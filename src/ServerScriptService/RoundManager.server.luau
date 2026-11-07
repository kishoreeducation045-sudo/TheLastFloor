--!strict
-- Round & Floor Lifecycle Manager for THE LAST FLOOR – VACCINE PROTOCOL

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)

local remotesFolder = ReplicatedStorage.TheLastFloor.Remotes
local floorStateChangedRemote = remotesFolder:WaitForChild("FloorStateChanged") :: RemoteEvent
local floorTimerUpdateRemote = remotesFolder:WaitForChild("FloorTimerUpdate") :: RemoteEvent

local RoundManager = {}
RoundManager.CurrentFloorIndex = 0
RoundManager.TimeRemaining = 0
RoundManager.IsRoundActive = false
local timerThread: thread? = nil

function RoundManager.StartFloor(floorIndex: number)
    local floorData = GameConfig.Floors[floorIndex + 1]
    if not floorData then
        warn(string.format("[RoundManager] Invalid floor index: %d", floorIndex))
        return
    end

    RoundManager.CurrentFloorIndex = floorIndex
    RoundManager.TimeRemaining = floorData.DurationSeconds
    RoundManager.IsRoundActive = true

    print(string.format("[RoundManager] Loading %s | Duration: %d seconds", floorData.Name, floorData.DurationSeconds))
    floorStateChangedRemote:FireAllClients(floorData.Id, floorData.Name, floorData.FloorCode, floorData.DurationSeconds)

    if timerThread then
        task.cancel(timerThread)
    end

    timerThread = task.spawn(function()
        while RoundManager.TimeRemaining > 0 and RoundManager.IsRoundActive do
            floorTimerUpdateRemote:FireAllClients(RoundManager.TimeRemaining)
            task.wait(1)
            RoundManager.TimeRemaining -= 1
        end

        if RoundManager.IsRoundActive and RoundManager.TimeRemaining <= 0 then
            RoundManager.OnTimerExpired()
        end
    end)
end

function RoundManager.OnTimerExpired()
    RoundManager.IsRoundActive = false
    print(string.format("[RoundManager] Timer expired on Floor %d! Triggering failure event...", RoundManager.CurrentFloorIndex))
    -- Floor failure event: gas breach or structural collapse
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:TakeDamage(100)
            end
        end
    end
end

function RoundManager.CompleteFloor()
    RoundManager.IsRoundActive = false
    if timerThread then
        task.cancel(timerThread)
        timerThread = nil
    end
    print(string.format("[RoundManager] Floor %d completed successfully! Elevator unlocked.", RoundManager.CurrentFloorIndex))
end

return RoundManager
