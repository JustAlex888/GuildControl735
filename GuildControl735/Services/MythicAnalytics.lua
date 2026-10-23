-- Local analytics only. No wire messages, guild permissions, or family inference.
local _,G=...
local A={};G.MythicAnalytics=A
A.ranges={"2-4","5-9","10-14","15-19","20-24","25-29","30-34","35+"}
A.profileRanges={"c_2_4","c_5_9","c_10_14","c_15_19","c_20_24","c_25_29","c_30_34","c_35_above"}
function A:State()
 G.db.ui=G.db.ui or{}
 local s=G.db.ui.mythicAnalytics
 local fresh=type(s)~="table"
 if type(s)~="table"then s={};G.db.ui.mythicAnalytics=s end
 s.classes=type(s.classes)=="table"and s.classes or{}
 s.roles=type(s.roles)=="table"and s.roles or{}
 -- Only a never-created analytics state receives new-install defaults.
 -- An existing empty column table means the user chose no optional columns.
 s.columns=type(s.columns)=="table"and s.columns or{}
 if fresh then
  s.window={width=1120,height=490}
  for _,key in ipairs({"total","2-4","5-9","10-14","15-19","20-24","25-29","30-34","35+","place","classPlace","rating","tank","heal","dps"})do s.columns[key]=true end
 end
 s.widths=type(s.widths)=="table"and s.widths or{}
 s.onlineDays=math.max(0,math.min(36500,tonumber(s.onlineDays)or 30))
 s.responseDays=math.max(0,math.min(36500,tonumber(s.responseDays)or 30))
 s.days=math.max(1,math.min(99,math.floor(tonumber(s.days)or 30)))
 s.startMinute=tonumber(s.startMinute)or 1140;s.endMinute=tonumber(s.endMinute)or 1260
 s.sort=s.sort or"name"
 return s
end
function A:ConfirmOwner(guid)
 -- Called only after existing live-session owner identity and summary admission.
 local root=G.FastRecords:Root();if not root then return end
 root.ownerResponses=root.ownerResponses or{}
 local count=0;for _ in pairs(root.ownerResponses)do count=count+1 end
 if root.ownerResponses[guid]or count<1500 then root.ownerResponses[guid]=time()end
end
function A:LastResponse(member)
 if member.guid==UnitGUID("player")then return time()end
 local root=G.db.fastSync and G.db.fastSync.guilds and G.db.fastSync.guilds[G:GetGuildKey()]
 return root and root.ownerResponses and tonumber(root.ownerResponses[member.guid])
end
function A:Minute(text)
 local h,m=tostring(text):match("^(%d%d?):(%d%d)$");h=tonumber(h);m=tonumber(m)
 if h and h<24 and m<60 then return h*60+m end
end
function A:InTime(stamp,s)
 -- Verified realm clock is UTC. Avoid the player's local timezone/date().
 local minute=math.floor(stamp/60)%1440
 if s.startMinute<=s.endMinute then return minute>=s.startMinute and minute<=s.endMinute end
 return minute>=s.startMinute or minute<=s.endMinute
end
function A:SelectedRoles(s)
 local count=0;for _,k in ipairs({"TANK","HEALER","DAMAGER"})do if s.roles[k]then count=count+1 end end
 return count>0 and count<3
end
function A:AttachRoles(target,data)
 -- Read only the public Mythic+ run members already populated by native AIO.
 -- Match target, immutable run ID/date/key and actual participant GUID/realm.
 local frame=_G.LadderFrame
 local all=frame and frame.PlayerStatisticData
 local owner=all and all[target.realm]and all[target.realm][target.number]
 local stat=owner and owner[-2];local groups=stat and stat.last_runs
 data.runRolesSchema=1
 if type(groups)~="table"or type(data.runs)~="table"then return end
 local wanted={};for _,r in ipairs(data.runs)do wanted[r.id]=r end
 local roles={[0]="TANK",[1]="HEALER",[2]="DAMAGER"};local visited=0
 for _,group in pairs(groups)do if type(group)=="table"then
  for id,run in pairs(group)do
   visited=visited+1;if visited>4096 then return end
   local r=wanted[tonumber(id)]
   if r and type(run)=="table"and tonumber(run.id)==r.id and tonumber(run.date)==r.date
    and tonumber(run.challenge_level)==r.level and type(run.members)=="table"then
    local found,conflict;local count=0
    for _,m in pairs(run.members)do
     count=count+1;if count>40 then conflict=true;break end
     if type(m)=="table"and tonumber(m.guid)==target.number and tonumber(m.realm_id)==target.realm then
      local role=roles[tonumber(m.role_id)]
      if not role or found and found~=role then conflict=true else found=role end
     end
    end
    if conflict then r.role=nil elseif found then r.role=found end
   end
  end
 end end
end
function A:Counts(d,s,now)
 local out={total=0,ranges={}};for _,k in ipairs(self.ranges)do out.ranges[k]=0 end
 if not d then return nil end
 if d.absent then return out end
 local p=d.profile
 local roleFilter=self:SelectedRoles(s)
 if not s.periodEnabled and not s.timeEnabled and not roleFilter then
  out.total=d.totalRuns
  for i,k in ipairs(self.ranges)do out.ranges[k]=p and p.ranges and p.ranges[self.profileRanges[i]]end
  return out
 end
 if not p or p.stale or not p.runsComplete or type(p.runs)~="table"then return nil end
 for _,r in ipairs(p.runs)do
  if type(r.date)=="number"and type(r.level)=="number"and r.date<=now
   and(not s.periodEnabled or r.date>=now-s.days*86400)
   and(not s.timeEnabled or self:InTime(r.date,s))then
   if roleFilter and not r.role then return nil end
   if not roleFilter or s.roles[r.role]then
    out.total=out.total+1
    local index=r.level>=35 and 8 or r.level>=5 and math.floor(r.level/5)+1 or 1
    local key=self.ranges[index];if key then out.ranges[key]=out.ranges[key]+1 end
   end
  end
 end
 return out
end
function A:Rows()
 local s=self:State();local out={};local now=time();local selected=false
 for _,v in pairs(s.classes)do if v then selected=true end end
 for _,m in ipairs(G.Roster.members or{})do
  local age=m.online and 0 or tonumber(m.offlineDays)
  local response=self:LastResponse(m)
  if G.AnalyticsSearch:Matches("mythic",m)and(not selected or s.classes[m.classFile])
   and(not s.onlineOnly or m.online)
   and(not s.onlineEnabled or age and age<=s.onlineDays)
   and(not s.responseEnabled or response and response<=now and now-response<=s.responseDays*86400)then
   local d=G.MythicLadder:Cached(m)
   if self:SelectedRoles(s)and d and d.profile and G.UWoWMythic and G.UWoWMythic:Available()then
    local number,realm=G.UWoWMythic:Resolve(m)
    if number then self:AttachRoles({number=number,realm=realm},d.profile)end
   end
   local counts=self:Counts(d,s,now)
   local row={member=m,name=m.name or m.fullName or"",class=m.class or m.classFile or"",level=m.level,rank=m.rank,
    total=counts and counts.total,place=d and d.rank,classPlace=d and d.classRank,rating=d and d.rating}
   for _,k in ipairs(self.ranges)do row[k]=counts and counts.ranges[k]end
   for _,k in ipairs({"tank","heal","dps"})do row[k]=d and d.profile and d.profile.roles and d.profile.roles[k]end
   if d and d.absent then row.rating=0;row.tank=0;row.heal=0;row.dps=0 end
   if not self:SelectedRoles(s)or counts and counts.total>0 then out[#out+1]=row end
  end
 end
 table.sort(out,function(a,b)
  local av,bv=a[s.sort],b[s.sort]
  if av==bv then return a.name<b.name end
  if av==nil then return false elseif bv==nil then return true end
  if s.descending then return av>bv else return av<bv end
 end)
 return out
end
