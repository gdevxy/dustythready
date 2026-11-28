-- DustyThready: "Disenchant" - every green/blue in your bags with what it
-- will turn into, whether the AH or the vendor pays more, a one-click button
-- and a "Disenchant next item" key binding. Plus a cheat sheet of the whole
-- disenchant table.
local _, ns = ...
local L = ns.L
local UI, C = ns.UI, ns.C

local pendingAfterCombat = false
local ROW_H = 60

---------------------------------------------------------------------------
-- Sell on the AH, disenchant, or vendor? Shared with UI/Tooltip.lua.
---------------------------------------------------------------------------
local AH_CUT = 0.95          -- the AH keeps 5% of a sale
local boundLinks = {}        -- links seen soulbound in the last bag scan
local RawItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local function bindTypeOf(item)
    if not item or not RawItemInfo then return nil end
    local ok, bind = pcall(function() return (select(14, RawItemInfo(item))) end)
    if ok then return ns.clean(bind) end
end

-- True when this item (or this copy in bag/slot) can't go on the AH:
-- bind on pickup, quest, account-bound, or a BoE that is already soulbound.
function ns.IsItemBound(item, bag, slot, containerInfo)
    local bt = bindTypeOf(item)
    if bt == 1 or bt == 4 or (type(bt) == "number" and bt >= 7) then return true end
    if containerInfo and ns.clean(containerInfo.isBound) then return true end
    if bag and slot and C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, res = pcall(function() return C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, slot)) end)
        if ok and ns.clean(res) then return true end
    end
    if type(item) == "string" and boundLinks[item] then return true end
    return false
end

-- Auctionator's price for the item itself (by link first: random-suffix greens differ).
function ns.ItemAHPrice(id, link)
    local A = _G.Auctionator
    local api = A and A.API and A.API.v1
    if not api then return nil end
    if type(link) == "string" and api.GetAuctionPriceByItemLink then
        local ok, p = pcall(api.GetAuctionPriceByItemLink, ns.name, link)
        if ok then
            if type(p) == "number" and p > 0 then return p end
            return nil
        end
    end
    if id then return ns.AHPrice(id) end
end

-- The reagent of this item that your Enchanting path still needs most
-- (beyond what you already have): { id, need } or nil.
local function pathNeed(pred, snap)
    local e = snap and snap.enchanting
    if not (pred and e and e.skill) or e.skill >= 300 then return nil end
    local best
    for _, o in ipairs(pred.outcomes) do
        if o.chance >= 0.15 then
            local need = ns.RemainingNeed("enchanting", e.skill, o.id) - ns.Count(o.id)
            if need > 0 and (not best or need > best.need) then best = { id = o.id, need = need } end
        end
    end
    return best
end

-- What to do with this item, by what matters to you:
--   "progress"  disenchant: your Enchanting still needs its reagents
--   "gold"      disenchant: its reagents sell for more than the vendor pays
--   "ah"        sell the item on the AH (it's worth more than its reagents)
--   "vendor"    the vendor pays more than its reagents are worth
--   nil         no prices to decide (scan the AH)
-- Returns { best, ah, net, de, vendor, bound, need = {id, need}, buyInstead }.
-- The AH price counts the 5% cut; soulbound items never get an AH price.
function ns.DESellChoice(id, link, pred, bound, snap)
    snap = snap or ns.Snapshot()
    local v = { de = pred and pred.ev, vendor = (pred and pred.sell) or 0, bound = bound and true or false }
    if not bound then v.ah = ns.ItemAHPrice(id, link) end
    local net = v.ah and v.ah * AH_CUT
    v.net = net
    local canDE = snap and snap.canDisenchant
    v.need = canDE and pathNeed(pred, snap) or nil
    if v.need then
        -- Leveling first, unless the item sells for far more than the reagents
        -- cost: then selling it and buying the reagents is clearly better.
        if net and v.de and net >= 2 * v.de and net - v.de >= 5000 then
            v.best, v.buyInstead = "ah", true
        else
            v.best = "progress"
        end
    elseif net and net > (v.de or 0) and net > v.vendor then v.best = "ah"
    elseif canDE and v.de and v.de > v.vendor then v.best = "gold"
    elseif v.de or not canDE then v.best = "vendor"
    end
    return v
end

-- Built again on DT_READY: the saved "/dusty locale" is only applied then
-- (saved variables load after every file has run).
local function buildBestLabels()
    ns.DE_BEST_LABEL = {
        progress = ns.Color("violet", "» " .. L["Disenchant"]),
        gold = ns.Color("good", "» " .. L["Disenchant & sell"]),
        ah = ns.Color("gold", "» " .. L["Sell on AH"]),
        vendor = ns.Color("warn", "» " .. L["Vendor it"]),
    }
end
buildBestLabels()

local function money(c) return c and ns.Money(c, true) or "?" end

-- One plain sentence saying why (shared with the item tooltip).
function ns.DEReason(v)
    if v.best == "progress" then
        return L["Your Enchanting still needs %d %s."]:format(math.ceil(v.need.need), ns.ItemName(v.need.id))
    elseif v.best == "ah" and v.buyInstead then
        return L["Sells for %s on the AH, its reagents ~%s: sell it and buy the reagents."]:format(money(v.ah), money(v.de))
    elseif v.best == "ah" then
        return L["Sells for %s on the AH (reagents ~%s, vendor %s)."]:format(money(v.ah), money(v.de), money(v.vendor))
    elseif v.best == "gold" then
        return L["Its reagents sell for ~%s, the vendor pays %s."]:format(money(v.de), money(v.vendor))
    elseif v.best == "vendor" and v.de then
        return L["The vendor pays %s, its reagents only ~%s."]:format(money(v.vendor), money(v.de))
    elseif v.best == "vendor" then
        return L["The vendor pays %s."]:format(money(v.vendor))
    end
    return L["No AH prices yet: open the Auction House with Auctionator to decide."]
end

-- Display order of the verdicts (the "Disenchant next" key takes the first two).
local ORDER = { progress = 1, gold = 2, ah = 3, vendor = 4 }
local function orderOf(v) return ORDER[v.best or ""] or 5 end
local function isDE(v) return v.best == "progress" or v.best == "gold" end

-- Bag scan + verdicts, grouped by verdict. Returns list, the next item to
-- disenchant ("progress" or "gold", not locked) or nil, and the number of
-- items you should sell rather than disenchant.
function ns.DEQueue()
    local list = ns.ScanBags()
    local snap = ns.Snapshot()
    for k in pairs(boundLinks) do boundLinks[k] = nil end
    for i, e in ipairs(list) do
        e.order = i
        local cinfo
        if C_Container and C_Container.GetContainerItemInfo then
            local ok, ci = pcall(C_Container.GetContainerItemInfo, e.bag, e.slot)
            if ok and type(ci) == "table" then cinfo = ci end
        end
        e.locked = (cinfo and ns.clean(cinfo.isLocked)) and true or false
        e.bound = ns.IsItemBound(e.link or e.id, e.bag, e.slot, cinfo)
        if e.bound and e.link then boundLinks[e.link] = true end
        e.value = ns.DESellChoice(e.id, e.link, e.pred, e.bound, snap)
    end
    table.sort(list, function(a, b)
        local oa, ob = orderOf(a.value), orderOf(b.value)
        if oa ~= ob then return oa < ob end
        return a.order < b.order
    end)
    local nextE, sellCount = nil, 0
    for _, e in ipairs(list) do
        if not isDE(e.value) then sellCount = sellCount + 1
        elseif not nextE and not e.locked then nextE = e end
    end
    return list, nextE, sellCount
end

local function isBusy()
    if UnitCastingInfo then
        local ok, name = pcall(UnitCastingInfo, "player")
        if ok and ns.clean(name) then return true end
    end
    if UnitChannelInfo then
        local ok, name = pcall(UnitChannelInfo, "player")
        if ok and ns.clean(name) then return true end
    end
    return false
end

local function deMacro(bag, slot)
    return ("/cast %s\n/use %d %d"):format(ns.SpellName(ns.DISENCHANT_SPELL, "Disenchant"), bag, slot)
end

---------------------------------------------------------------------------
-- "Disenchant next" key binding (Bindings.xml): a hidden secure button,
-- parented to UIParent, clicked by the key. PreClick (out of combat) rescans
-- the bags and points its macro at the next item, or clears it while you are
-- already casting (so a spammed key never "/use"s, i.e. equips, an item).
---------------------------------------------------------------------------
local NEXT_BINDING = "CLICK DustyThreadyDENextButton:LeftButton"
BINDING_HEADER_DUSTYTHREADY = "DustyThready"
_G["BINDING_NAME_" .. NEXT_BINDING] = L["Disenchant next item"]
ns:On("DT_READY", function()
    _G["BINDING_NAME_" .. NEXT_BINDING] = L["Disenchant next item"]
    buildBestLabels()
end)

local nextBtn = CreateFrame("Button", "DustyThreadyDENextButton", UIParent, "SecureActionButtonTemplate")
ns.DENextButton = nextBtn
nextBtn:RegisterForClicks("AnyUp", "AnyDown")
nextBtn:SetAttribute("useOnKeyDown", false)
nextBtn:SetAttribute("type", "macro")
nextBtn:SetAttribute("macrotext", nil)
nextBtn:Hide()

nextBtn:SetScript("PreClick", function(self)
    if InCombatLockdown() then self.reason = "combat" return end
    local macro, reason
    if not ns.db then
        reason = "empty"
    elseif not ns.KnowsSpell(ns.DISENCHANT_SPELL) then
        reason = "nolearn"
    elseif isBusy() then
        reason = "busy"
    else
        local _, e, ahCount = ns.DEQueue()
        if e then macro = deMacro(e.bag, e.slot)
        else reason = (ahCount > 0) and "ah" or "empty" end
    end
    self.reason = reason
    self:SetAttribute("macrotext", macro)
end)

local MESSAGES = {
    combat = "Can't disenchant in combat.",
    nolearn = "Learn Enchanting (any trainer) to disenchant.",
    empty = "Nothing to disenchant in your bags.",
    ah = "Nothing left worth disenchanting: sell the rest (see the Disenchant tab).",
    -- (English keys: shown through L[] below)
}
local lastMessage = 0
nextBtn:SetScript("PostClick", function(self)
    local msg = self.reason and MESSAGES[self.reason] and L[MESSAGES[self.reason]]
    if not msg then return end
    local now = GetTime()
    if now - lastMessage < 1 then return end -- the key fires twice (down + up)
    lastMessage = now
    print(ns.IconString(ns.ICON, 14) .. " " .. ns.Color("violet", "DustyThready: ") .. msg)
end)

-- Clearing the macro is still allowed in this handler; in combat the key does nothing.
ns:On("PLAYER_REGEN_DISABLED", function() nextBtn:SetAttribute("macrotext", nil) end)
ns:On("UPDATE_BINDINGS", function() ns:RequestRefresh() end)

-- Bound key as display text ("F", "Shift-F"), or nil.
local function nextKeyText()
    if not GetBindingKey then return nil end
    local ok, key = pcall(GetBindingKey, NEXT_BINDING)
    key = ok and ns.clean(key) or nil
    if not key then return nil end
    if GetBindingText then
        local ok2, t = pcall(GetBindingText, key)
        if ok2 and type(t) == "string" and t ~= "" then return t end
    end
    return key
end

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
        GameTooltip:AddLine(L["Click to disenchant"], 1, 1, 1)
        GameTooltip:Show()
    end
end)
overlay:SetScript("OnLeave", function(self)
    local t = self.target
    GameTooltip:Hide()
    if t then t:GetScript("OnLeave")(t) end
    self:Detach()
end)
-- Already casting (a double click, or the key was just pressed)? Run nothing
-- this click: "/use" without the Disenchant cursor would equip the item.
overlay:HookScript("PreClick", function(self)
    if InCombatLockdown() then return end
    local t = self.target
    self:SetAttribute("macrotext", (t and t.macro and not isBusy()) and t.macro or nil)
end)
overlay:HookScript("PostClick", function() C_Timer.After(0.1, function() overlay:Detach() end) end)
ns:On("PLAYER_REGEN_DISABLED", function() overlay:Detach() end) -- still allowed in this handler

local function makeRow(parent)
    local r = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(r, C.panel, C.edge, 0.9)
    r:SetHeight(ROW_H)
    r.item = UI.ItemButton(r, 34)
    r.item:SetPoint("LEFT", 8, 0)
    r.name = UI.Text(r, 13, C.text)
    r.name:SetPoint("TOPLEFT", r.item, "TOPRIGHT", 8, 6)
    r.name:SetWordWrap(false)
    r.why = UI.Text(r, 11, C.text)
    r.why:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.why:SetWordWrap(false)
    r.sub = UI.Text(r, 10, C.muted)
    r.sub:SetPoint("TOPLEFT", r.why, "BOTTOMLEFT", 0, -3)
    r.sub:SetWordWrap(false)

    -- The advice is the bright (primary) button; the other option stays
    -- available as a quiet (ghost) one. Disenchant buttons only look like
    -- buttons: the real (secure) click comes from the overlay that slides
    -- over them on hover (see ns.DEOverlay above).
    local function deButton(style, w)
        local b = UI.Button(r, L["Disenchant"], w, 26, nil, style)
        b:HookScript("OnEnter", function(self) ns.DEOverlay:Attach(self) end)
        return b
    end
    r.deMain = deButton("primary", 96)          -- advice: disenchant
    r.deMain:SetPoint("RIGHT", -8, 0)
    r.deAlt = deButton("ghost", 90)             -- possible, not advised
    r.deAlt.tip = L["Not advised, but you can still disenchant it."]

    r.sell = UI.Button(r, L["Sell"], 96, 26, nil, "primary") -- advice: vendor it
    r.sell:SetPoint("RIGHT", -8, 0)

    r.value = UI.Text(r, 12, C.text, "CENTER")  -- advice you act on elsewhere ("» Sell on AH")
    r.value:SetPoint("RIGHT", -8, 0)
    r.value:SetWidth(96)

    r.keep = UI.Button(r, L["Hide"], 44, 20, nil, "ghost")
    r.keep.tip = L["Not selling or disenchanting this one: hide it from the list (undo in the Cheat sheet view)."]
    return r
end

-- Places a row's buttons from the right: main action, ghost Disenchant, Hide,
-- then the texts take what's left.
local function layoutRow(r, main, showAlt)
    local right = main
    if showAlt then
        r.deAlt:ClearAllPoints()
        r.deAlt:SetPoint("RIGHT", main, "LEFT", -6, 0)
        right = r.deAlt
    end
    r.deAlt:SetShown(showAlt and true or false)
    r.keep:ClearAllPoints()
    r.keep:SetPoint("RIGHT", right, "LEFT", -6, 0)
    r.name:SetPoint("RIGHT", r.keep, "LEFT", -8, 0)
    r.why:SetPoint("RIGHT", r.keep, "LEFT", -8, 0)
    r.sub:SetPoint("RIGHT", r.keep, "LEFT", -8, 0)
end

local function merchantOpen()
    return MerchantFrame and MerchantFrame:IsShown() and true or false
end
ns:On("MERCHANT_SHOW", function() ns:RequestRefresh() end)
ns:On("MERCHANT_CLOSED", function() ns:RequestRefresh() end)

-- Sells the item in bag/slot, only while a vendor is open (without one,
-- "using" an item would equip it) and only if it's still the same item.
local function sellItem(bag, slot, id)
    if InCombatLockdown() or not merchantOpen() then return end
    if not (C_Container and C_Container.UseContainerItem and C_Container.GetContainerItemID) then return end
    local ok, cur = pcall(C_Container.GetContainerItemID, bag, slot)
    if not ok or cur ~= id then ns:RequestRefresh() return end
    pcall(C_Container.UseContainerItem, bag, slot)
end

local function verdict(v)
    if not v.best then return ns.Color("muted", L["no price data"]) end
    return ns.DE_BEST_LABEL[v.best]
end

-- Section headers, one per verdict (built on refresh: locale may change).
local function sectionTitle(key, n, extra)
    if key == "progress" then
        return ns.Color("violet", L["Disenchant: your Enchanting needs these"]) .. (extra or "")
    elseif key == "gold" then
        return ns.Color("good", L["Disenchant and sell the reagents: worth more than the vendor pays"])
    elseif key == "ah" then
        return ns.Color("gold", L["Sell on the Auction House: worth more than its reagents"])
    elseif key == "vendor" then
        return ns.Color("warn", L["Sell to a vendor: the reagents aren't worth it"])
    end
    return ns.Color("muted", L["Not sure yet: scan the Auction House with Auctionator"])
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
    v.headers = UI.Pool(function()
        local t = UI.Text(v.scroll.child, 12, C.text)
        t:SetWordWrap(false)
        return t
    end)
    v.empty = UI.Text(v, 13, C.muted, "CENTER")
    v.empty:SetPoint("CENTER", v.scroll, "CENTER")
    v.empty:SetWidth(420)
    return v
end

local function refreshBags(v, snap)
    if InCombatLockdown() then
        v.summary.text:SetText(ns.Color("warn", L["In combat. The list will update when you're out of combat."]))
        pendingAfterCombat = true
        return
    end
    local list, nextE = ns.DEQueue()
    overlay:Detach()
    v.rows:Release()
    v.headers:Release()
    local w = v.scroll:GetWidth()
    if w < 50 then w = 660 end

    -- Group stats first (the progress header names what you still need).
    local groups = {}
    local function group(key)
        local g = groups[key]
        if not g then g = { n = 0, de = 0, ah = 0, vendor = 0, items = {} } groups[key] = g end
        return g
    end
    local biggest
    for _, e in ipairs(list) do
        local g = group(e.value.best or "unknown")
        g.n = g.n + 1
        g.de = g.de + (e.value.de or 0)
        g.ah = g.ah + (e.value.ah or 0)
        g.vendor = g.vendor + (e.value.vendor or 0)
        table.insert(g.items, e)
        local nd = e.value.need
        if e.value.best == "progress" and nd and (not biggest or nd.need > biggest.need) then biggest = nd end
    end

    local y, current = 0, nil
    for _, e in ipairs(list) do
        local key = e.value.best or "unknown"
        if key ~= current then
            current = key
            local extra
            if key == "progress" and biggest then
                extra = ns.Color("muted", "  " .. L["(still %d %s to go)"]:format(math.ceil(biggest.need), ns.ItemName(biggest.id)))
            end
            local h = v.headers:Get()
            h:SetPoint("TOPLEFT", 4, -(y + (y > 0 and 8 or 2)))
            h:SetPoint("RIGHT", v.scroll.child, "RIGHT", -4, 0)
            h:SetText(sectionTitle(key, groups[key].n, extra))
            y = y + (y > 0 and 28 or 22)
        end
        local r = v.rows:Get()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetWidth(w)
        r.item:SetItem(e.id, e.link)
        r.name:SetText(ns.ItemText(e.id))
        r.why:SetText(ns.DEReason(e.value))
        local outs = {}
        for i, o in ipairs(e.pred.outcomes) do
            if i <= 3 then table.insert(outs, ns.OutcomeText(o, true)) end
        end
        r.sub:SetText(L["lvl %d %s  ·  %s"]:format(e.pred.level, L[e.pred.kind], table.concat(outs, "  ")))
        local macro = deMacro(e.bag, e.slot)
        r.deMain.macro, r.deAlt.macro = macro, macro
        local best, canDE = e.value.best, snap.canDisenchant
        r.deMain:Hide() r.sell:Hide() r.value:Hide()
        local main
        if canDE and (isDE(e.value) or not best) then
            -- The advice is to disenchant (or no prices: disenchanting is the safe default).
            main = r.deMain
            layoutRow(r, main, false)
        elseif best == "vendor" then
            main = r.sell
            local open = merchantOpen()
            r.sell:SetAlpha(open and 1 or 0.45)
            r.sell.tip = open and L["Sell it to this vendor."] or L["Open a vendor to sell it here with one click."]
            local bag, slot, sid = e.bag, e.slot, e.id
            r.sell:SetScript("OnClick", function() sellItem(bag, slot, sid) end)
            layoutRow(r, main, canDE)
        else
            -- "» Sell on AH" (done at the Auction House), or no prices and no Enchanting.
            main = r.value
            r.value:SetText(verdict(e.value))
            layoutRow(r, main, canDE and best == "ah")
        end
        main:Show()
        local id = e.id
        r.keep:SetScript("OnClick", function()
            ns.db.ignoredDE[id] = true
            ns:RequestRefresh()
        end)
        y = y + ROW_H + 4
    end
    v.scroll:SetContentHeight(y)

    if #list == 0 then
        v.empty:SetText(L["Nothing to disenchant right now."] .. "\n\n" ..
            L["%sGreen and blue armor or weapons|r you loot or sew will show up here, with what they'll turn into."]:format("|cff" .. ns.HEX.gold))
        v.empty:Show()
        v.summary.text:SetText(ns.Color("muted", L["Your bags are clean."]))
        v.summary:SetHeight(54)
        return
    end
    v.empty:Hide()

    -- Summary: one line per thing to do, most useful first.
    local lines = {}
    local function count(n) return (n == 1 and L["%d item"] or L["%d items"]):format(n) end
    local g = groups.progress
    if g then
        local totals, order = ns.ExpectedTotals(g.items)
        local parts = {}
        for i = 1, math.min(2, #order) do
            local id = order[i]
            local n = math.floor(totals[id] + 0.5)
            if n > 0 then table.insert(parts, ns.IconString(ns.ItemIcon(id), 14) .. " ~" .. n .. " " .. ns.ItemName(id)) end
        end
        table.insert(lines, ns.Color("violet", L["Disenchant"]) .. " " .. ns.Color("gold", count(g.n)) .. " " ..
            L["for your Enchanting"] .. (#parts > 0 and ("  " .. table.concat(parts, "  ")) or ""))
    end
    g = groups.gold
    if g then
        table.insert(lines, ns.Color("good", L["Disenchant"]) .. " " .. ns.Color("gold", count(g.n)) .. " " ..
            L["and sell the reagents (~%s, vendor %s)"]:format(money(g.de), money(g.vendor)))
    end
    g = groups.ah
    if g then
        table.insert(lines, ns.Color("gold", L["Sell"]) .. " " .. ns.Color("gold", count(g.n)) .. " " ..
            L["on the Auction House (~%s)"]:format(money(g.ah)))
    end
    g = groups.vendor
    if g then
        table.insert(lines, ns.Color("warn", L["Vendor"]) .. " " .. ns.Color("gold", count(g.n)) .. " " ..
            L["(%s; their reagents are worth less)"]:format(money(g.vendor)))
    end
    g = groups.unknown
    if g then
        table.insert(lines, ns.Color("muted", L["%s need AH prices to decide: open the Auction House with Auctionator."]:format(count(g.n))))
    end
    if not snap.canDisenchant then
        table.insert(lines, ns.Color("warn", L["Learn Enchanting (any trainer, no level needed) to disenchant."]))
    end
    -- Key hint: the bound key and what it will disenchant, or how to bind it.
    if snap.canDisenchant and nextE then
        local key = nextKeyText()
        if key then
            table.insert(lines, L["Press %s to disenchant the next item: %s"]:format(ns.Color("gold", key), ns.ItemText(nextE.id)))
        else
            table.insert(lines, ns.Color("muted", L["Tip: bind a key to"] .. " ") .. ns.Color("gold", L["Disenchant next item"]) ..
                ns.Color("muted", " " .. L["(Options > Keybindings > AddOns > DustyThready) and just press it after crafting."]))
        end
    end
    v.summary.text:SetWidth(v.summary:GetWidth() - 24)
    v.summary.text:SetText(table.concat(lines, "\n"))
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
        ns.Color("gold", L["Green armor"]) .. ": " .. L["75% dust · 20% essence · 5% shard"] .. "     " ..
        ns.Color("gold", L["Green weapons"]) .. ": " .. L["20% dust · 75% essence · 5% shard"] .. "\n" ..
        ns.Color("violet", L["Blue"]) .. ": " .. L["always a shard (tiny chance of Nexus Crystal at 51+)"] .. "     " ..
        ns.Color("violet", L["Purple"]) .. ": " .. L["shards up to 50, Nexus Crystal above"] .. "\n" ..
        ns.Color("muted", L["Rows use the item's REQUIRED level, not item level. You can disenchant anything from Enchanting 1."]))

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
    header = cells(hdr, -4, { L["REQ. LEVEL"], L["DUST"], L["ESSENCE"], L["SHARD / CRYSTAL"] }, C.muted)
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
    v.ignoredTitle:SetText(L["Items you chose to keep"])
    v.ignoredBox = CreateFrame("Frame", nil, c)
    v.ignoredBox:SetPoint("TOPLEFT", 0, -(y + 32))
    v.ignoredBox:SetPoint("RIGHT", c, "RIGHT")
    v.ignoredBox:SetHeight(24)
    v.ignoredPool = UI.Pool(function()
        local b = UI.Button(v.ignoredBox, "", 150, 22, nil, "ghost")
        b.tip = L["Click to allow disenchant suggestions again."]
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
    page.seg = UI.Segmented(page, { { "bags", L["In my bags"] }, { "sheet", L["Cheat sheet"] } }, function(key)
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
