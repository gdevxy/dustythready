-- DustyThready: the main window (header, tab bar, content, footer).
local _, ns = ...
local UI, C = ns.UI, ns.C

ns.Tabs = {}      -- key -> { label, icon, build(content), refresh(content, snap) }
ns.TabOrder = {}

function ns.RegisterTab(key, def)
    ns.Tabs[key] = def
    table.insert(ns.TabOrder, key)
end

local W, H = 700, 520
local Main = {}
ns.Main = Main

local function savePosition(f)
    local point, _, rel, x, y = f:GetPoint()
    ns.db.window = { point, rel, x, y }
end

function Main:ResetPosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER")
end

local function greeting(snap)
    local hour = tonumber(date("%H")) or 12
    local hello = hour < 12 and "Good morning" or (hour < 18 and "Good afternoon" or "Good evening")
    local name = UnitName("player") or "friend"
    return ("%s, %s  ·  level %d  ·  %s"):format(hello, name, snap.level, ns.Money(snap.money, true))
end

function Main:Build()
    local f = CreateFrame("Frame", "DustyThreadyFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(W, H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    UI.Backdrop(f, C.bg, C.edge, 0.97)
    if ns.db.window then
        local p = ns.db.window
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3], p[4])
    else
        f:SetPoint("CENTER")
    end
    tinsert(UISpecialFrames, "DustyThreadyFrame")
    f:Hide()

    -- Header (drag handle)
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(58)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() savePosition(f) end)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetTexture("Interface\\Buttons\\WHITE8x8")
    hbg:SetGradient("HORIZONTAL", CreateColor(0.22, 0.13, 0.36, 1), CreateColor(0.10, 0.08, 0.15, 1))

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(44, 44)
    logo:SetPoint("LEFT", 10, 0)
    logo:SetTexture(ns.ICON)
    pcall(logo.SetMask, logo, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
    local ring = header:CreateTexture(nil, "OVERLAY")
    ring:SetSize(50, 50)
    ring:SetPoint("CENTER", logo)
    ring:SetAtlas("auctionhouse-itemicon-border-artifact", false)
    if not ring:GetAtlas() then ring:Hide() end

    local title = UI.Text(header, 20, C.text)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -3)
    title:SetText(ns.Color("violet", "Dusty") .. ns.Color("gold", "Thready"))
    self.subtitle = UI.Text(header, 11, C.muted)
    self.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButtonNoScripts")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() f:Hide() end)

    local gear = UI.Button(header, "Settings", 70, 20, function() self:ToggleSettings() end, "ghost")
    gear:SetPoint("RIGHT", close, "LEFT", -6, 0)

    -- Tab bar
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -8)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -10, -8)
    bar:SetHeight(28)
    self.tabButtons = {}
    local x = 0
    for _, key in ipairs(ns.TabOrder) do
        local def = ns.Tabs[key]
        local b = CreateFrame("Button", nil, bar)
        b:SetHeight(28)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", 8, 0)
        b.icon:SetTexture(def.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.text = UI.Text(b, 13, C.muted)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.text:SetText(def.label)
        b:SetWidth(b.text:GetStringWidth() + 40)
        b.line = b:CreateTexture(nil, "OVERLAY")
        b.line:SetTexture("Interface\\Buttons\\WHITE8x8")
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT", 4, 0)
        b.line:SetPoint("BOTTOMRIGHT", -4, 0)
        b.line:SetVertexColor(C.violet[1], C.violet[2], C.violet[3])
        b.badge = UI.Pill(b, C.warn)
        b.badge:SetPoint("TOPRIGHT", 4, 4)
        b.badge:Hide()
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + 4
        b:SetScript("OnClick", function() self:Select(key) PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end)
        b:SetScript("OnEnter", function(s) if self.current ~= key then s.text:SetTextColor(C.text[1], C.text[2], C.text[3]) end end)
        b:SetScript("OnLeave", function(s) if self.current ~= key then s.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end end)
        self.tabButtons[key] = b
    end
    local sep = UI.Divider(f)
    sep:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -10, 0)
    sep:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 10, 0)

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -10)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 30)
    self.content = content
    self.pages = {}

    -- Footer
    self.footer = UI.Text(f, 10, C.muted)
    self.footer:SetPoint("BOTTOMLEFT", 12, 10)
    self.footer:SetPoint("BOTTOMRIGHT", -12, 10)

    f:SetScript("OnShow", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_OPEN or 829)
        self:Refresh()
    end)
    f:SetScript("OnHide", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_CLOSE or 830)
        if self.settings then self.settings:Hide() end
        if ns.DEOverlay then ns.DEOverlay:Detach() end
    end)

    self:BuildSettings()
end

function Main:Page(key)
    local page = self.pages[key]
    if not page then
        page = CreateFrame("Frame", nil, self.content)
        page:SetAllPoints()
        page:Hide()
        ns.Tabs[key].build(page)
        self.pages[key] = page
    end
    return page
end

function Main:Select(key)
    if not ns.Tabs[key] then key = "today" end
    self.current = key
    ns.db.tab = key
    for k, b in pairs(self.tabButtons) do
        local on = k == key
        b.line:SetShown(on)
        local c = on and C.text or C.muted
        b.text:SetTextColor(c[1], c[2], c[3])
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.7)
    end
    for k, p in pairs(self.pages) do p:SetShown(k == key) end
    self:Page(key):Show()
    self:Refresh()
end

function Main:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    local snap = ns.Snapshot()
    self.subtitle:SetText(greeting(snap))
    local page = self:Page(self.current or "today")
    local def = ns.Tabs[self.current or "today"]
    if def.refresh then def.refresh(page, snap) end

    -- Badge on the Disenchant tab: how many items are waiting.
    local deBtn = self.tabButtons.disenchant
    if deBtn then
        local n = #ns.ScanBags()
        if n > 0 then deBtn.badge:SetLabel(tostring(n), C.warn) deBtn.badge:Show() else deBtn.badge:Hide() end
    end

    if ns.HasAuctionator() then
        self.footer:SetText("Prices: Auctionator's last AH scan (open the Auction House to refresh them).  ·  /dusty  ·  Shift-click any icon to link it")
    else
        self.footer:SetText("Tip: install Auctionator for live AH prices and profit estimates.  ·  /dusty  ·  Shift-click any icon to link it")
    end
end

function Main:Toggle(tab)
    if not self.frame then self:Build() end
    if self.frame:IsShown() and (not tab or tab == self.current) then
        self.frame:Hide()
        return
    end
    self.frame:Show()
    self:Select(tab or self.current or ns.db.tab or "today")
end

---------------------------------------------------------------------------
-- Settings popover (deliberately tiny)
---------------------------------------------------------------------------
function Main:BuildSettings()
    local s = UI.Panel(self.frame, C.panel, C.violet, 0.98)
    s:SetSize(260, 120)
    s:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -52)
    s:SetFrameLevel(self.frame:GetFrameLevel() + 30)
    s:Hide()
    self.settings = s
    local t = UI.Text(s, 13, C.gold)
    t:SetPoint("TOPLEFT", 12, -10)
    t:SetText("Settings")

    local function check(label, y, get, set)
        local cb = CreateFrame("CheckButton", nil, s, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", 8, y)
        local txt = UI.Text(s, 12, C.text)
        txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        txt:SetText(label)
        cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
        cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
        return cb
    end
    check("Minimap button", -32, function() return not ns.db.minimap.hide end,
        function(v) ns.db.minimap.hide = not v ns:Fire("DT_MINIMAP") end)
    check("Disenchant info in item tooltips", -58, function() return ns.db.tooltip end,
        function(v) ns.db.tooltip = v end)
    local reset = UI.Button(s, "Re-center window", 120, 20, function() ns.db.window = nil self:ResetPosition() end, "ghost")
    reset:SetPoint("BOTTOMLEFT", 12, 10)
end

function Main:ToggleSettings()
    self.settings:SetShown(not self.settings:IsShown())
end

ns:On("DT_REFRESH", function() Main:Refresh() end)
