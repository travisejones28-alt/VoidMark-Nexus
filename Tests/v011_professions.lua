local N,test,eq,widget=...
-- 0.11 Priority 4: leveling while you play.
local function setup()
 local c=N.character
 c.professions.alch011={name='Alchemy',skill=60,max=150,at=time(),recipes={
  a={name='Minor Healing Potion',learned=true,reagents={{id=2447,qty=1},{id=765,qty=1}},output=118,difficulty='optimal'},
  b={name='Elixir of Lion\'s Strength',learned=true,reagents={{id=2449,qty=1},{id=765,qty=1}},output=2454,difficulty='optimal'}}}
 c.bags={[2447]=5,[765]=3}; c.bagsAt=time(); c.bank={[765]=10}; c.bankAt=time()
 N.db.settings.market=false; N.db.settings.manualFirst=true
 N:SetPrice(2447,.1); N:SetPrice(765,.05); N:SetPrice(2449,.2)
 N.levelCache=nil; N.levelCompare=nil
 return N.characterID,'alch011'
end
local function teardown() N.character.professions.alch011=nil; N.db.settings.market=true; N.db.settings.manualFirst=false end

test('0.11 leveling: next step says what to craft now and how many your bags allow',function()
 local cid,pid=setup()
 local plan=N:LevelingPlan(cid,pid,70,'Cheapest')
 local step=N:LevelingNextStep(plan,cid)
 assert(step and step.crafts>0); eq(step.from,60)
 local r=plan.segments[1].cand.r
 eq(step.now,N:CraftableNow(cid,r))
 eq(N:CraftableNow(cid,{reagents={{id=2447,qty=1},{id=765,qty=1}}}),3)  -- bags only: limited by 3 Silverleaf
 teardown()
end)

test('0.11 leveling: steps appear in the text plan; methods compare crafts and cost',function()
 local cid,pid=setup()
 local plan=N:LevelingPlan(cid,pid,70,'Cheapest')
 local text=N:LevelingSummary(plan)
 assert(text:find('STEPS',1,true) and text:find('MATERIALS',1,true))
 assert(text:find('STEPS',1,true)<text:find('MATERIALS',1,true))
 local rows=N:CompareLevelingModes(cid,pid,70)
 eq(#rows,#N.levelModes)
 for _,r in ipairs(rows) do assert(r.crafts>0); assert(N:LevelingModeLine(r):find(r.mode,1,true)) end
 teardown()
end)

test('0.11 leveling: missing prices make totals unknown, never free',function()
 local cid,pid=setup()
 N.prices[2449]=nil; N.prices[765]=nil
 local plan=N:LevelingPlan(cid,pid,70,'Fastest')
 assert(plan.unknown); eq(plan.cash,nil)
 local line=N:LevelingModeLine(N:CompareLevelingModes(cid,pid,70)[2])
 assert(line:find('unknown',1,true))
 teardown()
end)

test('0.11 leveling: shopping list says what to buy and what to collect from whom',function()
 local cid,pid=setup()
 local bank={name='Voidmark Bank',realm=N.character.realm,faction=N.character.faction,guid='bank-guid',account='other',imported=true,synced=true,syncedAt=time(),
  professions={},bags={[2449]=40},bank={},bagsAt=time(),bankAt=time()}
 N.db.characters['other/'..N.character.realm..'/Voidmark Bank']=bank
 local text=N:LevelingShoppingText(cid,pid,90,'Cheapest')
 assert(text:find('BUY',1,true)); assert(text:find('COLLECT',1,true))
 assert(text:find('Withdraw from your bank',1,true) or text:find('Voidmark Bank',1,true))
 N.db.characters['other/'..N.character.realm..'/Voidmark Bank']=nil
 teardown()
end)

test('0.11 leveling: Professions page highlights the current step and lists methods',function()
 local cid,pid=setup()
 N:Show('Professions'); N.ui.character,N.ui.profession=cid,pid; N.ui.profView='level'; N.ui.target:SetText('70'); N:Render()
 local first=N.ui.rows[1].data; assert(first and first.text:find('^Now:'),'current step first'); assert(first.current)
 local found=false
 for _,b in ipairs(N.ui.rows) do if b.data and b.data.text:find('Compare methods',1,true) then found=true end end
 -- The list may scroll; check the rendered row set instead.
 local all=N:RenderProfessions(N.ui); for _,r in ipairs(all) do if r.text:find('Compare methods',1,true) then found=true end end
 assert(found); eq(#N.errors,0)
 N.ui.target:SetText(''); teardown()
end)
