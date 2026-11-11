local _,N=...
-- Profession cooldowns on every character (Mooncloth, transmutes, the Salt
-- Shaker...): read from the game at login and after you craft, synced with the
-- other account, shown on the Characters page and announced when ready.

-- Spells read by name (the game only answers for spells you know). Recipes with
-- a cooldown seen in a profession window are added too, so others are covered.
N.cooldownSpells={'Mooncloth','Transmute: Arcanite','Transmute: Iron to Gold','Transmute: Mithril to Truesilver',
 'Transmute: Undeath to Water','Transmute: Water to Undeath','Transmute: Life to Earth','Transmute: Earth to Life',
 'Transmute: Air to Fire','Transmute: Fire to Earth','Transmute: Earth to Water','Transmute: Water to Air',
 'Transmute: Elemental Fire'}
N.cooldownItems={[15846]='Salt Shaker'}
local GCD=2   -- a cooldown this short is just the global cooldown: ready

local function spellInfo(self,name)
 if C_Spell and C_Spell.GetSpellInfo then
  local info=self:Call(C_Spell.GetSpellInfo,name)
  if type(info)=='table' then return tonumber(info.spellID),info.name end
 end
 if GetSpellInfo then
  local n,_,_,_,_,_,id=self:Call(GetSpellInfo,name)
  if n then return tonumber(id),n end
 end
end
local function spellCooldown(self,spell)
 if C_Spell and C_Spell.GetSpellCooldown then
  local cd=self:Call(C_Spell.GetSpellCooldown,spell)
  if type(cd)=='table' then return tonumber(cd.startTime),tonumber(cd.duration) end
 end
 if GetSpellCooldown then local s,d=self:Call(GetSpellCooldown,spell); return tonumber(s),tonumber(d) end
end
local function itemCooldown(self,id)
 local fn=(C_Container and C_Container.GetItemCooldown) or GetItemCooldown
 if fn then local s,d=self:Call(fn,id); return tonumber(s),tonumber(d) end
end
-- Game-clock start/duration to a wall-clock "ready at".
function N:ReadyAt(start,duration)
 local now=self:Now()
 if not self:Finite(start,0,1e9) or not self:Finite(duration,0,60*86400) or duration<=GCD or start<=0 then return now end
 local clock=GetTime and tonumber((self:Call(GetTime)))
 if not self:Finite(clock,0,1e9) then return nil end
 return math.floor(now+math.max(0,start+duration-clock)+.5)
end

function N:ScanCooldowns()
 local c=self.character; if not c then return end
 local list={}
 for _,name in ipairs(self.cooldownSpells) do
  local id,label=spellInfo(self,name)
  if id then
   local ready=self:ReadyAt(spellCooldown(self,id))
   if ready then list[id]={name=label or name,readyAt=ready} end
  end
 end
 -- Recipes with a cooldown, seen in a profession window (the recipe ID is the spell on this client).
 for _,p in pairs(c.professions or {}) do
  for rid,r in pairs(p.recipes or {}) do
   local id=tonumber(rid)
   if id and r.learned and (tonumber(r.cooldown) or 0)>0 and not list[id] and type(r.name)=='string' then
    local s,d=spellCooldown(self,id)
    local ready=s and self:ReadyAt(s,d) or ((tonumber(r.at) or self:Now())+r.cooldown)
    list[id]={name=r.name,readyAt=ready}
   end
  end
 end
 for id,name in pairs(self.cooldownItems) do
  local have=(c.bags and c.bags[id]) or (c.bank and c.bank[id])
  if have then
   local ready=self:ReadyAt(itemCooldown(self,id))
   if ready then list[id]={name=name,readyAt=ready} end
  end
 end
 c.cooldowns=list; c.cooldownsAt=self:Now(); self.dirty=true
end

-- Every tracked cooldown on every character (older copies skipped), soonest first.
function N:CooldownList()
 local preferred=self.PreferredRecords and self:PreferredRecords() or nil
 local out,now={},self:Now()
 for cid,c in pairs(self.db.characters) do
  if (not preferred or preferred[cid]) and type(c.cooldowns)=='table' then
   for id,cd in pairs(c.cooldowns) do
    if type(cd)=='table' and type(cd.name)=='string' and self:Finite(cd.readyAt,0,1e12) then
     out[#out+1]={id=id,name=cd.name,readyAt=cd.readyAt,ready=cd.readyAt<=now,character=c.name or '?',you=cid==self.characterID}
    end
   end
  end
 end
 table.sort(out,function(a,b) if a.readyAt~=b.readyAt then return a.readyAt<b.readyAt end; return a.character<b.character end)
 return out
end
function N:CooldownText(cd)
 if cd.ready then return cd.name..' ready' end
 local s=cd.readyAt-self:Now()
 local t=s>=86400 and string.format('%dd %dh',math.floor(s/86400),math.floor(s%86400/3600))
  or s>=3600 and string.format('%dh %dm',math.floor(s/3600),math.floor(s%3600/60)) or string.format('%dm',math.max(1,math.floor(s/60)))
 return cd.name..' in '..t
end
-- One line for the Characters page: what's ready, then what's next.
function N:CooldownLine()
 local list=self:CooldownList(); if #list==0 then return nil end
 local parts={}
 for i,cd in ipairs(list) do
  if i>3 then parts[#parts+1]='+'..(#list-3)..' more'; break end
  parts[#parts+1]=self:CooldownText(cd)..' ('..(cd.you and 'you' or cd.character)..')'
 end
 return 'Cooldowns: '..table.concat(parts,'; ')
end
function N:CooldownCommand()
 local list=self:CooldownList()
 if #list==0 then return self:Print('No profession cooldowns seen yet. Log in on each crafter once.') end
 for _,cd in ipairs(list) do self:Print(cd.character..': '..self:CooldownText(cd)) end
end
-- At login: say which cooldowns are ready (once per session).
function N:AnnounceCooldowns()
 if self.cooldownsAnnounced then return end
 self.cooldownsAnnounced=true
 local ready={}
 for _,cd in ipairs(self:CooldownList()) do if cd.ready then ready[#ready+1]=cd.name..' on '..(cd.you and 'this character' or cd.character) end end
 if #ready>0 then self:Print('Ready: '..table.concat(ready,', ')..'.') end
end

N:On('PLAYER_ENTERING_WORLD',function()
 if C_Timer and C_Timer.After then
  C_Timer.After(5,function() N:Guard('cooldowns',function() N:ScanCooldowns(); N:AnnounceCooldowns() end) end)
 end
end)
N:On('UNIT_SPELLCAST_SUCCEEDED',function(unit)
 if unit=='player' and (N.tradeSkillOpen or N.craftOpen) then N:Later('cooldowns',function() N:ScanCooldowns(); if N.SyncSoon then N:SyncSoon() end end) end
end)
N:On('TRADE_SKILL_SHOW',function() N.tradeSkillOpen=true end)
N:On('TRADE_SKILL_CLOSE',function() N.tradeSkillOpen=false; N:Later('cooldowns',function() N:ScanCooldowns() end) end)
N:On('CRAFT_SHOW',function() N.craftOpen=true end)
N:On('CRAFT_CLOSE',function() N.craftOpen=false end)
N:On('BAG_UPDATE_COOLDOWN',function() if N.character and N.character.bags and N.character.bags[15846] then N:Later('cooldowns',function() N:ScanCooldowns() end) end end)
