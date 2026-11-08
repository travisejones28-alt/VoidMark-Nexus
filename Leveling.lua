local _, N = ...
-- Profession leveling planner.
--
-- The client reports only a recipe's current difficulty colour, never its
-- colour thresholds. Nexus therefore records (skill, colour) observations every
-- time a profession is scanned and derives threshold bounds from them. Where a
-- boundary has not been observed yet, a conservative estimate is used and the
-- plan is labelled as estimated. Plans sharpen automatically as you level,
-- because every skill-up rescans the open profession.

-- 1 orange, 2 yellow, 3 green, 4 gray. Modern numeric enums are 0-3.
local COLOR={optimal=1,medium=2,easy=3,trivial=4,[0]=1,[1]=2,[2]=3,[3]=4}
N.levelColorNames={'orange','yellow','green','gray'}
N.levelModes={'Cheapest','Fastest','Self-found','Balanced'}
local DEFAULT_SPAN=15 -- typical Classic yellow->green and green->gray width; estimate only
local MAX_PROFESSIONS,MAX_RECIPES=40,800

function N:DifficultyColor(d) return COLOR[d] end

-- Called from profession scans. Thresholds are recipe properties, so evidence
-- is shared account-wide per profession name.
function N:RecordDifficulty(profession,key,skill,difficulty)
 local color=COLOR[difficulty]
 if not color or not self:Text(profession) or key==nil or not self:Finite(skill,1,1000) then return end
 local root=self.db.levelEvidence
 if type(root)~='table' then root={};self.db.levelEvidence=root end
 local prof=root[profession]
 if type(prof)~='table' then
  local n=0;for _ in pairs(root) do n=n+1 end;if n>=MAX_PROFESSIONS then return end
  prof={};root[profession]=prof
 end
 key=tostring(key)
 local e=prof[key]
 if type(e)~='table' or type(e.lo)~='table' or type(e.hi)~='table' then
  if e==nil then local n=0;for _ in pairs(prof) do n=n+1 end;if n>=MAX_RECIPES then return end end
  e={lo={},hi={}};prof[key]=e
 end
 local lo,hi=e.lo,e.hi
 if not self:Finite(lo[color],1,1000) or skill<lo[color] then lo[color]=skill end
 if not self:Finite(hi[color],1,1000) or skill>hi[color] then hi[color]=skill end
end

-- Returns first yellow (Y), first green (G) and first gray (X) skill levels.
function N:RecipeThresholds(profession,key,recipe,skill)
 local prof=type(self.db.levelEvidence)=='table' and self.db.levelEvidence[profession]
 local e=type(prof)=='table' and prof[tostring(key)]
 local lo,hi={},{}
 if type(e)=='table' then
  for c=1,4 do
   if type(e.lo)=='table' and self:Finite(e.lo[c],1,1000) then lo[c]=e.lo[c] end
   if type(e.hi)=='table' and self:Finite(e.hi[c],1,1000) then hi[c]=e.hi[c] end
  end
 end
 -- Fold in the scan-time colour if it was never recorded (older data).
 local c0=COLOR[recipe and recipe.difficulty]
 if c0 and self:Finite(skill,1,1000) then
  lo[c0]=lo[c0] and math.min(lo[c0],skill) or skill
  hi[c0]=hi[c0] and math.max(hi[c0],skill) or skill
 end
 local estimated=false
 local function bound(color)
  -- First skill at which the recipe is at least this colour.
  local lower
  for c=1,color-1 do if hi[c] then lower=math.max(lower or 0,hi[c]+1) end end
  local upper
  for c=color,4 do if lo[c] then upper=math.min(upper or 1e9,lo[c]) end end
  if lower and upper then return math.min(lower,upper),true end
  if upper then return upper,true end
  return lower,false
 end
 -- Unobserved boundaries: assume the earliest change (conservative) and a
 -- typical span for later colours. Observed boundaries are never moved later.
 local Y,yk=bound(2)
 if not yk then Y=Y or skill or 1;estimated=true end
 local G,gk=bound(3)
 if not gk then G=math.max(G or 0,Y+DEFAULT_SPAN);estimated=true end
 local X,xk=bound(4)
 if not xk then X=math.max(X or 0,G+DEFAULT_SPAN);estimated=true end
 if G>X then G=X end
 if Y>G then Y=G end
 return Y,G,X,estimated
end

-- Widely used Classic skill-up chance: orange certain, then linear to zero at gray.
function N:SkillUpChance(skill,Y,X)
 if skill<Y then return 1 end
 if skill>=X then return 0 end
 return math.max(0,math.min(1,(X-skill)/math.max(1,X-Y)))
end

local function priceUnit(self,id)
 local p=self:Price(id);return p and p.unit,p
end

local function craftEconomics(self,recipe)
 local cost,unknown=0,false
 for _,r in ipairs(recipe.reagents or {}) do
  local unit=r.id and priceUnit(self,r.id)
  if unit then cost=cost+unit*r.qty else unknown=true end
 end
 local recover=0
 local s=self.db.settings
 if recipe.output and not recipe.bound and s.levelResale~=false then
  local unit,p=priceUnit(self,recipe.output)
  if unit and not p.stale then
   local made=((recipe.outputMin or 1)+(recipe.outputMax or recipe.outputMin or 1))/2
   recover=unit*made*(1-s.cut)*s.saleFraction
  end
 end
 return (not unknown) and cost or nil,recover,unknown
end

function N:LevelingPlan(cid,pid,target,mode)
 mode=mode or 'Cheapest'
 local c=self.db.characters[cid];local p=c and c.professions[pid]
 local plan={segments={},materials={},unusable={},notes={},mode=mode,cash=0,economic=0,recovered=0,crafts=0,unknown=false,estimated=false}
 if not p then plan.error='No profession data. Open the profession on that character first.';return plan end
 local skill=math.floor(tonumber(p.skill) or 0);local max=math.floor(tonumber(p.max) or 0)
 target=math.floor(tonumber(target) or 0)
 if target<=skill then target=max>skill and max or skill end
 plan.from,plan.requested=skill,target
 if max>0 and target>max then
  plan.notes[#plan.notes+1]=string.format('Current rank caps at %d. Train the next rank at a profession trainer, then rescan to plan past %d.',max,max)
  target=max
 end
 plan.to=target
 if target<=skill then plan.error='Already at or above the target skill.';return plan end

 -- Candidate recipes and their fixed per-craft economics.
 local candidates={}
 for key,r in pairs(p.recipes or {}) do
  if type(r)=='table' then
   if not r.learned then
    plan.unusable[#plan.unusable+1]={name=r.name or tostring(key),reason='Not learned',source=r.source}
   elseif r.incomplete or not r.reagents or #r.reagents==0 then
    plan.unusable[#plan.unusable+1]={name=r.name or tostring(key),reason='Reagents unreadable; use native window',source=r.source}
   elseif r.disabled then
    plan.unusable[#plan.unusable+1]={name=r.name or tostring(key),reason='Disabled by client',source=r.source}
   elseif COLOR[r.difficulty] then
    local Y,G,X,est=self:RecipeThresholds(p.name,key,r,p.skill)
    local cost,recover,unknown=craftEconomics(self,r)
    candidates[#candidates+1]={key=tostring(key),r=r,Y=Y,G=G,X=X,est=est,cost=cost,recover=recover,unknown=unknown}
   end
  end
 end
 table.sort(candidates,function(a,b) return (a.r.name or a.key)<(b.r.name or b.key) end)
 table.sort(plan.unusable,function(a,b) return a.name<b.name end)

 -- Remaining stock is consumed as the simulation proceeds (Self-found mode).
 local stock=self:Stock(cid);local remaining={}
 for item,rows in pairs(stock) do local n=0;for _,s in ipairs(rows) do n=n+s.qty end;remaining[item]=n end
 local timeValue=tonumber(self.db.settings.levelCraftValue) or 500

 local current
 for k=skill,target-1 do
  local best,bestScore,bestCrafts
  for _,cand in ipairs(candidates) do
   local chance=self:SkillUpChance(k,cand.Y,cand.X)
   if chance>0 then
    local crafts=1/chance;local score
    local net=cand.cost and (cand.cost-cand.recover)
    if mode=='Fastest' then
     score=crafts*1e9+(net or 0)
    elseif mode=='Self-found' then
     local missing,cash=0,0
     for _,rg in ipairs(cand.r.reagents) do
      local short=math.max(0,rg.qty*crafts-(remaining[rg.id] or 0))
      missing=missing+short
      local unit=priceUnit(self,rg.id);cash=cash+short*(unit or 1e6)
     end
     score=missing*1e9+cash
    elseif net then
     score=crafts*net+(mode=='Balanced' and crafts*timeValue or 0)
    end
    if score and (not bestScore or score<bestScore) then best,bestScore,bestCrafts=cand,score,crafts end
   end
  end
  if not best then
   plan.stoppedAt=k
   plan.notes[#plan.notes+1]=string.format('No usable %srecipe gives skill at %d. Learn newer recipes from a trainer or vendor, or add prices.',(mode=='Cheapest' or mode=='Balanced') and 'priced ' or '',k)
   break
  end
  for _,rg in ipairs(best.r.reagents) do remaining[rg.id]=math.max(0,(remaining[rg.id] or 0)-rg.qty*bestCrafts) end
  if current and current.key==best.key then
   current.to=k+1;current.expected=current.expected+bestCrafts
  else
   current={key=best.key,name=best.r.name or best.key,from=k,to=k+1,expected=bestCrafts,cand=best,
    startColor=N.levelColorNames[k<best.Y and 1 or k<best.G and 2 or k<best.X and 3 or 4]}
   plan.segments[#plan.segments+1]=current
  end
  plan.estimated=plan.estimated or best.est
 end

 -- Totals from whole crafts, allocated against real inventory once.
 local need={}
 for _,seg in ipairs(plan.segments) do
  local cand=seg.cand
  seg.crafts=math.max(1,math.ceil(seg.expected-1e-9))
  seg.endColor=N.levelColorNames[seg.to-1<cand.Y and 1 or seg.to-1<cand.G and 2 or seg.to-1<cand.X and 3 or 4]
  seg.estimated=cand.est
  seg.cost=cand.cost and cand.cost*seg.crafts
  seg.recover=cand.recover*seg.crafts
  seg.unknown=cand.unknown
  plan.crafts=plan.crafts+seg.crafts
  plan.recovered=plan.recovered+seg.recover
  if cand.unknown then plan.unknown=true end
  for _,rg in ipairs(cand.r.reagents) do if rg.id then need[rg.id]=(need[rg.id] or 0)+rg.qty*seg.crafts end end
 end
 plan.materials=self:Allocate(need,stock)
 for _,row in ipairs(plan.materials) do
  local unit=priceUnit(self,row.id);row.unit=unit;row.price=self:Price(row.id)
  row.owned=row.need-row.missing
  if unit then
   row.cash=row.missing*unit;plan.cash=plan.cash+row.cash;plan.economic=plan.economic+row.need*unit
  else plan.unknown=true end
 end
 plan.reached=plan.stoppedAt or plan.to
 if plan.unknown then plan.cash,plan.economic=nil,nil end
 return plan
end

-- Small in-memory cache so the UI does not re-simulate on every redraw.
function N:CachedLevelingPlan(cid,pid,target,mode,force)
 local c=self.db.characters[cid];local p=c and c.professions[pid]
 local key=table.concat({tostring(cid),tostring(pid),tostring(target),tostring(mode),tostring(p and p.at),tostring(p and p.skill),
  tostring(c and c.bagsAt),tostring(c and c.bankAt),tostring(self.priceStamp or 0)},'|')
 local now=self:Now()
 local cache=self.levelCache
 if not force and cache and cache.key==key and now-cache.at<30 then return cache.plan end
 local plan=self:LevelingPlan(cid,pid,target,mode)
 self.levelCache={key=key,plan=plan,at=now}
 return plan
end

function N:LevelingSummary(plan)
 local lines={}
 if plan.error then return plan.error end
 lines[#lines+1]=string.format('%s plan: %d -> %d%s',plan.mode,plan.from,plan.reached,plan.reached<plan.requested and (' (requested '..plan.requested..')') or '')
 lines[#lines+1]=string.format('Expected crafts: %d',plan.crafts)
 lines[#lines+1]='Cash to buy missing materials: '..self:Money(plan.cash)
 lines[#lines+1]='Full material value: '..self:Money(plan.economic)
 if plan.recovered>0 then lines[#lines+1]='Possible resale of outputs: '..self:Money(plan.recovered)..' (not guaranteed to sell)' end
 if plan.unknown then lines[#lines+1]='Some prices are unknown, so totals are unknown. Set prices or scan with VoidMark Market.' end
 if plan.estimated then lines[#lines+1]='Some colour thresholds are estimated; the plan sharpens as you level and rescan.' end
 for _,n in ipairs(plan.notes) do lines[#lines+1]=n end
 lines[#lines+1]=''
 lines[#lines+1]='MATERIALS'
 for _,m in ipairs(plan.materials) do
  lines[#lines+1]=string.format('%s: need %d | have %d | missing %d | %s',self:ItemName(m.id),m.need,m.owned,m.missing,m.unit and self:Money(m.cash) or 'price unknown')
  if m.price then lines[#lines+1]='  '..self:PriceLabel(m.price) end
  for _,a in ipairs(m.allocations) do lines[#lines+1]='  '..a.qty..': '..a.transfer end
 end
 if #plan.unusable>0 then
  lines[#lines+1]=''
  lines[#lines+1]='NOT USABLE NOW'
  for i,u in ipairs(plan.unusable) do
   if i>25 then lines[#lines+1]='...and '..(#plan.unusable-25)..' more';break end
   lines[#lines+1]=u.name..' - '..u.reason..(u.source and (' | '..u.source) or '')
  end
 end
 lines[#lines+1]=''
 lines[#lines+1]='Skill-up odds: orange 100%, then (gray - skill)/(gray - yellow). Craft counts are expected values; real results vary. Trainer and vendor locations are shown only when the client supplies source text.'
 return table.concat(lines,'\n')
end

-- Queue the whole plan as craft plans for the planning character.
function N:QueueLevelingPlan(plan,cid,pid)
 if not plan or plan.error then return self:Print('No plan to queue.') end
 local added=0
 for _,seg in ipairs(plan.segments) do
  if #self.db.plans>=200 then self:Print('Planner limit: 200 entries.');break end
  self.db.plans[#self.db.plans+1]={character=cid,profession=pid,recipe=seg.key,qty=math.min(9999,seg.crafts)};added=added+1
 end
 self.dirty=true
 self:Print(added..' leveling steps added to the Crafting queue.')
end
