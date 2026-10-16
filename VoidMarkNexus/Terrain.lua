local _, N = ...
-- Observed movement corridors, not a collision mesh. Edges are directional:
-- a walked drop does not prove that the reverse climb is possible.
local MAX_ZONES, MAX_POINTS, MAX_EDGES = 50, 600, 2400
local function point(p)
 return type(p)=='table' and N:Finite(p.x,0,1) and N:Finite(p.y,0,1)
end
function N:InitializeTerrain()
 local old=self.db.terrain
 local clean={version=1,zones={}}
 if type(old)=='table' and type(old.version)=='number' and old.version>1 then self.terrainDisabled=true; return end
 local count=0
 for map,z in pairs(type(old)=='table' and type(old.zones)=='table' and old.zones or {}) do
  if self:Finite(map,1,100000) and type(z)=='table' and count<MAX_ZONES then
   local zone={points={},edges={},revision=0}; local remap={}
   for i,p in ipairs(type(z.points)=='table' and z.points or {}) do
    if #zone.points>=MAX_POINTS then break end
    if point(p) then zone.points[#zone.points+1]={x=p.x,y=p.y};remap[i]=#zone.points end
   end
   local edges=0
   for a,list in pairs(type(z.edges)=='table' and z.edges or {}) do
    if remap[a] and type(list)=='table' then
     for b,e in pairs(list) do
      if edges<MAX_EDGES and remap[b] and a~=b and type(e)=='table' and
       self:Finite(e.distance,.01,100) and self:Finite(e.seconds,.01,30) and
       self:Finite(e.speed,1,50) and (e.mode=='ground' or e.mode=='swim') then
       zone.edges[remap[a]]=zone.edges[remap[a]] or {}
       zone.edges[remap[a]][remap[b]]={distance=e.distance,seconds=e.seconds,speed=e.speed,mode=e.mode,samples=self:Finite(e.samples,1,1000) and e.samples or 1}
       edges=edges+1
      end
     end
    end
   end
   zone.edgeCount=edges;clean.zones[map]=zone;count=count+1
  end
 end
 self.db.terrain=clean;self.terrainDisabled=false;self.trailPrevious=nil
 self.db.terrainBlocks=type(self.db.terrainBlocks)=='table' and self.db.terrainBlocks or {}
 for map,list in pairs(self.db.terrainBlocks) do
  local valid={}
  if type(list)=='table' then for _,o in ipairs(list) do
   if #valid>=100 then break end
   if point(o) and self:Finite(o.r,15,500) then valid[#valid+1]={x=o.x,y=o.y,r=o.r} end
  end end
  self.db.terrainBlocks[map]=valid
 end
end
function N:TerrainZone(map,create)
 if self.terrainDisabled or not self.db.terrain then return end
 local zones=self.db.terrain.zones
 if not zones[map] and create then
  local count=0;for _ in pairs(zones) do count=count+1 end
  if count>=MAX_ZONES then return end
  zones[map]={points={},edges={},edgeCount=0,revision=0}
 end
 return zones[map]
end
function N:ClearTerrain()
 self.planningThread=nil
 local map=self:Position(); if not map or self.terrainDisabled then return end
 self.db.terrain.zones[map]=nil;self.trailPrevious=nil;self.dirty=true
 self:Print('Learned trails cleared in this zone. Walk corridors to rebuild them; obstacle marks remain.')
end
function N:RecordTraversal(map,x,y,at,mode,speed)
 if not self.db.settings.terrainLearn or not self:Finite(map,1,100000) or
  not point({x=x,y=y}) or not self:Finite(at,0,1e12) or not self:Finite(speed,1,50) then self.trailPrevious=nil;return end
 local w,h=self:MapSize(map);if not w then self.trailPrevious=nil;return end
 local previous=self.trailPrevious
 local current={map=map,x=x,y=y,at=at,mode=mode,speed=speed}
 self.trailPrevious=current
 if not previous or previous.map~=map or previous.mode~=mode then return end
 local dt=at-previous.at
 local distance=self:Distance(previous,current,w,h)
 if dt<=0 or dt>2 or distance>40 or distance>math.max(speed,previous.speed)*dt*1.6+3 then return end
 if distance<8 then
  -- Retain a short baseline, but never join across a long stationary interval.
  if dt<1.5 then self.trailPrevious=previous end
  return
 end
 if self:TerrainIntersects(previous,current,w,h,map) then return end
 local z=self:TerrainZone(map,true);if not z then return end
 local function vertex(p)
  -- Reuse only a very tight positional sample; no edges to nearby unwalked points.
  for i,v in ipairs(z.points) do if self:Distance(p,v,w,h)<2 then return i end end
  if #z.points>=MAX_POINTS then return end
  z.points[#z.points+1]={x=p.x,y=p.y};return #z.points
 end
 local a,b=vertex(previous),vertex(current)
 if not a or not b or a==b then return end
 z.edges[a]=z.edges[a] or {};local e=z.edges[a][b]
 if not e and z.edgeCount>=MAX_EDGES then return end
 if e and e.mode~=mode then return end
 local samples=e and math.min(99,e.samples or 1) or 0
 z.edges[a][b]={distance=distance,seconds=((e and e.seconds or 0)*samples+dt)/(samples+1),
  speed=((e and e.speed or 0)*samples+speed)/(samples+1),samples=samples+1,mode=mode}
 if not e then z.edgeCount=z.edgeCount+1 end
 z.revision=z.revision+1
end
function N:SampleTerrain()
 if not self.ready then return end
 if self.planningThread then self.trailPrevious=nil;return end
 if self:Call(UnitOnTaxi,'player') or self:Call(IsFlying) or self:Call(UnitIsDeadOrGhost,'player')
  or self:Call(IsFalling) or not self.db.settings.terrainLearn then self.trailPrevious=nil;return end
 local map,x,y=self:Position();local speed=self:Call(GetUnitSpeed,'player')
 local mode=self:Call(IsSwimming) and 'swim' or 'ground'
 self:RecordTraversal(map,x,y,self:Call(GetTime) or self:Now(),mode,speed)
 self.lastMovementState={mounted=self:Call(IsMounted)==true,swimming=mode=='swim',form=self:Call(GetShapeshiftForm),speed=speed}
end
-- Bounded Dijkstra (A* with zero heuristic), so measured delays cannot make
-- an inadmissible straight-line heuristic choose a worse trail.
function N:LearnedTerrainLeg(a,b,w,h,map,speed)
 local z=self:TerrainZone(map);if not z or #z.points==0 then return end
 speed=math.max(1,speed or self.db.settings.speed)
 local first,last,da,db
 for i,p in ipairs(z.points) do
  local x,y=self:Distance(a,p,w,h),self:Distance(b,p,w,h)
  if x<=20 and (not da or x<da) and not self:TerrainIntersects(a,p,w,h,map) then first,da=i,x end
  if y<=20 and (not db or y<db) and not self:TerrainIntersects(p,b,w,h,map) then last,db=i,y end
 end
 if not first or not last or first==last then return end
 local cost={[first]=0};local previous,done={},{}
 for step=1,MAX_POINTS do
  self:PlannerCheckpoint()
  local chosen,best
  for i,value in pairs(cost) do if not done[i] and (not best or value<best) then chosen,best=i,value end end
  if not chosen then return end
  if chosen==last then break end
  done[chosen]=true
  for i,e in pairs(z.edges[chosen] or {}) do
   if e.mode=='ground' and not done[i] and not self:TerrainIntersects(z.points[chosen],z.points[i],w,h,map) then
    local seconds=math.max(e.distance/speed,e.seconds*e.speed/speed)
    local nextCost=best+seconds
    if not cost[i] or nextCost<cost[i] then cost[i]=nextCost;previous[i]=chosen end
   end
  end
 end
 if not cost[last] then return end
 local reverse={};local i=last;local length=0
 while i do
  reverse[#reverse+1]=z.points[i]
  local p=previous[i];if p then length=length+self:Distance(z.points[p],z.points[i],w,h) end
  if i==first then break end;i=p
  if #reverse>MAX_POINTS then return end
 end
 local via={};for j=#reverse,1,-1 do via[#via+1]={x=reverse[j].x,y=reverse[j].y,validated=j<#reverse} end
 return length+da+db,via,{kind='learned',seconds=cost[last]+(da+db)/speed,validatedDistance=length,connectorDistance=da+db}
end
function N:PlannerCheckpoint()
 if not self.planningThread or coroutine.running()~=self.planningThread then return end
 self.planningWork=(self.planningWork or 0)+1
 local clock=type(debugprofilestop)=='function' and debugprofilestop() or nil
 if self.planningWork>=2500 or (clock and self.planningClock and clock-self.planningClock>=3) then
  coroutine.yield();self.planningWork=0;self.planningClock=type(debugprofilestop)=='function' and debugprofilestop() or nil
 end
end
function N:RunPlanner(work,complete)
 if self.planningThread then return self:Print('A route calculation is already running. /vmn cancelplan to cancel.') end
 if self:Call(InCombatLockdown) then return self:Print('Plan routes outside combat.') end
 local thread=coroutine.create(work);self.planningThread=thread
 local function step()
  if self.planningThread~=thread then return end
  if self:Call(InCombatLockdown) then self.planningThread=nil;self:Print('Route calculation cancelled by combat.');return end
  self.planningClock=type(debugprofilestop)=='function' and debugprofilestop() or nil
  local ok,value=coroutine.resume(thread)
  if not ok then self.planningThread=nil;self:Error('route calculation',value);return end
  if coroutine.status(thread)=='dead' then self.planningThread=nil;self:Guard('route result',complete,value)
  elseif C_Timer and C_Timer.After then C_Timer.After(.01,step)
  else self.planningThread=nil;self:Print('Incremental route calculation requires client timers.') end
 end
 step()
end
for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','ZONE_CHANGED_NEW_AREA'}) do
 N:On(event,function() N.trailPrevious=nil end)
end
