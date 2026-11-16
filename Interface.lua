local _, N = ...
-- 0.11 interface: pick herbs and ore one by one, hide grey resources.

-- Grey = 100+ skill above the node (no skill-ups; same bands as skill-up routes).
function N:IsGrayNode(n,skills)
 local p=skills and skills[n.kind]
 return p and self:Finite(n.skill,1,1000) and p.skill-n.skill>=100 or false
end
do
 local zoneNodes=N.ZoneNodes
 N.ZoneNodes=function(self,map,...)
  local out=zoneNodes(self,map,...)
  if self.db.settings.hideGray~=true or self.db.settings.routeSelectionMode=='skillup' then return out end
  local skills=self:GatheringSkills()
  if not next(skills) then return out end
  local kept={}
  for _,n in ipairs(out) do if not self:IsGrayNode(n,skills) then kept[#kept+1]=n end end
  return kept
 end
end

-- Resource menu: presets, then "Pick several..." which toggles single resources.
function N:ChooseResources(anchor)
 local s=self.db.settings
 local picked=type(s.routeResources)=='table' and s.routeResources or {}
 local map=self.RouteZone and (self:RouteZone()) or self:Position()
 local names,seen={},{}
 local skills=self:GatheringSkills()
 for _,n in ipairs(map and self:ZoneNodes(map,'all','') or {}) do
  if not seen[n.name] then seen[n.name]={kind=n.kind,gray=self:IsGrayNode(n,skills)};names[#names+1]=n.name end
 end
 table.sort(names,function(a,b) if seen[a].kind~=seen[b].kind then return seen[a].kind<seen[b].kind end return a<b end)
 local options={{label='Done',value='done'}}
 for _,name in ipairs(names) do
  options[#options+1]={label=(picked[name] and '[x] ' or '[ ] ')..name..(seen[name].gray and ' (grey)' or ''),value=name}
 end
 if #names==0 then options[#options+1]={label='Nothing gatherable in this zone',value='done'} end
 self:Choice(anchor,options,function(v)
  if v=='done' then return end
  local list=type(s.routeResources)=='table' and s.routeResources or {}
  list[v]=not list[v] or nil
  s.routeResources=next(list) and list or nil
  s.kind,s.target,s.routeSelectionMode='all','',s.routeResources and 'multi' or 'all'
  if self.ui then self.ui.bestZones=nil end
  self.dirty=true
  if C_Timer and C_Timer.After then C_Timer.After(0,function() self:ChooseResources(anchor) end) end
 end)
end
do
 local select=N.SelectResource
 N.SelectResource=function(self,v)
  if v=='multi:' then return self:ChooseResources(self.ui and self.ui.what) end
  if v=='gray:toggle' then
   self.db.settings.hideGray=not self.db.settings.hideGray
   self:Print(self.db.settings.hideGray and 'Grey resources (no skill-ups) are hidden from routes and the map.' or 'Grey resources are shown again.')
   self.dirty=true;return
  end
  return select(self,v)
 end
 local label=N.ResourceLabel
 N.ResourceLabel=function(self)
  local s=self.db.settings
  if s.routeSelectionMode=='multi' and type(s.routeResources)=='table' then
   local n=0;local one;for k in pairs(s.routeResources) do n=n+1;one=k end
   if n==1 then return 'Only '..one end
   return n..' picked'
  end
  return label(self)
 end
end
-- The menu Choice builds: add "Pick several" and the grey toggle on top.
do
 local choice=N.Choice
 N.Choice=function(self,anchor,choices,fn)
  if self.ui and anchor==self.ui.what and choices[1] and choices[1].value=='kind:herb' then
   table.insert(choices,4,{label='Pick several herbs / ore...',value='multi:'})
   table.insert(choices,5,{label=(self.db.settings.hideGray and 'Show' or 'Hide')..' grey (no skill-ups)',value='gray:toggle'})
  end
  return choice(self,anchor,choices,fn)
 end
end

N:AddCommand('resetwindow',function(self) self:ResetWindow();self:Print('Window size and position reset.') end,'/vmn resetwindow (size, position, scale)')
N:AddCommand('grey',function(self) self:SelectResource('gray:toggle') end,'/vmn grey (hide/show resources that give no skill-ups)')
N:AddCommand('gray',function(self) self:SelectResource('gray:toggle') end)

-- What to move between characters for everything in the crafting queue.
-- Grouped by the character holding it, with how to get it to the crafter.
function N:TransferPlanText()
 local rows=self.Shopping and self:Shopping() or {}
 local groups,order={},{}
 for _,row in ipairs(rows) do
  for _,a in ipairs(row.allocations or {}) do
   if a.id~=row.character then
    local k=a.id..'>'..row.character
    if not groups[k] then groups[k]={from=a.id,to=row.character,items={},at=a.at,location=a.location};order[#order+1]=k end
    local g=groups[k];g.items[row.id]=(g.items[row.id] or 0)+a.qty
   end
  end
 end
 if #order==0 then return 'Nothing to move: queued crafts use materials already on the crafting character (or nothing is queued).' end
 local lines={}
 for _,k in ipairs(order) do
  local g=groups[k];local from,to=self.db.characters[g.from],self.db.characters[g.to]
  local here=g.from==self.characterID
  local list={};for id,q in pairs(g.items) do list[#list+1]=q..' x '..self:ItemName(id) end;table.sort(list)
  lines[#lines+1]=string.format('%s%s -> %s%s',here and '>> ' or '',from and from.name or '?',to and to.name or '?',
   from and from.synced and ' (log into the other account)' or here and ' (you are on this character: mail now)' or '')
  lines[#lines+1]='   from '..g.location..(g.at and (', seen '..self:Ago(g.at)) or '')..': '..table.concat(list,', ')
 end
 lines[#lines+1]=''
 lines[#lines+1]='Counts come from the last bag/bank scan or sync. Soulbound items cannot be mailed.'
 return table.concat(lines,'\n')
end
N:AddCommand('transfers',function(self) self:TextDialog('Transfers for queued crafts',self:TransferPlanText()) end,'/vmn transfers (what to mail between characters for queued crafts)')
