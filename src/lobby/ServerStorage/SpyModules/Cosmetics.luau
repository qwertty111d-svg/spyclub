-- Server-authoritative wardrobe. Reuses Inventory ownership and existing profiles.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("SpyShared")
local Catalog=require(Shared.Catalog)
local Wardrobe=require(Shared.Wardrobe)
local Inventory=require(script.Parent.Inventory)
local Cosmetics={}
local states=setmetatable({}, {__mode="k"})
Wardrobe.bootstrap()
local ATTRIBUTE_BY_SLOT={
    title="SpyTitle",frame="SpyFrame",effect="SpyEffect",outfit="SpyEquippedOutfit",
    hat="SpyEquippedHat",glasses="SpyEquippedGlasses",tie="SpyEquippedTie",
    hair="SpyEquippedHair",gloves="SpyEquippedGloves",shoulder="SpyEquippedShoulder",card="SpyEquippedCard",
    trinket="SpyEquippedTrinket",accessory="SpyEquippedAccessory",emote="SpyEquippedEmote",
}
local function signature(equipped)
    local values={}
    for _,slot in ipairs({"outfit","hat","hair","accessory","glasses","tie","gloves","shoulder","card","trinket","effect"}) do
        values[#values+1]=equipped[slot] or ""
    end
    return table.concat(values,"|")
end
function Cosmetics.clear(character)
    Wardrobe.clear(character)
    states[character]=nil
end
-- Check assets BEFORE saving equipment. A missing model cannot become a false
-- 'equipped' success or remove the outfit currently visible on the player.
function Cosmetics.canEquip(player,profile,itemId)
    if not profile or not profile.ready then return false,"profile_unavailable" end
    if not player.Character or not player.Character:GetAttribute("SpyBaseReady") then
        return false,"appearanceLoading"
    end
    local proposed=table.clone(profile)
    proposed.equipped=table.clone(profile.equipped or {})
    local result=Inventory.equip(proposed,itemId,Catalog)
    if not result.ok then return false,result.code end
    local slot=result.slot or "trinket"
    local ok=Wardrobe.prepare(proposed.equipped,10,slot)
    if not ok or not player.Character then return false,"appearanceLoading" end
    local valid=Wardrobe.validate(player.Character,proposed.equipped,slot)
    if not valid then return false,"appearanceLoading" end
    return true
end
function Cosmetics.apply(player,profile,_,forceRebuild)
    local character=player and player.Character
    if not character or not character:GetAttribute("SpyBaseReady") or not profile or not profile.ready then return false end
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health<=0 then return false end
    local state=states[character]
    if not state then state={generation=0,retries=0};states[character]=state end
    local equipped=table.clone(profile.equipped or {})
    state.latest=profile
    for slot,attribute in pairs(ATTRIBUTE_BY_SLOT) do player:SetAttribute(attribute,equipped[slot] or "") end
    local wanted=signature(equipped)
    if not forceRebuild and state.signature==wanted then return true end
    state.generation+=1
    local generation=state.generation
    local ready,reason=Wardrobe.prepare(equipped,12)
    if state.generation~=generation or player.Character~=character or not character.Parent then return false end
    local ok,result=pcall(ready and Wardrobe.render or Wardrobe.renderAvailable,character,equipped)
    if not ready then ok=false;result=reason end
    if not ok or result~=true then
        character:SetAttribute("SpyCosmeticsReady",false)
        character:SetAttribute("SpyCosmeticsLastError",tostring(result))
        state.signature=nil
        if state.retries<6 then
            state.retries+=1
            task.delay(({5,10,20,30,45,60})[state.retries],function()
                if player.Character==character and states[character]==state then Cosmetics.apply(player,state.latest) end
            end)
        end
        warn("[SpyWardrobe] "..player.Name..": "..tostring(result))
        return false
    end
    state.signature=wanted;state.retries=0
    character:SetAttribute("SpyCosmeticsReady",true)
    character:SetAttribute("SpyCosmeticsLastError",nil)
    player:SetAttribute("SpyAppearanceRevision",(player:GetAttribute("SpyAppearanceRevision") or 0)+1)
    return true
end
function Cosmetics.emote(player,profile)
    if not profile or not profile.ready or (profile.equipped or {}).emote~="wave" then return false end
    local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health<=0 then return false end
    local animator=humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    return pcall(function()
        local animation=Instance.new("Animation")
        animation.AnimationId="rbxassetid://507770239"
        local track=animator:LoadAnimation(animation);animation:Destroy()
        track.Priority=Enum.AnimationPriority.Action;track.Looped=false;track:Play(.2)
        track.Stopped:Once(function() track:Destroy() end)
    end)
end
return Cosmetics
