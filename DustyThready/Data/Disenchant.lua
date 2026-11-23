-- DustyThready: what disenchanting gives (WoW Forever, wow-professions.com).
-- Rows are by the item's REQUIRED level ("Requires Level" on the tooltip),
-- not its item level. You can disenchant anything from Enchanting skill 1.
--   dust/essence = { itemID, min, max }, shard = itemID, crystal = itemID
local _, ns = ...

ns.DE_ROWS = {
    { lo = 1,  hi = 10, dust = { 10940, 1, 2 }, essence = { 10938, 1, 2 }, shard = 10978, noShardFromGreens = true },
    { lo = 11, hi = 15, dust = { 10940, 2, 3 }, essence = { 10939, 1, 2 }, shard = 10978 },
    { lo = 16, hi = 20, dust = { 10940, 4, 6 }, essence = { 10998, 1, 2 }, shard = 10978 },
    { lo = 21, hi = 25, dust = { 11083, 1, 2 }, essence = { 11082, 1, 2 }, shard = 11084 },
    { lo = 26, hi = 30, dust = { 11083, 2, 5 }, essence = { 11134, 1, 2 }, shard = 11138 },
    { lo = 31, hi = 35, dust = { 11137, 1, 2 }, essence = { 11135, 1, 2 }, shard = 11139 },
    { lo = 36, hi = 40, dust = { 11137, 2, 5 }, essence = { 11174, 1, 2 }, shard = 11177 },
    { lo = 41, hi = 45, dust = { 11176, 1, 2 }, essence = { 11175, 1, 2 }, shard = 11178 },
    { lo = 46, hi = 50, dust = { 11176, 2, 5 }, essence = { 16202, 1, 2 }, shard = 14343 },
    { lo = 51, hi = 55, dust = { 16204, 1, 2 }, essence = { 16203, 1, 2 }, shard = 14344, crystal = 20725 },
    { lo = 56, hi = 60, dust = { 16204, 2, 5 }, essence = { 16203, 1, 3 }, shard = 14344, crystal = 20725 },
}

-- Chances by kind of item (green = uncommon).
ns.DE_ODDS = {
    armor  = { dust = 0.75, essence = 0.20, shard = 0.05 },
    weapon = { dust = 0.20, essence = 0.75, shard = 0.05 },
}
ns.DE_RARE_CRYSTAL = 0.005 -- blue items, level 51+

-- Equipment slots that can never be disenchanted.
ns.DE_NEVER_SLOTS = {
    INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true,
    INVTYPE_AMMO = true, INVTYPE_THROWN = false,
}
