--!strict
-- Lobby Service for THE LAST FLOOR – VACCINE PROTOCOL
-- Manages 1-6 player multiplayer lobby, host controls, solo start, countdowns, and match initialization.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)

export type LobbyMember = {
    UserId: number,
    Name: string,
    DisplayName: string,
    IsHost: boolean,
    IsReady: boolean,
}

export type LobbyState = {
    Members: { LobbyMember },
    HostUserId: number?,
    IsCountingDown: boolean,
    CountdownSeconds: number,
    IsMatchStarting: boolean,
    StatusMessage: string,
}

local LobbyService = {}

local remotesFolder = ReplicatedStorage.TheLastFloor.Remotes
local lobbyStateUpdateRemote = remotesFolder:WaitForChild("LobbyStateUpdate") :: RemoteEvent
local matchStartingRemote = remotesFolder:WaitForChild("MatchStarting") :: RemoteEvent
local lobbyJoinFunction = remotesFolder:WaitForChild("LobbyJoin") :: RemoteFunction
local lobbyLeaveFunction = remotesFolder:WaitForChild("LobbyLeave") :: RemoteFunction
local lobbyStartMatchFunction = remotesFolder:WaitForChild("LobbyStartMatch") :: RemoteFunction

local lobbyMembers: { [Player]: LobbyMember } = {}
local hostPlayer: Player? = nil
local isCountingDown = false
local countdownSeconds = 5
local isMatchStarting = false
local countdownThread: thread? = nil

local function getLobbyState(): LobbyState
    local membersList: { LobbyMember } = {}
    for _, member in pairs(lobbyMembers) do
        table.insert(membersList, member)
    end

    return {
        Members = membersList,
        HostUserId = hostPlayer and hostPlayer.UserId or nil,
        IsCountingDown = isCountingDown,
        CountdownSeconds = countdownSeconds,
        IsMatchStarting = isMatchStarting,
        StatusMessage = isMatchStarting and "Deploying squad to Basement B1..." or (isCountingDown and string.format("Mission starts in %ds...", countdownSeconds) or "Waiting for squad..."),
    }
end

local function broadcastState()
    local state = getLobbyState()
    lobbyStateUpdateRemote:FireAllClients(state)
end

local function cancelCountdown()
    if isCountingDown then
        isCountingDown = false
        if countdownThread then
            task.cancel(countdownThread)
            countdownThread = nil
        end
        countdownSeconds = 5
        broadcastState()
    end
end

local function assignNewHost()
    hostPlayer = nil
    for player, member in pairs(lobbyMembers) do
        hostPlayer = player
        member.IsHost = true
        break
    end
end

function LobbyService.JoinLobby(player: Player): (boolean, string)
    if isMatchStarting then
        return false, "Match is already starting."
    end

    local memberCount = 0
    for _ in pairs(lobbyMembers) do
        memberCount += 1
    end

    if memberCount >= GameConfig.MaxPlayers then
        return false, "Lobby is full (Maximum 6 players)."
    end

    if lobbyMembers[player] then
        return true, "Already in lobby."
    end

    local isFirst = (memberCount == 0)
    if isFirst then
        hostPlayer = player
    end

    lobbyMembers[player] = {
        UserId = player.UserId,
        Name = player.Name,
        DisplayName = player.DisplayName,
        IsHost = isFirst,
        IsReady = true,
    }

    print(string.format("[LobbyService] %s joined the lobby (Count: %d/6)", player.Name, memberCount + 1))
    broadcastState()
    return true, "Joined lobby successfully."
end

function LobbyService.LeaveLobby(player: Player): (boolean, string)
    if not lobbyMembers[player] then
        return false, "Not in lobby."
    end

    lobbyMembers[player] = nil
    print(string.format("[LobbyService] %s left the lobby.", player.Name))

    if player == hostPlayer then
        assignNewHost()
    end

    -- If countdown was running and player left, re-check or cancel
    local remainingCount = 0
    for _ in pairs(lobbyMembers) do
        remainingCount += 1
    end

    if remainingCount == 0 then
        cancelCountdown()
    elseif isCountingDown then
        -- Cancel countdown if squad drops below requirement
        cancelCountdown()
    end

    broadcastState()
    return true, "Left lobby."
end

function LobbyService.StartMatch(player: Player, isSolo: boolean): (boolean, string)
    if isMatchStarting then
        return false, "Match start already in progress."
    end

    if not lobbyMembers[player] then
        return false, "You are not in the lobby."
    end

    if player ~= hostPlayer and not isSolo then
        return false, "Only the squad host can start the match."
    end

    local memberCount = 0
    for _ in pairs(lobbyMembers) do
        memberCount += 1
    end

    if memberCount < GameConfig.MinPlayers then
        return false, "Not enough players to start."
    end

    if isSolo then
        -- Instant start for solo player
        isMatchStarting = true
        broadcastState()
        task.spawn(function()
            matchStartingRemote:FireAllClients(lobbyMembers)
            print("[LobbyService] Solo mission launched!")
        end)
        return true, "Solo mission launching..."
    end

    -- Squad Countdown (5 seconds)
    if isCountingDown then
        return false, "Countdown already in progress."
    end

    isCountingDown = true
    countdownSeconds = 5
    broadcastState()

    countdownThread = task.spawn(function()
        while countdownSeconds > 0 and isCountingDown do
            task.wait(1)
            countdownSeconds -= 1
            broadcastState()
        end

        if isCountingDown and countdownSeconds <= 0 then
            isMatchStarting = true
            isCountingDown = false
            broadcastState()
            print("[LobbyService] Match countdown complete! Firing MatchStarting...")
            matchStartingRemote:FireAllClients(lobbyMembers)
        end
    end)

    return true, "Match countdown initiated."
end

function LobbyService.Init()
    -- Bind RemoteFunctions
    lobbyJoinFunction.OnServerInvoke = function(player: Player)
        return LobbyService.JoinLobby(player)
    end

    lobbyLeaveFunction.OnServerInvoke = function(player: Player)
        return LobbyService.LeaveLobby(player)
    end

    lobbyStartMatchFunction.OnServerInvoke = function(player: Player, isSolo: boolean)
        return LobbyService.StartMatch(player, isSolo)
    end

    Players.PlayerRemoving:Connect(function(player: Player)
        if lobbyMembers[player] then
            LobbyService.LeaveLobby(player)
        end
    end)

    print("[LobbyService] Initialized with 1–6 player support.")
end

return LobbyService

