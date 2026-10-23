-- Guild-scoped policy. Only the roster-confirmed guild leader may publish it.
local _,GC=...
local T={prefix="GC735TRUST",members={}}
GC.AdminTrust=T
local function Canon(name)return GC.TrustBoundary:CanonicalName(name)end
local function Integer(n)return type(n)=="number"and n%1==0 end
local function ValidMask(mask)return Integer(mask)and mask>=1 and mask<=1023 and mask%2==1 end
local function Has(mask,rank)return Integer(rank)and rank>=0 and rank<10 and math.floor(mask/2^rank)%2==1 end
function T:Refresh()
 local key=GC:GetGuildKey();local members={};local leader
 if key then
  for i=1,math.min(GetNumGuildMembers()or 0,1000)do
   local n,_,rank,_,_,_,_,_,_,_,_,_,_,_,_,_,guid=GetGuildRosterInfo(i)
   local name=Canon(n)
   if name and Integer(rank)and rank>=0 and rank<10 and type(guid)=="string"and guid:match("^Player%-%x+%-%x+$")then
    members[name]={rank=rank,guid=guid};if rank==0 then
     if leader then leader=false;break else leader=guid end
    end
   end
  end
 end
 if key~=self.key or leader~=self.leader then self.lastAsk=nil;self.nextAsk=nil;self.lastBroadcast=nil end
 self.key=key;self.leader=leader;self.members=members;self.refreshed=GetTime()
 if GC.db then GC.db.adminTrust=GC.db.adminTrust or {guilds={}} end
end
function T:Policy()
 local root=GC.db and GC.db.adminTrust
 local p=root and root.guilds and self.key and root.guilds[self.key]
 if type(p)=="table"and p.leader==self.leader and ValidMask(p.mask)and Integer(p.revision)and p.revision>=1 then return p end
end
function T:IsLeader()
 if self.key~=GC:GetGuildKey()then return false end
 local guid=UnitGUID("player")
 if not self.leader or not guid or guid~=self.leader then return false end
 for _,m in pairs(self.members)do if m.guid==guid and m.rank==0 then return true end end
 return false
end
function T:Allowed(sender)
 if self.key~=GC:GetGuildKey()or not self.key then return false,"guild_scope"end
 if not self.leader then return false,"no_leader"end
 if not self.refreshed or GetTime()-self.refreshed>120 then return false,"stale_roster"end
 local m=self.members[Canon(sender)or""];if not m then return false,"unknown_trust_sender"end
 if m.rank==0 and m.guid==self.leader then return true,"leader"end
 local p=self:Policy();if not p then return false,"no_policy"end
 if not Has(p.mask,m.rank)then return false,"rank_not_trusted"end
 return true,"trusted_rank"
end
function T:OwnAllowed()
 local guid=UnitGUID("player");if not guid then return false end
 for name,m in pairs(self.members)do if m.guid==guid then return self:Allowed(name)end end
 return false
end
function T:Save(mask)
 self:Refresh()
 if not self:IsLeader()or not ValidMask(mask)then return false end
 local old=self:Policy()
 local p={leader=self.leader,revision=math.max(time(),old and old.revision+1 or 1),mask=mask}
 GC.db.adminTrust.guilds[self.key]=p;self.dirty=true
 self:Broadcast();if GC.OnPermissionsChanged then GC:OnPermissionsChanged()end;return true
end
function T:Broadcast()
 if not self:IsLeader()then return false end
 local p=self:Policy();if not p then return false end
 local now=GetTime();if self.lastBroadcast and now-self.lastBroadcast<5 then self.dirty=true;return false end
 self.lastBroadcast=now;self.dirty=nil
 local policy=p
 GC.DataExchange:Enqueue(self.prefix,table.concat({"P","1",p.leader,p.revision,p.mask},"|"),function()return T:IsLeader()and T:Policy()==policy end)
 return true
end
function T:Receive(msg,sender,channel)
 if channel~="GUILD"then return false end
 if GC.SpamShield and GC.SpamShield:IsBlocked(sender)then return false end
 if channel~="GUILD"or type(msg)~="string"or #msg>110 then return false end
 if self.key~=GC:GetGuildKey()or not self.key or not self.leader or not self.refreshed or GetTime()-self.refreshed>120 then return false end
 local member=self.members[Canon(sender)or""];if not member then return false end
 if msg=="R|1"then
  -- One broadcast per five seconds, regardless of how many peers request it.
  if self:IsLeader()then self:Broadcast()end
  return true
 end
 if member.rank~=0 or member.guid~=self.leader then return false end
 local guid,rev,mask=msg:match("^P|1|(Player%-%x+%-%x+)|(%d+)|(%d+)$")
 rev=tonumber(rev);mask=tonumber(mask)
 if guid~=self.leader or not Integer(rev)or rev<1 or rev>time()+300 or not ValidMask(mask)then return false end
 local old=self:Policy()
 if old and (rev<old.revision or rev==old.revision and mask~=old.mask)then return false end
 if old and rev==old.revision and mask==old.mask then return true end
 GC.db.adminTrust.guilds[self.key]={leader=guid,revision=rev,mask=mask}
 if GC.OnPermissionsChanged then GC:OnPermissionsChanged()end
 return true
end
function T:Tick()
 local now=GetTime()
 if not self.lastRefreshRequest or now-self.lastRefreshRequest>=60 then
  self.lastRefreshRequest=now;if GuildRoster then GuildRoster()end
 end
 if self.dirty then self:Broadcast()end
 -- A leader heartbeat repairs a lost policy update. Peers with a valid policy
 -- never all rebroadcast requests every minute; cold peers stagger discovery.
 if self.key and self.leader then
  if self:IsLeader()then
   if not self.lastBroadcast or now-self.lastBroadcast>=60 then self:Broadcast()end
  elseif not self:Policy()then
   if not self.nextAsk then
    local own=UnitGUID("player");local ids={};for _,m in pairs(self.members)do ids[#ids+1]=m.guid end;table.sort(ids)
    local slot=1;for i,g in ipairs(ids)do if g==own then slot=i;break end end
    self.nextAsk=now+2+slot*0.2
   elseif now>=self.nextAsk then
    self.lastAsk=now;self.nextAsk=now+60
    local key=self.key
    GC.DataExchange:Enqueue(self.prefix,"R|1",function()return T.key==key and key==GC:GetGuildKey()and not T:Policy()end)
   end
  else self.nextAsk=nil end
 end
end
function GC:InitializeAdminTrust()
 if T.frame then return end
 T:Refresh();RegisterAddonMessagePrefix(T.prefix)
 local f=CreateFrame("Frame");T.frame=f
 for _,e in ipairs({"CHAT_MSG_ADDON","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","GUILD_RANKS_UPDATE","PLAYER_ENTERING_WORLD"})do f:RegisterEvent(e)end
 f:SetScript("OnEvent",function(_,event,prefix,msg,channel,sender)
  if event=="CHAT_MSG_ADDON"then if prefix==T.prefix and channel=="GUILD"then T:Receive(msg,sender,channel)end
  else
   T:Refresh()
   if T:IsLeader()then T.dirty=true end
   if GC.OnPermissionsChanged then GC:OnPermissionsChanged()end
  end
 end)
 local elapsed=0
 f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0;T:Tick()end)
end
