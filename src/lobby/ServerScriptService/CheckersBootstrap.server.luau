-- Optional recreation never participates in core loading readiness.
task.spawn(function()
 local ok,err=pcall(function()
  local modules=game:GetService("ServerStorage"):WaitForChild("SpyModules",10)
  local service=modules and modules:WaitForChild("CheckersService",5)
  local root=workspace:WaitForChild("SpyClub",15)
  if not service or not root then return end
  local deadline=os.clock()+20;local group
  repeat
   local archive=root:FindFirstChild("ClubArchive");group=archive and archive:FindFirstChild("CafeGroup3")
   if not group then task.wait(.2)end
  until group or os.clock()>=deadline
  if group then require(service).start(group)end
 end)
 if not ok then warn("[SpyCheckers] optional startup failed: "..tostring(err))end
end)
