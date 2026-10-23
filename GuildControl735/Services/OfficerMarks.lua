-- Original implementation. Only the exact public marker result is transmitted;
-- never officer note text or Blizzard write operations.
local _,G=...
local M={};G.OfficerMarks=M
local function trusted(guid)
 local row=G.Roster:FindByKey(guid)
 return row and G.AdminTrust:Allowed(row.name)and row
end
function M:Root()
 local key=G:GetGuildKey();if not key or not G.db then return nil end
 G.db.guilds=G.db.guilds or{};G.db.guilds[key]=G.db.guilds[key]or{}
 local guild=G.db.guilds[key];guild.officerMarks=guild.officerMarks or{}
 return guild.officerMarks
end
function M:CanRead()
 return G.AdminTrust:OwnAllowed()and type(CanViewOfficerNote)=="function"and CanViewOfficerNote()
  and G.Roster:CanPrune()
end
function M:Get(guid)
 local root=self:Root();local r=root and root[guid]
 if not r or r.leader~=G.AdminTrust.leader or not trusted(r.observer)then return nil end
 if type(r.stamp)~="number"or r.stamp>time()+300 then return nil end
 if r.conflict then return nil end
 return r
end
function M:CaptureAll()
 if not self:CanRead()then return false end
 local root=self:Root();if not root then return false end
 local observer=UnitGUID("player");local leader=G.AdminTrust.leader
 for _,row in ipairs(G.Roster.members)do
  -- Roster completeness and read permission are prerequisites for a negative.
  local nativeName,_,_,_,_,_,_,note,_,_,_,_,_,_,_,_,nativeGUID=GetGuildRosterInfo(row.index)
  if nativeGUID~=row.guid then return false end
  if type(note)=="string"and G.FastWire.GUID(row.guid)then
   local marked=note:find("[GC:MAIN]",1,true)~=nil;local old=root[row.guid]
   if not old or old.marked~=marked or old.conflict or old.leader~=leader or not trusted(old.observer)then
    local stamp=math.max(time(),old and old.stamp+1 or 0)
    if stamp<=time()+300 then root[row.guid]={marked=marked,stamp=stamp,observer=observer,leader=leader}end
   end
  end
 end
 return true
end
function M:Token(guid)
 local r=self:Get(guid)
 return r and table.concat({r.marked and "1"or "0",string.format("%.0f",r.stamp),r.observer,r.leader},",")or nil
end
function M:ValidToken(token)
 if token=="-"then return true end
 if type(token)~="string"or #token>96 then return false end
 local flag,stamp,observer,leader=token:match("^([01]),(%d+),(Player%-%d+%-%x+),(Player%-%d+%-%x+)$")
 stamp=G.FastWire.Int(stamp,1,time()+300)
 return flag and stamp and leader==G.AdminTrust.leader and G.FastWire.GUID(observer)and trusted(observer)and true or false
end
function M:ApplyToken(guid,token,provider)
 if G.ManualBans and(G.ManualBans:Blocked(guid)or G.ManualBans:Blocked(provider))then return true end -- Skip frozen interclient evidence without deleting it.
 if not G.Roster:FindByKey(guid)or not trusted(provider)or not self:ValidToken(token)then return false end
 if token=="-"then return true end -- No evidence is never a deletion.
 local flag,stamp,observer=token:match("^([01]),(%d+),(Player%-%d+%-%x+),Player%-%d+%-%x+$")
 stamp=tonumber(stamp);local root=self:Root();if not root then return false end
 local old=root[guid];local marked=flag=="1";local leader=G.AdminTrust.leader
 if old and old.leader==leader and old.stamp>stamp then return true end
 if old and old.leader==leader and old.stamp==stamp then
  if old.marked~=marked then old.conflict=true end
  return true
 end
 root[guid]={marked=marked,stamp=stamp,observer=observer,leader=leader,via=provider}
 if G.RefreshLinkedMemberCard then G:RefreshLinkedMemberCard()end
 return true
end
