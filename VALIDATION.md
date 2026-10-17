# Validation - 0.2.0 alpha

Current result: **47 tests pass**. See `DEVELOPMENT_V5.md` for terrain routing v5 tests, benchmark, known limitations and exact in-game steps. The historical baseline results and acceptance checks follow.

**29 automated tests passed** using the installed OBS `lua51.dll`, LuaJIT 2.0.5 / Lua 5.1 language compatibility. Full output: `Tests/results.txt`. The DLL was used only as a test runtime, is not modified, and is not distributed.

All addon Lua chunks, including the licensed dataset, compiled and loaded in TOC order. Pure/model tests cover initialization, data preservation, character separation, offline search, stock allocation across queues, stale inventory, bank separation, duplicate physical identity, foreign economies, profit/cash/opportunity value, missing prices, auction assumptions, import round trips, malformed imports, strict import sanitization, Market schema/age isolation, route budgets, node deduplication, leveling and updated Forever difficulty enums. Mock client tests cover profession capture, linked-view rejection, bag/bank API adapters, gather-loot deduplication, every UI page, separate action callbacks, map pin construction, arrow updates and optional Market navigation.

The separate reliability pass fixed: nil holes in multi-return APIs, invalid persisted numeric settings, reversed assumptions about numeric profession difficulty, accidental Market window toggling, stale loot context, unknown imported UI fields, missing storage snapshots, native-view reopen spam, and repeated stock rebuilding while rendering recipe rows.

These are automated and code-review results. **No live WoW testing or rendered in-game visual QA occurred.** Mocks cannot prove protected crafting permission, taint behavior, actual profession schemas, secret values, map/facing orientation or ElvUI layering.

## In-game acceptance checklist

1. Back up SavedVariables, enable Nexus alone, `/vmn debug`, and verify interface/build. Open every page with Lua errors enabled.
2. Open each profession, compare names, reagents, output quantities, skills and recipe counts to the native UI. Check unlearned/source data. Close/reopen; switch profession; use a linked profession; verify no ownership contamination.
3. Log into two alts; browse each from the other; compare bags and bank after visiting bank. Verify bank counts persist after closing it. Exclude an alt, bank, imported records and stale records.
4. Export to the second account, preview, cancel, preview again and confirm. Repeat an older export. Inspect identity conflicts and unchanged local characters.
5. Queue crafts sharing one material. Verify required totals, allocation order, transfer instructions and missing amounts. Change quantity and remove plans.
6. Set manual reagent/output prices, verify buy-all, buy-missing, economic profit, fee and deposit assumptions. Remove/age prices. Test with Market absent, present and wrong schema. Do not use a different realm's prices for an alt.
7. Test a single craft on the current character through a hardware click outside combat. Test an offline recipe, closed profession, changed filters and a cooldown. Use native crafting if the client blocks the custom button.
8. Gather a herb and ore, including multiple taps and byproducts. Compare confirmed inventory increases to session counts; test full bags, failed casts, interrupted casts and repeated loot windows.
9. Generate a filtered route in a familiar zone for every travel preset. Face north/east/south/west; check the arrow against the map. Verify range, skip, stop, zone change, budget, custom waypoints and saved route reloads.
10. Check map pins at different zooms and screen scales; open bags and ElvUI panels. Confirm acceptable layering and frame rate in a dense zone. Potential-node pins are capped at 250.

See README for substantial unfinished scope. Treat this build as an alpha for verification, not a complete production release.


## 0.2.1-alpha: faster planning and minimap routes

- Faster directed 2-opt checks use prefix sums instead of rebuilding and measuring an entire trial route for every candidate. Directional learned paths and closed-loop budgets remain part of scoring.
- A planning window shows the current stage, completed starts/zones, elapsed time, an approximate time remaining once measurable, and Cancel. `/vmn cancelplan` also cancels. Work yields after about 3 ms or 2,500 checkpoints, and resumes on a later frame.
- Calculations stop after 30 seconds. Route generation uses the best fully completed circuit if one exists; otherwise the request stops with guidance to narrow filters or use Start Here. The cap is checked between work slices, not during individual API calls.
- Up to six recent results are cached for two minutes in memory. Exact input signatures include settings, starting position where relevant, candidate nodes, terrain, obstacles and gathering evidence. Changing these inputs invalidates reuse. Following/pausing a route still does not rerun the planner.
- A thin minimap line follows the remaining prepared travel path, including terrain detours. It updates ten times per second for movement, zoom, rotation and waypoint changes, clips to square or round minimaps, and hides when no matching active route is available. Cyan denotes learned segments; purple denotes estimates. Settings → Thin minimap route line toggles it.
- Uses Forever's `C_Minimap.GetViewRadius`; if the client cannot provide a readable map scale/position, the line is hidden rather than drawn at a guessed scale. A bounded texture fallback handles clients with unsupported Line methods.

Validation: 51 Lua 5.1/LuaJIT tests passed, covering cache invalidation/copy isolation, queued cancellation, the time limit, clock/progress reporting, minimap clipping, rotation, zoom and fallback rendering. A local imported-zone Start Here benchmark decreased from 0.179 to about 0.027 CPU seconds for 35 stops (roughly 6x); in-game timings vary. Live Forever rendering still needs an in-game check.

## 0.2.2-alpha: numbered stops and reload persistence

- Small numbered minimap dots mark actual gathering stops in route order; terrain detours are not numbered. The next stop is highlighted, and completed/offscreen stops are hidden.
- Active navigation is saved per character on logout or `/reload`, including the route, waypoint, terrain-path position and pause state. Login restores it without running the planner. Stopping/completing a route clears its saved navigation at logout. Named saved routes remain separate.
- Restoration checks route geometry and bounds, rejects malformed snapshots and resets invalid indices.
- Validation: 54 Lua 5.1 tests pass, including route restoration, character isolation, cancellation persistence, malformed saved data, numbered stops and hiding completed markers.
