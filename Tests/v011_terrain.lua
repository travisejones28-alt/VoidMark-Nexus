local N,test,eq,widget=...
-- 0.11 Priority 1: terrain-aware zone loops.
local MAP,W,H=1411,5000,3000
local saved={}
local function isolate()
 saved.terrain=N.db.terrain;saved.blocks=N.db.terrainBlocks;saved.spots=N.db.spots
 N.db.terrain={version=1,zones={}};N.db.terrainBlocks={};N.db.spots={};N.terrainGraph=nil
end
local function restore()
 N.db.terrain=saved.terrain;N.db.terrainBlocks=saved.blocks;N.db.spots=saved.spots;N.terrainGraph=nil
end
-- A corridor as recorded by Terrain.lua, walked in both directions.
local function corridor(list,samples)
 local z={points={},edges={},edgeCount=0,revision=1}
 for i,p in ipairs(list) do z.points[i]={x=p[1],y=p[2]} end
 for i=1,#list-1 do
  local a,b=z.points[i],z.points[i+1]
  local d=math.sqrt(((a.x-b.x)*W)^2+((a.y-b.y)*H)^2)
  z.edges[i]=z.edges[i] or {}; z.edges[i][i+1]={distance=d,seconds=d/7,speed=7,samples=samples or 2,mode='ground'}
  z.edges[i+1]=z.edges[i+1] or {}; z.edges[i+1][i]={distance=d,seconds=d/7,speed=7,samples=samples or 2,mode='ground'}
  z.edgeCount=z.edgeCount+2
 end
 N.db.terrain.zones[MAP]=z
 return z
end
-- U-shaped walk from A (.40,.40) down, across and up to B (.44,.40): 380 yards vs 200 direct.
local U={{.40,.40},{.40,.41},{.40,.42},{.40,.43},{.41,.43},{.42,.43},{.43,.43},{.44,.43},{.44,.42},{.44,.41},{.44,.40}}
local nodes={{x=.40,y=.40,name='Peacebloom',kind='herb'},{x=.44,y=.40,name='Peacebloom',kind='herb'},{x=.42,y=.30,name='Silverleaf',kind='herb'}}
local function legBetween(route,ax,bx)
 for i,p in ipairs(route.points) do
  local q=route.points[i%#route.points+1]
  if math.abs(p.x-ax)<.001 and math.abs(q.x-bx)<.001 and math.abs(p.y-.40)<.001 and math.abs(q.y-.40)<.001 then return route.legs and route.legs[i],i end
 end
end

test('0.11 terrain: a zone with no trails or marks builds the same plain loop',function()
 isolate()
 local route=N:BuildZoneLoop(MAP,nodes,{x=.40,y=.40})
 eq(route.legs,nil); eq(route.optimizer,'zoneloop-v2'); eq(route.verifiedShare,0)
 restore()
end)

test('0.11 terrain: a corridor walked repeatedly replaces the straight leg and is marked verified',function()
 isolate(); corridor(U,2)
 local route=N:BuildZoneLoop(MAP,nodes,{x=.40,y=.40})
 assert(route.legs,'legs annotated')
 local leg=legBetween(route,.40,.44)
 if not leg then leg=legBetween(route,.44,.40) end
 assert(leg,'A-B leg present')
 eq(leg.kind,'learned'); assert(#leg.via>=9,'trail points kept')
 local validated=0; for _,v in ipairs(leg.via) do if v.validated then validated=validated+1 end end
 assert(validated>=8,'walked points are verified'); assert(leg.length>350 and leg.length<420,'uses the walked length, not 200 yd')
 assert(route.verifiedShare>0 and route.verifiedShare<1)
 assert(N:LoopTerrainSummary(route):find('learned trails',1,true))
 restore()
end)

test('0.11 terrain: a long corridor walked once is not trusted over the straight line',function()
 isolate(); corridor(U,1)
 local route=N:BuildZoneLoop(MAP,nodes,{x=.40,y=.40})
 for _,l in ipairs(route.legs or {}) do assert(l.kind~='learned','single long walk ignored (1.9x > 1.5x)') end
 restore()
end)

test('0.11 terrain: a corridor close to straight is used even after one walk',function()
 isolate(); corridor({{.40,.40},{.41,.401},{.42,.402},{.43,.401},{.44,.40}},1)
 local route=N:BuildZoneLoop(MAP,nodes,{x=.40,y=.40})
 local leg=legBetween(route,.40,.44) or legBetween(route,.44,.40); assert(leg and leg.kind=='learned')
 restore()
end)

test('0.11 terrain: a marked obstacle forces an estimated detour, never a straight line through it',function()
 isolate(); N.db.terrainBlocks[MAP]={{x=.42,y=.40,r=40}}
 local route=N:BuildZoneLoop(MAP,nodes,{x=.40,y=.40})
 local leg=legBetween(route,.40,.44) or legBetween(route,.44,.40)
 assert(leg,'leg found'); eq(leg.kind,'detour'); assert(#leg.via>0)
 for _,v in ipairs(leg.via) do assert(not v.validated,'detours are estimates') end
 assert(leg.length>200,'longer than the blocked straight line')
 for _,v in ipairs(leg.via) do
  local dx,dy=(v.x-.42)*W,(v.y-.40)*H; assert(dx*dx+dy*dy>=40*40,'detour stays outside the mark')
 end
 restore()
end)

test('0.11 terrain: the arrow follows trail points of the current leg, then the stop',function()
 isolate(); corridor(U,2)
 local route=N:BuildZoneLoop(MAP,nodes,{x=.40,y=.40})
 local _,i=legBetween(route,.40,.44); if not i then _,i=legBetween(route,.44,.40) end
 N:StartRoute(route,true); N.waypoint=i; N.db.settings.routeVisible=true; N.db.settings.manualStops=false
 N:SkipWaypoint(); eq(N.waypoint,i%#route.points+1)
 local via=N:LoopViaTarget(route); assert(via and via.loopVia,'heading for the first trail point')
 local first=route.legs[i].via[1]; eq(via.x,first.x)
 -- Stand on the second trail point: the arrow moves along the trail.
 local old=C_Map.GetPlayerMapPosition
 local px,py=route.legs[i].via[2].x,route.legs[i].via[2].y
 C_Map.GetPlayerMapPosition=function() return {GetXY=function() return px,py end} end
 N:ShowArrow(); N:UpdateArrow(); assert(N.loopLeg.i>=2,'advanced along the trail')
 eq(N.arrow.status.text,'Learned trail')
 -- Walk the rest of it.
 for _=1,20 do local v=N:LoopViaTarget(route); if not v then break end; px,py=v.x,v.y; N:UpdateArrow() end
 eq(N:LoopViaTarget(route),nil)
 C_Map.GetPlayerMapPosition=old
 N:StopRoute(); restore()
end)

test('0.11 terrain: world map ring draws trail points between stops without extra pins',function()
 isolate(); corridor(U,2)
 local route=N:BuildZoneLoop(MAP,nodes,{x=.40,y=.40})
 N:StartRoute(route,true); N.waypoint=1
 local ring=N:LoopRing(route,1); local stops,via=0,0
 for _,r in ipairs(ring) do if r.stop then stops=stops+1 else via=via+1 end end
 eq(stops,#route.points); assert(via>=9)
 local canvas=WorldMapFrame:GetCanvas()
 canvas.CreateLine=function() local l=widget(); return l end
 N.mapRouteLines={}; N.db.settings.routeVisible=true
 N:RefreshMap()
 local shown=0; for _,l in ipairs(N.mapRouteLines) do if l:IsShown() then shown=shown+1 end end
 eq(shown,#ring-1)
 N:StopRoute(); restore()
end)

test('0.11 terrain: trail learning is switched back on once, and stays off if you turn it off',function()
 local s=N.db.settings
 s.terrain011=nil; s.terrainLearn=false; N:Initialize(); eq(N.db.settings.terrainLearn,true)
 N.db.settings.terrainLearn=false; N:Initialize(); eq(N.db.settings.terrainLearn,false)
 N.db.settings.terrainLearn=true
end)

test('0.11 terrain: full-size trail graph on real Durotar herbs stays fast',function()
 isolate()
 -- 600 points on a 25 x 24 lattice, ~2300 directed edges (the saved-data caps).
 local z={points={},edges={},edgeCount=0,revision=7}
 for r=0,23 do for c=0,24 do z.points[#z.points+1]={x=.425+c*.006,y=.38+r*.01} end end
 local function id(r,c) return r*25+c+1 end
 local function add(a,b) local p,q=z.points[a],z.points[b]; local d=math.sqrt(((p.x-q.x)*W)^2+((p.y-q.y)*H)^2)
  z.edges[a]=z.edges[a] or {}; z.edges[a][b]={distance=d,seconds=d/7,speed=7,samples=3,mode='ground'}; z.edgeCount=z.edgeCount+1 end
 for r=0,23 do for c=0,24 do
  if c<24 then add(id(r,c),id(r,c+1)); add(id(r,c+1),id(r,c)) end
  if r<23 then add(id(r,c),id(r+1,c)); add(id(r+1,c),id(r,c)) end
 end end
 N.db.terrain.zones[MAP]=z
 local s=N.db.settings; local keep={s.kind,s.routeSelectionMode}; s.kind,s.routeSelectionMode='herb','herb'
 local t=os.clock()
 local route=N:BuildZoneLoop(MAP,N:ZoneNodes(MAP),{x=.5,y=.5})
 local spent=os.clock()-t
 print(string.format('BENCH terrain zone loop: %.3f CPU sec, %d stops, %.0f%% verified',spent,#route.points,(route.verifiedShare or 0)*100))
 assert(route.legs and #route.legs==#route.points); assert(route.verifiedShare>0,'some legs on the lattice')
 assert(spent<3,'bounded build time')
 s.kind,s.routeSelectionMode=keep[1],keep[2]
 restore()
end)
