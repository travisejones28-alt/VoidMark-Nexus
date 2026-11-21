local N,test,eq=...
test('0.14 Crates: every crate has its favor, level and bundles; item IDs are unique',function()
 eq(#N.CRATES,30)
 local seen={}
 for _,cr in ipairs(N.CRATES) do
  assert(not seen[cr.id],'duplicate crate '..cr.id); seen[cr.id]=true
  assert(N.CRATE_FAVOR[cr.tier][cr.kind],'favor for '..cr.name)
  assert(N.CRATE_LEVEL[cr.tier],'level for '..cr.name)
  assert(#cr.options>=1,'bundles for '..cr.name)
  for _,o in ipairs(cr.options) do assert(o[1]>0 and o[2]>0,cr.name) end
 end
 eq(N.CRATE_FAVOR.Apprentice.gathered,5); eq(N.CRATE_FAVOR.Expert.crafted,30)
end)

test('0.14 Crates: cheapest bundle, crate price, favor and cost per favor from Market prices',function()
 local old=VoidMarkMarket; local now=time()
 local prices={[248682]=720,[2447]=100,[765]=35,[2449]=145,[785]=114,[2450]=125,   -- Apprentice Herbs
  [248703]=1600,[2840]=250,[3576]=150,[2841]=239}                                 -- Apprentice Ingots
 VoidMarkMarket={db={},PriceObservation=function(_,id) local f=prices[id]; if f then return {floor=f,fair=f*2,at=now-600} end end}
 local plans=N:CratePlans()
 local byName={}; for _,p in ipairs(plans) do byName[p.crate.name]=p end
 local herbs=byName['Apprentice Herbs']
 eq(herbs.best.item,765); eq(herbs.best.qty,20); eq(herbs.best.cost,700)            -- 20 Silverleaf at the LOWEST listing (35c)
 eq(herbs.crateUnit,720); eq(herbs.refund,250); eq(herbs.total,1170); eq(herbs.favor,5); eq(herbs.perFavor,234)   -- 2s 50c paid back
 local ingots=byName['Apprentice Ingots']
 eq(ingots.best.item,2841); eq(ingots.best.cost,2390); eq(ingots.favor,10); eq(ingots.perFavor,349)  -- 10 Bronze beats 20 Tin; crafted: double favor
 eq(plans[1].crate.name,'Apprentice Herbs')                                        -- sorted cheapest per favor first
 assert(plans[#plans].perFavor==nil,'unpriced crates go last')
 -- 0.14.3: a crate you hold still counts at its AH price.
 local cid=N.characterID; local c=N.db.characters[cid]; local bags=c.bags; c.bags={[248682]=1}; c.bagsAt=now
 local again; for _,p in ipairs(N:CratePlans()) do if p.crate.id==248682 then again=p end end
 eq(again.crates,1); eq(again.total,1170); eq(again.perFavor,234)
 c.bags=bags
 -- The tab renders a "takes / costs / gives" line for each crate.
 N:Show('Crates'); N:Render()
 local rows=N:RenderCrates(N.ui)
 assert(rows[1].text:find('Apprentice Herbs  -  2s 34c per favor',1,true),rows[1].text)
 assert(rows[2].text:find('20 Silverleaf  |  5 favor  |  costs 11s 70c (incl. crate 7s 20c)',1,true),rows[2].text)
 assert(rows[#rows].text:find('Forged Delivery Receipt',1,true),'reputation tip')
 assert(N.ui.crateInfo:GetText():find('Dokimi',1,true),'Horde hand-in NPC')
 VoidMarkMarket=old
end)

test('0.14.1 Favor rewards: recipe favor follows the vendor skill bands; Horde camp vendors; gold at the cheapest crate',function()
 eq(N:FavorCost('Alchemy',245),120); eq(N:FavorCost('Alchemy',250),180); eq(N:FavorCost('Engineering',275),270)
 eq(N:FavorCost('Leatherworking',185),60); eq(N:FavorCost('Blacksmithing',250),90); eq(N:FavorCost('Cooking',250),90)
 local alch=N:FavorRecipes('Alchemy','Horde'); assert(#alch>=20,'alchemy favor recipes '..#alch)
 for _,r in ipairs(alch) do assert(r.favor and r.vendor=='Apothecary Durelle',r.name) end
 local old=VoidMarkVoidMarket; local now=time()
 local oldM=VoidMarkMarket
 VoidMarkMarket={db={},PriceObservation=function(_,id) local f=({[248682]=720,[765]=35})[id]; if f then return {floor=f,at=now-60} end end}
 local c=N.character; local profs=c.professions
 c.professions={[171]={name='Alchemy',skill=200,recipes={{name='Elixir of Lesser Spirit'}}}}
 N.ui.crateRewards=true; N:Show('Crates'); N:Render()
 local rows=N:RenderFavorRewards(N.ui)
 local sawKodo,sawKnown,sawRecipe=false,false,false
 for _,r in ipairs(rows) do
  if r.text:find('Pack Kodo',1,true) then sawKodo=true; assert(r.text:find('6000 favor',1,true) and r.text:find('~',1,true),r.text) end
  if r.text:find('Elixir of Lesser Spirit',1,true) then sawKnown=true end
  if r.text:find('Lesser Mageblood Elixir',1,true) then sawRecipe=true; assert(r.text:find('45 favor',1,true),r.text) end
 end
 assert(sawKodo,'other rewards'); assert(not sawKnown,'known recipe hidden'); assert(sawRecipe,'unknown recipe listed')
 c.professions=profs; N.ui.crateRewards=nil; VoidMarkMarket=oldM
end)
