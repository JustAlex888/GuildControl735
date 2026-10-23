-- Independent launcher: own frames only; no Blizzard widget hooks or wire calls.
local _,G=...
local MIN,MAX,PAD=24,160,16
local function finite(n)return type(n)=="number"and n==n and n~=math.huge and n~=-math.huge end
local function Settings()
 if not G.db then return end
 local s=G.db.floatingButton
 if type(s)~="table"then s={};G.db.floatingButton=s end
 s.size=finite(s.size)and math.max(MIN,math.min(MAX,s.size))or 44
 s.hidden=s.hidden==true
 return s
end
function G:InitializeFloatingButton()
 if self.FloatingButton or not Settings()then return end
 local f=CreateFrame("Frame","GuildControl735FloatingButton",UIParent);self.FloatingButton=f
 f:SetFrameStrata("HIGH");f:SetClampedToScreen(true);f:EnableMouse(true)
 local b=CreateFrame("Button",nil,f);f.button=b
 b:SetPoint("TOPLEFT",8,-8);b:EnableMouse(true);b:RegisterForClicks("LeftButtonUp","RightButtonUp")
 -- The high-resolution texture includes its own outside clipped-corner frame.
 -- No Blizzard Quickslot overlay: its inner frame crossed the old shield.
 local icon=b:CreateTexture(nil,"ARTWORK");b.icon=icon;icon:SetAllPoints();icon:SetTexture("Interface\\AddOns\\GuildControl735\\Textures\\GuildShieldG_Floating512.tga")
 local hover=b:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(1,.9,.5,.12)
 local glow=b:CreateTexture(nil,"OVERLAY");f.securityGlow=glow;glow:SetPoint("TOPLEFT",-7,7);glow:SetPoint("BOTTOMRIGHT",7,-7);glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");glow:SetBlendMode("ADD");glow:SetVertexColor(.15,.75,1,.85);glow:Hide()
 local bang=b:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");f.securityBang=bang;bang:SetPoint("TOPRIGHT",3,4);bang:SetText("|cffffff00!|r");bang:Hide()
 local drag=CreateFrame("Button",nil,f);f.moveHandle=drag
 drag:SetSize(32,32);drag:SetPoint("TOPLEFT",-16,16);drag:SetFrameLevel(b:GetFrameLevel()+3);drag:EnableMouse(true)
 local dot=drag:CreateTexture(nil,"ARTWORK");drag.dot=dot;dot:SetSize(18,18);dot:SetPoint("CENTER")
 dot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
 local grip=CreateFrame("Button",nil,f);f.sizeHandle=grip
 grip:SetSize(16,16);grip:SetPoint("BOTTOMRIGHT",0,0);grip:SetFrameLevel(b:GetFrameLevel()+3);grip:EnableMouse(true)
 local marks=grip:CreateTexture(nil,"ARTWORK");marks:SetAllPoints();marks:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
 grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
 function f:Restore()
  local s=Settings();local w,h=UIParent:GetWidth(),UIParent:GetHeight();local extent=s.size+PAD
  s.x=finite(s.x)and s.x or w/2-extent/2-220
  s.y=finite(s.y)and s.y or h/2-extent/2
  s.x=math.max(0,math.min(math.max(0,w-extent),s.x));s.y=math.max(0,math.min(math.max(0,h-extent),s.y))
  self:SetSize(extent,extent);b:SetSize(s.size,s.size)
  self:ClearAllPoints();self:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",s.x,s.y)
 end
 function f:Controls(show)
  drag:SetShown(show);grip:SetShown(show)
 end
 local function within()
  return MouseIsOver and(MouseIsOver(f)or MouseIsOver(drag)or MouseIsOver(grip))
 end
 local function leave()
  GameTooltip:Hide()
  -- Delay bridges transitions between the icon, outside handle and corner.
  -- No polling runs while idle.
  f.hoverToken=(f.hoverToken or 0)+1;local token=f.hoverToken
  C_Timer.After(.15,function()
   if token==f.hoverToken and not f.action and not within()then f:Controls(false)end
  end)
 end
 local function enter(owner,title,body)
  f.hoverToken=(f.hoverToken or 0)+1;f:Controls(true)
  if title then
   GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");GameTooltip:SetText(title,1,.82,0)
   GameTooltip:AddLine(body,1,1,1,true);GameTooltip:Show()
  end
 end
 function f:StopAction()
  if not self.action then return end
  self.action=nil;self:SetScript("OnUpdate",nil)
  -- Prevent a release over the icon from becoming an open-window click.
  self.suppressUntil=(GetTime and GetTime()or 0)+.2
  if self:IsShown()then leave()end
 end
 local function start(_,mouse,kind)
  if mouse~="LeftButton"or f.action then return end
  local s=Settings();local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
  f.action={kind=kind,cx=x/scale,cy=y/scale,x=s.x,y=s.y,size=s.size,top=s.y+s.size+PAD}
  f:Controls(true);GameTooltip:Hide()
  f:SetScript("OnUpdate",function()
   if not IsMouseButtonDown("LeftButton")then f:StopAction();return end
   local a=f.action;local cx,cy=GetCursorPosition();local sc=UIParent:GetEffectiveScale()
   local dx,dy=cx/sc-a.cx,cy/sc-a.cy
   if a.kind=="move"then s.x=a.x+dx;s.y=a.y+dy
   else
    s.size=math.max(MIN,math.min(MAX,math.floor(a.size+math.max(dx,-dy)+.5)))
    s.x=a.x;s.y=a.top-s.size-PAD
   end
   f:Restore()
  end)
 end
 drag:SetScript("OnMouseDown",function(o,m)start(o,m,"move")end)
 grip:SetScript("OnMouseDown",function(o,m)start(o,m,"size")end)
 for _,handle in ipairs({drag,grip})do handle:SetScript("OnMouseUp",function(_,m)if m=="LeftButton"then f:StopAction()end end)end
 b:SetScript("OnClick",function(_,mouse)
  if f.action or(GetTime and GetTime()or 0)<(f.suppressUntil or 0)then return end
  if mouse=="LeftButton"then if G.SpamShield:Unread()then G:OpenNetworkSecurity()else G:Toggle()end elseif mouse=="RightButton"then G:OpenMyCard()end
 end)
 f:SetScript("OnEnter",function()enter(f)end);f:SetScript("OnLeave",leave)
 b:SetScript("OnEnter",function()enter(b,"Guild Control 7.3.5",G.SpamShield:Unread()and(G:Text("Есть сетевое предупреждение. ЛКМ — открыть «Сетевую защиту»."))or(G:Text("ЛКМ — открыть или закрыть Guild Control. ПКМ — своя карточка. Точка сверху слева — перемещение, уголок снизу справа — размер. /gc735 button — скрыть или показать; /gc735 button reset — вернуть положение и размер.")))end)
 drag:SetScript("OnEnter",function()enter(drag,(G:Text("Перемещение")),(G:Text("Зажмите левую кнопку мыши и перетащите щиток.")))end)
 grip:SetScript("OnEnter",function()enter(grip,(G:Text("Размер кнопки")),(G:Text("Потяните за уголок левой кнопкой мыши. Положение и размер сохраняются.")))end)
 for _,owner in ipairs({b,drag,grip})do owner:SetScript("OnLeave",leave)end
 f:SetScript("OnHide",function()f:StopAction();f.hoverToken=(f.hoverToken or 0)+1;GameTooltip:Hide();f:Controls(false)end)
 f:SetScript("OnEvent",function()f:StopAction();f:Restore()end)
 f:RegisterEvent("DISPLAY_SIZE_CHANGED");f:RegisterEvent("UI_SCALE_CHANGED")
 f:Restore();f:Controls(false);f:SetShown(not Settings().hidden)
 if G.RefreshNetworkBadge then G:RefreshNetworkBadge()end
end
function G:ToggleFloatingButton()
 if not self.FloatingButton then self:InitializeFloatingButton()end
 local s=Settings();s.hidden=not s.hidden;self.FloatingButton:SetShown(not s.hidden)
 self:Print(s.hidden and(G:Text("Свободная кнопка скрыта. /gc735 button — показать."))or(G:Text("Свободная кнопка показана.")))
end
function G:ResetFloatingButton()
 if not self.FloatingButton then self:InitializeFloatingButton()end
 local f=self.FloatingButton;f:StopAction();local s=Settings()
 s.size=44;s.x=nil;s.y=nil;s.hidden=false;f:Restore();f:Controls(false);f:Show()
 self:Print((G:Text("Положение и размер свободной кнопки восстановлены.")))
end
