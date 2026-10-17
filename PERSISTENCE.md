# Saved routes and farming recordings — 0.3.0 beta

Nexus now keeps completed route calculations across normal reloads and logins. A repeated matching request can use the saved result instead of rerunning optimization. Existing named routes, learned trails, character records and UI placement are retained.

## In the Routes page

**Generate** prefers a compatible saved circuit. **Route tools** offers recording, replay preparation, route export/import, cache status, improvement, deletion and travel settings. Select a saved route and choose **Load selected** to start it. Its details show comparisons from saved gathering sessions.

For a new Optimal or Nearest run, the closest stop is numbered 1 and circuit direction is preserved. Restoring an active run after reload preserves its current waypoint instead of restarting. Recorded paths resume from the closest recorded trail point and follow the remaining recorded geometry.

**Improve route using saved work** explicitly runs another comparison, retaining the compatible saved circuit as a candidate. It uses shared travel-leg results. The 30-second cap still applies; its best completed circuit is saved for reuse. This does not prove a global optimum or resume a suspended coroutine.

## Recording a run

1. Enter a name in the Routes value box and choose **Route tools → Record a farming run**, or type `/vmn record NAME`.
2. Walk your intended path. The draft lives in your character's saved data during recording and returns after a normal reload.
3. Choose **Finish recording**, or `/vmn record finish`. Existing names are not overwritten; `/vmn recordname NAME` renames the draft.
4. Select the saved recording and choose **Load selected**, or `/vmn replay NAME`.

Recorded geometry is preserved, not reordered by the gathering solver. Sampling occurs at most once per second after moving eight yards. A draft holds at most 2,047 trail points. Its navigation markers are a smaller set of progress anchors, capped below 150; the line retains all trail points. A position jump over 80 yards, zone change, taxi, flight, death or falling interrupts recording rather than inventing a walked connection. Finish the valid portion or discard it and begin another segment. This conservative behavior may interrupt a recording during loading or an unavailable position reading.

`/vmn record status` shows the draft; `/vmn record discard` removes it. Finishing requires at least two points. Route tools can delete an unused named route after confirmation; the saved route limit remains 50.

## Reuse and invalidation

- Up to 12 completed route or zone-comparison results, valid for seven days.
- Up to three travel contexts, each with 512 directed legs and a 400,000-unit payload budget, valid for 30 days since context use.
- Pruning uses an approximate two-MiB derived-data payload budget; Lua table and serialization overhead are additional. It is not a process-memory ceiling.
- Client build, planner compatibility, map dimensions, filters, routing settings, observed terrain and obstacle changes select different cache entries.
- Cosmetic settings and repeated harvest timestamps do not invalidate route geometry. Current gathering evidence is rescored when a route is reused.
- A→B and B→A are separate. A walked drop never proves a climb is possible in reverse.
- Large keys or payloads are deliberately left uncached; planning still works. Eviction or a cache miss is normal and never deletes named routes or observations.

`/vmn cache` reports saved entries and this login's reuse counts. `/vmn cache clear` deletes computed data only. `/vmn route fresh` explicitly improves a compatible saved route. Unknown future cache formats are left untouched and disabled for this version.

## Sessions and backups

Current gathering totals and route performance now resume after normal reload/logout. Offline time is excluded from the restored session timer. Gathering's **Save/reset** archives a session for route comparisons; **Discard/reset** starts fresh. Comparisons show weighted overall material rate, median session rate and best session rate, rather than claiming a guaranteed gold yield.

**Export selected route** creates a non-executable copy/paste string; **Import route** previews it before confirmation. Existing names are never overwritten. Both generated routes and recorded geometry can be exported. `/vmn routeexport NAME` and `/vmn routeimport` open the same flow. This is a route backup, not a full backup of learned terrain, nodes or the entire account database.

WoW writes declared SavedVariables to disk during normal reload/logout. Updating a draft in memory is not immediate disk I/O and does not guarantee recovery after a crash. Keep a copy of the game's `VoidMarkNexus.lua` SavedVariables file when backing up the full addon database.

## Optional travel guidance

With Shortest Path Forever installed, select a route and choose **Travel to selected route**. Nexus calls its public version-1 navigation API only after that click. Normal Nexus route planning has no dependency on it. A successful handoff pauses farming guidance; use **Load selected** when ready to farm. API refusal or absence produces a message without losing your route.

This release uses original Nexus implementations informed by the package audit. It does not bundle those addons' source, databases or artwork. Full profession-to-target planning and a collision mesh remain outside this release.

## Validation and updating

Automated tests exercise saved-data serialization, reload restoration, bounds, invalidation, timeout preservation, recordings, imports, optional integration failures and existing addon behavior. Frame mocks cannot establish in-game rendering, taint behavior or actual travel timing.

Download the repository's `dist/VoidMarkNexus.zip` for installation. The ZIP is checked byte-for-byte against the addon source by `python tools/package.py --check`. GitHub Actions runs the suite under Lua 5.1 and checks that archive on each push/PR.
