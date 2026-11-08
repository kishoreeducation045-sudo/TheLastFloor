--!strict
-- Movement & Stealth Controller (Sprint, Crouch, Stamina, Noise)

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes = ReplicatedStorage.TheLastFloor.Remotes
local noiseRemote = remotes:WaitForChild("NoiseEmitted") :: RemoteEvent

local MovementController = {}
local localPlayer = Players.LocalPlayer

-- Stamina Config
local MAX_STAMINA = 100
local STAMINA_DRAIN_RATE = 18 -- Per second while sprinting
local STAMINA_RECOVER_RATE = 14 -- Per second while walking/idle
local STAMINA_RECOVERY_THRESHOLD = 15 -- Minimum stamina to sprint after exhaustion

local currentStamina = MAX_STAMINA
local isSprinting = false
local isCrouching = false
local isExhausted = false
local shiftKeyDown = false

local HUDController: any = nil

function MovementController.Init()
    -- Dynamically require HUDController for UI synchronization
    task.spawn(function()
        local controllers = script.Parent
        local hudMod = controllers:WaitForChild("HUDController")
        HUDController = require(hudMod)
        if HUDController and HUDController.SetStamina then
            HUDController.SetStamina(currentStamina / MAX_STAMINA)
        end
    end)

    local function setupCharacter(character: Model)
        local humanoid = character:WaitForChild("Humanoid") :: Humanoid
        isSprinting = false
        isCrouching = false
        isExhausted = false
        currentStamina = MAX_STAMINA
        shiftKeyDown = false

        if HUDController and HUDController.SetStamina then
            HUDController.SetStamina(1)
        end

        local function updateSpeed()
            if not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand then return end

            if isCrouching then
                humanoid.WalkSpeed = GameConfig.CrouchSpeed
            elseif isSprinting and not isExhausted then
                humanoid.WalkSpeed = GameConfig.SprintSpeed
            else
                humanoid.WalkSpeed = GameConfig.WalkSpeed
            end
        end

        UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end

            if input.KeyCode == Enum.KeyCode.LeftShift then
                shiftKeyDown = true
                if not isCrouching and not isExhausted and currentStamina > STAMINA_RECOVERY_THRESHOLD then
                    isSprinting = true
                    updateSpeed()
                end
            elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
                isCrouching = not isCrouching
                if isCrouching then
                    isSprinting = false
                elseif shiftKeyDown and not isExhausted and currentStamina > STAMINA_RECOVERY_THRESHOLD then
                    isSprinting = true
                end
                updateSpeed()
            end
        end)

        UserInputService.InputEnded:Connect(function(input, gpe)
            if input.KeyCode == Enum.KeyCode.LeftShift then
                shiftKeyDown = false
                isSprinting = false
                updateSpeed()
            end
        end)

        -- Heartbeat Loop: Manage Stamina Drain & Recovery
        local lastNoiseTick = 0
        local heartbeatConn: RBXScriptConnection
        heartbeatConn = RunService.Heartbeat:Connect(function(dt)
            if not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand then
                isSprinting = false
                return
            end

            local isMoving = humanoid.MoveDirection.Magnitude > 0.05

            if isSprinting and isMoving and not isCrouching then
                -- Drain stamina
                currentStamina = math.max(0, currentStamina - (STAMINA_DRAIN_RATE * dt))

                -- Emit noise every 0.6s
                local now = os.clock()
                if now - lastNoiseTick >= 0.6 then
                    lastNoiseTick = now
                    noiseRemote:FireServer("Sprint", character.PrimaryPart and character.PrimaryPart.Position or Vector3.zero)
                end

                if currentStamina <= 0 then
                    isExhausted = true
                    isSprinting = false
                    updateSpeed()
                end
            else
                -- Recover stamina gradually when walking or stationary
                currentStamina = math.min(MAX_STAMINA, currentStamina + (STAMINA_RECOVER_RATE * dt))

                if isExhausted and currentStamina >= STAMINA_RECOVERY_THRESHOLD then
                    isExhausted = false
                    -- If player is still holding Shift, resume sprint
                    if shiftKeyDown and not isCrouching and isMoving then
                        isSprinting = true
                        updateSpeed()
                    end
                end
            end

            -- Update HUD
            if HUDController and HUDController.SetStamina then
                HUDController.SetStamina(currentStamina / MAX_STAMINA)
            end
        end)

        humanoid.Died:Connect(function()
            if heartbeatConn then heartbeatConn:Disconnect() end
        end)
    end

    if localPlayer.Character then
        setupCharacter(localPlayer.Character)
    end
    localPlayer.CharacterAdded:Connect(setupCharacter)

    print("[MovementController] Stamina & Sprint system initialized.")
end

return MovementController
