-- Match seats remain server-owned. H borrows the replicated appearance on a
-- client-only, standing world rig; it never moves or unseats the real player.
local Workspace=game:GetService("Workspace")
local StandIn={}

local function jointRecord(node,owned)
    local a,b,c0,c1
    if node:IsA("Motor6D") or node:IsA("Weld") then
        a,b,c0,c1=node.Part0,node.Part1,node.C0,node.C1
    elseif node:IsA("AnimationConstraint") or node:IsA("RigidConstraint") then
        local aa,bb=node.Attachment0,node.Attachment1
        if aa and bb then
            a=aa:FindFirstAncestorWhichIsA("BasePart")
            b=bb:FindFirstAncestorWhichIsA("BasePart")
            if a and b then
                c0=a.CFrame:ToObjectSpace(aa.WorldCFrame)
                c1=b.CFrame:ToObjectSpace(bb.WorldCFrame)
            end
        end
    elseif node:IsA("WeldConstraint") then
        a,b=node.Part0,node.Part1
        if a and b then c0=a.CFrame:ToObjectSpace(b.CFrame);c1=CFrame.new() end
    else return end
    if not owned[a] or not owned[b] then node:Destroy();return end
    return {a=a,b=b,c0=c0,c1=c1}
end

local function bounds(parts,rootFrame)
    local low=Vector3.new(math.huge,math.huge,math.huge)
    local high=Vector3.new(-math.huge,-math.huge,-math.huge)
    for _,part in ipairs(parts) do
        local relative=rootFrame:ToObjectSpace(part.CFrame)
        for _,x in ipairs({-.5,.5}) do for _,y in ipairs({-.5,.5}) do for _,z in ipairs({-.5,.5}) do
            local p=relative:PointToWorldSpace(Vector3.new(x*part.Size.X,y*part.Size.Y,z*part.Size.Z))
            low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))
            high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
        end end end
    end
    return low,high
end

local function prepare(copy)
    local owned,parts,body,joints={},{},{},{}
    for _,node in ipairs(copy:GetDescendants()) do
        if node.Parent then
            if node:IsA("LuaSourceContainer") or node:IsA("LayerCollector") or node:IsA("GuiObject")
                or node:IsA("Animator") or node:IsA("AnimationController") or node:IsA("Sound")
                or node:IsA("ProximityPrompt") or node:IsA("ClickDetector") or node:IsA("Dialog")
                or node:IsA("Tool") or node:IsA("ForceField") or node:IsA("ParticleEmitter")
                or node:IsA("Trail") or node:IsA("Beam") or node:IsA("Light") then
                node:Destroy()
            elseif node:IsA("BasePart") then
                node.Anchored=true;node.CanCollide=false;node.CanTouch=false;node.CanQuery=false
                node.LocalTransparencyModifier=0 -- Preserve the authored Transparency, including the invisible root.
                owned[node]=true;parts[#parts+1]=node
                if node.Parent==copy and node.Name~="HumanoidRootPart" then body[#body+1]=node end
            elseif node:IsA("Humanoid") then
                node.Sit=false;node.AutoRotate=false;node.BreakJointsOnDeath=false
                node.AutomaticScalingEnabled=false;node.EvaluateStateMachine=false
                node.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
            elseif node:IsA("Motor6D") or node:IsA("Bone") then
                node.Transform=CFrame.new()
            elseif node:IsA("Constraint") then
                node.Enabled=false
                if node:IsA("AnimationConstraint") then node.Transform=CFrame.new() end
            end
        end
    end
    local root=copy:FindFirstChild("HumanoidRootPart")
    local head=copy:FindFirstChild("Head")
    local torso=copy:FindFirstChild("LowerTorso") or copy:FindFirstChild("Torso")
    if not owned[root] or not owned[head] or not owned[torso] then return nil end
    local original=root.CFrame
    for _,node in ipairs(copy:GetDescendants()) do
        local joint=jointRecord(node,owned)
        if joint then joints[#joints+1]=joint end
    end
    -- Solve rest offsets directly, rather than relying on the clone's last seated
    -- part CFrames or on an Animator/physics tick while every part is anchored.
    root.CFrame=CFrame.new()
    local solved={[root]=true}
    for _=1,#parts do
        local changed=false
        for _,joint in ipairs(joints) do
            local a,b=joint.a,joint.b
            if solved[a] and not solved[b] then
                b.CFrame=a.CFrame*joint.c0*joint.c1:Inverse();solved[b]=true;changed=true
            elseif solved[b] and not solved[a] then
                a.CFrame=b.CFrame*joint.c1*joint.c0:Inverse();solved[a]=true;changed=true
            end
        end
        if not changed then break end
    end
    for _,part in ipairs(body) do if not solved[part] then return nil end end
    -- A detached cosmetic keeps its authored offset, but body parts must have a
    -- complete rest-pose graph so a seated leg cannot silently survive cleanup.
    for _,part in ipairs(parts) do
        if not solved[part] then part.CFrame=original:ToObjectSpace(part.CFrame) end
    end
    local low,high=bounds(parts,CFrame.new())
    local bodyLow=bounds(body,CFrame.new())
    return {root=root,parts=parts,low=low,high=high,footY=bodyLow.Y}
end

local function findPlacement(source,rig,copy,previous)
    local root=source:FindFirstChild("HumanoidRootPart")
    local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
    if forward.Magnitude<.001 then forward=Vector3.new(0,0,-1) else forward=forward.Unit end
    local right=forward:Cross(Vector3.yAxis)
    local candidates={}
    if previous then candidates[#candidates+1]=previous.Position end
    -- Seats face the table. Start behind the chair, then try nearby open club
    -- floor; every candidate is checked against the actual avatar dimensions.
    for _,offset in ipairs({{0,3.25},{0,5},{0,6.75},{3,5},{-3,5},{5,6.75},{-5,6.75},{0,8.5}}) do
        candidates[#candidates+1]=root.Position+right*offset[1]-forward*offset[2]
    end
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={source,copy}
    ray.RespectCanCollide=true
    local room=Workspace:FindFirstChild("SpyMatchRoom")
    local clubFloor=room and room:FindFirstChild("MainFloor")
    if clubFloor and clubFloor:IsA("BasePart") and clubFloor.CanCollide then
        -- The authored floor is known in this place. Probe it directly so a
        -- chair back or tabletop can never be mistaken for standing floor.
        ray.FilterType=Enum.RaycastFilterType.Include
        ray.FilterDescendantsInstances={clubFloor}
    end
    local overlap=OverlapParams.new()
    overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.RespectCanCollide=true
    local size=rig.high-rig.low+Vector3.new(.2,.08,.2)
    local center=(rig.low+rig.high)*.5
    for _,position in ipairs(candidates) do
        local ground=Workspace:Raycast(Vector3.new(position.X,root.Position.Y+6,position.Z),Vector3.new(0,-18,0),ray)
        if ground and ground.Normal.Y>=.7 and ground.Position.Y<root.Position.Y-1
            and root.Position.Y-ground.Position.Y<=10 then
            local at=Vector3.new(position.X,ground.Position.Y-rig.footY+.04,position.Z)
            local target=CFrame.lookAt(at,at+forward)
            overlap.FilterDescendantsInstances={source,copy,ground.Instance}
            local occupied=Workspace:GetPartBoundsInBox(target*CFrame.new(center),size,overlap)
            if #occupied==0 then return target end
        end
    end
    return nil
end

local function equipmentKey(equipped)
    local values={}
    for slot,id in pairs(equipped or {}) do values[#values+1]=tostring(slot).."="..tostring(id) end
    table.sort(values)
    return table.concat(values,"|")
end

function StandIn.new(player,options)
    options=options or {}
    local self={alive=true,dirty=true,connections={},characterConnections={},visualConnections={},refreshToken=0}
    local function disconnect(list)
        for _,connection in ipairs(list) do connection:Disconnect() end
        table.clear(list)
    end
    function self:clear()
        local old=self.model;self.model=nil;self.source=nil;self.placement=nil;self.dirty=true
        self.refreshToken+=1;self.settling=false
        if old then old:Destroy() end
    end
    local function changed()
        self.dirty=true;self.refreshToken+=1
        if not self.model then return end
        -- Player attributes and character descendants can arrive in separate
        -- replication batches. Let one short quiet interval finish the outfit.
        self.settling=true
        local token=self.refreshToken
        task.delay(.08,function()
            if self.alive and self.refreshToken==token then self.settling=false end
        end)
    end
    local function unwatchVisual(node)
        local list=self.visualConnections[node]
        if list then disconnect(list);self.visualConnections[node]=nil end
    end
    local function watchVisual(node)
        if self.visualConnections[node] then return end
        local keys={}
        if node:IsA("BasePart") then
            keys={"Transparency","Color","Material","Size"}
            if node:IsA("MeshPart") then keys[#keys+1]="MeshId";keys[#keys+1]="TextureID" end
        elseif node:IsA("Shirt") then keys={"ShirtTemplate"}
        elseif node:IsA("Pants") then keys={"PantsTemplate"}
        elseif node:IsA("ShirtGraphic") then keys={"Graphic"}
        elseif node:IsA("Decal") then keys={"Texture","Color3","Transparency"}
        elseif node:IsA("SpecialMesh") then keys={"MeshId","TextureId","MeshType","Scale","Offset"}
        elseif node:IsA("SurfaceAppearance") then keys={"ColorMap","MetalnessMap","NormalMap","RoughnessMap"}
        elseif node:IsA("BodyColors") then keys={"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"}
        elseif node:IsA("Motor6D") or node:IsA("Weld") then keys={"C0","C1","Part0","Part1"}
        elseif node:IsA("Attachment") then keys={"CFrame"}
        elseif node:IsA("WeldConstraint") then keys={"Part0","Part1"}
        elseif node:IsA("AnimationConstraint") or node:IsA("RigidConstraint") then keys={"Attachment0","Attachment1"}
        end
        local list={};self.visualConnections[node]=list
        -- Animated CFrame/Transform and first-person visibility masks are not
        -- appearance changes and must never cause per-frame clone rebuilding.
        for _,key in ipairs(keys) do list[#list+1]=node:GetPropertyChangedSignal(key):Connect(changed) end
    end
    local function invalidated()
        self:clear()
        if self.alive and options.onInvalidated then options.onInvalidated() end
    end
    local function watchCharacter(character)
        disconnect(self.characterConnections)
        for node in pairs(self.visualConnections) do unwatchVisual(node) end
        self.human=nil
        if not character then return end
        local human=character:FindFirstChildOfClass("Humanoid")
        self.human=human
        if human then self.characterConnections[#self.characterConnections+1]=human.Died:Connect(invalidated) end
        for _,key in ipairs({"SpyBaseReady","SpyCosmeticsReady"}) do
            self.characterConnections[#self.characterConnections+1]=character:GetAttributeChangedSignal(key):Connect(changed)
        end
        for _,node in ipairs(character:GetDescendants()) do watchVisual(node) end
        self.characterConnections[#self.characterConnections+1]=character.DescendantAdded:Connect(function(node)
            watchVisual(node)
            for _,descendant in ipairs(node:GetDescendants()) do watchVisual(descendant) end
            changed()
        end)
        self.characterConnections[#self.characterConnections+1]=character.DescendantRemoving:Connect(function(node)
            unwatchVisual(node)
            for _,descendant in ipairs(node:GetDescendants()) do unwatchVisual(descendant) end
            changed()
        end)
    end
    self.connections[#self.connections+1]=player.CharacterAdded:Connect(function(character)
        invalidated();watchCharacter(character)
    end)
    self.connections[#self.connections+1]=player.CharacterRemoving:Connect(function()
        invalidated();watchCharacter(nil)
    end)
    for _,key in ipairs({"SpyAppearanceRevision","SpyAppearanceStatus"}) do
        self.connections[#self.connections+1]=player:GetAttributeChangedSignal(key):Connect(changed)
    end
    watchCharacter(player.Character)
    function self:refresh(equipped)
        local key=equipmentKey(equipped)
        if self.equipment~=key then self.equipment=key;changed() end
    end
    function self:getOrCreate()
        if not self.alive then return nil end
        local source=player.Character
        local human=source and source:FindFirstChildOfClass("Humanoid")
        local function fail(reason,copy)
            if copy then copy:Destroy() end
            self:clear()
            if options.onError then options.onError(reason) end
            return nil
        end
        if not source or not source.Parent or not source:FindFirstChild("HumanoidRootPart")
            or not human or human.Health<=0 or source:GetAttribute("SpyBaseReady")==false then
            return fail("appearance_unavailable")
        end
        -- CharacterAdded can precede its replicated Humanoid. Bind death once
        -- the usable source arrives, and never return a dead cached avatar.
        if self.human~=human then watchCharacter(source) end
        if self.model and self.model.Parent==Workspace and self.source==source and (not self.dirty or self.settling) then return self.model end
        local archivable=source.Archivable
        source.Archivable=true
        local cloned,copy=pcall(function()return source:Clone()end)
        source.Archivable=archivable -- No yield while the temporary cloning flag is held.
        if not cloned or not copy then return fail("appearance_unavailable") end
        local ok,rig=pcall(prepare,copy)
        if not ok or not rig then return fail("appearance_unavailable",copy) end
        local placed,target=pcall(findPlacement,source,rig,copy,self.placement)
        if not placed or not target then return fail("space_unavailable",copy) end
        for _,part in ipairs(rig.parts) do part.CFrame=target*part.CFrame end
        copy.Name="SpyMatchCharacterStandIn";copy.PrimaryPart=rig.root
        copy:SetAttribute("SpyCharacterStandIn",true)
        copy.Parent=Workspace
        -- Publish the replacement first so a camera observing the old actor's
        -- removal can resolve the new target without releasing its orbit.
        local old=self.model
        self.model=copy;self.source=source;self.placement=target;self.dirty=false
        if old then old:Destroy() end
        return copy
    end
    function self:destroy()
        self.alive=false;self:clear()
        disconnect(self.connections);watchCharacter(nil)
    end
    return self
end

return StandIn
