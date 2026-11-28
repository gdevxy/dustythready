-- DustyThready: localization.
--
--   local L = ns.L
--   text:SetText(L["Shopping list"])
--   L["Train %s now%s: %s, %s."]:format(...)
--
-- English is the key: a missing translation returns the key itself, so the
-- addon always works in English. Translations live in Locales\<code>.lua as
-- ns.LOCALES["deDE"] = { ["English"] = "Deutsch", ... } and load before this
-- file. Lookups go through the active table every time (no caching), so
-- "/dusty locale deDE" switches most texts at once; /reload for the rest.
-- Game data (Data\*.lua) stays in English and is wrapped where it is shown.
local _, ns = ...

ns.LOCALES = ns.LOCALES or {}

local active = {}
local current = "enUS"

local L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if type(v) ~= "string" or v == "" then return key end
        return v
    end,
})
ns.L = L

local function clientLocale()
    if not GetLocale then return "enUS" end
    local ok, code = pcall(GetLocale)
    if ok and type(code) == "string" and code ~= "" then return code end
    return "enUS"
end
ns.ClientLocale = clientLocale

-- code: "deDE", "frFR", ... or nil / "auto" for the client's language.
-- Returns the code in use and whether we have a translation for it.
function ns.SetLocale(code)
    if type(code) ~= "string" or code == "" or code == "auto" then code = clientLocale() end
    current = code
    active = ns.LOCALES[code] or {}
    return code, ns.LOCALES[code] ~= nil
end

function ns.Locale() return current end

-- True when texts come from a translation (not the English keys).
function ns.IsTranslated() return ns.LOCALES[current] ~= nil end

-- True when the client itself runs in English (game names are English too).
function ns.ClientIsEnglish()
    local code = clientLocale()
    return code == "enUS" or code == "enGB"
end

ns.SetLocale()
