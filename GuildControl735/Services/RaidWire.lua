-- Independent bounded raid-statistics protocol, shared verbatim by both addons.
local _, A = ...
local W = {prefix="GC735RAID", version="1", count=160, parts=16, cooldown=120}
A.RaidWire=W
W.raids=A:RegisterLocaleTable({},function()return {
 {name=(A:Text("Изумрудный Кошмар")),ej=768,bosses=7,ids={10911,10912,10913,10914,10920,10921,10922,10923,10924,10925,10926,10927,10915,10916,10917,10919,10928,10929,10930,10931,10932,10933,10934,10935,10936,10937,10938,10939}},
 {name=(A:Text("Испытание Доблести")),ej=861,bosses=3,ids={11407,11408,11409,11410,11411,11412,11413,11414,11415,11416,11417,11418}},
 {name=(A:Text("Цитадель Ночи")),ej=786,bosses=10,ids={10940,10941,10942,10943,10944,10945,10946,10947,10948,10949,10950,10951,10952,10953,10954,10955,10956,10957,10959,10960,10961,10962,10963,10964,10965,10966,10967,10968,10969,10970,10971,10972,10973,10974,10975,10976,10977,10978,10979,10980}},
 {name=(A:Text("Гробница Саргераса")),ej=875,bosses=9,ids={11877,11878,11879,11880,11881,11882,11883,11884,11885,11886,11887,11888,11889,11890,11891,11892,11893,11894,11895,11896,11897,11898,11899,11900,11901,11902,11903,11904,11905,11906,11907,11908,11909,11910,11911,11912}},
 {name=(A:Text("Анторус, Пылающий Трон")),ej=946,bosses=11,ids={12117,11954,11955,11956,12118,11957,11958,11959,12119,11960,11961,11962,12120,11963,11964,11965,12121,11966,11967,11968,12122,11969,11970,11971,12123,11972,11973,11974,12124,11975,11976,11977,12125,11978,11979,11980,12126,11981,11982,11983,12127,11984,11985,11986}},
} end)
function W.GUID(s)return type(s)=="string" and #s<=64 and s:match("^Player%-%x+%-%x+$")~=nil end
function W.Canonical(s,realm)
 if type(s)~="string"or #s>100 or s:find("[%z\1-\31\127|]")then return nil end
 local n,r=s:match("^([^-]+)%-(.+)$");n=n or s;r=r or realm
 if n==""or not r or r==""then return nil end
 return string.lower(n.."-"..r:gsub("%s+",""))
end
function W.Hash(s)
 local a,b=1,0;for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
 return tostring(b*65536+a)
end
function W.Value(v)
 if v=="u"then return "u"end
 if type(v)~="string"or not v:match("^%d+$")or #v>7 then return nil end
 local n=tonumber(v);if n>1000000 or tostring(n)~=v then return nil end;return v
end
function W.Split(s,sep)
 local t={};for v in (s..sep):gmatch("(.-)"..sep)do t[#t+1]=v end;return t
end
function W.Capture()
 local values={};local known=0
 for _,r in ipairs(W.raids)do for _,id in ipairs(r.ids)do
  local v="u"
  if type(GetStatistic)=="function"and type(GetAchievementInfo)=="function"then
   local ok,aid,name=pcall(GetAchievementInfo,id)
   if ok and aid==id and type(name)=="string"and name~=""then
    local good,raw=pcall(GetStatistic,id)
    -- '--' remains unknown until its semantics are verified on this realm.
    if good and type(raw)=="string"then
     local clean=raw:gsub("[,%.%s]",""):gsub("\194\160",""):gsub("\226\128\175","")
     v=W.Value(clean)or"u"
    elseif good and type(raw)=="number"and raw>=0 and raw<=1000000 and raw%1==0 then v=tostring(raw)end
   end
  end
  values[#values+1]=v;if v~="u"then known=known+1 end
 end end
 return values,known
end
function W.Frames(guid,at,values)
 if not W.GUID(guid)or type(at)~="number"or at%1~=0 or #values~=160 then return nil end
 for _,v in ipairs(values)do if not W.Value(v)then return nil end end
 local hash=W.Hash(table.concat(values,","));local frames={}
 for p=1,16 do
  local part={};for i=(p-1)*10+1,p*10 do part[#part+1]=values[i]end
  frames[p]=table.concat({"D","1",guid,tostring(at),hash,tostring(p),table.concat(part,",")},"|")
  if #frames[p]>240 then return nil end
 end
 return frames,hash
end
-- Dependencies keep synthetic and live transports separate; all parsing is identical.
function W.New(d)
 local e={d=d,assemblies={},queue=nil,requests={},rates={},metrics={sent=0,received=0,bytesOut=0,bytesIn=0,complete=0,rejected=0,duplicates=0,coalesced=0},scope=nil}
 function e:Reset()
  self.assemblies={};self.requests={};self.rates={};self.queue=nil;self.pending=nil;self.lastQuery=nil;self.lastSent=nil;self.pendingSender=nil;self.lastReject=nil;self.lastRejectSender=nil;self.lastRejectAt=nil
 end
 function e:Scope()
  local s=self.d.guild();if s~=self.scope then self:Reset();self.scope=s end;return s
 end
 function e:Emit(msg)
  if not self:Scope()then return false end
  local function sent()self.metrics.sent=self.metrics.sent+1;self.metrics.bytesOut=self.metrics.bytesOut+#msg end
  if self.d.asyncSend then return self.d.send(msg,sent)end
  if self.d.send(msg)==false then return false end;sent();return true
 end
 function e:Request(target)
  if not self:Scope()or (target~="ALL"and not W.GUID(target))then return false,"guild/target"end
  local now=self.d.clock()
  if self.lastQuery and now-self.lastQuery<15 then return false,"cooldown"end
  if not self:Emit("Q|1|"..target)then return false,"transport_busy"end;self.lastQuery=now;return true
 end
 function e:Reject(reason)self.lastReject=reason or "invalid_data";self.lastRejectAt=self.d.clock();self.lastRejectSender=self.lastSender;self.metrics.rejected=self.metrics.rejected+1;return false end
 function e:Receive(msg,sender,channel)
  self.lastSender=sender
  if self.d.admit and not self.d.admit(msg)then return self:Reject("secure_session_required")end
  if not self:Scope()or channel~="GUILD"or type(msg)~="string"or #msg>240 or #msg<5 or msg:find("[%z\1-\31\127]")then return self:Reject()end
  self.metrics.received=self.metrics.received+1;self.metrics.bytesIn=self.metrics.bytesIn+#msg
  local f=W.Split(msg,"|");if #f>7 or f[2]~="1"then return self:Reject("schema")end
  local identity=self.d.resolve(sender);if not W.GUID(identity)then return self:Reject("sender_identity")end
  local now=self.d.clock()
  local rate=self.rates[identity]
  if not rate or now-rate.at>=10 then
   if not rate then local n=0;for _ in pairs(self.rates)do n=n+1 end;if n>=500 then return self:Reject()end end
   rate={at=now,n=0};self.rates[identity]=rate
  end
  rate.n=rate.n+1;if rate.n>48 then return self:Reject("sender_rate")end
  if f[1]=="Q"then
   if #f~=3 or (f[3]~="ALL"and not W.GUID(f[3]))then return self:Reject("query_schema")end
   if self.d.authorize then local ok,why=self.d.authorize(sender);if not ok then return self:Reject("authorization:"..tostring(why or "denied"))end end
   if not self.d.capture or (f[3]~="ALL"and f[3]~=self.d.guid())then return true end
   if self.requests[identity]and now-self.requests[identity]<15 then return self:Reject("query_repeat")end
   self.requests[identity]=now
   if self.pending or self.queue or (self.lastSent and now-self.lastSent<120)or(self.d.lastPublished and self.d.wall()-self.d.lastPublished()<120)then
    self.metrics.coalesced=self.metrics.coalesced+1;return true
   end
   -- A sorted roster slot plus jitter avoids 300 clients all sending on the same tick.
   self.pendingSender=sender;self.pending=now+self.d.delay();return true
  end
  if f[1]~="D"or #f~=7 or f[3]~=identity or not W.GUID(f[3])then return self:Reject()end
  local at=tonumber(f[4]);local part=tonumber(f[6]);local hash=f[5]
  if not at or at%1~=0 or at<self.d.wall()-86400 or at>self.d.wall()+300 or not hash:match("^%d+$")or #hash>10
   or not part or part%1~=0 or part<1 or part>16 or tostring(part)~=f[6]then return self:Reject()end
  local vals=W.Split(f[7],",");if #vals~=10 then return self:Reject()end
  for _,v in ipairs(vals)do if not W.Value(v)then return self:Reject()end end
  local old=self.d.get and self.d.get(identity)
  if old and (old.capturedAt>at or(old.capturedAt==at and old.hash==hash))then self.metrics.duplicates=self.metrics.duplicates+1;return false end
  local a=self.assemblies[identity]
  if a and (a.at~=at or a.hash~=hash)then
   if a.at>=at then return self:Reject()end;a=nil
  end
  if not a then
   local n=0;for _ in pairs(self.assemblies)do n=n+1 end;if n>=500 then return self:Reject()end
   a={at=at,hash=hash,started=now,pieces={},count=0};self.assemblies[identity]=a
  end
  if a.pieces[part]then
   if a.pieces[part]~=f[7]then return self:Reject()end
   self.metrics.duplicates=self.metrics.duplicates+1;return true
  end
  a.pieces[part]=f[7];a.count=a.count+1
  if a.count==16 then
   self.assemblies[identity]=nil
   local payload=table.concat(a.pieces,",");if W.Hash(payload)~=hash then return self:Reject()end
   local values=W.Split(payload,",");if #values~=160 then return self:Reject()end
   local record={guid=identity,capturedAt=at,receivedAt=self.d.wall(),hash=hash,values=values,map=1,source="Satellite/self-report"}
   if self.d.save and self.d.save(record)==false then return self:Reject()end
   self.metrics.complete=self.metrics.complete+1
  end
  return true
 end
 function e:Tick()
  if not self:Scope()then return end
  local now=self.d.clock()
  for k,a in pairs(self.assemblies)do if now-a.started>150 then self.assemblies[k]=nil end end
  for k,t in pairs(self.requests)do if now-t>120 then self.requests[k]=nil end end
  for k,t in pairs(self.rates)do if now-t.at>120 then self.rates[k]=nil end end
  if (self.pending or self.queue)and self.d.authorize and not self.d.authorize(self.pendingSender)then
   self.pending=nil;self.queue=nil;self.pendingSender=nil;return
  end
  if self.pending and now>=self.pending then
   self.pending=nil
   if self.d.canSend and not self.d.canSend()then return end
   local values=self.d.capture();local frames=W.Frames(self.d.guid(),self.d.wall(),values)
   if frames then self.queue={frames=frames,index=1,next=now};self.lastSent=now
    if self.d.published then self.d.published(self.d.wall())end
   end
  end
  local q=self.queue
  if q and now>=q.next then
   if self.d.canSend and not self.d.canSend()then self.queue=nil;return end
   self:Emit(q.frames[q.index]);q.index=q.index+1;q.next=now+0.50
   if q.index>16 then self.queue=nil end
  end
 end
 return e
end
