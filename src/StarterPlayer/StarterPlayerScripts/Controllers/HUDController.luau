--!strict
-- HUDController for THE LAST FLOOR – VACCINE PROTOCOL
-- Manages atmospheric Survival HUD: Floor & Objective Checklist, Interaction Hint, Alerts, Timer, HP, Stamina, and Transitions.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local Workspace         = game:GetService("Workspace")

local HUDController = {}
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local remotes            = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
local floorStateRemote   = remotes:WaitForChild("FloorStateChanged") :: RemoteEvent
local floorTimerRemote   = remotes:WaitForChild("FloorTimerUpdate") :: RemoteEvent
local puzzleStateRemote  = remotes:WaitForChild("PuzzleStateChanged") :: RemoteEvent

local hpFill: Frame? = nil
local staminaFill: Frame? = nil

function HUDController.SetStamina(percent: number)
    if staminaFill then
        staminaFill.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
    end
end

local function playUiSound(soundId: string, volume: number, speed: number)
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = soundId
        s.Volume = volume
        s.PlaybackSpeed = speed
        s.PlayOnRemove = true
        s.Parent = SoundService
        s:Destroy()
    end)
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
    -- 1. SCREEN VIGNETTE OVERLAY (For Crawler Surge & Warnings)
    -------------------------------------------------------------------------
    local vignetteFrame = Instance.new("Frame")
    vignetteFrame.Name = "SurgeVignette"
    vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
    vignetteFrame.BackgroundColor3 = Color3.fromRGB(160, 15, 15)
    vignetteFrame.BackgroundTransparency = 1
    vignetteFrame.BorderSizePixel = 0
    vignetteFrame.ZIndex = 1
    vignetteFrame.Parent = sg

    -------------------------------------------------------------------------
    -- 2. COMPACT TOP-RIGHT TIMER
    -------------------------------------------------------------------------
    local timerBox = Instance.new("Frame")
    timerBox.Name = "TopRightTimerBox"
    timerBox.Size = UDim2.new(0, 160, 0, 40)
    timerBox.Position = UDim2.new(1, -180, 0, 18)
    timerBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
    timerBox.BackgroundTransparency = 0.22
    local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 6) c1.Parent = timerBox
    local s1 = Instance.new("UIStroke") s1.Color = Color3.fromRGB(65, 72, 85) s1.Thickness = 1.2 s1.Parent = timerBox

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(1, 0, 1, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "02:00"
    timerLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
    timerLabel.Font = Enum.Font.GothamBlack
    timerLabel.TextSize = 20
    timerLabel.Parent = timerBox
    timerBox.Parent = sg

    floorTimerRemote.OnClientEvent:Connect(function(secondsRemaining: number)
        local mins = math.floor(secondsRemaining / 60)
        local secs = secondsRemaining % 60
        timerLabel.Text = string.format("%02d:%02d", mins, secs)
        timerLabel.TextColor3 = secondsRemaining <= 30
            and Color3.fromRGB(255, 35, 35)
            or  Color3.fromRGB(255, 90, 90)
    end)

    -------------------------------------------------------------------------
    -- 3. TOP-LEFT FLOOR & 4-OBJECTIVE CHECKLIST CARD
    -------------------------------------------------------------------------
    local objCard = Instance.new("Frame")
    objCard.Name = "ObjectivesCard"
    objCard.Size = UDim2.new(0, 355, 0, 174)
    objCard.Position = UDim2.new(0, 18, 0, 18)
    objCard.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
    objCard.BackgroundTransparency = 0.24
    local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(0, 8) oc.Parent = objCard
    local objStroke = Instance.new("UIStroke") objStroke.Color = Color3.fromRGB(58, 65, 78) objStroke.Thickness = 1.2 objStroke.Parent = objCard
    objCard.Parent = sg

    local floorHeader = Instance.new("TextLabel")
    floorHeader.Name = "FloorHeader"
    floorHeader.Size = UDim2.new(1, -20, 0, 22)
    floorHeader.Position = UDim2.new(0, 10, 0, 6)
    floorHeader.BackgroundTransparency = 1
    floorHeader.Text = "B1  •  BASEMENT PARKING & LIFT"
    floorHeader.TextColor3 = Color3.fromRGB(245, 190, 55)
    floorHeader.Font = Enum.Font.GothamBlack
    floorHeader.TextSize = 12
    floorHeader.TextXAlignment = Enum.TextXAlignment.Left
    floorHeader.Parent = objCard

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -20, 0, 1)
    divider.Position = UDim2.new(0, 10, 0, 30)
    divider.BackgroundColor3 = Color3.fromRGB(55, 62, 74)
    divider.BorderSizePixel = 0
    divider.Parent = objCard

    local OBJECTIVE_TEXTS = {
        "OBJECTIVE 1: REMOVE THE JAMMED BEAM",
        "OBJECTIVE 2: RESTORE GENERATOR POWER",
        "OBJECTIVE 3: CALL THE ELEVATOR",
        "OBJECTIVE 4: SURVIVE AND BOARD",
    }
    local objLabels: { TextLabel } = {}
    for idx, text in ipairs(OBJECTIVE_TEXTS) do
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Objective_" .. idx
        lbl.Size = UDim2.new(1, -20, 0, 20)
        lbl.Position = UDim2.new(0, 10, 0, 34 + ((idx - 1) * 22))
        lbl.BackgroundTransparency = 1
        lbl.Text = "○  " .. text
        lbl.TextColor3 = Color3.fromRGB(165, 175, 190)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = objCard
        objLabels[idx] = lbl
    end

    local hintBox = Instance.new("Frame")
    hintBox.Size = UDim2.new(1, -20, 0, 38)
    hintBox.Position = UDim2.new(0, 10, 1, -44)
    hintBox.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
    hintBox.BackgroundTransparency = 0.2
    local hc = Instance.new("UICorner") hc.CornerRadius = UDim.new(0, 5) hc.Parent = hintBox
    hintBox.Parent = objCard

    local hintLabel = Instance.new("TextLabel")
    hintLabel.Name = "HintLabel"
    hintLabel.Size = UDim2.new(1, -12, 1, 0)
    hintLabel.Position = UDim2.new(0, 6, 0, 0)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = "Grab Crowbar at Workbench [Hold E 2s] or bypass Generator [E]."
    hintLabel.TextColor3 = Color3.fromRGB(185, 220, 255)
    hintLabel.Font = Enum.Font.GothamMedium
    hintLabel.TextSize = 10
    hintLabel.TextWrapped = true
    hintLabel.TextXAlignment = Enum.TextXAlignment.Left
    hintLabel.Parent = hintBox

    -------------------------------------------------------------------------
    -- 4. TOP-CENTER URGENT ALERT & PRY PROGRESS BAR
    -------------------------------------------------------------------------
    local alertBanner = Instance.new("Frame")
    alertBanner.Name = "AlertBanner"
    alertBanner.Size = UDim2.new(0, 480, 0, 44)
    alertBanner.Position = UDim2.new(0.5, -240, 0, 18)
    alertBanner.BackgroundColor3 = Color3.fromRGB(18, 12, 14)
    alertBanner.BackgroundTransparency = 0.15
    alertBanner.Visible = false
    local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0, 8) ac.Parent = alertBanner
    local as = Instance.new("UIStroke") as.Color = Color3.fromRGB(255, 165, 50) as.Thickness = 1.6 as.Parent = alertBanner
    alertBanner.Parent = sg

    local alertLbl = Instance.new("TextLabel")
    alertLbl.Size = UDim2.new(1, -20, 1, 0)
    alertLbl.Position = UDim2.new(0, 10, 0, 0)
    alertLbl.BackgroundTransparency = 1
    alertLbl.Text = ""
    alertLbl.TextColor3 = Color3.fromRGB(255, 210, 90)
    alertLbl.Font = Enum.Font.GothamBlack
    alertLbl.TextSize = 13
    alertLbl.TextWrapped = true
    alertLbl.Parent = alertBanner

    local alertVersion = 0
    local function showAlert(text: string, color: Color3?, duration: number?)
        alertVersion += 1
        local myVer = alertVersion
        local col = color or Color3.fromRGB(255, 200, 70)
        alertLbl.Text = text
        alertLbl.TextColor3 = col
        as.Color = col
        alertBanner.Visible = true
        task.delay(duration or 4.0, function()
            if alertVersion == myVer then
                alertBanner.Visible = false
            end
        end)
    end

    -- Pry Progress Bar (bottom-center above hotbar)
    local pryFrame = Instance.new("Frame")
    pryFrame.Name = "PryProgressFrame"
    pryFrame.Size = UDim2.new(0, 280, 0, 32)
    pryFrame.Position = UDim2.new(0.5, -140, 1, -138)
    pryFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
    pryFrame.BackgroundTransparency = 0.15
    pryFrame.Visible = false
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 6) pc.Parent = pryFrame
    local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(255, 185, 55) ps.Thickness = 1.5 ps.Parent = pryFrame
    pryFrame.Parent = sg

    local pryText = Instance.new("TextLabel")
    pryText.Size = UDim2.new(1, 0, 0, 16)
    pryText.Position = UDim2.new(0, 0, 0, 2)
    pryText.BackgroundTransparency = 1
    pryText.Text = "PRYING JAMMED ELEVATOR BEAM..."
    pryText.TextColor3 = Color3.fromRGB(255, 220, 120)
    pryText.Font = Enum.Font.GothamBold
    pryText.TextSize = 10
    pryText.Parent = pryFrame

    local pryBarBg = Instance.new("Frame")
    pryBarBg.Size = UDim2.new(1, -20, 0, 6)
    pryBarBg.Position = UDim2.new(0, 10, 1, -10)
    pryBarBg.BackgroundColor3 = Color3.fromRGB(35, 40, 48)
    local pbc = Instance.new("UICorner") pbc.CornerRadius = UDim.new(0, 3) pbc.Parent = pryBarBg
    pryBarBg.Parent = pryFrame

    local pryBarFill = Instance.new("Frame")
    pryBarFill.Size = UDim2.new(0, 0, 1, 0)
    pryBarFill.BackgroundColor3 = Color3.fromRGB(255, 195, 50)
    local pfc = Instance.new("UICorner") pfc.CornerRadius = UDim.new(0, 3) pfc.Parent = pryBarFill
    pryBarFill.Parent = pryBarBg

    -------------------------------------------------------------------------
    -- 5. BOTTOM-LEFT STATUS HUD: HP (white) + STM (orange)
    -------------------------------------------------------------------------
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusHUD"
    statusFrame.Size = UDim2.new(0, 220, 0, 60)
    statusFrame.Position = UDim2.new(0, 20, 1, -80)
    statusFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    statusFrame.BackgroundTransparency = 0.25
    local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0, 6) c2.Parent = statusFrame
    local s2 = Instance.new("UIStroke") s2.Color = Color3.fromRGB(50, 55, 65) s2.Thickness = 1.2 s2.Parent = statusFrame

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

    -------------------------------------------------------------------------
    -- 6. ASCENDING FLOOR TRANSITION CURTAIN
    -------------------------------------------------------------------------
    local transitionScreen = Instance.new("Frame")
    transitionScreen.Name = "TransitionOverlay"
    transitionScreen.Size = UDim2.new(1, 0, 1, 0)
    transitionScreen.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
    transitionScreen.BackgroundTransparency = 1
    transitionScreen.Visible = false
    transitionScreen.ZIndex = 20
    transitionScreen.Parent = sg

    local transitionTitle = Instance.new("TextLabel")
    transitionTitle.Size = UDim2.new(1, -80, 0, 40)
    transitionTitle.Position = UDim2.new(0, 40, 0.45, -20)
    transitionTitle.BackgroundTransparency = 1
    transitionTitle.Text = "ASCENDING TO FLOOR 1: THE INFECTED RESIDENTS"
    transitionTitle.TextColor3 = Color3.fromRGB(235, 245, 255)
    transitionTitle.TextTransparency = 1
    transitionTitle.Font = Enum.Font.GothamBlack
    transitionTitle.TextSize = 24
    transitionTitle.ZIndex = 21
    transitionTitle.Parent = transitionScreen

    local transitionSub = Instance.new("TextLabel")
    transitionSub.Size = UDim2.new(1, -80, 0, 26)
    transitionSub.Position = UDim2.new(0, 40, 0.45, 26)
    transitionSub.BackgroundTransparency = 1
    transitionSub.Text = "BASEMENT B1 ESCAPED — CHECKPOINT SAVED"
    transitionSub.TextColor3 = Color3.fromRGB(95, 240, 140)
    transitionSub.TextTransparency = 1
    transitionSub.Font = Enum.Font.GothamBold
    transitionSub.TextSize = 14
    transitionSub.ZIndex = 21
    transitionSub.Parent = transitionScreen

    -------------------------------------------------------------------------
    -- 7. REMOTE EVENT HOOKS (Puzzle, Floor, Combat, Cinematics)
    -------------------------------------------------------------------------
    floorStateRemote.OnClientEvent:Connect(function(id, name, code, _dur, _desc)
        floorHeader.Text = string.format("%s  •  %s", tostring(code or "B1"), string.upper(tostring(name or "BASEMENT")))
    end)

    puzzleStateRemote.OnClientEvent:Connect(function(payload)
        if typeof(payload) ~= "table" then return end
        if payload.floorCode and payload.floorName then
            floorHeader.Text = string.format("%s  •  %s", tostring(payload.floorCode), string.upper(tostring(payload.floorName)))
        end

        local states = {
            { done = payload.obj1Done == true, active = not payload.obj1Done },
            { done = payload.obj2Done == true, active = not payload.obj2Done },
            { done = payload.obj3Done == true, active = (payload.obj1Done and payload.obj2Done and not payload.obj3Done) },
            { done = payload.obj4Done == true, active = (payload.obj3Done and not payload.obj4Done) },
        }

        for i = 1, 4 do
            local lbl = objLabels[i]
            local st = states[i]
            if st.done then
                lbl.Text = "✔  " .. OBJECTIVE_TEXTS[i]
                lbl.TextColor3 = Color3.fromRGB(85, 225, 125)
            elseif st.active then
                lbl.Text = "▶  " .. OBJECTIVE_TEXTS[i]
                lbl.TextColor3 = Color3.fromRGB(255, 225, 130)
            else
                lbl.Text = "○  " .. OBJECTIVE_TEXTS[i]
                lbl.TextColor3 = Color3.fromRGB(115, 122, 135)
            end
        end

        if typeof(payload.hint) == "string" then
            hintLabel.Text = payload.hint
        end
        if typeof(payload.alert) == "string" and #payload.alert > 0 then
            showAlert(payload.alert, payload.alertColor, 4.0)
        end
    end)

    local crowbarPryState = remotes:FindFirstChild("CrowbarPryState") :: RemoteEvent?
    if crowbarPryState then
        crowbarPryState.OnClientEvent:Connect(function(action: string, dur: number)
            if action == "MissingCrowbar" then
                showAlert("CROWBAR REQUIRED — Hold [E] for 2s at the Workbench beside the lift!", Color3.fromRGB(255, 95, 75), 3.2)
            elseif action == "StartPry" then
                pryBarFill.Size = UDim2.new(0, 0, 1, 0)
                pryFrame.Visible = true
                TweenService:Create(pryBarFill, TweenInfo.new(dur or 3.0, Enum.EasingStyle.Linear), {
                    Size = UDim2.new(1, 0, 1, 0)
                }):Play()
                task.delay(dur or 3.0, function()
                    pryFrame.Visible = false
                end)
            end
        end)
    end

    local elimRemote = remotes:FindFirstChild("PlayerEliminated") :: RemoteEvent?
    if elimRemote then
        elimRemote.OnClientEvent:Connect(function(targetPlayer: Player, isFreeReturn: boolean?, delaySec: number?)
            if targetPlayer == localPlayer then
                if isFreeReturn then
                    showAlert(string.format("DOWNED OUT — FREE CHECKPOINT RETURN IN %.0fs!", delaySec or 5), Color3.fromRGB(255, 185, 65), delaySec or 5)
                else
                    showAlert("ELIMINATED — ENTERING SPECTATOR MODE", Color3.fromRGB(255, 50, 50), 5.0)
                end
            elseif isFreeReturn then
                showAlert(string.format("%s returning at checkpoint in %.0fs...", targetPlayer.DisplayName, delaySec or 5), Color3.fromRGB(255, 190, 90), 3.5)
            end
        end)
    end

    local elevWarnRemote = remotes:FindFirstChild("ElevatorWarning") :: RemoteEvent?
    if elevWarnRemote then
        elevWarnRemote.OnClientEvent:Connect(function(duration: number, msg: string)
            showAlert(msg or "⚠ LIFT NOISE ALERTED THE INFECTED!", Color3.fromRGB(255, 60, 60), duration + 1)
            playUiSound("rbxassetid://9069609200", 0.5, 1.15)
            task.spawn(function()
                for i = 1, 6 do
                    vignetteFrame.BackgroundTransparency = (i % 2 == 1) and 0.65 or 0.92
                    task.wait((duration or 3.0) / 6)
                end
                TweenService:Create(vignetteFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            end)
        end)
    end

    local crawlerRevealRemote = remotes:FindFirstChild("CrawlerEncounterTriggered") :: RemoteEvent?
    if crawlerRevealRemote then
        crawlerRevealRemote.OnClientEvent:Connect(function(crawlerModel: Model?, revealDur: number)
            if not crawlerModel then return end
            local cam = Workspace.CurrentCamera
            local targetPart = crawlerModel.PrimaryPart or crawlerModel:FindFirstChild("Head") :: BasePart?
            if not cam or not targetPart then return end

            playUiSound("rbxassetid://9069609200", 0.7, 1.4)
            local origType = cam.CameraType
            local origCF = cam.CFrame
            cam.CameraType = Enum.CameraType.Scriptable

            local lookFrom = targetPart.Position + (targetPart.CFrame.LookVector * 12) + Vector3.new(0, 3.5, 0)
            local lookGoal = CFrame.lookAt(lookFrom, targetPart.Position + Vector3.new(0, 0.5, 0))
            TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = lookGoal }):Play()

            task.delay((revealDur or 2.2) - 0.5, function()
                local tBack = TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = origCF })
                tBack:Play()
                tBack.Completed:Wait()
                cam.CameraType = origType
            end)
        end)
    end

    local ascendRemote = remotes:FindFirstChild("ElevatorAscending") :: RemoteEvent?
    if ascendRemote then
        ascendRemote.OnClientEvent:Connect(function(duration: number, headline: string)
            transitionTitle.Text = headline or "ASCENDING TO FLOOR 1: THE INFECTED RESIDENTS"
            transitionScreen.Visible = true
            transitionScreen.BackgroundTransparency = 1
            transitionTitle.TextTransparency = 1
            transitionSub.TextTransparency = 1

            -- Camera rumble then clean fade-in curtain
            task.spawn(function()
                local cam = Workspace.CurrentCamera
                local startT = os.clock()
                while os.clock() - startT < 1.2 do
                    if cam then
                        cam.CFrame = cam.CFrame * CFrame.new((math.random()-0.5)*0.12, (math.random()-0.5)*0.12, 0)
                    end
                    task.wait(0.03)
                end
            end)

            task.delay(0.8, function()
                TweenService:Create(transitionScreen, TweenInfo.new(1.0), { BackgroundTransparency = 0.08 }):Play()
                TweenService:Create(transitionTitle, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
                TweenService:Create(transitionSub, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
            end)
        end)
    end

    local function hookHealth(humanoid: Humanoid)
        local function update()
            local pct = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
            if hpFill then
                TweenService:Create(hpFill, TweenInfo.new(0.2), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
            end
        end
        update()
        humanoid.HealthChanged:Connect(update)
    end

    if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
        hookHealth(localPlayer.Character:FindFirstChild("Humanoid") :: Humanoid)
    end
    localPlayer.CharacterAdded:Connect(function(char)
        hookHealth(char:WaitForChild("Humanoid") :: Humanoid)
    end)

    print("[HUDController] Enhanced B1 HUD + Objectives + Cinematics initialized.")
end

return HUDController
