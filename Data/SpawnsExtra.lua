-- Extra Black Lotus spots Nexus's spawn list was missing (Nov 2026).
-- Stop positions from warcraftmaps.com's Black Lotus page (Classic spawn data on Forever terrain),
-- supplied by the owner. Map percent / 100. A spot is added only when Nexus has no spawn within
-- 1% of the map there, so nothing already known is doubled.
local _, N = ...
local BLACK_LOTUS = 176589
local extra = {
 [1444] = { 0.627,0.291 },                                   -- Feralas: The Maul (Dire Maul arena)
 [1428] = { 0.626,0.394, 0.555,0.420, 0.432,0.343, 0.356,0.489, 0.314,0.566,
            0.211,0.466, 0.544,0.633, 0.766,0.486, 0.825,0.341 }, -- Burning Steppes
 [1423] = { 0.671,0.433, 0.521,0.572, 0.232,0.729, 0.336,0.232, 0.612,0.239 }, -- Eastern Plaguelands
 [1452] = { 0.675,0.422, 0.492,0.086, 0.515,0.409, 0.594,0.592, 0.631,0.728, 0.656,0.633 }, -- Winterspring
 [1451] = { 0.390,0.830, 0.188,0.840 },                       -- Silithus
}
N.spawns = N.spawns or {}
local zones = N.spawns[BLACK_LOTUS] or {}
N.spawns[BLACK_LOTUS] = zones
local added = 0
for map, pts in pairs(extra) do
 local list = zones[map] or {}
 zones[map] = list
 for i = 1, #pts, 2 do
  local x, y, near = pts[i], pts[i+1], false
  for j = 1, #list - 1, 2 do
   local dx, dy = list[j] - x, list[j+1] - y
   if dx*dx + dy*dy < 0.0001 then near = true break end
  end
  if not near then list[#list+1] = x; list[#list+1] = y; added = added + 1 end
 end
end
N.extraLotusSpots = added
