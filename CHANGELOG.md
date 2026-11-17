# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/). Versions follow `0.MINOR.PATCH` until 1.0: MINOR = development phase, PATCH = fixes.

## [0.3.0-dev] — unreleased
### Added
- Collectibles (vanilla): skill books, recipe magazines and schematics, print media that reveal map locations, maps and recorded media are tracked per world as "found" once they enter the player inventory (nested bags included). Status icon next to the name, as filled badges drawn for each size: red with exclamation mark = not found, grey with eye = found, green with check = read (from the character's vanilla data).
- Collectibles from other mods: `RSK.Collect.register` API and `media/lua/shared/RSK_Collect/` data files (see README); built-in NewMusic support, one collectible per album (any cassette side, vinyl, CD or full case).
- Themed context menu (right click): same layout and behaviour as vanilla, theme colours; options added by other mods are untouched. Can be turned off in Settings → Modules.
- Settings, Inventory tab: "Reset found items when the character dies" (on by default); turned off, the next character in the same world keeps the found list.

## [0.2.0] — 2026-11-15
### Added
- Core: modules with dependencies, vanilla fallback on error, event bus, config file in `Zomboid/Lua/`.
- Themes Rust, Military and Night; themed widget library; bitmap Fira fonts scaled from the game's font size.
- Inventory and loot reskin: category colours, row tint, load bar, stacks, states, grouped "Equipped" items, Lua tooltips.
- Nested container windows (double click / "Open").
- First-level search in inventory and loot, "Take all" / "Transfer all" on visible items.
- Equipment and health window: 3D render, condition slots with holes, wound warning, skills, protection, temperature.
- Settings window: preset, UI scale, icon size, hidden equipped items, module toggles, reset to defaults, saved equipment window position.

### Fixed
- List scrollbar now starts below the header and its thumb follows the mouse.
- Background no longer disappears when changing scale with a collapsed inventory.
