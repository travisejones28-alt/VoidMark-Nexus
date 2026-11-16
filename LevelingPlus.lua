local _, N = ...
-- 0.11 profession leveling while you play.
--  * The step for your current skill is highlighted, with how many crafts are
--    left in it and how many you can make right now from your own bags.
--  * Materials show who holds them and where (bags, bank, another character).
--  * The four methods are compared side by side (crafts and cost), using
--    Market prices; unknown prices and estimated colour thresholds are flagged.
--  * A shopping list groups what to buy and what to collect from each character.
-- All of it follows the existing plan, so it recalculates whenever your skill,
-- bags, bank or prices change.
local floor=math.floor

-- What this character can craft now from its bags only (not bank, not alts).
function N:CraftableNow(cid,recipe)
 local c=self.db.characters[cid];if not c or type(recipe)~='table' or not recipe.reagents or #recipe.reagents==0 then return 0 end
 local n
 for _,rg in ipairs(recipe.reagents) do
  if not rg.id or not self:Finite(rg.qty,1,1e6) then return 0 end
  local have=tonumber(c.bags and c.bags[rg.id]) or 0
  local k=floor(have/rg.qty);if not n or k<n then n=k end
 end
 return n or 0
end

-- The step that covers the character's current skill.
function N:LevelingNextStep(plan,cid)
 if not plan or plan.error or not plan.segments[1] then return nil end
 local seg=plan.segments[1]
 local c=self.db.characters[cid]
 return {seg=seg,name=seg.name,crafts=seg.crafts,from=seg.from,to=seg.to,now=self:CraftableNow(cid,seg.cand.r),
  estimated=seg.estimated,character=c and c.name}
end

-- Where each held material is: "3 in Voidmark Bank's bank, 2 in bags".
function N:HolderText(row,cid)
 local parts={}
 for _,a in ipairs(row.allocations or {}) do
  local c=self.db.characters[a.id]
  local who=a.id==cid and 'your ' or ((c and c.name or '?')..'\'s ')
  parts[#parts+1]=a.qty..' in '..who..a.location
 end
 return table.concat(parts,', ')
end

-- Same plan in every method, for comparison. Cached for 30 s per inputs.
function N:CompareLevelingModes(cid,pid,target)
 local c=self.db.characters[cid];local p=c and c.professions[pid]
 local key=table.concat({tostring(cid),tostring(pid),tostring(target),tostring(p and p.at),tostring(p and p.skill),
  tostring(c and c.bagsAt),tostring(c and c.bankAt),tostring(self.priceStamp or 0)},'|')
 local cache=self.levelCompare
 if cache and cache.key==key and self:Now()-cache.at<30 then return cache.rows end
 local rows={}
 for _,mode in ipairs(self.levelModes) do
  local plan=self:LevelingPlan(cid,pid,target,mode)
  if not plan.error then
   rows[#rows+1]={mode=mode,crafts=plan.crafts,cash=plan.cash,economic=plan.economic,reached=plan.reached,to=plan.to,
    unknown=plan.unknown,estimated=plan.estimated,steps=#plan.segments}
  end
 end
 self.levelCompare={key=key,at=self:Now(),rows=rows}
 return rows
end
function N:LevelingModeLine(r)
 return string.format('%s: %d crafts to %d, buy %s, materials %s%s%s',r.mode,r.crafts,r.reached,
  r.cash and self:Money(r.cash) or 'unknown',r.economic and self:Money(r.economic) or 'unknown',
  r.reached<r.to and ' (stops early: no recipe)' or '',r.estimated and ' ~' or '')
end

-- What to buy, and what to collect from which character.
function N:TransferGroups(plan,cid)
 local groups,order={},{}
 for _,m in ipairs(plan.materials or {}) do
  for _,a in ipairs(m.allocations or {}) do
   if a.id~=cid or a.location=='bank' then
    local k=a.id..'/'..a.location
    if not groups[k] then
     local c=self.db.characters[a.id]
     groups[k]={id=a.id,name=c and c.name or '?',location=a.location,own=a.id==cid,synced=c and c.synced,items={},at=a.at}
     order[#order+1]=k
    end
    table.insert(groups[k].items,{id=m.id,qty=a.qty})
   end
  end
 end
 local out={};for _,k in ipairs(order) do out[#out+1]=groups[k] end
 table.sort(out,function(a,b) if a.own~=b.own then return a.own end return a.name<b.name end)
 return out
end
function N:LevelingShoppingText(cid,pid,target,mode)
 local plan=self:CachedLevelingPlan(cid,pid,target,mode or self.db.settings.levelMode)
 if plan.error then return plan.error end
 local c=self.db.characters[cid]
 local lines={string.format('%s %s plan for %s: %d -> %d, about %d crafts.',plan.mode,(c and c.professions[pid] and c.professions[pid].name) or '',c and c.name or '?',plan.from,plan.reached,plan.crafts),''}
 lines[#lines+1]='BUY'
 local any=false
 for _,m in ipairs(plan.materials) do
  if m.missing>0 then
   any=true
   lines[#lines+1]=string.format('%d x %s  %s',m.missing,self:ItemName(m.id),m.unit and ('= '..self:Money(m.cash)..'  ('..self:PriceLabel(m.price)..')') or '(no price)')
  end
 end
 if not any then lines[#lines+1]='Nothing: you hold every material.' end
 lines[#lines+1]='Total to buy: '..(plan.cash and self:Money(plan.cash) or 'unknown (some prices missing)')
 local groups=self:TransferGroups(plan,cid)
 if #groups>0 then
  lines[#lines+1]=''
  lines[#lines+1]='COLLECT'
  for _,g in ipairs(groups) do
   local how
   if g.own then how='Withdraw from your bank'
   elseif g.synced then how=string.format('Log into %s (other account) and mail to %s from %s',g.name,c and c.name or 'the crafter',g.location)
   else how=string.format('On %s: take from %s and mail to %s',g.name,g.location,c and c.name or 'the crafter') end
   local items={};for _,i in ipairs(g.items) do items[#items+1]=i.qty..' x '..self:ItemName(i.id) end
   lines[#lines+1]=how..(g.at and (' (seen '..self:Age(g.at)..')') or '')..':'
   lines[#lines+1]='  '..table.concat(items,', ')
  end
  lines[#lines+1]='Bound items cannot be mailed; check before you log over.'
 end
 return table.concat(lines,'\n')
end

-- Text summary: the old summary plus the steps themselves.
do
 local summary=N.LevelingSummary
 N.LevelingSummary=function(self,plan)
  local text=summary(self,plan)
  if plan.error or #plan.segments==0 then return text end
  local steps={'','STEPS'}
  for i,seg in ipairs(plan.segments) do
   steps[#steps+1]=string.format('%d. %d-%d  %s x%d%s%s',i,seg.from,seg.to,seg.name,seg.crafts,seg.estimated and ' (colour thresholds estimated)' or '',
    seg.unknown and ' (price unknown)' or '')
  end
  local first=text:find('\nMATERIALS',1,true)
  if first then return text:sub(1,first-1)..table.concat(steps,'\n')..text:sub(first) end
  return text..table.concat(steps,'\n')
 end
end

do -- Professions page: current step, holders, method comparison.
 local render=N.RenderProfessions
 N.RenderProfessions=function(self,u,...)
  local rows=render(self,u,...)
  if u.profView=='recipes' or not u.character or not u.profession then return rows end
  local s=self.db.settings
  local target=tonumber(u.target:GetText())
  local plan=self:CachedLevelingPlan(u.character,u.profession,target,s.levelMode)
  if plan.error then return rows end
  local step=self:LevelingNextStep(plan,u.character)
  -- Highlight the current step and mark estimated ones.
  for _,r in ipairs(rows) do
   if step and r.title==step.name and not step.marked then r.current=true;step.marked=true end
  end
  local top={}
  if step then
   local own=u.character==self.characterID
   top[#top+1]={text=string.format('Now: %s x%d for %d-%d%s',step.name,step.crafts,step.from,step.to,
    own and string.format('  (you can make %d from your bags)',step.now) or ''),color={1,.82,0},noIcon=true,current=true}
   if step.estimated then top[#top+1]={text='  Skill-up chances for this step are estimated, not confirmed.',color={.6,.6,.6},noIcon=true} end
  end
  if plan.unknown then top[#top+1]={text='Some material prices are missing: totals are unknown, not zero.',color={1,.5,.25},noIcon=true} end
  for i,r in ipairs(top) do table.insert(rows,i,r) end
  -- Holders on material rows.
  for _,m in ipairs(plan.materials) do
   local holders=self:HolderText(m,u.character)
   if holders~='' then
    for _,r in ipairs(rows) do if r.item==m.id and r.text:find(': buy ',1,true) then r.text=r.text..'  ['..holders..']' end end
   end
  end
  -- Method comparison; click one to switch.
  local cmp=self:CompareLevelingModes(u.character,u.profession,target)
  if #cmp>1 then
   rows[#rows+1]={text='Compare methods (click to use)',color={.6,.6,.6},noIcon=true}
   for _,r in ipairs(cmp) do
    rows[#rows+1]={text=(r.mode==s.levelMode and '> ' or '  ')..self:LevelingModeLine(r),noIcon=true,click=function() s.levelMode=r.mode end,
     color=r.mode==s.levelMode and {.75,.65,1} or nil}
   end
  end
  rows[#rows+1]={text='Shopping list and what to collect from each character (click)',noIcon=true,color={.4,.9,1},
   click=function() self:TextDialog('Leveling shopping list',self:LevelingShoppingText(u.character,u.profession,target,s.levelMode)) end}
  return rows
 end
end

-- /vmn level [profession] [target]: the plan for this character in chat.
function N:LevelCommand(args)
 local name,target=tostring(args or ''):match('^(.-)%s*(%d*)$')
 local cid=self.characterID;local c=self.character
 local pid
 for id,p in pairs(c and c.professions or {}) do
  if type(p)=='table' and (name=='' and not pid and p.recipes and next(p.recipes) or (name~='' and tostring(p.name):lower():find(name:lower(),1,true))) then pid=id end
 end
 if not pid then return self:Print('/vmn level PROFESSION [target]. Open the profession once first.') end
 local plan=self:CachedLevelingPlan(cid,pid,tonumber(target),self.db.settings.levelMode)
 if plan.error then return self:Print(plan.error) end
 local step=self:LevelingNextStep(plan,cid)
 self:Print(string.format('%s %d -> %d: %d crafts, buy %s.',c.professions[pid].name,plan.from,plan.reached,plan.crafts,plan.cash and self:Money(plan.cash) or 'unknown'))
 if step then self:Print(string.format('Now: %s x%d (%d-%d); you can make %d from your bags.',step.name,step.crafts,step.from,step.to,step.now)) end
 for _,r in ipairs(self:CompareLevelingModes(cid,pid,tonumber(target))) do self:Print('  '..self:LevelingModeLine(r)) end
end
N:AddCommand('level',function(self,args) self:LevelCommand(args) end,'/vmn level PROFESSION [target] (next step, methods compared)')
N:AddCommand('levelshop',function(self,args)
 local u=self.ui
 if u and u.character and u.profession then
  return self:TextDialog('Leveling shopping list',self:LevelingShoppingText(u.character,u.profession,tonumber(u.target and u.target:GetText()),self.db.settings.levelMode))
 end
 self:Print('Pick a profession on the Professions page first.')
end,'/vmn levelshop (shopping list + what to collect from each character)')
