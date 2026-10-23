local _,GC=...
local L=GC.L
local function Text(parent,y,h,size)
    local t=parent:CreateFontString(nil,"ARTWORK","GameFontHighlight");t:SetPoint("TOPLEFT",14,-y);t:SetSize(202,h)
    t:SetJustifyH("LEFT");t:SetJustifyV("TOP");t:SetWordWrap(true);GC:ApplyFont(t,size);return t
end
function GC:InitializeMemberCard(parent)
    local c=CreateFrame("Frame",nil,parent);c:SetPoint("TOPLEFT",1090,-207);c:SetSize(230,545);self.MemberCard=c
    local bg=c:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.04,.07,.10,.82)
    c.heading=Text(c,8,22,14);c.heading:SetText((GC:Text("Карточка игрока")));c.heading:SetWordWrap(false)
    c.contentScroll=CreateFrame("ScrollFrame","GC735MemberBodyScroll",c,"UIPanelScrollFrameTemplate")
    c.contentScroll:SetPoint("TOPLEFT",0,-32);c.contentScroll:SetSize(216,427)
    -- Only the committed layout owns visibility; native range callbacks still
    -- maintain slider values/arrows, then reconcile against that layout.
    local function reconcile(scroll)
        local bar=_G[scroll:GetName().."ScrollBar"]
        if bar then bar:SetShown(scroll.gcOverflow==true)end
    end
    c.contentScroll.scrollBarHideable=true
    c.contentScroll:HookScript("OnScrollRangeChanged",reconcile)
    local body=CreateFrame("Frame",nil,c.contentScroll);body:SetSize(230,427);c.contentScroll:SetScrollChild(body);c.body=body
    c.name=Text(body,0,36,14);c.rank=Text(body,38,18,11);c.status=Text(body,58,30,11)
    c.profileLines={};for i=1,4 do c.profileLines[i]=Text(body,94+(i-1)*32,32,10)end
    c.playerButton=CreateFrame("Button",nil,body,"UIPanelButtonTemplate");c.playerButton:SetSize(202,30)
    c.playerButton:SetText((GC:Text("Персонажи игрока")));self:ApplyFont(c.playerButton:GetFontString(),11)
    self:AttachHelp(c.playerButton,(GC:Text("Персонажи игрока")),(GC:Text("Показать в таблице основного и всех подтверждённых альтов выбранного игрока, включая выбранного персонажа. Остальные фильтры продолжают действовать и могут скрывать часть списка. Чтобы снять этот отбор, нажмите крестик у отметки над таблицей или «Сбросить фильтры». Если связи неполные, показываются только подтверждённые персонажи.")))
    c.playerButton:SetScript("OnClick",function()GC:FilterPlayerCharacters(GC.Roster:FindByKey(c.memberKey))end)
    c.playerButton:EnableMouseWheel(true);c.playerButton:SetScript("OnMouseWheel",function(_,delta)
        if c.compact then local bar=_G.GC735MemberBodyScrollScrollBar;if bar then bar:SetValue(bar:GetValue()-delta*30)end end
    end)
    c.familyNote=Text(body,312,32,11)
    c.familyScroll=CreateFrame("ScrollFrame","GC735MemberFamilyScroll",body,"UIPanelScrollFrameTemplate");c.familyScroll:SetPoint("TOPLEFT",14,-400);c.familyScroll:SetSize(178,64)
    local child=CreateFrame("Frame",nil,c.familyScroll);child:SetSize(176,250);c.familyScroll:SetScrollChild(child);c.familyChild=child
    c.familyScroll.scrollBarHideable=true
    c.familyScroll:HookScript("OnScrollRangeChanged",reconcile)
    c.familyScroll:EnableMouseWheel(true)
    c.familyScroll:HookScript("OnMouseWheel",function(_,delta)
        if c.compact then
            local bar=_G.GC735MemberBodyScrollScrollBar
            if bar then bar:SetValue(bar:GetValue()-delta*30)end
        end
    end)
    -- Keep the template scrollbar: arrows, thumb and native drag handlers.
    c.familyTitle=Text(body,348,20,11);c.familyTitle:SetText((GC:Text("|cffffd100Альты:|r")))
    c.alts=Text(child,0,250,11);c.alts:ClearAllPoints();c.alts:SetPoint("TOPLEFT",0,0);c.alts:SetWidth(174)
    c.categories={}
    for i,label in ipairs({"Mythic+",(GC:Text("PvP-активности")),(GC:Text("Рейды"))})do
        local kind=i==1 and "mythic" or (i==2 and "pvp" or "raid")
        local b=CreateFrame("Button",nil,c,"UIPanelButtonTemplate");b:SetSize(({90,138,75})[i],30);b:SetPoint("TOPLEFT",({14,14,128})[i],({-468,-502,-468})[i])
        GC:AttachHelp(b,label,({(GC:Text("Открыть данные Mythic+ выбранного персонажа: рейтинг, роли и прохождения ключей, доступные из серверного источника и сохранённого кэша.")),(GC:Text("Открыть PvP-данные выбранного персонажа: доступные рейтинги, игры и победы по режимам. При отсутствии данных показывается соответствующий статус.")),(GC:Text("Открыть сохранённые рейдовые данные выбранного персонажа и запросить доступное обновление. Данные офлайн-персонажа могут быть из кэша."))})[i])
        b:SetText(label);GC:ApplyFont(b:GetFontString(),10);b:SetScript("OnClick",function()GC:ToggleStats(kind)end);c.categories[i]=b
    end
    c.updated=Text(body,466,24,10);c.hint=Text(c,90,56,12);c.hint:SetText(L.SELECT_MEMBER)
    self:ShowMemberCard(nil)
end
function GC:ShowMemberCard(member)
    local c=self.MemberCard;if not c then return end
    c.memberKey=member and member.key or nil;c.hint:SetShown(not member)
    for _,t in ipairs({c.name,c.rank,c.status,c.familyNote,c.updated,c.familyTitle})do t:SetShown(member~=nil)end
    c.familyScroll:SetShown(member~=nil);c.contentScroll:SetShown(member~=nil)
    if c.playerButton then c.playerButton:SetShown(member~=nil);c.playerButton:SetEnabled(false)end
    for _,b in ipairs(c.categories)do b:SetEnabled(member~=nil)end
    for _,line in ipairs(c.profileLines)do line:Hide()end
    if not member then if self.UpdateStats then self:UpdateStats(nil)end;return end
    c.name:SetText(self:ClassName(member));c.rank:SetText(member.rank)
    -- Own identity uses its authoritative local set, including an empty set.
    -- Remote peers still pass through the unchanged receiver/cache boundary.
    local isSelf=member.guid==UnitGUID("player")
    local own=isSelf and self.Character and self.Character.Profile
    local record=own and own:GetCharacterStore() or self.SatelliteStore:Get(member);c.status:SetText(record and L.SATELLITE_INSTALLED or L.SATELLITE_NONE)
    local root=not isSelf and self.FastRecords and self.FastRecords:Root()
    local received=root and root.received[member.guid]
    if received then for _,cat in ipairs({"P","F","R"})do if received[cat]and received[cat].relay then
        c.status:SetText((record and L.SATELLITE_INSTALLED or L.SATELLITE_NONE)..(GC:Text("\n|cffffd100Есть данные от посредника|r")));break
    end end end
    local profiles=own and own:GetProfiles() or self.SatelliteStore:GetProfiles(member)
    for i,p in ipairs(profiles)do
        local line=c.profileLines[i];if not line then break end
        local _,name=GetSpecializationInfoByID(p.specID)
        line:SetText("|cffffd100"..(L['ROLE_'..p.role] or p.role).."|r — |cffffffff"..(name or L.UNKNOWN_SPECIALIZATION).."|r\n"..self:StatLabel(L.ITEM_LEVEL,math.floor(p.itemLevel+0.5)));line:Show()
    end
    if #profiles==0 then c.profileLines[1]:SetText(L.NO_PROFILES);c.profileLines[1]:Show()end
    c.updated:SetText("");c.updated:Hide() -- Dates remain in SavedVariables only.
    local family=self:PresentationFamily(member)
    if c.playerButton then c.playerButton:SetEnabled(family~=nil and #family.members>0)end
    if family then
        if family.mainGUID then c.familyNote:SetText((GC:Text("|cff50df70Основной:|r "))..self:ClassName(self.Roster:FindByKey(family.mainGUID)or{name=family.mainName}))
        elseif family.mainStatus=="conflict" then c.familyNote:SetText((GC:Text("|cffffd100Внимание!|r\nНа одном аккаунте несколько персонажей отмечены как основные. Проверьте метки [GC:MAIN] в офицерских заметках — оставьте только одну.")))
        elseif family.incomplete then c.familyNote:SetText((GC:Text("|cffffd100Данные о связях персонажей неполные.|r\nОсновной пока не подтверждён.")))
        elseif family.mainStatus=="unset" then c.familyNote:SetText((GC:Text("|cffffd100Внимание! Не указан основной персонаж|r")))
        else c.familyNote:SetText((GC:Text("Нет подтверждения метки основы")))end
        local names={};for _,m in ipairs(family.members)do if m.guid~=family.mainGUID then names[#names+1]=self:ClassName(m)..(m.archived and(GC:Text('\n|cffaaaaaa(Не в гильдии)|r'))or(GC:Text('\n|cff50df70(В гильдии)|r'))) end end
        c.alts:SetText(#names>0 and table.concat(names,"\n")or (GC:Text("Альты не подтверждены")))
    else c.familyNote:SetText((GC:Text("Персонажи аккаунта ещё не подтверждены")));c.alts:SetText(L.FAMILY_CARD_NO_DATA)end
    self:LayoutMemberCard()
    if self.UpdateStats then self:UpdateStats(member)end
end
function GC:OnSatelliteDataUpdated(member)
    if self.MainWindow and self.MainWindow:IsShown() then self:UpdateMainWindow()end
    if self.MemberCard and self.MemberCard.memberKey==member.key then self:ShowMemberCard(member)end
end
function GC:RefreshLinkedMemberCard()
    local k=self.MemberCard and self.MemberCard.memberKey;local m=k and self.Roster:FindByKey(k)
    if self.PlayerCharacterFilter and self.MainWindow and self.MainWindow:IsShown()then self:UpdateMainWindow()
    elseif m then self:ShowMemberCard(m)end
end

function GC:LayoutMemberCard()
    local c=self.MemberCard;if not c or not c.contentScroll then return end
    local available=math.max(80,c:GetHeight()-118)

    for i,b in ipairs(c.categories)do
        b:ClearAllPoints();b:SetPoint("TOPLEFT",({14,14,128})[i],-(c:GetHeight()-(i==2 and 43 or 77)))
    end
    local familyY=94
    for _,line in ipairs(c.profileLines)do if line:IsShown()then
        line:ClearAllPoints();line:SetPoint("TOPLEFT",14,-familyY)
        local h=math.max(28,(line:GetStringHeight()or 28)+2);line:SetHeight(h);familyY=familyY+h+2
    end end
    familyY=familyY+6
    if c.playerButton then c.playerButton:ClearAllPoints();c.playerButton:SetPoint("TOPLEFT",14,-familyY);familyY=familyY+c.playerButton:GetHeight()+8 end
    c.familyNote:ClearAllPoints();c.familyNote:SetPoint("TOPLEFT",14,-familyY);c.familyNote:SetHeight(0)
    local titleY=familyY+math.max(20,c.familyNote:GetStringHeight()or 20)+2
    c.familyTitle:ClearAllPoints();c.familyTitle:SetPoint("TOPLEFT",14,-titleY)
    local listY=titleY+20;c.alts:SetHeight(0)
    local textHeight=math.max(20,(c.alts:GetStringHeight()or 20)+4)
    local compact=listY+40>available;c.compact=compact
    local viewport=compact and textHeight or math.max(40,available-listY)
    local content=math.max(viewport,textHeight)
    c.familyScroll.gcOverflow=not compact and textHeight>viewport+.5
    c.contentScroll.gcOverflow=compact and listY+textHeight>available+.5
    c.familyScroll:ClearAllPoints();c.familyScroll:SetPoint("TOPLEFT",14,-listY);c.familyScroll:SetHeight(viewport)
    c.familyChild:SetHeight(content)
    local familyBar=_G.GC735MemberFamilyScrollScrollBar;if familyBar then familyBar:SetShown(c.familyScroll.gcOverflow)end
    c.familyScroll:SetVerticalScroll(math.max(0,math.min(c.familyScroll:GetVerticalScroll()or 0,content-viewport)))
    c.body:SetHeight(compact and listY+textHeight or available)
    c.contentScroll:SetHeight(available)
    local overflow=c.contentScroll.gcOverflow
    local bar=_G.GC735MemberBodyScrollScrollBar
    if bar then
        bar:ClearAllPoints();bar:SetPoint("TOPRIGHT",c,"TOPRIGHT",-2,-50);bar:SetPoint("BOTTOMRIGHT",c,"BOTTOMRIGHT",-2,104)
        bar:SetShown(overflow)
    end
    c.contentScroll:EnableMouseWheel(overflow)
    c.contentScroll:SetVerticalScroll(math.max(0,math.min(c.contentScroll:GetVerticalScroll()or 0,c.body:GetHeight()-available)))
end
