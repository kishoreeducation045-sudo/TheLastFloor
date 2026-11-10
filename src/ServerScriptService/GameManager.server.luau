--!strict
-- Master Game Manager for THE LAST FLOOR – VACCINE PROTOCOL

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")

local services        = ServerScriptService:WaitForChild("TheLastFloor"):WaitForChild("Services")
local HealthManager   = require(services:WaitForChild("HealthManager")) :: any
local LobbyService    = require(services:WaitForChild("LobbyService")) :: any
local ElevatorService = require(services:WaitForChild("ElevatorService")) :: any
local FloorManager    = require(services:WaitForChild("FloorManager")) :: any

print("[GameManager] Booting THE LAST FLOOR – VACCINE PROTOCOL (Vertical Slice)...")

HealthManager.Init()
LobbyService.Init()
FloorManager.Init(ElevatorService, HealthManager)

-- Connect Elevator Cabin once Workspace loaded
task.spawn(function()
    local tlfWS = Workspace:WaitForChild("TheLastFloor")
    local elevFolder = tlfWS:WaitForChild("Elevator")
    local cabin = elevFolder:WaitForChild("ElevatorCabin") :: Model
    ElevatorService.BindCabin(cabin)
    ElevatorService.UpdateScreen("THE LAST FLOOR", "B1: BASEMENT – LOCKED")
    print("[GameManager] Elevator bound and locked.")

    local remotes = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")
    local matchStartingRemote = remotes:WaitForChild("MatchStarting") :: RemoteEvent
    matchStartingRemote.OnServerEvent:Connect(function()
        FloorManager.StartFloor(0)
    end)

    task.wait(2)
    FloorManager.StartFloor(0)
end)

print("[GameManager] System ready.")
