-- Independently authored adapter for the observed read-only UWoW protocol.
-- No dynamic server Lua copied, executed or modified on disk.
local _,GC=...
GC.UWoWMythic={active=nil,unresolved={},generation=0}
local U=GC.UWoWMythic
local realms={uwowcn=2,epicx1=7,uwowaplus=16,uwowa=24,["х7"]=29,
    legionplusx1=44,x100plusseason=64,uwowx100=67,uwowfun=72,legionx5=88,
    testuwow=69,testepic=10,legionplustest=1}
local function NumericGUID(guid)
    if type(guid)~="string" then return nil end
    local realm,hex=guid:match("^Player%-(%d+)%-([%x]+)$")
    if not realm or #hex>13 then return nil end
    local n=tonumber(hex,16)
    if not n or n<1 or n>4503599627370495 then return nil end
    return n,realm
end
-- Canonical AIO realm IDs; aliases below were observed in this project's client.
-- No rating/bracket presence, GUID-as-realm guessing or fuzzy suffix matching.
realms.plusx1=44
realms["legion plus x1 [proxy ru]"]=44
local function RealmID(name)
    return type(name)=="string" and realms[name:lower()] or nil
end
function U:Available(category)
    local meta=type(AIO_sv_Addons)=="table" and AIO_sv_Addons.aio_rating_tables
    if type(meta)~="table" or type(AIO)~="table" then return false,"aio_not_loaded" end
    if meta.name~="aio_rating_tables" or tonumber(meta.crc)~=1367320996 then return false,"aio_incompatible" end
    local ladder=_G.LadderFrame
    if not ladder then return false,"ratings_not_loaded" end
    if type(ladder)~="table" then return false,"ratings_incompatible" end
    if type(ladder.CreatePlayerMythicPlusStatistic)~="function" then return false,"ratings_incompatible" end
    if category=="pvp" and type(ladder.CreatePlayerPvPStatistic)~="function" then return false,"pvp_not_loaded" end
    if type(RegisterAddonMessagePrefix)~="function" or type(SendAddonMessage)~="function" then return false,"client_api_unavailable" end
    return true
end
function U:Resolve(member)
    local number,group=NumericGUID(member and member.guid)
    if not number then return nil,"guid" end
    local _,ownRealm=UnitFullName("player")
    local _,ownGroup=NumericGUID(UnitGUID("player"))
    local memberRealm=(member.fullName or member.name or ""):match("%-(.+)$")
    local targetID=RealmID(memberRealm)
    local id
    if group==ownGroup then
        local a,b=RealmID(ownRealm),RealmID(GetRealmName())
        if a and b and a~=b then return nil,"ambiguous-realm" end
        id=a or b
        if id and targetID and id~=targetID then return nil,"ambiguous-realm" end
    else id=targetID end
    if not id then return nil,"unknown-realm" end
    return number,id
end
local failureText=GC:RegisterLocaleTable({},function()return {
    aio_not_loaded=(GC:Text("Источник UWoW/AIO не загружен на этом персонаже.")),
    aio_incompatible=(GC:Text("Версия источника UWoW/AIO не совпадает с проверенной.")),
    ratings_not_loaded=(GC:Text("Модуль рейтингов UWoW ещё не загружен.")),
    ratings_incompatible=(GC:Text("Интерфейс рейтингов UWoW несовместим с адаптером.")),
    pvp_not_loaded=(GC:Text("Интерфейс PvP UWoW не загружен.")),
    client_api_unavailable=(GC:Text("Клиентский интерфейс запросов UWoW недоступен.")),
    ["unknown-realm"]=(GC:Text("Не удалось определить реалм персонажа. Запрос не отправлен.")),
    ["ambiguous-realm"]=(GC:Text("Данные о реалме противоречат друг другу. Запрос не отправлен.")),
    guid=(GC:Text("Некорректный идентификатор персонажа. Запрос не отправлен.")),
    selection=(GC:Text("Персонаж не найден в текущем составе гильдии.")),
    source_unbound=(GC:Text("Не удалось подключить проверенный источник UWoW.")),
    source_incompatible=(GC:Text("Привязка источника UWoW не прошла проверку.")),
    busy=(GC:Text("Предыдущий запрос UWoW ещё выполняется.")),
    ["unfinished-response"]=(GC:Text("Предыдущий ответ UWoW ещё не завершён. Повтор пока недоступен.")),
    ["response-fence-cap"]=(GC:Text("Слишком много незавершённых ответов UWoW. Новые запросы приостановлены.")),
    timeout=(GC:Text("UWoW не ответил за отведённое время.")),
    ["send-error"]=(GC:Text("Не удалось отправить запрос UWoW.")),
    request_failed=(GC:Text("Не удалось выполнить запрос UWoW.")),
    context=(GC:Text("Контекст персонажа или источника изменился. Запрос отменён.")),
    context_changed=(GC:Text("Контекст персонажа или гильдии изменился. Запрос отменён.")),
    cancelled=(GC:Text("Запрос отменён.")),
    incomplete=(GC:Text("UWoW прислал неполный ответ; отсутствие рейтинга не подтверждено.")),
    empty=(GC:Text("В ответе UWoW нет рейтинговых данных.")),
} end)
function U:FailureText(reason)
    return failureText[reason] or (GC:Text("Ответ UWoW не удалось получить или он не прошёл проверку."))
end

local function Canonical(name) return GC.TrustBoundary:CanonicalName(name) end
local function SenderOK(sender)
    if type(sender)~="string" then return false end
    if not sender:find("-",1,true) then return sender==UnitName("player") end
    local name,realm=UnitFullName("player");name=name or UnitName("player");realm=realm or GetRealmName()
    return Canonical(sender)==Canonical(name.."-"..realm)
        or Canonical(sender)==Canonical(name.."-"..GetRealmName())
end
local function Split(message)
    if type(message)~="string" or #message>8192 or message:find("[%z\1-\31\127]") then return nil end
    local result={};for v in (message.."|"):gmatch("(.-)|") do
        result[#result+1]=v;if #result>1026 then return nil end
    end
    if result[#result]=="" then table.remove(result) end
    return result
end
local function Numeric(value,max,integer)
    local n=tonumber(value);if not n or n~=n or n<0 or n>max or (integer and n%1~=0) then return nil end;return n
end
function U:RestoreWindowGuard()
    local guard=self.guard;if not guard then return end
    if guard.owner[guard.method]==guard.wrapper then guard.owner[guard.method]=guard.original end
    self.guard=nil
end
function U:GuardWindow(number,realm,bracket)
    self:RestoreWindowGuard()
    local method=bracket==-2 and "CreatePlayerMythicPlusStatistic" or "CreatePlayerPvPStatistic"
    local owner=_G.LadderFrame;local original=owner[method]
    local guard={method=method,owner=owner,original=original,number=number,realm=realm,untilTime=GetTime()+17}
    guard.wrapper=function(frame,guid,realmID,typeID,...)
        if U.guard==guard and GetTime()<=guard.untilTime and tonumber(guid)==number and tonumber(realmID)==realm
            and (bracket==-2 or tonumber(typeID)==bracket)then return end
        return original(frame,guid,realmID,typeID,...)
    end
    self.guard=guard;owner[method]=guard.wrapper
end
function U:ReleaseGuard()
    local guard=self.guard;if not guard then return end
    guard.untilTime=GetTime()+0.5
    C_Timer.After(0.5,function()if U.guard==guard then U:RestoreWindowGuard()end end)
end
-- No nonce on this wire. A cancelled request remains physically active until
-- its matching CREATE, or the existing response timeout. UI intent is invalidated
-- immediately. A timed-out/failed key is not retried until its final arrives.
-- This is a completion fence, not a timed quarantine or guessed server cooldown.
function U:Retire(a)
    if a.trace then GC.MythicTrace:Event(a.trace,"fence","created")end
    self.unresolved[a.key]={number=a.number,realm=a.realm,bracket=a.bracket,trace=a.trace}
end
function U:Cancel()
    local a=self.active
    if a then
        if a.trace and not a.cancelled then GC.MythicTrace:Cancel(a.trace)end
        a.cancelled=true;a.callback=nil
    end
end
function U:CanStart(guild,guid,bracket)
    if self.active then return false,"busy"end
    local member=GC.Roster:FindByKey(guid)
    local number,realm=self:Resolve(member)
    for _,fence in pairs(self.unresolved)do
        if fence.number==number and fence.realm==realm and fence.bracket==bracket then
            if fence.trace then GC.MythicTrace:Event(fence.trace,"refused","unfinished-response")end
            return false,"unfinished-response"
        end
    end
    local count=0;for _ in pairs(self.unresolved)do count=count+1 end
    if count>=200 then return false,"response-fence-cap"end
    return true
end
function U:Finish(data,err,terminated)
    local a=self.active;if not a then return end
    if a.trace then
        a.trace.acceptedPackets=a.packets;a.trace.acceptedBytes=a.bytes
        a.trace.finished=GetTime();a.trace.summarySeen=a.summary~=nil;a.trace.finalSeen=terminated==true
        a.trace.result=err or(a.cancelled and "cancelled"or"complete")
        GC.MythicTrace:Event(a.trace,"finish",a.trace.result)
    end
    if not terminated then self:Retire(a)end
    self.active=nil;self:ReleaseGuard()
    if a.callback and not a.cancelled then a.callback(data,err)end
end
function U:Tick()
    local a=self.active
    if a and(GetTime()-a.started>15 or GetTime()<a.started or a.guild~=GC:GetGuildKey())then
        self:Finish(nil,"timeout")
    end
    if self.guard and GetTime()>self.guard.untilTime then self:RestoreWindowGuard()end
end
function U:Key(guild,guid,bracket)
    return guild..":"..guid..(bracket==-2 and "" or ":pvp:"..tostring(bracket))
end
function U:Start(guid,guild,callback,bracket)
    bracket=bracket or -2
    if not({[-2]=true,[7]=true,[0]=true,[3]=true,[9]=true})[bracket]then return false,"bracket"end
    local category=bracket==-2 and "mythic" or "pvp"
    local available,why=self:Available(category);if not available then return false,why end
    if guild~=GC:GetGuildKey()then return false,"context"end
    if self.active then return false,"busy"end
    local member=GC.Roster:FindByKey(guid);local number,realm=self:Resolve(member)
    if not number then return false,realm end
    local key=self:Key(guild,guid,bracket)
    local ready,why=self:CanStart(guild,guid,bracket);if not ready then return false,why end
    self.generation=self.generation+1
    local a={category=category,bracket=bracket,guid=guid,guild=guild,key=key,number=number,realm=realm,started=GetTime(),callback=callback,packets=0,bytes=0,summary=nil,bestKey=nil,runs={},runIDs={},runsConflict=false}
    self.active=a
    if GC.MythicTrace then GC.MythicTrace:Begin(a)end
    self:GuardWindow(number,realm,bracket)
    local ok,err=pcall(SendAddonMessage,"UIMSG_TO_SERVER","CMSG_RT_GET_PLAYER_STATISTIC\t"..string.format("%.0f",number).."|"..realm.."|"..bracket,"WHISPER",UnitName("player"))
    if a.trace then GC.MythicTrace:Event(a.trace,"send",ok and "api_returned"or"api_error")end
    if not ok then self:Finish(nil,"send-error");return false,"send-error"end
    return true
end
function U:ReceiveCore(prefix,message,channel,sender)
    if prefix~="UISMSG_TO_CLIENT"then return false,"inactive"end
    if channel~="WHISPER" or not SenderOK(sender)then return false,"sender"end
    -- Release only an exact physical terminator, even when a different target
    -- is currently active. Never parse/cache abandoned payload or private data.
    if type(message)=="string" and message:match("^SMSG_RT_PLAYER_STATISTIC_CREATE|")then
        local fields=Split(message)
        if fields and #fields==4 then
            for key,fence in pairs(self.unresolved)do
                if tonumber(fields[2])==fence.number and tonumber(fields[3])==fence.realm
                    and tonumber(fields[4])==fence.bracket then self.unresolved[key]=nil;return false,"drained"end
            end
        end
    end
    local a=self.active;if not a then return false,"inactive"end
    if a.guild~=GC:GetGuildKey() or GetTime()-a.started>15 or not self:Available(a.category) then self:Finish(nil,"context");return false,"context" end
    local summary=a.bracket==-2 and "SMSG_RT_PLAYER_CHALLENGE_STATISTIC_RESPONSE" or "SMSG_RT_PLAYER_PVP_STATISTIC_RESPONSE"
    local best="SMSG_RT_PLAYER_CHALLENGE_STATISTIC_BEST_RUNS_RESPONSE"
    local runs="SMSG_RT_PLAYER_CHALLENGE_STATISTIC_RUNS_RESPONSE"
    local final="SMSG_RT_PLAYER_STATISTIC_CREATE"
    local opcode=type(message)=="string" and message:match("^([A-Z_]+)|")
    -- Battle/member payload (IP/HWID/equipment) is never parsed.
    if opcode~=summary and opcode~=final and not(a.bracket==-2 and(opcode==best or opcode==runs))then return false,"unrelated" end
    local fields=Split(message);if not fields then self:Finish(nil,"format");return false,"format" end
    table.remove(fields,1)
    local size=opcode==summary and(a.bracket==-2 and 18 or 16)or(opcode==final and 3 or 16)
    if #fields<size or #fields%size~=0 then self:Finish(nil,"format");return false,"format" end
    -- Wrong-target replies are irrelevant, not evidence for current selection.
    for i=1,#fields,size do
        if tonumber(fields[i])~=a.number or tonumber(fields[i+1])~=a.realm then return false,"target" end
    end
    a.packets=a.packets+1;a.bytes=a.bytes+#message
    if a.packets>128 or a.bytes>65536 then self:Finish(nil,"response-cap");return false,"response-cap" end
    if a.cancelled then
        if opcode==final and #fields==3 and tonumber(fields[3])==a.bracket then self:Finish(nil,nil,true)end
        return false,"cancelled"
    end
    if opcode==summary then
        if #fields~=size or a.summary then self:Finish(nil,"duplicate-summary");return false,"duplicate-summary" end
        local member=GC.Roster:FindByKey(a.guid)
        if not member or fields[a.bracket==-2 and 4 or 3]~=member.baseName then self:Finish(nil,"name");return false,"name" end
        if a.bracket~=-2 then
            if tonumber(fields[4])~=a.bracket then return false,"bracket" end
            local p={guid=a.guid,bracket=a.bracket,week={},season={},last_season={}}
            for _,f in ipairs({{5,"week","games"},{6,"week","wins"},{7,"week","rating"},{14,"week","mmr"},{8,"season","games"},{9,"season","wins"},{10,"season","rating"},{15,"season","mmr"},{11,"last_season","games"},{12,"last_season","wins"},{13,"last_season","rating"},{16,"last_season","mmr"}})do
                local value=Numeric(fields[f[1]],100000000,true)
                if not value then self:Finish(nil,"number");return false,"number" end;p[f[2]][f[3]]=value
            end
            if p.week.wins>p.week.games or p.season.wins>p.season.games or p.last_season.wins>p.last_season.games then self:Finish(nil,"wins");return false,"wins" end
            a.summary=p;return true
        end
        local data={guid=a.guid,ranges={}}
        local numericFields={{6,"rating"},{7,"tank"},{8,"heal"},{9,"dps"},{18,"totalRuns"}}
        for _,f in ipairs(numericFields)do
            local n=Numeric(fields[f[1]],100000000,f[2]=="totalRuns")
            if not n then self:Finish(nil,"number");return false,"number" end;data[f[2]]=n
        end
        local rangeKeys={"2-4","5-9","10-14","15-19","20-24","25-29","30-34","35+"}
        for i,k in ipairs(rangeKeys)do local n=Numeric(fields[9+i],100000000,true);if not n then self:Finish(nil,"range");return false,"range" end;data.ranges[k]=n end
        a.summary=data
    elseif opcode==best or opcode==runs then
        if not a.summary then self:Finish(nil,"order");return false,"order" end
        for i=1,#fields,16 do
            local n=Numeric(fields[i+7],1000,true);if not n then self:Finish(nil,"key");return false,"key" end
            a.bestKey=math.max(a.bestKey or 0,n)
            -- Keep only validated, public run identity/completion time/key level.
            -- BEST is a subset; RUNS alone defines complete history coverage.
            if opcode==runs then
                local id=Numeric(fields[i+2],4503599627370495,true)
                local stamp=Numeric(fields[i+6],4102444800,true)
                if not id or id<1 or not stamp or stamp<1 or n<2 then self:Finish(nil,"run-number");return false,"run-number"end
                local prior=a.runIDs[id]
                if prior and(prior.date~=stamp or prior.level~=n)then a.runsConflict=true end
                if not prior then
                    if #a.runs>=4096 then self:Finish(nil,"run-cap");return false,"run-cap"end
                    local r={id=id,date=stamp,level=n};a.runIDs[id]=r;a.runs[#a.runs+1]=r
                end
            end
        end
    else
        if #fields~=3 or tonumber(fields[3])~=a.bracket then return false,"bracket" end
        if not a.summary then self:Finish(nil,"incomplete",true);return false,"incomplete" end
        if a.bracket~=-2 then self:Finish(a.summary,nil,true);return true end
        local data=a.summary;data.bestKey=a.bestKey
        data.runs=a.runs;data.runsComplete=not a.runsConflict and #a.runs==data.totalRuns
        if GC.MythicAnalytics then GC.MythicAnalytics:AttachRoles(a,data)end
        -- Optional rank from current runtime table, only exact GUID/realm entry.
        local ranks=_G.LadderFrame.PlayerTooltipProfileData
        local r=ranks and ranks[a.realm] and ranks[a.realm][a.number] and ranks[a.realm][a.number][-2]
        if type(r)=="table" and type(r.ranks)=="table" and Numeric(r.ranks.by_all,100000000,true) then data.rank=tonumber(r.ranks.by_all)end
        self:Finish(data,nil,true)
    end
    return true
end
-- Observe around the unchanged admission/parser, including its rejection result.
function U:Receive(prefix,message,channel,sender)
    if prefix~="UISMSG_TO_CLIENT"then return self:ReceiveCore(prefix,message,channel,sender)end
    local t=self.active and self.active.trace
    if type(message)=="string"and #message<=8192 and message:match("^SMSG_RT_PLAYER_STATISTIC_CREATE|")then
        local n,r,b=message:match("^SMSG_RT_PLAYER_STATISTIC_CREATE|(%d+)|(%d+)|([%-0-9]+)|?$")
        if tonumber(b)==-2 then
            for _,f in pairs(self.unresolved)do
                if f.number==tonumber(n)and f.realm==tonumber(r)and f.bracket==-2 then t=f.trace;break end
            end
        end
    end
    local observed=t and GC.MythicTrace:Receive(t,message,channel,SenderOK(sender))
    local accepted,reason=self:ReceiveCore(prefix,message,channel,sender)
    if observed then
        GC.MythicTrace:Event(t,"decision",accepted and "accepted"or(reason or "rejected"))
        if reason=="drained"then GC.MythicTrace:Event(t,"fence","drained")end
    end
    return accepted,reason
end
function GC.Rating:BindUWoW()
    local available,why=U:Available();if not available then return false,why end
    if not U.frame then
        U.frame=CreateFrame("Frame");U.frame:RegisterEvent("CHAT_MSG_ADDON");RegisterAddonMessagePrefix("UISMSG_TO_CLIENT")
        U.frame:SetScript("OnEvent",function(_,_,...)U:Receive(...)end)
        U.frame:SetScript("OnUpdate",function()
            U:Tick()
            if GC.RatingTabs then GC.RatingTabs:Tick()end
        end)
    end
    self.runtime={module="aio_rating_tables",crc=1367320996,schema=1,verifiedBinding=true,isLive=true,
        request=function(guid,guild,callback)return U:Start(guid,guild,callback)end}
    return true
end
