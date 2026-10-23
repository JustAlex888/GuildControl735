-- Read-only projections of admitted aggregate caches. No match/member parsing.
local _,G=...
local P={};G.PvPAnalytics=P
P.modes=G:RegisterLocaleTable({},function()return {{id="all",name=(G:Text("Общая статистика"))},{id=7,name="1×1"},{id=0,name="2×2"},{id=3,name="RBG"},{id=9,name="SoloQ 2×2"}} end)
P.periods=G:RegisterLocaleTable({},function()return {{id="season",name=(G:Text("Сезон"))},{id="week",name=(G:Text("Неделя"))},{id="last_season",name=(G:Text("Прошлый сезон"))}} end)
P.metrics={"games","wins","losses","winrate","rating","mmr"}
local function number(n)
 return type(n)=="number"and n==n and n>=0 and n<=100000000 and n%1==0 and n or nil
end
function P:State()
 G.db.ui=G.db.ui or{};local s=G.db.ui.pvpAnalytics
 local fresh=type(s)~="table";if fresh then s={};G.db.ui.pvpAnalytics=s end
 s.classes=type(s.classes)=="table"and s.classes or{}
 s.columns=type(s.columns)=="table"and s.columns or{}
 if fresh then for _,k in ipairs(self.metrics)do s.columns[k]=true end end
 s.widths=type(s.widths)=="table"and s.widths or{}
 s.mode=({all=true,[7]=true,[0]=true,[3]=true,[9]=true})[s.mode]and s.mode or"all"
 s.period=({week=true,season=true,last_season=true})[s.period]and s.period or"season"
 for _,k in ipairs({"onlineDays","responseDays"})do local n=tonumber(s[k]);s[k]=n and n==n and math.max(0,math.min(36500,math.floor(n)))or 30 end
 s.sort=({name=true,class=true,level=true,rank=true,games=true,wins=true,losses=true,winrate=true,rating=true,mmr=true})[s.sort]and s.sort or"name"
 return s
end
function P:ModeStats(d,mode,period)
 local target=d and d.pvp and d.pvp[mode];local p=target and target.profile
 if not p or p.stale or p.pvpPeriodsSchema~=1 then return nil,(G:Text("Нет подтверждённой полной статистики режима. Нажмите «Обновить»."))end
 local v=p[period];if type(v)~="table"then return nil,(G:Text("Выбранный период не получен."))end
 local games,wins,rating,mmr=number(v.games),number(v.games_win),number(v.rating),number(v.mmr)
 if not games or not wins or wins>games or not rating or not mmr then return nil,(G:Text("Неполные или противоречивые показатели периода."))end
 return {games=games,wins=wins,losses=games-wins,winrate=games>0 and wins/games*100 or 0,rating=rating,mmr=mmr,savedAt=p.savedAt}
end
function P:Stats(d,mode,period)
 if mode~="all"then return self:ModeStats(d,mode,period)end
 local out={games=0,wins=0,losses=0}
 for _,m in ipairs(self.modes)do if m.id~="all"then
  local v=self:ModeStats(d,m.id,period)
  if not v then return nil,(G:Text("Общий итог неполный: нет подтверждённых данных одного или нескольких из четырёх режимов. Пропуски не считаются нулями."))end
  out.games=out.games+v.games;out.wins=out.wins+v.wins;out.losses=out.losses+v.losses
  if type(v.savedAt)=="number"then out.savedAt=math.min(out.savedAt or v.savedAt,v.savedAt)end
 end end
 out.winrate=out.games>0 and out.wins/out.games*100 or 0
 return out -- Rating/MMR deliberately undefined for a union of modes.
end
function P:Format(key,value)
 if value==nil then return "—"end
 if key=="winrate"then return string.format("%.1f%%",value)end
 return tostring(value)
end
function P:Rows()
 local s=self:State();local out={};local now=time();local selected=false
 for _,v in pairs(s.classes)do if v then selected=true end end
 for _,m in ipairs(G.Roster.members or{})do
  local age=m.online and 0 or tonumber(m.offlineDays);local response=G.MythicAnalytics:LastResponse(m)
  if G.AnalyticsSearch:Matches("pvp",m)and(not selected or s.classes[m.classFile])and(not s.onlineOnly or m.online)
   and(not s.onlineEnabled or age and age<=s.onlineDays)
   and(not s.responseEnabled or response and response<=now and now-response<=s.responseDays*86400)then
   local stats,reason=self:Stats(G.MythicLadder:Cached(m),s.mode,s.period)
   local row={member=m,name=m.name or m.fullName or"",class=m.class or m.classFile or"",level=m.level,rank=m.rank,reason=reason,savedAt=stats and stats.savedAt}
   for _,k in ipairs(self.metrics)do row[k]=stats and stats[k]end
   out[#out+1]=row
  end
 end
 table.sort(out,function(a,b)
  local av,bv=a[s.sort],b[s.sort]
  if av==bv then if a.name==b.name then return tostring(a.member.guid)<tostring(b.member.guid)end;return a.name<b.name end
  if av==nil then return false elseif bv==nil then return true end
  if s.descending then return av>bv else return av<bv end
 end)
 return out
end
function P:WidthSamples()
 -- Actual available values from all guild rows/modes/periods, independent of filters.
 local root=G.db.mythicLadderCache
 local snapshot=root and root.guilds and root.guilds[G:GetGuildKey()]
 local members=G.Roster.members or{}
 local memo=self.widthMemo;local revision=G.MythicLadder.revision;local completed=G.LadderRefresh and G.LadderRefresh.completed
 if memo and memo.snapshot==snapshot and memo.members==members and memo.count==#members and memo.revision==revision
  and memo.completed==completed and memo.reader==G.MythicLadder.Cached then return memo.values end
 local out={games={"388"},wins={"204"},losses={"184"},winrate={"100.0%"},rating={"1711"},mmr={"2013"}}
 for _,m in ipairs(G.Roster.members or{})do
  local d=G.MythicLadder:Cached(m)
  for _,period in ipairs(self.periods)do for _,mode in ipairs(self.modes)do
   local v=self:Stats(d,mode.id,period.id)
   if v then for _,key in ipairs(self.metrics)do if v[key]~=nil then out[key][#out[key]+1]=self:Format(key,v[key])end end end
  end end
 end
 self.widthMemo={snapshot=snapshot,members=members,count=#members,revision=revision,completed=completed,reader=G.MythicLadder.Cached,values=out}
 return out
end
