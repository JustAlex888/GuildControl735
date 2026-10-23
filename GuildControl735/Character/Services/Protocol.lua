local _, GC = ...
local Satellite = GC.Character

local PREFIX = "GC735SAT"
local PROTOCOL = "1"

Satellite.Protocol = Satellite.Protocol or { requesters = {} }

local function CanonicalSender(sender)
    if type(sender) ~= "string" or sender == "" or #sender > 80
        or string.find(sender, "[%z\1-\31\127]") then
        return nil
    end
    local name, realm = string.match(sender, "^([^-]+)%-(.+)$")
    if not name then
        name, realm = sender, GetRealmName() or ""
    end
    realm = string.gsub(realm or "", "%s+", "")
    if name == "" or realm == "" then
        return nil
    end
    return string.lower(name .. "-" .. realm)
end

function Satellite:PublishProfile(profile, delay, guard)
    if not profile or not profile.guid or profile.guid == "" or not IsInGuild() then
        return false
    end
    local key=GC:GetGuildKey()
    C_Timer.After(delay or 0, function()
        if key==GC:GetGuildKey() and IsInGuild() and (not guard or guard()) then
            GC.ProfileList:Publish(guard)
            if Satellite.UpdateMainWindow and Satellite.MainWindow
                and Satellite.MainWindow:IsShown() then
                Satellite:UpdateMainWindow()
            end
        end
    end)
    return true
end

function Satellite:PublishCurrent()
    if not IsInGuild() then
        self:Print(self.L.NOT_IN_GUILD)
        return false
    end
    local profile = self.Profile:SaveCurrent()
    if not profile then
        self:Print(self.L.NO_SPECIALIZATION)
        return false
    end
    local queued=GC.ProfileList:Publish()
    -- Family links use their own bounded opt-in protocol. The equipment
    -- profile list is published atomically through GC735LIST.
    if self.PublishFamilyLinks then self:PublishFamilyLinks(false) end
    self:Print(queued and (GC:Text("Список сохранён и поставлен в очередь отправки.")) or (GC:Text("Комплект сохранён локально. Передача будет по разрешённому запросу доверенного персонажа.")))
    if self.UpdateMainWindow then
        self:UpdateMainWindow()
    end
    return true
end

function Satellite:PublishSavedProfiles(requester)
    local key=GC:GetGuildKey()
    local guard=requester and function()return key==GC:GetGuildKey()and GC.AdminTrust and GC.AdminTrust:Allowed(requester)end or nil
    local delay = math.random(0, 120) / 10
    C_Timer.After(delay,function()
        if not guard or guard() then GC.ProfileList:Publish(guard) end
    end)
end

function Satellite:InitializeProtocol()
    if self.Protocol.initialized then
        return
    end
    if not RegisterAddonMessagePrefix or not SendAddonMessage or not C_Timer
        or not C_Timer.After then
        self:Print("Satellite protocol is unavailable in this client.")
        return
    end

    RegisterAddonMessagePrefix(PREFIX)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
        if prefix~=PREFIX or channel~="GUILD"then return end
        if GC.SpamShield and GC.SpamShield:IsBlocked(sender)then return end
        if not GC.SecureExchange.dispatch then return end
        if prefix ~= PREFIX or channel ~= "GUILD" or type(message) ~= "string" then
            return
        end
        if #message > 32 then
            return
        end
        local version = string.match(message, "^REQ|" .. PROTOCOL .. "|(%d%d%d)$")
        local requester = CanonicalSender(sender)
        if not version or not requester then
            return
        end
        if not GC.AdminTrust or not GC.AdminTrust:Allowed(sender)then return end
        local now = time()
        if Satellite.Protocol.lastResponse and now-Satellite.Protocol.lastResponse<30 then return end
        local previous = Satellite.Protocol.requesters[requester] or 0
        if now - previous < 30 then
            return
        end
        Satellite.Protocol.requesters[requester] = now
        local requesterCount = 0
        for name, requestedAt in pairs(Satellite.Protocol.requesters) do
            requesterCount = requesterCount + 1
            if now - requestedAt > 3600 or requesterCount > 1000 then
                Satellite.Protocol.requesters[name] = nil
            end
        end
        Satellite.Protocol.lastResponse=now
        Satellite:PublishSavedProfiles(sender)
    end)

    self.Protocol.frame = frame
    self.Protocol.initialized = true
end
