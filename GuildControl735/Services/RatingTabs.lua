-- User-click-only, category-scoped scheduler. One active + one latest intent.
local _,GC=...
GC.RatingTabs={epoch=0,serial=0,desired=nil,active=nil}
local T=GC.RatingTabs
T.modes={{id=7,name="1×1"},{id=0,name="2×2"},{id=3,name="RBG"},{id=9,name="SoloQ2x2"}}
function T:Cancel()
    self.epoch=self.epoch+1;self.desired=nil;self.active=nil
    -- Card navigation does not cancel the independent refresh queue.
end
function T:OpenMythic(member)
    if not member or not member.guid then return end
    self:Cancel()
    GC.MythicLadder:Capture()
    self.desired={epoch=self.epoch,guild=GC:GetGuildKey(),guid=member.guid,kind="mythic",phase="cached"}
end
function T:Select(member,kind)
    if kind=="mythic"or kind=="pvp"then self:OpenMythic(member);if self.desired then self.desired.kind=kind end;return true end
    if not member or not member.guid or(kind~="mythic"and kind~="pvp")then return false end
    local guild=GC:GetGuildKey();if not guild then return false end
    local d=self.desired
    if d and(d.phase=="queued"or d.phase=="pending")and d.guid==member.guid and d.guild==guild and d.kind==kind then
        self:Tick()
        if d.phase=="queued"or d.phase=="pending"then return true end
    end
    self:Cancel();self.desired={epoch=self.epoch,guild=guild,guid=member.guid,kind=kind,phase="queued",index=1,results={},errors={}}
    self:Tick();return true
end
function T:GetPvPDatabase(guild)
    GC.db.pvpRatings=GC.db.pvpRatings or{version=1,guilds={}}
    local root=GC.db.pvpRatings.guilds
    if not root[guild]then local count=0;for _ in pairs(root)do count=count+1 end;if count>=30 then return nil end;root[guild]={}end
    local db=root[guild]
    for k,v in pairs(db)do
        if type(v)~="table"or type(v.updatedAt)~="number" then db[k]=nil
        else
            v.modes=type(v.modes)=="table"and v.modes or{}
            for bracket,data in pairs(v.modes)do
                if not({[7]=true,[0]=true,[3]=true,[9]=true})[bracket]or type(data)~="table"or type(data.updatedAt)~="number" then v.modes[bracket]=nil end
            end
        end
    end
    return db
end
function T:SavePvP(d,bracket,data)
    local db=self:GetPvPDatabase(d.guild);if not db then return end
    if not db[d.guid]then
        local count=0;for _ in pairs(db)do count=count+1 end
        if count>=1000 then return false end -- Preserve existing members at storage capacity.
        db[d.guid]={source="UWoW/server",updatedAt=time(),modes={}}
    end
    data.source="UWoW/server";data.updatedAt=time()
    db[d.guid].updatedAt=time();db[d.guid].modes[bracket]=data
end
function T:Done(context,data,err)
    local d=self.desired
    if self.active~=context or not d or d.epoch~=context.epoch or d.guild~=GC:GetGuildKey()
        or d.guid~=context.guid or d.kind~=context.kind then return false end
    self.active=nil
    if context.kind=="mythic"then d.data=data;d.phase=err or"fresh";if err then d.error=GC.Rating.stateReasons[d.guild..":"..d.guid]or err end;return true end
    if data then d.results[context.bracket]=data;self:SavePvP(d,context.bracket,data)
    else d.errors[context.bracket]=err or"error"end
    d.index=d.index+1;d.phase=d.index>4 and"fresh"or"queued"
    self:ScheduleTick()
    return true
end
function T:ScheduleTick()
    if self.scheduled then return end
    self.scheduled=true
    -- Next event-loop turn lets the original AIO handler finish its current
    -- CREATE dispatch while the matching native popup guard is still installed.
    C_Timer.After(0,function()T.scheduled=false;T:Tick()end)
end
function T:Refuse(d,reason,phase)
    d.phase=phase or "unavailable";d.error=reason or "request_failed"
    if GC.Diagnostics then GC.Diagnostics:Record("RATING_REFUSED",d.kind.." GUID="..d.guid.." reason="..d.error)end
end
function T:Tick()
    local d=self.desired
    if d and (d.guild~=GC:GetGuildKey()or not GC.Roster:FindByKey(d.guid))then self:Cancel()end
end
function T:View(member,kind)
    self:Tick();local d=self.desired
    if not d or not member or d.guid~=member.guid or d.kind~=kind or d.guild~=GC:GetGuildKey()then return nil end
    return d
end
