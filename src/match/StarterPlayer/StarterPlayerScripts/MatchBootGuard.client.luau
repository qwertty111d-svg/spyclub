-- Independent Match watchdog. Does not skip gameplay or mark a client ready.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local deadline=os.clock()+35
local pg=player:WaitForChild("PlayerGui",10)
if not pg then return end
local ready=false
local connection
local function restoreCamera()
 local camera=workspace.CurrentCamera
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if camera and humanoid then camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=humanoid end
end
task.spawn(function()
 while os.clock()<deadline do
  local remotes=Storage:FindFirstChild("MatchRemotes")
  local state=remotes and remotes:FindFirstChild("State")
  if state and not connection then
   connection=state.OnClientEvent:Connect(function(snapshot)
    if type(snapshot)=="table" and snapshot.phase and snapshot.phase~="Waiting" then ready=true end
   end)
  end
  if ready and player:GetAttribute("SpyMatchUIInitialized")==true then break end
  task.wait(.25)
 end
 if connection then connection:Disconnect() end
 local session=Storage:FindFirstChild("MatchSession")
 local phase=session and session:GetAttribute("RoundPhase")
 if (ready or (phase and phase~="Waiting")) and player:GetAttribute("SpyMatchUIInitialized")==true then return end
 local connecting=pg:FindFirstChild("SpyMatchConnecting")
 if connecting then connecting:Destroy() end
 -- Keep the main UI/result panels: only remove an opaque loading overlay.
 for _,gui in ipairs(pg:GetChildren()) do
  if gui:IsA("ScreenGui") and (gui.Name=="MatchUI" or gui.Name=="SpyMatchConnecting") then
   for _,node in ipairs(gui:GetDescendants()) do
    if node:IsA("GuiObject") and (node.Name=="Blackout" or node.Name=="ArrivalBriefing") then node.Visible=false end
   end
  end
 end
 restoreCamera()
 player:SetAttribute("SpyMatchBootDegraded",true)
 local screen=Instance.new("ScreenGui");screen.Name="SpyMatchRecovery";screen.DisplayOrder=900;screen.ResetOnSpawn=false;screen.Parent=pg
 local card=Instance.new("TextButton");card.Size=UDim2.new(.8,0,0,70);card.AnchorPoint=Vector2.new(.5,0);card.Position=UDim2.fromScale(.5,.10)
 card.BackgroundColor3=Color3.fromRGB(25,21,25);card.TextColor3=Color3.fromRGB(230,199,150);card.Font=Enum.Font.GothamBold;card.TextSize=15;card.TextWrapped=true
 card.Text="Матч не загрузился. Вернуться в лобби";card.Parent=screen
 Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
 card.Activated:Connect(function()
  local remotes=Storage:FindFirstChild("MatchRemotes");local back=remotes and remotes:FindFirstChild("ReturnLobby")
  if back then back:FireServer() else
   pcall(function() game:GetService("TeleportService"):Teleport(93859909286393,player) end)
  end
 end)
 player:GetAttributeChangedSignal("SpyMatchUIInitialized"):Connect(function()
  if player:GetAttribute("SpyMatchUIInitialized")==true then screen:Destroy() end
 end)
end)
