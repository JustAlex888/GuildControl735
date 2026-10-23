-- Private, single-level selectors. No Blizzard dropdown pool or protected frames.
local _, GC = ...
local D = { active = nil }
GC.Dropdown = D
local VISIBLE, HEIGHT = 12, 24

function D.Close()
    local owner = D.active
    D.active = nil
    if owner then owner.menu:Hide(); owner.dismiss:Hide() end
end
function D.CreateInfo() return {} end
function D.AddButton(info)
    local owner = D.building
    assert(owner, "private selector builder required")
    owner.items[#owner.items + 1] = info
end
function D.Initialize(owner, builder) owner.builder = builder end
function D.SetWidth(owner, width) owner:SetWidth(width + 32) end
function D.SetText(owner, text) owner:SetText(text) end

local function Build(owner)
    owner.items = {}
    D.building = owner
    local ok, err = pcall(owner.builder, owner, 1)
    D.building = nil
    if not ok then D.Close(); error(err) end
    owner.offset = math.min(owner.offset or 0, math.max(0, #owner.items - VISIBLE))
end
local function Render(owner)
    local count = math.min(VISIBLE, #owner.items)
    owner.menu:SetSize(math.max(owner:GetWidth() + 30, owner.minimumMenuWidth or 0), math.max(1, count) * HEIGHT + 20)
    for i, row in ipairs(owner.rows) do
        local item = owner.items[i + owner.offset]
        row.item = item
        if item then
            local checked = item.checked
            if type(checked) == "function" then checked = checked() end
            row:SetEnabled(not item.disabled)
            row:SetText((checked and (item.checkmark and "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t "or "|cff50df70* |r")or "   ") .. (item.text or ""))
            row:Show()
        else row:Hide() end
    end
    owner.hint:SetText(#owner.items > VISIBLE and (GC:Text("Колесо мыши: прокрутка")) or "")
end
function D.Open(owner)
    if D.active == owner then D.Close(); return end
    D.Close()
    if not owner.builder then return end
    D.active = owner; owner.offset = 0
    Build(owner); Render(owner)
    owner.dismiss:Show(); owner.menu:Show()
end
function D.Create(name, parent)
    local owner = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    owner:SetHeight(28)
    local label = owner:GetFontString()
    label:SetWordWrap(false)
    -- Preserve the addon's existing named text handle, never a Blizzard handle.
    if name then _G[name .. "Text"] = label end
    owner.dismiss = CreateFrame("Button", nil, UIParent)
    owner.dismiss:SetAllPoints(UIParent); owner.dismiss:SetFrameStrata("FULLSCREEN_DIALOG")
    owner.dismiss:SetFrameLevel(100); owner.dismiss:EnableMouse(true)
    owner.dismiss:SetScript("OnClick", D.Close); owner.dismiss:Hide()
    local menu = CreateFrame("Frame", nil, owner)
    owner.menu = menu; owner.rows = {}
    menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetFrameLevel(101)
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0); menu:SetClampedToScreen(true)
    menu:EnableMouse(true); menu:EnableMouseWheel(true)
    local bg = menu:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    bg:SetColorTexture(.04, .07, .09, 1)
    owner.hint = menu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    owner.hint:SetPoint("BOTTOM", 0, 3)
    for i = 1, VISIBLE do
        local row = CreateFrame("Button", nil, menu)
        row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * HEIGHT)
        row:SetPoint("RIGHT", menu, "RIGHT", -4, 0); row:SetHeight(HEIGHT)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", 3, 0); text:SetPoint("RIGHT", -3, 0)
        text:SetJustifyH("LEFT"); text:SetWordWrap(false); row:SetFontString(text)
        GC:ApplyFont(text, 11)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:SetScript("OnClick", function(button)
            local item = button.item
            if not item or item.disabled then return end
            if item.func then item.func() end
            if D.active == owner then
                if item.keepShownOnClick then Build(owner); Render(owner) else D.Close() end
            end
        end)
        owner.rows[i] = row
    end
    menu:SetScript("OnMouseWheel", function(_, delta)
        owner.offset = math.max(0, math.min(math.max(0, #owner.items - VISIBLE), owner.offset - delta))
        Render(owner)
    end)
    menu:EnableKeyboard(true)
    menu:SetPropagateKeyboardInput(true)
    menu:SetScript("OnKeyDown", function(frame, key)
        frame:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then D.Close() end
    end)
    menu:Hide()
    owner:SetScript("OnClick", function() D.Open(owner) end)
    owner:HookScript("OnHide", function() if D.active == owner then D.Close() end end)
    return owner
end
