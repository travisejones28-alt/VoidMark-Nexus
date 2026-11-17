local _, N = ...
-- Recorded recipe sources (recipe loot, quest rewards, recipe vendors) shared between
-- accounts: automatically over the paired-character sync (Sync.lua, section "recipes"),
-- or by hand with /vmn exportrecipes and /vmn importrecipes.
-- Only recipe facts and places are included: no character names, chat or messages.
-- Imports and sync are validated in full before anything is written, never delete
-- local records, and only replace a place with a newer observation of the same place.

local MAX_ITEMS,MAX_SPOTS=3000,20
local FIELDS={finds={'recipeFinds',{'drops','quests'}},vendors={'recipeVendors',{'vendors'}}}
local function num(v,lo,hi) return type(v)=='number' and v==v and v>=lo and v<=hi end
local function text(v) return type(v)=='string' and #v>0 and #v<=200 end
local function cleanSpot(v)
 if type(v)~='table' or not text(v.name) then return nil end
 local out={name=v.name}
 if num(v.map,1,1e6) and v.map%1==0 then out.map=v.map end
 if out.map and num(v.x,0,1) and num(v.y,0,1) then out.x,out.y=v.x,v.y end
 if num(v.at,0,4e9) then out.at=v.at end
 if num(v.seen,0,1e6) then out.seen=v.seen end
 if num(v.price,0,1e10) then out.price=v.price end
 if num(v.limited,0,1e4) then out.limited=v.limited end
 return out
end

-- Anything that changes recorded recipe sources calls this: the Missing list and the
-- sync payload are rebuilt only after a change.
function N:RecipeSourcesChanged() self.recipeSourceVersion=(self.recipeSourceVersion or 0)+1 end

function N:RecipeSyncPayload()
 local out={kind='recipe-sources',schema=1}
 for k,def in pairs(FIELDS) do
  local list,n={},0
  for id,r in pairs(self.db[def[1]] or {}) do
   if n>=MAX_ITEMS then break end
   if num(id,1,1e9) and id%1==0 and type(r)=='table' and text(r.recipe) then
    local e={recipe=r.recipe,name=text(r.name) and r.name or nil,profession=text(r.profession) and r.profession or nil}
    local any=false
    for _,sub in ipairs(def[2]) do
     local spots,c={},0
     for key,place in pairs(type(r[sub])=='table' and r[sub] or {}) do
      if c>=MAX_SPOTS then break end
      local s=text(key) and cleanSpot(place)
      if s then spots[key]=s;c=c+1;any=true end
     end
     if c>0 then e[sub]=spots end
    end
    if any then list[id]=e;n=n+1 end
   end
  end
  out[k]=list
 end
 return out
end

-- Encoded once per change; Sync.lua asks for it on every hello.
function N:RecipeSyncSection(hash)
 local c=self.recipeSyncCache
 if c and c.version==(self.recipeSourceVersion or 0) and c.db==self.db then return c.section end
 local raw=self:EncodeData(self:RecipeSyncPayload())
 c={version=self.recipeSourceVersion or 0,db=self.db,section={raw=raw,hash=hash(raw)}}
 self.recipeSyncCache=c
 return c.section
end

local function validate(data)
 if type(data)~='table' or data.kind~='recipe-sources' or data.schema~=1 then return nil,'Not a Nexus recipe-source export.' end
 local items,places=0,0
 for k,def in pairs(FIELDS) do
  local list=data[k]
  if type(list)~='table' then return nil,'Missing '..k..'.' end
  local n=0
  for id,e in pairs(list) do
   n=n+1
   if n>MAX_ITEMS then return nil,'Too many recipe records.' end
   if not (num(id,1,1e9) and id%1==0) or type(e)~='table' or not text(e.recipe)
    or (e.name~=nil and not text(e.name)) or (e.profession~=nil and not text(e.profession)) then return nil,'Invalid recipe record.' end
   for _,sub in ipairs(def[2]) do
    local spots=e[sub]
    if spots~=nil then
     if type(spots)~='table' then return nil,'Malformed locations.' end
     local c=0
     for key,v in pairs(spots) do
      c=c+1
      if c>MAX_SPOTS or not text(key) or not cleanSpot(v) then return nil,'Invalid location.' end
     end
     places=places+c
    end
   end
  end
  items=items+n
 end
 return items,places
end
N.ValidateRecipeSources=validate

-- Returns the number of places added or updated, or nil and an error. Validates
-- everything first so a bad record never leaves a half-applied import.
function N:MergeRecipeSources(data)
 local ok,err=validate(data)
 if not ok then return nil,err end
 local now=self:Now(); local changed=0
 for k,def in pairs(FIELDS) do
  local root=self.db[def[1]]
  if type(root)~='table' then root={};self.db[def[1]]=root end
  local size=0; for _ in pairs(root) do size=size+1 end
  for id,e in pairs(data[k]) do
   local r=root[id]
   if type(r)~='table' and size<MAX_ITEMS then r={};root[id]=r;size=size+1 end
   if type(r)=='table' then
    r.recipe=r.recipe or e.recipe; r.name=r.name or e.name; r.profession=r.profession or e.profession
    for _,sub in ipairs(def[2]) do
     if e[sub] then
      local mine=type(r[sub])=='table' and r[sub] or {}; r[sub]=mine
      local c=0; for _ in pairs(mine) do c=c+1 end
      for key,v in pairs(e[sub]) do
       local s=cleanSpot(v)
       if s.at and s.at>now+300 then s.at=now end -- the other PC's clock was ahead
       local prev=type(mine[key])=='table' and mine[key] or nil
       if not prev then
        if c<MAX_SPOTS then mine[key]=s;c=c+1;changed=changed+1 end
       elseif (s.at or 0)>(prev.at or 0) then
        s.seen=math.max(tonumber(prev.seen) or 0,s.seen or 0)
        if s.seen==0 then s.seen=nil end
        mine[key]=s;changed=changed+1
       end
      end
     end
    end
   end
  end
 end
 if changed>0 then self.dirty=true;self:RecipeSourcesChanged() end
 return changed
end

function N:ExportRecipeSources()
 return self:EncodeData(self:RecipeSyncPayload())
end
function N:PreviewRecipeSourceImport(raw)
 self.pendingImport=nil
 local ok,data=pcall(self.Decode,self,raw)
 if not ok then return nil,tostring(data) end
 local items,places=validate(data)
 if not items then return nil,places end
 self.pendingImport={kind='recipe-sources',data=data}
 return string.format('Import recorded recipe sources: %d recipes, %d places.\nYour own records are kept; a place is only replaced by a newer sighting.',items,places)
end

N:AddCommand('exportrecipes',function(self)
 self:TextDialog('Copy recipe sources to the other account',self:ExportRecipeSources())
end,'/vmn exportrecipes (copy recorded recipe sources)')
N:AddCommand('importrecipes',function(self)
 self:TextDialog('Paste recipe sources from the other account','','recipe-sources')
end,'/vmn importrecipes (paste recipe sources from /vmn exportrecipes)')
