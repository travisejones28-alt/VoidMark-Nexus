local _, N = ...
N.travelModes={{'Foot',7,0},{'60% Mount',11.2,3},{'100% Mount',14,3},{'Travel Form',9.8,1.5},{'Custom',7,0}}
function N:MapSize(map)
 if C_Map and C_Map.GetMapWorldSize then
  local width,height=self:Call(C_Map.GetMapWorldSize,map)
  if self:Finite(width,1,100000) and self:Finite(height,1,100000) then return width,height end
 end
 return nil
end
function N:Distance(a,b,width,height)
 return math.sqrt(((a.x-b.x)*width)^2+((a.y-b.y)*height)^2)
end
function N:BuildRoute(nodes,start,width,height,s)
 if not width then return nil,'Client map dimensions unavailable; cannot calculate reliable distance.' end
 local candidates={}; for _,n in ipairs(nodes) do candidates[#candidates+1]=self:Copy(n) end
 table.sort(candidates,function(a,b) local da=self:Distance(a,start,width,height); local db=self:Distance(b,start,width,height); if da==db then return a.object<b.object end; return da<db end)
 local limit=math.min(150,math.max(2,s.nodeLimit)); while #candidates>limit*3 do table.remove(candidates) end
 local path,last,elapsed={},start,0; local speed=math.max(1,s.speed); local stop=math.max(0,s.mountDelay)+math.max(0,s.gatherDelay)
 while #candidates>0 and #path<limit do
  local best,bestCost
  for i,n in ipairs(candidates) do local cost=self:Distance(last,n,width,height)/speed+stop; if not bestCost or cost<bestCost then best,bestCost=i,cost end end
  local point=candidates[best]; local home=self:Distance(point,start,width,height)/speed
  if elapsed+bestCost+home>s.routeMinutes*60 then break end
  path[#path+1]=table.remove(candidates,best); elapsed=elapsed+bestCost; last=point
 end
 -- Open-path 2-opt with a fixed player origin and a return to that origin.
 for pass=1,3 do
  local improved=false
  for i=1,#path-1 do for j=i+1,#path do
   local a=i==1 and start or path[i-1]; local b=path[i]; local c=path[j]; local d=path[j+1] or start
   if self:Distance(a,c,width,height)+self:Distance(b,d,width,height)+.01<self:Distance(a,b,width,height)+self:Distance(c,d,width,height) then
    local l,r=i,j; while l<r do path[l],path[r]=path[r],path[l]; l=l+1; r=r-1 end; improved=true
   end
  end end
  if not improved then break end
 end
 elapsed=0; last=start
 for _,p in ipairs(path) do elapsed=elapsed+self:Distance(last,p,width,height)/speed+stop; last=p end
 elapsed=elapsed+self:Distance(last,start,width,height)/speed
 return {points=path,origin=self:Copy(start),seconds=elapsed,width=width,height=height,mode=s.travel,created=self:Now(),map=start.map}
end
function N:GenerateRoute()
 local map,x,y=self:Position(); if not map then return self:Print('Zone position unavailable.') end
 local w,h=self:MapSize(map); local route,err=self:BuildRoute(self:ZoneNodes(map),{map=map,x=x,y=y},w,h,self.db.settings)
 if not route then return self:Print(err) end
 if #route.points<1 then return self:Print('No nodes fit the filters and route duration.') end
 self.activeRoute=route; self.waypoint=1; self.dirty=true; self:ShowArrow()
end
function N:SkipWaypoint()
 if not self.activeRoute then return end
 self.waypoint=(self.waypoint or 1)+1
 if self.waypoint>#self.activeRoute.points then self.activeRoute=nil; self:Print('Route complete.') end
 self.dirty=true
end
function N:SaveRoute(name)
 if not self.activeRoute then return end
 name=tostring(name or 'Route'):sub(1,80); if name=='' then name='Route' end
 local count=0; for _ in pairs(self.db.routes) do count=count+1 end
 if count>=50 and not self.db.routes[name] then return self:Print('Saved route limit: 50.') end
 self.db.routes[name]=self:Copy(self.activeRoute); self.dirty=true
end
function N:AddWaypoint()
 local map,x,y=self:Position(); if not map then return end
 if not self.activeRoute or self.activeRoute.map~=map then
  local w,h=self:MapSize(map); if not w then return end
  self.activeRoute={map=map,points={},origin={x=x,y=y,map=map},width=w,height=h,mode='Custom',created=self:Now()}
 end
 if #self.activeRoute.points>=150 then return end
 table.insert(self.activeRoute.points,{x=x,y=y,map=map,name='Custom waypoint',source='Custom'})
 self.waypoint=self.waypoint or 1; self.dirty=true; self:ShowArrow()
end
function N:ShowArrow()
 if not self.arrow then
  local f=CreateFrame('Frame','VoidMarkNexusArrow',UIParent); f:SetSize(170,110); f:SetPoint('TOP',UIParent,'TOP',0,-140)
  f:SetFrameStrata('LOW'); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function() f:StartMoving() end); f:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
  f.texture=f:CreateTexture(nil,'ARTWORK'); f.texture:SetSize(48,48); f.texture:SetPoint('TOP'); f.texture:SetTexture('Interface\\AddOns\\VoidMarkNexus\\Media\\Arrow.tga')
  f.label=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall'); f.label:SetPoint('TOP',0,-52); f.label:SetWidth(170)
  local elapsed=0
  f:SetScript('OnUpdate',function(_,dt) elapsed=elapsed+dt; if elapsed<.15 then return end; elapsed=0; N:Guard('navigation',function() N:UpdateArrow() end) end)
  self.arrow=f
 end
 self.arrow:Show()
end
function N:UpdateArrow()
 local route=self.activeRoute; local point=route and route.points[self.waypoint or 1]
 if not point or not self.db.settings.routeVisible then self.arrow:Hide(); return end
 local map,x,y=self:Position(); if map~=route.map then self.arrow.label:SetText('Return to route zone'); self.arrow.texture:Hide(); return end
 local facing=self:Call(GetPlayerFacing); if not self:Finite(facing,-10,10) then self.arrow.texture:Hide(); return end
 local distance=self:Distance({x=x,y=y},point,route.width,route.height)
 local bearing=math.atan2(-(point.x-x)*route.width,-(point.y-y)*route.height)
 self.arrow.texture:Show(); self.arrow.texture:SetRotation(bearing-facing)
 self.arrow.label:SetText(string.format('%s\n%d / %d  |  %.0f yd\n~%.0f sec direct',point.name or 'Waypoint',self.waypoint,#route.points,distance,distance/math.max(1,self.db.settings.speed)))
 if distance<8 then self:SkipWaypoint() end
end
local nexusNodeIcons = {
 ["Peacebloom"]=2447, ["Silverleaf"]=765, ["Earthroot"]=2449,
 ["Mageroyal"]=785, ["Briarthorn"]=2450, ["Bruiseweed"]=2453,
 ["Wild Steelbloom"]=3355, ["Kingsblood"]=3356, ["Liferoot"]=3357,
 ["Fadeleaf"]=3818, ["Goldthorn"]=3821, ["Khadgar's Whisker"]=3358,
 ["Wintersbite"]=3819, ["Firebloom"]=4625, ["Purple Lotus"]=8831,
 ["Sungrass"]=8838, ["Blindweed"]=8839, ["Ghost Mushroom"]=8845,
 ["Gromsblood"]=8846, ["Dreamfoil"]=13463, ["Mountain Silversage"]=13465,
 ["Plaguebloom"]=13466, ["Icecap"]=13467, ["Black Lotus"]=13468,
 ["Copper Vein"]=2770, ["Tin Vein"]=2771, ["Silver Vein"]=2775,
 ["Iron Deposit"]=2772, ["Gold Vein"]=2776, ["Mithril Deposit"]=3858,
 ["Truesilver Deposit"]=7911, ["Small Thorium Vein"]=10620,
 ["Rich Thorium Vein"]=10620
}
local nexusGenericHerb = 'Interface\\Icons\\INV_Misc_Herb_01'
local nexusGenericOre = 'Interface\\Icons\\INV_Ore_Copper_01'
function N:RefreshMap()
 local world=WorldMapFrame
 local canvas=world and world.GetCanvas and world:GetCanvas()
 if not canvas or not world:IsShown() then return end
 local map=world:GetMapID()
 if not map then return end
 local s=self.db.settings
 local filter=s.mapNodeFilter or 'all'
 -- A standalone world-map control, independent of whether the Nexus main window is open.
 if not self.mapNodeFilterButton then
  local b=CreateFrame('Button',nil,canvas,'UIPanelButtonTemplate')
  b:SetSize(140,23)
  b:SetPoint('TOPLEFT',canvas,'TOPLEFT',12,-12)
  b:SetFrameStrata('HIGH')
  b:SetScript('OnClick',function()
   N:Choice(b,{
    {label='Both: Herbs and Mining',value='all'},
    {label='Herbs only',value='herb'},
    {label='Mining only',value='ore'},
    {label='No gathering nodes',value='none'}
   },function(value)
    N.db.settings.mapNodeFilter=value
    N:RefreshMap()
   end)
  end)
  self.mapNodeFilterButton=b
 end
 local names={all='Herbs + Ore',herb='Herbs',ore='Mining',none='Hidden'}
 self.mapNodeFilterButton:SetText('Nexus: '..(names[filter] or names.all)..'  v')
 self.mapNodeFilterButton:Show()
 local nodes={}
 if s.nodesVisible and filter~='none' then
  -- Map display filters must NOT change the independent route-planning filter.
  for _,node in ipairs(self:ZoneNodes(map)) do
   if filter=='all' or node.kind==filter then nodes[#nodes+1]=node end
  end
 end
 self.mapPins=self.mapPins or {}
 local width,height=canvas:GetWidth(),canvas:GetHeight()
 if width<=0 or height<=0 then return end
 local points={}
 local route=self.activeRoute
 if s.routeVisible and route and route.map==map then
  for i,n in ipairs(route.points) do points[#points+1]={n=n,label=tostring(i),route=true} end
 end
 for i=1,math.min(250,#nodes) do points[#points+1]={n=nodes[i],label=''} end
 for i=1,math.max(#points,#self.mapPins) do
  local pin=self.mapPins[i]
  if not pin then
   pin=CreateFrame('Button',nil,canvas)
   pin:SetSize(17,17)
   pin.tex=pin:CreateTexture(nil,'ARTWORK')
   pin.tex:SetAllPoints()
   pin.label=pin:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
   pin.label:SetPoint('CENTER')
   pin:SetScript('OnEnter',function(p)
    GameTooltip:SetOwner(p,'ANCHOR_RIGHT')
    GameTooltip:SetText(p.node.name or 'Waypoint')
    GameTooltip:AddLine(p.node.source or 'Route')
    GameTooltip:Show()
   end)
   pin:SetScript('OnLeave',function() GameTooltip:Hide() end)
   self.mapPins[i]=pin
  end
  local p=points[i]
  if p then
   pin.node=p.n
   pin:ClearAllPoints()
   pin:SetPoint('CENTER',canvas,'TOPLEFT',p.n.x*width,-p.n.y*height)
   local texture
   if p.route then texture='Interface\\Icons\\INV_Misc_Map_01'
   else
    local id=nexusNodeIcons[p.n.name or '']
    if id and type(GetItemIcon)=='function' then texture=self:Call(GetItemIcon,id) end
    texture=texture or (p.n.kind=='ore' and nexusGenericOre or nexusGenericHerb)
   end
   pin.tex:SetTexture(texture)
   pin.label:SetText(p.label)
   pin:Show()
  else pin:Hide() end
 end
end
