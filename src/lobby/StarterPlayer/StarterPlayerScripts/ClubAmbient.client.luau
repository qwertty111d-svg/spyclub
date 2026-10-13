-- Continuous local atmosphere. A bounded number of volumes, no blur and no movement gate.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local player=Players.LocalPlayer
local records={}
local candidates=setmetatable({}, {__mode="k"})
local sceneCount,characterCount,barCount=0,0,0
local lamps={Aisle2Lens=true,Aisle3Lens=true,Bar2Lens=true,LoungeLampBulb=true,CeilingDiffuser=true,LampDiffuser=true}
local function allowed()return player:GetAttribute("SpyEffects")~=false and player:GetAttribute("SpyReducedMotion")~=true end
local function priority(owner)
 if owner:GetAttribute("ClubCharacterFX")==true or(owner.Parent and owner.Parent.Name=="EntryAvatar")then return 3 end
 if owner.Parent==player.Character then return 2 end
 return 0
end
local function distance(owner)
 local camera=workspace.CurrentCamera
 return camera and(owner.Position-camera.CFrame.Position).Magnitude or 0
end
local function remove(owner)
 local r=records[owner];if not r then return end
 if r.connection then r.connection:Disconnect()end
 for _,n in ipairs(r.objects)do n:Destroy()end
 if r.kind=="scene"then sceneCount-=1 elseif r.kind=="bar"then barCount-=1 else characterCount-=1 end
 records[owner]=nil
end
local function configure(e,character)
 e.Texture="rbxasset://textures/particles/smoke_main.dds";e.Color=ColorSequence.new(Color3.fromRGB(244,217,171))
 e.LightInfluence=.25;e.LightEmission=character and .65 or .35;e.Drag=.4
 e.Lifetime=character and NumberRange.new(1.8,3)or NumberRange.new(3.5,5.5)
 e.Rate=(character and 2.5 or 7)*(Input.TouchEnabled and .3 or 1)
 e.Speed=character and NumberRange.new(.10,.32)or NumberRange.new(.06,.18)
 e.SpreadAngle=Vector2.new(180,180);e.Acceleration=Vector3.new(.015,.015,.008)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.025),NumberSequenceKeypoint.new(.3,character and .085 or .07),NumberSequenceKeypoint.new(1,.025)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.42),NumberSequenceKeypoint.new(.75,.55),NumberSequenceKeypoint.new(1,1)})
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-12,12);e.Enabled=allowed()
end
local function add(owner)
 if not owner:IsA("BasePart")or records[owner]then return end
 local character=owner.Name=="HumanoidRootPart"and owner.Parent and owner.Parent:FindFirstChildOfClass("Humanoid")
 if character then candidates[owner]=true end
 local bar=owner.Name=="ShelfLight7.0"and owner:IsDescendantOf(workspace)
 local scene=lamps[owner.Name]and owner:IsDescendantOf(workspace)
 if not character and not scene and not bar then return end
 if bar and barCount>=1 then return end
 if scene and sceneCount>=(Input.TouchEnabled and 4 or 7) then return end
 if character and characterCount>=(Input.TouchEnabled and 3 or 6) then
  local candidate,worstPriority,worstDistance=nil,math.huge,-1
  for p,r in pairs(records)do if r.kind=="character"then
   local rank,d=priority(p),distance(p)
   if rank<worstPriority or(rank==worstPriority and d>worstDistance)then candidate=p;worstPriority=rank;worstDistance=d end
  end end
  local rank=priority(owner)
  if not candidate or rank<worstPriority or(rank==worstPriority and distance(owner)>=worstDistance)then return end
  remove(candidate)
 end
 local r={objects={},kind=character and "character"or(bar and "bar"or "scene")};records[owner]=r
 local emitter=Instance.new("ParticleEmitter");emitter.Name=character and "ClubPresenceMotes"or "Motes";configure(emitter,character)
 if character then
  characterCount+=1
  local a=Instance.new("Attachment");a.Name="ClubPresence";a.Position=Vector3.new(0,.5,.45);a.Parent=owner
  emitter.Parent=a;r.objects={a}
 elseif bar then
  barCount+=1
  local volume=Instance.new("Part");volume.Name="ClubBarHaze";volume.Size=Vector3.new(10,.8,1.4);volume.CFrame=owner.CFrame*CFrame.new(0,-.18,-.35)
  volume.Anchored=true;volume.CanCollide=false;volume.CanTouch=false;volume.CanQuery=false;volume.CastShadow=false;volume.Transparency=1;volume.Parent=owner
  emitter.Shape=Enum.ParticleEmitterShape.Box;emitter.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
  emitter.Rate=Input.TouchEnabled and .45 or .9;emitter.Lifetime=NumberRange.new(2.2,3.2);emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(1,1.2)})
  emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.93),NumberSequenceKeypoint.new(1,1)});emitter.LightEmission=.05;emitter.Speed=NumberRange.new(.06,.12);emitter.Parent=volume;r.objects={volume}
 else
  sceneCount+=1
  local low=owner.Name=="LoungeLampBulb"or owner.Name=="LampDiffuser"
  local entrance=owner.Name=="CeilingDiffuser"
  local volume=Instance.new("Part");volume.Name="ClubBeamMotes"
  volume.Size=low and Vector3.new(3,2.2,3)or Vector3.new(6,entrance and 6 or 9,6)
  volume.CFrame=owner.CFrame*CFrame.new(0,low and -1.4 or(entrance and -6.8 or -8.5),0)
  volume.Anchored=true;volume.CanCollide=false;volume.CanTouch=false;volume.CanQuery=false;volume.CastShadow=false;volume.Transparency=1;volume.Parent=owner
  emitter.Shape=Enum.ParticleEmitterShape.Box;emitter.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume;emitter.EmissionDirection=Enum.NormalId.Bottom
  emitter.Parent=volume;r.objects={volume}
  if not low then
   local top=Instance.new("Attachment");top.Name="ClubRayStart";top.Position=Vector3.new(0,-.05,0);top.Parent=owner
   local bottom=Instance.new("Attachment");bottom.Name="ClubRayEnd";bottom.Position=Vector3.new(0,entrance and -9 or -12,0);bottom.Parent=owner
   local beam=Instance.new("Beam");beam.Name="ClubLampRay";beam.Attachment0=top;beam.Attachment1=bottom
   beam.Width0=.18;beam.Width1=1.2;beam.Segments=8;beam.FaceCamera=true;beam.LightEmission=.35;beam.LightInfluence=.4
   beam.Color=ColorSequence.new(Color3.fromRGB(240,218,180));beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.992),NumberSequenceKeypoint.new(1,1)})
   beam.Enabled=allowed();beam.Parent=top;r.beam=beam;r.objects[#r.objects+1]=top;r.objects[#r.objects+1]=bottom
  end
 end
 r.emitter=emitter;r.connection=owner.Destroying:Connect(function()remove(owner)end)
 if allowed()then emitter:Emit(character and 3 or(Input.TouchEnabled and 4 or 20))end
end
local function refresh()
 local camera=workspace.CurrentCamera
 local stale={}
 for owner,r in pairs(records)do
  if not owner.Parent or not owner:IsDescendantOf(workspace)then stale[#stale+1]=owner
  else
   local near=not camera or(owner.Position-camera.CFrame.Position).Magnitude<(r.kind=="character"and 38 or 65)
   local value=allowed()and near;r.emitter.Enabled=value
   if not value then r.emitter:Clear()end
   if r.beam then r.beam.Enabled=value end
  end
 end
 for _,owner in ipairs(stale)do remove(owner)end
end
for _,p in ipairs(workspace:GetDescendants())do add(p)end
local added=workspace.DescendantAdded:Connect(function(owner)
 if owner:IsA("Humanoid")then
  local root=owner.Parent and owner.Parent:FindFirstChild("HumanoidRootPart")
  if root then add(root)end
 else add(owner)end
end)
local first=player:GetAttributeChangedSignal("SpyEffects"):Connect(refresh)
local second=player:GetAttributeChangedSignal("SpyReducedMotion"):Connect(refresh)
local elapsed,refill=0,0
local tick=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;refill+=dt;if elapsed<.5 then return end;elapsed=0;refresh()
 -- Streaming adds candidates by event; refilling never scans the whole scene.
 if refill>=3 then
  refill=0
  for owner in pairs(candidates)do
   if owner.Parent and owner:IsDescendantOf(workspace)then add(owner)else candidates[owner]=nil end
  end
 end
end)
refresh()
script.Destroying:Connect(function()
 added:Disconnect();first:Disconnect();second:Disconnect();tick:Disconnect()
 local owners={};for p in pairs(records)do owners[#owners+1]=p end;for _,p in ipairs(owners)do remove(p)end
end)
