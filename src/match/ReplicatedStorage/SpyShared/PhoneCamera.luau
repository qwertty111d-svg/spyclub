-- Local photos only. Saving always uses Roblox's explicit gallery prompt.
local Camera={}
function Camera.new(gui,language,options)
 local player=game:GetService('Players').LocalPlayer
 local self={active=false,generation=0};local leases={};local masks={};local connections={};local ownedCamera;local subject;local mode
 local root=Instance.new('Frame');root.Name='PhoneCameraView';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Visible=false;root.Parent=gui
 local function text(ru,en,zh)return language()=='en'and en or language()=='zh'and zh or ru end
 local function button(name,x,callback)
  local b=Instance.new('TextButton');b.Name=name;b.AnchorPoint=Vector2.new(.5,1);b.Position=UDim2.new(x,0,1,-24);b.Size=UDim2.new(.42,0,0,52);b.BackgroundColor3=Color3.fromRGB(25,34,33);b.BorderSizePixel=0;b.TextColor3=Color3.fromRGB(243,240,228);b.Font=Enum.Font.BuilderSansBold;b.TextSize=17;b.Parent=root
  local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(200,52);limit.Parent=b
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=b;b.Activated:Connect(callback);return b
 end
 local function ownsView()return workspace.CurrentCamera==ownedCamera and ownedCamera.CameraType==Enum.CameraType.Custom and ownedCamera.CameraSubject==subject and player.CameraMode==Enum.CameraMode.LockFirstPerson end
 local function maskPhone()
  local phone=player.Character and player.Character:FindFirstChild('SpyPhone')
  if phone then for _,part in ipairs(phone:GetDescendants())do if part:IsA('BasePart')then if masks[part]==nil then masks[part]=part.LocalTransparencyModifier end;part.LocalTransparencyModifier=1 end end end
 end
 local function hideHUD(g)
  if g~=gui and g:IsA('ScreenGui')and g.Enabled then leases[g]=true;g.Enabled=false end
 end
 local back=button('ExitPhoneCamera',.25,function()self:stop()end)
 local shutter=button('PhoneShutter',.75,function()
  if not self.active or self.pending then return end
  self.pending=true;self.generation+=1;local generation=self.generation;root.Visible=false
  if options.shutter then options.shutter()end
  local function finish(id)
   if not self.active or self.generation~=generation or not self.pending then return end
   self.pending=false
   if options.blocked()or not ownsView()then self:stop();return end
   if type(id)=='string'and #id>0 then self:stop();options.photo(id)
   else root.Visible=true;options.error('unavailable')end
  end
  task.delay(5,function()if self.active and self.generation==generation and self.pending then finish(nil)end end)
  task.delay(.05,function()
   if not self.active or self.generation~=generation then return end
   if options.blocked()or not ownsView()then self:stop();return end
   local ok=pcall(function()game:GetService('CaptureService'):CaptureScreenshot(finish)end);if not ok then finish(nil)end
  end)
 end)
 function self:start()
  self:stop(false)
  local camera=workspace.CurrentCamera;local character=player.Character;local human=character and character:FindFirstChildOfClass('Humanoid')
  if options.blocked()or player:GetAttribute('SpyPhoneCameraActive')==true or not camera or not human or human.Health<=0 or camera.CameraType~=Enum.CameraType.Custom or camera.CameraSubject~=human then return false end
  ownedCamera=camera;subject=human;mode=player.CameraMode
  self.active=true;self.pending=false;player.CameraMode=Enum.CameraMode.LockFirstPerson
  local head=character:FindFirstChild('Head');local torso=character:FindFirstChild('HumanoidRootPart')
  if torso then local position=head and head.Position or torso.Position;camera.CFrame=CFrame.lookAt(position,position+torso.CFrame.LookVector)end
  maskPhone();for _,g in ipairs(gui.Parent:GetChildren())do hideHUD(g)end
  connections[#connections+1]=gui.Parent.ChildAdded:Connect(function(g)if self.active then hideHUD(g)end end)
  connections[#connections+1]=game:GetService('RunService').RenderStepped:Connect(function()
   if options.blocked()or player.Character~=character or human.Health<=0 or not ownsView()then self:stop();return end;maskPhone()
  end)
  connections[#connections+1]=human.Died:Connect(function()self:stop()end)
  root.Visible=true;back.Text=text('Назад','Back','返回');shutter.Text=text('Снять','Capture','拍照')
  player:SetAttribute('SpyPhoneCameraActive',true);return true
 end
 function self:stop(notify)
  local was=self.active;self.active=false;self.pending=false;self.generation+=1;root.Visible=false
  for _,connection in ipairs(connections)do connection:Disconnect()end;table.clear(connections)
  -- Release only our settings; a cinematic may already own the camera.
  if was and player.CameraMode==Enum.CameraMode.LockFirstPerson then player.CameraMode=mode end
  for part,value in pairs(masks)do if part.Parent and part.LocalTransparencyModifier==1 then part.LocalTransparencyModifier=value end end;table.clear(masks)
  for g,value in pairs(leases)do if g.Parent and g.Enabled==false then g.Enabled=value end end;table.clear(leases)
  if was then player:SetAttribute('SpyPhoneCameraActive',false)end
  if was and notify~=false then options.onStop()end
 end
 function self:save(id)
  if type(id)~='string'or #id==0 then return end
  local ok=pcall(function()game:GetService('CaptureService'):PromptSaveCapturesToGallery({id},function()end)end)
  if not ok then options.error('unavailable')end
 end
 function self:destroy()self:stop(false);root:Destroy()end
 self.root=root;return self
end
return Camera
