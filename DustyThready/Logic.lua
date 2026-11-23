-- DustyThready: the brains. Pure functions over the data + live game state.
local _, ns = ...

table.insert(ns.ALL_ITEM_IDS, 11291)

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

---------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------
function ns.Steps(prof)
    if prof == "tailoring" then return ns.TAILORING end
    local route = ns.db and ns.db.enchantRoute or "dust"
    local list = {}
    for _, s in ipairs(ns.ENCHANTING) do
        if not s.route or s.route == route then table.insert(list, s) end
    end
    return list
end

function ns.CurrentStep(prof, skill)
    local steps = ns.Steps(prof)
    for i, s in ipairs(steps) do
        if skill < s.to then return s, i, steps end
    end
    return nil, #steps + 1, steps
end

function ns.RemainingCrafts(step, skill)
    if skill <= step.from then return step.count end
    local span = step.to - step.from
    if span <= 0 then return step.count end
    return max(1, ceil(step.count * (step.to - skill) / span))
end

function ns.Mats(step, crafts)
    local out = {}
    for _, m in ipairs(step.mats) do
        local need = m[2] * crafts
        local have = ns.Count(m[1])
        table.insert(out, { id = m[1], need = need, have = have, ok = have >= need })
    end
    return out
end

function ns.StepStatus(step, skill)
    if not skill then return "future" end
    if skill >= step.to then return "done" end
    if skill >= step.from then return "now" end
    return "future"
end

---------------------------------------------------------------------------
-- Training: what rank must the player go learn next?
-- Returns nil, or { rank = RANKS entry, ready = bool, reason = text }
---------------------------------------------------------------------------
function ns.TrainingNeed(prof, snap)
    local p = snap[prof]
    if not p then
        return { rank = ns.RANKS[1], ready = true, notLearned = true }
    end
    for _, r in ipairs(ns.RANKS) do
        if p.max < r.cap then
            if p.skill >= r.at then
                local lvlOK = snap.level >= r.level
                return { rank = r, ready = lvlOK, levelNeeded = (not lvlOK) and r.level or nil }
            end
            return nil
        end
    end
end

-- Rank whose cap covers this skill (to show "Expert" pills etc.)
function ns.RankForSkill(skill)
    for _, r in ipairs(ns.RANKS) do
        if skill < r.cap then return r end
    end
    return ns.RANKS[#ns.RANKS]
end

function ns.TrainersFor(prof, rankKey, faction)
    local list = ns.TRAINERS[prof] and ns.TRAINERS[prof][rankKey] or {}
    local out = {}
    for _, t in ipairs(list) do
        if t[4] == "N" or t[4] == faction then table.insert(out, t) end
    end
    return out
end

---------------------------------------------------------------------------
-- Recipe needs: formula/pattern the player still has to buy for a step
---------------------------------------------------------------------------
function ns.RecipeSource(itemID)
    for _, r in ipairs(ns.RECIPE_SOURCES) do
        if r.item == itemID then return r end
    end
end

function ns.MissingRecipe(step)
    local item = step.formula or step.pattern
    if not item then return nil end
    if ns.KnowsSpell(step.spell) then return nil end
    return item, ns.RecipeSource(item)
end

---------------------------------------------------------------------------
-- Disenchant prediction
-- Returns nil if it can't be disenchanted (or isn't cached yet), else
-- { level, row, outcomes = { {id, lo, hi, chance}, ... }, ev = copper|nil, kind }
---------------------------------------------------------------------------
local function rowFor(level)
    level = max(1, min(60, level))
    for _, r in ipairs(ns.DE_ROWS) do
        if level >= r.lo and level <= r.hi then return r end
    end
    return ns.DE_ROWS[#ns.DE_ROWS]
end
ns.DERowFor = rowFor

function ns.PredictDE(item)
    local info = ns.ItemInfo(item)
    if not info then return nil end
    local q = info.quality or 0
    if q < 2 or q > 4 then return nil end
    local kind
    if info.classID == 2 then kind = "weapon"
    elseif info.classID == 4 then kind = "armor"
    else return nil end
    local loc = info.equipLoc
    if not loc or loc == "" or ns.DE_NEVER_SLOTS[loc] then return nil end

    local level = (info.minLevel and info.minLevel > 0) and info.minLevel or max(1, (info.ilvl or 5) - 5)
    local row = rowFor(level)
    local outcomes = {}
    if q == 2 then
        local odds = ns.DE_ODDS[kind]
        local dust, ess, shard = odds.dust, odds.essence, odds.shard
        if row.noShardFromGreens then
            dust, ess, shard = dust / (dust + ess), ess / (dust + ess), 0
        end
        table.insert(outcomes, { id = row.dust[1], lo = row.dust[2], hi = row.dust[3], chance = dust })
        table.insert(outcomes, { id = row.essence[1], lo = row.essence[2], hi = row.essence[3], chance = ess })
        if shard > 0 then table.insert(outcomes, { id = row.shard, lo = 1, hi = 1, chance = shard }) end
        table.sort(outcomes, function(a, b) return a.chance > b.chance end)
    elseif q == 3 then
        if row.crystal then
            table.insert(outcomes, { id = row.shard, lo = 1, hi = 1, chance = 1 - ns.DE_RARE_CRYSTAL })
            table.insert(outcomes, { id = row.crystal, lo = 1, hi = 1, chance = ns.DE_RARE_CRYSTAL })
        else
            table.insert(outcomes, { id = row.shard, lo = 1, hi = 1, chance = 1 })
        end
    else -- epic
        if level > 50 then
            table.insert(outcomes, { id = 20725, lo = 1, hi = 2, chance = 1 })
        else
            table.insert(outcomes, { id = row.shard, lo = 2, hi = 4, chance = 1 })
        end
    end

    local ev, known = 0, true
    for _, o in ipairs(outcomes) do
        local p = ns.Price(o.id)
        if p then ev = ev + p * o.chance * (o.lo + o.hi) / 2
        elseif o.chance >= 0.1 then known = false end
    end
    return {
        level = level, row = row, kind = kind, quality = q, outcomes = outcomes,
        ev = known and ev or nil, sell = info.sellPrice,
    }
end

-- "75% 1-2 Soul Dust" style text for one outcome.
function ns.OutcomeText(o, withIcon)
    local qty = (o.lo == o.hi) and tostring(o.lo) or (o.lo .. "-" .. o.hi)
    local pct = o.chance >= 0.995 and "" or (o.chance < 0.01 and "<1% " or ("%d%% "):format(floor(o.chance * 100 + 0.5)))
    local icon = withIcon and (ns.IconString(ns.ItemIcon(o.id), 13) .. " ") or ""
    return ns.Color("muted", pct) .. icon .. qty .. " " .. ns.ItemText(o.id)
end

-- Expected number of the main reagent from one disenchant (for planning).
function ns.ExpectedMain(pred)
    local o = pred.outcomes[1]
    return o.id, o.chance * (o.lo + o.hi) / 2
end

---------------------------------------------------------------------------
-- Synergy: which tailoring crafts feed which enchanting steps
---------------------------------------------------------------------------
local function eachTailoringStep(fn)
    for _, s in ipairs(ns.TAILORING) do
        fn(s, false)
        if s.alts then for _, a in ipairs(s.alts) do fn(a, true) end end
    end
end

-- For a tailoring step: { pred, reagent, perCraft, total } or nil.
function ns.StepDE(step)
    if not step.out then return nil end
    local pred = ns.PredictDE(step.out)
    if not pred then return nil end
    local id, per = ns.ExpectedMain(pred)
    return { pred = pred, reagent = id, perCraft = per, total = per * step.count }
end

-- Enchanting steps (in the chosen route) that consume a given reagent.
function ns.EnchantStepsUsing(itemID)
    local out = {}
    for _, s in ipairs(ns.Steps("enchanting")) do
        for _, m in ipairs(s.mats) do
            if m[1] == itemID then table.insert(out, { step = s, need = m[2] * s.count }) break end
        end
    end
    return out
end

-- Tailoring steps whose crafts disenchant mainly into itemID.
function ns.TailoringSourcesOf(itemID)
    local out = {}
    eachTailoringStep(function(s, isAlt)
        local de = ns.StepDE(s)
        if de and de.reagent == itemID then table.insert(out, { step = s, de = de, alt = isAlt }) end
    end)
    return out
end

-- Total of an item still needed by the remaining steps of a profession.
function ns.RemainingNeed(prof, skill, itemID)
    local total = 0
    for _, s in ipairs(ns.Steps(prof)) do
        if skill < s.to then
            local crafts = ns.RemainingCrafts(s, skill)
            for _, m in ipairs(s.mats) do
                if m[1] == itemID then total = total + m[2] * crafts end
            end
        end
    end
    return total
end

-- The main reagent of an enchanting step (the dust/essence it eats most).
function ns.KeyReagent(step)
    local best, bestN
    for _, m in ipairs(step.mats) do
        local src = ns.SOURCES[m[1]]
        if src and src[1]:find("Disenchant") and (not bestN or m[2] > bestN) then best, bestN = m[1], m[2] end
    end
    return best
end

---------------------------------------------------------------------------
-- Bags: things worth disenchanting
---------------------------------------------------------------------------
local NUM_BAGS = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)

function ns.ScanBags()
    local out = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return out end
    for bag = 0, NUM_BAGS do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not ns.db.ignoredDE[info.itemID] then
                local pred = ns.PredictDE(info.hyperlink or info.itemID)
                if pred then
                    table.insert(out, { bag = bag, slot = slot, id = info.itemID, link = info.hyperlink,
                                        icon = info.iconFileID, pred = pred, count = info.stackCount or 1 })
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.pred.quality ~= b.pred.quality then return a.pred.quality > b.pred.quality end
        return a.pred.level > b.pred.level
    end)
    return out
end

-- Expected totals per reagent from a list of bag candidates.
function ns.ExpectedTotals(list)
    local totals, order = {}, {}
    for _, e in ipairs(list) do
        for _, o in ipairs(e.pred.outcomes) do
            if not totals[o.id] then totals[o.id] = 0 table.insert(order, o.id) end
            totals[o.id] = totals[o.id] + o.chance * (o.lo + o.hi) / 2
        end
    end
    table.sort(order, function(a, b) return totals[a] > totals[b] end)
    return totals, order
end

---------------------------------------------------------------------------
-- Money: craft profit from Auctionator prices
---------------------------------------------------------------------------
local AH_CUT = 0.95

-- Returns { cost, sale, profit } (any may be nil when prices are unknown).
function ns.CraftProfit(craft)
    local cost = 0
    for _, m in ipairs(craft.mats) do
        local p = ns.Price(m[1])
        local src = ns.SOURCES[m[1]]
        if not p then cost = nil break end
        -- Vendor-bought supplies: the vendor buy price is ~4x the sell price.
        if src and src.vendor then
            local _, s = ns.Price(m[1])
            if s == "vendor" then p = p * 4 end
        end
        cost = cost + p * m[2]
    end
    local sale = ns.AHPrice(craft.out)
    local profit = (cost and sale) and (sale * AH_CUT - cost) or nil
    return { cost = cost, sale = sale, profit = profit }
end
