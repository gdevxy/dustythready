-- DustyThready: item tooltips. On any green/blue/purple weapon or armor:
-- what it disenchants into, and whether that beats the vendor.
-- On reagents: which of your steps still need it.
local _, ns = ...

local function itemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function addLines(tooltip, id, link)
    if not ns.db or not ns.db.tooltip then return end
    if tooltip.dtDone == (link or id) then return end
    tooltip.dtDone = link or id
    local head = ns.IconString(ns.ICON, 14) .. " "

    local pred = ns.PredictDE(link or id)
    if pred then
        local parts = {}
        for _, o in ipairs(pred.outcomes) do table.insert(parts, ns.OutcomeText(o, false)) end
        tooltip:AddLine(head .. ns.Color("violet", "Disenchants into:"))
        for _, p in ipairs(parts) do tooltip:AddLine("   " .. p) end
        if pred.ev then
            local sell = pred.sell or 0
            local better = pred.ev >= sell
            tooltip:AddLine(("   Worth ~ %s as reagents  ·  vendor %s  %s"):format(ns.Money(pred.ev, true), ns.Money(sell, true),
                better and ns.Color("good", "» Disenchant") or ns.Color("warn", "» Vendor it")))
        end
        return
    end

    -- Reagent? Tell the player if their path still needs it.
    if not id then return end
    local snap = ns.Snapshot()
    local notes = {}
    for _, prof in ipairs({ "tailoring", "enchanting" }) do
        local p = snap[prof]
        if p then
            local need = ns.RemainingNeed(prof, p.skill, id)
            if need > 0 then
                table.insert(notes, ("%s still needs %d (you have %d)"):format(
                    prof == "tailoring" and ns.Color("gold", "Tailoring") or ns.Color("violet", "Enchanting"), need, ns.Count(id)))
            end
        end
    end
    if #notes > 0 then
        tooltip:AddLine(head .. table.concat(notes, "  ·  "))
    end
end

local function onItem(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    link = ok and ns.clean(link) or nil
    local id = (data and ns.clean(data.id)) or itemIDFromLink(link)
    if not id and not link then return end
    pcall(addLines, tooltip, id, link)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItem)
else
    GameTooltip:HookScript("OnTooltipSetItem", function(self) onItem(self) end)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", function(self) onItem(self) end) end
end

for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tt then tt:HookScript("OnTooltipCleared", function(self) self.dtDone = nil end) end
end
