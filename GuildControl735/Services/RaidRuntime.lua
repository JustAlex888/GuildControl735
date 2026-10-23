local _, GC=...
function GC:CreateRaidRuntime(A)
local W=A.RaidWire
local R={}
local function Guild()
 if not IsInGuild()then return nil end
 local name=GetGuildInfo("player");if not name then return nil end
 return (GetRealmName()or"").."\031"..name
end
function R:Index()
 local byName,byGuid={},{};local guids={}
 for i=1,math.min(GetNumGuildMembers(true)or 0,1000)do
  local row={GetGuildRosterInfo(i)};local name,guid=row[1],row[17]
  if name and W.GUID(guid)and #guids<500 then
   local canonical=W.Canonical(name,GetRealmName())
   if canonical then byName[canonical]=guid;byGuid[guid]={name=name,online=row[9]and not row[14]};guids[#guids+1]=guid end
  end
 end
 table.sort(guids);self.byName=byName;self.byGuid=byGuid;self.guids=guids
end
function R:Resolve(sender)
 return self.byName and self.byName[W.Canonical(sender,GetRealmName())or""]
end
function R:Database()
 if not A.db then return nil end
 local key=Guild();if not key then return nil end
 -- Additive storage; no migration or changes to existing schema/profiles.
 A.db.raidSnapshots=A.db.raidSnapshots or {guilds={}}
 local root=A.db.raidSnapshots.guilds
 if not root[key]then
  local count=0;for _ in pairs(root)do count=count+1 end
  if count>=10 then return nil end
  root[key]={records={}}
 end
 return root[key]
end
function R:Get(guid)
 local host=_G.GuildControl735ShellWindow
 if not self.publisher and guid==UnitGUID("player")and host and host.GetOwnRaidSnapshot then return host.GetOwnRaidSnapshot()end
 local db=self:Database();local r=db and db.records[guid]
 if type(r)~="table"or r.map~=1 or type(r.values)~="table"or #r.values~=160 or type(r.capturedAt)~="number"then return nil end
 if not self.byGuid or not self.byGuid[guid]then return nil end
 return r
end
function R:Save(record)
 local db=self:Database();if not db or not self.byGuid[record.guid]then return end
 local old=db.records[record.guid]
 if type(old)=="table"and type(old.values)=="table"then
  for i=1,160 do if old.values[i]and old.values[i]~="u"and record.values[i]=="u"then return false end end
 end
 if not old or old.capturedAt<=record.capturedAt then db.records[record.guid]=record end
 if self.batch and self.batch.expected[record.guid]then self.batch.got[record.guid]=true end
 return true
end
function R:Collect()
 local values,known=W.Capture();local guid=UnitGUID("player")
 local db=self:Database()
 if db and W.GUID(guid)then
  local at=time();local frames,hash=W.Frames(guid,at,values)
  if frames then
   self:Save({guid=guid,capturedAt=at,receivedAt=at,hash=hash,values=values,map=1,source="Satellite/self-report"})
  end
 end
 self.known=known;return values
end
function R:Initialize(publisher)
 if self.engine or not RegisterAddonMessagePrefix or not SendAddonMessage then return end
 self.publisher=publisher;self:Index()
 local function DB()return R:Database()end
 self.engine=W.New({guild=Guild,clock=GetTime,wall=time,guid=function()return UnitGUID("player")end,
  resolve=function(sender)return R:Resolve(sender)end,
  admit=function(msg)return A.SecureExchange and (A.SecureExchange.receiving or (A.SecureExchange.dispatch and msg=="Q|1|ALL"))end,
  authorize=function(sender)if A.AdminTrust then return A.AdminTrust:Allowed(sender)end;return false,"missing_trust_module"end,
  get=function(guid)return R:Get(guid)end,save=function(record)R:Save(record)end,
  capture=publisher and function()return R:Collect()end or nil,
  lastPublished=function()local db=DB();return db and type(db.publishedAt)=="table"and tonumber(db.publishedAt[UnitGUID("player")])or 0 end,
  published=function(at)local db=DB();if db then db.publishedAt=type(db.publishedAt)=="table"and db.publishedAt or {};db.publishedAt[UnitGUID("player")]=at end end,
  canSend=function()return not UnitAffectingCombat("player")end,
  delay=function()
   local slot=1;for i,g in ipairs(R.guids)do if g==UnitGUID("player")then slot=i;break end end
   return 2+(slot-1)*0.10+math.random()*0.10
  end,
  asyncSend=A.DataExchange~=nil,
  send=function(msg,onSent)
   if A.DataExchange then
    local key=A:GetGuildKey();local requester=R.engine and R.engine.pendingSender
    return A.SecureExchange:Send(W.prefix,msg,function()return key==A:GetGuildKey() and (msg:match("^D|") and requester and A.AdminTrust:Allowed(requester) or msg:match("^Q|") and A.AdminTrust:OwnAllowed())end,onSent)
   end
   SendAddonMessage(W.prefix,msg,"GUILD")
  end})
 RegisterAddonMessagePrefix(W.prefix)
 local f=CreateFrame("Frame");self.frame=f
 for _,event in ipairs({"CHAT_MSG_ADDON","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","ENCOUNTER_END"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,event,prefix,msg,channel,sender,success)
  if event=="CHAT_MSG_ADDON"then
   if prefix~=W.prefix or channel~="GUILD"then return end
   if prefix==W.prefix then
    if A.SpamShield and A.SpamShield:IsBlocked(sender)then return end
    A.SecureExchange:Reject("raw_raid_without_session",sender);return
   end
   if prefix==W.prefix and (not publisher or R.unified or type(msg)~="string"or not msg:match("^D|"))then
    local started=debugprofilestop();R.engine:Receive(msg,sender,channel)
    local ms=debugprofilestop()-started;R.rxCpuTotal=(R.rxCpuTotal or 0)+ms;R.rxCpuMax=math.max(R.rxCpuMax or 0,ms)
   end
  elseif event=="ENCOUNTER_END"then
   -- Only successful encounters refresh self; never trigger a broadcast.
   if publisher and success==1 then R.collectAt=GetTime()+5 end
  else
   R:Index();R.engine:Scope()
   local db=DB();if db then for guid,rec in pairs(db.records)do
    if type(rec)~="table"or type(rec.receivedAt)~="number"then db.records[guid]=nil end
   end end
   if db and type(db.publishedAt)=="table"then for guid in pairs(db.publishedAt)do if A.Roster:CanPrune()and not A.Roster:FindByKey(guid)then db.publishedAt[guid]=nil end end end
   if publisher then R.collectAt=GetTime()+5 end
   if R.batch and R.batch.guild~=Guild()then R.batch=nil end
  end
 end)
 f:SetScript("OnUpdate",function(_,elapsed)
  R.elapsed=(R.elapsed or 0)+elapsed;if R.elapsed<0.10 then return end;R.elapsed=0
  R.engine:Tick()
  if R.collectAt and GetTime()>=R.collectAt then
   R.collectAt=nil;if not UnitAffectingCombat("player")then R:Collect()else R.collectAt=GetTime()+5 end
  end
  if R.batch and not A.SecureExchange.job and not A.SecureExchange:Valid(A.SecureExchange.grant)then R.batch.finished=true end
 end)
 if publisher then self.collectAt=GetTime()+5 end
end
function R:Request(guid)
 if not self.engine then return false end
 if self.unified and guid==UnitGUID("player")then self:Collect();return true end
 local host=_G.GuildControl735ShellWindow
 if guid==UnitGUID("player")and not self.publisher and host and host.GetOwnRaidSnapshot then
  host.GetOwnRaidSnapshot(true);return true
 end
 if guid~="ALL"and (not self.byGuid[guid]or not self.byGuid[guid].online)then return false,"offline"end
 if not A.AdminTrust or not A.AdminTrust:OwnAllowed()then return false,(GC:Text("Нет разрешения главы на запрос данных"))end
 local expected={}
 for g,m in pairs(self.byGuid)do if m.online and (guid=="ALL"or g==guid)then expected[g]=true end end
 local ok,why=A.SecureExchange:Request(guid)
 if ok then
  local got={};for g in pairs(expected)do local r=self:Get(g);if r and time()-r.capturedAt<=120 then got[g]=true end end
  self.batch={guild=Guild(),started=GetTime(),expected=expected,got=got}
 end
 return ok,why
end
function R:Progress()
 local b=self.batch;if not b then return ""end
 local n,k=0,0;for g in pairs(b.expected)do n=n+1;if b.got[g]then k=k+1 end end
 return (b.finished and (GC:Text("Завершено: "))or(GC:Text("Получено: ")))..k.." / "..n..(GC:Text(". Без ответа — данные не получены."))
end
function R:Counts()
 local b=self.batch;local got,total=0,0
 if b then for g in pairs(b.expected)do total=total+1;if b.got[g]then got=got+1 end end end
 return got,total
end
function R:Stop()
 -- Local cancellation cannot recall an already sent guild request.
 self.batch=nil
 if A.DataExchange then A.DataExchange:Stop()end
 if self.engine then self.engine.pending=nil;self.engine.queue=nil end
end
local bossNames=GC:RegisterLocaleTable({},function()return {
 {(GC:Text("Низендра")),(GC:Text("Элерет Дикая Лань")),(GC:Text("Ил’гинот")),(GC:Text("Урсок")),(GC:Text("Драконы Кошмара")),(GC:Text("Кенарий")),(GC:Text("Ксавий"))},
 {(GC:Text("Один")),(GC:Text("Гарм")),(GC:Text("Хелия"))},
 {(GC:Text("Скорпирон")),(GC:Text("Хрономатическая аномалия")),(GC:Text("Триллиакс")),(GC:Text("Алуриэль")),(GC:Text("Звёздный авгур Этрей")),(GC:Text("Верховный ботаник Тел’арн")),(GC:Text("Тихондрий")),(GC:Text("Крос")),(GC:Text("Великий магистр Элисанда")),(GC:Text("Гул’дан"))},
 {(GC:Text("Горот")),(GC:Text("Демоническая инквизиция")),(GC:Text("Харджатан")),(GC:Text("Сёстры Луны")),(GC:Text("Госпожа Сашж’ин")),(GC:Text("Сонм страданий")),(GC:Text("Бдительная дева")),(GC:Text("Аватара Падшего")),(GC:Text("Кил’джеден"))},
 {(GC:Text("Разрушитель миров Кин’гарота")),(GC:Text("Ловчие Саргераса")),(GC:Text("Военный совет Анторуса")),(GC:Text("Хранительница порталов Азабель")),(GC:Text("Эонар")),(GC:Text("Имонар")),(GC:Text("Кин’гарот")),(GC:Text("Вариматрас")),(GC:Text("Ковен Шиварр")),(GC:Text("Агграмар")),(GC:Text("Аргус Порабощённый"))}
} end)
function R:Rows(guid,detail)
 local r=self:Get(guid)
 if not r then return (GC:Text("Рейдовая статистика не получена.\nДля обновления нужен разрешённый запрос доверенного персонажа и игрок онлайн с Guild Control."))end
 local rows={}
 local start=0
 for raidIndex,raid in ipairs(W.raids)do
  rows[#rows+1]=raid.name
  local labels={(GC:Text("Поиск рейда")),(GC:Text("Обычный")),(GC:Text("Героический")),(GC:Text("Эпохальный"))}
  for d=1,4 do
   local kills,known=0,0
   for b=1,raid.bosses do local v=r.values[start+(b-1)*4+d];if W.Value(v)and v~="u"then known=known+1;if tonumber(v)>0 then kills=kills+1 end end end
   rows[#rows+1]=A:StatLabel(labels[d],(known==0 and"—"or tostring(kills)).." / "..raid.bosses)
  end
  if detail then
   for b=1,raid.bosses do
    local name=bossNames[raidIndex][b]
    local vs={};for d=1,4 do local v=r.values[start+(b-1)*4+d];vs[d]=W.Value(v)and v~="u"and v or"—"end
    rows[#rows+1]=A:StatLabel(name,table.concat(vs," / "))
   end
  end
  start=start+#raid.ids;rows[#rows+1]=""
 end
 return table.concat(rows,"\n")
end

return R
end
GC.RaidRuntime=GC:CreateRaidRuntime(GC)
