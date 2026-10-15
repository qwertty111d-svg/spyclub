local player=game:GetService('Players').LocalPlayer
local pg=player:WaitForChild('PlayerGui',8)
local shared=game:GetService('ReplicatedStorage'):WaitForChild('SpyShared',8)
local m=shared and shared:WaitForChild('Presentation',8)
if not pg or not m then return end
local ok,service=pcall(function()return require(m).start(pg,player)end)
if ok and service then script.Destroying:Connect(function()service:destroy()end)else warn('[SpyPresentation] '..tostring(service))end

-- Optional feedback owns button audio and motion without delaying presentation.
local feedback,feedbackDestroyed
script.Destroying:Connect(function()
 feedbackDestroyed=true
 if feedback then feedback:destroy();feedback=nil end
end)
task.spawn(function()
 local feedbackOK,result=pcall(function()
  local module=shared:WaitForChild('UIFeedback',8)
  if feedbackDestroyed or not module then return nil end
  return require(module).start(pg,player)
 end)
 if not feedbackOK then warn('[SpyUIFeedback] '..tostring(result))
 elseif result then
  if feedbackDestroyed then result:destroy()else feedback=result end
 end
end)
