-- All clients animate all replicated phone holders; Transform alone is not replicated.
local Pose={}
function Pose.sample(open,elapsed,r6)
 local t=math.clamp(elapsed/(open and .68 or .42),0,1);local smooth=t*t*(3-2*t)
 local lift=open and smooth or 1-smooth
 local reach=open and math.sin(math.pi*t)*.38 or 0
 return{shoulder=(r6 and 1.06 or .72)*lift-.25*reach,roll=-.20*lift,elbow=1.02*lift,wrist=.06*lift,neck=-.10*lift,alpha=lift}
end
function Pose.grip(hand,head,torso,joint,flash)
 if not(head and torso)then return CFrame.new()end
 local position=hand.CFrame:PointToWorldSpace(joint.C0.Position)
 local direction=flash and -torso.CFrame.LookVector or head.Position-position
 if direction.Magnitude<.01 then return CFrame.new()end
 local up=torso.CFrame.UpVector
 if math.abs(direction.Unit:Dot(up))>.98 then up=torso.CFrame.LookVector end
 local world=CFrame.lookAt(position,position+direction,up)
 return joint.C0.Rotation:Inverse()*hand.CFrame.Rotation:Inverse()*world.Rotation
end
function Pose.gaze(character,alpha)
 local head=character:FindFirstChild('Head');local torso=character:FindFirstChild('UpperTorso')or character:FindFirstChild('Torso')
 local phone=character:FindFirstChild('SpyPhone');local screen=phone and phone:FindFirstChild('Screen')
 local weight=math.clamp(alpha or 0,0,1)
 if not(head and head:IsA('BasePart')and torso and torso:IsA('BasePart')and screen and screen:IsA('BasePart'))then return -.24*weight,0 end
 local direction=torso.CFrame:VectorToObjectSpace(screen.Position-head.Position)
 local horizontal=math.sqrt(direction.X*direction.X+direction.Z*direction.Z)
 local pitch=math.clamp(math.atan2(direction.Y,horizontal),-.62,.12)
 local yaw=math.clamp(math.atan2(-direction.X,-direction.Z),-.32,.32)
 return pitch*weight,yaw*weight
end
function Pose.start()
 local Players=game:GetService('Players');local Run=game:GetService('RunService');local rigs,watches={},{}
 local function clear(r)
  for j,v in pairs(r.applied)do if j.Parent then j.Transform=j.Transform==v.pose and v.base or v.delta:Inverse()*j.Transform end end
  table.clear(r.applied)
 end
 local function remove(c)local r=rigs[c];if r then clear(r);rigs[c]=nil end end
 local function add(p,c)
  local r={player=p,character=c,applied={}};rigs[c]=r
 end
 local function watch(p)
  watches[p]={p.CharacterAdded:Connect(function(c)add(p,c)end),p.CharacterRemoving:Connect(remove)}
  if p.Character then add(p,p.Character)end
 end
 for _,p in ipairs(Players:GetPlayers())do watch(p)end
 local joined=Players.PlayerAdded:Connect(watch)
 local left=Players.PlayerRemoving:Connect(function(p)for _,c in ipairs(watches[p]or{})do c:Disconnect()end;watches[p]=nil;for char,r in pairs(rigs)do if r.player==p then remove(char)end end end)
 local before=Run.PreAnimation:Connect(function()for _,r in pairs(rigs)do clear(r)end end)
 local step=Run.PreSimulation:Connect(function(dt)
  local now=workspace:GetServerTimeNow()
  for c,r in pairs(rigs)do
   local at=c:GetAttribute('SpyPhoneAt');local active=c:GetAttribute('SpyPhoneActive')==true
   if c.Parent and at and(active or now-at<.43)then
    local h=c:FindFirstChildOfClass('Humanoid');local q=Pose.sample(active,math.max(0,now-at),h and h.RigType==Enum.HumanoidRigType.R6)
    local target=c:GetAttribute('SpyPhoneFlash')==true and 1 or 0;r.mode=(r.mode or 0)+(target-(r.mode or 0))*(1-math.exp(-math.min(dt or 1/60,.1)*10))
    local mode=r.mode;local pitch,yaw=Pose.gaze(c,q.alpha*(1-mode))
    local shoulder=q.shoulder+mode*(.24*q.alpha);local elbow=q.elbow-mode*(.28*q.alpha)
    local joints={RightShoulder={shoulder,0,q.roll},['Right Shoulder']={shoulder,0,q.roll},RightElbow={elbow,0,0},RightWrist={q.wrist,0,0},Neck={pitch,yaw,0},LeftShoulder={.16*q.alpha,0,.03*q.alpha},['Left Shoulder']={.16*q.alpha,0,.03*q.alpha},LeftElbow={.18*q.alpha,0,0},LeftWrist={0,0,0}}
    for _,j in ipairs(c:GetDescendants())do
     local angles=joints[j.Name]
     if angles and(j:IsA('Motor6D')or j:IsA('AnimationConstraint')and j.IsKinematic)then
      local base=j.Transform;local a=CFrame.Angles(table.unpack(angles))
      -- Motor axes vary between R6 and R15; express our pose in the parent frame.
      if j:IsA('Motor6D')then a=j.C0.Rotation:Inverse()*a*j.C0.Rotation end
      local target=j.Name=='Neck'and(base*a)or a
      local value=base:Lerp(target,q.alpha);j.Transform=value;r.applied[j]={base=base,pose=value,delta=value*base:Inverse()}
     end
    end
    local phone=c:FindFirstChild('SpyPhone');local grip=phone and phone:FindFirstChild('PhoneGrip',true)
    local torso=c:FindFirstChild('UpperTorso')or c:FindFirstChild('Torso');local head=c:FindFirstChild('Head')
    if grip and grip.Part0 then
     local base=grip.Transform;local read=Pose.grip(grip.Part0,head,torso,grip,false);local torch=Pose.grip(grip.Part0,head,torso,grip,true)
     local value=base:Lerp(read:Lerp(torch,mode),q.alpha);grip.Transform=value;r.applied[grip]={base=base,pose=value,delta=value*base:Inverse()}
    end
   end
  end
 end)
 return{destroy=function()
  before:Disconnect();step:Disconnect();joined:Disconnect();left:Disconnect()
  for _,r in pairs(rigs)do clear(r)end
  for _,list in pairs(watches)do for _,c in ipairs(list)do c:Disconnect()end end
 end}
end
return Pose
