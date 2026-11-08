--!strict
-- FloorManager.luau
-- Authoritative floor timer + B1 3-Step Puzzle State Machine
-- Step 1: Pry elevator door track with Crowbar
-- Step 2: Fix East-wall generator (color wire bypass mini-game)
-- Step 3: Call & defend elevator (doors open, 59s Crawler ambush)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes    = ReplicatedStorage.TheLastFloor.Remotes

local floorStateRemote   = remotes.FloorStateChanged
local floorTimerRemote   = remotes.FloorTimerUpdate
local puzzleStateRemote  = remotes.PuzzleStateChanged

local FloorManager = {}
FloorManager.CurrentFloorIndex = 0
FloorManager.TimeRemaining      = 120
FloorManager.IsActive           = false

-- B1 Puzzle States:
-- 0 = Search area, 1 = Crowbar equipped, 2 = Door pried, 3 = Generator restored, 4 = Lift called
local B1State = 0
local timerThread: thread? = nil
local crawlerSpawned = false

local function getB1(): Folder?
    local tlf = Workspace:FindFirstChild("TheLastFloor")
    if not tlf then return end
    return tlf:FindFirstChild("Basement_B1") :: Folder?
end

local function broadcastPuzzle(state: number, msg: string)
    B1State = state
    puzzleStateRemote:FireAllClients(state, msg)
end

------------------------------------------------------------------------
-- CRAWLER AMBUSH AT 59 SECONDS
------------------------------------------------------------------------
local function spawnDislocatedCrawler()
    if crawlerSpawned then return end
    crawlerSpawned = true

    local b1 = getB1()
    if not b1 then return end

    print("[FloorManager] Ambush! Dislocated Crawler emerging at 59 seconds...")

    -- Spawn position: behind vehicle column 2
    local spawnCFrame = CFrame.new(28, 2.5, 12)

    local crawler = Instance.new("Model")
    crawler.Name = "DislocatedCrawler"

    local hum = Instance.new("Humanoid")
    hum.MaxHealth = 80
    hum.Health = 80
    hum.WalkSpeed = 16
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.Parent = crawler

    -- Torso (low to ground)
    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2.5, 1.2, 3.5)
    root.CFrame = spawnCFrame
    root.BrickColor = BrickColor.new("Dark taupe")
    root.Material = Enum.Material.CorrodedMetal
    root.CanCollide = true
    root.Parent = crawler
    crawler.PrimaryPart = root

    -- Head with glowing red eyes
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.CFrame = spawnCFrame * CFrame.new(0, 0.4, -2)
    head.BrickColor = BrickColor.new("Dark stone grey")
    head.Material = Enum.Material.Slate
    head.Parent = crawler

    local weldHead = Instance.new("WeldConstraint")
    weldHead.Part0 = root
    weldHead.Part1 = head
    weldHead.Parent = head

    -- Glowing eyes
    for _, eyeOffset in ipairs({Vector3.new(-0.3, 0.1, -0.6), Vector3.new(0.3, 0.1, -0.6)}) do
        local eye = Instance.new("Part")
        eye.Name = "CrawlerEye"
        eye.Size = Vector3.new(0.2, 0.2, 0.2)
        eye.CFrame = head.CFrame * CFrame.new(eyeOffset)
        eye.BrickColor = BrickColor.new("Bright red")
        eye.Material = Enum.Material.Neon
        eye.CanCollide = false
        eye.Parent = crawler

        local we = Instance.new("WeldConstraint")
        we.Part0 = head
        we.Part1 = eye
        we.Parent = eye
    end

    -- Limbs (crawling splayed posture)
    for i, offset in ipairs({
        Vector3.new(-1.6, -0.3, -1.2),
        Vector3.new(1.6, -0.3, -1.2),
        Vector3.new(-1.6, -0.3, 1.2),
        Vector3.new(1.6, -0.3, 1.2)
    }) do
        local limb = Instance.new("Part")
        limb.Name = "CrawlerLimb_"..i
        limb.Size = Vector3.new(0.6, 2.0, 0.6)
        limb.CFrame = spawnCFrame * CFrame.new(offset) * CFrame.Angles(math.rad(45), 0, (offset.X < 0 and math.rad(30) or math.rad(-30)))
        limb.BrickColor = BrickColor.new("Dark stone grey")
        limb.Material = Enum.Material.Slate
        limb.CanCollide = false
        limb.Parent = crawler

        local wl = Instance.new("WeldConstraint")
        wl.Part0 = root
        wl.Part1 = limb
        wl.Parent = limb
    end

    -- Horror audio cue
    local roar = Instance.new("Sound")
    roar.SoundId = "rbxassetid://9114223170" -- horror screech cue
    roar.Volume = 1.5
    roar.RollOffMaxDistance = 150
    roar.Parent = root
    roar:Play()

    crawler.Parent = b1

    -- Chase AI loop
    task.spawn(function()
        local lastAttack = 0
        while crawler and crawler.Parent and hum.Health > 0 do
            -- Find nearest player
            local nearestChar: Model? = nil
            local minDist = math.huge

            for _, p in ipairs(Players:GetPlayers()) do
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
                local pHum = c and c:FindFirstChild("Humanoid") :: Humanoid?
                if hrp and pHum and pHum.Health > 0 then
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearestChar = c
                    end
                end
            end

            if nearestChar and nearestChar.PrimaryPart then
                local targetPos = nearestChar.PrimaryPart.Position
                hum:MoveTo(targetPos)

                -- Attack if close
                if minDist <= 5 and os.clock() - lastAttack >= 1.2 then
                    lastAttack = os.clock()
                    local pHum = nearestChar:FindFirstChild("Humanoid") :: Humanoid?
                    if pHum then
                        pHum:TakeDamage(25)
                    end
                end
            end

            task.wait(0.25)
        end
    end)
end

------------------------------------------------------------------------
-- STEP 1: Pry Elevator Door Track
------------------------------------------------------------------------
local function onBeamPried()
    if B1State >= 2 then return end
    local b1 = getB1()
    if not b1 then return end

    local beam = b1:FindFirstChild("JammedBeam") :: BasePart?
    if beam then
        TweenService:Create(beam, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
            CFrame = beam.CFrame * CFrame.new(0, -3.5, 0),
            Transparency = 1
        }):Play()
        task.delay(1, function()
            if beam then beam:Destroy() end
        end)
    end

    local genPanel = b1:FindFirstChild("GeneratorPanel")
    if genPanel then
        local pp = genPanel:FindFirstChild("GeneratorPrompt") :: ProximityPrompt?
        if pp then pp.Enabled = true end
    end

    broadcastPuzzle(2, "BEAM CLEARED — Find the East-wall generator and bypass circuits.")
    print("[FloorManager] Step 1 complete: Jammed beam cleared, generator terminal active.")
end

------------------------------------------------------------------------
-- STEP 2: Generator Bypass Solved
------------------------------------------------------------------------
local function onGeneratorFixed()
    if B1State >= 3 then return end
    local b1 = getB1()
    if not b1 then return end

    -- Disable spark emission, emit burst of smoke
    local sparkPart = b1:FindFirstChild("GeneratorSparks")
    if sparkPart then
        local em = sparkPart:FindFirstChild("SparkEmitter") :: ParticleEmitter?
        if em then em.Enabled = false end

        local smoke = Instance.new("ParticleEmitter")
        smoke.Color = ColorSequence.new(Color3.fromRGB(180, 180, 180))
        smoke.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        })
        smoke.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 2),
            NumberSequenceKeypoint.new(1, 6)
        })
        smoke.Lifetime = NumberRange.new(1.5, 3)
        smoke.Rate = 45
        smoke.Speed = NumberRange.new(3, 8)
        smoke.Parent = sparkPart

        task.delay(3, function()
            smoke.Rate = 0
            task.delay(3, function() smoke:Destroy() end)
        end)
    end

    -- Generator status light -> Green
    local genLight = b1:FindFirstChild("GeneratorLight") :: BasePart?
    if genLight then
        genLight.BrickColor = BrickColor.new("Bright green")
        local pl = genLight:FindFirstChildOfClass("PointLight")
        if pl then pl.Color = Color3.fromRGB(40, 255, 80) end
    end

    local arrow = b1:FindFirstChild("GeneratorArrow") :: BasePart?
    if arrow then arrow.Transparency = 1 end

    -- Strobe sequence and stabilizing ceiling fixtures
    task.spawn(function()
        local fixtures = {}
        for _, d in ipairs(b1:GetDescendants()) do
            if d:IsA("PointLight") and d.Name == "CeilingLight" then
                table.insert(fixtures, d)
            end
        end

        for i = 1, 8 do
            local on = (i % 2 == 0)
            for _, pl in ipairs(fixtures) do
                pl.Enabled = on
                pl.Brightness = on and 4.5 or 0
            end
            task.wait(0.08 + (i * 0.025))
        end

        for _, pl in ipairs(fixtures) do
            pl.Enabled = true
            pl.Brightness = 4.5
        end

        -- Horror random flickers every ~3 seconds
        task.spawn(function()
            while true do
                task.wait(2.5 + (math.random() * 1.5))
                if #fixtures > 0 then
                    local pick = fixtures[math.random(1, #fixtures)]
                    pick.Brightness = 0.5
                    task.wait(0.05)
                    pick.Brightness = 4.5
                    task.wait(0.03)
                    pick.Brightness = 1.0
                    task.wait(0.08)
                    pick.Brightness = 4.5
                end
            end
        end)
    end)

    -- Ambient lighting upgrade
    local Lighting = game:GetService("Lighting")
    TweenService:Create(Lighting, TweenInfo.new(1.5), {
        Brightness = 1.2,
        Ambient = Color3.fromRGB(55, 55, 65),
        FogEnd = 240
    }):Play()

    -- Elevator status display -> Amber
    local indicator = b1:FindFirstChild("ElevatorIndicator")
    if indicator then
        local gui = indicator:FindFirstChild("ElevatorStatusGui")
        local lbl = gui and gui:FindFirstChild("StatusLabel") :: TextLabel?
        if lbl then
            lbl.Text = "POWER RESTORED\nCALL ELEVATOR"
            lbl.TextColor3 = Color3.fromRGB(255, 180, 0)
            lbl.BackgroundColor3 = Color3.fromRGB(20, 15, 0)
        end
    end

    -- Call button enabled
    local callBtn = b1:FindFirstChild("ElevatorCallButton")
    if callBtn then
        local pp = callBtn:FindFirstChild("CallElevatorPrompt") :: ProximityPrompt?
        if pp then pp.Enabled = true end

        local face = b1:FindFirstChild("CallButtonFace") :: BasePart?
        if face then
            face.BrickColor = BrickColor.new("Bright green")
            face.Material = Enum.Material.Neon
        end
    end

    broadcastPuzzle(3, "POWER RESTORED — Press the call button to summon the elevator.")
    print("[FloorManager] Step 2 complete: Facility power restored.")
end

------------------------------------------------------------------------
-- STEP 3: Call & Defend Elevator
------------------------------------------------------------------------
local function onElevatorCalled(ElevatorService: any)
    if B1State >= 4 then return end
    broadcastPuzzle(4, "ELEVATOR ARRIVING...")

    local b1 = getB1()
    if not b1 then return end

    local indicator = b1:FindFirstChild("ElevatorIndicator")
    local gui = indicator and indicator:FindFirstChild("ElevatorStatusGui")
    local lbl = gui and gui:FindFirstChild("StatusLabel") :: TextLabel?
    if lbl then
        lbl.Text = "ELEVATOR ARRIVING..."
        lbl.TextColor3 = Color3.fromRGB(50, 255, 80)
        lbl.BackgroundColor3 = Color3.fromRGB(0, 20, 5)
    end

    -- 2 second arrival as specified by user
    task.delay(2.0, function()
        if lbl then lbl.Text = "DOORS OPEN\nBOARD NOW" end

        local doorL = b1:FindFirstChild("ElevatorDoor_Left") :: BasePart?
        local doorR = b1:FindFirstChild("ElevatorDoor_Right") :: BasePart?
        if doorL then
            TweenService:Create(doorL, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
                CFrame = doorL.CFrame * CFrame.new(-5, 0, 0)
            }):Play()
        end
        if doorR then
            TweenService:Create(doorR, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
                CFrame = doorR.CFrame * CFrame.new(5, 0, 0)
            }):Play()
        end

        if ElevatorService then
            ElevatorService.Unlock()
        end
        broadcastPuzzle(4, "BOARD NOW — Elevator doors are open!")
        print("[FloorManager] Step 3 complete: Elevator doors open.")
    end)
end

------------------------------------------------------------------------
-- Public Lifecycle
------------------------------------------------------------------------
function FloorManager.Init(ElevatorService: any)
    local beamPried = remotes:WaitForChild("BeamPried") :: RemoteEvent
    beamPried.OnServerEvent:Connect(function()
        if B1State == 1 then
            onBeamPried()
        end
    end)

    local giveCrowbar = remotes:WaitForChild("GiveCrowbar") :: RemoteEvent
    local genFixed = remotes:WaitForChild("GeneratorFixed") :: RemoteEvent
    genFixed.OnServerEvent:Connect(function()
        if B1State == 2 then
            onGeneratorFixed()
        end
    end)

    local b1 = getB1()
    if b1 then
        local crowbarPickup = b1:FindFirstChild("CrowbarPickup") :: BasePart?
        if crowbarPickup then
            local pp = crowbarPickup:FindFirstChild("CrowbarPrompt") :: ProximityPrompt?
            if pp then
                pp.Triggered:Connect(function(player)
                    if B1State == 0 then
                        giveCrowbar:FireClient(player)
                        broadcastPuzzle(1, "Crowbar equipped — clear the elevator door obstruction.")
                        crowbarPickup.Transparency = 1
                        pp.Enabled = false
                    end
                end)
            end
        end

        local callBtn = b1:FindFirstChild("ElevatorCallButton")
        if callBtn then
            local pp = callBtn:FindFirstChild("CallElevatorPrompt") :: ProximityPrompt?
            if pp then
                pp.Triggered:Connect(function(player)
                    if B1State == 3 then
                        onElevatorCalled(ElevatorService)
                    end
                end)
            end
        end
    end

    print("[FloorManager] B1 3-step state machine initialized.")
end

function FloorManager.StartFloor(floorIndex: number)
    FloorManager.CurrentFloorIndex = floorIndex
    local data = GameConfig.Floors[floorIndex + 1]
    if not data then return end

    FloorManager.TimeRemaining = data.DurationSeconds
    FloorManager.IsActive      = true
    B1State = 0
    crawlerSpawned = false

    print(string.format("[FloorManager] Commencing %s | Time: %ds", data.Name, data.DurationSeconds))
    floorStateRemote:FireAllClients(data.Id, data.Name, data.FloorCode, data.DurationSeconds, data.Description)

    if timerThread then task.cancel(timerThread) end
    timerThread = task.spawn(function()
        while FloorManager.TimeRemaining > 0 and FloorManager.IsActive do
            floorTimerRemote:FireAllClients(FloorManager.TimeRemaining)

            -- At 59 seconds remaining: trigger crawler ambush!
            if FloorManager.TimeRemaining <= 59 and not crawlerSpawned then
                spawnDislocatedCrawler()
            end

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
    print("[FloorManager] Timer expired — floor failure triggered.")
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        local h = c and c:FindFirstChildOfClass("Humanoid") :: Humanoid?
        if h then h:TakeDamage(100) end
    end
end

return FloorManager
