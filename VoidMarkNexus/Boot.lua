local _, N = ...
function N:Diagnostics()
 local version,build,_,toc=self:Call(GetBuildInfo)
 local lines={'VoidMark Nexus '..self.version,'Client '..tostring(version)..' / '..tostring(build)..' / interface '..tostring(toc),
 'Modern recipes: '..tostring(C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeSchematic)=='function'),
 'Legacy recipes: '..tostring(type(GetTradeSkillInfo)=='function'),
 'Container API: '..tostring(C_Container~=nil),'Map position: '..tostring(C_Map~=nil),
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
 local b=CreateFrame('Button','VoidMarkNexusMinimap',Minimap); b:SetSize(28,28); b:SetPoint('TOPLEFT',Minimap,'TOPLEFT',-4,4)
 b:SetFrameStrata('MEDIUM'); local icon=b:CreateTexture(nil,'ARTWORK'); icon:SetAllPoints(); icon:SetTexture('Interface\\Icons\\INV_Misc_Gem_Amethyst_02')
 b:RegisterForClicks('LeftButtonUp','RightButtonUp'); b:SetScript('OnClick',function(_,key) if key=='RightButton' then N:Show('Settings') else N:Slash('') end end)
 b:SetScript('OnEnter',function() GameTooltip:SetOwner(b,'ANCHOR_LEFT'); GameTooltip:SetText('VoidMark Nexus'); GameTooltip:AddLine('Left: Open | Right: Settings'); GameTooltip:Show() end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end); b:SetShown(self.db.settings.minimap); self.minimap=b
end
local frame=CreateFrame('Frame')
frame:RegisterEvent('ADDON_LOADED'); frame:RegisterEvent('PLAYER_LOGIN')
for event in pairs(N.handlers) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript('OnEvent',function(_,event,...)
 if event=='ADDON_LOADED' then
  if ...=='VoidMarkNexus' then N:Guard('initialize',function() N:Initialize() end) end
 elseif event=='PLAYER_LOGIN' then
  if not N.ready then return end
  N:Guard('login',function() N:ScanProfessions(); N:ScanStorage(false); N:StartSession(); N:MinimapButton() end)
  if C_Timer and C_Timer.NewTicker then
   C_Timer.NewTicker(1,function() if WorldMapFrame and WorldMapFrame:IsShown() then N:Guard('map',function() N:RefreshMap() end) end end)
  end
 elseif N.ready then for _,fn in ipairs(N.handlers[event] or {}) do N:Guard(event,fn,...) end end
end)
SLASH_VOIDMARKNEXUS1='/vmn'
SlashCmdList.VOIDMARKNEXUS=function(msg) N:Guard('command',function() N:Slash(msg) end) end
BINDING_HEADER_VOIDMARKNEXUS='VoidMark Nexus'
BINDING_NAME_VOIDMARKNEXUS_TOGGLE='Open VoidMark Nexus'
