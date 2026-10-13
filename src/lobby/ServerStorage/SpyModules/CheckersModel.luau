local TweenService=game:GetService("TweenService")
local Model={CELL=.185,OUTER=1.76}
local cache=setmetatable({},{__mode="k"})
function Model.build(group)
 if cache[group]and cache[group].model.Parent then return cache[group]end
 local top=assert(group:FindFirstChild("CafeTableTop",true),"checkers_table_missing")
 local y=top.Position.Y+top.Size.X*.5+.005
 local center=Vector3.new(top.Position.X,y+.109,top.Position.Z)
 local seats={}
 for _,p in ipairs(group:GetChildren())do if p:IsA("Seat")then seats[p.Position.Z>center.Z and 1 or 2]=p end end
 assert(seats[1]and seats[2],"checkers_chairs_missing")
 local self={center=center,height=center.Y,cell=Model.CELL,seats=seats,pieces={},leases={},alive=true}
 local model=Instance.new("Model");model.Name="SpyCheckers";model.Parent=group;self.model=model
 local function lease(object,prop,value)
  local old=object[prop];self.leases[#self.leases+1]={object=object,prop=prop,old=old,value=value};object[prop]=value
 end
 for _,p in ipairs(group:GetChildren())do
  if p.Name:sub(1,8)=="CafeLamp"and p:IsA("BasePart")then lease(p,"CFrame",p.CFrame+Vector3.new(-1.16,0,0))
  elseif p.Name=="CafeFolder"or p.Name=="EspressoCup"then lease(p,"Transparency",1)end
 end
 local diffuser=group:FindFirstChild("CafeLampDiffuser")
 if diffuser then local light=diffuser:FindFirstChildOfClass("SurfaceLight");if light then lease(light,"Brightness",.35)end end
 local function part(parent,name,size,frame,color,material,variant)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.Wood
  p.MaterialVariant=variant or"ClubOak";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Reflectance=0;p:SetAttribute("SpyAuthoredSurface",true);p.Parent=parent;return p
 end
 local oak=Color3.fromRGB(59,52,44);local pale=Color3.fromRGB(154,150,136);local dark=Color3.fromRGB(65,68,65)
 local base=part(model,"BoardFrame",Vector3.new(Model.OUTER,.09,Model.OUTER),CFrame.new(center.X,y+.045,center.Z),oak,Enum.Material.Wood,"")
 base.CanQuery=true
 for r=1,8 do for c=1,8 do
  local p=part(model,"Square",Vector3.new(Model.CELL,.014,Model.CELL),CFrame.new(center.X+(c-4.5)*Model.CELL,y+.102,center.Z+(4.5-r)*Model.CELL),(c+r)%2==0 and dark or pale,Enum.Material.Wood,"")
  p.CanQuery=true;p:SetAttribute("CheckersSquare",(r-1)*8+c)
 end end
 local pieces=Instance.new("Folder");pieces.Name="Pieces";pieces.Parent=model
 local function squarePose(s,layer)
  local c,r=(s-1)%8+1,math.floor((s-1)/8)+1
  return CFrame.new(center.X+(c-4.5)*Model.CELL,center.Y+layer,center.Z+(4.5-r)*Model.CELL)
 end
 local function pose(s,offset,detail)
  return squarePose(s,offset)*(detail or CFrame.Angles(0,0,math.pi*.5))
 end
 local function layer(unit,name,height,diameter,offset,color)
  local p=part(unit.model,name,Vector3.new(height,diameter,diameter),pose(unit.square,offset),color,Enum.Material.Wood,"")
  p.Shape=Enum.PartType.Cylinder;unit.layers[#unit.layers+1]={part=p,offset=offset};return p
 end
 function self:render(st)
  if not self.alive then return end
  local present={}
  for s,value in ipairs(st.board)do if value~=0 then
   local id=st.ids[s];present[id]=true;local unit=self.pieces[id]
   local color=value>0 and Color3.fromRGB(188,179,157)or Color3.fromRGB(31,34,32)
   if not unit then
    local m=Instance.new("Model");m.Name="Piece"..id;m.Parent=pieces
    unit={model=m,layers={},tweens={},square=s};self.pieces[id]=unit
    layer(unit,"Body",.055,.151,.031,color)
    layer(unit,"TurnedRim",.007,.143,.062,color:Lerp(Color3.fromRGB(86,94,92),.14))
    layer(unit,"CarvedCentre",.005,.105,.066,color)
   end
   if math.abs(value)==1 and unit.king then
    for i=#unit.layers,4,-1 do local detail=unit.layers[i];local tween=unit.tweens[detail.part];if tween then pcall(function()tween:Cancel()end)end;unit.tweens[detail.part]=nil;detail.part:Destroy();table.remove(unit.layers,i)end
    unit.king=false
   end
   if math.abs(value)==2 and not unit.king then
    unit.king=true
    local seal=layer(unit,"King",.006,.108,.073,Color3.fromRGB(119,106,76));seal.Material=Enum.Material.Metal
    local function crown(name,size,x,z,rotation)
     local detail=CFrame.new(x,0,z)*CFrame.Angles(0,rotation or 0,0)
     local p=part(unit.model,name,size,pose(s,.078,detail),Color3.fromRGB(159,143,104),Enum.Material.Metal,"")
     unit.layers[#unit.layers+1]={part=p,offset=.078,frame=detail}
    end
    crown("CrownBase",Vector3.new(.069,.006,.010),0,.018)
    crown("CrownLeft",Vector3.new(.012,.006,.044),-.023,-.004,.22)
    crown("CrownCentre",Vector3.new(.012,.006,.051),0,-.008)
    crown("CrownRight",Vector3.new(.012,.006,.044),.023,-.004,-.22)
   end
   local moved=unit.square~=s;unit.square=s
   for _,detail in ipairs(unit.layers)do
    local p=detail.part;p.Transparency=st.captured[s]and .60 or 0
    if moved then
     if unit.tweens[p]then pcall(function()unit.tweens[p]:Cancel()end)end
     local target=pose(s,detail.offset,detail.frame)
     local ok=pcall(function()local t=TweenService:Create(p,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=target});unit.tweens[p]=t;t:Play()end)
     if not ok then p.CFrame=target end
    end
   end
  end end
  for id,unit in pairs(self.pieces)do if not present[id]then
   for _,t in pairs(unit.tweens)do pcall(function()t:Cancel()end)end
   unit.model:Destroy();self.pieces[id]=nil
  end end
 end
 local prompt=Instance.new("ProximityPrompt");prompt.Name="CheckersPrompt";prompt.ObjectText="Шашки";prompt.ActionText="Играть"
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.HoldDuration=0;prompt.MaxActivationDistance=8;prompt.RequiresLineOfSight=false;prompt.Parent=base;self.prompt=prompt
 function self:destroy()
  if not self.alive then return end;self.alive=false
  for _,unit in pairs(self.pieces)do for _,t in pairs(unit.tweens)do pcall(function()t:Cancel()end)end end
  for _,record in ipairs(self.leases)do pcall(function()if record.object.Parent and record.object[record.prop]==record.value then record.object[record.prop]=record.old end end)end
  cache[group]=nil;model:Destroy()
 end
 cache[group]=self;return self
end
return Model
