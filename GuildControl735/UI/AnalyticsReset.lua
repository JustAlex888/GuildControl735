local _,G=...
function G:CreateAnalyticsReset(f,id,s,definitions,refresh)
 local button=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.resetFilters=button
 button:SetSize(180,26);button:SetPoint("TOPRIGHT",-48,-158);button:SetText((G:Text("Сбросить фильтры")));G:ApplyFont(button:GetFontString(),12)
 button:SetScript("OnClick",function()
  G.Dropdown.Close()
  -- Commit any active edit before disabling its restriction; keep entered values.
  for _,key in ipairs({"onlineEdit","responseEdit","period","startEdit","endEdit"})do
   local edit=f[key];if edit and edit.ClearFocus and(key~="period"or id=="mythic")then edit:ClearFocus()end
  end
  for _,key in ipairs({"onlineEnabled","responseEnabled","onlineOnly","periodEnabled","timeEnabled"})do s[key]=false end
  for k in pairs(s.classes)do s.classes[k]=nil end
  if s.roles then for k in pairs(s.roles)do s.roles[k]=nil end end
  if id=="pvp"then s.period="season";s.mode="all";f.period:SetText((G:Text("Сезон")));f.mode:SetText((G:Text("Общая статистика")))end
  if id=="raid"then
   s.raid=5;s.difficulty=3;f.raid:SetText(G.RaidWire.raids[5].name);f.difficulty:SetText((G:Text("Героический")));G.RaidAnalytics:EnableAllColumns(s)
  end
  local list=type(definitions)=="function"and definitions()or definitions
  for _,d in ipairs(list)do if not d[3]then s.columns[d[1]]=true end end
  for _,key in ipairs({"onlineCheck","responseCheck","onlineOnly","periodCheck","timeCheck"})do if f[key]then f[key]:SetChecked(false)end end
  if f.scroll then f.scroll.offset=0 end
  G.AnalyticsSearch:Set(id,"");f.nameSearch:SetText("");f.nameSearch:ClearFocus()
  refresh()
 end)
 G:AttachHelp(button,(G:Text("Сбросить фильтры")),(G:Text("Снять ограничения, очистить имя, показать все классы/роли и включить все столбцы этого раздела. PvP: сезон и общая статистика. Рейды: Анторус, героический. Значения дней/часов, ширины и размер окна сохраняются.")))
 return button
end
