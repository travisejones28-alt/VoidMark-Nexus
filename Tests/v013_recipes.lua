local N,test,eq,widget,root=...
-- 0.13: bundled Forever and Classic recipe catalogs, clickable sources, Forever map
-- positions, source filter, recipe-source sync and manual export/import.

local function find(list,name) for i,e in ipairs(list) do if e.name==name then return e,i end end end
local function setup(prof,skill,faction)
 local c=N.character
 c.faction=faction or 'Horde'
 c.professions.r013={name=prof or 'Alchemy',skill=skill or 60,max=150,at=time(),recipes={
  a={name='Minor Healing Potion',learned=true,reagents={}}}}
 N.db.recipeFinds={}; N.db.recipeVendors={}; N.db.trainers={}
 N:ClearMissingCache(); N:RecipeSourcesChanged()
 return N.characterID,'r013'
end
local function teardown()
 N.character.professions.r013=nil; N.db.recipeFinds={}; N.db.recipeVendors={}; N.db.trainers={}
 N.db.settings.recipeSourceFilter=nil; N:ClearMissingCache(); N:RecipeSourcesChanged()
end
local function link(id,name) return '|cffffffff|Hitem:'..id..'::::::::::0|h['..name..']|h|r' end

test('0.13 recipes: no RecipeRadar or MTSL dependency anywhere at runtime',function()
 local toc=assert(io.open(root..'/VoidMarkNexus.toc')):read('*a')
 local deps=toc:match('## OptionalDeps: ([^\n]*)') or ''
 assert(not deps:find('RecipeRadar') and not deps:find('MissingTradeSkills') and not deps:find('MTSL'),deps)
 assert(not toc:find('## Dependencies'),'no hard dependencies')
 for file in toc:gmatch('\n([%w_\\]+%.lua)') do
  local src=assert(io.open(root..'/'..file:gsub('\\','/'))):read('*a')
  assert(not src:find('RR_DATA',1,true) and not src:find('MTSL_',1,true),file..' reads another addon\'s globals')
 end
 -- RecipeRadar's global, if present, is ignored entirely.
 local cid,pid=setup()
 RR_DATA={skills={Alchemy={{name={English='Radar Only Brew'},min_skill=5}}}}
 local list,sum=N:MissingRecipes(cid,pid)
 assert(not find(list,'Radar Only Brew')); assert(sum.external)
 RR_DATA=nil
 teardown()
end)

test('0.13 recipes: catalogs parse per profession, Forever first, Classic baseline fills in',function()
 N:ClearRecipeCatalogCache()
 local alch=N:CatalogRecipeData('Alchemy'); assert(#alch>100,'alchemy rows')
 local str=assert(find(alch,'Elixir of Minor Strength')); eq(str.skill,15)
 local mallory
 for _,s in ipairs(str.sources) do if s.text:find('Alchemist Mallory',1,true) then mallory=s end end
 assert(mallory,'Elwynn trainer listed'); eq(mallory.kind,'T'); eq(mallory.origin,'forever'); eq(mallory.faction,'A')
 eq(mallory.map,1429); assert(math.abs(mallory.x-.3984)<1e-9 and math.abs(mallory.y-.4823)<1e-9)
 eq(mallory.text,'Trainer Alchemist Mallory - Elwynn Forest (39.8, 48.2)')
 -- Duplicate lines from both catalogs collapse; sources unique per recipe.
 local seen={}; for _,s in ipairs(str.sources) do assert(not seen[s.text],'duplicate '..s.text); seen[s.text]=true end
 -- A recipe only in the Classic baseline is still listed and tagged as such.
 local base=N.BaseRecipeData.Alchemy; local onlyBase
 for line in base:gmatch('[^\n]+') do
  local name=line:match('^([^|]+)|')
  local e=name and find(alch,name)
  if e then local all=true; for _,s in ipairs(e.sources) do if s.origin~='base' then all=false end end; if all then onlyBase=e;break end end
 end
 if onlyBase then eq(onlyBase.sources[1].origin,'base') end
 -- Instances never get a map position (coordinates are not outdoor positions).
 local anyInstance=false
 for _,prof in ipairs({'Alchemy','Blacksmithing','Tailoring'}) do
  for _,e in ipairs(N:CatalogRecipeData(prof)) do for _,s in ipairs(e.sources) do
   if s.text:find('Molten Core',1,true) or s.text:find('Blackrock Depths',1,true) then anyInstance=true; eq(s.map,nil) end
   if s.map then assert(s.map>=1411 and s.map<=1458,'Classic-style map '..s.map); assert(s.x>0 and s.x<=1 and s.y>0 and s.y<=1) end
  end end
 end
 assert(anyInstance,'instance sources present but not mapped')
 -- Profession names with spaces, baseline-only professions, unknown names.
 assert(#N:CatalogRecipeData('First Aid')>5); assert(#N:CatalogRecipeData('Fishing')>0)
 eq(N:CatalogRecipeData('Nonsense'),nil)
end)

test('0.13 recipes: memory stays bounded (strings until viewed, three professions parsed)',function()
 N:ClearRecipeCatalogCache(); collectgarbage(); collectgarbage()
 local before=collectgarbage('count')
 for _,p in ipairs({'Alchemy','Blacksmithing','Cooking','Enchanting','Engineering','Leatherworking','Tailoring','First Aid','Mining','Poisons'}) do
  assert(N:CatalogRecipeData(p),p)
 end
 collectgarbage(); collectgarbage()
 local grew=collectgarbage('count')-before
 assert(grew<8000,'parsed cache grew '..grew..' KB')
 assert(type(N.ForeverRecipeData.Alchemy)=='string','catalog text kept as one string')
 -- The same table comes back while cached; an evicted profession reparses.
 local t=N:CatalogRecipeData('Poisons'); assert(N:CatalogRecipeData('Poisons')==t)
 local a=N:CatalogRecipeData('Alchemy'); assert(a~=nil)
 N:ClearRecipeCatalogCache()
end)

test('0.13 recipes: Forever map IDs resolve against the client (Classic first, modern fallback)',function()
 local zoneMap=N.RecipeZoneMap
 local names={[1429]='Elwynn Forest',[1453]='Stormwind City'}
 local old=C_Map.GetMapInfo
 C_Map.GetMapInfo=function(id) return names[id] and {name=names[id]} or nil end
 N:ClearRecipeCatalogCache()
 eq(zoneMap(12,'Elwynn Forest'),1429); eq(zoneMap(1519,'Stormwind City'),1453)
 eq(zoneMap(12,'Durotar'),nil,'area/zone mismatch rejected'); eq(zoneMap(2717,'Molten Core'),nil)
 -- A client that only knows the modern map numbers.
 N:ClearRecipeCatalogCache(); names={[37]='Elwynn Forest'}
 eq(zoneMap(12,'Elwynn Forest'),37)
 -- Non-English client: names differ, the Classic map still exists.
 N:ClearRecipeCatalogCache(); names={[1429]='Wald von Elwynn'}
 eq(zoneMap(12,'Elwynn Forest'),1429)
 -- Neither exists: no waypoint rather than a wrong one.
 N:ClearRecipeCatalogCache(); names={}
 eq(zoneMap(12,'Elwynn Forest'),nil)
 C_Map.GetMapInfo=old; N:ClearRecipeCatalogCache()
end)

test('0.13 recipes: clicking a missing recipe lists its individual sources and sets a waypoint',function()
 local cid,pid=setup('Alchemy',60,'Horde')
 local list=N:MissingRecipes(cid,pid)
 local e=assert(find(list,'Elixir of Minor Strength'))
 assert(#e.sources>10)
 -- Own-faction sources first; Forever before baseline; mappable first.
 assert(not e.sources[1].other,'own faction first')
 local pinned
 TomTom={AddWaypoint=function(_,map,x,y,o) pinned={map,x,y,o.title}; return 1 end}
 N.db.settings.tomtom=true
 local menu; local realChoice=N.Choice
 N.Choice=function(_,anchor,choices,fn) menu={anchor=anchor,choices=choices,fn=fn} end
 local shown=N:ChooseRecipeSource(e.name,e.sources)
 assert(menu and #menu.choices>5,'one entry per source')
 local pick
 for i,c in ipairs(menu.choices) do if c.label:find('Orgrimmar',1,true) then pick=c end end
 assert(pick,'Orgrimmar trainer offered'); assert(not menu.choices[1].label:find('other faction',1,true))
 menu.fn(pick.value)
 eq(pinned[1],1454); eq(pinned[4],'Elixir of Minor Strength')
 assert(shown[pick.value].text:find('Orgrimmar',1,true))
 -- One place: straight to the waypoint. None: a message, no error.
 menu=nil; pinned=nil
 N:ChooseRecipeSource('Solo',{{text='Vendor X',map=1411,x=.5,y=.5}}); assert(pinned and not menu)
 pinned=nil; N:ChooseRecipeSource('Nowhere',{{text='Drop: Somebody'}}); assert(not pinned and not menu)
 -- The row click uses the same chooser.
 N:Show('Professions'); local u=N.ui; u.character,u.profession=cid,pid; u.profView='missing'
 u.search:SetText('elixir of minor strength')
 local rows=N:RenderProfessions(u); eq(#rows,1)
 menu=nil; rows[1].click(); assert(menu and #menu.choices>5)
 u.search:SetText('')
 N.Choice=realChoice; TomTom=nil; N.db.settings.tomtom=nil
 eq(#N.errors,0)
 teardown()
end)

test('0.13 recipes: source filter works for catalog and recorded sources and is remembered',function()
 local cid,pid=setup('Cooking',60,'Horde')
 local realInfo=GetItemInfo
 GetItemInfo=function(id) local k=tonumber(id) or tonumber(tostring(id):match('item:(%d+)'))
  if k==5483 then return 'Recipe: Scorpid Surprise',nil,1,1,0,'Recipe','Cooking' end; return realInfo(id) end
 GetMerchantNumItems=function() return 1 end
 GetMerchantItemInfo=function() return 'Recipe: Scorpid Surprise',nil,140,1,3 end
 GetMerchantItemLink=function() return link(5483,'Recipe: Scorpid Surprise') end
 N:ScanMerchant()
 GetMerchantNumItems,GetMerchantItemInfo,GetMerchantItemLink=nil
 N:Show('Professions'); local u=N.ui; u.character,u.profession=cid,pid; u.profView='missing'; u.search:SetText('')
 local all=N:RenderProfessions(u)
 assert(u.sourceFilter.shown,'filter shown on Missing'); eq(u.sourceFilter:GetText(),'Sources: All sources')
 N:SetRecipeSourceFilter('V'); eq(N.db.settings.recipeSourceFilter,'V')
 local vend=N:RenderProfessions(u)
 assert(#vend>0 and #vend<#all,'vendor filter narrows the list')
 for _,r in ipairs(vend) do assert(r.text:find('Vendor',1,true),r.text) end
 local scorpid; for _,r in ipairs(vend) do if r.title=='Scorpid Surprise' then scorpid=r end end
 assert(scorpid,'recorded vendor counts as a vendor source')
 assert(u.profInfo:GetText():find('Showing: Vendors',1,true)); eq(u.sourceFilter:GetText(),'Sources: Vendors')
 N:SetRecipeSourceFilter('T'); local tr=N:RenderProfessions(u)
 for _,r in ipairs(tr) do assert(r.text:find('Trainer',1,true),r.text) end
 -- Filter menu offers every category through the normal dropdown.
 local realChoice=N.Choice; local got
 N.Choice=function(_,_,choices,fn) got=choices; fn('all') end
 N:RecipeSourceFilterMenu(u.sourceFilter); N.Choice=realChoice
 eq(#got,7); eq(N.db.settings.recipeSourceFilter,nil)
 eq(#N:RenderProfessions(u),#all)
 -- Hidden outside the Missing view.
 u.profView='recipes'; N:RenderProfessions(u); assert(not u.sourceFilter.shown)
 u.profView='missing'
 GetItemInfo=realInfo
 teardown()
end)

test('0.13 recipes: Missing list is rebuilt only when its inputs change',function()
 local cid,pid=setup('Alchemy',60)
 local a=N:MissingRecipes(cid,pid); local b=N:MissingRecipes(cid,pid)
 assert(a==b,'cached between redraws')
 N:RecipeSourcesChanged(); local c=N:MissingRecipes(cid,pid); assert(c~=a,'rebuilt after a recorded source changed')
 N.character.professions.r013.skill=61; local d=N:MissingRecipes(cid,pid); assert(d~=c,'rebuilt after skill-up')
 N.character.professions.r013.recipes.x={name='Elixir of Minor Strength',learned=true}
 N.character.professions.r013.at=time()+1
 local e=N:MissingRecipes(cid,pid); assert(not find(e,'Elixir of Minor Strength'),'learned recipe drops out after rescan')
 teardown()
end)

local function sampleRecords(now)
 N.db.recipeFinds={[3734]={name='Recipe: Big Bear Steak',recipe='Big Bear Steak',profession='Cooking',
  drops={['Bear@1411']={name='Bear',map=1411,x=.4,y=.4,at=now-100,seen=2}}}}
 N.db.recipeVendors={[5483]={name='Recipe: Scorpid Surprise',recipe='Scorpid Surprise',profession='Cooking',
  vendors={['Grubb@1411']={name='Grubb',map=1411,x=.52,y=.41,price=140,limited=3,at=now-50}}}}
 N:RecipeSourcesChanged()
end

test('0.13 recipes: merge keeps local records, validates first and caps sizes',function()
 local now=N:Now()
 sampleRecords(now)
 local payload=N:RecipeSyncPayload()
 eq(payload.vendors[5483].vendors['Grubb@1411'].limited,3,'limited stock count kept')
 eq(payload.finds[3734].drops['Bear@1411'].seen,2)
 -- Merging into an empty account adds everything.
 N.db.recipeFinds={}; N.db.recipeVendors={}
 eq(N:MergeRecipeSources(payload),2)
 eq(N.db.recipeVendors[5483].vendors['Grubb@1411'].price,140)
 -- Same data again: nothing changes.
 eq(N:MergeRecipeSources(payload),0)
 -- Older sighting does not replace a newer one; a newer one does.
 local older=N:RecipeSyncPayload(); older.vendors[5483].vendors['Grubb@1411'].at=now-1000; older.vendors[5483].vendors['Grubb@1411'].price=1
 eq(N:MergeRecipeSources(older),0); eq(N.db.recipeVendors[5483].vendors['Grubb@1411'].price,140)
 local newer=N:RecipeSyncPayload(); newer.vendors[5483].vendors['Grubb@1411'].at=now; newer.vendors[5483].vendors['Grubb@1411'].price=150
 eq(N:MergeRecipeSources(newer),1); eq(N.db.recipeVendors[5483].vendors['Grubb@1411'].price,150)
 -- A clock that ran ahead on the other PC is pulled back to now.
 local ahead=N:RecipeSyncPayload(); ahead.finds[3734].drops['Wolf@1411']={name='Wolf',map=1411,x=.1,y=.1,at=now+99999}
 eq(N:MergeRecipeSources(ahead),1); eq(N.db.recipeFinds[3734].drops['Wolf@1411'].at,now)
 -- One bad record anywhere: nothing at all is written.
 local bad=N:RecipeSyncPayload()
 bad.finds[9999]={recipe='New Thing',drops={['X@1']={name='X',map=1,x=.5,y=.5,at=now}}}
 bad.vendors[5483].vendors['Evil@1']={name=string.rep('a',500)}
 local n,err=N:MergeRecipeSources(bad); eq(n,nil); assert(err)
 eq(N.db.recipeFinds[9999],nil,'not half-applied')
 for _,v in ipairs({{},{kind='recipe-sources',schema=2,finds={},vendors={}},{kind='recipe-sources',schema=1,finds={}},
  {kind='recipe-sources',schema=1,finds={[1.5]={recipe='x'}},vendors={}},{kind='recipe-sources',schema=1,finds={[1]={recipe='x',drops='no'}},vendors={}}}) do
  eq(N:MergeRecipeSources(v),nil)
 end
 -- Caps: no more than 3000 recipe items, 20 places per item.
 local big={kind='recipe-sources',schema=1,finds={},vendors={}}
 for i=1,3001 do big.finds[i]={recipe='r'..i} end
 eq(N:MergeRecipeSources(big),nil)
 local many={kind='recipe-sources',schema=1,finds={[42]={recipe='Many',drops={}}},vendors={}}
 for i=1,21 do many.finds[42].drops['m'..i]={name='m',at=now} end
 eq(N:MergeRecipeSources(many),nil)
 N.db.recipeFinds={}; N.db.recipeVendors={}; N:RecipeSourcesChanged()
end)

test('0.13 recipes: sync payload is encoded once per change',function()
 sampleRecords(N:Now())
 local a=N:RecipeSyncSection(N.SyncHash); local b=N:RecipeSyncSection(N.SyncHash)
 assert(a==b,'cached')
 N:RecipeSourcesChanged(); local c=N:RecipeSyncSection(N.SyncHash)
 assert(c~=a); eq(c.hash,a.hash)
 local raw=N:Decode(c.raw); eq(raw.kind,'recipe-sources')
 -- No character names or messages in the payload.
 assert(not c.raw:find(N.character.name,1,true))
 N.db.recipeFinds={}; N.db.recipeVendors={}; N:RecipeSourcesChanged()
end)

test('0.13 recipes: recorded sources sync automatically between paired accounts',function()
 local sent={}
 local api=C_ChatInfo
 C_ChatInfo={SendAddonMessage=function(_,msg,_,target) sent[#sent+1]={msg=msg,target=target}; return 0 end,RegisterAddonMessagePrefix=function() return true end}
 local function drain() for _=1,200 do if not next(N.syncOut) then return end; N:FlushSync() end end
 N.db.sync.peers={};N.db.sync.known={};N.syncIn,N.syncHashes,N.syncOut={},N.db.sync.known,{}
 N:PairPeer('Banky'); drain()
 local f; for _,m in ipairs(sent) do if m.msg:find('^F:') then f=m.msg end end
 assert(f,'hello carries the recipe-source hash')
 -- The other account's recorded sources.
 local now=N:Now()
 local theirs={kind='recipe-sources',schema=1,finds={[3735]={recipe='Hot Lion Chops',profession='Cooking',
  quests={['Elixir of Pain@1411']={name='Elixir of Pain',map=1411,x=.3,y=.3,at=now}}}},
  vendors={[5483]={recipe='Scorpid Surprise',profession='Cooking',vendors={['Grubb@1411']={name='Grubb',map=1411,x=.52,y=.41,price=140,at=now}}}}}
 local raw=N:EncodeData(theirs); local H=N.SyncHash
 N.db.recipeFinds={}; N.db.recipeVendors={}
 sent={}
 N:SyncReceive('VMNX','H:PEER-9:a:b:c','WHISPER','Banky')
 N:SyncReceive('VMNX','F:'..H(raw),'WHISPER','Banky'); drain()
 local asked; for _,m in ipairs(sent) do if m.msg=='Q:recipes' then asked=true end end
 assert(asked,'asks for recipe sources it has not seen')
 raw=N.SyncEscape(raw); local n=math.ceil(#raw/230)
 for i=n,1,-1 do N:SyncReceive('VMNX',string.format('D:%d:recipes:%d:%d:',77,i,n)..raw:sub((i-1)*230+1,i*230),'WHISPER','Banky') end
 eq(N.db.recipeVendors[5483].vendors['Grubb@1411'].price,140)
 assert(N.db.recipeFinds[3735].quests['Elixir of Pain@1411'])
 -- Same hash again: not asked twice.
 sent={}; N:SyncReceive('VMNX','F:'..H(N:EncodeData(theirs)),'WHISPER','Banky'); drain(); eq(#sent,0)
 -- Our side answers Q:recipes with D: chunks of the recipes section.
 sent={}; N.syncSections=nil; N:SyncReceive('VMNX','Q:recipes','WHISPER','Banky'); drain()
 local chunks=0; for _,m in ipairs(sent) do if m.msg:find('^D:%d+:recipes:') then chunks=chunks+1 end end
 assert(chunks>0,'recipe section sent')
 -- An older peer asking for the usual sections never gets recipes it cannot read.
 sent={}; N:SyncReceive('VMNX','Q:id,inv,prof','WHISPER','Banky'); drain()
 for _,m in ipairs(sent) do assert(not m.msg:find(':recipes:',1,true)) end
 -- Damaged recipe data is ignored without touching saved records.
 local before=N.db.recipeVendors[5483].vendors['Grubb@1411'].price
 local evil=N.SyncEscape(N:EncodeData({kind='recipe-sources',schema=1,finds={[1]={recipe=5}},vendors={}}))
 N:SyncReceive('VMNX','D:78:recipes:1:1:'..evil,'WHISPER','Banky')
 eq(N.db.recipeVendors[5483].vendors['Grubb@1411'].price,before)
 N:UnpairPeer('Banky'); C_ChatInfo=api
 N.db.recipeFinds={}; N.db.recipeVendors={}; N:RecipeSourcesChanged()
 eq(#N.errors,0)
end)

test('0.13 recipes: manual export and import of recipe sources',function()
 sampleRecords(N:Now())
 local text=N:ExportRecipeSources(); assert(text:find('^VMN1:'))
 N.db.recipeFinds={}; N.db.recipeVendors={}
 -- Characters > Export menu offers it; the dialog shows preview and confirm.
 N:Show('Characters'); local u=N.ui; local realChoice=N.Choice; local got
 N.Choice=function(_,_,choices,fn) got=choices; fn('ri') end
 u.exportB.scripts.OnClick(); N.Choice=realChoice
 local labels={}; for _,c in ipairs(got) do labels[c.value]=c.label end
 assert(labels.re and labels.ri,'recipe export/import in the Export menu')
 local f=N.dialog; eq(f.importMode,'recipe-sources'); assert(f.preview.shown and f.confirm.shown,'import can be confirmed')
 f.edit:SetText(text); N.pendingImport=nil
 f.preview.scripts.OnClick()
 assert(N.pendingImport and N.pendingImport.kind=='recipe-sources',tostring(f.status:GetText()))
 assert(f.edit:GetText():find('2 recipes, 2 places',1,true),f.edit:GetText())
 f.confirm.scripts.OnClick()
 eq(N.db.recipeVendors[5483].vendors['Grubb@1411'].price,140); assert(N.db.recipeFinds[3734])
 -- Garbage and other export kinds are refused at preview.
 local ok,err=N:PreviewRecipeSourceImport('nope'); eq(ok,nil); assert(err)
 ok=N:PreviewRecipeSourceImport(N:EncodeData({kind='route',schema=1})); eq(ok,nil)
 -- Slash commands open the same dialogs.
 N:Slash('exportrecipes'); eq(N.dialog.importMode,nil); assert(N.dialog.edit:GetText():find('^VMN1:'))
 N:Slash('importrecipes'); eq(N.dialog.importMode,'recipe-sources')
 N.dialog:Hide(); N.pendingImport=nil
 N.db.recipeFinds={}; N.db.recipeVendors={}; N:RecipeSourcesChanged()
 eq(#N.errors,0)
end)
