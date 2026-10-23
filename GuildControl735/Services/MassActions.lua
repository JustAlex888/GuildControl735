-- Runtime-only guild action plan. Dispatch only through physical secure clicks.
local _,G=...
local A={maxBytes=255,timeout=45};G.MassActions=A
-- Full macro budget, including localized command, UTF-8 names and newlines.
-- Every subsequent portion still requires another physical click.
function A:TestByteLimit(command)return 255 end
local function copy(t)
 if type(t)~='table'then return t end
 local r={};for k,v in pairs(t)do r[k]=copy(v)end;return r
end
A.Copy=copy
local function safe(s)return type(s)=='string'and s~=''and not s:find('[%s%z\1-\31\127|/;%%]')end
local function log(k,s)if G.Diagnostics then G.Diagnostics:Record('MASS_'..k,s)end end
-- Compare client-localized constants, never broad words such as "guild".
-- Formatted errors must name a target in the submitted/armed portion.
function A:RemovalError(message)
 if type(message)~='string'then return false end
 for _,key in ipairs({'ERR_GUILD_PERMISSIONS','ERR_GUILD_PLAYER_NOT_IN_GUILD','ERR_GUILD_NOT_IN_A_GUILD','ERR_GUILD_INTERNAL','ERR_GUILD_RANKS_LOCKED'})do
  if type(_G[key])=='string'and message==_G[key]then return true end
 end
 local batch=self.armed or(self.pending and self.pending.entries)or{}
 for _,key in ipairs({'ERR_GUILD_PLAYER_NOT_FOUND_S','ERR_GUILD_PLAYER_NOT_IN_GUILD_S','ERR_GUILD_RANK_TOO_HIGH_S','ERR_GUILD_RANK_TOO_LOW_S','ERR_GUILD_CANT_PROMOTE_S','ERR_GUILD_CANT_DEMOTE_S'})do
  local template=_G[key]
  if type(template)=='string'then
   for _,entry in ipairs(batch)do
    for _,name in ipairs({entry.name,(entry.name:match('^([^-]+)'))})do
     local ok,text=pcall(string.format,template,name)
     if ok and text==message then return true end
    end
   end
  end
 end
 return false
end
local function diagnosticValue(value)
 return tostring(value):gsub('[%z\1-\31\127]',' '):gsub('|','||'):sub(1,600)
end
local function combat()return InCombatLockdown and InCombatLockdown()end
function A:Notify()if self.changed then self.changed()end end
function A:Native()
 if not IsInGuild()then return nil,'outside_guild'end
 local count=GetNumGuildMembers(true)
 if type(count)~='number'or count<1 or count>1500 then return nil,'invalid_count'end
 local map={}
 for i=1,count do
  local n,_,rank,_,_,_,_,_,online,_,_,_,_,_,_,_,guid=GetGuildRosterInfo(i)
  if not guid or not n or type(rank)~='number'then return nil,'incomplete_row_'..i end
  if guid then
   if map[guid]then return nil,'duplicate_guid'end
   map[guid]={name=n,rank=rank,online=online==true}
  end
 end
 if not map[UnitGUID('player')]then return nil,'missing_actor'end
 local _,_,rank=GetGuildInfo('player')
 if map[UnitGUID('player')].rank~=rank then return nil,'actor_rank_mismatch'end
 local ids={};for guid,row in pairs(map)do ids[#ids+1]=guid..':'..row.name..':'..row.rank..':'..tostring(row.online)end;table.sort(ids)
 return map,table.concat(ids,';')
end
function A:RankSignature()
 local n=GuildControlGetNumRanks();if type(n)~='number'or n<2 or n>10 then return end
 local names={};for i=1,n do local name=GuildControlGetRankName(i);if type(name)~='string'or name==''then return end;names[i]=name end
 return table.concat(names,'\n')
end
function A:Eligible(guid,row,kind,destination)
 kind=kind or'remove'
 if kind~='remove'then
  if not row or not safe(row.name)or type(row.rank)~='number'then return false end
  local expected=kind=='rank'and destination or row.rank+(kind=='promote'and-1 or 1)
  local c=G.MemberManagement:Allowed({guild=G:GetGuildKey(),guid=guid},'rank',expected)
  if not c or c.row.name~=row.name or c.row.rank~=row.rank then return false end
  local step=expected<row.rank and-1 or 1
  for rank=row.rank+step,expected,step do
   local ok,allowed=pcall(IsGuildRankAssignmentAllowed,c.row.index,rank+1)
   if not ok or allowed~=true then return false end
  end
  return true
 end
 local _,_,rank=GetGuildInfo('player')
 return row and safe(row.name)and type(row.rank)=='number'and type(rank)=='number'
  and guid~=UnitGUID('player')and row.rank>=1 and row.rank>rank
  and type(CanGuildRemove)=='function'and CanGuildRemove()==true
end
function A:Context()
 local s=self.state
 return s and IsInGuild()and not combat()and UnitGUID('player')==s.actor and G:GetGuildKey()==s.guild
end
function A:Stop(reason)
 local s=self.state;if not s then return end
 s.stopped=true;s.reason=reason or(G:Text('Остановлено пользователем.'))
 if self.disarm then self.disarm()end
 for _,e in ipairs(s.entries)do if e.status=='ready'then e.status='stopped';e.detail=s.reason end end
 log('STOP',s.reason);self:Notify()
end
function A:Prepare(selected,filters,sort,kind,destination)
 kind=kind or'remove';if kind~='remove'and kind~='promote'and kind~='demote'and kind~='rank'then return false,(G:Text('Неизвестное действие.'))end
 if kind=='rank'then
  local _,_,actorRank=GetGuildInfo('player')
  if type(destination)~='number'or destination%1~=0 or type(actorRank)~='number'or destination<=actorRank or destination>=GuildControlGetNumRanks()then return false,(G:Text('Выберите доступное звание.'))end
 end
 if self.pending then return false,(G:Text('Дождитесь результата уже отправленной порции.'))end
 if combat()or not IsInGuild()then return false,(G:Text('Управление недоступно в бою или вне гильдии.'))end
 if type(G:GetGuildKey())~='string'or G:GetGuildKey()==''or type(UnitGUID('player'))~='string'then return false,(G:Text('Не получена идентичность гильдии или персонажа.'))end
 local Q,M=G.MemberManagement,G.MemberActions
 if Q.state or(M.state and(M.state.pending or M:Dirty()))then return false,(G:Text('Сначала завершите одиночное действие или редактирование заметок.'))end
 local native=self:Native();if not native then return false,(G:Text('Не получен полный состав. Обновите состав.'))end
 G.Roster:Rebuild()
 local f=copy(filters);f.ignorePlayerCharacterFilter=true
 local entries={};local seen={}
 for _,m in ipairs(G.Filters:BuildView(G.Roster.members,filters,sort))do
  if selected[m.guid]and not seen[m.guid]then
   seen[m.guid]=true;local row=native[m.guid]
   local ok=self:Eligible(m.guid,row,kind,destination)
   entries[#entries+1]={guid=m.guid,name=m.name,rank=m.rank,rankIndex=m.rankIndex,online=m.online,
    offlineDays=m.offlineDays,status=ok and'ready'or'skipped',detail=ok and''or(kind=='rank'and row and row.rank==destination and(G:Text('Уже имеет выбранное звание.'))or(G:Text('Недоступно по текущим правам или составу.')))}
  end
 end
 if #entries==0 then return false,(G:Text('Выберите участников в отфильтрованном списке.'))end
 local ranks=kind~='remove'and self:RankSignature()or nil
 if kind~='remove'and not ranks then return false,(G:Text('Не получены названия званий.'))end
 for _,e in ipairs(entries)do
  if kind~='remove'then
   e.expected=kind=='rank'and destination or e.rankIndex+(kind=='promote'and-1 or 1)
   e.originalRank=e.rank
   if e.expected>=1 and e.expected<GuildControlGetNumRanks()then e.destinationName=GuildControlGetRankName(e.expected+1)end
  end
 end
 local _,_,actorRank=GetGuildInfo('player')
 self.state={actor=UnitGUID('player'),actorRank=actorRank,guild=G:GetGuildKey(),kind=kind,ranks=ranks,filters=f,sort=copy(sort),entries=entries,attempt=0}
 self.armed=nil;log('PREVIEW','selected='..#entries..' action='..kind);self:Notify();return true
end
function A:PreClick(button)
 self.armed=nil;if self.disarm then self.disarm()end
 local s=self.state
 if button~='LeftButton'or not s or s.stopped or self.pending then return end
 if not self:Context()then self:Stop((G:Text('Изменился персонаж, гильдия или начался бой.')));return end
 if G.Shell.activePage~='general'or not G.MassRoster.enabled or not G.MassRoster.confirm:IsShown()then return end
 if G.MemberManagement.state or G.MemberActions.state then self:Stop((G:Text('Открыто другое действие с участником.')));return end
 if G.MassRoster.filterSignature~=G.MassRoster:FilterSignature()then G.MassRoster:FilterChanged();return end
 local native=self:Native();if not native then self:Stop((G:Text('Не получен полный состав.')));return end
 if s.kind~='remove'and(s.ranks~=self:RankSignature()or native[s.actor].rank~=s.actorRank)then self:Stop((G:Text('Изменились звания гильдии или права управляющего.')));return end
 G.Roster:Rebuild()
 local matching={};for _,m in ipairs(G.Filters:BuildView(G.Roster.members,s.filters,s.sort))do matching[m.guid]=m end
 local command=G.MemberManagement:Command(s.kind=='rank'and'promote'or s.kind);self.maxBytes=self:TestByteLimit(command);local lines,batch={},{};local bytes=0
 for _,e in ipairs(s.entries)do
  if e.status=='ready'then
   local row=native[e.guid];local member=matching[e.guid]or(e.progressConfirmed and G.Roster:FindByKey(e.guid))
   if not self:Eligible(e.guid,row,s.kind,e.expected)or not member or row.name~=e.name or row.rank~=e.rankIndex or row.online~=e.online then
    e.status='skipped';e.detail=(G:Text('Изменились данные, фильтр или права.'));log('SKIP',e.name..'; changed context')
   else
    local direction=s.kind=='rank'and(e.expected<row.rank and'promote'or'demote')or s.kind
    local target=direction=='demote'and G.MemberManagement:DemotionTarget({name=row.name,guid=e.guid})or row.name
    local line=safe(target)and(G.MemberManagement:Command(direction)..' '..target)or string.rep(' ',256)
    if #line>self.maxBytes then e.status='skipped';e.detail=(G:Text('Команда длиннее допустимой порции.'))
    else
     local count=s.kind=='remove'and 1 or math.abs(e.expected-row.rank);local issued=0
     for i=1,count do
      local size=#line+(#lines>0 and 1 or 0);if bytes+size>self.maxBytes then break end
      lines[#lines+1]=line;bytes=bytes+size;issued=issued+1
     end
     if issued>0 then
      e.portionExpected=s.kind~='remove'and(row.rank+(direction=='promote'and-issued or issued))or nil
      e.commandCount=issued;batch[#batch+1]=e
     end
     if issued<count then break end
    end
   end
  end
 end
 if #batch==0 then self:Notify();return end
 self.armed=batch;return table.concat(lines,'\n')
end
function A:PostClick(button)
 local batch=self.armed;self.armed=nil
 if self.disarm then self.disarm()end
 if button~='LeftButton'or not batch then return end
 local s=self.state;s.attempt=s.attempt+1
 for _,e in ipairs(batch)do e.status='pending';e.detail=(G:Text('Команда отправлена; ожидаем обновление состава.'));log('REQUEST',e.name..' attempt='..s.attempt..' action='..s.kind..(e.expected and(' from='..e.rankIndex..' to='..e.expected..' portionTo='..e.portionExpected..' commands='..e.commandCount)or''))end
 self.pending={entries=batch,deadline=GetTime()+self.timeout,rosterSeen=false,nextPoll=GetTime(),nextRequest=GetTime()+3}
 if not self:Context()then self:Stop((G:Text('Контекст изменился во время нажатия.')))end
 G.Roster:RequestRefresh()
 self:Notify()
end
function A:ObserveRoster()
 local p=self.pending;if not p then return end
 if not self:Context()then self:Stop((G:Text('Изменился контекст; новые порции отменены.')));return end
 local native,signature=self:Native()
 if not native then if p.lastInvalid~=signature then p.lastInvalid=signature;log('ROSTER_WAIT',signature)end;return end
 local s=self.state
 if s.kind~='remove'and(s.ranks~=self:RankSignature()or native[s.actor].rank~=s.actorRank)and not s.stopped then self:Stop((G:Text('Изменились звания гильдии или права управляющего.')))end
 if p.nativeSignature~=signature then p.nativeSignature=signature;for _,e in ipairs(p.entries)do e.absentAt=nil end;log('ROSTER_SAMPLE','attempt='..self.state.attempt..' eventSeen='..tostring(p.rosterSeen))end
 local waiting=false
 for _,e in ipairs(p.entries)do
  if e.status=='pending'then
   local row=native[e.guid]
   local issued=e.portionExpected or e.expected
   local confirmed=s.kind=='remove'and not row or s.kind~='remove'and row and row.name==e.name and row.rank==issued and s.ranks==self:RankSignature()
   if confirmed then
    if not e.absentAt then e.absentAt=GetTime();waiting=true
    elseif GetTime()-e.absentAt<.25 then waiting=true
    elseif s.kind~='remove'and issued~=e.expected then
     e.rankIndex=issued;e.rank=GuildControlGetRankName(issued+1);e.progressConfirmed=true;e.portionExpected=nil;e.absentAt=nil
     e.status=s.stopped and'stopped'or'ready';e.detail=(G:Text('Промежуточное звание подтверждено. Продолжение — следующей порцией.'));log('RANK_PROGRESS',e.name..' rank='..issued..' target='..e.expected)
    else e.status='done';e.detail=s.kind=='remove'and(G:Text('Отсутствие GUID подтверждено обновлением состава.'))or((G:Text('Звание подтверждено составом: '))..e.destinationName);log('CONFIRMED',e.name..(e.expected and(' action='..s.kind..' rank='..e.expected)or''))end
   elseif s.kind~='remove'and row and(row.name~=e.name or(row.rank~=e.rankIndex and not(row.rank>math.min(e.rankIndex,issued)and row.rank<math.max(e.rankIndex,issued))))then
    e.status='unknown';e.detail=(G:Text('Обнаружено другое изменение звания. Повтора нет.'));self:Stop(e.detail)
   else e.absentAt=nil;waiting=true end
  end
 end
 if not waiting then self.pending=nil;G.Roster:Rebuild()end
 self:Notify()
end
function A:Tick()
 local p=self.pending;local now=GetTime()
 if p then
  if now>=(p.nextRequest or 0)then p.nextRequest=now+3;if G.Roster:RequestRefresh()then log('ROSTER_REQUEST','attempt='..tostring(self.state.attempt))end end
  if now>=(p.nextPoll or 0)then p.nextPoll=now+.5;self:ObserveRoster()end
 end
 if self.state and not self:Context()and not self.state.stopped then self:Stop((G:Text('Смена персонажа, гильдии или бой.')))end
 if self.pending and GetTime()>=self.pending.deadline then
  for _,e in ipairs(self.pending.entries)do if e.status=='pending'then e.status='unknown';e.detail=(G:Text('Нет подтверждения. Автоматического повтора нет.'));log('TIMEOUT',e.name)end end
  self.pending=nil;self:Stop((G:Text('Ожидание результата истекло. Проверьте состав.')))
 end
end
function A:Counts()
 local counts={ready=0,pending=0,done=0,skipped=0,stopped=0,unknown=0}
 for _,e in ipairs(self.state and self.state.entries or{})do counts[e.status]=(counts[e.status]or 0)+1 end
 return counts
end
local f=CreateFrame('Frame');A.frame=f
for _,event in ipairs({'GUILD_ROSTER_UPDATE','GUILD_RANKS_UPDATE','PLAYER_GUILD_UPDATE','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PLAYER_LOGOUT','ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN','UI_ERROR_MESSAGE'})do f:RegisterEvent(event)end
f:SetScript('OnEvent',function(_,event,owner,fn)
 if event=='GUILD_ROSTER_UPDATE'then
  if A.pending then
   A.pending.rosterSeen=true
   if not A.rosterQueued then A.rosterQueued=true;C_Timer.After(.25,function()A.rosterQueued=nil;A:ObserveRoster()end)end
  end
 elseif event=='GUILD_RANKS_UPDATE'then if A.state and A.state.kind~='remove'and A.state.ranks~=A:RankSignature()then A:Stop((G:Text('Изменились звания гильдии.')))end
 elseif event=='PLAYER_REGEN_ENABLED'then if G.MassRoster and G.MassRoster.deferClose then G.MassRoster:CloseConfirmation()end
 elseif event=='PLAYER_GUILD_UPDATE'then if A.state and not A:Context()then A:Stop((G:Text('Сменилась гильдия.')))end
 elseif event=='PLAYER_REGEN_DISABLED'or event=='PLAYER_LOGOUT'then A:Stop(event=='PLAYER_LOGOUT'and(G:Text('Выход/reload.'))or(G:Text('Начался бой.')))
 elseif (A.pending or A.armed)and event=='UI_ERROR_MESSAGE'then
  local relevant=A:RemovalError(fn)
  log('UI_ERROR','id='..diagnosticValue(owner)..'; action='..tostring(A.state and A.state.kind)..'; relevant='..tostring(relevant)..'; text='..diagnosticValue(fn))
  if relevant then A:Stop((G:Text('Ошибка действия: '))..diagnosticValue(fn)..(G:Text('. Новые порции отменены.')))end
 elseif (A.pending or A.armed)and(owner=='GuildControl735'or fn=='GuildUninvite'or fn=='GuildUninvite()'or fn=='GuildPromote'or fn=='GuildPromote()'or fn=='GuildDemote'or fn=='GuildDemote()')then
  log('BLOCK','event='..diagnosticValue(event)..'; addon='..diagnosticValue(owner)..'; function='..diagnosticValue(fn))
  A:Stop((G:Text('Блокировка '))..diagnosticValue(event)..': '..diagnosticValue(fn)..(G:Text('. Новые порции отменены.')))
 end
end)
local elapsed=0;f:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>=.25 then elapsed=0;A:Tick()end end)
