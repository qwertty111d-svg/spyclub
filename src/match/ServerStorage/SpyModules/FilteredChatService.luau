-- Compatibility entry point for older place scripts. User chat must use
-- TextChannel:SendAsync so Roblox owns filtering, privacy, and reporting.
-- Never recreate the retired RemoteEvent/GetChatForUserAsync experiment.
local Service={}
function Service.start(_inMatch)
 game:GetService("ReplicatedStorage"):SetAttribute("SpyChatTransport","text_channel")
 return nil
end
return Service
