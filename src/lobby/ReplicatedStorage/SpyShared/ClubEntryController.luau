-- The entrance owns a temporary camera/control lease, including late native initialization.
local Controller = {}
function Controller.create(ctx)
    local self = {active=false, entering=false, finished=false}
    local run=ctx.run or game:GetService("RunService")
    local prompts=ctx.prompts or game:GetService("ProximityPromptService")
    local saved, cameraConnection, pose, fovPose, controls, controlsWereEnabled, promptEnabled
    local humanoids={}
    local forced={WalkSpeed=0,JumpPower=0,JumpHeight=0,AutoRotate=false}
    local binding="SpyClubEntryCamera"
    local motionConnections={}
    local portraitFrame
    local function stopEstablish(snap)
        if self.establishTween then
            pcall(function()self.establishTween:Cancel()end)
            self.establishTween=nil
        end
        if snap and pose and portraitFrame and not self.entering then pose.Value=portraitFrame end
    end
    local function characterFrame(wide)
        local character=ctx.player.Character
        local root=character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
        if not root then return nil end
        local focus=root.Position+Vector3.new(0,1.7,0)
        local look=root.CFrame.LookVector
        local flat=Vector3.new(look.X,0,look.Z)
        if flat.Magnitude<.01 then flat=Vector3.new(0,0,-1)end
        local direction=(flat.Unit*-1+Vector3.new(0,wide and .48 or .28,0)).Unit
        local distance=math.clamp(ctx.player.CameraMaxZoomDistance,3.5,10)+(wide and 4 or 0)
        local position=focus+direction*distance
        -- Optional wall clearance must never become a dependency of the handoff.
        pcall(function()
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={character};params.IgnoreWater=true
            local hit=ctx.workspace:Raycast(focus,position-focus,params)
            if hit then position=hit.Position-direction*.6 end
        end)
        return CFrame.lookAt(position,focus),CFrame.new(focus)
    end
    local function hold()
        if not self.active then return end
        local camera=ctx.workspace.CurrentCamera
        if camera then
            camera.CameraType=Enum.CameraType.Scriptable
            local frame=pose.Value
            if not self.entering and ctx.idleDrift~=false and ctx.player:GetAttribute("SpyReducedMotion")~=true and ctx.player:GetAttribute("SpyCameraMotion")~=false then
                local t=os.clock();frame=frame*CFrame.new(math.sin(t*.18)*.08,math.sin(t*.23)*.025,0)
            end
            camera.CFrame=frame;camera.FieldOfView=fovPose.Value
            camera.Focus=self.worldFocus or pose.Value*CFrame.new(0,0,-(ctx.focusDistance or 24))
        end
        ctx.input.MouseBehavior=Enum.MouseBehavior.Default
        if controls and controls.controlsEnabled~=false then controls:Disable() end
        if prompts.Enabled~=false then promptEnabled=prompts.Enabled;prompts.Enabled=false end
        local character=ctx.player.Character
        local h=character and character:FindFirstChildOfClass("Humanoid")
        if h then
            local values=humanoids[h]
            if not values then
                values={};for name in pairs(forced)do values[name]=h[name]end;humanoids[h]=values
            end
            for name,value in pairs(forced)do
                if h[name]~=value then values[name]=h[name];h[name]=value end
            end
            h.Jump=false;h:Move(Vector3.zero,false)
        end
    end
    local function finish()
        if self.finished then return end
        self.finished=true;self.active=false
        -- Remove writers before restoring state. Every release is isolated from optional engine errors.
        pcall(function()run:UnbindFromRenderStep(binding)end)
        if cameraConnection then cameraConnection:Disconnect() end
        stopEstablish(false)
        for _,c in ipairs(motionConnections)do c:Disconnect()end
        table.clear(motionConnections)
        if self.tween then pcall(function()self.tween:Cancel()end)end
        if self.fovTween then pcall(function()self.fovTween:Cancel()end)end
        if pose then pose:Destroy()end
        if fovPose then fovPose:Destroy()end
        pcall(function()ctx.actions:UnbindAction("SpyClubEntryMovement")end)
        for h,values in pairs(humanoids)do
            pcall(function()
                for name,value in pairs(forced)do if h[name]==value then h[name]=values[name]end end
                h.Jump=false;h:Move(Vector3.zero,false)
            end)
        end
        if controls and controlsWereEnabled then pcall(function()controls:Enable()end)end
        if promptEnabled~=nil then pcall(function()if prompts.Enabled==false then prompts.Enabled=promptEnabled end end)end
        if saved then
            pcall(function()
                local camera=ctx.workspace.CurrentCamera
                if camera then
                    camera.FieldOfView=ctx.player:GetAttribute("SpyFOV") or saved.fov
                    local frame,focus=characterFrame(false)
                    camera.CFrame=frame or saved.cframe
                    camera.Focus=focus or saved.focus
                    local character=ctx.player.Character
                    local subject=character and character:FindFirstChildOfClass("Humanoid") or saved.subject
                    if subject then camera.CameraSubject=subject end
                    -- The authored place camera can still be Fixed before PlayerModule starts.
                    camera.CameraType=Enum.CameraType.Custom
                end
                ctx.input.MouseBehavior=saved.mouse
            end)
        end
        ctx.player:SetAttribute("SpyEntryActive",false)
        ctx.player:SetAttribute("SpyEntryPending",false)
        ctx.player:SetAttribute("SpyEntryCompleted",true)
        if ctx.close then ctx.close() end
    end
    self.finish=finish
    -- Reframe only the held portrait. A viewport rotation cannot replace an exit/handoff tween.
    function self:setPortraitFrame(frame)
        if not self.active or self.entering or self.finished or frame==portraitFrame then return end
        portraitFrame=frame;stopEstablish(true);hold()
    end
    function self:setControls(value)
        if not self.active or controls==value then return end
        if controls and controlsWereEnabled then controls:Enable()end
        controls=value;controlsWereEnabled=value.controlsEnabled~=false
        value:Disable()
    end
    function self:start(cameraFrame)
        if self.finished or self.active then return false end
        local camera=ctx.workspace.CurrentCamera
        if not camera then finish();return false end
        saved={type=camera.CameraType,subject=camera.CameraSubject,cframe=camera.CFrame,focus=camera.Focus,
            fov=camera.FieldOfView,mouse=ctx.input.MouseBehavior}
        portraitFrame=cameraFrame
        local motion=ctx.player:GetAttribute("SpyReducedMotion")~=true and ctx.player:GetAttribute("SpyCameraMotion")~=false
        pose=Instance.new("CFrameValue");pose.Value=motion and ctx.openingFrame or cameraFrame
        fovPose=Instance.new("NumberValue");fovPose.Value=54
        promptEnabled=prompts.Enabled
        self.active=true
        ctx.player:SetAttribute("SpyEntryActive",true)
        ctx.player:SetAttribute("SpyEntryPending",false)
        local ok=pcall(function()
            ctx.actions:BindActionAtPriority("SpyClubEntryMovement",function()
                if ctx.input:GetFocusedTextBox()then return Enum.ContextActionResult.Pass end
                return Enum.ContextActionResult.Sink
            end,false,3000,
                Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Up,Enum.KeyCode.Down,
                Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Space,Enum.KeyCode.Thumbstick1,Enum.KeyCode.ButtonA)
            run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+1,function()
                local held=pcall(hold)
                if not held then finish()end
            end)
            cameraConnection=ctx.workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(finish)
            hold()
        end)
        if not ok then finish();return false end
        local function motionPreference()
            if ctx.player:GetAttribute("SpyReducedMotion")==true or ctx.player:GetAttribute("SpyCameraMotion")==false then
                stopEstablish(true);hold()
            end
        end
        for _,name in ipairs({"SpyReducedMotion","SpyCameraMotion"})do
            table.insert(motionConnections,ctx.player:GetAttributeChangedSignal(name):Connect(motionPreference))
        end
        if motion and ctx.openingFrame then
            local established=pcall(function()
                self.establishTween=ctx.tweens:Create(pose,TweenInfo.new(4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Value=cameraFrame})
                self.establishTween:Play()
            end)
            if not established then stopEstablish(true)end
        end
        return true
    end
    local function approachCharacter()
        if self.finished then return end
        local start=characterFrame(true)
        local target,focus=characterFrame(false)
        if not start or not target or not ctx.revealWorld then finish();return end
        self.stage="character"
        self.worldFocus=focus
        local ok=pcall(function()
            pose.Value=start;hold()
            ctx.revealWorld()
            local info=TweenInfo.new(1.15,Enum.EasingStyle.Quint,Enum.EasingDirection.InOut)
            self.fovTween=ctx.tweens:Create(fovPose,info,{Value=ctx.player:GetAttribute("SpyFOV") or saved.fov})
            self.tween=ctx.tweens:Create(pose,info,{Value=target})
            self.tween.Completed:Connect(finish)
            self.fovTween:Play();self.tween:Play()
        end)
        if not ok then finish()end
    end
    function self:enter(reducedMotion)
        if not self.active or self.entering then return end
        stopEstablish(false)
        self.entering=true
        if reducedMotion then finish();return end
        ctx.delay(3.5,finish)
        local ok=pcall(function()
            -- Animate the owned pose, never the camera that native scripts also update.
            self.tween=ctx.tweens:Create(pose,TweenInfo.new(ctx.exitFrame and .85 or 1.65,Enum.EasingStyle.Quint,Enum.EasingDirection.InOut),
                {Value=ctx.exitFrame or saved.cframe})
            self.tween.Completed:Connect(function()
                if self.finished or self.fading then return end
                self.fading=true
                if ctx.exitFrame and ctx.fadeOut then
                    if pcall(ctx.fadeOut)then ctx.delay(.22,approachCharacter)else finish()end
                else finish()end
            end)
            self.tween:Play()
        end)
        if not ok then finish()end
    end
    return self
end
return Controller
