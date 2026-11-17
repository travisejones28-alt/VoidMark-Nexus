local _, N = ...
-- Missing recipes: what this character has not learned yet and where to get it.
--
-- Where the list comes from, best first:
--  1. Seen in game: trainers and recipe vendors you opened (Trainers.lua), plus
--     recipe items you looted or were offered as quest rewards (recorded here).
--  2. The game client: unlearned recipes the profession window reports, with
--     the client's own source text when it gives one.
--  3. The bundled recipe catalogs (ForeverRecipeBridge.lua): Forever data first,
--     then the Classic baseline. No other addon is needed.
--  4. Shipped Classic item data (Data/RecipeSources.lua, MIT) for any profession
--     the catalogs do not cover.
-- Recorded finds are capped, only hold recipe facts, and are shared with the other
-- account only through Nexus sync or export (RecipeSync.lua).

local MAX_FINDS,MAX_PER_ITEM=3000,20
local LIMIT_ROWS=400

local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function lower(s) return type(s)=='string' and s:lower() or '' end
local function strip(s)
 if type(s)~='string' then return nil end
 s=s:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|n',' '):gsub('|T.-|t',''):gsub('%s+',' ')
 s=s:match('^%s*(.-)%s*$'); return s~='' and s or nil
end
N.StripSource=strip

--------------------------------------------------------------------------------
-- Shipped data
--------------------------------------------------------------------------------
local KIND={V='vendor',B='drop',Z='drop',R='drop',Q='quest'}
local parsed={}
-- Parse one profession's shipped lines on first use; other professions stay strings.
function N:RecipeData(profession)
 if parsed[profession] then return parsed[profession] end
 local raw=type(self.RecipeSourceData)=='table' and self.RecipeSourceData[profession]
 local out={}
 if type(raw)=='string' then
  for line in raw:gmatch('[^\n]+') do
   local f={};local i=1
   for v in (line..'|'):gmatch('([^|]*)|') do f[i]=v;i=i+1 end
   local id,name=tonumber(f[1]),f[2]
   if id and name and name~='' then
    out[#out+1]={item=id,name=name,skill=tonumber(f[3]),code=f[4],npc=f[5]~='' and f[5] or nil,
     faction=f[6]~='' and f[6] or nil,cost=tonumber(f[7]),zone=f[8]~='' and f[8] or nil,
     quest=f[9]~='' and f[9] or nil,chance=tonumber(f[10])}
   end
  end
 end
 parsed[profession]=out
 return out
end

local function dataText(self,d)
 local side=d.faction=='A' and ' (Alliance)' or d.faction=='H' and ' (Horde)' or ''
 if d.code=='V' then return 'Vendor '..(d.npc or '?')..side..(d.cost and (' | '..self:Gold(d.cost)) or '') end
 if d.code=='B' then return 'Drops from '..(d.npc or 'a boss')..(d.zone and (', '..d.zone) or '')..(d.chance and (' ('..d.chance..'%)') or '') end
 if d.code=='Z' then return 'Drops in '..(d.zone or 'one zone')..(d.chance and (' ('..d.chance..'%)') or '') end
 if d.code=='R' then return 'Rare world drop'..(d.chance and (' ('..d.chance..'%)') or '') end
 if d.code=='Q' then return 'Quest reward: '..(d.quest or '?')..side end
 return nil
end

--------------------------------------------------------------------------------
-- Recording loot and quest rewards
--------------------------------------------------------------------------------
local function itemName(self,link)
 local name=self:Call(GetItemInfo,link)
 return name or (type(link)=='string' and link:match('%[(.-)%]'))
end
local function itemProfession(self,id)
 local info={self:Call(GetItemInfo,id)}
 return self:Text(info[7]) and info[7] or nil
end

function N:RecordRecipeFind(link,kind,source)
 local id=self:ItemID(link); local name=itemName(self,link)
 local recipe=self:RecipeNameFromItem(name)
 if not (id and recipe and self:Text(source)) then return false end
 local root=self.db.recipeFinds
 if not root[id] and count(root)>=MAX_FINDS then return false end
 local item=type(root[id])=='table' and root[id] or {}
 item.name,item.recipe=name,recipe
 item.profession=itemProfession(self,id) or item.profession
 local field=kind=='quest' and 'quests' or 'drops'
 item[field]=type(item[field])=='table' and item[field] or {}
 local map,x,y=self:Position()
 local key=source..'@'..tostring(map or 0)
 local e=item[field][key]
 if not e and count(item[field])>=MAX_PER_ITEM then root[id]=item; return false end
 e=type(e)=='table' and e or {seen=0}
 e.name,e.map,e.x,e.y,e.at,e.seen=source,map,x,y,self:Now(),(tonumber(e.seen) or 0)+1
 item[field][key]=e; root[id]=item; self.dirty=true; self:RecipeSourcesChanged()
 return true
end

function N:ScanLootRecipes()
 if type(GetNumLootItems)~='function' then return end
 local n=self:Call(GetNumLootItems); if not self:Finite(n,1,100) then return end
 local from
 if self:Call(UnitExists,'target') and self:Call(UnitIsDead,'target') then from=self:Call(UnitName,'target') end
 if not self:Text(from) then from='Something you looted' end
 for i=1,n do
  local link=self:Call(GetLootSlotLink,i)
  if link then self:RecordRecipeFind(link,'drop',from) end
 end
end

function N:ScanQuestRecipes()
 local title=strip(self:Call(GetTitleText)); if not self:Text(title) then return end
 local giver=self:Call(UnitName,'npc')
 local label=title..(self:Text(giver) and (' ('..giver..')') or '')
 for _,kind in ipairs({'reward','choice'}) do
  local n=self:Call(kind=='reward' and GetNumQuestRewards or GetNumQuestChoices)
  for i=1,(self:Finite(n,0,20) and n or 0) do
   local link=self:Call(GetQuestItemLink,kind,i)
   if link then self:RecordRecipeFind(link,'quest',label) end
  end
 end
end

N:On('LOOT_OPENED',function() N:ScanLootRecipes() end)
for _,e in ipairs({'QUEST_DETAIL','QUEST_COMPLETE'}) do N:On(e,function() N:ScanQuestRecipes() end) end

--------------------------------------------------------------------------------
-- The missing list
--------------------------------------------------------------------------------
local function myFaction(c)
 local f=c and c.faction or (UnitFactionGroup and select(1,N:Call(UnitFactionGroup,'player')))
 return f=='Alliance' and 'A' or f=='Horde' and 'H' or nil
end

-- Returns rows {name,skill,item,sources={{kind,text,seen,map,x,y}}} for one
-- character's profession, plus a summary table.
function N:MissingRecipes(cid,pid)
 local c=cid and self.db.characters[cid]; local p=c and c.professions and c.professions[pid]
 if not p then return {},{known=0} end
 local prof=p.name
 local known,byName,list={}, {}, {}
 local knownCount=0
 for _,r in pairs(p.recipes or {}) do
  if type(r)=='table' and self:Text(r.name) and r.learned~=false then known[lower(r.name)]=true;knownCount=knownCount+1 end
 end
 local mine=myFaction(c)
 local function entry(name,skill,item)
  local k=lower(name)
  if k=='' or known[k] then return nil end
  local e=byName[k]
  if not e then e={name=name,sources={},seenText={}};byName[k]=e;list[#list+1]=e end
  if skill and (not e.skill or skill<e.skill) then e.skill=skill end
  e.item=e.item or item
  return e
 end
 local function add(e,src)
  if not e or not src.text or e.seenText[src.text] then return end
  e.seenText[src.text]=true; e.sources[#e.sources+1]=src
 end
 -- 1. Seen in game: trainers and vendors.
 for _,t in pairs(self.db.trainers[prof] or {}) do
  for s,info in pairs(type(t)=='table' and type(t.services)=='table' and t.services or {}) do
   if not s:find(prof,1,true) then entry(s,info.skill) end
  end
 end
 for id,item in pairs(self.db.recipeVendors) do
  if type(item)=='table' and item.recipe then
   local ip=item.profession or itemProfession(self,id)
   if ip==prof then entry(item.recipe,nil,id) end
  end
 end
 for id,item in pairs(self.db.recipeFinds) do
  if type(item)=='table' and item.recipe and (item.profession or itemProfession(self,id))==prof then entry(item.recipe,nil,id) end
 end
 -- 2. The client's unlearned recipes.
 for _,r in pairs(p.recipes or {}) do
  if type(r)=='table' and r.learned==false and self:Text(r.name) then
   local e=entry(r.name,nil,nil)
   local text=strip(r.source)
   if e then e.client=true; if text then add(e,{kind='client',text=text,seen=true}) end end
  end
 end
 -- 3. Bundled recipe catalogs: Forever first, then the Classic baseline.
 local extRows=self:CatalogRecipeData(prof)
 for _,d in ipairs(extRows or {}) do
  if not known[lower(d.name)] then
   local e=entry(d.name,d.skill,d.item)
   if e then e.skill=d.skill or e.skill end
   for _,s in ipairs(d.sources) do add(e,{kind=s.kind,text=s.text,ext=true,origin=s.origin,other=s.faction and mine and s.faction~=mine or nil,map=s.map,x=s.x,y=s.y}) end
  end
 end
 -- 4. Shipped Classic item data, only when the catalogs lack this profession.
 for _,d in ipairs(extRows and {} or self:RecipeData(prof)) do
  if not known[lower(d.name)] then
   -- The data names one seller per recipe, so an Alliance-only line does not
   -- prove Horde cannot buy it: keep it, greyed and listed last.
   local e=entry(d.name,d.skill,d.item)
   add(e,{kind=KIND[d.code] or 'data',text=dataText(self,d),data=true,other=d.faction and mine and d.faction~=mine or nil})
  end
 end
 -- Sources for everything collected: recorded trainers/vendors, finds.
 for _,e in ipairs(list) do
  for _,src in ipairs(self:RecipeSources(prof,e.name)) do
   if not src.skill or not e.skill then e.skill=e.skill or src.skill end
   add(e,{kind=src.kind,text=self:SourceText(src),seen=true,map=src.map,x=src.x,y=src.y})
  end
  for _,item in pairs(self.db.recipeFinds) do
   if type(item)=='table' and item.recipe==e.name then
    for _,f in pairs(item.drops or {}) do add(e,{kind='drop',text='Looted from '..f.name..', '..self.TrainerWhere(self,f),seen=true,map=f.map,x=f.x,y=f.y}) end
    for _,f in pairs(item.quests or {}) do add(e,{kind='quest',text='Quest reward: '..f.name..', '..self.TrainerWhere(self,f),seen=true,map=f.map,x=f.x,y=f.y}) end
   end
  end
  table.sort(e.sources,function(a,b)
   if (a.seen and true or false)~=(b.seen and true or false) then return a.seen==true end
   if (a.other and true or false)~=(b.other and true or false) then return not a.other end
   if (a.ext and true or false)~=(b.ext and true or false) then return a.ext==true end
   if (a.origin=='forever')~=(b.origin=='forever') then return a.origin=='forever' end
   if (a.map and true or false)~=(b.map and true or false) then return a.map~=nil end
   return a.text<b.text end)
  e.seenText=nil
  e.other=#e.sources>0 and e.sources[1].other or nil
 end
 local skill=tonumber(p.skill) or 0
 table.sort(list,function(a,b)
  if (a.other and true or false)~=(b.other and true or false) then return not a.other end
  local an,bn=(a.skill or 999)<=skill,(b.skill or 999)<=skill
  if an~=bn then return an end
  if (a.skill or 999)~=(b.skill or 999) then return (a.skill or 999)<(b.skill or 999) end
  return a.name<b.name
 end)
 local now,other=0,0
 for _,e in ipairs(list) do if e.other then other=other+1 elseif (e.skill or 999)<=skill then now=now+1 end end
 return list,{known=knownCount,learnNow=now,otherFaction=other,skill=skill,profession=prof,external=extRows and true or nil}
end

-- Point at a recorded source: TomTom if present, otherwise the game's map pin.
function N:PointToSource(name,src)
 if not (src and src.map and self:Finite(src.x,0,1) and self:Finite(src.y,0,1)) then
  return self:Print('No position recorded for that source yet.')
 end
 local tt=rawget(_G,'TomTom')
 if self.db.settings.tomtom and type(tt)=='table' and type(tt.AddWaypoint)=='function' then
  local ok=pcall(tt.AddWaypoint,tt,src.map,src.x,src.y,{title=tostring(name),persistent=false,minimap=true,world=true,from='VoidMark Nexus'})
  if ok then return self:Print('TomTom waypoint set: '..tostring(name)..'.') end
 end
 local point=UiMapPoint and UiMapPoint.CreateFromCoordinates and self:Call(UiMapPoint.CreateFromCoordinates,src.map,src.x,src.y)
 if point and C_Map and C_Map.SetUserWaypoint then
  pcall(C_Map.SetUserWaypoint,point)
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
  return self:Print('Map pin set: '..src.text)
 end
 self:Print(src.text)
end

-- Rebuilt only when something it depends on changes (recorded sources, the
-- profession scan, skill, faction), not on every redraw or keystroke.
local buildMissing=N.MissingRecipes
local missingCache
function N:MissingRecipes(cid,pid)
 local c=cid and self.db.characters[cid]; local p=c and c.professions and c.professions[pid]
 if not p then return buildMissing(self,cid,pid) end
 local key=table.concat({tostring(cid),tostring(pid),tostring(self.recipeSourceVersion or 0),tostring(p.at),tostring(p.skill),
  tostring(p.recipes),tostring(self.db.trainers),tostring(self.db.recipeFinds),tostring(self.db.recipeVendors),tostring(c.faction)},'|')
 if missingCache and missingCache.key==key and missingCache.db==self.db then return missingCache.list,missingCache.sum end
 local list,sum=buildMissing(self,cid,pid)
 missingCache={key=key,db=self.db,list=list,sum=sum}
 return list,sum
end
function N:ClearMissingCache() missingCache=nil end

local TIP_SOURCES=14
local function sourceTag(s)
 local tag=s.seen and '[seen] ' or s.origin=='forever' and '[Forever data] ' or (s.ext or s.data) and '[Classic data] ' or ''
 if s.other and not s.seen then tag=tag:gsub('%] $',', other faction] ') end
 return tag
end

-- Rows for the Professions > Missing view.
function N:RenderMissing(u,c,p,colorRow,COLORS)
 local rows={}
 local list,sum=self:MissingRecipes(u.character,u.profession)
 local query=lower(u.search and u.search:GetText() or '')
 local filter,filterLabel=self:RecipeSourceFilter()
 local category=self.RecipeSourceCategory
 local shown=0
 for _,e in ipairs(list) do
  local srcs=e.sources
  if filter~='all' then
   srcs={}
   for _,s in ipairs(e.sources) do if category(s.kind)==filter then srcs[#srcs+1]=s end end
  end
  if #srcs>0 or filter=='all' then
  if query=='' or lower(e.name):find(query,1,true) then
   shown=shown+1
   if shown<=LIMIT_ROWS then
    local first=srcs[1]
    local where=first and first.text or 'Source not known yet. Nexus notes it when you see it.'
    local canNow=(e.skill or 999)<=sum.skill and not e.other
    local color=e.other and COLORS.gray or canNow and COLORS.good or (e.skill and COLORS.white or COLORS.gray)
    local mappable=0; for _,s in ipairs(srcs) do if s.map then mappable=mappable+1 end end
    rows[#rows+1]=colorRow({text=e.name..(e.skill and ('  ('..e.skill..')') or '')..'   '..where,
     item=e.item,title=e.name,
     click=function() self:ChooseRecipeSource(e.name,srcs,u.search) end,
     tip=function(tt)
      tt:AddLine(e.skill and ('Needs '..p.name..' '..e.skill) or 'Skill needed: unknown',1,.82,0)
      if #srcs==0 then tt:AddLine('No source known yet. Visit vendors and trainers, or loot it, and Nexus records where.',.8,.8,.8,true) end
      for i,s in ipairs(srcs) do
       if i>TIP_SOURCES then tt:AddLine('...and '..(#srcs-TIP_SOURCES)..' more. Click to see the ones on the map.',.6,.6,.6); break end
       tt:AddLine(sourceTag(s)..s.text,s.seen and .4 or .75,s.seen and 1 or .75,s.seen and .5 or .75,true)
      end
      if mappable==1 then tt:AddLine('Click: set a waypoint.',.6,.6,.6)
      elseif mappable>1 then tt:AddLine('Click: pick one of '..mappable..' places for a waypoint.',.6,.6,.6) end
     end},color)
   end
  end
  end
 end
 u.profInfo:SetText(string.format('%d missing (%d you can learn now at %d). You know %d.%s',shown,sum.learnNow or 0,sum.skill or 0,sum.known,
  shown>LIMIT_ROWS and (' Showing the first '..LIMIT_ROWS..'; search to narrow.') or '')..(filter~='all' and (' Showing: '..filterLabel..'.') or '')
  ..(sum.external and ' Sources: Forever data + seen in game.' or ' Sources: Classic data + seen in game.'))
 u.footer:SetText('Green: learnable at your skill. Grey: only an other-faction source is known. Hover for sources; click for a waypoint.')
 return rows
end

--------------------------------------------------------------------------------
-- Button on the game's profession window
--------------------------------------------------------------------------------
function N:ShowMissing()
 self:Show('Professions'); local u=self.ui; u.profView='missing'; u.offset=0
 if self.activeProfession then u.character,u.profession=self.characterID,self.activeProfession end
 self.dirty=true; self:Render()
end
function N:AttachMissingButton()
 if self.missingButton or self:Call(InCombatLockdown) then return end
 local host=rawget(_G,'ProfessionsFrame') or rawget(_G,'TradeSkillFrame')
 if type(host)~='table' or not host.IsShown then return end
 local b=CreateFrame('Button',nil,host,'UIPanelButtonTemplate')
 -- Small "MR" at the far right so it never covers the skill bar or its chat icon.
 b:SetSize(36,22); b:SetPoint('TOPRIGHT',host,'TOPRIGHT',-10,-28); b:SetText('MR')
 b:SetScript('OnEnter',function() GameTooltip:SetOwner(b,'ANCHOR_RIGHT'); GameTooltip:SetText('Missing recipes'); GameTooltip:AddLine('Recipes you do not know yet and where to get them.',1,1,1,true); GameTooltip:Show() end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 if b.SetFrameStrata then b:SetFrameStrata('HIGH') end
 b:SetScript('OnClick',function() N:Guard('missing',function() N:ShowMissing() end) end)
 self.missingButton=b
end
N:On('TRADE_SKILL_SHOW',function() N:Later('missingButton',function() N:AttachMissingButton() end) end)
N:AddCommand('missing',function(self,args)
 if self:Text(args) and args~='' then
  self:Show('Professions')
  for _,e in ipairs(self:ProfessionChoices()) do
   local c=self.db.characters[e.cid]; local p=c and c.professions[e.pid]
   if e.cid==self.characterID and p and lower(p.name):find(lower(args),1,true) then self.ui.character,self.ui.profession=e.cid,e.pid end
  end
  self.ui.profView='missing'; self.ui.offset=0; self.dirty=true; return self:Render()
 end
 self:ShowMissing()
end,'/vmn missing [profession] (recipes you have not learned and where to get them)')
