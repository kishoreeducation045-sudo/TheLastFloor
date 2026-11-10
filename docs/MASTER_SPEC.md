# THE LAST FLOOR – VACCINE PROTOCOL: MASTER SPECIFICATION

**Engine:** Roblox Studio (Luau + Rojo 7.7.1)  
**Genre:** 1–6 Player Cooperative Survival Horror  
**Authoritative Configuration:** `src/ReplicatedStorage/Configuration/GameConfig.luau`  

---

## 1. Core Gameplay & Survival Rules
- **Squad Size:** `MinPlayers = 1`, `MaxPlayers = 6` (`LobbyService.luau`).
- **Health & Downed State (`HealthManager.luau`):**
  - Base Health: `100 HP` (Roblox default `Health` auto-regen script is removed on spawn so damage persists cleanly).
  - Reaching `0 HP` triggers **Downed State** (`PlatformStand = true`, `WalkSpeed = 0`, `30s` bleedout timer, `5.0s` teammate hold `RevivePrompt` restoring `35 HP`).
  - **First Elimination (`eliminations < MaxEliminationsBeforeSpectator` where `MaxEliminationsBeforeSpectator = 2`):** Triggers **1 Free Checkpoint Return** after `FreeReturnDelay = 5.0s` (`player:LoadCharacter()`), preserving puzzle progression attributes (`HasCrowbar`).
  - **Second Elimination:** Transitions the player permanently to **Spectator Mode** (`SetSpectatorMode` remote).
- **Stealth & Acoustic Radii (`GameConfig.NoiseRadii`, `MovementController.luau`):**
  - `WalkSpeed = 12`, `SprintSpeed = 19` (`35` stud sprint noise radius via `NoiseEmitted` every `0.6s`), `CrouchSpeed = 6` (`2` stud radius), `DownedSpeed = 3`.
  - Flashlight toggled via **`F`** key (`FlashlightController.luau`), slot 1 in 4-slot hotbar (`InventoryController.luau`).

---

## 2. Floor 0 (Basement B1) – Redesigned 3-Stage Cooperative Lift Puzzle

### Architectural Enclosure
- Enclosed subterranean concrete garage (`X:[-82..82]`, `Y:[0..20]`, `Z:[-112..112]`), sealed perimeter walls (`Wall_East`, `Wall_West`, `Wall_South`, `Wall_North_Left/Right/Top`), full floor platform (`GarageFloor`), ceiling (`GarageCeiling`), and an enclosed concrete shaft around the recessed North cargo lift (`ElevatorCabin`, `Z:[109.5..125.5]`).

### Objective Pipeline (`B1` Timer: `120s`)
Stage 1 and Stage 2 may be completed **in either order**; **both are mandatory** before Stage 3 unlocks.

#### **Stage 1 – Jammed Elevator Beam**
1. Collect **Heavy Crowbar** from the Maintenance Workbench (`X = 16, Z = 106.5`) via `CrowbarPrompt` (`Hold E` for `2.0s`).
2. Server grants `HasCrowbar` attribute, clones `CrowbarTool` onto `player.Backpack` (replicated in multiplayer), plays pickup sound, and syncs Hotbar Slot 2 (`C`).
3. Interact with `JammedBeam` (`PryPrompt` `[E]` or `CrowbarTool` activation within `14` studs). Missing crowbar triggers server rejection + HUD alert (`CROWBAR REQUIRED`).
4. Valid pry freezes player (`IsPrying` attribute), plays a **3.0-second** lever animation and spark strain sound, emits `CrowbarPry` noise (`45` studs), breaks physical `DebrisWeld` on server, drops `JammedBeam` physically with velocity & impact sound, sets `DoorUnjammed = true`, consumes `CrowbarTool`, restores `GameConfig.WalkSpeed (12)`, and updates `HUDController`.

#### **Stage 2 – Backup Generator**
1. Interact with `GeneratorPanel` (`[E]` key or `GeneratorPrompt`) to request an authentic shuffled circuit order (`RequestGeneratorPuzzle` -> `OpenGeneratorPuzzle`).
2. Solve the **rust-masked 3-wire circuit bypass** (`GeneratorController.luau`):
   - Background **etched wiring schematic diagram** provides visual trace lines and corroded symbol clues (`~` Phase α, `≈` Phase β, `⏚` Ground γ) while terminal colors remain hidden under rust until validly connected.
   - Supports **Mouse, Touch, and Keyboard** (`1-3`, `4-6`, Arrows/`WASD`, `Tab`, `Enter`/`Space`, `Esc`).
   - Incorrect pairs flash red, shake the panel, play fault buzz, and stay rusted.
   - Correct pairs strip rust to reveal Neon Red/Blue/Yellow, draw 3-layer glowing cables, lock LEDs, and validate exact port indices on server (`GeneratorFixed`).
3. Completion sets `ElevatorPower = true`, plays looped generator sound + subtle chassis vibration + 3-second exhaust smoke burst, turns generator light green, and ignites the 11 ceiling fixtures to **100% full industrial power** (`SpotLight.Brightness = 2.8`, `Range = 38`, `Shadows = true`, `PointLight.Brightness = 1.35`, `Range = 24`, `Shadows = true`, `Neon` glowing bulbs) with violent, erratic multi-lamp industrial horror flickering (asynchronous micro-strobe bursts at 25-35Hz, pitch-black sudden dropouts 0.3-1.3s, voltage sags, overvoltage flares, and 8-14s whole-grid generator stumbles) in a pitch-black ambient horror environment with dense claustrophobic fog (`FogEnd = 85`), and updates `ElevatorIndicator` to amber.

#### **Stage 3 – Call and Defend**
1. `ElevatorCallButton.CallElevatorPrompt` activates **only** when `DoorUnjammed == true` **and** `ElevatorPower == true`.
2. Calling the elevator sets `ElevatorCalled = true`, plays a **3.0-second audio + red-strobe lighting warning** (`ElevatorWarning`), emits `ElevatorCall` noise (`50` studs), and spawns **one `DislocatedCrawler`** from `ServerStorage.TheLastFloor.Enemies.Crawler` with a `2.2s` cinematic reveal (`CrawlerEncounterTriggered`).
3. The Crawler hunts using **`PathfindingService`** and **server-verified `NoiseEmitted` events** (reacting to sprint noise around pillars/vehicles).
4. Recessed `ElevatorCabin` doors slide open and interior `CabinGateSwitch.GateSwitchPrompt` glows green.
5. Pulling `CabinGateSwitch`:
   - Server checks all active (non-spectator) player coordinates (`ElevatorService.GetBoardingStatus`).
   - If all active players are inside the cabin: seals immediately.
   - If any active teammate is outside (standing or downed): triggers a **5-second audible & HUD closure warning** listing teammates outside (`CLOSING IN Xs — BOARD NOW!`) before heavy mechanical door slam (`LockHeavy`).
6. Plays **Ascending Sequence** (`3.5s` motor rumble + screen shake + transition curtain), sets `CurrentFloorIndex = 1`, and fires `FloorStateChanged` for Floor 1 readiness.

