-- Vincent is an authored, saved R6 Humanoid, never an HTTP-dependent placeholder.
local Npc={}
local bound=setmetatable({}, {__mode="k"})
local function joint(parent,name,a,b,c0,c1)
    local m=parent:FindFirstChild(name) or Instance.new("Motor6D")
    m.Name,m.Part0,m.Part1=name,a,b
    m.C0,m.C1=c0 or CFrame.new(),c1 or CFrame.new();m.Parent=parent;return m
end
function Npc.spawn(world)
    local m=world:FindFirstChild("Bartender")
    assert(m and m:FindFirstChild("Head"),"Saved Vincent rig is missing from the canonical scene")
    if bound[m] then return m end
    local root,torso,head=m.HumanoidRootPart,m.Torso,m.Head
    root.Anchored=true;m.PrimaryPart=root
    local hum=m:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
    hum.Name,hum.WalkSpeed,hum.AutoRotate,hum.BreakJointsOnDeath="Humanoid",0,false,false
    hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;hum.Parent=m
    if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent=hum end
    joint(root,"RootJoint",root,torso)
    joint(torso,"Neck",torso,head,CFrame.new(0,1,0),CFrame.new(0,-.5,0))
    joint(torso,"Left Shoulder",torso,m["Left Arm"],CFrame.new(-1,.5,0),CFrame.new(.5,.5,0))
    joint(torso,"Right Shoulder",torso,m["Right Arm"],CFrame.new(1,.5,0),CFrame.new(-.5,.5,0))
    joint(torso,"Left Hip",torso,m["Left Leg"],CFrame.new(-.5,-1,0),CFrame.new(0,1,0))
    joint(torso,"Right Hip",torso,m["Right Leg"],CFrame.new(.5,-1,0),CFrame.new(0,1,0))
    local mesh=head:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh")
    mesh.MeshType,mesh.Scale,mesh.Parent=Enum.MeshType.Head,Vector3.new(1.1,1.1,1.1),head
    local face=head:FindFirstChild("face") or Instance.new("Decal")
    face.Name,face.Texture,face.Face,face.Parent="face","rbxasset://textures/face.png",Enum.NormalId.Front,head
    local spec=require(script.Parent.WorldSpec)
    for _,d in ipairs(spec.parts) do
        if d.group=="Bartender" and d.attach then
            local part=m:FindFirstChild(d.name);local target=m:FindFirstChild(d.attach)
            if part and target then
                local w=part:FindFirstChild("DetailWeld") or Instance.new("WeldConstraint")
                w.Name,w.Part0,w.Part1,w.Parent="DetailWeld",target,part,part
            end
        end
    end
    for _,part in ipairs(m:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide=false;part.Massless=true;part.Anchored=part==root end
    end
    local gui=head:FindFirstChild("ConciergeName") or Instance.new("BillboardGui")
    gui.Name,gui.Size,gui.StudsOffset,gui.MaxDistance,gui.Parent="ConciergeName",UDim2.fromOffset(180,30),Vector3.new(0,1.25,0),20,head
    local label=gui:FindFirstChild("Name") or Instance.new("TextLabel")
    label.Name,label.Size,label.BackgroundTransparency="Name",UDim2.fromScale(1,1),1
    label.Text,label.TextColor3,label.TextSize,label.Font="Винсент",Color3.fromRGB(228,214,185),15,Enum.Font.BuilderSansMedium
    label:SetAttribute("TextKey","vincentName");label.Parent=gui
    bound[m]=true
    return m
end
return Npc
