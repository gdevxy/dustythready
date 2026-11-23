# DustyThready: notes for Claude

World of Warcraft **Forever** addon (Interface 16001: modern retail engine, vanilla 1-60 content)
that pairs Tailoring and Enchanting. Owner plays a level ~40 character, cares a lot about polish and
simplicity ("no PhD menus"). Read `docs/ARCHITECTURE.md` before changing code.

- Addon code: the repository root (this folder is junctioned into
  `F:\Battle.net\World of Warcraft\_forever_\Interface\AddOns\DustyThready`, so edits are live after `/reload`).
- Game data only in `Data/`; logic in `Logic.lua`; UI in `UI/`.
- There is no Lua interpreter on this machine: review syntax carefully (Lua 5.1, no `goto`, no `//`).
- Only Latin-1 characters in UI strings (the game font lacks arrows, ≈, check marks). Check with a
  search for characters above U+00FF.
- Never put a SecureActionButton inside the main window (see the overlay in `UI/TabDisenchant.lua`).
- Installed Forever addons in the game folder (Auctionator, AtlasLootContinued, Questie, LootTriage...)
  are good references for which APIs exist on this client.
- Release flow and CurseForge: `docs/PUBLISHING.md`. Keep `CHANGELOG.md` updated.
- git is at `C:\Program Files\Git\cmd\git.exe` (may not be on PATH in a fresh shell). Remote uses SSH.
