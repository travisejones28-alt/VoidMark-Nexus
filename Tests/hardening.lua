local N,test,eq=...
test('Partial bags and unresolved occupied slots preserve the prior inventory snapshot',function()
 local api=C_Container;local previous=N.character.bags
 N.character.bags={[2770]=12}
 C_Container={GetContainerNumSlots=function(bag) if bag==1 then return nil end return 0 end,GetContainerItemInfo=function() end}
 N:ScanStorage(false);eq(N.character.bags[2770],12)
 C_Container.GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end
 C_Container.GetContainerItemInfo=function() return {stackCount=4} end
 N:ScanStorage(false);eq(N.character.bags[2770],12)
 C_Container.GetContainerItemInfo=function() error('Bag data loading') end
 N:ScanStorage(false);eq(N.character.bags[2770],12)
 C_Container.GetContainerItemInfo=function() end
 N:ScanStorage(false);eq(next(N.character.bags),nil)
 C_Container=api;N.character.bags=previous
end)
test('Malformed optional Market records fall back without Lua errors',function()
 local old,prices=VoidMarkMarketDB,N.prices
 N.prices={[990099]=12}
 VoidMarkMarketDB={schemaVersion=1,economies={[N.economy]=17}}
 eq(N:Price(990099),nil)
 N.prices[990099]={cached=false,manual='corrupt'};eq(N:Price(990099),nil)
 VoidMarkMarketDB,N.prices=old,prices
end)
test('A partial modern schematic cannot become a zero-reagent cost calculation',function()
 local old=C_TradeSkillUI
 C_TradeSkillUI={GetRecipeInfo=function() return {name='Loading recipe',learned=true} end,
  GetRecipeSchematic=function() return {outputItemID=2} end}
 local recipe=N:ModernRecipe(123);assert(recipe.incomplete)
 local result=N:Evaluate(recipe,1,N.characterID);assert(result.unknown and result.cost==nil)
 C_TradeSkillUI=old
end)
test('Future-dated inventory is not accepted as fresh stock',function()
 local old,at,stale=N.character.bags,N.character.bagsAt,N.db.settings.includeStale
 N.character.bags={[990099]=25};N.character.bagsAt=N:Now()+86400;N.db.settings.includeStale=false
 eq(N:Stock(N.characterID)[990099],nil)
 N.character.bags,N.character.bagsAt,N.db.settings.includeStale=old,at,stale
end)
test('Disabling guidance hides a paused HUD without reintroducing a title or hover help',function()
 local old,paused,visible=N.activeRoute,N.routePaused,N.db.settings.routeVisible
 N.activeRoute={map=1411,width=5000,height=3000,points={{x=.4,y=.4}}}
 N.routePaused=true;N.db.settings.routeVisible=false;N.arrow:Show();N:UpdateArrow()
 assert(not N.arrow:IsShown());eq(N.arrow.scripts.OnEnter,nil)
 N.activeRoute,N.routePaused,N.db.settings.routeVisible=old,paused,visible
end)
test('Passing a transit point advances without skipping the unvisited gathering stop',function()
 local position=N.Position
 N.Position=function() return 1411,.415,.4 end
 N.activeRoute={map=1411,width=5000,height=3000,speed=14,origin={x=.4,y=.4},points={{x=.42,y=.4}},
  travelPoints={{x=.41,y=.4,transit=true},{x=.42,y=.4}},travelStopIndices={2}}
 N.waypoint=1;N.terrainIndex=1;N.routePaused=false;N.db.settings.routeVisible=true
 N:UpdateArrow();eq(N.terrainIndex,2);eq(N.waypoint,1)
 N:UpdateArrow();eq(N.waypoint,1)
 N.Position=position;N.activeRoute=nil
end)
test('Reload repairs inconsistent geometry progress without rewinding visited gathering stops',function()
 local id=N.characterID
 local route={map=1411,width=5000,height=3000,origin={x=.3,y=.4},points={{x=.4,y=.4},{x=.5,y=.4}},
  travelPoints={{x=.3,y=.4,transit=true},{x=.4,y=.4},{x=.45,y=.4,transit=true},{x=.5,y=.4}},travelStopIndices={2,4}}
 N.db.navigation[id]={version=1,route=route,waypoint=2,terrainIndex=1,paused=true}
 N:RestoreNavigation();eq(N.waypoint,2);eq(N.terrainIndex,3);assert(N.routePaused)
 N.activeRoute=nil;N:SaveNavigation()
end)
test('Explicit rejoin stays forward and cannot jump over an unvisited gathering stop',function()
 local position=N.Position;N.Position=function() return 1411,.88,.4 end
 N.activeRoute={map=1411,width=5000,height=3000,origin={x=.3,y=.4},points={{x=.3,y=.4},{x=.5,y=.4},{x=.9,y=.4}},
  travelPoints={{x=.3,y=.4},{x=.4,y=.4,transit=true},{x=.5,y=.4},{x=.9,y=.4}},travelStopIndices={1,3,4}}
 N.waypoint=2;N.terrainIndex=2;N.routePaused=true
 N:RejoinRoute();eq(N.terrainIndex,3);eq(N.waypoint,2);assert(not N.routePaused)
 N.activeRoute=nil;N.Position=position
end)
test('HUD compass bearings agree with all four cardinal directions',function()
 local position=N.Position;N.Position=function() return 1411,.4,.4 end
 local cases={{.4,.3,0},{.5,.4,-math.pi/2},{.4,.5,math.pi},{.3,.4,math.pi/2}}
 for _,c in ipairs(cases) do
  N.activeRoute={map=1411,width=5000,height=3000,speed=10,points={{x=c[1],y=c[2]}}}
  N.waypoint=1;N.routePaused=false;N:UpdateArrow()
  local diff=(N.arrow.bearing-c[3]+math.pi)%(2*math.pi)-math.pi
  assert(math.abs(diff)<.00001)
 end
 N.activeRoute=nil;N.Position=position
end)
test('Closing gathering loot clears the cast correlation before another loot window',function()
 local total=N.session.total
 N.handlers.UNIT_SPELLCAST_SENT[1]('player','Copper Vein','hardening-cast',2575)
 N.handlers.UNIT_SPELLCAST_SUCCEEDED[1]('player','hardening-cast',2575)
 N.lootGather=N.gatherCast
 N.handlers.LOOT_CLOSED[1]();eq(N.gatherCast,nil);eq(N.session.total,total)
end)

test('Repeated trail sample counts alone do not discard reusable routing work',function()
 local terrain=N.db.terrain.zones[1411]
 N.db.terrain.zones[1411]={points={{x=.1,y=.1},{x=.2,y=.2}},edges={[1]={[2]={distance=20,seconds=2,speed=10,mode='ground',samples=1}}}}
 local before=N:PlannerCacheKey(N:RoutingTerrain(1411))
 N.db.terrain.zones[1411].edges[1][2].samples=50
 eq(N:PlannerCacheKey(N:RoutingTerrain(1411)),before)
 N.db.terrain.zones[1411].edges[1][2].seconds=3
 assert(N:PlannerCacheKey(N:RoutingTerrain(1411))~=before)
 N.db.terrain.zones[1411]=terrain
end)

test('Restricted API returns become unknown without losing later public values',function()
 local old=issecretvalue;local secret={}
 issecretvalue=function(value) return value==secret end
 local a,b,c=N:Call(function() return nil,secret,4 end)
 eq(a,nil);eq(b,nil);eq(c,4)
 issecretvalue=old
end)
test('Malformed schematic slots and output ranges remain incomplete estimates',function()
 local old=C_TradeSkillUI
 C_TradeSkillUI={GetRecipeInfo=function() return {name='Partial',learned=true} end,
  GetRecipeSchematic=function() return {quantityMin=3,quantityMax=1,reagentSlotSchematics={false,{quantityRequired='loading'}}} end}
 local recipe=N:ModernRecipe(1);assert(recipe.incomplete)
 assert(N:Evaluate(recipe,1,N.characterID).cost==nil)
 C_TradeSkillUI=old
end)
