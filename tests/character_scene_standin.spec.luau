-- Uses the immutable Roblox instance/math boundary from native_portrait.spec.
-- Ray/overlap results stand in for club geometry; all rig and clone code is real.
local RaycastParams={new=function()return {}end}
local OverlapParams={new=function()return {}end}
local originalInstanceNew=Instance.new
function Instance.new(class)
    local node=originalInstanceNew(class)
    local removing=signal();node._properties.DescendantRemoving=removing
    node._events[#node._events+1]=removing
    return node
end
function objectMethods:FindFirstAncestorWhichIsA(class)
    local parent=self.Parent
    while parent do if parent:IsA(class)then return parent end;parent=parent.Parent end
end
local floorAvailable,blocked=true,false
local probes,overlaps={},{}
function objectMethods:Raycast(origin,direction,params)
    probes[#probes+1]={origin=origin,direction=direction,params=params}
    if not floorAvailable then return nil end
    return {Position=vector(origin.X,0,origin.Z),Normal=Vector3.yAxis,Instance=self._floor}
end
function objectMethods:GetPartBoundsInBox(cf,size,params)
    overlaps[#overlaps+1]={cf=cf,size=size,params=params}
    return blocked and {self._wall} or {}
end
workspace._floor=object("Part","ClubFloor",workspace)
workspace._floor.Size=vector(80,1,80);workspace._floor.CFrame=CFrame.new(0,-.5,0)
workspace._wall=object("Part","ChairBack",workspace)
local worldAdmissions={}
local originalNewIndex=instanceMeta.__newindex
instanceMeta.__newindex=function(node,key,value)
    if key=="Parent" and node.Parent and node.Parent~=value then
        local ancestor=node.Parent
        while ancestor do
            if ancestor.DescendantRemoving then ancestor.DescendantRemoving:Fire(node) end
            ancestor=ancestor.Parent
        end
    end
    if key=="Parent" and value==workspace and node:GetAttribute("SpyCharacterStandIn") then
        for _,descendant in ipairs(node:GetDescendants())do
            check(not forbidden(descendant),"clone is sanitized before admission to the actual workspace")
            if descendant:IsA("BasePart")then check(descendant.Anchored and not descendant.CanCollide,"world admission already has safe clone physics")end
        end
        worldAdmissions[#worldAdmissions+1]=node
    end
    originalNewIndex(node,key,value)
end
-- CHARACTER_SCENE_STAND_IN_SOURCE_INSERT

local function fixture()
    local player=object("Player","LocalPlayer")
    player.CharacterAdded=signal();player.CharacterRemoving=signal()
    local model=object("Model","ActualMatchAvatar",workspace)
    model.Archivable=false
    local human=object("Humanoid","Humanoid",model)
    human.Health=100;human.Sit=true;human.WalkSpeed=0;human.AutoRotate=false;human.Died=signal()
    human.AutomaticScalingEnabled=true;human.EvaluateStateMachine=true
    local root=object("Part","HumanoidRootPart",model);root.CFrame=CFrame.new(0,3,0);root.Size=vector(2,2,1);root.Transparency=1;root.Anchored=true
    local torso=object("Part","Torso",model);torso.CFrame=CFrame.new(0,3,0);torso.Size=vector(2,2,1)
    local head=object("Part","Head",model);head.CFrame=CFrame.new(0,4.5,0);head.Size=vector(2,1,1);head.LocalTransparencyModifier=1;head.Transparency=.2
    local function joint(name,a,b,c0,c1,transform)
        local motor=object("Motor6D",name,a);motor.Part0=a;motor.Part1=b
        motor.C0=c0;motor.C1=c1 or CFrame.new();motor.Transform=transform or CFrame.new();return motor
    end
    joint("RootJoint",root,torso,CFrame.new())
    joint("Neck",torso,head,CFrame.new(0,1.5,0))
    local legs={}
    for i,side in ipairs({"Left","Right"})do
        local x=i==1 and -.5 or .5
        local leg=object("Part",side.." Leg",model);leg.Size=vector(1,2,1)
        leg.CFrame=CFrame.new(x,2,-1)
        joint(side.." Hip",torso,leg,CFrame.new(x,-1,0),CFrame.new(0,1,0),CFrame.Angles(math.rad(90),0,0))
        legs[#legs+1]=leg
    end
    local hat=object("Accessory","ActualEquippedHat",model)
    local handle=object("Part","Handle",hat);handle.CFrame=CFrame.new(0,5.2,0);handle.Size=vector(2.5,.4,2);handle.LocalTransparencyModifier=1
    local weld=object("Weld","AccessoryWeld",handle);weld.Part0=head;weld.Part1=handle;weld.C0=CFrame.new(0,.7,0);weld.C1=CFrame.new()
    local shirt=object("Shirt","EquippedShirt",model);shirt.ShirtTemplate="rbxassetid://actual-outfit"
    object("LocalScript","Animate",model);object("ModuleScript","InjectedScript",hat)
    object("Sound","Footstep",head);object("BillboardGui","Nametag",head)
    object("ProximityPrompt","Prompt",root);object("ClickDetector","Click",head)
    local seat=object("Seat","AuthoritativeSeat",workspace);human.SeatPart=seat
    local seatWeld=object("Weld","SeatWeld",root);seatWeld.Part0=seat;seatWeld.Part1=root;seatWeld.C0=CFrame.new();seatWeld.C1=CFrame.new()
    player.Character=model
    return player,model,human,root,head,legs
end
local player,source,human,sourceRoot,sourceHead,legs=fixture()
local errors,invalidations={},0
local scene=StandIn.new(player,{onError=function(reason)errors[#errors+1]=reason end,onInvalidated=function()invalidations+=1 end})
local sourceFrame=sourceRoot.CFrame
local actor=scene:getOrCreate()
check(actor and actor~=source and actor.Parent==workspace,"H creates one actual local workspace avatar")
check(#worldAdmissions==1,"clone enters the actual workspace once after preparation")
check(actor:FindFirstChild("EquippedShirt").ShirtTemplate=="rbxassetid://actual-outfit","clone preserves the actual replicated outfit")
check(actor.Head.LocalTransparencyModifier==0 and actor.Head.Transparency==.2,"clone clears first-person head masks and preserves authored transparency")
check(actor.ActualEquippedHat.Handle.LocalTransparencyModifier==0,"clone clears first-person accessory masks")
check(not actor.Humanoid.AutomaticScalingEnabled and not actor.Humanoid.EvaluateStateMachine and human.AutomaticScalingEnabled and human.EvaluateStateMachine,"only the solved clone disables future native scaling and locomotion state ticks")
for _,node in ipairs(actor:GetDescendants())do
    check(not forbidden(node) and not node:IsA("ClickDetector"),"world admission strips executable/interface/audio/interaction descendants")
    if node:IsA("BasePart")then check(node.Anchored and not node.CanCollide and not node.CanTouch and not node.CanQuery,"clone cannot affect gameplay physics")end
end
check(actor:FindFirstChild("SeatWeld",true)==nil,"external seat weld is removed from the clone")
check((actor["Left Leg"].CFrame.UpVector-Vector3.yAxis).Magnitude<.001,"seated leg transform is reconstructed as a standing rest pose")
check(math.abs(actor["Left Leg"].Position.Y-1.04)<.001,"standing feet reach the probed club floor")
check(actor.HumanoidRootPart.Position.Z>=3,"standing view is placed behind the chair, away from the table")
check(overlaps[#overlaps].size.Y>4 and overlaps[#overlaps].size.X>=2.5,"space check uses full avatar dimensions")
check(human.Sit and human.SeatPart and sourceRoot.CFrame==sourceFrame and sourceRoot.Anchored and human.WalkSpeed==0,"live seated authority and movement are untouched")
check(math.abs(source.Torso["Left Hip"].Transform.UpVector.Z-1)<.001 and legs[1].Position.Y==2,"source seated joint transforms and limb positions remain untouched")
check(sourceHead.LocalTransparencyModifier==1 and sourceHead.Transparency==.2 and not source.Archivable,"live appearance masks and Archivable flag are restored")
check(scene:getOrCreate()==actor and source._cloneCount==1,"per-frame provider reuses one owned clone")

local placement=actor.HumanoidRootPart.CFrame
source.EquippedShirt.ShirtTemplate="rbxassetid://new-authoritative-outfit"
player:SetAttribute("SpyAppearanceRevision",2)
check(scene:getOrCreate()==actor,"open view keeps its current actor while an appearance batch settles")
advance(.1)
local refreshed=scene:getOrCreate()
check(refreshed~=actor and actor._destroyed and refreshed.Parent==workspace,"appearance revision replaces and destroys the previous clone")
check((refreshed.HumanoidRootPart.Position-placement.Position).Magnitude<.001,"appearance refresh preserves the scene position")
check(refreshed.EquippedShirt.ShirtTemplate=="rbxassetid://new-authoritative-outfit","appearance refresh uses actual current replicated wardrobe")
scene:refresh({hat="new-hat"})
advance(.1)
local refreshedAgain=scene:getOrCreate()
check(refreshedAgain~=refreshed and refreshed._destroyed,"profile equipment change invalidates the clone")
scene:refresh({hat="new-hat"})
check(scene:getOrCreate()==refreshedAgain,"unchanged equipment profile does not create another clone")
player:SetAttribute("SpyAppearanceRevision",3);advance(.1)
local earlyRevision=scene:getOrCreate()
source.EquippedShirt.ShirtTemplate="rbxassetid://delayed-replication"
check(scene:getOrCreate()==earlyRevision,"a late visual property joins one settled refresh")
advance(.1)
local lateOutfit=scene:getOrCreate()
check(lateOutfit.EquippedShirt.ShirtTemplate=="rbxassetid://delayed-replication" and earlyRevision._destroyed,"visual properties arriving after the revision still reach the standing actor")
local newHat=object("Accessory","LateReplicatedHat")
local newHandle=object("Part","Handle",newHat);newHandle.Size=vector(2,.5,1)
local newWeld=object("Weld","AccessoryWeld",newHandle);newWeld.Part0=source.Head;newWeld.Part1=newHandle;newWeld.C0=CFrame.new(0,.8,0);newWeld.C1=CFrame.new()
newHat.Parent=source;advance(.1)
local lateAccessory=scene:getOrCreate()
check(lateAccessory:FindFirstChild("LateReplicatedHat") and lateOutfit._destroyed,"accessory descendants arriving after the revision refresh the world appearance")
source.Head.LocalTransparencyModifier=.8;source.Head.CFrame=CFrame.new(0,4.5,.1)
source.Torso["Left Hip"].Transform=CFrame.Angles(1.4,0,0)
advance(.1)
check(scene:getOrCreate()==lateAccessory,"native movement, seated animation and first-person masks do not churn clones")
newHat.Parent=nil;advance(.1)
local removedAccessory=scene:getOrCreate()
check(not removedAccessory:FindFirstChild("LateReplicatedHat") and lateAccessory._destroyed,"replicated removal refreshes the actual outfit")
check(#newHandle:GetPropertyChangedSignal("Size")._connections>0 and not newHandle:GetPropertyChangedSignal("Size")._connections[1].Connected,"removed appearance descendants release property observers")
scene:clear()
check(removedAccessory._destroyed,"closing H destroys its world actor")
local beforeErrors=#errors
source._cloneError=true
check(scene:getOrCreate()==nil and #errors==beforeErrors+1 and not source.Archivable,"clone errors fail clearly and restore the live clone flag")
source._cloneError=false;floorAvailable=false
check(scene:getOrCreate()==nil,"missing real club floor cannot create an out-of-world stand-in")
floorAvailable=true;blocked=true
check(scene:getOrCreate()==nil,"occupied club space cannot create a stand-in through furniture")
blocked=false
local beforeRespawn=scene:getOrCreate()
local replacement=object("Model","NewCharacter",workspace)
player.Character=replacement;player.CharacterAdded:Fire(replacement)
check(beforeRespawn._destroyed and invalidations==1,"respawn clears the clone and invalidates the camera view")
scene:destroy()
check(scene:getOrCreate()==nil,"destroyed controller cannot respawn leaked world objects")

-- R15 limbs form a longer graph, with a separate knee that must also leave its
-- seated animation transform. Classic replacement heads remain welded in place.
local r15Player,r15Source=fixture()
r15Source.Torso.Name="LowerTorso"
local lower=r15Source.LowerTorso
local upper=object("Part","UpperTorso",r15Source);upper.Size=vector(2,1,1)
local waist=object("Motor6D","Waist",lower);waist.Part0=lower;waist.Part1=upper
waist.C0=CFrame.new(0,1,0);waist.C1=CFrame.new();waist.Transform=CFrame.Angles(.5,0,0)
lower.Neck.Part0=upper
for _,side in ipairs({"Left","Right"})do
    local thigh=r15Source:FindFirstChild(side.." Leg");thigh.Name=side.."UpperLeg";thigh.Size=vector(1,1,1)
    local hip=lower:FindFirstChild(side.." Hip");hip.C1=CFrame.new(0,.5,0)
    local shin=object("Part",side.."LowerLeg",r15Source);shin.Size=vector(1,1,1)
    local knee=object("Motor6D",side.."Knee",thigh);knee.Part0=thigh;knee.Part1=shin
    knee.C0=CFrame.new(0,-.5,0);knee.C1=CFrame.new(0,.5,0);knee.Transform=CFrame.Angles(-1.5,0,0)
end
local classicHead=object("Part","SpyClassicHead",r15Source);classicHead.Size=vector(2,1,1)
local faceWeld=object("Weld","ClassicHeadWeld",classicHead);faceWeld.Part0=r15Source.Head;faceWeld.Part1=classicHead
faceWeld.C0=CFrame.new();faceWeld.C1=CFrame.new()
local room=object("Model","SpyMatchRoom",workspace)
local mainFloor=object("Part","MainFloor",room);mainFloor.CanCollide=true
local r15Scene=StandIn.new(r15Player)
local r15=r15Scene:getOrCreate()
check(r15 and (r15.LeftLowerLeg.CFrame.UpVector-Vector3.yAxis).Magnitude<.001,"R15 knee and hip seating transforms are both reset")
check((r15.SpyClassicHead.Position-r15.Head.Position).Magnitude<.001,"the authored classic head remains attached in the standing rest graph")
check(probes[#probes].params.FilterType==Enum.RaycastFilterType.Include and probes[#probes].params.FilterDescendantsInstances[1]==mainFloor,"match probes its authored club floor, never a tabletop or chair back")
local deathActor=r15Scene:getOrCreate();r15Source.Humanoid.Died:Fire()
check(deathActor._destroyed,"death clears the world actor even before CharacterRemoving")
r15Scene:destroy()
local delayedPlayer,delayedSource,delayedHuman=fixture()
delayedHuman.Parent=nil
local delayedScene=StandIn.new(delayedPlayer)
delayedHuman.Parent=delayedSource
local delayedActor=delayedScene:getOrCreate()
delayedHuman.Died:Fire()
check(delayedActor and delayedActor._destroyed,"a Humanoid replicated after CharacterAdded still receives death cleanup")
delayedScene:destroy()
local left=0
for _,node in ipairs(workspace:GetChildren())do if node:GetAttribute("SpyCharacterStandIn")then left+=1 end end
check(left==0,"closed, failed, respawned and destroyed sessions leave no workspace stand-ins")
check(activeConnections()==0,"destroyed controllers release all player, character and visual-property observers")
print("Character scene stand-in: "..checks.." checks passed")
