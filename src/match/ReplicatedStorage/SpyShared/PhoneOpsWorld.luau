-- Evidence rests on existing furniture. Only visible parts participate in camera rays.
local World={};World.__index=World
local function vector(v)
 if typeof(v)~='Vector3'then return false end
 for _,n in ipairs({v.X,v.Y,v.Z})do if n~=n or math.abs(n)>1e6 then return false end end
 return true
end
function World.build(club)
 if not club then return nil end
 local bar=club:FindFirstChild('BarTop',true);local desk=club:FindFirstChild('LibraryTop',true)
 if not bar or not desk or not bar:IsA('BasePart')or not desk:IsA('BasePart')then return nil end
 local root=club:FindFirstChild('SpyPhoneEvidenceSet');local targets={}
 if root then for _,m in ipairs(root:GetChildren())do targets[m.Name]=m end;return setmetatable({root=root,targets=targets},World)end
 root=Instance.new('Model');root.Name='SpyPhoneEvidenceSet'
 local steel=Color3.fromRGB(127,133,123);local black=Color3.fromRGB(32,36,35);local paper=Color3.fromRGB(205,193,161)
 local function object(id,surface,offset)
  local m=Instance.new('Model');m.Name=id;m:SetAttribute('SpyPhoneEvidence',id);m.Parent=root;targets[id]=m
  local origin=surface.CFrame*CFrame.new(offset.X,surface.Size.Y*.5,offset.Z)
  local function part(name,size,xyz,color,material)
   local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=origin*CFrame.new(xyz);p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=true;p.Color=color;p.Material=material or Enum.Material.Metal;p:SetAttribute('SpyPhoneEvidence',id);p.Parent=m
   if not m.PrimaryPart then m.PrimaryPart=p end;return p
  end
  return m,part
 end
 local m,part=object('cassette',bar,Vector3.new(bar.Size.X*.29,0,-bar.Size.Z*.2))
 part('Recorder',Vector3.new(1.85,.23,1.25),Vector3.new(0,.115,0),black)
 part('Panel',Vector3.new(1.7,.025,1.1),Vector3.new(0,.2425,0),steel)
 for _,x in ipairs({-.46,.46})do
  local p=part('Reel',Vector3.new(.04,.56,.56),Vector3.new(x,.275,-.12),black);p.Shape=Enum.PartType.Cylinder;p.CFrame*=CFrame.Angles(0,0,math.pi*.5)
  local hub=part('Hub',Vector3.new(.045,.13,.13),Vector3.new(x,.299,-.12),steel);hub.Shape=Enum.PartType.Cylinder;hub.CFrame*=CFrame.Angles(0,0,math.pi*.5)
 end
 for i=1,5 do part('TransportKey',Vector3.new(.17,.06,.16),Vector3.new(-.6+i*.2,.285,.4),i==5 and Color3.fromRGB(118,55,40)or black)end
 m,part=object('envelope',desk,Vector3.new(0,0,-1.5))
 part('BlueEnvelope',Vector3.new(.92,.045,1.36),Vector3.new(0,.0225,0),Color3.fromRGB(46,68,84),Enum.Material.Fabric)
 part('Fold',Vector3.new(.78,.012,.03),Vector3.new(0,.051,-.28),Color3.fromRGB(69,92,105))
 local seal=part('Seal',Vector3.new(.023,.23,.23),Vector3.new(0,.061,-.18),Color3.fromRGB(109,48,38));seal.Shape=Enum.PartType.Cylinder;seal.CFrame*=CFrame.Angles(0,0,math.pi*.5)
 m,part=object('call',bar,Vector3.new(-bar.Size.X*.29,0,-bar.Size.Z*.2))
 part('TelephoneBase',Vector3.new(1.5,.25,1.05),Vector3.new(0,.125,0),black)
 local dial=part('Dial',Vector3.new(.035,.54,.54),Vector3.new(0,.27,.12),steel);dial.Shape=Enum.PartType.Cylinder;dial.CFrame*=CFrame.Angles(0,0,math.pi*.5)
 for _,x in ipairs({-.48,.48})do part('Receiver',Vector3.new(.3,.19,.32),Vector3.new(x,.4,-.27),black)end
 part('Handset',Vector3.new(.96,.1,.15),Vector3.new(0,.46,-.27),black)
 part('NumberPlate',Vector3.new(.46,.018,.12),Vector3.new(0,.283,.4),paper)
 root.Parent=club;return setmetatable({root=root,targets=targets},World)
end
function World:capture(player,p,expected)
 local model=self.targets[expected];local target=model and model.PrimaryPart
 local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart');local head=char and char:FindFirstChild('Head')
 if not target or not target.Parent or not root or not head or type(p)~='table'or not vector(p.origin)or not vector(p.direction)then return false end
 if(p.origin-head.Position).Magnitude>16 or(root.Position-target.Position).Magnitude>18 or p.direction.Magnitude<.9 or p.direction.Magnitude>1.1 then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char};params.IgnoreWater=true
 local towardCamera=p.origin-head.Position
 if towardCamera.Magnitude>.25 then
  local block=workspace:Raycast(head.Position,towardCamera,params)
  if block and block.Distance<towardCamera.Magnitude-.2 then return false end
 end
 local hit=workspace:Raycast(p.origin,p.direction.Unit*80,params)
 return hit~=nil and hit.Instance:IsDescendantOf(model)
end
return World
