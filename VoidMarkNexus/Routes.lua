local _, N = ...
N.travelModes={{'Foot',7,0},{'60% Mount',11.2,3},{'100% Mount',14,3},{'Travel Form',9.8,1.5},{'Custom',7,0}}
function N:MapSize(map)
 if C_Map and C_Map.GetMapWorldSize then
  local width,height=self:Call(C_Map.GetMapWorldSize,map)
  if self:Finite(width,1,100000) and self:Finite(height,1,100000) then return width,height end
 end
 return nil
end
function N:Distance(a,b,width,height)
 return math.sqrt(((a.x-b.x)*width)^2+((a.y-b.y)*height)^2)
end
-- Player-marked obstacles provide local geometry absent from the WoW map API.
-- Each circle uses normalized map coordinates and a radius in world yards.
function N:MarkRouteObstacle(radius)
 self:CancelPlanner()
 local map,x,y=self:Position()
 if not map then return self:Print('Current zone position unavailable.') end
 local r=math.max(15,math.min(500,tonumber(radius) or 90))
 self.db.terrainBlocks=self.db.terrainBlocks or {}
 local list=self.db.terrainBlocks[map] or {}
 if #list>=100 then return self:Print('Maximum 100 marked obstacles per zone.') end
 list[#list+1]={x=x,y=y,r=r}
 self.db.terrainBlocks[map]=list
 self.dirty=true
 self:Print('Marked obstacle ('..r..' yards) at your location. Regenerate route.')
end
function N:ClearRouteObstacles()
 self:CancelPlanner()
 local map=self:Position()
 if not map then return end
 self.db.terrainBlocks=self.db.terrainBlocks or {}
 self.db.terrainBlocks[map]=nil
 self.dirty=true
 self:Print('Cleared obstacle marks in this zone.')
end
-- Grounded obstacle geometry: saved user marks, never inferred from map artwork.
function N:TerrainIntersects(a,b,width,height,map)
 local blocks=self.db and self.db.terrainBlocks and self.db.terrainBlocks[map]
 if not blocks then return false end
 local ax,ay=a.x*width,a.y*height
 local dx,dy=(b.x-a.x)*width,(b.y-a.y)*height
 local length=dx*dx+dy*dy
 for _,o in ipairs(blocks) do
  local cx,cy=o.x*width,o.y*height
  local t=length>0 and math.max(0,math.min(1,((cx-ax)*dx+(cy-ay)*dy)/length)) or 0
  local ex,ey=ax+t*dx-cx,ay+t*dy-cy
  if ex*ex+ey*ey<(o.r+12)^2 then return true end
 end
 return false
end
function N:TerrainLeg(a,b,width,height,map,speed)
 local learned,via,evidence=self:LearnedTerrainLeg(a,b,width,height,map,speed)
 if learned then return learned,via,evidence end
 local direct=self:Distance(a,b,width,height)
 local blocks=self.db and self.db.terrainBlocks and self.db.terrainBlocks[map]
 if not blocks or #blocks==0 or not self:TerrainIntersects(a,b,width,height,map) then return direct,{} end
 -- Visibility graph with eight safe clearance points around each marked obstacle.
 -- Bounded to 100 graph vertices to prevent excessive work inside the WoW frame.
 local vertices={{x=a.x,y=a.y},{x=b.x,y=b.y}}
 for _,o in ipairs(blocks) do
  if #vertices>=98 then break end
  local radius=(o.r+14)/math.cos(math.pi/8)+2
  for k=0,7 do
   local angle=k*math.pi/4
   local x=o.x+math.cos(angle)*radius/width
   local y=o.y+math.sin(angle)*radius/height
   if x>=0 and x<=1 and y>=0 and y<=1 then
    local safe=true
    for _,other in ipairs(blocks) do
     local dx,dy=(x-other.x)*width,(y-other.y)*height
     if dx*dx+dy*dy<(other.r+12)^2 then safe=false;break end
    end
    if safe then vertices[#vertices+1]={x=x,y=y} end
   end
  end
 end
 local cost={[1]=0}
 local previous,done={},{}
 for step=1,#vertices do
  self:PlannerCheckpoint()
  local chosen,best
  for k=1,#vertices do
   self:PlannerCheckpoint()
   if not done[k] and cost[k] and (not best or cost[k]<best) then chosen,best=k,cost[k] end
  end
  if not chosen or chosen==2 then break end
  done[chosen]=true
  for k=1,#vertices do
   if not done[k] and k~=chosen and not self:TerrainIntersects(vertices[chosen],vertices[k],width,height,map) then
    local newCost=best+self:Distance(vertices[chosen],vertices[k],width,height)
    if not cost[k] or newCost<cost[k] then cost[k]=newCost;previous[k]=chosen end
   end
  end
 end
 if not cost[2] then return math.huge,{}, {kind='unreachable'} end
 local reverse={}
 local i=previous[2]
 while i and i~=1 and #reverse<100 do
  reverse[#reverse+1]=vertices[i]
  i=previous[i]
 end
 local detours={}
 for j=#reverse,1,-1 do detours[#detours+1]=reverse[j] end
 return cost[2],detours
end
function N:TerrainSegmentDistance(a,b,width,height,map)
 -- Cheap direct-path check; avoid expensive graph searches during loop optimization.
 if not self:TerrainIntersects(a,b,width,height,map) then return self:Distance(a,b,width,height) end
 return self:Distance(a,b,width,height)+600
end
function N:BuildRoute(nodes,start,width,height,s)
 if not width or not height then return nil,'Client map dimensions unavailable; cannot calculate reliable distance.' end
 -- The imported spawn database can contain several records for one farming patch.
 -- Collapse near-identical/adjacent candidates before constructing navigation.
 local cache={}
 local function distance(a,b)
  local row=cache[a]
  if row and row[b] then return row[b] end
  self:PlannerCheckpoint()
  local d,_,info=self:TerrainLeg(a,b,width,height,start.map,s.speed)
  local value=info and info.seconds and info.seconds*s.speed or d
  -- Cache is local to this build: changes to speed, learned trails or obstacles
  -- cannot leak into subsequent calculations.
  row=row or {};cache[a]=row;row[b]=value;return value
 end
 local speed=math.max(1,s.speed)
 local stop=math.max(0,s.mountDelay)+math.max(0,s.gatherDelay)
 local spacing=math.max(40,math.min(85,speed*7)) -- 49 yards on foot, 78 on a 100% mount
 local candidates={}
 local ordered={}
 for _,node in ipairs(nodes) do
  self:PlannerCheckpoint()
  if type(node)=='table' and self:Finite(node.x,0,1) and self:Finite(node.y,0,1) then
  local blocked=false
  for _,o in ipairs((self.db.terrainBlocks or {})[start.map] or {}) do
   if ((node.x-o.x)*width)^2+((node.y-o.y)*height)^2 < o.r*o.r then blocked=true; break end
  end
  if not blocked then ordered[#ordered+1]=node end
  end
 end
 self:SetPlannerProgress("Selecting nearby gathering stops")
 local fromStart={}
 for _,p in ipairs(ordered) do fromStart[p]=distance(start,p) end
 table.sort(ordered,function(a,b)
  local da=fromStart[a]
  local db=fromStart[b]
  if da==db then return (a.object or 0)<(b.object or 0) end
  return da<db
 end)
 for _,n in ipairs(ordered) do
  self:PlannerCheckpoint()
  if #candidates>=250 then break end
  local nearby
  for _,c in ipairs(candidates) do
   if self:Distance(c,n,width,height)<spacing and not self:TerrainIntersects(c,n,width,height,start.map) then nearby=c; break end
  end
  if nearby then
   nearby.spawnCount=(nearby.spawnCount or 1)+1
   if nearby.source~='Observed' and n.source=='Observed' then
    nearby.x,nearby.y,nearby.name,nearby.object,nearby.source=n.x,n.y,n.name,n.object,n.source
   end
  else
   local copy=self:Copy(n)
   copy.spawnCount=1
   candidates[#candidates+1]=copy
  end
 end
 -- Try several constructive heuristics, then improve each closed circuit with 2-opt.
 -- All scoring uses Euclidean yard distances and real total loop duration.
 local limit=math.min(35,math.max(2,s.nodeLimit or 35))
 local budget=math.max(60,(s.routeMinutes or 15)*60)
 local function duration(path)
  local previous=start; local seconds=0
  for _,p in ipairs(path) do
   seconds=seconds+distance(previous,p,width,height)/speed+stop
   previous=p
  end
  return seconds+distance(previous,start,width,height)/speed
 end
 local function optimize(path)
  -- Directed 2-opt: include reversed internal edge costs, not just endpoints.
  -- Prefix sums make each candidate O(1); rebuild only after accepting a reversal.
  local forward,reverse,blocked
  local function prefixes()
   forward,reverse,blocked={[0]=0},{[0]=0},{[0]=0}
   for k=1,#path-1 do
    local f=distance(path[k],path[k+1])
    local r=distance(path[k+1],path[k])
    forward[k]=forward[k-1]+f
    reverse[k]=reverse[k-1]+(r<math.huge and r or 0)
    blocked[k]=blocked[k-1]+(r==math.huge and 1 or 0)
   end
  end
  prefixes()
  for pass=1,5 do
   local improved=false
   for i=1,#path-1 do
    for j=i+1,#path do
     self:PlannerCheckpoint()
     if blocked[j-1]==blocked[i-1] then
      local before=i==1 and start or path[i-1]
      local after=j==#path and start or path[j+1]
      local old=distance(before,path[i])+distance(path[j],after)+forward[j-1]-forward[i-1]
      local new=distance(before,path[j])+distance(path[i],after)+reverse[j-1]-reverse[i-1]
      if new+.01*speed<old then
       local l,r=i,j
       while l<r do path[l],path[r]=path[r],path[l];l=l+1;r=r-1 end
       improved=true;prefixes()
      end
     end
    end
   end
   if not improved then break end
  end
  return path
 end
 local useYield=#candidates>0
 for _,p in ipairs(candidates) do
  local e=self:GatherEvidence(start.map,p)
  if not e or e.checks<5 or e.harvests<3 then useYield=false;break end
 end
 local function value(path)
  local seconds=duration(path)
  if seconds>budget+.01 or #path==0 then return -1,seconds end
  local evidence={points=path,map=start.map,seconds=seconds}
  self:ScoreRouteEvidence(evidence)
  -- Penalize tiny repeat circuits; density is not treated as extra spawns.
  local coverage=math.min(1,#path/10)
  local score=(useYield and evidence.expectedResourcesPerHour and evidence.expectedResourcesPerHour/3600 or #path/math.max(600,seconds))*coverage
  return score,seconds
 end
 local best,bestScore,bestSeconds={},-1,0
 local strategies={{distance=1,returnWeight=.05},{distance=1,returnWeight=.35},
                   {distance=1,returnWeight=.75},{distance=1,returnWeight=.15,observed=12}}
 for modeIndex,mode in ipairs(strategies) do
  self:SetPlannerProgress("Improving circuit "..modeIndex.." / "..#strategies)
  local path,used,last,elapsed={},{},start,0
  while #path<limit do
   local choice,choiceScore,choiceDistance
   for i,p in ipairs(candidates) do
    if not used[i] then
     local d=distance(last,p,width,height)
     local home=distance(p,start,width,height)
     if elapsed+d/speed+stop+home/speed<=budget then
      local score=d/speed+mode.returnWeight*home/speed
      if p.source=='Observed' then score=score-(mode.observed or 6) end
      if not choiceScore or score<choiceScore then
       choice,choiceScore,choiceDistance=i,score,d
      end
     end
    end
   end
   if not choice then break end
   local p=candidates[choice]
   path[#path+1]=p;used[choice]=true
   elapsed=elapsed+choiceDistance/speed+stop;last=p
  end
  optimize(path)
  -- A shorter loop may be more productive than simply filling all 35 slots.
  local evaluations={#path,math.floor(#path*.75),math.floor(#path*.5)}
  for _,count in ipairs(evaluations) do
   if count>0 then
    local trial={}
    for i=1,count do trial[i]=path[i] end
    optimize(trial)
    local score,seconds=value(trial)
    if score>bestScore then best,bestScore,bestSeconds=trial,score,seconds end
   end
  end
 end
 local route={points=best,origin=self:Copy(start),seconds=bestSeconds,width=width,height=height,mode=s.travel,speed=s.speed,mountDelay=s.mountDelay,gatherDelay=s.gatherDelay,created=self:Now(),map=start.map,merged=true,optimizer='terrain-multi-seed-2opt-v5'}
 self:PrepareTerrainRoute(route)
 self:ScoreRouteEvidence(route)
 return route

end
-- Compare a small, geographically distributed set of candidate loop starts.
-- Scores are estimated stops/hour; imported points are potential, not live nodes.
function N:StartRouteAtNearest(route,here)
 if not route or (route.strategy~='nearest' and route.strategy~='optimal') or not here or here.map~=route.map or #route.points==0 then return route end
 local nearest,best=1,math.huge
 for i,p in ipairs(route.points) do
  self:PlannerCheckpoint()
  local distance,_,info=self:TerrainLeg(here,p,route.width,route.height,route.map,route.speed)
  local cost=info and info.seconds or distance/math.max(1,route.speed or self.db.settings.speed)
  if cost<best then nearest,best=i,cost end
 end
 if best==math.huge then return route end
 local points={}
 for offset=0,#route.points-1 do points[#points+1]=route.points[(nearest+offset-1)%#route.points+1] end
 route.points=points
 route.origin=self:Copy(points[1]);route.origin.map=route.map
 self:PrepareTerrainRoute(route);self:ScoreRouteEvidence(route)
 route.estimatedStopsPerHour=route.potentialStopsPerHour
 return route
end

function N:PlanRoute(strategy)
 local map,x,y=self:Position()
 if not map then return self:Print('Zone position unavailable.') end
 local nodes=self:ZoneNodes(map)
 if #nodes==0 then return self:Print('No matching gathering nodes in this zone.') end
 local w,h=self:MapSize(map)
 if not w then return self:Print('Map dimensions unavailable.') end
 local here={map=map,x=x,y=y}
 local settings=self:Copy(self.db.settings)
 strategy=strategy or settings.routeStrategy or 'optimal'
 local key=self:PlannerCacheKey({map=map,w=w,h=h,strategy=strategy,
  origin=strategy~='optimal' and here or nil,settings=settings,nodes=nodes,
  terrain=self:TerrainZone(map),blocks=(self.db.terrainBlocks or {})[map],
  evidence=(self.db.gatherEvidence or {})[map]})
 local cached=self:GetPlannerCache(key)
 if cached then self:SetPlannerProgress('Reusing recent route');return self:StartRouteAtNearest(cached,here) end
 local starts={here}
 if strategy~='here' then
  starts={}
  -- Spatial spread yields diverse candidate loops without testing all spawns.
  local cells,ordered={},{}
  for _,p in ipairs(nodes) do
   local key=math.floor(p.x*4)..':'..math.floor(p.y*4)
   local cell=cells[key]
   if not cell then cell={point=p,count=0}; cells[key]=cell end
   cell.count=cell.count+1
  end
  for _,c in pairs(cells) do ordered[#ordered+1]=c end
  table.sort(ordered,function(a,b)
   if a.count~=b.count then return a.count>b.count end
   return (a.point.x+a.point.y)<(b.point.x+b.point.y)
  end)
  for i=1,math.min(7,#ordered) do
   local seed=ordered[i].point
   starts[#starts+1]={map=map,x=seed.x,y=seed.y}
  end
  if strategy=='nearest' then starts[#starts+1]=here end
 end
 local best,bestScore
 for index,origin in ipairs(starts) do
  self:SetPlannerProgress("Comparing route starts",index-1,#starts)
  local route=self:BuildRoute(nodes,origin,w,h,settings)
  if route then
   route.strategy=strategy
   if strategy=='nearest' then self:StartRouteAtNearest(route,here) end
  end
  if route and not route.unreachable and #route.points>0 and route.seconds<=settings.routeMinutes*60+.01 then
   local seconds=math.max(1,route.seconds or settings.routeMinutes*60)
   local travel=self:Distance(here,route.origin,w,h)/math.max(1,settings.speed)
   -- For 'nearest', include getting to the circuit; for 'optimal', do not.
   local denominator=seconds+(strategy=='nearest' and travel or 0)
   local coverage=math.min(1,#route.points/12)
   local score=(#route.points*coverage)/math.max(600,denominator)
   if not bestScore or score>bestScore then
    best,bestScore=route,score
    best.strategy=strategy
    if self.planningJob then self.planningJob.best=self:Copy(best) end
   end
  end
 end
 if not best then return self:Print('No circuit fits your filters and time budget.') end
 best.strategy=strategy
 best.estimatedStopsPerHour=best.potentialStopsPerHour
 self:SetPlannerProgress("Route ready",#starts,#starts)
 self:PutPlannerCache(key,best)
 return self:StartRouteAtNearest(best,here)
end
-- Cross-zone comparisons are based on accessible imported coordinates, not active spawns.
function N:RankResourceZones(resource)
 if not resource or resource=='' then return {} end
 local settings=self:Copy(self.db.settings)
 local maps={}
 for object,kind in pairs(self.nodeTypes or {}) do
  if kind.name==resource then
   for map,points in pairs((self.spawns or {})[object] or {}) do
    if not self:IsGatheringCityMap(map) and type(points)=='table' then
     maps[map]=(maps[map] or 0)+math.floor(#points/2)
    end
   end
  end
 end
 local eligible={}
 for map in pairs(self.db.nodes or {}) do
  if not maps[map] and not self:IsGatheringCityMap(map) then
   local nodes=inputs.zones[map].nodes;if #nodes>0 then maps[map]=#nodes end
  end
 end
 for map,count in pairs(maps) do if count>=4 then eligible[#eligible+1]={map=map,count=count} end end
 table.sort(eligible,function(a,b) return a.count>b.count end)
 local inputs={resource=resource,settings=settings,zones={}}
 for _,entry in ipairs(eligible) do
  local map=entry.map
  inputs.zones[map]={nodes=self:ZoneNodes(map,'all',resource),terrain=self:TerrainZone(map),
   blocks=(self.db.terrainBlocks or {})[map],evidence=(self.db.gatherEvidence or {})[map]}
 end
 local key=self:PlannerCacheKey(inputs)
 local cached=self:GetPlannerCache(key)
 if cached then self:SetPlannerProgress('Reusing recent zone comparison');return cached end
 -- Every eligible zone is compared; the UI runs this through the incremental queue.
 local results={}
 for index=1,#eligible do
  self:SetPlannerProgress("Comparing zones",index-1,#eligible)
  local map=eligible[index].map
  local width,height=self:MapSize(map)
  if width and height then
   local nodes=inputs.zones[map].nodes
   local cells={}
   for _,node in ipairs(nodes) do
    local cell=math.floor(node.x*5)..':'..math.floor(node.y*5)
    local item=cells[cell]
    if not item then item={point=node,count=0};cells[cell]=item end
    item.count=item.count+1
   end
   local seeds={}
   for _,item in pairs(cells) do seeds[#seeds+1]=item end
   table.sort(seeds,function(a,b)
    if a.count~=b.count then return a.count>b.count end
    if a.point.x~=b.point.x then return a.point.x<b.point.x end
    return a.point.y<b.point.y
   end)
   local best,bestScore;local alternatives={}
   for j=1,math.min(5,#seeds) do
    local start=seeds[j].point
    local route=self:BuildRoute(nodes,{map=map,x=start.x,y=start.y},width,height,settings)
    if route and not route.unreachable and #route.points>=3 then
     local seconds=math.max(600,route.seconds)
     local coverage=math.min(1,#route.points/10)
     local score=#route.points*coverage/seconds
     alternatives[#alternatives+1]=route
     if not bestScore or score>bestScore then best,bestScore=route,score;best.strategy='optimal' end
    end
   end
   if best then
    local name='Zone '..map
    if C_Map and type(C_Map.GetMapInfo)=='function' then
     local info=self:Call(C_Map.GetMapInfo,map)
     if info and type(info.name)=='string' then name=info.name end
    end
    best.alternatives=nil
    results[#results+1]={map=map,name=name,route=best,score=bestScore*3600,rawCount=eligible[index].count,alternatives=alternatives}
   end
  end
 end
 local allObserved=#results>0
 for _,r in ipairs(results) do if not r.route.expectedResourcesPerHour then allObserved=false end end
 for _,r in ipairs(results) do
  r.metric=allObserved and 'resources' or 'potential stops'
  r.rankScore=allObserved and r.route.expectedResourcesPerHour or r.score
  r.score=allObserved and r.route.expectedResourcesPerHour or r.route.potentialStopsPerHour
 end
 table.sort(results,function(a,b)
  if a.rankScore==b.rankScore then return a.map<b.map end
  return a.rankScore>b.rankScore
 end)
 while #results>5 do table.remove(results) end
 self:PutPlannerCache(key,results)
 return results
end
function N:PrepareTerrainRoute(route)
 if not route or not route.points or not route.width or not route.height or not route.origin then return route end
 local points,indices={{x=route.origin.x,y=route.origin.y,map=route.map,transit=true,starting=true,name='Route start'}},{}
 local previous=route.origin
 local seconds,length,validated=0,0,0
 local speed=math.max(1,route.speed or self.db.settings.speed)
 route.unreachable=nil
 local function append(destination,closing)
  local distance,detour,info=self:TerrainLeg(previous,destination,route.width,route.height,route.map,speed)
  if distance==math.huge then route.unreachable=true;return false end
  for _,via in ipairs(detour) do
   if #points>=2048 then route.unreachable=true;return false end
   points[#points+1]={x=via.x,y=via.y,map=route.map,transit=true,closing=closing,name='Trail / detour',validated=via.validated==true}
  end
  local p=self:Copy(destination);p.validated=false
  if closing then p.transit=true;p.closing=true;p.name='Return to start' end
  points[#points+1]=p
  if not closing then indices[#indices+1]=#points end
  seconds=seconds+(info and info.seconds or distance/speed)
  if not closing then seconds=seconds+math.max(0,route.gatherDelay or self.db.settings.gatherDelay)+math.max(0,route.mountDelay or self.db.settings.mountDelay) end
  length=length+distance;validated=validated+(info and info.validatedDistance or 0)
  previous=destination;return true
 end
 for _,destination in ipairs(route.points) do if not append(destination,false) then break end end
 if not route.unreachable and #route.points>0 then append(route.origin,true) end
 route.travelPoints=route.unreachable and {} or points
 route.travelStopIndices=indices
 route.terrainSeconds=route.unreachable and math.huge or seconds
 route.seconds=route.terrainSeconds
 route.length=length
 route.traversalConfidence=length>0 and validated/length or 0
 route.terrainMode='learned-and-estimated'
 return route
end
function N:GenerateRoute()
 self:RunPlanner(function() return self:PlanRoute() end,function(best)
  if not best then return end
  local map,x,y=self:Position()
  if map and x and y then self:StartRouteAtNearest(best,{map=map,x=x,y=y}) end
  self.activeRoute=best; self.waypoint=1; self.terrainIndex=1;self.routePaused=false; self.dirty=true; self:ShowArrow()
  self:Print(string.format('%s: %d stops, %.1f minute loop; %.0f%% learned corridor distance. Unverified connectors remain estimates.',best.strategy,#best.points,(best.seconds or 0)/60,(best.traversalConfidence or 0)*100))
 end)
end
function N:SkipWaypoint()
 if not self.activeRoute then return end
 if self.activeRoute.travelStopIndices then
  local route=self.activeRoute
  if (self.waypoint or 1)>#route.points then self.activeRoute=nil;if self.arrow then self.arrow:Hide() end;self.dirty=true;return end
  self.terrainIndex=(route.travelStopIndices[self.waypoint or 1] or #(route.travelPoints or {}))+1
  self.waypoint=math.min(#route.points+1,(self.waypoint or 1)+1)
  self.dirty=true;return
 end
 self.waypoint=(self.waypoint or 1)+1
 local ids=self.activeRoute.travelStopIndices
 if ids then self.terrainIndex=((ids[self.waypoint-1] or 0)+1) end
 if self.waypoint>#self.activeRoute.points then self.activeRoute=nil; if self.arrow then self.arrow:Hide() end; self:Print('Route complete.') end
 self.dirty=true
end
function N:SaveRoute(name)
 if not self.activeRoute then return end
 name=tostring(name or 'Route'):sub(1,80); if name=='' then name='Route' end
 local count=0; for _ in pairs(self.db.routes) do count=count+1 end
 if count>=50 and not self.db.routes[name] then return self:Print('Saved route limit: 50.') end
 self.db.routes[name]=self:Copy(self.activeRoute); self.dirty=true
end
function N:AddWaypoint()
 local map,x,y=self:Position(); if not map then return end
 if not self.activeRoute or self.activeRoute.map~=map then
  local w,h=self:MapSize(map); if not w then return end
  self.activeRoute={map=map,points={},origin={x=x,y=y,map=map},width=w,height=h,mode='Custom',created=self:Now()}
 end
 if #self.activeRoute.points>=150 then return end
 table.insert(self.activeRoute.points,{x=x,y=y,map=map,name='Custom waypoint',source='Custom'})
 self.waypoint=self.waypoint or 1; self.dirty=true; self:ShowArrow()
end
local function nexusAngle(y,x)
 if math.atan2 then return math.atan2(y,x) end
 if x==0 then return y>=0 and math.pi/2 or -math.pi/2 end
 local n=math.atan(y/x)
 if x<0 then n=n+math.pi end
 return n
end
local function nexusDeltaAngle(a,b)
 return (b-a+math.pi)%(2*math.pi)-math.pi
end
local arrowAnchors={TOPLEFT=true,TOP=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,
 BOTTOMLEFT=true,BOTTOM=true,BOTTOMRIGHT=true}
function N:SaveArrowPosition()
 if not self.arrow then return end
 local point,relative,relativePoint,x,y=self.arrow:GetPoint(1)
 if (relative==UIParent or relative==nil) and arrowAnchors[point] and arrowAnchors[relativePoint]
  and self:Finite(x,-20000,20000) and self:Finite(y,-20000,20000) then
  self.db.settings.arrowPosition={point=point,relativePoint=relativePoint,x=x,y=y}
 end
end
function N:RestoreArrowPosition()
 if not self.arrow then return end
 local position=self.db.settings.arrowPosition
 self.arrow:ClearAllPoints()
 if type(position)=='table' and arrowAnchors[position.point] and arrowAnchors[position.relativePoint]
  and self:Finite(position.x,-20000,20000) and self:Finite(position.y,-20000,20000) then
  self.arrow:SetPoint(position.point,UIParent,position.relativePoint,position.x,position.y)
 else self.arrow:SetPoint('TOP',UIParent,'TOP',0,-135) end
end
function N:SetArrowScale(value)
 value=tonumber(value)
 if not self:Finite(value,.5,2) then self:Print('Navigation size must be 0.5 to 2.0.');return false end
 self.db.settings.arrowScale=value
 if self.arrow then self.arrow:SetScale(value) end
 return true
end
function N:ShowArrow()
 if not self.arrow then
  local f=CreateFrame('Frame','VoidMarkNexusArrow',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
  f:SetSize(320,262)
  f:SetFrameStrata('LOW')
  f:SetMovable(true); f:EnableMouse(true);f:SetClampedToScreen(true)
  f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function(w) w.dragging=true;w:StartMoving() end)
  f:SetScript('OnDragStop',function(w)
   w:StopMovingOrSizing();w.dragging=false;N:SaveArrowPosition()
  end)
  f:SetScript('OnHide',function(w)
   if w.dragging then w:StopMovingOrSizing();w.dragging=false;N:SaveArrowPosition() end
  end)
  if f.SetBackdrop then f:SetBackdrop(nil) end
  -- Arrow art points north; its compass pivot sits 60.6% down the texture.
  f.texture=f:CreateTexture(nil,'ARTWORK')
  f.texture:SetSize(104,104);f.texture:SetPoint('TOP',0,-35)
  f.texture:SetTexture('Interface\\AddOns\\VoidMarkNexus\\Media\\RouteCompass')
  f.rotationPivot=CreateVector2D and CreateVector2D(.5,.606) or nil
  local panel=f:CreateTexture(nil,'BACKGROUND')
  panel:SetTexture('Interface\\AddOns\\VoidMarkNexus\\Media\\RoutePanel')
  panel:SetSize(320,112);panel:SetPoint('TOP',0,-145)
  f.progress=CreateFrame('StatusBar',nil,f)
  f.progress:SetSize(136,9);f.progress:SetPoint('TOPLEFT',53,-181)
  f.progress:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
  f.progress:SetStatusBarColor(.72,.3,1,1);f.progress:SetMinMaxValues(0,1)
  local track=f.progress:CreateTexture(nil,'BACKGROUND');track:SetAllPoints(f.progress)
  track:SetColorTexture(.16,.12,.23,1)
  local function text(x,y,font)
   local label=f:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlight')
   label:SetPoint('TOP',f,'TOP',x,y);label:SetShadowColor(0,0,0,1);label:SetShadowOffset(1,-1)
   return label
  end
  f.count=text(84,-176,'GameFontHighlightLarge')
  f.label=text(-77,-211,'GameFontHighlightLarge')
  f.eta=text(53,-211,'GameFontHighlightLarge')
  f.status=text(0,-137,'GameFontHighlightSmall');f.status:SetTextColor(.82,.72,.92)
  f.status:SetWidth(280);f.status:SetWordWrap(false)
  local divider=f:CreateTexture(nil,'ARTWORK')
  divider:SetTexture('Interface\\Buttons\\WHITE8X8');divider:SetVertexColor(.7,.4,.9,.7)
  divider:SetSize(1,18);divider:SetPoint('TOP',-9,-210)
  f.skip=CreateFrame('Button',nil,f)
  f.skip:SetSize(28,28);f.skip:SetPoint('TOPRIGHT',-29,-202)
  f.skip:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
  local skipLabel=f.skip:CreateFontString(nil,'OVERLAY','GameFontHighlightLarge')
  skipLabel:SetPoint('CENTER');skipLabel:SetText('>');skipLabel:SetTextColor(.9,.7,1)
  f.skip:SetScript('OnClick',function() N:SkipWaypoint();f.refreshAt=0 end)
  f.skip:SetScript('OnEnter',function(self)
   GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Next gathering stop');GameTooltip:Show()
  end)
  f.skip:SetScript('OnLeave',function() GameTooltip:Hide() end)
  f.angle=nil
  local function menu()
   N:Choice(f,{
    {label='Skip waypoint',value='skip'},
    {label='Restart from waypoint 1',value='restart'},
    {label='Pause / resume',value='pause'},
    {label='Display',
     decrease=function() N:SetArrowScale(math.max(.5,(N.db.settings.arrowScale or 1)-.1)) end,
     increase=function() N:SetArrowScale(math.min(2,(N.db.settings.arrowScale or 1)+.1)) end},
    {label='Cancel route',value='cancel'}
   },function(action)
    if action=='skip' then N:SkipWaypoint()
    elseif action=='restart' and N.activeRoute then N.waypoint=1;N.terrainIndex=1;N.routePaused=false; N.dirty=true
    elseif action=='pause' then N.routePaused=not N.routePaused
    elseif action=='cancel' then N.activeRoute=nil; N.waypoint=nil; f:Hide(); N.dirty=true end
    f.refreshAt=0
    if WorldMapFrame and WorldMapFrame:IsShown() then N:RefreshMap() end
   end)
   -- Close the menu without affecting the active navigation.
   if N.menu then
    local close=CreateFrame('Button',nil,N.menu,'UIPanelCloseButton')
    close:SetSize(24,24)
    close:SetPoint('TOPRIGHT',N.menu,'TOPRIGHT',2,2)
    close:SetFrameLevel(N.menu:GetFrameLevel()+5)
    close:SetScript('OnClick',function() N.menu:Hide() end)
   end
  end
  f:SetScript('OnMouseUp',function(_,button) if button=='RightButton' then menu() end end)
  -- Smooth facing updates every frame; update expensive map coordinates 10x/sec.
  f.refreshAt=0
  f:SetScript('OnUpdate',function(w,dt)
   w.refreshAt=w.refreshAt-dt
   if w.refreshAt<=0 then
    w.refreshAt=.10
    N:Guard('navigation',function() N:UpdateArrow() end)
   end
   local facing=N:Call(GetPlayerFacing)
   if w.bearing and N:Finite(facing,-10,10) then
    local goal=w.bearing-facing
    if not w.angle then w.angle=goal end
    local fraction=math.min(1,dt*13)
    w.angle=w.angle+nexusDeltaAngle(w.angle,goal)*fraction
    if type(w.texture.SetRotation)=='function' then
     if w.rotationPivot then w.texture:SetRotation(w.angle,w.rotationPivot) else w.texture:SetRotation(w.angle) end
    end
   end
  end)
  self.arrow=f
 end
 self.arrow:SetFrameStrata('LOW')
 self.arrow:SetScale(self.db.settings.arrowScale or 1)
 if not self.arrow.positionRestored then self:RestoreArrowPosition();self.arrow.positionRestored=true end
 self.arrow.refreshAt=0
 self.arrow:Show()
end
function N:UpdateArrow()
 local arrow=self.arrow
 if not arrow then return end
 local route=self.activeRoute
 if route then
  local count=#route.points
  local current=math.min(self.waypoint or 1,count)
  arrow.count:SetText(current..' / '..count)
  arrow.progress:SetValue(count>0 and math.min(count,math.max(0,(self.waypoint or 1)-1))/count or 0)
 end
 if self.routePaused and route then
  arrow.status:SetText('Route paused');arrow.label:SetText('-- yd');arrow.eta:SetText('-- sec')
  arrow.texture:SetAlpha(.35);arrow.bearing=nil;return
 end
 local node=route and route.points[self.waypoint or 1]
 local transit=route and route.travelPoints and route.travelPoints[self.terrainIndex or 1]
 local point=transit or node
 if not point or not self.db.settings.routeVisible then arrow:Hide(); return end
 local map,x,y=self:Position()
 if map~=route.map or not x or not y then
  arrow.status:SetText('Return to route zone');arrow.label:SetText('-- yd');arrow.eta:SetText('-- sec')
  arrow.texture:Hide()
  arrow.bearing=nil
  return
 end
 local dx=(point.x-x)*route.width
 local dy=(point.y-y)*route.height
 local distance=math.sqrt(dx*dx+dy*dy)
 arrow.bearing=nexusAngle(-dx,-dy)
 arrow.texture:Show()
 arrow.texture:SetAlpha(1)
 arrow.status:SetText(point.transit and (point.closing and 'Return to start' or 'Following route') or (point.name or 'Gathering stop'))
 arrow.label:SetText(string.format('%.0f yd',distance))
 arrow.eta:SetText(string.format('~%.0f sec',distance/math.max(1,route.speed or self.db.settings.speed)))
 if distance<8 then
  if point.transit then
   self.terrainIndex=(self.terrainIndex or 1)+1
   if self.terrainIndex>#route.travelPoints then self.activeRoute=nil;arrow:Hide();self:Print('Route loop complete.') end
  elseif not self.db.settings.manualStops then self:SkipWaypoint() end
  self.dirty=true
  arrow.refreshAt=0
 end
end
-- Item IDs are the gathered resources, not world object/spawn IDs.
-- Prefer item icons from the client and use distinct inventory textures when uncached.
local nexusNodeIcons = {
 ["Peacebloom"]=2447, ["Silverleaf"]=765, ["Earthroot"]=2449,
 ["Mageroyal"]=785, ["Briarthorn"]=2450, ["Stranglekelp"]=3820,
 ["Bruiseweed"]=2453, ["Wild Steelbloom"]=3355, ["Grave Moss"]=3369,
 ["Kingsblood"]=3356, ["Liferoot"]=3357, ["Fadeleaf"]=3818,
 ["Goldthorn"]=3821, ["Khadgar's Whisker"]=3358, ["Wintersbite"]=3819,
 ["Firebloom"]=4625, ["Purple Lotus"]=8831, ["Arthas' Tears"]=8836,
 ["Sungrass"]=8838, ["Blindweed"]=8839, ["Ghost Mushroom"]=8845,
 ["Gromsblood"]=8846, ["Golden Sansam"]=13464, ["Dreamfoil"]=13463,
 ["Mountain Silversage"]=13465, ["Plaguebloom"]=13466, ["Icecap"]=13467,
 ["Black Lotus"]=13468,
 ["Copper Vein"]=2770, ["Tin Vein"]=2771, ["Silver Vein"]=2775,
 ["Iron Deposit"]=2772, ["Gold Vein"]=2776, ["Mithril Deposit"]=3858,
 ["Truesilver Deposit"]=7911, ["Dark Iron Deposit"]=11370,
 ["Small Thorium Vein"]=10620, ["Rich Thorium Vein"]=10620,
 ["Incendicite Mineral Vein"]=3340, ["Lesser Bloodstone Deposit"]=4278,
 ["Indurium Mineral Vein"]=5833, ["Hakkari Thorium Vein"]=10620,
 ["Small Obsidian Chunk"]=22202, ["Large Obsidian Chunk"]=22203
}
local nexusNodeFallback = {
 ["Peacebloom"]='Interface\\Icons\\INV_Misc_Flower_02',
 ["Silverleaf"]='Interface\\Icons\\INV_Misc_Herb_10',
 ["Earthroot"]='Interface\\Icons\\INV_Misc_Herb_07',
 ["Mageroyal"]='Interface\\Icons\\INV_Jewelry_Talisman_03',
 ["Briarthorn"]='Interface\\Icons\\INV_Misc_Root_01',
 ["Copper Vein"]='Interface\\Icons\\INV_Ore_Copper_01',
 ["Tin Vein"]='Interface\\Icons\\INV_Ore_Tin_01',
 ["Silver Vein"]='Interface\\Icons\\INV_Ore_Silver_01',
 ["Iron Deposit"]='Interface\\Icons\\INV_Ore_Iron_01',
 ["Gold Vein"]='Interface\\Icons\\INV_Ore_Gold_01',
 ["Mithril Deposit"]='Interface\\Icons\\INV_Ore_Mithril_01',
 ["Truesilver Deposit"]='Interface\\Icons\\INV_Ore_TrueSilver_01'
}
local nexusGenericHerb='Interface\\Icons\\INV_Misc_Herb_01'
local nexusGenericOre='Interface\\Icons\\INV_Ore_Copper_01'
local function nexusResourceIcon(node)
 local name=node.name or ''
 local id=nexusNodeIcons[name]
 local texture
 if id then
  if C_Item and type(C_Item.GetItemIconByID)=='function' then
   local ok,result=pcall(C_Item.GetItemIconByID,id)
   if ok then texture=result end
  end
  if not texture and type(GetItemIcon)=='function' then
   local ok,result=pcall(GetItemIcon,id)
   if ok then texture=result end
  end
  if not texture and type(GetItemInfoInstant)=='function' then
   local ok,_,_,_,_,icon=pcall(GetItemInfoInstant,id)
   if ok then texture=icon end
  end
 end
 return texture or nexusNodeFallback[name] or (node.kind=='ore' and nexusGenericOre or nexusGenericHerb)
end
-- Shared with the Routes tab, so list rows use the same resource artwork as map pins.
function N:ResourceNodeIcon(node)
 if type(node)~='table' then return 'Interface\\Icons\\INV_Misc_Map_01' end
 return nexusResourceIcon(node)
end
function N:RefreshMap()
 local world=WorldMapFrame
 local canvas=world and world.GetCanvas and world:GetCanvas()
 if not canvas or not world:IsShown() then return end
 local map=world:GetMapID()
 if not map then return end
 local s=self.db.settings
 local filter=s.mapNodeFilter or 'all'
 -- A standalone world-map control, independent of whether the Nexus main window is open.
 if not self.mapNodeFilterButton then
  local b=CreateFrame('Button',nil,canvas,'UIPanelButtonTemplate')
  b:SetSize(140,23)
  b:SetPoint('TOPLEFT',canvas,'TOPLEFT',12,-12)
  b:SetFrameStrata('HIGH')
  b:SetScript('OnClick',function()
   N:Choice(b,{
    {label='Both: Herbs and Mining',value='all'},
    {label='Herbs only',value='herb'},
    {label='Mining only',value='ore'},
    {label='No gathering nodes',value='none'}
   },function(value)
    N.db.settings.mapNodeFilter=value
    N:RefreshMap()
   end)
  end)
  self.mapNodeFilterButton=b
 end
 local names={all='Herbs + Ore',herb='Herbs',ore='Mining',none='Hidden'}
 -- Compact map-size slider, stored in account settings.
 if not self.mapIconSizeSlider then
  local slider=CreateFrame('Slider',nil,canvas,'OptionsSliderTemplate')
  slider:SetSize(120,16)
  slider:SetPoint('TOPLEFT',canvas,'TOPLEFT',18,-49)
  slider:SetMinMaxValues(5,16); slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetScript('OnValueChanged',function(_,value)
   local n=math.floor(value+0.5)
   if N.db.settings.mapIconSize~=n then
    N.db.settings.mapIconSize=n
    N:RefreshMap()
   end
  end)
  local caption=canvas:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
  caption:SetPoint('BOTTOM',slider,'TOP',0,3)
  slider.caption=caption
  self.mapIconSizeSlider=slider
 end
 local selectedSize=math.max(5,math.min(16,tonumber(s.mapIconSize) or 7))
 self.mapIconSizeSlider.caption:SetText('Icon size: '..selectedSize)
 self.mapIconSizeSlider:SetValue(selectedSize)
 self.mapIconSizeSlider:SetShown(filter~='none' and s.nodesVisible)
 self.mapNodeFilterButton:SetText('Nexus: '..(names[filter] or names.all)..'  v')
 self.mapNodeFilterButton:Show()
 -- Make active-route map selection explicit instead of silently hiding it.
 if not self.mapActiveRouteButton then
  local b=CreateFrame('Button',nil,canvas,'UIPanelButtonTemplate')
  b:SetSize(165,23)
  b:SetPoint('TOPLEFT',canvas,'TOPLEFT',162,-12)
  b:SetFrameStrata('HIGH')
  b:SetScript('OnClick',function()
   local route=N.activeRoute
   if route and WorldMapFrame and WorldMapFrame.SetMapID then
    WorldMapFrame:SetMapID(route.map)
    N:RefreshMap()
   end
  end)
  self.mapActiveRouteButton=b
 end
 local active=self.activeRoute
 if active and active.map then
  local info=C_Map and C_Map.GetMapInfo and self:Call(C_Map.GetMapInfo,active.map)
  local name=info and info.name or ('Zone '..tostring(active.map))
  self.mapActiveRouteButton:SetText(active.map==map and ('Route: '..name..' ('..tostring(#(active.points or {}))..' stops)') or ('View route: '..name))
  self.mapActiveRouteButton:Show()
 else
  self.mapActiveRouteButton:Hide()
 end
 local nodes={}
 if s.nodesVisible and filter~='none' then
  -- Map display filters must NOT change the independent route-planning filter.
  for _,node in ipairs(self:ZoneNodes(map,'all','')) do
   if filter=='all' or node.kind==filter then nodes[#nodes+1]=node end
  end
 end
 self.mapPins=self.mapPins or {}
 -- Exploration detail textures can be added above ordinary canvas children.
 -- A full-screen high-strata overlay keeps Nexus markers visible on revealed terrain.
 if not self.mapPinOverlay or self.mapPinOverlay:GetParent()~=canvas then
  local overlay=CreateFrame('Frame',nil,canvas)
  overlay:SetAllPoints(canvas)
  overlay:SetFrameStrata('HIGH')
  overlay:SetFrameLevel(math.max(canvas:GetFrameLevel()+120,world:GetFrameLevel()+120))
  overlay:EnableMouse(false)
  self.mapPinOverlay=overlay
  for _,pin in ipairs(self.mapPins or {}) do pin:SetParent(overlay) end
 end
 local width,height=canvas:GetWidth(),canvas:GetHeight()
 if width<=0 or height<=0 then return end
 -- Only the next five waypoints and connecting legs appear on the world map.
 -- Navigation retains every waypoint in the underlying route.
 self.mapRouteLines=self.mapRouteLines or {}
 local route=self.activeRoute
 local points={}
 local segments={}
 if s.routeVisible and route and route.map==map then
  local geometry=route.travelPoints or route.points
  local current=route.travelPoints and (self.terrainIndex or 1) or math.max(1,self.waypoint or 1)
  local last=math.min(#geometry,current+100)
  local prev=geometry[current-1] or route.origin
  local stop=self.waypoint or 1
  for i=current,last do
   local node=geometry[i]
   if node then
    points[#points+1]={n=node,label=node.transit and ((node.closing or node.starting) and 'S' or '�') or tostring(stop),route=true}
    if prev then segments[#segments+1]={a=prev,b=node,validated=node.validated==true} end
    prev=node
    if not node.transit then stop=stop+1 end
    if stop>(self.waypoint or 1)+4 then break end
   end
  end
 end
 -- Some Forever builds expose Line regions but reject one of their methods.
 -- Never let decorative route strokes stop waypoint pins from rendering.
 for i=1,math.max(#segments,#self.mapRouteLines) do
  local line=self.mapRouteLines[i]
  if not line and segments[i] and type(canvas.CreateLine)=='function' then
   local ok,created=pcall(canvas.CreateLine,self.mapPinOverlay,nil,'ARTWORK')
   if ok and created then line=created; self.mapRouteLines[i]=line end
  end
  if line then
   local leg=segments[i]
   if leg then
    local ok=pcall(function()
     line:SetStartPoint('TOPLEFT',canvas,'TOPLEFT',leg.a.x*width,-leg.a.y*height)
     line:SetEndPoint('TOPLEFT',canvas,'TOPLEFT',leg.b.x*width,-leg.b.y*height)
     line:SetThickness(i==1 and 3 or 2)
     if line.SetTexture then line:SetTexture('Interface\\Buttons\\WHITE8X8') end
     line:SetVertexColor(leg.validated and .4 or .73,leg.validated and .9 or .37,1,.92)
     line:Show()
    end)
    if not ok then line:Hide() end
   else line:Hide() end
  end
 end
 -- Dot texture fallback: several Forever builds expose CreateLine but cannot draw
 -- correctly on the world-map canvas. Keep at most four short, clipped segments.
 self.mapRouteDots=self.mapRouteDots or {}
 local usedDots=0
 for _,leg in ipairs(segments) do
  local ax,ay=leg.a.x*width,leg.a.y*height
  local bx,by=leg.b.x*width,leg.b.y*height
  local dx,dy=bx-ax,by-ay
  local distance=math.sqrt(dx*dx+dy*dy)
  local count=math.min(70,math.floor(distance/6))
  for j=0,count do
   if usedDots>=350 then break end
   local t=j/math.max(1,count)
   local x,y=ax+dx*t,ay+dy*t
   if x>=0 and y>=0 and x<=width and y<=height then
    usedDots=usedDots+1
    local dot=self.mapRouteDots[usedDots]
    if not dot then
     dot=self.mapPinOverlay:CreateTexture(nil,'OVERLAY')
     dot:SetTexture('Interface\\Buttons\\WHITE8X8')
     dot:SetSize(3,3)
     self.mapRouteDots[usedDots]=dot
    end
    dot:ClearAllPoints()
    dot:SetPoint('CENTER',canvas,'TOPLEFT',x,-y)
    dot:SetVertexColor(leg.validated and .4 or .73,leg.validated and .9 or .37,1,.96)
    dot:Show()
   end
  end
 end
 for i=usedDots+1,#self.mapRouteDots do self.mapRouteDots[i]:Hide() end
 -- Merge nearby display-only markers; keep full node records for farming calculations.
 local clusters={}
 for _,node in ipairs(nodes) do
  local match
  for _,c in ipairs(clusters) do
   local dx=(node.x-c.n.x)*width
   local dy=(node.y-c.n.y)*height
   if dx*dx+dy*dy<64 then match=c; break end
  end
  if match then
   match.count=match.count+1
   match.names[node.name or 'Unknown']=true
   -- Prefer observed node information over imported potential spawns.
   if node.source=='Observed' and match.n.source~='Observed' then match.n=node end
  else
   clusters[#clusters+1]={n=node,label='',count=1,names={[node.name or 'Unknown']=true}}
  end
 end
 -- Keep the map-wide distribution instead of only taking the first 250
 -- database records (which are grouped by object ID/region). Pick one from
 -- each spatial bucket per pass so distant areas stay represented.
 local buckets,order={},{}
 for _,c in ipairs(clusters) do
  local key=math.floor(c.n.x*12)..':'..math.floor(c.n.y*12)
  if not buckets[key] then buckets[key]={};order[#order+1]=key end
  buckets[key][#buckets[key]+1]=c
 end
 table.sort(order)
 for _,key in ipairs(order) do
  table.sort(buckets[key],function(a,b)
   if (a.n.source=='Observed')~=(b.n.source=='Observed') then return a.n.source=='Observed' end
   return a.count>b.count
  end)
 end
 local pass=1
 while #points<250 do
  local added=false
  for _,key in ipairs(order) do
   local c=buckets[key][pass]
   if c and #points<250 then points[#points+1]=c;added=true end
  end
  if not added then break end
  pass=pass+1
 end
 for i=1,math.max(#points,#self.mapPins) do
  local pin=self.mapPins[i]
  if not pin then
   pin=CreateFrame('Button',nil,self.mapPinOverlay)
   pin:SetSize(7,7)
   pin.tex=pin:CreateTexture(nil,'OVERLAY',nil,5)
   pin.tex:SetAllPoints()
   pin.label=pin:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
   pin.label:SetPoint('CENTER')
   pin.label:SetDrawLayer('OVERLAY',7)
   pin:SetScript('OnEnter',function(p)
    p:SetSize(16,16)
    p.tex:SetAlpha(1)
    GameTooltip:SetOwner(p,'ANCHOR_RIGHT')
    GameTooltip:SetText(p.node.name or 'Waypoint')
    GameTooltip:AddLine(p.node.source or 'Route')
    if p.clusterCount and p.clusterCount>1 then
     GameTooltip:AddLine(tostring(p.clusterCount)..' nearby spawn records')
     if p.clusterNames then for name in pairs(p.clusterNames) do GameTooltip:AddLine(name,1,0.85,0.45) end end
    end
    GameTooltip:Show()
   end)
   pin:SetScript('OnLeave',function(p) p:SetSize(p.normalSize or 7,p.normalSize or 7); p.tex:SetAlpha(1); GameTooltip:Hide() end)
   self.mapPins[i]=pin
  end
  local p=points[i]
  if p then
   pin.node=p.n
   pin.isRoute=p.route or false
   pin:SetFrameLevel(self.mapPinOverlay:GetFrameLevel()+(p.route and 3 or 2))
   pin.normalSize=p.route and (p.n.transit and 9 or 24) or math.max(5,math.min(16,tonumber(s.mapIconSize) or 7))
   pin:SetSize(pin.normalSize,pin.normalSize)
   pin.tex:SetAlpha(1)
   if p.route then pin.label:SetTextColor(1,.95,.1,1) end
   pin.clusterCount=p.count
   pin.clusterNames=p.names
   pin:ClearAllPoints()
   pin:SetPoint('CENTER',canvas,'TOPLEFT',p.n.x*width,-p.n.y*height)
   local texture
   if p.route then texture='Interface\\Icons\\INV_Misc_Map_01'
   else
    texture=nexusResourceIcon(p.n)
   end
   pin.tex:SetTexture(texture)
   pin.label:SetText(p.label)
   if p.route then pin.label:SetFontObject('GameFontNormalLarge') else pin.label:SetFontObject('GameFontNormalSmall') end
   pin:Show()
  else pin:Hide() end
 end
end


-- SavedVariables are written after PLAYER_LOGOUT, including /reload.
-- Store navigation per character, separately from the account's named routes.
local function navigationRoute(self,source)
 if type(source)~='table' or not self:Finite(source.map,1,100000)
  or not self:Finite(source.width,1,100000) or not self:Finite(source.height,1,100000)
  or type(source.points)~='table' or #source.points<1 or #source.points>150 then return end
 local route={}
 for k,v in pairs(source) do
  if type(k)=='string' and (type(v)=='boolean' or type(v)=='string' and #v<=512
   or type(v)=='number' and self:Finite(v,-1e15,1e15)) then route[k]=v end
 end
 local function point(p)
  if type(p)~='table' or not self:Finite(p.x,0,1) or not self:Finite(p.y,0,1) then return end
  local copy={x=p.x,y=p.y,map=source.map}
  for _,k in ipairs({'name','source','object','transit','validated','closing','starting'}) do
   local v=p[k]
   if type(v)=='boolean' or type(v)=='string' and #v<=160 or type(v)=='number' and self:Finite(v,0,1e12) then copy[k]=v end
  end
  return copy
 end
 route.points={}
 for i,p in ipairs(source.points) do route.points[i]=point(p);if not route.points[i] then return end end
 route.origin=point(source.origin) or self:Copy(route.points[1])
 if source.travelPoints~=nil then
  if type(source.travelPoints)~='table' or #source.travelPoints<1 or #source.travelPoints>2048 then return end
  route.travelPoints={}
  for i,p in ipairs(source.travelPoints) do route.travelPoints[i]=point(p);if not route.travelPoints[i] then return end end
  if type(source.travelStopIndices)~='table' then return end
  route.travelStopIndices={}
  for i=1,#route.points do
   local value=source.travelStopIndices[i]
   if not self:Finite(value,1,#route.travelPoints) or value~=math.floor(value) then return end
   route.travelStopIndices[i]=value
  end
 end
 return route
end
function N:SaveNavigation()
 if not self.db or not self.characterID then return end
 self.db.navigation=type(self.db.navigation)=='table' and self.db.navigation or {}
 local route=navigationRoute(self,self.activeRoute)
 self.db.navigation[self.characterID]=route and {version=1,route=route,
  waypoint=self.waypoint or 1,terrainIndex=self.terrainIndex or 1,paused=self.routePaused==true} or nil
end
function N:RestoreNavigation()
 local saved=type(self.db.navigation)=='table' and self.db.navigation[self.characterID]
 if type(saved)~='table' or saved.version~=1 then return end
 local route=navigationRoute(self,saved.route)
 if not route then return end
 local function index(value,maximum)
  if not self:Finite(value,1,maximum) or value~=math.floor(value) then return 1 end
  return value
 end
 self.activeRoute=route
 self.waypoint=index(saved.waypoint,#route.points+(route.travelPoints and 1 or 0))
 self.terrainIndex=index(saved.terrainIndex,route.travelPoints and #route.travelPoints or 1)
 self.routePaused=saved.paused==true;self.dirty=true
 self:ShowArrow()
 self:Print('Restored active route and waypoint'..(self.routePaused and ' (paused).' or '.'))
end
N:On('PLAYER_LOGOUT',function() N:SaveNavigation() end)
