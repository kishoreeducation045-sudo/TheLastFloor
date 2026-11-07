# THE LAST FLOOR – VACCINE PROTOCOL

**Engine:** Roblox Studio / Luau  
**Target:** 1–6 Player Cooperative Survival Horror  
**Visual Style:** Classic Roblox Avatars with Cinematic Realistic Environments  

---

## 1. Quick Start & Synchronization

This project is authored using modular Luau and synchronized via **Rojo 7.7.1**.

### Prerequisites
- [Roblox Studio](https://www.roblox.com/create)
- [Rojo 7.x](https://rojo.space/) (Installed via Winget: `winget install --id Rojo.Rojo`)
- [Rokit 1.2+](https://github.com/rojo-rbx/rokit) toolchain manager

### Connecting with Roblox Studio
1. Open your Roblox place file (e.g., `Place1.rbxl`) in **Roblox Studio**.
2. Open the Rojo Studio Plugin.
3. In your terminal, start the Rojo live-sync server:
   ```bash
   cd TheLastFloor
   rojo serve
   ```
4. In Roblox Studio, click **Connect** in the Rojo plugin window (default port `34872`).
5. Alternatively, compile a standalone place file:
   ```bash
   rojo build -o TheLastFloor.rbxlx
   ```

---

## 2. Project Directory Layout

```text
TheLastFloor/
│
├── default.project.json           # Rojo data-model mapping configuration
├── rokit.toml                     # Rokit toolchain manifest
├── README.md                      # Installation, build, and development instructions
├── CHANGELOG.md                   # Version and milestone tracking
├── .gitignore                     # Git exclusion rules
│
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Configuration/         # Centralized game balance & timers (GameConfig.luau)
│   │   ├── Remotes/               # Network RemoteEvent contracts
│   │   ├── Shared/                # Reusable modules
│   │   └── Assets/                # Shared animations, sounds, icons
│   │
│   ├── ServerScriptService/
│   │   ├── GameManager.server.luau# Master match lifecycle controller
│   │   ├── RoundManager.server.luau# Intermission, floor loading, timer loops
│   │   └── Services/              # Backend microservices (HealthManager, etc.)
│   │
│   ├── ServerStorage/
│   │   ├── ZombieModels/          # 8 Zombie physical models
│   │   ├── GhostModels/           # Phantom & Wraith models
│   │   ├── WeaponModels/          # Weapons & pick-ups
│   │   └── FloorAssets/           # Dynamic floor chunks (B1 to F10)
│   │
│   ├── StarterPlayer/
│   │   └── StarterPlayerScripts/
│   │       ├── ClientInit.client.luau # Client bootstrap
│   │       └── Controllers/       # Movement, HUD, Spectator controllers
│   │
│   ├── StarterGui/                # UI screens: HUD, Menus, Puzzles
│   └── Workspace/                 # Elevator cabin, lighting, collision zones
│
├── assets/                        # Raw 3D models, textures, audio stems
├── docs/                          # Detailed design and technical documents
│   ├── GAME_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── FLOOR_DESIGNS.md
│   ├── ENEMY_DESIGNS.md
│   └── TEST_PLAN.md
│
└── tests/                         # Unit and integration test suites
```

---

## 3. Floor Timers & Scaling

Every floor has a strict server-authoritative timer:
- **Basement B1:** 2 minutes (120s)
- **Scaling:** +1 minute 12 seconds (+72s) per subsequent floor

| Floor | Code | Timer | Encounter |
|---|---|---|---|
| Basement B1 | B1 | 2:00 | Truck Crash / Keypad Puzzle |
| Floor 1 | F1 | 3:12 | The Infected Residents (Resident, Screecher) |
| Floor 2 | F2 | 4:24 | The Cold Clinic (Exploder) |
| Floor 3 | F3 | 5:36 | Power Control Grid (Crawler) |
| Floor 4 | F4 | 6:48 | The Infected Ward (Blind Hunter) |
| Floor 5 | F5 | 8:00 | Research Lab Alpha (Runner) |
| Floor 6 | F6 | 9:12 | The Haunted Wing (Phantom) |
| Floor 7 | F7 | 10:24 | The Maintenance Maze (Brute) |
| Floor 8 | F8 | 11:36 | The Isolation Block (Mutant) |
| Floor 9 | F9 | 12:48 | The Final Guardian (Boss: The Abomination & Wraith) |
| Floor 10 | F10 | 14:00 | The Vaccine Protocol (Boss: The Origin) |

---

## 4. Player Survival Rules
- **Base Health:** 100 HP.
- **Downed State:** 30 seconds crawl with bleedout timer.
- **Revive:** 5.0 seconds hold interaction; restores 35 HP.
- **Lives:** 1 free return per round at elevator checkpoint.
- **Second Elimination:** Permanent spectator mode.
