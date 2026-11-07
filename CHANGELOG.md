# CHANGELOG: THE LAST FLOOR – VACCINE PROTOCOL

All notable project changes, milestones, and architectural updates will be documented in this log.

## [Unreleased] - Phase 0: Project Setup & Architecture
### Added
- Standardized Roblox Studio development directory structure matching master blueprint.
- `default.project.json` for Rojo synchronization with Roblox Studio.
- `rokit.toml` manifest configuring project toolchains (Rojo, Selene, StyLua).
- Centralized configuration module `GameConfig.luau` containing all floor timers, sound radii, downed parameters, and floor metadata.
- Comprehensive technical and game design documentation:
  - `docs/GAME_DESIGN.md`
  - `docs/ARCHITECTURE.md`
  - `docs/FLOOR_DESIGNS.md`
  - `docs/ENEMY_DESIGNS.md`
  - `docs/TEST_PLAN.md`
- Network Remote contracts for health, revive, spectator, and floor synchronization.
- Initial elevator prototype structure and controller in Roblox Studio (`Place1.rbxl`).
