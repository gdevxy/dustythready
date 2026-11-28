-- DustyThready: the brains. Pure functions over the data + live game state.
local _, ns = ...
local L = ns.L

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

---------------------------------------------------------------------------
-- Recipe colour (orange / yellow / green / grey)
--
-- The guide's counts are static. While a profession window is open we read
-- the client's own difficulty for every recipe of our paths and cache it per
-- character (DustyThreadyCharDB.difficulty[spell]):
--   { c = "yellow", at = 152,      -- colour seen, and the skill it was read at
--     y = 150, g = 170, x = 190 }  -- lowest skill seen yellow-or-worse,
--                                  -- green-or-worse and grey (learned thresholds)
-- Colours only get worse as skill rises, so the thresholds tell the colour
-- later without the window open. Without data we show nothing.
---------------------------------------------------------------------------
local RANK = { orange = 1, yellow = 2, green = 3, grey = 4 }
local TH = { [2] = "y", [3] = "g", [4] = "x" }
local BY_RANK = { "orange", "yellow", "green", "grey" }
ns.DIFF_RANK = RANK
-- The colours the game's profession window uses.
ns.DIFF_HEX = { orange = "ff8040", yellow = "ffff00", green = "40bf40", grey = "808080" }

function ns.DiffText(color, text)
    if not (color and ns.DIFF_HEX[color]) then return text or "" end
    return "|cff" .. ns.DIFF_HEX[color] .. (text or L[color]) .. "|r"
end

local pathSpells -- spell -> "tailoring" | "enchanting"
local function buildPathSpells()
    pathSpells = {}
    for prof, list in pairs({ tailoring = ns.TAILORING, enchanting = ns.ENCHANTING }) do
        for _, s in ipairs(list or {}) do
            pathSpells[s.spell] = prof
            if s.alts then
                for _, a in ipairs(s.alts) do pathSpells[a.spell] = prof end
            end
        end
    end
end

-- Colour key from a C_TradeSkillUI.GetRecipeInfo table, or nil.
-- Modern clients: relativeDifficulty (Enum.TradeskillRelativeDifficulty,
-- Optimal 0 / Medium 1 / Easy 2 / Trivial 3); older ones: difficulty strings.
local NUM_COLOR = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }
local NAME_COLOR = { optimal = "orange", medium = "yellow", easy = "green", trivial = "grey" }
local function colorOf(info)
    local rd = ns.clean(info.relativeDifficulty)
    if type(rd) == "number" then
        local E = Enum and Enum.TradeskillRelativeDifficulty
        if type(E) == "table" then
            if E.Optimal ~= nil and rd == E.Optimal then return "orange" end
            if E.Medium ~= nil and rd == E.Medium then return "yellow" end
            if E.Easy ~= nil and rd == E.Easy then return "green" end
            if E.Trivial ~= nil and rd == E.Trivial then return "grey" end
        end
        return NUM_COLOR[rd]
    end
    local d = ns.clean(info.difficulty)
    if type(d) == "string" then return NAME_COLOR[d] end
    if type(d) == "number" then return NUM_COLOR[d] end
    return nil
end

local function record(db, spell, c, skill)
    local e = db[spell]
    if type(e) ~= "table" then e = {} db[spell] = e end
    local changed = (e.c ~= c) or (e.at ~= skill)
    e.c, e.at = c, skill
    local r = RANK[c]
    for k = 2, r do
        local f = TH[k]
        if not e[f] or skill < e[f] then e[f] = skill changed = true end
    end
    -- A better colour at or above a stored threshold: that threshold is stale
    -- (profession dropped and relearned...): forget it.
    for k = r + 1, 4 do
        local f = TH[k]
        if e[f] and e[f] <= skill then e[f] = nil changed = true end
    end
    return changed
end

local function scanColors()
    local t = C_TradeSkillUI
    if not (ns.char and t and t.GetAllRecipeIDs and t.GetRecipeInfo) then return end
    if t.IsTradeSkillReady then
        local okR, ready = pcall(t.IsTradeSkillReady)
        if okR and not ready then return end
    end
    local ok, ids = pcall(t.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return end
    if not pathSpells then buildPathSpells() end
    if type(ns.char.difficulty) ~= "table" then ns.char.difficulty = {} end
    local db = ns.char.difficulty
    local skills, changed = {}, false
    for _, id in ipairs(ids) do
        local prof = pathSpells[id]
        if prof then
            local ok2, info = pcall(t.GetRecipeInfo, id)
            if ok2 and type(info) == "table" and ns.clean(info.learned) then
                local c = colorOf(info)
                if c then
                    if skills[prof] == nil then
                        local p = ns.ProfessionSkill(prof == "tailoring" and "TAILORING" or "ENCHANTING")
                        skills[prof] = (p and p.skill) or false
                    end
                    if skills[prof] and record(db, id, c, skills[prof]) then changed = true end
                end
            end
        end
    end
    if changed then ns:RequestRefresh() end
end

local scanPending = false
local function requestScan(delay)
    if scanPending then return end
    scanPending = true
    C_Timer.After(delay or 0.3, function()
        scanPending = false
        local ok, err = pcall(scanColors)
        if not ok then geterrorhandler()(err) end
    end)
end
ns:On("TRADE_SKILL_SHOW", function() requestScan(0.6) end)
ns:On("TRADE_SKILL_LIST_UPDATE", function() requestScan(0.3) end)
ns:On("SKILL_LINES_CHANGED", function() requestScan(0.5) end)

-- Colour from the static data (Data/RecipeSkill.lua: { orange, yellow, green, grey },
-- 0 = unknown).
local function staticColor(spell, skill)
    local t = ns.RECIPE_SKILL and spell and ns.RECIPE_SKILL[spell]
    if not (t and skill and t[4] and t[4] > 0) then return nil end
    if skill >= t[4] then return "grey" end
    if t[3] > 0 and skill >= t[3] then return "green" end
    if t[2] > 0 and skill >= t[2] then return "yellow" end
    if t[2] > 0 then return "orange" end
    return nil
end
ns.StaticRecipeColor = staticColor

local liveColor
-- Colour of a recipe at a skill level: "orange" | "yellow" | "green" | "grey" | nil,
-- and true when it was read live at exactly this skill. A live reading from the
-- profession window wins; otherwise the static thresholds.
function ns.RecipeColor(spell, skill)
    local c, exact = liveColor(spell, skill)
    if c then return c, exact end
    return staticColor(spell, skill)
end

liveColor = function(spell, skill)
    local db = ns.char and ns.char.difficulty
    local e = db and spell and db[spell]
    if not (type(e) == "table" and e.c and RANK[e.c] and e.at and skill) then return nil end
    if e.at == skill then return e.c, true end
    local cr = RANK[e.c]
    -- Learned thresholds: past one, the colour is at least that bad.
    for k = 4, 2, -1 do
        local th = e[TH[k]]
        if th and skill >= th then
            if skill < e.at then
                -- between threshold k and the reading's colour
                return (cr == k) and BY_RANK[k] or nil
            end
            -- Above the reading it may have got worse since: trust it for a few points (grey stays grey).
            if k == 4 or skill - e.at <= 5 then return BY_RANK[max(k, cr)] end
            return nil
        end
    end
    -- Below every known threshold.
    if skill < e.at then
        return (cr == 1) and "orange" or nil
    end
    -- (Here the reading was orange.) A few points above it: still a good guess.
    if skill - e.at <= 3 then return e.c end
    return nil
end

-- Crafts left for a step, made honest by the recipe colour.
-- Returns n, about (true when scaled up), color.
local YELLOW_PER_POINT, GREEN_PER_POINT = 1.6, 4
function ns.EstimateCrafts(prof, step, skill)
    local base = ns.RemainingCrafts(step, skill or 0)
    local color = skill and ns.RecipeColor(step.spell, skill) or nil
    -- With static thresholds, add up point by point: a recipe that is orange
    -- now may turn yellow and green before the step ends.
    local t = ns.RECIPE_SKILL and ns.RECIPE_SKILL[step.spell]
    if t and skill and color ~= "grey" then
        local est = 0
        for p = max(skill, step.from), step.to - 1 do
            local c = staticColor(step.spell, p)
            if c == "orange" then est = est + 1
            elseif c == "yellow" then est = est + YELLOW_PER_POINT
            elseif c == "green" then est = est + GREEN_PER_POINT
            else break end -- grey: no more skill-ups from this recipe
        end
        est = ceil(est)
        if est > base then return est, true, color end
        return base, false, color
    end
    if color == "yellow" or color == "green" then
        local from = max(skill, step.from)
        local points = max(0, step.to - from)
        local yellowPts, greenPts = points, 0
        if color == "green" then
            yellowPts, greenPts = 0, points
        else
            local e = ns.char and ns.char.difficulty and ns.char.difficulty[step.spell]
            local gAt = type(e) == "table" and e.g or nil
            if gAt and gAt > from and gAt < step.to then
                yellowPts, greenPts = gAt - from, step.to - gAt
            end
        end
        local est = ceil(yellowPts * YELLOW_PER_POINT + greenPts * GREEN_PER_POINT)
        if est > base then return est, true, color end
    end
    return base, false, color
end

---------------------------------------------------------------------------
-- Choosing what to craft now: the guide's step, or one of its alternatives
-- when it's clearly better for you (you know it, it's orange, your bags
-- cover it, or its missing mats are cheaper today).
---------------------------------------------------------------------------
local function knownForSure(prof, s)
    if ns.KnowsSpell(s.spell) then return true end
    return (ns.RecipeLearnedState and ns.RecipeLearnedState(prof, s.spell) == true) or false
end

local function isVendor(id)
    local src = ns.SOURCES and ns.SOURCES[id]
    return src and src.vendor and true or false
end

-- How far bags + bank get you with a step for n crafts:
-- { all, cost (AH copper for what's missing; nil if a price is unknown), key, keyHave }
-- key = the non-vendor mat you hold most of (for "You have 80 Wool Cloth").
local function coverage(s, crafts)
    local res = { all = true, cost = 0 }
    local key, keyHave = nil, -1
    for _, m in ipairs(ns.Mats(s, crafts)) do
        if not isVendor(m.id) and m.have > keyHave then key, keyHave = m.id, m.have end
        if not m.ok then
            res.all = false
            if not isVendor(m.id) then
                local p = ns.AHPrice(m.id)
                if p and res.cost then res.cost = res.cost + p * (m.need - m.have) else res.cost = nil end
            end
        end
    end
    res.key, res.keyHave = key, max(0, keyHave)
    return res
end
ns.StepCoverage = coverage

-- Returns nil when the path is done (or skill unknown), else
-- { main (the guide's step), step (what to craft), idx, steps,
--   reason = nil | "learned" | "color" | "bags" | "cost",
--   crafts, about, color (of step), mainColor, mainCov, cov,
--   grey = true when the guide's recipe is grey and nothing better is known }
function ns.ChooseStep(prof, skill)
    if not skill then return nil end
    local main, idx, steps = ns.CurrentStep(prof, skill)
    if not main then return nil end
    local res = { main = main, step = main, idx = idx, steps = steps }
    local mainColor = ns.RecipeColor(main.spell, skill)
    res.mainColor = mainColor

    local alts = {}
    for _, a in ipairs(main.alts or {}) do
        if a.to > skill and a.spell ~= main.spell then table.insert(alts, a) end
    end
    local function usable(s)
        if s.spell == main.spell or not knownForSure(prof, s) then return false end
        local c = ns.RecipeColor(s.spell, skill)
        if c == "grey" then return false end
        return true, c
    end
    local function finish()
        local n, about, color = ns.EstimateCrafts(prof, res.step, skill)
        res.crafts, res.about, res.color = n, about, color
        return res
    end

    -- 1. You don't know the guide's recipe, but you know an alternative.
    local mainLearned = ns.KnowsSpell(main.spell) or (ns.RecipeLearnedState and ns.RecipeLearnedState(prof, main.spell))
    if mainLearned == false then
        for _, a in ipairs(alts) do
            if usable(a) then
                res.step, res.reason = a, "learned"
                return finish()
            end
        end
    end

    -- 2. The guide's recipe turned yellow (or worse) and you know an orange one
    --    (an alternative, or the next step). If it's grey, anything better.
    local mr = mainColor and RANK[mainColor]
    if mr and mr >= 2 then
        local cands = {}
        for _, a in ipairs(alts) do table.insert(cands, a) end
        local nxt = steps[idx + 1]
        if nxt then
            table.insert(cands, nxt)
            for _, a in ipairs(nxt.alts or {}) do table.insert(cands, a) end
        end
        local best, br
        for _, s in ipairs(cands) do
            local ok, c = usable(s)
            local r = c and RANK[c]
            if ok and r and r < mr and (r == 1 or mr == 4) and (not br or r < br) then best, br = s, r end
        end
        if best then
            res.step, res.reason = best, "color"
            return finish()
        end
        if mr == 4 then res.grey = true end
    end

    -- 3. Bags, then prices, among the step and its alternatives.
    if #alts > 0 then
        local mainCov = coverage(main, (ns.EstimateCrafts(prof, main, skill)))
        res.mainCov = mainCov
        if not mainCov.all then
            local okAlts = {}
            for _, a in ipairs(alts) do
                local ok, c = usable(a)
                -- never trade the guide's recipe for a worse colour
                if ok and not (c and mr and RANK[c] > mr) then table.insert(okAlts, a) end
            end
            local covs = {}
            for i, a in ipairs(okAlts) do
                covs[i] = coverage(a, (ns.EstimateCrafts(prof, a, skill)))
                if covs[i].all then
                    res.step, res.reason, res.cov = a, "bags", covs[i]
                    return finish()
                end
            end
            if mainCov.cost and mainCov.cost > 0 then
                local best, bestCov
                for i, a in ipairs(okAlts) do
                    local cov = covs[i]
                    if cov.cost and cov.cost < mainCov.cost * 0.75 and mainCov.cost - cov.cost >= 2000
                        and (not bestCov or cov.cost < bestCov.cost) then
                        best, bestCov = a, cov
                    end
                end
                if best then
                    res.step, res.reason, res.cov = best, "cost", bestCov
                    return finish()
                end
            end
        end
    end
    return finish()
end

---------------------------------------------------------------------------
-- What's still needed up to your current trainer cap, and what it costs.
---------------------------------------------------------------------------
-- Returns totals[id], order, cap, produced[id]: what your own remaining steps
-- make (bolts...), which you don't have to buy.
function ns.CapNeeds(prof, snap)
    local p = snap and snap[prof]
    local skill = p and p.skill or 0
    local cap = p and p.max or 75
    if cap <= skill then cap = min(300, skill + 75) end
    local totals, order, produced = {}, {}, {}
    for _, s in ipairs(ns.Steps(prof)) do
        if skill < s.to and s.from < cap then
            local crafts
            if p and skill >= s.from then crafts = ns.EstimateCrafts(prof, s, skill)
            else crafts = ns.RemainingCrafts(s, skill) end
            if s.out then produced[s.out] = (produced[s.out] or 0) + crafts end
            for _, m in ipairs(s.mats) do
                if not totals[m[1]] then totals[m[1]] = 0 table.insert(order, m[1]) end
                totals[m[1]] = totals[m[1]] + m[2] * crafts
            end
        end
    end
    return totals, order, cap, produced
end

-- How many of an item you still have to get (not counting what you'll make).
function ns.CapMissing(totals, produced, id)
    return max(0, (totals[id] or 0) - (produced[id] or 0) - ns.Count(id))
end

-- nil without Auctionator prices, else
-- { cap, cost, unknown (some items unpriced), top (itemID costing most), money, short, done }
function ns.CapBudget(prof, snap)
    if not (snap and snap[prof] and ns.HasAuctionator()) then return nil end
    local totals, order, cap, produced = ns.CapNeeds(prof, snap)
    local cost, unknown, priced, missingAny = 0, false, false, false
    local top, topCost = nil, 0
    for _, id in ipairs(order) do
        local missing = ns.CapMissing(totals, produced, id)
        if missing > 0 and not isVendor(id) then
            missingAny = true
            local p = ns.AHPrice(id)
            if p then
                priced = true
                local c = p * missing
                cost = cost + c
                if c > topCost then top, topCost = id, c end
            else
                unknown = true
            end
        end
    end
    if missingAny and not priced then return nil end -- no AH scan for these items yet
    local money = snap.money or 0
    return { cap = cap, cost = cost, unknown = unknown, top = top, money = money,
             short = max(0, cost - money), done = not missingAny }
end

-- "Reaching 225: about 14g at today's prices. You have 9g; short 5g, mostly Silk Cloth."
function ns.BudgetText(b, compact)
    if not b then return nil end
    if b.done then
        return L["Reaching %d: you already have every Auction House mat."]:format(b.cap)
    end
    local plus = b.unknown and "+" or ""
    local s = L["Reaching %d: about %s%s at today's prices."]:format(b.cap, ns.Money(b.cost, true), plus)
    if b.short > 0 then
        local most = b.top and L[", mostly %s"]:format(ns.ItemName(b.top)) or ""
        if compact then
            s = s .. " " .. L["Short %s%s."]:format(ns.Money(b.short, true), most)
        else
            s = s .. " " .. L["You have %s; short %s%s."]:format(ns.Money(b.money, true), ns.Money(b.short, true), most)
        end
    elseif compact then
        s = s .. " " .. L["You can afford it."]
    else
        s = s .. " " .. L["You have %s: you can afford it."]:format(ns.Money(b.money, true))
    end
    return s
end
