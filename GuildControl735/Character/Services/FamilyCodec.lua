-- Original SNAP2 framing. Voluntary self-report; never account ownership proof.
local _, GC = ...
local Addon = GC.Character
local C = {}; Addon.FamilyCodec = C
C.MAX_PARTS, C.CHUNK, C.MAX_BYTES = 48, 140, 6720
function C.GUID(v)
    return type(v)=="string" and #v<=80 and v:match("^Player%-%d+%-%x+$")~=nil
end
function C.Name(v)
    return type(v)=="string" and #v>0 and #v<=80 and not v:find("[%z\1-\31\127|,]")
end
function C.Hex(v) return (v:gsub(".",function(c)return string.format("%02x",string.byte(c))end)) end
function C.Unhex(v)
    if #v%2~=0 or v:find("[^0-9a-f]") then return nil end
    return (v:gsub("..",function(c)return string.char(tonumber(c,16))end))
end
function C.Encode(guild, selfGUID, main, members, revision, stamp)
    if not C.GUID(selfGUID) or (main and not C.GUID(main)) or #guild>161 then return nil end
    local fields={guild,selfGUID,main or "-"}; local seen={}
    local count=0
    for _,m in ipairs(members) do
        if not C.GUID(m.guid) or not C.Name(m.name) or seen[m.guid] then return nil end
        count=count+1; seen[m.guid]=true
        fields[#fields+1]=m.guid..","..m.name
    end
    if count<1 or count>12 or not seen[selfGUID] or (main and not seen[main]) then return nil end
    local hex=C.Hex(table.concat(fields,"\030"))
    if #hex>C.MAX_BYTES then return nil end
    local n=math.ceil(#hex/C.CHUNK); local packets={}
    for i=1,n do
        packets[i]=table.concat({"SNAP","2",tostring(revision),tostring(stamp),tostring(i),tostring(n),hex:sub((i-1)*C.CHUNK+1,i*C.CHUNK)},"|")
        if #packets[i]>220 then return nil end
    end
    return packets
end
function C.Decode(hex)
    if #hex>C.MAX_BYTES then return nil end
    local raw=C.Unhex(hex); if not raw then return nil end
    local f={}; for v in (raw.."\030"):gmatch("(.-)\030") do f[#f+1]=v end
    if #f<4 or #f>15 or #f[1]>161 or not C.GUID(f[2]) then return nil end
    local main=f[3]~="-" and f[3] or nil
    if main and not C.GUID(main) then return nil end
    local members,seen={},{}
    for i=4,#f do
        local guid,name=f[i]:match("^([^,]+),([^,]+)$")
        if not C.GUID(guid) or not C.Name(name) or seen[guid] then return nil end
        seen[guid]=true;members[#members+1]={guid=guid,name=name}
    end
    if not seen[f[2]] or (main and not seen[main]) then return nil end
    return {guild=f[1],senderGUID=f[2],mainGUID=main,members=members}
end
