local _, GC = ...
GC.Filters = GC.Filters or {}

local function Contains(haystack, needle)
    return needle == "" or string.find(string.lower(haystack or ""), needle, 1, true) ~= nil
end

local function CountSelected(selections)
    local count = 0
    if type(selections) == "table" then
        for _, selected in pairs(selections) do
            if selected == true then count = count + 1 end
        end
    end
    return count
end
GC.Filters.CountSelected = CountSelected

function GC.Filters:NormalizeState(state)
    if type(state.ranks) ~= "table" then state.ranks = {} end
    if type(state.classes) ~= "table" then state.classes = {} end
    -- One-time non-destructive migration from 003 single-rank selection.
    if not state.multiRankInitialized then
        if type(state.rank) == "string" and state.rank ~= "" then
            state.ranks[state.rank] = true
        end
        state.multiRankInitialized = true
    end
    if tonumber(state.minLevel) == nil then state.minLevel = 1 end
    if tonumber(state.maxLevel) == nil then state.maxLevel = 110 end
end

function GC.Filters:Matches(member, state)
    state = state or {}
    local search = string.lower(type(state.search) == "string" and state.search or "")
    if search ~= "" and not Contains(member.name, search)
        and not Contains(member.rank, search)
        and not Contains(member.class, search)
        and not Contains(member.zone, search)
        and not (GC.MatchesPresentationSearch and GC:MatchesPresentationSearch(member,search)) then
        return false
    end

    if GC.MatchesPresentationFilters and not GC:MatchesPresentationFilters(member,state) then return false end

    -- Selections within ranks/classes are OR; different filter families are AND.
    local ranks = type(state.ranks) == "table" and state.ranks or nil
    if CountSelected(ranks) > 0 then
        if not ranks[member.rank] then return false end
    elseif not state.multiRankInitialized and state.rank and member.rank ~= state.rank then
        return false
    end
    local classes = type(state.classes) == "table" and state.classes or nil
    if CountSelected(classes) > 0 and not classes[member.classFile] then
        return false
    end
    local low = tonumber(state.minLevel) or 1
    local high = tonumber(state.maxLevel) or 110
    if low < 1 or high > 110 or low > high
        or member.level < low or member.level > high then
        return false
    end
    if state.onlineOnly and not member.online then return false end
    local days = tonumber(state.inactiveDays) or 0
    if days > 0 and (member.online or (tonumber(member.offlineDays) or 0) < days) then
        return false
    end
    return true
end

local function SortValue(member, key)
    if key == "rank" then
        return member.rankIndex
    elseif key == "level" then
        return member.level
    elseif key == "lastOnline" then
        return member.offlineDays
    elseif key == "zone" then
        return string.lower(member.zone or "")
    elseif key == "class"then
        return string.lower(member.classFile or member.class or "")
    elseif key == "family"then
        return GC:RosterFamilyStatus(member)
    elseif key=="note"then
        local public=GC.RosterDetails:Notes(member);return string.lower(public)
    elseif key=="officerNote"then
        local _,officer=GC.RosterDetails:Notes(member);return string.lower(officer)
    elseif key=="profession1"or key=="profession2"then
        return string.lower(GC.RosterDetails:ProfessionName(member,key=="profession1"and 1 or 2))
    elseif key == "satellite" then
        local record = GC.SatelliteStore:Get(member)
        return record and (tonumber(record.receivedAt) or 0) or 0
    end
    return string.lower(member.name or "")
end

function GC.Filters:BuildView(members, filterState, sortState)
    self:NormalizeState(filterState)
    local view = {}
    for _, member in ipairs(members) do
        if self:Matches(member, filterState) then view[#view + 1] = member end
    end
    local key = sortState.key or "name"
    local ascending = sortState.ascending ~= false
    local sortValues={}
    for _,member in ipairs(view)do sortValues[member]=SortValue(member,key)end
    table.sort(view, function(a, b)
        local av, bv = sortValues[a], sortValues[b]
        if av == bv then return string.lower(a.name) < string.lower(b.name) end
        if ascending then return av < bv end
        return av > bv
    end)
    return view
end
