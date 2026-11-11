local _, N = ...
_G.VoidMarkNexus = N
N.schema = 1
do -- One source of truth: the TOC's Version line (the fallback must match it).
 local get=(C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
 local ok,v=pcall(type(get)=='function' and get or error,'VoidMarkNexus','Version')
 N.version=(ok and type(v)=='string' and v~='') and v or '0.7.1-beta'
end
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
 if result[1] then
  if issecretvalue then for i=2,result.n do if issecretvalue(result[i]) then result[i]=nil end end end
  return unpack(result,2,result.n)
 end
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
-- Forever characters have a first name and a surname ("Voidmark Bank").
-- UnitName returns only the first name, so every character looked like
-- "Voidmark" and cross-account sync rejected the bank's data.
function N:UnitFullName(unit)
 unit=unit or 'player'
 if NameUtil and NameUtil.GetUnmodifiedUnitFullName and NameUtil.GetFullNameWithoutRealm and UnitNameUnmodified then
  local first,last=self:Call(UnitNameUnmodified,unit)
  first,last=self:Text(first),self:Text(last)
  if first and first~='' then
   local full=self:Text(self:Call(NameUtil.GetFullNameWithoutRealm,first,last))
   if full and full~='' then return full end
   return (last and last~='') and (first..' '..last) or first
  end
 end
  local first,second=self:Call(UnitName,unit)
 first,second=self:Text(first),self:Text(second)
 if not first or first=='' then return nil end
 -- Forever returns the surname in the slot other clients use for a realm.
 local realm=self:Text(self:Call(GetRealmName)) or ''
 if second and second~='' and second:gsub('%s',''):lower()~=realm:gsub('%s',''):lower() and not first:find(' ',1,true) then
  return first..' '..second
 end
 return first
end
function N:SameRealm(a,b)
 if type(a)~='string' or type(b)~='string' then return a==b end
 return a:gsub('%s',''):lower()==b:gsub('%s',''):lower()
end
-- Move this character's old record (saved under the first name only, or an
-- older realm spelling) to its full-name ID. Matched by GUID, so it is always
-- the same physical character. Older same-GUID copies are stale duplicates.
function N:MigrateCharacterID(d,newID,guid)
 if not guid or d.characters[newID] then return end
 local best,bestID,dups=nil,nil,{}
 for id,c in pairs(d.characters) do
  if id~=newID and type(c)=='table' and not c.imported and c.guid==guid then
   dups[#dups+1]=id
   if not best or (tonumber(c.at) or 0)>(tonumber(best.at) or 0) then best,bestID=c,id end
  end
 end
 if not best then return end
 d.characters[newID]=best
 for _,id in ipairs(dups) do
  d.characters[id]=nil; d.excluded[id]=nil
  for _,k in ipairs({'recordings','activeSessions','navigation'}) do
   local t=d[k]; if type(t)=='table' and t[id]~=nil then if id==bestID and t[newID]==nil then t[newID]=t[id] end; t[id]=nil end
  end
  for _,plan in ipairs(d.plans) do if type(plan)=='table' and plan.character==id then plan.character=newID end end
 end
 self.migratedFrom=bestID
end
-- One saved record per real character. Copies happen (an import plus a sync,
-- an old realm spelling); the one you are playing wins, then the newest.
-- A full "First Surname" is unique on a realm, so it identifies the character
-- even when one copy has no GUID. Old first-name-only records fall back to GUID.
function N:PhysicalKey(c)
 local name=tostring(c.name or '')
 if not name:find(' ',1,true) and type(c.guid)=='string' and c.guid~='' then return c.guid end
 return tostring(c.realm or ''):gsub('%s',''):lower()..'/'..name:lower()
end
local function fresh(c) return math.max(tonumber(c.at) or 0,tonumber(c.bagsAt) or 0,tonumber(c.bankAt) or 0,tonumber(c.syncedAt) or 0) end
function N:PreferredRecords()
 local best={}
 for cid,c in pairs(self.db.characters) do
  if type(c)=='table' then
   local k=self:PhysicalKey(c); local cur=best[k]
   if not cur or cid==self.characterID or (cur~=self.characterID and (fresh(c)>fresh(self.db.characters[cur]) or (fresh(c)==fresh(self.db.characters[cur]) and cid<cur))) then best[k]=cid end
  end
 end
 local out={}; for _,cid in pairs(best) do out[cid]=true end
 return out
end
function N:ItemID(link) return self:Text(link) and tonumber(link:match('item:(%d+)')) end
function N:ItemName(id)
 return self:Call(GetItemInfo,id) or self.db.itemNames[id] or ('Item '..tostring(id))
end
function N:Initialize()
 if type(VoidMarkNexusDB)~='table' then VoidMarkNexusDB={} end
 local d=VoidMarkNexusDB
 if tonumber(d.schema) and d.schema>self.schema then self:Print('Newer saved schema detected; Nexus disabled to preserve your data.'); return false end
 for _,k in ipairs({'characters','settings','prices','itemNames','plans','nodes','routes','sessions','wish','excluded','levelEvidence','trainers','recipeVendors','spots','laps'}) do if type(d[k])~='table' then d[k]={} end end
 local defaults={native=true,learn=true,importedNodes=true,observedNodes=true,nodesVisible=true,routeVisible=true,minimapRoute=true,learnSpots=true,stats=true,
 includeAlts=true,includeBanks=true,includeImports=false,includeStale=false,maxAge=86400,inventoryAge=604800,
 market=true,auctionator=false,manualFirst=false,cut=.05,deposit=0,failedAuctions=0,saleFraction=1,waste=0,
 speed=7,travel='Foot',mountDelay=0,gatherDelay=3,routeMinutes=20,nodeLimit=100,kind='all',target='',minimap=true,scale=1,arrowScale=1,mapIconSize=7,terrainLearn=true,manualStops=false,mapButton=true,tomtom=true,tomtomArrow=false,levelMode='Cheapest',includeSynced=true,levelResale=true,levelCraftValue=500,tooltipCounts=true}
 for k,v in pairs(defaults) do if type(d.settings[k])~=type(v) then d.settings[k]=v end end
 d.settings.hideArrowInCombat=nil; d.settings.minimapHideNear=nil -- retired in 0.6.1
 local bounds={levelCraftValue={0,1e7},maxAge={60,2592000},inventoryAge={60,2592000},cut={0,.3},deposit={0,1e8},failedAuctions={0,20},saleFraction={0,1},waste={0,1},speed={1,50},mountDelay={0,30},gatherDelay={0,60},routeMinutes={1,120},nodeLimit={2,150},scale={.6,1.5},arrowScale={.5,2}}
 for k,b in pairs(bounds) do if not self:Finite(d.settings[k],b[1],b[2]) then d.settings[k]=defaults[k] end end
 if d.settings.levelMode~='Cheapest' and d.settings.levelMode~='Fastest' and d.settings.levelMode~='Self-found' and d.settings.levelMode~='Balanced' then d.settings.levelMode='Cheapest' end
 if d.settings.kind~='all' and d.settings.kind~='herb' and d.settings.kind~='ore' then d.settings.kind='all' end
 local position=d.settings.position
 if type(position)~='table' or not self:Finite(position[1],-20000,20000) or not self:Finite(position[2],-20000,20000) then d.settings.position=nil end
 -- 0.5 redesign: the new route builder does not use learned trails, so stop
 -- recording them in the background (saved trails are kept).
 if not d.settings.redesign05 then d.settings.redesign05=true; d.settings.terrainLearn=false end
 d.schema=self.schema; d.account=d.account or ('VMN-'..tostring(self:Now())..'-'..tostring(math.random(100000,999999)))
 self.db=d
 local realm=self:Call(GetNormalizedRealmName) or self:Call(GetRealmName) or 'Unknown'
 local name=self:UnitFullName('player') or 'Unknown'; local guid=self:Text(self:Call(UnitGUID,'player'))
 self.characterID=d.account..'/'..realm..'/'..name
 self:MigrateCharacterID(d,self.characterID,guid)
 local c=d.characters[self.characterID] or {professions={},bags={},bank={}}
 c.name,c.realm,c.faction,c.guid,c.account=name,realm,self:Call(UnitFactionGroup,'player') or 'Unknown',guid,d.account
 c.imported=false; c.at=self:Now(); c.professions=c.professions or {}; c.bags=c.bags or {}; c.bank=c.bank or {}
 d.characters[self.characterID]=c; self.character=c; self.economy=realm..'|'..c.faction
 d.prices[self.economy]=d.prices[self.economy] or {}; self.prices=d.prices[self.economy]
 if self.InitializeSync then self:InitializeSync() end
 if self.InitializeTerrain then self:InitializeTerrain() end
 if self.InitializeCache then self:InitializeCache() end
 if self.InitializeRecording then self:InitializeRecording() end
 self.ready=true; return true
end

