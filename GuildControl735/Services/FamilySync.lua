-- SNAP2 is voluntary read-only self-report, never server-verified ownership.
local _,GC=...
local C=GC.FamilyCodec
GC.FamilySync={pending={},rate={},dead={}}
local S=GC.FamilySync
local TTL=180*86400
local function Count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
function S:GetDatabase()
    local key=GC:GetGuildKey();if not key or not GC.db then return nil end
    if self.guildKey~=key then self.pending={};self.rate={};self.dead={};self.guildKey=key;self.lastPrune=nil end
    GC.db.guilds=GC.db.guilds or {};GC.db.guilds[key]=GC.db.guilds[key] or {}
    local g=GC.db.guilds[key]
    -- Preserve legacy LINK claims as history, never use them as SNAP2.
    g.familySnapshots=g.familySnapshots or {version=2,snapshots={},watermarks={}}
    return g.familySnapshots
end
function S:Prune()
    local db=self:GetDatabase();if not db then self.pending={};self.rate={};self.dead={};return end
    local clock=GetTime();local now=time()
    if self.lastPrune and clock>=self.lastPrune and clock-self.lastPrune<5 then return end
    self.lastPrune=clock
    for k,v in pairs(self.pending)do if clock-v.started>150 or clock<v.started then self.pending[k]=nil;if Count(self.dead)<1000 then self.dead[k..":"..v.rev..":"..v.stamp]=clock+30 end end end
    for k,v in pairs(self.dead)do if clock>v then self.dead[k]=nil end end
    for k,v in pairs(self.rate)do if clock-v.started>=60 or clock<v.started then self.rate[k]=nil end end
    for k,v in pairs(db.snapshots)do if type(v)~="table" or type(v.receivedAt)~="number" then db.snapshots[k]=nil end end
    for k,v in pairs(db.watermarks)do if type(v)~="table" or type(v.at)~="number" then db.watermarks[k]=nil end end
end
function S:Receive(prefix,message,channel,sender)
    if prefix~="GC735FAM" or channel~="GUILD" then return false,"route" end
    if GC.SpamShield and GC.SpamShield:IsBlocked(sender)then return false,"spam_quarantine"end
    if not GC.SecureExchange.receiving then return GC.SecureExchange:Reject("raw_family_without_session",sender)end
    if prefix~="GC735FAM" or channel~="GUILD" or type(message)~="string" or #message>220 then return false,"channel-size" end
    local db=self:GetDatabase();if not db then return false,"guild" end
    local m=GC.Roster:FindBySender(sender);if not m or not C.GUID(m.guid) then return false,"sender" end
    local clock=GetTime();local w=self.rate[m.guid]
    if w and (clock-w.started>=60 or clock<w.started) then w=nil;self.rate[m.guid]=nil end
    self:Prune()
    if not w then if Count(self.rate)>=1000 then return false,"rate-cap" end;w={started=clock,count=0};self.rate[m.guid]=w end
    w.count=w.count+1;if w.count>64 then return false,"rate" end
    local rev,stamp,seq,total,chunk=message:match("^SNAP|2|(%d+)|(%d+)|(%d+)|(%d+)|([0-9a-f]+)$")
    if not rev or #rev>10 or #stamp>12 or #seq>2 or #total>2 then return false,"format" end
    rev,stamp,seq,total=tonumber(rev),tonumber(stamp),tonumber(seq),tonumber(total)
    if rev<1 or seq<1 or seq>total or total<1 or total>C.MAX_PARTS or #chunk>C.CHUNK or #chunk%2~=0 then return false,"bounds" end
    if stamp<=time()-TTL or stamp>time()+300 then return false,"time" end
    local watermark=db.watermarks[m.guid]
    if watermark and (rev<=watermark.rev or stamp<watermark.stamp) then return false,"replay" end
    local key=m.guid;local deadKey=key..":"..rev..":"..stamp
    if self.dead[deadKey] and clock<self.dead[deadKey] then return false,"aborted" end
    local p=self.pending[key]
    local function Abort(reason)
        self.pending[key]=nil;if Count(self.dead)<1000 then self.dead[deadKey]=clock+30 end
        return false,reason
    end
    if seq==1 then
        if p then return Abort("duplicate-start") end
        if Count(self.pending)>=16 then return false,"pending-cap" end
        p={rev=rev,stamp=stamp,total=total,next=1,parts={},bytes=0,started=clock};self.pending[key]=p
    end
    if not p or clock-p.started>150 or clock<p.started or p.rev~=rev or p.stamp~=stamp or p.total~=total or p.next~=seq then return Abort("order") end
    if seq<total and #chunk~=C.CHUNK then return Abort("short-part") end
    p.parts[seq]=chunk;p.bytes=p.bytes+#chunk;p.next=seq+1
    if p.bytes>C.MAX_BYTES then return Abort("size") end
    if seq<total then return true,"pending" end
    local snap=C.Decode(table.concat(p.parts));self.pending[key]=nil
    if not snap or snap.guild~=GC:GetGuildKey() or snap.senderGUID~=m.guid then return Abort("identity") end
    for _,v in ipairs(snap.members)do
        local rm=GC.Roster:FindByKey(v.guid)
        if not rm or rm.guid~=v.guid or GC.TrustBoundary:CanonicalName(v.name)~=rm.fullName then return Abort("roster") end
    end
    if not db.snapshots[key] and Count(db.snapshots)>=1000 then return Abort("cache-cap") end
    if not db.watermarks[key] and Count(db.watermarks)>=1000 then return Abort("watermark-cap") end
    snap.rev=rev;snap.stamp=stamp;snap.receivedAt=time();snap.trust="VOLUNTARY_SELF_REPORT"
    db.snapshots[key]=snap;db.watermarks[key]={rev=rev,stamp=stamp,at=time()}
    if GC.RefreshLinkedMemberCard then GC:RefreshLinkedMemberCard() end
    return true,"complete"
end
local function Has(s,g)for _,m in ipairs(s.members or {})do if m.guid==g then return true end end end
-- A mutual edge proves only the two self-reports, not a server account ID.
-- Main selection and complete-list equality are deliberately not edge criteria.
function S:GetVerifiedFamily(member)
 local db=self:GetDatabase();if not db or not member then return nil end
 local function snapshot(guid)
  if guid==UnitGUID("player")and GC.Character and GC.Character.Family then
   return {senderGUID=guid,members=GC.Character.Family:GetMembers()}
  end
  return db.snapshots[guid]or(GC.GuildArchive and GC.GuildArchive:Snapshot(guid))
 end
 if not snapshot(member.guid)then return nil end
 local found={[member.guid]=true};local todo={member.guid};local members={};local at=1
 while at<=#todo do
  local guid=todo[at];at=at+1;local row=GC.Roster:FindByKey(guid)or(GC.GuildArchive and GC.GuildArchive:Member(guid))
  if not row then return nil end
  members[#members+1]=row
  local own=snapshot(guid)
  local candidates={};for _,peer in ipairs(own and own.members or{})do candidates[#candidates+1]=peer end
  for guid in pairs(GC.GuildArchive and GC.GuildArchive:Peers(guid)or{})do candidates[#candidates+1]={guid=guid}end
  for _,peer in ipairs(candidates)do
   if not found[peer.guid]and(GC.Roster:FindByKey(peer.guid)or(GC.GuildArchive and GC.GuildArchive:Member(peer.guid)))then
    local other=snapshot(peer.guid)
    if (member.guid==UnitGUID("player")and guid==member.guid)or(other and Has(other,guid))or(GC.GuildArchive and GC.GuildArchive:Linked(guid,peer.guid))then
     if #todo>=12 then return {members={member},trust="FAMILY_CAPACITY",conflict=true}end
     found[peer.guid]=true;todo[#todo+1]=peer.guid
    end
   end
  end
 end
 table.sort(members,function(a,b)return a.guid<b.guid end)
 local result={members=members,trust="MUTUAL_SELF_REPORTS"}
 local mains={};local unknown=false
 for _,m in ipairs(members)do
  local mark=GC.OfficerMarks and GC.OfficerMarks:Get(m.guid)
  if not mark then unknown=true elseif mark.marked then mains[#mains+1]=m end
 end
 if #mains>1 then result.mainStatus="conflict"
 elseif unknown then result.mainStatus="unknown"
 elseif #mains==1 then result.mainGUID=mains[1].guid;result.mainName=mains[1].name;result.mainStatus="assigned"
 else result.mainStatus="unset"end
 return result
end
function GC:InitializeFamilySync()
    if S.initialized or type(RegisterAddonMessagePrefix)~="function" then return end
    RegisterAddonMessagePrefix("GC735FAM");S.initialized=true
    local f=CreateFrame("Frame");f:RegisterEvent("CHAT_MSG_ADDON");f:RegisterEvent("PLAYER_GUILD_UPDATE")
    f:SetScript("OnEvent",function(_,e,...)if e=="CHAT_MSG_ADDON" then local p,_,ch=...;if p~="GC735FAM" or ch~="GUILD" then return end;S:Receive(...) else S:Prune() end end);S.frame=f
end
