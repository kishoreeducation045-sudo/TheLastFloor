--!strict
-- FloorManager for THE LAST FLOOR – VACCINE PROTOCOL
-- Manages server-authoritative floor timers and floor puzzle submissions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes = ReplicatedStorage.TheLastFloor.Remotes
local floorStateRemote = remotes:WaitForChild("FloorStateChanged") :: RemoteEvent
local floorTimerRemote = remotes:WaitForChild("FloorTimerUpdate") :: RemoteEvent
local submitKeypadFunc = remotes:WaitForChild("SubmitKeypadCode") :: RemoteFunction

local FloorManager = {}
FloorManager.CurrentFloorIndex = 0
FloorManager.TimeRemaining = 120
FloorManager.IsActive = false
FloorManager.B1CorrectCode = "4815"
local timerThread: thread? = nil

function FloorManager.StartFloor(floorIndex: number)
    FloorManager.CurrentFloorIndex = floorIndex
    local data = GameConfig.Floors[floorIndex + 1]
    if not data then return end

    FloorManager.TimeRemaining = data.DurationSeconds
    FloorManager.IsActive = true

    print(string.format("[FloorManager] Commencing %s | Time: %ds", data.Name, data.DurationSeconds))
    floorStateRemote:FireAllClients(data.Id, data.Name, data.FloorCode, data.DurationSeconds, data.Description)

    if timerThread then task.cancel(timerThread) end
    timerThread = task.spawn(function()
        while FloorManager.TimeRemaining > 0 and FloorManager.IsActive do
            floorTimerRemote:FireAllClients(FloorManager.TimeRemaining)
            task.wait(1)
            FloorManager.TimeRemaining -= 1
        end

        if FloorManager.IsActive and FloorManager.TimeRemaining <= 0 then
            FloorManager.OnTimerExpired()
        end
    end)
end

function FloorManager.OnTimerExpired()
    FloorManager.IsActive = false
    print("[FloorManager] Timer Expired! Floor failure event triggered.")
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        local h = c and c:FindFirstChildOfClass("Humanoid") :: Humanoid?
        if h then h:TakeDamage(100) end
    end
end

function FloorManager.Init(ElevatorService: any)
    local d1 = math.random(1, 9)
    local d2 = math.random(0, 9)
    local d3 = math.random(0, 9)
    local d4 = math.random(0, 9)
    FloorManager.B1CorrectCode = string.format("%d%d%d%d", d1, d2, d3, d4)
    print(string.format("[FloorManager] B1 Keypad Solution generated: %s", FloorManager.B1CorrectCode))

    submitKeypadFunc.OnServerInvoke = function(player: Player, enteredCode: any)
        if tostring(enteredCode) == FloorManager.B1CorrectCode then
            print(string.format("[FloorManager] Player %s entered correct B1 Code!", player.Name))
            ElevatorService.Unlock()
            return true, "CODE ACCEPTED. ELEVATOR UNLOCKED."
        else
            return false, "INVALID CODE. ACCESS DENIED."
        end
    end
end

return FloorManager

