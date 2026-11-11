local _, N = ...
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
-- Compact window (0.5): Gather | Professions | Characters | Settings.
local W,H=460,560
local TOP=176          -- list starts below each page's controls
local ROW_H=24
local pages={'Gather','Professions','Characters','Settings'}
-- Older tab names open the page that replaced them.
local alias={Dashboard='Gather',Home='Gather',Routes='Gather',Gathering='Gather',Recipes='Professions',
 Profitability='Professions',Leveling='Professions',Crafting='Professions',Inventory='Characters'}
local COLORS={orange={1,.5,.25},yellow={1,1,0},green={.25,.75,.25},gray={.6,.6,.6},
 good={.3,.9,.3},bad={1,.35,.35},muted={.65,.6,.72},white={1,1,1},accent={.78,.6,1}}

function N:Ago(at)
 if not at then return 'never' end
 local s=math.max(0,self:Now()-at)
 if s<3600 then return math.floor(s/60)..'m ago' elseif s<172800 then return math.floor(s/3600)..'h ago' end
 return math.floor(s/86400)..'d ago'
end

function N:Show(tab)
 if not self.ui then self:CreateUI() end
 local u=self.ui
 if tab=='Recipes' or tab=='Profitability' then u.profView='recipes' elseif tab=='Leveling' then u.profView='level' end
 u.tab=alias[tab] or tab or u.tab or 'Gather'
 u.offset=0; u.frame:Show(); self.dirty=true; self:Render()
end

local function check(parent,text,x,y,get,set)
 local cb=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate')
 cb:SetSize(24,24); cb:SetPoint('TOPLEFT',x,y)
 local l=parent:CreateFontString(nil,'OVERLAY','GameFontHighlight'); l:SetPoint('LEFT',cb,'RIGHT',4,0); l:SetText(text)
 cb:SetScript('OnClick',function(self) N:Guard(text,function() set(self:GetChecked() and true or false) end); N.dirty=true end)
 cb.get=get; cb.label=l
 return cb
end

function N:CreateUI()
 local f=CreateFrame('Frame','VoidMarkNexusWindow',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil); skin(f)
 f:SetSize(W,H); f:SetFrameStrata('MEDIUM'); f:SetToplevel(true); f:SetClampedToScreen(true)
 f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
 local position=self.db.settings.position
 if type(position)=='table' then f:SetPoint('CENTER',UIParent,'CENTER',position[1],position[2]) else f:SetPoint('CENTER') end
 f:SetScale(self.db.settings.scale)
 f:SetScript('OnDragStart',function() f:StartMoving() end)
 f:SetScript('OnDragStop',function() f:StopMovingOrSizing(); local x,y=f:GetCenter(); local ux,uy=UIParent:GetCenter(); if x and ux then N.db.settings.position={x-ux,y-uy} end end)
 label(f,'VoidMark Nexus',14,-13,'GameFontNormalLarge')
 local close=button(f,'X',0,0,28,function() f:Hide(); if N.menu then N.menu:Hide() end end)
 close:ClearAllPoints(); close:SetPoint('TOPRIGHT',f,'TOPRIGHT',-8,-8)
 local u={frame=f,tab='Gather',profView='level',offset=0,rows={},tabs={},pages={}}
 self.ui=u
 -- Find an item anywhere: typing jumps to Characters and lists every place it is.
 u.find=edit(f,180,-9,200,'')
 u.findHint=u.find:CreateFontString(nil,'OVERLAY','GameFontDisable'); u.findHint:SetPoint('LEFT',4,0); u.findHint:SetText('Find item...')
 u.find:SetScript('OnTextChanged',function(e)
  local text=e:GetText(); u.findHint:SetShown(text=='')
  if text~='' then u.tab='Characters' end
  u.offset=0; N.dirty=true
 end)
 u.find:SetScript('OnEscapePressed',function(e) e:SetText(''); e:ClearFocus() end)
 u.find:SetScript('OnEnterPressed',function(e) e:ClearFocus() end)
 -- Shift-clicking an item while the box has focus searches for it.
 if hooksecurefunc and type(ChatEdit_InsertLink)=='function' then
  hooksecurefunc('ChatEdit_InsertLink',function(link)
   if u.find:HasFocus() and type(link)=='string' then local name=link:match('|h%[(.-)%]|h'); if name then u.find:SetText(name) end end
  end)
 end
 for i,name in ipairs(pages) do
  u.tabs[name]=button(f,name,12+(i-1)*109,-40,105,function() u.tab=name; u.offset=0; if N.menu then N.menu:Hide() end; N.dirty=true end)
 end
 for _,name in ipairs(pages) do
  local p=CreateFrame('Frame',nil,f); p:SetPoint('TOPLEFT',0,-72); p:SetSize(W,TOP-72); u.pages[name]=p
 end
 -- Gather controls
 local g=u.pages.Gather
 label(g,'Gather',14,-6,'GameFontNormal')
 u.what=button(g,'Herbs',70,0,200,function() N:ChooseResource(u.what) end)
 u.travel=button(g,'Foot',278,0,168,function()
  local options={}; for i,m in ipairs(N.travelModes) do if m[1]~='Custom' then options[#options+1]={label=m[1],value=i} end end
  N:Choice(u.travel,options,function(i) local m=N.travelModes[i]; local s=N.db.settings; s.travel,s.speed,s.mountDelay=m[1],m[2],m[3] end)
 end)
 u.start=button(g,'Start route',14,-32,150,function() if N.activeRoute then N:StopRoute() else N:OpenRoutePlanner() end end)
 u.next=button(g,'Next stop',170,-32,110,function() N:SkipWaypoint() end)
 u.zones=button(g,'Best zones',286,-32,160,function() u.bestZones=N:BestZones(6); u.offset=0 end)
 u.gatherInfo=label(g,'',14,-64,'GameFontHighlight'); u.gatherInfo:SetWidth(W-28)
 -- Professions controls
 local pr=u.pages.Professions
 u.prof=button(pr,'Pick a profession',14,0,250,function() N:ChooseProfession(u.prof) end)
 u.viewLevel=button(pr,'Level up',270,0,86,function() u.profView='level'; u.offset=0 end)
 u.viewRecipes=button(pr,'Recipes',360,0,86,function() u.profView='recipes'; u.offset=0 end)
 u.mode=button(pr,'Cheapest',14,-32,130,function()
  local options={}; for _,m in ipairs(N.levelModes) do options[#options+1]={label=m,value=m} end
  N:Choice(u.mode,options,function(v) N.db.settings.levelMode=v end)
 end)
 u.targetLabel=label(pr,'Up to skill',156,-37,'GameFontHighlight')
 u.target=edit(pr,240,-32,56,''); u.target:SetScript('OnTextChanged',function() N.dirty=true end)
 u.search=edit(pr,20,-32,260,''); u.search:SetScript('OnTextChanged',function() u.offset=0; N.dirty=true end)
 u.profInfo=label(pr,'',14,-64,'GameFontHighlight'); u.profInfo:SetWidth(W-28)
 -- Characters controls
 local ch=u.pages.Characters
 u.syncNow=button(ch,'Sync now',14,0,100,function() N:SyncAll(); N:Print('Sync requested.') end)
 u.pairName=edit(ch,126,0,150,'')
 u.pair=button(ch,'Pair',282,0,60,function() local name=u.pairName:GetText(); if name~='' then N:PairPeer(name); u.pairName:SetText('') end end)
 u.exportB=button(ch,'Export',348,0,98,function() N:Choice(u.exportB,{{label='Export (copy)',value='e'},{label='Import (paste)',value='i'}},function(v) if v=='e' then N:TextDialog('Copy to the other account',N:Export()) else N:TextDialog('Paste from the other account','',true) end end) end)
 u.syncInfo=label(ch,'',14,-36,'GameFontHighlight'); u.syncInfo:SetWidth(W-28)
 -- Settings page: plain checkboxes
 local st=u.pages.Settings; st:SetHeight(H-110)
 local s=function() return N.db.settings end
 local entries={
  {'tooltipCounts','Show my item counts in tooltips'},{'includeBanks','Count items in banks'},{'includeAlts','Count items on my other characters'},
  {'includeSynced','Count the other account (sync)'},{'market','Use VoidMark Market prices'},{'manualFirst','Use my own prices first'},
  {'routeVisible','Show the route arrow'},{'manualStops','Wait for me at each stop'},{'nodesVisible','Show spawn spots on the world map'},
  {'minimapRoute','Show the route on the minimap'},{'minimap','Minimap button'},{'native','Keep the normal profession window'},
  {'learnSpots','Learn which spots are often empty'}}
 u.checks={}
 for i,e in ipairs(entries) do
  local key=e[1]
  u.checks[#u.checks+1]=check(st,e[2],14,-4-(i-1)*25,function() return s()[key]~=false end,function(v)
   s()[key]=v
   if key=='minimap' and N.minimap then N.minimap:SetShown(v) end
   if key=='routeVisible' and N.activeRoute and v then N:ShowArrow() end
  end)
 end
 local y=-4-#entries*25-8
 local function adjuster(text,key,step,lo,hi,fmt,apply)
  local l=label(st,'',20,y-5,'GameFontHighlight')
  button(st,'-',300,y,36,function() s()[key]=math.max(lo,(s()[key] or lo)-step); if apply then apply() end end)
  button(st,'+',340,y,36,function() s()[key]=math.min(hi,(s()[key] or lo)+step); if apply then apply() end end)
  u.adjusters=u.adjusters or {}; u.adjusters[#u.adjusters+1]=function() l:SetText(text..': '..string.format(fmt,s()[key] or lo)) end
  y=y-30
 end
 adjuster('Route lap length (minutes)','routeMinutes',5,5,60,'%d')
 adjuster('Window size','scale',.1,.6,1.5,'%.1f',function() f:SetScale(s().scale) end)
 -- Shared list
 u.list=CreateFrame('Frame',nil,f); u.list:SetPoint('TOPLEFT',10,-TOP); u.list:SetSize(W-20,H-TOP-40)
 u.perPage=math.floor((H-TOP-40)/ROW_H)
 for i=1,u.perPage do
  local row=CreateFrame('Button',nil,u.list); row:SetSize(W-20,ROW_H-2); row:SetPoint('TOPLEFT',0,-(i-1)*ROW_H)
  row.bg=row:CreateTexture(nil,'BACKGROUND'); row.bg:SetAllPoints(); row.bg:SetColorTexture(.1,.07,.15,i%2==0 and .85 or .45)
  row.icon=row:CreateTexture(nil,'ARTWORK'); row.icon:SetSize(18,18); row.icon:SetPoint('LEFT',4,0)
  row.text=row:CreateFontString(nil,'OVERLAY','GameFontHighlight'); row.text:SetPoint('LEFT',28,0); row.text:SetWidth(W-60); row.text:SetJustifyH('LEFT')
  if row.text.SetWordWrap then row.text:SetWordWrap(false) end
  row:SetScript('OnClick',function(self) local d=self.data; if d and d.click then N:Guard('row',d.click); N.dirty=true end end)
  row:SetScript('OnEnter',function(self) N:RowTooltip(self) end)
  row:SetScript('OnLeave',function() GameTooltip:Hide() end)
  u.rows[i]=row
 end
 u.list:EnableMouseWheel(true)
 u.list:SetScript('OnMouseWheel',function(_,delta) u.offset=math.max(0,u.offset-delta*3); N.dirty=true end)
 u.footer=label(f,'',14,-(H-30),'GameFontDisable'); u.footer:SetWidth(W-28)
 local elapsed=0
 f:SetScript('OnUpdate',function(_,dt) elapsed=elapsed+dt; if elapsed>.3 then elapsed=0; if N.dirty then N:Guard('UI',function() N:Render() end) end end end)
 table.insert(UISpecialFrames,'VoidMarkNexusWindow')
end

function N:RowTooltip(row)
 local d=row.data; if not d then return end
 if not d.item and not d.tip then return end
 GameTooltip:SetOwner(row,'ANCHOR_RIGHT')
 if d.item then
  local id=tonumber(d.item); local ok=false
  if id and id>0 then
   local _,link=self:Call(GetItemInfo,id)
   if type(link)=='string' then ok=pcall(GameTooltip.SetHyperlink,GameTooltip,link) end
   if not ok then ok=pcall(GameTooltip.SetHyperlink,GameTooltip,'item:'..id) end
  end
  if not ok then GameTooltip:SetText(d.itemName or self:ItemName(id)) end
 end
 if d.tip then
  if not d.item then GameTooltip:SetText(d.title or '') end
  d.tip(GameTooltip)
 end
 GameTooltip:Show()
end

-- Resource picker: kinds, skill-ups, then the names found in this zone.
function N:ChooseResource(anchor)
 local options={{label='Herbs',value='kind:herb'},{label='Ore',value='kind:ore'},{label='Herbs and ore',value='kind:all'},
  {label='Herbalism skill-ups',value='skill:herb'},{label='Mining skill-ups',value='skill:ore'},
  {label='Herbs for gold',value='gold:herb'},{label='Ore for gold',value='gold:ore'}}
 local map=self:Position()
 if map then
  local names,seen={},{}
  for _,n in ipairs(self:ZoneNodes(map,'all','')) do if not seen[n.name] then seen[n.name]=true; names[#names+1]=n.name end end
  table.sort(names)
  for _,name in ipairs(names) do options[#options+1]={label='Only '..name,value='name:'..name} end
 end
 self:Choice(anchor,options,function(v) self:SelectResource(v) end)
end
function N:SelectResource(v)
 local s=self.db.settings
 local how,arg=tostring(v):match('^(%a+):(.*)$')
 s.routeResources=nil
 if how=='kind' then s.kind,s.target,s.routeSelectionMode=arg,'',arg
 elseif how=='skill' then s.kind,s.target,s.routeSelectionMode=arg,'','skillup'; self:ScanProfessions()
 elseif how=='gold' then s.kind,s.target,s.routeSelectionMode=arg,'','gold'; self:ScanProfessions()
 elseif how=='name' then s.kind,s.target,s.routeSelectionMode='all',arg,'name' end
 if self.ui then self.ui.bestZones=nil end
 self.dirty=true
end
function N:ResourceLabel()
 local s=self.db.settings
 if s.routeSelectionMode=='skillup' then return s.kind=='ore' and 'Mining skill-ups' or 'Herbalism skill-ups' end
 if s.routeSelectionMode=='gold' then return s.kind=='ore' and 'Ore for gold' or 'Herbs for gold' end
 if s.target and s.target~='' then return 'Only '..s.target end
 return ({herb='Herbs',ore='Ore',all='Herbs and ore'})[s.kind] or 'Herbs'
end
function N:StopRoute()
 self.activeRoute=nil; self.waypoint=nil; self.lingerAt=nil
 if self.arrow then self.arrow:Hide() end
 if self.SyncTomTom then self:SyncTomTom() end
 self.dirty=true
end

local function colorRow(row,c) row.color=c; return row end

function N:RenderGather(u)
 local s=self.db.settings
 u.what:SetText(self:ResourceLabel()); u.travel:SetText(s.travel or 'Foot')
 u.start:SetText(self.activeRoute and 'Stop route' or 'Start route'); u.next:SetShown(self.activeRoute~=nil)
 local rows,info={},{}
 local route=self.activeRoute
 if route then
  info[#info+1]=self:RouteSummary(route) or ''
  local p=route.points[self.waypoint or 1]
  info[#info+1]='Next: '..(p and p.name or '?')..'   lap '..(self.lap or 1)..(self.lapStats and ('  ('..self.lapStats.picked..' picked, '..self.lapStats.empty..' empty)') or '')
  if self.lastLap then info[#info+1]=self:LapLine(self.lastLap,'Last lap: ') end
  for i,pt in ipairs(route.points) do
   local here=i==(self.waypoint or 1)
   local seen=(pt.picked or 0)>0 and ('  found '..pt.picked..'x') or ''
   rows[#rows+1]=colorRow({text=(here and '> ' or '')..i..'. '..(pt.name or 'Stop')..((pt.spawns or 1)>1 and ('  ('..pt.spawns..' spots)') or '')..seen,
    icon=self:ResourceNodeIcon(pt),click=function() self.waypoint=i end,
    title=pt.name,tip=function(tt) tt:AddLine(string.format('%.1f, %.1f',pt.x*100,pt.y*100),1,1,1); tt:AddLine('Click to go here next.',.7,.7,.7) end},
    here and COLORS.accent or (pt.skillColor and COLORS[pt.skillColor=='gray' and 'gray' or pt.skillColor]) or nil)
  end
 else
  if s.routeSelectionMode=='skillup' then
   local skills=self:GatheringSkills(); local k=skills[s.kind=='ore' and 'ore' or 'herb']
   info[#info+1]=k and (k.name..' '..k.skill..'/'..k.max) or 'Open your profession once so Nexus knows your skill.'
  end
  info[#info+1]='Press Start route: Nexus draws one loop through this zone and the arrow guides you.'
  if u.bestZones then
   rows[#rows+1]=colorRow({text='Best zones for '..self:ResourceLabel():lower()},COLORS.muted)
   for _,z in ipairs(u.bestZones) do rows[#rows+1]={text=z.name..'  ('..z.spawns..' spawn spots)'} end
   if #u.bestZones==0 then rows[#rows+1]={text='No zone has enough matching spots.'} end
  end
 end
 u.gatherInfo:SetText(table.concat(info,'\n'))
 u.footer:SetText('Right-click the arrow for options. Gathering a node moves you to the next stop.')
 return rows
end

function N:ProfessionChoices()
 local list={}
 for cid,c in pairs(self.db.characters) do
  for pid,p in pairs(c.professions or {}) do
   local gatheringOnly=p.name=='Herbalism' or p.name=='Mining' or p.name=='Skinning' or p.name=='Fishing'
   if not gatheringOnly then
    list[#list+1]={label=c.name..': '..p.name..' '..(p.skill or 0)..'/'..(p.max or 0),cid=cid,pid=pid,own=cid==self.characterID}
   end
  end
 end
 table.sort(list,function(a,b) if a.own~=b.own then return a.own end return a.label<b.label end)
 return list
end
function N:ChooseProfession(anchor)
 local list=self:ProfessionChoices(); local options={}
 for _,e in ipairs(list) do options[#options+1]={label=e.label,value=e} end
 if #options==0 then return self:Print('Open a profession once so Nexus can record it.') end
 self:Choice(anchor,options,function(e) self.ui.character,self.ui.profession=e.cid,e.pid; self.ui.offset=0 end)
end

function N:RenderProfessions(u)
 local s=self.db.settings
 if not (u.character and u.profession and self.db.characters[u.character] and self.db.characters[u.character].professions[u.profession]) then
  local first=self:ProfessionChoices()[1]
  if first then u.character,u.profession=first.cid,first.pid else u.character,u.profession=nil,nil end
 end
 local c=u.character and self.db.characters[u.character]; local p=c and c.professions[u.profession]
 u.prof:SetText(p and (c.name..': '..p.name..' '..(p.skill or 0)..'/'..(p.max or 0)) or 'Pick a profession')
 local level=u.profView~='recipes'
 u.mode:SetShown(level); u.target:SetShown(level); u.targetLabel:SetShown(level); u.search:SetShown(not level)
 u.mode:SetText(s.levelMode or 'Cheapest')
 if level then u.viewLevel:Disable(); u.viewRecipes:Enable() else u.viewLevel:Enable(); u.viewRecipes:Disable() end
 u.footer:SetText(level and 'Hover a step for details. Prices come from VoidMark Market or your own prices.' or 'Profit for one craft after the auction cut. Hover for materials.')
 local rows={}
 if not p then u.profInfo:SetText('Open a profession in game once so Nexus records its recipes.'); return rows end
 if level then
  local plan=self:CachedLevelingPlan(u.character,u.profession,tonumber(u.target:GetText()),s.levelMode)
  if plan.error then u.profInfo:SetText(plan.error); return rows end
  u.profInfo:SetText(string.format('%d to %d: about %d crafts. Buy for %s.',plan.from,plan.reached,plan.crafts,plan.cash and self:Money(plan.cash) or 'unknown (missing prices)'))
  for _,seg in ipairs(plan.segments) do
   local cand=seg.cand
   rows[#rows+1]=colorRow({text=string.format('%d-%d  %s  x%d',seg.from,seg.to,seg.name,seg.crafts),icon=cand.r.icon,
    title=seg.name,tip=function(tt)
     tt:AddLine(string.format('Skill %d to %d, about %.0f crafts',seg.from,seg.to,seg.expected),1,1,1)
     for _,rg in ipairs(cand.r.reagents) do tt:AddLine(rg.qty..' x '..self:ItemName(rg.id),.8,.8,.8) end
     tt:AddLine('Materials: '..(seg.unknown and 'price unknown' or self:Money(seg.cost)),1,.82,0)
     if cand.r.source then tt:AddLine(cand.r.source,.7,.7,.7,true) end
    end},COLORS[seg.startColor])
  end
  local missing=0
  for _,m in ipairs(plan.materials) do if m.missing>0 then missing=missing+1 end end
  rows[#rows+1]=colorRow({text=missing>0 and 'To buy' or 'You already have every material'},COLORS.muted)
  for _,m in ipairs(plan.materials) do
   if m.missing>0 then
    rows[#rows+1]={text=self:ItemName(m.id)..': buy '..m.missing..(m.owned>0 and ('  (have '..m.owned..')') or '')..(m.unit and ('  '..self:Money(m.cash)) or ''),
     item=m.id,tip=function(tt) for _,a in ipairs(m.allocations) do tt:AddLine(a.qty..': '..a.transfer,.8,.8,.8) end end}
   end
  end
  for i,t in ipairs(plan.trainable or {}) do
   if i>5 then break end
   rows[#rows+1]=colorRow({text='Train '..t.name..' (skill '..t.skill..')',title=t.name,tip=function(tt) tt:AddLine(t.npc..', '..t.where,1,1,1); if t.cost then tt:AddLine(self:Money(t.cost),1,.82,0) end end},COLORS.accent)
  end
 else
  local query=u.search:GetText()
  local list={}
  for _,r in ipairs(self:Search(query,u.character,u.profession,'All')) do
   local e=self:Evaluate(r.r,1,r.character); list[#list+1]={r=r,e=e}
  end
  table.sort(list,function(a,b)
   local x,y=a.e.economic,b.e.economic
   if (x==nil)~=(y==nil) then return x~=nil end
   if x and y and x~=y then return x>y end
   return a.r.r.name<b.r.r.name
  end)
  u.profInfo:SetText(#list..' recipes, most profitable first.')
  for _,entry in ipairs(list) do
   local r,e=entry.r.r,entry.e
   local profit=e.economic
   rows[#rows+1]=colorRow({text=r.name..(r.learned and '' or '  (not learned)')..'   '..(profit and ((profit>=0 and '+' or '')..self:Money(profit)) or 'price unknown'),
    icon=r.icon,item=r.output,tip=function(tt)
     tt:AddLine(' ')
     for _,g in ipairs(e.rows) do tt:AddLine(g.need..' x '..self:ItemName(g.id)..(g.missing>0 and ('  (missing '..g.missing..')') or '  (have)'),g.missing>0 and 1 or .6,g.missing>0 and .5 or .9,.4) end
     tt:AddLine('Materials: '..self:Money(e.cost),1,.82,0)
     if e.sale then tt:AddLine('Sells for: '..self:Money(e.sale.unit)..' each',1,.82,0) end
     if profit then tt:AddLine('Profit: '..self:Money(profit),profit>=0 and .3 or 1,profit>=0 and .9 or .35,.3) end
    end},r.learned and (profit and (profit>=0 and COLORS.good or COLORS.bad) or COLORS.white) or COLORS.gray)
  end
 end
 return rows
end

function N:RenderCharacters(u)
 local query=u.find and u.find:GetText() or ''
 if query~='' then return self:RenderFinder(u,query) end
 local lines={}
 local peers={}; for peer in pairs(self.db.sync and self.db.sync.peers or {}) do peers[#peers+1]=peer end
 if #peers==0 then lines[#lines+1]='Not paired. Type the other character\'s full name (e.g. Voidmark Bank) and press Pair. Do it on both accounts.'
 else
  local names={}; for _,p in ipairs(peers) do names[#names+1]=(self.db.sync.peers[p] or p)..(self:SyncConnected(p) and ' (connected, auto-syncing)' or ' (waiting for them to log in)') end
  lines[#lines+1]='Paired with: '..table.concat(names,', ')..'.'
  local st=self.syncStats
  if st then local waiting=0; for _,q in pairs(self.syncOut or {}) do waiting=waiting+#q end
   lines[#lines+1]=string.format('Sent %d messages, %d waiting%s.',st.sent,waiting,st.failed>0 and (', '..st.failed..' failed') or '') end
 end
 if self.syncIgnored then lines[#lines+1]='Ignored data from '..tostring(self.syncIgnored)..' (not paired here).' end
 local gold=self:GoldLine(); if gold then table.insert(lines,1,gold) end
 u.syncInfo:SetText(table.concat(lines,'\n'))
 u.footer:SetText('Click: count on/off. Shift-click twice: remove an old character.')
 local ids={}; for id in pairs(self.db.characters) do ids[#ids+1]=id end
 table.sort(ids,function(a,b) if a==self.characterID then return true elseif b==self.characterID then return false end return self.db.characters[a].name<self.db.characters[b].name end)
 local rows={}
 local preferred=self:PreferredRecords()
 for _,id in ipairs(ids) do
  local c=self.db.characters[id]; local off=self.db.excluded[id] or not preferred[id]
  local tag=id==self.characterID and ' (you)' or c.synced and ' (synced)' or c.imported and ' (imported)' or ''
  rows[#rows+1]=colorRow({text=c.name..tag..'   '..(c.money and self:Gold(c.money) or 'gold ?')..'   bank '..self:Ago(c.bankAt)..(not preferred[id] and '   older copy, ignored' or off and '   not counted' or ''),
   click=function() if IsShiftKeyDown and IsShiftKeyDown() then self:ForgetCharacter(id) else self.db.excluded[id]=not self.db.excluded[id] or nil end end,title=c.name,
   tip=function(tt) tt:AddLine(c.realm..' / '..c.faction,1,1,1)
    tt:AddLine('Gold '..(c.money and self:Gold(c.money)..' (seen '..self:Ago(c.moneyAt)..')' or 'not seen yet: log in once'),1,.82,0)
    tt:AddLine('Bags '..self:Ago(c.bagsAt)..', bank '..self:Ago(c.bankAt),.8,.8,.8)
    for _,p in pairs(c.professions or {}) do tt:AddLine(p.name..' '..(p.skill or 0)..'/'..(p.max or 0),.8,.8,.8) end
    if c.synced then tt:AddLine('Last synced '..self:Ago(c.syncedAt),.7,.7,.7) end end},off and COLORS.gray or nil)
 end
 return rows
end

-- Remove a saved character record (never the one you are playing). Asks twice.
function N:ForgetCharacter(id)
 local c=self.db.characters[id]; if not c then return end
 if id==self.characterID then return self:Print('You cannot remove the character you are playing.') end
 local now=GetTime and GetTime() or self:Now()
 if self.forgetPending~=id or now-(self.forgetAt or 0)>8 then
  self.forgetPending,self.forgetAt=id,now
  return self:Print('Shift-click '..tostring(c.name)..' again to remove its saved record.')
 end
 self.forgetPending=nil
 self.db.characters[id]=nil; self.db.excluded[id]=nil
 -- A synced record comes back on the next sync; clear its hashes so it resends in full.
 local known=self.db.sync and self.db.sync.known
 if c.synced and type(known)=='table' then for peer in pairs(known) do if (c.name or ''):lower()==peer then known[peer]=nil end end end
 self.renderStocks=nil; self.dirty=true
 self:Print('Removed '..tostring(c.name)..'.')
end

function N:Render()
 local u=self.ui; if not u or not u.frame:IsShown() then return end; self.dirty=false
 self.renderStocks={}
 for name,p in pairs(u.pages) do p:SetShown(name==u.tab) end
 for name,b in pairs(u.tabs) do if name==u.tab then b:Disable() else b:Enable() end end
 local rows={}
 if u.tab=='Gather' then rows=self:RenderGather(u)
 elseif u.tab=='Professions' then rows=self:RenderProfessions(u)
 elseif u.tab=='Characters' then rows=self:RenderCharacters(u)
 else
  for _,cb in ipairs(u.checks) do cb:SetChecked(cb.get()) end
  for _,fn in ipairs(u.adjusters or {}) do fn() end
  u.footer:SetText('VoidMark Nexus '..self.version)
 end
 u.list:SetShown(u.tab~='Settings')
 u.offset=math.max(0,math.min(u.offset or 0,#rows-u.perPage))
 for i,b in ipairs(u.rows) do
  local r=rows[u.offset+i]; b.data=r; b:SetShown(r~=nil)
  if r then
   b.text:SetText(r.text)
   local c=r.color or COLORS.white; b.text:SetTextColor(c[1],c[2],c[3])
   local icon=r.icon or (r.item and self:InventoryIcon(r.item))
   b.icon:SetTexture(icon); b.icon:SetShown(icon~=nil)
  end
 end
 u.rowCount=#rows
 self.renderStocks=nil
end

-- Prefer the client's direct item-icon APIs, which work before item cache is populated.
function N:InventoryIcon(id)
 id=tonumber(id); if not id then return nil end
 if C_Item and C_Item.GetItemIconByID then local icon=self:Call(C_Item.GetItemIconByID,id); if icon then return icon end end
 local icon=self:Call(GetItemIcon,id); if icon then return icon end
 local info={self:Call(GetItemInfo,id)}; return info[10]
end
