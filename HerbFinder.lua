local _, N = ...
-- Herb finder: a small arrow that points to the nearest herb spot you can pick
-- (your Herbalism skill), with its name and distance. Spots come from Nexus's
-- spawn data and the herbs you've picked. Addons can't see whether a herb is up
-- right now, so a spot you've walked past (within 15 yards) is skipped for
-- 5 minutes and the arrow moves on. Toggle: Settings tab.

local VISIT_YARDS = 15
local SKIP_SECONDS = 300
local LIST_SECONDS = 30

local function angle(y, x)
 if math.atan2 then return math.atan2(y, x) end
 if x == 0 then return y >= 0 and math.pi / 2 or -math.pi / 2 end
 local n = math.atan(y / x)
 if x < 0 then n = n + math.pi end
 return n
end
local function delta(a, b) return (b - a + math.pi) % (2 * math.pi) - math.pi end

function N:HerbFinderOn() return self.db and self.db.settings and self.db.settings.herbFinder == true end

-- Herb spots on this map you have the skill to pick (cached for 30 seconds).
function N:HerbFinderSpots(map)
 local c = self.herbFinderCache
 if c and c.map == map and self:Now() - c.at < LIST_SECONDS then return c.spots end
 local skill = (self:GatheringSkills().herb or {}).skill
 local spots = {}
 for _, n in ipairs(self:ZoneNodes(map, 'herb', '') or {}) do
  if not skill or not self:Finite(n.skill, 0, 1000) or n.skill <= skill then
   spots[#spots + 1] = { x = n.x, y = n.y, name = n.name, key = map .. ':' .. math.floor(n.x * 2000 + .5) .. ':' .. math.floor(n.y * 2000 + .5) }
  end
 end
 self.herbFinderCache = { map = map, at = self:Now(), spots = spots }
 return spots
end

-- Nearest spot not visited in the last 5 minutes: spot, distance, dx, dy (yards).
function N:HerbFinderTarget()
 local map, x, y = self:Position()
 if not map then return nil end
 local w, h = self:MapSize(map)
 if not w or not h then return nil end
 self.herbVisited = self.herbVisited or {}
 local now = self:Now()
 local best, bestD, bdx, bdy
 for _, s in ipairs(self:HerbFinderSpots(map)) do
  local dx, dy = (s.x - x) * w, (s.y - y) * h
  local d = math.sqrt(dx * dx + dy * dy)
  local seen = self.herbVisited[s.key]
  if d <= VISIT_YARDS then
   -- Close enough to see it: up or not, move on to the next one.
   if not seen or now - seen > SKIP_SECONDS then self.herbVisited[s.key] = now end
  elseif not (seen and now - seen < SKIP_SECONDS) and (not bestD or d < bestD) then
   best, bestD, bdx, bdy = s, d, dx, dy
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
   N:Guard('herb finder', function() N:UpdateHerbFinder() end)
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
  f.name:SetText('No herbs here'); f.dist:SetText('')
  return
 end
 f.texture:SetAlpha(1)
 f.bearing = angle(-dx, -dy)
 f.name:SetText(spot.name)
 f.dist:SetText(math.floor(d + .5) .. ' yd')
end

function N:SetHerbFinder(on)
 self.db.settings.herbFinder = on and true or false
 if on then
  local f = self:HerbFinderFrame(); f.refresh = 0; f:Show()
 elseif self.herbArrow then
  self.herbArrow:Hide()
 end
end

-- Picking a herb skips that spot too (you may gather from a little way off).
N:On('LOOT_CLOSED', function()
 if not N:HerbFinderOn() then return end
 local map, x, y = N:Position()
 if not map then return end
 local w, h = N:MapSize(map)
 if not w then return end
 N.herbVisited = N.herbVisited or {}
 for _, s in ipairs(N:HerbFinderSpots(map)) do
  if math.sqrt(((s.x - x) * w) ^ 2 + ((s.y - y) * h) ^ 2) <= 25 then N.herbVisited[s.key] = N:Now() end
 end
end)
N:On('PLAYER_LOGIN', function() if N:HerbFinderOn() then N:SetHerbFinder(true) end end)
