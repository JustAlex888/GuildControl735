-- Read-only projection of the existing admitted raid snapshot. No new transport.
local _,G=...
local R={};G.RaidAnalytics=R
R.difficulties=G:RegisterLocaleTable({},function()return {{id=1,name=(G:Text("Поиск рейда"))},{id=2,name=(G:Text("Обычный"))},{id=3,name=(G:Text("Героический"))},{id=4,name=(G:Text("Эпохальный"))}} end)
local bossNames=G:RegisterLocaleTable({},function()return {
 {(G:Text("Низендра")),(G:Text("Элерет Дикая Лань")),(G:Text("Ил’гинот")),(G:Text("Урсок")),(G:Text("Драконы Кошмара")),(G:Text("Кенарий")),(G:Text("Ксавий"))},
 {(G:Text("Один")),(G:Text("Гарм")),(G:Text("Хелия"))},
 {(G:Text("Скорпирон")),(G:Text("Хрономатическая аномалия")),(G:Text("Триллиакс")),(G:Text("Алуриэль")),(G:Text("Звёздный авгур Этрей")),(G:Text("Верховный ботаник Тел’арн")),(G:Text("Тихондрий")),(G:Text("Крос")),(G:Text("Великий магистр Элисанда")),(G:Text("Гул’дан"))},
 {(G:Text("Горот")),(G:Text("Демоническая инквизиция")),(G:Text("Харджатан")),(G:Text("Сёстры Луны")),(G:Text("Госпожа Сашж’ин")),(G:Text("Сонм страданий")),(G:Text("Бдительная дева")),(G:Text("Аватара Падшего")),(G:Text("Кил’джеден"))},
 {(G:Text("Разрушитель миров Кин’гарота")),(G:Text("Ловчие Саргераса")),(G:Text("Военный совет Анторуса")),(G:Text("Хранительница порталов Азабель")),(G:Text("Эонар")),(G:Text("Имонар")),(G:Text("Кин’гарот")),(G:Text("Вариматрас")),(G:Text("Ковен Шиварр")),(G:Text("Агграмар")),(G:Text("Аргус Порабощённый"))}
} end)
function R:Raids()
 local out={};for i,r in ipairs(G.RaidWire.raids)do out[#out+1]={id=i,name=r.name}end;return out
end
function R:EnableAllColumns(s)
 s.columns.progress=true
 for i,r in ipairs(G.RaidWire.raids)do for b=1,r.bosses do s.columns['r'..i..'b'..b]=true end end
end
function R:State()
 G.db.ui=G.db.ui or{};local s=G.db.ui.raidAnalytics
 local fresh=type(s)~="table";if fresh then s={};G.db.ui.raidAnalytics=s end
 s.classes=type(s.classes)=="table"and s.classes or{}
 s.columns=type(s.columns)=="table"and s.columns or{};if fresh then self:EnableAllColumns(s)end
 s.widths=type(s.widths)=="table"and s.widths or{}
 s.raid=type(s.raid)=="number"and G.RaidWire.raids[s.raid]and s.raid or 5
 s.difficulty=({[1]=true,[2]=true,[3]=true,[4]=true})[s.difficulty]and s.difficulty or 3
 for _,k in ipairs({"onlineDays","responseDays"})do local n=tonumber(s[k]);s[k]=n and n==n and math.max(0,math.min(36500,math.floor(n)))or 30 end
 local valid={name=true,class=true,level=true,rank=true,progress=true}
 for b=1,G.RaidWire.raids[s.raid].bosses do valid['r'..s.raid..'b'..b]=true end
 s.sort=valid[s.sort]and s.sort or"name"
 return s
end
function R:Definitions()
 local s=self:State();local out={{"name",G.L.HEADER_NAME,true},{"class",G.L.HEADER_CLASS,true},{"level",G.L.HEADER_LEVEL,true},{"rank",G.L.HEADER_RANK,true},{"progress",(G:Text("Прогресс"))}}
 for b,name in ipairs(bossNames[s.raid])do
  local heading=name:gsub(" ","\n",1)
  out[#out+1]={'r'..s.raid..'b'..b,name,false,heading}
 end
 return out
end
function R:Stats(record,raid,difficulty)
 local info=G.RaidWire.raids[raid];local out={};local known,killed=0,0;local offset=0
 if not record or record.map~=1 or type(record.values)~="table"then return out,(G:Text("Рейдовая статистика не получена."))end
 for i=1,raid-1 do offset=offset+#G.RaidWire.raids[i].ids end
 for b=1,info.bosses do
  local raw=record.values[offset+(b-1)*4+difficulty]
  local value=G.RaidWire.Value(raw);local n=value and value~="u"and tonumber(value)or nil
  out['r'..raid..'b'..b]=n
  if n~=nil then known=known+1;if n>0 then killed=killed+1 end end
 end
 if known>0 then out.progress=killed end
 out.savedAt=record.capturedAt
 return out,known==info.bosses and(G:Text("Полная статистика выбранного рейда и сложности."))or((G:Text("Известны показатели боссов: "))..known.." / "..info.bosses..(G:Text(". Прогресс показывает подтверждённые убийства, как сводка Общих данных; прочерки боссов не заменяются нулями.")))
end
function R:Format(key,value)
 if value==nil then return "—"end
 if key=="progress"then return value.."/"..G.RaidWire.raids[self:State().raid].bosses end
 return tostring(value)
end
function R:Rows()
 local s=self:State();local out={};local now=time();local selected=false
 for _,v in pairs(s.classes)do if v then selected=true end end
 for _,m in ipairs(G.Roster.members or{})do
  local age=m.online and 0 or tonumber(m.offlineDays);local response=G.MythicAnalytics:LastResponse(m)
  if G.AnalyticsSearch:Matches("raid",m)and(not selected or s.classes[m.classFile])and(not s.onlineOnly or m.online)
   and(not s.onlineEnabled or age and age<=s.onlineDays)
   and(not s.responseEnabled or response and response<=now and now-response<=s.responseDays*86400)then
   local stats,reason=self:Stats(G.RaidRuntime:Get(m.guid),s.raid,s.difficulty)
   local row={member=m,name=m.name or m.fullName or"",class=m.class or m.classFile or"",level=m.level,rank=m.rank,reason=reason}
   for k,v in pairs(stats)do row[k]=v end
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
function R:WidthSamples()
 local s=self:State()
 if self.widthMemo and self.widthMemo.raid==s.raid then return self.widthMemo.values end
 local out={progress={"11/11"}}
 -- RaidWire.Value bounds admitted counters at 1,000,000. Reserve full range.
 for b=1,G.RaidWire.raids[s.raid].bosses do out['r'..s.raid..'b'..b]={"1000000"}end
 self.widthMemo={raid=s.raid,values=out};return out
end
