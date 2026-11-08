-- HUDController for THE LAST FLOOR – VACCINE PROTOCOL
-- Compact top-right timer | Bottom-left HP (white) + STM (orange) bars | Keypad modal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HUDController = {}
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
local floorTimerRemote = remotes:WaitForChild("FloorTimerUpdate")
local submitKeypadFunc = remotes:WaitForChild("SubmitKeypadCode")

local hpFill = nil
local staminaFill = nil

function HUDController.SetStamina(percent)
    if staminaFill then
        staminaFill.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
    end
end

function HUDController.Init()
    -- Guard: destroy any duplicate HUD from a previous spawn
    local existing = playerGui:FindFirstChild("TheLastFloor_HUD")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TheLastFloor_HUD"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 5
    sg.Parent = playerGui

    -------------------------------------------------------------------------
    -- 1. COMPACT TOP-RIGHT TIMER (160×36 px, no objective text)
    -------------------------------------------------------------------------
    local timerBox = Instance.new("Frame")
    timerBox.Name = "TopRightTimerBox"
    timerBox.Size = UDim2.new(0, 160, 0, 36)
    timerBox.Position = UDim2.new(1, -180, 0, 20)
    timerBox.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    timerBox.BackgroundTransparency = 0.25
    local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 6) c1.Parent = timerBox
    local s1 = Instance.new("UIStroke") s1.Color = Color3.fromRGB(60, 68, 80) s1.Thickness = 1.2 s1.Parent = timerBox

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

    floorTimerRemote.OnClientEvent:Connect(function(secondsRemaining)
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
    local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0, 6) c2.Parent = statusFrame
    local s2 = Instance.new("UIStroke") s2.Color = Color3.fromRGB(50, 55, 65) s2.Thickness = 1.2 s2.Parent = statusFrame

    -- HP row
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
    local c3 = Instance.new("UICorner") c3.CornerRadius = UDim.new(0, 4) c3.Parent = hpBg

    hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    local c4 = Instance.new("UICorner") c4.CornerRadius = UDim.new(0, 4) c4.Parent = hpFill
    hpFill.Parent = hpBg
    hpBg.Parent = statusFrame

    -- STM row
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
    local c5 = Instance.new("UICorner") c5.CornerRadius = UDim.new(0, 4) c5.Parent = stmBg

    staminaFill = Instance.new("Frame")
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
    local c6 = Instance.new("UICorner") c6.CornerRadius = UDim.new(0, 4) c6.Parent = staminaFill
    staminaFill.Parent = stmBg
    stmBg.Parent = statusFrame
    statusFrame.Parent = sg

    local function hookHealth(humanoid)
        humanoid.HealthChanged:Connect(function(hp)
            local pct = math.clamp(hp / humanoid.MaxHealth, 0, 1)
            if hpFill then
                TweenService:Create(hpFill, TweenInfo.new(0.2), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
            end
        end)
    end
    if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
        hookHealth(localPlayer.Character.Humanoid)
    end
    localPlayer.CharacterAdded:Connect(function(char)
        hookHealth(char:WaitForChild("Humanoid"))
    end)

    -------------------------------------------------------------------------
    -- 3. KEYPAD MODAL (hidden until ProximityPrompt triggered)
    -------------------------------------------------------------------------
    local kpModal = Instance.new("Frame")
    kpModal.Name = "KeypadModal"
    kpModal.Size = UDim2.new(0, 320, 0, 440)
    kpModal.Position = UDim2.new(0.5, -160, 0.5, -220)
    kpModal.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    kpModal.Visible = false
    local ckp = Instance.new("UICorner") ckp.CornerRadius = UDim.new(0, 10) ckp.Parent = kpModal
    local skp = Instance.new("UIStroke") skp.Color = Color3.fromRGB(70, 78, 90) skp.Thickness = 2 skp.Parent = kpModal
    kpModal.Parent = sg

    local kpTitle = Instance.new("TextLabel")
    kpTitle.Size = UDim2.new(1, 0, 0, 40)
    kpTitle.Position = UDim2.new(0, 0, 0, 10)
    kpTitle.BackgroundTransparency = 1
    kpTitle.Text = "ELEVATOR OVERRIDE KEYPAD"
    kpTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
    kpTitle.Font = Enum.Font.GothamBold
    kpTitle.TextSize = 16
    kpTitle.Parent = kpModal

    local dispBox = Instance.new("Frame")
    dispBox.Size = UDim2.new(0.85, 0, 0, 50)
    dispBox.Position = UDim2.new(0.075, 0, 0, 55)
    dispBox.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    local cdisp = Instance.new("UICorner") cdisp.CornerRadius = UDim.new(0, 6) cdisp.Parent = dispBox
    dispBox.Parent = kpModal

    local pinLbl = Instance.new("TextLabel")
    pinLbl.Size = UDim2.new(1, 0, 1, 0)
    pinLbl.BackgroundTransparency = 1
    pinLbl.Text = "----"
    pinLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    pinLbl.Font = Enum.Font.Code
    pinLbl.TextSize = 28
    pinLbl.Parent = dispBox

    local enteredPIN = ""
    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(0.85, 0, 0, 240)
    grid.Position = UDim2.new(0.075, 0, 0, 120)
    grid.BackgroundTransparency = 1
    grid.Parent = kpModal
    local gl = Instance.new("UIGridLayout")
    gl.CellPadding = UDim2.new(0, 8, 0, 8)
    gl.CellSize = UDim2.new(0.3, 0, 0.22, 0)
    gl.Parent = grid

    for _, bt in ipairs({"1","2","3","4","5","6","7","8","9","CLR","0","OK"}) do
        local b = Instance.new("TextButton")
        b.Text = bt
        b.TextColor3 = Color3.fromRGB(240, 245, 255)
        b.BackgroundColor3 = bt=="OK" and Color3.fromRGB(38,120,55) or (bt=="CLR" and Color3.fromRGB(140,40,40) or Color3.fromRGB(28,34,44))
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        local cb = Instance.new("UICorner") cb.CornerRadius = UDim.new(0, 6) cb.Parent = b
        b.Parent = grid
        b.Activated:Connect(function()
            if bt == "CLR" then
                enteredPIN = ""
                pinLbl.Text = "----"
                pinLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
            elseif bt == "OK" then
                if #enteredPIN == 4 then
                    pinLbl.Text = "CHECKING..."
                    local ok, _ = submitKeypadFunc:InvokeServer(enteredPIN)
                    if ok then
                        pinLbl.Text = "UNLOCKED!"
                        pinLbl.TextColor3 = Color3.fromRGB(50, 255, 80)
                        task.delay(1.2, function()
                            kpModal.Visible = false
                            enteredPIN = ""
                            pinLbl.Text = "----"
                        end)
                    else
                        pinLbl.Text = "DENIED!"
                        pinLbl.TextColor3 = Color3.fromRGB(255, 40, 40)
                        task.delay(1.2, function()
                            enteredPIN = ""
                            pinLbl.Text = "----"
                            pinLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
                        end)
                    end
                end
            else
                if #enteredPIN < 4 then
                    enteredPIN = enteredPIN .. bt
                    pinLbl.Text = enteredPIN
                end
            end
        end)
    end

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0.85, 0, 0, 36)
    closeBtn.Position = UDim2.new(0.075, 0, 1, -48)
    closeBtn.Text = "CANCEL / CLOSE"
    closeBtn.TextColor3 = Color3.fromRGB(180, 185, 195)
    closeBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = closeBtn
    closeBtn.Parent = kpModal
    closeBtn.Activated:Connect(function() kpModal.Visible = false end)

    task.spawn(function()
        local b1 = Workspace:WaitForChild("TheLastFloor"):WaitForChild("Basement_B1")
        local kpp = b1:WaitForChild("ElevatorKeypad")
        local prompt = kpp:WaitForChild("KeypadPrompt")
        prompt.Triggered:Connect(function()
            kpModal.Visible = true
            enteredPIN = ""
            pinLbl.Text = "----"
            pinLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
        end)
    end)

    print("[HUDController] HUD initialized: compact timer top-right, HP + STM bars bottom-left.")
end

return HUDController
