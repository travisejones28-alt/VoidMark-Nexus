# Nexus 0.3.1 beta — hardening review

Reviewed main at `2bfbf6e` and retained existing saved routes, learned trails, cached calculations, settings and artwork.

Confirmed fixes:
- Temporary map-data unavailability after reload no longer marks a valid recording draft interrupted. Confirmed zone changes and large position jumps retain their existing interruption rules.
- A partial bag/bank read, unresolved occupied slot or failed item-info call no longer replaces the last complete inventory snapshot. Readable empty containers still clear outdated stock. Missing link labels preserve cached item names.
- Future-dated inventory is not treated as fresh. Malformed optional Market records fall back cleanly; the live integration test verifies economy isolation.
- Missing/invalid modern reagent schematics and output ranges remain incomplete estimates rather than becoming zero-cost recipes. Restricted API results become unknown without shifting later return values.
- A paused HUD respects the guidance visibility setting. Cardinal bearings, distance, ETA, scale, anchors and next-stop controls retain regression coverage; removed headings/help are not restored.
- Passing a transit point within an eight-yard corridor can advance it when no more than 50 yards past its endpoint. Gathering stops are not auto-skipped by this rule.
- `/vmn rejoin`, also in the HUD menu, targets a forward point within the current remaining leg. It cannot jump over an unvisited gathering stop or rewind completed stops. A player far off route receives straight-line guidance to that remaining leg; no collision guarantee is added.
- Reload repairs contradictory waypoint/geometry indices while preserving valid progress and pause state.
- Closing a gathering loot window clears its cast correlation, preventing another window from inheriting that cast.
- Trail sample-count changes alone no longer invalidate calculations when geometry and measured costs are identical; cost changes still invalidate them.

Validation: **93 stock Lua 5.1 mock tests** pass, plus the complete four-addon shared-client integration in both Nexus/Mini Map load orders. The shared test uses actual addon sources and tests handlers and frame attributes, not pixels, z-order rendering or protected execution. GitHub CI now includes this integration and the source/ZIP consistency check.

Known limits remain: bounded heuristic optimization, a 30-second time cap, selected candidate stops rather than a global optimum, observed trails rather than a collision mesh, unknown live resource availability, and current-target ETA rather than a guarantee of total trip time. Derived caches remain capped; historical user records are retained. Large production saves still need in-game profiling. Settings and SavedVariables schema were not reset.

In-game checks: generate/reload/reuse a route; compare `/vmn cache`; pass a detour on foot and mounted; pause/hide/show; try `/vmn rejoin` after stepping aside; reload mid-route; record/reload/finish/replay a short loop; open a profession while data is loading; open/close the bank; verify two alts' inventory and a known recipe calculation. Gather two nodes with an unrelated loot window between them and verify totals.
