# Changelog

## v1.1.0

- One-click crafting: a **Craft** button on the Today cards and on your current Roadmap step. It crafts
  what the step still needs (as far as your bags allow; shift-click crafts one). If that profession
  isn't open yet, the first click opens it and the next one crafts.
- Enchants that go on an item let you pick the target first (bags or equipped, cheapest first), then
  **Enchant** applies it.
- Recipe icons on Today and the Roadmap link to chat: shift-click for the crafted item,
  shift-right-click for the pattern/formula (or the recipe when a trainer teaches it).
- NPC names (trainers, pattern and formula vendors, supply vendors) are links: click one to open the
  world map on its zone with a pin on the NPC (right-click the pin to remove it). TomTom gets a
  waypoint too. Positions come from QuestieDB's Forever data.
- Recipes a trainer teaches (like Enchant Cloak - Greater Defense) now say which trainer rank teaches
  them and who, on Today, the Roadmap, the Where tab's next stops and the Craft button's tooltip.
  Once you've opened a profession, missing ones show as "Not learned" even with the window closed;
  before that, the button says **Open** instead of offering to craft a recipe you may not have.
- Fix: shift-right-click on a recipe icon now links the pattern (it did nothing).
- Fix: shift-click item links and *Write my ad* use the client's current chat API.

## v1.0.0

First version.

- Today tab: what to craft next for Tailoring and Enchanting, materials have/need, training and recipe alerts,
  "Thread & Dust" synergy card.
- Roadmap tab: Forever 1-300 paths for both professions (Strange Dust or Magic Essence route for Enchanting),
  shopping list with Auctionator export.
- Disenchant tab: bag scan with odds, value vs vendor, one-click disenchant, cheat sheet.
- Where tab: trainers, formula and pattern vendors, supplies, cloth farming spots, filtered by faction.
- Gold tab: money ideas with live Auctionator prices.
- Disenchant and reagent info in item tooltips, minimap button (LibDBIcon), addon compartment entry.
