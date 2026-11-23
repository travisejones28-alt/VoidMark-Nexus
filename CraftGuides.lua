local _,N=...
N=N or VoidMarkNexus
-- Crafting guides for the Guides tab, Horde only. Each one gives the trainers,
-- every leveling step (what to craft, how many, and the notes that matter),
-- where to buy supplies and recipes, then the materials as have / need.
-- Sources: wow-professions.com Forever guides (Alchemy: Wowhead Forever) and
-- warcrafttavern.com trainer list. Forever is new; counts are the guide's.
--   train = {'Rank (requirements)', 'Trainer - place', ...}
--   steps = {range, craft, note}
--   shop  = {'What', 'where'}

N.CRAFT_GUIDES={
 alch={prof='Alchemy',name='Alchemy 1-300',source='Wowhead Forever guide',preset='alch',
  train={
   {'Journeyman (Alchemy 50, level 10)','Yelmak - Orgrimmar, The Drag; Doctor Marsh - Undercity, The Apothecarium; Bena Winterhoof - Thunder Bluff, Middle Rise'},
   {'Expert (Alchemy 125, level 20, 50s)','Doctor Herbert Halsey - Undercity, The Apothecarium'},
   {'Artisan (Alchemy 200, level 35)','Rogvar - Stonard, Swamp of Sorrows; or Master Mycologist Shurome - Emerald Sanctuary, Felwood'}},
  steps={
   {'1-12','Elixir of Minor Force x11','Known from the start.'},
   {'12-55','Elixir of Minor Defense x43','Known from the start. Learn Journeyman at 50.'},
   {'55-65','Minor Mana Potion x10'},
   {'65-90','Elixir of Minor Fortitude x26'},
   {'90-120','Elixir of Wisdom x30','Keep them if you also level Tailoring (Gloves of Meditation).'},
   {'120-160','Lesser Mana Potion x43','Learn Expert at 125 in Undercity.'},
   {'160-195','Mana Potion x38'},
   {'195-205','Elixir of Agility x10','Learn Artisan at 200 (Stonard).'},
   {'205-225','Greater Mana Potion x20'},
   {'225-226',"Philosopher's Stone x1",'Keep it: transmutes need it. Recipe from Alchemist Pestlezugg, Gadgetzan (Tanaris).'},
   {'226-240','Greater Mana Potion x20'},
   {'240-260','Draught of Detect Undead x23'},
   {'260-270','Superior Mana Potion x10','Recipe from Algernon, Undercity (Trade Quarter).'},
   {'270-300','Major Discolored Healing Potion x31','Taught after a short questline from Apothecary Renferrel, The Sepulcher (Silverpine Forest).'}},
  shop={
   {'Empty Vial','Alchemy or Trade Supply vendor next to any trainer (Undercity: Algernon).'},
   {'Leaded and Crystal Vial','Alchemy Supply vendors. Crystal Vial also Mishta, Silithus.'},
   {'Recipes',"Philosopher's Stone: Alchemist Pestlezugg, Gadgetzan. Superior Mana Potion: Algernon, Undercity."}}},

 lw={prof='Leatherworking',name='Leatherworking 1-300',source='wow-professions.com Forever guide',preset='lw',
  train={
   {'Journeyman (Leatherworking 50, level 10)','Karolek - Orgrimmar, The Drag; Arthur Moore - Undercity, Rogues\' Quarter; Tarn - Thunder Bluff, Middle Rise'},
   {'Expert (Leatherworking 125, level 20, 50s)','Una - Thunder Bluff, Middle Rise'},
   {'Artisan (Leatherworking 200, level 35)','Hahrana Ironhide - Camp Mojache, Feralas'}},
  steps={
   {'1-30','Light Leather x35'},
   {'30-55','Cured Light Hide x27','Keep 24 Light Hides for Light Leather Pants at 100. Learn Journeyman at 50.'},
   {'55-75','Embossed Leather Gloves x21'},
   {'75-80','Medium Leather x8'},
   {'80-90','Cured Medium Hide x10','Keep them for Dark Leather Belt at 115.'},
   {'90-100','Fine Leather Belt x19','Keep 10 for Dark Leather Belt at 115.'},
   {'100-115','Light Leather Pants x24'},
   {'115-125','Dark Leather Belt x10','Learn Expert at 125 from Una, Thunder Bluff.'},
   {'125-130','Heavy Leather x7'},
   {'130-143','Cured Heavy Hide x30','Keep 15 for Barbaric Shoulders (155) and 15 for Guardian Gloves (170).'},
   {'143-155',"Hillman's Leather Gloves x17"},
   {'155-170','Barbaric Shoulders x15'},
   {'170-185','Guardian Gloves x15'},
   {'185-195','Barbaric Harness x16'},
   {'195-205','Nightscape Headband x12','Learn Artisan at 200 from Hahrana Ironhide, Camp Mojache (Feralas).'},
   {'205-235','Nightscape Pants x36','Only the Artisan trainer teaches this, not Una.'},
   {'235-265','Wicked Leather Gauntlets x36 (or Blue Suede Shoes x36)','Gauntlets pattern: Werg Thickblade, Tirisfal Glades.'},
   {'265-300','Runic Leather Headband x53 (or Blue Suede Hat x15 from 285)','Headband pattern: Jase Farlane, Light\'s Hope Chapel (Eastern Plaguelands).'}},
  shop={
   {'Salt, Coarse Thread','Abigail Shiel, Brill (Tirisfal Glades).'},
   {'Threads, dyes, salt','Leatherworking Supply vendor next to each trainer.'},
   {'Patterns','Wicked Leather Gauntlets: Werg Thickblade, Tirisfal Glades. Runic Leather Headband: Jase Farlane, Light\'s Hope Chapel.'},
   {'Specialization','Dragonscale, Elemental or Tribal at Leatherworking 225 and level 40 (optional).'}}},

 cook={prof='Cooking',name='Cooking 1-300',source='wow-professions.com Forever guide',preset='cook',
  train={
   {'Apprentice and Journeyman (Cooking 50)','Zamja - Orgrimmar, The Drag; Eunice Burch - Undercity, Trade Quarter; Aska Mistrunner - Thunder Bluff; Cook Torka - Razor Hill; Duhng - Crossroads; William Pickman - Brill'},
   {'Expert (Cooking 125): a book, no trainer','Expert Cookbook from Wulan - Shadowprey Village, Desolace (26.1, 69.7)'},
   {'Artisan (Cooking 225, level 35): a quest','"To Gadgetzan You Go!" from Zamja (Orgrimmar), then Clamlette Surprise from Dirge Quikcleave, Gadgetzan (52.6, 27.9)'}},
  steps={
   {'1-50','Brilliant Smallfish, Slitherskin Mackerel, Charred Wolf Meat or Roasted Boar Meat x55','Learn Journeyman at 50, or skill stops at 75.'},
   {'50-100','Longjaw Mud Snapper, Rainbow Fin Albacore or Strider Stew x55 (or Smoked Bear Meat x65-75)','Smoked Bear Meat turns orange sooner: make extra.'},
   {'100-130','Bristle Whisker Catfish x30'},
   {'130-150','Bristle Whisker Catfish x25, Curiously Tasty Omelet x20, Goblin Deviled Clams x25 or Hot Lion Chops x25','Expert Cookbook at 125 from Wulan, Desolace.'},
   {'150-175','Goblin Deviled Clams x30, Curiously Tasty Omelet x30 or Hot Lion Chops x25','Catfish turns green at 160 (~90 needed for 25 points).'},
   {'175-225','Roast Raptor, Mithril Headed Trout or Soothing Turtle Bisque x55','Gather the Clamlette Surprise items before going to Gadgetzan.'},
   {'225-275','Spotted Yellowtail or Filet of Redgill x140 (cheaper fish)','Recipes: Gikkix, Steamwheedle Port (Tanaris); Kelsey Yance, Booty Bay.'},
   {'275-300','Spotted Yellowtail or Filet of Redgill x140, or Poached Sunscale Salmon x35'}},
  shop={
   {'Spices','Mild, Hot and Soothing Spices: Cooking Supply vendor near your trainer (not the AH).'},
   {'Fish recipes','Brilliant Smallfish / Longjaw Mud Snapper: Lizbeth Cromwell, Undercity; Harn Longcast, Mulgore. Mackerel / Albacore: Zansoa, Durotar; Shankys, Orgrimmar.'},
   {'Meat recipes','Smoked Bear Meat: Andrew Hilbert, Silverpine. Strider Stew: Tari\'qa, Barrens. Hot Lion Chops: Zargh, Barrens.'},
   {'More recipes','Catfish: Kilxx, Barrens; Ronald Burch, Undercity. Omelet and Roast Raptor: Keena, Arathi (Hammerfall). Trout: Shankys, Orgrimmar. Turtle Bisque: quest, Christoph Jeffcoat (Hillsbrad).'},
   {'225-300 recipes','Spotted Yellowtail and Poached Sunscale Salmon: Gikkix, Steamwheedle Port. Filet of Redgill: Kelsey Yance, Booty Bay.'}}},

 ench={prof='Enchanting',name='Enchanting 1-300',source='wow-professions.com Forever guide (Strange Dust path)',preset='ench',
  train={
   {'Journeyman (Enchanting 50, level 10)','Godan - Orgrimmar, The Drag; Lavinia Crowe - Undercity, The Apothecarium; Teg Dawnstrider - Thunder Bluff, Middle Rise'},
   {'Expert (Enchanting 125, level 20, 50s)','Hgarth - Sun Rock Retreat, Stonetalon Mountains (the only Horde one)'},
   {'Artisan (Enchanting 200, level 35)','Annora - Uldaman, south of Temple Hall. She appears after you clear her area. Learn ALL her recipes: 230+ are taught nowhere else.'}},
  steps={
   {'1-2','Runed Copper Rod x1'},
   {'2-20','Enchant Bracer - Inferior Stamina x18'},
   {'20-70','Enchant Chest - Inferior Stamina x50 (or Bracer - Minor Deflect)','Learn Journeyman at 50.'},
   {'70-100','Enchant Bracer - Minor Stamina x30'},
   {'100-109','Enchant Cloak - Minor Protection x9'},
   {'109-110','Runed Silver Rod x1'},
   {'110-130','Enchant Cloak - Minor Protection x32'},
   {'130-150','Enchant Boots - Minor Stamina x20 (or Bracer - Lesser Stamina)','Learn Expert at 125 from Hgarth. Buy the Minor Mana Oil and Lesser Wizard Oil formulas now.'},
   {'150-151','Runed Golden Rod x1'},
   {'151-165','Minor Mana Oil x16'},
   {'165-200','Enchant Boots - Lesser Agility x47 (or Bracer - Strength 165-185)'},
   {'200-201','Runed Truesilver Rod x1','Learn Artisan from Annora, Uldaman.'},
   {'201-220','Lesser Wizard Oil x25'},
   {'220-225','Enchant Cloak - Greater Defense x5'},
   {'225-250','Enchant Gloves - Agility x37'},
   {'250-265','Lesser Mana Oil x20','Formula: Kania, upstairs in the Silithus inn. No Purple Lotus? Bracer - Greater Strength (Annora).'},
   {'265-299','Enchant Shield - Greater Stamina x40','Formula: Daniel Bartlett, Undercity (bind on pickup). Yellow from 285: make extra.'},
   {'299-300','Runed Arcanite Rod x1','Formula: Lorelae Wintersong, Nighthaven (Moonglade). Can be made from 290.'}},
  shop={
   {'Copper Rod, Mote of Magic','Enchanting Supply: Jhag (Orgrimmar), Malcomb Wynn (Undercity), Mot Dawnstrider (Thunder Bluff). Motes also Vance Undergloom, Brill.'},
   {'Silver, Golden, Truesilver, Arcanite Rod','Made by blacksmiths: buy on the AH.'},
   {'Formulas','2H Lesser Intellect, Minor Mana Oil, Lesser Wizard Oil: Kithas (Orgrimmar), Nata Dawnstrider (Thunder Bluff), Thaddeus Webb (Undercity), Leo Sarn (Silverpine).'},
   {'Late formulas','Lesser Mana Oil: Kania, Silithus. Shield - Greater Stamina: Daniel Bartlett, Undercity. Runed Arcanite Rod: Lorelae Wintersong, Moonglade.'},
   {'Seeds and vials','Maple / Stranglethorn Seed: reagent vendors. Leaded Vial: Alchemy Supply. Crystal Vial: Mishta (Silithus) or Alchemy Supply.'}}},

 tail={prof='Tailoring',name='Tailoring 1-300',source='wow-professions.com Forever guide',preset='tail',
  train={
   {'Journeyman (Tailoring 50, level 10)','Magar - Orgrimmar; Rhiannon Davis - Undercity, The Magic Quarter; Tepa - Thunder Bluff; Mahani - Camp Taurajo (Barrens)'},
   {'Expert (Tailoring 125, level 20, 50s)','Josef Gregorian - Undercity, The Magic Quarter'},
   {'Artisan (Tailoring 200, level 35)','Daryl Stack - Tarren Mill, Hillsbrad Foothills'}},
  steps={
   {'1-30','Bolt of Linen Cloth x30'},
   {'30-55','Linen Belt x28','Learn Journeyman before 55.'},
   {'55-80','Bolt of Woolen Cloth x45','You need 153 bolts in all until 140: make them now.'},
   {'80-95','Woolen Cape x22'},
   {'95-100','Double-stitched Woolen Shoulders x5'},
   {'100-120','Bolt of Silk Cloth x54','You need 184 bolts in all until 190: make them now.'},
   {'120-140','Gloves of Meditation x29','Yellow at 125: make a few extra. Learn Expert at 125 (Undercity).'},
   {'140-150','Bolt of Mageweave x23','You need 157 bolts in all until 225: make them now.'},
   {'150-170','Crimson Silk Vest x20'},
   {'170-190','Crimson Silk Pantaloons x26','Yellow at 180.'},
   {'190-200','Black Mageweave Leggings x19','Yellow the whole way. Learn Artisan at 200 (Tarren Mill).'},
   {'200-205','Black Mageweave Shoulders x5','Only the Artisan trainer teaches this.'},
   {'205-215','Bolt of Runecloth x23','You need 311 bolts in all until 280: make them now.'},
   {'215-225','Mageweave Bag x26 (or Runecloth Belt x10)'},
   {'225-240','Runecloth Belt x24'},
   {'240-250','Runecloth Gloves x11','Pattern: Qia, Everlook (Winterspring).'},
   {'250-280','Runecloth Cuffs x39','Pattern: Pexmit, Mount Hyjal (bind on pickup). Yellow at 265.'},
   {'280-300','Runecloth Shoulders x58 or Wizardweave Turban x58','Patterns are world drops / AH. Runecloth Headband or Cuffs stop at ~290.'},
   {'285-300','Swarmtender\'s or Venomspew Gloves x5, Cord x5, Footpads x18','Cenarion Circle rep and a Loom. Patterns: Mishta, Silithus.'}},
  shop={
   {'Threads and dyes','Tailoring Supply vendor next to each trainer. Coarse Thread: Abigail Shiel, Brill.'},
   {'Patterns','Runecloth Gloves: Qia, Everlook. Runecloth Cuffs: Pexmit, Mount Hyjal. Cenarion patterns: Mishta, Silithus.'},
   {'Note','280-300 is from the Forever beta and may change.'}}},

 eng={prof='Engineering',name='Engineering 1-300',source='wow-professions.com Forever guide',preset='eng',
  train={
   {'Journeyman (Engineering 50, level 10)','Nogg - Orgrimmar, Valley of Honor; Franklin Lloyd - Undercity, Rogues\' Quarter'},
   {'Expert (Engineering 125, level 20, 50s)','Roxxik - Orgrimmar, Valley of Honor'},
   {'Artisan (Engineering 200, level 35)','Buzzek Bracketswing - Gadgetzan, Tanaris (also teaches the 200+ recipes)'}},
  steps={
   {'1-30','Rough Blasting Powder x60','Keep them for the bombs at 51. Buy a Blacksmith Hammer.'},
   {'30-50','Handful of Copper Bolts x30','Keep them for the bombs.'},
   {'50-51','Arclight Spanner x1','Keep it. Learn Journeyman before going past 50.'},
   {'51-75','Rough Copper Bomb x30','Some go yellow at 60.'},
   {'75-90','Coarse Blasting Powder x60','Keep them for the dynamite.'},
   {'90-100','Coarse Dynamite x20'},
   {'100-105','Silver Contact x5 (or Flying Tiger Goggles x5)'},
   {'105-125','Bronze Tube x25','Keep 10. Yellow the whole way.'},
   {'125-135','Standard Scope x10','Learn Expert at 125 from Roxxik. No Moss Agate? Heavy Blasting Powder.'},
   {'135-150','Heavy Blasting Powder x30, then Whirring Bronze Gizmo x15','You need both for the Explosive Sheep.'},
   {'150-160','Bronze Framework x15','Keep all 15.'},
   {'160-175','Explosive Sheep x15','Keep 5 if you may pick Goblin Engineering.'},
   {'175-194','Solid Blasting Powder x60','Save them.'},
   {'194-195','Gyromatic Micro-Adjustor x1','Keep it.'},
   {'195-200','Mithril Tube x6','Keep all 6 (Gnomish). At 200 and level 30 pick Gnomish or Goblin.'},
   {'200-215','Unstable Trigger x20','Learn Artisan at 200 from Buzzek Bracketswing, Gadgetzan.'},
   {'215-238','Mithril Casing x40','Keep them for the bombs.'},
   {'238-250','Hi-Explosive Bomb x20'},
   {'250-260','Dense Blasting Powder x30','Yellow from 250: may need more.'},
   {'260-285','Thorium Widget x35','Schematic: Sovik, Orgrimmar.'},
   {'285-300','Thorium Tube x20','Schematic: Xizzer Fizzbolt, Everlook (first building right of the gate). Bind on pickup.'}},
  shop={
   {'Weak Flux, Blacksmith Hammer','Engineering Supply vendor near Nogg (Orgrimmar) or Franklin Lloyd (Undercity). Hammer also Sumi, Orgrimmar.'},
   {'Schematics','Thorium Widget: Sovik, Orgrimmar. Thorium Tube: Xizzer Fizzbolt, Everlook (Winterspring).'}}},

 bs={prof='Blacksmithing',name='Blacksmithing 1-300',source='wow-professions.com Forever guide',preset='bs',
  train={
   {'Journeyman (Blacksmithing 50, level 10)','Snarl - Orgrimmar, Valley of Honor; James Van Brunt - Undercity, War Quarter; Karn Stonehoof - Thunder Bluff; Traugh - Crossroads'},
   {'Expert (Blacksmithing 125, level 20)','Saru Steelfury - Orgrimmar, Valley of Honor'},
   {'Artisan (Blacksmithing 200, level 35)','Brikk Keencraft - Booty Bay, Stranglethorn Vale'}},
  steps={
   {'1-25','Rough Sharpening Stone x30','Buy a Blacksmith Hammer.'},
   {'25-50','Rough Grinding Stone x30','Keep 10 for the Silver Rods.'},
   {'50-75','Coarse Grinding Stone x36','Make all 36 (bracers at 95 and 112). Learn Journeyman.'},
   {'75-80','Silver Rod x5 (or Runed Copper Belt x5)'},
   {'80-95','Runed Copper Belt x18'},
   {'95-100','Patterned Bronze Bracers x5'},
   {'100-112','Heavy Grinding Stone x20','Keep all 20 for Golden Scale Bracers.'},
   {'112-125','Patterned Bronze Bracers x13'},
   {'125-140','Bronze Shortsword x24','Learn Expert at 125 from Saru Steelfury.'},
   {'140-150','Bronze Warhammer x10'},
   {'150-175','Green Iron Bracers x30','Green Dye: Tamar, Orgrimmar.'},
   {'175-180','Solid Grinding Stone x8','Keep 6 for Heavy Mithril Axes.'},
   {'180-195','Golden Scale Bracers x20'},
   {'195-210','Mithril Plate Pants x17','Learn Artisan at 200 from Brikk Keencraft, Booty Bay.'},
   {'210-215','Heavy Mithril Axe x6','Keep 2 for Weaponsmithing.'},
   {'215-225','Heavy Mithril Breastplate x10'},
   {'225-230','Dense Sharpening Stone x5'},
   {'230-240','Heavy Mithril Boots x16'},
   {'240-245','Imperial Plate Belt x5','Quest from Derotain Mudsipper, Tanaris (20 Thorium Bars). Bring ~250 bars.'},
   {'245-270','Imperial Plate Bracers x27','Quest: 20 Thorium Bars.'},
   {'270-290','Imperial Plate Boots x20','Quest: 40 Thorium Bars.'},
   {'290-300','Imperial Plate Leggings x10','Quest: 60 Thorium Bars.'}},
  shop={
   {'Weak and Strong Flux','Blacksmithing Supply vendor next to each trainer.'},
   {'Blacksmith Hammer','Sumi (Orgrimmar), Samuel Van Brunt (Undercity), Taur Stonehoof (Thunder Bluff), Flakk (Razor Hill), Abigail Shiel (Brill).'},
   {'Green Dye','Tamar, Orgrimmar.'},
   {'Imperial Plate plans','Quests from Derotain Mudsipper, Tanaris (level 50).'}}},
}
N.CRAFT_ORDER={'alch','bs','cook','ench','eng','lw','tail'}

-- Trainers for the gathering guides (shown above the route).
N.GATHER_TRAINERS={
 herb={{'Herbalism trainers','Jandi - Orgrimmar, The Drag; Martha Alliestar - Undercity, Apothecarium; Komin Winterhoof - Thunder Bluff; Mishiki - Sen\'jin Village; Faruza - Brill'},
  {'Out in the world','Aranae Venomblood - Tarren Mill; Angrun - Grom\'gol; Ruw - Camp Mojache (Feralas)'}},
 mine={{'Mining trainers','Makaru - Orgrimmar, Valley of Honor; Brom Killian - Undercity, War Quarter; Brek Stonehoof - Thunder Bluff; Krunn - Razor Hill'},
  {'Out in the world','Johan Focht - The Sepulcher (Silverpine); Pikkle - Gadgetzan (Tanaris)'}},
 fish={{'Fishing trainers','Lumak - Orgrimmar, Valley of Honor; Armand Cromwell - Undercity; Kah Mistrunner - Thunder Bluff; Lau\'Tiki - Sen\'jin Village'},
  {'Expert and Artisan','Expert book: Old Man Heming, Booty Bay (27.5, 77.0). Artisan: Nat Pagle quest, Dustwallow Marsh (58.5, 59.8).'}},
}

-- Every guide in the Guides tab dropdown, in order.
N.GUIDE_LIST={
 {key='alch',label='Alchemy 1-300'},{key='bs',label='Blacksmithing 1-300'},{key='cook',label='Cooking 1-300'},
 {key='ench',label='Enchanting 1-300'},{key='eng',label='Engineering 1-300'},{key='lw',label='Leatherworking 1-300'},
 {key='tail',label='Tailoring 1-300'},
 {key='herb',label='Herbalism 1-300'},{key='mine',label='Mining 1-300'},{key='fish',label='Fishing 1-300'},
 {key='lock',label='Lockpicking 1-300 (Rogue)'},{key='camp',label='Camping: camp items'},
 {key='crates',label="Merchant's Favor: crates"},{key='favor',label="Merchant's Favor: how it works"},
}

-- Rows, info line and footer for one guide.
function N:GuideTabRows(key)
 local accent,muted,gold,sub={.78,.6,1},{.65,.6,.72},{1,.82,0},{.85,.8,.95}
 local g=self.CRAFT_GUIDES[key]
 if not g then
  local rows,info,foot=self:GuideRows(key)
  local t=self.GATHER_TRAINERS[key]
  if t then
   local top={{text='Trainers',color=accent}}
   for _,l in ipairs(t) do top[#top+1]={text='   '..l[1]..': '..l[2],color=sub} end
   top[#top+1]={text='Route',color=accent}
   for _,r in ipairs(rows) do top[#top+1]=r end
   rows=top
  end
  if key=='fish' then for _,r in ipairs(self:FishExtraRows()) do rows[#rows+1]=r end end
  return rows,info,foot
 end
 local rows={}
 rows[#rows+1]={text='Trainers (Horde)',color=accent}
 for _,t in ipairs(g.train) do
  rows[#rows+1]={text='   '..t[1],color=gold}
  rows[#rows+1]={text='      '..t[2],color=sub}
 end
 rows[#rows+1]={text='Steps',color=accent}
 for _,s in ipairs(g.steps) do
  rows[#rows+1]={text='   |cffc8a0ff'..s[1]..'|r  '..s[2],itemName=s[2]:match('^(.-) x%d') or nil}
  if s[3] then rows[#rows+1]={text='         '..s[3],color=muted} end
 end
 rows[#rows+1]={text='Where to buy (Horde)',color=accent}
 for _,s in ipairs(g.shop) do rows[#rows+1]={text='   '..s[1]..': |cffd8d0e0'..s[2]..'|r',color=gold} end
 local p=self.NEED_PRESETS[g.preset]
 local total=0
 if p then
  rows[#rows+1]={text='Materials: have / need (every character)',color=accent}
  for _,step in ipairs(p.steps) do
   local lines,cost,unknown=self:NeedLines(step[2]);total=total+cost
   rows[#rows+1]={text='   '..step[1]..'   buy ~'..self:Money(cost)..(unknown>0 and ('  (+'..unknown..' without an AH price)') or ''),color=gold}
   for i,l in ipairs(lines) do rows[#rows+1]={text='      '..l,itemName=step[2][i][2]} end
  end
 end
 return rows,g.name..' ('..g.source..'). Horde only.\nMaterials still to buy: ~'..self:Money(total)..' at AH prices; vendor items not included.',
  'Scroll for steps, vendors, then your materials. Bank and mail count from when you last opened them.'
end

-- Character view -------------------------------------------------------------
-- The profession each guide follows (crafting guides carry .prof).
N.GUIDE_PROF={herb='Herbalism',mine='Mining',fish='Fishing',lock='Lockpicking'}
function N:GuideProfession(key)
 local g=self.CRAFT_GUIDES[key]
 return g and g.prof or self.GUIDE_PROF[key]
end
-- A character's record for a profession, by name.
function N:CharProfession(c,name)
 if type(c)~='table' or not name then return nil end
 local want=name:lower()
 for _,p in pairs(c.professions or {}) do
  if type(p)=='table' and type(p.name)=='string' and p.name:lower()==want then return p end
 end
end
-- Characters for the dropdown: name, skill / cap, or not learned. Learned first.
function N:GuideCharacters(key)
 local prof=self:GuideProfession(key)
 local preferred=self:PreferredRecords()
 local out={}
 for cid,c in pairs(self.db.characters or {}) do
  if preferred[cid] and type(c)=='table' then
   local p=prof and self:CharProfession(c,prof)
   out[#out+1]={id=cid,name=c.name or '?',p=p}
  end
 end
 table.sort(out,function(a,b)
  if (a.p~=nil)~=(b.p~=nil) then return a.p~=nil end
  if a.p and b.p and (a.p.skill or 0)~=(b.p.skill or 0) then return (a.p.skill or 0)>(b.p.skill or 0) end
  return a.name<b.name end)
 return out
end

local function range(text)
 local a,b=tostring(text or ''):match('^(%d+)%-(%d+)')
 return tonumber(a),tonumber(b)
end
-- Recipe names a step may use: "A, B or C x55 (or D x10)" -> {A,B,C,D}; first count.
function N:StepCrafts(text)
 local names,count={},tonumber(tostring(text):match(' x(%d+)'))
 local text2=tostring(text):gsub('%(or ([^)]+)%)',function(alt) return ', '..alt end):gsub('%b()','')
 for piece in (text2:gsub(' or ',',')..','):gmatch('([^,]+),') do
  local name=piece:gsub(' x%d+.*$',''):gsub('^%s+',''):gsub('%s+$','')
  if name~='' then names[#names+1]=name end
 end
 return names,count or 0
end
-- The character's recipe for a step: the first option they know, or any option seen.
function N:StepRecipe(p,text)
 if not p or type(p.recipes)~='table' then return nil end
 local names=self:StepCrafts(text)
 local byName={}
 for _,r in pairs(p.recipes) do if type(r)=='table' and type(r.name)=='string' then byName[r.name:lower()]=r end end
 local seen
 for _,n in ipairs(names) do
  local r=byName[n:lower()]
  if r and r.learned~=false then return r,true end
  seen=seen or r
 end
 return seen,false
end
local function recipeCount(p) local n=0; for _ in pairs(p and p.recipes or {}) do n=n+1 end; return n end
-- {need,name} materials for n crafts of a recipe.
function N:RecipeNeeds(r,n)
 local list={}
 for _,g in ipairs(r and r.reagents or {}) do
  local name=g.name or (g.id and (self:FinderName(g.id) or self:ItemName(g.id)))
  if name then list[#list+1]={(g.qty or 1)*n,name} end
 end
 return list
end
-- How many items in a list you're short of.
function N:ShortCount(list)
 local short=0
 for _,e in ipairs(list) do if self:HaveCount(e[2])<e[1] then short=short+1 end end
 return short
end
-- Who holds an item: "Kitty 4 (bags), Bank 4 (bank)".
function N:HoldersText(name)
 for _,item in ipairs(self:FindItems(name)) do
  if item.name:lower()==tostring(name):lower() then return table.concat(self:ReportOwners(item.places),', ') end
 end
 return nil
end

-- Crafts you make, counted per recipe and the skill you had when you made
-- them, so a step can say "made 12, about 7 to go".
function N:RecordGuideCraft(spell)
 local c=self.character
 if type(c)~='table' or not spell then return false end
 for _,p in pairs(c.professions or {}) do
  if type(p)=='table' and type(p.recipes)=='table' then
   local r=p.recipes[tostring(spell)]
   if type(r)~='table' then for _,x in pairs(p.recipes) do if type(x)=='table' and x.spell==spell then r=x; break end end end
   if type(r)=='table' and type(r.name)=='string' then
    c.guideCrafts=type(c.guideCrafts)=='table' and c.guideCrafts or {}
    local k=r.name:lower();local h=type(c.guideCrafts[k])=='table' and c.guideCrafts[k] or {};c.guideCrafts[k]=h
    local sk=tonumber(p.skill) or 0;h[sk]=(h[sk] or 0)+1
    self.dirty=true
    return true
   end
  end
 end
 return false
end
N:On('UNIT_SPELLCAST_SUCCEEDED',function(unit,_,spell) if unit=='player' then N:RecordGuideCraft(spell) end end)
-- Crafts of a step's recipes made while your skill was inside the step.
function N:StepMade(c,names,a,b)
 local made=0
 local log=type(c)=='table' and type(c.guideCrafts)=='table' and c.guideCrafts or {}
 for _,n in ipairs(names or {}) do
  local h=log[tostring(n):lower()]
  if type(h)=='table' then for sk,k in pairs(h) do sk=tonumber(sk) if sk and sk>=a and sk<b and tonumber(k) then made=made+k end end end
 end
 return made
end
-- "Skill 24 / 30  [========--]  made 12 - about 7 to go"
function N:StepProgressText(skill,a,b,made,more)
 local span=math.max(1,b-a);local into=math.max(0,math.min(span,skill-a))
 local w=20;local fill=math.floor(w*into/span+0.5)
 local bar='[|cff66dd66'..string.rep('=',fill)..'|r|cff5a4f6a'..string.rep('-',w-fill)..'|r]'
 local tail=made>0 and ('made '..made..' - about '..more..' to go') or ('about '..more..' to go')
 return 'Skill '..skill..' / '..b..'  '..bar..'  '..tail
end

-- Training checkpoints: index 1/2/3 of a guide's train list = Journeyman,
-- Expert, Artisan; learn at 50/125/200, after which the cap is 150/225/300.
local TIERS={{at=50,cap=150},{at=125,cap=225},{at=200,cap=300}}

function N:GuideCharacterRows(key,cid,showDone)
 local accent,muted,gold,green,warn,sub={.78,.6,1},{.6,.56,.68},{1,.82,0},{.4,1,.4},{1,.75,.3},{.85,.8,.95}
 local c=self.db.characters[cid]
 local prof=self:GuideProfession(key)
 local p=self:CharProfession(c,prof)
 local name=c and c.name or '?'
 if not p then
  local rows={{text=name..' has not learned '..tostring(prof)..'.',color=muted},{text='Pick "Whole guide" to read it, or another character.',color=muted}}
  return rows,name..': '..tostring(prof)..' not learned (or not seen yet: log in on them once).',''
 end
 local skill,cap=tonumber(p.skill) or 0,tonumber(p.max) or 0
 local g=self.CRAFT_GUIDES[key]
 -- One ordered list of steps and checkpoints.
 local items={}
 if g then
  for i,s in ipairs(g.steps) do local a,b=range(s[1]); items[#items+1]={kind='step',a=a or 0,b=b or 0,s=s,order=(a or 0)+i/1000} end
  for i,t in ipairs(g.train) do
   local tier=TIERS[i]
   if tier then
    -- Placed before the step in which you reach it.
    local at=tier.at
    for _,it in ipairs(items) do if it.kind=='step' and it.b>tier.at then at=it.a-0.5; break end end
    items[#items+1]={kind='train',tier=tier,t=t,order=at}
   end
  end
 else
  local gd=self.GUIDES[key]
  local last
  for i,l in ipairs(gd and gd.lines or {}) do
   local a,b=range(l[2])
   local at=tonumber(tostring(l[2]):match('^(%d+)[%s:(]'))
   if a and l[1]=='h' then last={kind='step',a=a,b=b,s={l[2]:match('^[%d%-]+:%s*(.*)$') and (a..'-'..b) or l[2],l[2]:match('^[%d%-]+:%s*(.*)$') or l[2]},notes={},order=a+i/1000}; items[#items+1]=last
   elseif at and l[1]=='h' then items[#items+1]={kind='mark',at=at,text=l[2],order=at-0.5+i/1000}; last=nil
   elseif last then last.notes[#last.notes+1]=l[2]
   else items[#items+1]={kind='note',text=l[2],order=-1+i/1000} end
  end
 end
 table.sort(items,function(x,y) return x.order<y.order end)
 local steps=0;local curIndex
 for _,it in ipairs(items) do if it.kind=='step' then steps=steps+1; if not curIndex and skill<it.b then curIndex=steps end end end
 local rows={}
 local doneRows,doneCount,firstDone,lastDone={},0,nil,nil
 local n=0;local past=true
 local scanned=recipeCount(p)>0
 local flushed=false
 local function flushDone()
  if flushed then return end
  flushed=true
  if doneCount>0 then
   rows[#rows+1]={text=(showDone and '- ' or '+ ')..doneCount..' step'..(doneCount==1 and '' or 's')..' done ('..firstDone..'-'..lastDone..')'..(showDone and '  click to hide' or '  click to show'),color=green,toggleDone=true}
   if showDone then for _,r in ipairs(doneRows) do rows[#rows+1]=r end end
  end
 end
 for _,it in ipairs(items) do
  if it.kind=='step' then
   n=n+1
   local s=it.s
   local done=skill>=it.b
   if done and past then
    doneCount=doneCount+1;firstDone=firstDone or it.a;lastDone=it.b
    doneRows[#doneRows+1]={text='   |cff66dd66done|r  '..s[1]..'  '..s[2],color=muted}
   else
    if past then past=false; flushDone() end
    local stepNames,count=self:StepCrafts(s[2])
    if n==curIndex then
     local more=count
     if it.b>it.a and skill>=it.a then more=math.ceil(count*(it.b-skill)/(it.b-it.a)) end
     -- Once you have made a few, use your own skill-ups per craft.
     local made=g and self:StepMade(c,stepNames,it.a,it.b) or 0
     if made>=3 and skill>it.a then more=math.max(it.b-skill,math.ceil((it.b-skill)*made/(skill-it.a))) end
     local what=g and ('|cffffd200NOW|r  '..s[1]..'  '..s[2]..(count>0 and ('  - about '..more..' more') or '')) or ('|cffffd200NOW|r  '..s[1]..': '..s[2])
     rows[#rows+1]={text=what,color={1,1,1},current=true,itemName=s[2]:match('^(.-) x%d')}
     if skill<it.a then rows[#rows+1]={text='      Your skill is '..skill..'; this step starts at '..it.a..'.',color=warn}
     elseif g and count>0 then rows[#rows+1]={text='      '..self:StepProgressText(skill,it.a,it.b,made,more),color=sub,progress=true} end
     if g then
      local r,known=self:StepRecipe(p,s[2])
      if r and known then
       local list=self:RecipeNeeds(r,more)
       local lines=self:NeedLines(list)
       for i,l in ipairs(lines) do
        rows[#rows+1]={text='      '..l,itemName=list[i][2]}
        local who=self:HoldersText(list[i][2])
        if who and who~='' then rows[#rows+1]={text='         '..who,color=muted} end
       end
       if #list==0 then rows[#rows+1]={text='      No materials recorded for '..r.name..'.',color=muted} end
      elseif r then rows[#rows+1]={text='      Not learned yet: '..r.name..'.',color=warn}
      elseif scanned then rows[#rows+1]={text='      Not learned yet (see the note below).',color=warn}
      else rows[#rows+1]={text='      Open '..prof..' on '..name..' once to load the materials.',color=muted} end
      if s[3] then rows[#rows+1]={text='      '..s[3],color=sub} end
     else
      for _,t in ipairs(it.notes or {}) do rows[#rows+1]={text='      '..t,color=sub} end
     end
    else
     local tag=''
     if g then
      local r,known=self:StepRecipe(p,s[2])
      if r and known then
       local short=self:ShortCount(self:RecipeNeeds(r,count))
       tag=short==0 and '  |cff66dd66mats ready|r' or ('  |cffffc040short '..short..' item'..(short==1 and '' or 's')..'|r')
      elseif scanned then tag='  |cff9a8fb0not learned|r' end
     end
     rows[#rows+1]={text='   '..s[1]..'  '..s[2]..tag,itemName=g and s[2]:match('^(.-) x%d') or nil}
    end
   end
  elseif it.kind=='train' then
   local learned=cap>=it.tier.cap
   local due=not learned and skill>=it.tier.at
   if not (learned and past) then
    flushDone()
    local state=learned and '|cff66dd66learned|r' or due and '|cffffc040train now|r' or ('at '..it.tier.at)
    rows[#rows+1]={text=(due and '|cffffc040>|r ' or '   ')..'Train '..it.t[1]..'  '..state,color=due and warn or gold}
    rows[#rows+1]={text='      '..it.t[2],color=sub}
   end
  elseif it.kind=='mark' then
   if not (skill>=it.at and past) then flushDone(); rows[#rows+1]={text='   '..it.text,color=skill>=it.at and muted or gold} end
  elseif it.kind=='note' then
   rows[#rows+1]={text=it.text,color=muted}
  end
 end
 flushDone()
 if past and doneCount>0 then
  rows[#rows+1]={text='All '..doneCount..' steps done.',color=green}
 end
 if key=='fish' then for _,r in ipairs(self:FishExtraRows(skill)) do rows[#rows+1]=r end end
 if g then
  rows[#rows+1]={text='Where to buy (Horde)',color=accent}
  for _,sh in ipairs(g.shop) do rows[#rows+1]={text='   '..sh[1]..': |cffd8d0e0'..sh[2]..'|r',color=gold} end
 end
 local info=('%s: %s %d / %d'):format(name,prof,skill,cap>0 and cap or 300)
 if curIndex then info=info..('  -  step %d of %d'):format(curIndex,steps) end
 if g and not scanned then info=info..'\nOpen '..prof..' on '..name..' once so Nexus knows the recipes.' end
 return rows,info,'Skill updates on that character; materials update from bags (bank and mail when opened).',skill/300
end
