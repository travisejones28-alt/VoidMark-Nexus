local N,test,eq=...

test('Gathering skills use current character and localized profession IDs',function()
 local saved=N.character.professions
 N.character.professions={['182']={name='Localized herb',skill=75,max=150},['186']={name='Localized ore',skill=120,max=150}}
 local skills=N:GatheringSkills();eq(skills.herb.skill,75);eq(skills.ore.skill,120)
 N.character.professions={};eq(next(N:GatheringSkills()),nil)
 N.character.professions=saved
end)

test('Skill-up eligibility excludes locked nodes, estimated gray nodes and rank caps',function()
 local node={kind='herb',skill=50};local skills={herb={skill=49,max=150}}
 eq(N:SkillupNode(node,skills),nil)
 skills.herb.skill=50;local weight,color=N:SkillupNode(node,skills);eq(weight,1);eq(color,'orange')
 skills.herb.skill=75;weight,color=N:SkillupNode(node,skills);eq(weight,.65);eq(color,'yellow')
 skills.herb.skill=100;weight,color=N:SkillupNode(node,skills);eq(weight,.2);eq(color,'green')
 skills.herb.skill=150;skills.herb.max=225;eq(N:SkillupNode(node,skills),nil)
 skills.herb.skill=75;skills.herb.max=75;eq(N:SkillupNode(node,skills),nil)
 eq(N:SkillupNode(node,{}),nil)
end)

test('Skill-up route filtering never hides nodes from independent map filters',function()
 local settings,professions,types,spawns=N:Copy(N.db.settings),N.character.professions,N.nodeTypes,N.spawns
 N.character.professions={['182']={name='Herbalism',skill=100,max=150}}
 N.nodeTypes={[1]={kind='herb',name='Gray',skill=1},[2]={kind='herb',name='Orange',skill=100},[3]={kind='herb',name='Locked',skill=125},[4]={kind='ore',name='Unlearned',skill=1}}
 N.spawns={};for id=1,4 do N.spawns[id]={[1411]={.1+id*.1,.2}} end
 N.db.settings.kind='all';N.db.settings.target='';N.db.settings.importedNodes=true;N.db.settings.observedNodes=false;N.db.settings.routeSelectionMode='skillup'
 -- Requirement 1 becomes estimated gray at 101, so use 101 for this fixture.
 N.character.professions['182'].skill=101
 local nodes=N:ZoneNodes(1411);eq(#nodes,1);eq(nodes[1].name,'Orange');eq(nodes[1].skillPriority,1)
 eq(#N:ZoneNodes(1411,'all',''),4)
 N.db.settings,N.character.professions,N.nodeTypes,N.spawns=settings,professions,types,spawns
end)

test('Skill changes and rank-cap training invalidate skill-up planning settings',function()
 local settings,professions=N:Copy(N.db.settings),N.character.professions
 N.db.settings.routeSelectionMode='skillup'
 N.character.professions={['182']={name='Herbalism',skill=74,max=75}}
 local a=N:PlannerCacheKey(N:RouteSettings());N.character.professions['182'].skill=75
 local b=N:PlannerCacheKey(N:RouteSettings());assert(a~=b)
 N.character.professions['182'].max=150;assert(b~=N:PlannerCacheKey(N:RouteSettings()))
 N.db.settings,N.character.professions=settings,professions
end)

test('Skill-up route construction favors useful difficulty without exceeding the circuit budget',function()
 local nodes={}
 for i=1,8 do
  local angle=i*math.pi/4
  nodes[i]={x=.5+math.cos(angle)*.05,y=.5+math.sin(angle)*.05,skillPriority=i%2==0 and 1 or .2,skillColor=i%2==0 and 'orange' or 'green'}
 end
 local r=N:BuildRoute(nodes,{map=1411,x=.5,y=.5},5000,3000,{speed=14,mountDelay=3,gatherDelay=3,nodeLimit=2,routeMinutes=5,travel='100% Mount',routeSelectionMode='skillup'})
 assert(r and r.skillup and #r.points==2 and r.seconds<=300)
 eq(N:RouteStopValue(r.points),2)
 local clean=N:CleanNavigationRoute(r);assert(clean and clean.skillup);eq(clean.points[1].skillPriority,1)
end)

test('Routes dropdown exposes skill-up modes and selecting one clears old resource restrictions',function()
 local settings,professions=N:Copy(N.db.settings),N:Copy(N.character.professions)
 local choice=N.Choice;local tab=N.ui.tab;local options,select
 N.Choice=function(_,_,list,fn) options,select=list,fn end
 N.ui.tab='Routes';N.ui.filterButton.scripts.OnClick()
 local found={};for _,option in ipairs(options) do found[option.value]=true end
 assert(found.skillherb and found.skillore and found.skillall)
 N.db.settings.target='Silverleaf';N.db.settings.routeResources={Silverleaf=true}
 select('skillore');eq(N.db.settings.kind,'ore');eq(N.db.settings.target,'');eq(N.db.settings.routeSelectionMode,'skillup');eq(N.db.settings.routeResources,nil)
 N:Render();assert(N.ui.filterButton.text:find('Mining skill-ups',1,true))
 N.Choice,N.ui.tab=choice,tab;N.db.settings,N.character.professions=settings,professions
end)

test('Skill-up zone ranking preserves priority instead of replacing it with resource yield',function()
 local results={{map=1411,score=20,route={skillup=true,points={},seconds=600}},
  {map=1412,score=40,route={skillup=true,points={},seconds=600}}}
 N:RefreshZoneScores(results);eq(results[1].map,1412);eq(results[1].metric,'skill priority');eq(results[1].score,40)
 N:RefreshZoneScores(results);eq(results[1].score,40)
end)

test('Skill-up summary explains missing skills and the trainer rank cap',function()
 local settings,professions=N:Copy(N.db.settings),N.character.professions
 N.db.settings.kind='all';N.character.professions={['182']={name='Herbalism',skill=75,max=75}}
 local text=N:GatheringSkillSummary();assert(text:find('visit a trainer',1,true));assert(text:find('Mining skill unavailable',1,true))
 N.db.settings,N.character.professions=settings,professions
end)
