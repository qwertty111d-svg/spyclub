local SoundService=game:GetService("SoundService")
local Content=game:GetService("ContentProvider")
local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local Config=require(script.Parent.ClubMusicConfig)
local Music={}
local active
function Music.start(player,options)
    if active then return active end
    options=options or{}
    local self={}
    local alive,ready,ending=true,false,false
    local pending,gainTarget,motion
    local failures,connections={},{}
    local tracks=Config.Tracks
    local index=options.mode=="match"and 2 or 0
    local previous=SoundService:FindFirstChild("SpyClubPlaylist")
    if previous then previous:Destroy()end
    local root=Instance.new("Folder");root.Name="SpyClubPlaylist";root.Parent=SoundService
    local gain=Instance.new("SoundGroup");gain.Name="ClubMusicGain";gain.Volume=0;gain.Parent=root
    local sound=Instance.new("Sound");sound.Name="ClubMusic";sound.Looped=false
    sound.Volume=options.mode=="match"and Config.MatchVolume or Config.LobbyVolume
    sound.SoundGroup=gain;sound:SetAttribute("SpyAudioCategory","Music");sound.Parent=root
    local function muted()
        return player:GetAttribute("SpyEntryActive")or player:GetAttribute("SpyEntryPending")
            or player:GetAttribute("SpyMatchIntroActive")or player:GetAttribute("SpyCaseCinematicActive")
    end
    local function fade(value)
        if gainTarget==value then return end
        gainTarget=value
        if motion then motion:Cancel()end
        motion=Tween:Create(gain,TweenInfo.new(Config.FadeSeconds,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Volume=value})
        motion:Play()
    end
    local function sync()
        if not alive then return end
        if muted()then
            fade(0)
            if sound.IsPlaying then sound:Pause()end
        elseif ready then
            if not sound.IsPlaying then
                if sound.IsPaused then sound:Resume()else sound:Play()end
            end
            fade(ending and 0 or player:GetAttribute("SpyPhoneActive")and .35 or 1)
        end
    end
    local launch
    local function failed(entry)
        if not alive or pending~=entry then return end
        failures[entry.id]=os.clock()+Config.RetrySeconds
        pending=nil;ready=false;sound:Stop()
        task.defer(function()if alive then launch()end end)
    end
    local function loaded(entry)
        if not alive or pending~=entry then return end
        pending=nil;ready=true;ending=false
        sync()
    end
    launch=function()
        if not alive then return end
        local chosen
        local nextRetry=math.huge
        for _=1,#tracks do
            index=index%#tracks+1
            local id=tracks[index]
            if (failures[id]or 0)<=os.clock()then chosen=id;break end
            nextRetry=math.min(nextRetry,failures[id])
        end
        if not chosen then
            task.delay(math.max(1,nextRetry-os.clock()),function()if alive then launch()end end)
            return
        end
        sound:Stop();ready=false;ending=false
        if motion then motion:Cancel()end
        gain.Volume=0;gainTarget=nil
        local entry={id=chosen};pending=entry
        sound.SoundId="rbxassetid://"..tostring(chosen)
        task.delay(Config.LoadTimeout,function()failed(entry)end)
        task.spawn(function()
            local ok=pcall(Content.PreloadAsync,Content,{sound},function(_,status)
                if status==Enum.AssetFetchStatus.Success then loaded(entry)
                elseif status==Enum.AssetFetchStatus.Failure then failed(entry)end
            end)
            if not ok then failed(entry)
            elseif pending==entry and sound.IsLoaded then loaded(entry)end
        end)
    end
    connections[#connections+1]=sound.Ended:Connect(function()if alive and ready then ready=false;launch()end end)
    local elapsed=0
    connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
        elapsed+=dt;if elapsed<.5 then return end;elapsed=0
        if ready and sound.IsPlaying and (sound.TimeLength or 0)>Config.FadeSeconds
            and (sound.TimePosition or 0)>=sound.TimeLength-Config.FadeSeconds then ending=true;fade(0)end
    end)
    for _,key in ipairs({"SpyEntryActive","SpyEntryPending","SpyMatchIntroActive","SpyCaseCinematicActive","SpyPhoneActive"})do
        connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(sync)
    end
    function self:Destroy()
        if not alive then return end
        alive=false
        for _,connection in ipairs(connections)do connection:Disconnect()end
        if motion then motion:Cancel()end
        sound:Stop();root:Destroy();active=nil
    end
    active=self;launch();return self
end
return Music
