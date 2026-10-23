local _, GC = ...

local PREFIX = "GC735PERM"
local PROTOCOL = "1"

GC.Permissions = GC.Permissions or {
    canSpeakOfficer = false,
    checkingOfficer = true,
    nonce = nil,
}

local function SafeBoolean(func)
    if type(func) ~= "function" then
        return false
    end
    local ok, value = pcall(func)
    return ok and value and true or false
end

local function PlayerCanonicalName()
    local name, realm = UnitFullName("player")
    if not name then
        name = UnitName("player")
    end
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    if not name or not realm then
        return nil
    end
    return GC.TrustBoundary:CanonicalName(name .. "-" .. realm)
end

function GC.Permissions:RefreshCapabilities()
    self.isLeader = SafeBoolean(IsGuildLeader)
    self.canInvite = SafeBoolean(CanGuildInvite)
    self.canRemove = SafeBoolean(CanGuildRemove)
    self.canPromote = SafeBoolean(CanGuildPromote)
    self.canDemote = SafeBoolean(CanGuildDemote)
    self.canEditMOTD = SafeBoolean(CanEditMOTD)
    self.canEditPublicNote = SafeBoolean(CanEditPublicNote)
    self.canViewOfficerNote = SafeBoolean(CanViewOfficerNote)
    self.canEditOfficerNote = SafeBoolean(CanEditOfficerNote)
    self.canEditGuildInfo = SafeBoolean(CanEditGuildInfo)
    self.canEditGuildEvent = SafeBoolean(CanEditGuildEvent)
    if self.isLeader then
        self.canSpeakOfficer = true
        self.checkingOfficer = false
    end
end

function GC.Permissions:CanUseOfficerData()
    return GC.AdminTrust and GC.AdminTrust:OwnAllowed()or false
end

function GC.Permissions:GetModeText()
 if GC.AdminTrust and GC.AdminTrust:IsLeader() then return GC.L.MODE_LEADER end
 if self:CanUseOfficerData()then return GC.L.MODE_OFFICER end
 return GC.L.MODE_MEMBER
end
function GC.Permissions:NotifyChanged()if GC.OnPermissionsChanged then GC:OnPermissionsChanged()end end
function GC.Permissions:ProbeOfficerSpeak()self:RefreshCapabilities();self:NotifyChanged()end
function GC:InitializePermissions()
 if self.Permissions.initialized then return end
 self.Permissions.initialized=true;self.Permissions:RefreshCapabilities()
 local f=CreateFrame("Frame");self.Permissions.frame=f
 for _,e in ipairs({"PLAYER_GUILD_UPDATE","GUILD_RANKS_UPDATE","GUILD_ROSTER_UPDATE"})do f:RegisterEvent(e)end
 f:SetScript("OnEvent",function()GC.Permissions:RefreshCapabilities();GC.Permissions:NotifyChanged()end)
end
