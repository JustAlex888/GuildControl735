-- Native guild actions only. No addon trust, wire, cache or persistent note data.
local _,G=...
local M={};G.MemberActions=M
local function yes(fn,...)
 if type(fn)~="function"then return false end
 local ok,v=pcall(fn,...);return ok and v==true
end
local function combat()return yes(InCombatLockdown)end
local function label(text)return (tostring(text or""):gsub("|","||"))end
local function tell(text)G:Print(text)end
function M:Pin(member)
 local guild=G:GetGuildKey()
 if G.Roster.lastGuildKey and G.Roster.lastGuildKey~=guild then return end
 return member and member.guid and{guid=member.guid,guild=guild}
end
function M:Resolve(pin)
 if not pin or not pin.guild or not IsInGuild()or pin.guild~=G:GetGuildKey()then return end
 local n=GetNumGuildMembers(true);if type(n)~="number"or n<0 or n>1500 then return end
 local found
 for i=1,n do
  local row={GetGuildRosterInfo(i)}
  if row[17]==pin.guid then
   if found or type(row[1])~="string"or row[1]:find("[%z\1-\31\127|]")then return end
   found={index=i,name=row[1],rank=row[3],online=row[9]==true,mobile=row[14]==true,public=row[7]}
   if yes(CanViewOfficerNote)then found.officer=row[8]end
  end
 end
 return found
end
function M:Capabilities(pin)
 local row=self:Resolve(pin);if not row then return {}end
 local _,_,rank=GetGuildInfo("player")
 local below=type(rank)=="number"and type(row.rank)=="number"and row.rank>rank
 local other=pin.guid~=UnitGUID("player");local max=GuildControlGetNumRanks()-1
 return {row=row,readOfficer=yes(CanViewOfficerNote),public=yes(CanEditPublicNote),
  officer=yes(CanViewOfficerNote)and yes(CanEditOfficerNote),
  rank=other and below and((yes(CanGuildPromote)and row.rank>rank+1)or(yes(CanGuildDemote)and row.rank<max)),
  remove=other and below and row.rank>=1 and yes(CanGuildRemove),
  whisper=other and row.online and type(ChatFrame_SendTell)=="function",
  invite=other and row.online and not row.mobile and type(InviteToGroup)=="function"
   and(not yes(IsInGroup)or yes(UnitIsGroupLeader,"player")or yes(UnitIsGroupAssistant,"player"))}
end
function M:CloseEditor()
 self.state=nil;self.switch=nil
 if self.editor then
  for _,k in ipairs({'public','officer'})do self.editor.fields[k]:SetText('');self.editor.fields[k]:ClearFocus()end
  self.editor:Hide()
 end
end
function M:Close()
 if G.MemberManagement then G.MemberManagement:Close()end
 self.menuPin=nil;if self.menu then self.menu:Hide();self.dismiss:Hide()end;self:CloseEditor()
end
local function text(parent,value,x,y,width,height)
 local t=parent:CreateFontString(nil,'ARTWORK','GameFontHighlight');G:ApplyFont(t,12)
 t:SetPoint('TOPLEFT',x,-y);t:SetSize(width,height);t:SetJustifyH('LEFT');t:SetWordWrap(true);t:SetText(value);return t
end
local function panel(name,w,h)
 local f=CreateFrame('Frame',name,UIParent);f:SetSize(w,h);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(130);f:SetClampedToScreen(true);f:EnableMouse(true)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=false,edgeSize=20,insets={left=5,right=5,top=5,bottom=5}})
 f:SetBackdropColor(.035,.045,.04,.95)
 f:EnableKeyboard(true);f:SetPropagateKeyboardInput(true)
 f:SetScript('OnKeyDown',function(_,key)
  f:SetPropagateKeyboardInput(key~='ESCAPE');if key~='ESCAPE'then return end
  if G.Dropdown.active then G.Dropdown.Close()
  elseif f==M.menu then f:Hide()
  elseif M.switch then M:SwitchAnswer('cancel')else M:CloseEditor()end
 end)
 return f
end
function M:Dirty()
 local s=self.state;if not s then return false end
 local c=self:Capabilities(s.pin)
 for _,k in ipairs({'public','officer'})do if c[k]and self.editor.fields[k]:GetText()~=s.base[k]then return true end end
 return false
end
function M:SwitchAnswer(answer)
 local target=self.switch;if not target or not self.state then return end
 if answer=='cancel'then self.switch=nil;self:ValidateEditor(false);return end
 if answer=='save'then target.afterSave=true;self:Save();return end
 self.switch=nil;self:LoadNote(target.pin,target.kind);self:ApplySelection(target.pin)
end
function M:Editor()
 if self.editor then return self.editor end
 local f=panel('GC735NativeNoteEditor',380,230);self.editor=f
 f:SetPoint('CENTER',UIParent,'CENTER',220,30);f:SetMovable(true);f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function()if not combat()then f:StartMoving()end end)
 f:SetScript('OnDragStop',function()f:StopMovingOrSizing()end)
 f.title=text(f,'',16,12,348,22);f.help=text(f,(G:Text('До 31 символа в каждом поле.')),16,35,348,18)
 f.fields={};f.labels={}
 for i,k in ipairs({'public','officer'})do
  local y=55+(i-1)*48
  f.labels[k]=text(f,k=='public'and(G:Text('Общая заметка'))or(G:Text('Офицерская заметка')),16,y,348,18)
  local edit=CreateFrame('EditBox',nil,f,'InputBoxTemplate');f.fields[k]=edit
  edit:SetPoint('TOPLEFT',22,-y-20);edit:SetSize(336,24);edit:SetAutoFocus(false);edit:SetMaxLetters(31);G:ApplyFont(edit,12)
  edit:SetScript('OnEnterPressed',function()M:Save()end);edit:SetScript('OnEscapePressed',function()f:SetPropagateKeyboardInput(false);if M.switch then M:SwitchAnswer('cancel')else M:CloseEditor()end end)
 end
 f.status=text(f,'',16,153,348,28)
 f.save=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');f.save:SetPoint('TOPLEFT',16,-188);f.save:SetSize(166,26);f.save:SetText((G:Text('Сохранить')))
 f.cancel=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');f.cancel:SetPoint('TOPLEFT',198,-188);f.cancel:SetSize(166,26);f.cancel:SetText((G:Text('Закрыть')))
 f.save:SetScript('OnClick',function()M:Save()end);f.cancel:SetScript('OnClick',function()M:CloseEditor()end)
 f.switchLabel=text(f,(G:Text('Несохранённый текст. Перейти к другому участнику?')),16,222,348,32);f.switchButtons={}
 for i,item in ipairs({{(G:Text('Сохранить')),'save'},{(G:Text('Отбросить')),'discard'},{(G:Text('Остаться')),'cancel'}})do
  local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(112,26);b:SetPoint('TOPLEFT',16+(i-1)*118,-260);b:SetText(item[1]);b:SetScript('OnClick',function()M:SwitchAnswer(item[2])end);f.switchButtons[i]=b
 end
 f:SetScript('OnHide',function()M.state=nil;M.switch=nil;for _,edit in pairs(f.fields)do edit:SetText('');edit:ClearFocus()end end)
 f:SetScript('OnUpdate',function(_,dt)f.elapsed=(f.elapsed or 0)+dt;if f.elapsed>=.2 then f.elapsed=0;M:ValidateEditor(false)end end)
 f:Hide();return f
end
function M:ApplySelection(pin)
 local member=pin and G.Roster:FindByKey(pin.guid)
 if member and G.MainWindow then G.MainWindow.selectedMemberKey=member.key;G:ShowMemberCard(member);G:UpdateMainWindow()end
end
function M:LoadNote(pin,kind)
 local c=self:Capabilities(pin)
 if combat()or not c.row or type(c.row.public)~='string'or(c.readOfficer and type(c.row.officer)~='string')or(kind=='officer'and not c.readOfficer)then self:CloseEditor();tell((G:Text('Нет доступа или данные заметки ещё не получены. Обновите состав.')));return end
 local f=self:Editor();self.switch=nil;self.state={pin=pin,kind=kind,base={public=c.row.public,officer=c.readOfficer and c.row.officer or nil},name=c.row.name}
 f.title:SetText((G:Text('Заметки — '))..label(c.row.name));f.title:SetWordWrap(false)
 f.fields.public:SetText(c.row.public);f.fields.officer:SetText(c.readOfficer and c.row.officer or'')
 f.status:SetText('');f:Show();self:ValidateEditor(false)
end
function M:SelectMember(member)
 local s=self.state;if not s then return true end
 local pin=self:Pin(member);if not pin then return false end
 if s.pin.guid==pin.guid and s.pin.guild==pin.guild then return true end
 if s.pending then self.editor.status:SetText((G:Text('Дождитесь подтверждения сохранения перед переходом.')));return false end
 if self:Dirty()then self.switch={pin=pin,kind='public'};self:ValidateEditor(false);return false end
 self:LoadNote(pin,'public');return self.state~=nil
end
function M:OpenNote(member,kind,pinned)
 if kind~='public'and kind~='officer'then return end
 local pin=pinned or self:Pin(member);local c=self:Capabilities(pin)
 if not c.row or(kind=='officer'and not c.readOfficer)then tell((G:Text('Нет доступа к заметке выбранного участника.')));return end
 if self.state then
  if not self:SelectMember(member or{guid=pin.guid})then return end
  if self.state and self.state.pin.guid==pin.guid then return end
 end
 if G.MemberManagement then G.MemberManagement:Close()end
 if self.menu then self.menu:Hide()end
 self:LoadNote(pin,kind)
end
function M:ValidateEditor(fromEvent)
 local s=self.state;if not s then return end
 local c=self:Capabilities(s.pin);local f=self.editor
 if combat()or not c.row or c.row.name~=s.name or type(c.row.public)~='string'or(c.readOfficer and type(c.row.officer)~='string')then self:CloseEditor();return end
 for _,k in ipairs({'public','officer'})do
  local readable=k=='public'or c.readOfficer
  local edit=f.fields[k];local editable=c[k]==true and not s.pending and not self.switch
  edit:EnableMouse(editable);edit:EnableKeyboard(editable)
  if not readable then edit:SetText('');s.base[k]=nil;f.labels[k]:SetText((G:Text('Офицерская заметка — нет доступа')))
  else
   f.labels[k]:SetText((k=='public'and(G:Text('Общая заметка'))or(G:Text('Офицерская заметка')))..(c[k]and''or(G:Text(' — только чтение'))))
   if not c[k]then edit:SetText(c.row[k]or'');s.base[k]=c.row[k]end
  end
  if s.pending and s.pending[k]~=nil and not c[k]then self:CloseEditor();tell((G:Text('Право редактирования отозвано. Проверьте уже отправленные изменения.')));return end
 end
 if s.pending then
  if fromEvent then
   for k,v in pairs(s.pending)do if c.row[k]==v then s.base[k]=v;s.pending[k]=nil end end
   if not next(s.pending)then
    s.pending=nil;f.status:SetText((G:Text('Новый текст отображается в составе гильдии.')))
    if self.switch and self.switch.afterSave then local target=self.switch;self:LoadNote(target.pin,target.kind);self:ApplySelection(target.pin);return end
   end
  end
  if s.pending and GetTime()>s.deadline then s.pending=nil;self.switch=nil;f.status:SetText((G:Text('Сохранение подтверждено не полностью. Проверьте обе заметки.')));s.unconfirmed=true end
 end
 local switching=self.switch~=nil
 f:SetHeight(switching and 302 or 230);f.switchLabel:SetShown(switching)
 for _,b in ipairs(f.switchButtons)do b:SetShown(switching);b:SetEnabled(not s.pending)end
 f.save:SetEnabled((c.public or c.officer)==true and not s.pending and not switching and not s.unconfirmed)
end
local function validNote(value)
 if type(value)~='string'or#value>124 or value:find('[%z\1-\31\127]')then return false end
 local count=0;for _ in value:gmatch('[%z\1-\127\194-\244][\128-\191]*')do count=count+1 end
 return count<=31
end
function M:Save()
 local s=self.state;if not s or s.pending or s.unconfirmed then return end
 local c=self:Capabilities(s.pin);local f=self.editor
 if combat()or not c.row or c.row.name~=s.name then self:CloseEditor();return end
 local changes={};local functions={public=GuildRosterSetPublicNote,officer=GuildRosterSetOfficerNote}
 for _,k in ipairs({'public','officer'})do
  local value=f.fields[k]:GetText()
  if value~=(s.base[k]or'')then
   if not c[k]or type(c.row[k])~='string'then self:CloseEditor();tell((G:Text('Нет права или данных для сохранения этой заметки.')));return end
   if not validNote(value)then f.status:SetText((G:Text('В каждом поле — одна строка до 31 символа.')));return end
   if c.row[k]~=s.base[k]then f.status:SetText((G:Text('Заметка уже изменилась. Закройте и откройте её заново.')));return end
   if type(functions[k])~='function'then f.status:SetText((G:Text('Штатная функция редактирования недоступна.')));return end
   changes[k]=value
  end
 end
 if not next(changes)then f.status:SetText((G:Text('Изменений нет.')));return end
 s.pending=changes;s.deadline=GetTime()+12;f.save:SetEnabled(false)
 f.status:SetText((G:Text('Изменения отправлены. Ожидаем обновление состава…')))
 for _,k in ipairs({'public','officer'})do
  if changes[k]~=nil then
   local fresh=self:Capabilities(s.pin)
   if not fresh.row or fresh.row.name~=s.name or not fresh[k]or fresh.row[k]~=s.base[k]then self:CloseEditor();tell((G:Text('Контекст изменился. Проверьте уже отправленные заметки.')));return end
   local ok=pcall(functions[k],fresh.row.index,changes[k]);if not ok then self:CloseEditor();tell((G:Text('Клиент отклонил изменение. Проверьте обе заметки.')));return end
  end
 end
 for _,edit in pairs(f.fields)do edit:ClearFocus()end
 if type(GuildRoster)=='function'then GuildRoster()end
 self:ValidateEditor(false)
end

function M:Native(pin,kind)
 if G.MassActions and G.MassActions.pending then tell((G:Text('Дождитесь результата отправленной порции.')));return end
 if G.MemberManagement then G.MemberManagement:Open(pin,kind)end
end
function M:Items(pin)
 local c=self:Capabilities(pin);local member=c.row and{guid=pin.guid}or nil
 local items={
  {text=(G:Text("Написать сообщение")),enabled=c.whisper,run=function()local x=M:Capabilities(pin);if x.whisper then ChatFrame_SendTell(x.row.name)end end},
  {text=(G:Text("Пригласить в группу")),enabled=c.invite,run=function()local x=M:Capabilities(pin);if x.invite and not combat()then InviteToGroup(x.row.name)end end},
  {text=(G:Text("Заметка общая / офицерская")),enabled=c.row~=nil,run=function()M:OpenNote(member,"public",pin)end},
  {text=(G:Text("Изменить звание…")),enabled=c.rank,run=function()M:Native(pin,"rank")end},
  {text=(G:Text("Исключить…")),enabled=c.remove,run=function()M:Native(pin,"remove")end},
 }
 if G.MassRoster and G.MassRoster.enabled then items[#items+1]={text=(G:Text('Действия с выбранными… ('))..G.MassRoster:SelectionCount()..')',enabled=G.MassRoster:SelectionCount()>0 and not G.MassActions.pending,run=function()G.MassRoster:OpenActions()end}end
 return items
end
function M:OpenMenu(member)
 if not self:SelectMember(member)then return end
 if G.MemberManagement then G.MemberManagement:Close()end
 local pin=self:Pin(member);local c=self:Capabilities(pin)
 if not c.row or combat()then return end
 if G.MainWindow then G.MainWindow.selectedMemberKey=member.key;G:ShowMemberCard(member);G:UpdateMainWindow()end
 if not self.menu then
  local d=CreateFrame("Button",nil,UIParent);self.dismiss=d;d:SetAllPoints(UIParent);d:SetFrameStrata("FULLSCREEN_DIALOG");d:SetFrameLevel(100);d:SetScript("OnClick",function()M:Close()end);d:Hide()
  local f=panel("GC735NativeMemberActions",330,188);self.menu=f;f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetFrameLevel(101)
  f.title=text(f,"",14,12,302,30);f.buttons={}
  for i=1,5 do local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(302,24);b:SetPoint("TOPLEFT",14,-44-(i-1)*26);G:ApplyFont(b:GetFontString(),11);f.buttons[i]=b end
  f:SetScript("OnHide",function()M.menuPin=nil;d:Hide()end)
 end
 self.menuPin=pin;self.menu.title:SetText(label(c.row.name))
 local items=self:Items(pin);self.menu:SetHeight(58+#items*26)
 for i,item in ipairs(items)do
  local b=self.menu.buttons[i]
  if not b then b=CreateFrame('Button',nil,self.menu,'UIPanelButtonTemplate');b:SetSize(302,24);b:SetPoint('TOPLEFT',14,-44-(i-1)*26);G:ApplyFont(b:GetFontString(),11);self.menu.buttons[i]=b end
  b:Show();b:SetText(item.text);b:SetEnabled(item.enabled==true);b:SetScript("OnClick",function()if M.menuPin~=pin then return end;M.menu:Hide();item.run()end)
 end
 for i=#items+1,#self.menu.buttons do self.menu.buttons[i]:Hide()end
 local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale();self.menu:ClearAllPoints();self.menu:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale);self.dismiss:Show();self.menu:Show()
end
function M:Initialize(frame)
 if self.events then return end
 local f=CreateFrame("Frame");self.events=f
 for _,ev in ipairs({"GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","GUILD_RANKS_UPDATE","PLAYER_REGEN_DISABLED"})do f:RegisterEvent(ev)end
 f:SetScript("OnEvent",function(_,ev)
  if ev=="PLAYER_REGEN_DISABLED"then M:Close();return end
  if M.menuPin and not M:Capabilities(M.menuPin).row then M.menu:Hide()end
  if M.menuPin then for i,item in ipairs(M:Items(M.menuPin))do if M.menu.buttons[i]then M.menu.buttons[i]:SetEnabled(item.enabled==true)end end end
  M:ValidateEditor(ev=="GUILD_ROSTER_UPDATE")
  if G.MemberManagement then G.MemberManagement:Validate(false)end
 end)
end
