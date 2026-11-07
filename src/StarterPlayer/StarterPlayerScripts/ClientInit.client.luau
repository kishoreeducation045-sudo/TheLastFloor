--!strict
-- Client Bootstrap for THE LAST FLOOR – VACCINE PROTOCOL

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
print(string.format("[ClientInit] Initializing client subsystems for %s...", localPlayer.Name))

-- Controllers will be required and initialized here
local controllersFolder = script.Parent:WaitForChild("Controllers")
for _, child in ipairs(controllersFolder:GetChildren()) do
    if child:IsA("ModuleScript") then
        local success, result = pcall(function()
            local module = require(child) :: any
            if type(module) == "table" and type(module.Init) == "function" then
                module.Init()
            end
        end)
        if not success then
            warn(string.format("[ClientInit] Failed to initialize controller %s: %s", child.Name, tostring(result)))
        end
    end
end

print("[ClientInit] Client controllers initialized.")
