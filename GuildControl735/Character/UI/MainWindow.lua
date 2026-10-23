local _, GC = ...
local S = GC.Character
local L=S.L
local function Text(parent,width,size,value,heading)
    local t=parent:CreateFontString(nil,"ARTWORK",heading and "GameFontNormal" or "GameFontHighlight")
    t:SetWidth(width);t:SetHeight(0);t:SetJustifyH("LEFT");t:SetJustifyV("TOP");t:SetWordWrap(true)
    S:ApplyFont(t,size);t:SetTextColor(heading and 1 or 1,heading and .82 or 1,heading and 0 or 1)
    t:SetShadowColor(0,0,0,1);t:SetShadowOffset(1,-1);if value then t:SetText(value)end;return t
end
local function Place(text,parent,x,y,width)
    text:ClearAllPoints();text:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);text:SetWidth(width);text:SetHeight(0)
    return y+math.ceil(text:GetStringHeight() or 0)
end
function S:InitializeMainWindow()
    if self.MainWindow then return end
    local f=CreateFrame("Frame","GuildControl735SatelliteWindow",UIParent);self.MainWindow=f
    f:SetSize(780,560);f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
    local saved=self.db.window;f:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x,saved.y);f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames,"GuildControl735SatelliteWindow")end
    f:SetScript("OnMouseDown",function(o,b)if b=="LeftButton"then o:StartMoving()end end)
    f:SetScript("OnMouseUp",function(o)o:StopMovingOrSizing();local p,_,rp,x,y=o:GetPoint(1);S.db.window={point=p,relativePoint=rp,x=x,y=y}end)
    f.title=Text(f,690,16,L.TITLE,true);f.title:SetPoint("TOPLEFT",22,-18)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-6,-6);f.close=close
    f.purposeTitle=Text(f,340,14,L.PURPOSE_TITLE,true);f.purpose=Text(f,340,12,L.PURPOSE)
    f.privacyTitle=Text(f,340,14,L.PRIVACY_TITLE,true);f.privacy=Text(f,340,11,L.PRIVACY)
    f.stepsTitle=Text(f,338,14,L.STEPS_TITLE,true)
    f.steps=Text(f,338,11,(GC:Text("1. Выберите специализацию и наденьте комплект.\n2. Сохраните комплект кнопкой ниже.\nПовторите для другого комплекта.")))
    f.currentTitle=Text(f,338,14,L.CURRENT,true);f.current=Text(f,338,12)
    f.publish=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.publish:SetSize(338,36)
    f.publish:SetText((GC:Text("Сохранить текущий комплект")));self:ApplyFont(f.publish:GetFontString(),10)
    f.publish:SetScript("OnClick",function()S:PublishCurrent()end)
    f.publishedTitle=Text(f,338,14,L.PUBLISHED,true)
    f.profiles=CreateFrame("ScrollFrame","GC735SatellitePublishedScroll",f,"UIPanelScrollFrameTemplate");f.profiles:SetWidth(314)
    f.profiles:HookScript("OnScrollRangeChanged",function(_,_,range)
        local bar=_G.GC735SatellitePublishedScrollScrollBar
        if bar then bar:SetShown((range or 0)>0)end
    end)
    local child=CreateFrame("Frame",nil,f.profiles);child:SetWidth(310);f.profiles:SetScrollChild(child);f.profileContent=child
    f.profileLines={};f.deleteButtons={}
    f.profileMeasure=Text(f,230,11,(GC:Text("Боец — Специализация\nУровень предметов: 999")));f.profileMeasure:Hide()
    for i=1,4 do
        f.profileLines[i]=Text(child,230,11)
        local b=CreateFrame("Button",nil,child,"UIPanelButtonTemplate");b:SetSize(72,24);b:SetText((GC:Text("Удалить")));S:ApplyFont(b:GetFontString(),10)
        b:SetScript("OnClick",function()if b.specID then GC.ProfileList:Delete(b.specID)end end);b:Hide();f.deleteButtons[i]=b
    end
    self:InitializeFamilyWindow(f,28,0)
    f.manual=Text(f,712,10,L.MANUAL_ONLY);f.manual:SetPoint("TOPLEFT",28,-516)
    f:SetScript("OnShow",function()S:UpdateMainWindow()end)
    local events=CreateFrame("Frame")
    for _,e in ipairs({"PLAYER_EQUIPMENT_CHANGED","PLAYER_SPECIALIZATION_CHANGED","PLAYER_GUILD_UPDATE"})do events:RegisterEvent(e)end
    events:SetScript("OnEvent",function()if f:IsShown()then S:UpdateMainWindow()end end)
end
function S:LayoutMainWindow()
    local f=self.MainWindow;if not f then return end
    local y=Place(f.purposeTitle,f,28,64,340)+4;y=Place(f.purpose,f,28,y,340)+8
    y=Place(f.privacyTitle,f,28,y,340)+4;y=Place(f.privacy,f,28,y,340)+8
    local family=self.FamilyWindow;family:ClearAllPoints();family:SetPoint("TOPLEFT",f,"TOPLEFT",28,-y)
    self:LayoutFamilyList()
    f.layoutLeftBottom=y+164
    y=Place(f.stepsTitle,f,410,64,338)+4;y=Place(f.steps,f,410,y,338)+8
    y=Place(f.currentTitle,f,410,y,338)+4;y=math.max(Place(f.current,f,410,y,338),y+32)+8
    f.publish:ClearAllPoints();f.publish:SetPoint("TOPLEFT",410,-y);y=y+44
    y=Place(f.publishedTitle,f,410,y,338)+4
    local rowHeight=math.max(40,math.ceil(f.profileMeasure:GetStringHeight()or 28)+17)
    for _,line in ipairs(f.profileLines)do if line:IsShown()then rowHeight=math.max(rowHeight,math.ceil(line:GetStringHeight()or 28)+17)end end
    local profileHeight=0
    for i,line in ipairs(f.profileLines)do
        if line:IsShown()then
            local b=f.deleteButtons[i];b:ClearAllPoints();b:SetPoint("TOPLEFT",f.profileContent,"TOPLEFT",236,-profileHeight)
            Place(line,f.profileContent,0,profileHeight,230);profileHeight=profileHeight+rowHeight
        end
    end
    f.profileContent:SetHeight(math.max(1,profileHeight))
    local viewport=4*rowHeight
    f.profiles:ClearAllPoints();f.profiles:SetPoint("TOPLEFT",410,-y);f.profiles:SetHeight(viewport)
    local overflow=profileHeight>viewport
    local bar=_G.GC735SatellitePublishedScrollScrollBar
    if bar then bar:SetShown(overflow)end
    f.profiles:EnableMouseWheel(overflow)
    f.profiles:SetVerticalScroll(math.min(f.profiles:GetVerticalScroll(),math.max(0,profileHeight-viewport)))
    f.profilesOverflow=overflow;f.layoutBottom=math.max(f.layoutLeftBottom,y+viewport)
    local height=math.ceil(f.layoutBottom+64)
    f:SetHeight(height)
    f.manual:ClearAllPoints();f.manual:SetPoint("TOPLEFT",f,"TOPLEFT",28,-(height-44))
    GC:SetCompactPageHeight(height)

end
function S:UpdateMainWindow()
    local f=self.MainWindow;if not f then return end
    local c=self.Profile:ReadCurrent()
    if c then f.current:SetText(c.specName.." — "..(L['ROLE_'..c.role]or c.role).."\n"..L.ITEM_LEVEL..": "..math.floor(c.itemLevel+.5))else f.current:SetText(L.NO_SPECIALIZATION)end
    local profiles=self.Profile:GetProfiles()
    for i,line in ipairs(f.profileLines)do
        local p=profiles[i]
        local b=f.deleteButtons[i];b.specID=p and p.specID;b:SetShown(p~=nil)
        if p then line:SetText("|cffffd100"..(L['ROLE_'..p.role]or p.role).."|r — |cffffffff"..(p.specName or "").."|r\n"..GC:StatLabel(L.ITEM_LEVEL,math.floor(p.itemLevel+.5)));line:Show()
        elseif i==1 and #profiles==0 then line:SetText(L.NONE);line:Show()else line:Hide()end
    end
    self:UpdateFamilyWindow();self:LayoutMainWindow()
end
