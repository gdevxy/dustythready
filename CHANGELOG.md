# Changelog

## v1.2.1

- **Today shows what your crafts really gave**: *Last 10 crafts: +7 skill* next to the recipe, so
  you can check the "about N" estimate while you craft (this session, same recipe in a row).
- Recipe colours come only from the Forever data in the addon. The live reading from the
  profession window is gone: the Forever client never reports recipe colours.
- Fix: the *Thread & Dust* card named an Enchanting step you had already passed ("eats it at
  200-201" at skill 225), counted different crafts than the Tailoring card, and said *Go craft!*
  while Enchanting was at its trainer cap (now: *Train Artisan first, then craft*).

## v1.2.0

- **Recipe colours.** Today and the Roadmap show whether your recipe is orange, yellow, green or
  grey at your skill (WoW Forever values: Forever moved many Tailoring recipes). Crafts left are
  counted point by point ("about N" once it turns yellow), and Today tells you when to switch:
  *Turned yellow: switch to X (orange, you know it)*.
- **Works from your bags.** When an alternative recipe fits what you carry (or is cheaper at today's
  AH prices), Today recommends it and the Craft button crafts it.
- **Budget to the next cap.** *Reaching 225: about 14g at today's prices. You have 9g; short 5g,
  mostly Silk Cloth.* On the shopping list and the Today cards (needs Auctionator). The shopping list
  subtracts the bolts you'll sew yourself.
- **One profession only?** Today shows a full card for the one you have and a slim hint for the other.
- **Disenchant next key.** Bind *Disenchant next item* (Options > Keybindings > AddOns > DustyThready)
  and press it to disenchant your greens one by one. It never fires in combat or mid-cast.
- **The Disenchant tab tells you what to do with each item**, in this order:
  *Disenchant: your Enchanting needs these* (the reagent you're still short of, and how many),
  *Disenchant and sell the reagents* (worth more than the vendor pays),
  *Sell on the Auction House* (worth more than its reagents) and *Sell to a vendor*. Each row says
  why in one line, the summary lists the counts ("Disenchant 3 items for your Enchanting, Sell 1 on
  the Auction House..."), and the Today tab and item tooltips give the same advice. The advised
  action is the bright button: **Disenchant**, or **Sell** (one click while a vendor is open).
  Disenchanting stays possible on sell rows as a quiet button; the *Disenchant next* key only takes
  items worth disenchanting. **Keep** is now **Hide**. Soulbound items never show an AH price.
- **Recipe tooltips.** Patterns and formulas say whether you know them, when your path needs them, or
  that they're not on your path.
- **Enchanting for others.** Open a trade: a panel next to the trade window lists the enchants you
  know for the item in the *Will not be traded* slot, with mats, what the customer should bring, and
  a fair tip. **Enchant** casts it on their item. **Post my menu** writes your enchant list to chat.
- **Endgame tab** (shows at skill 250+): Mooncloth cooldown for all your tailors with a "ready"
  alert, crafts that pay at 300, patterns and enchants worth chasing and where they come from.
- The **Gold** tab's first card shows the same disenchant / sell / vendor counts.
- **This session** in the footer: skill-ups, dust gained, and gold saved vs vendoring.
- **Cloth farm hints.** Entering a zone where humanoids drop the cloth you need prints one chat line
  (can be turned off in settings).
- **Alts and mailbox.** Material chips show *(+15 alts)* or *(+5 mail)* when you're short, with
  who has what in the tooltip. Alts are remembered once they log in (or read from Syndicator).
  `/dusty forget <name>` removes a deleted character.
- **German and French.** The addon follows your client language; `/dusty locale deDE|frFR|enUS|auto`
  forces one. Translations are machine-assisted: corrections welcome.
- Recipes a trainer teaches (like Enchant Cloak - Greater Defense) now say which trainer rank teaches
  them and who, on Today, the Roadmap, the Where tab's next stops and the Craft button's tooltip.
  Once you've opened a profession, missing ones show as "Not learned" even with the window closed;
  before that, the button says **Open** instead of offering to craft a recipe you may not have.
- Fix: **Craft ×N** made only one when the profession wasn't open yet. Now the first click opens it
  and the next one crafts them all.

## v1.1.0

- One-click crafting: a **Craft** button on the Today cards and on your current Roadmap step. It opens
  the profession if needed and crafts what the step still needs (as far as your bags allow;
  shift-click crafts one).
- Enchants that go on an item let you pick the target first (bags or equipped, cheapest first), then
  **Enchant** applies it.
- Recipe icons on Today and the Roadmap link to chat: shift-click for the crafted item,
  shift-right-click for the pattern/formula (or the recipe when a trainer teaches it).
- NPC names (trainers, pattern and formula vendors, supply vendors) are links: click one to open the
  world map on its zone with a pin on the NPC (right-click the pin to remove it). TomTom gets a
  waypoint too. Positions come from QuestieDB's Forever data.
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
