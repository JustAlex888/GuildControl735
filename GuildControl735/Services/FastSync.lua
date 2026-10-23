-- Original bounded GUILD group survey; no GRM code.
local _,G=...
local W,R=G.FastWire,G.FastRecords
local F={prefix=W.prefix,metrics={accepted=0,rejected=0,sent=0,unchanged=0,changed=0,timeouts=0},rates={},acked={},probes={},recent={}}
G.FastSync=F
local E={metrics=F.metrics,receiving=false,dispatch=false};G.SecureExchange=E
local function Guid()return UnitGUID("player")end
local function Clock()return GetTime()end
local function Online(m)return m and m.online and not m.isMobile end
local function Count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
function F:BudgetDrop(reason)
 self.metrics[reason]=(self.metrics[reason]or 0)+1
 local run=G.SpamShield and G.SpamShield.run
 if run then run.reasonCounts=run.reasonCounts or{};run.reasonCounts[reason]=(run.reasonCounts[reason]or 0)+1 end
 return false,reason
end
function F:Reject(reason,sender)
 self.metrics.rejected=self.metrics.rejected+1;E.lastReason=reason;E.lastSender=sender
 if G.SpamShield then G.SpamShield:Reject(sender,reason,self.prefix)end
 return false,reason
end
function F:Valid(a)
 if a and G.ManualBans and(G.ManualBans:Blocked(a.issuer)or G.ManualBans:Blocked(a.target))then return false end
 if not a or(a~=self.active and self.probes[a.sid]~=a)or a.guild~=G:GetGuildKey()or Clock()-a.started>30 then return false end
 if not self.chain or self.chain.slots[a.slot]~=a or Clock()-self.chain.started>30 then return false end
 local issuer=G.Roster:FindBySender(a.sender);local target=G.Roster:FindByKey(a.target)
 return Online(issuer)and issuer.guid==a.issuer and Online(target)and G.AdminTrust:Allowed(a.sender)or false
end
function F:ChainValid(c)
 if c and G.ManualBans and G.ManualBans:Blocked(c.issuer)then return false end
 if not c or c~=self.chain or c.base~=self.groupKey or c.guild~=G:GetGuildKey()or Clock()-c.started>30 then return false end
 local m=G.Roster:FindBySender(c.sender)
 return Online(m)and m.guid==c.issuer and G.AdminTrust:Allowed(c.sender)or false
end
function F:Close(a)
 a=a or self.active;if not a then return end
 self.probes[a.sid]=nil
 if a.issuer~=Guid()and a.received.X and not a.ready.X and G.CacheSync then G.CacheSync:Want("incomplete_live_body")end
 if self.active==a then self.active=nil;E.grant=nil end
 if not next(self.probes)then self.coordinator=nil end
 if Count(self.recent)>=64 then local oldest,at;for sid,r in pairs(self.recent)do if not at or r.at<at then oldest,at=sid,r.at end end;self.recent[oldest]=nil end
 self.recent[a.sid]={target=a.target,at=Clock(),guild=a.guild}
end
function F:Stop(reason)
 if self.job then self.job.reason=reason;self.lastJob=self.job end
 self.job=nil;E.job=nil;self.active=nil;E.grant=nil;self.probes={};self.coordinator=nil;self.groupKey=nil;self.chain=nil
end
function F:Finish(code,a)
 a=a or self.active;if not a then return end
 local p=a.plan;local j=self.job
 if a.issuer==Guid()and j and p and not p.finished then
  p.finished=true;j.completed=j.completed+1
  if code~="OK"then j.partial=j.partial+1
  elseif a.changed==0 then j.unchanged=j.unchanged+1;self.metrics.unchanged=self.metrics.unchanged+1 end
  j.changed=j.changed+(a.changed or 0);j.nextAt=Clock()+(a.phase=="probe"and 0 or 0.125)
 end
 a.done=true;self:Close(a);self:Advance()
end
function F:Send(msg,a,onSent,notBefore)
 if #msg>W.limit then return false end
 return G.DataExchange:Enqueue(self.prefix,msg,function()return F:Valid(a)end,function()
  F.metrics.sent=F.metrics.sent+1;a.progress=Clock();if onSent then onSent()end
 end,nil,notBefore)
end
function F:Request(target)
 if not G.AdminTrust:OwnAllowed()then return false,"own_rank_not_trusted"end
 if not W.Hash("")then return false,"bit_api_unavailable"end
 if self.job then return false,"collection_already_running"end
 G.OfficerMarks:CaptureAll()
 local targets={}
 for _,m in ipairs(G.Roster.members or{})do if Online(m)and W.GUID(m.guid)and(not G.ManualBans or not G.ManualBans:Blocked(m.guid))and(not target or target=="ALL"or target==m.guid)then targets[#targets+1]=m.guid end end
 table.sort(targets);if #targets==0 or #targets>500 then return false,"online_targets"end
 self.job={targets=targets,index=1,completed=0,unchanged=0,changed=0,partial=0,skipped=0,failed=0,guild=G:GetGuildKey(),started=Clock(),nextAt=Clock(),groups=0}
 E.job=self.job;return true
end
function F:SurveyGroup(j)
 local group=j.group
 G.db.fastSequence=(tonumber(G.db.fastSequence)or 0)+1
 if G.db.fastSequence>268435455 then self:Stop("sequence_capacity");return end
 local base=string.format("%08x%07x",time(),G.db.fastSequence)
 group.base=base;group.started=Clock()
 self.active=nil;E.grant=nil;self.probes={};self.chain=nil;self.groupKey=nil;self.coordinator=nil
 local todo={}
 for _,p in ipairs(group.entries)do if not p.finished then
  if Online(G.Roster:FindByKey(p.target))then todo[#todo+1]=p else p.finished=true;j.skipped=j.skipped+1 end
 end end
 local size=#todo;local delay=GetFramerate and GetFramerate()<20 and 1500 or 750
 for slot,p in ipairs(todo)do
  p.sid=base..slot;p.answered=false;p.session=nil;p.sentAt=Clock();p.queued=true
  local member=G.Roster:FindByKey(p.target);p.known=R:Known(member)
  -- Cached relay revisions never suppress a direct owner body, even if a
  -- malicious relay chose an artificially large revision or matching hash.
  for cat,meta in pairs(p.known)do if meta.relay then p.known[cat]=nil end end
  -- Slot is already in the nonce; reuse the former slot field for group size.
  local sid=p.sid;local msg="B|"..sid.."|"..p.target.."|"..size.."|"..string.format("%04d",delay).."|"..W.Summary(p.known)
  local ok=G.DataExchange:Enqueue(self.prefix,msg,function()
   return F.job==j and j.group==group and group.base==base and p.sid==sid and not p.finished and G.AdminTrust:OwnAllowed()and Online(G.Roster:FindByKey(p.target))
  end,function()p.sentAt=Clock();p.queued=false end,function()p.sentAt=Clock()-3;p.queued=false end)
  if not ok then p.sentAt=Clock()-3;p.queued=false end
  local token=G.OfficerMarks:Token(p.target)
  if ok and token then
   G.DataExchange:Enqueue(self.prefix,"T|"..sid.."|"..token,function()
    return F.job==j and j.group==group and group.base==base and G.AdminTrust:OwnAllowed()
   end)
  end
 end
end
function F:RetryGroup(j)
 local group=j.group;group.retries=group.retries+1
 if group.retries>2 then
  for _,p in ipairs(group.entries)do if not p.finished then p.finished=true;j.failed=j.failed+1;if p.session then self:Close(p.session)end end end
 else self:SurveyGroup(j)end
end
function F:TickJob()
 local j=self.job;if not j then return end
 if j.guild~=G:GetGuildKey()or not G.AdminTrust:OwnAllowed()then self:Stop("permission_or_guild_changed");return end
 if Clock()<j.nextAt or G.DataExchange:Paused()then return end
 if self:ChainValid(self.chain)and self.chain.issuer~=Guid()and self.coordinator and Clock()<(self.leaseUntil or 0)then return end
 if not j.group then
  local entries={}
  while (j.targets[j.index]or(j.deferred and #j.deferred>0))and #entries<5 do
   local guid=j.targets[j.index]
   if guid then j.index=j.index+1 else guid=table.remove(j.deferred,1)end
   if Online(G.Roster:FindByKey(guid))then entries[#entries+1]={target=guid}else j.skipped=j.skipped+1 end
  end
  if #entries==0 then j.finished=Clock();self.lastJob=j;self.job=nil;E.job=nil;return end
  j.group={entries=entries,retries=0};j.groups=j.groups+1;self:SurveyGroup(j);return
 end
 local group=j.group;local all,answered,expired,restart=true,true,false,false
 for _,p in ipairs(group.entries)do if not p.finished then
  if not Online(G.Roster:FindByKey(p.target))then
   p.finished=true;j.skipped=j.skipped+1;restart=true;if p.session then self:Close(p.session)end
  else
   all=false
   if not p.answered then answered=false;if not p.queued and Clock()-p.sentAt>3 then expired=true end end
  end
 end end
 if all then
  local gap=0.02
  for _,p in ipairs(group.entries)do local a=p.session
   if a and a.compactRaid and a.received.X and(a.received.X.total or 0)>=2 then gap=0.28 end
  end
  j.group=nil;j.nextAt=Clock()+gap;return
 end
 if expired then
  for _,p in ipairs(group.entries)do
   if not p.finished and not p.answered and(p.queued or Clock()-p.sentAt<=3)then return end
  end
  -- Re-probe responders in a new bounded group. Silent slots cannot hold their
  -- transfer barrier; retry silent targets separately, at most twice more.
  j.deferred=j.deferred or{};j.missingAttempts=j.missingAttempts or{}
  local responders=0
  for _,p in ipairs(group.entries)do if not p.finished then
   if not p.answered and not p.queued and Clock()-p.sentAt>3 then
    local tries=(j.missingAttempts[p.target]or 0)+1;j.missingAttempts[p.target]=tries
    if tries<3 then j.deferred[#j.deferred+1]=p.target else j.failed=j.failed+1 end
    p.finished=true;if p.session then self:Close(p.session)end
   else responders=responders+1 end
  end end
  if responders>0 then self:SurveyGroup(j)
  else j.group=nil;j.nextAt=Clock()+0.125 end
  return
 end
 if restart then self:RetryGroup(j);return end
 if not answered or self.active then return end
 for _,p in ipairs(group.entries)do if not p.finished and not self:Valid(p.session)then self:RetryGroup(j);return end end
 self:Advance()
end
function F:Probe(msg,sender,member)
 if not G.AdminTrust:Allowed(sender)or not Online(member)then return self:Reject("query_authorization",sender)end
 local sid,target,size,delay,summary=msg:match("^B|([0-9a-f]+)|(Player%-%d+%-%x+)|([1-5])|(%d%d%d%d)|(.*)$")
 local slot=sid and tonumber(sid:sub(16))
 size=tonumber(size)
 if not sid or #sid~=16 or not slot or slot<1 or not size or slot>size or not W.GUID(target)or(delay~="0750"and delay~="1500")then return self:Reject("query_schema",sender)end
 if math.abs(time()-tonumber(sid:sub(1,8),16))>300 then return self:Reject("query_age",sender)end
 if not Online(G.Roster:FindByKey(target))then return self:Reject("target_offline",sender)end
 local known=W.ParseSummary(summary);if not known then return self:Reject("summary_schema",sender)end
 local now=Clock()
 if self.active and self:Valid(self.active)and self.active.issuer~=member.guid then return self:Reject("coordinator_busy",sender)end
 if self.coordinator and self.coordinator~=member.guid and now<(self.leaseUntil or 0)then return self:Reject("coordinator_busy",sender)end
 local root=R:Root();if not root then return self:Reject("storage_capacity",sender)end
 local base=sid:sub(1,15);local slotKey=tostring(slot)
 root.surveySlots=root.surveySlots or{}
 local previous=root.seen[member.guid];local marks=root.surveySlots[member.guid]
 if previous then
  local previousBase=previous:sub(1,15)
  if base<previousBase or(base==previousBase and(not marks or marks.base~=base or marks.slots[slotKey]))then return self:Reject("query_replay",sender)end
 end
 if not previous and Count(root.seen)>=500 then return self:Reject("issuer_capacity",sender)end
 if self.groupKey~=base or self.coordinator~=member.guid or not self.chain then
  if self.active then self:Close(self.active)end
  self.probes={};self.groupKey=base
  self.chain={base=base,issuer=member.guid,sender=sender,guild=G:GetGuildKey(),size=size,slots={},started=now}
 elseif self.chain.size~=size then return self:Reject("group_size_conflict",sender)end
 local c=self.chain
 if c.slots[slot]or Count(self.probes)>=5 then return self:Reject("group_capacity",sender)end
 for _,a in pairs(c.slots)do if a.target==target then return self:Reject("duplicate_target",sender)end end
 if not marks or marks.base~=base then marks={base=base,slots={}};root.surveySlots[member.guid]=marks end
 marks.slots[slotKey]=true;root.seen[member.guid]=previous and previous>sid and previous or sid
 self.coordinator=member.guid;self.leaseUntil=now+5
 local a={sid=sid,slot=slot,issuer=member.guid,sender=sender,target=target,guild=G:GetGuildKey(),known=known,started=now,progress=now,received={},ready={},changed=0,repair=0,packets=0,phase="probe"}
 self.probes[sid]=a;c.slots[slot]=a
 if member.guid==Guid()and self.job and self.job.group then
  for _,p in ipairs(self.job.group.entries)do if p.sid==sid then a.plan=p;p.session=a;break end end
 end
 if target==Guid()then
  local own,why=R:Own();if not own then self:Reject(why,sender);self:Close(a);return false end
  a.own=own
  self:Send("S|"..sid.."|"..W.Summary(own),a,nil,now+tonumber(delay)/1000)
 end
 return true
end
function F:Advance()
 local c=self.chain
 if self.active or not self:ChainValid(c)then return false end
 for i=1,c.size do local a=c.slots[i];if not a or(not a.summarySeen and not a.done)then return false end end
 for i=1,c.size do local a=c.slots[i]
  if not a.done then
   if not self:Valid(a)or not a.transfer then return false end
   self.active=a;E.grant=a;a.phase="data";a.progress=Clock();self.leaseUntil=Clock()+30
   if a.target==Guid()then
    a.frames={};a.repairs={}
    -- Packed owners finish sooner; retain the prior aggregate load envelope.
    local after=Clock()+0.11
    local packed,why=W.Pack(a.own,a.known,a.target)
    if not packed then return self:Reject(why,a.sender)end
    if #packed>0 then
     local rows=W.Parts(a.sid,"X",packed);a.frames.X=rows
     local header=W.PackedHeader(packed,a.own,a.known)
     if #rows>=2 and header.lengths[3]>0 and header.lengths[3]<a.own.R.len then after=after+0.04 end
     local interval=#rows>=3 and 0.15 or 0.125
     for i,p in ipairs(rows)do if not self:Send(p,a,nil,after+(i-1)*interval)then return self:Reject("tx_capacity",a.sender)end end
    end
   end
   if a.issuer==Guid()then self:Complete(a)end
   return true
  end
 end
 self.coordinator=nil;return true
end
function F:ResendAck(a)
 local c=self.chain
 if not a or not a.ackCode or a.issuer~=Guid()or not self:ChainValid(c)or(a.ackSends or 0)>=3 then return false end
 if a.lastAckSent and Clock()-a.lastAckSent<2.5 then return false end
 return G.DataExchange:Enqueue(self.prefix,"A|"..a.sid.."|"..a.ackCode,function()
  return F:ChainValid(c)and G.AdminTrust:OwnAllowed()and F.chain.slots[a.slot]==a and(a.done or a.ackQueued)
 end,function()
  a.ackSends=(a.ackSends or 0)+1;a.lastAckSent=Clock();F.metrics.ackResends=(F.metrics.ackResends or 0)+1
 end)
end
function F:Complete(a)
 if not a.meta or a.ackQueued then return end
 local all,complete=true,true
 for _,cat in ipairs(W.categories)do if a.meta[cat]then if not a.ready[cat]then all=false end else complete=false end end
 if not all then return end
 local batch=G.RaidRuntime and G.RaidRuntime.batch
 if batch and batch.expected and batch.expected[a.target]and a.meta.R and a.ready.R then batch.got[a.target]=true end
 local code=complete and"OK"or"NA"
 -- Verified summary is sufficient when no body transfer is needed.
 if a.phase=="probe"then if not a.transfer then self:Finish(code,a)end;return end
 if a.issuer~=Guid()then return end -- Passive receivers never ACK or advance the issuer.
 a.ackQueued=true;a.ackCode=code
 if not self:Send("A|"..a.sid.."|"..code,a,function()
  a.ackSends=(a.ackSends or 0)+1;a.lastAckSent=Clock()
  if F.active==a then F:Finish(code,a)end
 end)then a.ackQueued=nil end
end
function F:Summary(summary,a)
 if a.meta then return self:Reject("duplicate_summary",a.sender)end
 local meta=W.ParseSummary(summary);if not meta then return self:Reject("summary_schema",a.sender)end
 a.meta=meta
 local peer=G.Roster:FindByKey(a.target)
 for _,cat in ipairs(W.categories)do local r=meta[cat]
  if r then
   if W.Same(r,a.known[cat])then
    a.ready[cat]=true
    R:ConfirmDirect(peer,cat,r)
    if a.issuer~=Guid()and not W.Same(r,R:Known(peer)[cat])and G.CacheSync then G.CacheSync:Want("missing_live_body")end
   elseif r.len==0 then
    local ok,why=R:Apply(peer,cat,"",r);if not ok then return self:Reject(why,peer.name)end
    a.ready[cat]=true;a.changed=a.changed+1
   else a.bodyBytes=(a.bodyBytes or 0)+r.len end
  end
 end
 if a.bodyBytes then a.received.X={parts={},count=0,bytes=0,maxBytes=a.bodyBytes+17,maxTotal=math.ceil((a.bodyBytes+17)/W.chunk)}end
 if a.plan then a.plan.answered=true end
 a.summarySeen=true;self:Complete(a)
 if G.RefreshLinkedMemberCard then G:RefreshLinkedMemberCard()end
 return true
end
function F:Data(msg,a,sender)
 local sid,seq,total,body=msg:match("^D|([0-9a-f]+)|X|(%d%d)|(%d%d)|(.*)$")
 if sid~=a.sid or not a.meta then return self:Reject("data_session",sender)end
 local p=a.received.X;seq,total=tonumber(seq),tonumber(total)
 if not p or not total or total<1 or total>p.maxTotal or not seq or seq<1 or seq>total or #body<1 or #body>W.chunk or(seq<total and #body~=W.chunk)then return self:Reject("fragment_bounds",sender)end
 if p.total and p.total~=total then return self:Reject("fragment_conflict",sender)end
 if p.parts[seq]then if p.parts[seq]~=body then return self:Reject("fragment_conflict",sender)end;return true end
 if seq==1 then
  local h,why=W.PackedHeader(body,a.meta,a.known);if not h then return self:Reject(why,sender)end
  if math.ceil(h.bytes/W.chunk)~=total or h.bytes>p.maxBytes then return self:Reject("fragment_length",sender)end
  p.length=h.bytes
  a.compactRaid=h.lengths[3]>0 and h.lengths[3]<a.meta.R.len
 end
 local want=p.length and(seq<total and W.chunk or p.length-(total-1)*W.chunk)
 if want and #body~=want then return self:Reject("fragment_length",sender)end
 -- Before part one, the last fragment remains bounded but has no exact length.
 p.total=total;p.parts[seq]=body;p.count=p.count+1;p.bytes=p.bytes+#body
 if p.bytes>p.maxBytes then return self:Reject("fragment_bounds",sender)end
 if p.count==total then
  local raw=table.concat(p.parts);local peer=G.Roster:FindByKey(a.target)
  local rows,why=W.Unpack(raw,a.meta,a.known,a.target);if not rows then return self:Reject(why,sender)end
  -- Preflight every included section before mutating any native store.
  for _,cat in ipairs(W.categories)do if rows[cat]then
   local decoded,reason=R:Decode(cat,rows[cat],peer,a.meta[cat]);if not decoded then return self:Reject(reason,sender)end
  end end
  for _,cat in ipairs(W.categories)do if rows[cat]then
   local ok,reason=R:Apply(peer,cat,rows[cat],a.meta[cat]);if not ok then return self:Reject(reason,sender)end
   a.ready[cat]=true;a.changed=a.changed+1;self.metrics.accepted=self.metrics.accepted+1;self.metrics.changed=self.metrics.changed+1
   if G.SpamShield then G.SpamShield:Accepted(sender,cat)end
  end end
  a.ready.X=true;self:Complete(a)
  if G.RefreshLinkedMemberCard then G:RefreshLinkedMemberCard()end
 end
 return true
end

function F:Repair(msg,a,sender)
 local sid,cat,raw=msg:match("^N|([0-9a-f]+)|(X)|([%d,]+)$")
 if sid~=a.sid or not a.frames or not a.frames[cat]then return self:Reject("repair_session",sender)end
 local rows=W.Split(raw,",");if #rows<1 or #rows>14 then return self:Reject("repair_size",sender)end
 a.repairs[cat]=(a.repairs[cat]or 0)+1;if a.repairs[cat]>2 then return self:Reject("repair_budget",sender)end
 local seen={}
 for _,s in ipairs(rows)do local seq=W.Int(s,1,#a.frames[cat]);if not seq or seen[seq]then return self:Reject("repair_schema",sender)end;seen[seq]=true end
 for _,s in ipairs(rows)do if not self:Send(a.frames[cat][tonumber(s)],a)then return self:Reject("tx_capacity",sender)end end
 return true
end
function F:Admit(msg,sender,channel,minLength)
 if channel~="GUILD"then return false,"route"end
 if G.ManualBans and G.ManualBans:BlockedSender(sender)then return false,"manual_ban"end
 local now=Clock()
 -- Cheap O(1) native roster index gates a known sender before the shared
 -- CPU budget. Excess traffic from one member cannot spend everybody's quota.
 -- Unknown/stale identities still hit the global cap before a roster scan.
 local T=G.AdminTrust;local name=type(sender)=='string'and #sender<=128 and G.TrustBoundary:CanonicalName(sender)
 local indexed=T and T.key==G:GetGuildKey()and T.refreshed and now-T.refreshed<=120 and T.members and name and T.members[name]
 local gated
 if indexed and W.GUID(indexed.guid)then
  local rate=self.rates[indexed.guid]
  if not rate or now-rate.at>=10 or now<rate.at then
   if not rate and Count(self.rates)>=500 then return self:BudgetDrop('sender_capacity')end
   rate={at=now,n=0};self.rates[indexed.guid]=rate
  end
  rate.n=rate.n+1;if rate.n>80 then return self:BudgetDrop('sender_budget')end
  gated=indexed.guid
 end
 if not self.globalAt or now-self.globalAt>=1 then self.globalAt=now;self.globalCount=0 end
 self.globalCount=self.globalCount+1;if self.globalCount>200 then return self:BudgetDrop("work_budget")end
 if type(msg)~="string"or #msg>220 or #msg<(minLength or 19) or msg:find("[%z\1-\31\127]")then return self:Reject("wire_size_schema",sender)end
 local member=G.Roster:FindBySender(sender)
 if not member or not W.GUID(member.guid)then return self:Reject("sender_identity",sender)end
 if gated==member.guid then return member end
 local rate=self.rates[member.guid]
 if not rate or now-rate.at>=10 then
  if not rate and Count(self.rates)>=500 then return false,"sender_capacity"end
  rate={at=now,n=0};self.rates[member.guid]=rate
 end
 rate.n=rate.n+1;if rate.n>80 then return self:BudgetDrop("sender_budget")end
 return member
end
function F:Receive(msg,sender,channel)
 local member,why=self:Admit(msg,sender,channel)
 if not member then return false,why end
 local now=Clock()
 if msg:sub(1,2)=="B|"then return self:Probe(msg,sender,member)end
 local sid=msg:sub(3,18);local kind=msg:sub(1,1)
 if msg:sub(1,2)~=kind.."|"or msg:sub(19,19)~="|"then return self:Reject("command",sender)end
 if kind~="S"and kind~="D"and kind~="A"and kind~="N"and kind~="T"then return self:Reject("command",sender)end
 local c=self.chain;local slot=tonumber(sid:sub(16));local a=c and slot and c.slots[slot]
 if a and a.sid~=sid then a=nil end
 if kind=="T"then
  if not self:Valid(a)or member.guid~=a.issuer then return self:Reject("mark_issuer",sender)end
  a.packets=(a.packets or 0)+1;if a.packets>64 then return self:BudgetDrop("session_budget")end
  if a.markSeen then return self:Reject("duplicate_mark",sender)end;a.markSeen=true
  local ok=G.OfficerMarks:ApplyToken(a.target,msg:sub(20),a.issuer)
  if ok and G.CacheSync then G.CacheSync:Want("officer_marks")end
  return ok
 end
 if kind=="A"and a then
  local code=msg:sub(20)
  if code~="OK"and code~="NA"then return self:Reject("ack_schema",sender)end
  if member.guid~=a.issuer or not self:ChainValid(c)then return self:Reject("issuer_identity",sender)end
  a.packets=(a.packets or 0)+1;if a.packets>64 then return self:BudgetDrop("session_budget")end
  if a.done then
   if a.ackCode and a.ackCode~=code then return self:Reject("ack_conflict",sender)end
   a.ackCode=code;self:Advance();return true
  end
  if a.issuer==Guid()then
   if self.active~=a or not a.ackQueued then return self:Reject("ack_before_apply",sender)end
   a.ackCode=code;self:Finish(code,a);return true
  end
  -- The actual issuer could only ACK slot k after its predecessors. A later
  -- issuer ACK therefore repairs a lost predecessor ACK for scheduling only.
  -- Observers never apply or invent character records from this watermark.
  for i=1,a.slot do if not c.slots[i]then return self:Reject("ack_unknown_predecessor",sender)end end
  for i=1,a.slot do local p=c.slots[i]
   if not p.done then p.done=true;p.advancedBy=a.slot;if i==a.slot then p.ackCode=code end;self:Close(p)end
  end
  self:Advance();return true
 end
 if not self:Valid(a)then
  local r=self.recent[sid]
  if kind=="S"and r and now-r.at<10 and r.guild==G:GetGuildKey()and r.target==member.guid then
   if W.ParseSummary(msg:sub(20))then return true end
   return self:Reject("summary_schema",sender)
  end
  return self:Reject("no_active_trusted_session",sender)
 end
 if(kind=="S"or kind=="D")and member.guid~=a.target then return self:Reject("owner_identity",sender)end
 if(kind=="A"or kind=="N")and member.guid~=a.issuer then return self:Reject("issuer_identity",sender)end
 a.packets=a.packets+1;if a.packets>64 then return false,"session_budget"end
 if kind=="S"then
  if a.phase~="probe"or a.summarySeen then return self:Reject("summary_phase",sender)end
  local meta=W.ParseSummary(msg:sub(20));if not meta then return self:Reject("summary_schema",sender)end
  local same=true;for _,cat in ipairs(W.categories)do if not W.Same(meta[cat],a.known[cat])then same=false end end
  a.transfer=not same;a.progress=now
  local ok,why=self:Summary(msg:sub(20),a);if not ok then return ok,why end
  if G.MythicAnalytics then G.MythicAnalytics:ConfirmOwner(member.guid)end
  self:Advance();return true
 end
 if self.active~=a or a.phase~="data"then return self:Reject("data_before_turn",sender)end
 a.progress=now
 if kind=="N"then if a.target~=Guid()then return true end;return self:Repair(msg,a,sender)end
 a.sawData=true
 return self:Data(msg,a,sender)
end
function F:Tick()
 if G.DataExchange:Paused()then return end
 local a=self.active
 if a then
  if not self:Valid(a)then self:Close(a)
  elseif Clock()-a.progress>(a.target==Guid()and a.issuer~=Guid()and 10 or 3)then
   if a.issuer==Guid()and a.meta and a.repair<2 then
    a.repair=a.repair+1;a.progress=Clock()
    if a.ackQueued then
     if not self:ResendAck(a)then self:Close(a)end
    elseif not a.sawData then
     local previous
     for i=a.slot-1,1,-1 do local p=self.chain.slots[i];if p and p.done and p.ackCode then previous=p;break end end
     if not self:ResendAck(previous)then self:Close(a)end
    else
     for _,cat in ipairs({"X"})do local p=a.received[cat]
      if p and p.total and not a.ready[cat]then
       local missing={};for i=1,p.total do if not p.parts[i]then missing[#missing+1]=string.format("%02d",i)end end
       if #missing>0 then self:Send("N|"..a.sid.."|"..cat.."|"..table.concat(missing,","),a)end
      end
     end
    end
   else self.metrics.timeouts=self.metrics.timeouts+1;self:Close(a)end
  end
 end
 self:TickJob()
 if not self.pruned or Clock()-self.pruned>1 then
  self.pruned=Clock()
  for sid,p in pairs(self.probes)do if not self:Valid(p)then self:Close(p)end end
  for guid,r in pairs(self.rates)do if Clock()-r.at>10 then self.rates[guid]=nil end end
  for sid,r in pairs(self.recent)do if Clock()-r.at>10 then self.recent[sid]=nil end end
  if self.chain and Clock()-self.chain.started>30 then self.chain=nil;self.coordinator=nil end
 end
end
function E:Reject(reason,sender)return F:Reject(reason,sender)end
function E:Valid(a)return F:Valid(a)end
function E:Clear()F:Stop("cleared")end
function E:Request(target)return F:Request(target)end
function E:Send()return false,"legacy_transport_disabled"end
function E:Receive(_,sender,channel)if channel~="GUILD"then return false,"route"end;return F:Reject("legacy_transport_disabled",sender)end
function G:InitializeSecureExchange()
 if F.frame then return end
 RegisterAddonMessagePrefix(W.prefix)
 local f=CreateFrame("Frame");F.frame=f;E.frame=f;f:RegisterEvent("CHAT_MSG_ADDON")
 f:SetScript("OnEvent",function(_,_,prefix,msg,ch,sender)
  if prefix~=W.prefix or ch~="GUILD"then return end
  local start=debugprofilestop and debugprofilestop()
  if not G.SpamShield or not G.SpamShield:IsBlocked(sender)then F:Receive(msg,sender,ch)end
  if G.SpamShield then G.SpamShield:SecureTiming(start)end
 end)
 local elapsed=0;f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+(dt or 0);if elapsed<0.05 then return end;elapsed=0;F:Tick()end)
end
function G:SecurityStatus()
 local j=F.job or F.lastJob
 self:Print("NET7 accepted="..F.metrics.accepted.." rejected="..F.metrics.rejected.." sent="..F.metrics.sent.." queued="..#self.DataExchange.queue)
 if j then self:Print((G:Text("Сверка "))..j.completed.."/"..#j.targets..(G:Text(" без изменений="))..j.unchanged..(G:Text(" разделов обновлено="))..j.changed..(G:Text(" неполных="))..j.partial..(G:Text(" пропущено="))..j.skipped..(G:Text(" без ответа="))..j.failed)end
 self:Print((G:Text("Причина="))..tostring(E.lastReason)..(G:Text(" отправитель="))..tostring(E.lastSender)..(G:Text("; журнал /gc735 netlog")))
end
