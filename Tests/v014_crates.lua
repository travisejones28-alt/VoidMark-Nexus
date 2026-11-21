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
 eq(herbs.crateUnit,720); eq(herbs.total,1420); eq(herbs.favor,5); eq(herbs.perFavor,284)
 local ingots=byName['Apprentice Ingots']
 eq(ingots.best.item,2841); eq(ingots.best.cost,2390); eq(ingots.favor,10); eq(ingots.perFavor,399)  -- 10 Bronze beats 20 Tin; crafted: double favor
 eq(plans[1].crate.name,'Apprentice Herbs')                                        -- sorted cheapest per favor first
 assert(plans[#plans].perFavor==nil,'unpriced crates go last')
 -- A crate you hold costs nothing extra.
 local cid=N.characterID; local c=N.db.characters[cid]; local bags=c.bags; c.bags={[248682]=1}; c.bagsAt=now
 local again; for _,p in ipairs(N:CratePlans()) do if p.crate.id==248682 then again=p end end
 eq(again.crates,1); eq(again.total,700); eq(again.perFavor,140)
 c.bags=bags
 -- The tab renders a "takes / costs / gives" line for each crate.
 N:Show('Crates'); N:Render()
 local rows=N:RenderCrates(N.ui)
 assert(rows[1].text:find('takes 20 ',1,true) and rows[1].text:find('gives 5 favor',1,true) and rows[1].text:find('/favor',1,true),rows[1].text)
 assert(N.ui.crateInfo:GetText():find('Dokimi',1,true),'Horde hand-in NPC')
 VoidMarkMarket=old
end)
