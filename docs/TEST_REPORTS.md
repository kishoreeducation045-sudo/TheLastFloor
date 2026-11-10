# THE LAST FLOOR – VACCINE PROTOCOL: TEST REPORTS

**Date:** 2026-11-10  
**Environment:** Roblox Studio Live Play (`Place1.rbxl`) + `Rojo 7.7.1` Build Verification  

---

## 1. Summary of Executed Tests

| Test Case | Scope / Method | Result | Evidence / Notes |
|---|---|---|---|
| **Geometry Enclosure** | 2-stud `Basement_B1` interior/perimeter/corner raycasts + 1-stud `ElevatorCabin` raycasts in Studio Edit | **PASS** | `0` leaks detected after closing `GarageFloor` (`164x2x224`) and recessing/enclosing `ElevatorCabin` behind `Wall_North`. |
| **Rojo Build Check** | CLI: `rojo build TheLastFloor -o ...test_build.rbxlx` (`CrowbarTool/init.meta.json` added, `RoundManager` retired) | **PASS** | Exited with code `0` (`Built project to test_build.rbxlx`). |
| **Studio Output Audit** | Playtest Session 5 (`get_console_output`) after fixing `os` shadow & sound IDs | **PASS** | `0` Lua errors, `0` warnings, `0` failed sound loads across full B1 -> F1 run. |
| **Solo Full Completion (Order: 1 -> 2 -> 3)** | Live Studio Playtest (`InputHoldBegin` on Workbench `2.0s` -> `PryPrompt` `3s` -> `GeneratorFixed` -> `CallElevatorPrompt` -> `GateSwitchPrompt`) | **PASS** | `DoorUnjammed=true`, `ElevatorPower=true`, `ElevatorCalled=true`, heavy door close (`DoorLeft.X: -4.50 -> -1.00`), Floor 1 screen & HUD transition confirmed. |
| **Reverse Completion Order (Order: 2 -> 1 -> 3)** | Live Studio Playtest Session 1 | **PASS** | Solving Stage 2 first set `ElevatorPower=true` and Indicator Amber `"POWER RESTORED / REMOVE JAMMED BEAM"`, keeping `CallElevatorPrompt.Enabled = false` until Stage 1 completed. |
| **Incorrect Wire Connections** | Server spoof `{99, 99, 99}` in live Playtest + UI wrong-port error branch inspection | **PASS** | Server logged `[FloorManager] Rejected invalid/unauthenticated GeneratorFixed submission`, `ElevatorPower` stayed `false`; wrong-port UI branch performs red flash + panel shake + buzz. |
| **Wrong Crowbar Interaction** | Live Playtest `BeamPried:FireServer()` near `JammedBeam` without Crowbar | **PASS** | Server blocked pry (`DoorUnjammed=false`, `DebrisWeld` present) and HUD displayed `"CROWBAR REQUIRED — Hold [E] for 2s at the Workbench beside the lift!"`. |
| **WalkSpeed & Inventory Sync** | Live Playtest measurement before/during/after 3s pry | **PASS** | Mid-pry `WalkSpeed=0.0`, post-pry restored to `12.0` (`GameConfig.WalkSpeed`); Hotbar Slot 2 updated `"C:Crowbar"` on pickup and cleared `""` when consumed. |
| **Crawler Spawn & Pathfinding Attack** | Live Playtest Sessions 2 & 5 (`DislocatedCrawler` cloned from `ServerStorage`) | **PASS** | Does not spawn prematurely (`EarlyCrawler=false`); spawns after 3s warning at `(28, 2.2, 20)`, navigated to elevator doorway `(-1.9, 2.3, 103.5)`, attacked & downed stationary test character. |
| **Sprint Noise Detection** | Client `NoiseEmitted:FireServer("Sprint", pos)` connected to server listener in `FloorManager` | **PASS** | Event accepted & processed on server during Playtest 2/3 without errors. *(Full multi-client lure divergence inferred by inspection of `recordNoise` + `getNearestTargetPosition`).* |
| **Two-Player & Six-Player Lobby + Cabin Boarding** | Live Studio Server test (`LobbyService.JoinLobby` x6+1, `ElevatorService.GetBoardingStatus` with 2- and 6-rig proxies) | **PASS** | `Lobby7thRejected=true`; `2P_Split(in=1,out=1)`, `2P_All=true`, `6P_Split(in=5,out=1)`, `6P_All=true`. *(Live 5s HUD warning countdown during multi-client outside boarding verified by code inspection of `onGateSwitchPulled` loop + `GetBoardingStatus` check).* |
| **Downed State, First Free Return & 2nd Elimination** | Live Studio Playtest Session 2 (`Timer` expiration & Crawler bleedout #1 and #2) | **PASS** | Logged `downed-out #1 -> Free checkpoint return in 5.0s` followed by character respawn, and `eliminated #2 -> Permanent Spectator`. |
| **Floor 1 Transition** | Live Studio Playtest Session 5 (`CabinGateSwitch.GateSwitchPrompt`) | **PASS** | Logged `[FloorManager] Transitioned cleanly from Basement B1 -> Floor 1.`, `FloorHeader='F1 • FLOOR 1: LOBBY & RESIDENTIAL'`. |

