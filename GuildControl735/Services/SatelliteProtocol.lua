local _, GC = ...

local PREFIX = "GC735SAT"
local PROTOCOL = "1"

GC.SatelliteProtocol = GC.SatelliteProtocol or {}

local function NotifyUpdated(member)
    if GC.OnSatelliteDataUpdated then
        GC:OnSatelliteDataUpdated(member)
    end
end

local function Reject(kind, reason)
    GC.SatelliteStore:RecordResult(kind or "rejected", reason)
end

local function HandleMessage(message, sender)
    if GC.SpamShield and GC.SpamShield:IsBlocked(sender)then return false end
    return GC.SecureExchange:Reject("legacy_satellite_disabled",sender)
end

local function HistoricalHandleMessage(message, sender)
    if not GC.Permissions:CanUseOfficerData() then
        return
    end

    local fields = GC.TrustBoundary:Split(message)
    if not fields or fields[2] ~= PROTOCOL then
        Reject("rejected", "schema")
        return
    end
    local command = fields[1]
    if command ~= "HELLO" and command ~= "PUB" then
        Reject("rejected", "command")
        return
    end

    local allowed, rateReason = GC.TrustBoundary:CheckRate(sender, command)
    if not allowed then
        Reject("rate", rateReason)
        return
    end
    if GC.TrustBoundary:IsReplay(sender, message) then
        Reject("replay", "duplicate")
        return
    end

    if command == "HELLO" then
        local data, reason = GC.TrustBoundary:ValidateHello(fields, sender)
        if not data then
            Reject("rejected", reason)
            return
        end
        GC.SatelliteStore:MarkInstalled(data.member, sender, data.addonVersion,
            data.reportedAt)
        GC.SatelliteStore:RecordResult("accepted")
        NotifyUpdated(data.member)
    else
        local data, reason = GC.TrustBoundary:ValidateProfile(fields, sender)
        if not data then
            Reject("rejected", reason)
            return
        end
        local saved=GC.SatelliteStore:SaveProfile(data.member, sender, data.addonVersion,
            data.specID, data.role, data.itemLevel, data.reportedAt)
        if not saved then Reject("replay","superseded_by_full_list");return end
        GC.SatelliteStore:RecordResult("accepted")
        NotifyUpdated(data.member)
    end
end

function GC:InitializeSatelliteProtocol()
    if self.SatelliteProtocol.initialized then
        return
    end
    if not RegisterAddonMessagePrefix or not SendAddonMessage then
        self:Print("Satellite protocol is unavailable in this client.")
        return
    end

    RegisterAddonMessagePrefix(PREFIX)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
        if prefix ~= PREFIX or channel ~= "GUILD" or type(message) ~= "string" then
            return
        end
        HandleMessage(message, sender)
    end)

    self.SatelliteProtocol.frame = frame
    self.SatelliteProtocol.initialized = true
end

function GC:RequestSatelliteData()
    if not IsInGuild() or not SendAddonMessage then
        return false
    end
    self.Permissions:RefreshCapabilities()
    if not self.AdminTrust:OwnAllowed() then
        self:Print(self.L.REQUEST_DENIED)
        return false
    end
    if self.DataExchange then return self:RequestAllData() end
    do return false end
    self:Print(self.L.REQUEST_SENT)
    return true
end

