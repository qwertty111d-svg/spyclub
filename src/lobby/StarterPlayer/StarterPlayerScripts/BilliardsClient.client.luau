-- Optional, independent lobby LocalScript. All ball/scoring authority stays on server.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local PromptService=game:GetService("ProximityPromptService")
local player=Players.LocalPlayer
local transport=Storage:WaitForChild("SpyBilliards",20)
if not transport then return end
local action=transport:WaitForChild("Action",5)
local stateRemote=transport:WaitForChild("State",5)
if not action or not stateRemote then return end
local snapshot,sequence,opened=nil,0,false
local visualPhysics
local physicsModule=transport:FindFirstChild("VisualPhysics")
if physicsModule then local ok,result=pcall(require,physicsModule);if ok then visualPhysics=result end end
local prediction,ownMotion,localStroke=nil,nil,nil
local observedAim=nil
local aimDrawKey=nil
local shotSerial=0
local localCueAt=-math.huge
local startPrediction,clearPrediction
local chargeStarted=0
local beginPowerHold
local cameraLayoutKey=nil
local angle,power=0,.60
local gui,panel,score,scoreValue,note,shotHint,remainingLabel,joinButton,shotButton,angleBox,powerFill,powerText,resetButton,aimButton,instructions,joinConsent
local pointer,draggingPower,lastSend=nil,false,-100
local aimLocked=true
local aimChosen,aimTarget=false,0
local compactSpin,spinExpanded=false,false
local spinToggle,spinClose
local cameraRestore,disabledControls=nil,nil
local localModel,ballClones,ballTargets=nil,{},{}
local ballVisibility,originalMasks,visualConnections={},{},{}
local motionSamples={};local interpolationDelay=.10;local lastMotionTime=nil
local visualDirty,nextVisualRetry=true,0
local nextHudUpdate,lastHudInput=0,nil
local contextRecords={}
local promptLease
local modeSheet,modeFrame,modeButtons,modeDescription,timeButton,strictButton,startButton,playerCards,selectButton,passButton
local draftMode,draftSeconds,draftStrict="pool8",60,true
local selectingCue,safety=false,false
local spin={x=0,y=0};local spinFrame,spinHit,spinMarker,spinCaption,spinReset,spinPointer,decisionFrame
local lastAimSent=-100
local topHud,powerBar,powerPointer,pullOriginal,pushOutButton,fineAimToggle
local roundResult,nineGuide,feedbackLayoutKey
local fineAimExpanded=false
local pushOut=false
local shotPending=false
local shotPendingAt=-100
local shotRecoveryUntil=0
local transportNotice,transportNoticeUntil=nil,0
local audioFolder,audioLastId=nil,0
local audioVoices,audioCursor={},{}
-- Actual billiard recordings from Pro Sound Effects in the free Creator Store.
-- First isolated contact and its decay, without the subsequent stick movement.
local AUDIO={
 cue={id=9113441086,count=1,clip=.42,gain=.46,pitch=1},
 ball={id=9113440015,count=4,clip=.38,gain=.26,pitch=1},
 cushion={id=9113440622,count=2,clip=.29,gain=.20,pitch=1},
 pocket={id=9113442163,count=2,clip=.50,gain=.30,pitch=1},
}
local function cleanupAudio()
 if audioFolder then audioFolder:Destroy();audioFolder=nil end;audioVoices={};audioCursor={}
end
local function prepareAudio()
 if audioFolder then return end
 audioFolder=Instance.new("Folder");audioFolder.Name="SpyBilliardsAudio";audioFolder.Parent=game:GetService("SoundService")
 for kind,config in pairs(AUDIO)do
  audioVoices[kind]={};audioCursor[kind]=0
  for i=1,config.count do
   local sound=Instance.new("Sound");sound.Name=kind..i;sound.SoundId="rbxassetid://"..config.id;sound.Volume=config.gain;sound.PlaybackSpeed=config.pitch;sound.Looped=false;sound:SetAttribute("SpyAudioCategory","SFX");sound.Parent=audioFolder
   local voice={sound=sound,untilTime=0};table.insert(audioVoices[kind],voice)
   sound.Loaded:Connect(function()
    if audioFolder and opened and voice.untilTime>os.clock()then pcall(function()sound:Play()end)end
   end)
  end
 end
 local batch=audioFolder:GetChildren()
 task.spawn(function()pcall(function()game:GetService("ContentProvider"):PreloadAsync(batch)end)end)
end
local function receiveAudio(data,prime)
 if prime then audioLastId=math.max(audioLastId,data.audioSerial or 0);for _,e in ipairs(data.audio or {})do audioLastId=math.max(audioLastId,e.id or 0)end;return end
 if not opened then return end
 prepareAudio()
 for _,e in ipairs(data.audio or {})do
  if type(e.id)=="number"and e.id>audioLastId then
   audioLastId=e.id;local config=AUDIO[e.kind]
   local ownCue=e.kind=="cue"and ownMotion and e.at and e.at>=localCueAt-.05 and e.at<=localCueAt+1
   if config and not ownCue and type(e.at)=="number"and workspace:GetServerTimeNow()-e.at<.4 and type(e.level)=="number"then
    audioCursor[e.kind]=audioCursor[e.kind]%config.count+1;local voice=audioVoices[e.kind][audioCursor[e.kind]];local sound=voice.sound
    pcall(function()sound:Stop();sound.TimePosition=0;sound.Volume=config.gain*math.clamp(.25+e.level*.75,0,1);voice.untilTime=os.clock()+config.clip;if sound.IsLoaded then sound:Play()end end)
   end
  end
 end
end
local function cancelPull()
 draggingPower=false;powerPointer=nil;pointer=nil;aimLocked=true
 if pullOriginal then power=pullOriginal;pullOriginal=nil end
end
local visualMode,sourceBalls,promptGui=nil,nil,nil
local updateModePicker,showModePicker,clearPoolPrompt,layoutUI
local cueMarker,foulToast
local foulUntil=0
local function cueBall()
    if snapshot then for _,b in ipairs(snapshot.balls)do if b.id==snapshot.cueId then return b end end end
end
local function ballFrame(b)
    local c=snapshot.center;local scale=snapshot.scale or 1;local x,y,z,w=b.qx or 0,b.qy or 0,b.qz or 0,b.qw or 1
    local drop=b.fallT and math.min(1.1,.5*47.12*b.fallT^2)*scale or 0
    return CFrame.new(c.X+b.x*scale,snapshot.height-drop,c.Z+b.z*scale)*CFrame.new(0,0,0,
        1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),
        2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),
        2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y))
end
local cue,cueShaft,cueFerrule,cueTip,aimLine,afterLine,contactRing,homeLine,homeBadge
local function canvasSize()
    -- The drawable GUI can differ from the camera viewport on inset/scaled screens.
    local size=gui and gui.AbsoluteSize
    if size and size.X>0 and size.Y>0 then return size end
    local camera=workspace.CurrentCamera
    local view=camera and camera.ViewportSize or Vector2.new(800,600)
    local top,bottom=GuiService:GetGuiInset()
    return Vector2.new(math.max(1,view.X-top.X-bottom.X),math.max(1,view.Y-top.Y-bottom.Y))
end
-- BILLIARDS_STYLE_BEGIN
local palette={panel=Color3.fromRGB(26,27,31),panel2=Color3.fromRGB(36,37,42),brass=Color3.fromRGB(210,210,216),ivory=Color3.fromRGB(244,240,231),muted=Color3.fromRGB(168,170,179),green=Color3.fromRGB(238,238,241),ink=Color3.fromRGB(20,21,24)}
-- BILLIARDS_STYLE_END
local function member()
    if snapshot then for _,p in ipairs(snapshot.players)do if p.id==player.UserId then return p end end end
end
local function canConfigure()
    return snapshot~=nil and snapshot.phase~="moving"and(#snapshot.players==0 or(member()~=nil and snapshot.players[1].id==player.UserId and(#snapshot.players==1 or snapshot.phase=="finished"or snapshot.shots==0)))
end
local function canAim(whilePull)
    return not ownMotion and(not draggingPower or whilePull==true)and opened and snapshot~=nil and member()~=nil and snapshot.phase=="aiming"and snapshot.turn==player.UserId
        and not snapshot.ballInHand and not(instructions and instructions.Visible)and not(modeSheet and modeSheet.Visible)and visualMode==snapshot.mode
end
local function send(command,extra)
    if not snapshot or not opened then return end
    if command~="leave"and command~="shot"and os.clock()-lastSend<.16 then return end
    if command=="shot"and(shotPending or draggingPower or not canAim()or selectingCue or not aimChosen or pointer~=nil or math.abs((aimTarget-angle+180)%360-180)>.2)then return end
    if command=="reset"and not member()then return end
    lastSend=os.clock()
    local data={action=command,revision=snapshot.revision,angle=angle,power=power,safety=safety,pushOut=pushOut,spin={x=spin.x,y=spin.y}}
    for key,value in pairs(extra or {})do data[key]=value end
    if command=="shot"then
        shotPending=true;shotPendingAt=os.clock();shotRecoveryUntil=0;shotSerial+=1;data.shotRequestId=shotSerial
        ownMotion={rackId=snapshot.rackId,shots=snapshot.shots+1,requestId=shotSerial}
        localStroke={at=os.clock(),angle=angle,power=power,spin={x=spin.x,y=spin.y},cue=table.clone(cueBall())}
        if startPrediction then startPrediction(snapshot,data,false)end
        localCueAt=workspace:GetServerTimeNow();prepareAudio()
        local voice=audioVoices.cue and audioVoices.cue[1]
        if voice then pcall(function()voice.sound:Stop();voice.sound.TimePosition=0;voice.sound.Volume=AUDIO.cue.gain*(.25+power*.75);voice.untilTime=os.clock()+AUDIO.cue.clip;if voice.sound.IsLoaded then voice.sound:Play()end end)end
    end
    local ok=pcall(function()action:FireServer(data)end)
    if not ok then
        if command=="shot"then shotPending=false;shotRecoveryUntil=os.clock()+4;if clearPrediction then clearPrediction(true)end end
        return false
    end;return true
end
-- BILLIARDS_HELPERS_BEGIN
local function rounded(object,radius)
 if object:IsA("TextButton")then radius=math.max(radius or 4,4)end
    local c=object:FindFirstChildOfClass("UICorner")or Instance.new("UICorner");c.CornerRadius=UDim.new(0,radius);c.Parent=object
end
local function label(parent,name,text,size)
    local t=Instance.new("TextLabel");t.Name=name;t.BackgroundTransparency=1;t.TextColor3=palette.ivory
    t.Font=Enum.Font.BuilderSansMedium;t.TextSize=size or 14;t.TextXAlignment=Enum.TextXAlignment.Left;t.Text=text;t.Parent=parent;return t
end
local function button(parent,name,text,color)
    local t=Instance.new("TextButton");t.Name=name;t.BackgroundColor3=color or palette.panel2;t.BorderSizePixel=0
    t.TextColor3=color==palette.green and palette.ink or palette.ivory;t.Font=Enum.Font.BuilderSansMedium;t.TextSize=15;t.Text=text;t.AutoButtonColor=true;t.Parent=parent;rounded(t,4);return t
end
-- BILLIARDS_HELPERS_END
local function visualPart(name,color,material)
    local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Material=material or Enum.Material.SmoothPlastic;p.Color=color;p.Size=Vector3.new(.04,.04,1);p.Parent=localModel;return p
end
-- Mask each replicated property once. Replication may write visibility later;
-- retain its newest intended value and keep only this viewer's copy hidden.
local function maskOriginal(object,property,value)
    local record={object=object,property=property,desired=object[property],setting=false}
    table.insert(originalMasks,record)
    local function apply()record.setting=true;object[property]=value;record.setting=false end
    record.connection=object:GetPropertyChangedSignal(property):Connect(function()
        if not opened or record.setting or object[property]==value then return end
        record.desired=object[property];apply()
    end)
    apply()
end
local function hideOriginals()
    if not sourceBalls then return end
    for _,object in ipairs(sourceBalls:GetDescendants())do
        if object:IsA("BasePart")then maskOriginal(object,"LocalTransparencyModifier",1)
        elseif object:IsA("SurfaceGui")then maskOriginal(object,"Enabled",false)end
    end
end
local function setBallHidden(id,hidden)
    local record=ballVisibility[id]
    if not record or record.hidden==hidden then return end
    record.hidden=hidden
    for _,part in ipairs(record.parts)do part.Transparency=hidden and 1 or 0 end
    for _,surface in ipairs(record.surfaces)do surface.Enabled=not hidden end
end
local function targetsFrom(data)
    local targets={}
    for _,b in ipairs(data.balls)do
        targets[b.id]={cf=ballFrame(b),hidden=b.pocketed and(not b.fallT or b.fallT>=(data.fallSeconds or .42))or false}
    end
    return targets
end
local function queueMotion(data,old)
    local at=type(data.serverTime)=="number"and data.serverTime or workspace:GetServerTimeNow()
    local age=math.max(0,workspace:GetServerTimeNow()-at)
    local wantedDelay=math.clamp(age+.10,.10,.45)
    local sample={at=at,targets=ballTargets}
    -- Allow for packet delivery age as well as the 15 Hz sampling interval.
    -- Increase immediately on worse latency, release the margin gradually.
    interpolationDelay=math.max(wantedDelay,interpolationDelay-.001)
    -- Placement and new racks are deliberate discontinuities, not ball motion.
    if not old or data.rackId~=old.rackId or data.mode~=old.mode or data.phase~="moving"then
        motionSamples={sample};lastMotionTime=nil;interpolationDelay=wantedDelay
    else
        local previous=motionSamples[#motionSamples]
        if previous and at<=previous.at then motionSamples[#motionSamples]=sample
        else table.insert(motionSamples,sample)end
        if #motionSamples>12 then table.remove(motionSamples,1)end
    end
end
local function renderBalls(now)
    local count=#motionSamples;if count==0 then return end
    if snapshot.phase~="moving"then return end -- poses assigned on state change
    local time=math.max(lastMotionTime or -math.huge,now-interpolationDelay);lastMotionTime=time
    while #motionSamples>2 and motionSamples[2].at<=time do table.remove(motionSamples,1)end
    local a=motionSamples[1];local b=motionSamples[2]or a
    local alpha=b.at>a.at and math.clamp((time-a.at)/(b.at-a.at),0,1)or 1
    for id,to in pairs(b.targets)do
        local from=a.targets[id]or to;local part=ballClones[id]
        if part then
            local hidden=alpha>=1 and to.hidden or from.hidden
            setBallHidden(id,hidden)
            if not hidden then part.CFrame=from.cf:Lerp(to.cf,alpha)end
        end
    end
end
clearPrediction=function(rollback)
    prediction=nil;ownMotion=nil;localStroke=nil
    if rollback and snapshot then
        for id,target in pairs(targetsFrom(snapshot))do local part=ballClones[id];if part then part.CFrame=target.cf;setBallHidden(id,target.hidden)end end
    end
end
startPrediction=function(data,stroke,reconcile)
    if not visualPhysics then return end
    local balls={};for _,b in ipairs(data.balls)do table.insert(balls,table.clone(b))end
    if stroke and not visualPhysics.strike(balls,stroke.angle,stroke.power,data.mode,data.cueId,stroke.spin)then return end
    local params=visualPhysics.parameters(data.mode)
    local trace=visualPhysics.newTrace(balls,data.cueId,params)
    -- Account for bounded delivery age, never rewind the server or award a pot.
    if reconcile then
        local steps=math.min(12,math.floor(math.max(0,workspace:GetServerTimeNow()-(data.serverTime or workspace:GetServerTimeNow()))/visualPhysics.DT))
        for _=1,steps do visualPhysics.step(balls,params,trace);trace.audio={}end
    end
    local from={};if reconcile then for id,part in pairs(ballClones)do from[id]=part.CFrame end end
    prediction={balls=balls,params=params,trace=trace,at=os.clock(),elapsed=0,accumulator=0,from=from}
end
local function renderPrediction(dt)
    if not prediction then return false end
    local p=prediction
    -- A dropped response gets at most 0.8 s of local simulation and four steps/frame.
    if os.clock()-p.at<=.8 and p.elapsed<.8 then
        p.accumulator+=math.min(math.max(dt,0),1/30)
        local steps=0
        while p.accumulator>=visualPhysics.DT and steps<4 and p.elapsed<.8 do
            visualPhysics.step(p.balls,p.params,p.trace);p.trace.audio={}
            p.accumulator-=visualPhysics.DT;p.elapsed+=visualPhysics.DT;steps+=1
        end
    end
    local alpha=math.clamp((os.clock()-p.at+math.min(math.max(dt,0),1/60))/.08,0,1)
    for _,b in ipairs(p.balls)do
        local part=ballClones[b.id]
        if part then
            local hidden=b.pocketed and(not b.fallT or b.fallT>=(snapshot.fallSeconds or .42))or false
            setBallHidden(b.id,hidden)
            if not hidden then local target=ballFrame(b);part.CFrame=p.from[b.id]and p.from[b.id]:Lerp(target,alpha)or target end
        end
    end
    return true
end
local function cleanupVisuals()
    aimDrawKey=nil;clearPrediction(false)
    for _,connection in ipairs(visualConnections)do connection:Disconnect()end;visualConnections={}
    for _,record in ipairs(originalMasks)do
        record.connection:Disconnect()
        if record.object.Parent then
            local desired=record.desired
            if record.property=="Enabled"then
                local owner=record.object.Parent
                while owner and owner.Parent~=sourceBalls do owner=owner.Parent end
                if owner and owner:IsA("BasePart")then desired=owner.Transparency<1 end
            end
            record.object[record.property]=desired
        end
    end
    originalMasks={};ballVisibility={};motionSamples={};lastMotionTime=nil;interpolationDelay=.10
    visualMode=nil;sourceBalls=nil;visualDirty=true;nextVisualRetry=0
    if localModel then localModel:Destroy();localModel=nil end
    ballClones={};ballTargets={};cue,cueShaft,cueFerrule,cueTip,aimLine,afterLine,contactRing=nil,nil,nil,nil,nil,nil,nil
    cueMarker=nil;homeLine=nil;homeBadge=nil
end
local function beginVisuals()
    if localModel and sourceBalls and sourceBalls.Parent and visualMode==snapshot.mode and not visualDirty then return end
    local club=workspace:FindFirstChild("SpyClub");local tableModel=club and club:FindFirstChild("ClubBilliards")
    local readyBalls=tableModel and tableModel:FindFirstChild("Balls")
    if not snapshot or not readyBalls or tableModel:GetAttribute("Mode")~=snapshot.mode or #readyBalls:GetChildren()~=#snapshot.balls then return end
    if localModel then cleanupVisuals()end
    visualMode=snapshot.mode;sourceBalls=readyBalls;visualDirty=false
    table.insert(visualConnections,sourceBalls.DescendantAdded:Connect(function()visualDirty=true end))
    table.insert(visualConnections,sourceBalls.ChildRemoved:Connect(function()visualDirty=true end))
    table.insert(visualConnections,tableModel:GetAttributeChangedSignal("Mode"):Connect(function()visualDirty=true end))
    localModel=Instance.new("Model");localModel.Name="LocalBilliardsAim";localModel.Parent=workspace
    cue=visualPart("Cue",Color3.fromRGB(87,62,43),Enum.Material.Wood)
    cueShaft=visualPart("CueShaft",Color3.fromRGB(210,190,150))
    cueFerrule=visualPart("CueFerrule",Color3.fromRGB(224,221,202))
    cueTip=visualPart("CueTip",Color3.fromRGB(68,103,108))
    for _,section in ipairs({cue,cueShaft,cueFerrule,cueTip})do section.Shape=Enum.PartType.Cylinder end
    aimLine=visualPart("Aim",Color3.fromRGB(222,217,187),Enum.Material.Neon)
    afterLine=visualPart("ObjectDirection",Color3.fromRGB(133,189,159),Enum.Material.Neon)
    contactRing=visualPart("Contact",palette.ivory);contactRing.Shape=Enum.PartType.Ball;contactRing.Size=Vector3.new(.09,.09,.09)
    local root=workspace:FindFirstChild("SpyClub")
    local model=root and root:FindFirstChild("ClubBilliards")
    local balls=model and model:FindFirstChild("Balls")
    if balls then
        for _,p in ipairs(balls:GetChildren())do
            if p:IsA("BasePart")then
                local id=p:GetAttribute("BallId")
                if type(id)=="number"then
                    local copy=p:Clone();copy.Name="LocalBall"..id;copy.LocalTransparencyModifier=0;copy.Parent=localModel
                    for _,g in ipairs(copy:GetDescendants())do
                        if g:IsA("SurfaceGui")then g.Enabled=true
                        elseif g:IsA("BasePart")then g.LocalTransparencyModifier=0 end
                    end
                    ballClones[id]=copy
                    local record={parts={copy},surfaces={}};ballVisibility[id]=record
                    for _,object in ipairs(copy:GetDescendants())do
                        if object:IsA("BasePart")then table.insert(record.parts,object)
                        elseif object:IsA("SurfaceGui")then table.insert(record.surfaces,object)end
                    end
                end
            end
        end
    end
    local count=0;for _ in pairs(ballClones)do count+=1 end
    if count~=#snapshot.balls then visualMode=nil end
    ballTargets=targetsFrom(snapshot)
    motionSamples={{at=snapshot.serverTime or workspace:GetServerTimeNow(),targets=ballTargets}}
    for id,target in pairs(ballTargets)do
        local clone=ballClones[id]
        if clone then clone.CFrame=target.cf;setBallHidden(id,target.hidden)end
    end
    cueMarker=Instance.new("BillboardGui");cueMarker.Name="SelectedCue";cueMarker.Size=UDim2.fromOffset(30,30);cueMarker.AlwaysOnTop=true;cueMarker.LightInfluence=0;cueMarker.Parent=localModel
    local ring=Instance.new("Frame");ring.Size=UDim2.fromScale(1,1);ring.BackgroundTransparency=1;ring.Parent=cueMarker;rounded(ring,15)
    local edge=Instance.new("UIStroke");edge.Color=Color3.fromRGB(176,216,186);edge.Thickness=1.5;edge.Parent=ring
    homeLine=visualPart("HomeLine",palette.brass,Enum.Material.Neon);homeLine.Transparency=1
    local homeAnchor=visualPart("HomeAnchor",palette.brass);homeAnchor.Transparency=1
    homeAnchor.CFrame=CFrame.new(snapshot.center+Vector3.new(-snapshot.halfX*.75*snapshot.scale,snapshot.height+.02,0))
    homeBadge=Instance.new("BillboardGui");homeBadge.Name="HomeArea";homeBadge.Adornee=homeAnchor;homeBadge.Size=UDim2.fromOffset(52,22);homeBadge.AlwaysOnTop=true;homeBadge.LightInfluence=0;homeBadge.Enabled=false;homeBadge.Parent=localModel
    local homeText=label(homeBadge,"Label","ДОМ",13);homeText.TextColor3=palette.brass;homeText.Size=UDim2.fromScale(1,1);homeText.TextXAlignment=Enum.TextXAlignment.Center
    hideOriginals()
end
-- Own only properties which obscure the pool view, and restore the latest
-- intended state. A lobby refresh cannot put its dock back over this HUD.
local function suppress(object,property,value)
    if contextRecords[object]then return end
    local record={property=property,desired=object[property],setting=false}
    contextRecords[object]=record
    local function apply()
        record.setting=true;object[property]=value;record.setting=false
    end
    record.connection=object:GetPropertyChangedSignal(property):Connect(function()
        if not opened or record.setting or object[property]==value then return end
        record.desired=object[property];apply()
    end)
    apply()
end
local function characterObject(object)
    local parent=object.Parent
    while parent and parent~=workspace do
        for _,p in ipairs(Players:GetPlayers())do if parent==p.Character then return true end end
        parent=parent.Parent
    end
    return false
end
local function suppressContextObject(object)
    if not opened then return end
    if object:IsA("GuiObject")and (object.Name=="MainAction"or object.Name=="BottomDesk"or object.Name=="DailyDock"or object.Name=="TopStatus"or object.Name=="MobileMenu"or object.Name=="QuickChatButton"or object.Name=="QuickChatPanel")then
        suppress(object,"Visible",false)
    elseif object:IsA("ScreenGui")and object.Name=="SpyLobbyPolishUI"then
        suppress(object,"Enabled",false)
    elseif object:IsA("ProximityPrompt")and object.Name=="BilliardsEnter"then
        suppress(object,"Enabled",false)
    elseif object:IsA("BasePart")and snapshot and object.Position.Y>=14 and math.abs(object.Position.X-snapshot.center.X)<24 and math.abs(object.Position.Z-snapshot.center.Z)<24 then
        suppress(object,"LocalTransparencyModifier",1)
    elseif (object:IsA("BasePart")or(object:IsA("BillboardGui")and object.Name=="SpyRankTag"))and characterObject(object)then
        suppress(object,object:IsA("BasePart")and "LocalTransparencyModifier"or "Enabled",object:IsA("BasePart")and 1 or false)
    end
end
local function hideContext()
    local pg=player:FindFirstChild("PlayerGui")
    if pg then for _,object in ipairs(pg:GetDescendants())do suppressContextObject(object)end end
    local club=workspace:FindFirstChild("SpyClub")
    local tableModel=club and club:FindFirstChild("ClubBilliards")
    if club then for _,object in ipairs(club:GetDescendants())do if object:IsA("BasePart")and object.Position.Y>=14 then suppressContextObject(object)end end end
    if tableModel then
        local anchor=tableModel:FindFirstChild("JoinPoint")
        local prompt=anchor and anchor:FindFirstChild("BilliardsEnter")
        if prompt then suppressContextObject(prompt)end
    end
    for _,p in ipairs(Players:GetPlayers())do
        if p.Character then for _,object in ipairs(p.Character:GetDescendants())do suppressContextObject(object)end end
    end
end
local function restoreContext()
    for object,record in pairs(contextRecords)do
        record.connection:Disconnect()
        if object.Parent then object[record.property]=record.desired end
    end
    contextRecords={}
end
workspace.DescendantAdded:Connect(suppressContextObject)
local playerGui=player:WaitForChild("PlayerGui",5)
if playerGui then playerGui.DescendantAdded:Connect(suppressContextObject)end
local function releaseCamera()
    local camera=workspace.CurrentCamera
    if cameraRestore and camera then
        camera.CameraType=cameraRestore.kind;camera.FieldOfView=cameraRestore.fov
        camera.CameraSubject=cameraRestore.subject;camera.CFrame=cameraRestore.cf
    end
    cameraRestore=nil
    if disabledControls then pcall(function()disabledControls:Enable()end);disabledControls=nil end
end
local function close()
    cameraLayoutKey=nil
    opened=false;cancelPull();shotPending=false;shotRecoveryUntil=0;transportNotice=nil;transportNoticeUntil=0;pushOut=false;pointer=nil;draggingPower=false;aimLocked=true;aimChosen=false;aimTarget=angle;spinExpanded=false;fineAimExpanded=false
    if promptLease~=nil then if PromptService.Enabled==false then PromptService.Enabled=promptLease end;promptLease=nil end
    if gui then gui.Enabled=false end
    if modeSheet then modeSheet.Visible=false end
    selectingCue=false;safety=false;spin={x=0,y=0};spinPointer=nil;foulUntil=0
    if clearPoolPrompt then clearPoolPrompt()end
    releaseCamera();cleanupVisuals();cleanupAudio();restoreContext()
    if layoutUI then layoutUI()end
end
local function enterCamera()
    -- CHARACTER SCENE HANDOFF BEGIN
    if player:GetAttribute('SpyCharacterSceneActive')==true or player:GetAttribute('SpyCharacterMenuOpen')==true then
        local pg=player:FindFirstChildOfClass('PlayerGui');local close=pg and pg:FindFirstChild('SpyOpenDossier')
        if close and close:IsA('BindableEvent')then close:Fire('close',false)end
        player:SetAttribute('SpyCharacterSceneInterrupt',(tonumber(player:GetAttribute('SpyCharacterSceneInterrupt'))or 0)+1)
    end
    -- CHARACTER SCENE HANDOFF END
    local camera=workspace.CurrentCamera
    if camera and not cameraRestore then
        cameraRestore={kind=camera.CameraType,subject=camera.CameraSubject,fov=camera.FieldOfView,cf=camera.CFrame}
    end
    if member() and not disabledControls then
        pcall(function()
            local scripts=player:FindFirstChild("PlayerScripts")
            local module=scripts and scripts:FindFirstChild("PlayerModule")
            if module then
                local controls=require(module):GetControls()
                if controls.controlsEnabled~=false then controls:Disable();disabledControls=controls end
            end
        end)
    end
end
-- BILLIARDS_PRESENTATION_BEGIN
-- Actual HUD constructors, callbacks, responsive layout, and public-state presenter.
local function angleLabel()
    angle=(angle+360)%360
    if angleBox and not angleBox:IsFocused() then angleBox.Text=string.format("%.2f°",angle) end
    if powerText then powerText.Text=math.floor(power*100+.5).."%";powerFill.Size=UDim2.fromScale(1,power)end
    if aimButton then
        if snapshot and snapshot.mode=="pyramid"then aimButton.Text=selectingCue and "Отмена"or(panel.AbsoluteSize.X<340 and "Биток"or "Выбрать биток")
        else aimButton.Text=panel.AbsoluteSize.X<340 and "Заново"or "Перенавести"end
    end
end
local function pointIn(object,position)
    if not object or not object.Visible then return false end
    local p,s=object.AbsolutePosition,object.AbsoluteSize
    return position.X>=p.X and position.X<=p.X+s.X and position.Y>=p.Y and position.Y<=p.Y+s.Y
end
local function updateSpinPoint(position)
    if not canAim()then return end
    local p,size=spinHit.AbsolutePosition,spinHit.AbsoluteSize
    local x=(position.X-p.X-size.X*.5)/math.max(1,size.X*.42)
    local y=-(position.Y-p.Y-size.Y*.5)/math.max(1,size.Y*.42)
    local length=math.sqrt(x*x+y*y);local limit=snapshot.tipLimit or .72
    if length>limit then x*=limit/length;y*=limit/length end;spin.x,spin.y=x,y
end
local function buildAccessories()
    spinFrame=Instance.new("Frame");spinFrame.Name="SpinControl";spinFrame.AnchorPoint=Vector2.new(1,1);spinFrame.BackgroundColor3=palette.panel;spinFrame.BackgroundTransparency=.06;spinFrame.BorderSizePixel=0;spinFrame.Parent=gui;rounded(spinFrame,4)
    spinCaption=label(spinFrame,"Caption","Точка удара",14);spinCaption.Position=UDim2.fromOffset(10,5);spinCaption.Size=UDim2.new(1,-20,0,22);spinCaption.TextXAlignment=Enum.TextXAlignment.Center;spinCaption.Font=Enum.Font.BuilderSansMedium
    spinClose=button(spinFrame,"Close","×");spinClose.Position=UDim2.new(1,-44,0,0);spinClose.Size=UDim2.fromOffset(44,44);spinClose.BackgroundTransparency=1;spinClose.Visible=false
    spinClose.Activated:Connect(function()spinExpanded=false;spinFrame.Visible=false end)
    spinToggle=button(gui,"SpinToggle","Подкрутка");spinToggle.AnchorPoint=Vector2.new(1,1);spinToggle.Size=UDim2.fromOffset(112,44);spinToggle.Visible=false
    spinToggle.Activated:Connect(function()spinExpanded=not spinExpanded;if spinExpanded then fineAimExpanded=false end;spinFrame.Visible=spinExpanded;if layoutUI then layoutUI()end end)
    local viewport=Instance.new("ViewportFrame");viewport.Name="CueBallPreview";viewport.BackgroundTransparency=1;viewport.Ambient=Color3.fromRGB(135,143,150);viewport.LightColor=Color3.fromRGB(255,242,218);viewport.LightDirection=Vector3.new(-1,-1,-2);viewport.Parent=spinFrame
    local world=Instance.new("WorldModel");world.Parent=viewport
    local sphere=Instance.new("Part");sphere.Name="ActualCueBall";sphere.Shape=Enum.PartType.Ball;sphere.Size=Vector3.new(2,2,2);sphere.Color=palette.ivory;sphere.Material=Enum.Material.SmoothPlastic;sphere.Reflectance=.08;sphere.Anchored=true;sphere.CanCollide=false;sphere.Parent=world
    local cam=Instance.new("Camera");cam.CFrame=CFrame.lookAt(Vector3.new(0,0,4),Vector3.zero);cam.FieldOfView=35;cam.Parent=viewport;viewport.CurrentCamera=cam
    spinHit=Instance.new("TextButton");spinHit.Name="HitArea";spinHit.Text="";spinHit.BackgroundTransparency=1;spinHit.AutoButtonColor=false;spinHit.Parent=spinFrame
    local fixed=Instance.new("UIScale");fixed.Name="BilliardsInputScale";fixed.Scale=1;fixed.Parent=spinHit
    spinMarker=Instance.new("Frame");spinMarker.Name="TipPoint";spinMarker.AnchorPoint=Vector2.new(.5,.5);spinMarker.Size=UDim2.fromOffset(10,10);spinMarker.BackgroundColor3=palette.brass;spinMarker.BorderSizePixel=0;spinMarker.Parent=spinHit;rounded(spinMarker,5)
    local outline=Instance.new("UIStroke");outline.Color=Color3.fromRGB(29,32,33);outline.Thickness=2;outline.Parent=spinMarker
    for _,vertical in ipairs({true,false})do
        local mark=Instance.new("Frame");mark.Name="CenterGuide";mark.BackgroundColor3=Color3.fromRGB(75,78,78);mark.BackgroundTransparency=.45;mark.AnchorPoint=Vector2.new(.5,.5);mark.Position=UDim2.fromScale(.5,.5);mark.Size=vertical and UDim2.fromOffset(1,8)or UDim2.fromOffset(8,1);mark.BorderSizePixel=0;mark.Parent=spinHit
    end
    spinReset=button(spinFrame,"Center","В центр");spinReset.BackgroundTransparency=1;spinReset.TextColor3=palette.muted
    spinReset.Activated:Connect(function()if canAim()then spin.x,spin.y=0,0 end end)
    spinHit.InputBegan:Connect(function(input)if canAim()and(input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch)then spinPointer=input;updateSpinPoint(input.Position)end end)
    Input.InputChanged:Connect(function(input)if spinPointer and(input==spinPointer or input.UserInputType==Enum.UserInputType.MouseMovement)then updateSpinPoint(input.Position)end end)
    Input.InputEnded:Connect(function(input)if input==spinPointer or input.UserInputType==Enum.UserInputType.MouseButton1 then spinPointer=nil end end)
    local function arrangeSpin()
        local size=math.max(64,spinFrame.Size.X.Offset-24);viewport.Position=UDim2.fromOffset(12,44);viewport.Size=UDim2.fromOffset(size,size);spinHit.Position=viewport.Position;spinHit.Size=viewport.Size
        spinReset.Position=UDim2.new(0,6,1,-48);spinReset.Size=UDim2.new(1,-12,0,44)
    end
    spinFrame:GetPropertyChangedSignal("Size"):Connect(arrangeSpin);arrangeSpin()
    pushOutButton=button(gui,"PushOut","Push-out");pushOutButton.AnchorPoint=Vector2.new(.5,0);pushOutButton.Position=UDim2.new(.5,0,0,110);pushOutButton.Size=UDim2.fromOffset(112,44);pushOutButton.Visible=false
    pushOutButton.Activated:Connect(function()if canAim()and snapshot.mode=="pool9"and snapshot.pushOutAvailable then cancelPull();pushOut=not pushOut end end)
    decisionFrame=Instance.new("Frame");decisionFrame.Name="DecisionControl";decisionFrame.AnchorPoint=Vector2.new(.5,.5);decisionFrame.Position=UDim2.fromScale(.5,.38);decisionFrame.Size=UDim2.fromOffset(290,250);decisionFrame.BackgroundColor3=palette.panel;decisionFrame.BorderSizePixel=0;decisionFrame.Visible=false;decisionFrame.Parent=gui;rounded(decisionFrame,10)
    local title=label(decisionFrame,"Title","После разбоя",20);title.Position=UDim2.fromOffset(14,10);title.Size=UDim2.new(1,-28,0,28)
    local description=label(decisionFrame,"Description","",13);description.Position=UDim2.fromOffset(14,40);description.Size=UDim2.new(1,-28,0,46);description.TextWrapped=true;description.TextColor3=palette.muted
    local names={accept="Принять позицию",hand="Биток с руки из дома",pass="Вернуть удар сопернику",rerack_self="Расставить · бью я",rerack_other="Расставить · бьёт соперник"}
    for name,text in pairs(names)do local b=button(decisionFrame,name,text);b.Size=UDim2.new(1,-28,0,44);b.Visible=false;b.Activated:Connect(function()send("decision",{choice=name})end)end
end

local function copy(ru,en,zh)
 local lang=player:GetAttribute("SpyLanguage")
 return lang=="en"and en or lang=="zh"and zh or ru
end

local function buildGui()
    if gui then return end
    gui=Instance.new("ScreenGui");gui.Name="SpyBilliardsHUD";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false
    gui.DisplayOrder=82;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=player:WaitForChild("PlayerGui")
    panel=Instance.new("Frame");panel.Name="PoolPanel";panel.AnchorPoint=Vector2.new(.5,1);panel.Position=UDim2.new(.5,0,1,-12)
    panel.Size=UDim2.new(1,-32,0,112);panel.BackgroundColor3=palette.panel;panel.BorderSizePixel=0;panel.Parent=gui;rounded(panel,4);panel.BackgroundTransparency=.08
    local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(860,140);limit.MinSize=Vector2.new(280,104);limit.Parent=panel
    local border=Instance.new("UIStroke");border.Color=palette.ivory;border.Transparency=.87;border.Thickness=1;border.Parent=panel
    local dockRule=Instance.new("Frame");dockRule.Name="DockRule";dockRule.Position=UDim2.fromOffset(16,57);dockRule.Size=UDim2.new(1,-32,0,1);dockRule.BackgroundColor3=palette.ivory;dockRule.BackgroundTransparency=.88;dockRule.BorderSizePixel=0;dockRule.Parent=panel
    score=label(panel,"Score","Тренировка",18);score.Position=UDim2.fromOffset(16,9);score.Size=UDim2.new(.5,-88,0,26)
    score.TextTruncate=Enum.TextTruncate.AtEnd
    foulToast=label(panel,"FoulNotice","",15);foulToast.Position=UDim2.new(0,0,0,-52);foulToast.Size=UDim2.new(1,0,0,42);foulToast.BackgroundTransparency=.05;foulToast.BackgroundColor3=palette.panel;foulToast.TextColor3=Color3.fromRGB(218,157,150);foulToast.TextXAlignment=Enum.TextXAlignment.Center;foulToast.TextWrapped=true;foulToast.Visible=false;rounded(foulToast,8)
    scoreValue=label(panel,"ScoreValue","0",26);scoreValue.Visible=false;scoreValue.Font=Enum.Font.BuilderSansMedium
    scoreValue.AnchorPoint=Vector2.new(.5,0);scoreValue.Position=UDim2.new(.5,0,0,5);scoreValue.Size=UDim2.fromOffset(120,32);scoreValue.TextXAlignment=Enum.TextXAlignment.Center
    local exit=button(panel,"Exit","Выйти");exit.AnchorPoint=Vector2.new(1,0);exit.Position=UDim2.new(1,-14,0,8);exit.Size=UDim2.fromOffset(72,30)
    exit.Activated:Connect(function()send("leave");close()end)
    note=label(panel,"Turn","Твой ход",15);note.TextColor3=palette.muted;note.Position=UDim2.fromOffset(16,38);note.Size=UDim2.new(1,-150,0,23);note.TextTruncate=Enum.TextTruncate.AtEnd
    shotHint=label(panel,"ShotHint","",14);shotHint.TextColor3=palette.muted;shotHint.TextTruncate=Enum.TextTruncate.AtEnd
    remainingLabel=label(panel,"Remaining","15 шаров",14);remainingLabel.TextColor3=palette.muted
    remainingLabel.AnchorPoint=Vector2.new(1,0);remainingLabel.Position=UDim2.new(1,-16,0,38);remainingLabel.Size=UDim2.fromOffset(112,23);remainingLabel.TextXAlignment=Enum.TextXAlignment.Right
    topHud=Instance.new("Frame");topHud.Name="Players";topHud.BackgroundTransparency=1;topHud.AnchorPoint=Vector2.new(.5,0);topHud.Position=UDim2.new(.5,0,0,8);topHud.Size=UDim2.new(1,-24,0,94);topHud.Parent=gui
    playerCards={}
    for index=1,2 do
        local card=Instance.new("Frame");card.Name=index==1 and "PlayerOne"or "PlayerTwo";card.BackgroundColor3=palette.panel;card.BorderSizePixel=0;card.Parent=topHud;rounded(card,7)
        local edge=Instance.new("UIStroke");edge.Color=palette.ivory;edge.Transparency=1;edge.Parent=card
        local name=label(card,"PlayerName","",14);name.Position=UDim2.fromOffset(10,5);name.Size=UDim2.new(1,-64,0,23);name.TextTruncate=Enum.TextTruncate.AtEnd
        local value=label(card,"Points","0",24);value.Font=Enum.Font.BuilderSansMedium;value.AnchorPoint=Vector2.new(1,0);value.Position=UDim2.new(1,-8,0,4);value.Size=UDim2.fromOffset(45,25);value.TextXAlignment=Enum.TextXAlignment.Right
        local target=label(card,"Target","Открытый стол",13);target.TextColor3=palette.muted;target.Position=UDim2.fromOffset(10,30);target.Size=UDim2.new(1,-20,0,19);target.TextTruncate=Enum.TextTruncate.AtEnd
        local avatar=Instance.new("ImageLabel");avatar.Name="Avatar";avatar.BackgroundColor3=palette.panel;avatar.BorderSizePixel=0;avatar.Size=UDim2.fromOffset(34,34);avatar.Position=UDim2.fromOffset(8,6);avatar.Parent=card;rounded(avatar,17)
        local balls=Instance.new("Frame");balls.Name="Balls";balls.BackgroundTransparency=1;balls.Parent=card
        playerCards[index]={frame=card,name=name,value=value,target=target,edge=edge,avatar=avatar,balls=balls,icons={}}

    end
    nineGuide=Instance.new("Frame");nineGuide.Name="NineBallGuide";nineGuide.AnchorPoint=Vector2.new(.5,0);nineGuide.BackgroundColor3=palette.panel;nineGuide.BackgroundTransparency=.14;nineGuide.BorderSizePixel=0;nineGuide.Visible=false;nineGuide.Parent=gui;rounded(nineGuide,14)
    local first=label(nineGuide,"Target","",17);first.Font=Enum.Font.BuilderSansBold;first.Position=UDim2.fromOffset(14,7);first.Size=UDim2.new(1,-28,0,24);first.TextXAlignment=Enum.TextXAlignment.Center
    local goal=label(nineGuide,"Goal","",15);goal.Position=UDim2.fromOffset(14,33);goal.Size=UDim2.new(1,-28,0,24);goal.TextXAlignment=Enum.TextXAlignment.Center;goal.TextColor3=palette.muted
    local warning=label(nineGuide,"Warning","",14);warning.Position=UDim2.fromOffset(14,60);warning.Size=UDim2.new(1,-28,0,22);warning.TextXAlignment=Enum.TextXAlignment.Center;warning.TextColor3=Color3.fromRGB(218,157,150);warning.Visible=false
    roundResult=Instance.new("Frame");roundResult.Name="RoundResult";roundResult.AnchorPoint=Vector2.new(.5,.5);roundResult.Position=UDim2.fromScale(.5,.46);roundResult.BackgroundColor3=palette.panel;roundResult.BackgroundTransparency=.08;roundResult.BorderSizePixel=0;roundResult.Visible=false;roundResult.ZIndex=20;roundResult.Parent=gui;rounded(roundResult,4)
    local edge=Instance.new("UIStroke");edge.Color=palette.brass;edge.Transparency=.65;edge.Thickness=1;edge.Parent=roundResult
    local headline=label(roundResult,"Headline","",32);headline.Font=Enum.Font.Garamond;headline.Position=UDim2.fromOffset(20,14);headline.Size=UDim2.new(1,-40,0,40);headline.TextXAlignment=Enum.TextXAlignment.Center
    local winner=label(roundResult,"Winner","",19);winner.Font=Enum.Font.BuilderSansBold;winner.Position=UDim2.fromOffset(20,56);winner.Size=UDim2.new(1,-40,0,28);winner.TextXAlignment=Enum.TextXAlignment.Center;winner.TextTruncate=Enum.TextTruncate.AtEnd;winner:SetAttribute("SpyUserText",true)
    local reason=label(roundResult,"Reason","",15);reason.Position=UDim2.fromOffset(20,88);reason.Size=UDim2.new(1,-40,0,48);reason.TextWrapped=true;reason.TextXAlignment=Enum.TextXAlignment.Center;reason.TextColor3=palette.muted
    local again=button(roundResult,"Again","",palette.green);again.Position=UDim2.new(0,16,1,-60);again.Size=UDim2.new(.5,-20,0,44);again.TextSize=16
    again.Activated:Connect(function()if snapshot and snapshot.phase=="finished"and member()then send("reset")end end)
    local leave=button(roundResult,"Leave","");leave.Position=UDim2.new(.5,4,1,-60);leave.Size=UDim2.new(.5,-20,0,44);leave.TextSize=16
    leave.Activated:Connect(function()send("leave");close()end)
    for _,node in ipairs(roundResult:GetDescendants())do if node:IsA("GuiObject")then node.ZIndex=21 end end
    local controls=Instance.new("Frame");controls.Name="Controls";controls.BackgroundTransparency=1;controls.Position=UDim2.fromOffset(14,68);controls.Size=UDim2.new(1,-28,0,46);controls.Parent=panel
    powerBar=button(gui,"CuePower","",palette.panel);powerBar.ClipsDescendants=true;powerBar.AnchorPoint=Vector2.new(0,0);powerBar.Position=UDim2.new(0,24,.56,0);powerBar.Size=UDim2.fromOffset(78,240);rounded(powerBar,4)
    local powerEdge=Instance.new("UIStroke");powerEdge.Color=palette.brass;powerEdge.Transparency=.65;powerEdge.Parent=powerBar
    powerFill=Instance.new("Frame");powerFill.Name="Fill";powerFill.AnchorPoint=Vector2.new(0,1);powerFill.Position=UDim2.fromScale(0,1);powerFill.BackgroundColor3=palette.ivory;powerFill.BackgroundTransparency=.88;powerFill.BorderSizePixel=0;powerFill.Size=UDim2.fromScale(1,power);powerFill.Parent=powerBar;rounded(powerFill,4)
    powerText=label(powerBar,"Value","60%",24);powerText.Font=Enum.Font.BuilderSansBold;powerText.Position=UDim2.fromOffset(0,8);powerText.Size=UDim2.new(1,0,0,30);powerText.TextXAlignment=Enum.TextXAlignment.Center;powerText.ZIndex=3
    local pullCue=Instance.new("Frame");pullCue.Name="Handle";pullCue.Size=UDim2.fromOffset(6,112);pullCue.AnchorPoint=Vector2.new(.5,0);pullCue.Position=UDim2.new(.5,0,0,18);pullCue.BackgroundColor3=Color3.fromRGB(186,144,92);pullCue.BorderSizePixel=0;pullCue.Parent=powerBar;rounded(pullCue,3)
    local cueTip=Instance.new("Frame");cueTip.Size=UDim2.fromOffset(6,8);cueTip.BackgroundColor3=Color3.fromRGB(95,161,172);cueTip.BorderSizePixel=0;cueTip.Parent=pullCue
    local pullHint=label(powerBar,"Hint",copy("СИЛА","POWER","力量"),15);pullHint.Font=Enum.Font.BuilderSansBold;pullHint.Position=UDim2.new(0,0,1,-31);pullHint.Size=UDim2.new(1,0,0,24);pullHint.TextXAlignment=Enum.TextXAlignment.Center;pullHint.TextColor3=palette.ivory;pullHint.ZIndex=3
    shotButton=button(controls,"Shoot","Удар",palette.green);shotButton.TextSize=18
    shotButton.AnchorPoint=Vector2.new(1,0);shotButton.Position=UDim2.new(1,0,0,0);shotButton.Size=UDim2.fromOffset(144,46)
    local spinSummary=label(powerBar,"SpinSummary","",12);spinSummary.TextXAlignment=Enum.TextXAlignment.Center;spinSummary.Position=UDim2.new(0,0,1,-23);spinSummary.Size=UDim2.new(1,0,0,20);spinSummary.ZIndex=3;spinSummary.TextColor3=palette.ivory
    local function beginCharge(input)
        if shotPending or not canAim()or not aimChosen or selectingCue or pointer or powerPointer or spinPointer or Input:GetFocusedTextBox()or math.abs((aimTarget-angle+180)%360-180)>.2 then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.Space then
            powerPointer=input;pullOriginal=power;chargeStarted=os.clock();draggingPower=true;power=.08;aimTarget=angle;aimLocked=true;angleLabel()
        end
    end
    beginPowerHold=beginCharge
    shotButton.InputBegan:Connect(beginCharge)
    -- Activated fires after release too; it must never duplicate the stroke.
    shotButton.Activated:Connect(function()
        if snapshot and snapshot.phase=="finished"and member()then send("reset")end
    end)
    shotButton:SetAttribute("SpyHoldPower",true)
    -- Precision controls retain stable geometry while global feedback adds audio.
    for _,target in ipairs({shotButton,powerBar,spinHit})do
        if target then local fixed=Instance.new("UIScale");fixed.Name="BilliardsInputScale";fixed.Scale=1;fixed.Parent=target end
    end
    -- Fine aim is secondary to power and the shot; all controls remain available.
    local left=button(controls,"AngleLeft","−");left.Position=UDim2.fromOffset(0,54);left.Size=UDim2.fromOffset(32,30)
    left.Activated:Connect(function()if canAim()then aimLocked=true;angle-=1;aimTarget=angle;aimChosen=true;angleLabel()end end)
    angleBox=Instance.new("TextBox");angleBox.Name="Angle";angleBox.Position=UDim2.fromOffset(36,54);angleBox.Size=UDim2.fromOffset(64,30)
    angleBox.BackgroundColor3=Color3.fromRGB(32,37,38);angleBox.TextColor3=palette.ivory;angleBox.TextSize=14;angleBox.Font=Enum.Font.BuilderSansMedium
    angleBox.ClearTextOnFocus=false;angleBox.PlaceholderText="Угол °";angleBox.BorderSizePixel=0;angleBox.Parent=controls;rounded(angleBox,6)
    angleBox.FocusLost:Connect(function()
        local cleaned=angleBox.Text:gsub("°","");local value=tonumber(cleaned)
        if canAim()and value and value==value and math.abs(value)<100000 then angle=value;aimTarget=angle;aimChosen=true;aimLocked=true end;angleLabel()
    end)
    local right=button(controls,"AngleRight","+");right.Position=UDim2.fromOffset(104,54);right.Size=UDim2.fromOffset(32,30)
    right.Activated:Connect(function()if canAim()then aimLocked=true;angle+=1;aimTarget=angle;aimChosen=true;angleLabel()end end)
    fineAimToggle=button(controls,"FineAim","Прицел");fineAimToggle.BackgroundTransparency=1;fineAimToggle.TextColor3=palette.brass
    fineAimToggle.Activated:Connect(function()if draggingPower then return end;fineAimExpanded=not fineAimExpanded;if fineAimExpanded then spinExpanded=false;spinFrame.Visible=false end;if layoutUI then layoutUI()end end)
    aimButton=button(panel,"AimLock","Зафиксировать");aimButton.Position=UDim2.fromOffset(162,122);aimButton.Size=UDim2.fromOffset(116,30);aimButton.TextSize=13
    aimButton.Activated:Connect(function()
        if not canAim()then return end
        if snapshot.mode=="pyramid"then if snapshot.shots>0 then selectingCue=not selectingCue;instructions.Visible=false end
        else pointer=nil;aimChosen=false;aimTarget=angle;aimLocked=true end
        angleLabel()
    end)
    local rulesToggle=button(panel,"RulesToggle","Правила ?");rulesToggle.BackgroundTransparency=1;rulesToggle.AnchorPoint=Vector2.new(1,0);rulesToggle.Position=UDim2.new(1,-14,0,122);rulesToggle.Size=UDim2.fromOffset(72,30);rulesToggle.TextColor3=palette.muted
    joinButton=button(panel,"Join","Начать тренировку",palette.green);joinButton.TextSize=17;joinButton.Position=UDim2.fromOffset(14,68);joinButton.Size=UDim2.new(1,-28,0,46)
    joinButton.Activated:Connect(function()
        local offer=snapshot and snapshot.joinOffer
        if offer and offer.id==player.UserId then send("join_cancel",{token=offer.token})else showModePicker()end
    end)
    joinConsent=Instance.new("Frame");joinConsent.Name="JoinConsent";joinConsent.AnchorPoint=Vector2.new(.5,.5);joinConsent.Position=UDim2.fromScale(.5,.44)
    joinConsent.Size=UDim2.fromOffset(420,172);joinConsent.BackgroundColor3=palette.panel;joinConsent.BackgroundTransparency=.04;joinConsent.BorderSizePixel=0;joinConsent.Visible=false;joinConsent.Parent=gui;rounded(joinConsent,4)
    local requestName=label(joinConsent,"Requester","",19);requestName.Font=Enum.Font.BuilderSansBold;requestName.Position=UDim2.fromOffset(16,12);requestName.Size=UDim2.new(1,-32,0,30);requestName.TextTruncate=Enum.TextTruncate.AtEnd
    local requestText=label(joinConsent,"Description","",15);requestText.Position=UDim2.fromOffset(16,48);requestText.Size=UDim2.new(1,-32,0,52);requestText.TextWrapped=true;requestText.TextColor3=palette.muted
    local approve=button(joinConsent,"PlayTogether","",palette.green);approve.Position=UDim2.new(0,16,1,-56);approve.Size=UDim2.new(.5,-20,0,44);approve.TextSize=16;approve.TextWrapped=true
    local decline=button(joinConsent,"KeepTraining","");decline.Position=UDim2.new(.5,4,1,-56);decline.Size=UDim2.new(.5,-20,0,44);decline.TextSize=16;decline.TextWrapped=true
    local function decide(value)local offer=snapshot and snapshot.joinOffer;if offer and offer.owner==player.UserId then send("join_decision",{token=offer.token,accept=value})end end
    approve.Activated:Connect(function()decide(true)end);decline.Activated:Connect(function()decide(false)end)
    joinConsent.ZIndex=40;for _,n in ipairs(joinConsent:GetDescendants())do if n:IsA("GuiObject")then n.ZIndex=41 end end
    instructions=Instance.new("ScrollingFrame");instructions.ScrollBarThickness=3;instructions.ScrollBarImageColor3=palette.brass;instructions.CanvasSize=UDim2.fromOffset(0,306);instructions.Name="Instructions";instructions.Active=true;instructions.AnchorPoint=Vector2.new(0,1);instructions.Position=UDim2.new(0,0,0,-10);instructions.Size=UDim2.new(1,0,0,144)
    instructions.BackgroundColor3=palette.panel;instructions.BorderSizePixel=0;instructions.Visible=false;instructions.Parent=panel;rounded(instructions,4)
    local rulesHeading=label(instructions,"RulesHeading",copy("Правила стола","Table rules","球桌规则"),26);rulesHeading.Font=Enum.Font.Garamond;rulesHeading.Position=UDim2.fromOffset(16,12);rulesHeading.Size=UDim2.new(1,-32,0,32)
    local rules=label(instructions,"Rules","Выбранные правила действуют для всей партии.",14)
    rules.Position=UDim2.fromOffset(16,12);rules.Size=UDim2.new(1,-32,0,42);rules.TextWrapped=true
    local help=label(instructions,"Help",copy("Наведи кий на столе.\nЗажми СИЛУ и отпусти для удара. Esc — отмена.","Aim on the table.\nHold POWER and release to shoot. Esc cancels.","在球桌上瞄准。\n按住力量后松开击球。Esc取消。"),14)
    help.Position=UDim2.fromOffset(16,59);help.Size=UDim2.new(1,-32,0,42);help.TextColor3=palette.muted;help.TextWrapped=true
    resetButton=button(instructions,"Rerack","Новая партия");resetButton.Position=UDim2.fromOffset(16,106);resetButton.Size=UDim2.fromOffset(128,44)
    resetButton.Activated:Connect(function()send("reset");instructions.Visible=false end)
    local configure=button(instructions,"Configure","Выбор игры");configure.Position=UDim2.fromOffset(154,106);configure.Size=UDim2.fromOffset(118,44)
    configure.Activated:Connect(function()instructions.Visible=false;showModePicker()end)
    selectButton=button(instructions,"ChooseCue","Выбрать биток");selectButton.Position=UDim2.fromOffset(16,142);selectButton.Size=UDim2.fromOffset(136,44)
    selectButton.Activated:Connect(function()if snapshot and snapshot.mode=="pool8"and snapshot.canSpotHome then send("spot_home");instructions.Visible=false elseif canAim()and snapshot.mode=="pyramid"and snapshot.shots>0 then selectingCue=true;instructions.Visible=false end end)
    passButton=button(instructions,"ReturnTurn","Вернуть ход");passButton.Position=UDim2.fromOffset(160,142);passButton.Size=UDim2.fromOffset(112,44)
    passButton.Activated:Connect(function()send("pass");instructions.Visible=false end)
    modeSheet=Instance.new("TextButton");modeSheet.Name="ModePicker";modeSheet.Size=UDim2.fromScale(1,1);modeSheet.BackgroundColor3=Color3.new(0,0,0);modeSheet.BackgroundTransparency=.42;modeSheet.Text="";modeSheet.AutoButtonColor=false;modeSheet.Visible=false;modeSheet.ZIndex=10;modeSheet.Parent=gui
    local sheetScale=Instance.new("UIScale");sheetScale.Name="BilliardsSheetScale";sheetScale.Scale=1;sheetScale.Parent=modeSheet
    modeFrame=Instance.new("Frame");modeFrame.Name="Sheet";modeFrame.AnchorPoint=Vector2.new(.5,.5);modeFrame.Position=UDim2.fromScale(.5,.5);modeFrame.Size=UDim2.new(1,-24,0,544);modeFrame.BackgroundColor3=palette.panel;modeFrame.BorderSizePixel=0;modeFrame.Parent=modeSheet;modeFrame.ZIndex=11;rounded(modeFrame,4);modeFrame.BackgroundTransparency=.04
    local sheetEdge=Instance.new("UIStroke");sheetEdge.Color=palette.muted;sheetEdge.Transparency=.72;sheetEdge.Thickness=1;sheetEdge.Parent=modeFrame
    local modeLimit=Instance.new("UISizeConstraint");modeLimit.MaxSize=Vector2.new(620,680);modeLimit.MinSize=Vector2.new(200,240);modeLimit.Parent=modeFrame
    local heading=label(modeFrame,"Heading","За бильярдный стол",23);heading.Font=Enum.Font.Garamond;heading.Position=UDim2.fromOffset(18,14);heading.Size=UDim2.new(1,-108,0,28)
    local folio=label(modeFrame,"Folio","SPY CLUB  /  БИЛЬЯРД",11);folio.TextColor3=palette.muted;folio.Position=UDim2.fromOffset(24,16);folio.Size=UDim2.new(1,-96,0,16)
    local headerRule=Instance.new("Frame");headerRule.Name="HeaderRule";headerRule.BackgroundColor3=palette.muted;headerRule.BackgroundTransparency=.72;headerRule.BorderSizePixel=0;headerRule.Parent=modeFrame
    local caption=label(modeFrame,"Caption","Тренировка или партия с другом",14);caption.TextColor3=palette.muted;caption.Position=UDim2.fromOffset(18,44);caption.Size=UDim2.new(1,-36,0,24)
    local dismiss=button(modeFrame,"Close","Назад");dismiss.AnchorPoint=Vector2.new(1,0);dismiss.Position=UDim2.new(1,-16,0,14);dismiss.Size=UDim2.fromOffset(72,44)
    dismiss.Activated:Connect(function()modeSheet.Visible=false;panel.Visible=true end)
    local content=Instance.new("ScrollingFrame");content.Name="Content";content.Position=UDim2.fromOffset(0,78);content.Size=UDim2.new(1,0,1,-90);content.BackgroundTransparency=1;content.BorderSizePixel=0;content.ScrollBarThickness=3;content.ScrollBarImageColor3=palette.brass;content.CanvasSize=UDim2.fromOffset(0,710);content.Parent=modeFrame
    modeButtons={}
    local titles={pool8="Пул · Восьмёрка",pyramid="Русский бильярд",pool9="Пул · Девятка",challenge=copy("Пять ударов","Five shots","五次击球")}
    local subtitles={pool8="Своя группа, затем восьмёрка",pyramid="Свободная пирамида · до 8 шаров",pool9="Младший первым · комбинации на девятку",challenge=copy("Один игрок · реальный стол · до 50 очков","Solo · real table · up to 50 points","单人 · 实体球桌 · 最高50分")}
    for index,mode in ipairs({"pool8","pyramid","pool9","challenge"})do
        local card=button(content,"Mode_"..mode,"");card.Position=UDim2.fromOffset(18,(index-1)*90);card.Size=UDim2.new(1,-36,0,80)
        local edge=Instance.new("UIStroke");edge.Color=palette.ivory;edge.Transparency=.86;edge.Parent=card
        local numeral=label(card,"Number",string.format("%02d",index),28);numeral.Font=Enum.Font.Garamond;numeral.TextColor3=palette.muted;numeral.Position=UDim2.fromOffset(12,10);numeral.Size=UDim2.fromOffset(34,34)
        local selected=Instance.new("Frame");selected.Name="Selected";selected.Size=UDim2.new(0,2,1,-24);selected.Position=UDim2.fromOffset(0,12);selected.BackgroundColor3=palette.ivory;selected.BorderSizePixel=0;selected.Visible=false;selected.Parent=card
        local title=label(card,"Title",titles[mode],23);title.Font=Enum.Font.Garamond;title.Position=UDim2.fromOffset(56,8);title.Size=UDim2.new(1,-70,0,28)
        local desc=label(card,"Discipline",subtitles[mode],14);desc.TextColor3=palette.muted;desc.Position=UDim2.fromOffset(56,38);desc.Size=UDim2.new(1,-70,0,36);desc.TextWrapped=true;desc.TextYAlignment=Enum.TextYAlignment.Top
        card.Activated:Connect(function()if canConfigure()then draftMode=mode;updateModePicker()end end);modeButtons[mode]={button=card,edge=edge,title=title,desc=desc,selected=selected}
    end
    modeDescription=label(content,"Description","",14);modeDescription.Position=UDim2.fromOffset(18,366);modeDescription.Size=UDim2.new(1,-36,0,68);modeDescription.TextWrapped=true;modeDescription.TextColor3=palette.muted
    timeButton=button(content,"Time","Ход: 60 с");timeButton.Position=UDim2.fromOffset(18,444);timeButton.Size=UDim2.new(1,-36,0,44)
    timeButton.Activated:Connect(function()if canConfigure()then draftSeconds=draftSeconds==45 and 60 or(draftSeconds==60 and 90 or 45);updateModePicker()end end)
    startButton=button(modeFrame,"Start","Начать тренировку",palette.green);startButton.Position=UDim2.fromOffset(18,500);startButton.Size=UDim2.new(1,-36,0,46);startButton.TextSize=18
    startButton.Activated:Connect(function()send(member()and "reset"or "join",canConfigure()and {mode=draftMode,turnSeconds=draftSeconds}or nil)end)
    local clubBoard=label(content,"ClubLeaderboard","",14);clubBoard.Position=UDim2.fromOffset(18,560);clubBoard.Size=UDim2.new(1,-36,0,140);clubBoard.TextWrapped=true;clubBoard.TextYAlignment=Enum.TextYAlignment.Top;clubBoard.TextColor3=palette.ivory
    updateModePicker=function()
        if not snapshot then return end
        for mode,entry in pairs(modeButtons)do entry.button.Active=canConfigure();entry.button.BackgroundColor3=mode==draftMode and palette.panel2 or palette.panel;entry.edge.Transparency=mode==draftMode and .3 or .86;entry.selected.Visible=mode==draftMode end
        local descriptions={pool8="Забей свою группу, затем восьмёрку. Выбирать лузу не нужно. Чужой шар после правильного первого касания — без штрафа. Фол даёт сопернику биток с руки.",pyramid="После разбоя выбирай любой биток. Свояк засчитывается. После фола соперник снимает один шар на свою полку.",pool9="Первым коснись младшего шара. Законно забитая девятка — победа, даже комбинацией. После разбоя доступен push-out. Три фола подряд — поражение."}
        modeDescription.Text=draftMode=="challenge"and copy("5 ударов. За шар +3, за касание +1, за биток −2. До 10 за удар. Рекорд сохраняется без наград.","5 shots. +3 per object ball, +1 for contact, −2 for a scratch. Up to 10 per shot. Best score saved; no rewards.","5次击球。每进一球+3，碰球+1，母球入袋−2。每次最多10分。保存纪录，无奖励。")or descriptions[draftMode];
        timeButton.Visible=draftMode~="challenge"
        local lines={copy("Рекорды игроков в этом клубе","Best scores · players in this club","本俱乐部玩家纪录")}
        for index,entry in ipairs(snapshot.clubLeaderboard and snapshot.clubLeaderboard.entries or {})do if index<=4 then table.insert(lines,index..". "..entry.name.."  ·  "..entry.score.."/50")end end
        if #lines==1 then table.insert(lines,copy("Пока нет завершённых попыток","No completed attempts yet","暂无完成记录"))end
        clubBoard.Text=table.concat(lines,"\n");clubBoard:SetAttribute("SpyUserText",true);timeButton.Text="Ход: "..(draftSeconds==30 and 60 or draftSeconds).." с";timeButton.Active=canConfigure()
        local guest=not member()and #snapshot.players==1
        startButton.Active=not snapshot.joinOffer and(guest or snapshot.phase~="moving"and snapshot.phase~="penalty"and snapshot.phase~="decision")and(member()~=nil or #snapshot.players<2)
        startButton.Text=guest and copy("Попросить сыграть","Request to play","请求一起玩")or draftMode=="challenge"and copy("Начать 5 ударов","Start five shots","开始五次击球")or(member()and "Новая партия"or "Начать тренировку")
        if layoutUI then layoutUI()end
    end
    showModePicker=function()cancelPull();draftMode,draftSeconds=snapshot.challenge and "challenge"or snapshot.mode,snapshot.turnSeconds;modeSheet.Visible=true;panel.Visible=false;updateModePicker()end
    buildAccessories()
    rulesToggle.Activated:Connect(function()cancelPull();instructions.Visible=not instructions.Visible end)
    layoutUI=function()
        local view=canvasSize();local narrow=view.X<600;local tiny=view.X<380;local short=view.Y<520
        local inset=short and 12 or 16
        local panelWidth=math.min(860,view.X-inset*2)
        local controlY=short and 80 or 88
        local controlHeight=44
        local inlineFineAim=short and panelWidth>=430
        local fineAimRow=fineAimExpanded and not inlineFineAim and 48 or 0
        local panelHeight=controlY+controlHeight+12+fineAimRow
        limit.MinSize=Vector2.new(math.min(200,panelWidth),104);limit.MaxSize=Vector2.new(860,220)
        panel.Size=UDim2.fromOffset(panelWidth,panelHeight);panel.Position=UDim2.new(.5,0,1,-12)
        panel.DockRule.Position=UDim2.fromOffset(16,controlY-9);panel.DockRule.Size=UDim2.new(1,-32,0,1)
        local hudHeight=short and 78 or(tiny and 82 or 86)
        topHud.Size=UDim2.fromOffset(math.min(760,view.X-24),hudHeight)
        topHud.Position=UDim2.new(.5,0,0,8)
        score.Visible=true;score.Position=UDim2.fromOffset(16,7);score.Size=UDim2.new(1,-156,0,18);score.TextSize=14;score.Font=Enum.Font.BuilderSansMedium;score.TextColor3=palette.muted
        for i,entry in ipairs(playerCards)do
            entry.frame.Position=UDim2.new((i-1)*.5,(i-1)*4,0,0);entry.frame.Size=UDim2.new(.5,-4,1,0)
            local portraitSize=tiny and 26 or 32
            entry.avatar.Visible=not(short and view.X<600);entry.avatar.Size=UDim2.fromOffset(portraitSize,portraitSize);entry.avatar.Position=UDim2.fromOffset(8,8)
            local nameX=entry.avatar.Visible and(portraitSize+16)or 10
            entry.name.Position=UDim2.fromOffset(nameX,7);entry.name.Size=UDim2.new(1,-nameX-(tiny and 34 or 54),0,22);entry.name.TextSize=14;entry.name.Font=Enum.Font.BuilderSansMedium
            entry.value.Position=UDim2.new(1,-8,0,5);entry.value.Size=UDim2.fromOffset(tiny and 30 or 46,28);entry.value.TextSize=tiny and 22 or 27;entry.value.Font=Enum.Font.Garamond;entry.value.TextColor3=palette.ivory
            entry.target.Position=UDim2.fromOffset(10,short and 33 or 37);entry.target.Size=UDim2.new(1,-20,0,20);entry.target.TextSize=14;entry.target.Font=Enum.Font.BuilderSansMedium;entry.target.TextColor3=palette.muted
            entry.balls.Position=UDim2.fromOffset(10,short and 55 or 62);entry.balls.Size=UDim2.new(1,-20,0,tiny and 12 or 20)
        end
        local actualControlY=controlY+fineAimRow
        controls.Position=UDim2.fromOffset(16,actualControlY);controls.Size=UDim2.new(1,-32,0,controlHeight);joinButton.Position=controls.Position;joinButton.Size=UDim2.new(1,-32,0,controlHeight)
        note.Position=UDim2.fromOffset(16,28);note.Size=UDim2.new(1,-132,0,26);note.TextSize=tiny and 22 or 25;note.Font=Enum.Font.Garamond;note.TextTruncate=Enum.TextTruncate.AtEnd
        shotHint.Position=UDim2.fromOffset(16,short and 54 or 58);shotHint.Size=UDim2.new(1,-32,0,20);shotHint.TextSize=14;shotHint.Font=Enum.Font.BuilderSansMedium
        remainingLabel.Visible=true;remainingLabel.Position=UDim2.new(1,-16,0,31);remainingLabel.Size=UDim2.fromOffset(100,22);remainingLabel.TextSize=14;remainingLabel.Font=Enum.Font.BuilderSansMedium
        local shotWidth=tiny and 100 or(narrow and 126 or 194)
        shotButton.Size=UDim2.fromOffset(shotWidth,controlHeight);shotButton.TextWrapped=true;shotButton.Font=Enum.Font.BuilderSansMedium;shotButton.TextSize=tiny and 14 or 16;rounded(shotButton,4)
        local powerWidth=narrow and 64 or 88
        powerBar.Size=UDim2.fromOffset(powerWidth,short and 72 or 84);powerBar.Handle.Visible=false;powerBar.Active=false
        powerBar.Position=UDim2.fromOffset(12,hudHeight+20)
        powerText.TextSize=short and 24 or 28;powerText.Font=Enum.Font.Garamond;powerText.Position=UDim2.fromOffset(0,4);powerText.Size=UDim2.new(1,0,0,short and 24 or 30)
        pullHint.Position=UDim2.fromOffset(0,short and 30 or 36);pullHint.Size=UDim2.new(1,0,0,18);pullHint.TextSize=14
        powerBar.SpinSummary.TextSize=short and 11 or 12;powerBar.SpinSummary.Position=UDim2.new(0,0,1,-21);powerBar.SpinSummary.Size=UDim2.new(1,0,0,18)
        fineAimToggle.Position=UDim2.fromOffset(0,0);fineAimToggle.Size=UDim2.fromOffset(tiny and 52 or 88,controlHeight);fineAimToggle.TextSize=14
        fineAimToggle.Text=fineAimExpanded and copy("Готово","Done","完成")or(tiny and "Точно"or "Прицел");fineAimToggle.Visible=true
        left.Position=UDim2.fromOffset(inlineFineAim and 100 or 0,inlineFineAim and 0 or -48);left.Size=UDim2.fromOffset(44,controlHeight);left.Visible=fineAimExpanded
        angleBox.Position=UDim2.fromOffset(inlineFineAim and 148 or 48,inlineFineAim and 0 or -48);angleBox.Size=UDim2.fromOffset(60,controlHeight);angleBox.Visible=fineAimExpanded
        right.Position=UDim2.fromOffset(inlineFineAim and 212 or 112,inlineFineAim and 0 or -48);right.Size=left.Size;right.Visible=fineAimExpanded
        aimButton.Position=UDim2.fromOffset(tiny and 80 or(narrow and 120 or 136),actualControlY)
        aimButton.Visible=member()~=nil and not fineAimExpanded;aimButton.Size=UDim2.fromOffset(tiny and 48 or(narrow and 92 or 148),controlHeight);aimButton.TextSize=14;aimButton.BackgroundTransparency=1;aimButton.TextColor3=palette.muted
        local exit=panel.Exit;exit.Position=UDim2.new(1,-12,0,0);exit.Size=UDim2.fromOffset(52,44);exit.BackgroundTransparency=1;exit.TextSize=14;exit.TextColor3=palette.muted
        rulesToggle.Position=UDim2.new(1,-128,0,0);rulesToggle.Size=UDim2.fromOffset(72,44);rulesToggle.TextSize=14;rulesToggle.Text="Правила"
        local textHeight=game:GetService("TextService"):GetTextSize(rules.Text,14,rules.Font,Vector2.new(math.max(160,panelWidth-32),1000)).Y
        local rulesHeight=math.max(64,textHeight+8)
        rules.Position=UDim2.fromOffset(16,54);rules.Size=UDim2.new(1,-32,0,rulesHeight);rules.TextYAlignment=Enum.TextYAlignment.Top
        help.Position=UDim2.fromOffset(16,66+rulesHeight);help.Size=UDim2.new(1,-32,0,64);help.TextYAlignment=Enum.TextYAlignment.Top
        local row=140+rulesHeight;local stack=panelWidth<420
        local actionWidth=stack and panelWidth-32 or(panelWidth-44)*.5
        resetButton.Position=UDim2.fromOffset(16,row);resetButton.Size=UDim2.fromOffset(actionWidth,44)
        configure.Position=UDim2.fromOffset(stack and 16 or 28+actionWidth,row+(stack and 50 or 0));configure.Size=resetButton.Size
        selectButton.Position=UDim2.fromOffset(16,row+(stack and 100 or 50));selectButton.Size=resetButton.Size
        passButton.Position=UDim2.fromOffset(stack and 16 or 28+actionWidth,row+(stack and 150 or 50));passButton.Size=resetButton.Size
        local ruleCanvas=row+(stack and 210 or 110)
        instructions.CanvasSize=UDim2.fromOffset(0,ruleCanvas);instructions.Size=UDim2.new(1,0,0,math.max(64,math.min(ruleCanvas,320,view.Y-panelHeight-36)));instructions.Position=UDim2.new(0,0,0,-12)
        local sheetWidth=math.min(620,view.X-24);local sheetHeight=math.min(680,view.Y-24)
        modeFrame.Size=UDim2.fromOffset(sheetWidth,sheetHeight)
        local sheetInset=tiny and 16 or 24
        folio.Position=UDim2.fromOffset(sheetInset,14);folio.Size=UDim2.new(1,-104,0,16)
        heading.Text=copy("За бильярдный стол","At the billiard table","来到台球桌");heading.TextSize=view.X<320 and 25 or(tiny and 29 or 38);heading.Position=UDim2.fromOffset(sheetInset,35);heading.Size=UDim2.new(1,-sheetInset*2,0,44)
        caption.Position=UDim2.fromOffset(sheetInset,82);caption.Size=UDim2.new(1,-sheetInset*2,0,22);caption.TextSize=14;caption.TextTruncate=Enum.TextTruncate.AtEnd
        dismiss.Text="×";dismiss.TextSize=24;dismiss.BackgroundTransparency=1;dismiss.Position=UDim2.new(1,-sheetInset+4,0,4);dismiss.Size=UDim2.fromOffset(44,44)
        headerRule.Position=UDim2.fromOffset(sheetInset,113);headerRule.Size=UDim2.new(1,-sheetInset*2,0,1)
        local headerHeight=short and 78 or 124
        if short then folio.Visible=false;heading.Position=UDim2.fromOffset(sheetInset,10);heading.TextSize=30;caption.Position=UDim2.fromOffset(sheetInset,48);headerRule.Position=UDim2.fromOffset(sheetInset,73)else folio.Visible=true end
        content.Position=UDim2.fromOffset(0,headerHeight);content.Size=UDim2.new(1,0,1,-headerHeight-76)
        local rowHeight=tiny and 84 or 82;local rowGap=8
        for index,mode in ipairs({"pool8","pyramid","pool9","challenge"})do
            local entry=modeButtons[mode];entry.button.Position=UDim2.fromOffset(sheetInset,(index-1)*(rowHeight+rowGap));entry.button.Size=UDim2.new(1,-sheetInset*2,0,rowHeight)
            entry.title.TextSize=tiny and 20 or 24;entry.title.Position=UDim2.fromOffset(tiny and 48 or 56,8);entry.title.Size=UDim2.new(1,tiny and -60 or -70,0,28)
            entry.desc.Position=UDim2.fromOffset(tiny and 48 or 56,39);entry.desc.Size=UDim2.new(1,tiny and -60 or -70,0,36)
        end
        local detailY=4*(rowHeight+rowGap)+8
        local detailHeight=tiny and 112 or 76
        modeDescription.Position=UDim2.fromOffset(sheetInset,detailY);modeDescription.Size=UDim2.new(1,-sheetInset*2,0,detailHeight);modeDescription.TextYAlignment=Enum.TextYAlignment.Top
        local timerY=detailY+detailHeight+8
        timeButton.Position=UDim2.fromOffset(sheetInset,timerY);timeButton.Size=UDim2.new(1,-sheetInset*2,0,44)
        clubBoard.Position=UDim2.fromOffset(sheetInset,timerY+(timeButton.Visible and 60 or 8));clubBoard.Size=UDim2.new(1,-sheetInset*2,0,140);clubBoard.TextColor3=palette.muted
        content.CanvasSize=UDim2.fromOffset(0,clubBoard.Position.Y.Offset+152)
        startButton.Position=UDim2.new(0,sheetInset,1,-60);startButton.Size=UDim2.new(1,-sheetInset*2,0,44);startButton.TextSize=16
        local spinWidth=short and 96 or(narrow and 112 or 144)
        compactSpin=view.Y<740 or view.X<900
        spinFrame.Size=UDim2.fromOffset(spinWidth,spinWidth+72);spinFrame.Position=UDim2.new(1,-12,1,-panelHeight-24)
        spinToggle.Position=UDim2.new(1,-12,1,-panelHeight-24);spinToggle.Size=UDim2.fromOffset(narrow and 112 or 128,44)
        spinClose.Visible=compactSpin;spinCaption.Size=UDim2.new(1,compactSpin and -56 or -20,0,22);spinCaption.TextSize=14;spinCaption.TextTruncate=Enum.TextTruncate.AtEnd
        joinConsent.Size=UDim2.fromOffset(math.min(420,view.X-24),math.min(tiny and 204 or 184,view.Y-24))
        joinConsent.Requester.TextSize=tiny and 17 or 19;joinConsent.PlayTogether.TextSize=14;joinConsent.KeepTraining.TextSize=14
        roundResult.Size=UDim2.fromOffset(math.min(480,view.X-24),math.min(232,view.Y-24));roundResult.Headline.TextSize=tiny and 30 or 38
        roundResult.Headline.Position=UDim2.fromOffset(16,12);roundResult.Headline.Size=UDim2.new(1,-32,0,44)
        roundResult.Winner.Position=UDim2.fromOffset(16,60);roundResult.Winner.Size=UDim2.new(1,-32,0,28)
        roundResult.Reason.Position=UDim2.fromOffset(16,94);roundResult.Reason.Size=UDim2.new(1,-32,0,60);roundResult.Reason.Visible=true
        nineGuide.Position=UDim2.new(.5,0,0,hudHeight+20);nineGuide.Size=UDim2.fromOffset(math.min(420,view.X-32),nineGuide.Warning.Visible and 88 or 64)
        nineGuide.Visible=snapshot~=nil and snapshot.mode=="pool9"and snapshot.phase~="finished"and view.Y>=420 and not modeSheet.Visible
        -- Keep the power readout outside the central nine-ball guidance strip.
        if nineGuide.Visible and not narrow then nineGuide.Size=UDim2.fromOffset(math.min(420,view.X-232),nineGuide.Size.Y.Offset)end
        if nineGuide.Visible and narrow then powerBar.Position=UDim2.fromOffset(12,hudHeight+nineGuide.Size.Y.Offset+32)end
        pushOutButton.Position=UDim2.new(.5,0,0,hudHeight+22+(nineGuide.Visible and nineGuide.Size.Y.Offset+8 or 0))
        decisionFrame.Position=UDim2.fromScale(.5,.42)
        for _,object in ipairs(modeFrame:GetDescendants())do if object:IsA("GuiObject")then object.ZIndex=12 end end
    end
    rules:GetPropertyChangedSignal("Text"):Connect(layoutUI)
    panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutUI);gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutUI);layoutUI();angleLabel()
    local camera=workspace.CurrentCamera;if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutUI)end
end
local errors={challenge_solo="Пять ударов · только один игрок",rate_limited="Слишком быстро · повтори удар через секунду",table_full="Стол занят двумя игроками",balls_moving="Подожди остановки шаров",not_your_turn="Сейчас ход соперника",stale_state="Стол обновился · повтори действие",unavailable="Подойди к столу вне основной игры",match_in_progress="Правила меняются между партиями",bad_shot="Сила удара: от 8 до 100%",turn_expired="Время хода истекло",bad_placement="Здесь биток не помещается",place_cue="Поставь биток на свободное место",bad_rules="Выбери доступные правила",host_only="Правила выбирает создатель партии"}
local foulNames={wrong_first="первым задет чужой шар",opponent_potted="забит чужой шар",scratch="биток в лузе",no_contact="нет касания шара",no_rail="недостаточно движения после касания",weak_break="слабый разбой",timeout="время истекло",early_eight="восьмёрка забита раньше своих шаров",illegal_eight="восьмёрка забита с нарушением",contract_missed="контракт не выполнен",bad_home="из дома сначала нужно выйти за линию"}
local function foulText(mode,code)
    if mode=="pool9"and code=="wrong_first"then return "первым нужен младший шар"end
    return foulNames[code]or "нарушение правил"
end
local function updateHud()
    if not snapshot or not gui then return end
    if draggingPower and(not canAim(true)or instructions.Visible)then cancelPull()end
    panel.Visible=not modeSheet.Visible and(snapshot.phase~="finished"or not member())
    pushOutButton.Visible=canAim()and snapshot.mode=="pool9"and snapshot.pushOutAvailable;pushOutButton.BackgroundColor3=pushOut and palette.green or palette.panel
    local me=member();local myTurn=me~=nil and snapshot.turn==player.UserId
    score.Text=snapshot.challenge and copy("Пять ударов","Five shots","五次击球")or snapshot.mode=="pyramid"and "Русский"or(snapshot.mode=="pool9"and "Пул · 9"or "Пул · 8")
    scoreValue.Text=tostring(me and me.score or 0)
    for i,card in ipairs(playerCards)do
        local p=snapshot.players[i];local active=p and snapshot.turn==p.id and snapshot.phase~="finished"
        card.name:SetAttribute("SpyUserText",p~=nil and p.id~=player.UserId);card.name:SetAttribute("SpyLocalize",p==nil or p.id==player.UserId)
        card.name.Text=p and(p.id==player.UserId and "Ты"or p.name)or "Свободное место"
        local seconds=math.max(0,math.ceil((snapshot.deadline or 0)-workspace:GetServerTimeNow()))
        card.value.Text=p and(snapshot.mode=="pyramid"and(p.score.."/8")or tostring(p.score))or "—"
        card.avatar.Image=p and("rbxthumb://type=AvatarHeadShot&id="..p.id.."&w=150&h=150")or ""
        local narrow=panel.AbsoluteSize.X<500
        card.target.Text=not p and "Позови друга"or(snapshot.mode=="pyramid"and(active and(snapshot.cueId==0 and "Жёлтый биток"or "Биток: "..snapshot.cueId)or "До 8 шаров")or(p.targetEight and(narrow and "Восьмёрка"or "Цель: восьмёрка")or(p.group=="solids"and "Цельные · 1–7"or(p.group=="stripes"and(narrow and "Полосы · 9–15"or "Полосатые · 9–15")or(narrow and "После разбоя"or "Группы после разбоя")))))
        if snapshot.challenge then
            card.target.Text=p and copy("Любой шар · ","Any object ball · ","任意目标球 · ")..tostring(snapshot.challenge.shots).."/5"or copy("Соло · 5 ударов","Solo · 5 shots","单人 · 5次击球")
        end
        if snapshot.mode=="pool9"and p then
            card.target.Text=p.foulWarning and copy("2 фола · ещё один — поражение","2 fouls · next one loses","已连续2次犯规，再犯即负")or(copy("Сначала №","First hit #","先碰#")..tostring(snapshot.lowest or 9))
        end
        local wanted={}
        if p and snapshot.mode=="pool8"and p.group then
            for id=p.group=="solids"and 1 or 9,p.group=="solids"and 7 or 15 do table.insert(wanted,id)end;table.insert(wanted,8)
        elseif p and snapshot.mode=="pool9"then for id=1,9 do table.insert(wanted,id)end end
        for _,icon in pairs(card.icons)do icon.Visible=false end
        local colors={Color3.fromRGB(231,179,40),Color3.fromRGB(49,94,174),Color3.fromRGB(184,52,43),Color3.fromRGB(112,66,149),Color3.fromRGB(220,117,43),Color3.fromRGB(39,126,81),Color3.fromRGB(128,38,50),Color3.fromRGB(25,25,27)}
        local tiny=topHud.Size.X.Offset<340;local small=topHud.Size.X.Offset<500;local size=tiny and 10 or(small and 12 or 20)
        size=math.min(size,math.max(8,math.floor((card.balls.AbsoluteSize.X-math.max(0,#wanted-1)*2)/math.max(1,#wanted))))
        for n,id in ipairs(wanted)do
            local icon=card.icons[id]
            if not icon then
                icon=button(card.balls,"Ball"..id,tostring(id),colors[(id-1)%8+1]);icon.TextSize=10;icon.Font=Enum.Font.BuilderSansMedium;rounded(icon,16)
                if id>=9 then local stripe=Instance.new("UIStroke");stripe.Color=palette.ivory;stripe.Thickness=2;stripe.Parent=icon end
                card.icons[id]=icon
            end
            local gone=true;for _,b in ipairs(snapshot.balls)do if b.id==id then gone=b.pocketed end end
            icon.Visible=true;icon.Size=UDim2.fromOffset(size,size);icon.Position=UDim2.fromOffset((n-1)*(size+2),0)
            icon.BackgroundTransparency=gone and .82 or 0;icon.TextTransparency=gone and .65 or 0;icon.TextSize=tiny and 8 or 10;icon.Active=false;icon.AutoButtonColor=false
        end
        card.edge.Transparency=active and .55 or .90;card.frame.BackgroundColor3=active and palette.panel2 or palette.panel
    end
    joinButton.Visible=not me;panel.Controls.Visible=me~=nil;aimButton.Visible=me~=nil and not fineAimExpanded
    topHud.Visible=not modeSheet.Visible;powerBar.Visible=me~=nil and not modeSheet.Visible and snapshot.phase~="finished";powerBar.Active=false
    local observed=observedAim and observedAim.id==snapshot.turn and observedAim or nil
    local shownSpin=myTurn and spin or(observed and observed.spin)
    powerBar.SpinSummary.Text=(powerBar.Size.X.Offset<100 and ""or copy("Вращ ","Spin ","旋转 "))..(shownSpin and string.format("%+.0f/%+.0f",shownSpin.x*100,shownSpin.y*100)or "—")
    remainingLabel.Text=snapshot.challenge and (snapshot.challenge.shots.."/5 · "..snapshot.challenge.score.."/50")or(#snapshot.players==2 and math.max(0,math.ceil((snapshot.deadline or 0)-workspace:GetServerTimeNow()))..copy(" с"," s"," 秒")or copy("Без таймера","No timer","无计时"))
    local offer=snapshot.joinOffer
    local mine=offer and offer.id==player.UserId
    joinButton.Text=mine and copy("Отменить запрос","Cancel request","取消请求")or #snapshot.players>=2 and copy("Стол занят · наблюдение","Table full · watching","球桌已满 · 观战")or #snapshot.players==1 and copy("Попросить сыграть","Request to play","请求一起玩")or copy("Выбрать игру","Choose game","选择游戏")
    joinButton.Active=mine~=nil and mine~=false or #snapshot.players<2 and not offer
    joinConsent.Visible=offer~=nil and offer.owner==player.UserId
    if joinConsent.Visible then
        joinConsent.Requester.Text=offer.name..copy(" хочет сыграть"," wants to play","想一起玩")
        local seconds=math.max(0,math.ceil(offer.expires-workspace:GetServerTimeNow()))
        joinConsent.Description.Text=(snapshot.challenge and copy("Текущая попытка закончится. Начать новую партию?","This attempt will end. Start a new game?","当前练习将结束。开始新对局？")or copy("Начать новую партию вместе? Тренировка продолжится без твоего согласия.","Start a new game together? Practice continues unless you agree.","一起开始新对局？未经同意，练习会继续。")).."  ·  "..seconds..copy(" с"," s"," 秒")
        joinConsent.PlayTogether.Text=copy("Сыграть","Play together","一起玩");joinConsent.KeepTraining.Text=copy("Продолжить тренировку","Keep practicing","继续练习")
        joinConsent.PlayTogether.Active=snapshot.phase~="moving"and snapshot.phase~="penalty"and snapshot.phase~="decision"
    end
    local joinGuidance
    if snapshot.joinOutcome and snapshot.joinOutcome.id==player.UserId then
        local code=snapshot.joinOutcome.code
        if code=="join_declined"or code=="join_expired"then joinGuidance=copy("Тренировка продолжается · пока наблюдай","Practice continues · watch for now","练习继续 · 暂时观战")end
    elseif mine then joinGuidance=copy("Ждём согласия игрока","Waiting for permission","等待玩家同意")end
    local finished=snapshot.phase=="finished"and me~=nil
    local aimed=aimChosen and pointer==nil and math.abs((aimTarget-angle+180)%360-180)<=.2
    local readyShot=canAim()and not draggingPower and not shotPending and not selectingCue and aimed
    aimButton.Active=canAim()and(snapshot.mode~="pyramid"or snapshot.shots>0)
    angleLabel()
    if not myTurn then powerText.Text=observed and(math.floor(observed.power*100+.5).."%")or "—";powerFill.Size=UDim2.fromScale(1,observed and observed.power or 0)end
    shotButton.Active=readyShot or draggingPower or finished;shotButton.BackgroundColor3=(readyShot or finished)and palette.green or palette.panel2;shotButton.TextColor3=(readyShot or finished)and palette.ink or palette.muted
    shotButton.Text=draggingPower and(copy("Отпусти · ","Release · ","松开 · ")..math.floor(power*100+.5).."%")or(readyShot and copy("Зажми СИЛУ","Hold POWER","按住力量")or(snapshot.ballInHand and myTurn and copy("Поставь биток","Place cue ball","放置母球")or copy("Наведи кий","Aim cue","瞄准")))
    if shotPending then shotButton.Text=copy("Удар…","Shot…","击球…")elseif snapshot.phase=="moving"then shotButton.Text=copy("Шары в игре","Balls moving","球移动中")end
    shotButton.TextSize=panel.AbsoluteSize.X<340 and 14 or 16
    resetButton.Visible=me~=nil and(snapshot.phase=="finished"or #snapshot.players==1 or snapshot.shots==0)
    selectButton.Text=snapshot.mode=="pool8"and "Цель из дома"or "Выбрать биток"
    selectButton.Visible=me~=nil and(snapshot.mode=="pyramid"or(snapshot.mode=="pool8"and myTurn and snapshot.canSpotHome));selectButton.Active=(snapshot.mode=="pool8"and myTurn and snapshot.canSpotHome)or(canAim()and snapshot.shots>0)
    passButton.Visible=snapshot.mode=="pyramid"and myTurn and snapshot.canReturn==true
    local rulesText={pyramid="Любой биток после разбоя. Свояк после касания засчитывается. До 8 шаров. Фол: шары возвращаются, соперник выбирает штрафной. Без забитого шара нужен правильный ход через борта / центр.",pool8="Клубная восьмёрка — без заказа лузы. Сначала забей свою группу, затем восьмёрку в любую лузу. Группа определяется первым забитым шаром после разбоя. Чужой шар после правильного первого касания — без штрафа. Фол: биток с руки. Из дома сначала выйти за линию; если все цели в доме — «Цель из дома».",pool9="Первым — младший шар. Любой законно забитый шар сохраняет ход; девятка выигрывает даже комбинацией. Разбой: три шара в лузах / за домом. Фол: биток с руки; три фола подряд — поражение. После чистого разбоя — push-out: соперник принимает или возвращает удар."}
    instructions.Rules.Text=snapshot.challenge and copy("5 ударов: +3 за шар, +1 за касание, −2 за биток. До 10 за удар. Любой прицельный шар, включая №8. Рекорд без монет и опыта.","5 shots: +3 per object ball, +1 for contact, −2 for a scratch. Up to 10 per shot. Any object ball, including #8. Record only; no coins or XP.","5次击球：每进一球+3，碰球+1，母球入袋−2。每次最多10分。可击打任意目标球，包括8号球。仅保存纪录，不给金币或经验。")or rulesText[snapshot.mode]
    local remoteAim=snapshot.aim and snapshot.aim.at>=workspace:GetServerTimeNow()-1.1 and snapshot.aim.id~=player.UserId and snapshot.aim or nil
    local showSpin=not modeSheet.Visible and snapshot.phase=="aiming"and(me~=nil or remoteAim~=nil)
    spinFrame.Visible=showSpin and(not compactSpin or spinExpanded)
    spinToggle.Visible=showSpin and compactSpin and not spinExpanded;spinToggle.Text=remoteAim and "Удар соперника"or "Подкрутка"
    local shown=remoteAim and remoteAim.spin or spin
    spinMarker.Position=UDim2.fromScale(.5+(shown and shown.x or 0)*.42,.5-(shown and shown.y or 0)*.42)
    spinMarker.BackgroundColor3=remoteAim and Color3.fromRGB(163,183,207)or palette.brass
    spinCaption.Text=remoteAim and "Соперник · удар"or "Точка удара";spinHit.Active=canAim();spinReset.Active=canAim();spinReset.Visible=canAim()
    decisionFrame.Visible=snapshot.phase=="decision"and not modeSheet.Visible
    if decisionFrame.Visible then
        for _,b in ipairs(decisionFrame:GetChildren())do if b:IsA("TextButton")then b.Visible=false end end
        for i,choice in ipairs(snapshot.decisionOptions or {})do local b=decisionFrame:FindFirstChild(choice);if b then b.Visible=true;b.Active=myTurn==true;b.Position=UDim2.fromOffset(14,94+(i-1)*48)end end
        decisionFrame.Size=UDim2.fromOffset(math.min(320,canvasSize().X-24),104+#(snapshot.decisionOptions or {})*48)
        decisionFrame.Description.Text=snapshot.note or ""
        decisionFrame.Title.Text=myTurn and(snapshot.decision and snapshot.decision.kind=="nine_pushout"and "После push-out"or "После разбоя")or "Соперник выбирает"
    end
    local turnName="";for _,p in ipairs(snapshot.players)do if p.id==snapshot.turn then turnName=p.id==player.UserId and "ТВОЙ ХОД"or("БЬЁТ: "..p.name)end end
    local guidance=""
    note.TextColor3=palette.ivory
    if shotPending then guidance="Отправляю удар · ожидаю подтверждение"
    elseif os.clock()<shotRecoveryUntil then guidance="Удар не подтверждён · повтори вручную"
    elseif transportNotice and os.clock()<transportNoticeUntil then guidance=transportNotice
    elseif not snapshot.ok and errors[snapshot.code]then guidance=errors[snapshot.code]
    elseif not me and joinGuidance then guidance=joinGuidance
    elseif snapshot.phase=="finished"then
        local winner="";for _,p in ipairs(snapshot.players)do if p.id==snapshot.winner then winner=p.id==player.UserId and "ТЫ ПОБЕДИЛ"or("ПОБЕДА: "..p.name)end end
        guidance=winner~=""and winner or "ПАРТИЯ ПРОИГРАНА"
    elseif snapshot.phase=="moving"then guidance=turnName.." · шары в игре"
    elseif snapshot.phase=="penalty"then guidance=myTurn and "ВЫБЕРИ ШТРАФНОЙ ШАР"or "Соперник выбирает штрафной шар"
    elseif snapshot.ballInHand then guidance=myTurn and(snapshot.ballInHand=="home"and "1 · Поставь биток за линией дома"or "1 · Коснись свободного места для битка")or "Соперник ставит биток"
    elseif draggingPower then guidance=copy("Отпусти — удар","Release to shoot","松开即击球")
    elseif pushOut then guidance="PUSH-OUT · соперник выбирает следующий удар"
    elseif selectingCue then guidance="ВЫБЕРИ БИТОК НА СТОЛЕ"
    elseif snapshot.phase=="decision"then guidance=myTurn and "ВЫБЕРИ ПРОДОЛЖЕНИЕ"or "Соперник выбирает продолжение"
    elseif myTurn and snapshot.phase=="aiming"and not aimChosen then guidance="Зажми стол и наведи прицел"
    elseif myTurn and snapshot.phase=="aiming"and pointer then guidance="Отпусти — направление зафиксируется"
    elseif myTurn and snapshot.phase=="aiming"and not aimed then guidance="Прицел выравнивается…"
    else
        local seconds=math.max(0,math.ceil(snapshot.deadline-workspace:GetServerTimeNow()))
        guidance=myTurn and((snapshot.mode=="pool9"and "Первым №"..tostring(snapshot.lowest).." · "or "")..copy("Зажми СИЛУ и отпусти","Hold POWER, then release","按住力量后松开")..(#snapshot.players>1 and " · "..seconds.." с"or ""))or(turnName.." · "..seconds.." с")
        if snapshot.foul and foulNames[snapshot.foul]and snapshot.phase=="aiming"then guidance=turnName.." · фол: "..foulText(snapshot.mode,snapshot.foul)end
    end
    foulToast.Visible=os.clock()<foulUntil
    -- Phase, action guidance and timer have distinct jobs. No long instruction
    -- can hide whose turn it is or replace the final result.
    shotHint.Text=guidance
    if snapshot.phase=="finished"then
        local winner;for _,p in ipairs(snapshot.players)do if p.id==snapshot.winner then winner=p end end
        note.Text=me and snapshot.winner~=nil and(snapshot.winner==player.UserId and "Ты победил"or "Ты проиграл")or "Партия завершена"
        shotHint.Text=winner and("Победитель: "..winner.name)or(snapshot.note and snapshot.note~=""and snapshot.note or "Открой правила, чтобы начать новую партию")
        note.Font=Enum.Font.BuilderSansBold
    elseif snapshot.phase=="moving"then note.Text=turnName
    elseif snapshot.phase=="waiting"then note.Text=#snapshot.players==0 and "Стол свободен"or "Ждём соперника"
    else note.Text=myTurn and "Твой ход"or(me and "Ход соперника"or "Идёт партия")end
    local ended=snapshot.phase=="finished"
    roundResult.Visible=ended and not modeSheet.Visible
    if ended then
        local winning
        for _,p in ipairs(snapshot.players)do if p.id==snapshot.winner then winning=p end end
        roundResult.Headline.Text=me and(snapshot.winner==player.UserId and copy("Победа","Victory","胜利")or copy("Поражение","Defeat","失败"))or copy("Партия завершена","Rack complete","本局结束")
        if snapshot.challenge then
            roundResult.Headline.Text=copy("Пять ударов завершены","Five shots complete","五次击球完成")
            roundResult.Winner.Text=snapshot.challenge.score.." / 50"
            local best=math.max(snapshot.challenge.score,snapshot.personalBest or 0)
            roundResult.Reason.Text=copy("Забито: ","Potted: ","进球：")..snapshot.challenge.potted..copy(" · Личный рекорд: "," · Personal best: "," · 个人纪录：")..best.."/50"
        else
            roundResult.Winner.Text=winning and winning.name or ""
            roundResult.Reason.Text=snapshot.note or ""
        end
        roundResult.Headline.TextColor3=palette.ivory
        roundResult.Again.Text=copy("Ещё партия","Play again","再来一局");roundResult.Again.Visible=me~=nil;roundResult.Again.Active=me~=nil
        roundResult.Leave.Text=copy("Выйти","Leave","退出")
        roundResult.Leave.Position=UDim2.new(me and .5 or 0,me and 4 or 16,1,-60)
        roundResult.Leave.Size=UDim2.new(me and .5 or 1,me and -20 or -32,0,44)
        topHud.Visible=false;powerBar.Visible=false;spinFrame.Visible=false;spinToggle.Visible=false;pushOutButton.Visible=false;decisionFrame.Visible=false;nineGuide.Visible=false
    else
        local lowest=snapshot.lowest or 9
        nineGuide.Target.Text=copy("Первое касание: №","First contact: #","首先碰球：#")..tostring(lowest)
        nineGuide.Goal.Text=copy("Законно забей №9 — победа","Legally pocket #9 to win","合法打进9号球即可获胜")
        local warned=false;for _,p in ipairs(snapshot.players)do if p.id==snapshot.turn and p.foulWarning then warned=true end end
        nineGuide.Warning.Visible=warned
        nineGuide.Warning.Text=copy("Два фола подряд. Следующий — поражение.","Two consecutive fouls. Next foul loses.","已连续两次犯规，再犯即负。")
    end
    local feedbackKey=tostring(snapshot.mode)..":"..tostring(snapshot.phase)..":"..tostring(nineGuide.Warning.Visible)..":"..tostring(modeSheet.Visible)
    if feedbackKey~=feedbackLayoutKey then feedbackLayoutKey=feedbackKey;if layoutUI then layoutUI()end end
    if modeSheet.Visible then updateModePicker()end
end
-- BILLIARDS_PRESENTATION_END
local function line(part,a,b,width)
    local length=(a-b).Magnitude
    if length<.001 then part.Transparency=1;return end
    part.Transparency=.30;part.Size=Vector3.new(width,width,length);part.CFrame=CFrame.lookAt((a+b)/2,b)
end
local function cueSection(part,a,b,width)
    part.Size=Vector3.new((b-a).Magnitude,width,width)
    part.CFrame=CFrame.lookAt((a+b)*.5,b)*CFrame.Angles(0,math.pi/2,0)
    part.Transparency=0
end
local function drawAim()
    if not cue or not snapshot then return end
    local remote=snapshot.aim
    local liveRemote=remote and remote.at>=workspace:GetServerTimeNow()-1.1
    local stroking=localStroke and os.clock()-localStroke.at<.13
    local key=tostring(snapshot.revision)..":"..snapshot.phase..":"..tostring(canAim(true))..":"..tostring(selectingCue)..":"..tostring(modeSheet.Visible)..":"..tostring(angle)..":"..tostring(power)..":"..tostring(spin.x)..":"..tostring(spin.y)..":"..tostring(liveRemote)..":"..tostring(remote and remote.angle)..":"..tostring(remote and remote.power)..":"..tostring(remote and remote.spin and remote.spin.x)..":"..tostring(remote and remote.spin and remote.spin.y)..":"..tostring(pushOut)..":"..tostring(stroking and os.clock())
    if key==aimDrawKey then return end;aimDrawKey=key
    local me=member();local yourTurn=me~=nil and snapshot.turn==player.UserId and not modeSheet.Visible
    if cueMarker then cueMarker.Adornee=ballClones[snapshot.cueId];cueMarker.Enabled=yourTurn and snapshot.phase=="aiming"end
    if homeLine then
        local showHome=yourTurn and snapshot.phase=="aiming"and snapshot.ballInHand=="home"
        homeBadge.Enabled=showHome
        if showHome then
            local sc=snapshot.scale or 1;local c=snapshot.center;local x=c.X-snapshot.halfX*.5*sc;local y=snapshot.height-(snapshot.radius or .18)*sc+.025
            line(homeLine,Vector3.new(x,y,c.Z-snapshot.halfZ*sc),Vector3.new(x,y,c.Z+snapshot.halfZ*sc),.025*sc);homeLine.Transparency=.6
        else homeLine.Transparency=1 end
    end
    local cueBall=localStroke and os.clock()-localStroke.at<.13 and localStroke.cue or cueBall()
    local remoteAim=snapshot.aim and snapshot.aim.at>=workspace:GetServerTimeNow()-1.1 and snapshot.aim.id~=player.UserId and snapshot.phase=="aiming"and snapshot.aim or nil
    local stroking=localStroke and os.clock()-localStroke.at<.13
    local own=(canAim(true)or stroking)and not selectingCue
    if not(own or remoteAim)or not cueBall or cueBall.pocketed then
        for _,section in ipairs({cue,cueShaft,cueFerrule,cueTip})do section.Transparency=1 end
        aimLine.Transparency=1;afterLine.Transparency=1;contactRing.Transparency=1;return
    end
    local c=snapshot.center;local scale=snapshot.scale or 1;local radius=snapshot.radius or .18;local y=snapshot.height+.03
    local start=Vector3.new(c.X+cueBall.x*scale,y,c.Z+cueBall.z*scale)
    local shownAngle=stroking and localStroke.angle or(own and angle or remoteAim.angle);local shownPower=stroking and localStroke.power*math.max(0,1-(os.clock()-localStroke.at)/.06)or(own and power or remoteAim.power)
    local radians=math.rad(shownAngle);local dx,dz=math.cos(radians),math.sin(radians)
    local direction=Vector3.new(dx,0,dz)
    local length=12
    if dx>.0001 then length=math.min(length,((snapshot.halfX-radius)-cueBall.x)/dx)elseif dx<-.0001 then length=math.min(length,(-(snapshot.halfX-radius)-cueBall.x)/dx)end
    if dz>.0001 then length=math.min(length,((snapshot.halfZ-radius)-cueBall.z)/dz)elseif dz<-.0001 then length=math.min(length,(-(snapshot.halfZ-radius)-cueBall.z)/dz)end
    local hit=nil
    for _,b in ipairs(snapshot.balls)do
        if b.id~=snapshot.cueId and not b.pocketed then
            local bx,bz=b.x-cueBall.x,b.z-cueBall.z;local projection=bx*dx+bz*dz
            local cross=bx*dz-bz*dx
            if projection>0 and math.abs(cross)<radius*2 then
                local distance=projection-math.sqrt((radius*2)^2-cross^2)
                if distance>0 and distance<length then length=distance;hit=b end
            end
        end
    end
    local finish=start+direction*(math.max(.01,length)*scale)
    line(aimLine,start+direction*(.22*scale),finish,.027*scale)
    local shownSpin=own and spin or remoteAim.spin or {x=0,y=0}
    local tipOffset=Vector3.new(-dz,0,dx)*(shownSpin.x*radius*scale)+Vector3.new(0,shownSpin.y*radius*scale,0)
    local nose=start+tipOffset-direction*((radius+.12+shownPower*1.6)*scale)
    local shaftStart=nose-direction*(.12*scale);local joint=nose-direction*(1.92*scale)
    local butt=start+tipOffset-direction*((3.1+shownPower*1.6)*scale)
    cueSection(cue,butt,joint,.080*scale)
    cueSection(cueShaft,joint,shaftStart,.047*scale)
    cueSection(cueFerrule,shaftStart,nose-direction*(.035*scale),.045*scale)
    cueSection(cueTip,nose-direction*(.035*scale),nose,.045*scale)
    local diameter=radius*2*scale;contactRing.Size=Vector3.new(diameter,diameter,diameter);contactRing.CFrame=CFrame.new(finish);contactRing.Transparency=.70
    local legal=true
    if hit and snapshot.mode=="pool8"and not snapshot.challenge then
        if hit.id==8 then legal=me and me.targetEight
        elseif me and me.group then legal=(hit.id>=1 and hit.id<=7 and me.group=="solids")or(hit.id>=9 and me.group=="stripes")end
    end
    contactRing.Color=legal and palette.ivory or Color3.fromRGB(217,103,91)
    aimLine.Color=legal and Color3.fromRGB(222,217,187)or Color3.fromRGB(217,103,91)
    if not own then
        contactRing.Transparency=1;afterLine.Transparency=1
        line(aimLine,start+direction*(radius*scale),start+direction*(math.min(length,2.1)*scale),.023*scale);aimLine.Color=palette.brass;aimLine.Transparency=.65;return
    end
    if snapshot.mode=="pool9"and hit then legal=pushOut or hit.id==snapshot.lowest;contactRing.Color=legal and palette.ivory or Color3.fromRGB(217,103,91)end
    if hit then
        local object=Vector3.new(c.X+hit.x*scale,y,c.Z+hit.z*scale)
        local normal=(object-finish).Unit
        line(afterLine,object,object+normal*(1.25*scale),.026*scale)
    else afterLine.Transparency=1 end
end
local function aimAt(position)
    if not canAim()or draggingPower or selectingCue or spinPointer or pointIn(spinFrame,position)or pointIn(spinToggle,position)or pointIn(topHud,position)or pointIn(powerBar,position)then return end
    if panel and position.Y>=panel.AbsolutePosition.Y then return end
    if instructions and instructions.Visible then
        local p,s=instructions.AbsolutePosition,instructions.AbsoluteSize
        if position.X>=p.X and position.X<=p.X+s.X and position.Y>=p.Y and position.Y<=p.Y+s.Y then return end
    end
    local camera=workspace.CurrentCamera;if not camera then return end
    -- InputObject.Position already uses core UI inset coordinates, as does the HUD.
    -- ScreenPointToRay accepts this space; subtracting the inset again misaligns aim.
    local ray=camera:ScreenPointToRay(position.X,position.Y)
    if math.abs(ray.Direction.Y)<.001 then return end
    local t=(snapshot.height-ray.Origin.Y)/ray.Direction.Y
    if t<0 then return end
    local point=ray.Origin+ray.Direction*t;local c=snapshot.center
    local scale=snapshot.scale or 1
    if math.abs(point.X-c.X)>(snapshot.halfX+1.3)*scale or math.abs(point.Z-c.Z)>(snapshot.halfZ+1.15)*scale then return end
    local b=cueBall();if not b or b.pocketed then return end;local dx,dz=(point.X-c.X)/scale-b.x,(point.Z-c.Z)/scale-b.z
    if dx*dx+dz*dz>.36 then aimTarget=math.deg(math.atan2(dz,dx));aimChosen=true end
    -- A drag may start on the cue. Suppress its unstable angle, not the gesture.
    return true
end
local function clickTable(position)
    if not opened or not snapshot or not member()or snapshot.turn~=player.UserId or modeSheet.Visible or draggingPower or spinPointer or pointIn(spinFrame,position)or pointIn(spinToggle,position)or pointIn(topHud,position)or pointIn(powerBar,position)then return false end
    if position.Y>=panel.AbsolutePosition.Y then return false end
    if instructions.Visible then
        local origin,size=instructions.AbsolutePosition,instructions.AbsoluteSize
        if position.X>=origin.X and position.X<=origin.X+size.X and position.Y>=origin.Y and position.Y<=origin.Y+size.Y then return false end
    end
    local camera=workspace.CurrentCamera;if not camera then return false end
    local ray=camera:ScreenPointToRay(position.X,position.Y);if math.abs(ray.Direction.Y)<.001 then return false end
    local t=(snapshot.height-ray.Origin.Y)/ray.Direction.Y;if t<0 then return false end
    local point=ray.Origin+ray.Direction*t;local c=snapshot.center;local scale=snapshot.scale or 1
    local x,z=(point.X-c.X)/scale,(point.Z-c.Z)/scale
    if snapshot.ballInHand then send("place",{x=x,z=z});return true end
    if selectingCue or snapshot.phase=="penalty"then
        local nearest,best=nil,(snapshot.radius*2)^2
        for _,b in ipairs(snapshot.balls)do if not b.pocketed then local distance=(x-b.x)^2+(z-b.z)^2;if distance<best then nearest=b;best=distance end end end
        if nearest then send(snapshot.phase=="penalty"and "penalty"or "select",{ball=nearest.id});selectingCue=false end
        return true
    end
    return false
end
Input.InputBegan:Connect(function(input,processed)
    if not opened or processed then return end
    if Input:GetFocusedTextBox()then return end
    if pointIn(spinFrame,input.Position)or pointIn(spinToggle,input.Position)or spinPointer then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        if not clickTable(input.Position)and aimAt(input.Position)then pointer=input;aimLocked=false end
    end
    if canAim()and not draggingPower then
        if input.KeyCode==Enum.KeyCode.Space then if beginPowerHold then beginPowerHold(input)end
        elseif input.KeyCode==Enum.KeyCode.Left then aimLocked=true;angle-=.25;aimTarget=angle;aimChosen=true;angleLabel()
        elseif input.KeyCode==Enum.KeyCode.Right then aimLocked=true;angle+=.25;aimTarget=angle;aimChosen=true;angleLabel()
        elseif input.KeyCode==Enum.KeyCode.Up then power=math.min(1,power+.05);angleLabel()
        elseif input.KeyCode==Enum.KeyCode.Down then power=math.max(.08,power-.05);angleLabel()end
    end
    if input.KeyCode==Enum.KeyCode.Escape then if draggingPower then cancelPull();angleLabel()else send("leave");close()end end
end)
Input.InputChanged:Connect(function(input,processed)
    if processed or draggingPower or Input:GetFocusedTextBox()then return end
    if pointer and((input==pointer)or input.UserInputType==Enum.UserInputType.MouseMovement)then aimAt(input.Position)end
end)
Input.InputEnded:Connect(function(input)
    local keyboardRelease=powerPointer and powerPointer.KeyCode==Enum.KeyCode.Space and input.KeyCode==Enum.KeyCode.Space
    local mouseRelease=powerPointer and powerPointer.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1
    if draggingPower and(input==powerPointer or mouseRelease or keyboardRelease)then
        local valid=canAim(true)and power>=.08 and not Input:GetFocusedTextBox()
        pointer=nil;powerPointer=nil;draggingPower=false;aimLocked=true
        if valid then pullOriginal=nil;send("shot");instructions.Visible=false else cancelPull()end
        angleLabel();return
    end
    if input==pointer or(pointer and pointer.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)then pointer=nil;aimLocked=true end
end)
Input.WindowFocusReleased:Connect(function()cancelPull();spinPointer=nil;angleLabel()end)
Input.TextBoxFocused:Connect(function()cancelPull();spinPointer=nil;angleLabel()end)
stateRemote.OnClientEvent:Connect(function(data)
    if type(data)~="table" or type(data.sequence)~="number" or data.sequence<=sequence then return end
    local old=snapshot
    sequence=data.sequence;snapshot=data
    if not old or data.rackId~=old.rackId or data.turnToken~=old.turnToken then observedAim=nil end
    if data.aim then observedAim=table.clone(data.aim)end
    local preservePrediction=false
    local relevantError=data.ok==false and(not ownMotion or data.ackShotRequestId==nil or data.ackShotRequestId==ownMotion.requestId)
    if ownMotion then
        local own=ownMotion
        if data.rackId~=own.rackId or relevantError then clearPrediction(true)
        elseif data.shots==own.shots and data.phase=="moving"then startPrediction(data,nil,true);preservePrediction=true;shotPending=false
        elseif data.shots<own.shots and data.phase=="aiming"then preservePrediction=true
        else clearPrediction(false)end
    end
    if data.phase~="aiming"or data.turn~=player.UserId or data.rackId~=(old and old.rackId)or data.turnToken~=(old and old.turnToken)then cancelPull();shotPending=false;shotRecoveryUntil=0;pushOut=false;transportNotice=nil;transportNoticeUntil=0 end
    if relevantError then shotPending=false;if errors[data.code]then transportNotice=errors[data.code];transportNoticeUntil=os.clock()+3 end end
    if foulToast and data.foul and(old==nil or old.foul~=data.foul or old.shots~=data.shots)then
        foulToast.Text="Фол: "..foulText(data.mode,data.foul);foulUntil=os.clock()+5
    end
    if data.rackId~=(old and old.rackId)or data.turnToken~=(old and old.turnToken)then safety=false;selectingCue=false;spin={x=0,y=0};pointer=nil;aimChosen=false;aimTarget=angle;spinExpanded=false end
    if data.open or (data.phase=="aiming"and (not old or old.phase~="aiming"or old.turn~=data.turn or old.shots~=data.shots or old.cueId~=data.cueId))then aimLocked=true;pointer=nil;aimChosen=false;aimTarget=angle;angleLabel()end
    if data.code=="too_far" or data.code=="unavailable" or data.code=="left" then close();return end
    receiveAudio(data,data.open==true or not opened)
    if data.open then opened=true;if promptLease==nil and PromptService.Enabled~=false then promptLease=PromptService.Enabled;PromptService.Enabled=false end;prepareAudio();buildGui();gui.Enabled=true;beginVisuals();hideContext();enterCamera();if clearPoolPrompt then clearPoolPrompt()end
        if not member()and #snapshot.players<2 then showModePicker()end
    end
    if data.ok and(data.code=="joined"or data.code=="reset"or data.code=="join_pending")and modeSheet then modeSheet.Visible=false end
    if not opened then return end
    beginVisuals()
    enterCamera()
    ballTargets=targetsFrom(data);queueMotion(data,old)
    if data.phase~="moving"and not preservePrediction then
        for id,target in pairs(ballTargets)do
            local part=ballClones[id]
            if part then part.CFrame=target.cf;setBallHidden(id,target.hidden)end
        end
    end
    updateHud();nextHudUpdate=os.clock()+.10

end)
local function fitCamera()
    local camera=workspace.CurrentCamera
    if camera and cameraRestore then
        local drawable=gui.AbsoluteSize
        local key=tostring(camera)..":"..tostring(drawable.X)..":"..tostring(drawable.Y)..":"..tostring(camera.ViewportSize.X)..":"..tostring(camera.ViewportSize.Y)..":"..tostring(snapshot.height)..":"..tostring(topHud.Visible)..":"..tostring(topHud.Size.Y.Offset)..":"..tostring(panel.Size.Y.Offset)..":"..tostring(spinFrame.Visible)..":"..tostring(compactSpin)..":"..tostring(powerBar.Visible)..":"..tostring(nineGuide.Visible)..":"..tostring(pushOutButton.Visible)
        if key==cameraLayoutKey then return end;cameraLayoutKey=key
        local c=snapshot.center;local width,height=camera.ViewportSize.X,math.max(1,camera.ViewportSize.Y)
        local aspect=math.max(.3,width/height);local portrait=aspect<.85
        local inset,bottomInset=GuiService:GetGuiInset()
        local top=math.max(18,inset.Y+12)+(topHud and topHud.Visible and topHud.Size.Y.Offset or 0)+(pushOutButton and pushOutButton.Visible and 32 or 0)
        top+=nineGuide and nineGuide.Visible and nineGuide.Size.Y.Offset+18 or 0
        local bottom=math.max(top+100,height-panel.Size.Y.Offset-24-bottomInset.Y)
        local scale=snapshot.scale or 1
        local halfWidth,halfLength=(portrait and 3.9 or 7.8)*scale,(portrait and 7.8 or 4.1)*scale
        local rightGutter=spinFrame and spinFrame.Visible and not compactSpin and spinFrame.Size.X.Offset+24 or 0
        local leftGutter=powerBar and powerBar.Visible and powerBar.Size.X.Offset+powerBar.Position.X.Offset+16 or 0
        local gutter=rightGutter+leftGutter
        local verticalHalf=math.max(halfWidth/(math.max(.3,(width-gutter)/height)),halfLength*height/math.max(100,bottom-top))
        local up=portrait and Vector3.new(1,0,0)or Vector3.new(0,0,-1)
        local shift=verticalHalf*(1-(top+bottom)/height)
        local right=portrait and Vector3.new(0,0,1)or Vector3.new(1,0,0)
        local target=Vector3.new(c.X,snapshot.height,c.Z)-up*shift+right*(verticalHalf*aspect*(rightGutter-leftGutter)/width)
        -- Fit the complete bed above controls on short screens. Only this viewer
        -- hides ceiling pieces while playing; their properties are restored on leave.
        -- Portrait uses the long axis vertically so balls remain large enough to aim.
        local distance=math.max(10.8,verticalHalf/math.tan(math.rad(55)))
        local from=Vector3.new(target.X,target.Y+distance,target.Z+.01)
        camera.CameraType=Enum.CameraType.Scriptable
        camera.FieldOfView=math.clamp(math.deg(2*math.atan(verticalHalf/distance)),38,110)
        camera.CFrame=CFrame.lookAt(from,target,up)
    end
end
RunService.RenderStepped:Connect(function(dt)
    if not opened or not snapshot then return end
    if shotPending and os.clock()-shotPendingAt>=3 then
        -- Resync once, never replay the stroke: its original revision may already be accepted.
        shotPending=false;shotRecoveryUntil=os.clock()+4;clearPrediction(true);send("sync")
    end
    if visualDirty or not localModel or not sourceBalls or not sourceBalls.Parent then
        if sourceBalls and not sourceBalls.Parent or os.clock()>=nextVisualRetry then
            nextVisualRetry=os.clock()+.25;beginVisuals()
        end
    end
    if draggingPower then
        if Input:GetFocusedTextBox()or not canAim(true)then cancelPull()
        else power=math.clamp(.08+(os.clock()-chargeStarted)/1.2,.08,1);angleLabel()end
    end
    for _,voices in pairs(audioVoices)do for _,voice in ipairs(voices)do if voice.untilTime>0 and os.clock()>=voice.untilTime then voice.untilTime=0;pcall(function()voice.sound:Stop()end)end end end
    local camera=workspace.CurrentCamera
    fitCamera()
    if not renderPrediction(dt)then renderBalls(workspace:GetServerTimeNow())end
    -- Apply the same restrained angle to the cue, prediction and server strike.
    -- Free pointer motion never updates aimTarget. Avoid flips near the cue ball.
    if canAim()and aimChosen then
        local previousAngle=angle
        local delta=(aimTarget-angle+180)%360-180
        local maxStep=160*math.min(dt,.05)
        angle+=math.clamp(delta*(1-math.exp(-14*math.min(dt,.05))),-maxStep,maxStep)
        if math.abs((aimTarget-angle+180)%360-180)<.01 then angle=aimTarget end
        if angle~=previousAngle then angleLabel()end
    end
    if canAim(true)and aimChosen and os.clock()-lastAimSent>=.105 then
        lastAimSent=os.clock();action:FireServer({action="aim",rackId=snapshot.rackId,turnToken=snapshot.turnToken,angle=angle,power=math.max(.08,power),spin={x=spin.x,y=spin.y}})
    end
    drawAim()
    local settled=math.abs((aimTarget-angle+180)%360-180)<=.2
    local inputKey=tostring(pointer)..":"..tostring(draggingPower)..":"..tostring(aimChosen)..":"..tostring(settled)..":"..tostring(selectingCue)..":"..tostring(pushOut)..":"..tostring(shotPending)..":"..tostring(spin.x)..":"..tostring(spin.y)..":"..tostring(modeSheet.Visible)..":"..tostring(instructions.Visible)..":"..tostring(fineAimExpanded)..":"..tostring(compactSpin)..":"..tostring(spinExpanded)..":"..tostring(camera and camera.ViewportSize.X)..":"..tostring(camera and camera.ViewportSize.Y)
    if inputKey~=lastHudInput or os.clock()>=nextHudUpdate then
        lastHudInput=inputKey;nextHudUpdate=os.clock()+.10;updateHud()
    end
end)
player.CharacterRemoving:Connect(close)
player:GetAttributeChangedSignal("SpyTeleporting"):Connect(function()if player:GetAttribute("SpyTeleporting")then close()end end)
player:GetAttributeChangedSignal("SpyReconnectBusy"):Connect(function()if player:GetAttribute("SpyReconnectBusy")then close()end end)

clearPoolPrompt=function()
    if promptGui then promptGui:Destroy();promptGui=nil end
end
PromptService.PromptShown:Connect(function(prompt,inputType)
    if prompt.Name~="BilliardsEnter"or opened then return end
    clearPoolPrompt()
    promptGui=Instance.new("BillboardGui");promptGui.Name="BilliardsInvitation";promptGui.Adornee=prompt.Parent;promptGui.AlwaysOnTop=true
    promptGui.Size=UDim2.fromOffset(244,58);promptGui.StudsOffset=Vector3.new(0,1.25,0);promptGui.MaxDistance=12;promptGui.Active=true;promptGui.ResetOnSpawn=false;promptGui.Parent=player:FindFirstChild("PlayerGui")
    local card=button(promptGui,"Enter","");card.Size=UDim2.fromScale(1,1);card.BackgroundColor3=palette.panel;card.BackgroundTransparency=.08
    local edge=Instance.new("UIStroke");edge.Color=palette.brass;edge.Transparency=.55;edge.Parent=card
    local badge=label(card,"Key",inputType==Enum.ProximityPromptInputType.Gamepad and "X"or "E",26);badge.Font=Enum.Font.BuilderSansMedium
    badge.Position=UDim2.fromOffset(8,7);badge.Size=UDim2.fromOffset(42,44);badge.TextXAlignment=Enum.TextXAlignment.Center
    badge.BackgroundTransparency=0;badge.BackgroundColor3=Color3.fromRGB(34,39,38);rounded(badge,6)
    local keyEdge=Instance.new("UIStroke");keyEdge.Color=palette.ivory;keyEdge.Transparency=.82;keyEdge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;keyEdge.Parent=badge
    local heading=label(card,"Title","Бильярд",16);heading.Font=Enum.Font.BuilderSansBold;heading.Position=UDim2.fromOffset(61,8);heading.Size=UDim2.fromOffset(170,23)
    local hint=label(card,"Hint",inputType==Enum.ProximityPromptInputType.Touch and "Коснись, чтобы играть"or "Выбрать игру и правила",13);hint.TextColor3=palette.muted;hint.Position=UDim2.fromOffset(61,31);hint.Size=UDim2.fromOffset(174,20)
    card.Activated:Connect(function()if prompt.Parent and prompt.Enabled then prompt:InputHoldBegin();prompt:InputHoldEnd()end end)
end)
PromptService.PromptHidden:Connect(function(prompt)if prompt.Name=="BilliardsEnter"then clearPoolPrompt()end end)
