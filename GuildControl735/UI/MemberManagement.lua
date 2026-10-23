-- One physical secure click dispatches a bounded, fixed list of native rank
-- slash commands. No native API calls from Lua, timers, retries or leadership.
local _,G=...
local Q={};G.MemberManagement=Q
local M=G.MemberActions
local function combat()return InCombatLockdown and InCombatLockdown()end
local function clean(s)return type(s)=="string"and s~=""and not s:find("[%s%z\1-\31\127|/;]")end
local function escaped(s)return(tostring(s or""):gsub("|","||"))end
local function inviteName(s)return clean(s)and not s:find('[^%a%d\128-\255%-]')end
local function record(kind,detail)
 if G.Diagnostics then G.Diagnostics:Record('MEMBER_'..kind,detail)end
end
function Q:CanInvite()
 return not combat()and IsInGuild()and type(CanGuildInvite)=='function'and CanGuildInvite()==true and type(GuildInvite)=='function'
end
-- Use the client's own localized slash registration. Never call a protected API.
function Q:Command(kind)
 local defaults={promote='/gpromote',demote='/guilddemote',remove='/gremove'}
 local keys={promote='GUILD_PROMOTE',demote='GUILD_DEMOTE',remove='GUILD_UNINVITE'}
 local key=keys[kind];if not key then return end
 -- Prefer the long demotion alias if exported, otherwise use the native first alias.
 if kind=='demote'then for i=1,10 do if _G['SLASH_'..key..i]=='/guilddemote'then return '/guilddemote'end end end
 local native=_G['SLASH_'..key..'1']
 if type(native)=='string'and native:match('^/[^%s%z\1-\31\127|/;]+$')then return native end
 return defaults[kind]
end
function Q:DemotionTarget(row)
 -- UWoW may distinguish realm-qualified and realm-local command arguments.
 -- Shortening is allowed only for the actor's exact roster realm, a unique
 -- guild base name, AND a matching native GUID lookup. No name guessing/retry.
 local base,realm=row.name:match('^([^%-]+)%-(.+)$')
 if not base or type(GetPlayerInfoByGUID)~='function'then return row.name end
 local selfRow=M:Resolve({guild=G:GetGuildKey(),guid=UnitGUID('player')})
 local selfRealm=selfRow and selfRow.name:match('^[^%-]+%-(.+)$')
 if not selfRealm or realm:lower()~=selfRealm:lower()then return row.name end
 local _,_,_,_,_,nativeName,nativeRealm=GetPlayerInfoByGUID(row.guid or self.state.pin.guid)
 if nativeName~=base or(nativeRealm and nativeRealm~=''and nativeRealm:lower()~=realm:lower())then return row.name end
 local matches=0
 for i=1,GetNumGuildMembers(true)do
  local name=GetGuildRosterInfo(i)
  if name and(name:match('^([^%-]+)')or name):lower()==base:lower()then matches=matches+1 end
 end
 return matches==1 and base or row.name
end
-- Match complete localized messages, including positional format placeholders.
local function plain(text)
 if type(text)~='string'then return ''end
 return(text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|H.-|h(.-)|h',function(label)return label:match('^%[(.*)%]$')or label end))
end
local function templateValues(template,message,count)
 if type(template)~='string'or type(message)~='string'then return end
 local parts,order={},{};local i=1
 while i<=#template do
  local tail=template:sub(i);local token,position=tail:match('^(%%(%d+)%$s)')
  if not token and tail:sub(1,2)=='%s'then token='%s'end
  if token then parts[#parts+1]='(.-)';order[#order+1]=tonumber(position)or(#order+1);i=i+#token
  elseif tail:sub(1,2)=='%%'then parts[#parts+1]='%%';i=i+2
  else local c=template:sub(i,i);parts[#parts+1]=c:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1');i=i+1 end
 end
 if #order~=(count or 2)then return end
 local captures={plain(message):match('^'..table.concat(parts)..'$')};if #captures~=#order then return end
 local result={};for n,value in ipairs(captures)do result[order[n]]=value end
 return unpack(result,1,count or 2)
end
function Q:Aliases(name)
 local aliases={[name]=true};local base,realm=name:match('^([^%-]+)%-(.+)$')
 local actor=M:Resolve({guild=G:GetGuildKey(),guid=UnitGUID('player')})
 local actorRealm=actor and actor.name:match('^[^%-]+%-(.+)$')
 if not base or not realm or not actorRealm or realm:lower()~=actorRealm:lower()then return aliases end
 local count=0
 for i=1,GetNumGuildMembers(true)do local n=GetGuildRosterInfo(i);if n and(n:match('^[^%-]+')or n):lower()==base:lower()then count=count+1 end end
 if count==1 then aliases[base]=true end
 return aliases
end
function Q:RemovalConfirmed(source)
 local s=self.state;if not s or s.kind~='remove'or not(s.pending or s.armed or s.timedOut)or(s.failed and not s.timedOut)then return end
 record('CONFIRMED_REMOVE',s.name..' source='..source)
 self:Close()
 if source=='system'and type(GuildRoster)=='function'then GuildRoster()end
 G:Print((G:Text('Исключение '))..s.name..(G:Text(' подтверждено '))..(source=='system'and(G:Text('системным сообщением.'))or(G:Text('обновлённым составом.'))))
end
function Q:SystemMessage(message)
 local s=self.state
 if s and s.kind=='rank'then
  if not self:RankObserving(s)then return end
  local template
  if s.direction=='promote'then template=ERR_GUILD_PROMOTE_SSS else template=ERR_GUILD_DEMOTE_SSS end
  local actor,target,rank=templateValues(template,message,3)
  if actor and s.actorAliases[actor]and s.targetAliases[target]and rank==s.destinationName then self:RankConfirmed('system')end
  return
 end
 if not s or s.kind~='remove'or not(s.pending or s.armed or s.timedOut)or(s.failed and not s.timedOut)or not s.requestAt or GetTime()-s.requestAt>30 then return end
 if combat()or not IsInGuild()or G:GetGuildKey()~=s.pin.guild or UnitGUID('player')~=s.actorGUID then return end
 local target,actor=templateValues(ERR_GUILD_REMOVE_SS,message)
 if target and s.targetAliases and s.targetAliases[target]and s.actorAliases and s.actorAliases[actor]then self:RemovalConfirmed('system')end
end
-- Observe the requested final rank; never dispatch from an acknowledgement.





function Q:RankObserving(s)
 return s and s.kind=='rank'and(s.pending or s.armed or s.timedOut)and(not s.failed or s.timedOut)
  and s.requestAt and GetTime()-s.requestAt<=30 and not combat()and IsInGuild()
  and G:GetGuildKey()==s.pin.guild and UnitGUID('player')==s.actorGUID
  and s.destinationName==GuildControlGetRankName(s.expected+1)
end
function Q:RankConfirmed(source)
 local s=self.state;if not self:RankObserving(s)then return end
 local row=M:Resolve(s.pin);local rank=s.expected
 record('CONFIRMED_RANK',s.name..' rank='..rank..' source='..source)
 s.observedBase=s.baseRank;s.baseRank=rank;s.confirmedRank=rank
 s.pending=nil;s.armed=nil;s.failed=nil;s.timedOut=nil
 s.awaitingRoster=not row or row.rank~=rank
 s.destination=nil;s.destinationName=nil;s.expected=nil
 self:ClearButton();self:Refresh()
 self.frame.status:SetText(s.awaitingRoster and(G:Text('Звание подтверждено игрой. Обновляем состав…'))or(G:Text('Звание обновлено. Можно выбрать следующее звание.')))
 if source=='system'and type(GuildRoster)=='function'then GuildRoster()end
end
function Q:ValidateRank()
 local s=self.state;if not s or s.kind~='rank'then return end
 if combat()or not IsInGuild()or G:GetGuildKey()~=s.pin.guild or(s.actorGUID and UnitGUID('player')~=s.actorGUID)then self:Close();return end
 local row=M:Resolve(s.pin)
 if not row or row.name~=s.name then self:Close();return end
 if s.awaitingRoster then
  if row.rank==s.confirmedRank then
   s.awaitingRoster=nil;s.confirmedRank=nil;self:Refresh();self.frame.status:SetText((G:Text('Звание обновлено. Можно выбрать следующее звание.')))
  elseif GetTime()-s.requestAt>30 or row.rank~=s.observedBase then self:Close()end
  return
 end
 if s.failed and not s.timedOut then return end
 if s.pending or s.timedOut then
  if self:RankObserving(s)and row.rank==s.expected then self:RankConfirmed('roster');return end
  if GetTime()-s.requestAt>30 then
   record('RANK_OBSERVATION_END',s.name);self:Close();G:Print((G:Text('Проверьте звание в составе и системном чате. Повтор не выполняется.')));return
  end
  if row.rank~=s.baseRank then
   local inside=s.direction=='promote'and row.rank<s.baseRank and row.rank>s.expected
    or s.direction=='demote'and row.rank>s.baseRank and row.rank<s.expected
   if not inside then self:Close();return end
   if s.progress~=row.rank then
    s.progress=row.rank;record('RANK_PROGRESS',s.name..' rank='..row.rank..' target='..s.expected)
    self.frame.detail:SetText(escaped(s.name)..(G:Text('\nСейчас: '))..escaped(GuildControlGetRankName(row.rank+1)))
    self.frame.status:SetText((G:Text('Выбранное звание ещё не достигнуто. Ожидаем результат; повтор не выполняется.')))
   end
  end
  if s.pending and GetTime()>s.deadline then
   s.pending=nil;s.failed=true;s.timedOut=true;record('TIMEOUT',s.name..' rank='..tostring(s.expected))
   self:Refresh();self.frame.status:SetText((G:Text('Подтверждение задерживается. Проверьте системный чат. Повтор не выполняется.')))
  end
  return
 end
 if row.rank~=s.baseRank then self:Close();return end
 s.confirmedRank=nil
 if s.destination and GuildControlGetRankName(s.destination+1)~=s.destinationName then self:Close();return end
 if not M:Capabilities(s.pin).rank then self:Close();return end
 self:Refresh()
end
function Q:StopBlocked(addon,func)
 local s=self.state
 if not s or not(s.armed or s.pending or s.sending)or not s.requestAt or GetTime()-s.requestAt>12 then return end
 local native=type(func)=='string'and func:match('^([%w_]+)%s*%(?')
 local unknown=native=='UNKNOWN'and addon==G.name and s.kind=='rank'and(s.armed or s.pending)
 if native~=s.nativeFunction and not unknown then return end
 self:ClearButton();s.failed=true;s.armed=nil;s.pending=nil;s.timedOut=nil
 record('BLOCKED',tostring(addon)..' / '..tostring(func)..' / '..tostring(s.command))
 if s.kind=='invite'then self:Close();G:Print((G:Text('Клиент заблокировал приглашение. Повтор не выполняется.')));return end
 local f=self.frame;f.execute:SetEnabled(false);f.dropdown:SetEnabled(false)
 if G.Dropdown.active==f.dropdown then G.Dropdown.Close()end
 f.status:SetText((G:Text('Клиент заблокировал действие. Остановлено. Сохраните журнал; повтор не выполняется.')))
end
function Q:Escape(frame,key)
 if combat()then return end
 frame:SetPropagateKeyboardInput(key~='ESCAPE')
 if key~='ESCAPE'then return end
 if G.Dropdown.active==self.frame.dropdown then G.Dropdown.Close()else self:Close()end
end
function Q:InviteFrame()
 if self.inviteFrame then return self.inviteFrame end
 local f=CreateFrame('Frame','GC735GuildInvite',UIParent);self.inviteFrame=f
 f:SetSize(320,118);f:SetPoint('CENTER',UIParent,'CENTER',0,30);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(140)
 f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=20,insets={left=5,right=5,top=5,bottom=5}});f:SetBackdropColor(.025,.035,.03,.95)
 f:SetScript('OnDragStart',function()if not combat()then f:StartMoving()end end);f:SetScript('OnDragStop',function()f:StopMovingOrSizing()end)
 f.title=f:CreateFontString(nil,'ARTWORK','GameFontHighlight');f.title:SetPoint('TOPLEFT',16,-14);f.title:SetSize(288,20);G:ApplyFont(f.title,12);f.title:SetText((G:Text('Добавить в гильдию игрока:')))
 f.edit=CreateFrame('EditBox',nil,f,'InputBoxTemplate');f.edit:SetPoint('TOPLEFT',22,-42);f.edit:SetSize(272,24);f.edit:SetAutoFocus(false);f.edit:SetMaxLetters(77);G:ApplyFont(f.edit,12)
 f.accept=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');f.accept:SetPoint('TOPLEFT',16,-80);f.accept:SetSize(136,24);f.accept:SetText((G:Text('Принять')))
 f.cancel=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');f.cancel:SetPoint('TOPLEFT',168,-80);f.cancel:SetSize(136,24);f.cancel:SetText((G:Text('Отмена')))
 f.accept:SetScript('OnClick',function(_,button)if button=='LeftButton'then Q:SubmitInvite('button')end end)
 f.edit:SetScript('OnEnterPressed',function()Q:SubmitInvite('enter')end)
 f.edit:SetScript('OnEscapePressed',function()f:SetPropagateKeyboardInput(false);Q:Close()end)
 f.cancel:SetScript('OnClick',function()Q:Close()end)
 f.edit:SetScript('OnTextChanged',function()if Q.state and Q.state.kind=='invite'then Q:RefreshInvite()end end)
 f:EnableKeyboard(true);f:SetPropagateKeyboardInput(true)
 f:SetScript('OnKeyDown',function(_,key)f:SetPropagateKeyboardInput(key~='ESCAPE');if key=='ESCAPE'then Q:Close()end end)
 f:SetScript('OnHide',function()if Q.state and Q.state.kind=='invite'then Q.state=nil end;f.edit:SetText('');f.edit:ClearFocus()end)
 f:Hide();return f
end
function Q:RefreshInvite()
 local s=self.state;local f=self.inviteFrame;if not s or s.kind~='invite'or not f then return end
 f.accept:SetEnabled(self:CanInvite()and s.guild==G:GetGuildKey()and s.actorGUID==UnitGUID('player')and inviteName(f.edit:GetText())and not s.sending)
end
function Q:SubmitInvite(source)
 local s=self.state;local f=self.inviteFrame
 if(source~='button'and source~='enter')or not s or s.kind~='invite'or not f or not f:IsShown()or s.sending then return end
 if not self:CanInvite()or s.guild~=G:GetGuildKey()or s.actorGUID~=UnitGUID('player')then self:Close();return end
 local name=f.edit:GetText();if not inviteName(name)or#name>124 then return end
 s.sending=true;s.requestAt=GetTime();s.nativeFunction='GuildInvite';f.accept:SetEnabled(false);record('INVITE_REQUEST',name..' via='..source)
 -- Same invitation API as Blizzard 7.3.5 ADD_GUILDMEMBER, invoked only by
 -- our mouse/Enter handlers. No secure :Click(), binding, macro or retry.
 local ok=pcall(GuildInvite,name)
 if self.state~=s then return end
 if not ok then record('INVITE_ERROR',name);self:Close();G:Print((G:Text('Клиент отклонил запрос приглашения. Сохраните журнал.')));return end
 self:Close();G:Print(s.clientError and((G:Text('Игра: '))..s.clientError)or((G:Text('Приглашение для '))..name..(G:Text(' запрошено. Вступление требует согласия игрока.'))))
end

function Q:ClearButton()
 if not combat()and self.frame then self.frame.execute:SetAttribute("type",nil);self.frame.execute:SetAttribute("macrotext",nil)end
end
function Q:Close()
 self.state=nil
 if self.inviteFrame then self.inviteFrame:Hide();self.inviteFrame.edit:SetText('');self.inviteFrame.edit:ClearFocus()end
 if self.frame and G.Dropdown.active==self.frame.dropdown then G.Dropdown.active=nil;self.frame.dropdown.dismiss:Hide()end
 if combat()then self.deferred=true;return end
 self:ClearButton()
 if self.frame then self.frame.dropdown.menu:Hide();self.frame.dropdown.dismiss:Hide();UnregisterStateDriver(self.frame,"visibility");self.frame:Hide()end
 self.deferred=nil
end
function Q:Allowed(pin,kind,destination)
 if combat()then return end
 local c=M:Capabilities(pin);local row=c.row
 if not row or not clean(row.name)or not c[kind]then return end
 if kind=="rank"then
  local _,_,actor=GetGuildInfo("player");local max=GuildControlGetNumRanks()-1
  if type(actor)~='number'or type(destination)~="number"or destination%1~=0 or destination<=actor or destination>max or destination==row.rank then return end
  if destination<row.rank and not CanGuildPromote()or destination>row.rank and not CanGuildDemote()then return end
  if type(IsGuildRankAssignmentAllowed)~="function"then return end
  local ok,allowed=pcall(IsGuildRankAssignmentAllowed,row.index,destination+1)
  if not ok or allowed~=true then return end
 end
 return c
end
function Q:Ranks(pin)
 local rows={};local c=M:Capabilities(pin);if not c.row then return rows end
 for rank=1,GuildControlGetNumRanks()-1 do
  if self:Allowed(pin,"rank",rank)then rows[#rows+1]={rank=rank,name=GuildControlGetRankName(rank+1)}end
 end
 return rows
end
function Q:Absent(pin)
 local n=GetNumGuildMembers(true);if type(n)~="number"or n<1 or n>1500 or n%1~=0 then return false end
 local selfSeen=false;local seen={}
 for i=1,n do
  local row={GetGuildRosterInfo(i)}
  if type(row[1])~='string'or row[1]==''or type(row[17])~='string'or row[17]==''or seen[row[17]]then return false end
  seen[row[17]]=true
  if row[17]==pin.guid then return false end
  if row[17]==UnitGUID("player")then selfSeen=true end
 end
 return selfSeen
end
local function font(parent,x,y,w,h)
 local t=parent:CreateFontString(nil,"ARTWORK","GameFontHighlight");G:ApplyFont(t,12);t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);t:SetJustifyH("LEFT");t:SetWordWrap(true);return t
end
function Q:Frame()
 if self.frame then return self.frame end
 local f=CreateFrame("Frame","GC735MemberManagement",UIParent);self.frame=f
 f:SetSize(430,212);f:SetPoint("CENTER",UIParent,"CENTER",0,20);f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetFrameLevel(140);f:SetClampedToScreen(true);f:EnableMouse(true)
 f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=5,right=5,top=5,bottom=5}})
 f:SetBackdropColor(.025,.035,.03,.8)
 f.title=font(f,16,12,366,22);f.detail=font(f,16,38,398,44);f.status=font(f,16,116,398,42)
 f.dropdown=G.Dropdown.Create("GC735MemberDestination",f);f.dropdown:SetPoint("TOPLEFT",12,-84);G.Dropdown.SetWidth(f.dropdown,382)
 f.dropdown.menu:SetFrameLevel(160);f.dropdown.dismiss:SetFrameLevel(150)
 G.Dropdown.Initialize(f.dropdown,function()
  local s=Q.state;if not s or s.kind~="rank"or s.pending then return end
  for _,item in ipairs(Q:Ranks(s.pin))do
   local info=G.Dropdown.CreateInfo();info.text=item.name;info.checked=item.rank==(s.destination or s.confirmedRank or s.baseRank)
   info.func=function()if Q.state~=s or s.pending then return end;Q:Choose(item.rank)end
   G.Dropdown.AddButton(info)
  end
 end)
 local b=CreateFrame("Button","GC735MemberExecute",f,"UIPanelButtonTemplate,SecureActionButtonTemplate");f.execute=b
 b:SetSize(236,28);b:SetPoint("BOTTOMLEFT",18,16);b:RegisterForClicks("LeftButtonUp")
 b:SetScript("PreClick",function(_,button)Q:PreClick(button)end)
 b:SetScript("PostClick",function(_,button)Q:PostClick(button)end)
 f.cancel=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.cancel:SetSize(140,28);f.cancel:SetPoint("BOTTOMRIGHT",-18,16);f.cancel:SetText((G:Text("Отмена")));f.cancel:SetScript("OnClick",function()Q:Close()end)
 f.close=CreateFrame("Button",nil,f,"UIPanelCloseButton");f.close:SetPoint("TOPRIGHT",-3,-3);f.close:SetScript("OnClick",function()Q:Close()end)
 f:SetScript("OnUpdate",function(_,dt)f.elapsed=(f.elapsed or 0)+dt;if f.elapsed>=.2 then f.elapsed=0;Q:Validate(false)end end)
 f:SetScript("OnHide",function()if Q.state then Q:Close()end end)
 f:EnableKeyboard(true);f:SetPropagateKeyboardInput(true);f:SetScript('OnKeyDown',function(_,key)Q:Escape(f,key)end)
 f:Hide();return f
end
function Q:Choose(destination)
 local s=self.state;if not s or s.pending or s.awaitingRoster or s.failed or not self:Allowed(s.pin,s.kind,destination)then return end
 local name=GuildControlGetRankName(destination+1);if type(name)~="string"then return end
 s.completed=nil;s.destination=destination;s.destinationName=name;self.frame.status:SetText("");self:Refresh()
end
function Q:Refresh()
 local s=self.state;if not s or combat()then return end
 if s.kind=='invite'then self:RefreshInvite();return end
 local f=self.frame
 f:SetHeight(s.kind=='rank'and 212 or 190)
 f.status:ClearAllPoints();f.status:SetPoint('TOPLEFT',16,s.kind=='rank'and -116 or -88);f.status:SetHeight(s.kind=='rank'and 42 or 32)
 local c=M:Capabilities(s.pin)
 f.cancel:SetText(s.kind=="rank"and(G:Text("Закрыть"))or(G:Text("Отмена")))
 f.execute:SetEnabled(not s.pending and not s.awaitingRoster and not s.failed and self:Allowed(s.pin,s.kind,s.destination)~=nil)
 f.dropdown:SetShown(s.kind=="rank");f.dropdown:SetEnabled(not s.pending and not s.awaitingRoster and not s.failed)
 if s.kind=="rank"then
  G.Dropdown.SetText(f.dropdown,s.destinationName or GuildControlGetRankName((s.confirmedRank or(c.row and c.row.rank)or s.baseRank)+1)or"—")
  f.execute:SetText((G:Text("Изменить звание")))
  f.detail:SetText(escaped(s.name)..(G:Text("\nСейчас: "))..escaped(c.row and GuildControlGetRankName((s.confirmedRank or c.row.rank)+1)or"—"))
 else
  f.execute:SetText((G:Text("Подтверждаю исключение")))
  f.detail:SetText(escaped(s.name).."\n"..(G:Text("Исключить этого персонажа из гильдии?")))
 end
end
function Q:OpenInvite()
 if not self:CanInvite()then G:Print((G:Text('Нет права приглашать в гильдию или идёт бой.')));return end
 if M.state and(M.state.pending or M:Dirty())then G:Print((G:Text('Сначала сохраните или закройте заметки.')));return end
 M:Close();local f=self:InviteFrame()
 self.state={kind='invite',guild=G:GetGuildKey(),actorGUID=UnitGUID('player')};f.edit:SetText('')
 self:RefreshInvite();f:Show();f.edit:SetFocus()
end
function Q:Open(pin,kind)
 if M.state and(M.state.pending or M:Dirty())then G:Print((G:Text('Сначала сохраните или закройте заметки.')));return end
 local x,y=M.menu and M.menu:GetLeft(),M.menu and M.menu:GetTop()
 M:Close()
 if kind~="rank"and kind~="remove"then return end
 if combat()or not M:Capabilities(pin)[kind]then return end
 local c=M:Capabilities(pin);if not c.row or not clean(c.row.name)then return end
 local f=self:Frame();self.state={pin=pin,kind=kind,name=c.row.name,baseRank=c.row.rank}
 if x and y then f:ClearAllPoints();f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',x,y)end
 f.title:SetText(kind=="rank"and(G:Text("Изменение звания"))or(G:Text("Подтверждение исключения")))
 f.status:SetText(kind=='rank'and(G:Text('Выберите звание и нажмите «Изменить звание».'))or(G:Text('Выполнение — только кнопкой подтверждения.')))
 self:Refresh();RegisterStateDriver(f,"visibility","[combat] hide; show");f:Show()
end
function Q:PreClick(button)
 if combat()then return end
 self:ClearButton();local s=self.state
 if button~="LeftButton"or not s or s.pending or s.awaitingRoster or s.failed then return end
 if s.kind=='invite'then return end
 local c=self:Allowed(s.pin,s.kind,s.destination)
 if not c or c.row.name~=s.name or c.row.rank~=s.baseRank then self:Close();return end
 if s.kind=="rank"and GuildControlGetRankName(s.destination+1)~=s.destinationName then self:Close();return end
 s.requestAt=GetTime();s.actorGUID=UnitGUID('player')
 local actor=M:Resolve({guild=G:GetGuildKey(),guid=s.actorGUID})
 s.actorAliases=actor and self:Aliases(actor.name)or{};s.targetAliases=self:Aliases(s.name)
 if s.kind=='rank'then
  s.direction=s.destination<c.row.rank and 'promote'or'demote'
  s.nativeFunction=s.direction=='promote'and'GuildPromote'or'GuildDemote'
  s.expected=s.destination;s.count=math.abs(c.row.rank-s.destination);s.progress=nil
  if s.count<1 or s.count>9 then self:Close();return end
  local target=s.direction=='demote'and self:DemotionTarget(c.row)or c.row.name
  if target:find('%%')then self:Close();return end
  local command=self:Command(s.direction);local lines={}
  for i=1,s.count do
   local rank=c.row.rank+(s.direction=='promote'and-i or i)
   local ok,allowed=pcall(IsGuildRankAssignmentAllowed,c.row.index,rank+1)
   if not ok or allowed~=true then self:Close();return end
   lines[i]=command..' '..target
  end
  local macro=table.concat(lines,'\n')
  if #macro>255 then
   s.failed=true;self:Refresh();self.frame.status:SetText((G:Text('Команда для этого имени слишком длинная. Действие не отправлено.')));return
  end
  s.command=macro;s.armed=true
  record('RANK_REQUEST',s.name..' from='..c.row.rank..' to='..s.expected..' commands='..s.count..' bytes='..#macro)
  self.frame.execute:SetAttribute('macrotext',macro);self.frame.execute:SetAttribute('type','macro')
  return
 end
 s.nativeFunction='GuildUninvite'
 local macro=self:Command('remove')..' '..c.row.name;if #macro>255 then self:Close();return end
 s.command=macro;record('REQUEST',s.name..' command='..macro)
 s.armed=true;self.frame.execute:SetAttribute('macrotext',macro);self.frame.execute:SetAttribute('type','macro')

end
function Q:PostClick(button)
 if combat()then self:Close();return end
 self:ClearButton();local s=self.state
 if button~="LeftButton"or not s or not s.armed or s.failed then return end
 s.armed=nil
 if G.Dropdown.active==self.frame.dropdown then G.Dropdown.Close()end
 self.frame.dropdown:SetEnabled(false)
 if s.kind=='invite'then return end
 s.pending=true;s.deadline=GetTime()+12
 self.frame.execute:SetEnabled(false);self.frame.status:SetText(s.clientError and((G:Text('Игра: '))..s.clientError..(G:Text('. Ожидаем состав…')))or(G:Text('Команда запрошена. Ожидаем обновления состава…')))
 if type(GuildRoster)=="function"then GuildRoster()end
 if s.kind=='rank'then self:ValidateRank()end
end
function Q:Validate(fromEvent)
 local s=self.state;if not s then return end
 if combat()then self:Close();return end
 if s.kind=='invite'then
  if not self:CanInvite()or s.guild~=G:GetGuildKey()then self:Close()else self:Refresh()end;return
 end
 if not IsInGuild()or G:GetGuildKey()~=s.pin.guild then self:Close();return end
 if s.kind=='rank'then self:ValidateRank();return end
 if s.completed and s.kind~="rank"then return end
 local row=M:Resolve(s.pin)
 if row and row.name~=s.name then self:Close();return end
 if s.timedOut and s.kind=='remove'and GetTime()-s.requestAt<=30 then
  if not row and self:Absent(s.pin)then self:RemovalConfirmed('roster');return end
  return
 end
 if s.pending then
  if s.kind=='remove'and not row and self:Absent(s.pin)then self:RemovalConfirmed('roster');return end
  if GetTime()>s.deadline then
   record('TIMEOUT',s.name..' command='..tostring(s.command)..' expected='..tostring(s.expected)..' observed='..tostring(row and row.rank));s.pending=nil;s.failed=true
   s.timedOut=s.kind=='remove'or nil
   self.frame.status:SetText(s.timedOut and(G:Text('Подтверждение состава задерживается. Проверьте системный чат. Повтор не выполняется.'))or(G:Text('Изменение не подтверждено. Проверьте состав и сообщения игры. Повтор не выполняется.')))
  end
  return
 end
 if not row or row.name~=s.name or row.rank~=s.baseRank then self:Close();return end
 if s.kind=="rank"and s.destination and GuildControlGetRankName(s.destination+1)~=s.destinationName then self:Close();return end
 if not M:Capabilities(s.pin)[s.kind]then self:Close();return end
 if not s.failed then self:Refresh()end
end
local events=CreateFrame("Frame")
for _,ev in ipairs({"GUILD_ROSTER_UPDATE","GUILD_RANKS_UPDATE","PLAYER_GUILD_UPDATE","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN","UI_ERROR_MESSAGE","CHAT_MSG_SYSTEM"})do events:RegisterEvent(ev)end
events:SetScript("OnEvent",function(_,ev,addon,message)
 if ev=='CHAT_MSG_SYSTEM'then Q:SystemMessage(addon);return end
 if ev=="PLAYER_REGEN_ENABLED"then if Q.deferred then Q:Close()end;return end
 if ev=='UI_ERROR_MESSAGE'then
  local s=Q.state
  if s and(s.armed or s.pending or s.sending)then s.clientError=escaped(message or addon);record('CLIENT_ERROR',tostring(message or addon));if s.kind~='invite'then Q.frame.status:SetText(s.clientError)end end
  return
 end
 if ev=="PLAYER_REGEN_DISABLED"then Q:Close();return end
 if ev=='PLAYER_GUILD_UPDATE'or ev=='GUILD_RANKS_UPDATE'then Q:Validate(false);return end
 if ev=="ADDON_ACTION_BLOCKED"or ev=="ADDON_ACTION_FORBIDDEN"then
  Q:StopBlocked(addon,message)
  return
 end
 Q:Validate(true)
end)
Q.events=events
