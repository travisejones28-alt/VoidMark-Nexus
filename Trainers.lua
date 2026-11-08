local _, N = ...
-- Trainer and recipe-vendor knowledge, recorded from what you actually see in
-- game. Nexus ships no trainer/vendor database; every entry here comes from a
-- trainer or merchant window you opened, with its NPC name, zone and position.

local MAX_NPCS,MAX_SERVICES,MAX_RECIPE_ITEMS=200,600,3000
local RECIPE_PREFIX={'Recipe: ','Plans: ','Pattern: ','Schematic: ','Formula: ','Manual: '}

function N:RecipeNameFromItem(name)
 if type(name)~='string' then return nil end
 for _,p in ipairs(RECIPE_PREFIX) do if name:sub(1,#p)==p then return name:sub(#p+1) end end
end

local function npcKey(self)
 local name=self:Call(UnitName,'npc')
 if not self:Text(name) then return nil end
 local map,x,y=self:Position()
 return name..'@'..tostring(map or 0),name,map,x,y
end

local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end

function N:ScanTrainer()
 if type(GetNumTrainerServices)~='function' then return end
 if type(IsTradeskillTrainer)=='function' and not self:Call(IsTradeskillTrainer) then return end
 local key,name,map,x,y=npcKey(self);if not key then return end
 local total=self:Call(GetNumTrainerServices)
 if not self:Finite(total,1,MAX_SERVICES) then return end
 local root=self.db.trainers
 local services,profession={},nil
 for i=1,total do
  local service,rank,category=self:Call(GetTrainerServiceInfo,i)
  if self:Text(service) and category~='header' then
   local skillName,skillLevel=self:Call(GetTrainerServiceSkillReq,i)
   local cost=self:Call(GetTrainerServiceCost,i)
   local level=self:Call(GetTrainerServiceLevelReq,i)
   if self:Text(skillName) then profession=profession or skillName end
   services[service]={rank=self:Text(rank),skill=self:Finite(skillLevel,0,1000) and skillLevel or nil,
    cost=self:Finite(cost,0,1e10) and cost or nil,level=self:Finite(level,0,200) and level or nil}
  end
 end
 if not profession then
  -- Rank services (e.g. Journeyman) name the profession themselves.
  for s in pairs(services) do for _,c in pairs(self.db.characters) do for _,p in pairs(c.professions or {}) do
   if p.name and s:find(p.name,1,true) then profession=p.name end end end end
 end
 if not profession then return end
 root[profession]=type(root[profession])=='table' and root[profession] or {}
 local list=root[profession]
 if not list[key] and count(list)>=MAX_NPCS then return end
 local entry=type(list[key])=='table' and list[key] or {services={}}
 entry.name,entry.map,entry.x,entry.y,entry.at=name,map,x,y,self:Now()
 entry.services=type(entry.services)=='table' and entry.services or {}
 -- Merge: the trainer's filter may hide some services this visit.
 for s,info in pairs(services) do entry.services[s]=info end
 list[key]=entry;self.dirty=true
end

function N:ScanMerchant()
 if type(GetMerchantNumItems)~='function' then return end
 local key,name,map,x,y=npcKey(self);if not key then return end
 local total=self:Call(GetMerchantNumItems)
 if not self:Finite(total,1,500) then return end
 local root=self.db.recipeVendors
 for i=1,total do
  local itemName,_,price,stack,available=self:Call(GetMerchantItemInfo,i)
  local link=self:Call(GetMerchantItemLink,i)
  local id=self:ItemID(link)
  local recipe=self:RecipeNameFromItem(itemName)
  if id and recipe then
   if not root[id] and count(root)>=MAX_RECIPE_ITEMS then return end
   local item=type(root[id])=='table' and root[id] or {vendors={}}
   item.name,item.recipe=itemName,recipe
   item.vendors=type(item.vendors)=='table' and item.vendors or {}
   if item.vendors[key] or count(item.vendors)<20 then
    item.vendors[key]={name=name,map=map,x=x,y=y,price=self:Finite(price,0,1e10) and price or nil,
     limited=self:Finite(available,0,1e4) and available>=0 and available or nil,at=self:Now()}
   end
   root[id]=item;self.dirty=true
  end
 end
end

local function where(self,e)
 local zone=e.map and C_Map and C_Map.GetMapInfo and self:Call(C_Map.GetMapInfo,e.map)
 zone=type(zone)=='table' and zone.name or (e.map and ('map '..e.map)) or 'unknown zone'
 if self:Finite(e.x,0,1) and self:Finite(e.y,0,1) then return string.format('%s (%.1f, %.1f)',zone,e.x*100,e.y*100) end
 return zone
end
N.TrainerWhere=where

-- Where a recipe of this name can be learned, from recorded trainers/vendors.
function N:RecipeSources(profession,recipeName)
 local out={}
 if not self:Text(recipeName) then return out end
 for key,t in pairs(self.db.trainers[profession] or {}) do
  local s=type(t)=='table' and type(t.services)=='table' and t.services[recipeName]
  if s then out[#out+1]={kind='trainer',npc=t.name,where=where(self,t),skill=s.skill,cost=s.cost,map=t.map,x=t.x,y=t.y} end
 end
 for _,item in pairs(self.db.recipeVendors) do
  if type(item)=='table' and item.recipe==recipeName then
   for _,v in pairs(item.vendors or {}) do out[#out+1]={kind='vendor',npc=v.name,where=where(self,v),cost=v.price,limited=v.limited,map=v.map,x=v.x,y=v.y} end
  end
 end
 table.sort(out,function(a,b) return (a.cost or 1e15)<(b.cost or 1e15) end)
 return out
end
function N:SourceText(src)
 return (src.kind=='trainer' and 'Trainer ' or 'Vendor ')..tostring(src.npc)..', '..src.where..
  (src.skill and (' | needs skill '..src.skill) or '')..(src.cost and (' | '..self:Money(src.cost)) or '')..(src.limited and ' | limited supply' or '')
end

-- Recorded trainer services this character has not learned yet, up to a skill.
function N:TrainableRecipes(profession,known,maxSkill)
 local seen,out={},{}
 for _,t in pairs(self.db.trainers[profession] or {}) do
  for s,info in pairs(type(t)=='table' and t.services or {}) do
   if not known[s] and not seen[s] and info.skill and info.skill<=maxSkill and not s:find(profession,1,true) then
    seen[s]=true;out[#out+1]={name=s,skill=info.skill,cost=info.cost,npc=t.name,where=where(self,t)}
   end
  end
 end
 table.sort(out,function(a,b) if a.skill==b.skill then return a.name<b.name end return a.skill<b.skill end)
 return out
end
-- Nearest recorded trainer for rank training.
function N:TrainersFor(profession)
 local out={}
 for _,t in pairs(self.db.trainers[profession] or {}) do if type(t)=='table' then out[#out+1]={npc=t.name,where=where(self,t),at=t.at} end end
 table.sort(out,function(a,b) return (a.at or 0)>(b.at or 0) end)
 return out
end

N:On('TRAINER_SHOW',function() N:Later('trainer',function() N:ScanTrainer() end) end)
N:On('TRAINER_UPDATE',function() N:Later('trainer',function() N:ScanTrainer() end) end)
N:On('MERCHANT_SHOW',function() N:Later('merchant',function() N:ScanMerchant() end) end)
