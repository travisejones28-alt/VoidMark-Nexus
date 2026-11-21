local _, N = ...
-- Waylaid Crates: cheapest Merchant's Favor from the latest AH prices.
-- A crate is filled with ONE of its bundles; filled crates are handed to Dokimi
-- (Durotar Supply and Logistics, west of the Crossroads) or Marcy Baker
-- (Azeroth Commerce Authority, Three Corners, Redridge).
-- Favor per sealed crate (player reports; Blizzard has not published them):
--   gathered goods (Herbs, Ore, Textiles, Curiosities): 5 / 10 / 15 / 20
--   crafted goods  (Fabrics, Ingots, Parts):             10 / 20 / 30 / 40
--   Apprentice / Journeyman / Expert / Artisan. Artisan amounts are expected, not confirmed.
-- Sources: method.gg and conquestcapped.com crate guides, outof.games favor table (Nov 2026).
N.CRATE_FAVOR={Apprentice={gathered=5,crafted=10},Journeyman={gathered=10,crafted=20},
 Expert={gathered=15,crafted=30},Artisan={gathered=20,crafted=40}}
N.CRATE_FAVOR_ESTIMATED={Artisan=true}
N.CRATE_LEVEL={Apprentice=10,Journeyman=10,Expert=20,Artisan=35}
local function c(id,tier,name,kind,options) return {id=id,tier=tier,name=name,kind=kind,options=options} end
N.CRATES={
 c(248682,'Apprentice','Apprentice Herbs','gathered',{{2447,20},{765,20},{2449,10},{785,10},{2450,10}}),
 c(248686,'Journeyman','Journeyman Herbs','gathered',{{3820,10},{2453,10},{3355,10},{3369,10},{3356,10}}),
 c(248690,'Expert','Earthly Expert Herbs','gathered',{{3357,20},{3818,10},{3821,10},{3358,10}}),
 c(248691,'Expert','Flowering Expert Herbs','gathered',{{3819,10},{4625,10},{8831,20},{8836,10}}),
 c(248695,'Artisan','Earthly Artisan Herbs','gathered',{{13464,10},{8838,20},{8839,10},{8845,10},{8846,10}}),
 c(248696,'Artisan','Flowering Artisan Herbs','gathered',{{13463,20},{13465,20},{13466,20},{13467,20}}),
 c(248683,'Apprentice','Apprentice Ore','gathered',{{2770,20},{2771,20}}),
 c(248687,'Journeyman','Journeyman Ore','gathered',{{2775,10},{2772,20}}),
 c(248692,'Expert','Expert Ore','gathered',{{2776,10},{3858,20}}),
 c(248697,'Artisan','Artisan Ore','gathered',{{7911,10},{10620,20},{11370,20}}),
 c(248684,'Apprentice','Apprentice Textiles','gathered',{{2589,40},{2318,20}}),
 c(248688,'Journeyman','Journeyman Textiles','gathered',{{2592,20},{4306,40},{2319,20}}),
 c(248693,'Expert','Expert Textiles','gathered',{{4338,40},{4234,20}}),
 c(248698,'Artisan','Artisan Textiles','gathered',{{14047,40},{4304,20},{8170,20}}),
 c(248685,'Apprentice','Apprentice Curiosities','gathered',{{10940,20},{10939,4},{10978,6},{11084,2}}),
 c(248689,'Journeyman','Journeyman Curiosities','gathered',{{11083,20},{11082,4},{11138,6},{11139,2}}),
 c(248694,'Expert','Expert Curiosities','gathered',{{11137,20},{11135,4},{11177,6},{11178,2}}),
 c(248699,'Artisan','Artisan Curiosities','gathered',{{11176,20},{11175,4},{14343,6},{14344,2}}),
 c(248703,'Apprentice','Apprentice Ingots','crafted',{{2840,20},{3576,20},{2841,10}}),
 c(248706,'Journeyman','Journeyman Ingots','crafted',{{2842,10},{3575,20}}),
 c(248709,'Expert','Expert Ingots','crafted',{{3860,20},{3859,15},{3577,10}}),
 c(248712,'Artisan','Artisan Ingots','crafted',{{11371,2},{6037,10},{12359,20}}),
 c(248702,'Apprentice','Apprentice Fabrics','crafted',{{4231,2},{2996,20}}),
 c(248705,'Journeyman','Journeyman Fabrics','crafted',{{2997,6},{4305,10},{4233,2}}),
 c(248708,'Expert','Expert Fabrics','crafted',{{4339,8},{4236,2}}),
 c(248711,'Artisan','Artisan Fabrics','crafted',{{14048,8},{8172,2}}),
 c(248704,'Apprentice','Apprentice Parts','crafted',{{4359,16},{4361,16},{4363,4}}),
 c(248707,'Journeyman','Journeyman Parts','crafted',{{4371,8},{4375,7},{4382,4},{10558,45}}),
 c(248710,'Expert','Expert Parts','crafted',{{4387,8},{10559,5},{10560,12},{10561,5}}),
 c(248713,'Artisan','Artisan Parts','crafted',{{15994,5},{18631,5},{16000,2}}),
}

-- What one unit costs to BUY now: the lowest listing from the latest scan
-- (Market's own scan or the one synced from the bank character), else Nexus' price.
function N:BuyUnit(id)
 local api=VoidMarkMarket
 if self.db.settings.market and type(api)=='table' and api.db and type(api.PriceObservation)=='function' then
  local o=self:Call(api.PriceObservation,api,id)
  if type(o)=='table' and self:Finite(o.floor,1,1e12) then return o.floor,o.at end
 end
 local p=self:Price(id)
 if p and self:Finite(p.unit,1,1e12) then return p.unit,p.at end
 return nil
end

local function have(stock,id)
 local n=0
 for _,s in ipairs(stock[id] or {}) do if N:Finite(s.qty,0,1e9) then n=n+s.qty end end
 return n
end

-- One entry per crate: cheapest bundle, its cost, the crate's own price, favor, cost per favor.
function N:CratePlans()
 local stock=self.characterID and self:Stock(self.characterID) or {}
 local out={}; local newest
 for _,cr in ipairs(self.CRATES) do
  local favor=self.CRATE_FAVOR[cr.tier][cr.kind]
  local options,best={},nil
  for _,o in ipairs(cr.options) do
   local id,qty=o[1],o[2]
   local unit,at=self:BuyUnit(id)
   local opt={item=id,qty=qty,unit=unit,cost=unit and unit*qty or nil,have=have(stock,id)}
   if at and (not newest or at>newest) then newest=at end
   options[#options+1]=opt
   if opt.cost and (not best or opt.cost<best.cost) then best=opt end
  end
  local crateUnit,crateAt=self:BuyUnit(cr.id)
  if crateAt and (not newest or crateAt>newest) then newest=crateAt end
  local crates=have(stock,cr.id)
  -- A crate you already hold costs nothing extra; otherwise add its AH price when known.
  local crateCost=crates>0 and 0 or crateUnit
  local total=best and best.cost+(crateCost or 0) or nil
  out[#out+1]={crate=cr,favor=favor,estimated=self.CRATE_FAVOR_ESTIMATED[cr.tier] or false,level=self.CRATE_LEVEL[cr.tier],
   options=options,best=best,crateUnit=crateUnit,crateCost=crateCost,crates=crates,
   total=total,perFavor=total and total/favor or nil,fillPerFavor=best and best.cost/favor or nil}
 end
 table.sort(out,function(a,b)
  if (a.perFavor~=nil)~=(b.perFavor~=nil) then return a.perFavor~=nil end
  if a.perFavor and b.perFavor and a.perFavor~=b.perFavor then return a.perFavor<b.perFavor end
  return a.crate.name<b.crate.name
 end)
 return out,newest
end

local COL={good={.3,.9,.3},white={1,1,1},muted={.65,.6,.72},accent={.78,.6,1},bad={1,.35,.35},gold={1,.82,0}}
function N:RenderCrates(u)
 local plans,newest=self:CratePlans()
 local level=self:Call(UnitLevel,'player')
 local faction=self.character and self.character.faction
 local npc=faction=='Alliance' and 'Marcy Baker (Three Corners, Redridge)' or 'Dokimi (west of the Crossroads, Barrens)'
 u.crateInfo:SetText('Cheapest Merchant\'s Favor from the latest AH scan ('..(newest and self:Ago(newest) or 'no scan yet')..'). '..
  'Each crate takes ONE bundle. Hand filled crates to '..npc..'. Hover a row for every bundle.')
 local rows={}
 for i,p in ipairs(plans) do
  local cr=p.crate
  local fav=p.favor..(p.estimated and '*' or '')..' favor'
  local text,color
  if not p.best then
   text=cr.name..': no AH price for any bundle yet'
   color=COL.muted
  else
   local takes=p.best.qty..' '..self:ItemName(p.best.item)
   local crate=p.crates>0 and 'crate: you have '..p.crates or (p.crateUnit and 'crate '..self:Money(p.crateUnit) or 'crate: not on AH')
   text=string.format('%s  |  takes %s  |  costs %s (+%s)  |  gives %s  |  %s/favor',
    cr.name,takes,self:Money(p.best.cost),crate,fav,self:Money(p.perFavor))
   color=(i==1 and COL.good) or COL.white
   if level and p.level>level then text=text..'  (needs level '..p.level..')'; color=COL.muted end
  end
  local plan=p
  rows[#rows+1]={text=text,color=color,item=cr.id,tip=function(tt)
   tt:AddLine(' ')
   tt:AddLine(plan.crate.tier..' crate, '..plan.crate.kind..' goods: '..plan.favor..' Merchant\'s Favor'..(plan.estimated and ' (expected, not confirmed)' or ''),1,.82,0,true)
   tt:AddLine('Turn-in needs level '..plan.level,.8,.8,.8)
   tt:AddLine('Fill with ONE of:',1,1,1)
   for _,o in ipairs(plan.options) do
    local line=o.qty..' '..N:ItemName(o.item)..': '..(o.cost and N:Money(o.cost)..' ('..N:Money(o.unit)..' each)' or 'no AH price')
    if o.have>0 then line=line..'  - you have '..o.have end
    local best=plan.best==o
    tt:AddLine((best and '> ' or '   ')..line,best and .3 or .85,best and .9 or .85,best and .3 or .85)
   end
   tt:AddLine(plan.crates>0 and ('You have '..plan.crates..' of this crate') or ('Crate on AH: '..(plan.crateUnit and N:Money(plan.crateUnit) or 'not listed')),.8,.8,.8)
   if plan.fillPerFavor then tt:AddLine('Filling only (crate already owned): '..N:Money(plan.fillPerFavor)..' per favor',.8,.8,.8) end
  end}
 end
 u.footer:SetText('* Artisan favor is the expected amount (not yet confirmed). Prices: lowest listing in the latest scan.')
 return rows
end
