local _, N = ...
-- Derived data only. User routes and observed trails have independent lifetimes.
local VERSION, MAX_ROUTES, MAX_CONTEXTS, MAX_LEGS = 1, 12, 3, 512
local MAX_BYTES, MAX_ENTRY = 2097152, 262144
local function portable(value, budget, depth, seen)
 budget=budget or {bytes=0,nodes=0};depth=depth or 0;seen=seen or {}
 budget.nodes=budget.nodes+1
 assert(depth<14 and budget.nodes<180000,'Cache complexity limit')
 local kind=type(value)
 if kind=='table' then
  assert(not seen[value],'Cyclic cache');seen[value]=true
  local out={}
  for k,v in pairs(value) do
   assert(type(k)=='string' or type(k)=='number','Invalid cache key')
   out[portable(k,budget,depth+1,seen)]=portable(v,budget,depth+1,seen)
  end
  seen[value]=nil;return out,budget.bytes
 end
 assert(kind=='string' or kind=='boolean' or N:Finite(value,-1e14,1e14),'Invalid cache value')
 budget.bytes=budget.bytes+(kind=='string' and #value or 16)
 assert(budget.bytes<=MAX_BYTES,'Cache size limit')
 return value,budget.bytes
end
function N:PortableCache(value,limit)
 local ok,copy,bytes=pcall(portable,value)
 if ok and bytes<=(limit or MAX_ENTRY) then return copy,bytes end
end
local function fresh() return {version=VERSION,routes={},contexts={}} end
function N:InitializeCache()
 self.cacheStats={routes=0,legs=0,misses=0}
 local raw=self.db.calculations
 self.cacheReadOnly=type(raw)=='table' and type(raw.version)=='number' and raw.version>VERSION
 if self.cacheReadOnly then return end
 local clean=fresh()
 if type(raw)=='table' and raw.version==VERSION then
  local copy=self:PortableCache(raw,MAX_BYTES)
  if copy and type(copy.routes)=='table' and type(copy.contexts)=='table' then clean=copy end
 end
 self.db.calculations=clean
 self:PruneCalculationCache()
end
local function alive(self,entry,age)
 return type(entry)=='table' and type(entry.key)=='string' and #entry.key<=200000
  and self:Finite(entry.at,0,self:Now()) and self:Now()-entry.at<=age
end
function N:PruneCalculationCache()
 if self.cacheReadOnly then return end
 local c=self.db.calculations;local used=0
 for _,spec in ipairs({{'routes',MAX_ROUTES,604800},{'contexts',MAX_CONTEXTS,2592000}}) do
  local keep={}
  for _,entry in ipairs(c[spec[1]]) do
   if #keep>=spec[2] then break end
   local copy,bytes=self:PortableCache(entry,spec[1]=='routes' and 524288 or 786432)
   if copy and alive(self,copy,spec[3]) and used+bytes<=MAX_BYTES then
    if spec[1]=='contexts' then
     if type(copy.legs)=='table' and type(copy.order)=='table' then
      local legs,order={},{}
      for _,key in ipairs(copy.order) do
       if #order>=MAX_LEGS then break end
       if type(key)=='string' and #key<=160 and type(copy.legs[key])=='table' and not legs[key] then
        legs[key]=copy.legs[key];order[#order+1]=key
       end
      end
      copy.legs,copy.order=legs,order;keep[#keep+1]=copy;used=used+bytes
     end
    elseif type(copy.route)=='table' then keep[#keep+1]=copy;used=used+bytes end
   end
  end
  c[spec[1]]=keep
 end
end
function N:RouteSettings()
 local out={}
 for _,k in ipairs({'speed','travel','mountDelay','gatherDelay','routeMinutes','nodeLimit','kind','target',
  'importedNodes','observedNodes','routeSelectionMode','routeResources'}) do out[k]=self.db.settings[k] end
 return self:Copy(out)
end
function N:RoutingTerrain(map)
 local z=self:TerrainZone(map);if not z then return end
 local edges={}
 for a,list in pairs(z.edges or {}) do
  edges[a]={}
  for b,e in pairs(list) do
   edges[a][b]={distance=e.distance,seconds=e.seconds,speed=e.speed,mode=e.mode}
  end
 end
 return {points=z.points,edges=edges}
end
function N:RoutingNodes(nodes)
 local out={}
 for _,p in ipairs(nodes) do
  out[#out+1]={x=p.x,y=p.y,object=p.object,source=p.source,name=p.name,kind=p.kind,skill=p.skill}
 end
 table.sort(out,function(a,b)
  if a.x~=b.x then return a.x<b.x end
  if a.y~=b.y then return a.y<b.y end
  for _,field in ipairs({'object','source','name','kind','skill'}) do
   local av,bv=tostring(a[field] or ''),tostring(b[field] or '')
   if av~=bv then return av<bv end
  end
  return false
 end)
 return out
end
function N:CacheCompatibility()
 local version,build,_,interface=self:Call(GetBuildInfo)
 return {planner='terrain-v6',client=version,build=build,interface=interface}
end
function N:TravelContext(map,width,height,speed)
 if self.cacheReadOnly then return end
 local key=self:PlannerCacheKey({compat=self:CacheCompatibility(),map=map,width=width,height=height,speed=speed,
  terrain=self:RoutingTerrain(map),blocks=(self.db.terrainBlocks or {})[map]})
 if #key>200000 then return end
 local contexts=self.db.calculations.contexts
 for i,c in ipairs(contexts) do
  if c.key==key and alive(self,c,2592000) then
   table.remove(contexts,i);table.insert(contexts,1,c);c.at=self:Now()
   c.sizes={};c.bytes=0
   for k,v in pairs(c.legs) do
    local copy,bytes=self:PortableCache(v,8192)
    if copy then c.sizes[k]=bytes+#k;c.bytes=c.bytes+bytes+#k else c.legs[k]=nil end
   end
   return c
  end
 end
 local c={key=key,at=self:Now(),legs={},order={},sizes={},bytes=0}
 table.insert(contexts,1,c);while #contexts>MAX_CONTEXTS do table.remove(contexts) end
 return c
end
function N:CachedTerrainLeg(a,b,width,height,map,speed,context)
 if not context then return self:TerrainLeg(a,b,width,height,map,speed) end
 -- Exact normalized endpoints, directional; never infer the reverse of a walked drop.
 local key=string.format('%.17g:%.17g>%.17g:%.17g',a.x,a.y,b.x,b.y)
 local hit=context.legs[key]
 if type(hit)=='table' and self:Finite(hit.distance,0,1e12) and type(hit.via)=='table' then
  local copy=self:PortableCache(hit)
  if copy and #copy.via<=2048 and (not copy.info or type(copy.info)=='table' and
   (copy.info.seconds==nil or self:Finite(copy.info.seconds,0,1e12))) then
   local valid=true
   for _,field in ipairs({'validatedDistance','connectorDistance'}) do
    if copy.info and copy.info[field]~=nil and not self:Finite(copy.info[field],0,1e12) then valid=false end
   end
   for _,p in ipairs(copy.via) do
    if type(p)~='table' or not self:Finite(p.x,0,1) or not self:Finite(p.y,0,1) then valid=false;break end
   end
   if valid then self.cacheStats.legs=self.cacheStats.legs+1;return copy.distance,copy.via,copy.info end
  end
 end
 local distance,via,info=self:TerrainLeg(a,b,width,height,map,speed)
 if self:Finite(distance,0,1e12) then
  local copy,bytes=self:PortableCache({distance=distance,via=via or {},info=info},8192)
  if copy then
   if not context.legs[key] then context.order[#context.order+1]=key end
   context.sizes=context.sizes or {};context.bytes=(context.bytes or 0)-(context.sizes[key] or 0)+bytes+#key
   context.sizes[key]=bytes+#key
   context.legs[key]=copy
   while #context.order>MAX_LEGS or context.bytes>400000 do
    local old=table.remove(context.order,1);if not old then break end
    context.bytes=context.bytes-(context.sizes[old] or 0);context.sizes[old]=nil;context.legs[old]=nil
   end
  end
 end
 return distance,via,info
end
function N:ClearCalculations()
 self:CancelPlanner()
 if self.cacheReadOnly then return self:Print('Newer calculation format preserved; cache disabled for this version.') end
 self.db.calculations=fresh();self.plannerCache=nil;self.cacheStats={routes=0,legs=0,misses=0}
 self:Print('Computed route cache cleared. Saved routes, recordings and learned trails retained.')
end
function N:CacheSummary()
 if self.cacheReadOnly then return 'Newer saved calculation format preserved; caching disabled in this version.' end
 local c=self.db.calculations or {};local count=0
 for _,context in ipairs(type(c.contexts)=='table' and c.contexts or {}) do count=count+#(context.order or {}) end
 local s=self.cacheStats or {}
 return string.format('Saved calculations: %d routes, %d travel legs. This login: %d route reuses, %d leg reuses.',
  #(type(c.routes)=='table' and c.routes or {}),count,s.routes or 0,s.legs or 0)
end
N:On('PLAYER_LOGOUT',function() N:PruneCalculationCache() end)
