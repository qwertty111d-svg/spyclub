-- Client-only rain with a fixed part budget. It never gates lobby startup.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local touch=game:GetService("UserInputService").TouchEnabled
local player=Players.LocalPlayer
if not player then return end
local rng=Random.new()
local rain,windows,heartbeat
local drops={}
local surfaces={}
local streams={}
local stopped=false
local accumulator=0
local scan
local function destroy()
 if heartbeat then heartbeat:Disconnect();heartbeat=nil end
 if rain then rain:Destroy();rain=nil end
 for _,surface in ipairs(surfaces)do surface:Destroy()end
 windows=nil;table.clear(drops);table.clear(surfaces);table.clear(streams)
end
local function enabled()return player:GetAttribute("SpyEffects")~=false end
local function reset(drop,initial)
 drop.x=drop.center.X-rng:NextNumber(1.5,8.5)
 drop.y=initial and rng:NextNumber(drop.center.Y-6.5,drop.center.Y+9.5) or rng:NextNumber(drop.center.Y+6.5,drop.center.Y+9.5)
 drop.z=drop.center.Z+rng:NextNumber(-5.7,5.7)
 drop.speed=rng:NextNumber(19,25)
end
local function resetStream(stream,initial)
 stream.x=rng:NextNumber(8,stream.width-8)
 stream.y=initial and rng:NextNumber(0,stream.height-12) or -stream.length-8
 stream.speed=rng:NextNumber(18,48)
 stream.phase=rng:NextNumber(0,math.pi*2)
 stream.age=0
 stream.part.Position=UDim2.fromOffset(stream.x,stream.y)
end
local function wetGlass(glass)
 local old=glass:FindFirstChild("GlassRain");if old then old:Destroy()end
 local surface=Instance.new("SurfaceGui");surface.Name="GlassRain";surface.Adornee=glass
 -- +X is the club-facing side of the west-wall panes. This layer is water,
 -- not a screen overlay: furniture and the wooden mullions still occlude it.
 surface.Face=Enum.NormalId[glass:GetAttribute("RainFace") or "Right"];surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
 local width=math.max(240,math.floor(glass.Size.Z*60))
 local height=math.max(200,math.floor(glass.Size.Y*60))
 surface.CanvasSize=Vector2.new(width,height);surface.AlwaysOnTop=false;surface.LightInfluence=0
 surface.Brightness=.60;surface.MaxDistance=90;surface.ZOffset=.012
 surface.ClipsDescendants=true;surface.Active=false;surface.Enabled=enabled();surface.Parent=glass
 surfaces[#surfaces+1]=surface
 local function water(parent,name,w,h,alpha)
  local f=Instance.new("Frame");f.Name=name;f.Size=UDim2.fromOffset(w,h)
  f.BorderSizePixel=0;f.BackgroundColor3=Color3.fromRGB(163,188,192)
  f.BackgroundTransparency=alpha;f.Active=false;f.Parent=parent
  local curve=Instance.new("UICorner");curve.CornerRadius=UDim.new(.5,0);curve.Parent=f
  return f
 end
 for index=1,(touch and 7 or 14) do
  local length=rng:NextNumber(10,36)
  local flow=water(surface,"Rivulet",rng:NextNumber(1.1,1.8),length,.88)
  local bead=water(flow,"WaterBead",2.6,5,.78);bead.AnchorPoint=Vector2.new(.5,1);bead.Position=UDim2.new(.5,0,1,1)
  local glint=water(bead,"Reflection",.9,2.8,.84);glint.Position=UDim2.fromOffset(.4,.8)
  local stream={part=flow,length=length,index=index,width=width,height=height};resetStream(stream,true);streams[#streams+1]=stream
 end
 for index=1,(touch and 6 or 12) do
  local bead=water(surface,"Condensation",rng:NextNumber(1.2,2.3),rng:NextNumber(2.5,4),.82)
  bead.Position=UDim2.fromOffset(rng:NextNumber(8,width-8),rng:NextNumber(8,height-8))
 end
end
local function attach(model)
 if stopped or windows==model then return end
 local centers,panes={},{}
 local club=workspace:FindFirstChild("SpyClub")
 local entrance=club and club:FindFirstChild("NocturneLounge")
 local entranceGlass=entrance and entrance:FindFirstChild("Glass")
 for _,name in ipairs({"EntranceWindow","LoungeWindow"})do
  local bay=model:FindFirstChild(name);local glass=bay and bay:FindFirstChild("Glass")
  if not glass then return end
  centers[#centers+1]=glass.Position
  for _,pane in ipairs(bay:GetDescendants())do
   if pane:IsA("BasePart")and (pane:GetAttribute("RainPane")==true or pane==glass)then panes[#panes+1]=pane end
  end
 end
 if entranceGlass then centers[#centers+1]=entranceGlass.Position;panes[#panes+1]=entranceGlass end
 destroy();windows=model
 for _,glass in ipairs(panes)do wetGlass(glass)end
 rain=Instance.new("Folder");rain.Name="SpyLocalWindowRain";rain.Parent=workspace
 local count=touch and 10 or(player:GetAttribute("SpyReducedMotion")==true and 14 or 28)
 for _,center in ipairs(centers)do for index=1,count do
  local p=Instance.new("Part");p.Name="RainStreak";p.Size=Vector3.new(.035,rng:NextNumber(.65,1.15),.035)
  p.Color=Color3.fromRGB(123,151,162);p.Material=Enum.Material.SmoothPlastic
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Transparency=enabled() and .72 or 1;p.Parent=rain
  local drop={part=p,center=center};reset(drop,true);drops[#drops+1]=drop
  p.CFrame=CFrame.new(drop.x,drop.y,drop.z)
 end end
 heartbeat=RunService.Heartbeat:Connect(function(dt)
  if not model.Parent or not script.Parent then destroy();return end
  for _,glass in ipairs(panes)do
   if not glass.Parent then destroy();task.defer(scan);return end
  end
  accumulator+=dt
  if accumulator<(touch and 1/15 or 1/30) then return end
  local elapsed=math.min(accumulator,.1);accumulator=0
  local show=enabled()
  local calm=player:GetAttribute("SpyReducedMotion")==true
  for _,surface in ipairs(surfaces)do surface.Enabled=show end
  for _,stream in ipairs(streams)do
   stream.part.Visible=not calm or stream.index<=7
   if show then
    stream.age+=elapsed;stream.y+=stream.speed*elapsed*(calm and .45 or 1)
    if stream.y>stream.height+8 then resetStream(stream,false)end
    local drift=math.sin(stream.age*.8+stream.phase)*1.2
    stream.part.Position=UDim2.fromOffset(stream.x+drift,stream.y)
   end
  end
  for _,drop in ipairs(drops)do
   drop.part.Transparency=show and .72 or 1
   if show then
    drop.y-=drop.speed*elapsed;drop.z-=elapsed*1.2
    if drop.y<drop.center.Y-8.2 then reset(drop,false)end
    drop.part.CFrame=CFrame.new(drop.x,drop.y,drop.z)*CFrame.Angles(0,0,-.05)
   end
  end
 end)
end
scan=function()
 local club=workspace:FindFirstChild("SpyClub")
 local model=club and club:FindFirstChild("RainWindows")
 if model then
  local entrance=club:FindFirstChild("NocturneLounge")
  local pane=entrance and entrance:FindFirstChild("Glass")
  local missing=pane and not pane:FindFirstChild("GlassRain")
  for _,glass in ipairs(model:GetDescendants())do
   if glass:IsA("BasePart")and glass:GetAttribute("RainPane")==true and not glass:FindFirstChild("GlassRain")then missing=true;break end
  end
  if windows==model and missing then destroy()end
  attach(model)
 end
end
local connection=workspace.DescendantAdded:Connect(function(n)
 if n.Name=="RainWindows"or n.Name=="Glass"or n.Name=="GlassLowerLeft"or n.Name=="VentGlass"then task.defer(scan)end
end)
script.Destroying:Connect(function()stopped=true;connection:Disconnect();destroy()end)
task.defer(scan)
