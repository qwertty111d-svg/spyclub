-- A bounded camera lease on the existing club. No miniature, clones or new room.
local Scene={};Scene.__index=Scene
local blocked={'SpyEntryActive','SpyEntryPending','SpyTeleporting','SpyReconnectBusy','SpyBilliardsPlaying','SpyCheckersPlaying'}
function Scene.new(options)
 local self=setmetatable({active=false,generation=0,connections={},hiddenParts={},humanoids={},options=options or{}},Scene)
 self.player=game:GetService('Players').LocalPlayer;self.run=game:GetService('RunService')
 self.input=game:GetService('UserInputService');self.actions=game:GetService('ContextActionService')
 return self
end
function Scene:frame(close,opening)
 local head=self.head;if not head or not head.Parent then return nil end
 local forward=head.CFrame.LookVector;forward=Vector3.new(forward.X,0,forward.Z)
 if forward.Magnitude<.01 then forward=Vector3.new(0,0,-1)else forward=forward.Unit end
 local right=Vector3.new(-forward.Z,0,forward.X)
 local camera=workspace.CurrentCamera;local portrait=camera and camera.ViewportSize.X<camera.ViewportSize.Y
 -- Aim below the face: Vincent stays above the dialogue rather than behind it.
 local distance=portrait and 6.7 or(close and 6.4 or 8.6)
 if opening then distance+=portrait and 1.2 or 2.2 end
 local side=portrait and .45 or 1.3;local horizontal=math.sqrt(distance*distance+side*side)
 local fraction=math.clamp(((self.insetY or 0)+(self.space or camera.ViewportSize.Y*.65)*.45)/camera.ViewportSize.Y,.15,.35)
 local angle=math.atan((1-2*fraction)*math.tan(math.rad(24)))+math.atan(.25/horizontal)
 local target=head.Position-Vector3.new(0,horizontal*math.tan(angle)-.25,0)
 return CFrame.lookAt(head.Position+forward*distance+right*side+Vector3.new(0,.25,0),target),CFrame.new(target)
end
function Scene:canStart()
 for _,key in ipairs(blocked)do if self.player:GetAttribute(key)==true then return false end end
 local h=self.player.Character and self.player.Character:FindFirstChildOfClass('Humanoid')
 if not h or h.Health<=0 or h.SeatPart then return false end
 local camera=workspace.CurrentCamera
 return camera and camera.CameraType~=Enum.CameraType.Scriptable
end
function Scene:hideCharacter(character)
 if not character then return end
 for _,n in ipairs(character:GetDescendants())do if n:IsA('BasePart')then
  if self.hiddenParts[n]==nil then self.hiddenParts[n]=n.LocalTransparencyModifier end
  n.LocalTransparencyModifier=1
 end end
end
function Scene:hold(dt)
 if not self.active then return end
 if workspace.CurrentCamera~=self.camera or not self.head.Parent then self:stop(true);return end
 if self.appliedPose and(self.camera.CameraType~=Enum.CameraType.Scriptable or self.camera.CFrame~=self.appliedPose)then self:stop(true,false);return end
 local target,focus=self:frame(self.closeup);if not target then self:stop(true);return end
 local reduced=self.player:GetAttribute('SpyReducedMotion')==true or self.player:GetAttribute('SpyCameraMotion')==false
 self.pose=reduced and target or self.pose:Lerp(target,1-math.exp(-math.min(dt or .016,1)*5))
 self.writing=true;self.camera.CameraType=Enum.CameraType.Scriptable;self.camera.CFrame=self.pose;self.camera.Focus=focus;self.camera.FieldOfView=48
 self.appliedPose=self.pose;self.writing=false
 self.input.MouseBehavior=Enum.MouseBehavior.Default
 local h=self.player.Character and self.player.Character:FindFirstChildOfClass('Humanoid')
 if not h or h.Health<=0 or h.SeatPart then self:stop(true);return end
 local forced={WalkSpeed=0,JumpPower=0,JumpHeight=0,AutoRotate=false}
 local saved=self.humanoids[h]
 if not saved then saved={};for k in pairs(forced)do saved[k]=h[k]end;self.humanoids[h]=saved end
 for k,v in pairs(forced)do if h[k]~=v then saved[k]=h[k];h[k]=v end end
 h.Jump=false;h:Move(Vector3.zero,false)
 self:hideCharacter(self.player.Character)
end
function Scene:start()
 if self.active then return true end
 if self.space and self.space<96 then return false end
 if not self:canStart()then return false end
 local club=workspace:FindFirstChild('SpyClub');local vincent=club and club:FindFirstChild('VincentVisual',true)
 local head=vincent and vincent:FindFirstChild('Head',true)
 if not head or not head:IsA('BasePart')then return false end
 self:clearRecovery()
 self.head=head;self.camera=workspace.CurrentCamera
 self.saved={frame=self.camera.CFrame,focus=self.camera.Focus,fov=self.camera.FieldOfView,subject=self.camera.CameraSubject,mouse=self.input.MouseBehavior}
 self.closeup=false;self.pose=self:frame(false,true);self.appliedPose=nil;self.writing=false;self.active=true;self.generation+=1;local id=self.generation
 self.player:SetAttribute('SpyCaseCinematicActive',true)
 local ok,err=pcall(function()
  self.actions:BindActionAtPriority('SpyCaseMovement',function()
   if self.input:GetFocusedTextBox()then return Enum.ContextActionResult.Pass end
   return Enum.ContextActionResult.Sink
  end,false,3001,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Space)
  self.run:BindToRenderStep('SpyCaseCinematic',Enum.RenderPriority.Camera.Value+2,function(dt)
   local held,err=pcall(self.hold,self,dt);if not held then warn('[SpyCaseCamera] '..tostring(err));self:stop(true)end
  end)
  self.connections[#self.connections+1]=self.camera:GetPropertyChangedSignal('CFrame'):Connect(function()
   if self.active and self.appliedPose and not self.writing and self.camera.CFrame~=self.appliedPose then self:stop(true,false)end
  end)
  self.connections[#self.connections+1]=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()self:stop(true)end)
  self.connections[#self.connections+1]=self.player.CharacterRemoving:Connect(function()self:stop(true)end)
  self.connections[#self.connections+1]=self.input.InputBegan:Connect(function(key)
   if key.KeyCode==Enum.KeyCode.Escape or key.KeyCode==Enum.KeyCode.ButtonB then self:stop(true)end
  end)
  for _,key in ipairs(blocked)do self.connections[#self.connections+1]=self.player:GetAttributeChangedSignal(key):Connect(function()
   if self.player:GetAttribute(key)==true then self:stop(true,key~='SpyBilliardsPlaying'and key~='SpyCheckersPlaying'and key~='SpyEntryActive')end
  end)end
  self:hold(0)
 end)
 if not ok then warn('[SpyCaseCamera] '..tostring(err));self:stop(false);return false end
 -- Physical movement is held on this Humanoid; native PlayerModule stays with its owner.
 task.delay(120,function()if self.active and self.generation==id then self:stop(true)end end)
 return self.active
end
function Scene:focus(closeup)self.closeup=closeup==true end
function Scene:restoreView(camera,saved)
 local h=self.player.Character and self.player.Character:FindFirstChildOfClass('Humanoid')
 camera.CFrame=saved.frame;camera.Focus=saved.focus;camera.FieldOfView=self.player:GetAttribute('SpyFOV')or saved.fov
 camera.CameraSubject=h or saved.subject;camera.CameraType=Enum.CameraType.Custom
end
function Scene:clearRecovery()
 local record=self.recovery;self.recovery=nil
 if record then for _,c in ipairs(record.connections)do c:Disconnect()end end
end
function Scene:watchRetired(camera,pose,saved)
 self:clearRecovery()
 local record={connections={},pending=false};self.recovery=record
 local function check()
  if self.recovery~=record then return end
  if workspace.CurrentCamera~=camera or camera.CameraType==Enum.CameraType.Custom then self:clearRecovery();return end
  if camera.CameraType~=Enum.CameraType.Scriptable or camera.CFrame~=pose or record.pending then return end
  record.pending=true
  task.defer(function()
   record.pending=false
   if self.recovery~=record or self.active or workspace.CurrentCamera~=camera or camera.CameraType~=Enum.CameraType.Scriptable or camera.CFrame~=pose then return end
   self:clearRecovery();pcall(self.restoreView,self,camera,saved)
  end)
 end
 for _,key in ipairs({'CFrame','CameraType'})do record.connections[#record.connections+1]=camera:GetPropertyChangedSignal(key):Connect(check)end
 record.connections[#record.connections+1]=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(check)
 record.connections[#record.connections+1]=self.player.CharacterRemoving:Connect(function()self:clearRecovery()end)
end
function Scene:stop(notify,restoreCamera)
 if not self.active then return end
 -- Membership can arrive before its new camera writer. Release our own pose,
 -- but leave an already changed table/entry view with its current owner.
 local releaseView=restoreCamera~=false or(self.camera and self.camera.CameraType==Enum.CameraType.Scriptable and self.camera.CFrame==self.pose)
 self.active=false;self.generation+=1
 pcall(function()self.run:UnbindFromRenderStep('SpyCaseCinematic')end)
 pcall(function()self.actions:UnbindAction('SpyCaseMovement')end)
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 for h,values in pairs(self.humanoids)do pcall(function()
  for k,forced in pairs({WalkSpeed=0,JumpPower=0,JumpHeight=0,AutoRotate=false})do if h[k]==forced then h[k]=values[k]end end
 end)end;table.clear(self.humanoids)
 for n,alpha in pairs(self.hiddenParts)do pcall(function()if n.LocalTransparencyModifier==1 then n.LocalTransparencyModifier=alpha end end)end;table.clear(self.hiddenParts)
 local saved=self.saved
 if saved then
  pcall(function()self.input.MouseBehavior=saved.mouse end)
  if self.camera then
   if releaseView then self:clearRecovery();pcall(self.restoreView,self,self.camera,saved)
   else self:watchRetired(self.camera,self.appliedPose or self.pose,saved)end
  end
 end
 self.player:SetAttribute('SpyCaseCinematicActive',false)
 if notify and self.options.onStop then self.options.onStop()end
end
function Scene:destroy()self:stop(false);self:clearRecovery()end
return Scene
