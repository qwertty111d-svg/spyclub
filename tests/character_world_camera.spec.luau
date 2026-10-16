-- The real CharacterWorldCamera executes below. Shared native_portrait stubs supply
-- only immutable Roblox math, Instances, signals and task scheduling; these tests
-- cannot exercise native camera rendering or the engine's physical raycaster.
local originalFrameIndex=frameMeta.__index
frameMeta.__index=function(cf,key)
    if key=="Lerp" then return function(a,b,t)
        return frame(a.Position:Lerp(b.Position,t),a._right:Lerp(b._right,t),a._up:Lerp(b._up,t),a._back:Lerp(b._back,t))
    end end
    return originalFrameIndex(cf,key)
end
vectorMeta.__eq=function(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
frameMeta.__eq=function(a,b)return a.Position==b.Position and a._right==b._right and a._up==b._up and a._back==b._back end
Enum.RenderPriority.Camera.Value=200
local RunService=services.RunService
local renderSteps={}
local bindFailure
function RunService:BindToRenderStep(name,priority,callback)
    if bindFailure then error("injected render binding failure") end
    assert(not renderSteps[name],"render name already bound")
    renderSteps[name]={priority=priority,callback=callback}
end
function RunService:UnbindFromRenderStep(name)renderSteps[name]=nil end
local function step(dt)
    local callbacks={}
    for _,entry in pairs(renderSteps)do callbacks[#callbacks+1]=entry end
    table.sort(callbacks,function(a,b)return a.priority<b.priority end)
    for _,entry in ipairs(callbacks)do entry.callback(dt)end
    advance(0)
end
local Actions={bound={}}
function Actions:BindActionAtPriority(name,callback,touch,priority,...)
    self.bound[name]={callback=callback,touch=touch,priority=priority,inputs={...}}
end
function Actions:UnbindAction(name)self.bound[name]=nil end
services.ContextActionService=Actions
local Input=services.UserInputService
local RaycastParams={new=function()return {}end}
local raycast
workspace.Raycast=function(_,origin,direction,params)
    check(params.FilterType==Enum.RaycastFilterType.Exclude and params.IgnoreWater==true,"collision excludes the actor and water")
    return raycast and raycast(origin,direction,params) or nil
end

-- CHARACTER_WORLD_CAMERA_SOURCE_INSERT

local controllers={}
local player,camera,controls,rect,actor,human,root
local cameraWriteFailure
local originalInstanceNewIndex=instanceMeta.__newindex
instanceMeta.__newindex=function(instance,key,value)
    if instance==camera and key==cameraWriteFailure then
        cameraWriteFailure=nil
        error("injected partial camera property write failure")
    end
    return originalInstanceNewIndex(instance,key,value)
end
local function count(map)local n=0;for _ in pairs(map)do n+=1 end;return n end
local function near(a,b,epsilon)return math.abs(a-b)<(epsilon or 1e-6)end
local function character(name,yaw)
    local model=object("Model",name or "Character",workspace)
    local rootPart=object("Part","HumanoidRootPart",model)
    rootPart.CFrame=CFrame.new(7,5,-13)*CFrame.Angles(0,math.rad(yaw or 110),0)
    rootPart.Size=vector(2,2,1);rootPart.LocalTransparencyModifier=.7
    local head=object("Part","Head",model)
    head.CFrame=rootPart.CFrame*CFrame.new(0,2.5,0);head.Size=vector(2,1,1)
    local feet=object("Part","Feet",model)
    feet.CFrame=rootPart.CFrame*CFrame.new(0,-2,0);feet.Size=vector(2,2,1)
    local humanoid=object("Humanoid","Humanoid",model)
    humanoid.Health=100;humanoid.Died=signal();model.PrimaryPart=rootPart
    return model,humanoid,rootPart
end
local function reset()
    for _,controller in ipairs(controllers)do controller:destroy()end
    controllers={}
    for _,child in ipairs(workspace:GetChildren())do child:Destroy()end
    advance(1)
    table.clear(renderSteps);table.clear(Actions.bound);raycast=nil;bindFailure=false;cameraWriteFailure=nil
    player=object("Player","LocalPlayer",workspace)
    player.CharacterRemoving=signal();player.OnTeleport=signal()
    actor,human,root=character()
    player.Character=actor;services.Players.LocalPlayer=player
    camera=object("Camera","WorldCamera",workspace)
    camera.CFrame=CFrame.lookAt(vector(30,14,18),vector(7,6,-13))
    camera.Focus=CFrame.new(4,3,2);camera.FieldOfView=73
    camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=human
    camera.ViewportSize=Vector2.new(1440,900)
    workspace.CurrentCamera=camera
    Input.MouseBehavior=Enum.MouseBehavior.LockCenter;Input.MouseIconEnabled=false
    controls={controlsEnabled=true,disables=0,enables=0}
    function controls:Disable()
        self.disables+=1;self.controlsEnabled=false
        if self.failDisable then error("injected partially completed controls disable") end
    end
    function controls:Enable()self.enables+=1;self.controlsEnabled=true end
    rect={position=Vector2.new(320,85),size=Vector2.new(760,730),canvasSize=camera.ViewportSize}
end
local function controller(provider)
    local result=CharacterWorldCamera.create({player=player,controls=controls,viewport=function()return rect end,character=provider})
    controllers[#controllers+1]=result;return result
end
local function snapshot()
    return {frame=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView,type=camera.CameraType,subject=camera.CameraSubject}
end
local function assertSaved(saved)
    check(camera.CFrame==saved.frame and camera.Focus==saved.focus and camera.FieldOfView==saved.fov,"restores exact saved camera pose, focus and FOV")
    check(camera.CameraType==saved.type and camera.CameraSubject==saved.subject,"restores saved camera type and subject")
end
local function assertCleanup()
    check(count(renderSteps)==0 and count(Actions.bound)==0,"releases render and movement bindings")
    check(player:GetAttribute("SpyCharacterSceneActive")==false and player:GetAttribute("SpyCharacterSceneToken")==nil,"releases scene attributes")
end
local function assertFits(model)
    local bounds,size=model:GetBoundingBox()
    local tanV=math.tan(math.rad(camera.FieldOfView)*.5)
    local canvas=camera.ViewportSize
    local px,py=math.min(20,rect.size.X*.06),math.min(24,rect.size.Y*.045)
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local point=bounds:PointToWorldSpace(size*vector(x,y,z)*.5)-camera.CFrame.Position
        local depth=point:Dot(camera.CFrame.LookVector)
        check(depth>0,"every bounding corner is in front of the camera")
        local sx=canvas.X*.5*(1+point:Dot(camera.CFrame.RightVector)/(depth*tanV*(canvas.X/canvas.Y)))
        local sy=canvas.Y*.5*(1-point:Dot(camera.CFrame.UpVector)/(depth*tanV))
        check(sx>=rect.position.X+px-1e-5 and sx<=rect.position.X+rect.size.X-px+1e-5,"bounding corner fits the requested horizontal rectangle")
        check(sy>=rect.position.Y+py-1e-5 and sy<=rect.position.Y+rect.size.Y-py+1e-5,"bounding corner fits the requested vertical rectangle")
    end end end
end
local passed,failures=0,0
local function test(name,callback)
    reset()
    local ok,message=pcall(callback)
    if ok then passed+=1;print("PASS: "..name)else failures+=1;print("FAIL: "..name..": "..tostring(message))end
end

test("opening orbits the real world camera and frames only after .72 seconds",function()
    local initial=camera.CFrame
    local framed,unavailable=0,0
    local scene=controller()
    check(scene:open({onFramed=function()framed+=1 end,onUnavailable=function()unavailable+=1 end}),"valid actor opens")
    check(camera==workspace.CurrentCamera and camera.CameraType==Enum.CameraType.Scriptable,"leases the existing world camera")
    check(camera.CFrame==initial and framed==0,"opening begins at the exact gameplay camera and does not reveal early")
    check(controls.disables==1 and not controls.controlsEnabled,"disables originally enabled movement controls")
    for _,entry in pairs(renderSteps)do check(entry.priority==210,"updates after the gameplay camera")end
    for _,entry in pairs(Actions.bound)do check(entry.callback()==Enum.ContextActionResult.Sink and #entry.inputs==5,"sinks movement and jump")end
    step(.36)
    check(camera.CFrame~=initial and framed==0,"midpoint advances the orbit without completing")
    step(.359);check(framed==0,"does not complete before .72 seconds")
    step(.002);check(framed==1 and unavailable==0,"completes after the full opening duration")
    local bounds=actor:GetBoundingBox()
    check((camera.CFrame.Position-bounds.Position).Unit:Dot(root.CFrame.LookVector)>.999999,"camera views the actor's actual authored front")
    assertFits(actor)
    step(1);check(framed==1,"framed callback runs once")
end)

test("render binding failure rolls back an acquired camera and reports once",function()
    local saved=snapshot();local failed,reason=0,nil
    local scene=controller();bindFailure=true
    local ok,accepted=pcall(scene.open,scene,{onUnavailable=function(value)failed+=1;reason=value end})
    check(ok and accepted==false,"an engine binding failure rejects opening without escaping")
    check(failed==1 and reason=="camera_error" and not scene.active,"reports a single failed acquisition")
    assertSaved(saved);assertCleanup()
    check(controls.controlsEnabled and controls.enables==1,"failed acquisition restores its disabled controls")
    bindFailure=false
    check(scene:open({reducedMotion=true}),"a later H attempt can acquire the recovered camera")
end)

test("partially completed control disable rolls back all independent leases",function()
    local saved=snapshot();local failed=0;local scene=controller();controls.failDisable=true
    local ok,accepted=pcall(scene.open,scene,{onUnavailable=function()failed+=1 end})
    check(ok and accepted==false and failed==1,"control failure rejects opening once")
    assertSaved(saved);assertCleanup()
    check(controls.controlsEnabled and controls.enables==1,"restores controls even when Disable changed state before throwing")
end)

test("partial native camera property writes still restore the gameplay controller",function()
    local saved=snapshot();local failed=0;local scene=controller();cameraWriteFailure="FieldOfView"
    local ok,accepted=pcall(scene.open,scene,{onUnavailable=function()failed+=1 end})
    check(ok and accepted==false and failed==1,"a partial camera write is rejected once")
    assertSaved(saved);assertCleanup()
    check(controls.controlsEnabled,"partial camera writes cannot strand movement controls")
end)

test("a rejected-open fallback callback is never invoked twice if it raises",function()
    local scene=controller();local failed=0;player:SetAttribute("SpyTradeOpen",true)
    local ok,accepted=pcall(scene.open,scene,{onUnavailable=function()
        failed+=1;error("injected UI rejection callback failure")
    end})
    check(ok and accepted==false and failed==1,"a failed rejection callback is logged once without a duplicate notification")
    check(not scene.active and count(renderSteps)==0 and count(Actions.bound)==0,"rejection callback cannot acquire a hidden scene")
end)

test("an inactive close completion is never invoked twice if it raises",function()
    local scene=controller();local closed=0
    local ok=pcall(scene.close,scene,{onClosed=function()
        closed+=1;error("injected inactive close callback failure")
    end})
    check(ok and closed==1,"an inactive close callback is logged once without duplicate completion")
    check(not scene.active and count(renderSteps)==0 and count(Actions.bound)==0,"inactive close does not acquire scene resources")
end)

test("a failed camera restore write still clears leases and completes close",function()
    local saved=snapshot();local closed=0;local scene=controller();scene:open({reducedMotion=true})
    cameraWriteFailure="CFrame"
    local ok=pcall(scene.close,scene,{immediate=true,onClosed=function()closed+=1 end})
    check(ok and closed==1 and not scene.active,"restoration failure cannot skip close completion")
    assertCleanup()
    check(camera.CameraType==saved.type and camera.CameraSubject==saved.subject,"other owned camera properties restore independently of a failed pose setter")
    check(controls.controlsEnabled,"restoration failure releases movement controls")
end)

test("animated return errors complete the close callback after rollback",function()
    local closed,failed=0,0;local scene=controller()
    scene:open({onUnavailable=function()failed+=1 end});step(.73)
    scene:close({onClosed=function()closed+=1 end})
    raycast=function()error("injected return orbit raycast failure")end
    local ok=pcall(step,.1)
    check(ok and closed==1 and not scene.active,"failed return animation still releases the UI's close session")
    assertCleanup()
    step(1);check(closed==1,"return failure cannot deliver duplicate close callbacks")
end)

test("runtime raycast failure releases the frozen camera instead of flooding frames",function()
    local saved=snapshot();local failed,framed,reason=0,0,nil;local scene=controller()
    scene:open({onFramed=function()framed+=1 end,onUnavailable=function(value)failed+=1;reason=value end});step(.1)
    raycast=function()error("injected native raycast failure")end
    local ok=pcall(step,.1)
    check(ok and not scene.active and failed==1 and reason=="camera_error","render error releases its lease and reports once")
    assertSaved(saved);assertCleanup()
    check(controls.controlsEnabled and framed==0,"failed framing releases movement without leaving a Scriptable camera")
    step(1);check(failed==1,"a failed render callback is unbound and cannot flood errors")
end)

test("FOV and focus drift do not cancel framing or strand a Scriptable camera",function()
    local failed,framed=0,0;local scene=controller()
    scene:open({onFramed=function()framed+=1 end,onUnavailable=function()failed+=1 end})
    camera.FieldOfView+=.001;camera.Focus=CFrame.new(0,0,0)
    step(.73)
    check(scene.active and framed==1 and failed==0,"independent lens or focus writes do not impersonate a camera owner")
    assertFits(actor)
end)

test("close restores owned camera properties while preserving a foreign lens and focus",function()
    local saved=snapshot();local scene=controller();scene:open({reducedMotion=true})
    local foreignFov,foreignFocus=81,CFrame.new(44,2,11)
    camera.FieldOfView,camera.Focus=foreignFov,foreignFocus
    scene:close({immediate=true})
    check(camera.CFrame==saved.frame and camera.CameraType==saved.type and camera.CameraSubject==saved.subject,"restores owned gameplay pose and camera controller")
    check(camera.FieldOfView==foreignFov and camera.Focus==foreignFocus,"preserves independently changed lens and focus properties")
    assertCleanup()
end)

test("landscape and portrait resizing fits all bounds inside the UI rectangle",function()
    local scene=controller();scene:open({reducedMotion=true})
    assertFits(actor)
    local first=camera.CFrame
    rect={position=Vector2.new(28,240),size=Vector2.new(374,520),canvasSize=Vector2.new(430,932)}
    camera.ViewportSize=rect.canvasSize;scene:resize()
    assertFits(actor)
    check(camera.CFrame~=first,"resize recomputes the world framing")
    rect={position=Vector2.new(500,120),size=Vector2.new(510,540),canvasSize=Vector2.new(1920,1080)}
    camera.ViewportSize=rect.canvasSize;scene:resize();assertFits(actor)
end)

test("safe-area canvas uses the full camera projection plane",function()
    camera.ViewportSize=Vector2.new(1920,1080)
    rect={position=Vector2.new(1060,116),size=Vector2.new(500,760),canvasSize=Vector2.new(1920,1044)}
    local scene=controller();scene:open({reducedMotion=true});assertFits(actor)
    rect={position=Vector2.new(30,90),size=Vector2.new(370,360),canvasSize=Vector2.new(430,896)}
    camera.ViewportSize=Vector2.new(430,932);scene:resize();assertFits(actor)
    local bounds=actor:GetBoundingBox()
    check(near(camera.CFrame.Position.Y,bounds.Position.Y),"off-centre portrait keeps its camera above the actor's floor")
end)

test("immediate close restores a Scriptable camera exactly and original mouse state",function()
    camera.CameraType=Enum.CameraType.Scriptable
    local subject=object("Part","SavedScriptableSubject",workspace);camera.CameraSubject=subject
    local saved=snapshot();local closed=0
    local scene=controller();scene:open({reducedMotion=true})
    check(root.LocalTransparencyModifier==0,"temporarily clears first-person local masks")
    scene:close({immediate=true,onClosed=function()closed+=1 end})
    assertSaved(saved);assertCleanup()
    check(controls.enables==1 and controls.controlsEnabled,"restores movement it disabled")
    check(Input.MouseBehavior==Enum.MouseBehavior.LockCenter and Input.MouseIconEnabled==false,"restores owned mouse properties")
    check(root.LocalTransparencyModifier==.7,"restores original local visibility")
    check(closed==1,"close callback fires once")
end)

test("animated close cancels pending framing and restores at .38 seconds",function()
    local saved=snapshot();local framed,closed=0,0
    local scene=controller();scene:open({onFramed=function()framed+=1 end})
    step(.2);scene:close({onClosed=function()closed+=1 end})
    step(.379);check(scene.active and closed==0 and framed==0,"close retains the lease until its duration finishes")
    step(.002);check(not scene.active and closed==1 and framed==0,"interrupted opening cannot publish a late framed callback")
    assertSaved(saved);assertCleanup();step(2);check(closed==1 and framed==0,"callbacks stay settled after release")
end)

test("reduced motion settles opening and closing immediately",function()
    local saved=snapshot();local framed,closed=0,0
    local scene=controller();scene:open({onFramed=function()framed+=1 end})
    step(.1);scene:setReducedMotion(true)
    check(framed==1,"turning reduced motion on finishes the pending camera transition")
    assertFits(actor)
    local still=camera.CFrame;step(1);check(camera.CFrame==still,"settled reduced-motion camera stays still")
    scene:close({onClosed=function()closed+=1 end})
    check(closed==1 and not scene.active,"reduced motion closes synchronously")
    assertSaved(saved)
end)

test("Custom restore replaces an invalid saved humanoid with the living player",function()
    local stale=object("Humanoid","StaleSubject",workspace);stale.Health=0;stale.Died=signal()
    camera.CameraSubject=stale
    local scene=controller();scene:open({reducedMotion=true});stale:Destroy()
    scene:close({immediate=true})
    check(camera.CameraType==Enum.CameraType.Custom and camera.CameraSubject==human,"restores Custom against a valid current humanoid")
end)

test("originally disabled movement controls remain disabled",function()
    controls.controlsEnabled=false
    local scene=controller();scene:open({reducedMotion=true});scene:close({immediate=true})
    check(controls.disables==0 and controls.enables==0 and not controls.controlsEnabled,"does not enable controls owned by an existing blocker")
end)

test("losing scene ownership preserves a successor camera while releasing our controls",function()
    local failed,reason=0,nil
    local scene=controller();scene:open({onUnavailable=function(value)failed+=1;reason=value end})
    step(.1)
    local successor=CFrame.new(80,20,30);camera.CFrame=successor
    Input.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition;Input.MouseIconEnabled=false
    player:SetAttribute("SpyCharacterSceneToken","successor")
    check(not scene.active and failed==1 and reason=="ownership_lost","reports token takeover once")
    check(camera.CFrame==successor and player:GetAttribute("SpyCharacterSceneToken")=="successor" and player:GetAttribute("SpyCharacterSceneActive")==true,"does not overwrite or clear successor ownership")
    check(controls.enables==1 and controls.controlsEnabled,"our disabled controls restore when no successor claimed them")
    check(Input.MouseBehavior==Enum.MouseBehavior.LockCurrentPosition and Input.MouseIconEnabled==false,"does not overwrite successor mouse properties")
    check(count(renderSteps)==0 and count(Actions.bound)==0,"token takeover releases owned bindings")
    step(1);check(failed==1,"takeover cannot publish duplicate failures")
end)

test("successor control claim retains disabled controls and control token",function()
    local scene=controller();scene:open({reducedMotion=true})
    player:SetAttribute("SpyCharacterSceneControlsToken","successor")
    player:SetAttribute("SpyCharacterSceneToken","successor")
    check(controls.enables==0 and not controls.controlsEnabled,"successor keeps the controls it claimed")
    check(player:GetAttribute("SpyCharacterSceneControlsToken")=="successor","does not clear successor control claim")
end)

test("external camera pose and mouse writes retain property ownership",function()
    local scene=controller();local failed=0
    scene:open({onUnavailable=function()failed+=1 end})
    local replacement=CFrame.new(90,23,17);camera.CFrame=replacement
    Input.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition;Input.MouseIconEnabled=false
    step(.1)
    check(not scene.active and failed==1 and camera.CFrame==replacement,"external camera writes terminate the lease without restoring stale pose")
    check(Input.MouseBehavior==Enum.MouseBehavior.LockCurrentPosition and Input.MouseIconEnabled==false,"external mouse writes survive release")
    assertCleanup()
end)

test("camera replacement releases bindings without changing either camera",function()
    local failed,reason=0,nil;local scene=controller()
    scene:open({onUnavailable=function(value)failed+=1;reason=value end});step(.1)
    local previous=camera.CFrame
    local nextCamera=object("Camera","NextCamera",workspace);nextCamera.CFrame=CFrame.new(100,200,300)
    local nextFrame=nextCamera.CFrame;workspace.CurrentCamera=nextCamera
    check(not scene.active and failed==1 and reason=="camera_replaced","replacement interrupts synchronously")
    check(camera.CFrame==previous and nextCamera.CFrame==nextFrame,"release leaves both replaced and current camera poses alone")
    assertCleanup()
end)

test("dead actor and removed actor clean up without late framing",function()
    for _,mode in ipairs({"dead","removed"})do
        local framed,failed,reason=0,0,nil
        local scene=controller();scene:open({onFramed=function()framed+=1 end,onUnavailable=function(value)failed+=1;reason=value end})
        if mode=="dead"then human.Health=0;human.Died:Fire()else actor.Parent=nil;advance(0)end
        check(not scene.active and failed==1 and framed==0,"actor loss releases once before framing")
        check(reason==(mode=="dead" and "died" or "character_removed"),"actor loss preserves its reason")
        assertCleanup();step(1);check(failed==1 and framed==0,"actor loss cannot revive pending framing")
        if mode=="dead"then human.Health=100 else actor.Parent=workspace end
    end
end)

test("provider replacement survives destroyed prior actor and cleared CameraSubject",function()
    local first=character("FirstStandIn");local current=first
    local framed,failed=0,0
    local scene=controller(function()return current end)
    scene:open({onFramed=function()framed+=1 end,onUnavailable=function()failed+=1 end});step(.2)
    local nextActor,nextHuman=character("ReplacementStandIn",35);current=nextActor
    first:Destroy();camera.CameraSubject=nil
    advance(0);step(.53)
    check(scene.active and framed==1 and failed==0,"published replacement continues the original transition")
    check(camera.CameraSubject==nextHuman,"hands the camera subject to the replacement humanoid")
    assertFits(nextActor)
    scene:close({immediate=true});assertCleanup()
end)

test("real player death interrupts a scene with an independent actor",function()
    local standin=character("IndependentActor")
    local failed,reason=0,nil;local scene=controller(function()return standin end)
    scene:open({onUnavailable=function(value)failed+=1;reason=value end})
    human.Health=0;human.Died:Fire()
    check(not scene.active and failed==1 and reason=="died","real humanoid death releases a cloned-actor scene")
    assertCleanup()
end)

test("blocking states reject before acquisition and interrupt an acquired lease",function()
    player:SetAttribute("SpyTradeOpen",true)
    local failed,reason=0,nil;local scene=controller()
    check(not scene:open({onUnavailable=function(value)failed+=1;reason=value end}) and failed==1 and reason=="blocked","reports a blocked attempt once")
    check(controls.disables==0 and count(renderSteps)==0,"blocked attempt cannot acquire controls or rendering")
    player:SetAttribute("SpyTradeOpen",false)
    scene:open({onUnavailable=function(value)failed+=1;reason=value end})
    player:SetAttribute("SpyTradeOpen",true)
    check(not scene.active and failed==2 and reason=="interrupted","blocker activation interrupts an opening")
    assertCleanup()
end)

test("collision search widens safely and refuses a completely obstructed view",function()
    local rays=0
    raycast=function(origin,direction)
        rays+=1
        if rays<=5 then return {Position=origin+direction*.5,Normal=Vector3.yAxis}end
        return nil
    end
    local scene=controller();check(scene:open({reducedMotion=true}),"search finds the first unobstructed wider lens")
    check(camera.FieldOfView==58 and rays==6,"search tests alternate angles before widening its lens")
    scene:close({immediate=true})
    local failed,reason=0,nil;local saved=snapshot()
    raycast=function(origin,direction)return {Position=origin+direction*.5,Normal=Vector3.yAxis}end
    check(not scene:open({onUnavailable=function(value)failed+=1;reason=value end}),"all obstructed candidates reject opening")
    check(failed==1 and reason=="no_safe_view" and not scene.active,"blocked geometry reports a single stable fallback")
    assertSaved(saved);assertCleanup()
end)

test("destroy releases listeners and prevents later opens",function()
    local baseline=activeConnections();local saved=snapshot();local framed=0
    local scene=controller();scene:open({onFramed=function()framed+=1 end});step(.1)
    scene:destroy();scene:destroy();step(2)
    check(not scene.active and framed==0,"destroy cancels pending framing idempotently")
    assertSaved(saved);assertCleanup()
    check(activeConnections()==baseline,"destroy releases every owned signal listener")
    local failed,reason=0,nil
    check(not scene:open({onUnavailable=function(value)failed+=1;reason=value end}) and failed==1 and reason=="destroyed","destroyed controller reports exactly one rejected open")
end)

for _,scene in ipairs(controllers)do scene:destroy()end
print("World character camera: "..passed.." tests, "..checks.." assertions, "..failures.." failures (native rendering and physics not exercised)")
assert(failures==0,"world character camera behavior checks failed")
