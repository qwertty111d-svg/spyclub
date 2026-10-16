-- These tests execute the client camera blocks; they do not claim Roblox rendering.
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function signal()
    local listeners={};local event={}
    function event:Connect(callback)
        local entry={callback=callback,connected=true};listeners[#listeners+1]=entry
        return {Disconnect=function()entry.connected=false end}
    end
    function event:Fire(...)
        for _,entry in ipairs(table.clone(listeners))do if entry.connected then entry.callback(...)end end
    end
    return event
end
local function playerStub()
    local player={attributes={},signals={}}
    function player:GetAttribute(key)return self.attributes[key]end
    function player:GetAttributeChangedSignal(key)
        self.signals[key]=self.signals[key]or signal();return self.signals[key]
    end
    function player:SetAttribute(key,value)
        local changed=self.attributes[key]~=value;self.attributes[key]=value
        if changed and self.signals[key]then self.signals[key]:Fire()end
    end
    return player
end
local Enum={CameraType={Custom='Custom',Scriptable='Scriptable'},EasingStyle={Quint='Quint'},EasingDirection={Out='Out'},
    MouseBehavior={Default='Default',LockCenter='LockCenter',LockCurrentPosition='LockCurrentPosition'}}
local vectorMeta={}
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},vectorMeta)end}
vectorMeta.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
local CFrame={lookAt=function(from,to)return {from=from,to=to}end}
local TweenInfo={new=function(...)return {...}end}
local function lobbyScenario()
    local player=playerStub();local humanoid={Parent=true}
    player.Character={FindFirstChildOfClass=function()return humanoid end}
    local camera={CameraType='Custom',FieldOfView=70,CFrame='gameplay'}
    local workspace={CurrentCamera=camera}
    local Config={Tables={{id='a',x=10,z=20},{id='b',x=30,z=40}}}
    local state={tableId='a'}
    local cameraSaved,cameraTween,lastCameraTable=nil,nil,nil
    local tweens={};local TweenService={}
    function TweenService:Create(target,_,properties)
        local tween={cancelled=false}
        function tween:Cancel()self.cancelled=true end
        function tween:Play()for key,value in pairs(properties)do target[key]=value end end
        tweens[#tweens+1]=tween;return tween
    end
-- LOBBY_CAMERA_SOURCE_INSERT
    focusTable('a')
    local original=camera.CFrame
    player:SetAttribute('SpyCharacterMenuOpen',true)
    check(tweens[1].cancelled,'opening H must cancel the in-flight lobby camera tween before scene acquisition')
    player:SetAttribute('SpyCharacterSceneActive',true)
    camera.CFrame='character scene'
    state.tableId='b';focusTable(state.tableId)
    check(camera.CFrame=='character scene','a table state update must not overwrite the world character camera')
    player:SetAttribute('SpyCharacterSceneActive',false)
    check(camera.CFrame=='character scene','table camera must wait until the pending H UI closes')
    player:SetAttribute('SpyCharacterMenuOpen',false)
    check(camera.CFrame~='character scene'and camera.CFrame.from.X==30,'release must resume the latest lobby table, including a changed table')
    player:SetAttribute('SpyCharacterMenuOpen',true)
    player:SetAttribute('SpyCharacterSceneActive',true)
    camera.CFrame='second character scene';state.tableId=nil;focusTable(nil)
    player:SetAttribute('SpyTeleporting',true)
    player:SetAttribute('SpyCharacterSceneActive',false);player:SetAttribute('SpyCharacterMenuOpen',false)
    check(camera.CFrame=='second character scene','teleport camera ownership must survive H release')
    player:SetAttribute('SpyTeleporting',false)
    check(camera.CameraType=='Custom'and camera.CameraSubject==humanoid,'a later safe release must restore the original gameplay camera')
    check(cameraSaved==nil,'table camera snapshot must release after leaving the latest table')
end
lobbyScenario()
local function matchScenario()
    local player=playerStub()
    local camera={CFrame='native seat',CameraType='Scriptable',FieldOfView=70}
    local workspace={CurrentCamera=camera}
    local currentState={phase='Hint'}
    local cursorReleased=false
    local seatedCameraActive=true
    local UserInputService={MouseBehavior='LockCenter',MouseIconEnabled=false}
    local script={Destroying=signal()}
    local cancelled=0
    local function cancelCameraSequence()cancelled+=1 end
    local pendingCameraTween={Cancel=function()cancelled+=1 end}
    local matchUI={nativeCameraTweens={[pendingCameraTween]=true}}
    local function node(class,properties)
        local object=properties or {};object.Parent=true
        function object:IsA(expected)return class==expected end
        return object
    end
    local front=node('SurfaceGui',{Enabled=true})
    local back=node('SurfaceGui',{Enabled=true})
    local part=node('BasePart',{LocalTransparencyModifier=.35})
    function part:GetDescendants()return {front,back}end
    local ownCard={part=part,frontGui=front}
    local characterScene={}
    local closeEvent={}
    local playerGui={FindFirstChild=function(_,name)return name=='SpyOpenDossier'and closeEvent or nil end}
    function closeEvent:IsA(class)return class=='BindableEvent'end
    function closeEvent:Fire(action)
        check(action=='close','camera takeover must request the real H menu close')
        player:SetAttribute('SpyCharacterMenuOpen',false)
        characterScene.changed()
    end
-- MATCH_CAMERA_OWNERSHIP_SOURCE_INSERT
    check(type(characterScene.changed)=='function','the match must provide native world scene ownership integration')
    player:SetAttribute('SpyCharacterMenuOpen',true);characterScene.changed()
    check(cancelled==2,'H acquisition must cancel all native camera tweens before taking the camera')
    check(cursorReleased and UserInputService.MouseBehavior=='Default','H must release the captured native cursor')
    check(part.LocalTransparencyModifier==1 and not front.Enabled and not back.Enabled,'private camera-relative card geometry and faces must be hidden during H')
    player:SetAttribute('SpyCharacterSceneActive',true);characterScene.changed()
    player:SetAttribute('SpyFOV',88)
    characterScene.setCardFront(ownCard,false)
    player:SetAttribute('SpyCharacterSceneActive',false);characterScene.changed()
    check(part.LocalTransparencyModifier==1,'the private card must stay hidden until both scene and UI release')
    player:SetAttribute('SpyCharacterMenuOpen',false);characterScene.changed()
    check(part.LocalTransparencyModifier==.35 and not front.Enabled and back.Enabled,'release must restore card masks while preserving gameplay face changes made during H')
    check(camera.FieldOfView==88,'normal seated-camera release must apply the latest FOV preference after yielding during H')
    check(not cursorReleased and UserInputService.MouseBehavior=='LockCenter'and not UserInputService.MouseIconEnabled,'normal release must restore the exact previously locked cursor')
    cursorReleased=true;UserInputService.MouseBehavior='Default';UserInputService.MouseIconEnabled=true
    player:SetAttribute('SpyCharacterMenuOpen',true);characterScene.changed()
    player:SetAttribute('SpyCharacterMenuOpen',false);characterScene.changed()
    check(cursorReleased and UserInputService.MouseBehavior=='Default','an already released native cursor must remain released')
    cursorReleased=false;UserInputService.MouseBehavior='LockCenter';UserInputService.MouseIconEnabled=false
    player:SetAttribute('SpyCharacterMenuOpen',true);characterScene.changed()
    camera.CFrame='foreign takeover'
    player:SetAttribute('SpyCharacterMenuOpen',false);characterScene.changed()
    check(UserInputService.MouseBehavior=='Default','a foreign camera takeover must not receive stale cursor restoration')
    local replacement={CFrame='replacement native',CameraType='Scriptable'}
    workspace.CurrentCamera=replacement
    cursorReleased=false;UserInputService.MouseBehavior='LockCenter';UserInputService.MouseIconEnabled=false
    player:SetAttribute('SpyCharacterMenuOpen',true);characterScene.changed()
    replacement.CFrame='replacement takeover'
    player:SetAttribute('SpyCharacterMenuOpen',false);characterScene.changed()
    check(UserInputService.MouseBehavior=='Default','input restoration must compare the leased camera object after CurrentCamera replacement')
    workspace.CurrentCamera=camera
    camera.CFrame='native seat'
    player:SetAttribute('SpyCharacterMenuOpen',true);characterScene.changed()
    player:SetAttribute('SpyCharacterSceneActive',true);characterScene.changed()
    local interrupted=0
    local holdScene=false
    player:GetAttributeChangedSignal('SpyCharacterSceneInterrupt'):Connect(function()
        interrupted+=1
        if not holdScene then
            player:SetAttribute('SpyCharacterSceneActive',false)
            characterScene.changed()
        end
    end)
    check(characterScene.interrupt(),'native takeover must synchronously release the scene and close H')
    check(interrupted==1 and player:GetAttribute('SpyCharacterSceneInterrupt')==1,'native camera entry must issue the numeric interrupt contract')
    check(not characterScene.active()and part.LocalTransparencyModifier==.35,'interrupt must leave no card lease or scene-active gate behind')
    check(UserInputService.MouseBehavior=='Default','interruption must leave cursor authority to the new native phase')
    local armPose='lift'
    local armRig={rigType='R15',hand={CFrame='native hand'},shoulder={Transform='native arm'}}
    local forceCharacterVisible=true
    local cardFollowHand=true
    local cardAnimating=false
    local cardMode='open'
    local MatchPresentation={applyCameraVisibility=function()error('native actor visibility must yield during H')end}
    local Lighting={FindFirstChild=function()return nil end}
    local RunService={RenderStepped=signal()}
    local TweenService={calls=0}
    function TweenService:Create()
        self.calls+=1
        return {Completed=signal(),Play=function()end}
    end
    matchUI.timer={};matchUI.clockFill={}
    player.Character={GetDescendants=function()error('native avatar visibility must yield during H')end}
-- MATCH_AVATAR_WRITERS_SOURCE_INSERT
-- MATCH_ARM_CAMERA_WRITERS_SOURCE_INSERT
-- MATCH_FOV_SOURCE_INSERT
-- MATCH_TWEEN_SOURCE_INSERT
-- MATCH_CAMERA_ENTRY_SOURCE_INSERT
-- MATCH_PHASE_ADMISSION_SOURCE_INSERT
-- MATCH_RENDER_SOURCE_INSERT
    currentState=nil
    holdScene=true
    player:SetAttribute('SpyCharacterMenuOpen',true);characterScene.changed()
    player:SetAttribute('SpyCharacterSceneActive',true);characterScene.changed()
    camera.CFrame='world scene';camera.FieldOfView=42;part.CFrame='native card'
    showLocalAvatar();hideHeadForPOV();updateArm(.1);updateSeatedCamera(.1);applyCinematicPreferences()
    RunService.RenderStepped:Fire(.1)
    cardFollowHand=false
    RunService.RenderStepped:Fire(.1)
    check(camera.CFrame=='world scene'and camera.FieldOfView==42,'native camera render and preference writers must yield during H')
    check(part.CFrame=='native card'and armRig.shoulder.Transform=='native arm','camera-relative private card and procedural arms must yield during H')
    check(tween(camera,.5,{CFrame='bad'})==nil and TweenService.calls==0,'a new native camera tween must not start through an active scene lease')
    local before=interrupted
    startSeatedCamera({});introCamera({});characterCamera();resultCamera()
    check(interrupted==before+4 and camera.CFrame=='world scene','every native camera entry must interrupt and yield if release has not completed')
    handleState({phase='Result'})
    check(currentState and currentState.phase=='Result','a delayed scene release must not discard authoritative match state')
    player:SetAttribute('SpyCharacterSceneActive',false);characterScene.changed()
    script.Destroying:Fire()
end
matchScenario()
local function minigameScenario(kind)
    local player=playerStub()
    local camera={CameraType='Scriptable',CFrame='H character scene',Focus='H focus',FieldOfView=42,CameraSubject='H actor'}
    local workspace={CurrentCamera=camera}
    local Input={MouseBehavior='Default'}
    local trace={}
    local controls={controlsEnabled=false}
    function controls:Enable()self.controlsEnabled=true;trace[#trace+1]='enable'end
    function controls:Disable()self.controlsEnabled=false;trace[#trace+1]='disable'end
    local controlModule={GetControls=function()return controls end}
    local playerScripts={FindFirstChild=function()return controlModule end}
    local require=function(module)return module end
    local task={spawn=function(callback)callback()end,wait=function()error('native controls should already be available')end}
    local dossierEvent={Event=signal()}
    function dossierEvent:IsA(class)return class=='BindableEvent'end
    function dossierEvent:Fire(...)self.Event:Fire(...)end
    local playerGui={FindFirstChild=function(_,name)return name=='SpyOpenDossier'and dossierEvent or nil end}
    function player:FindFirstChild(name)return name=='PlayerScripts'and playerScripts or name=='PlayerGui'and playerGui or nil end
    function player:FindFirstChildOfClass(class)return class=='PlayerGui'and playerGui or nil end
    local closeArgument='unset'
    local panels={accessoryRoll={close=function(_,animated)
        closeArgument=animated;trace[#trace+1]='close'
        if animated==false then
            camera.CameraType='Custom';camera.CFrame='native gameplay';camera.CameraSubject='real humanoid'
            camera.Focus='native focus';camera.FieldOfView=75
            controls:Enable()
            player:SetAttribute('SpyCharacterSceneActive',false);player:SetAttribute('SpyCharacterMenuOpen',false)
        end
    end}}
    local dossierOpenRequested,dossierCategory
    local function openPanel()error('minigame handoff must only close H')end
    local function togglePanel()error('minigame handoff must only close H')end
    local warn=function(message)error(message)end
-- LOBBY_PANEL_CALL_SOURCE_INSERT
-- LOBBY_DOSSIER_BINDER_SOURCE_INSERT
    player:SetAttribute('SpyCharacterSceneActive',true);player:SetAttribute('SpyCharacterMenuOpen',true)
    player:GetAttributeChangedSignal('SpyCharacterSceneInterrupt'):Connect(function()
        trace[#trace+1]='interrupt'
        -- The numeric contract deliberately skips a retired camera restoration.
        if player:GetAttribute('SpyCharacterSceneActive')then
            controls:Enable();player:SetAttribute('SpyCharacterSceneActive',false)
        end
    end)
    local opened=false
    local generation=0
    local ownedCamera,saved,controlsChanged
    local PromptService={Enabled=true}
    local promptLease
    local cameraRestore,disabledControls
    local member=function()return true end
-- CHECKERS_CONTROLS_SOURCE_INSERT
-- CHECKERS_CAPTURE_SOURCE_INSERT
-- BILLIARDS_CAPTURE_SOURCE_INSERT
    if kind=='checkers'then open();acquireControls(generation)else enterCamera()end
    local snapshot=kind=='checkers'and saved or cameraRestore
    check(closeArgument==false,kind..' entry must request the real H binder immediate close before capturing camera or controls')
    check(snapshot and (snapshot.frame or snapshot.cf)=='native gameplay'and (kind=='checkers'or snapshot.kind=='Custom'),kind..' must save the underlying gameplay camera, not the departing Scriptable H pose')
    check(trace[1]=='close'and trace[2]=='enable'and trace[#trace]=='disable',kind..' handoff must restore the H control lease before native minigame disable')
    check(kind=='checkers'and controlsChanged==true or kind=='billiards'and disabledControls==controls,kind..' must remember ownership of its own disabled controls')
    check(not player:GetAttribute('SpyCharacterSceneActive')and not player:GetAttribute('SpyCharacterMenuOpen'),kind..' capture must leave the departing H scene fully released')
    dossierEvent:Fire('close')
    check(closeArgument==nil,'legacy close events must retain the default animation argument')
end
minigameScenario('checkers');minigameScenario('billiards')
print('PASS character camera integration: '..checks..' checks')
