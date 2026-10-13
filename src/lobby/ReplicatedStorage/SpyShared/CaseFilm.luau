-- Finite camera sequence in the actual club. Reuses the verified camera/control lease.
local Film={}
function Film.new(parent,language,onEnd)
 local shared=game:GetService('ReplicatedStorage').SpyShared
 local Lease=require(shared.CaseScene);local Timeline=require(shared.FilmTimeline);local Stage=require(shared.FilmStage);local UI=require(shared.PhoneUI)
 local self={active=false,generation=0}
 local gui=Instance.new('ScreenGui');gui.Name='SpyCaseFilmUI';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=415;gui.Enabled=false;gui.Parent=parent
 pcall(function()gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
 local caption=Instance.new('TextLabel');caption.Name='SceneTitle';caption.AnchorPoint=Vector2.new(.5,1);caption.Position=UDim2.new(.5,0,1,-24);caption.Size=UDim2.new(1,-40,0,52);caption.BackgroundTransparency=1;caption.TextColor3=Color3.fromRGB(242,239,226);caption.Font=Enum.Font.BuilderSansBold;caption.TextSize=24;caption.TextWrapped=true;caption.RichText=false;caption.TextStrokeTransparency=.65;caption.Parent=gui
 local skip=Instance.new('TextButton');skip.AnchorPoint=Vector2.new(1,0);skip.Position=UDim2.new(1,-18,0,18);skip.Size=UDim2.fromOffset(126,44);skip.BackgroundColor3=Color3.fromRGB(24,30,30);skip.TextColor3=caption.TextColor3;skip.Font=Enum.Font.BuilderSansMedium;skip.TextSize=16;skip.BorderSizePixel=0;skip.Parent=gui
 local lease
 local function finish()
  if not self.active then return end
  self.active=false;self.generation+=1;gui.Enabled=false
  if self.stage then self.stage:destroy();self.stage=nil end
  for part,value in pairs(self.evidenceLease or{})do if part.Parent and part.LocalTransparencyModifier==1 then part.LocalTransparencyModifier=value end end;self.evidenceLease=nil
  if onEnd then onEnd()end
 end
 lease=Lease.new({onStop=finish});local oldHold=lease.hold
 function lease:frame()
  if not self.filmStage then return nil end
  local q=Timeline.sample(self.fileId,self.elapsed or 0,self.filmStage.variant);if not q then return nil end
  local function v(a)return Vector3.new(a[1],a[2],a[3])end
  local eye=self.filmStage.base:PointToWorldSpace(v(q.eye));local target=self.filmStage.base:PointToWorldSpace(v(q.target))
  local cam=workspace.CurrentCamera
  if cam.ViewportSize.X<cam.ViewportSize.Y then eye=target+(eye-target)*1.3 end
  local frame=CFrame.lookAt(eye,target)
  if self.shot~=q.shot then self.pose=frame;self.shot=q.shot end
  return frame,CFrame.new(target)
 end
 function lease:hold(dt)
  self.elapsed=(self.elapsed or 0)+math.min(dt or 0,.1)
  local q=Timeline.sample(self.fileId,self.elapsed,self.filmStage.variant)
  if not q or q.done then self:stop(true);return end
  if self.filmStage then self.filmStage:apply(q,self.elapsed)end
  oldHold(self,dt)
 end
 function self:start(id,title)
  self:stop();if not lease:canStart()then return false end
  local ok,stage=pcall(Stage.new,id);if not ok or not stage then return false end
  self.stage=stage;lease.filmStage=stage;lease.fileId=id;lease.elapsed=0;lease.shot=nil
  self.active=true;self.generation+=1;local generation=self.generation
  self.evidenceLease={};local club=workspace:FindFirstChild('SpyClub');local props=club and club:FindFirstChild('SpyPhoneEvidenceSet')
  if props then for _,part in ipairs(props:GetDescendants())do if part:IsA('BasePart')then self.evidenceLease[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1 end end end
  caption.Text=title;skip.Text=UI.text(language(),'skip');gui.Enabled=true
  if not lease:start()then finish();return false end
  task.delay(Timeline.Duration+2,function()if self.active and self.generation==generation then self:stop()end end)
  return true
 end
 function self:stop()if lease.active then lease:stop(true)else finish()end end
 function self:destroy()self:stop();lease:destroy();gui:Destroy()end
 skip.Activated:Connect(function()self:stop()end)
 self.lease=lease;self.gui=gui;return self
end
return Film
