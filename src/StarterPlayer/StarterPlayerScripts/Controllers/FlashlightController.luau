--!strict
-- FlashlightController.luau
-- F key toggles flashlight SpotLight on player's head across respawns.

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local FlashlightController = {}
local localPlayer  = Players.LocalPlayer
local flashlightOn = false
local spotLight: SpotLight? = nil

local function attachSpotlight(character: Model)
    if spotLight then spotLight:Destroy() end
    local head = character:WaitForChild("Head", 5) or character:WaitForChild("HumanoidRootPart", 5)
    if not head then return end

    local sl = Instance.new("SpotLight")
    sl.Name       = "PlayerFlashlight"
    sl.Enabled    = false
    sl.Brightness = 7.5
    sl.Range      = 70
    sl.Angle      = 52
    sl.Color      = Color3.fromRGB(255, 252, 235)
    sl.Face       = Enum.NormalId.Front
    sl.Shadows    = true
    sl.Parent     = head
    spotLight = sl
end

local function setFlashlight(on: boolean)
    flashlightOn = on
    if spotLight then
        spotLight.Enabled = on
    end
end

function FlashlightController.Init()
    if localPlayer.Character then
        attachSpotlight(localPlayer.Character)
    end
    localPlayer.CharacterAdded:Connect(function(char)
        attachSpotlight(char)
        if flashlightOn then setFlashlight(true) end
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F then
            setFlashlight(not flashlightOn)
        end
    end)

    print("[FlashlightController] F key flashlight active.")
end

return FlashlightController
