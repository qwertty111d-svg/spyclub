-- The entrance is its own room above the map. It cannot cover a lobby board or aisle.
local Set={VERSION=11}
function Set.apply(club)
    local old=club:FindFirstChild("NocturneLounge")
    if old and old:GetAttribute("DesignVersion")==Set.VERSION then return old end
    local model=Instance.new("Model");model.Name="NocturneLounge"
    pcall(function()model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent end)
    local origin=Vector3.new(0,60,0)
    local function part(name,size,pos,color,material,alpha)
        local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(origin+pos)
        p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Transparency=alpha or 0
        if name:find("Diffuser",1,true)then p:SetAttribute("ClubFixture",true)end
        if name=="Floor"then p.Material=Enum.Material.Wood;p.MaterialVariant="ClubOak"elseif material==Enum.Material.Carpet then p.MaterialVariant="ClubWoven"end
        p.Reflectance=0;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=true;p.Parent=model
        return p
    end
    local charcoal=Color3.fromRGB(84,81,74);local wood=Color3.fromRGB(70,68,64)
    part("Floor",Vector3.new(30,.3,27),Vector3.new(0,-.15,0),wood,Enum.Material.WoodPlanks)
    part("Ceiling",Vector3.new(30,.3,27),Vector3.new(0,12,0),Color3.fromRGB(55,48,40))
    part("BackWall",Vector3.new(30,12,.3),Vector3.new(0,6,-13.5),charcoal,Enum.Material.Plaster)
    part("RightWall",Vector3.new(.3,12,27),Vector3.new(15,6,0),charcoal,Enum.Material.Plaster)
    -- A restrained architectural rhythm, grounded furniture and a textile sitting area.
    part("BackWainscot",Vector3.new(29.5,2.6,.12),Vector3.new(0,1.3,-13.27),wood,Enum.Material.Wood)
    part("PictureRail",Vector3.new(29.5,.045,.12),Vector3.new(0,2.65,-13.18),Color3.fromRGB(135,116,85),Enum.Material.Metal)
    local rug=part("EntranceTextile",Vector3.new(14,.1,7.5),Vector3.new(-2,.052,-7.4),Color3.fromRGB(42,55,49),Enum.Material.Carpet)
    rug.CastShadow=false
    for _,x in ipairs({-10.5,-7.5,-4.5,-1.5,1.5,4.5,7.5,10.5})do
        part("WallBatten",Vector3.new(.045,7.5,.09),Vector3.new(x,7.1,-13.29),Color3.fromRGB(53,48,42),Enum.Material.Wood)
    end
    -- Leave clear knee space for tall portrait rigs; table props move with its footprint.
    part("CoffeeTableTop",Vector3.new(5,.18,2.7),Vector3.new(-2,1.25,-4.1),Color3.fromRGB(63,57,49),Enum.Material.Marble)
    for _,x in ipairs({-3.95,-.05})do for _,z in ipairs({-5.05,-3.15})do
        part("CoffeeTableLeg",Vector3.new(.12,1.16,.12),Vector3.new(x,.58,z),Color3.fromRGB(72,69,62),Enum.Material.Metal)
    end end
    -- One large window, with real mullions and a visible exterior; no opaque decorative screen.
    part("WindowBelow",Vector3.new(.3,2,27),Vector3.new(-15,1,0),wood)
    part("WindowAbove",Vector3.new(.3,2,27),Vector3.new(-15,11,0),charcoal)
    for _,z in ipairs({-11,-3,5,13}) do part("WindowMullion",Vector3.new(.35,8,.15),Vector3.new(-15,6,z),wood,Enum.Material.Wood) end
    local glass=part("Glass",Vector3.new(.08,8,24),Vector3.new(-15,6,1),Color3.fromRGB(180,195,198),Enum.Material.SmoothPlastic,.96)
    glass:SetAttribute("RainPane",true);glass:SetAttribute("RainFace","Right")
    -- Reuse the actual sofa meshes already shipped in the place, without scripts, seats or prompts.
    local sofa=club:FindFirstChild("LoungeSofa")
    local seatFrame
    if sofa then
        local copy=sofa:Clone();copy.Name="EntranceSofa"
        local cf,size=copy:GetBoundingBox()
        local distance=math.huge
        for _,n in ipairs(copy:GetDescendants())do if n:IsA("Seat")then
            local d=math.abs(n.Position.X-cf.Position.X)
            if d<distance then distance=d;seatFrame=n.CFrame*CFrame.new(0,n.Size.Y*.5,0)end
        end end
        for _,n in ipairs(copy:GetDescendants()) do
            if n:IsA("LuaSourceContainer") or n:IsA("Seat") or n:IsA("ProximityPrompt") or n:IsA("ClickDetector") then n:Destroy()
            elseif n:IsA("BasePart") then n.Anchored=true;n.CanCollide=false;n.CanTouch=false;n.CanQuery=false end
        end
        local delta=origin+Vector3.new(-3,size.Y*.5,-9)-cf.Position
        copy:PivotTo(copy:GetPivot()+delta)
        if seatFrame then seatFrame=seatFrame+delta end
        copy.Parent=model
    end
    local hero=part("HeroSeat",Vector3.new(.1,.1,.1),Vector3.new(-2.94,1.803,-8.55),charcoal,nil,1)
    hero.CFrame=(seatFrame or CFrame.new(origin+Vector3.new(-2.94,1.803,-8.55))*CFrame.Angles(0,math.pi,0))*CFrame.new(0,.10,-.18)
    hero.CastShadow=false;hero:SetAttribute("FloorY",origin.Y+.102)
    -- A grounded side table and a lamp whose diffuser owns the light.
    part("SideTableTop",Vector3.new(2.8,.15,2.8),Vector3.new(3.7,2.2,-8.4),wood,Enum.Material.Wood)
    part("SideTableStem",Vector3.new(.18,2.1,.18),Vector3.new(3.7,1.05,-8.4),Color3.fromRGB(108,91,68),Enum.Material.Metal)
    part("SideTableFoot",Vector3.new(1.8,.12,1.8),Vector3.new(3.7,.06,-8.4),charcoal,Enum.Material.Metal)
    part("LampBase",Vector3.new(.9,.08,.9),Vector3.new(3.7,2.32,-8.4),charcoal,Enum.Material.Metal)
    part("LampStem",Vector3.new(.06,3.25,.06),Vector3.new(3.7,3.995,-8.4),Color3.fromRGB(164,139,99),Enum.Material.Metal)
    part("LampShade",Vector3.new(2,.35,1.35),Vector3.new(3.7,5.73,-8.4),Color3.fromRGB(55,48,40),Enum.Material.Metal)
    local diffuser=part("LampDiffuser",Vector3.new(1.8,.04,1.1),Vector3.new(3.7,5.53,-8.4),Color3.fromRGB(201,178,141),Enum.Material.Neon,0)
    local light=Instance.new("SurfaceLight");light.Name="LampLight";light.Face=Enum.NormalId.Bottom;light.Color=Color3.fromRGB(255,225,191)
    light.Brightness=1.35;light.Range=13;light.Angle=145;light.Shadows=true;light.Parent=diffuser
    -- A visible lamp diffuser sends a broad face light sideways; the downlight alone missed the seated portrait.
    local face=part("PortraitKeyDiffuser",Vector3.new(.035,.11,1.08),Vector3.new(2.79,5.53,-8.4),Color3.fromRGB(201,178,141),Enum.Material.Neon,0)
    local key=Instance.new("SurfaceLight");key.Name="PortraitKeyLight";key.Face=Enum.NormalId.Left;key.Color=Color3.fromRGB(255,234,212)
    key.Brightness=.85;key.Range=13;key.Angle=140;key.Shadows=true;key.Parent=face
    -- Cool rim comes from a visible strip mounted to the wall behind the seated portrait.
    part("PortraitRimHousing",Vector3.new(3.4,.13,.12),Vector3.new(-3,6.1,-13.23),Color3.fromRGB(135,116,85),Enum.Material.Metal)
    for _,x in ipairs({-4.4,-1.6})do part("PortraitRimBracket",Vector3.new(.08,.07,.18),Vector3.new(x,6.1,-13.30),charcoal,Enum.Material.Metal)end
    local rim=part("PortraitRimDiffuser",Vector3.new(3.1,.055,.035),Vector3.new(-3,6.1,-13.14),Color3.fromRGB(173,201,219),Enum.Material.Neon,.2)
    local back=Instance.new("SurfaceLight");back.Name="PortraitRimLight";back.Face=Enum.NormalId.Back;back.Color=Color3.fromRGB(173,201,219)
    back.Brightness=.65;back.Range=11;back.Angle=110;back.Shadows=false;back.Parent=rim
    for _,x in ipairs({-7,6}) do
        local trim=part("CeilingFixture",Vector3.new(1.4,.12,1.4),Vector3.new(x,11.79,-4),charcoal,Enum.Material.Metal)
        local lens=part("CeilingDiffuser",Vector3.new(1.1,.035,1.1),Vector3.new(x,11.7125,-4),Color3.fromRGB(242,223,199),Enum.Material.Neon,.35)
        local spot=Instance.new("SpotLight");spot.Name="CeilingLight";spot.Face=Enum.NormalId.Bottom;spot.Color=Color3.fromRGB(255,231,207)
        spot.Brightness=1.05;spot.Angle=110;spot.Range=18;spot.Shadows=true;spot.Parent=lens
    end
    -- Real volumes and opaque window panes remain visible through the smooth rain glass.
    local exterior=Instance.new("Model");exterior.Name="Exterior";exterior.Parent=model
    local function outside(name,size,pos,color,mat)
        local p=part(name,size,pos,color,mat);p.Parent=exterior;return p
    end
    outside("NightBackdrop",Vector3.new(1,100,140),Vector3.new(-140,24,0),Color3.fromRGB(24,31,40))
    outside("NightRoad",Vector3.new(25,.20,110),Vector3.new(-29,-2.3,0),Color3.fromRGB(31,36,39),Enum.Material.Asphalt)
    for i,z in ipairs({-25,-3,22})do
        local h=36+i*6;local x=-48-(i%2)*13
        outside("CityTower",Vector3.new(14,h,17),Vector3.new(x,h*.5-5,z),Color3.fromRGB(42+i*3,48+i*2,53+i),Enum.Material.Concrete)
        outside("TowerCornice",Vector3.new(14.8,.6,17.8),Vector3.new(x,h-5,z),Color3.fromRGB(61,64,66),Enum.Material.Concrete)
        for row=0,7 do
            local y=-1+row*4.6
            outside("FloorBand",Vector3.new(.22,.16,17.15),Vector3.new(x+7.12,y+1.9,z),Color3.fromRGB(58,61,63),Enum.Material.Concrete)
            for col=0,3 do
                local lit=(row*3+col+i)%5~=0
                local pane=outside("CityWindow",Vector3.new(.18,2.35,1.42),Vector3.new(x+7.12,y,z-6+col*3.9),
                    lit and ((row+col)%4==0 and Color3.fromRGB(116,148,161) or Color3.fromRGB(182,151,107)) or Color3.fromRGB(35,44,48),
                    lit and Enum.Material.Neon or Enum.Material.SmoothPlastic)
                pane.CastShadow=false
            end
        end
        -- The return wall shows depth when the camera moves past the rain window.
        for row=0,6 do for col=0,2 do
            local pane=outside("CityWindow",Vector3.new(1.40,2.35,.18),Vector3.new(x-4.4+col*4.4,-1+row*4.6,z-8.61),
                (row+col)%3==0 and Color3.fromRGB(174,144,105) or Color3.fromRGB(42,50,53),
                (row+col)%3==0 and Enum.Material.Neon or Enum.Material.SmoothPlastic)
            pane.CastShadow=false
        end end
    end
    -- A low back-wall library grounds the frame; its objects rest on the shelf.
    part("LibraryTop",Vector3.new(6.8,.14,.95),Vector3.new(6.6,2.55,-12.6),wood,Enum.Material.Wood)
    part("LibraryLower",Vector3.new(6.8,.12,.95),Vector3.new(6.6,.65,-12.6),wood,Enum.Material.Wood)
    for _,x in ipairs({3.5,9.7})do part("LibraryLeg",Vector3.new(.12,2.5,.12),Vector3.new(x,1.25,-12.6),Color3.fromRGB(146,124,88),Enum.Material.Metal)end
    for i=1,9 do
        local h=1.05+(i%3)*.13
        part("LibraryVolume",Vector3.new(.23,h,.7),Vector3.new(4.3+i*.27,.71+h*.5,-12.6),Color3.fromRGB(69+i*4,67+i*2,55+i),Enum.Material.Fabric)
    end
    local painting=part("FramedArchive",Vector3.new(5.3,3.2,.12),Vector3.new(6.5,6.9,-13.25),Color3.fromRGB(134,114,82),Enum.Material.Metal)
    part("ArchivePaper",Vector3.new(5.1,3,.03),Vector3.new(6.5,6.9,-13.17),Color3.fromRGB(51,62,59),Enum.Material.Plaster)
    for i=1,5 do part("ArchiveDrawing",Vector3.new(3.4-i*.38,.035,.015),Vector3.new(6.5,6.1+i*.27,-13.14),Color3.fromRGB(174,152,104),Enum.Material.Metal)end
    -- Low archive equipment replaces the large potted plant: it stays below the portrait's face.
    part("PortraitRecorder",Vector3.new(1.55,.36,.88),Vector3.new(3.7,2.455,-7.48),Color3.fromRGB(49,52,49),Enum.Material.Metal)
    part("PortraitRecorderFace",Vector3.new(1.40,.28,.035),Vector3.new(3.7,2.455,-7.0225),Color3.fromRGB(110,112,107),Enum.Material.Metal)
    for _,x in ipairs({3.4,4.0})do
        local reel=part("PortraitRecorderReel",Vector3.new(.035,.24,.24),Vector3.new(x,2.455,-6.9925),Color3.fromRGB(150,126,89),Enum.Material.Metal)
        reel.Shape=Enum.PartType.Cylinder;reel.CFrame*=CFrame.Angles(0,math.pi*.5,0)
    end
    -- A closed archive door and telephone communicate a private appointment, not a public shop.
    part("PrivateDoor",Vector3.new(.12,7,3.2),Vector3.new(14.73,3.5,4.5),Color3.fromRGB(63,67,61),Enum.Material.Wood)
    for _,z in ipairs({2.83,6.17})do part("DoorCasing",Vector3.new(.19,7.2,.13),Vector3.new(14.64,3.6,z),Color3.fromRGB(137,121,86),Enum.Material.Metal)end
    part("DoorLintel",Vector3.new(.19,.13,3.47),Vector3.new(14.64,7.13,4.5),Color3.fromRGB(137,121,86),Enum.Material.Metal)
    part("PrivateDoorHandle",Vector3.new(.20,.12,.6),Vector3.new(14.5,3.45,5.63),Color3.fromRGB(160,143,103),Enum.Material.Metal)
    local file=part("MeetingDossier",Vector3.new(1.25,.055,.86),Vector3.new(-2.7,1.365,-4.45),Color3.fromRGB(169,157,126))
    part("MeetingTelephone",Vector3.new(1.03,.25,.76),Vector3.new(-.8,1.465,-4.15),Color3.fromRGB(39,44,39),Enum.Material.Metal)
    part("MeetingReceiver",Vector3.new(1.1,.11,.19),Vector3.new(-.8,1.68,-4.32),Color3.fromRGB(32,36,32),Enum.Material.Metal)
    local dial=part("MeetingDial",Vector3.new(.45,.035,.45),Vector3.new(-.8,1.606,-3.92),Color3.fromRGB(143,124,87),Enum.Material.Metal);dial.Shape=Enum.PartType.Cylinder
    -- The seated portrait occupies the left third; the club entrance remains on the right.
    local opening=part("OpeningCamera",Vector3.new(.1,.1,.1),Vector3.new(7.4,4.7,5.9),charcoal,nil,1)
    opening.CFrame=CFrame.lookAt(origin+Vector3.new(7.4,4.7,5.9),origin+Vector3.new(1.8,3.8,-10.2));opening.CastShadow=false
    local camera=part("EntryCamera",Vector3.new(.1,.1,.1),Vector3.new(5.6,4.4,2.8),charcoal,nil,1)
    camera.CFrame=CFrame.lookAt(origin+Vector3.new(5.6,4.4,2.8),origin+Vector3.new(1.2,3.8,-9.8));camera.CastShadow=false
    local mobile=part("MobileCamera",Vector3.new(.1,.1,.1),Vector3.new(1.8,4.2,3.4),charcoal,nil,1)
    mobile.CFrame=CFrame.lookAt(origin+Vector3.new(1.8,4.2,3.4),hero.Position+Vector3.new(0,2,0));mobile.CastShadow=false
    local exit=part("ExitCamera",Vector3.new(.1,.1,.1),Vector3.new(5.2,3.9,.8),charcoal,nil,1)
    exit.CFrame=CFrame.lookAt(origin+Vector3.new(5.2,3.9,.8),origin+Vector3.new(-5.7,3.9,-8.55));exit.CastShadow=false
    model:SetAttribute("DesignVersion",Set.VERSION);model.Parent=club
    if old then old:Destroy() end
    return model
end
return Set
