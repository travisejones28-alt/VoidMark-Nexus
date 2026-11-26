# VoidMark Nexus

## Disenchant value (WoW Forever)

Shift-click an item into `/vmn de ITEM_LINK`, or use `/vmn de ITEM_ID`. Nexus shows expected dust/essence/shard yields, after-fee material value, vendor value, and estimated after-fee auction value using VoidMark Market's own realm/faction prices. Item tooltips show a short comparison by default; `/vmn de off` hides it (`/vmn de on` restores it; also in Settings). **When VoidMark Market is installed, Nexus adds no disenchant lines to tooltips** — Market's tooltip (hold Shift) is the one to use, since it prices the exact gear variant, includes Forever's weapon-essence change and learns from your own disenchants.

**Accuracy boundaries:** the built-in probabilities are independently authored Classic-based estimates mapped to Forever item levels (NOT required equip levels), *not* verified Forever drop rates. Greens and blues above item level 65, and epics above 92, are deliberately **not** projected into expansion tables. Unsupported items and unknown material prices produce **unknown**, not zero. Epic items level 61–92 require an external detailed distribution. The optional DisenchantBuddy API v1 may supply supported results; its outputs are validated and expansion materials rejected. No DisenchantBuddy code or tables are bundled. A best-option recommendation only appears with complete, non-stale prices, and is an expected-value estimate, not a guaranteed result or a verified disenchant-eligibility test. Baseline reference: https://legacyofwarcraft.com/db/forever/professions/disenchanting.html.

 0.13.8 beta

Gathering routes, profession leveling and your items across both accounts, for WoW Forever (interface **16001**).

## What it does

**Gather.** Pick Herbs, Ore, one specific herb or ore, or *Herbalism / Mining skill-ups*, then press **Start route**. Nexus draws one smooth loop through the zone right away: spawns close together become one stop, lonely outliers are dropped, and the stops are ordered so the path never crosses itself. The arrow takes you stop to stop and moves on by itself when you get close or gather a node. The loop keeps going lap after lap. **Best zones** lists the zones with the most matching spawns for you.

**Professions.** Pick a profession (any of your characters). *Level up* shows the cheapest (or fastest) steps to your target skill, what to buy, and which recipes to train. *Profit* lists every recipe you know with its profit, most profitable first; hover for materials and prices. *To learn* lists the recipes you have not learned and where to get them (also the *MR* button on the game's profession window, or `/vmn missing`). Hover any of these buttons for what it does.

**Characters.** Your characters with how fresh their bag and bank data is. Pair with the bank character on the other account to sync live while both are online. Item tooltips show how many of that item each character holds.

**Gold.** Every character's gold is saved when you log in and whenever it changes, and the bank character's gold syncs over with its bags. The Characters page shows each character's gold and the total; `/vmn gold` prints it in chat.

**Find item.** Type in the box at the top of the window (part of a name, an item ID, or shift-click an item into it). Nexus lists every character holding it, split into bags and bank, with how old that information is. `/vmn find NAME` gives the same answer in chat.

**Settings.** A short list of checkboxes, the route lap length, and the window size.

## What changed in 0.14.8

- **960 more mining spots, from Wowhead's WoW Forever map data.** Every Forever mineral vein (46 node types, about 12,400 spots) was checked against Nexus; spots Nexus didn't have are added. Biggest gaps filled: Mount Hyjal (Rich Thorium), Riverglades (Iron, Tin, Gold, Mithril, Truesilver), Zephras Isle and Redridge (Copper, Tin), Shen'dralas, and Silver/Gold across Desolace, Thousand Needles, Ashenvale and Stranglethorn.
- **New Forever ores:** Heavy Thorium Vein (skill 300, Mount Hyjal) and Chunk of Amber / Large Chunk of Amber (skill 1, Teldrassil; they give Copper Ore).

## What changed in 0.14.7

- **Route arrow always shows when a route starts.** If "Show routes" had been unticked (world map checkbox), starting a route left the arrow hidden with no message. Starting a route now turns it back on and says so.
- **Arrow keeps pointing in caves, towns and sub-zones.** When the game put you on a smaller map than the route's zone, the arrow hid itself and said "Go to <zone>". It now reads your spot on the route's zone map.
- **Arrow can't get lost off screen.** A saved arrow spot that is off the current screen (smaller window or resolution) resets to the top-centre default. The arrow also draws on the same layer as normal windows, so UI-panel addons can't cover it.

## What changed in 0.14.6

- **Guides track your progress live.** The step you're on shows a progress line: `Skill 24 / 30  [==========----------]  made 12 - about 7 to go`. Crafts you make are counted per recipe; after 3 crafts the "to go" number uses your own skill-ups per craft instead of the guide's estimate. Updates as you craft.
- **Opens on the character you're on.** A profession guide now shows the logged-in character's progress automatically when they have that profession. Pick "Whole guide" to read the full guide instead (remembered).

## What changed in 0.14.5
- Routes: the current gathering stop is now also WoW's own waypoint (map pin, tracked), so the game's on-screen navigation marker (`/console showInGameNavigation 1`) points at it and moves with the route. A pin you set yourself is never cleared by Nexus.

## What changed in 0.14.4
- Gather: 141 herb stops that were missing from Nexus's spawn list were added across 25 herbs, e.g. Black Lotus at The Maul in Feralas (Dire Maul arena), Plaguewood and Browman Mill, and 33 Dreamfoil stops. Positions come from WarcraftMaps (warcraftmaps.com/gold/herb-spots); they are Classic spawn positions, not yet checked in Forever. A stop is only added where Nexus had no spawn within about 60-70 yards.

## What changed in 0.14.3
- Crates: the crate's own AH price is always part of the cost, even for crates you already hold (you could sell them instead). The hover box still shows the materials-only cost.

## What changed in 0.14.2
- Crates tab easier to read: each crate is a short headline (name and cost per favor) with the bundle, favor and cost on the line below; real item names instead of "Item 8172"; money without zero parts ("20s 96c", "2c").

## What changed in 0.14.1
- Crates: costs now subtract the silver each sealed crate pays back (50c per favor). Expert favor is marked player-reported and Artisan expected; Apprentice and Journeyman are confirmed.
- Crates: **Show rewards** lists what favor buys, priced in gold at your cheapest crate: the Pack Kodo, Minimule pet, Advertising License, tabard, certifications, Forged Delivery Receipts, and every favor recipe for your professions that you don't know yet (favor price from the vendors' skill bands, Wowhead).
- A reminder line shows the cheapest empty crate for Forged Delivery Receipts (+50 reputation each).

## What changed in 0.14.0
- New **Crates** tab: every Waylaid Crate ranked by the cheapest Merchant's Favor from your latest AH scan. Each row says what the crate **takes** (its cheapest bundle), what it **costs** (bundle + the crate's AH price, or nothing extra if you already hold one), what it **gives** (favor) and the cost per favor. Hover a row for every bundle, its price, and how many you already have.
- Favor per crate (player reports): gathered goods 5/10/15/20, crafted goods 10/20/30/40 for Apprentice/Journeyman/Expert/Artisan; Artisan amounts are expected, not confirmed.

## What changed in 0.13.8

- Fewer, bigger stops: spawns within 60 yd now group into one stop (was 35), so tight clusters like 8-14 become one point. The minimap ring is sized to cover the group, and the route waits while you pick around inside it. Settings > "Group spawns within (yards)" changes it (30-120). Press Rebuild / Start route again to regroup an existing route.

## What changed in 0.13.7

- Minimap route is decluttered: only the current stop and the next 3 are drawn (rings, numbers and the line between them). Settings > "Minimap: stops shown ahead" changes it (1-10).

## What changed in 0.13.6

- Detours are safe: running off to grab a node at a far stop (e.g. 50 while the route is on 24) leaves the route where it was. That stop is marked picked for this lap and passed over automatically when the route gets to it. Only the next 4 stops can pull the route forward.

## What changed in 0.13.5

- Route summary: Stop route opens a summary of everything you gathered on the route, each with its approximate AH value, the total and gold per hour. `/vmn haul` shows it mid-route (or the last one). The tally survives /reload; rebuilding the route keeps it.
- Zone loops catch up: reaching the current stop or any of the next 4 stops (within 25 yd, by any path) moves the route on, so walking past stop 4 to stop 5 no longer leaves the arrow stuck on 4.

## What changed in 0.13.4

- Gather page: "Best zones for ..." lists up to 10 zones for what you picked, best first, with a per-herb count when several are ticked. Click a zone to build routes there.
- Route options window: rows sit below the explanation text and stay one line (notes like price estimates move to the hover tooltip); the window grows to fit, so text no longer overlaps.

## What changed in 0.13.3

- Gather resource menu: **Pick herbs / ore (toggle)...** opens a checklist of every herb and ore in the game. Click rows to tick/untick; the list stays open. Done closes, Clear all unticks.
- Replaces One herb / One ore. If none of the ticked ones are in the route zone, the Zone moves to where they grow most.

## What changed in 0.13.2

- Gather resource menu: "Pick several herbs / ore" removed. New **One herb...** and **One ore...** list every herb and ore in the game (sorted by skill, "- here" marks ones in the route zone), not just the current zone.
- Picking one that isn't in the route zone moves the Zone to where it grows most (Zone button still overrides).

## What changed in 0.13.1
- Profession window button is now a small **MR** at the far right, so it no longer covers the skill bar.
- The profession picker reads "Cooking 300/300 - Soulreaver" and is cut short instead of running into *Level up*.
- *Recipes* is now **Profit** and *Missing* is now **To learn**; hover any of these buttons for what it does.

## What changed in 0.13.0
- **Recipe database built in.** Missing recipes now uses Nexus's own Forever recipe catalog first and a Classic baseline second. No other recipe addon is needed or read.
- **Click a recipe to pick a source.** Each trainer, vendor, drop, quest or object is listed on its own; pick one to set a waypoint. Outdoor zones and capitals have map positions; dungeon and raid sources are listed without one.
- **Sources dropdown** on the Missing view: All, Trainers, Vendors, Drops, Quests, Objects or Other. It is remembered.
- **Recipe sources sync between accounts.** Recipe loot, quest rewards and recipe vendors you record are shared with your paired character automatically while both are online. Manual: Characters > Export > *Recipe sources*, or `/vmn exportrecipes` / `/vmn importrecipes`. Your own records are never removed; a place is only replaced by a newer sighting.
- Lighter: each profession's data is unpacked only when you view it (at most three kept), the Missing list is rebuilt only when something changes, and the sync data is re-encoded only after new sightings.

## What changed in 0.12.0
- **Missing recipes**: Professions > *Missing*, the *Missing recipes* button on the profession window, or `/vmn missing [profession]`. Lists what you have not learned, green when your skill is high enough, with where to get it. Hover for every source; click a row with a recorded position to set a TomTom waypoint (or the game's map pin).
- Sources, best first: what you have seen in game (trainers, recipe vendors, and now recipe items you loot or are offered as quest rewards, with position); the game's own unlearned list and source text; RecipeRadar's database when that addon is installed (read only, never copied); otherwise shipped Classic data (787 recipe items, MIT data from wow-classic-items). Forever can differ from Classic data, so those lines say so.
- Recipes whose only known seller is the other faction stay listed, greyed, at the bottom (the Classic data names one seller per recipe).

## What changed in 0.11.1
- **Help & commands** window: Settings > Help & commands (or `/vmn help`). A short FAQ and every `/vmn` command, with a search box. A test fails if a command is added without a help line.

## What changed in 0.11.0
- **Terrain-aware loops.** When you have walked a zone (trail learning is on again; saved trails were kept) or marked obstacles (`/vmn block 90`), the loop is ordered by those trails: a corridor you walked replaces the straight line when it is not much longer (1.5x after one walk, 2.5x when walked repeatedly), and a marked obstacle is always walked around. The arrow follows the trail points of the leg you are on; the world map, minimap and preview draw walked legs **cyan** (verified) and everything else **purple** (estimated). Map artwork is never treated as collision. `/vmn terrain on|off|use|ignore|clear`.
- **Every route learns separately.** Each distinct loop (same stops, any start or direction) records laps, stops visited, found and empty, items and quantities, skill gained, gathering versus travel time, nodes/hr and gold/hr, including the part of a lap you stopped after a minute. Options are ranked by an estimate pulled toward your real results (worth 3 laps against them), with a confidence label. `/vmn routes` compares your routes; `/vmn runroute N` runs one again; `/vmn routereset N|current|zone|all` clears learned performance without touching sessions, spots or other zones.
- **Gold per hour from VoidMark Market.** Routes show estimated gold/hr (your loot on that loop, or before you run it, prices x your observed yield per node, at least 1). Missing prices make figures partial and are never counted as zero; stale, unverified and developing Market prices are flagged (Market's read-only `GetPriceInfo` status is used when present). Gold routes rank by gold/hr. `/vmn compare` (herbs vs ore here), `/vmn prices`, `/vmn market ITEM` (opens Market's search; nothing is bought, posted or cancelled). Shift-click a stop to open its resource in Market.
- **Leveling while you play.** The step for your current skill is highlighted with crafts left and how many your bags allow; materials show who holds them; the four methods are compared side by side (click to switch); a shopping list says what to buy and what to collect from each character. `/vmn level PROFESSION [target]`, `/vmn levelshop`, `/vmn transfers` (for queued crafts).
- **Skinning and fishing.** Learned from what you do: where you skinned (beast, level, leather), where you fished and caught, and fishing pools (from the loot source, or `/vmn pool NAME`). Sessions show skins or catches per hour, items/hr, gold/hr and skill gained. Guides gets a Skinning page (beast level you can skin, Classic level-range zones, your spots, leather held); the Fishing guide adds your data. `/vmn poolroute` loops through a zone's pools; pools show on the world map. Spots are where beasts or pools were, not guarantees.
- **Window.** Drag the bottom-right corner to resize; size and position are kept (`/vmn resetwindow`). Pick several herbs/ore one by one, and hide grey resources (no skill-ups) from routes and the map (`/vmn grey`, or the map filter menu).
- **Sync.** Newer data always wins: an older bag, bank, mail, gold or profession snapshot can no longer overwrite a newer one. `/vmn sync` shows the last successful sync, when the other character was last heard from, whether it looks offline or is not answering, stale inventory, waiting messages and refused older snapshots.
- **Dashboard and notices.** `/vmn dash` opens a small farming dashboard (session time, items, skill gained, value, nodes/hr, gold/hr, route expected vs this lap, last 10 sessions). One chat line when a profession nears or reaches its rank cap, and once per route when stops need more skill than you have (`/vmn notify off`).

## What changed in 0.10.31
- **Fishing guide expanded** (Guides > Fishing 1-300): zones by fishing skill (minimum / 100% catch), poles, lures and gear with their bonuses and how many you hold, rare fish and the pools they come from, and Forever extras (Find Fish, camp items, Fishing Extravaganza). Pick a character and each zone tier shows *100% catch*, *some get away* or the skill you still need.

## What changed in 0.10.1
- **Zone button** on Gather (replaces Best zones): *Current zone* follows you, or pick any zone with matching spots (best first) and Start route / `/vmn route now` build the loop there. The arrow says which zone to go to.

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
| `/vmn routes [zone]`, `/vmn runroute N`, `/vmn routereset N\|current\|zone\|all` | Compare, rerun and reset learned routes |
| `/vmn compare`, `/vmn prices`, `/vmn market ITEM` | Herbs vs ore gold/hr, resource prices, open in Market |
| `/vmn terrain on\|off\|use\|ignore\|clear`, `/vmn block [yards]`, `/vmn clearblocks` | Learned trails and obstacle marks |
| `/vmn level PROFESSION [target]`, `/vmn levelshop`, `/vmn transfers` | Leveling step, shopping list, what to mail |
| `/vmn missing [profession]` | Recipes you have not learned and where to get them |
| `/vmn exportrecipes`, `/vmn importrecipes` | Copy or paste recorded recipe sources between accounts |
| `/vmn skinning`, `/vmn fishing`, `/vmn pool NAME`, `/vmn poolroute`, `/vmn pools on\|off` | Skinning and fishing |
| `/vmn dash`, `/vmn notify on\|off`, `/vmn grey`, `/vmn resetwindow` | Dashboard, notices, grey filter, window |
| `/vmn help [word]`, `/vmn debug` | Help & commands window (FAQ, search), diagnostics |

## Install

Install the repository root as **VoidMarkNexus** (it directly contains `VoidMarkNexus.toc`). The AddOns folder name must match the TOC name exactly: a junction named `VoidMark-Nexus` will not load. Use `Install-WoWLinks.ps1`, or `mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\VoidMarkNexus" "C:\WoW Forever Addons\VoidMark-Nexus"`. Enable it and use `/vmn`. Log into each character, open every profession, and visit the bank to populate records. Keybinding: Open VoidMark Nexus. The minimap gem opens the window; right-click opens Settings.

## Integration contract v1

Nexus reads `VoidMarkMarketDB.schemaVersion == 1`, `economies[normalizedRealm .. '|' .. faction].market[itemID]`, unsuffixed records only, `fairValue`/`latest.median`, and `lastSeen`/`latest.at`. It does not mutate Market records or infer ages for missing timestamps. Unknown schemas fail closed. `VoidMarkNexus.integrationVersion == 1`; `:Price(itemID)` returns `unit`, `source`, `at`, `stale`, optional `confidence`. `:Shopping()` returns per-plan materials with allocations and missing quantities. This is a Nexus API, not an undocumented promise that Market implements a new API. Market source remains unchanged.

0.11: when Market is loaded and exposes `VoidMarkMarket:GetPriceInfo(itemID)` with `apiVersion == 1` (Market 1.23+), Nexus reads its `status` and marks the price stale when it is not `current`; `cacheUntrusted`/`analysisIncomplete` mark it stale and `developingMarket` is shown. The price value itself still comes from the record above. `VoidMarkNexus.API` (version 1) gives other addons read-only copies: `GetSessionStats()`, `GetGatheringSkills()`, `GetBestRoutes(limit)`.

## Licensing

Original Nexus implementation: MIT, see LICENSE. GatherLite node definitions and data: Copyright (c) 2019 Wuild, MIT; full license in `VoidMarkNexus/Licenses/GatherLite.txt`. See `SOURCE_REVIEW.md` for reference decisions. Recipe sources in `Data/RecipeSources.lua`: generated from wow-classic-items, Copyright (c) 2019 Nakroma, MIT; license in `VoidMarkNexus/Licenses/wow-classic-items.txt` (`tools/bake_recipes.py` rebuilds it). The bundled recipe catalogs (`Data/ForeverRecipeCatalog.lua`, `Data/BaseRecipeCatalog.lua`) are included with permission; Nexus does not load or read any other recipe addon. Other reference addons and TomTom artwork are not redistributed.

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
