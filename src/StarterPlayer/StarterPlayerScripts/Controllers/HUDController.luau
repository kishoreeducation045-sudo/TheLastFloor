--!strict
-- HUDController for THE LAST FLOOR – VACCINE PROTOCOL
-- Manages top HUD (timer, objective), bottom HUD (health, stamina), and interactive elevator keypad modal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HUDController = {}
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local remotes = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
local floorStateRemote = remotes:WaitForChild("FloorStateChanged") :: RemoteEvent
local floorTimerRemote = remotes:WaitForChild("FloorTimerUpdate") :: RemoteEvent
local submitKeypadFunc = remotes:WaitForChild("SubmitKeypadCode") :: RemoteFunction

function HUDController.Init()
    local sg = Instance.new("ScreenGui")
    sg.Name = "TheLastFloor_HUD"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 5
    sg.Parent = playerGui

    -- TOP HUD: TIMER & OBJECTIVE
    local topFrame = Instance.new("Frame")
    topFrame.Name = "TopHUD"
    topFrame.Size = UDim2.new(0, 440, 0, 75)
    topFrame.Position = UDim2.new(0.5, -220, 0, 15)
    topFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    topFrame.BackgroundTransparency = 0.25
    local cornerTop = Instance.new("UICorner") cornerTop.CornerRadius = UDim.new(0, 8) cornerTop.Parent = topFrame
    local strokeTop = Instance.new("UIStroke") strokeTop.Color = Color3.fromRGB(60, 68, 80) strokeTop.Thickness = 1.5 strokeTop.Parent = topFrame
    topFrame.Parent = sg

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(1, 0, 0.45, 0)
    timerLabel.Position = UDim2.new(0, 0, 0.08, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "TIME REMAINING: 02:00"
    timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    timerLabel.Font = Enum.Font.GothamBlack
    timerLabel.TextSize = 20
    timerLabel.Parent = topFrame

    local objectiveLabel = Instance.new("TextLabel")
    objectiveLabel.Name = "ObjectiveLabel"
    objectiveLabel.Size = UDim2.new(1, -20, 0.4, 0)
    objectiveLabel.Position = UDim2.new(0, 10, 0.52, 0)
    objectiveLabel.BackgroundTransparency = 1
    objectiveLabel.Text = "OBJECTIVE: Solve 4-symbol puzzle & unlock elevator"
    objectiveLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
    objectiveLabel.Font = Enum.Font.GothamSemibold
    objectiveLabel.TextSize = 13
    objectiveLabel.TextWrapped = true
    objectiveLabel.Parent = topFrame

    floorTimerRemote.OnClientEvent:Connect(function(secondsRemaining: number)
        local mins = math.floor(secondsRemaining / 60)
        local secs = secondsRemaining % 60
        timerLabel.Text = string.format("TIME REMAINING: %02d:%02d", mins, secs)
        if secondsRemaining <= 30 then
            timerLabel.TextColor3 = Color3.fromRGB(255, 20, 20)
        else
            timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end)

    floorStateRemote.OnClientEvent:Connect(function(id: number, name: string, code: string, dur: number, desc: string)
        objectiveLabel.Text = "OBJECTIVE: " .. tostring(desc)
    end)

    -- BOTTOM-LEFT HUD: HEALTH
    local hpFrame = Instance.new("Frame")
    hpFrame.Name = "HealthHUD"
    hpFrame.Size = UDim2.new(0, 260, 0, 50)
    hpFrame.Position = UDim2.new(0, 25, 1, -75)
    hpFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    hpFrame.BackgroundTransparency = 0.25
    local cornerHp = Instance.new("UICorner") cornerHp.CornerRadius = UDim.new(0, 6) cornerHp.Parent = hpFrame
    local strokeHp = Instance.new("UIStroke") strokeHp.Color = Color3.fromRGB(50, 55, 65) strokeHp.Thickness = 1.5 strokeHp.Parent = hpFrame
    hpFrame.Parent = sg

    local hpTitle = Instance.new("TextLabel")
    hpTitle.Size = UDim2.new(0.4, 0, 1, 0)
    hpTitle.Position = UDim2.new(0, 12, 0, 0)
    hpTitle.BackgroundTransparency = 1
    hpTitle.Text = "HEALTH"
    hpTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
    hpTitle.Font = Enum.Font.GothamBold
    hpTitle.TextSize = 14
    hpTitle.TextXAlignment = Enum.TextXAlignment.Left
    hpTitle.Parent = hpFrame

    local hpBarBg = Instance.new("Frame")
    hpBarBg.Size = UDim2.new(0.55, 0, 0.35, 0)
    hpBarBg.Position = UDim2.new(0.4, 0, 0.32, 0)
    hpBarBg.BackgroundColor3 = Color3.fromRGB(35, 40, 48)
    local cornerBar = Instance.new("UICorner") cornerBar.CornerRadius = UDim.new(0, 4) cornerBar.Parent = hpBarBg
    hpBarBg.Parent = hpFrame

    local hpFill = Instance.new("Frame")
    hpFill.Name = "Fill"
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
    local cornerFill = Instance.new("UICorner") cornerFill.CornerRadius = UDim.new(0, 4) cornerFill.Parent = hpFill
    hpFill.Parent = hpBarBg

    local function updateHealth(humanoid: Humanoid)
        humanoid.HealthChanged:Connect(function(hp)
            local pct = math.clamp(hp / humanoid.MaxHealth, 0, 1)
            TweenService:Create(hpFill, TweenInfo.new(0.2), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
        end)
    end

    if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
        updateHealth(localPlayer.Character.Humanoid :: Humanoid)
    end
    localPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid") :: Humanoid
        updateHealth(hum)
    end)

    -- INTERACTIVE KEYPAD MODAL
    local kpModal = Instance.new("Frame")
    kpModal.Name = "KeypadModal"
    kpModal.Size = UDim2.new(0, 320, 0, 440)
    kpModal.Position = UDim2.new(0.5, -160, 0.5, -220)
    kpModal.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    kpModal.Visible = false
    local cornerKp = Instance.new("UICorner") cornerKp.CornerRadius = UDim.new(0, 10) cornerKp.Parent = kpModal
    local strokeKp = Instance.new("UIStroke") strokeKp.Color = Color3.fromRGB(70, 78, 90) strokeKp.Thickness = 2 strokeKp.Parent = kpModal
    kpModal.Parent = sg

    local kpTitleLbl = Instance.new("TextLabel")
    kpTitleLbl.Size = UDim2.new(1, 0, 0, 40)
    kpTitleLbl.Position = UDim2.new(0, 0, 0, 10)
    kpTitleLbl.BackgroundTransparency = 1
    kpTitleLbl.Text = "ELEVATOR OVERRIDE KEYPAD"
    kpTitleLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    kpTitleLbl.Font = Enum.Font.GothamBold
    kpTitleLbl.TextSize = 16
    kpTitleLbl.Parent = kpModal

    local displayBox = Instance.new("Frame")
    displayBox.Size = UDim2.new(0.85, 0, 0, 50)
    displayBox.Position = UDim2.new(0.075, 0, 0, 55)
    displayBox.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    local cornerDisp = Instance.new("UICorner") cornerDisp.CornerRadius = UDim.new(0, 6) cornerDisp.Parent = displayBox
    displayBox.Parent = kpModal

    local pinDisplay = Instance.new("TextLabel")
    pinDisplay.Size = UDim2.new(1, 0, 1, 0)
    pinDisplay.BackgroundTransparency = 1
    pinDisplay.Text = "----"
    pinDisplay.TextColor3 = Color3.fromRGB(255, 215, 0)
    pinDisplay.Font = Enum.Font.Code
    pinDisplay.TextSize = 28
    pinDisplay.Parent = displayBox

    local enteredPIN = ""

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(0.85, 0, 0, 240)
    grid.Position = UDim2.new(0.075, 0, 0, 120)
    grid.BackgroundTransparency = 1
    grid.Parent = kpModal

    local uigrid = Instance.new("UIGridLayout")
    uigrid.CellPadding = UDim2.new(0, 8, 0, 8)
    uigrid.CellSize = UDim2.new(0.3, 0, 0.22, 0)
    uigrid.Parent = grid

    local buttons = {"1","2","3","4","5","6","7","8","9","CLR","0","OK"}
    for _, bText in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Text = bText
        btn.TextColor3 = Color3.fromRGB(240, 245, 255)
        btn.BackgroundColor3 = (bText == "OK") and Color3.fromRGB(38, 120, 55) or (bText == "CLR" and Color3.fromRGB(140, 40, 40) or Color3.fromRGB(28, 34, 44))
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        local cornerBtn = Instance.new("UICorner") cornerBtn.CornerRadius = UDim.new(0, 6) cornerBtn.Parent = btn
        btn.Parent = grid

        btn.Activated:Connect(function()
            if bText == "CLR" then
                enteredPIN = ""
                pinDisplay.Text = "----"
                pinDisplay.TextColor3 = Color3.fromRGB(255, 215, 0)
            elseif bText == "OK" then
                if #enteredPIN == 4 then
                    pinDisplay.Text = "CHECKING..."
                    local success, msg = submitKeypadFunc:InvokeServer(enteredPIN)
                    if success then
                        pinDisplay.Text = "UNLOCKED!"
                        pinDisplay.TextColor3 = Color3.fromRGB(50, 255, 80)
                        task.delay(1.2, function()
                            kpModal.Visible = false
                            enteredPIN = ""
                            pinDisplay.Text = "----"
                        end)
                    else
                        pinDisplay.Text = "DENIED!"
                        pinDisplay.TextColor3 = Color3.fromRGB(255, 40, 40)
                        task.delay(1.2, function()
                            enteredPIN = ""
                            pinDisplay.Text = "----"
                            pinDisplay.TextColor3 = Color3.fromRGB(255, 215, 0)
                        end)
                    end
                end
            else
                if #enteredPIN < 4 then
                    enteredPIN = enteredPIN .. bText
                    pinDisplay.Text = enteredPIN
                end
            end
        end)
    end

    local closeKpBtn = Instance.new("TextButton")
    closeKpBtn.Size = UDim2.new(0.85, 0, 0, 36)
    closeKpBtn.Position = UDim2.new(0.075, 0, 1, -48)
    closeKpBtn.Text = "CANCEL / CLOSE"
    closeKpBtn.TextColor3 = Color3.fromRGB(180, 185, 195)
    closeKpBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
    closeKpBtn.Font = Enum.Font.GothamBold
    closeKpBtn.TextSize = 13
    local cornerClose = Instance.new("UICorner") cornerClose.CornerRadius = UDim.new(0, 6) cornerClose.Parent = closeKpBtn
    closeKpBtn.Parent = kpModal
    closeKpBtn.Activated:Connect(function() kpModal.Visible = false end)

    task.spawn(function()
        local tlfWS = Workspace:WaitForChild("TheLastFloor")
        local b1 = tlfWS:WaitForChild("Basement_B1")
        local kpPart = b1:WaitForChild("ElevatorKeypad")
        local prompt = kpPart:WaitForChild("KeypadPrompt") :: ProximityPrompt
        prompt.Triggered:Connect(function()
            kpModal.Visible = true
            enteredPIN = ""
            pinDisplay.Text = "----"
            pinDisplay.TextColor3 = Color3.fromRGB(255, 215, 0)
        end)
    end)

    print("[HUDController] HUD, timer, health and interactive keypad initialized.")
end

return HUDController

