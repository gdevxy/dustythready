-- DustyThready: "Gold" - money ideas that fit Tailoring + Enchanting, made
-- concrete with your bags, your skills and Auctionator's AH prices.
local _, ns = ...
local UI, C = ns.UI, ns.C

local DUSTS = { 10940, 11083, 11137, 11176, 16204, 10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175,
                16202, 16203, 10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344, 20725 }

local function makeCard(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(f, C.panel, C.edge, 0.9)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(24, 24)
    f.icon:SetPoint("TOPLEFT", 12, -10)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = UI.Text(f, 14, C.gold)
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
    f.title:SetPoint("RIGHT", -140, 0)
    f.lead = UI.Text(f, 11, C.muted)
    f.lead:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.lead:SetPoint("RIGHT", -140, 0)
    f.body = UI.Text(f, 12, C.text)
    f.body:SetSpacing(4)
    f.btn = UI.Button(f, "", 120, 22, nil, "primary")
    f.btn:SetPoint("TOPRIGHT", -12, -12)
    return f
end

local function buildAd()
    local known = {}
    for _, spell in ipairs(ns.POPULAR_ENCHANTS) do
        if ns.KnowsSpell(spell) then
            local name = ns.SpellName(spell, "")
            name = name:gsub("^Enchant ", "")
            if name ~= "" then table.insert(known, name) end
        end
        if #known >= 5 then break end
    end
    return known
end

local function cards(snap)
    local out = {}
    local t, e = snap.tailoring, snap.enchanting

    -- 1. Disenchant vs vendor
    do
        local list = ns.ScanBags()
        local ev, sell, priced = 0, 0, 0
        for _, it in ipairs(list) do
            if it.pred.ev then ev = ev + it.pred.ev sell = sell + (it.pred.sell or 0) priced = priced + 1 end
        end
        local body
        if #list == 0 then
            body = "Every green you loot is worth more as dust than as vendor trash most of the time. Nothing in your bags right now."
        elseif priced > 0 then
            body = ("%d items in your bags: ~%s as reagents vs %s at the vendor.")
                :format(#list, ns.Money(ev, true), ns.Money(sell, true))
        else
            body = ("%d items in your bags could be disenchanted. Scan the AH with Auctionator to see what they're worth."):format(#list)
        end
        table.insert(out, { icon = 132857, title = "Never vendor a green again",
            lead = "Zero investment. The best money for a broke level 40.", body = body,
            btn = #list > 0 and "Disenchant tab" or nil, click = function() ns.Main:Select("disenchant") end })
    end

    -- 2. Enchant for tips
    if e then
        local known = buildAd()
        local body
        if #known > 0 then
            body = "You can sell these right now: " .. ns.Color("violet", table.concat(known, ", ")) ..
                ".\nStand near the bank / AH, people bring their own mats and tip you. Great while you wait for a group."
        else
            body = "Once you know Bracer - Strength, Boots - Lesser Agility or Cloak - Greater Defense, people will pay you to apply them with their own mats."
        end
        table.insert(out, { icon = 136244, title = "Enchant for tips",
            lead = "Your skill is the product. Customers bring the mats.", body = body,
            btn = #known > 0 and "Write my ad" or nil, click = function()
                local ad = "/2 Enchanter LF work! " .. table.concat(known, ", ") .. ". Your mats, tips appreciated - whisper me!"
                ns.OpenChat(ad)
            end })
    end

    -- 3. Surplus dust: what you have beyond what your Enchanting path still needs
    do
        local lines = {}
        for _, id in ipairs(DUSTS) do
            local have = ns.Count(id)
            if have > 0 then
                local need = e and ns.RemainingNeed("enchanting", e.skill, id) or 0
                local surplus = have - need
                if surplus > 0 then
                    local p = ns.AHPrice(id)
                    table.insert(lines, ("%s %s %s%s"):format(ns.IconString(ns.ItemIcon(id), 14), ns.Color("good", surplus), ns.ItemName(id),
                        p and ns.Color("muted", ("  ~ %s on the AH"):format(ns.Money(p * surplus, true))) or ""))
                elseif need > 0 then
                    table.insert(lines, ("%s %s %s  %s"):format(ns.IconString(ns.ItemIcon(id), 14), have, ns.ItemName(id),
                        ns.Color("warn", ("keep: your path still needs %d"):format(need))))
                end
            end
        end
        table.insert(out, { icon = 132858, title = "Sell your surplus reagents",
            lead = "Levelers always need dust. Sell what your own path won't use.",
            body = #lines > 0 and table.concat(lines, "\n") or "No dust or essence in your bags yet." })
    end

    -- 4. Crafts that sell
    do
        local lines = {}
        for _, craft in ipairs(ns.GOLD_CRAFTS) do
            local p = snap[craft.prof]
            local can = p and p.skill >= craft.skill
            local status
            if not p then status = ns.Color("muted", "needs " .. (craft.prof == "tailoring" and "Tailoring" or "Enchanting"))
            elseif not can then status = ns.Color("muted", ("at skill %d"):format(craft.skill))
            else
                local r = ns.CraftProfit(craft)
                if r.profit then
                    status = r.profit > 0 and ns.Color("good", "+" .. ns.Money(r.profit, true) .. " each")
                        or ns.Color("bad", ns.Money(r.profit, true) .. " each")
                elseif r.sale then status = ns.Color("text", "sells ~" .. ns.Money(r.sale, true))
                else status = ns.Color("muted", "no AH data yet") end
            end
            table.insert(lines, ("%s %s  %s\n     %s"):format(ns.IconString(ns.ItemIcon(craft.out), 14),
                ns.ItemText(craft.out), status, ns.Color("muted", craft.why)))
        end
        table.insert(out, { icon = 133639, title = "Crafts that sell",
            lead = "Profit = AH price after the 5% cut, minus what the mats would cost you.",
            body = table.concat(lines, "\n") })
    end

    -- 5. Bolts or cloth?
    do
        local lines = {}
        for _, b in ipairs(ns.BOLTS) do
            local pb, pc = ns.AHPrice(b.bolt), ns.AHPrice(b.cloth)
            if pb and pc then
                local inCloth = pc * b.n
                local verdict = pb * 0.95 > inCloth * 0.95 and ns.Color("good", "sell bolts") or ns.Color("text", "sell raw cloth")
                table.insert(lines, ("%s %s %s vs %d× %s %s  »  %s"):format(ns.IconString(ns.ItemIcon(b.bolt), 14), ns.ItemName(b.bolt),
                    ns.Money(pb, true), b.n, ns.ItemName(b.cloth), ns.Money(inCloth, true), verdict))
            end
        end
        table.insert(out, { icon = 132903, title = "Bolts or raw cloth?",
            lead = "Other tailors buy whichever saves them time. Check before you craft.",
            body = #lines > 0 and table.concat(lines, "\n") or "Open the Auction House with Auctionator once to get cloth prices." })
    end

    -- 6. Farm cloth at your level
    do
        local best
        for _, f in ipairs(ns.CLOTH_FARMS) do
            if snap.level >= f.lo - 2 and snap.level <= f.hi + 8 then best = f end
        end
        best = best or ns.CLOTH_FARMS[#ns.CLOTH_FARMS]
        local spots = {}
        for _, s in ipairs(best.spots) do
            if s[3] == "N" or s[3] == snap.faction then table.insert(spots, ns.Color("gold", s[1]) .. " (" .. s[2] .. ")") end
            if #spots >= 3 then break end
        end
        local p = ns.AHPrice(best.cloth)
        table.insert(out, { icon = ns.ItemIcon(best.cloth), title = "Quest where the cloth drops",
            lead = ("At level %d you loot %s%s. You need it, and so does everyone else."):format(snap.level, ns.ItemName(best.cloth),
                p and (" (~" .. ns.Money(p * 20, true) .. " a stack)") or ""),
            body = "Try: " .. table.concat(spots, ", ") .. ".",
            btn = "All spots", click = function() ns.Main:Select("places") end })
    end

    -- 7. Habits
    table.insert(out, { icon = 133784, title = "Little habits, real gold",
        lead = "What experienced sellers do without thinking.",
        body = table.concat({
            "- Post reagents in the stack sizes people craft with (5, 10, 20).",
            "- Undercut by a copper, not by half. Don't crash your own market.",
            "- Buy threads, dyes, vials and seeds from vendors. Never from the AH.",
            "- Before you vendor anything, hover it: DustyThready shows its disenchant value.",
            "- Bags and wands sell best in the evening, when alts and new players are online.",
        }, "\n") })
    return out
end

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
    local y = 0
    for _, d in ipairs(cards(snap)) do
        local f = page.cards:Get()
        f:SetPoint("TOPLEFT", 0, -y)
        f:SetWidth(w)
        f.icon:SetTexture(d.icon)
        f.title:SetText(d.title)
        f.lead:SetText(d.lead or "")
        f.title:SetWidth(w - 12 - 24 - 8 - 140)
        f.lead:SetWidth(w - 12 - 24 - 8 - 140)
        local top0 = math.max(34, 12 + f.title:GetStringHeight() + 3 + f.lead:GetStringHeight())
        f.body:ClearAllPoints()
        f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(top0 + 10))
        f.body:SetWidth(w - 24)
        f.body:SetText(d.body or "")
        if d.btn then
            f.btn:SetLabel(d.btn)
            f.btn:SetScript("OnClick", d.click)
            f.btn:Show()
        else
            f.btn:Hide()
        end
        local top = math.max(34, 12 + f.title:GetStringHeight() + 3 + f.lead:GetStringHeight())
        local h = top + 10 + f.body:GetStringHeight() + 14
        f:SetHeight(h)
        y = y + h + 8
    end
    page.scroll:SetContentHeight(y)
end

ns.RegisterTab("gold", { label = "Gold", icon = 133784, build = build, refresh = refresh })
