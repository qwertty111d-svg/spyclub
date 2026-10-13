-- Bounded spy props; optional architecture never participates in loading readiness.
local Dossier={VERSION=5}
local wallLeases=setmetatable({},{__mode="k"})
function Dossier.apply(club)
 local old=club:FindFirstChild("ClubArchive")
 local previous=wallLeases[club]
 if old and old:GetAttribute("DesignVersion")==Dossier.VERSION and previous and previous.model==old then return old end
 -- Restore synchronously before reading originals; engine removal signals may be deferred.
 if previous then previous.release()end
 if old then old:Destroy()end
 local model=Instance.new("Model");model.Name="ClubArchive";model:SetAttribute("DesignVersion",Dossier.VERSION)
 local contractSign=club:FindFirstChild("VIPTitle")
 if contractSign then
  local lettering=contractSign:FindFirstChildWhichIsA("TextLabel",true)
  if lettering then lettering.Text="БАРХАТНЫЙ ЗАЛ"end
 end
 local brass=Color3.fromRGB(145,125,88);local oak=Color3.fromRGB(76,77,73);local ink=Color3.fromRGB(39,43,41)
 local function part(name,size,pos,color,material,variant,parent)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(pos);p.Color=color;p.Material=material or Enum.Material.Metal
  p.MaterialVariant=variant or "";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Reflectance=0;p.Parent=parent or model;return p
 end
 local function lettering(p,name,text,face,size)
  local g=Instance.new("SurfaceGui");g.Name=name;g.Face=face;g.CanvasSize=Vector2.new(840,140);g.LightInfluence=.15;g.AlwaysOnTop=false;g.MaxDistance=55;g.Parent=p
  local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.RobotoMono;t.TextSize=size or 42;t.TextColor3=Color3.fromRGB(228,216,185);t.Text=text;t.Parent=g;return g
 end
 local function light(lens,class,face,brightness,range,angle)
  lens:SetAttribute("ClubFixture",true);lens.Material=Enum.Material.Neon;lens.Transparency=.18
  local l=Instance.new(class);l.Name="ArchiveLight";l.Face=face;l.Brightness=brightness;l.Range=range;l.Angle=angle;l.Shadows=false;l.Color=Color3.fromRGB(255,231,198);l.Parent=lens;return l
 end
 -- Conversation corners face each other; the central carpet remains a clear aisle.
 for i,center in ipairs({Vector3.new(-9,0,-9),Vector3.new(9,0,-9),Vector3.new(9,0,9.2)})do
  local group=Instance.new("Model");group.Name="CafeGroup"..i;group.Parent=model
  local function piece(name,size,offset,color,mat,variant)
   return part(name,size,center+offset,color,mat,variant,group)
  end
  local function disc(name,height,diam,y,color,mat,variant)
   local p=piece(name,Vector3.new(height,diam,diam),Vector3.new(0,y,0),color,mat,variant)
   p.Shape=Enum.PartType.Cylinder;p.CFrame*=CFrame.Angles(0,0,math.pi*.5);return p
  end
  local top=disc("CafeTableTop",.15,2.9,2.25,Color3.fromRGB(78,78,71),Enum.Material.Concrete,"ClubStone")
  top.CanCollide=true;top.CanQuery=true
  disc("TableBrassEdge",.05,2.94,2.175,brass)
  disc("TableFoot",.10,1.75,.15,ink,Enum.Material.Metal,"ClubMetal")
  disc("TableStem",2.02,.22,1.20,brass,Enum.Material.Metal,"ClubMetal")
  for _,side in ipairs({-1,1})do
   local frame=CFrame.new(center+Vector3.new(0,0,side*2.95))*CFrame.Angles(0,side==1 and 0 or math.pi,0)
   local function chairPart(name,size,offset,color,mat,variant)
    local p=part(name,size,Vector3.zero,color,mat,variant,group);p.CFrame=frame*CFrame.new(offset);return p
   end
   local fabric=Color3.fromRGB(62,73,65)
   local seat=Instance.new("Seat");seat.Name="ConversationSeat";seat.Size=Vector3.new(2.25,.16,1.9)
   seat.CFrame=frame*CFrame.new(0,1.66,0);seat.Color=fabric;seat.Material=Enum.Material.Fabric;seat.MaterialVariant="ClubFabric"
   seat.Anchored=true;seat.CanCollide=true;seat.CanTouch=true;seat.CanQuery=true;seat.Parent=group
   chairPart("ChairCushion",Vector3.new(2.25,.27,1.95),Vector3.new(0,1.46,0),fabric,Enum.Material.Fabric,"ClubFabric")
   -- Three angled upholstered back panels give the chair a wrapped silhouette.
   for j=-1,1 do
    local back=chairPart("ChairBack",Vector3.new(.79,1.47,.28),Vector3.new(j*.73,2.12,.90-math.abs(j)*.13),fabric,Enum.Material.Fabric,"ClubFabric")
    back.CFrame*=CFrame.Angles(0,-j*.16,0)
   end
   for _,x in ipairs({-1.15,1.15})do
    chairPart("ChairArm",Vector3.new(.15,.21,1.78),Vector3.new(x,2.0,.04),oak,Enum.Material.Wood,"ClubOak")
    for _,z in ipairs({-.69,.69})do chairPart("ChairLeg",Vector3.new(.13,1.41,.13),Vector3.new(x*.87,.76,z),ink,Enum.Material.Metal,"ClubMetal")end
   end
  end
  local base=disc("CafeLampBase",.075,.4,2.38,brass)
  piece("CafeLampStem",Vector3.new(.05,.48,.05),Vector3.new(0,2.64,0),brass)
  disc("CafeLampShade",.18,.72,2.94,Color3.fromRGB(52,59,52),Enum.Material.Metal,"ClubMetal")
  local lens=disc("CafeLampDiffuser",.025,.56,2.838,Color3.fromRGB(217,190,147))
  light(lens,"SurfaceLight",Enum.NormalId.Left,.35,7,135)
  -- The cylinder's local left face points down after the quarter-turn.
  local cup=piece("EspressoCup",Vector3.new(.24,.26,.24),Vector3.new(.75,2.455,.25),Color3.fromRGB(193,187,168),Enum.Material.SmoothPlastic)
  cup.Shape=Enum.PartType.Cylinder;cup.Size=Vector3.new(.26,.24,.24);cup.CFrame*=CFrame.Angles(0,0,math.pi*.5)
  piece("CafeFolder",Vector3.new(.66,.035,.46),Vector3.new(-.58,2.343,-.24),Color3.fromRGB(138,129,105),Enum.Material.SmoothPlastic)
 end
 -- Cut both structural wall and panelling; the door is recessed into their opening.
 -- Missing architecture omits this optional doorway rather than spawning detached furniture.
 local wall=club:FindFirstChild("FrontWall")
 local restoreLayers={}
 if wall and wall:IsA("BasePart") and wall.Size.X>12 and wall.Size.Y>11 then
  local base=wall.CFrame*CFrame.new(0,-wall.Size.Y*.5,0)
  local halfWidth,height=3.7,10.2
  local opening=Instance.new("Model");opening.Name="DoorWallOpening";opening.Parent=model
  local function splitLayer(original)
   local at=base:Inverse()*original.CFrame
   local left=at.Position.X-original.Size.X*.5;local right=at.Position.X+original.Size.X*.5
   local top=at.Position.Y+original.Size.Y*.5
   local function fragment(x,y,w,h)
    if w<=.001 or h<=.001 then return end
    local p=original:Clone();p.Name="WallFragment";p.Size=Vector3.new(w,h,original.Size.Z)
    p.CFrame=base*CFrame.new(x,y,at.Position.Z);p.Anchored=true;p.Parent=opening
   end
   fragment((left-halfWidth)*.5,at.Position.Y,-halfWidth-left,original.Size.Y)
   fragment((right+halfWidth)*.5,at.Position.Y,right-halfWidth,original.Size.Y)
   if top>height then fragment(0,(top+height)*.5,halfWidth*2,top-height)end
   restoreLayers[#restoreLayers+1]={part=original,values={Transparency=original.Transparency,CanCollide=original.CanCollide,
    CanTouch=original.CanTouch,CanQuery=original.CanQuery,CastShadow=original.CastShadow}}
  end
  splitLayer(wall)
  local panelling=club:FindFirstChild("WallWainscot-33.3")
  local trimPlane=wall.Size.Z*.5
  if panelling and panelling:IsA("BasePart")then
   local at=base:Inverse()*panelling.CFrame
   trimPlane=math.max(trimPlane,at.Position.Z+panelling.Size.Z*.5)
   splitLayer(panelling)
  end
  -- The chair rail is a separate native layer, not part of the timber panel.
  local rail=club:FindFirstChild("BrassRail-33.3")
  if rail and rail:IsA("BasePart")then splitLayer(rail)end
  local door=Instance.new("Model");door.Name="ClubExitDoor";door.Parent=model
  local function doorPart(name,size,pos,color,mat,variant)
   local p=part(name,size,Vector3.zero,color,mat,variant,door);p.CFrame=base*CFrame.new(pos);return p
  end
  local leafZ=wall.Size.Z*.5-.15
  for _,x in ipairs({-1.83,1.83})do
   local leaf=doorPart("ClosedLeaf",Vector3.new(3.64,9.98,.24),Vector3.new(x,5.10,leafZ),Color3.fromRGB(55,60,55),Enum.Material.Wood,"ClubOak")
   leaf.CanCollide=true;leaf.CanQuery=true
   for _,y in ipairs({2.93,7.0})do
    -- Stepped timber mouldings make an actual recessed panel, with metal only on hardware.
    doorPart("DoorPanel",Vector3.new(3.05,3.50,.04),Vector3.new(x,y,leafZ+.135),Color3.fromRGB(45,49,44),Enum.Material.Wood,"ClubOak")
    for _,edge in ipairs({-1.55,1.55})do
     doorPart("PanelStile",Vector3.new(.16,3.72,.12),Vector3.new(x+edge,y,leafZ+.18),oak,Enum.Material.Wood,"ClubOak")
    end
    for _,edge in ipairs({-1.80,1.80})do
     doorPart("PanelMoulding",Vector3.new(3.26,.12,.12),Vector3.new(x,y+edge,leafZ+.18),oak,Enum.Material.Wood,"ClubOak")
    end
   end
   local pullX=x>0 and .40 or -.40
   doorPart("HandleBackplate",Vector3.new(.20,1.45,.045),Vector3.new(pullX,4.4,leafZ+.25),ink,Enum.Material.Metal,"ClubMetal")
   for _,y in ipairs({3.96,4.84})do doorPart("HandleMount",Vector3.new(.10,.08,.20),Vector3.new(pullX,y,leafZ+.36),brass)end
   doorPart("DoorPull",Vector3.new(.09,1.05,.10),Vector3.new(pullX,4.4,leafZ+.48),brass)
  end
  -- A shallow frame touches the existing timber face; deep reveals bridge to the inset leaves.
  local revealDepth=trimPlane+wall.Size.Z*.5
  local revealZ=(trimPlane-wall.Size.Z*.5)*.5
  for _,x in ipairs({-3.655,3.655})do
   doorPart("DoorReveal",Vector3.new(.09,10.12,revealDepth),Vector3.new(x,5.14,revealZ),ink,Enum.Material.Wood,"ClubWalnut")
  end
  doorPart("DoorHeadReveal",Vector3.new(7.4,.10,revealDepth),Vector3.new(0,10.15,revealZ),ink,Enum.Material.Wood,"ClubWalnut")
  for _,x in ipairs({-3.81,3.81})do
   doorPart("DoorJamb",Vector3.new(.22,10.20,.14),Vector3.new(x,5.18,trimPlane-.015),oak,Enum.Material.Wood,"ClubWalnut")
  end
  doorPart("DoorLintel",Vector3.new(7.84,.22,.14),Vector3.new(0,10.18,trimPlane-.015),oak,Enum.Material.Wood,"ClubWalnut")
  doorPart("DoorThreshold",Vector3.new(7.40,.018,revealDepth),Vector3.new(0,.073,revealZ),brass)
  local backing=doorPart("ClosedDoorBacking",Vector3.new(7.40,10.20,.12),Vector3.new(0,5.10,-wall.Size.Z*.5+.06),ink)
  backing.CanCollide=true;backing.CanQuery=true;backing.CastShadow=false
  doorPart("DoorLampHousing",Vector3.new(1.46,.13,.32),Vector3.new(0,10.68,wall.Size.Z*.5+.15),brass)
  local lens=doorPart("DoorLampDiffuser",Vector3.new(1.24,.025,.24),Vector3.new(0,10.601,wall.Size.Z*.5+.15),Color3.fromRGB(221,191,147))
  light(lens,"SurfaceLight",Enum.NormalId.Bottom,.45,11,125)
  local latch=doorPart("LockPlate",Vector3.new(.18,.43,.10),Vector3.new(.40,3.62,leafZ+.31),brass)
  local prompt=Instance.new("ProximityPrompt");prompt.Name="ClubLockedExit";prompt.ActionText="Проверить";prompt.ObjectText="Дверь клуба"
  prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.Style=Enum.ProximityPromptStyle.Default
  prompt.MaxActivationDistance=7;prompt.RequiresLineOfSight=false;prompt.HoldDuration=.15;prompt.Parent=latch
  local lastUse=-math.huge;local responding=false
  local lockedConnection=prompt.Triggered:Connect(function(player)
   local character=player.Character;local root=character and character:FindFirstChild("HumanoidRootPart")
   if not root or model.Parent~=club or (root.Position-latch.Position).Magnitude>9 then return end
   local now=os.clock();if responding or now-lastUse<1.2 then return end;lastUse=now;responding=true
   prompt.ActionText="Заперто"
   task.delay(2,function()if prompt.Parent then prompt.ActionText="Проверить"end;responding=false end)
  end)
  model.Destroying:Connect(function()lockedConnection:Disconnect()end)
 end
 local released=false
 local lease={model=model}
 local function releaseWalls()
  if released then return end;released=true
  if wallLeases[club]==lease then wallLeases[club]=nil end
  for _,layer in ipairs(restoreLayers)do
   if layer.part.Parent then for key,value in pairs(layer.values)do layer.part[key]=value end end
  end
 end
 lease.release=releaseWalls
 model.Destroying:Connect(releaseWalls)
 model.AncestryChanged:Connect(function()
  if model.Parent~=club and wallLeases[club]==lease then releaseWalls()end
 end)
 part("EastWainscot",Vector3.new(.08,2.9,44),Vector3.new(39.43,1.5,-11),oak,Enum.Material.Wood,"ClubOak")
 -- East-wall trim stops before the real corridor opening, leaving windows and front leaderboards alone.
 for _,z in ipairs({-28,-21,-14,-7,0,7})do
  part("OakPanel",Vector3.new(.10,2.8,6.94),Vector3.new(39.34,1.46,z),oak,Enum.Material.Wood,"ClubOak")
  for _,y in ipairs({.2,2.85})do part("PanelMoulding",Vector3.new(.13,.06,6.90),Vector3.new(39.26,y,z),brass)end
  for _,edge in ipairs({-3.45,3.45})do part("PanelMoulding",Vector3.new(.13,2.65,.045),Vector3.new(39.26,1.5,z+edge),brass)end
 end
 part("EastSkirting",Vector3.new(.17,.2,44),Vector3.new(39.25,.15,-11),ink,Enum.Material.Wood,"ClubOak")
 -- Directional pendants over the actual Trio and Quartet game tables.
 for _,x in ipairs({-15,15})do
  local pendant=Instance.new("Model");pendant.Name="MeetingPendant";pendant:SetAttribute("ClubSway",true);pendant.Parent=model
  part("CeilingRose",Vector3.new(.7,.12,.7),Vector3.new(x,15.94,0),ink,nil,nil,pendant)
  part("PendantCable",Vector3.new(.04,3.12,.04),Vector3.new(x,14.32,0),ink,nil,nil,pendant)
  part("PendantShade",Vector3.new(2,.24,2),Vector3.new(x,12.67,0),Color3.fromRGB(59,65,56),Enum.Material.Metal,"ClubMetal",pendant)
  local lens=part("MeetingDiffuser",Vector3.new(1.75,.035,1.75),Vector3.new(x,12.53,0),Color3.fromRGB(250,223,180),nil,nil,pendant)
  local l=light(lens,"SpotLight",Enum.NormalId.Bottom,1.05,13,85);l.Shadows=true
 end
 -- Physical title directly above Vincent; neutral lettering remains readable without showing through walls.
 local title=part("VincentNameplate",Vector3.new(10,.72,.08),Vector3.new(0,11.30,32.77),ink,Enum.Material.Metal,"ClubMetal")
 lettering(title,"VincentLettering","ВИНСЕНТ  /  ХРАНИТЕЛЬ КЛУБА",Enum.NormalId.Front,34)
 local sign=part("BarArchiveNeon",Vector3.new(8,.045,.06),Vector3.new(0,11.78,32.72),Color3.fromRGB(211,175,111),Enum.Material.Neon)
 sign:SetAttribute("ClubPulse",true);light(sign,"SurfaceLight",Enum.NormalId.Front,.45,7,120)
 -- Archive console uses existing real furniture beside the lounge sofa.
 for i=1,3 do
  local f=part("ClassifiedFolder",Vector3.new(.79,.06,.55),Vector3.new(-38.46,2.965+i*.065,-26.7+i*.72),Color3.fromRGB(156-i*9,144-i*7,118-i*5),Enum.Material.SmoothPlastic)
  lettering(f,"SecurityStamp","СЕКРЕТНО",Enum.NormalId.Top,40)
 end
 local recorder=part("TapeRecorder",Vector3.new(.83,.35,1.15),Vector3.new(-38.46,3.12,-24),Color3.fromRGB(49,49,43),Enum.Material.Metal,"ClubMetal")
 for _,z in ipairs({-24.32,-23.69})do
  local reel=part("TapeReel",Vector3.new(.12,.05,.12),Vector3.new(-38.46,3.32,z),brass);reel.Shape=Enum.PartType.Cylinder
 end
 local phone=part("RotaryTelephone",Vector3.new(.82,.22,.85),Vector3.new(-38.46,3.07,-28),ink,Enum.Material.Metal,"ClubMetal")
 part("TelephoneReceiver",Vector3.new(.78,.10,.16),Vector3.new(-38.46,3.26,-28.2),ink,Enum.Material.Metal,"ClubMetal")
 local dial=part("TelephoneDial",Vector3.new(.38,.035,.38),Vector3.new(-38.46,3.2,-27.93),brass);dial.Shape=Enum.PartType.Cylinder
 -- Current visitors are the suspects: actual public headshots, never fabricated user IDs.
 local board=part("EvidenceBoard",Vector3.new(.13,3.8,5.5),Vector3.new(39.28,8.3,3.8),brass)
 local paper=part("EvidenceBacking",Vector3.new(.02,3.58,5.28),Vector3.new(39.19,8.3,3.8),Color3.fromRGB(63,66,57),Enum.Material.Fabric,"ClubFabric")
 local g=Instance.new("SurfaceGui");g.Name="CaseBoard";g.Face=Enum.NormalId.Left;g.CanvasSize=Vector2.new(1000,680);g.LightInfluence=.2;g.AlwaysOnTop=false;g.MaxDistance=45;g.Parent=paper
 local photos={}
 for i=1,4 do
  local frame=Instance.new("Frame");frame.Name="PinnedPrint";frame.Size=UDim2.fromOffset(150,195);frame.Position=UDim2.fromOffset(65+(i-1)*245,100+(i%2)*165)
  frame.Rotation=i%2==0 and 4 or -5;frame.BackgroundColor3=Color3.fromRGB(215,207,185);frame.BorderSizePixel=0;frame.Parent=g
  local image=Instance.new("ImageLabel");image.Name="VisitorPhoto";image.Size=UDim2.fromOffset(136,140);image.Position=UDim2.fromOffset(7,7);image.BackgroundColor3=Color3.fromRGB(74,77,71);image.BorderSizePixel=0;image.ImageColor3=Color3.fromRGB(180,176,160);image.Parent=frame;photos[i]=image
  local label=Instance.new("TextLabel");label.Size=UDim2.fromOffset(136,36);label.Position=UDim2.fromOffset(7,152);label.BackgroundTransparency=1;label.Font=Enum.Font.RobotoMono;label.TextSize=20;label.TextColor3=ink;label.Text="ДЕЛО / 0"..i;label.Parent=frame
 end
 for _,line in ipairs({{170,287,290,110},{400,167,275,165},{645,317,235,110}})do
  local n=Instance.new("Frame");n.Name="EvidenceThread";n.Position=UDim2.fromOffset(line[1],line[2]);n.Size=UDim2.fromOffset(line[3],2);n.Rotation=line[4]==110 and -23 or 28;n.BackgroundColor3=Color3.fromRGB(149,63,47);n.BorderSizePixel=0;n.Parent=g
 end
 local Players=game:GetService("Players")
 local function update()
  local visitors=Players:GetPlayers()
  for i,image in ipairs(photos)do local visitor=visitors[i];image.Image=visitor and visitor.UserId>0 and("rbxthumb://type=AvatarHeadShot&id="..tostring(visitor.UserId).."&w=150&h=150")or ""end
 end
 local a=Players.PlayerAdded:Connect(update);local b=Players.PlayerRemoving:Connect(function()task.defer(update)end)
 model.Destroying:Connect(function()a:Disconnect();b:Disconnect()end);update()
 part("BoardLampHousing",Vector3.new(.44,.13,2.3),Vector3.new(39.1,10.54,3.8),brass)
 local lens=part("BoardLampDiffuser",Vector3.new(.36,.03,2),Vector3.new(39.05,10.46,3.8),Color3.fromRGB(255,225,180));light(lens,"SurfaceLight",Enum.NormalId.Bottom,.7,6,130)
 for _,z in ipairs({-30,30})do
  part("CameraBracket",Vector3.new(.7,.10,.14),Vector3.new(-39.18,12.6,z),ink)
  part("SecurityCamera",Vector3.new(.62,.32,.42),Vector3.new(-38.90,12.35,z),Color3.fromRGB(111,110,99),Enum.Material.Metal,"ClubMetal")
  local eye=part("CameraLens",Vector3.new(.20,.17,.03),Vector3.new(-38.90,12.35,z-.23),ink,Enum.Material.Glass)
 end
 model.Parent=club
 wallLeases[club]=lease
 for _,layer in ipairs(restoreLayers)do
  layer.part.Transparency=1;layer.part.CanCollide=false;layer.part.CanTouch=false;layer.part.CanQuery=false;layer.part.CastShadow=false
 end
 return model
end
return Dossier
