-- Internal card page adapter; registered by the shared startup lifecycle.
local _, GC = ...
local S = GC.Character
function S:AttachShell()
    local host=_G.GuildControl735ShellWindow
    if not host or not host.AttachSatellite or not self.MainWindow then return false end
    if self.shellHost==host then return true end
    local f=self.MainWindow
    S:UpdateMainWindow()
    local page={width=780,height=f:GetHeight(),
        Init=function(_,owner,header)
            f:Hide();f:SetParent(owner);f:ClearAllPoints();f:SetPoint("TOPLEFT",owner,"TOPLEFT",0,-header)
            f:SetBackdrop(nil);f.close:Hide()
            f:SetMovable(false);f:SetClampedToScreen(false);f:SetFrameStrata("DIALOG")
            f:SetScript("OnMouseDown",function(_,b)local fn=owner:GetScript("OnMouseDown");if fn then fn(owner,b)end end)
            f:SetScript("OnMouseUp",function()local fn=owner:GetScript("OnMouseUp");if fn then fn(owner)end end)
            f.close:SetScript("OnClick",function()owner:Hide()end)
        end,
        Show=function()f:Show()end,
        Hide=function()f:Hide();if GC.Dropdown.Close then GC.Dropdown.Close()end end}
    if not host:AttachSatellite(page)then return false end
    self.shellHost=host
    host.GetOwnRaidSnapshot=function(refresh)
        if refresh then S.RaidRuntime:Collect()end
        return S.RaidRuntime:Get(UnitGUID("player"))
    end
    if UISpecialFrames then
        for i=#UISpecialFrames,1,-1 do if UISpecialFrames[i]=="GuildControl735SatelliteWindow"then table.remove(UISpecialFrames,i)end end
    end
    return true
end
