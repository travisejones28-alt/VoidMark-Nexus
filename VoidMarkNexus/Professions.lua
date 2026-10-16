local _, N = ...
function N:ScanProfessions()
 local c=self.character
 local function save(key,name,skill,max,icon)
  if not self:Text(name) then return end
  key=tostring(key or name); local p=c.professions[key] or {recipes={}}
  p.name,p.skill,p.max,p.icon,p.at=name,tonumber(skill) or 0,tonumber(max) or 0,icon,self:Now(); c.professions[key]=p
 end
 if GetProfessions and GetProfessionInfo then
  local ids={self:Call(GetProfessions)}
  for _,id in pairs(ids) do local name,icon,skill,max,_,_,line=self:Call(GetProfessionInfo,id); save(line,name,skill,max,icon) end
 end
 -- Capture every skill line offered by Forever, including unknown custom lines.
 local api=C_SkillInfo
 if api and api.GetNumSkillLines and api.GetSkillLineInfo then
  for i=1,(self:Call(api.GetNumSkillLines) or 0) do
   local s=self:Call(api.GetSkillLineInfo,i)
   if type(s)=='table' and not s.isHeader and s.isProfession then save(s.skillLineID,s.name,s.rank,s.maxRank) end
  end
 end
 c.at=self:Now(); self.dirty=true
end
function N:OwnProfession()
 local api=C_TradeSkillUI
 for _,fn in ipairs({'IsTradeSkillLinked','IsTradeSkillGuild','IsNPCCrafting','IsDataSourceChanging'}) do
  if api and self:Call(api[fn]) then return false end
 end
 if self:Call(IsTradeSkillLinked) then return false end
 return true
end
function N:ModernRecipe(id)
 local api=C_TradeSkillUI; local info=self:Call(api.GetRecipeInfo,id)
 if type(info)~='table' or not self:Text(info.name) then return nil end
 local r={name=info.name,learned=info.learned==true or info.isLearned==true,spell=id,adapter='modern',icon=info.icon,
  difficulty=info.relativeDifficulty or info.difficulty,reagents={},at=self:Now(),disabled=info.disabled==true}
 r.source=self:Call(api.GetRecipeSourceText,id); r.link=self:Call(api.GetRecipeItemLink,id); r.output=self:ItemID(r.link) or info.itemID
 r.cooldown=self:Call(api.GetRecipeCooldown,id)
 local s=self:Call(api.GetRecipeSchematic,id,false)
 if type(s)=='table' then
  r.output=s.outputItemID or r.output; r.outputMin=s.quantityMin or 1; r.outputMax=s.quantityMax or r.outputMin
  for _,slot in ipairs(s.reagentSlotSchematics or {}) do
   if slot.required~=false and (slot.quantityRequired or 0)>0 then
    local g=slot.reagents and slot.reagents[1]; local item=g and (g.itemID or g.item and g.item.itemID)
    r.reagents[#r.reagents+1]={id=item,qty=slot.quantityRequired}
    if not item or #(slot.reagents or {})~=1 then r.incomplete=true end
   end
  end
 else r.incomplete=true end
 if r.output then
  local facts={self:Call(GetItemInfo,r.output)}; r.bound=facts[14]==1
 end
 return r
end
function N:ScanModern()
 local api=C_TradeSkillUI
 if not (api and api.GetAllRecipeIDs and api.GetRecipeInfo) then return false end
 local ids=self:Call(api.GetAllRecipeIDs); local info=self:Call(api.GetBaseProfessionInfo)
 if type(ids)~='table' or #ids==0 or type(info)~='table' or not self:Text(info.professionName or info.name) then return false end
 local pid=tostring(info.professionID or info.skillLineID or info.professionName or info.name)
 local c=self.character; local p=c.professions[pid] or {recipes={}}
 p.name=info.professionName or info.name; p.skill=info.skillLevel or p.skill or 0; p.max=info.maxSkillLevel or p.max or 0
 p.recipes=p.recipes or {}; c.professions[pid]=p; self.activeProfession=pid
 self.scanToken=(self.scanToken or 0)+1; local token=self.scanToken; local cursor=1
 local function batch()
  if token~=self.scanToken or not self:OwnProfession() then return end
  local current=N:Call(api.GetBaseProfessionInfo)
  if not current or tostring(current.professionID or current.skillLineID or current.professionName or current.name)~=pid then return end
  for i=1,30 do
   local id=ids[cursor]; if not id then p.at=N:Now(); c.at=N:Now(); N.dirty=true; return end
   local r=N:ModernRecipe(id); if r then p.recipes[tostring(id)]=r end; cursor=cursor+1
  end
  N.dirty=true
  if C_Timer and C_Timer.After then C_Timer.After(.01,function() N:Guard('recipe scan',batch) end) else batch() end
 end
 batch(); return true
end
function N:ScanLegacy(craft)
 local count=craft and self:Call(GetNumCrafts) or self:Call(GetNumTradeSkills)
 local name,skill,max
 if craft then name,skill,max=self:Call(GetCraftDisplaySkillLine) else name,skill,max=self:Call(GetTradeSkillLine) end
 if not self:Text(name) or name=='UNKNOWN' or not self:Finite(count,1,10000) then return false end
 local pid=name
 for key,p in pairs(self.character.professions) do if p.name==name then pid=key; break end end
 local p=self.character.professions[pid] or {recipes={}}; p.name,p.skill,p.max,p.at=name,skill or 0,max or 0,self:Now()
 self.character.professions[pid]=p; self.activeProfession=pid
 for index=1,count do
  local rname,difficulty,available
  if craft then local sub; rname,sub,difficulty,available=self:Call(GetCraftInfo,index) else rname,difficulty,available=self:Call(GetTradeSkillInfo,index) end
  if rname and difficulty~='header' then
   local r={name=rname,difficulty=difficulty,learned=true,index=index,adapter=craft and 'craft' or 'legacy',reagents={},at=self:Now()}
   r.link=self:Call(craft and GetCraftItemLink or GetTradeSkillItemLink,index); r.output=self:ItemID(r.link)
   local spellLink=self:Call(craft and GetCraftItemLink or GetTradeSkillRecipeLink,index)
   r.spell=spellLink and tonumber(spellLink:match('enchant:(%d+)') or spellLink:match('spell:(%d+)'))
   r.icon=self:Call(craft and GetCraftIcon or GetTradeSkillIcon,index)
   r.outputMin,r.outputMax=self:Call(craft and GetCraftNumMade or GetTradeSkillNumMade,index)
   r.outputMin=r.outputMin or 1; r.outputMax=r.outputMax or r.outputMin
   local n=self:Call(craft and GetCraftNumReagents or GetTradeSkillNumReagents,index)
   if not n then r.incomplete=true end
   for j=1,n or 0 do
    local reagentName,_,qty=self:Call(craft and GetCraftReagentInfo or GetTradeSkillReagentInfo,index,j)
    local link=self:Call(craft and GetCraftReagentItemLink or GetTradeSkillReagentItemLink,index,j)
    local id=self:ItemID(link); r.reagents[#r.reagents+1]={id=id,name=reagentName,qty=qty or 1}
    if not id then r.incomplete=true end
   end
   p.recipes[tostring(r.spell or rname)]=r
  end
 end
 self.character.at=self:Now(); self.dirty=true; return true
end
function N:ScanRecipes(craft)
 if not self:OwnProfession() then return end
 self:ScanProfessions()
 local found=not craft and self:ScanModern()
 if not found then found=self:ScanLegacy(craft) end
 if found and not self.db.settings.native and not self:Call(InCombatLockdown) and (not self.ui or not self.ui.frame:IsShown()) then
  self:Show('Recipes'); self.ui.character=self.characterID; self.ui.profession=self.activeProfession
  -- Keep Blizzard's window alive: hiding it can close its data source on Forever.
 end
end
function N:Craft(ref,qty)
 if ref.character~=self.characterID then return self:Print('Offline characters are browse-only. Log into the crafting character.') end
 if not self:OwnProfession() or ref.profession~=self.activeProfession or self:Call(InCombatLockdown) then return self:Print('Open this character\'s profession outside combat first.') end
 local r=self:Recipe(ref); if not r or not r.learned or r.disabled or r.incomplete then return self:Print('Recipe unavailable or incomplete; use the native window.') end
 qty=math.min(9999,math.max(1,math.floor(tonumber(qty) or 1)))
 if r.cooldown and r.cooldown>0 then return self:Print('Refresh the profession cooldown before crafting.') end
 if r.adapter=='modern' and C_TradeSkillUI then
  local current=self:Call(C_TradeSkillUI.GetRecipeInfo,r.spell)
  if not current or not current.learned then return self:Print('Recipe is no longer available.') end
  local ok,err=pcall(C_TradeSkillUI.CraftRecipe,r.spell,qty); if not ok then self:Print('Use the native crafting button: '..tostring(err)) end
 else
  local fn=r.adapter=='craft' and GetCraftInfo or GetTradeSkillInfo
  local getLink=r.adapter=='craft' and GetCraftItemLink or GetTradeSkillRecipeLink
  local count=self:Call(r.adapter=='craft' and GetNumCrafts or GetNumTradeSkills) or 0
  for index=1,count do
   local name=self:Call(fn,index); local link=self:Call(getLink,index)
   local spell=link and tonumber(link:match('enchant:(%d+)') or link:match('spell:(%d+)'))
   if (r.spell and spell==r.spell) or (not r.spell and name==r.name) then
    local action=r.adapter=='craft' and DoCraft or DoTradeSkill
    local ok,err=pcall(action,index,qty); if not ok then self:Print('Use native crafting: '..tostring(err)) end; return
   end
  end
  self:Print('Recipe is filtered or unavailable. Open it in the native window.')
 end
end
N:On('SKILL_LINES_CHANGED',function() N:Later('skills',function() N:ScanProfessions() end) end)
for _,event in ipairs({'TRADE_SKILL_SHOW','TRADE_SKILL_LIST_UPDATE','TRADE_SKILL_DATA_SOURCE_CHANGED'}) do
 N:On(event,function() N:Later('recipes',function() N:ScanRecipes(false) end) end)
end
N:On('CRAFT_SHOW',function() N:ScanRecipes(true) end)
N:On('TRADE_SKILL_CLOSE',function() N.activeProfession=nil; N.scanToken=(N.scanToken or 0)+1 end)
N:On('CRAFT_CLOSE',function() N.activeProfession=nil end)
