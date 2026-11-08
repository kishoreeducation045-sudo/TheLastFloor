-- InventoryController.luau
-- 4-slot inventory hotbar at bottom-center
-- Slot 1: Flashlight (default, permanent)
-- Slots 2-4: Pickups (crowbar, etc.)

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryController = {}
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

local MAX_SLOTS = 4
local slots = {}           -- slot[i] = { name, symbol, color }
local selectedSlot = 1

-- Icons per item (emoji + label)
local ITEM_ICONS = {
    Flashlight = { symbol = "🔦", color = Color3.fromRGB(255, 230, 100) },
    Crowbar    = { symbol = "🔧", color = Color3.fromRGB(160, 160, 180) },
    Empty      = { symbol = "",   color = Color3.fromRGB(30, 35, 45)    },
}

local slotFrames = {}
local slotLabels = {}
local slotNames  = {}

-- Internal item list
local items = {}   -- items[i] = itemName or nil
for i = 1, MAX_SLOTS do items[i] = nil end

------------------------------------------------------------------------
-- Build HUD
------------------------------------------------------------------------
local function buildHotbar()
    local sg = Instance.new("ScreenGui")
    sg.Name  = "TheLastFloor_Inventory"
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
        slot.Name = "Slot_"..i
        slot.Size = UDim2.new(0, 60, 0, 60)
        slot.Position = UDim2.new(0, (i-1)*66, 0, 0)
        slot.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
        slot.BackgroundTransparency = 0.2
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = slot
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(50, 55, 70)
        s.Thickness = 1.5
        s.Parent = slot

        -- Slot number label (top-left)
        local numLbl = Instance.new("TextLabel")
        numLbl.Size = UDim2.new(0, 14, 0, 14)
        numLbl.Position = UDim2.new(0, 4, 0, 2)
        numLbl.BackgroundTransparency = 1
        numLbl.Text = tostring(i)
        numLbl.TextColor3 = Color3.fromRGB(100, 108, 120)
        numLbl.Font = Enum.Font.GothamBold
        numLbl.TextSize = 10
        numLbl.Parent = slot

        -- Icon label (center)
        local icon = Instance.new("TextLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(1, 0, 0, 30)
        icon.Position = UDim2.new(0, 0, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Text = ""
        icon.TextColor3 = Color3.fromRGB(255, 255, 255)
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 22
        icon.Parent = slot

        -- Item name label (bottom)
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

------------------------------------------------------------------------
-- Refresh a single slot visually
------------------------------------------------------------------------
local function refreshSlot(i)
    local frame = slotFrames[i]
    local icon  = slotLabels[i]
    local lbl   = slotNames[i]
    if not frame then return end

    local itemName = items[i]
    local info = itemName and ITEM_ICONS[itemName] or ITEM_ICONS.Empty

    icon.Text = info.symbol
    lbl.Text  = itemName or ""

    -- Selected highlight
    local stroke = frame:FindFirstChildOfClass("UIStroke")
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

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
function InventoryController.AddItem(itemName)
    -- Find first empty slot (slot 1 is reserved for flashlight)
    for i = 2, MAX_SLOTS do
        if items[i] == nil then
            items[i] = itemName
            refreshSlot(i)
            return true
        end
    end
    return false  -- inventory full
end

function InventoryController.RemoveItem(itemName)
    for i = 1, MAX_SLOTS do
        if items[i] == itemName then
            items[i] = nil
            refreshSlot(i)
            return true
        end
    end
    return false
end

function InventoryController.HasItem(itemName)
    for i = 1, MAX_SLOTS do
        if items[i] == itemName then return true end
    end
    return false
end

function InventoryController.SelectSlot(i)
    if i < 1 or i > MAX_SLOTS then return end
    selectedSlot = i
    for j = 1, MAX_SLOTS do refreshSlot(j) end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
function InventoryController.Init()
    buildHotbar()

    -- Slot 1: Flashlight always present by default
    items[1] = "Flashlight"
    for i = 1, MAX_SLOTS do refreshSlot(i) end

    -- Hotkey: 1–4 to select slots
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local keySlot = {
            [Enum.KeyCode.One]   = 1,
            [Enum.KeyCode.Two]   = 2,
            [Enum.KeyCode.Three] = 3,
            [Enum.KeyCode.Four]  = 4,
        }
        local s = keySlot[input.KeyCode]
        if s then InventoryController.SelectSlot(s) end
    end)

    -- Listen for server grant of crowbar
    local remotes = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
    local giveCrowbar = remotes:WaitForChild("GiveCrowbar")
    giveCrowbar.OnClientEvent:Connect(function()
        InventoryController.AddItem("Crowbar")
        -- Equip as actual Roblox Tool via LocalPlayer Backpack
        local CrowbarTool = ReplicatedStorage.TheLastFloor:FindFirstChild("CrowbarTool")
        if CrowbarTool then
            local clone = CrowbarTool:Clone()
            clone.Parent = localPlayer.Backpack
        end
    end)

    print("[InventoryController] 4-slot hotbar initialized. Slot 1: Flashlight.")
end

return InventoryController

