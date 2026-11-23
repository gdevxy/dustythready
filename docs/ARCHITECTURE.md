# Architecture

DustyThready is plain Lua + the WoW widget API. No libraries, no XML. Everything lives in one
namespace table `ns` (the second value of `...` in every file), also exposed as `_G.DustyThready`
for debugging (`/dump DustyThready.Snapshot()`).

## File map (load order = `DustyThready.toc`)

```
DustyThready/
  DustyThready.toc      Interface 16001 (WoW Forever), saved variables, addon compartment hooks
  Core.lua              namespace, colors, saved vars, event bus, safe API wrappers, items, money,
                        prices (Auctionator), profession skill reading, slash commands
  Data/
    Items.lua           fallback English item names + "where to get it" per reagent (ns.SOURCES)
    Tailoring.lua       ns.RANKS (trainer ranks) and ns.TAILORING (1-300 steps)
    Enchanting.lua      ns.ENCHANTING (1-300 steps, two routes) and ns.POPULAR_ENCHANTS
    Disenchant.lua      ns.DE_ROWS (required level -> reagents) and ns.DE_ODDS
    Places.lua          ns.TRAINERS, ns.RECIPE_SOURCES, ns.SUPPLIES, ns.CLOTH_FARMS
    Gold.lua            ns.GOLD_CRAFTS (crafts with live profit), ns.BOLTS (bolt vs cloth)
  Logic.lua             pure-ish functions over data + game state (see below)
  UI/
    Widgets.lua         ns.UI: Panel, Text, Button, Pill, ProgressBar, ItemButton, Scroll, Pool,
                        Segmented, LayoutMats (have/need chips)
    Main.lua            window, header, tab bar, footer, settings popover, ns.RegisterTab
    TabToday.lua        profession cards + "Thread & Dust" synergy card + bag teaser
    TabRoadmap.lua      step list, route switch, shopping list popover (+ Auctionator export)
    TabDisenchant.lua   bag scan, secure one-click disenchant overlay, cheat sheet
    TabPlaces.lua       "Where": next stops, trainers, recipes, supplies, cloth farms
    TabGold.lua         money cards
    Tooltip.lua         item tooltip lines (TooltipDataProcessor)
    Minimap.lua         minimap button
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
- Item info may not be cached yet: `ns.ItemInfo` returns nil and requests it; the
  `GET_ITEM_INFO_RECEIVED` event triggers a refresh. Use `ns.ItemName(id)` for display: it falls
  back to `ns.ITEM_NAMES`.

## Saved variables

- `DustyThreadyDB` (account): minimap, tooltip toggle, window position, last tab, enchant route,
  roadmap profession, `ignoredDE` (items the player chose to keep).
- `DustyThreadyCharDB` (character): `learned` recipe cache, filled while a profession window is open.
