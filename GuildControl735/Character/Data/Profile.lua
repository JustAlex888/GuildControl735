local _, GC = ...
local Satellite = GC.Character

Satellite.Profile = Satellite.Profile or {}

local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local validRoles = { TANK = true, HEALER = true, DAMAGER = true }
local MAX_PROFILES = 4

function Satellite.Profile:GetCharacterKey()
    local name, realm = UnitFullName("player")
    name = name or UnitName("player") or "Unknown"
    realm = realm or GetRealmName() or ""
    return name .. "-" .. realm
end

function Satellite.Profile:GetCharacterStore()
    if not Satellite.db then
        return nil
    end
    Satellite.db.characters = type(Satellite.db.characters) == "table"
        and Satellite.db.characters or {}
    local key = self:GetCharacterKey()
    local store = type(Satellite.db.characters[key]) == "table"
        and Satellite.db.characters[key] or { profiles = {} }
    store.profiles = type(store.profiles) == "table" and store.profiles or {}
    Satellite.db.characters[key] = store
    return store
end

function Satellite.Profile:ReadCurrent()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then
        return nil
    end
    local specID, specName, _, _, role = GetSpecializationInfo(specIndex)
    if not specID or not role then
        return nil
    end
    local _, equipped = GetAverageItemLevel()
    if not equipped or equipped < 1 or equipped > 2000 then
        return nil
    end
    return {
        guid = UnitGUID("player") or "",
        specID = tonumber(specID),
        specName = specName or "",
        role = role,
        itemLevel = tonumber(equipped),
        reportedAt = time(),
    }
end

function Satellite.Profile:SaveCurrent()
    local profile = self:ReadCurrent()
    local store = self:GetCharacterStore()
    if not profile or not store then
        return nil
    end
    store.guid = profile.guid
    store.lastSaved = profile.reportedAt
    store.listRevision = math.max((tonumber(store.listRevision) or 0)+1,time()*1000)
    local profileCount = 0
    for _ in pairs(store.profiles) do
        profileCount = profileCount + 1
    end
    if not store.profiles[tostring(profile.specID)] and profileCount >= MAX_PROFILES then
        local oldestKey, oldestTime
        for key, saved in pairs(store.profiles) do
            local savedAt = tonumber(saved.reportedAt) or 0
            if not oldestTime or savedAt < oldestTime then
                oldestKey, oldestTime = key, savedAt
            end
        end
        if oldestKey then
            store.profiles[oldestKey] = nil
        end
    end
    store.profiles[tostring(profile.specID)] = profile
    return profile
end

function Satellite.Profile:GetProfiles()
    local store = self:GetCharacterStore()
    local profiles = {}
    if not store then
        return profiles
    end
    local clean = {}
    for _, profile in pairs(store.profiles) do
        local specID = type(profile) == "table" and tonumber(profile.specID)
        local itemLevel = type(profile) == "table" and tonumber(profile.itemLevel)
        local reportedAt = type(profile) == "table" and tonumber(profile.reportedAt)
        if specID and specID > 0 and specID <= 100000 and validRoles[profile.role]
            and itemLevel and itemLevel >= 1 and itemLevel <= 2000 and reportedAt then
            profile.guid = string.sub(tostring(profile.guid or store.guid or ""), 1, 80)
            profile.specID = specID
            profile.itemLevel = itemLevel
            profile.reportedAt = reportedAt
            clean[tostring(specID)] = profile
            profiles[#profiles + 1] = profile
        end
    end
    store.profiles = clean
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

function Satellite.Profile:MarkChannelSent()
    local store = self:GetCharacterStore()
    if store then
        store.lastChannelSentAt = time()
    end
end

function Satellite.Profile:GetLastChannelSentAt()
    local store = self:GetCharacterStore()
    return store and tonumber(store.lastChannelSentAt) or nil
end
