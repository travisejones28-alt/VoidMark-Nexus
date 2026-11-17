local N,test,eq=...
test('0.13.5 route summary: counts what you gather on a route and prices it on Stop',function()
 N.db.routeHaul=nil; N.activeRoute=nil
 local route={map=1411,points={{x=.4,y=.4,name='Peacebloom'},{x=.5,y=.5,name='Peacebloom'}},width=5000,height=3000,seconds=60,length=100}
 N:StartRoute(route,true)
 assert(N.db.routeHaul,'tally started')
 local price=N.Price; N.Price=function(_,id) if id==2447 then return {unit=150} end end
 N:RouteHaulAdd(2447,3); N:RouteHaulAdd(2447,2); N:RouteHaulAdd(765,4)
 N:StartRoute(route,true) -- rebuild keeps the tally
 eq(N.db.routeHaul.items[2447],5)
 local shown; local td=N.TextDialog; N.TextDialog=function(_,title,text) shown={title=title,text=text} end
 N:StopRoute()
 assert(shown and shown.title=='Route summary','summary shown on stop')
 assert(shown.text:find('5 x',1,true) and shown.text:find(N:Money(750),1,true),'priced line')
 assert(shown.text:find('no price',1,true),'unpriced item listed')
 eq(N.db.routeHaul,nil)
 N:RouteHaulAdd(2447,1); eq(N.db.routeHaul,nil) -- no route: not counted
 N.TextDialog=td; N.Price=price
end)
test('0.13.5 loops: reaching a later stop moves the route on to it',function()
 local pts={}; for i=1,8 do pts[i]={x=.1*i,y=.5,name='Peacebloom'} end
 local route={map=1411,loop=true,points=pts,width=5000,height=3000,arriveRadius=25,seconds=60,length=100}
 N.activeRoute=nil; N:StartRoute(route,true); N.waypoint=4; N.lingerAt=nil
 -- standing at stop 6 (two ahead)
 assert(N:LoopCatchUp(route,.6,.5)); eq(N.waypoint,6); eq(N.lingerAt,6)
 assert(not N:LoopCatchUp(route,.6,.5),'stays while you are at it')
 -- far from everything: nothing changes
 N.lingerAt=nil; assert(not N:LoopCatchUp(route,.65,.9)); eq(N.waypoint,6)
 -- wraps past the last stop into the next lap
 N.waypoint=7; local lap=N.lap or 1; assert(N:LoopCatchUp(route,.1,.5)); eq(N.waypoint,1); eq(N.lap,lap+1)
 local td=N.TextDialog; N.TextDialog=function() end; N:StopRoute(); N.TextDialog=td
end)
test('0.13.6 loops: a detour to a far stop keeps the route; that stop is skipped later this lap',function()
 local pts={}; for i=1,12 do pts[i]={x=.07*i,y=.5,name='Peacebloom'} end
 local route={map=1411,loop=true,points=pts,width=5000,height=3000,arriveRadius=25,seconds=60,length=100}
 N.activeRoute=nil; N:StartRoute(route,true); N.waypoint=3; N.lingerAt=nil
 -- gather at stop 10 (far ahead): the route stays on 3
 eq(N:MarkOffRoutePick(route,pts[10].x,.5),10); eq(N.waypoint,3)
 assert(not N:LoopCatchUp(route,pts[10].x,.55),'standing near 10 does not jump the route')
 eq(N.waypoint,3)
 -- later the route reaches 9, then 10 is passed over automatically
 N.waypoint=10; N.lingerAt=nil; assert(N:LoopCatchUp(route,.5,.95)); eq(N.waypoint,11)
 local td=N.TextDialog; N.TextDialog=function() end; N:StopRoute(); N.TextDialog=td
end)
