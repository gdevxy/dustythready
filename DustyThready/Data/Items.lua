-- DustyThready: item names (English fallbacks shown until the client has the
-- item cached; the game's own localized names replace them as soon as it does)
-- and a one-line "where do I get this" hint for every reagent.
local _, ns = ...

ns.ITEM_NAMES = {
    -- Cloth & bolts
    [2589] = "Linen Cloth", [2996] = "Bolt of Linen Cloth",
    [2592] = "Wool Cloth", [2997] = "Bolt of Woolen Cloth",
    [4306] = "Silk Cloth", [4305] = "Bolt of Silk Cloth",
    [4338] = "Mageweave Cloth", [4339] = "Bolt of Mageweave",
    [14047] = "Runecloth", [14048] = "Bolt of Runecloth",
    -- Thread, dye, leather, misc tailoring
    [2320] = "Coarse Thread", [2321] = "Fine Thread", [4291] = "Silken Thread",
    [8343] = "Heavy Silken Thread", [14341] = "Rune Thread",
    [6260] = "Blue Dye", [2604] = "Red Dye",
    [4234] = "Heavy Leather", [8170] = "Rugged Leather", [14227] = "Ironweb Spider Silk",
    [3577] = "Gold Bar", [7910] = "Star Ruby", [7080] = "Essence of Water", [7082] = "Essence of Air",
    -- Tailoring products
    [7026] = "Linen Belt", [2584] = "Woolen Cape", [4314] = "Double-stitched Woolen Shoulders",
    [7048] = "Azure Silk Hood", [4245] = "Small Silk Pack", [7058] = "Crimson Silk Vest",
    [7062] = "Crimson Silk Pantaloons", [9999] = "Black Mageweave Leggings",
    [10027] = "Black Mageweave Shoulders", [10051] = "Red Mageweave Bag", [13856] = "Runecloth Belt",
    [13863] = "Runecloth Gloves", [14103] = "Brightcloth Cloak", [254123] = "Runecloth Cuffs",
    [13867] = "Runecloth Shoulders", [14130] = "Wizardweave Turban", [13866] = "Runecloth Headband",
    -- Patterns
    [14481] = "Pattern: Runecloth Gloves", [254124] = "Pattern: Runecloth Cuffs",
    [14504] = "Pattern: Runecloth Shoulders", [14484] = "Pattern: Brightcloth Cloak",
    -- Enchanting reagents
    [247786] = "Mote of Magic", [6217] = "Copper Rod", [6338] = "Silver Rod", [11128] = "Golden Rod",
    [11144] = "Truesilver Rod", [16206] = "Arcanite Rod", [1210] = "Shadowgem", [4470] = "Simple Wood",
    [5500] = "Iridescent Pearl", [7971] = "Black Pearl", [13926] = "Golden Pearl",
    [17034] = "Maple Seed", [17035] = "Stranglethorn Seed", [3372] = "Leaded Vial", [8925] = "Crystal Vial",
    [8831] = "Purple Lotus", [4625] = "Firebloom",
    [10940] = "Strange Dust", [11083] = "Soul Dust", [11137] = "Vision Dust", [11176] = "Dream Dust",
    [16204] = "Illusion Dust",
    [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence",
    [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence",
    [11134] = "Lesser Mystic Essence", [11135] = "Greater Mystic Essence",
    [11174] = "Lesser Nether Essence", [11175] = "Greater Nether Essence",
    [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence",
    [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard",
    [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard",
    [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard",
    [14343] = "Small Brilliant Shard", [14344] = "Large Brilliant Shard", [20725] = "Nexus Crystal",
    -- Enchanting products
    [6218] = "Runed Copper Rod", [6339] = "Runed Silver Rod", [11130] = "Runed Golden Rod",
    [11145] = "Runed Truesilver Rod", [16207] = "Runed Arcanite Rod",
    [11287] = "Lesser Magic Wand", [11288] = "Greater Magic Wand",
    [11289] = "Lesser Mystic Wand", [11290] = "Greater Mystic Wand",
    [20745] = "Minor Mana Oil", [20746] = "Lesser Wizard Oil", [20747] = "Lesser Mana Oil", [20750] = "Wizard Oil",
    -- Formulas
    [6349] = "Formula: Enchant 2H Weapon - Lesser Intellect", [20752] = "Formula: Minor Mana Oil",
    [20753] = "Formula: Lesser Wizard Oil", [20754] = "Formula: Lesser Mana Oil", [20755] = "Formula: Wizard Oil",
    [16217] = "Formula: Enchant Shield - Greater Stamina", [16243] = "Formula: Runed Arcanite Rod",
}

-- Where each reagent comes from, in one short line. "vendor" ones are
-- flagged so the shopping list can say "buy from a vendor, never the AH".
ns.SOURCES = {
    [2589] = { "Humanoids lvl 5-15" }, [2592] = { "Humanoids lvl 15-25" }, [4306] = { "Humanoids lvl 25-35" },
    [4338] = { "Humanoids lvl 35-45" }, [14047] = { "Humanoids lvl 48-60" },
    [2320] = { "Trade / tailoring supply vendors", vendor = true },
    [2321] = { "Trade / tailoring supply vendors", vendor = true },
    [4291] = { "Trade / tailoring supply vendors", vendor = true },
    [8343] = { "Trade / tailoring supply vendors", vendor = true },
    [14341] = { "Tailoring supply vendors (not sold in Theramore!)", vendor = true },
    [6260] = { "Trade / tailoring supply vendors", vendor = true },
    [2604] = { "Trade / tailoring supply vendors", vendor = true },
    [4234] = { "Skinning / Auction House" }, [8170] = { "Skinning / Auction House" },
    [14227] = { "Spiders lvl 50+ / Auction House" }, [3577] = { "Mining / Auction House" },
    [7910] = { "Mining / Auction House" }, [7080] = { "Water elementals / Auction House" },
    [7082] = { "Air elementals / Auction House" },
    [247786] = { "Enchanting supply vendor next to the trainer", vendor = true },
    [6217] = { "Enchanting or trade supply vendor", vendor = true },
    [4470] = { "Trade supply vendors", vendor = true },
    [17034] = { "Jeeda (Sun Rock, H) / Dawn Brightstar (Tower of Azora, A)", vendor = true },
    [17035] = { "Reagent vendors", vendor = true },
    [3372] = { "Alchemy supply vendors / Kulwia (Sun Rock) / Dawn Brightstar", vendor = true },
    [8925] = { "Alchemy supply vendors / Mishta (Silithus)", vendor = true },
    [6338] = { "Blacksmiths / Auction House" }, [11128] = { "Blacksmiths / Auction House" },
    [11144] = { "Blacksmiths / Auction House" }, [16206] = { "Blacksmiths / Auction House" },
    [1210] = { "Mining / Auction House" }, [5500] = { "Clams / Auction House" },
    [7971] = { "Clams / Auction House" }, [13926] = { "Clams / Auction House" },
    [8831] = { "Herbalism / Auction House" }, [4625] = { "Herbalism / Auction House" },
}
for _, id in ipairs({ 10940, 11083, 11137, 11176, 16204, 10938, 10939, 10998, 11082, 11134, 11135,
                      11174, 11175, 16202, 16203, 10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344 }) do
    ns.SOURCES[id] = { "Disenchant greens / Auction House" }
end
-- Bolts are made, not bought (but the AH sometimes has them cheaper).
for _, id in ipairs({ 2996, 2997, 4305, 4339, 14048 }) do ns.SOURCES[id] = { "Craft from cloth (or Auction House)" } end

ns.ALL_ITEM_IDS = {}
for id in pairs(ns.ITEM_NAMES) do table.insert(ns.ALL_ITEM_IDS, id) end
