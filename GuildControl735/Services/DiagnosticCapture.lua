-- Local diagnostics only. Does not call or hook guild-management functions.
local addonName,G=...
local C={sessionLimit=8,maxSeconds=600};G.DiagnosticCapture=C
-- Metadata only; no Lua error handler, external error database or stack capture.
local function clip(v,n)
 if type(v)~="string"and type(v)~="number"and type(v)~="boolean"then return ""end
 local s=tostring(v):gsub("[%c]"," ")
 if #s<=n then return s end
 return(s:sub(1,n):gsub("[\194-\244][\128-\191]*$",""))
end
local function stamp()return date("%Y-%m-%d %H:%M:%S")end
local function currentCVar()
 if type(GetCVar)~="function"then return nil end
 local ok,v=pcall(GetCVar,"taintLog");return ok and tonumber(v)or nil
end
local function writeCVar(value)
 if type(SetCVar)~="function"then return false end
 local ok=pcall(SetCVar,"taintLog",tostring(value));return ok and currentCVar()==value
end
function C:Record(kind,detail)
 if G.Diagnostics then G.Diagnostics:Record(kind,detail)end
end
function C:SessionInfo()
 if not self.session then return end
 local s=self.session
 s.actor=clip(UnitName and UnitName("player"),160);s.guid=clip(UnitGUID and UnitGUID("player"),100)
 s.realm=clip(GetRealmName and GetRealmName(),120);s.guild=clip(GetGuildInfo and GetGuildInfo("player"),180)
 s.locale=clip(GetLocale and GetLocale(),16)
 if GetBuildInfo then local version,build,_,iface=GetBuildInfo();s.client=clip(version,40);s.clientBuild=clip(build,40);s.interface=tonumber(iface)end
 s.addons={};s.addonsOmitted=0
 if GetNumAddOns and GetAddOnInfo and IsAddOnLoaded then
  for i=1,math.min(GetNumAddOns(),512)do
   local name=GetAddOnInfo(i)
   if name and IsAddOnLoaded(name)then
    if #s.addons<256 then
     s.addons[#s.addons+1]={name=clip(name,100),version=clip(GetAddOnMetadata and GetAddOnMetadata(i,"Version"),80)}
    else s.addonsOmitted=(s.addonsOmitted or 0)+1 end
   end
  end
 end
end
function C:Initialize(db)
 local t=db.diagnosticCapture
 if type(t)~="table"or t.schema~=1 then t={schema=1,sequence=0,errors={},sessions={},dropped=0};db.diagnosticCapture=t end
 t.errors=type(t.errors)=="table"and t.errors or{};t.sessions=type(t.sessions)=="table"and t.sessions or{}
 t.sequence=math.max(0,tonumber(t.sequence)or 0);t.dropped=math.max(0,tonumber(t.dropped)or 0);t.nativeDropped=math.max(0,tonumber(t.nativeDropped)or 0)
 -- Historical error records stay saved; this version neither collects nor imports errors.
 -- Retain bounded metadata from our schema, with no arbitrary saved subtables.
 local sessions={}
 for i=math.max(1,#t.sessions-self.sessionLimit+2),#t.sessions do
  local old=t.sessions[i]
  if type(old)=="table"then
   local s={}
   for _,key in ipairs({"at","ended","reason","build","provenance","actor","guid","realm","guild","locale","client","clientBuild","source","id","interface","elapsed","taintStarts","taintStops","addonsOmitted"})do
    if type(old[key])=="number"then s[key]=old[key]else s[key]=clip(old[key],200)end
   end
   s.addons={};if type(old.addons)=="table"then for k=1,math.min(#old.addons,256)do local a=old.addons[k];if type(a)=="table"then s.addons[#s.addons+1]={name=clip(a.name,100),version=clip(a.version,80)}end end end
   sessions[#sessions+1]=s
  end
 end
 t.sessions=sessions;self.db=t;self.started=GetTime()
 self.session={id=G.Diagnostics.db.session,at=stamp(),build=G.build,provenance="GC735_103_FROM_8D8BA0E1_COOPERATIVE_SURVEY",taintStarts=0,taintStops=0}
 sessions[#sessions+1]=self.session;self:SessionInfo()
 -- A lease is only recovery information, never an instruction to resume logging.
 local lease=t.taintLease;t.taintLease=nil
 if type(lease)=="table"and tonumber(lease.previous)and currentCVar()==2 then
  local ok=writeCVar(tonumber(lease.previous));self:Record("TAINT_RECOVERY",ok and "previous value restored; no resume"or"restore failed; check taintLog")
 end
end
function C:StartTaint()
 if not self.db or self.lease then return false end
 local before=currentCVar()
 if before==nil then self.notice=(G:Text("taintLog недоступен в этом клиенте."));return false end
 if not writeCVar(2)then
  if currentCVar()==2 and before~=2 then
   if not writeCVar(before)then self.lease={previous=before,started=GetTime()};self.db.taintLease={previous=before}end
  end
  self.notice=(G:Text("Не удалось подтвердить включение taintLog. Проверьте его значение и сообщения игры."));self:Record("TAINT_START_FAILED",tostring(currentCVar()));return false
 end
 self.lease={previous=before,started=GetTime()};self.db.taintLease={previous=before}
 self.session.taintStarts=self.session.taintStarts+1;self.notice=(G:Text("Запись включена. Повторите ошибку и остановите запись."))
 self:Record("TAINT_START","previous="..before.." requested=2; limit=600s");return true
end
function C:StopTaint(reason)
 local lease=self.lease
 if not lease then return false end
 local now=currentCVar();local ok=true
 if now==nil then ok=false elseif now==2 then ok=writeCVar(lease.previous)end
 if not ok then
  self.nextStopAttempt=GetTime()+30
  self.notice=(G:Text("Не удалось остановить taintLog. Повторите отключение."));self:Record("TAINT_STOP_FAILED",reason or"manual");return false
 end
 self.lease=nil;self.nextStopAttempt=nil;self.db.taintLease=nil;self.session.taintStops=self.session.taintStops+1
 self.notice=now~=2 and(G:Text("Настройка изменена извне; её значение сохранено."))or(lease.previous~=0 and(G:Text("Восстановлена прежняя запись taintLog. Для полного выключения нажмите ещё раз."))or(G:Text("Запись taintLog остановлена.")))
 self:Record("TAINT_STOP",(reason or"manual").."; current="..tostring(currentCVar()));return true
end
function C:ManualStop()
 if self.lease then return self:StopTaint("manual")end
 -- A deliberate second click can turn off recording started outside our session.
 local ok=writeCVar(0);self.notice=ok and(G:Text("Запись taintLog выключена."))or(G:Text("Не удалось выключить taintLog."))
 self:Record("TAINT_MANUAL_OFF",ok and"0"or"failed");return ok
end
function C:Update()
 if not self.db then return end
 self.session.elapsed=math.max(0,math.floor(GetTime()-self.started))
 local value=currentCVar();local canStop=not self.nextStopAttempt or GetTime()>=self.nextStopAttempt
 if self.lease and value~=2 and canStop then self:StopTaint("external change")
 elseif self.lease and GetTime()-self.lease.started>=self.maxSeconds and canStop then self:StopTaint("timeout")end
end
function C:Finish(reason)
 if not self.db then return end
 self:Update();if self.lease then self:StopTaint(reason)end
 self.session.ended=stamp();self.session.reason=reason
end
function C:Text()
 if not self.db then return "\nRecording sessions not initialized."end
 self:Update()
 local out={"\n=== Guild Control recording sessions ===",
  "taintLog="..tostring(currentCVar()).."; owned="..tostring(self.lease~=nil).."; native Logs/taint.log is a separate file."}
 for _,s in ipairs(self.db.sessions)do
  out[#out+1]=string.format("SESSION %s %s %s %s / %s / %s source=%s elapsed=%s ended=%s",tostring(s.id),s.at or"",s.build or"",s.actor or"",s.realm or"",s.guild or"",s.source or"",tostring(s.elapsed or 0),s.ended or"")
  out[#out+1]="client="..tostring(s.client).." build="..tostring(s.clientBuild).." interface="..tostring(s.interface).." locale="..tostring(s.locale).." GUID="..tostring(s.guid)
  local a={};for _,x in ipairs(s.addons or{})do a[#a+1]=(x.name or"").." "..(x.version or"")end;out[#out+1]="loaded addons: "..table.concat(a,"; ")
 end
 return table.concat(out,"\n")
end
-- Extend only the local diagnostic service. Core, actions and transport stay intact.
local init=G.Diagnostics.Initialize
function G.Diagnostics:Initialize(db)init(self,db);C:Initialize(db)end
local observer=G.Diagnostics.SetObserver
function G.Diagnostics:SetObserver(...)observer(self,...);C:SessionInfo()end
local text=G.Diagnostics.Text
function G.Diagnostics:Text()return text(self)..C:Text()end
local f=CreateFrame("Frame");C.frame=f
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_LOGOUT"})do f:RegisterEvent(event)end
f:SetScript("OnEvent",function(_,event,owner,func)
 if event=="PLAYER_LOGOUT"then C:Finish("logout/reload")
 elseif event=="PLAYER_LOGIN"then C:SessionInfo()
 end
end)
local elapsed=0
f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0;C:Update()end)
