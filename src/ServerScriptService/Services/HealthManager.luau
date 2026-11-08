--!strict
-- Authoritative Health, Downed, Revive and Elimination Service
-- Implements fall-to-ground downed state, 5-second revive, and checkpoint respawn.

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
        humanoid.PlatformStand = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        humanoid.BreakJointsOnDeath = false

        humanoid.HealthChanged:Connect(function(health)
            if health <= 0 and not state.isDowned and not state.isSpectator then
                -- Enter downed state: Fall to the ground limp
                state.isDowned = true
                humanoid.Health = 1
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
                humanoid.JumpHeight = 0

                -- Physics fall down: Disable getting up & enable PlatformStand
                humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
                humanoid.PlatformStand = true
                humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)

                -- Tilt character onto the floor
                task.defer(function()
                    if rootPart and rootPart.Parent then
                        rootPart.CFrame = rootPart.CFrame * CFrame.Angles(math.rad(-85), 0, 0)
                    end
                end)

                playerDownedRemote:FireAllClients(player, GameConfig.DownedDuration)

                -- 5-second hold ProximityPrompt for teammates
                local prompt = Instance.new("ProximityPrompt")
                prompt.Name = "RevivePrompt"
                prompt.ActionText = "Revive Teammate"
                prompt.ObjectText = player.DisplayName
                prompt.HoldDuration = 5.0 -- Exactly 5 seconds
                prompt.MaxActivationDistance = 9
                prompt.RequiresLineOfSight = false
                prompt.Parent = rootPart

                local promptConn: RBXScriptConnection
                promptConn = prompt.Triggered:Connect(function(revivingPlayer)
                    if revivingPlayer ~= player and state.isDowned then
                        state.isDowned = false
                        if prompt then prompt:Destroy() end
                        if promptConn then promptConn:Disconnect() end
                        if state.bleedoutThread then
                            task.cancel(state.bleedoutThread)
                            state.bleedoutThread = nil
                        end

                        -- Restore player upright
                        humanoid.PlatformStand = false
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
                        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                        if rootPart and rootPart.Parent then
                            rootPart.CFrame = CFrame.new(rootPart.Position.X, rootPart.Position.Y + 3, rootPart.Position.Z)
                        end

                        humanoid.Health = GameConfig.RevivedHealth
                        humanoid.WalkSpeed = GameConfig.WalkSpeed
                        humanoid.JumpPower = 50
                        humanoid.JumpHeight = 7.2

                        playerRevivedRemote:FireAllClients(player, revivingPlayer)
                        print(string.format("[HealthManager] %s was revived by %s (Restored to %d HP)", player.Name, revivingPlayer.Name, GameConfig.RevivedHealth))
                    end
                end)

                -- 30s Bleedout Timer
                state.bleedoutThread = task.spawn(function()
                    task.wait(GameConfig.DownedDuration)
                    if state.isDowned then
                        if prompt then prompt:Destroy() end
                        if promptConn then promptConn:Disconnect() end
                        state.isDowned = false
                        state.livesUsed += 1

                        local isFinalDeath = (state.livesUsed >= GameConfig.MaxEliminationsBeforeSpectator)
                        playerEliminatedRemote:FireAllClients(player, isFinalDeath)

                        if isFinalDeath then
                            state.isSpectator = true
                            setSpectatorRemote:FireClient(player, true)
                            character:Destroy()
                            print(string.format("[HealthManager] %s eliminated (Moved to Spectator)", player.Name))
                        else
                            -- 1 Free return respawn at checkpoint
                            character:Destroy()
                            task.wait(GameConfig.FreeReturnDelay)
                            player:LoadCharacter()
                            print(string.format("[HealthManager] %s used free return checkpoint", player.Name))
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

    print("[HealthManager] Initialized with Fall-to-Ground Downed state & 5s Revive.")
end

return HealthManager
