# VoidMark Nexus 0.5.0 beta

Gathering routes, profession leveling and your items across both accounts, for WoW Forever (interface **16001**).

## What it does

**Gather.** Pick Herbs, Ore, one specific herb or ore, or *Herbalism / Mining skill-ups*, then press **Start route**. Nexus draws one smooth loop through the zone right away: spawns close together become one stop, lonely outliers are dropped, and the stops are ordered so the path never crosses itself. The arrow takes you stop to stop and moves on by itself when you get close or gather a node. The loop keeps going lap after lap. **Best zones** lists the zones with the most matching spawns for you.

**Professions.** Pick a profession (any of your characters). *Level up* shows the cheapest (or fastest) steps to your target skill, what to buy, and which recipes to train. *Recipes* lists every recipe with its profit, most profitable first; hover for materials and prices.

**Characters.** Your characters with how fresh their bag and bank data is. Pair with the bank character on the other account to sync live while both are online. Item tooltips show how many of that item each character holds.

**Gold.** Every character's gold is saved when you log in and whenever it changes, and the bank character's gold syncs over with its bags. The Characters page shows each character's gold and the total; `/vmn gold` prints it in chat.

**Find item.** Type in the box at the top of the window (part of a name, an item ID, or shift-click an item into it). Nexus lists every character holding it, split into bags and bank, with how old that information is. `/vmn find NAME` gives the same answer in chat.

**Settings.** A short list of checkboxes, the route lap length, and the window size.

## What changed in 0.10.0
- **Find item sees the mailbox and worn gear.** The mailbox is read when you open it; gear whenever it changes. Items you mail to another character show as "In the mail to X" until that character opens their mailbox (or 30 days pass).
- **Profession cooldowns on every character** (Mooncloth, transmutes, Salt Shaker, and any recipe cooldown seen in a profession window): synced with the other account, on the Characters page, announced at login when ready. `/vmn cd` lists them.

## What changed in 0.9.0
- **Route options with a preview.** Gather > Start route builds several loops (Quick, Balanced, Long, Stay on land when the zone has water to cross, plus the best loops in two other zones) and shows each on the zone's map. With OpenMap installed (English client) the preview uses OpenMap's terrain art; otherwise the game's zone map. Pick one and press Start this route. `/vmn route now` still starts the balanced loop straight away.
- **Learns from your picks.** Every pick and every lap on it (nodes picked, minutes) is logged per zone and kind of route. Options are ranked by expected nodes per hour, pulled toward what you really got; the top one is marked Recommended and says why. `/vmn routelog` shows the history.
- **Land outlines from OpenMap** (MIT, baked into Data/ZoneLand.lua by tools/bake_openmap.py) keep "Stay on land" loops from cutting across sea or out of the zone. They are zone outlines, not rivers or cliffs.

## What changed in 0.8.0
- Gold tracking on every character, synced across accounts, with a total on the Characters page and `/vmn gold`.

## What changed in 0.7.0
- Find item: search all saved bags and banks (both accounts) from the top of the window or `/vmn find`.
- Sync works with either Forever name form and retries on its own; old first-name records move to full names.

## What changed in 0.6.1
- Minimap stops are hollow rings with the number beside them, and route lines stop at the ring, so the herb/ore blip under a stop always shows.
- Zone loops stay on a stop when you reach it ("look around") and move on when you gather there or walk 20 yd past it, so a stop never disappears before you've looked.
- The arrow no longer hides in combat (the 0.6.0 setting is removed).

## What changed in 0.6.0
- **Loops learn.** Reach a stop and gather there: the spot counts as found. Reach it and leave empty-handed: it counts as empty. Rebuilt loops favour spots where you found things and skip spots that were empty 5 times and never found. Setting: "Learn which spots are often empty". `/vmn spots forget` clears this zone.
- **Lap stats.** Each lap prints picked, empty, minutes and skill gained; the Gather tab shows this lap and the last one, and each stop shows how often you found something there.
- **Real speed.** The arrow's seconds and the lap minutes use how fast you actually move.
- **Auto re-plan.** On a skill-up loop, when a herb or ore turns grey or a new one unlocks, the loop rebuilds from where you stand.
- **Gold routes.** "Herbs for gold" / "Ore for gold" weight stops by VoidMark Market price, and leave out anything above your skill.
- Reached stops leave the map; the next stop's number hides within 40 yd so the node blip shows; duplicate spawn entries count once.

## What changed in 0.5.0

- New compact window with four pages instead of eleven tabs.
- New route builder: instant zone loop instead of the 30-second planner and its progress window.
- Item tooltips show counts per character, including the synced bank character.
- Removed from the window: crafting queue, session stats, route recording, learned trails and obstacle marks. Their saved data is kept. Learning trails in the background is now off, which saves CPU.

## Commands

| Command | Action |
|---|---|
| `/vmn` | Open or close the window |
| `/vmn start`, `/vmn stop`, `/vmn next` | Start the route, stop it, skip to the next stop |
| `/vmn kind herb\|ore\|all`, `/vmn target NAME` | What to gather |
| `/vmn skillroute herb\|ore` | Skill-up loop for the current zone |
| `/vmn pair NAME`, `/vmn sync` | Pair with the other account, sync status |
| `/vmn price ITEM_ID GOLD` | Set your own price for an item |
| `/vmn help`, `/vmn debug` | Command list, diagnostics |

## Install

Install the repository root as **VoidMarkNexus** (it directly contains `VoidMarkNexus.toc`). The AddOns folder name must match the TOC name exactly: a junction named `VoidMark-Nexus` will not load. Use `Install-WoWLinks.ps1`, or `mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\VoidMarkNexus" "C:\WoW Forever Addons\VoidMark-Nexus"`. Enable it and use `/vmn`. Log into each character, open every profession, and visit the bank to populate records. Keybinding: Open VoidMark Nexus. The minimap gem opens the window; right-click opens Settings.

## Integration contract v1

Nexus reads `VoidMarkMarketDB.schemaVersion == 1`, `economies[normalizedRealm .. '|' .. faction].market[itemID]`, unsuffixed records only, `fairValue`/`latest.median`, and `lastSeen`/`latest.at`. It does not mutate Market records or infer ages for missing timestamps. Unknown schemas fail closed. `VoidMarkNexus.integrationVersion == 1`; `:Price(itemID)` returns `unit`, `source`, `at`, `stale`, optional `confidence`. `:Shopping()` returns per-plan materials with allocations and missing quantities. This is a Nexus API, not an undocumented promise that Market implements a new API. Market source remains unchanged.

## Licensing

Original Nexus implementation: MIT, see LICENSE. GatherLite node definitions and data: Copyright (c) 2019 Wuild, MIT; full license in `VoidMarkNexus/Licenses/GatherLite.txt`. See `SOURCE_REVIEW.md` for reference decisions. Other reference addons and TomTom artwork are not redistributed.

## Older versions

### What's new in 0.4.1

**Live sync between your two accounts.** On Voidmark Soulreaver type `/vmn pair Bank` (the bank character's name), and on the bank character type `/vmn pair Soulreaver`. While both clients are online on the same realm and faction, each sends the other its bags, bank and professions through the game's addon whisper channel. Only changed sections are sent, and only paired names are accepted. Synced characters show as **[Synced]** and count toward materials (Settings: "Use synced characters"); transfer lines say "Mail from ... (other account)". `/vmn sync` shows status, `/vmn sync now` resends, `/vmn unpair NAME` stops. Nothing is sent while the other character is offline; it catches up the next time both are online. Manual export/import still works.

**Trainers and recipe vendors, recorded in game.** Opening a profession trainer records its name, location, recipes, required skill and cost. Opening a vendor records any recipes it sells (Recipe/Plans/Pattern/Schematic/Formula/Manual) with price and limited stock. The Leveling plan then lists recipes you can train now and where, where to buy unlearned recipes, and which trainer to visit for the next rank. Nexus ships no trainer data; it only knows NPCs you have opened.

**Resizable window.** Drag the corner grip to resize; the list shows more rows and the detail pane grows. Size and position are saved. Window scale is still in Settings. Recipes lists add ROI and two sorts: Cash ascending (most affordable) and Fewest missing.

### What's new in 0.4.0

**Leveling planner (new Leveling tab).** Pick a profession, type a target skill in the bottom field (leave `1` to plan to your current rank cap) and choose the route type with the top-right button: **Cheapest**, **Fastest**, **Self-found** (uses what you and your alts already hold first) or **Balanced** (cost plus a per-craft time value set in Settings). The plan lists each step (skill range, recipe, crafts, colour), total materials with have/missing per character and transfer instructions, cash to buy what is missing, recipes you cannot use yet with the client's source text, and when a trainer rank is needed. **Queue plan** sends the steps to Crafting.

How it works: the game only reports a recipe's current colour, not its thresholds. Nexus now records the colour every time a profession is scanned and derives where yellow, green and gray start. Unseen boundaries are estimated conservatively and the plan says so; it gets sharper as you level, because each skill-up rescans the open profession. Skill-up odds use the standard Classic rule (orange 100%, then falling linearly to 0 at gray). Craft counts are expected values. Nexus has no trainer/vendor database; it shows only source text the client supplies.

**World-map controls fixed for OpenMap.** The Nexus map button and filter panel are now parented to the screen instead of the world map, so map replacements that resize or re-skin the map can no longer hide them. The button follows the map open/close, can be Shift-dragged (position saved), right-click resets it, and `/vmn mapcontrols reset` restores it if it is ever lost. The world-map button and minimap right-click now open the same filter panel (nodes on/off, herbs, ore, other, routes, icon size). `/vmn debug` lists detected map addons.

**TomTom.** When TomTom is installed, the current gathering stop is mirrored as one temporary TomTom waypoint and updated as you advance (Settings: on by default; TomTom's own arrow is off by default so it does not compete with the Nexus arrow).

**Market confidence.** Price lines now show VoidMark Market's confidence score and flag low-confidence (sparse) prices.

### Install

Install the repository root as **VoidMarkNexus** (it directly contains `VoidMarkNexus.toc`). The AddOns folder name must match the TOC name exactly: a junction named `VoidMark-Nexus` will not load. Use `Install-WoWLinks.ps1`, or `mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\VoidMarkNexus" "C:\WoW Forever Addons\VoidMark-Nexus"`. Enable it and use `/vmn`. Log into each character, open every profession, and visit the bank to populate records. Keybinding: Open VoidMark Nexus. The minimap gem opens the window; right-click opens Settings.

### Implemented

- Shared account database; character-specific recipes and timestamped bag/bank snapshots. Optional imported-character inventory, exclusions, and stale-data controls. Cross-realm and cross-faction inventories are excluded from calculations. Binding and mail restrictions must be checked in game.
- Modern schematic API with legacy trade skill and craft fallbacks; offline and account-wide recipe search, known/unknown/wishlist filters, price and margin sorting, recipe details, source text where provided by the client. Linked/guild/NPC professions do not overwrite your character.
- Manual two-account export/import with bounded non-executable serialization, validation, preview, explicit confirmation, duplicate-identity and stale-record protection. Imports never overwrite local characters. Uncompressed exports are limited to 2 MB.
- Craft queues with shared stock allocation, shopping lists and per-source transfer instructions. Offline crafts remain plans; current-character crafting requires the open profession and a user click. Enchantments with no output item have no assumed sale value.
- Buy-all costs, buy-missing cash, owned-material value, economic profit, net sale-of-reagents comparison, variable output range, configurable fees, deposit cash/loss, sold fraction and waste assumptions. Unknown prices invalidate totals rather than becoming free materials. Conservative minimum recipe output is used for profit.
- Read-only VoidMark Market schema-1 integration, realm/faction scoped; optional Auctionator lookup, timestamp-preserving Nexus cache, manual prices. Manual-first is configurable. Market is optional. Market navigation filters its existing opportunities view; it does not purchase materials or inject an order.
- GatherLite's MIT-licensed Forever potential spawn data and resource definitions. Deduplicated observed nodes, herb/ore and name filters, world-map pins, recorded gathering loot statistics and bounded session history.
- Foot, 60% mount, 100% mount, Travel Form and custom route assumptions. Bounded nearest-neighbor plus 2-opt route improvement, time budget, save/load, manual waypoint creation, numbered map pins and independent purple arrow. No TomTom dependency or copied TomTom art.
- Short-horizon leveling ranking by purchase cost or fewest missing materials, using explicit approximate difficulty probabilities. Rescan after each skill gain.
- Ten-page dark interface, item tooltips, character/profession dropdowns, search, paging, movable window, saved position, scale, settings and diagnostics.

### Commands

| Command | Action |
|---|---|
| `/vmn` | Toggle window |
| `/vmn native` | Restore native profession preference/access |
| `/vmn price ITEM_ID GOLD` | Set manual unit price; e.g. `/vmn price 2447 0.25` |
| `/vmn export` / `/vmn import` | Cross-account copy/paste |
| `/vmn kind herb`, `ore`, or `all` | Gathering resource type |
| `/vmn target Silverleaf` | Name filter; empty target clears it |
| `/vmn route` | Generate a route in the current zone |
| `/vmn save NAME` | Save active route |
| `/vmn waypoint` | Add current position to a custom route |
| `/vmn skip` / `/vmn stop` | Advance or stop guidance |
| `/vmn debug` | Build and API diagnostics |

Settings contain speed, time budget, remount and gathering delays. Selecting a travel preset resets speed and delay to its assumptions. Custom settings can be edited afterward. Travel geometry uses observed directional trails and manually marked obstacle detours; unverified connectors remain estimates. There is no collision mesh. Routes do not know live spawns or unseen player competition. Map rendering caps potential-node pins at 250; routes cap at 150 waypoints and improve only a nearby candidate subset.

### Incomplete / needs follow-up

- Full native-window replacement is deliberately not claimed. Selecting Nexus opens its browser while preserving Blizzard's data source and crafting access. No suppression of protected native UI.
- No bundled complete Forever recipe/source catalog. The browser records the catalog exposed by an opened profession; legacy APIs expose learned recipes only. Specialization and prerequisite modeling, full leveling threshold tables and full trainer shopping are not implemented.
- No collision mesh, live-spawn visibility or congestion model. Learned corridors, manual obstacle detours, minimap route lines and route/session recording are implemented; full automatic performance-based circuit optimization remains future work.
- No compressed/chunked transfer, arbitrary source-addon SavedVariables migration, guild/reagent/account bank support, per-item binding-aware transfers, or deeply integrated Market shopping orders yet.
- Alternative reagent slots are marked incomplete rather than guessing. Uncached modern item binding metadata and unexposed profession cooldowns need in-game review.
- UI is fixed-size with adjustable scale. Import preview is displayed in the transfer window before confirmation. Full visual QA in the game, localization, secret-value coverage and every Forever-specific profession require client testing.
- Gather tracking uses confirmed known gathering spells and matching node names; unknown/localized resources and rank-specific spells may need extensions. Recorded loot includes byproducts. No claim of complete fishing/skinning support.

### Validation

Run `lua Tests/run.lua` from the repository root using Lua 5.1, or `pwsh -File Tests/Run.ps1 -LuaDll PATH` with a Lua 5.1 compatible DLL on Windows. Tests cover pure logic, mock API scanning, persistence, imports, inventory allocation, prices, routes and UI construction. See `VALIDATION.md` for actual results and in-game checks. Keep a copy of `WTF/Account/.../SavedVariables/VoidMarkNexus.lua` before testing upgrades.

### Integration contract v1

Nexus reads `VoidMarkMarketDB.schemaVersion == 1`, `economies[normalizedRealm .. '|' .. faction].market[itemID]`, unsuffixed records only, `fairValue`/`latest.median`, and `lastSeen`/`latest.at`. It does not mutate Market records or infer ages for missing timestamps. Unknown schemas fail closed. `VoidMarkNexus.integrationVersion == 1`; `:Price(itemID)` returns `unit`, `source`, `at`, `stale`, optional `confidence`. `:Shopping()` returns per-plan materials with allocations and missing quantities. This is a Nexus API, not an undocumented promise that Market implements a new API. Market source remains unchanged.

### Licensing

Original Nexus implementation: MIT, see LICENSE. GatherLite node definitions and data: Copyright (c) 2019 Wuild, MIT; full license in `VoidMarkNexus/Licenses/GatherLite.txt`. See `SOURCE_REVIEW.md` for reference decisions. Other reference addons and TomTom artwork are not redistributed.


### 0.2.1-alpha: faster planning and minimap routes

- Faster directed 2-opt checks use prefix sums instead of rebuilding and measuring an entire trial route for every candidate. Directional learned paths and closed-loop budgets remain part of scoring.
- A planning window shows the current stage, completed starts/zones, elapsed time, an approximate time remaining once measurable, and Cancel. `/vmn cancelplan` also cancels. Work yields after about 3 ms or 2,500 checkpoints, and resumes on a later frame.
- Calculations stop after 30 seconds. Route generation uses the best fully completed circuit if one exists; otherwise the request stops with guidance to narrow filters or use Start Here. The cap is checked between work slices, not during individual API calls.
- Up to six recent results are cached for two minutes in memory. Exact input signatures include settings, starting position where relevant, candidate nodes, terrain, obstacles and gathering evidence. Changing these inputs invalidates reuse. Following/pausing a route still does not rerun the planner.
- A thin minimap line follows the remaining prepared travel path, including terrain detours. It updates ten times per second for movement, zoom, rotation and waypoint changes, clips to square or round minimaps, and hides when no matching active route is available. Cyan denotes learned segments; purple denotes estimates. Settings → Thin minimap route line toggles it.
- Uses Forever's `C_Minimap.GetViewRadius`; if the client cannot provide a readable map scale/position, the line is hidden rather than drawn at a guessed scale. A bounded texture fallback handles clients with unsupported Line methods.

Validation: 51 Lua 5.1/LuaJIT tests passed, covering cache invalidation/copy isolation, queued cancellation, the time limit, clock/progress reporting, minimap clipping, rotation, zoom and fallback rendering. A local imported-zone Start Here benchmark decreased from 0.179 to about 0.027 CPU seconds for 35 stops (roughly 6x); in-game timings vary. Live Forever rendering still needs an in-game check.

### 0.2.2-alpha: numbered stops and reload persistence

- Small numbered minimap dots mark actual gathering stops in route order; terrain detours are not numbered. The next stop is highlighted, and completed/offscreen stops are hidden.
- Active navigation is saved per character on logout or `/reload`, including the route, waypoint, terrain-path position and pause state. Login restores it without running the planner. Stopping/completing a route clears its saved navigation at logout. Named saved routes remain separate.
- Restoration checks route geometry and bounds, rejects malformed snapshots and resets invalid indices.
- Validation: 54 Lua 5.1 tests pass, including route restoration, character isolation, cancellation persistence, malformed saved data, numbered stops and hiding completed markers.

### 0.2.3-alpha

- Closest/Nearest loops rotate the stop order so the nearest reachable gathering stop is number 1. Circuit direction is preserved and terrain detours are rebuilt; previews and saved nearest loops recheck the entry stop when activated.
- The next leg is warm gold and brighter; later route segments are faded. Hover numbered stops to see resource, stop number and distance.
- Numbered markers are smaller (12 instead of 18 units at standard scale) with softer backgrounds.
- Route overlays follow the minimap's own UI layer. VoidMark Mini Map 0.1.9 moves the map into the background so quest objectives and normal panels can appear above it.
- Validation: 55 Lua 5.1 tests pass, including nearest-stop rotation, preserved circuit order, rebuilt detours and waypoint tooltip contents.

### 0.2.4-alpha

- Optimal loops now also renumber the nearest reachable gathering stop as waypoint 1, keeping circuit direction. Preview activation and loading a saved Optimal route recheck your current position.
- Cached Optimal loops are reused, then renumbered for the current player position. Reload restoration continues to preserve in-progress navigation rather than restarting it. Start Here retains its existing player-origin behavior.
- Kept zone-ranking timeout results separate from single-route results.
- Validation: 56 Lua 5.1 tests pass, including Optimal route rotation after movement and cache reuse.

### 0.2.5-alpha: purple navigation HUD

- Restyled the live waypoint display to match the supplied reference: violet compass arrow, Route title with a diamond rule, an ornate two-tier panel, progress bar, stop count, yards, estimated seconds and a next-stop button.
- Artwork is transparent RGBA TGA at power-of-two sizes for the game client. The compass rotates around its medallion pivot; labels and progress remain live UI elements.
- Keeps smooth heading updates, left-drag movement and the existing right-click Skip/Restart/Pause/Cancel menu. Pause and wrong-zone states clear unavailable distance/ETA instead of leaving stale values.
- Validation: 57 Lua 5.1 tests pass, including live HUD values, progress, direction, next-stop action, pause and wrong-zone states. Alpha and runtime texture dimensions checked. In-game visual verification remains needed.

### 0.2.6-alpha

Removed the Route title and decorative line above the compass arrow. Live guidance and the lower progress panel remain.

### 0.2.7-alpha

Removed the navigation HUD hover-help tooltip. Dragging and the right-click action menu still work.

### 0.2.8-alpha

Resize the entire navigation HUD through its right-click menu: Smaller display, Larger display, or Reset display size. Nexus Settings also has Navigation display scale (0.5-2.0); `/vmn arrowscale 0.8` sets an exact size. This saved setting scales the arrow, panel, text, progress and button together. The navigation hover-help tooltip is removed.

### 0.2.9-alpha

The complete navigation HUD now uses the LOW UI layer, so the world map and normal application windows cover its arrow, panel, labels and controls. Showing or resizing it preserves this layer.

### 0.2.10-alpha

Replaced the three navigation sizing menu entries with one Display row containing minus and plus buttons. Repeated clicks resize the entire HUD without closing the menu; limits remain 50%-200%.

### 0.2.11-alpha

The navigation HUD now saves its screen anchor after dragging and restores it when recreated after login or `/reload`, applying its saved scale first. Repeated route activation does not reset placement. Invalid saved anchors fall back to the default, and the display stays clamped to screen.

### 0.3.0-beta

- Retain up to 12 compatible completed route results for seven days across normal reloads/logins. Share bounded directed travel-leg results across candidate starts and sessions. Cosmetic settings and harvest timestamps no longer discard geometry; current evidence is rescored.
- Preserve time-cap results, and add explicit improvement seeded with the compatible saved circuit. New Optimal/Nearest runs number the closest stop as 1; active-run restoration retains progress.
- Add per-character saved recording drafts, exact-path playback, validated preview/confirm route exports/imports, deletion confirmation and saved-session comparisons. Current gathering totals resume after logout/reload with offline time excluded.
- Fix observed-only cross-zone ranking and keep generated-loop comparison identities stable when the start rotates.
- Add optional Shortest Path Forever travel handoff via its public API. It is never required for Nexus planning.
- Add Lua 5.1 CI and a reproducible source-verified installable ZIP. A collision mesh is outside this release. (Profession-target planning was added in 0.4.0.)

0.3.1 hardening: see https://github.com/travisejones28-alt/VoidMark-Nexus/blob/main/HARDENING.md .

### Gathering skill-up routes (0.4.4)

In Routes, open the resource filter and select Herbalism skill-ups, Mining skill-ups, or Both gathering skill-ups. Generate/Preview uses the current character's recorded gathering skills and rank caps. Top 5 zones compares eligible skill-up nodes across zones. You can also use `/vmn skillroute herb`, `/vmn skillroute ore`, or `/vmn skillroute all`.

Orange nodes receive the highest planning priority, then yellow, then green. Locked nodes and estimated gray nodes are excluded. Difficulty bands use the same requirement-relative estimates as the companion minimap legend; Forever thresholds can differ. Priority/hour is a weighted planning score, not promised skill gains. Zone travel and combat danger are excluded from zone comparisons. Regenerate after gaining skill or training a new rank. Choosing a normal gathering filter exits skill-up mode. Map display filters remain independent.
