-- Compact owner records are converted locally into existing validated stores.
local _,G=...
local W=G.FastWire
local R={};G.FastRecords=R
local function Count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local roles={TANK="T",HEALER="H",DAMAGER="D"}
local function Profiles(rows)
 local out={};for _,p in pairs(rows or{})do
  if not roles[p.role]or type(p.itemLevel)~="number"or not tonumber(p.reportedAt)then return nil end
  out[#out+1]=table.concat({p.specID,roles[p.role],math.floor(p.itemLevel*100+0.5),p.reportedAt},",")
 end
 if #out>4 then return nil end;table.sort(out);return table.concat(out,";")
end
local function Family(stamp,main,members)
 local guids={};for _,m in pairs(members or{})do guids[#guids+1]=type(m)=="table"and m.guid or m end
 table.sort(guids);return tostring(stamp).."|"..(main or"-").."|"..table.concat(guids,",")
end
function R:Root()
 if not G.db or not G:GetGuildKey()then return nil end
 G.db.fastSync=G.db.fastSync or{guilds={}}
 local root=G.db.fastSync.guilds;local key=G:GetGuildKey()
 if not root[key]then if Count(root)>=10 then return nil end;root[key]={own={},received={},seen={}}end
 return root[key]
end
function R:Own()
 local db=self:Root();if not db then return nil,"storage_capacity"end
 local guid=UnitGUID("player");local member=G.Roster:FindByKey(guid)
 if not W.GUID(guid)or not member or not member.online then return nil,"own_identity"end
 local source=G.Character;local profileStore=source.Profile:GetCharacterStore()
 local pbody=profileStore and Profiles(source.Profile:GetProfiles())
 local fs=source.Family:RegisterCurrent();local familyBody,familySemantic
 if fs then
  local all=source.Family:GetMembers();local members={}
  for _,m in ipairs(all)do if W.GUID(m.guid)and G.Roster:FindByKey(m.guid)then members[#members+1]=m end end
  local valid=#members>=1 and #members<=12
  if G.Diagnostics and #members~=#all then G.Diagnostics:Record('FAMILY_LOCAL_SUBSET','owner='..guid..' local='..#all..' inGuild='..#members)end
  if valid then familySemantic=Family(0,nil,members);familyBody=Family(time(),nil,members)end
 end
 local raid=G.RaidRuntime:Get(guid)
 if raid and time()-(raid.capturedAt or 0)>86000 then
  G.RaidRuntime:Collect();raid=G.RaidRuntime:Get(guid)
 end
 local values=raid and raid.values or G.RaidWire.Capture();local valid=#values==160
 for _,v in ipairs(values)do if not G.RaidWire.Value(v)then valid=false end end
 local raw=valid and table.concat(values,",")or nil
 local inputs={P=pbody,F=familyBody,R=raw and(time().."|"..raw)or nil}
 local semantic={P=pbody,F=familySemantic,R=raw};local records={}
 if not db.own[guid]and Count(db.own)>=500 then return nil,"owner_capacity"end
 db.own[guid]=db.own[guid]or{}
 for _,cat in ipairs(W.categories)do local body=inputs[cat]
  if body and #body<=W.caps[cat]then
   local old=db.own[guid][cat];local key=W.Hash(semantic[cat]);if not key then return nil,"bit_api_unavailable"end
   -- Preserve publication dates on unchanged content. Renew a raid capture only
   -- after the existing legacy24h admission window, not on every request.
   local renew=old and ((cat=="R"and time()-(old.stamp or 0)>86000)or(cat=="F"and time()-(old.stamp or 0)>179*86400))
   if not old or old.semantic~=key or renew then
    local rev=math.max(1,old and old.rev+1 or 1)
    if cat=="P"then rev=math.max(rev,tonumber(profileStore.listRevision)or time()*1000);profileStore.listRevision=rev
    elseif cat=="F"then rev=math.max(rev,(tonumber(fs.revision)or 0)+1);fs.revision=rev end
    if rev>9999999999999 or(cat=="F"and rev>9999999999)then return nil,"revision_capacity"end
    old={rev=rev,len=#body,hash=W.Hash(body),body=body,semantic=key,stamp=time()};db.own[guid][cat]=old
   end
   records[cat]=old
  end
 end
 return records
end
function R:CachedBody(member,cat)
 if cat=="P"then local p=G.SatelliteStore:Get(member);return p and p.listRevision and Profiles(p.profiles)or nil end
 if cat=="F"then local db=G.FamilySync:GetDatabase();local p=db and db.snapshots[member.guid];return p and Family(p.stamp,p.mainGUID,p.members)or nil end
 local p=G.RaidRuntime:Get(member.guid);if not p then return nil end
 local values=table.concat(p.values,",")
 -- A local recapture may refresh its wall-clock without changing any statistic.
 -- Reuse only the exact previously received canonical body, verified by Known.
 if member.guid==UnitGUID("player")then
  local db=self:Root();local own=db and db.own[member.guid]and db.own[member.guid].R
  local stamp,raw;if own and own.body then stamp,raw=own.body:match("^(%d+)|(.*)$")end
  if stamp and tonumber(stamp)<=p.capturedAt and raw==values then return own.body end
 end
 return tostring(p.capturedAt).."|"..values
end
function R:Known(member)
 local db=self:Root();local stored=db and db.received[member.guid];local result={}
 for _,cat in ipairs(W.categories)do local meta=stored and stored[cat]
  if meta then local body=self:CachedBody(member,cat)
   if body and #body==meta.len and W.Hash(body)==meta.hash then result[cat]=meta end
  end
 end
 return result
end
function R:Decode(cat,body,member,meta)
 if #body~=meta.len or W.Hash(body)~=meta.hash then return nil,"checksum"end
 if cat=="P"then
  local rows=body==""and{}or W.Split(body,";");if #rows>4 then return nil,"profile_count"end
  local seen={}
  for _,row in ipairs(rows)do
   local a,b,c,d=row:match("^(%d+),([THD]),(%d+),(%d+)$")
   local spec,ilvl,stamp=W.Int(a,1,100000),W.Int(c,100,200000),W.Int(d,1,time()+300)
   if not spec or not ilvl or not stamp or seen[spec]then return nil,"profile_schema"end
   if GetSpecializationInfoByID then local _,name=GetSpecializationInfoByID(spec);if not name then return nil,"specialization"end end
   seen[spec]=true
  end
  return {count=#rows,body=body}
 end
 local stamp,rest=body:match("^(%d+)|(.*)$");stamp=W.Int(stamp,1,time()+300)
 if not stamp then return nil,"timestamp"end
 if cat=="F"then
  if stamp<=time()-180*86400 or meta.rev>9999999999 then return nil,"family_age_revision"end
  local main,raw=rest:match("^([^|]+)|([^|]+)$");if not main then return nil,"family_schema"end
  local ids=W.Split(raw,",");if #ids<1 or #ids>12 then return nil,"family_count"end
  local seen,members={},{}
  for _,guid in ipairs(ids)do local m=W.GUID(guid)and G.Roster:FindByKey(guid)
   if not m or seen[guid]then return nil,"family_roster"end
   seen[guid]=true;members[#members+1]={guid=guid,name=m.fullName or m.name}
  end
  if not seen[member.guid]or(main~="-"and not seen[main])then return nil,"family_owner"end
  return {stamp=stamp,main=main~="-"and main or nil,members=members}
 end
 if stamp<time()-86400 then return nil,"raid_age"end
 local values=W.Split(rest,",");if #values~=160 then return nil,"raid_count"end
 for _,v in ipairs(values)do if not G.RaidWire.Value(v)then return nil,"raid_value"end end
 return {stamp=stamp,values=values}
end
-- Relay metadata is not an owner revision. A direct owner may replace it,
-- including its native-store watermark, after complete schema validation.
function R:MarkSource(member,cat,provider)
 if cat=="P"then
  local record=G.SatelliteStore:Get(member)
  for _,p in pairs(record and record.profiles or{})do
   p.source=provider and "TRUSTED_CACHE_RELAY"or"SATELLITE_SELF_REPORT"
   p.trust=provider and "UNVERIFIED_RELAY"or"UNVERIFIED_SELF_REPORT"
  end
 elseif cat=="F"then
  local db=G.FamilySync:GetDatabase();local record=db and db.snapshots[member.guid]
  if record then record.trust=provider and "UNVERIFIED_RELAY"or"VOLUNTARY_SELF_REPORT"end
 else
  local record=G.RaidRuntime:Get(member.guid)
  if record then record.source=provider and "TRUSTED_CACHE_RELAY"or"Satellite/self-report"end
 end
end
function R:ConfirmDirect(member,cat,meta)
 local db=self:Root();local old=db and db.received[member.guid]and db.received[member.guid][cat]
 if old and W.Same(old,meta)then old.relay=nil;old.source="OWNER_SELF_REPORT";self:MarkSource(member,cat)end
end
function R:Apply(member,cat,body,meta,provider)
 if G.ManualBans and G.ManualBans:Blocked(member.guid)then return false,"owner_manual_ban"end
 local db=self:Root();if not db then return false,"storage"end
 if not db.received[member.guid]and Count(db.received)>=500 then return false,"cache_capacity"end
 local old=db.received[member.guid]and db.received[member.guid][cat]
 if provider and member.guid==UnitGUID("player")then return false,"own_record_protected"end
 if old and (provider or not old.relay)and(meta.rev<old.rev or meta.rev==old.rev and meta.hash~=old.hash)then return false,"revision_conflict"end
 local decoded,why=self:Decode(cat,body,member,meta);if not decoded then return false,why end
 local restore
 if old and old.relay and not provider then
  if cat=="P"then
   G.SatelliteStore:Get(member)
   local db=G.db.guilds[G:GetGuildKey()].satellite;local mark=db.listWatermarks[member.guid]
   db.listWatermarks[member.guid]=nil
   restore=function()db.listWatermarks[member.guid]=mark end
  elseif cat=="F"then
   local db=G.FamilySync:GetDatabase();local mark=db.watermarks[member.guid]
   local pending=G.FamilySync.pending[member.guid];local removed={}
   for key,value in pairs(G.FamilySync.dead)do if key:sub(1,#member.guid+1)==member.guid..":"then removed[key]=value;G.FamilySync.dead[key]=nil end end
   db.watermarks[member.guid]=nil;G.FamilySync.pending[member.guid]=nil
   restore=function()db.watermarks[member.guid]=mark;G.FamilySync.pending[member.guid]=pending;for key,value in pairs(removed)do G.FamilySync.dead[key]=value end end
  else
   local db=G.RaidRuntime:Database();local record=db.records[member.guid]
   db.records[member.guid]=nil
   restore=function()db.records[member.guid]=record end
  end
 end
 local E=G.SecureExchange;E.receiving=true
 local ok,result,reason=pcall(function()
  if cat=="P"then
   local msg=table.concat({"S","1",G.wireVersion,member.guid,string.format("%.0f",meta.rev),decoded.count,body},"|")
   return G.ProfileList:Receive(msg,member.name,"GUILD")
  elseif cat=="F"then
   local fdb=G.FamilySync:GetDatabase();local snap=fdb and fdb.snapshots[member.guid];local mark=fdb and fdb.watermarks[member.guid]
   if mark and meta.rev==mark.rev then
    if snap and self:CachedBody(member,"F")==body then return true end
    return false,"family_watermark"
   end
   local packets=G.FamilyCodec.Encode(G:GetGuildKey(),member.guid,decoded.main,decoded.members,meta.rev,decoded.stamp)
   if not packets then return false,"family_codec"end
   for _,p in ipairs(packets)do local accepted,why=G.FamilySync:Receive("GC735FAM",p,"GUILD",member.name);if not accepted then return false,why end end
   return true
  else
   local previous=G.RaidRuntime:Get(member.guid)
   local frames,hash=G.RaidWire.Frames(member.guid,decoded.stamp,decoded.values)
   if not frames then return false,"raid_frames"end
   if previous and previous.capturedAt==decoded.stamp and previous.hash==hash then return true end
   if previous and previous.capturedAt>decoded.stamp then
    -- Local owner only: all160 validated values must match exactly; keep newer
    -- native timestamp intact. Never relax a remote sender's rollback check.
    if member.guid==UnitGUID("player")and table.concat(previous.values,",")==table.concat(decoded.values,",")then return true end
    return false,"raid_native_newer"
   end
   for _,p in ipairs(frames)do if not G.RaidRuntime.engine:Receive(p,member.name,"GUILD")then return false,G.RaidRuntime.engine.lastReject or"raid_native_rejected"end end
   return true
  end
 end)
 E.receiving=false
 if (not ok or not result)and restore then restore()end
 if not ok then
  if G.Diagnostics and(not self.lastExceptionAt or GetTime()-self.lastExceptionAt>=5)then self.lastExceptionAt=GetTime();G.Diagnostics:Record("RECORD_ERROR",cat.." owner="..member.guid.." "..tostring(result):sub(1,240))end
  return false,"record_exception_"..cat
 end
 if not result then return false,reason or("native_rejected_"..cat)end
 db.received[member.guid]=db.received[member.guid]or{}
 db.received[member.guid][cat]={rev=meta.rev,len=meta.len,hash=meta.hash,
  source=provider and "TRUSTED_CACHE_RELAY"or"OWNER_SELF_REPORT",
  relay=provider and {provider=provider,receivedAt=time(),source="TRUSTED_CACHE_RELAY"}or nil}
 self:MarkSource(member,cat,provider)
 if cat=='F'and G.Diagnostics then
  local ids={};for _,m in ipairs(decoded.members)do ids[#ids+1]=m.guid end
  for i=1,#ids,3 do local part={};for j=i,math.min(i+2,#ids)do part[#part+1]=ids[j]end
   G.Diagnostics:Record('FAMILY_APPLIED','owner='..member.guid..' rev='..meta.rev..' part='..math.floor((i+2)/3)..'/'..math.ceil(#ids/3)..' members='..table.concat(part,','))
  end
 end
 return true
end
