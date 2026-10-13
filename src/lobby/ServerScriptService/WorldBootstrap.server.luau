-- Independent safety bootstrap. No network, data, catalogue, or purchases here.
local function ensureSafety()
    local world=workspace:FindFirstChild("SpyClub")
    if not world then world=Instance.new("Model"); world.Name="SpyClub"; world.Parent=workspace end
    local floor=world:FindFirstChild("SafetyFloor")
    if not floor then
        floor=Instance.new("Part"); floor.Name="SafetyFloor"
        floor.Size,floor.CFrame=Vector3.new(144,1,80),CFrame.new(28,-.5,0)
        floor.Color=Color3.fromRGB(23,29,30); floor.Parent=world
    end
    floor.Anchored,floor.CanCollide=true,true
    local spawn=world:FindFirstChild("ClubSpawn")
    if not spawn then
        spawn=Instance.new("SpawnLocation"); spawn.Name="ClubSpawn"
        spawn.Size=Vector3.new(8,.2,5)
        spawn.Parent=world
    end
    -- Match WorldSpec.entry even before presentation modules have initialized.
    spawn.CFrame=CFrame.new(0,.25,-26.5)*CFrame.Angles(0,math.pi,0)
    spawn.Anchored,spawn.CanCollide,spawn.Neutral,spawn.Duration=true,false,true,0
    spawn.Transparency=1
    spawn.Enabled=true
    return spawn
end
local safeSpawn=ensureSafety()
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local elapsed=0
-- Below the real floor only; normal jumps, seat poses and VIP travel are untouched.
RunService.Heartbeat:Connect(function(dt)
    elapsed=elapsed+dt
    if elapsed<.5 then return end
    elapsed=0
    for _,player in ipairs(Players:GetPlayers()) do
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if root and humanoid and humanoid.Health>0 and root.Position.Y < -12 then
            root.Anchored=false
            root.AssemblyLinearVelocity,root.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
            character:PivotTo(safeSpawn.CFrame*CFrame.new(0,4,0))
        end
    end
end)
local modules=game:GetService("ServerStorage"):WaitForChild("SpyModules")
local shared=game:GetService("ReplicatedStorage"):WaitForChild("SpyShared")
local World=require(modules:WaitForChild("World"))
World.build(require(shared:WaitForChild("Config")))

-- New lobby flow uses UI parties and a separate Match place.
-- Remove the legacy physical match tables from the lobby after the authored world binds.
local function removeLegacyLobbyTables()
    local strayMatch = workspace:FindFirstChild("SpyMatch")
    if strayMatch then
        strayMatch:Destroy()
    end

    local club = workspace:FindFirstChild("SpyClub")
    if not club then
        return
    end

    for _, legacyName in ipairs({"Trio", "Quartet", "HighStakes"}) do
        local legacy = club:FindFirstChild(legacyName)
        if legacy then
            legacy:Destroy()
        end
    end

    for _, descendant in ipairs(club:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "JoinTable" then
            descendant.Enabled = false
        end
    end
end

removeLegacyLobbyTables()
