local _,N=...
N=N or VoidMarkNexus
-- Guides from wow-professions.com (Forever): gathering routes, Lockpicking,
-- Camping items (have/need) and Merchant's Favor crates (what you can fill).
-- Shown in the Guides tab. Counts and routes are the guide's; Forever
-- is new, so some may change on live.

local H,T='h','t' -- heading / text line
N.GUIDES={
 herb={name='Herbalism 1-300 route',lines={
  {H,'1-70: Peacebloom, Silverleaf, Earthroot (15)'},{T,'Durotar, Mulgore, Tirisfal Glades, Zephras Isle. Starting-zone trainers only teach to 75.'},
  {H,'50: learn Journeyman at a main trainer (Mishiki, Komin Winterhoof, Faruza)'},
  {H,'70-115: Mageroyal, Briarthorn, Stranglekelp (85)'},{T,'Silverpine Forest, Loch Modan, Darkshore.'},
  {H,'125: learn Expert'},
  {H,'115-170: Bruiseweed, Wild Steelbloom, Stranglekelp, Kingsblood (125), Liferoot (150)'},{T,'Hillsbrad Foothills (safest), or Stonetalon Mountains if over 125.'},
  {H,'170-205: Kingsblood, Liferoot, Fadeleaf, Goldthorn, Khadgar\'s Whisker (185)'},{T,'Stranglethorn Vale, Arathi Highlands.'},
  {H,'200: learn Artisan BEFORE leaving (no trainer in Tanaris or Searing Gorge)'},
  {H,'205-230: Purple Lotus, Firebloom'},{T,'Tanaris, Searing Gorge.'},
  {H,'230-270: Sungrass, Purple Lotus, Ghost Mushroom (245, cave), Golden Sansam'},{T,'The Hinterlands.'},
  {H,'270-300: Sungrass, Gromsblood, Golden Sansam, Dreamfoil, Mountain Silversage, Plaguebloom'},{T,'Felwood.'},
  {T,'Find Herbs turns off when you die. Goldthorn Tea gives +15 (Cooking 175).'}}},
 mine={name='Mining 1-300 route',lines={
  {T,'Buy a Mining Pick. Find Minerals turns off when you die. Bonuses: Enchant Gloves - Mining (+2), Goblin Mining Helmet (+5).'},
  {H,'1-65: Copper'},{T,'Durotar (cave), smelt at Razor Hill. Or Mulgore, Tirisfal, Zephras Isle.'},
  {H,'50: learn Journeyman (Makaru in Orgrimmar; junior trainers stop at 75)'},
  {H,'65-125: Copper, Tin (65), Silver (75)'},{T,'Silverpine Forest cave or Hillsbrad Foothills. Smelt Copper+Tin into Bronze first (stops giving points ~105).'},
  {H,'125: learn Expert. Iron (125), Gold (155)'},{T,'125-175: Thousand Needles at low level, Arathi Highlands when mounted. Skip the 4 Arathi caves at low level.'},
  {H,'175-245: Mithril (175), Truesilver (230)'},{T,'The Hinterlands (skip the level 62 elites route) or Tanaris (skip the caves under 60). Learn Artisan at 200.'},
  {H,'245-275: Mithril, Small Thorium (245)'},{T,'Un\'Goro Crater caves (mob-heavy; good for stealth), Blasted Lands, Felwood Jaedenar cave.'},
  {H,'275-300: Thorium, Rich Thorium (275)'},{T,'Un\'Goro Crater, Eastern Plaguelands, Burning Steppes (skip the two caves at low level).'},
  {T,'Optional fast 1-105 by smelting: buy ~140 Copper Ore and 70 Tin Ore; Copper to 65, Tin 65-75, Bronze 75-105.'}}},
 fish={name='Fishing 1-300 route',lines={
  {T,'Buy a Fishing Pole and Shiny Baubles (Orgrimmar: Shankys). Drag Fishing from the Professions window (hammer button) to your bar.'},
  {H,'1-75: any starting zone water'},{T,'Durotar, Mulgore, Tirisfal Glades, Zephras Isle.'},
  {H,'50 (level 10): learn Journeyman'},
  {H,'75-150: capital cities, The Barrens, Silverpine Forest'},{T,'Nightcrawlers help if fish escape.'},
  {H,'125 (level 20): Expert Fishing - The Bass and You'},{T,'Old Man Heming, Booty Bay (or the AH). Buy Bright Baubles from him.'},
  {H,'150-225: Dustwallow Marsh with Bright Baubles'},{T,'Or Arathi, Desolace, Stranglethorn, Swamp of Sorrows, Thousand Needles.'},
  {H,'225 (level 35): Artisan quest "Nat Pagle, Angler Extreme"'},{T,'Nat Pagle, Tidefury Cove (Dustwallow). One fish each: Feralas Ahi (Feralas), Misty Reed Mahi Mahi (Swamp of Sorrows), Sar\'theris Striker (Desolace), Savage Coast Blue Sailfin (Stranglethorn).'},
  {H,'225-300: Felwood, Feralas, The Hinterlands, Tanaris, Un\'Goro, Western Plaguelands'},{T,'Keep Bright Baubles on.'}}},
 lock={name='Lockpicking 1-300 route (Rogue)',lines={
  {T,'Max skill = 5 x your level (100 at 20, 150 at 30, 200 at 40, 250 at 50, 300 at 60). No items needed.'},
  {H,'1-100: Buccaneer\'s Strongboxes on the ship near Ratchet (Barrens)'},{T,'Fast respawn. Skip the Jewel of the Southsea chest at low level (spawns a killer mob).'},
  {H,'100-150: Waterlogged Footlockers, Zoram Strand (Ashenvale)'},
  {H,'150-200: Angor Fortress (Badlands)'},{T,'Upstairs Battered Footlockers (150), downstairs Dented Footlockers (175). Don\'t pickpocket here.'},
  {H,'200-250: The Slag Pit (Searing Gorge)'},{T,'Footlockers, and pickpocket Sturdy Junkboxes. Stay low in the pit until 225.'},
  {H,'250-300: Blackrock Depths doors (needs Shadowforge Key)'},{T,'Use Pick Lock (right-clicking uses the key). 4 locks per run, reset instances, 5 runs an hour (~20 points/hour). Pickpocket Heavy Junkboxes too.'}}},
 favor={name='Merchant\'s Favor (Durotar Supply)',lines={
  {T,'Camp: Durotar Supply and Logistics, outside the Crossroads west gate (Barrens). Turn in Sealed crates to Dokimi.'},
  {T,'Fill a Waylaid Crate with one bundle, turn in the Sealed crate for Favor. Favor buys recipes (some need camp reputation).'},
  {H,'Reputation: Craftsman\'s Writs (once per day each)'},{T,'Journeyman 75 rep, Expert 125, Artisan 200. Writs drop in the world or sell on the AH. Make or buy the item and deliver it.'},
  {T,'First crate or writ: quest for 2,000 rep and 50 Favor.'},
  {H,'After Friendly: Forged Delivery Receipt (15 Favor, Kurvelk Shadowhoof)'},{T,'Use it on the cheapest empty Waylaid Crate from the AH, turn in for 50 rep.'},
  {T,'Forger\'s Quill (15 Favor, Honored): reroll a writ.'},
  {H,'Recipes for Favor (same at both camps)'},{T,'Alchemy 45-240, Cooking 30-90, Blacksmithing 30-120, Enchanting 45-240 Favor. Crafted armor and weapons bind on pickup.'},
  {T,'See "Merchant\'s Favor: crates you can fill" for what you hold now.'}}},
}

-- Camping: every camp item with its materials (counts per item).
N.CAMP_ITEMS={
 {'Campfire kits',{{'Basic Campfire Kit (Cooking 1)',{{1,'Simple Wood'}}},{'Journeyman Campfire Kit (Cooking 90)',{{1,'Star Wood'}}},{'Expert Campfire Kit (Cooking 200)',{{1,'Thick Logs'}}}}},
 {'Herbalism',{{'Incense Candle (20)',{{1,'Peacebloom'},{1,'Silverleaf'}}},{'Greenhouse (140)',{{2,'Simple Wood'},{1,"Arthas' Tears"},{1,'Purple Lotus'}}},{'Seed Hybridizer (300)',{{4,'Mountain Silversage'},{1,'Crystal Vial'},{2,'Runecloth'}}}}},
 {'Alchemy',{{'Mana Well (20)',{{1,'Peacebloom'},{1,'Empty Vial'}}},{'Fermenter (140)',{{1,'Leaded Vial'},{1,'Kingsblood'},{1,'Swiftthistle'}}},{'Alchemy Laboratory (300)',{{1,"Lich's Index Finger"},{1,'Crystal Vial'},{2,'Dreamfoil'}}}}},
 {'Skinning',{{'Camp Chair (20)',{{3,'Light Leather'},{2,'Simple Wood'}}},{'Field Guide (140)',{{3,'Medium Leather'},{2,'Slimy Murloc Scale'},{1,'Fine Thread'}}},{"Trapper's Workbench (300)",{{2,'Simple Wood'},{4,'Heavy Leather'},{1,'Iron Bar'}}}}},
 {'Leatherworking',{{'Camp Tent (20)',{{5,'Light Leather'}}},{'Tanning Rack (125)',{{5,'Medium Leather'},{3,'Fine Thread'},{2,'Simple Wood'}}},{'Sewing Machine (300)',{{1,'Undeath Engine'},{5,'Rugged Leather'},{1,'Rune Thread'}}}}},
 {'Mining',{{'Lodestone (20)',{{1,'Rough Stone'},{1,'Copper Bar'}}},{'Rock Garden (140)',{{2,'Heavy Stone'},{1,'Iron Ore'},{1,'Silver Bar'}}},{'Molten Foundry (300)',{{5,'Thorium Bar'},{2,'Dense Stone'},{1,'Truesilver Bar'}}}}},
 {'Enchanting',{{'Enchanted Lute (20)',{{1,'Simple Wood'},{1,'Strange Dust'}}},{'Arcane Salvager (140)',{{2,'Vision Dust'},{1,'Lesser Nether Essence'}}},{'Arcane Forge (300)',{{1,"Maker's Spark"},{2,'Large Brilliant Shard'},{4,'Greater Eternal Essence'}}}}},
 {'Blacksmithing',{{'Sharpening Wheel (20)',{{1,'Rough Stone'},{1,'Copper Bar'}}},{'Anvil (140)',{{5,'Bronze Bar'},{2,'Coarse Grinding Stone'},{2,'Medium Leather'}}},{'Master Forge (300)',{{1,'Golem Heart'},{5,'Thorium Bar'},{2,'Rugged Leather'}}}}},
 {'Engineering',{{'Reagent Bot (20)',{{1,'Handful of Copper Bolts'},{1,'Copper Tube'}}},{'Repair Bot (140)',{{2,'Whirring Bronze Gizmo'},{1,'Bronze Tube'},{1,'Heavy Leather'}}},{"Anarchist's Workbench (300)",{{1,'Essence of Anarchy'},{2,'Thorium Widget'}}}}},
 {'Tailoring',{{'Faction Banner (20)',{{1,'Bolt of Linen Cloth'},{1,'Coarse Thread'}}},{'Spinning Wheel (140)',{{2,'Simple Wood'},{5,'Bolt of Silk Cloth'},{3,'Fine Thread'}}},{'Loom (300)',{{1,'Bottled Screams'},{4,'Bolt of Runecloth'},{4,'Simple Wood'}}}}},
 {'Cooking',{{"Cookie's Feast (140)",{{2,'Mystery Meat'},{1,'Heavy Kodo Meat'},{1,'Soothing Spices'}}},{'Iron Oven (300)',{{10,'Simple Flour'},{5,'Refreshing Spring Water'},{4,'Soothing Spices'}}}}},
 {'First Aid',{{'First Aid Kit (20)',{{3,'Linen Bandage'},{1,'Refreshing Spring Water'}}},{'Toxin Study (140)',{{1,'Anti-Venom'},{2,'Mageweave Bandage'},{2,'Simple Wood'}}},{"Plague Doctor's Laboratory (300)",{{2,'Simple Wood'},{2,'Strong Anti-Venom'},{5,'Heavy Runecloth Bandage'}}}}},
 {'Fishing',{{'Fish Bowl (20)',{{1,'Raw Brilliant Smallfish'},{1,'Empty Vial'}}},{'Fishing Rack (140)',{{2,'Simple Wood'},{1,'Crystal Vial'},{2,'Raw Mithril Head Trout'}}},{'Fishing Hut (300)',{{5,'Simple Wood'},{2,'Bolt of Runecloth'},{1,'Seasonal Fish Steaks'}}}}},
}

-- Merchant's Favor crates: {tier, crate, favor, {{count,item},...}} (fill with one bundle).
N.FAVOR_CRATES={
 {'Apprentice','Textiles',5,{{40,'Linen Cloth'},{20,'Light Leather'}}},{'Apprentice','Ore',5,{{20,'Copper Ore'},{20,'Tin Ore'}}},
 {'Apprentice','Herbs',5,{{20,'Peacebloom'},{20,'Silverleaf'},{10,'Earthroot'},{10,'Mageroyal'},{10,'Briarthorn'}}},
 {'Apprentice','Curiosities',5,{{20,'Strange Dust'},{4,'Greater Magic Essence'},{6,'Small Glimmering Shard'},{2,'Large Glimmering Shard'}}},
 {'Apprentice','Fabrics',10,{{2,'Cured Light Hide'},{20,'Bolt of Linen Cloth'}}},{'Apprentice','Ingots',10,{{20,'Copper Bar'},{20,'Tin Bar'},{10,'Bronze Bar'}}},
 {'Apprentice','Parts',10,{{16,'Handful of Copper Bolts'},{16,'Copper Tube'},{4,'Copper Modulator'}}},
 {'Journeyman','Textiles',10,{{40,'Wool Cloth'},{40,'Silk Cloth'},{20,'Medium Leather'}}},{'Journeyman','Ore',10,{{10,'Silver Ore'},{20,'Iron Ore'}}},
 {'Journeyman','Herbs',10,{{10,'Stranglekelp'},{10,'Bruiseweed'},{10,'Wild Steelbloom'},{10,'Grave Moss'},{10,'Kingsblood'}}},
 {'Journeyman','Curiosities',10,{{20,'Soul Dust'},{4,'Greater Astral Essence'},{6,'Small Glowing Shard'},{2,'Large Glowing Shard'}}},
 {'Journeyman','Fabrics',20,{{6,'Bolt of Woolen Cloth'},{10,'Bolt of Silk Cloth'},{2,'Cured Medium Hide'}}},{'Journeyman','Ingots',20,{{10,'Silver Bar'},{20,'Iron Bar'}}},
 {'Journeyman','Parts',20,{{8,'Bronze Tube'},{7,'Whirring Bronze Gizmo'},{4,'Bronze Framework'},{45,'Gold Power Core'}}},
 {'Expert','Textiles',15,{{40,'Mageweave Cloth'},{20,'Heavy Leather'}}},{'Expert','Ore',15,{{10,'Gold Ore'},{20,'Mithril Ore'}}},
 {'Expert','Earthly Herbs',15,{{20,'Liferoot'},{10,'Fadeleaf'},{10,'Goldthorn'},{10,"Khadgar's Whisker"}}},
 {'Expert','Flowering Herbs',15,{{10,'Wintersbite'},{10,'Firebloom'},{20,'Purple Lotus'},{10,"Arthas' Tears"}}},
 {'Expert','Curiosities',15,{{20,'Vision Dust'},{4,'Greater Mystic Essence'},{6,'Small Radiant Shard'},{2,'Large Radiant Shard'}}},
 {'Expert','Fabrics',30,{{8,'Bolt of Mageweave'},{2,'Cured Heavy Hide'}}},{'Expert','Ingots',30,{{20,'Mithril Bar'},{15,'Steel Bar'},{10,'Gold Bar'}}},
 {'Expert','Parts',30,{{8,'Iron Strut'},{5,'Mithril Tube'},{12,'Unstable Trigger'},{5,'Mithril Casing'}}},
 {'Artisan','Textiles',nil,{{40,'Runecloth'},{20,'Thick Leather'},{20,'Rugged Leather'}}},{'Artisan','Ore',nil,{{10,'Truesilver Ore'},{20,'Thorium Ore'},{20,'Dark Iron Ore'}}},
 {'Artisan','Earthly Herbs',nil,{{10,'Golden Sansam'},{20,'Sungrass'},{10,'Blindweed'},{10,'Ghost Mushroom'},{10,'Gromsblood'}}},
 {'Artisan','Flowering Herbs',nil,{{20,'Dreamfoil'},{20,'Mountain Silversage'},{20,'Plaguebloom'},{20,'Icecap'}}},
 {'Artisan','Curiosities',nil,{{20,'Dream Dust'},{4,'Greater Nether Essence'},{6,'Small Brilliant Shard'},{2,'Large Brilliant Shard'}}},
 {'Artisan','Fabrics',nil,{{8,'Bolt of Runecloth'},{2,'Cured Thick Hide'}}},{'Artisan','Ingots',nil,{{2,'Dark Iron Bar'},{10,'Truesilver Bar'},{20,'Thorium Bar'}}},
 {'Artisan','Parts',nil,{{5,'Thorium Widget'},{5,'Truesilver Transformer'},{2,'Thorium Tube'}}},
}

-- Rows for the Reports window.
function N:GuideRows(key)
 local accent,muted,green={.78,.6,1},{.65,.6,.72},{.4,1,.4}
 local rows={}
 if key=='camp' then
  local ready=0
  for _,group in ipairs(self.CAMP_ITEMS) do
   rows[#rows+1]={text=group[1],color=accent}
   for _,it in ipairs(group[2]) do
    local parts,ok={},true
    for _,m in ipairs(it[2]) do
     local have=self:HaveCount(m[2])
     if have<m[1] then ok=false end
     parts[#parts+1]=('%s %d/%d'):format(m[2],math.min(have,m[1]),m[1])
    end
    if ok then ready=ready+1 end
    rows[#rows+1]={text='     '..it[1]..': '..table.concat(parts,', ')..(ok and '  |cff40ff40can make|r' or ''),itemName=it[2][1][2]}
   end
  end
  return rows,('Camping: camp items by profession and what you hold for each (%d you can make now).\nYou need the profession skill and, for tiers 2-3, the Blueprint.'):format(ready),
   'Each player places one camp item at a campfire (1-hour cooldown). Simple Wood: trade and general goods vendors.'
 end
 if key=='crates' then
  local can,last=0,nil
  for _,c in ipairs(self.FAVOR_CRATES) do
   if c[1]~=last then last=c[1];rows[#rows+1]={text=c[1]..' crates',color=accent} end
   local best,bestHave,bestNeed,fills=nil,-1,1,0
   for _,b in ipairs(c[4]) do
    local have=self:HaveCount(b[2])
    local n=math.floor(have/b[1]);fills=fills+n
    if have/b[1]>bestHave/bestNeed then best,bestHave,bestNeed=b,have,b[1] end
   end
   can=can+fills
   local favor=c[3] and (c[3]..' Favor') or 'Favor unknown'
   local text
   if fills>0 then text=('     %s (%s): |cff40ff40can fill %d|r - e.g. %d %s (have %d)'):format(c[2],favor,fills,best[1],best[2],bestHave)
   else text=('     %s (%s): closest %s %d/%d'):format(c[2],favor,best and best[2] or '?',math.max(0,bestHave),best and best[1] or 0) end
   rows[#rows+1]={text=text,itemName=best and best[2],color=fills==0 and muted or nil}
  end
  return rows,('Merchant\'s Favor: Waylaid Crates you can fill from what you hold (%d in all).\nFill a crate with ONE bundle; turn in at Durotar Supply (Crossroads, Barrens).'):format(can),
   'Apprentice and Journeyman need level 10, Expert 20, Artisan 35. Artisan Favor amounts aren\'t known yet.'
 end
 local g=self.GUIDES[key]
 if not g then return rows,'','' end
 for _,l in ipairs(g.lines) do rows[#rows+1]={text=(l[1]==H and '' or '     ')..l[2],color=l[1]==H and accent or nil} end
 return rows,g.name..' (wow-professions.com Forever guide).','Routes are the guide\'s; Forever is new, so some may change on live.'
end
