local _, N = ...
local tabs={'Home','Professions','Leveling','Recipes','Crafting','Gathering','Inventory','Characters','Settings'}
-- Older tab names still open the merged tab.
local tabAlias={Dashboard='Home',Profitability='Recipes',Routes='Gathering'}
local function label(parent,text,x,y,size)
 local f=parent:CreateFontString(nil,'OVERLAY',size or 'GameFontNormal'); f:SetPoint('TOPLEFT',x,y); f:SetText(text); f:SetJustifyH('LEFT'); return f
end
local function button(parent,text,x,y,width,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate'); b:SetSize(width,24); b:SetPoint('TOPLEFT',x,y); b:SetText(text)
 b:SetScript('OnClick',function() N:Guard(text,fn) end); return b
end
local function edit(parent,x,y,width,text)
 local e=CreateFrame('EditBox',nil,parent,'InputBoxTemplate'); e:SetSize(width,24); e:SetPoint('TOPLEFT',x,y); e:SetAutoFocus(false); e:SetText(text or '')
 e:SetScript('OnEscapePressed',function() e:ClearFocus() end); return e
end
local function skin(f)
 if f.SetBackdrop then
  f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
  f:SetBackdropColor(.035,.025,.06,.97); f:SetBackdropBorderColor(.48,.25,.72,1)
 end
end
function N:Choice(anchor,choices,fn)
 if self.menu then self.menu:Hide() end
 local menu=CreateFrame('Frame',nil,UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil); skin(menu)
 menu:SetFrameStrata('DIALOG'); menu:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT'); menu:SetSize(270,math.min(15,#choices)*25+10)
 local scroll=CreateFrame('ScrollFrame',nil,menu,'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',4,-4); scroll:SetPoint('BOTTOMRIGHT',-26,4)
 local child=CreateFrame('Frame',nil,scroll); child:SetSize(235,#choices*25); scroll:SetScrollChild(child)
 for i,c in ipairs(choices) do
  local y=-(i-1)*25
  if c.decrease and c.increase then
   label(child,c.label,10,y-5,'GameFontHighlight')
   local minus=button(child,'-',143,y,38,c.decrease)
   local plus=button(child,'+',187,y,38,c.increase)
   menu.adjustments=menu.adjustments or {}
   menu.adjustments[#menu.adjustments+1]={minus=minus,plus=plus}
  else
   button(child,c.label,0,y,230,function() menu:Hide(); fn(c.value); N.dirty=true end)
  end
 end
 self.menu=menu
end
function N:TextDialog(title,text,import)
 if not self.dialog then
  local f=CreateFrame('Frame','VoidMarkNexusTransfer',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil); skin(f)
  f:SetSize(720,480); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG'); f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function() f:StartMoving() end); f:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
  f.title=label(f,'',16,-16); button(f,'Close',610,-10,90,function() f:Hide(); N.pendingImport=nil end)
  local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',18,-50); scroll:SetPoint('BOTTOMRIGHT',-35,65)
  local e=CreateFrame('EditBox',nil,scroll); e:SetWidth(650); e:SetMultiLine(true); e:SetFontObject('ChatFontNormal'); e:SetAutoFocus(false); e:SetMaxLetters(2000000); scroll:SetScrollChild(e)
  e:SetScript('OnTextChanged',function() N.pendingImport=nil end)
  e:SetScript('OnEscapePressed',function() e:ClearFocus() end); f.edit=e
  f.preview=button(f,'Preview import',18,-438,160,function()
   local preview,err
   if f.importMode=='route' then preview,err=N:PreviewRouteImport(e:GetText()) else preview,err=N:PreviewImport(e:GetText()) end; f.status:SetText(preview and 'Review changes above, then confirm. Close to cancel.' or tostring(err))
   if preview then local pending=N.pendingImport; e:SetText(preview); N.pendingImport=pending; f.preview:Disable(); N.importPreview=preview; f.confirm:Enable() else f.confirm:Disable() end
  end)
  f.confirm=button(f,'Confirm import',188,-438,160,function() N:ConfirmImport(); f:Hide() end)
  f.status=label(f,'',18,-408,'GameFontHighlightSmall'); f.status:SetWidth(670)
  f.review=button(f,'View preview',358,-438,150,function() if N.importPreview then N:Print(N.importPreview) end end)
  self.dialog=f
 end
 local f=self.dialog; f.importMode=import;N.pendingImport=nil; f.title:SetText(title); f.edit:SetText(text or ''); f.edit:HighlightText(); f.confirm:Disable()
 f.preview:SetShown(import==true or import=='route'); f.confirm:SetShown(import==true or import=='route'); f.review:SetShown(import==true or import=='route')
 f.preview:Enable(); f.status:SetText(import and 'Paste VMN1 export, then preview and review before confirming.' or 'Ctrl+A, Ctrl+C to copy.'); f:Show()
end
function N:Show(tab)
 if not self.ui then self:CreateUI() end
 self.ui.tab=tabAlias[tab] or tab or self.ui.tab or 'Home'; self.ui.frame:Show(); self.dirty=true; self:Render()
end
-- Prefer the client's direct item-icon APIs, which work before item cache is populated.
function N:InventoryIcon(id)
 id=tonumber(id)
 if not id then return nil end
 if C_Item and type(C_Item.GetItemIconByID)=='function' then
  local icon=self:Call(C_Item.GetItemIconByID,id)
  if icon then return icon end
 end
 if type(GetItemInfoInstant)=='function' then
  local _,_,_,_,icon=self:Call(GetItemInfoInstant,id)
  if icon then return icon end
 end
 if type(GetItemIcon)=='function' then
  local icon=self:Call(GetItemIcon,id)
  if icon then return icon end
 end
 if type(GetItemInfo)=='function' then
  local _,_,_,_,_,_,_,_,_,icon=self:Call(GetItemInfo,id)
  if icon then return icon end
 end
 return nil
end
function N:ShowResourcePicker()
 local entries={}
 for _,node in pairs(self.nodeTypes or {}) do entries[node.name]=node.kind end
 local names={}
 for name in pairs(entries) do names[#names+1]=name end
 table.sort(names)
 if self.resourcePicker then self.resourcePicker:Hide() end
 local f=CreateFrame('Frame',nil,UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
 skin(f); f:SetSize(385,500); f:SetPoint('CENTER'); f:SetFrameStrata('FULLSCREEN_DIALOG')
 f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function(w) w:StartMoving() end)
 f:SetScript('OnDragStop',function(w) w:StopMovingOrSizing() end)
 local title=label(f,'NEXUS | MULTI-RESOURCE ROUTE',16,-16,'GameFontNormal')
 title:SetTextColor(1,.8,.15)
 local stored=self.db.settings.routeResources
 local pending={}
 if type(stored)=='table' then for k,v in pairs(stored) do if v then pending[k]=true end end end
 local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate')
 scroll:SetPoint('TOPLEFT',16,-48); scroll:SetPoint('BOTTOMRIGHT',-32,58)
 local child=CreateFrame('Frame',nil,scroll); child:SetSize(325,math.max(1,#names)*26); scroll:SetScrollChild(child)
 local boxes={}
 for i,name in ipairs(names) do
  local cb=CreateFrame('CheckButton',nil,child,'UICheckButtonTemplate')
  cb:SetSize(24,24); cb:SetPoint('TOPLEFT',4,-(i-1)*26)
  cb:SetChecked(pending[name]==true)
  cb:SetScript('OnClick',function(w) pending[name]=w:GetChecked() and true or nil end)
  local txt=label(child,name,33,-(i-1)*26-5,'GameFontHighlightSmall')
  boxes[#boxes+1]=cb
 end
 button(f,'All herbs',15,-462,82,function()
  for i,name in ipairs(names) do if entries[name]=='herb' then pending[name]=true; boxes[i]:SetChecked(true) end end
 end)
 button(f,'All ore',103,-462,75,function()
  for i,name in ipairs(names) do if entries[name]=='ore' then pending[name]=true; boxes[i]:SetChecked(true) end end
 end)
 button(f,'Clear',184,-462,65,function()
  for i,name in ipairs(names) do pending[name]=nil; boxes[i]:SetChecked(false) end
 end)
 button(f,'Apply',255,-462,55,function()
  N.db.settings.kind='all'; N.db.settings.target=''
  N.db.settings.routeSelectionMode='multi'
  N.db.settings.routeResources=pending
  if N.ui then N.ui.page=1; N.ui.selected=nil end
  N.dirty=true; f:Hide()
 end)
 button(f,'X',340,-10,32,function() f:Hide() end)
 self.resourcePicker=f
end

-- Schematic zone-coordinate route preview; never claims to show terrain or roads.
function N:ShowRoutePreview(strategy,displayMode,prebuiltRoute)
 if not prebuiltRoute then
  return self:RunPlanner(function() return self:PlanRoute(strategy) end,function(route)
   if route then self:ShowRoutePreview(strategy,displayMode,route) end
  end)
 end
 local route=prebuiltRoute or self:PlanRoute(strategy)
 if not route then return end
 local map,x,y=self:Position()
 if map and x and y then self:StartRouteAtNearest(route,{map=map,x=x,y=y}) end
 displayMode=displayMode or self.db.settings.previewMode or 'map'
 if self.previewWindow then self.previewWindow:Hide() end
 local w=CreateFrame('Frame',nil,UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
 skin(w); w:SetSize(530,540); w:SetPoint('CENTER'); w:SetFrameStrata('FULLSCREEN_DIALOG')
 w:EnableMouse(true); w:SetMovable(true); w:RegisterForDrag('LeftButton')
 w:SetScript('OnDragStart',function(a) a:StartMoving() end)
 w:SetScript('OnDragStop',function(a) a:StopMovingOrSizing() end)
 label(w,'VOIDMARK | PROJECTED ROUTE',16,-14)
 button(w,'X',484,-10,35,function() w:Hide() end)
 local title=label(w,string.format('%s  |  %d stops  |  ~%.1f min/loop',({optimal='Optimal Loop',nearest='Nearest Loop',here='Start Here'})[route.strategy] or 'Route',#route.points,(route.seconds or 0)/60),16,-40,'GameFontHighlight')
 title:SetWidth(490)
 local canvas=CreateFrame('Frame',nil,w,BackdropTemplateMixin and 'BackdropTemplate' or nil)
 canvas:SetSize(448,380); canvas:SetPoint('TOPLEFT',40,-70)
 skin(canvas)
 -- Render the exact C_Map tile artwork used by the World Map where supported.
 -- Tile coordinates are proportional to the entire zone, not to the route bounds.
 local artLoaded=false
 local origin=route.origin
 local all={origin}
 for _,p in ipairs(route.travelPoints or route.points) do all[#all+1]=p end
 local boundMinX,boundMaxX,boundMinY,boundMaxY=1,0,1,0
 for _,p in ipairs(all) do
  boundMinX=math.min(boundMinX,p.x); boundMaxX=math.max(boundMaxX,p.x)
  boundMinY=math.min(boundMinY,p.y); boundMaxY=math.max(boundMaxY,p.y)
 end
 local padX=math.max(.02,(boundMaxX-boundMinX)*.13)
 local padY=math.max(.02,(boundMaxY-boundMinY)*.13)
 local viewX1=math.max(0,boundMinX-padX)
 local viewX2=math.min(1,boundMaxX+padX)
 local viewY1=math.max(0,boundMinY-padY)
 local viewY2=math.min(1,boundMaxY+padY)
 local zoomX,zoomY=448/math.max(.02,viewX2-viewX1),380/math.max(.02,viewY2-viewY1)
 if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
 if displayMode=='map' and C_Map and type(C_Map.GetMapArtLayers)=='function' and type(C_Map.GetMapArtLayerTextures)=='function' then
  local ok,layers=pcall(C_Map.GetMapArtLayers,route.map)
  local layer=ok and type(layers)=='table' and layers[1]
  if layer and layer.layerWidth and layer.layerHeight and layer.tileWidth and layer.tileHeight then
   local okTextures,textures=pcall(C_Map.GetMapArtLayerTextures,route.map,1)
   if okTextures and type(textures)=='table' and #textures>0 then
    local valid=0
    for _,id in ipairs(textures) do if type(id)=='number' and id>0 then valid=valid+1 end end
    local tilesAcross=math.ceil(layer.layerWidth/layer.tileWidth)
    local tilesDown=math.ceil(layer.layerHeight/layer.tileHeight)
    if valid>0 and tilesAcross*tilesDown<=100 then
     for row=0,tilesDown-1 do
      for col=0,tilesAcross-1 do
       local id=textures[row*tilesAcross+col+1]
       if type(id)=='number' and id>0 then
        local tw=math.min(layer.tileWidth,layer.layerWidth-col*layer.tileWidth)
        local th=math.min(layer.tileHeight,layer.layerHeight-row*layer.tileHeight)
        local tile=canvas:CreateTexture(nil,'ARTWORK',nil,-7)
        tile:SetTexture(id)
        tile:Show()
        tile:SetSize(zoomX*tw/layer.layerWidth,zoomY*th/layer.layerHeight)
        tile:SetPoint('TOPLEFT',canvas,'TOPLEFT',zoomX*(col*layer.tileWidth/layer.layerWidth-viewX1),-zoomY*(row*layer.tileHeight/layer.layerHeight-viewY1))
        tile:SetTexCoord(0,tw/layer.tileWidth,0,th/layer.tileHeight)
        tile:SetAlpha(.82)
       end
      end
     end
     artLoaded=true
    end
   end
  end
 end

 -- Add detailed exploration overlay textures above the base zone map.
 -- These are visual only; no exploration progress is changed.
 local overlaysShown=0
 if artLoaded and C_MapExplorationInfo and type(C_MapExplorationInfo.GetExploredMapTextures)=='function'
    and C_Map and type(C_Map.GetMapArtLayers)=='function' then
  local ok,infos=pcall(C_MapExplorationInfo.GetExploredMapTextures,route.map)
  local okLayers,layers=pcall(C_Map.GetMapArtLayers,route.map)
  local layer=okLayers and type(layers)=='table' and layers[1]
  if ok and type(infos)=='table' and layer and layer.layerWidth and layer.layerHeight then
   for _,info in ipairs(infos) do
    if type(info)=='table' and type(info.fileDataIDs)=='table'
       and info.textureWidth and info.textureHeight and info.offsetX and info.offsetY then
     local cols=math.ceil(info.textureWidth/(layer.tileWidth or 256))
     local rows=math.ceil(info.textureHeight/(layer.tileHeight or 256))
     if cols>0 and rows>0 and cols*rows<=36 then
      for row=0,rows-1 do for col=0,cols-1 do
       local id=info.fileDataIDs[row*cols+col+1]
       if type(id)=='number' and id>0 then
        local tileWidth=math.min(layer.tileWidth or 256,info.textureWidth-col*(layer.tileWidth or 256))
        local tileHeight=math.min(layer.tileHeight or 256,info.textureHeight-row*(layer.tileHeight or 256))
        local t=canvas:CreateTexture(nil,'ARTWORK',nil,-6)
        t:SetTexture(id)
        t:SetSize(tileWidth*zoomX/layer.layerWidth,tileHeight*zoomY/layer.layerHeight)
        t:SetPoint('TOPLEFT',canvas,'TOPLEFT',
         ((info.offsetX+col*(layer.tileWidth or 256))/layer.layerWidth-viewX1)*zoomX,
         -((info.offsetY+row*(layer.tileHeight or 256))/layer.layerHeight-viewY1)*zoomY)
        t:SetTexCoord(0,tileWidth/(layer.tileWidth or 256),0,tileHeight/(layer.tileHeight or 256))
        overlaysShown=overlaysShown+1
       end
      end end
     end
    end
   end
  end
 end
 local left,top=15,15
 local minX,maxX,minY,maxY=0,1,0,1
 local scaleX,scaleY=448,380
 if not artLoaded then
  minX,maxX,minY,maxY=1,0,1,0
  for _,p in ipairs(all) do
   minX=math.min(minX,p.x); maxX=math.max(maxX,p.x)
   minY=math.min(minY,p.y); maxY=math.max(maxY,p.y)
  end
  local dx=math.max(.02,maxX-minX); local dy=math.max(.02,maxY-minY)
  local scale=math.min(415/dx,345/dy)
  scaleX,scaleY=scale,scale
 end
 local function xy(p)
  if artLoaded then return (p.x-viewX1)*zoomX,(p.y-viewY1)*zoomY end
  return left+(p.x-minX)*scaleX,top+(p.y-minY)*scaleY
 end
 local function point(p,index)
  local x,y=xy(p)
  local dot=canvas:CreateTexture(nil,'OVERLAY')
  dot:SetTexture('Interface\\Buttons\\WHITE8X8')
  dot:SetSize(index==0 and 10 or 5,index==0 and 10 or 5)
  dot:SetVertexColor(index==0 and 1 or .73,index==0 and .76 or .47,index==0 and .2 or .94,1)
  dot:SetPoint('CENTER',canvas,'TOPLEFT',x,-y)
  local number=canvas:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
  number:SetPoint('BOTTOMLEFT',canvas,'TOPLEFT',x+4,-y+4)
  number:SetText(index==0 and 'S' or tostring(index))
 end
 -- Use small solid textures for path segments. This works on Forever clients
 -- where Frame:CreateLine is unavailable and avoids silent missing lines.
 local segmentBudget=1200
 local function connect(a,b,isFirst)
  local x1,y1=xy(a); local x2,y2=xy(b)
  local dx,dy=x2-x1,y2-y1
  local length=math.sqrt(dx*dx+dy*dy)
  local count=math.max(1,math.ceil(length/5))
  count=math.min(count,segmentBudget)
  for j=0,count do
   if segmentBudget<=0 then break end
   local t=canvas:CreateTexture(nil,'ARTWORK')
   t:SetTexture('Interface\\Buttons\\WHITE8X8')
   t:SetSize(isFirst and 4 or 3,isFirst and 4 or 3)
   t:SetVertexColor(isFirst and .4 or .73,isFirst and .9 or .37,1,.9)
   t:SetPoint('CENTER',canvas,'TOPLEFT',x1+dx*j/math.max(1,count),-(y1+dy*j/math.max(1,count)))
   segmentBudget=segmentBudget-1
  end
 end
 local previous=origin
 for i,p in ipairs(route.travelPoints or route.points) do connect(previous,p,p.validated);previous=p end
 if not route.travelPoints and #route.points>1 then connect(previous,origin) end
 point(origin,0)
 for i,p in ipairs(route.points) do point(p,i) end
 local foot=label(w,string.format('%.0f yd | %.0f%% learned corridors; remaining travel unverified.\n%s',route.length or 0,(route.traversalConfidence or 0)*100,route.skillup and 'Skill-up route: estimated orange > yellow > green; gains not guaranteed.' or route.dataQuality or 'Potential spawn route'),18,-460,'GameFontHighlightSmall')
 foot:SetWidth(490)
 button(w,displayMode=='map' and 'Diagram view' or 'Map view',20,-499,125,function()
  local newMode=displayMode=='map' and 'diagram' or 'map'
  N.db.settings.previewMode=newMode
  N:ShowRoutePreview(strategy,newMode,route)
 end)
  button(w,'Activate route',182,-499,160,function()
  local selected=N:Copy(route)
  local map,x,y=N:Position()
  if map and x and y then N:StartRouteAtNearest(selected,{map=map,x=x,y=y}) end
  N.activeRoute=selected;N.waypoint=1;N.terrainIndex=1;N.routePaused=false;N.dirty=true;N:ShowArrow();w:Hide()
 end)
 self.previewWindow=w
end
function N:ShowTopGatheringZones()
 local choices={}
 local seen={}
 for _,node in pairs(self.nodeTypes or {}) do
  if node.kind=='herb' or node.kind=='ore' then
   if not seen[node.name] then
    seen[node.name]=true
    choices[#choices+1]={label=node.name,value=node.name}
   end
  end
 end
 table.sort(choices,function(a,b) return a.label<b.label end)
 if self.db.settings.routeSelectionMode=='skillup' then choices={{label='Best skill-up zones (current skills)',value='Skill-up routes'}} end
 if not self.ui then return end
 self:Choice(self.ui.zoneButton,choices,function(resource)
  self:RunPlanner(function() return self:RankResourceZones(resource) end,function(ranking)
  if #ranking==0 then self:Print('No comparable zones with available map dimensions for '..resource); return end
  if self.zoneRankingWindow then self.zoneRankingWindow:Hide() end
  local w=CreateFrame('Frame',nil,UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
  skin(w);w:SetSize(670,330);w:SetPoint('CENTER');w:SetFrameStrata('FULLSCREEN_DIALOG')
  w:EnableMouse(true);w:SetMovable(true);w:RegisterForDrag('LeftButton')
  w:SetScript('OnDragStart',function(frame) frame:StartMoving() end)
  w:SetScript('OnDragStop',function(frame) frame:StopMovingOrSizing() end)
  label(w,'TOP 5 FARMING ZONES | '..resource,16,-15,'GameFontNormalLarge')
  button(w,'Close',567,-10,86,function() w:Hide() end)
  label(w,'ZONE',20,-52,'GameFontNormalSmall')
  label(w,resource=='Skill-up routes' and 'PRIORITY/HR' or 'EST. STOPS/HR',265,-52,'GameFontNormalSmall')
  label(w,'LOOP',400,-52,'GameFontNormalSmall')
  label(w,'STOPS',487,-52,'GameFontNormalSmall')
  for i,r in ipairs(ranking) do
   local y=-68-(i-1)*43
   local name=r.name
   if #name>26 then name=name:sub(1,25)..'.' end
   label(w,i..'. '..name,20,y-7,'GameFontHighlightSmall')
   label(w,string.format('%.0f%s',r.score,r.metric=='resources' and ' res' or r.metric=='skill priority' and ' pts' or ' stops'),285,y-7,'GameFontHighlightSmall')
   label(w,string.format('%.1f min',(r.route.seconds or 0)/60),400,y-7,'GameFontHighlightSmall')
   label(w,tostring(#r.route.points),500,y-7,'GameFontHighlightSmall')
   label(w,string.format('%d spawns | %.0f yd | %.0f%% trail | %d/%d observed stops',r.rawCount,r.route.length or 0,(r.route.traversalConfidence or 0)*100,r.route.observedStops or 0,#r.route.points),20,y-25,'GameFontHighlightSmall')
   button(w,'Preview',565,y,85,function()
    local choices={{label='Best ranked loop',value=r.route}}
    for j,route in ipairs(r.alternatives or {}) do
     if route~=r.route then choices[#choices+1]={label=string.format('Alternative %d: %d stops / %.1f min',j,#route.points,route.seconds/60),value=route} end
    end
    N:Choice(w,choices,function(route) w:Hide();route.strategy='optimal';N:ShowRoutePreview('optimal',nil,route) end)
   end)
  end
  label(w,resource=='Skill-up routes' and 'Estimated difficulty priority, not skill-ups/hour. Travel and zone danger excluded.' or 'In-zone loops only; travel to zone excluded. Stops are potential; res uses sampled checks.',18,-300,'GameFontHighlightSmall')
  self.zoneRankingWindow=w
  end)
 end)
end
function N:CreateUI()
 local f=CreateFrame('Frame','VoidMarkNexusWindow',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil); skin(f)
 local size=self.db.settings.size
 local w,h=1060,660
 if type(size)=='table' and self:Finite(size[1],1060,2400) and self:Finite(size[2],560,1600) then w,h=size[1],size[2] end
 f:SetSize(w,h); f:SetFrameStrata('MEDIUM'); if f.SetResizable then f:SetResizable(true) end
 if f.SetResizeBounds then f:SetResizeBounds(1060,560,2400,1600) elseif f.SetMinResize then f:SetMinResize(1060,560); if f.SetMaxResize then f:SetMaxResize(2400,1600) end end f:SetToplevel(true); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
 local position=self.db.settings.position; if type(position)=='table' then f:SetPoint('CENTER',UIParent,'CENTER',position[1],position[2]) else f:SetPoint('CENTER') end
 f:SetScale(self.db.settings.scale)
 f:SetScript('OnDragStart',function() f:StartMoving() end)
 f:SetScript('OnDragStop',function() f:StopMovingOrSizing(); local x,y=f:GetCenter(); local ux,uy=UIParent:GetCenter(); N.db.settings.position={x-ux,y-uy} end)
 -- Size grip: the layout below is anchored to the window edges (see LayoutUI).
 local grip=CreateFrame('Button',nil,f)
 grip:SetSize(28,28); grip:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-2,2)
 grip:SetFrameLevel(f:GetFrameLevel()+10)
 local t=grip:CreateTexture(nil,'OVERLAY'); t:SetAllPoints(); t:SetTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
 grip:RegisterForDrag('LeftButton')
 grip:SetScript('OnDragStart',function() f:StartSizing('BOTTOMRIGHT') end)
 grip:SetScript('OnDragStop',function()
  f:StopMovingOrSizing()
  local fw,fh=f:GetWidth(),f:GetHeight()
  if N:Finite(fw,1060,2400) and N:Finite(fh,560,1600) then N.db.settings.size={math.floor(fw+.5),math.floor(fh+.5)} end
  local x,y=f:GetCenter(); local ux,uy=UIParent:GetCenter()
  if x and ux then N.db.settings.position={x-ux,y-uy} end
  N:LayoutUI()
 end)
 grip:SetScript('OnEnter',function() GameTooltip:SetOwner(grip,'ANCHOR_RIGHT'); GameTooltip:SetText('Drag to resize Nexus (scale is in Settings)'); GameTooltip:Show() end)
 grip:SetScript('OnLeave',function() GameTooltip:Hide() end)
 label(f,'VOIDMARK  |  NEXUS',18,-17,'GameFontNormalLarge'); label(f,self.version,280,-19,'GameFontHighlightSmall')
 local closeButton=button(f,'Close',956,-10,86,function() f:Hide(); if N.menu then N.menu:Hide() end end)
 closeButton:ClearAllPoints(); closeButton:SetPoint('TOPRIGHT',f,'TOPRIGHT',-18,-10)
 self.ui={frame=f,tab='Home',rows={},page=1,filter='All'}; local u=self.ui
 for i,tab in ipairs(tabs) do button(f,tab,12,-56-(i-1)*40,130,function() u.tab=tab; u.page=1; u.selected=nil; N.dirty=true end) end
 u.search=edit(f,165,-55,220,''); u.search:SetScript('OnTextChanged',function() u.page=1; N.dirty=true end)
 u.characterButton=button(f,'All characters',404,-55,205,function()
  local choices={{label='All characters',value=false}}
  for id,c in pairs(N.db.characters) do choices[#choices+1]={label=c.name..' - '..c.realm..(c.imported and ' [Imported]' or ''),value=id} end
  N:Choice(u.characterButton,choices,function(v) u.character=v or nil; u.profession=nil; u.page=1 end)
 end)
 u.professionButton=button(f,'All professions',617,-55,205,function()
  local choices={{label='All professions',value=false}}; local seen={}
  for id,c in pairs(N.db.characters) do if not u.character or id==u.character then for pid,p in pairs(c.professions) do if not seen[pid] then choices[#choices+1]={label=p.name,value=pid}; seen[pid]=true end end end end
  N:Choice(u.professionButton,choices,function(v) u.profession=v or nil; u.page=1 end)
 end)
 u.filterButton=button(f,'All nodes',830,-55,210,function()
  if u.tab=='Leveling' then
   local choices={}
   for _,m in ipairs(N.levelModes) do choices[#choices+1]={label=m..' route',value=m} end
   N:Choice(u.filterButton,choices,function(v) N.db.settings.levelMode=v; u.selected=nil; u.page=1; N.dirty=true end)
  elseif u.tab=='Gathering' then
   N:Choice(u.filterButton,{
    {label='All gathering',value='all'},
    {label='Herbs only',value='herb'},
    {label='Mining only',value='ore'},
    {label='Herbalism skill-ups',value='skillherb'},
    {label='Mining skill-ups',value='skillore'},
    {label='Both gathering skill-ups',value='skillall'},
    {label='Multi-select...',value='multi'}
   },function(v)
    local settings=N.db.settings
    if v=='multi' then N:ShowResourcePicker(); return end
    if v:sub(1,5)=='skill' then N:SelectSkillupRoute(v:sub(6));u.selected=nil;u.page=1;return end
    settings.kind=v; settings.target=''; settings.routeSelectionMode=v; settings.routeResources=nil
    u.selected=nil; u.page=1; N.dirty=true
   end)
  else
   local choices={}
   for _,v in ipairs({'All','Known','Unknown','Wishlist','Profit','Loss','Missing','Available','Fresh','Cost ascending','Cash ascending','Fewest missing','Profit descending','Margin descending'}) do choices[#choices+1]={label=v,value=v} end
   N:Choice(u.filterButton,choices,function(v) u.filter=v; u.page=1 end)
  end
 end)
 u.heading=label(f,'',164,-95); u.heading:SetWidth(875)
 for i=1,40 do
  local row=CreateFrame('Button',nil,f); row:SetSize(535,27); row:SetPoint('TOPLEFT',160,-125-(i-1)*28)
  row.bg=row:CreateTexture(nil,'BACKGROUND'); row.bg:SetAllPoints(); row.bg:SetColorTexture(.1,.07,.15,i%2==0 and .9 or .4)
  row.icon=row:CreateTexture(nil,'ARTWORK'); row.icon:SetSize(20,20); row.icon:SetPoint('LEFT',3,0)
  row.text=label(row,'',28,-6,'GameFontHighlight'); row.text:SetWidth(500); row.text:SetWordWrap(false)
  row:SetScript('OnClick',function() if row.data then u.selected=row.data; N.dirty=true end end)
  row:SetScript('OnEnter',function(self)
   local data=self.data
   if not data or not data.item then return end
   local itemID=tonumber(data.item)
   if not itemID or itemID<=0 then return end
   GameTooltip:Hide()
   GameTooltip:ClearLines()
   GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
   local ok=false
   if type(data.itemLink)=='string' then
    ok=pcall(GameTooltip.SetHyperlink,GameTooltip,data.itemLink)
   end
   -- Fall back to the client-resolved link if the scanned link is unavailable.
   if not ok and type(GetItemInfo)=='function' then
    local success,_,link=pcall(GetItemInfo,itemID)
    if success and type(link)=='string' then
     ok=pcall(GameTooltip.SetHyperlink,GameTooltip,link)
    end
   end
   if not ok and type(GameTooltip.SetItemByID)=='function' then
    ok=pcall(GameTooltip.SetItemByID,GameTooltip,itemID)
   end
   if not ok then
    ok=pcall(GameTooltip.SetHyperlink,GameTooltip,'item:'..itemID..':0:0:0:0:0:0:0')
   end
   if not ok then GameTooltip:ClearLines(); GameTooltip:AddLine(data.itemName or ('Item #'..itemID)) end
   GameTooltip:Show()
  end)
  row:SetScript('OnLeave',function() GameTooltip:Hide() end); u.rows[i]=row
 end
 local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',715,-125); scroll:SetSize(300,440); u.detailScroll=scroll
 local child=CreateFrame('Frame',nil,scroll); child:SetSize(295,440); scroll:SetScrollChild(child)
 u.detail=label(child,'',0,0,'GameFontHighlight'); u.detail:SetWidth(290); u.detail:SetSpacing(4); u.detail:SetWordWrap(true); u.detailChild=child
 u.prevButton=button(f,'Previous',164,-583,100,function() u.page=math.max(1,u.page-1); u.selected=nil; N.dirty=true end)
 u.nextButton=button(f,'Next',270,-583,100,function() u.page=u.page+1; u.selected=nil; N.dirty=true end)
 u.pageLabel=label(f,'',385,-589,'GameFontHighlightSmall')
 u.value=edit(f,555,-584,140,'1'); u.actions={}
 u.previewButton=button(f,'Preview route',715,-546,140,function() N:ShowRoutePreview(N.db.settings.routeStrategy or 'optimal') end)
 u.zoneButton=button(f,'Top 5 zones',865,-546,140,function() N:ShowTopGatheringZones() end)
 u.zoneButton:Hide()
 u.previewButton:Hide()
 u.strategyButton=button(f,'Best loop',555,-546,140,function()
  local options={{label='Best loop',value='optimal'},{label='Nearest loop',value='nearest'},{label='Start here',value='here'}}
  N:Choice(u.strategyButton,options,function(v) N.db.settings.routeStrategy=v; N.dirty=true; N:ShowRoutePreview(v) end)
 end)
 u.strategyButton:Hide()
 u.value:SetScript('OnTextChanged',function() N.dirty=true end)
 for i=1,3 do u.actions[i]=button(f,'',708+(i-1)*112,-583,108,function() local fn=u.actionFns and u.actionFns[i]; if fn then fn() end; N.dirty=true end) end
 u.footer=label(f,'',164,-625,'GameFontHighlightSmall'); u.footer:SetWidth(875)
 f:EnableMouseWheel(true); f:SetScript('OnMouseWheel',function(_,delta) u.page=math.max(1,u.page-delta); u.selected=nil; N.dirty=true end)
 local elapsed=0; f:SetScript('OnUpdate',function(_,dt) elapsed=elapsed+dt; if elapsed>.3 then elapsed=0; if N.dirty then N:Guard('UI',function() N:Render() end) end end end)
 table.insert(UISpecialFrames,'VoidMarkNexusWindow')
 f:SetScript('OnSizeChanged',function() N:LayoutUI() end)
 self:LayoutUI()
end
-- Edge-anchored layout; rows and detail grow with the window.
function N:LayoutUI()
 local u=self.ui; if not u then return end
 local f=u.frame
 local W,H=f:GetWidth(),f:GetHeight()
 if not self:Finite(W,100,5000) or not self:Finite(H,100,5000) then W,H=1060,660 end
 local rowWidth=math.max(400,W-525)
 u.heading:SetWidth(W-185); u.footer:SetWidth(W-185)
 u.perPage=math.max(8,math.min(#u.rows,math.floor((H-212)/28)))
 for i,row in ipairs(u.rows) do
  row:SetWidth(rowWidth); row.text:SetWidth(rowWidth-35)
  if i>u.perPage then row:Hide() end
 end
 u.detailScroll:ClearAllPoints()
 u.detailScroll:SetPoint('TOPLEFT',f,'TOPLEFT',W-345,-125)
 u.detailScroll:SetSize(300,math.max(200,H-220))
 local function bottom(widget,x,y,fromRight)
  widget:ClearAllPoints(); widget:SetPoint('TOPLEFT',f,fromRight and 'BOTTOMRIGHT' or 'BOTTOMLEFT',x,y)
 end
 bottom(u.prevButton,164,77); bottom(u.nextButton,270,77)
 u.pageLabel:ClearAllPoints(); u.pageLabel:SetPoint('TOPLEFT',f,'BOTTOMLEFT',385,71)
 bottom(u.value,-505,76,true)
 for i,b in ipairs(u.actions) do bottom(b,-352+(i-1)*112,77,true) end
 bottom(u.strategyButton,-505,114,true); bottom(u.previewButton,-345,114,true); bottom(u.zoneButton,-195,114,true)
 u.footer:ClearAllPoints(); u.footer:SetPoint('TOPLEFT',f,'BOTTOMLEFT',164,35)
 self.dirty=true
end
function N:SetActions(names,fns)
 self.ui.actionFns=fns
 for i,b in ipairs(self.ui.actions) do b:SetText(names[i] or ''); b:SetShown(names[i]~=nil) end
end
function N:RecipeDetail(row)
 local r=row.r; local qty=tonumber(self.ui.value:GetText()) or 1; local e=self:Evaluate(r,qty,row.character)
 local lines={r.name,row.c.name..' - '..row.c.realm..' / '..row.c.faction,row.p.name..' '..(row.p.skill or 0)..'/'..(row.p.max or 0),
  (r.learned and 'Known' or 'Unknown')..' | '..self:Age(r.at),r.source or 'Recipe source not supplied by the client.',
  'Output: '..e.output..' to '..e.outputMax,'Buy all materials: '..self:Money(e.cost),'Buy missing (cash): '..self:Money(e.cash),
  'Owned material value: '..self:Money(e.owned),'Estimated net proceeds: '..self:Money(e.net),'Economic profit: '..self:Money(e.economic),
  'Cash surplus: '..self:Money(e.cashProfit),'Craft vs sell reagents (net): '..self:Money(e.craftAdvantage),
  'Deposit cash required: '..self:Money(e.depositCash),'Expected lost deposits: '..self:Money(e.depositLoss),
  e.stale and 'WARNING: price age stale or unknown.' or 'Prices follow Settings priority.',
  r.incomplete and 'Incomplete/alternative reagent schematic: profit unavailable.' or '',
  'Listed prices are estimates; sale volume is not predicted.','', 'Materials:'}
 for _,g in ipairs(e.rows) do
  lines[#lines+1]=self:ItemName(g.id)..' x'..g.need..' | Missing '..g.missing
  lines[#lines+1]='  '..self:PriceLabel(g.price)
  for _,a in ipairs(g.allocations) do lines[#lines+1]='  '..a.qty..': '..a.transfer..' ('..self:Age(a.at)..')' end
 end
 return table.concat(lines,'\n')
end
function N:SettingsRows()
 local rows={}; local s=self.db.settings
 local booleans={{'native','Use the normal profession window'},{'learn','Remember herbs and ore I find'},{'importedNodes','Show possible spawn spots'},{'observedNodes','Show spots I have gathered'},
 {'nodesVisible','Show spots on the map'},{'routeVisible','Show the route arrow'},{'minimapRoute','Route line on minimap'},{'terrainLearn','Learn paths I walk'},{'manualStops','Wait for me to skip each stop'},{'stats','Track gathering totals'},{'includeAlts','Count items on alts'},{'includeBanks','Count items in banks'},
 {'includeImports','Count imported characters'},{'includeSynced','Count the other account (sync)'},{'includeStale','Count old bag/bank data'},{'market','VoidMark Market prices'},{'auctionator','Auctionator prices'},{'manualFirst','Use my prices first'},{'minimap','Minimap button'},{'mapButton','Nexus button on world map'},{'tomtom','TomTom waypoint for next stop'},{'tomtomArrow','Also show TomTom arrow'},{'levelResale','Leveling: count selling what I craft'}}
 for _,v in ipairs(booleans) do rows[#rows+1]={text=v[2]..': '..(s[v[1]] and 'On' or 'Off'),key=v[1],boolean=true,detail='Select it, then press Apply to switch it on or off.'} end
 for _,v in ipairs({{'maxAge','Prices are old after (seconds)',60,2592000},{'inventoryAge','Bag data is old after (seconds)',60,2592000},
 {'cut','Auction cut (0.05 = 5%)',0,.3},{'deposit','Deposit per craft (copper)',0,1e8},{'failedAuctions','Failed listings per craft',0,20},
 {'saleFraction','Share of crafts that sell (0-1)',0,1},{'waste','Extra material waste (0-1)',0,1},{'speed','Travel speed (yards/sec)',1,50},
 {'mountDelay','Remount time per stop (seconds)',0,30},{'gatherDelay','Gather time per stop (seconds)',0,60},
 {'routeMinutes','Route time limit (minutes)',1,120},{'levelCraftValue','Balanced plan: my time per craft (copper)',0,1e7},{'nodeLimit','Most stops in a route',2,150},{'mapIconSize','Map icon size',5,16},{'scale','Window scale',.6,1.5},{'arrowScale','Arrow size (0.5-2)',.5,2}}) do
  rows[#rows+1]={text=v[2]..': '..s[v[1]],key=v[1],min=v[3],max=v[4],detail='Type a number in the bottom box, then press Apply.'}
 end
 return rows
end
function N:Render()
 local u=self.ui; if not u or not u.frame:IsShown() then return end; self.dirty=false
 if u.strategyButton then
  u.strategyButton:SetShown(u.tab=='Gathering')
  if u.previewButton then u.previewButton:SetShown(u.tab=='Gathering') end
  if u.zoneButton then u.zoneButton:SetShown(u.tab=='Gathering') end
  local titles={optimal='Best loop',nearest='Nearest loop',here='Start here'}
  u.strategyButton:SetText(titles[self.db.settings.routeStrategy or 'optimal'] or 'Best loop')
 end
 self.renderStocks={}
 local rows,detail={},''; local selected=u.selected; local tab=u.tab
 local c=u.character and self.db.characters[u.character]
 u.characterButton:SetText(c and c.name or 'All characters'); u.professionButton:SetText(u.profession or 'All professions'); u.filterButton:SetText(tab=='Leveling' and (self.db.settings.levelMode..' route') or tab=='Gathering' and (self.db.settings.routeSelectionMode=='skillup' and (({herb='Herbalism',ore='Mining',all='Both'})[self.db.settings.kind]..' skill-ups') or self.db.settings.routeSelectionMode=='multi' and 'Multi-select' or ({all='All gathering',herb='Herbs only',ore='Mining only'})[self.db.settings.kind] or 'All gathering') or u.filter)
 local hints={Home='Your characters at a glance.',Professions='Pick a profession, then Recipes or Level plan.',
  Leveling='Type a target skill in the bottom box (1 = current cap). Top-right picks cheapest/fastest.',
  Recipes='Search above. Top-right sorts and filters. Bottom box is the quantity.',Crafting='Your queued crafts and what to buy.',
  Gathering='Top-right picks what to gather, then press Generate.',Inventory='Bags and banks for all your characters.',
  Characters='Your characters and the bank account.',Settings='Select a setting, then press Apply.'}
 u.heading:SetText(tab..'  |  '..(hints[tab] or ''))
 self:SetActions({},{}); u.footer:SetText('')
 if tab=='Recipes' then
  local filter=({'All','Known','Unknown','Wishlist'})[1]; if u.filter=='Known' or u.filter=='Unknown' or u.filter=='Wishlist' then filter=u.filter end
  for _,r in ipairs(self:Search(u.search:GetText(),u.character,u.profession,filter)) do
   local e=self:Evaluate(r.r,1,r.character); local missing=0; for _,g in ipairs(e.rows) do missing=missing+g.missing end
   local accept=u.filter~='Profit' and u.filter~='Loss' and u.filter~='Missing' and u.filter~='Available' and u.filter~='Fresh'
    or u.filter=='Profit' and e.economic and e.economic>0 or u.filter=='Loss' and e.economic and e.economic<0
    or u.filter=='Missing' and missing>0 or u.filter=='Available' and missing==0 and not e.unknown or u.filter=='Fresh' and not e.stale and not e.unknown
   if accept then r.text=r.r.name..' | '..r.c.name..' | '..self:Money(e.economic)..(e.margin and string.format(' | ROI %d%%',math.floor(e.margin*100+.5)) or ''); r.item=r.r.output; r.icon=r.r.icon; r.e=e; r.missing=missing; rows[#rows+1]=r end
  end
  if u.filter=='Cost ascending' then table.sort(rows,function(a,b) return (a.e.cost or math.huge)<(b.e.cost or math.huge) end)
  elseif u.filter=='Cash ascending' then table.sort(rows,function(a,b) return (a.e.cash or math.huge)<(b.e.cash or math.huge) end)
  elseif u.filter=='Fewest missing' then table.sort(rows,function(a,b) if a.missing==b.missing then return a.r.name<b.r.name end return a.missing<b.missing end)
  elseif u.filter=='Profit descending' or u.filter=='Margin descending' then local k=u.filter=='Profit descending' and 'economic' or 'margin'; table.sort(rows,function(a,b) return (a.e[k] or -math.huge)>(b.e[k] or -math.huge) end) end
  self:SetActions({'Queue','Craft','Wishlist'},{function() if u.selected then N:AddPlan(u.selected,u.value:GetText()) end end,function() if u.selected then N:Craft(u.selected,u.value:GetText()) end end,function() if u.selected then local k=u.selected.recipe; N.db.wish[k]=not N.db.wish[k] end end})
  if selected and selected.r then detail=self:RecipeDetail(selected) end
 elseif tab=='Professions' then
  for id,ch in pairs(self.db.characters) do if not u.character or id==u.character then for pid,p in pairs(ch.professions) do
   rows[#rows+1]={text=ch.name..' | '..p.name..' '..(p.skill or 0)..'/'..(p.max or 0),character=id,profession=pid,detail='Last observed: '..self:Age(p.at)..'\nRecipes browses this profession. Level plan opens the leveling planner for it.'}
  end end end
  self:SetActions({'Recipes','Level plan'},{function() if u.selected then u.character=u.selected.character; u.profession=u.selected.profession; u.tab='Recipes'; u.selected=nil end end,
   function() N:ShowLeveling() end})
 elseif tab=='Leveling' then
  local cid=u.character or self.characterID
  local ch=self.db.characters[cid]
  local pid=u.profession
  if selected and selected.levelPick then u.character=selected.levelCharacter; u.profession=selected.levelPick; u.selected=nil; selected=nil; cid=u.character; ch=self.db.characters[cid]; pid=u.profession end
  if not (ch and pid and ch.professions[pid]) then
   for id,pp in pairs(ch and ch.professions or {}) do
    rows[#rows+1]={text=pp.name..'  '..(pp.skill or 0)..' / '..(pp.max or 0),levelPick=id,levelCharacter=cid}
   end
   table.sort(rows,function(a,b) return a.text<b.text end)
   detail='Pick a profession to plan.\n\nUse the character button to plan an alt from its last scan. Open a profession in game once so its recipes are recorded.'
  else
   local p=ch.professions[pid]
   local plan=self:CachedLevelingPlan(cid,pid,tonumber(u.value:GetText()),self.db.settings.levelMode,u.levelForce)
   u.levelForce=nil; u.levelPlan=plan; u.levelRef={cid,pid}
   for _,seg in ipairs(plan.segments) do
    local cand=seg.cand
    local per={}
    for _,rg in ipairs(cand.r.reagents) do per[#per+1]=rg.qty..'x '..self:ItemName(rg.id) end
    rows[#rows+1]={text=string.format('%d-%d  %s x%d  (%s > %s) | %s',seg.from,seg.to,seg.name,seg.crafts,seg.startColor,seg.endColor,seg.unknown and 'price unknown' or self:Money(seg.cost)),
     icon=cand.r.icon,item=cand.r.output,
     detail=seg.name..'\nSkill '..seg.from..' to '..seg.to..'\nExpected crafts: '..string.format('%.1f',seg.expected)..' (plan '..seg.crafts..')\n'..
      string.format('Yellow from %d, green from %d, gray from %d%s',cand.Y,cand.G,cand.X,seg.estimated and ' (estimated)' or ' (observed)')..
      '\nPer craft: '..table.concat(per,', ')..'\nMaterial cost: '..(seg.unknown and 'unknown' or self:Money(seg.cost))..
      (seg.recover>0 and ('\nPossible output resale: '..self:Money(seg.recover)) or '')..
      (cand.r.source and ('\nSource: '..cand.r.source) or '')}
   end
   detail=ch.name..' | '..p.name..' '..(p.skill or 0)..'/'..(p.max or 0)..' | '..self:Age(p.at)..'\n\n'..self:LevelingSummary(plan)
   self:SetActions({'Queue plan','Change prof','Recalculate'},{function() N:QueueLevelingPlan(u.levelPlan,u.levelRef[1],u.levelRef[2]) end,
    function() u.profession=nil; u.selected=nil end,function() u.levelForce=true end})
  end
 elseif tab=='Crafting' then
  for i,p in ipairs(self.db.plans) do local r=self:Recipe(p); rows[#rows+1]={text=(r and r.name or 'Missing recipe')..' x'..p.qty,index=i,detail='Planned work only. Materials are allocated once across the complete queue. Edit quantity below or export the shopping list.'} end
  self:SetActions({'Set qty','Remove','Shopping'},{function() if u.selected then local p=N.db.plans[u.selected.index]; if p then p.qty=math.max(1,math.min(9999,math.floor(tonumber(u.value:GetText()) or 1))) end end end,
   function() if u.selected then table.remove(N.db.plans,u.selected.index); u.selected=nil end end,function() N:TextDialog('Material shopping list',N:ShoppingText()) end})
  detail=self:ShoppingText()
 elseif tab=='Inventory' then
  local query=u.search:GetText():lower()
  for id,ch in pairs(self.db.characters) do if not u.character or id==u.character then for _,loc in ipairs({'bags','bank'}) do for item,qty in pairs(ch[loc]) do
   local name=self:ItemName(item); if query=='' or name:lower():find(query,1,true) then rows[#rows+1]={text=name..' x'..qty..' | '..ch.name..' / '..loc,item=item,itemName=name,itemLink=ch.itemLinks and ch.itemLinks[loc] and ch.itemLinks[loc][item],detail=name..'\n'..ch.name..' / '..ch.realm..' / '..ch.faction..'\n'..self:Age(ch[loc..'At'])..'\nCached inventory may have changed. Cross-realm/faction transfers are not included.'} end
  end end end end
  self:SetActions({'Set price','Market','Prices'},{function() if u.selected then N:SetPrice(u.selected.item,u.value:GetText()) end end,function() if u.selected then N:OpenMarket(u.selected.item) end end,function() N:TextDialog('Manual prices', 'Use /vmn price ITEM_ID GOLD\nFor example: /vmn price 2447 0.25\nEnable Prefer manual prices in Settings to override Market.') end})
 elseif tab=='Characters' then
  for id,ch in pairs(self.db.characters) do rows[#rows+1]={text=ch.name..' | '..ch.realm..' | '..ch.faction..(ch.synced and ' [Synced]' or ch.imported and ' [Imported]' or '')..(self.db.excluded[id] and ' [Excluded]' or ''),character=id,detail='Account: '..ch.account..'\n'..self:Age(ch.at)..'\nBags: '..self:Age(ch.bagsAt)..'\nBank: '..self:Age(ch.bankAt)..'\nImported inventories require opt-in in Settings.'} end
  self:SetActions({'Include/excl','Export','Import'},{function() if u.selected then local id=u.selected.character; N.db.excluded[id]=not N.db.excluded[id] end end,function() N:TextDialog('Cross-account export',N:Export()) end,function() N:TextDialog('Cross-account import','',true) end})
 elseif tab=='Settings' then
  rows=self:SettingsRows(); self:SetActions({'Apply','Clear sessions','Diagnostics'},{function()
   local r=u.selected; if not r or not r.key then return end
   if r.boolean then N.db.settings[r.key]=not N.db.settings[r.key]
   else local value=tonumber(u.value:GetText()); if N:Finite(value,r.min,r.max) then N.db.settings[r.key]=value else N:Print('Value outside allowed range.') end end
   u.frame:SetScale(N.db.settings.scale); if N.minimap then N.minimap:SetShown(N.db.settings.minimap) end
   if N.activeRoute and N.db.settings.routeVisible then N:ShowArrow() end
  end,function() N.db.sessions={}; N:Print('Saved gathering sessions cleared.') end,function() N:TextDialog('Compatibility diagnostics',N:Diagnostics()) end})
 elseif tab=='Gathering' then
  local map=self:Position(); local nodes=map and self:ZoneNodes(map) or {}; local s=self.db.settings
  detail='What: '..(s.target~='' and s.target or ({all='Herbs and ore',herb='Herbs',ore='Ore'})[s.kind] or 'Herbs and ore')..
   '\nRoute style: '..({optimal='Best loop',nearest='Nearest loop',here='Start here'})[s.routeStrategy or 'optimal']..
   '\nTravel: '..s.travel..'\nTime limit: '..s.routeMinutes..' min\n'..#nodes..' spots in this zone\n\nBlue lines are paths you have walked; purple are guesses.\nRoute tools: record a run, travel to a route, export or import.'
  if s.routeSelectionMode=='skillup' then detail='SKILL-UP ROUTE\n'..self:GatheringSkillSummary()..'\n\n'..detail end
  for name,r in pairs(self.db.routes) do
   local valid=self:CleanNavigationRoute(r)
   rows[#rows+1]={text='Saved: '..tostring(name)..(valid and (' | '..#valid.points..' waypoints') or ' | invalid data retained'),
    routeName=name,detail=valid and (self:SavedRunSummary(valid)..'\nUse Load selected to navigate this saved route.') or 'Invalid saved geometry was retained. Delete this route through Route tools if no longer needed.'}
  end
  if self.activeRoute then for i,p in ipairs(self.activeRoute.points) do rows[#rows+1]={text=i..'. '..(p.name or 'Waypoint')..string.format(' (%.1f, %.1f)',p.x*100,p.y*100),icon=self:ResourceNodeIcon(p),detail=p.source or 'Custom waypoint'} end end
  local secs,rate,gph=self:SessionStats()
  if secs and secs>0 then detail=string.format('This session: %d min, %d items/hour, %s/hour',math.floor(secs/60),math.floor(rate),self:Money(gph))..'\n\n'..detail end
  for i,ss in ipairs(self.db.sessions) do local sec2,r2,g2=self:SessionStats(ss); rows[#rows+1]={text='Session '..i..': '..ss.total..' items in '..math.floor(sec2/60)..' min',detail=math.floor(r2)..' items/hour\n'..self:Money(g2)..'/hour\n'..ss.character..'\n'..self:RouteSessionText(ss)} end
  local rec=self.recording and self:RecordingStatus()
  if rec then detail=rec..'\n\n'..detail end
  self:SetActions({'Route tools','Generate','Load selected'},{function()
   N:RouteTools(u.actions[1])
  end,function() N:GenerateRoute() end,function() if u.selected and u.selected.routeName then N:ReplayRoute(u.selected.routeName) end end})
 else
  local n=0; for _ in pairs(self.db.characters) do n=n+1 end
  rows={{text=self.character.name..' - '..self.character.realm}}
  for _,p in pairs(self.character.professions) do rows[#rows+1]={text=p.name..' '..(p.skill or 0)..'/'..(p.max or 0)} end
  rows[#rows+1]={text=n..' characters recorded'}
  if #self.db.plans>0 then rows[#rows+1]={text=#self.db.plans..' crafts queued'} end
  if self.activeRoute then rows[#rows+1]={text='Gathering route active: '..#self.activeRoute.points..' stops'} end
  rows[#rows+1]={text='Prices: '..(VoidMarkMarketDB and 'VoidMark Market' or 'manual only (Market not loaded)')}
  detail='VoidMark Nexus '..self.version..'\n\nOpen each profession once and visit your bank so Nexus knows what you have.'
  self:SetActions({'Recipes','Shopping','Refresh bags'},{function() u.tab='Recipes'; u.selected=nil end,function() N:TextDialog('Shopping list',N:ShoppingText()) end,function() N:ScanStorage(false); N:ScanProfessions() end})
 end
 if selected and selected.detail then detail=selected.detail end
 local per=u.perPage or 16; local pages=math.max(1,math.ceil(#rows/per)); u.page=math.min(pages,math.max(1,u.page)); u.pageLabel:SetText(u.page..' / '..pages..'  ('..#rows..')')
 for i,b in ipairs(u.rows) do local r=i<=per and rows[(u.page-1)*per+i] or nil; b.data=r; b:SetShown(r~=nil)
  if r then
   b.text:SetText(r.text)
   b.icon:SetTexture(r.icon or (r.item and self:InventoryIcon(r.item)) or 'Interface\\Icons\\INV_Misc_QuestionMark')
  end
 end
 u.detail:SetText(detail); u.detailChild:SetHeight(math.max(440,u.detail:GetStringHeight()+20))
 self.renderStocks=nil
end
function N:ShoppingText()
 local lines={'Materials are allocated once in queue order. Costs use the current realm/faction economy.'}
 for _,r in ipairs(self:Shopping()) do
  lines[#lines+1]=self:ItemName(r.id)..' x'..r.need..' | Buy '..r.missing..' | '..r.recipeName
  lines[#lines+1]='  Estimated purchase: '..self:Money(r.price and r.price.unit*r.missing)
  for _,a in ipairs(r.allocations) do lines[#lines+1]='  '..a.qty..' '..a.transfer end
 end
 return table.concat(lines,'\n')
end
-- Opens the Leveling tab for the selected profession row (Professions tab).
function N:ShowLeveling()
 local u=self.ui; local r=u and u.selected
 if r and r.profession then u.character=r.character; u.profession=r.profession end
 if u then u.tab='Leveling'; u.selected=nil; u.page=1; self.dirty=true end
end


function N:RouteTools(anchor)
 self:Choice(anchor,{
  {label='Travel mode',value='travel'},
  {label=self.recording and 'Finish recording' or 'Record a farming run',value='record'},
  {label='Discard recording draft',value='discard'},
  {label='Travel to selected route',value='trip'},
  {label='Export selected route',value='export'},
  {label='Import route',value='import'},
  {label='Delete selected route',value='delete'},
  {label='Save gathering session',value='savesession'},
  {label='Reset gathering session',value='resetsession'},
  {label='Improve current route',value='improve'},
  {label='Route details',value='status'},
  {label='Clear computed cache',value='clear'}
 },function(value)
  local selected=self.ui and self.ui.selected;local name=selected and selected.routeName
  if value=='travel' then
   local options={};for i,m in ipairs(self.travelModes) do options[#options+1]={label=m[1],value=i} end
   self:Choice(anchor,options,function(i)
    local m=self.travelModes[i];self.db.settings.travel=m[1]
    if m[1]~='Custom' then self.db.settings.speed=m[2];self.db.settings.mountDelay=m[3] end
    self.dirty=true
   end)
  elseif value=='record' then if self.recording then self:FinishRecording() else
   local text=self.ui and self.ui.value:GetText();self:StartRecording(text~='1' and text or '') end
  elseif value=='discard' then self:DiscardRecording()
  elseif value=='trip' then self:TravelToRoute(name)
  elseif value=='import' then self:TextDialog('Route import','','route')
  elseif value=='export' then local raw,err=self:ExportRoute(name);if raw then self:TextDialog('Route export',raw) else self:Print(err) end
  elseif value=='delete' then
   if name then self:Choice(anchor,{{label='Delete '..name,value=true},{label='Keep route',value=false}},function(yes)
    if yes then self.db.routes[name]=nil;self.ui.selected=nil;self.dirty=true end
   end) else self:Print('Select a saved route first.') end
  elseif value=='savesession' then self:SaveSession()
  elseif value=='resetsession' then self:StartSession()
  elseif value=='improve' then self:GenerateRoute(true)
  elseif value=='clear' then self:ClearCalculations()
  elseif value=='status' then self:TextDialog('Saved calculations',self:CacheSummary()..'\n'..self:RecordingStatus()) end
  self.dirty=true
 end)
end
