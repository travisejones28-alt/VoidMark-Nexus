local N,test,eq,widget=...
-- 0.11 Priorities 2-3: per-route learning, scoring, Market value.
local MAP=1411
local clock=2000000
local realNow=N.Now
local function setNow(t) clock=t; N.Now=function() return clock end end
local function restoreNow() N.Now=realNow end
local function loopRoute(points,map)
 return {map=map or MAP,width=5000,height=3000,loop=true,arriveRadius=25,points=points,length=1000,seconds=600}
end
local A={{x=.40,y=.40,name='Peacebloom'},{x=.45,y=.40,name='Silverleaf'},{x=.45,y=.45,name='Peacebloom'},{x=.40,y=.45,name='Earthroot'}}
local function rotated(list,k,rev)
 local out={}
 for i=1,#list do out[i]=list[(i+k-1)%#list+1] end
 if rev then local r={out[1]}; for i=#out,2,-1 do r[#r+1]=out[i] end; out=r end
 return out
end
local function freshHistory() N.db.routeHistory={} end
-- One lap on the active route: n stops found, items gathered, seconds long.
local function runLap(route,picked,empty,items,seconds,gatherSeconds,partial)
 if N.activeRoute~=route then N:StartRoute(route,true) end
 setNow(clock)
 local lap=N:LapStats(); lap.started=clock
 lap.picked=picked; lap.empty=empty; lap.visited=picked+empty
 for id,q in pairs(items or {}) do N:NoteGatherLoot(id,q,{map=route.map}) end
 if gatherSeconds then N:NoteGatherCast({map=route.map,castSeconds=gatherSeconds}) end
 setNow(clock+seconds)
 if partial then N:StopRoute() else N:FinishLap() end
end

test('0.11 learning: the same stops make the same route whatever the start or direction',function()
 local k1=N:RouteKey(loopRoute(A))
 eq(N:RouteKey(loopRoute(rotated(A,2))),k1)
 eq(N:RouteKey(loopRoute(rotated(A,1,true))),k1)
 local B=rotated(A,0); B[4]={x=.30,y=.45,name='Earthroot'}
 assert(N:RouteKey(loopRoute(B))~=k1,'a different stop is a different route')
end)

test('0.11 learning: each lap records stops, finds, empties, items, gathering and travel time',function()
 freshHistory(); local route=loopRoute(A)
 runLap(route,3,1,{[2447]=6,[765]=2},600,30)
 local r=N:RouteRecords()[N:RouteKey(route)]
 assert(r,'record'); eq(r.laps,1); eq(r.picked,3); eq(r.empty,1); eq(r.visited,4); eq(r.qty,8)
 eq(r.items[2447],6); eq(r.items[765],2); eq(r.seconds,600); eq(r.gatherSeconds,30)
 assert(r.stops:find('0.4000,0.4000',1,true),'stops kept to run it again')
 N:StopRoute(); restoreNow()
end)

test('0.11 learning: different loops in one zone keep separate statistics',function()
 freshHistory()
 local one,two=loopRoute(A),loopRoute({{x=.6,y=.6,name='Copper Vein'},{x=.65,y=.6,name='Copper Vein'},{x=.65,y=.65,name='Copper Vein'}})
 runLap(one,4,0,{[2447]=4},600)
 runLap(two,1,2,{[2770]=2},600)
 local a,b=N:RouteRecords()[N:RouteKey(one)],N:RouteRecords()[N:RouteKey(two)]
 eq(a.picked,4); eq(b.picked,1); eq(a.laps,1); eq(b.laps,1)
 N:StopRoute(); restoreNow()
end)

test('0.11 learning: stopping mid-lap keeps the part after a minute, not before',function()
 freshHistory(); local route=loopRoute(A)
 runLap(route,1,1,{[2447]=2},45,nil,true)
 eq(N:RouteRecords()[N:RouteKey(route)],nil)
 runLap(route,2,1,{[2447]=3},120,nil,true)
 local r=N:RouteRecords()[N:RouteKey(route)]; eq(r.partial,1); eq(r.laps,0); eq(r.picked,2)
 restoreNow()
end)

test('0.11 learning: one lucky lap only nudges the estimate; many laps move it',function()
 freshHistory(); local route=loopRoute(A)
 local base=N:ScoreRoute(route,'balanced')
 eq(base.confidence,'estimate'); eq(base.real,nil)
 runLap(route,4,0,{},300)                     -- 48 nodes/hr
 local one=N:ScoreRoute(route,'balanced')
 assert(one.real>40 and one.real<50); eq(one.confidence,'low')
 local gap=math.abs(one.rate-one.real); assert(gap>math.abs(base.rate-one.real)*.5,'one lap moves it less than halfway')
 for _=1,11 do runLap(route,4,0,{},300) end
 local many=N:ScoreRoute(route,'balanced')
 assert(math.abs(many.rate-many.real)<math.abs(one.rate-one.real),'more laps, closer to what you got')
 assert(many.confidence=='medium' or many.confidence=='good')
 N:StopRoute(); restoreNow()
end)

test('0.11 value: gold/hr uses your loot and prices; missing prices are partial, never zero',function()
 freshHistory(); local route=loopRoute(A)
 local keepMarket=N.db.settings.market; N.db.settings.market=false
 N.prices[2447]=nil; N.prices[765]=nil; N.prices[2449]=nil
 runLap(route,4,0,{[2447]=8,[765]=4},1800)
 eq(N:ScoreRoute(route,'balanced').gold,nil)  -- nothing priced: unknown, not 0
 N:SetPrice(2447,.5)                           -- 50s each; Silverleaf still unpriced
 local s=N:ScoreRoute(route,'balanced')
 assert(s.gold and s.gold>0); assert(s.goldPartial,'flagged partial'); eq(s.goldBasis,'your loot on this loop')
 local line=N:RouteRecordLine(N:RouteKey(route),N:RouteRecords()[N:RouteKey(route)])
 assert(line:find('/hr*',1,true),'line marks unpriced items')
 -- Actual: 8 x 50s in half an hour = 8g/hr.
 eq(math.floor(s.realGold+.5),80000)
 N:SetPrice(765,.2); assert(not N:ScoreRoute(route,'balanced').goldPartial)
 N.db.settings.market=keepMarket
 N:StopRoute(); restoreNow()
end)

test('0.11 value: an unrun route is estimated from its stops at no less than 1 item per node',function()
 freshHistory(); N.db.settings.market=false
 N:SetPrice(2447,1); N:SetPrice(765,1); N:SetPrice(2449,1)
 N.db.gatherEvidence={}
 local route=loopRoute(A)
 local s=N:ScoreRoute(route,'balanced')
 assert(s.gold and s.goldBasis:find('minimum 1',1,true))
 eq(math.floor(s.gold+.5),math.floor(s.rate*10000+.5))
 -- Your own gathers say 2 per Peacebloom node.
 N.db.gatherEvidence={[MAP]={['1618:200:200']={harvests=5,qty=10,checks=0,available=0}}}
 local s2=N:ScoreRoute(route,'balanced')
 assert(s2.goldBasis:find('observed',1,true)); assert(s2.gold>s.gold)
 N.db.gatherEvidence={}; N.db.settings.market=true
end)

test('0.11 value: Market status marks stale and developing prices without changing them',function()
 VoidMarkMarketDB={schemaVersion=1,economies={[N.economy]={market={[2447]={fairValue=500,lastSeen=time()-60,latest={median=500},itemSuffix=0,developingMarket=true}}}}}
 VoidMarkMarket={db={},GetPriceInfo=function(_,id) return {apiVersion=1,status=id==2447 and 'stale' or 'current',itemID=id} end}
 N.db.settings.manualFirst=false
 local p=N:Price(2447); eq(p.unit,500); assert(p.stale); assert(p.developing); eq(p.marketStatus,'stale')
 local label=N:PriceLabel(p); assert(label:find('STALE',1,true) and label:find('developing',1,true))
 VoidMarkMarket.GetPriceInfo=function() return {apiVersion=1,status='current'} end
 VoidMarkMarketDB.economies[N.economy].market[2447].developingMarket=nil
 p=N:Price(2447); assert(not p.stale); assert(not p.developing)
 VoidMarkMarket=nil; VoidMarkMarketDB=nil
end)

test('0.11 learning: resetting one zone keeps other zones, sessions and spots',function()
 freshHistory()
 local here,there=loopRoute(A),loopRoute({{x=.4,y=.4,name='Copper Vein'},{x=.5,y=.4,name='Copper Vein'},{x=.5,y=.5,name='Copper Vein'}},1412)
 runLap(here,2,0,{},300); runLap(there,2,0,{},300); N:StopRoute()
 N:RouteHistory().stats['1411:balanced']={picks=1,laps=1,picked=2,empty=0,seconds=300}
 N:RouteHistory().stats['1412:balanced']={picks=1,laps=1,picked=2,empty=0,seconds=300}
 local sessions=#N.db.sessions; N.db.spots[MAP]={['1:1']={picked=1,empty=0}}
 eq(N:ResetRouteLearning('zone'),1)
 eq(N:RouteRecords()[N:RouteKey(here)],nil); assert(N:RouteRecords()[N:RouteKey(there)])
 eq(N:RouteHistory().stats['1411:balanced'],nil); assert(N:RouteHistory().stats['1412:balanced'])
 eq(#N.db.sessions,sessions); assert(N.db.spots[MAP]['1:1'])
 N.db.spots={}; restoreNow()
end)

test('0.11 learning: best routes list ranks by results and runs one again',function()
 freshHistory(); N.db.settings.market=false
 local good,poor=loopRoute(A),loopRoute({{x=.6,y=.6,name='Peacebloom'},{x=.65,y=.6,name='Peacebloom'},{x=.65,y=.65,name='Peacebloom'}})
 for _=1,4 do runLap(good,4,0,{},300) end
 for _=1,4 do runLap(poor,1,3,{},300) end
 N:StopRoute()
 local list=N:BestRouteRecords(MAP)
 eq(list[1].key,N:RouteKey(good)); eq(list[2].key,N:RouteKey(poor))
 N.routeList=list
 N:RunRouteRecord(1)
 assert(N.activeRoute and N.activeRoute.loop); eq(#N.activeRoute.points,4); eq(N:RouteKey(N.activeRoute),N:RouteKey(good))
 N:StopRoute(); N.db.settings.market=true; restoreNow()
end)

test('0.11 value: herbs vs ore comparison builds a loop for each with gold/hr or unknown',function()
 local rows=N:CompareKinds(MAP)
 eq(#rows,2); eq(rows[1].kind,'herb'); eq(rows[2].kind,'ore')
 for _,r in ipairs(rows) do if r.route then assert(r.rate>0) end end
 N:CompareCommand()
end)

test('0.11 value: gold routes rank route options by gold/hr',function()
 local s=N.db.settings; local keep={s.routeSelectionMode,s.kind,s.routeZone}
 s.routeSelectionMode,s.kind,s.routeZone='gold','herb',nil
 s.market=false; N:SetPrice(2447,5); N:SetPrice(765,.01)
 local list=N:RouteOptions(false)
 assert(list and #list>0)
 for i=2,#list do assert(list[i-1].score>=list[i].score) end
 assert(list[1].scored and list[1].scored.gold,'top option has a gold estimate')
 assert(N:RouteOptionLine(list[1]):find('/hr',1,true))
 assert(N:RouteOptionWhy(list[1]):find('Gold:',1,true))
 s.routeSelectionMode,s.kind,s.routeZone=keep[1],keep[2],keep[3]; s.market=true
end)

test('0.11 value: Gather page shows the loop record and best routes, shift-click opens Market',function()
 freshHistory(); local route=loopRoute(A)
 runLap(route,3,1,{[2447]=4},600)
 N:Show('Gather'); N:Render()
 local first=N.ui.rows[1].data; assert(first and first.text:find('nodes/hr',1,true))
 N:StopRoute()
 N:Render()
 local found=false
 for _,b in ipairs(N.ui.rows) do if b.data and b.data.text:find('best routes',1,true) then found=true end end
 assert(found,'best routes listed when idle')
 eq(#N.errors,0); restoreNow()
end)
