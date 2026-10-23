-- Guild-local departed-member history. No wire authority, officer-note writes or actions.
local _,G=...
local A={ttl=90*86400};G.GuildArchive=A
local function clone(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
local function log(k,s)if G.Diagnostics then G.Diagnostics:Record('ARCHIVE_'..k,s)end end
function A:Root()
 local key=G:GetGuildKey();if not key or not G.db then return end
 G.db.guilds=G.db.guilds or{};G.db.guilds[key]=G.db.guilds[key]or{}
 local g=G.db.guilds[key];g.departedHistory=g.departedHistory or{schema=1,entries={},identities={}}
 return g.departedHistory,g
end
function A:Entry(guid)
 local root=self:Root();local e=root and root.entries[guid]
 return e and type(e.leftAt)=='number'and time()<e.leftAt+self.ttl and e or nil
end
function A:Member(guid)
 local live=G.Roster:FindByKey(guid);if live then return live end
 local e=self:Entry(guid);if not e then return end
 local m=clone(e.identity or{});m.guid=guid;m.key=guid;m.name=m.name or(e.profile and e.profile.name)or guid
 m.fullName=G.TrustBoundary:CanonicalName(m.name);m.archived=true;m.online=false
 return m
end
function A:Peers(guid)
 local root=self:Root();local out={};if not root then return out end
 if self.indexRoot~=root or not self.index then
  self.indexRoot=root;self.index={}
  for id,e in pairs(root.entries)do for peer in pairs(e.peers or{})do
   self.index[id]=self.index[id]or{};self.index[id][peer]=id
   self.index[peer]=self.index[peer]or{};self.index[peer][id]=id
  end end
 end
 for peer,anchor in pairs(self.index[guid]or{})do
  if self:Entry(anchor)and self:Member(peer)then out[peer]=true end
 end
 return out
end
function A:Linked(a,b)return self:Peers(a)[b]==true end
function A:Snapshot(guid)
 local e=self:Entry(guid);if e and e.family then return e.family end
 local peers=self:Peers(guid);if not next(peers)then return end
 peers[guid]=true;local members={};for id in pairs(peers)do local m=self:Member(id);if m then members[#members+1]={guid=id,name=m.fullName or m.name}end end
 return {senderGUID=guid,members=members,trust='RETAINED_MUTUAL_HISTORY'}
end
function A:Track()
 local root=self:Root();if not root then return end
 for _,m in ipairs(G.Roster.members)do root.identities[m.guid]={name=m.name,class=m.class,classFile=m.classFile}end
end
function A:Reconcile(keep)
 local root,g=self:Root();if not root then return false end
 local sat=g.satellite;local fam=g.familySnapshots
 local fast=G.db.fastSync and G.db.fastSync.guilds and G.db.fastSync.guilds[G:GetGuildKey()]
 local own=G.Character and G.Character.db and G.Character.db.families and G.Character.db.families[G:GetGuildKey()]
 local now=time();local changed=false;local expired={}
 -- First remove expired history; active canonical lists remain byte-for-byte intact.
 for guid,e in pairs(root.entries)do
  if type(e.leftAt)~='number'or now>=e.leftAt+self.ttl then root.entries[guid]=nil;expired[guid]=true;if not keep[guid]then root.identities[guid]=nil end;changed=true;log('EXPIRED',guid)end
 end
 local candidates={}
 for guid in pairs(sat and sat.members or{})do candidates[guid]=true end
 for guid in pairs(fam and fam.snapshots or{})do candidates[guid]=true end
 for guid in pairs(own and own.members or{})do candidates[guid]=true end
 for guid in pairs(root.identities)do candidates[guid]=true end
 for guid in pairs(candidates)do
  if not keep[guid]and(not root.entries[guid]or root.entries[guid].returnedAt)and not expired[guid]then
   local profile=sat and sat.members[guid];local family=fam and fam.snapshots[guid]
   local meta=fast and fast.received and fast.received[guid]
   local peers=clone(root.entries[guid]and root.entries[guid].peers or{})
   for _,p in ipairs(family and family.members or{})do
    local other=fam and fam.snapshots[p.guid]
    for _,back in ipairs(other and other.members or{})do if back.guid==guid and p.guid~=guid then peers[p.guid]=true end end
   end
   root.entries[guid]={leftAt=now,peers=peers,identity=clone(root.identities[guid]),profile=clone(profile),family=clone(family),profileWatermark=clone(sat and sat.listWatermarks and sat.listWatermarks[guid]),familyWatermark=clone(fam and fam.watermarks and fam.watermarks[guid]),fast=meta and{P=clone(meta.P),F=clone(meta.F)}or nil}
   changed=true;log('LEFT',guid..' ttl=90d profile='..tostring(profile~=nil)..' family='..tostring(family~=nil))
  end
 end
 for guid,e in pairs(root.entries)do if keep[guid]and not e.returnedAt then
  if e.profile then
   if not sat then sat={members={},listWatermarks={}};g.satellite=sat end
   sat.members=sat.members or{};sat.listWatermarks=sat.listWatermarks or{}
   local old=sat.members[guid]
   if not old or(tonumber(old.listRevision)or 0)<(tonumber(e.profile.listRevision)or 0)then sat.members[guid]=clone(e.profile);if e.profileWatermark then sat.listWatermarks[guid]=clone(e.profileWatermark)end end
  end
  if e.family then
   if not fam then fam={version=2,snapshots={},watermarks={}};g.familySnapshots=fam end
   local old=fam.snapshots[guid]
   if not old or(tonumber(old.rev)or 0)<(tonumber(e.family.rev)or 0)then fam.snapshots[guid]=clone(e.family);if e.familyWatermark then fam.watermarks[guid]=clone(e.familyWatermark)end end
  end
  -- Let the existing authenticated protocol reconcile fresh revisions/hashes.
  e.returnedAt=now;changed=true;log('RETURNED',guid..' restored local history; MAIN not restored')
 end end
 if changed then self.index=nil end
 return changed
end
local rebuild=G.Roster.Rebuild
function G.Roster:Rebuild(...)local result=rebuild(self,...);A:Track();return result end
