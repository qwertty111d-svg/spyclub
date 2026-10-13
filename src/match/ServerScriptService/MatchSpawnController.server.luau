local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CharacterService = require(ServerStorage:WaitForChild("SpyModules"):WaitForChild("CharacterService"))

local room = workspace:WaitForChild("SpyMatchRoom")
local spawns = room:WaitForChild("PlayerSpawns")

local function orderedPlayers()
    local list = Players:GetPlayers()
    table.sort(list, function(a, b)
        return a.UserId < b.UserId
    end)
    return list
end

local function spawnIndex(player)
    for index, other in ipairs(orderedPlayers()) do
        if other == player then
            return math.clamp(index, 1, 4)
        end
    end
    return 1
end

local function placeCharacter(player, character)
    local session = game:GetService("ReplicatedStorage"):FindFirstChild("MatchSession")
    if player.Character ~= character or (session and session:GetAttribute("RosterLocked")) then return end
    local root = character:WaitForChild("HumanoidRootPart", 10)
    if not root then return end
    local marker = spawns:FindFirstChild("Spawn" .. tostring(spawnIndex(player)))
    if not marker then return end
    task.wait()
    character:PivotTo(marker.CFrame * CFrame.new(0, 3, 0))
end

local function setup(player)
    local ok, joinData = pcall(function() return player:GetJoinData() end)
    local teleportData = ok and joinData and joinData.TeleportData
    if type(teleportData) == "table" then
        if teleportData.partyId then player:SetAttribute("PartyId", tostring(teleportData.partyId)) end
        if teleportData.partyName then player:SetAttribute("PartyName", tostring(teleportData.partyName)) end
        if teleportData.ownerId then player:SetAttribute("HostUserId", tonumber(teleportData.ownerId)) end
    end
    local function prepareAndPlace(character)
        player:SetAttribute("SpyAppearanceStatus", "loading")
        for attempt = 1, 3 do
            if player.Character ~= character or not character.Parent then return end
            local ok, prepared, reason = pcall(CharacterService.apply, player, character)
            if ok and prepared == true then
                player:SetAttribute("SpyAppearanceStatus", "ready")
                placeCharacter(player, character)
                return
            end
            if ok and (reason == "character_replaced" or reason == "character_changed") then return end
            warn("[SPY M22/APPEARANCE] " .. player.Name .. ", attempt " .. attempt .. ": " .. tostring(ok and reason or prepared))
            if attempt < 3 then task.wait(attempt) end
        end
        if player.Character == character then player:SetAttribute("SpyAppearanceStatus", "failed") end
    end
    player.CharacterAdded:Connect(function(character) task.spawn(prepareAndPlace, character) end)
    if player.Character then task.spawn(prepareAndPlace, player.Character) end
end

for _, player in ipairs(Players:GetPlayers()) do setup(player) end
Players.PlayerAdded:Connect(setup)

-- Optional presentation has one owner and cannot block character/session boot.
task.defer(function()
    ReplicatedStorage:SetAttribute("SpyMatchRoomExperienceStatus", "loading")
    local ready, result = pcall(function()
        local module = ServerStorage.SpyModules:FindFirstChild("MatchRoomExperience")
        if not module then error("MatchRoomExperience module is unavailable") end
        return require(module).start(room)
    end)
    ready = ready and result ~= nil
    ReplicatedStorage:SetAttribute("SpyMatchRoomExperienceStatus", ready and "ready" or "failed")
    if not ready then
        warn("[MatchRoomExperience] " .. tostring(result or "Authored table/floor is unavailable"))
    end
end)
