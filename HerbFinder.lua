local _, N = ...
-- Finder: a small arrow that points to a herb or ore node you have actually
-- seen up, with its name and distance. Addons can't read the minimap's
-- tracking dots directly, so a node counts as seen when its name shows in
-- the game's tooltip: mouse over the dot on the minimap (or the node in the
-- world). The arrow then points there until you gather it, walk up to it, or
-- 10 minutes pass. With nothing seen it stays dim and doesn't point.
-- Off by default; the Finder dropdown on the Gather tab turns it on.

local VISIT_YARDS = 15
local SEEN_SECONDS = 600
local LIST_SECONDS = 30
local SNAP_YARDS = 40

local function angle(y, x)
 if math.atan2 then return math.atan2(y, x) end
 if x == 0 then return y >= 0 and math.pi / 2 or -math.pi / 2 end
 local n = math.atan(y / x)
 if x < 0 then n = n + math.pi end
 return n
end
local function delta(a, b) return (b - a + math.pi) % (2 * math.pi) - math.pi end

-- 'herb', 'ore', 'all', or nil (off, the default).
function N:FinderKind()
 local s = self.db and self.db.settings
 if not s then return nil end
 if s.finderKind == 'herb' or s.finderKind == 'ore' or s.finderKind == 'all' then return s.finderKind end
 return nil
end
function N:HerbFinderOn() return self:FinderKind() ~= nil end

-- Spots on this map you have the skill to gather (cached for 30 seconds).
function N:HerbFinderSpots(map)
 local kind = self:FinderKind() or 'herb'
 local c = self.herbFinderCache
 if c and c.map == map and c.kind == kind and self:Now() - c.at < LIST_SECONDS then return c.spots end
 local skills = self:GatheringSkills()
 local spots = {}
 for _, n in ipairs(self:ZoneNodes(map, kind, '') or {}) do
  local skill = (skills[n.kind] or {}).skill
  if not skill or not self:Finite(n.skill, 0, 1000) or n.skill <= skill then
   spots[#spots + 1] = { x = n.x, y = n.y, name = n.name, key = map .. ':' .. math.floor(n.x * 2000 + .5) .. ':' .. math.floor(n.y * 2000 + .5) }
  end
 end
 self.herbFinderCache = { map = map, kind = kind, at = self:Now(), spots = spots }
 return spots
end

-- Names you can gather on this map (lower case -> shown name).
function N:HerbFinderNames(map)
 local out = {}
 for _, s in ipairs(self:HerbFinderSpots(map)) do if s.name then out[s.name:lower()] = s.name end end
 local kind = self:FinderKind() or 'herb'
 local herbs = kind ~= 'ore' and self.FIND_CATEGORIES and self.FIND_CATEGORIES.herbs
 for _, n in ipairs(herbs and herbs.names or {}) do
  if not out[n] then out[n] = (n:gsub("^%l", string.upper):gsub(" %l", string.upper)) end
 end
 return out
end

-- Mark a node as seen up. x, y: where it is (map units) if known; otherwise
-- the nearest known spot with that name within `range` yards of you.
function N:HerbFinderSeen(map, name, x, y, range)
 local px, py = select(2, self:Position())
 local w, h = self:MapSize(map)
 if not w or not h or not px then return end
 local ox, oy, limit = x or px, y or py, x and SNAP_YARDS or (range or 60)
 local best, bestD
 for _, s in ipairs(self:HerbFinderSpots(map)) do
  if s.name and s.name:lower() == name:lower() then
   local d = math.sqrt(((s.x - ox) * w) ^ 2 + ((s.y - oy) * h) ^ 2)
   if d <= limit and (not bestD or d < bestD) then best, bestD = s, d end
  end
 end
 if not best and not x then return end
 best = best or { x = x, y = y, name = name, key = map .. ':seen:' .. math.floor(x * 2000 + .5) .. ':' .. math.floor(y * 2000 + .5) }
 self.herbSeen = self.herbSeen or {}
 local old = self.herbSeen[best.key]
 if old then old.at = self:Now(); return old end
 local e = { key = best.key, map = map, x = best.x, y = best.y, name = best.name or name, at = self:Now() }
 self.herbSeen[best.key] = e
 return e
end

local function tooltipLines()
 local out = {}
 local n = GameTooltip.NumLines and GameTooltip:NumLines() or 0
 for i = 1, math.min(n, 30) do
  local fs = _G['GameTooltipTextLeft' .. i]
  local t = fs and fs.GetText and fs:GetText()
  if type(t) == 'string' then
   t = t:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|T.-|t', '')
   for line in (t .. '\n'):gmatch('([^\n]*)\n') do
    line = line:match('^%s*(.-)%s*$')
    if line ~= '' then out[#out + 1] = line end
   end
  end
 end
 return out
end

-- Read the game tooltip: the minimap's dot tooltip (names under the cursor)
-- or a node you are mousing over in the world.
function N:HerbFinderScanTooltip()
 if not GameTooltip or not GameTooltip:IsShown() then return end
 local map, px, py = self:Position()
 if not map then return end
 local names = self:HerbFinderNames(map)
 local onMinimap = Minimap and Minimap.IsMouseOver and Minimap:IsMouseOver()
 if onMinimap then
  local cx, cy = Minimap:GetCenter()
  local radius = C_Minimap and C_Minimap.GetViewRadius and self:Call(C_Minimap.GetViewRadius)
  local w, h = self:MapSize(map)
  local mx, my
  if cx and w and self:Finite(radius, 1, 100000) and GetCursorPosition then
   local scale = Minimap:GetEffectiveScale() or 1
   local ux, uy = GetCursorPosition()
   local nx = (ux / scale - cx) / (Minimap:GetWidth() / 2)
   local ny = (uy / scale - cy) / (Minimap:GetHeight() / 2)
   local facing = 0
   if GetCVarBool and self:Call(GetCVarBool, 'rotateMinimap') and not (C_Minimap.IsRotateMinimapIgnored and self:Call(C_Minimap.IsRotateMinimapIgnored)) then
    facing = self:Call(GetPlayerFacing) or 0
   end
   local cos, sin = math.cos(facing), math.sin(facing)
   local dx, dy = (nx * cos - ny * sin) * radius, (nx * sin + ny * cos) * radius
   mx, my = px + dx / w, py - dy / h
  end
  for _, line in ipairs(tooltipLines()) do
   local name = names[line:lower()]
   if name then self:HerbFinderSeen(map, name, mx, my, 250) end
  end
 elseif not (UnitExists and UnitExists('mouseover')) then
  local line = tooltipLines()[1]
  local name = line and names[line:lower()]
  if name then self:HerbFinderSeen(map, name, nil, nil, 60) end
 end
end

-- Nearest node seen up: spot, distance, dx, dy (yards). Reaching one (within
-- 15 yards) or seen more than 10 minutes ago drops it.
function N:HerbFinderTarget()
 local map, x, y = self:Position()
 if not map then return nil end
 local w, h = self:MapSize(map)
 if not w or not h then return nil end
 local now = self:Now()
 local best, bestD, bdx, bdy
 for key, s in pairs(self.herbSeen or {}) do
  if now - s.at > SEEN_SECONDS then self.herbSeen[key] = nil
  elseif s.map == map then
   local dx, dy = (s.x - x) * w, (s.y - y) * h
   local d = math.sqrt(dx * dx + dy * dy)
   if d <= VISIT_YARDS then self.herbSeen[key] = nil
   elseif not bestD or d < bestD then best, bestD, bdx, bdy = s, d, dx, dy end
  end
 end
 return best, bestD, bdx, bdy
end

function N:HerbFinderFrame()
 if self.herbArrow then return self.herbArrow end
 local f = CreateFrame('Frame', 'VoidMarkNexusHerbArrow', UIParent)
 f:SetSize(120, 104)
 f:SetFrameStrata('LOW')
 f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
 f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart', function(w) w:StartMoving() end)
 f:SetScript('OnDragStop', function(w)
  w:StopMovingOrSizing()
  local point, _, rel, px, py = w:GetPoint(1)
  N.db.settings.herbFinderPos = { point = point, rel = rel, x = px, y = py }
 end)
 f.texture = f:CreateTexture(nil, 'ARTWORK')
 f.texture:SetSize(64, 64); f.texture:SetPoint('TOP', 0, 0)
 f.texture:SetTexture('Interface\\AddOns\\VoidMarkNexus\\Media\\RouteCompass')
 f.texture:SetVertexColor(.45, 1, .45)
 f.pivot = CreateVector2D and CreateVector2D(.5, .606) or nil
 f.name = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
 f.name:SetPoint('TOP', f.texture, 'BOTTOM', 0, -2); f.name:SetWidth(160); f.name:SetWordWrap(false)
 f.name:SetTextColor(.55, 1, .55); f.name:SetShadowOffset(1, -1)
 f.dist = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 f.dist:SetPoint('TOP', f.name, 'BOTTOM', 0, -1); f.dist:SetShadowOffset(1, -1)
 local pos = self.db.settings.herbFinderPos
 if type(pos) == 'table' and pos.point and self:Finite(pos.x, -20000, 20000) and self:Finite(pos.y, -20000, 20000) then
  f:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y)
 else
  f:SetPoint('CENTER', UIParent, 'CENTER', 0, 160)
 end
 f.refresh = 0
 f:SetScript('OnUpdate', function(w, dt)
  w.refresh = w.refresh - dt
  if w.refresh <= 0 then
   w.refresh = .25
   N:Guard('herb finder', function() N:HerbFinderScanTooltip(); N:UpdateHerbFinder() end)
  end
  local facing = N:Call(GetPlayerFacing)
  if w.bearing and N:Finite(facing, -10, 10) then
   local goal = w.bearing - facing
   w.angle = w.angle or goal
   w.angle = w.angle + delta(w.angle, goal) * math.min(1, dt * 13)
   if w.texture.SetRotation then
    if w.pivot then w.texture:SetRotation(w.angle, w.pivot) else w.texture:SetRotation(w.angle) end
   end
  end
 end)
 self.herbArrow = f
 return f
end

function N:UpdateHerbFinder()
 local f = self.herbArrow
 if not f then return end
 if not self:HerbFinderOn() then f:Hide(); return end
 local spot, d, dx, dy = self:HerbFinderTarget()
 if not spot then
  f.bearing = nil; f.texture:SetAlpha(.3)
  f.name:SetText(({ ore = 'Hover ore on minimap', all = 'Hover a node on minimap' })[self:FinderKind()] or 'Hover a herb on minimap'); f.dist:SetText('')
  return
 end
 f.texture:SetAlpha(1)
 f.bearing = angle(-dx, -dy)
 f.name:SetText(spot.name)
 f.dist:SetText(math.floor(d + .5) .. ' yd')
end

function N:SetFinder(kind)
 if kind ~= 'herb' and kind ~= 'ore' and kind ~= 'all' then kind = nil end
 self.db.settings.finderKind = kind
 self.herbFinderCache = nil
 self.dirty = true
 if kind then
  local f = self:HerbFinderFrame(); f.refresh = 0
  f.texture:SetVertexColor(kind == 'ore' and 1 or .45, kind == 'ore' and .8 or 1, kind == 'ore' and .4 or .45)
  f.name:SetTextColor(kind == 'ore' and 1 or .55, kind == 'ore' and .82 or 1, kind == 'ore' and .45 or .55)
  f:Show()
 elseif self.herbArrow then
  self.herbArrow:Hide()
 end
end
function N:SetHerbFinder(on)
 self:SetFinder(on and 'herb' or nil)
end
-- Gathering clears the node you were heading to.
N:On('LOOT_CLOSED', function()
 if not N:HerbFinderOn() or not N.herbSeen then return end
 local map, x, y = N:Position()
 if not map then return end
 local w, h = N:MapSize(map)
 if not w then return end
 for key, s in pairs(N.herbSeen) do
  if s.map == map and math.sqrt(((s.x - x) * w) ^ 2 + ((s.y - y) * h) ^ 2) <= 25 then N.herbSeen[key] = nil end
 end
end)
N:On('PLAYER_LOGIN', function() if N:FinderKind() then N:SetFinder(N:FinderKind()) end end)
