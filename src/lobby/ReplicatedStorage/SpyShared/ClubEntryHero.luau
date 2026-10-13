-- Client-only portrait. Every joint is solved on an anchored clone, never on the live avatar.
local Hero={}
-- Upper-body variations share the same supported pelvis/legs for every avatar scale.
local poses={
 {waist={8,-3,-2},neck={-5,9,1},left={14,0,-5},right={18,0,10},elbows={32,28}},
 {waist={4,5,1},neck={-3,-12,0},left={18,0,-8},right={12,0,5},elbows={28,35}},
 {waist={7,-6,0},neck={-2,16,-1},left={11,0,-4},right={21,0,8},elbows={36,30}},
}
local function jointRecord(n,owned)
 local a,b,c0,c1,animated
 if n:IsA("Motor6D")or n:IsA("Weld")then
  a,b,c0,c1=n.Part0,n.Part1,n.C0,n.C1;animated=n:IsA("Motor6D")
 elseif n:IsA("AnimationConstraint")or n:IsA("RigidConstraint")then
  local aa,bb=n.Attachment0,n.Attachment1
  if not aa or not bb then return end
  a=aa:FindFirstAncestorWhichIsA("BasePart");b=bb:FindFirstAncestorWhichIsA("BasePart")
  if not a or not b then return end
  -- World offsets include optional Bone parents and work without compatibility aliases.
  c0=a.CFrame:ToObjectSpace(aa.WorldCFrame);c1=b.CFrame:ToObjectSpace(bb.WorldCFrame)
  animated=n:IsA("AnimationConstraint")
 elseif n:IsA("WeldConstraint")then
  a,b=n.Part0,n.Part1;if not a or not b then return end
  c0=a.CFrame:ToObjectSpace(b.CFrame);c1=CFrame.new()
 else return end
 if not owned[a]or not owned[b]then return end
 return {Part0=a,Part1=b,C0=c0,C1=c1,object=n,animated=animated}
end
local function lowerEdge(p)
 local y=math.huge
 for _,x in ipairs({-1,1})do for _,z in ipairs({-1,1})do for _,v in ipairs({-1,1})do
  y=math.min(y,p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X*.5,v*p.Size.Y*.5,z*p.Size.Z*.5)).Y)
 end end end
 return y
end
function Hero.create(context)
 local self={alive=true,connections={},time=0}
 self.poseIndex=math.clamp(math.floor(tonumber(context.poseIndex)or math.random(1,#poses)),1,#poses)
 local portraitPose=poses[self.poseIndex]
 local player,set=context.player,context.set
 local anchor=set:FindFirstChild("HeroSeat")
 if not anchor then self.alive=false end
 local function clear()
  if self.model then self.model:Destroy();self.model=nil end
  if self.footrest then self.footrest:Destroy();self.footrest=nil end
  self.joints=nil;self.root=nil;self.pose=nil
 end
 function self:destroy()
  self.alive=false
  for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
  if self.appearance then self.appearance:Disconnect();self.appearance=nil end
  clear()
 end
 local function solve()
  if not self.root then return end
  self.root.CFrame=self.rootFrame
  local solved={[self.root]=true}
  for _=1,8 do
   local changed=false
   for _,j in ipairs(self.joints)do
   local a,b=j.Part0,j.Part1;local t=self.pose[j]or CFrame.new()
    if j.animated then j.object.Transform=t end
    if solved[a]and not solved[b]then b.CFrame=a.CFrame*j.C0*t*j.C1:Inverse();solved[b]=true;changed=true
    elseif solved[b]and not solved[a]then a.CFrame=b.CFrame*j.C1*t:Inverse()*j.C0:Inverse();solved[a]=true;changed=true end
   end
   if not changed then break end
  end
 end
 local function angle(j,x,y,z)
  if not j then return end
  -- R6 joints have different local axes. Rotate in the parent body's basis in both rigs.
  local r=j.C0.Rotation
  self.pose[j]=r:Inverse()*CFrame.Angles(x or 0,y or 0,z or 0)*r
 end
 local function rebuild()
  if not self.alive or not set.Parent or player:GetAttribute("SpyEntryCompleted")==true then return end
  local source=player.Character
  if not source or not source:FindFirstChild("HumanoidRootPart")or not source:FindFirstChildOfClass("Humanoid")then return end
  local previous=source.Archivable
  source.Archivable=true
  local ok,copy=pcall(function()return source:Clone()end)
  source.Archivable=previous -- no yield occurs while this temporary flag is held
  if not ok or not copy then return end
  copy.Name="EntryAvatar";copy:SetAttribute("PortraitPose",self.poseIndex)
  local owned,joints,names={},{},{}
  for _,n in ipairs(copy:GetDescendants())do
   if n:IsA("LuaSourceContainer")or n:IsA("Animator")or n:IsA("AnimationController")or n:IsA("ProximityPrompt")or
    n:IsA("ClickDetector")or n:IsA("BillboardGui")or n:IsA("ForceField")or n:IsA("Sound")or n:IsA("ParticleEmitter")or
    n:IsA("Trail")or n:IsA("Beam")or n:IsA("Light")then n:Destroy()
   elseif n:IsA("BasePart")then
    n.Anchored=true;n.CanCollide=false;n.CanTouch=false;n.CanQuery=false;n.LocalTransparencyModifier=0;owned[n]=true
   elseif n:IsA("Humanoid")then
    n.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;n.AutoRotate=false;n.WalkSpeed=0
    n.JumpPower=0;n.JumpHeight=0;n.BreakJointsOnDeath=false
   elseif n:IsA("Constraint")then n.Enabled=false
   end
  end
  for _,n in ipairs(copy:GetDescendants())do
   local j=jointRecord(n,owned)
   if j then joints[#joints+1]=j;names[n.Name]=j end
  end
  local root=copy:FindFirstChild("HumanoidRootPart")
  local pelvis=copy:FindFirstChild("LowerTorso")or copy:FindFirstChild("Torso")
  if not root or not pelvis then copy:Destroy();return end
  clear();self.model=copy;self.root=root;self.joints=joints;self.pose={};self.names=names
  self.rootFrame=anchor.CFrame*CFrame.new(0,pelvis.Size.Y*.5,0)
  solve()
  self.rootFrame=self.rootFrame+Vector3.new(0,anchor.Position.Y+pelvis.Size.Y*.5-pelvis.Position.Y,0)
  local function pose(j,v)angle(j,math.rad(v[1]),math.rad(v[2]or 0),math.rad(v[3]or 0))end
  pose(names.Waist,portraitPose.waist);pose(names.Neck,portraitPose.neck)
  pose(names.LeftShoulder or names["Left Shoulder"],portraitPose.left)
  pose(names.RightShoulder or names["Right Shoulder"],portraitPose.right)
  angle(names.LeftElbow,math.rad(portraitPose.elbows[1]));angle(names.RightElbow,math.rad(portraitPose.elbows[2]))
  angle(names.LeftWrist,math.rad(-16));angle(names.RightWrist,math.rad(-13))
  local floor=anchor:GetAttribute("FloorY")or anchor.Position.Y-1.7
  -- Seat height must support the posed thighs, not just the upright pelvis.
  local bent={}
  for _,side in ipairs({"Left","Right"})do
   local hip=names[side.."Hip"]or names[side.." Hip"]
   local knee=names[side.."Knee"]
   local foot=copy:FindFirstChild(side.."Foot")or copy:FindFirstChild(side.." Leg")
   if hip and knee and foot then
    angle(hip,math.rad(88));angle(knee,math.rad(-88));bent[side]={knee=knee,ankle=names[side.."Ankle"],foot=foot}
   elseif hip and foot then
    -- R6 has one rigid leg instead of a thigh/knee/shin chain.
    local lo,hi=0,math.rad(105)
    for _=1,15 do
     local value=(lo+hi)*.5;angle(hip,value);angle(knee,-value);solve()
     if lowerEdge(foot)<floor then lo=value else hi=value end
    end
    local value=(lo+hi)*.5;angle(hip,value);angle(knee,-value)
   end
  end
  solve()
  local contact=lowerEdge(pelvis)
  for side in pairs(bent)do local thigh=copy:FindFirstChild(side.."UpperLeg");if thigh then contact=math.min(contact,lowerEdge(thigh))end end
  self.rootFrame=self.rootFrame+Vector3.new(0,math.max(0,anchor.Position.Y+.025-contact),0)
  solve()
  for _,leg in pairs(bent)do
   if lowerEdge(leg.foot)<floor then
    -- Long legs fold back under the knee instead of extending into the coffee table.
    -- Counter-rotate the ankle so the sole remains flat on its support.
    local lo,hi=0,math.rad(80)
    for _=1,15 do
     local value=(lo+hi)*.5;angle(leg.knee,math.rad(-88)-value);angle(leg.ankle,value);solve()
     if lowerEdge(leg.foot)<floor then lo=value else hi=value end
    end
    local value=(lo+hi)*.5;angle(leg.knee,math.rad(-88)-value);angle(leg.ankle,value)
   end
  end
  solve()
  local minX,minZ,maxX,maxZ,sole=math.huge,math.huge,-math.huge,-math.huge,math.huge
  for _,leg in pairs(bent)do
   sole=math.min(sole,lowerEdge(leg.foot))
   for _,x in ipairs({-1,1})do for _,z in ipairs({-1,1})do
    local point=leg.foot.CFrame:PointToWorldSpace(Vector3.new(x*leg.foot.Size.X*.5,0,z*leg.foot.Size.Z*.5))
    minX=math.min(minX,point.X);maxX=math.max(maxX,point.X);minZ=math.min(minZ,point.Z);maxZ=math.max(maxZ,point.Z)
   end end
  end
  -- A small, visible upholstered rest supports shorter avatars without burying their bodies.
  if sole<math.huge and sole-floor>.04 then
   local rest=Instance.new("Part");rest.Name="PortraitFootrest"
   rest.Size=Vector3.new(maxX-minX+.22,sole-floor,maxZ-minZ+.22)
   rest.CFrame=CFrame.new((minX+maxX)*.5,floor+rest.Size.Y*.5,(minZ+maxZ)*.5)
   rest.Material=Enum.Material.Leather;rest.MaterialVariant="ClubLeather";rest.Color=Color3.fromRGB(46,43,36)
   rest.Anchored=true;rest.CanCollide=false;rest.CanTouch=false;rest.CanQuery=false;rest.Parent=set;self.footrest=rest
  end
  root:SetAttribute("ClubCharacterFX",true);copy.Parent=set
 end
 local pending=false
 local function refresh()
  if pending or not self.alive then return end;pending=true
  context.delay(.15,function()pending=false;if self.alive then rebuild()end end)
 end
 local function watch(character)
  if self.appearance then self.appearance:Disconnect();self.appearance=nil end
  if character then self.appearance=character.DescendantAdded:Connect(function(n)
   if n:IsA("Accessory")or n:IsA("Shirt")or n:IsA("Pants")or n.Name=="HumanoidRootPart"then refresh()end
  end)end
  rebuild()
 end
 if self.alive then
  self.connections[#self.connections+1]=player.CharacterAdded:Connect(watch)
  self.connections[#self.connections+1]=player.CharacterAppearanceLoaded:Connect(refresh)
  self.connections[#self.connections+1]=set.Destroying:Connect(function()self:destroy()end)
  self.connections[#self.connections+1]=context.run.RenderStepped:Connect(function(dt)
   if not self.alive or not self.model then return end
   self.time+=math.min(dt,.1)
   local breath=player:GetAttribute("SpyReducedMotion")==true and 0 or math.sin(self.time*1.45)*.005
   local w=portraitPose.waist
   angle(self.names.Waist,math.rad(w[1])+breath,math.rad(w[2]),math.rad(w[3]));solve()
  end)
  watch(player.Character)
  context.delay(12,function()if self.alive and not self.model then self:destroy()end end)
 end
 return self
end
return Hero
