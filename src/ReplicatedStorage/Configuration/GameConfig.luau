--!strict
-- Central Game Configuration for THE LAST FLOOR – VACCINE PROTOCOL

export type FloorDefinition = {
    Id: number,
    Name: string,
    FloorCode: string,
    DurationSeconds: number,
    Description: string,
    IsBossFloor: boolean,
    IsFinalFloor: boolean,
}

local GameConfig = {}

-- Player Session Parameters
GameConfig.MinPlayers = 1
GameConfig.MaxPlayers = 6

-- Survival & Revive Tuning
GameConfig.MaxHealth = 100
GameConfig.RevivedHealth = 35
GameConfig.DownedDuration = 30 -- Bleedout countdown
GameConfig.ReviveDuration = 5.0 -- Hold duration to revive
GameConfig.MaxEliminationsBeforeSpectator = 2 -- 1 free return, 2nd death = spectator

-- Acoustic Detection Radii (in Studs)
GameConfig.NoiseRadii = {
    Sprint = 35,
    Walk = 14,
    Crouch = 2, -- Near silent
    Gunshot = 80,
    DoorSlam = 40,
    ItemDrop = 20,
}

-- Movement Speeds
GameConfig.WalkSpeed = 12
GameConfig.SprintSpeed = 19
GameConfig.CrouchSpeed = 6
GameConfig.DownedSpeed = 3

-- Floor Duration Formula:
-- B1 = 120s (2m 00s)
-- Each subsequent floor adds 72s (+1m 12s)
local function calculateFloorDuration(floorIndex: number): number
    return 120 + (floorIndex * 72)
end

GameConfig.Floors = {
    {
        Id = 0,
        Name = "Basement B1: Boiler & Parking",
        FloorCode = "B1",
        DurationSeconds = calculateFloorDuration(0), -- 120s (2:00)
        Description = "Solve the 4-symbol maintenance puzzle to restore elevator power.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 1,
        Name = "Floor 1: Lobby & Residential",
        FloorCode = "F1",
        DurationSeconds = calculateFloorDuration(1), -- 192s (3:12)
        Description = "Collect 3 fuses and decrypt the CCTV security pin.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 2,
        Name = "Floor 2: The Cold Clinic",
        FloorCode = "F2",
        DurationSeconds = calculateFloorDuration(2), -- 264s (4:24)
        Description = "Calibrate cryogenic valves from patient charts; beware Exploders.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 3,
        Name = "Floor 3: Power Control Grid",
        FloorCode = "F3",
        DurationSeconds = calculateFloorDuration(3), -- 336s (5:36)
        Description = "Sequence high-voltage breakers; beware Crawlers beneath machinery.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 4,
        Name = "Floor 4: The Infected Ward",
        FloorCode = "F4",
        DurationSeconds = calculateFloorDuration(4), -- 408s (6:48)
        Description = "Locate 3 patient wristbands; move silently to avoid the Blind Hunter.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 5,
        Name = "Floor 5: Research Lab Alpha",
        FloorCode = "F5",
        DurationSeconds = calculateFloorDuration(5), -- 480s (8:00)
        Description = "Reconstruct the DNA codon sequence on research terminals.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 6,
        Name = "Floor 6: The Haunted Wing",
        FloorCode = "F6",
        DurationSeconds = calculateFloorDuration(6), -- 552s (9:12)
        Description = "Align 4 spirit seals in order while warding off the Phantom.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 7,
        Name = "Floor 7: The Maintenance Maze",
        FloorCode = "F7",
        DurationSeconds = calculateFloorDuration(7), -- 624s (10:24)
        Description = "Balance 4 steam pressure valves while evading the Brute.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 8,
        Name = "Floor 8: The Isolation Block",
        FloorCode = "F8",
        DurationSeconds = calculateFloorDuration(8), -- 696s (11:36)
        Description = "Retrieve 4 security cards under bio-decontamination lockdown.",
        IsBossFloor = false,
        IsFinalFloor = false,
    },
    {
        Id = 9,
        Name = "Floor 9: The Final Guardian",
        FloorCode = "F9",
        DurationSeconds = calculateFloorDuration(9), -- 768s (12:48)
        Description = "Overcharge 3 cooling cores while kiting The Abomination & Wraith.",
        IsBossFloor = true,
        IsFinalFloor = false,
    },
    {
        Id = 10,
        Name = "Floor 10: The Vaccine Protocol",
        FloorCode = "F10",
        DurationSeconds = calculateFloorDuration(10), -- 840s (14:00)
        Description = "Secure the vaccine, survive The Origin, and signal extraction.",
        IsBossFloor = true,
        IsFinalFloor = true,
    },
}

return table.freeze(GameConfig)

