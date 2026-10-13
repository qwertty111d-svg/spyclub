-- One local controller in either place; only the server's profile confirms a save.
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Lighting = game:GetService('Lighting')
local SoundService = game:GetService('SoundService')
local HttpService = game:GetService('HttpService')
local Preferences = require(script.Parent.Preferences)
local ClientPreferences = {}
local player = Players.LocalPlayer
local current = Preferences.defaults()
local confirmed = Preferences.defaults()
local changed = Instance.new('BindableEvent')
ClientPreferences.Changed = changed.Event
local started, ready, dirty = false, false, false
local status, revision, editVersion, debounce = 'loading', -1, 0, 0
local pending, action, blur
local sounds = setmetatable({}, {__mode='k'})
local effects = setmetatable({}, {__mode='k'})

local function music(sound)
	local category = sound:GetAttribute('SpyAudioCategory')
	if category == 'Music' then return true end
	if category == 'SFX' then return false end
	-- Looping alone is NOT music: engines, ambience and room sounds remain SFX.
	local node = sound
	for _ = 1, 4 do
		if not node or node == workspace or node == SoundService then break end
		local name = string.lower(node.Name)
		if name:find('music',1,true) or name:find('soundtrack',1,true)
			or name:find('jazz',1,true) or name:find('lobbytheme',1,true) then return true end
		node = node.Parent
	end
	return sound.SoundGroup ~= nil and string.lower(sound.SoundGroup.Name):find('music',1,true) ~= nil
end
local function applySound(sound, record)
	local multiplier = music(sound) and current.musicVolume or current.sfxVolume
	record.applied = record.base * multiplier
	if sound.Volume ~= record.applied then sound.Volume = record.applied end
end
local function applyEffect(node, record)
	record.applied = current.effects and record.base
	if node.Enabled ~= record.applied then node.Enabled = record.applied end
end
local function observe(node)
	if node:IsA('Sound') and not sounds[node] then
		local record = {base=node.Volume}
		sounds[node] = record
		node:GetPropertyChangedSignal('Volume'):Connect(function()
			if node.Volume ~= record.applied then record.base=node.Volume; applySound(node,record) end
		end)
		node:GetAttributeChangedSignal('SpyAudioCategory'):Connect(function() applySound(node,record) end)
		applySound(node,record)
	elseif (node:IsA('ParticleEmitter') or node:IsA('Trail') or node:IsA('Beam')
		or node:IsA('BloomEffect') or node:IsA('SunRaysEffect')) and not effects[node] then
		local record = {base=node.Enabled}
		effects[node] = record
		node:GetPropertyChangedSignal('Enabled'):Connect(function()
			if node.Enabled ~= record.applied then record.base=node.Enabled; applyEffect(node,record) end
		end)
		applyEffect(node,record)
	end
end
local function applyFOV()
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable and player:GetAttribute('SpyCinematicActive') ~= true then
		if camera.FieldOfView ~= current.fov then camera.FieldOfView = current.fov end
	end
end
function ClientPreferences.get() return table.clone(current) end
function ClientPreferences.status() return status, ready end
function ClientPreferences.apply(settings)
	local clean = Preferences.sanitize(settings)
	if not clean then return false end
	current = clean
	player:SetAttribute('SpyLanguage',current.language)
	player:SetAttribute('SpyReducedMotion',current.reducedMotion)
	player:SetAttribute('SpyCameraMotion',current.cameraMotion)
	player:SetAttribute('SpyEffects',current.effects)
	player:SetAttribute('SpyFOV',current.fov)
	for sound,record in pairs(sounds) do if sound.Parent then applySound(sound,record) end end
	for node,record in pairs(effects) do if node.Parent then applyEffect(node,record) end end
	if blur then blur.Enabled=current.motionBlur and not current.reducedMotion and current.effects end
	applyFOV()
	changed:Fire()
	return true
end

local send
local function schedule()
	debounce += 1
	local token = debounce
	task.delay(0.5,function() if token==debounce then send() end end)
end
local function rollback()
	pending, dirty = nil, false
	status = 'failed'
	ClientPreferences.apply(confirmed)
end
send = function()
	if not ready or not dirty or pending then return end
	local request = {id='prefs-'..HttpService:GenerateGUID(false),version=editVersion}
	pending = request
	status = 'saving'
	changed:Fire()
	local ok = pcall(function() action:FireServer('settings',table.clone(current),request.id) end)
	if not ok then rollback(); return end
	task.delay(12,function()
		if pending==request then
			rollback()
			action:FireServer('preferencesSync',nil,'prefs-'..HttpService:GenerateGUID(false))
		end
	end)
end
function ClientPreferences.set(key,value)
	if not ready then return false end
	local nextSettings = table.clone(current)
	nextSettings[key] = value
	local clean = Preferences.sanitize(nextSettings)
	if not clean then return false end
	editVersion += 1
	dirty, status = true, 'saving'
	ClientPreferences.apply(clean)
	schedule()
	return true
end
function ClientPreferences.sync(profile,receipt,requestId)
	local own = pending and requestId==pending.id
	local clean
	if type(profile)=='table' and profile.ready==true and (tonumber(profile.revision) or 0)>=revision then
		local raw = type(profile.settings)=='table' and table.clone(profile.settings) or {}
		if profile.language=='ru' or profile.language=='en' or profile.language=='zh' then raw.language=profile.language end
		clean = Preferences.sanitize(raw)
		if clean then confirmed=clean; revision=tonumber(profile.revision) or 0; ready=true end
	end
	if own then
		if not receipt or receipt.ok~=true or not clean then rollback(); return end
		local newer = editVersion>pending.version
		pending = nil
		dirty = newer
		if newer then schedule() else status='saved'; ClientPreferences.apply(confirmed) end
	elseif clean and not dirty and not pending then
		status='saved'
		ClientPreferences.apply(confirmed)
	end
	changed:Fire()
end
function ClientPreferences.start()
	if started then return ClientPreferences end
	started = true
	task.spawn(function()
		local module=script.Parent:FindFirstChild('I18n')
		local pg=player:FindFirstChildOfClass('PlayerGui') or player:WaitForChild('PlayerGui',10)
		if module and pg then
			local ok,I18n=pcall(require,module)
			if ok then I18n.bind(pg,player);I18n.bind(workspace,player) end
		end
	end)
	local shared = ReplicatedStorage:WaitForChild('SpyShared')
	action = shared:WaitForChild('EconomyAction')
	shared:WaitForChild('Profile').OnClientEvent:Connect(ClientPreferences.sync)
	local state = shared:FindFirstChild('State')
	if state then state.OnClientEvent:Connect(function(snapshot)
		if type(snapshot)=='table' and snapshot.profile then ClientPreferences.sync(snapshot.profile) end
	end) end
	for _, container in ipairs({workspace,SoundService,Lighting,player:WaitForChild('PlayerGui')}) do
		container.DescendantAdded:Connect(observe)
		for _, node in ipairs(container:GetDescendants()) do observe(node) end
	end
	blur = Instance.new('BlurEffect')
	blur.Name='SpyPreferenceMotionBlur'; blur.Size=0; blur.Enabled=false; blur.Parent=Lighting
	local cameraConnections = {}
	local function watchCamera()
		for _,connection in ipairs(cameraConnections) do connection:Disconnect() end
		table.clear(cameraConnections)
		local camera=workspace.CurrentCamera
		if camera then
			table.insert(cameraConnections,camera:GetPropertyChangedSignal('CameraType'):Connect(function() task.defer(applyFOV) end))
			table.insert(cameraConnections,camera:GetPropertyChangedSignal('FieldOfView'):Connect(applyFOV))
		end
		applyFOV()
	end
	workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(watchCamera)
	player:GetAttributeChangedSignal('SpyCinematicActive'):Connect(applyFOV)
	watchCamera()
	local previousLook
	RunService.RenderStepped:Connect(function(dt)
		local camera=workspace.CurrentCamera
		if not camera then return end
		local look=camera.CFrame.LookVector
		local target=0
		if blur.Enabled and previousLook then
			target=math.clamp(math.acos(math.clamp(look:Dot(previousLook),-1,1))/math.max(dt,1/240)*2,0,9)
		end
		blur.Size += (target-blur.Size)*math.min(dt*12,1)
		previousLook=look
	end)
	ClientPreferences.apply(current)
	local function requestInitialProfile()
		if ready then return end
		action:FireServer('preferencesSync',nil,'prefs-'..HttpService:GenerateGUID(false))
		-- Profile loading can finish after the first request in either place.
		-- Read-only retry; never turns an unavailable profile into writable defaults.
		task.delay(3,requestInitialProfile)
	end
	requestInitialProfile()
	return ClientPreferences
end
return ClientPreferences
