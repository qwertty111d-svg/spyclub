local Lighting=game:GetService("Lighting")
local TweenService=game:GetService("TweenService")
local UIEffects={}
local owners=setmetatable({}, {__mode="k"})
local blur=Lighting:FindFirstChild("SpyClubUIBlur")
if not blur then
    blur=Instance.new("BlurEffect")
    blur.Name="SpyClubUIBlur"
    blur.Size=0
    blur.Enabled=true
    blur.Parent=Lighting
end
local tween
local function update()
    local target=0
    for _,amount in pairs(owners) do target=math.max(target,amount or 14) end
    if tween then tween:Cancel() end
    tween=TweenService:Create(blur,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=target})
    tween:Play()
end
function UIEffects.pushBlur(owner,amount)
    if not owner then return end
    owners[owner]=amount or 14
    update()
end
function UIEffects.popBlur(owner)
    if not owner then return end
    owners[owner]=nil
    update()
end
function UIEffects.clearBlur()
    table.clear(owners)
    update()
end
return UIEffects
