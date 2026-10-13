-- Architecture is optional; it never owns profiles, camera or loading readiness.
local Interior={VERSION=7}
local warm=Color3.fromRGB(255,224,184)
local walnut=Color3.fromRGB(88,67,52)
local bronze=Color3.fromRGB(150,126,89)
local function part(root,name,size,pos,color,material,variant)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(pos);p.Color=color
 p.Material=material or Enum.Material.Metal;p.MaterialVariant=variant or "";p.Reflectance=0
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=root
 return p
end
local function emission(p,face,brightness,range,angle,shadows)
 p:SetAttribute("ClubFixture",true)
 local l=Instance.new("SurfaceLight");l.Name="FixtureEmission";l.Face=face;l.Brightness=brightness;l.Range=range
 l.Angle=angle;l.Color=warm;l.Shadows=shadows==true;l.Parent=p
 return l
end
local function ceiling(root,name,x,y,z,width,length,brightness,range,shadows)
 part(root,name.."Housing",Vector3.new(width+.22,.18,length+.22),Vector3.new(x,y,z),bronze)
 local lens=part(root,name.."Lens",Vector3.new(width,.035,length),Vector3.new(x,y-.108,z),warm,Enum.Material.Neon)
 lens.Transparency=.38;emission(lens,Enum.NormalId.Bottom,brightness,range,115,shadows)
 return lens
end
local function planterBottom(model)
 local pot=model:FindFirstChild("Pot",true)or model:FindFirstChild("Part",true)
 if not pot or not pot:IsA("BasePart")then return nil end
 local cf,s=pot.CFrame,pot.Size
 local half=(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)*.5
 return pot.Position.Y-half
end
local function groundedClone(root,original,name,position)
 if not original then return end
 local copy=original:Clone();copy.Name=name
 for _,p in ipairs(copy:GetDescendants())do
  if p:IsA("LuaSourceContainer") or p:IsA("ProximityPrompt") or p:IsA("ClickDetector")then p:Destroy()
  elseif p:IsA("BasePart")then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end
 end
 local cf,size=copy:GetBoundingBox()
 local bottom=planterBottom(copy)or(cf.Position.Y-size.Y*.5)
 copy:PivotTo(copy:GetPivot()+Vector3.new(position.X-cf.Position.X,position.Y-bottom,position.Z-cf.Position.Z));copy.Parent=root
 return copy
end
function Interior.material(p)
 if not p:IsA("BasePart") then return end
 if p:GetAttribute("SpyAuthoredSurface")then return end
 -- Preserve real imported mesh textures, glass, paper and playing-ball markings.
 if p:IsA("MeshPart") and p.TextureID~="" then return end
 local material=p.Material
 local variants={
  [Enum.Material.Wood]="ClubWalnut",[Enum.Material.WoodPlanks]="ClubWalnut",
  [Enum.Material.Carpet]="ClubWoven",[Enum.Material.Fabric]="ClubFabric",
  [Enum.Material.Metal]="ClubMetal",[Enum.Material.Plaster]="ClubPlaster",
  [Enum.Material.Concrete]="ClubStone",[Enum.Material.Leather]="ClubLeather",
 }
 if material==Enum.Material.WoodPlanks then p.Material=Enum.Material.Wood end
 if variants[material] then if p.MaterialVariant~="ClubOak"and p.MaterialVariant~="ClubWoven"then p.MaterialVariant=variants[material]end;p.Reflectance=(p.Name=="ContinuousFloor"or p.Name=="Floor")and .02 or 0 end
end
function Interior.apply(club)
 local old=club:FindFirstChild("ClubInterior")
 if old and old:GetAttribute("DesignVersion")==Interior.VERSION then return old end
 local model=Instance.new("Model");model.Name="ClubInterior";model:SetAttribute("DesignVersion",Interior.VERSION)
 -- Smoked timber uses actual color/normal/roughness maps on one seamless surface.
 part(model,"ContinuousFloor",Vector3.new(79,.05,67),Vector3.new(0,.035,0),Color3.fromRGB(70,68,64),Enum.Material.Wood,"ClubOak")
 for _,p in ipairs(club:GetChildren())do
  if p:IsA("BasePart")then
   if p.Name:match("^Tile") and math.abs(p.Position.X)<40 and math.abs(p.Position.Z)<34 then p.Transparency=1 end
   if p.Name:match("^Sconce%-?%d+_")then p.Transparency=1 end
   if p.Name=="BarCaption"then p.Transparency=1;local sign=p:FindFirstChildOfClass("SurfaceGui");if sign then sign.Enabled=false end end
   if p.Name=="FrontWall" or p.Name=="BackWall" or p.Name=="WestWall" or p.Name=="EastWall" or p.Name=="EastWallSouth" or p.Name=="EastWallNorth" or p.Name=="EastDoorHeader" then
    p.Material=Enum.Material.Plaster;p.Color=Color3.fromRGB(84,81,74);p.MaterialVariant="ClubPlaster"
   elseif p.Name:match("^WallColumn39_")then
    -- The old half-height posts stood in front of the display wall and evidence board.
    p.Size=Vector3.new(.12,15.8,.20);p.CFrame=CFrame.new(39.40,7.90,p.Position.Z)
    p.Material=Enum.Material.Wood;p.MaterialVariant="ClubWalnut";p.Color=Color3.fromRGB(50,45,38);p.CanCollide=false
   elseif p.Name=="MainCeiling" or p.Name:match("^Ceiling")then
    p.Material=Enum.Material.Wood;p.MaterialVariant="ClubWalnut";p.Color=Color3.fromRGB(74,70,64)
   end
  end
 end
 -- The six old wall emitters were floating 1.55 studs ahead of their actual brass fixtures.
 for _,side in ipairs({-1,1})do for _,z in ipairs({-22,-6,8})do
  local x=side*39.45
  local plate=part(model,"SconceBackplate",Vector3.new(.11,2.18,.54),Vector3.new(x,8.2,z),bronze)
  plate.MaterialVariant="ClubMetal"
  local lens=part(model,"SconceLens",Vector3.new(.16,1.55,.31),Vector3.new(x-side*.12,8.2,z),warm,Enum.Material.Neon)
  lens.Transparency=.22;emission(lens,side<0 and Enum.NormalId.Right or Enum.NormalId.Left,.95,20,125,true)
  local upper=part(model,"SconceUpperLens",Vector3.new(.13,.045,.28),Vector3.new(x-side*.12,9.0,z),warm,Enum.Material.Neon)
  upper.Transparency=.24;emission(upper,Enum.NormalId.Top,.45,10,115,false)
 end end
 -- End-wall sconces reach all four corners without placing lamps in walking routes or over the boards.
 for _,x in ipairs({-37.7,37.7})do for _,side in ipairs({-1,1})do
  local lamp=Instance.new("Model");lamp.Name="CornerSconce";lamp.Parent=model
  part(lamp,"CornerBackplate",Vector3.new(.64,1.85,.12),Vector3.new(x,7.8,side*33.44),bronze,Enum.Material.Metal,"ClubMetal")
  local lens=part(lamp,"CornerLens",Vector3.new(.34,1.28,.12),Vector3.new(x,7.8,side*33.31),warm,Enum.Material.Neon)
  lens.Transparency=.24;emission(lens,side<0 and Enum.NormalId.Back or Enum.NormalId.Front,.95,20,130,true)
  local upper=part(lamp,"CornerUpperLens",Vector3.new(.32,.035,.13),Vector3.new(x,8.47,side*33.31),warm,Enum.Material.Neon)
  upper.Transparency=.26;emission(upper,Enum.NormalId.Top,.35,9,120,false)
  local lower=part(lamp,"CornerLowerLens",Vector3.new(.32,.035,.13),Vector3.new(x,7.13,side*33.31),warm,Enum.Material.Neon)
  lower.Transparency=.26;emission(lower,Enum.NormalId.Bottom,.60,12,120,true)
 end end
 -- Flush ceiling fixtures, including the previously unlit side seating and case aisle.
 for i,z in ipairs({-23,-8,7,22})do ceiling(model,"Aisle"..i,4.5,15.91,z,2.3,1.1,1.15,22,i==2 or i==4)end
 for i,pos in ipairs({{-19,-23},{-19,12},{23,-15},{23,5},{23,23}})do
  ceiling(model,"Side"..i,pos[1],15.91,pos[2],1.65,.9,1.0,22,false)
 end
 for i,x in ipairs({-10,3.8,10})do ceiling(model,"Bar"..i,x,15.91,28,1.6,.85,1.0,19,i==2)end
 for _,x in ipairs({44,49})do ceiling(model,"Corridor"..x,x,11.96,18,1.25,.7,.8,15,false)end
 -- Visible cool strips sit in the window recesses, behind their top rails.
 for _,z in ipairs({-14,16})do
  part(model,"WindowLightHousing",Vector3.new(.20,.10,11.8),Vector3.new(-39.43,12.36,z),bronze)
  local lens=part(model,"WindowLightLens",Vector3.new(.035,.07,11.5),Vector3.new(-39.30,12.32,z),Color3.fromRGB(183,211,233),Enum.Material.Neon)
  lens.Transparency=.2
  local l=emission(lens,Enum.NormalId.Right,.45,15,100,false);l.Color=Color3.fromRGB(177,203,226)
 end
 -- The visible shelf strips emit down onto bottles; no hidden points behind the bar.
 for _,p in ipairs(club:GetChildren())do if p:IsA("BasePart") and p.Name:match("^ShelfLight")then
  p.Material=Enum.Material.Neon;p.Transparency=.12;p.Color=warm
  if not p:FindFirstChild("FixtureEmission")then emission(p,Enum.NormalId.Bottom,.45,6,115,false)end
 end end
 -- An actual inset metal plate on the bar fascia replaces the left HUD location card.
 local plaque=part(model,"LobbyPlaque",Vector3.new(6.8,.85,.09),Vector3.new(0,1.65,23.015),Color3.fromRGB(45,43,38),Enum.Material.Metal,"ClubMetal")
 for _,x in ipairs({-3.34,3.34})do part(model,"PlaqueEdge",Vector3.new(.035,.85,.04),Vector3.new(x,1.65,22.95),bronze)end
 local gui=Instance.new("SurfaceGui");gui.Name="EngravedLobby";gui.Face=Enum.NormalId.Front
 gui.CanvasSize=Vector2.new(1020,128);gui.LightInfluence=.75;gui.AlwaysOnTop=false;gui.MaxDistance=65;gui.Parent=plaque
 local title=Instance.new("TextLabel");title.Name="LobbyLettering";title.BackgroundTransparency=1;title.Size=UDim2.fromScale(1,1)
 title.Font=Enum.Font.RobotoCondensed;title.Text="S P Y   C L U B    /    Л О Б Б И";title.TextSize=47;title.TextColor3=Color3.fromRGB(218,194,149);title.Parent=gui
 groundedClone(model,club:FindFirstChild("ClubPlant"),"EntrancePlant",Vector3.new(-35.7,.06,-29))
 local casePlant=club:FindFirstChild("ClubPlant")
 if casePlant then
  local bottom=planterBottom(casePlant)
  if bottom then casePlant:PivotTo(casePlant:GetPivot()+Vector3.new(0,.06-bottom,0))end
 end
 -- The original bar rail projected into the aisle without any mounting brackets.
 local footRail,cabinet=club:FindFirstChild("BarFootRail"),club:FindFirstChild("BarCabinet")
 if footRail and cabinet and footRail:IsA("BasePart")and cabinet:IsA("BasePart")then
  local face=(footRail.CFrame:Inverse()*cabinet.CFrame).Position.Z-cabinet.Size.Z*.5
  if face>.10 and face<2 then
   for _,fraction in ipairs({-.40,-.20,0,.20,.40})do
    local x=footRail.Size.X*fraction
    local bracket=part(model,"FootRailBracket",Vector3.new(.12,.12,face+.12),Vector3.zero,bronze,Enum.Material.Metal,"ClubMetal")
    bracket.CFrame=footRail.CFrame*CFrame.new(x,0,face*.5)
    local plate=part(model,"RailMountPlate",Vector3.new(.24,.35,.055),Vector3.zero,bronze,Enum.Material.Metal,"ClubMetal")
    plate.CFrame=footRail.CFrame*CFrame.new(x,0,face)
   end
  end
 end
 -- The tall desk plant hid the reward and dominated low camera angles. Retain the imported asset, out of view.
 local plant=club:FindFirstChild("DailyPlant")
 if plant then for _,p in ipairs(plant:GetDescendants())do if p:IsA("BasePart")then
  p.Transparency=1;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 end end end
 local desk=club:FindFirstChild("DailyTop")
 if desk and desk:IsA("BasePart")then
  local center=desk.Position+Vector3.new(-2.57,desk.Size.Y*.5, -.265)
  local recorder=Instance.new("Model");recorder.Name="RewardRecorder";recorder.Parent=model
  part(recorder,"RecorderBody",Vector3.new(1.75,.40,1.0),center+Vector3.new(0,.20,0),Color3.fromRGB(49,52,49),Enum.Material.Metal,"ClubMetal")
  part(recorder,"RecorderFace",Vector3.new(1.60,.30,.035),center+Vector3.new(0,.20,-.51),Color3.fromRGB(110,112,107),Enum.Material.Metal,"ClubMetal")
  for _,x in ipairs({-.33,.33})do
   local reel=part(recorder,"RecorderReel",Vector3.new(.035,.25,.25),center+Vector3.new(x,.23,-.55),bronze,Enum.Material.Metal,"ClubMetal")
   reel.Shape=Enum.PartType.Cylinder;reel.CFrame*=CFrame.Angles(0,math.pi*.5,0)
  end
  for i=1,4 do part(recorder,"RecorderKey",Vector3.new(.13,.035,.09),center+Vector3.new(-.30+i*.15,.058,-.55),Color3.fromRGB(63,64,60))end
 end
 -- A grounded lounge lamp gives the sofa a warm side light from an actual visible bulb.
 part(model,"LoungeLampFoot",Vector3.new(1.05,.10,1.05),Vector3.new(-22.5,.11,-23.8),bronze)
 part(model,"LoungeLampStem",Vector3.new(.08,4.7,.08),Vector3.new(-22.5,2.5,-23.8),bronze)
 part(model,"LoungeLampShade",Vector3.new(1.25,.16,.9),Vector3.new(-22.9,4.84,-23.8),Color3.fromRGB(46,43,37))
 local bulb=part(model,"LoungeLampBulb",Vector3.new(.19,.19,.19),Vector3.new(-22.9,4.66,-23.8),warm,Enum.Material.Neon)
 bulb.Shape=Enum.PartType.Ball;bulb.CastShadow=false;bulb:SetAttribute("ClubFixture",true)
 local glow=Instance.new("PointLight");glow.Name="BulbGlow";glow.Color=warm;glow.Brightness=.38;glow.Range=11;glow.Shadows=true;glow.Parent=bulb
 -- Furniture belongs beside the sofa and against the wall, leaving every game route open.
 part(model,"LibraryTop",Vector3.new(1.15,.15,7),Vector3.new(-38.5,2.85,-25.5),walnut,Enum.Material.Wood,"ClubWalnut")
 part(model,"LibraryShelf",Vector3.new(1.1,.13,7),Vector3.new(-38.5,.8,-25.5),walnut,Enum.Material.Wood,"ClubWalnut")
 for _,z in ipairs({-28.7,-22.3})do part(model,"LibraryLeg",Vector3.new(.11,2.8,.16),Vector3.new(-38.5,1.46,z),bronze)end
 local colors={Color3.fromRGB(84,98,94),Color3.fromRGB(111,77,57),Color3.fromRGB(157,140,111)}
 for i=1,11 do
  local h=1.1+(i%3)*.14
  part(model,"BoundVolume",Vector3.new(.73,h,.21),Vector3.new(-38.46,.865+h*.5,-27.8+i*.26),colors[(i-1)%3+1],Enum.Material.Fabric,"ClubFabric")
 end
 -- A small, deliberately drawn brass-line artwork; no generated billboard or guessed image ID.
 local frame=part(model,"ArchiveFrame",Vector3.new(.15,3.1,4.3),Vector3.new(-39.31,7.3,-26.6),bronze)
 for _,y in ipairs({6,8.6})do for _,z in ipairs({-28.5,-24.7})do
  part(model,"FrameStandOff",Vector3.new(.13,.10,.10),Vector3.new(-39.435,y,z),bronze)
 end end
 part(model,"ArchiveMat",Vector3.new(.025,2.88,4.08),Vector3.new(-39.22,7.3,-26.6),Color3.fromRGB(41,48,46),Enum.Material.Plaster,"ClubPlaster")
 for i=1,5 do part(model,"ArchiveLines",Vector3.new(.018,.035,2.4-i*.23),Vector3.new(-39.20,6.45+i*.28,-26.6),Color3.fromRGB(154,133,91))end
 local artLens=part(model,"PictureLampLens",Vector3.new(.28,.07,2.3),Vector3.new(-39.03,9.14,-26.6),warm,Enum.Material.Neon)
 part(model,"PictureLampHousing",Vector3.new(.32,.13,2.5),Vector3.new(-39.05,9.24,-26.6),bronze)
 for _,z in ipairs({-27.4,-25.8})do part(model,"PictureLampBracket",Vector3.new(.5,.06,.1),Vector3.new(-39.28,9.22,z),bronze)end
 emission(artLens,Enum.NormalId.Bottom,.6,6,115,false)
 -- Short wall-mounted picture lights replace the articulated ceiling heads above the cases.
 local lit={};local names={AtelierCase=true,ClassicCase=true,SilverCase=true,GoldCase=true}
 local function display(item)
  if not item:IsA("Model")or not names[item.Name]or lit[item]then return end
  local prompt=item:FindFirstChild("CasePrompt",true)
  if not prompt and item.Name=="AtelierCase"and item.Parent then prompt=item.Parent:FindFirstChild("CasePrompt",true)end
  local anchor=prompt and prompt.Parent
  if not anchor or not anchor:IsA("BasePart")then return end
  local pos=anchor.Position;lit[item]=true
  local lamp=Instance.new("Model");lamp.Name="DisplayFixture_"..item.Name;lamp.Parent=model
  -- Ceiling-flush keys are in FRONT of the cases, illuminating the visible face.
  part(lamp,"DisplayHousing",Vector3.new(1.52,.18,1.12),Vector3.new(35.1,15.91,pos.Z),bronze,Enum.Material.Metal,"ClubMetal")
  local lens=part(lamp,"DisplayLens",Vector3.new(1.3,.035,.9),Vector3.new(35.1,15.802,pos.Z),warm,Enum.Material.Neon)
  lens.Transparency=.38
  local light=emission(lens,Enum.NormalId.Bottom,1.35,20,110,false);light.Name="DisplayAccent";light.Color=Color3.fromRGB(247,233,211)
  -- Refinish existing imported podium geometry; retain its mesh and collision.
  for _,stand in ipairs(workspace:GetChildren())do
   if stand:IsA("Model")and stand~=club and stand~=item and not names[stand.Name]then
    for _,p in ipairs(stand:GetDescendants())do if p:IsA("BasePart")then
     local delta=p.Position-pos
     if p.Position.Y>.25 and p.Position.Y<4.2 and Vector3.new(delta.X,0,delta.Z).Magnitude<2.2 then
      p.Color=Color3.fromRGB(68,74,64);p.Material=Enum.Material.Wood;p.MaterialVariant="ClubOak";p.Reflectance=.015
     end
    end end
   end
  end
  local pedestal=item.Parent and item.Parent:FindFirstChild("Pedestal")
  if pedestal then for _,p in ipairs(pedestal:GetDescendants())do if p:IsA("BasePart")then p.Color=Color3.fromRGB(68,74,64);p.Material=Enum.Material.Wood;p.MaterialVariant="ClubOak";p.Reflectance=.015 end end end
  item.Destroying:Connect(function()lit[item]=nil;lamp:Destroy()end)
 end
 local function scanDisplays()for _,item in ipairs(workspace:GetDescendants())do display(item)end end
 local pending=false
 local connection=workspace.DescendantAdded:Connect(function(item)
  if (item:IsA("Model")and names[item.Name])or item:IsA("ProximityPrompt")then
   if pending then return end;pending=true;task.defer(function()pending=false;if model.Parent then scanDisplays()end end)
  end
 end)
 model.Destroying:Connect(function()connection:Disconnect()end)
 if old then old:Destroy()end
 model.Parent=club;scanDisplays()
 for _,p in ipairs(club:GetDescendants())do Interior.material(p)end
 task.defer(function()
  local modules=game:GetService("ServerStorage"):FindFirstChild("SpyModules")
  local module=modules and modules:FindFirstChild("CaseSet")
  if module and model.Parent then local ok,set=pcall(require,module);if ok then pcall(set.lobby,club)end end
 end)
 return model
end
return Interior
