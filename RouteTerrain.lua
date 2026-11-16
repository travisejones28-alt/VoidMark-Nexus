local _, N = ...
-- 0.11 terrain-aware zone loops.
--
-- The fast zone-loop builder (RouteGen.lua) orders stops by travel cost. When
-- this zone has learned movement trails (Terrain.lua) or obstacle marks, that
-- cost comes from them:
--  * Learned trail: both stops sit within 20 yards of a recorded corridor and
--    the corridor connects them. Uses measured travel time scaled to the
--    current speed. Shown as VERIFIED (cyan) except the short connectors.
--  * Obstacle detour: the straight line crosses a marked obstacle; the leg
--    goes around it. ESTIMATED (purple): nobody has walked it yet.
--  * Direct: straight line. ESTIMATED.
-- Nothing here reads collision from map artwork. A trail proves a path exists;
-- it does not prove the straight line is blocked. A learned detour replaces
-- the straight line only when it is not much longer than it, and the limit is
-- looser when the corridor has been walked repeatedly.
local ANCHOR=20          -- yards from a stop to the nearest trail point
local MAX_SOURCES=160    -- single-source searches per graph (one per anchored stop)
local SINGLE_WALK=1.5    -- learned path may be this much longer than straight (walked once)
local REPEATED_WALK=2.5  -- ...or this much when walked at least twice on average
local UNREACHABLE=5000   -- yards of penalty instead of math.huge (keeps 2-opt arithmetic finite)

local floor,sqrt=math.floor,math.sqrt

-- Small binary heap for Dijkstra.
local function push(h,id,cost)
 local n=#h+1;h[n]={id,cost}
 while n>1 do local p=floor(n/2);if h[p][2]<=h[n][2] then break end;h[p],h[n]=h[n],h[p];n=p end
end
local function pop(h)
 local top=h[1];if not top then return end
 local last=table.remove(h)
 if #h>0 then
  h[1]=last;local n=1
  while true do
   local l,r,s=n*2,n*2+1,n
   if h[l] and h[l][2]<h[s][2] then s=l end
   if h[r] and h[r][2]<h[s][2] then s=r end
   if s==n then break end
   h[s],h[n]=h[n],h[s];n=s
  end
 end
 return top[1],top[2]
end

-- Prepared, read-only view of one zone's learned corridors and obstacle marks.
-- Cached until trails, marks, size or speed change. nil when the zone has none:
-- the builder then keeps its plain straight-line behaviour.
function N:TerrainGraph(map,w,h,speed)
 if not w or not h then return end
 local z=self.TerrainZone and self:TerrainZone(map)
 local blocks=self.db.terrainBlocks and self.db.terrainBlocks[map]
 local trail=type(z)=='table' and #z.points>1 and (z.edgeCount or 0)>0
 local marked=type(blocks)=='table' and #blocks>0
 if not trail and not marked then return end
 speed=math.max(1,tonumber(speed) or 7)
 local key=table.concat({map,trail and z.revision or 0,trail and #z.points or 0,marked and #blocks or 0,
  marked and string.format('%.4f%.4f',blocks[#blocks].x,blocks[#blocks].y) or '',w,h,string.format('%.2f',speed)},':')
 local g=self.terrainGraph
 if g and g.key==key then return g end
 g={key=key,map=map,w=w,h=h,speed=speed,z=trail and z or nil,marked=marked,grid={},sources={},sourceCount=0}
 if trail then
  for i,p in ipairs(z.points) do
   local k=floor(p.x*w/ANCHOR)..':'..floor(p.y*h/ANCHOR)
   g.grid[k]=g.grid[k] or {};table.insert(g.grid[k],i)
  end
 end
 self.terrainGraph=g
 return g
end

-- Nearest trail point within ANCHOR yards that can be reached without crossing a mark.
local function anchor(self,g,p)
 if not g.z then return end
 if p.anchorKey==g.key then return p.anchorIndex,p.anchorDistance end
 local gx,gy=floor(p.x/ANCHOR),floor(p.y/ANCHOR)
 local best,bd
 local here={x=p.x/g.w,y=p.y/g.h}
 for dx=-1,1 do for dy=-1,1 do
  for _,i in ipairs(g.grid[(gx+dx)..':'..(gy+dy)] or {}) do
   local q=g.z.points[i]
   local d=sqrt((q.x*g.w-p.x)^2+(q.y*g.h-p.y)^2)
   if d<=ANCHOR and (not bd or d<bd) and not (g.marked and self:TerrainIntersects(here,q,g.w,g.h,g.map)) then best,bd=i,d end
  end
 end end
 p.anchorKey,p.anchorIndex,p.anchorDistance=g.key,best,bd
 return best,bd
end

-- Shortest measured travel time from one trail point to every other (ground edges only).
local function search(self,g,source)
 local s=g.sources[source]
 if s then return s end
 if g.sourceCount>=MAX_SOURCES then return end
 local z=g.z;local cost,prev,done={[source]=0},{},{}
 local heap={};push(heap,source,0)
 while true do
  local i,c=pop(heap);if not i then break end
  if not done[i] then
   done[i]=true
   for j,e in pairs(z.edges[i] or {}) do
    if e.mode=='ground' and not done[j] and not (g.marked and self:TerrainIntersects(z.points[i],z.points[j],g.w,g.h,g.map)) then
     local seconds=math.max(e.distance/g.speed,e.seconds*e.speed/g.speed)
     local nc=c+seconds
     if not cost[j] or nc<cost[j] then cost[j]=nc;prev[j]=i;push(heap,j,nc) end
    end
   end
  end
 end
 s={cost=cost,prev=prev};g.sources[source]=s;g.sourceCount=g.sourceCount+1
 return s
end

-- One directed leg between two stops given in yards ({x,y}). Returns a table:
--  cost (yard-equivalent used by the optimiser), length (yards), seconds,
--  via (normalised points between the stops), kind, verified (yards on trail).
function N:TerrainLoopLeg(g,a,b)
 local d=sqrt((a.x-b.x)^2+(a.y-b.y)^2)
 local speed=g.speed
 local na,nb={x=a.x/g.w,y=a.y/g.h},{x=b.x/g.w,y=b.y/g.h}
 local blocked=g.marked and self:TerrainIntersects(na,nb,g.w,g.h,g.map)
 -- Learned corridor between the two stops.
 local ia,da=anchor(self,g,a);local ib,db=anchor(self,g,b)
 if ia and ib and ia~=ib then
  local s=search(self,g,ia)
  if s and s.cost[ib] then
   local path,length,walks={},0,0
   local i=ib
   while i do
    path[#path+1]=i
    local p=s.prev[i]
    if p then
     local e=g.z.edges[p][i];local q,r=g.z.points[p],g.z.points[i]
     local seg=sqrt(((q.x-r.x)*g.w)^2+((q.y-r.y)*g.h)^2)
     length=length+seg;walks=walks+seg*(e and e.samples or 1)
    end
    if i==ia or #path>2000 then break end
    i=p
   end
   local total=length+da+db
   local repeated=length>0 and walks/length>=2
   local limit=(repeated and REPEATED_WALK or SINGLE_WALK)*math.max(d,1)
   if total<=limit or blocked then
    local via={}
    for k=#path,1,-1 do local q=g.z.points[path[k]];via[#via+1]={x=q.x,y=q.y,validated=k<#path} end
    local seconds=s.cost[ib]+(da+db)/speed
    return {cost=seconds*speed,length=total,seconds=seconds,via=via,kind='learned',verified=length,repeated=repeated or nil}
   end
  end
 end
 if blocked then
  local distance,detour=self:TerrainLeg(na,nb,g.w,g.h,g.map,speed)
  if distance==math.huge or not self:Finite(distance,0,1e9) then
   return {cost=d+UNREACHABLE,length=d,seconds=d/speed,via={},kind='unreachable',verified=0}
  end
  local via={};for _,p in ipairs(detour or {}) do via[#via+1]={x=p.x,y=p.y,validated=false} end
  return {cost=distance,length=distance,seconds=distance/speed,via=via,kind='detour',verified=0}
 end
 return {cost=d,length=d,seconds=d/speed,via={},kind='direct',verified=0}
end

-- Cost function for the loop optimiser. Symmetric (mean of both directions) so
-- 2-opt reversals stay valid; the final loop is then checked in both directions.
-- Returns nil when the zone has no trails or marks (plain distance is used).
function N:LoopCostFunction(map,w,h,speed,opts)
 if self.db.settings.terrainRouting==false then return end
 local g=self:TerrainGraph(map,w,h,speed);if not g then return end
 opts=opts or {}
 local pen=opts.landPenalty and self.LegOffLand and self:HasLand(map) and opts.landPenalty
 local memo=setmetatable({},{__mode='k'})
 local function one(a,b)
  local row=memo[a];if not row then row={};memo[a]=row end
  local c=row[b];if c then return c end
  local leg=self:TerrainLoopLeg(g,a,b);c=leg.cost
  -- Leaving the zone's land outline only penalises unverified legs.
  if pen and leg.kind~='learned' then c=c*(1+pen*self:LegOffLand(map,a.x/w,a.y/h,b.x/w,b.y/h)) end
  row[b]=c;return c
 end
 return function(a,b) if a==b then return 0 end return (one(a,b)+one(b,a))/2 end,g
end

-- Directed legs for an ordered loop (stops in yards). Picks the cheaper direction.
function N:AnnotateLoopLegs(g,ordered)
 local n=#ordered
 local function legs(list)
  local out,total={},0
  for i=1,#list do local l=self:TerrainLoopLeg(g,list[i],list[i%#list+1]);out[i]=l;total=total+l.cost end
  return out,total
 end
 local forward,ft=legs(ordered)
 if n>2 then
  local reversed={ordered[1]};for k=n,2,-1 do reversed[#reversed+1]=ordered[k] end
  local backward,bt=legs(reversed)
  if bt<ft-1 then return reversed,backward end
 end
 return ordered,forward
end

-- Summary of how much of a loop has been walked before.
function N:LoopTerrainSummary(route)
 if not route or not route.legs then return nil end
 local learned,detour,blocked=0,0,0
 for _,l in ipairs(route.legs) do
  if l.kind=='learned' then learned=learned+1 elseif l.kind=='detour' then detour=detour+1 elseif l.kind=='unreachable' then blocked=blocked+1 end
 end
 local parts={string.format('%d%% of the loop on trails you walked',floor((route.verifiedShare or 0)*100+.5))}
 if learned>0 then parts[#parts+1]=learned..' leg'..(learned==1 and '' or 's')..' follow learned trails' end
 if detour>0 then parts[#parts+1]=detour..' detour'..(detour==1 and '' or 's')..' around marked obstacles (estimated)' end
 if blocked>0 then parts[#parts+1]=blocked..' leg'..(blocked==1 and '' or 's')..' with no way round a mark found' end
 return table.concat(parts,'; ')
end

--------------------------------------------------------------------------------
-- Navigation along a loop leg's trail points
--------------------------------------------------------------------------------
-- The arrow follows the trail points of the leg you are on, then the stop.
function N:LoopViaTarget(route)
 local leg=self.loopLeg
 if not leg or leg.route~=route or not route.legs or leg.to~=(self.waypoint or 1) then return end
 local l=route.legs[leg.from];local p=l and l.via and l.via[leg.i]
 if not p then return end
 return {x=p.x,y=p.y,transit=true,loopVia=true,validated=p.validated,
  name=l.kind=='learned' and 'Learned trail' or 'Detour around obstacle'}
end
-- Snap forward along the leg's remaining trail points: the nearest one ahead
-- becomes the target, and reaching it (15 yd) moves on. Never moves backward.
function N:LoopViaUpdate(route,x,y)
 local leg=self.loopLeg;local l=leg and route.legs and route.legs[leg.from];local list=l and l.via
 if not list or not list[leg.i] then return false end
 local w,h=route.width,route.height
 local best,bd
 for k=leg.i,math.min(#list,leg.i+40) do
  local d=sqrt(((list[k].x-x)*w)^2+((list[k].y-y)*h)^2)
  if not bd or d<bd then best,bd=k,d end
 end
 if bd<15 then leg.i=best+1;return true end
 if best>leg.i then leg.i=best;return true end
 return false
end
function N:AdvanceLoopVia() if self.loopLeg then self.loopLeg.i=self.loopLeg.i+1 end end
do
 local skip=N.SkipWaypoint
 N.SkipWaypoint=function(self,...)
  local route=self.activeRoute;local from=self.waypoint or 1
  local a,b=skip(self,...)
  if route and route.loop and self.activeRoute==route and route.legs then
   self.loopLeg={route=route,from=from,to=self.waypoint or 1,i=1}
  else self.loopLeg=nil end
  return a,b
 end
end

-- The rest of a loop from stop w0, with trail points between stops, closing
-- back to stop 1. Each entry: {n=point, stop=index or nil, validated=bool}.
-- validated describes the segment that ends at that entry.
function N:LoopRing(route,w0)
 local pts=route.points;local n=#pts;local out={}
 w0=math.max(1,math.min(n,w0 or self.waypoint or 1))
 local function via(k)
  local l=route.legs and route.legs[k]
  for _,p in ipairs(l and l.via or {}) do out[#out+1]={n=p,validated=p.validated==true} end
 end
 -- The leg you are on now (its remaining trail points) comes first.
 local leg=self.loopLeg
 if leg and leg.route==route and leg.to==w0 and route.legs and route.legs[leg.from] then
  local list=route.legs[leg.from].via or {}
  for k=leg.i,#list do out[#out+1]={n=list[k],validated=list[k].validated==true} end
 end
 out[#out+1]={n=pts[w0],stop=w0}
 for k=w0,n-1 do via(k);out[#out+1]={n=pts[k+1],stop=k+1} end
 if w0>1 then via(n);out[#out+1]={n=pts[1],stop=1,closing=true} end
 return out
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------
N.commands=N.commands or {}
N.commandHelp=N.commandHelp or {}
function N:AddCommand(name,fn,help)
 self.commands[name]=fn
 if help then self.commandHelp[#self.commandHelp+1]=help end
end
function N:TerrainStatus()
 local map=self:Position()
 local z=map and self:TerrainZone(map)
 local blocks=map and self.db.terrainBlocks and self.db.terrainBlocks[map]
 return string.format('Trail learning %s. This zone: %d trail points, %d connections, %d obstacle marks. Loop routing %s.',
  self.db.settings.terrainLearn and 'on' or 'off',z and #z.points or 0,z and z.edgeCount or 0,type(blocks)=='table' and #blocks or 0,
  self.db.settings.terrainRouting==false and 'ignores them' or 'uses them')
end
N:AddCommand('terrain',function(self,args)
 if args=='on' then self.db.settings.terrainLearn=true
 elseif args=='off' then self.db.settings.terrainLearn=false;self.trailPrevious=nil
 elseif args=='clear' then return self:ClearTerrain()
 elseif args=='use' then self.db.settings.terrainRouting=true
 elseif args=='ignore' then self.db.settings.terrainRouting=false end
 self.terrainGraph=nil
 self:Print(self:TerrainStatus()..' /vmn terrain on|off|use|ignore|clear')
end,'/vmn terrain on|off|use|ignore|clear (learned trails)')
N:AddCommand('block',function(self,args) self.terrainGraph=nil;self:MarkRouteObstacle(args) end,'/vmn block [yards] (mark an obstacle here)')
N:AddCommand('clearblocks',function(self) self.terrainGraph=nil;self:ClearRouteObstacles() end)
