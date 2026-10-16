local _, N = ...
local tabs={'Dashboard','Professions','Recipes','Crafting','Profitability','Gathering','Routes','Inventory','Characters','Settings'}
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
 for i,c in ipairs(choices) do button(child,c.label,0,-(i-1)*25,230,function() menu:Hide(); fn(c.value); N.dirty=true end) end
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
   local preview,err=N:PreviewImport(e:GetText()); f.status:SetText(preview and 'Review changes above, then confirm. Close to cancel.' or tostring(err))
   if preview then local pending=N.pendingImport; e:SetText(preview); N.pendingImport=pending; f.preview:Disable(); N.importPreview=preview; f.confirm:Enable() else f.confirm:Disable() end
  end)
  f.confirm=button(f,'Confirm import',188,-438,160,function() N:ConfirmImport(); f:Hide() end)
  f.status=label(f,'',18,-408,'GameFontHighlightSmall'); f.status:SetWidth(670)
  f.review=button(f,'View preview',358,-438,150,function() if N.importPreview then N:Print(N.importPreview) end end)
  self.dialog=f
 end
 local f=self.dialog; f.title:SetText(title); f.edit:SetText(text or ''); f.edit:HighlightText(); f.confirm:Disable()
 f.preview:SetShown(import==true); f.confirm:SetShown(import==true); f.review:SetShown(import==true)
 f.preview:Enable(); f.status:SetText(import and 'Paste VMN1 export, then preview and review before confirming.' or 'Ctrl+A, Ctrl+C to copy.'); f:Show()
end
function N:Show(tab)
 if not self.ui then self:CreateUI() end
 self.ui.tab=tab or self.ui.tab or 'Dashboard'; self.ui.frame:Show(); self.dirty=true; self:Render()
end
function N:CreateUI()
 local f=CreateFrame('Frame','VoidMarkNexusWindow',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil); skin(f)
 f:SetSize(1060,660); f:SetFrameStrata('MEDIUM'); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
 local position=self.db.settings.position; if type(position)=='table' then f:SetPoint('CENTER',UIParent,'CENTER',position[1],position[2]) else f:SetPoint('CENTER') end
 f:SetScale(self.db.settings.scale)
 f:SetScript('OnDragStart',function() f:StartMoving() end)
 f:SetScript('OnDragStop',function() f:StopMovingOrSizing(); local x,y=f:GetCenter(); local ux,uy=UIParent:GetCenter(); N.db.settings.position={x-ux,y-uy} end)
 label(f,'VOIDMARK  |  NEXUS',18,-17,'GameFontNormalLarge'); label(f,self.version,280,-19,'GameFontHighlightSmall')
 button(f,'Close',956,-10,86,function() f:Hide(); if N.menu then N.menu:Hide() end end)
 self.ui={frame=f,tab='Dashboard',rows={},page=1,filter='All'}; local u=self.ui
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
 u.filterButton=button(f,'All',830,-55,210,function()
  local choices={}; for _,v in ipairs({'All','Known','Unknown','Wishlist','Profit','Loss','Missing','Available','Fresh','Cost ascending','Profit descending','Margin descending'}) do choices[#choices+1]={label=v,value=v} end
  N:Choice(u.filterButton,choices,function(v) u.filter=v; u.page=1 end)
 end)
 u.heading=label(f,'',164,-95); u.heading:SetWidth(875)
 for i=1,16 do
  local row=CreateFrame('Button',nil,f); row:SetSize(535,27); row:SetPoint('TOPLEFT',160,-125-(i-1)*28)
  row.bg=row:CreateTexture(nil,'BACKGROUND'); row.bg:SetAllPoints(); row.bg:SetColorTexture(.1,.07,.15,i%2==0 and .9 or .4)
  row.icon=row:CreateTexture(nil,'ARTWORK'); row.icon:SetSize(20,20); row.icon:SetPoint('LEFT',3,0)
  row.text=label(row,'',28,-6,'GameFontHighlightSmall'); row.text:SetWidth(500); row.text:SetWordWrap(false)
  row:SetScript('OnClick',function() if row.data then u.selected=row.data; N.dirty=true end end)
  row:SetScript('OnEnter',function() if row.data and row.data.item then GameTooltip:SetOwner(row,'ANCHOR_RIGHT'); GameTooltip:SetHyperlink('item:'..row.data.item); GameTooltip:Show() end end)
  row:SetScript('OnLeave',function() GameTooltip:Hide() end); u.rows[i]=row
 end
 local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',715,-125); scroll:SetSize(300,440)
 local child=CreateFrame('Frame',nil,scroll); child:SetSize(295,440); scroll:SetScrollChild(child)
 u.detail=label(child,'',0,0,'GameFontHighlightSmall'); u.detail:SetWidth(290); u.detail:SetSpacing(4); u.detail:SetWordWrap(true); u.detailChild=child
 button(f,'Previous',164,-583,100,function() u.page=math.max(1,u.page-1); u.selected=nil; N.dirty=true end)
 button(f,'Next',270,-583,100,function() u.page=u.page+1; u.selected=nil; N.dirty=true end)
 u.pageLabel=label(f,'',385,-589,'GameFontHighlightSmall')
 u.value=edit(f,555,-584,140,'1'); u.actions={}
 u.value:SetScript('OnTextChanged',function() N.dirty=true end)
 for i=1,3 do u.actions[i]=button(f,'',708+(i-1)*112,-583,108,function() local fn=u.actionFns and u.actionFns[i]; if fn then fn() end; N.dirty=true end) end
 u.footer=label(f,'',164,-625,'GameFontHighlightSmall'); u.footer:SetWidth(875)
 f:EnableMouseWheel(true); f:SetScript('OnMouseWheel',function(_,delta) u.page=math.max(1,u.page-delta); u.selected=nil; N.dirty=true end)
 local elapsed=0; f:SetScript('OnUpdate',function(_,dt) elapsed=elapsed+dt; if elapsed>.3 then elapsed=0; if N.dirty then N:Guard('UI',function() N:Render() end) end end end)
 table.insert(UISpecialFrames,'VoidMarkNexusWindow')
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
  lines[#lines+1]='  '..(g.price and (self:Money(g.price.unit)..' / '..g.price.source..' / '..self:Age(g.price.at)) or 'Unknown price')
  for _,a in ipairs(g.allocations) do lines[#lines+1]='  '..a.qty..': '..a.transfer..' ('..self:Age(a.at)..')' end
 end
 return table.concat(lines,'\n')
end
function N:SettingsRows()
 local rows={}; local s=self.db.settings
 local booleans={{'native','Open native profession UI'},{'learn','Learn gathering nodes'},{'importedNodes','Show potential spawns'},{'observedNodes','Show observed nodes'},
 {'nodesVisible','Map nodes'},{'routeVisible','Route guidance'},{'stats','Gathering statistics'},{'includeAlts','Use alt inventory'},{'includeBanks','Use bank inventory'},
 {'includeImports','Use imported inventory'},{'includeStale','Use stale inventory'},{'market','VoidMark Market prices'},{'auctionator','Auctionator prices (age unknown)'},{'manualFirst','Prefer manual prices'},{'minimap','Minimap button'}}
 for _,v in ipairs(booleans) do rows[#rows+1]={text=v[2]..': '..tostring(s[v[1]]),key=v[1],boolean=true,detail='Select and press Apply to toggle. Foreign realms/factions remain excluded. Item binding/transfer restrictions must be checked in game.'} end
 for _,v in ipairs({{'maxAge','Price expiration (seconds)',60,2592000},{'inventoryAge','Inventory expiration (seconds)',60,2592000},
 {'cut','Auction cut (0.05 = 5%)',0,.3},{'deposit','Deposit per craft (copper)',0,1e8},{'failedAuctions','Failed listings per craft',0,20},
 {'saleFraction','Expected sold fraction',0,1},{'waste','Additional material cost fraction',0,1},{'speed','Travel speed (yards/sec)',1,50},
 {'mountDelay','Remount/form delay per node (seconds)',0,30},{'gatherDelay','Gathering delay per node (seconds)',0,60},
 {'routeMinutes','Route time budget (minutes)',1,120},{'nodeLimit','Maximum route waypoints',2,150},{'scale','Window scale',.6,1.5}}) do
  rows[#rows+1]={text=v[2]..': '..s[v[1]],key=v[1],min=v[3],max=v[4],detail='Enter a value in the bottom field and press Apply. These are user assumptions, not measured predictions.'}
 end
 return rows
end
function N:Render()
 local u=self.ui; if not u or not u.frame:IsShown() then return end; self.dirty=false
 self.renderStocks={}
 local rows,detail={},''; local selected=u.selected; local tab=u.tab
 local c=u.character and self.db.characters[u.character]
 u.characterButton:SetText(c and c.name or 'All characters'); u.professionButton:SetText(u.profession or 'All professions'); u.filterButton:SetText(u.filter)
 u.heading:SetText(tab..'  |  '..(tab=='Settings' and 'Select setting; Apply uses the bottom value field' or 'Search above; quantity or action value below'))
 self:SetActions({},{}); u.footer:SetText('Offline data is cached. Open each profession and bank once to record it. /vmn native restores Blizzard access.')
 if tab=='Recipes' or tab=='Profitability' then
  local filter=({'All','Known','Unknown','Wishlist'})[1]; if u.filter=='Known' or u.filter=='Unknown' or u.filter=='Wishlist' then filter=u.filter end
  for _,r in ipairs(self:Search(u.search:GetText(),u.character,u.profession,filter)) do
   local e=self:Evaluate(r.r,1,r.character); local missing=0; for _,g in ipairs(e.rows) do missing=missing+g.missing end
   local accept=u.filter~='Profit' and u.filter~='Loss' and u.filter~='Missing' and u.filter~='Available' and u.filter~='Fresh'
    or u.filter=='Profit' and e.economic and e.economic>0 or u.filter=='Loss' and e.economic and e.economic<0
    or u.filter=='Missing' and missing>0 or u.filter=='Available' and missing==0 and not e.unknown or u.filter=='Fresh' and not e.stale and not e.unknown
   if accept then r.text=r.r.name..' | '..r.c.name..' | '..self:Money(e.economic); r.item=r.r.output; r.icon=r.r.icon; r.e=e; rows[#rows+1]=r end
  end
  if u.filter=='Cost ascending' then table.sort(rows,function(a,b) return (a.e.cost or math.huge)<(b.e.cost or math.huge) end)
  elseif u.filter=='Profit descending' or u.filter=='Margin descending' then local k=u.filter=='Profit descending' and 'economic' or 'margin'; table.sort(rows,function(a,b) return (a.e[k] or -math.huge)>(b.e[k] or -math.huge) end) end
  self:SetActions({'Queue','Craft','Wishlist'},{function() if u.selected then N:AddPlan(u.selected,u.value:GetText()) end end,function() if u.selected then N:Craft(u.selected,u.value:GetText()) end end,function() if u.selected then local k=u.selected.recipe; N.db.wish[k]=not N.db.wish[k] end end})
  if selected and selected.r then detail=self:RecipeDetail(selected) end
 elseif tab=='Professions' then
  for id,ch in pairs(self.db.characters) do if not u.character or id==u.character then for pid,p in pairs(ch.professions) do
   rows[#rows+1]={text=ch.name..' | '..p.name..' '..(p.skill or 0)..'/'..(p.max or 0),character=id,profession=pid,detail='Last observed: '..self:Age(p.at)..'\nOpen Recipes to browse. Leveling recommends a short batch using current difficulty; rescan after gains. Probability assumptions: orange 1, yellow 0.5, green 0.25. Exact thresholds are not available.'}
  end end end
  self:SetActions({'Recipes','Level cheap','Use stock'},{function() if u.selected then u.character=u.selected.character; u.profession=u.selected.profession; u.tab='Recipes'; u.selected=nil end end,
   function() N:ShowLeveling('Gold') end,function() N:ShowLeveling('Inventory') end})
 elseif tab=='Crafting' then
  for i,p in ipairs(self.db.plans) do local r=self:Recipe(p); rows[#rows+1]={text=(r and r.name or 'Missing recipe')..' x'..p.qty,index=i,detail='Planned work only. Materials are allocated once across the complete queue. Edit quantity below or export the shopping list.'} end
  self:SetActions({'Set qty','Remove','Shopping'},{function() if u.selected then local p=N.db.plans[u.selected.index]; if p then p.qty=math.max(1,math.min(9999,math.floor(tonumber(u.value:GetText()) or 1))) end end end,
   function() if u.selected then table.remove(N.db.plans,u.selected.index); u.selected=nil end end,function() N:TextDialog('Material shopping list',N:ShoppingText()) end})
  detail=self:ShoppingText()
 elseif tab=='Inventory' then
  local query=u.search:GetText():lower()
  for id,ch in pairs(self.db.characters) do if not u.character or id==u.character then for _,loc in ipairs({'bags','bank'}) do for item,qty in pairs(ch[loc]) do
   local name=self:ItemName(item); if query=='' or name:lower():find(query,1,true) then rows[#rows+1]={text=name..' x'..qty..' | '..ch.name..' / '..loc,item=item,detail=name..'\n'..ch.name..' / '..ch.realm..' / '..ch.faction..'\n'..self:Age(ch[loc..'At'])..'\nCached inventory may have changed. Cross-realm/faction transfers are not included.'} end
  end end end end
  self:SetActions({'Set price','Market','Prices'},{function() if u.selected then N:SetPrice(u.selected.item,u.value:GetText()) end end,function() if u.selected then N:OpenMarket(u.selected.item) end end,function() N:TextDialog('Manual prices', 'Use /vmn price ITEM_ID GOLD\nFor example: /vmn price 2447 0.25\nEnable Prefer manual prices in Settings to override Market.') end})
 elseif tab=='Characters' then
  for id,ch in pairs(self.db.characters) do rows[#rows+1]={text=ch.name..' | '..ch.realm..' | '..ch.faction..(ch.imported and ' [Imported]' or '')..(self.db.excluded[id] and ' [Excluded]' or ''),character=id,detail='Account: '..ch.account..'\n'..self:Age(ch.at)..'\nBags: '..self:Age(ch.bagsAt)..'\nBank: '..self:Age(ch.bankAt)..'\nImported inventories require opt-in in Settings.'} end
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
  local seconds,rate,gph=self:SessionStats(); detail=string.format('Current session\n%.1f minutes\n%.1f materials/hour\nEstimated value/hour: %s\nOnly confirmed gathering loot is counted. Prices are estimates; unpriced items make total value unknown.',seconds/60,rate,self:Money(gph))
  if self.session then for id,qty in pairs(self.session.items) do rows[#rows+1]={text=self:ItemName(id)..' x'..qty,item=id} end end
  for i,s in ipairs(self.db.sessions) do local secs,r,g=self:SessionStats(s); rows[#rows+1]={text='Saved session '..i..': '..s.total..' items / '..math.floor(secs/60)..' min',detail='Measured rate: '..math.floor(r)..'/hour\nEstimated value/hour: '..self:Money(g)..'\nCharacter: '..s.character} end
  self:SetActions({'Save/reset','Discard/reset','Routes'},{function() N:SaveSession() end,function() N:StartSession() end,function() u.tab='Routes'; u.selected=nil end})
 elseif tab=='Routes' then
  local map=self:Position(); local nodes=map and self:ZoneNodes(map) or {}; local s=self.db.settings
  detail='Travel: '..s.travel..' ('..s.speed..' yd/s)\nTime budget: '..s.routeMinutes..' minutes\nRemount/form delay: '..s.mountDelay..'s per node\n'..#nodes..' candidate locations\n\nRoutes use direct distances and a bounded 2-opt improvement. Terrain, cliffs, roads and live competition are not known. Waypoints are potential spawns, not guaranteed resources.\n\n/vmn kind herb|ore|all\n/vmn target Silverleaf\n/vmn save NAME\n/vmn waypoint (add your position)\n/vmn skip\n/vmn stop\nCustom speed and route limits: Settings.'
  for name,r in pairs(self.db.routes) do rows[#rows+1]={text='Saved: '..name..' | '..#r.points..' waypoints',routeName=name,detail='Use Load selected to navigate this saved route.'} end
  if self.activeRoute then for i,p in ipairs(self.activeRoute.points) do rows[#rows+1]={text=i..'. '..(p.name or 'Waypoint')..string.format(' (%.1f, %.1f)',p.x*100,p.y*100),detail=p.source or 'Custom waypoint'} end end
  self:SetActions({'Travel mode','Generate','Load selected'},{function()
   local choices={}; for i,m in ipairs(N.travelModes) do choices[#choices+1]={label=m[1],value=i} end
   N:Choice(u.actions[1],choices,function(i) local m=N.travelModes[i]; s.travel=m[1]; s.speed=m[2]; s.mountDelay=m[3] end)
  end,function() N:GenerateRoute() end,function() if u.selected and u.selected.routeName then N.activeRoute=N:Copy(N.db.routes[u.selected.routeName]); N.waypoint=1; N:ShowArrow() end end})
 else
  local n=0; for _ in pairs(self.db.characters) do n=n+1 end
  rows={{text=self.character.name..' - '..self.character.realm..' / '..self.character.faction},
   {text=n..' recorded characters; '..#self.db.plans..' planned crafts'},
   {text='Market: '..(VoidMarkMarketDB and 'Detected; compatible realm/faction prices enabled by setting' or 'Not loaded; Nexus works independently')},
   {text='Open each profession to record its recipes; visit the bank to refresh inventory.'},
   {text='Gathering routes: choose travel mode, resource filter and Generate.'},
   {text='Cross-account export/import: Characters tab.'}}
  for _,p in pairs(self.character.professions) do rows[#rows+1]={text=p.name..' '..(p.skill or 0)..'/'..(p.max or 0)} end
  detail='VoidMark Nexus '..self.version..'\n\nStandalone profession and gathering workspace.\n\nUse Recipes for account-wide search. Select a character to browse offline professions.\n\nCrafting plans do not execute automatically.\n\nPrice an item: /vmn price ITEM_ID GOLD\n\nThis alpha requires in-game validation on your Forever build.'
  self:SetActions({'Recipes','Shopping','Refresh bags'},{function() u.tab='Recipes'; u.selected=nil end,function() N:TextDialog('Shopping list',N:ShoppingText()) end,function() N:ScanStorage(false); N:ScanProfessions() end})
 end
 if selected and selected.detail then detail=selected.detail end
 local pages=math.max(1,math.ceil(#rows/16)); u.page=math.min(pages,math.max(1,u.page)); u.pageLabel:SetText(u.page..' / '..pages..'  ('..#rows..')')
 for i,b in ipairs(u.rows) do local r=rows[(u.page-1)*16+i]; b.data=r; b:SetShown(r~=nil)
  if r then b.text:SetText(r.text); b.icon:SetTexture(r.icon or (r.item and self:Call(GetItemIcon,r.item)) or 'Interface\\Icons\\INV_Misc_Gem_Amethyst_02') end
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
function N:ShowLeveling(mode)
 local r=self.ui.selected; if not r or not r.profession then return end
 local result=self:Leveling(r.character,r.profession,tonumber(self.ui.value:GetText()),mode)
 local lines={'Short-horizon recommendations (maximum 10 points). Difficulty probabilities are assumptions. Rescan after each skill gain. Training/specialization requirements remain enforced by the client.'}
 for i=1,math.min(10,#result) do local a=result[i]; lines[#lines+1]=a.name..': ~'..a.qty..' crafts | '..self:Money(a.cash)..' cash | '..a.missing..' missing reagents' end
 if #result==0 then lines[#lines+1]='No priced, known, non-gray recipes with readable materials. Open the profession or supply manual prices.' end
 self:TextDialog('Leveling: '..mode,table.concat(lines,'\n'))
end
