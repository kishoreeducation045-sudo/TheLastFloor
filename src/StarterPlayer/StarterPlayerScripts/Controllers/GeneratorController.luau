--!strict
-- GeneratorController.luau
-- Upgraded Industrial Auxiliary Generator Circuit Bypass Mini-Game
-- Features:
--   - Faded schematic wiring diagram + corroded phase symbol clues (~ / ≈ / ⏚) so connections are deducible
--   - Initially RUST-MASKED plates; true colors (Red/Blue/Yellow) burst out ONLY upon valid match
--   - Clear feedback (3-layer glowing cable, voltage LEDs, panel shake + buzz on short-circuit fault)
--   - Full Mouse, Touch, and Keyboard support (1/2/3, Arrows/WSAD, Tab, Enter/Space, Esc)
--   - Authoritative server-issued order & server-side solution verification

local Players                = game:GetService("Players")
local UserInputService       = game:GetService("UserInputService")
local TweenService           = game:GetService("TweenService")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace              = game:GetService("Workspace")
local SoundService           = game:GetService("SoundService")

local GeneratorController = {}
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local remotes           = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
local requestGenRemote  = remotes:WaitForChild("RequestGeneratorPuzzle") :: RemoteEvent
local openPuzzleRemote  = remotes:WaitForChild("OpenGeneratorPuzzle") :: RemoteEvent
local genFixedRemote    = remotes:WaitForChild("GeneratorFixed") :: RemoteEvent

local WIRE_SPECS = {
    [1] = { id = 1, glyph = "~", name = "CIRCUIT α (PHASE A)", color = Color3.fromRGB(235, 45, 45),  glow = Color3.fromRGB(255, 95, 95) },
    [2] = { id = 2, glyph = "≈", name = "CIRCUIT β (PHASE B)", color = Color3.fromRGB(40, 130, 250), glow = Color3.fromRGB(100, 185, 255) },
    [3] = { id = 3, glyph = "⏚", name = "CIRCUIT γ (GROUND)",  color = Color3.fromRGB(245, 205, 35), glow = Color3.fromRGB(255, 235, 110) },
}

local RUST_BASE     = Color3.fromRGB(72, 45, 28)
local RUST_BORDER   = Color3.fromRGB(98, 62, 38)
local RUST_CORE     = Color3.fromRGB(44, 30, 20)
local RUST_APERTURE = Color3.fromRGB(22, 16, 12)

local modalSg: ScreenGui? = nil
local modalVisible = false
local puzzleSolved = false
local selectedLeftIdx: number? = nil
local connectedWires = { false, false, false }
local matchedPorts: { [number]: number } = {}
local rightOrder = { 1, 2, 3 }

-- Keyboard focus state: column ("LEFT" | "RIGHT"), row (1..3)
local focusCol = "LEFT"
local focusRow = 1

local leftTerminalFrames: { [number]: Frame } = {}
local rightTerminalFrames: { [number]: Frame } = {}
local leftSockets: { [number]: Frame } = {}
local rightSockets: { [number]: Frame } = {}
local leftStrokes: { [number]: UIStroke } = {}
local rightStrokes: { [number]: UIStroke } = {}
local leftActionFns: { [number]: () -> () } = {}
local rightActionFns: { [number]: () -> () } = {}
local statusLedBars: { [number]: Frame } = {}
local activeCables: { [number]: Frame } = {}

local function playSound(soundId: string, pitch: number, vol: number)
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = soundId
        s.PlaybackSpeed = pitch
        s.Volume = vol
        s.PlayOnRemove = true
        s.Parent = SoundService
        s:Destroy()
    end)
end

local function playClick()
    playSound("rbxassetid://6895079853", 1.0, 0.45)
end

local function playZap()
    playSound("rbxassetid://138090596", 1.2, 0.65)
end

local function playError()
    playSound("rbxassetid://9069609200", 0.8, 0.55)
end

local function playPowerOn()
    playSound("rbxassetid://138090596", 0.65, 0.8)
end

local function shakeChassis(chassis: Frame)
    task.spawn(function()
        local basePos = UDim2.new(0.5, -340, 0.5, -255)
        for i = 1, 5 do
            if not chassis or not chassis.Parent then return end
            local offsetX = (i % 2 == 1) and 9 or -9
            chassis.Position = UDim2.new(0.5, -340 + offsetX, 0.5, -255)
            task.wait(0.04)
        end
        if chassis and chassis.Parent then
            chassis.Position = basePos
        end
    end)
end

local function cleanupBoard()
    for _, cable in pairs(activeCables) do
        if cable and cable.Parent then cable:Destroy() end
    end
    activeCables = {}
    selectedLeftIdx = nil
    connectedWires = { false, false, false }
    matchedPorts = {}
    focusCol = "LEFT"
    focusRow = 1
end

local function refreshKeyboardHighlights()
    for j = 1, 3 do
        local ls = leftStrokes[j]
        if ls and not connectedWires[j] then
            if selectedLeftIdx == j then
                ls.Color = Color3.fromRGB(255, 215, 60)
                ls.Thickness = 3.2
            elseif focusCol == "LEFT" and focusRow == j then
                ls.Color = Color3.fromRGB(160, 215, 255)
                ls.Thickness = 2.6
            else
                ls.Color = RUST_BORDER
                ls.Thickness = 2.0
            end
        end

        local wireId = rightOrder[j]
        local rs = rightStrokes[j]
        if rs and not connectedWires[wireId] then
            if focusCol == "RIGHT" and focusRow == j then
                rs.Color = Color3.fromRGB(160, 215, 255)
                rs.Thickness = 2.8
            else
                rs.Color = RUST_BORDER
                rs.Thickness = 2.0
            end
        end
    end
end

local function createTerminalBlock(
    parent: GuiObject,
    xPos: UDim2,
    yOffset: number,
    tagText: string,
    clueGlyph: string
): (Frame, Frame, UIStroke, TextButton)
    local block = Instance.new("Frame")
    block.Size = UDim2.new(0, 136, 0, 74)
    block.Position = UDim2.new(xPos.X.Scale, xPos.X.Offset, 0, yOffset)
    block.BackgroundColor3 = RUST_BASE
    block.BorderSizePixel = 0
    block.ZIndex = 3
    block.Parent = parent

    local blockCorner = Instance.new("UICorner")
    blockCorner.CornerRadius = UDim.new(0, 6)
    blockCorner.Parent = block

    local blockStroke = Instance.new("UIStroke")
    blockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    blockStroke.Color = RUST_BORDER
    blockStroke.Thickness = 2.0
    blockStroke.Parent = block

    for _, bPos in ipairs({ Vector2.new(6, 6), Vector2.new(130, 6), Vector2.new(6, 68), Vector2.new(130, 68) }) do
        local bolt = Instance.new("Frame")
        bolt.Size = UDim2.new(0, 5, 0, 5)
        bolt.Position = UDim2.new(0, bPos.X - 2.5, 0, bPos.Y - 2.5)
        bolt.BackgroundColor3 = Color3.fromRGB(35, 25, 20)
        bolt.BorderSizePixel = 0
        bolt.ZIndex = 4
        local boltCorner = Instance.new("UICorner")
        boltCorner.CornerRadius = UDim.new(1, 0)
        boltCorner.Parent = bolt
        bolt.Parent = block
    end

    local patch1 = Instance.new("Frame")
    patch1.Name = "RustPatch1"
    patch1.Size = UDim2.new(0, 50, 0, 28)
    patch1.Position = UDim2.new(0, 8, 0, 10)
    patch1.BackgroundColor3 = Color3.fromRGB(98, 55, 30)
    patch1.BackgroundTransparency = 0.35
    patch1.BorderSizePixel = 0
    patch1.ZIndex = 3
    local p1Corner = Instance.new("UICorner")
    p1Corner.CornerRadius = UDim.new(0, 4)
    p1Corner.Parent = patch1
    patch1.Parent = block

    local patch2 = Instance.new("Frame")
    patch2.Name = "RustPatch2"
    patch2.Size = UDim2.new(0, 38, 0, 22)
    patch2.Position = UDim2.new(1, -46, 1, -30)
    patch2.BackgroundColor3 = Color3.fromRGB(50, 32, 20)
    patch2.BackgroundTransparency = 0.4
    patch2.BorderSizePixel = 0
    patch2.ZIndex = 3
    local p2Corner = Instance.new("UICorner")
    p2Corner.CornerRadius = UDim.new(0, 4)
    p2Corner.Parent = patch2
    patch2.Parent = block

    -- Faded corroded electrical glyph clue stamped onto plate edge (~ / ≈ / ⏚)
    local glyphLbl = Instance.new("TextLabel")
    glyphLbl.Name = "ClueGlyph"
    glyphLbl.Size = UDim2.new(0, 26, 0, 26)
    glyphLbl.Position = UDim2.new(0, 10, 0.5, -13)
    glyphLbl.BackgroundTransparency = 1
    glyphLbl.Text = clueGlyph
    glyphLbl.TextColor3 = Color3.fromRGB(165, 130, 95)
    glyphLbl.TextTransparency = 0.25
    glyphLbl.Font = Enum.Font.GothamBlack
    glyphLbl.TextSize = 18
    glyphLbl.ZIndex = 4
    glyphLbl.Parent = block

    local socket = Instance.new("Frame")
    socket.Name = "Socket"
    socket.Size = UDim2.new(0, 34, 0, 34)
    socket.Position = UDim2.new(0.5, -17, 0.5, -17)
    socket.BackgroundColor3 = RUST_CORE
    socket.BorderSizePixel = 0
    socket.ZIndex = 4
    local socketCorner = Instance.new("UICorner")
    socketCorner.CornerRadius = UDim.new(1, 0)
    socketCorner.Parent = socket

    local socketStroke = Instance.new("UIStroke")
    socketStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    socketStroke.Color = RUST_BORDER
    socketStroke.Thickness = 1.8
    socketStroke.Parent = socket
    socket.Parent = block

    local contactHole = Instance.new("Frame")
    contactHole.Name = "ContactHole"
    contactHole.Size = UDim2.new(0, 16, 0, 16)
    contactHole.Position = UDim2.new(0.5, -8, 0.5, -8)
    contactHole.BackgroundColor3 = RUST_APERTURE
    contactHole.BorderSizePixel = 0
    contactHole.ZIndex = 5
    local holeCorner = Instance.new("UICorner")
    holeCorner.CornerRadius = UDim.new(1, 0)
    holeCorner.Parent = contactHole
    contactHole.Parent = socket

    local tag = Instance.new("TextLabel")
    tag.Name = "Tag"
    tag.Size = UDim2.new(1, 0, 0, 14)
    tag.Position = UDim2.new(0, 0, 1, -16)
    tag.BackgroundTransparency = 1
    tag.Text = tagText
    tag.TextColor3 = Color3.fromRGB(150, 130, 115)
    tag.Font = Enum.Font.GothamBold
    tag.TextSize = 10
    tag.ZIndex = 4
    tag.Parent = block

    local btn = Instance.new("TextButton")
    btn.Name = "TriggerButton"
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 6
    btn.Parent = block

    return block, socket, blockStroke, btn
end

local function drawFadedSchematicLine(canvas: Frame, x1: number, y1: number, x2: number, y2: number, glyph: string)
    local deltaX = x2 - x1
    local deltaY = y2 - y1
    local length = math.sqrt((deltaX * deltaX) + (deltaY * deltaY))
    local angle  = math.atan2(deltaY, deltaX)

    -- Subtle dashed blueprint trace etched across background board
    local trace = Instance.new("Frame")
    trace.Name = "SchematicTrace"
    trace.BackgroundColor3 = Color3.fromRGB(58, 76, 98)
    trace.BackgroundTransparency = 0.65
    trace.BorderSizePixel = 0
    trace.Size = UDim2.new(0, length, 0, 2)
    trace.Position = UDim2.new(0, x1, 0, y1)
    trace.AnchorPoint = Vector2.new(0, 0.5)
    trace.Rotation = math.deg(angle)
    trace.ZIndex = 1
    trace.Parent = canvas

    -- Midpoint faded symbol badge along schematic trace
    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 20, 0, 20)
    badge.Position = UDim2.new(0, (x1 + x2) / 2 - 10, 0, (y1 + y2) / 2 - 10)
    badge.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
    badge.BackgroundTransparency = 0.3
    badge.Text = glyph
    badge.TextColor3 = Color3.fromRGB(78, 100, 128)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 12
    badge.ZIndex = 2
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = badge
    badge.Parent = canvas
end

local function drawIndustrialCable(canvas: Frame, x1: number, y1: number, x2: number, y2: number, spec: any): Frame
    local deltaX = x2 - x1
    local deltaY = y2 - y1
    local length = math.sqrt((deltaX * deltaX) + (deltaY * deltaY))
    local angle  = math.atan2(deltaY, deltaX)

    local cableContainer = Instance.new("Frame")
    cableContainer.Name = "Cable_" .. spec.id
    cableContainer.BackgroundTransparency = 1
    cableContainer.Size = UDim2.new(0, length, 0, 14)
    cableContainer.Position = UDim2.new(0, x1, 0, y1)
    cableContainer.AnchorPoint = Vector2.new(0, 0.5)
    cableContainer.Rotation = math.deg(angle)
    cableContainer.ZIndex = 5

    local outerSleeve = Instance.new("Frame")
    outerSleeve.Size = UDim2.new(1, 0, 0, 10)
    outerSleeve.Position = UDim2.new(0, 0, 0.5, -5)
    outerSleeve.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
    outerSleeve.BorderSizePixel = 0
    outerSleeve.ZIndex = 5
    local sleeveCorner = Instance.new("UICorner") sleeveCorner.CornerRadius = UDim.new(0, 5) sleeveCorner.Parent = outerSleeve
    outerSleeve.Parent = cableContainer

    local innerCore = Instance.new("Frame")
    innerCore.Size = UDim2.new(1, -4, 0, 6)
    innerCore.Position = UDim2.new(0, 2, 0.5, -3)
    innerCore.BackgroundColor3 = spec.color
    innerCore.BorderSizePixel = 0
    innerCore.ZIndex = 6
    local coreCorner = Instance.new("UICorner") coreCorner.CornerRadius = UDim.new(0, 3) coreCorner.Parent = innerCore
    innerCore.Parent = cableContainer

    local highlight = Instance.new("Frame")
    highlight.Size = UDim2.new(1, -8, 0, 2)
    highlight.Position = UDim2.new(0, 4, 0.5, -1)
    highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    highlight.BackgroundTransparency = 0.35
    highlight.BorderSizePixel = 0
    highlight.ZIndex = 7
    local hlCorner = Instance.new("UICorner") hlCorner.CornerRadius = UDim.new(0, 1) hlCorner.Parent = highlight
    highlight.Parent = cableContainer

    cableContainer.Parent = canvas
    return cableContainer
end

local function buildModal(serverOrder: { number }?)
    if modalSg then modalSg:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TLF_GeneratorPuzzle"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 40
    sg.Enabled = true
    sg.Parent = playerGui
    modalSg = sg

    local backdrop = Instance.new("Frame")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.62
    backdrop.BorderSizePixel = 0
    backdrop.Parent = sg

    local chassis = Instance.new("Frame")
    chassis.Name = "GeneratorChassis"
    chassis.Size = UDim2.new(0, 680, 0, 510)
    chassis.Position = UDim2.new(0.5, -340, 0.5, -255)
    chassis.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
    chassis.BorderSizePixel = 0
    chassis.Parent = sg

    local chassisCorner = Instance.new("UICorner") chassisCorner.CornerRadius = UDim.new(0, 10) chassisCorner.Parent = chassis
    local chassisStroke = Instance.new("UIStroke")
    chassisStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    chassisStroke.Color = Color3.fromRGB(75, 82, 95)
    chassisStroke.Thickness = 2.5
    chassisStroke.Parent = chassis

    local topHazard = Instance.new("Frame")
    topHazard.Size = UDim2.new(1, 0, 0, 8)
    topHazard.BackgroundColor3 = Color3.fromRGB(240, 180, 20)
    topHazard.BorderSizePixel = 0
    local thCorner = Instance.new("UICorner") thCorner.CornerRadius = UDim.new(0, 10) thCorner.Parent = topHazard
    topHazard.Parent = chassis

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -24, 0, 64)
    header.Position = UDim2.new(0, 12, 0, 14)
    header.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
    header.BorderSizePixel = 0
    local headerCorner = Instance.new("UICorner") headerCorner.CornerRadius = UDim.new(0, 8) headerCorner.Parent = header
    header.Parent = chassis

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLabel"
    titleLbl.Size = UDim2.new(1, -20, 0, 26)
    titleLbl.Position = UDim2.new(0, 10, 0, 6)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "⚡  AUXILIARY GENERATOR — MANUAL CIRCUIT BYPASS  ⚡"
    titleLbl.TextColor3 = Color3.fromRGB(250, 195, 45)
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 15
    titleLbl.Parent = header

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name = "StatusLabel"
    statusLbl.Size = UDim2.new(1, -20, 0, 20)
    statusLbl.Position = UDim2.new(0, 10, 0, 34)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "TRACE FADED SCHEMATIC SYMBOLS (~ / ≈ / ⏚) FROM LEFT TO RIGHT PORTS"
    statusLbl.TextColor3 = Color3.fromRGB(175, 185, 200)
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.TextSize = 11
    statusLbl.Parent = header

    local diagBar = Instance.new("Frame")
    diagBar.Size = UDim2.new(1, -24, 0, 30)
    diagBar.Position = UDim2.new(0, 12, 0, 84)
    diagBar.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
    diagBar.BorderSizePixel = 0
    local diagCorner = Instance.new("UICorner") diagCorner.CornerRadius = UDim.new(0, 6) diagCorner.Parent = diagBar
    local diagStroke = Instance.new("UIStroke") diagStroke.Color = Color3.fromRGB(45, 50, 62) diagStroke.Thickness = 1.0 diagStroke.Parent = diagBar
    diagBar.Parent = chassis

    local meterLbl = Instance.new("TextLabel")
    meterLbl.Size = UDim2.new(0, 180, 1, 0)
    meterLbl.Position = UDim2.new(0, 12, 0, 0)
    meterLbl.BackgroundTransparency = 1
    meterLbl.Text = "CIRCUITS CLOSED: 0 / 3"
    meterLbl.TextColor3 = Color3.fromRGB(220, 160, 40)
    meterLbl.Font = Enum.Font.GothamBold
    meterLbl.TextSize = 12
    meterLbl.TextXAlignment = Enum.TextXAlignment.Left
    meterLbl.Parent = diagBar

    statusLedBars = {}
    for ch = 1, 3 do
        local led = Instance.new("Frame")
        led.Size = UDim2.new(0, 74, 0, 16)
        led.Position = UDim2.new(1, -246 + ((ch - 1) * 80), 0.5, -8)
        led.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
        led.BorderSizePixel = 0
        local ledCorner = Instance.new("UICorner") ledCorner.CornerRadius = UDim.new(0, 3) ledCorner.Parent = led
        local ledStroke = Instance.new("UIStroke") ledStroke.Color = Color3.fromRGB(70, 30, 30) ledStroke.Thickness = 1.0 ledStroke.Parent = led
        led.Parent = diagBar

        local ledText = Instance.new("TextLabel")
        ledText.Size = UDim2.new(1, 0, 1, 0)
        ledText.BackgroundTransparency = 1
        ledText.Text = "CH " .. ch .. ": OFF"
        ledText.TextColor3 = Color3.fromRGB(160, 65, 65)
        ledText.Font = Enum.Font.GothamBold
        ledText.TextSize = 10
        ledText.Parent = led
        statusLedBars[ch] = led
    end

    local board = Instance.new("Frame")
    board.Name = "WireBoard"
    board.Size = UDim2.new(1, -24, 0, 315)
    board.Position = UDim2.new(0, 12, 0, 120)
    board.BackgroundColor3 = Color3.fromRGB(9, 11, 14)
    board.BorderSizePixel = 0
    local boardCorner = Instance.new("UICorner") boardCorner.CornerRadius = UDim.new(0, 8) boardCorner.Parent = board
    local boardStroke = Instance.new("UIStroke") boardStroke.Color = Color3.fromRGB(42, 48, 58) boardStroke.Thickness = 1.5 boardStroke.Parent = board
    board.Parent = chassis

    local wireCanvas = Instance.new("Frame")
    wireCanvas.Name = "WireCanvas"
    wireCanvas.Size = UDim2.new(1, 0, 1, 0)
    wireCanvas.BackgroundTransparency = 1
    wireCanvas.ClipsDescendants = false
    wireCanvas.Parent = board

    -- Faded schematic header note
    local schematicLbl = Instance.new("TextLabel")
    schematicLbl.Size = UDim2.new(0, 230, 0, 34)
    schematicLbl.Position = UDim2.new(0.5, -115, 0, 4)
    schematicLbl.BackgroundTransparency = 1
    schematicLbl.Text = "ETCHED WIRING SCHEMATIC • 240V 3-PHASE\nMATCH CORRODED SYMBOLS TO RESTORE GRID"
    schematicLbl.TextColor3 = Color3.fromRGB(52, 66, 84)
    schematicLbl.Font = Enum.Font.GothamBold
    schematicLbl.TextSize = 9
    schematicLbl.ZIndex = 1
    schematicLbl.Parent = board

    if serverOrder and #serverOrder == 3 then
        rightOrder = table.clone(serverOrder)
    else
        rightOrder = { 1, 2, 3 }
        for i = #rightOrder, 2, -1 do
            local j = math.random(1, i)
            rightOrder[i], rightOrder[j] = rightOrder[j], rightOrder[i]
        end
    end

    leftTerminalFrames = {}
    rightTerminalFrames = {}
    leftSockets = {}
    rightSockets = {}
    leftStrokes = {}
    rightStrokes = {}
    leftActionFns = {}
    rightActionFns = {}
    cleanupBoard()

    local boardWidth = 656
    local leftCenterX = 88
    local rightCenterX = boardWidth - 88

    -- Draw Faded Wiring Diagram Trace Lines matching the real circuit solution
    for visualIdx, wireId in ipairs(rightOrder) do
        local leftCenterY = 64 + ((wireId - 1) * 95)
        local rightCenterY = 64 + ((visualIdx - 1) * 95)
        drawFadedSchematicLine(wireCanvas, leftCenterX, leftCenterY, rightCenterX, rightCenterY, WIRE_SPECS[wireId].glyph)
    end

    -- Spawn Left Input Terminals
    for i = 1, 3 do
        local yOffset = 27 + ((i - 1) * 95)
        local block, socket, stroke, btn = createTerminalBlock(board, UDim2.new(0, 20, 0, 0), yOffset, "INPUT " .. i, WIRE_SPECS[i].glyph)
        leftTerminalFrames[i] = block
        leftSockets[i] = socket
        leftStrokes[i] = stroke

        local function selectLeft()
            if connectedWires[i] or puzzleSolved then return end
            playClick()
            selectedLeftIdx = i
            focusCol = "RIGHT"
            focusRow = 1
            statusLbl.Text = string.format("INPUT %d [%s] SELECTED — SELECT MATCHING PORT [RIGHT]", i, WIRE_SPECS[i].glyph)
            statusLbl.TextColor3 = Color3.fromRGB(255, 205, 75)
            refreshKeyboardHighlights()
        end

        leftActionFns[i] = selectLeft
        btn.Activated:Connect(selectLeft)
    end

    -- Spawn Right Receiver Ports
    for visualIdx, wireId in ipairs(rightOrder) do
        local yOffset = 27 + ((visualIdx - 1) * 95)
        local portLetter = string.char(64 + visualIdx)
        local block, socket, stroke, btn = createTerminalBlock(board, UDim2.new(1, -156, 0, 0), yOffset, "PORT " .. portLetter, WIRE_SPECS[wireId].glyph)
        rightTerminalFrames[visualIdx] = block
        rightSockets[visualIdx] = socket
        rightStrokes[visualIdx] = stroke

        local function connectRight()
            if puzzleSolved then return end
            if selectedLeftIdx == nil then
                playClick()
                statusLbl.Text = "SELECT AN INPUT TERMINAL ON THE LEFT FIRST!"
                statusLbl.TextColor3 = Color3.fromRGB(245, 165, 45)
                focusCol = "LEFT"
                refreshKeyboardHighlights()
                return
            end

            local activeLeft = selectedLeftIdx
            if connectedWires[activeLeft] then return end

            if wireId == activeLeft then
                connectedWires[activeLeft] = true
                matchedPorts[activeLeft] = visualIdx
                playZap()

                local spec = WIRE_SPECS[activeLeft]
                statusLbl.Text = string.format("✔ %s CONNECTED — CONDUCTIVITY RESTORED", spec.name)
                statusLbl.TextColor3 = spec.glow

                -- Reveal left & right true colors
                local lBlock = leftTerminalFrames[activeLeft]
                local lSocket = leftSockets[activeLeft]
                local lStroke = leftStrokes[activeLeft]
                lBlock.BackgroundColor3 = spec.color
                lStroke.Color = spec.glow
                lStroke.Thickness = 2.5
                lSocket.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                local lHole = lSocket:FindFirstChild("ContactHole") :: Frame?
                if lHole then lHole.BackgroundColor3 = spec.glow end
                local lP1 = lBlock:FindFirstChild("RustPatch1") :: Frame?
                local lP2 = lBlock:FindFirstChild("RustPatch2") :: Frame?
                if lP1 then lP1.BackgroundTransparency = 1 end
                if lP2 then lP2.BackgroundTransparency = 1 end

                local rBlock = rightTerminalFrames[visualIdx]
                local rSocket = rightSockets[visualIdx]
                local rStroke = rightStrokes[visualIdx]
                rBlock.BackgroundColor3 = spec.color
                rStroke.Color = spec.glow
                rStroke.Thickness = 2.5
                rSocket.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                local rHole = rSocket:FindFirstChild("ContactHole") :: Frame?
                if rHole then rHole.BackgroundColor3 = spec.glow end
                local rP1 = rBlock:FindFirstChild("RustPatch1") :: Frame?
                local rP2 = rBlock:FindFirstChild("RustPatch2") :: Frame?
                if rP1 then rP1.BackgroundTransparency = 1 end
                if rP2 then rP2.BackgroundTransparency = 1 end

                local actualW = board.AbsoluteSize.X > 0 and board.AbsoluteSize.X or boardWidth
                local leftCenterY = 64 + ((activeLeft - 1) * 95)
                local rightCenterY = 64 + ((visualIdx - 1) * 95)
                local cable = drawIndustrialCable(wireCanvas, 88, leftCenterY, actualW - 88, rightCenterY, spec)
                activeCables[activeLeft] = cable

                local led = statusLedBars[activeLeft]
                if led then
                    led.BackgroundColor3 = Color3.fromRGB(20, 60, 25)
                    local ls = led:FindFirstChildOfClass("UIStroke")
                    if ls then ls.Color = Color3.fromRGB(40, 200, 60) end
                    local lt = led:FindFirstChildOfClass("TextLabel")
                    if lt then
                        lt.Text = "CH " .. activeLeft .. ": LOCKED"
                        lt.TextColor3 = Color3.fromRGB(60, 240, 100)
                    end
                end

                selectedLeftIdx = nil
                focusCol = "LEFT"
                refreshKeyboardHighlights()

                local totalConnected = 0
                for _, done in ipairs(connectedWires) do
                    if done then totalConnected += 1 end
                end
                meterLbl.Text = string.format("CIRCUITS CLOSED: %d / 3", totalConnected)

                if totalConnected == 3 then
                    puzzleSolved = true
                    playPowerOn()
                    titleLbl.Text = "✅  CIRCUIT RESTORED — AUXILIARY POWER ONLINE"
                    titleLbl.TextColor3 = Color3.fromRGB(60, 255, 110)
                    statusLbl.Text = "GENERATOR START SEQUENCE INITIATED... ENGAGING EMERGENCY GRID."
                    statusLbl.TextColor3 = Color3.fromRGB(240, 255, 240)

                    local payloadToSend = table.clone(matchedPorts)
                    task.delay(1.1, function()
                        GeneratorController.Close()
                        genFixedRemote:FireServer(payloadToSend)
                    end)
                end
            else
                -- SHORT CIRCUIT ERROR FEEDBACK
                playError()
                shakeChassis(chassis)
                statusLbl.Text = "❌ POLARITY REJECTED — FOLLOW THE FADED SCHEMATIC SYMBOLS!"
                statusLbl.TextColor3 = Color3.fromRGB(255, 65, 65)

                local rBlock = rightTerminalFrames[visualIdx]
                local rStroke = rightStrokes[visualIdx]
                local oldBg = rBlock.BackgroundColor3
                rBlock.BackgroundColor3 = Color3.fromRGB(165, 25, 25)
                rStroke.Color = Color3.fromRGB(255, 60, 60)

                task.delay(0.35, function()
                    if rBlock and rBlock.Parent then
                        rBlock.BackgroundColor3 = oldBg
                    end
                    refreshKeyboardHighlights()
                end)

                selectedLeftIdx = nil
                focusCol = "LEFT"
                refreshKeyboardHighlights()
            end
        end

        rightActionFns[visualIdx] = connectRight
        btn.Activated:Connect(connectRight)
    end

    refreshKeyboardHighlights()

    -- Controls footer hint + Abort Button
    local controlsHint = Instance.new("TextLabel")
    controlsHint.Size = UDim2.new(1, -24, 0, 16)
    controlsHint.Position = UDim2.new(0, 12, 1, -66)
    controlsHint.BackgroundTransparency = 1
    controlsHint.Text = "TOUCH / MOUSE: TAP TERMINALS   •   KEYBOARD: [1-3] INPUT  |  [↑/↓] MOVE  |  [TAB] SWITCH SIDE  |  [ENTER] CONNECT  |  [ESC] CLOSE"
    controlsHint.TextColor3 = Color3.fromRGB(115, 125, 140)
    controlsHint.Font = Enum.Font.Gotham
    controlsHint.TextSize = 9
    controlsHint.Parent = chassis

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "AbortButton"
    closeBtn.Size = UDim2.new(0, 150, 0, 32)
    closeBtn.Position = UDim2.new(0.5, -75, 1, -42)
    closeBtn.BackgroundColor3 = Color3.fromRGB(26, 30, 38)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "ABORT BYPASS [ESC]"
    closeBtn.TextColor3 = Color3.fromRGB(165, 175, 190)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 11
    local cbCorner = Instance.new("UICorner") cbCorner.CornerRadius = UDim.new(0, 6) cbCorner.Parent = closeBtn
    local cbStroke = Instance.new("UIStroke") cbStroke.Color = Color3.fromRGB(60, 68, 80) cbStroke.Thickness = 1.0 cbStroke.Parent = closeBtn
    closeBtn.Parent = chassis

    closeBtn.Activated:Connect(function()
        playClick()
        GeneratorController.Close()
    end)
end

function GeneratorController.Open(serverOrder: { number }?)
    if modalVisible or puzzleSolved then return end
    modalVisible = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    buildModal(serverOrder)
    if modalSg then
        modalSg.Enabled = true
    end
end

function GeneratorController.Close()
    modalVisible = false
    if modalSg then
        modalSg.Enabled = false
    end
    local pgGui = playerGui:FindFirstChild("TLF_GeneratorPuzzle") :: ScreenGui?
    if pgGui then
        pgGui.Enabled = false
    end
end

function GeneratorController.Init()
    modalVisible = false
    puzzleSolved = false

    UserInputService.InputBegan:Connect(function(input, gpe)
        if modalVisible then
            -- Full keyboard navigation inside puzzle modal
            if input.KeyCode == Enum.KeyCode.Escape then
                playClick()
                GeneratorController.Close()
                return
            elseif input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Right then
                playClick()
                focusCol = (focusCol == "LEFT") and "RIGHT" or "LEFT"
                refreshKeyboardHighlights()
                return
            elseif input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.W then
                playClick()
                focusRow = (focusRow == 1) and 3 or (focusRow - 1)
                refreshKeyboardHighlights()
                return
            elseif input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.S then
                playClick()
                focusRow = (focusRow == 3) and 1 or (focusRow + 1)
                refreshKeyboardHighlights()
                return
            elseif input.KeyCode == Enum.KeyCode.One then
                if leftActionFns[1] then leftActionFns[1]() end
                return
            elseif input.KeyCode == Enum.KeyCode.Two then
                if leftActionFns[2] then leftActionFns[2]() end
                return
            elseif input.KeyCode == Enum.KeyCode.Three then
                if leftActionFns[3] then leftActionFns[3]() end
                return
            elseif input.KeyCode == Enum.KeyCode.Four then
                if rightActionFns[1] then rightActionFns[1]() end
                return
            elseif input.KeyCode == Enum.KeyCode.Five then
                if rightActionFns[2] then rightActionFns[2]() end
                return
            elseif input.KeyCode == Enum.KeyCode.Six then
                if rightActionFns[3] then rightActionFns[3]() end
                return
            elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space then
                if focusCol == "LEFT" and leftActionFns[focusRow] then
                    leftActionFns[focusRow]()
                elseif focusCol == "RIGHT" and rightActionFns[focusRow] then
                    rightActionFns[focusRow]()
                end
                return
            end
            return
        end

        if gpe then return end
        if input.KeyCode ~= Enum.KeyCode.E then return end

        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root then return end

        local b1 = Workspace:FindFirstChild("TheLastFloor") and Workspace.TheLastFloor:FindFirstChild("Basement_B1")
        if not b1 then return end
        local powerVal = b1:FindFirstChild("ElevatorPower") :: BoolValue?
        if powerVal and powerVal.Value == true then return end

        local panel = b1:FindFirstChild("GeneratorPanel") :: BasePart?
            or b1:FindFirstChild("Generator") :: BasePart?
        if not panel then return end

        if (root.Position - panel.Position).Magnitude <= 22 then
            requestGenRemote:FireServer()
        end
    end)

    ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
        if player ~= localPlayer then return end
        if prompt.Name == "GeneratorPrompt" or (prompt.Parent and prompt.Parent.Name:find("Generator")) then
            requestGenRemote:FireServer()
        end
    end)

    openPuzzleRemote.OnClientEvent:Connect(function(serverOrder: { number }?)
        GeneratorController.Open(serverOrder)
    end)

    print("[GeneratorController] Upgraded circuit bypass mini-game (Schematic + Mouse/Touch/Keyboard) initialized.")
end

return GeneratorController
