<p align="center">
  <img src="Media/icon-source.jpg" width="128" alt="DustyThready icon">
</p>

<h1 align="center">DustyThready</h1>

<p align="center"><b>Tailoring + Enchanting, woven together.</b><br>
A World of Warcraft <i>Forever</i> addon that tells you what to craft next, what it disenchants into,
where to train, and how to turn it all into gold.</p>

---

## Why

Tailoring and Enchanting are the classic "no gathering needed" pair: cloth drops from the humanoids
you're already killing, Tailoring turns it into green items, and Enchanting turns those greens into
the dust it needs to level. Guides explain this on a web page. DustyThready keeps it in the game,
works it out from **your** skill, bags and level, and stays out of your way.

Design rules:

- **One glance is enough.** The *Today* tab answers "what do I do now?" for both professions.
- **No menus to learn.** Five tabs (a sixth, *Endgame*, appears at skill 250), almost no settings.
- **Live, not static.** Counts come from your bags and bank, prices from Auctionator's last AH scan.

## Features

| Tab | What it shows |
| --- | --- |
| **Today** | Both professions: skill bar with your trainer cap, the next recipe and how many crafts are left, your materials (have / need), a one-click **Craft** button (enchants let you pick the item to enchant first), alerts like *Train Expert now*, *Buy Formula: Minor Mana Oil*. A **Thread & Dust** card explains how your next crafts feed the other profession, and what you're short of. |
| **Roadmap** | The full 1-300 path for each profession (Forever-specific, including the new Runecloth Cuffs and Mote of Magic recipes). Done steps fade out, your current step is highlighted (with its **Craft** button), alternatives are indented. Enchanting has a *Strange Dust* or *Magic Essence* route. **Shopping list** shows what you still need up to your current cap and can create an **Auctionator shopping list** in one click. |
| **Disenchant** | Every green/blue/purple weapon or armor in your bags, what it will turn into (with odds), what to do with it (*disenchant it for your Enchanting*, *disenchant and sell the dust*, *sell it on the AH* or *vendor it*) and why, with a **one-click Disenchant** or **Sell** button. A *Cheat sheet* view shows the whole disenchant table, with your level's rows highlighted. |
| **Where** | Your next stops (trainer, formula, pattern), every trainer by rank for your faction, recipe vendors, vendor-only supplies, and where each cloth drops by level. Click any NPC name (here, in Roadmap notes or Today alerts) to see it pinned on your world map. |
| **Endgame** | Shows from skill 250: Mooncloth cooldown for all your tailors, crafts that pay at 300, patterns and enchants worth chasing and where they come from. |
| **Gold** | Money ideas for a low-budget player: disenchant instead of vendoring, enchant for tips (writes your trade-chat ad), sell surplus dust, crafts that sell with a live profit estimate, bolts vs raw cloth, where to farm cloth at your level. |

Also:

- **Item tooltips** show what any green/blue/purple disenchants into, its value vs the vendor, and,
  on reagents, how many your remaining steps still need.
- **Recipe colours**: Today and the Roadmap know when your recipe turns yellow, adjust the crafts
  left, and suggest a better recipe you know or can make from your bags.
- **Disenchant next key**: bind it in Options > Keybindings > AddOns > DustyThready and press it to
  disenchant your greens one by one. Items worth more on the AH are skipped.
- **Enchanting for others**: open a trade and a panel lists the enchants you can put on the customer's
  item, the mats they should bring, a fair tip, and a *Post my menu* button.
- **Alts and mailbox**: material chips show what your other characters and your mailbox hold.
- **Session line** in the footer, **cloth farm hints** in chat when you enter a good zone.
- **English, German, French** (follows your client; machine-assisted translations).
- **Minimap button** (drag to move; right-click opens *Disenchant*) and the **addon compartment** entry.

## Install

Easiest: install it from **CurseForge** with the CurseForge app.

By hand: download the zip from the latest
[GitHub release](https://github.com/gdevxy/dustythready/releases), extract the `DustyThready` folder into
`World of Warcraft\_forever_\Interface\AddOns\`, then restart the game or type `/reload`.
(If you clone the repository instead, name the cloned folder `DustyThready`.)

Optional: install **Auctionator** for AH prices, profit estimates and shopping lists.

## Commands

| Command | Does |
| --- | --- |
| `/dusty` | Open / close the window |
| `/dusty de` | Open the Disenchant tab (`gold`, `road`, `where` work too) |
| `/dusty minimap` | Show / hide the minimap button |
| `/dusty reset` | Re-center the window |
| `/dusty forget <name>` | Forget a deleted character's materials |
| `/dusty locale deDE` | Force a language (`frFR`, `enUS`, `auto`) |

## Data sources

Leveling paths, trainers, recipe sources and the disenchant table follow the WoW Forever guides on
[wow-professions.com](https://www.wow-professions.com/forever/) (enchanting, tailoring, disenchanting
and trainer pages). Item IDs and recipe IDs are Forever IDs. Cloth farming spots and money tips are
community knowledge. Counts are estimates: once a recipe turns yellow/green you may need a few more.

## For developers

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): how the code is organised, and the WoW Forever API quirks.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): local setup, testing checklist, how to update game data.
- [docs/PUBLISHING.md](docs/PUBLISHING.md): releasing on CurseForge (and Wago / GitHub).
- [CHANGELOG.md](CHANGELOG.md)

## License

[MIT](LICENSE)
