# THE LAST FLOOR – VACCINE PROTOCOL: SYSTEM ARCHITECTURE

## 1. Architectural Philosophy
The project enforces **Client–Server Separation of Concerns**:
- **Server Authority:** `GameManager.server.luau` and `Services/*` exclusively control match timers, puzzle state progression (`DoorUnjammed`, `ElevatorPower`, `ElevatorCalled`), `CrowbarTool` ownership & `DebrisWeld` physics, generator puzzle permutation verification, Crawler spawning/pathfinding/damage, health/revive/free-return state, and cabin boarding bounds.
- **Client Presentation:** `ClientInit.client.luau` and `Controllers/*` handle local HUD (`HUDController`), 4-slot hotbar sync (`InventoryController`), `F`-key flashlight (`FlashlightController`), sprint/crouch/noise intents (`MovementController`), generator schematic UI (`GeneratorController`), and 3s pry animation (`CrowbarClient.client.luau`).
- **Zero Client Trust:** Distance checks (`<= 14` for beam/workbench, `<= 25–28` for generator), `HasCrowbar` + Backpack tool ownership, issued generator `rightOrder` verification, and server-side `HumanoidRootPart.Position` bounds/noise tracking prevent client spoofing.

---

## 2. Synchronized Directory Hierarchy (`TheLastFloor/src/`)

```text
TheLastFloor/
├── default.project.json
├── rokit.toml
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Configuration/
│   │   │   └── GameConfig.luau           # Authoritative speeds, health, timers, noise radii, floor table
│   │   ├── CrowbarTool/
│   │   │   ├── init.meta.json            # Tool className metadata for Rojo build
│   │   │   └── CrowbarClient.client.luau # 3s pry lever animation & activated trigger
│   │   └── Remotes/                      # Network contract instances in Studio
│   │
│   ├── ServerScriptService/
│   │   ├── GameManager.server.luau       # Boots HealthManager, LobbyService, ElevatorService, FloorManager
│   │   ├── RoundManager.server.luau      # [RETIRED] Inert stub; superseded by FloorManager
│   │   └── Services/
│   │       ├── HealthManager.luau        # Downed crawl, 5s revive, 1 free return, spectator transition
│   │       ├── LobbyService.luau         # 1–6 player matchmaking & countdowns
│   │       ├── ElevatorService.luau      # Recessed cabin doors, GateSwitch, boarding bounds, F1 ascend
│   │       └── FloorManager.luau         # B1 3-stage lift puzzle, NoiseEmitted listener, Crawler AI
│   │
│   ├── StarterPlayer/
│   │   └── StarterPlayerScripts/
│   │       ├── ClientInit.client.luau    # Ordered controller boot + spawn typewriter hint
│   │       └── Controllers/
│   │           ├── HUDController.luau    # Objectives checklist, hints, alerts, timer, HP/STM, cinematics
│   │           ├── InventoryController.luau # 4-slot hotbar synced via InventorySync / GiveCrowbar
│   │           ├── FlashlightController.luau # F-key head SpotLight
│   │           ├── GeneratorController.luau  # Schematic + rust-masked 3-wire UI (Mouse/Touch/Keyboard)
│   │           └── MovementController.luau   # Sprint/Crouch stamina + NoiseEmitted + IsPrying respect
│   │
│   └── ServerStorage/
│       └── TheLastFloor/Enemies/Crawler  # Server-cloned DislocatedCrawler template (in Studio place)
│
└── docs/
    ├── MASTER_SPEC.md
    ├── ARCHITECTURE.md
    ├── PHASE_STATUS.md
    ├── BUG_TRACKER.md
    ├── TEST_REPORTS.md
    ├── GAME_DESIGN.md
    ├── FLOOR_DESIGNS.md
    ├── ENEMY_DESIGNS.md
    └── TEST_PLAN.md
```

---

## 3. Network Communication Protocol (`ReplicatedStorage.TheLastFloor.Remotes`)

| Remote Name | Class | Direction | Purpose |
|---|---|---|---|
| `FloorStateChanged` | RemoteEvent | Server -> Clients | Broadcasts floor ID, name, code, duration, and description |
| `FloorTimerUpdate` | RemoteEvent | Server -> Clients | Countdown sync every second (`00:00` on expiry) |
| `PuzzleStateChanged` | RemoteEvent | Server -> Clients | Broadcasts `{ floorCode, floorName, obj1Done..obj4Done, hint, alert, alertColor }` |
| `GiveCrowbar` / `InventorySync` | RemoteEvent | Server -> Client | Synchronizes 4-slot hotbar additions/removals (`Crowbar`) |
| `BeamPried` | RemoteEvent | Client -> Server | Requests Stage 1 pry validation from `CrowbarClient` tool activation |
| `CrowbarPryState` | RemoteEvent | Server -> Client | Triggers `MissingCrowbar` alert or 3-second `StartPry` animation & progress bar |
| `RequestGeneratorPuzzle` | RemoteEvent | Client -> Server | Requests server-shuffled circuit order (`OpenGeneratorPuzzle`) |
| `OpenGeneratorPuzzle` | RemoteEvent | Server -> Client | Delivers server-generated `{ order }` to `GeneratorController` |
| `GeneratorFixed` | RemoteEvent | Client -> Server | Submits `{ [1..3] = portIdx }` for authoritative server verification |
| `NoiseEmitted` | RemoteEvent | Client -> Server | Reports sprint noise; server records authoritative `HRP.Position` for Crawler AI |
| `ElevatorWarning` | RemoteEvent | Server -> Clients | 3-second red vignette + audio alert upon elevator call |
| `CrawlerEncounterTriggered` | RemoteEvent | Server -> Clients | Triggers `2.2s` DislocatedCrawler cinematic reveal pan |
| `ElevatorAscending` | RemoteEvent | Server -> Clients | Camera rumble & Floor 1 transition overlay |
| `PlayerDowned` / `PlayerRevived` / `PlayerEliminated` / `SetSpectatorMode` | RemoteEvent | Server -> Client(s) | Squad downed alerts, revive sync, 5s free return banner, and spectator switch |
