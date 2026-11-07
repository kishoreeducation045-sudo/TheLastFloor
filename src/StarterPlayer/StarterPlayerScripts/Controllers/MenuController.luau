--!strict
-- Main Menu & Multiplayer Lobby Controller for THE LAST FLOOR – VACCINE PROTOCOL
-- Handles 3D cinematic camera, flickering title, Menu navigation, 1-6 player lobby, solo mode, countdown, and loading screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MenuController = {}
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local camera = Workspace.CurrentCamera :: Camera

local remotesFolder = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
local lobbyStateUpdateRemote = remotesFolder:WaitForChild("LobbyStateUpdate") :: RemoteEvent
local matchStartingRemote = remotesFolder:WaitForChild("MatchStarting") :: RemoteEvent
local lobbyJoinFunction = remotesFolder:WaitForChild("LobbyJoin") :: RemoteFunction
local lobbyLeaveFunction = remotesFolder:WaitForChild("LobbyLeave") :: RemoteFunction
local lobbyStartMatchFunction = remotesFolder:WaitForChild("LobbyStartMatch") :: RemoteFunction

-- State
local screenGui: ScreenGui
local menuContainer: Frame
local lobbyContainer: Frame
local howToPlayModal: Frame
local settingsModal: Frame
local creditsModal: Frame
local countdownOverlay: Frame
local loadingOverlay: Frame
local countdownLabel: TextLabel
local loadingStatusLabel: TextLabel
local loadingFillBar: Frame

local playerCardSlots: { Frame } = {}
local isHost = false
local cameraConn: RBXScriptConnection? = nil

-- Colors & Styles
local COLOR_BG_DARK = Color3.fromRGB(12, 14, 18)
local COLOR_PANEL_BG = Color3.fromRGB(18, 22, 28)
local COLOR_ACCENT_RED = Color3.fromRGB(220, 45, 45)
local COLOR_ACCENT_RED_HOVER = Color3.fromRGB(255, 75, 75)
local COLOR_TEXT_MUTED = Color3.fromRGB(160, 168, 180)
local COLOR_TEXT_LIGHT = Color3.fromRGB(240, 244, 250)
local COLOR_GOLD = Color3.fromRGB(245, 180, 50)

local function createCorner(parent: GuiObject, radius: number?)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

local function createStroke(parent: GuiObject, color: Color3?, thickness: number?)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(50, 55, 65)
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function styleButton(button: TextButton, isPrimary: boolean?)
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamBold
    button.TextSize = 16
    button.TextColor3 = COLOR_TEXT_LIGHT
    button.BackgroundColor3 = isPrimary and COLOR_ACCENT_RED or COLOR_PANEL_BG
    createCorner(button, 8)
    createStroke(button, isPrimary and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(60, 68, 80), 1.5)

    local originalBg = button.BackgroundColor3
    local hoverBg = isPrimary and COLOR_ACCENT_RED_HOVER or Color3.fromRGB(28, 34, 44)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = hoverBg }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = originalBg }):Play()
    end)
end

local function setupCinematicCamera()
    local menuCameraPart = Workspace:FindFirstChild("TheLastFloor") 
        and Workspace.TheLastFloor:FindFirstChild("Lobby") 
        and Workspace.TheLastFloor.Lobby:FindFirstChild("MenuScene")
        and Workspace.TheLastFloor.Lobby.MenuScene:FindFirstChild("MenuCameraPart")

    if menuCameraPart and menuCameraPart:IsA("BasePart") then
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = menuCameraPart.CFrame

        -- Subtle camera sway for eerie immersion
        local t0 = os.clock()
        if cameraConn then cameraConn:Disconnect() end
        cameraConn = RunService.RenderStepped:Connect(function()
            local elapsed = os.clock() - t0
            local swayX = math.sin(elapsed * 0.5) * 0.4
            local swayY = math.cos(elapsed * 0.7) * 0.3
            camera.CFrame = menuCameraPart.CFrame * CFrame.Angles(math.rad(swayY), math.rad(swayX), 0)
        end)
    end
end

local function releaseCamera()
    if cameraConn then
        cameraConn:Disconnect()
        cameraConn = nil
    end
    camera.CameraType = Enum.CameraType.Custom
end

local function buildUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TheLastFloor_MainMenuGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 10
    screenGui.Parent = playerGui

    -- Main Container (Full screen)
    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = UDim2.new(1, 0, 1, 0)
    root.BackgroundTransparency = 1
    root.Parent = screenGui

    -- Subtle dark horror gradient vignette on edges
    local vignette = Instance.new("Frame")
    vignette.Name = "Vignette"
    vignette.Size = UDim2.new(1, 0, 1, 0)
    vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    vignette.BackgroundTransparency = 0.45
    vignette.BorderSizePixel = 0
    vignette.Parent = root

    -------------------------------------------------------------------------
    -- 1. MAIN MENU CONTAINER
    -------------------------------------------------------------------------
    menuContainer = Instance.new("Frame")
    menuContainer.Name = "MenuContainer"
    menuContainer.Size = UDim2.new(1, 0, 1, 0)
    menuContainer.BackgroundTransparency = 1
    menuContainer.Parent = root

    -- Title Section (Top Left)
    local titleFrame = Instance.new("Frame")
    titleFrame.Name = "TitleFrame"
    titleFrame.Size = UDim2.new(0, 480, 0, 140)
    titleFrame.Position = UDim2.new(0.06, 0, 0.1, 0)
    titleFrame.BackgroundTransparency = 1
    titleFrame.Parent = menuContainer

    local mainTitle = Instance.new("TextLabel")
    mainTitle.Name = "MainTitle"
    mainTitle.Size = UDim2.new(1, 0, 0.55, 0)
    mainTitle.BackgroundTransparency = 1
    mainTitle.Text = "THE LAST FLOOR"
    mainTitle.TextColor3 = COLOR_ACCENT_RED
    mainTitle.Font = Enum.Font.GothamBlack
    mainTitle.TextSize = 42
    mainTitle.TextXAlignment = Enum.TextXAlignment.Left
    mainTitle.Parent = titleFrame

    local subTitle = Instance.new("TextLabel")
    subTitle.Name = "SubTitle"
    subTitle.Size = UDim2.new(1, 0, 0.35, 0)
    subTitle.Position = UDim2.new(0, 0, 0.58, 0)
    subTitle.BackgroundTransparency = 1
    subTitle.Text = "– VACCINE PROTOCOL –"
    subTitle.TextColor3 = COLOR_TEXT_LIGHT
    subTitle.Font = Enum.Font.GothamBold
    subTitle.TextSize = 18
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.Parent = titleFrame

    -- Flickering title light animation
    task.spawn(function()
        while menuContainer.Parent do
            task.wait(math.random(3, 7))
            for _ = 1, math.random(2, 4) do
                mainTitle.TextTransparency = 0.7
                subTitle.TextTransparency = 0.5
                task.wait(0.06)
                mainTitle.TextTransparency = 0
                subTitle.TextTransparency = 0
                task.wait(0.08)
            end
        end
    end)

    -- Menu Button Stack (Left Side)
    local buttonStack = Instance.new("Frame")
    buttonStack.Name = "ButtonStack"
    buttonStack.Size = UDim2.new(0, 260, 0, 240)
    buttonStack.Position = UDim2.new(0.06, 0, 0.34, 0)
    buttonStack.BackgroundTransparency = 1
    buttonStack.Parent = menuContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 14)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = buttonStack

    local playBtn = Instance.new("TextButton")
    playBtn.Name = "PlayButton"
    playBtn.Size = UDim2.new(1, 0, 0, 48)
    playBtn.Text = "PLAY MISSION"
    playBtn.LayoutOrder = 1
    styleButton(playBtn, true)
    playBtn.Parent = buttonStack

    local howToPlayBtn = Instance.new("TextButton")
    howToPlayBtn.Name = "HowToPlayButton"
    howToPlayBtn.Size = UDim2.new(1, 0, 0, 44)
    howToPlayBtn.Text = "HOW TO PLAY"
    howToPlayBtn.LayoutOrder = 2
    styleButton(howToPlayBtn, false)
    howToPlayBtn.Parent = buttonStack

    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Name = "SettingsButton"
    settingsBtn.Size = UDim2.new(1, 0, 0, 44)
    settingsBtn.Text = "SETTINGS"
    settingsBtn.LayoutOrder = 3
    styleButton(settingsBtn, false)
    settingsBtn.Parent = buttonStack

    local creditsBtn = Instance.new("TextButton")
    creditsBtn.Name = "CreditsButton"
    creditsBtn.Size = UDim2.new(1, 0, 0, 44)
    creditsBtn.Text = "CREDITS"
    creditsBtn.LayoutOrder = 4
    styleButton(creditsBtn, false)
    creditsBtn.Parent = buttonStack

    -------------------------------------------------------------------------
    -- 2. MULTIPLAYER LOBBY CONTAINER (1-6 Players)
    -------------------------------------------------------------------------
    lobbyContainer = Instance.new("Frame")
    lobbyContainer.Name = "LobbyContainer"
    lobbyContainer.Size = UDim2.new(0.88, 0, 0.84, 0)
    lobbyContainer.Position = UDim2.new(0.06, 0, 0.08, 0)
    lobbyContainer.BackgroundColor3 = COLOR_PANEL_BG
    lobbyContainer.BackgroundTransparency = 0.1
    lobbyContainer.Visible = false
    createCorner(lobbyContainer, 12)
    createStroke(lobbyContainer, Color3.fromRGB(65, 72, 85), 2)
    lobbyContainer.Parent = root

    -- Lobby Header
    local lobbyHeader = Instance.new("Frame")
    lobbyHeader.Name = "LobbyHeader"
    lobbyHeader.Size = UDim2.new(1, -40, 0, 60)
    lobbyHeader.Position = UDim2.new(0, 20, 0, 16)
    lobbyHeader.BackgroundTransparency = 1
    lobbyHeader.Parent = lobbyContainer

    local lobbyTitle = Instance.new("TextLabel")
    lobbyTitle.Name = "LobbyTitle"
    lobbyTitle.Size = UDim2.new(0.6, 0, 1, 0)
    lobbyTitle.BackgroundTransparency = 1
    lobbyTitle.Text = "MISSION BRIEFING ROOM (1–6 OPERATIVES)"
    lobbyTitle.TextColor3 = COLOR_TEXT_LIGHT
    lobbyTitle.Font = Enum.Font.GothamBlack
    lobbyTitle.TextSize = 22
    lobbyTitle.TextXAlignment = Enum.TextXAlignment.Left
    lobbyTitle.Parent = lobbyHeader

    local lobbyStatus = Instance.new("TextLabel")
    lobbyStatus.Name = "LobbyStatus"
    lobbyStatus.Size = UDim2.new(0.4, 0, 1, 0)
    lobbyStatus.Position = UDim2.new(0.6, 0, 0, 0)
    lobbyStatus.BackgroundTransparency = 1
    lobbyStatus.Text = "Waiting for squad..."
    lobbyStatus.TextColor3 = COLOR_GOLD
    lobbyStatus.Font = Enum.Font.GothamBold
    lobbyStatus.TextSize = 16
    lobbyStatus.TextXAlignment = Enum.TextXAlignment.Right
    lobbyStatus.Parent = lobbyHeader

    -- 6 Player Cards Grid (2 rows x 3 columns)
    local cardGrid = Instance.new("Frame")
    cardGrid.Name = "CardGrid"
    cardGrid.Size = UDim2.new(1, -40, 0.6, 0)
    cardGrid.Position = UDim2.new(0, 20, 0, 85)
    cardGrid.BackgroundTransparency = 1
    cardGrid.Parent = lobbyContainer

    local uigrid = Instance.new("UIGridLayout")
    uigrid.CellPadding = UDim2.new(0, 16, 0, 16)
    uigrid.CellSize = UDim2.new(0.315, 0, 0.44, 0)
    uigrid.SortOrder = Enum.SortOrder.LayoutOrder
    uigrid.Parent = cardGrid

    for i = 1, 6 do
        local card = Instance.new("Frame")
        card.Name = "CardSlot_" .. i
        card.BackgroundColor3 = COLOR_BG_DARK
        card.LayoutOrder = i
        createCorner(card, 8)
        createStroke(card, Color3.fromRGB(40, 45, 55), 1)
        card.Parent = cardGrid

        local avatarImg = Instance.new("ImageLabel")
        avatarImg.Name = "AvatarThumb"
        avatarImg.Size = UDim2.new(0, 56, 0, 56)
        avatarImg.Position = UDim2.new(0, 12, 0.5, -28)
        avatarImg.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
        avatarImg.Image = ""
        createCorner(avatarImg, 28)
        createStroke(avatarImg, Color3.fromRGB(60, 68, 80), 1)
        avatarImg.Parent = card

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "PlayerName"
        nameLabel.Size = UDim2.new(1, -85, 0, 24)
        nameLabel.Position = UDim2.new(0, 78, 0, 16)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "[ OPEN SLOT ]"
        nameLabel.TextColor3 = COLOR_TEXT_MUTED
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 14
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        local badgeLabel = Instance.new("TextLabel")
        badgeLabel.Name = "RoleBadge"
        badgeLabel.Size = UDim2.new(0, 90, 0, 20)
        badgeLabel.Position = UDim2.new(0, 78, 0, 44)
        badgeLabel.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
        badgeLabel.Text = "EMPTY"
        badgeLabel.TextColor3 = COLOR_TEXT_MUTED
        badgeLabel.Font = Enum.Font.GothamSemibold
        badgeLabel.TextSize = 11
        createCorner(badgeLabel, 4)
        badgeLabel.Parent = card

        table.insert(playerCardSlots, card)
    end

    -- Lobby Bottom Controls
    local lobbyControls = Instance.new("Frame")
    lobbyControls.Name = "LobbyControls"
    lobbyControls.Size = UDim2.new(1, -40, 0, 55)
    lobbyControls.Position = UDim2.new(0, 20, 1, -75)
    lobbyControls.BackgroundTransparency = 1
    lobbyControls.Parent = lobbyContainer

    local leaveBtn = Instance.new("TextButton")
    leaveBtn.Name = "LeaveButton"
    leaveBtn.Size = UDim2.new(0, 150, 0, 48)
    leaveBtn.Position = UDim2.new(0, 0, 0, 0)
    leaveBtn.Text = "< LEAVE LOBBY"
    styleButton(leaveBtn, false)
    leaveBtn.Parent = lobbyControls

    local soloBtn = Instance.new("TextButton")
    soloBtn.Name = "SoloButton"
    soloBtn.Size = UDim2.new(0, 180, 0, 48)
    soloBtn.Position = UDim2.new(1, -380, 0, 0)
    soloBtn.Text = "SOLO MISSION"
    styleButton(soloBtn, false)
    soloBtn.Parent = lobbyControls

    local startMatchBtn = Instance.new("TextButton")
    startMatchBtn.Name = "StartMatchButton"
    startMatchBtn.Size = UDim2.new(0, 180, 0, 48)
    startMatchBtn.Position = UDim2.new(1, -185, 0, 0)
    startMatchBtn.Text = "START SQUAD"
    styleButton(startMatchBtn, true)
    startMatchBtn.Parent = lobbyControls

    -------------------------------------------------------------------------
    -- 3. COUNTDOWN & LOADING OVERLAYS
    -------------------------------------------------------------------------
    countdownOverlay = Instance.new("Frame")
    countdownOverlay.Name = "CountdownOverlay"
    countdownOverlay.Size = UDim2.new(1, 0, 1, 0)
    countdownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    countdownOverlay.BackgroundTransparency = 0.5
    countdownOverlay.Visible = false
    countdownOverlay.Parent = root

    countdownLabel = Instance.new("TextLabel")
    countdownLabel.Name = "CountdownLabel"
    countdownLabel.Size = UDim2.new(0, 400, 0, 120)
    countdownLabel.Position = UDim2.new(0.5, -200, 0.45, -60)
    countdownLabel.BackgroundTransparency = 1
    countdownLabel.Text = "MISSION LAUNCH IN: 5"
    countdownLabel.TextColor3 = COLOR_ACCENT_RED
    countdownLabel.Font = Enum.Font.GothamBlack
    countdownLabel.TextSize = 48
    countdownLabel.Parent = countdownOverlay

    loadingOverlay = Instance.new("Frame")
    loadingOverlay.Name = "LoadingOverlay"
    loadingOverlay.Size = UDim2.new(1, 0, 1, 0)
    loadingOverlay.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
    loadingOverlay.BackgroundTransparency = 0
    loadingOverlay.Visible = false
    loadingOverlay.Parent = root

    local loadingTitle = Instance.new("TextLabel")
    loadingTitle.Name = "LoadingTitle"
    loadingTitle.Size = UDim2.new(1, 0, 0, 40)
    loadingTitle.Position = UDim2.new(0, 0, 0.4, -40)
    loadingTitle.BackgroundTransparency = 1
    loadingTitle.Text = "THE LAST FLOOR – VACCINE PROTOCOL"
    loadingTitle.TextColor3 = COLOR_ACCENT_RED
    loadingTitle.Font = Enum.Font.GothamBlack
    loadingTitle.TextSize = 28
    loadingTitle.Parent = loadingOverlay

    loadingStatusLabel = Instance.new("TextLabel")
    loadingStatusLabel.Name = "LoadingStatus"
    loadingStatusLabel.Size = UDim2.new(1, 0, 0, 30)
    loadingStatusLabel.Position = UDim2.new(0, 0, 0.46, 0)
    loadingStatusLabel.BackgroundTransparency = 1
    loadingStatusLabel.Text = "Approaching infected zone in Rescue Truck..."
    loadingStatusLabel.TextColor3 = COLOR_TEXT_MUTED
    loadingStatusLabel.Font = Enum.Font.GothamSemibold
    loadingStatusLabel.TextSize = 16
    loadingStatusLabel.Parent = loadingOverlay

    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(0, 420, 0, 8)
    barBg.Position = UDim2.new(0.5, -210, 0.54, 0)
    barBg.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
    createCorner(barBg, 4)
    barBg.Parent = loadingOverlay

    loadingFillBar = Instance.new("Frame")
    loadingFillBar.Name = "Fill"
    loadingFillBar.Size = UDim2.new(0.05, 0, 1, 0)
    loadingFillBar.BackgroundColor3 = COLOR_ACCENT_RED
    createCorner(loadingFillBar, 4)
    loadingFillBar.Parent = barBg

    -------------------------------------------------------------------------
    -- 4. MODALS (How To Play, Settings, Credits)
    -------------------------------------------------------------------------
    local function createModal(titleText: string, contentText: string): Frame
        local modal = Instance.new("Frame")
        modal.Size = UDim2.new(0.65, 0, 0.72, 0)
        modal.Position = UDim2.new(0.175, 0, 0.14, 0)
        modal.BackgroundColor3 = COLOR_PANEL_BG
        modal.BackgroundTransparency = 0.05
        modal.Visible = false
        createCorner(modal, 10)
        createStroke(modal, Color3.fromRGB(70, 78, 92), 2)
        modal.Parent = root

        local modalTitle = Instance.new("TextLabel")
        modalTitle.Size = UDim2.new(1, -40, 0, 45)
        modalTitle.Position = UDim2.new(0, 20, 0, 15)
        modalTitle.BackgroundTransparency = 1
        modalTitle.Text = titleText
        modalTitle.TextColor3 = COLOR_ACCENT_RED
        modalTitle.Font = Enum.Font.GothamBold
        modalTitle.TextSize = 22
        modalTitle.TextXAlignment = Enum.TextXAlignment.Left
        modalTitle.Parent = modal

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 36, 0, 36)
        closeBtn.Position = UDim2.new(1, -50, 0, 15)
        closeBtn.Text = "✕"
        styleButton(closeBtn, false)
        closeBtn.Parent = modal
        closeBtn.Activated:Connect(function()
            modal.Visible = false
            menuContainer.Visible = true
        end)

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -40, 1, -80)
        body.Position = UDim2.new(0, 20, 0, 65)
        body.BackgroundTransparency = 1
        body.Text = contentText
        body.TextColor3 = COLOR_TEXT_LIGHT
        body.Font = Enum.Font.Gotham
        body.TextSize = 15
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextWrapped = true
        body.Parent = modal

        return modal
    end

    howToPlayModal = createModal(
        "HOW TO PLAY – VACCINE PROTOCOL",
        "• OBJECTIVE: Infiltrate the infected 10-floor apartment building, survive all floors, find the vaccine on Floor 10, and escape.\n\n" ..
        "• PROGRESSION: The elevator is your ONLY path upward. Every floor has a unique puzzle and time limit.\n\n" ..
        "• TIME LIMITS: Basement B1 starts with 2:00. Every subsequent floor adds +1m 12s. Do not let the timer expire!\n\n" ..
        "• SURVIVAL: When downed, crawl to safety (30s bleedout). Teammates can revive you in 5 seconds (restores 35 HP). You get 1 free return; second elimination is spectator mode.\n\n" ..
        "• STEALTH & SOUND: Sprinting and shooting make loud noise that alerts infected (Blind Hunter, Runners). Crouch (C / Left Ctrl) to move silently."
    )

    settingsModal = createModal(
        "MISSION SETTINGS",
        "• AUDIO: Master Volume: 100% | Atmospheric Horror Reverb: Enabled\n\n" ..
        "• GRAPHICS: Volumetric Fog: Enabled | Dynamic Shadows: Enabled\n\n" ..
        "• CONTROLS:\n" ..
        "  - Move: W, A, S, D\n" ..
        "  - Sprint: Left Shift (High Noise)\n" ..
        "  - Crouch: Left Control / C (Silent)\n" ..
        "  - Flashlight: F\n" ..
        "  - Interact / Revive: E (Hold 5s to Revive Teammate)\n" ..
        "  - Inventory: 1, 2, 3"
    )

    creditsModal = createModal(
        "THE LAST FLOOR – CREDITS",
        "• DEVELOPMENT: Antigravity Senior Engineering Team\n\n" ..
        "• ENGINE: Roblox Studio / Luau\n\n" ..
        "• AUDIO & CINEMATICS: Original Horror Spatial Audio & Cinematic Rig\n\n" ..
        "• GAMEPLAY DESIGN: Cooperative Survival Horror Architecture"
    )

    -------------------------------------------------------------------------
    -- 5. BUTTON WIRING & NETWORKING
    -------------------------------------------------------------------------
    playBtn.Activated:Connect(function()
        local success, msg = lobbyJoinFunction:InvokeServer()
        if success then
            menuContainer.Visible = false
            lobbyContainer.Visible = true
        else
            warn("[MenuController] Join lobby failed: " .. tostring(msg))
        end
    end)

    howToPlayBtn.Activated:Connect(function()
        menuContainer.Visible = false
        howToPlayModal.Visible = true
    end)

    settingsBtn.Activated:Connect(function()
        menuContainer.Visible = false
        settingsModal.Visible = true
    end)

    creditsBtn.Activated:Connect(function()
        menuContainer.Visible = false
        creditsModal.Visible = true
    end)

    leaveBtn.Activated:Connect(function()
        lobbyLeaveFunction:InvokeServer()
        lobbyContainer.Visible = false
        menuContainer.Visible = true
    end)

    soloBtn.Activated:Connect(function()
        local success, msg = lobbyStartMatchFunction:InvokeServer(true)
        if not success then
            warn("[MenuController] Solo start failed: " .. tostring(msg))
        end
    end)

    startMatchBtn.Activated:Connect(function()
        local success, msg = lobbyStartMatchFunction:InvokeServer(false)
        if not success then
            warn("[MenuController] Squad start failed: " .. tostring(msg))
        end
    end)

    -- Handle Lobby State Replications
    lobbyStateUpdateRemote.OnClientEvent:Connect(function(state: any)
        if not state then return end

        local statusText = state.StatusMessage or "Waiting for squad..."
        lobbyStatus.Text = statusText

        isHost = (state.HostUserId == localPlayer.UserId)
        startMatchBtn.Visible = isHost
        soloBtn.Visible = isHost

        -- Update countdown overlay
        if state.IsCountingDown then
            countdownOverlay.Visible = true
            countdownLabel.Text = string.format("MISSION LAUNCH IN: %d", state.CountdownSeconds or 5)
            TweenService:Create(countdownLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                TextSize = 54
            }):Play()
            task.delay(0.3, function()
                TweenService:Create(countdownLabel, TweenInfo.new(0.3), { TextSize = 48 }):Play()
            end)
        else
            countdownOverlay.Visible = false
        end

        -- Update 6 Card Slots
        local members = state.Members or {}
        for i = 1, 6 do
            local card = playerCardSlots[i]
            local member = members[i]
            local nameLabel = card:FindFirstChild("PlayerName") :: TextLabel
            local badgeLabel = card:FindFirstChild("RoleBadge") :: TextLabel
            local avatarImg = card:FindFirstChild("AvatarThumb") :: ImageLabel

            if member then
                nameLabel.Text = member.DisplayName or member.Name
                nameLabel.TextColor3 = COLOR_TEXT_LIGHT

                if member.IsHost then
                    badgeLabel.Text = "SQUAD LEADER"
                    badgeLabel.BackgroundColor3 = COLOR_ACCENT_RED
                    badgeLabel.TextColor3 = Color3.new(1, 1, 1)
                else
                    badgeLabel.Text = "READY"
                    badgeLabel.BackgroundColor3 = Color3.fromRGB(38, 70, 48)
                    badgeLabel.TextColor3 = Color3.fromRGB(150, 240, 160)
                end

                -- Fetch avatar thumbnail
                task.spawn(function()
                    local thumbType = Enum.ThumbnailType.HeadShot
                    local thumbSize = Enum.ThumbnailSize.Size100x100
                    local content, isReady = Players:GetUserThumbnailAsync(member.UserId, thumbType, thumbSize)
                    if isReady and avatarImg then
                        avatarImg.Image = content
                    end
                end)
            else
                nameLabel.Text = "[ OPEN SLOT ]"
                nameLabel.TextColor3 = COLOR_TEXT_MUTED
                badgeLabel.Text = "EMPTY"
                badgeLabel.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
                badgeLabel.TextColor3 = COLOR_TEXT_MUTED
                avatarImg.Image = ""
            end
        end
    end)

    -- Match Starting Transition -> Loading Screen -> B1
    matchStartingRemote.OnClientEvent:Connect(function()
        lobbyContainer.Visible = false
        menuContainer.Visible = false
        countdownOverlay.Visible = false
        loadingOverlay.Visible = true

        -- Animate loading bar
        loadingStatusLabel.Text = "Entering Basement B1 with Emergency Response Truck..."
        TweenService:Create(loadingFillBar, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()

        task.delay(2.8, function()
            -- Fade loading screen and restore camera
            local fadeTween = TweenService:Create(loadingOverlay, TweenInfo.new(1.0), { BackgroundTransparency = 1 })
            fadeTween:Play()
            fadeTween.Completed:Wait()
            loadingOverlay.Visible = false
            releaseCamera()
            print("[MenuController] Transition to B1 complete!")
        end)
    end)
end

function MenuController.Init()
    setupCinematicCamera()
    buildUI()
    print("[MenuController] Main menu and multiplayer lobby initialized.")
end

return MenuController

