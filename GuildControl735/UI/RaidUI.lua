local _,GC=...
function GC:InitializeRaidUI()
 local f=self.MainWindow;local p=self.StatsPanel
 p:HookScript("OnHide",function()p.detail=false;p.lastText=nil;p.scroll:SetVerticalScroll(0)end)
 -- The general page now has one combined request button.
 p.raidDetails=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");p.raidDetails:SetSize(110,22);p.raidDetails:SetPoint("TOPLEFT",14,-62);p.raidDetails:SetText((GC:Text("Подробнее")))
 p.raidDetails:SetScript("OnClick",function()p.detail=not p.detail;GC:UpdateStats(GC.Roster:FindByKey(p.guid))end);p.raidDetails:Hide()
 p.raidRefresh=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");p.raidRefresh:SetSize(100,22);p.raidRefresh:SetPoint("TOPLEFT",130,-62);p.raidRefresh:SetText((GC:Text("Обновить")))
 p.raidRefresh:SetScript("OnClick",function()local ok,why=GC.RaidRuntime:Request(p.guid);if not ok then GC:Print((GC:Text("Запрос недоступен: "))..tostring(why))end end);p.raidRefresh:Hide()
 GC:AttachHelp(p.raidDetails,(GC:Text("Подробности рейдов")),(GC:Text("Переключить сводный и подробный список рейдового прогресса выбранного персонажа.")))
 GC:AttachHelp(p.raidRefresh,(GC:Text("Обновить рейды")),(GC:Text("Запросить обновление рейдовых данных выбранного персонажа. Действуют существующие права, доступность источника и ограничения частоты.")))
end
function GC:OpenRaidOwn()
 local member=self.Roster:FindByKey(UnitGUID("player"));if not member then return end
 self.Shell:Open("general");self:ShowMemberCard(member);self:ToggleStats("raid")
end
function GC:UpdateRaidPanel(member)
 local p=self.StatsPanel;p:SetWidth(340);p.scroll:SetWidth(286);p.child:SetWidth(286);p.text:SetWidth(284);p.title:SetWidth(308)
 p.title:SetText((GC:Text("Рейды\n"))..self:ClassName(member));p.text:SetTextColor(1,1,1);p.raidDetails:Show();p.raidRefresh:Show();p.raidDetails:SetText(p.detail and(GC:Text("Сводка"))or(GC:Text("Подробнее")))
 local text=self.RaidRuntime:Rows(member.guid,p.detail)
 if text~=p.lastText then p.text:SetText(text);p.lastText=text end
 p.text:SetHeight(0);local content=(p.text:GetStringHeight()or 0)+12
 local available=math.min(self.MainWindow:GetHeight(),UIParent:GetHeight()*UIParent:GetEffectiveScale()/p:GetEffectiveScale()-40)
 if not p.detail then p.raidSummaryHeight=math.max(540,content+106)end
 local height=math.min(p.raidSummaryHeight or 540,math.max(160,available));p:SetHeight(height);p.viewport=height-106
 p.scroll:SetHeight(p.viewport);p.child:SetHeight(math.max(p.viewport,content));p.overflow=content>p.viewport
 local bar=_G.GC735StatsScrollScrollBar;if bar then bar:SetShown(p.overflow)end
 p.scroll:EnableMouseWheel(p.overflow)
 p.scroll:SetVerticalScroll(math.max(0,math.min(p.scroll:GetVerticalScroll(),p.child:GetHeight()-p.viewport)))
 self:FitDockedPanels()
end
