-- One finish for the authored match room. Turn lamps only observe round state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local Room = {}
local running = setmetatable({}, { __mode = "k" })
local CHARCOAL = Color3.fromRGB(32, 32, 34)
local CEILING = Color3.fromRGB(27, 27, 29)
local WALNUT = Color3.fromRGB(58, 43, 37)
local BRASS = Color3.fromRGB(144, 120, 82)
local IVORY = Color3.fromRGB(242, 226, 199)
local OXBLOOD = Color3.fromRGB(66, 29, 34)
local SIGNAL_OFF = Color3.fromRGB(69, 62, 55)

local function finish(piece, color, material)
    piece.Color = color
    piece.Material = material
    piece.Reflectance = 0
end

local function quietDecoration(piece)
    -- Never change authored collision, seats, or anchors to simplify the view.
    if not piece.CanCollide then
        piece.Transparency = 1
        piece.CastShadow = false
    else
        finish(piece, CHARCOAL, Enum.Material.SmoothPlastic)
    end
end

local function decorativePart(parent, name, size, cf, color, material)
    local piece = Instance.new("Part")
    piece.Name = name
    piece.Size = size
    piece.CFrame = cf
    finish(piece, color, material)
    piece.Anchored = true
    piece.CanCollide = false
    piece.CanTouch = false
    piece.CanQuery = false
    piece.CastShadow = false
    piece.Parent = parent
    return piece
end

local function downwardFace(piece)
    local choices = {
        { Enum.NormalId.Right, Vector3.new(1, 0, 0) },
        { Enum.NormalId.Left, Vector3.new(-1, 0, 0) },
        { Enum.NormalId.Top, Vector3.new(0, 1, 0) },
        { Enum.NormalId.Bottom, Vector3.new(0, -1, 0) },
        { Enum.NormalId.Front, Vector3.new(0, 0, -1) },
        { Enum.NormalId.Back, Vector3.new(0, 0, 1) },
    }
    local result, lowest = Enum.NormalId.Bottom, math.huge
    for _, choice in ipairs(choices) do
        local y = piece.CFrame:VectorToWorldSpace(choice[2]).Y
        if y < lowest then lowest = y; result = choice[1] end
    end
    return result
end

local function finishLighting()
    Lighting.Brightness = 2.1
    Lighting.ExposureCompensation = 0.08
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = 0.4
    Lighting.EnvironmentDiffuseScale = 0.65
    Lighting.EnvironmentSpecularScale = 0.4
    Lighting.Ambient = Color3.fromRGB(88, 84, 80)
    Lighting.OutdoorAmbient = Color3.fromRGB(60, 59, 58)
    Lighting.FogEnd = 100000
    pcall(function()
        Lighting.LightingStyle = Enum.LightingStyle.Realistic
        Lighting.PrioritizeLightingQuality = true
    end)
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("Atmosphere") then
            effect.Density = 0; effect.Haze = 0; effect.Glare = 0
        elseif effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
            effect.Enabled = false
        elseif effect:IsA("ColorCorrectionEffect") and effect.Name ~= "SpyMatchVisual_Grade" then
            effect.Enabled = false
        end
    end
    local mapper = Lighting:FindFirstChildOfClass("ColorGradingEffect")
    if mapper then mapper.TonemapperPreset = Enum.TonemapperPreset.Default end
end

local function finishRoom(room, tableModel)
    finishLighting()
    local lounge = room:FindFirstChild("LoungeDecor")
    local coffers = room:FindFirstChild("CeilingCoffers")
    local moulding = room:FindFirstChild("WallMoulding")
    local sconces = room:FindFirstChild("WallSconces")
    local focal = room:FindFirstChild("BackWallFocal")
    for _, piece in ipairs(room:GetDescendants()) do
        if not piece:IsA("BasePart") then continue end
        local name = piece.Name
        if piece:IsA("Seat") or piece:IsA("SpawnLocation")
            or piece.Parent.Name == "PlayerSpawns" then
            continue
        elseif piece.Parent == tableModel and name:match("^Card%d+$") then
            -- Role cards are dealt privately by the client after the intro.
            quietDecoration(piece)
        elseif name == "MainFloor" or name == "SafetyFloor" then
            finish(piece, Color3.fromRGB(46, 39, 35), Enum.Material.WoodPlanks)
        elseif name == "Ceiling" then
            finish(piece, CEILING, Enum.Material.SmoothPlastic)
        elseif piece.Parent == room and name:find("Wall") then
            finish(piece, CHARCOAL, Enum.Material.SmoothPlastic)
        elseif coffers and piece:IsDescendantOf(coffers) then
            quietDecoration(piece)
        elseif lounge and piece:IsDescendantOf(lounge) then
            if name == "VIPMainRug" then
                finish(piece, Color3.fromRGB(42, 36, 35), Enum.Material.Fabric)
            else
                quietDecoration(piece)
            end
        elseif name:find("Wood") or name:find("Cornice")
            or name:find("Rail") or (moulding and piece:IsDescendantOf(moulding)) then
            finish(piece, WALNUT, Enum.Material.Wood)
        elseif piece.Parent == tableModel then
            if name == "Felt" then
                finish(piece, OXBLOOD, Enum.Material.Fabric)
            elseif name:match("^Cushion%d+$") or name:match("^ChairInset%d+$") then
                finish(piece, OXBLOOD, Enum.Material.Fabric)
            elseif name == "Rim" or name:match("^ChairTrim%d+$") then
                finish(piece, BRASS, Enum.Material.Metal)
                piece.Reflectance = 0.025
            elseif name == "Glow" then
                quietDecoration(piece)
            elseif name == "LampFace" then
                finish(piece, IVORY, Enum.Material.SmoothPlastic)
                piece.Transparency = 0.12
            elseif name == "Lamp" or name == "LampWire" then
                finish(piece, CHARCOAL, Enum.Material.Metal)
            else
                finish(piece, WALNUT, Enum.Material.Wood)
            end
        elseif sconces and piece:IsDescendantOf(sconces) then
            if name:find("SconceGlow") then
                finish(piece, IVORY, Enum.Material.SmoothPlastic)
                piece.Transparency = 0.18
            else
                finish(piece, BRASS, Enum.Material.Metal)
            end
        elseif focal and piece:IsDescendantOf(focal) then
            local emblem = name:find("Emblem")
            finish(piece, emblem and BRASS or CHARCOAL,
                emblem and Enum.Material.Metal or Enum.Material.SmoothPlastic)
        end
    end

    -- Normalize the authored lights in the same pass; decorative corner lamps
    -- and the tabletop glow no longer create competing pools of light.
    for _, light in ipairs(room:GetDescendants()) do
        if not light:IsA("Light") then continue end
        light.Color = IVORY
        if light.Parent.Name == "LampFace" and light:IsA("PointLight") then
            light.Enabled = true; light.Brightness = 0.4
            light.Range = 20; light.Shadows = false
        elseif sconces and light:IsDescendantOf(sconces) then
            light.Enabled = true; light.Brightness = 0.45
            light.Range = 14; light.Shadows = false
        else
            light.Enabled = false
        end
    end
    local lamp = tableModel:FindFirstChild("LampFace")
    if lamp and lamp:IsA("BasePart") then
        -- The shade is a rotated thin cylinder: preserve its suspension and
        -- thickness, reduce the radial axes, and select its real down face.
        for _, name in ipairs({ "Lamp", "LampFace" }) do
            local shell = tableModel:FindFirstChild(name)
            if shell and shell:IsA("BasePart") and not shell:GetAttribute("SpyCompactShade") then
                local size = shell.Size
                shell.Size = Vector3.new(size.X, size.Y * 0.55, size.Z * 0.55)
                shell:SetAttribute("SpyCompactShade", true)
            end
        end
        local pool = lamp:FindFirstChild("TablePool")
        if not pool then
            pool = Instance.new("SpotLight")
            pool.Name = "TablePool"; pool.Parent = lamp
        end
        -- The broad pool reaches seated faces at the authored 7.6-stud radius.
        pool.Face = downwardFace(lamp); pool.Angle = 120
        pool.Range = 22; pool.Brightness = 1.25
        pool.Color = IVORY; pool.Shadows = true; pool.Enabled = true
    end
end

function Room.start(room)
    if not room then return nil end
    if running[room] then return running[room] end
    local tableModel = room:FindFirstChild("GameTable")
    local felt = tableModel and tableModel:FindFirstChild("Felt")
    local floor = room:FindFirstChild("MainFloor")
    if not felt or not felt:IsA("BasePart") or not floor or not floor:IsA("BasePart") then
        return nil
    end
    -- Remove only previous runtime layers, never authored room geometry.
    for _, name in ipairs({ "PrivateRoomFinish", "MatchExperience" }) do
        local previous = room:FindFirstChild(name)
        if previous then previous:Destroy() end
    end
    for _, gui in ipairs(room:GetDescendants()) do
        if gui:IsA("SurfaceGui") and gui.Name:match("^PrivateRoomInsignia_") then
            gui:Destroy()
        end
    end
    finishRoom(room, tableModel)

    local decor = Instance.new("Folder")
    decor.Name = "MatchExperience"; decor.Parent = room
    local center = felt.Position
    local top = center.Y + math.min(felt.Size.X, felt.Size.Y, felt.Size.Z) * 0.5
    local signals, lamps = {}, {}
    for index = 1, 4 do
        local cushion = tableModel:FindFirstChild("Cushion" .. index, true)
        local direction = cushion and Vector3.new(cushion.Position.X - center.X, 0, cushion.Position.Z - center.Z)
            or Vector3.new(math.sin((index - 1) * math.pi * 0.5), 0, -math.cos((index - 1) * math.pi * 0.5))
        direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.new(0, 0, -1)
        local position = Vector3.new(center.X, top + 0.04, center.Z) + direction * 4.9
        local base = decorativePart(decor, "TurnSignal" .. index, Vector3.new(0.6, 0.04, 0.14),
            CFrame.lookAt(position, position - direction), BRASS, Enum.Material.Metal)
        local glow = decorativePart(base, "SignalLens", Vector3.new(0.42, 0.015, 0.065),
            base.CFrame * CFrame.new(0, 0.027, 0), SIGNAL_OFF, Enum.Material.SmoothPlastic)
        local light = Instance.new("PointLight")
        light.Name = "SpeakingLight"; light.Color = IVORY; light.Range = 2
        light.Brightness = 0; light.Shadows = false; light.Parent = glow
        signals[index] = base; lamps[index] = { glow = glow, light = light }
    end

    local session, connections = nil, {}
    local function currentSeat()
        if not session then return 0 end
        local id = tonumber(session:GetAttribute("CurrentTurnUserId")) or 0
        if id == 0 then return 0 end
        local player = Players:GetPlayerByUserId(id)
        local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local seat = humanoid and humanoid.SeatPart
        if seat then
            local index = tonumber(seat.Name:match("^MatchSeat(%d+)$"))
            if index then return index end
        end
        local members = session:FindFirstChild("MemberIdsJson")
        local ok, ids = pcall(function()
            return HttpService:JSONDecode(members and members.Value or "[]")
        end)
        if ok and type(ids) == "table" then
            for index, memberId in ipairs(ids) do
                if memberId == id then return index end
            end
        end
        return 0
    end
    local function update()
        local phase = session and session:GetAttribute("RoundPhase") or "Waiting"
        local seat = phase == "Hint" and currentSeat() or 0
        for index, base in ipairs(signals) do
            local active = index == seat
            base:SetAttribute("Active", active)
            lamps[index].glow.Color = active and IVORY or SIGNAL_OFF
            lamps[index].glow.Material = active and Enum.Material.Neon or Enum.Material.SmoothPlastic
            lamps[index].light.Brightness = active and 0.12 or 0
        end
    end
    local function bind(value)
        if session or value.Name ~= "MatchSession" then return end
        session = value
        for _, attribute in ipairs({ "RoundPhase", "CurrentTurnUserId" }) do
            table.insert(connections, session:GetAttributeChangedSignal(attribute):Connect(update))
        end
        update()
    end
    local initial = ReplicatedStorage:FindFirstChild("MatchSession")
    if initial then bind(initial) end
    table.insert(connections, ReplicatedStorage.ChildAdded:Connect(bind))
    local controller = {
        update = update,
        destroy = function()
            for _, connection in ipairs(connections) do connection:Disconnect() end
            running[room] = nil; decor:Destroy()
        end,
    }
    running[room] = controller
    update()
    return controller
end

return Room
