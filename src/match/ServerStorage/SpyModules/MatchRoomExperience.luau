-- Physical match feedback. Observes authoritative attributes, never runs a round.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local Room={}
local running=setmetatable({}, {__mode="k"})
local BRASS=Color3.fromRGB(148,124,86)
local WARM=Color3.fromRGB(245,215,165)
local DARK=Color3.fromRGB(28,31,35)
local function part(parent,name,size,cf,color,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
    p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true
    p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=true;p.Parent=parent
    return p
end
local function downwardFace(p)
    local choices={{Enum.NormalId.Right,Vector3.new(1,0,0)},{Enum.NormalId.Left,Vector3.new(-1,0,0)},
        {Enum.NormalId.Top,Vector3.new(0,1,0)},{Enum.NormalId.Bottom,Vector3.new(0,-1,0)},
        {Enum.NormalId.Front,Vector3.new(0,0,-1)},{Enum.NormalId.Back,Vector3.new(0,0,1)}}
    local result,lowest=Enum.NormalId.Bottom,math.huge
    for _,choice in ipairs(choices)do
        local y=p.CFrame:VectorToWorldSpace(choice[2]).Y
        if y<lowest then lowest=y;result=choice[1]end
    end
    return result
end
function Room.start(room)
    if running[room]then return running[room]end
    local tableModel=room and room:FindFirstChild("GameTable")
    local felt=tableModel and tableModel:FindFirstChild("Felt")
    local floor=room and room:FindFirstChild("MainFloor")
    if not felt or not floor then return nil end
    local old=room:FindFirstChild("MatchExperience")
    if old then old:Destroy()end
    local decor=Instance.new("Folder");decor.Name="MatchExperience";decor.Parent=room
    local center=felt.Position
    local top=center.Y+math.min(felt.Size.X,felt.Size.Y,felt.Size.Z)*.5
    local signals,lamps={},{}
    for index=1,4 do
        local cushion=tableModel:FindFirstChild("Cushion"..index,true)
        local direction=cushion and Vector3.new(cushion.Position.X-center.X,0,cushion.Position.Z-center.Z)
            or Vector3.new(math.sin((index-1)*math.pi*.5),0,-math.cos((index-1)*math.pi*.5))
        direction=direction.Magnitude>.01 and direction.Unit or Vector3.new(0,0,-1)
        local position=Vector3.new(center.X,top+.055,center.Z)+direction*4.9
        local base=part(decor,"TurnSignal"..index,Vector3.new(.7,.05,.16),CFrame.lookAt(position,position-direction),DARK,Enum.Material.Metal)
        local glow=part(base,"SignalLens",Vector3.new(.5,.018,.075),base.CFrame*CFrame.new(0,.033,0),Color3.fromRGB(64,70,73),Enum.Material.SmoothPlastic)
        local light=Instance.new("PointLight");light.Name="SpeakingLight";light.Color=WARM;light.Range=3
        light.Brightness=0;light.Shadows=false;light.Parent=glow
        signals[index]=base;lamps[index]={glow=glow,light=light}
    end
    local board=part(decor,"RoomPhaseBoard",Vector3.new(7.2,2.15,.12),
        floor.CFrame*CFrame.new(0,7.1,-floor.Size.Z*.5+.35),DARK,Enum.Material.Metal)
    local surface=Instance.new("SurfaceGui");surface.Name="StatusDisplay";surface.Face=Enum.NormalId.Back
    surface.CanvasSize=Vector2.new(864,258);surface.LightInfluence=.15;surface.Parent=board
    local function boardText(name,y,height,size,color)
        local text=Instance.new("TextLabel");text.Name=name;text.Position=UDim2.fromOffset(32,y)
        text.Size=UDim2.new(1,-64,0,height);text.BackgroundTransparency=1;text.Text=""
        text.Font=Enum.Font.BuilderSansBold;text.TextSize=size;text.TextColor3=color;text.Parent=surface;return text
    end
    local heading=boardText("ClubStamp",16,30,20,BRASS);heading.Text="SPY CLUB  /  PRIVATE TABLE"
    local phaseTitle=boardText("PhaseTitle",63,64,44,Color3.fromRGB(240,235,223))
    local phaseClock=boardText("PhaseClock",147,62,42,WARM)
    -- The original ceiling lamp is a rotated thin cylinder. A hard-coded
    -- Bottom face projects sideways; choose its actual downward face instead.
    local lamp=tableModel:FindFirstChild("LampFace")
    if lamp then
        -- Keep the existing suspension, but stop the diffuser filling the POV.
        for _,name in ipairs({"Lamp","LampFace"})do
            local shell=tableModel:FindFirstChild(name)
            if shell and shell:IsA("BasePart")and not shell:GetAttribute("SpyCompactShade")then
                local size=shell.Size
                shell.Size=Vector3.new(size.X,size.Y*.55,size.Z*.55)
                shell:SetAttribute("SpyCompactShade",true)
            end
        end
        lamp.Color=Color3.fromRGB(224,222,209);lamp.Material=Enum.Material.SmoothPlastic
        local pool=lamp:FindFirstChild("TablePool")
        if pool then pool.Face=downwardFace(lamp);pool.Angle=105;pool.Brightness=1.25 end
    end
    local centerGlow=tableModel:FindFirstChild("Glow")
    if centerGlow then
        centerGlow.Transparency=1
        for _,light in ipairs(centerGlow:GetChildren())do if light:IsA("Light")then light.Enabled=false end end
    end
    felt.Material=Enum.Material.SmoothPlastic;felt.Color=Color3.fromRGB(29,48,46);felt.Reflectance=0
    floor.Material=Enum.Material.WoodPlanks;floor.Color=Color3.fromRGB(44,39,37);floor.Reflectance=.025
    for _,p in ipairs(room:GetDescendants())do
        if p:IsA("BasePart")and (p.Name=="Rug" or p.Name=="VIPMainRug"or p.Name:match("^Cushion%d+$"))then
            p.Material=Enum.Material.Fabric;p.Color=Color3.fromRGB(58,57,66)
        end
    end
    -- The tabletop is for role cards. Archive props belong on the rear cabinets.
    local cabinetY=floor.Size.Y*.5+2.56
    local cabinetZ=-floor.Size.Z*.5+1.95
    local recorder=part(decor,"TapeRecorder",Vector3.new(1.65,.22,.95),floor.CFrame*CFrame.new(floor.Size.X*.32,cabinetY,cabinetZ),DARK,Enum.Material.Metal)
    for _,x in ipairs({-.42,.42})do
        local reel=part(recorder,"TapeReel",Vector3.new(.06,.52,.52),recorder.CFrame*CFrame.new(x,.15,-.06)*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(181,178,167),Enum.Material.Metal)
        reel.Shape=Enum.PartType.Cylinder
    end
    part(recorder,"PlayKey",Vector3.new(.2,.035,.15),recorder.CFrame*CFrame.new(-.45,.135,.34),BRASS,Enum.Material.Metal)
    local folder=part(decor,"SealedDossier",Vector3.new(1.5,.045,1),floor.CFrame*CFrame.new(-floor.Size.X*.32,cabinetY-.09,cabinetZ),Color3.fromRGB(86,67,57),Enum.Material.Fabric)
    part(folder,"ArchiveBand",Vector3.new(1.42,.015,.085),folder.CFrame*CFrame.new(0,.032,-.32),BRASS,Enum.Material.Metal)
    local session,connections=nil,{}
    local function currentSeat()
        if not session then return 0 end
        local id=tonumber(session:GetAttribute("CurrentTurnUserId"))or 0
        if id==0 then return 0 end
        local p=Players:GetPlayerByUserId(id)
        local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        local seat=h and h.SeatPart
        if seat then local index=tonumber(seat.Name:match("^MatchSeat(%d+)$"));if index then return index end end
        local members=session:FindFirstChild("MemberIdsJson")
        local ok,ids=pcall(function()return HttpService:JSONDecode(members and members.Value or "[]")end)
        if ok and type(ids)=="table"then for index,memberId in ipairs(ids)do if memberId==id then return index end end end
        return 0
    end
    local function update()
        local phase=session and session:GetAttribute("RoundPhase")or "Waiting"
        local seat=phase=="Hint"and currentSeat()or 0
        for i,base in ipairs(signals)do
            local active=i==seat
            base:SetAttribute("Active",active)
            lamps[i].glow.Color=active and WARM or Color3.fromRGB(64,70,73)
            lamps[i].glow.Material=active and Enum.Material.Neon or Enum.Material.SmoothPlastic
            lamps[i].light.Brightness=active and .16 or 0
        end
        local titles={Waiting="СТОЛ ГОТОВИТСЯ",Intro="КАРТЫ НА СТОЛ",Role="ТВОЁ ДЕЛО",Discuss="ОБСУЖДЕНИЕ",
            Vote="ГОЛОСОВАНИЕ",ExtraRound="ЕЩЁ КРУГ",Result="ИТОГ ПАРТИИ",Finished="ВОЗВРАЩЕНИЕ"}
        phaseTitle.Text=phase=="Hint"and string.format("ПОДСКАЗКА  /  МЕСТО %02d",seat)or titles[phase]or "SPY CLUB"
        local remaining=math.max(0,math.ceil((session and session:GetAttribute("PhaseEndAt")or 0)-workspace:GetServerTimeNow()))
        phaseClock.Text=remaining>0 and string.format("%d:%02d",math.floor(remaining/60),remaining%60)or "—"
    end
    local function bind(value)
        if session or value.Name~="MatchSession"then return end
        session=value
        for _,attribute in ipairs({"RoundPhase","CurrentTurnUserId","PhaseEndAt"})do
            table.insert(connections,session:GetAttributeChangedSignal(attribute):Connect(update))
        end
        update()
    end
    local initial=ReplicatedStorage:FindFirstChild("MatchSession")
    if initial then bind(initial)end
    table.insert(connections,ReplicatedStorage.ChildAdded:Connect(bind))
    task.spawn(function()while decor.Parent do update();task.wait(1)end end)
    local controller={update=update,destroy=function()
        for _,connection in ipairs(connections)do connection:Disconnect()end
        running[room]=nil;decor:Destroy()
    end}
    running[room]=controller;update();return controller
end
return Room
