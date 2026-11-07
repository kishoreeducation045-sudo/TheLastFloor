--!strict
-- Master Game Manager for THE LAST FLOOR – VACCINE PROTOCOL

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.TheLastFloor.Configuration.GameConfig)
local HealthManager = require(ServerScriptService.TheLastFloor.Services.HealthManager)

print("[GameManager] Initializing THE LAST FLOOR – VACCINE PROTOCOL...")

HealthManager.Init()

local function onPlayerAdded(player: Player)
    print(string.format("[GameManager] Player joined: %s (UserId: %d)", player.Name, player.UserId))
end

local function onPlayerRemoving(player: Player)
    print(string.format("[GameManager] Player leaving: %s", player.Name))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[GameManager] Core services initialized successfully.")
