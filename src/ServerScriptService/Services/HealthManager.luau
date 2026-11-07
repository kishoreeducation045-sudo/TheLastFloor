--!strict
-- Authoritative Health, Downed, Revive and Elimination Service

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes = ReplicatedStorage.TheLastFloor.Remotes
local playerDownedRemote = remotes:WaitForChild("PlayerDowned") :: RemoteEvent
local playerRevivedRemote = remotes:WaitForChild("PlayerRevived") :: RemoteEvent
local playerEliminatedRemote = remotes:WaitForChild("PlayerEliminated") :: RemoteEvent
local setSpectatorRemote = remotes:WaitForChild("SetSpectatorMode") :: RemoteEvent

type PlayerState = {
    livesUsed: number,
    isDowned: boolean,
    isSpectator: boolean,
    bleedoutThread: thread?,
}

local HealthManager = {}
local playerStates: { [Player]: PlayerState } = {}

function HealthManager.Init()
    local function onCharacterAdded(player: Player, character: Model)
        local humanoid = character:WaitForChild("Humanoid") :: Humanoid
        local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

        local state = playerStates[player]
        if not state then return end

        if state.isSpectator then
            character:Destroy()
            setSpectatorRemote:FireClient(player, true)
            return
        end

        state.isDowned = false
        humanoid.WalkSpeed = GameConfig.WalkSpeed
        humanoid.BreakJointsOnDeath = false

        humanoid.HealthChanged:Connect(function(health)
            if health <= 0 and not state.isDowned and not state.isSpectator then
                -- Enter downed state
                state.isDowned = true
                humanoid.Health = 1
                humanoid.WalkSpeed = GameConfig.DownedSpeed
                humanoid.JumpPower = 0

                playerDownedRemote:FireAllClients(player, GameConfig.DownedDuration)

                -- 5-second revive prompt for teammates
                local prompt = Instance.new("ProximityPrompt")
                prompt.Name = "RevivePrompt"
                prompt.ActionText = "Revive Teammate"
                prompt.ObjectText = player.DisplayName
                prompt.HoldDuration = GameConfig.ReviveDuration
                prompt.MaxActivationDistance = 8
                prompt.RequiresLineOfSight = false
                prompt.Parent = rootPart

                local promptConn: RBXScriptConnection
                promptConn = prompt.Triggered:Connect(function(revivingPlayer)
                    if revivingPlayer ~= player and state.isDowned then
                        state.isDowned = false
                        prompt:Destroy()
                        promptConn:Disconnect()
                        if state.bleedoutThread then
                            task.cancel(state.bleedoutThread)
                            state.bleedoutThread = nil
                        end

                        humanoid.Health = GameConfig.RevivedHealth
                        humanoid.WalkSpeed = GameConfig.WalkSpeed
                        humanoid.JumpPower = 50
                        playerRevivedRemote:FireAllClients(player, revivingPlayer)
                    end
                end)

                -- 30s Bleedout Timer
                state.bleedoutThread = task.spawn(function()
                    task.wait(GameConfig.DownedDuration)
                    if state.isDowned then
                        prompt:Destroy()
                        promptConn:Disconnect()
                        state.isDowned = false
                        state.livesUsed += 1

                        local isFinalDeath = (state.livesUsed >= GameConfig.MaxEliminationsBeforeSpectator)
                        playerEliminatedRemote:FireAllClients(player, isFinalDeath)

                        if isFinalDeath then
                            state.isSpectator = true
                            setSpectatorRemote:FireClient(player, true)
                            character:Destroy()
                        else
                            -- 1 Free return respawn at elevator
                            character:Destroy()
                            task.wait(5)
                            player:LoadCharacter()
                        end
                    end
                end)
            end
        end)
    end

    local function onPlayerAdded(player: Player)
        playerStates[player] = {
            livesUsed = 0,
            isDowned = false,
            isSpectator = false,
            bleedoutThread = nil,
        }

        player.CharacterAdded:Connect(function(char)
            onCharacterAdded(player, char)
        end)

        if player.Character then
            onCharacterAdded(player, player.Character)
        end
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p)
    end

    Players.PlayerRemoving:Connect(function(player)
        playerStates[player] = nil
    end)
end

return HealthManager

