-- DustyThready: "Today" - the one screen you need most of the time.
-- Two profession cards (what to craft right now, with your mats), a synergy
-- card (how one profession feeds the other), and a bag teaser.
local _, ns = ...
local UI, C = ns.UI, ns.C

local PROF = {
    tailoring  = { label = "Tailoring",  key = "tailoring",  color = C.gold,   icon = 136249, spell = 3908 },
    enchanting = { label = "Enchanting", key = "enchanting", color = C.violet, icon = 136244, spell = 7411 },
}

local function alertLine(card, text, color)
    card.alert:SetText(text)
    card.alertBg:SetVertexColor(color[1] * 0.3, color[2] * 0.3, color[3] * 0.3, 0.9)
    card.alertEdge:SetVertexColor(color[1], color[2], color[3], 1)
    card.alert:SetTextColor(color[1], color[2], color[3])
    card.alertFrame:Show()
end

local function makeProfCard(parent, prof)
    local p = PROF[prof]
    local card = UI.Panel(parent, C.panel, C.edge)
    card.prof = prof

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(28, 28)
    card.icon:SetPoint("TOPLEFT", 12, -12)
    card.icon:SetTexture(p.icon)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.title = UI.Text(card, 15, p.color)
    card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 8, 0)
    card.title:SetText(p.label)
    card.rank = UI.Pill(card, p.color)
    card.rank:SetPoint("LEFT", card.title, "RIGHT", 8, 0)
    card.skill = UI.Text(card, 13, C.text, "RIGHT")
    card.skill:SetPoint("TOPRIGHT", -12, -14)

    card.bar = UI.ProgressBar(card, p.color)
    card.bar:SetPoint("TOPLEFT", card.icon, "BOTTOMLEFT", 0, -8)
    card.bar:SetPoint("RIGHT", card, "RIGHT", -12, 0)

    -- Alert strip (train / buy recipe / level up)
    local af = CreateFrame("Frame", nil, card)
    af:SetPoint("TOPLEFT", card.bar, "BOTTOMLEFT", 0, -8)
    af:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    af:SetHeight(34)
    card.alertBg = af:CreateTexture(nil, "BACKGROUND")
    card.alertBg:SetAllPoints()
    card.alertBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    card.alertEdge = af:CreateTexture(nil, "ARTWORK")
    card.alertEdge:SetTexture("Interface\\Buttons\\WHITE8x8")
    card.alertEdge:SetPoint("TOPLEFT")
    card.alertEdge:SetPoint("BOTTOMLEFT")
    card.alertEdge:SetWidth(3)
    card.alert = UI.Text(af, 11, C.warn)
    card.alert:SetPoint("TOPLEFT", 10, -4)
    card.alert:SetPoint("BOTTOMRIGHT", -8, 4)
    card.alert:SetJustifyV("MIDDLE")
    af:EnableMouse(true)
    af:SetScript("OnMouseUp", function() if card.alertTab then ns.Main:Select(card.alertTab) end end)
    card.alertFrame = af

    -- "Next up"
    card.nextLabel = UI.Text(card, 10, C.muted)
    card.nextLabel:SetText("NEXT UP")
    card.recipe = UI.ItemButton(card, 30)
    card.recipeName = UI.Text(card, 13, C.text)
    card.recipeName:SetPoint("TOPLEFT", card.recipe, "TOPRIGHT", 8, -1)
    card.recipeName:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    card.recipeSub = UI.Text(card, 11, C.muted)
    card.recipeSub:SetPoint("TOPLEFT", card.recipeName, "BOTTOMLEFT", 0, -3)
    card.recipeSub:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    card.recipe:HookScript("OnEnter", function(self)
        if self.spellID and not self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
            GameTooltip:Show()
        end
    end)

    card.matsBox = CreateFrame("Frame", nil, card)
    card.chips = UI.Pool(UI.MatChipFactory(card.matsBox))
    card.tip = UI.Text(card, 11, C.muted)
    card.tip:SetPoint("RIGHT", card, "RIGHT", -12, 0)

    -- Empty state (profession not learned)
    card.empty = UI.Text(card, 12, C.muted)
    card.empty:SetPoint("TOPLEFT", card.bar, "BOTTOMLEFT", 0, -56)
    card.empty:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    return card
end

local function layoutCard(card, snap)
    local prof = card.prof
    local p = snap[prof]
    local width = card:GetWidth() - 24
    card.alertFrame:Hide()
    card.alertTab = nil

    if not p then
        card.rank:SetLabel("not learned", C.muted)
        card.skill:SetText("")
        card.bar:SetValue(0)
        card.bar:SetCap(nil)
        local t = ns.TrainersFor(prof, "apprentice", snap.faction)[1]
        alertLine(card, ("Learn %s from any trainer, e.g. %s in %s.  (Where tab)")
            :format(PROF[prof].label, t and t[1] or "?", t and t[2] or "?"), C.warn)
        card.alertTab = "places"
        card.nextLabel:Hide() card.recipe:Hide() card.recipeName:SetText("") card.recipeSub:SetText("")
        card.chips:Release() card.tip:SetText("")
        card.empty:SetText(prof == "enchanting"
            and "Enchanting turns every green you find (and every green Tailoring makes) into dust instead of vendor trash."
            or "Tailoring needs no gathering: cloth drops from humanoids you're already killing.")
        card.empty:Show()
        card:SetHeight(170)
        return
    end
    card.empty:Hide()

    local rank = ns.RankForSkill(math.max(p.skill, 0))
    local rankName = (p.max >= 300 and "Artisan") or (p.max >= 225 and "Expert") or (p.max >= 150 and "Journeyman") or "Apprentice"
    card.rank:SetLabel(rankName, PROF[prof].color)
    card.skill:SetText(("|cffffffff%d|r |cff%s/ %d|r"):format(p.skill, ns.HEX.muted, p.max))
    card.bar:SetValue(p.skill / 300)
    card.bar:SetCap(p.max / 300)

    -- Alerts, most urgent first
    local train = ns.TrainingNeed(prof, snap)
    local step = ns.CurrentStep(prof, p.skill)
    local missingItem, missingSrc
    if step then missingItem, missingSrc = ns.MissingRecipe(step) end

    if train and not train.notLearned then
        if train.ready then
            local t = ns.TrainersFor(prof, train.rank.key, snap.faction)[1]
            local cost = train.rank.cost and (" (" .. ns.Money(train.rank.cost) .. ")") or ""
            alertLine(card, ("Train %s now%s: %s, %s."):format(train.rank.name, cost, t and t[1] or "?", t and t[2] or "?"), C.warn)
        else
            alertLine(card, ("You can train %s at level %d. Until then, skill stops at %d.")
                :format(train.rank.name, train.levelNeeded, p.max), C.bad)
        end
        card.alertTab = "places"
    elseif missingItem then
        local w = missingSrc and missingSrc.where
        local where = ""
        if w then
            for _, v in ipairs(w) do
                if v[3] == "N" or v[3] == snap.faction then where = v[1] .. ", " .. v[2] break end
            end
        end
        alertLine(card, ("Buy %s%s"):format(ns.ItemName(missingItem), where ~= "" and (" from " .. where) or ""), C.warn)
        card.alertTab = "places"
    end

    local y = 62 + (card.alertFrame:IsShown() and 42 or 0)
    card.nextLabel:ClearAllPoints()
    card.nextLabel:SetPoint("TOPLEFT", 12, -y)
    card.nextLabel:Show()
    y = y + 16

    if not step then
        card.recipe:Hide()
        card.recipeName:SetText(ns.Color("good", "All done: 300! Go make something legendary."))
        card.recipeSub:SetText("")
        card.recipeName:ClearAllPoints()
        card.recipeName:SetPoint("TOPLEFT", 12, -y)
        card.chips:Release()
        card.tip:SetText("")
        card:SetHeight(y + 40)
        return
    end

    card.recipe:Show()
    card.recipe:ClearAllPoints()
    card.recipe:SetPoint("TOPLEFT", 12, -y)
    card.recipe.spellID = step.spell
    if step.out then card.recipe:SetItem(step.out) else card.recipe:SetSpellIcon(step.spell) end
    card.recipeName:ClearAllPoints()
    card.recipeName:SetPoint("TOPLEFT", card.recipe, "TOPRIGHT", 8, -1)
    card.recipeName:SetPoint("RIGHT", card, "RIGHT", -12, 0)

    local crafts = ns.RemainingCrafts(step, p.skill)
    local name = step.out and ns.ItemText(step.out) or ns.SpellName(step.spell, step.name)
    card.recipeName:SetText(("%s  |cff%s×%d|r"):format(name, ns.HEX.gold, crafts))
    local sub = ("skill %d » %d"):format(math.max(step.from, p.skill), step.to)
    local de = prof == "tailoring" and ns.StepDE(step)
    if de then
        sub = sub .. "  ·  " .. ns.Color("violet", ("disenchants » ~%d %s"):format(math.floor(de.perCraft * crafts + 0.5), ns.ItemName(de.reagent)))
    end
    card.recipeSub:SetText(sub)
    card.recipeName:SetWidth(width - 38)
    card.recipeSub:SetWidth(width - 38)
    y = y + math.max(34, card.recipeName:GetStringHeight() + 3 + card.recipeSub:GetStringHeight() + 6)

    card.matsBox:ClearAllPoints()
    card.matsBox:SetPoint("TOPLEFT", 12, -y)
    card.matsBox:SetSize(width, 20)
    card.chips:Release()
    local h = UI.LayoutMats(card.matsBox, card.chips, ns.Mats(step, crafts), width, 0, 0)
    y = y + h + 8

    card.tip:ClearAllPoints()
    card.tip:SetPoint("TOPLEFT", 12, -y)
    card.tip:SetWidth(width)
    card.recipeName:SetWidth(width - 38)
    card.recipeSub:SetWidth(width - 38)
    card.tip:SetText(step.tip and ("|cff" .. ns.HEX.gold .. "Tip:|r " .. step.tip) or "")
    if step.tip then y = y + card.tip:GetStringHeight() + 6 end
    card:SetHeight(math.max(y + 8, 150))
end

---------------------------------------------------------------------------
-- Synergy card
---------------------------------------------------------------------------
local function synergyLines(snap)
    local lines = {}
    local t, e = snap.tailoring, snap.enchanting
    if not t and not e then
        table.insert(lines, "Learn " .. ns.Color("gold", "Tailoring") .. " and " .. ns.Color("violet", "Enchanting") ..
            ": no gathering needed, and every green you sew becomes dust for the other.")
        return lines
    end
    if t and not e then
        table.insert(lines, "Pick up " .. ns.Color("violet", "Enchanting") ..
            ": the greens you sew from skill 95 on would disenchant into the exact dust Enchanting levels with.")
    end
    if e and not t then
        table.insert(lines, "Pick up " .. ns.Color("gold", "Tailoring") ..
            ": it turns cloth you already loot into greens, and greens into the dust you need.")
    end

    -- Tailoring » Enchanting
    if t then
        local step, idx, steps = ns.CurrentStep("tailoring", t.skill)
        local de = step and ns.StepDE(step)
        local feeder = step
        if step and not de then
            for i = idx + 1, #steps do
                local d = ns.StepDE(steps[i])
                if d then de, feeder = d, steps[i] break end
            end
        end
        if de and feeder then
            local uses = ns.EnchantStepsUsing(de.reagent)
            local when = ""
            if #uses > 0 then
                local u = uses[1].step
                when = (" » Enchanting eats it at %d-%d (%s)"):format(u.from, u.to, ns.SpellName(u.spell, u.name))
            end
            local crafts = (feeder == step) and ns.RemainingCrafts(feeder, t.skill) or feeder.count
            local prefix = (feeder == step) and "Your next" or ("From Tailoring " .. feeder.from .. ",")
            table.insert(lines, ("%s %s %s disenchant into ~%s%s."):format(
                prefix, ns.Color("gold", crafts), ns.ItemText(feeder.out),
                ns.Color("violet", math.floor(de.perCraft * crafts + 0.5) .. " " .. ns.ItemName(de.reagent)), when))
            if e then
                local need = ns.RemainingNeed("enchanting", e.skill, de.reagent)
                local have = ns.Count(de.reagent)
                if need > 0 and e.skill < (uses[1] and uses[1].step.from or 0) then
                    table.insert(lines, ("Bank it! You'll need %d %s later (you have %d). Don't sell it now.")
                        :format(need, ns.ItemName(de.reagent), have))
                end
            end
        end
    end

    -- Enchanting: what am I short of, and where to get it
    if e then
        local step = ns.CurrentStep("enchanting", e.skill)
        local key = step and ns.KeyReagent(step)
        if key then
            local crafts = ns.RemainingCrafts(step, e.skill)
            local need = 0
            for _, m in ipairs(step.mats) do if m[1] == key then need = m[2] * crafts end end
            local have = ns.Count(key)
            if have >= need then
                table.insert(lines, ns.Color("good", "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t ") .. ("You have all the %s for your current Enchanting step. Go craft!"):format(ns.ItemName(key)))
            else
                local short = need - have
                local from = {}
                if t then
                    for _, src in ipairs(ns.TailoringSourcesOf(key)) do
                        if not src.alt then
                            table.insert(from, ("sew %s (Tailoring %d-%d)"):format(ns.ItemText(src.step.out), src.step.from, src.step.to))
                        end
                    end
                end
                local price = ns.AHPrice(key)
                if price then table.insert(from, "buy ~" .. ns.Money(price * short, true) .. " on the AH") end
                table.insert(from, "disenchant level-" .. ns.DE_ROWS[1].lo .. "+ greens (see Disenchant tab)")
                for _, r in ipairs(ns.DE_ROWS) do
                    if r.dust[1] == key or r.essence[1] == key then
                        from[#from] = ("disenchant greens needing level %d-%d"):format(r.lo, r.hi)
                        break
                    end
                end
                table.insert(lines, ("Enchanting is short %s %s. Get it: %s.")
                    :format(ns.Color("warn", short), ns.ItemText(key), table.concat(from, ", or ")))
            end
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- Build / refresh
---------------------------------------------------------------------------
local function build(page)
    local scroll = UI.Scroll(page)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -8, 0)
    page.scroll = scroll
    local c = scroll.child

    page.cards = { tailoring = makeProfCard(c, "tailoring"), enchanting = makeProfCard(c, "enchanting") }

    local syn = UI.Panel(c, { 0.14, 0.10, 0.22 }, C.violet)
    page.syn = syn
    syn.title = UI.Text(syn, 13, C.text)
    syn.title:SetPoint("TOPLEFT", 12, -10)
    syn.title:SetText(ns.Color("gold", "Thread") .. " & " .. ns.Color("violet", "Dust") .. "   |cff" .. ns.HEX.muted .. "how your two professions feed each other|r")
    syn.body = UI.Text(syn, 12, C.text)
    syn.body:SetPoint("TOPLEFT", syn.title, "BOTTOMLEFT", 0, -8)
    syn.body:SetPoint("RIGHT", syn, "RIGHT", -12, 0)
    syn.body:SetSpacing(4)

    local bag = UI.Panel(c, C.panel, C.edge)
    page.bag = bag
    bag.text = UI.Text(bag, 12, C.text)
    bag.text:SetPoint("LEFT", 12, 0)
    bag.text:SetPoint("RIGHT", -150, 0)
    bag.text:SetJustifyV("MIDDLE")
    bag.btn = UI.Button(bag, "Open Disenchanter", 130, 24, function() ns.Main:Select("disenchant") end, "primary")
    bag.btn:SetPoint("RIGHT", -12, 0)
end

local function refresh(page, snap)
    local c = page.scroll.child
    local w = page.scroll:GetWidth()
    if w < 50 then w = 660 end
    local half = math.floor((w - 10) / 2)
    local t, e = page.cards.tailoring, page.cards.enchanting
    t:SetWidth(half) e:SetWidth(half)
    t:ClearAllPoints() e:ClearAllPoints()
    t:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    e:SetPoint("TOPLEFT", c, "TOPLEFT", half + 10, 0)
    layoutCard(t, snap)
    layoutCard(e, snap)
    local top = math.max(t:GetHeight(), e:GetHeight())
    t:SetHeight(top) e:SetHeight(top)

    local syn = page.syn
    syn:ClearAllPoints()
    syn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(top + 10))
    syn:SetWidth(w)
    local lines = synergyLines(snap)
    for i, l in ipairs(lines) do lines[i] = ns.Color("violet", "-") .. " " .. l end
    syn.body:SetWidth(w - 24)
    syn.body:SetText(table.concat(lines, "\n"))
    local sh = 38 + syn.body:GetStringHeight() + 8
    syn:SetHeight(sh)

    local bag = page.bag
    bag:ClearAllPoints()
    bag:SetPoint("TOPLEFT", syn, "BOTTOMLEFT", 0, -10)
    bag:SetWidth(w)
    bag:SetHeight(48)
    local list = ns.ScanBags()
    if #list == 0 then
        bag.text:SetText(ns.Color("muted", "No greens or blues in your bags right now. Loot some, or sew some!"))
        bag.btn:Hide()
    else
        local totals, order = ns.ExpectedTotals(list)
        local parts = {}
        for i = 1, math.min(3, #order) do
            local id = order[i]
            table.insert(parts, ns.IconString(ns.ItemIcon(id), 14) .. " ~" .. math.floor(totals[id] + 0.5) .. " " .. ns.ItemName(id))
        end
        bag.text:SetText(("%s in your bags could become  %s")
            :format(ns.Color("gold", #list .. (#list == 1 and " item" or " items")), table.concat(parts, "   ")))
        bag.btn:SetShown(snap.canDisenchant)
    end

    page.scroll:SetContentHeight(top + 10 + sh + 10 + 48 + 4)
end

ns.RegisterTab("today", { label = "Today", icon = 134939, build = build, refresh = refresh })
