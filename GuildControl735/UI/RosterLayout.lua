-- Presentation only: existing validated/local family data, no wire or rights.
local _,G=...
-- Help is attached only to General-page controls, not global Blizzard widgets.
function G:AttachHelp(owner,title,body)
 owner:HookScript("OnEnter",function(o)
  GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:SetText(title,1,.82,0)
  GameTooltip:AddLine(body,1,1,1,true);GameTooltip:Show()
 end)
 owner:HookScript("OnLeave",function()GameTooltip:Hide()end)
 owner:HookScript("OnHide",function(o)if GameTooltip:IsOwned(o)then GameTooltip:Hide()end end)
end
function G:InitializeRosterSizing(frame)
 local counts={name=10,rank=10,satellite=8,family=10,lastOnline=6,zone=10}
 self.db.ui=self.db.ui or {};local saved=self.db.ui.rosterColumnWidths
 if type(saved)~="table"then saved={};self.db.ui.rosterColumnWidths=saved end
 local measure=frame:CreateFontString(nil,"ARTWORK","GameFontHighlight");measure:Hide()
 local function finite(v)return type(v)=="number"and v==v and v~=math.huge and v~=-math.huge end
 local function textWidth(text,size,padding)
  G:ApplyFont(measure,size);measure:SetText(text);return math.ceil(measure:GetStringWidth()+(padding or 8))
 end
 local maximumText={name=string.rep("н",22),rank=string.rep("н",15),satellite=G.L.ADDON_UNKNOWN,
  family=G.L.HEADER_FAMILY,lastOnline=G.L.HEADER_LAST_ONLINE,zone="Разлом зловещего шрама"}
 for i,column in ipairs(frame.columns)do
  G:ApplyFont(measure,column.key=="satellite"and 10 or 12)
  measure:SetText(string.rep("н",counts[column.key]or 1))
  column.minWidth=counts[column.key]and math.ceil(measure:GetStringWidth()+8)or column.defaultWidth
  local fixed=column.key=="class"or column.key=="level"
  if column.key=="profession1"or column.key=="profession2"then
   column.minWidth=textWidth(G.L[column.label],12,10)
  elseif column.key=="note"or column.key=="officerNote"then
   column.minWidth=textWidth(G.L.HEADER_NOTE,12,10)
  end
  column.maxWidth=fixed and column.minWidth or maximumText[column.key]and textWidth(maximumText[column.key],column.key=="satellite"and 10 or 12,(column.key=="family"or column.key=="lastOnline")and 10 or 8)or 320
  if column.key=="lastOnline"then
   local h=frame.columnHeaders[i]
   if h.second then
    column.minWidth=math.max(column.minWidth,math.ceil(h.label:GetStringWidth()+10),math.ceil(h.second:GetStringWidth()+10))
    column.maxWidth=math.max(column.maxWidth,column.minWidth)
   end
  end
  if column.key=="profession1"or column.key=="profession2"then column.maxWidth=math.max(column.minWidth,G:ProfessionMaximumWidth(measure))end
  column.minWidth=math.min(column.minWidth,column.maxWidth)
  column.resetWidth=column.minWidth
  if column.key=="name"then column.resetWidth=textWidth(string.rep("н",12),12,8)
  elseif column.key=="family"then column.resetWidth=math.max(column.minWidth,math.min(column.maxWidth,column.defaultWidth))end
  local value=saved[column.key]
  column.width=finite(value)and math.max(column.minWidth,math.min(column.maxWidth,value))or math.max(column.minWidth,math.min(column.maxWidth,column.defaultWidth))
 end
 function frame:ApplyColumnWidths()
  local total=0
  for i,column in ipairs(self.columns)do
   local h=self.columnHeaders[i];h.button:ClearAllPoints();h.button:SetPoint("TOPLEFT",total,0)
   h.button:SetWidth(column.width);h.label:SetWidth(column.width-10)
   if h.second then h.second:SetWidth(column.width-10)end
   h.x=total
   local visible=G:IsRosterColumnVisible(column.key)
   h.button:SetShown(visible);if h.grip then h.grip:SetShown(visible)end
   for _,row in ipairs(self.rows)do
    local cell=row.cells[i];cell:ClearAllPoints();cell:SetPoint("TOPLEFT",total+4,0);cell:SetWidth(column.width-8)
    cell:SetShown(visible)
    local hit=row.detailHits and row.detailHits[i]
    if hit then hit:ClearAllPoints();hit:SetPoint("TOPLEFT",total,0);hit:SetWidth(column.width);hit:SetShown(visible)end
    if column.key=="class"then row.classIcon:ClearAllPoints();row.classIcon:SetPoint("TOPLEFT",total+(column.width-22)/2,-4)end
   end
   if visible then total=total+column.width end
  end
  self.header:SetWidth(total);self.rosterContent:SetWidth(total)
  for _,row in ipairs(self.rows)do row:SetWidth(total)end
  local maximum=math.max(0,total-self.rosterViewport:GetWidth())
  self.horizontalSlider:SetMinMaxValues(0,maximum)
  self.horizontalSlider:SetValue(math.min(self.horizontalSlider:GetValue(),maximum))
 end
 local function stop()
  if not frame.columnDrag then return end
  frame.columnDrag=nil;frame.resizeDriver:SetScript("OnUpdate",nil)
  for _,column in ipairs(frame.columns)do saved[column.key]=column.width end
 end
 frame.StopColumnDrag=stop
 frame.resizeDriver=CreateFrame("Frame",nil,frame)
 frame:HookScript("OnHide",stop)
 for i,column in ipairs(frame.columns)do
  local h=frame.columnHeaders[i]
  G:AttachHelp(h.button,h.heading or h.label:GetText(),column.minWidth==column.maxWidth and (G:Text("Нажмите для сортировки; повторное нажатие меняет порядок. Ширина этого столбца фиксирована. Полное название профессии видно при наведении на ячейку."))or (G:Text("Нажмите для сортировки; повторное нажатие меняет порядок. Перетащите правую границу для изменения ширины в установленных пределах. Длинный текст обрезается.")))
  local grip=CreateFrame("Button",nil,frame.header);h.grip=grip
  grip:SetSize(32,h.button:GetHeight());grip:SetPoint("CENTER",h.button,"RIGHT",0,0)
  local hover=grip:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(.3,.65,.9,.35)
  grip:SetFrameLevel(h.button:GetFrameLevel()+5);grip:EnableMouse(true)
  local edge=grip:CreateTexture(nil,"BACKGROUND");edge:SetPoint("TOP",0,-5);edge:SetSize(1,h.button:GetHeight()-10);edge:SetColorTexture(.55,.65,.7,.55)
  G:AttachHelp(grip,(G:Text("Ширина столбца")),(G:Text("Перетащите границу вправо или влево. Минимальная ширина ограничена; выбранные размеры сохраняются после выхода из игры или /reload.")))
  if column.minWidth==column.maxWidth then
   grip:EnableMouse(false)
  end
  grip:SetScript("OnMouseDown",function(_,button)
   if button~="LeftButton"or column.minWidth==column.maxWidth then return end
   local cursor=GetCursorPosition();frame.columnDrag={x=cursor,width=column.width,column=column}
   frame.resizeDriver:SetScript("OnUpdate",function()
    local drag=frame.columnDrag;if not drag then return end
    if not IsMouseButtonDown("LeftButton")then stop();return end
    local x=GetCursorPosition();local scale=frame:GetEffectiveScale()
    local value=math.floor(drag.width+(x-drag.x)/scale+.5)
    value=math.max(drag.column.minWidth,math.min(drag.column.maxWidth,value))
    if value~=drag.column.width then drag.column.width=value;frame:ApplyColumnWidths()end
   end)
  end)
  grip:SetScript("OnMouseUp",stop)
  grip:HookScript("OnHide",stop)
 end
 local reset=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");frame.resetWidths=reset
 reset:SetSize(150,26);reset:SetPoint("TOPRIGHT",frame.horizontalRail,"BOTTOMRIGHT",0,-5)
 reset:SetText((G:Text("Сбросить ширину")));G:ApplyFont(reset:GetFontString(),11)
 reset:SetScript("OnClick",function()
  stop()
  for _,column in ipairs(frame.columns)do column.width=column.resetWidth;saved[column.key]=nil end
  frame:ApplyColumnWidths()
 end)
 G:AttachHelp(reset,(G:Text("Сбросить ширину")),(G:Text("Вернуть исходную ширину всех столбцов таблицы. Поиск и фильтры не изменяются.")))
 G:AttachHelp(frame.horizontalSlider,(G:Text("Прокрутка таблицы")),(G:Text("Перетащите ползунок или используйте колесо мыши над полосой, чтобы увидеть столбцы слева и справа.")))
 G:AttachHelp(frame.horizontalLeft,(G:Text("Влево")),(G:Text("Прокрутить таблицу влево. Заголовки и строки перемещаются вместе.")))
 G:AttachHelp(frame.horizontalRight,(G:Text("Вправо")),(G:Text("Прокрутить таблицу вправо. Заголовки и строки перемещаются вместе.")))
 local vertical=frame.scroll.modernRail
 if vertical then
  G:AttachHelp(vertical.up,(G:Text("Вверх")),(G:Text("Показать предыдущую строку состава.")))
  G:AttachHelp(vertical.down,(G:Text("Вниз")),(G:Text("Показать следующую строку состава.")))
 end
 frame:ApplyColumnWidths()
end
function G:ModernVerticalScrollbar(scroll,anchor,y,height,step)
 local bar=_G[scroll:GetName().."ScrollBar"];if not bar then return end
 if scroll.modernRail then return scroll.modernRail end
 local rail=CreateFrame("Frame",nil,scroll:GetParent());scroll.modernRail=rail
 rail:SetPoint("TOPLEFT",anchor,"TOPRIGHT",0,y);rail:SetSize(22,height)
 local size=height>=100 and 22 or 16;local gap=size+2
 -- Keep native parent, range and callbacks: templates resolve GetParent().
 bar:ClearAllPoints();bar:SetPoint("TOPLEFT",rail,"TOPLEFT",0,-gap);bar:SetPoint("BOTTOMRIGHT",rail,"BOTTOMRIGHT",0,gap)
 bar:SetFrameLevel(scroll:GetFrameLevel()+20);bar:EnableMouse(true);bar:SetOrientation("VERTICAL")
 bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
 local thumb=bar:GetThumbTexture();thumb:SetSize(22,math.min(22,math.max(10,(height-2*gap)/2)))
 for _,region in ipairs({bar:GetRegions()})do if region~=thumb and region.Hide then region:Hide()end end
 for _,suffix in ipairs({"ScrollUpButton","ScrollDownButton"})do
  local old=_G[bar:GetName()..suffix]or bar[suffix]
  if old then old:Hide();old:EnableMouse(false)end
 end
 local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.08,.12,.16,.95)
 for i,label in ipairs({"^","v"})do
  local b=CreateFrame("Button",nil,rail,"UIPanelButtonTemplate");b:SetSize(22,size)
  b:SetPoint(i==1 and"TOPLEFT"or"BOTTOMLEFT",0,0);b:SetText(label)
  b:SetFrameLevel(bar:GetFrameLevel()+1)
  b:SetScript("OnClick",function()bar:SetValue(bar:GetValue()+(i==1 and-step or step))end)
  if i==1 then rail.up=b else rail.down=b end
 end
 local function update()
  local lo,hi=bar:GetMinMaxValues();local value=bar:GetValue()
  rail:SetShown(scroll:IsShown()and bar:IsShown()and hi>lo)
  rail.up:SetEnabled(value>lo);rail.down:SetEnabled(value<hi)
 end
 bar:HookScript("OnValueChanged",update);bar:HookScript("OnShow",update)
 bar:HookScript("OnHide",function()rail:Hide()end)
 scroll:HookScript("OnShow",update);scroll:HookScript("OnHide",function()rail:Hide()end)
 scroll:HookScript("OnScrollRangeChanged",update)
 update();return rail
end
function G:RosterFamilyStatus(member)
 local family=self:PresentationFamily(member)
 if not family then return self.L.FAMILY_UNKNOWN end
 if family.mainStatus=="conflict"then return (G:Text("Конфликт меток"))end
 if family.incomplete then return (G:Text("Связи не подтверждены"))end
 if family.mainGUID then return family.mainGUID==member.guid and self.L.FAMILY_MAIN or self.L.FAMILY_ALT end
 return #family.members>1 and (G:Text("Персонажей: "))..#family.members or (G:Text("1 персонаж"))
end
function G:SetRosterClass(row,member)
 local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[member.classFile]
 row.classIcon:SetShown(coords~=nil)
 if coords then
  row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
  row.classIcon:SetTexCoord(unpack(coords));row.cells[2]:SetText("")
 else row.cells[2]:SetText("?")end
end
function G:CreateRosterViewport(frame,contentWidth,viewportWidth,headerHeight,rowHeight,visible)
 local clip=CreateFrame("ScrollFrame",nil,frame)
 clip:SetPoint("TOPLEFT",18,-196);clip:SetSize(viewportWidth,headerHeight+rowHeight*visible)
 local content=CreateFrame("Frame",nil,clip);content:SetSize(contentWidth,headerHeight+rowHeight*visible)
 clip:SetScrollChild(content);frame.rosterViewport=clip;frame.rosterContent=content
 local rail=CreateFrame("Frame",nil,frame);rail:SetPoint("TOPLEFT",clip,"BOTTOMLEFT",0,-8);rail:SetSize(viewportWidth,22)
 frame.horizontalRail=rail
 local slider=CreateFrame("Slider",nil,rail);frame.horizontalSlider=slider
 slider:EnableMouse(true)
 slider:SetOrientation("HORIZONTAL");slider:SetPoint("TOPLEFT",24,0);slider:SetSize(viewportWidth-48,22)
 local bg=slider:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.08,.12,.16,.95)
 slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
 local thumb=slider:GetThumbTexture();thumb:SetSize(24,22)
 slider:SetMinMaxValues(0,math.max(0,contentWidth-viewportWidth));slider:SetValueStep(1)
 slider:SetScript("OnValueChanged",function(_,value)
  local max=math.max(0,content:GetWidth()-clip:GetWidth())
  local x=math.max(0,math.min(max,math.floor(value+.5)))
  frame.rosterHorizontalOffset=x;clip:SetHorizontalScroll(x)
 end)
 slider:EnableMouseWheel(true)
 slider:SetScript("OnMouseWheel",function(_,delta)slider:SetValue(slider:GetValue()-delta*60)end)
 for i,label in ipairs({"<",">"})do
  local button=CreateFrame("Button",nil,rail,"UIPanelButtonTemplate");button:SetSize(22,22)
  button:SetPoint(i==1 and"LEFT"or"RIGHT",rail,i==1 and"LEFT"or"RIGHT",0,0);button:SetText(label)
  button:SetScript("OnClick",function()slider:SetValue(slider:GetValue()+(i==1 and-80 or 80))end)
  if i==1 then frame.horizontalLeft=button else frame.horizontalRight=button end
 end
 slider:SetValue(frame.rosterHorizontalOffset or 0)
 local function vertical(_,delta)
  local scroll=frame.scroll;local bar=scroll and _G[scroll:GetName().."ScrollBar"]
  if bar then bar:SetValue(bar:GetValue()-delta*rowHeight*3)end
 end
 clip:EnableMouseWheel(true);clip:SetScript("OnMouseWheel",vertical)
 frame.rosterWheel=vertical
 return content
end
