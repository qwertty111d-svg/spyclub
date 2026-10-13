-- Real west-wall bays with server-owned ventilation. Presentation never gates lobby boot.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Windows={VERSION=7}
local function part(parent,name,size,pos,color,material,collision)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(pos)
 p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 if name=="WallPier"or name=="WallBelow"or name=="WallAbove"then p.Material=Enum.Material.Plaster;p.MaterialVariant="ClubPlaster"end
 p.Anchored=true;p.CanCollide=collision==true;p.CanTouch=false;p.CanQuery=collision==true
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end
local function glass(parent,name,size,pos)
 -- Refractive Glass hides translucent scenery on lower graphics settings.
 -- Rain SurfaceGuis and the physical frame carry the glass appearance instead.
 local p=part(parent,name,size,pos,Color3.fromRGB(210,218,220),Enum.Material.SmoothPlastic,false)
 p.Transparency=.97;p.Reflectance=0;p.CastShadow=false
 p:SetAttribute("RainPane",true);p:SetAttribute("RainFace","Right");return p
end
local function vent(bay,z,wood,trim)
 local sash=Instance.new("Model");sash.Name="VentSash";sash.Parent=bay
 local hinge=CFrame.new(-39.78,7.625,z+3)
 local pivot=part(sash,"VentPivot",Vector3.new(.05,.05,.05),hinge.Position,wood,nil,false)
 pivot.Transparency=1;pivot.CastShadow=false;sash.PrimaryPart=pivot
 glass(sash,"VentGlass",Vector3.new(.10,4.50,5.62),Vector3.new(-39.78,5.375,z+3))
 for _,side in ipairs({-1,1})do part(sash,"SashEdge",Vector3.new(.16,4.64,.12),Vector3.new(-39.72,5.375,z+3+side*2.87),wood,Enum.Material.Wood,false)end
 for _,y in ipairs({3.055,7.695})do part(sash,"SashRail",Vector3.new(.16,.12,5.84),Vector3.new(-39.72,y,z+3),wood,Enum.Material.Wood,false)end
 local handle=part(sash,"WindowHandle",Vector3.new(.17,.11,.75),Vector3.new(-39.56,3.65,z+3),trim,Enum.Material.Metal,false)
 local prompt=Instance.new("ProximityPrompt");prompt.Name="WindowPrompt"
 prompt.ActionText="Приоткрыть";prompt.ObjectText="Окно · дождь"
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
 prompt.HoldDuration=.25;prompt.MaxActivationDistance=8;prompt.RequiresLineOfSight=false;prompt.Parent=handle
 local pose=Instance.new("NumberValue");pose.Name="OpenPose";pose.Value=0;pose.Parent=bay
 local tween,lastToggle=nil,-math.huge
 bay:SetAttribute("WindowOpen",false)
 local poseConnection=pose:GetPropertyChangedSignal("Value"):Connect(function()
  if sash.Parent then sash:PivotTo(hinge*CFrame.Angles(0,0,-math.rad(18)*pose.Value))end
 end)
 local triggerConnection=prompt.Triggered:Connect(function(player)
  local character=player and player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  if not root or not root:IsA("BasePart")or not bay.Parent or (root.Position-handle.Position).Magnitude>9.5 then return end
  local now=os.clock();if now-lastToggle<.85 then return end;lastToggle=now
  local open=not bay:GetAttribute("WindowOpen")
  bay:SetAttribute("WindowOpen",open);prompt.ActionText=open and "Закрыть"or "Приоткрыть"
  if tween then tween:Cancel()end
  tween=TweenService:Create(pose,TweenInfo.new(.65,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Value=open and 1 or 0})
  tween:Play()
 end)
 bay.Destroying:Connect(function()triggerConnection:Disconnect();poseConnection:Disconnect();if tween then tween:Cancel()end end)
end
function Windows.apply(club)
 local existing=club:FindFirstChild("RainWindows")
 if existing and existing:GetAttribute("RainWindowsVersion")==Windows.VERSION then return existing end
 local original=club:FindFirstChild("WestWall")
 if not original or not original:IsA("BasePart")then return nil end
 local model=Instance.new("Model");model.Name="RainWindows"
 pcall(function()model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent end)
 local wall=original.Color
 for _,rect in ipairs({{-27,14},{1,18},{28,12}})do
  part(model,"WallPier",Vector3.new(1,20,rect[2]),Vector3.new(-40,10,rect[1]),wall,nil,true)
 end
 -- The original continuous panelling reaches y=4 and hides the lowered bays.
 -- Keep its height between windows and finish it directly below the new sills.
 local wainscot=club:FindFirstChild("WestWainscot")
 if wainscot and wainscot:IsA("BasePart")then
  for _,rect in ipairs({{-26.75,13.5},{1,18},{27.75,11.5}})do
   local panel=part(model,"WainscotPier",Vector3.new(.4,4,rect[2]),Vector3.new(-39.25,2,rect[1]),wainscot.Color,wainscot.Material,true)
   panel.MaterialVariant=wainscot.MaterialVariant
  end
  for _,z in ipairs({-14,16})do
   local panel=part(model,"WainscotBelow",Vector3.new(.4,2.83,12),Vector3.new(-39.25,1.415,z),wainscot.Color,wainscot.Material,true)
   panel.MaterialVariant=wainscot.MaterialVariant
  end
 end
 for index,z in ipairs({-14,16})do
  part(model,"WallBelow",Vector3.new(1,3,12),Vector3.new(-40,1.5,z),wall,nil,true)
  part(model,"WallAbove",Vector3.new(1,7.5,12),Vector3.new(-40,16.25,z),wall,nil,true)
  local bay=Instance.new("Model");bay.Name=index==1 and "EntranceWindow"or "LoungeWindow";bay.Parent=model
  local wood=Color3.fromRGB(53,45,43);local trim=Color3.fromRGB(144,127,97)
  glass(bay,"Glass",Vector3.new(.10,4.52,11.65),Vector3.new(-39.82,10.125,z))
  glass(bay,"GlassLowerLeft",Vector3.new(.10,4.50,5.62),Vector3.new(-39.82,5.375,z-3))
  local guard=part(bay,"SafetyPane",Vector3.new(.10,9.5,12),Vector3.new(-40.15,7.75,z),wood,nil,true)
  guard.Transparency=1;guard.CanQuery=false;guard.CastShadow=false
  for _,side in ipairs({-1,1})do
   part(bay,"Jamb",Vector3.new(.34,9.85,.34),Vector3.new(-39.47,7.75,z+side*6),wood,Enum.Material.Wood,true)
   part(bay,"Trim",Vector3.new(.04,9.55,.055),Vector3.new(-39.24,7.75,z+side*5.8),trim,Enum.Material.Metal,false)
  end
  for _,y in ipairs({3.0,7.75,12.5})do part(bay,"Rail",Vector3.new(.32,.20,12.3),Vector3.new(-39.46,y,z),wood,Enum.Material.Wood,false)end
  part(bay,"Mullion",Vector3.new(.28,9.5,.16),Vector3.new(-39.44,7.75,z),wood,Enum.Material.Wood,false)
  part(bay,"Sill",Vector3.new(1.3,.20,12.8),Vector3.new(-39.3,2.93,z),wood,Enum.Material.Wood,true)
  vent(bay,z,wood,trim)
  -- Physical weatherproof light under the external window canopy. Its inward
  -- cone passes through the actual aperture; walls still cast proper shadows.
  part(bay,"ExteriorCanopy",Vector3.new(.36,.20,12.2),Vector3.new(-40.72,12.36,z),trim,Enum.Material.Metal,false)
  local lens=part(bay,"WindowStreetLens",Vector3.new(.055,.10,11.3),Vector3.new(-40.53,12.22,z),Color3.fromRGB(206,217,224),Enum.Material.Neon,false)
  lens.CFrame*=CFrame.Angles(0,0,-math.rad(25));lens.Transparency=0;lens.CastShadow=false;lens:SetAttribute("ClubFixture",true)
  local spill=Instance.new("SurfaceLight");spill.Name="StreetSpill";spill.Face=Enum.NormalId.Right;spill.Angle=110
  spill.Color=Color3.fromRGB(193,210,224);spill.Brightness=.85;spill.Range=24;spill.Shadows=true;spill.Parent=lens
  local pavement=Instance.new("SurfaceLight");pavement.Name="CanopyPavement";pavement.Face=Enum.NormalId.Bottom;pavement.Angle=100
  pavement.Color=Color3.fromRGB(216,219,218);pavement.Brightness=.35;pavement.Range=16;pavement.Shadows=false;pavement.Parent=lens
 end
 local exterior=Instance.new("Model");exterior.Name="Exterior";exterior.Parent=model
 local ok,detail=pcall(function()
  local shared=ReplicatedStorage:FindFirstChild("SpyShared")
  local scene=shared and shared:FindFirstChild("NightStreetScene")
  assert(scene,"NightStreetScene missing");require(scene).build(exterior)
 end)
 model:SetAttribute("NightStreetStatus",ok and "ready"or "failed")
 if not ok then warn("[NightStreet] "..tostring(detail))end
 model:SetAttribute("RainWindowsVersion",Windows.VERSION);model.Parent=club
 -- The existing shell stays until the full replacement is attached.
 if existing then existing:Destroy()end
 original.Transparency=1;original.CanCollide=false;original.CanQuery=false;original.CastShadow=false
 if wainscot and wainscot:IsA("BasePart")then
  wainscot.Transparency=1;wainscot.CanCollide=false;wainscot.CanQuery=false;wainscot.CastShadow=false
 end
 return model
end
return Windows
