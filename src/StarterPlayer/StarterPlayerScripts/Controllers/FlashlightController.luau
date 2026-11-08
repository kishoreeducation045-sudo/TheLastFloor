-- FlashlightController.luau
-- F key toggles flashlight SpotLight on player's head
-- Flashlight is droppable (future feature) but always starts in inventory slot 1

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local FlashlightController = {}
local localPlayer = Players.LocalPlayer
local flashlightOn = false
local spotLight    = nil

local function attachSpotlight(character)
    -- Remove old spotlight if exists
    if spotLight then spotLight:Destroy() end

    local head = character:FindFirstChild("Head")
    if not head then return end

    spotLight = Instance.new("SpotLight")
    spotLight.Name       = "PlayerFlashlight"
    spotLight.Enabled    = false
    spotLight.Brightness = 6
    spotLight.Range      = 55
    spotLight.Angle      = 40
    spotLight.Color      = Color3.fromRGB(240, 240, 220)  -- slightly warm white
    spotLight.Face       = Enum.NormalId.Front
    spotLight.Parent     = head
end

local function setFlashlight(on)
    flashlightOn = on
    if spotLight then spotLight.Enabled = on end
end

function FlashlightController.Init()
    -- Attach to current character
    if localPlayer.Character then
        attachSpotlight(localPlayer.Character)
    end
    localPlayer.CharacterAdded:Connect(function(char)
        char:WaitForChild("Head")
        attachSpotlight(char)
        -- Restore on state after respawn
        if flashlightOn then setFlashlight(true) end
    end)

    -- F key toggle
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F then
            setFlashlight(not flashlightOn)
        end
    end)

    -- Rotate flashlight to always point where camera faces
    RunService.RenderStepped:Connect(function()
        if not flashlightOn then return end
        local char = localPlayer.Character
        if not char then return end
        local head = char:FindFirstChild("Head")
        if not head or not spotLight then return end
        -- Face direction = camera look vector projected onto character
        local cam = workspace.CurrentCamera
        if cam then
            -- The SpotLight faces the Part's Face (Front) automatically
            -- We rotate Head to look in camera direction only on Y axis
            -- (Movement controller handles walk direction; flashlight just uses head orientation)
        end
    end)

    print("[FlashlightController] F key flashlight initialized (SpotLight on Head).")
end

return FlashlightController

