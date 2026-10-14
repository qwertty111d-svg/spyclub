local shared=game:GetService("ReplicatedStorage"):WaitForChild("SpyShared")
local player=game:GetService("Players").LocalPlayer
local preferences=require(shared:WaitForChild("ClientPreferences"))
preferences.start()
local controller=require(shared:WaitForChild("ClubMusicPlaylist")).start(player,{mode="match"})
script.Destroying:Connect(function()controller:Destroy()end)
