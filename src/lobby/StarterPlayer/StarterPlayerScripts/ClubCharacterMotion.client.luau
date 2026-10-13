-- Additive presentation only. Humanoid/PlayerModule remain the movement authority.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Storage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Content=game:GetService("ContentProvider")
local localPlayer=Players.LocalPlayer
local shared=Storage:WaitForChild("SpyShared",8)
local module=shared and shared:WaitForChild("ClubMotion",4)
if not module then return end
local Motion=require(module)
local gaitModule=shared:FindFirstChild("ClubGait")
local Gait=gaitModule and require(gaitModule)
local requested=Storage:GetAttribute("SpyClubWalkAnimationId")
local walkId=type(requested)=="number"and requested>0 and requested<9007199254740992 and requested%1==0 and requested or 2510202577
-- Actual animation-clip IDs from Roblox's official animation reference, not catalog bundle IDs.
-- Rthro neutral is the verified fallback for the requested reference; walk and run are distinct.
-- This is our interpretation of the requested slow reference, not a private Gokuran asset.
local clips={idle={2510197257,2510196951},walk={walkId},run={2510198475},jump={2510197830},fall={2510195892}}
local rigs,players={},{}
local available,animations={},{}
local preloadClosed=false
local preloadObjects={}
local phaseConnection,simulationConnection,cameraConnection
local function clearOffset(rig)
 for joint,value in pairs(rig.offsets)do
  if joint.Parent and joint.Transform==value.applied then joint.Transform=value.base end
 end
 table.clear(rig.offsets)
end
local function remove(character)
 local rig=rigs[character];if not rig then return end
 clearOffset(rig)
 for _,c in ipairs(rig.connections)do c:Disconnect()end
 if rig.cameraApplied and rig.humanoid and rig.humanoid.Parent and rig.humanoid.CameraOffset==rig.cameraApplied then rig.humanoid.CameraOffset=rig.cameraBase end
 if rig.dustAttachment then rig.dustAttachment:Destroy()end
 if rig.gait then rig.gait:destroy();rig.gait=nil end
 for n,value in pairs(animations)do if value.rig==rig then
  if n.Parent and value.selected and n.AnimationId==value.selected then n.AnimationId=value.original end
  animations[n]=nil
 end end
 rigs[character]=nil
end
local function patchAnimation(rig,n)
 if rig.player~=localPlayer or not rig.humanoid or not n:IsA("Animation") or rig.humanoid.RigType==Enum.HumanoidRigType.R6 or n.AnimationId=="" then return end
 local animate=rig.character:FindFirstChild("Animate")
 if not animate or not n:IsDescendantOf(animate)then return end
 local parent=n.Parent;local ids=parent and clips[parent.Name]
 if parent and rig.failedStates[parent.Name]then return end
 if not ids then return end
 local index=n.Name=="Animation2"and 2 or 1
 local id=ids[index]or ids[1]
 local value=animations[n]
 if not value then value={rig=rig,original=n.AnimationId};animations[n]=value end
 if available[id]==true then
  local target="rbxassetid://"..tostring(id)
  if n.AnimationId~=target then value.original=n.AnimationId;value.selected=target;n.AnimationId=target end
 end
end
-- Optional clips have their own deadline. A denied or unavailable asset keeps the working native clip.
local function closePreload()
 if preloadClosed then return end;preloadClosed=true
 local missing={}
 for state,ids in pairs(clips)do if available[ids[1]]~=true then missing[#missing+1]=state end end
 table.sort(missing)
 local status=#missing==0 and "Rthro neutral"or("native fallback: "..table.concat(missing,", "))
 local current=localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
 if current and current.RigType==Enum.HumanoidRigType.R6 then status="R6 native clips + procedural motion"end
 localPlayer:SetAttribute("SpyAnimationStatus",status)
 if #missing>0 then warn("[ClubAnimations] "..status.."; check animation permissions/assets in published Play")end
 for _,object in ipairs(preloadObjects)do object:Destroy()end
 table.clear(preloadObjects)
end
task.delay(6,closePreload)
task.spawn(function()
 if preloadClosed then return end
 for _,ids in pairs(clips)do for _,id in ipairs(ids)do
  local animation=Instance.new("Animation");animation.AnimationId="rbxassetid://"..tostring(id);preloadObjects[#preloadObjects+1]=animation
 end end
 pcall(function()Content:PreloadAsync(preloadObjects,function(uri,status)
  if preloadClosed then return end
  local id=tonumber(tostring(uri):match("id=(%d+)")or tostring(uri):match("(%d+)$"))
  if id then available[id]=status==Enum.AssetFetchStatus.Success end
  for n,value in pairs(animations)do if n.Parent then patchAnimation(value.rig,n)end end
 end)end)
 closePreload()
end)
local function add(player,character)
 if rigs[character]then return end
 local rig={player=player,character=character,motion=Motion.new(),joints={},offsets={},connections={},lastLook=nil,time=0,failedStates={}}
 rigs[character]=rig
 local function discover(n)
  if n:IsA("Humanoid")then
   rig.humanoid=n
   if player==localPlayer and n.RigType==Enum.HumanoidRigType.R6 then localPlayer:SetAttribute("SpyAnimationStatus","R6 native clips + procedural motion");warn("[ClubAnimations] R6: Rthro neutral clips require R15; keeping compatible native clips")end
   task.defer(function()if character.Parent then for _,a in ipairs(character:GetDescendants())do if a:IsA("Animation")then patchAnimation(rig,a)end end end end)
  elseif n:IsA("BasePart")and n.Name=="HumanoidRootPart"then rig.root=n
  elseif n:IsA("Motor6D")or n:IsA("AnimationConstraint")then rig.joints[n.Name]=n
  elseif n:IsA("Animation")then
   patchAnimation(rig,n)
   rig.connections[#rig.connections+1]=n:GetPropertyChangedSignal("AnimationId"):Connect(function()patchAnimation(rig,n)end)
  end
 end
 for _,n in ipairs(character:GetDescendants())do discover(n)end
 rig.connections[#rig.connections+1]=character.DescendantAdded:Connect(discover)
 rig.connections[#rig.connections+1]=character.Destroying:Connect(function()remove(character)end)
end
local function watch(player)
 if players[player]then return end
 players[player]={player.CharacterAdded:Connect(function(c)add(player,c)end),player.CharacterRemoving:Connect(remove)}
 if player.Character then add(player,player.Character)end
end
local function dust(rig)
 if rig.player~=localPlayer or localPlayer:GetAttribute("SpyEffects")==false or localPlayer:GetAttribute("SpyReducedMotion")==true then return end
 local foot=rig.character:FindFirstChild(rig.motion.steps%2==0 and "LeftFoot"or "RightFoot")or
  rig.character:FindFirstChild(rig.motion.steps%2==0 and "Left Leg"or "Right Leg")
 if not foot or not rig.root then return end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={rig.character}
 local hit=workspace:Raycast(foot.Position+Vector3.new(0,.3,0),Vector3.new(0,-1.3,0),params)
 if not hit or hit.Material==Enum.Material.Water then return end
 if not rig.dustAttachment then
  local a=Instance.new("Attachment");a.Name="ClubStepDust";a.Parent=rig.root
  local e=Instance.new("ParticleEmitter");e.Name="SoleDust";e.Texture="rbxasset://textures/particles/smoke_main.dds"
  e.Rate=0;e.Lifetime=NumberRange.new(.18,.32);e.Speed=NumberRange.new(.15,.35);e.Drag=4;e.SpreadAngle=Vector2.new(45,45)
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.09),NumberSequenceKeypoint.new(1,.22)})
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.88),NumberSequenceKeypoint.new(1,1)})
  e.Color=ColorSequence.new(Color3.fromRGB(177,163,140));e.LightInfluence=1;e.LightEmission=0;e.Parent=a
  rig.dustAttachment=a;rig.dust=e
 end
 rig.dustAttachment.Position=rig.root.CFrame:PointToObjectSpace(hit.Position+Vector3.new(0,.035,0))
 rig.dust:Emit(hit.Material==Enum.Material.Carpet and 1 or 2)
end
local function pose(rig,jointName,cf)
 local joint=rig.joints[jointName];if not joint or not joint.Parent then return end
 if joint:IsA("AnimationConstraint")and not joint.IsKinematic then return end
 local base=joint.Transform;local applied=base*cf;joint.Transform=applied;rig.offsets[joint]={base=base,applied=applied}
end
local function walk(rig,speed,enabled)
 if rig.player~=localPlayer or rig.humanoid.RigType==Enum.HumanoidRigType.R6 or not Gait then return end
 if not rig.gait then
  local animator=rig.humanoid:FindFirstChildOfClass("Animator")
  if animator then
   local ids={};for state,values in pairs(clips)do if available[values[1]]==true then ids[state]=values[1]end end
   -- Wait for completed verification without holding character movement or boot.
   if next(ids)==nil then return end
   rig.gaitIds=ids;rig.gait=Gait.create(animator,ids,task.delay,function(state,reason)
    if rigs[rig.character]~=rig then return end
    rig.failedStates[state]=true;rig.gaitIds[state]=nil
    for n,value in pairs(animations)do
     if value.rig==rig and n.Parent and n.Parent.Name==state and value.selected and n.AnimationId==value.selected then
      value.selected=nil;n.AnimationId=value.original
     end
    end
    local status="native fallback: "..state.." ("..reason..")";localPlayer:SetAttribute("SpyAnimationStatus",status);warn("[ClubAnimations] "..status)
   end)
  end
 end
 if rig.gait then
  for state,values in pairs(clips)do if available[values[1]]==true and not rig.failedStates[state]then rig.gaitIds[state]=values[1]else rig.gaitIds[state]=nil end end
  rig.gait:step(speed,rig.humanoid:GetState(),rig.humanoid.FloorMaterial~=Enum.Material.Air,enabled)
 end
end
phaseConnection=Run.PreAnimation:Connect(function()for _,rig in pairs(rigs)do clearOffset(rig)end end)
simulationConnection=Run.PreSimulation:Connect(function(dt)
 for character,rig in pairs(rigs)do
  local h,root=rig.humanoid,rig.root
  if character.Parent and h and root and root.Parent then
   local state=h:GetState();local velocity=root.AssemblyLinearVelocity;local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
   local localVelocity=root.CFrame:VectorToObjectSpace(velocity)
   local grounded=h.FloorMaterial~=Enum.Material.Air
   local enabled=h.Health>0 and not h.Sit and state~=Enum.HumanoidStateType.Climbing and state~=Enum.HumanoidStateType.Swimming and state~=Enum.HumanoidStateType.PlatformStanding
   if rig.player==localPlayer and (localPlayer:GetAttribute("SpyEntryActive")==true or localPlayer:GetAttribute("SpyEntryPending")==true or localPlayer:GetAttribute("SpyCaseCinematicActive")==true)then enabled=false end
   walk(rig,speed,enabled)
   local look=root.CFrame.LookVector;local turn=0
   if rig.lastLook and dt>.001 then
    local cross=rig.lastLook.X*look.Z-rig.lastLook.Z*look.X
    local dot=rig.lastLook.X*look.X+rig.lastLook.Z*look.Z
    turn=math.atan2(cross,dot)/dt
   end
   rig.lastLook=look;rig.time+=math.min(dt,.1)
   if Motion.step(rig.motion,{speed=speed,side=localVelocity.X,forward=-localVelocity.Z,turn=turn,grounded=grounded,vertical=velocity.Y,enabled=enabled},dt)then dust(rig)end
   local m=rig.motion
   -- Reduced motion restores the animated pose; it also suppresses bob and impact layers.
   if localPlayer:GetAttribute("SpyReducedMotion")~=true and enabled and rig.player:GetAttribute("SpyPhoneActive")~=true then
   local breathing=math.sin(rig.time*1.45)*.003
    pose(rig,rig.joints.Waist and "Waist"or "RootJoint",CFrame.new(0,-m.landing*.045,0)*CFrame.Angles(m.pitch+m.landing*.055+breathing,0,m.roll))
    pose(rig,"Neck",CFrame.Angles(-m.pitch*.28,0,-m.roll*.3))
    pose(rig,"LeftKnee",CFrame.Angles(-m.landing*.12,0,0));pose(rig,"RightKnee",CFrame.Angles(-m.landing*.12,0,0))
   end
  end
 end
end)
cameraConnection=Run.RenderStepped:Connect(function(dt)
 local rig=localPlayer.Character and rigs[localPlayer.Character];local cam=workspace.CurrentCamera
 if not rig or not rig.humanoid or not rig.root or not cam then return end
 local h=rig.humanoid;local current=h.CameraOffset
 if not rig.cameraApplied or current~=rig.cameraApplied then rig.cameraBase=current end
 local active=cam.CameraType==Enum.CameraType.Custom and cam.CameraSubject==h and not h.Sit and h.Health>0 and
  localPlayer:GetAttribute("SpyEntryActive")~=true and localPlayer:GetAttribute("SpyEntryPending")~=true and localPlayer:GetAttribute("SpyCaseCinematicActive")~=true and
  localPlayer:GetAttribute("SpyReducedMotion")~=true and localPlayer:GetAttribute("SpyCameraMotion")~=false and not Input.VREnabled
 local head=rig.character:FindFirstChild("Head")or rig.root
 local distance=(cam.CFrame.Position-head.Position).Magnitude
 local m=rig.motion;local weight=active and distance>1.1 and math.clamp(m.speed/11,0,1)or 0
 local amplitude=Input.TouchEnabled and .012 or .020
 local goal=Vector3.new(math.sin(m.phase)*amplitude*weight,math.sin(m.phase*2)*amplitude*.6*weight-(active and m.landing*.06 or 0),0)
 rig.bob=(rig.bob or Vector3.zero):Lerp(goal,1-math.exp(-15*math.min(dt,.1)))
 rig.cameraApplied=rig.cameraBase+rig.bob;h.CameraOffset=rig.cameraApplied
end)
for _,p in ipairs(Players:GetPlayers())do watch(p)end
local joined=Players.PlayerAdded:Connect(watch)
local left=Players.PlayerRemoving:Connect(function(p)
 for _,c in ipairs(players[p]or {})do c:Disconnect()end;players[p]=nil
 for character,rig in pairs(rigs)do if rig.player==p then remove(character)end end
end)
script.Destroying:Connect(function()
 closePreload()
 phaseConnection:Disconnect();simulationConnection:Disconnect();cameraConnection:Disconnect();joined:Disconnect();left:Disconnect()
 for _,connections in pairs(players)do for _,c in ipairs(connections)do c:Disconnect()end end
 local characters={};for c in pairs(rigs)do characters[#characters+1]=c end;for _,c in ipairs(characters)do remove(c)end
end)
