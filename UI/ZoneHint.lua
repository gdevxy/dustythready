-- DustyThready: a one-line chat hint when you enter a zone where the cloth
-- for your level drops (ns.CLOTH_FARMS) and you're still levelling Tailoring.
-- Once per zone per session, never in instances. Toggle: Settings popover
-- ("Cloth farm hints in chat", ns.db.zoneHints, default on).
local _, ns = ...
local L = ns.L

local shown = {}   -- zone name -> true (this session)

-- Bolt made from each cloth, so a step using bolts counts as using the cloth.
local function boltOf(cloth)
    for _, b in ipairs(ns.BOLTS or {}) do
        if b.cloth == cloth then return b.bolt end
    end
end

-- Skill range in which the Tailoring path still uses this cloth: from, to (or nil).
local function usedRange(cloth)
    local bolt = boltOf(cloth)
    local lo, hi
    local function scan(s)
        for _, m in ipairs(s.mats or {}) do
            if m[1] == cloth or (bolt and m[1] == bolt) then
                lo = (not lo or s.from < lo) and s.from or lo
                hi = (not hi or s.to > hi) and s.to or hi
                return
            end
        end
    end
    for _, s in ipairs(ns.TAILORING or {}) do
        scan(s)
        if s.alts then for _, a in ipairs(s.alts) do scan(a) end end
    end
    return lo, hi
end

-- Where the player is: zone text (for "once per zone"), the map name, and the
-- set of UiMapIDs from the player's map up to its zone (a city or sub-map
-- sits under its zone), so zones match by ID whatever the client language.
local function zoneName()
    local name
    local ids = {}
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        id = ok and ns.clean(id) or nil
        local depth = 0
        while type(id) == "number" and id > 0 and depth < 6 do
            ids[id] = true
            local ok2, info = pcall(C_Map.GetMapInfo, id)
            if not (ok2 and type(info) == "table") then break end
            if depth == 0 and type(info.name) == "string" and info.name ~= "" then name = info.name end
            -- Stop at the zone level: its parent is a continent.
            local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
            if type(info.mapType) == "number" and info.mapType <= zoneType then break end
            id = info.parentMapID
            depth = depth + 1
        end
    end
    local text = GetZoneText and GetZoneText()
    -- Prefer GetZoneText (the zone, not a sub-map); fall back to the map name.
    if text and text ~= "" then return text, name, ids end
    return name, nil, ids
end

-- Does a farm spot's zone (English name from Data\Places.lua) match where we are?
local function sameZone(spotZone, zone, alt, ids)
    local id = ns.ZONE_MAPS and ns.ZONE_MAPS[spotZone]
    if id and ids[id] then return true end
    return spotZone == zone or (alt ~= nil and spotZone == alt)
end

local function check()
    if not ns.db or ns.db.zoneHints == false then return end
    if IsInInstance then
        local ok, inside = pcall(IsInInstance)
        if ok and inside then return end
    end
    local snap = ns.Snapshot()
    local t = snap.tailoring
    if not t or t.skill >= 300 then return end
    local zone, alt, ids = zoneName()
    if not zone or shown[zone] then return end

    -- Best farm for this zone at my level (the bracket closest to my level wins).
    local best, bestSpot, bestDist
    for _, f in ipairs(ns.CLOTH_FARMS or {}) do
        if snap.level >= f.lo - 3 and snap.level <= f.hi + 5 then
            for _, s in ipairs(f.spots) do
                if sameZone(s[1], zone, alt, ids) and (s[3] == "N" or s[3] == snap.faction) then
                    local d = (snap.level < f.lo and f.lo - snap.level) or (snap.level > f.hi and snap.level - f.hi) or 0
                    if not bestDist or d < bestDist then best, bestSpot, bestDist = f, s, d end
                end
            end
        end
    end
    if not best then return end
    local lo, hi = usedRange(best.cloth)
    if hi and t.skill >= hi then return end   -- my Tailoring is past this cloth already
    shown[zone] = true
    local skillText = lo and (" " .. L["(Tailoring %d+)"]:format(lo)) or ""
    print(ns.Color("violet", "DustyThready:") .. " " .. L["%s here drop %s%s."]:format(L[bestSpot[2]],
        ns.Color("gold", ns.ItemName(best.cloth)), skillText))
end

local function later()
    -- Zone text settles a moment after the event.
    C_Timer.After(2, function()
        local ok, err = pcall(check)
        if not ok then geterrorhandler()(err) end
    end)
end

ns:On("ZONE_CHANGED_NEW_AREA", later)
ns:On("PLAYER_ENTERING_WORLD", later)
