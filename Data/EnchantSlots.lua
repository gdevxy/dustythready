-- DustyThready: which equipment slot each enchant goes on, by recipe spell ID.
-- Spell names are localized ("Enchant Bracer - Strength", "Armschiene -
-- Stärke verzaubern"...), so the slot comes from this table first; parsing the
-- name (Craft.lua, ns.EnchantSlotKey) is only the fallback for enchants that
-- are not listed here. Keys match the slot table in Craft.lua.
local _, ns = ...

local BY_SLOT = {
    ["Bracer"] = {
        7418, 7428, 7457, 7766, 7779, 7782, 7859, 13501, 13536, 13622, 13642, 13646, 13648,
        13661, 13822, 13846, 13931, 13939, 13945, 20008, 20009, 20010, 20011, 23801, 23802,
    },
    ["Chest"] = {
        7420, 7426, 7443, 7748, 7776, 7857, 13538, 13607, 13626, 13640, 13663, 13700, 13858,
        13917, 13941, 20025, 20026, 20028,
    },
    ["Cloak"] = {
        7454, 7771, 7861, 13419, 13421, 13522, 13635, 13657, 13746, 13794, 13882, 20014, 20015,
        25081, 25082, 25083, 25084, 25086,
    },
    ["Boots"] = {
        7863, 7867, 13637, 13644, 13687, 13836, 13890, 13935, 20020, 20023, 20024,
    },
    ["Gloves"] = {
        13612, 13617, 13620, 13698, 13815, 13841, 13868, 13887, 13947, 13948, 20012, 20013,
        25072, 25073, 25074, 25078, 25079, 25080,
    },
    ["Shield"] = {
        13378, 13485, 13631, 13659, 13689, 13817, 13905, 13933, 20016, 20017,
    },
    ["2H Weapon"] = {
        7745, 7793, 13380, 13529, 13695, 13937, 20030, 20035, 20036, 27837,
    },
    ["Weapon"] = {
        7786, 7788, 13503, 13653, 13655, 13693, 13898, 13915, 13943, 20029, 20031, 20032, 20033,
        20034, 21931, 22749, 22750, 23799, 23800, 23803, 23804,
    },
}

ns.ENCHANT_SLOT = {}
for slot, ids in pairs(BY_SLOT) do
    for _, id in ipairs(ids) do ns.ENCHANT_SLOT[id] = slot end
end
