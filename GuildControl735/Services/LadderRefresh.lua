-- Independent aggregate refresh. Reuses the unchanged admitted UWoW adapter.
local _,GC=...
local Q={jobs={},attempts={},nextSend=0,completed=0,failed=0,interval=2};GC.LadderRefresh=Q
local modes={-2,7,0,3,9}
local ranges={"c_2_4","c_5_9","c_10_14","c_15_19","c_20_24","c_25_29","c_30_34","c_35_above"}
local wireRanges={"2-4","5-9","10-14","15-19","20-24","25-29","30-34","35+"}
local function Copy(v,depth)
 if type(v)~="table"then return v end
 if depth==0 then return nil end
 local d={};for k,x in pairs(v)do if type(k)=="string"or type(k)=="number"then d[k]=Copy(x,depth-1)end end;return d
end
local function Target(d,b)return b==-2 and not d.absent and d or b~=-2 and d.pvp and d.pvp[b]or nil end
local function Count(d,b)return b==-2 and d.totalRuns or d.seasonGames end
local function Stamp(p,d,b,at)
 if p.summaryRating==nil then p.summaryRating=d.rating;p.summaryCount=Count(d,b);p.savedAt=at end
end
function Q:Preserve(records,old)
 for guid,d in pairs(records)do
  local prior=old and old.records and old.records[guid]
  if prior and (prior.guid~=guid or prior.realm~=d.realm)then prior=nil end
  for _,b in ipairs(modes)do
   local dst=b==-2 and d or d.pvp[b]
   local src=prior and (b==-2 and prior or prior.pvp and prior.pvp[b])
   if dst then
    -- Native-memory recapture must not drop a matching admitted period schema.
    if b~=-2 and dst.profile and src and src.profile and src.profile.pvpPeriodsSchema==1 then
     local same=true
     for _,period in ipairs({"week","season","last_season"})do
      local a,c=dst.profile[period],src.profile[period]
      for _,k in ipairs({"games","games_win","rating","mmr"})do
       if type(a)~="table"or type(c)~="table"or a[k]~=c[k]then same=false end
      end
     end
     if same then dst.profile=Copy(src.profile,4)end
    end
    if dst.profile then Stamp(dst.profile,dst,b,d.updatedAt)
    elseif src and type(src.profile)=="table"then
     dst.profile=Copy(src.profile,4);Stamp(dst.profile,src,b,src.updatedAt)
    end
    if dst.profile then
     if b==-2 and src and src.profile and src.profile.runs and dst.profile.runs==nil then
      dst.profile.runs=Copy(src.profile.runs,3)
      dst.profile.runsComplete=src.profile.runsComplete
      dst.profile.runRolesSchema=src.profile.runRolesSchema
     end
     dst.profile.stale=(b==-2 and d.absent)or dst.profile.summaryRating~=dst.rating
       or (Count(dst,b)~=nil and dst.profile.summaryCount~=Count(dst,b))or false
    end
   end
  end
 end
end
function Q:Needed(d,b)
 local t=Target(d,b);if not t then return false end
 local p=t.profile
 return not p or p.summaryRating~=t.rating or(Count(t,b)~=nil and p.summaryCount~=Count(t,b))or(b==-2 and(p.runsComplete==nil or p.runRolesSchema~=1))or(b~=-2 and(p.pvpPeriodsSchema~=1 or p.pvpRefreshStamp~=self.pvpRefreshStamp))
end
function Q:Snapshot()
 local root=GC.db and GC.db.mythicLadderCache
 return root and root.guilds and root.guilds[GC:GetGuildKey()]
end
function Q:Ready()
 local L=GC.MythicLadder
 return L and not L.pending and L.completeRoot~=nil and _G.LadderFrame
  and L.completeRoot==_G.LadderFrame.BracketsByTypeData and L.savedGuild==GC:GetGuildKey()
end
function Q:Plan()
 if not self:Ready()then return end
 self.generalError=nil
 local guild=GC:GetGuildKey();local epoch=GC.MythicLadder.epoch
 if self.guild~=guild or self.epoch~=epoch then
  self.guild=guild;self.epoch=epoch;self.attempts={};self.completed=0;self.failed=0
 end
 local s=self:Snapshot();local jobs={}
 for _,m in ipairs(GC.Roster.members or{})do
  local d=s and s.records[m.guid]
  if d then
   for _,b in ipairs(modes)do
    if self:Needed(d,b)then
     local key=guild..":"..m.guid..":"..b
     if not self.active or self.active.key~=key then jobs[#jobs+1]={key=key,guid=m.guid,guild=guild,realm=d.realm,bracket=b}end
    end
   end
  end
 end
 table.sort(jobs,function(a,b)return a.key<b.key end)
 self.jobs=jobs
end
function Q:Save(job,data)
 if job.guild~=GC:GetGuildKey()or type(data)~="table"or data.guid~=job.guid then return false end
 local s=self:Snapshot();local d=s and s.records[job.guid]
 if not d or d.realm~=job.realm then return false end
 local dst=Target(d,job.bracket);if not dst then return false end
 local p={source="UWoW/server",savedAt=time(),freshness="received",summaryRating=data.rating or(data.season and data.season.rating)}
 if job.bracket==-2 then
  p.roles={tank=data.tank,heal=data.heal,dps=data.dps};p.ranges={};p.summaryCount=data.totalRuns
  p.runs=data.runs;p.runsComplete=data.runsComplete==true
  p.runRolesSchema=data.runRolesSchema
  for i,k in ipairs(ranges)do p.ranges[k]=data.ranges and data.ranges[wireRanges[i]]end
 else
  for _,period in ipairs({"week","season","last_season"})do
   local v=data[period]
   if type(v)~="table"then return false end
   for _,k in ipairs({"games","wins","rating","mmr"})do
    local n=v[k];if type(n)~="number"or n~=n or n<0 or n>100000000 or n%1~=0 then return false end
   end
   if v.wins>v.games then return false end
  end
  p.summaryCount=data.season and data.season.games
  p.pvpPeriodsSchema=1;p.pvpRefreshStamp=self.pvpRefreshStamp
  for _,period in ipairs({"week","season","last_season"})do
   local v=data[period]
   if v then p[period]={games=v.games,games_win=v.wins,rating=v.rating,mmr=v.mmr}end
  end
 end
 p.stale=p.summaryRating~=dst.rating or(Count(dst,job.bracket)~=nil and p.summaryCount~=Count(dst,job.bracket))or false
 dst.profile=p
 -- Store the successful detail checkpoint independently of the common snapshot.
 return true
end
function Q:Done(job,data,err)
 if self.active~=job then return end
 self.active=nil
 local a=self.attempts[job.key]or{count=1};self.attempts[job.key]=a
 if not err and self:Save(job,data)then self.completed=self.completed+1
 else a.after=GetTime()+60;a.error=err or"context";self.failed=self.failed+1 end
 if GC.Diagnostics then GC.Diagnostics:Record("LADDER_REFRESH",job.guid..":"..job.bracket..":"..tostring(err or"complete"))end
 self:Plan()
end
function Q:RequestGeneral()
 local L=GC.MythicLadder
 if L.pending then return false,"pending"end
 if L.helloAt and GetTime()-L.helloAt<60 then return false,"cooldown"end
 if not GC:GetGuildKey()or not GC.UWoWMythic:Available()then return false,"unavailable"end
 if GC.UWoWMythic.active then return false,"busy"end
 local frame=_G.LadderFrame
 if type(frame.ClearTables)~="function"then return false,"unavailable"end
 -- Same admitted common request as the verified native module, no UI opening.
 frame:ClearTables();L:Begin()
 local ok=pcall(SendAddonMessage,"UIMSG_TO_SERVER","CMSG_RT_HELLO\t","WHISPER",UnitName("player"))
 self.generalDeadline=GetTime()+15
 if not ok then L.pending=false;L.completeRoot=nil;return false,"send-error"end
 return true
end
-- Explicit PvP refresh reuses the same HELLO/queue, gates and retry budgets.
function Q:RefreshPvP()
 self.pvpRefreshSerial=(self.pvpRefreshSerial or 0)+1
 self.pvpRefreshStamp=tostring(time())..":"..tostring(GetTime())..":"..self.pvpRefreshSerial
 self:Refresh()
end
function Q:Refresh()
 self.refreshWanted=true;self.generalError=nil
end
function Q:Tick()
 if not GC.db or not GC.Roster then return end
 local L=GC.MythicLadder;local U=GC.UWoWMythic;local now=GetTime()
 if self.active and(self.active.guild~=GC:GetGuildKey()or not GC.Roster:FindByKey(self.active.guid))then
  U:Cancel();self.active=nil
 end
 if U.frame then U:Tick()end
 if self.active and not U.active then self:Done(self.active,nil,"cancelled")end
 if not self.started then self.started=now end
 if L.pending and L.helloAt and now-L.helloAt>15 then
  L.pending=false;L.completeRoot=nil;self.generalError=(GC:Text("Общая статистика не получена. Нажмите «Обновить» позже."))
 end
 -- Native login HELLO is preferred. One fallback if it was missed before hooks.
 if not self.startupChecked and now-self.started>=15 then
  self.startupChecked=true
  if not L.completeRoot and not L.pending then self.refreshWanted=true end
 end
 if self.refreshWanted then
  local ok,why=self:RequestGeneral()
  if ok then self.refreshWanted=false;return end
  if why=="send-error"then self.refreshWanted=false;self.generalError=(GC:Text("Не удалось обновить общую статистику."))end
 end
 if not self:Ready()or self.active or U.active or now<self.nextSend then return end
 local gate=GC.Rating:Gate();if not gate then return end
 for _,job in ipairs(self.jobs)do
  local d=self:Snapshot();d=d and d.records[job.guid]
  local member=GC.Roster:FindByKey(job.guid)
  local n,r=U:Resolve(member)
  local a=self.attempts[job.key]or{count=0,after=0}
  if member and n and r==job.realm and job.guild==GC:GetGuildKey()and d and self:Needed(d,job.bracket)
   and a.count<2 and now>=(a.after or 0)then
   local ready=U:CanStart(job.guild,job.guid,job.bracket)
   if ready then
    a.count=a.count+1;self.attempts[job.key]=a;self.active=job;self.nextSend=now+self.interval
    local ok,why=U:Start(job.guid,job.guild,function(data,err)Q:Done(job,data,err)end,job.bracket)
    if not ok and self.active==job then self:Done(job,nil,why)end
    return
   end
  end
 end
end
function Q:StatusText()
 if self.generalError then return self.generalError end
 if self.refreshWanted then return (GC:Text("Ожидание обновления общей статистики…"))end
 if not self:Ready()then return (GC:Text("Ожидание общей статистики UWoW…"))end
 local left=0;for _,j in ipairs(self.jobs)do left=left+1 end
 if self.active then left=left+1 end
 if left>0 then return (GC:Text("Обновлено: "))..self.completed..(GC:Text(". Осталось: "))..left..(GC:Text(". Ошибок: "))..self.failed end
 return (GC:Text("Сохранённая статистика обновлена."))
end
local f=CreateFrame("Frame")
f:SetScript("OnUpdate",function(_,elapsed)
 Q.elapsed=(Q.elapsed or 0)+elapsed
 if Q.elapsed>=0.2 then Q.elapsed=0;Q:Tick()end
end)
