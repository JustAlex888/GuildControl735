local _, GC = ...

local function SetBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
end

function GC:InitializeReminderWindow()
    if self.ReminderWindow then return end
    local frame = CreateFrame("Frame", "GuildControl735ReminderWindow", UIParent)
    frame:SetSize(970, 332)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    SetBackdrop(frame)
    frame:Hide()
    self.ReminderWindow = frame
    -- Remember only this window's optional position. No existing SavedVariables
    -- names, guild permissions or Satellite cache are changed.
    local position = self.db and self.db.reminderWindow
    if type(position) ~= "table" then position = nil end
    frame:SetPoint(position and position.point or "CENTER", UIParent,
        position and position.relativePoint or "CENTER",
        position and tonumber(position.x) or 0,
        position and tonumber(position.y) or 0)
    frame:SetScript("OnMouseDown", function(owner, button)
        if button == "LeftButton" then owner:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(owner, button)
        if button ~= "LeftButton" then return end
        owner:StopMovingOrSizing()
        if GC.db then
            local point, _, relativePoint, x, y = owner:GetPoint(1)
            GC.db.reminderWindow = {point = point, relativePoint = relativePoint,
                x = x, y = y}
        end
    end)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -14)
    title:SetText(self.L.REMINDER_SETTINGS)
    self:ApplyFont(title, 17)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 26, -48)
    label:SetText(self.L.REMINDER_DESCRIPTION)
    self:ApplyFont(label, 12)

    -- InputBoxTemplate is a single-line border and its decorative lines were
    -- crossing the second row of actual multi-line input. Use an actual
    -- multi-line EditBox inside a correctly sized framed editor instead.
    local editor = CreateFrame("Frame", nil, frame)
    editor:SetSize(914, 76)
    editor:SetPoint("TOPLEFT", 28, -73)
    editor:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editor:SetBackdropColor(0, 0, 0, 0.82)
    editor:SetBackdropBorderColor(0.62, 0.56, 0.35, 1)

    local edit = CreateFrame("EditBox", nil, editor)
    edit:SetMultiLine(true)
    edit:EnableMouse(true)
    edit:SetAutoFocus(false)
    edit:SetSize(888, 58)
    edit:SetPoint("TOPLEFT", editor, "TOPLEFT", 13, -9)
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
        math.floor(12 * self:GetTextScale() + 0.5))
    frame.edit = edit
    frame.editor = editor

    local counter = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    counter:SetPoint("TOPLEFT", 28, -153)
    self:ApplyFont(counter, 12)
    frame.counter = counter
    edit:SetScript("OnTextChanged", function(owner)
        local bytes = #owner:GetText()
        counter:SetText(string.format(GC.L.REMINDER_BYTES, bytes, 255))
        if bytes > 255 or bytes == 0 then
            counter:SetTextColor(1, 0.3, 0.3)
        else
            counter:SetTextColor(0.5, 0.9, 0.5)
        end
    end)
    edit:SetScript("OnEscapePressed", function(owner) owner:ClearFocus() end)

    local auto = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    auto:SetPoint("TOPLEFT", 25, -181)
    auto.label = auto:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    auto.label:SetPoint("LEFT", auto, "RIGHT", 2, 0)
    auto.label:SetText(self.L.REMINDER_AUTO_24H)
    self:ApplyFont(auto.label, 12)
    frame.auto = auto

    frame.info = {}
    for i = 1, 3 do
        local info = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        info:SetPoint("TOPLEFT", 39, -217 - (i - 1) * 23)
        info:SetWidth(875)
        info:SetHeight(23)
        info:SetJustifyH("LEFT")
        self:ApplyFont(info, 11)
        frame.info[i] = info
    end

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    status:SetPoint("BOTTOMLEFT", 28, 17)
    status:SetWidth(540)
    status:SetJustifyH("LEFT")
    self:ApplyFont(status, 11)
    frame.status = status

    local save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    save:SetSize(160, 30)
    save:SetPoint("BOTTOMRIGHT", -230, 11)
    save:SetText(self.L.REMINDER_SAVE)
    self:ApplyFont(save:GetFontString(), 11)
    save:SetScript("OnClick", function()
        local ok, reason = GC.Reminders:SetMessage(edit:GetText())
        if not ok then
            status:SetText(reason)
            return
        end
        GC.Reminders:SetAutoEnabled(auto:GetChecked())
        status:SetText(GC.L.REMINDER_SAVED)
        GC:RefreshReminderWindowStatus()
    end)

    local send = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    send:SetSize(195, 30)
    send:SetPoint("BOTTOMRIGHT", -24, 11)
    send:SetText(self.L.REMINDER_SEND)
    self:ApplyFont(send:GetFontString(), 11)
    send:SetScript("OnClick", function()
        local ok, reason = GC.Reminders:SetMessage(edit:GetText())
        if not ok then status:SetText(reason); return end
        GC.Reminders:SetAutoEnabled(auto:GetChecked())
        local sent = GC.Reminders:Send(true)
        status:SetText(sent and GC.L.REMINDER_ATTEMPTED or GC.L.REMINDER_NOT_SENT)
        GC:RefreshReminderWindowStatus()
    end)

    frame:SetScript("OnShow", function()
        if not GC.Reminders:IsLeader() then frame:Hide(); return end
        local prefs = GC.Reminders:GetSettings()
        if not prefs then frame:Hide(); return end
        edit:SetText(prefs.message)
        auto:SetChecked(prefs.autoEnabled)
        status:SetText("")
        GC:RefreshReminderWindowStatus()
    end)
end

function GC:OpenReminderWindow()
    if not self.Reminders or not self.Reminders:IsLeader() then
        self:Print(self.L.REMINDER_DENIED)
        return
    end
    self:InitializeReminderWindow()
    self.ReminderWindow:Show()
end

function GC:RefreshReminderWindowStatus()
    local frame = self.ReminderWindow
    if not frame or not frame.info or not self.Reminders then return end
    local state = self.Reminders:GetStatus()
    if not state then return end
    local L = self.L
    frame.info[1]:SetText(L.REMINDER_AUTO_LABEL .. ": " ..
        (state.autoEnabled and L.REMINDER_STATUS_ENABLED or L.REMINDER_STATUS_DISABLED))
    local last = state.lastSentAt > 0 and date("%d.%m.%Y %H:%M", state.lastSentAt)
        or L.REMINDER_STATUS_NEVER
    local source = state.lastSentKind == "manual" and L.REMINDER_SOURCE_MANUAL
        or state.lastSentKind == "auto" and L.REMINDER_SOURCE_AUTO
        or L.REMINDER_SOURCE_UNKNOWN
    frame.info[2]:SetText(L.REMINDER_LAST_LABEL .. ": " .. last .. " (" .. source .. ")")
    local nextText
    if not state.autoEnabled then
        nextText = L.REMINDER_NEXT_DISABLED
    elseif state.secondsRemaining > 0 then
        nextText = string.format(L.REMINDER_NEXT_LATER,
            date("%d.%m.%Y %H:%M", state.nextAutoEligibleAt))
    else
        nextText = L.REMINDER_NEXT_LOGIN
    end
    local reason = state.lastAutoReason == "cooldown" and L.REMINDER_SKIP_COOLDOWN
        or state.lastAutoReason == "invalid" and L.REMINDER_SKIP_INVALID
        or state.lastAutoReason == "chat-error" and L.REMINDER_SKIP_CHAT
        or nil
    if reason and state.autoEnabled then nextText = nextText .. " · " .. reason end
    frame.info[3]:SetText(L.REMINDER_NEXT_LABEL .. ": " .. nextText)
end
