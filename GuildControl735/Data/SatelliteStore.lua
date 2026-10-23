local _, GC = ...

GC.SatelliteStore = GC.SatelliteStore or {}

local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local validRoles = { TANK = true, HEALER = true, DAMAGER = true }
local MAX_PROFILES = 4
local MAX_MEMBERS = 1000
-- Current guild members are retained irrespective of offline duration.

local function EnsureDatabase()
    if not GC.db then
        return nil
    end
    GC.db.guilds = type(GC.db.guilds) == "table" and GC.db.guilds or {}
    local guildKey = GC:GetGuildKey()
    if not guildKey then
        return nil
    end
    local guild = GC.db.guilds[guildKey]
    if type(guild) ~= "table" then
        guild = {}
        GC.db.guilds[guildKey] = guild
    end
    if type(guild.satellite) ~= "table" then
        guild.satellite = {}
    end
    local database = guild.satellite
    database.protocol = 1
    database.listWatermarks = type(database.listWatermarks)=="table" and database.listWatermarks or {}
    database.members = type(database.members) == "table" and database.members or {}
    database.security = type(database.security) == "table" and database.security or {}
    database.security.accepted = tonumber(database.security.accepted) or 0
    database.security.rejected = tonumber(database.security.rejected) or 0
    database.security.rateLimited = tonumber(database.security.rateLimited) or 0
    database.security.replays = tonumber(database.security.replays) or 0

    if not GC.db.migration002SatelliteDone and type(GC.db.satellite) == "table"
        and type(GC.db.satellite.members) == "table" then
        for key, record in pairs(GC.db.satellite.members) do
            if type(key) == "string" and type(record) == "table"
                and database.members[key] == nil then
                database.members[key] = record
            end
        end
        GC.db.migration002SatelliteDone = true
    end
    return database
end

local function SanitizeProfile(profile)
    if type(profile) ~= "table" then
        return nil
    end
    local specID = tonumber(profile.specID)
    local itemLevel = tonumber(profile.itemLevel)
    local reportedAt = tonumber(profile.reportedAt)
    local receivedAt = tonumber(profile.receivedAt)
    if not specID or specID <= 0 or specID > 100000 or not validRoles[profile.role]
        or not itemLevel or itemLevel < 1 or itemLevel > 2000
        or not reportedAt or not receivedAt then
        return nil
    end
    return {
        specID = specID,
        role = profile.role,
        itemLevel = itemLevel,
        reportedAt = reportedAt,
        receivedAt = receivedAt,
        source = profile.source=="TRUSTED_CACHE_RELAY"and"TRUSTED_CACHE_RELAY"or"SATELLITE_SELF_REPORT",
        trust = profile.source=="TRUSTED_CACHE_RELAY"and"UNVERIFIED_RELAY"or"UNVERIFIED_SELF_REPORT",
    }
end

local function SanitizeRecord(record)
    if type(record) ~= "table" or type(record.guid) ~= "string" or record.guid == ""
        or type(record.name) ~= "string" or record.name == "" then
        return nil
    end
    local result = {
        guid = string.sub(record.guid, 1, 80),
        name = string.sub(record.name, 1, 80),
        sender = string.sub(tostring(record.sender or ""), 1, 80),
        addonVersion = string.sub(tostring(record.addonVersion or ""), 1, 8),
        reportedAt = tonumber(record.reportedAt) or 0,
        receivedAt = tonumber(record.receivedAt) or 0,
        installed = record.installed and true or false,
        listRevision = tonumber(record.listRevision),
        listDigest = record.listDigest,
        profiles = {},
        source = "SATELLITE_SELF_REPORT",
        trust = "UNVERIFIED_SELF_REPORT",
    }
    local count = 0
    if type(record.profiles) == "table" then
        for _, profile in pairs(record.profiles) do
            local clean = SanitizeProfile(profile)
            if clean and count < MAX_PROFILES then
                result.profiles[tostring(clean.specID)] = clean
                count = count + 1
            end
        end
    end
    return result
end

function GC.SatelliteStore:Initialize()
    local database = EnsureDatabase()
    if not database then
        return
    end
    local cleanMembers = {}
    local count = 0
    for _, record in pairs(database.members) do
        local clean = SanitizeRecord(record)
        if clean and count < MAX_MEMBERS then
            cleanMembers[clean.guid] = clean
            count = count + 1
        end
    end
    database.members = cleanMembers
    self:Prune()
end

function GC.SatelliteStore:Get(member)
    local database = EnsureDatabase()
    if not database or not member or not member.guid then
        return nil
    end
    return database.members[member.guid]
end

function GC.SatelliteStore:MarkInstalled(member, sender, addonVersion, reportedAt)
    local database = EnsureDatabase()
    if not database or not member or not member.guid then
        return nil
    end
    local record = database.members[member.guid] or { profiles = {} }
    record.guid = member.guid
    record.name = string.sub(member.name or "", 1, 80)
    record.sender = string.sub(sender or "", 1, 80)
    record.addonVersion = string.sub(addonVersion or "", 1, 8)
    record.reportedAt = tonumber(reportedAt) or 0
    record.receivedAt = time()
    record.installed = true
    record.source = "SATELLITE_SELF_REPORT"
    record.trust = "UNVERIFIED_SELF_REPORT"
    record.profiles = type(record.profiles) == "table" and record.profiles or {}
    database.members[member.guid] = record
    return record
end

local function OldestProfileKey(profiles)
    local oldestKey, oldestTime
    for key, profile in pairs(profiles) do
        local value = tonumber(profile.receivedAt) or 0
        if not oldestTime or value < oldestTime then
            oldestKey, oldestTime = key, value
        end
    end
    return oldestKey
end

function GC.SatelliteStore:SaveProfile(member, sender, addonVersion, specID, role,
        itemLevel, reportedAt)
    local previous=self:Get(member)
    local db=EnsureDatabase()
    if (previous and previous.listRevision) or (db and db.listWatermarks[member.guid]) then return nil end
    local record = self:MarkInstalled(member, sender, addonVersion, reportedAt)
    if not record then
        return nil
    end
    local key = tostring(specID)
    local count = 0
    for _ in pairs(record.profiles) do
        count = count + 1
    end
    if not record.profiles[key] and count >= MAX_PROFILES then
        local oldest = OldestProfileKey(record.profiles)
        if oldest then
            record.profiles[oldest] = nil
        end
    end
    record.profiles[key] = {
        specID = tonumber(specID),
        role = role,
        itemLevel = tonumber(itemLevel),
        reportedAt = tonumber(reportedAt) or 0,
        receivedAt = time(),
        source = "SATELLITE_SELF_REPORT",
        trust = "UNVERIFIED_SELF_REPORT",
    }
    return record.profiles[key]
end

function GC.SatelliteStore:GetProfiles(member)
    local record = self:Get(member)
    local profiles = {}
    if not record or type(record.profiles) ~= "table" then
        return profiles
    end
    for _, profile in pairs(record.profiles) do
        local clean = SanitizeProfile(profile)
        if clean then
            profiles[#profiles + 1] = clean
        end
    end
    table.sort(profiles, function(a, b)
        local ar = roleOrder[a.role] or 99
        local br = roleOrder[b.role] or 99
        if ar == br then
            return (tonumber(a.specID) or 0) < (tonumber(b.specID) or 0)
        end
        return ar < br
    end)
    return profiles
end

function GC.SatelliteStore:RecordResult(kind, reason)
    local database = EnsureDatabase()
    if not database then
        return
    end
    local security = database.security
    if kind == "accepted" then
        security.accepted = security.accepted + 1
    elseif kind == "rate" then
        security.rateLimited = security.rateLimited + 1
    elseif kind == "replay" then
        security.replays = security.replays + 1
    else
        security.rejected = security.rejected + 1
        security.lastReason = string.sub(tostring(reason or "unknown"), 1, 40)
    end
end

function GC.SatelliteStore:Prune()
    -- No age eviction. Only confirmed membership can delete guild records.
    if GC.GuildCache then return GC.GuildCache:Prune() end
end
