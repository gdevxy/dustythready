# Architecture

DustyThready is plain Lua + the WoW widget API, no XML. The only libraries are LibStub, CallbackHandler-1.0,
LibDataBroker-1.1 and LibDBIcon-1.0 (in `Libs/`, for the minimap button only). Everything lives in one
namespace table `ns` (the second value of `...` in every file), also exposed as `_G.DustyThready`
for debugging (`/dump DustyThready.Snapshot()`).

## File map (load order = `DustyThready.toc`)

```
(repository root = the addon folder; .pkgmeta keeps docs/, tools/, README.md, CLAUDE.md out of the zip)
  DustyThready.toc      Interface 16001 (WoW Forever), saved variables, addon compartment hooks.
                        Version is @project-version@: the packager replaces it with the git tag.
  Bindings.xml          key binding "Disenchant next item" (clicks DustyThreadyDENextButton, see
                        TabDisenchant.lua; the binding texts are set there through L)
  Libs/                 LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0
  Locales/
    deDE.lua, frFR.lua  translations: ns.LOCALES["deDE"] = { ["English"] = "Deutsch", ... }
  Locale.lua            ns.L (English key -> active translation, falls back to the key),
                        ns.SetLocale, ns.IsTranslated, ns.ClientIsEnglish (see Localization)
  Core.lua              namespace, colors, saved vars, event bus, safe API wrappers, items, money,
                        prices (Auctionator), profession skill reading, materials on other
                        characters and in the mailbox (ns.CountAlts, ns.CountMail,
                        ns.CountElsewhere), ns.ZoneName, slash commands
  Data/
    Items.lua           fallback English item names + "where to get it" per reagent (ns.SOURCES)
    Tailoring.lua       ns.RANKS (trainer ranks) and ns.TAILORING (1-300 steps)
    Enchanting.lua      ns.ENCHANTING (1-300 steps, two routes) and ns.POPULAR_ENCHANTS
    Disenchant.lua      ns.DE_ROWS (required level -> reagents) and ns.DE_ODDS
    Places.lua          ns.TRAINERS, ns.RECIPE_SOURCES, ns.SUPPLIES, ns.CLOTH_FARMS,
                        ns.ZONE_MAPS (English zone name -> UiMapID)
    Coords.lua          GENERATED ns.NPC_COORDS (name -> UiMapID, x, y) by tools\extract-npc-coords.ps1
    Gold.lua            ns.GOLD_CRAFTS (crafts with live profit), ns.BOLTS (bolt vs cloth)
    EnchantService.lua  ns.SERVICE_ENCHANTS: order of the enchants offered in the trade window
    EnchantSlots.lua    ns.ENCHANT_SLOT: enchant spell ID -> slot key ("Bracer", "2H Weapon"...)
    RecipeSkill.lua     ns.RECIPE_SKILL: recipe spell -> { orange, yellow, green, grey } (Forever values;
                        the client reports no recipe colours). Used by ns.RecipeColor.
    Endgame.lua         ns.MOONCLOTH (spell, cooldown, vendor), ns.ENDGAME_CRAFTS (same shape as
                        GOLD_CRAFTS), ns.ENDGAME_PATTERNS (famous patterns / formulas + sources)
  Logic.lua             pure-ish functions over data + game state (see below)
  Craft.lua             one-click crafting: craft state, enchant slots (ns.EnchantSlotKey,
                        ns.EnchantShort) and targets, OpenTradeSkill + CraftRecipe
  Service.lua           selling Enchanting in the trade window: known enchants for the item in
                        the "Will not be traded" slot, mats from the recipe schematic, quote + tip,
                        "Post my menu" chat line, CraftRecipe + ClickTargetTradeButton(7)
  Endgame.lua           ns.Endgame: Mooncloth cooldown per tailor (account-wide), login / ready alerts
  Session.lua           ns.Session: "this session" skill-ups, reagents gained, disenchant value
                        (footer line); crafts of the same path recipe in a row and the skill they
                        gave (ns.Session.Run: "Last N crafts: +M skill" on Today)
  UI/
    Widgets.lua         ns.UI: Panel, Text, Button, Pill, ProgressBar, ItemButton, Scroll, Pool,
                        Segmented, LayoutMats (have/need chips, + mailbox/alts counts)
    Main.lua            window, header, tab bar (tabs may have visible(snap)), footer, settings
                        popover, ns.RegisterTab
    Craft.lua           UI.CraftControl (Craft button + enchant target chip) and the target picker
    MapPin.lua          NPC links (ns.NpcLink, ns.EnableNpcLinks) and the world-map pin (ns.ShowNpcOnMap)
    TabToday.lua        profession cards + "Thread & Dust" synergy card + bag teaser
    TabRoadmap.lua      step list, route switch, shopping list popover (+ Auctionator export)
    TabDisenchant.lua   bag scan, AH / disenchant / vendor verdict, secure one-click disenchant
                        overlay, "Disenchant next" binding button, cheat sheet
    TabPlaces.lua       "Where": next stops, trainers, recipes, supplies, cloth farms
    TabGold.lua         money cards
    TabEndgame.lua      "Endgame" (only shown at 250+): Mooncloth cooldowns, top crafts, patterns
    Tooltip.lua         item tooltip lines (TooltipDataProcessor)
    Minimap.lua         minimap button (LibDataBroker launcher + LibDBIcon)
    Trade.lua           Enchanting service panel docked to the trade window (uses Service.lua)
    ZoneHint.lua        one chat line per zone when its cloth farm fits your level (ns.db.zoneHints)
  Media/
    icon.tga            128x128 32-bit TGA used in game
    icon-source.jpg     original artwork (not packaged)
```

## Data model

A **step** (in `ns.TAILORING` / `ns.ENCHANTING`):

```lua
{ from = 150, to = 170,          -- skill range this step covers
  spell = 8791,                   -- recipe spell ID (used for names, icons, "known?" checks)
  name = "Crimson Silk Vest",     -- fallback name if the client hasn't cached the spell/item
  out = 7058,                     -- crafted item ID (nil for enchants); drives disenchant predictions
  count = 20,                     -- crafts the guide estimates for the whole range
  mats = { {4305, 4}, {2604, 2}, {2321, 2} },   -- { itemID, per craft }
  rank = "expert",                -- optional: must train this rank first
  formula = 20752 / pattern = 14481,  -- optional: recipe item that must be bought
  route = "dust" | "essence",     -- enchanting only: which 20-150 route it belongs to
  tip = "...",                    -- optional one-liner shown in the UI
  alts = { <step>, ... } }        -- optional alternatives shown indented
```

`ns.Steps(prof)` returns the active list (enchanting filtered by `ns.db.enchantRoute`).

## Logic.lua: the important functions

| Function | Returns |
| --- | --- |
| `ns.Snapshot()` (Core) | `{ level, faction "H"/"A"/"N", tailoring = {skill,max}|nil, enchanting = ..., money, canDisenchant }` |
| `ns.CurrentStep(prof, skill)` | first step with `skill < to` |
| `ns.RemainingCrafts(step, skill)` | crafts left, scaled linearly inside the range |
| `ns.Mats(step, crafts)` | `{ id, need, have, ok }` list (bags + bank) |
| `ns.TrainingNeed(prof, snap)` | rank to train now (or the level you need), or nil |
| `ns.PredictDE(itemOrLink)` | outcomes with odds and quantities, expected value, vendor price |
| `ns.StepDE(step)` | what a tailoring step's output disenchants into, per craft and total |
| `ns.EnchantStepsUsing(id)` / `ns.TailoringSourcesOf(id)` | the synergy links in both directions |
| `ns.RemainingNeed(prof, skill, id)` | how many of an item the rest of the path still uses |
| `ns.ScanBags()` | disenchantable items in bags with predictions |
| `ns.CraftProfit(craft)` | `{ cost, sale, profit }` from Auctionator prices |
| `ns.RecipeColor(spell, skill)` | `"orange"/"yellow"/"green"/"grey"` or nil, from `Data/RecipeSkill.lua` only (the Forever client reports no recipe difficulty) |
| `ns.PathProfession(spell)` | `"tailoring"` / `"enchanting"` when a recipe is on a path (alternatives included), else nil |
| `ns.EstimateCrafts(prof, step, skill)` | crafts left, counted point by point through the static colours (yellow ~1.6 and green ~4 crafts per point): `n, about, color` |
| `ns.ChooseStep(prof, skill)` | what to craft now: the guide's step or an alternative you know that is better (`reason` = `"learned"`, `"color"`, `"bags"`, `"cost"`), with `crafts`, `about`, `color`, `grey` |
| `ns.CapNeeds(prof, snap)` | everything the remaining steps up to the trainer cap use: `totals[id], order, cap, produced[id]` (what your own steps make, e.g. bolts) |
| `ns.CapBudget(prof, snap)` | nil without Auctionator, else `{ cap, cost, unknown, top, money, short, done }` for the missing AH mats; `ns.BudgetText(b, compact)` words it |
| `ns.CountAlts(id)` (Core) | total and list of what your other characters (same realm(s) and faction) hold: own cache in `DustyThreadyDB.chars`, Syndicator wins when installed |
| `ns.CountMail(id)` (Core) | what this character's mailbox held when last opened; `ns.CountElsewhere(id)` = mailbox + alts |

Disenchant predictions read **live item info** (quality, required level, weapon/armor), so they work
for any item, not only the ones in our data.

## Events and refresh

`ns:On(event, fn)` registers game events (or custom `DT_*` events). Bag, skill, money, level and
recipe events all call `ns:RequestRefresh()`, which coalesces bursts into one `DT_REFRESH` after
0.25 s. The main window only rebuilds the visible tab (`Main:Refresh`). Tabs are built lazily on
first view (`build(page)`), then `refresh(page, snap)` re-lays them out. Rows come from `UI.Pool`.

## WoW Forever API notes (learned the hard way)

- Interface number is **16001**. It is a modern client with classic content:
  `GetSpellInfo`, `GetNumSkillLines`, `GetSkillLineInfo` are **nil**. Use `C_Spell.GetSpellName`,
  `GetProfessions()` + `GetProfessionInfo()` (skill line IDs: Tailoring 197, Enchanting 333), or
  `C_SkillInfo.GetSkillLineInfoByID(id)` (`.rank`, `.maxRank`).
- `C_Item.*`, `C_Container.*`, `C_TradeSkillUI.*`, `TooltipDataProcessor`, `BackdropTemplate` exist.
- Some values can be **secret** during combat (`issecretvalue`). `ns.clean(v)` strips them; wrap
  API calls in `pcall`.
- The default font (Friz Quadrata) has no arrows, check marks or "≈". Use Latin-1 only
  (`» « · ×`) or textures (`|TInterface\RaidFrame\ReadyCheck-Ready:12|t`). A quick check:
  search the Lua files for any character above U+00FF before committing.
- **Secure buttons**: a `SecureActionButtonTemplate` inside our window would make the whole window
  protected (can't move/close it in combat). The one-click disenchant uses a **single overlay button
  parented to UIParent**, positioned by absolute coordinates over the row you hover, and hidden on
  `PLAYER_REGEN_DISABLED`. Its macro is `/cast Disenchant` + `/use <bag> <slot>`.
  It registers `AnyUp, AnyDown` because of the `ActionButtonUseKeyDown` CVar.
- **Crafting** (`Craft.lua`): `C_TradeSkillUI.CraftRecipe(spellID, n)` works from an addon click
  (no secure button), but only while that profession is open: check `IsTradeSkillReady()` and
  `GetBaseProfessionInfo().professionID` (197 / 333), else `OpenTradeSkill(line)` first. If it isn't
  ready within the same click, the player clicks again: never craft from an event handler. Enchants
  on items use `CraftEnchant(spellID, 1, nil, ItemLocation)`; the fallback casts the recipe and applies
  it with `PickupInventoryItem` / `C_Container.PickupContainerItem` while `SpellIsTargeting()`.
  The enchant's slot comes from its spell ID (`ns.ENCHANT_SLOT`, `Data/EnchantSlots.lua`); parsing
  the (localized) spell name is only the fallback (`ns.EnchantSlotKey` in `Craft.lua`).
- **Map pins** (`UI/MapPin.lua`): `C_Map.SetUserWaypoint` isn't reliable on Forever, so (like
  ForeverDungeonJournal) we draw our own pin on `WorldMapFrame:GetCanvas()` at
  `width * x/100, -height * y/100`, shown only while `WorldMapFrame:GetMapID()` is the NPC's map.
  NPC names are custom hyperlinks `|Hdtnpc:<name>|h...|h`; a frame that shows them needs
  `ns.EnableNpcLinks(frame)`. The map can't be opened by an addon in combat: the pin waits.
- **Chat**: links and chat go through `ns.InsertLink` / `ns.OpenChat` (`ChatFrameUtil.*` on this
  client, old globals as fallback). `IsModifiedClick("CHATLINK")` ignores right clicks: check
  `IsShiftKeyDown()` for shift-right-click.
- Item info may not be cached yet: `ns.ItemInfo` returns nil and requests it; the
  `GET_ITEM_INFO_RECEIVED` event triggers a refresh. Use `ns.ItemName(id)` for display: it falls
  back to `ns.ITEM_NAMES`.

- **No realms, two-part names**: Forever has rulesets, not realms. `GetRealmName()` and
  `GetNormalizedRealmName()` return `""`; `UnitFullName("player")` returns the first and the **last
  name** (`"Frieza", "Cold"`). The WTF folders are `WTF\Account\<ACCOUNT>\93\Frieza-Cold`.
  `GetRealmID()` gives nothing either. The ruleset comes from
  `C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset)` (also `RPRuleset`, `HardcoreRuleset`).
  At `PLAYER_LOGOUT` the bags already read as empty: never save counts then.
- **Minimap button**: always go through LibDBIcon. Minimap-button managers (e.g. Leatrix Plus)
  refuse custom buttons and show *This is a custom button* in the tooltip.

## Localization

- `Locales/<code>.lua` load first and fill `ns.LOCALES[code]`; `Locale.lua` then creates `ns.L`
  and picks the table for `GetLocale()`. The English text **is** the key: `L["Shopping list"]`,
  `L["Train %s now%s: %s, %s."]:format(...)`. A missing (or empty) translation returns the key, so
  untranslated texts stay English. Lookups are not cached: `ns.SetLocale(code)` switches at once.
- Every file that shows text starts with `local _, ns = ...` then `local L = ns.L`. Wrap texts
  **where they are shown**, not where they are stored: `Data/` stays English (tips, sources, rank
  names, slot keys) and the UI shows `L[step.tip]`, `L[r.name]`, `L[src[1]]`... Logic that compares
  data strings (`ns.KeyReagent` looks for "Disenchant" in `ns.SOURCES`) keeps working.
- Never wrap identifiers, saved-variable keys, event names, macros or values that are compared.
  The disenchant macro uses the client's spell name (`ns.SpellName(13262, "Disenchant")`).
- Game names come from the client: items (`ns.ItemName`), spells (`ns.SpellName`), zones
  (`ns.ZoneName(englishName)`: the map name of `ns.ZONE_MAPS[name]` on a non-English client,
  else `L[name]`), faction names (`FACTION_HORDE`), soulbound text (`ITEM_SOULBOUND`).
  Zone matching uses UiMapIDs (`UI/ZoneHint.lua`), enchant slots use spell IDs. NPC names stay
  English: they are the keys of `ns.NPC_COORDS` and the map links.
- Plurals: two keys (`"%d item"` / `"%d items"`). English articles: `ns.Article(word)` adds
  "a"/"an" only when no translation is active; translated sentences are written around the word.
- Testing another language on any client: `/dusty locale deDE` (or `frFR`, `enUS`, `auto`), then
  `/reload` so texts built at load time (binding names, the verdict labels) follow too. Saved in
  `DustyThreadyDB.locale`.
- Translations must keep every `%s`/`%d` in the same order and stay Latin-1 (German and French
  accents are fine; no curly quotes, no ellipsis character, no French "oe" ligature). Check the
  locale files for characters above U+00FF like the rest of the code.

## Saved variables

- `DustyThreadyDB` (account): minimap, tooltip toggle, window position, last tab, enchant route,
  roadmap profession, `ignoredDE` (items the player chose to keep), `zoneHints` (false = no cloth
  farm hints; nil/true = on), `locale` (forced language, nil = the client's), and:
  - `chars["First Last-Group"]` = `{ name, last, realm, faction, class, level, updated, items = { [itemID] =
    { bags, bank, mail } } }`: what each character holds of the items DustyThready tracks
    (filled by each character's bag / bank / mailbox scans; read by `ns.CountAlts`). Forever has
    no realms (only rulesets) and characters have a last name: the key is `"Frieza Cold-PvE"`. The
    group is the ruleset (`PvE`, `PvP`, `RP`, `RPPvP`, `HC`, read from `C_GameRules` like
    Auctionator does), or the realm name on clients that have one. No scan at logout: bags read
    empty then. `charsVersion` = 4 (older records were dropped).
  - `mooncloth["Name-Realm"]` = `{ readyAt = epoch seconds (0 = ready), class }`: Mooncloth
    cooldown per tailor (`Endgame.lua`).
- `DustyThreadyCharDB` (character): `learned` recipe cache and `scanned` (profession lines whose
  recipe list was read), filled while a profession window is open. (v1.2.0 also stored a
  `difficulty` table; Forever never filled it, and it is cleared at load.)
