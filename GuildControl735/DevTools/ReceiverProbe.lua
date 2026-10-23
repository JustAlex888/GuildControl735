-- Development tool only. Isolated module context; no real roster/DB/network hooks.
local _,GC=...
local P=GC.DevTools
P.RaidWire=GC.RaidWire
P.RaidRuntime=GC:CreateRaidRuntime(P)
local W,R=P.RaidWire,P.RaidRuntime
local B={};P.ReceiverProbe=B
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function percentile(t,p)
 if #t==0 then return 0 end
 table.sort(t);return t[math.max(1,math.ceil(#t*p))]
end
function B:Prepare(mode)
 assert(mode=='baseline' or mode=='paced' or mode=='burst' or mode=='duplicate' or mode=='loss')
 local events,roster,byGuid={}, {}, {}
 if mode=='baseline'then return events,roster,byGuid,0 end
 local bytes=0
 -- No sender engines: encode and schedule fixtures before any timing baseline.
 for i=1,300 do
  local sender='Sim'..i..'-Test';local guid='Player-1-'..string.format('%08X',i)
  roster[W.Canonical(sender,'Test')]=guid;byGuid[guid]={name=sender,online=true}
  events[#events+1]={at=0,msg='Q|1|ALL',sender=sender}
  local values={};for j=1,160 do values[j]=tostring((i*j)%30)end
  local frames=assert(W.Frames(guid,1800000000,values))
  for part,msg in ipairs(frames)do
   if not(mode=='loss' and part==8)then
    local at=mode=='burst' and 0 or 2+(i-1)*0.1+(part-1)*0.5
    events[#events+1]={at=at,msg=msg,sender=sender}
    if mode=='duplicate'then events[#events+1]={at=at,msg=msg,sender=sender}end
   end
  end
 end
 for i,e in ipairs(events)do e.order=i;bytes=bytes+#e.msg end
 table.sort(events,function(a,b)return a.at==b.at and a.order<b.order or a.at<b.at end)
 return events,roster,byGuid,bytes
end
function B:Start(mode)
 self:Stop();self.report=nil;mode=mode or'paced'
 if not({baseline=true,paced=true,burst=true,duplicate=true,loss=true})[mode]then return false end
 local events,roster,byGuid,bytes=self:Prepare(mode)
 local db={records={}}
 -- Substitute only storage/context in this private copy. Keep production Get/Save.
 R.Database=function()return db end;R.byGuid=byGuid;R.publisher=true
 local r={mode=mode,events=events,index=1,now=0,db=db,bytes=bytes,
  calls={},steps={},frames={},cpu=0,receiveCpu=0,tickCpu=0,saveCalls=0,outgoing=0,
  started=GetTime(),lastTick=-1,lastUI=-1,memory=collectgarbage('count')}
 r.engine=W.New({guild=function()return'ISOLATED_RECEIVER' end,
  clock=function()return r.now end,wall=function()return 1800000000+math.floor(r.now)end,
  guid=function()return'Player-1-FFFFFFFF'end,
  resolve=function(sender)return roster[W.Canonical(sender,'Test')]end,
  get=function(guid)return R:Get(guid)end,
  save=function(record)r.saveCalls=r.saveCalls+1;return R:Save(record)end,
  send=function()r.outgoing=r.outgoing+1 end})
 self.run=r;self:Frame();self.frame:Show();return true
end
function B:Frame()
 if self.frame then return end
 local f=CreateFrame('Frame','GC735ReceiverProbeWindow',UIParent);self.frame=f
 f:SetSize(650,245);f:SetPoint('CENTER');f:SetFrameStrata('TOOLTIP');f:SetFrameLevel(1000)
 f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
 self.text=f:CreateFontString(nil,'ARTWORK','GameFontHighlight');self.text:SetPoint('TOPLEFT',22,-22);self.text:SetSize(605,180);self.text:SetJustifyH('LEFT');self.text:SetJustifyV('TOP')
 local stop=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');stop:SetSize(140,25);stop:SetPoint('BOTTOMRIGHT',-20,16);stop:SetText((GC:Text('Стоп / закрыть')));stop:SetScript('OnClick',function()B:Stop()end)
 f:SetScript('OnUpdate',function(_,elapsed)B:Step(elapsed)end)
end
function B:Step(elapsed)
 local r=self.run;if not r or r.finished then return end
 if r.drained then
  -- Include the frame after the last delivery, particularly the burst stall.
  r.frames[#r.frames+1]=(elapsed or 0)*1000;self:Finish();return
 end
 local started=debugprofilestop();r.now=GetTime()-r.started
 r.frames[#r.frames+1]=(elapsed or 0)*1000
 local work=0
 -- Burst deliberately drains the bounded 5100-message fixture in one callback.
 -- It exposes the worst case; it does not pretend production OnEvent is budgeted.
 while work<(r.mode=='burst'and 10000 or 200)and(r.mode=='burst'or debugprofilestop()-started<2)do
  local event=r.events[r.index];if not event or event.at>r.now then break end
  local t=debugprofilestop();r.engine:Receive(event.msg,event.sender,'GUILD')
  local ms=debugprofilestop()-t;r.calls[#r.calls+1]=ms;r.receiveCpu=r.receiveCpu+ms;r.maxReceive=math.max(r.maxReceive or 0,ms)
  r.index=r.index+1;work=work+1
 end
 if r.now-r.lastTick>=0.1 then
  local t=debugprofilestop();r.engine:Tick();r.tickCpu=r.tickCpu+debugprofilestop()-t;r.lastTick=r.now
 end
 local done=(r.mode=='baseline' and r.now>=15)or(r.mode~='baseline'and r.index>#r.events and (r.mode~='loss' or r.now>=90))or r.now>=120
 if r.now-r.lastUI>=1 or done then
  self.text:SetText(string.format((GC:Text('TEST: один получатель / 300 отправителей / %s\nСети и настоящих сохранений нет.\nПринято сообщений: %d / %d; снимков: %d / 300\nВремя: %.1f сек; receive CPU: %.2f мс\nМакс receive: %.3f мс; память без GC: %+.0f КБ\nПодготовка отправителей исключена; полный отчёт /gcrp report')),r.mode,r.index-1,#r.events,count(r.db.records),r.now,r.receiveCpu,r.maxReceive or 0,collectgarbage('count')-r.memory))
  r.lastUI=r.now
 end
 local ms=debugprofilestop()-started;r.cpu=r.cpu+ms;r.steps[#r.steps+1]=ms
 if done then r.drained=true end
end
function B:Finish()
 local started=debugprofilestop();local r=self.run;if not r then return end;r.finished=true
 local m=r.engine.metrics
 self.report={mode=r.mode,messages=r.index-1,bytes=r.bytes,complete=count(r.db.records),saveCalls=r.saveCalls,
  rejected=m.rejected,duplicates=m.duplicates,outgoing=r.outgoing,seconds=r.now,
  receiveCpu=r.receiveCpu,tickCpu=r.tickCpu,callbackCpu=r.cpu,
  receiveMax=percentile(r.calls,1),receiveP99=percentile(r.calls,.99),
  callbackMax=percentile(r.steps,1),callbackP99=percentile(r.steps,.99),
  frameMax=percentile(r.frames,1),frameP99=percentile(r.frames,.99),
  memoryUncollectedKB=collectgarbage('count')-r.memory}
 self.report.finalizeMs=debugprofilestop()-started;self:Report()
 self.text:SetText(string.format((GC:Text('Завершён: один получатель / %s\nСообщений: %d; полных снимков: %d; сохранений: %d\nReceive CPU: %.2f мс; max receive: %.3f мс\nMax callback: %.3f мс; p99 callback: %.3f мс\nПодробный итог выведен в локальный чат; /gcrp report\nИзолированная модель. Не измерение сети UWoW.')),r.mode,self.report.messages,self.report.complete,r.saveCalls,r.receiveCpu,self.report.receiveMax,self.report.callbackMax,self.report.callbackP99))
end
function B:Report()
 local r=self.report;if not r then print((GC:Text('GC735 receiver: нет завершённого теста')));return end
 print(string.format('GC735 RECEIVER %s complete=%d/300 msg=%d bytes=%d saves=%d rejected=%d duplicates=%d outgoing=%d',r.mode,r.complete,r.messages,r.bytes,r.saveCalls,r.rejected,r.duplicates,r.outgoing))
 print(string.format('seconds=%.2f receiveCPU=%.2fms tickCPU=%.2fms fullCallbackCPU=%.2fms',r.seconds,r.receiveCpu,r.tickCpu,r.callbackCpu))
 print(string.format('receive max/p99=%.3f/%.3fms callback max/p99=%.3f/%.3fms frame max/p99=%.3f/%.3fms memoryUncollected=%+.0fKB',r.receiveMax,r.receiveP99,r.callbackMax,r.callbackP99,r.frameMax,r.frameP99,r.memoryUncollectedKB))
 print((GC:Text('TEST loopback: не сеть UWoW. Frame включает весь клиент; память включает диагностические массивы и мусор Lua.')))
 print(string.format((GC:Text('Отдельная финализация отчёта: %.3fms (не включена в callbackCPU).')),r.finalizeMs or 0))
end
function B:Stop()
 self.run=nil;R.byGuid=nil;R.Database=function()return nil end
 if self.frame then self.frame:Hide()end
end
SLASH_GC735RECEIVERPROBE1='/gcrp'
SlashCmdList.GC735RECEIVERPROBE=function(msg)
 msg=(msg or''):lower():match('^%s*(.-)%s*$')
 if msg=='report'then B:Report()elseif msg=='stop'then B:Stop()else
  if not B:Start(msg==''and'paced'or msg)then print('/gcrp baseline | paced | burst | duplicate | loss | report | stop')end
 end
end
