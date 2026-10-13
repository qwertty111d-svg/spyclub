local player=game:GetService('Players').LocalPlayer
local pg=player:WaitForChild('PlayerGui',8)
local shared=game:GetService('ReplicatedStorage'):WaitForChild('SpyShared',8)
local m=shared and shared:WaitForChild('Presentation',8)
if not pg or not m then return end
local ok,service=pcall(function()return require(m).start(pg,player)end)
if ok and service then script.Destroying:Connect(function()service:destroy()end)else warn('[SpyPresentation] '..tostring(service))end
