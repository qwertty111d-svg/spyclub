local checks=0
local function check(v,message)checks+=1;assert(v,message)end
events.Ended=true;events.Loaded=true
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
function Methods:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('Attr_'..key)end
function Methods:SetAttribute(key,value)self._attributes[key]=value;self:GetAttributeChangedSignal(key):Fire()end
function Methods:Play()self.IsPlaying=true;self.IsPaused=false end
function Methods:Pause()self.IsPlaying=false;self.IsPaused=true end
function Methods:Resume()self.IsPlaying=true;self.IsPaused=false end
function Methods:Stop()self.IsPlaying=false;self.IsPaused=false;self.TimePosition=0 end
local sounds=Instance.new('Folder');services.SoundService=sounds
services.RunService={Heartbeat=signal()}
local failing={}
services.ContentProvider={PreloadAsync=function(_,nodes,callback)
 local sound=nodes[1]
 if failing[sound.SoundId]then callback(sound.SoundId,Enum.AssetFetchStatus.Failure);return end
 sound.IsLoaded=true;sound.TimeLength=60;sound.TimePosition=0
 callback(sound.SoundId,Enum.AssetFetchStatus.Success)
end}
local function load(name)
 local chunk=assert(loadstring(Sources[name],name))
 setfenv(chunk,setmetatable({script=script,game=game,require=function(k)return modules[k]end,
  Instance=Instance,Enum=Enum,task=task,TweenInfo=TweenInfo},{__index=getfenv(0)}))
 return chunk()
end
modules.ClubMusicConfig=load('ClubMusicConfig')
local Music=load('ClubMusicPlaylist')
check(type(Music.start)=='function','real playlist controller must exist')
local player=Instance.new('Player')
local controller=Music.start(player,{mode='lobby'})
local root=sounds:FindFirstChild('SpyClubPlaylist')
check(root~=nil,'one managed music root exists')
local audio=root:FindFirstChild('ClubMusic')
local gain=root:FindFirstChild('ClubMusicGain')
check(audio.IsPlaying and audio.Looped==false,'playlist plays finite tracks instead of looping one song forever')
local first=audio.SoundId
audio.Ended:Fire()
check(audio.SoundId~=first and audio.IsPlaying,'end advances to a different real configured track')
check(audio:GetAttribute('SpyAudioCategory')=='Music','saved Music setting owns base sound volume')
local base=audio.Volume
player:SetAttribute('SpyEntryActive',true)
check(not audio.IsPlaying and gain.Volume==0,'entry music can take over without duplicate club playback')
player:SetAttribute('SpyEntryActive',false)
check(audio.IsPlaying,'playlist resumes after entry closes')
player:SetAttribute('SpyPhoneActive',true)
check(gain.Volume<1 and audio.Volume==base,'ducking does not corrupt saved volume scaling')
check(Music.start(player,{mode='lobby'})==controller,'repeat startup does not add another player or playlist')
controller:Destroy()
check(sounds:FindFirstChild('SpyClubPlaylist')==nil,'destroy removes managed playback')
failing['rbxassetid://'..tostring(modules.ClubMusicConfig.Tracks[1])]=true
local recovered=Music.start(player,{mode='lobby'})
local replacement=sounds:FindFirstChild('SpyClubPlaylist'):FindFirstChild('ClubMusic')
check(replacement.IsPlaying and replacement.SoundId~='rbxassetid://'..tostring(modules.ClubMusicConfig.Tracks[1]),'unavailable asset is skipped without a silent permanent lock')
recovered:Destroy()
events.DescendantAdded=true
local matchGui=Instance.new('ScreenGui')
local setup=assert(loadstring(Sources.MatchAudioSetup,'MatchIntro audio setup'))
setfenv(setup,setmetatable({SoundService=sounds,Instance=Instance,Enum=Enum,task=task,playerGui=matchGui,
 ClientPreferences={get=function()return{musicVolume=1,sfxVolume=1}end,Changed=signal()}},{__index=getfenv(0)}))
setup()
local matchController=Music.start(player,{mode='match'})
local musicCount,sfxCount=0,0
for _,sound in ipairs(sounds:GetDescendants())do
 if sound.ClassName=='Sound'then
  if sound:GetAttribute('SpyAudioCategory')=='Music'then musicCount+=1 else sfxCount+=1 end
 end
end
check(musicCount==1,'actual match audio setup and playlist have exactly one background music owner')
check(sfxCount==6,'match click, cards, phase, reveal and voting audio remain available')
check(sounds:FindFirstChild('SpyClubPlaylist'):FindFirstChild('ClubMusic').Volume==modules.ClubMusicConfig.MatchVolume,'match uses quiet configured playlist volume')
matchController:Destroy()
print('Club music: '..checks..' assertions passed (delivery/playback stubbed)')
