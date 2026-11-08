-- GeneratorController.luau
-- Wire connect mini-game: 3 coloured wires (Red, Blue, Yellow)
-- Click left terminal → click matching right terminal to connect
-- All 3 connected = generator fixed → fires GeneratorFixed remote

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneratorController = {}
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
local genFixedRemote = remotes:WaitForChild("GeneratorFixed")

-- Wire colour definitions
local WIRES = {
    { name = "Red",    color = Color3.fromRGB(220, 50,  50)  },
    { name = "Blue",   color = Color3.fromRGB(50,  120, 255) },
    { name = "Yellow", color = Color3.fromRGB(255, 210, 50)  },
}

local connected   = { false, false, false }   -- which wires are connected
local selectedLeft = nil                        -- index of selected left terminal
local lineFrames   = {}                         -- visual connector lines
local leftBtns     = {}
local rightBtns    = {}
local modalVisible = false
local modalSg      = nil

------------------------------------------------------------------------
-- Build the wire mini-game modal
------------------------------------------------------------------------
local function buildModal()
    if modalSg then modalSg:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TheLastFloor_Generator"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 20
    sg.Enabled = false
    sg.Parent = playerGui
    modalSg = sg

    -- Backdrop
    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.5
    backdrop.Parent = sg

    -- Modal panel
    local panel = Instance.new("Frame")
    panel.Name = "GeneratorPanel"
    panel.Size = UDim2.new(0, 460, 0, 380)
    panel.Position = UDim2.new(0.5, -230, 0.5, -190)
    panel.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0,10) pc.Parent = panel
    local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(60,70,85) ps.Thickness = 2 ps.Parent = panel
    panel.Parent = sg

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 44)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡  CIRCUIT BREAKER PANEL  ⚡"
    title.TextColor3 = Color3.fromRGB(255, 180, 30)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.Parent = panel

    -- Instruction
    local instr = Instance.new("TextLabel")
    instr.Size = UDim2.new(1, -20, 0, 24)
    instr.Position = UDim2.new(0, 10, 0, 44)
    instr.BackgroundTransparency = 1
    instr.Text = "Connect each wire on the LEFT to its matching colour on the RIGHT"
    instr.TextColor3 = Color3.fromRGB(160, 170, 185)
    instr.Font = Enum.Font.Gotham
    instr.TextSize = 12
    instr.Parent = panel

    -- Wire area (left terminals | centre canvas | right terminals)
    local wireArea = Instance.new("Frame")
    wireArea.Name = "WireArea"
    wireArea.Size = UDim2.new(1, -20, 0, 240)
    wireArea.Position = UDim2.new(0, 10, 0, 76)
    wireArea.BackgroundTransparency = 1
    wireArea.Parent = panel

    -- LEFT terminals column
    local leftCol = Instance.new("Frame")
    leftCol.Size = UDim2.new(0, 80, 1, 0)
    leftCol.Position = UDim2.new(0, 0, 0, 0)
    leftCol.BackgroundTransparency = 1
    leftCol.Parent = wireArea

    -- RIGHT terminals column (shuffled order)
    local rightCol = Instance.new("Frame")
    rightCol.Size = UDim2.new(0, 80, 1, 0)
    rightCol.Position = UDim2.new(1, -80, 0, 0)
    rightCol.BackgroundTransparency = 1
    rightCol.Parent = wireArea

    -- Centre canvas for wire lines
    local canvas = Instance.new("Frame")
    canvas.Name = "LineCanvas"
    canvas.Size = UDim2.new(1, -180, 1, 0)
    canvas.Position = UDim2.new(0, 90, 0, 0)
    canvas.BackgroundTransparency = 1
    canvas.ClipsDescendants = true
    canvas.Parent = wireArea

    -- Shuffle right side order for puzzle
    local rightOrder = {1, 2, 3}
    -- Simple shuffle
    for i = #rightOrder, 2, -1 do
        local j = math.random(1, i)
        rightOrder[i], rightOrder[j] = rightOrder[j], rightOrder[i]
    end

    local function makeTerminal(parent, wireIdx, isRight, yPos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 50)
        btn.Position = UDim2.new(0, 5, 0, yPos)
        btn.BackgroundColor3 = WIRES[wireIdx].color
        btn.Text = WIRES[wireIdx].name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = btn
        local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(255,255,255) bs.Thickness = 1.5 bs.Parent = btn
        btn.Parent = parent
        return btn
    end

    local rightMapping = {}  -- rightMapping[screenPosition] = wireIdx

    for i, wireIdx in ipairs(WIRES) do
        local yPos = (i - 1) * 75 + 20
        local lb = makeTerminal(leftCol, i, false, yPos)
        leftBtns[i] = lb

        -- Place right terminal at shuffled position
        local rightPos = rightOrder[i]
        local ryPos = (rightPos - 1) * 75 + 20
        local rb = makeTerminal(rightCol, i, true, ryPos)
        rightBtns[i] = rb
        rightMapping[rightPos] = i  -- which wire is at this visual position

        -- Left click selects
        lb.Activated:Connect(function()
            if connected[i] then return end
            selectedLeft = i
            -- Highlight selected
            for j, b in ipairs(leftBtns) do
                local stroke = b:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color = (j == i) and Color3.fromRGB(255, 255, 100) or Color3.fromRGB(255,255,255)
                    stroke.Thickness = (j == i) and 3 or 1.5
                end
            end
        end)

        -- Right click attempts connection
        rb.Activated:Connect(function()
            if selectedLeft == nil then return end
            if connected[selectedLeft] then return end

            -- Check if this right terminal matches selected left
            if selectedLeft == i then
                -- Correct connection!
                connected[i] = true
                lb.BackgroundTransparency = 0.3
                rb.BackgroundTransparency = 0.3

                -- Draw a line in canvas
                local line = Instance.new("Frame")
                line.Name = "WireLine_"..i
                line.Size = UDim2.new(1, 0, 0, 4)
                -- Position it vertically centered between left and right terminal mid-points
                local leftMidY  = yPos + 25
                local rightMidY = ryPos + 25
                local topY    = math.min(leftMidY, rightMidY)
                local botY    = math.max(leftMidY, rightMidY)
                local lineH   = math.max(4, botY - topY)
                line.Position = UDim2.new(0, 0, 0, topY)
                line.Size = UDim2.new(1, 0, 0, lineH)
                line.BackgroundColor3 = WIRES[i].color
                line.BackgroundTransparency = 0.1
                local lc = Instance.new("UICorner") lc.CornerRadius = UDim.new(0,2) lc.Parent = line
                line.Parent = canvas
                table.insert(lineFrames, line)

                selectedLeft = nil
                for _, b in ipairs(leftBtns) do
                    local stroke = b:FindFirstChildOfClass("UIStroke")
                    if stroke then stroke.Color = Color3.fromRGB(255,255,255) stroke.Thickness = 1.5 end
                end

                -- Check if all connected
                local allDone = true
                for _, c in ipairs(connected) do if not c then allDone = false break end end
                if allDone then
                    -- Success animation
                    title.Text = "✅  CIRCUIT RESTORED"
                    title.TextColor3 = Color3.fromRGB(50, 255, 100)
                    task.delay(1.5, function()
                        sg.Enabled = false
                        modalVisible = false
                        -- Fire server
                        genFixedRemote:FireServer()
                    end)
                end
            else
                -- Wrong connection — flash red
                rb.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                task.delay(0.5, function()
                    rb.BackgroundColor3 = WIRES[i].color
                end)
            end
        end)
    end

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 120, 0, 34)
    closeBtn.Position = UDim2.new(0.5, -60, 1, -44)
    closeBtn.Text = "CANCEL"
    closeBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
    closeBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,6) cc.Parent = closeBtn
    closeBtn.Parent = panel
    closeBtn.Activated:Connect(function()
        sg.Enabled = false
        modalVisible = false
    end)
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
function GeneratorController.Open()
    if modalVisible then return end
    -- Reset state
    for i = 1, #WIRES do connected[i] = false end
    selectedLeft = nil
    lineFrames = {}
    buildModal()
    modalSg.Enabled = true
    modalVisible = true
end

function GeneratorController.Init()
    buildModal()

    -- Listen for generator panel proximity prompt
    task.spawn(function()
        local b1 = workspace:WaitForChild("TheLastFloor"):WaitForChild("Basement_B1")
        local genPanel = b1:WaitForChild("GeneratorPanel")
        local pp = genPanel:WaitForChild("GeneratorPrompt")
        pp.Triggered:Connect(function()
            GeneratorController.Open()
        end)
    end)

    print("[GeneratorController] Wire mini-game initialized.")
end

return GeneratorController

