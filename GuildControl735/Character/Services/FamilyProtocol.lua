local _, GC = ...
local S = GC.Character
S.FamilyProtocol={generation=0}
function S:PublishFamilyLinks()
    if not GC.SecureExchange:Valid(GC.SecureExchange.grant) then return false,"no_trusted_session"end
    if not self.FamilyProtocol.initialized or not IsInGuild() then return false,"unavailable" end
    local store,guid=self.Family:RegisterCurrent();if not store then return false,"unavailable" end
    local now=time();if store.lastFamilyPublishAt and now-store.lastFamilyPublishAt<30 then return false,"cooldown" end
    local guild=self.Family:GetGuildKey();local rev=math.max(0,tonumber(store.revision) or 0)+1
    local packets=self.FamilyCodec.Encode(guild,guid,nil,self.Family:GetMembers(),rev,now)
    if not packets then return false,"format" end
    store.revision=rev;store.lastFamilyPublishAt=now;self.FamilyProtocol.generation=self.FamilyProtocol.generation+1
    local generation=self.FamilyProtocol.generation
    for i,p in ipairs(packets) do
        local packet=p
        C_Timer.After((i-1)*0.20,function()
            if generation==S.FamilyProtocol.generation and IsInGuild() and S.Family:GetGuildKey()==guild
                and S.Family:GetCurrentGUID()==guid and store.revision==rev then GC.SecureExchange:Send("GC735FAM",packet) end
        end)
    end
    return true,#packets
end
function S:InitializeFamilyProtocol()
    if self.FamilyProtocol.initialized then return end
    if type(RegisterAddonMessagePrefix)~="function" or type(SendAddonMessage)~="function"
        or not C_Timer or type(C_Timer.After)~="function" then return end
    RegisterAddonMessagePrefix("GC735FAM");self.FamilyProtocol.initialized=true
end
