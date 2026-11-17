local _, N = ...
-- 0.13.5: what you picked on a route. Counts every gathered item while a route
-- runs (kept across /reload) and shows a summary with approximate sale value
-- when you press Stop route.

-- A new route starts a fresh tally; a rebuild of the running route keeps it.
function N:RouteHaulStart(fresh)
 local h=self.db.routeHaul
 if fresh or type(h)~='table' or type(h.items)~='table' or not self:Finite(h.at,0,self:Now()+300) then
  self.db.routeHaul={at=self:Now(),items={}}
 end
end
function N:RouteHaulAdd(id,qty)
 local h=self.db and self.db.routeHaul
 if type(h)~='table' or type(h.items)~='table' or not self.activeRoute then return end
 if not self:Finite(id,1,1e9) or not self:Finite(qty,1,1e6) then return end
 h.items[id]=(h.items[id] or 0)+qty
end

function N:RouteHaulText(h)
 local list={}
 for id,qty in pairs(h.items or {}) do
  local p=self:Price(id)
  list[#list+1]={id=id,qty=qty,name=self:ItemName(id),unit=p and p.unit,stale=p and p.stale}
 end
 table.sort(list,function(a,b)
  local va,vb=(a.unit or 0)*a.qty,(b.unit or 0)*b.qty
  if va~=vb then return va>vb end return a.name<b.name end)
 local mins=math.max(0,math.floor((self:Now()-(h.at or self:Now()))/60+.5))
 local lines={string.format('Route time: about %d min   Laps: %d',mins,self.lap or 1),''}
 if #list==0 then lines[#lines+1]='Nothing gathered on this route.'; return table.concat(lines,'\n'),0 end
 local total,count,unpriced,stale=0,0,0,false
 for _,e in ipairs(list) do
  count=count+e.qty
  if e.unit then
   total=total+e.unit*e.qty; stale=stale or e.stale
   lines[#lines+1]=string.format('%4d x %s   ~%s  (%s each)%s',e.qty,e.name,self:Money(e.unit*e.qty),self:Money(e.unit),e.stale and ' *' or '')
  else
   unpriced=unpriced+1
   lines[#lines+1]=string.format('%4d x %s   no price',e.qty,e.name)
  end
 end
 lines[#lines+1]=''
 lines[#lines+1]=string.format('Total: %d items, about %s',count,self:Money(total))
 if mins>0 and total>0 then lines[#lines+1]='About '..self:Money(total*60/mins)..' per hour' end
 if stale then lines[#lines+1]='* price is old; scan the AH for a fresher number.' end
 if unpriced>0 then lines[#lines+1]='Items with no price are not in the total.' end
 lines[#lines+1]='Prices are approximate (VoidMark Market / Auctionator), before AH cut.'
 return table.concat(lines,'\n'),total
end

do
 local start=N.StartRoute
 N.StartRoute=function(self,route,quiet)
  self:RouteHaulStart(self.activeRoute==nil)
  return start(self,route,quiet)
 end
 local stop=N.StopRoute
 N.StopRoute=function(self,...)
  local h=self.db.routeHaul
  local had=self.activeRoute~=nil
  local r=stop(self,...)
  self.db.routeHaul=nil
  if had and type(h)=='table' then
   local text,total=self:RouteHaulText(h)
   self:Print('Route ended: about '..self:Money(total)..' gathered.')
   if self.TextDialog then self:TextDialog('Route summary',text) end
   self.lastRouteHaul=text
  end
  return r
 end
end
N:AddCommand('haul',function(self)
 local h=self.db.routeHaul
 if type(h)=='table' then self:TextDialog('Route so far',(self:RouteHaulText(h)))
 elseif self.lastRouteHaul then self:TextDialog('Last route summary',self.lastRouteHaul)
 else self:Print('No route summary yet. Start a route and gather.') end
end,'/vmn haul (what you picked on this route and its approximate value)')
