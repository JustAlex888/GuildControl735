local _, GC = ...

local RADIUS = 81
local DEFAULT_ANGLE = 215
local function Preferences()
    if not GC.db then return nil end
    local p = GC.db.minimap
    if type(p) ~= "table" then
        p = {}
        GC.db.minimap = p
    end
    local a = tonumber(p.angle)
    if not a or a ~= a or a < -36000 or a > 36000 then a = DEFAULT_ANGLE end
    p.angle = a % 360
    p.hidden = p.hidden == true
    return p
end

local function CursorAngle()
    if not Minimap or not Minimap.GetCenter or not GetCursorPosition then return nil end
    local cx, cy = Minimap:GetCenter()
    local x, y = GetCursorPosition()
    if not cx or not cy or not x or not y then return nil end
    local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1
    if not scale or scale <= 0 then return nil end
    local dx, dy = x / scale - cx, y / scale - cy
    if dx == 0 and dy == 0 then return nil end
    local a
    if math.atan2 then
        a = math.atan2(dy, dx)
    elseif dx == 0 then
        a = dy > 0 and math.pi / 2 or -math.pi / 2
    else
        a = math.atan(dy / dx)
        if dx < 0 then a = a + math.pi end
    end
    return (math.deg(a) + 360) % 360
end

function GC:PositionMinimapButton()
    local button = self.MinimapButton
    local settings = Preferences()
    if not button or not settings or not Minimap then return end
    local a = math.rad(settings.angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", RADIUS * math.cos(a), RADIUS * math.sin(a))
end

function GC:InitializeMinimapButton()
    if self.MinimapButton or not Minimap or not Preferences() then return end
    local b = CreateFrame("Button", "GuildControl735MinimapButton", Minimap)
    self.MinimapButton = b
    b:SetSize(31, 31)
    b:SetFrameStrata("HIGH")
    if Minimap.GetFrameLevel and b.SetFrameLevel then
        b:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    end
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    b.background = background

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(19, 19)
    icon:SetPoint("CENTER", background, "CENTER")
    icon:SetTexture("Interface\\AddOns\\GuildControl735\\Textures\\GuildShieldG.tga")
    icon:SetTexCoord(0, 1, 0, 1)
    b.icon = icon

    local rim = b:CreateTexture(nil, "OVERLAY")
    rim:SetSize(53, 53)
    rim:SetPoint("TOPLEFT", b, "TOPLEFT")
    rim:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.border = rim

    b:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
        GameTooltip:AddLine("Guild Control 7.3.5", 1, 0.82, 0)
        GameTooltip:AddLine(GC.L.MINIMAP_TOOLTIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(owner, mouse)
        -- Avoid opening either window when a left drag is released.
        local now = GetTime and GetTime() or 0
        if owner.dragging or (owner.dragFinished and now - owner.dragFinished < 0.16) then return end
        if mouse == "LeftButton" then
            GC:Toggle()
        elseif mouse == "RightButton" then
            GC:OpenMyCard()
        end
    end)
    b:SetScript("OnDragStart", function(owner)
        owner.dragging = true
        GameTooltip:Hide()
        owner:SetScript("OnUpdate", function()
            local angle = CursorAngle()
            local settings = Preferences()
            if angle and settings then
                settings.angle = angle
                GC:PositionMinimapButton()
            end
        end)
    end)
    b:SetScript("OnDragStop", function(owner)
        owner.dragging = false
        owner:SetScript("OnUpdate", nil)
        owner.dragFinished = GetTime and GetTime() or 0
    end)

    self:PositionMinimapButton()
    b:SetShown(not Preferences().hidden)
end

function GC:ToggleMinimapButton()
    local p = Preferences()
    if not p then return end
    if not self.MinimapButton then self:InitializeMinimapButton() end
    p.hidden = not p.hidden
    if self.MinimapButton then self.MinimapButton:SetShown(not p.hidden) end
    self:Print(p.hidden and self.L.MINIMAP_HIDDEN or self.L.MINIMAP_SHOWN)
end
