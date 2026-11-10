--!strict
-- HealthManager.luau
-- Authoritative player health, downed crawl state, 5s revive, 1 free checkpoint return, and permanent spectator transition.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local remotes    = ReplicatedStorage.TheLastFloor.Remotes

local downedRemote       = remotes:WaitForChild("PlayerDowned") :: RemoteEvent
local revivedRemote      = remotes:WaitForChild("PlayerRevived") :: RemoteEvent
local elimRemote         = remotes:WaitForChild("PlayerEliminated") :: RemoteEvent
local setSpectatorRemote = remotes:WaitForChild("SetSpectatorMode") :: RemoteEvent

local HealthManager = {}

export type PlayerState = {
    isDowned: boolean,
    bleedoutRemaining: number,
    isSpectator: boolean,
    isReturning: boolean,
    eliminations: number,
    reviveProgress: number,
    revivingPlayer: Player?,
}

local playerStates: { [Player]: PlayerState } = {}
local activeCheckpoint: CFrame = CFrame.new(60, 3.5, -55) * CFrame.Angles(0, math.rad(-90), 0)

function HealthManager.SetCheckpoint(cf: CFrame)
    activeCheckpoint = cf
end

function HealthManager.GetState(player: Player): PlayerState?
    return playerStates[player]
end

function HealthManager.IsSpectator(player: Player): boolean
    local s = playerStates[player]
    return s ~= nil and s.isSpectator
end

function HealthManager.IsDowned(player: Player): boolean
    local s = playerStates[player]
    return s ~= nil and s.isDowned
end

function HealthManager.IsActivePlayer(player: Player): boolean
    local s = playerStates[player]
    if not s or s.isSpectator then
        return false
    end
    return true
end

function HealthManager.onCharacterAdded(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid") :: Humanoid
    local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

    -- Disable default Roblox auto-heal so damage & downed bleedout stay faithful to horror balance
    local regenScript = character:FindFirstChild("Health")
    if regenScript then
        regenScript:Destroy()
    end

    local state = playerStates[player]
    if not state then return end

    if state.isSpectator then
        task.defer(function()
            if character and character.Parent then
                character:Destroy()
            end
        end)
        setSpectatorRemote:FireClient(player, true)
        return
    end

    state.isDowned = false
    state.isReturning = false
    humanoid.MaxHealth = GameConfig.MaxHealth
    humanoid.Health    = GameConfig.MaxHealth
    humanoid.WalkSpeed = GameConfig.WalkSpeed
    humanoid.JumpPower = 50
    humanoid.PlatformStand = false
    humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
    humanoid.BreakJointsOnDeath = false

    -- Authoritative checkpoint spawn inside active level
    task.defer(function()
        if rootPart and rootPart.Parent then
            rootPart.CFrame = activeCheckpoint
        end
    end)

    -- Re-grant CrowbarTool if player already carried it before free return
    if player:GetAttribute("HasCrowbar") == true then
        local tlf = ReplicatedStorage:FindFirstChild("TheLastFloor")
        local crowbarTemplate = tlf and tlf:FindFirstChild("CrowbarTool")
        if crowbarTemplate then
            local clone = crowbarTemplate:Clone()
            clone.Parent = player:WaitForChild("Backpack")
        end
    end

    local hookedDowned = false
    humanoid.HealthChanged:Connect(function(health)
        if health <= 0 and not hookedDowned and not state.isDowned and not state.isSpectator then
            hookedDowned = true
            state.isDowned = true
            humanoid.Health = 1
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0

            humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
            humanoid.PlatformStand = true
            humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)

            task.defer(function()
                if rootPart and rootPart.Parent then
                    rootPart.CFrame = rootPart.CFrame * CFrame.Angles(math.rad(-85), 0, 0)
                end
            end)

            downedRemote:FireAllClients(player, GameConfig.DownedDuration)
            state.bleedoutRemaining = GameConfig.DownedDuration

            local prompt = Instance.new("ProximityPrompt")
            prompt.Name = "RevivePrompt"
            prompt.ActionText = "Revive Teammate"
            prompt.ObjectText = player.DisplayName
            prompt.HoldDuration = GameConfig.ReviveDuration
            prompt.MaxActivationDistance = 8
            prompt.RequiresLineOfSight = false
            prompt.Parent = rootPart

            local promptConn: RBXScriptConnection?
            promptConn = prompt.Triggered:Connect(function(revivingPlayer: Player)
                if revivingPlayer ~= player and not HealthManager.IsDowned(revivingPlayer) and not HealthManager.IsSpectator(revivingPlayer) then
                    hookedDowned = false
                    HealthManager.RevivePlayer(player)
                    if promptConn then promptConn:Disconnect() end
                    if prompt and prompt.Parent then prompt:Destroy() end
                end
            end)

            task.spawn(function()
                while state.isDowned and state.bleedoutRemaining > 0 and player.Parent == Players do
                    task.wait(1)
                    state.bleedoutRemaining -= 1
                end

                if state.isDowned and state.bleedoutRemaining <= 0 and player.Parent == Players then
                    if prompt and prompt.Parent then prompt:Destroy() end
                    HealthManager.EliminatePlayer(player)
                end
            end)
        end
    end)
end

function HealthManager.RevivePlayer(player: Player)
    local state = playerStates[player]
    if not state or not state.isDowned then return end

    state.isDowned = false
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?

    if humanoid and rootPart then
        humanoid.PlatformStand = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        humanoid.Health = GameConfig.RevivedHealth
        humanoid.WalkSpeed = GameConfig.WalkSpeed
        humanoid.JumpPower = 50
        rootPart.CFrame = CFrame.new(rootPart.Position.X, 3.5, rootPart.Position.Z)

        local oldPrompt = rootPart:FindFirstChild("RevivePrompt")
        if oldPrompt then oldPrompt:Destroy() end
    end

    revivedRemote:FireAllClients(player, GameConfig.RevivedHealth)
    print(string.format("[HealthManager] %s was revived with %d HP", player.Name, GameConfig.RevivedHealth))
end

function HealthManager.EliminatePlayer(player: Player)
    local state = playerStates[player]
    if not state or state.isSpectator then return end

    state.isDowned = false
    state.eliminations += 1
    player:SetAttribute("Eliminations", state.eliminations)

    local character = player.Character
    if character then
        character:Destroy()
    end

    -- Grant 1 Free Return on first elimination (MaxEliminationsBeforeSpectator == 2)
    if state.eliminations < GameConfig.MaxEliminationsBeforeSpectator then
        state.isReturning = true
        local delaySec = GameConfig.FreeReturnDelay or 5.0
        elimRemote:FireAllClients(player, true, delaySec)
        print(string.format("[HealthManager] %s downed-out #1 -> Free checkpoint return in %.1fs", player.Name, delaySec))

        task.delay(delaySec, function()
            if player.Parent == Players and not state.isSpectator then
                state.isReturning = false
                player:LoadCharacter()
            end
        end)
    else
        state.isReturning = false
        state.isSpectator = true
        elimRemote:FireAllClients(player, false, 0)
        setSpectatorRemote:FireClient(player, true)
        print(string.format("[HealthManager] %s eliminated #%d -> Permanent Spectator", player.Name, state.eliminations))
    end
end

local function registerPlayer(player: Player)
    if playerStates[player] then return end
    playerStates[player] = {
        isDowned          = false,
        bleedoutRemaining = GameConfig.DownedDuration,
        isSpectator       = false,
        isReturning       = false,
        eliminations      = 0,
        reviveProgress    = 0,
        revivingPlayer    = nil,
    }
    player:SetAttribute("Eliminations", 0)

    player.CharacterAdded:Connect(function(char)
        HealthManager.onCharacterAdded(player, char)
    end)

    if player.Character then
        task.spawn(function()
            HealthManager.onCharacterAdded(player, player.Character)
        end)
    end
end

function HealthManager.Init()
    for _, existing in ipairs(Players:GetPlayers()) do
        registerPlayer(existing)
    end

    Players.PlayerAdded:Connect(registerPlayer)

    Players.PlayerRemoving:Connect(function(player)
        playerStates[player] = nil
    end)

    print("[HealthManager] Initialized with Downed crawl, 5s Revive, 1 Free Return & Spectator mode.")
end

return HealthManager
