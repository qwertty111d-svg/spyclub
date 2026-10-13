-- Optional phone service cannot gate the place boot.
local root=game:GetService('ServerStorage'):WaitForChild('SpyModules',8)
local module=root and root:WaitForChild('PhoneService',8)
if module then local ok,err=pcall(function()require(module).start()end);if not ok then warn('[SpyPhone] '..tostring(err))end end
