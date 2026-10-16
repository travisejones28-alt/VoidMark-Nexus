local _, N = ...
local function key(p)
 return tostring(p.object)..':'..math.floor(p.x*500+.5)..':'..math.floor(p.y*500+.5)
end
function N:GatherEvidence(map,p,create)
 if not p.object then return end
 self.db.gatherEvidence=type(self.db.gatherEvidence)=='table' and self.db.gatherEvidence or {}
 local zones=self.db.gatherEvidence
 if not zones[map] and create then
  local n=0;for _ in pairs(zones) do n=n+1 end;if n>=50 then return end
  zones[map]={}
 end
 local z=zones[map];if type(z)~='table' then return end
 local k=key(p);local e=z[k]
 if e and (type(e)~='table' or not self:Finite(e.harvests,0,1e9) or not self:Finite(e.qty,0,1e12)
  or not self:Finite(e.checks,0,1e9) or not self:Finite(e.available,0,1e9)) then z[k]=nil;e=nil end
 if not e and create then
  local n=0;for _ in pairs(z) do n=n+1 end;if n>=3000 then return end
  e={harvests=0,qty=0,checks=0,available=0,duration=0};z[k]=e
 end
 return e
end
function N:RecordHarvest(g,qty)
 local e=self:GatherEvidence(g.map,g,true);if not e then return end
 if not g.recordedHarvest then
  e.harvests=math.min(1e9,e.harvests+1)
  e.duration=(tonumber(e.duration) or 0)+math.max(0,(g.at or self:Now())-(g.started or g.at or self:Now()))
  g.recordedHarvest=true
 end
 e.qty=math.min(1e12,e.qty+qty);e.at=self:Now()
 local s=self.session;s.resources=s.resources or {}
 local name=(self.nodeTypes[g.object] or {}).name or tostring(g.object)
 s.resources[name]=(s.resources[name] or 0)+qty
 local route=self.activeRoute
 if route and not self.routePaused and route.map==g.map then
  local id=self:RouteIdentity(route);s.routeTotals=s.routeTotals or {}
  s.routeTotals[id]=(s.routeTotals[id] or 0)+qty
  if s.routePerformance and s.routePerformance[id] then
   local run=s.routePerformance[id];run.total=run.total+qty
  end
 end
end
function N:RouteIdentity(route)
 local parts={tostring(route.map),route.mode or 'Foot',tostring(route.speed or 7)}
 for _,p in ipairs(route.points or {}) do parts[#parts+1]=key(p) end
 local text=table.concat(parts,';');local hash=0
 for i=1,#text do hash=(hash*31+text:byte(i))%2147483647 end
 return tostring(route.map)..':'..tostring(hash)
end
function N:TrackRouteSession()
 local now=self:Call(GetTime) or self:Now();local last=self.routeSessionAt;self.routeSessionAt=now
 if not last or now-last>2 or now-last<=0 or not self.session or not self.db.settings.stats or self.routePaused then return end
 local r=self.activeRoute;local map=self:Position();if not r or r.map~=map then return end
 local runs=self.session.routePerformance or {};self.session.routePerformance=runs
 local id=self:RouteIdentity(r)
 if not runs[id] then
  local count=0;for _ in pairs(runs) do count=count+1 end;if count>=30 then return end
  runs[id]={map=map,mode=r.mode or 'Custom',seconds=0,total=0,stops=#r.points}
 end
 runs[id].seconds=runs[id].seconds+now-last
end
function N:RouteSessionText(session)
 local lines={}
 for id,r in pairs(session.routePerformance or {}) do
  lines[#lines+1]=string.format('Route %s (%s): %.1f min, %d materials, %.1f/hour',id,r.mode,r.seconds/60,r.total,r.total/math.max(1,r.seconds)*3600)
 end
 table.sort(lines);return table.concat(lines,'\n')
end
-- Availability requires explicit checks including empty visits. Successful
-- casts alone are a biased sample and never establish a spawn probability.
function N:CheckGatherStop(available)
 local r=self.activeRoute;local p=r and r.points[self.waypoint or 1]
 local map,x,y=self:Position()
 if not p or not x or map~=r.map or self:Distance(p,{x=x,y=y},r.width,r.height)>25 then
  return self:Print('Stand within 25 yards of the current gathering stop before recording a check.')
 end
 local e=self:GatherEvidence(map,p,true);if not e then return end
 if e.checkedAt and self:Now()-e.checkedAt<60 then return self:Print('This stop was checked in the last minute.') end
 e.checks=math.min(1e9,e.checks+1);e.available=math.min(1e9,e.available+(available and 1 or 0));e.checkedAt=self:Now()
 self:Print(available and 'Recorded available node.' or 'Recorded empty stop.');self.dirty=true
end
function N:ScoreRouteEvidence(route)
 local expected,known,observed,checks=0,0,0,0
 for _,p in ipairs(route.points) do
  if p.source=='Observed' then observed=observed+1 end
  local e=self:GatherEvidence(route.map,p)
  if e and e.checks>=5 and e.harvests>=3 then
   expected=expected+math.min(1,e.available/e.checks)*e.qty/e.harvests
   known=known+1;checks=checks+e.checks
  end
 end
 route.observedStops=observed;route.evidenceStops=known;route.availabilityChecks=checks
 route.expectedResourcesPerHour=known==#route.points and known>0 and expected/math.max(1,route.seconds)*3600 or nil
 route.potentialStopsPerHour=#route.points/math.max(1,route.seconds)*3600
 route.dataQuality=route.expectedResourcesPerHour and 'Sampled checks; limited confidence' or 'Potential stops; harvest rate unknown'
end
