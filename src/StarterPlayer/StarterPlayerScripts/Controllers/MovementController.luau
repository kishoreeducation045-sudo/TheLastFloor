--!strict
-- Movement & Stealth Controller (Sprint, Crouch, Noise)

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes = ReplicatedStorage.TheLastFloor.Remotes
local noiseRemote = remotes:WaitForChild("NoiseEmitted") :: RemoteEvent

local MovementController = {}
local localPlayer = Players.LocalPlayer

local isSprinting = false
local isCrouching = false

function MovementController.Init()
    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid") :: Humanoid

    localPlayer.CharacterAdded:Connect(function(newChar)
        character = newChar
        humanoid = newChar:WaitForChild("Humanoid") :: Humanoid
        isSprinting = false
        isCrouching = false
    end)

    local function updateMovement()
        if not humanoid or humanoid.Health <= 0 then return end

        if isCrouching then
            humanoid.WalkSpeed = GameConfig.CrouchSpeed
        elseif isSprinting then
            humanoid.WalkSpeed = GameConfig.SprintSpeed
            -- Emit sprinting noise periodically
            noiseRemote:FireServer("Sprint", character.PrimaryPart and character.PrimaryPart.Position or Vector3.zero)
        else
            humanoid.WalkSpeed = GameConfig.WalkSpeed
        end
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.LeftShift then
            if not isCrouching then
                isSprinting = true
                updateMovement()
            end
        elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
            isCrouching = not isCrouching
            if isCrouching then
                isSprinting = false
            end
            updateMovement()
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.LeftShift then
            isSprinting = false
            updateMovement()
        end
    end)
end

return MovementController
