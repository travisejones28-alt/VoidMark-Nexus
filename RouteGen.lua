local _, N = ...
-- Zone loop generator (0.5): one smooth loop through the zone's spawn points.
--  1. Spawns within STOP_RADIUS yards become one stop (you will see the node).
--  2. Lonely outlier stops far from everything else are dropped.
--  3. All stops are ordered: nearest-neighbour start, then 2-opt and or-opt.
--  4. If the loop is longer than the stop/time limit, the best stretch of the
--     loop (most spawns per yard) is kept and closed into a smaller loop.
-- Runs synchronously in well under a second; no planning window, no cache.
local STOP_RADIUS=35
local ARRIVE_RADIUS=25
N.loopArriveRadius=ARRIVE_RADIUS

local function dist(a,b) local dx,dy=a.x-b.x,a.y-b.y; return math.sqrt(dx*dx+dy*dy) end

-- Groups spawn points (map coords 0-1) into stops in yard space.
function N:ClusterStops(nodes,w,h,radius)
 radius=radius or STOP_RADIUS
 local r2=radius*radius
 local grid,stops={},{}
 for _,n in ipairs(nodes) do
  if self:Finite(n.x,0,1) and self:Finite(n.y,0,1) then
   local x,y=n.x*w,n.y*h
   local gx,gy=math.floor(x/radius),math.floor(y/radius)
   local best,bestD
   for dx=-1,1 do for dy=-1,1 do
    local list=grid[(gx+dx)..':'..(gy+dy)]
    if list then for _,s in ipairs(list) do
     local d=(s.ax-x)^2+(s.ay-y)^2
     if d<=r2 and (not bestD or d<bestD) then best,bestD=s,d end
    end end
   end end
   local weight=n.skillPriority or 1
   if best then
    best.count=best.count+1; best.weight=best.weight+weight
    best.sx=best.sx+x; best.sy=best.sy+y
    best.names[n.name or '?']=(best.names[n.name or '?'] or 0)+1
    if n.source=='Observed' then best.observed=true end
    if (n.skillPriority or 0)>(best.skillPriority or 0) then best.skillPriority,best.skillColor=n.skillPriority,n.skillColor end
   else
    local s={ax=x,ay=y,sx=x,sy=y,count=1,weight=weight,names={[n.name or '?']=1},kind=n.kind,object=n.object,
     observed=n.source=='Observed',skillPriority=n.skillPriority,skillColor=n.skillColor}
    local key=gx..':'..gy; grid[key]=grid[key] or {}; table.insert(grid[key],s)
    stops[#stops+1]=s
   end
  end
 end
 for _,s in ipairs(stops) do
  s.x,s.y=s.sx/s.count,s.sy/s.count
  local top,topN,kinds=nil,0,0
  for name,c in pairs(s.names) do kinds=kinds+1; if c>topN or (c==topN and name<top) then top,topN=name,c end end
  s.name=kinds>1 and (top..' +'..(kinds-1)) or top
  s.ax,s.ay,s.sx,s.sy=nil,nil,nil,nil
 end
 return stops
end

-- Drop stops whose nearest neighbour is far away compared with the zone norm.
function N:DropOutliers(stops)
 if #stops<6 then return stops end
 local nn={}
 for i,a in ipairs(stops) do
  local best=math.huge
  for j,b in ipairs(stops) do if i~=j then local d=dist(a,b); if d<best then best=d end end end
  nn[i]=best
 end
 local sorted={}; for i=1,#nn do sorted[i]=nn[i] end; table.sort(sorted)
 local median=sorted[math.floor((#sorted+1)/2)]
 local limit=math.max(200,median*3)
 local out={}
 for i,s in ipairs(stops) do if nn[i]<=limit then out[#out+1]=s end end
 return #out>=3 and out or stops
end

local function tourLength(t)
 local total=0; for i=1,#t do total=total+dist(t[i],t[i%#t+1]) end; return total
end
N.LoopLength=tourLength

local function nearestTour(stops,start)
 local left={}; for i,s in ipairs(stops) do left[i]=s end
 local tour={}; local cur=start
 while #left>0 do
  local bi,bd=1,math.huge
  for i,s in ipairs(left) do local d=dist(cur,s); if d<bd then bi,bd=i,d end end
  cur=table.remove(left,bi); tour[#tour+1]=cur
 end
 return tour
end

local function twoOpt(t,maxPasses)
 local n=#t; if n<4 then return end
 for _=1,maxPasses or 30 do
  local improved=false
  for i=1,n-2 do
   for j=i+2,n do
    if not (i==1 and j==n) then
     local a,b,c,d=t[i],t[i+1],t[j],t[j%n+1]
     if dist(a,c)+dist(b,d)<dist(a,b)+dist(c,d)-.01 then
      local l,r=i+1,j
      while l<r do t[l],t[r]=t[r],t[l]; l=l+1; r=r-1 end
      improved=true
     end
    end
   end
  end
  if not improved then return end
 end
end

-- Move short runs of 1-3 stops to a better place in the loop.
local function orOpt(t,maxPasses)
 for _=1,maxPasses or 10 do
  local n=#t; if n<5 then return end
  local moved=false
  for len=1,3 do
   local i=1
   while i<=n-len+1 do
    local prev,first,last,nextS=t[i==1 and n or i-1],t[i],t[i+len-1],t[(i+len-1)%n+1]
    local gain=dist(prev,first)+dist(last,nextS)-dist(prev,nextS)
    local bestK,bestCost,bestRev
    for k=1,n do
     -- Skip edges that touch the run itself (including the wrap edge).
     if not (k>=i-1 and k<=i+len-1) and not (i==1 and k==n) then
      local a,b=t[k],t[k%n+1]
      local fwd=dist(a,first)+dist(last,b)-dist(a,b)
      local rev=dist(a,last)+dist(first,b)-dist(a,b)
      local cost=math.min(fwd,rev)
      if cost<gain-.01 and (not bestCost or cost<bestCost) then bestK,bestCost,bestRev=k,cost,rev<fwd end
     end
    end
    if bestK then
     local seg={}; for x=i,i+len-1 do seg[#seg+1]=t[x] end
     local anchor=t[bestK]
     for _=1,len do table.remove(t,i) end
     local at; for x=1,#t do if t[x]==anchor then at=x; break end end
     if bestRev then local r={}; for x=#seg,1,-1 do r[#r+1]=seg[x] end; seg=r end
     for x=#seg,1,-1 do table.insert(t,at+1,seg[x]) end
     moved=true
    else i=i+1 end
   end
  end
  if not moved then return end
 end
end
N.LoopTwoOpt,N.LoopOrOpt=twoOpt,orOpt

-- Keep the best consecutive stretch of the loop that fits the limits.
local function bestWindow(t,maxStops,maxYards)
 local n=#t
 if n<=maxStops and tourLength(t)<=maxYards then return t end
 local best,bestScore
 for i=1,n do
  local w,path,weight={},0,0
  for k=0,math.min(maxStops,n)-1 do
   local s=t[(i+k-1)%n+1]
   if #w>0 then path=path+dist(w[#w],s) end
   if path+dist(s,t[i])>maxYards and #w>=3 then break end
   w[#w+1]=s; weight=weight+s.weight
  end
  local loop=path+dist(w[#w],w[1])
  local score=weight/math.max(100,loop)*math.min(1,#w/12)
  if #w>=3 and (not bestScore or score>bestScore) then best,bestScore={},score; for x,s in ipairs(w) do best[x]=s end end
 end
 return best or t
end

-- Builds a loop for the given nodes. here={x,y} in map coords (optional).
function N:BuildZoneLoop(map,nodes,here,settings)
 settings=settings or self.db.settings
 local w,h=self:MapSize(map)
 if not w then return nil,'Map size unavailable here.' end
 local stops=self:DropOutliers(self:ClusterStops(nodes,w,h))
 if #stops==0 then return nil,'No spawn points match in this zone.' end
 -- What you have found at each spot: favour picked spots, drop ones always empty.
 if self.SpotFactor and settings.learnSpots~=false and type(self.db.spots)=='table' and type(self.db.spots[map])=='table' then
  local kept,dropped={},0
  for _,s in ipairs(stops) do
   local e=self:SpotEvidence(map,s.x/w,s.y/h); local f=self:SpotFactor(e)
   if f>0 then s.weight=s.weight*f;s.picked=e and e.picked;s.empty=e and e.empty;kept[#kept+1]=s else dropped=dropped+1 end
  end
  if #kept>=3 then stops=kept;self.lastDroppedSpots=dropped else self.lastDroppedSpots=0 end
 end
 local start=here and {x=here.x*w,y=here.y*h} or stops[1]
 local speed=self.TravelSpeed and self:TravelSpeed() or math.max(1,settings.speed or 7)
 local perStop=math.max(0,settings.gatherDelay or 3)+math.max(0,settings.mountDelay or 0)
 local maxStops=math.max(3,math.min(150,settings.nodeLimit or 100))
 local budget=math.max(60,(settings.routeMinutes or 20)*60)
 local maxYards=math.max(200,(budget-perStop*math.min(#stops,maxStops))*speed)
 local tour=nearestTour(stops,start)
 twoOpt(tour,#tour>250 and 6 or 30)
 tour=bestWindow(tour,maxStops,maxYards)
 twoOpt(tour,40); orOpt(tour,10); twoOpt(tour,10)
 -- Start at the stop nearest you, heading toward the nearer neighbour.
 local n=#tour
 local first,bd=1,math.huge
 for i,s in ipairs(tour) do local d=dist(start,s); if d<bd then first,bd=i,d end end
 local ordered={}
 for k=0,n-1 do ordered[#ordered+1]=tour[(first+k-1)%n+1] end
 if n>2 and dist(start,ordered[n])<dist(start,ordered[2]) then
  local r={ordered[1]}; for k=n,2,-1 do r[#r+1]=ordered[k] end; ordered=r
 end
 local length=tourLength(ordered)
 local points={}
 for i,s in ipairs(ordered) do
  points[i]={x=s.x/w,y=s.y/h,map=map,name=s.name,kind=s.kind,object=s.object,spawns=s.count,
   source=s.observed and 'Observed' or 'Potential spawn',skillPriority=s.skillPriority,skillColor=s.skillColor,picked=s.picked,empty=s.empty}
 end
 local route={points=points,map=map,width=w,height=h,loop=true,strategy='zoneloop',optimizer='zoneloop-v1',
  speed=speed,mountDelay=settings.mountDelay,gatherDelay=settings.gatherDelay,mode=settings.travel,created=self:Now(),
  length=length,seconds=length/speed+perStop*#points,arriveRadius=ARRIVE_RADIUS,origin=self:Copy(points[1]),
  skillup=settings.routeSelectionMode=='skillup' or nil,gold=settings.routeSelectionMode=='gold' or nil}
 return route
end

function N:RouteSummary(route)
 route=route or self.activeRoute
 if not route then return nil end
 local spawns=0; for _,p in ipairs(route.points) do spawns=spawns+(p.spawns or 1) end
 return string.format('%d stops (%d spawn spots), %.1f km loop, about %d min per lap',#route.points,spawns,(route.length or 0)*0.9144/1000,math.floor((route.seconds or 0)/60+.5))
end

-- Instant replacement for the old multi-pass planner.
function N:GenerateRoute()
 local map,x,y=self:Position()
 if not map then return self:Print('Your position is not available here.') end
 if self.db.settings.routeSelectionMode=='skillup' or self.db.settings.routeSelectionMode=='gold' then
  self.generating=true; self:Guard('scan',function() self:ScanProfessions() end); self.generating=nil
 end
 local nodes=self:ZoneNodes(map)
 if #nodes==0 then
  local mode=self.db.settings.routeSelectionMode
  return self:Print(mode=='skillup' and 'Nothing in this zone gives you skill-ups. Try a zone from "Best zones".'
   or mode=='gold' and 'Nothing here you can gather. Try a zone from "Best zones".' or 'Nothing matching in this zone.')
 end
 local route,err=self:BuildZoneLoop(map,nodes,{x=x,y=y})
 if not route then return self:Print(err) end
 if self.ResourceSetKey then route.resourceKey=self:ResourceSetKey(nodes) end
 if self.ResetLoopTracking then self:ResetLoopTracking() end
 self.activeRoute=route; self.waypoint=1; self.terrainIndex=1; self.routePaused=false; self.lap=1
 self.dirty=true; self:ShowArrow()
 if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() and self.RefreshMap then self:RefreshMap() end
 self:Print('Route ready: '..self:RouteSummary(route)..'.'..((self.lastDroppedSpots or 0)>0 and (' Skipped '..self.lastDroppedSpots..' spots that were always empty.') or ''))
 return route
end

-- Zones ranked by how many matching stops they have (for skill-ups or a resource).
function N:BestZones(limit)
 local maps={}
 for _,zones in pairs(self.spawns or {}) do for map in pairs(zones) do maps[map]=true end end
 local out={}
 for map in pairs(maps) do
  if not self:IsGatheringCityMap(map) then
   local nodes=self:ZoneNodes(map)
   if #nodes>=4 then
    local weight=0; for _,n in ipairs(nodes) do weight=weight+(n.skillPriority or 1) end
    local info=C_Map and C_Map.GetMapInfo and self:Call(C_Map.GetMapInfo,map)
    out[#out+1]={map=map,name=type(info)=='table' and info.name or ('Zone '..map),spawns=#nodes,weight=weight}
   end
  end
 end
 table.sort(out,function(a,b) if a.weight~=b.weight then return a.weight>b.weight end return a.map<b.map end)
 while #out>(limit or 3) do table.remove(out) end
 return out
end

-- Gathering a node near the current stop counts as arriving there.
N:On('UNIT_SPELLCAST_SUCCEEDED',function(unit,_,spell)
 local kind=N.gatherSpells and N.gatherSpells[spell]
 if unit~='player' or (kind~='herb' and kind~='ore') then return end
 local route=N.activeRoute; if not route or not route.loop or N.routePaused then return end
 if N.ClaimGather and N:ClaimGather() then return end -- it was the stop you just reached
 local p=route.points[N.waypoint or 1]; local map,x,y=N:Position()
 if p and map==route.map and x then
  local dx,dy=(p.x-x)*route.width,(p.y-y)*route.height
  if dx*dx+dy*dy<=(STOP_RADIUS+15)^2 then N:SkipWaypoint('picked') end
 end
end)
