local _, N = ...
_G.VoidMarkNexus = N
N.version, N.schema = '0.2.8-alpha', 1
N.handlers, N.jobs, N.errors = {}, {}, {}
function N:Now() return time() end
function N:Finite(v, lo, hi)
 return type(v)=='number' and not (issecretvalue and issecretvalue(v)) and v==v and v>=lo and v<=hi
end
function N:Text(v) return type(v)=='string' and not (issecretvalue and issecretvalue(v)) and v or nil end
function N:Call(fn,...)
 if type(fn)~='function' then return nil end
 local function pack(...) return {n=select('#',...),...} end
 local result=pack(pcall(fn,...))
 if result[1] then return unpack(result,2,result.n) end
end
function N:Copy(t)
 if type(t)~='table' then return t end
 local out={}; for k,v in pairs(t) do out[k]=self:Copy(v) end; return out
end
function N:Print(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffae82ffVoidMark Nexus:|r '..tostring(s)) end end
function N:Error(label,err)
 self.errors[#self.errors+1]=label..': '..tostring(err)
 if #self.errors>30 then table.remove(self.errors,1) end
 self:Print(self.errors[#self.errors]); self.dirty=true
end
function N:Guard(label,fn,...)
 local ok,err=pcall(fn,...); if not ok then self:Error(label,err) end; return ok
end
function N:On(event,fn)
 self.handlers[event]=self.handlers[event] or {}; table.insert(self.handlers[event],fn)
end
function N:Later(key,fn)
 if self.jobs[key] then return end
 self.jobs[key]=true
 local function run() self.jobs[key]=nil; self:Guard(key,fn) end
 if C_Timer and C_Timer.After then C_Timer.After(.15,run) else run() end
end
function N:Money(n)
 if not self:Finite(n,-1e15,1e15) then return 'Unknown' end
 local sign=n<0 and '-' or ''; n=math.floor(math.abs(n)+.5)
 return sign..string.format('%dg %ds %dc',math.floor(n/10000),math.floor(n/100)%100,n%100)
end
function N:Age(at)
 if not at then return 'Never scanned' end
 return string.format('%.1fh old', math.max(0,self:Now()-at)/3600)
end
function N:ItemID(link) return self:Text(link) and tonumber(link:match('item:(%d+)')) end
function N:ItemName(id)
 return self:Call(GetItemInfo,id) or self.db.itemNames[id] or ('Item '..tostring(id))
end
function N:Initialize()
 if type(VoidMarkNexusDB)~='table' then VoidMarkNexusDB={} end
 local d=VoidMarkNexusDB
 if tonumber(d.schema) and d.schema>self.schema then self:Print('Newer saved schema detected; Nexus disabled to preserve your data.'); return false end
 for _,k in ipairs({'characters','settings','prices','itemNames','plans','nodes','routes','sessions','wish','excluded'}) do if type(d[k])~='table' then d[k]={} end end
 local defaults={native=true,learn=true,importedNodes=true,observedNodes=true,nodesVisible=true,routeVisible=true,minimapRoute=true,stats=true,
 includeAlts=true,includeBanks=true,includeImports=false,includeStale=false,maxAge=86400,inventoryAge=604800,
 market=true,auctionator=false,manualFirst=false,cut=.05,deposit=0,failedAuctions=0,saleFraction=1,waste=0,
 speed=7,travel='Foot',mountDelay=0,gatherDelay=3,routeMinutes=20,nodeLimit=100,kind='all',target='',minimap=true,scale=1,arrowScale=1,mapIconSize=7,terrainLearn=true,manualStops=false}
 for k,v in pairs(defaults) do if type(d.settings[k])~=type(v) then d.settings[k]=v end end
 local bounds={maxAge={60,2592000},inventoryAge={60,2592000},cut={0,.3},deposit={0,1e8},failedAuctions={0,20},saleFraction={0,1},waste={0,1},speed={1,50},mountDelay={0,30},gatherDelay={0,60},routeMinutes={1,120},nodeLimit={2,150},scale={.6,1.5},arrowScale={.5,2}}
 for k,b in pairs(bounds) do if not self:Finite(d.settings[k],b[1],b[2]) then d.settings[k]=defaults[k] end end
 if d.settings.kind~='all' and d.settings.kind~='herb' and d.settings.kind~='ore' then d.settings.kind='all' end
 local position=d.settings.position
 if type(position)~='table' or not self:Finite(position[1],-20000,20000) or not self:Finite(position[2],-20000,20000) then d.settings.position=nil end
 d.schema=self.schema; d.account=d.account or ('VMN-'..tostring(self:Now())..'-'..tostring(math.random(100000,999999)))
 self.db=d
 local realm=self:Call(GetNormalizedRealmName) or self:Call(GetRealmName) or 'Unknown'
 local name=self:Call(UnitName,'player') or 'Unknown'; local guid=self:Call(UnitGUID,'player')
 self.characterID=d.account..'/'..realm..'/'..name
 local c=d.characters[self.characterID] or {professions={},bags={},bank={}}
 c.name,c.realm,c.faction,c.guid,c.account=name,realm,self:Call(UnitFactionGroup,'player') or 'Unknown',guid,d.account
 c.imported=false; c.at=self:Now(); c.professions=c.professions or {}; c.bags=c.bags or {}; c.bank=c.bank or {}
 d.characters[self.characterID]=c; self.character=c; self.economy=realm..'|'..c.faction
 d.prices[self.economy]=d.prices[self.economy] or {}; self.prices=d.prices[self.economy]
 if self.InitializeTerrain then self:InitializeTerrain() end
 self.ready=true; return true
end

