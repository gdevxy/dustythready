-- DustyThready: one-click crafting for the current step.
--
-- How it works on the WoW Forever client (modern C_TradeSkillUI API):
--   * C_TradeSkillUI.CraftRecipe(spellID, n) crafts, but only while that
--     profession is "open" (IsTradeSkillReady + GetBaseProfessionInfo).
--   * C_TradeSkillUI.OpenTradeSkill(skillLine) opens it; the player then clicks
--     Craft once more (crafting needs a click, so we never craft from an event,
--     and crafting in the opening click lets the open cancel a multi-craft).
--   * Enchants that go on an item use CraftEnchant(spellID, 1, nil, itemLocation)
--     with the target the player picked; if that API is missing we cast the
--     recipe and apply it to the target while the spell is waiting for one.
local _, ns = ...
local L = ns.L

local LINE = { tailoring = 197, enchanting = 333 }
local LABEL = { tailoring = "Tailoring", enchanting = "Enchanting" } -- shown through L[]
local NUM_BAGS = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
local GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount

local function T() return C_TradeSkillUI end

function ns.CanCraftAPI()
    local t = T()
    return t and t.CraftRecipe and t.OpenTradeSkill and true or false
end

-- Is this profession's trade skill open and usable right now?
function ns.ProfessionOpen(prof)
    local t = T()
    if not (t and t.IsTradeSkillReady) then return false end
    local ok, ready = pcall(t.IsTradeSkillReady)
    if not ok or not ready then return false end
    if t.GetBaseProfessionInfo then
        local ok2, info = pcall(t.GetBaseProfessionInfo)
        if ok2 and type(info) == "table" and info.professionID then
            return info.professionID == LINE[prof]
        end
        return false
    end
    return true -- can't tell which profession is open: let CraftRecipe decide
end

-- true = learned, false = not learned, nil = can't tell yet.
-- "Not learned" is trusted when the profession is open (the recipe list is live)
-- or when its recipe list was read before (every learned recipe got cached then).
local function knownState(prof, spell)
    if ns.KnowsSpell(spell) then return true end
    if ns.ProfessionOpen(prof) and T().GetRecipeInfo then
        local ok, info = pcall(T().GetRecipeInfo, spell)
        if ok and type(info) == "table" then
            local learned = ns.clean(info.learned)
            if learned ~= nil then return learned and true or false end
        elseif ok then
            return false
        end
    end
    if ns.char and ns.char.scanned and ns.char.scanned[LINE[prof]] then return false end
    return nil
end
ns.RecipeLearnedState = knownState

-- Localized word with an English article ("an Expert"). Translated languages
-- get the word alone: their sentences are written around it in Locales\.
function ns.Article(word)
    word = L[word]
    if ns.IsTranslated() then return word end
    return (word:match("^[AEIOUaeiou]") and "an " or "a ") .. word
end

-- For a recipe a trainer teaches (no pattern/formula): the rank whose trainers
-- teach it and the first trainer for your faction, e.g. Expert + Kitta Firewind.
function ns.RecipeTrainer(prof, step, faction)
    local r = ns.RankForSkill(step.from)
    return r, ns.TrainersFor(prof, r.key, faction)[1]
end

-- How many times the step can be crafted from what's in your bags (not the bank).
function ns.CraftableFromBags(step)
    local n
    for _, m in ipairs(step.mats) do
        local ok, have = pcall(GetItemCount, m[1])
        have = (ok and ns.clean(have)) or 0
        local can = math.floor(have / m[2])
        n = n and math.min(n, can) or can
    end
    return n or 0
end

---------------------------------------------------------------------------
-- Enchant targets
---------------------------------------------------------------------------
-- Slot key -> equip locations and the equipment slots to look at. The keys
-- (and nouns) are English: show them through L[].
local SLOTS = {
    ["Bracer"]    = { locs = { INVTYPE_WRIST = true }, inv = { 9 }, noun = "bracer" },
    ["Chest"]     = { locs = { INVTYPE_CHEST = true, INVTYPE_ROBE = true }, inv = { 5 }, noun = "chest piece" },
    ["Cloak"]     = { locs = { INVTYPE_CLOAK = true }, inv = { 15 }, noun = "cloak" },
    ["Boots"]     = { locs = { INVTYPE_FEET = true }, inv = { 8 }, noun = "pair of boots" },
    ["Gloves"]    = { locs = { INVTYPE_HAND = true }, inv = { 10 }, noun = "pair of gloves" },
    ["Shield"]    = { locs = { INVTYPE_SHIELD = true }, inv = { 17 }, noun = "shield" },
    ["2H Weapon"] = { locs = { INVTYPE_2HWEAPON = true }, inv = { 16 }, noun = "two-handed weapon" },
    ["Weapon"]    = { locs = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
                               INVTYPE_2HWEAPON = true }, inv = { 16, 17 }, noun = "weapon" },
}

ns.ENCHANT_SLOT_ORDER = { "Bracer", "Chest", "Cloak", "Boots", "Gloves", "Shield", "2H Weapon", "Weapon" }

function ns.EnchantSlotInfo(key) return key and SLOTS[key] end

-- Fallback for enchants missing from ns.ENCHANT_SLOT (Data\EnchantSlots.lua):
-- the slot word inside a localized spell name. Lower-case ASCII words, checked
-- in this order ("2H Weapon" before "Weapon": "Zweihandwaffe" contains "waffe").
local SLOT_WORDS = {
    { "2H Weapon", { "2h weapon", "2h-waffe", "zweihand", "arme 2m", "deux mains" } },
    { "Bracer",    { "bracer", "armschiene", "bracelet", "brassard" } },
    { "Chest",     { "chest", "brust", "plastron", "torse" } },
    { "Cloak",     { "cloak", "umhang", "cape" } },
    { "Boots",     { "boots", "stiefel", "bottes" } },
    { "Gloves",    { "gloves", "handschuhe", "gants" } },
    { "Shield",    { "shield", "schild", "bouclier" } },
    { "Weapon",    { "weapon", "waffe", "arme" } },
}
-- A name only counts as an enchant when it looks like one in some language
-- (Tailoring recipes like "Runecloth Gloves" must not match).
local ENCHANT_MARKS = { "^enchant ", " verzaubern$", "^enchantement", "^enchanter " }

-- Slot key ("Bracer", "2H Weapon"...) for an enchant spell, or nil.
function ns.EnchantSlotKey(spell, name)
    local key = spell and ns.ENCHANT_SLOT and ns.ENCHANT_SLOT[spell]
    if key then return key end
    if type(name) ~= "string" then return nil end
    local en = name:match("^Enchant (.-) %- ")
    if en and SLOTS[en] then return en end
    local low = name:lower()
    local isEnchant = false
    for _, mark in ipairs(ENCHANT_MARKS) do
        if low:find(mark) then isEnchant = true break end
    end
    if not isEnchant or not low:find(" %- ") then return nil end
    local head = low:match("^(.-) %- ") or low
    for _, sw in ipairs(SLOT_WORDS) do
        for _, word in ipairs(sw[2]) do
            if head:find(word, 1, true) then return sw[1] end
        end
    end
    return nil
end

-- The effect part of an enchant name: "Strength" from "Enchant Bracer - Strength"
-- (or "Armschiene - Stärke verzaubern"), else the whole name.
function ns.EnchantShort(name)
    if type(name) ~= "string" then return "" end
    local s = name:match("^Enchant .- %- (.+)$")
        or name:match("^.- %- (.+) verzaubern$")
        or name:match("^.- %- (.+)$")
        or name:match("%((.+)%)$")
    return s or name
end

-- Slot info if this step is an enchant that goes on an item, else nil.
function ns.EnchantSlot(step)
    return SLOTS[ns.EnchantSlotKey(step.spell, step.name) or ""]
end

local function itemLocation(c)
    if not ItemLocation then return nil end
    if c.equip then return ItemLocation:CreateFromEquipmentSlot(c.equip) end
    return ItemLocation:CreateFromBagAndSlot(c.bag, c.slot)
end

-- Items you could put this enchant on, best choice first:
-- cheap bag items (grey/white), then what you wear, then other bag items.
function ns.EnchantTargets(step)
    local s = ns.EnchantSlot(step)
    if not s then return nil end
    local list = {}
    for _, inv in ipairs(s.inv) do
        local link = GetInventoryItemLink("player", inv)
        local info = link and ns.ItemInfo(link)
        if info and s.locs[info.equipLoc] then
            table.insert(list, { key = "e" .. inv, equip = inv, link = link, id = GetInventoryItemID("player", inv),
                                 icon = info.icon, quality = info.quality or 1, sell = info.sellPrice or 0, rank = 2 })
        end
    end
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, NUM_BAGS do
            for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
                local ci = C_Container.GetContainerItemInfo(bag, slot)
                local info = ci and ci.hyperlink and ns.ItemInfo(ci.hyperlink)
                if info and s.locs[info.equipLoc] then
                    local q = info.quality or 1
                    table.insert(list, { key = ("b%d:%d"):format(bag, slot), bag = bag, slot = slot, link = ci.hyperlink,
                                         id = ci.itemID, icon = ci.iconFileID or info.icon, quality = q,
                                         sell = info.sellPrice or 0, rank = q <= 1 and 1 or 3 })
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.sell < b.sell
    end)
    return list, s
end

-- The picked target for a recipe (this session only), or the best default.
local picked = {}
function ns.CraftTarget(step)
    local list, s = ns.EnchantTargets(step)
    if not list then return nil end
    local want = picked[step.spell]
    if want then
        for _, c in ipairs(list) do
            if c.key == want.key and c.id == want.id then return c, list, s end
        end
    end
    return list[1], list, s
end

function ns.SetCraftTarget(step, c)
    picked[step.spell] = c and { key = c.key, id = c.id } or nil
end

---------------------------------------------------------------------------
-- State for the Craft button: { enabled, label, tip, n, target, targets, slot }
---------------------------------------------------------------------------
function ns.CraftState(prof, step, crafts, snap)
    local st = { enabled = false, label = L["Craft"] }
    if not ns.CanCraftAPI() then
        st.tip = L["Crafting from here isn't supported by this game client."]
        return st
    end
    local p = snap and snap[prof]
    if p and p.skill >= p.max and p.max < 300 then
        st.label = L["Train first"]
        st.tip = L["Your %s is capped at %d: train the next rank, or crafting won't give skill."]:format(L[LABEL[prof]], p.max)
        return st
    end
    if InCombatLockdown() then
        st.label = L["In combat"]
        st.tip = L["You can craft again after combat."]
        return st
    end
    local learned = knownState(prof, step.spell)
    if learned == nil and not ns.ProfessionOpen(prof) then
        -- Never seen this profession's recipe list: open it first so we know
        -- whether this recipe is learned (the click only opens it, see DoCraft).
        st.enabled = true
        st.label = L["Open"]
        st.tip = L["Opens %s to check you've learned this recipe. Then click again."]:format(L[LABEL[prof]])
        return st
    end
    if learned == false then
        st.label = L["Not learned"]
        local item = step.formula or step.pattern
        if item then
            st.tip = L["Learn it first: %s (see the Where tab)."]:format(ns.ItemName(item))
        else
            local r, t = ns.RecipeTrainer(prof, step, snap and snap.faction)
            st.tip = L["Learn it first from %s %s trainer%s."]:format(ns.Article(r.name), L[LABEL[prof]],
                t and (": " .. t[1] .. ", " .. ns.ZoneName(t[2])) or "")
        end
        return st
    end

    local can = ns.CraftableFromBags(step)
    if can <= 0 then
        st.label = L["Need mats"]
        local miss = {}
        for _, m in ipairs(step.mats) do
            local ok, have = pcall(GetItemCount, m[1])
            have = (ok and ns.clean(have)) or 0
            if have < m[2] then table.insert(miss, ("%d %s"):format(m[2] - have, ns.ItemName(m[1]))) end
        end
        st.tip = L["For one craft you're missing %s. Items in the bank don't count: take them out first."]
            :format(table.concat(miss, ", "))
        return st
    end

    local target, targets, slot = ns.CraftTarget(step)
    st.slot, st.targets, st.target = slot, targets, target
    if slot then
        if not target then
            st.label = L["No target"]
            st.tip = L["Carry or wear a %s to enchant (any old one works)."]:format(L[slot.noun])
            return st
        end
        st.n = 1
        st.enabled = true
        st.label = L["Enchant"]
        st.tip = L["Puts the enchant on the item shown next to this button. Click the item to pick another."] ..
            "\n" .. L["If it already has an enchant, the game asks before replacing it."]
        return st
    end

    st.n = math.max(1, math.min(can, crafts or can))
    st.enabled = true
    st.label = L["Craft ×%d"]:format(st.n)
    st.tip = L["Crafts %d (what you need for this step, as far as your bags allow)."]:format(st.n) ..
        "\n" .. L["Shift-click: craft just one."]
    return st
end

-- Sets up a recipe icon (UI.ItemButton) for linking, and its tooltip hint.
-- Shift-click: the crafted item (the recipe for enchants).
-- Shift-right-click: the pattern/formula you buy, or the recipe if it's trainer-taught.
function ns.SetupRecipeIcon(btn, prof, step)
    btn.spellID = step.spell
    btn.patternID = step.pattern or step.formula
    if btn.patternID then ns.ItemInfo(btn.patternID) end -- warm the cache so the link is ready
    local left = step.out and L["Shift-click: link the item."] or L["Shift-click: link the recipe."]
    local right = btn.patternID and (prof == "tailoring" and L["Shift-right-click: link the pattern."]
        or L["Shift-right-click: link the formula."]) or L["Shift-right-click: link the recipe."]
    btn.extra = ns.Color("gold", left .. "\n" .. right)
    if step.out then btn:SetItem(step.out) else btn:SetSpellIcon(step.spell) end
end

---------------------------------------------------------------------------
-- The click
---------------------------------------------------------------------------
local function say(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1, 0.82, 0.35)
    else
        print(ns.Color("violet", "DustyThready:") .. " " .. msg)
    end
end

local function applyToTarget(c)
    if not (SpellIsTargeting and SpellIsTargeting()) then return end
    if c.equip then PickupInventoryItem(c.equip)
    elseif C_Container and C_Container.PickupContainerItem then C_Container.PickupContainerItem(c.bag, c.slot) end
end

function ns.DoCraft(prof, step, st, one)
    if not (st and st.enabled) then return end
    local t = T()
    -- Never craft in the same click that opens (or switches) the profession:
    -- the open finishes a moment later and closing/switching the trade skill
    -- cancels the rest of a multi-craft, so only the first one would be made.
    if not ns.ProfessionOpen(prof) then
        pcall(t.OpenTradeSkill, LINE[prof])
        say(L["%s is open: click again."]:format(L[LABEL[prof]]))
        return
    end

    if st.slot then
        local c = st.target
        local loc = itemLocation(c)
        if t.CraftEnchant and loc then
            local ok = pcall(t.CraftEnchant, step.spell, 1, nil, loc)
            if ok then return end
        end
        local ok = pcall(t.CraftRecipe, step.spell, 1)
        if ok then applyToTarget(c) end
        return
    end

    local n = one and 1 or st.n
    local ok, err = pcall(t.CraftRecipe, step.spell, n)
    if not ok then say(L["Couldn't craft: %s"]:format(tostring(err))) end
end

-- Keep the buttons honest when the profession window or combat state changes.
for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                      "PLAYER_EQUIPMENT_CHANGED" }) do
    ns:On(ev, function() ns:RequestRefresh() end)
end
