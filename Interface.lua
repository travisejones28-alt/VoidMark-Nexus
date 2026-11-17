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

-- Resource menu (0.13.2): presets, grey toggle, then "One herb..." / "One ore..."
-- which list EVERY herb or ore in the game (not just this zone). Picking one
-- that isn't in the route zone moves the Zone to where it grows most.
function N:AllResourceNames(kind)
 local seen,out={},{}
 for _,t in pairs(self.nodeTypes or {}) do
  if t.kind==kind and t.name and not seen[t.name] then seen[t.name]=t.skill or 0; out[#out+1]=t.name end
 end
 table.sort(out,function(a,b) if seen[a]~=seen[b] then return seen[a]<seen[b] end return a<b end)
 return out,seen
end
function N:ChooseResource(anchor)
 local grey=self.db.settings.hideGray
 local options={{label='Herbs',value='kind:herb'},{label='Ore',value='kind:ore'},{label='Herbs and ore',value='kind:all'},
  {label='One herb...',value='list:herb'},{label='One ore...',value='list:ore'},
  {label='Herbalism skill-ups',value='skill:herb'},{label='Mining skill-ups',value='skill:ore'},
  {label='Herbs for gold',value='gold:herb'},{label='Ore for gold',value='gold:ore'},
  {label=(grey and 'Show' or 'Hide')..' grey (no skill-ups)',value='gray:toggle'}}
 self:Choice(anchor,options,function(v) self:SelectResource(v) end)
end
function N:ChooseOneResource(anchor,kind)
 local names,skill=self:AllResourceNames(kind)
 local map=self.RouteZone and (self:RouteZone()) or self:Position()
 local here={}
 for _,n in ipairs(map and self:ZoneNodes(map,kind,'') or {}) do here[n.name]=true end
 local skills=self:GatheringSkills() or {}
 local p=skills[kind]
 local options={{label='< Back',value='back'}}
 for _,name in ipairs(names) do
  local tag=''
  if p and p.skill and skill[name]>p.skill then tag=' (need '..skill[name]..')'
  elseif p and p.skill and p.skill-skill[name]>=100 then tag=' (grey)' end
  options[#options+1]={label=name..tag..(here[name] and ' - here' or ''),value='name:'..name}
 end
 self:Choice(anchor,options,function(v)
  if v=='back' then return self:ChooseResource(anchor) end
  self:SelectResource(v)
 end)
end
-- After picking one resource: if the route zone has none, jump the Zone to the best one.
function N:ZoneForTarget(name)
 local map=self.RouteZone and (self:RouteZone())
 if map and #self:ZoneNodes(map)>0 then return end
 local best=self.BestZones and self:BestZones(1)[1]
 if best then
  self.db.settings.routeZone=best.map
  self:Print(name..' is not in this zone. Zone set to '..best.name..' ('..best.spawns..' spots). Use the Zone button to pick another.')
 else
  self:Print('No known spawn spots for '..name..'.')
 end
end
do
 local select=N.SelectResource
 N.SelectResource=function(self,v)
  local how,arg=tostring(v):match('^(%a+):(.*)$')
  if how=='list' then return self:ChooseOneResource(self.ui and self.ui.what,arg) end
  if v=='gray:toggle' then
   self.db.settings.hideGray=not self.db.settings.hideGray
   self:Print(self.db.settings.hideGray and 'Grey resources (no skill-ups) are hidden from routes and the map.' or 'Grey resources are shown again.')
   self.dirty=true;return
  end
  local r=select(self,v)
  if how=='name' and arg~='' then self:ZoneForTarget(arg) end
  return r
 end
 -- Old saves may still hold a "pick several" selection; show it sensibly.
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
