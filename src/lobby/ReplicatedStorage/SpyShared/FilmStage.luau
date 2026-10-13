-- Full-size locally staged action on the existing bar: actual club remains the backdrop.
local Stage={};Stage.__index=Stage
local function joint(n,owned)
 local a,b,c0,c1
 if n:IsA('Motor6D')or n:IsA('Weld')then a,b,c0,c1=n.Part0,n.Part1,n.C0,n.C1
 elseif n:IsA('AnimationConstraint')or n:IsA('RigidConstraint')then
  local aa,bb=n.Attachment0,n.Attachment1;if not aa or not bb then return end
  a=aa:FindFirstAncestorWhichIsA('BasePart');b=bb:FindFirstAncestorWhichIsA('BasePart');if not a or not b then return end
  c0=a.CFrame:ToObjectSpace(aa.WorldCFrame);c1=b.CFrame:ToObjectSpace(bb.WorldCFrame)
 elseif n:IsA('WeldConstraint')then a,b=n.Part0,n.Part1;if not a or not b then return end;c0=a.CFrame:ToObjectSpace(b.CFrame);c1=CFrame.new()
 else return end
 if not owned[a]or not owned[b]then return end
 return{a=a,b=b,c0=c0,c1=c1,name=n.Name}
end
local function build(id,self)
 local club=workspace:FindFirstChild('SpyClub');local bar=club and club:FindFirstChild(id=='envelope'and'LibraryTop'or'BarTop',true)
 if not bar or not bar:IsA('BasePart')then return nil end
 local source=game:GetService('Players').LocalPlayer.Character
 local sourceRoot=source and source:FindFirstChild('HumanoidRootPart');local sourceHumanoid=source and source:FindFirstChildOfClass('Humanoid')
 if not sourceRoot or not sourceHumanoid or not(id=='call'or id=='envelope'or id=='cassette')then return nil end
 local sign=id=='call'and-1 or 1
 self.origin=id=='envelope'and Vector3.new(bar.Position.X,bar.Position.Y+bar.Size.Y*.5,bar.Position.Z)or Vector3.new(bar.Position.X+sign*math.min(8,bar.Size.X*.28),bar.Position.Y+bar.Size.Y*.5,bar.Position.Z-bar.Size.Z*.5+.9)
 self.base=CFrame.new(self.origin)*CFrame.Angles(0,id=='envelope'and-math.pi*.5 or 0,0);self.variant=Random.new():NextInteger(1,3)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 local ignore={self.root};for _,p in ipairs(game:GetService('Players'):GetPlayers())do if p.Character then ignore[#ignore+1]=p.Character end end
 params.FilterDescendantsInstances=ignore
 local ground=self.base:PointToWorldSpace(Vector3.new(0,12,-1.15))
 local ray=workspace:Raycast(ground,Vector3.new(0,-24,0),params)
 self.floorY=ray and ray.Position.Y or 0
 local function part(name,size,pos,color,mat)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=self.base*CFrame.new(pos);p.Color=color;p.Material=mat or Enum.Material.Metal;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=self.root;return p
 end
 self.part=part
 local graphite=Color3.fromRGB(37,41,40);local steel=Color3.fromRGB(124,132,124);local cream=Color3.fromRGB(195,187,157)
 -- Illuminated desk lamp: the light is physically attached to its visible shade.
 local lampZ=id=='envelope'and .1 or .5
 part('LampFoot',Vector3.new(.8,.06,.55),Vector3.new(-2,.03,lampZ),graphite)
 local stem=part('LampStem',Vector3.new(.06,1.35,.06),Vector3.new(-2,.73,lampZ),steel)
 local shade=part('LampShade',Vector3.new(.85,.24,.46),Vector3.new(-1.75,1.4,lampZ-.25),Color3.fromRGB(42,71,60))
 local light=Instance.new('SpotLight');light.Face=Enum.NormalId.Bottom;light.Brightness=1.7;light.Range=10;light.Angle=85;light.Shadows=true;light.Color=Color3.fromRGB(255,221,172);light.Parent=shade
 if id=='cassette'then
  part('RecorderChassis',Vector3.new(1.85,.26,1.3),Vector3.new(0,.13,0),graphite)
  part('RecorderPanel',Vector3.new(1.7,.025,1.15),Vector3.new(0,.275,0),steel)
  self.reels={}
  for _,x in ipairs({-.46,.46})do
   local m=Instance.new('Model');m.Name='Reel';m.Parent=self.root
   local reel=part('TapeReel',Vector3.new(.04,.64,.64),Vector3.new(x,.31,-.12),graphite);reel.Shape=Enum.PartType.Cylinder;reel.CFrame*=CFrame.Angles(0,0,math.pi*.5);reel.Parent=m;m.PrimaryPart=reel
   local hub=part('Hub',Vector3.new(.055,.13,.13),Vector3.new(x,.32,-.12),steel);hub.Shape=Enum.PartType.Cylinder;hub.CFrame*=CFrame.Angles(0,0,math.pi*.5);hub.Parent=m
   for i=1,3 do local a=i*math.pi*2/3;local p=part('Spoke',Vector3.new(.03,.02,.2),Vector3.new(x+math.sin(a)*.15,.35,-.12+math.cos(a)*.15),steel);p.CFrame*=CFrame.Angles(0,a,0);p.Parent=m end
   self.reels[#self.reels+1]={model=m,frame=m:GetPivot()}
  end
  for i=1,6 do part('TransportKey',Vector3.new(.17,.06,.17),Vector3.new(-.63+i*.2,.315,.43),i==6 and Color3.fromRGB(139,60,42)or graphite)end
  local rec=part('RecordIndicator',Vector3.new(.08,.015,.08),Vector3.new(.73,.33,.12),Color3.fromRGB(161,54,36),Enum.Material.Neon)
 elseif id=='envelope'then
  self.envelope=part('SealedEnvelope',Vector3.new(1.6,.035,.76),Vector3.new(0,.023,0),Color3.fromRGB(47,68,87),Enum.Material.Fabric)
  self.envelopeFrame=self.envelope.CFrame
  self.seal=part('WaxSeal',Vector3.new(.028,.25,.25),Vector3.new(0,.06,0),Color3.fromRGB(111,48,40));self.seal.Shape=Enum.PartType.Cylinder;self.seal.CFrame*=CFrame.Angles(0,0,math.pi*.5)
  part('Manifest',Vector3.new(.65,.017,.62),Vector3.new(1.2,.012,0),cream,Enum.Material.SmoothPlastic)
 else
  part('TelephoneBase',Vector3.new(1.45,.26,1.1),Vector3.new(0,.13,0),graphite)
  local dial=part('RotaryDial',Vector3.new(.035,.62,.62),Vector3.new(0,.28,.17),steel);dial.Shape=Enum.PartType.Cylinder;dial.CFrame*=CFrame.Angles(0,0,math.pi*.5)
  for i=1,10 do local a=i*math.pi*2/10;local p=part('DialHole',Vector3.new(.04,.082,.082),Vector3.new(math.sin(a)*.22,.305,.17+math.cos(a)*.22),graphite);p.Shape=Enum.PartType.Cylinder;p.CFrame*=CFrame.Angles(0,0,math.pi*.5)end
  self.handset=Instance.new('Model');self.handset.Name='Handset';self.handset.Parent=self.root
  local bridge=part('Grip',Vector3.new(1.1,.1,.17),Vector3.new(0,.48,-.33),graphite);bridge.Parent=self.handset;self.handset.PrimaryPart=bridge
  for _,x in ipairs({-.56,.56})do local p=part('Receiver',Vector3.new(.3,.2,.36),Vector3.new(x,.47,-.33),graphite);p.Parent=self.handset end
  self.handsetFrame=self.handset:GetPivot()
  local a=Instance.new('Attachment');a.Position=Vector3.new(.55,0,0);a.Parent=bridge
  local fixed=part('CordSocket',Vector3.new(.05,.05,.05),Vector3.new(.68,.13,-.32),graphite);local b=Instance.new('Attachment');b.Parent=fixed
  local cord=Instance.new('Beam');cord.Attachment0=a;cord.Attachment1=b;cord.Width0=.035;cord.Width1=.035;cord.Segments=16;cord.CurveSize0=.4;cord.CurveSize1=.3;cord.Color=ColorSequence.new(graphite);cord.FaceCamera=true;cord.Parent=bridge
 end
 local player=game:GetService('Players').LocalPlayer;local char=player.Character
 if char then
  local old=char.Archivable;char.Archivable=true;local ok,copy=pcall(function()return char:Clone()end);char.Archivable=old
  if ok and copy then
   local phone=copy:FindFirstChild('SpyPhone');if phone then phone:Destroy()end
   local owned={};for _,n in ipairs(copy:GetDescendants())do
    if n:IsA('LuaSourceContainer')or n:IsA('Animator')or n:IsA('ProximityPrompt')or n:IsA('BillboardGui')or n:IsA('Sound')or n:IsA('Light')or n:IsA('ParticleEmitter')or n:IsA('Trail')then n:Destroy()
    elseif n:IsA('BasePart')then n.Anchored=true;n.CanCollide=false;n.CanTouch=false;n.CanQuery=false;n.LocalTransparencyModifier=0;owned[n]=true
    elseif n:IsA('Humanoid')then n.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;n.AutoRotate=false;n.BreakJointsOnDeath=false
    elseif n:IsA('Constraint')then n.Enabled=false end
   end
   for _,n in ipairs(copy:GetDescendants())do local j=joint(n,owned);if j then self.joints[#self.joints+1]=j end end
   self.actorRoot=copy:FindFirstChild('HumanoidRootPart');self.actor=copy;copy.Name='CaseOperative';copy.Parent=self.root
   local h=copy:FindFirstChildOfClass('Humanoid');if not self.actorRoot or not h then copy:Destroy();return nil end
   local leg=copy:FindFirstChild('Left Leg')
   self.rootY=self.floorY+h.HipHeight+self.actorRoot.Size.Y*.5+(h.RigType==Enum.HumanoidRigType.R6 and leg and leg.Size.Y or 0)
   self.names={};for _,j in ipairs(self.joints)do self.names[j.name]=j end
  end
 end
 if not self.actorRoot then return nil end
 self.root.Parent=workspace;return self
end
function Stage.new(id)
 local self=setmetatable({id=id,parts={},joints={}},Stage)
 self.root=Instance.new('Model');self.root.Name='SpyCaseFilm'
 local ok,result=pcall(build,id,self)
 if not ok or not result then self:destroy();return nil end
 return result
end
function Stage:apply(q,t)
 if self.reels then for _,r in ipairs(self.reels)do r.model:PivotTo(r.frame*CFrame.Angles(q.reel,0,0))end end
 if self.actorRoot then
  local stride=math.sin(t*5.5)*(1-q.walk)*.45;local reach=q.action*(1-q.settle*.35)
  self.actorRoot.CFrame=self.base*CFrame.new(0,-self.origin.Y+self.rootY,-5+q.walk*3.85)*CFrame.Angles(0,math.pi,0)
  local solved={[self.actorRoot]=true}
  for _=1,8 do
   local changed=false
   for _,j in ipairs(self.joints)do
    local x,z=0,0
    if j.name=='RightShoulder'or j.name=='Right Shoulder'then x=reach*.9-stride*.5;z=-reach*.15
    elseif j.name=='LeftShoulder'or j.name=='Left Shoulder'then x=stride*.5
    elseif j.name=='RightElbow'then x=reach*.7
    elseif j.name=='LeftHip'or j.name=='Left Hip'then x=stride
    elseif j.name=='RightHip'or j.name=='Right Hip'then x=-stride
    elseif j.name=='Neck'then x=reach*.1 end
    local r=j.c0.Rotation;local pose=r:Inverse()*CFrame.Angles(x,0,z)*r
    if solved[j.a]and not solved[j.b]then j.b.CFrame=j.a.CFrame*j.c0*pose*j.c1:Inverse();solved[j.b]=true;changed=true
    elseif solved[j.b]and not solved[j.a]then j.a.CFrame=j.b.CFrame*j.c1*pose:Inverse()*j.c0:Inverse();solved[j.a]=true;changed=true end
   end
   if not changed then break end
  end
  local hand=self.actor:FindFirstChild('RightHand')or self.actor:FindFirstChild('Right Arm')
  if hand then
   local grip=self.base:PointToWorldSpace(Vector3.new(-.35,.48,-.33))
   local head=self.actor:FindFirstChild('Head')
   local carry=math.clamp((t-8.4)/2,0,1);carry=carry*carry*(3-2*carry)
   if head and self.id~='cassette'then grip=grip:Lerp(head.Position+Vector3.new(-.45,-.65,.45),carry)end
   local palm=function()return hand.Name=='Right Arm'and hand.CFrame:PointToWorldSpace(Vector3.new(0,-hand.Size.Y*.42,-.21))or hand.Position end
   local idle=palm();self:arm(idle:Lerp(grip,q.action))
   local pickup=math.clamp((t-8)/.4,0,1);pickup=pickup*pickup*(3-2*pickup)
   local contact=CFrame.new(palm())*CFrame.Angles(0,0,self.id=='envelope'and .12 or .16)
   if self.handset then self.handset:PivotTo(self.handsetFrame:Lerp(contact,pickup))end
   if self.envelope then
    self.envelope.CFrame=self.envelopeFrame:Lerp(contact,pickup)
    self.seal.CFrame=self.envelope.CFrame*CFrame.new(0,.04,0)*CFrame.Angles(0,0,math.pi*.5)
   end
  end
 end
end
local function align(from,to,up)
 if from.Magnitude<.001 or to.Magnitude<.001 then return CFrame.new()end
 -- Choosing a nonparallel up axis keeps nearly vertical R6 arms well-defined.
 if math.abs(from.Unit:Dot(up))>.98 or math.abs(to.Unit:Dot(up))>.98 then up=Vector3.new(0,0,1)end
 return CFrame.lookAt(Vector3.zero,to,up)*CFrame.lookAt(Vector3.zero,from,up):Inverse()
end
function Stage:arm(target)
 local names=self.names;local shoulder=names.RightShoulder or names['Right Shoulder']
 if not shoulder then return end
 local hand=self.actor:FindFirstChild('RightHand')or self.actor:FindFirstChild('Right Arm');if not hand then return end
 local upper=shoulder.b;local p0=(shoulder.a.CFrame*shoulder.c0).Position
 local elbow,wrist=names.RightElbow,names.RightWrist
 local up=self.actorRoot.CFrame.RightVector
 local function turn(part,pivot,rotation)part.CFrame=CFrame.new(pivot)*rotation*CFrame.new(-pivot)*part.CFrame end
 if not elbow or not wrist then
  local palm=hand.CFrame:PointToWorldSpace(Vector3.new(0,-hand.Size.Y*.42,-.21))
  turn(upper,p0,align(palm-p0,target-p0,up));return
 end
 local p1=(upper.CFrame*elbow.c0).Position
 local l1=(p1-p0).Magnitude;local l2=(hand.Position-p1).Magnitude
 local direction=target-p0;if direction.Magnitude<.001 then return end
 local d=math.clamp(direction.Magnitude,math.abs(l1-l2)+.01,l1+l2-.01);direction=direction.Unit
 local bend=up-direction*up:Dot(direction);if bend.Magnitude<.001 then bend=Vector3.new(0,1,0)end;bend=bend.Unit
 local x=(l1*l1-l2*l2+d*d)/(2*d);local y=math.sqrt(math.max(0,l1*l1-x*x));local e=p0+direction*x+bend*y
 turn(upper,p0,align(p1-p0,e-p0,bend))
 local lower=elbow.b;lower.CFrame=upper.CFrame*elbow.c0*elbow.c1:Inverse()
 hand.CFrame=lower.CFrame*wrist.c0*wrist.c1:Inverse()
 turn(lower,e,align(hand.Position-e,target-e,bend))
 hand.CFrame=lower.CFrame*wrist.c0*wrist.c1:Inverse()
 -- Accessories welded to the hand follow the solved arm too.
 for _,j in ipairs(self.joints)do
  if j.a==hand then j.b.CFrame=hand.CFrame*j.c0*j.c1:Inverse()
  elseif j.b==hand then j.a.CFrame=hand.CFrame*j.c1*j.c0:Inverse()end
 end
end
function Stage:destroy()if self.root then self.root:Destroy();self.root=nil end end
return Stage
