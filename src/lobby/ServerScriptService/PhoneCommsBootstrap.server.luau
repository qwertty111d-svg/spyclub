local root=game:GetService('ServerStorage'):WaitForChild('SpyModules',8)
local m=root and root:WaitForChild('PhoneCommsService',8)
if m then local ok,err=pcall(function()return require(m).start()end);if not ok then warn('[SpyPhoneComms] '..tostring(err))end end
