# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/). Versions follow `0.MINOR.PATCH` until 1.0: MINOR = development phase, PATCH = fixes.

## [0.3.0-dev] — unreleased
### Added
- Collectibles (vanilla): skill books, recipe magazines and schematics, print media that reveal map locations, maps and recorded media are tracked per world as "found" once they enter the player inventory (nested bags included). Status icon next to the name: red exclamation mark = not found, eye = found, check = read (from the character's vanilla data).
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
