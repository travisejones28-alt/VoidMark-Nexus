local N,test,eq,widget=...
-- 0.12: Missing recipes (Professions > Missing, /vmn missing, profession-window button).

local realItemInfo=GetItemInfo
local items={}
local function withItems(map) items=map; GetItemInfo=function(id)
 local k=tonumber(id) or tonumber(tostring(id):match('item:(%d+)'))
 local e=items[k]; if e then return e[1],nil,1,1,0,'Recipe',e[2] end
 return realItemInfo(id) end end
local function restore() GetItemInfo=realItemInfo; items={} end
local function link(id,name) return '|cffffffff|Hitem:'..id..'::::::::::0|h['..name..']|h|r' end

local function setup()
 local c=N.character
 c.faction='Horde'
 c.professions.cook012={name='Cooking',skill=60,max=150,at=time(),recipes={
  a={name='Herb Baked Egg',learned=true,reagents={}},
  b={name='Forever Stew',learned=false,source='|cffffd200Vendor: |rGrubb|n|cffffd200Zone: |rDurotar'}}}
 N.db.recipeFinds={}; N.db.recipeVendors={}; N.db.trainers={}
 return N.characterID,'cook012'
end
local function teardown() N.character.professions.cook012=nil; N.db.recipeFinds={}; N.db.recipeVendors={}; N.db.trainers={}; restore() end
local function find(list,name) for i,e in ipairs(list) do if e.name==name then return e,i end end end

test('0.12 missing: shipped Classic data parses per profession on demand',function()
 local cook=N:RecipeData('Cooking')
 assert(#cook>50,'cooking rows')
 local w; for _,d in ipairs(cook) do if d.name=='Westfall Stew' then w=d end end
 assert(w); eq(w.skill,50); eq(w.code,'V'); eq(w.faction,'A'); eq(w.npc,'Kendor Kabonka')
 local eng=N:RecipeData('Engineering'); local ray
 for _,d in ipairs(eng) do if d.name=='Discombobulator Ray' then ray=d end end
 assert(ray and ray.code=='B' and ray.zone=='Gnomeregan')
 eq(#N:RecipeData('Nonsense'),0)
end)

test('0.12 missing: known recipes are left out; client unlearned recipes and data rows listed',function()
 local cid,pid=setup()
 local list,sum=N:MissingRecipes(cid,pid)
 assert(not find(list,'Herb Baked Egg'),'learned recipe hidden')
 local fs=find(list,'Forever Stew'); assert(fs and fs.client,'client unlearned recipe listed')
 eq(fs.sources[1].kind,'client'); eq(fs.sources[1].text,'Vendor: Grubb Zone: Durotar')
 local scorpid=find(list,'Scorpid Surprise'); assert(scorpid and scorpid.skill==20 and not scorpid.other)
 local westfall,wi=find(list,'Westfall Stew'); assert(westfall and westfall.other,'Alliance-only seller kept but marked')
 local _,si=find(list,'Scorpid Surprise'); assert(si<wi,'own-faction rows before other-faction rows')
 eq(sum.known,1); eq(sum.skill,60); assert(sum.learnNow>0 and sum.otherFaction>0)
 -- Learnable now sorted before higher skill.
 local seenHigh=false
 for _,e in ipairs(list) do if not e.other then
  if (e.skill or 999)>60 then seenHigh=true elseif seenHigh then error('learnable row after a higher one: '..e.name) end end end
 teardown()
end)

test('0.12 missing: loot and quest rewards are recorded with place and shown as seen',function()
 local cid,pid=setup()
 withItems({[3734]={'Recipe: Big Bear Steak','Cooking'},[3735]={'Recipe: Hot Lion Chops','Cooking'},[999]={'Linen Cloth','Cloth'}})
 GetNumLootItems=function() return 2 end
 GetLootSlotLink=function(i) return i==1 and link(3734,'Recipe: Big Bear Steak') or link(999,'Linen Cloth') end
 UnitExists=function() return true end; UnitIsDead=function() return true end
 N:ScanLootRecipes()
 local f=N.db.recipeFinds[3734]; assert(f and f.profession=='Cooking' and f.recipe=='Big Bear Steak')
 assert(not N.db.recipeFinds[999],'non-recipe loot ignored')
 local _,d=next(f.drops); eq(d.map,1411); eq(d.seen,1)
 N:ScanLootRecipes(); local _,d2=next(f.drops); eq(d2.seen,2)
 GetTitleText=function() return 'Elixir of Pain' end
 GetNumQuestRewards=function() return 1 end; GetNumQuestChoices=function() return 0 end
 GetQuestItemLink=function() return link(3735,'Recipe: Hot Lion Chops') end
 N:ScanQuestRecipes()
 local q=N.db.recipeFinds[3735]; assert(q and next(q.quests))
 local list=N:MissingRecipes(cid,pid)
 local bear=find(list,'Big Bear Steak'); assert(bear.sources[1].seen and bear.sources[1].text:find('Looted from',1,true))
 assert(bear.sources[1].map==1411,'waypoint position kept')
 local lion=find(list,'Hot Lion Chops'); assert(lion.sources[1].seen and lion.sources[1].text:find('Quest reward: Elixir of Pain',1,true))
 GetNumLootItems,GetLootSlotLink,UnitExists,UnitIsDead,GetTitleText,GetNumQuestRewards,GetNumQuestChoices,GetQuestItemLink=nil
 teardown()
end)

test('0.12 missing: recorded vendors and trainers feed the list with their place',function()
 local cid,pid=setup()
 withItems({[5483]={'Recipe: Scorpid Surprise','Cooking'}})
 GetMerchantNumItems=function() return 1 end
 GetMerchantItemInfo=function() return 'Recipe: Scorpid Surprise',nil,140,1,-1 end
 GetMerchantItemLink=function() return link(5483,'Recipe: Scorpid Surprise') end
 N:ScanMerchant()
 eq(N.db.recipeVendors[5483].profession,'Cooking')
 N.db.trainers.Cooking={['Zamja@1411']={name='Zamja',map=1411,x=.5,y=.5,services={['Trainer Only Soup']={skill=40,cost=500}}}}
 local list=N:MissingRecipes(cid,pid)
 local s=find(list,'Scorpid Surprise'); assert(s.sources[1].seen and s.sources[1].kind=='vendor')
 assert(#s.sources>=2,'Classic data line kept below the seen one')
 local t=find(list,'Trainer Only Soup'); assert(t and t.skill==40 and t.sources[1].kind=='trainer')
 GetMerchantNumItems,GetMerchantItemInfo,GetMerchantItemLink=nil
 teardown()
end)

test('0.12 missing: recipe finds are capped',function()
 setup(); withItems({})
 for i=1,3000 do N.db.recipeFinds[100000+i]={recipe='x'} end
 withItems({[3734]={'Recipe: Big Bear Steak','Cooking'}})
 eq(N:RecordRecipeFind(link(3734,'Recipe: Big Bear Steak'),'drop','Bear'),false)
 teardown()
end)

test('0.12 missing: Professions > Missing view, /vmn missing and the waypoint click',function()
 local cid,pid=setup()
 N:Show('Professions'); local u=N.ui; u.character,u.profession=cid,pid
 u.viewMissing.scripts.OnClick()
 eq(u.profView,'missing')
 local rows=N:RenderProfessions(u)
 assert(#rows>10); assert(u.profInfo:GetText():find('missing',1,true))
 assert(not u.target.shown and u.search.shown)
 u.search:SetText('forever'); rows=N:RenderProfessions(u); eq(#rows,1); u.search:SetText('')
 -- Click without a recorded position says so instead of failing.
 rows[1].click()
 local pinned
 TomTom={AddWaypoint=function(_,map,x,y,o) pinned={map,x,y,o.title}; return 1 end}
 N:PointToSource('Soup',{map=1411,x=.25,y=.75,text='Vendor X'})
 eq(pinned[1],1411); eq(pinned[4],'Soup'); TomTom=nil
 N:Slash('missing cooking'); eq(N.ui.profView,'missing'); eq(N.ui.profession,pid)
 u.viewLevel.scripts.OnClick(); eq(u.profView,'level')
 eq(#N.errors,0)
 teardown()
end)
