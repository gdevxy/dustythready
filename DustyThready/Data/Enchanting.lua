-- DustyThready: Enchanting 1-300 (WoW Forever), after wow-professions.com's
-- Forever guide. Two routes between 20 and 150:
--   route "dust"    = Strange Dust     (what disenchanting armor gives most)
--   route "essence" = Lesser Magic Essence (what disenchanting weapons gives most)
-- Steps without a route are shared. formula = the recipe item you must buy.
local _, ns = ...

ns.ENCHANTING = {
    { from = 1, to = 2, spell = 7421, name = "Runed Copper Rod", out = 6218, count = 1,
      mats = { { 6217, 1 }, { 247786, 1 } },
      tip = "Motes of Magic are only sold by Enchanting vendors (in starting zones: Zephras Isle and Tirisfal)." },
    { from = 2, to = 20, spell = 7418, name = "Enchant Bracer - Inferior Stamina", count = 18,
      mats = { { 247786, 1 } }, tip = "Enchant your own bracers over and over. Forever made these first points cheap!" },
    { from = 20, to = 70, spell = 7420, name = "Enchant Chest - Inferior Stamina", count = 50, route = "dust",
      mats = { { 10940, 1 } } },
    { from = 20, to = 70, spell = 7428, name = "Enchant Bracer - Minor Deflect", count = 50, route = "essence",
      mats = { { 10938, 1 } }, tip = "Right-click a Greater Magic Essence to split it into 3 Lesser." },

    -- Journeyman
    { from = 70, to = 85, spell = 7420, name = "Enchant Chest - Inferior Stamina", count = 21, route = "dust",
      mats = { { 10940, 1 } }, rank = "journeyman" },
    { from = 85, to = 100, spell = 7457, name = "Enchant Bracer - Minor Stamina", count = 15, route = "dust",
      mats = { { 10940, 2 } } },
    { from = 100, to = 109, spell = 7771, name = "Enchant Cloak - Minor Protection", count = 9, route = "dust",
      mats = { { 10940, 2 } } },
    { from = 70, to = 109, spell = 7426, name = "Enchant Chest - Minor Absorption", count = 49, route = "essence",
      mats = { { 10938, 1 } }, rank = "journeyman" },
    { from = 109, to = 110, spell = 7795, name = "Runed Silver Rod", out = 6339, count = 1,
      mats = { { 6338, 1 }, { 10940, 3 }, { 10938, 4 }, { 1210, 1 } },
      tip = "Silver Rods are made by Blacksmiths: check the Auction House." },
    { from = 110, to = 130, spell = 7771, name = "Enchant Cloak - Minor Protection", count = 29, route = "dust",
      mats = { { 10940, 2 } }, tip = "Yellow the whole way." },
    { from = 130, to = 150, spell = 7863, name = "Enchant Boots - Minor Stamina", count = 20, route = "dust",
      mats = { { 10940, 4 } },
      alts = { { from = 130, to = 150, spell = 13501, name = "Enchant Bracer - Lesser Stamina", count = 20,
                 mats = { { 11083, 1 } }, tip = "Cheaper if 20 Soul Dust cost less than 80 Strange Dust." } } },
    { from = 110, to = 125, spell = 14807, name = "Greater Magic Wand", out = 11288, count = 23, route = "essence",
      mats = { { 4470, 1 }, { 10938, 2 } }, tip = "Wands sell to low-level casters: don't vendor them!" },
    { from = 125, to = 150, spell = 7793, name = "Enchant 2H Weapon - Lesser Intellect", count = 37, route = "essence",
      mats = { { 10938, 4 } }, formula = 6349,
      alts = { { from = 125, to = 150, spell = 7863, name = "Enchant Boots - Minor Stamina", count = 25,
                 mats = { { 10940, 4 } } } } },

    -- Expert
    { from = 150, to = 151, spell = 13628, name = "Runed Golden Rod", out = 11130, count = 1,
      mats = { { 11128, 1 }, { 5500, 1 }, { 11082, 1 }, { 11083, 1 } }, rank = "expert" },
    { from = 151, to = 165, spell = 25125, name = "Minor Mana Oil", out = 20745, count = 16,
      mats = { { 11083, 1 }, { 17034, 2 }, { 3372, 1 } }, formula = 20752,
      tip = "Buy the Lesser Wizard Oil formula at the same time." },
    { from = 165, to = 200, spell = 13637, name = "Enchant Boots - Lesser Agility", count = 44,
      mats = { { 11083, 1 } }, tip = "Yellow from 180: make a few extra if you're short.",
      alts = { { from = 185, to = 200, spell = 13661, name = "Enchant Bracer - Strength", count = 15,
                 mats = { { 11137, 1 } }, tip = "Cheaper if 2 Vision Dust cost less than 3 Soul Dust." } } },
    { from = 200, to = 201, spell = 13702, name = "Runed Truesilver Rod", out = 11145, count = 1,
      mats = { { 11144, 1 }, { 7971, 1 }, { 11135, 1 }, { 11137, 1 } } },
    { from = 201, to = 220, spell = 25126, name = "Lesser Wizard Oil", out = 20746, count = 25,
      mats = { { 11137, 1 }, { 17035, 2 }, { 3372, 1 } }, formula = 20753 },
    { from = 220, to = 225, spell = 13746, name = "Enchant Cloak - Greater Defense", count = 5,
      mats = { { 11137, 1 } } },

    -- Artisan
    { from = 225, to = 250, spell = 13815, name = "Enchant Gloves - Agility", count = 34,
      mats = { { 11137, 1 } }, rank = "artisan", tip = "Yellow from 230." },
    { from = 250, to = 270, spell = 25127, name = "Lesser Mana Oil", out = 20747, count = 26,
      mats = { { 11176, 1 }, { 8831, 1 }, { 8925, 1 } }, formula = 20754,
      tip = "Buy the Wizard Oil formula from Kania at the same time.",
      alts = { { from = 250, to = 270, spell = 13939, name = "Enchant Bracer - Greater Strength", count = 23,
                 mats = { { 11176, 1 }, { 11174, 2 } } } } },
    { from = 270, to = 275, spell = 20017, name = "Enchant Shield - Greater Stamina", count = 5,
      mats = { { 11176, 6 } }, formula = 16217 },
    { from = 275, to = 295, spell = 25128, name = "Wizard Oil", out = 20750, count = 26,
      mats = { { 16204, 3 }, { 4625, 2 }, { 8925, 1 } }, formula = 20755,
      tip = "If Illusion Dust is pricey, make Greater Stamina shields instead.",
      alts = { { from = 275, to = 295, spell = 20017, name = "Enchant Shield - Greater Stamina", count = 23,
                 mats = { { 11176, 6 } } } } },
    { from = 295, to = 299, spell = 20017, name = "Enchant Shield - Greater Stamina", count = 8,
      mats = { { 11176, 6 } } },
    { from = 299, to = 300, spell = 20051, name = "Runed Arcanite Rod", out = 16207, count = 1,
      mats = { { 16206, 1 }, { 13926, 1 }, { 16204, 10 }, { 16203, 4 }, { 14343, 4 }, { 14344, 2 } },
      formula = 16243, tip = "Needed for most 300 enchants (Crusader!). Otherwise one more shield." },
}

-- Enchants people actually ask for in trade chat while leveling, by recipe
-- spell. Used by the "Enchant for tips" card: only the ones you know show.
ns.POPULAR_ENCHANTS = {
    13637, -- Boots - Lesser Agility
    13661, -- Bracer - Strength
    13746, -- Cloak - Greater Defense
    13815, -- Gloves - Agility
    13501, -- Bracer - Lesser Stamina
    7863,  -- Boots - Minor Stamina
    7793,  -- 2H Weapon - Lesser Intellect
    13939, -- Bracer - Greater Strength
    13935, -- Boots - Agility
    13941, -- Chest - Stats
    13943, -- Weapon - Greater Striking
    13937, -- 2H Weapon - Greater Impact
    20017, -- Shield - Greater Stamina
}
