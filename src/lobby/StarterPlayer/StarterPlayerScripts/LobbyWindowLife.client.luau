-- Optional local street movement and spatial rain. No waits, remotes or profile writes.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local SoundService=game:GetService("SoundService")
local touch=game:GetService("UserInputService").TouchEnabled
local player=Players.LocalPlayer
if not player then return end
local scene,windows,traffic
local cars,weather={},{}
local connections={}
local pending,stopped=false,false
local accumulator=0
local function clean()
    for _,entry in ipairs(weather)do
        entry.loaded:Disconnect();entry.sound:Destroy();entry.group:Destroy()
    end
    table.clear(weather);table.clear(cars)
    if traffic then traffic:Destroy();traffic=nil end
    windows=nil
end
local function addWeather(bay,index)
    local handle=bay:FindFirstChild("WindowHandle",true)
    local group=Instance.new("SoundGroup");group.Name="SpyWindowWeather"..index;group.Volume=.055;group.Parent=SoundService
    local sound=Instance.new("Sound");sound.Name="WindowRainSound";sound.SoundId=scene.RAIN_SOUND
    sound.Looped=true;sound.Volume=.34;sound.RollOffMode=Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance=5;sound.RollOffMaxDistance=48;sound.SoundGroup=group
    sound:SetAttribute("SpyAudioCategory","SFX")
    local eq=Instance.new("EqualizerSoundEffect");eq.Name="GlassMuffle";eq.LowGain=-2;eq.MidGain=-9;eq.HighGain=-18;eq.Parent=sound
    sound.Parent=handle
    local loaded=sound:GetPropertyChangedSignal("IsLoaded"):Connect(function()
        if sound.IsLoaded then player:SetAttribute("SpyWindowRainAudioStatus","ready")end
    end)
    sound:Play()
    if sound.IsLoaded then player:SetAttribute("SpyWindowRainAudioStatus","ready")end
    task.delay(12,function()
        if sound.Parent and not sound.IsLoaded then
            player:SetAttribute("SpyWindowRainAudioStatus","unavailable")
            warn("[WindowRain] Audio has not loaded; window and lobby remain usable.")
        end
    end)
    weather[#weather+1]={bay=bay,sound=sound,group=group,eq=eq,loaded=loaded,mix=.055}
end
local function tireSpray(car)
    local attachment=Instance.new("Attachment");attachment.Name="TyreMist";attachment.Position=Vector3.new(0,.25,2.25)*(car:GetAttribute("TrafficScale")or 1);attachment.Parent=car.PrimaryPart
    local spray=Instance.new("ParticleEmitter");spray.Name="RoadSpray";spray.Texture="rbxasset://textures/particles/smoke_main.dds"
    spray.Rate=4;spray.Lifetime=NumberRange.new(.35,.65);spray.Speed=NumberRange.new(1.5,2.5)
    spray.EmissionDirection=Enum.NormalId.Back;spray.SpreadAngle=Vector2.new(12,28)
    spray.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,.85)})
    spray.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.91),NumberSequenceKeypoint.new(1,1)})
    spray.Color=ColorSequence.new(Color3.fromRGB(137,150,155));spray.Enabled=false;spray.Parent=attachment
    return spray
end
local function scan()
    if stopped then return end
    local club=workspace:FindFirstChild("SpyClub")
    local model=club and club:FindFirstChild("RainWindows")
    if not model or model==windows then return end
    local shared=ReplicatedStorage:FindFirstChild("SpyShared")
    local module=shared and shared:FindFirstChild("NightStreetScene")
    if not module then return end
    local bays={model:FindFirstChild("EntranceWindow"),model:FindFirstChild("LoungeWindow")}
    if not bays[1]or not bays[2]then return end
    for _,bay in ipairs(bays)do if not bay:FindFirstChild("WindowHandle",true)then return end end
    local ok,result=pcall(require,module)
    if not ok then player:SetAttribute("SpyWindowLifeStatus","failed");warn("[WindowLife] "..tostring(result));return end
    clean();scene=result;windows=model
    traffic=Instance.new("Folder");traffic.Name="SpyNightTraffic";traffic.Parent=workspace
    player:SetAttribute("SpyWindowRainAudioStatus","loading")
    for index,bay in ipairs(bays)do
        addWeather(bay,index)
        local car=scene.createCar(traffic,index)
        local lights={}
        for _,p in ipairs(car:GetDescendants())do if p:IsA("Light")then lights[#lights+1]=p end end
        cars[index]={model=car,lights=lights,spray=tireSpray(car)}
        car:PivotTo(CFrame.new(0,-500-index*10,0))
    end
    player:SetAttribute("SpyWindowLifeStatus","ready")
end
local function schedule()
    if stopped or pending then return end;pending=true
    task.defer(function()
        pending=false
        local ok,detail=pcall(scan)
        if not ok then clean();player:SetAttribute("SpyWindowLifeStatus","failed");warn("[WindowLife] "..tostring(detail))end
    end)
end
connections[#connections+1]=workspace.DescendantAdded:Connect(function(object)
    if object.Name=="RainWindows"or object.Name=="WindowHandle"or object.Name=="NightStreetScene"then schedule()end
end)
-- Shared modules can arrive after the scenery in streamed/client startup.
connections[#connections+1]=ReplicatedStorage.DescendantAdded:Connect(function(object)if object.Name=="NightStreetScene"then schedule()end end)
connections[#connections+1]=RunService.Heartbeat:Connect(function(dt)
    if not windows then return end
    if not windows.Parent then clean();schedule();return end
    accumulator+=dt;if accumulator<(touch and 1/20 or 1/30) then return end
    local elapsed=math.min(accumulator,.15);accumulator=0
    local calm=player:GetAttribute("SpyReducedMotion")==true
    local effects=player:GetAttribute("SpyEffects")~=false
    local english=player:GetAttribute("SpyLanguage")=="en"
    local now=workspace:GetServerTimeNow()
    for slot,entry in ipairs(cars)do
        local frame=not calm and scene.trafficFrame(slot,now)or nil
        entry.model:PivotTo(frame or CFrame.new(0,-500-slot*10,0))
        entry.spray.Enabled=frame~=nil and effects
        for _,l in ipairs(entry.lights)do l.Enabled=frame~=nil end
    end
    for _,entry in ipairs(weather)do
        local open=entry.bay:GetAttribute("WindowOpen")==true
        local target=open and 1 or .055
        entry.mix+=(target-entry.mix)*(1-math.exp(-4*elapsed))
        -- Existing ClientPreferences owns Sound.Volume. This gain only models the opening.
        entry.group.Volume=entry.mix
        local clarity=(entry.mix-.055)/.945
        entry.eq.HighGain=-18+clarity*15;entry.eq.MidGain=-9+clarity*8
        local prompt=entry.bay:FindFirstChild("WindowPrompt",true)
        if prompt then
            prompt.ActionText=english and (open and "Close"or "Open slightly")or (open and "Закрыть"or "Приоткрыть")
            prompt.ObjectText=english and "Window · rain"or "Окно · дождь"
            prompt.Enabled=player:GetAttribute("SpyCinematicActive")~=true
        end
    end
end)
script.Destroying:Connect(function()
    stopped=true;for _,connection in ipairs(connections)do connection:Disconnect()end;clean()
end)
schedule()
