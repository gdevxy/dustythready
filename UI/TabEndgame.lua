-- DustyThready: "Endgame" - what now, once Tailoring or Enchanting reaches
-- 250+: Mooncloth cooldowns for all your tailors, the crafts that pay at the
-- top, and the famous patterns / formulas with where they come from.
-- Only shown in the tab bar when one of the two professions is 250 or more.
local _, ns = ...
local L = ns.L
local UI, C = ns.UI, ns.C

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t"

local function makeCard(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(f, C.panel, C.edge, 0.9)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(24, 24)
    f.icon:SetPoint("TOPLEFT", 12, -10)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = UI.Text(f, 14, C.gold)
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
    f.lead = UI.Text(f, 11, C.muted)
    f.lead:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.body = UI.Text(f, 12, C.text)
    f.body:SetSpacing(4)
    ns.EnableNpcLinks(f)
    return f
end

local function spellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end
    return 136244
end

local function whereText(p)
    local where = p.where and L[p.where] or ""
    if p.npc then
        local link = ns.NpcLink(p.npc, p.npc, "text")
        where = where ~= "" and (link .. ", " .. where) or link
    end
    return ns.Color("gold", L[p.src] .. ":") .. " " .. ns.Color("muted", where)
end

local function profitText(craft, snap)
    local p = snap[craft.prof]
    if not p then return ns.Color("muted", L["needs %s"]:format(L[craft.prof == "tailoring" and "Tailoring" or "Enchanting"])) end
    local r = ns.CraftProfit(craft)
    local status
    if r.profit then
        status = r.profit > 0 and ns.Color("good", L["%s each"]:format("+" .. ns.Money(r.profit, true)))
            or ns.Color("bad", L["%s each"]:format(ns.Money(r.profit, true)))
    elseif r.sale then
        status = ns.Color("text", L["sells ~%s"]:format(ns.Money(r.sale, true)))
    else
        status = ns.Color("muted", L["no AH data yet"])
    end
    if p.skill < craft.skill then status = status .. ns.Color("muted", "  (" .. L["at skill %d"]:format(craft.skill) .. ")") end
    return status
end

---------------------------------------------------------------------------
-- Cards
---------------------------------------------------------------------------
local function moonclothCard(snap)
    local M = ns.MOONCLOTH
    local E = ns.Endgame
    E.UpdateMooncloth()
    local tailors = E.Tailors()
    local t = snap.tailoring
    if not t and #tailors == 0 then return nil end

    local lines = {}
    local known = t and E.KnowsMooncloth()
    if t then
        if known then
            local mine
            for _, e in ipairs(tailors) do if e.me then mine = e end end
            local felcloth = ns.Count(M.felcloth)
            table.insert(lines, ("%s: %s   %s"):format(ns.Color("text", L["You"]), E.FormatLeft(mine and mine.left or 0),
                ns.Color(felcloth >= 2 and "muted" or "warn", L["you have %d Felcloth"]:format(felcloth))))
        else
            table.insert(lines, L["Learn it: %s from %s, %s%s."]:format(ns.ItemText(M.pattern), ns.NpcLink(M.vendor, M.vendor, "text"),
                L[M.where], t.skill < M.skill and (" " .. L["(needs Tailoring %d)"]:format(M.skill)) or ""))
        end
    end
    local realm = (GetRealmName and GetRealmName()) or ""
    for _, e in ipairs(tailors) do
        if not e.me then
            local who = E.ClassName(e) .. ((e.realm ~= "" and e.realm ~= realm) and ns.Color("muted", " - " .. e.realm) or "")
            table.insert(lines, ("%s: %s"):format(who, E.FormatLeft(e.left)))
        end
    end
    local craft = ns.ENDGAME_CRAFTS[1]
    local r = ns.CraftProfit(craft)
    if r.sale then
        table.insert(lines, ns.Color("muted", L["Mooncloth sells ~%s on the AH%s."]:format(ns.Money(r.sale, true),
            r.cost and L[", 2 Felcloth cost ~%s"]:format(ns.Money(r.cost, true)) or "")))
    end

    return { icon = ns.ItemIcon(M.item), title = ns.ItemName(M.item),
        lead = L["2 Felcloth into 1 Mooncloth, once every 4 days per tailor. Every Mooncloth recipe needs it."],
        body = table.concat(lines, "\n") }
end

local function craftsCard(snap)
    local lines = {}
    for _, craft in ipairs(ns.ENDGAME_CRAFTS) do
        if snap[craft.prof] then
            table.insert(lines, ("%s %s  %s\n     %s"):format(ns.IconString(ns.ItemIcon(craft.out), 14),
                ns.ItemText(craft.out), profitText(craft, snap), ns.Color("muted", L[craft.why])))
        end
    end
    if #lines == 0 then return nil end
    return { icon = 133784, title = L["Crafts that pay at the top"],
        lead = L["Profit = AH price after the 5% cut, minus what the mats would cost you."],
        body = table.concat(lines, "\n") }
end

local function patternsCard(snap)
    if not snap.tailoring then return nil end
    local lines = {}
    for _, p in ipairs(ns.ENDGAME_PATTERNS.tailoring) do
        local known = ns.KnowsSpell(p.spell)
        table.insert(lines, ("%s %s%s  %s\n     %s"):format(ns.IconString(ns.ItemIcon(p.out), 14), ns.ItemText(p.out),
            known and ("  " .. CHECK) or "", ns.Color("muted", L["skill %d"]:format(p.skill)), whereText(p)))
    end
    return { icon = ns.ItemIcon(14152), title = L["Patterns worth chasing"],
        lead = L["The robes and bags people still ask for. A check mark means you know it."],
        body = table.concat(lines, "\n") }
end

local function enchantsCard(snap)
    if not snap.enchanting then return nil end
    local lines = {}
    for _, p in ipairs(ns.ENDGAME_PATTERNS.enchanting) do
        local known = ns.KnowsSpell(p.spell)
        local name = ns.SpellName(p.spell, p.name)
        table.insert(lines, ("%s %s%s  %s\n     %s"):format(ns.IconString(spellIcon(p.spell), 14), ns.Color("violet", name),
            known and ("  " .. CHECK) or "", ns.Color("muted", (p.short and (L[p.short] .. "  ·  ") or "") .. L["skill %d"]:format(p.skill)),
            whereText(p)))
    end
    return { icon = 136244, title = L["Enchants people pay for"],
        lead = L["Players bring the mats and tip well for these. A check mark means you know it."],
        body = table.concat(lines, "\n") }
end

---------------------------------------------------------------------------
local function build(page)
    page.scroll = UI.Scroll(page)
    page.scroll:SetPoint("TOPLEFT")
    page.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    page.cards = UI.Pool(function() return makeCard(page.scroll.child) end)
end

local function refresh(page, snap)
    page.cards:Release()
    local w = page.scroll:GetWidth()
    if w < 50 then w = 660 end
    local list = {}
    for _, fn in ipairs({ moonclothCard, craftsCard, patternsCard, enchantsCard }) do
        local ok, d = pcall(fn, snap)
        if ok and d then table.insert(list, d)
        elseif not ok then geterrorhandler()(d) end
    end
    local y = 0
    for _, d in ipairs(list) do
        local f = page.cards:Get()
        f:SetPoint("TOPLEFT", 0, -y)
        f:SetWidth(w)
        f.icon:SetTexture(d.icon)
        f.title:SetWidth(w - 12 - 24 - 8 - 12)
        f.lead:SetWidth(w - 12 - 24 - 8 - 12)
        f.title:SetText(d.title)
        f.lead:SetText(d.lead or "")
        local top = math.max(34, 12 + f.title:GetStringHeight() + 3 + f.lead:GetStringHeight())
        f.body:ClearAllPoints()
        f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(top + 10))
        f.body:SetWidth(w - 24)
        f.body:SetText(d.body or "")
        local h = top + 10 + f.body:GetStringHeight() + 14
        f:SetHeight(h)
        y = y + h + 8
    end
    page.scroll:SetContentHeight(y)
end

local function visible(snap)
    local t, e = snap.tailoring, snap.enchanting
    return (t and t.skill >= 250) or (e and e.skill >= 250) or false
end

ns.RegisterTab("endgame", { label = "Endgame", icon = "Interface\\Icons\\INV_Fabric_Moonrag_01",
    build = build, refresh = refresh, visible = visible })
