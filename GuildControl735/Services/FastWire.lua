-- Original GC735N28 wire framing; no GRM source. SHA-256 follows FIPS 180-4;
-- first 128 bits are a content fingerprint, never an authorization token.
local _,G=...
local W={prefix="GC735N47",chunk=193,limit=220,categories={"P","F","R"},caps={P=256,F=1024,R=1400},containerCap=2697}
G.FastWire=W
local B=bit or bit32
local K={1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298}
local function U(n)return n%4294967296 end
function W.Hash(s)
 if not B then return nil end
 local band,bxor,bnot,rshift=B.band,B.bxor,B.bnot,B.rshift
 local function rr(x,n)return U(rshift(x,n)+U(x)*2^(32-n))end
 -- Avoid imprecise large multiplication: rotate via low n bits only.
 rr=function(x,n)return U(rshift(x,n)+band(x,2^n-1)*2^(32-n))end
 local bits=#s*8;local pad=(55-#s)%64
 s=s..string.char(128)..string.rep(string.char(0),pad)..string.char(0,0,0,0,math.floor(bits/16777216)%256,math.floor(bits/65536)%256,math.floor(bits/256)%256,bits%256)
 local h={1779033703,3144134277,1013904242,2773480762,1359893119,2600822924,528734635,1541459225}
 for off=1,#s,64 do
  local w={}
  for i=0,15 do local a,b,c,d=s:byte(off+i*4,off+i*4+3);w[i]=a*16777216+b*65536+c*256+d end
  for i=16,63 do
   local x,y=w[i-15],w[i-2]
   w[i]=U(w[i-16]+U(bxor(rr(x,7),rr(x,18),rshift(x,3)))+w[i-7]+U(bxor(rr(y,17),rr(y,19),rshift(y,10))))
  end
  local a,b,c,d,e,f,g,hh=unpack(h)
  for i=0,63 do
   local t=U(hh+U(bxor(rr(e,6),rr(e,11),rr(e,25)))+U(bxor(band(e,f),band(bnot(e),g)))+K[i+1]+w[i])
   local q=U(U(bxor(rr(a,2),rr(a,13),rr(a,22)))+U(bxor(band(a,b),band(a,c),band(b,c))))
   hh,g,f,e,d,c,b,a=g,f,e,U(d+t),c,b,a,U(t+q)
  end
  local out={a,b,c,d,e,f,g,hh};for i=1,8 do h[i]=U(h[i]+out[i])end
 end
 local out={};for i=1,4 do out[i]=string.format("%04x%04x",math.floor(h[i]/65536),h[i]%65536)end;return table.concat(out)
end
function W.GUID(s)return type(s)=="string"and #s<=32 and s:match("^Player%-%d+%-%x+$")~=nil end
function W.Split(s,sep)
 local t={};for v in(s..sep):gmatch("(.-)"..sep)do t[#t+1]=v end;return t
end
function W.Int(s,lo,hi)
 if type(s)~="string"or not s:match("^%d+$")or #s>13 then return nil end
 local n=tonumber(s);return n and n>=lo and n<=hi and n%1==0 and n or nil
end
function W.Summary(records)
 local rows={}
 for _,cat in ipairs(W.categories)do local r=records[cat]
  rows[#rows+1]=r and string.format("%013.0f,%05d,%s",r.rev,r.len,r.hash)or("0000000000000,00000,"..string.rep("0",32))
 end
 return table.concat(rows,";")
end
function W.ParseSummary(s)
 if type(s)~="string"or #s~=158 then return nil end
 local rows=W.Split(s,";");if #rows~=3 then return nil end
 local records={}
 for i,cat in ipairs(W.categories)do
  local a,b,h=rows[i]:match("^(%d%d%d%d%d%d%d%d%d%d%d%d%d),(%d%d%d%d%d),([0-9a-f]+)$")
  local rev=W.Int(a,0,9999999999999);local len=W.Int(b,0,W.caps[cat])
  if not rev or not len or not h or #h~=32 then return nil end
  if rev==0 then if len~=0 or h~=string.rep("0",32)then return nil end
  else records[cat]={rev=rev,len=len,hash=h}end
 end
 return records
end
function W.Same(a,b)return a and b and a.rev==b.rev and a.len==b.len and a.hash==b.hash end
function W.Parts(sid,cat,body)
 local cap=cat=="X"and W.containerCap or W.caps[cat]
 if not cap or #body>cap then return nil end
 local rows={};local total=math.ceil(#body/W.chunk)
 for seq=1,total do rows[seq]=string.format("D|%s|%s|%02d|%02d|%s",sid,cat,seq,total,body:sub((seq-1)*W.chunk+1,seq*W.chunk))end
 return rows
end

-- Original transport-only packing. Canonical records and their hashes persist.
function W.CompactFamily(body,owner)
 local stamp,main,raw=body:match("^(%d+)|([^|]+)|([^|]+)$")
 if not stamp or not W.GUID(owner)then return nil end
 local ids=W.Split(raw,",");local others,seen={},{}
 if #ids<1 or #ids>12 then return nil end
 for _,id in ipairs(ids)do
  if not W.GUID(id)or seen[id]then return nil end
  seen[id]=true;if id~=owner then others[#others+1]=id end
 end
 if not seen[owner]then return nil end
 table.sort(others)
 local index=main=="-"and"-"or main==owner and"0"or nil
 for i,id in ipairs(others)do if id==main then index=tostring(i)end end
 if not index then return nil end
 return stamp.."|"..index.."|"..table.concat(others,",")
end
function W.ExpandFamily(body,owner)
 local stamp,index,raw=body:match("^(%d+)|([^|]+)|(.*)$")
 if not stamp or not W.GUID(owner)then return nil end
 local ids=raw==""and{}or W.Split(raw,",");if #ids>11 then return nil end
 local seen={[owner]=true};local last
 for _,id in ipairs(ids)do
  if not W.GUID(id)or seen[id]or(last and id<=last)then return nil end
  seen[id]=true;last=id
 end
 local main
 if index=="-"then main="-"
 else local n=W.Int(index,0,#ids);if not n or tostring(n)~=index then return nil end;main=n==0 and owner or ids[n]end
 ids[#ids+1]=owner;table.sort(ids)
 return stamp.."|"..main.."|"..table.concat(ids,",")
end
-- Original bounded run-length codec for transport only; no external code.
-- Unknown 'u' stays unknown. Canonical timestamps, order and values survive.
function W.CompactRaid(body)
 if type(body)~="string"or #body>W.caps.R then return nil end
 local stamp,raw=body:match("^(%d+)|(.*)$");if not stamp then return nil end
 local values=W.Split(raw,",");if #values~=160 then return nil end
 for _,value in ipairs(values)do if not G.RaidWire.Value(value)then return nil end end
 local tokens={};local i=1
 while i<=160 do
  local value=values[i];local last=i
  while last<160 and values[last+1]==value do last=last+1 end
  local count=last-i+1;local run=tostring(count).."*"..value
  if count>=2 and #run<count*(#value+1)-1 then tokens[#tokens+1]=run
  else for _=i,last do tokens[#tokens+1]=value end end
  i=last+1
 end
 local compact=stamp.."|"..table.concat(tokens,",")
 if #compact<#body then return compact end
 return body
end
function W.ExpandRaid(body,expected)
 if type(body)~="string"or #body>W.caps.R or not expected or expected>W.caps.R then return nil end
 local stamp,raw=body:match("^(%d+)|(.*)$");if not stamp or #stamp>13 then return nil end
 local tokens=W.Split(raw,",");if #tokens<1 or #tokens>160 then return nil end
 local values={};local bytes=#stamp+1
 for _,token in ipairs(tokens)do
  if #token>11 then return nil end
  local number,value=token:match("^(%d+)%*([%du]+)$");local count=1
  if number then
   count=W.Int(number,2,160)
   if not count or tostring(count)~=number then return nil end
  else value=token end
  if not G.RaidWire.Value(value)or #values+count>160 then return nil end
  -- Bound expansion before allocation, including delimiters already implied.
  local extra=count*(#value+1);if #values==0 then extra=extra-1 end
  if bytes+extra>expected then return nil end
  bytes=bytes+extra
  for _=1,count do values[#values+1]=value end
 end
 if #values~=160 or bytes~=expected then return nil end
 return stamp.."|"..table.concat(values,",")
end

function W.Pack(records,known,owner)
 local bodies,lengths={},{};local any=false
 for _,cat in ipairs(W.categories)do local r=records[cat];local b=""
  if r and r.len>0 and not W.Same(r,known[cat])then
   if cat=="F"then b=W.CompactFamily(r.body,owner)elseif cat=="R"then b=W.CompactRaid(r.body)else b=r.body end
   if not b or #b>W.caps[cat]then return nil,"pack_record"end
   any=true
  end
  bodies[#bodies+1]=b;lengths[#lengths+1]=tostring(#b)
 end
 if not any then return ""end
 return table.concat(lengths,",").."|"..table.concat(bodies)
end
function W.PackedHeader(body,meta,known)
 local p,f,r=body:match("^(%d+),(%d+),(%d+)|")
 if not p or #p>4 or #f>4 or #r>4 then return nil,"container_header"end
 local lengths={p,f,r};local header=#p+#f+#r+3;local bytes=header
 for i,cat in ipairs(W.categories)do
  local n=W.Int(lengths[i],0,W.caps[cat]);if not n or tostring(n)~=lengths[i]then return nil,"container_length"end
  local m=meta[cat];local needed=m and m.len>0 and not W.Same(m,known[cat])
  if needed then
   if n<1 or((cat=="F"or cat=="R")and n>m.len)or(cat=="P"and n~=m.len)then return nil,"container_categories"end
  elseif n~=0 then return nil,"container_unchanged"end
  lengths[i]=n;bytes=bytes+n
 end
 return {lengths=lengths,header=header,bytes=bytes}
end
function W.Unpack(body,meta,known,owner)
 local h,why=W.PackedHeader(body,meta,known);if not h then return nil,why end
 if #body~=h.bytes then return nil,"container_length"end
 local rows={};local at=h.header+1
 for i,cat in ipairs(W.categories)do local n=h.lengths[i]
  if n>0 then
   local raw=body:sub(at,at+n-1);at=at+n
   if cat=="F"then raw=W.ExpandFamily(raw,owner)elseif cat=="R"then raw=W.ExpandRaid(raw,meta[cat].len)end
   if not raw or #raw~=meta[cat].len or W.Hash(raw)~=meta[cat].hash then return nil,"checksum"end
   rows[cat]=raw
  end
 end
 return rows
end
