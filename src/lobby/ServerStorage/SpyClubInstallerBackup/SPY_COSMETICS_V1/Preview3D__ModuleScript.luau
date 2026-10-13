local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Art=require(script.Parent.Art)
local Preview3D={}
local C={
    dark=Color3.fromRGB(20,25,27), wood=Color3.fromRGB(74,47,36), wood2=Color3.fromRGB(112,72,48),
    brass=Color3.fromRGB(205,158,78), ivory=Color3.fromRGB(235,225,204), mint=Color3.fromRGB(100,218,172),
    velvet=Color3.fromRGB(62,28,41), black=Color3.fromRGB(10,12,14), steel=Color3.fromRGB(87,95,97),
    red=Color3.fromRGB(156,55,61), blue=Color3.fromRGB(85,129,165)
}
local function part(parent,name,size,cf,color,material,shape,className)
    local p=Instance.new(className or "Part")
    p.Name,p.Size,p.CFrame,p.Color=name,size,cf,color
    p.Material=material or Enum.Material.SmoothPlastic
    p.Anchored,p.CanCollide,p.CastShadow=true,false,true
    p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
    if shape and p:IsA("Part") then p.Shape=shape end
    p.Parent=parent
    return p
end
local function trim(parent,pos,size,color)
    return part(parent,"Trim",size,CFrame.new(pos),color,Enum.Material.Metal)
end

local STAND_MODEL_BY_CASE={
    midnight="ClassicCase",
    velvet="SilverCase",
    blackvault="GoldCase",
}

local function cloneStandCase(parent,caseId)
    local modelName=STAND_MODEL_BY_CASE[caseId]
    local source=modelName and workspace:FindFirstChild(modelName)
    if not source then return nil end
    local wasArchivable=source.Archivable
    source.Archivable=true
    local clone=source:Clone()
    source.Archivable=wasArchivable
    if not clone then return nil end
    clone.Name="CasePreview"
    clone:SetAttribute("StandModel",modelName)
    for _,descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("ProximityPrompt")
            or descendant:IsA("Script")
            or descendant:IsA("LocalScript")
            or descendant:IsA("ModuleScript")
        then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored=true
            descendant.CanCollide=false
            descendant.CanTouch=false
            descendant.CanQuery=false
        end
    end
    clone.Parent=parent
    return clone
end

local function caseModel(parent,caseId)
    local m=Instance.new("Model"); m.Name="CasePreview"; m.Parent=parent
    local baseColor=caseId=="blackvault" and C.black or (caseId=="velvet" and C.velvet or C.wood)
    local accent=caseId=="blackvault" and C.mint or C.brass
    local material=caseId=="midnight" and Enum.Material.Wood or Enum.Material.Fabric
    local lining=caseId=="velvet" and Color3.fromRGB(98,43,62) or Color3.fromRGB(27,45,40)
    -- A hollow box: opening reveals a lined interior, not the top of a solid block.
    part(m,"Base",Vector3.new(5.1,.3,3.45),CFrame.new(0,-.93,0),baseColor,material)
    part(m,"Lining",Vector3.new(4.7,.12,3.02),CFrame.new(0,-.71,0),lining,Enum.Material.Fabric)
    for _,x in ipairs({-2.43,2.43}) do
        part(m,"Side",Vector3.new(.24,1.87,3.45),CFrame.new(x,.15,0),baseColor,material)
        part(m,"Rim",Vector3.new(.27,.09,3.5),CFrame.new(x,1.08,0),accent,Enum.Material.Metal)
    end
    for _,z in ipairs({-1.6,1.6}) do
        part(m,"Face",Vector3.new(4.65,1.87,.25),CFrame.new(0,.15,z),baseColor,material)
        part(m,"Rim",Vector3.new(5.12,.09,.2),CFrame.new(0,1.08,z),accent,Enum.Material.Metal)
    end
    local lid=Instance.new("Model"); lid.Name="LidAssembly"; lid.Parent=m
    part(lid,"Lid",Vector3.new(5.1,.42,3.45),CFrame.new(0,1.34,0),baseColor,material)
    part(lid,"Inside",Vector3.new(4.7,.04,3.06),CFrame.new(0,1.115,0),lining,Enum.Material.Fabric)
    for _,x in ipairs({-1.78,1.78}) do
        for _,z in ipairs({-1.75,1.75}) do
            part(m,"Band",Vector3.new(.18,1.82,.06),CFrame.new(x,.16,z),accent,Enum.Material.Metal)
        end
        part(lid,"LidBand",Vector3.new(.18,.46,3.5),CFrame.new(x,1.34,0),accent,Enum.Material.Metal)
        for _,y in ipairs({-.52,.83}) do
            part(m,"Rivet",Vector3.new(.12,.12,.07),CFrame.new(x,y,-1.8),C.ivory,Enum.Material.Metal,Enum.PartType.Ball)
        end
    end
    for _,x in ipairs({-2.31,2.31}) do
        for _,z in ipairs({-1.5,1.5}) do
            part(m,"Corner",Vector3.new(.26,.2,.26),CFrame.new(x,-.82,z),accent,Enum.Material.Metal)
            part(lid,"Corner",Vector3.new(.26,.18,.26),CFrame.new(x,1.57,z),accent,Enum.Material.Metal)
        end
    end
    for i,x in ipairs({-.9,.9}) do
        local lock=Instance.new("Model"); lock.Name="Lock"..i; lock.Parent=m
        part(lock,"Latch",Vector3.new(.42,.62,.14),CFrame.new(x,.91,-1.84),accent,Enum.Material.Metal)
        part(lock,"Keyhole",Vector3.new(.08,.17,.04),CFrame.new(x,.85,-1.93),C.dark)
        lock.WorldPivot=CFrame.new(x,1.06,-1.84)
        part(m,"Hinge",Vector3.new(.55,.18,.18),CFrame.new(x,1.1,1.78),accent,Enum.Material.Metal,Enum.PartType.Cylinder)
    end
    -- Handle and emblem face the camera (negative Z).
    part(m,"Handle",Vector3.new(1.35,.16,.18),CFrame.new(0,-.2,-2.04),C.steel,Enum.Material.Metal)
    for _,x in ipairs({-.6,.6}) do
        part(m,"HandleMount",Vector3.new(.15,.36,.22),CFrame.new(x,-.05,-1.93),accent,Enum.Material.Metal)
    end
    local sealCF=CFrame.new(0,.6,-1.81)*CFrame.Angles(0,math.rad(90),0)
    part(m,"Crest",Vector3.new(.07,.52,.52),sealCF,accent,Enum.Material.Metal,Enum.PartType.Cylinder)
    part(m,"CrestInset",Vector3.new(.045,.25,.25),CFrame.new(0,.6,-1.87)*CFrame.Angles(0,math.rad(90),0),baseColor)
    if caseId=="blackvault" then
        part(m,"VaultGlow",Vector3.new(3.1,.04,.06),CFrame.new(0,1.05,-1.8),C.mint,Enum.Material.Neon)
    end
    lid.WorldPivot=CFrame.new(0,1.11,1.68)
    return m
end
local function itemModel(parent,item)
    local m=Instance.new("Model"); m.Name="ItemPreview"; m.Parent=parent
    local color=item and item.color and Color3.fromRGB(item.color[1],item.color[2],item.color[3]) or C.mint
    local kind=item and item.kind or "card"
    local id=item and item.id or ""
    local art=item and item.art or ""
    if id=="dockGift" then
        part(m,"GiftBox",Vector3.new(3.4,2.6,3),CFrame.new(0,-.2,0),Color3.fromRGB(158,62,93),Enum.Material.SmoothPlastic)
        part(m,"GiftLid",Vector3.new(3.65,.45,3.2),CFrame.new(0,1.27,0),Color3.fromRGB(205,95,120),Enum.Material.SmoothPlastic)
        part(m,"RibbonFront",Vector3.new(.48,3.15,3.24),CFrame.new(0,.1,0),C.brass,Enum.Material.Metal)
        part(m,"RibbonTop",Vector3.new(3.68,.08,.46),CFrame.new(0,1.54,0),C.brass,Enum.Material.Metal)
        for _,x in ipairs({-.48,.48}) do part(m,"Bow",Vector3.new(1.05,.65,.55),CFrame.new(x,1.88,0)*CFrame.Angles(0,0,x*.55),C.brass,Enum.Material.Metal) end
    elseif id=="dockSettings" then
        local steel=Color3.fromRGB(151,179,194)
        local axis=CFrame.Angles(0,math.rad(90),0)
        part(m,"Gear",Vector3.new(.58,2.9,2.9),axis,steel,Enum.Material.Metal,Enum.PartType.Cylinder)
        for i=1,8 do
            local a=i*math.pi/4
            part(m,"Tooth",Vector3.new(.68,.86,.64),CFrame.new(math.sin(a)*1.5,math.cos(a)*1.5,0)*CFrame.Angles(0,0,-a),steel,Enum.Material.Metal)
        end
        part(m,"Inset",Vector3.new(.65,1.55,1.55),CFrame.new(0,0,-.07)*axis,C.dark,Enum.Material.SmoothPlastic,Enum.PartType.Cylinder)
        part(m,"Hub",Vector3.new(.7,.77,.77),CFrame.new(0,0,-.12)*axis,C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
    elseif id=="dockWardrobe" then
        local hat=Color3.fromRGB(151,109,70)
        part(m,"Brim",Vector3.new(.25,4.4,3.7),CFrame.Angles(0,0,math.rad(90)),hat,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Crown",Vector3.new(1.65,2.9,2.55),CFrame.new(0,.9,0)*CFrame.Angles(0,0,math.rad(90)),hat,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Ribbon",Vector3.new(.38,3,2.65),CFrame.new(0,.43,0)*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(70,116,135),Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Pin",Vector3.new(.42,.44,.15),CFrame.new(.45,.43,-1.37),C.brass,Enum.Material.Metal)
    elseif art=="fedora" then
        part(m,"Brim",Vector3.new(.18,4.2,3.5),CFrame.Angles(0,0,math.rad(90)),C.black,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Crown",Vector3.new(1.55,2.7,2.35),CFrame.new(0,.86,0)*CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Band",Vector3.new(.28,2.88,2.52),CFrame.new(0,.38,0)*CFrame.Angles(0,0,math.rad(90)),color,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Pin",Vector3.new(.18,.45,.12),CFrame.new(.95,.38,-1.18),C.brass,Enum.Material.Metal)
    elseif art=="tophat" then
        part(m,"Brim",Vector3.new(.18,4.15,3.65),CFrame.Angles(0,0,math.rad(90)),C.black,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Crown",Vector3.new(2.45,2.75,2.55),CFrame.new(0,1.24,0)*CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Band",Vector3.new(.38,2.92,2.72),CFrame.new(0,.54,0)*CFrame.Angles(0,0,math.rad(90)),color,Enum.Material.Fabric,Enum.PartType.Cylinder)
    elseif art=="glasses" then
        local frame=id=="noir_glasses" and C.black or Color3.fromRGB(68,57,46)
        for _,x in ipairs({-1.05,1.05}) do
            local lens=part(m,"Lens",Vector3.new(1.68,1.18,.12),CFrame.new(x,0,0),color,Enum.Material.Glass); lens.Transparency=.35
            part(m,"Top",Vector3.new(1.88,.12,.16),CFrame.new(x,.66,-.04),frame,Enum.Material.Metal)
            part(m,"Bottom",Vector3.new(1.88,.12,.16),CFrame.new(x,-.66,-.04),frame,Enum.Material.Metal)
            part(m,"Left",Vector3.new(.12,1.26,.16),CFrame.new(x-.88,0,-.04),frame,Enum.Material.Metal)
            part(m,"Right",Vector3.new(.12,1.26,.16),CFrame.new(x+.88,0,-.04),frame,Enum.Material.Metal)
        end
        part(m,"Bridge",Vector3.new(.48,.12,.16),CFrame.new(0,.08,-.04),frame,Enum.Material.Metal)
    elseif art=="tie" then
        part(m,"Knot",Vector3.new(.72,.72,.32),CFrame.new(0,1.35,0)*CFrame.Angles(0,0,math.rad(45)),C.black,Enum.Material.Fabric)
        part(m,"Blade",Vector3.new(.82,2.5,.26),CFrame.new(0,-.15,0),C.black,Enum.Material.Fabric)
        part(m,"Tip",Vector3.new(.72,.72,.26),CFrame.new(0,-1.65,0)*CFrame.Angles(0,0,math.rad(45)),C.black,Enum.Material.Fabric)
    elseif art=="gloves" then
        for _,x in ipairs({-1.05,1.05}) do
            part(m,"Cuff",Vector3.new(1.1,.62,.88),CFrame.new(x,-.85,0),color,Enum.Material.Fabric)
            part(m,"Palm",Vector3.new(1.02,1.35,.82),CFrame.new(x,.15,0),C.dark,Enum.Material.Fabric)
            for finger=1,4 do
                part(m,"Finger",Vector3.new(.18,.78,.22),CFrame.new(x-.33+(finger-1)*.22,1.16,0),C.dark,Enum.Material.Fabric)
            end
        end
    elseif art=="holster" then
        part(m,"Torso",Vector3.new(3.35,4.15,1.7),CFrame.new(),Color3.fromRGB(27,28,31),Enum.Material.Fabric)
        local leather=Color3.fromRGB(83,52,37)
        part(m,"ShoulderStrap",Vector3.new(.30,4.45,.18),CFrame.new(-.85,.05,-.92)*CFrame.Angles(0,0,math.rad(-13)),leather,Enum.Material.Fabric)
        part(m,"ChestStrap",Vector3.new(2.65,.28,.18),CFrame.new(0,-.42,-.94)*CFrame.Angles(0,0,math.rad(8)),leather,Enum.Material.Fabric)
        part(m,"Holster",Vector3.new(.72,1.22,.36),CFrame.new(1.02,-1.05,-1.02)*CFrame.Angles(0,0,math.rad(-8)),Color3.fromRGB(58,37,29),Enum.Material.Fabric)
        part(m,"Buckle",Vector3.new(.32,.22,.08),CFrame.new(-.25,-.42,-1.06),C.brass,Enum.Material.Metal)
    elseif art=="vest" then
        part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(),Color3.fromRGB(29,34,32),Enum.Material.Fabric)
        part(m,"Shirt",Vector3.new(1.0,3.55,.16),CFrame.new(0,.08,-.99),C.ivory,Enum.Material.Fabric)
        for index=1,4 do part(m,"Button",Vector3.new(.16,.16,.08),CFrame.new(0,.72-index*.5,-1.11),C.brass,Enum.Material.Metal,Enum.PartType.Ball) end
    elseif art=="tuxedo" then
        part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(),Color3.fromRGB(45,22,39),Enum.Material.Fabric)
        part(m,"Shirt",Vector3.new(1.0,3.55,.16),CFrame.new(0,.08,-.99),C.ivory,Enum.Material.Fabric)
        part(m,"LapelL",Vector3.new(.68,3.0,.16),CFrame.new(-.68,.05,-1.12)*CFrame.Angles(0,0,math.rad(-12)),C.black,Enum.Material.Fabric)
        part(m,"LapelR",Vector3.new(.68,3.0,.16),CFrame.new(.68,.05,-1.12)*CFrame.Angles(0,0,math.rad(12)),C.black,Enum.Material.Fabric)
        part(m,"PocketSquare",Vector3.new(.55,.28,.12),CFrame.new(.78,.25,-1.22)*CFrame.Angles(0,0,math.rad(-8)),color,Enum.Material.Fabric)
    elseif art=="director" then
        part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(),Color3.fromRGB(19,20,23),Enum.Material.Fabric)
        part(m,"Shirt",Vector3.new(1.0,3.55,.16),CFrame.new(0,.08,-.99),C.ivory,Enum.Material.Fabric)
        part(m,"LapelL",Vector3.new(.72,3.05,.16),CFrame.new(-.70,.04,-1.12)*CFrame.Angles(0,0,math.rad(-12)),C.black,Enum.Material.Fabric)
        part(m,"LapelR",Vector3.new(.72,3.05,.16),CFrame.new(.70,.04,-1.12)*CFrame.Angles(0,0,math.rad(12)),C.black,Enum.Material.Fabric)
        part(m,"Pin",Vector3.new(.24,.24,.10),CFrame.new(.82,.35,-1.23),C.brass,Enum.Material.Metal,Enum.PartType.Ball)
        part(m,"Chain",Vector3.new(.10,1.15,.08),CFrame.new(.55,-.16,-1.22)*CFrame.Angles(0,0,math.rad(48)),C.brass,Enum.Material.Metal)
    elseif id=="dice" then
        part(m,"Die",Vector3.new(2.5,2.5,2.5),CFrame.Angles(math.rad(18),math.rad(32),math.rad(8)),C.ivory)
        for _,pos in ipairs({Vector3.new(-.55,.55,-1.28),Vector3.new(.55,-.55,-1.28),Vector3.new(0,0,-1.28)}) do part(m,"Pip",Vector3.new(.28,.28,.08),CFrame.Angles(math.rad(18),math.rad(32),math.rad(8))*CFrame.new(pos),C.dark) end
    elseif id=="lens" then
        part(m,"LensRing",Vector3.new(.34,3.2,3.2),CFrame.Angles(0,math.rad(90),0),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
        local glass=part(m,"Glass",Vector3.new(.1,2.55,2.55),CFrame.new(0,0,-.24)*CFrame.Angles(0,math.rad(90),0),Color3.fromRGB(145,217,222),Enum.Material.Glass,Enum.PartType.Cylinder); glass.Transparency=.35
        part(m,"Handle",Vector3.new(.4,2.1,.4),CFrame.new(.75,-2,0)*CFrame.Angles(0,0,math.rad(24)),C.wood,Enum.Material.Wood)
    elseif id=="watch" then
        part(m,"Watch",Vector3.new(.35,3,3),CFrame.Angles(0,math.rad(90),0),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
        part(m,"Face",Vector3.new(.12,2.5,2.5),CFrame.new(0,0,-.24)*CFrame.Angles(0,math.rad(90),0),C.ivory,Enum.Material.SmoothPlastic,Enum.PartType.Cylinder)
        part(m,"Hand",Vector3.new(.07,.9,.06),CFrame.new(0,.35,-.34),C.dark)
    elseif id=="notebook" or id=="history" then
        local cover=id=="history" and Color3.fromRGB(44,76,72) or Color3.fromRGB(95,76,49)
        part(m,"Book",Vector3.new(3.3,.5,4.4),CFrame.Angles(math.rad(9),math.rad(-18),0),cover,Enum.Material.Fabric)
        part(m,"Pages",Vector3.new(2.95,.34,4.05),CFrame.new(0,.17,0)*CFrame.Angles(math.rad(9),math.rad(-18),0),C.ivory)
        part(m,"Band",Vector3.new(.28,.58,4.48),CFrame.new(.78,.06,0)*CFrame.Angles(math.rad(9),math.rad(-18),0),color,Enum.Material.SmoothPlastic)
        if id=="history" then
            for i=1,3 do part(m,"Tab"..i,Vector3.new(.7,.12,.38),CFrame.new(1.56,.38,-1.25+i*.8)*CFrame.Angles(math.rad(9),math.rad(-18),0),color) end
        end
    elseif kind=="outfit" then
        part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(0,0,0),Color3.fromRGB(25,27,29),Enum.Material.Fabric)
        part(m,"Shirt",Vector3.new(1.05,3.3,.18),CFrame.new(0,.1,-1),C.ivory,Enum.Material.Fabric)
        part(m,"LapelL",Vector3.new(.72,2.9,.16),CFrame.new(-.72,.1,-1.14)*CFrame.Angles(0,0,math.rad(-12)),C.dark,Enum.Material.Fabric)
        part(m,"LapelR",Vector3.new(.72,2.9,.16),CFrame.new(.72,.1,-1.14)*CFrame.Angles(0,0,math.rad(12)),C.dark,Enum.Material.Fabric)
        part(m,"Bow",Vector3.new(1.15,.35,.28),CFrame.new(0,1.25,-1.24),C.dark,Enum.Material.Fabric)
    elseif kind=="accessory" then
        part(m,"Brim",Vector3.new(.35,4.2,4.2),CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Crown",Vector3.new(2.2,2.8,2.8),CFrame.new(0,1.1,0)*CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
        part(m,"Band",Vector3.new(.35,2.95,2.95),CFrame.new(0,.42,0)*CFrame.Angles(0,0,math.rad(90)),C.brass,Enum.Material.Fabric,Enum.PartType.Cylinder)
    elseif kind=="frame" then
        for _,x in ipairs({-1.7,1.7}) do part(m,"Side",Vector3.new(.28,4.2,.28),CFrame.new(x,0,0),color,Enum.Material.Metal) end
        for _,y in ipairs({-2,2}) do part(m,"Top",Vector3.new(3.7,.28,.28),CFrame.new(0,y,0),color,Enum.Material.Metal) end
        for _,x in ipairs({-1.7,1.7}) do for _,y in ipairs({-2,2}) do part(m,"Stud",Vector3.new(.48,.48,.48),CFrame.new(x,y,0),color,Enum.Material.Metal,Enum.PartType.Ball) end end
    elseif kind=="title" then
        part(m,"Plaque",Vector3.new(4.1,.34,2.25),CFrame.Angles(math.rad(12),math.rad(-16),0),C.dark,Enum.Material.SmoothPlastic)
        part(m,"Inset",Vector3.new(3.55,.18,1.72),CFrame.new(0,.28,0)*CFrame.Angles(math.rad(12),math.rad(-16),0),color,Enum.Material.Metal)
        part(m,"Medal",Vector3.new(.2,.9,.9),CFrame.new(-1.2,.48,-.1)*CFrame.Angles(math.rad(12),math.rad(-16),math.rad(90)),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
    elseif kind=="emote" then
        part(m,"Palm",Vector3.new(1.6,2,1),CFrame.new(0,-.2,0)*CFrame.Angles(0,0,math.rad(-12)),color,Enum.Material.SmoothPlastic)
        for i=1,4 do part(m,"Finger"..i,Vector3.new(.34,1.85,.34),CFrame.new(-.62+(i-1)*.42,1.45,0)*CFrame.Angles(0,0,math.rad(-10+i*4)),color,Enum.Material.SmoothPlastic) end
    elseif kind=="effect" then
        local core=part(m,"Core",Vector3.new(2.2,2.2,2.2),CFrame.new(),color,Enum.Material.Neon,Enum.PartType.Ball); core.Transparency=.08
        for i=1,10 do
            local a=i*math.pi/5
            local orb=part(m,"Spark",Vector3.new(.38,.38,.38),CFrame.new(math.cos(a)*2.1,math.sin(a*.7)*1.2,math.sin(a)*1.4),color,Enum.Material.Neon,Enum.PartType.Ball); orb.Transparency=.15
        end
    else
        part(m,"File",Vector3.new(3.6,.28,4.8),CFrame.Angles(math.rad(10),math.rad(-22),0),color,Enum.Material.SmoothPlastic)
        part(m,"Paper",Vector3.new(3.15,.1,4.1),CFrame.new(0,.22,0)*CFrame.Angles(math.rad(10),math.rad(-22),0),C.ivory)
        part(m,"Seal",Vector3.new(.24,1.05,1.05),CFrame.new(.7,.46,.45)*CFrame.Angles(math.rad(10),math.rad(-22),math.rad(90)),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
        part(m,"Strip",Vector3.new(2.2,.06,.16),CFrame.new(-.25,.42,-.65)*CFrame.Angles(math.rad(10),math.rad(-22),0),C.dark)
    end
    return m
end
function Preview3D.mount(parent,item,caseId,options)
    options=options or {}
    if item and item.kind=="card" then
        local host=Instance.new("Frame")
        host.Name="CardPreview"; host.Size=UDim2.fromScale(.66,.9); host.Position=UDim2.fromScale(.5,.5)
        host.AnchorPoint=Vector2.new(.5,.5); host.BackgroundTransparency=1; host.ZIndex=parent.ZIndex+1; host.Parent=parent
        local aspect=Instance.new("UIAspectRatioConstraint"); aspect.AspectRatio=.72; aspect.Parent=host
        return Art.draw(host,item),nil
    end
    local viewport=Instance.new("ViewportFrame")
    viewport.Name="Preview3D"; viewport.Size=UDim2.fromScale(1,1); viewport.BackgroundTransparency=1
    viewport.BorderSizePixel=0; viewport.ZIndex=parent.ZIndex+1
    viewport.Ambient=Color3.fromRGB(165,158,144); viewport.LightColor=Color3.fromRGB(255,239,207)
    viewport.LightDirection=Vector3.new(-1,-1,-1); viewport.Parent=parent
    local world=Instance.new("WorldModel"); world.Parent=viewport
    local model=caseId and (cloneStandCase(world,caseId) or caseModel(world,caseId)) or itemModel(world,item)
    local cf,size=model:GetBoundingBox()
    local camera=Instance.new("Camera"); camera.FieldOfView=34; camera.Parent=viewport; viewport.CurrentCamera=camera
    local extent=math.max(size.X,size.Y,size.Z)
    local phase=0
    local function frameCamera()
        local aspect=math.max(.35,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
        local distance=extent*(options.dock and 1.5 or (caseId and 1.7 or 1.95))*math.max(1,1/aspect)
        local angle=math.rad(23)+(options.motion and math.sin(phase*.5)*.07 or 0)
        local target=cf.Position+Vector3.new(0,caseId and .5 or 0,0)
        camera.CFrame=CFrame.lookAt(target+Vector3.new(math.sin(angle)*distance,distance*.42,-math.cos(angle)*distance),target)
    end
    frameCamera()
    local sizeConnection=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
    local idle
    if options.motion then idle=RunService.RenderStepped:Connect(function(dt)
        if not viewport.Parent then return end
        local visible=true; local ancestor=viewport.Parent
        while ancestor and ancestor:IsA("GuiObject") do if not ancestor.Visible then visible=false; break end; ancestor=ancestor.Parent end
        if visible then phase=phase+dt; frameCamera() end
    end) end
    viewport.Destroying:Connect(function() sizeConnection:Disconnect(); if idle then idle:Disconnect() end end)
    -- The preview uses the same public shirt asset as Cosmetics.apply, with 3D fallback.
    if item and item.id=="tuxedo" then
        local image=Instance.new("ImageLabel"); image.Name="ActualShirtPreview"; image.BackgroundTransparency=1
        image.Size=UDim2.fromScale(1,1); image.ScaleType=Enum.ScaleType.Fit; image.ZIndex=viewport.ZIndex+1
        image.Image="rbxthumb://type=Asset&id=6952255153&w=420&h=420"; image.Visible=false; image.Parent=parent
        local ready=image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
            if image.IsLoaded then image.Visible=true; viewport.Visible=false end
        end)
        image.Destroying:Connect(function() ready:Disconnect() end)
        if image.IsLoaded then image.Visible=true; viewport.Visible=false end
    end
    return viewport,model
end
local function pivotTween(group,target,duration,delay)
    local driver=Instance.new("CFrameValue"); driver.Value=group:GetPivot(); driver.Parent=group
    local connection=driver:GetPropertyChangedSignal("Value"):Connect(function() if group.Parent then group:PivotTo(driver.Value) end end)
    group.Destroying:Connect(function() connection:Disconnect() end)
    task.delay(delay or 0,function()
        if not group.Parent then return end
        local tween=TweenService:Create(driver,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Value=target})
        tween:Play()
    end)
end
function Preview3D.animateCaseOpen(viewport,model)
    if not viewport or not model or model:GetAttribute("Opened") then return 1.05 end
    model:SetAttribute("Opened",true)
    for index,name in ipairs({"Lock1","Lock2"}) do
        local lock=model:FindFirstChild(name)
        if lock then pivotTween(lock,lock:GetPivot()*CFrame.new(0,-.14,-.16)*CFrame.Angles(math.rad(-52),0,0),.24,(index-1)*.07) end
    end
    local lid=model:FindFirstChild("LidAssembly")
    if lid then pivotTween(lid,lid:GetPivot()*CFrame.Angles(math.rad(104),0,0),.75,.2) end
    if model:GetAttribute("StandModel") and not lid then
        pivotTween(model,model:GetPivot()*CFrame.new(0,.18,0)*CFrame.Angles(0,math.rad(8),0),.7,.12)
    end
    return 1.05
end
return Preview3D
