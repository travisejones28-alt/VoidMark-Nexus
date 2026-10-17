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
 'Terrain: observed directional trails only; no collision/elevation API used. Limits: 50 zones / 600 samples / 2400 edges each.',
 'Market adapter: schema 1, integration v'..self.integrationVersion,'Recent errors:'}
 for _,e in ipairs(self.errors) do lines[#lines+1]=e end
 return table.concat(lines,'\n')
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
 elseif command=='block' then self:MarkRouteObstacle(args)
 elseif command=='clearblocks' then self:ClearRouteObstacles()
 elseif command=='terrain' then
  if args=='clear' then self:ClearTerrain()
  elseif args=='on' or args=='off' then self.db.settings.terrainLearn=args=='on';self.trailPrevious=nil
  else local map=self:Position();local z=map and self:TerrainZone(map);self:Print('Learned samples: '..(z and #z.points or 0)..'; directed connections: '..(z and z.edgeCount or 0)..'. /vmn terrain on|off|clear') end
 elseif command=='check' then
  if args=='empty' or args=='available' then self:CheckGatherStop(args=='available') else self:Print('/vmn check empty|available') end
 elseif command=='pause' then self.routePaused=not self.routePaused
 elseif command=='restart' then self.waypoint=1;self.terrainIndex=1;self.routePaused=false
 elseif command=='arrowscale' then self:SetArrowScale(args)
 elseif command=='cancelplan' then self:CancelPlanner('Route calculation cancelled.')
 elseif command=='route' then self:GenerateRoute()
 elseif command=='skip' then self:SkipWaypoint()
 elseif command=='stop' then self.activeRoute=nil; if self.arrow then self.arrow:Hide() end
 elseif command=='save' then self:SaveRoute(args)
 elseif command=='waypoint' then self:AddWaypoint()
 elseif command=='target' then self.db.settings.target=args; self:Print('Node filter: '..(args=='' and 'All' or args))
 elseif command=='kind' then if args=='herb' or args=='ore' or args=='all' then self.db.settings.kind=args end
 elseif command=='debug' then self:TextDialog('Diagnostics',self:Diagnostics())
 else if self.ui and self.ui.frame:IsShown() then self.ui.frame:Hide() else self:Show() end end
 self.dirty=true
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
  if key=='RightButton' then N:Show('Settings') else N:Slash('') end
 end)
 b:SetScript('OnEnter',function()
  GameTooltip:SetOwner(b,'ANCHOR_LEFT')
  GameTooltip:SetText('VoidMark Nexus')
  GameTooltip:AddLine('Left: Open | Right: Settings')
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
  N:Guard('login',function() N:ScanProfessions(); N:ScanStorage(false); N:StartSession(); N:MinimapButton(); N:RestoreNavigation() end)
  if C_Timer and C_Timer.NewTicker then
   C_Timer.NewTicker(1,function() if WorldMapFrame and WorldMapFrame:IsShown() then N:Guard('map',function() N:RefreshMap() end) end end)
   C_Timer.NewTicker(.5,function() N:Guard('terrain sampling',function() N:SampleTerrain();N:TrackRouteSession() end) end)
  end
 elseif N.ready then for _,fn in ipairs(N.handlers[event] or {}) do N:Guard(event,fn,...) end end
end)
SLASH_VOIDMARKNEXUS1='/vmn'
SlashCmdList.VOIDMARKNEXUS=function(msg) N:Guard('command',function() N:Slash(msg) end) end
BINDING_HEADER_VOIDMARKNEXUS='VoidMark Nexus'
BINDING_NAME_VOIDMARKNEXUS_TOGGLE='Open VoidMark Nexus'

