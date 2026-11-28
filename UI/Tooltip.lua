-- DustyThready: item tooltips. On any green/blue/purple weapon or armor:
-- what it disenchants into, and whether the AH, disenchanting or the vendor
-- pays most. On patterns/formulas from our paths: known / needed at what skill.
-- On reagents: which of your steps still need it.
local _, ns = ...
local L = ns.L

local function itemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

---------------------------------------------------------------------------
-- Is this copy soulbound? (the tooltip says so when it's in your bags)
---------------------------------------------------------------------------
local function tooltipSaysBound(tooltip, data)
    local marks = {}
    for _, g in ipairs({ "ITEM_SOULBOUND", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND" }) do
        if type(_G[g]) == "string" then marks[_G[g]] = true end
    end
    if data and type(data.lines) == "table" then
        for i = 1, math.min(#data.lines, 8) do
            local l = data.lines[i]
            local text = type(l) == "table" and ns.clean(l.leftText)
            if type(text) == "string" and marks[text] then return true end
        end
    end
    local name = tooltip.GetName and tooltip:GetName()
    local n = tooltip.NumLines and tooltip:NumLines() or 0
    if name then
        for i = 2, math.min(n, 8) do
            local fs = _G[name .. "TextLeft" .. i]
            local text = fs and ns.clean(fs:GetText())
            if type(text) == "string" and marks[text] then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Patterns and formulas: recipe item ID -> the steps that use it
---------------------------------------------------------------------------
local recipeMap
local function buildRecipeMap()
    recipeMap = {}
    local function add(prof, s, alt, route)
        local item = s.pattern or s.formula
        if not item then return end
        recipeMap[item] = recipeMap[item] or {}
        table.insert(recipeMap[item], { prof = prof, step = s, alt = alt, route = route })
    end
    for _, pair in ipairs({ { "tailoring", ns.TAILORING }, { "enchanting", ns.ENCHANTING } }) do
        for _, s in ipairs(pair[2] or {}) do
            add(pair[1], s, false, s.route)
            if s.alts then
                for _, a in ipairs(s.alts) do add(pair[1], a, true, a.route or s.route) end
            end
        end
    end
end

-- English keys, shown through L[] (built at use, so "/dusty locale" applies).
local PROF_NAME = { tailoring = "Tailoring", enchanting = "Enchanting" }
local PROF_COLOR = { tailoring = "gold", enchanting = "violet" }
local ROUTE_TEXT = { dust = "Strange Dust route", essence = "Magic Essence route" }
local function profText(prof)
    if not PROF_NAME[prof] then return prof end
    return ns.Color(PROF_COLOR[prof], L[PROF_NAME[prof]])
end
-- Recipe item subclasses (item class 9): 2 = Tailoring, 8 = Enchanting.
local OUR_RECIPE_SUBCLASS = { [2] = true, [8] = true }

-- One line for a pattern/formula, or nil if it isn't one of ours.
local function recipeLine(id)
    if not recipeMap then buildRecipeMap() end
    local list = recipeMap[id]
    local text
    if not list then
        local info = ns.ItemInfo(id)
        if not (info and info.classID == 9 and OUR_RECIPE_SUBCLASS[info.subclassID]) then return nil end
        text = ns.Color("muted", L["Not on your path"])
    else
        for _, e in ipairs(list) do
            if ns.KnowsSpell(e.step.spell) then text = ns.Color("good", L["you know this"]) break end
        end
        if not text then
            -- Best use of it: on your route, still ahead of you, main step, lowest skill.
            local snap = ns.Snapshot()
            local route = (ns.db and ns.db.enchantRoute) or "dust"
            local best, bestScore
            for _, e in ipairs(list) do
                local p = snap[e.prof]
                local onRoute = not e.route or e.route == route
                local past = p and p.skill >= e.step.to
                local score = (onRoute and 0 or 4) + (past and 2 or 0) + (e.alt and 1 or 0)
                if not best or score < bestScore or (score == bestScore and e.step.from < best.step.from) then
                    best, bestScore = e, score
                end
            end
            local p = snap[best.prof]
            local skill = p and p.skill
            local prof = profText(best.prof)
            if best.route and best.route ~= route then
                text = ns.Color("muted", L["Not on your path"] .. " (" .. L[ROUTE_TEXT[best.route] or best.route] .. ")")
            elseif skill and skill >= best.step.to then
                text = ns.Color("muted", L["Not needed anymore (you're past %d)"]:format(best.step.to))
            elseif skill and skill >= best.step.from then
                text = ns.Color("warn", L["Needed now"]) .. (" (%s %d-%d)"):format(prof, best.step.from, best.step.to)
            elseif best.alt then
                text = L["Optional at %d (%s path, alternative)"]:format(best.step.from, prof)
            else
                text = L["Needed at %d (%s path)"]:format(best.step.from, prof)
            end
        end
    end
    local ah = ns.AHPrice(id)
    if ah then text = text .. ns.Color("muted", "  ·  " .. L["AH"] .. " ") .. ns.Money(ah, true) end
    return ns.Color("violet", "DustyThready: ") .. text
end

---------------------------------------------------------------------------
local function addLines(tooltip, id, link, data)
    if not ns.db or not ns.db.tooltip then return end
    if tooltip.dtDone == (link or id) then return end
    tooltip.dtDone = link or id
    local head = ns.IconString(ns.ICON, 14) .. " "

    local pred = ns.PredictDE(link or id)
    if pred then
        local parts = {}
        for _, o in ipairs(pred.outcomes) do table.insert(parts, ns.OutcomeText(o, false)) end
        tooltip:AddLine(head .. ns.Color("violet", L["Disenchants into:"]))
        for _, p in ipairs(parts) do tooltip:AddLine("   " .. p) end
        local bound = (ns.IsItemBound and ns.IsItemBound(link or id)) or tooltipSaysBound(tooltip, data)
        local v = ns.DESellChoice and ns.DESellChoice(id, link, pred, bound)
        if v and v.best then
            local vals = {}
            if v.ah then table.insert(vals, L["AH"] .. " " .. ns.Money(v.ah, true)) end
            table.insert(vals, L["DE ~"] .. " " .. ns.Money(v.de, true))
            table.insert(vals, L["vendor"] .. " " .. ns.Money(v.vendor, true))
            tooltip:AddLine("   " .. table.concat(vals, "  ·  "))
            tooltip:AddLine("   " .. (ns.DE_BEST_LABEL[v.best] or "") .. "  " .. ns.Color("muted", ns.DEReason(v)), 1, 1, 1, true)
        end
        return
    end

    if not id then return end

    -- Pattern / formula?
    local recipe = recipeLine(id)
    if recipe then
        tooltip:AddLine(head .. recipe)
        return
    end

    -- Reagent? Tell the player if their path still needs it.
    local snap = ns.Snapshot()
    local notes = {}
    for _, prof in ipairs({ "tailoring", "enchanting" }) do
        local p = snap[prof]
        if p then
            local need = ns.RemainingNeed(prof, p.skill, id)
            if need > 0 then
                table.insert(notes, L["%s still needs %d (you have %d)"]:format(profText(prof), need, ns.Count(id)))
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
    pcall(addLines, tooltip, id, link, data)
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
