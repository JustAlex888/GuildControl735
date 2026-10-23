local _,GC=...
function GC:InitializeAdminTrustUI()
 local T=GC.AdminTrust
 local host=GC.Shell.frame
 local f=CreateFrame("Frame","GuildControl735AdminTrustWindow",host)
 local height=GC.CompactPageHeight or 490
 T.window=f;f:SetSize(780,height);f:SetPoint("TOPLEFT",host,"TOPLEFT",0,0);f:EnableMouse(true);f:Hide()
 f:SetScript("OnMouseDown",function(_,b)if b=="LeftButton" then local fn=host:GetScript("OnMouseDown");if fn then fn(host,b)end end end)
 f:SetScript("OnMouseUp",function(_,b)local fn=host:GetScript("OnMouseUp");if fn then fn(host,b)end end)
 local title=f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge");title:SetPoint("TOPLEFT",24,-24);title:SetText((GC:Text("Доверенные звания")))
 local text=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");text:SetPoint("TOPLEFT",24,-60);text:SetWidth(340);text:SetJustifyH("LEFT")
 text:SetText((GC:Text("Выбранные звания могут запрашивать данные игроков.\nНастройку задаёт и передаёт участникам глава гильдии.")))
 GC.SpamShield:SetEnabled(true) -- automatic protection; legacy OFF is diagnostic only
 local draftMask,draftKey,draftLeader=1,nil,nil
 local selector=GC.Dropdown.Create("GuildControl735TrustedRanksDropdown",f)
 selector:SetPoint("TOPLEFT",24,-154);GC.Dropdown.SetWidth(selector,304)
 local function selectedCount()
  local n=0;for i=1,math.min(GuildControlGetNumRanks()or 0,10)do if math.floor(draftMask/2^(i-1))%2==1 then n=n+1 end end;return n
 end
 local function caption()GC.Dropdown.SetText(selector,(GC:Text("Доверенные звания: выбрано "))..selectedCount())end
 GC.Dropdown.Initialize(selector,function(_,level)
  T:Refresh();local leader=T:IsLeader()
  for i=1,math.min(GuildControlGetNumRanks()or 0,10)do
   local index=i;local info=GC.Dropdown.CreateInfo()
   info.text=i..". "..(GuildControlGetRankName(i)or "")
   info.checked=math.floor(draftMask/2^(i-1))%2==1;info.disabled=not leader or i==1
   info.isNotRadio=true;info.keepShownOnClick=true;info.checkmark=true
   info.func=function()
    T:Refresh()
    if index==1 or not T:IsLeader()or T.key~=draftKey or T.leader~=draftLeader then return end
    local bit=2^(index-1)
    draftMask=draftMask+(math.floor(draftMask/bit)%2==1 and -bit or bit);caption()
   end
   GC.Dropdown.AddButton(info,level)
  end
 end)
 GC:ApplyFont(selector:GetFontString(),12)
 GC:AttachHelp(selector,(GC:Text("Доверенные звания")),(GC:Text("Отметьте несколько званий. Глава включён всегда. Выбор применяется только кнопкой «Сохранить и передать гильдии» и только главой гильдии.")))
 f.trustSelector=selector
 local status=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");status:SetPoint("TOPLEFT",24,-202);status:SetWidth(340);status:SetJustifyH("LEFT")
 local save=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");save:SetSize(344,28);save:SetPoint("TOPLEFT",24,-252);save:SetText((GC:Text("Сохранить и передать гильдии")))
 save:SetScript("OnClick",function()
  T:Refresh()
  if T.key~=draftKey or T.leader~=draftLeader then status:SetText((GC:Text("Состав или глава изменились. Откройте настройки заново.")));return end
  if T:Save(draftMask)then status:SetText((GC:Text("Сохранено. Настройки передаются участникам.")))else status:SetText((GC:Text("Настройки может менять только глава гильдии.")))end
 end)
 f:HookScript("OnHide",function()if GC.Dropdown.active==selector then GC.Dropdown.Close()end end)
 f:SetScript("OnShow",function()
  T:Refresh();local leader=T:IsLeader();local p=T:Policy();local mask=p and p.mask or 1
  draftMask=mask;draftKey=T.key;draftLeader=T.leader;caption()
  save:SetEnabled(leader)
  status:SetText(p and (GC:Text("Действуют сохранённые настройки главы."))or(leader and (GC:Text("Выберите звания и сохраните настройки."))or (GC:Text("Настройки главы ещё не получены. Доступ есть только у главы."))))
 end)
 GC:ApplyFont(title,16);GC:ApplyFont(text,12);GC:ApplyFont(status,11);GC:ApplyFont(save:GetFontString(),11)

 GC:CreateDiagnosticSettings(f)
 GC.Shell:Register("settings",{width=780,height=height,Hide=function()f:Hide()end,Show=function()f:Show()end})
end
