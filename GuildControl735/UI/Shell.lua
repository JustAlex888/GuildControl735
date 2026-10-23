-- Host owns navigation and geometry; pages expose only lifecycle and dimensions.
local _,GC=...
GC.Shell={pages={},activePage="general"}
local H=GC.Shell
local HEADER=0
local function Backdrop(f)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
end
function H:Register(id,page)
    if self.pages[id]then return false end
    self.pages[id]=page
    if page.Init then page:Init(self.frame,HEADER)end
    page:Hide()
    return true
end
function H:Select(id)
    GC.Diagnostics:Record("PAGE",id)
    local page=self.pages[id];if not page then return false end
    local old=self.pages[self.activePage]
    if old and old~=page then old:Hide()end
    self.activePage=id
    local f=self.frame
    -- Freeze the actual top-left before resizing a CENTER-anchored legacy window.
    local left,top=f:GetLeft(),f:GetTop()
    if left and top then f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)end
    if GC.PreparePageGeometry then GC:PreparePageGeometry(id,page)end
    f:SetSize(page.width,page.height+HEADER)
    if id=="general"and GC.LayoutGeneral then GC:LayoutGeneral(page.width,page.height)end
    if GC.GeneralGrip then GC.GeneralGrip:SetShown(id=="general")end
    if f:IsShown()then page:Show()end
    for key,button in pairs(self.buttons)do
        if key==id then PanelTemplates_SelectTab(button)else PanelTemplates_DeselectTab(button)end
    end
    GC:FitDockedPanels()
    return true
end
function H:Open(id)
    self:Select(id or self.activePage)
    if not self.frame:IsShown()then self.frame:Show()end
end
function H:Toggle()
    if self.frame:IsShown()then self.frame:Hide()else self:Open()end
end
function GC:InitializeShell()
    if H.frame then return end
    local f=CreateFrame("Frame","GuildControl735ShellWindow",UIParent);H.frame=f;self.ShellWindow=f
    f:SetSize(1350,760);f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);Backdrop(f);f:Hide()
    local saved=self.db.window
    f:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x,saved.y)
    f:SetScript("OnMouseDown",function(o,b)if b=="LeftButton"then o:StartMoving()end end)
    f:SetScript("OnMouseUp",function(o)
        o:StopMovingOrSizing();GC:FitDockedPanels()
        local point,_,relativePoint,x,y=o:GetPoint(1)
        GC.db.window.point,GC.db.window.relativePoint,GC.db.window.x,GC.db.window.y=point,relativePoint,x,y
    end)
    H.buttons={}
    for i,entry in ipairs({{"general",(GC:Text("Общие данные"))},{"satellite",(GC:Text("Моя визитка"))},{"analytics",(GC:Text("Аналитика"))},{"settings",(GC:Text("Настройки"))},{"security",(GC:Text("Сетевая защита"))}})do
        local id,label=entry[1],entry[2]
        local b=CreateFrame("Button","GuildControl735PageTab"..i,f,"CharacterFrameTabButtonTemplate")
        b:SetID(i);b:SetText(label);b:SetSize(150,32)
        b.selectedTextY=-3;b.deselectedTextY=-3
        b:GetFontString():SetHeight(24)
        b:SetPoint("BOTTOMLEFT",f,"TOPLEFT",12+(i-1)*152,-4)
        -- Replace the CharacterFrame-specific resize hooks (default max88).
        local function ResizeTab(o)PanelTemplates_TabResize(o,0,150,150)end
        b:SetScript("OnShow",ResizeTab);b:SetScript("OnEvent",ResizeTab);ResizeTab(b)
        -- Native artwork is made for bottom tabs; mirror only the artwork so
        -- its open edge joins the body below these top tabs. Text stays upright.
        for _,part in ipairs({"Left","Middle","Right","LeftDisabled","MiddleDisabled","RightDisabled","HighlightTexture"})do
            local texture=_G[b:GetName()..part]
            if texture then
                local ulx,uly,llx,lly,urx,ury,lrx,lry=texture:GetTexCoord()
                texture:SetTexCoord(llx,lly,ulx,uly,lrx,lry,urx,ury)
            end
        end
        -- Raise only inactive artwork: bottom stays at -33, top -1 -> +2.
        local left=_G[b:GetName().."Left"]
        if left then
            left:ClearAllPoints();left:SetPoint("TOPLEFT",b,"TOPLEFT",0,2)
            for _,part in ipairs({"Left","Middle","Right"})do _G[b:GetName()..part]:SetHeight(35)end
            local highlight=_G[b:GetName().."HighlightTexture"]
            if highlight then
                highlight:ClearAllPoints();highlight:SetPoint("TOPLEFT",b,"TOPLEFT",3,2);highlight:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-3,-1)
            end
        end
        GC:ApplyFont(b:GetFontString(),13);b:SetScript("OnClick",function()H:Select(id)end);H.buttons[id]=b
    end
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-6,-6)
    close:SetFrameLevel(f:GetFrameLevel()+20)
    close:SetScript("OnClick",function()f:Hide()end);H.close=close
    if UISpecialFrames then table.insert(UISpecialFrames,"GuildControl735ShellWindow")end
    f:SetScript("OnShow",function()local p=H.pages[H.activePage];if p then p:Show()end;GC:FitDockedPanels()end)
    f:SetScript("OnHide",function()
        local p=H.pages[H.activePage];if p then p:Hide()end
        GC:CloseDockedPanels()
        if GC.ReminderWindow then GC.ReminderWindow:Hide()end
        if GC.Dropdown.Close then GC.Dropdown.Close()end
    end)
    -- Narrow bridge for the optional second addon; no profiles or wire data here.
    f.AttachSatellite=function(_,page)
        local old=H.pages.satellite
        if old and not old.unavailable then return false end
        if old then old:Hide();H.pages.satellite=nil end
        H:Register("satellite",page)
        if H.activePage=="satellite"then H:Select("satellite")end
        return true
    end
    f.OpenPage=function(_,id)H:Open(id)end
    f.ToggleSatellite=function()
        if f:IsShown()and H.activePage=="satellite"then f:Hide()else H:Open("satellite")end
    end
end
