-- DustyThready: the Craft button (+ enchant target chip) used by Today and Roadmap.
--
--   local ctl = UI.CraftControl(parent, wide)
--   ctl:Update(prof, step, crafts, snap)   -> returns the control's width
--
-- wide = true (Today card): [Craft] on [icon] Item name   (left-aligned)
-- wide = false (Roadmap):   [icon] [Craft]                 (anchor its right edge)
local _, ns = ...
local UI, C = ns.UI, ns.C

local BTN_W, H = 96, 22

---------------------------------------------------------------------------
-- Target picker (one shared popover)
---------------------------------------------------------------------------
local picker

local function buildPicker()
    local p = UI.Panel(UIParent, C.panel, C.violet, 0.98)
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:Hide()
    p.title = UI.Text(p, 12, C.violet)
    p.title:SetPoint("TOPLEFT", 10, -8)
    p.hint = UI.Text(p, 10, C.muted)
    p.hint:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -3)
    p.hint:SetWidth(260)
    p.rows = UI.Pool(function()
        local r = CreateFrame("Button", nil, p, "BackdropTemplate")
        UI.Backdrop(r, C.bg, C.edge, 0.6)
        r:SetSize(260, 24)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 4, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = UI.Text(r, 11, C.text)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetPoint("RIGHT", -70, 0)
        r.name:SetWordWrap(false)
        r.tag = UI.Text(r, 10, C.muted, "RIGHT")
        r.tag:SetPoint("RIGHT", -6, 0)
        r:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.panelHi[1], C.panelHi[2], C.panelHi[3], 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.c.link)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self)
            self:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.6)
            GameTooltip:Hide()
        end)
        return r
    end)
    local main = _G.DustyThreadyFrame
    if main then main:HookScript("OnHide", function() p:Hide() end) end
    return p
end

local function openPicker(anchor, step, st)
    picker = picker or buildPicker()
    if picker:IsShown() and picker.anchor == anchor then picker:Hide() return end
    picker.anchor = anchor
    picker.title:SetText("Enchant which " .. st.slot.noun .. "?")
    picker.hint:SetText("Leveling tip: any cheap one works. Enchanting a bag item binds it to you.")
    picker.rows:Release()
    local y = 8 + picker.title:GetStringHeight() + 3 + picker.hint:GetStringHeight() + 8
    for i, c in ipairs(st.targets) do
        if i > 12 then break end
        local r = picker.rows:Get()
        r.c = c
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 10, -y)
        r.icon:SetTexture(c.icon or 134400)
        r.name:SetText(c.link)
        local tag = c.equip and "equipped" or "in bags"
        if st.target and c.key == st.target.key then tag = ns.Color("good", "selected") end
        r.tag:SetText(tag)
        r:SetScript("OnClick", function()
            ns.SetCraftTarget(step, c)
            picker:Hide()
            if ns.Main then ns.Main:Refresh() end
        end)
        y = y + 26
    end
    picker:SetSize(280, y + 8)
    picker:ClearAllPoints()
    picker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    picker:Show()
end

---------------------------------------------------------------------------
-- The control
---------------------------------------------------------------------------
function UI.CraftControl(parent, wide)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(H)
    f.wide = wide

    f.btn = UI.Button(f, "Craft", BTN_W, H, nil, "primary")
    f.btn:RegisterForClicks("LeftButtonUp")
    f.btn:SetScript("OnClick", function()
        if f.prof and f.step then ns.DoCraft(f.prof, f.step, f.state, IsShiftKeyDown()) end
    end)

    f.target = UI.ItemButton(f, H)
    f.target:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and self.link and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) return end
        if f.state and f.state.targets and #f.state.targets > 0 then openPicker(self, f.step, f.state) end
    end)
    f.target.extra = ns.Color("gold", "Click to choose another item.")

    if wide then
        f.btn:SetPoint("LEFT")
        f.on = UI.Text(f, 11, C.muted)
        f.on:SetPoint("LEFT", f.btn, "RIGHT", 8, 0)
        f.on:SetText("on")
        f.target:SetPoint("LEFT", f.on, "RIGHT", 6, 0)
        f.targetName = CreateFrame("Button", nil, f)
        f.targetName:SetPoint("LEFT", f.target, "RIGHT", 6, 0)
        f.targetName:SetPoint("RIGHT", f, "RIGHT")
        f.targetName:SetHeight(H)
        f.targetName.text = UI.Text(f.targetName, 11, C.text)
        f.targetName.text:SetAllPoints()
        f.targetName.text:SetWordWrap(false)
        f.targetName:SetScript("OnClick", function() f.target:GetScript("OnClick")(f.target) end)
    else
        f.btn:SetPoint("RIGHT")
        f.target:SetPoint("RIGHT", f.btn, "LEFT", -6, 0)
    end

    function f:SetEnabledLook(on)
        self.btn:SetEnabled(on)
        self.btn:SetAlpha(on and 1 or 0.55)
        self.btn.text:SetTextColor(on and 1 or C.muted[1], on and 1 or C.muted[2], on and 1 or C.muted[3])
    end

    -- Returns the width the control takes.
    function f:Update(prof, step, crafts, snap)
        self.prof, self.step = prof, step
        local st = ns.CraftState(prof, step, crafts, snap)
        self.state = st
        self.btn:SetLabel(st.label)
        self.btn.tip = st.tip
        self:SetEnabledLook(st.enabled)

        local showTarget = st.slot and st.target
        self.target:SetShown(showTarget and true or false)
        if showTarget then self.target:SetItem(st.target.id, st.target.link) end
        if self.wide then
            self.on:SetShown(showTarget and true or false)
            self.targetName:SetShown(showTarget and true or false)
            if showTarget then
                self.targetName.text:SetText(st.target.link .. ns.Color("muted", st.target.equip and "  (equipped)" or ""))
            end
            return self:GetWidth()
        end
        local w = BTN_W + (showTarget and (H + 6) or 0)
        self:SetWidth(w)
        return w
    end
    return f
end
