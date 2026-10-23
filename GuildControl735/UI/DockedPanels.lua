local _,GC=...
local function Backdrop(f)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
end
local function Label(parent,x,y,w,h,size,value)
    local t=parent:CreateFontString(nil,"ARTWORK","GameFontHighlight");t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);t:SetJustifyH("LEFT");t:SetJustifyV("TOP");t:SetWordWrap(true);GC:ApplyFont(t,size)
    if value then t:SetText(value)end;return t
end
local function Vertical(s)
    local chars={};for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*")do chars[#chars+1]=c end
    return table.concat(chars,"\n")
end
function GC:InitializeDockedPanels(parent)
    local host=self.ShellWindow or parent
    local page=CreateFrame("Frame",nil,host);self.GuildPage=page
    page:SetSize(300,300);page:SetPoint("TOPRIGHT",host,"TOPLEFT",-34,-48);Backdrop(page);page:Hide()
    page.title=Label(page,18,18,264,48,14)
    local scroll=CreateFrame("ScrollFrame","GC735GuildPageScroll",page,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",18,-80);scroll:SetSize(244,190);page.scroll=scroll
    page.measure=Label(page,0,0,244,1,12);page.measure:Hide()
    local edit=CreateFrame("EditBox",nil,scroll);edit:SetSize(244,190);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:EnableMouse(true)
    GC:ApplyFont(edit,12);edit:SetTextInsets(2,2,2,2);scroll:SetScrollChild(edit);page.edit=edit
    -- Permit native focus, selection, Ctrl+A/Ctrl+C. Never Disable the EditBox.
    edit:SetScript("OnEscapePressed",function(o)o:ClearFocus()end)
    edit:SetScript("OnKeyDown",function(o,key)if key=="A" and IsControlKeyDown and IsControlKeyDown() then o:HighlightText()end end)
    edit:SetScript("OnTextChanged",function(o)
        if page.restoring then return end
        if o:GetText()~=(page.snapshot or "") then
            local pos=o:GetCursorPosition();page.restoring=true;o:SetText(page.snapshot or "");o:SetCursorPosition(math.min(pos,#(page.snapshot or "")));page.restoring=false
        end
    end)
    edit:SetScript("OnCursorChanged",function(_,x,y,w,h)
        local top=math.max(0,-y);local offset=scroll:GetVerticalScroll();local viewport=scroll:GetHeight()
        if top<offset then scroll:SetVerticalScroll(top)
        elseif top+h>offset+viewport then scroll:SetVerticalScroll(math.max(0,top+h-viewport))end
    end)
    self.GuildTabs={}
    for i,name in ipairs({(GC:Text("Информация")),(GC:Text("Сообщение дня"))})do
        local kind=i==1 and "info" or "motd"
        local b=CreateFrame("Button",nil,host);b:SetSize(34,140);b:SetPoint("TOPRIGHT",host,"TOPLEFT",0,-48-(i-1)*144);Backdrop(b)
        local t=b:CreateFontString(nil,"ARTWORK","GameFontNormal");t:SetPoint("CENTER",0,0);t:SetSize(30,136);t:Hide()
        local texture=b:CreateTexture(nil,"ARTWORK");texture:SetAllPoints();local suffix=GC.locale=="ruRU" and "" or "_en";texture:SetTexture("Interface\\AddOns\\GuildControl735\\Textures\\"..(i==1 and "InfoTab" or "MotdTab")..suffix..".tga")
        b:SetScript("OnClick",function()
            if page:IsShown() and page.kind==kind then page:Hide();page.kind=nil else page.kind=kind;page:Show();GC:RefreshGuildPage();GC.Roster:RequestRefresh()end
            GC:FitDockedPanels()
        end);self.GuildTabs[i]=b
        GC:AttachHelp(b,name,i==1 and (GC:Text("Показать информацию о гильдии из Blizzard. Текст можно выделить и скопировать; редактирование гильдии здесь недоступно."))or (GC:Text("Показать сообщение дня гильдии из Blizzard. Текст доступен для выделения и копирования.")))
    end
    local stats=CreateFrame("Frame",nil,parent);self.StatsPanel=stats
    stats:SetSize(230,400);stats:SetPoint("BOTTOMLEFT",parent,"BOTTOMRIGHT",0,0);Backdrop(stats);stats:Hide()
    stats.title=Label(stats,14,18,198,54,14)
    stats.close=CreateFrame("Button",nil,stats,"UIPanelCloseButton");stats.close:SetPoint("TOPRIGHT",-2,-2)
    stats.close:SetScript("OnClick",function()GC.RatingTabs:Cancel();stats:Hide();stats.kind=nil;GC:FitDockedPanels()end)
    GC:AttachHelp(stats.close,(GC:Text("Закрыть")),(GC:Text("Закрыть панель статистики выбранного персонажа.")))
    local ss=CreateFrame("ScrollFrame","GC735StatsScroll",stats,"UIPanelScrollFrameTemplate");ss:SetPoint("TOPLEFT",14,-86);ss:SetSize(176,294);stats.scroll=ss;stats.scrollOffsets={}
    ss:HookScript("OnScrollRangeChanged",function(_,_,range)
        local bar=_G.GC735StatsScrollScrollBar
        if bar then bar:SetShown(stats.overflow and (range or 0)>0 or false)end
    end)
    local child=CreateFrame("Frame",nil,ss);child:SetSize(176,720);ss:SetScrollChild(child);stats.child=child
    stats.text=Label(child,0,0,174,710,11)
    stats:SetScript("OnUpdate",function(_,elapsed)
        stats.elapsed=(stats.elapsed or 0)+elapsed
        if stats.elapsed>=1 then
            stats.elapsed=0;GC:UpdateStats(GC.Roster:FindByKey(GC.MemberCard and GC.MemberCard.memberKey))
        end
    end)
    local events=CreateFrame("Frame")
    for _,e in ipairs({"GUILD_MOTD","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE"})do events:RegisterEvent(e)end
    events:SetScript("OnEvent",function()GC:RefreshGuildPage();GC.Rating:Tick()end)
end
function GC:RefreshGuildPage()
    local p=self.GuildPage;if not p or not p:IsShown() then return end
    local read=p.kind=="motd" and GetGuildRosterMOTD or GetGuildInfoText
    local text=(GC:Text("Источник недоступен"))
    if IsInGuild() and type(read)=="function" then local ok,v=pcall(read);if ok and type(v)=="string" then text=v end end
    -- Memory-only display copy, never SavedVariables. Ignore markup visually by escaping pipes.
    -- Preserve the exact Blizzard string for manual copying.
    p.title:SetText(p.kind=="motd" and (GC:Text("Сообщение дня")) or (GC:Text("Информация")))
    if p.snapshot~=text then
        p.snapshot=text;p.restoring=true;p.edit:SetText(text);p.edit:SetCursorPosition(0);p.restoring=false
        p.scroll:SetVerticalScroll(0)
    end
    p.measure:SetText(text);p.measure:SetHeight(0)
    p.edit:SetHeight(math.max(190,(p.measure:GetStringHeight() or 190)+24))
end
local function SaveStatsScroll(panel)
    if not panel.scrollKey then return end
    local count=0;for _ in pairs(panel.scrollOffsets)do count=count+1 end
    if count>=200 and not panel.scrollOffsets[panel.scrollKey]then panel.scrollOffsets[next(panel.scrollOffsets)]=nil end
    panel.scrollOffsets[panel.scrollKey]=panel.scroll:GetVerticalScroll()
end
function GC:ToggleStats(kind)
    local p=self.StatsPanel;local member=self.Roster:FindByKey(self.MemberCard.memberKey)
    if not member then return end
    if p:IsShown()and p.kind==kind and p.guid==member.guid then
        SaveStatsScroll(p);self:CloseStatsPanel();self:FitDockedPanels();return
    end
    SaveStatsScroll(p)
    p.scrollKey=tostring(self:GetGuildKey())..":"..member.guid..":"..kind
    p.restoreScroll=p.scrollOffsets[p.scrollKey]or 0;p.scroll:SetVerticalScroll(0)
    p.kind=kind;p.guid=member.guid;p.lastText=nil;p.diagnostic=nil
    p.text:SetText((GC:Text("Загрузка…")));p:Show()
    if kind=="raid"then self.RatingTabs:Cancel();self.RaidRuntime:Request(member.guid)elseif kind=="mythic"then self.RatingTabs:OpenMythic(member)else self.RatingTabs:Select(member,kind)end
    self:UpdateStats(member);self:FitDockedPanels()
end
function GC:UpdateStats(member)
    local p=self.StatsPanel;if not p or not p:IsShown()then return end
    if not member then self.RatingTabs:Cancel();p:Hide();self:FitDockedPanels();return end
    if p.guid~=member.guid then
        SaveStatsScroll(p);self.RatingTabs:Cancel();p.guid=member.guid;p.lastText=nil
        p.scrollKey=tostring(self:GetGuildKey())..":"..member.guid..":"..tostring(p.kind);p.restoreScroll=p.scrollOffsets[p.scrollKey]or 0;p.scroll:SetVerticalScroll(0)
    end
    if p.kind=="raid"then GC:UpdateRaidPanel(member);return end
    if p.kind=="mythic"and not self.RatingTabs:View(member,"mythic")then self.RatingTabs:OpenMythic(member)end
    if p.raidDetails then p.raidDetails:Hide();p.raidRefresh:Hide()end
    p:SetWidth(230);p.scroll:SetWidth(176);p.child:SetWidth(176);p.text:SetWidth(174);p.title:SetWidth(198)
    p.title:SetText((p.kind=="pvp"and"PvP"or"Mythic+").."\n"..self:ClassName(member))
    local view=self.RatingTabs:View(member,p.kind);local rows={}
    local function muted(text)return "|cff999999"..text.."|r"end
    local function numberRow(label,value)
        local text=label..": "..value
        return tonumber(value)==0 and muted(text)or GC:StatLabel(label,value)
    end
    if p.kind=="mythic"then
        local data=self.MythicLadder:Cached(member)
        if data then
            if data.absent then rows[#rows+1]=muted((GC:Text("Не ходил в ключи в текущем сезоне.")))
            else
                rows[#rows+1]=numberRow((GC:Text("Общий рейтинг")),data.rating)
                rows[#rows+1]=numberRow((GC:Text("Закрыто")),data.totalRuns)
                if data.rank then rows[#rows+1]=numberRow((GC:Text("Место")),data.rank) end
                if data.classRank then rows[#rows+1]=numberRow((GC:Text("Место по классу")),data.classRank) end
                if data.profile then
                    for _,f in ipairs({{"tank",(GC:Text("Танк"))},{"heal",(GC:Text("Лекарь"))},{"dps",(GC:Text("Боец"))}})do local v=data.profile.roles[f[1]];if v~=nil then rows[#rows+1]=numberRow(f[2],v) end end
                    for _,f in ipairs({{"c_2_4","2–4"},{"c_5_9","5–9"},{"c_10_14","10–14"},{"c_15_19","15–19"},{"c_20_24","20–24"},{"c_25_29","25–29"},{"c_30_34","30–34"},{"c_35_above","35+"}})do local v=data.profile.ranges[f[1]];if v~=nil then rows[#rows+1]=numberRow(f[2],v) end end
                end
            end

        else
            rows[#rows+1]=(GC:Text("Сводка ладдера UWoW пока не загружена."))
        end
    elseif p.kind=="pvp"then
        local data=self.MythicLadder:Cached(member)
        if data then
            for _,mode in ipairs(self.RatingTabs.modes)do
                local d=data.pvp and data.pvp[mode.id]
                rows[#rows+1]=d and ("|cff40ff40"..mode.name.."|r: "..self:StatLabel((GC:Text("Рейтинг")),d.rating))or muted(mode.name..(GC:Text(": Не ходил в текущем сезоне")))
                if d then
                    if d.rank then rows[#rows+1]=self:StatLabel((GC:Text("Место")),d.rank) end
                    if d.classRank then rows[#rows+1]=self:StatLabel((GC:Text("Место по классу")),d.classRank) end
                    rows[#rows+1]=d.seasonGames~=nil and self:StatLabel((GC:Text("Бои за сезон")),d.seasonGames)or (GC:Text("Бои за сезон: нет данных."))
                    if d.profile then
                        for _,f in ipairs({{"week",(GC:Text("Неделя"))},{"season",(GC:Text("Сезон"))}})do
                            local v=d.profile[f[1]]
                            if v then
                                rows[#rows+1]="|cff40ff40"..f[2].."|r"
                                if v.games~=nil then rows[#rows+1]=self:StatLabel((GC:Text("Бои")),v.games) end
                                if v.games_win~=nil then rows[#rows+1]=self:StatLabel((GC:Text("Победы")),v.games_win) end
                                if v.rating~=nil then rows[#rows+1]=self:StatLabel((GC:Text("Рейтинг")),v.rating) end
                                if v.mmr~=nil then rows[#rows+1]=self:StatLabel("MMR",v.mmr) end
                            end
                        end
                    end
                end
            end
        else rows[#rows+1]=(GC:Text("Сводка ладдера UWoW пока не загружена."))end
    else rows[1]=(GC:Text("Данные недоступны."))end
    p.text:SetTextColor(1,1,1) -- Active PvP blocks include their zero weekly values.
    local text=table.concat(rows,"\n")
    if text~=p.lastText then p.text:SetText(text);p.lastText=text end
    -- Keep the bottom anchor, move only the top edge. Grow for wrapped/extra rows;
    -- a local scrollbar is a fallback only when the screen cannot fit the text.
    p.text:SetHeight(0)
    local content=(p.text:GetStringHeight()or 0)+12
    local base=p.kind=="pvp"and 540 or 302
    local reserved=106
    local available=math.min(self.MainWindow:GetHeight(),UIParent:GetHeight()*UIParent:GetEffectiveScale()/p:GetEffectiveScale()-40)
    local height=math.min(math.max(base,content+reserved),math.max(160,available))
    local oldHeight=p:GetHeight();p:SetHeight(height);local viewport=height-reserved;p.viewport=viewport
    p.scroll:SetHeight(viewport);p.child:SetHeight(math.max(viewport,content))
    local overflow=content>viewport;p.overflow=overflow
    local bar=_G.GC735StatsScrollScrollBar;if bar then bar:SetShown(overflow)end
    p.scroll:EnableMouseWheel(overflow)
    p.scroll:SetVerticalScroll(math.max(0,math.min(p.scroll:GetVerticalScroll(),p.child:GetHeight()-viewport)))
    if view and view.phase=="fresh"and p.restoreScroll then
        p.scroll:SetVerticalScroll(math.max(0,math.min(p.restoreScroll,p.child:GetHeight()-p.viewport)));p.restoreScroll=nil
    end
    if oldHeight~=height then self:FitDockedPanels()end
end
function GC:CloseStatsPanel()
    if self.RatingTabs then self.RatingTabs:Cancel()end
    if self.StatsPanel then self.StatsPanel:Hide();self.StatsPanel.kind=nil end
end
function GC:CloseDockedPanels()
    self:CloseStatsPanel()
    if self.GuildPage then self.GuildPage:Hide();self.GuildPage.kind=nil;self.GuildPage.edit:ClearFocus()end
    if self.StatsPanel then self.StatsPanel:Hide();self.StatsPanel.kind=nil end
end
function GC:FitDockedPanels()
    local f=self.ShellWindow or self.MainWindow;if not f or not UIParent.GetWidth then return end
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight();if not sw or not sh or sw<=0 or sh<=0 then return end
    local left=self.GuildPage and self.GuildPage:IsShown() and 334 or 34
    local right=self.StatsPanel and self.StatsPanel:IsShown() and self.StatsPanel:GetWidth() or 0
    -- Keep one scale across all pages; reserve maximum dock footprint.
    local footprint=self.StatsPanel and self.StatsPanel:IsShown()and self.StatsPanel.kind=="raid"and 2032 or 1922
    local scale
    if self.Shell.activePage=="general"then
        self.GeneralScale=self.GeneralScale or math.min(1,sw/1922,sh/824)
        scale=self.GeneralScale
    else scale=math.min(1,sw/footprint,sh/824)end
    f:SetScale(scale)
    if self.Shell.activePage=="general"and self.ConstrainGeneralToScreen then self:ConstrainGeneralToScreen()end
    local width,height=f:GetWidth(),f:GetHeight()
    if self.StatsPanel and self.StatsPanel:IsVisible()then height=math.max(height,self.StatsPanel:GetHeight())end
    local factor=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local l,b=f:GetLeft(),f:GetBottom();if not l or not b then return end
    local low,high=l*factor-left*factor,(l+width+right)*factor
    local dx=low<0 and -low or (high>sw and sw-high or 0)
    local dy=b*factor<0 and -b*factor or ((b+height+32)*factor>sh and sh-(b+height+32)*factor or 0)
    if dx~=0 or dy~=0 then local point,rel,rp,x,y=f:GetPoint(1);f:ClearAllPoints();f:SetPoint(point,rel,rp,x+dx/factor,y+dy/factor)end
end
