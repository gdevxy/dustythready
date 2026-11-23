-- DustyThready: Core
-- Namespace, saved variables, a tiny event bus and safe wrappers around the
-- WoW Forever API (a modern client running classic content: C_Item,
-- C_Container, C_Spell, GetProfessions, C_SkillInfo... and some globals gone).

local ADDON, ns = ...
_G.DustyThready = ns

ns.name = ADDON
ns.ICON = "Interface\\AddOns\\DustyThready\\Media\\icon.tga"

ns.SKILL = { TAILORING = 197, ENCHANTING = 333 }
ns.DISENCHANT_SPELL = 13262

---------------------------------------------------------------------------
-- Colors (one palette for the whole addon)
---------------------------------------------------------------------------
ns.C = {
    violet  = { 0.73, 0.55, 1.00 },  -- enchanting / magic
    gold    = { 0.91, 0.76, 0.44 },  -- tailoring / thread
    text    = { 0.93, 0.91, 0.96 },
    muted   = { 0.62, 0.58, 0.70 },
    good    = { 0.45, 0.88, 0.55 },
    warn    = { 1.00, 0.78, 0.35 },
    bad     = { 1.00, 0.45, 0.45 },
    bg      = { 0.07, 0.06, 0.10 },
    panel   = { 0.12, 0.10, 0.17 },
    panelHi = { 0.17, 0.14, 0.24 },
    edge    = { 0.30, 0.24, 0.42 },
}
local function hex(c) return ("%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
ns.HEX = {}
for k, v in pairs(ns.C) do ns.HEX[k] = hex(v) end
function ns.Color(key, text) return "|cff" .. (ns.HEX[key] or "ffffff") .. tostring(text) .. "|r" end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local DEFAULTS = {
    minimap = { hide = false, minimapPos = 205 },  -- LibDBIcon settings
    tooltip = true,
    window = nil,           -- { point, x, y }
    tab = "today",
    enchantRoute = "dust",  -- "dust" (Strange Dust) or "essence" (Lesser Magic Essence)
    roadmapProf = "tailoring",
    ignoredDE = {},         -- itemID -> true: never suggest disenchanting it
    welcomed = false,
}
local CHAR_DEFAULTS = {
    learned = {},           -- recipe spellID -> true (learned recipes, cached from the profession window)
}

local function fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = type(v) == "table" and fill({}, v) or v
        elseif type(v) == "table" and type(dst[k]) == "table" then
            fill(dst[k], v)
        end
    end
    return dst
end

---------------------------------------------------------------------------
-- Event bus: ns:On("EVENT", fn) for game events and ns:Fire("custom")
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.frame = frame
local handlers = {}

function ns:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        if not event:find("^DT_") then pcall(frame.RegisterEvent, frame, event) end
    end
    table.insert(handlers[event], fn)
end

function ns:Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end

frame:SetScript("OnEvent", function(_, event, ...) ns:Fire(event, ...) end)

-- Coalesce bursts (bag updates fire a lot) into one "DT_REFRESH" per frame-ish.
local pending = false
function ns:RequestRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = false
        ns:Fire("DT_REFRESH")
    end)
end

---------------------------------------------------------------------------
-- Safe helpers
---------------------------------------------------------------------------
local issecret = _G.issecretvalue
local function clean(v)
    if issecret and issecret(v) then return nil end
    return v
end
ns.clean = clean

function ns.SpellName(id, fallback)
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok then name = clean(n) end
    elseif GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok then name = clean(n) end
    end
    return name or fallback or ("Spell " .. id)
end

function ns.KnowsSpell(id)
    if ns.char and ns.char.learned[id] then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and clean(known) then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and clean(known) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Items: info, names (with fallbacks while the client caches), icons, counts
---------------------------------------------------------------------------
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
local GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount

-- Returns a table of the useful GetItemInfo fields, or nil (and asks the
-- client to load it; GET_ITEM_INFO_RECEIVED will refresh the UI).
function ns.ItemInfo(item)
    if not item then return nil end
    local ok, name, link, quality, ilvl, minLevel, _, _, _, equipLoc, icon, sellPrice, classID, subclassID =
        pcall(GetItemInfo, item)
    if not ok or not name then
        if type(item) == "number" and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, item)
        end
        return nil
    end
    return {
        name = name, link = link, quality = quality, ilvl = ilvl, minLevel = minLevel,
        equipLoc = equipLoc, icon = icon, sellPrice = sellPrice, classID = classID, subclassID = subclassID,
    }
end

function ns.ItemName(id)
    local info = ns.ItemInfo(id)
    if info then return info.name end
    return (ns.ITEM_NAMES and ns.ITEM_NAMES[id]) or ("Item " .. id)
end

-- Name colored by quality (white if unknown).
function ns.ItemText(id)
    local info = ns.ItemInfo(id)
    local name = info and info.name or (ns.ITEM_NAMES and ns.ITEM_NAMES[id]) or ("Item " .. id)
    local q = info and info.quality or 1
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if color and color.hex then return color.hex .. name .. "|r" end
    return name
end

function ns.ItemIcon(id)
    local ok, icon = pcall(GetItemIcon, id)
    return (ok and icon) or 134400 -- question mark
end

function ns.Count(id)
    if not GetItemCount then return 0 end
    local ok, n = pcall(GetItemCount, id, true) -- bags + bank
    return (ok and clean(n)) or 0
end

function ns.IconString(icon, size)
    size = size or 14
    return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(tostring(icon), size, size)
end

---------------------------------------------------------------------------
-- Money
---------------------------------------------------------------------------
function ns.Money(copper, short)
    if not copper then return ns.Color("muted", "?") end
    copper = math.floor(copper + 0.5)
    local neg = copper < 0
    if neg then copper = -copper end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, ("%d|cffffd100g|r"):format(g)) end
    if s > 0 and (not short or g < 100) then table.insert(parts, ("%d|cffc7c7cfs|r"):format(s)) end
    if (c > 0 and (not short or (g == 0 and s < 10))) or #parts == 0 then
        table.insert(parts, ("%d|cffeda55fc|r"):format(c))
    end
    return (neg and "-" or "") .. table.concat(parts, " ")
end

-- Price for one unit: Auctionator's last scanned AH price when available,
-- else the vendor sell price. Returns copper, source ("ah" | "vendor").
function ns.Price(id)
    local A = _G.Auctionator
    if A and A.API and A.API.v1 and A.API.v1.GetAuctionPriceByItemID then
        local ok, p = pcall(A.API.v1.GetAuctionPriceByItemID, ADDON, id)
        if ok and type(p) == "number" and p > 0 then return p, "ah" end
    end
    local info = ns.ItemInfo(id)
    if info and info.sellPrice and info.sellPrice > 0 then return info.sellPrice, "vendor" end
    return nil
end

function ns.AHPrice(id)
    local p, src = ns.Price(id)
    if src == "ah" then return p end
end

function ns.HasAuctionator()
    local A = _G.Auctionator
    return A and A.API and A.API.v1 and true or false
end

---------------------------------------------------------------------------
-- Player professions: { skill, max } for Tailoring and Enchanting, or nil
---------------------------------------------------------------------------
local function readByProfessions(line)
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return end
    local ok, a, b, c, d, e, f = pcall(GetProfessions)
    if not ok then return end
    for _, index in pairs({ a, b, c, d, e, f }) do
        local ok2, _, _, rank, max, _, _, skillLine = pcall(GetProfessionInfo, index)
        if ok2 and clean(skillLine) == line then
            return clean(rank), clean(max)
        end
    end
end

local function readBySkillInfo(line)
    if not (C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then return end
    local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, line)
    if ok and type(info) == "table" then
        local max = clean(info.maxRank)
        if max and max > 0 then return clean(info.rank) or 0, max end
    end
end

local function readByLegacy(line, wantedName)
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then return end
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, max = GetSkillLineInfo(i)
        if not isHeader and name == wantedName then return rank, max end
    end
end

function ns.ProfessionSkill(key)
    local line = ns.SKILL[key]
    local rank, max = readByProfessions(line)
    if not rank then rank, max = readBySkillInfo(line) end
    if not rank then
        local spell = key == "TAILORING" and 3908 or 7411
        rank, max = readByLegacy(line, ns.SpellName(spell))
    end
    if rank then return { skill = rank, max = max or 0 } end
    return nil
end

function ns.Snapshot()
    local level = UnitLevel("player") or 1
    local faction = UnitFactionGroup("player") or "Neutral"
    return {
        level = level,
        faction = faction == "Horde" and "H" or (faction == "Alliance" and "A" or "N"),
        tailoring = ns.ProfessionSkill("TAILORING"),
        enchanting = ns.ProfessionSkill("ENCHANTING"),
        money = GetMoney and GetMoney() or 0,
        canDisenchant = ns.KnowsSpell(ns.DISENCHANT_SPELL),
    }
end

---------------------------------------------------------------------------
-- Learned recipe cache (read while a profession window is open)
---------------------------------------------------------------------------
local function cacheLearned()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) then return end
    local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return end
    local changed = false
    for _, id in ipairs(ids) do
        local ok2, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        if ok2 and type(info) == "table" and clean(info.learned) and not ns.char.learned[id] then
            ns.char.learned[id] = true
            changed = true
        end
    end
    if changed then ns:RequestRefresh() end
end

---------------------------------------------------------------------------
-- Boot
---------------------------------------------------------------------------
ns:On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    DustyThreadyDB = fill(DustyThreadyDB or {}, DEFAULTS)
    DustyThreadyCharDB = fill(DustyThreadyCharDB or {}, CHAR_DEFAULTS)
    ns.db, ns.char = DustyThreadyDB, DustyThreadyCharDB
    ns:Fire("DT_READY")
end)

ns:On("PLAYER_LOGIN", function()
    -- Warm the item cache so names/qualities are ready when the window opens.
    if ns.ALL_ITEM_IDS and C_Item and C_Item.RequestLoadItemDataByID then
        for _, id in ipairs(ns.ALL_ITEM_IDS) do pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    C_Timer.After(3, function() ns:RequestRefresh() end)
    if not ns.db.welcomed then
        ns.db.welcomed = true
        print(ns.IconString(ns.ICON, 16) .. " " .. ns.Color("violet", "Dusty") .. ns.Color("gold", "Thready") ..
            " is ready. Type " .. ns.Color("gold", "/dusty") .. " or click the minimap button.")
    end
end)

for _, ev in ipairs({ "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_MONEY",
                      "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED", "TRADE_SKILL_LIST_UPDATE", "BANKFRAME_OPENED",
                      "AUCTION_HOUSE_CLOSED" }) do
    ns:On(ev, function() ns:RequestRefresh() end)
end
ns:On("TRADE_SKILL_SHOW", function() C_Timer.After(0.5, cacheLearned) end)
ns:On("TRADE_SKILL_LIST_UPDATE", function() cacheLearned() end)
ns:On("NEW_RECIPE_LEARNED", function(id) if ns.char and id then ns.char.learned[id] = true end ns:RequestRefresh() end)

-- Item data arriving: refresh at most a couple of times per second.
ns:On("GET_ITEM_INFO_RECEIVED", function(_, ok) if ok then ns:RequestRefresh() end end)

SLASH_DUSTYTHREADY1 = "/dusty"
SLASH_DUSTYTHREADY2 = "/dustythready"
SlashCmdList.DUSTYTHREADY = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        ns:Fire("DT_MINIMAP")
        return
    elseif msg == "reset" then
        ns.db.window = nil
        if ns.Main then ns.Main:ResetPosition() end
        return
    end
    local tab = ({ de = "disenchant", disenchant = "disenchant", gold = "gold", road = "roadmap",
                   roadmap = "roadmap", where = "places", trainers = "places" })[msg]
    ns.Toggle(tab)
end

function ns.Toggle(tab)
    if ns.Main then ns.Main:Toggle(tab) end
end

-- Addon compartment (the puzzle-piece menu by the minimap)
function DustyThready_OnCompartmentClick() ns.Toggle() end
function DustyThready_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.Color("violet", "Dusty") .. ns.Color("gold", "Thready"))
    GameTooltip:AddLine("Click to open your Tailoring + Enchanting companion.", 1, 1, 1, true)
    GameTooltip:Show()
end
function DustyThready_OnCompartmentLeave() GameTooltip:Hide() end
