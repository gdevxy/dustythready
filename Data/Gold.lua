-- DustyThready: money ideas. Crafts here get a live profit estimate from
-- Auctionator's last AH scan (mats cost vs. sale price, after the 5% cut).
local _, ns = ...

ns.GOLD_CRAFTS = {
    -- Bags: everyone needs them, always.
    { prof = "tailoring", skill = 125, spell = 3813, out = 4245, name = "Small Silk Pack",
      mats = { { 4305, 3 }, { 4234, 2 }, { 2321, 3 } }, why = "10-slot bag: alts and new players buy these daily." },
    { prof = "tailoring", skill = 215, spell = 12079, out = 10051, name = "Red Mageweave Bag",
      mats = { { 4339, 5 }, { 2604, 2 }, { 8343, 2 } }, why = "12-slot bag at a price people can afford." },
    -- Wands: casters level with them.
    { prof = "enchanting", skill = 110, spell = 14807, out = 11288, name = "Greater Magic Wand",
      mats = { { 4470, 1 }, { 10938, 2 } }, why = "Low-level mages, priests and warlocks live on wands." },
    { prof = "enchanting", skill = 155, spell = 14809, out = 11289, name = "Lesser Mystic Wand",
      mats = { { 11291, 1 }, { 11134, 1 }, { 11083, 1 } }, why = "Twink and leveling wand, steady seller." },
    { prof = "enchanting", skill = 175, spell = 14810, out = 11290, name = "Greater Mystic Wand",
      mats = { { 11291, 1 }, { 11135, 1 }, { 11137, 1 } }, why = "Same buyers, higher level." },
    -- Oils: raiders and dungeon casters.
    { prof = "enchanting", skill = 201, spell = 25126, out = 20746, name = "Lesser Wizard Oil",
      mats = { { 11137, 1 }, { 17035, 2 }, { 3372, 1 } }, why = "Cheap spell-power for leveling casters." },
    { prof = "enchanting", skill = 250, spell = 25127, out = 20747, name = "Lesser Mana Oil",
      mats = { { 11176, 1 }, { 8831, 1 }, { 8925, 1 } }, why = "Healers buy these for every raid night." },
    { prof = "enchanting", skill = 275, spell = 25128, out = 20750, name = "Wizard Oil",
      mats = { { 16204, 3 }, { 4625, 2 }, { 8925, 1 } }, why = "Raid consumable: steady weekly demand." },
}
ns.ITEM_NAMES[11291] = "Star Wood"
ns.SOURCES[11291] = { "Trade supply vendors", vendor = true }
ns.ITEM_NAMES[11289] = ns.ITEM_NAMES[11289] or "Lesser Mystic Wand"

-- Bolt vs. raw cloth: sometimes bolts sell for more than the cloth in them
-- (people level tailoring), sometimes less. Checked live.
ns.BOLTS = {
    { bolt = 2996, cloth = 2589, n = 2 }, { bolt = 2997, cloth = 2592, n = 3 },
    { bolt = 4305, cloth = 4306, n = 4 }, { bolt = 4339, cloth = 4338, n = 5 },
    { bolt = 14048, cloth = 14047, n = 5 },
}
