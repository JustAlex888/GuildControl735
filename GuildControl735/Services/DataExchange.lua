-- One first-party GUILD queue. No interclient WHISPER transport.
local _,G=...
local X={queue={},maxQueue=32,nextAt=0,bytes=244,lastRefill=0,metrics={sent=0,bytes=0,otherBytes=0,dropped=0,coalesced=0,errors=0}}
G.DataExchange=X
function X:Paused()
 return self.loading or GetTime()<(self.resumeAt or 0)or UnitAffectingCombat("player")or(_G.ChatThrottleLib and _G.ChatThrottleLib.bQueueing)
end
function X:Enqueue(prefix,msg,guard,onSent,onDrop,notBefore)
 if G.ManualBans and prefix~=G.ManualBans.prefix and G.ManualBans:Blocked(UnitGUID("player"))then return false end
 if not IsInGuild()or not G:GetGuildKey()or type(prefix)~="string"or #prefix>16 or type(msg)~="string"or #msg>220 then return false end
 for _,item in ipairs(self.queue)do if item.prefix==prefix and item.message==msg and item.guard==guard then self.metrics.coalesced=self.metrics.coalesced+1;return true end end
 if #self.queue>=self.maxQueue then return false end
 self.queue[#self.queue+1]={prefix=prefix,message=msg,guard=guard,onSent=onSent,onDrop=onDrop,guild=G:GetGuildKey(),expires=GetTime()+30,notBefore=notBefore or 0}
 return true
end
function X:HasPending()
 local f,c,r=G.FastSync,G.CacheSync,G.RaidRuntime and G.RaidRuntime.engine
 return #self.queue>0 or (G.AutoSurvey and G.AutoSurvey.running~=nil)or (f and (f.job~=nil or f.active~=nil)) or (c and (c.client~=nil or c.server~=nil or c.wanted==true)) or (r and (r.pending~=nil or r.queue~=nil)) or false
end
function X:Stop(reason)
 if G.AutoSurvey and reason~="guild_event"then G.AutoSurvey:ManualStop()end
 self.metrics.dropped=self.metrics.dropped+#self.queue;self.queue={}
 if G.FastSync then G.FastSync:Stop("manual_stop")end
 if G.CacheSync then G.CacheSync:Stop(reason or "manual_stop")end
 if G.Character and G.Character.FamilyProtocol then G.Character.FamilyProtocol.generation=G.Character.FamilyProtocol.generation+1 end
 if G.RaidRuntime and G.RaidRuntime.engine then G.RaidRuntime.engine.pending=nil;G.RaidRuntime.engine.queue=nil end
end
function X:Tick()
 local now=GetTime();local elapsed=math.max(0,now-self.lastRefill);self.lastRefill=now
 local low=GetFramerate and GetFramerate()<20;local rate=low and 1024 or 2048
 self.bytes=math.min(244,self.bytes+math.min(elapsed,1)*rate)
 if self:Paused()or now<self.nextAt then return end
 local index,item;for i,q in ipairs(self.queue)do if now>=(q.notBefore or 0)then index,item=i,q;break end end;if not item then return end
 if not IsInGuild()or item.guild~=G:GetGuildKey()or now>item.expires or(G.ManualBans and item.prefix~=G.ManualBans.prefix and G.ManualBans:Blocked(UnitGUID("player")))or(item.guard and not item.guard())then
  table.remove(self.queue,index);self.metrics.dropped=self.metrics.dropped+1;if item.onDrop then item.onDrop()end;return
 end
 local cost=#item.prefix+#item.message+16;if self.bytes<cost then return end
 table.remove(self.queue,index);self.bytes=self.bytes-cost;self.nextAt=now+(low and 0.25 or 0.125)
 local ok,result=pcall(SendAddonMessage,item.prefix,item.message,"GUILD")
 if not ok or result==false then self.metrics.errors=self.metrics.errors+1;if item.onDrop then item.onDrop()end;return end
 self.metrics.sent=self.metrics.sent+1;self.metrics.bytes=self.metrics.bytes+cost
 if G.SpamShield then G.SpamShield:TX(item.prefix,#item.message,item.message)end
 if item.onSent then item.onSent()end
end
function G:RequestAllData()
 local ok,why=self.SecureExchange:Request()
 self:Print(ok and (G:Text("Сверка онлайн-персонажей запущена; передаются только изменения. /gc735 netstop — стоп."))or((G:Text("Запрос недоступен: "))..tostring(why)))
 return ok,why
end
function G:InitializeDataExchange()
 if X.frame then return end
 local f=CreateFrame("Frame");X.frame=f
 for _,event in ipairs({"PLAYER_LEAVING_WORLD","PLAYER_ENTERING_WORLD","PLAYER_GUILD_UPDATE"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,ev)
  if ev=="PLAYER_GUILD_UPDATE"then X:Stop("guild_event")
  elseif ev=="PLAYER_LEAVING_WORLD"then X.loading=true
  else X.loading=false;X.resumeAt=GetTime()+5 end
 end)
 f:SetScript("OnUpdate",function(_,dt)if dt and dt>0.25 then X.resumeAt=GetTime()+2 end;X:Tick()end)
 if hooksecurefunc and type(SendAddonMessage)=="function"then
  hooksecurefunc("SendAddonMessage",function(prefix,msg)
   local own=(G.FastWire and prefix==G.FastWire.prefix)or(G.CacheSync and prefix==G.CacheSync.prefix)or(G.ManualBans and prefix==G.ManualBans.prefix)or(G.AutoSurvey and prefix==G.AutoSurvey.prefix)
   if not own and prefix~="GC735N28"and prefix~="GC735C42"and prefix~="GC735TRUST"and prefix~="GC735VER"and type(prefix)=="string"and type(msg)=="string"then
    local cost=#prefix+#msg+16;X.bytes=math.max(-2048,X.bytes-cost);X.metrics.otherBytes=X.metrics.otherBytes+cost
   end
  end)
 end
 self.ProfileList:Initialize()
end
