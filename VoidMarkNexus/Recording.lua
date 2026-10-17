local _, N = ...
local function validDraft(self,d)
 if type(d)~='table' or d.version~=1 or type(d.name)~='string' or #d.name>80
  or not self:Finite(d.map,1,100000) or not self:Finite(d.width,1,100000)
  or not self:Finite(d.height,1,100000) or type(d.points)~='table' or #d.points<1 or #d.points>2047 then return false end
 for _,p in ipairs(d.points) do
  if type(p)~='table' or not self:Finite(p.x,0,1) or not self:Finite(p.y,0,1) then return false end
 end
 return true
end
function N:InitializeRecording()
 self.db.recordings=type(self.db.recordings)=='table' and self.db.recordings or {}
 local d=self.db.recordings[self.characterID]
 self.recordingReadOnly=type(d)=='table' and type(d.version)=='number' and d.version>1
 self.recording=validDraft(self,d) and d or nil
 self.recordingAt=nil
end
function N:StartRecording(name)
 if self.recordingReadOnly then return self:Print('Newer recording format preserved. Update Nexus to continue it.') end
 if self.recording then return self:Print('A recording is already saved. Finish or discard it first.') end
 if self.planningThread then return self:Print('Finish or cancel route calculation before recording.') end
 local map,x,y=self:Position();local w,h
 if map then w,h=self:MapSize(map) end
 if not (w and h and x and y) then return self:Print('Zone position unavailable.') end
 name=tostring(name or ''):sub(1,80);if name=='' then name='Recorded '..date('%m-%d %H:%M') end
 self.recording={version=1,name=name,map=map,width=w,height=h,points={{x=x,y=y}},created=self:Now()}
 self.db.recordings[self.characterID]=self.recording;self.recordingAt=nil
 self:Print('Recording '..name..'. /vmn record finish saves it; /vmn record discard removes the draft.')
 self.dirty=true
end
function N:SampleRecording()
 local d=self.recording;if not d then return end
 local now=self:Call(GetTime) or self:Now()
 if self.recordingAt and now-self.recordingAt<1 then return end
 self.recordingAt=now
 if self:Call(UnitOnTaxi,'player') or self:Call(IsFlying) or self:Call(UnitIsDeadOrGhost,'player') or self:Call(IsFalling) then
  d.interrupted=true;return
 end
 local map,x,y=self:Position();if map~=d.map or not x or not y then d.interrupted=true;return end
 local p={x=x,y=y};local previous=d.points[#d.points]
 if previous and self:Distance(previous,p,d.width,d.height)<8 then return end
 if #d.points>=2047 then
  if not d.full then d.full=true;self:Print('Recording limit reached. Finish this draft before recording more.') end
  return
 end
 -- Large jumps or leaving the zone cannot be represented as a walked segment.
 if previous and self:Distance(previous,p,d.width,d.height)>80 then
  d.interrupted=true;return
 end
 if d.interrupted then return end
 d.points[#d.points+1]=p;self.dirty=true
end
function N:FinishRecording()
 local d=self.recording;if not d then return self:Print('No recording draft.') end
 if #d.points<2 then return self:Print('Walk farther before finishing the recording.') end
 local count=0;for _ in pairs(self.db.routes) do count=count+1 end
 if self.db.routes[d.name] then return self:Print('A route with that name exists. Rename it with /vmn recordname NAME, then finish.') end
 if count>=50 then return self:Print('Saved route limit: 50. Delete an unused route first.') end
 local travel,points,indices={}, {}, {}
 for i,p in ipairs(d.points) do travel[i]={x=p.x,y=p.y,map=d.map,transit=true,name='Recorded trail'} end
 local stride=math.max(1,math.ceil((#travel-1)/148))
 for i=1,#travel do
  if i==1 or i==#travel or (i-1)%stride==0 then
   local p=self:Copy(travel[i]);p.transit=false;p.name='Recorded waypoint'
   points[#points+1]=p;indices[#indices+1]=i
  end
 end
 local length=0;for i=2,#travel do length=length+self:Distance(travel[i-1],travel[i],d.width,d.height) end
 local route={map=d.map,width=d.width,height=d.height,points=points,origin=self:Copy(points[1]),
  travelPoints=travel,travelStopIndices=indices,mode='Recorded',recorded=true,
  speed=self.db.settings.speed,gatherDelay=0,mountDelay=0,length=length,
  seconds=length/math.max(1,self.db.settings.speed),created=d.created}
 if not self:CleanNavigationRoute(route) then return self:Print('Recording could not be validated; draft retained.') end
 self.db.routes[d.name]=route
 self.db.recordings[self.characterID]=nil;self.recording=nil;self.recordingAt=nil
 self:Print('Saved '..d.name..' with '..#travel..' trail points. Replay follows the recorded path.');self.dirty=true
end
function N:DiscardRecording()
 if self.recordingReadOnly then return self:Print('Newer recording format preserved.') end
 self.db.recordings[self.characterID]=nil;self.recording=nil;self.recordingAt=nil;self.dirty=true
 self:Print('Recording draft discarded.')
end
function N:RecordingStatus()
 local d=self.recording
 return d and string.format('Recording: %s | %d / 2047 trail points%s',d.name,#d.points,
  d.interrupted and ' | interrupted by a position jump; finish the valid portion' or '') or 'No recording draft.'
end
function N:ReplayRoute(name)
 local route=self.db.routes[name]
 if not route then return self:Print('Choose a saved route or use /vmn replay NAME.') end
 if self.planningThread then return self:Print('Finish or cancel route calculation first.') end
 route=self:CleanNavigationRoute(route);if not route then return self:Print('Saved route is invalid; original retained.') end
 local map,x,y=self:Position()
 if route.recorded then
  if map~=route.map or not x then return self:Print('Return to the recording zone before replaying.') end
  local best,index=math.huge,1
  for i,p in ipairs(route.travelPoints or {}) do
   local distance=self:Distance({x=x,y=y},p,route.width,route.height)
   if distance<best then best,index=distance,i end
  end
  self.activeRoute=route;self.terrainIndex=index;self.waypoint=1
  while self.waypoint<#route.points and route.travelStopIndices[self.waypoint]<index do self.waypoint=self.waypoint+1 end
  self.routePaused=false;self:ShowArrow();self.dirty=true;return
 end
 self:RunPlanner(function()
  if (route.strategy=='nearest' or route.strategy=='optimal') and map==route.map and x and y then
   return self:StartRouteAtNearest(route,{map=map,x=x,y=y})
  end
  return self:PrepareTerrainRoute(route)
 end,function(r)
  if r.unreachable then return self:Print('Saved route contains an unreachable leg.') end
  self.activeRoute=r;self.waypoint=1;self.terrainIndex=1;self.routePaused=false;self:ShowArrow();self.dirty=true
 end)
end
function N:SaveActiveSession()
 if not self.session then return end
 self.db.activeSessions=type(self.db.activeSessions)=='table' and self.db.activeSessions or {}
 local old=self.db.activeSessions[self.characterID]
 if type(old)=='table' and type(old.version)=='number' and old.version>1 then return end
 local copy=self:PortableCache(self.session)
 if copy then self.db.activeSessions[self.characterID]={version=1,session=copy,
  elapsed=math.max(0,self:Now()-copy.started),at=self:Now()} end
end
function N:RestoreSession()
 local entry=type(self.db.activeSessions)=='table' and self.db.activeSessions[self.characterID]
 local copy=type(entry)=='table' and entry.version==1 and self:PortableCache(entry.session)
 if copy and copy.character==self.characterID and type(copy.items)=='table' and
  self:Finite(copy.total,0,1e12) and self:Finite(entry.elapsed,0,31536000) and self:Finite(entry.at,0,self:Now()) then
  for id,qty in pairs(copy.items) do
   if not self:Finite(id,1,1e9) or id%1~=0 or not self:Finite(qty,0,1e12) then copy=nil;break end
  end
  if copy then
   for _,key in ipairs({'zones','kinds','resources','routeTotals'}) do
    if copy[key]~=nil and type(copy[key])~='table' then copy=nil;break end
    copy[key]=copy[key] or {}
    for _,qty in pairs(copy[key]) do if not self:Finite(qty,0,1e12) then copy=nil;break end end
    if not copy then break end
   end
  end
  if copy and type(copy.routePerformance or {})=='table' then
   for _,run in pairs(copy.routePerformance or {}) do
    if type(run)~='table' or type(run.mode)~='string' or not self:Finite(run.seconds,0,1e9)
     or not self:Finite(run.total,0,1e12) then copy=nil;break end
   end
  else copy=nil end
  if copy then
   self.session=copy;copy.started=self:Now()-entry.elapsed;copy.finished=nil;self.routeSessionAt=nil;return true
  end
 end
 self:StartSession();return false
end
N:On('PLAYER_LOGOUT',function() N:SaveActiveSession() end)
function N:SavedRunSummary(route)
 local id=self:RouteIdentity(route);local runs={};local total,elapsed=0,0
 for _,session in ipairs(self.db.sessions) do
  local r=(session.routePerformance or {})[id]
  if r and self:Finite(r.seconds,1,1e8) and self:Finite(r.total,0,1e12) then
   runs[#runs+1]=r.total/r.seconds*3600;total=total+r.total;elapsed=elapsed+r.seconds
  end
 end
 if #runs==0 then return 'No saved runs yet. Save your gathering session after a run to compare results.' end
 table.sort(runs)
 local median=(runs[math.floor((#runs+1)/2)]+runs[math.ceil((#runs+1)/2)])/2
 return string.format('%d saved sessions | %.1f materials/hour overall | median %.1f/hour | best %.1f/hour',
  #runs,total/math.max(1,elapsed)*3600,median,runs[#runs])
end
function N:TravelToRoute(name)
 local route=self.db.routes[name]
 if not route or not self:CleanNavigationRoute(route) then return self:Print('Select a valid saved route first.') end
 local addon=_G.ShortestPathForever;local api=type(addon)=='table' and addon.API
 if type(api)~='table' or api.version~=1 or type(api.Navigate)~='function' then
  return self:Print('Install Shortest Path Forever to guide the trip to this route. Nexus works without it.')
 end
 local destination=route.points[1];local map,x,y=self:Position()
 if not route.recorded and map==route.map and x and y then
  local best=math.huge
  for _,p in ipairs(route.points) do
   local d=self:Distance({x=x,y=y},p,route.width,route.height)
   if d<best then best=d;destination=p end
  end
 end
 local ok,taken=pcall(api.Navigate,'VoidMarkNexus',route.map,destination.x,destination.y,'Travel to '..name,'objective')
 if not ok or taken~=true then return self:Print('Travel guidance unavailable. Leave combat and check Shortest Path journey settings.') end
 self.routePaused=true;self.dirty=true
 self:Print('Shortest Path is guiding the trip. Use Load selected when ready to farm.')
end
