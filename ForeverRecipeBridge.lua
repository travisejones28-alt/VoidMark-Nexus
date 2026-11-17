local _, N = ...
-- Bundled recipe catalogs: Data/ForeverRecipeCatalog.lua (Forever, used first) and
-- Data/BaseRecipeCatalog.lua (Classic baseline, fills gaps). No other addon is needed.
--
-- Row format: name|skill|item|type|source|area|x|y|faction|zone
-- Memory/CPU: each profession stays a single string until it is viewed. Only the last
-- three viewed professions are kept parsed; zone lookups are resolved once per zone.

local KIND_LABEL={T='Trainer ',V='Vendor ',D='Drop: ',Q='Quest: ',O='Object: ',S='',U=''}
local MAX_CACHED=3
local cache,order={},{}

-- Catalog area ID -> {UI map Forever uses (Classic numbering), modern UI map, English name}.
-- Instances are left out on purpose: their coordinates are not outdoor map positions.
local ZONES={
 [1]={1426,27,'Dun Morogh'},[3]={1418,15,'Badlands'},[4]={1419,17,'Blasted Lands'},
 [8]={1435,51,'Swamp of Sorrows'},[10]={1431,47,'Duskwood'},[11]={1437,56,'Wetlands'},
 [12]={1429,37,'Elwynn Forest'},[14]={1411,1,'Durotar'},[15]={1445,70,'Dustwallow Marsh'},
 [16]={1447,76,'Azshara'},[17]={1413,10,'The Barrens'},[28]={1422,22,'Western Plaguelands'},
 [33]={1434,224,'Stranglethorn Vale'},[36]={1416,nil,'Alterac Mountains'},[38]={1432,48,'Loch Modan'},
 [40]={1436,52,'Westfall'},[41]={1430,42,'Deadwind Pass'},[44]={1433,49,'Redridge Mountains'},
 [45]={1417,14,'Arathi Highlands'},[46]={1428,36,'Burning Steppes'},[47]={1425,26,'The Hinterlands'},
 [51]={1427,32,'Searing Gorge'},[85]={1420,18,'Tirisfal Glades'},[130]={1421,21,'Silverpine Forest'},
 [139]={1423,23,'Eastern Plaguelands'},[141]={1438,57,'Teldrassil'},[148]={1439,62,'Darkshore'},
 [215]={1412,7,'Mulgore'},[267]={1424,25,'Hillsbrad Foothills'},[331]={1440,63,'Ashenvale'},
 [357]={1444,69,'Feralas'},[361]={1448,77,'Felwood'},[400]={1441,64,'Thousand Needles'},
 [405]={1443,66,'Desolace'},[406]={1442,65,'Stonetalon Mountains'},[440]={1446,71,'Tanaris'},
 [490]={1449,78,"Un'Goro Crater"},[493]={1450,80,'Moonglade'},[618]={1452,83,'Winterspring'},
 [1377]={1451,81,'Silithus'},[1497]={1458,90,'Undercity'},[1519]={1453,84,'Stormwind City'},
 [1537]={1455,87,'Ironforge'},[1637]={1454,85,'Orgrimmar'},[1638]={1456,88,'Thunder Bluff'},
 [1657]={1457,89,'Darnassus'},
}
N.RecipeZoneMaps=ZONES
local resolved={}
-- Pick the UI map this client actually has: the Classic ID first, confirmed by name when
-- the client gives English names, otherwise the first ID the client knows.
local function zoneMap(area,zone)
 local z=ZONES[tonumber(area)]
 if not z or z[3]~=zone then return nil end
 local got=resolved[z[1]]
 if got~=nil then return got or nil end
 local pick=z[1]
 local info=C_Map and C_Map.GetMapInfo
 if type(info)=='function' then
  pick=nil
  local function name(id) if not id then return nil end; local ok,i=pcall(info,id); return ok and type(i)=='table' and (i.name or '') or nil end
  for i=1,2 do if name(z[i])==z[3] then pick=z[i];break end end
  if not pick then for i=1,2 do if name(z[i]) then pick=z[i];break end end end
 end
 resolved[z[1]]=pick or false
 return pick
end
N.RecipeZoneMap=zoneMap

-- Same categories for catalog codes and for what Nexus records in game.
local CATEGORY={T='T',trainer='T',V='V',vendor='V',D='D',drop='D',Q='Q',quest='Q',O='O',object='O'}
function N.RecipeSourceCategory(kind) return CATEGORY[kind] or 'S' end

local function catalogText(t,profession)
 if type(t)~='table' then return nil end
 local v=t[profession]
 if v==nil then
  local want=profession:gsub('%s',''):lower()
  for k,s in pairs(t) do if type(k)=='string' and k:gsub('%s',''):lower()==want then v=s;break end end
 end
 return type(v)=='string' and v or nil
end

local function parse(raw,origin,out,byName)
 for line in raw:gmatch('[^\r\n]+') do
  local f={};local i=1
  for v in (line..'|'):gmatch('([^|]*)|') do f[i]=v;i=i+1 end
  local name=f[1] and f[1]:match('^%s*(.-)%s*$')
  if name and name~='' and i>=11 then
   local key=name:lower(); local e=byName[key]
   if not e then
    e={name=name,skill=tonumber(f[2]),item=tonumber(f[3]),sources={},texts={}}
    byName[key]=e;out[#out+1]=e
   else
    e.skill=e.skill or tonumber(f[2]); e.item=e.item or tonumber(f[3])
   end
   local code,zone=f[4],f[10]
   local text=(KIND_LABEL[code] or '')..(f[5]~='' and f[5] or 'Unknown')
   if zone~='' then text=text..' - '..zone end
   local x,y=tonumber(f[7]),tonumber(f[8])
   local map=x and y and x>0 and y>0 and x<=100 and y<=100 and zoneMap(f[6],zone) or nil
   if map then text=text..string.format(' (%.1f, %.1f)',x,y) end
   if not e.texts[text] then
    e.texts[text]=true
    e.sources[#e.sources+1]={text=text,kind=code,origin=origin,faction=(f[9]=='A' or f[9]=='H') and f[9] or nil,
     map=map,x=map and x/100 or nil,y=map and y/100 or nil}
   end
  end
 end
end

-- Rows {name,skill,item,sources={{text,kind,origin,faction,map,x,y}}} or nil when neither
-- catalog has the profession (then the shipped Classic item data is used instead).
function N:CatalogRecipeData(profession)
 if type(profession)~='string' then return nil end
 if cache[profession] then return cache[profession] end
 local forever=catalogText(self.ForeverRecipeData,profession)
 local base=catalogText(self.BaseRecipeData,profession)
 if not forever and not base then return nil end
 local out,byName={},{}
 if forever then parse(forever,'forever',out,byName) end
 if base then parse(base,'base',out,byName) end
 for _,e in ipairs(out) do e.texts=nil end
 cache[profession]=out; order[#order+1]=profession
 if #order>MAX_CACHED then cache[table.remove(order,1)]=nil end
 return out
end
function N:ClearRecipeCatalogCache() cache,order,resolved={},{},{} end

--------------------------------------------------------------------------------
-- Clicking a missing recipe: pick one source to set a waypoint for.
--------------------------------------------------------------------------------
function N:ChooseRecipeSource(name,sources,anchor)
 local list={}
 for _,s in ipairs(sources or {}) do if s.map and self:Finite(s.x,0,1) and self:Finite(s.y,0,1) then list[#list+1]=s end end
 if #list==0 then return self:Print('No map position known for '..tostring(name)..'. Hover the row for where to get it.') end
 if #list==1 then return self:PointToSource(name,list[1]) end
 local choices={}
 for i,s in ipairs(list) do
  if i>40 then break end
  choices[#choices+1]={label=(s.other and '(other faction) ' or '')..s.text,value=i}
 end
 self:Choice(anchor or (self.ui and self.ui.search) or UIParent,choices,function(i) N:PointToSource(name,list[i]) end)
 return list
end

--------------------------------------------------------------------------------
-- Source filter for Professions > Missing.
--------------------------------------------------------------------------------
N.RecipeSourceFilters={{value='all',label='All sources'},{value='T',label='Trainers'},{value='V',label='Vendors'},
 {value='D',label='Drops'},{value='Q',label='Quests'},{value='O',label='Objects'},{value='S',label='Other'}}
function N:RecipeSourceFilter()
 local v=self.db and self.db.settings and self.db.settings.recipeSourceFilter
 for _,o in ipairs(self.RecipeSourceFilters) do if o.value==v then return v,o.label end end
 return 'all','All sources'
end
function N:SetRecipeSourceFilter(v)
 local ok=false; for _,o in ipairs(self.RecipeSourceFilters) do if o.value==v then ok=true end end
 self.db.settings.recipeSourceFilter=(ok and v~='all') and v or nil
 if self.ui then self.ui.offset=0 end
 self.dirty=true
end
function N:RecipeSourceFilterMenu(anchor)
 self:Choice(anchor,self.RecipeSourceFilters,function(v) N:SetRecipeSourceFilter(v) end)
end
