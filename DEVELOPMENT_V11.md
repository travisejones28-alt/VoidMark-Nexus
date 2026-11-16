# Nexus 0.11.0 beta: development notes

Reviewed main at `ef975bc` (0.10.31-beta). Saved variables, characters, sessions, laps, spots, trails, obstacle marks, routes and sync records are all kept; no schema reset.

## Audit: what was there before

| Area | Before 0.11 | Conflict / gap |
|---|---|---|
| Route generation | Fast zone loop (RouteGen.lua, 0.5): straight-line distance, optional land-outline penalty | Terrain graph (Terrain.lua, Routes.lua `TerrainLeg`, Cache.lua) still present but only used by the retired `BuildRoute` planner; trail learning switched off by the 0.5 migration |
| Route learning | History by zone + variant (`routeHistory.stats`) | Different loops in one zone shared statistics; `RouteIdentity` hashed speed/mode, so the same loop changed identity whenever measured speed changed |
| Market | Read-only `VoidMarkMarketDB` adapter with confidence | No farming gold/hr; Market staleness/developing status not used; Market link opened Opportunities (item often absent) |
| Leveling | Strong planner (modes, allocations, trainers) | Text summary omitted the steps; no "what now", no method comparison, no grouped collection list |
| Skinning / fishing | Fishing guide only; skinning rank 1 counted as gathering | No observation, pools, sessions or advice; skinning ranks 2-4 not counted |
| UI | Fixed 480x560 window with scale | No resizing; no multi-resource picker; no grey filter |
| Sync | Automatic, hashed sections | Any received section replaced stored data even if older; status only showed "last received" |

## What changed

New files (all before `Boot.lua` in the TOC): `RouteTerrain.lua`, `RouteLearning.lua`, `LevelingPlus.lua`, `WildGather.lua`, `Interface.lua`, `Dashboard.lua`. Edited: `Core.lua` (version, one-time trail-learning re-enable, `terrainRouting` default), `RouteGen.lua` (terrain cost hook, multi-seed loop, directed legs), `Routes.lua` (arrow follows leg trail points; ring drawing), `MinimapRoute.lua`, `RoutePlanner.lua` (preview colours, terrain line), `Gathering.lua` (cast timing, loot hook), `Prices.lua` (Market status, browse view), `Sync.lua` (newer-wins merge, diagnostics), `UI.lua` (resizing, stale flag, sync line), `Boot.lua` (command registry, map filter entries).

### Terrain-aware loops
- Leg cost comes from a read-only view of the zone's learned corridors (heap Dijkstra, one search per anchored stop, at most 160) and obstacle marks; plain distance is used when the zone has neither, so behaviour there is unchanged.
- A learned corridor replaces the straight line when its length is at most 1.5x (walked once) or 2.5x (walked at least twice on average). It always replaces a straight line through a marked obstacle. Marked obstacles are otherwise passed with the existing visibility-graph detour (estimated). A leg with no way round a mark gets a large finite penalty instead of infinity.
- Optimisation uses the mean of both directions so 2-opt stays valid; the final loop is evaluated in both directions on the directed legs and the cheaper one kept. Loops of 6-60 stops also try two extra seeds.
- Each leg stores trail points flagged verified/estimated. The arrow snaps forward along the current leg's points (never backward), the world map and minimap ring draw them, and the preview colours them.
- Map artwork is never used as collision. Swimming edges are excluded from routing.

### Route learning and value
- `RouteKey`: zone + sorted 40-yard stop cells (start and direction do not matter).
- Records (`routeHistory.routes`, max 150, least-run pruned first): laps, part laps (stopped after 60 s with 2+ visits), seconds, gathering seconds, visited, found, empty, item quantities, skill gain, packed stops.
- Expected nodes/hr = (estimate x 3 + real x laps) / (3 + laps); confidence estimate / low / medium / good. Gold/hr from the loop's own loot once it has 3+ finds, otherwise price x observed yield per node (from your gathers; 1 when fewer than 3 gathers). Unpriced resources make it partial; nothing unpriced is counted as zero.

## Testing performed
- `lua5.1 Tests/run.lua`: **220 tests pass** on stock Lua 5.1 (177 before plus 43 new across `Tests/v011_*.lua`). Two existing tests were changed on purpose: Market navigation now expects the browse view, and the scroll test checks visible rows instead of the row-pool size.
- `python3 Tests/integration.py` with real VoidMark Mini Map, VoidMark Forever and VoidMark Market sources in one mocked client, both load orders: pass.
- `python3 tools/package.py --check`: ZIP matches source.
- Benchmark (mock, CPU time): Durotar herb loop with a 600-point / 2,300-edge trail graph builds in about 0.25-0.35 s.

These are mocked-client tests. **Nothing here was run in the live Forever client.** Pixels, z-order, protected execution, real loot-source GUIDs and real addon-message timing are not covered.

## Known limitations
- Trails prove a path exists, not that the straight line is blocked. A long learned detour walked only once is ignored (1.5x rule); walk it twice to make it count, or mark the obstacle.
- Building a loop with a full trail graph still runs in one frame (no coroutine): expect a short hitch (~0.3 s measured in mock) in heavily walked zones.
- Pool detection depends on `GetLootSourceInfo` naming the pool's game object. If Forever reports the bobber for pool catches too, pools are only learned through `/vmn pool NAME`. Pool positions are where you stood, not the pool centre.
- Skinning level rule and zone ranges are Classic's; Forever may differ. Skinning spots are where beasts were.
- Gold/hr uses current prices for past loot, not the price at the time.
- Sync still needs both characters online; offline exchange is Export/Import only.

## In-game checks (please run)
1. Install from `dist/VoidMarkNexus.zip` or the junction; `/console scriptErrors 1`; `/reload`; `/vmn debug` shows no errors.
2. `/vmn terrain` should say learning is on. Walk between two herb spots in both directions twice, then `/vmn route`: the preview shows cyan on that leg; start it and check the arrow follows the walked path ("Learned trail") and the world map and minimap draw it.
3. `/vmn block 60` beside a cliff or building, rebuild: the loop goes round the mark (purple). `/vmn clearblocks` removes it.
4. Run two different loops in one zone for a lap each, then `/vmn routes`: two separate lines with nodes/hr; `/vmn runroute 1` starts the first again; `/vmn routereset 1` clears only it.
5. With VoidMark Market prices: route options show `~Xg/hr`; `/vmn prices` shows age/confidence; shift-click a stop opens Market's search on that item; nothing is bought or posted.
6. Pick *Herbs for gold*: options rank by gold/hr. `/vmn compare` prints herbs and ore lines.
7. Professions > Level up: the "Now:" line matches your skill and bag contents; click a method under *Compare methods*; open the shopping list.
8. Skin 3-4 beasts, then `/vmn skinning`: spots, beast names and levels appear. Fish a pool and open water: `/vmn fishing` shows catches; check whether the pool was detected (if not, `/vmn pool NAME`).
9. Drag the window's bottom-right corner; `/reload`; size and position are kept. `/vmn resetwindow` restores them.
10. With both accounts online, `/vmn sync` shows connected and a recent successful sync; log the bank out and check it changes to waiting/not answering. Move items on the bank, reopen it, confirm the main sees the new counts.
11. `/vmn dash` while gathering: numbers move; reload keeps the window shown.
