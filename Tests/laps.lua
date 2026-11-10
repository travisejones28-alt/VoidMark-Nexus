local N,test,eq,widget=...
-- 0.6: spot learning, lap stats, measured speed, re-plan, gold routes, combat hide.

local function at(x,y) N.Position=function() return 1411,x,y end end
local function gather(spell) for _,fn in ipairs(N.handlers.UNIT_SPELLCAST_SUCCEEDED) do fn('player','cast',spell or 2366) end end
local function loop(points)
 local route={map=1411,width=5000,height=3000,loop=true,arriveRadius=25,points=points}
 N.activeRoute=route;N.waypoint=1;N.terrainIndex=1;N.routePaused=false;N.lap=1
 N:ResetLoopTracking();N.db.settings.routeVisible=true;N.db.settings.manualStops=false
 return route
end

test('Spot learning: picked spots count up, empty ones down, five empties drop a spot',function()
 N.db.spots={}
 N:RecordSpot(1411,.5,.5,'picked'); local e=N:SpotEvidence(1411,.5,.5); eq(e.picked,1); eq(e.empty,0)
 assert(N:SpotFactor(e)>1,'picked spot is favoured')
 for _=1,4 do N:RecordSpot(1411,.6,.6,'empty') end
 local f=N:SpotFactor(N:SpotEvidence(1411,.6,.6)); assert(f>0 and f<1,'demoted, not dropped yet')
 N:RecordSpot(1411,.6,.6,'empty'); eq(N:SpotFactor(N:SpotEvidence(1411,.6,.6)),0)
 -- A find halves the old misses.
 N:RecordSpot(1411,.6,.6,'picked'); e=N:SpotEvidence(1411,.6,.6); eq(e.picked,1); eq(e.empty,2)
 N.db.settings.learnSpots=false; N:RecordSpot(1411,.7,.7,'picked'); eq(N:SpotEvidence(1411,.7,.7),nil)
 N.db.settings.learnSpots=true; N.db.spots={}
end)

test('Visits: arrive and gather = picked; arrive and leave = empty; a manual skip records nothing',function()
 local old=N.Position; N.db.spots={}
 local P={{x=.4,y=.4,name='A'},{x=.5,y=.4,name='B'},{x=.6,y=.4,name='C'},{x=.7,y=.4,name='D'}}
 loop(P); N:ShowArrow()
 at(.4,.4); N:UpdateArrow(); eq(N.waypoint,1)          -- reached A (stays while you look)
 gather(); eq(N:SpotEvidence(1411,.4,.4).picked,1); eq(N.waypoint,2) -- picked A, on to B
 at(.5,.4); N:UpdateArrow(); eq(N.waypoint,2)          -- reached B, nothing gathered
 at(.6,.4); N:UpdateArrow(); eq(N.waypoint,3)          -- walked off B
 N:UpdateArrow(); eq(N.waypoint,3)                     -- reached C: B closes as empty
 eq(N:SpotEvidence(1411,.5,.4).empty,1)
 N:SkipWaypoint('left'); N:SkipWaypoint()               -- leave C, manual skip past D
 eq(N:SpotEvidence(1411,.7,.4),nil)
 eq(N.lapStats,nil); eq(N.lastLap.picked,1); eq(N.lastLap.visited,3)
 assert(#N.db.laps>=1 and N.db.laps[#N.db.laps].picked==1)
 assert(N:LapLine(N.lastLap,'Last lap: '):find('1 picked',1,true))
 N.Position=old; N:StopRoute(); N.db.spots={}
end)

test('Rebuilt loops drop always-empty spots and favour picked ones',function()
 local s=N.db.settings; local saved={s.kind,s.routeSelectionMode}; s.kind,s.routeSelectionMode='herb','herb'
 N.db.spots={}
 local nodes={}
 for i=0,9 do nodes[#nodes+1]={x=.30+i*.02,y=.5,name='Peacebloom',kind='herb'} end
 local base=N:BuildZoneLoop(1411,nodes,{x=.3,y=.5}); eq(#base.points,10)
 for _=1,5 do N:RecordSpot(1411,.36,.5,'empty') end
 N:RecordSpot(1411,.40,.5,'picked')
 local route=N:BuildZoneLoop(1411,nodes,{x=.3,y=.5}); eq(#route.points,9); eq(N.lastDroppedSpots,1)
 local found; for _,p in ipairs(route.points) do assert(math.abs(p.x-.36)>.001,'dead spot kept'); if math.abs(p.x-.40)<.001 then found=p end end
 eq(found.picked,1)
 s.learnSpots=false; route=N:BuildZoneLoop(1411,nodes,{x=.3,y=.5}); eq(#route.points,10); s.learnSpots=true
 N.db.spots={}; s.kind,s.routeSelectionMode=saved[1],saved[2]
end)

test('Measured speed: real movement replaces the fixed speed in the arrow',function()
 local old=N.Position
 loop({{x=.9,y=.4,name='Far'}}); N.measuredSpeed=nil; N.speedSample=nil
 at(.400,.4); N:SampleSpeed(1)
 at(.4028,.4); N:SampleSpeed(1)              -- 14 yd in 1 s (5000 yd wide map)
 assert(math.abs(N.measuredSpeed-14)<.01)
 at(.4028,.4); N:SampleSpeed(1); assert(math.abs(N.measuredSpeed-14)<.01,'standing still is ignored')
 at(.8,.4); N:SampleSpeed(1); assert(math.abs(N.measuredSpeed-14)<.01,'teleports are ignored')
 eq(N:TravelSpeed(N.activeRoute),N.measuredSpeed)
 N:ShowArrow(); at(.4,.4); N:UpdateArrow()
 eq(N.arrow.eta.text,string.format('~%.0f sec',2500/N.measuredSpeed))
 N.measuredSpeed=nil; eq(N:TravelSpeed({speed=9}),9)
 N.Position=old; N:StopRoute()
end)

test('Gold routes weight by price and skip what you cannot gather yet',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode,s.manualFirst}
 local profs=N.character.professions
 N.character.professions={['182']={name='Herbalism',skill=60,max=150}}
 s.kind,s.target,s.routeSelectionMode,s.manualFirst='herb','','gold',true
 N:SetPrice(2447,.1)   -- Peacebloom
 N:SetPrice(785,.5)    -- Mageroyal
 local w={}; for _,n in ipairs(N:ZoneNodes(1411)) do w[n.name]=n.skillPriority end
 eq(w.Mageroyal,1); assert(math.abs(w.Peacebloom-.2)<1e-9); eq(w.Briarthorn,nil) -- 70 > 60
 eq(N:ResourceLabel(),'Herbs for gold')
 N.character.professions=profs; s.kind,s.target,s.routeSelectionMode,s.manualFirst=saved[1],saved[2],saved[3],saved[4]
end)

test('Skill-up loops rebuild when a herb turns grey or a new one unlocks',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode}
 local profs=N.character.professions; local oldScan=N.ScanProfessions
 s.kind,s.target,s.routeSelectionMode='herb','','skillup'
 N.character.professions={['182']={name='Herbalism',skill=60,max=150}}
 local scans=0
 local route=N:GenerateRoute(); assert(route and route.resourceKey:find('Mageroyal',1,true))
 eq(N.activeRoute,route)
 N.character.professions['182'].skill=61; N:CheckReplan(); eq(N.activeRoute,route) -- same herbs: keep
 N.character.professions['182'].skill=116                                       -- Peacebloom and Silverleaf go grey
 N:CheckReplan(); assert(N.activeRoute~=route,'rebuilt')
 assert(not N.activeRoute.resourceKey:find('Peacebloom',1,true))
 N:StopRoute(); N.character.professions=profs; N.ScanProfessions=oldScan
 s.kind,s.target,s.routeSelectionMode=saved[1],saved[2],saved[3]
end)


test('/vmn spots and /vmn laps report and forget',function()
 N.db.spots={}; N:RecordSpot(1411,.5,.5,'picked'); for _=1,5 do N:RecordSpot(1411,.6,.6,'empty') end
 local said; local p=N.Print; N.Print=function(_,m) said=m end
 SlashCmdList.VOIDMARKNEXUS('spots'); assert(said:find('2 spots learned',1,true) and said:find('1 skipped',1,true),said)
 SlashCmdList.VOIDMARKNEXUS('spots forget'); eq(N.db.spots[1411],nil)
 N.lastLap,N.lapStats=nil,nil; SlashCmdList.VOIDMARKNEXUS('laps'); eq(said,'No laps yet.')
 N.Print=p
end)

test('Zone loops stay on a stop while you look, then move on when you gather or walk away',function()
 local old=N.Position; N.db.spots={}
 loop({{x=.4,y=.4,name='A'},{x=.5,y=.4,name='B'},{x=.6,y=.4,name='C'}}); N:ShowArrow()
 at(.4,.4); N:UpdateArrow(); eq(N.waypoint,1); eq(N.lingerAt,1)        -- arrived at A: still A
 assert(N.arrow.status.text:find('look around',1,true))
 at(.403,.4); N:UpdateArrow(); eq(N.waypoint,1)                      -- 15 yd off, looking: still A
 gather(); eq(N.waypoint,2); eq(N:SpotEvidence(1411,.4,.4).picked,1) -- gathered: on to B
 at(.5,.4); N:UpdateArrow(); eq(N.waypoint,2); eq(N.lingerAt,2)
 at(.51,.4); N:UpdateArrow(); eq(N.waypoint,3)                       -- 50 yd away: B left empty
 at(.6,.4); N:UpdateArrow(); eq(N:SpotEvidence(1411,.5,.4).empty,1)
 eq(N.lapStats.picked,1)
 N.Position=old; N:StopRoute(); eq(N.lingerAt,nil); N.db.spots={}
end)
