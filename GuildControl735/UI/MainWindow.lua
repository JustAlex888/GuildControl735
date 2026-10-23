local _, GC = ...
local L = GC.L

local ROW_HEIGHT = 30
-- Header labels scale as text. A taller header gives the last-online label
-- its own second line at the fixed 120% font size.
local HEADER_HEIGHT = 43
local VISIBLE_ROWS = 14 -- Initial pool, extended lazily when the window grows.
local ROSTER_WIDTH = 1050
local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER",
}
local CLASS_FALLBACK = GC:RegisterLocaleTable({},function()return {
    WARRIOR = (GC:Text("Воин")), PALADIN = (GC:Text("Паладин")), HUNTER = (GC:Text("Охотник")),
    ROGUE = (GC:Text("Разбойник")), PRIEST = (GC:Text("Жрец")), DEATHKNIGHT = (GC:Text("Рыцарь смерти")),
    SHAMAN = (GC:Text("Шаман")), MAGE = (GC:Text("Маг")), WARLOCK = (GC:Text("Чернокнижник")),
    MONK = (GC:Text("Монах")), DRUID = (GC:Text("Друид")), DEMONHUNTER = (GC:Text("Охотник на демонов")),
} end)
local function ClassLabel(file)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file])
        or CLASS_FALLBACK[file] or file
end
local inactivityOptions = { 0, 30, 60, 90, 180, 365 }
local columns = {
    { key = "name", label = "HEADER_NAME", width = 225 },
    { key = "class", label = "HEADER_CLASS", width = 52 },
    { key = "level", label = "HEADER_LEVEL", width = 55 },
    { key = "rank", label = "HEADER_RANK", width = 165 },
    { key = "satellite", label = "HEADER_SATELLITE", width = 205 },
    { key = "family", label = "HEADER_FAMILY", width = 145 },
    { key = "lastOnline", label = "HEADER_LAST_ONLINE", width = 140 },
    { key = "zone", label = "HEADER_ZONE", width = 220 },
    { key = "note", label = "HEADER_NOTE", width = 200 },
    { key = "officerNote", label = "HEADER_OFFICER_NOTE", width = 200 },
    { key = "profession1", label = "HEADER_PROFESSION1", width = 120 },
    { key = "profession2", label = "HEADER_PROFESSION2", width = 120 },
}
for _,column in ipairs(columns)do column.defaultWidth=column.width end
local CONTENT_WIDTH=0;for _,column in ipairs(columns)do CONTENT_WIDTH=CONTENT_WIDTH+column.width end

local function SetBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
end

local function FormatLastOnline(member)
    if member.online then
        return L.ONLINE
    end
    local days = math.floor(member.offlineDays or 0)
    if days >= 365 then
        return string.format(L.YEARS, math.floor(days / 365))
    elseif days >= 30 then
        return string.format(L.MONTHS, math.floor(days / 30))
    end
    return string.format(L.DAYS, days)
end

local function FormatSatellite(member)
    local text=GC:ProfileSummary(member)
    return text==L.CARD_EMPTY and L.ADDON_UNKNOWN or text
end

local function CreateTextCell(parent, width)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetWidth(width - 8)
    text:SetHeight(ROW_HEIGHT)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    GC:ApplyFont(text, 12)
    return text
end

function GC:InitializeMainWindow()
    if self.MainWindow then
        return
    end

    local frame = CreateFrame("Frame", "GuildControl735MainWindow", self.ShellWindow)
    frame:SetSize(1350, 760)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    -- Shell owns the native frame; General owns only its content.
    frame:Hide()
    self.MainWindow = frame

    frame:SetPoint("TOPLEFT",self.ShellWindow,"TOPLEFT",0,0)
    frame:SetMovable(false);frame:SetClampedToScreen(false)
    frame:SetScript("OnMouseDown",function(_,button)local fn=GC.ShellWindow:GetScript("OnMouseDown");if fn then fn(GC.ShellWindow,button)end end)
    frame:SetScript("OnMouseUp",function()local fn=GC.ShellWindow:GetScript("OnMouseUp");if fn then fn(GC.ShellWindow)end end)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(string.format(L.TITLE_CREDIT,L.TITLE))
    title:SetSize(1280,18);title:SetWordWrap(false);title:SetJustifyH("LEFT")
    self:ApplyFont(title, 9);frame.title=title

    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(300, 32)
    search:SetPoint("TOPLEFT", 22, -58)
    search:SetFont(STANDARD_TEXT_FONT, math.floor(13 * self:GetTextScale() + 0.5))
    search:SetAutoFocus(false)
    search:SetText(self.db.filters.search or "")
    search.hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    search.hint:SetPoint("LEFT", 7, 0)
    search.hint:SetText(L.SEARCH)
    search.hint:SetShown(search:GetText() == "")
    self:ApplyFont(search.hint, 12)
    frame.search = search

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(130, 30)
    refresh:SetPoint("LEFT", search, "RIGHT", 10, 0)
    refresh:SetText(L.REFRESH)
    self:ApplyFont(refresh:GetFontString(), 12)
    refresh:SetScript("OnClick", function()
        GC.Roster:RequestRefresh()
        GC.RosterDetails:RequestProfessions()
        GC.Roster:Rebuild()
        GC:UpdateMainWindow()
    end)

    local guildInvite = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    guildInvite:SetSize(190,30);guildInvite:SetPoint("TOPLEFT",616,-58)
    guildInvite:SetText((GC:Text("Принять в гильдию")));self:ApplyFont(guildInvite:GetFontString(),12)
    guildInvite:GetFontString():SetTextColor(1,.82,0)
    -- Keep the native template's rim, text and highlight; tint only its inset.
    local green=guildInvite:CreateTexture(nil,"ARTWORK");green:SetPoint("TOPLEFT",5,-5);green:SetPoint("BOTTOMRIGHT",-5,5);green:SetTexture("Interface\\Buttons\\WHITE8X8")
    local function paint(pressed)
        if guildInvite.gcInviteEnabled==false then green:SetGradientAlpha("VERTICAL",.05,.07,.05,1,.15,.18,.15,1)
        elseif pressed then green:SetGradientAlpha("VERTICAL",.015,.10,.02,1,.035,.25,.045,1)
        else green:SetGradientAlpha("VERTICAL",.025,.14,.03,1,.10,.43,.07,1)end
    end
    guildInvite.greenFill=green;guildInvite.PaintGreen=paint;paint(false);frame.guildInvite=guildInvite
    guildInvite:HookScript("OnMouseDown",function()paint(true)end);guildInvite:HookScript("OnMouseUp",function()paint(false)end)
    guildInvite:HookScript("OnLeave",function()paint(false)end)
    guildInvite:SetScript("OnClick",function()if GC.MemberManagement then GC.MemberManagement:OpenInvite()end end)

    local rankDropdown = GC.Dropdown.Create("GuildControl735RankDropdown", frame)
    rankDropdown:SetPoint("TOPLEFT",194,-103)
    GC.Dropdown.SetWidth(rankDropdown, 165)
    self:ApplyFont(_G[rankDropdown:GetName() .. "Text"], 12)
    frame.rankDropdown = rankDropdown
    self.Filters:NormalizeState(self.db.filters)

    local inactivityDropdown = GC.Dropdown.Create("GuildControl735InactivityDropdown", frame)
    inactivityDropdown:SetPoint("TOPLEFT",382,-103)
    GC.Dropdown.SetWidth(inactivityDropdown, 175)
    self:ApplyFont(_G[inactivityDropdown:GetName() .. "Text"], 12)
    frame.inactivityDropdown = inactivityDropdown

    local satelliteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    satelliteButton:SetSize(200, 30)
    satelliteButton:SetPoint("TOPRIGHT",-24,-120)
    satelliteButton:SetText(L.REQUEST_SATELLITE)
    self:ApplyFont(satelliteButton:GetFontString(), 11)
    satelliteButton:SetScript("OnClick", function()
        GC.Roster:Rebuild()
        GC:RequestAllData()
    end)
    frame.satelliteButton = satelliteButton

    local stopRequest = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    stopRequest:SetSize(200,30);stopRequest:SetPoint("TOPRIGHT",-24,-156)
    stopRequest:SetText((GC:Text("Остановить запрос")));GC:ApplyFont(stopRequest:GetFontString(),11)
    stopRequest:SetScript("OnClick",function()GC.DataExchange:Stop();stopRequest:SetEnabled(false)end)
    local elapsed=0;stopRequest:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+(dt or 0);if elapsed>=.2 then elapsed=0;stopRequest:SetEnabled(GC.DataExchange:HasPending())end end)
    stopRequest:SetScript("OnShow",function()stopRequest:SetEnabled(GC.DataExchange:HasPending())end)
    stopRequest:SetEnabled(false);frame.stopRequest=stopRequest
    GC:AttachHelp(stopRequest,(GC:Text("Остановить запрос")),(GC:Text("Отменяет текущий локальный сбор и ожидающие задачи обмена. Уже полученные данные сохраняются; отправленные сообщения не отзываются.")))

    local onlineOnly = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    onlineOnly:SetPoint("TOPLEFT", 22, -145)
    onlineOnly:SetChecked(self.db.filters.onlineOnly)
    onlineOnly.text = onlineOnly:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    onlineOnly.text:SetPoint("LEFT", onlineOnly, "RIGHT", 2, 1)
    onlineOnly.text:SetText(L.ONLINE_ONLY)
    self:ApplyFont(onlineOnly.text, 13)
    frame.onlineOnly = onlineOnly

    frame.permissionMode = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.permissionMode:SetPoint("TOPLEFT",20,-39)
    frame.permissionMode:SetSize(1100,20);frame.permissionMode:SetWordWrap(false)
    frame.permissionMode:SetJustifyH("LEFT")
    self:ApplyFont(frame.permissionMode, 13)

    local remind = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    remind:SetSize(200, 30)
    remind:SetPoint("TOPRIGHT", -24, -48)
    remind:SetText(L.REMINDER_SEND)
    self:ApplyFont(remind:GetFontString(), 11)
    remind:SetScript("OnClick", function() GC.Reminders:Send(true) end)
    frame.reminderSend = remind

    local reminderSettings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reminderSettings:SetSize(200, 30)
    reminderSettings:SetPoint("TOPRIGHT", -24, -84)
    reminderSettings:SetText(L.REMINDER_SETTINGS)
    self:ApplyFont(reminderSettings:GetFontString(), 11)
    reminderSettings:SetScript("OnClick", function() GC:OpenReminderWindow() end)
    frame.reminderSettings = reminderSettings

    local classDropdown = GC.Dropdown.Create("GuildControl735ClassDropdown", frame)
    classDropdown:SetPoint("TOPLEFT",6,-103)
    GC.Dropdown.SetWidth(classDropdown, 165)
    self:ApplyFont(_G[classDropdown:GetName() .. "Text"], 12)
    frame.classDropdown = classDropdown

    local rangeFromLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeFromLabel:SetPoint("TOPLEFT",616,-113)
    rangeFromLabel:SetText(L.LEVEL_FROM)
    self:ApplyFont(rangeFromLabel, 12)
    local rangeFrom = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    rangeFrom:SetSize(54, 26)
    rangeFrom:SetPoint("LEFT", rangeFromLabel, "RIGHT", 12, 0)
    rangeFrom:SetAutoFocus(false)
    rangeFrom:SetNumeric(true)
    rangeFrom:SetText(tostring(self.db.filters.minLevel or 1))
    self:ApplyFont(rangeFrom,13)
    frame.levelFrom = rangeFrom;frame.rangeFromLabel=rangeFromLabel

    local rangeToLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeToLabel:SetPoint("LEFT", rangeFrom, "RIGHT", 14, 0)
    rangeToLabel:SetText(L.LEVEL_TO)
    self:ApplyFont(rangeToLabel, 12)
    local rangeTo = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    rangeTo:SetSize(54, 26)
    rangeTo:SetPoint("LEFT", rangeToLabel, "RIGHT", 12, 0)
    rangeTo:SetAutoFocus(false)
    rangeTo:SetNumeric(true)
    rangeTo:SetText(tostring(self.db.filters.maxLevel or 110))
    self:ApplyFont(rangeTo,13)
    frame.levelTo = rangeTo;frame.rangeToLabel=rangeToLabel

    self:InitializePresentationFilters(frame)

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(160, 29)
    -- Third row leaves room for future filters between Online and Reset.
    reset:SetPoint("TOPLEFT",720,-146)
    reset:SetText(L.RESET_FILTERS)
    self:ApplyFont(reset:GetFontString(), 11)
    frame.resetFilters = reset

    local content=self:CreateRosterViewport(frame,CONTENT_WIDTH,ROSTER_WIDTH,HEADER_HEIGHT,ROW_HEIGHT,VISIBLE_ROWS)
    local header = CreateFrame("Frame", nil, content)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetSize(CONTENT_WIDTH, HEADER_HEIGHT)
    frame.header = header
    frame.columnHeaders={};frame.columns=columns

    local x = 0
    for columnIndex, column in ipairs(columns) do
        local sortKey = column.key
        local button = CreateFrame("Button", nil, header)
        button:SetPoint("TOPLEFT", x, 0)
        button:SetSize(column.width, HEADER_HEIGHT)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.20, 0.28, 0.95)
        local label = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 5, -2)
        label:SetSize(column.width - 10, HEADER_HEIGHT - 4)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetWordWrap(false)
        local heading = L[column.label]

        label:SetText(heading)
        if column.key=="officerNote"then label:SetWordWrap(true)end
        local second
        if column.key=="lastOnline"then
            local first,tail=heading:match("^(%S+)%s+(.+)$")
            if tail then
                label:ClearAllPoints();label:SetPoint("TOPLEFT",5,-3)
                label:SetSize(column.width-10,18);label:SetText(first)
                second=button:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
                second:SetPoint("TOPLEFT",5,-22);second:SetSize(column.width-10,18)
                second:SetJustifyH("LEFT");second:SetJustifyV("MIDDLE");second:SetWordWrap(false)
                second:SetText(tail);self:ApplyFont(second,12)
            end
        end
        self:ApplyFont(label, 12)
        button:SetScript("OnClick", function()
            if GC.db.sort.key == sortKey then
                GC.db.sort.ascending = not GC.db.sort.ascending
            else
                GC.db.sort.key = sortKey
                GC.db.sort.ascending = true
            end
            GC:UpdateMainWindow()
        end)
        frame.columnHeaders[columnIndex]={button=button,label=label,second=second,heading=heading}
        x = x + column.width
    end

    frame.rows = {}
    local function CreateRosterRow(rowIndex)
        local row = CreateFrame("Button", nil, content)
        row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
        row:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.25, 0.55, 0.75, 0.20)
        row.selection = row:CreateTexture(nil, "BACKGROUND")
        row.selection:SetAllPoints()
        row.selection:SetColorTexture(0.20, 0.42, 0.58, 0.28)
        row.selection:Hide()

        row.cells = {}
        local cellX = 0
        for columnIndex, column in ipairs(columns) do
            local cell = CreateTextCell(row, column.width)
            if column.key=="satellite"then GC:ApplyFont(cell,10)end
            cell:SetPoint("TOPLEFT", cellX + 4, 0)
            row.cells[columnIndex] = cell
            if column.key=="class"then
                row.classIcon=row:CreateTexture(nil,"ARTWORK");row.classIcon:SetSize(22,22)
                row.classIcon:SetPoint("TOPLEFT",cellX+15,-4)
            end
            cellX = cellX + column.width
        end
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",frame.rosterWheel)
        row:RegisterForClicks("LeftButtonUp","RightButtonUp")
        row:SetScript("OnClick", function(owner,button)
            if button=="RightButton"and owner.member and GC.MemberActions then GC.MemberActions:OpenMenu(owner.member);return end
            if owner.member then
                if GC.MemberActions and not GC.MemberActions:SelectMember(owner.member)then return end
                frame.selectedMemberKey = owner.member.key
                GC:ShowMemberCard(owner.member)
                GC:UpdateMainWindow()
            end
        end)
        frame.rows[rowIndex] = row
        if GC.RosterDetails.frame then GC.RosterDetails:AttachRow(row,frame)end
    end
    function frame:EnsureRows(count)
        for i=#self.rows+1,count do CreateRosterRow(i)end
    end
    frame:EnsureRows(VISIBLE_ROWS)

    local scroll = CreateFrame("ScrollFrame", "GuildControl735RosterScroll", frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame.rosterViewport, "TOPLEFT", 0, -HEADER_HEIGHT)
    scroll:SetPoint("BOTTOMRIGHT", frame.rosterViewport, "BOTTOMRIGHT", -2, 0)
    scroll:SetScript("OnVerticalScroll", function(owner, offset)
        FauxScrollFrame_OnVerticalScroll(owner, offset, ROW_HEIGHT, function()
            GC:UpdateMainWindow()
        end)
    end)
    frame.scroll = scroll
    self:ModernVerticalScrollbar(scroll,frame.rosterViewport,-HEADER_HEIGHT,VISIBLE_ROWS*ROW_HEIGHT,ROW_HEIGHT)

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    status:SetPoint("BOTTOMLEFT", 22, 23)
    frame.status = status
    self:ApplyFont(status, 12)

    local safety = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    safety:SetPoint("BOTTOMLEFT", 270, 23)
    safety:SetWidth(685)
    safety:SetJustifyH("LEFT")
    frame.safety = safety
    safety:SetText(L.READ_ONLY)
    self:ApplyFont(safety, 11)

    self:InitializeGeneralColumns(frame)
    self:InitializeRosterSizing(frame)
    self.RosterDetails:Initialize(frame)
    self:InitializePlayerCharacterFilter(frame)
    self:CompactGeneralFilters(frame)
    self:AttachHelp(search,(GC:Text("Поиск")),(GC:Text("Поиск по данным участников, включая спеки, роли, основу/альта, доступные заметки и профессии. Работает вместе с фильтрами.")))
    self:AttachHelp(refresh,L.REFRESH,(GC:Text("Запросить актуальный состав гильдии Blizzard и обновить таблицу: персонажи, звания, уровни, присутствие и зоны. Это не запрос комплектов аддона.")))
    self:AttachHelp(rankDropdown,(GC:Text("Звание")),(GC:Text("Выберите одно или несколько званий. Пустой выбор показывает все звания. Другие фильтры продолжают действовать.")))
    self:AttachHelp(inactivityDropdown,(GC:Text("Неактивность")),(GC:Text("Показать отсутствующих не меньше выбранного количества дней. Значение «Все» отключает этот фильтр. С фильтром «Только в сети» выбор неактивных даст пустой список.")))
    self:AttachHelp(classDropdown,(GC:Text("Классы")),(GC:Text("Выберите один или несколько классов. Пустой выбор показывает все классы.")))
    self:AttachHelp(rangeFrom,(GC:Text("Уровень от")),(GC:Text("Минимальный уровень включительно. Допустимый диапазон: 1–110.")))
    self:AttachHelp(rangeTo,(GC:Text("Уровень до")),(GC:Text("Максимальный уровень включительно. Он должен быть не меньше минимального.")))
    self:AttachHelp(onlineOnly,L.ONLINE_ONLY,(GC:Text("Показывать только персонажей, которые сейчас в сети по данным состава Blizzard.")))
    self:AttachHelp(reset,L.RESET_FILTERS,(GC:Text("Сбросить поиск, звания, классы, профессии, состояния аддона и спеков, отбор персонажей игрока, неактивность, диапазон уровней и ограничение «Только в сети». Ширина столбцов сохраняется.")))
    self:AttachHelp(satelliteButton,L.REQUEST_SATELLITE,(GC:Text("Доверенный участник запускает сверку онлайн-персонажей с аддоном: комплекты специализаций, связи персонажей аккаунта и доступные результаты меток основы. Передаются изменения; сохранённые данные догружаются через доверенный кэш. Действуют права, очередь и ограничения частоты; результат приходит не мгновенно.")))
    self:AttachHelp(remind,L.REMINDER_SEND,(GC:Text("Отправить предусмотренное напоминание о заполнении визитки. Доступность зависит от прав; действуют ограничения отправки.")))
    self:AttachHelp(reminderSettings,L.REMINDER_SETTINGS,(GC:Text("Открыть настройки напоминаний о заполнении визитки.")))
    self:InitializeMemberCard(frame)
    self:InitializeDockedPanels(frame)
    self:InitializeGeneralSizing(frame)

    search:SetScript("OnTextChanged", function(owner)
        owner.hint:SetShown(owner:GetText() == "")
        GC.db.filters.search = owner:GetText()
        GC:UpdateMainWindow()
    end)
    search:SetScript("OnEscapePressed", function(owner)
        owner:ClearFocus()
    end)

    onlineOnly:SetScript("OnClick", function(owner)
        GC.db.filters.onlineOnly = owner:GetChecked() and true or false
        GC:UpdateMainWindow()
    end)

    local function UpdateLevelEdit(owner, key, fallback)
        local number = tonumber(owner:GetText())
        GC.db.filters[key] = number and math.floor(number) or fallback
        GC:UpdateMainWindow()
    end
    local function NormalizeLevelEdit(owner, key, fallback)
        local value = tonumber(owner:GetText()) or fallback
        value = math.max(1, math.min(110, math.floor(value)))
        GC.db.filters[key] = value
        owner:SetText(tostring(value))
        GC:UpdateMainWindow()
    end
    rangeFrom:SetScript("OnTextChanged", function(owner) UpdateLevelEdit(owner, "minLevel", 1) end)
    rangeTo:SetScript("OnTextChanged", function(owner) UpdateLevelEdit(owner, "maxLevel", 110) end)
    rangeFrom:SetScript("OnEnterPressed", function(owner) owner:ClearFocus() end)
    rangeTo:SetScript("OnEnterPressed", function(owner) owner:ClearFocus() end)
    rangeFrom:SetScript("OnEditFocusLost", function(owner) NormalizeLevelEdit(owner, "minLevel", 1) end)
    rangeTo:SetScript("OnEditFocusLost", function(owner) NormalizeLevelEdit(owner, "maxLevel", 110) end)

    reset:SetScript("OnClick", function()
        local f = GC.db.filters
        f.search, f.rank, f.ranks, f.classes = "", nil, {}, {}
        f.profession, f.addonState = nil, nil
        f.professions, f.addonStates = {}, {}
        GC:ClearPlayerCharacterFilter(false)
        frame:ShowAllColumns()
        f.multiRankInitialized = true
        f.minLevel, f.maxLevel, f.inactiveDays, f.onlineOnly = 1, 110, 0, false
        search:SetText("")
        rangeFrom:SetText("1")
        rangeTo:SetText("110")
        onlineOnly:SetChecked(false)
        GC:UpdateMainWindow()
    end)

    GC.Dropdown.Initialize(rankDropdown, function(_, level)
        local selection = GC.db.filters.ranks
        local all = GC.Dropdown.CreateInfo()
        all.text = L.RANK_ALL
        all.isNotRadio = true
        all.checked = GC.Filters.CountSelected(selection) == 0
        all.func = function()
            GC.db.filters.ranks = {}
            GC:UpdateMainWindow()
        end
        GC.Dropdown.AddButton(all, level)
        for _, rank in ipairs(GC.Roster.ranks) do
            local rankName = rank.name
            local info = GC.Dropdown.CreateInfo()
            info.text = rankName
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.checked = selection[rankName] == true
            info.func = function()
                selection[rankName] = not selection[rankName] and true or nil
                GC:UpdateMainWindow()
            end
            GC.Dropdown.AddButton(info, level)
        end
    end)

    GC.Dropdown.Initialize(classDropdown, function(_, level)
        local selection = GC.db.filters.classes
        local all = GC.Dropdown.CreateInfo()
        all.text = L.CLASS_ALL
        all.isNotRadio = true
        all.checked = GC.Filters.CountSelected(selection) == 0
        all.func = function()
            GC.db.filters.classes = {}
            GC:UpdateMainWindow()
        end
        GC.Dropdown.AddButton(all, level)
        for _, classID in ipairs(CLASS_ORDER) do
            local key = classID
            local info = GC.Dropdown.CreateInfo()
            info.text = ClassLabel(key)
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.checked = selection[key] == true
            info.func = function()
                selection[key] = not selection[key] and true or nil
                GC:UpdateMainWindow()
            end
            GC.Dropdown.AddButton(info, level)
        end
    end)

    GC.Dropdown.Initialize(inactivityDropdown, function(_, level)
        for _, value in ipairs(inactivityOptions) do
            local days = value
            local info = GC.Dropdown.CreateInfo()
            info.text = days > 0 and string.format(L.INACTIVE_PREFIX, days) or L.INACTIVE_ALL
            info.checked = (tonumber(GC.db.filters.inactiveDays) or 0) == days
            info.func = function()
                GC.db.filters.inactiveDays = days
                GC.Dropdown.Close()
                GC:UpdateMainWindow()
            end
            GC.Dropdown.AddButton(info, level)
        end
    end)

    frame:SetScript("OnShow", function()
        GC.Roster:RequestRefresh()
        GC.RosterDetails:RequestProfessions()
        GC.Roster:Rebuild()
        GC:UpdateMainWindow()
        GC:FitDockedPanels()
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("GUILD_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_GUILD_UPDATE")
    events:SetScript("OnEvent", function()
        if GC.Roster.updatePending then return end
        GC.Roster.updatePending = true
        C_Timer.After(0.20, function()
            GC.Roster.updatePending = false
            local changed = GC.Roster:Rebuild()
            GC.Roster:ConfirmMembership()
            GC.SatelliteStore:Prune()
            if GC.FamilySync then GC.FamilySync:Prune() end
            if changed and frame:IsShown() then GC.RosterDetails:QueueRefresh() end
            GC:RefreshGuildPage()
        end)
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        GC.Roster.pollElapsed = (GC.Roster.pollElapsed or 0) + elapsed
        if GC.Roster.pollElapsed >= 10 then
            GC.Roster.pollElapsed = 0
            GC.Roster:RequestRefresh()
            if GC.Roster:Rebuild() then GC:RefreshGuildPage() end
        end
        if GC.Rating then GC.Rating:Tick() end
    end)
    frame:SetScript("OnHide", function()
        if GC.MemberActions then GC.MemberActions:Close()end
        if GC.StopGeneralSizing then GC.StopGeneralSizing()end
        GC:SaveGeneralSize()
        GC.RosterDetails:ClearOfficerDisplay()
        if frame.StopColumnDrag then frame.StopColumnDrag()end
        GC.Roster.pollElapsed = 0
        if GC.Rating and not(GC.LadderRefresh and GC.LadderRefresh.active)then GC.Rating:Cancel()end
        GC:CloseStatsPanel()
    end)
end

function GC:UpdateMainWindow(geometryOnly)
    local frame = self.MainWindow
    if not frame or not frame:IsShown() then
        return
    end
    if geometryOnly and not self.RosterDetails:CanReadOfficer()then
        self.RosterDetails:ClearOfficerDisplay()
    end

    if not IsInGuild() then
        self:ClearPlayerCharacterFilter(false)
        self.RosterDetails:ClearOfficerDisplay()
        frame.status:SetText(L.NOT_IN_GUILD)
        for _, row in ipairs(frame.rows) do
            row:Hide()
        end
        self:ShowMemberCard(nil)
        return
    end

    local rankCount = self.Filters.CountSelected(self.db.filters.ranks)
    GC.Dropdown.SetText(frame.rankDropdown, rankCount > 0
        and string.format(L.RANK_SELECTED, rankCount) or L.RANK_ALL)
    local classCount = self.Filters.CountSelected(self.db.filters.classes)
    GC.Dropdown.SetText(frame.classDropdown, classCount > 0
        and string.format(L.CLASS_SELECTED, classCount) or L.CLASS_ALL)
    local inactiveDays = tonumber(self.db.filters.inactiveDays) or 0
    GC.Dropdown.SetText(frame.inactivityDropdown, inactiveDays > 0
        and string.format(L.INACTIVE_PREFIX, inactiveDays) or L.INACTIVE_ALL)
    self:UpdatePresentationFilterLabels(frame)
    local mode=self.Permissions:GetModeText()
    local prefix,value=mode:match("^(.-:)%s*(.*)$")
    frame.permissionMode:SetText(prefix and ("|cffffff00"..prefix.."|r |cff40ff40"..value.."|r")or mode)
    frame.satelliteButton:SetEnabled(self.Permissions:CanUseOfficerData())
    frame.guildInvite.gcInviteEnabled=GC.MemberManagement and GC.MemberManagement:CanInvite()or false
    frame.guildInvite:SetEnabled(frame.guildInvite.gcInviteEnabled);frame.guildInvite.PaintGreen(false)
    local leader = self.Reminders and self.Reminders:IsLeader()
    frame.reminderSend:SetShown(leader == true)
    frame.reminderSettings:SetShown(leader == true)

    self:PreparePlayerCharacterFilter()
    local view = geometryOnly and frame.renderedView or self.Filters:BuildView(self.Roster.members, self.db.filters, self.db.sort)
    if not view then return self:UpdateMainWindow()end
    frame.renderedView=view
    self:UpdatePlayerCharacterFilterLabel(frame,#view)
    local visible=frame.visibleRows or VISIBLE_ROWS
    FauxScrollFrame_Update(frame.scroll, #view, visible, ROW_HEIGHT)
    local bar=_G[frame.scroll:GetName().."ScrollBar"]
    local maxOffset=math.max(0,#view-visible)*ROW_HEIGHT
    if bar and bar:GetValue()>maxOffset then bar:SetValue(maxOffset)end
    local offset = FauxScrollFrame_GetOffset(frame.scroll)

    for rowIndex, row in ipairs(frame.rows) do
        local member = view[offset + rowIndex]
        if member and rowIndex<=visible then
            local reuse=geometryOnly and row.member==member
            row.member = member
            if not reuse then
            row.cells[1]:SetText(member.name)
            self:SetRosterClass(row,member)
            row.cells[3]:SetText(member.level)
            row.cells[4]:SetText(member.rank)
            row.cells[5]:SetText(FormatSatellite(member))
            row.cells[6]:SetText(self:RosterFamilyStatus(member))
            row.cells[7]:SetText(FormatLastOnline(member))
            row.cells[8]:SetText(member.zone)
            local public,officer=self.RosterDetails:Notes(member)
            row.cells[9]:SetText(public);row.cells[10]:SetText(officer)
            row.cells[11]:SetText(self.RosterDetails:ProfessionName(member,1))
            row.cells[12]:SetText(self.RosterDetails:ProfessionName(member,2))

            local color = member.classFile and RAID_CLASS_COLORS[member.classFile]
            if not member.online then
                row.cells[1]:SetTextColor(.55,.55,.55)
            elseif color then
                row.cells[1]:SetTextColor(color.r, color.g, color.b)
            else
                row.cells[1]:SetTextColor(1, 1, 1)
            end
            for cellIndex = 2, #row.cells do
                row.cells[cellIndex]:SetTextColor(member.online and 1 or 0.55,
                    member.online and 1 or 0.55, member.online and 1 or 0.55)
            end
            if not member.online then
                for _,cell in ipairs(row.cells)do
                    local text=cell:GetText();if type(text)=="string"then cell:SetText((text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")))end
                end
            end
            end -- unchanged bound rows retain their text during geometry-only work
            row.selection:SetShown(frame.selectedMemberKey == member.key)
            row:Show()
        else
            row.member = nil
            row.cells[9]:SetText("");row.cells[10]:SetText("")
            row.cells[11]:SetText("");row.cells[12]:SetText("")
            row.selection:Hide()
            row:Hide()
        end
    end

    if frame.selectedMemberKey and not geometryOnly then
        local selected = self.Roster:FindByKey(frame.selectedMemberKey)
        if selected then
            self:ShowMemberCard(selected)
        else
            frame.selectedMemberKey = nil
            self:ShowMemberCard(nil)
        end
    end
    local from = tonumber(self.db.filters.minLevel) or 1
    local to = tonumber(self.db.filters.maxLevel) or 110
    if from < 1 or to > 110 or from > to then
        frame.status:SetText(L.LEVEL_INVALID)
    else
        frame.status:SetText(string.format(L.MEMBERS_SHOWN, #view, #self.Roster.members))
    end
end

function GC:OnPermissionsChanged()
    local signature = self.Permissions:GetModeText() .. ":" .. tostring(self.Permissions:CanUseOfficerData())
    if self.lastPermissionSignature == signature then return end
    self.lastPermissionSignature = signature
    if self.MainWindow and self.MainWindow:IsShown() then
        self:UpdateMainWindow()
    end
end
