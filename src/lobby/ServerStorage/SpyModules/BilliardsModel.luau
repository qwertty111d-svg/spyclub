-- Original native-part club table; no third-party scripts, guessed assets or runtime downloads.
local Model={}
Model.CENTER=Vector3.new(-26,0,-2.5)
Model.WORLD_SCALE=1.15
Model.PLAY_HEIGHT=3.36+.13725*Model.WORLD_SCALE
function Model.point(x,z,height)
    return Model.CENTER+Vector3.new(x*Model.WORLD_SCALE,height or Model.PLAY_HEIGHT,z*Model.WORLD_SCALE)
end
local C={wood=Color3.fromRGB(70,63,51),edge=Color3.fromRGB(39,43,36),brass=Color3.fromRGB(172,143,100),
    felt=Color3.fromRGB(44,89,72),cushion=Color3.fromRGB(30,65,51),ivory=Color3.fromRGB(239,231,209),hole=Color3.fromRGB(9,12,10)}
local BALL_COLORS={Color3.fromRGB(231,179,40),Color3.fromRGB(49,94,174),Color3.fromRGB(184,52,43),
    Color3.fromRGB(112,66,149),Color3.fromRGB(220,117,43),Color3.fromRGB(39,126,81),Color3.fromRGB(128,38,50),Color3.fromRGB(25,25,27)}
local function part(parent,name,size,pos,color,material,collide)
    local s=Model.WORLD_SCALE
    local p=Instance.new("Part");p.Name=name;p.Size=Vector3.new(size.X*s,size.Y,size.Z*s)
    p.CFrame=CFrame.new(Model.point(pos.X,pos.Z,pos.Y))
    p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
    local variants={[Enum.Material.Wood]="ClubWalnut",[Enum.Material.Carpet]="ClubTextile",[Enum.Material.Metal]="ClubMetal",[Enum.Material.Fabric]="ClubFabric"}
    p.MaterialVariant=variants[p.Material]or "";p.Anchored=true
    p.CanCollide=collide==true;p.CanTouch=false;p.CanQuery=collide==true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=parent;return p
end
local function cylinder(parent,name,radius,height,pos,color,material)
    local p=part(parent,name,Vector3.new(height,radius*2,radius*2),pos,color,material)
    -- Native cylinders run along local X, rotated to world Y below.
    -- Scale their diameter in the playing plane, preserving their height.
    p.Size=Vector3.new(height,radius*2*Model.WORLD_SCALE,radius*2*Model.WORLD_SCALE)
    p.Shape=Enum.PartType.Cylinder;p.CFrame*=CFrame.Angles(0,0,math.pi/2);return p
end
function Model.ball(parent,id,x,z,parameters,mode)
    local radius=parameters and parameters.RADIUS or .18;local height=3.36+radius*Model.WORLD_SCALE
    local color=mode=="pyramid"and(id==0 and BALL_COLORS[1]or C.ivory)or(id==0 and C.ivory or BALL_COLORS[(id-1)%8+1])
    local p=part(parent,"Ball"..id,Vector3.new(.36,.36,.36),Vector3.new(x,height,z),mode~="pyramid"and id>=9 and C.ivory or color)
    local diameter=radius*2*Model.WORLD_SCALE;p.Size=Vector3.new(diameter,diameter,diameter)
    p.Shape=Enum.PartType.Ball;p.Reflectance=.14;p:SetAttribute("BallId",id)
    if mode~="pyramid"and id>=9 then
        -- A thin native cylinder makes the colored belt; white spherical caps remain.
        local belt=cylinder(p,"Stripe",radius+.001,radius*.78*Model.WORLD_SCALE,Vector3.new(x,height,z),color)
        belt.Anchored=false;belt.Reflectance=.14
        local weld=Instance.new("WeldConstraint");weld.Name="StripeWeld";weld.Part0=p;weld.Part1=belt;weld.Parent=p
    end
    if id>0 then
        -- Small round number discs only; a square SurfaceGui is not a wrapped skin.
        for _,face in ipairs({Enum.NormalId.Top,Enum.NormalId.Bottom}) do
            local gui=Instance.new("SurfaceGui");gui.Name="Number";gui.Face=face;gui.CanvasSize=Vector2.new(120,120)
            gui.LightInfluence=.65;gui.AlwaysOnTop=false;gui.Parent=p
            local disc=Instance.new("TextLabel");disc.Size=UDim2.fromScale(.42,.42);disc.Position=UDim2.fromScale(.29,.29)
            disc.BackgroundColor3=C.ivory;disc.TextColor3=Color3.fromRGB(24,23,26);disc.Font=Enum.Font.GothamBold;disc.Text=tostring(id);disc.TextSize=38;disc.BorderSizePixel=0;disc.Parent=gui
            local round=Instance.new("UICorner");round.CornerRadius=UDim.new(1,0);round.Parent=disc
        end
    end
    return p
end
function Model.heightFor(mode)return 3.36+(mode=="pyramid"and .16330708661417322 or .13725)*Model.WORLD_SCALE end
function Model.pose(b,height)
    local x,y,z,w=b.qx or 0,b.qy or 0,b.qz or 0,b.qw or 1
    local drop=b.fallT and math.min(1.1,.5*47.12*b.fallT^2)*Model.WORLD_SCALE or 0
    return CFrame.new(Model.point(b.x,b.z,height-drop))*CFrame.new(0,0,0,
        1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),
        2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),
        2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y))
end
function Model.applyMode(m,physics,mode)
    local p=physics.parameters(mode);local height=Model.heightFor(mode)
    for _,name in ipairs({"Balls","MouthGeometry"})do local old=m:FindFirstChild(name);if old then old:Destroy()end end
    local geometry=Instance.new("Folder");geometry.Name="MouthGeometry";geometry.Parent=m
    local hx,hz=physics.HALF_X,physics.HALF_Z
    -- Narrow conservative bed strips cut all six apertures out of the felt.
    -- There is no solid felt sheet underneath the black mouth.
    local slices=physics.BED_SLICES;local width=2*hx/slices
    for index=0,slices-1 do
        local x=-hx+(index+.5)*width;local cut=physics.apertureCut(x,p)
        local depth=2*(hz-cut)
        part(geometry,"SlateSupport",Vector3.new(width+.0001,.55,depth),Vector3.new(x,3.035,0),C.edge,Enum.Material.Slate,true)
        part(geometry,"BedStrip",Vector3.new(width+.0001,.1,depth),Vector3.new(x,3.31,0),C.felt,Enum.Material.Carpet,true)
    end
    local inner=p.MOUTH;local outer=hx-p.CORNER;local length=outer-inner
    for _,signZ in ipairs({-1,1})do for _,signX in ipairs({-1,1})do
        local x=signX*(inner+outer)/2
        part(geometry,"Cushion",Vector3.new(length,.19,.18),Vector3.new(x,3.37,signZ*(hz+.09)),C.cushion)
        part(geometry,"LongRail",Vector3.new(length,.27,.61),Vector3.new(x,3.38,signZ*(hz+.30)),C.edge,Enum.Material.Wood,true)
    end end
    for _,sign in ipairs({-1,1})do
        part(geometry,"EndCushion",Vector3.new(.18,.19,(hz-p.CORNER)*2),Vector3.new(sign*(hx+.09),3.37,0),C.cushion)
        part(geometry,"EndRail",Vector3.new(.61,.27,(hz-p.CORNER)*2),Vector3.new(sign*(hx+.30),3.38,0),C.edge,Enum.Material.Wood,true)
    end
    -- Flush rounded caps bridge the two rail ends around each mouth. The inner
    -- radius stays outside the server's actual capture aperture in every mode.
    local function pocketCap(cx,cz,radius,side)
        local sx=cx<0 and -1 or 1;local sz=cz<0 and -1 or 1
        local first,last=side and 0 or -math.pi/2,math.pi
        local segments=side and 12 or 18
        local step=(last-first)/segments
        local inner,outer=radius+.032,.61
        local mid=(inner+outer)*.5
        for i=0,segments-1 do
            local angle=first+(i+.5)*step
            local dx,dz=math.cos(angle)*(side and 1 or sx),math.sin(angle)*sz
            local rotation=math.atan2(dz,dx)
            local cap=part(geometry,"RoundedRailCap",Vector3.new(outer-inner,.12,2*outer*math.tan(step*.5)+.002),Vector3.new(cx+dx*mid,3.455,cz+dz*mid),C.edge,Enum.Material.Wood)
            cap.CFrame*=CFrame.Angles(0,-rotation,0)
            local leatherInner,leatherOuter=radius+.012,radius+.063
            local leatherMid=(leatherInner+leatherOuter)*.5
            local lip=part(geometry,"PocketTrim",Vector3.new(leatherOuter-leatherInner,.020,2*leatherOuter*math.tan(step*.5)+.001),Vector3.new(cx+dx*leatherMid,3.36,cz+dz*leatherMid),Color3.fromRGB(43,40,33),Enum.Material.Leather)
            lip.MaterialVariant="ClubLeather";lip.CFrame*=CFrame.Angles(0,-rotation,0)
        end
    end
    for i,pocket in ipairs(physics.POCKETS)do
        local pocketRadius=physics.pocketRadius(p,i)
        -- A recessed leather throat, without an oversized bright ring.
        cylinder(geometry,"Pocket"..i,pocketRadius,.025,Vector3.new(pocket[1],2.76,pocket[2]),C.hole)
        pocketCap(pocket[1],pocket[2],pocketRadius,i==2 or i==5)
        local liner=Instance.new("Folder");liner.Name="LeatherPocket"..i;liner.Parent=geometry
        for segment=0,15 do
            local angle=(segment+.5)*math.pi/8;local radius=pocketRadius+.015
            local wall=part(liner,"PocketLiner",Vector3.new(.035,.39,2*radius*math.sin(math.pi/16)),Vector3.new(pocket[1]+math.cos(angle)*radius,2.975,pocket[2]+math.sin(angle)*radius),C.hole,Enum.Material.Fabric)
            wall.CFrame*=CFrame.Angles(0,-angle,0)
        end
    end
    for _,jaw in ipairs(physics.jaws(p))do cylinder(geometry,"PocketJaw",p.JAW,.19,Vector3.new(jaw[1],3.37,jaw[2]),C.cushion)end
    local balls=Instance.new("Folder");balls.Name="Balls";balls.Parent=m;local refs={}
    for _,b in ipairs(physics.newRack(mode))do refs[b.id]=Model.ball(balls,b.id,b.x,b.z,p,mode)end
    m:SetAttribute("Mode",mode);m:SetAttribute("RuleSet",mode);m:SetAttribute("BallRadius",p.RADIUS*Model.WORLD_SCALE);m:SetAttribute("PlayHeight",height)
    return refs
end
function Model.build(root,physics,mode)
    mode=mode or "pool8"
    -- Keep the coffee setting beside the sofa; the pool table occupies the
    -- clear floor further into the club, away from the lounge seats.
    if root:GetAttribute("BilliardsLoungeArrangement")~=2 then
        local offset=Vector3.new(8,0,-5)
        for _,name in ipairs({"LoungeTableBase","LoungeTableStem","LoungeTableTop","LoungeBook","LoungeCoffee"})do
            local object=root:FindFirstChild(name)
            if object then
                if object:IsA("BasePart")then object.CFrame+=offset
                else for _,p in ipairs(object:GetDescendants())do if p:IsA("BasePart")then p.CFrame+=offset end end end
            end
        end
        root:SetAttribute("BilliardsLoungeArrangement",2)
    end
    local existing=root:FindFirstChild("ClubBilliards")
    if existing then existing:Destroy() end
    local m=Instance.new("Model");m.Name="ClubBilliards";m:SetAttribute("DesignVersion",9)
    m:SetAttribute("Center",Model.CENTER);m:SetAttribute("PlayHeight",Model.PLAY_HEIGHT)
    m:SetAttribute("WorldScale",Model.WORLD_SCALE)
    m:SetAttribute("PlayHalfX",physics.HALF_X*Model.WORLD_SCALE);m:SetAttribute("PlayHalfZ",physics.HALF_Z*Model.WORLD_SCALE)
    m:SetAttribute("BallRadius",physics.RADIUS*Model.WORLD_SCALE);m:SetAttribute("PlayingAxes","X long / Z short")
    m:SetAttribute("RuleSet",mode);m:SetAttribute("AssetOrigin","OriginalNativeParts")
    local body=part(m,"WalnutBody",Vector3.new(14,.17,7),Vector3.new(0,2.62,0),C.wood,Enum.Material.Wood,true)
    m.PrimaryPart=body
    for _,sign in ipairs({-1,1})do
        part(m,"WalnutApron",Vector3.new(14,.66,.20),Vector3.new(0,2.95,sign*3.48),C.wood,Enum.Material.Wood,true)
        part(m,"WalnutApron",Vector3.new(.20,.66,6.8),Vector3.new(sign*6.90,2.95,0),C.wood,Enum.Material.Wood,true)
    end
    part(m,"LowerMoulding",Vector3.new(13.7,.17,6.7),Vector3.new(0,2.47,0),C.edge,Enum.Material.Wood)
    -- Four substantial legs with brass shoes and turned walnut collars.
    for _,x in ipairs({-5.1,5.1}) do for _,z in ipairs({-2.15,2.15}) do
        cylinder(m,"Leg",.39,2.08,Vector3.new(x,1.36,z),C.wood,Enum.Material.Wood).CanCollide=true
        cylinder(m,"Foot",.49,.20,Vector3.new(x,.24,z),C.edge,Enum.Material.Wood)
        cylinder(m,"BrassShoe",.415,.17,Vector3.new(x,.45,z),C.brass,Enum.Material.Metal)
        cylinder(m,"TurnedCollar",.47,.22,Vector3.new(x,2.18,z),C.wood,Enum.Material.Wood)
    end end
    part(m,"CrossBrace",Vector3.new(10.7,.31,.27),Vector3.new(0,.85,0),C.edge,Enum.Material.Wood)
    for _,z in ipairs({-3.35,3.35}) do for _,x in ipairs({-4.65,-3.10,-1.55,1.55,3.10,4.65}) do
        local sight=part(m,"IvorySight",Vector3.new(.09,.009,.09),Vector3.new(x,3.52,z),C.ivory)
        sight.CFrame*=CFrame.Angles(0,math.pi/4,0)
    end end
    -- Rules live in the interaction panel; the physical table has no advertising plates.
    -- Northside cue rack clears the actual sofa, boards and contact desk.
    local rack=Vector3.new(-5.5,0,-5.1)
    part(m,"CueRackBase",Vector3.new(2.1,.15,.55),rack+Vector3.new(0,.30,0),C.wood,Enum.Material.Wood)
    part(m,"CueRackTop",Vector3.new(2.1,.16,.4),rack+Vector3.new(0,4.15,0),C.wood,Enum.Material.Wood)
    for _,x in ipairs({-.78,-.26,.26,.78}) do
        local cue=part(m,"RackCue",Vector3.new(.075,4.8,.075),rack+Vector3.new(x,2.65,0),Color3.fromRGB(186,144,92),Enum.Material.Wood)
        cylinder(m,"RackCueCollar",.046,.18,rack+Vector3.new(x,4.67,0),C.brass,Enum.Material.Metal)
        part(m,"RackCueTip",Vector3.new(.079,.08,.079),rack+Vector3.new(x,5.08,0),Color3.fromRGB(106,145,152))
        cue.CanQuery=false
    end
    -- A single restrained fixture flush-mounted to the actual 16-stud ceiling.
    -- Nothing hangs in the player's view or between the pool camera and balls.
    part(m,"CeilingLightHousing",Vector3.new(7.6,.22,.72),Vector3.new(0,15.89,0),C.edge,Enum.Material.Metal)
    part(m,"CeilingLightTrim",Vector3.new(7.4,.04,.68),Vector3.new(0,15.76,0),C.brass,Enum.Material.Metal)
    local diffuser=part(m,"CeilingLightDiffuser",Vector3.new(7.2,.025,.49),Vector3.new(0,15.7275,0),C.ivory,Enum.Material.Neon)
    diffuser:SetAttribute("ClubFixture",true);diffuser.Transparency=.18
    local light=Instance.new("SurfaceLight");light.Face=Enum.NormalId.Bottom;light.Color=Color3.fromRGB(255,233,207)
    light.Brightness=1.5;light.Range=22;light.Angle=100;light.Shadows=true;light.Parent=diffuser
    local refs=Model.applyMode(m,physics,mode)
    local anchor=part(m,"JoinPoint",Vector3.new(.1,.1,.1),Vector3.new(0,2.5,4.20),C.ivory)
    anchor.Transparency=1
    local prompt=Instance.new("ProximityPrompt");prompt.Name="BilliardsEnter";prompt.ActionText="За стол"
    prompt.ObjectText="Бильярд · тренировка / 2 игрока";prompt.KeyboardKeyCode=Enum.KeyCode.E
    prompt.HoldDuration=0;prompt.MaxActivationDistance=8;prompt.RequiresLineOfSight=false;prompt.Style=Enum.ProximityPromptStyle.Custom;prompt.Parent=anchor
    m.Parent=root
    return m,refs,prompt
end
return Model
