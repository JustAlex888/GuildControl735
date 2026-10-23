-- UWoW manual Mythic adapter bound to observed CRC/framing; fail closed on runtime drift.
local _,GC=...
GC.Rating={active=nil,lastRequest=nil,serial=0,states={},stateReasons={},runtime=nil}
local R=GC.Rating
R.BASELINE_CRC=1367320996
R.labels=GC:RegisterLocaleTable({},function()return {never=(GC:Text("Не запрашивалось")),pending=(GC:Text("Запрос выполняется")),empty=(GC:Text("Нет данных")),error=(GC:Text("Ошибка")),stale=(GC:Text("Данные устарели")),unavailable=(GC:Text("Источник недоступен")),fresh="UWoW/server"} end)
function R:SetState(key,value,reason)
    if not self.states[key] then
        local count=0;for _ in pairs(self.states) do count=count+1 end
        if count>=200 then local victim=next(self.states);self.states[victim]=nil;self.stateReasons[victim]=nil end
    end
    self.states[key]=value;self.stateReasons[key]=reason
    if reason and GC.Diagnostics then GC.Diagnostics:Record("RATING_STATE",value.." reason="..tostring(reason))end
end
function R:Gate()
    if not self.runtime then
        local ok,why=self:BindUWoW();if not ok then return false,why or "source_unbound"end
    end
    local a=self.runtime
    if type(a)~="table" or a.module~="aio_rating_tables" or a.crc~=self.BASELINE_CRC
        or a.schema~=1 or a.verifiedBinding~=true or type(a.request)~="function"then return false,"source_incompatible"end
    if a.isLive then return GC.UWoWMythic:Available()end
    return true
end
function R:Database()
    local key=GC:GetGuildKey();if not key or not GC.db then return nil end
    GC.db.ratingCache=GC.db.ratingCache or {version=1,guilds={}}
    local root=GC.db.ratingCache.guilds
    if not root[key] then
        local n=0;for _ in pairs(root)do n=n+1 end;if n>=30 then return nil end
        root[key]={}
    end
    local db=root[key]
    for guid,v in pairs(db)do if type(v)~="table" or type(v.updatedAt)~="number" or false then db[guid]=nil end end
    return db
end
function R:Cached(member)
    if not member or not GC.db then return nil end
    local root=GC.db.ratingCache;local guilds=type(root)=="table"and root.guilds
    local db=type(guilds)=="table"and guilds[GC:GetGuildKey()]
    local record=type(db)=="table"and db[member.guid]
    if type(record)=="table"and type(record.updatedAt)=="number"and record.guid==member.guid then return record end
end
function R:Status(member)
    if not member then return "never" end
    self:Tick()
    local key=GC:GetGuildKey();local sk=tostring(key)..":"..tostring(member.guid)
    if self.active and self.active.guid==member.guid and self.active.guild==key then return "pending" end
    local db=self:Database();local record=db and db[member.guid]
    local status=self.states[sk]
    if status=="error" or status=="empty" or status=="unavailable" then return status,record,self.stateReasons[sk] end
    if record then return time()-record.updatedAt>3600 and "stale" or "fresh",record end
    return self.states[sk] or "never"
end
function R:Cancel(reason)
    if GC.UWoWMythic then GC.UWoWMythic:Cancel(true) end
    if self.active then
        self:SetState(self.active.guild..":"..self.active.guid,"error",reason or "cancelled")
        self.active=nil;self.serial=self.serial+1
    end
end
function R:Tick()
    local a=self.active
    if a and (a.guild~=GC:GetGuildKey() or GetTime()-a.started>15 or GetTime()<a.started
        or not GC.Roster:FindByKey(a.guid)) then self:Cancel(a.guild~=GC:GetGuildKey()and"context_changed"or"timeout")end
end
function R:Request(member)
    self:Tick()
    if not member or not GC.FamilyCodec.GUID(member.guid) or not GC:GetGuildKey() or not GC.Roster:FindByKey(member.guid) then return false,"selection" end
    if self.active then return false,"busy" end
    local key=GC:GetGuildKey();local ok,reason=self:Gate()
    if not ok then self:SetState(key..":"..member.guid,"unavailable",reason);return false,reason end
    if self.runtime.isLive then
        local number,realm=GC.UWoWMythic:Resolve(member)
        if not number then self:SetState(key..":"..member.guid,"unavailable",realm);return false,realm end
        local ready,why=GC.UWoWMythic:CanStart(key,member.guid,-2)
        if not ready then return false,why end
    end
    self.serial=self.serial+1;local id=self.serial
    self.lastRequest=GetTime();self.active={id=id,guid=member.guid,guild=key,started=GetTime()}
    self:SetState(key..":"..member.guid,"pending")
    -- Adapter callback carries correlation and completed full semantic response.
    local sent,accepted,why=pcall(self.runtime.request,member.guid,key,function(data,err)
        self:Complete(id,member.guid,key,data,err)
    end)
    if not sent or accepted==false then
        local failure=sent and why or "request_failed";self:Cancel(failure)
        self:SetState(key..":"..member.guid,"error",failure);return false,failure
    end
    return true
end
local function Number(v,max,integer)
    return type(v)=="number" and v==v and v>=0 and v<=max and (not integer or v%1==0)
end
function R:Complete(id,guid,guild,data,err)
    self:Tick();local a=self.active
    if not a or a.id~=id or a.guid~=guid or a.guild~=guild or guild~=GC:GetGuildKey() then return false,"correlation" end
    self.active=nil
    local stateKey=guild..":"..guid
    if err or type(data)~="table" or data.guid~=guid then self:SetState(stateKey,"error",err or "data");return false,err or "data" end
    if data.empty==true then local db=self:Database();if db then db[guid]=nil end;self:SetState(stateKey,"empty");return true end
    local clean={guid=guid,source="UWoW/server",updatedAt=time(),bracket="MYTHIC_PLUS"}
    local found=false
    for _,field in ipairs({"rating","rank","tank","heal","dps","bestKey","totalRuns"})do
        if data[field]~=nil then
            if not Number(data[field],field=="bestKey" and 1000 or 100000000,field=="bestKey" or field=="rank" or field=="totalRuns") then self:SetState(stateKey,"error");return false,"number" end
            clean[field]=data[field];found=true
        end
    end
    if data.ranges~=nil then
        if type(data.ranges)~="table" then self:SetState(stateKey,"error");return false,"ranges" end
        clean.ranges={}
        for _,k in ipairs({"2-4","5-9","10-14","15-19","20-24","25-29","30-34","35+"})do
            if data.ranges[k]~=nil then
                if not Number(data.ranges[k],100000000,true) then self:SetState(stateKey,"error");return false,"range" end
                clean.ranges[k]=data.ranges[k];found=true
            end
        end
    end
    if not found then local db=self:Database();if db then db[guid]=nil end;self:SetState(stateKey,"empty");return true end
    local db=self:Database();if not db then self:SetState(stateKey,"error");return false,"guild-cap" end
    local n=0;for _ in pairs(db)do n=n+1 end
    if not db[guid] and n>=1000 then return false,"storage-capacity" end
    db[guid]=clean;self.states[stateKey]=nil;self.stateReasons[stateKey]=nil
    if GC.UpdateStats then GC:UpdateStats(GC.Roster:FindByKey(GC.MemberCard and GC.MemberCard.memberKey))end
    return true
end
