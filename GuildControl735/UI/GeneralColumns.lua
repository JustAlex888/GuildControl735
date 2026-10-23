-- General-page presentation only. Keep original column indexes/click handlers.
local _,G=...
local optional={satellite=true,family=true,lastOnline=true,zone=true,note=true,officerNote=true,profession1=true,profession2=true}
function G:RosterColumnState()
 self.db.ui=self.db.ui or{}
 local state=self.db.ui.rosterColumns
 if type(state)~="table"then state={};self.db.ui.rosterColumns=state end
 return state
end
function G:IsRosterColumnVisible(key)
 return not optional[key]or self:RosterColumnState()[key]~=false
end
function G:InitializeGeneralColumns(frame)
 local d=self.Dropdown.Create("GC735RosterColumns",frame);frame.columnsDropdown=d
 self:ApplyFont(d:GetFontString(),11)
 function frame:UpdateColumnsCaption()
  local count=0
  for _,c in ipairs(self.columns)do if optional[c.key]and G:IsRosterColumnVisible(c.key)then count=count+1 end end
  G.Dropdown.SetText(d,count==8 and(G:Text("Столбцы: Все"))or((G:Text("Столбцы: "))..count.."/8"))
 end
 local function apply()
  if frame.StopColumnDrag then frame.StopColumnDrag()end
  frame:ApplyColumnWidths();frame:UpdateColumnsCaption()
 end
 function frame:ShowAllColumns()
  local state=G:RosterColumnState()
  for key in pairs(optional)do state[key]=nil end
  apply()
 end
 self.Dropdown.Initialize(d,function(_,level)
  local all=G.Dropdown.CreateInfo();all.text=(G:Text("Все столбцы"));all.func=function()frame:ShowAllColumns()end
  G.Dropdown.AddButton(all,level)
  for _,c in ipairs(frame.columns)do
   if optional[c.key]then
    local key=c.key;local info=G.Dropdown.CreateInfo()
    info.text=(G.L[c.label]or key):gsub("\n"," ");info.checked=G:IsRosterColumnVisible(key)
    info.keepShownOnClick=true;info.isNotRadio=true;info.checkmark=true
    info.func=function()G:RosterColumnState()[key]=not G:IsRosterColumnVisible(key);apply()end
    G.Dropdown.AddButton(info,level)
   end
  end
 end)
 self:AttachHelp(d,(G:Text("Столбцы")),(G:Text("Имя, класс, уровень и звание видны всегда. Отметьте дополнительные столбцы. Выбор сохраняется; данные, поиск и действия видимых ячеек остаются прежними. «Все столбцы» включает все восемь дополнительных.")))
 frame:UpdateColumnsCaption()
end
function G:CompactGeneralFilters(frame)
 -- Measure the longest button captions in the existing font; menus keep
 -- their own minimum width, independent of the compact buttons.
 local function width(button,captions)
  local label=button:GetFontString();local old=label:GetText();local w=0
  for _,s in ipairs(captions)do label:SetText(s);w=math.max(w,math.ceil(label:GetStringWidth()+20))end
  label:SetText(old);button:SetWidth(w);return w
 end
 local function place(button,x,y)
  button:ClearAllPoints();button:SetPoint("TOPLEFT",x,-y)
  return x+button:GetWidth()+6
 end
 local L=self.L
 width(frame.classDropdown,{L.CLASS_ALL,string.format(L.CLASS_SELECTED,12)})
 width(frame.rankDropdown,{L.RANK_ALL,string.format(L.RANK_SELECTED,10)})
 width(frame.inactivityDropdown,{L.INACTIVE_ALL,string.format(L.INACTIVE_PREFIX,365)})
 frame.classDropdown.minimumMenuWidth=240;frame.rankDropdown.minimumMenuWidth=240
 frame.inactivityDropdown.minimumMenuWidth=240
 local x=18
 x=place(frame.classDropdown,x,103);x=place(frame.rankDropdown,x,103);x=place(frame.inactivityDropdown,x,103)
 frame.rangeFromLabel:ClearAllPoints();frame.rangeFromLabel:SetPoint("TOPLEFT",x+4,-113)
 frame.levelFrom:ClearAllPoints();frame.levelFrom:SetPoint("LEFT",frame.rangeFromLabel,"RIGHT",8,0)
 frame.rangeToLabel:ClearAllPoints();frame.rangeToLabel:SetPoint("LEFT",frame.levelFrom,"RIGHT",8,0)
 frame.levelTo:ClearAllPoints();frame.levelTo:SetPoint("LEFT",frame.rangeToLabel,"RIGHT",8,0)
 width(frame.professionDropdown,{(G:Text("Профессии: Все")),(G:Text("Профессии: 12"))})
 width(frame.addonDropdown,{(G:Text("Аддон и спеки: все")),(G:Text("Аддон и спеки: 4"))})
 width(frame.columnsDropdown,{(G:Text("Столбцы: Все")),(G:Text("Столбцы: 8/8"))})
 width(frame.resetFilters,{L.RESET_FILTERS})
 frame.professionDropdown.minimumMenuWidth=290;frame.addonDropdown.minimumMenuWidth=360
 frame.columnsDropdown.minimumMenuWidth=250
 x=22+32+math.ceil(frame.onlineOnly.text:GetStringWidth())+8
 x=place(frame.professionDropdown,x,146);x=place(frame.addonDropdown,x,146)
 x=place(frame.columnsDropdown,x,146);place(frame.resetFilters,x,146)
end
