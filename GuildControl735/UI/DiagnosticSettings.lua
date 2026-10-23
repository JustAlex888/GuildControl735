local _,G=...
-- Advisory guild discovery; no remote URLs, commands, permissions or WHISPER sends.
local V={prefix='GC735VER',channel='TEST',links={issues='https://github.com/JustAlex888/GuildControl735/issues',releases='https://github.com/JustAlex888/GuildControl735/releases'},senders={}}
G.VersionCheck=V
local function version(s)
 if type(s)~='string'or #s>11 then return end
 local a,b,c=s:match('^(%d+)%.(%d+)%.(%d+)$');if not a then return end
 a,b,c=tonumber(a),tonumber(b),tonumber(c)
 if a>999 or b>999 or c>999 or s~=string.format('%d.%d.%d',a,b,c)then return end
 return a*1000000+b*1000+c
end
function V:Root()
 local r=G.db.versionNotice
 if type(r)~='table'then r={schema=1,guilds={}};G.db.versionNotice=r end
 r.guilds=type(r.guilds)=='table'and r.guilds or{}
 for key,row in pairs(r.guilds)do
  if type(row)~='table'or type(row.seenAt)~='number'or row.seenAt>time()or time()-row.seenAt>=86400 then r.guilds[key]=nil end
 end
 return r
end
function V:Known()
 local key=G:GetGuildKey();local row=key and self:Root().guilds[key]
 if type(row)=='table'and row.channel==self.channel and type(row.seenAt)=='number'and time()>=row.seenAt and time()-row.seenAt<86400 and version(row.version)and version(row.version)>(version(G.version)or math.huge)then return row.version,row.reporter end
end
function V:Announce()
 local now=GetTime();local guild=G:GetGuildKey()
 if not guild or not version(G.version)or now<(self.nextSend or 0)then return false end
 self.nextSend=now+30
 return G.DataExchange:Enqueue(self.prefix,'1|'..self.channel..'|'..G.version,function()return G:GetGuildKey()==guild end)
end
function V:Receive(msg,sender,channel)
 if channel~='GUILD'or not G:GetGuildKey()or type(msg)~='string'or #msg>32 then return false end
 local release,s=msg:match('^1|([A-Z]+)|([%d%.]+)$');local value=version(s)
 if release~=self.channel or not value then return false end
 local T=G.AdminTrust
 if T.key~=G:GetGuildKey()or not T.refreshed or GetTime()-T.refreshed>120 then return false end
 local name=G.TrustBoundary:CanonicalName(sender);local member=name and T.members[name]
 if not member or member.guid==UnitGUID('player')or(G.SpamShield and G.SpamShield:IsBlocked(sender))then return false end
 local now=GetTime();if now<(self.senders[name]or 0)then return false end
 local count=0;for _ in pairs(self.senders)do count=count+1 end
 if not self.senders[name]and count>=1000 then return false end
 self.senders[name]=now+60
 local own=version(G.version)
 if value>own then
  local root=self:Root();local key=G:GetGuildKey();local old=root.guilds[key]
  local fresh=type(old)=='table'and old.channel==self.channel and type(old.seenAt)=='number'and time()>=old.seenAt and time()-old.seenAt<86400 and version(old.version)
  if not fresh or value>=version(old.version)then
   local size=0;for _ in pairs(root.guilds)do size=size+1 end
   if not old and size>=30 then return false end
   root.guilds[key]={channel=self.channel,version=s,seenAt=time(),reporter=name,reporterGUID=member.guid}
  end
 elseif value<own then self.reply=true end
 return true
end
function V:Tick()
 local now=GetTime();local key=G:GetGuildKey()
 if key~=self.guild then self.guild=key;self.senders={};self.reply=nil;self.nextSend=nil;self.announceAt=now+15 end
 if key and(self.reply or now>=(self.announceAt or math.huge))and now>=(self.nextSend or 0)then
  if self:Announce()then self.reply=nil;self.announceAt=now+600 end
 end
 if now<(self.loginAt or now)+120 or(InCombatLockdown and InCombatLockdown())or(UnitAffectingCombat and UnitAffectingCombat('player'))then return end
 local known,reporter=self:Known();if not known then return end
 local root=self:Root();local at=tonumber(root.lastNoticeAt)
 if at and time()-at<86400 then return end
 if not DEFAULT_CHAT_FRAME then return end
 DEFAULT_CHAT_FRAME:AddMessage((G:Text('[GuildControl735] Согильдиец '))..tostring(reporter or''):gsub('|','||')..(G:Text(' сообщил о версии '))..known..(G:Text('. Установлена '))..G.version..(G:Text('. Сообщение не подтверждает выпуск. Ссылка: Настройки: «Скачать новую версию».')),1,.5,1)
 root.lastNoticeAt=time()
end
function G:InitializeVersionCheck()
 if V.frame then return end
 V.loginAt=GetTime();V.announceAt=V.loginAt+15;V.guild=G:GetGuildKey()
 RegisterAddonMessagePrefix(V.prefix)
 local f=CreateFrame('Frame');V.frame=f;f:RegisterEvent('CHAT_MSG_ADDON')
 f:SetScript('OnEvent',function(_,_,prefix,msg,channel,sender)if prefix==V.prefix then V:Receive(msg,sender,channel)end end)
 local elapsed=0;f:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0;V:Tick()end)
end
function G:CreateDiagnosticSettings(parent)
 local C=G.DiagnosticCapture;local x,w=412,344
 local panel=CreateFrame("Frame",nil,parent);panel:SetAllPoints();parent.diagnosticPanel=panel
 local function label(y,text,size,color)
  local t=panel:CreateFontString(nil,"ARTWORK","GameFontHighlight");t:SetPoint("TOPLEFT",x,-y);t:SetWidth(w);t:SetJustifyH("LEFT")
  t:SetText(text);G:ApplyFont(t,size or 11);if color then t:SetTextColor(unpack(color))end;return t
 end
 label(24,(G:Text("Проверка ошибки")),16,{1,.82,0})
 label(56,(G:Text("Включайте запись только для проверки ошибки. Включите запись, повторите действие и остановите запись.")),11)
 local function button(xoff,text,fn,y,width)
  local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x+xoff,-(y or 132));b:SetSize(width or 164,28);b:SetText(text);b:SetScript("OnClick",fn);G:ApplyFont(b:GetFontString(),11);return b
 end
 local start,stop,notice,installed,available
 local function refresh()
  if installed then installed:SetText((G:Text('Установлена: '))..G.version..' '..V.channel);available:SetText(V:Known()and((G:Text('Сообщена версия: '))..V:Known()..(G:Text(' (не проверена)')))or(G:Text('Свежих сообщений о новой версии нет.')))end
  local value=type(GetCVar)=="function"and GetCVar("taintLog")or nil
  start:SetEnabled(C.db~=nil and C.lease==nil);stop:SetEnabled(C.lease~=nil or tonumber(value)~=nil and tonumber(value)~=0)
  if notice then
   local messages={
    [(G:Text("Запись taintLog остановлена."))]=(G:Text("Запись остановлена.")),
    [(G:Text("Запись taintLog выключена."))]=(G:Text("Запись выключена.")),
    [(G:Text("Восстановлена прежняя запись taintLog. Для полного выключения нажмите ещё раз."))]=(G:Text("Запись была включена ранее. Для полного выключения нажмите «Остановить запись» ещё раз.")),
   }
   local text=C.notice or"";notice:SetText(messages[text]or(text:gsub("taintLog",(G:Text("журнал")))))
  end
 end
 start=button(0,(G:Text("Включить запись")),function()C:StartTaint();refresh()end,112)
 stop=button(180,(G:Text("Остановить запись")),function()C:ManualStop();refresh()end,112)
 notice=label(146,"",10)
 label(182,(G:Text("Сообщение об ошибке создайте в Issues. Приложите GuildControl735.lua и taint.log.")),11)
 label(238,(G:Text("Отчёт отдельно установленного BugGrabber поможет определить причину ошибки.")),11)
 local function showResource(kind)
  local f=panel.resourceWindow
  if not f then
   f=CreateFrame("Frame","GuildControl735ErrorResourceWindow",panel);panel.resourceWindow=f
   f:SetSize(420,156);f:SetPoint("CENTER",UIParent,"CENTER");f:SetFrameStrata("DIALOG");f:EnableMouse(true)
   f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
   local title=f:CreateFontString(nil,"ARTWORK","GameFontNormal");f.title=title;title:SetPoint("TOPLEFT",20,-20);G:ApplyFont(title,13)
   local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-4,-4);close:SetScript("OnClick",function()f:Hide()end)
   local edit=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.edit=edit
   edit:SetPoint("TOPLEFT",22,-54);edit:SetSize(376,48);edit:SetMultiLine(true);edit:SetAutoFocus(false);G:ApplyFont(edit,11)
   edit:SetScript("OnEscapePressed",function()f:Hide()end)
   edit:SetScript("OnEditFocusGained",function(self)self:HighlightText()end)
   f:SetScript("OnHide",function()edit:ClearFocus()end)
   local hint=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");f.hint=hint;hint:SetPoint("TOPLEFT",22,-118);G:ApplyFont(hint,10)
   UISpecialFrames[#UISpecialFrames+1]="GuildControl735ErrorResourceWindow"
  end
  local url=V.links[kind]
  f.title:SetText(kind=='issues'and(G:Text('Сообщить об ошибке'))or(G:Text('Скачать новую версию')))
  f.edit:SetText(url or(kind=='issues'and(G:Text('Раздел Issues ещё не опубликован. Ссылка будет добавлена после публикации.'))or(G:Text('Страница Releases ещё не опубликована. Ссылка будет добавлена после публикации.'))))
  f.hint:SetText(url and(G:Text('Выделить всё: Ctrl+A. Копировать: Ctrl+C.'))or(G:Text('Пока это заглушка — адрес ещё не задан.')))
  f:Show();f.edit:SetFocus();f.edit:HighlightText()
 end
 panel.report=button(0,(G:Text("Сообщить об ошибке")),function()showResource('issues')end,306,344)
 label(352,(G:Text('Обновление аддона')),13,{1,.82,0})
 installed=label(378,'',11);available=label(400,'',10)
 panel.download=button(0,(G:Text('Скачать новую версию')),function()showResource('releases')end,438,344)
 panel.installed=installed;panel.available=available
 panel:SetScript("OnHide",function()if panel.resourceWindow then panel.resourceWindow:Hide()end end)
 panel.start=start;panel.stop=stop
 panel:SetScript("OnShow",refresh)
 local elapsed=0
 panel:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0;refresh()end)
 refresh()
 return panel
end
