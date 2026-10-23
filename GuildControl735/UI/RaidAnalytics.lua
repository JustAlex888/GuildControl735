-- Raid content shares the accepted analytics table layout; no new transport.
local _,G=...
local P=G.RaidAnalytics
local function Label(parent,text,x,y,width)
 local t=parent:CreateFontString(nil,"ARTWORK","GameFontNormal");G:ApplyFont(t,12)
 t:SetPoint("TOPLEFT",x,-y);t:SetSize(width,24);t:SetJustifyH("LEFT");t:SetWordWrap(false);t:SetText(text);return t
end
function P:CreateContent(page,outer,host)
 local s=self:State();local f=CreateFrame("Frame",nil,outer);self.frame=f;page.raid=f
 f:SetPoint("TOPLEFT",outer,"TOPLEFT",0,-38);f:SetPoint("BOTTOMRIGHT",outer,"BOTTOMRIGHT",0,0);f.rows={};f.headers={}
 G.AnalyticsSearch:CreateField("raid",f,24,158,function()if f.scroll then f.scroll.offset=0 end;P:Render()end)
 local function Refresh()P:Render()end
 local function Reset()if f.scroll then f.scroll.offset=0 end end
 local function Checkbox(key,x,y,text,width)
  local c=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");c:SetSize(26,26);c:SetPoint("TOPLEFT",x,-y)
  c:SetChecked(s[key]==true);Label(f,text,x+30,y+2,width)
  c:SetScript("OnClick",function(o)s[key]=o:GetChecked()and true or false;Reset();Refresh()end)
  G:AttachHelp(c,text,(G:Text("Включить ограничение. Значение сохраняется при выключении.")));return c
 end
 local function Edit(x,y,value,key,help)
  local e=CreateFrame("EditBox",nil,f,"InputBoxTemplate");e:SetSize(58,24);e:SetPoint("TOPLEFT",x,-y);e:SetAutoFocus(false);e:SetNumeric(true);e:SetMaxLetters(5);e:SetText(value)
  local function Save(o)local n=tonumber(o:GetText());if n and n==n then s[key]=math.max(0,math.min(36500,math.floor(n)))end;o:SetText(s[key]);Reset();Refresh()end
  e:SetScript("OnEnterPressed",function(o)Save(o);o:ClearFocus()end);e:SetScript("OnEditFocusLost",Save);e:SetScript("OnEscapePressed",function(o)o:ClearFocus()end)
  G:AttachHelp(e,help,(G:Text("Введите число дней. Это фильтр состава, а не период рейдовой статистики.")));return e
 end
 f.onlineCheck=Checkbox("onlineEnabled",24,34,(G:Text("Последний онлайн не более")),230)
 f.onlineEdit=Edit(294,36,tostring(s.onlineDays),"onlineDays",(G:Text("Давность онлайна")));Label(f,(G:Text("дней назад")),363,38,105)
 f.responseCheck=Checkbox("responseEnabled",24,70,(G:Text("Последний ответ аддона не более")),265)
 f.responseEdit=Edit(332,72,tostring(s.responseDays),"responseDays",(G:Text("Давность ответа аддона")));Label(f,(G:Text("дней назад")),400,74,105)
 G:AttachHelp(f.responseCheck,(G:Text("Последний ответ аддона")),(G:Text("Подтверждённый ответ владельца Guild Control, не дата убийства босса и не посещение рейда.")))
 f.onlineOnly=Checkbox("onlineOnly",720,116,G.L.ONLINE_ONLY,170)
 Label(f,(G:Text("Рейд")),540,36,105);Label(f,(G:Text("Сложность")),540,72,105)
 for _,entry in ipairs({{"raid","GC735RaidSelection",P:Raids(),34},{"difficulty","GC735RaidDifficulty",P.difficulties,70}})do
  local key,name,choices,y=unpack(entry);local menu=G.Dropdown.Create(name,f);f[key]=menu
  menu:SetSize(280,28);menu:SetPoint("TOPLEFT",660,-y)
  local function Name()for _,c in ipairs(choices)do if c.id==s[key]then return c.name end end end
  menu:SetText(Name())
  G.Dropdown.Initialize(menu,function()for _,c in ipairs(choices)do
   local id,label=c.id,c.name
   G.Dropdown.AddButton({text=label,checked=s[key]==id,func=function()s[key]=id;menu:SetText(label);Reset();P:Layout();Refresh()end})
  end end)
  G:AttachHelp(menu,key=="raid"and(G:Text("Рейд"))or(G:Text("Сложность")),(G:Text("Накопленные убийства боссов по статистике персонажа. Это не посещаемость и не количество за неделю.")))
 end
 local classes=G.Dropdown.Create("GC735RaidClasses",f);f.classes=classes;classes:SetSize(180,28);classes:SetPoint("TOPLEFT",24,-116);classes:SetText((G:Text("Классы")))
 G.Dropdown.Initialize(classes,function()
  G.Dropdown.AddButton({text=(G:Text("Все классы")),func=function()for k in pairs(s.classes)do s.classes[k]=nil end;Reset();Refresh()end})
  local names={};for _,m in ipairs(G.Roster.members or{})do if m.classFile then names[m.classFile]=m.class or m.classFile end end
  local keys={};for k in pairs(names)do keys[#keys+1]=k end;table.sort(keys)
  for _,key in ipairs(keys)do local k=key;G.Dropdown.AddButton({text=names[k],checkmark=true,checked=s.classes[k],keepShownOnClick=true,func=function()s.classes[k]=not s.classes[k];Reset();Refresh()end})end
 end)
 local columns=G.Dropdown.Create("GC735RaidColumns",f);f.columnPicker=columns;columns:SetSize(230,28);columns:SetPoint("TOPLEFT",218,-116);columns:SetText((G:Text("Столбцы рейда")))
 G.Dropdown.Initialize(columns,function()
   local all=true;for _,d in ipairs(P:Definitions())do if not d[3]and not s.columns[d[1]]then all=false end end
   G.Dropdown.AddButton({text=(G:Text("Все столбцы")),checked=all,func=function()
    for _,d in ipairs(P:Definitions())do if not d[3]then s.columns[d[1]]=true end end
    P:Layout();Refresh()
   end})
for _,d in ipairs(P:Definitions())do if not d[3]then local k=d[1];G.Dropdown.AddButton({text=d[2],checkmark=true,checked=s.columns[k],keepShownOnClick=true,func=function()s.columns[k]=not s.columns[k];P:Layout();Refresh()end})end end end)
 G:AttachHelp(classes,(G:Text("Классы")),(G:Text("Один или несколько классов; без галочек показаны все.")))
 G:AttachHelp(columns,(G:Text("Столбцы рейда")),(G:Text("Все показатели включены по умолчанию. Имя, класс, уровень и звание постоянны. Выбор столбцов не скрывает персонажей. Счётчик учитывает переключаемые показатели; четыре постоянных столбца не входят в него.")))
 for _,menu in ipairs({f.raid,f.difficulty,classes,columns})do for _,row in ipairs(menu.rows or{})do
  row:HookScript("OnEnter",function(o)if not o.item then return end;GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:SetText(o.item.text or"");GameTooltip:AddLine((G:Text("Изменить выбор; остальные настройки сохраняются.")),1,1,1,true);GameTooltip:Show()end)
  row:HookScript("OnLeave",function()GameTooltip:Hide()end)
  row:HookScript("OnHide",function(o)if GameTooltip:IsOwned(o)then GameTooltip:Hide()end end)
 end end
 local refresh=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.refresh=refresh;refresh:SetSize(130,28);refresh:SetPoint("TOPRIGHT",-48,26);refresh:SetText((G:Text("Обновить")))
 refresh:SetScript("OnClick",function()local ok,why=G.RaidRuntime:Request("ALL");if not ok then G:Print((G:Text("Запрос рейдов недоступен: "))..tostring(why))end end)
 refresh:SetScript("OnEnter",function(o)GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:SetText((G:Text("Обновить рейдовую статистику")));GameTooltip:AddLine((G:Text("Существующий разрешённый запрос Guild Control для участников онлайн. Без ответа остаётся сохранённая статистика. Переключение рейда/сложности не отправляет запросов.")),1,1,1,true);GameTooltip:Show()end)
 refresh:SetScript("OnLeave",function()GameTooltip:Hide()end)
 function f:UpdateSelectionLabels()
  local count=0;for _,selected in pairs(s.classes)do if selected then count=count+1 end end
  self.classes:SetText((G:Text("Классы: "))..(count==0 and(G:Text("Все"))or tostring(count)))
  local selected,total=0,0
  for _,d in ipairs(P:Definitions())do if not d[3]then total=total+1;if s.columns[d[1]]then selected=selected+1 end end end
  self.columnPicker:SetText((G:Text("Столбцы рейда ("))..(selected==total and(G:Text("Все"))or selected.."/"..total)..")")

 end
 f:UpdateSelectionLabels()
 f.status=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");G:ApplyFont(f.status,12)
 f.status:SetPoint("BOTTOMLEFT",22,23)

 G:CreateAnalyticsReset(f,"raid",s,function()return P:Definitions()end,function()P:Layout();Refresh()end)
 local content=G:CreateRosterViewport(f,1000,1000,43,30,12)
 f.header=CreateFrame("Frame",nil,content);f.header:SetPoint("TOPLEFT",0,0);f.header:SetHeight(43)
 f.scroll=CreateFrame("ScrollFrame","GC735RaidAnalyticsScroll",f,"FauxScrollFrameTemplate")
 f.scroll:SetScript("OnVerticalScroll",function(o,v)FauxScrollFrame_OnVerticalScroll(o,v,30,Refresh)end)
 f.measure=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");G:ApplyFont(f.measure,12);f.measure:Hide()
 f.driver=CreateFrame("Frame",nil,f);f.StopDrag=function()f.drag=nil;f.driver:SetScript("OnUpdate",nil)end
 f:HookScript("OnHide",function()f.StopDrag();G.Dropdown.Close();GameTooltip:Hide()end)
 f:SetScript("OnUpdate",function(_,elapsed)f.elapsed=(f.elapsed or 0)+elapsed;if f.elapsed>=1 then f.elapsed=0;Refresh()end end)
 for _,control in ipairs({f.horizontalSlider,f.horizontalLeft,f.horizontalRight})do G:AttachHelp(control,(G:Text("Прокрутка таблицы")),(G:Text("Заголовки и строки перемещаются вместе.")))end
 f:Hide()
end
function P:Layout()
 local f=self.frame;if not f or not f:IsShown()or f.laying then return end;f.laying=true
 local s=self:State();local host=G.ShellWindow;local width,height=host:GetWidth(),host:GetHeight()
 local visible=math.max(1,math.min(128,math.floor((height-356)/30)));f.visibleRows=visible
 local viewport=width-62
 f.rosterViewport:SetSize(viewport,43+visible*30);f.rosterContent:SetHeight(43+visible*30)
 f.horizontalRail:SetWidth(viewport);f.horizontalSlider:SetWidth(viewport-48)
 f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",f.rosterViewport,"TOPLEFT",0,-43);f.scroll:SetSize(viewport,visible*30)
 local rail=f.scroll.modernRail
 if not rail then rail=G:ModernVerticalScrollbar(f.scroll,f.rosterViewport,-43,visible*30,30)
  if rail then G:AttachHelp(rail.up,(G:Text("Вверх")),(G:Text("Показать предыдущую строку.")));G:AttachHelp(rail.down,(G:Text("Вниз")),(G:Text("Показать следующую строку.")))end
 end
 if rail then rail:SetHeight(visible*30)end
  for key,h in pairs(f.headers)do
   if key~="name"and key~="class"and key~="level"and key~="rank"then h:Hide();h.grip:Hide()end
  end
 if f.headerRaid~=s.raid then
  for _,h in pairs(f.headers)do h:Hide();h.grip:Hide()end
  f.raidHeaders=f.raidHeaders or{};f.raidHeaders[f.headerRaid or s.raid]=f.headers
  f.headers=f.raidHeaders[s.raid]or{};f.raidHeaders[s.raid]=f.headers;f.headerRaid=s.raid
 end
 local samples=self:WidthSamples()
 if f.widthSamples~=self.widthMemo then
  f.metricWidths={}
  for key,values in pairs(samples)do
   local widest=0
   for _,value in ipairs(values)do f.measure:SetText(value);widest=math.max(widest,f.measure:GetStringWidth())end
   f.metricWidths[key]=widest
  end
  f.widthSamples=self.widthMemo
 end
 f.columns={};local total=0
 for _,d in ipairs(P:Definitions())do if d[3]or s.columns[d[1]]then
  local key=d[1];local heading=d[4]or d[2];local textWidth=0
  for line in heading:gmatch("[^\n]+")do f.measure:SetText(line);textWidth=math.max(textWidth,f.measure:GetStringWidth())end
  textWidth=math.max(textWidth,f.metricWidths[key]or 0)
  local minimum=math.ceil(textWidth+12);local maximum=minimum
  if key=="name"or key=="rank"or key=="level"then for _,base in ipairs(G.MainWindow.columns)do if base.key==key then minimum,maximum=base.minWidth,base.maxWidth;break end end end
  if key=="class"then
   for _,base in ipairs(G.MainWindow.columns)do if base.key==key then minimum=math.max(base.minWidth,math.ceil(textWidth+14));break end end
   maximum=minimum
  end
  local value=tonumber(s.widths[key])
  local cw=math.max(minimum,math.min(maximum,value or minimum))
  local h=f.headers[key]
  if not h then
   h=CreateFrame("Button",nil,f.header);f.headers[key]=h;h:SetHeight(43)
   local bg=h:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.12,.20,.28,.95)
   h.text=h:CreateFontString(nil,"ARTWORK","GameFontNormalSmall");G:ApplyFont(h.text,12)
   local first,second=heading:match("^([^\n]+)\n(.+)$")
   h.heading=heading;h.text:SetPoint("TOPLEFT",5,second and-3 or-2);h.text:SetSize(minimum-10,second and 18 or 39);h.text:SetJustifyH("LEFT");h.text:SetJustifyV("MIDDLE");h.text:SetWordWrap(false);h.text:SetText(first or heading)
   if second then
    h.second=h:CreateFontString(nil,"ARTWORK","GameFontNormalSmall");G:ApplyFont(h.second,12)
    h.second:SetPoint("TOPLEFT",5,-22);h.second:SetSize(minimum-10,18);h.second:SetJustifyH("LEFT");h.second:SetJustifyV("MIDDLE");h.second:SetWordWrap(false);h.second:SetText(second)
   end
   h:SetScript("OnClick",function()if s.sort==key then s.descending=not s.descending else s.sort=key;s.descending=not d[3]end;P:Render()end)
   G:AttachHelp(h,d[2],(G:Text("Нажмите для сортировки. Накопленные убийства на выбранной сложности. Прогресс — подтверждённые убитые боссы, как в сводке Общих данных. Прочерк — нет подтверждённого числа, не ноль.")))
   local grip=CreateFrame("Button",nil,f.header);h.grip=grip;grip:SetSize(32,43);grip:SetPoint("CENTER",h,"RIGHT",0,0);grip:SetFrameLevel(h:GetFrameLevel()+5);grip:EnableMouse(true)
   local hover=grip:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(.3,.65,.9,.35)
   local edge=grip:CreateTexture(nil,"BACKGROUND");edge:SetSize(1,33);edge:SetPoint("CENTER",0,0);edge:SetColorTexture(.55,.65,.7,.55)
   grip:SetScript("OnMouseDown",function(_,b)
    if b~="LeftButton"or h.minimum==h.maximum then return end
    f.drag={x=GetCursorPosition(),width=h:GetWidth()}
    f.driver:SetScript("OnUpdate",function()
     if not IsMouseButtonDown("LeftButton")then f.StopDrag();return end
     s.widths[key]=math.max(h.minimum,math.min(h.maximum,math.floor(f.drag.width+(GetCursorPosition()-f.drag.x)/f:GetEffectiveScale()+.5)))
     P:Layout();P:Render()
    end)
   end)
   grip:SetScript("OnMouseUp",f.StopDrag);grip:HookScript("OnHide",f.StopDrag)
   G:AttachHelp(grip,(G:Text("Ширина столбца")),(G:Text("Изменяется только ширина имени и звания. Остальные столбцы имеют компактную фиксированную ширину.")))
  end
  h.minimum,h.maximum=minimum,maximum;h:ClearAllPoints();h:SetPoint("TOPLEFT",total,0);h:SetWidth(cw);h.text:SetWidth(cw-10);if h.second then h.second:SetWidth(cw-10)end;h:Show()
  h.grip:EnableMouse(minimum~=maximum);h.grip:Show()
  f.columns[#f.columns+1]={key=key,x=total,width=cw};total=total+cw
 end end
 f.header:SetWidth(total);f.rosterContent:SetWidth(total)
 for i=1,visible do
  local row=f.rows[i]
  if not row then row=CreateFrame("Frame",nil,f.rosterContent);row.cells={};row.classIcon=row:CreateTexture(nil,"ARTWORK");row.classIcon:SetSize(22,22);f.rows[i]=row;row:SetHeight(30);row:EnableMouse(true)
   row:SetScript("OnEnter",function(o)
    local data=o.data;if not data then return end
    GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:SetText(data.member.name or (G:Text("Рейды")))
    GameTooltip:AddLine(data.reason or (G:Text("Накопленная статистика выбранной сложности.")),1,1,1,true)
    if data.savedAt then GameTooltip:AddLine((G:Text("Снимок: "))..date("%d.%m.%Y %H:%M",data.savedAt),1,1,1,true)end
    GameTooltip:AddLine((G:Text("Числа накопленные; дата снимка не является датой убийства. Посещаемость, неделя и роли по этим данным не определяются.")),1,1,1,true);GameTooltip:Show()
   end)
   row:SetScript("OnLeave",function()GameTooltip:Hide()end)
   row:HookScript("OnHide",function(o)if GameTooltip:IsOwned(o)then GameTooltip:Hide()end end)
  end
  row:SetPoint("TOPLEFT",0,-43-(i-1)*30);row:SetWidth(total)
  for _,cell in pairs(row.cells)do cell:Hide()end
  for _,c in ipairs(f.columns)do
   local cell=row.cells[c.key];if not cell then cell=Label(row,"",0,0,c.width);cell:SetTextColor(1,1,1);row.cells[c.key]=cell end
   cell:ClearAllPoints();cell:SetPoint("TOPLEFT",c.x+5,-4);cell:SetWidth(c.width-10);cell:Show()
   if c.key=="class"then row.classIcon:ClearAllPoints();row.classIcon:SetPoint("TOPLEFT",c.x+(c.width-22)/2,-4)end
  end
 end
 for i=visible+1,#f.rows do f.rows[i]:Hide()end
 f.horizontalSlider:SetMinMaxValues(0,math.max(0,total-viewport));f.horizontalSlider:SetValue(math.min(f.horizontalSlider:GetValue(),math.max(0,total-viewport)))
 f.laying=nil
end
function P:Render()
 local f=self.frame;if not f or not f:IsShown()or not f.visibleRows then return end
 local s=self:State();local stamp=tostring(s.raid)..":"..tostring(s.difficulty)
 if f.widthStamp~=stamp then f.widthStamp=stamp;self:Layout()end
 f:UpdateSelectionLabels()
 local rows=self:Rows();f.status:SetText(string.format(G.L.MEMBERS_SHOWN,#rows,#(G.Roster.members or{})))
 local offset=FauxScrollFrame_GetOffset(f.scroll)
 offset=math.max(0,math.min(offset,math.max(0,#rows-f.visibleRows)));f.scroll.offset=offset
 FauxScrollFrame_Update(f.scroll,#rows,f.visibleRows,30)
 for i=1,f.visibleRows do
  local row=f.rows[i];local data=rows[i+offset];row:SetShown(data~=nil)
  row.data=data
  if data then
   for _,c in ipairs(f.columns)do
    local value=data[c.key];if c.key=="name"then value=data.member.online and G:ClassName(data.member)or data.name end
    local muted=c.key~="name"and c.key~="class"and c.key~="level"and c.key~="rank"and(value==nil or value==0)
    local color=(not data.member.online or muted)and .55 or 1;row.cells[c.key]:SetTextColor(color,color,color)
    row.cells[c.key]:SetText(P:Format(c.key,value))
   end
   local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[data.member.classFile];row.classIcon:SetShown(coords~=nil)
   if coords then row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");row.classIcon:SetTexCoord(unpack(coords));row.cells.class:SetText("")else row.cells.class:SetText("?")end
  end
 end
end
