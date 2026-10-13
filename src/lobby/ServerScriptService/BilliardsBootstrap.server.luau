-- Optional lobby feature: failure cannot stop Spy Club boot or the main game.
local Storage=game:GetService("ServerStorage")
task.spawn(function()
    local ok,err=pcall(function()
        local modules=Storage:WaitForChild("SpyModules",10)
        if not modules then error("billiards_modules_missing") end
        local module=modules:WaitForChild("BilliardsService",5)
        local root=workspace:WaitForChild("SpyClub",15)
        if not module or not root then error("billiards_world_missing") end
        -- Wait finitely for core geometry, which may remove saved decorative groups.
        local started=os.clock()
        while root:GetAttribute("WorldReady")~=true and os.clock()-started<15 do task.wait(.2) end
        require(module).start(root)
    end)
    if not ok then warn("[SPY BILLIARDS] optional startup failed: "..tostring(err)) end
end)
