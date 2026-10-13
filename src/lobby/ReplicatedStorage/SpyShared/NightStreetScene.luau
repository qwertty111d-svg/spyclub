-- Shared, script-free scenery. Server builds architecture; each client moves two cars.
local Scene={VERSION=3,RAIN_SOUND="rbxassetid://9112793871"}
local DARK=Color3.fromRGB(32,38,43)
local BRONZE=Color3.fromRGB(97,86,66)
local WARM=Color3.fromRGB(214,193,157)
local function part(parent,name,size,position,color,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(position)
    p.Color=color or DARK;p.Material=material or Enum.Material.Concrete
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Reflectance=0;p.Transparency=0;p.Parent=parent
    return p
end
local function light(owner,class,face,color,brightness,range)
    owner:SetAttribute("ClubFixture",true)
    local l=Instance.new(class);l.Name="FixtureLight";l.Color=color;l.Brightness=brightness;l.Range=range;l.Shadows=false
    if class~="PointLight"then l.Face=face;l.Angle=110 end
    l.Parent=owner;return l
end
local function building(root,index,x,z,width,depth,height,distant)
    local model=Instance.new("Model");model.Name=distant and "DistantTower"or "StreetBuilding";model.Parent=root
    local colors={Color3.fromRGB(78,77,69),Color3.fromRGB(67,75,76),Color3.fromRGB(83,76,70)}
    local wall=colors[index%3+1]
    -- Keep the bulk set back from real masonry piers. Windows sit inside
    -- this .8-stud facade cavity, clear of the opaque mass behind them.
    local inset=distant and 0 or .8
    local mass=part(model,"BuildingMass",Vector3.new(depth-inset,height,width),Vector3.new(x-inset*.5,height*.5,z),wall)
    mass:SetAttribute("NightBuilding",true)
    local front=x+depth*.5
    part(model,"RoofCornice",Vector3.new(depth+.65,.45,width+.65),Vector3.new(x,height+.15,z),Color3.fromRGB(57,62,64))
    part(model,"RoofParapet",Vector3.new(.65,1.1,width+.55),Vector3.new(front-.18,height+.78,z),wall)
    part(model,"RoofEquipment",Vector3.new(depth*.30,2.4,width*.27),Vector3.new(x-2,height+1.5,z+width*.18),DARK,Enum.Material.Metal)
    local columns=distant and 4 or 3
    local spacing=width/columns
    local frame=Color3.fromRGB(52,55,53)
    if not distant then
        for column=0,columns do
            part(model,"FacadePier",Vector3.new(.82,height-4.4,.85),
                Vector3.new(front-.39,(height+4.4)*.5,z-width*.5+column*spacing),wall)
        end
        part(model,"GroundFloorHeader",Vector3.new(1.0,.35,width+.55),Vector3.new(front-.22,4.3,z),Color3.fromRGB(111,106,94))
    end
    -- Lit and unlit windows are opaque: their silhouettes survive rain panes
    -- and low graphics without translucent/refractive sorting artifacts.
    local floors=math.floor((height-5)/(distant and 4.5 or 4))
    for row=1,floors do
        local y=3+row*(distant and 4.5 or 4)
        if not distant then
            part(model,"FloorBand",Vector3.new(.82,1.4,width),Vector3.new(front-.39,y-2,z),wall)
            part(model,"WindowSill",Vector3.new(1.03,.12,width+.30),Vector3.new(front-.28,y-1.18,z),Color3.fromRGB(111,106,94))
        end
        for column=1,columns do
            local lit=(row*7+column*3+index)%5< (distant and 2 or 3)
            if not distant or lit then
                local warm=(row+column+index)%4~=0
                local color=lit and (warm and Color3.fromRGB(171,153,123)or Color3.fromRGB(111,137,147))or Color3.fromRGB(36,47,51)
                local pane=part(model,"FacadeWindow",Vector3.new(.12,distant and 2.5 or 2.2,distant and width/7 or spacing-1.15),
                    Vector3.new(distant and front+.10 or front-.65,y,z-width*.5+(column-.5)*spacing),color,lit and Enum.Material.Neon or Enum.Material.SmoothPlastic)
                pane.Reflectance=lit and 0 or .02
                pane.CastShadow=false
                if not distant then
                    part(model,"WindowMullion",Vector3.new(.07,2.2,.075),pane.Position+Vector3.new(.085,0,0),frame,Enum.Material.Metal)
                    if row%3==0 and column==2 then
                        part(model,"BalconySlab",Vector3.new(1.7,.15,spacing-.6),Vector3.new(front+.30,y-1.25,pane.Position.Z),Color3.fromRGB(67,70,67))
                        part(model,"BalconyRail",Vector3.new(.09,.65,spacing-.8),Vector3.new(front+1.07,y-.87,pane.Position.Z),BRONZE,Enum.Material.Metal)
                    end
                end
            end
        end
    end
    for side=-1,1,2 do
        for row=1,math.min(floors,10)do
            if (row+index)%3~=0 then
                local pane=part(model,"SideWindow",Vector3.new(depth/8,2,.14),Vector3.new(x+depth*.20,3+row*4,z+side*(width*.5+.08)),
                    Color3.fromRGB(83,99,104),Enum.Material.Neon);pane.CastShadow=false
            end
        end
    end
    if not distant then
        part(model,"GroundFloorPlinth",Vector3.new(.26,4.1,width),Vector3.new(front-.52,2.05,z),Color3.fromRGB(55,56,51))
        part(model,"StreetEntrance",Vector3.new(.12,2.85,1.75),Vector3.new(front-.31,1.43,z-width*.34),frame,Enum.Material.Metal)
        part(model,"DoorTransom",Vector3.new(.13,.55,1.75),Vector3.new(front-.30,3.17,z-width*.34),Color3.fromRGB(111,100,78),Enum.Material.Neon)
        part(model,"ShopAwning",Vector3.new(2.25,.16,width*.56),Vector3.new(front+.70,3.55,z+width*.12),Color3.fromRGB(49+index%3*7,57,54),Enum.Material.Fabric)
        local shop=part(model,"ShopWindow",Vector3.new(.14,2.3,width*.46),Vector3.new(front-.28,1.8,z+width*.12),Color3.fromRGB(118,105,82),Enum.Material.Neon)
        shop.CastShadow=false
        for _,side in ipairs({-1,1})do
            part(model,"ShopJamb",Vector3.new(.48,3.25,.16),Vector3.new(front-.10,1.85,z+width*.12+side*width*.235),frame,Enum.Material.Metal)
        end
        part(model,"ShopMullion",Vector3.new(.12,2.3,.12),shop.Position+Vector3.new(.13,0,0),frame,Enum.Material.Metal)
        part(model,"ShopSignboard",Vector3.new(.40,.37,width*.55),Vector3.new(front-.14,3.28,z+width*.12),Color3.fromRGB(107,101,82),Enum.Material.Metal)
        light(shop,"SurfaceLight",Enum.NormalId.Right,Color3.fromRGB(232,208,166),.55,22)
        -- Visible upward-facing canopy lamps reveal the real stone facade.
        -- Emissive window panes alone do not illuminate neighboring geometry.
        part(model,"FacadeLampHousing",Vector3.new(.65,.16,width*.62),Vector3.new(front+1.35,3.73,z),BRONZE,Enum.Material.Metal)
        local wash=part(model,"FacadeLampLens",Vector3.new(.42,.035,width*.58),Vector3.new(front+1.35,3.83,z),WARM,Enum.Material.Neon)
        wash.CastShadow=false
        local up=light(wash,"SurfaceLight",Enum.NormalId.Top,Color3.fromRGB(221,209,189),1.45,43);up.Angle=135
    end
end
function Scene.build(parent)
    local existing=parent:FindFirstChild("NightStreet")
    if existing and existing:GetAttribute("DesignVersion")==Scene.VERSION then return existing end
    local root=Instance.new("Model");root.Name="NightStreet";root:SetAttribute("DesignVersion",Scene.VERSION)
    -- Road and sidewalk are below the lobby floor; a low sill leaves the view usable.
    local road=part(root,"Road",Vector3.new(18,.18,290),Vector3.new(-60,-.20,0),Color3.fromRGB(34,38,40),Enum.Material.Asphalt)
    road.Reflectance=.13
    part(root,"Sidewalk",Vector3.new(9,.20,290),Vector3.new(-45.5,-.02,0),Color3.fromRGB(57,60,59))
    part(root,"FarSidewalk",Vector3.new(7,.20,290),Vector3.new(-72.5,-.02,0),Color3.fromRGB(51,55,54))
    for _,x in ipairs({-50.2,-69.8})do part(root,"Kerb",Vector3.new(.38,.25,290),Vector3.new(x,-.015,0),Color3.fromRGB(84,84,77))end
    for z=-132,132,12 do part(root,"LaneMark",Vector3.new(.14,.012,4.8),Vector3.new(-60,-.103,z),Color3.fromRGB(156,149,125),Enum.Material.SmoothPlastic)end
    for _,z in ipairs({-80,-44,-8,28,64,100})do
        part(root,"LampFoot",Vector3.new(.58,.20,.58),Vector3.new(-49.3,.12,z),BRONZE,Enum.Material.Metal)
        part(root,"LampPost",Vector3.new(.14,10.3,.14),Vector3.new(-49.3,5.35,z),BRONZE,Enum.Material.Metal)
        part(root,"LampArm",Vector3.new(3.25,.15,.16),Vector3.new(-50.86,10.37,z),BRONZE,Enum.Material.Metal)
        part(root,"LampHousing",Vector3.new(1.38,.20,.65),Vector3.new(-52.1,10.30,z),DARK,Enum.Material.Metal)
        local lens=part(root,"LampLens",Vector3.new(1.15,.035,.48),Vector3.new(-52.1,10.18,z),WARM,Enum.Material.Neon)
        light(lens,"SurfaceLight",Enum.NormalId.Bottom,Color3.fromRGB(234,216,182),1.0,40);lens.FixtureLight.Angle=145
    end
    for index,z in ipairs({-64,-39,-12,17,45,76})do
        building(root,index,-91-(index%3)*4,z,18+(index%2)*3,22+(index%2)*5,24+(index%3)*5,false)
    end
    for index,z in ipairs({-87,-35,24,88})do
        building(root,index+6,-155-(index%2)*24,z,26+(index%2)*8,32+(index%2)*10,66+index*12,true)
    end
    root.Parent=parent;if existing then existing:Destroy()end;return root
end
function Scene.createCar(parent,index)
    local model=Instance.new("Model");model.Name="NightCar"..index
    local bodyColor=index%2==1 and Color3.fromRGB(35,48,52)or Color3.fromRGB(99,91,72)
    local pivot=part(model,"CarPivot",Vector3.new(.1,.1,.1),Vector3.zero,DARK);pivot.Transparency=1;pivot.CastShadow=false;model.PrimaryPart=pivot
    local body=part(model,"Coachwork",Vector3.new(2.85,.65,6.5),Vector3.new(0,.94,0),bodyColor,Enum.Material.Metal);body.Reflectance=.06
    part(model,"Bonnet",Vector3.new(2.66,.25,1.95),Vector3.new(0,1.29,-2.18),bodyColor,Enum.Material.Metal)
    part(model,"Boot",Vector3.new(2.68,.20,1.55),Vector3.new(0,1.28,2.40),bodyColor,Enum.Material.Metal)
    local cabin=part(model,"CabinGlass",Vector3.new(2.35,.60,2.46),Vector3.new(0,1.56,.12),Color3.fromRGB(35,52,59),Enum.Material.SmoothPlastic);cabin.Reflectance=.03
    part(model,"Roof",Vector3.new(2.48,.11,2.55),Vector3.new(0,1.90,.15),bodyColor,Enum.Material.Metal)
    for _,x in ipairs({-1.22,1.22})do
        part(model,"WindowPillar",Vector3.new(.075,.65,.10),Vector3.new(x,1.56,.35),bodyColor,Enum.Material.Metal)
        part(model,"Beltline",Vector3.new(.07,.055,5.7),Vector3.new(x*1.16,1.12,.15),Color3.fromRGB(149,150,141),Enum.Material.Metal)
        part(model,"Mirror",Vector3.new(.20,.13,.28),Vector3.new(x*1.24,1.31,-.70),bodyColor,Enum.Material.Metal)
        for _,z in ipairs({-2.12,2.10})do
            local tyre=part(model,"Wheel",Vector3.new(.42,1.10,1.10),Vector3.new(x*1.03,.56,z),Color3.fromRGB(23,25,25),Enum.Material.Rubber);tyre.Shape=Enum.PartType.Cylinder
            local hub=part(model,"WheelHub",Vector3.new(.035,.56,.56),Vector3.new(x*1.22,.56,z),Color3.fromRGB(119,120,113),Enum.Material.Metal);hub.Shape=Enum.PartType.Cylinder
        end
    end
    for _,z in ipairs({-3.29,3.29})do part(model,"Bumper",Vector3.new(2.7,.11,.09),Vector3.new(0,.81,z),Color3.fromRGB(142,145,136),Enum.Material.Metal)end
    part(model,"Grille",Vector3.new(1.25,.22,.025),Vector3.new(0,1.10,-3.267),Color3.fromRGB(29,34,33),Enum.Material.Metal)
    for _,x in ipairs({-.97,.97})do
        local head=part(model,"Headlight",Vector3.new(.48,.20,.025),Vector3.new(x,1.14,-3.27),Color3.fromRGB(224,211,172),Enum.Material.Neon)
        local beam=light(head,"SpotLight",Enum.NormalId.Front,Color3.fromRGB(238,227,197),.55,27);beam.Angle=70
        part(model,"TailLight",Vector3.new(.44,.15,.025),Vector3.new(x,1.08,3.27),Color3.fromRGB(148,51,39),Enum.Material.Neon)
    end
    -- Match a 5-stud avatar: a sedan is about 10.7 studs long and 4.7 wide.
    -- Scale all native geometry together so tyres, lamps and cabin stay aligned.
    local scale=1.65;model:SetAttribute("TrafficScale",scale)
    for _,p in ipairs(model:GetDescendants())do if p:IsA("BasePart")then
        p.Size*=scale;p.CFrame=CFrame.new(p.Position*scale)
    end end
    model.Parent=parent;return model
end
function Scene.trafficFrame(slot,serverTime)
    local phase=(serverTime+(slot==1 and 0 or 16))%34
    if phase>=12.5 then return nil end
    local z=-140+phase/12.5*280
    if slot==1 then return CFrame.new(-55.7,.015,-z)end
    return CFrame.new(-64.3,.015,z)*CFrame.Angles(0,math.pi,0)
end
return Scene
