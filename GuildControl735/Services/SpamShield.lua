-- Local, opt-out inbound anti-spam guard. This does NOT alter guild rights,
-- payload validity, secure-session authorization, or server-side traffic.
local _,GC=...
local S={prefixes={GC735VER=true,GC735C42=true,GC735N28=true,GC735NET=true,GC735SEC=true,GC735SAT=true,GC735LIST=true,GC735RAID=true,GC735FAM=true,GC735TRUST=true},
         windows={},lastGuild=nil,maxSenders=400,maxEvents=300}
GC.SpamShield=S
-- Derive active transports from their owners; legacy routes remain observable.
function S:IsPrefix(prefix)
 return self.prefixes[prefix]or(GC.FastWire and prefix==GC.FastWire.prefix)or(GC.CacheSync and prefix==GC.CacheSync.prefix)or(GC.ManualBans and prefix==GC.ManualBans.prefix)
end
function S:IsBulkPrefix(prefix)
 return prefix=='GC735C42'or prefix=='GC735NET'or prefix=='GC735N28'or(GC.FastWire and prefix==GC.FastWire.prefix)or(GC.CacheSync and prefix==GC.CacheSync.prefix)
end
local function Clock()return GetTime and GetTime()or 0 end
local function Epoch()return time and time()or 0 end
local function Safe(v,max)
 local s=tostring(v or ""):gsub("[%c]"," ")
 if #s>max then return s:sub(1,max)end
 return s
end
local function Size(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
function S:Root()
 if not GC.db then return nil end
 local r=GC.db.networkSpam
 if type(r)~="table"then r={enabled=true,guilds={},runs={}};GC.db.networkSpam=r end
 if type(r.enabled)~="boolean"then r.enabled=true end
 if type(r.guilds)~="table"then r.guilds={}end
 if type(r.runs)~="table"then r.runs={}end
 return r
end
function S:Guild()
 local key=self.lastGuild
 if key==nil then key=GC:GetGuildKey();self.lastGuild=key end
 if not key then return nil end
 local root=self:Root();if not root then return nil end
 local guild=root.guilds[key]
 if not guild then
  if Size(root.guilds)>=10 then return nil end
  guild={senders={},events={}};root.guilds[key]=guild
 end
 if type(guild.senders)~="table"then guild.senders={}end
 if type(guild.events)~="table"then guild.events={}end
 if guild.recoverySchema~=2 then
  for _,r in pairs(guild.senders)do if type(r.blockUntil)=="number"and r.blockUntil>Epoch()+300 then r.blockUntil=Epoch()+300 end end
  guild.recoverySchema=2
 end
 return guild
end
local reasonText=GC:RegisterLocaleTable({},function()return {excess_queries_2s=(GC:Text("Слишком частые запросы")),excess_queries_10s=(GC:Text("Слишком частые запросы")),excess_packets_2s=(GC:Text("Слишком частые сообщения")),excess_packets_10s=(GC:Text("Слишком частые сообщения"))} end)
function S:Reason(reason)return reasonText[reason]or(GC:Text("Превышена допустимая частота обмена"))end
function S:Recent(r,seconds)
 local keep={};local now=Epoch();local n=0;seconds=seconds or 86400
 for _,at in ipairs(r.incidentTimes or{})do if type(at)=="number"and at<=now and now-at<864000 then keep[#keep+1]=at;if now-at<seconds then n=n+1 end end end
 r.incidentTimes=keep;return n
end
function S:Incident(rec,reason)
 local now=Epoch();self:Recent(rec)
 if not rec.lastIncidentAt or now<rec.lastIncidentAt or now-rec.lastIncidentAt>=1800 then rec.incidents=0 end
 rec.incidents=math.min(3,(tonumber(rec.incidents)or 0)+1)
 local duration=({60,120,300})[rec.incidents]
 rec.blockUntil=now+duration;rec.lastReason=reason;rec.lastIncidentAt=now;rec.unread=true
 rec.incidentTimes[#rec.incidentTimes+1]=now
 while #rec.incidentTimes>4096 do table.remove(rec.incidentTimes,1)end
 if GC.AdminTrust and GC.AdminTrust:OwnAllowed()and(not self.lastNotice or now<self.lastNotice or now-self.lastNotice>=60)then
  self.lastNotice=now
  local text=(GC:Text("──────── Guild Control ────────\nОбмен с "))..rec.name..(GC:Text(" ограничен на "))..duration..(GC:Text(" сек. "))..self:Reason(reason)..(GC:Text(". Восстановление автоматическое.\nПодробности: вкладка «Сетевая защита»."))
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text,.25,.8,1)end
 end
 if GC.RefreshNetworkBadge then GC:RefreshNetworkBadge()end
 return duration
end
function S:Rows(showAll)
 local guild=self:Guild();local out,seen,guids={},{},{};if not guild then return out end
 local now=Epoch()
 for _,m in ipairs(GC.Roster and GC.Roster.members or{})do
  local key=type(m.name)=="string"and m.name:lower();local r=key and guild.senders[key]
  if r and r.guid and r.guid~=""and r.guid~=m.guid then r=nil end
  local count=r and self:Recent(r)or 0;local ten=r and self:Recent(r,864000)or 0;local manual=GC.ManualBans and GC.ManualBans:Get(m.guid)
  local banned=manual and manual.untilAt>now or false;local blocked=banned or r and self:Enabled()and(r.blockUntil or 0)>now or false
  if showAll or blocked or ten>0 or manual and manual.total>0 or r and r.unread then
   out[#out+1]={member=m,record=r,count=count,ten=ten,manual=manual,blocked=not not blocked,state=banned and(GC:Text("Ручной бан"))or(blocked and(GC:Text("Временно ограничен"))or(ten>0 and(GC:Text("Обмен восстановлен"))or(GC:Text("Без ограничений"))))}
  end
  if key then seen[key]=true end;if m.guid then guids[m.guid]=true end
 end
 -- Local evidence survives departure; historical rows never authorize anyone.
 for key,r in pairs(guild.senders)do if not seen[key]then
  if r.guid then guids[r.guid]=true end
  local count=self:Recent(r);local ten=self:Recent(r,864000);local manual=GC.ManualBans and GC.ManualBans:Get(r.guid);local banned=manual and manual.untilAt>now or false;local blocked=banned or self:Enabled()and(r.blockUntil or 0)>now
  if ten>0 or blocked or r.unread or manual and manual.total>0 then out[#out+1]={member={name=r.name,guid=r.guid},record=r,count=count,ten=ten,manual=manual,blocked=blocked,state=banned and(GC:Text("Ручной бан"))or(blocked and(GC:Text("Временно ограничен"))or(GC:Text("Обмен восстановлен")))}end
 end end
 local policy=GC.ManualBans and GC.ManualBans:Root()
 for guid,entry in pairs(policy and policy.confirmed and policy.entries or{})do if not guids[guid]then
  local banned=entry.untilAt>now
  out[#out+1]={member={name=entry.name or guid,guid=guid},count=0,ten=0,manual=entry,blocked=banned,state=banned and(GC:Text("Ручной бан"))or(GC:Text("Обмен восстановлен"))}
 end end
 table.sort(out,function(a,b)if a.blocked~=b.blocked then return a.blocked end;if a.count~=b.count then return a.count>b.count end;return a.member.name<b.member.name end)
 return out
end
function S:Unread()
 if not GC.AdminTrust or not GC.AdminTrust:OwnAllowed()then return false end
 local guild=self:Guild();for _,r in pairs(guild and guild.senders or{})do if r.unread then return true end end
 return false
end
function S:Read()
 local guild=self:Guild();for _,r in pairs(guild and guild.senders or{})do r.unread=nil end
 if GC.RefreshNetworkBadge then GC:RefreshNetworkBadge()end
end
function S:Observer()
 local guid=UnitGUID and UnitGUID("player")or ""
 local member=GC.Roster and GC.Roster.FindByKey and GC.Roster:FindByKey(guid)
 local name=member and member.name or UnitName and UnitName("player")or (GC:Text("неизвестно"))
 return Safe(name,80),Safe(guid,80)
end
function S:Audit(kind,sender,guid,prefix,reason,value,untilAt)
 local guild=self:Guild();if not guild then return end
 local name,observerGUID=self:Observer()
 local e={at=Epoch(),kind=Safe(kind,32),observer=name,observerGUID=observerGUID,
          build=GC.build,version=GC.version,sender=Safe(sender,80),senderGUID=Safe(guid,80),prefix=Safe(prefix,20),
          reason=Safe(reason,80),count=tonumber(value)or 0,blockUntil=tonumber(untilAt)or 0,mode=self:Enabled()}
 guild.events[#guild.events+1]=e
 while #guild.events>self.maxEvents do table.remove(guild.events,1)end
end
function S:Actor(sender)
 if type(sender)~="string"or #sender==0 or #sender>80 then return nil end
 local guild=self:Guild();if not guild then return nil end
 local key=string.lower(sender)
 local rec=guild.senders[key]
 if not rec then
  if Size(guild.senders)>=self.maxSenders then return nil end
  local m=GC.Roster and GC.Roster.FindBySender and GC.Roster:FindBySender(sender)
  rec={name=Safe(sender,80),guid=m and Safe(m.guid,80)or "",total=0,blocked=0,
       rejected=0,incidents=0,lastSeen=0,lastReason="",blockUntil=0,queryCount=0,dataCount=0,peak2=0,peak10=0,accepted=0,prefixCounts={},reasonCounts={}}
  guild.senders[key]=rec
  local mine=UnitGUID and UnitGUID("player")
  self.windows[key]={own=mine and m and m.guid==mine or false}
 elseif not self.windows[key] then
  local m=GC.Roster and GC.Roster.FindBySender and GC.Roster:FindBySender(sender)
  self.windows[key]={own=UnitGUID and m and m.guid==UnitGUID("player")or false}
  if m and m.guid then rec.guid=Safe(m.guid,80)end
 end
 return rec,self.windows[key]
end
function S:StartRun(reason)
 local root=self:Root();if not root then return end
 if self.run then
  local old=self.run;old.ended=Epoch();old.endReason=reason
  root.runs[#root.runs+1]=old
  while #root.runs>12 do table.remove(root.runs,1)end
 end
 local name,guid=self:Observer()
 self.run={start=Epoch(),enabled=root.enabled,observer=name,observerGUID=guid,
           version=GC.version,build=GC.build,rxBytes=0,tx=0,txBytes=0,rxPrefixes={},txPrefixes={},actors={},
           received=0,denied=0,rejected=0,potentialBlocks=0,
           fpsSamples=0,fpsSum=0,fpsMin=0,frameGapMaxMs=0,shieldCpuMs=0,shieldCpuMaxMs=0,
           secureCpuMs=0,secureCpuMaxMs=0,secureCalls=0}
 self.fpsElapsed=0
end
function S:Enabled()local root=self:Root();return root and root.enabled~=false end
function S:SetEnabled(value)
 local root=self:Root();if not root then return end
 value=not not value
 if root.enabled==value then return end
 self:StartRun(value and "enabled"or"disabled")
 root.enabled=value
 self.windows={} -- comparable independent rate windows for ON/OFF measurements
 -- Record the final mode in the newly started measurement; the old run retains its mode.
 self.run.enabled=value
 self:Audit("MODE",nil,nil,nil,value and "enabled"or"disabled")
end
function S:ResetMeasurement()
 self:StartRun("new_measurement")
 self:Audit("MEASURE_START",nil,nil,nil,self:Enabled()and "enabled"or"disabled")
end
function S:IsBlocked(sender)
 if GC.ManualBans and GC.ManualBans:BlockedSender(sender)then return true end
 if not self:Enabled()then return false end
 local g=self:Guild();if not g or type(sender)~="string"then return false end
 local r=g.senders[string.lower(sender)];if not r then return false end
 local w=self.windows[string.lower(sender)]
 if w and w.own then return false end
 return type(r.blockUntil)=="number"and r.blockUntil>Epoch()
end
function S:Reject(sender,reason,prefix)
 local rec=self:Actor(sender)
 if rec then
  rec.rejected=(tonumber(rec.rejected)or 0)+1
  local code=Safe(reason,80)
  rec.lastReason=code
  rec.reasonCounts=rec.reasonCounts or {}
  if rec.reasonCounts[code]or Size(rec.reasonCounts)<24 then
   rec.reasonCounts[code]=(rec.reasonCounts[code]or 0)+1
  else rec.reasonCounts.other=(rec.reasonCounts.other or 0)+1 end
 end
 if self.run then self.run.rejected=self.run.rejected+1;local a=type(sender)=="string"and self.run.actors[string.lower(sender)];if a then a.rejected=a.rejected+1;a.lastReason=Safe(reason,80)end end
end
function S:Accepted(sender,prefix)
 local r=self:Actor(sender)
 if r then r.accepted=(r.accepted or 0)+1 end
end
function S:Observe(prefix,msg,channel,sender)
 if channel~="GUILD"or not self:IsPrefix(prefix)then return end
 local bytes=type(msg)=="string"and #msg or 0
 if self.run then self.run.received=self.run.received+1;self.run.rxBytes=self.run.rxBytes+bytes;self.run.rxPrefixes[prefix]=(self.run.rxPrefixes[prefix]or 0)+1 end
 if self.run and prefix=="GC735N28"then self:Kind(self.run,"rxKinds",msg)end
 local rec,w=self:Actor(sender);if not rec then return end
 rec.rxBytes=(rec.rxBytes or 0)+bytes
 rec.prefixBytes=rec.prefixBytes or{};rec.prefixBytes[prefix]=(rec.prefixBytes[prefix]or 0)+bytes
 local run=self.run
 if run then
  local key=string.lower(sender);local actor=run.actors[key]
  if not actor then actor={first=Epoch(),last=Epoch(),rx=0,bytes=0,rejected=0,prefixes={}};run.actors[key]=actor end
  actor.last=Epoch();actor.rx=actor.rx+1;actor.bytes=actor.bytes+bytes;actor.prefixes[prefix]=(actor.prefixes[prefix]or 0)+1
 end

 local now=Clock();local epoch=Epoch()
 rec.total=(tonumber(rec.total)or 0)+1;rec.lastSeen=epoch
 rec.prefixCounts=rec.prefixCounts or {}
 rec.prefixCounts[prefix]=(rec.prefixCounts[prefix]or 0)+1
 local kind=((prefix=="GC735SEC"or self:IsBulkPrefix(prefix))and type(msg)=="string"and (msg:sub(1,2)=="Q|"or msg:sub(1,2)=="B|"))and"query"or"data"
 if kind=="query"then rec.queryCount=(rec.queryCount or 0)+1 else rec.dataCount=(rec.dataCount or 0)+1 end
 if not w.start2 or now<w.start2 or now-w.start2>=2 then w.start2=now;w.n2=0;w.q2=0;w.warned2=false end
 if not w.start10 or now<w.start10 or now-w.start10>=10 then w.start10=now;w.n10=0;w.q10=0;w.warned10=false end
 w.n2=w.n2+1;w.n10=w.n10+1
 if kind=="query"then w.q2=w.q2+1;w.q10=w.q10+1 end
 rec.peak2=math.max(rec.peak2 or 0,w.n2)
 rec.peak10=math.max(rec.peak10 or 0,w.n10)
 if w.own then return end -- own server echo is not a hostile sender
 if self:Enabled()and rec.blockUntil and epoch<rec.blockUntil then
  rec.blocked=(rec.blocked or 0)+1
  if self.run then self.run.denied=self.run.denied+1 end
  return
 end
 -- All limits are per sender. SEC data fragments use higher budgets than queries.
 local q2,q10=self:IsBulkPrefix(prefix)and 16 or 8,self:IsBulkPrefix(prefix)and 64 or 20
 local exceed=(w.q2>q2 or w.q10>q10 or w.n2>80 or w.n10>160)
 if not exceed then return end
 if (w.warned2 and now-w.start2<2)or(w.warned10 and now-w.start10<10)then return end
 w.warned2=true;w.warned10=true
 local reason=w.q2>q2 and "excess_queries_2s"or w.q10>q10 and "excess_queries_10s"or w.n2>80 and "excess_packets_2s"or"excess_packets_10s"
 if not self:Enabled()then
  if self.run then self.run.potentialBlocks=self.run.potentialBlocks+1 end
  self:Audit("WOULD_BLOCK",sender,rec.guid,prefix,reason,w.n2,0)
  return
 end
 self:Incident(rec,reason);rec.blocked=(rec.blocked or 0)+1
 if self.run then self.run.denied=self.run.denied+1 end
 self:Audit("BLOCK",sender,rec.guid,prefix,reason,w.n2,rec.blockUntil)
end
function S:SecureTiming(started)
 if not self.run or not started or not debugprofilestop then return end
 local delta=debugprofilestop()-started
 if delta>=0 and delta<100000 then
  self.run.secureCpuMs=self.run.secureCpuMs+delta
  self.run.secureCpuMaxMs=math.max(self.run.secureCpuMaxMs,delta)
  self.run.secureCalls=self.run.secureCalls+1
 end
end
function S:Unblock(sender)
 if not GC.AdminTrust or not GC.AdminTrust:IsLeader()then return false end
 local r=self:Actor(sender);if not r then return false end
 r.blockUntil=0;r.incidents=0
 self:Audit("UNBLOCK",sender,r.guid,nil,"manual")
 return true
end
local function ReadableKey(v)return Safe(v,100)end
function S:Kind(run,key,msg)
 local kind=type(msg)=="string"and msg:sub(1,1)or"other"
 if kind~="B"and kind~="S"and kind~="D"and kind~="A"and kind~="N"then kind="other"end
 run[key]=run[key]or{};run[key][kind]=(run[key][kind]or 0)+1
end
function S:TX(prefix,bytes,msg)
 local r=self.run;if not r then return end
 r.tx=r.tx+1;r.txBytes=r.txBytes+bytes;r.txPrefixes[prefix]=(r.txPrefixes[prefix]or 0)+1
 if prefix=="GC735N28"then self:Kind(r,"txKinds",msg)end
end
function S:Text()
 local root=self:Root();if not root then return "No SavedVariables" end
 local name,guid=self:Observer();local run=self.run or{}
 local secs=math.max(1,Epoch()-(run.start or Epoch()))
 local fps=run.fpsSamples and run.fpsSamples>0 and run.fpsSum/run.fpsSamples or 0
 local rows={(GC:Text("Guild Control — Сетевая безопасность")), (GC:Text("Version "))..GC.version.." / "..GC.build,
  (GC:Text("Observer "))..name.." / "..guid,(GC:Text("Guild "))..ReadableKey(self.lastGuild),
  (GC:Text("Protection "))..(root.enabled and "ON"or"OFF")..(GC:Text("; base GUID/session/payload checks ALWAYS ON")),
  string.format((GC:Text("MEASURE %s %ds received=%d denied=%d rejected=%d wouldBlock=%d")),run.enabled and"ON"or"OFF",secs,run.received or 0,run.denied or 0,run.rejected or 0,run.potentialBlocks or 0),
  string.format((GC:Text("FPS avg=%.1f min=%.1f samples=%d maxFrameGapMs=%.1f")),fps,run.fpsMin or 0,run.fpsSamples or 0,run.frameGapMaxMs or 0),
  string.format((GC:Text("SecureExchange handler CPU sample: calls=%d totalMs=%.2f maxMs=%.2f (not total WoW CPU)")),run.secureCalls or 0,run.secureCpuMs or 0,run.secureCpuMaxMs or 0),
  string.format((GC:Text("RX payloadBytes=%d TX API-accepted=%d payloadBytes=%d (not delivery ACK)")),run.rxBytes or 0,run.tx or 0,run.txBytes or 0),
  (GC:Text("Packet TX on Trojan is not proof of receiver delivery. Frame gap can be caused by other addons or window focus.")),(GC:Text("--- SENDERS ---"))}
 local f=GC.FastSync;local j=f and(f.job or f.lastJob);local x=GC.DataExchange
 if f then rows[#rows+1]=string.format((GC:Text("NET7 hard drops: work=%d sender=%d session=%d")),f.metrics.work_budget or 0,f.metrics.sender_budget or 0,f.metrics.session_budget or 0)end
 if f then rows[#rows+1]=string.format((GC:Text("ACK chain: C retired; repeated A since load=%d")),f.metrics.ackResends or 0)end
 for _,key in ipairs({"rxKinds","txKinds"})do
  local kinds=run[key]or{};rows[#rows+1]=string.format((GC:Text("NET7 %s B=%d S=%d D=%d A=%d N=%d other=%d")),key,kinds.B or 0,kinds.S or 0,kinds.D or 0,kinds.A or 0,kinds.N or 0,kinds.other or 0)
 end
 if run.reasonCounts then rows[#rows+1]=string.format((GC:Text("Interval hard drops: work=%d sender=%d session=%d")),run.reasonCounts.work_budget or 0,run.reasonCounts.sender_budget or 0,run.reasonCounts.session_budget or 0)end
 if j then rows[#rows+1]=string.format((GC:Text("Collection: completed=%d unchanged=%d changedSections=%d partial=%d skipped=%d failed=%d targets=%d")),j.completed,j.unchanged,j.changed,j.partial,j.skipped,j.failed,#j.targets)end
 if j then rows[#rows+1]=string.format((GC:Text("Survey groups=%d maximumGroupSize=5; unchanged uses B/S only")),j.groups or 0)end
 if x then rows[#rows+1]=string.format((GC:Text("Queue: pending=%d estimatedTXbytes=%d otherObservedBytes=%d dropped=%d")),#x.queue,x.metrics.bytes,x.metrics.otherBytes,x.metrics.dropped)end
 rows[#rows+1]=(GC:Text("--- CURRENT INTERVAL ACTORS (RX event counts, payload bytes) ---"))
 for sender,a in pairs(run.actors or{})do rows[#rows+1]=string.format((GC:Text("%s first=%d last=%d RX=%d bytes=%d reject=%d reason=%s")),Safe(sender,80),a.first,a.last,a.rx,a.bytes,a.rejected,Safe(a.lastReason,80))end
 local g=self:Guild()
 if g then
  local senderRows={}
  for _,r in pairs(g.senders)do senderRows[#senderRows+1]=r end
  table.sort(senderRows,function(a,b)return(a.total or 0)>(b.total or 0)end)
  for i=1,math.min(#senderRows,60)do
   local r=senderRows[i]
   rows[#rows+1]=string.format((GC:Text("%s [%s] total=%d query=%d data=%d accepted=%d reject=%d earlyBlocked=%d peak2=%d peak10=%d strikes=%d until=%s last=%s")),Safe(r.name,70),Safe(r.guid,45),r.total or 0,r.queryCount or 0,r.dataCount or 0,r.accepted or 0,r.rejected or 0,r.blocked or 0,r.peak2 or 0,r.peak10 or 0,r.incidents or 0,r.blockUntil and r.blockUntil>Epoch() and date("%Y-%m-%d %H:%M:%S",r.blockUntil)or"none",Safe(r.lastReason,50))
   local parts={};for prefix,n in pairs(r.prefixCounts or {})do parts[#parts+1]=prefix..":"..n end;table.sort(parts)
   rows[#rows+1]=(GC:Text("  prefixes "))..table.concat(parts,", ")
   parts={};for why,n in pairs(r.reasonCounts or {})do parts[#parts+1]=Safe(why,60)..":"..n end;table.sort(parts)
   rows[#rows+1]=(GC:Text("  rejectReasons "))..table.concat(parts,", ")
  end
  rows[#rows+1]=(GC:Text("--- INCIDENTS (bounded; newest last) ---"))
  rows[#rows+1]=(GC:Text("Saved incidents="))..#g.events..(GC:Text("; showing last 60 in window; all saved in GuildControl735.lua"))
  for i=math.max(1,#g.events-59),#g.events do
   local e=g.events[i]
   rows[#rows+1]=string.format((GC:Text("%s [%s %s] observer=%s/%s sender=%s/%s prefix=%s why=%s count=%d blockUntil=%d")),date("%Y-%m-%d %H:%M:%S",e.at or Epoch()),Safe(e.kind,20),e.mode and"mode-on"or"mode-off",Safe(e.observer,50),Safe(e.observerGUID,45),Safe(e.sender,60),Safe(e.senderGUID,45),Safe(e.prefix,18),Safe(e.reason,70),e.count or 0,e.blockUntil or 0)
  end
 end
 rows[#rows+1]=(GC:Text("--- MANUAL LEADER POLICY (native sender authenticated, not a signature) ---"))
 local policy=GC.ManualBans and GC.ManualBans:Root()
 if policy then
  local ids={};local active=0;for guid,entry in pairs(policy.entries)do ids[#ids+1]=guid;if entry.untilAt>Epoch()then active=active+1 end end;table.sort(ids)
  rows[#rows+1]=string.format((GC:Text("confirmed=%s leader=%s revision=%.0f entries=%d active=%d")),tostring(policy.confirmed),Safe(policy.leader,45),policy.revision,#ids,active)
  for i=1,math.min(60,#ids)do local guid=ids[i];local entry=policy.entries[guid];rows[#rows+1]=string.format((GC:Text("%s until=%d totalBans=%d")),guid,entry.untilAt,entry.total)end
 else rows[#rows+1]=(GC:Text("Policy unavailable; local automatic protection is independent."))end
 rows[#rows+1]="--- PREVIOUS MEASUREMENTS ---"
 for _,r in ipairs(root.runs)do rows[#rows+1]=string.format("observer=%s/%s mode=%s start=%d ended=%d received=%d denied=%d wouldBlock=%d minFPS=%.1f maxGap=%.1f",Safe(r.observer,60),Safe(r.observerGUID,50),r.enabled and"ON"or"OFF",r.start or 0,r.ended or 0,r.received or 0,r.denied or 0,r.potentialBlocks or 0,r.fpsMin or 0,r.frameGapMaxMs or 0)end
 return table.concat(rows,"\n")
end
function S:Show()
 if not self.frameUI then
  local f=CreateFrame("Frame",nil,UIParent);self.frameUI=f;f:SetSize(820,560);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetFrameLevel(150);f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",function()f:StartMoving()end);f:SetScript("OnDragStop",function()f:StopMovingOrSizing()end);f:SetScript("OnHide",function()f:StopMovingOrSizing()end)
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local measure=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");measure:SetPoint("BOTTOMLEFT",22,16);measure:SetSize(190,26);measure:SetText((GC:Text("Начать новый замер")));measure:SetScript("OnClick",function()S:ResetMeasurement();S:Show()end);self.measureButton=measure
  local summary=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");summary:SetPoint("BOTTOMLEFT",224,16);summary:SetSize(190,26);summary:SetText((GC:Text("Краткая сводка в чат")));summary:SetScript("OnClick",function()GC:SecurityStatus()end);self.summaryButton=summary
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOPLEFT",22,-18);title:SetText((GC:Text("Сетевая безопасность — журнал (Ctrl+A, Ctrl+C)")))
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-5,-5);close:SetScript("OnClick",function()f:Hide()end)
  local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",22,-55);scroll:SetSize(750,445)
  local edit=CreateFrame("EditBox",nil,scroll);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject(ChatFontNormal);edit:SetWidth(737)
  edit:SetScript("OnEscapePressed",function()f:Hide()end);scroll:SetScrollChild(edit);self.edit=edit
 end
 self.frameUI:SetFrameStrata("FULLSCREEN_DIALOG");self.frameUI:SetFrameLevel(150);local report=self:Text();self.edit:SetText(report);self.edit:SetHeight(math.max(445,math.ceil(#report/95)*16+40));self.edit:SetCursorPosition(0);self.frameUI:Show();self.edit:SetFocus()
end
function S:Initialize()
 if self.frame then return end
 self:Root();self.lastGuild=GC:GetGuildKey();self:StartRun("startup")
 local f=CreateFrame("Frame");self.frame=f
 for _,ev in ipairs({"CHAT_MSG_ADDON","PLAYER_GUILD_UPDATE","PLAYER_LOGOUT"})do f:RegisterEvent(ev)end
 f:SetScript("OnEvent",function(_,ev,prefix,msg,channel,sender)
  if ev=="PLAYER_GUILD_UPDATE"then S.lastGuild=GC:GetGuildKey();S.windows={};return end
  if ev=="PLAYER_LOGOUT"then S:StartRun("logout");S.run=nil;return end
  if channel=="GUILD"and prefix and S:IsPrefix(prefix)then
   local start=debugprofilestop and debugprofilestop()or nil
   S:Observe(prefix,msg,channel,sender)
   if start and S.run then
    local delta=debugprofilestop()-start
    if delta>=0 and delta<100000 then S.run.shieldCpuMs=S.run.shieldCpuMs+delta;S.run.shieldCpuMaxMs=math.max(S.run.shieldCpuMaxMs,delta)end
   end
  end
 end)
 f:SetScript("OnUpdate",function(_,dt)
  local run=S.run;if not run then return end
  if dt and dt>0 then run.frameGapMaxMs=math.max(run.frameGapMaxMs,dt*1000)end
  S.fpsElapsed=(S.fpsElapsed or 0)+(dt or 0)
  if S.fpsElapsed<1 then return end
  S.fpsElapsed=0
  if GC.RefreshNetworkBadge then GC:RefreshNetworkBadge()end
  local fps=GetFramerate and GetFramerate()
  if type(fps)=="number"and fps>0 and fps<1000 then
   run.fpsSamples=run.fpsSamples+1;run.fpsSum=run.fpsSum+fps
   if run.fpsMin==0 or fps<run.fpsMin then run.fpsMin=fps end
  end
 end)
end
