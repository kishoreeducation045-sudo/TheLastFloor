--!strict
-- FloorManager.luau
-- Authoritative Floor Timer + Basement B1 3-Stage Cooperative Lift Puzzle State Machine
--   Stage 1: Collect Heavy Crowbar (2s Hold E) & Pry Jammed Elevator Beam (E, 3s pry, DebrisWeld break)
--   Stage 2: East-Wall Backup Generator 3-Wire Bypass (Server-validated, sound + vibration + smoke + 20% dim glow)
--   Stage 3: Call Lift (Requires Stage 1+2) -> 3s Warning -> DislocatedCrawler Pathfinding/Noise Hunt -> Interior Gate Switch (5s teammate warning) -> Floor 1 Transition

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")
local Players            = game:GetService("Players")
local Workspace          = game:GetService("Workspace")
local TweenService       = game:GetService("TweenService")
local Lighting           = game:GetService("Lighting")
local PathfindingService = game:GetService("PathfindingService")
local Debris             = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes    = ReplicatedStorage.TheLastFloor.Remotes

local floorStateRemote       = remotes:WaitForChild("FloorStateChanged") :: RemoteEvent
local floorTimerRemote       = remotes:WaitForChild("FloorTimerUpdate") :: RemoteEvent
local puzzleStateRemote      = remotes:WaitForChild("PuzzleStateChanged") :: RemoteEvent
local noiseRemote            = remotes:WaitForChild("NoiseEmitted") :: RemoteEvent
local giveCrowbarRemote      = remotes:WaitForChild("GiveCrowbar") :: RemoteEvent
local beamPriedRemote        = remotes:WaitForChild("BeamPried") :: RemoteEvent
local crowbarPryStateRemote  = remotes:WaitForChild("CrowbarPryState") :: RemoteEvent
local inventorySyncRemote    = remotes:WaitForChild("InventorySync") :: RemoteEvent
local requestGenPuzzleRemote = remotes:WaitForChild("RequestGeneratorPuzzle") :: RemoteEvent
local openGenPuzzleRemote    = remotes:WaitForChild("OpenGeneratorPuzzle") :: RemoteEvent
local genFixedRemote         = remotes:WaitForChild("GeneratorFixed") :: RemoteEvent
local crawlerEncounterRemote = remotes:WaitForChild("CrawlerEncounterTriggered") :: RemoteEvent
local elevWarningRemote      = remotes:WaitForChild("ElevatorWarning") :: RemoteEvent

local FloorManager = {}
FloorManager.CurrentFloorIndex = 0
FloorManager.TimeRemaining     = 120
FloorManager.IsActive          = false

local elevatorServiceRef: any = nil
local healthManagerRef: any = nil

-- Authoritative Basement B1 Flags
local doorUnjammed = false
local generatorRestored = false
local elevatorCalled = false
local gateSequenceStarted = false
local floorCompleted = false
local isPryingBeam = false
local crawlerSpawned = false

local activeCrawler: Model? = nil
local timerThread: thread? = nil
local generatorVibrationRunning = false
local lightingFlickerRunning = false
local activeLampThreads: { thread } = {}

-- Server-side anti-cheat session tracking
local activePuzzleOrders: { [Player]: { number } } = {}
local lastHeardNoise: { position: Vector3, timestamp: number, radius: number }? = nil

local function getB1(): Folder?
    local tlf = Workspace:FindFirstChild("TheLastFloor")
    if not tlf then return nil end
    return tlf:FindFirstChild("Basement_B1") :: Folder?
end

local function playWorldSound(parent: Instance?, soundId: string, volume: number, speed: number?, looped: boolean?, maxDist: number?): Sound?
    if not parent then return nil end
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = volume
    s.PlaybackSpeed = speed or 1.0
    s.Looped = looped == true
    s.RollOffMaxDistance = maxDist or 55
    s.RollOffMinDistance = 5
    s.Parent = parent
    s:Play()
    if not s.Looped then
        Debris:AddItem(s, 4)
    end
    return s
end

local function setBoolState(name: string, value: boolean)
    local b1 = getB1()
    if not b1 then return end
    local bv = b1:FindFirstChild(name) :: BoolValue?
    if bv then
        bv.Value = value
    end
end

local function getDefaultHint(): string
    if not doorUnjammed and not generatorRestored then
        return "Grab the Crowbar at Workbench [Hold E 2s] or bypass East Generator [E]."
    elseif not doorUnjammed then
        return "Power online — Collect Crowbar at Workbench [Hold E 2s] & pry Elevator Beam [E]."
    elseif not generatorRestored then
        return "Beam cleared — Solve the East-Wall Backup Generator puzzle [E]."
    elseif not elevatorCalled then
        return "Systems ready! Press the Call Console [E] beside the North Elevator."
    elseif not gateSequenceStarted then
        return "SURVIVE & BOARD! Enter the North Elevator and hit the Gate Switch [E]!"
    else
        return "Lift sealing — hold inside the cabin!"
    end
end

local function broadcastObjectiveState(customHint: string?, alertMsg: string?, alertColor: Color3?)
    local data = GameConfig.Floors[FloorManager.CurrentFloorIndex + 1]
    local payload = {
        floorIndex = FloorManager.CurrentFloorIndex,
        floorCode  = data and data.FloorCode or "B1",
        floorName  = data and data.Name or "Basement B1: Boiler & Parking",
        obj1Done   = doorUnjammed,
        obj2Done   = generatorRestored,
        obj3Done   = elevatorCalled,
        obj4Done   = floorCompleted,
        hint       = customHint or getDefaultHint(),
        alert      = alertMsg,
        alertColor = alertColor,
    }
    puzzleStateRemote:FireAllClients(payload)
end

local function updateElevatorSignage()
    local b1 = getB1()
    if not b1 then return end

    local indicator = b1:FindFirstChild("ElevatorIndicator")
    local gui = indicator and indicator:FindFirstChild("ElevatorStatusGui")
    local lbl = gui and gui:FindFirstChild("StatusLabel") :: TextLabel?

    local callBtn = b1:FindFirstChild("ElevatorCallButton")
    local callPrompt = callBtn and callBtn:FindFirstChild("CallElevatorPrompt") :: ProximityPrompt?
    local callFace = b1:FindFirstChild("CallButtonFace") :: BasePart?

    local canCall = doorUnjammed and generatorRestored and not elevatorCalled

    if callPrompt then
        callPrompt.Enabled = canCall
    end

    if callFace then
        if canCall then
            callFace.BrickColor = BrickColor.new("Bright green")
        elseif generatorRestored then
            callFace.BrickColor = BrickColor.new("Deep orange")
        else
            callFace.BrickColor = BrickColor.new("Crimson")
        end
    end

    if lbl then
        if elevatorCalled then
            lbl.Text = "LIFT DISPATCHED\nSTAND CLEAR"
            lbl.TextColor3 = Color3.fromRGB(80, 255, 110)
            lbl.BackgroundColor3 = Color3.fromRGB(0, 25, 8)
        elseif canCall then
            lbl.Text = "POWER RESTORED\nCALL ELEVATOR [E]"
            lbl.TextColor3 = Color3.fromRGB(255, 185, 25)
            lbl.BackgroundColor3 = Color3.fromRGB(24, 16, 0)
        elseif generatorRestored and not doorUnjammed then
            lbl.Text = "POWER RESTORED\nREMOVE JAMMED BEAM"
            lbl.TextColor3 = Color3.fromRGB(255, 185, 25)
            lbl.BackgroundColor3 = Color3.fromRGB(24, 16, 0)
        elseif not generatorRestored and doorUnjammed then
            lbl.Text = "TRACK CLEARED\nBYPASS GENERATOR"
            lbl.TextColor3 = Color3.fromRGB(255, 90, 90)
            lbl.BackgroundColor3 = Color3.fromRGB(24, 6, 6)
        else
            lbl.Text = "GENERATOR FAULT\nMANUAL BYPASS REQUIRED"
            lbl.TextColor3 = Color3.fromRGB(255, 65, 65)
            lbl.BackgroundColor3 = Color3.fromRGB(24, 6, 6)
        end
    end
end

local function isPlayerAliveNonDowned(player: Player): boolean
    if healthManagerRef then
        if healthManagerRef.IsSpectator(player) or healthManagerRef.IsDowned(player) then
            return false
        end
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function getActiveNonSpectatorPlayers(): { Player }
    local list: { Player } = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if not healthManagerRef or healthManagerRef.IsActivePlayer(p) then
            table.insert(list, p)
        end
    end
    return list
end

local function recordNoise(pos: Vector3, radius: number)
    lastHeardNoise = {
        position = pos,
        timestamp = os.clock(),
        radius = radius,
    }
end

------------------------------------------------------------------------
-- STAGE 1: CROWBAR PICKUP & JAMMED BEAM PRY
------------------------------------------------------------------------
local function ensureCrowbarAvailability()
    if doorUnjammed then return end
    local someoneHasCrowbar = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("HasCrowbar") == true and (not healthManagerRef or not healthManagerRef.IsSpectator(p)) then
            someoneHasCrowbar = true
            break
        end
    end
    if not someoneHasCrowbar then
        local b1 = getB1()
        local pickup = b1 and b1:FindFirstChild("CrowbarPickup") :: BasePart?
        local pp = pickup and pickup:FindFirstChild("CrowbarPrompt") :: ProximityPrompt?
        if pickup and pp then
            pickup.Transparency = 0
            pp.Enabled = true
        end
    end
end

local function grantCrowbarToPlayer(player: Player)
    if doorUnjammed then return end
    if healthManagerRef and (healthManagerRef.IsDowned(player) or healthManagerRef.IsSpectator(player)) then return end

    local b1 = getB1()
    local pickup = b1 and b1:FindFirstChild("CrowbarPickup") :: BasePart?
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not pickup or not hrp then return end

    if (hrp.Position - pickup.Position).Magnitude > 14 then
        return
    end

    if player:GetAttribute("HasCrowbar") == true then return end
    player:SetAttribute("HasCrowbar", true)

    -- Server-side authoritative tool clone so all squad members see Crowbar in hand!
    local tlf = ReplicatedStorage:FindFirstChild("TheLastFloor")
    local toolTemplate = tlf and tlf:FindFirstChild("CrowbarTool")
    local backpack = player:FindFirstChild("Backpack")
    if toolTemplate and backpack and not backpack:FindFirstChild("CrowbarTool") and not (char and char:FindFirstChild("CrowbarTool")) then
        local clone = toolTemplate:Clone()
        clone.Parent = backpack
    end

    pickup.Transparency = 1
    local pp = pickup:FindFirstChild("CrowbarPrompt") :: ProximityPrompt?
    if pp then pp.Enabled = false end

    playWorldSound(pickup, "rbxassetid://6895079853", 0.7, 0.85, false, 30)
    giveCrowbarRemote:FireClient(player, "Add", "Crowbar")
    inventorySyncRemote:FireClient(player, "Add", "Crowbar")
    broadcastObjectiveState(nil, string.format("%s collected the Heavy Crowbar!", player.DisplayName), Color3.fromRGB(230, 210, 120))
    print(string.format("[FloorManager] %s picked up Crowbar (2s hold validated).", player.Name))
end

local function tryStartBeamPry(player: Player)
    if doorUnjammed or isPryingBeam or not FloorManager.IsActive then return end
    if healthManagerRef and (healthManagerRef.IsDowned(player) or healthManagerRef.IsSpectator(player)) then return end

    local b1 = getB1()
    local beam = b1 and b1:FindFirstChild("JammedBeam") :: BasePart?
    if not beam then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    if (hrp.Position - beam.Position).Magnitude > 14 then
        return
    end

    -- Strict server-side Crowbar validation
    local hasAttr = (player:GetAttribute("HasCrowbar") == true)
    local toolInChar = char and char:FindFirstChild("CrowbarTool") :: Tool?
    local backpack = player:FindFirstChild("Backpack")
    local toolInBag = backpack and backpack:FindFirstChild("CrowbarTool") :: Tool?
    local crowbarTool = toolInChar or toolInBag

    if not hasAttr or not crowbarTool then
        playWorldSound(beam, "rbxassetid://9069609200", 0.65, 1.0, false, 25)
        crowbarPryStateRemote:FireClient(player, "MissingCrowbar", 0)
        return
    end

    -- Begin 3-second authoritative pry sequence
    isPryingBeam = true
    local pryPrompt = beam:FindFirstChild("PryPrompt") :: ProximityPrompt?
    if pryPrompt then pryPrompt.Enabled = false end

    if toolInBag then
        hum:EquipTool(toolInBag)
    end

    char:SetAttribute("IsPrying", true)
    hum.WalkSpeed = 0

    local pryDur = GameConfig.BeamPryDuration or 3.0
    crowbarPryStateRemote:FireClient(player, "StartPry", pryDur)
    broadcastObjectiveState("Prying jammed steel beam off the elevator track...", nil)

    local strainSound = playWorldSound(beam, "rbxassetid://138090596", 0.65, 0.55, true, 45)
    recordNoise(beam.Position, GameConfig.NoiseRadii.CrowbarPry or 45)

    task.delay(pryDur, function()
        if strainSound then
            strainSound:Stop()
            strainSound:Destroy()
        end

        -- Restore player movement cleanly using GameConfig.WalkSpeed (never hardcoded 16!)
        if char and char.Parent then
            char:SetAttribute("IsPrying", nil)
        end
        if hum and hum.Parent and (not healthManagerRef or not healthManagerRef.IsDowned(player)) then
            hum.WalkSpeed = GameConfig.WalkSpeed
        end

        if beam and beam.Parent then
            -- Break physical DebrisWeld on the server
            for _, child in ipairs(beam:GetChildren()) do
                if child:IsA("WeldConstraint") then
                    child:Destroy()
                end
            end

            -- Sparks + Heavy metallic impact drop
            local sparks = Instance.new("ParticleEmitter")
            sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60))
            sparks.Size = NumberSequence.new(0.35, 0)
            sparks.Lifetime = NumberRange.new(0.25, 0.5)
            sparks.Speed = NumberRange.new(10, 20)
            sparks.Rate = 80
            sparks.Parent = beam
            task.delay(0.4, function()
                sparks.Rate = 0
                Debris:AddItem(sparks, 1)
            end)

            beam.Anchored = false
            beam.CanCollide = true
            beam.AssemblyLinearVelocity = Vector3.new(2.5, -3.5, -11.0)
            beam.AssemblyAngularVelocity = Vector3.new(1.5, 0.4, 2.2)

            playWorldSound(beam, "rbxassetid://138090596", 0.9, 0.65, false, 55)

            -- Anchor safely once settled on concrete floor so it doesn't clutter physics forever
            task.delay(2.5, function()
                if beam and beam.Parent then
                    beam.Anchored = true
                end
            end)
        end

        -- Consume crowbar cleanly across server + client hotbar
        player:SetAttribute("HasCrowbar", nil)
        local tNow = (char and char:FindFirstChild("CrowbarTool")) or (backpack and backpack:FindFirstChild("CrowbarTool"))
        if tNow then tNow:Destroy() end
        inventorySyncRemote:FireClient(player, "Remove", "Crowbar")

        doorUnjammed = true
        setBoolState("DoorUnjammed", true)
        isPryingBeam = false

        updateElevatorSignage()
        broadcastObjectiveState(nil, "OBJECTIVE 1 COMPLETE — Jammed elevator beam removed!", Color3.fromRGB(80, 255, 120))
        print("[FloorManager] Stage 1 complete: DebrisWeld broken & beam dropped.")
    end)
end

------------------------------------------------------------------------
-- STAGE 2: GENERATOR BYPASS (ANY ORDER WITH STAGE 1, BOTH MANDATORY)
------------------------------------------------------------------------
local function generateShuffledOrder(): { number }
    local order = { 1, 2, 3 }
    repeat
        for i = #order, 2, -1 do
            local j = math.random(1, i)
            order[i], order[j] = order[j], order[i]
        end
    until order[1] ~= 1 or order[2] ~= 2
    return order
end

local function handleOpenGeneratorRequest(player: Player)
    if generatorRestored or not FloorManager.IsActive then return end
    if healthManagerRef and (healthManagerRef.IsDowned(player) or healthManagerRef.IsSpectator(player)) then return end

    local b1 = getB1()
    local genPanel = b1 and (b1:FindFirstChild("GeneratorPanel") :: BasePart? or b1:FindFirstChild("Generator") :: BasePart?)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not genPanel or not hrp then return end

    if (hrp.Position - genPanel.Position).Magnitude > 25 then return end

    local order = activePuzzleOrders[player]
    if not order then
        order = generateShuffledOrder()
        activePuzzleOrders[player] = order
    end
    openGenPuzzleRemote:FireClient(player, order)
end

local function cancelLightingFlicker()
    lightingFlickerRunning = false
    for _, th in ipairs(activeLampThreads) do
        task.cancel(th)
    end
    table.clear(activeLampThreads)
end

-- ATMOSPHERE MODE (Easily switch between DAYLIGHT and DARK HORROR)
local USE_DAYLIGHT_ATMOSPHERE = true -- Set to false later to return to dark horror atmosphere

local function applyAtmosphereLighting(isGeneratorPowered: boolean)
    local l = Lighting
    if USE_DAYLIGHT_ATMOSPHERE then
        l.ClockTime = 14.0
        l.Brightness = 2.5
        l.Ambient = Color3.fromRGB(150, 150, 150)
        l.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
        l.FogColor = Color3.fromRGB(200, 220, 240)
        l.FogStart = 500
        l.FogEnd = 100000
        l.GlobalShadows = true

        local hcg = l:FindFirstChild("HorrorColorGrade") :: ColorCorrectionEffect?
        if hcg then
            hcg.Enabled = false
            hcg.Contrast = 0.05
            hcg.Saturation = 0.05
            hcg.TintColor = Color3.fromRGB(255, 255, 255)
            hcg.Brightness = 0
        end

        local bloom = l:FindFirstChild("Bloom") :: BloomEffect?
        if bloom then
            bloom.Enabled = true
            bloom.Intensity = 0.35
            bloom.Size = 24
            bloom.Threshold = 1.1
        end

        local atmo = l:FindFirstChild("Atmosphere") :: Atmosphere?
        if atmo then
            atmo.Density = 0.2
            atmo.Haze = 0
            atmo.Color = Color3.fromRGB(199, 175, 166)
            atmo.Decay = Color3.fromRGB(104, 112, 125)
            atmo.Glare = 0
        end
    else
        l.ClockTime = 0.0
        l.Brightness = 0.12
        l.Ambient = Color3.fromRGB(6, 8, 10)
        l.OutdoorAmbient = Color3.fromRGB(2, 3, 4)
        l.FogColor = Color3.fromRGB(4, 6, 8)
        l.FogStart = 8
        l.FogEnd = isGeneratorPowered and 85 or 65
        l.GlobalShadows = true

        local hcg = l:FindFirstChild("HorrorColorGrade") :: ColorCorrectionEffect?
        if hcg then
            hcg.Enabled = true
            hcg.Contrast = 0.32
            hcg.Saturation = -0.38
            hcg.TintColor = Color3.fromRGB(195, 205, 205)
            hcg.Brightness = 0
        end

        local bloom = l:FindFirstChild("Bloom") :: BloomEffect?
        if bloom then
            bloom.Enabled = true
            bloom.Intensity = 0.85
            bloom.Size = 36
            bloom.Threshold = 0.95
        end

        local atmo = l:FindFirstChild("Atmosphere") :: Atmosphere?
        if atmo then
            atmo.Density = 0.42
            atmo.Haze = 3.2
            atmo.Color = Color3.fromRGB(12, 16, 18)
            atmo.Decay = Color3.fromRGB(3, 4, 5)
        end
    end
end

local function activateEmergencyLightsAndGenerator()
    local b1 = getB1()
    if not b1 then return end

    -- 1. Generator Engine Sound & Physical Vibration
    local genPart = b1:FindFirstChild("Generator") :: BasePart?
    local genTop = b1:FindFirstChild("Generator_Top") :: BasePart?
    local engineSound: Sound? = nil
    if genPart then
        engineSound = genPart:FindFirstChild("EngineLoop") :: Sound?
        if not engineSound then
            engineSound = Instance.new("Sound")
            engineSound.Name = "EngineLoop"
            engineSound.SoundId = "rbxassetid://138090596"
            engineSound.PlaybackSpeed = 0.35
            engineSound.Looped = true
            engineSound.Volume = 0.75
            engineSound.RollOffMaxDistance = 65
            engineSound.RollOffMinDistance = 6
            engineSound.Parent = genPart
        end
        engineSound:Play()

        if not generatorVibrationRunning then
            generatorVibrationRunning = true
            local baseMain = genPart.CFrame
            local baseTop = genTop and genTop.CFrame or nil
            task.spawn(function()
                while generatorRestored and generatorVibrationRunning and genPart and genPart.Parent do
                    local jx = (math.random() - 0.5) * 0.05
                    local jy = (math.random() - 0.5) * 0.03
                    local jz = (math.random() - 0.5) * 0.05
                    local offset = CFrame.new(jx, jy, jz)
                    genPart.CFrame = baseMain * offset
                    if genTop and baseTop then
                        genTop.CFrame = baseTop * offset
                    end
                    task.wait(0.04)
                end
                if genPart and genPart.Parent then genPart.CFrame = baseMain end
                if genTop and baseTop then genTop.CFrame = baseTop end
            end)
        end
    end

    -- 2. Stop fault sparks & emit 3s exhaust smoke burst
    local sparkPart = b1:FindFirstChild("GeneratorSparks") :: BasePart?
    if sparkPart then
        local em = sparkPart:FindFirstChild("SparkEmitter") :: ParticleEmitter?
        if em then em.Enabled = false end

        local smoke = Instance.new("ParticleEmitter")
        smoke.Color = ColorSequence.new(Color3.fromRGB(185, 185, 185))
        smoke.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        })
        smoke.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 2),
            NumberSequenceKeypoint.new(1, 5.5)
        })
        smoke.Lifetime = NumberRange.new(1.5, 2.5)
        smoke.Rate = 38
        smoke.Speed = NumberRange.new(3, 7)
        smoke.Parent = sparkPart

        task.delay(3.0, function()
            smoke.Rate = 0
            Debris:AddItem(smoke, 2.6)
        end)
    end

    -- 3. Generator indicator lamp turns green
    local genLight = b1:FindFirstChild("GeneratorLight") :: BasePart?
    if genLight then
        genLight.BrickColor = BrickColor.new("Bright green")
        local pl = genLight:FindFirstChildOfClass("PointLight")
        if pl then pl.Color = Color3.fromRGB(40, 255, 80) end
    end

    -- 4. Apply Atmosphere Lighting (Daylight or Dark Horror)
    applyAtmosphereLighting(true)

    -- 5. High-Intensity Ultra-Bright Ceiling Lights with Fully Erratic Industrial Horror Flickering
    cancelLightingFlicker()
    lightingFlickerRunning = true

    task.spawn(function()
        local lampsFolder = b1:FindFirstChild("PendantLamps")
        if not lampsFolder then return end

        type LampData = {
            model: Instance,
            bulb: BasePart?,
            spot: SpotLight,
            glow: PointLight,
            baseSpotBrightness: number,
            baseGlowBrightness: number,
        }

        local lampList: { LampData } = {}
        for _, lampModel in ipairs(lampsFolder:GetChildren()) do
            local spot = lampModel:FindFirstChildWhichIsA("SpotLight", true)
            local glow = lampModel:FindFirstChildWhichIsA("PointLight", true)
            local bulb = lampModel:FindFirstChild("LampBulb", true) :: BasePart?
            if spot and glow then
                spot.Range = 48
                spot.Angle = 80
                spot.Color = Color3.fromRGB(255, 252, 235)
                spot.Shadows = true

                glow.Range = 32
                glow.Color = Color3.fromRGB(255, 245, 220)
                glow.Shadows = true

                table.insert(lampList, {
                    model = lampModel,
                    bulb = bulb,
                    spot = spot,
                    glow = glow,
                    baseSpotBrightness = 6.0,  -- High-intensity ultra-bright industrial beam
                    baseGlowBrightness = 3.0,  -- High-intensity wide ambient glow
                })
            end
        end

        local function setLampPower(lamp: LampData, ratio: number)
            local bSpot = lamp.baseSpotBrightness * ratio
            local bGlow = lamp.baseGlowBrightness * ratio
            lamp.spot.Brightness = bSpot
            lamp.spot.Enabled = bSpot > 0.05
            lamp.glow.Brightness = bGlow
            lamp.glow.Enabled = bGlow > 0.05
            if lamp.bulb then
                if ratio > 0.1 then
                    lamp.bulb.Material = Enum.Material.Neon
                    lamp.bulb.Transparency = math.clamp(0.05 + (1 - ratio) * 0.4, 0.05, 0.7)
                    lamp.bulb.Color = Color3.fromRGB(255, 245, 220)
                else
                    lamp.bulb.Material = Enum.Material.SmoothPlastic
                    lamp.bulb.Transparency = 0.85
                    lamp.bulb.Color = Color3.fromRGB(50, 50, 48)
                end
            end
        end

        -- Initial Power Surge Sequence (Chaotic 1.6s ignition stutter across all lamps)
        if genPart then
            playWorldSound(genPart, "rbxassetid://138090596", 0.8, 1.25, false, 80)
        end

        for step = 1, 6 do
            local on = (step % 2 == 1)
            local pwr = on and (step == 5 and 1.15 or 0.7) or 0
            for _, l in ipairs(lampList) do
                setLampPower(l, pwr)
            end
            task.wait(0.04 + (step * 0.025))
        end

        -- Bring all lamps to full 100% brightness
        for _, l in ipairs(lampList) do
            setLampPower(l, 1.0)
        end

        -- Launch Asynchronous Horror Flicker Coroutine for each lamp individually
        for _, lamp in ipairs(lampList) do
            local th = task.spawn(function()
                while generatorRestored and lightingFlickerRunning and FloorManager.IsActive do
                    -- Steady 100% burn period between erratic flickers (0.4s to 2.4s)
                    task.wait(0.4 + math.random() * 2.0)
                    if not generatorRestored or not lightingFlickerRunning or elevatorCalled then break end

                    local roll = math.random()
                    if roll < 0.42 then
                        -- PATTERN A: Rapid Micro-Strobe / Glitch (3 to 6 violent micro-bursts at 25-35Hz)
                        local bursts = math.random(3, 6)
                        for _ = 1, bursts do
                            local lvl = math.random() < 0.5 and 0.05 or (1.0 + (math.random() - 0.5) * 0.4)
                            setLampPower(lamp, lvl)
                            task.wait(0.02 + math.random() * 0.03)
                        end
                        setLampPower(lamp, 1.0)

                    elseif roll < 0.72 then
                        -- PATTERN B: Sudden Blackout / Pitch-Black Drop (0.3s to 1.3s total darkness)
                        setLampPower(lamp, 0)
                        task.wait(0.3 + math.random() * 1.0)
                        if generatorRestored and lightingFlickerRunning and not elevatorCalled then
                            -- Pop back on with sudden surge
                            if lamp.bulb and math.random() < 0.35 then
                                playWorldSound(lamp.bulb, "rbxassetid://138090596", 0.35, 1.3, false, 35)
                            end
                            setLampPower(lamp, 1.2)
                            task.wait(0.06)
                            setLampPower(lamp, 1.0)
                        end

                    elseif roll < 0.90 then
                        -- PATTERN C: Voltage Sag / Brownout (0.6s to 1.6s dim sickly glow)
                        setLampPower(lamp, 0.25 + math.random() * 0.15)
                        task.wait(0.6 + math.random() * 1.0)
                        if generatorRestored and lightingFlickerRunning and not elevatorCalled then
                            setLampPower(lamp, 1.0)
                        end

                    else
                        -- PATTERN D: High-Voltage Surge Flare
                        setLampPower(lamp, 1.35)
                        task.wait(0.06)
                        setLampPower(lamp, 1.0)
                    end
                end
            end)
            table.insert(activeLampThreads, th)
        end

        -- Global Power Grid Shudder / Generator Engine Dip (Every 8-14s)
        local globalGridThread = task.spawn(function()
            while generatorRestored and lightingFlickerRunning and FloorManager.IsActive do
                task.wait(8.0 + math.random() * 6.0)
                if not generatorRestored or not lightingFlickerRunning or elevatorCalled then break end

                -- Generator stumbles
                if engineSound then
                    engineSound.PlaybackSpeed = 0.25
                end
                if genPart then
                    playWorldSound(genPart, "rbxassetid://138090596", 0.6, 0.7, false, 70)
                end

                -- Entire basement drops into pitch-black terror
                for _, l in ipairs(lampList) do
                    setLampPower(l, 0.05)
                end

                task.wait(0.2 + math.random() * 0.3)

                -- Power snaps back
                if engineSound then
                    engineSound.PlaybackSpeed = 0.35
                end
                for _, l in ipairs(lampList) do
                    setLampPower(l, 1.0)
                end
            end
        end)
        table.insert(activeLampThreads, globalGridThread)
    end)
end

local function handleGeneratorFixed(player: Player, submittedConnections: any)
    if generatorRestored or not FloorManager.IsActive then return end
    if healthManagerRef and (healthManagerRef.IsDowned(player) or healthManagerRef.IsSpectator(player)) then return end

    local b1 = getB1()
    local genPanel = b1 and (b1:FindFirstChild("GeneratorPanel") :: BasePart? or b1:FindFirstChild("Generator") :: BasePart?)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not genPanel or not hrp or (hrp.Position - genPanel.Position).Magnitude > 28 then
        return
    end

    -- Server-side wire solution validation against player's issued order
    local expectedOrder = activePuzzleOrders[player]
    if not expectedOrder or typeof(submittedConnections) ~= "table" then
        warn("[FloorManager] Rejected invalid/unauthenticated GeneratorFixed submission from " .. player.Name)
        return
    end
    for leftIdx = 1, 3 do
        local matchedVisualIdx = submittedConnections[leftIdx] or submittedConnections[tostring(leftIdx)]
        if typeof(matchedVisualIdx) ~= "number" or expectedOrder[matchedVisualIdx] ~= leftIdx then
            warn("[FloorManager] Wire verification failed for " .. player.Name)
            return
        end
    end

    generatorRestored = true
    setBoolState("ElevatorPower", true)
    table.clear(activePuzzleOrders)

    activateEmergencyLightsAndGenerator()
    updateElevatorSignage()
    broadcastObjectiveState(nil, "OBJECTIVE 2 COMPLETE — Emergency power grid restored to 100%!", Color3.fromRGB(255, 195, 50))
    print("[FloorManager] Stage 2 complete: Generator restored & verified by server.")
end

------------------------------------------------------------------------
-- STAGE 3: CALL ELEVATOR -> 3s WARNING -> CRAWLER + PATHFINDING/NOISE -> GATE SWITCH -> FLOOR 1
------------------------------------------------------------------------
local function getNearestTargetPosition(crawlerRoot: BasePart): (Vector3?, Model?)
    local now = os.clock()
    local bestChar: Model? = nil
    local minDist = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if isPlayerAliveNonDowned(p) then
            local c = p.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp then
                local d = (hrp.Position - crawlerRoot.Position).Magnitude
                -- Direct close sight/chase priority if within 45 studs (or unobstructed)
                if d < minDist then
                    minDist = d
                    bestChar = c
                end
            end
        end
    end

    -- Check direct proximity vs acoustic sprint detection
    if bestChar and minDist <= 18 then
        return bestChar.PrimaryPart and bestChar.PrimaryPart.Position, bestChar
    end

    if lastHeardNoise and (now - lastHeardNoise.timestamp) <= 6.0 then
        local noiseDist = (lastHeardNoise.position - crawlerRoot.Position).Magnitude
        if noiseDist <= (lastHeardNoise.radius * 2.2) then
            return lastHeardNoise.position, bestChar
        end
    end

    if bestChar and bestChar.PrimaryPart then
        return bestChar.PrimaryPart.Position, bestChar
    end
    return nil, nil
end

local function spawnAndRunCrawler()
    if crawlerSpawned then return end
    crawlerSpawned = true

    local b1 = getB1()
    if not b1 then return end

    local tlfSS = ServerStorage:FindFirstChild("TheLastFloor")
    local enemies = tlfSS and tlfSS:FindFirstChild("Enemies")
    local template = enemies and enemies:FindFirstChild("Crawler")
    if not template then
        warn("[FloorManager] Crawler template missing in ServerStorage.TheLastFloor.Enemies.Crawler!")
        return
    end

    local crawler = template:Clone() :: Model
    crawler.Name = "DislocatedCrawler"
    local spawnCF = CFrame.new(28, 2.2, 20) * CFrame.Angles(0, math.rad(165), 0)
    crawler:PivotTo(spawnCF)
    crawler.Parent = b1
    activeCrawler = crawler

    local hum = crawler:FindFirstChildOfClass("Humanoid") :: Humanoid
    local root = crawler.PrimaryPart :: BasePart
    if not hum or not root then return end

    hum.WalkSpeed = 0 -- Pause during 2.2s intro reveal animation!

    -- Crawler screech & reveal audio + notify clients for intro reveal animation
    playWorldSound(root, "rbxassetid://9069609200", 0.9, 1.45, false, 120)
    crawlerEncounterRemote:FireAllClients(crawler, 2.2)

    -- Server-side dramatic physical intro twitch/rearing before hunting
    task.spawn(function()
        local head = crawler:FindFirstChild("Head") :: BasePart?
        for step = 1, 8 do
            if not crawler.Parent then return end
            if head then
                head.Color = (step % 2 == 0) and Color3.fromRGB(145, 95, 88) or Color3.fromRGB(105, 85, 78)
            end
            task.wait(0.25)
        end
        if not crawler.Parent or not FloorManager.IsActive then return end
        hum.WalkSpeed = 16.5 -- Sprint hunt speed (slightly slower than player sprint 19, faster than walk 12!)

        local lastPathTime = 0
        local currentWaypoints: { PathWaypoint } = {}
        local waypointIdx = 1
        local lastAttack = 0

        while crawler and crawler.Parent and hum.Health > 0 and FloorManager.IsActive do
            local targetPos, nearestChar = getNearestTargetPosition(root)
            if targetPos then
                local dist = (targetPos - root.Position).Magnitude

                -- If very close, move directly for responsive lunge; else use PathfindingService around pillars & cars
                if dist <= 16 then
                    hum:MoveTo(targetPos)
                else
                    if os.clock() - lastPathTime >= 0.7 then
                        lastPathTime = os.clock()
                        local path = PathfindingService:CreatePath({
                            AgentRadius = 2.0,
                            AgentHeight = 3.5,
                            AgentCanJump = false,
                            WaypointSpacing = 4.5,
                        })
                        local ok = pcall(function()
                            path:ComputeAsync(root.Position, targetPos)
                        end)
                        if ok and path.Status == Enum.PathStatus.Success then
                            currentWaypoints = path:GetWaypoints()
                            waypointIdx = 2 -- skip start point
                        else
                            currentWaypoints = {}
                        end
                    end

                    if #currentWaypoints >= waypointIdx then
                        local wp = currentWaypoints[waypointIdx]
                        hum:MoveTo(wp.Position)
                        if (wp.Position - root.Position).Magnitude < 4.0 then
                            waypointIdx += 1
                        end
                    else
                        hum:MoveTo(targetPos)
                    end
                end

                -- Melee claw strike check
                if nearestChar and nearestChar.PrimaryPart then
                    local playerDist = (nearestChar.PrimaryPart.Position - root.Position).Magnitude
                    if playerDist <= 5.5 and (os.clock() - lastAttack) >= 1.2 then
                        lastAttack = os.clock()
                        local targetPlayer = Players:GetPlayerFromCharacter(nearestChar)
                        if not targetPlayer or isPlayerAliveNonDowned(targetPlayer) then
                            local pHum = nearestChar:FindFirstChildOfClass("Humanoid")
                            if pHum and pHum.Health > 0 then
                                playWorldSound(root, "rbxassetid://138090596", 0.75, 1.35, false, 45)
                                pHum:TakeDamage(25)
                            end
                        end
                    end
                end
            end

            task.wait(0.2)
        end
    end)

    print("[FloorManager] DislocatedCrawler spawned from ServerStorage with Pathfinding + Acoustic AI.")
end

local function finalizeAndTransitionToFloor1()
    if floorCompleted then return end
    floorCompleted = true

    if elevatorServiceRef then
        elevatorServiceRef.LockHeavy()
    end

    broadcastObjectiveState("Lift doors sealed! Ascending to Floor 1...", "B1 ESCAPE SUCCESSFUL — ASCENDING!", Color3.fromRGB(80, 255, 130))

    -- Clean up crawler cleanly once sealed outside
    task.delay(1.0, function()
        if activeCrawler and activeCrawler.Parent then
            activeCrawler:Destroy()
            activeCrawler = nil
        end
    end)

    FloorManager.IsActive = false
    cancelLightingFlicker()
    if timerThread then
        task.cancel(timerThread)
        timerThread = nil
    end
    generatorVibrationRunning = false

    -- Stop generator engine loop before Floor 1 load
    local b1 = getB1()
    local genPart = b1 and b1:FindFirstChild("Generator")
    local engineLoop = genPart and genPart:FindFirstChild("EngineLoop") :: Sound?
    if engineLoop then engineLoop:Stop() end

    if elevatorServiceRef then
        elevatorServiceRef.RunAscendingSequence()
    end

    -- Transition state cleanly to Floor 1 (ready state; Floor 1 geometry starts in next phase)
    FloorManager.CurrentFloorIndex = 1
    local f1 = GameConfig.Floors[2]
    if f1 then
        floorStateRemote:FireAllClients(f1.Id, f1.Name, f1.FloorCode, f1.DurationSeconds, f1.Description)
    end
    broadcastObjectiveState("Arrived at Floor 1: Lobby & Residential.", "WELCOME TO FLOOR 1 (LEVEL READY)", Color3.fromRGB(140, 220, 255))
    print("[FloorManager] Transitioned cleanly from Basement B1 -> Floor 1.")
end

local function onGateSwitchPulled(activatingPlayer: Player)
    if gateSequenceStarted or not elevatorCalled or floorCompleted then return end
    if not elevatorServiceRef or not elevatorServiceRef.IsOpen then return end
    if healthManagerRef and (healthManagerRef.IsDowned(activatingPlayer) or healthManagerRef.IsSpectator(activatingPlayer)) then return end
    if not elevatorServiceRef.IsPlayerInsideCabin(activatingPlayer) then return end

    gateSequenceStarted = true

    local activePlayers = getActiveNonSpectatorPlayers()
    local status = elevatorServiceRef.GetBoardingStatus(activePlayers)

    if status.allInside then
        elevatorServiceRef.SetGateSwitchEnabled(false, false)
        finalizeAndTransitionToFloor1()
        return
    end

    -- Teammate(s) outside cabin: NEVER silently abandon! Give 5-second audible/HUD warning.
    elevatorServiceRef.SetGateSwitchEnabled(false, true)
    local warnSeconds = math.ceil(GameConfig.GateCloseWarningDuration or 5)

    task.spawn(function()
        local deadline = os.clock() + warnSeconds
        local lastShownSec = -1

        while os.clock() < deadline and not floorCompleted and FloorManager.IsActive do
            local remaining = math.ceil(deadline - os.clock())
            local curActive = getActiveNonSpectatorPlayers()
            local curStatus = elevatorServiceRef.GetBoardingStatus(curActive)

            if curStatus.allInside then
                break
            end

            if remaining ~= lastShownSec then
                lastShownSec = remaining
                local names = {}
                for _, outP in ipairs(curStatus.outside) do
                    table.insert(names, outP.DisplayName)
                end
                local msg = string.format("CLOSING IN %ds — TEAMMATE(S) OUTSIDE: %s", remaining, table.concat(names, ", "))
                elevatorServiceRef.UpdateScreen("GATE WARNING", string.format("CLOSING IN %ds — BOARD NOW!", remaining))
                broadcastObjectiveState("GET INSIDE THE ELEVATOR NOW!", msg, Color3.fromRGB(255, 85, 65))
                playWorldSound(elevatorServiceRef.GetGateSwitch(), "rbxassetid://6895079853", 0.9, 0.75, false, 70)
            end

            task.wait(0.25)
        end

        finalizeAndTransitionToFloor1()
    end)
end

local function onElevatorCalled(player: Player)
    if not doorUnjammed or not generatorRestored or elevatorCalled or not FloorManager.IsActive then return end
    if healthManagerRef and (healthManagerRef.IsDowned(player) or healthManagerRef.IsSpectator(player)) then return end

    elevatorCalled = true
    setBoolState("ElevatorCalled", true)
    updateElevatorSignage()

    local b1 = getB1()
    local callBtn = b1 and b1:FindFirstChild("ElevatorCallButton") :: BasePart?
    if callBtn then
        playWorldSound(callBtn, "rbxassetid://6895079853", 0.85, 0.9, false, 60)
        recordNoise(callBtn.Position, GameConfig.NoiseRadii.ElevatorCall or 50)
    end

    local warnTime = GameConfig.CrawlerWarningDuration or 3.0
    elevWarningRemote:FireAllClients(warnTime, "⚠ LIFT NOISE ALERTED SOMETHING IN THE DARK!")
    broadcastObjectiveState("Lift dispatched — WATCH THE SHADOWS!", "⚠ MOVEMENT DETECTED — DEFENSIVE POSITIONS!", Color3.fromRGB(255, 65, 65))

    -- 3-second audio & blood-red frantic emergency warning sequence before Crawler reveals & doors open
    task.spawn(function()
        cancelLightingFlicker()

        local spots: { SpotLight } = {}
        local glows: { PointLight } = {}
        local bulbs: { BasePart } = {}
        if b1 then
            for _, d in ipairs(b1:GetDescendants()) do
                if d:IsA("SpotLight") and d.Name == "CeilingLight" then
                    table.insert(spots, d)
                elseif d:IsA("PointLight") and d.Name == "CeilingLightGlow" then
                    table.insert(glows, d)
                elseif d:IsA("BasePart") and d.Name == "LampBulb" then
                    table.insert(bulbs, d)
                end
            end
        end

        for pulse = 1, 8 do
            local isRed = (pulse % 2 == 1)
            for _, s in ipairs(spots) do
                s.Enabled = true
                s.Color = isRed and Color3.fromRGB(255, 35, 35) or Color3.fromRGB(160, 20, 20)
                s.Brightness = isRed and 2.6 or 0.15
                s.Shadows = true
            end
            for _, g in ipairs(glows) do
                g.Enabled = true
                g.Color = isRed and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(130, 15, 15)
                g.Brightness = isRed and 1.3 or 0.05
                g.Shadows = true
            end
            for _, b in ipairs(bulbs) do
                b.Color = isRed and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(60, 20, 20)
                b.Transparency = isRed and 0.05 or 0.85
            end
            if callBtn and pulse % 2 == 1 then
                playWorldSound(callBtn, "rbxassetid://6895079853", 0.85, 0.65, false, 90)
            end
            task.wait(warnTime / 8)
        end

        for _, s in ipairs(spots) do
            s.Color = Color3.fromRGB(235, 55, 40)
            s.Brightness = 1.8
            s.Shadows = true
        end
        for _, g in ipairs(glows) do
            g.Color = Color3.fromRGB(215, 45, 30)
            g.Brightness = 0.9
            g.Shadows = true
        end

        if not FloorManager.IsActive then return end

        -- Spawn DislocatedCrawler + Open recessed Elevator doors simultaneously!
        spawnAndRunCrawler()

        if elevatorServiceRef then
            elevatorServiceRef.Unlock()
        end

        broadcastObjectiveState(nil, "DOORS OPEN — BOARD LIFT & PULL GATE SWITCH [E]!", Color3.fromRGB(80, 255, 120))
        print("[FloorManager] Stage 3 active: Crawler unleashed, Lift open, Interior Gate Switch live.")
    end)
end

------------------------------------------------------------------------
-- PUBLIC LIFECYCLE
------------------------------------------------------------------------
function FloorManager.Init(ElevatorService: any, HealthManager: any?)
    elevatorServiceRef = ElevatorService
    healthManagerRef = HealthManager

    if not healthManagerRef then
        local ok, hm = pcall(function()
            return require(script.Parent:WaitForChild("HealthManager"))
        end)
        if ok then healthManagerRef = hm end
    end

    noiseRemote.OnServerEvent:Connect(function(player, noiseType, _clientPos)
        if typeof(noiseType) ~= "string" then return end
        local radius = GameConfig.NoiseRadii[noiseType]
        if not radius then return end
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return end
        recordNoise(hrp.Position, radius)
    end)

    beamPriedRemote.OnServerEvent:Connect(function(player)
        tryStartBeamPry(player)
    end)

    requestGenPuzzleRemote.OnServerEvent:Connect(function(player)
        handleOpenGeneratorRequest(player)
    end)

    genFixedRemote.OnServerEvent:Connect(function(player, connections)
        handleGeneratorFixed(player, connections)
    end)

    Players.PlayerRemoving:Connect(function(player)
        activePuzzleOrders[player] = nil
        task.defer(ensureCrowbarAvailability)
    end)

    local b1 = getB1()
    if b1 then
        local crowbarPickup = b1:FindFirstChild("CrowbarPickup") :: BasePart?
        local crowbarPrompt = crowbarPickup and crowbarPickup:FindFirstChild("CrowbarPrompt") :: ProximityPrompt?
        if crowbarPrompt then
            crowbarPrompt.HoldDuration = GameConfig.CrowbarPickupDuration or 2.0
            crowbarPrompt.Triggered:Connect(grantCrowbarToPlayer)
        end

        local beam = b1:FindFirstChild("JammedBeam") :: BasePart?
        local pryPrompt = beam and beam:FindFirstChild("PryPrompt") :: ProximityPrompt?
        if pryPrompt then
            pryPrompt.Triggered:Connect(tryStartBeamPry)
        end

        local genPanel = b1:FindFirstChild("GeneratorPanel")
        local genPrompt = genPanel and genPanel:FindFirstChild("GeneratorPrompt") :: ProximityPrompt?
        if genPrompt then
            genPrompt.Enabled = true
            genPrompt.Triggered:Connect(handleOpenGeneratorRequest)
        end

        local callBtn = b1:FindFirstChild("ElevatorCallButton")
        local callPrompt = callBtn and callBtn:FindFirstChild("CallElevatorPrompt") :: ProximityPrompt?
        if callPrompt then
            callPrompt.Triggered:Connect(onElevatorCalled)
        end
    end

    local tlf = Workspace:FindFirstChild("TheLastFloor")
    local elevFolder = tlf and tlf:FindFirstChild("Elevator")
    local cabin = elevFolder and elevFolder:FindFirstChild("ElevatorCabin")
    local gateSwitch = cabin and cabin:FindFirstChild("CabinGateSwitch")
    local gatePrompt = gateSwitch and gateSwitch:FindFirstChild("GateSwitchPrompt") :: ProximityPrompt?
    if gatePrompt then
        gatePrompt.Triggered:Connect(onGateSwitchPulled)
    end

    print("[FloorManager] 3-Stage Cooperative Basement B1 puzzle state machine initialized.")
end

function FloorManager.StartFloor(floorIndex: number)
    FloorManager.CurrentFloorIndex = floorIndex
    local data = GameConfig.Floors[floorIndex + 1]
    if not data then return end

    FloorManager.TimeRemaining = data.DurationSeconds
    FloorManager.IsActive = true

    cancelLightingFlicker()
    applyAtmosphereLighting(false)

    -- Extinguish ceiling lights until generator restore
    local b1 = getB1()
    if b1 then
        for _, d in ipairs(b1:GetDescendants()) do
            if d:IsA("SpotLight") and d.Name == "CeilingLight" then
                d.Enabled = false
                d.Brightness = 0
            elseif d:IsA("PointLight") and d.Name == "CeilingLightGlow" then
                d.Enabled = false
                d.Brightness = 0
            elseif d:IsA("BasePart") and d.Name == "LampBulb" then
                d.Material = Enum.Material.SmoothPlastic
                d.Transparency = 0.85
                d.Color = Color3.fromRGB(50, 50, 48)
            end
        end
    end

    -- Authoritative spawn safety: Ensure all active squad members start inside Basement B1
    local checkpointCf = CFrame.new(60, 3.5, -55) * CFrame.Angles(0, math.rad(-90), 0)
    for _, p in ipairs(Players:GetPlayers()) do
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.CFrame = checkpointCf
        end
    end

    doorUnjammed = false
    generatorRestored = false
    elevatorCalled = false
    gateSequenceStarted = false
    floorCompleted = false
    isPryingBeam = false
    crawlerSpawned = false
    lastHeardNoise = nil
    table.clear(activePuzzleOrders)

    setBoolState("DoorUnjammed", false)
    setBoolState("ElevatorPower", false)
    setBoolState("ElevatorCalled", false)
    updateElevatorSignage()

    print(string.format("[FloorManager] Commencing %s | Time: %ds", data.Name, data.DurationSeconds))
    floorStateRemote:FireAllClients(data.Id, data.Name, data.FloorCode, data.DurationSeconds, data.Description)
    broadcastObjectiveState()

    if timerThread then task.cancel(timerThread) end
    timerThread = task.spawn(function()
        while FloorManager.TimeRemaining > 0 and FloorManager.IsActive do
            floorTimerRemote:FireAllClients(FloorManager.TimeRemaining)
            task.wait(1)
            FloorManager.TimeRemaining -= 1
        end

        if FloorManager.IsActive and FloorManager.TimeRemaining <= 0 then
            FloorManager.OnTimerExpired()
        end
    end)
end

function FloorManager.OnTimerExpired()
    FloorManager.IsActive = false
    cancelLightingFlicker()
    floorTimerRemote:FireAllClients(0)
    print("[FloorManager] Timer expired — floor failure triggered.")
    broadcastObjectiveState("TIME EXPIRED — Gas breach!", "CRITICAL FAILURE — BASEMENT LOCKDOWN COLLAPSE!", Color3.fromRGB(255, 35, 35))
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        local h = c and c:FindFirstChildOfClass("Humanoid") :: Humanoid?
        if h and h.Health > 0 then
            h:TakeDamage(100)
        end
    end
end

return FloorManager
