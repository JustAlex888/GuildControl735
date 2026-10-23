-- Local retention uses only independently confirmed native guild membership.
-- Provider cache absence and offline status are never deletion evidence.
local _,G=...
local R=G.Roster
function R:MembershipSnapshot()
 if not IsInGuild()or not G:GetGuildKey()then return nil end
 local total=GetNumGuildMembers(true)
 if type(total)~="number"or total<1 or total>1000 or #self.members~=total then return nil end
 local ids,set={},{}
 for _,m in ipairs(self.members)do
  if type(m.guid)~="string"or not m.guid:match("^Player%-%d+%-%x+$")or set[m.guid]or not m.name then return nil end
  set[m.guid]=true;ids[#ids+1]=m.guid
 end
 if not set[UnitGUID("player")]then return nil end
 table.sort(ids);return G:GetGuildKey()..":"..table.concat(ids,","),set
end
function R:CanPrune()
 local sig=self:MembershipSnapshot()
 return sig and self.confirmedMembership==sig or false
end
function R:ConfirmMembership()
 local sig=self:MembershipSnapshot();local now=GetTime()
 if not sig then self.membershipCandidate=nil;self.confirmedMembership=nil;return false end
 if self.confirmedMembership==sig then return true end
 self.confirmedMembership=nil
 local c=self.membershipCandidate
 if c and c.signature==sig and c.requested and now-c.at>=3 and now-c.at<30 then
  self.confirmedMembership=sig;self.membershipCandidate=nil
  if G.GuildCache then G.GuildCache:Prune()end
  return true
 end
 if c and c.signature==sig and now-c.at<30 then return false end
 c={signature=sig,at=now};self.membershipCandidate=c
 C_Timer.After(3.2,function()
  if R.membershipCandidate~=c or R:MembershipSnapshot()~=sig then return end
  -- Mark before the API call: only a later roster-event confirmation qualifies.
  c.requested=true
  if not R:RequestRefresh()then c.requested=false end
 end)
 return false
end
local C={};G.GuildCache=C
function C:Prune()
 if not R:CanPrune()or not G.db then return false end
 local _,keep=R:MembershipSnapshot();local key=G:GetGuildKey();local db=G.db
 local removed={};local changed=G.GuildArchive:Reconcile(keep)
 local function trim(t)
  if type(t)~="table"then return end
  for guid in pairs(t)do if type(guid)=="string"and guid:match("^Player%-%d+%-%x+$")and not keep[guid]then t[guid]=nil;removed[guid]=true;changed=true end end
 end
 local guild=db.guilds and db.guilds[key]
 if guild then
  local sat=guild.satellite;if sat then trim(sat.members);trim(sat.listWatermarks)end
  local fam=guild.familySnapshots
  if fam then
   trim(fam.snapshots);trim(fam.watermarks);trim(guild.officerMarks)

  end
 end
 for _,name in ipairs({"raidSnapshots","ratingCache","pvpRatings","mythicLadderCache"})do
  local root=db[name];local scoped=root and root.guilds and root.guilds[key]
  if scoped then trim(scoped.records or scoped);trim(scoped.publishedAt)end
 end
 local fast=db.fastSync and db.fastSync.guilds and db.fastSync.guilds[key]
 if fast then trim(fast.own);trim(fast.received)end
 -- Nonce/replay ledgers intentionally remain bounded security tombstones.
 -- Removing them on kick/reinvite would reopen a still-fresh replay window.
 local family=G.Character and G.Character.db and G.Character.db.families and G.Character.db.families[key]
 if family then
  local before=false
  for guid in pairs(family.members or{})do if not keep[guid]and not G.GuildArchive:Member(guid)then family.members[guid]=nil;before=true end end
  trim(family.pending)
  if family.primaryGUID and not keep[family.primaryGUID]then family.primaryGUID=nil;before=true end
  if before then family.revision=(tonumber(family.revision)or 0)+1;changed=true end
 end
 if changed then
  local rating=G.Rating
  if rating then
   for stateKey in pairs(rating.states or{})do
    local guid=stateKey:match("(Player%-%d+%-%x+)$")
    if guid and not keep[guid]then rating.states[stateKey]=nil;if rating.stateReasons then rating.stateReasons[stateKey]=nil end end
   end
  end
  if G.CacheSync then G.CacheSync:Stop("guild_event")end
  if G.LadderRefresh then G.LadderRefresh:Plan()end
  if G.Diagnostics then local n=0;for _ in pairs(removed)do n=n+1 end;G.Diagnostics:Record("GUILD_CACHE_PRUNE","confirmed removed="..n)end
 end
 return true
end
-- Shared UI colors; no persisted profile or class data is rewritten.
function G:ClassName(member)
 local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.classFile]
 if not c then return member.name end
 return string.format("|cff%02x%02x%02x%s|r",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5),member.name)
end
function G:StatLabel(label,value)return "|cffffd100"..label.."|r: |cffffffff"..tostring(value).."|r"end
function G:ProfileSummary(member)
 local own=member.guid==UnitGUID("player")and self.Character and self.Character.Profile
 local record=own and own:GetCharacterStore()or self.SatelliteStore:Get(member)
 if not record then return self.L.ADDON_UNKNOWN end
 local profiles=own and own:GetProfiles()or self.SatelliteStore:GetProfiles(member)
 if #profiles==1 then return self.L.SATELLITE_COUNT_ONE end
 if #profiles>1 then return string.format(self.L.SATELLITE_COUNT_MANY,#profiles)end
 return self.L.CARD_EMPTY
end
