-- Atelier reuses the authored briefcase meshes and the same podium as its neighbours.
-- No external model loading is needed for the display or game boot.
local Storage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local function find(name)
 local item=workspace:FindFirstChild(name,true)
 return item and item:IsA("Model") and item or nil
end
local deadline=os.clock()+20
local silver,gold,classic,club
repeat
 silver=find("SilverCase");gold=find("GoldCase");classic=find("ClassicCase");club=workspace:FindFirstChild("SpyClub")
 if silver and gold and classic and club then break end
 task.wait(.2)
until os.clock()>=deadline
if not silver or not gold or not classic or not club or club:FindFirstChild("AtelierDisplay") then return end
local sourceCF,sourceSize=silver:GetBoundingBox()
local sourceBottom=sourceCF.Position.Y-sourceSize.Y*.5
local floor=club:FindFirstChild("SafetyFloor")
local ground=floor and floor.Position.Y+floor.Size.Y*.5 or 0
local podium,score
for _,model in ipairs(workspace:GetChildren()) do
 if model:IsA("Model") and model~=club and model~=silver and model~=gold and not model.Name:find("Case",1,true) then
  for _,item in ipairs(model:GetDescendants()) do
   if item:IsA("BasePart") and item.Position.Y>ground+.25 and item.Position.Y<sourceBottom then
    local delta=item.Position-sourceCF.Position
    local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
    if distance<1.5 and (not score or distance<score) then podium=model;score=distance end
   end
  end
 end
end
if not podium then warn("[Atelier] Authored podium unavailable") return end
local delta=gold:GetPivot().Position-silver:GetPivot().Position
local direction=Vector3.new(delta.X,0,delta.Z)
if direction.Magnitude<.5 then direction=Vector3.new(0,0,8) end
-- The authored row is on the east wall. Put the entry-priced case before
-- Classic, on the clear floor between its stand and the corner plant.
-- Classic has legacy geometry below the floor, so use its actual prompt.
local classicPrompt=classic:FindFirstChild("CasePrompt",true)
local firstPosition=classicPrompt and classicPrompt.Parent and classicPrompt.Parent:IsA("BasePart") and classicPrompt.Parent.Position or classic:GetPivot().Position
local location=firstPosition-direction.Unit*math.max(6,direction.Magnitude)
local shift=Vector3.new(location.X-silver:GetPivot().Position.X,0,location.Z-silver:GetPivot().Position.Z)
local function sanitize(root,collide)
 for _,item in ipairs(root:GetDescendants()) do
  if item:IsA("LuaSourceContainer") or item:IsA("ProximityPrompt") or item:IsA("ClickDetector") or item:IsA("LayerCollector") or item:IsA("JointInstance") or item:IsA("Constraint") or item:IsA("Sound") or item:IsA("Light") then
   item:Destroy()
  elseif item:IsA("BasePart") then
   item.Anchored=true;item.CanCollide=collide;item.CanTouch=false;item.CanQuery=collide
  end
 end
end
local display=Instance.new("Model");display.Name="AtelierDisplay"
local pedestal=Instance.new("Model");pedestal.Name="Pedestal";pedestal.Parent=display
-- Only visible stand geometry is copied; old parts buried under the floor stay behind.
for _,item in ipairs(podium:GetDescendants()) do
 if item:IsA("BasePart") then
  local relative=item.Position-sourceCF.Position
  if item.Position.Y>=ground-.05 and item.Position.Y<sourceBottom and Vector3.new(relative.X,0,relative.Z).Magnitude<3 then
   local copy=item:Clone();sanitize(copy,true)
   copy.Anchored=true;copy.CanCollide=true;copy.CanTouch=false;copy.CanQuery=true
   copy.CFrame=item.CFrame+shift;copy.Parent=pedestal
  end
 end
end
local case=silver:Clone();case.Name="AtelierCase"
sanitize(case,false)
case:SetAttribute("CaseId","atelier");case:SetAttribute("SpinSpeed",12);case:SetAttribute("FloatAmplitude",.09)
case:SetAttribute("GeometrySource","SilverCase · 9316100277 / 9316100454")
for _,item in ipairs(case:GetDescendants()) do
 if item:IsA("BasePart") then
  item.CFrame=item.CFrame+shift
  -- Warm saddle finish and a muted brass handle; no noisy fabric texture.
  item.Material=Enum.Material.SmoothPlastic
  item.Color=item.Name:find(".001",1,true) and Color3.fromRGB(186,161,114) or Color3.fromRGB(116,75,62)
 end
end
local origin=sourceCF+shift
local function anchor(name,cf,parent)
 local item=Instance.new("Part");item.Name=name;item.Size=Vector3.new(.1,.1,.1);item.CFrame=cf
 item.Transparency=1;item.Anchored=true;item.CanCollide=false;item.CanTouch=false;item.CanQuery=false;item.Parent=parent;return item
end
case.PrimaryPart=anchor("Pivot",origin,case);case.Parent=display
display.Parent=club
-- Interaction remains fixed on the stand while the mesh case turns above it.
local promptAnchor=anchor("AtelierPromptAnchor",origin,display)
local prompt=Instance.new("ProximityPrompt")
local shared=Storage:WaitForChild("SpyShared",10)
local catalogModule=shared and shared:FindFirstChild("Catalog")
local ok,catalog=pcall(function()return catalogModule and require(catalogModule)end)
local price=ok and catalog and catalog.Cases and catalog.Cases.atelier and catalog.Cases.atelier.price or 150
prompt.Name="CasePrompt";prompt.ActionText="ВНЕШНОСТЬ";prompt.ObjectText="АТЕЛЬЕ · ПРИЧЁСКИ · ROLLS"
prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.MaxActivationDistance=8;prompt.RequiresLineOfSight=false
prompt.HoldDuration=0;prompt.Style=Enum.ProximityPromptStyle.Custom
prompt:SetAttribute("CaseId","atelier");prompt:SetAttribute("ActionKey","inspect");prompt.Parent=promptAnchor
local last={}
prompt.Triggered:Connect(function(player)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root or (root.Position-promptAnchor.Position).Magnitude>11 or os.clock()-(last[player.UserId] or -100)<.5 then return end
 last[player.UserId]=os.clock()
 local shared=Storage:FindFirstChild("SpyShared");local notice=shared and shared:FindFirstChild("Notice")
 if notice then notice:FireClient(player,{key="openPanel",panel="accessoryRoll",category="hair"}) end
end)
Players.PlayerRemoving:Connect(function(player)last[player.UserId]=nil end)
