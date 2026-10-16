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
 for i=1,math.max(#segments,#self.mapRouteLines) do
  local line=self.mapRouteLines[i]
  if not line and type(canvas.CreateLine)=='function' then
   line=canvas:CreateLine(nil,'ARTWORK')
   line:SetTexture('Interface\\Buttons\\WHITE8X8')
   self.mapRouteLines[i]=line
  end
  if line then
   local leg=segments[i]
   if leg then
    line:SetStartPoint('TOPLEFT',canvas,'TOPLEFT',leg.a.x*width,-leg.a.y*height)
    line:SetEndPoint('TOPLEFT',canvas,'TOPLEFT',leg.b.x*width,-leg.b.y*height)
    line:SetThickness(i==1 and 3 or 2)
    line:SetVertexColor(i==1 and 1 or .65,i==1 and .75 or .32,i==1 and .25 or 1,.92)
    line:Show()
   else line:Hide() end
  end
 end
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
 for i=1,math.min(250,#clusters) do points[#points+1]=clusters[i] end
 for i=1,math.max(#points,#self.mapPins) do
  local pin=self.mapPins[i]
  if not pin then
   pin=CreateFrame('Button',nil,canvas)
   pin:SetSize(7,7)
   pin.tex=pin:CreateTexture(nil,'ARTWORK')
   pin.tex:SetAllPoints()
   pin.label=pin:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
   pin.label:SetPoint('CENTER')
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
   pin:SetScript('OnLeave',function(p) p:SetSize(p.normalSize or 7,p.normalSize or 7); p.tex:SetAlpha(p.isRoute and 1 or .7); GameTooltip:Hide() end)
   self.mapPins[i]=pin
  end
  local p=points[i]
  if p then
   pin.node=p.n
   pin.isRoute=p.route or false
   pin.normalSize=p.route and 12 or math.max(5,math.min(16,tonumber(s.mapIconSize) or 7))
   pin:SetSize(pin.normalSize,pin.normalSize)
   pin.tex:SetAlpha(p.route and 1 or .7)
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
   pin:Show()
  else pin:Hide() end
 end
end
