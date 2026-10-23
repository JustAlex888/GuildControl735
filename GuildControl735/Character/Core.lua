local addonName, GC = ...
local Satellite = GC.Character

Satellite.name = addonName
Satellite.version = "0.0.102"
-- Compact compatibility version required by the existing GC735SAT v1 schema.
Satellite.wireVersion = "021"
Satellite.build = "GuildControl735-0.0.102-20261023-01"

local defaults = {
    window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    minimap = { angle = 305, hidden = false },
    ui = { textScale = 1.20 },
    schemaVersion = 2,
    characters = {},
    families = {},
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

function Satellite:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff5fcde4Guild Control 735:|r " .. tostring(message))
end

Satellite.fontTargets = Satellite.fontTargets or {}

function Satellite:GetTextScale()
    -- Ignore but retain legacy saved scale for reversible rollback.
    return 1.20
end

function Satellite:ApplyFont(fontString, baseSize, flags)
    if not fontString or not fontString.SetFont then
        return
    end
    self.fontTargets[fontString] = { size = baseSize, flags = flags }
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fontString:SetFont(font, math.floor((baseSize or 12) * self:GetTextScale() + 0.5), flags or "")
end

function Satellite:RefreshFonts()
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local scale = self:GetTextScale()
    for target, settings in pairs(self.fontTargets) do
        if target and target.SetFont then
            target:SetFont(font, math.floor(settings.size * scale + 0.5), settings.flags or "")
        end
    end
end

function Satellite:CycleTextScale()
    if not self.db then
        return
    end
    self:RefreshFonts()
    if self.UpdateMainWindow then
        self:UpdateMainWindow()
    end
end

function Satellite:ShowMyCard()
    if self:AttachShell()then self.shellHost:OpenPage("satellite");return end
    if self.MainWindow then self.MainWindow:Show()end
end
function Satellite:Toggle()
    if self:AttachShell()then self.shellHost:ToggleSatellite();return end
    if self.MainWindow then self.MainWindow:SetShown(not self.MainWindow:IsShown())end
end

function Satellite:InitializeData(root)
    root.character = type(root.character)=="table" and root.character or {}
    CopyDefaults(root.character, defaults)
    self.db=root.character
end
function Satellite:Initialize()
    self:InitializeProtocol()
    self:InitializeFamilyProtocol()
    self.Family:RegisterCurrent()
    self:InitializeMainWindow()
    self:AttachShell()
    local frame=CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:SetScript("OnEvent",function()Satellite.Family:RegisterCurrent()end)
end

SLASH_GUILDCONTROL735SATELLITE1 = "/gcs"
SLASH_GUILDCONTROL735SATELLITE2 = "/gcsatellite"
SlashCmdList.GUILDCONTROL735SATELLITE = function(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if command == "version" then
        Satellite:Print("0.0.102 TEST / " .. Satellite.build)
    elseif command == "raids" then
        Satellite.RaidRuntime:Collect()
        Satellite:Print((GC:Text("Собственная рейдовая статистика обновлена локально. Передача — по запросу Guild Control.")))
    elseif command == "minimap" then
        -- Legacy command alias for the single Guild Control launcher.
        if SlashCmdList and type(SlashCmdList.GUILDCONTROL735) == "function" then
            SlashCmdList.GUILDCONTROL735("minimap")
        end
    elseif command == "family" then
        Satellite:OpenFamilyWindow()
    elseif command == "show" then
        Satellite:ShowMyCard()
    elseif command == "scale" then
        Satellite:CycleTextScale()
        Satellite:Print(string.format(Satellite.L.SCALE_CHANGED,
            math.floor(Satellite:GetTextScale() * 100 + 0.5)))
    else
        Satellite:Toggle()
    end
end
