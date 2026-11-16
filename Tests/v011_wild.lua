local N,test,eq,widget=...
-- 0.11 Priority 5: skinning and fishing learned from play.
local function fire(event,...) for _,fn in ipairs(N.handlers[event] or {}) do fn(...) end end
local function lootOf(id,qty,source)
 GetNumLootItems=function() return 1 end
 GetLootSlotLink=function() return 'item:'..id..' [Thing]' end
 GetLootSlotInfo=function() return 'icon','Thing',qty end
 GetLootSourceInfo=source and function() return source,1 end or nil
end
local function reset() N.db.wild=nil; N.wildSession=nil; N:WildDB() end
local function at(x,y) N.Position=function() return 1411,x,y end end
local realPosition=N.Position

test('0.11 skinning: a skin records place, beast, level and leather; session counts it',function()
 reset(); at(.5,.5)
 UnitLevel=function() return 12 end
 fire('UNIT_SPELLCAST_SENT','player','Mottled Boar','skin-1',8617)
 fire('UNIT_SPELLCAST_SUCCEEDED','player','skin-1',8617)
 lootOf(2318,2,'Creature-0-1-2-3-3098-0000')
 fire('LOOT_OPENED'); fire('LOOT_SLOT_CLEARED',1); fire('LOOT_CLOSED')
 local spots=N:SkinHotspots()
 eq(#spots,1); eq(spots[1].n,1); eq(spots[1].qty,2); eq(spots[1].lo,12); eq(spots[1].names[1].n,'Mottled Boar')
 eq(N.wildSession.kind,'skin'); eq(N.wildSession.qty,2)
 eq(N.gatherSpells[8617],'leather')
 N.Position=realPosition
end)

test('0.11 skinning: loot from a non-creature after a skin cast is not counted',function()
 reset(); at(.5,.5)
 fire('UNIT_SPELLCAST_SENT','player','Mottled Boar','skin-2',8613)
 fire('UNIT_SPELLCAST_SUCCEEDED','player','skin-2',8613)
 lootOf(2318,2,'GameObject-0-1-2-3-1618-0000')
 fire('LOOT_OPENED'); fire('LOOT_SLOT_CLEARED',1); fire('LOOT_CLOSED')
 eq(#N:SkinHotspots(),0)
 N.Position=realPosition
end)

test('0.11 skinning: level limit, zones in range and the guide page',function()
 eq(N:SkinnableLevel(1),10); eq(N:SkinnableLevel(100),20); eq(N:SkinnableLevel(150),30); eq(N:SkinnableLevel(300),60)
 local zones,top=N:SkinningZones(150); eq(top,30)
 assert(#zones>0); for _,z in ipairs(zones) do assert(z.lo<=30 and z.hi>=20) end
 N.character.professions.skin011={name='Skinning',skill=150,max=225}
 local rows=N:SkinningRows(); assert(rows[1].text:find('level 30',1,true))
 local guide,info=N:GuideTabRows('skin'); assert(#guide>3 and info:find('Skinning 150',1,true))
 N.character.professions.skin011=nil
 local listed=false; for _,g in ipairs(N.GUIDE_LIST) do if g.key=='skin' then listed=true end end; assert(listed)
end)

test('0.11 fishing: a catch from a pool records the pool; open water does not; bobber ignored',function()
 reset(); at(.3,.3)
 IsFishingLoot=function() return true end
 fire('UNIT_SPELLCAST_SENT','player','','fish-1',7620)
 lootOf(6303,1,'GameObject-0-1-2-3-35591-0000')        -- the bobber: open water
 fire('LOOT_OPENED'); fire('LOOT_SLOT_CLEARED',1); fire('LOOT_CLOSED')
 eq(#N:PoolSpots(),0)
 fire('UNIT_SPELLCAST_SENT','player','','fish-2',7620)
 lootOf(6303,2,'GameObject-0-1-2-3-180655-0000')       -- some pool object
 fire('LOOT_OPENED'); fire('LOOT_SLOT_CLEARED',1); fire('LOOT_CLOSED')
 local pools=N:PoolSpots(); eq(#pools,1); eq(pools[1].e.id,180655); eq(pools[1].e.n,1)
 eq(N.wildSession.kind,'fish'); eq(N.wildSession.n,2); eq(N.wildSession.qty,3)
 assert(N.session.kinds.fish>=3,'fish count in the gathering session')
 -- Loot far from where you cast is not a catch.
 fire('UNIT_SPELLCAST_SENT','player','','fish-3',7620)
 at(.9,.9); lootOf(6303,1); fire('LOOT_OPENED'); fire('LOOT_SLOT_CLEARED',1); fire('LOOT_CLOSED')
 eq(N.wildSession.n,2)
 IsFishingLoot=nil; GetLootSourceInfo=nil; N.Position=realPosition
end)

test('0.11 fishing: named pools, pool loop, sessions with gold/hr and the guide rows',function()
 reset()
 at(.30,.30); N:Slash('pool Oily Blackmouth School')
 at(.36,.30); N:Slash('pool Oily Blackmouth School')
 at(.36,.38); N:Slash('pool Floating Wreckage')
 eq(#N:PoolSpots(1411),3); eq(N:PoolSpots(1411)[1].name:find('School',1,true)~=nil or N:PoolSpots(1411)[1].name:find('Wreckage',1,true)~=nil,true)
 at(.30,.31)
 local route=N:PoolRoute(); assert(route and route.loop and #route.points==3); eq(route.variant,'pools')
 N:StopRoute()
 N.db.settings.market=false; N:SetPrice(6303,.01)
 N:RecordCatch(1411,.3,.3,{[6303]=3})
 N.wildSession.started=N.wildSession.started-1800
 local line=N:WildSessionLine(N.wildSession); assert(line:find('/hr',1,true) and line:find('Fishing',1,true))
 N:EndWildSession(); eq(#N.db.wild.log,1)
 local rows=N:FishExtraRows(100); local found=false
 for _,r in ipairs(rows) do if r.text:find('Your fishing',1,true) then found=true end end
 assert(found); N.db.settings.market=true; N.Position=realPosition
end)

test('0.11 fishing: pool markers draw on the world map and can be hidden',function()
 reset(); N:RecordPool(1411,.4,.4,nil,'School'); N:RecordPool(1411,.5,.4,nil,'School')
 N.db.settings.nodesVisible=true; N.db.settings.mapShowPools=true
 N:RefreshMap()
 local shown=0; for _,p in ipairs(N.poolPins or {}) do if p:IsShown() then shown=shown+1 end end
 eq(shown,2)
 N:Slash('pools off'); N:RefreshMap()
 shown=0; for _,p in ipairs(N.poolPins or {}) do if p:IsShown() then shown=shown+1 end end
 eq(shown,0); N.db.settings.mapShowPools=true
end)

test('0.11 wild data: a newer saved format is left untouched',function()
 local keep=N.db.wild; N.db.wild={version=9,precious=true}; N.wildDisabled=nil
 eq(N:WildDB(),nil); eq(N.db.wild.precious,true)
 N.db.wild=keep; N.wildDisabled=nil
end)
