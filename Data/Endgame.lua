-- DustyThready: what to do once a profession is nearly done (250-300).
-- Mooncloth, crafts that pay at 300, and the famous patterns/formulas with
-- where they come from. Recipe/item IDs checked on wowhead.com/forever;
-- sources marked "UNSURE" come from vanilla knowledge and were not
-- confirmed for Forever (Forever moved some skill levels and sources).
local _, ns = ...

-- Mooncloth: 2 Felcloth -> 1 Mooncloth, with a long per-character cooldown.
-- Wowhead Forever shows "Cooldown: 3.958 days" (= 95 h); guides say "4 days".
-- The live cooldown is read from the game when it can be; this is only the
-- fallback used right after a craft. Mooncloth's cooldown is its own (not
-- shared with anything else on this client as far as we know).
ns.MOONCLOTH = {
    spell = 18560, item = 14342, felcloth = 14256, pattern = 14526, skill = 250,
    cooldown = 95 * 3600,
    vendor = "Qia", where = "Everlook, Winterspring",
}

-- Crafts that pay at the top (same shape as ns.GOLD_CRAFTS: live profit via ns.CraftProfit).
ns.ENDGAME_CRAFTS = {
    { prof = "tailoring", skill = 250, spell = 18560, out = 14342, name = "Mooncloth",
      mats = { { 14256, 2 } }, why = "Every Mooncloth recipe needs it. One per tailor every 4 days: craft it on cooldown." },
    -- UNSURE: skill 260 is the vanilla value; the Forever wiki may list it lower.
    { prof = "tailoring", skill = 260, spell = 18405, out = 14046, name = "Runecloth Bag",
      mats = { { 14048, 5 }, { 8170, 2 }, { 14341, 1 } }, why = "14-slot bag: what every level 50+ player wants." },
    { prof = "tailoring", skill = 255, spell = 18445, out = 14155, name = "Mooncloth Bag",
      mats = { { 14048, 4 }, { 14342, 1 }, { 14341, 1 } }, why = "16-slot bag. Turns one Mooncloth into a lot of gold." },
    { prof = "enchanting", skill = 300, spell = 25129, out = 20749, name = "Brilliant Wizard Oil",
      mats = { { 14344, 2 }, { 4625, 3 }, { 18256, 1 } }, why = "Raid casters burn these every week." },
    { prof = "enchanting", skill = 300, spell = 25130, out = 20748, name = "Brilliant Mana Oil",
      mats = { { 14344, 2 }, { 8831, 3 }, { 18256, 1 } }, why = "Healers' raid oil: steady demand." },
}

-- Patterns and formulas worth chasing. src = "Vendor" | "Drop" | "Trainer" | "Quest"
-- npc = name in ns.NPC_COORDS (becomes a map link) when we have it.
-- Skill values for tailoring follow the warcraft.wiki.gg "Forever tailoring patterns" table.
ns.ENDGAME_PATTERNS = {
    tailoring = {
        { spell = 18560, out = 14342, name = "Mooncloth", skill = 250, src = "Vendor", npc = "Qia",
          where = "Everlook, Winterspring (limited stock)" },
        { spell = 18405, out = 14046, name = "Runecloth Bag", skill = 260, src = "Vendor", npc = "Qia",
          where = "Everlook, Winterspring (limited stock)" },
        { spell = 18445, out = 14155, name = "Mooncloth Bag", skill = 255, src = "Drop",
          where = "World drop, check the AH" },
        { spell = 18447, out = 14138, name = "Mooncloth Vest", skill = 270, src = "Drop",
          where = "World drop, check the AH" },
        { spell = 22902, out = 18486, name = "Mooncloth Robe", skill = 275, src = "Vendor", npc = "Shen'dralar Provisioner",
          where = "Dire Maul, Capital Gardens" },
        -- UNSURE: the drop source for Forever is unknown.
        { spell = 26086, out = 21341, name = "Felcloth Bag", skill = 285, src = "Drop",
          where = "Rare drop, check the AH (warlocks pay well)" },
        { spell = 18457, out = 14152, name = "Robe of the Archmage", skill = 295, src = "Drop",
          where = "Firebrand Pyromancers, Lower Blackrock Spire" },
        { spell = 18456, out = 14154, name = "Truefaith Vestments", skill = 295, src = "Drop",
          where = "Balnazzar, Stratholme" },
        -- UNSURE: trainer-taught in vanilla (Artisan); Forever may differ.
        { spell = 18406, out = 13858, name = "Runecloth Robe", skill = 260, src = "Trainer",
          where = "Artisan Tailoring trainer" },
    },
    enchanting = {
        { spell = 20034, name = "Enchant Weapon - Crusader", short = "+100 Strength and heal procs", skill = 300, src = "Drop",
          where = "Scarlet Archmages & Praetorians, Tyr's Hand (Eastern Plaguelands)" },
        -- UNSURE: reputation level needed (Honored in vanilla, we think).
        { spell = 23800, name = "Enchant Weapon - Agility", short = "+15 Agility", skill = 290, src = "Vendor", npc = "Meilosh",
          where = "Timbermaw Hold, Felwood (Timbermaw reputation)" },
        -- UNSURE: vanilla rare drop; exact source not confirmed for Forever.
        { spell = 20025, name = "Enchant Chest - Greater Stats", short = "+4 all stats", skill = 300, src = "Drop",
          where = "Rare drop from level 55+ mobs, check the AH" },
        { spell = 22749, name = "Enchant Weapon - Spell Power", short = "+30 spell damage", skill = 300, src = "Drop",
          where = "Molten Core trash" },
        { spell = 22750, name = "Enchant Weapon - Healing Power", short = "+55 healing", skill = 300, src = "Drop",
          where = "Molten Core trash" },
    },
}

-- Fallback names (until the client caches the items) + warm the item cache at login.
local NAMES = {
    [14342] = "Mooncloth", [14256] = "Felcloth", [14526] = "Pattern: Mooncloth",
    [14046] = "Runecloth Bag", [14155] = "Mooncloth Bag", [21341] = "Felcloth Bag",
    [18486] = "Mooncloth Robe", [14138] = "Mooncloth Vest", [14152] = "Robe of the Archmage",
    [14154] = "Truefaith Vestments", [13858] = "Runecloth Robe",
    [20749] = "Brilliant Wizard Oil", [20748] = "Brilliant Mana Oil", [18256] = "Imbued Vial",
}
for id, name in pairs(NAMES) do
    if not ns.ITEM_NAMES[id] then
        ns.ITEM_NAMES[id] = name
        table.insert(ns.ALL_ITEM_IDS, id)
    end
end
ns.SOURCES[14256] = ns.SOURCES[14256] or { "Satyrs and demons lvl 50+ (Felwood, Dire Maul) / Auction House" }
ns.SOURCES[14342] = ns.SOURCES[14342] or { "Tailors (2 Felcloth, 4-day cooldown) / Auction House" }
