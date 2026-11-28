-- DustyThready: selling your Enchanting through the trade window.
--
-- The customer opens a trade and puts their item in the bottom slot
-- ("Will not be traded", slot 7). We list the enchants you know that fit it,
-- with mats, what you're short of and a fair tip. Applying one is the classic
-- flow: CraftRecipe starts the enchant (the cursor waits for a target), then
-- ClickTargetTradeButton(7) drops it on their item. CraftEnchant needs an
-- ItemLocation, which only exists for your own bags and equipment, so it
-- can't target a trade slot. If the cursor doesn't wait for a target, the
-- player finishes by hand (we open the recipe and say what to click).
local _, ns = ...
local L = ns.L

local TRADE_ITEM_SLOT = 7  -- "Will not be traded"
local TRADE_SLOTS = 6      -- the other player's tradable slots
local MENU_MAX = 250       -- chat lines are capped at 255 characters
local GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

local clean = ns.clean

local function say(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1, 0.82, 0.35)
    else
        print(ns.Color("violet", "DustyThready:") .. " " .. msg)
    end
end

local function bagCount(id)
    if not GetItemCount then return 0 end
    local ok, n = pcall(GetItemCount, id) -- bags only: enchanting can't use the bank
    return (ok and clean(n)) or 0
end

local function targeting()
    if not SpellIsTargeting then return false end
    local ok, t = pcall(SpellIsTargeting)
    return ok and clean(t) and true or false
end

---------------------------------------------------------------------------
-- Roadmap data: fallback names and mats per recipe spell
---------------------------------------------------------------------------
local stepNames, stepMats, stepOrder
local function roadmap()
    if stepNames then return end
    stepNames, stepMats, stepOrder = {}, {}, {}
    local steps = {}
    for _, s in ipairs(ns.ENCHANTING or {}) do
        table.insert(steps, s)
        for _, a in ipairs(s.alts or {}) do table.insert(steps, a) end
    end
    for _, s in ipairs(steps) do
        if s.spell then
            stepNames[s.spell] = stepNames[s.spell] or s.name
            stepMats[s.spell] = stepMats[s.spell] or s.mats
        end
    end
    table.sort(steps, function(a, b) return (a.from or 0) > (b.from or 0) end)
    for _, s in ipairs(steps) do table.insert(stepOrder, s.spell) end
end

---------------------------------------------------------------------------
-- Enchants you know, best sellers first
---------------------------------------------------------------------------
local function candidates()
    roadmap()
    local seen, out = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            table.insert(out, id)
        end
    end
    for _, id in ipairs(ns.SERVICE_ENCHANTS or {}) do add(id) end
    for _, id in ipairs(ns.POPULAR_ENCHANTS or {}) do add(id) end
    for _, id in ipairs(stepOrder) do add(id) end
    -- Everything else learned (the cache also holds Tailoring recipes: the
    -- name check below drops them). Higher IDs first: roughly higher level.
    local rest = {}
    if ns.char and ns.char.learned then
        for id in pairs(ns.char.learned) do
            if type(id) == "number" and not seen[id] then table.insert(rest, id) end
        end
    end
    table.sort(rest, function(a, b) return a > b end)
    for _, id in ipairs(rest) do add(id) end
    return out
end

-- { spell, name, key = "Bracer" (localized label), slotKey = "Bracer", short = "Strength",
--   slot = <Craft.lua slot info> }, ...
-- The slot comes from the spell ID (Data\EnchantSlots.lua), the name parser is
-- the fallback, so this works with localized spell names.
function ns.ServiceEnchants()
    local list, seenName = {}, {}
    for _, id in ipairs(candidates()) do
        if ns.KnowsSpell(id) then
            local name = ns.SpellName(id, stepNames[id])
            local slotKey = ns.EnchantSlotKey(id, name)
            local slot = ns.EnchantSlotInfo(slotKey)
            if slot and not seenName[name] then
                seenName[name] = true
                table.insert(list, { spell = id, name = name, key = L[slotKey], slotKey = slotKey,
                                     short = ns.EnchantShort(name), slot = slot })
            end
        end
    end
    return list
end

-- Have we ever seen the Enchanting recipe list? (Else "known" may be incomplete.)
function ns.ServiceScanned()
    return ns.char and ns.char.scanned and ns.char.scanned[ns.SKILL.ENCHANTING] and true or false
end

-- "bracer", "two-handed weapon"... (localized) for an equip location, or nil if no enchant fits it.
function ns.SlotNoun(equipLoc)
    if not equipLoc or equipLoc == "" then return nil end
    for _, key in ipairs(ns.ENCHANT_SLOT_ORDER) do
        local s = ns.EnchantSlotInfo(key)
        if s and s.locs[equipLoc] then return L[s.noun] end
    end
end

function ns.EnchantsFor(equipLoc)
    local out = {}
    if not equipLoc then return out end
    for _, e in ipairs(ns.ServiceEnchants()) do
        if e.slot.locs[equipLoc] then table.insert(out, e) end
    end
    return out
end

---------------------------------------------------------------------------
-- Mats: from the game's recipe data, else from our roadmap
---------------------------------------------------------------------------
local matsCache = {}
function ns.EnchantMats(spell)
    if matsCache[spell] then return matsCache[spell] end
    local list = {}
    local t = C_TradeSkillUI
    if t and t.GetRecipeSchematic then
        local ok, sch = pcall(t.GetRecipeSchematic, spell, false)
        if ok and type(sch) == "table" and type(sch.reagentSlotSchematics) == "table" then
            local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
            for _, slot in ipairs(sch.reagentSlotSchematics) do
                local r = type(slot.reagents) == "table" and slot.reagents[1]
                local need = clean(slot.quantityRequired)
                local required = slot.required or (basic ~= nil and slot.reagentType == basic)
                if r and r.itemID and type(need) == "number" and need > 0 and required then
                    table.insert(list, { r.itemID, need })
                end
            end
        end
    end
    if #list == 0 then
        roadmap()
        for _, m in ipairs(stepMats[spell] or {}) do table.insert(list, { m[1], m[2] }) end
    end
    if #list > 0 then matsCache[spell] = list end
    return list
end

---------------------------------------------------------------------------
-- The trade window
---------------------------------------------------------------------------
local function itemID(link)
    local id = type(link) == "string" and link:match("item:(%d+)")
    return id and tonumber(id)
end

local function targetLink(i)
    if not GetTradeTargetItemLink then return nil end
    local ok, link = pcall(GetTradeTargetItemLink, i)
    link = ok and clean(link)
    if type(link) == "string" and link ~= "" then return link end
end

-- The item in their "Will not be traded" slot:
-- { link, id, equipLoc, icon, enchantment = pending enchant name or nil }, or nil.
function ns.TradeItem()
    local link = targetLink(TRADE_ITEM_SLOT)
    if not link then return nil end
    local it = { link = link, id = itemID(link) }
    if GetItemInfoInstant then
        local ok, _, _, _, equipLoc, icon = pcall(GetItemInfoInstant, link)
        if ok then it.equipLoc, it.icon = clean(equipLoc), clean(icon) end
    end
    if not it.equipLoc then
        local info = ns.ItemInfo(link)
        if info then it.equipLoc, it.icon = info.equipLoc, info.icon end
    end
    if GetTradeTargetItemInfo then
        local ok, _, _, _, _, _, enchantment = pcall(GetTradeTargetItemInfo, TRADE_ITEM_SLOT)
        enchantment = ok and clean(enchantment)
        if type(enchantment) == "string" and enchantment ~= "" then it.enchantment = enchantment end
    end
    return it
end

-- What they put in the tradable slots: itemID -> count (yours once the trade goes through).
function ns.TradeOffered()
    local out = {}
    for i = 1, TRADE_SLOTS do
        local id = itemID(targetLink(i))
        if id then
            local n = 1
            if GetTradeTargetItemInfo then
                local ok, _, _, q = pcall(GetTradeTargetItemInfo, i)
                q = ok and clean(q)
                if type(q) == "number" and q > 0 then n = q end
            end
            out[id] = (out[id] or 0) + n
        end
    end
    return out
end

-- The game's own label of the bottom trade slot ("Will not be traded").
function ns.NotTradedLabel()
    local g = _G.TRADE_FRAME_WILL_NOT_BE_TRADED or _G.WILL_NOT_BE_TRADED
    if type(g) == "string" and g ~= "" then return g end
    return L["Will not be traded"]
end

-- Trade partner as a whisper target ("Name" or "Name-Realm"), or nil.
function ns.TradePartner()
    local ok, name, realm = pcall(UnitName, "NPC")
    name, realm = ok and clean(name), ok and clean(realm)
    if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
    if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm:gsub("%s", "") end
    return name
end

---------------------------------------------------------------------------
-- Price and tip
---------------------------------------------------------------------------
-- About 15% of the mats, rounded to 5s / 50s / 1g, at least 10s.
function ns.NiceTip(cost)
    if not cost or cost <= 0 then return nil end
    local t = cost * 0.15
    local step
    if t < 10000 then step = 500
    elseif t < 100000 then step = 5000
    else step = 10000 end
    t = math.floor(t / step + 0.5) * step
    return math.max(t, 1000)
end

-- { mats = { {id, need, have} }, short = { {id, n, offered, bank} }, cost, tip }
function ns.ServiceQuote(e, offered)
    local q = { mats = {}, short = {} }
    local cost, priced = 0, true
    for _, m in ipairs(ns.EnchantMats(e.spell)) do
        local id, need = m[1], m[2]
        local have = bagCount(id)
        table.insert(q.mats, { id = id, need = need, have = have })
        if have < need then
            table.insert(q.short, { id = id, n = need - have, offered = offered and offered[id] or 0,
                                    bank = math.max(0, ns.Count(id) - have) })
        end
        local p = ns.AHPrice(id)
        if p then cost = cost + p * need else priced = false end
    end
    if priced and #q.mats > 0 then
        q.cost = cost
        q.tip = ns.NiceTip(cost)
    end
    return q
end

---------------------------------------------------------------------------
-- "Post my menu": one chat line, grouped by slot, best sellers first
---------------------------------------------------------------------------
local function renderMenu(prefix, groups)
    local parts = {}
    for _, g in ipairs(groups) do
        if #g.items > 0 then table.insert(parts, g.key .. " " .. table.concat(g.items, "/")) end
    end
    if #parts == 0 then return nil end
    return prefix .. L["Enchanting: %s. Your mats, tips welcome!"]:format(table.concat(parts, ", "))
end

-- prefix: "/w Name " or "/2 " (the player presses Enter themselves).
function ns.ServiceMenu(prefix)
    prefix = prefix or ""
    local groups, byKey = {}, {}
    local line
    for _, e in ipairs(ns.ServiceEnchants()) do
        local g = byKey[e.key]
        if not g then
            g = { key = e.key, items = {} }
            byKey[e.key] = g
            table.insert(groups, g)
        end
        table.insert(g.items, e.short)
        local try = renderMenu(prefix, groups)
        if try and #try <= MENU_MAX then
            line = try
        else
            table.remove(g.items) -- doesn't fit: skip it, a shorter one later may
        end
    end
    return line
end

---------------------------------------------------------------------------
-- The click: enchant their item
---------------------------------------------------------------------------
-- Returns nothing; tells the player what happened (or what to do) on screen.
function ns.DoTradeEnchant(e)
    if InCombatLockdown() then say(L["You can enchant after combat."]) return end
    local t = C_TradeSkillUI
    if not (t and t.CraftRecipe) then say(L["Enchanting from here isn't supported by this game client."]) return end
    if not ns.TradeItem() then
        say(L["Ask them to put the item in the bottom slot (%s) first."]:format(ns.NotTradedLabel()))
        return
    end
    -- CraftRecipe only works while Enchanting is open. Opening it takes a
    -- moment, so this click only opens it (same rule as the Craft button).
    if not ns.ProfessionOpen("enchanting") then
        if t.OpenTradeSkill then pcall(t.OpenTradeSkill, ns.SKILL.ENCHANTING) end
        say(L["Enchanting is open: click the enchant again."])
        return
    end
    if targeting() and SpellStopTargeting then pcall(SpellStopTargeting) end

    local ok = pcall(t.CraftRecipe, e.spell, 1)
    if ok and targeting() and ClickTargetTradeButton then
        pcall(ClickTargetTradeButton, TRADE_ITEM_SLOT)
        if not targeting() then return end -- applied (the game may ask before replacing an enchant)
    end
    if ok and targeting() then
        say(L["Now click their item in the trade window (the %s slot)."]:format(ns.NotTradedLabel()))
        return
    end
    -- The enchant didn't start waiting for a target: let the player do it by hand.
    if t.OpenRecipe then pcall(t.OpenRecipe, e.spell) end
    say(L["Press Enchant in the Enchanting window, then click their item in the trade window."])
end
