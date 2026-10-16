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

