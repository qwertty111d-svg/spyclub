-- Executes the real Preview3D module. Only Roblox engine boundaries are supplied
-- here: Instances, immutable vector/frame math, signals, services and task time.
-- It cannot validate native texture loading, font rendering or pixel composition.
local checks=0
local function check(value,message)
    checks+=1
    assert(value,message)
end
local enumCache={}
local function enumBranch(prefix)
    return setmetatable({}, {__index=function(self,key)
        local name=prefix.."."..key
        local item=enumCache[name]
        if not item then item=enumBranch(name);enumCache[name]=item end
        rawset(self,key,item);return item
    end})
end
local Enum=enumBranch("Enum")
local vectorMeta={}
local function vector(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vectorMeta)end
vectorMeta.__index=function(v,key)
    if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end
    if key=="Unit" then return v/v.Magnitude end
    if key=="Dot" then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
    if key=="Cross" then return function(a,b)return vector(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end end
    if key=="Lerp" then return function(a,b,t)return a+(b-a)*t end end
end
vectorMeta.__add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vectorMeta.__sub=function(a,b)return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vectorMeta.__unm=function(v)return vector(-v.X,-v.Y,-v.Z)end
vectorMeta.__mul=function(a,b)
    if type(a)=="number" then return vector(a*b.X,a*b.Y,a*b.Z)end
    if type(b)=="number" then return vector(a.X*b,a.Y*b,a.Z*b)end
    return vector(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
vectorMeta.__div=function(a,b)return vector(a.X/b,a.Y/b,a.Z/b)end
local Vector3={new=vector,zero=vector(),one=vector(1,1,1),xAxis=vector(1,0,0),yAxis=vector(0,1,0),zAxis=vector(0,0,1)}
local Vector2={new=function(x,y)return vector(x,y,0)end,zero=vector()}
local frameMeta={}
local function frame(position,right,up,back)
    return setmetatable({Position=position or vector(),_right=right or vector(1,0,0),
        _up=up or vector(0,1,0),_back=back or vector(0,0,1)},frameMeta)
end
local function transform(cf,v)return cf._right*v.X+cf._up*v.Y+cf._back*v.Z end
frameMeta.__index=function(cf,key)
    if key=="LookVector"then return -cf._back end
    if key=="RightVector" or key=="XVector"then return cf._right end
    if key=="UpVector" or key=="YVector"then return cf._up end
    if key=="ZVector"then return cf._back end
    if key=="Rotation"then return frame(vector(),cf._right,cf._up,cf._back)end
    if key=="PointToWorldSpace"then return function(a,v)return a.Position+transform(a,v)end end
    if key=="VectorToWorldSpace"then return transform end
    if key=="Inverse"then return function(a)
        local right=vector(a._right.X,a._up.X,a._back.X)
        local up=vector(a._right.Y,a._up.Y,a._back.Y)
        local back=vector(a._right.Z,a._up.Z,a._back.Z)
        local inverse=frame(vector(),right,up,back);inverse.Position=transform(inverse,-a.Position);return inverse
    end end
    if key=="ToObjectSpace"then return function(a,b)return a:Inverse()*b end end
    if key=="PointToObjectSpace"then return function(a,b)return a:Inverse()*b end end
    if key=="VectorToObjectSpace"then return function(a,b)return transform(a:Inverse(),b)end end
end
frameMeta.__mul=function(a,b)
    if getmetatable(b)==vectorMeta then return a.Position+transform(a,b)end
    return frame(a.Position+transform(a,b.Position),transform(a,b._right),transform(a,b._up),transform(a,b._back))
end
frameMeta.__add=function(a,b)return frame(a.Position+b,a._right,a._up,a._back)end
frameMeta.__sub=function(a,b)return frame(a.Position-b,a._right,a._up,a._back)end
local CFrame={}
function CFrame.new(x,y,z)
    return frame(getmetatable(x)==vectorMeta and x or vector(x,y,z))
end
function CFrame.Angles(x,y,z)
    local sx,cx,sy,cy,sz,cz=math.sin(x),math.cos(x),math.sin(y),math.cos(y),math.sin(z),math.cos(z)
    return frame(vector(),vector(cy*cz,cx*sz+sx*sy*cz,sx*sz-cx*sy*cz),
        vector(-cy*sz,cx*cz-sx*sy*sz,sx*cz+cx*sy*sz),vector(sy,-sx*cy,cx*cy))
end
function CFrame.lookAt(position,target,up)
    local back=(position-target).Unit
    local right=(up or Vector3.yAxis):Cross(back).Unit
    return frame(position,right,back:Cross(right),back)
end
function CFrame.fromMatrix(position,right,up,back)return frame(position,right,up,back or right:Cross(up))end
CFrame.identity=CFrame.new()
local Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end,new=function(r,g,b)return {R=r,G=g,B=b}end}
local UDim={new=function(scale,offset)return {Scale=scale,Offset=offset}end}
local UDim2={new=function(xs,xo,ys,yo)return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end}
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
local allSignals={}
local function signal()
    local event={_connections={}}
    function event:Connect(callback)
        local connection={Connected=true,_callback=callback}
        function connection:Disconnect()self.Connected=false end
        self._connections[#self._connections+1]=connection;return connection
    end
    function event:Fire(...)
        for _,connection in ipairs(table.clone(self._connections))do
            if connection.Connected then connection._callback(...)end
        end
    end
    function event:DisconnectAll()for _,connection in ipairs(self._connections)do connection:Disconnect()end end
    allSignals[#allSignals+1]=event;return event
end
local function activeConnections()
    local count=0
    for _,event in ipairs(allSignals)do for _,connection in ipairs(event._connections)do if connection.Connected then count+=1 end end end
    return count
end
local clock,scheduled=0,{}
local task={}
local function schedule(delay,callback,...)
    local thread=type(callback)=="thread" and callback or coroutine.create(callback)
    scheduled[#scheduled+1]={at=clock+delay,thread=thread,args={...}}
    return thread
end
function task.spawn(callback,...)return schedule(0,callback,...)end
function task.defer(callback,...)return schedule(0,callback,...)end
function task.delay(delay,callback,...)return schedule(delay,callback,...)end
function task.wait(delay)return coroutine.yield(delay or .03)end
function task.cancel(thread)
    for index=#scheduled,1,-1 do if scheduled[index].thread==thread then table.remove(scheduled,index)end end
end
local function advance(seconds)
    local limit=clock+seconds
    local executed=0
    while true do
        local nextIndex,nextAt
        for index,item in ipairs(scheduled)do
            if item.at<=limit and (not nextAt or item.at<nextAt)then nextIndex,nextAt=index,item.at end
        end
        if not nextIndex then break end
        executed+=1;assert(executed<=256,"portrait task retries did not remain bounded")
        clock=nextAt
        local item=table.remove(scheduled,nextIndex)
        local ok,delay=coroutine.resume(item.thread,table.unpack(item.args))
        assert(ok,delay)
        if coroutine.status(item.thread)~="dead"then schedule(delay or .03,item.thread)end
    end
    clock=limit
end
local objectMethods,instanceMeta={},{}
local worldAdmissions={}
local function forbidden(node)
    return node:IsA("LuaSourceContainer") or node:IsA("ProximityPrompt") or node:IsA("Dialog")
        or node:IsA("BillboardGui") or node:IsA("SurfaceGui")
end
instanceMeta.__index=function(instance,key)
    if objectMethods[key]then return objectMethods[key]end
    if key=="Parent"then return rawget(instance,"_parent")end
    if key=="Position"then return instance.CFrame.Position end
    local value=instance._properties[key]
    if value~=nil then return value end
    for _,child in ipairs(instance._children)do if child.Name==key then return child end end
end
instanceMeta.__newindex=function(instance,key,value)
    if key:sub(1,1)=="_"then rawset(instance,key,value);return end
    if key=="Parent"then
        local previous=instance.Parent
        if previous==value then return end
        if value and value:IsA("WorldModel") and instance:IsA("Model")then
            local safe=true
            for _,node in ipairs(instance:GetDescendants())do
                if forbidden(node)then safe=false end
                if node:IsA("BasePart") and (not node.Anchored or node.CanCollide or node.CanTouch or node.CanQuery)then safe=false end
            end
            worldAdmissions[#worldAdmissions+1]={model=instance,safe=safe}
        end
        if previous then
            for index,child in ipairs(previous._children)do if child==instance then table.remove(previous._children,index);break end end
            previous.ChildRemoved:Fire(instance)
        end
        rawset(instance,"_parent",value)
        if value then
            value._children[#value._children+1]=instance;value.ChildAdded:Fire(instance)
            local ancestor=value
            while ancestor do ancestor.DescendantAdded:Fire(instance);ancestor=ancestor.Parent end
        end
        instance.AncestryChanged:Fire(instance,value)
    else
        local previous=instance._properties[key];instance._properties[key]=value
        if previous~=value and instance._propertySignals[key]then instance._propertySignals[key]:Fire()end
    end
end
function objectMethods:IsA(class)
    if self.ClassName==class or class=="Instance"then return true end
    if class=="BasePart"then return self.ClassName=="Part" or self.ClassName=="MeshPart"end
    if class=="LuaSourceContainer"then return self.ClassName=="Script" or self.ClassName=="LocalScript" or self.ClassName=="ModuleScript"end
    if class=="PVInstance"then return self:IsA("BasePart") or self:IsA("Model")end
    return false
end
function objectMethods:GetChildren()return table.clone(self._children)end
function objectMethods:GetDescendants()
    local descendants={}
    local function walk(parent)for _,child in ipairs(parent._children)do descendants[#descendants+1]=child;walk(child)end end
    walk(self);return descendants
end
function objectMethods:FindFirstChild(name,recursive)
    for _,child in ipairs(self._children)do if child.Name==name then return child end end
    if recursive then for _,child in ipairs(self._children)do local found=child:FindFirstChild(name,true);if found then return found end end end
end
function objectMethods:FindFirstChildOfClass(class)
    for _,child in ipairs(self._children)do if child.ClassName==class then return child end end
end
function objectMethods:FindFirstChildWhichIsA(class,recursive)
    for _,child in ipairs(recursive and self:GetDescendants() or self:GetChildren())do if child:IsA(class)then return child end end
end
function objectMethods:WaitForChild(name)return self:FindFirstChild(name)end
function objectMethods:IsDescendantOf(ancestor)
    local parent=self.Parent;while parent do if parent==ancestor then return true end;parent=parent.Parent end;return false
end
function objectMethods:GetPropertyChangedSignal(key)
    if not self._propertySignals[key]then self._propertySignals[key]=signal()end
    return self._propertySignals[key]
end
function objectMethods:SetAttribute(key,value)
    local previous=self._attributes[key];self._attributes[key]=value
    if previous~=value and self._attributeSignals[key]then self._attributeSignals[key]:Fire()end
end
function objectMethods:GetAttribute(key)return self._attributes[key]end
function objectMethods:GetAttributeChangedSignal(key)
    if not self._attributeSignals[key]then self._attributeSignals[key]=signal()end
    return self._attributeSignals[key]
end
function objectMethods:Destroy()
    if self._destroyed then return end
    self._destroyed=true;self.Destroying:Fire()
    for _,child in ipairs(self:GetChildren())do child:Destroy()end
    self.Parent=nil
    for _,event in pairs(self._propertySignals)do event:DisconnectAll()end
    for _,event in pairs(self._attributeSignals)do event:DisconnectAll()end
    for _,event in ipairs(self._events)do event:DisconnectAll()end
end
function objectMethods:GetPivot()
    if self.PrimaryPart then return self.PrimaryPart.CFrame end
    return self.WorldPivot
end
function objectMethods:PivotTo(target)
    local delta=target*self:GetPivot():Inverse()
    for _,part in ipairs(self:GetDescendants())do if part:IsA("BasePart")then part.CFrame=delta*part.CFrame end end
    self.WorldPivot=target
end
function objectMethods:GetBoundingBox()
    local low,high=vector(math.huge,math.huge,math.huge),vector(-math.huge,-math.huge,-math.huge)
    local count=0
    for _,part in ipairs(self:GetDescendants())do if part:IsA("BasePart")then
        count+=1
        for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
            local corner=part.CFrame*(part.Size*vector(x,y,z))
            low=vector(math.min(low.X,corner.X),math.min(low.Y,corner.Y),math.min(low.Z,corner.Z))
            high=vector(math.max(high.X,corner.X),math.max(high.Y,corner.Y),math.max(high.Z,corner.Z))
        end end end
    end end
    if count==0 then return CFrame.new(),vector()end
    return CFrame.new((low+high)/2),high-low
end
local Instance={}
function Instance.new(class)
    local instance=setmetatable({_properties={ClassName=class,Name=class,Archivable=true,
        CFrame=CFrame.new(),WorldPivot=CFrame.new(),Size=vector(1,1,1),AbsoluteSize=Vector2.zero,
        ZIndex=1,BackgroundTransparency=0,Transparency=0,CanCollide=true,CanTouch=true,CanQuery=true,
        Anchored=false,FieldOfView=70,Visible=true,Enabled=true},_children={},_attributes={},
        _propertySignals={},_attributeSignals={},_events={}},instanceMeta)
    for _,name in ipairs({"Destroying","AncestryChanged","ChildAdded","ChildRemoved","DescendantAdded","InputBegan","InputChanged","InputEnded"})do
        local event=signal();instance._properties[name]=event;instance._events[#instance._events+1]=event
    end
    return instance
end
function objectMethods:Clone()
    self._cloneCount=(self._cloneCount or 0)+1
    if self._cloneError then error("injected engine Clone failure")end
    if not self.Archivable then return nil end
    local copies={}
    local function copy(source)
        if not source.Archivable then return nil end
        local clone=Instance.new(source.ClassName);copies[source]=clone
        for key,value in pairs(source._properties)do
            if not table.find(source._events,value)then clone[key]=value end
        end
        clone._attributes=table.clone(source._attributes)
        for _,child in ipairs(source:GetChildren())do local nextChild=copy(child);if nextChild then nextChild.Parent=clone end end
        return clone
    end
    local root=copy(self)
    for _,clone in pairs(copies)do
        for key,value in pairs(clone._properties)do if copies[value]then clone[key]=copies[value]end end
    end
    return root
end
local function object(class,name,parent)
    local instance=Instance.new(class);instance.Name=name;instance.Parent=parent;return instance
end
local workspace=object("Workspace","Workspace")
local services={Workspace=workspace,ReplicatedStorage=object("ReplicatedStorage","ReplicatedStorage"),
    ServerStorage=object("ServerStorage","ServerStorage"),Players={LocalPlayer={}},
    RunService={RenderStepped=signal(),Heartbeat=signal()},
    UserInputService={InputChanged=signal(),InputEnded=signal()},TweenService={}}
local game={GetService=function(_,name)assert(services[name],"unexpected service: "..name);return services[name]end}
local script={Parent={Art="Art",Wardrobe="Wardrobe"}}
local wardrobeCalls=0
local modules={Art={},Wardrobe=setmetatable({}, {__index=function(_,key)
    return function()wardrobeCalls+=1;error("NPC portrait must preserve authored appearance without Wardrobe."..key)end
end})}
local function require(module)assert(modules[module],"unexpected module require");return modules[module]end
local warnings={}
local function warn(message)warnings[#warnings+1]=message end
local nativeTypeof=typeof
local function typeof(value)
    if getmetatable(value)==instanceMeta then return "Instance"end
    if getmetatable(value)==vectorMeta then return "Vector3"end
    if getmetatable(value)==frameMeta then return "CFrame"end
    return nativeTypeof(value)
end

-- INSERT_REAL_PREVIEW3D_MODULE

check(type(Preview3D.mountNPC)=="function","Preview3D.mountNPC must expose the native Vincent portrait helper")
local function reset()
    for _,child in ipairs(workspace:GetChildren())do child:Destroy()end
    for _,name in ipairs({"ReplicatedStorage","ServerStorage"})do
        for _,child in ipairs(services[name]:GetChildren())do child:Destroy()end
    end
    advance(10)
    worldAdmissions={};warnings={};wardrobeCalls=0
    local camera=object("Camera","MainCamera",workspace)
    camera.CFrame=CFrame.new(10,20,30);camera.FieldOfView=74;camera.CameraType=Enum.CameraType.Custom
    workspace.CurrentCamera=camera
    return camera
end
local function host()
    local parent=object("Frame","IdentityColumn",workspace);parent.ZIndex=4
    parent.AbsoluteSize=Vector2.new(260,360);return parent
end
local function npc(parent,name)
    local model=object("Model",name or "VincentVisual",parent)
    model.Archivable=false;model.WorldPivot=CFrame.new(9000,-7000,5000)
    model:SetAttribute("AuthoredNPC","VincentV136")
    local origin=CFrame.new(128,40,-62)*CFrame.Angles(0,math.rad(31),0)
    local function part(name,position,size)
        local item=object("Part",name,model)
        item.CFrame=origin*CFrame.new(position);item.Size=size
        item.Color=Color3.fromRGB(213,181,154);item.Material=Enum.Material.SmoothPlastic
        return item
    end
    local head=part("Head",vector(0,3.5,0),vector(2,1,1))
    local torso=part("Torso",vector(0,2,0),vector(2,2,1))
    part("Hat",vector(0,4.35,0),vector(3,.8,2))
    part("Left Arm",vector(-1.5,2,0),vector(1,2,1))
    part("Right Arm",vector(1.5,2,0),vector(1,2,1))
    part("Left Leg",vector(-.5,0,0),vector(1,2,1))
    part("Right Leg",vector(.5,0,0),vector(1,2,1))
    local mesh=object("SpecialMesh","AuthoredHeadMesh",head);mesh.MeshId="rbxassetid://native-head";mesh.TextureId="rbxassetid://native-skin"
    local decal=object("Decal","face",head);decal.Texture="rbxassetid://native-face"
    local shirt=object("Shirt","Shirt",model);shirt.ShirtTemplate="rbxassetid://native-shirt"
    local pants=object("Pants","Pants",model);pants.PantsTemplate="rbxassetid://native-pants"
    local joint=object("Weld","AuthoredWeld",torso);joint.Part0=torso;joint.Part1=head
    object("Snap","AuthoredSnap",head)
    local humanoid=object("Humanoid","Humanoid",model)
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.Viewer
    humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
    humanoid.NameDisplayDistance=100;humanoid.HealthDisplayDistance=100
    for _,class in ipairs({"Script","LocalScript","ModuleScript","ProximityPrompt","Dialog","BillboardGui","SurfaceGui"})do
        object(class,"Unsafe"..class,head)
    end
    return model
end
local function mounted(parent,source)
    local viewport=Preview3D.mountNPC(parent,source)
    check(viewport and viewport:IsA("ViewportFrame"),"mountNPC returns its native ViewportFrame")
    advance(0)
    return viewport
end
local function portraitModel(viewport)
    local world=viewport:FindFirstChildWhichIsA("WorldModel")
    check(world~=nil,"portrait isolates the NPC in a WorldModel")
    return world:FindFirstChildWhichIsA("Model"),world
end
local failures,passed=0,0
local function test(name,callback)
    reset()
    local ok,message=pcall(callback)
    if ok then passed+=1;print("PASS: "..name)else failures+=1;print("FAIL: "..name..": "..tostring(message))end
end

test("authored NPC appearance survives safe cloning",function()
    local parent=host()
    local source=npc(workspace)
    local sourcePivot,sourceHead=source:GetPivot(),source.Head.CFrame
    local viewport=mounted(parent,source)
    check(viewport.Name=="VincentPortrait" and viewport.Parent==parent,"portrait belongs to its identity column")
    check(viewport:GetAttribute("PortraitReady")==true,"native success publishes readiness for the textual fallback")
    check(source.Archivable==false,"successful cloning restores the original Archivable flag")
    local clone=portraitModel(viewport)
    check(clone~=nil and clone~=source,"portrait renders a clone, leaving the world NPC in place")
    check(clone:GetAttribute("AuthoredNPC")=="VincentV136","clone retains authored identity")
    check(clone:FindFirstChild("AuthoredHeadMesh",true).MeshId==source.Head.AuthoredHeadMesh.MeshId,"authored mesh is preserved")
    check(clone.Head.face.Texture==source.Head.face.Texture,"authored face decal is preserved")
    check(clone.Shirt.ShirtTemplate==source.Shirt.ShirtTemplate and clone.Pants.PantsTemplate==source.Pants.PantsTemplate,"authored classic clothing is preserved")
    check(clone.Torso.AuthoredWeld.Part0==clone.Torso and clone.Torso.AuthoredWeld.Part1==clone.Head,"cloned joints keep internal clone references")
    check(clone.Head:FindFirstChild("AuthoredSnap")~=nil,"authored non-script rig joints remain")
    local parts=0
    for _,node in ipairs(clone:GetDescendants())do
        check(not forbidden(node),"portrait removes active world content: "..node.ClassName)
        if node:IsA("BasePart")then
            parts+=1
            check(node.Anchored and not node.CanCollide and not node.CanTouch and not node.CanQuery,"portrait geometry cannot simulate or interact")
        end
    end
    check(parts==7,"portrait retains all seven authored physical parts")
    check(clone.Humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.None,"portrait suppresses the native nameplate")
    check(#worldAdmissions==1 and worldAdmissions[1].safe,"NPC clone is sanitized before entering the WorldModel")
    check(source:GetPivot()==sourcePivot and source.Head.CFrame==sourceHead,"portrait never moves the real NPC or its stale saved pivot")
    check(source.Head.CanCollide and source.Head:FindFirstChild("UnsafeScript")~=nil,"sanitization cannot alter the real NPC")
    check(wardrobeCalls==0,"portrait never rerenders authored clothing through Wardrobe")
    parent:Destroy()
end)

test("physical head framing and resize use a private neutral camera",function()
    local mainCamera=workspace.CurrentCamera
    local mainCFrame,mainFov=mainCamera.CFrame,mainCamera.FieldOfView
    local parent=host()
    local source=npc(workspace)
    local viewport=mounted(parent,source)
    local clone=portraitModel(viewport)
    local camera=viewport.CurrentCamera
    check(camera and camera~=mainCamera and camera:IsDescendantOf(viewport),"portrait owns its camera")
    check(viewport.Ambient.R==viewport.Ambient.G and viewport.Ambient.G==viewport.Ambient.B,"portrait ambient is neutral gray")
    check(viewport.LightColor.R==1 and viewport.LightColor.G==1 and viewport.LightColor.B==1,"portrait key light is white")
    viewport.AbsoluteSize=Vector2.new(300,360)
    advance(0)
    local wideDistance=(camera.CFrame.Position-clone.Head.Position).Magnitude
    check(wideDistance>1 and wideDistance<30,"camera frames physical head/torso despite a distant saved pivot")
    check(camera.CFrame.LookVector:Dot((clone.Head.Position-camera.CFrame.Position).Unit)>.9,"camera looks toward the authored face")
    viewport.AbsoluteSize=Vector2.new(90,360)
    advance(0)
    local narrowDistance=(camera.CFrame.Position-clone.Head.Position).Magnitude
    check(narrowDistance>wideDistance*1.3,"narrowing the portrait backs the camera away to retain the bust")
    check(workspace.CurrentCamera==mainCamera and mainCamera.CFrame==mainCFrame and mainCamera.FieldOfView==mainFov,
        "portrait cannot acquire or mutate the player's world camera")
    check(mainCamera.CameraType==Enum.CameraType.Custom,"portrait cannot lease the gameplay camera")
    parent:Destroy()
end)

test("default lookup selects only the authored SpyClub VincentVisual",function()
    local club=object("Model","SpyClub",workspace)
    local source=npc(club)
    local legacy=npc(services.ServerStorage,"Bartender")
    local wrongRoot=npc(workspace,"VincentVisual")
    local parent=host()
    local viewport=mounted(parent)
    local clone=portraitModel(viewport)
    check(clone and viewport:GetAttribute("PortraitReady")==true,"default source resolves the authored club NPC")
    check(source._cloneCount==1 and not legacy._cloneCount and not wrongRoot._cloneCount,"default resolution never substitutes a legacy or similarly named NPC")
    parent:Destroy()
end)

test("missing native NPC keeps the textual fallback available",function()
    local legacy=npc(services.ServerStorage,"Bartender")
    local wrongRoot=npc(workspace,"VincentVisual")
    local parent=host()
    local viewport=mounted(parent)
    check(viewport:GetAttribute("PortraitReady")==false,"missing source explicitly leaves the UI's text/seal fallback active")
    check(not legacy._cloneCount and not wrongRoot._cloneCount,"missing authored NPC cannot silently use another appearance")
    advance(10)
    check(viewport:GetAttribute("PortraitReady")==false,"bounded source discovery leaves a stable fallback when the NPC never arrives")
    check(#scheduled==0,"missing source cannot create an unbounded retry task")
    parent:Destroy()
end)

test("late native NPC discovery replaces fallback once",function()
    local baseline=activeConnections()
    local parent=host()
    local viewport=mounted(parent)
    check(viewport:GetAttribute("PortraitReady")==false,"initially missing native source preserves the fallback")
    local club=object("Model","SpyClub",workspace)
    local source=npc(club)
    advance(.5)
    check(viewport:GetAttribute("PortraitReady")==true,"source arriving during the bounded discovery window becomes ready")
    local clone=portraitModel(viewport)
    check(clone and clone:GetAttribute("AuthoredNPC")=="VincentV136","late discovery renders the real authored NPC")
    advance(5)
    check(source._cloneCount==1 and #worldAdmissions==1,"successful late discovery stops retrying and cannot duplicate the portrait")
    parent:Destroy()
    check(activeConnections()==baseline,"late discovery still releases all portrait listeners on destruction")
end)

test("incomplete native NPC stays outside the WorldModel with bounded retries",function()
    local parent=host()
    local source=npc(workspace)
    source.Head:Destroy()
    local viewport=mounted(parent,source)
    advance(10)
    check(viewport:GetAttribute("PortraitReady")==false,"missing authored Head leaves the text/seal fallback available")
    check(#worldAdmissions==0,"invalid native clone is rejected before entering the WorldModel")
    check(source._cloneCount and source._cloneCount>=1 and source._cloneCount<=20,"incomplete native source receives at most twenty clone attempts")
    check(#scheduled==0,"incomplete native source cannot keep retrying indefinitely")
    check(source.Archivable==false,"all rejected clone attempts restore the original Archivable flag")
    parent:Destroy()
end)

test("engine Clone failure restores Archivable and preserves fallback",function()
    local source=npc(workspace);source._cloneError=true
    local parent=host()
    local viewport=mounted(parent,source)
    check(source._cloneCount and source._cloneCount>=1,"test exercises an actual failing source Clone call")
    check(source.Archivable==false,"protected clone restores Archivable even when the engine throws")
    check(viewport:GetAttribute("PortraitReady")==false,"Clone failure preserves the textual fallback")
    check(#worldAdmissions==0,"failed clone cannot parent an incomplete NPC into the portrait")
    parent:Destroy()
end)

test("destroyed owner releases listeners and blocks late discovery",function()
    local baseline=activeConnections()
    local parent=host()
    local viewport=mounted(parent)
    parent:Destroy()
    local club=object("Model","SpyClub",workspace)
    local late=npc(club)
    advance(10)
    check(viewport.Parent==nil and #viewport:GetChildren()==0,"owning window destruction removes its viewport tree")
    check(not late._cloneCount,"late native NPC cannot revive a destroyed portrait")
    check(activeConnections()==baseline,"owner destruction releases source discovery and size listeners")
    check(#scheduled==0,"owner destruction cannot leave portrait retry work pending")
end)

test("destroyed populated portrait leaves no listeners or rebuild work",function()
    local baseline=activeConnections()
    local parent=host()
    local source=npc(workspace)
    local viewport=mounted(parent,source)
    local camera=viewport.CurrentCamera
    local previousFrame=camera.CFrame
    local attempts=source._cloneCount
    parent:Destroy()
    viewport.AbsoluteSize=Vector2.new(50,600)
    workspace.DescendantAdded:Fire(source)
    advance(10)
    check(camera.Parent==nil,"destroying the owner removes the private camera")
    check(camera.CFrame==previousFrame,"destroyed viewport resize cannot update a retained camera")
    check(source._cloneCount==attempts,"destroyed portrait cannot rebuild its native clone")
    check(activeConnections()==baseline,"populated portrait releases all owned listeners")
end)

reset()
print("Native NPC portrait: "..passed.." tests, "..checks.." assertions, "..failures.." failures (native rendering not exercised)")
assert(failures==0,"native portrait behavior checks failed")
