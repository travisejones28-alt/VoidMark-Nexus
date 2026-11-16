local _, N = ...
-- 0.11 route learning and farming value.
--
-- Every distinct loop (same zone, same set of stops, in any order or starting
-- point) gets its own record: laps, stops visited, found and empty, resources
-- and quantities, skill gained, time spent gathering versus travelling. Those
-- records rank the route options next time:
--  * Expected nodes/hour starts from the old estimate and moves toward what you
--    actually got, weighted by how many laps you ran (a few laps barely move it).
--  * Gold/hour uses the items you actually gathered on that loop and current
--    prices. Before you have run a loop it is estimated from its stops, the
--    yield per node you have seen for each resource (at least 1) and prices.
--    Missing prices are never counted as zero: they make the figure partial.
-- Records are kept per route; /vmn routereset clears one route or one zone
-- without touching sessions, spots or other zones.
local PRIOR_LAPS=3          -- the estimate counts as this many laps against real ones
local MIN_HOURS=.05         -- 3 minutes of real data before it moves the estimate
local MAX_ROUTES=150        -- route records kept (least useful pruned first)
local MAX_STOPS=150
local CELL=40

local floor=math.floor
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

function N:RouteRecords()
 local h=self:RouteHistory()
 if type(h.routes)~='table' then h.routes={} end
 return h.routes
end

-- Same stops = same route, whatever the start or direction.
function N:RouteKey(route)
 if not route or not route.points or #route.points==0 then return nil end
 if route.key and route.keyCount==#route.points then return route.key end
 local w,h=route.width,route.height
 if not w then w,h=self:MapSize(route.map) end
 if not w then return nil end
 local cells={}
 for _,p in ipairs(route.points) do
  if not p.transit then cells[#cells+1]=floor(p.x*w/CELL)..':'..floor(p.y*h/CELL) end
 end
 table.sort(cells)
 local text=tostring(route.map)..'|'..table.concat(cells,';')
 local hash=0
 for i=1,#text do hash=(hash*31+text:byte(i))%2147483647 end
 route.key=tostring(route.map)..'-'..tostring(hash);route.keyCount=#route.points
 return route.key
end

-- Compact copy of the stops so a good route can be run again later.
local function packStops(route)
 local names,index,out={}, {}, {}
 for i,p in ipairs(route.points) do
  if i>MAX_STOPS then break end
  local name=tostring(p.name or 'Stop')
  if not index[name] then names[#names+1]=name;index[name]=#names end
  out[#out+1]=string.format('%.4f,%.4f,%d',p.x,p.y,index[name])
 end
 return table.concat(out,';'),names
end
function N:RouteFromRecord(rec)
 if type(rec)~='table' or type(rec.stops)~='string' or not self:Finite(rec.map,1,100000) then return nil end
 local w,h=self:MapSize(rec.map);if not w then return nil end
 local points={}
 for x,y,i in rec.stops:gmatch('([%d%.]+),([%d%.]+),(%d+)') do
  x,y=tonumber(x),tonumber(y)
  if self:Finite(x,0,1) and self:Finite(y,0,1) then
   points[#points+1]={x=x,y=y,map=rec.map,name=type(rec.names)=='table' and rec.names[tonumber(i)] or 'Stop',source='Saved route'}
  end
 end
 if #points<3 then return nil end
 local s=self.db.settings
 local speed=self.TravelSpeed and self:TravelSpeed() or s.speed
 local route={points=points,map=rec.map,width=w,height=h,loop=true,strategy='zoneloop',optimizer='saved-loop',variant=rec.variant,
  speed=speed,gatherDelay=s.gatherDelay,mountDelay=s.mountDelay,mode=s.travel,created=self:Now(),arriveRadius=self.loopArriveRadius or 25,origin=self:Copy(points[1])}
 -- Re-attach learned trails between the saved stops.
 local g=self.TerrainGraph and s.terrainRouting~=false and self:TerrainGraph(rec.map,w,h,speed)
 local length,seconds=0,0
 if g then
  local stops={};for i,p in ipairs(points) do stops[i]={x=p.x*w,y=p.y*h} end
  route.legs={}
  local verified=0
  for i=1,#stops do
   local l=self:TerrainLoopLeg(g,stops[i],stops[i%#stops+1]);route.legs[i]=l
   length=length+l.length;seconds=seconds+l.seconds;verified=verified+(l.verified or 0)
  end
  route.verifiedShare=length>0 and verified/length or 0
 else
  for i,p in ipairs(points) do length=length+self:Distance(p,points[i%#points+1],w,h) end
  seconds=length/math.max(1,speed)
 end
 route.length=length
 route.seconds=seconds+(math.max(0,s.gatherDelay or 3)+math.max(0,s.mountDelay or 0))*#points
 self:RouteKey(route)
 return route
end

--------------------------------------------------------------------------------
-- Recording what each lap produced
--------------------------------------------------------------------------------
local function onRoute(self,g)
 local route=self.activeRoute
 return route and route.loop and not self.routePaused and g and route.map==g.map and self.lapStats
end
function N:NoteGatherCast(g)
 if not onRoute(self,g) then return end
 local lap=self.lapStats
 if self:Finite(g.castSeconds,0,60) then lap.gatherSeconds=(lap.gatherSeconds or 0)+g.castSeconds end
end
function N:NoteGatherLoot(id,qty,g)
 if not onRoute(self,g) then return end
 local lap=self.lapStats
 lap.items=lap.items or {};lap.items[id]=(lap.items[id] or 0)+qty
 lap.qty=(lap.qty or 0)+qty
end

-- Adds one lap (or the finished part of one) to the route's record.
function N:LogRouteRun(route,lap,partial)
 if not route or not lap or not route.loop then return end
 local secs=(lap.finished or self:Now())-(lap.started or self:Now())
 if not self:Finite(secs,partial and 60 or 30,4*3600) then return end
 if partial and (lap.visited or 0)<2 then return end
 local key=self:RouteKey(route);if not key then return end
 local routes=self:RouteRecords()
 local r=routes[key]
 if type(r)~='table' then
  r={map=route.map,variant=route.variant,kind=self.db.settings.kind,stopCount=#route.points,length=route.length,created=self:Now(),
   laps=0,partial=0,seconds=0,gatherSeconds=0,visited=0,picked=0,empty=0,qty=0,gain=0,items={}}
  r.stops,r.names=packStops(route)
  routes[key]=r
  self:PruneRouteRecords()
 end
 if partial then r.partial=r.partial+1 else r.laps=r.laps+1 end
 r.seconds=r.seconds+secs
 r.gatherSeconds=r.gatherSeconds+math.min(secs,tonumber(lap.gatherSeconds) or 0)
 r.visited=r.visited+(tonumber(lap.visited) or 0)
 r.picked=r.picked+(tonumber(lap.picked) or 0)
 r.empty=r.empty+(tonumber(lap.empty) or 0)
 r.qty=r.qty+(tonumber(lap.qty) or 0)
 r.gain=r.gain+(tonumber(lap.gain) or 0)
 for id,q in pairs(lap.items or {}) do
  if count(r.items)<40 or r.items[id] then r.items[id]=(r.items[id] or 0)+q end
 end
 r.last=self:Now();r.variant=route.variant or r.variant
 self.dirty=true
 return r
end
-- Keep the routes you ran most; drop never-run and old ones first.
function N:PruneRouteRecords()
 local routes=self:RouteRecords();local list={}
 for k,r in pairs(routes) do list[#list+1]={k=k,v=(type(r)=='table' and ((r.laps or 0)*10+(r.partial or 0)) or -1),at=type(r)=='table' and (r.last or r.created) or 0} end
 if #list<=MAX_ROUTES then return end
 table.sort(list,function(a,b) if a.v~=b.v then return a.v<b.v end return a.at<b.at end)
 for i=1,#list-MAX_ROUTES do routes[list[i].k]=nil end
end
do
 local finish=N.FinishLap
 N.FinishLap=function(self,...)
  local lap,route=self.lapStats,self.activeRoute
  local a,b=finish(self,...)
  if lap and route then
   lap.finished=lap.finished or self:Now()
   self:Guard('routeRun',function() self:LogRouteRun(route,lap,false) end)
  end
  return a,b
 end
 -- Stopping or switching mid-lap keeps what that part of the lap produced.
 local function flush(self)
  local lap,route=self.lapStats,self.activeRoute
  if lap and route and route.loop then
   lap.finished=self:Now()
   local now=self.LoopSkill and self:LoopSkill();if lap.skill and now then lap.gain=math.max(0,now-lap.skill) end
   self:Guard('routeRun',function() self:LogRouteRun(route,lap,true) end)
  end
 end
 local stop=N.StopRoute
 N.StopRoute=function(self,...) flush(self);self.lapStats=nil;return stop(self,...) end
 local start=N.StartRoute
 N.StartRoute=function(self,route,...) if self.activeRoute and self.activeRoute~=route then flush(self) end;return start(self,route,...) end
end

--------------------------------------------------------------------------------
-- Value: prices, yield per node
--------------------------------------------------------------------------------
-- Average items per successful gather for each resource, from your own gathers.
function N:YieldPerNode()
 local stamp=self.yieldStamp
 if stamp and stamp.at==self:Now() and stamp.db==self.db.gatherEvidence then return stamp.byName end
 local byName={}
 for _,zone in pairs(type(self.db.gatherEvidence)=='table' and self.db.gatherEvidence or {}) do
  if type(zone)=='table' then
   for key,e in pairs(zone) do
    local object=tonumber(tostring(key):match('^(%d+):'))
    local kind=object and self.nodeTypes[object]
    if kind and type(e)=='table' and self:Finite(e.harvests,1,1e9) and self:Finite(e.qty,1,1e12) then
     local t=byName[kind.name] or {h=0,q=0};byName[kind.name]=t;t.h=t.h+e.harvests;t.q=t.q+e.qty
    end
   end
  end
 end
 self.yieldStamp={at=self:Now(),byName=byName,db=self.db.gatherEvidence}
 return byName
end
do local record=N.RecordHarvest
 N.RecordHarvest=function(self,...) self.yieldStamp=nil;return record(self,...) end
end
-- Value of one gathered node of this resource: price x observed yield (>= 1).
function N:NodeValue(name)
 local id=self.nodeItemIDs and self.nodeItemIDs[name]
 if not id then return nil,nil,'no item' end
 local p=self:Price(id)
 if not p then return nil,nil,'no price' end
 local y=self:YieldPerNode()[name]
 local per=(y and y.h>=3) and y.q/y.h or 1
 return p.unit*per,p,(y and y.h>=3) and 'observed yield' or 'minimum 1 per node'
end
-- Priced value of an item bag ({[id]=qty}); unpriced quantity is reported separately.
function N:ItemsValue(items)
 local value,unpriced,stale,total=0,0,false,0
 for id,q in pairs(items or {}) do
  total=total+q
  local p=self:Price(tonumber(id))
  if p then value=value+p.unit*q;if p.stale then stale=true end else unpriced=unpriced+q end
 end
 return value,unpriced,stale,total
end

--------------------------------------------------------------------------------
-- Scoring
--------------------------------------------------------------------------------
local function confidence(laps,hours)
 if laps<=0 and hours<MIN_HOURS then return 'estimate' end
 if laps<3 or hours<1/3 then return 'low' end
 if laps<8 or hours<1 then return 'medium' end
 return 'good'
end
N.RouteConfidence=confidence
-- Expected rates for a built route. Returns a table:
--  rate (nodes/hr), guess, real, laps, hours, confidence,
--  gold (copper/hr or nil), goldBasis, goldPartial, realGold, record.
function N:ScoreRoute(route,variant)
 local rate,guess=self:RouteRate(route,variant)
 local out={rate=rate,guess=guess,laps=0,hours=0,confidence='estimate'}
 local key=self:RouteKey(route);local r=key and self:RouteRecords()[key]
 if type(r)=='table' and (r.seconds or 0)>0 then
  local hours=r.seconds/3600;local laps=(r.laps or 0)+(r.partial or 0)*.5
  out.record,out.hours,out.laps=r,hours,r.laps or 0
  if hours>=MIN_HOURS then
   out.real=r.picked/hours
   out.rate=(rate*PRIOR_LAPS+out.real*laps)/(PRIOR_LAPS+laps)
  end
  out.confidence=confidence(laps,hours)
  if (r.picked or 0)>=3 and next(r.items or {}) then
   local value,unpriced,stale,total=self:ItemsValue(r.items)
   if total>0 and unpriced<total then
    out.realGold=hours>0 and value/hours or nil
    out.gold=value/r.picked*out.rate
    out.goldBasis='your loot on this loop';out.goldPartial=unpriced>0 or nil;out.goldStale=stale or nil
   end
  end
 end
 if not out.gold then
  -- Estimate from the stops: value per node of each stop's resource.
  local sum,priced,missing,basis,stale=0,0,0,'minimum 1 per node',false
  for _,p in ipairs(route.points) do
   local name=p.name and p.name:match('^(.-) %+%d+$') or p.name
   local v,price,how=self:NodeValue(name or '')
   if v then sum=sum+v;priced=priced+1;if how=='observed yield' then basis='observed yield' end;if price.stale then stale=true end
   else missing=missing+1 end
  end
  if priced>0 then
   out.gold=sum/priced*out.rate
   out.goldBasis='estimate: '..basis;out.goldPartial=missing>0 or nil;out.goldStale=stale or nil
   out.goldMissing=missing
  end
 end
 return out
end

do -- Route options are ranked by these scores (gold routes by gold/hour).
 local rank=N.RankRouteOptions
 N.RankRouteOptions=function(self,out)
  rank(self,out)
  local gold=self.db.settings.routeSelectionMode=='gold'
  for _,o in ipairs(out) do
   local s=self:ScoreRoute(o.route,o.variant)
   o.scored=s;o.rate=s.rate;o.real=s.real or o.real;o.laps=s.laps>0 and s.laps or o.laps
   local share,picks=self:VariantShare(o.variant)
   local base=s.rate
   if gold then base=s.gold or s.rate*1e-6 end -- unpriced routes sort last, by nodes/hr
   o.score=(base or 0)*(1+(picks>=3 and share*.15 or 0))*(o.here and 1 or .85)
   -- Thin evidence never outranks a route with real history by itself.
   if s.confidence=='low' then o.score=o.score*.97 end
   o.recommended=nil
  end
  table.sort(out,function(a,b) if a.score~=b.score then return a.score>b.score end return a.label<b.label end)
  if out[1] then out[1].recommended=true end
  for i,o in ipairs(out) do o.rank=i end
  return out
 end
 local line=N.RouteOptionLine
 N.RouteOptionLine=function(self,o)
  local text,spawns=line(self,o)
  local s=o.scored
  if s and s.gold then text=text..string.format(', ~%s/hr%s',self:Gold(s.gold),s.goldPartial and '*' or '') end
  return text,spawns
 end
 local why=N.RouteOptionWhy
 N.RouteOptionWhy=function(self,o)
  local text=why(self,o);local s=o.scored
  if not s then return text end
  local lines={text}
  if s.record then
   lines[#lines+1]=string.format('This exact loop: %d lap%s, %.0f min, %d found / %d empty, %d items (%s confidence)',
    s.record.laps or 0,s.record.laps==1 and '' or 's',(s.record.seconds or 0)/60,s.record.picked or 0,s.record.empty or 0,s.record.qty or 0,s.confidence)
  else lines[#lines+1]='Never run this exact loop: rates are estimates.' end
  if s.gold then
   lines[#lines+1]=string.format('Gold: ~%s/hr (%s)%s%s',self:Gold(s.gold),s.goldBasis,s.goldPartial and '; some resources have no price' or '',s.goldStale and '; some prices are STALE' or '')
  else lines[#lines+1]='Gold/hr unknown: no prices for these resources.' end
  return table.concat(lines,'\n')
 end
end

--------------------------------------------------------------------------------
-- Comparing, resetting, herbs vs ore
--------------------------------------------------------------------------------
function N:RouteRecordLine(key,r)
 local hours=(r.seconds or 0)/3600
 local rate=hours>0 and r.picked/hours or 0
 local value,unpriced,stale,total=self:ItemsValue(r.items)
 local gold=hours>0 and total>0 and unpriced<total and value/hours or nil
 local travel=(r.seconds or 0)-(r.gatherSeconds or 0)
 return string.format('%s: %d stops, %d lap%s%s, %.0f min (%.0f%% travelling), %d nodes/hr, %d empty, %d items%s, %s%s',
  self:RouteZoneName(r.map),r.stopCount or 0,r.laps or 0,r.laps==1 and '' or 's',(r.partial or 0)>0 and (' +'..r.partial..' part') or '',
  hours*60,(r.seconds or 0)>0 and travel/r.seconds*100 or 0,floor(rate+.5),r.empty or 0,r.qty or 0,(r.gain or 0)>0 and (', +'..r.gain..' skill') or '',
  gold and (self:Gold(gold)..'/hr'..(unpriced>0 and '*' or '')..(stale and ' (stale prices)' or '')) or 'gold/hr unknown',
  ' ['..confidence((r.laps or 0)+(r.partial or 0)*.5,hours)..']')
end
-- Routes you have run, best first (by gold/hr when every one is priced, else nodes/hr).
function N:BestRouteRecords(map,limit)
 local list={}
 for key,r in pairs(self:RouteRecords()) do
  if type(r)=='table' and (r.seconds or 0)>0 and (not map or r.map==map) then
   local hours=r.seconds/3600
   local value,unpriced,_,total=self:ItemsValue(r.items)
   list[#list+1]={key=key,r=r,rate=r.picked/math.max(hours,1e-6),gold=total>0 and unpriced<total and value/hours or nil,
    weight=(r.laps or 0)+(r.partial or 0)*.5}
  end
 end
 local allGold=#list>0
 for _,e in ipairs(list) do if not e.gold then allGold=false end end
 -- Shrink each toward the average so a single lucky lap does not top the list.
 local mean,n=0,0
 for _,e in ipairs(list) do mean=mean+(allGold and e.gold or e.rate);n=n+1 end
 mean=n>0 and mean/n or 0
 for _,e in ipairs(list) do local v=allGold and e.gold or e.rate;e.score=(mean*PRIOR_LAPS+v*e.weight)/(PRIOR_LAPS+e.weight) end
 table.sort(list,function(a,b) if a.score~=b.score then return a.score>b.score end return a.key<b.key end)
 while limit and #list>limit do table.remove(list) end
 return list,allGold
end
function N:RoutesCommand(args)
 local map=(args=='zone' or args=='here') and self:Position() or nil
 local list,byGold=self:BestRouteRecords(map,10)
 if #list==0 then return self:Print('No route runs recorded yet. Run a lap of any route and it is tracked here.') end
 self.routeList=list
 self:Print('Your routes, best first by '..(byGold and 'gold/hr' or 'nodes/hr')..' (few laps are pulled toward the average). * = some items unpriced.')
 for i,e in ipairs(list) do self:Print(i..'. '..self:RouteRecordLine(e.key,e.r)) end
 self:Print('/vmn runroute N starts one again. /vmn routereset N | current | zone | all')
end
function N:RunRouteRecord(i)
 local e=self.routeList and self.routeList[tonumber(i) or 0]
 if not e then return self:Print('List routes first with /vmn routes.') end
 local route=self:RouteFromRecord(e.r)
 if not route then return self:Print('That route could not be rebuilt (map size unavailable here).') end
 self:StartRoute(route)
 if self:Position()~=route.map then self:Print('This loop is in '..self:RouteZoneName(route.map)..'. Head there; the arrow points to the first stop.') end
end
-- Clear learned performance without touching sessions, spots, laps or other zones.
function N:ResetRouteLearning(what)
 local routes=self:RouteRecords();local h=self:RouteHistory();local n=0
 if what=='all' then
  n=count(routes);h.routes={};h.stats={}
 elseif what=='zone' then
  local map=self:Position();if not map then return self:Print('Position unavailable.') end
  for k,r in pairs(routes) do if type(r)~='table' or r.map==map then routes[k]=nil;n=n+1 end end
  for k in pairs(h.stats) do if k:match('^(%d+):')==tostring(map) then h.stats[k]=nil end end
 elseif what=='current' then
  local key=self.activeRoute and self:RouteKey(self.activeRoute)
  if not key then return self:Print('No active route.') end
  if routes[key] then routes[key]=nil;n=1 end
 else
  local e=self.routeList and self.routeList[tonumber(what) or 0]
  if not e then return self:Print('/vmn routereset N (from /vmn routes) | current | zone | all') end
  if routes[e.key] then routes[e.key]=nil;n=1 end
  self.routeList=nil
 end
 self.dirty=true
 self:Print('Cleared learned performance for '..n..' route'..(n==1 and '' or 's')..'. Sessions, spots and other zones are unchanged.')
 return n
end
-- Herbs vs ore in one zone: an estimated loop for each, plus your own history.
function N:CompareKinds(map)
 map=map or (self.RouteZone and (self:RouteZone())) or self:Position()
 if not map then return nil,'Position unavailable.' end
 local s=self.db.settings
 local out={}
 for _,kind in ipairs({'herb','ore'}) do
  local nodes=self:ZoneNodes(map,kind,'')
  local skills=self:GatheringSkills()
  local usable={}
  for _,n in ipairs(nodes) do local p=skills[kind];if not p or not n.skill or p.skill>=n.skill then usable[#usable+1]=n end end
  local row={kind=kind,spawns=#usable}
  if #usable>=3 then
   local ok,route=pcall(self.BuildZoneLoop,self,map,usable,nil,nil,{minutes=s.routeMinutes})
   if ok and route then local sc=self:ScoreRoute(route,'balanced');row.route=route;row.rate=sc.rate;row.gold=sc.gold;row.basis=sc.goldBasis;row.partial=sc.goldPartial;row.stale=sc.goldStale end
  end
  -- Your own runs of that kind in this zone.
  local secs,value,unpriced,total=0,0,0,0
  for _,r in pairs(self:RouteRecords()) do
   if type(r)=='table' and r.map==map and r.kind==kind then
    secs=secs+(r.seconds or 0)
    local v,u,_,t=self:ItemsValue(r.items);value=value+v;unpriced=unpriced+u;total=total+t
   end
  end
  if secs>=180 and total>0 and unpriced<total then row.realGold=value/secs*3600;row.realPartial=unpriced>0 or nil;row.hours=secs/3600 end
  out[#out+1]=row
 end
 return out
end
function N:CompareCommand()
 local map=self.RouteZone and (self:RouteZone()) or self:Position()
 local rows,err=self:CompareKinds(map);if not rows then return self:Print(err) end
 self:Print('Herbs vs ore in '..self:RouteZoneName(map)..' (only nodes your skill can gather):')
 for _,r in ipairs(rows) do
  local label=r.kind=='herb' and 'Herbs' or 'Ore'
  if not r.route then self:Print(label..': not enough spawn spots ('..r.spawns..').')
  else
   self:Print(string.format('%s: %d stops, ~%d nodes/hr, %s%s',label,#r.route.points,floor(r.rate+.5),
    r.gold and ('~'..self:Gold(r.gold)..'/hr ('..r.basis..(r.partial and ', some unpriced' or '')..(r.stale and ', stale prices' or '')..')') or 'gold/hr unknown (no prices)',
    r.realGold and string.format('; you made %s/hr over %.1f h%s',self:Gold(r.realGold),r.hours,r.realPartial and ' (some unpriced)' or '') or ''))
  end
 end
end
N:AddCommand('routes',function(self,args) self:RoutesCommand(args) end,'/vmn routes [zone] (compare your routes), /vmn runroute N, /vmn routereset N|current|zone|all')
N:AddCommand('runroute',function(self,args) self:RunRouteRecord(args) end)
N:AddCommand('routereset',function(self,args) self:ResetRouteLearning(args~='' and args or 'current') end)
N:AddCommand('compare',function(self) self:CompareCommand() end,'/vmn compare (herbs vs ore here: nodes/hr and gold/hr)')

-- Prices of the resources on the route or in the zone, with age and confidence.
function N:ResourcePriceLines(map)
 local names,seen={},{}
 local route=self.activeRoute
 if route and route.map==map then
  for _,p in ipairs(route.points) do local n=p.name and (p.name:match('^(.-) %+%d+$') or p.name);if n and not seen[n] then seen[n]=true;names[#names+1]=n end end
 else
  for _,n in ipairs(self:ZoneNodes(map) or {}) do if not seen[n.name] then seen[n.name]=true;names[#names+1]=n.name end end
 end
 table.sort(names)
 local lines={}
 for _,name in ipairs(names) do
  local id=self.nodeItemIDs and self.nodeItemIDs[name]
  local p=id and self:Price(id)
  local y=self:YieldPerNode()[name]
  lines[#lines+1]={name=name,id=id,price=p,text=name..': '..(p and self:PriceLabel(p) or 'no price (not counted as zero)')..
   (y and y.h>0 and string.format(' | %.1f per node over %d gathers',y.q/y.h,y.h) or '')}
 end
 return lines
end
N:AddCommand('prices',function(self)
 local map=self.RouteZone and (self:RouteZone()) or self:Position()
 if not map then return self:Print('Position unavailable.') end
 local lines=self:ResourcePriceLines(map)
 if #lines==0 then return self:Print('No resources match here.') end
 for _,l in ipairs(lines) do self:Print(l.text) end
end,'/vmn prices (resource prices here: age, confidence, stale flags)')
N:AddCommand('market',function(self,args)
 local id=tonumber(args) or (self.ItemIDByName and self:ItemIDByName(args)) or (self.nodeItemIDs and self.nodeItemIDs[args])
 if not id then return self:Print('/vmn market ITEM NAME or ID') end
 self:OpenMarket(id)
end,'/vmn market ITEM (open it in VoidMark Market; read only)')

do -- Gather page: this loop's record while running; your best routes when idle.
 local render=N.RenderGather
 N.RenderGather=function(self,u,...)
  local rows=render(self,u,...)
  local route=self.activeRoute
  local extra={}
  if route and route.loop then
   local key=self:RouteKey(route);local r=key and self:RouteRecords()[key]
   local s=self:ScoreRoute(route,route.variant)
   local terrain=self.LoopTerrainSummary and self:LoopTerrainSummary(route)
   extra[#extra+1]=string.format('Expected ~%d nodes/hr%s [%s]',floor(s.rate+.5),s.gold and (', ~'..self:Gold(s.gold)..'/hr'..(s.goldPartial and '*' or '')) or '',s.confidence)
   if r then extra[#extra+1]='This loop so far: '..self:RouteRecordLine(key,r):gsub('^[^:]+: ','') end
   if terrain then extra[#extra+1]=terrain end
  else
   local map=self.RouteZone and (self:RouteZone())
   local best=map and self:BestRouteRecords(map,3) or {}
   if #best>0 then
    self.routeList=best
    rows[#rows+1]={text='Your best routes here (click to run again)',color={.6,.6,.6}}
    for i,e in ipairs(best) do
     rows[#rows+1]={text=i..'. '..self:RouteRecordLine(e.key,e.r),click=function() self:RunRouteRecord(i) end}
    end
   end
  end
  -- Resource rows: price in the tooltip; shift-click opens it in Market.
  for _,row in ipairs(rows) do
   local name=row.title and (row.title:match('^(.-) %+%d+$') or row.title)
   local id=name and self.nodeItemIDs and self.nodeItemIDs[name]
   if id then
    local tip,click=row.tip,row.click
    row.tip=function(tt) if tip then tip(tt) end;local p=self:Price(id);tt:AddLine(p and self:PriceLabel(p) or 'No price',1,.82,0);tt:AddLine('Shift-click: open in VoidMark Market',.7,.7,.7) end
    row.click=function() if IsShiftKeyDown and IsShiftKeyDown() then self:OpenMarket(id) elseif click then click() end end
   end
  end
  -- Shown above the stop list (the info text above it is capped at a few lines).
  for i,text in ipairs(extra) do table.insert(rows,i,{text=text,color={.75,.65,1},noIcon=true}) end
  return rows
 end
end
