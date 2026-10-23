-- Independently authored UI. Explicit confirmation calls leader policy only.
local _,G=...
local defs=G:RegisterLocaleTable({},function()return {{'name',(G:Text('Имя')),true,160,120,400},{'class',(G:Text('Класс')),true,54,54,54},{'level',(G:Text('Ур.')),true,40,40,40},{'rank',(G:Text('Звание')),true,100,85,220},{'state',(G:Text('Состояние\nобмена')),false,145,110,240},{'reason',(G:Text('Причина')),false,120,90,320},{'count',(G:Text('За 24 ч.')),false,76,76,76},{'ten',(G:Text('За 10 дней')),false,90,90,90},{'ban',(G:Text('Ручной\nбан')),false,82,82,82},{'remaining',(G:Text('Осталось')),false,92,92,92},{'total',(G:Text('Всего\nбанов')),false,74,74,74}} end)
local function label(f,x,y,w,size)local t=f:CreateFontString(nil,'ARTWORK','GameFontHighlight');t:SetPoint('TOPLEFT',x,-y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetWordWrap(false);G:ApplyFont(t,size or 11);return t end
local function state()G.db.ui.security=G.db.ui.security or{};local s=G.db.ui.security;for _,k in ipairs({'widths','columns','classes','ranks'})do s[k]=s[k]or{}end;return s end
local function fold(x)return G.AnalyticsSearch:Fold(tostring(x or''))end
local function remaining(at)local n=math.max(0,(at or 0)-time());if n==0 then return'—'elseif n>=86400 then return math.floor(n/86400)..(G:Text(' д. '))..math.floor(n%86400/3600)..(G:Text(' ч.'))elseif n>=3600 then return math.floor(n/3600)..(G:Text(' ч. '))..math.floor(n%3600/60)..(G:Text(' мин.'))end;return math.max(1,math.ceil(n/60))..(G:Text(' мин.'))end
function G:RefreshNetworkBadge()local f=self.FloatingButton;local unread=self.SpamShield:Unread();if f and f.securityGlow then f.securityGlow:SetShown(unread);f.securityBang:SetShown(unread)end end
function G:OpenNetworkSecurity()if self.Shell and self.Shell.pages.security then self.Shell:Open('security')end end
function G:CreateNetworkSecurityPage()
 local p={width=1120,height=490,offset=0,selected={},definitions=defs}
 function p:StopDrag()self.drag=nil;if self.driver then self.driver:SetScript('OnUpdate',nil)end end
 function p:StopSize()if not self.sizing then return end;self.sizing=nil;self.grip:SetScript('OnUpdate',nil);self.host:StopMovingOrSizing();state().window={width=self.host:GetWidth(),height=self.host:GetHeight()};self.width=self.host:GetWidth();self.height=self.host:GetHeight()end
 function p:Confirm(days)
  if not G.AdminTrust:IsLeader()then return end;local ids={};for guid in pairs(self.selected)do ids[#ids+1]=guid end;table.sort(ids);if #ids==0 then return end
  local f=self.confirmation;if not f then
   f=CreateFrame('Frame','GC735ManualBanConfirmation',UIParent);self.confirmation=f;f:SetSize(280,250);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(150);f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag('LeftButton');f:SetScript('OnDragStart',function()f:StartMoving()end);f:SetScript('OnDragStop',function()f:StopMovingOrSizing()end);f:SetScript('OnHide',function()f:StopMovingOrSizing()end)
   f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
   f.title=label(f,16,18,248,12);f.title:SetHeight(64);f.title:SetWordWrap(true)
   local scroll=CreateFrame('ScrollFrame','GC735ManualBanConfirmScroll',f,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',16,-90);scroll:SetSize(220,96)
   f.body=CreateFrame('Frame',nil,scroll);f.body:SetWidth(214);scroll:SetScrollChild(f.body);f.list=label(f.body,0,0,210,11);f.list:SetWordWrap(true)
   local yes=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');f.yes=yes;yes:SetPoint('BOTTOMLEFT',16,16);yes:SetSize(120,26);yes:SetText((G:Text('Подтвердить')))
   local no=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');no:SetPoint('BOTTOMRIGHT',-16,16);no:SetSize(120,26);no:SetText((G:Text('Отмена')));no:SetScript('OnClick',function()f:Hide()end)
   yes:SetScript('OnClick',function()G.AdminTrust:Refresh();local ok,why=G.ManualBans:SetMany(f.ids,f.days);if ok then p.selected={};f:Hide();p:Refresh()else f.title:SetText((G:Text('Не применено: '))..tostring(why)..(G:Text('. Проверьте выбор и полномочия.')))end end)
  end
  f.ids=ids;f.days=days;f.title:SetText(days==0 and(G:Text('Снять ручной бан с выбранных персонажей?'))or((G:Text('Ручной бан на '))..days..(G:Text(' д. Ограничивается только обмен аддона, не права гильдии.'))))
  local names={};for i,guid in ipairs(ids)do local m=G.Roster:FindByKey(guid);names[#names+1]=i..'. '..(m and m.name or guid)end;f.list:SetText(table.concat(names,'\n'));local textHeight=math.max(96,f.list:GetStringHeight()+8);f.list:SetHeight(textHeight);f.body:SetHeight(textHeight);f:Show()
 end
 function p:Init(host)
  self.host=host;local f=CreateFrame('Frame',nil,host);self.frame=f;G.NetworkSecurity=self;f:SetAllPoints(host)
  label(f,24,18,900,18):SetText((G:Text('Сетевая защита')));self.hint=label(f,24,47,1000,10);self.hint:SetText((G:Text('Автоматические ограничения снимаются сами. Общий ручной бан назначает и снимает только глава гильдии.')));self.policy=label(f,24,67,1000,10)
  self.search=CreateFrame('EditBox',nil,f,'InputBoxTemplate');self.search:SetPoint('TOPLEFT',26,-91);self.search:SetSize(390,25);self.search:SetAutoFocus(false);self.search:SetMaxLetters(128);self.search:SetText(state().search or'')
  self.search:SetScript('OnTextChanged',function(o)state().search=o:GetText();p.offset=0;p:Refresh()end);self.search:SetScript('OnEscapePressed',function(o)o:SetText('');o:ClearFocus()end);self.search:SetScript('OnEnterPressed',function(o)o:ClearFocus()end)
  G:AttachHelp(self.search,(G:Text('Поиск по данным участников')),(G:Text('Имя, класс, звание, зона и доступные данные участника. Поиск не отправляет запросов.')))
  local function picker(x,w,title,builder)local b=G.Dropdown.Create('GC735SecurityPicker'..x,f);b:SetPoint('TOPLEFT',x,-128);b:SetSize(w,28);b:SetText(title);G.Dropdown.Initialize(b,builder);return b end
  self.classes=picker(24,180,(G:Text('Классы: Все')),function()
   G.Dropdown.AddButton({text=(G:Text('Все классы')),func=function()state().classes={};p.offset=0;p:Refresh()end});local seen,rows={},{}
   for _,m in ipairs(G.Roster.members or{})do local key=m.classFile or m.classFileName;if key and not seen[key]then seen[key]=true;rows[#rows+1]={key,m.class or key}end end;table.sort(rows,function(a,b)return a[2]<b[2]end)
   for _,v in ipairs(rows)do local key=v[1];G.Dropdown.AddButton({text=v[2],checked=state().classes[key],checkmark=true,keepShownOnClick=true,func=function()state().classes[key]=not state().classes[key];p.offset=0;p:Refresh()end})end
  end)
  self.ranks=picker(216,180,(G:Text('Звания: Все')),function()
   G.Dropdown.AddButton({text=(G:Text('Все звания')),func=function()state().ranks={};p.offset=0;p:Refresh()end});local seen,rows={},{};for _,m in ipairs(G.Roster.members or{})do if m.rank and not seen[m.rank]then seen[m.rank]=true;rows[#rows+1]=m.rank end end;table.sort(rows)
   for _,name in ipairs(rows)do local key=name;G.Dropdown.AddButton({text=key,checked=state().ranks[key],checkmark=true,keepShownOnClick=true,func=function()state().ranks[key]=not state().ranks[key];p.offset=0;p:Refresh()end})end
  end)
  self.columnPicker=picker(408,180,(G:Text('Столбцы')),function()for _,d in ipairs(defs)do local key=d[1];G.Dropdown.AddButton({text=d[2]:gsub('\n',' '),checked=d[3]or state().columns[key]~=false,disabled=d[3],checkmark=true,keepShownOnClick=true,func=function()state().columns[key]=state().columns[key]==false;p:Layout();p:Refresh()end})end end)
  self.all=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate');self.all:SetPoint('TOPLEFT',604,-128);label(f,637,135,300,10):SetText((G:Text('Показать всех участников')));self.all:SetScript('OnClick',function(o)G.db.ui.securityShowAll=o:GetChecked()and true or false;p.offset=0;p:Refresh()end)
  self.report=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');self.report:SetSize(210,25);self.report:SetPoint('TOPRIGHT',-24,-91);self.report:SetText((G:Text('Технический отчёт')));self.report:SetScript('OnClick',function()G.SpamShield:Show()end)
  self.viewport=CreateFrame('ScrollFrame','GC735SecurityTableViewport',f);self.viewport:SetPoint('TOPLEFT',24,-170);self.content=CreateFrame('Frame',nil,self.viewport);self.viewport:SetScrollChild(self.content);self.headers={};self.rows={};self.driver=CreateFrame('Frame',nil,f);self.measure=label(f,0,0,1000,12);self.measure:Hide()
  for _,d in ipairs(defs)do local key=d[1];local h=CreateFrame('Button',nil,self.content);self.headers[key]=h;h:SetHeight(40);local bg=h:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.12,.20,.28,.95);h.text=label(h,5,2,d[4]-10,11);h.text:SetHeight(36);h.text:SetWordWrap(true);h.text:SetText('|cffffd100'..d[2]..'|r')
   h:SetScript('OnClick',function()local s=state();if s.sort==key then s.descending=not s.descending else s.sort=key;s.descending=not d[3]end;p.offset=0;p:Refresh()end)
   h.grip=CreateFrame('Button',nil,h);h.grip:SetPoint('CENTER',h,'RIGHT');h.grip:SetSize(20,40);h.grip:SetFrameLevel(h:GetFrameLevel()+3);local hover=h.grip:CreateTexture(nil,'HIGHLIGHT');hover:SetAllPoints();hover:SetColorTexture(.3,.65,.9,.35);h.grip.hover=hover;local edge=h.grip:CreateTexture(nil,'BACKGROUND');edge:SetSize(1,32);edge:SetPoint('CENTER');edge:SetColorTexture(.6,.65,.7,.7)
   h.grip:SetScript('OnMouseDown',function(_,mouse)if mouse~='LeftButton'or h.minimum==h.maximum then return end;p.drag={key=key,x=GetCursorPosition(),width=h:GetWidth()};p.driver:SetScript('OnUpdate',function()if not IsMouseButtonDown('LeftButton')then p:StopDrag();return end;state().widths[key]=math.max(h.minimum,math.min(h.maximum,p.drag.width+(GetCursorPosition()-p.drag.x)/f:GetEffectiveScale()));p:Layout();p:Refresh()end)end);h.grip:SetScript('OnMouseUp',function()p:StopDrag()end)
  end
  local function slider(name,orient)local b=CreateFrame('Slider',name,f);b:SetOrientation(orient);b:SetValueStep(1);b:SetThumbTexture('Interface\\Buttons\\UI-ScrollBar-Knob');b:GetThumbTexture():SetSize(16,24);b:SetMinMaxValues(0,0);b:SetValue(0);return b end
  self.slider=slider('GC735SecurityScrollBar','VERTICAL');self.slider:SetPoint('TOPRIGHT',-24,-212);self.slider:SetWidth(16);self.slider:SetScript('OnValueChanged',function(_,v)p.offset=math.floor(v+.5);if not p.refreshing then p:Refresh()end end)
  self.horizontal=slider('GC735SecurityHorizontal','HORIZONTAL');self.horizontal:SetHeight(16);self.horizontal:SetScript('OnValueChanged',function(_,v)state().horizontal=v;p.viewport:SetHorizontalScroll(v)end)
  f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',function(_,d)p.slider:SetValue(math.max(0,math.min(p.maxOffset or 0,p.offset-d*3)))end)
  self.details=label(f,24,380,1050,10);self.details:SetHeight(50);self.details:SetWordWrap(true);self.empty=label(f,30,220,1000,11)
  self.mode=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate');self.mode:SetPoint('BOTTOMLEFT',20,70);label(self.mode,32,7,300,11):SetText((G:Text('Действия с нарушителями')));self.mode:SetScript('OnClick',function(o)p.actionMode=o:GetChecked()and G.AdminTrust:IsLeader()or false;p.selected={};p:Layout();p:Refresh()end)
  local function button(x,w,title,fn)local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetPoint('BOTTOMLEFT',x,16);b:SetSize(w,27);b:SetText(title);b:SetScript('OnClick',fn);return b end
  self.selectAll=button(24,200,(G:Text('Выбрать показанных')),function()for _,row in ipairs(p.rows)do local d=row.data;if row:IsShown()and d and d.member.guid~=G.AdminTrust.leader then p.selected[d.member.guid]=true end end;p:Refresh()end);self.clear=button(236,160,(G:Text('Снять выбор')),function()p.selected={};p:Refresh()end)
  self.actions=G.Dropdown.Create('GC735SecurityActions',f);self.actions:SetPoint('BOTTOMLEFT',408,16);self.actions:SetSize(300,27);self.actions:SetText((G:Text('Действия с нарушителями…')));G.Dropdown.Initialize(self.actions,function()for _,n in ipairs({1,3,6})do local days=n;G.Dropdown.AddButton({text=(G:Text('Ручной бан на '))..days..(G:Text(' д.')),func=function()p:Confirm(days)end})end;G.Dropdown.AddButton({text=(G:Text('Снять ручной бан')),func=function()p:Confirm(0)end})end)
  self.selectedText=label(f,420,0,250,11);self.grip=CreateFrame('Button',nil,host);self.grip:SetPoint('BOTTOMRIGHT',-3,3);self.grip:SetSize(22,22);self.grip:SetFrameLevel(host:GetFrameLevel()+30);local tex=self.grip:CreateTexture(nil,'ARTWORK');tex:SetAllPoints();tex:SetTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
  self.grip:SetScript('OnMouseDown',function(_,mouse)if mouse=='LeftButton'then p:StopDrag();p.sizing=true;host:StartSizing('BOTTOMRIGHT');p.grip:SetScript('OnUpdate',function()if not IsMouseButtonDown('LeftButton')then p:StopSize()end end)end end);self.grip:SetScript('OnMouseUp',function()p:StopSize()end);self.grip:Hide()
  f:HookScript('OnSizeChanged',function()if f:IsShown()then p:Layout();p:Refresh()end end);f:SetScript('OnUpdate',function(_,dt)p.elapsed=(p.elapsed or 0)+dt;if p.elapsed>=1 then p.elapsed=0;p:Refresh()end end)
 end
 function p:Layout()
  local w,h=self.host:GetWidth(),self.host:GetHeight();self.visible=math.max(1,math.min(128,math.floor((h-385)/30)));local vw,vh=w-66,40+self.visible*30
  self.viewport:SetSize(vw,vh);self.slider:SetHeight(self.visible*30);self.horizontal:ClearAllPoints();self.horizontal:SetPoint('TOPLEFT',24,-(174+vh));self.horizontal:SetWidth(vw);self.details:ClearAllPoints();self.details:SetPoint('TOPLEFT',24,-(199+vh));self.details:SetWidth(vw);self.details:SetHeight(math.max(28,h-(199+vh)-110));self.hint:SetWidth(w-48);self.policy:SetWidth(w-48);self.empty:SetWidth(vw-16);self.selectedText:ClearAllPoints();self.selectedText:SetPoint('BOTTOMLEFT',236,50)
  local total=self.actionMode and 28 or 0;self.columns={}
  for _,d in ipairs(defs)do local head=self.headers[d[1]];local show=d[3]or state().columns[d[1]]~=false;head:SetShown(show);if show then local lo,hi=d[5],d[6]
   if d[1]=='reason'then self.measure:SetText('0000000000');lo=math.ceil(self.measure:GetStringWidth()+12);self.measure:SetText(G.SpamShield:Reason('unknown'));hi=math.max(lo,math.ceil(self.measure:GetStringWidth()+12))end
   local cw=math.max(lo,math.min(hi,tonumber(state().widths[d[1]])or d[4]));head.minimum,head.maximum=lo,hi;head:ClearAllPoints();head:SetPoint('TOPLEFT',total,0);head:SetWidth(cw);head.text:SetWidth(cw-10);head.grip:SetShown(lo~=hi);head.grip:EnableMouse(lo~=hi);self.columns[#self.columns+1]={key=d[1],x=total,width=cw};total=total+cw
  end end
  self.content:SetSize(total,vh);local maximum=math.max(0,total-vw);self.horizontal:SetMinMaxValues(0,maximum);self.horizontal:SetShown(maximum>0);self.horizontal:SetValue(math.max(0,math.min(maximum,state().horizontal or 0)))
  for i=1,self.visible do if not self.rows[i]then local row=CreateFrame('Button',nil,self.content);self.rows[i]=row;row.cells={};row:SetHeight(30);local bg=row:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.08,.15,.19,i%2==0 and .7 or .3)
   row.check=CreateFrame('CheckButton',nil,row,'UICheckButtonTemplate');row.check:SetSize(26,26);row.check:SetPoint('TOPLEFT',0,-2);row.check:SetScript('OnClick',function(o)local d=row.data;if d and G.AdminTrust:IsLeader()and p.actionMode then p.selected[d.member.guid]=o:GetChecked()and true or nil;p:Refresh()end end);row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(22,22)
   row:SetScript('OnClick',function()p.focus=row.data and row.data.member.guid;p:Details(row.data)end);row:SetScript('OnEnter',function()local d=row.data;if not d then return end;GameTooltip:SetOwner(row,'ANCHOR_RIGHT');GameTooltip:SetText(d.member.name);GameTooltip:AddLine(d.member.class or'',1,1,1);local at=d.manual and d.manual.untilAt>time()and d.manual.untilAt or d.record and d.record.blockUntil;if at and at>time()then GameTooltip:AddLine((G:Text('Восстановление: '))..date('%d.%m %H:%M:%S',at),1,1,1,true)end;GameTooltip:Show()end);row:SetScript('OnLeave',function()GameTooltip:Hide()end)
  end end
  for i,row in ipairs(self.rows)do row:SetShown(i<=self.visible);row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-40-(i-1)*30);row:SetWidth(total);for _,t in pairs(row.cells)do t:Hide()end;for _,c in ipairs(self.columns)do local t=row.cells[c.key];if not t then t=label(row,0,0,20,11);row.cells[c.key]=t end;t:ClearAllPoints();t:SetPoint('TOPLEFT',c.x+5,-5);t:SetWidth(c.width-10);t:SetHeight(23);t:Show()end end
 end
 function p:Value(d,key)
  local m,r,b=d.member,d.record,d.manual;local banned=b and b.untilAt>time()
  if key=='count'then return d.count elseif key=='ten'then return d.ten or 0 elseif key=='ban'then return banned and 1 or 0 elseif key=='remaining'then return banned and b.untilAt-time()or 0 elseif key=='total'then return b and b.total or 0 elseif key=='level'then return tonumber(m.level)or 0 elseif key=='rank'then return tonumber(m.rankIndex)or 99 elseif key=='class'then return m.class or''elseif key=='reason'then return banned and(G:Text('Ручной бан главы'))or r and G.SpamShield:Reason(r.lastReason)or''elseif key=='state'then return d.blocked and 1 or 0 end;return fold(m.name)
 end
 function p:Details(d)
  if not d then self.details:SetText((G:Text('Нажмите на персонажа для подробностей. Срабатывания — отдельные случаи ограничения, а не количество пакетов.')));return end
  local m,r,b=d.member,d.record,d.manual;local lines={m.name..' — '..d.state};if b and b.untilAt>time()then lines[#lines+1]=(G:Text('Ручной бан главы до '))..date('%d.%m %H:%M:%S',b.untilAt)..(G:Text('. Всего банов: '))..b.total..'.'end;if r and r.lastIncidentAt then lines[#lines+1]=(G:Text('Последнее автосрабатывание: '))..date('%d.%m %H:%M:%S',r.lastIncidentAt)..'. '..G.SpamShield:Reason(r.lastReason)..'.'end;if r and(r.blockUntil or 0)>time()then lines[#lines+1]=(G:Text('Автоматическое восстановление в '))..date('%H:%M:%S',r.blockUntil)..'.'end;lines[#lines+1]=(G:Text('За 24 ч.: '))..d.count..(G:Text('; за 10 дней: '))..(d.ten or 0)..(G:Text('. Наблюдения этого компьютера.'));self.details:SetText(table.concat(lines,'\n'))
 end
 function p:Refresh()
  if self.refreshing then return end;self.refreshing=true;local scope=(G:GetGuildKey()or'')..(G.AdminTrust.leader or'');local leader=G.AdminTrust:IsLeader()
  if self.scope~=scope or not leader then local relayout=self.actionMode;self.selected={};self.actionMode=false;self.scope=scope;if self.confirmation then self.confirmation:Hide()end;if relayout then self:Layout()end end
  self.mode:SetEnabled(leader);self.mode:SetChecked(self.actionMode==true);self.all:SetChecked(G.db.ui.securityShowAll==true);self.selectAll:SetShown(self.actionMode==true);self.clear:SetShown(self.actionMode==true);self.actions:SetShown(self.actionMode==true)
  local root=G.ManualBans:Root();self.policy:SetText(root and root.confirmed and(G:Text('Список ручных банов подтверждён главой. Сохранённые правила действуют и без него онлайн.'))or(G:Text('Список ручных банов ещё не подтверждён главой. Локальная автоматическая защита работает.')))
  local s=state();local data={};local query=fold(s.search);local function any(t)for _,v in pairs(t)do if v then return true end end;return false end
  for _,d in ipairs(G.SpamShield:Rows(G.db.ui.securityShowAll==true))do local m=d.member;local match=query==''or fold(table.concat({m.name or'',m.class or'',m.rank or'',m.zone or'',m.note or'',m.officerNote or''},' ')):find(query,1,true)or G.MatchesPresentationSearch and G:MatchesPresentationSearch(m,query);if match and(not any(s.classes)or s.classes[m.classFile or m.classFileName])and(not any(s.ranks)or s.ranks[m.rank])then data[#data+1]=d end end
  table.sort(data,function(a,b)if not s.sort then if a.blocked~=b.blocked then return a.blocked end;if a.count~=b.count then return a.count>b.count end;return a.member.name<b.member.name end;local x,y=self:Value(a,s.sort),self:Value(b,s.sort);if x==y then return a.member.name<b.member.name end;if s.descending then return x>y end;return x<y end)
  self.data=data;self.maxOffset=math.max(0,#data-(self.visible or 1));self.offset=math.max(0,math.min(self.offset,self.maxOffset));self.slider:SetMinMaxValues(0,self.maxOffset);self.slider:SetValue(self.offset);self.slider:SetShown(self.maxOffset>0);self.empty:SetText(#data==0 and(G:Text('Нет участников, подходящих под выбранное отображение.'))or'')
  local n=0;for _ in pairs(self.selected)do n=n+1 end;self.selectedText:SetText(self.actionMode and((G:Text('Выбрано: '))..n)or'');self.actions:SetEnabled(n>0 and leader)
  local nc,nr=0,0;for _,v in pairs(s.classes)do if v then nc=nc+1 end end;for _,v in pairs(s.ranks)do if v then nr=nr+1 end end;self.classes:SetText((G:Text('Классы: '))..(nc>0 and nc or(G:Text('Все'))));self.ranks:SetText((G:Text('Звания: '))..(nr>0 and nr or(G:Text('Все'))))
  for i,row in ipairs(self.rows)do local d=data[self.offset+i];row.data=d;row:SetShown(i<=(self.visible or 0)and d~=nil);row.icon:Hide();row.check:SetShown(self.actionMode==true and d~=nil)
   if d then local m,r,b=d.member,d.record,d.manual;local banned=b and b.untilAt>time();row.check:SetChecked(self.selected[m.guid]==true);row.check:SetEnabled(leader and m.guid~=G.AdminTrust.leader);local class=m.classFile or m.classFileName;local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or'']
    for _,c in ipairs(self.columns)do local key,value=c.key
     if key=='name'then value=color and string.format('|cff%02x%02x%02x%s|r',color.r*255,color.g*255,color.b*255,m.name)or m.name
     elseif key=='class'then value=m.class or'—';local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class or''];if coords then row.icon:SetTexture('Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES');row.icon:SetTexCoord(unpack(coords));row.icon:ClearAllPoints();row.icon:SetPoint('TOPLEFT',c.x+8,-4);row.icon:Show();value=''end
     elseif key=='level'then value=m.level or'—'elseif key=='rank'then value=m.rank or'—'elseif key=='state'then value=(d.blocked and'|cffff6666'or(d.ten or 0)>0 and'|cffffd100'or'|cffffffff')..d.state..'|r'
     elseif key=='reason'then value=banned and(G:Text('Ручной бан главы'))or r and((d.ten or 0)>0 or d.blocked)and G.SpamShield:Reason(r.lastReason)or'—'elseif key=='ban'then value=banned and(G:Text('Да'))or(G:Text('Нет'))elseif key=='remaining'then value=remaining(b and b.untilAt)else value=tostring(self:Value(d,key))end;row.cells[key]:SetText(value)
    end
   end
  end
  local focus;for _,d in ipairs(data)do if d.member.guid==self.focus then focus=d;break end end;self:Details(focus);self.refreshing=nil;if self.frame:IsShown()then G.SpamShield:Read()end
 end
 function p:Show()self.frame:Show();self.grip:Show();self:Layout();self:Refresh()end
 function p:Hide()self:StopDrag();self:StopSize();self.grip:Hide();self.frame:Hide();self.selected={};self.actionMode=false;if self.confirmation then self.confirmation:Hide()end;G.Dropdown.Close()end
 return p
end
