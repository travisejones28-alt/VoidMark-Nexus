# Source and compatibility review

All ten ZIPs were extracted locally. The duplicate Ultimate Gathering Counter archives have identical SHA-256 `73cc43428dcbc5e3cd63a92702436c734a3a131998da78818eeeead1c81b7385`. Archive manifests, Lua/API/event signatures, TOCs and available licenses were inventoried. Detailed review focused on profession adapters, inventory snapshots, price calculations, gather detection, route calculations and navigation. This is not a claim of in-game validation of these reference addons.

| Source | Useful systems / inspected assumptions | Nexus decision |
|---|---|---|
| CraftProfit 0.4.0 | MIT, Vystery 2026. Modern schematic cache, required basic reagent slots, output ranges, price source hierarchy, linked/guild/NPC guards, craft dependency depth guard. `CP.db.recipeCache` and learned-character maps. | Independent implementation; no code copied. Preserve unknown cost rather than zero. No automatic legacy migration. |
| CraftProfit 1.1.0 | Separate pure calculation, history, modern/legacy adapters, price queue and leveling modules. Bind-on-acquire output handling. Difficulty enum documented as 0–3, not 1–4. No top-level license found in this ZIP. | Reference only. No source/data copied. Difficulty mapping corrected in review; probabilities remain explicit estimates. |
| ForeverProfessionMaster 1.6.2 Fixed | MIT. Interface 16001; GetProfessions holes, modern base profession/schematic/source APIs and legacy fallback. Broad recipe UI, queue and guide data. | Independent adapter implementation with incremental modern scans; no guide data copied. Native data source stays alive. |
| GatherLite 8.1.17 | Interface 16001; object-ID keyed Forever coordinate lists; resource definitions and aliases; cast GUID matching; quantized duplicate checks; HBD world/minimap coordinates; route planner and many UI/event systems. | Reuse only potential spawn data and herb/ore definitions; retain provenance and the license notice supplied with the earlier reference archive. A separate 8.1.17 archive lacks the root license file, which alone does not establish changed permissions. Build own bounded discovery, map pins and navigation. Do not embed its entire framework, UI or recurring tracking changes. |
| GatherMate2 Data 2026-08-19 | Expansion-separated global herb/mining tables; depends on GatherMate2 and AceAddon import system. Era locations cannot be assumed identical to Forever. No bundled clear top-level grant located. | Not redistributed. Prefer the supplied Forever-specific MIT dataset. |
| FarmLedger 1.00 | Session ledger, per-zone route recordings, run history, nearest-neighbor/2-opt, cached pricing. `FarmLedgerDB`. Squared-distance 2-opt comparisons do not generally equal true-distance route improvements. No top-level license found. | Reference only; independent implementation uses actual Euclidean lengths for 2-opt. No code copied. |
| The Forever Panel 1.3.1 | Interface 16001; modern container tables with legacy tuple fallback, separate bags/banks and character caches; numerous unrelated transport/panel modules. `TheForeverPanelDB`. No top-level license found. | Reference only. Independent bag/bank scanner; exclude unrelated systems and uncertain data migrations. |
| Ultimate Gathering Counter 1.3.4 (both ZIPs) | Multi-client TOCs including 16001, `UGC_DB`, bag gain confirmation, categories, price adapters, capped history, many UI/OnUpdate systems. No top-level license found. | Reference only. Count confirmed matched gather-loot slots instead of arbitrary bag gains, reducing mail/trade inflation. No code copied. |
| TomTom 4.3.12 | Waypoint direction minus player facing; navigation update interval and map transforms. Classic arrow permission is non-commercial; other bundled artwork has separate terms. | No code/art bundled. Original purple arrow and independent map/facing calculations. TomTom is not required. |

## Repository inspection

Nexus main initially contained only `.gitattributes`, tree `92bc39924bd6a2206dadf6978cc52b126e85ded5`.

Market tree inspected: `7124c3f20860e42f2b6b98fad8bda01791957aed`. Reviewed Core.lua, Database.lua, MarketModel.lua, UI.lua and TOC. Economy key is normalized realm plus faction. Random suffix markets must not be substituted into commodity reagent prices. Nexus reads schema 1 only and preserves observation timestamps. Existing `SetView('opportunities')` and filter provide optional navigation, not a shopping-order API. No Market modifications.

## Reliability choices

- No automatic migration from unrelated SavedVariables. Their identity, locale and catalog differences need a separately tested converter; their data is untouched.
- Event handlers run independently behind error reporting; scans are coalesced and modern recipes process 30 per timer slice. Main UI refresh only occurs when dirty. Navigation updates at 0.15 seconds while active; map pins refresh only while the world map is shown.
- 2 MB non-executable imports, depth/token/character/recipe/reagent bounds, identity validation, imported-field sanitization and stale-record handling.
- Storage snapshots remain intact when APIs are unavailable. No bank scan while closed. Duplicate physical character inventories are excluded.
- Small module files; syntax loaded by a Lua 5.1-compatible interpreter. Tests exercise mocked event and UI behavior separately from game claims.

Actual client build/API behavior remains to be verified with `/vmn debug` and the in-game checklist. The reference TOCs consistently support 16001; no live client API probe was run.


## 0.3.0 package review and implementation boundary

Reviewed supplied Shortest Path Forever v1.19.2, Travelcraft 1.28.1, Polestar 0.2.5, SkillUp Forever v0.16.1 and FarmLedger (ZIP named v1.00; internal version 1.1.11). Useful patterns included separate graph and endpoint caches, directed observations, explicit dependency invalidation, stable persisted identifiers and recorded-loop comparisons.

This release adds original Nexus cache, recording, session and route-transfer implementations. No third-party source or artwork from those packages is bundled. Optional Shortest Path support calls its documented version-1 public navigation API after an explicit user action. Existing GatherLite data provenance remains unchanged. SkillUp profession-target integration and bundled terrain meshes are not part of this release.
