-- Scene binding is independent from profile loading and optional presentation.
local World={}
local refs,builtRoot
local C={floor=Color3.fromRGB(24,23,30),wood=Color3.fromRGB(67,45,40),gold=Color3.fromRGB(174,139,85),mint=Color3.fromRGB(156,125,194),white=Color3.fromRGB(228,214,185)}
local function part(parent,name,size,cf,col,material)
    local p=Instance.new("Part")
    p.Name,p.Size,p.CFrame,p.Color=name,size,cf,col
    p.Material,p.Anchored,p.CanCollide=material or Enum.Material.SmoothPlastic,true,false
    p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function cylinder(parent,name,radius,height,pos,col,material)
    local p=part(parent,name,Vector3.new(height,2*radius,2*radius),CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2),col,material)
    p.Shape=Enum.PartType.Cylinder;return p
end
-- The foyer frames ClubArchive/ClubExitDoor, which already owns the real door,
-- front-wall opening and collision lease. It never replaces an interaction.
local function retireEntrancePlaque(root)
    local entrance = root:FindFirstChild("ClubEntrance")
    local plaque = entrance and entrance:FindFirstChild("EntrancePlaque")
    if plaque then plaque:Destroy() end
end
local function buildEntrance(root, entry)
    local old = root:FindFirstChild("ClubEntrance")
    retireEntrancePlaque(root)
    if old and old:GetAttribute("DesignVersion") == entry.version then return old end
    local model = Instance.new("Model")
    model.Name = "ClubEntrance"
    model:SetAttribute("DesignVersion", entry.version)
    pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
    local brass, ink = Color3.fromRGB(155, 131, 91), Color3.fromRGB(37, 42, 45)
    local warm, cool = Color3.fromRGB(247, 220, 181), Color3.fromRGB(172, 194, 214)
    local function block(name, size, position, color, material)
        local object = part(model, name, size, CFrame.new(position), color, material)
        object.CanTouch, object.CanQuery = false, false
        object.Reflectance = material == Enum.Material.Metal and .025 or 0
        -- Preserve our authored finish when the optional interior material pass runs.
        object:SetAttribute("SpyAuthoredSurface", true)
        return object
    end
    local function fixture(owner, name, face, color, brightness, range, angle)
        owner:SetAttribute("ClubFixture", true)
        owner.CastShadow = false
        local light = Instance.new("SurfaceLight")
        light.Name, light.Face, light.Color = name, face, color
        light.Brightness, light.Range, light.Angle, light.Shadows = brightness, range, angle, true
        light.Parent = owner
    end
    -- A flush stone finish on the existing support floor; no step or new obstacle.
    local landing = block("EntranceLanding", Vector3.new(13.6, .025, 8.6), Vector3.new(0, .08, -28.75), Color3.fromRGB(46, 51, 54), Enum.Material.Slate)
    landing.Reflectance, landing.CastShadow = .025, false
    for _, x in ipairs({-6.65, 6.65}) do
        block("LandingBrassEdge", Vector3.new(.035, .004, 8.4), Vector3.new(x, .095, -28.75), brass, Enum.Material.Metal).CastShadow = false
    end
    -- Side wings sit outside the eight-stud spawn footprint and six-stud route.
    for _, side in ipairs({-1, 1}) do
        local x = side * 6.4
        block("FoyerPier", Vector3.new(.38, 10.45, 3.8), Vector3.new(x, 5.285, -31.1), ink, Enum.Material.Concrete)
        block("PierBrassReveal", Vector3.new(.045, 9.7, .06), Vector3.new(x - side * .23, 5.3, -29.18), brass, Enum.Material.Metal)
        block("EntrySconceHousing", Vector3.new(.55, 1.65, .23), Vector3.new(side * 5.7, 5.8, -32.75), brass, Enum.Material.Metal)
        local lens = block("EntranceWarmLens", Vector3.new(.31, 1.30, .065), Vector3.new(side * 5.7, 5.8, -32.58), warm, Enum.Material.Neon)
        lens.Transparency = .18
        fixture(lens, "EntryWarmLight", Enum.NormalId.Back, warm, .75, 12, 115)
    end
    block("EntranceCanopy", Vector3.new(13.2, .20, 6.7), Vector3.new(0, 10.55, -29.6), ink, Enum.Material.Metal)
    block("CanopyBrassLip", Vector3.new(13.2, .055, .08), Vector3.new(0, 10.40, -26.20), brass, Enum.Material.Metal)
    local face = block("EntranceFaceLens", Vector3.new(3.2, .055, .13), Vector3.new(0, 10.34, -26.23), warm, Enum.Material.Neon)
    face.Transparency = .24
    fixture(face, "EntryFaceLight", Enum.NormalId.Bottom, Color3.fromRGB(255, 235, 211), .85, 14, 125)
    -- A separate visible, low-output cool strip defines the threshold without fog emitters.
    block("ThresholdHousing", Vector3.new(5.2, .09, .14), Vector3.new(0, 10.31, -32.8), ink, Enum.Material.Metal)
    local lens = block("CoolThresholdLens", Vector3.new(4.9, .035, .10), Vector3.new(0, 10.245, -32.8), cool, Enum.Material.Neon)
    lens.Transparency = .22
    fixture(lens, "EntryCoolLight", Enum.NormalId.Bottom, cool, .38, 10, 105)
    -- Build off-tree, so the light audit sees the full allowed ancestry on attachment.
    model.Parent = root
    if old then old:Destroy() end
    root:SetAttribute("EntranceVersion", entry.version)
    return model
end
function World.ensureSafety()
    local root=workspace:FindFirstChild("SpyClub")
    if not root then root=Instance.new("Model");root.Name="SpyClub";root.Parent=workspace end
    local floor=root:FindFirstChild("SafetyFloor") or part(root,"SafetyFloor",Vector3.new(144,1,80),CFrame.new(28,-.5,0),C.floor)
    floor.Anchored,floor.CanCollide=true,true
    local spawn=root:FindFirstChild("ClubSpawn")
    if not spawn then
        spawn=Instance.new("SpawnLocation");spawn.Name="ClubSpawn";spawn.Parent=root
    end
    local spec = require(script.Parent.WorldSpec)
    local entry = spec.entry
    spawn.Size = Vector3.new(8, .2, 5)
    spawn.CFrame = CFrame.new(table.unpack(entry.spawn.position)) * CFrame.Angles(0, math.rad(entry.spawn.yaw), 0)
    spawn.Anchored,spawn.CanCollide,spawn.Neutral,spawn.Duration,spawn.Enabled,spawn.Transparency=true,false,true,0,true,1
    spawn.CanTouch, spawn.CanQuery, spawn.CastShadow = false, false, false
    spawn:SetAttribute("EntranceSafeRadius", 4)
    spawn:SetAttribute("EntranceFacing", "MainLounge")
    return root
end
local function buildFeedbackDesk(root)
    local existing = root:FindFirstChild("FeedbackDesk")
    if existing and existing:GetAttribute("DesignVersion") == 2 then return end
    -- Build off-tree, then replace the previous station once the whole object exists.
    local desk = Instance.new("Model")
    desk.Name = "FeedbackDesk"
    desk:SetAttribute("DesignVersion", 2)
    local base = CFrame.new(-8, 0, -17.5) * CFrame.Angles(0, math.rad(12), 0)
    local wood = Color3.fromRGB(57, 38, 32)
    local darkWood = Color3.fromRGB(39, 29, 27)
    local leather = Color3.fromRGB(75, 37, 43)
    local paper = Color3.fromRGB(226, 213, 188)
    local brass = Color3.fromRGB(172, 143, 100)
    local function block(name, size, offset, color, material, collide)
        local p = part(desk, name, size, base * offset, color, material)
        p.CastShadow, p.CanTouch, p.CanQuery = true, false, collide == true
        p.CanCollide = collide == true
        return p
    end
    local function lettering(object, name, face, text, width, height, fontSize)
        local gui = Instance.new("SurfaceGui")
        gui.Name, gui.Face, gui.CanvasSize = name, face, Vector2.new(width, height)
        gui.LightInfluence, gui.AlwaysOnTop, gui.Parent = .65, false, object
        local label = Instance.new("TextLabel")
        label.Name, label.Size, label.Position = "Inscription", UDim2.fromScale(.94, .86), UDim2.fromScale(.03, .07)
        label.BackgroundTransparency, label.TextColor3 = 1, paper
        label.Font, label.TextSize, label.TextWrapped = Enum.Font.GothamMedium, fontSize, true
        label.Text, label.Parent = text, gui
        return label
    end

    -- A compact walnut writing cabinet, with recessed drawer fronts and a leather blotter.
    block("CabinetBody", Vector3.new(4.25, 2.12, 1.92), CFrame.new(0, 1.26, .08), darkWood, Enum.Material.Wood, true)
    block("CabinetPlinth", Vector3.new(4.35, .16, 2), CFrame.new(0, .18, .08), wood, Enum.Material.Wood, true)
    block("WritingSurface", Vector3.new(4.8, .17, 2.4), CFrame.new(0, 2.4, 0), wood, Enum.Material.Wood, true)
    block("TopBead", Vector3.new(4.55, .055, 2.18), CFrame.new(0, 2.29, 0), brass, Enum.Material.Metal)
    block("LeatherBlotter", Vector3.new(3.95, .025, 1.87), CFrame.new(-.17, 2.501, -.02), leather, Enum.Material.Fabric)
    for _, x in ipairs({-1.13, 1.13}) do
        for _, y in ipairs({.81, 1.58}) do
            block("RecessedDrawer", Vector3.new(1.93, .66, .055), CFrame.new(x, y, -.912), wood, Enum.Material.Wood)
            block("DrawerPull", Vector3.new(.49, .04, .11), CFrame.new(x, y + .13, -.989), brass, Enum.Material.Metal)
        end
    end
    local plaque = block("DeskPlaque", Vector3.new(3.96, .43, .035), CFrame.new(0, 2.15, -1.035), leather, Enum.Material.Fabric)
    lettering(plaque, "ContactPlaque", Enum.NormalId.Front, "СВЯЗЬ С РАЗРАБОТЧИКОМ", 800, 100, 29)

    -- Keep this book's position and prompt identity: server proximity checks and the tour use it.
    block("BookLowerCover", Vector3.new(1.95, .05, 1.5), CFrame.new(-.4, 2.555, -.08), leather, Enum.Material.Fabric)
    block("PageBlock", Vector3.new(1.79, .10, 1.36), CFrame.new(-.4, 2.612, -.08), paper, Enum.Material.SmoothPlastic)
    block("BookSpine", Vector3.new(.12, .14, 1.46), CFrame.new(-1.34, 2.62, -.08), leather, Enum.Material.Fabric)
    local cover = block("FeedbackBookCover", Vector3.new(1.95, .07, 1.5), CFrame.new(-.4, 2.67, -.08), leather, Enum.Material.Fabric)
    for _, x in ipairs({-1.23, .43}) do
        block("CoverFoilLine", Vector3.new(.014, .005, 1.23), CFrame.new(x, 2.709, -.08), brass, Enum.Material.Metal)
    end
    lettering(cover, "CoverFoil", Enum.NormalId.Top, "SPY CLUB\nПОЧТА КЛУБА", 500, 350, 29).TextColor3 = brass

    -- Small envelopes, a brass letter tray and a pen make the interaction legible in-world.
    block("LetterTray", Vector3.new(.99, .045, 1.36), CFrame.new(1.28, 2.55, -.15), brass, Enum.Material.Metal)
    for _, x in ipairs({.78, 1.78}) do
        block("LetterTrayLip", Vector3.new(.04, .1, 1.37), CFrame.new(x, 2.59, -.15), brass, Enum.Material.Metal)
    end
    for index = 1, 3 do
        block("Envelope" .. index, Vector3.new(.81, .012, .56), CFrame.new(1.28 + (index - 2) * .025, 2.58 + index * .013, -.24 + (index - 2) * .035) * CFrame.Angles(0, math.rad((index - 2) * 4), 0), paper, Enum.Material.SmoothPlastic)
    end
    block("PenRest", Vector3.new(.08, .045, .76), CFrame.new(.72, 2.552, -.06) * CFrame.Angles(0, -.15, 0), darkWood, Enum.Material.Wood)
    block("FountainPen", Vector3.new(.037, .037, .65), CFrame.new(.72, 2.59, -.06) * CFrame.Angles(0, -.15, 0), brass, Enum.Material.Metal)

    local lampX, lampZ = -1.77, .72
    block("ReadingLampBase", Vector3.new(.44, .065, .40), CFrame.new(lampX, 2.54, lampZ), brass, Enum.Material.Metal)
    block("ReadingLampStem", Vector3.new(.055, .79, .055), CFrame.new(lampX, 2.97, lampZ), brass, Enum.Material.Metal)
    local shade = block("ReadingLampShade", Vector3.new(.94, .30, .37), CFrame.new(lampX, 3.38, lampZ - .06), leather, Enum.Material.Metal)
    shade.Shape = Enum.PartType.Cylinder
    local diffuser = block("ReadingLampDiffuser", Vector3.new(.77, .015, .25), CFrame.new(lampX, 3.24, lampZ - .06), paper, Enum.Material.SmoothPlastic)
    local light = Instance.new("SurfaceLight")
    light.Name, light.Face, light.Color = "FeedbackWarmLight", Enum.NormalId.Bottom, Color3.fromRGB(255, 219, 171)
    light.Brightness, light.Range, light.Angle, light.Shadows = .55, 7, 100, true
    light.Parent = diffuser
    local note = block("ContactCard", Vector3.new(1.67, .34, .045), CFrame.new(.66, 2.81, .93) * CFrame.Angles(math.rad(-8), 0, 0), darkWood, Enum.Material.Wood)
    lettering(note, "ContactHint", Enum.NormalId.Front, "БАГИ  /  ИДЕИ", 500, 100, 27)

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name, prompt.ActionText, prompt.ObjectText = "FeedbackBook", "Написать", "Связь с разработчиком"
    prompt.KeyboardKeyCode, prompt.MaxActivationDistance = Enum.KeyCode.E, 9
    prompt.RequiresLineOfSight, prompt.HoldDuration, prompt.Style = false, 0, Enum.ProximityPromptStyle.Custom
    prompt.Parent = cover
    if existing then existing:Destroy() end
    desk.Parent = root
end
function World.build(config)
    local root=World.ensureSafety()
    -- Retire a stale generated plate even when the scene itself is already bound.
    retireEntrancePlaque(root)
    if refs and builtRoot==root then return refs end
	local result=require(script.Parent.WorldGeometry).bind(root,config)
    -- Binding also writes the baked SpawnLocation. Keep the live start point authoritative.
    World.ensureSafety()
    task.spawn(function()
        local entranceOk, entranceErr = pcall(buildEntrance, root, require(script.Parent.WorldSpec).entry)
        if not entranceOk then root:SetAttribute("EntranceError", tostring(entranceErr));warn("SpyClub foyer: " .. tostring(entranceErr)) end
        local ok,err=pcall(buildFeedbackDesk,root)
        if not ok then root:SetAttribute("FeedbackDeskError",tostring(err));warn("SpyClub writing desk: "..tostring(err)) end
        local routeOk,routeErr=pcall(function() require(script.Parent.LobbyWayfinding).start(root) end)
        if not routeOk then root:SetAttribute("WayfindingError",tostring(routeErr));warn("SpyClub floor runners: "..tostring(routeErr)) end
    end)
	-- Remove old lobby displays that were baked into WorldSpec.
	local removeOnBuild = {
		"FeaturedCases",

		"CollectionCard0",
		"CollectionCard1",
		"CollectionCard2",

		"CollectionFrame0",
		"CollectionFrame1",
		"CollectionFrame2",

		"CollectionSign",
		"DailySign",
	}

	for _, name in ipairs(removeOnBuild) do
		local object = root:FindFirstChild(name)
		if object then
			object:Destroy()
		end
	end
    -- The authored character already exists in the saved file; bind its joints in place.
    refs,builtRoot=result,root
    task.spawn(function()
        local ok,err=pcall(function() require(script.Parent.Npc).spawn(root) end)
        if not ok then root:SetAttribute("NpcBootError",tostring(err));warn("SpyClub Vincent: "..tostring(err)) end
    end)
    task.spawn(function()
        local ok,err=pcall(function() require(script.Parent.LobbyLighting).apply() end)
        if not ok then root:SetAttribute("LightingBootError",tostring(err));warn("SpyClub lighting: "..tostring(err)) end
    end)
    task.defer(function()
        for _,ref in pairs(result) do
            for seat=1,#ref.seats do
                local ok,err=pcall(World.applyCosmetics,ref,{seat=seat,equipped={card="classic",trinket=""}},nil)
                if not ok then warn("SpyClub table art: "..tostring(err)) end
            end
        end
    end)
    root:SetAttribute("WorldReady",true)
    return refs
end

function World.getRefs() return refs end

function World.applyCosmetics(ref, data, userId)
    local shared = game:GetService("ReplicatedStorage"):FindFirstChild("SpyShared")
    if not shared then return end
    local Catalog = require(shared.Catalog)
    local Art = require(shared.Art)
    local seat = data and data.seat or (userId and ref.owners[userId])
    if not seat then return end
    if userId then ref.owners[userId] = data and seat or nil end
    local equipped = data and data.equipped or {card="classic",trinket=""}
    local card=ref.model:FindFirstChild("Card"..seat)
    if not card then return end
    local skin=card:FindFirstChild("CardSkin")
    if skin then skin:Destroy() end
    local item=Catalog.ById[equipped.card] or Catalog.ById.classic
    local gui=Instance.new("SurfaceGui")
    gui.Name,gui.Face,gui.CanvasSize,gui.Parent="CardSkin",Enum.NormalId.Top,Vector2.new(180,250),card
    gui.LightInfluence=0.5
    Art.draw(gui,item)
    local old=ref.model:FindFirstChild("Trinket"..seat)
    if old then old:Destroy() end
    local trinket=Catalog.ById[equipped.trinket]
    if not trinket or trinket.kind~="trinket" then return end
    local model=Instance.new("Model")
    model.Name,model.Parent="Trinket"..seat,ref.model
    local cf=card.CFrame*CFrame.new(1.25,0.28,0)
    if trinket.id=="dice" then
        part(model,"Die",Vector3.new(0.58,0.58,0.58),cf,Art.color(trinket))
        for _,pos in ipairs({{-0.16,-0.16},{0.16,-0.16},{0,0},{-0.16,0.16},{0.16,0.16}}) do
            local dot=part(model,"Pip",Vector3.new(0.09,0.02,0.09),cf*CFrame.new(pos[1],0.301,pos[2]),C.floor)
            dot.Shape=Enum.PartType.Ball
        end
    else
        cylinder(model,"Brass",0.37,0.11,cf.Position,C.gold,Enum.Material.Metal)
        local face=cylinder(model,"Face",0.30,0.12,cf.Position+Vector3.new(0,0.02,0),trinket.id=="lens" and C.mint or C.white)
        if trinket.id=="lens" then
            face.Transparency=0.4
            part(model,"Handle",Vector3.new(0.16,0.14,0.55),cf*CFrame.new(0,0,0.56),C.wood)
        else
            part(model,"Hand",Vector3.new(0.035,0.03,0.24),cf*CFrame.new(0,0.10,-0.05),C.floor)
            part(model,"Hand2",Vector3.new(0.20,0.03,0.035),cf*CFrame.new(0.07,0.10,0.02),C.floor)
            part(model,"Crown",Vector3.new(0.15,0.10,0.16),cf*CFrame.new(0,0,-0.40),C.gold,Enum.Material.Metal)
        end
    end
    for _,p in ipairs(model:GetChildren()) do if p:IsA("BasePart") then p.CanCollide=false end end
end

return World
