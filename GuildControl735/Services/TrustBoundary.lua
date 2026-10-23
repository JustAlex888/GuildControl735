local _, GC = ...

GC.TrustBoundary = GC.TrustBoundary or {
    senderWindows = {},
    commandTimes = {},
    replays = {},
}

local MAX_MESSAGE_LENGTH = 220
local MAX_FIELDS = 8
local WINDOW_SECONDS = 10
local MAX_MESSAGES_PER_WINDOW = 12
local REPLAY_SECONDS = 60
local MAX_REPLAY_KEYS = 240
local MAX_PROFILE_AGE = 180 * 24 * 60 * 60
local MAX_FUTURE_SKEW = 5 * 60

local function NowPrecise()
    return GetTime and GetTime() or time()
end

local function RealmKey(value)
    value = tostring(value or "")
    value = string.gsub(value, "%s+", "")
    return string.lower(value)
end

function GC.TrustBoundary:CanonicalName(name)
    if type(name) ~= "string" or name == "" or #name > 80 then
        return nil
    end
    if string.find(name, "[%z\1-\31\127]") then
        return nil
    end
    local character, realm = string.match(name, "^([^-]+)%-(.+)$")
    if not character then
        character = name
        realm = GetRealmName() or ""
    end
    if character == "" or realm == "" then
        return nil
    end
    return string.lower(character) .. "-" .. RealmKey(realm)
end

function GC.TrustBoundary:Split(message)
    if type(message) ~= "string" or #message == 0 or #message > MAX_MESSAGE_LENGTH
        or string.find(message, "[%z\1-\31\127]") then
        return nil
    end
    local result = {}
    local startIndex = 1
    while true do
        if #result >= MAX_FIELDS then
            return nil
        end
        local delimiter = string.find(message, "|", startIndex, true)
        if not delimiter then
            result[#result + 1] = string.sub(message, startIndex)
            break
        end
        result[#result + 1] = string.sub(message, startIndex, delimiter - 1)
        startIndex = delimiter + 1
    end
    return result
end

function GC.TrustBoundary:CheckRate(sender, command)
    local canonical = self:CanonicalName(sender)
    if not canonical then
        return false, "sender"
    end
    local now = NowPrecise()
    local window = self.senderWindows[canonical]
    if not window or now - window.started >= WINDOW_SECONDS then
        window = { started = now, count = 0 }
        self.senderWindows[canonical] = window
    end
    window.count = window.count + 1
    if window.count > MAX_MESSAGES_PER_WINDOW then
        return false, "rate"
    end

    local commandKey = canonical .. "\031" .. tostring(command or "")
    local previous = self.commandTimes[commandKey] or 0
    self.commandTimes[commandKey] = now
    if now - previous < 0.20 then
        return false, "command_rate"
    end
    return true
end

function GC.TrustBoundary:IsReplay(sender, message)
    local now = NowPrecise()
    local key = tostring(sender or "") .. "\031" .. message
    local previous = self.replays[key]
    self.replays[key] = now
    if previous and now - previous <= REPLAY_SECONDS then
        return true
    end

    local count = 0
    for replayKey, seenAt in pairs(self.replays) do
        count = count + 1
        if now - seenAt > REPLAY_SECONDS or count > MAX_REPLAY_KEYS then
            self.replays[replayKey] = nil
        end
    end
    return false
end

function GC.TrustBoundary:ResolveSelfReport(sender, claimedGUID)
    if type(claimedGUID) ~= "string" or claimedGUID == "" or #claimedGUID > 80
        or not string.match(claimedGUID, "^Player%-%x+%-%x+$") then
        return nil, "guid"
    end
    if #GC.Roster.members == 0 then
        GC.Roster:Rebuild()
    end
    local member = GC.Roster:FindBySender(sender)
    if not member or not member.guid or member.guid ~= claimedGUID then
        return nil, "identity"
    end
    return member
end

function GC.TrustBoundary:ValidTimestamp(value)
    local timestamp = tonumber(value)
    local now = time()
    return timestamp and timestamp >= now - MAX_PROFILE_AGE
        and timestamp <= now + MAX_FUTURE_SKEW and timestamp or nil
end

function GC.TrustBoundary:ValidateHello(fields, sender)
    if #fields ~= 5 or fields[1] ~= "HELLO" or fields[2] ~= "1" then
        return nil, "schema"
    end
    local addonVersion = fields[3]
    if not string.match(addonVersion or "", "^%d%d%d$") then
        return nil, "version"
    end
    local member, reason = self:ResolveSelfReport(sender, fields[4])
    local reportedAt = self:ValidTimestamp(fields[5])
    if not member or not reportedAt then
        return nil, reason or "timestamp"
    end
    return {
        member = member,
        addonVersion = addonVersion,
        reportedAt = reportedAt,
    }
end

function GC.TrustBoundary:ValidateProfile(fields, sender)
    if #fields ~= 8 or fields[1] ~= "PUB" or fields[2] ~= "1" then
        return nil, "schema"
    end
    local addonVersion = fields[3]
    local specID = tonumber(fields[5])
    local role = fields[6]
    local itemLevelRaw = tonumber(fields[7])
    local reportedAt = self:ValidTimestamp(fields[8])
    local member, reason = self:ResolveSelfReport(sender, fields[4])
    if not string.match(addonVersion or "", "^%d%d%d$") then
        return nil, "version"
    end
    if not member or not specID or specID <= 0 or specID > 100000
        or not ({ TANK = true, HEALER = true, DAMAGER = true })[role]
        or not itemLevelRaw or itemLevelRaw < 100 or itemLevelRaw > 200000
        or not reportedAt then
        return nil, reason or "payload"
    end
    if GetSpecializationInfoByID then
        local _, specName = GetSpecializationInfoByID(specID)
        if not specName or specName == "" then
            return nil, "specialization"
        end
    end
    return {
        member = member,
        addonVersion = addonVersion,
        specID = specID,
        role = role,
        itemLevel = itemLevelRaw / 100,
        reportedAt = reportedAt,
    }
end

