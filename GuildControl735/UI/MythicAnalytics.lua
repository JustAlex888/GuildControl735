local _,G=...
local A=G.MythicAnalytics
local definitions=G:RegisterLocaleTable({},function()return {{"name",G.L.HEADER_NAME,true},{"class",G.L.HEADER_CLASS,true},{"level",G.L.HEADER_LEVEL,true},{"rank",G.L.HEADER_RANK,true},
 {"total",(G:Text("Всего прохождений")),false,(G:Text("Всего\nпрохождений"))},{"2-4","2–4"},{"5-9","5–9"},{"10-14","10–14"},{"15-19","15–19"},
 {"20-24","20–24"},{"25-29","25–29"},{"30-34","30–34"},{"35+","35+"},
 {"place",(G:Text("Место в ладдере")),false,(G:Text("Место в\nладдере"))},{"classPlace",(G:Text("Место по классу")),false,(G:Text("Место по\nклассу"))},{"rating",(G:Text("Рейтинг Mythic+")),false,(G:Text("Рейтинг\nMythic+"))},
 {"tank",(G:Text("Рейтинг танка")),false,(G:Text("Рейтинг\nтанка"))},{"heal",(G:Text("Рейтинг хила")),false,(G:Text("Рейтинг\nхила"))},{"dps",(G:Text("Рейтинг DD")),false,(G:Text("Рейтинг\nDD"))}} end)
local function Label(parent,text,x,y,width)
 local t=parent:CreateFontString(nil,"ARTWORK","GameFontNormal");G:ApplyFont(t,12)
 t:SetPoint("TOPLEFT",x,-y);t:SetSize(width,24);t:SetJustifyH("LEFT");t:SetWordWrap(false);t:SetText(text);return t
end
local function Clock(n)return string.format("%02d:%02d",math.floor(n/60),n%60)end
function A:CreatePage()
 local page={width=1350,height=760}
 function page:Init(host)
  local s=A:State();local outer=CreateFrame("Frame",nil,host);self.frame=outer;outer:SetAllPoints(host)
  local f=CreateFrame("Frame",nil,outer);self.mythic=f;A.frame=f
  f:SetPoint("TOPLEFT",outer,"TOPLEFT",0,-38);f:SetPoint("BOTTOMRIGHT",outer,"BOTTOMRIGHT",0,0);f.rows={};f.headers={};f.offset=0
  self.tabs={}
  for i,entry in ipairs({{"mythic","Mythic+"},{"raid",(G:Text("Рейды"))},{"pvp",(G:Text("PvP-активности"))}})do
   local id,name=entry[1],entry[2];local b=CreateFrame("Button",nil,outer,"UIPanelButtonTemplate")
   b:SetSize(188,26);b:SetPoint("TOPLEFT",24+(i-1)*198,-12);b:SetText(name);self.tabs[id]=b
   b:SetScript("OnClick",function()self:SelectSection(id)end)
   G:AttachHelp(b,name,id=="mythic"and(G:Text("Аналитика прохождений Mythic+."))or id=="pvp"and(G:Text("Статистика PvP по режимам и периодам ладдера."))or(G:Text("Накопленный прогресс и убийства боссов по рейду и сложности. Посещаемость и период не вычисляются.")))
  end
  self.placeholder=Label(outer,"",28,76,700);self.placeholder:Hide()
  G.PvPAnalytics:CreateContent(self,outer,host)
  G.RaidAnalytics:CreateContent(self,outer,host)
  G.AnalyticsSearch:CreateField("mythic",f,24,158,function()if f.scroll then f.scroll.offset=0 end;A:Render()end)
  local function Refresh()A:Render()end
  local function Reset()if f.scroll then f.scroll.offset=0 end end
  local function Checkbox(key,x,y,text,width)
   local c=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");c:SetSize(26,26);c:SetPoint("TOPLEFT",x,-y)
   c:SetChecked(s[key]==true);Label(f,text,x+30,y+2,width)
   c:SetScript("OnClick",function(o)s[key]=o:GetChecked()and true or false;Reset();Refresh()end)
   G:AttachHelp(c,text,(G:Text("Включить или выключить это ограничение. Значение сохраняется при выключении.")))
   return c
  end
  local function Edit(x,y,width,value,commit,help,numeric)
   local e=CreateFrame("EditBox",nil,f,"InputBoxTemplate");e:SetSize(width,24);e:SetPoint("TOPLEFT",x,-y);e:SetAutoFocus(false)
   if numeric then e:SetNumeric(true);e:SetMaxLetters(5)else e:SetMaxLetters(5)end
   e:SetText(value)
   local function Save(o)commit(o);Reset();Refresh()end
   e:SetScript("OnEnterPressed",function(o)Save(o);o:ClearFocus()end)
   e:SetScript("OnEditFocusLost",Save);e:SetScript("OnEscapePressed",function(o)o:ClearFocus()end)
   G:AttachHelp(e,help,(G:Text("Введите значение и нажмите Enter или перейдите к другому полю.")))
   return e
  end
  f.onlineCheck=Checkbox("onlineEnabled",24,34,(G:Text("Последний онлайн не более")),230)
  f.onlineOnly=Checkbox("onlineOnly",720,116,G.L.ONLINE_ONLY,170)
  G:AttachHelp(f.onlineOnly,G.L.ONLINE_ONLY,(G:Text("Показывать только персонажей, которые сейчас в сети по данным состава Blizzard.")))
  f.onlineEdit=Edit(294,36,58,tostring(s.onlineDays),function(e)local n=tonumber(e:GetText());if n then s.onlineDays=math.max(0,math.min(36500,math.floor(n)))end;e:SetText(s.onlineDays)end,(G:Text("Давность онлайна")),true)
  Label(f,(G:Text("дней назад")),363,38,105)
  f.responseCheck=Checkbox("responseEnabled",24,70,(G:Text("Последний ответ аддона не более")),265)
  f.responseEdit=Edit(332,72,58,tostring(s.responseDays),function(e)local n=tonumber(e:GetText());if n then s.responseDays=math.max(0,math.min(36500,math.floor(n)))end;e:SetText(s.responseDays)end,(G:Text("Давность ответа аддона")),true)
  Label(f,(G:Text("дней назад")),400,74,105)
  G:AttachHelp(f.responseCheck,(G:Text("Последний ответ аддона")),(G:Text("Учитывается подтверждённый ответ владельца в существующем обмене с момента этой версии. Получение старого кэша от посредника не обновляет дату. Отсутствие ответа не доказывает удаление аддона.")))
  f.periodCheck=Checkbox("periodEnabled",540,34,(G:Text("Период прохождений")),175)
  local period=Edit(750,36,58,tostring(s.days),function(e)local n=tonumber(e:GetText());if n then s.days=math.max(1,math.min(99,math.floor(n)))end;e:SetText(s.days)end,(G:Text("Период прохождений: 1–99 дней")),true);f.period=period
  period:SetMaxLetters(2);Label(f,(G:Text("дней")),819,38,55)
  G:AttachHelp(period,(G:Text("Период прохождений")),(G:Text("Введите от 1 до 99 последних суток. Без галочки учитывается вся доступная история ладдера.")))
  f.timeCheck=Checkbox("timeEnabled",540,70,(G:Text("Время завершения ключей: с")),240)
  f.startEdit=Edit(812,72,62,Clock(s.startMinute),function(e)local n=A:Minute(e:GetText());if n then s.startMinute=n end;e:SetText(Clock(s.startMinute))end,(G:Text("Начало интервала, серверное время")))
  Label(f,(G:Text("до")),884,74,24)
  f.endEdit=Edit(918,72,62,Clock(s.endMinute),function(e)local n=A:Minute(e:GetText());if n then s.endMinute=n end;e:SetText(Clock(s.endMinute))end,(G:Text("Конец интервала, серверное время")))
  G:AttachHelp(f.timeCheck,(G:Text("Время завершения ключей")),(G:Text("По серверным часам. Допускается интервал через полночь, например 23:00–02:00. Считаются завершения, без вычисления начала или онлайна.")))
  local classes=G.Dropdown.Create("GC735AnalyticsClasses",f);f.classes=classes;classes:SetSize(180,28);classes:SetPoint("TOPLEFT",24,-116);classes:SetText((G:Text("Классы")))
  G.Dropdown.Initialize(classes,function()
   G.Dropdown.AddButton({text=(G:Text("Все классы")),func=function()for k in pairs(s.classes)do s.classes[k]=nil end;Reset();Refresh()end})
   local names={};for _,m in ipairs(G.Roster.members or{})do if m.classFile then names[m.classFile]=m.class or m.classFile end end
   local keys={};for k in pairs(names)do keys[#keys+1]=k end;table.sort(keys)
   for _,k in ipairs(keys)do G.Dropdown.AddButton({text=names[k],checkmark=true,checked=s.classes[k],keepShownOnClick=true,func=function()s.classes[k]=not s.classes[k];Reset();Refresh()end})end
  end)
  G:AttachHelp(classes,(G:Text("Классы")),(G:Text("Выберите один или несколько классов. Если ни один не выбран, показаны все классы.")))
  local roles=G.Dropdown.Create("GC735AnalyticsRoles",f);f.roles=roles;roles:SetSize(180,28);roles:SetPoint("TOPLEFT",218,-116);roles:SetText((G:Text("Роли")))
  G.Dropdown.Initialize(roles,function()
   G.Dropdown.AddButton({text=(G:Text("Все роли")),checked=not A:SelectedRoles(s),func=function()for k in pairs(s.roles)do s.roles[k]=nil end;Reset();Refresh()end})
   for _,r in ipairs({{"TANK",(G:Text("Танк"))},{"HEALER",(G:Text("Хил"))},{"DAMAGER","DD"}})do
    local key,label=r[1],r[2]
    G.Dropdown.AddButton({text=label,checked=s.roles[key],checkmark=true,keepShownOnClick=true,func=function()s.roles[key]=not s.roles[key];Reset();Refresh()end})
   end
  end)
  G:AttachHelp(roles,(G:Text("Роли в прохождениях")),(G:Text("Выберите танка, хила, DD или сочетание ролей. Считаются ключи в выбранных ролях за указанные дни и часы. Без подходящих ключей персонаж скрывается. При неполных сведениях о роли подходящих прохождений персонаж не включается. Все роли снимает ограничение.")))
  local columns=G.Dropdown.Create("GC735AnalyticsColumns",f);f.columnPicker=columns;columns:SetSize(230,28);columns:SetPoint("TOPLEFT",412,-116);columns:SetText((G:Text("Столбцы Mythic+")))
  G.Dropdown.Initialize(columns,function()
   local all=true;for _,d in ipairs(definitions)do if not d[3]and not s.columns[d[1]]then all=false end end
   G.Dropdown.AddButton({text=(G:Text("Все столбцы")),checked=all,func=function()
    for _,d in ipairs(definitions)do if not d[3]then s.columns[d[1]]=true end end
    A:Layout();Refresh()
   end})

   for _,d in ipairs(definitions)do if not d[3]then G.Dropdown.AddButton({text=d[2],checkmark=true,checked=s.columns[d[1]],keepShownOnClick=true,func=function()s.columns[d[1]]=not s.columns[d[1]];A:Layout();Refresh()end})end end
  end)
  G:AttachHelp(columns,(G:Text("Столбцы Mythic+")),(G:Text("Имя, класс, уровень и звание видны всегда. Галочки добавляют показатели; колесо прокручивает список. Выбор столбцов не фильтрует персонажей. Счётчик учитывает переключаемые показатели; четыре постоянных столбца не входят в него.")))
  for _,owner in ipairs({roles,classes,columns})do
   for _,row in ipairs(owner.rows or{})do
    row:HookScript("OnEnter",function(o)
     local item=o.item;if not item then return end
     GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:SetText(item.text or"")
     GameTooltip:AddLine(owner==columns and(G:Text("Изменить отображение столбца. Фильтры остаются прежними."))or owner==classes and(G:Text("Отметить класс. Разные классы сочетаются по «или»."))or(G:Text("Отобрать прохождения по фактической роли. Танк + DD исключает прохождения хилом.")),1,1,1,true);GameTooltip:Show()
    end)
    row:HookScript("OnLeave",function()GameTooltip:Hide()end)
    row:HookScript("OnHide",function(o)if GameTooltip:IsOwned(o)then GameTooltip:Hide()end end)
   end
  end
  local refresh=CreateFrame("Button",nil,outer,"UIPanelButtonTemplate");f.refresh=refresh;refresh:SetSize(130,28);refresh:SetPoint("TOPRIGHT",-48,-12);refresh:SetText((G:Text("Обновить")))
  refresh:SetScript("OnClick",function()G.LadderRefresh:Refresh()end)
  refresh:SetScript("OnEnter",function(o)GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:SetText((G:Text("Обновить сохранённую статистику")));GameTooltip:AddLine(G.LadderRefresh:StatusText(),1,1,1,true);GameTooltip:Show()end)
  refresh:SetScript("OnLeave",function()GameTooltip:Hide()end);refresh:HookScript("OnHide",function(o)if GameTooltip:IsOwned(o)then GameTooltip:Hide()end end)
  function f:UpdateSelectionLabels()
   local count=0;for _,selected in pairs(s.classes)do if selected then count=count+1 end end
   self.classes:SetText((G:Text("Классы: "))..(count==0 and(G:Text("Все"))or tostring(count)))
   local selected,total=0,0
   for _,d in ipairs(definitions)do if not d[3]then total=total+1;if s.columns[d[1]]then selected=selected+1 end end end
   self.columnPicker:SetText((G:Text("Столбцы Mythic+ ("))..(selected==total and(G:Text("Все"))or selected.."/"..total)..")")
   local roles=0;for _,key in ipairs({"TANK","HEALER","DAMAGER"})do if s.roles[key]then roles=roles+1 end end
   self.roles:SetText((G:Text("Роли: "))..((roles==0 or roles==3)and(G:Text("Все"))or tostring(roles)))
  end
  f:UpdateSelectionLabels()
  f.status=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");G:ApplyFont(f.status,12)
  f.status:SetPoint("BOTTOMLEFT",22,23)

  G:CreateAnalyticsReset(f,"mythic",s,definitions,function()A:Layout();Refresh()end)
  local content=G:CreateRosterViewport(f,1000,1000,43,30,12)
  f.header=CreateFrame("Frame",nil,content);f.header:SetPoint("TOPLEFT",0,0);f.header:SetHeight(43)
  f.scroll=CreateFrame("ScrollFrame","GC735AnalyticsScroll",f,"FauxScrollFrameTemplate")
  f.scroll:SetScript("OnVerticalScroll",function(o,v)FauxScrollFrame_OnVerticalScroll(o,v,30,Refresh)end)
  f.measure=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");G:ApplyFont(f.measure,12);f.measure:Hide()
  f.driver=CreateFrame("Frame",nil,f)
  local function StopDrag()f.drag=nil;f.driver:SetScript("OnUpdate",nil)end
  f.StopDrag=StopDrag
  local grip=CreateFrame("Button",nil,host);f.grip=grip;grip:SetSize(24,24);grip:SetPoint("BOTTOMRIGHT",-4,4);grip:SetFrameLevel(host:GetFrameLevel()+30)
  local tex=grip:CreateTexture(nil,"ARTWORK");tex:SetAllPoints();tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  local function StopSizing()
   if not f.sizing then return end;f.sizing=nil;grip:SetScript("OnUpdate",nil);host:StopMovingOrSizing()
   s.window={width=host:GetWidth(),height=host:GetHeight()};page.width,page.height=host:GetWidth(),host:GetHeight();G:FitDockedPanels()
  end
  grip:SetScript("OnMouseDown",function(_,b)if b=="LeftButton"then StopDrag();f.sizing=true;host:StartSizing("BOTTOMRIGHT");grip:SetScript("OnUpdate",function()if not IsMouseButtonDown("LeftButton")then StopSizing()end end)end end)
  grip:SetScript("OnMouseUp",StopSizing);grip:HookScript("OnHide",StopSizing)
  G:AttachHelp(grip,(G:Text("Размер окна")),(G:Text("Потяните уголок для изменения размера окна аналитики. Размер сохраняется отдельно от Общих данных.")))
  host:HookScript("OnSizeChanged",function()if G.Shell.activePage=="analytics"then A:Layout();Refresh();G.PvPAnalytics:Layout();G.PvPAnalytics:Render();G.RaidAnalytics:Layout();G.RaidAnalytics:Render()end end)
  local display=CreateFrame("Frame");display:RegisterEvent("DISPLAY_SIZE_CHANGED");display:RegisterEvent("UI_SCALE_CHANGED")
  display:SetScript("OnEvent",function()
   if G.Shell.activePage~="analytics"then return end
   local a,b,c,d=G:GeneralBounds();host:SetMinResize(a,b);host:SetMaxResize(c,d)
   host:SetSize(math.max(a,math.min(c,host:GetWidth())),math.max(b,math.min(d,host:GetHeight())))
   A:Layout();Refresh();G.PvPAnalytics:Layout();G.PvPAnalytics:Render();G.RaidAnalytics:Layout();G.RaidAnalytics:Render();G:FitDockedPanels()
  end)
  f:HookScript("OnHide",function()StopDrag();StopSizing();grip:Hide();G.Dropdown.Close()end)
  f:SetScript("OnUpdate",function(_,elapsed)f.elapsed=(f.elapsed or 0)+elapsed;if f.elapsed>=1 then f.elapsed=0;Refresh()end end)
  for _,control in ipairs({f.horizontalSlider,f.horizontalLeft,f.horizontalRight})do G:AttachHelp(control,(G:Text("Прокрутка таблицы")),(G:Text("Прокрутить столбцы по горизонтали. Заголовки перемещаются вместе со строками.")))end
 end
 function page:SelectSection(id)
  if not self.tabs[id]then id="mythic"end
  A:State().section=id;G.Dropdown.Close()
  self.mythic:SetShown(id=="mythic");self.mythic.refresh:SetShown(id=="mythic")
  self.pvp:SetShown(id=="pvp");G.PvPAnalytics:Layout();G.PvPAnalytics:Render()
  self.raid:SetShown(id=="raid");G.RaidAnalytics:Layout();G.RaidAnalytics:Render()
  self.placeholder:Hide()
  self.placeholder:SetText("")
  for key,b in pairs(self.tabs)do b:SetButtonState(key==id and"PUSHED"or"NORMAL",key==id);b:GetFontString():SetTextColor(1,key==id and .82 or 1,key==id and 0 or 1)end
  self.mythic.grip:Show();A:Layout();if id=="mythic"then A:Render()end
 end
 function page:Show()self.frame:Show();self:SelectSection(A:State().section or"mythic")end
 function page:Hide()self.mythic:Hide();self.pvp:Hide();self.raid:Hide();self.frame:Hide();self.mythic.grip:Hide();self.mythic.refresh:Hide()end
 return page
end
function A:Layout()
 local f=self.frame;if not f or f.laying then return end;f.laying=true
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
   if key~="name"and key~="class"and key~="level"and key~="rank"and not s.columns[key]then h:Hide();h.grip:Hide()end
  end
 f.columns={};local total=0
 for _,d in ipairs(definitions)do if d[3]or s.columns[d[1]]then
  local key=d[1];local heading=d[4]or d[2];local textWidth=0
  for line in heading:gmatch("[^\n]+")do f.measure:SetText(line);textWidth=math.max(textWidth,f.measure:GetStringWidth())end
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
   h:SetScript("OnClick",function()if s.sort==key then s.descending=not s.descending else s.sort=key;s.descending=not d[3]end;A:Render()end)
   G:AttachHelp(h,d[2],(G:Text("Нажмите для сортировки. Повторное нажатие меняет порядок. Количество учитывает выбранные период и часы; рейтинги и места остаются показателями ладдера. Прочерк означает, что подтверждённые данные ещё не получены.")))
   local grip=CreateFrame("Button",nil,f.header);h.grip=grip;grip:SetSize(32,43);grip:SetPoint("CENTER",h,"RIGHT",0,0);grip:SetFrameLevel(h:GetFrameLevel()+5);grip:EnableMouse(true)
   local hover=grip:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(.3,.65,.9,.35)
   local edge=grip:CreateTexture(nil,"BACKGROUND");edge:SetSize(1,33);edge:SetPoint("CENTER",0,0);edge:SetColorTexture(.55,.65,.7,.55)
   grip:SetScript("OnMouseDown",function(_,b)
    if b~="LeftButton"or h.minimum==h.maximum then return end
    f.drag={x=GetCursorPosition(),width=h:GetWidth()}
    f.driver:SetScript("OnUpdate",function()
     if not IsMouseButtonDown("LeftButton")then f.StopDrag();return end
     s.widths[key]=math.max(h.minimum,math.min(h.maximum,math.floor(f.drag.width+(GetCursorPosition()-f.drag.x)/f:GetEffectiveScale()+.5)))
     A:Layout();A:Render()
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
  if not row then row=CreateFrame("Frame",nil,f.rosterContent);row.cells={};row.classIcon=row:CreateTexture(nil,"ARTWORK");row.classIcon:SetSize(22,22);f.rows[i]=row;row:SetHeight(30)end
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
function A:Render()
 local f=self.frame;if not f or not f:IsShown()or not f.visibleRows then return end
 f:UpdateSelectionLabels()
 local rows=self:Rows();f.status:SetText(string.format(G.L.MEMBERS_SHOWN,#rows,#(G.Roster.members or{})))
 local offset=FauxScrollFrame_GetOffset(f.scroll)
 offset=math.max(0,math.min(offset,math.max(0,#rows-f.visibleRows)));f.scroll.offset=offset
 FauxScrollFrame_Update(f.scroll,#rows,f.visibleRows,30)
 for i=1,f.visibleRows do
  local row=f.rows[i];local data=rows[i+offset];row:SetShown(data~=nil)
  if data then
   for _,c in ipairs(f.columns)do
    local value=data[c.key];if c.key=="name"then value=data.member.online and G:ClassName(data.member)or data.name end
    local muted=c.key~="name"and c.key~="class"and c.key~="level"and c.key~="rank"and(value==nil or value==0)
    local color=(not data.member.online or muted)and .55 or 1;row.cells[c.key]:SetTextColor(color,color,color)
    row.cells[c.key]:SetText(value==nil and"—"or tostring(value))
   end
   local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[data.member.classFile];row.classIcon:SetShown(coords~=nil)
   if coords then row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");row.classIcon:SetTexCoord(unpack(coords));row.cells.class:SetText("")else row.cells.class:SetText("?")end
  end
 end
end
