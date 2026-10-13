-- Server-owned SPY CLUB wearables. Appearance never affects match rules.
local AssetService=game:GetService("AssetService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage:WaitForChild("SpyShared"):WaitForChild("Catalog"))

local Cosmetics={}
local states=setmetatable({}, {__mode="k"})
local assetCache={}
local builders={}
local MAX_EFFECT_RATE=3
local LEGACY_TUX_SHIRT=6952255153
local LEGACY_TUX_PANTS=6952255997

local BLACK=Color3.fromRGB(18,19,22)
local CHARCOAL=Color3.fromRGB(31,32,36)
local CREAM=Color3.fromRGB(226,215,194)
local BRASS=Color3.fromRGB(190,145,73)

local function rgb(value,fallback)
    if type(value)=="table" and #value>=3 then
        return Color3.fromRGB(value[1],value[2],value[3])
    end
    return fallback
end

local function mark(instance)
    instance:SetAttribute("SpyCosmetic",true)
    return instance
end

function Cosmetics.clear(character)
    if not character then return end
    local targets={}
    for _,instance in ipairs(character:GetDescendants()) do
        if instance:GetAttribute("SpyCosmetic") then targets[#targets+1]=instance end
    end
    for index=#targets,1,-1 do
        local instance=targets[index]
        if instance.Parent then instance:Destroy() end
    end
end

local function safePart(parent,name,size,color,material,shape)
    local part=Instance.new("Part")
    part.Name=name; part.Size=size; part.Color=color
    part.Material=material or Enum.Material.SmoothPlastic
    part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
    part.Massless=true; part.CastShadow=true
    part.TopSurface=Enum.SurfaceType.Smooth; part.BottomSurface=Enum.SurfaceType.Smooth
    if shape then part.Shape=shape end
    part.Parent=parent
    return part
end

local function weld(root,part,offset)
    part.CFrame=root.CFrame*offset
    local constraint=Instance.new("WeldConstraint")
    constraint.Part0=root; constraint.Part1=part; constraint.Parent=part
end

local function piece(container,root,name,size,offset,color,material,shape)
    local part=safePart(container,name,size,color,material,shape)
    weld(root,part,offset)
    return part
end

local function attachManual(character,accessory,bodyPart,offset)
    local handle=accessory:FindFirstChild("Handle")
    if not handle or not bodyPart then accessory:Destroy() return false end
    accessory.Parent=character
    handle.CFrame=bodyPart.CFrame*offset
    local joint=Instance.new("Weld")
    joint.Name="AccessoryWeld"; joint.Part0=bodyPart; joint.Part1=handle; joint.C0=offset; joint.Parent=handle
    return true
end

local function attachAccessory(character,humanoid,accessory,bodyPart,offset)
    mark(accessory)
    local ok=pcall(function() humanoid:AddAccessory(accessory) end)
    local handle=accessory:FindFirstChild("Handle")
    if ok and accessory.Parent==character and handle and handle:FindFirstChild("AccessoryWeld") then return true end
    if accessory.Parent then accessory.Parent=nil end
    return attachManual(character,accessory,bodyPart,offset)
end

local function headAccessory(name,attachmentName,attachmentCFrame)
    local accessory=Instance.new("Accessory"); accessory.Name="SpyCosmetic_"..name
    local handle=safePart(accessory,"Handle",Vector3.new(.18,.18,.18),BLACK); handle.Transparency=1
    local attachment=Instance.new("Attachment")
    attachment.Name=attachmentName; attachment.CFrame=attachmentCFrame or CFrame.new(); attachment.Parent=handle
    return accessory,handle
end

local function sanitize(container)
    for _,instance in ipairs(container:GetDescendants()) do
        if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
            or instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
            instance:Destroy()
        elseif instance:IsA("BasePart") then
            instance.CanCollide=false; instance.CanTouch=false; instance.CanQuery=false; instance.Massless=true
        end
    end
end

local function loadExternalAccessory(assetId)
    if type(assetId)~="number" or assetId<=0 then return nil end
    if assetCache[assetId] then return assetCache[assetId]:Clone() end
    local ok,container=pcall(function() return AssetService:LoadAssetAsync(assetId) end)
    if not ok or not container then return nil end
    sanitize(container)
    local accessory=container:FindFirstChildWhichIsA("Accessory",true)
    if not accessory then container:Destroy() return nil end
    accessory.Parent=nil; container:Destroy()
    assetCache[assetId]=accessory:Clone()
    return accessory
end

local function body(character)
    return {
        head=character:FindFirstChild("Head"),
        torso=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
        left=character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"),
        right=character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"),
        root=character:FindFirstChild("HumanoidRootPart"),
    }
end

builders.fedora=function(character,humanoid,item)
    local parts=body(character); if not parts.head then return false end
    local accent=rgb(item.color,Color3.fromRGB(78,98,130))
    local accessory,handle=headAccessory("Fedora_"..item.id,"HatAttachment",CFrame.new(0,-.16,0))
    piece(accessory,handle,"Brim",Vector3.new(.14,2.72,2.38),CFrame.new(0,.08,0)*CFrame.Angles(0,0,math.rad(90)),BLACK,Enum.Material.Fabric,Enum.PartType.Cylinder)
    piece(accessory,handle,"Crown",Vector3.new(1.08,1.67,1.48),CFrame.new(0,.62,0)*CFrame.Angles(0,0,math.rad(90)),CHARCOAL,Enum.Material.Fabric,Enum.PartType.Cylinder)
    piece(accessory,handle,"Band",Vector3.new(.20,1.76,1.57),CFrame.new(0,.31,0)*CFrame.Angles(0,0,math.rad(90)),accent,Enum.Material.Fabric,Enum.PartType.Cylinder)
    piece(accessory,handle,"Pin",Vector3.new(.12,.24,.06),CFrame.new(.72,.32,-.72),BRASS,Enum.Material.Metal)
    return attachAccessory(character,humanoid,accessory,parts.head,CFrame.new(0,parts.head.Size.Y*.68,0))
end

builders.tophat=function(character,humanoid,item)
    local parts=body(character); if not parts.head then return false end
    local external=loadExternalAccessory(item.wearable and item.wearable.assetId)
    if external then
        external.Name="SpyCosmetic_Tophat_"..item.id; sanitize(external)
        if attachAccessory(character,humanoid,external,parts.head,CFrame.new(0,parts.head.Size.Y*.72,0)) then return true end
    end
    local accent=rgb(item.color,Color3.fromRGB(144,90,190))
    local fallback,handle=headAccessory("Tophat_"..item.id,"HatAttachment",CFrame.new(0,-.12,0))
    piece(fallback,handle,"Brim",Vector3.new(.14,2.82,2.55),CFrame.new(0,.06,0)*CFrame.Angles(0,0,math.rad(90)),BLACK,Enum.Material.Fabric,Enum.PartType.Cylinder)
    piece(fallback,handle,"Crown",Vector3.new(1.62,1.78,1.68),CFrame.new(0,.91,0)*CFrame.Angles(0,0,math.rad(90)),CHARCOAL,Enum.Material.Fabric,Enum.PartType.Cylinder)
    piece(fallback,handle,"Band",Vector3.new(.24,1.88,1.78),CFrame.new(0,.35,0)*CFrame.Angles(0,0,math.rad(90)),accent,Enum.Material.Fabric,Enum.PartType.Cylinder)
    return attachAccessory(character,humanoid,fallback,parts.head,CFrame.new(0,parts.head.Size.Y*.72,0))
end

builders.glasses=function(character,humanoid,item)
    local parts=body(character); if not parts.head then return false end
    local noir=item.wearable and item.wearable.style=="noir"
    local frame=noir and BLACK or Color3.fromRGB(61,53,46)
    local tint=noir and Color3.fromRGB(53,72,98) or Color3.fromRGB(112,93,72)
    local accessory,handle=headAccessory("Glasses_"..item.id,"FaceFrontAttachment",CFrame.new(0,0,.04))
    for _,x in ipairs({-.36,.36}) do
        piece(accessory,handle,"Lens",Vector3.new(.58,.40,.06),CFrame.new(x,0,-.12),tint,Enum.Material.Glass).Transparency=.32
        piece(accessory,handle,"Top",Vector3.new(.66,.06,.08),CFrame.new(x,.23,-.15),frame,Enum.Material.Metal)
        piece(accessory,handle,"Bottom",Vector3.new(.66,.06,.08),CFrame.new(x,-.23,-.15),frame,Enum.Material.Metal)
        piece(accessory,handle,"SideL",Vector3.new(.06,.46,.08),CFrame.new(x-.32,0,-.15),frame,Enum.Material.Metal)
        piece(accessory,handle,"SideR",Vector3.new(.06,.46,.08),CFrame.new(x+.32,0,-.15),frame,Enum.Material.Metal)
    end
    piece(accessory,handle,"Bridge",Vector3.new(.18,.06,.08),CFrame.new(0,.04,-.15),frame,Enum.Material.Metal)
    return attachAccessory(character,humanoid,accessory,parts.head,CFrame.new(0,.07,-parts.head.Size.Z*.52))
end

local function weldedRoot(character,name,bodyPart,offset)
    if not bodyPart then return nil,nil end
    local model=mark(Instance.new("Model")); model.Name="SpyCosmetic_"..name; model.Parent=character
    local root=safePart(model,"Root",Vector3.new(.12,.12,.12),BLACK); root.Transparency=1; root.CFrame=bodyPart.CFrame*offset
    local joint=Instance.new("Weld")
    joint.Part0=bodyPart; joint.Part1=root; joint.C0=offset; joint.Parent=root
    return model,root
end

builders.tie=function(character,humanoid,item)
    local torso=body(character).torso
    local model,root=weldedRoot(character,"Tie_"..item.id,torso,CFrame.new(0,torso and torso.Size.Y*.15 or 0,-(torso and torso.Size.Z*.52 or .55)))
    if not model then return false end
    piece(model,root,"Knot",Vector3.new(.34,.28,.12),CFrame.new(0,.35,0)*CFrame.Angles(0,0,math.rad(45)),BLACK,Enum.Material.Fabric)
    local blade=piece(model,root,"Blade",Vector3.new(.34,1.20,.10),CFrame.new(0,-.38,0),BLACK,Enum.Material.Fabric)
    local tip=piece(model,root,"Tip",Vector3.new(.31,.31,.10),CFrame.new(0,-1.02,0)*CFrame.Angles(0,0,math.rad(45)),BLACK,Enum.Material.Fabric)
    blade.CastShadow=false; tip.CastShadow=false
    return true
end

builders.gloves=function(character,humanoid,item)
    local parts=body(character); local made=false
    for side,limb in pairs({Left=parts.left,Right=parts.right}) do
        if limb then
            local isR6Arm=limb.Name=="Left Arm" or limb.Name=="Right Arm"
            local offset=isR6Arm and CFrame.new(0,-limb.Size.Y*.33,0) or CFrame.new()
            local gloveSize=isR6Arm
                and Vector3.new(limb.Size.X*1.04,limb.Size.Y*.34,limb.Size.Z*1.04)
                or limb.Size+Vector3.new(.07,.09,.07)
            local model,root=weldedRoot(character,side.."Glove_"..item.id,limb,offset)
            local shell=piece(model,root,"Glove",gloveSize,CFrame.new(),CHARCOAL,Enum.Material.Fabric)
            shell.CastShadow=false; made=true
        end
    end
    return made
end

builders.holster=function(character,humanoid,item)
    local torso=body(character).torso
    local model,root=weldedRoot(character,"Holster_"..item.id,torso,CFrame.new(0,0,-(torso and torso.Size.Z*.53 or .55)))
    if not model then return false end
    local leather=Color3.fromRGB(76,48,34)
    piece(model,root,"ShoulderStrap",Vector3.new(.18,torso.Size.Y*1.08,.12),CFrame.new(-torso.Size.X*.29,.05,0)*CFrame.Angles(0,0,math.rad(-14)),leather,Enum.Material.Fabric)
    piece(model,root,"ChestStrap",Vector3.new(torso.Size.X*.72,.16,.12),CFrame.new(0,-torso.Size.Y*.12,0)*CFrame.Angles(0,0,math.rad(9)),leather,Enum.Material.Fabric)
    piece(model,root,"Holster",Vector3.new(.48,.78,.20),CFrame.new(torso.Size.X*.30,-torso.Size.Y*.28,-.02)*CFrame.Angles(0,0,math.rad(-8)),Color3.fromRGB(59,37,29),Enum.Material.Fabric)
    piece(model,root,"Buckle",Vector3.new(.20,.13,.05),CFrame.new(-torso.Size.X*.08,-torso.Size.Y*.12,-.09),BRASS,Enum.Material.Metal)
    return true
end

local function outfitDetails(character,item)
    if not item or not item.wearable then return end
    local torso=body(character).torso
    local model,root=weldedRoot(character,"OutfitDetails_"..item.id,torso,CFrame.new(0,0,-(torso and torso.Size.Z*.53 or .55)))
    if not model then return end
    local style=item.wearable.style
    if style=="vest" then
        for index=1,4 do piece(model,root,"Button"..index,Vector3.new(.10,.10,.05),CFrame.new(0,.52-index*.30,-.05),BRASS,Enum.Material.Metal,Enum.PartType.Ball) end
    elseif style=="velvet" then
        piece(model,root,"PocketSquare",Vector3.new(.34,.19,.06),CFrame.new(torso.Size.X*.25,.20,-.05)*CFrame.Angles(0,0,math.rad(-8)),Color3.fromRGB(132,54,91),Enum.Material.Fabric)
    elseif style=="director" then
        piece(model,root,"DirectorPin",Vector3.new(.18,.18,.06),CFrame.new(torso.Size.X*.26,.30,-.05),BRASS,Enum.Material.Metal,Enum.PartType.Ball)
        piece(model,root,"Chain",Vector3.new(.07,.76,.05),CFrame.new(torso.Size.X*.16,-.05,-.04)*CFrame.Angles(0,0,math.rad(48)),BRASS,Enum.Material.Metal)
    end
end

local function effect(character,item)
    if not item or not item.effect then return end
    local parts=body(character); local anchor=parts.root or parts.torso
    if not anchor then return end
    local attachment=mark(Instance.new("Attachment")); attachment.Name="SpyCosmetic_Effect_"..item.id; attachment.Position=Vector3.new(0,-1.4,0); attachment.Parent=anchor
    local emitter=Instance.new("ParticleEmitter")
    emitter.Name="SubtleAura"; emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color=ColorSequence.new(rgb(item.effect.color,rgb(item.color,BRASS)))
    emitter.LightEmission=.25; emitter.Rate=math.clamp(item.effect.rate or 1,1,MAX_EFFECT_RATE)
    emitter.Lifetime=NumberRange.new(.45,.8); emitter.Speed=NumberRange.new(.25,.7); emitter.SpreadAngle=Vector2.new(16,16)
    emitter.Rotation=NumberRange.new(0,360); emitter.RotSpeed=NumberRange.new(-30,30)
    emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.11),NumberSequenceKeypoint.new(.7,.07),NumberSequenceKeypoint.new(1,0)})
    emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.32),NumberSequenceKeypoint.new(1,1)})
    emitter.Parent=attachment
end

local function equipFlash(character,item)
    local anchor=body(character).torso; if not anchor then return end
    local attachment=mark(Instance.new("Attachment")); attachment.Name="SpyCosmetic_EquipFlash"; attachment.Parent=anchor
    local emitter=Instance.new("ParticleEmitter")
    emitter.Rate=0; emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"; emitter.Color=ColorSequence.new(rgb(item and item.color,CREAM))
    emitter.Lifetime=NumberRange.new(.28,.40); emitter.Speed=NumberRange.new(1.4,2.2); emitter.SpreadAngle=Vector2.new(180,180)
    emitter.Size=NumberSequence.new(.08); emitter.Transparency=NumberSequence.new(.18,1); emitter.Parent=attachment; emitter:Emit(8)
    task.delay(.55,function() if attachment.Parent then attachment:Destroy() end end)
end

local function ensureOriginal(player,character,humanoid,state)
    if state.originalDescription then return true end
    local loaded=true; pcall(function() loaded=player:HasAppearanceLoaded() end)
    if not loaded then return false end
    local ok,description=pcall(function() return humanoid:GetAppliedDescription() end)
    if not ok or not description or not description:IsA("HumanoidDescription") then return false end
    state.originalDescription=description:Clone(); description:Destroy(); return true
end

local function equippedItem(equipped,slot,catalog)
    local itemId=equipped[slot]
    return type(itemId)=="string" and catalog.ById[itemId] or nil
end

local function signature(equipped)
    local values={}
    for _,slot in ipairs({"accessory","hat","glasses","tie","outfit","gloves","shoulder"}) do values[#values+1]=tostring(equipped[slot] or "") end
    return table.concat(values,"|")
end

function Cosmetics.apply(player,profile,catalog)
    catalog=catalog or Catalog
    local character=player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or not profile or not profile.ready then return false end
    local state=states[character]
    if not state then state={applying=false,outfitId=nil,signature=nil} states[character]=state end
    state.latest=profile
    local equipped=profile.equipped or {}
    player:SetAttribute("SpyTitle",equipped.title or ""); player:SetAttribute("SpyFrame",equipped.frame or "")
    if not ensureOriginal(player,character,humanoid,state) then return false end

    local outfit=equippedItem(equipped,"outfit",catalog)
    local outfitId=outfit and outfit.id or (equipped.outfit=="tuxedo" and "tuxedo" or "")
    if state.outfitId~=outfitId and not state.applying then
        state.applying=true
        task.spawn(function()
            local ok,err=pcall(function()
                if player.Character~=character or not humanoid.Parent then return end
                local description=state.originalDescription:Clone()
                if outfit and outfit.wearable then
                    description.Shirt=outfit.wearable.shirtId or description.Shirt
                    description.Pants=outfit.wearable.pantsId or description.Pants
                elseif outfitId=="tuxedo" then
                    description.Shirt=LEGACY_TUX_SHIRT; description.Pants=LEGACY_TUX_PANTS
                end
                humanoid:ApplyDescriptionResetAsync(description,Enum.AssetTypeVerification.Default)
                description:Destroy(); state.outfitId=outfitId; state.signature=nil
            end)
            state.applying=false
            if not ok then
                warn("SpyClub: outfit delivery failed; it remains owned for retry: "..tostring(err))
            elseif player.Character==character and state.latest then Cosmetics.apply(player,state.latest,catalog) end
        end)
        return true
    end
    if state.applying then return true end

    local nextSignature=signature(equipped)
    if state.signature==nextSignature then return true end
    Cosmetics.clear(character)
    if equipped.accessory=="tophat" then builders.tophat(character,humanoid,{id="legacy_tophat",color={212,184,122},wearable={builder="tophat"}}) end
    local strongestEffect=nil
    for _,slot in ipairs({"hat","glasses","tie","gloves","shoulder"}) do
        local item=equippedItem(equipped,slot,catalog)
        local builder=item and item.wearable and builders[item.wearable.builder]
        if builder then builder(character,humanoid,item) end
        if item and item.effect and (not strongestEffect or catalog.Rarities[item.rarity].rank>catalog.Rarities[strongestEffect.rarity].rank) then strongestEffect=item end
    end
    outfitDetails(character,outfit)
    if outfit and outfit.effect and (not strongestEffect or catalog.Rarities[outfit.rarity].rank>catalog.Rarities[strongestEffect.rarity].rank) then strongestEffect=outfit end
    effect(character,strongestEffect)
    equipFlash(character,strongestEffect or outfit or equippedItem(equipped,"hat",catalog))
    state.signature=nextSignature
    return true
end

function Cosmetics.emote(player,profile)
    if not profile or not profile.ready or (profile.equipped or {}).emote~="wave" then return false end
    local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return pcall(function()
        local animator=humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator",humanoid)
        local animation=Instance.new("Animation"); animation.AnimationId="rbxassetid://507770239"
        local track=animator:LoadAnimation(animation); animation:Destroy()
        track.Priority=Enum.AnimationPriority.Action; track.Looped=false; track:Play(.2)
        track.Stopped:Once(function() track:Destroy() end)
    end)
end

return Cosmetics
