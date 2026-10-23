local _, GC = ...

GC.Roster = GC.Roster or { members = {}, ranks = {} }

local function OfflineDays(index, online)
    if online then
        return -1
    end
    local years, months, days, hours = GetGuildRosterLastOnline(index)
    years = tonumber(years) or 0
    months = tonumber(months) or 0
    days = tonumber(days) or 0
    hours = tonumber(hours) or 0
    return years * 365 + months * 30 + days + (hours / 24)
end

local function BaseName(name)
    return string.match(name or "", "^([^-]+)") or (name or "")
end

function GC.Roster:Rebuild()
    local old = self.members
    self.members = {}
    self.ranks = {}

    if not IsInGuild() then
        self.lastGuildKey = nil
        return #old > 0
    end

    local rankSeen = {}
    local total = GetNumGuildMembers(true)
    for index = 1, total do
        local name, rank, rankIndex, level, class, zone, note, officerNote,
            online, status, classFile, achievementPoints, achievementRank,
            isMobile, canSoR, reputation, guid = GetGuildRosterInfo(index)

        if name then
            local member = {
                index = index,
                name = name,
                baseName = BaseName(name),
                rank = rank or "",
                rankIndex = tonumber(rankIndex) or 99,
                level = tonumber(level) or 0,
                class = class or "",
                classFile = classFile,
                zone = zone or "",
                note = note or "",
                -- Officer note text is read locally on demand by RosterDetails.
                -- Never retain it on shared member objects.
                online = online and true or false,
                status = status,
                achievementPoints = tonumber(achievementPoints) or 0,
                achievementRank = tonumber(achievementRank) or 0,
                isMobile = isMobile and true or false,
                reputation = tonumber(reputation) or 0,
                guid = guid,
            }
            member.fullName = GC.TrustBoundary and GC.TrustBoundary:CanonicalName(name) or name
            member.offlineDays = OfflineDays(index, member.online)
            member.key = member.guid or member.name
            self.members[#self.members + 1] = member

            if member.rank ~= "" and not rankSeen[member.rank] then
                rankSeen[member.rank] = true
                self.ranks[#self.ranks + 1] = {
                    name = member.rank,
                    index = member.rankIndex,
                }
            end
        end
    end

    local changed = self.lastGuildKey ~= GC:GetGuildKey() or #old ~= #self.members
    self.lastGuildKey = GC:GetGuildKey()
    if not changed then
        for i, member in ipairs(self.members) do
            for key, value in pairs(member) do if old[i][key] ~= value then changed = true; break end end
            if changed then break end
        end
    end
    self.changed = changed
    table.sort(self.ranks, function(a, b)
        if a.index == b.index then
            return a.name < b.name
        end
        return a.index < b.index
    end)
    return changed
end

function GC.Roster:FindBySender(sender)
    if not sender then
        return nil
    end
    local canonical = GC.TrustBoundary and GC.TrustBoundary:CanonicalName(sender) or sender
    if not canonical then
        return nil
    end
    for _, member in ipairs(self.members) do
        if member.fullName == canonical then
            return member
        end
    end
    return nil
end

function GC.Roster:FindByKey(key)
    for _, member in ipairs(self.members) do
        if member.key == key or member.guid == key or member.name == key then
            return member
        end
    end
    return nil
end

function GC.Roster:RequestRefresh()
    local clock = GetTime()
    if IsInGuild() and (not self.lastRequest or clock < self.lastRequest or clock - self.lastRequest >= 3) then
        self.lastRequest = clock
        GuildRoster()
        return true
    end
    return false
end
