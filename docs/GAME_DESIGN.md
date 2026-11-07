# THE LAST FLOOR – VACCINE PROTOCOL: GAME DESIGN DOCUMENT

## 1. Executive Summary & Identity
- **Title:** THE LAST FLOOR – VACCINE PROTOCOL
- **Platform / Engine:** Roblox Studio (Luau)
- **Genre:** Cooperative Survival Horror
- **Target Audience:** 13+ (Horror, tension, cooperative team survival)
- **Player Capacity:** 1–6 Players (Cooperative matchmaking or solo)
- **Visual Style:** Classic Roblox avatars juxtaposed against dark, cinematic, realistic horror environments with atmospheric volumetric fog, rain, dynamic lighting, and spatial audio.

---

## 2. Narrative & Setting
A lethal viral pathogen has collapsed the metropolitan city. An emergency hazardous-materials response team travels in a heavy reinforced rescue vehicle carrying intelligence regarding an experimental prototype vaccine housed in an executive research laboratory on the 10th floor of an infected high-rise residential complex.

Upon breaching the apartment's underground basement (B1), the truck loses control and collides violently into a structural concrete pillar. The survivors emerge amidst wreckage, severed power cables, and leaking fuel to discover the main elevator shaft locked down under emergency protocol.

To survive and contain the contagion, the team must ascend the tower floor-by-floor via the elevator—the only structural route surviving—unravelling floor-specific puzzles, evading infected mutations, confronting supernatural anomalies, and securing the vaccine on Floor 10.

---

## 3. Core Mechanics & Systems

### 3.1 Elevator Progression Loop
- The elevator cabin serves as the central progression anchor and transient safe sanctuary.
- Transitioning between levels is exclusively facilitated via the elevator; all emergency stairwells are sealed, collapsed, or locked behind environmental hazards.
- Unlocking the elevator on each floor requires completing that floor's designated puzzle objective (e.g., restoring electrical breakers, finding keycards, decoding CCTV records, adjusting temperature valves).
- Once the objective is satisfied, the elevator doors unlock, allowing surviving players to board, initiate the transit sequence, and advance.

### 3.2 Server-Authoritative Timer Architecture
- Every floor imposes a strict countdown timer managed directly by the server.
- **Base Duration:** Basement B1 grants **2 minutes (120 seconds)**.
- **Progression Scaling:** Each subsequent floor adds **1 minute 12 seconds (+72 seconds)**.

| Floor | Code | Timer | Encounter Theme | Primary Objective |
|---|---|---|---|---|
| Basement B1 | B1 | 2:00 | Truck Crash / Initial Breach | Match pillar symbols to chart & enter keypad code |
| Floor 1 | F1 | 3:12 | The Infected Residents | Collect fuses & decrypt CCTV code for elevator power |
| Floor 2 | F2 | 4:24 | The Cold Clinic | Calibrate 3 cryogenic temperature valves from patient charts |
| Floor 3 | F3 | 5:36 | Power Control Grid | Sequence high-voltage breakers through cable corridors |
| Floor 4 | F4 | 6:48 | The Infected Ward | Locate and cross-reference 3 patient wristbands |
| Floor 5 | F5 | 8:00 | Research Laboratory Alpha | Synthesize DNA base-pair sequences across terminals |
| Floor 6 | F6 | 9:12 | The Haunted Wing | Activate 4 spirit seals in paranormal alignment order |
| Floor 7 | F7 | 10:24 | The Maintenance Maze | Regulate steam pressure release valves |
| Floor 8 | F8 | 11:36 | Isolation Block | Retrieve 4 biological security keys under lockdown |
| Floor 9 | F9 | 12:48 | The Final Guardian (Boss) | Overcharge 3 cooling cores while evading The Abomination |
| Floor 10 | F10 | 14:00 | The Vaccine Chamber (Origin) | Secure keys, calibrate vaccine, survive The Origin & extract |

- **Timer Expiration Penalty:** Server triggers a catastrophic floor failure event (toxic gas inundation, structural ceiling collapse, or an aggressive horde breach) eliminating stranded players.

---

### 3.3 Health, Downed State, and Revives
- **Base Player Health:** 100 HP.
- **Downed State:** Triggered when health reaches 0.
  - Duration: 30-second bleedout countdown.
  - Movement: Restricted crawl speed (3 studs/sec), jumping and weapon usage disabled.
  - Bleedout timer indicator visible to all squadmates.
- **Revival Mechanic:**
  - Requires a standing teammate to hold interaction for **5.0 continuous seconds**.
  - Interrupted if the reviver takes damage or moves outside interaction radius (8 studs).
  - Revived player receives **35 HP** and resumes standard mobility.
- **Lives & Elimination:**
  - Each player receives **one free return per round** upon initial elimination.
  - Return Spawn Point: Last completed floor elevator checkpoint.
  - A teammate reviving a downed player does *not* consume the player's free return.
  - Second elimination triggers permanent elimination for that match, immediately shifting the player into **Spectator Mode**.

### 3.4 Stealth, Movement & Sound Propagation
- **Movement Modes:**
  - Sprint: 19 studs/sec (generates loud footsteps audible within 35 studs).
  - Walk: 12 studs/sec (standard movement audible within 14 studs).
  - Crouch: 6 studs/sec (silent movement audible within 2 studs, lowers hit box).
- **Hiding Mechanisms:** Closets, hospital beds, under desks, and storage lockers provide full line-of-sight concealment from zombie vision cones.
- **Sound Emission System:** Firing unsuppressed firearms (80 studs radius), slamming doors (40 studs radius), or sprinting attracts nearby infected and alerts acoustic stalkers (Blind Hunter).

---

## 4. Enemy & Entity Taxonomy

### 4.1 Regular Infected (8 Archetypes)
1. **Resident:** Slow, shuffling infected that ambushes players around blind corners.
2. **Screecher:** Non-combat alert specialist; detects player proximity, issues a disorienting shriek, and summons nearby infected.
3. **Crawler:** Low-profile mutant traversing beneath furniture, striking player legs with crippling slashes.
4. **Runner:** High-velocity stalker with rapid acceleration and leaping strikes.
5. **Blind Hunter:** Completely devoid of vision; tracks players exclusively via emitted noise vectors.
6. **Brute:** Massive juggernaut capable of battering down wooden doors and delivering lethal wide swings.
7. **Exploder:** Distended, volatile specimen that rushes into player clusters and detonates into corrosive bile.
8. **Mutant:** Agile evolved apex infected capable of wall-climbing and alternating between ranged spit and leaping claws.

### 4.2 Supernatural Entities (2 Anomalies)
9. **Phantom:** Spectral apparition that dematerializes, flickers room lighting, creates illusory footsteps, and manifests behind isolated players.
10. **Wraith:** Ethereal ghost capable of phasing through solid partitions, causing severe temperature drops (visual frost), and dragging victims away from teammates.

### 4.3 Boss Encounters
- **Floor 9 Boss — The Abomination:** A towering amalgamation of infected biomass requiring environmental puzzle sabotage (cooling cores) to weaken and stun.
- **Floor 10 Boss — The Origin:** The patient-zero parasitic entity guarding the vaccine cryogenic vault; features multiple phases, toxic spore bursts, and tendril sweeps.

---

## 5. Armament & Inventory
- Dedicated inventory slots:
  - Slot 1: Primary / Secondary Weapon (Metal Pipe, 9mm Pistol, Pump Shotgun, or Flare Gun).
  - Slot 2: Puzzle Key / Quest Item.
  - Slot 3: Medical Syringe / Bandage (restores 40 HP).
- Independent Equipment: Heavy Duty Flashlight (Toggled via 'F', drains battery if not managed).
- Strict ammunition scarcity: Ammo boxes must be searched from drawers, lockers, and toolboxes.

