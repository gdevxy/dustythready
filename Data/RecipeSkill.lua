-- DustyThready: skill colours of the recipes we use: { orange, yellow, green, grey }.
-- The WoW Forever client does not report recipe colours, so Today and the Roadmap use these
-- (a live reading from the profession window wins when there is one).
-- Tailoring: WoW Forever values from wowhead.com/forever (Forever moved many Tailoring recipes).
-- Enchanting: same as vanilla on Forever; from AtlasLootContinued's data (green halfway).
-- A 0 means unknown.
local _, ns = ...

ns.RECIPE_SKILL = {
    [2402] = { 55, 80, 97, 115 }, -- Woolen Cape
    [2963] = { 0, 25, 37, 50 }, -- Bolt of Linen Cloth
    [2964] = { 55, 70, 77, 85 }, -- Bolt of Woolen Cloth
    [3813] = { 125, 145, 160, 175 }, -- Small Silk Pack
    [3839] = { 100, 110, 115, 120 }, -- Bolt of Silk Cloth
    [3848] = { 85, 110, 127, 145 }, -- Double-stitched Woolen Shoulders
    [3865] = { 140, 145, 147, 150 }, -- Bolt of Mageweave
    [7418] = { 70, 70, 90, 110 }, -- Enchant Bracer - Inferior Stamina
    [7420] = { 15, 70, 90, 110 }, -- Enchant Chest - Inferior Stamina
    [7421] = { 1, 5, 7, 10 }, -- Runed Copper Rod
    [7426] = { 40, 90, 110, 130 }, -- Enchant Chest - Minor Absorption
    [7428] = { 80, 80, 100, 120 }, -- Enchant Bracer - Minor Deflect
    [7457] = { 50, 100, 120, 140 }, -- Enchant Bracer - Minor Stamina
    [7771] = { 90, 110, 130, 150 }, -- Enchant Cloak - Minor Protection
    [7793] = { 100, 130, 150, 170 }, -- Enchant 2H Weapon - Lesser Intellect
    [7795] = { 100, 130, 150, 170 }, -- Runed Silver Rod
    [7863] = { 125, 150, 170, 190 }, -- Enchant Boots - Minor Stamina
    [8760] = { 120, 130, 135, 140 }, -- Azure Silk Hood
    [8776] = { 15, 50, 67, 85 }, -- Linen Belt
    [8791] = { 150, 170, 180, 190 }, -- Crimson Silk Vest
    [8799] = { 160, 180, 190, 200 }, -- Crimson Silk Pantaloons
    [12049] = { 170, 185, 200, 215 }, -- Black Mageweave Leggings
    [12074] = { 190, 205, 220, 235 }, -- Black Mageweave Shoulders
    [12079] = { 195, 210, 225, 240 }, -- Red Mageweave Bag
    [13501] = { 130, 155, 175, 195 }, -- Enchant Bracer - Lesser Stamina
    [13628] = { 150, 175, 195, 215 }, -- Runed Golden Rod
    [13637] = { 160, 180, 200, 220 }, -- Enchant Boots - Lesser Agility
    [13661] = { 180, 200, 220, 240 }, -- Enchant Bracer - Strength
    [13702] = { 200, 220, 240, 260 }, -- Runed Truesilver Rod
    [13746] = { 205, 225, 245, 265 }, -- Enchant Cloak - Greater Defense
    [13815] = { 210, 230, 250, 270 }, -- Enchant Gloves - Agility
    [13939] = { 240, 260, 280, 300 }, -- Enchant Bracer - Greater Strength
    [14807] = { 70, 110, 130, 150 }, -- Greater Magic Wand
    [14809] = { 155, 175, 195, 215 }, -- Lesser Mystic Wand
    [14810] = { 175, 195, 215, 235 }, -- Greater Mystic Wand
    [18401] = { 205, 210, 212, 215 }, -- Bolt of Runecloth
    [18402] = { 210, 225, 240, 255 }, -- Runecloth Belt
    [18405] = { 215, 230, 245, 260 }, -- Runecloth Bag
    [18406] = { 215, 230, 245, 260 }, -- Runecloth Robe
    [18417] = { 230, 245, 260, 275 }, -- Runecloth Gloves
    [18420] = { 230, 245, 260, 275 }, -- Brightcloth Cloak
    [18444] = { 250, 265, 280, 295 }, -- Runecloth Headband
    [18445] = { 255, 270, 285, 300 }, -- Mooncloth Bag
    [18447] = { 270, 285, 300, 315 }, -- Mooncloth Vest
    [18449] = { 260, 275, 290, 305 }, -- Runecloth Shoulders
    [18450] = { 260, 275, 290, 305 }, -- Wizardweave Turban
    [18456] = { 295, 310, 325, 340 }, -- Truefaith Vestments
    [18457] = { 295, 310, 325, 340 }, -- Robe of the Archmage
    [18560] = { 230, 270, 285, 300 }, -- Mooncloth
    [20017] = { 265, 285, 305, 325 }, -- Enchant Shield - Greater Stamina
    [20025] = { 300, 320, 340, 360 }, -- Enchant Chest - Greater Stats
    [20034] = { 300, 320, 340, 360 }, -- Enchant Weapon - Crusader
    [20051] = { 290, 310, 330, 350 }, -- Runed Arcanite Rod
    [22749] = { 300, 320, 340, 360 }, -- Enchant Weapon - Spell Power
    [22750] = { 300, 320, 340, 360 }, -- Enchant Weapon - Healing Power
    [22902] = { 275, 290, 305, 320 }, -- Mooncloth Robe
    [23800] = { 290, 310, 330, 350 }, -- Enchant Weapon - Agility
    [25125] = { 150, 160, 170, 180 }, -- Minor Mana Oil
    [25126] = { 200, 210, 220, 230 }, -- Lesser Wizard Oil
    [25127] = { 250, 260, 270, 280 }, -- Lesser Mana Oil
    [25128] = { 275, 285, 295, 305 }, -- Wizard Oil
    [25129] = { 300, 310, 320, 330 }, -- Brilliant Wizard Oil
    [25130] = { 300, 310, 320, 330 }, -- Brilliant Mana Oil
    [26086] = { 0, 0, 285, 290 }, -- Felcloth Bag
    [1257487] = { 250, 265, 280, 295 }, -- Runecloth Cuffs
}
