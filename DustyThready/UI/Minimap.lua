-- DustyThready: a round minimap button (drag to move around the minimap).
local _, ns = ...

local btn

local function position()
    local angle = math.rad(ns.db.minimap.angle or 205)
    local r = (Minimap:GetWidth() / 2) + 6
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function create()
    btn = CreateFrame("Button", "DustyThreadyMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ns.ICON)
    pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.Toggle("disenchant") else ns.Toggle() end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.Color("violet", "Dusty") .. ns.Color("gold", "Thready"))
        local snap = ns.Snapshot()
        for _, prof in ipairs({ "tailoring", "enchanting" }) do
            local p = snap[prof]
            local label = prof == "tailoring" and ns.Color("gold", "Tailoring") or ns.Color("violet", "Enchanting")
            if p then
                local step = ns.CurrentStep(prof, p.skill)
                local next = step and (ns.Color("muted", "  next: ") .. (step.out and ns.ItemName(step.out) or ns.SpellName(step.spell, step.name))) or ""
                GameTooltip:AddLine(("%s %d/%d%s"):format(label, p.skill, p.max, next), 1, 1, 1)
            else
                GameTooltip:AddLine(label .. ns.Color("muted", "  not learned"), 1, 1, 1)
            end
        end
        local n = #ns.ScanBags()
        if n > 0 then GameTooltip:AddLine(ns.Color("warn", n .. " item(s) to disenchant")) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.Color("muted", "Click: open  ·  Right-click: disenchant  ·  Drag: move"))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            position()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    position()
end

local function update()
    if not btn then create() end
    btn:SetShown(not ns.db.minimap.hide)
end

ns:On("DT_READY", update)
ns:On("DT_MINIMAP", update)
