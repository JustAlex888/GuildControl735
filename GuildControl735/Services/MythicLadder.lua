-- Read-only native memory snapshot; never sends a request or replaces handlers.
local _,GC=...
local L={epoch=0,revision=0};GC.MythicLadder=L
local function Own(sender)
 if sender==UnitName("player")then return true end
 if type(sender)~="string"then return false end
 local n,r=UnitFullName("player");local C=GC.TrustBoundary
 return C and (C:CanonicalName(sender)==C:CanonicalName((n or UnitName("player")).."-"..(r or GetRealmName()))or C:CanonicalName(sender)==C:CanonicalName((n or UnitName("player")).."-"..GetRealmName()))
end
local function Num(v,max)
 local n=tonumber(v);if not n or n~=n or n<0 or n>max then return nil end;return n
end
local function Tuple(n,r)return string.format("%.0f:%.0f",r,n)end
function L:Begin()
 self.epoch=self.epoch+1;self.pending=true;self.completeRoot=nil;self.candidate=nil;self.publicInfo=nil;self.revision=self.revision+1
 self.helloAt=GetTime()
end
function L:Complete()
 self.pending=false
 local epoch=self.epoch
 C_Timer.After(0,function()
  if L.epoch~=epoch or L.pending then return end
  L.completeRoot=_G.LadderFrame and _G.LadderFrame.BracketsByTypeData
  L:Capture(true)
 end)
end
function L:Capture(force)
 if not GC.db or not GC.Roster or self.pending then return false end
 local guild=GC:GetGuildKey();if not guild then return false end
 local ok=GC.UWoWMythic:Available();local frame=_G.LadderFrame
 local root=frame and frame.BracketsByTypeData
 if not ok or type(root)~="table"then return false end
 local rows=root[-2];if rows~=nil and type(rows)~="table"then return false end
 local size=0
 for _,mode in ipairs({-2,7,0,3,9})do
  if root[mode]~=nil and type(root[mode])~="table"then return false end
  size=size+(type(root[mode])=="table"and #root[mode]or 0)
 end
 -- A partial/merely stable table must never erase saved data or imply absence.
 if self.completeRoot~=root then return false end
 local members=GC.Roster.members or {};if #members>1500 then return false end
 if not GC.Roster:MembershipSnapshot()then return false end
 local keys={};for _,m in ipairs(members)do keys[#keys+1]=tostring(m.guid)..":"..tostring(m.fullName or m.name)end
 local signature=table.concat(keys,"|")
 if not force and self.savedRoot==root and self.savedSize==size and self.savedGuild==guild and self.savedSignature==signature and self.savedRevision==self.revision then return true end
 local index={};local count=0
 for _,row in pairs(rows or {})do
  count=count+1;if count>50000 or type(row)~="table"then return false end
  local n,r=Num(row.guid,4503599627370495),Num(row.realm_id,100000)
  local rating,runs=Num(row.rating,100000000),Num(row.season_games,100000000)
  if not n or n<1 or not r or not rating or not runs or n%1~=0 or r%1~=0 or runs%1~=0 then return false end
  local key=Tuple(n,r);if index[key]then return false end
  index[key]=row
 end
 local pvp={}
 for _,mode in ipairs({7,0,3,9})do
  local list=root[mode]
  if list~=nil and type(list)~="table"then return false end
  local idx={};pvp[mode]=idx
  local amount=0
  for _,row in pairs(list or {})do
   amount=amount+1;if amount>50000 then return false end
   local n,r=type(row)=="table"and Num(row.guid,4503599627370495),type(row)=="table"and Num(row.realm_id,100000)
   local rating=type(row)=="table"and Num(row.rating,100000000)
   if not n or n<1 or not r or not rating or n%1~=0 or r%1~=0 then return false end
   local key=Tuple(n,r);if idx[key]then return false end;idx[key]=row
  end
 end
 local records={};local matched,absent,unknown=0,0,0;local at=(self.savedRoot==root and not force and self.sourceAt)or time()
 for _,m in ipairs(members)do
  local n,r=GC.UWoWMythic:Resolve(m)
  if m.guid and n and r then
   local row=index[Tuple(n,r)]
   local data={guid=m.guid,realm=r,source="UWoW/loaded-ladder",updatedAt=at}
   if row then
    data.rating=tonumber(row.rating);data.totalRuns=tonumber(row.season_games)
    data.rank=type(row.ranks)=="table"and Num(row.ranks.by_all,100000000)or nil
    data.classRank=type(row.ranks)=="table"and Num(row.ranks.by_class,100000000)or nil
    data.identity={name=row.name,classID=row.class_id,raceID=row.race_id,fakeRaceID=row.fake_race_id,genderID=row.gender_id,factionID=row.faction_id}
    matched=matched+1
   else data.absent=true;absent=absent+1 end
   data.pvp={}
   for _,mode in ipairs({7,0,3,9})do
    local row=pvp[mode][Tuple(n,r)]
    if row then
     local extra=self.publicInfo and self.publicInfo.root==root and self.publicInfo.pvp[mode]and self.publicInfo.pvp[mode][Tuple(n,r)]
     -- Native tables omit season_games and faction; only same-snapshot public
     -- HELLO rows can supplement them. Never carry an old counter into new data.
     local games=Num(row.season_games,100000000)
     if not games and extra and extra.rating==tonumber(row.rating)then games=extra.games end
     local d={rating=tonumber(row.rating),seasonGames=games,
      rank=type(row.ranks)=="table"and Num(row.ranks.by_all,100000000)or nil,
      classRank=type(row.ranks)=="table"and Num(row.ranks.by_class,100000000)or nil,
      name=row.name,classID=row.class_id,raceID=row.race_id,genderID=row.gender_id,
      factionID=extra and extra.factionID or row.faction_id,
      gamesSource=games~=nil and (row.season_games~=nil and "native-memory"or "native-HELLO-observed")or "not-retained"}
     if games and games%1~=0 then return false end
     data.pvp[mode]=d
    end
   end
   local profiles=frame.PlayerTooltipProfileData
   local profile=type(profiles)=="table"and profiles[r]and profiles[r][n]
   local previous=type(profile)=="table"and profile[-2]and profile[-2].prev_rating
   if type(previous)=="table"then
    local v={};for _,key in ipairs({"total","tank","heal","dps"})do v[key]=Num(previous[key],100000000)end
    if v.total or v.tank or v.heal or v.dps then data.previousRating=v end
   end
   local all=frame.PlayerStatisticData
   local details=type(all)=="table"and type(all[r])=="table"and all[r][n]
   if type(details)=="table"then
    local detail=details[-2]
    if not data.absent and type(detail)=="table"and type(detail.rating)=="table"and type(detail.completed_runs)=="table"
      and Num(detail.rating.curr,100000000)==data.rating and Num(detail.completed_runs.total,100000000)==data.totalRuns then
     local agg={roles={},ranges={},source="UWoW/profile-memory",freshness="unknown"}
     for _,key in ipairs({"tank","heal","dps"})do agg.roles[key]=Num(detail.rating[key],100000000)end
     for _,key in ipairs({"c_2_4","c_5_9","c_10_14","c_15_19","c_20_24","c_25_29","c_30_34","c_35_above"})do agg.ranges[key]=Num(detail.completed_runs[key],100000000)end
     data.profile=agg
    end
    for _,mode in ipairs({7,0,3,9})do
     local target=data.pvp[mode];local detail=details[mode]
     if target and type(detail)=="table"and type(detail.season)=="table"and Num(detail.season.rating,100000000)==target.rating
       and (target.seasonGames==nil or Num(detail.season.games,100000000)==target.seasonGames)then
      local agg={source="UWoW/profile-memory",freshness="unknown"}
      for _,period in ipairs({"week","season","last_season"})do
       local src=detail[period]
       if type(src)=="table"then
        local dst={};for _,key in ipairs({"games","games_win","rating","mmr"})do dst[key]=Num(src[key],100000000)end
        if not dst.games_win or not dst.games or dst.games_win<=dst.games then agg[period]=dst end
       end
      end
      target.profile=agg
      if target.seasonGames==nil and agg.season and agg.season.games~=nil then target.seasonGames=agg.season.games;target.gamesSource="native-profile-memory"end
     end
    end
   end
   records[m.guid]=data
  else unknown=unknown+1 end
 end
 local db=GC.db.mythicLadderCache
 if type(db)~="table"or db.schema~=1 or type(db.guilds)~="table"then db={schema=1,guilds={}};GC.db.mythicLadderCache=db end
 if not db.guilds[guild]then local c=0;for _ in pairs(db.guilds)do c=c+1 end;if c>=30 then return false end end
 if GC.LadderRefresh then GC.LadderRefresh:Preserve(records,db.guilds[guild])end
 local prior=db.guilds[guild] and db.guilds[guild].records
 for guid,old in pairs(prior or{})do
  local member=GC.Roster:FindByKey(guid)
  if not records[guid]or(member and not member.online and records[guid].absent)then records[guid]=old end
 end
 db.guilds[guild]={updatedAt=at,source="UWoW/loaded-ladder",records=records,rows=count,matched=matched,absent=absent,unknown=unknown,readiness=self.completeRoot==root and "observed-complete"or "preloaded-stable"}
 self.sourceAt=at;self.savedRoot=root;self.savedSize=size;self.savedGuild=guild;self.savedSignature=signature;self.savedRevision=self.revision
 if GC.LadderRefresh then GC.LadderRefresh:Plan()end
 return true
end
function L:Cached(member)
 local db=GC.db and GC.db.mythicLadderCache;local guilds=type(db)=="table"and db.guilds
 local snapshot=type(guilds)=="table"and guilds[GC:GetGuildKey()]
 return member and type(snapshot)=="table"and type(snapshot.records)=="table"and snapshot.records[member.guid]or nil
end
function L:Status(member)
 local d=self:Cached(member);if not d then return "unknown"end
 return d.absent and "absent"or "present",d
end
-- Observe ONLY the public aggregate opcode already sent by native UWoW.
function L:ObservePublic(message)
 if type(message)~="string"or #message>8192 or message:find("[%z\1-\31\127]")then return false end
 if not message:match("^SMSG_RT_HELLO_PVP_BRACKETS_RESPONSE|")then return false end
 if not GC.UWoWMythic:Available()then return false end
 local frame=_G.LadderFrame;local root=frame and frame.BracketsByTypeData
 if type(root)~="table"then return false end
 local fields={};for v in (message.."|"):gmatch("(.-)|")do fields[#fields+1]=v;if #fields>4096 then return false end end
 if fields[#fields]==""then table.remove(fields)end
 table.remove(fields,1)
 if #fields<11 or #fields%11~=0 then return false end
 local batch={}
 for i=1,#fields,11 do
  local mode=tonumber(fields[i]);local n,r=Num(fields[i+1],4503599627370495),Num(fields[i+3],100000)
  local rating,games=Num(fields[i+9],100000000),Num(fields[i+10],100000000)
  if not n or n<1 or n%1~=0 or not r or r%1~=0 or not rating or not games or games%1~=0 then return false end
  if ({[7]=true,[0]=true,[3]=true,[9]=true})[mode]then
   batch[#batch+1]={mode=mode,key=Tuple(n,r),rating=rating,games=games,factionID=Num(fields[i+4],100)}
  end
 end
 local info=self.publicInfo
 if not info or info.root~=root then info={root=root,pvp={},count=0};self.publicInfo=info end
 local additions=0;local unique={}
 for _,v in ipairs(batch)do
  local key=v.mode..":"..v.key
  if not(info.pvp[v.mode]and info.pvp[v.mode][v.key])and not unique[key]then additions=additions+1;unique[key]=true end
 end
 if info.count+additions>50000 then return false end
 for _,v in ipairs(batch)do info.pvp[v.mode]=info.pvp[v.mode]or {};info.pvp[v.mode][v.key]=v end
 info.count=info.count+additions;self.revision=self.revision+1
 return true
end
if type(hooksecurefunc)=="function"and type(SendAddonMessage)=="function"then
 hooksecurefunc("SendAddonMessage",function(prefix,message,channel,target)
  if prefix=="UIMSG_TO_SERVER"and channel=="WHISPER"and target==UnitName("player")and(message=="CMSG_RT_HELLO\t"or message=="CMSG_RT_HELLO")then L:Begin()end
 end)
end
local f=CreateFrame("Frame");f:RegisterEvent("CHAT_MSG_ADDON");f:RegisterEvent("GUILD_ROSTER_UPDATE");f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function(_,event,prefix,message,channel,sender)
 if event=="CHAT_MSG_ADDON"then
  if prefix=="UISMSG_TO_CLIENT"and channel=="WHISPER"and Own(sender)then
   L:ObservePublic(message)
   if type(message)=="string"and #message<=8192 and message:match("^SMSG_RT_PLAYER_STATISTIC_CREATE|%d+|%d+|[%-0-9]+|?$")then L.revision=L.revision+1 end
  end
  if prefix=="UISMSG_TO_CLIENT"and channel=="WHISPER"and Own(sender)and(message=="SMSG_RT_HELLO_COMPLETE"or message=="SMSG_RT_HELLO_COMPLETE|")then L:Complete()end
 else L:Capture()end
end)
f:SetScript("OnUpdate",function(_,elapsed)
 L.elapsed=(L.elapsed or 0)+elapsed
 if L.elapsed>=5 then L.elapsed=0;L:Capture()end
end)
