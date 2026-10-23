local _,GC=...
local function Count(t)local n=0;for _ in pairs(t or {})do n=n+1 end;return n end
-- Diagnostic reads only. This interface does not authorize network requests.
GuildControl735DiagnosticsAPI={
 Status=function()
  local R=GC.RaidRuntime;local e=R and R.engine;local out={version=GC.version,build=GC.build}
  for k,v in pairs(e and e.metrics or {})do if type(v)=="number"then out[k]=v end end
  out.lastReject=e and e.lastReject;out.lastRejectSender=e and e.lastRejectSender;out.lastRejectAt=e and e.lastRejectAt
  out.assemblies=Count(e and e.assemblies);out.queued=e and e.queue and 1 or 0;out.pending=e and e.pending and 1 or 0
  out.rxCpuTotal=R and R.rxCpuTotal or 0;out.rxCpuMax=R and R.rxCpuMax or 0
  local b=GC.DevTools and GC.DevTools.ReceiverProbe
  if b and b.report then out.benchmark={};for k,v in pairs(b.report)do if type(v)=="number"or type(v)=="string"then out.benchmark[k]=v end end end
  return out
 end,
 Mark=function(id,label)GC.Diagnostics:Record("LAB_MARK",tostring(id):sub(1,32).." "..tostring(label):sub(1,40))end,
 Benchmark=function(mode)
  if UnitAffectingCombat("player")then return false end
  local b=GC.DevTools and GC.DevTools.ReceiverProbe;return b and b:Start(mode)or false
 end,
 StopBenchmark=function()local b=GC.DevTools and GC.DevTools.ReceiverProbe;if b then b:Stop()end end,
 ShowLog=function()GC.Diagnostics:Show()end,
}

function GC:ShowAuthorizationStatus()
 local R,T=self.RaidRuntime,self.AdminTrust;local e=R and R.engine
 local sender=e and e.lastRejectSender
 self:Print((GC:Text("Причина отказа: "))..tostring(e and e.lastReject))
 self:Print((GC:Text("Отправитель: "))..tostring(sender))
 local name=sender and self.TrustBoundary:CanonicalName(sender)
 local m=name and T.members[name];local p=T:Policy()
 self:Print((GC:Text("Состав доверия: "))..tostring(name)..(GC:Text("; ранг="))..tostring(m and m.rank).."; GUID="..tostring(m and m.guid))
 self:Print((GC:Text("Рейдовый состав: GUID="))..tostring(sender and R:Resolve(sender)))
 local ok,why=T:Allowed(sender)
 self:Print((GC:Text("Допуск сейчас: "))..tostring(ok).." / "..tostring(why)..(GC:Text("; маска="))..tostring(p and p.mask))
 self:Print((GC:Text("Возраст состава: "))..tostring(T.refreshed and math.floor(GetTime()-T.refreshed))..(GC:Text("; глава="))..tostring(T.leader))
end
