-- DustyThready: a small, consistent widget kit (flat, dark, violet + gold).
local _, ns = ...
local L = ns.L
local C = ns.C
local UI = {}
ns.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function UI.Backdrop(f, bg, edge, alpha)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    bg = bg or C.panel
    edge = edge or C.edge
    f:SetBackdropColor(bg[1], bg[2], bg[3], alpha or 0.96)
    f:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

function UI.Panel(parent, bg, edge, alpha)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Backdrop(f, bg, edge, alpha)
    return f
end

function UI.Text(parent, size, color, justify, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 12, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    color = color or C.text
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    return fs
end

function UI.Divider(parent, color, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(WHITE)
    color = color or C.edge
    t:SetVertexColor(color[1], color[2], color[3], alpha or 0.6)
    t:SetHeight(1)
    return t
end

-- Flat button with a soft hover. style: "primary" | "ghost" | nil
function UI.Button(parent, label, width, height, onClick, style, template)
    local b = CreateFrame("Button", nil, parent, template and (template .. ",BackdropTemplate") or "BackdropTemplate")
    b:SetSize(width or 110, height or 24)
    local base = style == "primary" and { 0.36, 0.24, 0.58 } or (style == "ghost" and C.bg or C.panelHi)
    local edge = style == "primary" and C.violet or C.edge
    UI.Backdrop(b, base, edge, style == "ghost" and 0.4 or 1)
    b.text = UI.Text(b, 12, style == "primary" and { 1, 1, 1 } or C.text, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(label or "")
    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(base[1] + 0.08, base[2] + 0.07, base[3] + 0.10, 1)
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(base[1], base[2], base[3], style == "ghost" and 0.4 or 1)
        GameTooltip:Hide()
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:SetLabel(t) self.text:SetText(t) end
    return b
end

-- Small rounded-looking label ("pill").
function UI.Pill(parent, color)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    color = color or C.violet
    UI.Backdrop(f, { color[1] * 0.25, color[2] * 0.25, color[3] * 0.25 }, color, 0.95)
    f.text = UI.Text(f, 10, color, "CENTER")
    f.text:SetPoint("CENTER", 0, 0)
    f:SetHeight(16)
    function f:SetLabel(t, c)
        if c then
            self.text:SetTextColor(c[1], c[2], c[3])
            self:SetBackdropBorderColor(c[1], c[2], c[3], 1)
            self:SetBackdropColor(c[1] * 0.25, c[2] * 0.25, c[3] * 0.25, 0.95)
        end
        self.text:SetText(t)
        self:SetWidth(self.text:GetStringWidth() + 12)
    end
    return f
end

function UI.ProgressBar(parent, color)
    local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
    UI.Backdrop(bar, C.bg, C.edge, 1)
    bar:SetStatusBarTexture(WHITE)
    color = color or C.violet
    bar:SetStatusBarColor(color[1], color[2], color[3], 0.9)
    bar:SetMinMaxValues(0, 1)
    bar:SetHeight(10)
    -- soft sheen on top
    local sheen = bar:CreateTexture(nil, "OVERLAY")
    sheen:SetTexture(WHITE)
    sheen:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPLEFT")
    sheen:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "RIGHT")
    sheen:SetVertexColor(1, 1, 1, 0.12)
    -- "cap" marker (where the trainer rank stops you)
    bar.cap = bar:CreateTexture(nil, "OVERLAY")
    bar.cap:SetTexture(WHITE)
    bar.cap:SetVertexColor(C.warn[1], C.warn[2], C.warn[3], 0.9)
    bar.cap:SetWidth(2)
    bar.cap:SetPoint("TOP")
    bar.cap:SetPoint("BOTTOM")
    bar:SetScript("OnSizeChanged", function(self) self:SetCap(self.capFrac) end)
    function bar:SetCap(fraction)
        self.capFrac = fraction
        if not fraction or fraction >= 1 or self:GetWidth() <= 0 then self.cap:Hide() return end
        self.cap:ClearAllPoints()
        self.cap:SetPoint("TOP", self, "TOPLEFT", self:GetWidth() * fraction, 0)
        self.cap:SetPoint("BOTTOM", self, "BOTTOMLEFT", self:GetWidth() * fraction, 0)
        self.cap:Show()
    end
    return bar
end

-- Item icon that shows the item tooltip on hover; shift-click links it.
function UI.ItemButton(parent, size)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(size or 22, size or 22)
    UI.Backdrop(b, C.bg, C.edge, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = UI.Text(b, 10, { 1, 1, 1 }, "RIGHT", "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetScript("OnEnter", function(self)
        if not self.itemID and not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetItemByID(self.itemID) end
        if self.extra then GameTooltip:AddLine(" ") GameTooltip:AddLine(self.extra, 1, 1, 1, true) end
        -- extraLines = { { left, right }, ... } (right optional): e.g. counts on other characters
        if type(self.extraLines) == "table" and #self.extraLines > 0 then
            GameTooltip:AddLine(" ")
            for _, l in ipairs(self.extraLines) do
                if l[2] then GameTooltip:AddDoubleLine(l[1], l[2], 1, 1, 1, 1, 1, 1)
                else GameTooltip:AddLine(l[1], 1, 1, 1, true) end
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        -- IsModifiedClick("CHATLINK") only reports left clicks: check Shift ourselves for the right button.
        if IsModifiedClick("CHATLINK") or (button == "RightButton" and IsShiftKeyDown()) then
            -- Recipe buttons (Today / Roadmap): shift-click links the crafted item,
            -- shift-right-click the pattern/formula (or the recipe if it has none).
            local link
            if self.spellID then
                if button == "RightButton" then
                    local pinfo = self.patternID and ns.ItemInfo(self.patternID)
                    link = (pinfo and pinfo.link) or ns.RecipeLink(self.spellID)
                elseif not self.itemID then
                    link = ns.RecipeLink(self.spellID)
                end
            end
            if not link then
                local info = (not self.link and self.itemID) and ns.ItemInfo(self.itemID)
                link = self.link or (info and info.link)
            end
            ns.InsertLink(link)
        end
    end)
    function b:SetItem(id, link)
        self.itemID, self.link = id, link
        self.icon:SetTexture(id and ns.ItemIcon(id) or 134400)
        local info = id and ns.ItemInfo(id)
        local q = info and info.quality
        local col = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if col and q >= 2 then self:SetBackdropBorderColor(col.r, col.g, col.b, 1)
        else self:SetBackdropBorderColor(C.edge[1], C.edge[2], C.edge[3], 1) end
    end
    function b:SetSpellIcon(spellID)
        self.itemID, self.link = nil, nil
        local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        self.icon:SetTexture(icon or 136244)
    end
    return b
end

-- Scroll area with a slim custom scrollbar. Returns scrollFrame; put content
-- in scrollFrame.child and call scrollFrame:SetContentHeight(h).
function UI.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf.child = child

    local track = parent:CreateTexture(nil, "ARTWORK")
    track:SetTexture(WHITE)
    track:SetVertexColor(C.edge[1], C.edge[2], C.edge[3], 0.25)
    track:SetWidth(4)
    track:SetPoint("TOPLEFT", sf, "TOPRIGHT", 3, 0)
    track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 3, 0)

    local thumb = CreateFrame("Frame", nil, parent)
    thumb:SetWidth(4)
    local tt = thumb:CreateTexture(nil, "OVERLAY")
    tt:SetAllPoints()
    tt:SetTexture(WHITE)
    tt:SetVertexColor(C.violet[1], C.violet[2], C.violet[3], 0.7)
    thumb:EnableMouse(true)

    local function update()
        local h, view = child:GetHeight(), sf:GetHeight()
        local maxScroll = math.max(0, h - view)
        local cur = sf:GetVerticalScroll()
        if cur > maxScroll then cur = maxScroll sf:SetVerticalScroll(cur) end
        if maxScroll <= 0 then
            thumb:Hide() track:Hide()
            if cur ~= 0 then sf:SetVerticalScroll(0) end
            return
        end
        track:Show() thumb:Show()
        local th = math.max(20, view * view / h)
        thumb:SetHeight(th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -(view - th) * (cur / maxScroll))
    end
    sf.UpdateThumb = update

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 40)))
        update()
    end)
    sf:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
        update()
    end)
    -- Drag the thumb
    thumb:SetScript("OnMouseDown", function(self)
        local _, y0 = GetCursorPosition()
        local s0 = sf:GetVerticalScroll()
        self:SetScript("OnUpdate", function()
            local _, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            local h, view = child:GetHeight(), sf:GetHeight()
            local maxScroll = math.max(0, h - view)
            local th = self:GetHeight()
            local ratio = maxScroll / math.max(1, view - th)
            sf:SetVerticalScroll(math.min(maxScroll, math.max(0, s0 + (y0 - y) / scale * ratio)))
            update()
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)

    function sf:SetContentHeight(h)
        child:SetHeight(math.max(1, h))
        update()
    end
    function sf:ScrollToTop() self:SetVerticalScroll(0) update() end
    function sf:ScrollTo(y)
        local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, y)))
        update()
    end
    return sf
end

-- Simple object pool: pool:Get() returns a (shown) object, pool:Release() hides all.
function UI.Pool(factory)
    local pool = { items = {}, used = 0 }
    function pool:Get()
        self.used = self.used + 1
        local o = self.items[self.used]
        if not o then o = factory() self.items[self.used] = o end
        o:Show()
        return o
    end
    function pool:Release()
        for _, o in ipairs(self.items) do o:Hide() o:ClearAllPoints() end
        self.used = 0
    end
    return pool
end

-- Segmented control: options = { {key, label}, ... }
function UI.Segmented(parent, options, onChange)
    local f = CreateFrame("Frame", nil, parent)
    f.buttons = {}
    local x = 0
    for _, opt in ipairs(options) do
        local b = UI.Button(f, opt[2], opt[3] or 110, 22, function() f:Select(opt[1], true) end, "ghost")
        b:SetPoint("LEFT", x, 0)
        b.key = opt[1]
        x = x + (opt[3] or 110) - 1
        table.insert(f.buttons, b)
    end
    f:SetSize(x + 1, 22)
    function f:Select(key, user)
        self.value = key
        for _, b in ipairs(self.buttons) do
            if b.key == key then
                b:SetBackdropBorderColor(C.violet[1], C.violet[2], C.violet[3], 1)
                b.text:SetTextColor(1, 1, 1)
                b:SetBackdropColor(0.30, 0.20, 0.48, 1)
            else
                b:SetBackdropBorderColor(C.edge[1], C.edge[2], C.edge[3], 1)
                b.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                b:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.4)
            end
        end
        if user and onChange then onChange(key) end
    end
    -- keep the selected look after hover
    for _, b in ipairs(f.buttons) do
        b:HookScript("OnLeave", function() f:Select(f.value) end)
    end
    return f
end

-- Hovering the chip's text shows the same tooltip as its icon.
local function chipEnter(self)
    local fn = self.btn and self.btn:GetScript("OnEnter")
    if fn then fn(self.btn) end
end
local function chipLeave() GameTooltip:Hide() end

-- When you are short: what your mailbox and other characters hold.
-- Returns the " (+15 alts)" suffix and the tooltip lines, or "", nil.
local function elsewhere(id, have, need)
    if not ns.CountElsewhere then return "", nil end
    local ok, total, list = pcall(ns.CountElsewhere, id)
    if not ok or type(total) ~= "number" or total <= 0 or type(list) ~= "table" then return "", nil end
    local onlyMail = #list == 1 and list[1].mailbox
    local suffix = (" |cff%s(+%d %s)|r"):format(have + total >= need and ns.HEX.good or ns.HEX.violet,
        math.min(total, 9999), onlyMail and L["mail"] or L["alts"])
    local lines = { { "|cff" .. ns.HEX.gold .. L["Also on hand elsewhere:"] .. "|r" } }
    for i, c in ipairs(list) do
        if i > 8 then
            table.insert(lines, { "|cff" .. ns.HEX.muted .. L["and %d more"]:format(#list - 8) .. "|r" })
            break
        end
        local name = c.mailbox and L["Your mailbox"] or (ns.CharName and ns.CharName(c) or tostring(c.name))
        table.insert(lines, { name, tostring(c.count) })
    end
    return suffix, lines
end

-- A row of "have/need" reagent chips, wrapping inside width. Returns height.
function UI.LayoutMats(container, pool, mats, width, x0, y0)
    local x, y = x0 or 0, y0 or 0
    local rowH = 20
    for _, m in ipairs(mats) do
        local chip = pool:Get()
        chip:SetParent(container)
        chip.btn:SetItem(m.id)
        local need = m.need
        local ok = m.have >= need
        local col = ok and ns.HEX.good or ns.HEX.warn
        local more, lines = "", nil
        if not ok then more, lines = elsewhere(m.id, m.have, need) end
        chip.text:SetText(("|cff%s%d|r|cff%s/%d|r%s %s"):format(col, math.min(m.have, 9999), ns.HEX.muted, need, more, ns.ItemName(m.id)))
        local src = ns.SOURCES[m.id]
        chip.btn.extra = src and ("|cff" .. ns.HEX.gold .. L["Get it:"] .. " |r" .. L[src[1]]) or nil
        chip.btn.extraLines = lines
        if not chip.dtHover then
            chip.dtHover = true
            chip:SetScript("OnEnter", chipEnter)
            chip:SetScript("OnLeave", chipLeave)
        end
        chip:EnableMouse(lines ~= nil)
        local w = 24 + chip.text:GetStringWidth() + 12
        chip:SetWidth(w)
        if x + w > width and x > (x0 or 0) then
            x = x0 or 0
            y = y + rowH + 2
        end
        chip:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
        x = x + w + 4
    end
    if #mats == 0 then return 0 end
    return y + rowH - (y0 or 0)
end

function UI.MatChipFactory(parent)
    return function()
        local chip = CreateFrame("Frame", nil, parent)
        chip:SetHeight(20)
        chip.btn = UI.ItemButton(chip, 18)
        chip.btn:SetPoint("LEFT", 0, 0)
        chip.text = UI.Text(chip, 11, C.text)
        chip.text:SetPoint("LEFT", chip.btn, "RIGHT", 4, 0)
        chip.text:SetWordWrap(false)
        return chip
    end
end
