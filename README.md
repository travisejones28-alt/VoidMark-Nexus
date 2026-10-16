# VoidMark Nexus 0.2.0 alpha

Terrain routing v5 adds learned directional trails, shared detour geometry, incremental planning, explicit gathering evidence and route performance. See [DEVELOPMENT_V5.md](DEVELOPMENT_V5.md) for current features, limits, 47-test validation and in-game steps. The older feature notes below describe the original baseline where they conflict with that update.

Standalone profession, offline-alt, inventory, crafting and gathering workspace for Forever interface **16001**. This is an initial testable implementation, not a claim that the entire requested product is complete. No actual game-client testing was performed during development.

## Install

Copy **VoidMarkNexus** (the folder containing `VoidMarkNexus.toc`) into `World of Warcraft/_classic_beta_/Interface/AddOns/`. Enable it and use `/vmn`. Log into each character, open every profession, and visit the bank to populate records. Keybinding: Open VoidMark Nexus. The minimap gem opens the window; right-click opens Settings.

## Windows GitHub Desktop junction installation

The GitHub repository root contains a nested **VoidMarkNexus** directory. **Point the WoW junction at this inner directory**, not the repository root. The inner directory contains `VoidMarkNexus.toc`.

If you cloned the repo to `C:\WoW Forever Addons\VoidMark  Nexus` (two spaces), run `Install-WoWLinks.ps1` from that root in PowerShell as Administrator. It installs or repairs junctions for both `_classic_beta_` and `_forever_`. It never deletes a regular addon directory. Existing junctions are updated without touching the repository's addon files.

Alternatively, install the distributable `dist/VoidMarkNexus.zip` directly. It already has the correct top-level `VoidMarkNexus/` folder. **Do not extract the whole repository ZIP into AddOns.**

## Implemented

- Shared account database; character-specific recipes and timestamped bag/bank snapshots. Optional imported-character inventory, exclusions, and stale-data controls. Cross-realm and cross-faction inventories are excluded from calculations. Binding and mail restrictions must be checked in game.
- Modern schematic API with legacy trade skill and craft fallbacks; offline and account-wide recipe search, known/unknown/wishlist filters, price and margin sorting, recipe details, source text where provided by the client. Linked/guild/NPC professions do not overwrite your character.
- Manual two-account export/import with bounded non-executable serialization, validation, preview, explicit confirmation, duplicate-identity and stale-record protection. Imports never overwrite local characters. Uncompressed exports are limited to 2 MB.
- Craft queues with shared stock allocation, shopping lists and per-source transfer instructions. Offline crafts remain plans; current-character crafting requires the open profession and a user click. Enchantments with no output item have no assumed sale value.
- Buy-all costs, buy-missing cash, owned-material value, economic profit, net sale-of-reagents comparison, variable output range, configurable fees, deposit cash/loss, sold fraction and waste assumptions. Unknown prices invalidate totals rather than becoming free materials. Conservative minimum recipe output is used for profit.
- Read-only VoidMark Market schema-1 integration, realm/faction scoped; optional Auctionator lookup, timestamp-preserving Nexus cache, manual prices. Manual-first is configurable. Market is optional. Market navigation filters its existing opportunities view; it does not purchase materials or inject an order.
- VoidMark gathering database and resource definitions, with deduplicated observed nodes, herb/ore and name filters, world-map pins, recorded gathering loot statistics and bounded session history.
- Foot, 60% mount, 100% mount, Travel Form and custom route assumptions. Bounded nearest-neighbor plus 2-opt route improvement, time budget, save/load, manual waypoint creation, numbered map pins and independent purple arrow. No TomTom dependency or copied TomTom art.
- Short-horizon leveling ranking by purchase cost or fewest missing materials, using explicit approximate difficulty probabilities. Rescan after each skill gain.
- Ten-page dark interface, item tooltips, character/profession dropdowns, search, paging, movable window, saved position, scale, settings and diagnostics.

## Commands

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

Settings contain speed, time budget, remount and gathering delays. Selecting a travel preset resets speed and delay to its assumptions. Custom settings can be edited afterward. Route distance is straight-line; there is no navigation mesh. Changing speed can change how many nodes fit the budget, but does not manufacture terrain-dependent paths. Routes do not know live spawns or unseen player competition. Map rendering caps potential-node pins at 250; routes cap at 150 waypoints and improve only a nearby candidate subset.

## Incomplete / needs follow-up

- Full native-window replacement is deliberately not claimed. Selecting Nexus opens its browser while preserving Blizzard's data source and crafting access. No suppression of protected native UI.
- No bundled complete Forever recipe/source catalog. The browser records the catalog exposed by an opened profession; legacy APIs expose learned recipes only. Specialization and prerequisite modeling, full leveling threshold tables and full trainer shopping are not implemented.
- No terrain/road/water navigation, congestion model, minimap node overlays, route lines, market-weighted routing or learned route performance optimization yet. Navigation is direct waypoint guidance. Custom route editing is add/save/load only.
- No compressed/chunked transfer, arbitrary source-addon SavedVariables migration, guild/reagent/account bank support, per-item binding-aware transfers, or deeply integrated Market shopping orders yet.
- Alternative reagent slots are marked incomplete rather than guessing. Uncached modern item binding metadata and unexposed profession cooldowns need in-game review.
- UI is fixed-size with adjustable scale. Import preview is displayed in the transfer window before confirmation. Full visual QA in the game, localization, secret-value coverage and every Forever-specific profession require client testing.
- Gather tracking uses confirmed known gathering spells and matching node names; unknown/localized resources and rank-specific spells may need extensions. Recorded loot includes byproducts. No claim of complete fishing/skinning support.

## Validation

Run `lua Tests/run.lua` from the repository root using Lua 5.1, or `pwsh -File Tests/Run.ps1 -LuaDll PATH` with a Lua 5.1 compatible DLL on Windows. Tests cover pure logic, mock API scanning, persistence, imports, inventory allocation, prices, routes and UI construction. See `VALIDATION.md` for actual results and in-game checks. Keep a copy of `WTF/Account/.../SavedVariables/VoidMarkNexus.lua` before testing upgrades.

## Integration contract v1

Nexus reads `VoidMarkMarketDB.schemaVersion == 1`, `economies[normalizedRealm .. '|' .. faction].market[itemID]`, unsuffixed records only, `fairValue`/`latest.median`, and `lastSeen`/`latest.at`. It does not mutate Market records or infer ages for missing timestamps. Unknown schemas fail closed. `VoidMarkNexus.integrationVersion == 1`; `:Price(itemID)` returns `unit`, `source`, `at`, `stale`, optional `confidence`. `:Shopping()` returns per-plan materials with allocations and missing quantities. This is a Nexus API, not an undocumented promise that Market implements a new API. Market source remains unchanged.

## Licensing

VoidMark Nexus implementation: see LICENSE. The bundled gathering dataset and resource definitions retain the source notice in `VoidMarkNexus/Licenses/GatherLite.txt`. See `SOURCE_REVIEW.md` for reference decisions. VoidMark's interface and routing remain standalone; no third-party addon is required.

