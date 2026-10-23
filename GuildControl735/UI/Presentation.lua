-- Original local presentation helpers. No addon wire, permission or cache changes.
local _,G=...
local professions=G:RegisterLocaleTable({},function()return {
 {171,(G:Text("Алхимия")),"Alchemy"},{164,(G:Text("Кузнечное дело")),"Blacksmithing"},
 {333,(G:Text("Наложение чар")),"Enchanting"},{202,(G:Text("Инженерное дело")),"Engineering"},
 {182,(G:Text("Травничество")),"Herbalism"},{773,(G:Text("Начертание")),"Inscription"},
 {755,(G:Text("Ювелирное дело")),"Jewelcrafting"},{165,(G:Text("Кожевничество")),"Leatherworking"},
 {186,(G:Text("Горное дело")),"Mining"},{393,(G:Text("Снятие шкур")),"Skinning"},
 {197,(G:Text("Портняжное дело")),"Tailoring"}} end)
G.ProfessionLabels=professions
local states=G:RegisterLocaleTable({},function()return {
 {"all",(G:Text("Аддон и спеки: все"))},{"installed",(G:Text("Аддон установлен"))},
 {"filled",(G:Text("Аддон установлен, спеки заполнены"))},
 {"empty",(G:Text("Аддон установлен, спеки не заполнены"))},
 {"unknown",(G:Text("Установка не подтверждена"))}} end)
local fold={}
do
 local upper={"А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"}
 local small={"а","б","в","г","д","е","ё","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я"}
 for i,c in ipairs(upper)do fold[c]=small[i]end
end
local function lower(text)
 return (string.lower(tostring(text or "")):gsub("[\194-\244][\128-\191]+",fold))
end
function G:ProfessionMaximumWidth(measure)
 local maximum=0
 self:ApplyFont(measure,12)
 for _,p in ipairs(professions)do for i=2,3 do
  measure:SetText(p[i].." [999]");maximum=math.max(maximum,math.ceil(measure:GetStringWidth()+10))
 end end
 return maximum
end
function G:PresentationProfiles(member)
 local own=member.guid==UnitGUID("player")and self.Character and self.Character.Profile
 if own then return true,own:GetProfiles()end
 return self.SatelliteStore:Get(member)~=nil,self.SatelliteStore:GetProfiles(member)or{}
end
local function selection(state,key,legacy)
 if type(state[key])=="table"then return state[key]end
 local value=state[legacy]
 if key=="professions"then value=tonumber(value)end
 return value and value~="all"and {[value]=true}or{}
end
local function count(values,options)
 local n=0;for _,entry in ipairs(options)do if entry[1]~="all"and entry[1]~=-1 and values[entry[1]]==true then n=n+1 end end;return n
end
local professionOptions=G:RegisterLocaleTable({},function()return {{0,(G:Text("Нет данных"))}} end)
for _,p in ipairs(professions)do professionOptions[#professionOptions+1]=p end
function G:NormalizePresentationSelections()
 local f=self.db.filters
 if type(f.professions)~="table"then f.professions=selection(f,"professions","profession")end
 if type(f.addonStates)~="table"then f.addonStates=selection(f,"addonStates","addonState")end
end
function G:MatchesPresentationFilters(member,state)
 local choices=selection(state,"addonStates","addonState")
 if count(choices,states)>0 then
  local installed,profiles=self:PresentationProfiles(member)
  local match=(choices.installed==true and installed)or(choices.filled==true and installed and #profiles>0)
   or(choices.empty==true and installed and #profiles==0)or(choices.unknown==true and not installed)
  if not match then return false end
 end
 choices=selection(state,"professions","profession")
 if count(choices,professionOptions)>0 then
  local D=self.RosterDetails;local rows=D.guild==self:GetGuildKey()and D.professions[member.guid]or{}
  local match=choices[0]==true and #rows==0
  for _,p in ipairs(rows)do if choices[p.id]==true then match=true end end
  if not match then return false end
 end
 if self.PlayerCharacterFilter and not state.ignorePlayerCharacterFilter then
  local view=self.PlayerCharacterView
  if not view or view.guild~=self:GetGuildKey()or not view.ids[member.guid]then return false end
 end
 return true
end
function G:MatchesPresentationSearch(member,query)
 query=lower(query)
 local function has(s)return lower(s):find(query,1,true)~=nil end
 -- Recheck base fields with Cyrillic-aware folding, too.
 for _,s in ipairs({member.name or "",member.rank or "",member.class or "",member.zone or "",self:RosterFamilyStatus(member)})do if has(s)then return true end end
 local _,profiles=self:PresentationProfiles(member)
 for _,p in ipairs(profiles)do
  local _,name=GetSpecializationInfoByID(p.specID)
  if has(name)or has(self.L["ROLE_"..p.role]or p.role)then return true end
 end
 local public,officer=self.RosterDetails:Notes(member)
 -- Native rights/GUID checked at each read; text stays in this call only.
 if has(public)or has(officer)then return true end
 for i=1,2 do if has(self.RosterDetails:ProfessionName(member,i))then return true end end
 return false
end
function G:InitializePresentationFilters(frame)
 self:NormalizePresentationSelections()
 local function dropdown(name,x,width)
  local d=self.Dropdown.Create(name,frame);d:SetPoint("TOPLEFT",x,-146)
  self.Dropdown.SetWidth(d,width);self:ApplyFont(_G[name.."Text"],11);return d
 end
 frame.professionDropdown=dropdown("GC735ProfessionFilter",194,155)
 frame.addonDropdown=dropdown("GC735AddonFilter",392,280)
 self.Dropdown.Initialize(frame.professionDropdown,function(_,level)
  local options={{-1,(G:Text("Профессии: все"))},{0,self.L.NO_NATIVE_DATA}}
  for _,p in ipairs(professions)do options[#options+1]={p[1],GetLocale()=="ruRU"and p[2]or p[3]}end
  for _,entry in ipairs(options)do
   local id=entry[1];local info=G.Dropdown.CreateInfo();info.text=entry[2]
   info.checked=id==-1 and count(G.db.filters.professions,professionOptions)==0 or G.db.filters.professions[id]==true
   info.isNotRadio=true;info.keepShownOnClick=true;info.checkmark=true
   info.func=function()
    local selected=G.db.filters.professions
    if id==-1 then G.db.filters.professions={}else selected[id]=selected[id]~=true or nil end
    G:UpdateMainWindow()
   end
   G.Dropdown.AddButton(info,level)
  end
 end)
 self.Dropdown.Initialize(frame.addonDropdown,function(_,level)
  for _,entry in ipairs(states)do
   local id=entry[1];local info=G.Dropdown.CreateInfo();info.text=entry[2]
   info.checked=id=="all"and count(G.db.filters.addonStates,states)==0 or G.db.filters.addonStates[id]==true
   info.isNotRadio=true;info.keepShownOnClick=true;info.checkmark=true
   info.func=function()
    local selected=G.db.filters.addonStates
    if id=="all"then G.db.filters.addonStates={}else selected[id]=selected[id]~=true or nil end
    G:UpdateMainWindow()
   end
   G.Dropdown.AddButton(info,level)
  end
 end)
 self:AttachHelp(frame.professionDropdown,(G:Text("Профессии")),(G:Text("Отметьте одну или несколько профессий. Достаточно любой выбранной профессии в любом из двух столбцов. «Все» или пустой выбор снимает этот фильтр. Нет данных означает отсутствие доступной информации Blizzard. Остальные фильтры продолжают действовать.")))
 self:AttachHelp(frame.addonDropdown,(G:Text("Аддон и спеки")),(G:Text("Можно выбрать несколько состояний: достаточно любого отмеченного. «Все» или пустой выбор снимает этот фильтр. Заполненные спеки — хотя бы один сохранённый комплект. Нет подтверждения установки не означает отсутствие аддона. Сведения могут быть из кэша, а не от текущего живого клиента.")))
end
function G:UpdatePresentationFilterLabels(frame)
 self:NormalizePresentationSelections()
 local n=count(self.db.filters.professions,professionOptions)
 self.Dropdown.SetText(frame.professionDropdown,n>0 and((G:Text("Профессии: "))..n)or(G:Text("Профессии: Все")))
 n=count(self.db.filters.addonStates,states)
 self.Dropdown.SetText(frame.addonDropdown,n>0 and((G:Text("Аддон и спеки: "))..n)or states[1][2])
end
function G.RosterDetails:OpenProfession(member,slot)
 local function fail(text)G:Print(text);return false end
 if InCombatLockdown and InCombatLockdown()then return fail((G:Text("Просмотр профессии доступен вне боя.")))end
 local row=member and self.guild==G:GetGuildKey()and self.professions[member.guid]
 local p=row and row[slot]
 if not IsInGuild()or not p or type(CanViewGuildRecipes)~="function"or type(GetGuildMemberRecipes)~="function"then
  return fail((G:Text("Просмотр этой профессии недоступен.")))
 end
 -- Never carry a stale native index into a request for another character.
 local ok,guid=pcall(function()return select(17,GetGuildRosterInfo(member.index))end)
 if not ok or guid~=member.guid then return fail((G:Text("Состав изменился. Обновите состав перед просмотром профессии.")))end
 local allowed,can=pcall(CanViewGuildRecipes,p.id)
 if not allowed or not can then return fail((G:Text("Для этой профессии Blizzard не предоставляет просмотр рецептов.")))end
 if GetTime()<(self.nextOpen or 0)then return false end
 self.nextOpen=GetTime()+1
 local requested=pcall(GetGuildMemberRecipes,member.name,p.id)
 if not requested then return fail((G:Text("Не удалось запросить профессию у Blizzard.")))end
 return true
end
function G:SetCompactPageHeight(height)
 self.CompactPageHeight=height
 for _,id in ipairs({"satellite","settings"})do
  local page=self.Shell and self.Shell.pages[id];if page then page.height=height end
 end
 local settings=self.AdminTrust and self.AdminTrust.window
 if settings then settings:SetHeight(height)end
 if self.ShellWindow and self.Shell and(self.Shell.activePage=="satellite"or self.Shell.activePage=="settings")then
  self.ShellWindow:SetHeight(height)
 end
end

-- A read-only, stricter view of the existing admitted family records.
-- The service retains its own local-registration semantics and wire format.
local function hasMember(family,guid)
 for _,row in ipairs(family and family.members or{})do if row.guid==guid then return true end end
 return false
end
function G:PresentationFamily(member)
 local sync=self.FamilySync
 local base=sync:GetVerifiedFamily(member)
 if not base then return nil end
 local members,found={},{}
 local ownGUID=UnitGUID("player")
 local incomplete=base.trust=="FAMILY_CAPACITY"
 for _,row in ipairs(base.members)do
  -- The service's local first hop can include a character whose return claim
  -- is missing. Require its existing remote graph to reach us before display.
  local confirmed=member.guid~=ownGUID or row.guid==ownGUID
  if not confirmed then confirmed=hasMember(sync:GetVerifiedFamily(row),ownGUID)end
  if confirmed then members[#members+1]=row;found[row.guid]=true else incomplete=true end
 end
 local db=sync:GetDatabase()
 local localFamily=self.Character and self.Character.Family
 local own=localFamily and {members=localFamily:GetMembers()}
 for _,row in ipairs(members)do
  local claim=row.guid==ownGUID and own or db and db.snapshots[row.guid]or(self.GuildArchive and self.GuildArchive:Snapshot(row.guid))
  if not claim then incomplete=true else
   -- A known outgoing claim outside this mutual component is not proof of
   -- membership or of absence of another MAIN. Do not display its name.
   for _,peer in ipairs(claim.members or{})do
    if self.Roster:FindByKey(peer.guid)and not found[peer.guid]then incomplete=true end
   end
  end
 end
 table.sort(members,function(a,b)return a.guid<b.guid end)
 local result={members=members,incomplete=incomplete,trust="MUTUAL_PRESENTATION_ONLY"}
 local mains,unknown={},false
 for _,row in ipairs(members)do
  if not row.archived then
  local mark=self.OfficerMarks and self.OfficerMarks:Get(row.guid)
  if not mark then unknown=true elseif mark.marked then mains[#mains+1]=row end
 end
 end
 if #mains>1 then result.mainStatus="conflict"
 elseif incomplete or unknown then result.mainStatus="unknown"
 elseif #mains==1 then result.mainGUID=mains[1].guid;result.mainName=mains[1].name;result.mainStatus="assigned"
 else result.mainStatus="unset"end
 return result
end

-- Runtime-only guild-scoped roster view. No family declarations are written.
function G:ClearPlayerCharacterFilter(refresh)
 self.PlayerCharacterFilter=nil;self.PlayerCharacterView=nil
 local frame=self.MainWindow
 if frame and frame.playerFilter then frame.playerFilter:Hide()end
 if refresh~=false then self:UpdateMainWindow()end
end
function G:PreparePlayerCharacterFilter()
 local active=self.PlayerCharacterFilter;if not active then self.PlayerCharacterView=nil;return end
 local guild=self:GetGuildKey()
 if active.guild~=guild then self:ClearPlayerCharacterFilter(false);return end
 local member=self.Roster:FindByKey(active.guid)or(self.GuildArchive and self.GuildArchive:Member(active.guid))
 local family=member and self:PresentationFamily(member)
 local view={guild=guild,ids={},total=0,live=0,name=family and family.mainName or active.name,incomplete=family and family.incomplete}
 if family then
  for _,row in ipairs(family.members)do if not view.ids[row.guid]then view.ids[row.guid]=true;view.total=view.total+1;if self.Roster:FindByKey(row.guid)then view.live=view.live+1 end end end
 end
 self.PlayerCharacterView=view
end
function G:FilterPlayerCharacters(member)
 if not member or not self:GetGuildKey()then return false end
 local family=self:PresentationFamily(member)
 if not family or #family.members==0 then return false end
 self.PlayerCharacterFilter={guild=self:GetGuildKey(),guid=member.guid,name=member.name}
 self:PreparePlayerCharacterFilter()
 local frame=self.MainWindow
 local bar=frame and frame.scroll and _G[frame.scroll:GetName().."ScrollBar"]
 if bar then bar:SetValue(0)end
 self:UpdateMainWindow();return true
end
function G:InitializePlayerCharacterFilter(frame)
 local badge=CreateFrame("Frame",nil,frame);frame.playerFilter=badge
 badge:SetPoint("TOPLEFT",18,-178);badge:SetSize(frame.rosterViewport:GetWidth(),18)
 badge.label=badge:CreateFontString(nil,"ARTWORK","GameFontNormal");badge.label:SetPoint("LEFT",0,0)
 badge.label:SetJustifyH("LEFT");badge.label:SetWordWrap(false);badge.label:SetHeight(18);self:ApplyFont(badge.label,10)
 badge.close=CreateFrame("Button",nil,badge,"UIPanelButtonTemplate");badge.close:SetSize(20,18);badge.close:SetText("×");self:ApplyFont(badge.close:GetFontString(),11)
 badge.close:SetScript("OnClick",function()G:ClearPlayerCharacterFilter()end)
 self:AttachHelp(badge.close,(G:Text("Снять отбор")),(G:Text("Показать таблицу без отбора персонажей этого игрока. Остальные фильтры и ширины столбцов сохраняются.")))
 badge.detail=badge:CreateFontString(nil,"ARTWORK","GameFontHighlight");badge.detail:SetJustifyH("LEFT");badge.detail:SetWordWrap(false);badge.detail:SetHeight(18);self:ApplyFont(badge.detail,10)
 badge:EnableMouse(true)
 badge:SetScript("OnEnter",function(o)
  GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:ClearLines();GameTooltip:AddLine(o.label:GetText(),1,.82,0,true)
  GameTooltip:AddLine(o.detail:GetText(),1,1,1,true);GameTooltip:AddLine((G:Text("Отбор использует только подтверждённые связи. Остальные фильтры и поиск продолжают действовать. Крестик снимает только этот отбор; «Сбросить фильтры» очищает все фильтры.")),1,1,1,true);GameTooltip:Show()
 end)
 badge:SetScript("OnLeave",function()GameTooltip:Hide()end)
 badge:SetScript("OnHide",function(o)if GameTooltip:IsOwned(o)then GameTooltip:Hide()end end);badge:Hide()
end
function G:UpdatePlayerCharacterFilterLabel(frame,shown)
 local badge=frame.playerFilter;if not badge then return end
 local view=self.PlayerCharacterView
 if not self.PlayerCharacterFilter or not view then badge:Hide();return end
 local width=frame.rosterViewport:GetWidth();badge:SetWidth(width)
 badge.label:SetText((G:Text("Персонажи игрока: "))..(view.name or ""))
 local labelWidth=math.min(math.ceil(badge.label:GetStringWidth())+4,math.floor(width*.5))
 badge.label:SetWidth(labelWidth);badge.close:ClearAllPoints();badge.close:SetPoint("LEFT",badge,"LEFT",labelWidth+2,0)
 badge.detail:ClearAllPoints();badge.detail:SetPoint("LEFT",badge.close,"RIGHT",8,0);badge.detail:SetWidth(math.max(1,width-labelWidth-32))
 local detail
 if view.total==0 then detail=(G:Text("Нет подтверждённых данных о связях."))
 else
  local live=view.live or view.total
  detail=(G:Text("В гильдии: "))..live..(G:Text(" из "))..view.total
  if shown<live then detail=detail..(G:Text("; показано: "))..shown..(G:Text(" из "))..live end
 end
 if view.incomplete then detail=detail..(G:Text(" Связи неполные."))end
 badge.detail:SetText(detail);badge:Show()
end
