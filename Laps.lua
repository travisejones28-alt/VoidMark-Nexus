local _, N = ...
-- 0.6: zone loops learn from what you actually find.
--  * Spot learning: arriving at a stop and gathering there marks the spot
--    "picked"; arriving and leaving without gathering marks it "empty".
--    Rebuilt loops favour picked spots and drop spots that are always empty.
--  * Lap stats: picked / empty / minutes / skill gained, per lap.
--  * Measured speed: the arrow's seconds and the lap minutes use how fast you
--    really move (on foot or mounted) instead of a fixed guess.
--  * Re-plan: on a skill-up route, when a herb or ore turns grey or a new one
--    unlocks, the loop is rebuilt from where you stand.
-- All of it is event driven or sampled once a second; nothing runs off-route.

local CELL=40          -- yards; evidence is kept per cell so it survives rebuilds
local VISIT_WINDOW=90  -- seconds after arriving in which a gather counts for that stop
local PICK_RADIUS=60   -- yards from the stop centre
local MAX_SPOTS=2000   -- per zone
N.spotCell=CELL

local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end

function N:SpotKey(map,x,y)
 if not self:Finite(x,0,1) or not self:Finite(y,0,1) then return end
 local w,h=self:MapSize(map); if not w then return end
 return math.floor(x*w/CELL)..':'..math.floor(y*h/CELL)
end
function N:SpotEvidence(map,x,y)
 local key=self:SpotKey(map,x,y)
 local zone=key and type(self.db.spots)=='table' and self.db.spots[map]
 local e=type(zone)=='table' and zone[key]
 return type(e)=='table' and e or nil
end
function N:RecordSpot(map,x,y,result)
 if self.db.settings.learnSpots==false then return end
 local key=self:SpotKey(map,x,y); if not key then return end
 local spots=self.db.spots; if type(spots[map])~='table' then spots[map]={} end
 local zone=spots[map]; local e=zone[key]
 if type(e)~='table' then
  if count(zone)>=MAX_SPOTS then return end
  e={picked=0,empty=0}; zone[key]=e
 end
 if result=='picked' then
  e.picked=math.min(50,(tonumber(e.picked) or 0)+1)
  e.empty=math.floor((tonumber(e.empty) or 0)/2) -- a find forgives old misses
 else e.empty=math.min(50,(tonumber(e.empty) or 0)+1) end
 e.at=self:Now(); self.dirty=true
end
-- Weight multiplier for a stop. 0 = never seen up after 5 visits: drop it.
function N:SpotFactor(e)
 if type(e)~='table' then return 1 end
 local p,m=tonumber(e.picked) or 0,tonumber(e.empty) or 0
 if p==0 and m>=5 then return 0 end
 return math.max(.15,math.min(2,(1+p*.5)/(1+m*.5)))
end
function N:ForgetSpots(map)
 if map then self.db.spots[map]=nil else self.db.spots={} end
 self.dirty=true
end

-- Current skill in the route's gathering profession (nil if unknown).
function N:LoopSkill(route)
 local skills=self:GatheringSkills()
 local kind=self.db.settings.kind=='ore' and 'ore' or 'herb'
 local p=skills[kind] or skills.herb or skills.ore
 return p and p.skill
end
function N:LapStats()
 if not self.lapStats then
  self.lapStats={started=self:Now(),visited=0,picked=0,empty=0,skill=self:LoopSkill(self.activeRoute)}
 end
 return self.lapStats
end
function N:LapLine(lap,prefix)
 if not lap then return nil end
 local minutes=((lap.finished or self:Now())-lap.started)/60
 local gain=lap.gain or (lap.skill and self:LoopSkill() and self:LoopSkill()-lap.skill) or nil
 return string.format('%s%d picked, %d empty, %.1f min%s',prefix or '',lap.picked,lap.empty,minutes,
  gain and gain>0 and ('  +'..gain..' skill') or '')
end
function N:FinishLap()
 local lap=self.lapStats; self.lapStats=nil
 if not lap then return end
 lap.finished=self:Now()
 local now=self:LoopSkill(); if lap.skill and now then lap.gain=math.max(0,now-lap.skill) end
 self.lastLap=lap
 local h=self.db.laps; h[#h+1]={at=lap.finished,map=self.activeRoute and self.activeRoute.map,picked=lap.picked,empty=lap.empty,
  seconds=lap.finished-lap.started,gain=lap.gain}
 while #h>50 do table.remove(h,1) end
 self:Print(self:LapLine(lap,'Lap done: ')..'.')
 self.dirty=true
end

-- A visit starts when you reach a stop. It counts as picked if you gather
-- near it within VISIT_WINDOW, otherwise as empty when the next visit starts.
function N:EndVisit()
 local v=self.visit; self.visit=nil
 if not v or v.picked then return end
 self:RecordSpot(v.map,v.x,v.y,'empty')
 if self.lapStats then self.lapStats.empty=self.lapStats.empty+1 end
end
function N:BeginVisit(route,index,picked)
 self:EndVisit()
 local p=route and route.points and route.points[index]
 if not p then return end
 local lap=self:LapStats(); lap.visited=lap.visited+1
 self.visit={map=route.map,x=p.x,y=p.y,at=self:Now(),index=index}
 if picked then self:MarkVisitPicked() end
end
function N:MarkVisitPicked()
 local v=self.visit; if not v or v.picked then return end
 v.picked=true
 self:RecordSpot(v.map,v.x,v.y,'picked')
 local lap=self:LapStats(); lap.picked=lap.picked+1
end
-- Called on a successful gather cast. True when it belonged to the open visit.
function N:ClaimGather()
 local v=self.visit; if not v or v.picked or self:Now()-v.at>VISIT_WINDOW then return false end
 local map,x,y=self:Position(); local w,h=self:MapSize(v.map)
 if map~=v.map or not x or not w then return false end
 local dx,dy=(v.x-x)*w,(v.y-y)*h
 if dx*dx+dy*dy>PICK_RADIUS*PICK_RADIUS then return false end
 local route=self.activeRoute; local cur=route and route.map==v.map and route.points[self.waypoint or 1]
 if cur and cur~=route.points[v.index] then
  local cx,cy=(cur.x-x)*w,(cur.y-y)*h
  if cx*cx+cy*cy<dx*dx+dy*dy then return false end -- nearer the next stop: it's that one's herb
 end
 self:MarkVisitPicked(); return true
end
function N:ResetLoopTracking()
 self.visit=nil; self.lapStats=nil; self.lingerAt=nil
end

-- Measured movement speed (yards/second), sampled once a second while a route is active.
function N:SampleSpeed(dt)
 local route=self.activeRoute
 if not route or self.routePaused then self.speedSample=nil;return end
 if UnitOnTaxi and self:Call(UnitOnTaxi,'player') then self.speedSample=nil;return end
 local map,x,y=self:Position()
 local w,h; if map then w,h=self:MapSize(map) end
 if not w then self.speedSample=nil;return end
 local last=self.speedSample
 self.speedSample={map=map,x=x,y=y}
 if not last or last.map~=map or not self:Finite(dt,.2,3) then return end
 local v=math.sqrt(((x-last.x)*w)^2+((y-last.y)*h)^2)/dt
 if v<2 or v>40 then return end -- standing, gathering, or teleported
 self.measuredSpeed=self.measuredSpeed and (self.measuredSpeed*.8+v*.2) or v
end
function N:TravelSpeed(route)
 if self:Finite(self.measuredSpeed,1,50) then return self.measuredSpeed end
 return math.max(1,(route and route.speed) or self.db.settings.speed or 7)
end

-- Skill-up routes: rebuild when the set of useful herbs/ore changes.
function N:ResourceSetKey(nodes)
 local names,seen={},{}
 for _,n in ipairs(nodes or {}) do if n.name and not seen[n.name] then seen[n.name]=true;names[#names+1]=n.name end end
 table.sort(names); return table.concat(names,'|')
end
function N:CheckReplan()
 local route=self.activeRoute
 if self.generating or not route or not route.loop or not route.skillup or not route.resourceKey then return end
 if self.db.settings.routeSelectionMode~='skillup' then return end
 local map=self:Position(); if map~=route.map then return end
 local key=self:ResourceSetKey(self:ZoneNodes(map))
 if key==route.resourceKey then return end
 if key=='' then return self:Print('Nothing in this zone gives skill-ups any more. Pick another zone with the Zone button.') end
 local lap,lastLap=self.lap,self.lapStats
 local fresh=self:GenerateRoute()
 if fresh then
  self.lap=lap or 1; self.lapStats=lastLap
  self:Print('Herb colours changed, so the loop was rebuilt from here.')
 end
end
do
 local scan=N.ScanProfessions
 if type(scan)=='function' then
  N.ScanProfessions=function(self,...)
   local a,b,c=scan(self,...)
   if not self.generating then self:Guard('replan',function() self:CheckReplan() end) end
   return a,b,c
  end
 end
end

local driver=CreateFrame('Frame')
local elapsed=0
driver:SetScript('OnUpdate',function(_,delta)
 elapsed=elapsed+delta; if elapsed<1 then return end
 local dt=elapsed; elapsed=0
 if N.ready then N:Guard('speed',function() N:SampleSpeed(dt) end) end
end)
N:On('UNIT_SPELLCAST_SUCCEEDED',function(unit,_,spell)
 if unit~='player' then return end
 local kind=N.gatherSpells and N.gatherSpells[spell]
 if kind=='herb' or kind=='ore' then N:ClaimGather() end
end)
