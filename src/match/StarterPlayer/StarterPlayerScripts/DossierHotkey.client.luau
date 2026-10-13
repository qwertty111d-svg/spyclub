-- H toggles the same character menu as the visible dock/menu button.
local Players=game:GetService("Players")
local Input=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("SpyShared")
local Policy=require(Shared:WaitForChild("DossierPolicy"))
local player=Players.LocalPlayer
local parent=player:WaitForChild("PlayerGui")
local event=parent:FindFirstChild("SpyOpenDossier") or Instance.new("BindableEvent")
event.Name="SpyOpenDossier";event.Parent=parent
local function flags()
    return {
        teleporting=player:GetAttribute("SpyTeleporting")==true or player:GetAttribute("SpyReconnectBusy")==true,
        cinematic=player:GetAttribute("SpyEntryActive")==true or player:GetAttribute("SpyEntryPending")==true
            or player:GetAttribute("SpyMatchIntroActive")==true or player:GetAttribute("SpyCaseCinematicActive")==true,
        phone=player:GetAttribute("SpyPhoneActive")==true,
        trade=player:GetAttribute("SpyTradeOpen")==true,
        minigame=player:GetAttribute("SpyBilliardsPlaying")==true or player:GetAttribute("SpyCheckersPlaying")==true,
    }
end
local connection=Input.InputBegan:Connect(function(input,processed)
    if input.KeyCode==Enum.KeyCode.H and Policy.hotkey(processed,Input:GetFocusedTextBox()~=nil,flags()) then
        event:Fire()
    elseif (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB)
        and player:GetAttribute("SpyCharacterMenuOpen")==true and Input:GetFocusedTextBox()==nil then
        event:Fire("close")
    end
end)
script.Destroying:Connect(function()connection:Disconnect()end)
