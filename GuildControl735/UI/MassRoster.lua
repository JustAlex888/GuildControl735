-- General-page selection adapter; execution remains in Services/MassActions.lua.
local _,G=...
local P={selected={},enabled=false};G.MassRoster=P
local A=G.MassActions
local function text(parent,value,x,y,w,size)
 local t=parent:CreateFontString(nil,'ARTWORK','GameFontHighlight');t:SetPoint('TOPLEFT',x,-y);t:SetWidth(w);t:SetJustifyH('LEFT');G:ApplyFont(t,size or 12);t:SetText(value);return t
end
local function button(parent,value,x,y,w,fn,template)
 local b=CreateFrame('Button',nil,parent,template or'UIPanelButtonTemplate');b:SetPoint('TOPLEFT',x,-y);b:SetSize(w,28);b:SetText(value);G:ApplyFont(b:GetFontString(),11);if fn then b:SetScript('OnClick',fn)end;return b
end
local function backdrop(f)
 f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
end
local function plain(value)return(tostring(value or''):gsub('|','||'):gsub('[%z\1-\31\127]',' '))end
local function tint(color,value)return'|c'..color..plain(value)..'|r'end
local function classColor(member)
 local c=member and member.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.classFile]
 if not c then return'ffffffff'end
 local function channel(v)return math.floor(math.max(0,math.min(1,tonumber(v)or 1))*255+.5)end
 return string.format('ff%02x%02x%02x',channel(c.r),channel(c.g),channel(c.b))
end
local function status(entry)
 if entry.status=='done'then return tint('ff40e070',(G:Text('Выполнено')))end
 if entry.status=='pending'then return tint('ffffd966',(G:Text('Ожидается подтверждение')))end
 if entry.status=='skipped'then return tint('ffaaaaaa',(G:Text('Пропущено'))..(entry.detail and entry.detail~=''and(': '..entry.detail)or''))end
 if entry.status=='unknown'then return tint('ffffa040',(G:Text('Не подтверждено. Проверьте результат.')))end
 if entry.status=='stopped'then return tint('ffffa040',(G:Text('Остановлено')))end
 if entry.status=='ready'then return tint('ffffffff',(G:Text('К выполнению')))end
 return tint('ffffa040',(G:Text('Не подтверждено. Проверьте результат.')))
end
local actions=G:RegisterLocaleTable({},function()return {remove={title=(G:Text('Исключение выбранных участников')),next=(G:Text('Исключить следующую порцию'))},rank={title=(G:Text('Назначение звания выбранным персонажам')),next=(G:Text('Изменить звание следующей порции'))},promote={title=(G:Text('Повышение выбранных на одно звание')),next=(G:Text('Повысить следующую порцию'))},demote={title=(G:Text('Понижение выбранных на одно звание')),next=(G:Text('Понизить следующую порцию'))}} end)
function P:OpenActions()
 if not self.enabled or self:SelectionCount()==0 or A.pending or(InCombatLockdown and InCombatLockdown())then return end
 self.choosingRank=nil
 G.Dropdown.Open(self.frame.prepare)
end
function P:ChooseRank()
 if not self.enabled or self:SelectionCount()==0 or A.pending or(InCombatLockdown and InCombatLockdown())then return end
 G.Dropdown.Close();self.choosingRank=true;G.Dropdown.Open(self.frame.prepare)
end
local function signature(value)
 if type(value)~='table'then return type(value)..':'..tostring(value)end
 local keys={};for k in pairs(value)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do out[#out+1]=signature(k)..'='..signature(value[k])end
 return '{'..table.concat(out,';')..'}'
end
function P:State()return {filters=G.db.filters,sort=G.db.sort}end
function P:FilterSignature()
 return signature({filters=G.db.filters,family=G.PlayerCharacterFilter,guild=G:GetGuildKey(),actor=UnitGUID('player')})
end
function P:FilterChanged()
 self.selected={};if A.state then A:Stop((G:Text('Изменены фильтры. Выбор сброшен.')))end
end
function P:View()return self.frame.renderedView or{}end
function P:SelectionCount()local n=0;for _ in pairs(self.selected)do n=n+1 end;return n end
function P:SelectAll()
 if not self.enabled or A.pending then return end
 self:Refresh();self.selected={}
 for _,m in ipairs(self:View())do if m.guid then self.selected[m.guid]=true end end
 if A.state then A:Stop((G:Text('Изменён выбор участников.')))end;self:Refresh()
end
function P:Toggle(member)
 if not self.enabled or A.pending or not member or not member.guid then return end
 if A.state then A:Stop((G:Text('Изменён выбор участников.')))end
 self.selected[member.guid]=not self.selected[member.guid]or nil;self:Refresh()
end
function P:SetEnabled(value)
 self.enabled=value==true;self.selected={};self.filterSignature=self:FilterSignature()
 A:Stop((G:Text('Режим выбора изменён.')));self:CloseConfirmation();self:Refresh()
end
function P:Rows()
 local f=self.frame
 for _,row in ipairs(f.rows)do
  if not row.massCheck then
   local c=CreateFrame('CheckButton',nil,row,'UICheckButtonTemplate');row.massCheck=c
   c:SetSize(26,30);c:SetPoint('TOPLEFT',0,0);c:SetFrameLevel(row:GetFrameLevel()+30)
   c:SetScript('OnClick',function()P:Toggle(row.member)end)
   c:EnableMouseWheel(true);c:SetScript('OnMouseWheel',f.rosterWheel)
   row.massSelection=row:CreateTexture(nil,'BACKGROUND');row.massSelection:SetAllPoints();row.massSelection:SetColorTexture(.2,.42,.58,.28)
  end
  local c=f.columns[1];row.cells[1]:ClearAllPoints();row.cells[1]:SetPoint('TOPLEFT',self.enabled and 30 or 4,0);row.cells[1]:SetWidth(c.width-(self.enabled and 34 or 8))
  row.massCheck:SetShown(self.enabled and row.member~=nil);row.massCheck:SetChecked(self.selected[row.member and row.member.guid]==true)
  row.massCheck:SetEnabled(not A.pending);row.massSelection:SetShown(self.enabled and self.selected[row.member and row.member.guid]==true)
 end
end
function P:Update()
 local f=self.frame;if not f then return end
 local sig=self:FilterSignature()
 if sig~=self.filterSignature then self.filterSignature=sig;self:FilterChanged()end
 -- Column visibility, sorting and widths do not change membership selection.
 self:Rows();f.safety:Hide()
 f.status:ClearAllPoints();f.status:SetPoint('BOTTOMLEFT',22,self.enabled and 43 or 23)
 f.selectionMode:SetText(self.enabled and(G:Text('Завершить выбор'))or(G:Text('Управление составом гильдии')))
 f.selectionMode:ClearAllPoints();f.selectionMode:SetPoint('BOTTOMLEFT',self.enabled and 22 or 270,self.enabled and 10 or 20);f.selectionMode:SetWidth(self.enabled and 165 or 270)
 for _,b in ipairs({f.massAll,f.massClear,f.prepare})do b:SetShown(self.enabled)end
 f.massCount:SetShown(self.enabled);f.massCount:SetText((G:Text('Выбрано: '))..self:SelectionCount())
 f.prepare:SetEnabled(self.enabled and self:SelectionCount()>0 and not A.pending and not(InCombatLockdown and InCombatLockdown()))
 f.massAll:SetEnabled(not A.pending);f.massClear:SetEnabled(not A.pending)
 self:UpdateConfirmation()
end
function P:Refresh()G:UpdateMainWindow()end
function G:InitializeMassRoster()
 local f=self.MainWindow;P.frame=f;P.filterSignature=P:FilterSignature()
 local function footer(label,x,width,fn)
  local b=button(f,label,0,0,width,fn);b:ClearAllPoints();b:SetPoint('BOTTOMLEFT',x,10);b:SetHeight(26);return b
 end
 f.massCount=text(f,'',0,0,320,12);f.massCount:ClearAllPoints();f.massCount:SetPoint('BOTTOMLEFT',195,43)
 f.selectionMode=footer((G:Text('Управление составом гильдии')),270,270,function()P:SetEnabled(not P.enabled)end)
 f.massAll=footer((G:Text('Выбрать показанных')),195,180,function()P:SelectAll()end)
 f.massClear=footer((G:Text('Снять выбор')),383,130,function()if not A.pending then P.selected={};A:Stop((G:Text('Выбор снят.')));P:Refresh()end end)
 f.prepare=G.Dropdown.Create('GC735MassActions',f);f.prepare:SetPoint('BOTTOMLEFT',521,10);f.prepare:SetSize(220,26);f.prepare:SetText((G:Text('Действия с выбранными…')));G:ApplyFont(f.prepare:GetFontString(),11)
 G.Dropdown.Initialize(f.prepare,function()
  if P.choosingRank then
   local _,_,actorRank=GetGuildInfo('player');if type(actorRank)~='number'then return end
   for rank=actorRank+1,GuildControlGetNumRanks()-1 do
    local destination=rank;local info=G.Dropdown.CreateInfo();info.text=GuildControlGetRankName(rank+1)
    info.disabled=A.pending~=nil or not P.enabled or P:SelectionCount()==0 or(InCombatLockdown and InCombatLockdown())
    info.func=function()G.Dropdown.Close();P.choosingRank=nil;P:Preview('rank',destination)end;G.Dropdown.AddButton(info)
   end
   local back=G.Dropdown.CreateInfo();back.text=(G:Text('Отмена'));back.keepShownOnClick=true;back.func=function()G.Dropdown.Close();P:OpenActions()end;G.Dropdown.AddButton(back);return
  end
  for _,kind in ipairs({'rank','remove'})do
   local action=kind;local info=G.Dropdown.CreateInfo();info.text=action=='rank'and(G:Text('Назначить звание выбранным…'))or(G:Text('Исключить выбранных…'));info.keepShownOnClick=action=='rank'
   info.disabled=A.pending~=nil or not P.enabled or P:SelectionCount()==0 or(InCombatLockdown and InCombatLockdown())
   info.func=function()G.Dropdown.Close();if action=='rank'then P:ChooseRank()else P:Preview(action)end end;G.Dropdown.AddButton(info)
  end
 end)
 f.prepare:SetScript('OnClick',function()P:OpenActions()end)
 local original=self.UpdateMainWindow
 self.UpdateMainWindow=function(g,geometryOnly)original(g,geometryOnly);if f:IsShown()then P:Update()end end
 local widths=f.ApplyColumnWidths
 f.ApplyColumnWidths=function(frame,...)widths(frame,...);P:Rows()end
 f:HookScript('OnHide',function()
  P.enabled=false;P.selected={};A:Stop((G:Text('Общие данные закрыты.')));P:CloseConfirmation()
 end)
 -- Immediate invalidation also covers family-filter changes from the player card.
 A.changed=function()
  for _,entry in ipairs(A.state and A.state.entries or{})do if entry.status=='done'and not entry.selectionCleared then P.selected[entry.guid]=nil;entry.selectionCleared=true end end
  P:UpdateConfirmation();if f:IsShown()then P:Refresh()end
 end
 P:Update()
end

function P:UpdateConfirmation()
 local f=self.confirm;if not f or not A.state then return end
 local s=A.state;local count=A:Counts();local out={}
 local action=actions[s.kind or'remove'];f.title:SetText(action.title)
 f.hint:SetText(s.kind=='remove'and(G:Text('Проверьте список. Выполненные исключения нельзя отменить. Чтобы обработать весь список, может потребоваться несколько нажатий.'))or(G:Text('Проверьте конечное звание. Переход выполняется по одной ступени. Для обработки всего списка может потребоваться несколько нажатий; при повышении и понижении их число может различаться.')))
 if not(InCombatLockdown and InCombatLockdown())then self:LayoutConfirmation()end
 if self.colorState~=s then
  self.colorState=s;self.previewColors={}
  for _,entry in ipairs(s.entries)do
   local member=G.Roster:FindByKey(entry.guid)or(G.GuildArchive and G.GuildArchive:Member(entry.guid))
   self.previewColors[entry.guid]=classColor(member)
  end
 end
 if s.stopped and s.reason then
  local reason=s.reason:find('ADDON_ACTION_',1,true)and(G:Text('Игра заблокировала действие. Очередь остановлена.'))or s.reason
  out[#out+1]=tint('ffffa040',reason);out[#out+1]=''
 end
 for i,e in ipairs(s.entries)do
  if i>1 then out[#out+1]=''end
  local name=i..'. '..tint(self.previewColors[e.guid]or'ffffffff',e.name)
  if e.expected then
   local transition=(G:Text('Сейчас: '))..plain(e.rank)..(G:Text(' | Цель: '))..plain(e.destinationName or(G:Text('Недоступно')))
   local line=name..'  '..transition;f.measure:SetText(i..'. '..plain(e.name)..'  '..transition)
   if f.measure:GetStringWidth()<=f.report:GetWidth()then out[#out+1]=line
   else out[#out+1]=name;out[#out+1]=transition end
  else out[#out+1]=name end
  out[#out+1]=status(e)
 end
 f.report:SetHeight(0);f.report:SetText(table.concat(out,'\n'))
 local height=math.max(1,math.ceil(f.report:GetStringHeight())+6)
 f.child:SetHeight(height);f.report:SetHeight(height)
 if not(InCombatLockdown and InCombatLockdown())then
  f.hint:SetHeight(0);local top=24+math.ceil(f.title:GetStringHeight())+math.ceil(f.hint:GetStringHeight())+12
  f.scroll:ClearAllPoints();f.scroll:SetPoint('TOPLEFT',18,-top)
  local window=f.userSized and f:GetHeight()or math.max(360,math.min(420,top+height+64))
  f:SetHeight(window);f.scroll:SetHeight(window-top-64)
  f.scroll:SetVerticalScroll(math.min(f.scroll:GetVerticalScroll(),math.max(0,height-f.scroll:GetHeight())))
 end
 if not(InCombatLockdown and InCombatLockdown())then f.execute:SetEnabled(count.ready>0 and not s.stopped and not A.pending and A:Context())end
 f.execute:SetText(A.pending and(G:Text('Ожидаем состав…'))or s.stopped and(G:Text('Очередь остановлена'))or(f:GetWidth()<600 and(s.kind=='remove'and(G:Text('Продолжить исключение'))or(G:Text('Продолжить смену звания')))or action.next))
 f.stop:SetEnabled(not s.stopped and(count.ready>0 or A.pending~=nil))
end
function P:LayoutConfirmation()
 local f=self.confirm;if not f or(InCombatLockdown and InCombatLockdown())then return end
 if f:GetWidth()~=440 then f:SetWidth(440)end
 local width=440;local content=width-72
 f.title:SetWidth(width-66);f.title:SetHeight(0)
 f.hint:ClearAllPoints();f.hint:SetPoint('TOPLEFT',18,-(24+math.ceil(f.title:GetStringHeight())));f.hint:SetWidth(width-66)
 f.drag:SetWidth(width-62);f.scroll:SetWidth(content+6);f.child:SetWidth(content);f.report:SetWidth(content);f.measure:SetWidth(content)
 local available=width-52;local execute=math.floor(available*.52);local stop=math.floor(available*.21);local done=available-execute-stop
 for _,v in ipairs({{f.execute,18,execute},{f.stop,26+execute,stop},{f.done,34+execute+stop,done}})do
  v[1]:ClearAllPoints();v[1]:SetPoint('BOTTOMLEFT',v[2],18);v[1]:SetWidth(v[3])
 end
end
function P:Confirmation()
 if self.confirm then return self.confirm end
 local f=CreateFrame('Frame','GuildControl735MassConfirmation',UIParent);self.confirm=f
 f:SetSize(440,360);f:SetPoint('CENTER',UIParent,'CENTER',0,50);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(160);f:EnableMouse(true);f:SetClampedToScreen(true);f:SetMovable(true);f:SetResizable(true);f:SetMinResize(440,360);f:SetMaxResize(440,850);backdrop(f);f:SetBackdropColor(.025,.035,.04,.96)
 f.title=text(f,(G:Text('Исключение выбранных участников')),18,18,554,14);f.title:SetJustifyV('TOP');f.title:SetWordWrap(true)
 f.hint=text(f,(G:Text('Проверьте список. Выполненные исключения нельзя отменить.')),18,48,554,11);f.hint:SetJustifyV('TOP');f.hint:SetWordWrap(true)
 local drag=CreateFrame('Frame',nil,f);f.drag=drag;drag:SetPoint('TOPLEFT',14,-10);drag:SetSize(558,30);drag:EnableMouse(true);drag:RegisterForDrag('LeftButton')
 drag:SetScript('OnDragStart',function()if not(InCombatLockdown and InCombatLockdown())then f:StartMoving()end end)
 drag:SetScript('OnDragStop',function()if not(InCombatLockdown and InCombatLockdown())then f:StopMovingOrSizing()end end)
 local scroll=CreateFrame('ScrollFrame','GuildControl735MassPreviewScroll',f,'UIPanelScrollFrameTemplate');f.scroll=scroll;scroll:SetPoint('TOPLEFT',18,-88);scroll:SetSize(554,180)
 local child=CreateFrame('Frame',nil,scroll);child:SetSize(548,180);scroll:SetScrollChild(child);f.child=child
 f.report=text(child,'',0,0,548,11);f.report:SetJustifyV('TOP');f.report:SetWordWrap(true)
 f.measure=text(child,'',0,0,548,11);f.measure:SetWordWrap(false);f.measure:Hide()
 local function footer(label,x,width,fn,template)
  local b=button(f,label,0,0,width,fn,template);b:ClearAllPoints();b:SetPoint('BOTTOMLEFT',x,18);return b
 end
 f.execute=footer((G:Text('Исключить следующую порцию')),18,300,nil,'SecureActionButtonTemplate,UIPanelButtonTemplate')
 f.execute:RegisterForClicks('LeftButtonUp')
 local function disarm()if not(InCombatLockdown and InCombatLockdown())then f.execute:SetAttribute('type',nil);f.execute:SetAttribute('macrotext',nil)end end
 A.disarm=disarm
 f.execute:SetScript('PreClick',function(_,b)
  local macro=A:PreClick(b)
  if macro then f.execute:SetAttribute('macrotext',macro);f.execute:SetAttribute('type','macro')end
  P:UpdateConfirmation()
 end)
 f.execute:SetScript('PostClick',function(_,b)A:PostClick(b);P:Refresh()end)
 f.stop=footer((G:Text('Остановить')),326,120,function()A:Stop((G:Text('Остановлено пользователем.')))end)
 local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-5,-5);close:SetScript('OnClick',function()f:Hide()end)
 local done=footer((G:Text('Закрыть')),454,140,function()f:Hide()end);f.done=done
 local grip=CreateFrame('Button',nil,f);f.grip=grip;grip:SetSize(22,22);grip:SetPoint('BOTTOMRIGHT',-3,3);grip:SetFrameLevel(f:GetFrameLevel()+30)
 local texture=grip:CreateTexture(nil,'ARTWORK');texture:SetAllPoints();texture:SetTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up');grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
 local function stopSizing()
  if not f.sizing then return end
  f.sizing=nil;grip:SetScript('OnUpdate',nil);f:StopMovingOrSizing();P:UpdateConfirmation()
 end
 grip:SetScript('OnMouseDown',function(_,b)
  if b~='LeftButton'or(InCombatLockdown and InCombatLockdown())then return end
  f.userSized=true;f.sizing=true;f:StartSizing('BOTTOM')
  grip:SetScript('OnUpdate',function()if not IsMouseButtonDown('LeftButton')then stopSizing()end end)
 end)
 grip:SetScript('OnMouseUp',stopSizing);grip:HookScript('OnHide',stopSizing)
 f:SetScript('OnSizeChanged',function()
  if f.layoutBusy or(InCombatLockdown and InCombatLockdown())then return end
  f.layoutBusy=true;P:UpdateConfirmation();f.layoutBusy=nil
 end)
 f:Hide()
 f:SetScript('OnHide',function()
  A:Stop((G:Text('Окно подтверждения закрыто.')));disarm()
  if InCombatLockdown and InCombatLockdown()then P.deferClose=true else UnregisterStateDriver(f,'visibility')end
 end)
 f:EnableKeyboard(true);f:SetPropagateKeyboardInput(true)
 f:SetScript('OnKeyDown',function(_,key)
  f:SetPropagateKeyboardInput(key~='ESCAPE')
  if key=='ESCAPE'then P:CloseConfirmation()end
 end)
 return f
end
function P:Preview(kind,destination)
 if not self.enabled or not self.frame:IsShown()then return end
 self:Refresh()
 local f=self:Confirmation()
 local s=self:State();local ok,reason=A:Prepare(self.selected,s.filters,s.sort,kind,destination)
 if not ok then self.frame.status:SetText(reason);return end
 G.MemberActions:Close();self:UpdateConfirmation();RegisterStateDriver(f,'visibility','[combat] hide; show');f:Show()
end
function P:CloseConfirmation()
 if not self.confirm then return end
 if InCombatLockdown and InCombatLockdown()then self.deferClose=true;return end
 self.deferClose=nil;UnregisterStateDriver(self.confirm,'visibility');self.confirm:Hide();if A.disarm then A.disarm()end
end
