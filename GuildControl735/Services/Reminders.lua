local _, GC = ...
GC.Reminders = GC.Reminders or {}

local MAX_BYTES = 255
local AUTO_INTERVAL = 24 * 60 * 60
local MANUAL_INTERVAL = 60

local function IsLeader()
    if not IsInGuild() or type(IsGuildLeader) ~= "function" then return false end
    local ok, value = pcall(IsGuildLeader)
    return ok and value and true or false
end

function GC.Reminders:GetSettings()
    if not GC.db then return nil end
    local guildKey = GC:GetGuildKey()
    if not guildKey then return nil end
    if type(GC.db.reminders) ~= "table" then GC.db.reminders = {} end
    local root = GC.db.reminders
    if type(root.guilds) ~= "table" then root.guilds = {} end
    local prefs = root.guilds[guildKey]
    if type(prefs) ~= "table" then
        prefs = {}
        root.guilds[guildKey] = prefs
    end
    if type(prefs.message) ~= "string" or #prefs.message == 0 or #prefs.message > MAX_BYTES then
        prefs.message = GC.L.REMINDER_DEFAULT
    end
    prefs.autoEnabled = prefs.autoEnabled == true
    if prefs.lastSentKind ~= "manual" and prefs.lastSentKind ~= "auto" then
        prefs.lastSentKind = nil -- historical sends have an unknown origin
    end
    if type(prefs.lastAutoReason) ~= "string" or #prefs.lastAutoReason > 40 then
        prefs.lastAutoReason = nil
    end
    local check = tonumber(prefs.lastAutoCheckAt)
    prefs.lastAutoCheckAt = check and check > 0 and check <= time() and check or nil
    local when = tonumber(prefs.lastSentAt)
    prefs.lastSentAt = when and when > 0 and when <= time() and when or 0
    return prefs
end

function GC.Reminders:IsLeader()
    return IsLeader()
end

function GC.Reminders:SetMessage(value)
    if not IsLeader() then return false, GC.L.REMINDER_DENIED end
    if type(value) ~= "string" or #value == 0 or #value > MAX_BYTES
        or string.find(value, "[%z\1-\31\127]") then
        return false, GC.L.REMINDER_INVALID
    end
    local prefs = self:GetSettings()
    if not prefs then return false, GC.L.NOT_IN_GUILD end
    prefs.message = value
    return true
end

function GC.Reminders:SetAutoEnabled(enabled)
    if not IsLeader() then return false, GC.L.REMINDER_DENIED end
    local prefs = self:GetSettings()
    if not prefs then return false, GC.L.NOT_IN_GUILD end
    prefs.autoEnabled = enabled == true
    return true
end

function GC.Reminders:GetStatus()
    local prefs = self:GetSettings()
    if not prefs then return nil end
    local now = time()
    local lastSent = tonumber(prefs.lastSentAt) or 0
    return {
        autoEnabled = prefs.autoEnabled == true,
        lastSentAt = lastSent,
        lastSentKind = prefs.lastSentKind,
        nextAutoEligibleAt = lastSent > 0 and lastSent + AUTO_INTERVAL or 0,
        lastAutoCheckAt = prefs.lastAutoCheckAt,
        lastAutoReason = prefs.lastAutoReason,
        secondsRemaining = lastSent > 0 and math.max(0, lastSent + AUTO_INTERVAL - now) or 0,
    }
end

function GC.Reminders:Send(manual)
    if not IsLeader() then
        if manual then GC:Print(GC.L.REMINDER_DENIED) end
        return false, "permission"
    end
    if type(SendChatMessage) ~= "function" then return false, "chat-unavailable" end
    local prefs = self:GetSettings()
    if not prefs then return false, "no-guild" end
    if not manual and not prefs.autoEnabled then
        prefs.lastAutoCheckAt = time()
        prefs.lastAutoReason = "auto-disabled"
        return false, "auto-disabled"
    end
    local now = time()
    local function ReportAuto(reason)
        if not manual then
            prefs.lastAutoCheckAt = now
            prefs.lastAutoReason = reason
            if GC.RefreshReminderWindowStatus then GC:RefreshReminderWindowStatus() end
        end
    end
    local cooldown = manual and MANUAL_INTERVAL or AUTO_INTERVAL
    if prefs.lastSentAt > 0 and now - prefs.lastSentAt < cooldown then
        if manual then GC:Print(GC.L.REMINDER_COOLDOWN) end
        ReportAuto("cooldown")
        return false, "cooldown"
    end
    local msg = prefs.message
    if type(msg) ~= "string" or #msg > MAX_BYTES or #msg == 0
        or string.find(msg, "[%z\1-\31\127]") then
        if manual then GC:Print(GC.L.REMINDER_INVALID) end
        ReportAuto("invalid")
        return false, "invalid"
    end
    -- A chat API call is not a server delivery acknowledgement.
    local ok = pcall(SendChatMessage, msg, "GUILD")
    if not ok then
        if manual then GC:Print(GC.L.REMINDER_FAILED) end
        ReportAuto("chat-error")
        return false, "chat-error"
    end
    prefs.lastSentAt = now
    prefs.lastSentKind = manual and "manual" or "auto"
    ReportAuto("sent-to-channel")
    if manual then GC:Print(GC.L.REMINDER_ATTEMPTED) end
    return true
end

function GC:InitializeReminders()
    if self.Reminders.initialized then return end
    self.Reminders.initialized = true
    -- Wait until PLAYER_LOGIN and roster/permissions have had time to settle.
    -- Auto mode is deliberately OFF by default; no outgoing chat in a fresh install.
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(10, function()
            if GC.Reminders then GC.Reminders:Send(false) end
        end)
    end
end
