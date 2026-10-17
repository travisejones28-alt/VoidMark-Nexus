local _, N = ...
function N:Stock(targetID)
 if self.renderStocks and self.renderStocks[targetID] then return self.renderStocks[targetID] end
 local target=self.db.characters[targetID]; local stock,seen={},{}
 if not target then return stock end
 local ids={targetID}; for id in pairs(self.db.characters) do if id~=targetID then ids[#ids+1]=id end end
 table.sort(ids,function(a,b) if a==targetID then return b~=targetID elseif b==targetID then return false end return a<b end)
 for _,id in ipairs(ids) do
  local c=self.db.characters[id]; local physical=c.guid or (c.realm..'/'..c.name)
  local allowed=not self.db.excluded[id] and (id==targetID or self.db.settings.includeAlts)
   and (not c.imported or self.db.settings.includeImports) and c.realm==target.realm and c.faction==target.faction
  if allowed and not seen[physical] then
   seen[physical]=true
   for _,location in ipairs({'bags','bank'}) do
    local at=c[location..'At']; local sane=self:Finite(at,0,self:Now()+300)
    local fresh=sane and self:Now()-at<=self.db.settings.inventoryAge
    if (location~='bank' or self.db.settings.includeBanks) and (fresh or self.db.settings.includeStale and (sane or at==nil)) then
     for item,qty in pairs(c[location] or {}) do
      if self:Finite(qty,1,1e9) then
       stock[item]=stock[item] or {}; table.insert(stock[item],{id=id,location=location,qty=qty,at=at,imported=c.imported,
        transfer=id==targetID and (location=='bank' and 'Withdraw from bank' or 'On crafting character') or
         (c.imported and 'Cross-account trade/mail; verify item transferability' or 'Mail/trade from '..c.name..'; verify item transferability')})
      end
     end
    end
   end
  end
 end
 if self.renderStocks then self.renderStocks[targetID]=stock end
 return stock
end
function N:Requirements(recipe,qty)
 local out={}; for _,r in ipairs(recipe.reagents or {}) do
  if r.id and self:Finite(r.qty,1,1e6) then out[r.id]=(out[r.id] or 0)+r.qty*qty end
 end; return out
end
function N:Allocate(requirements,stock,used)
 local rows={}; used=used or {}
 for item,need in pairs(requirements) do
  local row={id=item,need=need,missing=need,allocations={}}
  for _,s in ipairs(stock[item] or {}) do
   local key=s.id..'/'..s.location..'/'..item; local take=math.min(row.missing,math.max(0,s.qty-(used[key] or 0)))
   if take>0 then local a=self:Copy(s); a.qty=take; table.insert(row.allocations,a); used[key]=(used[key] or 0)+take; row.missing=row.missing-take end
  end
  rows[#rows+1]=row
 end
 table.sort(rows,function(a,b) return a.id<b.id end); return rows
end
function N:Evaluate(recipe,qty,targetID,used)
 qty=math.floor(tonumber(qty) or 1); qty=math.min(9999,math.max(1,qty))
 local out={rows=self:Allocate(self:Requirements(recipe,qty),self:Stock(targetID),used),buyAll=0,buyMissing=0,owned=0,unknown=false,stale=false}
 local settings=self.db.settings
 local target=self.db.characters[targetID]
 if not target or target.realm~=self.character.realm or target.faction~=self.character.faction then out.unknown=true end
 if recipe.incomplete or not recipe.reagents then out.unknown=true end
 for _,r in ipairs(out.rows) do
  local p=self:Price(r.id); r.price=p; local cost=p and p.unit
  if cost then
   out.buyAll=out.buyAll+r.need*cost; out.buyMissing=out.buyMissing+r.missing*cost; out.owned=out.owned+(r.need-r.missing)*cost
   out.stale=out.stale or p.stale
  else out.unknown=true end
 end
 out.output=qty*(recipe.outputMin or 1); out.outputMax=qty*(recipe.outputMax or recipe.outputMin or 1)
 out.sale=self:Price(recipe.output); local sale=out.sale and out.sale.unit
 out.stale=out.stale or (out.sale and out.sale.stale) or false
 out.depositCash=settings.deposit*qty; out.depositLoss=out.depositCash*settings.failedAuctions
 out.cost=out.buyAll*(1+settings.waste); out.cash=out.buyMissing*(1+settings.waste)
 if sale and not out.unknown and not recipe.bound then
  out.gross=sale*out.output*settings.saleFraction; out.fees=out.gross*settings.cut
  out.net=out.gross-out.fees-out.depositLoss; out.economic=out.net-out.cost; out.cashProfit=out.net-out.cash
  out.sellMaterials=out.buyAll*(1-settings.cut); out.craftAdvantage=out.net-out.sellMaterials
  out.margin=out.cost>0 and out.economic/out.cost or nil
 end
 if out.unknown then out.cost=nil; out.cash=nil; out.owned=nil end
 return out
end
function N:Recipe(ref)
 local c=self.db.characters[ref.character]; local p=c and c.professions[ref.profession]
 return p and p.recipes and p.recipes[ref.recipe]
end
function N:AddPlan(ref,qty)
 local r=self:Recipe(ref); if not r or not r.learned then return self:Print('Choose a known recipe.') end
 if #self.db.plans>=200 then return self:Print('Planner limit: 200 entries.') end
 local p=self:Copy(ref); p.qty=math.min(9999,math.max(1,math.floor(tonumber(qty) or 1))); self.db.plans[#self.db.plans+1]=p; self.dirty=true
end
function N:Shopping()
 local out,used={},{}
 for i,p in ipairs(self.db.plans) do
  local r=self:Recipe(p)
  if r then
   local e=self:Evaluate(r,p.qty,p.character,used)
   for _,row in ipairs(e.rows) do row.plan=i; row.character=p.character; row.recipeName=r.name; out[#out+1]=row end
  end
 end
 return out
end
function N:Search(query,character,profession,filter)
 local rows={}; query=string.lower(query or '')
 for cid,c in pairs(self.db.characters) do if not character or cid==character then
  for pid,p in pairs(c.professions) do if not profession or pid==profession then
   for rid,r in pairs(p.recipes or {}) do
    if (query=='' or string.find(string.lower(r.name or ''),query,1,true)) and
     (not filter or filter=='All' or filter=='Known' and r.learned or filter=='Unknown' and not r.learned or filter=='Wishlist' and self.db.wish[rid]) then
     rows[#rows+1]={character=cid,profession=pid,recipe=rid,r=r,c=c,p=p}
    end
   end
  end end
 end end
 table.sort(rows,function(a,b) if a.r.name==b.r.name then return a.character<b.character end return a.r.name<b.r.name end)
 return rows
end
function N:Leveling(cid,pid,target,mode)
 local c=self.db.characters[cid]; local p=c and c.professions[pid]; local out={}
 if not p then return out end
 local chances={optimal=1,medium=.5,easy=.25,trivial=0,[0]=1,[1]=.5,[2]=.25,[3]=0}
 local points=math.max(0,math.min(10,(tonumber(target) or (p.skill or 0)+1)-(p.skill or 0)))
 for rid,r in pairs(p.recipes or {}) do
  local chance=chances[r.difficulty]
  if r.learned and chance and chance>0 and not r.incomplete then
   local qty=math.ceil(points/chance); local e=self:Evaluate(r,math.max(1,qty),cid); local missing=0
   for _,row in ipairs(e.rows) do missing=missing+row.missing end
   if e.cash then out[#out+1]={recipe=rid,name=r.name,qty=qty,chance=chance,cash=e.cash,missing=missing,
    score=mode=='Inventory' and missing or mode=='Balanced' and e.cash+missing*100 or e.cash} end
  end
 end
 table.sort(out,function(a,b) return a.score<b.score end); return out
end
