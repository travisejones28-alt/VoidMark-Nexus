local _, N = ...

-- Clip in normalized minimap space before drawing: children are not clipped
-- by a Minimap mask, and outside-to-outside legs can still cross the viewport.
function N:ClipMinimapLeg(ax,ay,bx,by,square)
 local dx,dy=bx-ax,by-ay
 local low,high=0,1
 if square then
  local function edge(p,q)
   if p==0 then return q>=0 end
   local t=q/p
   if p<0 then low=math.max(low,t) else high=math.min(high,t) end
   return low<=high
  end
  if not edge(-dx,ax+1) or not edge(dx,1-ax) or not edge(-dy,ay+1) or not edge(dy,1-ay) then return end
 else
  local a=dx*dx+dy*dy
  if a==0 then if ax*ax+ay*ay>1 then return end
  else
   local b=2*(ax*dx+ay*dy);local c=ax*ax+ay*ay-1
   local disc=b*b-4*a*c;if disc<0 then return end
   local root=math.sqrt(disc)
   low=math.max(low,(-b-root)/(2*a));high=math.min(high,(-b+root)/(2*a))
   if low>high then return end
  end
 end
 return ax+dx*low,ay+dy*low,ax+dx*high,ay+dy*high
end
function N:MinimapStopTooltip(pin)
 local route=self.activeRoute
 local index=pin.stopIndex
 local p=route and route==pin.route and route.points[index]
 if not p or not GameTooltip then return end
 GameTooltip:SetOwner(pin,'ANCHOR_RIGHT')
 local resource=p.name or (p.object and self.nodeTypes[p.object] and self.nodeTypes[p.object].name) or 'Gathering stop'
 GameTooltip:SetText('Stop '..index..' / '..#route.points)
 GameTooltip:AddLine(resource,1,1,1)
 local map,x,y=self:Position()
 local w,h=route.width,route.height
 if not self:Finite(w,1,100000) or not self:Finite(h,1,100000) then w,h=self:MapSize(route.map) end
 if map==route.map and x and y and w and h then
  local distance=self:Distance({x=x,y=y},p,w,h)
  GameTooltip:AddLine(string.format('%.0f yards away',distance),.8,.8,.8)
 end
 GameTooltip:AddLine(index==(self.waypoint or 1) and 'Next gathering stop' or 'Upcoming gathering stop',1,.85,.35)
 GameTooltip:Show()
end
function N:HideMinimapRoute()
 if self.minimapRouteOverlay then self.minimapRouteOverlay:Hide() end
end
function N:UpdateMinimapRoute()
 local route=self.activeRoute
 if not self.ready or not Minimap or not Minimap:IsShown() or not route or not self.db.settings.routeVisible
  or not self.db.settings.minimapRoute then self:HideMinimapRoute();return end
 local map,x,y=self:Position()
 local radius=C_Minimap and self:Call(C_Minimap.GetViewRadius)
 if map~=route.map or not self:Finite(x,0,1) or not self:Finite(y,0,1)
  or not self:Finite(radius,1,100000) then self:HideMinimapRoute();return end
 local w,h=self:MapSize(map)
 if not w then self:HideMinimapRoute();return end
 local facing=0
 local rotating=GetCVarBool and self:Call(GetCVarBool,'rotateMinimap')
 if rotating and not (C_Minimap.IsRotateMinimapIgnored and self:Call(C_Minimap.IsRotateMinimapIgnored)) then
  facing=self:Call(GetPlayerFacing)
  if not self:Finite(facing,-100,100) then self:HideMinimapRoute();return end
 end
 local cos,sin=math.cos(facing),math.sin(facing)
 local width,height=Minimap:GetWidth()/2-2,Minimap:GetHeight()/2-2
 if width<=0 or height<=0 then self:HideMinimapRoute();return end
 if not self.minimapRouteOverlay then
  local f=CreateFrame('Frame',nil,Minimap);f:SetAllPoints(Minimap);f:EnableMouse(false)
  self.minimapRouteOverlay=f;self.minimapRouteLines={};self.minimapRouteDots={}
 end
 local overlay=self.minimapRouteOverlay
 overlay:SetFrameStrata(Minimap:GetFrameStrata())
 overlay:SetFrameLevel(Minimap:GetFrameLevel()+1);overlay:Show()
 local square=GetMinimapShape and GetMinimapShape()=='SQUARE'
 local function project(p)
  if not p or not self:Finite(p.x,0,1) or not self:Finite(p.y,0,1) then return end
  local dx,dy=(p.x-x)*w,(y-p.y)*h
  return (dx*cos+dy*sin)/radius,(-dx*sin+dy*cos)/radius
 end
 local geometry=route.travelPoints or route.points or {}
 local current=route.travelPoints and (self.terrainIndex or 1) or (self.waypoint or 1)
 local previous=geometry[current-1] or route.origin
 local used,dots=0,0
 local scale=Minimap:GetEffectiveScale() or 1
 local thickness=1.5/math.max(.25,scale)
 for i=current,math.min(#geometry,2048) do
  local p=geometry[i]
  local ax,ay=project(previous);local bx,by=project(p)
  if ax and bx and used<256 then
   ax,ay,bx,by=self:ClipMinimapLeg(ax,ay,bx,by,square)
   if ax and math.abs(ax-bx)+math.abs(ay-by)>1e-8 then
    used=used+1
    ax,ay,bx,by=ax*width,ay*height,bx*width,by*height
    local line=self.minimapRouteLines[used]
    if not line and not self.minimapLineUnavailable and type(overlay.CreateLine)=='function' then
     local ok,value=pcall(overlay.CreateLine,overlay,nil,'ARTWORK')
     if ok then line=value;self.minimapRouteLines[used]=line end
    end
    local destination=route.travelStopIndices and route.travelStopIndices[self.waypoint or 1]
    local nextLeg=i<=(destination or current)
    local red,green,blue,alpha=p.validated and .35 or .8,p.validated and .95 or .5,1,nextLeg and 1 or .35
    if nextLeg then red,green,blue=1,.85,.35 end
    local drawn=false
    if line then
     drawn=pcall(function()
      line:SetStartPoint('CENTER',Minimap,ax,ay)
      line:SetEndPoint('CENTER',Minimap,bx,by)
      line:SetThickness(nextLeg and thickness*1.25 or thickness)
      line:SetColorTexture(red,green,blue,alpha)
      line:Show()
     end)
     if not drawn then line:Hide() end
    end
    if not drawn then
     self.minimapLineUnavailable=true
     local dx,dy=bx-ax,by-ay
     local steps=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)/1.5))
     for step=0,math.min(steps,768-dots-1) do
      dots=dots+1;local dot=self.minimapRouteDots[dots]
      if not dot then dot=overlay:CreateTexture(nil,'ARTWORK');self.minimapRouteDots[dots]=dot end
      dot:SetSize(thickness,thickness);dot:ClearAllPoints()
      dot:SetPoint('CENTER',Minimap,'CENTER',ax+dx*step/steps,ay+dy*step/steps)
      dot:SetColorTexture(red,green,blue,alpha);dot:Show()
     end
    end
   end
  end
  previous=p
 end
 -- Number actual gathering stops, not intermediate terrain detours.
 self.minimapRoutePins=self.minimapRoutePins or {}
 local shown=0
 for index=self.waypoint or 1,math.min(#(route.points or {}),150) do
  local px,py=project(route.points[index])
  local margin=10/math.max(.25,scale)
  local inside=px and (square and math.abs(px*width)<=width-margin and math.abs(py*height)<=height-margin
   or not square and px*px+py*py<=(1-margin/math.min(width,height))^2)
  if inside then
   shown=shown+1
   local pin=self.minimapRoutePins[shown]
   if not pin then
    pin=CreateFrame('Frame',nil,overlay);pin:EnableMouse(true)
    pin:SetScript('OnEnter',function(self) N:MinimapStopTooltip(self) end)
    pin:SetScript('OnLeave',function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    pin.background=pin:CreateTexture(nil,'ARTWORK');pin.background:SetAllPoints(pin)
    if type(pin.CreateMaskTexture)=='function' then
     local mask=pin:CreateMaskTexture()
     if mask then
      mask:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask')
      mask:SetAllPoints(pin.background);pin.background:AddMaskTexture(mask);pin.mask=mask
     end
    end
    pin.label=pin:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    pin.label:SetPoint('CENTER');pin.label:SetShadowColor(0,0,0,1);pin.label:SetShadowOffset(1,-1)
    self.minimapRoutePins[shown]=pin
   end
   pin:SetSize(12/math.max(.25,scale),12/math.max(.25,scale))
   pin:SetFrameLevel(overlay:GetFrameLevel()+2)
   pin:ClearAllPoints();pin:SetPoint('CENTER',Minimap,'CENTER',px*width,py*height)
   pin.background:SetColorTexture(.12,.06,.2,index==(self.waypoint or 1) and .8 or .5)
   pin.stopIndex=index;pin.route=route
   pin.label:SetText(tostring(index));pin:Show()
  end
 end
 for i=shown+1,#self.minimapRoutePins do self.minimapRoutePins[i]:Hide() end
 for i=used+1,#self.minimapRouteLines do self.minimapRouteLines[i]:Hide() end
 for i=dots+1,#self.minimapRouteDots do self.minimapRouteDots[i]:Hide() end
end
local driver=CreateFrame('Frame')
local elapsed=0
driver:SetScript('OnUpdate',function(_,delta)
 elapsed=elapsed+delta;if elapsed<.1 then return end;elapsed=0
 if N.ready then N:Guard('minimap route',function() N:UpdateMinimapRoute() end) end
end)
