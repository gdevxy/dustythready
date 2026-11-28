-- DustyThready: "Today" - the one screen you need most of the time.
-- Two profession cards (what to craft right now, with your mats), a synergy
-- card (how one profession feeds the other), and a bag teaser.
local _, ns = ...
local L = ns.L
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
    card.title:SetText(L[p.label])
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
    ns.EnableNpcLinks(af)
    -- Clicking the strip opens the Where tab, unless the click was on an NPC link (that shows the map).
    af:SetScript("OnMouseUp", function()
        C_Timer.After(0, function()
            if af.dtLinkClicked and GetTime() - af.dtLinkClicked < 0.5 then return end
            if card.alertTab then ns.Main:Select(card.alertTab) end
        end)
    end)
    card.alertFrame = af

    -- "Next up"
    card.nextLabel = UI.Text(card, 10, C.muted)
    card.nextLabel:SetText(L["NEXT UP"])
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
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.extra, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    -- Why this recipe and not the guide's (bags, colour, price), or a colour warning
    card.note = UI.Text(card, 11, C.good)
    card.note:SetSpacing(2)

    card.matsBox = CreateFrame("Frame", nil, card)
    card.chips = UI.Pool(UI.MatChipFactory(card.matsBox))
    card.craft = UI.CraftControl(card, true)
    card.tip = UI.Text(card, 11, C.muted)
    card.tip:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    -- Budget to the trainer cap (Auctionator prices only)
    card.budget = UI.Text(card, 11, C.muted)
    return card
end

-- A slim one-line strip for a profession you haven't learned (instead of an empty card).
local function makeMissingStrip(parent, prof)
    local p = PROF[prof]
    local f = UI.Panel(parent, C.panel, C.edge, 0.8)
    f.prof = prof
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(22, 22)
    f.icon:SetPoint("TOPLEFT", 12, -10)
    f.icon:SetTexture(p.icon)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon:SetDesaturated(true)
    f.text = UI.Text(f, 12, C.text)
    f.text:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2)
    f.text:SetSpacing(2)
    ns.EnableNpcLinks(f)
    -- Click: the Where tab (unless the click was on an NPC link, which shows the map).
    f:SetScript("OnMouseUp", function()
        C_Timer.After(0, function()
            if f.dtLinkClicked and GetTime() - f.dtLinkClicked < 0.5 then return end
            ns.Main:Select("places")
        end)
    end)
    return f
end

-- Lays the strip out at this width; returns its height.
local function fillMissingStrip(f, snap, width, other)
    local prof = f.prof
    local p = PROF[prof]
    local t = ns.TrainersFor(prof, "apprentice", snap.faction)[1]
    local where = " " .. (t and L["Learn it from %s, %s."]:format(ns.NpcLink(t[1]), ns.ZoneName(t[2]))
        or L["Any trainer teaches it (Where tab)."])
    local why
    if prof == "enchanting" then
        why = other and L["the other half of the pair: the greens you sew disenchant into the very dust Enchanting levels with."]
            or L["it turns every green you find into dust instead of vendor trash."]
    else
        why = other and L["the other half of the pair: cloth you already loot becomes greens, and greens become your dust."]
            or L["no gathering needed: cloth drops from the humanoids you're already killing."]
    end
    f:SetWidth(width)
    f.text:SetWidth(width - 56)
    f.text:SetText(ns.Color(prof == "enchanting" and "violet" or "gold", L[p.label]) ..
        ns.Color("muted", " (" .. L["not learned"] .. "): ") .. why .. ns.Color("muted", where))
    local h = math.max(42, f.text:GetStringHeight() + 22)
    f:SetHeight(h)
    return h
end

local function stepName(s)
    return s.out and ns.ItemText(s.out) or ns.SpellName(s.spell, s.name)
end

-- The one-liner explaining a choice (or a colour warning). Returns text, color.
local function choiceNote(ch)
    local pick, main = ch.step, ch.main
    if ch.reason == "learned" then
        return L["You don't know %s yet: %s works too, and you know it."]:format(stepName(main), stepName(pick)), C.warn
    elseif ch.reason == "color" then
        return L["Turned %s: switch to %s (%s, you know it)."]:format(ns.DiffText(ch.mainColor),
            stepName(pick), ns.DiffText(ch.color or "orange")), C.warn
    elseif ch.reason == "bags" then
        local cov = ch.cov
        local have = (cov and cov.key and cov.keyHave > 0) and L["You have %d %s: "]:format(cov.keyHave, ns.ItemName(cov.key)) or ""
        return have .. L["%s gets you to %d with what you have (the guide says %s)."]:format(stepName(pick), pick.to, stepName(main)), C.good
    elseif ch.reason == "cost" and ch.cov and ch.mainCov then
        return L["Cheaper today: %s, about %s in missing mats vs %s for %s."]:format(stepName(pick),
            ns.Money(ch.cov.cost, true), ns.Money(ch.mainCov.cost, true), stepName(main)), C.good
    end
    if ch.grey then
        local nxt = ch.steps and ch.steps[ch.idx + 1]
        return L["%s is %s now: it gives no more skill.%s"]:format(stepName(main), ns.DiffText("grey", L["grey"]),
            nxt and (" " .. L["Move on to %s."]:format(stepName(nxt))) or ""), C.bad
    end
    return nil
end

local function layoutCard(card, snap)
    local prof = card.prof
    local p = snap[prof]
    local width = card:GetWidth() - 24
    card.alertFrame:Hide()
    card.alertTab = nil

    card.note:SetText("")
    card.budget:SetText("")
    if not p then -- not learned: refresh shows a slim strip instead of this card
        card:Hide()
        return
    end
    card:Show()

    local rankName = L[(p.max >= 300 and "Artisan") or (p.max >= 225 and "Expert") or (p.max >= 150 and "Journeyman") or "Apprentice"]
    card.rank:SetLabel(rankName, PROF[prof].color)
    card.skill:SetText(("|cffffffff%d|r |cff%s/ %d|r"):format(p.skill, ns.HEX.muted, p.max))
    card.bar:SetValue(p.skill / 300)
    card.bar:SetCap(p.max / 300)

    -- Alerts, most urgent first
    local train = ns.TrainingNeed(prof, snap)
    local choice = ns.ChooseStep(prof, p.skill)
    local step = choice and choice.main -- the guide's step (alerts are about it)
    local missingItem, missingSrc
    if step then missingItem, missingSrc = ns.MissingRecipe(step) end

    if train and not train.notLearned then
        if train.ready then
            local t = ns.TrainersFor(prof, train.rank.key, snap.faction)[1]
            local cost = train.rank.cost and (" (" .. ns.Money(train.rank.cost) .. ")") or ""
            alertLine(card, L["Train %s now%s: %s, %s."]:format(L[train.rank.name], cost, t and ns.NpcLink(t[1]) or "?", t and ns.ZoneName(t[2]) or "?"), C.warn)
        else
            alertLine(card, L["You can train %s at level %d. Until then, skill stops at %d."]
                :format(L[train.rank.name], train.levelNeeded, p.max), C.bad)
        end
        card.alertTab = "places"
    elseif missingItem then
        local w = missingSrc and missingSrc.where
        local where = ""
        if w then
            for _, v in ipairs(w) do
                if v[3] == "N" or v[3] == snap.faction then where = ns.NpcLink(v[1]) .. ", " .. ns.ZoneName(v[2]) break end
            end
        end
        alertLine(card, (where ~= "" and L["Buy %s from %s"]:format(ns.ItemName(missingItem), where)
            or L["Buy %s"]:format(ns.ItemName(missingItem))), C.warn)
        card.alertTab = "places"
    elseif step and not (step.formula or step.pattern) and ns.RecipeLearnedState(prof, step.spell) == false then
        local r, t = ns.RecipeTrainer(prof, step, snap.faction)
        alertLine(card, L["Learn %s from %s trainer%s."]:format(ns.SpellName(step.spell, step.name), ns.Article(r.name),
            t and (": " .. ns.NpcLink(t[1]) .. ", " .. ns.ZoneName(t[2])) or ""), C.warn)
        card.alertTab = "places"
    end

    -- Why we craft something else than the guide (or a colour warning).
    local noteText, noteColor
    if choice then noteText, noteColor = choiceNote(choice) end
    if noteText and choice.reason == "color" and not card.alertFrame:IsShown() then
        alertLine(card, noteText, C.warn) -- the colour switch is worth the strip when it's free
        noteText = nil
    end

    local y = 62 + (card.alertFrame:IsShown() and 42 or 0)
    card.nextLabel:ClearAllPoints()
    card.nextLabel:SetPoint("TOPLEFT", 12, -y)
    card.nextLabel:Show()
    y = y + 16

    if not step then
        card.recipe:Hide()
        card.recipeName:SetText(ns.Color("good", L["All done: 300! Go make something legendary."]))
        card.recipeSub:SetText("")
        card.recipeName:ClearAllPoints()
        card.recipeName:SetPoint("TOPLEFT", 12, -y)
        card.chips:Release()
        card.craft:Hide()
        card.tip:SetText("")
        card:SetHeight(y + 40)
        return
    end

    -- What to craft: the guide's step, or the better choice for your bags / colour.
    local pick = choice.step
    card.recipe:Show()
    card.recipe:ClearAllPoints()
    card.recipe:SetPoint("TOPLEFT", 12, -y)
    ns.SetupRecipeIcon(card.recipe, prof, pick)
    card.recipeName:ClearAllPoints()
    card.recipeName:SetPoint("TOPLEFT", card.recipe, "TOPRIGHT", 8, -1)
    card.recipeName:SetPoint("RIGHT", card, "RIGHT", -12, 0)

    local crafts = choice.crafts or ns.RemainingCrafts(pick, p.skill)
    card.recipeName:SetText(("%s  |cff%s%s×%d|r"):format(stepName(pick), ns.HEX.gold, choice.about and (L["about"] .. " ") or "", crafts))
    local sub = L["skill %d » %d"]:format(math.max(pick.from, p.skill), pick.to)
    if choice.color then sub = sub .. "  ·  " .. ns.DiffText(choice.color, L[choice.color]) end
    local de = prof == "tailoring" and ns.StepDE(pick)
    if de then
        sub = sub .. "  ·  " .. ns.Color("violet", L["disenchants » ~%d %s"]:format(math.floor(de.perCraft * crafts + 0.5), ns.ItemName(de.reagent)))
    end
    -- What the last crafts of this recipe really gave, so the "about N" can be checked.
    local ran, gain = ns.Session.Run(prof, pick.spell)
    if ran then
        local txt = (ran == 1 and L["Last craft: +%d skill"] or L["Last %d crafts: +%d skill"])
        txt = (ran == 1) and txt:format(gain) or txt:format(ran, gain)
        sub = sub .. "  ·  " .. ns.Color(gain > 0 and "good" or "warn", txt)
    end
    card.recipeSub:SetText(sub)
    card.recipeName:SetWidth(width - 38)
    card.recipeSub:SetWidth(width - 38)
    y = y + math.max(34, card.recipeName:GetStringHeight() + 3 + card.recipeSub:GetStringHeight() + 6)

    card.note:ClearAllPoints()
    card.note:SetPoint("TOPLEFT", 12, -y)
    card.note:SetWidth(width)
    if noteText then
        local nc = noteColor or C.good
        card.note:SetTextColor(nc[1], nc[2], nc[3])
        card.note:SetText(noteText)
        y = y + card.note:GetStringHeight() + 6
    end

    card.matsBox:ClearAllPoints()
    card.matsBox:SetPoint("TOPLEFT", 12, -y)
    card.matsBox:SetSize(width, 20)
    card.chips:Release()
    local h = UI.LayoutMats(card.matsBox, card.chips, ns.Mats(pick, crafts), width, 0, 0)
    y = y + h + 8

    card.craft:ClearAllPoints()
    card.craft:SetPoint("TOPLEFT", 12, -y)
    card.craft:SetWidth(width)
    card.craft:Update(prof, pick, crafts, snap)
    card.craft:Show()
    y = y + card.craft:GetHeight() + 8

    card.tip:ClearAllPoints()
    card.tip:SetPoint("TOPLEFT", 12, -y)
    card.tip:SetWidth(width)
    card.tip:SetText(pick.tip and ("|cff" .. ns.HEX.gold .. L["Tip:"] .. "|r " .. L[pick.tip]) or "")
    if pick.tip then y = y + card.tip:GetStringHeight() + 6 end

    -- "Reaching 225: about 14g at today's prices. Short 5g, mostly Silk Cloth."
    local budget = ns.BudgetText(ns.CapBudget(prof, snap), true)
    card.budget:ClearAllPoints()
    card.budget:SetPoint("TOPLEFT", 12, -y)
    card.budget:SetWidth(width)
    if budget then
        card.budget:SetText(budget)
        y = y + card.budget:GetStringHeight() + 6
    end
    card:SetHeight(math.max(y + 8, 150))
end

---------------------------------------------------------------------------
-- Synergy card
---------------------------------------------------------------------------
local function synergyLines(snap)
    local lines = {}
    local t, e = snap.tailoring, snap.enchanting
    if not t and not e then
        table.insert(lines, L["Learn %s and %s: no gathering needed, and every green you sew becomes dust for the other."]
            :format(ns.Color("gold", L["Tailoring"]), ns.Color("violet", L["Enchanting"])))
        return lines
    end
    -- (With only one profession, the "not learned" strip above says why the other matters.)

    -- Tailoring » Enchanting
    if t then
        -- Same pick and crafts as the Tailoring card above, so the numbers match.
        local choice = ns.ChooseStep("tailoring", t.skill)
        local step = choice and choice.step
        local de = step and ns.StepDE(step)
        local feeder = step
        if step and not de then
            for i = choice.idx + 1, #choice.steps do
                local d = ns.StepDE(choice.steps[i])
                if d then de, feeder = d, choice.steps[i] break end
            end
        end
        if de and feeder then
            -- The next Enchanting step that still uses it (not one you've passed).
            local nextUse
            for _, u in ipairs(ns.EnchantStepsUsing(de.reagent)) do
                if not e or u.step.to > e.skill then nextUse = u.step break end
            end
            local when = ""
            if nextUse then
                when = " " .. L["» Enchanting eats it at %d-%d (%s)"]:format(nextUse.from, nextUse.to, ns.SpellName(nextUse.spell, nextUse.name))
            end
            local crafts = (feeder == step) and (choice.crafts or ns.RemainingCrafts(feeder, t.skill)) or feeder.count
            local count = ns.Color("gold", crafts)
            local gets = ns.Color("violet", math.floor(de.perCraft * crafts + 0.5) .. " " .. ns.ItemName(de.reagent))
            if feeder == step then
                table.insert(lines, L["Your next %s %s disenchant into ~%s%s."]:format(
                    count, ns.ItemText(feeder.out), gets, when))
            else
                table.insert(lines, L["From Tailoring %d, %s %s disenchant into ~%s%s."]:format(
                    feeder.from, count, ns.ItemText(feeder.out), gets, when))
            end
            if e then
                local need = ns.RemainingNeed("enchanting", e.skill, de.reagent)
                local have = ns.Count(de.reagent)
                if need > 0 and nextUse and e.skill < nextUse.from then
                    table.insert(lines, L["Bank it! You'll need %d %s later (you have %d). Don't sell it now."]
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
            if have >= need and e.skill >= e.max then
                -- At the trainer cap: the dust is ready, but crafting gives no skill yet.
                local train = ns.TrainingNeed("enchanting", snap)
                if train and train.rank and train.ready then
                    table.insert(lines, L["You have all the %s for your next Enchanting step. Train %s first, then craft."]
                        :format(ns.ItemName(key), L[train.rank.name]))
                else
                    table.insert(lines, L["You have all the %s for your next Enchanting step."]:format(ns.ItemName(key)))
                end
            elseif have >= need then
                table.insert(lines, ns.Color("good", "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t ") .. L["You have all the %s for your current Enchanting step. Go craft!"]:format(ns.ItemName(key)))
            else
                local short = need - have
                local from = {}
                if t then
                    for _, src in ipairs(ns.TailoringSourcesOf(key)) do
                        if not src.alt then
                            table.insert(from, L["sew %s (Tailoring %d-%d)"]:format(ns.ItemText(src.step.out), src.step.from, src.step.to))
                        end
                    end
                end
                local price = ns.AHPrice(key)
                if price then table.insert(from, L["buy ~%s on the AH"]:format(ns.Money(price * short, true))) end
                table.insert(from, L["disenchant level-%d+ greens (see Disenchant tab)"]:format(ns.DE_ROWS[1].lo))
                for _, r in ipairs(ns.DE_ROWS) do
                    if r.dust[1] == key or r.essence[1] == key then
                        from[#from] = L["disenchant greens needing level %d-%d"]:format(r.lo, r.hi)
                        break
                    end
                end
                table.insert(lines, L["Enchanting is short %s %s. Get it: %s."]
                    :format(ns.Color("warn", short), ns.ItemText(key), table.concat(from, L[", or "])))
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
    page.missing = { tailoring = makeMissingStrip(c, "tailoring"), enchanting = makeMissingStrip(c, "enchanting") }

    local syn = UI.Panel(c, { 0.14, 0.10, 0.22 }, C.violet)
    page.syn = syn
    syn.title = UI.Text(syn, 13, C.text)
    syn.title:SetPoint("TOPLEFT", 12, -10)
    syn.title:SetText(ns.Color("gold", L["Thread"]) .. " & " .. ns.Color("violet", L["Dust"]) .. "   |cff" .. ns.HEX.muted .. L["how your two professions feed each other"] .. "|r")
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
    bag.btn = UI.Button(bag, L["Open Disenchanter"], 130, 24, function() ns.Main:Select("disenchant") end, "primary")
    bag.btn:SetPoint("RIGHT", -12, 0)
end

local function refresh(page, snap)
    local c = page.scroll.child
    local w = page.scroll:GetWidth()
    if w < 50 then w = 660 end
    local half = math.floor((w - 10) / 2)
    local t, e = page.cards.tailoring, page.cards.enchanting
    local mt, me = page.missing.tailoring, page.missing.enchanting
    t:ClearAllPoints() e:ClearAllPoints()
    mt:ClearAllPoints() me:ClearAllPoints()
    local top
    if snap.tailoring and snap.enchanting then
        -- Both: two cards side by side.
        mt:Hide() me:Hide()
        t:SetWidth(half) e:SetWidth(half)
        t:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
        e:SetPoint("TOPLEFT", c, "TOPLEFT", half + 10, 0)
        layoutCard(t, snap)
        layoutCard(e, snap)
        top = math.max(t:GetHeight(), e:GetHeight())
        t:SetHeight(top) e:SetHeight(top)
    elseif snap.tailoring or snap.enchanting then
        -- One: its card full width, and a one-liner for the other.
        local card = snap.tailoring and t or e
        local other = snap.tailoring and e or t
        local strip = snap.tailoring and me or mt
        local hidden = snap.tailoring and mt or me
        hidden:Hide()
        other:Hide()
        card:SetWidth(w)
        card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
        layoutCard(card, snap)
        local ch = card:GetHeight()
        strip:Show()
        strip:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(ch + 10))
        top = ch + 10 + fillMissingStrip(strip, snap, w, true)
    else
        -- Neither: two one-liners.
        t:Hide() e:Hide()
        mt:Show() me:Show()
        mt:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
        local h1 = fillMissingStrip(mt, snap, w, false)
        me:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(h1 + 8))
        top = h1 + 8 + fillMissingStrip(me, snap, w, false)
    end

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
    if #lines == 0 then sh = -10 end -- nothing to say: no empty card
    syn:SetShown(#lines > 0)

    local bag = page.bag
    bag:ClearAllPoints()
    bag:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(top + 10 + sh + 10))
    bag:SetWidth(w)
    bag:SetHeight(48)
    local list = ns.DEQueue and ns.DEQueue() or ns.ScanBags()
    if #list == 0 then
        bag.text:SetText(ns.Color("muted", L["No greens or blues in your bags right now. Loot some, or sew some!"]))
        bag.btn:Hide()
    else
        -- What to do with them: disenchant for your Enchanting / for gold, sell, vendor.
        local n = { progress = 0, gold = 0, ah = 0, vendor = 0 }
        for _, e in ipairs(list) do
            local b = e.value and e.value.best
            if b and n[b] then n[b] = n[b] + 1 end
        end
        local parts = {}
        if n.progress > 0 then table.insert(parts, ns.Color("violet", L["disenchant %d for your Enchanting"]:format(n.progress))) end
        if n.gold > 0 then table.insert(parts, ns.Color("good", L["disenchant %d for gold"]:format(n.gold))) end
        if n.ah > 0 then table.insert(parts, ns.Color("gold", L["sell %d on the AH"]:format(n.ah))) end
        if n.vendor > 0 then table.insert(parts, ns.Color("warn", L["vendor %d"]:format(n.vendor))) end
        if #parts == 0 then
            local totals, order = ns.ExpectedTotals(list)
            for i = 1, math.min(3, #order) do
                local id = order[i]
                local k = math.floor(totals[id] + 0.5)
                if k > 0 then table.insert(parts, ns.IconString(ns.ItemIcon(id), 14) .. " ~" .. k .. " " .. ns.ItemName(id)) end
            end
            bag.text:SetText(L["%s in your bags could become  %s"]
                :format(ns.Color("gold", (#list == 1 and L["%d item"] or L["%d items"]):format(#list)), table.concat(parts, "   ")))
        else
            bag.text:SetText(L["In your bags: %s"]:format(table.concat(parts, "  ·  ")))
        end
        bag.btn:SetShown(snap.canDisenchant)
    end

    page.scroll:SetContentHeight(top + 10 + sh + 10 + 48 + 4)
end

ns.RegisterTab("today", { label = "Today", icon = 134939, build = build, refresh = refresh })
