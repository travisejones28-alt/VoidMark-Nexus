local N,test,eq,widget=...
-- Route planner: OpenMap land outlines, route options, learning from picks and laps, preview.

test('OpenMap land outlines: every baked zone decodes, Durotar coast is not land',function()
 local zones=0; for map in pairs(N.zoneLand.land) do zones=zones+1; assert(N:HasLand(map)) end
 assert(zones>=40,'zones '..zones)
 assert(not N:HasLand(999999)); eq(N:OnLand(999999,.5,.5),nil); eq(N:LegOffLand(999999,0,0,1,1),0)
 -- Durotar: inland near the middle, open sea at the far right edge of the map.
 local inland=0; for x=.40,.56,.02 do if N:OnLand(1411,x,.45) then inland=inland+1 end end
 assert(inland>=4,'Durotar inland cells '..inland)
 eq(N:OnLand(1411,.99,.5),false)
 assert(N:LegOffLand(1411,.45,.45,.99,.45)>.2,'leg out to sea counts as off land')
 assert(N:LegOffLand(1411,.48,.45,.50,.46)<.2)
end)

test('Route options: different loops here plus other zones, ranked, one recommended',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode,s.routeMinutes}
 s.kind,s.target,s.routeSelectionMode,s.routeMinutes='herb','','herb',20
 N.db.routeHistory={}
 local list=assert(N:RouteOptions())
 assert(#list>=3,'options '..#list)
 local here,other,variants=0,0,{}
 for i,o in ipairs(list) do
  assert(o.route and #o.route.points>=3 and o.rate>0 and o.rank==i)
  if o.here then here=here+1; variants[o.variant]=true else other=other+1 end
  if i>1 then assert(list[i-1].score>=o.score,'sorted by score') end
 end
 assert(here>=2 and variants.balanced and variants.quick,'variants here')
 assert(list[1].recommended); for i=2,#list do assert(not list[i].recommended) end
 -- Quick is shorter than balanced, long is longer (when both exist).
 local by={}; for _,o in ipairs(list) do if o.here then by[o.variant]=o.route end end
 assert(by.quick.seconds<by.balanced.seconds)
 if by.long then assert(by.long.seconds>by.balanced.seconds) end
 -- Every here-loop has its off-land share measured (Durotar has an outline).
 assert(by.balanced.offLand~=nil)
 -- Lines and reasons are plain text.
 local line=N:RouteOptionLine(list[1]); assert(line:find('nodes/hr',1,true) and line:sub(1,2)=='* ',line)
 assert(N:RouteOptionWhy(list[1]):find('Estimate',1,true))
 s.kind,s.target,s.routeSelectionMode,s.routeMinutes=saved[1],saved[2],saved[3],saved[4]
end)

test('Stay on land: the land-aware loop crosses less water than the plain one',function()
 -- Two clusters on land with the sea between them on the straight line: on Durotar's outline,
 -- find a pair of land cells whose straight leg crosses non-land, and a land path around.
 local nodes,pair={},nil
 for y1=.30,.70,.05 do for x1=.30,.60,.03 do for x2=.35,.75,.03 do
  if not pair and N:OnLand(1411,x1,y1) and N:OnLand(1411,x2,y1+.02) and N:LegOffLand(1411,x1,y1,x2,y1+.02)>.3 then pair={x1,y1,x2,y1+.02} end
 end end end
 assert(pair,'Durotar has a bay to cross')
 for i=0,4 do nodes[#nodes+1]={x=pair[1]+i*.004,y=pair[2]+i*.004,name='Peacebloom'}; nodes[#nodes+1]={x=pair[3]+i*.004,y=pair[4]+i*.004,name='Peacebloom'} end
 local start={x=pair[1],y=pair[2]}
 local plain=assert(N:BuildZoneLoop(1411,nodes,start,nil,{minutes=60}))
 local land=assert(N:BuildZoneLoop(1411,nodes,start,nil,{minutes=60,landPenalty=4}))
 assert(plain.offLand>0,'plain loop crosses the bay')
 assert(plain.offLand and land.offLand)
 assert(land.offLand<=plain.offLand+1e-9,string.format('land %.3f plain %.3f',land.offLand,plain.offLand))
 -- The cost hook is reset after a build: a plain build again matches the first.
 local again=N:BuildZoneLoop(1411,nodes,start,nil,{minutes=60}); eq(again.length,plain.length)
end)

test('Learning: picks and laps are logged and move the ranking toward what really worked',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode}
 s.kind,s.target,s.routeSelectionMode='herb','','herb'
 N.db.routeHistory={}
 local list=assert(N:OpenRoutePlanner())
 assert(N.routePreview and N.routePreview:IsShown())
 -- Pick the quick loop.
 local qi; for i,o in ipairs(list) do if o.here and o.variant=='quick' then qi=i end end
 assert(qi,'quick option')
 N.routeSelected=qi; N:DrawRoutePreview(); N.routePreview.start.scripts.OnClick()
 local h=N:RouteHistory(); eq(#h.picks,1); eq(h.picks[1].variant,'quick'); eq(h.picks[1].rank,qi)
 assert(N.activeRoute and N.activeRoute.variant=='quick'); assert(not N.routePreview:IsShown())
 -- Two great laps on it.
 for _=1,2 do
  N.lapStats={started=N:Now()-300,visited=20,picked=40,empty=2}
  N:FinishLap()
 end
 local st=N:RouteStat(1411,'quick'); eq(st.laps,2); eq(st.picked,80); eq(st.picks,1)
 eq(h.picks[1].laps,2)
 -- 40 nodes per 5-minute lap = 480/hr: quick now outranks everything here and says why.
 local again=assert(N:RouteOptions())
 eq(again[1].variant,'quick'); assert(again[1].recommended)
 assert(again[1].real and math.abs(again[1].real-480)<1,tostring(again[1].real))
 assert(N:RouteOptionWhy(again[1]):find('You got 480 nodes/hr over 2 laps',1,true),N:RouteOptionWhy(again[1]))
 -- Junk laps are ignored.
 N.lapStats={started=N:Now()-5,picked=99,empty=0}; N:FinishLap(); eq(N:RouteStat(1411,'quick').laps,2)
 -- Chat summary.
 local printed={}; local p=N.Print; N.Print=function(_,m) printed[#printed+1]=m end
 N:RouteLogCommand(); assert(printed[1]:find('quick: picked 1 time, 2 laps, 480 nodes/hr',1,true),printed[1]); N.Print=p
 N:StopRoute(); N.db.routeHistory={}
 s.kind,s.target,s.routeSelectionMode=saved[1],saved[2],saved[3]
end)

test('Preview: draws the zone art and the loop; OpenMap tiles when OpenMap is loaded',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode}
 s.kind,s.target,s.routeSelectionMode='herb','','herb'
 -- Without OpenMap: Blizzard's zone art grid.
 local oldMap=C_Map
 C_Map=setmetatable({GetMapArtLayers=function(map) if map==947 then return {{layerWidth=1002,layerHeight=668}} end return {{layerWidth=1002,layerHeight=668,tileWidth=256,tileHeight=256}} end,
  GetMapArtLayerTextures=function() local t={} for i=1,12 do t[i]=1000+i end return t end,
  GetMapRectOnMap=function() return .55,.65,.40,.55 end,GetMapInfo=function(m) return {name='Zone '..m} end},{__index=oldMap})
 local tiles=N:ZoneArtTiles(1411,360,240); eq(tiles.source,'game map'); eq(#tiles,12)
 eq(tiles[2].x,256*360/1002)
 -- With OpenMap loaded: its baked tiles covering the zone's world rectangle.
 local oldLoaded=IsAddOnLoaded; IsAddOnLoaded=function(name) return name=='OpenMap' end
 local om=N:ZoneArtTiles(1411,360,240); eq(om.source,'OpenMap'); assert(#om>0)
 assert(om[1].file:find('OpenMap\\Media\\Textures\\Forever\\MapZones\\',1,true),om[1].file)
 for _,t in ipairs(om) do assert(t.x<360 and t.y<240 and t.x+t.w>0 and t.y+t.h>0,'tile overlaps the canvas') end
 -- Non-English clients fall back (the baked art has English names on it).
 local oldLocale=GetLocale; GetLocale=function() return 'deDE' end
 eq(N:ZoneArtTiles(1411,360,240).source,'game map'); GetLocale=oldLocale
 -- Drawing: one line per leg, a dot per stop plus you, and the option rows.
 local list=assert(N:OpenRoutePlanner()); local f=N.routePreview; local c=f.canvas
 local n=#list[1].route.points
 local shown=0; for _,l in ipairs(c.lines) do if l:IsShown() then shown=shown+1 end end; eq(shown,n)
 local dots=0; for _,d in ipairs(c.dots) do if d:IsShown() then dots=dots+1 end end; eq(dots,n+(list[1].route.map==1411 and 1 or 0))
 eq(f.source.text,'Map: OpenMap')
 assert(f.rows[1].text.text:find('nodes/hr',1,true)); eq(f.rows[#list+1] and f.rows[#list+1]:IsShown() or false,false)
 -- Clicking another option redraws for it.
 f.rows[2].scripts.OnClick(); eq(N.routeSelected,2)
 f.cancel.scripts.OnClick(); assert(not f:IsShown()); eq(N.routeOptions,nil)
 IsAddOnLoaded=oldLoaded; C_Map=oldMap
 s.kind,s.target,s.routeSelectionMode=saved[1],saved[2],saved[3]
end)

test('Gather > Start route opens the options instead of starting blind; /vmn route now still starts',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode}
 s.kind,s.target,s.routeSelectionMode='herb','','herb'
 N.activeRoute=nil; N:Show('Gather'); N.ui.start.scripts.OnClick()
 assert(N.routePreview:IsShown() and not N.activeRoute)
 N.routePreview:Hide(); N.routeOptions=nil
 N:Slash('route now'); assert(N.activeRoute)
 N:StopRoute()
 s.kind,s.target,s.routeSelectionMode=saved[1],saved[2],saved[3]
end)

test('Other zones arrive a moment after the window opens, keeping your selection',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode}
 s.kind,s.target,s.routeSelectionMode='herb','','herb'
 local oldTimer=C_Timer; local pending={}
 C_Timer={After=function(_,fn) pending[#pending+1]=fn end,NewTicker=function() end}
 local list=assert(N:OpenRoutePlanner())
 for _,o in ipairs(list) do assert(o.here,'only this zone at first') end
 assert(N.routePreview.why.text:find('Looking at other zones',1,true))
 local here=#list; N.routeSelected=2; local chosen=list[2]
 eq(#pending,1); pending[1]()
 assert(#N.routeOptions>here,'other zones added')
 eq(N.routeOptions[N.routeSelected],chosen)
 local recommended=0; for _,o in ipairs(N.routeOptions) do if o.recommended then recommended=recommended+1 end end; eq(recommended,1)
 C_Timer=oldTimer; N.routePreview:Hide(); N.routeOptions=nil
 s.kind,s.target,s.routeSelectionMode=saved[1],saved[2],saved[3]
end)

test('Zone button: build routes in a picked zone, or switch back to the current zone',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode,s.routeZone}
 s.kind,s.target,s.routeSelectionMode,s.routeZone='herb','','herb',nil
 N:Show('Gather'); N:Render(); eq(N.ui.zones.text,'Zone: Current')
 -- The menu lists Current zone first, then zones with spots.
 local captured; local choice=N.Choice
 N.Choice=function(_,_,options,fn) captured={options=options,fn=fn} end
 N.ui.zones.scripts.OnClick()
 eq(captured.options[1].value,0); assert(#captured.options>=3)
 local other; for i=2,#captured.options do if captured.options[i].value~=1411 then other=captured.options[i].value; break end end
 assert(other,'another zone listed')
 captured.fn(other); eq(s.routeZone,other)
 N:Render(); assert(N.ui.zones.text~='Zone: Current'); assert(N.ui.gatherInfo.text:find('Routes will be in ',1,true),N.ui.gatherInfo.text)
 -- Options are all in the picked zone; no extra zones; nothing claims you are there.
 local list=assert(N:RouteOptions())
 for _,o in ipairs(list) do eq(o.map,other); eq(o.here,false) end
 assert(#list>=2)
 local opened=assert(N:OpenRoutePlanner()); for _,o in ipairs(opened) do eq(o.map,other) end
 N.routePreview:Hide(); N.routeOptions=nil
 -- Quick start goes there too.
 local r=assert(N:GenerateRoute()); eq(r.map,other); N:StopRoute()
 -- Back to current.
 captured.fn(0); eq(s.routeZone,nil); N:Render(); eq(N.ui.zones.text,'Zone: Current')
 local back=assert(N:RouteOptions(false)); eq(back[1].map,1411); eq(back[1].here,true)
 N.Choice=choice
 s.kind,s.target,s.routeSelectionMode,s.routeZone=saved[1],saved[2],saved[3],saved[4]
end)
