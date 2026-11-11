local _, N = ...
-- Route planner (0.9): "Start route" builds a few different loops, shows each on
-- the zone's map (OpenMap's terrain art when it's installed), and starts the one
-- you pick. Every pick and every lap you run on it is logged, and that history
-- ranks the options next time ("Recommended" is the one you do best on).

local LAND=N.zoneLand
local PICK_RATE=.5          -- guessed share of spawn spots that are up, before any laps are logged
local PRIOR_LAPS=2          -- how many laps the guess is worth against real laps
local MAX_PICKS=200         -- pick log length

--------------------------------------------------------------------------------
-- Land (OpenMap's zone outlines, Data/ZoneLand.lua)
--------------------------------------------------------------------------------
local landCache={}
local function landBits(map)
 local c=landCache[map]
 if c~=nil then return c end
 local rows=LAND and LAND.land and LAND.land[map]
 if type(rows)~='table' then landCache[map]=false; return false end
 local bits={}
 for y,hex in ipairs(rows) do
  local r={}
  for i=1,#hex do
   local v=tonumber(hex:sub(i,i),16) or 0
   for b=3,0,-1 do r[#r+1]=math.floor(v/2^b)%2==1 end
  end
  bits[y]=r
 end
 landCache[map]=bits; return bits
end
function N:HasLand(map) return landBits(map)~=false end
-- true/false for a point (0-1 on the zone map); nil when the zone has no outline.
function N:OnLand(map,x,y)
 local bits=landBits(map); if not bits then return nil end
 local gx=math.min(LAND.w,math.max(1,math.floor(x*LAND.w)+1))
 local gy=math.min(LAND.h,math.max(1,math.floor(y*LAND.h)+1))
 return bits[gy] and bits[gy][gx] or false
end
-- Share (0-1) of a straight leg that runs off the zone's land.
function N:LegOffLand(map,x1,y1,x2,y2)
 local bits=landBits(map); if not bits then return 0 end
 local steps=math.max(2,math.min(24,math.floor(math.max(math.abs(x2-x1)*LAND.w,math.abs(y2-y1)*LAND.h))+1))
 local off=0
 for i=0,steps do
  local t=i/steps
  if self:OnLand(map,x1+(x2-x1)*t,y1+(y2-y1)*t)==false then off=off+1 end
 end
 return off/(steps+1)
end

--------------------------------------------------------------------------------
-- History: what you picked, and how the laps on it went
--------------------------------------------------------------------------------
function N:RouteHistory()
 local h=self.db.routeHistory
 if type(h)~='table' then h={}; self.db.routeHistory=h end
 if type(h.picks)~='table' then h.picks={} end
 if type(h.stats)~='table' then h.stats={} end
 return h
end
local function statKey(map,variant) return tostring(map)..':'..tostring(variant) end
function N:RouteStat(map,variant)
 local s=self:RouteHistory().stats[statKey(map,variant)]
 return type(s)=='table' and s or nil
end
-- How often each kind of route gets picked, anywhere (0-1).
function N:VariantShare(variant)
 local picks=self:RouteHistory().picks; local n,hit=0,0
 for _,p in ipairs(picks) do n=n+1; if p.variant==variant then hit=hit+1 end end
 return n>0 and hit/n or 0,n
end
function N:LogRoutePick(option,rank,count)
 local h=self:RouteHistory(); local r=option.route
 h.picks[#h.picks+1]={at=self:Now(),map=r.map,variant=option.variant,rank=rank,options=count,
  stops=#r.points,minutes=math.floor((r.seconds or 0)/60+.5),recommended=option.recommended or nil}
 while #h.picks>MAX_PICKS do table.remove(h.picks,1) end
 local k=statKey(r.map,option.variant); local s=h.stats[k]
 if type(s)~='table' then s={picks=0,laps=0,picked=0,empty=0,seconds=0}; h.stats[k]=s end
 s.picks=s.picks+1; s.lastPick=self:Now()
end
-- Called when a lap ends on a planned route.
function N:LogRouteLap(route,lap)
 if not route or not route.variant or not lap then return end
 local h=self:RouteHistory(); local k=statKey(route.map,route.variant); local s=h.stats[k]
 if type(s)~='table' then s={picks=0,laps=0,picked=0,empty=0,seconds=0}; h.stats[k]=s end
 local secs=(lap.finished or self:Now())-(lap.started or self:Now())
 if not self:Finite(secs,30,4*3600) then return end -- a lap under 30s or over 4h is not a real lap
 s.laps=s.laps+1; s.picked=s.picked+(tonumber(lap.picked) or 0); s.empty=s.empty+(tonumber(lap.empty) or 0)
 s.seconds=s.seconds+secs; s.gain=(s.gain or 0)+(tonumber(lap.gain) or 0); s.lastLap=self:Now()
 local p=h.picks[#h.picks]; if p and p.map==route.map and p.variant==route.variant then p.laps=(p.laps or 0)+1 end
end
do -- every finished lap also feeds the history
 local finish=N.FinishLap
 N.FinishLap=function(self,...)
  local lap,route=self.lapStats,self.activeRoute
  local a,b=finish(self,...)
  if lap and route and route.variant then self:Guard('routeLap',function() self:LogRouteLap(route,lap) end) end
  return a,b
 end
end

-- Expected nodes per hour: a guess from the spots on the loop, pulled toward
-- what you really got on earlier laps of the same kind of route in that zone.
function N:RouteRate(route,variant)
 local spots=0; for _,p in ipairs(route.points) do spots=spots+math.min(3,p.spawns or 1)*(p.picked and p.picked>0 and 1.2 or 1) end
 local lapMin=math.max(1,(route.seconds or 60)/60)
 local guess=math.min(#route.points,spots*PICK_RATE)/lapMin*60
 local s=self:RouteStat(route.map,variant)
 if s and s.laps>0 and s.seconds>0 then
  local real=s.picked/s.seconds*3600
  return (guess*PRIOR_LAPS+real*s.laps)/(PRIOR_LAPS+s.laps),guess,real,s.laps
 end
 return guess,guess,nil,0
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------
local VARIANTS={
 {id='balanced',label='Balanced',note='your lap length'},
 {id='quick',label='Quick',note='half the lap, densest stretch'},
 {id='long',label='Long',note='twice the lap, more spots'},
 {id='land',label='Stay on land',note='avoids crossing water'},
}
local function zoneName(self,map)
 local info=C_Map and C_Map.GetMapInfo and self:Call(C_Map.GetMapInfo,map)
 return type(info)=='table' and info.name or ('Zone '..tostring(map))
end
local function sameLoop(a,b)
 if #a.points~=#b.points then return false end
 local keys={}
 for _,p in ipairs(a.points) do keys[string.format('%.4f:%.4f',p.x,p.y)]=true end
 for _,p in ipairs(b.points) do if not keys[string.format('%.4f:%.4f',p.x,p.y)] then return false end end
 return true
end

-- Builds the options: up to four loops here, plus the best loop in up to two
-- other zones. Ranked by expected nodes per hour, nudged by what you tend to pick.
function N:RouteOptions(otherZones)
 local map,x,y=self:Position()
 if not map then return nil,'Your position is not available here.' end
 local mode=self.db.settings.routeSelectionMode
 if mode=='skillup' or mode=='gold' then self.generating=true; self:Guard('scan',function() self:ScanProfessions() end); self.generating=nil end
 local s=self.db.settings; local base=math.max(5,s.routeMinutes or 20)
 local out={}
 local nodes=self:ZoneNodes(map)
 if #nodes>0 then
  local here={x=x,y=y}
  for _,v in ipairs(VARIANTS) do
   local opts={minutes=base}
   if v.id=='quick' then opts.minutes=math.max(5,math.floor(base/2+.5))
   elseif v.id=='long' then opts.minutes=math.min(120,base*2)
   elseif v.id=='land' then opts.landPenalty=4 end
   if v.id~='land' or self:HasLand(map) then
    local ok,route=pcall(self.BuildZoneLoop,self,map,nodes,here,nil,opts)
    if ok and route and #route.points>=3 then
     local dup=false
     for _,o in ipairs(out) do if sameLoop(o.route,route) then dup=true; break end end
     -- "Stay on land" only earns a place when the balanced loop really crosses water.
     if v.id=='land' and out[1] and (out[1].route.offLand or 0)<.04 then dup=true end
     if v.id=='land' and (route.offLand or 0)>=((out[1] and out[1].route.offLand) or 1)-.02 then dup=true end
     if not dup then out[#out+1]={variant=v.id,label=v.label,note=v.note,route=route,map=map,zone=zoneName(self,map),here=true} end
    end
   end
  end
 end
 if otherZones~=false then self:AddOtherZoneOptions(out,map) end
 if #out==0 then
  return nil,mode=='skillup' and 'Nothing near you gives skill-ups. Try "Best zones".'
   or mode=='gold' and 'Nothing near you that you can gather.' or 'Nothing matching in this zone.'
 end
 self:RankRouteOptions(out)
 return out
end
-- The best loop in up to two other zones (the slow part: done after the window is up).
function N:AddOtherZoneOptions(out,map)
 local base=math.max(5,self.db.settings.routeMinutes or 20)
 local others=0
 for _,z in ipairs(self:BestZones(4)) do
  if z.map~=map and others<2 then
   local ok,route=pcall(self.BuildZoneLoop,self,z.map,self:ZoneNodes(z.map),nil,nil,{minutes=base})
   if ok and route and #route.points>=3 then
    others=others+1
    out[#out+1]={variant='balanced',label=z.name,note='another zone: travel there first',route=route,map=z.map,zone=z.name,here=false}
   end
  end
 end
 return others
end
function N:RankRouteOptions(out)
 for _,o in ipairs(out) do
  o.route.variant=o.variant
  o.rate,o.guess,o.real,o.laps=self:RouteRate(o.route,o.variant)
  local share,picks=self:VariantShare(o.variant)
  -- A small nudge toward what you usually choose (up to +15%), once you have picked a few times.
  -- Other zones are discounted for the trip there.
  o.score=o.rate*(1+(picks>=3 and share*.15 or 0))*(o.here and 1 or .85)
  o.recommended=nil
 end
 table.sort(out,function(a,b) if a.score~=b.score then return a.score>b.score end return a.label<b.label end)
 if out[1] then out[1].recommended=true end
 for i,o in ipairs(out) do o.rank=i end
 return out
end

function N:RouteOptionLine(o)
 local r=o.route
 local spawns=0; for _,p in ipairs(r.points) do spawns=spawns+(p.spawns or 1) end
 local min=math.floor((r.seconds or 0)/60+.5)
 local line=string.format('%s%s: %d stops, %d min, ~%d nodes/hr',o.recommended and '* ' or '',o.label,#r.points,min,math.floor(o.rate+.5))
 return line,spawns
end
function N:RouteOptionWhy(o)
 local r=o.route; local lines={}
 lines[#lines+1]=o.zone..' - '..o.note
 lines[#lines+1]=string.format('%.1f km loop, %d stops', (r.length or 0)*0.9144/1000, #r.points)
 if r.offLand and r.offLand>=.01 then lines[#lines+1]=string.format('%d%% of the loop crosses water or leaves the zone',math.floor(r.offLand*100+.5)) end
 if o.real then lines[#lines+1]=string.format('You got %d nodes/hr over %d lap%s on this kind of route here',math.floor(o.real+.5),o.laps,o.laps==1 and '' or 's')
 else lines[#lines+1]='Estimate (no laps logged on this kind of route here yet)' end
 if o.recommended then lines[#lines+1]='Recommended: best expected nodes per hour' end
 return table.concat(lines,'\n')
end

-- Starts a built route (the planner's pick, or GenerateRoute's).
function N:StartRoute(route,quiet)
 if self.ResetLoopTracking then self:ResetLoopTracking() end
 self.activeRoute=route; self.waypoint=1; self.terrainIndex=1; self.routePaused=false; self.lap=1
 self.dirty=true; self:ShowArrow()
 if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() and self.RefreshMap then self:RefreshMap() end
 if not quiet then self:Print('Route ready: '..self:RouteSummary(route)..'.') end
 return route
end
function N:PickRouteOption(i)
 local list=self.routeOptions; local o=list and list[i]
 if not o then return end
 self:LogRoutePick(o,i,#list)
 if self.ResourceSetKey then o.route.resourceKey=self:ResourceSetKey(self:ZoneNodes(o.map)) end
 self:StartRoute(o.route)
 if not o.here then self:Print('This loop is in '..o.zone..'. Head there; the arrow points to the first stop.') end
 self.routeOptions=nil
 if self.routePreview then self.routePreview:Hide() end
end

--------------------------------------------------------------------------------
-- Preview window
--------------------------------------------------------------------------------
local CW,CH=360,240            -- map canvas (3:2, like the zone art)
local OPENMAP='Interface\\AddOns\\OpenMap\\Media\\Textures\\Forever\\MapZones\\'

local function openMapReady()
 local loaded=(C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('OpenMap')) or (IsAddOnLoaded and IsAddOnLoaded('OpenMap'))
 local locale=GetLocale and GetLocale() or 'enUS'
 -- OpenMap's baked tiles carry English place names; other clients draw Blizzard's own art.
 return loaded and locale:sub(1,2)=='en' and LAND and LAND.art and true or false
end
-- The zone's rectangle on the stitched world (0-1).
function N:ZoneWorldRect(map)
 if OpenMapAPI and OpenMapAPI.WorldFromMap then
  local u0,v0=self:Call(OpenMapAPI.WorldFromMap,map,0,0); local u1,v1=self:Call(OpenMapAPI.WorldFromMap,map,1,1)
  if self:Finite(u0,-1,2) and self:Finite(u1,-1,2) and self:Finite(v0,-1,2) and self:Finite(v1,-1,2) and u1>u0 and v1>v0 then return u0,u1,v0,v1 end
 end
 if C_Map and C_Map.GetMapRectOnMap then
  local l,r,t,b=self:Call(C_Map.GetMapRectOnMap,map,947)
  if self:Finite(l,-1,2) and self:Finite(r,-1,2) and r>l and self:Finite(t,-1,2) and self:Finite(b,-1,2) and b>t then return l,r,t,b end
 end
end
-- Texture placements for the zone's art: {file, x, y, w, h, tex coords} in canvas pixels.
function N:ZoneArtTiles(map,cw,ch)
 local out={}
 if openMapReady() then
  local u0,u1,v0,v1=self:ZoneWorldRect(map)
  local layers=C_Map and C_Map.GetMapArtLayers and self:Call(C_Map.GetMapArtLayers,947)
  local world=type(layers)=='table' and layers[1]
  if u0 and type(world)=='table' and self:Finite(world.layerWidth,1,1e6) and self:Finite(world.layerHeight,1,1e6) then
   local art=LAND.art; local size=art.step/art.px; local inset=(art.size-art.step)/2/art.size
   local have={}; for _,k in ipairs(art.tiles) do have[k]=true end
   local x0,x1,y0,y1=u0*world.layerWidth,u1*world.layerWidth,v0*world.layerHeight,v1*world.layerHeight
   local sx,sy=cw/(x1-x0),ch/(y1-y0)
   for i=math.floor(x0/size),math.floor(x1/size) do
    for j=math.floor(y0/size),math.floor(y1/size) do
     if have[i*256+j] then
      out[#out+1]={file=OPENMAP..i..'_'..j,x=(i*size-x0)*sx,y=(j*size-y0)*sy,w=size*sx,h=size*sy,coords={inset,1-inset,inset,1-inset}}
     end
    end
   end
   if #out>0 then out.source='OpenMap' return out end
  end
 end
 -- Blizzard's own zone art: a grid of tiles over the zone map.
 local layers=C_Map and C_Map.GetMapArtLayers and self:Call(C_Map.GetMapArtLayers,map)
 local layer=type(layers)=='table' and layers[1]
 local files=C_Map and C_Map.GetMapArtLayerTextures and self:Call(C_Map.GetMapArtLayerTextures,map,1)
 if type(layer)=='table' and type(files)=='table' and self:Finite(layer.layerWidth,1,1e5) and self:Finite(layer.tileWidth,1,1e5) then
  local cols=math.ceil(layer.layerWidth/layer.tileWidth)
  local sx,sy=cw/layer.layerWidth,ch/layer.layerHeight
  for k,file in ipairs(files) do
   local c,r=(k-1)%cols,math.floor((k-1)/cols)
   out[#out+1]={file=file,x=c*layer.tileWidth*sx,y=r*layer.tileHeight*sy,w=layer.tileWidth*sx,h=layer.tileHeight*sy,coords={0,1,0,1}}
  end
  out.source='game map'
 end
 return out
end

local function btn(parent,text,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate'); b:SetSize(w,22); b:SetText(text)
 b:SetScript('OnClick',function() N:Guard(text,fn) end); return b
end

function N:CreateRoutePreview()
 if self.routePreview then return self.routePreview end
 local f=CreateFrame('Frame','VoidMarkNexusRoutePreview',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
 f:SetSize(CW+24,CH+250); f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true)
 f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function() f:StartMoving() end); f:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
 if f.SetBackdrop then
  f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
  f:SetBackdropColor(.06,.04,.1,.96); f:SetBackdropBorderColor(.62,.34,.95,1)
 end
 local anchor=self.ui and self.ui.frame
 if anchor then f:SetPoint('TOPLEFT',anchor,'TOPRIGHT',8,0) else f:SetPoint('CENTER') end
 f.title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); f.title:SetPoint('TOPLEFT',12,-10); f.title:SetText('Route options')
 local close=btn(f,'X',26,function() f:Hide(); N.routeOptions=nil end); close:SetPoint('TOPRIGHT',-8,-8)
 local canvas=CreateFrame('Frame',nil,f); canvas:SetSize(CW,CH); canvas:SetPoint('TOPLEFT',12,-36)
 if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
 canvas.bg=canvas:CreateTexture(nil,'BACKGROUND'); canvas.bg:SetAllPoints(); canvas.bg:SetColorTexture(.12,.1,.08,1)
 canvas.tiles,canvas.lines,canvas.dots={},{},{}
 f.canvas=canvas
 f.source=f:CreateFontString(nil,'OVERLAY','GameFontDisableSmall'); f.source:SetPoint('TOPRIGHT',canvas,'BOTTOMRIGHT',0,-2)
 f.why=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); f.why:SetPoint('TOPLEFT',canvas,'BOTTOMLEFT',0,-16)
 f.why:SetWidth(CW); f.why:SetJustifyH('LEFT')
 f.rows={}
 for i=1,6 do
  local r=CreateFrame('Button',nil,f); r:SetSize(CW,20); r:SetPoint('TOPLEFT',canvas,'BOTTOMLEFT',0,-80-(i-1)*21)
  r.bg=r:CreateTexture(nil,'BACKGROUND'); r.bg:SetAllPoints(); r.bg:SetColorTexture(.2,.12,.3,.6)
  r.text=r:CreateFontString(nil,'OVERLAY','GameFontHighlight'); r.text:SetPoint('LEFT',6,0); r.text:SetWidth(CW-12); r.text:SetJustifyH('LEFT')
  r:SetScript('OnClick',function() N.routeSelected=i; N:DrawRoutePreview() end)
  f.rows[i]=r
 end
 f.start=btn(f,'Start this route',150,function() N:PickRouteOption(N.routeSelected or 1) end)
 f.start:SetPoint('BOTTOMLEFT',12,10)
 f.again=btn(f,'Rebuild',90,function() N:OpenRoutePlanner() end); f.again:SetPoint('LEFT',f.start,'RIGHT',8,0)
 f.cancel=btn(f,'Cancel',90,function() f:Hide(); N.routeOptions=nil end); f.cancel:SetPoint('LEFT',f.again,'RIGHT',8,0)
 table.insert(UISpecialFrames,'VoidMarkNexusRoutePreview')
 self.routePreview=f
 return f
end

local function line(canvas,i)
 local l=canvas.lines[i]
 if not l and canvas.CreateLine then l=canvas:CreateLine(nil,'OVERLAY'); canvas.lines[i]=l end
 return l
end
local function dot(canvas,i)
 local d=canvas.dots[i]
 if not d then d=canvas:CreateTexture(nil,'OVERLAY',nil,7); canvas.dots[i]=d end
 return d
end

function N:DrawRoutePreview()
 local f=self.routePreview; local list=self.routeOptions
 if not f or not list then return end
 local sel=math.max(1,math.min(#list,self.routeSelected or 1)); self.routeSelected=sel
 local o=list[sel]; local r=o.route; local c=f.canvas
 -- Terrain: redrawn only when the zone changes.
 local artKey=tostring(r.map)..':'..tostring(openMapReady())
 if c.map~=artKey then
  for _,t in ipairs(c.tiles) do t:Hide() end
  local tiles=self:ZoneArtTiles(r.map,CW,CH)
  for i,t in ipairs(tiles) do
   local tex=c.tiles[i] or c:CreateTexture(nil,'ARTWORK'); c.tiles[i]=tex
   tex:SetTexture(t.file); tex:SetTexCoord(t.coords[1],t.coords[2],t.coords[3],t.coords[4])
   tex:ClearAllPoints(); tex:SetPoint('TOPLEFT',c,'TOPLEFT',t.x,-t.y); tex:SetSize(t.w,t.h); tex:Show()
  end
  c.map=artKey; c.source=tiles.source
 end
 f.source:SetText(c.source and ('Map: '..c.source) or 'No map art here')
 -- Route: the loop as lines, stops as dots (brighter where you found something before).
 local n=#r.points
 for i=1,math.max(#c.lines,n) do local l=c.lines[i]; if l then l:Hide() end end
 for i=1,#c.dots do c.dots[i]:Hide() end
 for i,p in ipairs(r.points) do
  local q=r.points[i%n+1]
  local l=line(c,i)
  if l then
   l:SetThickness(2); l:SetColorTexture(.78,.6,1,.95)
   l:SetStartPoint('TOPLEFT',c,p.x*CW,-p.y*CH); l:SetEndPoint('TOPLEFT',c,q.x*CW,-q.y*CH); l:Show()
  end
  local d=dot(c,i); local size=i==1 and 9 or 5
  d:SetSize(size,size); d:ClearAllPoints(); d:SetPoint('CENTER',c,'TOPLEFT',p.x*CW,-p.y*CH)
  if i==1 then d:SetColorTexture(.3,1,.4,1) elseif p.picked and p.picked>0 then d:SetColorTexture(1,.85,.2,1) else d:SetColorTexture(1,1,1,.85) end
  d:Show()
 end
 local map,x,y=self:Position()
 if map==r.map and x then
  local me=dot(c,n+1); me:SetSize(10,10); me:ClearAllPoints(); me:SetPoint('CENTER',c,'TOPLEFT',x*CW,-y*CH); me:SetColorTexture(.2,.7,1,1); me:Show()
 end
 f.title:SetText('Route options - '..o.zone)
 f.why:SetText(self:RouteOptionWhy(o))
 for i,row in ipairs(f.rows) do
  local opt=list[i]; row:SetShown(opt~=nil)
  if opt then
   row.text:SetText((self:RouteOptionLine(opt)))
   if i==sel then row.bg:SetColorTexture(.45,.25,.7,.85) else row.bg:SetColorTexture(.2,.12,.3,.6) end
  end
 end
end

-- Gather > Start route: build the options and show them. Starting is one click.
-- This zone's loops show at once; other zones are added a moment later so the
-- game never stalls on opening the window.
function N:OpenRoutePlanner()
 local deferred=C_Timer and C_Timer.After and true or false
 local list,err=self:RouteOptions(not deferred)
 if not list and deferred then list,err=self:RouteOptions(true); deferred=false end
 if not list then return self:Print(err) end
 self.routeOptions=list; self.routeSelected=1
 local f=self:CreateRoutePreview(); f:Show()
 self:DrawRoutePreview()
 if deferred then
  local token={}; self.routePlanToken=token
  f.why:SetText(f.why:GetText()..'\nLooking at other zones...')
  C_Timer.After(.05,function()
   if self.routePlanToken~=token or self.routeOptions~=list then return end
   self:Guard('routeOptions',function()
    local map=self:Position()
    local picked=list[self.routeSelected or 1]
    self:AddOtherZoneOptions(list,map); self:RankRouteOptions(list)
    for i,o in ipairs(list) do if o==picked then self.routeSelected=i end end
    self:DrawRoutePreview()
   end)
  end)
 end
 return list
end

-- /vmn routelog: what you picked and how it went, per zone and kind of route.
function N:RouteLogCommand()
 local h=self:RouteHistory(); local rows={}
 for k,s in pairs(h.stats) do
  local map,variant=k:match('^(%d+):(.+)$')
  if map then rows[#rows+1]={name=zoneName(self,tonumber(map))..' / '..variant,s=s} end
 end
 if #rows==0 then return self:Print('No routes picked yet. Start one from Gather > Start route.') end
 table.sort(rows,function(a,b) return (a.s.lastPick or 0)>(b.s.lastPick or 0) end)
 for i,r in ipairs(rows) do
  if i>8 then break end
  local s=r.s
  local rate=s.seconds>0 and string.format(', %d nodes/hr',math.floor(s.picked/s.seconds*3600+.5)) or ''
  self:Print(string.format('%s: picked %d time%s, %d lap%s%s',r.name,s.picks,s.picks==1 and '' or 's',s.laps,s.laps==1 and '' or 's',rate))
 end
end
