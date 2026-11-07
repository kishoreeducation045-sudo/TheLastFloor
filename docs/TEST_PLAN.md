# THE LAST FLOOR – VACCINE PROTOCOL: TEST & QA PLAN

## 1. Testing Scope & Methodology
To guarantee publication-grade stability, testing is conducted across:
- **Solo Execution (1 Player)**
- **Small Team (2 Players)**
- **Full Squad (6 Players)**

## 2. Test Cases by Core Phase

### Phase 0: Architecture & Environment
- [ ] Rojo sync establishes cleanly with Roblox Studio.
- [ ] Directory layout matches proposed specification without missing directories or circular dependencies.
- [ ] Central configurations (`GameConfig.luau`) compile without runtime syntax warnings.

### Phase 1: Main Menu & Multiplayer Lobby
- [ ] Play, How To Play, Settings, Credits buttons route correctly.
- [ ] 1 to 6 player lobby slots dynamically populate with avatar thumbnails and usernames.
- [ ] Solo start bypasses countdown cleanly when initiated.
- [ ] Host migration / departure handled gracefully without orphaned states.

### Phase 2: Opening Crash Cinematic
- [ ] Truck driving sequence replicates across all 6 players in sync.
- [ ] Crash impact triggers screen shake, sound cue, glass debris, and transition to B1.
- [ ] Skip button functions upon majority vote or solo press.
- [ ] Players spawn inside B1 with correct initial orientation facing wreckage.

### Phase 3: Basement B1 & Puzzle
- [ ] 4 pillar symbols generate randomized associations each round.
- [ ] Maintenance room clue chart displays readable mapping.
- [ ] Keypad UI allows numeric entry and triggers error alarm on invalid PIN.
- [ ] Timer initiates at 2:00 (120s); reaching 0:00 triggers gas failure event.
- [ ] Correct PIN unlocks elevator doors and enables boarding.

### Phase 4: Player Survival, Downed, Revive & Elimination
- [ ] Reaching 0 HP enters Downed crawl state (30s countdown).
- [ ] Teammate holding interaction for 5.0s revives player to 35 HP.
- [ ] Taking damage interrupts revive attempt.
- [ ] First bleedout death grants free return at elevator checkpoint.
- [ ] Second bleedout death switches player to Spectator camera mode.

### Phase 5: Elevator & Floor Progression
- [ ] Elevator doors open and close via TweenService without clipping or physics glitches.
- [ ] Elevator display updates floor status, timer, and warnings accurately.
- [ ] Players cannot board or leave while transit sequence is active.
- [ ] Checkpoints persist across transitions.

