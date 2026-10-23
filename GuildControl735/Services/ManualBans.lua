-- Leader-authenticated local policy; no relayed policy or remote native actions.
local _,G=...
local B={prefix="GC735BAN",rates={},sequence=0};G.ManualBans=B
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function integer(v,lo,hi)
 if type(v)~="string"or not v:match("^%d+$")or #v>14 or(#v>1 and v:sub(1,1)=="0")then return end
 local n=tonumber(v);if n and n>=lo and n<=hi then return n end
end
function B:Root()
 if not G.db or not G.AdminTrust or not G.AdminTrust.leader or not G:GetGuildKey()then return end
 G.db.manualBans=G.db.manualBans or{guilds={}};local all=G.db.manualBans.guilds;local key=G:GetGuildKey();local r=all[key]
 if not r then if count(all)>=10 then return end;r={};all[key]=r end
 if r.leader~=G.AdminTrust.leader then r.leader=G.AdminTrust.leader;r.entries={};r.revision=0;r.confirmed=false;r.digest=nil end
 if G.AdminTrust:IsLeader()and not r.confirmed then r.confirmed=true;r.revision=time()*1000 end
 return r
end
function B:Get(guid)
 local r=self:Root();return r and r.confirmed and r.entries[guid]or nil
end
function B:Blocked(guid)
 local r=self:Get(guid);return r and r.untilAt>time()or false
end
function B:BlockedSender(sender)
 local T=G.AdminTrust;local key=T and G.TrustBoundary:CanonicalName(sender)
 local m=key and T.members and T.members[key]
 return m and self:Blocked(m.guid)or false
end
function B:SetMany(ids,days)
 G.AdminTrust:Refresh()
 if not G.AdminTrust:IsLeader()or(days~=0 and days~=1 and days~=3 and days~=6)then return false,"leader_only_or_duration"end
 local root=self:Root();if not root then return false,"storage"end
 local seen,missing={},0
 for _,guid in ipairs(ids)do
  if not G.FastWire.GUID(guid)or guid==root.leader or(not G.Roster:FindByKey(guid)and not(days==0 and root.entries[guid]))then return false,"target"end
  if seen[guid]then return false,"duplicate_target"end;seen[guid]=true;if not root.entries[guid]then missing=missing+1 end
 end
 if not next(seen)or count(root.entries)+missing>500 then return false,"capacity_or_empty"end
 for guid in pairs(seen)do
  local old=root.entries[guid]or{total=0,untilAt=0}
  root.entries[guid]={untilAt=days==0 and 0 or time()+days*86400,total=math.min(1000000,old.total+(days>0 and 1 or 0))}
 end
 root.revision=math.max(time()*1000,root.revision+1);self.dirty=true;self.tx=nil;self.pending=nil
 if G.RefreshNetworkBadge then G:RefreshNetworkBadge()end
 return true
end
function B:Snapshot()
 local r=self:Root();if not r then return end
 local ids={};for guid in pairs(r.entries)do ids[#ids+1]=guid end;table.sort(ids)
 local rows={};for _,guid in ipairs(ids)do local x=r.entries[guid];rows[#rows+1]=guid.."|"..x.untilAt.."|"..x.total end
 return rows,G.FastWire.Hash(table.concat(rows,"\n"))
end
function B:Broadcast()
 if not G.AdminTrust:IsLeader()then return end
 local r=self:Root();local rows,hash=self:Snapshot();if not rows or not hash then return end
 self.sequence=(self.sequence+1)%268435455
 local sid=string.format("%08x%08x",time(),self.sequence)
 local messages={"S|"..sid.."|"..string.format("%.0f",r.revision).."|"..r.leader.."|"..#rows.."|"..hash}
 for i,row in ipairs(rows)do messages[#messages+1]="R|"..sid.."|"..i.."|"..row end
 messages[#messages+1]="E|"..sid.."|"..hash
 self.tx={messages=messages,index=1,root=r,revision=r.revision,guild=G:GetGuildKey()};self.lastBroadcast=GetTime();self.dirty=false
end
function B:Receive(msg,sender,ch)
 if ch~="GUILD"or type(msg)~="string"or #msg>220 or #msg<19 or msg:find("[%z\1-\31\127]")then return false,"route_schema"end
 local T=G.AdminTrust;if T.key~=G:GetGuildKey()or not T.refreshed or GetTime()-T.refreshed>120 then return false,"roster"end
 local m=T.members[G.TrustBoundary:CanonicalName(sender)or""];if not m then return false,"identity"end
 if msg:sub(1,2)~="Q|"and(m.guid~=T.leader or m.rank~=0)then return false,"leader_identity"end
 local now=GetTime();if not self.window or now-self.window>=1 then self.window=now;self.work=0 end
 self.work=self.work+1;if self.work>200 then return false,"work_budget"end
 local rate=self.rates[m.guid];if not rate then if count(self.rates)>=500 then return false,"capacity"end;rate={at=now,n=0};self.rates[m.guid]=rate end
 if now-rate.at>=10 or now<rate.at then rate.at=now;rate.n=0 end;rate.n=rate.n+1;if rate.n>80 then return false,"sender_budget"end
 local kind,sid=msg:match("^([QSRE])|([0-9a-f]+)|");if not sid or #sid~=16 then return false,"schema"end
 if kind=="Q"then
  local known=integer(msg:match("^Q|[0-9a-f]+|(%d+)$"),0,(time()+300)*1000)
  if not known then return false,"query_schema"end
  local root=self:Root()
  if T:IsLeader()and root and known~=root.revision and not self.tx and now-(self.lastBroadcast or -100)>=60 then self:Broadcast()end
  return true
 end
 if m.guid==UnitGUID("player")then return true end
 local root=self:Root();if not root then return false,"storage"end
 if kind=="S"then
  local rev,leader,n,hash=msg:match("^S|[0-9a-f]+|(%d+)|(Player%-%d+%-%x+)|(%d+)|([0-9a-f]+)$")
  rev=integer(rev,1,(time()+300)*1000);n=integer(n,0,500)
  if not rev or not n or leader~=T.leader or not hash or #hash~=32 or rev<root.revision then return false,"snapshot_header"end
  if rev==root.revision and root.confirmed and root.digest and hash~=root.digest then return false,"revision_conflict"end
  if self.pending and now-self.pending.at<180 and self.pending.sid~=sid and rev<=self.pending.rev then return false,"busy_or_replay"end
  self.pending={sid=sid,rev=rev,count=n,hash=hash,entries={},rows={},index=0,at=now,leader=leader,guild=G:GetGuildKey()};return true
 end
 local p=self.pending;if not p or p.sid~=sid or p.guild~=G:GetGuildKey()or p.leader~=T.leader or now-p.at>180 then return false,"session"end
 if kind=="R"then
  local i,guid,untilAt,total=msg:match("^R|[0-9a-f]+|(%d+)|(Player%-%d+%-%x+)|(%d+)|(%d+)$")
  i=integer(i,1,500);untilAt=integer(untilAt,0,time()+6*86400+300);total=integer(total,0,1000000)
  if not i or i~=p.index+1 or i>p.count or not untilAt or not total or guid==T.leader or not G.FastWire.GUID(guid)or p.entries[guid]or(p.last and guid<=p.last)then return false,"row_schema"end
  p.index=i;p.last=guid;p.entries[guid]={untilAt=untilAt,total=total};p.rows[i]=guid.."|"..untilAt.."|"..total;return true
 end
 if kind~="E"or msg~="E|"..sid.."|"..p.hash or p.index~=p.count or G.FastWire.Hash(table.concat(p.rows,"\n"))~=p.hash then return false,"snapshot_incomplete"end
 -- Commit only the complete authenticated snapshot, never partial bans/unbans.
 local changed=not root.confirmed or root.revision~=p.rev or root.digest~=p.hash
 root.entries=p.entries;root.revision=p.rev;root.digest=p.hash;root.confirmed=true;self.pending=nil
 if changed and(not self.lastNotice or now-self.lastNotice>=60)then self.lastNotice=now;G:Print((G:Text("Список ручных ограничений главы обновлён. Подробности: «Сетевая защита».")))end
 return true
end
function B:Tick()
 local root=self:Root();if not root then self.tx=nil;self.pending=nil;return end
 local now=GetTime()
 for guid,r in pairs(self.rates)do if now-r.at>10 then self.rates[guid]=nil end end
 if self.pending and(now-self.pending.at>180 or self.pending.leader~=root.leader or self.pending.guild~=G:GetGuildKey())then self.pending=nil end
 local tx=self.tx
 if tx and(tx.root~=root or tx.revision~=root.revision or tx.guild~=G:GetGuildKey()or not G.AdminTrust:IsLeader())then self.tx=nil;tx=nil end
 if tx then
  local msg=tx.messages[tx.index]
  if not msg then self.tx=nil;return end
  if not tx.queued then
   tx.queued=true
   if not G.DataExchange:Enqueue(self.prefix,msg,function()return B.tx==tx and G.AdminTrust:IsLeader()and tx.revision==root.revision end,
    function()tx.queued=nil;tx.index=tx.index+1;if tx.index>#tx.messages then B.tx=nil end end,function()tx.queued=nil end)then tx.queued=nil end
  end
 elseif G.AdminTrust:IsLeader()then
  if self.dirty and now-(self.lastBroadcast or -100)>=5 then self:Broadcast()end
 elseif not self.pending and now>=(self.nextAsk or 0)then
  self.sequence=(self.sequence+1)%268435455;local sid=string.format("%08x%08x",time(),self.sequence)
  local guild=G:GetGuildKey();G.DataExchange:Enqueue(self.prefix,"Q|"..sid.."|"..string.format("%.0f",root.confirmed and root.revision or 0),function()return guild==G:GetGuildKey()end)
  self.nextAsk=now+60+(tonumber((UnitGUID("player")or"0"):sub(-3),16)or 0)%20
 end
end
local f=CreateFrame("Frame");B.frame=f;RegisterAddonMessagePrefix(B.prefix);f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent",function(_,_,prefix,msg,ch,sender)if prefix==B.prefix and ch=="GUILD"then B:Receive(msg,sender,ch)end end)
f:SetScript("OnUpdate",function(_,dt)B.elapsed=(B.elapsed or 0)+dt;if B.elapsed>=.25 then B.elapsed=0;B:Tick()end end)
