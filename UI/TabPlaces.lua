-- DustyThready: "Where" - trainers, recipe sellers, supply vendors and cloth
-- farming spots, filtered to your faction, with your next stops on top.
local _, ns = ...
local UI, C = ns.UI, ns.C

local PROF_LABEL = { tailoring = "Tailoring", enchanting = "Enchanting" }
local PROF_COLOR = { tailoring = "gold", enchanting = "violet" }

local function makeBlock(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(f, C.panel, C.edge, 0.9)
    f.title = UI.Text(f, 13, C.text)
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetPoint("RIGHT", -12, 0)
    f.body = UI.Text(f, 12, C.text)
    f.body:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
    f.body:SetPoint("RIGHT", -12, 0)
    f.body:SetSpacing(4)
    ns.EnableNpcLinks(f)
    return f
end

local function factionOK(code, faction) return code == "N" or code == faction end

local function trainerLine(t)
    return ("%s  %s  %s"):format(ns.NpcLink(t[1], t[1], "text"), ns.Color("gold", t[2]), ns.Color("muted", "· " .. t[3]))
end

local function nextStops(snap)
    local lines = {}
    for _, prof in ipairs({ "tailoring", "enchanting" }) do
        local label = ns.Color(PROF_COLOR[prof], PROF_LABEL[prof])
        local p = snap[prof]
        local need = ns.TrainingNeed(prof, snap)
        if need then
            local ts = ns.TrainersFor(prof, need.rank.key, snap.faction)
            local who = ts[1] and (ns.NpcLink(ts[1][1]) .. " (" .. ts[1][2] .. ")") or "?"
            if need.notLearned then
                table.insert(lines, ("%s: learn it from %s. No level needed."):format(label, who))
            elseif need.ready then
                table.insert(lines, ("%s: %s - train %s with %s."):format(label, ns.Color("warn", "now"), need.rank.name, who))
            else
                table.insert(lines, ("%s: train %s at level %d with %s."):format(label, need.rank.name, need.levelNeeded, who))
            end
        elseif p and p.max < 300 then
            -- Next rank, so you can plan the trip
            for _, r in ipairs(ns.RANKS) do
                if r.cap > p.max then
                    local ts = ns.TrainersFor(prof, r.key, snap.faction)
                    local who = ts[1] and (ns.NpcLink(ts[1][1]) .. " (" .. ts[1][2] .. ")") or "?"
                    table.insert(lines, ("%s: %s at skill %d%s: %s."):format(label, r.name, r.at,
                        snap.level < r.level and (" and level " .. r.level) or "", who))
                    break
                end
            end
        end
        -- Recipes coming up within the next ~40 skill points
        if p then
            for _, s in ipairs(ns.Steps(prof)) do
                local item = s.formula or s.pattern
                if item and s.to > p.skill and s.from <= p.skill + 40 and not ns.KnowsSpell(s.spell) then
                    local src = ns.RecipeSource(item)
                    local where = {}
                    if src then
                        for _, w in ipairs(src.where) do
                            if factionOK(w[3], snap.faction) then table.insert(where, ns.NpcLink(w[1]) .. " (" .. w[2] .. ")") end
                        end
                    end
                    table.insert(lines, ("%s: buy %s before %d%s"):format(label, ns.Color("warn", ns.ItemName(item)), s.from,
                        #where > 0 and (" - " .. table.concat(where, ", ")) or ""))
                end
            end
        end
    end
    if #lines == 0 then table.insert(lines, ns.Color("good", "Nothing urgent. Keep crafting!")) end
    return lines
end

local function build(page)
    page.seg = UI.Segmented(page, { { "tailoring", "Tailoring" }, { "enchanting", "Enchanting" } }, function(key)
        page.prof = key
        ns.Main:Refresh()
    end)
    page.seg:SetPoint("TOPLEFT")
    page.factionNote = UI.Text(page, 11, C.muted, "RIGHT")
    page.factionNote:SetPoint("TOPRIGHT", -10, -4)
    page.scroll = UI.Scroll(page)
    page.scroll:SetPoint("TOPLEFT", 0, -32)
    page.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    page.blocks = UI.Pool(function() return makeBlock(page.scroll.child) end)
end

local function refresh(page, snap)
    page.prof = page.prof or (snap.enchanting and not snap.tailoring and "enchanting") or "tailoring"
    page.seg:Select(page.prof)
    page.factionNote:SetText(("Showing %s + neutral"):format(snap.faction == "H" and "Horde" or (snap.faction == "A" and "Alliance" or "all")))
    page.blocks:Release()
    local w = page.scroll:GetWidth()
    if w < 50 then w = 660 end
    local y = 0
    local function add(title, lines, highlight)
        local b = page.blocks:Get()
        b:SetPoint("TOPLEFT", 0, -y)
        b:SetWidth(w)
        b.title:SetWidth(w - 24)
        b.body:SetWidth(w - 24)
        b.title:SetText(title)
        b.body:SetText(table.concat(lines, "\n"))
        local h = 18 + b.title:GetStringHeight() + 8 + b.body:GetStringHeight() + 6
        b:SetHeight(h)
        if highlight then
            b:SetBackdropBorderColor(C.violet[1], C.violet[2], C.violet[3], 1)
            b:SetBackdropColor(0.14, 0.10, 0.22, 0.95)
        else
            b:SetBackdropBorderColor(C.edge[1], C.edge[2], C.edge[3], 1)
            b:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.9)
        end
        y = y + h + 8
    end

    add(ns.Color("warn", "Your next stops"), nextStops(snap), true)

    local prof = page.prof
    local p = snap[prof]
    for _, r in ipairs(ns.RANKS) do
        local list = ns.TrainersFor(prof, r.key, snap.faction)
        local lines = {}
        for _, t in ipairs(list) do table.insert(lines, trainerLine(t)) end
        if #lines == 0 then lines[1] = ns.Color("muted", "No trainer for your faction at this rank.") end
        local done = p and p.max >= r.cap
        local req = r.at > 0 and ("  |cff%sskill %d · level %d%s|r"):format(ns.HEX.muted, r.at, r.level,
            r.cost and (" · " .. ns.Money(r.cost)) or "") or ""
        local title = ("%s %s  |cff%s(to %d)|r%s%s"):format(PROF_LABEL[prof], r.name, ns.HEX.muted, r.cap, req,
            done and ("  " .. ns.Color("good", "trained")) or "")
        add(title, lines, false)
    end

    -- Recipes to buy/hunt
    local rl = {}
    for _, src in ipairs(ns.RECIPE_SOURCES) do
        if src.prof == prof then
            local known = ns.KnowsSpell(src.spell)
            local where = {}
            for _, wh in ipairs(src.where) do
                if factionOK(wh[3], snap.faction) then
                    table.insert(where, ns.NpcLink(wh[1]) .. " " .. ns.Color("gold", wh[2]) .. (wh[4] and ns.Color("muted", " (" .. wh[4] .. ")") or ""))
                end
            end
            table.insert(rl, ("%s %s  %s\n     %s%s"):format(
                known and ns.Color("good", "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t") or ns.Color("warn", "-"),
                ns.ItemText(src.item), ns.Color("muted", "for skill " .. src.skill),
                #where > 0 and table.concat(where, ";  ") or ns.Color("muted", "Other faction only"),
                src.note and ns.Color("muted", "  · " .. src.note) or ""))
        end
    end
    add((prof == "enchanting" and "Formulas" or "Patterns") .. " you'll need", rl, false)

    -- Vendor supplies
    local sl = {}
    for _, s in ipairs(ns.SUPPLIES) do
        table.insert(sl, ns.Color("gold", s[1]) .. "  " .. ns.Color("muted", ns.LinkNpcsIn(s[2])))
    end
    add("Vendor supplies " .. ns.Color("muted", "(never pay AH prices for these)"), sl, false)

    -- Cloth farming, nearest to your level first
    local farms = {}
    for _, f in ipairs(ns.CLOTH_FARMS) do table.insert(farms, f) end
    local lvl = snap.level
    table.sort(farms, function(a, b)
        local da = (lvl < a.lo and a.lo - lvl) or (lvl > a.hi and lvl - a.hi) or 0
        local db = (lvl < b.lo and b.lo - lvl) or (lvl > b.hi and lvl - b.hi) or 0
        if da ~= db then return da < db end
        return a.lo < b.lo
    end)
    local fl = {}
    for _, f in ipairs(farms) do
        local here = lvl >= f.lo - 3 and lvl <= f.hi + 5
        local spots = {}
        for _, s in ipairs(f.spots) do
            if factionOK(s[3], snap.faction) then table.insert(spots, ns.Color("gold", s[1]) .. ": " .. s[2]) end
        end
        table.insert(fl, ("%s %s %s  %s\n     %s"):format(
            ns.IconString(ns.ItemIcon(f.cloth), 14), ns.ItemText(f.cloth),
            ns.Color("muted", ("lvl %d-%d"):format(f.lo, f.hi)), here and ns.Color("good", "« your level") or "",
            table.concat(spots, ";  ")))
    end
    add("Where cloth drops " .. ns.Color("muted", "(any humanoid of that level drops it)"), fl, false)

    page.scroll:SetContentHeight(y)
end

ns.RegisterTab("places", { label = "Where", icon = 134269, build = build, refresh = refresh })
