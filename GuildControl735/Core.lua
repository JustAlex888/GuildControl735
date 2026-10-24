local addonName, GC = ...

GC.Character = {}
GC.DevTools = {}
GC.name = addonName
GC.version = "0.0.103"
-- Compact compatibility version required by the existing GC735SAT v1 schema.
GC.wireVersion = "021"
GC.build = "GuildControl735-0.0.103-20261023-01"

local defaults = {
    window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    minimap = { angle = 215, hidden = false },
    ui = { textScale = 1.20 },
    filters = { search = "", rank = nil, ranks = {}, classes = {}, multiRankInitialized = false,
        minLevel = 1, maxLevel = 110, inactiveDays = 0, onlineOnly = false },
    reminders = { guilds = {} },
    sort = { key = "name", ascending = true },
    schemaVersion = 2,
    guilds = {},
    networkSpam = { enabled = true, guilds = {}, runs = {} },
}

local function CopyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- Only presentation preferences are character-owned. All service/data keys
-- continue to resolve to the unchanged account store; this facade is runtime only.
local personalKeys={window=true,minimap=true,ui=true,filters=true,sort=true,floatingButton=true,reminderWindow=true}
local personalDefaults={
 window={point='CENTER',relativePoint='CENTER',x=0,y=0},
 minimap={angle=215,hidden=false},floatingButton={size=44,hidden=false},
 filters={search='',ranks={},classes={},multiRankInitialized=false,minLevel=1,maxLevel=110,inactiveDays=0,onlineOnly=false},
 sort={key='name',ascending=true},reminderWindow={},
 ui={textScale=1.20,generalWindow={width=1120,height=490}},
}
function GC:BindPersonalSettings(root,guid)
 if type(root)~='table'or type(guid)~='string'or not guid:match('^Player%-%x+%-%x+$')then return false end
 root.personalSettings=type(root.personalSettings)=='table'and root.personalSettings or{schema=1,characters={}}
 local store=root.personalSettings
 store.characters=type(store.characters)=='table'and store.characters or{}
 local record=store.characters[guid]
 if type(record)~='table'then record={schema=1,settings={}};store.characters[guid]=record end
 record.settings=type(record.settings)=='table'and record.settings or{}
 CopyDefaults(record.settings,personalDefaults)
 record.name=UnitName('player');self.accountDB=root;self.personalSettings=record.settings;self.personalGUID=guid
 local settings=record.settings
 self.db=setmetatable({},{__index=function(_,k)if personalKeys[k]then return settings[k]else return root[k]end end,
  __newindex=function(_,k,v)if personalKeys[k]then settings[k]=v else root[k]=v end end})
 return true
end

function GC:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff5fcde4Guild Control 735 for UWoW Legion:|r " .. tostring(message))
end

GC.fontTargets = GC.fontTargets or {}

function GC:GetTextScale()
    -- Legacy saved values remain available for rollback, but never drive UI.
    return 1.20
end

function GC:ApplyFont(fontString, baseSize, flags)
    if not fontString or not fontString.SetFont then
        return
    end
    self.fontTargets[fontString] = { size = baseSize, flags = flags }
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fontString:SetFont(font, math.floor((baseSize or 12) * self:GetTextScale() + 0.5), flags or "")
end

function GC:RefreshFonts()
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local scale = self:GetTextScale()
    for target, settings in pairs(self.fontTargets) do
        if target and target.SetFont then
            target:SetFont(font, math.floor(settings.size * scale + 0.5), settings.flags or "")
        end
    end
    if self.MainWindow and self.MainWindow.search then
        self.MainWindow.search:SetFont(font, math.floor(13 * scale + 0.5))
    end
    if self.ReminderWindow and self.ReminderWindow.edit then
        self.ReminderWindow.edit:SetFont(font, math.floor(12 * scale + 0.5))
    end
end

-- Legacy slash/API alias: fixed size, no setting mutation or cycling.
function GC:CycleTextScale()
    self:RefreshFonts()
end

function GC:GetGuildKey()
    if not IsInGuild() then
        return nil
    end
    local guildName = GetGuildInfo("player")
    local realm = GetRealmName() or ""
    if not guildName or guildName == "" then
        return nil
    end
    return realm .. "\031" .. guildName
end

function GC:OpenMyCard()
    if not self.ShellWindow then return false end
    self.Shell:Open("satellite");return true
end
function GC:Toggle()
    if not self.ShellWindow then return end
    if self.ShellWindow:IsShown()and self.Shell.activePage~="general"then
        self.Shell:Open("general")
    else self.Shell:Toggle()end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if GC.disabled then return end
    if event == "ADDON_LOADED" and arg1 == addonName then
        GuildControl735DB = GuildControl735DB or {}
        CopyDefaults(GuildControl735DB, defaults)
        GC.db = GuildControl735DB
        GC:InitializeLanguage(GC.db)
        if IsAddOnLoaded and IsAddOnLoaded("GuildControlTrojan")then GC.disabled=true;GC:Print((GC:Text("Отключите GuildControlTrojan на этом персонаже и выполните /reload.")));return end
        GC.Diagnostics:Initialize(GC.db)
        GC.Character:InitializeData(GC.db)
    elseif event == "PLAYER_LOGIN" then
        if IsAddOnLoaded and IsAddOnLoaded("GuildControlTrojan")then GC.disabled=true;GC:Print((GC:Text("Включите только один вариант Guild Control на этом персонаже.")));return end
        if not GC:BindPersonalSettings(GuildControl735DB,UnitGUID('player'))then GC:Print((GC:Text('Не удалось определить персонажа. Выполните /reload.')));return end
        GC.Diagnostics:Record("PLAYER_LOGIN", "initialization.begin")
        if GC.Roster then
            GC.Roster:RequestRefresh()
            GC.Roster:Rebuild()
        end
        if GC.Diagnostics.SetObserver then GC.Diagnostics:SetObserver()end
        GC.SpamShield:Initialize()
        if GC.SatelliteStore and GC.SatelliteStore.Initialize then
            GC.SatelliteStore:Initialize()
        end
        GC:InitializeAdminTrust()
        if GC.InitializePermissions then
            GC:InitializePermissions()
        end
        if GC.InitializeSatelliteProtocol then
            GC:InitializeSatelliteProtocol()
        end
        if GC.InitializeReminders then
            GC:InitializeReminders()
        end
        if GC.InitializeFamilySync then
            GC:InitializeFamilySync()
        end
        GC:InitializeShell()
        if GC.InitializeMainWindow then
            GC:InitializeMainWindow()
        end
        GC:InitializePages()
        GC:InitializeMassRoster()
        GC.RaidRuntime.unified=true
        GC.RaidRuntime:Initialize(true)
        GC.Character.RaidRuntime=GC.RaidRuntime
        GC.Character:Initialize()
        GC:InitializeRaidUI()
        GC:InitializeAdminTrustUI()
        GC:InitializeDataExchange()
        GC:InitializeVersionCheck()
        GC:InitializeSecureExchange()
        GC.AutoSurvey:Initialize()
        if GC.InitializeMinimapButton then
            GC:InitializeMinimapButton()
        end
        if GC.InitializeFloatingButton then GC:InitializeFloatingButton() end
    end
end)

-- /gc is reserved by Blizzard guild-chat parsing before addon dispatch.
SLASH_GUILDCONTROL7351 = "/gc735"
SLASH_GUILDCONTROL7352 = "/guildcontrol"
SlashCmdList.GUILDCONTROL735 = function(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
    GC.Diagnostics:Record("COMMAND", command:match("^%S+") or "toggle")
    if command == "language"or command:match("^language%s")then GC:LanguageCommand(command:match("^language%s*(.-)%s*$"))
    elseif command == "auth" then GC:ShowAuthorizationStatus()
    elseif command == "security" then GC:SecurityStatus()
    elseif command == "trust" then GC.Shell:Open("settings")
    elseif command == "log" then GC.Diagnostics:Show()
    elseif command == "netstop" then GC.DataExchange:Stop();GC:Print((GC:Text("Сбор и локальная очередь остановлены.")))
    elseif command == "netlog" then GC.SpamShield:Show()
    elseif command == "netreset" then GC.SpamShield:ResetMeasurement();GC:Print((GC:Text("Новый сетевой замер начат; журнал нарушений сохранён.")))
    elseif command == "unblock" then
        local key=GC.MainWindow and GC.MainWindow.selectedMemberKey
        local m=key and GC.Roster:FindByKey(key)
        GC:Print(m and GC.SpamShield:Unblock(m.name) and (GC:Text("Локальная блокировка выбранного персонажа снята.")) or (GC:Text("Не удалось снять блокировку: выберите персонажа; требуется глава гильдии.")))
    elseif command == "version" then
        GC:Print("0.0.103 TEST / " .. GC.build)
    elseif command == "raidtest" or command == "raidtest storm" then
        GC.RaidTest:Start("storm")
    elseif command == "raidtest loss" then GC.RaidTest:Start("loss")
    elseif command == "raidtest duplicate" then GC.RaidTest:Start("duplicate")
    elseif command == "raidtest stop" then GC.RaidTest:Stop()
    elseif command == "raidtest report" then GC.RaidTest:Report()
    elseif command == "raids" then GC:OpenRaidOwn()
    elseif command == "minimap" then
        if GC.ToggleMinimapButton then
            GC:ToggleMinimapButton()
        end
    elseif command == "button" then
        GC:ToggleFloatingButton()
    elseif command == "button reset" then
        GC:ResetFloatingButton()
    elseif command == "card" or command == "vizitka" then
        GC:OpenMyCard()
    elseif command == "remind" then
        if GC.Reminders then GC.Reminders:Send(true) end
    elseif command == "reminder" then
        if GC.OpenReminderWindow then GC:OpenReminderWindow() end
    elseif command == "scale" then
        GC:CycleTextScale()
        GC:Print(string.format(GC.L.SCALE_CHANGED, math.floor(GC:GetTextScale() * 100 + 0.5)))
    else
        GC:Toggle()
    end
end
