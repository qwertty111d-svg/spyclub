-- ReplicatedStorage > SpyShared > OnboardingUI
-- ПОЛНАЯ ЗАМЕНА
--
-- Новый onboarding:
-- • никаких обязательных квестов;
-- • никаких подсветок Винсента;
-- • никаких "сядь за стол";
-- • только аккуратная книга "РУКОВОДСТВО";
-- • нажал -> открывается GuideUI;
-- • после первой сыгранной партии она сама больше не появляется.

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local GuideUI = require(script.Parent.GuideUI)

local OnboardingUI = {}

---------------------------------------------------------------------
-- STYLE
---------------------------------------------------------------------

local C = {
	Cover = Color3.fromRGB(50, 38, 42),
	CoverHover = Color3.fromRGB(61, 47, 51),
	CoverPressed = Color3.fromRGB(42, 32, 36),

	Page = Color3.fromRGB(221, 207, 188),

	Brass = Color3.fromRGB(194, 158, 101),
	Border = Color3.fromRGB(111, 86, 76),

	Text = Color3.fromRGB(239, 231, 221),
}

local FONT = {
	Strong = Enum.Font.BuilderSans,
}

local T = {
	Hover = TweenInfo.new(
		0.17,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Press = TweenInfo.new(
		0.09,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	),

	Show = TweenInfo.new(
		0.24,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Hide = TweenInfo.new(
		0.16,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	),
}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function make(className, parent, props)
	local object = Instance.new(className)

	for key, value in pairs(props or {}) do
		object[key] = value
	end

	object.Parent = parent

	return object
end

local function tween(object, info, props)
	if not object or not object.Parent then
		return
	end

	local animation =
		TweenService:Create(
			object,
			info,
			props
		)

	animation:Play()

	return animation
end

local function corner(parent, radius)
	return make(
		"UICorner",
		parent,
		{
			CornerRadius =
				UDim.new(
					0,
					radius
				),
		}
	)
end

local function stroke(
	parent,
	color,
	transparency
)
	return make(
		"UIStroke",
		parent,
		{
			ApplyStrokeMode =
				Enum.ApplyStrokeMode.Border,

			Color = color,

			Transparency =
				transparency,

			Thickness = 1,
		}
	)
end

local function english(ctx)
	return ctx.language
		and ctx.language() == "en"
end


---------------------------------------------------------------------
-- V49 FIRST-RUN CINEMATIC TOUR
-- World-aware, prompt-driven, line-of-sight-safe. No guessed table models.
---------------------------------------------------------------------
local TOUR_WORLD_READY_TIMEOUT=8
local TOUR_STAGES={
    {id="overview",mode="world",anchorKind="overview",titleRu="SPY CLUB",titleEn="SPY CLUB",ru="Осмотрись. Это твой клуб.",en="Take a look around. This is your club.",distance=24,height=9.5,fov=66,dwell=5.2,move=2.7},
    {id="cases_wide",mode="world",promptNames={InspectCase=true,CasePrompt=true},titleRu="ОБРАЗ",titleEn="APPEARANCE",ru="Здесь можно прокрутить аксессуар за Roll.",en="Roll for an accessory here.",distance=15,height=6.4,fov=61,dwell=4.8,move=2.5},
    {id="cases_close",mode="world",promptNames={InspectCase=true,CasePrompt=true},titleRu="КОЛЛЕКЦИЯ",titleEn="COLLECTION",ru="Выбирай категории. Все полученные вещи остаются в инвентаре.",en="Choose a category. Every item stays in your inventory.",distance=9.5,height=4.8,fov=55,dwell=4.6,move=2.3},
    {id="bar",mode="world",promptNames={TalkVincent=true},titleRu="БАР",titleEn="BAR",ru="За стойкой — Винсент.",en="Vincent is behind the bar.",distance=15.5,height=6.2,fov=61,dwell=4.8,move=2.6},
    {id="vincent",mode="world",promptNames={TalkVincent=true},titleRu="ВИНСЕНТ",titleEn="VINCENT",ru="У него можно продать ненужные вещи.",en="You can sell unwanted items to him.",distance=8.5,height=4.3,fov=54,dwell=4.7,move=2.35},
    {id="feedback",mode="world",promptNames={FeedbackBook=true},titleRu="КНИГА СВЯЗИ",titleEn="CONTACT BOOK",ru="Баги и идеи — сюда.",en="Bugs and ideas go here.",distance=9,height=4.5,fov=56,dwell=4.3,move=2.3},
    {id="daily_wide",mode="world",promptNames={DailyReward=true},titleRu="ЕЖЕДНЕВНАЯ НАГРАДА",titleEn="DAILY REWARD",ru="На этом столе — ежедневная награда.",en="Your daily reward is on this table.",distance=12.5,height=5.6,fov=59,dwell=5.0,move=2.55},
    {id="daily_close",mode="world",promptNames={DailyReward=true},titleRu="ЗАБИРАЙ КАЖДЫЙ ДЕНЬ",titleEn="COME BACK DAILY",ru="Подойди к столу и забери её.",en="Walk up to the table and claim it.",distance=7.4,height=3.9,fov=53,dwell=4.8,move=2.3},
    {id="create_table",mode="ui",uiTarget="create",titleRu="СОЗДАТЬ СТОЛ",titleEn="CREATE TABLE",ru="Отсюда собирается группа перед матчем.",en="Build your group here before a match.",dwell=5.0},
    {id="ready",mode="world",anchorKind="overview",titleRu="ГОТОВО",titleEn="READY",ru="Можно начинать.",en="You're ready.",distance=22,height=8.7,fov=63,dwell=4.6,move=2.5},
}

local function promptWorldPosition(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return nil end
    local parent=prompt.Parent
    if parent and parent:IsA("Attachment") then return parent.WorldPosition end
    if parent and parent:IsA("BasePart") then return parent.Position end
    if parent and parent.Parent and parent.Parent:IsA("BasePart") then return parent.Parent.Position end
    return nil
end

local function matchingPromptPositions(promptNames)
    local positions={}
    for _,node in ipairs(workspace:GetDescendants()) do
        if node:IsA("ProximityPrompt") and promptNames[node.Name] then
            local position=promptWorldPosition(node)
            if position then table.insert(positions,position) end
        end
    end
    return positions
end

local function averagePositions(positions)
    if #positions==0 then return nil end
    local sum=Vector3.new()
    for _,position in ipairs(positions) do sum+=position end
    return sum/#positions
end

local function resolveConcreteStageAnchor(stage)
    if stage.mode~="world" or stage.anchorKind=="overview" then return nil end
    return averagePositions(matchingPromptPositions(stage.promptNames or {}))
end

local function resolveOverviewAnchor()
    local positions={}
    for _,stage in ipairs(TOUR_STAGES) do
        if stage.mode=="world" and stage.anchorKind~="overview" then
            local position=resolveConcreteStageAnchor(stage)
            if position then table.insert(positions,position) end
        end
    end
    if #positions<2 then return nil end
    return averagePositions(positions)
end

local function buildRuntimeStages()
    local runtimeStages={}
    local worldCount=0
    for _,stage in ipairs(TOUR_STAGES) do
        if stage.mode=="ui" then
            table.insert(runtimeStages,stage)
        else
            local anchor=stage.anchorKind=="overview" and resolveOverviewAnchor() or resolveConcreteStageAnchor(stage)
            if not anchor then
                continue
            end
            local runtime=table.clone(stage)
            runtime.anchor=anchor
            table.insert(runtimeStages,runtime)
            worldCount+=1
        end
    end
    return runtimeStages,worldCount
end

local function cameraCandidates(focus,distance,height,camera)
    local projected=camera and Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z) or Vector3.new(0,0,-1)
    if projected.Magnitude<0.05 then projected=Vector3.new(0,0,-1) else projected=projected.Unit end
    local right=Vector3.new(-projected.Z,0,projected.X)
    local dirs={
        -projected,
        (-projected+right*.55).Unit,
        (-projected-right*.55).Unit,
        right,
        -right,
        projected,
        (projected+right*.55).Unit,
        (projected-right*.55).Unit,
    }
    local result={}
    for _,dir in ipairs(dirs) do
        table.insert(result,focus+dir*distance+Vector3.new(0,height,0))
    end
    return result
end

local function safeCameraCFrame(focus,distance,height,camera,character)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=character and {character} or {}
    params.IgnoreWater=true
    local eye=focus+Vector3.new(0,1.4,0)
    local bestPosition=nil
    local bestDistance=-1
    for _,desired in ipairs(cameraCandidates(focus,distance,height,camera)) do
        local delta=desired-eye
        local hit=workspace:Raycast(eye,delta,params)
        local candidate=desired
        if hit then
            local unit=delta.Magnitude>0 and delta.Unit or Vector3.new(0,0,1)
            candidate=hit.Position-unit*1.35
        end
        local clearDistance=(candidate-eye).Magnitude
        if clearDistance>=5.5 and clearDistance>bestDistance then
            -- A second line-of-sight check catches thin geometry / numerical edge cases.
            local verify=workspace:Raycast(candidate,eye-candidate,params)
            if not verify or (verify.Position-eye).Magnitude<1.8 then
                bestPosition=candidate
                bestDistance=clearDistance
            end
        end
    end
    if not bestPosition then return nil end
    return CFrame.lookAt(bestPosition,eye)
end

local function waitForWorldAnchors(tokenValid)
    local deadline=os.clock()+TOUR_WORLD_READY_TIMEOUT
    local lastStages,lastWorldCount={},0
    repeat
        if not tokenValid() then return nil end
        lastStages,lastWorldCount=buildRuntimeStages()
        local hasCases,hasVincent,hasDaily=false,false,false
        for _,stage in ipairs(lastStages) do
            if stage.id=="cases_wide" or stage.id=="cases_close" then hasCases=true end
            if stage.id=="bar" or stage.id=="vincent" then hasVincent=true end
            if stage.id=="daily_wide" or stage.id=="daily_close" then hasDaily=true end
        end
        if lastWorldCount>=3 and hasCases and hasVincent and hasDaily then return lastStages end
        task.wait(.12)
    until os.clock()>=deadline
    if lastWorldCount>=1 then return lastStages end
    return nil
end

local function createTourController(ctx,overlay)
    local player=Players.LocalPlayer
    local playerGui=player:WaitForChild("PlayerGui")
    local tourRoot=overlay.root
    local self={active=false,preparing=false,attempted=false,destroyed=false,finishing=false,token=0,retryAfter=0}
    local saved=nil
    local activeTween=nil
    local fadeTween=nil
    local hudSnapshot=nil
    local uiTargetSnapshots={}
    local currentUiTarget=nil

    local function destroyTargetClone(entry)
        if entry and entry.clone and entry.clone.Parent then entry.clone:Destroy() end
    end

    local function clearUiTargets()
        for _,entry in pairs(uiTargetSnapshots) do destroyTargetClone(entry) end
        uiTargetSnapshots={}
        currentUiTarget=nil
        if overlay.targetGlow then overlay.targetGlow.Visible=false end
        if overlay.targetDim then overlay.targetDim.Visible=false end
        if overlay.targetCallout then overlay.targetCallout.Visible=false end
    end

    local function cloneTourTarget(guiObject,key)
        if not guiObject or not guiObject:IsA("GuiObject") then return nil end
        local absolutePosition=guiObject.AbsolutePosition
        local absoluteSize=guiObject.AbsoluteSize
        if absoluteSize.X<8 or absoluteSize.Y<8 then return nil end
        local clone=guiObject:Clone()
        clone.Name="TourGhost_"..tostring(key)
        clone.AnchorPoint=Vector2.new(0,0)
        clone.Position=UDim2.fromOffset(math.floor(absolutePosition.X+.5),math.floor(absolutePosition.Y+.5))
        clone.Size=UDim2.fromOffset(math.floor(absoluteSize.X+.5),math.floor(absoluteSize.Y+.5))
        clone.Visible=false
        clone.ZIndex=508
        if clone:IsA("GuiButton") then
            clone.Active=false
            clone.Selectable=false
            clone.AutoButtonColor=false
        end
        for _,descendant in ipairs(clone:GetDescendants()) do
            if descendant:IsA("LocalScript") or descendant:IsA("Script") then
                descendant:Destroy()
            elseif descendant:IsA("GuiObject") then
                descendant.ZIndex=math.max(509,descendant.ZIndex+508)
                if descendant:IsA("GuiButton") then
                    descendant.Active=false
                    descendant.Selectable=false
                    descendant.AutoButtonColor=false
                end
            end
        end
        clone.Parent=overlay.targetLayer
        return {
            clone=clone,
            position=Vector2.new(absolutePosition.X,absolutePosition.Y),
            size=Vector2.new(absoluteSize.X,absoluteSize.Y),
        }
    end

    local function captureUiTargets()
        clearUiTargets()
        local hud=playerGui:FindFirstChild("HudGui")
        if not hud then return end
        local createButton=hud:FindFirstChild("MainAction")
        uiTargetSnapshots.create=cloneTourTarget(createButton,"create")
    end

    local function hideUiTarget()
        currentUiTarget=nil
        for _,entry in pairs(uiTargetSnapshots) do
            if entry and entry.clone then entry.clone.Visible=false end
        end
        if overlay.targetGlow then overlay.targetGlow.Visible=false end
        if overlay.targetDim then overlay.targetDim.Visible=false end
        if overlay.targetCallout then overlay.targetCallout.Visible=false end
        if overlay.bottomBar then overlay.bottomBar.Visible=true end
    end

    local function showUiTarget(key,stage)
        hideUiTarget()
        local entry=uiTargetSnapshots[key]
        if not entry or not entry.clone or not entry.clone.Parent then return false end
        currentUiTarget=key
        if overlay.bottomBar then overlay.bottomBar.Visible=false end
        if overlay.targetDim then overlay.targetDim.Visible=true end
        entry.clone.Visible=true
        local pad=10
        local px=entry.position.X-pad
        local py=entry.position.Y-pad
        local sx=entry.size.X+pad*2
        local sy=entry.size.Y+pad*2
        if overlay.targetGlow then
            overlay.targetGlow.Visible=true
            overlay.targetGlow.Position=UDim2.fromOffset(px-8,py-8)
            overlay.targetGlow.Size=UDim2.fromOffset(sx+16,sy+16)
            overlay.targetGlow.BackgroundTransparency=.94
            TweenService:Create(
                overlay.targetGlow,
                TweenInfo.new(.46,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
                {Position=UDim2.fromOffset(px,py),Size=UDim2.fromOffset(sx,sy),BackgroundTransparency=.985}
            ):Play()
        end
        if overlay.targetCallout then
            local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
            local cx=math.clamp(entry.position.X+entry.size.X*.5,190,math.max(190,viewport.X-190))
            local above=entry.position.Y-18
            local calloutY=math.max(110,above)
            overlay.targetCallout.AnchorPoint=Vector2.new(.5,1)
            overlay.targetCallout.Position=UDim2.fromOffset(cx,calloutY)
            overlay.targetCallout.Visible=true
            overlay.targetCalloutTitle.Text=english(ctx) and (stage.titleEn or "") or (stage.titleRu or "")
            overlay.targetCalloutBody.Text=english(ctx) and stage.en or stage.ru
            overlay.targetCallout.GroupTransparency=1
            TweenService:Create(overlay.targetCallout,TweenInfo.new(.34,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{GroupTransparency=0}):Play()
        end
        return true
    end

    local function cancelCameraTween()
        if activeTween then activeTween:Cancel(); activeTween=nil end
    end

    local function cancelFadeTween()
        if fadeTween then fadeTween:Cancel(); fadeTween=nil end
    end

    local function waitTween(animation,duration)
        if not animation then
            if duration and duration>0 then task.wait(duration) end
            return
        end
        local done=false
        local connection=animation.Completed:Connect(function() done=true end)
        local deadline=os.clock()+(duration or 0)+.35
        while not done and os.clock()<deadline and not self.destroyed do task.wait() end
        connection:Disconnect()
    end

    local function setFade(transparency,duration)
        local fade=overlay.fade
        if not fade or not fade.Parent then return end
        cancelFadeTween()
        fade.Visible=true
        if not duration or duration<=0 then
            fade.BackgroundTransparency=transparency
            return
        end
        fadeTween=TweenService:Create(
            fade,
            TweenInfo.new(duration,Enum.EasingStyle.Quint,Enum.EasingDirection.InOut),
            {BackgroundTransparency=transparency}
        )
        fadeTween:Play()
        waitTween(fadeTween,duration)
        fadeTween=nil
    end

    local function fadeToBlack(duration)
        setFade(0,duration or .22)
    end

    local function fadeFromBlack(duration)
        setFade(1,duration or .48)
    end

    local function hideGameplayUI()
        if hudSnapshot then return end
        hudSnapshot={screens={},siblings={},connections={}}

        local function lockScreen(name)
            local screen=playerGui:FindFirstChild(name)
            if not screen or not screen:IsA("ScreenGui") then return end
            table.insert(hudSnapshot.screens,{gui=screen,enabled=screen.Enabled})
            screen.Enabled=false
            table.insert(hudSnapshot.connections,screen:GetPropertyChangedSignal("Enabled"):Connect(function()
                if self.active and screen.Parent and screen.Enabled then screen.Enabled=false end
            end))
        end

        -- Keep Roblox's own escape/menu controls available, but remove every SPY CLUB
        -- gameplay element so the establishing shots read like a real opening cinematic.
        lockScreen("HudGui")
        lockScreen("SpyAULChat")

        for _,child in ipairs(ctx.gui:GetChildren()) do
            if child ~= tourRoot and child:IsA("GuiObject") then
                table.insert(hudSnapshot.siblings,{object=child,visible=child.Visible})
                child.Visible=false
                table.insert(hudSnapshot.connections,child:GetPropertyChangedSignal("Visible"):Connect(function()
                    if self.active and child.Parent and child.Visible then child.Visible=false end
                end))
            end
        end
    end

    local function restoreGameplayUI()
        local snapshot=hudSnapshot
        if not snapshot then return end
        hudSnapshot=nil
        for _,connection in ipairs(snapshot.connections) do
            connection:Disconnect()
        end
        for _,entry in ipairs(snapshot.screens) do
            if entry.gui and entry.gui.Parent then entry.gui.Enabled=entry.enabled end
        end
        for _,entry in ipairs(snapshot.siblings) do
            if entry.object and entry.object.Parent then entry.object.Visible=entry.visible end
        end
    end
    self.restoreGameplayUI=restoreGameplayUI

    local function restoreCamera()
        cancelCameraTween()
        if not saved then return end
        local camera=workspace.CurrentCamera
        local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if camera then
            camera.CameraType=saved.type
            if saved.subject and saved.subject.Parent then camera.CameraSubject=saved.subject elseif humanoid then camera.CameraSubject=humanoid end
            camera.CFrame=saved.cframe
            camera.FieldOfView=saved.fov
        end
        player.CameraMinZoomDistance=saved.minZoom
        player.CameraMaxZoomDistance=saved.maxZoom
        if humanoid and saved.walkSpeed then
            humanoid.WalkSpeed=saved.walkSpeed
            humanoid.JumpPower=saved.jumpPower
            humanoid.AutoRotate=saved.autoRotate
        end
        saved=nil
    end
    self.restoreCamera=restoreCamera

    local function setOverlayVisible(visible)
        overlay.root.Visible=visible
        if overlay.topBar then overlay.topBar.Visible=visible end
        if overlay.bottomBar then overlay.bottomBar.Visible=visible end
        if not visible and overlay.fade then
            overlay.fade.Visible=false
            overlay.fade.BackgroundTransparency=1
        end
    end

    local function finish(save,cinematic)
        if self.finishing then return end
        self.finishing=true
        self.preparing=false
        self.attempted=true
        if cinematic and tourRoot.Visible then fadeToBlack(.24) end
        hideUiTarget()
        clearUiTargets()
        self.active=false
        if overlay.topBar then overlay.topBar.Visible=false end
        if overlay.bottomBar then overlay.bottomBar.Visible=false end
        restoreCamera()
        restoreGameplayUI()
        if cinematic and tourRoot.Visible then
            task.wait(.05)
            fadeFromBlack(.52)
        end
        setOverlayVisible(false)
        self.token+=1
        self.finishing=false
        if save then ctx.request("onboarding", "lobbyTourSeen") end
    end

    function self:skip()
        if self.active and not self.finishing then
            task.spawn(function() finish(true,true) end)
        end
    end

    function self:destroy()
        self.destroyed=true
        self.token+=1
        self.preparing=false
        self.active=false
        self.finishing=false
        cancelFadeTween()
        hideUiTarget()
        clearUiTargets()
        setOverlayVisible(false)
        restoreGameplayUI()
        restoreCamera()
    end

    local function eligible(profile,state)
        if player:GetAttribute("SpyEntryCompleted")~=true or player:GetAttribute("SpyEntryPresented")==true then return false end
        if player:GetAttribute("SpyEntryPending")==true or player:GetAttribute("SpyEntryActive")==true then return false end
        if self.destroyed or self.active or self.preparing or self.finishing or self.attempted then return false end
        if os.clock()<self.retryAfter then return false end
        if not profile or profile.ready~=true or profile.lobbyTourSeen==true then return false end
        if state and state.tableId then return false end
        local rs=tostring(player:GetAttribute("SpyReturnRestoreState") or "none")
        if rs=="checking" or rs=="restoring" then return false end
        if player:GetAttribute("SpyReturnedFromMatch")==true or player:GetAttribute("SpyTeleporting")==true then return false end
        local character=player.Character
        local camera=workspace.CurrentCamera
        return camera~=nil and character~=nil and character:FindFirstChildOfClass("Humanoid")~=nil
    end

    local function showStage(index,total,stage)
        if stage.mode=="ui" then
            showUiTarget(stage.uiTarget,stage)
        else
            hideUiTarget()
            overlay.title.Text=english(ctx) and (stage.titleEn or "") or (stage.titleRu or "")
            overlay.body.Text=english(ctx) and stage.en or stage.ru
            overlay.title.TextTransparency=1
            overlay.body.TextTransparency=1
            TweenService:Create(overlay.title,TweenInfo.new(.32,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency=.03}):Play()
            TweenService:Create(overlay.body,TweenInfo.new(.46,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
        end
        if overlay.progress then
            overlay.progress.Size=UDim2.new(math.clamp((index-1)/math.max(total,1),0,1),0,1,0)
            TweenService:Create(
                overlay.progress,
                TweenInfo.new(.62,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
                {Size=UDim2.new(math.clamp(index/math.max(total,1),0,1),0,1,0)}
            ):Play()
        end
    end

    local function applyCameraStage(camera,stage,reduced)
        local target=stage.cameraTarget
        if not target then return end
        cancelCameraTween()
        camera.CFrame=target
        camera.FieldOfView=(stage.fov or 60)+2
        if reduced then
            camera.FieldOfView=stage.fov or 60
            return
        end
        local focus=stage.anchor+Vector3.new(0,1.4,0)
        local direction=(camera.CFrame.Position-focus)
        local dolly=direction.Magnitude>0 and direction.Unit*1.15 or Vector3.new(0,0,1.15)
        local settled=CFrame.lookAt(camera.CFrame.Position-dolly,focus)
        activeTween=TweenService:Create(
            camera,
            TweenInfo.new(stage.move or 2.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
            {CFrame=settled,FieldOfView=stage.fov or 60}
        )
        activeTween:Play()
    end

    local function begin(profile,state)
        if not eligible(profile,state) then return end
        self.preparing=true
        self.token+=1
        local token=self.token
        task.spawn(function()
            local runtimeStages=waitForWorldAnchors(function()
                return token==self.token and self.preparing and not self.destroyed
            end)
            if token~=self.token or self.destroyed then return end
            if not runtimeStages or #runtimeStages==0 then
                self.preparing=false
                self.retryAfter=os.clock()+3
                return
            end

            local camera=workspace.CurrentCamera
            local character=player.Character
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            if not camera or not character or not humanoid then
                self.preparing=false
                self.retryAfter=os.clock()+2
                return
            end

            -- Capture the real CREATE TABLE control before hiding the gameplay interface.
            -- Daily rewards are a world shot anchored to the DailyReward prompt.
            captureUiTargets()

            -- Preflight every shot before we take control of the player's screen.
            -- Nothing is hidden until we know the cinematic has at least one valid shot.
            local displayStages={}
            for _,stage in ipairs(runtimeStages) do
                if stage.mode=="ui" then
                    if stage.uiTarget and uiTargetSnapshots[stage.uiTarget] then table.insert(displayStages,stage) end
                elseif stage.anchor then
                    local target=safeCameraCFrame(stage.anchor,stage.distance or 11,stage.height or 5,camera,character)
                    if target then
                        local prepared=table.clone(stage)
                        prepared.cameraTarget=target
                        table.insert(displayStages,prepared)
                    end
                end
            end
            if #displayStages==0 then
                self.preparing=false
                self.retryAfter=os.clock()+3
                return
            end

            saved={type=camera.CameraType,subject=camera.CameraSubject,cframe=camera.CFrame,fov=camera.FieldOfView,
                minZoom=player.CameraMinZoomDistance,maxZoom=player.CameraMaxZoomDistance,
                walkSpeed=humanoid.WalkSpeed,jumpPower=humanoid.JumpPower,autoRotate=humanoid.AutoRotate}

            self.preparing=false
            self.active=true
            hideGameplayUI()
            setOverlayVisible(true)
            setFade(0,0) -- true fade-from-black: no HUD flash before the establishing shot

            humanoid.WalkSpeed=0
            humanoid.JumpPower=0
            humanoid.AutoRotate=false
            camera.CameraType=Enum.CameraType.Scriptable

            local reduced=player:GetAttribute("SpyReducedMotion")==true or player:GetAttribute("SpyCameraMotion")==false

            for index,stage in ipairs(displayStages) do
                if token~=self.token or not self.active then return end

                if index>1 then
                    fadeToBlack(reduced and .07 or .14)
                    if token~=self.token or not self.active then return end
                end

                applyCameraStage(camera,stage,reduced)
                showStage(index,#displayStages,stage)

                if index==1 then
                    task.wait(.10)
                    fadeFromBlack(reduced and .12 or .88)
                else
                    task.wait(.04)
                    fadeFromBlack(reduced and .09 or .38)
                end

                local dwell=reduced and math.min(stage.dwell or 3.2,2.1) or (stage.dwell or 4.0)
                local deadline=os.clock()+dwell
                while os.clock()<deadline do
                    if token~=self.token or not self.active then return end
                    task.wait(.05)
                end
            end

            if token==self.token and self.active then finish(true,true) end
        end)
    end

    function self:update(profile,state) begin(profile,state) end
    player.CharacterRemoving:Connect(function()
        if self.active or self.preparing or self.finishing then self:destroy() end
    end)
    return self
end
---------------------------------------------------------------------
-- CREATE
---------------------------------------------------------------------

function OnboardingUI.create(ctx)
	local self = {
		dismissed = false,
		talked = false,
		stage = nil,
	}
	local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	local oldTourScreen=playerGui:FindFirstChild("SpyClubCinematicTour")
	if oldTourScreen then oldTourScreen:Destroy() end
	local tourScreen=make("ScreenGui",playerGui,{Name="SpyClubCinematicTour",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=500,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Enabled=true})
	local tourRoot=make("Frame",tourScreen,{Name="LobbyTourOverlay",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=500})

	-- World shots use only a soft lower gradient; HUD-target shots get a precise spotlight.
	local captionShade=make("Frame",tourRoot,{Name="TourCaptionShade",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,210),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0,BorderSizePixel=0,ZIndex=501})
	make("UIGradient",captionShade,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.36,.72),NumberSequenceKeypoint.new(1,.12)})})
	local accentLine=make("Frame",captionShade,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,92),Size=UDim2.fromOffset(82,1),BackgroundColor3=C.Brass,BackgroundTransparency=.24,BorderSizePixel=0,ZIndex=502})
	local tourTitle=make("TextLabel",captionShade,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,108),Size=UDim2.new(1,-220,0,22),BackgroundTransparency=1,Text="",TextColor3=C.Brass,Font=Enum.Font.BuilderSansMedium,TextSize=13,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=502})
	local tourBody=make("TextLabel",captionShade,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,136),Size=UDim2.new(1,-340,0,34),BackgroundTransparency=1,Text="",TextColor3=C.Text,Font=Enum.Font.BuilderSans,TextSize=17,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=502})

	local targetDim=make("Frame",tourRoot,{Name="TourTargetDim",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=.60,BorderSizePixel=0,Visible=false,ZIndex=504})
	local targetLayer=make("Frame",tourRoot,{Name="TourTargetLayer",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=506})
	local targetGlow=make("Frame",targetLayer,{Name="TourTargetGlow",BackgroundColor3=C.Brass,BackgroundTransparency=.985,BorderSizePixel=0,Visible=false,ZIndex=507}); corner(targetGlow,12); local targetStroke=stroke(targetGlow,C.Brass,.06); targetStroke.Thickness=2
	local targetCallout=make("CanvasGroup",targetLayer,{Name="TourTargetCallout",Size=UDim2.fromOffset(350,78),BackgroundColor3=Color3.fromRGB(11,10,12),BackgroundTransparency=.12,BorderSizePixel=0,Visible=false,GroupTransparency=0,ZIndex=510}); corner(targetCallout,10); stroke(targetCallout,C.Border,.48)
	local targetCalloutTitle=make("TextLabel",targetCallout,{Position=UDim2.fromOffset(16,10),Size=UDim2.new(1,-32,0,20),BackgroundTransparency=1,Text="",TextColor3=C.Brass,Font=Enum.Font.BuilderSansMedium,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=511})
	local targetCalloutBody=make("TextLabel",targetCallout,{Position=UDim2.fromOffset(16,33),Size=UDim2.new(1,-32,0,30),BackgroundTransparency=1,Text="",TextColor3=C.Text,Font=Enum.Font.BuilderSans,TextSize=15,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=511})

	local progressTrack=make("Frame",tourRoot,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-14),Size=UDim2.fromOffset(230,2),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=.86,BorderSizePixel=0,ZIndex=512})
	local tourProgress=make("Frame",progressTrack,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.Brass,BackgroundTransparency=.16,BorderSizePixel=0,ZIndex=513})
	local tourSkip=make("TextButton",tourRoot,{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-24,1,-22),Size=UDim2.fromOffset(108,30),BackgroundColor3=Color3.fromRGB(12,11,13),BackgroundTransparency=.34,BorderSizePixel=0,Text="Пропустить",TextColor3=Color3.fromRGB(211,202,194),Font=Enum.Font.BuilderSans,TextSize=12,ZIndex=514}); corner(tourSkip,7); stroke(tourSkip,C.Border,.68)
	local fadeFrame=make("Frame",tourRoot,{Name="TourFade",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,Visible=false,Active=false,ZIndex=520})
	local tour=createTourController(ctx,{root=tourRoot,bottomBar=captionShade,title=tourTitle,body=tourBody,progress=tourProgress,fade=fadeFrame,targetDim=targetDim,targetLayer=targetLayer,targetGlow=targetGlow,targetCallout=targetCallout,targetCalloutTitle=targetCalloutTitle,targetCalloutBody=targetCalloutBody})
	tourSkip.Activated:Connect(function() tour:skip() end)

	local parent =
		ctx.hintRail
		or ctx.gui

	-----------------------------------------------------------------
	-- ROOT
	-----------------------------------------------------------------

	local card =
		make(
			"CanvasGroup",
			parent,
			{
				Name =
				"GuideBookPrompt",

				Size =
				UDim2.fromOffset(
					232,
					58
				),

				BackgroundColor3 =
				C.Cover,

				BackgroundTransparency =
				0,

				GroupTransparency =
				1,

				Visible =
				false,

				BorderSizePixel =
				0,

				LayoutOrder =
				1,

				ZIndex =
				30,
			}
		)

	corner(card, 7)

	local outline =
		stroke(
			card,
			C.Border,
			0.30
		)

	local objectScale =
		make(
			"UIScale",
			card,
			{
				Scale = 0.97,
			}
		)

	-----------------------------------------------------------------
	-- MINI BOOK
	-----------------------------------------------------------------

	local book =
		make(
			"Frame",
			card,
			{
				Name = "Book",

				Position =
				UDim2.fromOffset(
					10,
					7
				),

				Size =
				UDim2.fromOffset(
					40,
					44
				),

				BackgroundColor3 =
				Color3.fromRGB(
					64,
					45,
					50
				),

				BorderSizePixel =
				0,

				ZIndex =
				32,
			}
		)

	corner(book, 4)

	stroke(
		book,
		C.Brass,
		0.28
	)

	-----------------------------------------------------------------
	-- SPINE
	-----------------------------------------------------------------

	local spine =
		make(
			"Frame",
			book,
			{
				Position =
				UDim2.fromOffset(
					5,
					3
				),

				Size =
				UDim2.new(
					0,
					3,
					1,
					-6
				),

				BackgroundColor3 =
				C.Brass,

				BorderSizePixel =
				0,

				ZIndex =
				33,
			}
		)

	corner(spine, 2)

	-----------------------------------------------------------------
	-- PAGE EDGES
	-----------------------------------------------------------------

	for i = 0, 2 do
		make(
			"Frame",
			book,
			{
				Position =
					UDim2.new(
						0,
						11,
						1,
						-9 - i * 3
					),

				Size =
					UDim2.new(
						1,
						-17,
						0,
						1
					),

				BackgroundColor3 =
					C.Page,

				BackgroundTransparency =
					0.18 + i * 0.12,

				BorderSizePixel =
					0,

				ZIndex =
					33,
			}
		)
	end

	-----------------------------------------------------------------
	-- SYMBOL
	-----------------------------------------------------------------

	local symbol =
		make(
			"TextLabel",
			book,
			{
				Position =
				UDim2.fromOffset(
					11,
					5
				),

				Size =
				UDim2.new(
					1,
					-16,
					0,
					24
				),

				BackgroundTransparency =
				1,

				Text = "?",

				Font =
				FONT.Strong,

				TextSize =
				14,

				TextColor3 =
				C.Brass,

				TextXAlignment =
				Enum.TextXAlignment.Center,

				ZIndex =
				34,
			}
		)

	-----------------------------------------------------------------
	-- TITLE ONLY
	-----------------------------------------------------------------

	local title =
		make(
			"TextLabel",
			card,
			{
				Position =
				UDim2.fromOffset(
					62,
					0
				),

				Size =
				UDim2.new(
					1,
					-74,
					1,
					0
				),

				BackgroundTransparency =
				1,

				Text =
				english(ctx)
				and "GUIDE"
				or "РУКОВОДСТВО",

				Font =
				FONT.Strong,

				TextSize =
				12,

				TextColor3 =
				C.Text,

				TextXAlignment =
				Enum.TextXAlignment.Left,

				TextYAlignment =
				Enum.TextYAlignment.Center,

				ZIndex =
				33,
			}
		)

	-----------------------------------------------------------------
	-- HIT AREA
	-----------------------------------------------------------------

	local hit =
		make(
			"TextButton",
			card,
			{
				Name = "OpenGuide",

				Size =
				UDim2.fromScale(
					1,
					1
				),

				BackgroundTransparency =
				1,

				Text = "",

				AutoButtonColor =
				false,

				ZIndex =
				40,
			}
		)

	-----------------------------------------------------------------
	-- STATE
	-----------------------------------------------------------------

	local visible = false
	local token = 0

	local function show()
		title.Text =
			english(ctx)
			and "GUIDE"
			or "РУКОВОДСТВО"

		if visible then
			return
		end

		visible = true
		self.stage = "guide"

		token += 1

		card.Visible = true
		card.GroupTransparency = 1
		objectScale.Scale = 0.97

		tween(
			card,
			T.Show,
			{
				GroupTransparency = 0,
			}
		)

		tween(
			objectScale,
			T.Show,
			{
				Scale = 1,
			}
		)
	end

	local function hide()
		if not visible then
			card.Visible = false
			self.stage = nil
			return
		end

		visible = false
		self.stage = nil

		token += 1

		local currentToken =
			token

		tween(
			card,
			T.Hide,
			{
				GroupTransparency = 1,
			}
		)

		local closing =
			tween(
				objectScale,
				T.Hide,
				{
					Scale = 0.97,
				}
			)

		if closing then
			closing.Completed:Once(function()
				if currentToken == token
					and not visible
				then
					card.Visible =
						false
				end
			end)
		end
	end

	-----------------------------------------------------------------
	-- HOVER
	-----------------------------------------------------------------

	hit.MouseEnter:Connect(function()
		tween(
			card,
			T.Hover,
			{
				BackgroundColor3 =
					C.CoverHover,
			}
		)

		tween(
			outline,
			T.Hover,
			{
				Color =
					C.Brass,

				Transparency =
					0.12,
			}
		)

		tween(
			objectScale,
			T.Hover,
			{
				Scale = 1.018,
			}
		)

		tween(
			book,
			T.Hover,
			{
				Position =
					UDim2.fromOffset(
						11,
						6
					),
			}
		)
	end)

	hit.MouseLeave:Connect(function()
		tween(
			card,
			T.Hover,
			{
				BackgroundColor3 =
					C.Cover,
			}
		)

		tween(
			outline,
			T.Hover,
			{
				Color =
					C.Border,

				Transparency =
					0.30,
			}
		)

		tween(
			objectScale,
			T.Show,
			{
				Scale = 1,
			}
		)

		tween(
			book,
			T.Show,
			{
				Position =
					UDim2.fromOffset(
						10,
						7
					),
			}
		)
	end)

	-----------------------------------------------------------------
	-- PRESS
	-----------------------------------------------------------------

	hit.MouseButton1Down:Connect(function()
		tween(
			card,
			T.Press,
			{
				BackgroundColor3 =
					C.CoverPressed,
			}
		)

		tween(
			objectScale,
			T.Press,
			{
				Scale = 0.96,
			}
		)
	end)

	hit.MouseButton1Up:Connect(function()
		tween(
			objectScale,
			T.Show,
			{
				Scale = 1.018,
			}
		)
	end)

	-----------------------------------------------------------------
	-- CLICK
	-----------------------------------------------------------------

	hit.Activated:Connect(function()
		self.dismissed = true

		hide()

		task.defer(function()
			GuideUI.open(ctx)
		end)
	end)

	-----------------------------------------------------------------
	-- COMPATIBILITY
	-----------------------------------------------------------------

	function self:skip() tour:skip() end
	function self:destroy() tour:destroy(); hide(); if tourScreen and tourScreen.Parent then tourScreen:Destroy() end end

	function self:markTalked()
		self.talked = true
	end

	function self:isVisible()
		return visible
			and card.Visible
	end

	-----------------------------------------------------------------
	-- UPDATE
	-----------------------------------------------------------------

	function self:update(profile, state)
        if Players.LocalPlayer:GetAttribute("SpyEntryPending")==true or Players.LocalPlayer:GetAttribute("SpyEntryActive")==true then hide();return end
		tourSkip.Text=english(ctx) and "Skip" or "Пропустить"
		tour:update(profile,state)
		if tour.active then hide() return end
		if self.dismissed then
			hide()
			return
		end

		if not profile
			or not profile.ready
		then
			hide()
			return
		end

		---------------------------------------------------------
		-- После первой партии автоматически больше не показываем.
		---------------------------------------------------------

		if (profile.rounds or 0) > 0 then
			hide()
			return
		end

		---------------------------------------------------------
		-- Во время игры / за столом не мешаем.
		---------------------------------------------------------

		if state
			and state.tableId
		then
			hide()
			return
		end

		---------------------------------------------------------
		-- Если открыт диалог — тоже прячем.
		---------------------------------------------------------

		if ctx.dialogueVisible
			and ctx.dialogueVisible()
		then
			hide()
			return
		end

		show()
	end

	return self
end

return OnboardingUI
