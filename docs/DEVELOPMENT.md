# Development

## Local setup

The repository lives at `D:\Development\wow`. The game loads the addon through a **directory
junction**, so edits in the repo are live after `/reload`:

```
F:\Battle.net\World of Warcraft\_forever_\Interface\AddOns\DustyThready
    -> D:\Development\wow
```

To recreate the junction (no admin rights needed), in PowerShell:

```powershell
cmd /c mklink /J "F:\Battle.net\World of Warcraft\_forever_\Interface\AddOns\DustyThready" "D:\Development\wow"
```

Useful in-game helpers (already installed): **BugGrabber + BugSack** to catch Lua errors,
`/reload` after each change, `/dump DustyThready.Snapshot()` to inspect state, `/fstack` to inspect frames,
`/console scriptErrors 1` to see errors immediately.

## Manual test checklist

Run through this before each release:

1. Log in: no Lua errors, welcome line once, minimap button shows, `/dusty` opens the window.
2. **Today**: both cards show the right skill and cap; *Next up* matches your skill; mats show
   have/need; alerts appear when you hit 50 / 125 / 200 (train) or need a formula/pattern.
3. Character without one of the professions: the card shows the "learn it" state, no errors.
4. **Roadmap**: switch professions and routes; current step is highlighted and scrolled into view;
   Shopping list opens; with Auctionator, *Send to Auctionator* creates the list.
   **Craft** (Today card and the highlighted Roadmap row): with the profession window closed, the
   first click opens it (and crafts if it's ready, else "click Craft again"); crafts the remaining
   count, shift-click crafts one. Without mats it says *Need mats*; at your cap *Train first*.
   Enchants: the item chip shows a target; clicking it lists bracers/boots/... in bags and equipped;
   *Enchant* applies it to the picked item.
   Shift-click the recipe icon (Today and Roadmap): the recipe link goes into chat (chat closed:
   it opens with the link). Shift-click a mat chip still links the item.
5. **Disenchant**: put greens in bags; rows appear with odds and value; hover the button and click
   to disenchant; *Keep* hides an item; *Cheat sheet* lists kept items and un-keeps them.
6. Enter combat with the window open: you can still move and close it; the Disenchant list says
   it will update after combat; no "action blocked" message.
7. **Where** and **Gold**: faction filter correct; *Write my ad* opens chat with the text (not sent).
8. Tooltips: a green shows *Disenchants into*; a reagent shows *still needs N*; toggle in Settings.
9. `/dusty minimap`, `/dusty reset`, drag the minimap button.

## Updating game data

All game knowledge is in `Data/`. No logic changes needed for most updates.

- **A leveling step changed**: edit `Data/Tailoring.lua` or `Data/Enchanting.lua`. Keep `from`/`to`
  contiguous, `count` = the guide's craft count, `mats` = per-craft amounts.
- **New item**: add its ID and English name to `ns.ITEM_NAMES` in `Data/Items.lua`, and a
  `ns.SOURCES` line if it is a reagent (`vendor = true` for vendor-only supplies).
- **Trainer / vendor**: `Data/Places.lua`. Faction code is `"H"`, `"A"` or `"N"` (both).
- **Disenchant table**: `Data/Disenchant.lua`. Rows are by *required* level.
- IDs: look them up on `https://www.wowhead.com/forever/` (Forever has its own new IDs, e.g.
  Mote of Magic 247786, Runecloth Cuffs 254123). The AtlasLoot data in the game folder
  (`AtlasLootContinued/Data/Profession.lua`) maps recipe spell -> crafted item and is a good
  cross-check.

Source guides: wow-professions.com `/forever/enchanting-leveling-guide`,
`/forever/tailoring-leveling-guide`, `/forever/disenchanting-guide`, `/forever/enchanting-trainers`,
`/forever/tailoring-trainers`.

## Releasing

1. Add the new version's section at the top of `CHANGELOG.md` (it becomes the CurseForge changelog).
2. Commit, then tag and push: `git tag v1.0.1` then `git push origin main --tags`.
3. CurseForge packages and publishes the tag automatically; GitHub Actions attaches the same zip to a
   GitHub Release (see [PUBLISHING.md](PUBLISHING.md)).

The toc's `## Version:` is `@project-version@` and is filled in from the tag: never edit it by hand.

If the game updates its Interface number, change `## Interface:` in the toc (find the current one in
any recently updated Forever addon's `.toc`, or `/dump select(4, GetBuildInfo())` in game).
