--!strict
-- HUDController for THE LAST FLOOR – VACCINE PROTOCOL
-- Manages compact top-right timer, HP & Stamina bars in bottom-left.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HUDController = {}
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local remotes = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
local floorTimerRemote = remotes:WaitForChild("FloorTimerUpdate") :: RemoteEvent

local hpFill: Frame? = nil
local staminaFill: Frame? = nil

function HUDController.SetStamina(percent: number)
    if staminaFill then
        staminaFill.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
    end
end

function HUDController.Init()
    local existing = playerGui:FindFirstChild("TheLastFloor_HUD")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TheLastFloor_HUD"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 5
    sg.Parent = playerGui

    -------------------------------------------------------------------------
    -- 1. COMPACT TOP-RIGHT TIMER (160x36 px)
    -------------------------------------------------------------------------
    local timerBox = Instance.new("Frame")
    timerBox.Name = "TopRightTimerBox"
    timerBox.Size = UDim2.new(0, 160, 0, 36)
    timerBox.Position = UDim2.new(1, -180, 0, 20)
    timerBox.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    timerBox.BackgroundTransparency = 0.25

    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 6)
    c1.Parent = timerBox

    local s1 = Instance.new("UIStroke")
    s1.Color = Color3.fromRGB(60, 68, 80)
    s1.Thickness = 1.2
    s1.Parent = timerBox

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(1, 0, 1, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "02:00"
    timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    timerLabel.Font = Enum.Font.GothamBlack
    timerLabel.TextSize = 18
    timerLabel.Parent = timerBox
    timerBox.Parent = sg

    floorTimerRemote.OnClientEvent:Connect(function(secondsRemaining: number)
        local mins = math.floor(secondsRemaining / 60)
        local secs = secondsRemaining % 60
        timerLabel.Text = string.format("%02d:%02d", mins, secs)
        timerLabel.TextColor3 = secondsRemaining <= 30
            and Color3.fromRGB(255, 30, 30)
            or  Color3.fromRGB(255, 80, 80)
    end)

    -------------------------------------------------------------------------
    -- 2. BOTTOM-LEFT STATUS HUD: HP (white) + STM (orange)
    -------------------------------------------------------------------------
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusHUD"
    statusFrame.Size = UDim2.new(0, 220, 0, 60)
    statusFrame.Position = UDim2.new(0, 20, 1, -80)
    statusFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    statusFrame.BackgroundTransparency = 0.3

    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(0, 6)
    c2.Parent = statusFrame

    local s2 = Instance.new("UIStroke")
    s2.Color = Color3.fromRGB(50, 55, 65)
    s2.Thickness = 1.2
    s2.Parent = statusFrame

    -- HP
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Size = UDim2.new(0, 36, 0, 20)
    hpLabel.Position = UDim2.new(0, 10, 0, 7)
    hpLabel.BackgroundTransparency = 1
    hpLabel.Text = "HP"
    hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpLabel.Font = Enum.Font.GothamBold
    hpLabel.TextSize = 13
    hpLabel.TextXAlignment = Enum.TextXAlignment.Left
    hpLabel.Parent = statusFrame

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0, 160, 0, 8)
    hpBg.Position = UDim2.new(0, 50, 0, 13)
    hpBg.BackgroundColor3 = Color3.fromRGB(35, 40, 48)
    local c3 = Instance.new("UICorner")
    c3.CornerRadius = UDim.new(0, 4)
    c3.Parent = hpBg

    hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    local c4 = Instance.new("UICorner")
    c4.CornerRadius = UDim.new(0, 4)
    c4.Parent = hpFill
    hpFill.Parent = hpBg
    hpBg.Parent = statusFrame

    -- STM
    local stmLabel = Instance.new("TextLabel")
    stmLabel.Size = UDim2.new(0, 36, 0, 20)
    stmLabel.Position = UDim2.new(0, 10, 0, 32)
    stmLabel.BackgroundTransparency = 1
    stmLabel.Text = "STM"
    stmLabel.TextColor3 = Color3.fromRGB(255, 140, 20)
    stmLabel.Font = Enum.Font.GothamBold
    stmLabel.TextSize = 13
    stmLabel.TextXAlignment = Enum.TextXAlignment.Left
    stmLabel.Parent = statusFrame

    local stmBg = Instance.new("Frame")
    stmBg.Size = UDim2.new(0, 160, 0, 8)
    stmBg.Position = UDim2.new(0, 50, 0, 38)
    stmBg.BackgroundColor3 = Color3.fromRGB(35, 40, 48)
    local c5 = Instance.new("UICorner")
    c5.CornerRadius = UDim.new(0, 4)
    c5.Parent = stmBg

    staminaFill = Instance.new("Frame")
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
    local c6 = Instance.new("UICorner")
    c6.CornerRadius = UDim.new(0, 4)
    c6.Parent = staminaFill
    staminaFill.Parent = stmBg
    stmBg.Parent = statusFrame
    statusFrame.Parent = sg

    local function hookHealth(humanoid: Humanoid)
        humanoid.HealthChanged:Connect(function(hp)
            local pct = math.clamp(hp / humanoid.MaxHealth, 0, 1)
            if hpFill then
                TweenService:Create(hpFill, TweenInfo.new(0.2), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
            end
        end)
    end

    if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
        hookHealth(localPlayer.Character.Humanoid :: Humanoid)
    end
    localPlayer.CharacterAdded:Connect(function(char)
        hookHealth(char:WaitForChild("Humanoid") :: Humanoid)
    end)

    print("[HUDController] Clean HUD initialized.")
end

return HUDController
