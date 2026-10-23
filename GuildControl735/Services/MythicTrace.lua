-- Local diagnostic observer only; never sends, accepts or modifies a response.
local _,GC=...
local D={};GC.MythicTrace=D
local payloads={SMSG_RT_PLAYER_CHALLENGE_STATISTIC_RESPONSE=true,
 SMSG_RT_PLAYER_CHALLENGE_STATISTIC_BEST_RUNS_RESPONSE=true,
 SMSG_RT_PLAYER_CHALLENGE_STATISTIC_RUNS_RESPONSE=true,SMSG_RT_PLAYER_STATISTIC_CREATE=true}
function D:Begin(a)
 if a.bracket~=-2 or not GC.db then return end
 local db=GC.db.mythicTrace
 if type(db)~="table"or db.schema~=1 or type(db.requests)~="table"then db={schema=1,sequence=0,requests={}};GC.db.mythicTrace=db end
 db.sequence=(tonumber(db.sequence)or 0)+1
 local t={id=db.sequence,build=GC.build,observerGUID=UnitGUID("player"),observer=UnitName("player"),
  guid=a.guid,number=a.number,realm=a.realm,bracket=a.bracket,guild=a.guild,at=date("%Y-%m-%d %H:%M:%S"),
  started=GetTime(),events={},counts={},rx=0,bytes=0,storedBytes=0,dropped=0,
  txPrefix="UIMSG_TO_SERVER",txChannel="WHISPER",txTarget=UnitName("player")}
 db.requests[#db.requests+1]=t
 while #db.requests>8 do table.remove(db.requests,1)end
 a.trace=t
 self:Event(t,"start","CMSG_RT_GET_PLAYER_STATISTIC",tostring(a.number).."|"..a.realm.."|-2")
end
function D:Event(t,kind,reason,raw)
 if not t then return end
 local key=kind..":"..tostring(reason or "")
 -- Only a fixed set of parser decisions/opcodes enters counters.
 t.counts[key]=(t.counts[key]or 0)+1
 if #t.events>=128 then t.dropped=t.dropped+1;return end
 local e={ms=math.floor((GetTime()-t.started)*1000),kind=kind,reason=reason}
 if raw then
  if #raw<=8192 and t.storedBytes+#raw<=65536 then e.raw=raw;t.storedBytes=t.storedBytes+#raw
  else e.omittedBytes=#raw;t.dropped=t.dropped+1 end
 end
 t.events[#t.events+1]=e
 return e
end
function D:Receive(t,message,channel,senderOK,accepted,reason)
 if not t then return end
 if channel~="WHISPER"or not senderOK then
  -- Aggregate untrusted noise, never store its payload or one event per packet.
  local key=channel~="WHISPER"and"channel"or"sender"
  t.counts[key]=(t.counts[key]or 0)+1;return
 end
 local op=type(message)=="string"and message:match("^([A-Z_]+)|")
 if op and op:find("PVP",1,true)then return end
 if op=="SMSG_RT_PLAYER_STATISTIC_CREATE"and type(message)=="string"and #message<=8192 then
  local bracket=tonumber(message:match("|([%-0-9]+)|?$"))
  if bracket==7 or bracket==0 or bracket==3 or bracket==9 then return end
 end
 t.rx=t.rx+1;t.bytes=t.bytes+(type(message)=="string"and #message or 0)
 local known=op and payloads[op]
 -- Unknown/private member, equipment, IP/HWID and PvP payloads are never saved.
 -- Permit raw only for the four public Mythic/final opcodes, bounded above.
 local event=self:Event(t,"rx",known and op or "other",known and message or nil)
 if not known and op and event then event.opcode=op:sub(1,96)end
 if accepted~=nil or reason then self:Event(t,"decision",accepted and "accepted"or(reason or "rejected"))end
 return true
end
function D:Cancel(t)
 local e=self:Event(t,"cancel","caller_cancelled")
 if e and type(debugstack)=="function"then
  local ok,stack=pcall(debugstack,3,5,0)
  if ok and type(stack)=="string"then e.stack=stack:sub(1,1024)end
 end
end
