-- A camera viewfinder over the real world. Never changes CameraType or player controls.
local Scanner={}
function Scanner.new(gui,language,files,options)
 local player=game:GetService('Players').LocalPlayer;local Run=game:GetService('RunService')
 local self={active=false,generation=0};local connection;local focus;local aim;local last=0;local feedback=0
 local root=Instance.new('Frame');root.Name='PhoneViewfinder';root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Visible=false;root.Parent=gui
 local function label(name,position,size)
  local p=Instance.new('TextLabel');p.Name=name;p.Position=position;p.Size=size;p.BackgroundTransparency=.18;p.BackgroundColor3=Color3.fromRGB(14,21,21);p.TextColor3=Color3.fromRGB(232,233,221);p.Font=Enum.Font.BuilderSansMedium;p.TextSize=16;p.TextWrapped=true;p.Parent=root;return p
 end
 local title=label('ScannerTitle',UDim2.new(.1,0,0,18),UDim2.new(.8,0,0,44))
 local caption=label('ScannerFocus',UDim2.new(.1,0,1,-128),UDim2.new(.8,0,0,40))
 local cross=label('ScannerCrosshair',UDim2.new(.5,-24,.5,-24),UDim2.fromOffset(48,48));cross.BackgroundTransparency=1;cross.Text='＋';cross.TextSize=42
 local function button(name,x,key,callback)
  local p=Instance.new('TextButton');p.Name=name;p.AnchorPoint=Vector2.new(.5,1);p.Position=UDim2.new(x,0,1,-20);p.Size=UDim2.new(.4,0,0,60);p.TextColor3=cross.TextColor3;p.BackgroundColor3=Color3.fromRGB(31,42,39);p.Font=Enum.Font.BuilderSansMedium;p.TextSize=16;p.TextWrapped=true;p.BorderSizePixel=0;p.Parent=root
  p.Activated:Connect(callback);p:SetAttribute('SpyUserText',true);return p
 end
 local back=button('ScannerExit',.27,'exit_camera',function()self:stop()end)
 local shutter=button('ScannerCapture',.73,'capture',function()
  if not self.active or not focus or not aim then caption.Text=files.text(language(),'no_target');return end
  feedback=0;options.capture({action='capture',token=self.data.token,target=self.data.id,origin=aim.Origin,direction=aim.Direction.Unit})
 end)
 local highlight=Instance.new('Highlight');highlight.Name='PhoneFocus';highlight.FillTransparency=1;highlight.OutlineColor=Color3.fromRGB(195,173,121);highlight.OutlineTransparency=.15;highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Enabled=false;highlight.Parent=workspace
 local function tick(dt)
  if not self.active then return end
  if options.blocked()then self:stop();return end
  feedback=math.max(0,feedback-dt);last+=dt;if last<.1 then return end;last=0
  focus=nil;aim=nil;highlight.Enabled=false
  local cam=workspace.CurrentCamera;if not cam then return end
  local centre=cross.AbsolutePosition+cross.AbsoluteSize*.5;local ray=cam:ScreenPointToRay(centre.X,centre.Y)
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=player.Character and{player.Character}or{};params.IgnoreWater=true
  local hit=workspace:Raycast(ray.Origin,ray.Direction*80,params)
  local body=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  if hit and hit.Instance:GetAttribute('SpyPhoneEvidence')==self.data.id and body then
   if(body.Position-hit.Position).Magnitude<=18 then focus=hit.Instance;aim=ray;highlight.Adornee=focus;highlight.Enabled=true;if feedback<=0 then caption.Text=files.text(language(),'focus')..' · '..self.data.file.target end
   else if feedback<=0 then caption.Text=files.text(language(),'too_far')end end
  else if feedback<=0 then caption.Text=files.text(language(),'aim')end end
 end
 function self:start(data)
  self:stop(false);if not data or data.phase~='search'or options.blocked()then return false end
  feedback=0;self.data=data;self.active=true;self.generation+=1;root.Visible=true;title.Text=data.file.target;caption.Text=files.text(language(),'aim');back.Text=files.text(language(),'exit_camera');shutter.Text=files.text(language(),'capture')
  connection=Run.RenderStepped:Connect(tick);return true
 end
 function self:stop(notify)
  local was=self.active;self.active=false;self.generation+=1;root.Visible=false;focus=nil;aim=nil;highlight.Enabled=false
  if connection then connection:Disconnect();connection=nil end
  if was and notify~=false and options.onStop then options.onStop()end
 end
 function self:result(result)
  if not self.active then return end
  if result.ok then self:stop()else feedback=3;caption.Text=files.text(language(),result.code or'unavailable')end
 end
 function self:destroy()self:stop(false);highlight:Destroy();root:Destroy()end
 self.root=root;return self
end
return Scanner
