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
function World.ensureSafety()
    local root=workspace:FindFirstChild("SpyClub")
    if not root then root=Instance.new("Model");root.Name="SpyClub";root.Parent=workspace end
    local floor=root:FindFirstChild("SafetyFloor") or part(root,"SafetyFloor",Vector3.new(144,1,80),CFrame.new(28,-.5,0),C.floor)
    floor.Anchored,floor.CanCollide=true,true
    local spawn=root:FindFirstChild("ClubSpawn")
    if not spawn then
        spawn=Instance.new("SpawnLocation");spawn.Name="ClubSpawn";spawn.Size=Vector3.new(8,.2,5);spawn.CFrame=CFrame.new(0,.25,-23);spawn.Parent=root
    end
    spawn.Anchored,spawn.CanCollide,spawn.Neutral,spawn.Duration,spawn.Enabled,spawn.Transparency=true,false,true,0,true,1
    local gate=root:FindFirstChild("HighStakesGate") or part(root,"HighStakesGate",Vector3.new(1.2,11,11.5),CFrame.new(40,5.5,18),C.floor)
    gate.Anchored,gate.CanCollide,gate.Transparency,gate.CollisionGroup=true,true,1,"Default"
    return root
end
function World.build(config)
    local root=World.ensureSafety()
    if refs and builtRoot==root then return refs end
	local result=require(script.Parent.WorldGeometry).bind(root,config)
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
    require(script.Parent.Npc).spawn(root)
    require(script.Parent.LobbyLighting).apply()
    refs,builtRoot=result,root
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
