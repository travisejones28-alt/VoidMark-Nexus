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
-- Player-marked obstacles provide local geometry absent from the WoW map API.
-- Each circle uses normalized map coordinates and a radius in world yards.
function N:MarkRouteObstacle(radius)
 local map,x,y=self:Position()
 if not map then return self:Print('Current zone position unavailable.') end
 local r=math.max(15,math.min(500,tonumber(radius) or 90))
 self.db.terrainBlocks=self.db.terrainBlocks or {}
 local list=self.db.terrainBlocks[map] or {}
 if #list>=100 then return self:Print('Maximum 100 marked obstacles per zone.') end
 list[#list+1]={x=x,y=y,r=r}
 self.db.terrainBlocks[map]=list
 self.dirty=true
 self:Print('Marked obstacle ('..r..' yards) at your location. Regenerate route.')
end
function N:ClearRouteObstacles()
 local map=self:Position()
 if not map then return end
 self.db.terrainBlocks=self.db.terrainBlocks or {}
 self.db.terrainBlocks[map]=nil
 self.dirty=true
 self:Print('Cleared obstacle marks in this zone.')
end
function N:TerrainSegmentDistance(a,b,width,height,map)
 local direct=self:Distance(a,b,width,height)
 local blocks=self.db and self.db.terrainBlocks and self.db.terrainBlocks[map]
 if not blocks or #blocks==0 then return direct end
 local ax,ay=a.x*width,a.y*height
 local bx,by=b.x*width,b.y*height
 local vx,vy=bx-ax,by-ay
 local len2=vx*vx+vy*vy
 local cost=direct
 for _,o in ipairs(blocks) do
  local cx,cy=o.x*width,o.y*height
  local projection=len2>0 and math.max(0,math.min(1,((cx-ax)*vx+(cy-ay)*vy)/len2)) or 0
  local dx,dy=ax+projection*vx-cx,ay+projection*vy-cy
  if dx*dx+dy*dy<o.r*o.r then
   -- Large estimated detour cost discourages crossing a marked obstruction.
   cost=cost+math.max(200,o.r*6)
  end
 end
 return cost
end
function N:BuildRoute(nodes,start,width,height,s)
 if not width or not height then return nil,'Client map dimensions unavailable; cannot calculate reliable distance.' end
 -- The imported spawn database can contain several records for one farming patch.
 -- Collapse near-identical/adjacent candidates before constructing navigation.
 local function distance(a,b) return self:TerrainSegmentDistance(a,b,width,height,start.map) end
 local speed=math.max(1,s.speed)
 local stop=math.max(0,s.mountDelay)+math.max(0,s.gatherDelay)
 local spacing=math.max(40,math.min(85,speed*7)) -- 49 yards on foot, 78 on a 100% mount
 local candidates={}
 local ordered={}
 for _,node in ipairs(nodes) do
  local blocked=false
  for _,o in ipairs((self.db.terrainBlocks or {})[start.map] or {}) do
   if ((node.x-o.x)*width)^2+((node.y-o.y)*height)^2 < o.r*o.r then blocked=true; break end
  end
  if not blocked then ordered[#ordered+1]=node end
 end
 table.sort(ordered,function(a,b)
  local da=distance(a,start,width,height)
  local db=distance(b,start,width,height)
  if da==db then return (a.object or 0)<(b.object or 0) end
  return da<db
 end)
 for _,n in ipairs(ordered) do
  local nearby
  for _,c in ipairs(candidates) do
   if distance(c,n,width,height)<spacing then nearby=c; break end
  end
  if nearby then
   nearby.spawnCount=(nearby.spawnCount or 1)+1
   if nearby.source~='Observed' and n.source=='Observed' then
    nearby.x,nearby.y,nearby.name,nearby.object,nearby.source=n.x,n.y,n.name,n.object,n.source
   end
  else
   local copy=self:Copy(n)
   copy.spawnCount=1
   candidates[#candidates+1]=copy
  end
 end
 -- Try several constructive heuristics, then improve each closed circuit with 2-opt.
 -- All scoring uses Euclidean yard distances and real total loop duration.
 local limit=math.min(35,math.max(2,s.nodeLimit or 35))
 local budget=math.max(60,(s.routeMinutes or 15)*60)
 local function duration(path)
  local previous=start; local seconds=0
  for _,p in ipairs(path) do
   seconds=seconds+distance(previous,p,width,height)/speed+stop
   previous=p
  end
  return seconds+distance(previous,start,width,height)/speed
 end
 local function optimize(path)
  -- Full 2-opt on a bounded path, always including the closing edge.
  for pass=1,5 do
   local improved=false
   for i=1,#path-1 do
    for j=i+1,#path do
     local a=i==1 and start or path[i-1]
     local b=path[i]
     local c=path[j]
     local d=path[j+1] or start
     if distance(a,c,width,height)+distance(b,d,width,height)+.01 <
       distance(a,b,width,height)+distance(c,d,width,height) then
      local left,right=i,j
      while left<right do path[left],path[right]=path[right],path[left];left=left+1;right=right-1 end
      improved=true
     end
    end
   end
   if not improved then break end
  end
  return path
 end
 local function value(path)
  local seconds=duration(path)
  if seconds>budget+.01 or #path==0 then return -1,seconds end
  local observed=0
  for _,p in ipairs(path) do if p.source=='Observed' then observed=observed+1 end end
  -- Penalize tiny repeat circuits; density is not treated as extra spawns.
  local coverage=math.min(1,#path/10)
  local score=(#path+observed*.25)*coverage/math.max(600,seconds)
  return score,seconds
 end
 local best,bestScore,bestSeconds={},-1,0
 local strategies={{distance=1,returnWeight=.05},{distance=1,returnWeight=.35},
                   {distance=1,returnWeight=.75},{distance=1,returnWeight=.15,observed=12}}
 for _,mode in ipairs(strategies) do
  local path,used,last,elapsed={},{},start,0
  while #path<limit do
   local choice,choiceScore,choiceDistance
   for i,p in ipairs(candidates) do
    if not used[i] then
     local d=distance(last,p,width,height)
     local home=distance(p,start,width,height)
     if elapsed+d/speed+stop+home/speed<=budget then
      local score=d/speed+mode.returnWeight*home/speed
      if p.source=='Observed' then score=score-(mode.observed or 6) end
      if not choiceScore or score<choiceScore then
       choice,choiceScore,choiceDistance=i,score,d
      end
     end
    end
   end
   if not choice then break end
   local p=candidates[choice]
   path[#path+1]=p;used[choice]=true
   elapsed=elapsed+choiceDistance/speed+stop;last=p
  end
  optimize(path)
  -- A shorter loop may be more productive than simply filling all 35 slots.
  local evaluations={#path,math.floor(#path*.75),math.floor(#path*.5)}
  for _,count in ipairs(evaluations) do
   if count>0 then
    local trial={}
    for i=1,count do trial[i]=path[i] end
    optimize(trial)
    local score,seconds=value(trial)
    if score>bestScore then best,bestScore,bestSeconds=trial,score,seconds end
   end
  end
 end
 return {points=best,origin=self:Copy(start),seconds=bestSeconds,width=width,height=height,mode=s.travel,created=self:Now(),map=start.map,merged=true,optimizer='multi-seed-2opt-v4'}

end
-- Compare a small, geographically distributed set of candidate loop starts.
-- Scores are estimated stops/hour; imported points are potential, not live nodes.
function N:PlanRoute(strategy)
 local map,x,y=self:Position()
 if not map then return self:Print('Zone position unavailable.') end
 local nodes=self:ZoneNodes(map)
 if #nodes==0 then return self:Print('No matching gathering nodes in this zone.') end
 local w,h=self:MapSize(map)
 if not w then return self:Print('Map dimensions unavailable.') end
 local here={map=map,x=x,y=y}
 local settings=self.db.settings
 strategy=strategy or settings.routeStrategy or 'optimal'
 local starts={here}
 if strategy~='here' then
  starts={}
  -- Spatial spread yields diverse candidate loops without testing all spawns.
  local cells,ordered={},{}
  for _,p in ipairs(nodes) do
   local key=math.floor(p.x*4)..':'..math.floor(p.y*4)
   local cell=cells[key]
   if not cell then cell={point=p,count=0}; cells[key]=cell end
   cell.count=cell.count+1
  end
  for _,c in pairs(cells) do ordered[#ordered+1]=c end
  table.sort(ordered,function(a,b)
   if a.count~=b.count then return a.count>b.count end
   return (a.point.x+a.point.y)<(b.point.x+b.point.y)
  end)
  for i=1,math.min(7,#ordered) do
   local seed=ordered[i].point
   starts[#starts+1]={map=map,x=seed.x,y=seed.y}
  end
  if strategy=='nearest' then starts[#starts+1]=here end
 end
 local best,bestScore
 for _,origin in ipairs(starts) do
  local route=self:BuildRoute(nodes,origin,w,h,settings)
  if route and #route.points>0 then
   local seconds=math.max(1,route.seconds or settings.routeMinutes*60)
   local travel=self:Distance(here,origin,w,h)/math.max(1,settings.speed)
   -- For 'nearest', include getting to the circuit; for 'optimal', do not.
   local denominator=seconds+(strategy=='nearest' and travel or 0)
   local coverage=math.min(1,#route.points/12)
   local score=(#route.points*coverage)/math.max(600,denominator)
   if not bestScore or score>bestScore then best,bestScore=route,score end
  end
 end
 if not best then return self:Print('No circuit fits your filters and time budget.') end
 best.strategy=strategy
 best.estimatedStopsPerHour=bestScore*3600
 return best
end
-- Cross-zone comparisons are based on accessible imported coordinates, not active spawns.
function N:RankResourceZones(resource)
 if not resource or resource=='' then return {} end
 local maps={}
 for object,kind in pairs(self.nodeTypes or {}) do
  if kind.name==resource then
   for map,points in pairs((self.spawns or {})[object] or {}) do
    if not self:IsGatheringCityMap(map) and type(points)=='table' then
     maps[map]=(maps[map] or 0)+math.floor(#points/2)
    end
   end
  end
 end
 local eligible={}
 for map,count in pairs(maps) do if count>=4 then eligible[#eligible+1]={map=map,count=count} end end
 table.sort(eligible,function(a,b) return a.count>b.count end)
 -- Preselect up to 20 plausible zones before running the expensive optimizer.
 local results={}
 for index=1,math.min(20,#eligible) do
  local map=eligible[index].map
  local width,height=self:MapSize(map)
  if width and height then
   local nodes=self:ZoneNodes(map,'all',resource)
   local cells={}
   for _,node in ipairs(nodes) do
    local cell=math.floor(node.x*5)..':'..math.floor(node.y*5)
    local item=cells[cell]
    if not item then item={point=node,count=0};cells[cell]=item end
    item.count=item.count+1
   end
   local seeds={}
   for _,item in pairs(cells) do seeds[#seeds+1]=item end
   table.sort(seeds,function(a,b)
    if a.count~=b.count then return a.count>b.count end
    if a.point.x~=b.point.x then return a.point.x<b.point.x end
    return a.point.y<b.point.y
   end)
   local best,bestScore
   for j=1,math.min(5,#seeds) do
    local start=seeds[j].point
    local route=self:BuildRoute(nodes,{map=map,x=start.x,y=start.y},width,height,self.db.settings)
    if route and #route.points>=3 then
     local seconds=math.max(600,route.seconds)
     local observed=0
     for _,p in ipairs(route.points) do if p.source=='Observed' then observed=observed+1 end end
     local coverage=math.min(1,#route.points/10)
     local score=(#route.points+observed*.25)*coverage/seconds
     if not bestScore or score>bestScore then best,bestScore=route,score end
    end
   end
   if best then
    local name='Zone '..map
    if C_Map and type(C_Map.GetMapInfo)=='function' then
     local info=self:Call(C_Map.GetMapInfo,map)
     if info and type(info.name)=='string' then name=info.name end
    end
    results[#results+1]={map=map,name=name,route=best,score=bestScore*3600,rawCount=eligible[index].count}
   end
  end
 end
 table.sort(results,function(a,b)
  if a.score==b.score then return a.map<b.map end
  return a.score>b.score
 end)
 while #results>5 do table.remove(results) end
 return results
end
function N:GenerateRoute()
 local best=self:PlanRoute()
 if not best then return end
 self.activeRoute=best; self.waypoint=1; self.dirty=true; self:ShowArrow()
 self:Print(string.format('%s: %d stops, approx %.1f minute loop (straight-line estimate).',best.strategy,#best.points,(best.seconds or 0)/60))
end
function N:SkipWaypoint()
 if not self.activeRoute then return end
 self.waypoint=(self.waypoint or 1)+1
 if self.waypoint>#self.activeRoute.points then self.activeRoute=nil; if self.arrow then self.arrow:Hide() end; self:Print('Route complete.') end
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
local function nexusAngle(y,x)
 if math.atan2 then return math.atan2(y,x) end
 if x==0 then return y>=0 and math.pi/2 or -math.pi/2 end
 local n=math.atan(y/x)
 if x<0 then n=n+math.pi end
 return n
end
local function nexusDeltaAngle(a,b)
 return (b-a+math.pi)%(2*math.pi)-math.pi
end
function N:ShowArrow()
 if not self.arrow then
  local f=CreateFrame('Frame','VoidMarkNexusArrow',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
  f:SetSize(152,100)
  f:SetPoint('TOP',UIParent,'TOP',0,-135)
  f:SetFrameStrata('HIGH')
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function(w) w:StartMoving() end)
  f:SetScript('OnDragStop',function(w) w:StopMovingOrSizing() end)
  if f.SetBackdrop then f:SetBackdrop(nil) end
  local top=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
  top:SetPoint('TOPLEFT',8,-6); top:SetText('|cffad9bbfRoute|r')
  -- Compact directional pointer without a compass ring or cardinal lettering.
  f.texture=f:CreateTexture(nil,'ARTWORK')
  f.texture:SetSize(40,40); f.texture:SetPoint('TOP',0,-20)
  f.texture:SetTexture('Interface\\Minimap\\MinimapArrow')
  f.texture:SetVertexColor(.72,.57,.86,.95)
  f.label=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  f.label:SetPoint('BOTTOM',0,12); f.label:SetWidth(146)
  f.label:SetJustifyH('CENTER')
  f.angle=nil
  local function menu()
   N:Choice(f,{
    {label='Skip waypoint',value='skip'},
    {label='Restart from waypoint 1',value='restart'},
    {label='Cancel route',value='cancel'}
   },function(action)
    if action=='skip' then N:SkipWaypoint()
    elseif action=='restart' and N.activeRoute then N.waypoint=1; N.dirty=true
    elseif action=='cancel' then N.activeRoute=nil; N.waypoint=nil; f:Hide(); N.dirty=true end
    f.refreshAt=0
    if WorldMapFrame and WorldMapFrame:IsShown() then N:RefreshMap() end
   end)
   -- Close the menu without affecting the active navigation.
   if N.menu then
    local close=CreateFrame('Button',nil,N.menu,'UIPanelCloseButton')
    close:SetSize(24,24)
    close:SetPoint('TOPRIGHT',N.menu,'TOPRIGHT',2,2)
    close:SetFrameLevel(N.menu:GetFrameLevel()+5)
    close:SetScript('OnClick',function() N.menu:Hide() end)
   end
  end
  f:SetScript('OnMouseUp',function(_,button) if button=='RightButton' then menu() end end)
  f:SetScript('OnEnter',function()
   GameTooltip:SetOwner(f,'ANCHOR_RIGHT')
   GameTooltip:SetText('VoidMark Nexus navigation')
   GameTooltip:AddLine('Right-click: Skip / Restart / Cancel')
   GameTooltip:AddLine('Left-drag: Move',.8,.8,.8)
   GameTooltip:Show()
  end)
  f:SetScript('OnLeave',function() GameTooltip:Hide() end)
  -- Smooth facing updates every frame; update expensive map coordinates 10x/sec.
  f.refreshAt=0
  f:SetScript('OnUpdate',function(w,dt)
   w.refreshAt=w.refreshAt-dt
   if w.refreshAt<=0 then
    w.refreshAt=.10
    N:Guard('navigation',function() N:UpdateArrow() end)
   end
   local facing=N:Call(GetPlayerFacing)
   if w.bearing and N:Finite(facing,-10,10) then
    local goal=w.bearing-facing
    if not w.angle then w.angle=goal end
    local fraction=math.min(1,dt*13)
    w.angle=w.angle+nexusDeltaAngle(w.angle,goal)*fraction
    w.texture:SetRotation(w.angle)
   end
  end)
  self.arrow=f
 end
 self.arrow.refreshAt=0
 self.arrow:Show()
end
function N:UpdateArrow()
 local arrow=self.arrow
 if not arrow then return end
 local route=self.activeRoute
 local point=route and route.points[self.waypoint or 1]
 if not point or not self.db.settings.routeVisible then arrow:Hide(); return end
 local map,x,y=self:Position()
 if map~=route.map or not x or not y then
  arrow.label:SetText('Return to route zone')
  arrow.texture:Hide()
  arrow.bearing=nil
  return
 end
 local dx=(point.x-x)*route.width
 local dy=(point.y-y)*route.height
 local distance=math.sqrt(dx*dx+dy*dy)
 arrow.bearing=nexusAngle(-dx,-dy)
 arrow.texture:Show()
 arrow.label:SetText(string.format('%s  |  %d/%d\n%.0f yd · ~%.0f sec',point.name or 'Waypoint',self.waypoint,#route.points,distance,distance/math.max(1,self.db.settings.speed)))
 if distance<8 then self:SkipWaypoint(); arrow.refreshAt=0 end
end
-- Item IDs are the gathered resources, not world object/spawn IDs.
-- Prefer item icons from the client and use distinct inventory textures when uncached.
local nexusNodeIcons = {
 ["Peacebloom"]=2447, ["Silverleaf"]=765, ["Earthroot"]=2449,
 ["Mageroyal"]=785, ["Briarthorn"]=2450, ["Stranglekelp"]=3820,
 ["Bruiseweed"]=2453, ["Wild Steelbloom"]=3355, ["Grave Moss"]=3369,
 ["Kingsblood"]=3356, ["Liferoot"]=3357, ["Fadeleaf"]=3818,
 ["Goldthorn"]=3821, ["Khadgar's Whisker"]=3358, ["Wintersbite"]=3819,
 ["Firebloom"]=4625, ["Purple Lotus"]=8831, ["Arthas' Tears"]=8836,
 ["Sungrass"]=8838, ["Blindweed"]=8839, ["Ghost Mushroom"]=8845,
 ["Gromsblood"]=8846, ["Golden Sansam"]=13464, ["Dreamfoil"]=13463,
 ["Mountain Silversage"]=13465, ["Plaguebloom"]=13466, ["Icecap"]=13467,
 ["Black Lotus"]=13468,
 ["Copper Vein"]=2770, ["Tin Vein"]=2771, ["Silver Vein"]=2775,
 ["Iron Deposit"]=2772, ["Gold Vein"]=2776, ["Mithril Deposit"]=3858,
 ["Truesilver Deposit"]=7911, ["Dark Iron Deposit"]=11370,
 ["Small Thorium Vein"]=10620, ["Rich Thorium Vein"]=10620,
 ["Incendicite Mineral Vein"]=3340, ["Lesser Bloodstone Deposit"]=4278,
 ["Indurium Mineral Vein"]=5833, ["Hakkari Thorium Vein"]=10620,
 ["Small Obsidian Chunk"]=22202, ["Large Obsidian Chunk"]=22203
}
local nexusNodeFallback = {
 ["Peacebloom"]='Interface\\Icons\\INV_Misc_Flower_02',
 ["Silverleaf"]='Interface\\Icons\\INV_Misc_Herb_10',
 ["Earthroot"]='Interface\\Icons\\INV_Misc_Herb_07',
 ["Mageroyal"]='Interface\\Icons\\INV_Jewelry_Talisman_03',
 ["Briarthorn"]='Interface\\Icons\\INV_Misc_Root_01',
 ["Copper Vein"]='Interface\\Icons\\INV_Ore_Copper_01',
 ["Tin Vein"]='Interface\\Icons\\INV_Ore_Tin_01',
 ["Silver Vein"]='Interface\\Icons\\INV_Ore_Silver_01',
 ["Iron Deposit"]='Interface\\Icons\\INV_Ore_Iron_01',
 ["Gold Vein"]='Interface\\Icons\\INV_Ore_Gold_01',
 ["Mithril Deposit"]='Interface\\Icons\\INV_Ore_Mithril_01',
 ["Truesilver Deposit"]='Interface\\Icons\\INV_Ore_TrueSilver_01'
}
local nexusGenericHerb='Interface\\Icons\\INV_Misc_Herb_01'
local nexusGenericOre='Interface\\Icons\\INV_Ore_Copper_01'
local function nexusResourceIcon(node)
 local name=node.name or ''
 local id=nexusNodeIcons[name]
 local texture
 if id then
  if C_Item and type(C_Item.GetItemIconByID)=='function' then
   local ok,result=pcall(C_Item.GetItemIconByID,id)
   if ok then texture=result end
  end
  if not texture and type(GetItemIcon)=='function' then
   local ok,result=pcall(GetItemIcon,id)
   if ok then texture=result end
  end
  if not texture and type(GetItemInfoInstant)=='function' then
   local ok,_,_,_,_,icon=pcall(GetItemInfoInstant,id)
   if ok then texture=icon end
  end
 end
 return texture or nexusNodeFallback[name] or (node.kind=='ore' and nexusGenericOre or nexusGenericHerb)
end
-- Shared with the Routes tab, so list rows use the same resource artwork as map pins.
function N:ResourceNodeIcon(node)
 if type(node)~='table' then return 'Interface\\Icons\\INV_Misc_Map_01' end
 return nexusResourceIcon(node)
end
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
 -- Compact map-size slider, stored in account settings.
 if not self.mapIconSizeSlider then
  local slider=CreateFrame('Slider',nil,canvas,'OptionsSliderTemplate')
  slider:SetSize(120,16)
  slider:SetPoint('TOPLEFT',canvas,'TOPLEFT',18,-49)
  slider:SetMinMaxValues(5,16); slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetScript('OnValueChanged',function(_,value)
   local n=math.floor(value+0.5)
   if N.db.settings.mapIconSize~=n then
    N.db.settings.mapIconSize=n
    N:RefreshMap()
   end
  end)
  local caption=canvas:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
  caption:SetPoint('BOTTOM',slider,'TOP',0,3)
  slider.caption=caption
  self.mapIconSizeSlider=slider
 end
 local selectedSize=math.max(5,math.min(16,tonumber(s.mapIconSize) or 7))
 self.mapIconSizeSlider.caption:SetText('Icon size: '..selectedSize)
 self.mapIconSizeSlider:SetValue(selectedSize)
 self.mapIconSizeSlider:SetShown(filter~='none' and s.nodesVisible)
 self.mapNodeFilterButton:SetText('Nexus: '..(names[filter] or names.all)..'  v')
 self.mapNodeFilterButton:Show()
 -- Make active-route map selection explicit instead of silently hiding it.
 if not self.mapActiveRouteButton then
  local b=CreateFrame('Button',nil,canvas,'UIPanelButtonTemplate')
  b:SetSize(165,23)
  b:SetPoint('TOPLEFT',canvas,'TOPLEFT',162,-12)
  b:SetFrameStrata('HIGH')
  b:SetScript('OnClick',function()
   local route=N.activeRoute
   if route and WorldMapFrame and WorldMapFrame.SetMapID then
    WorldMapFrame:SetMapID(route.map)
    N:RefreshMap()
   end
  end)
  self.mapActiveRouteButton=b
 end
 local active=self.activeRoute
 if active and active.map then
  local info=C_Map and C_Map.GetMapInfo and self:Call(C_Map.GetMapInfo,active.map)
  local name=info and info.name or ('Zone '..tostring(active.map))
  self.mapActiveRouteButton:SetText(active.map==map and ('Route: '..name..' ('..tostring(#(active.points or {}))..' stops)') or ('View route: '..name))
  self.mapActiveRouteButton:Show()
 else
  self.mapActiveRouteButton:Hide()
 end
 local nodes={}
 if s.nodesVisible and filter~='none' then
  -- Map display filters must NOT change the independent route-planning filter.
  for _,node in ipairs(self:ZoneNodes(map,'all','')) do
   if filter=='all' or node.kind==filter then nodes[#nodes+1]=node end
  end
 end
 self.mapPins=self.mapPins or {}
 local width,height=canvas:GetWidth(),canvas:GetHeight()
 if width<=0 or height<=0 then return end
 -- Only the next five waypoints and connecting legs appear on the world map.
 -- Navigation retains every waypoint in the underlying route.
 self.mapRouteLines=self.mapRouteLines or {}
 local route=self.activeRoute
 local points={}
 local segments={}
 if s.routeVisible and route and route.map==map then
  local current=math.max(1,self.waypoint or 1)
  local last=math.min(#route.points,current+4)
  local prev
  -- Starting at the player's live map position avoids a line to an old origin.
  local liveMap,px,py=self:Position()
  if liveMap==map and px and py then prev={x=px,y=py}
  else prev=route.points[current-1] or route.origin end
  for i=current,last do
   local node=route.points[i]
   if node then
    points[#points+1]={n=node,label=tostring(i),route=true}
    if prev then segments[#segments+1]={a=prev,b=node} end
    prev=node
   end
  end
 end
 -- Some Forever builds expose Line regions but reject one of their methods.
 -- Never let decorative route strokes stop waypoint pins from rendering.
 for i=1,math.max(#segments,#self.mapRouteLines) do
  local line=self.mapRouteLines[i]
  if not line and segments[i] and type(canvas.CreateLine)=='function' then
   local ok,created=pcall(canvas.CreateLine,canvas,nil,'ARTWORK')
   if ok and created then line=created; self.mapRouteLines[i]=line end
  end
  if line then
   local leg=segments[i]
   if leg then
    local ok=pcall(function()
     line:SetStartPoint('TOPLEFT',canvas,'TOPLEFT',leg.a.x*width,-leg.a.y*height)
     line:SetEndPoint('TOPLEFT',canvas,'TOPLEFT',leg.b.x*width,-leg.b.y*height)
     line:SetThickness(i==1 and 3 or 2)
     if line.SetTexture then line:SetTexture('Interface\\Buttons\\WHITE8X8') end
     line:SetVertexColor(i==1 and 1 or .65,i==1 and .75 or .32,i==1 and .25 or 1,.92)
     line:Show()
    end)
    if not ok then line:Hide() end
   else line:Hide() end
  end
 end
 -- Dot texture fallback: several Forever builds expose CreateLine but cannot draw
 -- correctly on the world-map canvas. Keep at most four short, clipped segments.
 self.mapRouteDots=self.mapRouteDots or {}
 local usedDots=0
 for _,leg in ipairs(segments) do
  local ax,ay=leg.a.x*width,leg.a.y*height
  local bx,by=leg.b.x*width,leg.b.y*height
  local dx,dy=bx-ax,by-ay
  local distance=math.sqrt(dx*dx+dy*dy)
  local count=math.min(70,math.floor(distance/6))
  for j=0,count do
   local t=j/math.max(1,count)
   local x,y=ax+dx*t,ay+dy*t
   if x>=0 and y>=0 and x<=width and y<=height then
    usedDots=usedDots+1
    local dot=self.mapRouteDots[usedDots]
    if not dot then
     dot=canvas:CreateTexture(nil,'OVERLAY')
     dot:SetTexture('Interface\\Buttons\\WHITE8X8')
     dot:SetSize(3,3)
     self.mapRouteDots[usedDots]=dot
    end
    dot:ClearAllPoints()
    dot:SetPoint('CENTER',canvas,'TOPLEFT',x,-y)
    dot:SetVertexColor(.73,.37,1,.96)
    dot:Show()
   end
  end
 end
 for i=usedDots+1,#self.mapRouteDots do self.mapRouteDots[i]:Hide() end
 -- Merge nearby display-only markers; keep full node records for farming calculations.
 local clusters={}
 for _,node in ipairs(nodes) do
  local match
  for _,c in ipairs(clusters) do
   local dx=(node.x-c.n.x)*width
   local dy=(node.y-c.n.y)*height
   if dx*dx+dy*dy<64 then match=c; break end
  end
  if match then
   match.count=match.count+1
   match.names[node.name or 'Unknown']=true
   -- Prefer observed node information over imported potential spawns.
   if node.source=='Observed' and match.n.source~='Observed' then match.n=node end
  else
   clusters[#clusters+1]={n=node,label='',count=1,names={[node.name or 'Unknown']=true}}
  end
 end
 -- Keep the map-wide distribution instead of only taking the first 250
 -- database records (which are grouped by object ID/region). Pick one from
 -- each spatial bucket per pass so distant areas stay represented.
 local buckets,order={},{}
 for _,c in ipairs(clusters) do
  local key=math.floor(c.n.x*12)..':'..math.floor(c.n.y*12)
  if not buckets[key] then buckets[key]={};order[#order+1]=key end
  buckets[key][#buckets[key]+1]=c
 end
 table.sort(order)
 for _,key in ipairs(order) do
  table.sort(buckets[key],function(a,b)
   if (a.n.source=='Observed')~=(b.n.source=='Observed') then return a.n.source=='Observed' end
   return a.count>b.count
  end)
 end
 local pass=1
 while #points<250 do
  local added=false
  for _,key in ipairs(order) do
   local c=buckets[key][pass]
   if c and #points<250 then points[#points+1]=c;added=true end
  end
  if not added then break end
  pass=pass+1
 end
 for i=1,math.max(#points,#self.mapPins) do
  local pin=self.mapPins[i]
  if not pin then
   pin=CreateFrame('Button',nil,canvas)
   pin:SetSize(7,7)
   pin.tex=pin:CreateTexture(nil,'OVERLAY',nil,5)
   pin.tex:SetAllPoints()
   pin.label=pin:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
   pin.label:SetPoint('CENTER')
   pin.label:SetDrawLayer('OVERLAY',7)
   pin:SetScript('OnEnter',function(p)
    p:SetSize(16,16)
    p.tex:SetAlpha(1)
    GameTooltip:SetOwner(p,'ANCHOR_RIGHT')
    GameTooltip:SetText(p.node.name or 'Waypoint')
    GameTooltip:AddLine(p.node.source or 'Route')
    if p.clusterCount and p.clusterCount>1 then
     GameTooltip:AddLine(tostring(p.clusterCount)..' nearby spawn records')
     if p.clusterNames then for name in pairs(p.clusterNames) do GameTooltip:AddLine(name,1,0.85,0.45) end end
    end
    GameTooltip:Show()
   end)
   pin:SetScript('OnLeave',function(p) p:SetSize(p.normalSize or 7,p.normalSize or 7); p.tex:SetAlpha(1); GameTooltip:Hide() end)
   self.mapPins[i]=pin
  end
  local p=points[i]
  if p then
   pin.node=p.n
   pin.isRoute=p.route or false
   pin:SetFrameLevel(math.max(canvas:GetFrameLevel(),world:GetFrameLevel())+(p.route and 110 or 90))
   pin.normalSize=p.route and 24 or math.max(5,math.min(16,tonumber(s.mapIconSize) or 7))
   pin:SetSize(pin.normalSize,pin.normalSize)
   pin.tex:SetAlpha(1)
   if p.route then pin.label:SetTextColor(1,.95,.1,1) end
   pin.clusterCount=p.count
   pin.clusterNames=p.names
   pin:ClearAllPoints()
   pin:SetPoint('CENTER',canvas,'TOPLEFT',p.n.x*width,-p.n.y*height)
   local texture
   if p.route then texture='Interface\\Icons\\INV_Misc_Map_01'
   else
    texture=nexusResourceIcon(p.n)
   end
   pin.tex:SetTexture(texture)
   pin.label:SetText(p.label)
   if p.route then pin.label:SetFontObject('GameFontNormalLarge') else pin.label:SetFontObject('GameFontNormalSmall') end
   pin:Show()
  else pin:Hide() end
 end
end
