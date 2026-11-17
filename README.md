# Project Inventory

A UI reskin and inventory overhaul for **Project Zomboid Build 42** (42.20 or later). Lua only, no Java and no dependencies.

> Status: in development (`0.3.0-dev`). Singleplayer only until 1.0.

## Features
- Themed inventory and loot windows: category colours, load bar, compact stacks, item states, Lua tooltips.
- Nested containers open in their own windows (double click or "Open").
- First-level search in inventory and loot.
- Compact equipment and health window with a 3D character render and condition slots.
- Settings window (gear button in the player inventory): theme preset (Rust, Military, Night), UI scale, icon size, hidden or grouped equipped items, per-module toggles.
- Collectibles: skill books, recipe magazines, map flyers, maps and recorded media show whether they were found in this world or read (status icon next to the name). NewMusic albums are supported.
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
Compatibility patches are welcome; see [LICENSE](LICENSE).

Modded items that use the vanilla properties (skill books, `LearnedRecipes` magazines, recorded media) are recognised automatically. Other collectibles can be declared in two ways.

A data file, no code needed: `media/lua/shared/RSK_Collect/<YourMod>.lua`
```lua
RSK_CollectData = RSK_CollectData or {}
-- a list: one collectible per item type
table.insert(RSK_CollectData, { id = "YourMod", items = { "YourMod.TapeA", "YourMod.TapeB" } })
-- a map: item types with the same value are one collectible
table.insert(RSK_CollectData, { id = "YourModAlbums", items = { ["YourMod.Album1Tape"] = "album1", ["YourMod.Album1CD"] = "album1" } })
```

Or the Lua API (client side, after Project Inventory has loaded):
```lua
if RSK and RSK.Collect and RSK.Collect.register then
    RSK.Collect.register({ id = "YourMod", match = function(item, fullType)
        return fullType:find("^YourMod%.Tape") and fullType or nil -- a key, or nil if not a collectible
    end })
end
```
Items from these sources show "not found" / "found" only: Project Inventory adds no "read" flag of its own.

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
