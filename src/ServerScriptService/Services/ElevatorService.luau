--!strict
-- ElevatorService for THE LAST FLOOR – VACCINE PROTOCOL
-- Manages the recessed cargo elevator doors, interior gate switch, server-side boarding validation, and ascending transitions.

local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes    = ReplicatedStorage.TheLastFloor.Remotes

local ElevatorService = {}
ElevatorService.IsLocked = true
ElevatorService.IsOpen = false
ElevatorService.CurrentFloorIndex = 0

local cabin: Model? = nil
local floorPart: BasePart? = nil
local doorLeft: BasePart? = nil
local doorRight: BasePart? = nil
local gateSwitch: BasePart? = nil
local gateSwitchFace: BasePart? = nil
local interiorLight: PointLight? = nil

local closedPosLeft: Vector3? = nil
local closedPosRight: Vector3? = nil
local openPosLeft: Vector3? = nil
local openPosRight: Vector3? = nil

local openTweenInfo  = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local heavyCloseInfo = TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function playDoorSound(hostPart: BasePart?, soundId: string, pitch: number, volume: number)
    if not hostPart then return end
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.PlaybackSpeed = pitch
    s.Volume = volume
    s.RollOffMaxDistance = 65
    s.Parent = hostPart
    s:Play()
    game:GetService("Debris"):AddItem(s, 3)
end

function ElevatorService.BindCabin(cabinModel: Model)
    cabin = cabinModel
    floorPart = cabinModel:WaitForChild("Floor") :: BasePart
    doorLeft = cabinModel:WaitForChild("DoorLeft") :: BasePart
    doorRight = cabinModel:WaitForChild("DoorRight") :: BasePart
    gateSwitch = cabinModel:FindFirstChild("CabinGateSwitch") :: BasePart?
    gateSwitchFace = cabinModel:FindFirstChild("GateSwitchFace") :: BasePart?

    local ceiling = cabinModel:FindFirstChild("Ceiling")
    interiorLight = ceiling and ceiling:FindFirstChild("CabinInteriorLight") :: PointLight? or nil

    closedPosLeft = doorLeft.Position
    closedPosRight = doorRight.Position
    openPosLeft = closedPosLeft - Vector3.new(3.5, 0, 0)
    openPosRight = closedPosRight + Vector3.new(3.5, 0, 0)

    ElevatorService.IsLocked = true
    ElevatorService.IsOpen = false
    ElevatorService.SetGateSwitchEnabled(false, false)
end

function ElevatorService.GetCabin(): Model?
    return cabin
end

function ElevatorService.GetGateSwitch(): BasePart?
    return gateSwitch
end

function ElevatorService.SetGateSwitchEnabled(enabled: boolean, warningMode: boolean?)
    if gateSwitch then
        local pp = gateSwitch:FindFirstChild("GateSwitchPrompt") :: ProximityPrompt?
        if pp then
            pp.Enabled = enabled
        end
    end
    if gateSwitchFace then
        if not enabled then
            gateSwitchFace.Color = Color3.fromRGB(160, 40, 40)
        elseif warningMode then
            gateSwitchFace.Color = Color3.fromRGB(255, 175, 25)
        else
            gateSwitchFace.Color = Color3.fromRGB(50, 255, 95)
        end
    end
end

function ElevatorService.SetDoors(open: boolean, heavy: boolean?)
    if not doorLeft or not doorRight or not openPosLeft or not closedPosLeft or not openPosRight or not closedPosRight then return end
    ElevatorService.IsOpen = open
    local targetL = open and openPosLeft or closedPosLeft
    local targetR = open and openPosRight or closedPosRight
    local info = (not open and heavy) and heavyCloseInfo or openTweenInfo

    doorLeft.CanCollide = true
    doorRight.CanCollide = true

    if open then
        playDoorSound(floorPart, "rbxassetid://138090596", 0.65, 0.75)
    elseif heavy then
        playDoorSound(floorPart, "rbxassetid://138090596", 0.35, 0.85)
    end

    local t1 = TweenService:Create(doorLeft, info, { Position = targetL })
    local t2 = TweenService:Create(doorRight, info, { Position = targetR })
    t1:Play()
    t2:Play()
    t1.Completed:Wait()

    if not open and heavy then
        playDoorSound(floorPart, "rbxassetid://138090596", 0.55, 0.9)
    end
end

function ElevatorService.Unlock()
    ElevatorService.IsLocked = false
    if interiorLight then
        interiorLight.Color = Color3.fromRGB(255, 200, 130)
        interiorLight.Brightness = 1.2
    end
    ElevatorService.SetGateSwitchEnabled(true, false)
    ElevatorService.UpdateScreen("CARRIAGE READY", "BOARD & PULL GATE SWITCH [E]")
    print("[ElevatorService] Elevator unlocked! Sliding doors open...")
    ElevatorService.SetDoors(true, false)
end

function ElevatorService.LockHeavy()
    ElevatorService.IsLocked = true
    ElevatorService.SetGateSwitchEnabled(false, false)
    ElevatorService.SetDoors(false, true)
end

function ElevatorService.IsPlayerInsideCabin(player: Player): boolean
    if not floorPart then return false end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end

    local rel = floorPart.CFrame:PointToObjectSpace(hrp.Position)
    -- Cabin floor is 16x16; doorway threshold at -Z = -8.0. Allow inside -7.2 .. +7.5 in Z
    return math.abs(rel.X) <= 7.2 and rel.Z >= -7.2 and rel.Z <= 7.6 and rel.Y >= -1.0 and rel.Y <= 11.5
end

function ElevatorService.GetBoardingStatus(activePlayers: { Player }): { allInside: boolean, inside: { Player }, outside: { Player } }
    local inside: { Player } = {}
    local outside: { Player } = {}
    for _, p in ipairs(activePlayers) do
        if ElevatorService.IsPlayerInsideCabin(p) then
            table.insert(inside, p)
        else
            table.insert(outside, p)
        end
    end
    return {
        allInside = (#outside == 0),
        inside = inside,
        outside = outside,
    }
end

function ElevatorService.RunAscendingSequence()
    if interiorLight then
        interiorLight.Color = Color3.fromRGB(200, 225, 255)
        interiorLight.Brightness = 1.4
    end

    ElevatorService.UpdateScreen("GATE SEALED", "ASCENDING TO FLOOR 1...")

    local ascendRemote = remotes:FindFirstChild("ElevatorAscending") :: RemoteEvent?
    local duration = GameConfig.ElevatorAscendDuration or 3.5
    if ascendRemote then
        ascendRemote:FireAllClients(duration, "ASCENDING TO FLOOR 1: THE INFECTED RESIDENTS")
    end

    local motorSound: Sound? = nil
    if floorPart then
        motorSound = Instance.new("Sound")
        motorSound.SoundId = "rbxassetid://138090596"
        motorSound.PlaybackSpeed = 0.45
        motorSound.Volume = 0.8
        motorSound.Looped = true
        motorSound.Parent = floorPart
        motorSound:Play()
    end

    task.wait(duration)

    if motorSound then
        motorSound:Stop()
        motorSound:Destroy()
    end

    ElevatorService.CurrentFloorIndex = 1
    ElevatorService.UpdateScreen("FLOOR 1: LOBBY & RESIDENTIAL", "B1 COMPLETE — READY FOR FLOOR 1")
end

function ElevatorService.UpdateScreen(title: string, status: string)
    if not cabin then return end
    local screen = cabin:FindFirstChild("ElevatorScreen")
    if screen and screen:FindFirstChild("SurfaceGui") then
        local sg = screen.SurfaceGui :: SurfaceGui
        local frame = sg:FindFirstChild("Frame") :: Frame?
        if frame then
            local tl = frame:FindFirstChild("TitleLabel") :: TextLabel?
            local sl = frame:FindFirstChild("StatusLabel") :: TextLabel?
            if tl then tl.Text = title end
            if sl then sl.Text = status end
        end
    end
end

return ElevatorService
