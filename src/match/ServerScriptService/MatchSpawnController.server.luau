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

-- SPY CLUB / PRIVATE ROOM ART DIRECTION
-- Built on the server so every player and Studio play session sees the same room.
-- All added pieces are decorative and cannot collide with characters or cards.
local Lighting = game:GetService("Lighting")
local INK = Color3.fromRGB(27, 25, 29)
local PLUM = Color3.fromRGB(43, 33, 39)
local WALNUT = Color3.fromRGB(65, 43, 38)
local BRASS = Color3.fromRGB(152, 117, 74)
local CREAM = Color3.fromRGB(238, 215, 182)

local function finish(part, color, material)
    if not part or not part:IsA("BasePart") then return end
    part.Color = color
    if material then part.Material = material end
end

local function decorativePart(parent, name, size, cf, color, material, transparency)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cf
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Transparency = transparency or 0
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function wallIdentity(panel, face)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "PrivateRoomInsignia_" .. face.Name
    gui.Face = face
    gui.CanvasSize = Vector2.new(960, 520)
    gui.LightInfluence = 0.35
    gui.AlwaysOnTop = false
    gui.Parent = panel

    local mark = Instance.new("Frame")
    mark.Name = "DiamondOutline"
    mark.AnchorPoint = Vector2.new(0.5, 0.5)
    mark.Position = UDim2.fromScale(0.5, 0.27)
    mark.Size = UDim2.fromOffset(48, 48)
    mark.Rotation = 45
    mark.BackgroundTransparency = 1
    mark.Parent = gui
    local border = Instance.new("UIStroke")
    border.Color = BRASS
    border.Thickness = 2
    border.Parent = mark

    local center = Instance.new("Frame")
    center.AnchorPoint = Vector2.new(0.5, 0.5)
    center.Position = UDim2.fromScale(0.5, 0.5)
    center.Size = UDim2.fromOffset(11, 11)
    center.BackgroundColor3 = CREAM
    center.BorderSizePixel = 0
    center.Parent = mark

    local function inscription(name, content, y, height, font, size, color)
        local text = Instance.new("TextLabel")
        text.Name = name
        text.BackgroundTransparency = 1
        text.AnchorPoint = Vector2.new(0.5, 0)
        text.Position = UDim2.fromScale(0.5, y)
        text.Size = UDim2.fromScale(0.92, height)
        text.Font = font
        text.Text = content
        text.TextSize = size
        text.TextColor3 = color
        text.TextXAlignment = Enum.TextXAlignment.Center
        text.Parent = gui
    end
    inscription("Club", "SPY CLUB", 0.44, 0.18, Enum.Font.Garamond, 68, CREAM)
    inscription("PrivateTable", "ЗАКРЫТЫЙ СТОЛ", 0.65, 0.10, Enum.Font.GothamMedium, 19, BRASS)
end

local function dressPrivateRoom()
    local existing = room:FindFirstChild("PrivateRoomFinish")
    if existing then return end
    local decor = Instance.new("Folder")
    decor.Name = "PrivateRoomFinish"
    decor.Parent = room

    local mapper=Lighting:FindFirstChildOfClass("ColorGradingEffect")
    if mapper then mapper.TonemapperPreset=Enum.TonemapperPreset.Default end
    Lighting.Brightness = 2.6
    Lighting.ExposureCompensation = 0.10
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = 0.36
    Lighting.EnvironmentDiffuseScale = 0.76
    Lighting.EnvironmentSpecularScale = 0.68
    Lighting.Ambient = Color3.fromRGB(105, 112, 123)
    Lighting.OutdoorAmbient = Color3.fromRGB(67, 75, 88)
    Lighting.FogEnd = 100000
    pcall(function() Lighting.LightingStyle=Enum.LightingStyle.Realistic;Lighting.PrioritizeLightingQuality=true end)
    for _,effect in ipairs(Lighting:GetChildren())do
        if effect:IsA("Atmosphere") then effect.Density=0;effect.Haze=0;effect.Glare=0
        elseif effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then effect.Enabled=false
        elseif effect:IsA("ColorCorrectionEffect") and effect.Name~="SpyMatchVisual_Grade" then effect.Enabled=false end
    end

    local tableModel = room:FindFirstChild("GameTable")
    for _, part in ipairs(room:GetDescendants()) do
        if not part:IsA("BasePart") or part:IsDescendantOf(decor) then continue end
        local name = part.Name
        local parent = part.Parent and part.Parent.Name or ""
        if parent == "GameTable" and name:match("^Card%d+$") then
            -- These are construction placeholders. The client deals real cards
            -- only after the Intro event; showing both reads as a broken cutscene.
            part.Transparency = 1
            part.CastShadow = false
            part.CanCollide = false
        elseif name == "MainFloor" then
            finish(part, INK, Enum.Material.SmoothPlastic)
        elseif name == "Ceiling" then
            finish(part, Color3.fromRGB(28, 23, 29), Enum.Material.SmoothPlastic)
        elseif name:find("Wall") and (parent == "SpyMatchRoom" or name:find("VIPWall")) then
            finish(part, PLUM, Enum.Material.SmoothPlastic)
        elseif parent == "CeilingCoffers" then
            finish(part, WALNUT, Enum.Material.Wood)
        elseif parent == "WallMoulding" or name:find("Wood") or name:find("Cornice") then
            finish(part, WALNUT, Enum.Material.Wood)
        elseif name:find("Rail") or name:find("ChairTrim") or name == "Rim" then
            finish(part, BRASS, Enum.Material.Metal)
            part.Reflectance = 0.06
        elseif name == "Felt" then
            finish(part, Color3.fromRGB(42, 80, 65), Enum.Material.SmoothPlastic)
        elseif name:find("ChairInset") or name:find("Cushion") then
            finish(part, Color3.fromRGB(83, 44, 49), Enum.Material.SmoothPlastic)
        elseif name == "Rug" or name == "VIPMainRug" then
            finish(part, Color3.fromRGB(37, 51, 57), Enum.Material.SmoothPlastic)
        elseif name == "LampFace" then
            finish(part, CREAM, Enum.Material.Neon)
            part.Transparency = 0.82
        elseif name == "Glow" then
            finish(part, Color3.fromRGB(191, 137, 77), Enum.Material.Neon)
            part.Transparency = 0.70
        elseif name:find("SconceGlow") or name:find("VIPLamp") then
            finish(part, Color3.fromRGB(228, 179, 120), Enum.Material.Neon)
            part.Transparency = math.max(part.Transparency, 0.28)
        elseif name == "Inset" and parent == "BackWallFocal" then
            finish(part, Color3.fromRGB(43, 28, 35), Enum.Material.SmoothPlastic)
        end
    end

    for _, light in ipairs(room:GetDescendants()) do
        if light:IsA("PointLight") then
            local owner = light.Parent and light.Parent.Name or ""
            light.Color = owner == "Glow" and Color3.fromRGB(236, 190, 133) or CREAM
            light.Brightness = owner == "LampFace" and 1.48
                or owner == "Glow" and 0.12 or 0.58
            light.Range = owner == "LampFace" and 24 or 14
            light.Shadows = owner == "LampFace"
        end
    end

    if tableModel then
        local lampFace = tableModel:FindFirstChild("LampFace")
        if lampFace and lampFace:IsA("BasePart") then
            local key = Instance.new("SpotLight")
            key.Name = "TablePool"
            key.Face = Enum.NormalId.Bottom
            key.Angle = 83
            key.Range = 20
            key.Brightness = 1.65
            key.Color = CREAM
            key.Shadows = true
            key.Parent = lampFace
        end
    end

    local focal = room:FindFirstChild("BackWallFocal")
    local panel = focal and focal:FindFirstChild("Inset")
    if panel and panel:IsA("BasePart") then
        for _, ornament in ipairs(focal:GetChildren()) do
            if ornament:IsA("BasePart") and ornament.Name:find("Emblem") then
                ornament.Transparency = 1
            end
        end
        wallIdentity(panel, Enum.NormalId.Front)
        wallIdentity(panel, Enum.NormalId.Back)
    end

    local coffers = room:FindFirstChild("CeilingCoffers")
    if coffers then
        for _, beam in ipairs(coffers:GetChildren()) do
            if beam:IsA("BasePart") and beam.Name:find("BeamX_") then
                decorativePart(
                    decor, "Cove_" .. beam.Name,
                    Vector3.new(math.max(1, beam.Size.X - 0.8), 0.045, 0.055),
                    beam.CFrame * CFrame.new(0, -beam.Size.Y / 2 - 0.01, 0),
                    Color3.fromRGB(229, 166, 101), Enum.Material.Neon, 0.48
                )
            end
        end
    end

    -- Two archival cabinets give the north wall a reason to exist. Their
    -- dimensions are measured from the authored floor, not from a second map.
    local floor = room:FindFirstChild("MainFloor")
    if floor and floor:IsA("BasePart") then
        local z = -floor.Size.Z * 0.5 + 1.8
        for _, direction in ipairs({-1, 1}) do
            local x = direction * floor.Size.X * 0.32
            local base = floor.CFrame * CFrame.new(x, floor.Size.Y * 0.5, z)
            local bay = Instance.new("Model")
            bay.Name = direction < 0 and "ArchiveWest" or "ArchiveEast"
            bay.Parent = decor

            decorativePart(bay, "WallPanel", Vector3.new(6.6, 6.1, 0.16),
                base * CFrame.new(0, 5.0, -0.82), Color3.fromRGB(33, 29, 32), Enum.Material.SmoothPlastic)
            for _, side in ipairs({-1, 1}) do
                decorativePart(bay, "Pilaster", Vector3.new(0.13, 6.35, 0.22),
                    base * CFrame.new(side * 3.31, 5.0, -0.68), WALNUT, Enum.Material.Wood)
                decorativePart(bay, "InsetLine", Vector3.new(0.035, 4.8, 0.025),
                    base * CFrame.new(side * 2.98, 5.08, -0.55), BRASS, Enum.Material.Metal)
            end
            decorativePart(bay, "Crown", Vector3.new(7.0, 0.16, 0.33),
                base * CFrame.new(0, 8.12, -0.66), WALNUT, Enum.Material.Wood)
            local cabinet = decorativePart(bay, "Cabinet", Vector3.new(6.65, 2.25, 1.38),
                base * CFrame.new(0, 1.15, 0.13), WALNUT, Enum.Material.Wood)
            cabinet.CanCollide = true
            cabinet.CanQuery = true
            local cabinetTop = decorativePart(bay, "CabinetTop", Vector3.new(7.0, 0.12, 1.6),
                base * CFrame.new(0, 2.35, 0.13), Color3.fromRGB(93, 70, 56), Enum.Material.Wood)
            cabinetTop.CanCollide = true
            cabinetTop.CanQuery = true
            decorativePart(bay, "CounterLine", Vector3.new(7.0, 0.035, 1.62),
                base * CFrame.new(0, 2.43, 0.13), BRASS, Enum.Material.Metal)
            for drawer = -1, 1 do
                decorativePart(bay, "Drawer", Vector3.new(1.93, 0.86, 0.035),
                    base * CFrame.new(drawer * 2.12, 1.34, 0.84), Color3.fromRGB(74, 49, 42), Enum.Material.Wood)
                decorativePart(bay, "Pull", Vector3.new(0.34, 0.055, 0.065),
                    base * CFrame.new(drawer * 2.12, 1.32, 0.89), BRASS, Enum.Material.Metal)
            end
            for document = 1, 5 do
                local px = (document - 3) * 0.9
                decorativePart(bay, "ArchiveVolume", Vector3.new(0.57, 1.7, 0.68),
                    base * CFrame.new(px, 3.42, -0.28),
                    document % 2 == 0 and Color3.fromRGB(57, 65, 60) or Color3.fromRGB(86, 55, 55), Enum.Material.Fabric)
                decorativePart(bay, "VolumeIndex", Vector3.new(0.43, 0.028, 0.014),
                    base * CFrame.new(px, 3.43, 0.07), BRASS, Enum.Material.Metal)
            end
            local artLight = decorativePart(bay, "PictureLamp", Vector3.new(2.8, 0.11, 0.17),
                base * CFrame.new(0, 7.55, -0.42), BRASS, Enum.Material.Metal)
            local wash = Instance.new("SpotLight")
            wash.Name = "ArchiveWash"
            wash.Face = Enum.NormalId.Bottom
            wash.Angle = 85
            wash.Range = 9
            wash.Brightness = 0.52
            wash.Color = CREAM
            wash.Shadows = false
            wash.Parent = artLight
        end
    end
end

-- Optional room presentation is independent of session/character boot.
task.defer(function()
    local dressed,detail=pcall(dressPrivateRoom)
    if not dressed then warn("[MatchRoomDress] "..tostring(detail))end
    local ready,errorMessage=pcall(function()
        local module=ServerStorage.SpyModules:FindFirstChild("MatchRoomExperience")
        if module then require(module).start(room)end
    end)
    ReplicatedStorage:SetAttribute("SpyMatchRoomExperienceStatus",ready and "ready" or "failed")
    if not ready then warn("[MatchRoomExperience] "..tostring(errorMessage))end
end)
