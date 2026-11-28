-- DustyThready: Core
-- Namespace, saved variables, a tiny event bus and safe wrappers around the
-- WoW Forever API (a modern client running classic content: C_Item,
-- C_Container, C_Spell, GetProfessions, C_SkillInfo... and some globals gone).

local ADDON, ns = ...
_G.DustyThready = ns
local L = ns.L -- Locale.lua (loaded first)

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
    chars = {},             -- "Name-Realm" -> what that character holds (see "other characters" below)
}
local CHAR_DEFAULTS = {
    learned = {},           -- recipe spellID -> true (learned recipes, cached from the profession window)
    scanned = {},           -- profession skill line -> true once its recipe list was read
                            -- (from then on, "not in learned" means not learned)
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
    return name or fallback or L["Spell %s"]:format(tostring(id))
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
    return (ns.ITEM_NAMES and ns.ITEM_NAMES[id]) or L["Item %s"]:format(tostring(id))
end

-- Name colored by quality (white if unknown).
function ns.ItemText(id)
    local info = ns.ItemInfo(id)
    local name = info and info.name or (ns.ITEM_NAMES and ns.ITEM_NAMES[id]) or L["Item %s"]:format(tostring(id))
    local q = info and info.quality or 1
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if color and color.hex then return color.hex .. name .. "|r" end
    return name
end

function ns.ItemIcon(id)
    local ok, icon = pcall(GetItemIcon, id)
    return (ok and icon) or 134400 -- question mark
end

-- Bags + bank on this character. includeMail = also what waits in this
-- character's mailbox (as last seen when the mailbox was open).
function ns.Count(id, includeMail)
    if not GetItemCount then return 0 end
    local ok, n = pcall(GetItemCount, id, true) -- bags + bank
    n = (ok and clean(n)) or 0
    if includeMail and ns.CountMail then n = n + ns.CountMail(id) end
    return n
end

---------------------------------------------------------------------------
-- Materials on the other characters and in the mailbox
--   DustyThreadyDB.chars["Name-Realm"] = { name, realm, faction "A"/"H"/"N",
--       class (e.g. "MAGE"), level, updated = time(),
--       items = { [itemID] = { bags = n, bank = n, mail = n } } }
-- Only items DustyThready uses are stored (reagents, disenchant mats, cloth)
-- and only non-zero fields, to keep the saved variables small. Each
-- character fills its own entry; alts are read from the other entries
-- (or from Syndicator when it is installed).
---------------------------------------------------------------------------
local tracked -- itemID -> true, built on first use (after the Data files are loaded)

local function track(id)
    if type(id) == "number" and id > 0 then tracked[id] = true end
end

local function trackMats(list)
    for _, s in ipairs(list or {}) do
        if type(s) == "table" then
            for _, m in ipairs(s.mats or {}) do
                if type(m) == "table" then track(m[1]) end
            end
            if s.alts then trackMats(s.alts) end
        end
    end
end

function ns.TrackedItems()
    if tracked then return tracked end
    tracked = {}
    for _, id in ipairs(ns.ALL_ITEM_IDS or {}) do track(id) end
    for id in pairs(ns.ITEM_NAMES or {}) do track(id) end
    trackMats(ns.TAILORING)
    trackMats(ns.ENCHANTING)
    trackMats(ns.GOLD_CRAFTS)
    for _, r in ipairs(ns.DE_ROWS or {}) do
        if type(r.dust) == "table" then track(r.dust[1]) end
        if type(r.essence) == "table" then track(r.essence[1]) end
        track(r.shard)
        track(r.crystal)
    end
    for _, b in ipairs(ns.BOLTS or {}) do track(b.bolt) track(b.cloth) end
    for _, f in ipairs(ns.CLOTH_FARMS or {}) do track(f.cloth) end
    return tracked
end

local function factionLetter()
    local ok, f = pcall(UnitFactionGroup, "player")
    f = ok and clean(f) or nil
    return f == "Horde" and "H" or (f == "Alliance" and "A" or "N")
end

-- WoW Forever has no realms, only rulesets, and characters have a first and a
-- last name: GetNormalizedRealmName / GetRealmName give "", GetRealmID gives
-- nothing, and UnitFullName's second value is the last name ("Frieza", "Cold").
-- Characters are keyed "First Last-<group>": the group is the realm name on a
-- client that has one, else the ruleset ("PvE", "PvP", "RP", "RPPvP", "HC",
-- read like Auctionator does). Only the same group and faction count as alts.
local function rulesetName()
    local rules, active = Enum and Enum.GameRule, C_GameRules and C_GameRules.IsGameRuleActive
    if type(rules) ~= "table" or type(active) ~= "function" then return "" end
    local function on(name)
        local rule = rules[name]
        if rule == nil then return false end
        local ok, v = pcall(active, rule)
        return ok and clean(v) == true
    end
    if on("HardcoreRuleset") then return "HC" end
    local pvp, rp = on("PvPRuleset"), on("RPRuleset")
    if pvp and rp then return "RPPvP" end
    if pvp then return "PvP" end
    if rp then return "RP" end
    return "PvE"
end

-- Returns the group, and true when the client has no realm name (Forever).
local function realmName()
    for _, f in ipairs({ GetNormalizedRealmName or false, GetRealmName or false }) do
        if f then
            local ok, r = pcall(f)
            r = ok and clean(r) or nil
            if type(r) == "string" and r ~= "" then return (r:gsub("[%s%-]", "")), false end
        end
    end
    return rulesetName(), true
end

-- Last name on Forever (UnitFullName's second value when the client has no realm name).
local function lastName()
    if not UnitFullName then return nil end
    local ok, _, last = pcall(UnitFullName, "player")
    last = ok and clean(last) or nil
    if type(last) == "string" and last ~= "" then return last end
    return nil
end

local me -- { key = "First Last-Group", name, last, realm } once the game knows them
local function whoAmI()
    if me then return me end
    local ok, name = pcall(UnitName, "player")
    name = ok and clean(name) or nil
    if type(name) ~= "string" or name == "" or name == _G.UNKNOWNOBJECT then return nil end
    local realm, noRealms = realmName()
    local last = noRealms and lastName() or nil
    me = { key = name .. (last and (" " .. last) or "") .. "-" .. realm, name = name, last = last, realm = realm }
    return me
end

-- This character's saved entry (read-only lookup, may be nil).
local function myEntry()
    local id = whoAmI()
    local chars = ns.db and ns.db.chars
    if not id or type(chars) ~= "table" then return nil end
    local rec = chars[id.key]
    return type(rec) == "table" and rec or nil
end

-- This character's entry, created and stamped (used by the scans).
local function myRecord()
    local id = whoAmI()
    if not id or not ns.db then return nil end
    if type(ns.db.chars) ~= "table" then ns.db.chars = {} end
    local rec = ns.db.chars[id.key]
    if type(rec) ~= "table" then rec = {} ns.db.chars[id.key] = rec end
    if type(rec.items) ~= "table" then rec.items = {} end
    rec.name, rec.last, rec.realm, rec.faction = id.name, id.last, id.realm, factionLetter()
    local okC, _, class = pcall(UnitClass, "player")
    if okC and clean(class) then rec.class = class end
    local okL, level = pcall(UnitLevel, "player")
    if okL and clean(level) then rec.level = level end
    rec.updated = time()
    return rec
end

local function setField(items, id, field, n)
    if type(n) ~= "number" or n <= 0 then n = nil end
    local e = items[id]
    if type(e) ~= "table" then
        if not n then items[id] = nil return end
        e = {}
        items[id] = e
    end
    e[field] = n
    if not e.bags and not e.bank and not e.mail then items[id] = nil end
end

local bankOpen, mailOpen = false, false
local function isOpen(flag, frameName)
    if flag then return true end
    local f = _G[frameName]
    if f and f.IsShown then
        local ok, shown = pcall(f.IsShown, f)
        return ok and shown and true or false
    end
    return false
end

local function scanBags(rec, ids)
    local atBank = isOpen(bankOpen, "BankFrame")
    for id in pairs(ids) do
        local ok, bags = pcall(GetItemCount, id, false)
        bags = (ok and clean(bags)) or 0
        setField(rec.items, id, "bags", bags)
        -- The bank part only counts when the client knows the bank; while
        -- it is closed, keep what we saw last time unless it shows more.
        local bank = ns.Count(id) - bags
        if bank > 0 or atBank then setField(rec.items, id, "bank", bank) end
    end
end

local function inboxItemID(i, a, itemID)
    if type(itemID) == "number" then return itemID end
    if not GetInboxItemLink then return nil end
    local ok, link = pcall(GetInboxItemLink, i, a)
    if ok and type(clean(link)) == "string" then return tonumber(link:match("item:(%d+)")) end
end

local function scanMail(rec, ids)
    if not isOpen(mailOpen, "MailFrame") or not GetInboxNumItems or not GetInboxItem then return false end
    local okN, num = pcall(GetInboxNumItems)
    num = okN and tonumber(clean(num)) or nil
    if not num then return false end
    local counts = {}
    local maxAtt = tonumber(_G.ATTACHMENTS_MAX_RECEIVE) or 16
    for i = 1, num do
        for a = 1, maxAtt do
            local ok, name, itemID, _, count = pcall(GetInboxItem, i, a)
            if ok and clean(name) then
                local id = inboxItemID(i, a, clean(itemID))
                if id and ids[id] then
                    counts[id] = (counts[id] or 0) + (tonumber(clean(count)) or 1)
                end
            end
        end
    end
    for id in pairs(ids) do setField(rec.items, id, "mail", counts[id]) end
    return true
end

-- Scans run at most every half second (bag and mail events come in bursts).
local want = {}
local function doScan()
    if not (want.bags or want.mail) then return end
    local rec = myRecord()
    if not rec then return end
    local ids = ns.TrackedItems()
    for id in pairs(rec.items) do
        if not ids[id] then rec.items[id] = nil end -- no longer used by the addon
    end
    local mailChanged = false
    if want.bags and GetItemCount then scanBags(rec, ids) end
    if want.mail then mailChanged = scanMail(rec, ids) end
    want.bags, want.mail = nil, nil
    if mailChanged then ns:RequestRefresh() end
end

local scanPending = false
local function requestScan(kind)
    want[kind] = true
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.5, function()
        scanPending = false
        local ok, err = pcall(doScan)
        if not ok then geterrorhandler()(err) end
    end)
end

-- Scan right now (the bank / mailbox is about to close, or we log out).
local function scanNow(kind)
    want[kind] = true
    local ok, err = pcall(doScan)
    if not ok then geterrorhandler()(err) end
end

-- What this character has in its mailbox (as last seen there).
function ns.CountMail(id)
    local rec = myEntry()
    local e = rec and type(rec.items) == "table" and rec.items[id]
    return (type(e) == "table" and tonumber(e.mail)) or 0
end

local realmSet
local function myRealms(id)
    if realmSet then return realmSet end
    realmSet = { [id.realm] = true }
    if GetAutoCompleteRealms then
        local ok, list = pcall(GetAutoCompleteRealms)
        if ok and type(list) == "table" then
            for _, r in ipairs(list) do
                if type(r) == "string" then realmSet[r] = true end
            end
        end
    end
    return realmSet
end

-- Optional: Syndicator knows every character too (often fresher). Its
-- characters win over our own cache when both have one.
local function fromSyndicator(itemID, id, out)
    local S = _G.Syndicator
    local api = type(S) == "table" and S.API
    if type(api) ~= "table" or type(api.GetInventoryInfoByItemID) ~= "function" then return end
    if type(api.IsReady) == "function" then
        local ok, ready = pcall(api.IsReady)
        if not ok or not ready then return end
    end
    local ok, info = pcall(api.GetInventoryInfoByItemID, itemID, true, true) -- same realm, same faction
    if not ok or type(info) ~= "table" or type(info.characters) ~= "table" then return end
    for _, c in ipairs(info.characters) do
        if type(c) == "table" and type(c.character) == "string" then
            local realm = type(c.realmNormalized) == "string" and c.realmNormalized or id.realm
            local key = c.character .. "-" .. realm
            local bags, bank, mail = tonumber(c.bags) or 0, tonumber(c.bank) or 0, tonumber(c.mail) or 0
            if key ~= id.key and bags + bank + mail > 0 then
                out[key] = { name = c.character, realm = realm, class = c.className,
                             bags = bags, bank = bank, mail = mail, count = bags + bank + mail }
            end
        end
    end
end

-- How many of an item your other characters hold (bags + bank + mailbox),
-- same realm (or connected realms) and same faction only, since only those
-- can mail it to you. Returns total, list of { name, count, bags, bank,
-- mail, class } sorted by count (most first). The current character is
-- never in the list.
function ns.CountAlts(itemID)
    local list, total = {}, 0
    local id = whoAmI()
    if not itemID or not id or not ns.db then return 0, list end
    local found = {}
    fromSyndicator(itemID, id, found)
    local chars = ns.db.chars
    if type(chars) == "table" then
        local realms, faction = myRealms(id), factionLetter()
        for key, rec in pairs(chars) do
            if key ~= id.key and not found[key] and type(rec) == "table" and type(rec.items) == "table"
                and realms[rec.realm] and rec.faction == faction then
                local e = rec.items[itemID]
                if type(e) == "table" then
                    local bags, bank, mail = tonumber(e.bags) or 0, tonumber(e.bank) or 0, tonumber(e.mail) or 0
                    if bags + bank + mail > 0 then
                        found[key] = { name = rec.name, realm = rec.realm, class = rec.class,
                                       bags = bags, bank = bank, mail = mail, count = bags + bank + mail }
                    end
                end
            end
        end
    end
    for _, c in pairs(found) do
        if type(c.name) ~= "string" then c.name = "?" end
        if c.realm and c.realm ~= id.realm then c.name = c.name .. "-" .. c.realm end
        total = total + c.count
        table.insert(list, c)
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return total, list
end

-- Everything outside this character's bags + bank: the mailbox first, then
-- the alts. Returns total, list of { name, count, mailbox = true for the mailbox }
-- (alt entries are the ones from ns.CountAlts).
function ns.CountElsewhere(itemID)
    local lines = {}
    local mail = ns.CountMail(itemID)
    if mail > 0 then table.insert(lines, { name = L["Mailbox"], count = mail, mailbox = true }) end
    local alts, list = ns.CountAlts(itemID)
    for _, c in ipairs(list) do table.insert(lines, c) end
    return mail + alts, lines
end

-- "Name" colored by class when we know it.
function ns.CharName(entry)
    local name = entry and entry.name or "?"
    local cc = entry and entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
    if cc and cc.colorStr then return "|c" .. cc.colorStr .. name .. "|r" end
    return name
end

-- /dusty forget Name: drop a deleted or transferred character from the cache.
function ns.ForgetChar(who)
    who = type(who) == "string" and who:lower() or ""
    local chars = ns.db and ns.db.chars
    if who == "" or type(chars) ~= "table" then return 0 end
    local n = 0
    for key, rec in pairs(chars) do
        local name = type(rec) == "table" and type(rec.name) == "string" and rec.name:lower()
        local full = name and type(rec.last) == "string" and (name .. " " .. rec.last:lower())
        if key:lower() == who or name == who or full == who then
            chars[key] = nil
            n = n + 1
        end
    end
    return n
end

ns:On("PLAYER_LOGIN", function() C_Timer.After(5, function() requestScan("bags") end) end)
ns:On("BAG_UPDATE_DELAYED", function() requestScan("bags") end)
ns:On("PLAYERBANKSLOTS_CHANGED", function() requestScan("bags") end)
ns:On("BANKFRAME_OPENED", function() bankOpen = true requestScan("bags") end)
ns:On("BANKFRAME_CLOSED", function() scanNow("bags") bankOpen = false end)
ns:On("MAIL_SHOW", function() mailOpen = true end)
ns:On("MAIL_INBOX_UPDATE", function() requestScan("mail") end)
ns:On("MAIL_CLOSED", function() mailOpen = false end) -- the inbox may read as empty once closed: no scan
-- No scan on PLAYER_LOGOUT: the bags already read as empty then, which wiped
-- every "bags" count (bag events keep the record current anyway).
-- Modern clients also announce the bank and mailbox this way.
local PIT = Enum and Enum.PlayerInteractionType
ns:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if not PIT or not kind then return end
    if kind == PIT.Banker then bankOpen = true requestScan("bags")
    elseif kind == PIT.MailInfo then mailOpen = true end -- MAIL_INBOX_UPDATE follows with the contents
end)
ns:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
    if not PIT or not kind then return end
    if kind == PIT.Banker then scanNow("bags") bankOpen = false
    elseif kind == PIT.MailInfo then mailOpen = false end
end)

---------------------------------------------------------------------------
-- Chat: open the chat box / put a link in it (the API moved to ChatFrameUtil)
---------------------------------------------------------------------------
function ns.OpenChat(text)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or _G.ChatFrame_OpenChat
    if open then pcall(open, text or "") end
end

-- Inserts the link into the open chat box, or opens chat with it.
function ns.InsertLink(link)
    if not link then return end
    local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or _G.ChatEdit_InsertLink
    if insert then
        local ok, done = pcall(insert, link)
        if ok and done then return end
    end
    ns.OpenChat(link)
end

-- Clickable recipe link ("[Tailoring: Bolt of Linen Cloth]") for a recipe spell.
function ns.RecipeLink(spellID)
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeLink then
        local ok, link = pcall(C_TradeSkillUI.GetRecipeLink, spellID)
        if ok and clean(link) and link ~= "" then return link end
    end
    local getLink = (C_Spell and C_Spell.GetSpellLink) or _G.GetSpellLink
    if getLink then
        local ok, link = pcall(getLink, spellID)
        if ok and clean(link) and link ~= "" then return link end
    end
end

-- A zone from our data (English name, Data\Places.lua) as the player's client
-- calls it: the map's own name on a non-English client, else the locale table.
function ns.ZoneName(name)
    if type(name) ~= "string" then return name end
    local id = ns.ZONE_MAPS and ns.ZONE_MAPS[name]
    if id and not ns.ClientIsEnglish() and C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, id)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    return L[name]
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
    local learnedNow = {}
    for _, id in ipairs(ids) do
        local ok2, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        if ok2 and type(info) == "table" and clean(info.learned) then
            learnedNow[id] = true
            if not ns.char.learned[id] then
                ns.char.learned[id] = true
                changed = true
            end
        end
    end
    -- Remember which profession's list we've read, so its unlearned recipes
    -- show as "not learned" even after the window closes. The profession is
    -- recognised by its recipes (a learned one from our roadmap), not by
    -- GetBaseProfessionInfo, whose IDs can differ on this client.
    for line, steps in pairs({ [ns.SKILL.TAILORING] = ns.TAILORING, [ns.SKILL.ENCHANTING] = ns.ENCHANTING }) do
        if not ns.char.scanned[line] then
            for _, s in ipairs(steps or {}) do
                if learnedNow[s.spell] then
                    ns.char.scanned[line] = true
                    changed = true
                    break
                end
            end
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
    ns.char.difficulty = nil -- v1.2.0 live recipe colours: Forever never reports them
    -- Character records before v1.2.2 were never saved right (empty realm, empty
    -- bags at logout, surname as realm): start over, each character refills on login.
    if (ns.db.charsVersion or 0) < 4 then ns.db.chars = {} ns.db.charsVersion = 4 end
    -- "/dusty locale deDE": a language other than the client's (nil = the client's).
    if type(ns.db.locale) == "string" then ns.SetLocale(ns.db.locale) end
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
            " " .. L["is ready. Type %s or click the minimap button."]:format(ns.Color("gold", "/dusty")))
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
    elseif msg:find("^forget%s") then
        local who = msg:match("^forget%s+(.-)$") or ""
        local n = ns.ForgetChar(who)
        print(ns.Color("violet", "Dusty") .. ns.Color("gold", "Thready") .. ": " ..
            (n > 0 and L["forgot %s's materials."]:format(who) or L["no saved character called %s."]:format(who)))
        return
    elseif msg == "locale" or msg:find("^locale%s") then
        -- /dusty locale deDE | frFR | enUS | auto (the client's language)
        local want = msg:match("^locale%s+(%S+)") or ""
        local codes = { auto = "auto", enus = "enUS", engb = "enUS", dede = "deDE", frfr = "frFR" }
        for code in pairs(ns.LOCALES) do codes[code:lower()] = code end
        local code = codes[want]
        if not code then
            local have = { "enUS" }
            for c in pairs(ns.LOCALES) do table.insert(have, c) end
            table.sort(have)
            print(ns.Color("violet", "DustyThready:") .. " /dusty locale " .. table.concat(have, " | ") .. " | auto  (" ..
                L["now: %s"]:format(ns.Locale()) .. ")")
            return
        end
        ns.db.locale = (code ~= "auto") and code or nil
        local used = ns.SetLocale(ns.db.locale)
        print(ns.Color("violet", "DustyThready:") .. " " .. L["Language: %s. Type /reload to update every text."]:format(used))
        ns:RequestRefresh()
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
    GameTooltip:AddLine(L["Click to open your Tailoring + Enchanting companion."], 1, 1, 1, true)
    GameTooltip:Show()
end
function DustyThready_OnCompartmentLeave() GameTooltip:Hide() end
