-- The personal character scene leases the real world camera. It never moves,
-- clones or changes the physical state of its actor; adapters own that choice.
local CharacterWorldCamera = {}
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local OPEN_TIME, CLOSE_TIME = .72, .38
local ACTIVE, TOKEN, INTERRUPT = "SpyCharacterSceneActive", "SpyCharacterSceneToken", "SpyCharacterSceneInterrupt"
local CONTROL_TOKEN = "SpyCharacterSceneControlsToken"
local blockers = {
    SpyBilliardsPlaying = true, SpyCheckersPlaying = true, SpyMatchIntroActive = true,
    SpyCaseCinematicActive = true, SpyEntryActive = true, SpyEntryPending = true,
    SpyTeleporting = true, SpyReconnectBusy = true, SpyReturningToLobby = true,
    SpyPhoneCameraActive = true, SpyPhoneActive = false, SpyTradeOpen = false,
}
local sequence = 0

local function disconnect(connections)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end

local function ease(t) return t * t * (3 - 2 * t) end
local function lerp(a, b, t) return a + (b - a) * t end
local function cleanup(operation)
    local ok, message = pcall(operation)
    if not ok then warn("[SPY CLUB] Character camera cleanup failed: " .. tostring(message)) end
end
local function living(character)
    if not character or not character.Parent then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    if not humanoid or humanoid.Health <= 0 or not root then return nil end
    return humanoid, root
end

function CharacterWorldCamera.create(config)
    local player = config.player
    assert(player and type(config.viewport) == "function", "character camera requires a player and viewport")
    sequence += 1
    local self = { active = false }
    local owner = "CharacterWorldCamera:" .. tostring(sequence)
    local renderName, inputName = owner .. ":Camera", owner .. ":Movement"
    local generation, destroyed, reduced = 0, false, false
    local connections, actorConnections, masks = {}, {}, {}
    local camera, saved, written, actor, humanoid, root, realCharacter
    local controls, controlsWereEnabled, controlsDisabled
    local phase, elapsed, startFrame, startFov, closingCallback, openingOptions
    local currentTarget, lastBounds
    local release, abort, render, protectedCall

    local function blocked()
        if config.blocked and config.blocked() then return true end
        for attribute in pairs(blockers) do if player:GetAttribute(attribute) == true then return true end end
        return false
    end

    local function ownsToken()
        return player:GetAttribute(ACTIVE) == true and player:GetAttribute(TOKEN) == owner
    end

    local function ownsCameraPose()
        return camera and written and workspace.CurrentCamera == camera
            and camera.CameraType == written.type
            and camera.CFrame == written.frame
    end

    local function ownsCamera()
        return ownsCameraPose() and camera.CameraSubject == written.subject
    end

    local function restoreMasks()
        for part, value in pairs(masks) do
            cleanup(function()
                if part.Parent and part.LocalTransparencyModifier == 0 then part.LocalTransparencyModifier = value end
            end)
        end
        table.clear(masks)
    end

    local function revealActor()
        for _, part in ipairs(actor:GetDescendants()) do
            if part:IsA("BasePart") then
                if masks[part] == nil then masks[part] = part.LocalTransparencyModifier end
                -- Base Transparency belongs to Wardrobe, including its hidden real head.
                part.LocalTransparencyModifier = 0
            end
        end
    end

    local function source()
        if config.character then
            local ok, value = pcall(config.character)
            return ok and value or nil
        end
        return player.Character
    end

    local function refreshActor()
        local nextActor = source()
        local nextHumanoid, nextRoot = living(nextActor)
        if not nextHumanoid then return false end
        if nextActor ~= actor then
            local previousHumanoid = humanoid
            disconnect(actorConnections)
            restoreMasks()
            actor, humanoid, root = nextActor, nextHumanoid, nextRoot
            -- Appearance rebuilds publish their replacement before removing the
            -- old model. Roblox can clear CameraSubject as that humanoid dies.
            if previousHumanoid and ownsCameraPose()
                and (camera.CameraSubject == previousHumanoid
                    or (camera.CameraSubject == nil and not previousHumanoid.Parent)) then
                camera.CameraSubject = humanoid
                written.subject = humanoid
            end
            actorConnections[#actorConnections + 1] = humanoid.Died:Connect(function() abort("died", true) end)
            actorConnections[#actorConnections + 1] = actor.AncestryChanged:Connect(function()
                if actor.Parent then return end
                local version = generation
                task.defer(function()
                    if self.active and generation == version and not refreshActor() then abort("character_removed", true) end
                end)
            end)
        else
            humanoid, root = nextHumanoid, nextRoot
        end
        revealActor()
        return true
    end

    local function rectangle()
        local ok, value, size, canvasSize = pcall(config.viewport)
        if not ok then return nil end
        local position
        if type(value) == "table" and value.position then
            position, size, canvasSize = value.position, value.size, value.canvasSize
        else
            position = value
        end
        -- Safe-area ScreenGuis can be smaller than the camera projection plane.
        -- AbsolutePosition already locates the stage inside that full plane.
        local nativeSize = camera.ViewportSize
        if nativeSize and nativeSize.X >= 8 and nativeSize.Y >= 8 then canvasSize = nativeSize end
        if not position or not size or not canvasSize or size.X < 8 or size.Y < 8
            or canvasSize.X < 8 or canvasSize.Y < 8 then return nil end
        local paddingX, paddingY = math.min(20, size.X * .06), math.min(24, size.Y * .045)
        local left = math.max(0, position.X + paddingX)
        local right = math.min(canvasSize.X, position.X + size.X - paddingX)
        local top = math.max(0, position.Y + paddingY)
        local bottom = math.min(canvasSize.Y, position.Y + size.Y - paddingY)
        if right - left < 4 or bottom - top < 4 then return nil end
        return {
            left = left / canvasSize.X * 2 - 1, right = right / canvasSize.X * 2 - 1,
            top = 1 - top / canvasSize.Y * 2, bottom = 1 - bottom / canvasSize.Y * 2,
            x = (left + right) / canvasSize.X - 1, y = 1 - (top + bottom) / canvasSize.Y,
            aspect = canvasSize.X / canvasSize.Y,
        }
    end

    local function rayTo(center, position)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = actor == realCharacter and { actor } or { actor, realCharacter }
        params.IgnoreWater = true
        return workspace:Raycast(center, position - center, params)
    end

    local function fitAt(bounds, size, rect, forward, fov)
        local tanV = math.tan(math.rad(fov) * .5)
        local tanH = tanV * rect.aspect
        local baseRight = Vector3.yAxis:Cross(forward).Unit
        local base = CFrame.fromMatrix(Vector3.zero, baseRight, Vector3.yAxis, forward)
        local screenRay = Vector3.new(rect.x * tanH, rect.y * tanV, -1).Unit
        local orientation = base * CFrame.lookAt(Vector3.zero, screenRay):Inverse()
        local right, up, back = orientation.RightVector, orientation.UpVector, orientation.ZVector
        local depthPerDistance = forward:Dot(back)
        local distance = 3
        for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
            local corner = bounds:PointToWorldSpace(Vector3.new(size.X * x, size.Y * y, size.Z * z) * .5) - bounds.Position
            local px, py, pz = corner:Dot(right), corner:Dot(up), corner:Dot(back)
            distance = math.max(distance, (pz + 1.5) / depthPerDistance,
                (px / tanH + rect.right * pz) / (depthPerDistance * (rect.right - rect.x)),
                (-px / tanH - rect.left * pz) / (depthPerDistance * (rect.x - rect.left)),
                (py / tanV + rect.top * pz) / (depthPerDistance * (rect.top - rect.y)),
                (-py / tanV - rect.bottom * pz) / (depthPerDistance * (rect.y - rect.bottom)))
        end end end
        -- Aim the optical axis below/aside the actor for an off-centre stage.
        -- Translating a level camera instead would put it below the club floor
        -- for a phone layout whose avatar sits near the top of the screen.
        return CFrame.fromMatrix(bounds.Position + forward * distance, right, up, back)
    end

    local function target()
        local rect = rectangle()
        if not rect then return nil end
        local ok, bounds, size = pcall(function() return actor:GetBoundingBox() end)
        if not ok then return nil end
        local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        if forward.Magnitude < .01 then forward = Vector3.new(0, 0, -1) end
        forward = forward.Unit
        -- Prefer the actor's front. Wider lenses and small alternate angles allow
        -- a full standing frame beside club furniture without entering a wall.
        for _, fov in ipairs({42, 58, 72}) do
            for _, angle in ipairs({0, 18, -18, 35, -35}) do
                local rotated = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(forward)
                local frame = fitAt(bounds, size, rect, rotated, fov)
                if not rayTo(bounds.Position, frame.Position) then
                    lastBounds = { center = bounds.Position, radius = math.max(size.X, size.Z) * .5 + .8 }
                    return { frame = frame, fov = fov, focus = CFrame.new(bounds.Position) }
                end
            end
        end
        return nil
    end

    local function write(frame, fov, focus)
        -- Track each completed property write, including a partially failed
        -- acquisition. Lens/focus updates alone do not transfer camera control.
        written = written or {type = camera.CameraType, subject = camera.CameraSubject,
            frame = camera.CFrame, fov = camera.FieldOfView, focus = camera.Focus}
        camera.CameraType = Enum.CameraType.Scriptable
        written.type = camera.CameraType
        camera.CameraSubject = humanoid
        written.subject = camera.CameraSubject
        camera.CFrame = frame
        written.frame = camera.CFrame
        camera.FieldOfView = fov
        written.fov = camera.FieldOfView
        camera.Focus = focus
        written.focus = camera.Focus
    end

    local function orbit(from, to, t)
        if t <= 0 then return from end
        if t >= 1 then return to end
        local center = lastBounds.center
        local a, b = from.Position - center, to.Position - center
        local yawA, yawB = math.atan2(a.X, a.Z), math.atan2(b.X, b.Z)
        local angle = (yawB - yawA + math.pi) % (math.pi * 2) - math.pi
        local radiusA = math.sqrt(a.X * a.X + a.Z * a.Z)
        local radiusB = math.sqrt(b.X * b.X + b.Z * b.Z)
        local yaw = yawA + angle * t
        local radius = math.max(lastBounds.radius, lerp(radiusA, radiusB, t))
        -- A shallow arc also gives an already frontal camera a visible approach.
        yaw += math.sin(t * math.pi) * math.rad(20)
        local position = center + Vector3.new(math.sin(yaw) * radius, lerp(a.Y, b.Y, t), math.cos(yaw) * radius)
        local hit = rayTo(center, position)
        if hit then
            position = hit.Position + hit.Normal * .45
            if (position - center).Magnitude < lastBounds.radius then return camera.CFrame end
        end
        return (from:Lerp(to, t) - from:Lerp(to, t).Position) + position
    end

    local function findControls()
        if config.controls then return config.controls end
        local scripts = player:FindFirstChild("PlayerScripts")
        local module = scripts and scripts:FindFirstChild("PlayerModule")
        if module then
            local ok, result = pcall(function() return require(module):GetControls() end)
            if ok then return result end
        end
        return nil
    end

    release = function(restoreCamera, callback)
        local tokenOwned, cameraOwned = ownsToken(), ownsCamera()
        self.active = false
        generation += 1
        cleanup(function() RunService:UnbindFromRenderStep(renderName) end)
        cleanup(function() Actions:UnbindAction(inputName) end)
        cleanup(function() disconnect(connections) end)
        cleanup(function() disconnect(actorConnections) end)
        restoreMasks()
        -- Camera ownership can change independently of the Disable we issued.
        -- A successor that retains disabled controls claims this token first.
        if controlsDisabled and player:GetAttribute(CONTROL_TOKEN) == owner then
            if controlsWereEnabled and controls.controlsEnabled == false then
                cleanup(function() controls:Enable() end)
            end
            cleanup(function() player:SetAttribute(CONTROL_TOKEN, nil) end)
        end
        if tokenOwned then
            if restoreCamera and cameraOwned then
                cleanup(function() camera.CFrame = saved.frame end)
                cleanup(function() if camera.Focus == written.focus then camera.Focus = saved.focus end end)
                cleanup(function() if camera.FieldOfView == written.fov then camera.FieldOfView = saved.fov end end)
                local subject = saved.subject
                if saved.type == Enum.CameraType.Custom
                    and (not subject or not subject.Parent or (subject:IsA("Humanoid") and subject.Health <= 0)) then
                    local currentHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                    subject = currentHumanoid and currentHumanoid.Health > 0 and currentHumanoid or nil
                end
                cleanup(function() camera.CameraSubject = subject end)
                cleanup(function() camera.CameraType = saved.type end)
            end
            cleanup(function() if Input.MouseBehavior == Enum.MouseBehavior.Default then Input.MouseBehavior = saved.mouseBehavior end end)
            cleanup(function() if Input.MouseIconEnabled == true then Input.MouseIconEnabled = saved.mouseIcon end end)
            -- Clearing only this token leaves a later scene owner's lease intact.
            cleanup(function() player:SetAttribute(TOKEN, nil) end)
            cleanup(function() player:SetAttribute(ACTIVE, false) end)
        end
        phase, currentTarget, openingOptions, closingCallback = nil, nil, nil, nil
        controls, controlsDisabled = nil, false
        camera, saved, written, actor, humanoid, root = nil, nil, nil, nil, nil, nil
        if callback then cleanup(callback) end
    end

    abort = function(reason, restoreCamera)
        if not self.active then return end
        local callback = openingOptions and openingOptions.onUnavailable
        release(restoreCamera == true, callback and function() callback(reason) end)
    end

    local function finishOpen()
        write(currentTarget.frame, currentTarget.fov, currentTarget.focus)
        phase = "ready"
        local callback = openingOptions and openingOptions.onFramed
        if callback then
            openingOptions.onFramed = nil
            callback()
        end
    end

    render = function(dt)
        if not self.active then return end
        if not ownsToken() then abort("ownership_lost", false); return end
        if player.Character ~= realCharacter or not refreshActor() then abort("character_removed", true); return end
        if not ownsCamera() then abort("camera_changed", false); return end
        if blocked() then abort("interrupted", false); return end
        if phase == "closing" then
            elapsed += math.max(0, dt)
            local alpha = reduced and 1 or math.min(1, elapsed / CLOSE_TIME)
            write(orbit(startFrame, saved.frame, ease(alpha)), lerp(startFov, saved.fov, ease(alpha)), saved.focus)
            if alpha >= 1 then release(true, closingCallback) end
            return
        end
        currentTarget = target()
        if not currentTarget then abort("no_safe_view", true); return end
        if phase == "opening" then
            elapsed += math.max(0, dt)
            local alpha = reduced and 1 or math.min(1, elapsed / OPEN_TIME)
            if alpha >= 1 then finishOpen()
            else write(orbit(startFrame, currentTarget.frame, ease(alpha)), lerp(startFov, currentTarget.fov, ease(alpha)), currentTarget.focus) end
        else
            write(currentTarget.frame, currentTarget.fov, currentTarget.focus)
        end
    end

    function self:open(options)
        options = options or {}
        local function unavailable(reason)
            if options.onUnavailable then
                local ok, message = pcall(options.onUnavailable, reason)
                if not ok then warn("[SPY CLUB] Character camera fallback failed: " .. tostring(message)) end
            end
            return false
        end
        if destroyed then return unavailable("destroyed") end
        if self.active then release(true) end
        if player:GetAttribute(ACTIVE) == true or player:GetAttribute(TOKEN) ~= nil then return unavailable("ownership_lost") end
        generation += 1
        local requestVersion = generation
        local nextCamera, nextRealCharacter = workspace.CurrentCamera, player.Character
        local nextActor = source()
        local human = living(nextActor)
        if not nextCamera then return unavailable("camera_missing") end
        if not human or not nextRealCharacter then return unavailable("no_actor") end
        if blocked() then return unavailable("blocked") end
        -- Snapshot every leased property before controls, mouse, attributes or camera writes.
        local nextControls = findControls()
        -- Requiring PlayerModule may yield. A later open, close or destroy wins.
        if destroyed or generation ~= requestVersion then return unavailable("interrupted") end
        if workspace.CurrentCamera ~= nextCamera or player.Character ~= nextRealCharacter then return unavailable("camera_changed") end
        if player:GetAttribute(ACTIVE) == true or player:GetAttribute(TOKEN) ~= nil then return unavailable("ownership_lost") end
        camera, realCharacter, controls, actor = nextCamera, nextRealCharacter, nextControls, nil
        controlsWereEnabled = controls and controls.controlsEnabled == true
        saved = { frame = camera.CFrame, focus = camera.Focus, fov = camera.FieldOfView,
            type = camera.CameraType, subject = camera.CameraSubject,
            mouseBehavior = Input.MouseBehavior, mouseIcon = Input.MouseIconEnabled }
        reduced = options.reducedMotion == true
        self.active, openingOptions, phase, elapsed = true, options, "opening", 0
        startFrame, startFov = saved.frame, saved.fov
        player:SetAttribute(TOKEN, owner)
        player:SetAttribute(ACTIVE, true)
        if not refreshActor() then release(false); return unavailable("no_actor") end
        currentTarget = target()
        if not currentTarget then release(false); return unavailable("no_safe_view") end
        if controlsWereEnabled then
            player:SetAttribute(CONTROL_TOKEN, owner)
            controlsDisabled = true
            controls:Disable()
        end
        Input.MouseBehavior, Input.MouseIconEnabled = Enum.MouseBehavior.Default, true
        Actions:BindActionAtPriority(inputName, function() return Enum.ContextActionResult.Sink end, false, 3000,
            Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward, Enum.PlayerActions.CharacterLeft,
            Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
        write(saved.frame, saved.fov, saved.focus)
        connections[#connections + 1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if self.active and workspace.CurrentCamera ~= camera then abort("camera_replaced", false) end
        end)
        connections[#connections + 1] = player:GetAttributeChangedSignal(INTERRUPT):Connect(function() abort("interrupted", false) end)
        connections[#connections + 1] = player:GetAttributeChangedSignal(TOKEN):Connect(function()
            if self.active and not ownsToken() then abort("ownership_lost", false) end
        end)
        connections[#connections + 1] = player:GetAttributeChangedSignal(ACTIVE):Connect(function()
            if self.active and not ownsToken() then abort("ownership_lost", false) end
        end)
        for attribute, cameraOwner in pairs(blockers) do
            connections[#connections + 1] = player:GetAttributeChangedSignal(attribute):Connect(function()
                if self.active and player:GetAttribute(attribute) == true then abort("interrupted", not cameraOwner) end
            end)
        end
        connections[#connections + 1] = player.CharacterRemoving:Connect(function(character)
            if character == realCharacter then abort("character_removed", true) end
        end)
        local realHumanoid = realCharacter:FindFirstChildOfClass("Humanoid")
        if realHumanoid and realHumanoid ~= humanoid then
            connections[#connections + 1] = realHumanoid.Died:Connect(function() abort("died", true) end)
        end
        if player.OnTeleport then connections[#connections + 1] = player.OnTeleport:Connect(function() abort("teleport", false) end) end
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 10, function(dt)
            protectedCall(render, nil, nil, dt)
        end)
        if reduced then finishOpen() end
        return true
    end

    function self:close(options)
        options = options or {}
        generation += 1
        if not self.active then if options.onClosed then cleanup(options.onClosed) end; return end
        if openingOptions then openingOptions.onFramed = nil end
        if options.immediate or reduced or not ownsToken() or not ownsCamera() then release(true, options.onClosed); return end
        phase, elapsed, startFrame, startFov, closingCallback = "closing", 0, camera.CFrame, camera.FieldOfView, options.onClosed
    end

    function self:resize()
        if not self.active or phase == "closing" then return end
        if not ownsToken() or not ownsCamera() then abort("camera_changed", false); return end
        if not refreshActor() then abort("character_removed", true); return end
        currentTarget = target()
        if not currentTarget then abort("no_safe_view", true); return end
        if phase == "ready" then write(currentTarget.frame, currentTarget.fov, currentTarget.focus) end
    end

    function self:setReducedMotion(value)
        reduced = value == true
        if not self.active or not reduced then return end
        if phase == "closing" then release(true, closingCallback)
        elseif phase == "opening" then self:resize(); if self.active then finishOpen() end end
    end

    function self:destroy()
        if destroyed then return end
        destroyed = true
        generation += 1
        if self.active then release(true) end
    end

    -- Native calls and scene callbacks can fail after Scriptable, controls and
    -- attributes were acquired. Roll back once; never leave a hidden framing
    -- scene or an erroring callback bound to every render frame.
    protectedCall = function(operation, onUnavailable, onClosed, ...)
        local ok, result = pcall(operation, ...)
        if ok then return result end
        warn("[SPY CLUB] Character camera failed: " .. tostring(result))
        local notify = openingOptions and openingOptions.onUnavailable or onUnavailable
        local completeClose = closingCallback or onClosed
        if self.active then release(true, completeClose)
        elseif completeClose then cleanup(completeClose) end
        if notify and not completeClose then
            local notified, message = pcall(notify, "camera_error")
            if not notified then warn("[SPY CLUB] Character camera fallback failed: " .. tostring(message)) end
        end
        return false
    end
    local open, close, resize, setReducedMotion, destroy = self.open, self.close, self.resize, self.setReducedMotion, self.destroy
    function self:open(options)
        return protectedCall(open, options and options.onUnavailable, nil, self, options)
    end
    function self:close(options) return protectedCall(close, nil, options and options.onClosed, self, options) end
    function self:resize() return protectedCall(resize, nil, nil, self) end
    function self:setReducedMotion(value) return protectedCall(setReducedMotion, nil, nil, self, value) end
    function self:destroy() return protectedCall(destroy, nil, nil, self) end

    return self
end

return CharacterWorldCamera
