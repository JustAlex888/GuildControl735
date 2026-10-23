-- Original local-only presentation. No note/profession encoder or receiver.
local _,G=...
local D={professions={}};G.RosterDetails=D
local primary={[164]=true,[165]=true,[171]=true,[182]=true,[186]=true,[197]=true,[202]=true,[333]=true,[393]=true,[755]=true,[773]=true}
local function plain(s)
 if type(s)~="string"then return ""end
 return (s:gsub("|","||"):gsub("[%z\1-\31\127]"," "))
end
function D:CanReadOfficer()
 if not IsInGuild()or type(CanViewOfficerNote)~="function"then return false end
 local ok,value=pcall(CanViewOfficerNote);return ok and value==true
end
function D:Notes(member)
 local denied=G.L.INSUFFICIENT_RIGHTS;local can=self:CanReadOfficer()
 if not member or not IsInGuild()or type(GetGuildRosterInfo)~="function"then return G.L.NO_NATIVE_DATA,can and G.L.NO_NATIVE_DATA or denied end
 local ok,row=pcall(function()return {GetGuildRosterInfo(member.index)}end)
 -- Native roster indexes can change after sort/update. Never read another row.
 if not ok or not member.guid or row[17]~=member.guid then return G.L.NO_NATIVE_DATA,can and G.L.NO_NATIVE_DATA or denied end
 local public=type(row[7])=="string"and plain(row[7])or G.L.NO_NATIVE_DATA
 if public==""then public=G.L.NO_NOTE end
 if not can then return public,denied end
 local officer=type(row[8])=="string"and plain(row[8])or G.L.NO_NATIVE_DATA
 if officer==""then officer=G.L.NO_NOTE end
 return public,officer
end
function D:ClearOfficerDisplay()
 local frame=G.MainWindow;if not frame then return end
 for _,row in ipairs(frame.rows or{})do
  if row.cells[10]then row.cells[10]:SetText(self:CanReadOfficer()and ""or G.L.INSUFFICIENT_RIGHTS)end
  local hit=row.detailHits and row.detailHits[10]
  if hit and GameTooltip:IsOwned(hit)then GameTooltip:Hide()end
 end
 if self.tooltipOfficer then GameTooltip:Hide();self.tooltipOfficer=nil end
end
local function count()
 local ok,n=pcall(GetNumGuildTradeSkill)
 return ok and type(n)=="number"and n>=0 and n<=20000 and math.floor(n)==n and n or nil
end
-- Snapshot the currently visible native rows before changing the shared flag.
-- This also absorbs update events caused by our own restore without scan loops.
local function viewSignature()
 local n=count();if not n then return nil end
 local parts={G:GetGuildKey()or ""}
 for i=1,n do
  local row={GetGuildTradeSkillInfo(i)}
  for _,k in ipairs({1,2,4,5,6,7,8,9,13})do parts[#parts+1]=tostring(row[k])end
 end
 return table.concat(parts,"\n")
end
function D:ReadProfessions()
 if self.nativeReading or self.reading then return end
 if not IsInGuild()or type(GetNumGuildTradeSkill)~="function"or type(GetGuildTradeSkillInfo)~="function"then self.professions={};self.nativeViewSignature=nil;self.scanSignature=nil;return end
 local sigOK,signature=pcall(viewSignature)
 if not sigOK or not signature then self.professions={};self.nativeViewSignature=nil;self.scanSignature=nil;return end
 local hasFlag=type(GetGuildRosterShowOffline)=="function"and type(SetGuildRosterShowOffline)=="function"
 local flagOK,original=true,nil
 if hasFlag then flagOK,original=pcall(GetGuildRosterShowOffline)end
 if not flagOK then self.professions={};self.nativeViewSignature=nil;self.scanSignature=nil;return end
 local key=tostring(original)..":"..signature
 if key==self.nativeViewSignature and not self.forceRead then return end
 self.nativeReading=true
 local switched=false
 local ok,result=pcall(function()
  if hasFlag and not original then
   -- Mark first so even a setter that raises after changing state is restored.
   switched=true;SetGuildRosterShowOffline(true)
   if not GetGuildRosterShowOffline()then return false end
  end
  return self:ReadAvailableProfessions()
 end)
 local restored=true
 if switched then
  restored=pcall(SetGuildRosterShowOffline,original)
  local checked,value=pcall(GetGuildRosterShowOffline)
  restored=restored and checked and not value
 end
 self.nativeReading=nil
 if ok and result and restored then self.nativeViewSignature=key
 else
  self.professions={};self.nativeViewSignature=nil;self.scanSignature=nil
  if G.Diagnostics then G.Diagnostics:Record('PROFESSIONS_READ','read='..tostring(ok and result)..'; restored='..tostring(restored))end
 end
end
function D:ReadAvailableProfessions()
 if self.reading then return end
 if not IsInGuild()or type(GetNumGuildTradeSkill)~="function"or type(GetGuildTradeSkillInfo)~="function"then self.professions={};return end
 local sigOK,signature=pcall(function()
  local n=count();if not n then return nil end
  local parts={G:GetGuildKey()or ""}
  for i=1,n do
   local id,c,_,h,a,b,d,_,full,_,_,_,skill=GetGuildTradeSkillInfo(i)
   parts[#parts+1]=table.concat({tostring(id),tostring(c),tostring(h),tostring(a),tostring(b),tostring(d),tostring(full),tostring(skill)},":")
  end
  return table.concat(parts,"\n")
 end)
 if not sigOK or not signature then self.professions={};return end
 if signature==self.scanSignature and not self.forceRead then return true end
 self.forceRead=nil
 self.professions={};self.guild=G:GetGuildKey()
 self.reading=true;local restore={};local gathered={}
 local ok=pcall(function()
  local n=count();if not n then return end
  -- Read header identities first. Temporarily expose native collapsed rows,
  -- then restore the exact headers; never change the native sort.
  for i=1,n do
   local id,collapsed,_,header=GetGuildTradeSkillInfo(i)
   if primary[id]and header and collapsed and type(ExpandGuildTradeSkillHeader)=="function"and type(CollapseGuildTradeSkillHeader)=="function"then restore[#restore+1]=id end
  end
  for _,id in ipairs(restore)do ExpandGuildTradeSkillHeader(id)end
  n=count();if not n then return end
  local headers={}
  for i=1,n do
   local id,_,_,header,_,_,_,display,full,_,_,_,skill=GetGuildTradeSkillInfo(i)
   if primary[id]then
    if type(header)=="string"and header~=""then headers[id]=header
    elseif type(full or display)=="string"then
     local member=G.Roster:FindBySender(full or display)
     if member and member.guid and headers[id]then
      gathered[member.guid]=gathered[member.guid]or{}
      gathered[member.guid][id]={id=id,name=plain(headers[id]),skill=type(skill)=="number"and skill or nil}
     end
    end
   end
  end
 end)
 for _,id in ipairs(restore)do pcall(CollapseGuildTradeSkillHeader,id)end
 if ok and self.guild==G:GetGuildKey()then
  for guid,byID in pairs(gathered)do
   local rows={};for _,p in pairs(byID)do rows[#rows+1]=p end
   table.sort(rows,function(a,b)return a.id<b.id end)
   if #rows<=2 then self.professions[guid]=rows end
  end
 end
 self.reading=false
 if ok and self.guild==G:GetGuildKey()then self.scanSignature=signature;return true end
 self.scanSignature=nil;return false
end
function D:ProfessionName(member,slot)
 local row=member and self.guild==G:GetGuildKey()and self.professions[member.guid]
 local p=row and row[slot]
 if not p then return G.L.NO_NATIVE_DATA end
 local skill=p.skill
 return p.name..(type(skill)=="number"and skill==math.floor(skill)and skill>=0 and skill<=999 and (" ["..skill.."]")or "")
end
function D:RequestProfessions()
 if not IsInGuild()then return end
 self.forceRead=true
 self:ReadProfessions()
 if type(QueryGuildRecipes)~="function"or GetTime()<(self.nextQuery or 0)then return end
 self.nextQuery=GetTime()+30;self.awaitingQuery=true;pcall(QueryGuildRecipes)
end
-- Coalesce presentation work only. Admission, roster confirmation and pruning
-- keep their existing callbacks and timing.
function D:QueueRefresh()
 if self.pendingView then return end
 self.pendingView=true
 C_Timer.After(.25,function()
  D.pendingView=nil
  if D.pendingProfessions then
   D.pendingProfessions=nil
   if D.awaitingQuery then D.forceRead=true;D.awaitingQuery=nil end
   D:ReadProfessions()
  end
  local frame=G.MainWindow
  if frame and frame:IsShown()then G:UpdateMainWindow()end
 end)
end
function D:Initialize(frame)
 if self.frame then return end
 if G.MemberActions then G.MemberActions:Initialize(frame)end
 local events=CreateFrame("Frame");self.frame=events
 for _,ev in ipairs({"GUILD_TRADESKILL_UPDATE","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","GUILD_RANKS_UPDATE"})do events:RegisterEvent(ev)end
 events:SetScript("OnEvent",function(_,ev)
  -- Revoke immediately, but never blank an authorized column for routine data events.
  if ev=="PLAYER_GUILD_UPDATE"or not D:CanReadOfficer()then D:ClearOfficerDisplay()end
  if ev=="PLAYER_GUILD_UPDATE"then D.professions={};D.guild=nil;D.nextQuery=nil;D.scanSignature=nil;D.nativeViewSignature=nil;D.awaitingQuery=nil end
  if ev=="GUILD_TRADESKILL_UPDATE"then
   if D.reading or D.nativeReading then return end
   D.pendingProfessions=true
  end
  D:QueueRefresh()
 end)
 for _,row in ipairs(frame.rows)do self:AttachRow(row,frame)end
 frame:ApplyColumnWidths()
end

function D:AttachRow(row,frame)
  row.detailHits={}
  for i=1,12 do
   local index=i;local hit=CreateFrame("Button",nil,row);row.detailHits[i]=hit
   hit:SetHeight(row:GetHeight());hit:SetFrameLevel(row:GetFrameLevel()+2)
   hit:RegisterForClicks("LeftButtonUp","RightButtonUp")
   hit:SetScript("OnClick",function(_,button)
    local member=row.member;if not member then return end
    if button=="RightButton"and G.MemberActions then G.MemberActions:OpenMenu(member);return end
    local fn=row:GetScript("OnClick");if fn then fn(row)end
    if(index==9 or index==10)and G.MemberActions then G.MemberActions:OpenNote(member,index==10 and"officer"or"public")
    elseif index>=11 then D:OpenProfession(member,index-10)end
   end)
   hit:EnableMouseWheel(true);hit:SetScript("OnMouseWheel",frame.rosterWheel)
   hit:SetScript("OnEnter",function(o)
    if not row.member then return end
    local value
    if index==9 or index==10 then local public,officer=D:Notes(row.member);value=index==9 and public or officer
    elseif index>=11 then value=D:ProfessionName(row.member,index-10)
    elseif index==2 then value=row.member.class~=""and row.member.class or row.member.classFile or G.L.NO_NATIVE_DATA
    elseif index==1 then value=row.member.name
    else value=row.cells[index]:GetText()end
    GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:ClearLines();GameTooltip:AddLine(tostring(value or G.L.NO_NATIVE_DATA),1,1,1,true)
    GameTooltip:Show();D.tooltipOfficer=index==10
   end)
   local function hide()if GameTooltip:IsOwned(hit)then GameTooltip:Hide()end;if index==10 then D.tooltipOfficer=nil end end
   hit:SetScript("OnLeave",hide);hit:SetScript("OnHide",hide)
  end
 end
