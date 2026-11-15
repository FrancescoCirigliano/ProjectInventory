# Project Inventory

A UI reskin and inventory overhaul for **Project Zomboid Build 42** (42.20 or later). Lua only, no Java and no dependencies.

> Status: in development (`0.2.0-dev`). Singleplayer only until 1.0.

## Features
- Themed inventory and loot windows: category colours, load bar, compact stacks, item states, Lua tooltips.
- Nested containers open in their own windows (double click or "Open").
- First-level search in inventory and loot.
- Compact equipment and health window with a 3D character render and condition slots.
- Settings window (gear button in the player inventory): theme preset (Rust, Military, Night), UI scale, icon size, hidden or grouped equipped items, per-module toggles.
- Bitmap Fira Sans Extra Condensed fonts that follow the game's font size setting.

Every module can be turned off, and on error it falls back to the vanilla UI. The mod can be added to or removed from an existing save.

## Install
Subscribe on the Steam Workshop (coming later), or copy the repository's `42/` and `common/` folders into `Zomboid/mods/ProjectInventory/`, then enable **Project Inventory** in the mod list.

## Roadmap
1. **0.2 (beta 1):** inventory MVP.
2. **0.3:** collectible tracking (vanilla and modded), context menu and all game screens.
3. **0.4:** vehicle dashboards, radio/TV/generator HUD.
4. **1.0:** full customisation, multiplayer evaluation.

## For modders
Compatibility patches are welcome; see [LICENSE](LICENSE). A public API for registering modded collectibles (`RSK.Collect.register`) will arrive in 0.3.

## Development
Unit tests (Lua 5.1 through [lupa](https://pypi.org/project/lupa/)):

```
python tests/run_unit.py
```

In-game tests: start the game with `-debug`, right-click in the world → "RSK: esegui test".

Release build (checks versions and tests, excludes the in-game tests, zips the mod):

```
powershell -File tools/release.ps1 -Version 0.2.0            # dry run
powershell -File tools/release.ps1 -Version 0.2.0 -Publish   # also tags v0.2.0
```

## License
All rights reserved, with the permissions listed in [LICENSE](LICENSE). Fonts: SIL OFL 1.1.
