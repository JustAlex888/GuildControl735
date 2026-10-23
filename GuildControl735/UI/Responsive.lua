-- Original General-page geometry. No collection, permissions, or transport.
local _,G=...
local MIN_W,MIN_H,TOP,HEADER,ROW=1120,490,196,43,30
local function number(x)return type(x)=="number"and x==x and x~=math.huge and x~=-math.huge end
function G:GeneralBounds()
 local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
 self.GeneralScale=self.GeneralScale or math.min(1,sw/1922,sh/824)
 local ratio=1/self.GeneralScale
 -- Shell scale is relative to UIParent; reserve top tabs and fixed side tabs.
 local right=self.StatsPanel and self.StatsPanel:IsShown()and self.StatsPanel:GetWidth()or 0
 local left=self.GuildPage and self.GuildPage:IsShown()and 334 or 34
 local maxW=math.max(MIN_W,math.floor(sw*ratio-left-right-12))
 local maxH=math.max(MIN_H,math.min(4180,math.floor(sh*ratio-48)))
 return MIN_W,MIN_H,maxW,maxH
end
function G:GeneralDimensions()
 local a,b,c,d=self:GeneralBounds();local saved=self.db.ui and self.db.ui.generalWindow or{}
 local w=number(saved.width)and saved.width or 1350
 local h=number(saved.height)and saved.height or 760
 return math.max(a,math.min(c,w)),math.max(b,math.min(d,h))
end
function G:PreparePageGeometry(id,page)
 local host=self.ShellWindow;host:SetResizable(id=="general"or id=="analytics"or id=="security")
 if id=="security"then
  local a,b,c,d=self:GeneralBounds();host:SetMinResize(a,b);host:SetMaxResize(c,d)
  local s=self.db.ui.security or{};local saved=s.window or{}
  page.width=math.max(a,math.min(c,tonumber(saved.width)or a));page.height=math.max(b,math.min(d,tonumber(saved.height)or b));return
 end
 if id=="analytics"then
  local a,b,c,d=self:GeneralBounds();host:SetMinResize(a,b);host:SetMaxResize(c,d)
  local s=self.MythicAnalytics:State();local saved=s.window or{}
  page.width=math.max(a,math.min(c,tonumber(saved.width)or 1350))
  page.height=math.max(b,math.min(d,tonumber(saved.height)or 760))
  return
 end
 if id=="general"then
  local a,b,c,d=self:GeneralBounds();host:SetMinResize(a,b);host:SetMaxResize(c,d)
  host:SetScale(self.GeneralScale);page.width,page.height=self:GeneralDimensions()
 else
  -- General's native resize limits must never constrain the fixed other pages.
  host:SetMinResize(1,1);host:SetMaxResize(10000,10000)
 end
end
function G:SaveGeneralSize()
 if self.Shell.activePage~="general"then return end
 self.db.ui=self.db.ui or{};self.db.ui.generalWindow={width=self.ShellWindow:GetWidth(),height=self.ShellWindow:GetHeight()}
 local page=self.Shell.pages.general;if page then page.width,page.height=self.ShellWindow:GetWidth(),self.ShellWindow:GetHeight()end
end
function G:ConstrainGeneralToScreen()
 if self.constrainingGeneral or not self.MainWindow then return end
 local host=self.ShellWindow;local a,b,c,d=self:GeneralBounds()
 host:SetMinResize(a,b);host:SetMaxResize(c,d)
 local w,h=math.max(a,math.min(c,host:GetWidth())),math.max(b,math.min(d,host:GetHeight()))
 if w~=host:GetWidth()or h~=host:GetHeight()then
  self.constrainingGeneral=true;host:SetSize(w,h);self.constrainingGeneral=nil
 end
end
function G:LayoutGeneral(width,height)
 local frame=self.MainWindow;if not frame or self.layingGeneral then return end
 self.layingGeneral=true
 frame:SetSize(width,height)
 local visible=math.max(5,math.min(128,math.floor((height-340)/ROW)))
 frame.visibleRows=visible;frame:EnsureRows(visible)
 local viewport=width-300
 frame.rosterViewport:SetSize(viewport,HEADER+visible*ROW)
 frame.rosterContent:SetHeight(HEADER+visible*ROW)
 frame.horizontalRail:SetWidth(viewport);frame.horizontalSlider:SetWidth(viewport-48)
 frame.scroll:ClearAllPoints();frame.scroll:SetPoint("TOPLEFT",frame.rosterViewport,"TOPLEFT",0,-HEADER)
 frame.scroll:SetSize(viewport-2,visible*ROW)
 local rail=frame.scroll.modernRail
 if rail then rail:SetHeight(visible*ROW)end
 frame:ApplyColumnWidths()
 local card=self.MemberCard
 if card then
  card:ClearAllPoints();card:SetPoint("TOPLEFT",frame,"TOPLEFT",width-260,-TOP)
  card:SetSize(230,height-TOP-8)
  self:LayoutMemberCard()
 end
 if self.StatsPanel and self.StatsPanel:IsShown()then
  local member=self.Roster:FindByKey(card and card.memberKey)
  if member then self:UpdateStats(member)end
 end
 self.layingGeneral=nil
 if frame:IsShown()then self:UpdateMainWindow(true)end
end
function G:InitializeGeneralSizing(frame)
 local host=self.ShellWindow
 local grip=CreateFrame("Button",nil,host);self.GeneralGrip=grip
 grip:SetSize(24,24);grip:SetPoint("BOTTOMRIGHT",-4,4);grip:SetFrameLevel(host:GetFrameLevel()+30)
 local texture=grip:CreateTexture(nil,"ARTWORK");texture:SetAllPoints();texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
 grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
 self:AttachHelp(grip,(G:Text("Размер окна")),(G:Text("Потяните уголок для изменения размера Общих данных. Минимум — пять строк состава. Шрифты и ширина столбцов сохраняются.")))
 local function stop()
  if not G.generalSizing then return end
  G.generalSizing=nil;grip:SetScript("OnUpdate",nil);host:StopMovingOrSizing();G:SaveGeneralSize();G:FitDockedPanels()
 end
 grip:SetScript("OnMouseDown",function(_,button)
  if button~="LeftButton"or G.Shell.activePage~="general"then return end
  if frame.StopColumnDrag then frame.StopColumnDrag()end
  G:ConstrainGeneralToScreen();G.generalSizing=true;host:StartSizing("BOTTOMRIGHT")
  grip:SetScript("OnUpdate",function()if not IsMouseButtonDown("LeftButton")then stop()end end)
 end)
 grip:SetScript("OnMouseUp",stop);grip:HookScript("OnHide",stop)
 -- Native sizing owns dimensions; this driver only handles release outside grip.
 G.StopGeneralSizing=stop
 host:HookScript("OnSizeChanged",function(_,w,h)
  if G.Shell.activePage=="general"then G:LayoutGeneral(w,h)end
 end)
 frame:HookScript("OnHide",function()stop();G:SaveGeneralSize()end)
 local event=CreateFrame("Frame");event:RegisterEvent("DISPLAY_SIZE_CHANGED");event:RegisterEvent("UI_SCALE_CHANGED")
 event:SetScript("OnEvent",function()
  G.GeneralScale=nil
  if G.Shell.activePage=="general"then G:FitDockedPanels();G:LayoutGeneral(host:GetWidth(),host:GetHeight())end
 end)
end
