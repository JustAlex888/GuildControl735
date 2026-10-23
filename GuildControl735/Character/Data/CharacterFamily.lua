-- Guild Control Character Family: own account-wide, guild-scoped local state.
-- Identity here is local, not a server-certified WoW-account identifier.
local _, GC = ...
local Satellite = GC.Character
Satellite.Family = Satellite.Family or {}

local MAX_MEMBERS = 12
local MAX_GUILDS = 30
-- Known local characters are retained; migration never expires them.

local function SafeGUID(value)
    return type(value) == "string" and #value >= 6 and #value <= 80
        and value:match("^[%w%-]+$") ~= nil
end

local function SafeName(value)
    return type(value) == "string" and #value > 0 and #value <= 80
        and not value:find("[%z\1-\31\127]")
end

function Satellite.Family:GetGuildKey()
    if not IsInGuild() then return nil end
    local guild = GetGuildInfo and GetGuildInfo("player")
    local realm = GetRealmName and GetRealmName()
    if not SafeName(guild) or not SafeName(realm) then return nil end
    return realm .. "\031" .. guild
end

function Satellite.Family:GetCurrentGUID()
    local guid = UnitGUID and UnitGUID("player")
    return SafeGUID(guid) and guid or nil
end

function Satellite.Family:GetCurrentName()
    local name, realm = UnitFullName("player")
    name = name or UnitName("player")
    realm = realm or (GetRealmName and GetRealmName())
    if not SafeName(name) or not SafeName(realm) then return nil end
    return name .. "-" .. realm:gsub("%s+", "")
end

function Satellite.Family:GetStore()
    local key = self:GetGuildKey()
    if not key or not Satellite.db then return nil end
    if type(Satellite.db.families) ~= "table" then Satellite.db.families = {} end
    local root = Satellite.db.families
    local store = root[key]
    if type(store) ~= "table" then
        local count, oldestKey, oldestTime = 0, nil, nil
        for storedKey, stored in pairs(root) do
            count = count + 1
            local usedAt = type(stored) == "table" and tonumber(stored.lastUsedAt) or 0
            if not oldestTime or usedAt < oldestTime then oldestKey, oldestTime = storedKey, usedAt end
        end
        -- Never silently delete existing guild data: fail closed at capacity.
        if count >= MAX_GUILDS then return nil end
        store = {
            version = 1,
            localID = string.format("%08x%08x", math.random(1, 2147483647), math.random(1, 2147483647)),
            members = {}, primaryGUID = nil, pending = {}, lastUsedAt = time(),
        }
        root[key] = store
    end
    if type(store.members) ~= "table" then store.members = {} end
    if type(store.pending) ~= "table" then store.pending = {} end
    -- This value never leaves this local account's SavedVariables.
    if not SafeName(store.localID) then
        store.localID = string.format("%08x%08x", math.random(1, 2147483647), math.random(1, 2147483647))
    end
    if store.primaryGUID ~= nil and (not SafeGUID(store.primaryGUID) or not store.members[store.primaryGUID]) then
        store.primaryGUID = nil
    end
    store.version = 2
    store.revision = math.max(0, tonumber(store.revision) or 0)
    store.lastUsedAt = time()
    return store
end

function Satellite.Family:RegisterCurrent()
    local guid, name = self:GetCurrentGUID(), self:GetCurrentName()
    local store = self:GetStore()
    if not guid or not name or not store then return nil, "unavailable" end
    local count = 0
    for candidate in pairs(store.members) do
        if SafeGUID(candidate) then count = count + 1 end
    end
    if not store.members[guid] and count >= MAX_MEMBERS then return nil, "capacity" end
    local old = store.members[guid]
    store.members[guid] = type(old) == "table" and old or {}
    store.members[guid].name, store.members[guid].seenAt = name, time()
    return store, guid
end

function Satellite.Family:GetMembers()
    local store = self:RegisterCurrent()
    local members = {}
    if not store then return members end
    for guid, record in pairs(store.members) do
        if SafeGUID(guid) and type(record) == "table" and SafeName(record.name)
            then
            members[#members + 1] = { guid = guid, name = record.name, main = false }
        end
    end
    table.sort(members, function(a, b)
        if a.main ~= b.main then return a.main end
        return a.name < b.name
    end)
    return members
end

function Satellite.Family:GetPrimary()
    local store = self:RegisterCurrent()
    if not store or not store.primaryGUID then return nil end
    local record = store.members[store.primaryGUID]
    if type(record) ~= "table" or not SafeName(record.name) then return nil end
    return store.primaryGUID, record.name
end

function Satellite.Family:SetCurrentMain()
    return false, "officer_note_managed"
end

function Satellite.Family:MarkCurrentAltPending()
    return false, "officer_note_managed"
end

function Satellite.Family:GetCurrentRole()
    local store, guid = self:RegisterCurrent()
    if not store or not guid then return "unavailable" end
    if not store.primaryGUID then
        return store.pending[guid] and "waiting-main" or "not-selected"
    end
    return store.primaryGUID == guid and "main" or "alt"
end

-- Selection may target any already observed local member. The popup captures
-- guild+old+new and revalidates all three to avoid a stale confirmation.
function Satellite.Family:SetPrimary(guid, expectedGuild, expectedOld)
    return false, "officer_note_managed"
end
