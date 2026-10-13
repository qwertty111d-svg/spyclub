-- SPY CLUB / one wardrobe renderer for live characters and every fitting preview.
-- Asset IDs below are catalog IDs. ShirtTemplate/PantsTemplate come from the
-- actual loaded clothing instance, never from a catalog ID string.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Catalog = require(script.Parent.Catalog)
local templateModule=script.Parent:FindFirstChild("WardrobeTemplates")
local Templates=templateModule and require(templateModule)
local Wardrobe = {}
Wardrobe.VERSION = 28
Wardrobe.HAIR = 4875445470
Wardrobe.Outfits = {
    base = {shirt=10507717098,pants=4666394268},
    club_vest = {shirt=129538902582804,pants=4666394268},
    velvet_tuxedo = {shirt=12386048507,pants=4666394268},
    director_suit = {shirt=12779575121,pants=33210031},
    founder_suit = {shirt=199168526,pants=33210031,bow=4602807964},
    tuxedo = {shirt=12786197,pants=12786204,tieShirt=199168526},
}
Wardrobe.Accessories = {
hair_charmer = {id=376548738,slot="hair"},
hair_spikes = {id=6140774351,slot="hair"},
hair_swept = {id=5163640422,slot="hair"},
hair_ponytail = {id=7331217038,slot="hair"},
hair_noir = {id=77799917,slot="hair"},
hair_ash = {id=9513453851,slot="hair"},
hair_amber = {id=12299883619,slot="hair"},
hair_crimson = {id=10476395186,slot="hair"},
    dark_fedora = {id=18342574766,slot="hat"},
    agent_fedora = {id=13617897285,slot="hat"},
    crimson_fedora = {id=72082328,slot="hat",nativeAttachment=true},
    midnight_tophat = {id=14011918284,slot="hat"},
    tophat = {id=14011918284,slot="accessory"},
    closed_club_fedora = {id=18342574766,slot="hat",signature=true},
    classic_glasses = {id=15318940395,slot="glasses"},
    noir_glasses = {id=13619533061,slot="glasses"},
    interrogation_glasses = {id=15318940395,slot="glasses",gold=true},
    black_tie = {id=5411045718,slot="tie"},
    burgundy_tie = {id=5411047290,slot="tie",tint={103,32,45}},
    founder_tie = {id=5411045718,slot="tie"},
}
local SKIN = Color3.fromRGB(224,197,172)
local WHITE = Color3.new(1,1,1)
local BLACK = Color3.fromRGB(25,25,28)
local BRASS = Color3.fromRGB(191,154,95)
local activeLoads, nextAttempt = {}, {}
local root
local booted = false
-- New catalog entries share the same renderer; existing signatures are retained.
for _,item in ipairs(Catalog.Items) do
    if item.wearable and item.wearable.assetId and not Wardrobe.Accessories[item.id] then
        Wardrobe.Accessories[item.id]={id=item.wearable.assetId,slot=item.equipSlot or item.kind,nativeAttachment=item.wearable.nativeAttachment==true}
    end
end

local function assets()
    if root and root.Parent then return root end
    root = ReplicatedStorage:FindFirstChild("SpyWardrobeAssets")
    if not root and RunService:IsServer() then
        root = Instance.new("Folder")
        root.Name = "SpyWardrobeAssets"
        root:SetAttribute("Revision",0)
        root.Parent = ReplicatedStorage
    end
    return root
end

local function sanitize(instance)
    for _,node in ipairs(instance:GetDescendants()) do
        if node:IsA("LuaSourceContainer") or node:IsA("RemoteEvent")
            or node:IsA("RemoteFunction") or node:IsA("BindableEvent")
            or node:IsA("BindableFunction") or node:IsA("Sound")
            or node:IsA("ProximityPrompt") or node:IsA("ClickDetector")
            or node:IsA("LayerCollector") or node:IsA("Humanoid") then
            node:Destroy()
        elseif node:IsA("BasePart") then
            node.Anchored=true;node.CanCollide=false;node.CanTouch=false
            node.CanQuery=false;node.Massless=true
        end
    end
end

local function cached(id,className)
    local folder=assets()
    local item=folder and folder:FindFirstChild("A"..id)
    return item and item:IsA(className) and item or nil
end

local function requestAsset(id,className)
    if not RunService:IsServer() or cached(id,className) or activeLoads[id]
        or os.clock()<(nextAttempt[id] or 0) then return end
    -- Verified rigid models are already packaged with the place. Their mesh and
    -- texture resources remain native Roblox content, without repeated model fetch.
    local localTemplate=Templates and Templates.create(id)
    if localTemplate then
        assert(localTemplate:IsA(className),"Local wardrobe class mismatch")
        sanitize(localTemplate);localTemplate.Name="A"..id
        local folder=assets();localTemplate.Parent=folder
        folder:SetAttribute("Revision",(folder:GetAttribute("Revision") or 0)+1)
        folder:SetAttribute("Failed_"..id,nil)
        return
    end
    local lease = {}
    activeLoads[id]=lease
    -- LoadAsset may stall independently of boot. Release only this request's
    -- lease; a late response must never overwrite a newer asset request.
    task.delay(20,function()
        if activeLoads[id]~=lease then return end
        activeLoads[id]=nil;nextAttempt[id]=os.clock()+8
        assets():SetAttribute("Failed_"..id,true)
    end)
    local nativeStarted,insertFinished,nativeFinished=false,false,false
    local function publish(loaded)
        if activeLoads[id]~=lease then
            if loaded then loaded:Destroy() end
            return false
        end
        local source=loaded and loaded:FindFirstChildWhichIsA(className,true)
        if source and className=="Shirt" and (type(source.ShirtTemplate)~="string" or source.ShirtTemplate=="") then source=nil end
        if source and className=="Pants" and (type(source.PantsTemplate)~="string" or source.PantsTemplate=="") then source=nil end
        if source then
            local copy=source:Clone()
            sanitize(copy)
            copy.Name="A"..id
            copy:SetAttribute("CatalogAssetId",id)
            local folder=assets()
            local old=folder:FindFirstChild(copy.Name)
            if old then old:Destroy() end
            copy.Parent=folder
            folder:SetAttribute("Revision",(folder:GetAttribute("Revision") or 0)+1)
            folder:SetAttribute("Failed_"..id,nil)
            activeLoads[id]=nil
        end
        if loaded then loaded:Destroy() end
        return source~=nil
    end
    local function nativeDelivery()
        if nativeStarted or activeLoads[id]~=lease then return end
        nativeStarted=true
        task.spawn(function()
            -- Resolve a separate avatar, never reset the live/seated character.
            local d=Instance.new("HumanoidDescription")
            d.Shirt=0;d.Pants=0;d.HairAccessory="";d.HatAccessory=""
            if className=="Shirt" then d.Shirt=id
            elseif className=="Pants" then d.Pants=id
            else
                local slot=id==Wardrobe.HAIR and "hair" or "hat"
                for _,definition in pairs(Wardrobe.Accessories) do if definition.id==id then slot=definition.slot;break end end
                local field=({hair="HairAccessory",hat="HatAccessory",accessory="HatAccessory",glasses="FaceAccessory",tie="NeckAccessory"})[slot] or "HatAccessory"
                d[field]=tostring(id)
            end
            local ok,model=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(d,Enum.HumanoidRigType.R15) end)
            d:Destroy()
            if publish(ok and model or nil) then return end
            nativeFinished=true
            if insertFinished and activeLoads[id]==lease then
                activeLoads[id]=nil;nextAttempt[id]=os.clock()+8
                assets():SetAttribute("Failed_"..id,true)
            end
        end)
    end
    -- A stalled insert cannot prevent the independent native path from starting.
    task.delay(4,nativeDelivery)
    task.spawn(function()
        local ok,loaded=pcall(function() return game:GetService("InsertService"):LoadAsset(id) end)
        insertFinished=true
        if not publish(ok and loaded or nil) then
            nativeDelivery()
            if nativeFinished and activeLoads[id]==lease then
                activeLoads[id]=nil;nextAttempt[id]=os.clock()+8;assets():SetAttribute("Failed_"..id,true)
            end
        end
    end)
end

function Wardrobe.outfit(equipped)
    local definition=Wardrobe.Outfits[equipped.outfit] or Wardrobe.Outfits.base
    local shirt=definition.shirt
    if equipped.tie and equipped.tie~="" and definition.tieShirt then shirt=definition.tieShirt end
    return definition,shirt,definition.pants
end

function Wardrobe.hat(equipped)
    if equipped.hat and equipped.hat~="" then return equipped.hat end
    return equipped.accessory=="tophat" and "tophat" or nil
end

function Wardrobe.requirements(equipped,onlySlot)
    equipped=equipped or {}
    local outfit,shirt,pants=Wardrobe.outfit(equipped)
    local result={[shirt]="Shirt",[pants]="Pants"}
    local hat=Wardrobe.hat(equipped)
    local hair=Wardrobe.Accessories[equipped.hair];result[hair and hair.id or Wardrobe.HAIR]="Accessory"
    for _,id in ipairs({hat or "",equipped.glasses or "",equipped.tie or ""}) do
        local definition=Wardrobe.Accessories[id]
        if definition then result[definition.id]="Accessory" end
    end
    if outfit.bow and (not equipped.tie or equipped.tie=="") then result[outfit.bow]="Accessory" end
    if onlySlot then
        local required={}
        if onlySlot=="outfit" then
            required[shirt]="Shirt";required[pants]="Pants"
            if outfit.bow and (not equipped.tie or equipped.tie=="") then required[outfit.bow]="Accessory" end
        elseif onlySlot=="hair" then
            required[hair and hair.id or Wardrobe.HAIR]="Accessory"
        else
            local id=(onlySlot=="hat" or onlySlot=="accessory") and hat or equipped[onlySlot]
            local selected=Wardrobe.Accessories[id]
            if selected then required[selected.id]="Accessory" end
        end
        return required
    end
    return result
end

function Wardrobe.prepare(equipped,timeout,onlySlot)
    local required=Wardrobe.requirements(equipped,onlySlot)
    for id,className in pairs(required) do requestAsset(id,className) end
    local deadline=os.clock()+(timeout or 12)
    repeat
        local missing
        for id,className in pairs(required) do
            if not cached(id,className) then missing=id;break end
        end
        if not missing then return true end
        if os.clock()>=deadline then return false,"asset:"..missing end
        if RunService:IsServer() and not activeLoads[missing] and nextAttempt[missing] then
            return false,"asset:"..missing
        end
        task.wait(.05)
    until false
end

function Wardrobe.description(equipped,bare)
    equipped=equipped or {}
    local d=Instance.new("HumanoidDescription")
    d.HeightScale=1;d.WidthScale=1;d.DepthScale=1;d.HeadScale=1
    d.BodyTypeScale=0;d.ProportionScale=0
    for _,name in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"}) do d[name]=0 end
    d.HeadColor=SKIN;d.LeftArmColor=SKIN;d.RightArmColor=SKIN
    d.TorsoColor=Color3.fromRGB(214,208,194)
    d.LeftLegColor=Color3.fromRGB(38,38,42);d.RightLegColor=d.LeftLegColor
    d.Face=0;d.GraphicTShirt=0
    if not bare then
        local _,shirt,pants=Wardrobe.outfit(equipped)
        d.Shirt=shirt;d.Pants=pants
        local hair=Wardrobe.Accessories[equipped.hair];d.HairAccessory=tostring(hair and hair.id or Wardrobe.HAIR)
    end
    return d
end

function Wardrobe.face(character)
    local head=character:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return false end
    -- Modern default heads can use dynamic-face UVs. A classic decal on those
    -- UVs stretches into a stripe even with TextureID cleared. Keep the R15
    -- rig head for its neck, attachments and scaling, but render a classic mesh.
    for _,node in ipairs(head:GetChildren()) do
        if node:IsA("Decal") or node:IsA("Texture") or node:IsA("SurfaceGui")
            or node:IsA("SurfaceAppearance") then node:Destroy() end
    end
    head.Transparency=1
    head.CastShadow=false
    local visual=character:FindFirstChild("SpyClassicHead")
    if visual and not visual:IsA("Part") then visual:Destroy();visual=nil end
    if not visual then
        visual=Instance.new("Part")
        visual.Name="SpyClassicHead"
        visual.CanCollide=false;visual.CanTouch=false;visual.CanQuery=false
        visual.Massless=true
        visual.TopSurface=Enum.SurfaceType.Smooth
        visual.BottomSurface=Enum.SurfaceType.Smooth
        visual.Parent=character
    end
    -- This visual is intentionally not tagged SpyWardrobe: changing a tie or
    -- hat must not remove the face or unhide the dynamic head beneath it.
    visual.Size=Vector3.new(2,1,1)
    visual.Color=SKIN;visual.Material=Enum.Material.SmoothPlastic
    visual.Transparency=0;visual.CastShadow=true
    visual.Anchored=head.Anchored
    visual.CFrame=head.CFrame
    for _,node in ipairs(visual:GetChildren()) do node:Destroy() end
    local mesh=Instance.new("SpecialMesh")
    mesh.Name="ClassicHeadMesh"
    mesh.MeshType=Enum.MeshType.Head
    mesh.Scale=Vector3.new(1.25,1.25,1.25)
    mesh.Parent=visual
    local face=Instance.new("Decal")
    face.Name="face";face.Face=Enum.NormalId.Front
    face.Texture="rbxasset://textures/face.png"
    face.Color3=Color3.fromRGB(43,35,32)
    face.Parent=visual
    local joint=Instance.new("Weld")
    joint.Name="ClassicHeadWeld";joint.Part0=head;joint.Part1=visual
    joint.C0=CFrame.new();joint.C1=CFrame.new();joint.Parent=visual
    return true
end

local function mark(object,slot,id)
    object:SetAttribute("SpyWardrobe",true)
    object:SetAttribute("SpySlot",slot)
    object:SetAttribute("SpyItemId",id)
    return object
end

local function weld(bodyPart,part,c0,c1)
    local joint=Instance.new("Weld")
    joint.Name="AccessoryWeld";joint.Part0=bodyPart;joint.Part1=part
    joint.C0=c0 or bodyPart.CFrame:ToObjectSpace(part.CFrame)
    joint.C1=c1 or CFrame.new();joint.Parent=part
    return joint
end

local function piece(parent,bodyPart,name,size,offset,color,shape)
    local part=Instance.new("Part")
    part.Name=name;part.Size=size;part.Color=color
    part.Material=Enum.Material.SmoothPlastic
    part.Anchored=false;part.CanCollide=false;part.CanTouch=false
    part.CanQuery=false;part.Massless=true
    if shape then part.Shape=shape end
    part.CFrame=bodyPart.CFrame*offset;part.Parent=parent
    weld(bodyPart,part,offset)
    return part
end

local function attachmentOnBody(character,name)
    for _,limb in ipairs(character:GetChildren()) do
        if limb:IsA("BasePart") then
            local attachment=limb:FindFirstChild(name)
            if attachment and attachment:IsA("Attachment") then return attachment end
        end
    end
    return nil
end

local function attach(character,id,slot,definition)
    local source=assert(cached(definition.id,"Accessory"),"Accessory not prepared: "..id)
    local copy=source:Clone()
    local handle=copy:FindFirstChild("Handle")
    assert(handle and handle:IsA("BasePart"),"No handle: "..id)
    local sourceAttachment,targetAttachment
    for _,node in ipairs(handle:GetChildren()) do
        if node:IsA("Attachment") then
            local target=attachmentOnBody(character,node.Name)
            if target then sourceAttachment=node;targetAttachment=target;break end
        end
    end
    if not targetAttachment then copy:Destroy();error("No matching R15 attachment: "..id) end
    -- Snapshot the frames before parenting. Roblox must not create a second
    -- automatic accessory weld or rescale the handle after manual placement.
    local bodyFrame=targetAttachment.CFrame
    if slot=="glasses" and not definition.nativeAttachment then
        -- Apply the correction in head-local space, before the attachment's
        -- rotation, and use the same frame for initial position and the weld.
        bodyFrame=CFrame.new(0,0.20,0)*bodyFrame
    end
    local handleFrame=sourceAttachment.CFrame
    local transform=targetAttachment.Parent.CFrame*bodyFrame*handleFrame:Inverse()*handle.CFrame:Inverse()
    for _,node in ipairs(copy:GetDescendants()) do
        if node:IsA("JointInstance") or node:IsA("Constraint") then node:Destroy() end
    end
    for _,node in ipairs(copy:GetDescendants()) do
        if node:IsA("BasePart") then
            node.CFrame=transform*node.CFrame
            node.Anchored=false;node.Massless=true;node.CanCollide=false
            node.CanTouch=false;node.CanQuery=false
            if definition.gold or definition.tint then
                local tint=definition.gold and BRASS or Color3.fromRGB(table.unpack(definition.tint))
                node.Color=tint;node.Material=Enum.Material.SmoothPlastic
                if node:IsA("MeshPart") then node.TextureID="" end
                for _,mesh in ipairs(node:GetChildren()) do
                    if mesh:IsA("SpecialMesh") then mesh.TextureId="";mesh.VertexColor=Vector3.new(1,1,1)
                    elseif mesh:IsA("SurfaceAppearance") then mesh:Destroy() end
                end
            end
        end
    end
    local assembly=mark(Instance.new("Model"),slot,id)
    assembly.Name="SpyWear_"..id
    copy.Name="Geometry"
    copy.Parent=assembly
    weld(targetAttachment.Parent,handle,bodyFrame,handleFrame)
    for _,node in ipairs(copy:GetDescendants()) do
        if node:IsA("BasePart") and node~=handle then weld(handle,node) end
    end
    assembly.Parent=character
    return assembly
end

local function group(character,id,slot)
    local model=mark(Instance.new("Model"),slot,id)
    model.Name="SpyWear_"..id;model.Parent=character
    return model
end

local function gloves(character)
    local model=group(character,"agent_gloves","gloves")
    for _,side in ipairs({"Left","Right"}) do
        local hand=assert(character:FindFirstChild(side.."Hand"),"R15 hand missing")
        local glove=hand:Clone()
        for _,node in ipairs(glove:GetChildren()) do
            if not node:IsA("SpecialMesh") then node:Destroy() end
        end
        glove.Name=side.."Glove";glove.Size=hand.Size*1.025
        glove.Material=Enum.Material.SmoothPlastic;glove.Color=BLACK
        if glove:IsA("MeshPart") then glove.TextureID="" end
        local mesh=glove:FindFirstChildOfClass("SpecialMesh")
        if mesh then mesh.TextureId="" end
        glove.Anchored=false;glove.Massless=true;glove.CanCollide=false
        glove.CanTouch=false;glove.CanQuery=false
        glove.CFrame=hand.CFrame;glove.Parent=model
        weld(hand,glove,CFrame.new())
    end
end

local function holster(character)
    local torso=assert(character:FindFirstChild("UpperTorso"),"R15 torso missing")
    local m=group(character,"shoulder_holster","shoulder")
    local z=torso.Size.Z*.5+.025
    local leather=Color3.fromRGB(64,40,30)
    for _,sign in ipairs({-1,1}) do
        piece(m,torso,"Strap",Vector3.new(.12,torso.Size.Y*.95,.035),
            CFrame.new(-.51,.05,sign*z)*CFrame.Angles(0,0,math.rad(-12)),leather)
    end
    piece(m,torso,"Shoulder",Vector3.new(.15,.035,torso.Size.Z),CFrame.new(-.57,torso.Size.Y*.47,0),leather)
    piece(m,torso,"Pouch",Vector3.new(.24,.61,.42),CFrame.new(-torso.Size.X*.52,-.30,.03),leather)
    piece(m,torso,"Clasp",Vector3.new(.10,.065,.04),CFrame.new(-.44,-.19,-z-.027),BRASS)
end

local function credential(character,item)
    if not item or item.id=="classic" then return end
    local torso=assert(character:FindFirstChild("LowerTorso"),"R15 torso missing")
    local model=group(character,item.id,"card")
    local cf=CFrame.new(-torso.Size.X*.32,-.1,-torso.Size.Z*.5-.045)
    piece(model,torso,"Sleeve",Vector3.new(.41,.54,.055),cf,BLACK)
    piece(model,torso,"Foil",Vector3.new(.29,.40,.02),cf*CFrame.new(0,0,-.042),Color3.fromRGB(table.unpack(item.dark)))
    piece(model,torso,"Seal",Vector3.new(.11,.11,.02),cf*CFrame.new(0,.07,-.058)*CFrame.Angles(0,0,math.pi/4),Color3.fromRGB(table.unpack(item.color)))
end

local function trinket(character,item)
    if not item then return end
    local torso=assert(character:FindFirstChild("LowerTorso"),"R15 torso missing")
    local m=group(character,item.id,"trinket")
    local cf=CFrame.new(torso.Size.X*.33,-.12,-torso.Size.Z*.5-.07)
    piece(m,torso,"Loop",Vector3.new(.08,.19,.045),cf*CFrame.new(0,.23,0),BLACK)
    if item.id=="dice" then
        piece(m,torso,"Die",Vector3.new(.26,.26,.26),cf,Color3.fromRGB(222,214,193))
        for _,n in ipairs({-.065,.065}) do
            piece(m,torso,"Pip",Vector3.new(.035,.035,.01),cf*CFrame.new(n,n,-.136),BLACK,Enum.PartType.Ball)
        end
    else
        local rotation=CFrame.Angles(0,math.pi/2,0)
        piece(m,torso,"Rim",Vector3.new(.045,.33,.33),cf*rotation,BRASS,Enum.PartType.Cylinder)
        local face=piece(m,torso,"Face",Vector3.new(.05,.265,.265),cf*CFrame.new(0,0,-.02)*rotation,
            item.id=="lens" and Color3.fromRGB(98,137,145) or Color3.fromRGB(228,215,188),Enum.PartType.Cylinder)
        if item.id=="lens" then
            face.Transparency=.45
            piece(m,torso,"Handle",Vector3.new(.065,.24,.055),cf*CFrame.new(.08,-.24,0)*CFrame.Angles(0,0,.3),BLACK)
        else
            piece(m,torso,"Hand",Vector3.new(.018,.105,.018),cf*CFrame.new(0,.035,-.055),BLACK)
        end
    end
end

local function effect(character,item)
    if not item then return end
    local anchor=character:FindFirstChild("LowerTorso")
    if not anchor then return end
    local data=item.effect or {color=item.color,rate=item.id=="embers" and 3 or 1}
    local holder=mark(Instance.new("Attachment"),"effect",item.id)
    holder.Name="SpyWear_Effect";holder.Position=Vector3.new(0,-.5,.2);holder.Parent=anchor
    local p=Instance.new("ParticleEmitter")
    p.Name="ClubMotes";p.Texture="rbxasset://textures/particles/sparkles_main.dds"
    p.Color=ColorSequence.new(Color3.fromRGB(table.unpack(data.color or {224,190,135})))
    p.Rate=math.clamp(data.rate or 1,1,3);p.Speed=NumberRange.new(.15,.4)
    p.Lifetime=NumberRange.new(.7,1.3);p.SpreadAngle=Vector2.new(35,35)
    p.LightEmission=.15;p.Rotation=NumberRange.new(0,360)
    p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(1,0)})
    p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.4),NumberSequenceKeypoint.new(1,1)})
    p.Parent=holder
end

function Wardrobe.clear(character)
    for _,node in ipairs(character:GetDescendants()) do
        if node:GetAttribute("SpyWardrobe") and node.Parent then node:Destroy() end
    end
    for _,node in ipairs(character:GetChildren()) do
        if node:IsA("Accessory") or node:IsA("Shirt") or node:IsA("Pants")
            or node:IsA("ShirtGraphic") or node.Name=="SpyHouseUniform"
            or node.Name=="SpyHouseHair" or node:GetAttribute("SpyCosmetic") then node:Destroy() end
    end
end

function Wardrobe.validate(character,equipped,onlySlot)
    if not character:FindFirstChild("UpperTorso") or not character:FindFirstChild("Head") then
        return false,"missing_r15_body"
    end
    for id,className in pairs(Wardrobe.requirements(equipped,onlySlot)) do
        local template=cached(id,className)
        if not template then return false,"asset:"..id end
        if className=="Shirt" and template.ShirtTemplate=="" then return false,"shirt_texture:"..id end
        if className=="Pants" and template.PantsTemplate=="" then return false,"pants_texture:"..id end
        if className=="Accessory" then
            local handle=template:FindFirstChild("Handle")
            local found=false
            if handle and handle:IsA("BasePart") then
                for _,attachment in ipairs(handle:GetChildren()) do
                    if attachment:IsA("Attachment") and attachmentOnBody(character,attachment.Name) then found=true;break end
                end
            end
            if not found then return false,"r15_attachment:"..id end
        end
    end
    if equipped.gloves=="agent_gloves" and (not character:FindFirstChild("LeftHand") or not character:FindFirstChild("RightHand")) then
        return false,"missing_r15_hands"
    end
    return true
end

local function clearSlot(character,slot)
    for _, object in ipairs(character:GetChildren()) do
        if object:GetAttribute("SpyWardrobe") and object:GetAttribute("SpySlot")==slot then object:Destroy() end
    end
end

function Wardrobe.captureClothing(character,equipped)
    if not RunService:IsServer() then return end
    local _,shirtId,pantsId=Wardrobe.outfit(equipped or {})
    for _,record in ipairs({{shirtId,"Shirt","ShirtTemplate"},{pantsId,"Pants","PantsTemplate"}}) do
        local source=character:FindFirstChildOfClass(record[2])
        if source and source[record[3]]~="" and not cached(record[1],record[2]) then
            local copy=source:Clone();copy.Name="A"..record[1]
            copy:SetAttribute("CatalogAssetId",record[1]);copy.Parent=assets()
            assets():SetAttribute("Revision",(assets():GetAttribute("Revision") or 0)+1)
        end
    end
end

function Wardrobe.ensureDressed(character)
    local shirt=character:FindFirstChildOfClass("Shirt")
    local pants=character:FindFirstChildOfClass("Pants")
    if shirt and shirt.ShirtTemplate~="" and pants and pants.PantsTemplate~="" then
        local temporary=character:FindFirstChild("SpyTemporaryUniform")
        if temporary then temporary:Destroy() end
        for _,part in ipairs(character:GetChildren()) do
            local original=part:GetAttribute("SpyFallbackBodyColor")
            if part:IsA("BasePart") and original then
                part.Color=original;part:SetAttribute("SpyFallbackBodyColor",nil)
            end
        end
        character:SetAttribute("SpyAppearanceDegraded",false)
        return true
    end
    if character:FindFirstChild("SpyTemporaryUniform") then return false end
    local torso=character:FindFirstChild("UpperTorso")
    if not torso then return false end
    -- Authored temporary tailoring, not an invented catalog texture or owned
    -- item. It is replaced as soon as real shirt + trousers become available.
    local jacket=Color3.fromRGB(32,39,49)
    local trouser=Color3.fromRGB(24,28,35)
    for _,part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            part:SetAttribute("SpyFallbackBodyColor",part.Color)
            if part.Name:find("Torso") or part.Name:find("Arm") then part.Color=jacket
            elseif part.Name:find("Leg") or part.Name:find("Foot") then part.Color=trouser end
        end
    end
    local model=Instance.new("Model");model.Name="SpyTemporaryUniform";model.Parent=character
    local front=-torso.Size.Z*.5-.025
    piece(model,torso,"ShirtFront",Vector3.new(torso.Size.X*.30,torso.Size.Y*.92,.028),CFrame.new(0,0,front),Color3.fromRGB(222,219,211))
    for _,side in ipairs({-1,1}) do
        piece(model,torso,"Lapel",Vector3.new(torso.Size.X*.13,torso.Size.Y*.60,.035),
            CFrame.new(side*torso.Size.X*.20,torso.Size.Y*.18,front-.02)*CFrame.Angles(0,0,side*math.rad(19)),Color3.fromRGB(20,25,33))
    end
    piece(model,torso,"Tie",Vector3.new(.13,torso.Size.Y*.54,.038),CFrame.new(0,-.05,front-.04),Color3.fromRGB(112,44,49))
    piece(model,torso,"ClubPin",Vector3.new(.085,.085,.032),CFrame.new(torso.Size.X*.29,.22,front-.04)*CFrame.Angles(0,0,math.pi/4),BRASS)
    character:SetAttribute("SpyAppearanceDegraded",true)
    return false
end

function Wardrobe.renderAvailable(character,equipped)
    equipped=equipped or {}
    if not character:FindFirstChild("UpperTorso") or not character:FindFirstChild("Head") then return false end
    local definition,shirtId,pantsId=Wardrobe.outfit(equipped)
    local shirt,pants=cached(shirtId,"Shirt"),cached(pantsId,"Pants")
    if shirt and shirt.ShirtTemplate~="" and pants and pants.PantsTemplate~="" then
        local copies={shirt:Clone(),pants:Clone()}
        clearSlot(character,"outfit")
        for _,old in ipairs(character:GetChildren()) do
            if old:IsA("Shirt") or old:IsA("Pants") or old:IsA("ShirtGraphic") then old:Destroy() end
        end
        for _,clothes in ipairs(copies) do
            clothes.Name="SpyClub"..clothes.ClassName;clothes.Color3=WHITE
            mark(clothes,"outfit",equipped.outfit or "base");clothes.Parent=character
        end
    end
    local function replaceAccessory(id,slot,accessory)
        if not accessory then clearSlot(character,slot);return end
        local template=cached(accessory.id,"Accessory")
        local handle=template and template:FindFirstChild("Handle")
        local valid=false
        if handle and handle:IsA("BasePart") then
            for _,a in ipairs(handle:GetChildren()) do
                if a:IsA("Attachment") and attachmentOnBody(character,a.Name) then valid=true;break end
            end
        end
        if not valid then return end
        -- Assemble first, then retire the old slot. A bad attachment keeps the
        -- previous visible item intact and can be retried later.
        local old={}
        for _,n in ipairs(character:GetChildren()) do
            if n:GetAttribute("SpyWardrobe") and n:GetAttribute("SpySlot")==slot then old[#old+1]=n end
        end
        attach(character,id,slot,accessory)
        for _,n in ipairs(old) do n:Destroy() end
    end
    local hair=Wardrobe.Accessories[equipped.hair]
    replaceAccessory(hair and equipped.hair or "house_hair","hair",hair or {id=Wardrobe.HAIR})
    local hat=Wardrobe.hat(equipped)
    for _,slot in ipairs({"hat","glasses","tie"}) do
        local id=slot=="hat" and hat or equipped[slot]
        replaceAccessory(id,slot,Wardrobe.Accessories[id])
    end
    if definition.bow and (not equipped.tie or equipped.tie=="") then
        replaceAccessory("black_tie_bow","tie",{id=definition.bow})
    end
    for _,slot in ipairs({"gloves","shoulder","card","trinket","effect"}) do clearSlot(character,slot) end
    if equipped.gloves=="agent_gloves" and character:FindFirstChild("LeftHand") and character:FindFirstChild("RightHand") then gloves(character) end
    if equipped.shoulder=="shoulder_holster" then holster(character) end
    credential(character,Catalog.ById[equipped.card]);trinket(character,Catalog.ById[equipped.trinket])
    local selected=Catalog.ById[equipped.effect]
    if not selected or selected.id=="soft" then
        local outfitItem=Catalog.ById[equipped.outfit];local hatItem=Catalog.ById[hat]
        selected=outfitItem and outfitItem.effect and outfitItem or hatItem and hatItem.effect and hatItem or selected
    end
    effect(character,selected)
    Wardrobe.ensureDressed(character);Wardrobe.face(character)
    return true
end

function Wardrobe.render(character,equipped)
    -- Pure assembly: callers prepare ALL templates before entering this function.
    -- No yields between removing the old outfit and welding the new one.
    equipped=equipped or {}
    local valid,reason=Wardrobe.validate(character,equipped)
    assert(valid,reason)
    Wardrobe.clear(character)
    local definition,shirtId,pantsId=Wardrobe.outfit(equipped)
    for _,record in ipairs({{shirtId,"Shirt"},{pantsId,"Pants"}}) do
        local clothes=cached(record[1],record[2]):Clone()
        clothes.Name="SpyClub"..record[2]
        clothes.Color3=WHITE
        mark(clothes,"outfit",equipped.outfit or "base");clothes.Parent=character
    end
    local hat=Wardrobe.hat(equipped)
    local hair=Wardrobe.Accessories[equipped.hair];attach(character,hair and equipped.hair or "house_hair","hair",hair or {id=Wardrobe.HAIR})
    for _,id in ipairs({hat or "",equipped.glasses or "",equipped.tie or ""}) do
        local accessory=Wardrobe.Accessories[id]
        if accessory then attach(character,id,accessory.slot,accessory) end
    end
    if definition.bow and (not equipped.tie or equipped.tie=="") then
        attach(character,"black_tie_bow","outfit",{id=definition.bow})
    end
    if equipped.outfit=="founder_suit" then
        local torso=assert(character:FindFirstChild("UpperTorso"))
        local pin=group(character,"founder_pin","outfit")
        piece(pin,torso,"ClubPin",Vector3.new(.09,.09,.022),CFrame.new(.53,.24,-torso.Size.Z*.5-.017)*CFrame.Angles(0,0,math.pi/4),BRASS)
    end
    if hat=="closed_club_fedora" then
        local head=assert(character:FindFirstChild("Head"))
        local pin=group(character,"club_hat_pin","hat")
        piece(pin,head,"Pin",Vector3.new(.07,.15,.035),CFrame.new(.72,.75,-.30)*CFrame.Angles(0,math.rad(-30),0),BRASS)
    end
    if equipped.gloves=="agent_gloves" then gloves(character) end
    if equipped.shoulder=="shoulder_holster" then holster(character) end
    credential(character,Catalog.ById[equipped.card])
    trinket(character,Catalog.ById[equipped.trinket])
    -- An explicitly selected aura always wins over an outfit's automatic aura.
    local selected=Catalog.ById[equipped.effect]
    if not selected or selected.id=="soft" then
        local outfitItem=Catalog.ById[equipped.outfit]
        local hatItem=Catalog.ById[hat]
        selected=outfitItem and outfitItem.effect and outfitItem
            or hatItem and hatItem.effect and hatItem or selected
    end
    effect(character,selected)
    Wardrobe.ensureDressed(character)
    Wardrobe.face(character)
    character:SetAttribute("SpyWardrobeVersion",Wardrobe.VERSION)
    return true
end

function Wardrobe.itemsToEquipment(items,current)
    local equipped=current and table.clone(current) or {card="classic",effect="soft"}
    for _,item in ipairs(items or {}) do
        if item and item.kind~="gadget" then
            local slot=item.equipSlot or item.kind
            if slot=="hat" then equipped.accessory="" end
            if item.id=="tophat" then equipped.hat="" end
            equipped[slot]=item.id
        end
    end
    return equipped
end

function Wardrobe.bootstrap()
    if booted or not RunService:IsServer() then return end
    booted=true
    assets()
    if Templates then
        for _,accessory in pairs(Wardrobe.Accessories)do
            if Templates.has(accessory.id)then requestAsset(accessory.id,"Accessory")end
        end
        requestAsset(Wardrobe.HAIR,"Accessory")
    end
    task.spawn(function()
        local description=Wardrobe.description({},true)
        local ok,rig=pcall(function()
            return Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
        end)
        if not ok then
            description.HairAccessory=""
            ok,rig=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15) end)
        end
        if not ok then
            description.Shirt=0;description.Pants=0
            ok,rig=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15) end)
        end
        description:Destroy()
        if not ok then warn("[SpyWardrobe] Preview rig: "..tostring(rig));return end
        Wardrobe.captureClothing(rig,{})
        for _,node in ipairs(rig:GetDescendants()) do
            if node:IsA("LuaSourceContainer") then node:Destroy()
            elseif node:IsA("BasePart") then node.Anchored=true;node.CanCollide=false end
        end
        rig.Name="PreviewRig";rig:PivotTo(CFrame.new());rig.Parent=assets()
    end)
    local list,seen={},{}
    local function add(id,className)
        if not seen[id] then seen[id]=true;list[#list+1]={id,className} end
    end
    for id,className in pairs(Wardrobe.requirements({})) do add(id,className) end
    for _,outfit in pairs(Wardrobe.Outfits) do
        add(outfit.shirt,"Shirt");add(outfit.pants,"Pants")
        if outfit.tieShirt then add(outfit.tieShirt,"Shirt") end
        if outfit.bow then add(outfit.bow,"Accessory") end
    end
    for _,accessory in pairs(Wardrobe.Accessories) do add(accessory.id,"Accessory") end
    local cursor=0
    for _=1,4 do task.spawn(function()
        while true do
            cursor+=1
            local record=list[cursor]
            if not record then break end
            requestAsset(record[1],record[2])
            local deadline=os.clock()+15
            while activeLoads[record[1]] and os.clock()<deadline do task.wait(.1) end
        end
    end) end
end

return Wardrobe
