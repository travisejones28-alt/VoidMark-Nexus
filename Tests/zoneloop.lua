local N,test,eq,setNow,widget=...
local function crossings(route)
 local P,n,w,h=route.points,#route.points,route.width,route.height;local c=0
 local function ccw(ax,ay,bx,by,cx,cy) return (cy-ay)*(bx-ax)>(by-ay)*(cx-ax) end
 for i=1,n do for j=i+2,n do if not (i==1 and j==n) then
  local a,b,cc,d=P[i],P[i%n+1],P[j],P[j%n+1]
  if ccw(a.x*w,a.y*h,cc.x*w,cc.y*h,d.x*w,d.y*h)~=ccw(b.x*w,b.y*h,cc.x*w,cc.y*h,d.x*w,d.y*h)
   and ccw(a.x*w,a.y*h,b.x*w,b.y*h,cc.x*w,cc.y*h)~=ccw(a.x*w,a.y*h,b.x*w,b.y*h,d.x*w,d.y*h) then c=c+1 end
 end end end
 return c
end
test('Zone loop: spawns close together become one stop; far ones stay separate',function()
 local nodes={{x=.100,y=.100,name='Peacebloom'},{x=.104,y=.100,name='Peacebloom'},{x=.100,y=.105,name='Silverleaf'},{x=.200,y=.200,name='Earthroot'}}
 local stops=N:ClusterStops(nodes,5000,3000)
 eq(#stops,2); eq(stops[1].count,3); eq(stops[1].name,'Peacebloom +1'); eq(stops[2].count,1)
end)
test('Zone loop: a lonely far-away stop is dropped',function()
 local stops={}
 for i=0,9 do stops[#stops+1]={x=1000+i*60,y=1000,weight=1} end
 stops[#stops+1]={x=4500,y=2800,weight=1}
 local kept=N:DropOutliers(stops); eq(#kept,10)
end)
test('Zone loop on real Durotar herbs: instant, no crossing paths, starts next to you',function()
 local s=N.db.settings; local saved={s.kind,s.target,s.routeSelectionMode}
 s.kind,s.target,s.routeSelectionMode='herb','','herb'
 local nodes=N:ZoneNodes(1411); assert(#nodes>50)
 local here={x=.5,y=.5}
 local route=N:BuildZoneLoop(1411,nodes,here)
 assert(route and route.loop and #route.points>=10)
 eq(crossings(route),0)
 assert(route.seconds<=s.routeMinutes*60*1.15,'lap fits the time limit')
 local w,h=route.width,route.height
 local function d(p) return math.sqrt(((p.x-here.x)*w)^2+((p.y-here.y)*h)^2) end
 for _,p in ipairs(route.points) do assert(d(route.points[1])<=d(p)+.001,'first stop is the nearest') end
 -- Better than a plain nearest-neighbour ordering of the same stops.
 local stops={};for _,p in ipairs(route.points) do stops[#stops+1]={x=p.x*w,y=p.y*h} end
 local nn,left,cur={},{},stops[1];for i=2,#stops do left[#left+1]=stops[i] end;nn[1]=cur
 while #left>0 do local bi,bd=1,math.huge;for i,q in ipairs(left) do local dd=(q.x-cur.x)^2+(q.y-cur.y)^2;if dd<bd then bi,bd=i,dd end end;cur=table.remove(left,bi);nn[#nn+1]=cur end
 assert(route.length<=N.LoopLength(nn)+.01)
 s.kind,s.target,s.routeSelectionMode=saved[1],saved[2],saved[3]
end)
test('Zone loop: Start route is immediate and the loop wraps into a new lap',function()
 local s=N.db.settings; local saved={s.kind,s.routeSelectionMode}; s.kind,s.routeSelectionMode='herb','herb'
 N.activeRoute=nil;N.planningThread=nil
 local route=N:GenerateRoute(); assert(route and N.activeRoute==route and not N.planningThread,'no planner job')
 local n=#route.points; N.waypoint=n; N.lap=1
 N:SkipWaypoint(); eq(N.waypoint,1); eq(N.lap,2); assert(N.activeRoute,'loop keeps going')
 s.kind,s.routeSelectionMode=saved[1],saved[2]
end)
test('Zone loop: the arrow advances within 25 yards, and gathering near a stop advances too',function()
 local route={map=1411,width=5000,height=3000,loop=true,arriveRadius=25,points={{x=.4,y=.4,name='A'},{x=.6,y=.6,name='B'},{x=.4,y=.6,name='C'}}}
 N.activeRoute=route;N.waypoint=1;N.terrainIndex=1;N.routePaused=false;N.db.settings.routeVisible=true;N.db.settings.manualStops=false
 N:ShowArrow()
 -- Player is at (0.4,0.4) in the test position stub: within 25 yd of stop A.
 N:UpdateArrow(); eq(N.waypoint,2)
 route.points[2]={x=.402,y=.401,name='B near'}
 for _,fn in ipairs(N.handlers.UNIT_SPELLCAST_SUCCEEDED) do fn('player','cast',2366) end
 eq(N.waypoint,3)
 route.points[3]={x=.401,y=.402,name='C near'}
 for _,fn in ipairs(N.handlers.UNIT_SPELLCAST_SUCCEEDED) do fn('player','cast',11993) end -- Artisan rank
 eq(N.waypoint,1)
 N:StopRoute(); eq(N.activeRoute,nil)
end)
test('Zone loop: whole ring is drawn on the world map and the loop survives /reload',function()
 local s=N.db.settings; local saved={s.kind,s.routeSelectionMode}; s.kind,s.routeSelectionMode='herb','herb'
 local route=N:BuildZoneLoop(1411,N:ZoneNodes(1411),{x=.5,y=.5})
 N.activeRoute=route;N.waypoint=3;N.terrainIndex=1;s.routeVisible=true
 local canvas=WorldMapFrame:GetCanvas()
 local function line() local l={};for _,m in ipairs({'SetStartPoint','SetEndPoint','SetThickness','SetTexture','SetVertexColor','SetColorTexture','SetDrawLayer'}) do l[m]=function() end end
  l.Show=function(self) self.shown=true end;l.Hide=function(self) self.shown=false end;l.IsShown=function(self) return self.shown end;return l end
 canvas.CreateLine=function() return line() end
 N.mapRouteLines={}
 N:RefreshMap()
 local shown=0;for _,line in ipairs(N.mapRouteLines or {}) do if line:IsShown() then shown=shown+1 end end
 eq(shown,#route.points-2) -- stops 1-2 reached: legs 3..n plus closing leg to 1
 N:SaveNavigation();N.activeRoute=nil;N:RestoreNavigation()
 assert(N.activeRoute and N.activeRoute.loop,'loop flag kept');eq(N.waypoint,3)
 eq(N.activeRoute.arriveRadius,25);assert(N.activeRoute.points[1].spawns)
 N:StopRoute();N.db.navigation[N.characterID]=nil
 s.kind,s.routeSelectionMode=saved[1],saved[2]
end)
test('Secret event arguments reach handlers as nil instead of erroring',function()
 local secret={}; local oldFn=issecretvalue; issecretvalue=function(v) return v==secret end
 local before=#N.errors
 N.activeRoute={map=1411,width=5000,height=3000,loop=true,points={{x=.4,y=.4,name='A'},{x=.6,y=.6,name='B'}}};N.waypoint=1
 N.eventFrame.scripts.OnEvent(N.eventFrame,'UNIT_SPELLCAST_SUCCEEDED','player','cast',secret)
 N.eventFrame.scripts.OnEvent(N.eventFrame,'UNIT_SPELLCAST_SENT','player','Peacebloom','cast',secret)
 eq(#N.errors,before); eq(N.waypoint,1)
 local got={}; local list=N.handlers.UNIT_SPELLCAST_SUCCEEDED
 list[#list+1]=function(unit,cast,spell) got.unit,got.cast,got.spell,got.seen=unit,cast,spell,true end
 N.eventFrame.scripts.OnEvent(N.eventFrame,'UNIT_SPELLCAST_SUCCEEDED','player','cast',secret)
 table.remove(list)
 assert(got.seen); eq(got.unit,'player'); eq(got.cast,'cast'); eq(got.spell,nil)
 issecretvalue=oldFn; N:StopRoute()
end)

test('Zone loop: reached stops leave the minimap and the next stop hides when close',function()
 local oldPosition,oldMinimap,oldC=N.Position,Minimap,C_Minimap
 C_Minimap={GetViewRadius=function() return 10000 end}
 Minimap=widget();Minimap.GetWidth=function() return 200 end;Minimap.GetHeight=function() return 200 end
 Minimap.GetEffectiveScale=function() return 1 end
 local s=N.db.settings;s.routeVisible=true;s.minimapRoute=true;s.minimapHideNear=40
 local pts={};for i=1,6 do pts[i]={x=.3+i*.02,y=.5,name='P'..i} end
 N.activeRoute={map=1411,width=5000,height=3000,loop=true,points=pts}
 N.minimapRouteOverlay=nil;N.minimapRoutePins=nil
 local function labels()
  local t={};for _,pin in ipairs(N.minimapRoutePins or {}) do if pin:IsShown() then t[#t+1]=pin.stopIndex end end
  table.sort(t);return table.concat(t,',')
 end
 N.Position=function() return 1411,.1,.1 end
 N.waypoint=3;N:UpdateMinimapRoute();eq(labels(),'3,4,5,6')
 -- Standing on stop 3 (0 yd away): its number hides so the node blip is visible.
 N.Position=function() return 1411,pts[3].x,pts[3].y end
 N:UpdateMinimapRoute();eq(labels(),'4,5,6')
 s.minimapHideNear=0;N:UpdateMinimapRoute();eq(labels(),'3,4,5,6')
 N.waypoint=1;s.minimapHideNear=40;N.Position=function() return 1411,.1,.1 end
 N:UpdateMinimapRoute();eq(labels(),'1,2,3,4,5,6')
 N.Position,Minimap,C_Minimap=oldPosition,oldMinimap,oldC;N.activeRoute=nil;N.minimapRouteOverlay=nil
end)
