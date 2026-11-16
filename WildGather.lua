local _, N = ...
-- 0.11 skinning and fishing.
--
-- Everything here is learned from what you actually do; nothing is assumed:
--  * Skinning: where you skinned (40-yard cells), which beasts, their levels and
--    what they dropped. These are places beasts were, not corpses waiting for
--    you: spawns move and other players skin too.
--  * Fishing: where you fished, what you caught and, when the client says the
--    loot came from a fishing pool (loot source GUID), where that pool was. You
--    can also mark a pool by hand with /vmn pool NAME.
--  * Sessions: catches or skins per hour, items per hour, gold per hour from
--    prices (unpriced items reported, never counted as zero), skill gained.
-- Level ranges for skinning use the Classic rule (skill (L-10)*10 up to level
-- 20, L*5 above). Zone level ranges are Classic's; Forever may differ.
local CELL=40
local MAX_ZONES,MAX_CELLS,MAX_LOG=60,600,40
local BOBBER=35591          -- the fishing bobber game object
local IDLE=600              -- a session ends after 10 minutes without a catch/skin

local SKIN_SPELLS={[8613]=true,[8617]=true,[8618]=true,[10768]=true}
local FISH_SPELLS={[7620]=true,[7731]=true,[7732]=true,[18248]=true}
N.skinSpells,N.fishSpells=SKIN_SPELLS,FISH_SPELLS
-- Higher skinning ranks count as gathering loot too (rank 1 already did).
for id in pairs(SKIN_SPELLS) do if N.gatherSpells and not N.gatherSpells[id] then N.gatherSpells[id]='leather' end end

N.LEATHER={ -- leather and hides, by tier
 {2934,'Ruined Leather Scraps'},{2318,'Light Leather'},{783,'Light Hide'},{2319,'Medium Leather'},{4232,'Medium Hide'},
 {4234,'Heavy Leather'},{4235,'Heavy Hide'},{4304,'Thick Leather'},{8169,'Thick Hide'},{8170,'Rugged Leather'},{8171,'Rugged Hide'}}
N.ZONE_LEVELS={ -- Classic zone level ranges
 {'Durotar',1,10},{'Mulgore',1,10},{'Tirisfal Glades',1,10},{'Elwynn Forest',1,10},{'Dun Morogh',1,10},{'Teldrassil',1,10},
 {'The Barrens',10,25},{'Silverpine Forest',10,20},{'Westfall',10,20},{'Loch Modan',10,20},{'Darkshore',10,20},
 {'Redridge Mountains',15,25},{'Stonetalon Mountains',15,27},{'Ashenvale',18,30},{'Duskwood',18,30},{'Wetlands',20,30},
 {'Hillsbrad Foothills',20,30},{'Thousand Needles',25,35},{'Alterac Mountains',30,40},{'Arathi Highlands',30,40},
 {'Desolace',30,40},{'Stranglethorn Vale',30,45},{'Dustwallow Marsh',35,45},{'Badlands',35,45},{'Swamp of Sorrows',35,45},
 {'Feralas',40,50},{'Tanaris',40,50},{'The Hinterlands',40,50},{'Searing Gorge',43,50},{'Azshara',45,55},
 {'Blasted Lands',45,55},{"Un'Goro Crater",48,55},{'Felwood',48,55},{'Burning Steppes',50,58},
 {'Western Plaguelands',51,58},{'Eastern Plaguelands',53,60},{'Winterspring',53,60},{'Silithus',55,60}}

local floor=math.floor
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

function N:WildDB()
 local w=self.db.wild
 if type(w)~='table' or (tonumber(w.version) or 0)>1 then
  if type(w)=='table' then self.wildDisabled=true;return nil end -- newer format: leave it alone
  w={version=1};self.db.wild=w
 end
 for _,k in ipairs({'skin','fish','pools','poolNames','log','fishItems','skinItems'}) do if type(w[k])~='table' then w[k]={} end end
 return w
end
local function cellOf(self,map,x,y)
 if not self:Finite(x,0,1) or not self:Finite(y,0,1) then return end
 local w,h=self:MapSize(map);if not w then return end
 return floor(x*w/CELL)..':'..floor(y*h/CELL)
end
local function zoneTable(root,map)
 if type(root[map])=='table' then return root[map] end
 if count(root)>=MAX_ZONES then return end
 root[map]={};return root[map]
end

-- Profession skill by name (Skinning / Fishing) on the current character.
function N:ProfessionSkill(name,id)
 for pid,p in pairs(self.character and self.character.professions or {}) do
  if type(p)=='table' and (p.name==name or tostring(pid)==tostring(id)) and self:Finite(p.skill,0,1000) then return p.skill,p.max end
 end
end

--------------------------------------------------------------------------------
-- Sessions
--------------------------------------------------------------------------------
function N:WildSession(kind)
 local now=self:Now();local s=self.wildSession
 if s and (s.kind~=kind or now-(s.last or s.started)>IDLE) then self:EndWildSession() ;s=nil end
 if not s then
  local skill=self:ProfessionSkill(kind=='fish' and 'Fishing' or 'Skinning',kind=='fish' and 356 or 393)
  s={kind=kind,started=now,last=now,n=0,qty=0,items={},skill=skill,map=self:Position()}
  self.wildSession=s
 end
 return s
end
function N:EndWildSession()
 local s=self.wildSession;self.wildSession=nil
 local w=self:WildDB()
 if not s or not w or s.n==0 then return end
 local skill=self:ProfessionSkill(s.kind=='fish' and 'Fishing' or 'Skinning',s.kind=='fish' and 356 or 393)
 w.log[#w.log+1]={kind=s.kind,started=s.started,finished=s.last,n=s.n,qty=s.qty,items=s.items,map=s.map,
  gain=s.skill and skill and math.max(0,skill-s.skill) or nil}
 while #w.log>MAX_LOG do table.remove(w.log,1) end
 self.dirty=true
end
function N:WildSessionLine(s)
 if not s then return nil end
 local secs=math.max(1,(s.finished or s.last or self:Now())-s.started)
 local value,unpriced,stale,total=self:ItemsValue(s.items)
 local hours=secs/3600
 local skill=s.gain or (s==self.wildSession and s.skill and (self:ProfessionSkill(s.kind=='fish' and 'Fishing' or 'Skinning',s.kind=='fish' and 356 or 393) or s.skill)-s.skill) or 0
 return string.format('%s: %d %s in %.0f min (%.0f/hr), %d items (%.0f/hr), %s%s',s.kind=='fish' and 'Fishing' or 'Skinning',
  s.n,s.kind=='fish' and 'catches' or 'skins',secs/60,s.n/hours,total,total/hours,
  (total>0 and unpriced<total) and (self:Gold(value/hours)..'/hr'..(unpriced>0 and ' (some items unpriced)' or '')..(stale and ' (stale prices)' or '')) or 'gold/hr unknown',
  skill>0 and ('  +'..skill..' skill') or '')
end

--------------------------------------------------------------------------------
-- Recording
--------------------------------------------------------------------------------
function N:RecordSkin(map,x,y,creature,level,items)
 local w=self:WildDB();if not w then return end
 local key=cellOf(self,map,x,y);local z=key and zoneTable(w.skin,map);if not z then return end
 local e=z[key]
 if type(e)~='table' then if count(z)>=MAX_CELLS then return end;e={n=0,qty=0,names={}};z[key]=e end
 e.n=e.n+1;e.at=self:Now()
 if creature and (e.names[creature] or count(e.names)<8) then e.names[creature]=(e.names[creature] or 0)+1 end
 if self:Finite(level,1,100) then e.lo=math.min(e.lo or level,level);e.hi=math.max(e.hi or level,level) end
 local zi=zoneTable(w.skinItems,map)
 for id,q in pairs(items or {}) do
  e.qty=e.qty+q
  if zi and (zi[id] or count(zi)<30) then zi[id]=(zi[id] or 0)+q end
 end
 local s=self:WildSession('skin');s.n=s.n+1;s.last=self:Now()
 for id,q in pairs(items or {}) do s.items[id]=(s.items[id] or 0)+q;s.qty=s.qty+q end
 self.dirty=true
end
function N:RecordCatch(map,x,y,items,pool)
 local w=self:WildDB();if not w then return end
 local key=cellOf(self,map,x,y);local z=key and zoneTable(w.fish,map);if not z then return end
 local e=z[key]
 if type(e)~='table' then if count(z)>=MAX_CELLS then return end;e={n=0,qty=0,pool=0};z[key]=e end
 e.n=e.n+1;e.at=self:Now();if pool then e.pool=e.pool+1 end
 local zi=zoneTable(w.fishItems,map)
 for id,q in pairs(items or {}) do
  e.qty=e.qty+q
  if zi and (zi[id] or count(zi)<30) then zi[id]=(zi[id] or 0)+q end
 end
 if pool then self:RecordPool(map,x,y,pool) end
 local s=self:WildSession('fish');s.n=s.n+1;s.last=self:Now()
 for id,q in pairs(items or {}) do s.items[id]=(s.items[id] or 0)+q;s.qty=s.qty+q end
 self.dirty=true
end
-- A pool seen from here. Stored at your position: pools are within casting range.
function N:RecordPool(map,x,y,id,name)
 local w=self:WildDB();if not w then return end
 local key=cellOf(self,map,x,y);local z=key and zoneTable(w.pools,map);if not z then return end
 local e=z[key]
 if type(e)~='table' then if count(z)>=MAX_CELLS then return end;e={n=0,x=x,y=y};z[key]=e end
 e.n=e.n+1;e.at=self:Now()
 if id then e.id=id end
 if name then e.name=name;if id then w.poolNames[id]=name end end
 self.dirty=true
 return e
end
function N:PoolName(e)
 local w=self:WildDB()
 return (e and e.name) or (e and e.id and w and w.poolNames[e.id]) or (e and e.id and ('Pool '..e.id)) or 'Pool'
end

N:On('UNIT_SPELLCAST_SENT',function(unit,target,cast,spell)
 if N:Text(unit)~='player' then return end
 if FISH_SPELLS[spell] then
  local map,x,y=N:Position()
  if map then N.fishCast={map=map,x=x,y=y,at=N:Now()} end
 elseif SKIN_SPELLS[spell] then
  local map,x,y=N:Position()
  local level=N:Call(UnitLevel,'target')
  N.skinCast={map=map,x=x,y=y,cast=cast,creature=N:Text(target),level=N:Finite(level,1,100) and level or nil}
 end
end)
N:On('UNIT_SPELLCAST_SUCCEEDED',function(unit,cast,spell)
 if unit=='player' and SKIN_SPELLS[spell] and N.skinCast and N.skinCast.cast==cast then N.skinCast.at=N:Now() end
end)
for _,event in ipairs({'UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED'}) do
 N:On(event,function(unit,cast) if unit=='player' and N.skinCast and N.skinCast.cast==cast then N.skinCast=nil end end)
end
-- Loot source: creature ID for skins; game object ID (not the bobber) for pools.
local function sources()
 local out={}
 if type(GetLootSourceInfo)~='function' then return out end
 local list={N:Call(GetLootSourceInfo,1)}
 for i=1,#list,2 do
  local guid=N:Text(list[i])
  if guid then
   local object=tonumber(guid:match('^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))
   local creature=tonumber(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))
   out[#out+1]={object=object,creature=creature}
  end
 end
 return out
end
N:On('LOOT_OPENED',function()
 N.wildLoot=nil
 local map,x,y=N:Position();if not map then return end
 local now=N:Now()
 local kind,from
 local f=N.fishCast
 if f and now-f.at<=35 and f.map==map and (type(IsFishingLoot)~='function' or N:Call(IsFishingLoot)) then
  local w,h=N:MapSize(map)
  if not w or N:Distance(f,{x=x,y=y},w,h)<=15 then kind,from='fish',f end
 end
 local s=N.skinCast
 if not kind and s and s.at and now-s.at<=4 and s.map==map then kind,from='skin',s end
 if not kind then return end
 local pool,creature
 for _,src in ipairs(sources()) do
  if src.object and src.object~=BOBBER then pool=src.object end
  if src.creature then creature=src.creature end
 end
 if kind=='skin' and type(GetLootSourceInfo)=='function' and #sources()>0 and not creature then N.skinCast=nil;return end
 local slots={}
 for slot=1,(N:Call(GetNumLootItems) or 0) do
  local id=N:ItemID(N:Call(GetLootSlotLink,slot));local _,name,qty=N:Call(GetLootSlotInfo,slot)
  if id and N:Finite(qty,1,1e6) then slots[slot]={id=id,qty=qty,name=name} end
 end
 N.wildLoot={kind=kind,map=map,x=x,y=y,from=from,pool=pool,slots=slots,items={},counted=false}
 if kind=='fish' then N.fishCast=nil else N.skinCast=nil end
end)
N:On('LOOT_SLOT_CLEARED',function(slot)
 local l=N.wildLoot;local item=l and l.slots[slot];if not item then return end
 l.slots[slot]=nil;l.items[item.id]=(l.items[item.id] or 0)+item.qty
 N.db.itemNames[item.id]=item.name
 -- Fish are not gathering loot elsewhere; count them in the session once.
 if l.kind=='fish' and N.lootGather==nil and N.db.settings.stats then
  if not N.session then N:StartSession() end
  local s=N.session;s.items[item.id]=(s.items[item.id] or 0)+item.qty;s.total=s.total+item.qty
  s.kinds.fish=(s.kinds.fish or 0)+item.qty
 end
end)
N:On('LOOT_CLOSED',function()
 local l=N.wildLoot;N.wildLoot=nil
 if not l or not next(l.items) then return end
 if l.kind=='fish' then N:RecordCatch(l.map,l.x,l.y,l.items,l.pool)
 else N:RecordSkin(l.map,l.x,l.y,l.from.creature,l.from.level,l.items) end
end)
N:On('PLAYER_LOGOUT',function() N:EndWildSession() end)

--------------------------------------------------------------------------------
-- Advice and reports
--------------------------------------------------------------------------------
-- Highest beast level this skinning skill can skin (Classic rule).
function N:SkinnableLevel(skill)
 if not self:Finite(skill,0,1000) then return nil end
 if skill<100 then return floor(skill/10)+10 end
 return floor(skill/5)
end
-- Zones whose level range reaches beasts you can skin and still learn from.
function N:SkinningZones(skill)
 local top=self:SkinnableLevel(skill);if not top then return {} end
 local out={}
 for _,z in ipairs(self.ZONE_LEVELS) do
  if z[2]<=top and z[3]>=top-10 then out[#out+1]={name=z[1],lo=z[2],hi=z[3],fit=math.abs(math.min(z[3],top)-top)} end
 end
 table.sort(out,function(a,b) if a.fit~=b.fit then return a.fit<b.fit end return a.hi>b.hi end)
 while #out>6 do table.remove(out) end
 return out,top
end
-- Your skinning spots, best first (most skins).
function N:SkinHotspots(limit,map)
 local w=self:WildDB();local out={}
 for m,z in pairs(w and w.skin or {}) do
  if not map or m==map then
   for key,e in pairs(z) do
    if type(e)=='table' and (e.n or 0)>0 then
     local gx,gy=key:match('^(%-?%d+):(%-?%d+)$');local ww,hh=self:MapSize(m)
     local names={};for n,c in pairs(e.names or {}) do names[#names+1]={n=n,c=c} end
     table.sort(names,function(a,b) return a.c>b.c end)
     out[#out+1]={map=m,key=key,n=e.n,qty=e.qty or 0,lo=e.lo,hi=e.hi,at=e.at,names=names,
      x=ww and gx and (tonumber(gx)+.5)*CELL/ww,y=hh and gy and (tonumber(gy)+.5)*CELL/hh}
    end
   end
  end
 end
 table.sort(out,function(a,b) if a.n~=b.n then return a.n>b.n end return (a.at or 0)>(b.at or 0) end)
 while limit and #out>limit do table.remove(out) end
 return out
end
function N:PoolSpots(map)
 local w=self:WildDB();local out={}
 for m,z in pairs(w and w.pools or {}) do
  if not map or m==map then
   for key,e in pairs(z) do if type(e)=='table' and self:Finite(e.x,0,1) and self:Finite(e.y,0,1) then out[#out+1]={map=m,key=key,e=e,x=e.x,y=e.y,name=self:PoolName(e)} end end
  end
 end
 table.sort(out,function(a,b) if a.e.n~=b.e.n then return a.e.n>b.e.n end return a.key<b.key end)
 return out
end
function N:SkinningRows()
 local accent,muted,gold,sub={.78,.6,1},{.6,.56,.68},{1,.82,0},{.85,.8,.95}
 local rows={}
 local skill,max=self:ProfessionSkill('Skinning',393)
 local zones,top=self:SkinningZones(skill)
 if skill then
  rows[#rows+1]={text=string.format('Skinning %d/%d: you can skin beasts up to level %d.',skill,max or 0,top),color=gold}
  if max and skill>=max then rows[#rows+1]={text='   At your rank cap: train the next rank to keep gaining skill.',color={1,.5,.25}} end
  rows[#rows+1]={text='Level-appropriate zones (Classic level ranges; Forever may differ)',color=accent}
  for _,z in ipairs(zones) do rows[#rows+1]={text=string.format('   %s (%d-%d)',z.name,z.lo,z.hi),color=sub} end
  rows[#rows+1]={text='   Best skill-ups come from beasts close to level '..top..'; much lower beasts give little or none.',color=muted}
 else
  rows[#rows+1]={text='Skinning not found on this character. Open your professions once.',color=muted}
 end
 rows[#rows+1]={text='Where you have skinned (places beasts were; spawns and other players vary)',color=accent}
 local spots=self:SkinHotspots(8)
 if #spots==0 then rows[#rows+1]={text='   Nothing recorded yet. Skin a few beasts and spots appear here.',color=muted} end
 for _,s in ipairs(spots) do
  local names={};for i,n in ipairs(s.names) do if i>2 then break end;names[#names+1]=n.n end
  rows[#rows+1]={text=string.format('   %s %.0f,%.0f: %d skins, %d items%s%s',self:RouteZoneName(s.map),(s.x or 0)*100,(s.y or 0)*100,s.n,s.qty,
   #names>0 and (' - '..table.concat(names,', ')) or '',s.lo and (' (lvl '..s.lo..(s.hi~=s.lo and ('-'..s.hi) or '')..')') or ''),color=gold}
 end
 rows[#rows+1]={text='Leather you hold (every counted character) and its price',color=accent}
 local stock=self:Stock(self.characterID)
 for _,l in ipairs(self.LEATHER) do
  local have=0
  for _,s in ipairs(stock[l[1]] or {}) do have=have+s.qty end
  if have>0 then
   local p=self:Price(l[1])
   rows[#rows+1]={text=string.format('   %s: %d  %s',l[2],have,p and self:PriceLabel(p) or 'no price'),item=l[1],color=sub}
  end
 end
 rows[#rows+1]={text='Your skinning sessions',color=accent}
 local any=false
 if self.wildSession and self.wildSession.kind=='skin' then rows[#rows+1]={text='   Now: '..self:WildSessionLine(self.wildSession),color=gold};any=true end
 local w=self:WildDB()
 for i=#(w and w.log or {}),1,-1 do
  local s=w.log[i]
  if s.kind=='skin' then rows[#rows+1]={text='   '..self:WildSessionLine(s),color=sub};any=true end
 end
 if not any then rows[#rows+1]={text='   None yet.',color=muted} end
 return rows
end
function N:FishingObservedRows()
 local accent,muted,gold,sub={.78,.6,1},{.6,.56,.68},{1,.82,0},{.85,.8,.95}
 local rows={{text='Your fishing (learned as you fish)',color=accent}}
 local w=self:WildDB()
 if self.wildSession and self.wildSession.kind=='fish' then rows[#rows+1]={text='   Now: '..self:WildSessionLine(self.wildSession),color=gold} end
 local shown=0
 for i=#(w and w.log or {}),1,-1 do
  local s=w.log[i]
  if s.kind=='fish' and shown<5 then rows[#rows+1]={text='   '..self:WildSessionLine(s),color=sub};shown=shown+1 end
 end
 local pools=self:PoolSpots()
 if #pools>0 then
  rows[#rows+1]={text='   Pools you have fished ('..#pools..'); /vmn poolroute builds a loop through this zone\'s pools',color=muted}
  for i,p in ipairs(pools) do
   if i>6 then break end
   rows[#rows+1]={text=string.format('      %s in %s at %.0f,%.0f (%d catches)',p.name,self:RouteZoneName(p.map),p.x*100,p.y*100,p.e.n),color=sub}
  end
 else rows[#rows+1]={text='   No pools recorded yet. Fish a pool, or stand by one and type /vmn pool NAME.',color=muted} end
 -- Catches by zone.
 local zones={}
 for m,z in pairs(w and w.fish or {}) do local n,q=0,0;for _,e in pairs(z) do if type(e)=='table' then n=n+(e.n or 0);q=q+(e.qty or 0) end end;zones[#zones+1]={map=m,n=n,q=q} end
 table.sort(zones,function(a,b) return a.n>b.n end)
 for i,z in ipairs(zones) do
  if i>4 then break end
  local items=w.fishItems[z.map] or {};local value,unpriced=self:ItemsValue(items)
  rows[#rows+1]={text=string.format('   %s: %d catches, %d items, worth %s%s',self:RouteZoneName(z.map),z.n,z.q,self:Money(value),unpriced>0 and ' + unpriced items' or ''),color=sub}
 end
 return rows
end
do -- Fishing guide gets your own data; a Skinning page joins the guide list.
 local extra=N.FishExtraRows
 N.FishExtraRows=function(self,skill,...)
  local rows=extra(self,skill,...)
  for _,r in ipairs(self:FishingObservedRows()) do rows[#rows+1]=r end
  return rows
 end
 if type(N.GUIDE_LIST)=='table' then table.insert(N.GUIDE_LIST,{key='skin',label='Skinning: zones, your spots, leather'}) end
 local tab=N.GuideTabRows
 N.GuideTabRows=function(self,key,...)
  if key=='skin' then
   local skill=self:ProfessionSkill('Skinning',393)
   return self:SkinningRows(),skill and ('Skinning '..skill..': beasts up to level '..self:SkinnableLevel(skill)) or 'Skinning',
    'Spots are where you skinned before, not guaranteed beasts.'
  end
  return tab(self,key,...)
 end
end

-- Loop through this zone's known pools.
function N:PoolRoute()
 local map,x,y=self:Position();if not map then return self:Print('Position unavailable.') end
 local pools=self:PoolSpots(map)
 if #pools<3 then return self:Print('Need at least 3 recorded pools in this zone (have '..#pools..'). Fish pools or mark them with /vmn pool NAME.') end
 local nodes={}
 for _,p in ipairs(pools) do nodes[#nodes+1]={x=p.x,y=p.y,name=p.name,kind='fish',source='Observed'} end
 local route,err=self:BuildZoneLoop(map,nodes,{x=x,y=y},nil,{minutes=self.db.settings.routeMinutes})
 if not route then return self:Print(err) end
 route.variant='pools'
 self:StartRoute(route)
 return route
end

-- Pool markers on the world map (own textures; capped).
do
 local refresh=N.RefreshMap
 N.RefreshMap=function(self,...)
  local a,b=refresh(self,...)
  self:Guard('poolPins',function()
   local world=WorldMapFrame;local canvas=world and world.GetCanvas and world:GetCanvas()
   local overlay=self.mapPinOverlay
   self.poolPins=self.poolPins or {}
   local map=world and world.GetMapID and world:GetMapID()
   local shown=0
   if canvas and overlay and map and self.db.settings.mapShowPools~=false and self.db.settings.nodesVisible then
    local width,height=canvas:GetWidth(),canvas:GetHeight()
    for _,p in ipairs(self:PoolSpots(map)) do
     if shown>=100 then break end
     shown=shown+1
     local pin=self.poolPins[shown]
     if not pin then
      pin=overlay:CreateTexture(nil,'OVERLAY');pin:SetTexture('Interface\\Icons\\INV_Misc_Fish_02');pin:SetSize(10,10)
      self.poolPins[shown]=pin
     end
     pin:ClearAllPoints();pin:SetPoint('CENTER',canvas,'TOPLEFT',p.x*width,-p.y*height);pin:Show()
    end
   end
   for i=shown+1,#self.poolPins do self.poolPins[i]:Hide() end
  end)
  return a,b
 end
end

N:AddCommand('skinning',function(self) self:Show('Guides');if self.ui then self.ui.guideKey='skin';self.db.settings.guide='skin';self.ui.offset=0 end end,'/vmn skinning, /vmn fishing (your spots, sessions, zones)')
N:AddCommand('fishing',function(self) self:Show('Guides');if self.ui then self.ui.guideKey='fish';self.db.settings.guide='fish';self.ui.offset=0 end end)
N:AddCommand('pool',function(self,args)
 local map,x,y=self:Position();if not map then return self:Print('Position unavailable.') end
 local name=args~='' and args or nil
 local e=self:RecordPool(map,x,y,nil,name or 'Pool')
 if e then self:Print('Marked '..(name or 'a pool')..' here. '..#self:PoolSpots(map)..' pools known in this zone.') end
end,'/vmn pool NAME (mark a fishing pool here), /vmn poolroute (loop through them)')
N:AddCommand('poolroute',function(self) self:PoolRoute() end)
N:AddCommand('pools',function(self,args) self.db.settings.mapShowPools=args~='off';self:Print('Pool markers '..(self.db.settings.mapShowPools and 'on' or 'off')..'.') end)
