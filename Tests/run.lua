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
  CreateTexture=function() return widget() end,CreateFontString=function() return widget() end}
 return setmetatable(w,{__index=function(_,k) return methods[k] or function() end end})
end
function CreateFrame() return widget() end
UIParent=widget(); Minimap=widget(); GameTooltip=widget()
local timers={}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end,NewTicker=function() end}
local function flush() local rounds=0; while #timers>0 do rounds=rounds+1; assert(rounds<1000,'timer recursion'); local fn=table.remove(timers,1); fn() end end
C_Map={GetBestMapForUnit=function() return 1411 end,GetPlayerMapPosition=function() return {GetXY=function() return .4,.4 end} end,GetMapWorldSize=function() return 5000,3000 end}
local N={}
local files={'Core','Data/Nodes','Data/Spawns','Model','Transfer','Professions','Inventory','Prices','Gathering','Routes','UI','Boot'}
for _,f in ipairs(files) do assert(loadfile(root..'/VoidMarkNexus/'..f..'.lua'))('VoidMarkNexus',N) end
local results={}; local count=0
local function test(name,fn)
 local ok,err=pcall(fn); results[#results+1]=(ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)); print(results[#results]); if not ok then error(err) end; count=count+1
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
test('All TOC Lua files compile and load under Lua 5.1 compatible runtime',function() eq(N.version,'0.1.0-alpha') end)
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
local summary='PASS: '..count..' tests; '.._VERSION..' / '..tostring(jit and jit.version or 'standard interpreter')
print(summary); results[#results+1]=summary
local file=assert(io.open(root..'/Tests/results.txt','w')); file:write(table.concat(results,'\n')); file:close()
