-- Two brass lanterns on a cue-tail bracket. Pure local presentation; no remotes or ball physics.
local Lanterns={}
function Lanterns.create(parent)
 local self={parts={}}
 function self:destroy()
  if self.model then self.model:Destroy();self.model=nil end;table.clear(self.parts)
 end
 local function create()
  local model=Instance.new("Model");model.Name="CueLanterns";self.model=model
  local function part(name,size,pos,color,material)
   local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Material=material
   p.MaterialVariant=material==Enum.Material.Metal and "ClubMetal"or ""
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
   self.parts[#self.parts+1]={part=p,size=size,offset=pos};p.Parent=model;return p
  end
  local metal=Color3.fromRGB(128,104,69)
  part("Bracket",Vector3.new(.58,.035,.035),Vector3.new(0,.12,.12),metal,Enum.Material.Metal)
  for _,side in ipairs({-1,1})do
   local x=side*.27
   for _,y in ipairs({.04,.31})do part("Cap",Vector3.new(.19,.035,.16),Vector3.new(x,y,0),metal,Enum.Material.Metal)end
   for _,dx in ipairs({-.077,.077})do for _,z in ipairs({-.062,.062})do
    part("Frame",Vector3.new(.018,.25,.018),Vector3.new(x+dx,.175,z),metal,Enum.Material.Metal)
   end end
   local lens=part("Lens",Vector3.new(.085,.16,.07),Vector3.new(x,.175,.015),Color3.fromRGB(255,215,152),Enum.Material.Neon)
   lens.Transparency=.12;lens:SetAttribute("ClubFixture",true)
   local light=Instance.new("SpotLight");light.Name="Spot";light.Face=Enum.NormalId.Back;light.Color=Color3.fromRGB(255,222,174)
   light.Brightness=.5;light.Range=4.5;light.Angle=95;light.Shadows=false;light.Parent=lens
  end
  model.Parent=parent
 end
 function self:update(cue,scale,visible)
  if not visible or not parent.Parent or not cue or not cue.Parent then self:destroy();return end
  if not self.model then create()end
  local base=cue.CFrame*CFrame.new(0,0,-cue.Size.Z*.5-.17*scale)
  for _,record in ipairs(self.parts)do record.part.Size=record.size*scale;record.part.CFrame=base*CFrame.new(record.offset*scale)end
 end
 return self
end
return Lanterns
