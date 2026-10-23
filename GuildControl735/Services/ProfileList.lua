local _,GC=...
local S=GC.Character
local P={prefix="GC735LIST",roles={TANK="T",HEALER="H",DAMAGER="D"},decodeRoles={T="TANK",H="HEALER",D="DAMAGER"}}
GC.ProfileList=P
local function integer(v,lo,hi)
 if type(v)~="string" or not v:match("^%d+$") then return nil end
 local n=tonumber(v);if n<lo or n>hi then return nil end;return n
end
function P:Encode()
 local store=S.Profile:GetCharacterStore();if not store then return nil end
 local guid=UnitGUID("player");if not GC.RaidWire.GUID(guid) then return nil end
 -- Migration gives the existing local authoritative set a durable revision, even when empty.
 if not tonumber(store.listRevision) then store.listRevision=time()*1000 end
 local rows={}
 for _,p in ipairs(S.Profile:GetProfiles())do
  rows[#rows+1]=table.concat({p.specID,self.roles[p.role],math.floor(p.itemLevel*100+0.5),p.reportedAt},",")
  if #rows>4 then return nil end
 end
 table.sort(rows)
 local msg=table.concat({"S","1",GC.wireVersion,guid,string.format("%.0f",store.listRevision),#rows,table.concat(rows,";")},"|")
 if #msg>254 then return nil end
 return msg
end
function P:Publish(guard)
 if not IsInGuild() then return false end
 local msg=self:Encode();if not msg then return false end
 local ok=GC.SecureExchange:Send(self.prefix,msg,guard,function()S.Profile:MarkChannelSent()end)
 return ok
end
function P:Delete(specID)
 local store=S.Profile:GetCharacterStore();local key=tostring(specID)
 if not store or not store.profiles[key] then return false end
 store.profiles[key]=nil
 store.listRevision=math.max((tonumber(store.listRevision)or 0)+1,time()*1000)
 local ok=self:Publish()
 if S.UpdateMainWindow then S:UpdateMainWindow() end
 S:Print(ok and (GC:Text("Комплект удалён. Новый список отправляется участникам.")) or (GC:Text("Комплект удалён локально. Изменение будет передано по разрешённому запросу доверенного персонажа.")))
 return true
end
function P:Receive(msg,sender,channel)
 if channel~="GUILD"then return false,"route"end
 if GC.SpamShield and GC.SpamShield:IsBlocked(sender)then return false,"spam_quarantine"end
 if not GC.SecureExchange.receiving then return GC.SecureExchange:Reject("raw_list_without_session",sender)end
 if not GC.db or not IsInGuild() or not GC:GetGuildKey() then return false,"guild" end
 if channel~="GUILD" or type(msg)~="string" or #msg>254 or msg:find("[%z\1-\31\127]") then return false,"schema" end
 local version,guid,revText,countText,body=msg:match("^S|1|(%d%d%d)|(Player%-%x+%-%x+)|(%d+)|(%d+)|(.*)$")
 if not version then return false,"schema" end
 local member,why=GC.TrustBoundary:ResolveSelfReport(sender,guid)
 if not member then return false,why end
 local rev=integer(revText,1,999999999999999);local count=integer(countText,0,4)
 if not rev or not count then return false,"revision_count" end
 GC.SatelliteStore:Get(member) -- Initialize the existing guild-scoped database.
 local guild=GC.db.guilds[GC:GetGuildKey()]
 local db=guild and guild.satellite
 if not db then GC.SatelliteStore:MarkInstalled(member,sender,version,0);db=GC.db.guilds[GC:GetGuildKey()].satellite end
 db.listWatermarks=db.listWatermarks or {}
 local mark=db.listWatermarks[guid]
 if not mark then local total=0;for _ in pairs(db.listWatermarks)do total=total+1 end;if total>=1000 then return false,"watermark_capacity" end end
 if mark and rev<mark.revision then return false,"stale_revision" end
 local digest=table.concat({guid,revText,countText,body},"|")
 if mark and rev==mark.revision and digest~=mark.digest then return false,"revision_conflict" end
 -- Parse the complete bounded datagram first. Never mutate profiles on partial/invalid input.
 local profiles={};local n=0
 if body~="" then
  if body:sub(1,1)==";" or body:sub(-1)==";" or body:find(";;",1,true) then return false,"rows" end
  for row in body:gmatch("[^;]+")do
   n=n+1;if n>4 then return false,"count" end
   local a,b,c,d=row:match("^(%d+),([THD]),(%d+),(%d+)$")
   local spec=integer(a,1,100000);local ilvl=integer(c,100,200000);local at=integer(d,1,time()+300)
   if not spec or not ilvl or not at or profiles[tostring(spec)] then return false,"profile" end
   if GetSpecializationInfoByID then local _,name=GetSpecializationInfoByID(spec);if not name then return false,"specialization" end end
   profiles[tostring(spec)]={specID=spec,role=self.decodeRoles[b],itemLevel=ilvl/100,reportedAt=at,receivedAt=time(),source="SATELLITE_SELF_REPORT",trust="UNVERIFIED_SELF_REPORT"}
  end
 end
 if n~=count then return false,"incomplete" end
 if not GC.TrustBoundary:CheckRate(sender,"LIST") then return false,"rate" end
 -- Repeated unchanged lists may restore a pruned view but do not change publication dates.
 local record=GC.SatelliteStore:MarkInstalled(member,sender,version,time())
 record.profiles=profiles;record.listRevision=rev;record.listDigest=digest
 db.listWatermarks[guid]={revision=rev,digest=digest}
 GC.SatelliteStore:RecordResult("accepted")
 if GC.OnSatelliteDataUpdated then GC:OnSatelliteDataUpdated(member) end
 return true
end
function P:Initialize()
 if self.frame then return end
 RegisterAddonMessagePrefix(self.prefix)
 local f=CreateFrame("Frame");self.frame=f;f:RegisterEvent("CHAT_MSG_ADDON")
 f:SetScript("OnEvent",function(_,_,prefix,msg,channel,sender)
  if prefix==P.prefix and channel=="GUILD" then local ok,why=P:Receive(msg,sender,channel);if not ok then GC.SatelliteStore:RecordResult("rejected",why) end end
 end)
end
