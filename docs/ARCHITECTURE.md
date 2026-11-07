# THE LAST FLOOR – VACCINE PROTOCOL: SYSTEM ARCHITECTURE

## 1. Architectural Philosophy
The project enforces a strict **Client-Server Separation of Concerns** adhering to authoritative multiplayer guidelines:
- **Server Authority:** The server exclusively controls match progression, round states, damage evaluation, inventory mutation, puzzle resolution, elevator locks, and enemy AI decision loops.
- **Client Prediction & Presentation:** The client handles local character responsiveness (camera, footstep synthesis, crouch kinematics, flashlight rendering, HUD updates, screen shakes, audio spatialization) and sends lightweight action intent payloads to the server.
- **Zero Client Trust:** Hitscan traces, interact prompt durations, health alterations, and checkpoint skips proposed by clients are rigorously validated on the server against character position, raycasts, and state timestamps.

---

## 2. Directory Hierarchy and Role Breakdown

```text
TheLastFloor/
│
├── default.project.json           # Rojo data-model mapping configuration
├── rokit.toml                     # Rokit toolchain manifest (Rojo, Selene, StyLua, Wally)
├── README.md                      # Installation, build, and development instructions
├── CHANGELOG.md                   # Version and milestone tracking
├── .gitignore                     # Git exclusion rules for Roblox build artifacts
│
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Configuration/         # Centralized game balance, timers, sound tables
│   │   │   └── GameConfig.luau
│   │   ├── Remotes/               # Network RemoteEvent & RemoteFunction contracts
│   │   ├── Shared/                # Reusable cross-boundary utilities, types, math
│   │   └── Assets/                # Shared animations, sounds, icons
│   │
│   ├── ServerScriptService/
│   │   ├── GameManager.server.luau# Master match lifecycle controller
│   │   ├── RoundManager.server.luau# Intermission, floor loading, timer loops
│   │   └── Services/              # Modular backend microservices
│   │       ├── HealthManager.luau
│   │       ├── ElevatorService.luau
│   │       ├── PuzzleService.luau
│   │       ├── NoiseService.luau
│   │       └── EnemyDirector.luau
│   │
│   ├── ServerStorage/
│   │   ├── ZombieModels/          # Server-only enemy physical archetypes
│   │   ├── GhostModels/           # Supernatural physical/mesh containers
│   │   ├── WeaponModels/          # Server pick-up prefabs and hitboxes
│   │   └── FloorAssets/           # Dynamic floor chunks (B1 to F10)
│   │
│   ├── StarterPlayer/
│   │   └── StarterPlayerScripts/
│   │       ├── ClientInit.client.luau # Client bootstrap
│   │       └── Controllers/       # Client presentation controllers
│   │           ├── CameraController.luau
│   │           ├── MovementController.luau
│   │           ├── FlashlightController.luau
│   │           ├── SoundDetectorController.luau
│   │           ├── HUDController.luau
│   │           └── SpectatorController.luau
│   │
│   ├── StarterGui/                # UI screens: HUD, Menus, Puzzles, Downed Indicator
│   └── Workspace/                 # Static place geometry: Elevator, Lobby base, Lighting
│
├── assets/                        # Raw 3D models, textures, audio stems, references
├── docs/                          # Engineering & design specifications
└── tests/                         # Unit and integration test suites
```

---

## 3. Network Communication Protocol (Remotes)

| Remote Name | Class | Direction | Purpose |
|---|---|---|---|
| `PlayerDowned` | RemoteEvent | Server -> Clients | Broadcasts downed state, starting 30s bleedout HUD |
| `PlayerRevived` | RemoteEvent | Server -> Clients | Notifies squad of successful 5s revive completion |
| `PlayerEliminated` | RemoteEvent | Server -> Clients | Notifies squad of permanent or checkpoint death |
| `SetSpectatorMode` | RemoteEvent | Server -> Client | Instructs client to switch to spectator camera system |
| `NoiseEmitted` | RemoteEvent | Client -> Server | Informs server of loud action (sprint, jump, door) |
| `FloorStateChanged`| RemoteEvent | Server -> Clients | Updates current floor, title, active objectives |
| `FloorTimerUpdate` | RemoteEvent | Server -> Clients | Synchronizes countdown timer with server clock |
| `ElevatorAction` | RemoteFunction| Client -> Server | Requests elevator activation / button press |
| `SubmitPuzzleCode` | RemoteFunction| Client -> Server | Submits a keypad code or puzzle item combination |
