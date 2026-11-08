local _, N = ...
function N:Diagnostics()
 local version,build,_,toc=self:Call(GetBuildInfo)
 local lines={'VoidMark Nexus '..self.version,'Client '..tostring(version)..' / '..tostring(build)..' / interface '..tostring(toc),
 'Modern recipes: '..tostring(C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeSchematic)=='function'),
 'Legacy recipes: '..tostring(type(GetTradeSkillInfo)=='function'),
 'Container API: '..tostring(C_Container~=nil),'Map position: '..tostring(C_Map and type(C_Map.GetPlayerMapPosition)=='function'),
 'Map dimensions: '..tostring(C_Map and type(C_Map.GetMapWorldSize)=='function'),
 'Map artwork: '..tostring(C_Map and type(C_Map.GetMapArtLayers)=='function'),
 'Exploration artwork: '..tostring(C_MapExplorationInfo and type(C_MapExplorationInfo.GetExploredMapTextures)=='function'),
 'Movement speed: '..tostring(type(GetUnitSpeed)=='function'),
 'Taxi / flight / swimming: '..tostring(type(UnitOnTaxi)=='function')..' / '..tostring(type(IsFlying)=='function')..' / '..tostring(type(IsSwimming)=='function'),
 'Market adapter: schema 1, integration v'..self.integrationVersion,
 'World map: '..tostring(WorldMapFrame~=nil)..' | viewport '..tostring(WorldMapFrame and WorldMapFrame.ScrollContainer~=nil)..' | map button '..tostring(self.mapControls~=nil and self.mapControls:IsShown()),
 'Map addons loaded: '..self:LoadedAddons({'OpenMap','Leatrix_Maps','Mapster','Magnify','TomTom'}),
 'Recent errors:'}
 for _,e in ipairs(self.errors) do lines[#lines+1]=e end
 return table.concat(lines,'\n')
end
function N:LoadedAddons(names)
 local check=(C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
 local found={}
 for _,name in ipairs(names) do if type(check)=='function' and self:Call(check,name) then found[#found+1]=name end end
 return #found>0 and table.concat(found,', ') or 'none detected'
end
function N:Slash(msg)
 if not self.ready then return self:Print('Nexus is not initialized.') end
 local command,args=tostring(msg or ''):match('^(%S*)%s*(.-)$'); command=command:lower()
 if command=='price' then local id,gold=args:match('^(%d+)%s+([%d%.]+)$'); self:SetPrice(id,gold)
 elseif command=='export' then self:TextDialog('Cross-account export',self:Export())
 elseif command=='import' then self:TextDialog('Cross-account import','',true)
 elseif command=='native' then
  self.db.settings.native=true
  local f=ProfessionsFrame or TradeSkillFrame or CraftFrame
  if f and not self:Call(InCombatLockdown) then f:Show() end
  self:Print('Native profession UI enabled. Open your profession normally.')
 elseif command=='pause' then self.routePaused=not self.routePaused
 elseif command=='rejoin' then self:RejoinRoute()
 elseif command=='restart' then self.waypoint=1;self.terrainIndex=1;self.routePaused=false
 elseif command=='arrowscale' then self:SetArrowScale(args)
 elseif command=='skillroute' then
  if args=='herb' or args=='ore' then self:SelectResource('skill:'..args);self:GenerateRoute()
  else self:Print('/vmn skillroute herb|ore') end
 elseif command=='route' or command=='start' then self:GenerateRoute()
 elseif command=='skip' or command=='next' then self:SkipWaypoint()
 elseif command=='stop' then self:StopRoute()
 elseif command=='target' then if args=='' then self:SelectResource('kind:all') else self:SelectResource('name:'..args) end; self:Print('Gathering: '..self:ResourceLabel())
 elseif command=='kind' then if args=='herb' or args=='ore' or args=='all' then self:SelectResource('kind:'..args) end
 elseif command=='help' then
  self:Print('/vmn opens the window. /vmn start | stop | next (route), /vmn kind herb|ore|all, /vmn target NAME, /vmn skillroute herb|ore, /vmn pair NAME, /vmn sync, /vmn price ITEM_ID GOLD, /vmn debug')
 elseif command=='mapcontrols' or command=='mapfilters' then
  self.db.settings.mapButton=true
  if args=='reset' then self.db.settings.mapButtonPos=nil end
  if WorldMapFrame and WorldMapFrame:IsShown() then
   self:EnsureMapControls();self:PlaceMapControls(args=='reset');self:RefreshMap()
   self:ToggleMapFilterMenu(self.mapControls)
  else self:ToggleMapFilterMenu() end
 elseif command=='pair' then self:PairPeer(args)
 elseif command=='unpair' then self:UnpairPeer(args)
 elseif command=='sync' then if args=='now' then self:SyncAll();self:Print('Sync requested.') else self:TextDialog('Live sync',self:SyncStatus()) end
 elseif command=='debug' then self:TextDialog('Diagnostics',self:Diagnostics())
 else if self.ui and self.ui.frame:IsShown() then self.ui.frame:Hide() else self:Show() end end
 self.dirty=true
end
-- One map-layer menu, opened from the world-map button or the minimap icon.
-- It is parented to UIParent so map replacements (OpenMap) cannot hide it.
function N:ToggleMapFilterMenu(anchor)
 if not self.mapFilterMenu then
  local f=CreateFrame('Frame','VoidMarkNexusMapFilterMenu',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
  f:SetSize(218,276)
  f:SetFrameStrata('FULLSCREEN_DIALOG')
  f:SetFrameLevel(60)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag('LeftButton')
  f:SetScript('OnDragStart',function(w) w:StartMoving() end)
  f:SetScript('OnDragStop',function(w) w:StopMovingOrSizing() end)
  if f.SetBackdrop then
   f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
   f:SetBackdropColor(.035,.025,.06,.97)
   f:SetBackdropBorderColor(.48,.25,.72,1)
  end
  local title=f:CreateFontString(nil,'OVERLAY','GameFontNormal')
  title:SetPoint('TOPLEFT',12,-14)
  title:SetText('Nexus | Map Filters')
  local close=CreateFrame('Button',nil,f,'UIPanelButtonTemplate')
  close:SetSize(24,22);close:SetPoint('TOPRIGHT',-8,-7);close:SetText('X')
  close:SetScript('OnClick',function() f:Hide() end)
  local entries={{'nodesVisible','Show gathering nodes'},{'mapShowHerbs','Herbs'},{'mapShowOre','Ore'},{'mapShowOther','Other nodes'},{'routeVisible','Show routes'},{'mapButton','Button on world map'}}
  f.checks={}
  for i,entry in ipairs(entries) do
   local key=entry[1]
   local cb=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
   cb:SetSize(24,24);cb:SetPoint('TOPLEFT',10,-(14+i*30))
   local text=f:CreateFontString(nil,'OVERLAY','GameFontHighlight')
   text:SetPoint('LEFT',cb,'RIGHT',5,0);text:SetText(entry[2])
   cb:SetScript('OnClick',function(w)
    N.db.settings[key]=w:GetChecked() and true or false
    N.dirty=true
    N:RefreshMap()
    if N.mapControls then N:EnsureMapControls() end
    if key=='routeVisible' then
     if N.activeRoute and N.db.settings.routeVisible then N:ShowArrow()
     elseif N.arrow then N.arrow:Hide() end
     if N.UpdateMinimapRoute then N:UpdateMinimapRoute() end
    end
   end)
   f.checks[key]=cb
  end
  local size=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  size:SetPoint('TOPLEFT',12,-224)
  f.sizeLabel=size
  local function resize(delta)
   local s=N.db.settings
   s.mapIconSize=math.max(5,math.min(16,(tonumber(s.mapIconSize) or 7)+delta))
   size:SetText('Icon size: '..s.mapIconSize)
   N:RefreshMap()
  end
  local smaller=CreateFrame('Button',nil,f,'UIPanelButtonTemplate')
  smaller:SetSize(36,22);smaller:SetPoint('TOPLEFT',110,-219);smaller:SetText('-')
  smaller:SetScript('OnClick',function() resize(-1) end)
  local larger=CreateFrame('Button',nil,f,'UIPanelButtonTemplate')
  larger:SetSize(36,22);larger:SetPoint('TOPLEFT',152,-219);larger:SetText('+')
  larger:SetScript('OnClick',function() resize(1) end)
  local hint=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  hint:SetPoint('BOTTOMLEFT',12,11);hint:SetText('Drag to move. /vmn mapcontrols')
  f:Hide()
  self.mapFilterMenu=f
 end
 local f=self.mapFilterMenu
 if f:IsShown() then f:Hide();return end
 for key,cb in pairs(f.checks) do cb:SetChecked(self.db.settings[key]~=false) end
 f.sizeLabel:SetText('Icon size: '..(tonumber(self.db.settings.mapIconSize) or 7))
 f:ClearAllPoints()
 f.anchoredToMap=anchor~=nil and anchor==self.mapControls
 if anchor then f:SetPoint('TOPRIGHT',anchor,'BOTTOMRIGHT',0,-4)
 elseif self.minimap then f:SetPoint('TOPLEFT',self.minimap,'BOTTOMRIGHT',8,-4)
 else f:SetPoint('CENTER',UIParent,'CENTER') end
 f:Show()
end
function N:MinimapButton()
 if not Minimap then return end
 local b=CreateFrame('Button','VoidMarkNexusMinimap',Minimap)
 b:SetSize(28,28)
 b:SetFrameStrata('MEDIUM')
 local icon=b:CreateTexture(nil,'ARTWORK')
 icon:SetAllPoints()
 icon:SetTexture('Interface\\Icons\\INV_Misc_Gem_Amethyst_02')
 local function position()
  local angle=math.rad(tonumber(N.db.settings.minimapAngle) or 135)
  local radius=(Minimap:GetWidth() or 140)/2+8
  b:ClearAllPoints()
  b:SetPoint('CENTER',Minimap,'CENTER',math.cos(angle)*radius,math.sin(angle)*radius)
 end
 b:RegisterForClicks('LeftButtonUp','RightButtonUp')
 local wasDragged=false
 local function updatePosition()
  local scale=Minimap:GetEffectiveScale()
  local mx,my=Minimap:GetCenter()
  local cx,cy=GetCursorPosition()
  if not scale or scale<=0 or not mx or not my or not cx or not cy then return end
  local dx,dy=cx/scale-mx,cy/scale-my
  local angle
  if math.atan2 then angle=math.atan2(dy,dx)
  elseif dx==0 then angle=dy>=0 and math.pi/2 or -math.pi/2
  else
   angle=math.atan(dy/dx)
   if dx<0 then angle=angle+math.pi end
  end
  N.db.settings.minimapAngle=math.deg(angle)
  position()
 end
 b:SetScript('OnMouseDown',function(_,key)
  if key~='LeftButton' then return end
  local x,y=GetCursorPosition()
  b.pressX,b.pressY=x,y
  wasDragged=false
  b:SetScript('OnUpdate',function()
   local cx,cy=GetCursorPosition()
   if not cx or not cy then return end
   if not wasDragged then
    local dx,dy=cx-b.pressX,cy-b.pressY
    if dx*dx+dy*dy>=16 then wasDragged=true end
   end
   if wasDragged then updatePosition() end
  end)
 end)
 b:SetScript('OnMouseUp',function(_,key)
  if key=='LeftButton' then b:SetScript('OnUpdate',nil) end
 end)
 b:SetScript('OnClick',function(_,key)
  if key=='LeftButton' and wasDragged then wasDragged=false; return end
  if key=='RightButton' then N:ToggleMapFilterMenu() else N:Slash('') end
 end)
 b:SetScript('OnEnter',function()
  GameTooltip:SetOwner(b,'ANCHOR_LEFT')
  GameTooltip:SetText('VoidMark Nexus')
  GameTooltip:AddLine('Left: Open | Right: Map filters')
  GameTooltip:AddLine('Left-drag: Move around minimap')
  GameTooltip:Show()
 end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 position()
 b:SetShown(self.db.settings.minimap)
 self.minimap=b
end

local frame=CreateFrame('Frame')
frame:RegisterEvent('ADDON_LOADED'); frame:RegisterEvent('PLAYER_LOGIN')
for event in pairs(N.handlers) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript('OnEvent',function(_,event,...)
 if event=='ADDON_LOADED' then
  if ...=='VoidMarkNexus' then N:Guard('initialize',function() N:Initialize() end) end
 elseif event=='PLAYER_LOGIN' then
  if not N.ready then return end
  N:Guard('login',function() N:ScanProfessions(); N:ScanStorage(false); N:RestoreSession(); N:MinimapButton(); N:RestoreNavigation(); N:HookTooltips();if C_Timer and C_Timer.After then C_Timer.After(8,function() N:Guard('sync',function() N:SyncAll() end) end) end;if N.recording then N:Print(N:RecordingStatus()) end end)
  if C_Timer and C_Timer.NewTicker then
   C_Timer.NewTicker(1,function() if WorldMapFrame and WorldMapFrame:IsShown() then N:Guard('map',function() N:RefreshMap() end) end end)
   -- Background work only for features that are switched on.
   C_Timer.NewTicker(.5,function() N:Guard('tick',function()
    if N.db.settings.terrainLearn then N:SampleTerrain() end
    if N.recording then N:SampleRecording() end
    if N.activeRoute or N.tomtomUID then N:SyncTomTom() end
   end) end)
  end
 elseif N.ready then for _,fn in ipairs(N.handlers[event] or {}) do N:Guard(event,fn,...) end end
end)
SLASH_VOIDMARKNEXUS1='/vmn'
SlashCmdList.VOIDMARKNEXUS=function(msg) N:Guard('command',function() N:Slash(msg) end) end
BINDING_HEADER_VOIDMARKNEXUS='VoidMark Nexus'
BINDING_NAME_VOIDMARKNEXUS_TOGGLE='Open VoidMark Nexus'

