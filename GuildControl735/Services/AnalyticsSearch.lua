-- Session-only character-name search. Never stored in SavedVariables or sent.
local _,G=...
local A={queries={}};G.AnalyticsSearch=A
local upper="АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮĴĶĹĻĽŁŃŅŇŊŌŎŐŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŸŹŻŽ"
local lower="абвгдеёжзийклмнопрстуфхцчшщъыьэюяàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþāăąćĉċčďđēĕėęěĝğġģĥħĩīĭįĵķĺļľłńņňŋōŏőŕŗřśŝşšţťŧũūŭůűųŵŷÿźżž"
local chars="[%z\1-\127\194-\244][\128-\191]*"
local map={};local values={};for c in lower:gmatch(chars)do values[#values+1]=c end
local i=0;for c in upper:gmatch(chars)do i=i+1;map[c]=values[i]end
function A:Fold(text)
 return (string.lower(type(text)=="string"and text or""):gsub(chars,function(c)return map[c]or c end))
end
function A:Get(id)return self.queries[id]or""end
function A:Set(id,text)
 if id~="mythic"and id~="pvp"and id~="raid"then return end
 self.queries[id]=self:Fold(text):match("^%s*(.-)%s*$")
end
function A:Matches(id,member)
 local query=self:Get(id);if query==""then return true end
 local name=member.baseName or member.name or member.fullName or""
 name=name:match("^([^%-]+)")or name
 return self:Fold(name):find(query,1,true)~=nil
end
function A:CreateField(id,parent,x,y,refresh)
 local label=parent:CreateFontString(nil,"ARTWORK","GameFontNormal");G:ApplyFont(label,12)
 label:SetPoint("TOPLEFT",x,-y-3);label:SetSize(140,24);label:SetJustifyH("LEFT");label:SetText((G:Text("Поиск по имени")))
 local field=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");parent.nameSearch=field
 field:SetPoint("TOPLEFT",x+148,-y);field:SetSize(280,26);field:SetAutoFocus(false);field:SetMaxLetters(64);field:SetText(self:Get(id))
 field:SetScript("OnTextChanged",function(o)A:Set(id,o:GetText());refresh()end)
 field:SetScript("OnEnterPressed",function(o)o:ClearFocus()end)
 field:SetScript("OnEscapePressed",function(o)o:SetText("");o:ClearFocus()end)
 field:HookScript("OnHide",function(o)o:ClearFocus()end)
 local clear=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");parent.clearNameSearch=clear
 clear:SetPoint("TOPLEFT",x+440,-y);clear:SetSize(100,26);clear:SetText((G:Text("Очистить")))
 clear:SetScript("OnClick",function()field:SetText("");field:ClearFocus()end)
 G:ApplyFont(clear:GetFontString(),12)
 G:AttachHelp(field,(G:Text("Поиск по имени")),(G:Text("Часть имени без учёта регистра. Поиск пересекается с остальными фильтрами. Класс, звание, реалм и числовые показатели не ищутся. После /reload поле пустое. Esc — очистить.")))
 G:AttachHelp(clear,(G:Text("Очистить поиск")),(G:Text("Вернуть всех персонажей, подходящих под выбранные фильтры. Остальные настройки сохраняются.")))
end
