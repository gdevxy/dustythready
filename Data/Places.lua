-- DustyThready: where to train, where to buy recipes and supplies, where to
-- farm cloth. Faction: "H" Horde, "A" Alliance, "N" both.
local _, ns = ...

ns.TRAINERS = {
    enchanting = {
        apprentice = {
            { "Jhag", "Orgrimmar", "The Drag, in Godan's Runeworks", "H" },
            { "Malcomb Wynn", "Undercity", "The Apothecarium", "H" },
            { "Mot Dawnstrider", "Thunder Bluff", "Outside the Dawnstrider Enchanters hut, middle rise", "H" },
            { "Pa'zula", "Durotar", "Sen'jin Village, big building, on the right", "H" },
            { "Vance Undergloom", "Tirisfal Glades", "Brill, upstairs in Gallows' End Tavern (sells Motes!)", "H" },
            { "Eaysaa Brightgust", "Zephras Isle", "Valanaar (sells Motes!)", "N" },
            { "Nasalanna Windsinger", "Zephras Isle", "Shen'dar Village inn (sells Motes!)", "N" },
            { "Betty Quin", "Stormwind", "Mage Quarter canals, Cordell's Enchanting", "A" },
            { "Thonys Pillarstone", "Ironforge", "The Great Forge, by the gryphon master", "A" },
            { "Lalina Summermoon", "Darnassus", "Craftsmen's Terrace", "A" },
            { "Alanna Raveneye", "Teldrassil", "The Oracle Glade (NW)", "A" },
            { "Vanessa Sellers", "Dalaran", "Trade District", "A" },
        },
        journeyman = {
            { "Godan", "Orgrimmar", "The Drag, Godan's Runeworks", "H" },
            { "Lavinia Crowe", "Undercity", "The Apothecarium", "H" },
            { "Teg Dawnstrider", "Thunder Bluff", "Inside the Dawnstrider Enchanters hut", "H" },
            { "Lucan Cordell", "Stormwind", "Mage Quarter canals, Cordell's Enchanting", "A" },
            { "Gimble Thistlefuzz", "Ironforge", "The Great Forge, upstairs in the enchanting shop", "A" },
            { "Taladan", "Darnassus", "Craftsmen's Terrace", "A" },
            { "Vanessa Sellers", "Dalaran", "Trade District", "A" },
        },
        expert = {
            { "Hgarth", "Stonetalon Mountains", "Sun Rock Retreat, on the cliff above the village", "H" },
            { "Kitta Firewind", "Elwynn Forest", "Tower of Azora, top floor", "A" },
        },
        artisan = {
            { "Annora", "Uldaman (Badlands)", "Back entrance. Appears once her area is cleared: bring a group. Bring ~12g for all her recipes.", "N" },
        },
    },
    tailoring = {
        apprentice = {
            { "Snang", "Orgrimmar", "The Drag, Magar's Cloth Goods", "H" },
            { "Vhan", "Thunder Bluff", "Armorers building, middle rise", "H" },
            { "Victor Ward", "Undercity", "Magic Quarter", "H" },
            { "Kil'hala", "The Barrens", "Crossroads, tent by the south gate", "H" },
            { "Bowen Brisboise", "Tirisfal Glades", "Cold Hearth Manor, SW of Brill (thread: Abigail Shiel in Brill)", "H" },
            { "Othesia Evengale", "Zephras Isle", "Valanaar", "N" },
            { "Taleen Shimmerthread", "Zephras Isle", "Shen'dar Village", "N" },
            { "Lawrence Schneider", "Stormwind", "Mage Quarter, Duncan's Textiles", "A" },
            { "Uthrar Threx", "Ironforge", "The Great Forge, Stonebrow's Clothier", "A" },
            { "Trianna", "Darnassus", "Craftsmen's Terrace", "A" },
            { "Grondal Moonbreeze", "Darkshore", "Auberdine, north of the inn", "A" },
            { "Eldrin", "Elwynn Forest", "Eastvale Logging Camp", "A" },
            { "Charles Worth", "Dalaran", "Talismanic Textiles", "A" },
        },
        journeyman = {
            { "Magar", "Orgrimmar", "The Drag, Magar's Cloth Goods", "H" },
            { "Tepa", "Thunder Bluff", "Armorers building", "H" },
            { "Rhiannon Davis", "Undercity", "Magic Quarter", "H" },
            { "Mahani", "The Barrens", "Camp Taurajo", "H" },
            { "Grarnik Goodstitch", "Stranglethorn Vale", "Booty Bay, top of the tailoring shop", "N" },
            { "Othesia Evengale", "Zephras Isle", "Valanaar", "N" },
            { "Sellandus", "Stormwind", "Mage Quarter", "A" },
            { "Jormund Stonebrow", "Ironforge", "The Great Forge, Stonebrow's Clothier", "A" },
            { "Me'lynn", "Darnassus", "Craftsmen's Terrace", "A" },
            { "Charles Worth", "Dalaran", "Talismanic Textiles", "A" },
        },
        expert = {
            { "Josef Gregorian", "Undercity", "Magic Quarter", "H" },
            { "Georgio Bolero", "Stormwind", "Mage Quarter, Duncan's Textiles", "A" },
            { "Charles Worth", "Dalaran", "Talismanic Textiles", "A" },
            { "Melanori", "Shen'dralas", "After the \"Strange Pylons\" quest chain: teaches up to Expert", "N" },
        },
        artisan = {
            { "Daryl Stack", "Hillsbrad Foothills", "Tarren Mill, the church east of the inn", "H" },
            { "Timothy Worthington", "Dustwallow Marsh", "Theramore, upstairs, first building left of the docks", "A" },
        },
    },
}

-- Recipes you must buy or hunt. step = recipe spell it unlocks.
ns.RECIPE_SOURCES = {
    { item = 6349, prof = "enchanting", spell = 7793, skill = 125, where = {
        { "Kithas", "Orgrimmar", "H" }, { "Nata Dawnstrider", "Thunder Bluff", "H" },
        { "Leo Sarn", "Silverpine Forest", "H" }, { "Tilli Thistlefuzz", "Ironforge", "A" } } },
    { item = 20752, prof = "enchanting", spell = 25125, skill = 150, where = {
        { "Kithas", "Orgrimmar", "H" }, { "Nata Dawnstrider", "Thunder Bluff", "H" }, { "Thaddeus Webb", "Undercity", "H" },
        { "Jessara Cordell", "Stormwind", "A" }, { "Tilli Thistlefuzz", "Ironforge", "A" }, { "Vaean", "Darnassus", "A" } } },
    { item = 20753, prof = "enchanting", spell = 25126, skill = 200, where = {
        { "Kithas", "Orgrimmar", "H" }, { "Nata Dawnstrider", "Thunder Bluff", "H" }, { "Thaddeus Webb", "Undercity", "H" },
        { "Jessara Cordell", "Stormwind", "A" }, { "Tilli Thistlefuzz", "Ironforge", "A" }, { "Vaean", "Darnassus", "A" } } },
    { item = 20754, prof = "enchanting", spell = 25127, skill = 250, where = {
        { "Kania", "Silithus", "N", "Cenarion Hold, upstairs in the inn" } } },
    { item = 20755, prof = "enchanting", spell = 25128, skill = 275, where = {
        { "Kania", "Silithus", "N", "Cenarion Hold, upstairs in the inn" } } },
    { item = 16217, prof = "enchanting", spell = 20017, skill = 265, where = {
        { "Daniel Bartlett", "Undercity", "H" }, { "Mythrin'dir", "Darnassus", "A" } }, note = "Binds when picked up" },
    { item = 16243, prof = "enchanting", spell = 20051, skill = 290, where = {
        { "Lorelae Wintersong", "Moonglade", "N", "Nighthaven" } }, note = "Binds when picked up" },
    { item = 14481, prof = "tailoring", spell = 18417, skill = 240, where = {
        { "Qia", "Winterspring", "N", "Everlook, inside the bank" } } },
    { item = 254124, prof = "tailoring", spell = 1257487, skill = 250, where = {
        { "Pexmit", "Mount Hyjal", "N", "Hard to find; bind on pickup" },
        { "Quest: Threading a Solution", "Mount Hyjal", "H", "From Kal'tinzan, Elderwild. Lvl 54, needs 6 Bolt of Runecloth" } } },
    { item = 14504, prof = "tailoring", spell = 18449, skill = 280, where = {
        { "World drop", "Auction House", "N", "Check the AH often" } } },
    { item = 14484, prof = "tailoring", spell = 18420, skill = 240, where = {
        { "World drop", "Auction House", "N" } } },
}

-- Supplies that come from a vendor, never pay AH prices for these.
ns.SUPPLIES = {
    { "Thread & dyes", "Any trade supplies / tailoring supply vendor in the capitals. Rune Thread isn't sold in Theramore: stock up first." },
    { "Mote of Magic", "Enchanting supply vendor next to every Enchanting trainer." },
    { "Maple Seed, Leaded Vial", "Jeeda & Kulwia at Sun Rock Retreat (H) / Dawn Brightstar, Tower of Azora (A)." },
    { "Stranglethorn Seed", "Any reagent vendor." },
    { "Crystal Vial", "Any alchemy supply vendor, or Mishta in Silithus." },
    { "Simple Wood, Copper Rod", "Trade supply vendors (Copper Rod also at Enchanting vendors)." },
}

-- Where cloth drops (humanoids). Community-proven spots by level.
ns.CLOTH_FARMS = {
    { cloth = 2589, lo = 5, hi = 15, spots = {
        { "Westfall", "Defias Bandits & Thugs", "A" }, { "The Barrens", "Kolkar centaurs", "H" },
        { "Silverpine Forest", "Moonrage gnolls & Dalaran apprentices", "H" } } },
    { cloth = 2592, lo = 15, hi = 25, spots = {
        { "Westfall", "Defias at the Moonbrook / Jangolode camps", "A" }, { "Redridge Mountains", "Blackrock orcs", "A" },
        { "The Barrens", "Bristleback quilboar & Kolkar", "H" }, { "Hillsbrad Foothills", "Hillsbrad farmers & Syndicate", "H" } } },
    { cloth = 4306, lo = 25, hi = 35, spots = {
        { "Arathi Highlands", "Syndicate at Northfold Manor", "N" }, { "Hillsbrad Foothills", "Syndicate at Durnholde", "N" },
        { "Thousand Needles", "Galak centaurs", "N" }, { "Duskwood", "Defias & cultists", "A" } } },
    { cloth = 4338, lo = 35, hi = 45, spots = {
        { "Arathi Highlands", "Witherbark trolls & Boulderfist ogres", "N" },
        { "Desolace", "Magram & Gelkis centaurs", "N" },
        { "Stranglethorn Vale", "Skullsplitter & Bloodscalp trolls", "N" },
        { "Tanaris", "Wastewander bandits", "N" }, { "Badlands", "Dustbelcher ogres", "N" } } },
    { cloth = 14047, lo = 48, hi = 60, spots = {
        { "Eastern Plaguelands", "Scourge (Corin's Crossing, Stratholme gates)", "N" },
        { "Felwood", "Jaedenar satyrs & Deadwood furbolgs", "N" },
        { "Burning Steppes", "Blackrock orcs", "N" }, { "Azshara", "Haldarr & Legashi satyrs", "N" } } },
}

-- UiMapID of every zone named above (English name -> map), so zones are matched
-- by ID and shown with the client's own (localized) map name. Names that are no
-- single zone map ("Dalaran", "Uldaman (Badlands)", "Auction House"...) are
-- left out: they are shown through the locale table instead.
ns.ZONE_MAPS = {
    ["Durotar"] = 1411, ["The Barrens"] = 1413, ["Arathi Highlands"] = 1417, ["Badlands"] = 1418,
    ["Tirisfal Glades"] = 1420, ["Silverpine Forest"] = 1421, ["Eastern Plaguelands"] = 1423,
    ["Hillsbrad Foothills"] = 1424, ["Burning Steppes"] = 1428, ["Elwynn Forest"] = 1429,
    ["Duskwood"] = 1431, ["Redridge Mountains"] = 1433, ["Stranglethorn Vale"] = 1434,
    ["Westfall"] = 1436, ["Teldrassil"] = 1438, ["Darkshore"] = 1439, ["Thousand Needles"] = 1441,
    ["Stonetalon Mountains"] = 1442, ["Desolace"] = 1443, ["Dustwallow Marsh"] = 1445,
    ["Tanaris"] = 1446, ["Azshara"] = 1447, ["Felwood"] = 1448, ["Moonglade"] = 1450,
    ["Silithus"] = 1451, ["Winterspring"] = 1452, ["Stormwind"] = 1453, ["Orgrimmar"] = 1454,
    ["Ironforge"] = 1455, ["Thunder Bluff"] = 1456, ["Darnassus"] = 1457, ["Undercity"] = 1458,
    ["Mount Hyjal"] = 2482, ["Zephras Isle"] = 2521,
}
