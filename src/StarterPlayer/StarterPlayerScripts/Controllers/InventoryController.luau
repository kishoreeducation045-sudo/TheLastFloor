--!strict
-- InventoryController.luau
-- 4-slot inventory hotbar at bottom-center synchronized with server Backpack & attributes.
-- Slot 1: Flashlight (default, permanent)
-- Slots 2-4: Puzzle & survival items (Crowbar, etc.)

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local InventoryController = {}
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local MAX_SLOTS = 4
local selectedSlot = 1

local ITEM_ICONS: { [string]: { symbol: string, color: Color3 } } = {
    Flashlight = { symbol = "F", color = Color3.fromRGB(255, 230, 100) },
    Crowbar    = { symbol = "C", color = Color3.fromRGB(220, 120, 95) },
    Empty      = { symbol = "",  color = Color3.fromRGB(30, 35, 45) },
}

local slotFrames: { [number]: Frame } = {}
local slotLabels: { [number]: TextLabel } = {}
local slotNames: { [number]: TextLabel } = {}
local items: { [number]: string? } = { "Flashlight", nil, nil, nil }

local function refreshSlot(i: number)
    local frame = slotFrames[i]
    local icon  = slotLabels[i]
    local lbl   = slotNames[i]
    if not frame or not icon or not lbl then return end

    local itemName = items[i]
    local info = (itemName and ITEM_ICONS[itemName]) or ITEM_ICONS.Empty

    icon.Text = info.symbol
    icon.TextColor3 = info.color
    lbl.Text  = itemName or ""

    local stroke = frame:FindFirstChildOfClass("UIStroke")
    if stroke then
        if i == selectedSlot and itemName then
            stroke.Color = Color3.fromRGB(255, 200, 50)
            stroke.Thickness = 2.5
            frame.BackgroundColor3 = Color3.fromRGB(30, 35, 25)
        else
            stroke.Color = Color3.fromRGB(50, 55, 70)
            stroke.Thickness = 1.5
            frame.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
        end
    end
end

local function pulseSlot(i: number)
    local frame = slotFrames[i]
    if not frame then return end
    local orig = frame.Size
    frame.Size = UDim2.new(0, 68, 0, 68)
    TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = orig
    }):Play()
end

local function buildHotbar(): ScreenGui
    local existing = playerGui:FindFirstChild("TheLastFloor_Inventory")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TheLastFloor_Inventory"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 6
    sg.Parent = playerGui

    local container = Instance.new("Frame")
    container.Name = "HotbarContainer"
    container.Size = UDim2.new(0, MAX_SLOTS * 68, 0, 70)
    container.Position = UDim2.new(0.5, -(MAX_SLOTS * 68 / 2), 1, -90)
    container.BackgroundTransparency = 1
    container.Parent = sg

    for i = 1, MAX_SLOTS do
        local slot = Instance.new("Frame")
        slot.Name = "Slot_" .. i
        slot.Size = UDim2.new(0, 60, 0, 60)
        slot.Position = UDim2.new(0, (i - 1) * 66, 0, 0)
        slot.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
        slot.BackgroundTransparency = 0.2
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = slot
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(50, 55, 70) s.Thickness = 1.5 s.Parent = slot

        local numLbl = Instance.new("TextLabel")
        numLbl.Size = UDim2.new(0, 14, 0, 14)
        numLbl.Position = UDim2.new(0, 4, 0, 2)
        numLbl.BackgroundTransparency = 1
        numLbl.Text = tostring(i)
        numLbl.TextColor3 = Color3.fromRGB(100, 108, 120)
        numLbl.Font = Enum.Font.GothamBold
        numLbl.TextSize = 10
        numLbl.Parent = slot

        local icon = Instance.new("TextLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(1, 0, 0, 30)
        icon.Position = UDim2.new(0, 0, 0, 8)
        icon.BackgroundTransparency = 1
        icon.Text = ""
        icon.TextColor3 = Color3.fromRGB(255, 255, 255)
        icon.Font = Enum.Font.GothamBlack
        icon.TextSize = 18
        icon.Parent = slot

        local name = Instance.new("TextLabel")
        name.Name = "ItemName"
        name.Size = UDim2.new(1, -4, 0, 14)
        name.Position = UDim2.new(0, 2, 1, -16)
        name.BackgroundTransparency = 1
        name.Text = ""
        name.TextColor3 = Color3.fromRGB(180, 185, 200)
        name.Font = Enum.Font.Gotham
        name.TextSize = 9
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Parent = slot

        slot.Parent = container
        slotFrames[i] = slot
        slotLabels[i] = icon
        slotNames[i]  = name
    end

    return sg
end

function InventoryController.AddItem(itemName: string): boolean
    if InventoryController.HasItem(itemName) then return true end
    for i = 2, MAX_SLOTS do
        if items[i] == nil then
            items[i] = itemName
            refreshSlot(i)
            pulseSlot(i)
            return true
        end
    end
    return false
end

function InventoryController.RemoveItem(itemName: string): boolean
    for i = 2, MAX_SLOTS do
        if items[i] == itemName then
            items[i] = nil
            if selectedSlot == i then
                selectedSlot = 1
            end
            for j = 1, MAX_SLOTS do refreshSlot(j) end
            return true
        end
    end
    return false
end

function InventoryController.HasItem(itemName: string): boolean
    for i = 1, MAX_SLOTS do
        if items[i] == itemName then return true end
    end
    return false
end

function InventoryController.SelectSlot(i: number)
    if i < 1 or i > MAX_SLOTS then return end
    selectedSlot = i
    for j = 1, MAX_SLOTS do refreshSlot(j) end

    -- Sync actual equipped tool for Backpack items (Crowbar)
    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if items[i] == "Crowbar" then
            local bag = localPlayer:FindFirstChild("Backpack")
            local tool = bag and bag:FindFirstChild("CrowbarTool") :: Tool?
            if tool then hum:EquipTool(tool) end
        else
            hum:UnequipTools()
        end
    end
end

function InventoryController.Init()
    buildHotbar()
    items = { "Flashlight", nil, nil, nil }
    for i = 1, MAX_SLOTS do refreshSlot(i) end

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local genGui = playerGui:FindFirstChild("TLF_GeneratorPuzzle") :: ScreenGui?
        if genGui and genGui.Enabled then return end

        local ks = {
            [Enum.KeyCode.One]   = 1,
            [Enum.KeyCode.Two]   = 2,
            [Enum.KeyCode.Three] = 3,
            [Enum.KeyCode.Four]  = 4,
        }
        local s = ks[input.KeyCode]
        if s then
            InventoryController.SelectSlot(s)
        end
    end)

    local remotes = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
    local function handleSync(action: string?, itemName: string?)
        local item = itemName or "Crowbar"
        if action == "Remove" then
            InventoryController.RemoveItem(item)
        else
            if InventoryController.AddItem(item) then
                -- Auto-select Crowbar slot on pickup for visual confirmation!
                for idx = 2, MAX_SLOTS do
                    if items[idx] == item then
                        InventoryController.SelectSlot(idx)
                        break
                    end
                end
            end
        end
    end

    local syncRemote = remotes:FindFirstChild("InventorySync") :: RemoteEvent?
    if syncRemote then
        syncRemote.OnClientEvent:Connect(handleSync)
    end
    local giveCrowbar = remotes:WaitForChild("GiveCrowbar") :: RemoteEvent
    giveCrowbar.OnClientEvent:Connect(function(action, itemName)
        if not syncRemote then
            handleSync(action or "Add", itemName or "Crowbar")
        end
    end)

    -- Keep in sync across checkpoint respawns
    localPlayer.CharacterAdded:Connect(function()
        task.wait(0.2)
        if localPlayer:GetAttribute("HasCrowbar") == true then
            InventoryController.AddItem("Crowbar")
        else
            InventoryController.RemoveItem("Crowbar")
        end
    end)

    print("[InventoryController] Synchronized 4-slot hotbar initialized.")
end

return InventoryController
