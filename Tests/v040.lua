-- 0.4.0: leveling planner and world-map controls.
local N,test,eq,widget,setNow=...

local function fresh(name)
 -- Isolated profession on the current character; removed by each test.
 local p={name=name,skill=100,max=150,at=N:Now(),recipes={}}
 N.character.professions[name]=p
 return p
end
local function evidence(prof,key,list)
 for skill,diff in pairs(list) do N:RecordDifficulty(prof,key,skill,diff) end
end

test('Observed colours bound recipe thresholds without guessing',function()
 N.db.levelEvidence={}
 evidence('TestCraft','a',{[100]='optimal',[110]='optimal',[115]='medium',[125]='easy',[140]='trivial'})
 local Y,G,X,est=N:RecipeThresholds('TestCraft','a',{difficulty='optimal'},100)
 eq(Y,111);eq(G,116);eq(X,126);eq(est,false)
end)

test('Unobserved boundaries are conservative estimates and are flagged',function()
 N.db.levelEvidence={}
 evidence('TestCraft','b',{[100]='optimal'})
 local Y,G,X,est=N:RecipeThresholds('TestCraft','b',{difficulty='optimal'},100)
 eq(Y,101);eq(G,116);eq(X,131);eq(est,true)
 -- A gray recipe never yields skill at the current level.
 local y2,_,x2=N:RecipeThresholds('TestCraft','g',{difficulty='trivial'},100)
 eq(N:SkillUpChance(100,y2,x2),0)
 -- Modern numeric enum is accepted.
 N:RecordDifficulty('TestCraft','n',100,0);eq(N.db.levelEvidence.TestCraft.n.hi[1],100)
end)

test('Skill-up chance follows orange-certain then linear-to-gray',function()
 eq(N:SkillUpChance(100,111,130),1);eq(N:SkillUpChance(111,111,130),1)
 assert(math.abs(N:SkillUpChance(120,111,130)-10/19)<1e-9);eq(N:SkillUpChance(130,111,130),0)
end)

local function setup()
 N.db.levelEvidence={}
 local p=fresh('Plancraft')
 p.recipes.a={name='Cheap Thing',learned=true,difficulty='optimal',reagents={{id=501,qty=1}},output=601,outputMin=1,outputMax=1}
 p.recipes.b={name='Dear Thing',learned=true,difficulty='optimal',reagents={{id=502,qty=1}},output=602,outputMin=1,outputMax=1}
 p.recipes.c={name='Locked Thing',learned=false,difficulty='optimal',reagents={{id=503,qty=1}},source='Vendor: Test Supplier'}
 evidence('Plancraft','a',{[100]='optimal',[110]='optimal',[111]='medium',[120]='easy',[130]='trivial'})
 evidence('Plancraft','b',{[100]='optimal',[149]='optimal'})
 N:SetPrice(501,.01);N:SetPrice(502,1)
 N.character.bags={};N.character.bank={}
 return p
end

test('Cheapest plan follows cheap recipe through its colours and totals materials',function()
 setup()
 local plan=N:LevelingPlan(N.characterID,'Plancraft',120,'Cheapest')
 eq(plan.error,nil);eq(plan.reached,120);eq(plan.segments[1].name,'Cheap Thing');eq(#plan.segments,1)
 assert(plan.crafts>=20,'expected at least one craft per point')
 eq(plan.materials[1].id,501);eq(plan.materials[1].need,plan.crafts);eq(plan.cash,plan.crafts*100)
 local found=false;for _,u in ipairs(plan.unusable) do if u.name=='Locked Thing' then found=u.source=='Vendor: Test Supplier' end end
 assert(found,'unlearned recipe must be listed with its source')
 N.character.professions.Plancraft=nil
end)

test('Fastest plan prefers certain skill-ups; Self-found uses owned materials',function()
 setup()
 local fast=N:LevelingPlan(N.characterID,'Plancraft',125,'Fastest')
 local usedB=false;for _,s in ipairs(fast.segments) do if s.name=='Dear Thing' then usedB=true end end
 assert(usedB,'fastest should switch to the orange recipe');eq(fast.crafts,25)
 N.character.bags={[502]=100};N.character.bagsAt=N:Now()
 local own=N:LevelingPlan(N.characterID,'Plancraft',125,'Self-found')
 eq(own.segments[1].name,'Dear Thing');eq(own.materials[1].missing,0);eq(own.cash,0)
 N.character.bags={};N.character.professions.Plancraft=nil
end)

test('Unknown prices and rank caps are reported instead of invented',function()
 setup()
 N.prices[501]=nil;N.prices[502]=nil
 local plan=N:LevelingPlan(N.characterID,'Plancraft',120,'Cheapest')
 eq(plan.stoppedAt,100);eq(#plan.segments,0);assert(#plan.notes>0)
 local fast=N:LevelingPlan(N.characterID,'Plancraft',120,'Fastest')
 assert(fast.unknown);eq(fast.cash,nil)
 N:SetPrice(501,.01);N:SetPrice(502,1)
 local capped=N:LevelingPlan(N.characterID,'Plancraft',300,'Cheapest')
 eq(capped.to,150);assert(capped.notes[1]:find('Train the next rank',1,true))
 N.character.professions.Plancraft=nil
end)

test('Leveling plan queues to Crafting and the Leveling tab renders',function()
 setup()
 local plans=#N.db.plans
 local plan=N:LevelingPlan(N.characterID,'Plancraft',120,'Balanced')
 N:QueueLevelingPlan(plan,N.characterID,'Plancraft')
 eq(#N.db.plans,plans+#plan.segments)
 for i=#N.db.plans,plans+1,-1 do table.remove(N.db.plans,i) end
 N:Show('Leveling');N.ui.character=N.characterID;N.ui.profession='Plancraft';N.ui.target:SetText('120');N:Render()
 assert(N.ui.rowCount>0,'plan steps listed')
 assert(N.ui.profInfo.text:find('crafts',1,true),'plan summary shown')
 assert(N:LevelingSummary(plan):find('Cash to buy missing',1,true))
 N.ui.profession=nil;N.character.professions.Plancraft=nil
end)

test('World-map controls live on UIParent and follow the map',function()
 local hooks={}
 local world=widget();world.ScrollContainer=widget()
 world.HookScript=function(_,event,fn) hooks[event]=fn end
 world.GetCanvas=function() return widget() end
 local oldWorld=WorldMapFrame;WorldMapFrame=world
 N.mapControls,N.mapHooks,N.mapFilterMenu=nil,nil,nil
 N.db.settings.mapNodeFilter='ore';N.db.settings.mapShowHerbs=true
 N:EnsureMapControls()
 assert(N.mapControls.parent==UIParent,'button must not be parented to the world map')
 eq(N.mapControls.strata,'FULLSCREEN_DIALOG')
 eq(N.db.settings.mapNodeFilter,'all');eq(N.db.settings.mapShowHerbs,false)
 assert(N.mapControls:IsShown());assert(hooks.OnShow and hooks.OnHide)
 world:Hide();hooks.OnHide();assert(not N.mapControls:IsShown())
 world:Show();hooks.OnShow();assert(N.mapControls:IsShown())
 N:ToggleMapFilterMenu(N.mapControls)
 assert(N.mapFilterMenu:IsShown());assert(N.mapFilterMenu.parent==UIParent);assert(N.mapFilterMenu.anchoredToMap)
 hooks.OnHide();assert(not N.mapFilterMenu:IsShown())
 N.db.settings.mapButton=false;N:EnsureMapControls();assert(not N.mapControls:IsShown())
 N:Slash('mapcontrols reset');eq(N.db.settings.mapButton,true);eq(N.db.settings.mapButtonPos,nil)
 N.db.settings.mapShowHerbs=true
 WorldMapFrame=oldWorld
end)

test('TomTom mirrors the current stop and clears when navigation ends',function()
 local added,removed={},{}
 TomTom={AddWaypoint=function(_,map,x,y,opts) added[#added+1]={map,x,y,opts};return #added end,RemoveWaypoint=function(_,uid) removed[#removed+1]=uid end}
 local route,wp,paused=N.activeRoute,N.waypoint,N.routePaused
 N.tomtomKey,N.tomtomUID=nil,nil;N.routePaused=false
 N.activeRoute={map=1411,points={{x=.1,y=.2,name='Peacebloom'},{x=.3,y=.4}}};N.waypoint=1
 N:SyncTomTom();eq(#added,1);eq(added[1][1],1411);eq(added[1][4].crazy,false)
 N:SyncTomTom();eq(#added,1)
 N.waypoint=2;N:SyncTomTom();eq(#added,2);eq(removed[1],1)
 N.activeRoute=nil;N:SyncTomTom();eq(removed[2],2);eq(N.tomtomUID,nil)
 N.db.settings.tomtom=false;N.activeRoute={map=1411,points={{x=.1,y=.2}}};N:SyncTomTom();eq(#added,2)
 N.db.settings.tomtom=true
 TomTom=nil;N.activeRoute,N.waypoint,N.routePaused=route,wp,paused;N.tomtomKey,N.tomtomUID=nil,nil
end)
