-- Independent coordinator: no module requires, profile, chat or admin dependencies.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local start=os.clock()
local stateSeen=false
local stateConnection
local loadingNames={ClubLoading=true,SpyLoading=true,SpyClubLoading=true}
local watchedGui
local function watchGui(pg)
 if watchedGui==pg then return end
 watchedGui=pg
 pg.ChildAdded:Connect(function(gui)
  if loadingNames[gui.Name] and player:GetAttribute("SpyLoadingReleased")==true then gui:Destroy() end
 end)
 if player:GetAttribute("SpyLoadingReleased")==true then
  for _,gui in ipairs(pg:GetChildren()) do if loadingNames[gui.Name] then gui:Destroy() end end
 end
end
player.ChildAdded:Connect(function(child)
 if child:IsA("PlayerGui") then watchGui(child) end
end)
local existingGui=player:FindFirstChildOfClass("PlayerGui")
if existingGui then watchGui(existingGui) end
local function attachState(remote)
 if stateConnection or not remote:IsA("RemoteEvent") then return end
 stateConnection=remote.OnClientEvent:Connect(function(snapshot)
  if type(snapshot)=="table" then stateSeen=true;player:SetAttribute("SpyStateReceived",true) end
 end)
end
local function removeLoading()
 local pg=player:FindFirstChildOfClass("PlayerGui")
 if pg then
  watchGui(pg)
  for _,name in ipairs({"ClubLoading","SpyLoading","SpyClubLoading"}) do
   local gui=pg:FindFirstChild(name);if gui then gui:Destroy() end
  end
 end
 game:GetService("ReplicatedFirst"):RemoveDefaultLoadingScreen()
 player:SetAttribute("SpyLoadingReleased",true)
end
-- Hard deadline fires even if the game client errors, never sets ProfileReady.
task.delay(25,function()
 if player:GetAttribute("SpyClientReady")~=true then player:SetAttribute("SpyBootDegraded",true) end
 removeLoading()
end)
task.spawn(function()
 for attempt=1,30 do
  local shared=Storage:FindFirstChild("SpyShared")
  local remote=shared and shared:FindFirstChild("State")
  local action=shared and shared:FindFirstChild("Action")
  if remote then attachState(remote) end
  if action and action:IsA("RemoteEvent") and (not stateSeen or attempt%5==0) then action:FireServer("Sync") end
  if stateSeen and player.Character and player:FindFirstChildOfClass("PlayerGui") then
   player:SetAttribute("SpyCoreReady",true)
   if player:GetAttribute("SpyClientReady")==true then removeLoading();break end
  end
  task.wait(math.min(3,.5+attempt*.12))
 end
end)
player:GetAttributeChangedSignal("SpyClientReady"):Connect(function()
 if player:GetAttribute("SpyClientReady")==true then removeLoading() end
end)
