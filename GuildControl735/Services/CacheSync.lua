-- Original bounded catch-up protocol. Only current trusted peers may relay.
-- Requesting cached records never calls FastSync:Request or polls their owners.
local _,G=...
local W,R=G.FastWire,G.FastRecords
local C={prefix="GC735C47",chunk=160,wanted=true,attempts={},cooldowns={},metrics={applied=0,completed=0,rejected=0}}
G.CacheSync=C
local function Clock()return GetTime()end
local function Own()return UnitGUID("player")end
local function Size(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function Online(m)return m and m.online and not m.isMobile end
local function Log(s)if G.Diagnostics then G.Diagnostics:Record("CACHE_SYNC",s)end end
function C:Want(reason)
 self.wanted=true;self.reason=reason
end
function C:Stop(reason)
 self.client=nil;self.server=nil;self.wanted=reason=="guild_event"
 self.nextAsk=Clock()+10
end
function C:Trusted(guid)
 if G.ManualBans and G.ManualBans:Blocked(guid)then return nil end
 local m=G.Roster:FindByKey(guid)
 return Online(m)and G.AdminTrust:Allowed(m.name)and m or nil
end
function C:Valid(s)
 if not s or s.guild~=G:GetGuildKey()or Clock()-s.started>600 then return false end
 return self:Trusted(s.provider)and Online(G.Roster:FindByKey(s.receiver))or false
end
function C:Send(s,msg,notBefore)
 local final=msg=="Z|"..s.id
 if msg:sub(1,2)~="Q|"then msg=s.receiver.."|"..msg end
 if #msg>220 then return false end
 return G.DataExchange:Enqueue(self.prefix,msg,function()
  return (C.client==s or C.server==s)and C:Valid(s)
 end,function()s.progress=Clock();if final then s.finalSent=true end end,nil,notBefore)
end
function C:Reject(why)
 self.metrics.rejected=self.metrics.rejected+1;self.lastReason=why
 if not self.lastLog or Clock()-self.lastLog>=5 then self.lastLog=Clock();Log("reject "..tostring(why))end
 return false,why
end
-- Reconstruct only hash-matching canonical records through existing validators.
-- Empty P is retained as a versioned deletion. Offline owners can be relayed.
function C:Export(member,includeOwn)
 if G.ManualBans and G.ManualBans:Blocked(member.guid)then return nil end
 local records={}
 if includeOwn and member.guid==Own()then
  local own=R:Own()
  for _,cat in ipairs(W.categories)do local r=own and own[cat]
   if r and R:Decode(cat,r.body,member,r)then records[cat]={rev=r.rev,len=r.len,hash=r.hash,body=r.body}end
  end
 else
  local known=R:Known(member)
  for _,cat in ipairs(W.categories)do local m=known[cat];local body=m and R:CachedBody(member,cat)
   if body and R:Decode(cat,body,member,m)then records[cat]={rev=m.rev,len=m.len,hash=m.hash,body=body}end
  end
 end
 return next(records)and records or nil
end
function C:Build(s,includeOwn)
 if includeOwn then G.OfficerMarks:CaptureAll()end
 s.members={};s.rows={};s.buildIndex=1;s.includeOwn=includeOwn
 for _,m in ipairs(G.Roster.members or{})do
  if W.GUID(m.guid)then s.members[#s.members+1]=m end
 end
 table.sort(s.members,function(a,b)return a.guid<b.guid end)
 if #s.members>1000 then return false end
 s.phase="build";return true
end
function C:BuildTick(s)
 local m=s.members[s.buildIndex]
 if m then
  s.buildIndex=s.buildIndex+1
  local rows=self:Export(m,s.includeOwn)
  if rows then
   if #s.rows>=500 then return false end
   s.rows[#s.rows+1]={owner=m.guid,records=rows,mark=G.OfficerMarks:Token(m.guid)}
  end
  return true
 end
 local parts={}
 for _,row in ipairs(s.rows)do parts[#parts+1]=row.owner..":"..W.Summary(row.records)..":"..(row.mark or "-")end
 s.digest=W.Hash(table.concat(parts,"\n"));s.members=nil
 return s.digest~=nil,"done"
end
function C:Start(provider)
 local root=R:Root();if not root then return false end
 root.cacheSequence=(tonumber(root.cacheSequence)or 0)+1
 if root.cacheSequence>1048575 then return false end
 local id=string.format("%08x%05x000",time(),root.cacheSequence)
 local s={id=id,provider=provider.guid,receiver=Own(),guild=G:GetGuildKey(),started=Clock(),progress=Clock(),phase="offer",index=0,packets=0,bytes=0}
 self.client=s;self.nextAsk=Clock()+60
 if not self:Send(s,"Q|"..id.."|"..provider.guid)then self.client=nil;return false end
 Log("request "..provider.guid);return true
end
function C:Offer(id,provider,member)
 if provider~=Own()or not G.AdminTrust:OwnAllowed()then return false,"not_provider"end
 local now=Clock()
 if id:sub(14)~="000"or math.abs(time()-tonumber(id:sub(1,8),16))>300 then return false,"nonce_age"end
 local root=R:Root();if not root then return false,"storage"end
 root.cacheSeen=root.cacheSeen or{}
 local old=root.cacheSeen[member.guid]
 if old and id<=old then return false,"replay"end
 if not old and Size(root.cacheSeen)>=500 then return false,"issuer_capacity"end
 if self.server or G.FastSync.job or G.FastSync.active or now<(self.nextOffer or 0)or now<(self.cooldowns[member.guid]or 0)then
  -- One bounded busy response, not a new owner survey. A confirmed busy peer
  -- remains eligible after a staggered minute, unlike an absent old client.
  self.busyReplies=self.busyReplies or{}
  if Size(self.busyReplies)<500 or self.busyReplies[member.guid]then
   if now>=(self.busyReplies[member.guid]or 0)then
    self.busyReplies[member.guid]=now+60;local guild=G:GetGuildKey()
    G.DataExchange:Enqueue(self.prefix,member.guid.."|B|"..id,function()
     return guild==G:GetGuildKey()and C:Trusted(Own())and Online(G.Roster:FindByKey(member.guid))
    end)
   end
  end
  return false,"busy"
 end
 root.cacheSeen[member.guid]=id;self.cooldowns[member.guid]=now+60;self.nextOffer=now+10
 local s={id=id,provider=Own(),receiver=member.guid,guild=G:GetGuildKey(),started=now,progress=now,index=0,packets=0,bytes=0}
 if not self:Build(s,true)then return false,"roster_capacity"end
 self.server=s;return true
end
function C:Next(s)
 local after=Clock()+(s.compactMulti and 0.28 or 0.02);s.compactMulti=nil
 s.index=s.index+1;s.packets=0
 local row=s.rows[s.index]
 if not row then s.phase="finish";return self:Send(s,"F|"..s.id)end
 s.row=row;s.rowID=s.id:sub(1,13)..string.format("%03x",s.index)
 s.phase="known"
 return self:Send(s,"O|"..s.rowID.."|"..row.owner.."|"..(row.mark or "-"),after)
  and self:Send(s,"S|"..s.rowID.."|"..W.Summary(row.records),after)
end
function C:Apply(s)
 if G.ManualBans and G.ManualBans:Blocked(s.owner)then return true end
 local member=G.Roster:FindByKey(s.owner)
 if not member or not s.meta or not s.known then return false,"owner_context"end
 local rows={}
 if s.total then
  if s.count~=s.total then return false,"incomplete"end
  local why;rows,why=W.Unpack(table.concat(s.parts),s.meta,s.known,s.owner)
  if not rows then return false,why end
 end
 for _,cat in ipairs(W.categories)do local meta=s.meta[cat]
  if meta and not W.Same(meta,s.known[cat])then
   if meta.len==0 then rows[cat]=""end
   if rows[cat]==nil then return false,"missing_body"end
  end
 end
 -- Officer metadata is independently bounded and checked before any write.
 if s.mark and not G.OfficerMarks:ValidToken(s.mark)then return false,"officer_mark_schema"end
 -- Full preflight, including rollback conflicts, before native writes.
 local root=R:Root();local prior=root and root.received[s.owner];local keepNativeRaid=false;local protected={}
 local relay=s.provider~=s.owner and s.provider or nil
 for cat,body in pairs(rows)do local meta=s.meta[cat];local old=prior and prior[cat]
  local valid,why=R:Decode(cat,body,member,meta);if not valid then return false,why end
  -- Trusted newer copies may refresh an offline owner's old direct record.
  -- Older/conflicting copies skip this category without aborting other rows.
  protected[cat]=relay and(s.owner==Own()or old and(meta.rev<old.rev or meta.rev==old.rev and meta.hash~=old.hash))or false
  if not protected[cat]and old and(relay or not old.relay)and(meta.rev<old.rev or meta.rev==old.rev and meta.hash~=old.hash)then return false,"revision_conflict"end
  if cat=="R"then
   local native=G.RaidRuntime:Get(member.guid)
   keepNativeRaid=native and type(native.capturedAt)=="number"and native.capturedAt>valid.stamp or false
   if old and old.relay and not relay then keepNativeRaid=false end
   if keepNativeRaid then
    if native.capturedAt>time()+300 then keepNativeRaid=false end
    for i=1,160 do if not G.RaidWire.Value(native.values[i])then keepNativeRaid=false;break end end
   end
  end
 end
 if not self:Valid(s)then return false,"revoked"end
 if s.mark and not G.OfficerMarks:ApplyToken(s.owner,s.mark,s.provider)then return false,"officer_mark_rejected"end
 for _,cat in ipairs(W.categories)do if rows[cat]~=nil and not protected[cat]and not(cat=="R"and keepNativeRaid)then
  local ok,why=R:Apply(member,cat,rows[cat],s.meta[cat],relay);if not ok then return false,why end
  self.metrics.applied=self.metrics.applied+1
 elseif protected[cat]then self.metrics.directKept=(self.metrics.directKept or 0)+1
 end end
 if G.RefreshLinkedMemberCard then G:RefreshLinkedMemberCard()end
 if keepNativeRaid then
  self.metrics.nativeRaidKept=(self.metrics.nativeRaidKept or 0)+1
  Log("kept newer native raid owner="..member.guid)
 end
 return true
end
function C:Receive(msg,sender,channel)
 if channel~="GUILD"then return false,"route"end
 local member,why=G.FastSync:Admit(msg,sender,channel,18)
 if not member then return false,why end
 if not Online(member)then return false,"offline_sender"end
 local recipient
 if msg:sub(1,2)~="Q|"then
  recipient,msg=msg:match("^(Player%-%d+%-%x+)|(.+)$")
  if not recipient or not W.GUID(recipient)then return self:Reject("recipient_schema")end
 end
 local kind,id=msg:match("^([A-Z])|([0-9a-f]+)")
 if not id or #id~=16 then return self:Reject("schema")end
 if kind=="Q"then
  local nonce,target=msg:match("^Q|([0-9a-f]+)|(Player%-%d+%-%x+)$")
  if not nonce or not W.GUID(target)then return self:Reject("query_schema")end
  if member.guid==Own()then return true end
  return self:Offer(nonce,target,member)
 end
 local s=self.server
 if s and recipient==s.receiver and member.guid==s.receiver and self:Valid(s)then
  if kind=="L"and msg=="L|"..s.id and s.phase=="list"then s.progress=Clock();return self:Next(s)end
  if kind=="Z"and msg=="Z|"..s.id and(s.phase=="list"or s.phase=="finish")then self.server=nil;return true end
  if kind=="K"and s.phase=="known"and id==s.rowID then
   local known=W.ParseSummary(msg:sub(20));if not known or msg:sub(19,19)~="|"then return self:Reject("known_schema")end
   local body,err=W.Pack(s.row.records,known,s.row.owner);if not body then return self:Reject(err)end
   s.phase="ack";s.progress=Clock()
   local frames={};local total=math.ceil(#body/self.chunk)
   for seq=1,total do frames[#frames+1]=string.format("D|%s|X|%02d|%02d|%s",id,seq,total,body:sub((seq-1)*self.chunk+1,seq*self.chunk))end
   local header=body~=""and W.PackedHeader(body,s.row.records,known)
   s.compactMulti=total>=2 and header and header.lengths[3]>0 and header.lengths[3]<s.row.records.R.len
   local after=Clock()+0.11+(s.compactMulti and 0.04 or 0)
   local interval=total>=3 and 0.15 or 0.125
   for i,p in ipairs(frames)do if not self:Send(s,p,after+(i-1)*interval)then return self:Reject("tx_capacity")end end
   return self:Send(s,"E|"..id,after+total*interval)
  end
  if kind=="A"and s.phase=="ack"and type(s.rowID)=="string"and msg=="A|"..s.rowID then s.progress=Clock();return self:Next(s)end
 end
 s=self.client
 if not s or recipient~=Own()or member.guid~=s.provider or not self:Valid(s)then return false,"not_recipient"end
 s.packets=s.packets+1;s.bytes=s.bytes+#msg
 if s.packets>10002 or s.bytes>2097152 then self.client=nil;return self:Reject("session_budget")end
 if kind=="V"and id==s.id and s.phase=="offer"then
  local hash=msg:match("^V|[0-9a-f]+|([0-9a-f]+)$")
  if not hash or #hash~=32 then return self:Reject("digest_schema")end
  s.remoteDigest=hash;s.progress=Clock();return self:Build(s,false)
 end
 if kind=="B"and msg=="B|"..s.id and s.phase=="offer"then
  self.client=nil;self.wanted=true
  self.attempts[s.provider]=math.max(0,(self.attempts[s.provider]or 1)-1)
  self.nextAsk=Clock()+60+(self.joinSlot or 1)*0.2
  return true
 end
 if kind=="O"and s.phase=="rows"then
  local rid,owner,mark=msg:match("^O|([0-9a-f]+)|(Player%-%d+%-%x+)|([^|]+)$")
  if not mark or not G.OfficerMarks:ValidToken(mark)then return self:Reject("officer_mark_schema")end
  local expected=s.id:sub(1,13)..string.format("%03x",s.index+1)
  if rid~=expected or s.index>=500 or not G.Roster:FindByKey(owner)then return self:Reject("owner_sequence")end
  if s.lastOwner and owner<=s.lastOwner then return self:Reject("owner_order")end
  s.index=s.index+1;s.rowID=rid;s.owner=owner;s.mark=mark;s.lastOwner=owner;s.meta=nil;s.known=nil;s.parts={};s.total=nil;s.count=0;s.rowBytes=0;s.rowPackets=0;s.phase="summary";s.progress=Clock();return true
 end
 if id==s.rowID then s.rowPackets=(s.rowPackets or 0)+1;if s.rowPackets>64 then return self:Reject("row_packet_budget")end end
 if kind=="S"and id==s.rowID and s.phase=="summary"and msg:sub(19,19)=="|"then
  local meta=W.ParseSummary(msg:sub(20));if not meta then return self:Reject("summary_schema")end
  s.meta=meta;s.known=R:Known(G.Roster:FindByKey(s.owner));s.phase="body";s.progress=Clock()
  -- An older provider must not roll back a newer local record. K may decline
  -- that category without changing any persisted revision or fingerprint.
  for _,cat in ipairs(W.categories)do local localMeta=s.known[cat];local remote=meta[cat]
   if localMeta and remote and localMeta.rev>remote.rev then s.known[cat]=remote end
  end
  return self:Send(s,"K|"..id.."|"..W.Summary(s.known))
 end
 if kind=="D"and id==s.rowID and s.phase=="body"then
  local rid,seq,total,body=msg:match("^D|([0-9a-f]+)|X|(%d%d)|(%d%d)|(.*)$")
  seq,total=tonumber(seq),tonumber(total)
  local cap=0;for _,cat in ipairs(W.categories)do local m=s.meta[cat];if m and not W.Same(m,s.known[cat])then cap=cap+m.len end end;cap=cap+17
  if not rid or not seq or not total or total<1 or total>math.ceil(cap/self.chunk)or seq<1 or seq>total or #body<1 or #body>self.chunk or(seq<total and #body~=self.chunk)then return self:Reject("fragment_bounds")end
  if s.total and s.total~=total then return self:Reject("fragment_conflict")end
  if s.parts[seq]then return s.parts[seq]==body or self:Reject("fragment_conflict")end
  if s.rowBytes+#body>cap then return self:Reject("fragment_bounds")end
  if seq==1 then local h,err=W.PackedHeader(body,s.meta,s.known);if not h or math.ceil(h.bytes/self.chunk)~=total then return self:Reject(err or"fragment_length")end end
  s.total=total;s.parts[seq]=body;s.count=s.count+1;s.rowBytes=s.rowBytes+#body;s.progress=Clock();return true
 end
 if kind=="E"and msg=="E|"..s.rowID and s.phase=="body"then
  local ok,err=self:Apply(s);if not ok then self.client=nil;self:Want("apply_retry");return self:Reject(err)end
  s.phase="rows";s.progress=Clock();return self:Send(s,"A|"..id)
 end
 if kind=="F"and msg=="F|"..s.id and s.phase=="rows"then
  self:Send(s,"Z|"..s.id);s.phase="done";s.doneAt=Clock();self.metrics.completed=self.metrics.completed+1
  self.attempts={}
  Log("complete owners="..s.index.." via="..s.provider);return true
 end
 return self:Reject("phase_or_nonce")
end
function C:Tick()
 if not G.db or not G.Roster or not Own()then return end
 local key=G:GetGuildKey()
 if key~=self.guild then
  self.guild=key;self.server=nil;self.client=nil;self.attempts={};self.cooldowns={};self.busyReplies={};self.wanted=true
  local ids={};for _,m in ipairs(G.Roster.members or{})do if W.GUID(m.guid)then ids[#ids+1]=m.guid end end;table.sort(ids)
  self.joinSlot=1;for i,guid in ipairs(ids)do if guid==Own()then self.joinSlot=i;break end end
  self.nextAsk=Clock()+10+self.joinSlot*0.2
 end
 if not key then return end
 local paused=G.DataExchange:Paused()
 for _,name in ipairs({"server","client"})do local s=self[name]
  if s then
   if not self:Valid(s)then self[name]=nil;self:Want("context_changed")
   elseif s.phase=="done"then if s.finalSent or Clock()-s.doneAt>30 then self[name]=nil end
   elseif paused then s.progress=Clock()
   elseif Clock()-s.progress>60 then self[name]=nil;self:Want("timeout");Log("timeout "..name.." via="..s.provider)
   elseif s.phase=="build"then
    local ok,status=self:BuildTick(s);s.progress=Clock()
    if not ok then self[name]=nil;self.lastReason="catalogue_capacity"
    elseif status=="done"then
     if name=="server"then s.phase="list";self:Send(s,"V|"..s.id.."|"..s.digest)
     elseif s.digest==s.remoteDigest then
      self:Send(s,"Z|"..s.id);s.phase="done";s.doneAt=Clock();self.metrics.completed=self.metrics.completed+1;Log("unchanged")
      self.attempts={}
     else s.phase="rows";self:Send(s,"L|"..s.id)end
    end
   end
  end
 end
 if paused or self.client or self.server or not self.wanted or Clock()<(self.nextAsk or 0)or G.FastSync.job or G.FastSync.active then return end
 if Clock()<(self.electAt or 0)then return end
 self.electAt=Clock()+5
 local peers={};local fingerprint={}
 for _,m in ipairs(G.Roster.members or{})do if m.guid~=Own()and self:Trusted(m.guid)then peers[#peers+1]=m end end
 table.sort(peers,function(a,b)if a.rankIndex~=b.rankIndex then return a.rankIndex<b.rankIndex end;return a.guid<b.guid end)
 for _,m in ipairs(peers)do fingerprint[#fingerprint+1]=m.guid end
 local signature=table.concat(fingerprint,",")
 if self.peers~=signature then self.peers=signature;self.attempts={};self.exhaustedAt=nil end
 for _,m in ipairs(peers)do if(self.attempts[m.guid]or 0)<2 then
  self.attempts[m.guid]=(self.attempts[m.guid]or 0)+1
  if self:Start(m)then self.wanted=false end
  self.exhaustedAt=nil
  return
 end end
 if #peers>0 then
  self.exhaustedAt=self.exhaustedAt or Clock()+300
  if Clock()>=self.exhaustedAt then self.attempts={};self.exhaustedAt=nil end
 end
end
local frame=CreateFrame("Frame");C.frame=frame;RegisterAddonMessagePrefix(C.prefix)
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent",function(_,_,prefix,msg,ch,sender)
 if prefix~=C.prefix or ch~="GUILD"then return end
 if G.SpamShield and G.SpamShield:IsBlocked(sender)then return end
 C:Receive(msg,sender,ch)
end)
frame:SetScript("OnUpdate",function(_,dt)
 C.elapsed=(C.elapsed or 0)+dt
 if C.elapsed>=0.05 then C.elapsed=0;C:Tick()end
end)
