-- SPY CLUB / deterministic dressed R15 spawn.
local Players=game:GetService("Players")
local Wardrobe=require(game:GetService("ReplicatedStorage"):WaitForChild("SpyShared"):WaitForChild("Wardrobe"))
local CharacterService={BASE_VERSION=23}
Wardrobe.bootstrap()
function CharacterService.createDescription(equipped)
    return Wardrobe.description(equipped)
end
function CharacterService.ensureFace(character)
    return Wardrobe.face(character)
end
local function loadDescription(player,character,callback)
    local description=CharacterService.createDescription()
    local ok,result=pcall(callback,description)
    if not ok and player.Character==character then
        -- One unavailable hair asset must not reject the shirt and trousers.
        -- The shared wardrobe renderer will retry the hair/accessories later.
        description.HairAccessory=""
        ok,result=pcall(callback,description)
    end
    description:Destroy()
    return ok,result
end
function CharacterService.apply(player,character)
    if player.Character~=character then return false,"character_changed" end
    local humanoid=character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid",10)
    if not humanoid then return false,"missing_humanoid" end
    if humanoid.RigType~=Enum.HumanoidRigType.R15 then
        local ok,replacement=loadDescription(player,character,function(description)
            return Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
        end)
        if not ok then
            character:SetAttribute("SpyAppearanceError",tostring(replacement))
            return false,"r15_create_failed"
        end
        if player.Character~=character then replacement:Destroy();return false,"character_changed" end
        replacement.Name=player.Name;replacement:PivotTo(character:GetPivot())
        replacement:SetAttribute("SpySpawnAppearanceReady",true)
        replacement.Parent=workspace;player.Character=replacement;character:Destroy()
        return false,"character_replaced"
    end
    if character:GetAttribute("SpyBaseVersion")==CharacterService.BASE_VERSION then return true end
    -- An existing R15 body is usable immediately. Never reset a seated live
    -- character through a yielding catalog request: late resets also strip the
    -- selected profile skin. Asset recovery belongs to the independent wardrobe.
    Wardrobe.renderAvailable(character,{})
    if player.Character~=character then return false,"character_changed" end
    local shirt=character:FindFirstChildOfClass("Shirt")
    local pants=character:FindFirstChildOfClass("Pants")
    if not shirt or shirt.ShirtTemplate=="" or not pants or pants.PantsTemplate=="" then
        character:SetAttribute("SpyAppearanceError","base_clothing_missing")
        character:SetAttribute("SpyAppearanceDegraded",true)
    end
    if character:GetAttribute("SpySpawnAppearanceReady") and shirt and shirt.ShirtTemplate~="" and pants and pants.PantsTemplate~="" then
        Wardrobe.captureClothing(character,{})
    end
    Wardrobe.ensureDressed(character)
    Wardrobe.face(character)
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator",humanoid) end
    for _,name in ipairs({"SpyHouseUniform","SpyHouseHair"}) do
        local old=character:FindFirstChild(name)
        if old then old:Destroy() end
    end
    character:SetAttribute("SpyBaseVersion",CharacterService.BASE_VERSION)
    if not character:GetAttribute("SpyAppearanceDegraded") then character:SetAttribute("SpyAppearanceError",nil) end
    character:SetAttribute("SpyBaseReady",true)
    return true
end
return CharacterService
