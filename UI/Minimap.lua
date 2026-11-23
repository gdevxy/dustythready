-- DustyThready: minimap button through LibDataBroker + LibDBIcon, the standard
-- every minimap-button manager (Leatrix Plus, MinimapButtonButton, ...) understands.
local _, ns = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local NAME = "DustyThready"

local function tooltip(tt)
    tt:AddLine(ns.Color("violet", "Dusty") .. ns.Color("gold", "Thready"))
    local snap = ns.Snapshot()
    for _, prof in ipairs({ "tailoring", "enchanting" }) do
        local p = snap[prof]
        local label = prof == "tailoring" and ns.Color("gold", "Tailoring") or ns.Color("violet", "Enchanting")
        if p then
            local step = ns.CurrentStep(prof, p.skill)
            local nextUp = step and (ns.Color("muted", "  next: ") .. (step.out and ns.ItemName(step.out) or ns.SpellName(step.spell, step.name))) or ""
            tt:AddLine(("%s %d/%d%s"):format(label, p.skill, p.max, nextUp), 1, 1, 1)
        else
            tt:AddLine(label .. ns.Color("muted", "  not learned"), 1, 1, 1)
        end
    end
    local n = #ns.ScanBags()
    if n > 0 then tt:AddLine(ns.Color("warn", n .. " item(s) to disenchant")) end
    tt:AddLine(" ")
    tt:AddLine(ns.Color("muted", "Click: open  ·  Right-click: disenchant  ·  Drag: move"))
end

local registered = false
local function update()
    if not (LDB and DBIcon) then return end
    if not registered then
        local obj = LDB:NewDataObject(NAME, {
            type = "launcher",
            text = NAME,
            icon = ns.ICON,
            OnClick = function(_, button)
                if button == "RightButton" then ns.Toggle("disenchant") else ns.Toggle() end
            end,
            OnTooltipShow = function(tt) if tt and tt.AddLine then tooltip(tt) end end,
        })
        DBIcon:Register(NAME, obj, ns.db.minimap)
        registered = true
    end
    if ns.db.minimap.hide then DBIcon:Hide(NAME) else DBIcon:Show(NAME) end
end

ns:On("DT_READY", update)
ns:On("DT_MINIMAP", update)
