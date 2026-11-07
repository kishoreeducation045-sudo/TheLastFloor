--!strict
-- ElevatorService for THE LAST FLOOR – VACCINE PROTOCOL

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ElevatorService = {}
ElevatorService.IsLocked = true
ElevatorService.IsOpen = false
ElevatorService.CurrentFloorIndex = 0

local cabin: Model? = nil
local doorLeft: BasePart? = nil
local doorRight: BasePart? = nil
local closedPosLeft: Vector3? = nil
local closedPosRight: Vector3? = nil
local openPosLeft: Vector3? = nil
local openPosRight: Vector3? = nil
local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function ElevatorService.BindCabin(cabinModel: Model)
    cabin = cabinModel
    doorLeft = cabin:WaitForChild("DoorLeft") :: BasePart
    doorRight = cabin:WaitForChild("DoorRight") :: BasePart
    closedPosLeft = doorLeft.Position
    closedPosRight = doorRight.Position
    openPosLeft = closedPosLeft - Vector3.new(3.5, 0, 0)
    openPosRight = closedPosRight + Vector3.new(3.5, 0, 0)
end

function ElevatorService.SetDoors(open: boolean)
    if not doorLeft or not doorRight or not openPosLeft or not closedPosLeft or not openPosRight or not closedPosRight then return end
    ElevatorService.IsOpen = open
    local targetL = open and openPosLeft or closedPosLeft
    local targetR = open and openPosRight or closedPosRight

    local t1 = TweenService:Create(doorLeft, tweenInfo, {Position = targetL})
    local t2 = TweenService:Create(doorRight, tweenInfo, {Position = targetR})
    t1:Play()
    t2:Play()
    t1.Completed:Wait()
end

function ElevatorService.Unlock()
    ElevatorService.IsLocked = false
    print("[ElevatorService] Elevator unlocked! Opening doors...")
    ElevatorService.SetDoors(true)
    ElevatorService.UpdateScreen("ELEVATOR UNLOCKED", "BOARD TO PROCEED")
end

function ElevatorService.UpdateScreen(title: string, status: string)
    if not cabin then return end
    local screen = cabin:FindFirstChild("ElevatorScreen")
    if screen and screen:FindFirstChild("SurfaceGui") then
        local sg = screen.SurfaceGui :: SurfaceGui
        local frame = sg:FindFirstChild("Frame") :: Frame?
        if frame then
            local tl = frame:FindFirstChild("TitleLabel") :: TextLabel?
            local sl = frame:FindFirstChild("StatusLabel") :: TextLabel?
            if tl then tl.Text = title end
            if sl then sl.Text = status end
        end
    end
end

return ElevatorService

