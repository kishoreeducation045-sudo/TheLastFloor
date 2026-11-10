--!strict
-- Client Bootstrap for THE LAST FLOOR – VACCINE PROTOCOL

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
print(string.format("[ClientInit] Initializing client subsystems for %s...", localPlayer.Name))

local controllersFolder = script.Parent:WaitForChild("Controllers")

-- Boot order matters: HUD first, then inventory, flashlight, generator, movement
local bootOrder = {
    "HUDController",
    "InventoryController",
    "FlashlightController",
    "GeneratorController",
    "MovementController",
}

for _, modName in ipairs(bootOrder) do
    local mod = controllersFolder:FindFirstChild(modName)
    if mod and mod:IsA("ModuleScript") then
        local success, result = pcall(function()
            local module = require(mod) :: any
            if type(module) == "table" and type(module.Init) == "function" then
                module.Init()
            end
        end)
        if not success then
            warn(string.format("[ClientInit] Failed to initialize controller %s: %s", modName, tostring(result)))
        end
    else
        warn(string.format("[ClientInit] Controller %s not found in Controllers folder", modName))
    end
end

-- Atmospheric spawn hint with typewriter effect
task.spawn(function()
    local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
    task.wait(1.5)

    local sg = Instance.new("ScreenGui")
    sg.Name = "SpawnHint"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 15
    sg.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 440, 0, 52)
    frame.Position = UDim2.new(0.5, -220, 0.5, -26)
    frame.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
    frame.BackgroundTransparency = 0.2

    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
    local fs = Instance.new("UIStroke") fs.Color = Color3.fromRGB(80, 88, 105) fs.Thickness = 1.5 fs.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = ""
    lbl.TextColor3 = Color3.fromRGB(230, 230, 225)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 15
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = frame
    frame.Parent = sg

    local msg = "Check the elevator — generator must be running."
    for i = 1, #msg do
        lbl.Text = string.sub(msg, 1, i)
        task.wait(0.045)
    end

    task.wait(2.0)

    TweenService:Create(frame, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(lbl, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
    task.wait(0.9)
    sg:Destroy()
end)

print("[ClientInit] All client subsystems initialized.")
