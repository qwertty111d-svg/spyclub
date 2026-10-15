-- The real MatchPresentation module runs against bounded Instance/service stubs.
-- These checks cannot establish avatar mesh loading, replication, or luminance.
local checks=0
local function check(value,message)
    checks+=1
    assert(value,message)
end
function objectMethods:ClearAllChildren()
    for _,child in ipairs(self:GetChildren())do child:Destroy()end
end

-- No player has arrived yet: even its waiting portrait must inherit the neutral
-- grade used by H/store previews rather than independently tinting a skin gold.
local host=object("Frame","PortraitHost",workspace);host.ZIndex=4
local dispose=Presentation.attachPortrait(host,nil)
local viewport=host:FindFirstChild("LivePortrait")
check(viewport~=nil,"real portrait initializer creates its viewport")
check(viewport.Ambient.r==viewport.Ambient.g and viewport.Ambient.g==viewport.Ambient.b,
    "match portrait ambient must be neutral, matching the character preview")
check(viewport.LightColor.r==viewport.LightColor.g and viewport.LightColor.g==viewport.LightColor.b,
    "match portrait key light must not tint selected clothing")
check(viewport.Ambient.r>=175 and viewport.LightColor.r>=240,
    "neutral portrait lighting must retain useful face fill")
check(viewport.CurrentCamera~=nil,"portrait retains its own camera")
check(viewport:FindFirstChild("PortraitStatus").Visible==true,"missing player remains an explicit waiting state")

function objectMethods:FindFirstAncestorWhichIsA(class)
    local parent=self.Parent
    while parent do
        if parent:IsA(class)then return parent end
        parent=parent.Parent
    end
end
local function visual(parent,name)
    local part=object("Part",name,parent);part.LocalTransparencyModifier=.37
    return part
end
local function accessory(parent,slot,attachmentName)
    -- Production clothing wraps an Accessory in a slot-tagged Model. The POV
    -- hide must still recognize its native head attachment inside that wrapper.
    local wrapper=object("Model","SpyWear_"..tostring(slot),parent)
    wrapper:SetAttribute("SpySlot",slot)
    local item=object("Accessory","Geometry",wrapper)
    local handle=visual(item,"Handle")
    if attachmentName then object("Attachment",attachmentName,handle)end
    return handle
end
local own=object("Model","OwnCharacter",workspace)
local head=visual(own,"Head")
local classicHead=visual(own,"SpyClassicHead")
local torso=visual(own,"UpperTorso")
local hand=visual(own,"LeftHand")
local hat=accessory(own,"hat","HatAttachment")
local hair=accessory(own,"hair","HairAttachment")
local glasses=accessory(own,"glasses","FaceFrontAttachment")
local tie=accessory(own,"tie","NeckAttachment")
local root=visual(own,"HumanoidRootPart")
local peer=object("Model","OtherCharacter",workspace)
local peerHead=visual(peer,"SpyClassicHead")
local peerTorso=visual(peer,"UpperTorso")
local peerHat=accessory(peer,"hat","HatAttachment")

Presentation.applyCameraVisibility(own,false)
for _,part in ipairs({head,classicHead,hat,hair,glasses})do
    check(part.LocalTransparencyModifier==1,"first-person view hides only local head accessories: "..part.Name)
end
for _,part in ipairs({torso,hand,tie})do
    check(part.LocalTransparencyModifier==0,"first-person view preserves local body/clothing: "..part.Name)
end
check(root.LocalTransparencyModifier==.37,"camera visibility leaves the invisible rig root alone")
for _,part in ipairs({peerHead,peerTorso,peerHat})do
    check(part.LocalTransparencyModifier==.37,"changing own view cannot hide a peer: "..part.Name)
end
Presentation.applyCameraVisibility(own,true)
for _,part in ipairs({head,classicHead,torso,hand,hat,hair,glasses,tie})do
    check(part.LocalTransparencyModifier==0,"table view restores own full visual: "..part.Name)
end
for _,part in ipairs({peerHead,peerTorso,peerHat})do
    check(part.LocalTransparencyModifier==.37,"restoring own view cannot alter a peer: "..part.Name)
end
dispose()
check(viewport.Parent==nil,"portrait cleanup removes its viewport")
print("Match portraits: "..checks.." assertions passed (actual initializer/local visibility; native rendering not exercised)")
