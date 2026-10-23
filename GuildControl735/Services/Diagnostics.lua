-- Local bounded breadcrumbs. No network, global error-handler replacement or protected hooks.
local addonName,GC=...
local D={limit=400,fieldLimit=240};GC.Diagnostics=D
local function Clean(v)
 if type(v)~="string" and type(v)~="number" and type(v)~="boolean" then return "" end
 local s=tostring(v):gsub("[%c]"," ")
 local limit=D.fieldLimit
 if #s<=limit then return s end
 local cut=limit
 while cut>0 and s:byte(cut)>=128 and s:byte(cut)<192 do cut=cut-1 end
 local b=s:byte(cut)or 0
 local width=b>=240 and 4 or b>=224 and 3 or b>=192 and 2 or 1
 if cut+width-1>limit then return s:sub(1,cut-1)end
 return s:sub(1,limit)
end
function D:Record(kind,detail)
 if not self.db then return end
 local t=self.db
 t.sequence=t.sequence+1
 t.entries[#t.entries+1]={n=t.sequence,session=t.session,at=date("%Y-%m-%d %H:%M:%S"),kind=Clean(kind),detail=Clean(detail),
  observer=Clean(self.observer),observerGUID=Clean(self.observerGUID)}
 if #t.entries>self.limit then table.remove(t.entries,1)end
end
function D:Initialize(db)
 local t=db.diagnostics
 if type(t)~="table" or t.schema~=1 then t={schema=1,sequence=0,session=0,entries={}};db.diagnostics=t end
 if type(t.entries)~="table"then t.entries={}end
 local entries={}
 for _,e in ipairs(t.entries)do
  if type(e)=="table"then entries[#entries+1]={n=tonumber(e.n)or 0,session=tonumber(e.session)or 0,at=Clean(e.at),kind=Clean(e.kind),detail=Clean(e.detail),
   observer=Clean(e.observer),observerGUID=Clean(e.observerGUID)}end
 end
 while #entries>self.limit do table.remove(entries,1)end
 t.entries=entries;t.sequence=tonumber(t.sequence)or 0;t.session=(tonumber(t.session)or 0)+1;self.db=t
 self:Record("SESSION",GC.version.." / "..GC.build)
end
function D:SetObserver()
 local guid=UnitGUID and UnitGUID("player")or""
 local m=GC.Roster and GC.Roster.FindByKey and GC.Roster:FindByKey(guid)
 self.observer=m and m.name or UnitName and UnitName("player")or"unknown"
 self.observerGUID=guid
 self:Record("IDENTITY",self.observer.." / "..self.observerGUID)
end
function D:Text()
 local rows={"Guild Control diagnostics / "..GC.build}
 for _,e in ipairs(self.db and self.db.entries or {})do
  rows[#rows+1]=string.format("%s #%d S%d [%s / %s] %s %s",e.at,e.n,e.session,e.observer or"",e.observerGUID or"",e.kind,e.detail)
 end
 return table.concat(rows,"\n")
end
function D:Show()
 if not self.frame then
  local f=CreateFrame("Frame",nil,UIParent);self.frame=f
  f:SetSize(760,450);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");title:SetPoint("TOPLEFT",20,-18);title:SetText((GC:Text("Guild Control — журнал (Ctrl+A, Ctrl+C)")))
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-4,-4)
  close:SetScript("OnClick",function()f:Hide()end)
  local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",20,-48);scroll:SetSize(690,375)
  local edit=CreateFrame("EditBox",nil,scroll);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject(ChatFontNormal);edit:SetWidth(680)
  edit:SetScript("OnEscapePressed",function()f:Hide()end);scroll:SetScrollChild(edit);self.edit=edit
 end
 self.edit:SetText(self:Text());self.edit:SetCursorPosition(0);self.frame:Show();self.edit:SetFocus()
end
local f=CreateFrame("Frame")
for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN","PLAYER_LOGOUT","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"})do f:RegisterEvent(event)end
f:SetScript("OnEvent",function(_,event,owner,action)
 if event=="ADDON_ACTION_BLOCKED"or event=="ADDON_ACTION_FORBIDDEN"then
  if owner==addonName then D:Record(event,action)end
 else D:Record(event,"")end
end)
