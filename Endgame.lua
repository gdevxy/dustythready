-- DustyThready: Mooncloth cooldowns for all your tailors.
-- Stored account-wide in DustyThreadyDB.mooncloth["Name-Realm"] =
--   { readyAt = epoch seconds (0 = ready / never seen), class = "MAGE" }
-- so any character can see when each tailor can make Mooncloth again.
local _, ns = ...
local L = ns.L

local Endgame = {}
ns.Endgame = Endgame

local function now()
    if GetServerTime then
        local ok, t = pcall(GetServerTime)
        if ok and type(t) == "number" then return t end
    end
    return time()
end
Endgame.Now = now

local function charKey()
    local name = UnitName("player") or "?"
    local realm = (GetRealmName and GetRealmName()) or ""
    return name .. "-" .. realm, name
end
Endgame.CharKey = charKey

local function store()
    if not ns.db then return nil end
    if type(ns.db.mooncloth) ~= "table" then ns.db.mooncloth = {} end
    return ns.db.mooncloth
end

-- Seconds left on the Mooncloth cooldown as the game reports it, or nil
-- when the client gives us nothing usable (we then keep what we stored).
local function readRemaining()
    local spell = ns.MOONCLOTH.spell
    local clean = ns.clean
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spell)
        if ok and type(info) == "table" then
            local s, d = clean(info.startTime), clean(info.duration)
            if type(s) == "number" and type(d) == "number" and s > 0 and d > 60 then
                return s + d - GetTime()
            end
        end
    elseif GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, spell)
        if ok then
            s, d = clean(s), clean(d)
            if type(s) == "number" and type(d) == "number" and s > 0 and d > 60 then
                return s + d - GetTime()
            end
        end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeCooldown then
        local ok, cd = pcall(C_TradeSkillUI.GetRecipeCooldown, spell)
        if ok then
            cd = clean(cd)
            if type(cd) == "number" and cd > 60 then return cd end
        end
    end
    return nil
end

function Endgame.KnowsMooncloth()
    return ns.KnowsSpell(ns.MOONCLOTH.spell)
end

-- Reads the live cooldown and saves it for this character (only if they know Mooncloth).
function Endgame.UpdateMooncloth()
    local db = store()
    if not db then return end
    local key = charKey()
    local rec = db[key]
    if not Endgame.KnowsMooncloth() and not rec then return end
    if not rec then
        rec = { readyAt = 0 }
        db[key] = rec
    end
    local _, class = UnitClass("player")
    rec.class = class
    local left = readRemaining()
    if left and left > 0 then
        local readyAt = math.floor(now() + left + 0.5)
        if math.abs((rec.readyAt or 0) - readyAt) > 30 then
            rec.readyAt = readyAt
            ns:RequestRefresh()
        end
    end
end

-- { key, name, realm, class, readyAt, left (seconds, 0 when ready), me } sorted: me first, then soonest.
function Endgame.Tailors()
    local db = store()
    local out = {}
    if not db then return out end
    local me = charKey()
    local t = now()
    for key, rec in pairs(db) do
        if type(rec) == "table" then
            local name, realm = key:match("^(.-)%-(.*)$")
            local left = math.max(0, (rec.readyAt or 0) - t)
            table.insert(out, { key = key, name = name or key, realm = realm or "", class = rec.class,
                                readyAt = rec.readyAt or 0, left = left, me = key == me })
        end
    end
    table.sort(out, function(a, b)
        if a.me ~= b.me then return a.me end
        if a.left ~= b.left then return a.left < b.left end
        return a.key < b.key
    end)
    return out
end

function Endgame.FormatLeft(sec)
    if not sec or sec <= 0 then return ns.Color("good", L["Ready now"]) end
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    local text
    if d > 0 then text = ("%dd %dh"):format(d, h)
    elseif h > 0 then text = ("%dh %dm"):format(h, m)
    else text = ("%dm"):format(math.max(1, m)) end
    return ns.Color("muted", L["ready in"] .. " ") .. text
end

-- Name colored by class.
function Endgame.ClassName(entry)
    local c = entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
    if c and c.colorStr then return "|c" .. c.colorStr .. entry.name .. "|r" end
    return entry.name
end

---------------------------------------------------------------------------
-- Alerts: one line at login if Mooncloth is ready, one when it comes off
-- cooldown during the session.
---------------------------------------------------------------------------
local PREFIX = function() return ns.Color("violet", "DustyThready:") .. " " end
local wasWaiting = false

local function myLeft()
    local db = store()
    local rec = db and db[charKey()]
    if not rec then return nil end
    return math.max(0, (rec.readyAt or 0) - now())
end

local function loginAlert()
    if not Endgame.KnowsMooncloth() then return end
    Endgame.UpdateMooncloth()
    local left = myLeft()
    if not left then return end
    if left > 0 then wasWaiting = true return end
    local others = {}
    for _, e in ipairs(Endgame.Tailors()) do
        if not e.me and e.left <= 0 then table.insert(others, e.name) end
    end
    local felcloth = ns.Count(ns.MOONCLOTH.felcloth)
    local line = PREFIX() .. ns.Color("good", L["Mooncloth is ready"]) .. " " ..
        (felcloth >= 2 and L["(you have %d Felcloth)"]:format(felcloth) or L["(you need 2 Felcloth)"])
    if #others > 0 then line = line .. ". " .. L["Also ready on: %s"]:format(table.concat(others, ", ")) end
    print(line .. ".")
end

local function tick()
    local left = myLeft()
    if not left then return end
    if left > 0 then
        wasWaiting = true
    elseif wasWaiting then
        wasWaiting = false
        print(PREFIX() .. ns.Color("good", L["Mooncloth is off cooldown."]) .. " " .. L["2 Felcloth make 1 Mooncloth."])
        ns:RequestRefresh()
    end
end

ns:On("PLAYER_LOGIN", function()
    C_Timer.After(8, function()
        local ok, err = pcall(loginAlert)
        if not ok then geterrorhandler()(err) end
    end)
    if C_Timer.NewTicker then C_Timer.NewTicker(60, function() pcall(tick) end) end
end)

-- A fresh craft: store the fallback duration now, then trust the game's own number.
ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    spellID = ns.clean(spellID)
    if unit ~= "player" or spellID ~= ns.MOONCLOTH.spell then return end
    local db = store()
    if not db then return end
    local key = charKey()
    db[key] = db[key] or {}
    db[key].readyAt = now() + ns.MOONCLOTH.cooldown
    local _, class = UnitClass("player")
    db[key].class = class
    wasWaiting = true
    C_Timer.After(1, Endgame.UpdateMooncloth)
    ns:RequestRefresh()
end)

ns:On("TRADE_SKILL_LIST_UPDATE", function() Endgame.UpdateMooncloth() end)
ns:On("SPELLS_CHANGED", function() Endgame.UpdateMooncloth() end)
