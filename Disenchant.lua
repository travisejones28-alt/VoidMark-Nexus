local _, N = ...
-- VoidMark Nexus: independently authored disenchant value estimates for WoW Forever.
-- The built-in bands use the publicly documented Classic-to-Forever level mapping;
-- their probabilities are estimates, NOT measured Forever drops.
-- Do not import third-party addon code or GPL tables. DisenchantBuddy is optional.
local materials={
 [10940]='Strange Dust',[10938]='Lesser Magic Essence',[10939]='Greater Magic Essence',
 [10978]='Small Glimmering Shard',[10998]='Lesser Astral Essence',[11083]='Soul Dust',
 [11082]='Greater Astral Essence',[11084]='Large Glimmering Shard',
 [11134]='Lesser Mystic Essence',[11138]='Small Glowing Shard',
 [11137]='Vision Dust',[11135]='Greater Mystic Essence',[11139]='Large Glowing Shard',
 [11174]='Lesser Nether Essence',[11177]='Small Radiant Shard',
 [11176]='Dream Dust',[11175]='Greater Nether Essence',[11178]='Large Radiant Shard',
 [16202]='Lesser Eternal Essence',[14343]='Small Brilliant Shard',
 [16204]='Illusion Dust',[16203]='Greater Eternal Essence',[14344]='Large Brilliant Shard',
 [20725]='Nexus Crystal'
}
-- Item level (NOT required player level), dust, essence, rare shard, and quantities.
-- Probabilities are independently transcribed from the Classic-based WoW Forever
-- reference at legacyofwarcraft.com/db/forever/professions/disenchanting.html.
-- Each odds array is {dust, essence, shard}, in percentages.
local bands={
 {cap=15,d=10940,e=10938,dmin=1,dmax=2,emin=1,emax=2,a={80,20,0},w={20,80,0}},
 {cap=20,d=10940,e=10939,s=10978,dmin=2,dmax=3,emin=1,emax=2,a={75,20,5},w={20,75,5}},
 {cap=25,d=10940,e=10998,s=10978,dmin=4,dmax=6,emin=1,emax=2,a={75,15,10},w={15,75,10}},
 {cap=30,d=11083,e=11082,s=11084,dmin=1,dmax=2,emin=1,emax=2,a={75,20,5},w={20,75,5}},
 {cap=35,d=11083,e=11134,s=11138,dmin=2,dmax=5,emin=1,emax=2,a={75,20,5},w={20,75,5}},
 {cap=40,d=11137,e=11135,s=11139,dmin=1,dmax=2,emin=1,emax=2,a={75,20,5},w={20,75,5}},
 {cap=45,d=11137,e=11174,s=11177,dmin=2,dmax=5,emin=1,emax=2,a={75,20,5},w={20,75,5}},
 {cap=50,d=11176,e=11175,s=11178,dmin=1,dmax=2,emin=1,emax=2,a={75,20,5},w={20,75,5}},
 {cap=55,d=11176,e=16202,s=14343,dmin=2,dmax=5,emin=1,emax=2,a={75,20,5},w={22,75,3}},
 {cap=60,d=16204,e=16203,s=14344,dmin=1,dmax=2,emin=1,emax=2,a={75,20,5},w={22,75,3}},
 {cap=65,d=16204,e=16203,s=14344,dmin=2,dmax=5,emin=2,emax=2,a={75,20,5},w={22,75,3}}
}
local rare={
 {25,10978},{30,11084},{35,11138},{40,11139},{45,11177},
 {50,11178},{55,14343},{65,14344}
}
local epic={
 {45,11177,2,4},{50,11178,2,4},{55,14343,2,4},{60,20725,1,1}
}
local function add(out,id,chance,lo,hi)
 if id and chance>0 then out[#out+1]={itemId=id,probability=chance,minQuantity=lo,maxQuantity=hi} end
end
function N:DEBaseline(quality,level,class)
 if type(level)~='number' or level%1~=0 or level<5 or level>65 then return nil end
 local out={}
 if quality==2 then
  for _,b in ipairs(bands) do
   if level<=b.cap then
    local odds=class==2 and b.w or b.a
    add(out,b.d,odds[1],b.dmin,b.dmax)
    add(out,b.e,odds[2],b.emin,b.emax)
    add(out,b.s,odds[3],1,1)
    return out
   end
  end
 elseif quality==3 and level>=16 then
  for _,b in ipairs(rare) do
   if level<=b[1] then add(out,b[2],100,1,1);return out end
  end
 elseif quality==4 and level>=40 then
  for _,b in ipairs(epic) do
   if level<=b[1] then add(out,b[2],100,b[3],b[4]);return out end
  end
 end
 return nil
end

-- Validate other addons' results. A non-Classic material or bad chance table
-- must never leak TBC/expansion estimates into Forever profit decisions.
function N:DEValidate(rows)
 if type(rows)~='table' or #rows<1 or #rows>8 then return nil end
 local out,total={},0
 for _,r in ipairs(rows) do
  if type(r)~='table' then return nil end
  local id,p,lo,hi=r.itemId,r.probability,r.minQuantity,r.maxQuantity
  if not materials[id] or not self:Finite(p,0,100) or not self:Finite(lo,1,20)
   or not self:Finite(hi,lo,20) or lo%1~=0 or hi%1~=0 then return nil end
  add(out,id,p,lo,hi);total=total+p
 end
 if math.abs(total-100)>0.1 then return nil end
 return out
end

local function itemID(item)
 if type(item)=='number' then return item end
 if type(item)~='string' then return nil end
 return tonumber(item:match('item:(%d+)') or item:match('^%s*(%d+)%s*$'))
end
function N:DEItem(item)
 local id=itemID(item)
 if not id or id%1~=0 or id<1 or id>1e9 then return nil,'Provide an item link or numeric item ID.' end
 local api=GetItemInfo or (C_Item and C_Item.GetItemInfo)
 local request=type(item)=='string' and item:find('item:',1,true) and item or id
 local name,link,quality,level,_,_,_,_,slot,_,vendor,class=self:Call(api,request)
 if not name then return nil,'Item not cached. Hover the item in game and retry.' end
 if class~=2 and class~=4 then return nil,'Only weapons and armor may be disenchanted.' end
 if quality~=2 and quality~=3 and quality~=4 then return nil,'Requires uncommon, rare, or epic gear.' end
 if type(slot)=='string' and (slot=='INVTYPE_SHIRT' or slot=='INVTYPE_TABARD' or slot=='INVTYPE_BAG') then
  return nil,'This equipment slot is not eligible.'
 end
 if not self:Finite(level,1,10000) or level%1~=0 then return nil,'Item level unavailable.' end
 -- No unverified >65 green/blue or >92 epic expansion tables.
 if (quality~=4 and level>65) or (quality==4 and level>92) then
  return nil,'No confirmed Forever disenchant odds for this item level.'
 end
 local rows,source
 local buddy=DisenchantBuddy and DisenchantBuddy.API and DisenchantBuddy.API.v1
 if type(buddy)=='table' and type(buddy.GetDisenchantResults)=='function' then
  rows=self:DEValidate(self:Call(buddy.GetDisenchantResults,'VoidMarkNexus',link or id))
  if rows then source='DisenchantBuddy API (external estimate)' end
 end
 if not rows then
  rows=self:DEBaseline(quality,level,class)
  if rows then source='Classic-based Forever estimate (unverified)' end
 end
 if not rows then return nil,'No reliable quantity model for this Forever item level.' end
 return {id=id,name=name,link=link,quality=quality,level=level,class=class,
  source=source,rows=rows,vendor=self:Finite(vendor,0,1e12) and vendor or nil}
end

-- A DE price is only a problem when Market says its data is untrusted or the
-- last sighting is older than Nexus' max price age (default a day). Market's own
-- "stale" status also means "not in the very latest scan", which is true for most
-- greens and many enchanting materials, so it no longer blocks the comparison.
function N:DEPriceOld(p)
 if type(p)~='table' then return false end
 if p.untrusted then return true end
 return self:Finite(p.at,0,1e12) and self:Now()-p.at>self.db.settings.maxAge or false
end
-- Values use Nexus' own realm/faction-scoped Market prices, not any remote
-- market. All outcomes must be priced; missing prices are never treated as 0.
function N:DEValue(item)
 local info,err=self:DEItem(item)
 if not info then return nil,err end
 local gross,missing,stale,untrusted=0,0,false,false
 for _,r in ipairs(info.rows) do
  r.expected=r.probability/100*(r.minQuantity+r.maxQuantity)/2
  r.name=materials[r.itemId]
  r.price=self:Price(r.itemId)
  if r.price and self:Finite(r.price.unit,0,1e12) then
   gross=gross+r.expected*r.price.unit
   r.old=self:DEPriceOld(r.price)
   if r.price.untrusted then untrusted=true elseif r.old then stale=true end
  else missing=missing+1 end
 end
 info.unknownPrices=missing
 if missing==0 then
  info.gross=gross
  local s=self.db.settings
  info.net=gross*(1-s.cut)*s.saleFraction
 end
 info.itemPrice=self:Price(info.id)
 local p=info.itemPrice
 if p and self:Finite(p.unit,0,1e12) then
  info.auctionNet=p.unit*(1-self.db.settings.cut)*self.db.settings.saleFraction
  if p.untrusted then untrusted=true elseif self:DEPriceOld(p) then stale=true end
 end
 info.stale=stale; info.untrusted=untrusted
 -- Only claim a best option when all three values are known and none comes
 -- from untrusted data. Old prices still give a best option, marked as such.
 if info.net and info.auctionNet and info.vendor and not untrusted then
  local best=info.vendor>info.net and 'Vendor' or 'Disenchant'
  local max=math.max(info.vendor,info.net)
  if info.auctionNet>max then best='Auction (estimate)' end
  info.best=best
 end
 return info
end
local function money(self,v)
 return v and self:Money(v) or 'unknown'
end
function N:DECommand(arg)
 arg=tostring(arg or '')
 if arg=='on' or arg=='off' then
  self.db.settings.deTooltips=arg=='on';self.dirty=true
  return self:Print('Disenchant tooltip: '..arg)
 end
 if arg=='' then return self:Print('Usage: /vmn de ITEM_LINK or ITEM_ID; /vmn de on|off') end
 local v,err=self:DEValue(arg)
 if not v then return self:Print('Disenchant: '..err) end
 self:Print(v.name..' (item level '..v.level..') | '..v.source)
 for _,r in ipairs(v.rows) do
  self:Print(string.format('  %s: %g%%, %d-%d; average %.2f; %s',
   r.name,r.probability,r.minQuantity,r.maxQuantity,r.expected,
   r.price and self:Money(r.price.unit)..(r.old and ' (over a day old)' or '') or 'price missing'))
 end
 self:Print('DE expected sale net: '..money(self,v.net)..(v.unknownPrices>0 and ' (missing '..v.unknownPrices..' material prices)' or '')
  ..'; vendor: '..money(self,v.vendor)..'; auction sale net ~'..money(self,v.auctionNet))
 if v.best then self:Print('Best estimated option: '..v.best)
 else self:Print('No complete reliable best choice: missing/stale prices or incomplete estimates.') end
 self:Print('Expected value over many disenchants, not guaranteed for one item. Check that this item is actually disenchantable.')
end

function N:AddDisenchantTooltip(t,id)
 if not self.ready or not self.db or not self.db.settings.deTooltips or not t or not t.AddDoubleLine then return end
 id=tonumber(id)
 if not id or t.vmnDE==id then return end
 local v=self:DEValue(id)
 if not v then return end
 t.vmnDE=id
 t:AddDoubleLine('Nexus DE net (expected)',money(self,v.net),.8,.62,1,1,.95,.65)
 t:AddDoubleLine('Vendor / auction net ~',money(self,v.vendor)..' / '..money(self,v.auctionNet),.72,.72,.82,1,1,1)
 if v.best then t:AddLine('Best estimate: '..v.best..(v.stale and ' (some prices over a day old)' or ''),.45,1,.55)
 elseif v.unknownPrices>0 then t:AddLine('DE incomplete: '..v.unknownPrices..' materials have no price',1,.5,.35)
 elseif v.untrusted then t:AddLine('DE comparison skipped: Market data not trusted yet',1,.5,.35) end
 if t.Show then t:Show() end
end
