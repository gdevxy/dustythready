-- DustyThready: "show this NPC on the map".
--
-- NPC names in our texts become links (ns.NpcLink) when we know where the NPC
-- stands (Data\Coords.lua). Clicking one opens the world map on that zone and
-- drops a pulsing pin there. Like ForeverDungeonJournal we draw our own pin on
-- the map canvas: C_Map.SetUserWaypoint isn't reliable on WoW Forever.
-- TomTom, if installed, also gets a waypoint.
local _, ns = ...
local C = ns.C

local MAP_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local target, pin, driver

---------------------------------------------------------------------------
-- Links
---------------------------------------------------------------------------
-- "|Hdtnpc:Kithas|h[map] Kithas|h" if we know where Kithas is, else the plain text.
function ns.NpcLink(name, text, colorKey)
    text = text or name
    if not (ns.NPC_COORDS and ns.NPC_COORDS[name]) then return text end
    local shown = colorKey and ns.Color(colorKey, text) or text
    return ("|Hdtnpc:%s|h%s %s|h"):format(name, ns.IconString(MAP_ICON, 12), shown)
end

-- Turns every known NPC name inside a free text into a link.
function ns.LinkNpcsIn(text)
    if not (ns.NPC_COORDS and text) then return text end
    for name in pairs(ns.NPC_COORDS) do
        local s, e = text:find(name, 1, true)
        if s then text = text:sub(1, s - 1) .. ns.NpcLink(name) .. text:sub(e + 1) end
    end
    return text
end

-- Makes the NPC links inside a frame's font strings clickable.
function ns.EnableNpcLinks(frame)
    frame:EnableMouse(true)
    frame:SetHyperlinksEnabled(true)
    frame:SetScript("OnHyperlinkClick", function(self, link)
        local name = link:match("^dtnpc:(.+)$")
        if name then
            self.dtLinkClicked = GetTime()
            ns.ShowNpcOnMap(name)
        end
    end)
    frame:SetScript("OnHyperlinkEnter", function(self, link)
        local name = link:match("^dtnpc:(.+)$")
        local c = name and ns.NPC_COORDS[name]
        if not c then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddLine(("%s  %.1f, %.1f"):format(ns.MapName(c.m), c.x, c.y), C.gold[1], C.gold[2], C.gold[3])
        GameTooltip:AddLine("Click to show on your map.", C.muted[1], C.muted[2], C.muted[3])
        GameTooltip:Show()
    end)
    frame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
end

function ns.MapName(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and info and info.name and info.name ~= "" then return info.name end
    end
    return "Map " .. mapID
end

---------------------------------------------------------------------------
-- The pin
---------------------------------------------------------------------------
local function canvas()
    if not WorldMapFrame then return nil end
    if WorldMapFrame.GetCanvas then
        local ok, c = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
        if ok and c then return c end
    end
    return WorldMapFrame.ScrollContainer and (WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer)
end

local function buildPin(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(40, 40)
    b:RegisterForClicks("AnyUp")

    b.pulse = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.pulse:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    b.pulse:SetVertexColor(C.violet[1], C.violet[2], C.violet[3], 0.6)
    b.pulse:SetBlendMode("ADD")
    b.pulse:SetSize(30, 30)
    b.pulse:SetPoint("CENTER")
    b.pulse:SetAlpha(0)
    pcall(function()
        local g = b.pulse:CreateAnimationGroup()
        g:SetLooping("REPEAT")
        local grow = g:CreateAnimation("Scale")
        grow:SetDuration(1.6)
        if grow.SetScaleFrom then grow:SetScaleFrom(0.9, 0.9) grow:SetScaleTo(2.2, 2.2) else grow:SetScale(2.2, 2.2) end
        grow:SetOrigin("CENTER", 0, 0)
        local fadeIn = g:CreateAnimation("Alpha")
        fadeIn:SetDuration(0.4) fadeIn:SetFromAlpha(0) fadeIn:SetToAlpha(0.7)
        local fadeOut = g:CreateAnimation("Alpha")
        fadeOut:SetStartDelay(0.4) fadeOut:SetDuration(1.2) fadeOut:SetFromAlpha(0.7) fadeOut:SetToAlpha(0)
        b.anim = g
    end)

    b.disc = b:CreateTexture(nil, "BORDER")
    b.disc:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    b.disc:SetVertexColor(0, 0, 0, 1)
    b.disc:SetSize(28, 28)
    b.disc:SetPoint("CENTER")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(ns.ICON)
    b.icon:SetSize(24, 24)
    b.icon:SetPoint("CENTER")
    local mask = b:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(mask)

    b.ring = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.ring:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    b.ring:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.95)
    b.ring:SetSize(32, 32)
    b.ring:SetPoint("CENTER")

    b:SetScript("OnEnter", function(self)
        if not target then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.Color("violet", "Dusty") .. ns.Color("gold", "Thready"))
        GameTooltip:AddLine(target.name, 1, 1, 1)
        if target.why then GameTooltip:AddLine(target.why, C.muted[1], C.muted[2], C.muted[3], true) end
        GameTooltip:AddLine(("%.1f, %.1f"):format(target.x, target.y), C.gold[1], C.gold[2], C.gold[3])
        GameTooltip:AddLine("Right-click to remove.", C.muted[1], C.muted[2], C.muted[3])
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(_, button) if button == "RightButton" then ns.ClearMapPin() end end)
    return b
end

local function update()
    if not (target and WorldMapFrame and WorldMapFrame:IsShown()) then
        if pin then pin:Hide() end
        return
    end
    local c = canvas()
    if not c then return end
    pin = pin or buildPin(c)
    if pin:GetParent() ~= c then pin:SetParent(c) end
    local ok, mapID = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
    local w, h = c:GetWidth(), c:GetHeight()
    if not ok or mapID ~= target.m or not w or w <= 1 then pin:Hide() return end
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", c, "TOPLEFT", w * target.x / 100, -h * target.y / 100)
    pin:SetFrameLevel(9000)
    if not pin:IsShown() then
        pin:Show()
        if pin.anim then pin.anim:Play() end
    end
end

local function startDriver()
    if driver then driver:Show() return end
    driver = CreateFrame("Frame")
    driver.t = 0
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        if self.t < 0.1 then return end
        self.t = 0
        if not target then self:Hide() return end
        update()
    end)
end

function ns.ClearMapPin()
    target = nil
    if pin then pin:Hide() end
end

local function openMap(mapID)
    if InCombatLockdown() or not WorldMapFrame then return false end
    if C_Map and C_Map.OpenWorldMap then pcall(C_Map.OpenWorldMap, mapID)
    elseif OpenWorldMap then pcall(OpenWorldMap, mapID) end
    if not WorldMapFrame:IsShown() then pcall(ShowUIPanel, WorldMapFrame) end
    if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
    return WorldMapFrame:IsShown()
end

-- Opens the map on the NPC's zone with our pin on it. why = optional tooltip line.
function ns.ShowNpcOnMap(name, why)
    local c = ns.NPC_COORDS and ns.NPC_COORDS[name]
    if not c then return false end
    target = { name = name, m = c.m, x = c.x, y = c.y, why = why }
    startDriver()

    local tt = _G.TomTom
    if tt and tt.AddWaypoint then
        pcall(tt.AddWaypoint, tt, c.m, c.x / 100, c.y / 100, { title = name, persistent = false })
    end

    local place = ("%s (%s %.0f, %.0f)"):format(ns.Color("gold", name), ns.MapName(c.m), c.x, c.y)
    if openMap(c.m) then
        -- The map sometimes settles on the player's zone a frame later: insist briefly.
        for _, d in ipairs({ 0.05, 0.2, 0.5 }) do
            C_Timer.After(d, function()
                if target and target.name == name and WorldMapFrame:IsShown() and WorldMapFrame.SetMapID then
                    pcall(WorldMapFrame.SetMapID, WorldMapFrame, c.m)
                end
            end)
        end
        update()
        print(ns.Color("violet", "DustyThready:") .. " " .. place .. " is marked on your map.")
    else
        print(ns.Color("violet", "DustyThready:") .. " " .. place .. " is marked: open your map after combat.")
    end
    return true
end
