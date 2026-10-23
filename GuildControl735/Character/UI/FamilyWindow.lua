-- Read-only automatically observed local characters. No main/alt controls.
local _,GC=...
local S=GC.Character
function S:InitializeFamilyWindow(parent,x,y)
 if self.FamilyWindow then return end
 local f=CreateFrame("Frame",nil,parent);f:SetPoint("TOPLEFT",x,-y);f:SetSize(338,180);self.FamilyWindow=f
 f.title=f:CreateFontString(nil,"ARTWORK","GameFontNormal");f.title:SetPoint("TOPLEFT",0,0);f.title:SetSize(338,26);f.title:SetText((GC:Text("Мои персонажи")));self:ApplyFont(f.title,14)
 f.rows={}
 for i=1,12 do
  local t=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");t:SetPoint("TOPLEFT",i<=6 and 0 or 174,-32-((i-1)%6)*22);t:SetSize(166,22);t:SetJustifyH("LEFT");t:SetWordWrap(false);S:ApplyFont(t,11);f.rows[i]=t
  local hit=CreateFrame("Frame",nil,f);hit:SetAllPoints(t);hit:EnableMouse(true)
  hit:SetScript("OnEnter",function(o)if t.fullName then GameTooltip:SetOwner(o,"ANCHOR_RIGHT");GameTooltip:ClearLines();GameTooltip:AddLine(t.fullName,1,1,1,true);GameTooltip:Show()end end)
  hit:SetScript("OnLeave",function()GameTooltip:Hide()end)
  hit:SetScript("OnHide",function(o)if GameTooltip:IsOwned(o)then GameTooltip:Hide()end end)
 end
end
function S:SelectFamilyMain()return false,"officer_note_managed"end
function S:UpdateFamilyWindow()
 local f=self.FamilyWindow;if not f then return end
 local members=self.Family:GetMembers();f.memberCount=#members
 for i,t in ipairs(f.rows)do local m=members[i];local roster=m and GC.Roster:FindByKey(m.guid);t.fullName=m and m.name or nil;t:SetText(m and GC:ClassName(roster or m)or "");t:SetShown(m~=nil)end
 if self.MainWindow then self:LayoutMainWindow()end
 if GC.RefreshLinkedMemberCard then GC:RefreshLinkedMemberCard()end
end
function S:LayoutFamilyList(viewport)
 self.FamilyWindow:SetSize(340,164);self.FamilyWindow.overflow=false
end
function S:OpenFamilyWindow()
 self:ShowMyCard();self:UpdateFamilyWindow()
end
