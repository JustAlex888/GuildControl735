-- Bounded passive observer: metadata/field presence only, never request/accept data.
local _,GC=...
local D={buffer={},dropped=0};GC.LadderObserver=D
local public={SMSG_RT_HELLO_COMPLETE=true,SMSG_RT_HELLO_CHALLENGE_RESPONSE=true,
 SMSG_RT_HELLO_PVP_BRACKETS_RESPONSE=true,SMSG_RT_HELLO_PREV_SCORE_RESPONSE=true,
 SMSG_RT_PLAYER_CHALLENGE_STATISTIC_RESPONSE=true,SMSG_RT_PLAYER_CHALLENGE_STATISTIC_BEST_RUNS_RESPONSE=true,
 SMSG_RT_PLAYER_CHALLENGE_STATISTIC_RUNS_RESPONSE=true,SMSG_RT_PLAYER_PVP_STATISTIC_RESPONSE=true,
 SMSG_RT_PLAYER_STATISTIC_CREATE=true}
local function Own(sender)
 if sender==UnitName("player")then return true end
 if type(sender)~="string"then return false end
 local n,r=UnitFullName("player");local C=GC.TrustBoundary
 return C and (C:CanonicalName(sender)==C:CanonicalName((n or UnitName("player")).."-"..(r or GetRealmName()))or C:CanonicalName(sender)==C:CanonicalName((n or UnitName("player")).."-"..GetRealmName()))
end
function D:Attach()
 if self.session then return self.session end
 if type(GC.db)~="table"then return nil end
 local db=GC.db.ladderObserver
 if type(db)~="table"or db.schema~=1 or type(db.sessions)~="table"then db={schema=1,sequence=0,sessions={}};GC.db.ladderObserver=db end
 db.sequence=(tonumber(db.sequence)or 0)+1
 local s={id=db.sequence,build=GC.build,at=date("%Y-%m-%d %H:%M:%S"),observer=UnitGUID("player"),events={},counts={},dropped=self.dropped}
 self.session=s;db.sessions[#db.sessions+1]=s
 while #db.sessions>4 do table.remove(db.sessions,1)end
 for _,e in ipairs(self.buffer)do s.events[#s.events+1]=e;s.counts[e.kind]=(s.counts[e.kind]or 0)+1 end
 self.buffer={};return s
end
function D:Event(kind,fields)
 local e={kind=kind,at=date("%Y-%m-%d %H:%M:%S"),clock=GetTime()}
 for k,v in pairs(fields or {})do
  if type(v)=="number"or type(v)=="boolean"then e[k]=v
  elseif type(v)=="string"then e[k]=v:sub(1,384)end
 end
 local s=self:Attach()
 if s then
  s.counts[kind]=(s.counts[kind]or 0)+1
  if #s.events>=256 then s.dropped=s.dropped+1;return end
  s.events[#s.events+1]=e
 elseif #self.buffer<64 then self.buffer[#self.buffer+1]=e
 else self.dropped=self.dropped+1 end
end
function D:State(number,realm)
 local f=_G.LadderFrame;local root=f and f.BracketsByTypeData
 local e={native=type(f)=="table",general=type(root)=="table",guild=GC:GetGuildKey()or ""}
 for _,mode in ipairs({-2,7,0,3,9})do e["rows"..mode]=type(root)=="table"and type(root[mode])=="table"and #root[mode]or 0 end
 local all=f and f.PlayerStatisticData
 local inspected,mythic,pvp=0,0,0
 if type(all)=="table"then
  for _,realmProfiles in pairs(all)do
   if type(realmProfiles)=="table"then
    for _,profiles in pairs(realmProfiles)do
     inspected=inspected+1
     if type(profiles)=="table"then
      if type(profiles[-2])=="table"then mythic=mythic+1 end
      for _,mode in ipairs({7,0,3,9})do if type(profiles[mode])=="table"then pvp=pvp+1 end end
     end
     if inspected>=10000 then break end
    end
   end
   if inspected>=10000 then break end
  end
 end
 e.totalMythicProfiles=mythic;e.totalPvPProfiles=pvp;e.profileCountCapped=inspected>=10000
 local guid=GC.MemberCard and GC.MemberCard.memberKey
 local m=GC.Roster and GC.Roster:FindByKey(guid)
 if m then
  e.selectedGUID=m.guid;e.selectedName=m.name
  if not number then number,realm=GC.UWoWMythic:Resolve(m)end
 end
 if number and realm then
  e.number=number;e.realm=realm
  local all=f and f.PlayerStatisticData
  local details=type(all)=="table"and type(all[realm])=="table"and all[realm][number]
  for _,mode in ipairs({-2,7,0,3,9})do
   local detail=type(details)=="table"and details[mode]
   e["profile"..mode]=type(detail)=="table"
   if type(detail)=="table"then
    if mode==-2 then e.mythicRoles=type(detail.rating)=="table";e.mythicRanges=type(detail.completed_runs)=="table"
    else e["season"..mode]=type(detail.season)=="table";e["week"..mode]=type(detail.week)=="table"end
   end
  end
 end
 return e
end
function D:Sample(force)
 local e=self:State();local pieces={}
 for k,v in pairs(e)do pieces[#pieces+1]=k.."="..tostring(v)end;table.sort(pieces)
 local signature=table.concat(pieces,"|")
 if force or signature~=self.last then self.last=signature;self:Event("MEMORY",e)end
end
function D:Transmit(prefix,message,channel,target)
 if prefix~="UIMSG_TO_SERVER"or channel~="WHISPER"or not Own(target)or type(message)~="string"or #message>256 then return end
 local op,payload=message:match("^([A-Z_]+)\t(.*)$")
 if op~="CMSG_RT_HELLO"and op~="CMSG_RT_GET_PLAYER_STATISTIC"then return end
 local e={opcode=op,channel=channel,target=target}
 if op=="CMSG_RT_GET_PLAYER_STATISTIC"then
  local n,r,b=payload:match("^(%d+)|(%d+)|([%-0-9]+)$")
  e.number=tonumber(n);e.realm=tonumber(r);e.bracket=tonumber(b)
  self:Event("BEFORE_TX_MEMORY",self:State(e.number,e.realm))
 end
 if type(debugstack)=="function"then local ok,v=pcall(debugstack,3,4,0);if ok and type(v)=="string"then e.callsite=v:sub(1,384)end end
 self:Event("TX_OBSERVED",e)
end
function D:Receive(prefix,message,channel,sender)
 if prefix~="UISMSG_TO_CLIENT"or channel~="WHISPER"or not Own(sender)or type(message)~="string"then return end
 local op=message:match("^([A-Z_]+)")
 if not public[op]then return end
 local e={opcode=op,bytes=#message,channel=channel}
 if #message<=8192 and not op:find("HELLO",1,true)then
  local n,r=message:match("^[A-Z_]+|(%d+)|(%d+)|")
  e.number=tonumber(n);e.realm=tonumber(r)
 end
 self:Event("RX_OBSERVED",e)
 -- After all native event handlers have had a chance to populate their tables.
 if op=="SMSG_RT_HELLO_COMPLETE"or op=="SMSG_RT_PLAYER_STATISTIC_CREATE"or op=="SMSG_RT_PLAYER_CHALLENGE_STATISTIC_RESPONSE"or op=="SMSG_RT_PLAYER_PVP_STATISTIC_RESPONSE"then
  if not self.deferred then self.deferred=true;C_Timer.After(0,function()D.deferred=false;D:Sample(true)end)end
 end
end
function D:Install()
 if type(hooksecurefunc)~="function"then return end
 if not self.generalHook and type(PVEFrame_ShowFrame)=="function"then
  self.generalHook=true;hooksecurefunc("PVEFrame_ShowFrame",function(name)
   if name=="LadderFrame"then D:Event("NATIVE_LADDER_VIEW",{});D:Sample(true)end
  end)
 end
 if not self.cardHook and type(GC.ToggleStats)=="function"then
  self.cardHook=true;hooksecurefunc(GC,"ToggleStats",function(_,kind)D:Event("CARD_CATEGORY",{category=kind});D:Sample(true)end)
 end
 local f=_G.LadderFrame
 if type(f)=="table"and f~=self.nativeHook and type(f.CreatePlayerMythicPlusStatistic)=="function"then
  self.nativeHook=f;hooksecurefunc(f,"CreatePlayerMythicPlusStatistic",function(_,n,r)D:Event("NATIVE_PROFILE_OPEN",D:State(tonumber(n),tonumber(r)))end)
  self:Event("NATIVE_HOOK_READY",{})
 end
end
if type(hooksecurefunc)=="function"and type(SendAddonMessage)=="function"then
 hooksecurefunc("SendAddonMessage",function(...)D:Transmit(...)end)
 D:Event("TX_HOOK_READY",{})
else D:Event("TX_HOOK_UNAVAILABLE",{})end
local frame=CreateFrame("Frame")
for _,event in ipairs({"CHAT_MSG_ADDON","PLAYER_LOGIN","PLAYER_LOGOUT"})do frame:RegisterEvent(event)end
frame:SetScript("OnEvent",function(_,event,...)
 if event=="CHAT_MSG_ADDON"then D:Receive(...)
 else D:Install();D:Event(event,{});D:Sample(true)end
end)
frame:SetScript("OnUpdate",function(_,elapsed)
 D.elapsed=(D.elapsed or 0)+elapsed
 if D.elapsed>=1 then D.elapsed=0;D:Attach();D:Install();D:Sample()end
end)
