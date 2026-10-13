-- One custom frontend, one Roblox TextChannel transport.
-- Core configuration is not proof that the engine created a usable input bar.
local TextChatService=game:GetService("TextChatService")
local StarterGui=game:GetService("StarterGui")
local player=game:GetService("Players").LocalPlayer
local inMatch=true -- Place builder replaces this marker for Match.
if not player then return end
player:SetAttribute("SpyNativeChatReady",false)
local observed=setmetatable({},{__mode="k"})
local applying=false
local function suppress(instance)
 if applying then return end
 if not instance:IsA("ChatWindowConfiguration") and not instance:IsA("ChatInputBarConfiguration")
  and not instance:IsA("ChannelTabsConfiguration") then return end
 applying=true
 pcall(function()instance.Enabled=false end)
 applying=false
 if not observed[instance] then
  observed[instance]=true
  instance:GetPropertyChangedSignal("Enabled"):Connect(function()suppress(instance)end)
 end
end
TextChatService.ChildAdded:Connect(suppress)
for _,child in ipairs(TextChatService:GetChildren())do suppress(child)end
local function hideCore(attempt)
 local ok=pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,false)end)
 if not ok and attempt<5 then task.delay(.25*2^(attempt-1),function()hideCore(attempt+1)end)end
end
hideCore(1)
