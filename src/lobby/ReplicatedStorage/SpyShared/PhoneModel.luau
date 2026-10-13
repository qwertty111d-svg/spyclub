-- Original handheld hardware, welded to the real avatar. No imported scripts/assets.
local Model={}
function Model.hand(character)return character:FindFirstChild('RightHand')or character:FindFirstChild('Right Arm')end
function Model.create(character)
 local hand=Model.hand(character);if not hand then return nil end
 local old=character:FindFirstChild('SpyPhone');if old then old:Destroy()end
 local root=Instance.new('Model');root.Name='SpyPhone'
 local scale=math.clamp(hand.Size.Y/(hand.Name=='Right Arm'and 2 or 1),.75,1.35)
 local body
 local function part(name,size,offset,color,material)
  local p=Instance.new('Part');p.Name=name;p.Size=size*scale;p.CFrame=hand.CFrame*offset
  p.Color=color;p.Material=material or Enum.Material.Metal;p.Anchored=false;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=root
  if body then local w=Instance.new('WeldConstraint');w.Part0=body;w.Part1=p;w.Parent=p end;return p
 end
 -- Keep the device beyond the real hand's thickness/end, including blocky R6.
 -- A single grip joint turns the whole connected device without stretching its parts.
 local center=CFrame.new(0,-hand.Size.Y/2-.24*scale,-hand.Size.Z/2-.10*scale)*CFrame.Angles(0,math.pi,0)
 body=part('GraphiteBody',Vector3.new(.64,1.08,.095),center,Color3.fromRGB(32,34,33))
 local grip=Instance.new('Motor6D');grip.Name='PhoneGrip';grip.Part0=hand;grip.Part1=body;grip.C0=center;grip.C1=CFrame.new();grip.Transform=CFrame.new();grip.Parent=body
 for _,x in ipairs({-.309,.309})do part('SideRail',Vector3.new(.018,.94,.10),center*CFrame.new(x*scale,0,0),Color3.fromRGB(92,95,89))end
 local screen=part('Screen',Vector3.new(.56,.94,.014),center*CFrame.new(0,.01,-.056*scale),Color3.fromRGB(13,21,21),Enum.Material.SmoothPlastic)
 local ui=Instance.new('SurfaceGui');ui.Name='ClubDisplay';ui.Face=Enum.NormalId.Front;ui.CanvasSize=Vector2.new(180,300);ui.LightInfluence=.2;ui.Parent=screen
 local label=Instance.new('TextLabel');label.Position=UDim2.fromOffset(14,20);label.Size=UDim2.fromOffset(150,60);label.BackgroundTransparency=1;label.Text=os.date('%H:%M');label.TextColor3=Color3.fromRGB(237,240,228);label.TextSize=32;label.Font=Enum.Font.BuilderSansBold;label.Parent=ui
 for i,color in ipairs({Color3.fromRGB(79,148,113),Color3.fromRGB(82,127,161),Color3.fromRGB(61,136,102),Color3.fromRGB(90,101,111),Color3.fromRGB(150,126,76),Color3.fromRGB(116,102,145),Color3.fromRGB(151,130,66),Color3.fromRGB(134,101,115)})do
  local tile=Instance.new('Frame');tile.Name='AppIcon_'..i;tile.Size=UDim2.fromOffset(30,30);tile.Position=UDim2.fromOffset(17+((i-1)%4)*39,108+math.floor((i-1)/4)*48);tile.BackgroundColor3=color;tile.BorderSizePixel=0;tile.Parent=ui
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=tile
  local stroke=Instance.new('UIStroke');stroke.Thickness=1;stroke.Color=Color3.fromRGB(227,235,220);stroke.Transparency=.5;stroke.Parent=tile
 end
 part('Receiver',Vector3.new(.14,.013,.012),center*CFrame.new(0,.46*scale,-.047*scale),Color3.fromRGB(110,118,107))
 part('Lens',Vector3.new(.095,.095,.023),center*CFrame.new(-.17*scale,.36*scale,.056*scale),Color3.fromRGB(13,16,19))
 local led=part('FlashLED',Vector3.new(.065,.065,.016),center*CFrame.new(-.04*scale,.36*scale,.056*scale),Color3.fromRGB(231,224,190))
 root.PrimaryPart=body;root.Parent=character;return root
end
function Model.visible(root,show)
 if not root then return end
 for _,n in ipairs(root:GetDescendants())do if n:IsA('BasePart')then n.Transparency=show and 0 or 1 elseif n:IsA('SurfaceGui')then n.Enabled=show end end
end
return Model
