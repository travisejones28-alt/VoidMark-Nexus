local _, N = ...
function N:Position()
 if not C_Map then return end
 local map=self:Call(C_Map.GetBestMapForUnit,'player'); local p=map and self:Call(C_Map.GetPlayerMapPosition,map,'player')
 if p and p.GetXY then local x,y=p:GetXY(); if self:Finite(x,0,1) and self:Finite(y,0,1) then return map,x,y end end
end
-- City map entries in the imported gathering dataset are false positives.
-- Keep their raw source data for auditability, but never use them for display or routes.
local nexusCityMaps = {
 [1453]=true, -- Stormwind
 [1455]=true, -- Ironforge
 [1454]=true, -- Orgrimmar
 [1456]=true, -- Thunder Bluff
 [1457]=true, -- Darnassus
 [1458]=true, -- Undercity
 [84]=true, [87]=true, -- modern client city UI map IDs
 [85]=true, [88]=true, [89]=true, [90]=true
}
function N:IsGatheringCityMap(map)
 return nexusCityMaps[tonumber(map)]==true
end
function N:ZoneNodes(map,kindOverride,targetOverride)
 if self:IsGatheringCityMap(map) then return {} end
 local out,seen={},{}
 local s=self.db.settings
 local selectedKind=kindOverride or s.kind
 local selectedTarget=targetOverride~=nil and targetOverride or s.target
 local function add(object,x,y,source,at)
  local kind=self.nodeTypes[object]; if not kind or (selectedKind~='all' and kind.kind~=selectedKind) then return end
  if selectedTarget~='' and not kind.name:lower():find(selectedTarget:lower(),1,true) then return end
  if kindOverride==nil and targetOverride==nil and s.routeSelectionMode=='multi' then
   if type(s.routeResources)~='table' or not s.routeResources[kind.name] then return end
  end
  local key=tostring(object)..':'..math.floor(x*500+.5)..':'..math.floor(y*500+.5)
  if seen[key] then if source=='Observed' then out[seen[key]].source=source; out[seen[key]].at=at end; return end
  out[#out+1]={object=object,x=x,y=y,source=source,at=at,map=map,name=kind.name,kind=kind.kind,skill=kind.skill}; seen[key]=#out
 end
 if s.importedNodes then for object,maps in pairs(self.spawns or {}) do
  local points=maps[map]; if points then for i=1,#points,2 do add(object,points[i],points[i+1],'Potential spawn') end end
 end end
 if s.observedNodes then for _,p in pairs(self.db.nodes[map] or {}) do add(p.object,p.x,p.y,'Observed',p.at) end end
 return out
end
function N:LearnNode(object,map,x,y)
 if not self.db.settings.learn or not self.nodeTypes[object] then return end
 self.db.nodes[map]=self.db.nodes[map] or {}; local nodes=self.db.nodes[map]
 local key=object..':'..math.floor(x*500+.5)..':'..math.floor(y*500+.5)
 local count=0; for _ in pairs(nodes) do count=count+1 end
 if count>=3000 and not nodes[key] then return end
 nodes[key]={object=object,x=x,y=y,at=self:Now()}; self.dirty=true
end
function N:StartSession()
 self.session={started=self:Now(),character=self.characterID,items={},zones={},kinds={},total=0}
 self.dirty=true
end
function N:SaveSession()
 if not self.session then return end
 self.session.finished=self:Now(); table.insert(self.db.sessions,self:Copy(self.session))
 while #self.db.sessions>100 do table.remove(self.db.sessions,1) end
 self:StartSession()
end
function N:SessionStats(session)
 session=session or self.session; if not session then return 0,0,nil end
 local seconds=math.max(1,(session.finished or self:Now())-session.started); local value,unknown=0,false
 for id,qty in pairs(session.items) do local p=self:Price(id); if p then value=value+p.unit*qty else unknown=true end end
 return seconds,session.total/seconds*3600,not unknown and value/seconds*3600 or nil
end
local spells={[2575]='ore',[2366]='herb',[8613]='leather',[7620]='fish'}
N:On('UNIT_SPELLCAST_SENT',function(unit,target,cast,spell)
 if N:Text(unit)~='player' then return end
 N.gatherCast=nil
 if not spells[spell] then return end
 local map,x,y=N:Position(); if not map then return end
 local object
 for id,kind in pairs(N.nodeTypes) do if kind.name:lower()==tostring(target):lower() then object=id; break end end
 N.gatherCast={cast=cast,spell=spell,kind=spells[spell],object=object,map=map,x=x,y=y}
end)
N:On('UNIT_SPELLCAST_SUCCEEDED',function(unit,cast,spell)
 local g=N.gatherCast
 if N:Text(unit)=='player' and g and g.cast==cast and g.spell==spell then
  g.at=N:Now(); if g.object then N:LearnNode(g.object,g.map,g.x,g.y) end
 end
end)
for _,event in ipairs({'UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED'}) do
 N:On(event,function(unit,cast) if unit=='player' and N.gatherCast and N.gatherCast.cast==cast then N.gatherCast=nil end end)
end
N:On('LOOT_OPENED',function()
 local g=N.gatherCast; N.lootSlots={}; N.lootGather=nil
 if not g or not g.at or N:Now()-g.at>3 then return end
 N.lootGather=g; N.gatherCast=nil
 for slot=1,(N:Call(GetNumLootItems) or 0) do
  local id=N:ItemID(N:Call(GetLootSlotLink,slot)); local _,name,qty=N:Call(GetLootSlotInfo,slot)
  if id and N:Finite(qty,1,1e6) then N.lootSlots[slot]={id=id,qty=qty,name=name} end
 end
end)
N:On('LOOT_SLOT_CLEARED',function(slot)
 local item=N.lootSlots and N.lootSlots[slot]; local g=N.lootGather
 if not item or not g then return end
 N.lootSlots[slot]=nil
 if not N.db.settings.stats then return end
 if not N.session then N:StartSession() end
 local s=N.session; s.items[item.id]=(s.items[item.id] or 0)+item.qty; s.total=s.total+item.qty
 s.zones[g.map]=(s.zones[g.map] or 0)+item.qty; s.kinds[g.kind]=(s.kinds[g.kind] or 0)+item.qty
 N.db.itemNames[item.id]=item.name; N.dirty=true
end)
N:On('LOOT_CLOSED',function() N.lootSlots=nil; N.lootGather=nil end)
