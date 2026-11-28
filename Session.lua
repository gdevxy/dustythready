-- DustyThready: "This session" progress (since login or /reload).
-- Skill-ups, enchanting reagents gained (bag + bank count increases, not
-- counting mail / AH / trade / vendor / guild bank windows), and what your
-- disenchants were worth compared to vendoring the items.
local _, ns = ...
local L = ns.L

local Session = {}
ns.Session = Session

local REAGENTS = {}   -- every dust / essence / shard / crystal from Data\Disenchant.lua
do
    local seen = {}
    local function add(id) if id and not seen[id] then seen[id] = true table.insert(REAGENTS, id) end end
    for _, r in ipairs(ns.DE_ROWS or {}) do
        add(r.dust and r.dust[1]) add(r.essence and r.essence[1]) add(r.shard) add(r.crystal)
    end
    -- Large shards (the rows only name the main shard of each bracket).
    for _, id in ipairs({ 11084, 11139, 11178, 14344, 20725 }) do add(id) end
end

local ready = false
local base = {}        -- profession key -> skill at session start
local last = {}        -- reagent id -> last count seen
local gained = 0       -- reagents gained this session
local des, priced, saved = 0, 0, 0   -- disenchants, how many had prices, copper (DE value - vendor)
local busy = {}        -- window name -> true while it's open (moves items without "gaining" them)
local pending          -- { guid, ev, sell } for the disenchant being cast

local function isBusy()
    for _, v in pairs(busy) do if v then return true end end
    return false
end

local function resync()
    for _, id in ipairs(REAGENTS) do last[id] = ns.Count(id) end
end

local function readSkills()
    for _, key in ipairs({ "tailoring", "enchanting" }) do
        if base[key] == nil then
            local p = ns.ProfessionSkill(key:upper())
            if p and p.skill then base[key] = p.skill end
        end
    end
end

local function start()
    resync()
    readSkills()
    ready = true
end

ns:On("PLAYER_LOGIN", function() C_Timer.After(3, start) end)

ns:On("BAG_UPDATE_DELAYED", function()
    if not ready then return end
    if isBusy() then resync() return end
    local changed = false
    for _, id in ipairs(REAGENTS) do
        local n = ns.Count(id)
        local before = last[id] or n
        if n > before then gained = gained + (n - before) changed = true end
        last[id] = n
    end
    if changed then ns:RequestRefresh() end
end)

ns:On("SKILL_LINES_CHANGED", function() if ready then readSkills() end end)

-- Windows that move reagents around: don't count those as gains.
local WINDOWS = {
    MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
    AUCTION_HOUSE_SHOW = { "ah", true }, AUCTION_HOUSE_CLOSED = { "ah", false },
    TRADE_SHOW = { "trade", true }, TRADE_CLOSED = { "trade", false },
    MERCHANT_SHOW = { "merchant", true }, MERCHANT_CLOSED = { "merchant", false },
    GUILDBANKFRAME_OPENED = { "guildbank", true }, GUILDBANKFRAME_CLOSED = { "guildbank", false },
    -- The bank's contents may only become known (counted) once it is opened.
    BANKFRAME_OPENED = { "bank", true }, BANKFRAME_CLOSED = { "bank", false },
}
for event, spec in pairs(WINDOWS) do
    ns:On(event, function()
        busy[spec[1]] = spec[2]
        if not spec[2] and ready then
            -- Late bag updates from that window: take them as the new baseline.
            C_Timer.After(1, function() if not isBusy() then resync() end end)
        end
    end)
end

---------------------------------------------------------------------------
-- Disenchant value: while Disenchant is cast, the target item is locked in
-- the bags. Remember its prediction; count it when the cast succeeds.
---------------------------------------------------------------------------
local NUM_BAGS = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)

local function lockedTarget()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return nil end
    for bag = 0, NUM_BAGS do
        local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (okN and n or 0) do
            local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and info.isLocked and info.itemID then
                local pred = ns.PredictDE(info.hyperlink or info.itemID)
                if pred then return pred end
            end
        end
    end
    return nil
end

local function isDE(unit, spellID)
    return unit == "player" and ns.clean(spellID) == ns.DISENCHANT_SPELL
end

ns:On("UNIT_SPELLCAST_START", function(unit, guid, spellID)
    if not isDE(unit, spellID) then return end
    -- The lock can show up a moment after the cast starts.
    pending = { guid = ns.clean(guid) }
    local p = pending
    local function look()
        if pending ~= p or p.pred then return end
        p.pred = lockedTarget()
    end
    look()
    C_Timer.After(0.2, look)
end)

ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, guid, spellID)
    if not isDE(unit, spellID) then return end
    local p = pending
    pending = nil
    if not ready then return end
    des = des + 1
    local pred = p and p.pred
    if pred and pred.ev then
        priced = priced + 1
        saved = saved + (pred.ev - (pred.sell or 0))
    end
    ns:RequestRefresh()
end)

local function cancel(unit, _, spellID)
    if isDE(unit, spellID) then pending = nil end
end
ns:On("UNIT_SPELLCAST_INTERRUPTED", cancel)
ns:On("UNIT_SPELLCAST_FAILED", cancel)

---------------------------------------------------------------------------
-- Crafts of path recipes: the current run per profession (same recipe in a
-- row) and the skill it started at, so Today can say "Last 10 crafts: +7 skill".
-- The skill is read when the run's first cast starts, before its skill-up.
---------------------------------------------------------------------------
local runs = {}        -- profession key -> { spell, crafts, from }
local casting = {}     -- cast GUID -> true for path-recipe casts in progress

local function profSkill(prof)
    local p = ns.ProfessionSkill(prof:upper())
    return p and p.skill or nil
end

ns:On("UNIT_SPELLCAST_START", function(unit, guid, spellID)
    if unit ~= "player" then return end
    local spell = ns.clean(spellID)
    local prof = ns.PathProfession and ns.PathProfession(spell)
    if not prof then return end
    local g = ns.clean(guid)
    if g then casting[g] = true end
    local r = runs[prof]
    if not (r and r.spell == spell) then
        local skill = profSkill(prof)
        runs[prof] = skill and { spell = spell, crafts = 0, from = skill } or nil
    end
end)

ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, guid, spellID)
    if unit ~= "player" then return end
    local spell = ns.clean(spellID)
    local prof = ns.PathProfession and ns.PathProfession(spell)
    if not prof then return end
    local g = ns.clean(guid)
    -- Instant casts send no START: open the run here (the skill-up comes after this event).
    if not (g and casting[g]) and not (runs[prof] and runs[prof].spell == spell) then
        local skill = profSkill(prof)
        runs[prof] = skill and { spell = spell, crafts = 0, from = skill } or nil
    end
    if g then casting[g] = nil end
    local r = runs[prof]
    if r and r.spell == spell then
        r.crafts = r.crafts + 1
        ns:RequestRefresh()
    end
end)

local function endCast(unit, guid)
    if unit ~= "player" then return end
    local g = ns.clean(guid)
    if g then casting[g] = nil end
end
ns:On("UNIT_SPELLCAST_INTERRUPTED", endCast)
ns:On("UNIT_SPELLCAST_FAILED", endCast)

-- The run of this recipe this session: crafts, skill gained; nil before the first craft.
function Session.Run(prof, spell)
    local r = runs[prof]
    if not (r and r.spell == spell and r.crafts > 0) then return nil end
    local now = profSkill(prof) or r.from
    return r.crafts, math.max(0, now - r.from)
end

---------------------------------------------------------------------------
-- The footer line
---------------------------------------------------------------------------
function Session.Gains()
    local skills = {}
    for _, key in ipairs({ "tailoring", "enchanting" }) do
        local b = base[key]
        local p = b and ns.ProfessionSkill(key:upper())
        skills[key] = (p and p.skill and p.skill > b) and (p.skill - b) or 0
    end
    return { tailoring = skills.tailoring, enchanting = skills.enchanting, reagents = gained,
             disenchants = des, priced = priced, saved = saved }
end

-- "This session: +14 Tailoring, +9 Enchanting, 38 dust, ~+1g 20s vs vendoring", or nil when nothing happened.
function Session.FooterText()
    if not ready then return nil end
    local g = Session.Gains()
    local parts = {}
    if g.tailoring > 0 then table.insert(parts, ns.Color("gold", L["+%d Tailoring"]:format(g.tailoring))) end
    if g.enchanting > 0 then table.insert(parts, ns.Color("violet", L["+%d Enchanting"]:format(g.enchanting))) end
    if g.reagents > 0 then table.insert(parts, ns.Color("text", L["%d dust"]:format(g.reagents))) end
    if g.priced > 0 and math.abs(g.saved) >= 1 then
        local money = (g.saved > 0 and "+" or "") .. ns.Money(g.saved, true)
        table.insert(parts, ns.Color(g.saved > 0 and "good" or "warn", "~" .. money) .. " " .. L["vs vendoring"])
    end
    if #parts == 0 then return nil end
    return L["This session: %s"]:format(table.concat(parts, ", "))
end
