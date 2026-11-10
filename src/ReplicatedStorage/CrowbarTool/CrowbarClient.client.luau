--!strict
-- CrowbarClient.client.luau
-- Plays 3-second prying animation synced with server pry validation and forwards manual activation near JammedBeam.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local tool        = script.Parent :: Tool
local localPlayer = Players.LocalPlayer
local remotes     = ReplicatedStorage:WaitForChild("TheLastFloor"):WaitForChild("Remotes")

local beamPriedRemote       = remotes:WaitForChild("BeamPried") :: RemoteEvent
local crowbarPryStateRemote = remotes:WaitForChild("CrowbarPryState") :: RemoteEvent

local isAnimating = false

local function playPryAnimation(duration: number)
    if isAnimating then return end
    isAnimating = true

    local origGrip = tool.Grip
    local cam = Workspace.CurrentCamera
    local steps = math.max(4, math.floor((duration or 3.0) / 0.35))
    local stepDur = (duration or 3.0) / steps

    task.spawn(function()
        for i = 1, steps do
            if not tool or not tool.Parent then break end
            local tilt = (i % 2 == 1) and CFrame.Angles(math.rad(-28), 0, math.rad(14)) or CFrame.Angles(math.rad(12), 0, math.rad(-8))
            TweenService:Create(tool, TweenInfo.new(stepDur * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Grip = origGrip * tilt
            }):Play()

            if cam then
                cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((i % 2 == 1) and -0.8 or 0.6), 0, 0)
            end
            task.wait(stepDur)
        end

        if tool and tool.Parent then
            tool.Grip = origGrip
        end
        isAnimating = false
    end)
end

-- Server triggers pry animation whenever E (PryPrompt) or click initiates valid pry
local conn = crowbarPryStateRemote.OnClientEvent:Connect(function(action: string, dur: number)
    if action == "StartPry" then
        playPryAnimation(dur or 3.0)
    end
end)

tool.Destroying:Connect(function()
    conn:Disconnect()
end)

-- Also allow left-click when equipped right in front of JammedBeam (server enforces 3s pry & validation)
tool.Activated:Connect(function()
    if isAnimating then return end
    local tlf = Workspace:FindFirstChild("TheLastFloor")
    local b1 = tlf and tlf:FindFirstChild("Basement_B1")
    local beam = b1 and b1:FindFirstChild("JammedBeam") :: BasePart?
    if not beam then return end

    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root or (root.Position - beam.Position).Magnitude > 14 then return end

    beamPriedRemote:FireServer()
end)

