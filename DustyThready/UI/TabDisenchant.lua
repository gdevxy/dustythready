-- DustyThready: "Disenchant" - every green/blue in your bags with what it
-- will turn into, whether that beats the vendor, and a one-click button.
-- Plus a cheat sheet of the whole disenchant table.
local _, ns = ...
local UI, C = ns.UI, ns.C

local pendingAfterCombat = false

---------------------------------------------------------------------------
-- One secure button, parented to UIParent and positioned by absolute
-- coordinates (no anchors), so our window never becomes "protected" and
-- can still be moved/closed in combat. It hovers over whichever
-- "Disenchant" button the mouse is on and runs:
--   /cast Disenchant
--   /use <bag> <slot>
---------------------------------------------------------------------------
local overlay = CreateFrame("Button", "DustyThreadyDisenchantButton", UIParent, "SecureActionButtonTemplate")
ns.DEOverlay = overlay
overlay:SetFrameStrata("DIALOG")
overlay:RegisterForClicks("AnyUp", "AnyDown")
overlay:SetAttribute("type", "macro")
overlay:Hide()

function overlay:Attach(target)
    if InCombatLockdown() or not target.macro or not target:IsVisible() then return end
    local s = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local l, b, w, h = target:GetRect()
    if not l then return end
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
    self:SetSize(w * s, h * s)
    self:SetAttribute("macrotext", target.macro)
    self.target = target
    self:Show()
end

function overlay:Detach()
    if InCombatLockdown() then return end
    self:Hide()
    self:SetAttribute("macrotext", nil)
    self.target = nil
end

overlay:SetScript("OnEnter", function(self)
    local t = self.target
    if t then
        t:GetScript("OnEnter")(t)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Click to disenchant", 1, 1, 1)
        GameTooltip:Show()
    end
end)
overlay:SetScript("OnLeave", function(self)
    local t = self.target
    GameTooltip:Hide()
    if t then t:GetScript("OnLeave")(t) end
    self:Detach()
end)
overlay:HookScript("PostClick", function() C_Timer.After(0.1, function() overlay:Detach() end) end)
ns:On("PLAYER_REGEN_DISABLED", function() overlay:Detach() end) -- still allowed in this handler

local function makeRow(parent)
    local r = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(r, C.panel, C.edge, 0.9)
    r:SetHeight(52)
    r.item = UI.ItemButton(r, 34)
    r.item:SetPoint("LEFT", 8, 0)
    r.name = UI.Text(r, 13, C.text)
    r.name:SetPoint("TOPLEFT", r.item, "TOPRIGHT", 8, 0)
    r.name:SetWordWrap(false)
    r.sub = UI.Text(r, 11, C.muted)
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.sub:SetWordWrap(false)

    -- Looks like a button; the real (secure) click comes from the overlay
    -- that slides over it on hover (see ns.DEOverlay below).
    r.de = UI.Button(r, "Disenchant", 96, 26, nil, "primary")
    r.de:SetPoint("RIGHT", -8, 0)
    r.de:HookScript("OnEnter", function(self) ns.DEOverlay:Attach(self) end)

    r.keep = UI.Button(r, "Keep", 48, 20, nil, "ghost")
    r.keep:SetPoint("RIGHT", r.de, "LEFT", -6, 0)
    r.keep.tip = "Never suggest disenchanting this item again (undo in the Cheat sheet view)."

    r.value = UI.Text(r, 11, C.text, "RIGHT")
    r.value:SetPoint("RIGHT", r.keep, "LEFT", -10, 0)
    r.value:SetWidth(120)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
    r.sub:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
    return r
end

local function verdict(pred)
    if not pred.ev then return ns.Color("muted", "no price data"), nil end
    local sell = pred.sell or 0
    local ev = pred.ev
    local line = ("DE ~ %s\n|cff%svendor %s|r"):format(ns.Money(ev, true), ns.HEX.muted, ns.Money(sell, true))
    if ev >= sell then return line, "de" end
    return line, "vendor"
end

local function buildBags(page)
    local v = CreateFrame("Frame", nil, page)
    v:SetPoint("TOPLEFT", 0, -32)
    v:SetPoint("BOTTOMRIGHT")
    v.summary = UI.Panel(v, { 0.14, 0.10, 0.22 }, C.violet)
    v.summary:SetPoint("TOPLEFT")
    v.summary:SetPoint("TOPRIGHT", -8, 0)
    v.summary:SetHeight(54)
    v.summary.text = UI.Text(v.summary, 12, C.text)
    v.summary.text:SetPoint("TOPLEFT", 12, -10)
    v.summary.text:SetPoint("RIGHT", -12, 0)
    v.summary.text:SetSpacing(3)
    v.scroll = UI.Scroll(v)
    v.scroll:SetPoint("TOPLEFT", v.summary, "BOTTOMLEFT", 0, -8)
    v.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    -- Rows move under the cursor when scrolling: never leave the overlay on a stale row.
    v.scroll:HookScript("OnVerticalScroll", function() overlay:Detach() end)
    v.scroll:HookScript("OnMouseWheel", function() overlay:Detach() end)
    v.rows = UI.Pool(function() return makeRow(v.scroll.child) end)
    v.empty = UI.Text(v, 13, C.muted, "CENTER")
    v.empty:SetPoint("CENTER", v.scroll, "CENTER")
    v.empty:SetWidth(420)
    return v
end

local function refreshBags(v, snap)
    if InCombatLockdown() then
        v.summary.text:SetText(ns.Color("warn", "In combat. The list will update when you're out of combat."))
        pendingAfterCombat = true
        return
    end
    local list = ns.ScanBags()
    overlay:Detach()
    v.rows:Release()
    local spell = ns.SpellName(ns.DISENCHANT_SPELL, "Disenchant")
    local w = v.scroll:GetWidth()
    if w < 50 then w = 660 end
    local y = 0
    local deCount, deValue, vendorValue = 0, 0, 0
    for _, e in ipairs(list) do
        local r = v.rows:Get()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetWidth(w)
        r.item:SetItem(e.id, e.link)
        r.name:SetText(ns.ItemText(e.id))
        local outs = {}
        for i, o in ipairs(e.pred.outcomes) do
            if i <= 3 then table.insert(outs, ns.OutcomeText(o, true)) end
        end
        r.sub:SetText(("lvl %d %s  ·  %s"):format(e.pred.level, e.pred.kind, table.concat(outs, "  ")))
        local text, best = verdict(e.pred)
        r.value:SetText(text)
        if best == "vendor" then r.value:SetTextColor(C.warn[1], C.warn[2], C.warn[3])
        else r.value:SetTextColor(C.good[1], C.good[2], C.good[3]) end
        if e.pred.ev then
            deValue = deValue + e.pred.ev
            vendorValue = vendorValue + (e.pred.sell or 0)
        end
        r.de.macro = ("/cast %s\n/use %d %d"):format(spell, e.bag, e.slot)
        r.de:SetShown(snap.canDisenchant)
        local id = e.id
        r.keep:SetScript("OnClick", function()
            ns.db.ignoredDE[id] = true
            ns:RequestRefresh()
        end)
        deCount = deCount + 1
        y = y + 56
    end
    v.scroll:SetContentHeight(y)

    if deCount == 0 then
        v.empty:SetText("Nothing to disenchant right now.\n\n|cff" .. ns.HEX.gold .. "Green and blue armor or weapons|r you loot or sew will show up here, with what they'll turn into.")
        v.empty:Show()
        v.summary.text:SetText(ns.Color("muted", "Your bags are clean."))
        return
    end
    v.empty:Hide()
    local totals, order = ns.ExpectedTotals(list)
    local parts = {}
    for i = 1, math.min(4, #order) do
        local id = order[i]
        table.insert(parts, ns.IconString(ns.ItemIcon(id), 14) .. " ~" .. math.floor(totals[id] + 0.5) .. " " .. ns.ItemName(id))
    end
    local line1 = ("%s ready  ·  expect  %s"):format(ns.Color("gold", deCount .. (deCount == 1 and " item" or " items")), table.concat(parts, "   "))
    local line2
    if deValue > 0 then
        local diff = deValue - vendorValue
        line2 = ("Worth ~ %s as reagents vs %s at the vendor  %s"):format(ns.Money(deValue, true), ns.Money(vendorValue, true),
            diff >= 0 and ns.Color("good", "(+" .. ns.Money(diff, true) .. " by disenchanting)") or ns.Color("warn", "(vendoring pays more this time)"))
    else
        line2 = ns.Color("muted", "Scan the AH with Auctionator to compare disenchant value vs. vendor price.")
    end
    if not snap.canDisenchant then
        line2 = ns.Color("warn", "Learn Enchanting (any trainer, no level needed) to disenchant. ") .. line2
    end
    v.summary.text:SetWidth(v.summary:GetWidth() - 24)
    v.summary.text:SetText(line1 .. "\n" .. line2)
    v.summary:SetHeight(math.max(54, v.summary.text:GetStringHeight() + 20))
end

---------------------------------------------------------------------------
-- Cheat sheet
---------------------------------------------------------------------------
local function buildSheet(page)
    local v = CreateFrame("Frame", nil, page)
    v:SetPoint("TOPLEFT", 0, -32)
    v:SetPoint("BOTTOMRIGHT")
    v.scroll = UI.Scroll(v)
    v.scroll:SetPoint("TOPLEFT")
    v.scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    local c = v.scroll.child

    v.intro = UI.Text(c, 12, C.text)
    v.intro:SetPoint("TOPLEFT", 0, 0)
    v.intro:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    v.intro:SetSpacing(3)
    v.intro:SetText(
        ns.Color("gold", "Green armor") .. ": 75% dust · 20% essence · 5% shard     " ..
        ns.Color("gold", "Green weapons") .. ": 20% dust · 75% essence · 5% shard\n" ..
        ns.Color("violet", "Blue") .. ": always a shard (tiny chance of Nexus Crystal at 51+)     " ..
        ns.Color("violet", "Purple") .. ": shards up to 50, Nexus Crystal above\n" ..
        ns.Color("muted", "Rows use the item's REQUIRED level, not item level. You can disenchant anything from Enchanting 1."))

    local header = {}
    v.rows = {}
    local cols = { { "Req. level", 70 }, { "Dust", 190 }, { "Essence", 200 }, { "Shard / Crystal", 180 } }
    local function cells(parent, y, values, color)
        local x = 8
        local out = {}
        for i, col in ipairs(cols) do
            local t = UI.Text(parent, 11, color or C.text)
            t:SetPoint("TOPLEFT", x, y)
            t:SetWidth(col[2])
            t:SetWordWrap(false)
            t:SetText(values[i] or "")
            out[i] = t
            x = x + col[2]
        end
        return out
    end
    local hdr = CreateFrame("Frame", nil, c)
    hdr:SetPoint("TOPLEFT", 0, -64)
    hdr:SetPoint("RIGHT", c, "RIGHT")
    hdr:SetHeight(20)
    header = cells(hdr, -4, { "REQ. LEVEL", "DUST", "ESSENCE", "SHARD / CRYSTAL" }, C.muted)
    v.header = header

    local y = 86
    for _, row in ipairs(ns.DE_ROWS) do
        local f = CreateFrame("Frame", nil, c, "BackdropTemplate")
        UI.Backdrop(f, C.panel, C.edge, 0.85)
        f:SetPoint("TOPLEFT", 0, -y)
        f:SetPoint("RIGHT", c, "RIGHT")
        f:SetHeight(24)
        f.row = row
        local function item(spec)
            return ns.IconString(ns.ItemIcon(spec[1]), 14) .. " " .. spec[2] .. "-" .. spec[3] .. " " .. ns.ItemName(spec[1])
        end
        local shard = ns.IconString(ns.ItemIcon(row.shard), 14) .. " " .. ns.ItemName(row.shard)
        if row.crystal then shard = shard .. " / " .. ns.IconString(ns.ItemIcon(row.crystal), 14) end
        f.cells = cells(f, -6, { row.lo .. "-" .. row.hi, item(row.dust), item(row.essence), shard })
        table.insert(v.rows, f)
        y = y + 26
    end

    v.ignoredTitle = UI.Text(c, 12, C.gold)
    v.ignoredTitle:SetPoint("TOPLEFT", 0, -(y + 12))
    v.ignoredTitle:SetText("Items you chose to keep")
    v.ignoredBox = CreateFrame("Frame", nil, c)
    v.ignoredBox:SetPoint("TOPLEFT", 0, -(y + 32))
    v.ignoredBox:SetPoint("RIGHT", c, "RIGHT")
    v.ignoredBox:SetHeight(24)
    v.ignoredPool = UI.Pool(function()
        local b = UI.Button(v.ignoredBox, "", 150, 22, nil, "ghost")
        b.tip = "Click to allow disenchant suggestions again."
        return b
    end)
    v.baseY = y + 32
    return v
end

local function refreshSheet(v, snap)
    for _, f in ipairs(v.rows) do
        local mine = snap.level >= f.row.lo - 4 and snap.level <= f.row.hi + 4
        if mine then
            f:SetBackdropBorderColor(C.violet[1], C.violet[2], C.violet[3], 1)
            f:SetBackdropColor(0.18, 0.13, 0.28, 0.95)
        else
            f:SetBackdropBorderColor(C.edge[1], C.edge[2], C.edge[3], 1)
            f:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.85)
        end
    end
    v.ignoredPool:Release()
    local x, rowY, n = 0, 0, 0
    local maxW = v.scroll:GetWidth()
    if maxW < 50 then maxW = 660 end
    for id in pairs(ns.db.ignoredDE) do
        local b = v.ignoredPool:Get()
        b:SetLabel(ns.ItemName(id))
        local bw = math.max(80, b.text:GetStringWidth() + 20)
        b:SetWidth(bw)
        if x > 0 and x + bw > maxW then x = 0 rowY = rowY + 26 end
        b:SetPoint("TOPLEFT", x, -rowY)
        x = x + bw + 4
        n = n + 1
        b:SetScript("OnClick", function() ns.db.ignoredDE[id] = nil ns:RequestRefresh() end)
    end
    v.ignoredTitle:SetShown(n > 0)
    v.scroll:SetContentHeight(v.baseY + rowY + 30)
end

---------------------------------------------------------------------------
local function build(page)
    page.mode = "bags"
    page.seg = UI.Segmented(page, { { "bags", "In my bags" }, { "sheet", "Cheat sheet" } }, function(key)
        page.mode = key
        ns.Main:Refresh()
    end)
    page.seg:SetPoint("TOPLEFT")
    page.bags = buildBags(page)
    page.sheet = buildSheet(page)
end

local function refresh(page, snap)
    page.seg:Select(page.mode)
    page.bags:SetShown(page.mode == "bags")
    page.sheet:SetShown(page.mode == "sheet")
    if page.mode == "bags" then refreshBags(page.bags, snap) else refreshSheet(page.sheet, snap) end
end

ns:On("PLAYER_REGEN_ENABLED", function()
    if pendingAfterCombat then pendingAfterCombat = false ns:RequestRefresh() end
end)
ns.RegisterTab("disenchant", { label = "Disenchant", icon = 132857, build = build, refresh = refresh })
