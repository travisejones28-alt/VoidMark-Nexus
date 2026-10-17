local source=debug.getinfo(1,'S').source:sub(2):gsub('\\','/')
local root=source:match('^(.*)/Tests/run.lua$') or '.'
local now=1000000
function time() return now end
function GetTime() return now end
function GetNormalizedRealmName() return 'TestRealm' end
function GetRealmName() return 'Test Realm' end
local player='Priest'
function UnitName() return player end
function UnitFactionGroup() return 'Horde' end
function UnitGUID() return 'GUID-'..player end
function GetBuildInfo() return '1.60.1','test','date',16001 end
function InCombatLockdown() return false end
function GetItemInfo(id) return 'Item '..tostring(id) end
function GetItemIcon() return 'icon' end
function GetPlayerFacing() return 0 end
SlashCmdList={}; UISpecialFrames={}
local messages={}; DEFAULT_CHAT_FRAME={AddMessage=function(_,s) messages[#messages+1]=s end}
local function widget()
 local w={shown=true,text='',scripts={}}
 local methods={SetText=function(self,t) self.text=t end,GetText=function(self) return self.text end,
  Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,IsShown=function(self) return self.shown end,
  SetShown=function(self,v) self.shown=v end,SetScript=function(self,k,fn) self.scripts[k]=fn end,
  GetWidth=function() return 1000 end,GetHeight=function() return 600 end,GetStringHeight=function() return 500 end,
  GetCenter=function() return 500,300 end,GetMapID=function() return 1411 end,
  GetFrameLevel=function(self) return self.level or 1 end,SetFrameLevel=function(self,v) self.level=v end,
  GetParent=function(self) return self.parent end,SetParent=function(self,v) self.parent=v end,
  SetFrameStrata=function(self,v) self.strata=v end,
  CreateTexture=function() return widget() end,CreateFontString=function() return widget() end}
 return setmetatable(w,{__index=function(_,k) return methods[k] or (k:match('^[A-Z]') and function() end or nil) end})
end
function CreateFrame(_,_,parent) local w=widget();w.parent=parent;return w end
UIParent=widget(); Minimap=widget(); GameTooltip=widget()
local timers={}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end,NewTicker=function() end}
local function flush() local rounds=0; while #timers>0 do rounds=rounds+1; assert(rounds<100000,'timer recursion'); local fn=table.remove(timers,1); fn() end end
C_Map={GetBestMapForUnit=function() return 1411 end,GetPlayerMapPosition=function() return {GetXY=function() return .4,.4 end} end,GetMapWorldSize=function() return 5000,3000 end}
local N={}
local files={'Core','Data/Nodes','Data/Spawns','Model','Transfer','Professions','Inventory','Prices','Gathering','Analytics','Planner','Terrain','Routes','MinimapRoute','UI','Boot'}
for _,f in ipairs(files) do assert(loadfile(root..'/VoidMarkNexus/'..f..'.lua'))('VoidMarkNexus',N) end
local results={}; local count=0
local function test(name,fn)
 local ok,err=pcall(fn); results[#results+1]=(ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)); print(results[#results]); if not ok then error(err) end; count=count+1
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
test('All TOC Lua files compile and load under Lua 5.1 compatible runtime',function() eq(N.version,'0.2.8-alpha') end)
test('Initialize and retain existing characters',function()
 assert(N:Initialize()); local account=N.db.account; N.character.custom='retained'; assert(N:Initialize()); eq(N.db.account,account); eq(N.character.custom,'retained')
end)
local firstID=N.characterID
local function recipe() return {name='Potion',learned=true,reagents={{id=1,qty=2}},output=2,outputMin=1,outputMax=1,difficulty='optimal',at=now} end
test('Profession separation and offline search',function()
 N.character.professions.alchemy={name='Alchemy',skill=100,max=150,recipes={potion=recipe()},at=now}
 player='Rogue'; N:Initialize(); N.character.professions.engineering={name='Engineering',skill=75,max=150,recipes={},at=now}
 eq(#N:Search('Potion',N.characterID),0); eq(#N:Search('Potion',firstID),1); eq(#N:Search('Potion'),1)
 player='Priest'; N:Initialize()
end)
local r=recipe()
test('Known stock, economic profit and missing cash are separate',function()
 N.character.bags={[1]=3}; N.character.bagsAt=now; N:SetPrice(1,.01); N:SetPrice(2,.1)
 local e=N:Evaluate(r,2,firstID); eq(e.buyAll,400); eq(e.buyMissing,100); eq(e.owned,300); eq(e.economic,1500); eq(e.cashProfit,1800)
end)
test('Unknown price never becomes free',function()
 local other=recipe(); other.reagents[1].id=999; local e=N:Evaluate(other,1,firstID); eq(e.cost,nil); eq(e.economic,nil); assert(e.unknown)
end)
test('No double allocation across planned crafts',function()
 N.db.plans={}; local ref={character=firstID,profession='alchemy',recipe='potion'}; N:AddPlan(ref,1); N:AddPlan(ref,1)
 local rows=N:Shopping(); eq(rows[1].missing,0); eq(rows[2].missing,1)
end)
test('Stale inventory excluded unless opted in; bank separate',function()
 N.character.bagsAt=1; eq(N:Evaluate(r,1,firstID).rows[1].missing,2)
 N.db.settings.includeStale=true; eq(N:Evaluate(r,1,firstID).rows[1].missing,0); N.db.settings.includeStale=false; N.character.bagsAt=now
 N.character.bank={[1]=5}; N.character.bankAt=now; eq(N:Evaluate(r,4,firstID).rows[1].missing,0)
 N.db.settings.includeBanks=false; eq(N:Evaluate(r,4,firstID).rows[1].missing,5); N.db.settings.includeBanks=true
end)
test('Physical-character duplicates and foreign realms excluded',function()
 local dup=N:Copy(N.character); dup.bags={[1]=100}; N.db.characters.duplicate=dup
 eq(N:Evaluate(r,5,firstID).rows[1].missing,2); N.db.characters.duplicate=nil
 dup.guid='other'; dup.realm='Other'; N.db.characters.foreign=dup; eq(N:Evaluate(r,5,firstID).rows[1].missing,2); N.db.characters.foreign=nil
end)
test('Cross-account serialization preserves delimiters and previews before changes',function()
 local raw=N:Export(); local decoded=N:Decode(raw); eq(decoded.schema,1)
 local old=VoidMarkNexusDB; VoidMarkNexusDB={account='second'}; player='Bank'; N:Initialize()
 local preview,err=N:PreviewImport(raw); assert(preview,err); eq(N.db.characters[firstID],nil); N:ConfirmImport(); assert(N.db.characters[firstID].imported)
 local before=N.db.characters[firstID]; N:PreviewImport(raw); N:ConfirmImport(); eq(N.db.characters[firstID],before)
 VoidMarkNexusDB=old; player='Priest'; N:Initialize()
end)
test('Malformed, executable, duplicate-key, huge and unsupported imports rejected',function()
 for _,raw in ipairs({'return os.execute("bad")','VMN2:{}','VMN1:{','VMN1:{s1:at s1:af}','VMN1:s999999999:x','VMN1:{}garbage'}) do assert(not pcall(N.Decode,N,raw)) end
 local raw=N:Export(); assert(not N:PreviewImport(raw))
end)
test('Read-only Market adapter preserves age and respects economy/schema',function()
 VoidMarkMarketDB={schemaVersion=1,economies={[N.economy]={market={[1]={fairValue=250,lastSeen=now-100,latest={median=300},itemSuffix=0}}}}}
 local p=N:Price(1); eq(p.unit,250); eq(p.at,now-100); eq(p.source,'VoidMark Market')
 VoidMarkMarketDB.schemaVersion=2; eq(N:Price(1).source,'Nexus cache'); VoidMarkMarketDB=nil
 N.db.settings.manualFirst=true; eq(N:Price(1).unit,100); N.db.settings.manualFirst=false
end)
test('Deposits, sale fraction and variable output',function()
 N.db.settings.manualFirst=true; N.db.settings.deposit=50; N.db.settings.failedAuctions=2; N.db.settings.saleFraction=.5
 local e=N:Evaluate(r,2,firstID); eq(e.depositCash,100); eq(e.depositLoss,200); eq(e.net,750); eq(e.economic,350)
 N.db.settings.deposit=0; N.db.settings.failedAuctions=0; N.db.settings.saleFraction=1
end)
test('Bounded route, distinct waypoints, budget, mount mode',function()
 local points={}; for i=1,40 do points[i]={x=i/100,y=.1,object=i,name='Node'} end
 local s=N:Copy(N.db.settings); s.routeMinutes=2; s.speed=7; s.mountDelay=0
 local route=N:BuildRoute(points,{x=0,y=.1,map=1411},5000,3000,s); assert(route.seconds<=120); assert(#route.points>0)
 local seen={}; for _,p in ipairs(route.points) do assert(not seen[p.object]); seen[p.object]=true end
 s.speed=14; local faster=N:BuildRoute(points,{x=0,y=.1,map=1411},5000,3000,s); assert(#faster.points>=#route.points)
 eq(N:BuildRoute(points,{},nil,nil,s),nil)
end)
test('Forever node database and observed deduplication',function()
 local nodes=N:ZoneNodes(1411); assert(#nodes>20)
 N:LearnNode(1731,1411,.2,.3); N:LearnNode(1731,1411,.2,.3); local n=0; for _ in pairs(N.db.nodes[1411]) do n=n+1 end; eq(n,1)
 N.db.settings.kind='herb'; for _,p in ipairs(N:ZoneNodes(1411)) do eq(p.kind,'herb') end; N.db.settings.kind='all'
end)
test('Leveling recommendations omit unpriced and gray recipes',function()
 local ranked=N:Leveling(firstID,'alchemy',105,'Gold'); eq(#ranked,1); eq(ranked[1].qty,5)
 N.character.professions.alchemy.recipes.potion.difficulty='trivial'; eq(#N:Leveling(firstID,'alchemy',105),0)
 N.character.professions.alchemy.recipes.potion.difficulty='optimal'
end)
test('Modern profession scan and linked-view protection',function()
 C_TradeSkillUI={GetAllRecipeIDs=function() return {123} end,GetBaseProfessionInfo=function() return {professionID=171,professionName='Alchemy',skillLevel=100,maxSkillLevel=150} end,
 GetRecipeInfo=function() return {name='New Potion',learned=true,relativeDifficulty=1} end,
 GetRecipeSchematic=function() return {outputItemID=2,quantityMin=1,quantityMax=2,reagentSlotSchematics={{quantityRequired=2,reagents={{itemID=1}}}}} end}
 N:ScanRecipes(); flush(); eq(N.character.professions['171'].recipes['123'].name,'New Potion')
 C_TradeSkillUI.IsTradeSkillLinked=function() return true end; assert(not N:OwnProfession()); C_TradeSkillUI.IsTradeSkillLinked=nil
end)
test('Bag and bank scanning use distinct containers',function()
 C_Container={GetContainerNumSlots=function(bag) return (bag==0 or bag==-1) and 1 or 0 end,
 GetContainerItemInfo=function(bag) return {itemID=1,stackCount=bag==0 and 4 or 9,hyperlink='item:1 [Material]'} end}
 N:ScanStorage(false); eq(N.character.bags[1],4); N.bankOpen=true; N:ScanStorage(true); eq(N.character.bank[1],9); eq(N.character.bags[1],4)
end)
test('Gather loot counted once only after matched gathering success',function()
 N:StartSession(); N.handlers.UNIT_SPELLCAST_SENT[1]('player','Copper Vein','cast-1',2575)
 N.handlers.UNIT_SPELLCAST_SUCCEEDED[1]('player','cast-1',2575)
 function GetNumLootItems() return 1 end
 function GetLootSlotLink() return 'item:2770 [Copper Ore]' end
 function GetLootSlotInfo() return 'icon','Copper Ore',3 end
 N.handlers.LOOT_OPENED[1](); N.handlers.LOOT_SLOT_CLEARED[1](1); N.handlers.LOOT_SLOT_CLEARED[1](1); eq(N.session.total,3)
 N.handlers.LOOT_CLOSED[1](); N.handlers.LOOT_OPENED[1](); N.handlers.LOOT_SLOT_CLEARED[1](1); eq(N.session.total,3)
end)
test('UI construction and every page render against frame mocks',function()
 for _,tab in ipairs({'Dashboard','Professions','Recipes','Crafting','Profitability','Gathering','Routes','Inventory','Characters','Settings'}) do N:Show(tab); N:Render() end
 N:TextDialog('Export',N:Export()); N:TextDialog('Import','',true); N:MinimapButton(); N:ShowArrow(); N:UpdateArrow()
 eq(#N.errors,0)
end)
test('Nil slots in multi-return APIs preserve later professions',function()
 local a,b,c,d=N:Call(function() return nil,22,nil,44 end); eq(a,nil); eq(b,22); eq(c,nil); eq(d,44)
 GetProfessions=function() return nil,2,nil,4 end
 GetProfessionInfo=function(i) return 'Profession '..i,'icon',10,75,nil,nil,100+i end
 N:ScanProfessions(); assert(N.character.professions['102']); assert(N.character.professions['104'])
end)
test('Forever difficulty enum starts at zero; gray never recommended',function()
 N.character.professions.alchemy.recipes.potion.difficulty=0; eq(N:Leveling(firstID,'alchemy',101)[1].qty,1)
 N.character.professions.alchemy.recipes.potion.difficulty=3; eq(#N:Leveling(firstID,'alchemy',101),0)
 N.character.professions.alchemy.recipes.potion.difficulty='optimal'
end)
test('Offline crafting never calls a game action',function()
 local called=false; C_TradeSkillUI.CraftRecipe=function() called=true end
 N:Craft({character='other',profession='171',recipe='123'},1); assert(not called)
end)
test('Import rejects invalid quantity and sanitizes unknown fields',function()
 local c=N:Copy(N.character); c.bags[1]=-1; assert(not pcall(N.ValidateCharacter,N,c))
 c=N:Copy(N.character); c.professions.alchemy.recipes.potion.icon={malicious=true}
 local clean=N:CleanImported(c); eq(clean.professions.alchemy.recipes.potion.icon,nil); eq(clean.custom,nil)
end)
test('Malformed saved settings are repaired without losing characters',function()
 N.db.settings.speed=0/0; N.db.settings.cut=9; N.db.settings.position={'bad',nil}; N:Initialize()
 eq(N.db.settings.speed,7); eq(N.db.settings.cut,.05); eq(N.db.settings.position,nil); assert(N.character.professions.alchemy)
end)
test('Missing storage data preserves the previous snapshot',function()
 local old=N.character.bank; C_Container.GetContainerNumSlots=function() return nil end
 N.bankOpen=true; N:ScanStorage(true); eq(N.character.bank,old)
end)
test('All three primary UI actions are bound to their own handler',function()
 N:Show('Dashboard'); local called={}; N:SetActions({'A','B','C'},{function() called[1]=true end,function() called[2]=true end,function() called[3]=true end})
 for _,b in ipairs(N.ui.actions) do b.scripts.OnClick() end
 assert(called[1] and called[2] and called[3])
end)
test('Arrow update and map pin creation',function()
 N.activeRoute={map=1411,width=5000,height=3000,points={{x=.5,y=.5,name='Node'}}}; N.waypoint=1; N:ShowArrow(); N:UpdateArrow()
 assert(N.arrow.label.text:find('yd',1,true)); WorldMapFrame=widget(); local canvas=widget(); WorldMapFrame.GetCanvas=function() return canvas end; N:RefreshMap(); assert(#N.mapPins>0)
end)
test('Market navigation opens its existing view without hiding it',function()
 local opened
 VoidMarkMarket={db={settings={}},ToggleUI=function() error('must not toggle a visible market') end,SetView=function(_,view) opened=view end,RefreshUI=function() end}
 N:OpenMarket(1); eq(opened,'opportunities'); VoidMarkMarket=nil
end)
test('Newer database schema remains untouched',function()
 local original=VoidMarkNexusDB; VoidMarkNexusDB={schema=99,valuable='preserve'}; assert(not N:Initialize()); eq(VoidMarkNexusDB.valuable,'preserve'); eq(VoidMarkNexusDB.schema,99); VoidMarkNexusDB=original
end)
test('Terrain migration sanitizes corrupt graphs and preserves newer versions',function()
 N.db.terrain={version=1,zones={[1411]={points={{x=.1,y=.1},{x=.11,y=.1},{x='bad'}},edges={[1]={[2]={distance=10,seconds=1,speed=10,mode='ground',samples=2},[3]={}}}}}}
 N:InitializeTerrain();eq(#N.db.terrain.zones[1411].points,2);eq(N.db.terrain.zones[1411].edgeCount,1)
 local future={version=99,zones={}};N.db.terrain=future;N:InitializeTerrain();eq(N.db.terrain,future);assert(N.terrainDisabled)
 N.db.terrain=nil;N:InitializeTerrain()
end)
test('Only actual directed movement creates trail edges; discontinuities rejected',function()
 N.db.terrain.zones={};N.trailPrevious=nil
 N:RecordTraversal(1411,.1,.1,100,'ground',14)
 N:RecordTraversal(1411,.102,.1,101,'ground',14)
 local z=N:TerrainZone(1411);eq(z.edgeCount,1);assert(not z.edges[2] or not z.edges[2][1])
 N:RecordTraversal(1411,.8,.8,102,'ground',14);eq(z.edgeCount,1)
 N:RecordTraversal(1411,.802,.8,110,'ground',14);eq(z.edgeCount,1)
 N:RecordTraversal(1412,.804,.8,111,'ground',14);eq(z.edgeCount,1)
 N:RecordTraversal(1412,.806,.8,112,'swim',14);eq(z.edgeCount,1)
end)
test('Directed learned path uses measured time and selected speed',function()
 N.db.terrain.zones={};N.trailPrevious=nil
 for i=0,8 do N:RecordTraversal(1411,.1+i*.002,.1,200+i,'ground',14) end
 local a,b={x=.1,y=.1},{x=.116,y=.1}
 local d,via,info=N:LearnedTerrainLeg(a,b,5000,3000,1411,7)
 assert(d and #via>=8);assert(info.seconds>=16);assert(info.validatedDistance>70)
 local _,_,fast=N:LearnedTerrainLeg(a,b,5000,3000,1411,14);assert(fast.seconds<info.seconds)
 eq(N:LearnedTerrainLeg(b,a,5000,3000,1411,7),nil)
end)
test('Manual obstacles generate clear detours and reject unreachable endpoints',function()
 N.db.terrain.zones={};N.db.terrainBlocks={[1411]={{x=.5,y=.5,r=100}}}
 local a,b={x=.3,y=.5},{x=.7,y=.5}
 local d,via=N:TerrainLeg(a,b,1000,1000,1411)
 assert(d>400 and d<1000 and #via>0)
 local prev=a;for _,p in ipairs(via) do assert(not N:TerrainIntersects(prev,p,1000,1000,1411));prev=p end
 assert(not N:TerrainIntersects(prev,b,1000,1000,1411))
 eq(N:TerrainLeg(a,{x=.5,y=.5},1000,1000,1411),math.huge)
 N.db.terrainBlocks={}
end)
test('Prepared geometry includes closing detours and exact loop duration',function()
 N.db.terrainBlocks={[1411]={{x=.5,y=.5,r=100}}}
 local r={map=1411,width=1000,height=1000,origin={x=.3,y=.5},points={{x=.7,y=.5}},speed=10,gatherDelay=3,mountDelay=0}
 N:PrepareTerrainRoute(r);assert(#r.travelPoints>3);assert(r.travelPoints[#r.travelPoints].closing)
 local length=0;local prev=r.origin
 for _,p in ipairs(r.travelPoints) do length=length+N:Distance(prev,p,1000,1000);prev=p end
 assert(math.abs(r.seconds-(length/10+3))<.001)
 N.db.terrainBlocks={}
end)
test('Corrupt and duplicate nodes cannot inflate route coverage',function()
 local settings=N:Copy(N.db.settings);settings.routeMinutes=1
 local nodes={{x=.11,y=.1,object=1},{x=.11,y=.1,object=1},{x=0/0,y=.2},{x='bad',y=.3},{x=.2}}
 local r=N:BuildRoute(nodes,{map=1411,x=.1,y=.1},1000,1000,settings)
 eq(#r.points,1);assert(r.seconds<=60)
 local empty=N:BuildRoute({},{map=1411,x=.1,y=.1},1000,1000,settings);eq(#empty.points,0)
end)
test('Terrain-aware route budgets include detours and closing leg',function()
 N.db.terrainBlocks={[1411]={{x=.5,y=.5,r=100}}}
 local s=N:Copy(N.db.settings);s.speed=7;s.routeMinutes=1
 local r=N:BuildRoute({{x=.7,y=.5,object=1},{x=.3,y=.7,object=2}},{map=1411,x=.3,y=.5},1000,1000,s)
 assert(r.seconds<=60);assert(not r.unreachable)
 N.db.terrainBlocks={}
end)
test('Two-opt and candidate selection keep compact circuit within budget',function()
 local s=N:Copy(N.db.settings);s.routeMinutes=20;s.speed=7
 local p={{x=.1,y=.1,object=1},{x=.9,y=.9,object=2},{x=.1,y=.9,object=3},{x=.9,y=.1,object=4}}
 local r=N:BuildRoute(p,{x=.1,y=.1,map=1411},1000,1000,s)
 assert(#r.points==4);assert(r.length<=3200.001);assert(r.seconds<=1200)
end)
test('Manual stop confirmation, detour progression, pause and restart',function()
 N.db.settings.manualStops=true
 local r={map=1411,width=5000,height=3000,origin={x=.4,y=.4},points={{x=.4,y=.4,name='Node',object=1}}}
 N:PrepareTerrainRoute(r);N.activeRoute=r;N.waypoint=1;N.terrainIndex=1;N.routePaused=false;N:ShowArrow();N:UpdateArrow();eq(N.waypoint,1)
 N:SkipWaypoint();eq(N.waypoint,2);assert(N.activeRoute)
 N.routePaused=true;N:UpdateArrow();assert(N.activeRoute)
 N:Slash('restart');eq(N.waypoint,1);eq(N.terrainIndex,1);assert(not N.routePaused)
 N:SkipWaypoint();N:UpdateArrow();eq(N.activeRoute,nil)
 N.db.settings.manualStops=false
end)
test('Harvest-only evidence never invents availability; explicit checks enable estimates',function()
 N.db.gatherEvidence={};local p={object=1617,x=.4,y=.4};local r={map=1411,points={p},seconds=60}
 local e=N:GatherEvidence(1411,p,true);e.harvests=3;e.qty=6
 N:ScoreRouteEvidence(r);eq(r.expectedResourcesPerHour,nil)
 e.checks=10;e.available=5;N:ScoreRouteEvidence(r);eq(r.expectedResourcesPerHour,60)
end)
test('Cross-zone ranking uses in-zone efficiency, not spawn count',function()
 local spawns,types,observed=N.spawns,N.nodeTypes,N.db.nodes
 local minutes=N.db.settings.routeMinutes;N.db.settings.routeMinutes=120
 N.nodeTypes={[1]={name='Test Herb',kind='herb'}}
 N.spawns={[1]={[2001]={.1,.1,.15,.1,.15,.15,.1,.15},[2002]={.1,.1,.8,.1,.8,.8,.1,.8}}};N.db.nodes={}
 local ranked=N:RankResourceZones('Test Herb');eq(#ranked,2);eq(ranked[1].map,2001);eq(ranked[1].metric,'potential stops')
 assert(#ranked[1].alternatives>0)
 N.spawns,N.nodeTypes,N.db.nodes=spawns,types,observed
 N.db.settings.routeMinutes=minutes
end)
test('Planner yields, completes and rejects combat without executing work',function()
 local done=false
 N:RunPlanner(function() for i=1,7501 do N:PlannerCheckpoint() end;return 42 end,function(v) eq(v,42);done=true end)
 assert(not done);flush();assert(done);eq(N.planningThread,nil)
 InCombatLockdown=function() return true end
 N:RunPlanner(function() error('combat work') end,function() error('combat completion') end)
 eq(N.planningThread,nil);InCombatLockdown=function() return false end
end)
test('World-map layering retains high-strata pins and exact detour geometry',function()
 local r={map=1411,width=5000,height=3000,origin={x=.3,y=.3},points={{x=.5,y=.5,name='Node'}}}
 N:PrepareTerrainRoute(r);N.activeRoute=r;N.waypoint=1;N.terrainIndex=1;N:RefreshMap()
 eq(N.mapPinOverlay.strata,'HIGH');assert(N.mapPinOverlay.level>=121)
 eq(N.mapPins[1].parent,N.mapPinOverlay);assert(N.mapPins[1].level>N.mapPinOverlay.level)
 N:ShowRoutePreview('here','diagram',r);assert(N.previewWindow)
 N:ShowRoutePreview('here','map',r);assert(N.previewWindow)
end)
test('Empty readable containers clear stale stock; unavailable API preserves it',function()
 C_Container.GetContainerNumSlots=function() return 0 end;N.character.bags={[1]=99};N:ScanStorage(false);eq(next(N.character.bags),nil)
 local old=N.character.bags;C_Container.GetContainerNumSlots=function() return nil end;N:ScanStorage(false);eq(N.character.bags,old)
end)
test('A different loot source after gathering is not counted',function()
 N:StartSession();N.handlers.UNIT_SPELLCAST_SENT[1]('player','Copper Vein','cast-x',2575)
 N.handlers.UNIT_SPELLCAST_SUCCEEDED[1]('player','cast-x',2575)
 GetLootSourceInfo=function() return 'Creature-0-1-1-1-123-000000',1 end
 N.handlers.LOOT_OPENED[1]();N.handlers.LOOT_SLOT_CLEARED[1](1);eq(N.session.total,0)
 GetLootSourceInfo=nil
end)
test('Route performance measures active time and excludes pause',function()
 N:StartSession();N.activeRoute={map=1411,mode='Foot',points={{x=.4,y=.4,object=1}}};N.routePaused=false;N.routeSessionAt=now-1
 N:TrackRouteSession();local id=N:RouteIdentity(N.activeRoute);eq(N.session.routePerformance[id].seconds,1)
 N.routePaused=true;now=now+1;N:TrackRouteSession();eq(N.session.routePerformance[id].seconds,1);N.routePaused=false
end)
test('Graph storage bounds reject additional samples without deleting history',function()
 local z={points={},edges={},edgeCount=0,revision=0}
 for i=1,600 do z.points[i]={x=.01,y=i/10000} end
 N.db.terrain.zones[1411]=z;N.trailPrevious=nil
 N:RecordTraversal(1411,.5,.5,500,'ground',14);N:RecordTraversal(1411,.502,.5,501,'ground',14)
 eq(#z.points,600);eq(z.edgeCount,0)
end)
test('Real imported-zone planning completes through the incremental queue',function()
 N.db.terrainBlocks={};N.db.terrain.zones={};N.db.settings.target='';N.db.settings.kind='all'
 local started=os.clock();local route
 N:RunPlanner(function() return N:PlanRoute('here') end,function(r) route=r end);flush()
 assert(route and #route.points>0);assert(route.seconds<=N.db.settings.routeMinutes*60+.01)
 print(string.format('BENCH imported-zone start-here: %.3f CPU sec, %d stops',os.clock()-started,#route.points))
end)

test('Exact-input route cache avoids rebuilding and invalidates on relevant changes',function()
 local position,nodes,build=N.Position,N.ZoneNodes,N.BuildRoute
 local calls=0;local x=.4;local list={{x=.4,y=.4,object=1},{x=.41,y=.4,object=1},{x=.41,y=.41,object=1}}
 N.plannerCache={};N.db.terrain.zones={};N.db.terrainBlocks={};N.db.gatherEvidence={}
 N.Position=function() return 1411,x,.4 end
 N.ZoneNodes=function() return list end
 N.BuildRoute=function(_,_,start)
  calls=calls+1
  return {points=N:Copy(list),origin=start,map=1411,seconds=600,potentialStopsPerHour=18}
 end
 local first=N:PlanRoute('here');eq(calls,1)
 first.points[1].x=.99
 local again=N:PlanRoute('here');eq(calls,1);eq(again.points[1].x,.4)
 N.db.settings.speed=N.db.settings.speed+1;N:PlanRoute('here');eq(calls,2)
 x=.401;N:PlanRoute('here');eq(calls,3)
 N.db.terrainBlocks[1411]={{x=.8,y=.8,r=30}};N:PlanRoute('here');eq(calls,4)
 N.db.gatherEvidence[1411]={sample={checks=5}};N:PlanRoute('here');eq(calls,5)
 list[1].x=.402;N:PlanRoute('here');eq(calls,6)
 N.db.terrain.zones[1411]={revision=1,points={},edges={}};N:PlanRoute('here');eq(calls,7)
 now=now+121;N:PlanRoute('here');eq(calls,8)
 assert(#N.plannerCache<=6)
 N.Position,N.ZoneNodes,N.BuildRoute=position,nodes,build
 N.db.settings.speed=N.db.settings.speed-1
end)

test('Progress, approximate ETA, cancel, timeout and old queued callbacks',function()
 local result
 N:RunPlanner(function()
  N:SetPlannerProgress('Comparing starts',1,4)
  for i=1,5001 do N:PlannerCheckpoint() end
  return 'old'
 end,function(v) result=v end)
 assert(N.planningThread and N.plannerWindow:IsShown())
 now=now+2
 assert(N:PlannerStatus():find('1 / 4',1,true) and N:PlannerStatus():find('left',1,true))
 N:CancelPlanner();assert(not N.plannerWindow:IsShown());flush();eq(result,nil)
 N:RunPlanner(function()
  N.planningJob.best={points={{x=.4,y=.4}},strategy='here'}
  for i=1,5001 do N:PlannerCheckpoint() end
 end,function(v) result=v end)
 now=now+31;flush();assert(result and result.strategy=='here');eq(N.planningThread,nil)
 assert(not N.plannerWindow:IsShown())
 N:RunPlanner(function() return 7 end,function(v) result=v end);eq(result,7)
end)

test('Minimap clipping covers crossing, offscreen and circular legs',function()
 local ax,ay,bx,by=N:ClipMinimapLeg(-2,.5,2,.5,true)
 eq(ax,-1);eq(bx,1);eq(ay,.5);eq(by,.5)
 eq(N:ClipMinimapLeg(-2,2,2,2,true),nil)
 ax,ay,bx,by=N:ClipMinimapLeg(-2,0,2,0,false);eq(ax,-1);eq(bx,1)
 eq(N:ClipMinimapLeg(-2,1.1,2,1.1,false),nil)
end)

test('Thin minimap lines track zoom, rotation, detours, visibility and fallback',function()
 local oldPosition,oldMinimap=N.Position,Minimap
 local oldC,oldBool,oldFacing=C_Minimap,GetCVarBool,GetPlayerFacing
 local oldShape=GetMinimapShape
 local radius=100;local rotate=false
 C_Minimap={GetViewRadius=function() return radius end}
 GetCVarBool=function() return rotate end
 GetPlayerFacing=function() return math.pi/2 end
 GetMinimapShape=function() return 'SQUARE' end
 Minimap=widget();Minimap.GetWidth=function() return 200 end;Minimap.GetHeight=function() return 200 end
 Minimap.GetEffectiveScale=function() return 1 end
 N.Position=function() return 1411,.4,.4 end
 N.db.settings.routeVisible=true;N.db.settings.minimapRoute=true
 N.activeRoute={map=1411,origin={x=.39,y=.4},points={{x=.41,y=.4}},
  travelPoints={{x=.39,y=.4},{x=.4,y=.39,validated=true},{x=.41,y=.4}}}
 N.terrainIndex=1;N.minimapRouteOverlay=widget();N.minimapRouteLines={};N.minimapRouteDots={}
 N.minimapLineUnavailable=nil
 N.minimapRouteOverlay.CreateLine=function()
  local line=widget()
  line.SetStartPoint=function(self,anchor,parent,x,y,...)
   eq(select('#',...),0);eq(type(x),'number');eq(type(y),'number');self.ax,self.ay=x,y
  end
  line.SetEndPoint=function(self,anchor,parent,x,y,...) eq(select('#',...),0);self.bx,self.by=x,y end
  line.SetThickness=function(self,n) self.thickness=n end
  return line
 end
 N:UpdateMinimapRoute();local line=N.minimapRouteLines[1]
 assert(line and line:IsShown());eq(line.thickness,1.5)
 local before=line.by;assert(before>0)
 radius=200;N:UpdateMinimapRoute();assert(math.abs(line.by-before/2)<.001)
 rotate=true;N:UpdateMinimapRoute();assert(math.abs(line.by)<.001 and line.bx>0)
 N.db.settings.minimapRoute=false;N:UpdateMinimapRoute();assert(not N.minimapRouteOverlay:IsShown())
 N.db.settings.minimapRoute=true;N.Position=function() return 999,.4,.4 end
 N:UpdateMinimapRoute();assert(not N.minimapRouteOverlay:IsShown())
 N.Position=function() return 1411,.4,.4 end
 N.minimapRouteLines={};N.minimapRouteOverlay.CreateLine=function() error('unsupported') end
 N:UpdateMinimapRoute();assert(#N.minimapRouteDots>0 and #N.minimapRouteDots<=768)
 C_Minimap={};N:UpdateMinimapRoute();assert(not N.minimapRouteOverlay:IsShown())
 N.Position,Minimap=oldPosition,oldMinimap
 C_Minimap,GetCVarBool,GetPlayerFacing=oldC,oldBool,oldFacing
 GetMinimapShape=oldShape;N.activeRoute=nil
end)


test('Active navigation survives reload per character without replanning',function()
 local id=N.characterID;local originalPlanner=N.RunPlanner
 N.activeRoute={map=1411,width=5000,height=3000,speed=7,points={{x=.41,y=.4},{x=.42,y=.4}},
  origin={x=.4,y=.4},travelPoints={{x=.4,y=.4,starting=true,transit=true},{x=.41,y=.4},{x=.42,y=.4},{x=.4,y=.4,closing=true,transit=true}},travelStopIndices={2,3}}
 N.waypoint=2;N.terrainIndex=3;N.routePaused=true
 for _,fn in ipairs(N.handlers.PLAYER_LOGOUT) do fn() end
 assert(N.db.navigation[id]);N.activeRoute=nil;N.waypoint=nil;N.terrainIndex=nil;N.routePaused=false
 N.characterID='Different character';N:RestoreNavigation();eq(N.activeRoute,nil)
 N.characterID=id;N.RunPlanner=function() error('Restoring must not replan') end
 N:RestoreNavigation();eq(N.waypoint,2);eq(N.terrainIndex,3);eq(N.routePaused,true)
 eq(#N.activeRoute.travelPoints,4);eq(N.activeRoute.travelStopIndices[2],3)
 N.activeRoute.points[1].x=.7;eq(N.db.navigation[id].route.points[1].x,.41)
 N.RunPlanner=originalPlanner
 N.activeRoute=nil;N:SaveNavigation();eq(N.db.navigation[id],nil)
 N:RestoreNavigation();eq(N.activeRoute,nil)
end)

test('Malformed navigation is rejected and invalid progress is safely reset',function()
 local id=N.characterID
 N.db.navigation[id]={version=1,route={map=1411,width=5000,height=3000,points={{x=99,y=.4}}}}
 N:RestoreNavigation();eq(N.activeRoute,nil)
 N.db.navigation[id].route.points[1].x=.4
 N.db.navigation[id].waypoint=0/0;N.db.navigation[id].terrainIndex=999999
 N:RestoreNavigation();eq(N.waypoint,1);eq(N.terrainIndex,1)
 N.activeRoute=nil;N:SaveNavigation()
end)

test('Minimap dots number gathering stops and hide completed/offscreen stops',function()
 local position,oldMinimap=N.Position,Minimap
 local oldC,oldShape=C_Minimap,GetMinimapShape
 C_Minimap={GetViewRadius=function() return 100 end}
 GetMinimapShape=function() return 'SQUARE' end
 Minimap=widget();Minimap.GetWidth=function() return 200 end;Minimap.GetHeight=function() return 200 end
 Minimap.GetEffectiveScale=function() return 1 end
 N.Position=function() return 1411,.4,.4 end
 N.db.settings.routeVisible=true;N.db.settings.minimapRoute=true
 N.activeRoute={map=1411,origin={x=.4,y=.4},points={{x=.402,y=.4},{x=.404,y=.4},{x=.9,y=.9}},
  travelPoints={{x=.401,y=.4,transit=true},{x=.402,y=.4},{x=.404,y=.4},{x=.9,y=.9}}}
 N.waypoint=1;N.terrainIndex=1
 N:UpdateMinimapRoute();eq(#N.minimapRoutePins,2)
 local tooltip=GameTooltip;local entries={}
 GameTooltip=widget();GameTooltip.SetOwner=function(self,pin) self.owner=pin end
 GameTooltip.AddLine=function(self,text) entries[#entries+1]=text end
 N.activeRoute.points[1].name='Silverleaf'
 N.minimapRoutePins[1].scripts.OnEnter(N.minimapRoutePins[1])
 eq(GameTooltip.text,'Stop 1 / 3');eq(entries[1],'Silverleaf')
 assert(entries[2]:find('yards away',1,true))
 GameTooltip=tooltip
 eq(N.minimapRoutePins[1].label.text,'1');eq(N.minimapRoutePins[2].label.text,'2')
 N.waypoint=2;N:UpdateMinimapRoute();eq(N.minimapRoutePins[1].label.text,'2')
 assert(not N.minimapRoutePins[2]:IsShown())
 N.activeRoute=nil;N:UpdateMinimapRoute();assert(not N.minimapRouteOverlay:IsShown())
 N.Position,Minimap=position,oldMinimap;C_Minimap,GetMinimapShape=oldC,oldShape
end)


test('Nearest loop rotates stop order and rebuilds detours without reversing direction',function()
 N.db.terrain.zones={};N.db.terrainBlocks={}
 local route={strategy='nearest',map=1411,width=5000,height=3000,speed=7,
  gatherDelay=3,mountDelay=0,points={{x=.1,y=.1,name='A'},{x=.2,y=.2,name='B'},{x=.4,y=.4,name='C'},{x=.3,y=.3,name='D'}}}
 N:StartRouteAtNearest(route,{map=1411,x=.4001,y=.4})
 eq(route.points[1].name,'C');eq(route.points[2].name,'D')
 eq(route.points[3].name,'A');eq(route.points[4].name,'B')
 eq(route.origin.x,.4)
 eq(route.travelPoints[route.travelStopIndices[1]].name,'C')
 assert(route.travelPoints[#route.travelPoints].closing)
 local before=route.points[1]
 route.strategy='optimal';N:StartRouteAtNearest(route,{map=1411,x=.1,y=.1});eq(route.points[1].name,'A')
 local original=route.points[1];route.strategy='here'
 N:StartRouteAtNearest(route,{map=1411,x=.4,y=.4});eq(route.points[1],original)
end)


test('Cached optimal loops renumber the nearest stop after the player moves',function()
 local position,zone,build,rotate=N.Position,N.ZoneNodes,N.BuildRoute,N.StartRouteAtNearest
 local x=.1;local calls=0
 local nodes={{x=.1,y=.1,name='A'},{x=.2,y=.2,name='B'},{x=.4,y=.4,name='C'}}
 N.plannerCache={};N.db.terrain.zones={};N.db.terrainBlocks={}
 N.Position=function() return 1411,x,x end
 N.ZoneNodes=function() return nodes end
 N.BuildRoute=function(_,_,start,w,h,settings)
  calls=calls+1
  return {points=N:Copy(nodes),origin=start,map=1411,width=w,height=h,speed=settings.speed,
   seconds=600,strategy='optimal',potentialStopsPerHour=18}
 end
 local first=N:PlanRoute('optimal');eq(first.points[1].name,'A')
 local built=calls;x=.4
 local second=N:PlanRoute('optimal');eq(calls,built);eq(second.points[1].name,'C')
 eq(second.points[2].name,'A');eq(second.points[3].name,'B')
 N.Position,N.ZoneNodes,N.BuildRoute=position,zone,build
end)


test('Reference-style arrow HUD updates live progress, distance, ETA and next-stop action',function()
 local position=N.Position
 N.Position=function() return 1411,.4,.4 end
 N.activeRoute={map=1411,width=5000,height=3000,speed=10,
  points={{x=.45,y=.4,name='A'},{x=.5,y=.4,name='Silverleaf'},{x=.6,y=.4,name='C'}}}
 N.waypoint=2;N.terrainIndex=1;N.routePaused=false
 N.db.settings.routeVisible=true;N:ShowArrow()
 local f=N.arrow
 f.progress.SetValue=function(self,value) self.value=value end
 f.texture.SetRotation=function(self,value) self.angle=value end
 N:UpdateArrow()
 eq(f.count.text,'2 / 3');eq(f.label.text,'500 yd');eq(f.eta.text,'~50 sec')
 eq(f.status.text,'Silverleaf');assert(math.abs(f.progress.value-1/3)<.00001)
 f.angle=nil;f.scripts.OnUpdate(f,1)
 assert(math.abs(f.texture.angle+math.pi/2)<.00001,'North-facing artwork should turn right for an east target')
 f.skip.scripts.OnClick();eq(N.waypoint,3)
 N.routePaused=true;N:UpdateArrow();eq(f.status.text,'Route paused');eq(f.eta.text,'-- sec')
 N.routePaused=false;N.Position=function() return 999,.4,.4 end
 N:UpdateArrow();eq(f.status.text,'Return to route zone');assert(not f.texture:IsShown())
 N.Position=position;N.activeRoute=nil
end)


test('Navigation display scales as one saved unit with safe size bounds',function()
 local f=N.arrow
 f.SetScale=function(self,value) self.appliedScale=value end
 assert(N:SetArrowScale(.75));eq(f.appliedScale,.75);eq(N.db.settings.arrowScale,.75)
 N:ShowArrow();eq(f.appliedScale,.75)
 assert(not N:SetArrowScale(9));eq(f.appliedScale,.75)
 assert(not N:SetArrowScale(0/0));eq(N.db.settings.arrowScale,.75)
 assert(N:SetArrowScale(1));eq(f.appliedScale,1)
 eq(f.scripts.OnEnter,nil);eq(f.scripts.OnLeave,nil)
end)

local summary='PASS: '..count..' tests; '.._VERSION..' / '..tostring(jit and jit.version or 'standard interpreter')
print(summary); results[#results+1]=summary
local file=assert(io.open(root..'/Tests/results.txt','w')); file:write(table.concat(results,'\n')); file:close()

