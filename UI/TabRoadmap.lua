-- DustyThready: "Roadmap" - the full 1-300 path for each profession, with
-- where you are, what each step costs, and how the steps link up.
local _, ns = ...
local UI, C = ns.UI, ns.C

local ROW_W_PAD = 12

local function makeRow(parent)
    local r = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(r, C.panel, C.edge, 0.9)
    r.range = UI.Text(r, 12, C.text, "CENTER")
    r.range:SetPoint("TOPLEFT", 8, -10)
    r.range:SetWidth(62)
    r.icon = UI.ItemButton(r, 28)
    r.icon:SetPoint("TOPLEFT", 74, -6)
    r.icon:HookScript("OnEnter", function(self)
        if self.spellID and not self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
            GameTooltip:Show()
        end
    end)
    r.title = UI.Text(r, 13, C.text)
    r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.mats = UI.Text(r, 11, C.muted)
    r.mats:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
    r.notes = UI.Text(r, 11, C.text)
    r.notes:SetPoint("TOPLEFT", r.mats, "BOTTOMLEFT", 0, -4)
    r.notes:SetSpacing(2)
    r.check = r:CreateTexture(nil, "OVERLAY")
    r.check:SetSize(16, 16)
    r.check:SetPoint("TOPRIGHT", -8, -8)
    r.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    return r
end

local function matsLine(step)
    local parts = {}
    for _, m in ipairs(step.mats) do
        local total = m[2] * step.count
        local have = ns.Count(m[1])
        local col = have >= total and ns.HEX.good or ns.HEX.muted
        table.insert(parts, ("%s|cff%s%d|r %s"):format(ns.IconString(ns.ItemIcon(m[1]), 13), col, total, ns.ItemName(m[1])))
    end
    return table.concat(parts, "   ")
end

local function notesFor(prof, step, snap)
    local notes = {}
    if step.rank then
        local r
        for _, rr in ipairs(ns.RANKS) do if rr.key == step.rank then r = rr end end
        if r then
            table.insert(notes, ns.Color("warn", ("Train %s first (skill %d, level %d)"):format(r.name, r.at, r.level)))
        end
    end
    local item = step.formula or step.pattern
    if item then
        if ns.KnowsSpell(step.spell) then
            table.insert(notes, ns.Color("good", "Recipe known"))
        else
            local src = ns.RecipeSource(item)
            local where = ""
            if src then
                for _, v in ipairs(src.where) do
                    if v[3] == "N" or v[3] == snap.faction then where = " · " .. v[1] .. ", " .. v[2] break end
                end
            end
            table.insert(notes, ns.Color("warn", "Needs " .. ns.ItemName(item)) .. ns.Color("muted", where))
        end
    end
    if prof == "tailoring" then
        local de = ns.StepDE(step)
        if de then
            local uses = ns.EnchantStepsUsing(de.reagent)
            local u = uses[1] and (" · Enchanting uses it at " .. uses[1].step.from .. "-" .. uses[1].step.to) or ""
            table.insert(notes, ns.Color("violet", ("Disenchants into ~%d %s"):format(math.floor(de.total + 0.5), ns.ItemName(de.reagent))) .. ns.Color("muted", u))
        end
    else
        local key = ns.KeyReagent(step)
        if key then
            local srcs = ns.TailoringSourcesOf(key)
            if #srcs > 0 then
                local names = {}
                for _, s in ipairs(srcs) do
                    if not s.alt then table.insert(names, ns.ItemName(s.step.out) .. " (" .. s.step.from .. ")") end
                end
                if #names > 0 then
                    table.insert(notes, ns.Color("gold", "Sew » DE for " .. ns.ItemName(key) .. ": ") .. ns.Color("muted", table.concat(names, ", ")))
                end
            end
        end
    end
    if step.tip then table.insert(notes, ns.Color("muted", step.tip)) end
    return table.concat(notes, "\n")
end

local function fillRow(r, prof, step, snap, isAlt, width)
    local skill = snap[prof] and snap[prof].skill
    local status = ns.StepStatus(step, skill)
    r:SetWidth(width - (isAlt and 40 or 0))
    r.range:SetText((isAlt and "|cff" .. ns.HEX.muted .. "or|r\n" or "") .. step.from .. "-" .. step.to)
    r.icon.spellID = step.spell
    if step.out then r.icon:SetItem(step.out) else r.icon:SetSpellIcon(step.spell) end
    local name = step.out and ns.ItemText(step.out) or ns.SpellName(step.spell, step.name)
    local crafts = (status == "now") and ns.RemainingCrafts(step, skill) or step.count
    local left = (status == "now") and (" |cff" .. ns.HEX.muted .. "(" .. crafts .. " left)|r") or ""
    r.title:SetText(("%s  |cff%s×%d|r%s"):format(name, ns.HEX.gold, step.count, left))
    local textW = r:GetWidth() - 74 - 28 - 8 - 32
    r.title:SetWidth(textW)
    r.mats:SetWidth(textW)
    r.notes:SetWidth(textW)
    r.mats:SetText(matsLine(step))
    local notes = notesFor(prof, step, snap)
    r.notes:SetText(notes)

    local h = 12 + r.title:GetStringHeight() + 4 + r.mats:GetStringHeight()
    local nh = r.notes:GetStringHeight()
    if notes ~= "" then h = h + 4 + nh end
    h = math.max(h + 10, 42)
    r:SetHeight(h)

    r.check:SetShown(status == "done")
    if status == "now" then
        r:SetBackdropBorderColor(C.violet[1], C.violet[2], C.violet[3], 1)
        r:SetBackdropColor(0.18, 0.13, 0.28, 0.95)
        r:SetAlpha(1)
        r.range:SetTextColor(C.violet[1], C.violet[2], C.violet[3])
    elseif status == "done" then
        r:SetBackdropBorderColor(C.edge[1], C.edge[2], C.edge[3], 0.6)
        r:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.6)
        r:SetAlpha(0.5)
        r.range:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    else
        r:SetBackdropBorderColor(C.edge[1], C.edge[2], C.edge[3], 1)
        r:SetBackdropColor(isAlt and C.bg[1] or C.panel[1], isAlt and C.bg[2] or C.panel[2], isAlt and C.bg[3] or C.panel[3], 0.9)
        r:SetAlpha(1)
        r.range:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
    return h, status
end

---------------------------------------------------------------------------
-- Shopping list popover
---------------------------------------------------------------------------
local function shoppingTotals(prof, snap)
    local p = snap[prof]
    local skill = p and p.skill or 0
    local cap = p and p.max or 75
    if cap <= skill then cap = math.min(300, skill + 75) end
    local totals, order = {}, {}
    for _, s in ipairs(ns.Steps(prof)) do
        if skill < s.to and s.from < cap then
            local crafts = ns.RemainingCrafts(s, skill)
            for _, m in ipairs(s.mats) do
                if not totals[m[1]] then totals[m[1]] = 0 table.insert(order, m[1]) end
                totals[m[1]] = totals[m[1]] + m[2] * crafts
            end
        end
    end
    -- Bolts: count the cloth they need too? No: the bolt steps already ask for cloth.
    return totals, order, cap
end

local function sendToAuctionator(prof, totals, order)
    local A = _G.Auctionator
    if not (A and A.API and A.API.v1 and A.API.v1.CreateShoppingList) then
        print(ns.Color("violet", "DustyThready:") .. " Auctionator isn't loaded.")
        return
    end
    local terms = {}
    for _, id in ipairs(order) do
        local src = ns.SOURCES[id]
        local missing = totals[id] - ns.Count(id)
        if missing > 0 and not (src and src.vendor) then
            local name = ns.ItemName(id)
            local term
            if A.API.v1.ConvertToSearchString then
                local ok, s = pcall(A.API.v1.ConvertToSearchString, ns.name, { searchString = name, isExact = true, quantity = missing })
                if ok then term = s end
            end
            table.insert(terms, term or ('"' .. name .. '"'))
        end
    end
    local listName = "DustyThready " .. (prof == "tailoring" and "Tailoring" or "Enchanting")
    local ok, err = pcall(A.API.v1.CreateShoppingList, ns.name, listName, terms)
    if ok then
        print(ns.Color("violet", "DustyThready:") .. (" Shopping list %s created in Auctionator (%d items). Open the AH » Shopping tab."):format(ns.Color("gold", listName), #terms))
    else
        print(ns.Color("violet", "DustyThready:") .. " couldn't create the list: " .. tostring(err))
    end
end

local function buildShopping(page)
    local s = UI.Panel(page, C.panel, C.gold, 0.99)
    s:SetSize(330, 360)
    s:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -30)
    s:SetFrameLevel(page:GetFrameLevel() + 20)
    s:EnableMouse(true)
    s:Hide()
    s.title = UI.Text(s, 13, C.gold)
    s.title:SetPoint("TOPLEFT", 12, -10)
    local x = UI.Button(s, "Close", 50, 18, function() s:Hide() end, "ghost")
    x:SetPoint("TOPRIGHT", -8, -8)
    s.body = UI.Scroll(s)
    s.body:SetPoint("TOPLEFT", 10, -34)
    s.body:SetPoint("BOTTOMRIGHT", -16, 44)
    s.lines = UI.Pool(function()
        local f = CreateFrame("Frame", nil, s.body.child)
        f:SetHeight(22)
        f.btn = UI.ItemButton(f, 20)
        f.btn:SetPoint("LEFT")
        f.text = UI.Text(f, 11, C.text)
        f.text:SetPoint("LEFT", f.btn, "RIGHT", 6, 0)
        f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
        f.text:SetWordWrap(false)
        return f
    end)
    s.send = UI.Button(s, "Send to Auctionator", 150, 24, nil, "primary")
    s.send:SetPoint("BOTTOMLEFT", 12, 10)
    s.send.tip = "Creates an Auctionator shopping list with everything you're missing (vendor items excluded)."
    s.cost = UI.Text(s, 11, C.muted, "RIGHT")
    s.cost:SetPoint("BOTTOMRIGHT", -12, 16)

    function s:Fill(prof, snap)
        local totals, order, cap = shoppingTotals(prof, snap)
        self.title:SetText(("Shopping list · %s to %d"):format(prof == "tailoring" and "Tailoring" or "Enchanting", cap))
        self.lines:Release()
        local y, cost, unknown = 0, 0, false
        for _, id in ipairs(order) do
            local need, have = totals[id], ns.Count(id)
            local missing = math.max(0, need - have)
            local f = self.lines:Get()
            f:SetPoint("TOPLEFT", 0, -y)
            f:SetPoint("RIGHT", self.body.child, "RIGHT")
            f.btn:SetItem(id)
            local src = ns.SOURCES[id]
            f.btn.extra = src and ("|cff" .. ns.HEX.gold .. "Get it: |r" .. src[1]) or nil
            local tag = (src and src.vendor) and ns.Color("muted", " (vendor)") or ""
            if missing == 0 then
                f.text:SetText(ns.Color("good", "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t ") .. ns.ItemName(id) .. ns.Color("muted", (" %d/%d"):format(have, need)))
            else
                f.text:SetText(("%s %s%s %s"):format(ns.Color("warn", missing), ns.ItemName(id), tag, ns.Color("muted", ("(%d/%d)"):format(have, need))))
                local p = ns.AHPrice(id)
                if src and src.vendor then -- cheap, ignore
                elseif p then cost = cost + p * missing
                else unknown = true end
            end
            y = y + 24
        end
        self.body:SetContentHeight(y)
        self.cost:SetText(cost > 0 and ("AH cost ~ " .. ns.Money(cost, true) .. (unknown and "+" or "")) or "")
        self.send:SetScript("OnClick", function() sendToAuctionator(prof, totals, order) end)
        self.send:SetShown(ns.HasAuctionator())
    end
    return s
end

---------------------------------------------------------------------------
local function build(page)
    page.prof = UI.Segmented(page, { { "tailoring", "Tailoring" }, { "enchanting", "Enchanting" } }, function(key)
        ns.db.roadmapProf = key
        page.jump = true
        ns.Main:Refresh()
    end)
    page.prof:SetPoint("TOPLEFT", 0, 0)
    page.route = UI.Segmented(page, { { "dust", "Strange Dust route", 140 }, { "essence", "Magic Essence route", 150 } }, function(key)
        ns.db.enchantRoute = key
        ns.Main:Refresh()
    end)
    page.route:SetPoint("LEFT", page.prof, "RIGHT", 12, 0)
    page.route.buttons[1].tip = "Levels 20-150 with Strange Dust (what disenchanting armor gives most)."
    page.route.buttons[2].tip = "Levels 20-150 with Lesser Magic Essence (what disenchanting weapons gives most)."
    page.shopBtn = UI.Button(page, "Shopping list", 110, 22, function()
        if page.shop:IsShown() then page.shop:Hide() else page.shop:Fill(ns.db.roadmapProf, ns.Snapshot()) page.shop:Show() end
    end)
    page.shopBtn:SetPoint("TOPRIGHT", -8, 0)

    page.scroll = UI.Scroll(page)
    page.scroll:SetPoint("TOPLEFT", 0, -32)
    page.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    page.rows = UI.Pool(function() return makeRow(page.scroll.child) end)
    page.shop = buildShopping(page)
    page.jump = true
    page:HookScript("OnShow", function() page.jump = true end)
end

local function refresh(page, snap)
    local prof = ns.db.roadmapProf or "tailoring"
    page.prof:Select(prof)
    page.route:SetShown(prof == "enchanting")
    page.route:Select(ns.db.enchantRoute)
    if page.shop:IsShown() then page.shop:Fill(prof, snap) end

    page.rows:Release()
    local w = page.scroll:GetWidth()
    if w < 50 then w = 660 end
    local y, nowY = 0, nil
    for _, step in ipairs(ns.Steps(prof)) do
        local r = page.rows:Get()
        local h, status = fillRow(r, prof, step, snap, false, w)
        r:SetPoint("TOPLEFT", 0, -y)
        if status == "now" and not nowY then nowY = y end
        y = y + h + 6
        if step.alts then
            for _, alt in ipairs(step.alts) do
                local ar = page.rows:Get()
                local ah = fillRow(ar, prof, alt, snap, true, w)
                ar:SetPoint("TOPLEFT", 40, -y)
                y = y + ah + 6
            end
        end
    end
    page.scroll:SetContentHeight(y)
    if page.jump then
        page.jump = false
        page.scroll:ScrollTo((nowY or 0) - 8)
    end
end

ns.RegisterTab("roadmap", { label = "Roadmap", icon = 134327, build = build, refresh = refresh })
