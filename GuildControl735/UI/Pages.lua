-- Page adapters preserve the existing view, state, subscriptions and services.
local _,GC=...
local function StaticPage(title,body,width,height)
    return {width=width,height=height,
        Init=function(self,host,header)
            local f=CreateFrame("Frame",nil,host);self.frame=f;f:SetSize(width,height);f:SetPoint("TOPLEFT",host,"TOPLEFT",0,-header)
            local t=f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge");t:SetPoint("TOPLEFT",28,-28);t:SetText(title);GC:ApplyFont(t,18)
            local text=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");text:SetPoint("TOPLEFT",28,-72);text:SetText(body);GC:ApplyFont(text,14)
        end,
        Show=function(self)self.frame:Show()end,
        Hide=function(self)self.frame:Hide()end}
end
function GC:InitializePages()
    local H=self.Shell
    H:Register("general",{width=1350,height=760,
        Show=function()GC.MainWindow:Show();GC:LayoutGeneral(GC.ShellWindow:GetWidth(),GC.ShellWindow:GetHeight())end,
        Hide=function()
            GC.MainWindow:Hide()
            if GC.ReminderWindow then GC.ReminderWindow:Hide()end
            if GC.Dropdown.Close then GC.Dropdown.Close()end
        end})
    local analytics=GC.MythicAnalytics:CreatePage()
    H:Register("analytics",analytics)
    H:Register("security",self:CreateNetworkSecurityPage())
    H:Select("general")
end
