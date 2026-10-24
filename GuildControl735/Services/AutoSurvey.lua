-- Cooperative scheduler only. Owner records still use the existing authenticated wire.
local _,G=...
local W,R=G.FastWire,G.FastRecords
local A={prefix="GC735AUTO1",peers={},out={},pendingMarks={},asked={},interval=1800,age=28800,lease=70,maxPass=900}
G.AutoSurvey=A
local function Clock()return GetTime()end
local function Own()return UnitGUID("player")end
local function Count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function Online(m)return m and m.online and not m.isMobile end
function A:Trusted(guid)
 local m=G.Roster:FindByKey(guid)
 return Online(m)and G.AdminTrust:Allowed(m.name)and(not G.ManualBans or not G.ManualBans:Blocked(guid))and m or nil
end
function A:Root()
 local key=G:GetGuildKey();if not G.db or not key then return nil end
 G.db.autoSurvey=G.db.autoSurvey or{guilds={}}
 local all=G.db.autoSurvey.guilds
 if not all[key]then if Count(all)>=10 then return nil end;all[key]={marks={},queue={},nextAt=0,sequence=0}end
 return all[key]
end
function A:Known(guid)
 local m=G.Roster:FindByKey(guid);if not m then return nil end
 local rows=guid==Own()and R:Own()or R:Known(m)
 if not rows or not rows.P or not rows.F or not rows.R then return nil end
 return W.Summary(rows)
end
function A:Fresh(guid)
 local root=self:Root();local m=root and root.marks[guid]
 local records=R:Root();local rows=records and(guid==Own()and records.own[guid]or records.received[guid])
 return m and m.at<=time()+300 and time()-m.at<self.age and rows and W.Summary(rows)==m.summary or false
end
function A:Mark(guid,at,summary,source)
 local root=self:Root()
 if not root or not W.GUID(guid)or not G.Roster:FindByKey(guid)or not W.ParseSummary(summary)or at>time()+300 or time()-at>self.age or at<1 then return false end
 if self:Known(guid)~=summary then
  if Count(self.pendingMarks)<500 or self.pendingMarks[guid]then
   local old=self.pendingMarks[guid];if not old or at>old.at then self.pendingMarks[guid]={at=at,summary=summary,source=source}end
  end
  if G.CacheSync then G.CacheSync:Want("survey_missing_record");G.CacheSync.preferredProvider=source end
  return false
 end
 local old=root.marks[guid]
 if not old or at>old.at then
  if not old and Count(root.marks)>=1000 then return false end
  root.marks[guid]={at=at,summary=summary,source=source}
 end
 root.queue[guid]=nil;self.pendingMarks[guid]=nil
 return true
end
function A:Push(msg)
 if #msg>220 or #self.out>=1600 then return false end
 self.out[#self.out+1]=msg;return true
end
function A:Completed(session,code)
 if code~="OK"or not session.meta then return end
 local summary=W.Summary(session.meta)
 local at=time();self:Mark(session.target,at,summary,session.issuer)
 if session.issuer==Own()and G.AdminTrust:OwnAllowed()then
  self:Push("M|"..session.target.."|"..at.."|"..summary)
 end
end
function A:Heartbeat()
 local root=self:Root();if not root then return end
 local p=self.running
 root.heartbeat=math.max((root.heartbeat or 0)+1,time()*1000)
 local msg=table.concat({"H",string.format("%.0f",root.heartbeat),p and p.id or"-",p and p.started or 0,math.floor(root.nextAt or 0)},"|")
 local key=G:GetGuildKey()
 return G.DataExchange:Enqueue(self.prefix,msg,function()return key==G:GetGuildKey()and A.running==p and G.AdminTrust:OwnAllowed()end)
end
function A:Snapshot()
 if self.snapshotQueued then return end
 local root=self:Root();if not root then return end
 self.snapshotQueued=true;self:Heartbeat()
 for guid,m in pairs(root.marks)do if self:Fresh(guid)then self:Push("M|"..guid.."|"..m.at.."|"..m.summary)end end
 local p=self.running
 if p then for guid in pairs(root.queue)do self:Push("J|"..p.id.."|"..p.started.."|"..guid)end end
end
function A:Candidate()
 local peers={};local now=Clock()
 for guid,p in pairs(self.peers)do if now-p.seen<=self.lease and self:Trusted(guid)then peers[#peers+1]=guid end end
 table.sort(peers,function(a,b)
  local x,y=G.Roster:FindByKey(a),G.Roster:FindByKey(b)
  if x.rankIndex~=y.rankIndex then return x.rankIndex<y.rankIndex end;return a<b
 end)
 return peers[1]
end
function A:Active()
 local best,selected
 for guid,p in pairs(self.peers)do
  if p.id and Clock()-p.seen<=self.lease and self:Trusted(guid)and time()-p.started<self.maxPass+300 then
   if not selected or p.started<selected.started or p.started==selected.started and guid<best then best,selected=guid,p end
  end
 end
 return best,selected
end
function A:AddOnline()
 local root=self:Root();if not root or not self.running then return end
 local p=self.running
 for _,m in ipairs(G.Roster.members or{})do
  if Online(m)and W.GUID(m.guid)and not self:Fresh(m.guid)and not p.visited[m.guid]and not root.queue[m.guid]
    and(not G.ManualBans or not G.ManualBans:Blocked(m.guid))and Count(root.queue)<500 then
   root.queue[m.guid]=true;self:Push("J|"..p.id.."|"..p.started.."|"..m.guid)
  end
 end
end
function A:Begin(previous)
 local root=self:Root();if not root then return end
 root.sequence=(root.sequence or 0)+1
 local started=previous and previous.started or time()
 if time()-started>=self.maxPass then started=time();previous=nil end
 self.running={id=previous and previous.id or string.format("%08x%06x",time(),root.sequence%16777216),started=started,visited={},nextBatch=Clock()+3}
 root.pass={id=self.running.id,started=started}
 if G.Diagnostics then G.Diagnostics:Record("AUTO_SURVEY_BEGIN",self.running.id)end
 self:AddOnline();self:Heartbeat()
end
function A:EndPass(reason)
 local root=self:Root();if not root then return end
 if G.FastSync.job and G.FastSync.job.automatic then G.FastSync:Stop(reason or"auto_end")end
 self.running=nil;self.batch=nil;root.pass=nil;root.queue={}
 root.nextAt=time()+self.interval
 if G.Diagnostics then G.Diagnostics:Record("AUTO_SURVEY_END",reason or"complete")end
 self:Heartbeat();self.peers[Own()]={seen=Clock()}
end
function A:ManualStop()
 local root=self:Root();if root then root.nextAt=time()+self.interval end
 if self.running then self:EndPass("manual_stop")end
 self.out={};self.snapshotQueued=nil
 self.quietUntil=Clock()+self.interval
end
function A:Receive(msg,sender,channel)
 if not self.rootKey or channel~="GUILD"then return false end
 local member=G.FastSync:Admit(msg,sender,channel,3)
 if not member or not self:Trusted(member.guid)then return false end
 local root=self:Root();if not root then return false end
 local kind=msg:sub(1,2)
 if kind=="H|"then
  local serial,id,started,due=msg:match("^H|(%d+)|([0-9a-f%-]+)|(%d+)|(%d+)$")
  serial=W.Int(serial,1,(time()+300)*1000+999)
  started=tonumber(started);due=tonumber(due)
  if not serial or not id or(id~="-"and #id~=14)or not due or due>time()+self.interval+300 or not started or started>time()+300 then return false end
  if id~="-"and(time()-started>self.maxPass+300 or started<1)then return false end
  root.heartbeats=root.heartbeats or{}
  if serial<=(root.heartbeats[member.guid]or 0)then return false end
  if not root.heartbeats[member.guid]and Count(root.heartbeats)>=1000 then return false end
  root.heartbeats[member.guid]=serial
  local old=self.peers[member.guid]
  self.peers[member.guid]={seen=Clock(),id=id~="-"and id or nil,started=started}
  root.nextAt=math.max(root.nextAt or 0,due)
  if member.guid~=Own()and(not old or Clock()-old.seen>self.lease)then
   self.snapshotWanted=true
  end
  return true
 elseif kind=="M|"then
  local guid,stamp,summary=msg:match("^M|(Player%-%d+%-%x+)|(%d+)|(.+)$")
  local at=W.Int(stamp,1,time()+300);if not at then return false end
  return self:Mark(guid,at,summary,member.guid)
 elseif kind=="J|"then
  local id,stamp,guid=msg:match("^J|([0-9a-f]+)|(%d+)|(Player%-%d+%-%x+)$")
  local p=self.peers[member.guid];local active=self:Active()
  if not id or not p or p.id~=id or active~=member.guid or tonumber(stamp)~=p.started or not W.GUID(guid)or not G.Roster:FindByKey(guid)then return false end
  root.pass={id=id,started=p.started}
  if not self:Fresh(guid)and Count(root.queue)<500 then root.queue[guid]=true end
  return true
 elseif kind=="Q|"then
  local target=msg:match("^Q|(Player%-%d+%-%x+)$")
  if target~=Own()or not G.AdminTrust:OwnAllowed()then return false end
  if Clock()<(self.asked[member.guid]or 0)then return false end
  self.asked[member.guid]=Clock()+60;self:Snapshot();return true
 end
 return false
end
function A:Tick()
 local key=G:GetGuildKey();local root=self:Root()
 if not root then return end
 if self.rootKey~=key then
  self.rootKey=key;self.peers={};self.out={};self.asked={};self.pendingMarks={};self.running=nil;self.batch=nil
  self.readyAt=Clock()+25;self.nextBeat=0;self.nextPull=Clock()+8;self.snapshotWanted=true
 end
 if not G.AdminTrust:OwnAllowed()or not self:Trusted(Own())then
  if self.running then self:EndPass("permission_changed")end
  self.out={};return
 end
 -- Bounded housekeeping; expired marks never become permanent suppression.
 if not self.pruned or Clock()-self.pruned>=60 then
  self.pruned=Clock()
  for guid,m in pairs(root.marks)do if not G.Roster:FindByKey(guid)or time()-m.at>=self.age or m.at>time()+300 then root.marks[guid]=nil end end
  for guid in pairs(root.queue)do if not G.Roster:FindByKey(guid)then root.queue[guid]=nil end end
  for guid,p in pairs(self.peers)do if Clock()-p.seen>self.lease then self.peers[guid]=nil;self.asked[guid]=nil end end
 end
 if Clock()>=(self.nextMarkCheck or 0)then
  self.nextMarkCheck=Clock()+10
  local ids={};for guid in pairs(self.pendingMarks)do ids[#ids+1]=guid end;table.sort(ids)
  for _=1,math.min(5,#ids)do
   self.markCursor=(self.markCursor or 0)%#ids+1
   local guid=ids[self.markCursor];local m=self.pendingMarks[guid]
   if time()-m.at>=self.age or not self:Trusted(m.source)then self.pendingMarks[guid]=nil
   elseif self:Known(guid)==m.summary then self:Mark(guid,m.at,m.summary,m.source)end
  end
 end
 if G.DataExchange:Paused()then return end
 if Clock()>=(self.nextBeat or 0)then self.nextBeat=Clock()+20;self:Heartbeat()end
 -- Never enqueue a snapshot wholesale in the transport's 32-entry queue.
 if #self.out>0 and #G.DataExchange.queue<8 and Clock()>=(self.nextSend or 0)then
  local msg=self.out[1];local guild=key
  if G.DataExchange:Enqueue(self.prefix,msg,function()return guild==G:GetGuildKey()and G.AdminTrust:OwnAllowed()end)then table.remove(self.out,1);self.nextSend=Clock()+0.5 end
 end
 if #self.out==0 then self.snapshotQueued=nil end
 local active=self:Active();local candidate=self:Candidate()
 if (self.snapshotWanted or Clock()>=(self.nextReconcile or 0))and Clock()>=(self.nextPull or 0)then
  local provider=active~=Own()and active or nil
  if not provider then
   local others={};for guid,p in pairs(self.peers)do if guid~=Own()and Clock()-p.seen<=self.lease and self:Trusted(guid)then others[#others+1]=guid end end
   table.sort(others)
   if #others>0 then self.pullSlot=(self.pullSlot or 0)%#others+1;provider=others[self.pullSlot]end
  end
  if provider and provider~=Own()then
   self:Push("Q|"..provider);G.CacheSync:Want("trusted_join")
   G.CacheSync.preferredProvider=provider
   self.snapshotWanted=nil;self.nextPull=Clock()+60;self.nextReconcile=Clock()+120
  end
 end
 if Clock()<(self.readyAt or 0)or Clock()<(self.quietUntil or 0)then return end
 if self.running then
  if active and active~=Own()then
   if G.FastSync.job and G.FastSync.job.automatic then G.FastSync:Stop("other_coordinator")end
   self.running=nil;self.batch=nil;self.snapshotWanted=true;return
  end
  if time()-self.running.started>=self.maxPass then self:EndPass("time_budget");return end
  if G.FastSync.job then return end
  if self.batch then
   for guid in pairs(self.batch)do root.queue[guid]=nil;self.running.visited[guid]=true end
   self.batch=nil;self.running.nextBatch=Clock()+12
  end
  self:AddOnline()
  if Clock()<self.running.nextBatch or G.FastSync.active or G.CacheSync.client or G.CacheSync.server then return end
  local targets={};local n=0
  local ids={};for guid in pairs(root.queue)do ids[#ids+1]=guid end;table.sort(ids)
  for _,guid in ipairs(ids)do
   if self:Fresh(guid)or not Online(G.Roster:FindByKey(guid))then root.queue[guid]=nil
   elseif n<5 then targets[guid]=true;n=n+1 end
  end
  if n==0 then self:EndPass("complete");return end
  if G.FastSync:Request(nil,{targets=targets,automatic=true})then self.batch=targets end
 elseif not active and candidate==Own()and time()>=(root.nextAt or 0)and not G.FastSync.job and not G.FastSync.active and not G.CacheSync.client and not G.CacheSync.server then
  self:Begin(root.pass)
 end
end
function A:Initialize()
 if self.frame then return end
 RegisterAddonMessagePrefix(self.prefix)
 local f=CreateFrame("Frame");self.frame=f;f:RegisterEvent("CHAT_MSG_ADDON")
 f:SetScript("OnEvent",function(_,_,prefix,msg,ch,sender)
  if prefix==A.prefix and(not G.SpamShield or not G.SpamShield:IsBlocked(sender))then A:Receive(msg,sender,ch)end
 end)
 local dt=0;f:SetScript("OnUpdate",function(_,elapsed)dt=dt+(elapsed or 0);if dt>=1 then dt=0;A:Tick()end end)
end
