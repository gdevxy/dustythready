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
   Recipe icon (Today and Roadmap): shift-click links the crafted item (enchants: the recipe),
   shift-right-click the pattern/formula, or the recipe if it's trainer-taught. With chat closed,
   chat opens with the link. Shift-click a mat chip still links the item.
   Recipe colour shows next to the skill on Today ("yellow", "about N" crafts) and on the current
   Roadmap row; it comes from `Data/RecipeSkill.lua` (the client reports none).
   Craft a few of the Today recipe: its line shows *Last N crafts: +M skill* (counts each
   successful cast, also from the batch Craft button; +0 in warn colour once it stops paying).
5. **Disenchant**: put greens in bags; rows are grouped by advice (*Disenchant: your Enchanting
   needs these* / *Disenchant and sell* / *Sell on the AH* / *Sell to a vendor*), each with a one-line
   reason; the summary lists the counts. The advised action is the bright button: hover + click
   Disenchant works; on a vendor row, **Sell** is dim until a merchant is open, then sells it; the
   quiet Disenchant button still works. *Hide* hides an item; *Cheat sheet* lists hidden items and
   un-hides them. Today's bag line and the Gold tab's first card show the same counts.
   **Disenchant next key** (Options > Keybindings > AddOns > DustyThready): one press = one
   disenchant of the top advised item; pressing again during the cast does nothing (never equips);
   in combat it only prints a line; it skips sell/vendor items.
6. Enter combat with the window open: you can still move and close it; the Disenchant list says
   it will update after combat; no "action blocked" message.
7. **NPC links** (map icon before a name: Where tab, Roadmap notes, Today alerts): click opens the
   map on the right zone with the DustyThready pin on the NPC; hover shows coordinates; right-click
   the pin removes it. Clicking a link in a Today alert doesn't switch to the Where tab.
   **Where** and **Gold**: faction filter correct; *Write my ad* opens chat with the text (not sent).
8. Tooltips: a green shows *Disenchants into*, AH / DE / vendor values and the advice; a reagent
   shows *still needs N*; a pattern/formula says known / needed at N / not on your path; toggle in
   Settings.
9. `/dusty minimap`, `/dusty reset`, drag the minimap button.
10. **Trade** (needs an alt or a friend): open a trade, they put an item in *Will not be traded*;
    the panel next to the trade window lists fitting enchants with mats and a tip; **Enchant**
    applies it (watch for "action blocked"); *Post my menu* opens a whisper (right-click: `/2`).
11. **Alts and mail**: an alt with cloth in bags/bank logs in once; back on the main, a short mat chip
    shows *(+N alts)*, its tooltip lists who has it; open the mailbox with mats attached: *(+N mail)*.
    `/dusty forget <name>` removes an alt.
12. **Endgame tab** only at skill 250+; Mooncloth cooldown and alert on a tailor who knows it.
    Footer shows *This session: +N Tailoring...* after a skill-up or a disenchant. Entering a cloth
    zone for your level prints one hint (Settings checkbox turns it off).
13. **Locale**: `/dusty locale deDE`, `/reload`: German texts, no clipped buttons, binding name in
    German; `/dusty locale auto` to go back.

## Updating game data

All game knowledge is in `Data/`. No logic changes needed for most updates.

- **A leveling step changed**: edit `Data/Tailoring.lua` or `Data/Enchanting.lua`. Keep `from`/`to`
  contiguous, `count` = the guide's craft count, `mats` = per-craft amounts.
- **New item**: add its ID and English name to `ns.ITEM_NAMES` in `Data/Items.lua`, and a
  `ns.SOURCES` line if it is a reagent (`vendor = true` for vendor-only supplies).
- **Trainer / vendor**: `Data/Places.lua`. Faction code is `"H"`, `"A"` or `"N"` (both). Then
  regenerate the map positions (needs the QuestieDB addon installed in the game):
  `powershell -ExecutionPolicy Bypass -File tools\extract-npc-coords.ps1`. It rewrites
  `Data/Coords.lua` and lists NPCs it couldn't place. Supply NPCs that only appear in texts go in the
  script's `$extra` list.
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
