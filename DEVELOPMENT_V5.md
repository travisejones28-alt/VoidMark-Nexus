# Nexus terrain routing v5 - 0.2.0 alpha

Implemented against main `fc4f468a2f411b7cdb9132263fa5de252fe208d2`.
The high-strata map-pin overlay introduced in `8220539` is preserved.

## Implemented

- Persistent, versioned directional movement graph. Sampling runs every 0.5 seconds, retains roughly 8-40 yard segments, and rejects gaps over two seconds, implausible speed, transitions, taxi travel, flight, falling and death when those client checks exist. Swimming is recorded separately and excluded from ground routing. Movement speed is stored with each edge; the latest mount/form state is available in memory.
- Bounded Dijkstra search (A* with a zero heuristic) uses measured travel time scaled to the selected speed. Only recorded edges connect graph vertices. Endpoint connectors up to 20 yards remain unverified. The system does not derive collision or elevation from artwork.
- Manual circular blocks remain supported. Their visibility-graph detours now use sufficient clearance at large radii, and unreachable paths never fall back to direct guidance through the block.
- Route construction uses actual terrain leg costs, a per-build directed distance cache, multi-start nearest-neighbor variants, directed-safe 2-opt and shorter-loop comparisons. Full return-to-origin travel and gathering delays count against the budget. Existing limits are retained: at most 35 stops and 250 clustered candidate patches per start.
- UI route generation, preview generation and Top 5 comparisons run incrementally. Checkpoints target three milliseconds when the client profiling clock exists, with an operation-count fallback. Combat cancels planning. `/vmn cancelplan` cancels it manually. Movement learning pauses during planning to keep its graph stable.
- One prepared geometry drives the arrow, projected map/diagram and world map, including the start, intermediate points and closing detours. Cyan means a recorded corridor; purple means unverified travel. Resource icons and the dedicated high-strata pin overlay remain intact. Route dots use that overlay too and are capped at 350.
- Navigation supports pause/resume, restart, skip, cancel and a Settings toggle requiring manual confirmation at gathering stops. Completing the last gathering stop continues through the closing leg before finishing the loop.
- Top 5 evaluates every eligible zone with available dimensions, compares in-zone efficiency, exposes alternative candidate loops and shows spawn counts, loop length, observed stops and learned-distance coverage. Travel to the zone is explicitly excluded. All compared rows use the same rate metric.
- Confirmed harvest quantities and durations are stored separately from explicit availability checks. `/vmn check empty` and `/vmn check available` record checks near the current stop, with a one-minute duplicate guard. Harvest success alone never establishes availability. Resource/hour estimates require at least five checks and three harvests at every stop; otherwise the UI reports potential stops and unknown harvest rate. These thresholds are minimum evidence gates, not statistical confidence guarantees.
- Session records include resource totals and active-route time/yield for comparing actual runs. Pauses and time outside the route zone are excluded. Existing value/hour uses optional pricing and remains unknown when prices are missing.
- Gathering rejects a mismatched loot-source GUID when the client supplies source information. Missing source data uses the existing matched-cast/time window plus a position check, so source ambiguity remains a client-dependent limitation.
- Audit fixes: readable empty inventories clear stale stock; modern crafting accepts either learned-recipe flag; custom travel mode retains custom speed; missing map icon size is initialized; saved-route loading recalculates terrain geometry; restart resets the detour index.

## Bounds and compatibility

Terrain: 50 zones, 600 samples and 2,400 directed edges per zone; full zones stop admitting new samples rather than deleting history. `/vmn terrain clear` clears this zone's trails for rebuilding, without removing obstacle marks. Prepared geometry is capped around 2,048 intermediate points. Gathering evidence: 50 zones and 3,000 locations per zone. Existing session retention remains 100 sessions; route performance stores at most 30 route identities per session.

SavedVariables schema stays at 1; terrain has its own version. Invalid graph coordinates/edges and obstacle records are sanitized. A newer terrain version is preserved and disabled. Existing characters, recipes, inventory, preferences, node data and saved routes are not intentionally reset. Licensed node data and notices are unchanged. No other addon is required and no communication or telemetry was added.

## API findings and limitations

The code uses capability checks for `C_Map.GetPlayerMapPosition`, `C_Map.GetMapWorldSize`, map-art/exploration functions, movement speed, taxi/flight/swimming checks and texture rotation. `/vmn debug` reports availability on the actual client. No live Forever API probe was possible in this session. Artwork is used only for display; no available collision mesh, elevation mesh or authoritative walkability interface has been established.

Observed trails are evidence of past traversal, not guaranteed navigation. Sparse samples can miss sharp bends or changed conditions, and very close stacked floors cannot be disambiguated without elevation. Swimming edges are not used for ground routes. No automated failed-approach inference, imported terrain mesh, combat navigation, player movement, respawn model, competition estimate, 3-opt, ant-colony optimizer or guaranteed optimal tour is claimed. Unknown connectors and manual-block detours are explicitly estimates. Short-loop rate estimates do not establish that resources will respawn before the next lap.

## Validation

Run from the repository root:

```powershell
.\Tests\Run.ps1
```

Or use a Lua 5.1-compatible interpreter: `lua Tests/run.lua`.

47 regression tests pass under the installed OBS LuaJIT 2.0.5 / Lua 5.1-compatible DLL. All addon Lua modules compile/load in TOC order. Tests cover the existing profession/inventory/import/market systems plus closed-loop budgets, directed 2-opt, candidates, duplicates, travel speed, ranking, obstacles, detours, unreachable endpoints, terrain migration and bounds, manual navigation, corrupt nodes, incremental processing, UI construction and high-strata map pins. A real imported-zone start-here route with 35 stops took about 0.10 CPU seconds after replacing formatted string cache keys with table-keyed caching (about 4.2 seconds before that change). This is one mocked-runtime benchmark, not an in-game frame-time guarantee or a dense learned-graph benchmark.

No in-game testing or visual verification was performed. Mocks cannot establish Forever compatibility, actual loot GUID formats, map zoom/panning behavior, ElvUI compatibility or protected crafting permissions.

## In-game acceptance

1. Fetch/pull the repository in GitHub Desktop, then `/reload`. The existing junction must target the inner `VoidMarkNexus` folder. Alternatively use the updated `dist/VoidMarkNexus.zip`.
2. `/console scriptErrors 1`, then `/vmn debug`. Verify the expected map and movement APIs are present.
3. In a familiar zone, `/vmn terrain on`; walk a corridor in both directions, then `/vmn terrain` to inspect sample/connection counts. Take a flight path or hearth and verify no jump connection appears.
4. `/vmn target Silverleaf`, then `/vmn route`. Compare the start, stop numbers and detours in the arrow, world map and both preview modes. Check explored and unexplored terrain, map zoom/panning, icon sizes and filters.
5. Enable **Require manual skip at gathering stops** in Settings. Approach a stop; it must remain until `/vmn skip`. Test `/vmn pause`, `/vmn restart`, `/vmn stop`, changing zone and finishing the return leg.
6. Test `/vmn block 90` near a known obstacle, regenerate and inspect the detour. `/vmn clearblocks` removes this zone's marks. `/vmn terrain clear` resets only learned trails.
7. Compare Top 5 and alternate loops on Foot, 60% Mount, 100% Mount, Travel Form and Custom. Check the labels distinguish potential stops from sampled resource yield; zone-entry travel is excluded.
8. Gather herbs/ore, interrupt a cast, loot a corpse and test full bags. Verify only actual gathering loot increases totals. Record both available and empty checks; compare two saved gathering sessions.
9. Repeat the profession/bank/import/Market checklist in `VALIDATION.md`, including Nexus with Market absent.

Next priorities: in-game acceptance and tuning, richer sampling/corridor simplification, multi-anchor endpoint search, learned swim/form-specific navigation, stronger repeated-loop availability evidence and more detailed historical route comparisons.
