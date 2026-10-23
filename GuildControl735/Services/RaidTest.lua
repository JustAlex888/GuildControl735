-- Isolated loopback only. No SendAddonMessage, no SavedVariables or real roster writes.
local _,GC=...
local W=GC.RaidWire
GC.RaidTest={}
local T=GC.RaidTest
function T:Stop()
 self.run=nil;if self.frame then self.frame:Hide()end
end
function T:Start(mode)
 self:Stop();mode=mode or"storm"
 if not ({storm=true,loss=true,duplicate=true})[mode]then return false end
 local r={mode=mode,now=0,index=1,delivery=1,events={},nodes={},records={},wall=1800000000,steps=0,delivered=0,bytes=0,ms=0,maxMs=0,started=GetTime(),memory=collectgarbage("count")}
 self.run=r
 local roster={};for i=1,300 do roster["Sim"..i.."-Test"]="Player-1-"..string.format("%08X",i)end
 for i=1,300 do
  local sender="Sim"..i.."-Test";local guid=roster[sender];local localStore={};local values={}
  for j=1,160 do values[j]=tostring((i*j)%30)end
  local n=W.New({guild=function()return"SIMULATION"end,clock=function()return r.now end,wall=function()return r.wall+math.floor(r.now)end,guid=function()return guid end,
   resolve=function(s)return roster[s]end,delay=function()return 2+(i-1)*0.10 end,capture=function()return values end,
   get=function(g)return localStore[g]end,
   save=function(record)
    localStore[record.guid]={capturedAt=record.capturedAt,hash=record.hash}
    if i==1 then r.records[record.guid]=record end
   end,
   send=function(msg)
    r.bytes=r.bytes+#msg
    if not(mode=="loss"and msg:match("^D|")and msg:match("|8|"))then
     r.events[#r.events+1]={msg=msg,sender=sender}
     if mode=="duplicate"and msg:match("^D|")then r.events[#r.events+1]={msg=msg,sender=sender}end
    end
   end})
  r.nodes[i]=n
 end
 -- One simultaneous update from every simulated reader.
 for _,n in ipairs(r.nodes)do n:Request("ALL")end
 if not self.frame then
  local f=CreateFrame("Frame","GC735RaidTestWindow",UIParent);self.frame=f;f:SetSize(640,260);f:SetPoint("CENTER");f:SetFrameStrata("TOOLTIP");f:SetFrameLevel(1000)
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local text=f:CreateFontString(nil,"ARTWORK","GameFontHighlight");text:SetPoint("TOPLEFT",24,-24);text:SetSize(590,190);text:SetJustifyH("LEFT");text:SetJustifyV("TOP");GC:ApplyFont(text,12);self.text=text
  local stop=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");stop:SetSize(140,28);stop:SetPoint("BOTTOMRIGHT",-20,18);stop:SetText((GC:Text("Закрыть / стоп")));stop:SetScript("OnClick",function()T:Stop()end)
  f:SetScript("OnUpdate",function()T:Step()end)
 end
 self.frame:Show();return true
end
function T:Step()
 local r=self.run;if not r or r.finished then return end
 local started=debugprofilestop();local work=0
 while work<200 and debugprofilestop()-started<2 do
  if r.tickIndex then
   r.nodes[r.tickIndex]:Tick();r.tickIndex=r.tickIndex+1
   if r.tickIndex>300 then
    r.tickIndex=nil
    if r.now>=90 then r.finished=true;break end
   end
  else
   local event=r.events[r.index]
   if event then
    r.nodes[r.delivery]:Receive(event.msg,event.sender,"GUILD");r.delivered=r.delivered+1;r.delivery=r.delivery+1
    if r.delivery>300 then r.events[r.index]=false;r.index=r.index+1;r.delivery=1 end
   else
    r.events={};r.index=1;r.now=r.now+0.10;r.steps=r.steps+1;r.tickIndex=1
   end
  end
  work=work+1
 end
 if not r.nextUI or GetTime()>=r.nextUI or r.finished then
  local n=0;for _ in pairs(r.records)do n=n+1 end
  local sent,rejected,coalesced=0,0,0
  for _,node in ipairs(r.nodes)do sent=sent+node.metrics.sent;rejected=rejected+node.metrics.rejected;coalesced=coalesced+node.metrics.coalesced end
  self.text:SetText((GC:Text("ТЕСТ: 300 виртуальных участников / "))..r.mode..(GC:Text("\nРеальная сеть и сохранения не используются.\n"))..
   (r.finished and(GC:Text("Завершён"))or(GC:Text("Выполняется")))..(GC:Text(". Время модели: "))..math.floor(r.now)..(GC:Text(" сек.\n"))..
   (GC:Text("Отправок: "))..sent..(GC:Text("; полезных байт: "))..r.bytes..(GC:Text("\nДоставок: "))..r.delivered..(GC:Text("; объединено запросов: "))..coalesced.."\n"..
   (GC:Text("Полных снимков у читателя: "))..n..(GC:Text(" / 300; отклонено: "))..rejected.."\n"..
   string.format((GC:Text("CPU: %.1f мс; max callback: %.2f мс; память без GC: %+.0f КБ")),r.ms,r.maxMs,collectgarbage("count")-r.memory).."\n"..
   (GC:Text("Эмуляция; сеть UWoW не проверена. Бюджет 2 мс не является жёстким пределом.")))
  r.nextUI=GetTime()+1
  self.lastReport={mode=r.mode,complete=n,sent=sent,bytes=r.bytes,deliveries=r.delivered,cpuMs=r.ms,maxStepMs=r.maxMs,seconds=r.now,finished=r.finished or false}
 end
 local fullMs=debugprofilestop()-started;r.ms=r.ms+fullMs;r.maxMs=math.max(r.maxMs,fullMs)
 if self.lastReport then self.lastReport.cpuMs=r.ms;self.lastReport.maxStepMs=r.maxMs end
end
function T:Report()
 local r=self.lastReport;if not r then GC:Print((GC:Text("Тест ещё не запускался.")));return end
 GC:Print(string.format("SIM300 %s complete=%d/300 sent=%d bytes=%d deliveries=%d cpu=%.1fms maxStep=%.2fms model=%.1fs finished=%s; NOT GAME NETWORK",r.mode,r.complete,r.sent,r.bytes,r.deliveries,r.cpuMs,r.maxStepMs,r.seconds,tostring(r.finished)))
end
