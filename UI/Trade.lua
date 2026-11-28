-- DustyThready: Enchanting service panel, docked to the right of the trade window.
-- Shows while you trade and know Enchanting: the enchants you know for the
-- item in their "Will not be traded" slot, mats (have/need), what they should
-- bring, mat cost and a fair tip, a one-click Enchant, and "Post my menu".
-- No secure frames here; it hangs off TradeFrame, never our main window.
local _, ns = ...
local L = ns.L
local UI, C = ns.UI, ns.C

local W = 300
local PAD = 10
local MAX_ROWS = 6
local BTN_W = 70

local panel
local tradeOpen = false

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function setEnabledLook(b, on)
    b:SetEnabled(on)
    b:SetAlpha(on and 1 or 0.55)
    b.text:SetTextColor(on and 1 or C.muted[1], on and 1 or C.muted[2], on and 1 or C.muted[3])
end

local function makeRow(p)
    local r = CreateFrame("Frame", nil, p, "BackdropTemplate")
    UI.Backdrop(r, C.panel, C.edge, 0.9)
    r:SetWidth(W - 2 * PAD)

    r.icon = UI.ItemButton(r, 20)
    r.icon:SetPoint("TOPLEFT", 6, -6)
    r.icon:HookScript("OnEnter", function(self)
        if not self.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.Color("gold", L["Shift-click: link the recipe."]), 1, 1, 1, true)
        GameTooltip:Show()
    end)

    r.btn = UI.Button(r, L["Enchant"], BTN_W, 20, nil, "primary")
    r.btn:SetPoint("TOPRIGHT", -6, -6)
    r.btn:RegisterForClicks("LeftButtonUp")
    r.btn:SetScript("OnClick", function(self)
        if r.enchant then ns.DoTradeEnchant(r.enchant) end
        C_Timer.After(0.3, function() ns:RequestRefresh() end)
    end)

    r.name = UI.Text(r, 12, C.text)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -3)
    r.name:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
    r.name:SetWordWrap(false)

    r.chips = CreateFrame("Frame", nil, r)
    r.chips:SetPoint("TOPLEFT", 32, -30)
    r.chips:SetSize(W - 2 * PAD - 38, 20)

    r.info = UI.Text(r, 10, C.muted)
    r.info:SetWidth(W - 2 * PAD - 38)
    r.info:SetSpacing(2)
    return r
end

local function onMenuClick(_, button)
    local prefix
    local who = ns.TradePartner()
    if button == "RightButton" or not who then prefix = "/2 " else prefix = "/w " .. who .. " " end
    local line = ns.ServiceMenu(prefix)
    if line then ns.OpenChat(line) end
end

local function build()
    local parent = _G.TradeFrame or UIParent
    local p = UI.Panel(parent, C.bg, C.violet, 0.97)
    panel = p
    p:SetWidth(W)
    p:SetHeight(80)
    p:EnableMouse(true)
    p:SetClampedToScreen(true)
    p:ClearAllPoints()
    if _G.TradeFrame then
        p:SetPoint("TOPLEFT", _G.TradeFrame, "TOPRIGHT", 4, 0)
    else
        p:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
    p:Hide()

    p.close = UI.Button(p, "x", 18, 18, function() p.dismissed = true p:Hide() end, "ghost")
    p.close:SetPoint("TOPRIGHT", -6, -6)
    p.close.tip = L["Hide for this trade."]

    p.menu = UI.Button(p, L["Post my menu"], 96, 18)
    p.menu:SetPoint("RIGHT", p.close, "LEFT", -4, 0)
    p.menu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p.menu:SetScript("OnClick", onMenuClick)
    p.menu.tip = L["Writes the enchants you know in a whisper to the person you're trading with."] ..
        "\n" .. L["Right-click: in trade chat (/2) instead."] .. "\n" .. L["You press Enter to send it."]

    p.title = UI.Text(p, 13, C.violet)
    p.title:SetPoint("TOPLEFT", PAD, -9)
    p.title:SetPoint("RIGHT", p.menu, "LEFT", -6, 0)
    p.title:SetWordWrap(false)
    p.title:SetText(L["Enchanting service"])

    p.item = UI.ItemButton(p, 28)
    p.itemName = UI.Text(p, 12, C.text)
    p.itemName:SetPoint("LEFT", p.item, "RIGHT", 8, 0)
    p.itemName:SetWidth(W - 2 * PAD - 36)
    p.itemName:SetWordWrap(true)

    p.status = UI.Text(p, 11, C.muted)
    p.status:SetWidth(W - 2 * PAD)
    p.status:SetSpacing(2)

    p.more = UI.Text(p, 10, C.muted)
    p.more:SetWidth(W - 2 * PAD)

    p.rows = UI.Pool(function() return makeRow(p) end)
    p.chipPool = UI.Pool(UI.MatChipFactory(p))
    return p
end

---------------------------------------------------------------------------
-- Filling
---------------------------------------------------------------------------
local function shortText(q)
    local parts, allOffered = {}, true
    for _, s in ipairs(q.short) do
        table.insert(parts, ("%d %s"):format(s.n, ns.ItemName(s.id)))
        if s.offered < s.n then allOffered = false end
    end
    local text = ns.Color("warn", L["They should bring: %s."]:format(table.concat(parts, ", ")))
    if allOffered then
        text = text .. "\n" .. ns.Color("text", L["They put them in this trade: press Trade, then trade again with the item."])
    else
        text = text .. "\n" .. L["Mats must be in your bags before you enchant: trade them first."]
        for _, s in ipairs(q.short) do
            if s.bank > 0 then text = text .. "\n" .. ns.Color("muted", L["(You have more in your bank.)"]) break end
        end
    end
    return text
end

local function fillRow(r, e, q, profOpen, combat)
    r.enchant = e
    r.icon:SetSpellIcon(e.spell)
    r.icon.spellID = e.spell
    r.icon.extra = nil
    r.name:SetText(e.key .. " - " .. ns.Color("violet", e.short))

    local chipW = W - 2 * PAD - 38
    local chipsH = UI.LayoutMats(r.chips, panel.chipPool, q.mats, chipW, 0, 0)
    r.chips:SetHeight(math.max(1, chipsH))

    local lines = {}
    if #q.mats == 0 then
        table.insert(lines, L["Mats: see the recipe in your Enchanting window."])
    end
    if q.cost then
        table.insert(lines, L["Mats ~ %s  ·  fair tip ~ %s"]:format(ns.Money(q.cost, true),
            ns.Color("gold", ns.Money(q.tip, true))))
    elseif #q.mats > 0 and ns.HasAuctionator() then
        table.insert(lines, L["No AH price yet for these mats."])
    end
    if #q.short > 0 then table.insert(lines, shortText(q)) end
    r.info:SetText(table.concat(lines, "\n"))
    r.info:ClearAllPoints()
    local infoY = 30 + (chipsH > 0 and (chipsH + 4) or 0)
    r.info:SetPoint("TOPLEFT", 32, -infoY)
    local infoH = #lines > 0 and r.info:GetStringHeight() or 0

    if combat then
        r.btn:SetLabel(L["In combat"])
        r.btn.tip = L["You can enchant after combat."]
        setEnabledLook(r.btn, false)
    elseif #q.short > 0 then
        r.btn:SetLabel(L["Need mats"])
        r.btn.tip = L["You're short of mats for this one (see below the reagents)."]
        setEnabledLook(r.btn, false)
    elseif not profOpen then
        r.btn:SetLabel(L["Open"])
        r.btn.tip = L["Opens Enchanting (needed to enchant from here). Then click again."]
        setEnabledLook(r.btn, true)
    else
        r.btn:SetLabel(L["Enchant"])
        r.btn.tip = L["Casts it on their item in the trade window."] ..
            "\n" .. L["If it already has an enchant, the game asks before replacing it."]
        setEnabledLook(r.btn, true)
    end

    local h = infoY + infoH + 8
    r:SetHeight(math.max(34, h))
    return r:GetHeight()
end

local function refresh()
    local p = panel
    if not p or not p:IsShown() then return end
    p.rows:Release()
    p.chipPool:Release()
    p.more:Hide()

    local known = ns.ServiceEnchants()
    setEnabledLook(p.menu, #known > 0)
    local who = ns.TradePartner()
    p.title:SetText(who and L["Enchanting for %s"]:format(who) or L["Enchanting service"])

    local y = 34
    local item = ns.TradeItem()
    local status
    local list = {}
    if item then
        p.item:ClearAllPoints()
        p.item:SetPoint("TOPLEFT", PAD, -y)
        p.item:SetItem(item.id, item.link)
        p.item:Show()
        local name = item.link
        if item.enchantment then
            name = name .. "\n" .. ns.Color("good", L["Pending: %s"]:format(item.enchantment))
        end
        p.itemName:SetText(name)
        p.itemName:Show()
        y = y + 34

        local noun = ns.SlotNoun(item.equipLoc)
        list = noun and ns.EnchantsFor(item.equipLoc) or {}
        if item.enchantment then
            status = ns.Color("good", L["Enchant applied. Both of you press Trade to finish."])
        elseif not noun then
            status = L["Nothing to enchant on this item (no enchant fits its slot)."]
        elseif #list == 0 then
            status = L["You don't know an enchant for a %s yet."]:format(noun)
            if not ns.ServiceScanned() then
                status = status .. " " .. L["Open your Enchanting window once so DustyThready can see your recipes."]
            end
        else
            status = L["Enchants you know for this %s. Mats come from your bags."]:format(noun)
        end
    else
        p.item:Hide()
        p.itemName:Hide()
        if #known == 0 and not ns.ServiceScanned() then
            status = L["Open your Enchanting window once so DustyThready can see which enchants you know."]
        elseif #known == 0 then
            status = L["You don't know an enchant that goes on an item yet."]
        else
            status = (#known == 1 and L["Ask them to put the item in the bottom slot (%s). You know %d enchant."]
                or L["Ask them to put the item in the bottom slot (%s). You know %d enchants."])
                :format(ns.Color("text", ns.NotTradedLabel()), #known)
        end
    end

    p.status:ClearAllPoints()
    p.status:SetPoint("TOPLEFT", PAD, -y)
    p.status:SetText(status or "")
    y = y + p.status:GetStringHeight() + 8

    if item and not item.enchantment then
        local offered = ns.TradeOffered()
        local profOpen = ns.ProfessionOpen("enchanting")
        local combat = InCombatLockdown()
        for i, e in ipairs(list) do
            if i > MAX_ROWS then
                p.more:ClearAllPoints()
                p.more:SetPoint("TOPLEFT", PAD, -y)
                p.more:SetText(L["+%d more in your Enchanting window."]:format(#list - MAX_ROWS))
                p.more:Show()
                y = y + p.more:GetStringHeight() + 6
                break
            end
            local r = p.rows:Get()
            r:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
            local h = fillRow(r, e, ns.ServiceQuote(e, offered), profOpen, combat)
            y = y + h + 4
        end
    end
    p:SetHeight(y + 6)
end

---------------------------------------------------------------------------
-- When to show
---------------------------------------------------------------------------
local function update()
    if not tradeOpen then
        if panel then panel:Hide() end
        return
    end
    if not ns.ProfessionSkill("ENCHANTING") then return end
    local p = panel or build()
    if p.dismissed then return end
    p:Show()
    refresh()
end

ns:On("TRADE_SHOW", function()
    tradeOpen = true
    if panel then panel.dismissed = false end
    update()
end)
ns:On("TRADE_CLOSED", function()
    tradeOpen = false
    update()
end)
ns:On("TRADE_TARGET_ITEM_CHANGED", function() update() end)
ns:On("DT_REFRESH", function()
    if tradeOpen then update() end
end)
