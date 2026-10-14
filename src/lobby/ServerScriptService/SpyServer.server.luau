local bootTarget=game:GetService("ReplicatedStorage")
bootTarget:SetAttribute("SpyLobbyBootStatus","starting")
bootTarget:SetAttribute("SpyBuild","V134_CLUB_UI")
local bootOK,bootError=xpcall(function()
-- SPY_ADMIN_CORE_V503
local SpyAdminCore = (function()
    local PlayersService = game:GetService("Players")
    local ReplicatedStorageService = game:GetService("ReplicatedStorage")
    local RunServiceService = game:GetService("RunService")
    local TextServiceService = game:GetService("TextService")
    local sharedFolder = ReplicatedStorageService:WaitForChild("SpyShared")
    local remote = sharedFolder:FindFirstChild("AdminCommand")
    if remote and not remote:IsA("RemoteEvent") then remote:Destroy(); remote=nil end
    if not remote then remote=Instance.new("RemoteEvent"); remote.Name="AdminCommand"; remote.Parent=sharedFolder end
    local broadcast = sharedFolder:FindFirstChild("SpyBroadcast")
    if broadcast and not broadcast:IsA("RemoteEvent") then broadcast:Destroy(); broadcast=nil end
    if not broadcast then broadcast=Instance.new("RemoteEvent"); broadcast.Name="SpyBroadcast"; broadcast.Parent=sharedFolder end

    local creatorUserId=nil
    local studioOwnerUserId=nil
    local startedAt=os.time()
    local frozen={}
    local rateBuckets={}

    local function resolveStudioOwner()
        if studioOwnerUserId~=nil then return studioOwnerUserId end
        local current=PlayersService:GetPlayers()
        if #current>0 then studioOwnerUserId=current[1].UserId end
        return studioOwnerUserId
    end
    local function isCreator(p)
        if not p then return false end
        if RunServiceService:IsStudio() then return p.UserId==studioOwnerUserId end
        if game.CreatorType==Enum.CreatorType.User and type(game.CreatorId)=="number" and game.CreatorId>0 and p.UserId==game.CreatorId then return true end
        if creatorUserId and p.UserId==creatorUserId then return true end
        return false
    end
    local function stamp(p)
        local yes=isCreator(p)
        p:SetAttribute("SpyStaffRole",yes and "creator" or nil)
        p:SetAttribute("SpyIsAdmin",yes)
    end
    PlayersService.PlayerAdded:Connect(function(p)
        if RunServiceService:IsStudio() and studioOwnerUserId==nil then studioOwnerUserId=p.UserId end
        stamp(p)
    end)
    PlayersService.PlayerRemoving:Connect(function(p)
        rateBuckets[p.UserId]=nil; frozen[p.UserId]=nil
        if RunServiceService:IsStudio() and studioOwnerUserId==p.UserId then studioOwnerUserId=nil end
    end)
    if RunServiceService:IsStudio() then resolveStudioOwner() end
    for _,p in ipairs(PlayersService:GetPlayers()) do stamp(p) end
    sharedFolder:SetAttribute("SpyAdminIdentityState", "ready")
    if not RunServiceService:IsStudio() and game.CreatorType==Enum.CreatorType.Group then
        sharedFolder:SetAttribute("SpyAdminIdentityState", "waiting_group_owner")
        task.spawn(function()
            for attempt=1,3 do
                local ok,info=pcall(function() return game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId) end)
                local owner=ok and type(info)=="table" and info.Owner
                if type(owner)=="table" and type(owner.Id)=="number" and owner.Id>0 then
                    creatorUserId=owner.Id
                    sharedFolder:SetAttribute("SpyAdminIdentityState", "ready")
                    for _,p in ipairs(PlayersService:GetPlayers()) do stamp(p) end
                    return
                end
                if attempt<3 then task.wait(2^attempt) end
            end
            sharedFolder:SetAttribute("SpyAdminIdentityState", "failed_group_owner")
            warn("SPY_ADMIN group owner unavailable; permissions remain closed")
        end)
    end

    local function allowedRate(p)
        local now=os.clock(); local bucket=rateBuckets[p.UserId] or {}; rateBuckets[p.UserId]=bucket
        for i=#bucket,1,-1 do if now-bucket[i]>2 then table.remove(bucket,i) end end
        if #bucket>=8 then return false end
        table.insert(bucket,now); return true
    end
    local function reply(p,command,requestId,ok,code,data)
        if p and p.Parent==PlayersService then
            remote:FireClient(p,{type="receipt",command=command,requestId=requestId,ok=ok==true,code=code or (ok and "ok" or "error"),data=data})
        end
    end
    local function log(actor,target,command,result)
        print("SPY_ADMIN",actor and actor.UserId or 0,target and target.UserId or 0,command,result)
    end
    local function targetOf(payload)
        local id=payload and payload.targetUserId
        if type(id)~="number" or id%1~=0 then return nil,"bad_target" end
        local p=PlayersService:GetPlayerByUserId(id)
        if not p then return nil,"target_left" end
        return p
    end
    local function roots(p,allowDead)
        local c=p and p.Character
        local root=c and c:FindFirstChild("HumanoidRootPart")
        local hum=c and c:FindFirstChildOfClass("Humanoid")
        if not root or not hum or ((not allowDead) and hum.Health<=0) then return nil,nil end
        return root,hum
    end
    local function filterText(actor,text,maxLen)
        if type(text)~="string" then return nil,"bad_text" end
        text=string.gsub(text,"^%s+",""); text=string.gsub(text,"%s+$","")
        local length=utf8.len(text)
        if not length or length<1 or length>maxLen then return nil,"bad_text" end
        local ok,res=pcall(function()
            return TextServiceService:FilterStringAsync(text,actor.UserId):GetNonChatStringForBroadcastAsync()
        end)
        if not ok or type(res)~="string" then return nil,RunServiceService:IsStudio() and "filter_unavailable_in_studio" or "filter_failed" end
        return res
    end
    local function roster()
        local out={}
        for _,p in ipairs(PlayersService:GetPlayers()) do
            local _,hum=roots(p,true)
            out[#out+1]={
                displayName=p.DisplayName, username=p.Name, userId=p.UserId,
                level=tonumber(p:GetAttribute("SpyLevel")) or 1,
                coins=tonumber(p:GetAttribute("SpyCoins")) or 0,
                staffRole=p:GetAttribute("SpyStaffRole"),
                muted=p:GetAttribute("SpyAdminMuted")==true,
                alive=hum~=nil and hum.Health>0,
                health=hum and math.floor(hum.Health+0.5) or 0,
                maxHealth=hum and math.floor(hum.MaxHealth+0.5) or 0,
            }
        end
        table.sort(out,function(a,b)
            local ca=a.staffRole=="creator"; local cb=b.staffRole=="creator"
            if ca~=cb then return ca end
            return string.lower(a.displayName)<string.lower(b.displayName)
        end)
        return out
    end
    local function serverInfo(placeName)
        return {
            place=placeName,
            uptime=math.max(0,os.time()-startedAt),
            playerCount=#PlayersService:GetPlayers(),
            maxPlayers=PlayersService.MaxPlayers,
            placeId=game.PlaceId,
            jobId=game.JobId,
            studio=RunServiceService:IsStudio(),
        }
    end

    local EARLY={list=true,diagnostics=true,["goto"]=true,bring=true,freeze=true,unfreeze=true,heal=true,kill=true,respawn=true,kick=true,warning=true,announce=true}
    remote.OnServerEvent:Connect(function(actor,payload)
        if type(payload)~="table" then return end
        local command=payload.command
        if type(command)~="string" or not EARLY[command] then return end
        local requestId=payload.requestId
        if actor:GetAttribute("SpyIsAdmin")~=true then reply(actor,command,requestId,false,"denied"); log(actor,nil,command,"denied"); return end
        if not allowedRate(actor) then reply(actor,command,requestId,false,"rate_limited"); return end
        if command=="diagnostics" then
            local r=ReplicatedStorageService
            reply(actor,command,requestId,true,"ok",{
                creatorId=game.CreatorId,creatorType=tostring(game.CreatorType),placeId=game.PlaceId,
                build=r:GetAttribute("SpyBuild") or "unknown",identity=sharedFolder:GetAttribute("SpyAdminIdentityState"),
                lobby=r:GetAttribute("SpyLobbyBootStatus"),lobbyError=r:GetAttribute("SpyLobbyBootStatusError"),
                session=r:GetAttribute("SpySessionBootStatus"),sessionError=r:GetAttribute("SpySessionBootStatusError"),
                round=r:GetAttribute("SpyRoundBootStatus"),roundError=r:GetAttribute("SpyRoundBootStatusError"),
                lobbyChat=actor:GetAttribute("SpyLobbyChatState"),lobbyChatDetail=actor:GetAttribute("SpyLobbyChatDetail"),
                matchChat=actor:GetAttribute("SpyMatchChatState"),matchChatDetail=actor:GetAttribute("SpyMatchChatDetail"),
                chatTransport=r:GetAttribute("SpyChatTransport"),relayChat=actor:GetAttribute("SpyRelayChatState"),relayChatDetail=actor:GetAttribute("SpyRelayChatDetail"),
            })
            return
        end
        if command=="list" then
            reply(actor,command,requestId,true,"ok",{players=roster(),server=serverInfo("lobby")})
            return
        end
        if command=="announce" then
            local text,err=filterText(actor,payload.text,180); if not text then reply(actor,command,requestId,false,err); return end
            broadcast:FireAllClients({kind="announcement",text=text,from=actor.DisplayName,at=os.time()}); reply(actor,command,requestId,true,"announced"); log(actor,nil,command,"ok"); return
        end
        local target,terr=targetOf(payload); if not target then reply(actor,command,requestId,false,terr); return end
        if command=="goto" or command=="bring" then
            local ar=roots(actor); local tr=roots(target); if not ar or not tr then reply(actor,command,requestId,false,"character_unavailable"); return end
            if command=="goto" then ar.CFrame=tr.CFrame*CFrame.new(3,0,0) else tr.CFrame=ar.CFrame*CFrame.new(3,0,0) end
            reply(actor,command,requestId,true,"ok"); log(actor,target,command,"ok"); return
        elseif command=="freeze" then
            local root,hum=roots(target); if not root then reply(actor,command,requestId,false,"character_unavailable"); return end
            if not frozen[target.UserId] then frozen[target.UserId]={anchored=root.Anchored,autoRotate=hum.AutoRotate} end
            root.Anchored=true; hum.AutoRotate=false; reply(actor,command,requestId,true,"frozen"); log(actor,target,command,"ok"); return
        elseif command=="unfreeze" then
            local state=frozen[target.UserId]; local root,hum=roots(target,true)
            if state and root and hum then root.Anchored=state.anchored; hum.AutoRotate=state.autoRotate end
            frozen[target.UserId]=nil; reply(actor,command,requestId,true,"unfrozen"); log(actor,target,command,"ok"); return
        elseif command=="heal" then
            local _,hum=roots(target,true); if not hum then reply(actor,command,requestId,false,"character_unavailable"); return end
            hum.Health=hum.MaxHealth; reply(actor,command,requestId,true,"healed"); log(actor,target,command,"ok"); return
        elseif command=="kill" then
            local _,hum=roots(target,true); if not hum then reply(actor,command,requestId,false,"character_unavailable"); return end
            hum.Health=0; reply(actor,command,requestId,true,"killed"); log(actor,target,command,"ok"); return
        elseif command=="respawn" then
            target:LoadCharacter(); reply(actor,command,requestId,true,"respawned"); log(actor,target,command,"ok"); return
        elseif command=="warning" then
            local text,err=filterText(actor,payload.text,180); if not text then reply(actor,command,requestId,false,err); return end
            broadcast:FireClient(target,{kind="warning",text=text,from=actor.DisplayName,at=os.time()}); reply(actor,command,requestId,true,"sent"); log(actor,target,command,"ok"); return
        elseif command=="kick" then
            local reason=payload.reason
            if type(reason)~="string" or reason=="" then reason="Removed by SPY CLUB staff" end
            local safe,err=filterText(actor,reason,120); if not safe then reply(actor,command,requestId,false,err); return end
            reply(actor,command,requestId,true,"kicked"); log(actor,target,command,"ok"); target:Kick(safe); return
        end
    end)
    sharedFolder:SetAttribute("SpyAdminCoreReady",true)
    print("SPY_ADMIN_CORE_READY","LOBBY",RunServiceService:IsStudio())
    return {remote=remote,broadcast=broadcast,reply=reply,log=log,targetOf=targetOf,serverInfo=serverInfo,filterText=filterText}
end)()


-- SPY CLUB PREMIUM SHOP V1 :: SpyServer
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
-- Spawn with the house outfit already in the HumanoidDescription. This must
-- run before PlayerAdded, otherwise the default empty Roblox rig can flash.
Players.CharacterAutoLoads = false
pcall(function() StarterPlayer.LoadCharacterAppearance = false end)
local shared = ReplicatedStorage:WaitForChild("SpyShared")
-- Lobby-wide free text uses one dedicated TextChannel. Roblox owns filtering,
-- privacy, blocked-user handling and regional/account eligibility. Private table
-- channels below remain isolated.
local channelFolder = TextChatService:FindFirstChild("TextChannels")
if not channelFolder then
	channelFolder = Instance.new("Folder")
	channelFolder.Name, channelFolder.Parent = "TextChannels", TextChatService
end

local LOBBY_GLOBAL_CHANNEL = "SpyLobbyGlobal"
local lobbyGlobalChannel = channelFolder:FindFirstChild("RBXGeneral") or channelFolder:FindFirstChild(LOBBY_GLOBAL_CHANNEL)
if lobbyGlobalChannel and not lobbyGlobalChannel:IsA("TextChannel") then
	lobbyGlobalChannel:Destroy()
	lobbyGlobalChannel = nil
end
if not lobbyGlobalChannel then
	lobbyGlobalChannel = Instance.new("TextChannel")
	lobbyGlobalChannel.Name = LOBBY_GLOBAL_CHANNEL
	lobbyGlobalChannel.Parent = channelFolder
end

ReplicatedStorage:SetAttribute("SpyChatChannelName", lobbyGlobalChannel.Name)

local LOBBY_GLOBAL_MAX = 180
local LOBBY_GLOBAL_COOLDOWN = 0.75
local lobbyGlobalLastSent = {}
local lobbyGlobalMessagePermissions = {}

local function lobbyGlobalMessageAllowed(message)
	if not message or not message.TextSource then return false end
	local senderId = message.TextSource.UserId
	local sender = Players:GetPlayerByUserId(senderId)
	if not sender or sender:GetAttribute("SpyAdminMuted") == true then return false end

	local messageId = tostring(message.MessageId or "")
	if messageId ~= "" and lobbyGlobalMessagePermissions[messageId] ~= nil then
		return lobbyGlobalMessagePermissions[messageId]
	end

	local text = tostring(message.Text or "")
	local length = utf8.len(text)
	local nowClock = os.clock()
	local allowed = length ~= nil and length > 0 and length <= LOBBY_GLOBAL_MAX
		and nowClock - (lobbyGlobalLastSent[senderId] or -1000) >= LOBBY_GLOBAL_COOLDOWN

	if allowed then lobbyGlobalLastSent[senderId] = nowClock end
	if messageId ~= "" then
		lobbyGlobalMessagePermissions[messageId] = allowed
		task.delay(20, function() lobbyGlobalMessagePermissions[messageId] = nil end)
	end
	return allowed
end

local function lobbyGlobalDelivery(message, target)
	if ReplicatedStorage:GetAttribute("SpyChatTransport") == "server_filtered" then return false end
	if not message or (message.TextChannel and message.TextChannel ~= lobbyGlobalChannel) then return false end
	if not target then return false end
	local receiver = Players:GetPlayerByUserId(target.UserId)
	local sender = message.TextSource and Players:GetPlayerByUserId(message.TextSource.UserId)
	if not receiver or not sender then return false end
	-- Players seated at a table use its channel and phase/turn gates.
	if (sender:GetAttribute("SpyRelayTableId") or "") ~= ""
		or (receiver:GetAttribute("SpyRelayTableId") or "") ~= "" then return false end
	return lobbyGlobalMessageAllowed(message)
end

lobbyGlobalChannel.ShouldDeliverCallback = lobbyGlobalDelivery

local lobbyChatSourceConnections = {}
local lobbyChatEnrollGeneration = {}
local lobbyChatEnrollBusy = {}

local function setLobbyChatState(player, stateName, ready, detail)
	if player.Parent ~= Players then return end
	if player:GetAttribute("SpyLobbyChatState") ~= stateName or player:GetAttribute("SpyLobbyChatDetail") ~= tostring(detail or "") then
		print("[SPY CHAT SERVER] Lobby channel=" .. lobbyGlobalChannel.Name .. " state=" .. stateName .. " eligibility=" .. tostring(player:GetAttribute("SpyChatEligibility") or "pending") .. " detail=" .. tostring(detail or ""))
	end
	player:SetAttribute("SpyLobbyChatState", stateName)
	player:SetAttribute("SpyLobbyChatReady", ready == true)
	player:SetAttribute("SpyLobbyChatDetail", tostring(detail or ""))
end

local function findLobbyChatSource(userId)
	for _, child in ipairs(lobbyGlobalChannel:GetChildren()) do
		if child:IsA("TextSource") and child.UserId == userId then return child end
	end
	return nil
end

local function applyLobbyChatPermission(player, source)
	if player.Parent ~= Players or not source or not source.Parent then return end
	-- Diagnostic mode: the server records TextSource state, but the client is
	-- allowed to call TextChannel:SendAsync and read Roblox's final status.
	if player:GetAttribute("SpyAdminMuted") == true then
		setLobbyChatState(player, "blocked", false, "muted")
	elseif source.CanSend == true then
		setLobbyChatState(player, "ready", true, "")
	else
		setLobbyChatState(player, "ready", false, "TextSource.CanSend=false; SendAsync probe enabled")
	end
end

local function observeLobbyChatSource(player, source)
	local previous = lobbyChatSourceConnections[player.UserId]
	if previous then previous:Disconnect() end
	lobbyChatSourceConnections[player.UserId] = nil
	if not source or not source.Parent then return end
	source:SetAttribute("SpyChatUserId",player.UserId)
	local function refresh() applyLobbyChatPermission(player, source) end
	local connections = {source:GetPropertyChangedSignal("CanSend"):Connect(refresh),
		player:GetAttributeChangedSignal("SpyAdminMuted"):Connect(refresh)}
	lobbyChatSourceConnections[player.UserId] = {Disconnect=function()
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end}
	applyLobbyChatPermission(player, source)
end

local function ensureLobbyGlobalChatSource(player)
	if player.Parent ~= Players or lobbyChatEnrollBusy[player.UserId] then return end
	local generation = (lobbyChatEnrollGeneration[player.UserId] or 0) + 1
	lobbyChatEnrollGeneration[player.UserId] = generation
	lobbyChatEnrollBusy[player.UserId] = generation
	local function current()
		return player.Parent == Players and lobbyChatEnrollGeneration[player.UserId] == generation
	end
	-- Do not call CanUserChatAsync here. Enrollment + SendAsync are the probe.
	player:SetAttribute("SpyChatEligibility", "send_async_probe")
	setLobbyChatState(player, "connecting", false, "enrolling_without_precheck")
	task.delay(15, function()
		if current() and lobbyChatEnrollBusy[player.UserId] == generation then
			lobbyChatEnrollGeneration[player.UserId] = generation + 1
			lobbyChatEnrollBusy[player.UserId] = nil
			setLobbyChatState(player, "failed", false, "enrollment_timeout")
		end
	end)
	task.spawn(function()
		for attempt = 1, 5 do
			if not current() then return end
			local source = findLobbyChatSource(player.UserId)
			local ok = source ~= nil
			if not source then ok, source = pcall(function() return lobbyGlobalChannel:AddUserAsync(player.UserId) end) end
			if not current() then return end
			if ok and source then
				lobbyChatEnrollBusy[player.UserId] = nil
				observeLobbyChatSource(player, source)
				return
			end
			warn("SpyClub: Lobby TextChannel enrollment attempt " .. attempt .. "/5 failed for " .. player.Name)
			if attempt < 5 then task.wait(0.8 * attempt) end
		end
		if not current() then return end
		lobbyChatEnrollBusy[player.UserId] = nil
		setLobbyChatState(player, "failed", false, "TextChannel enrollment failed; SendAsync may still report the exact client status")
	end)
end

-- Prefer the engine's standard group channel. Selection is made on the
-- server at startup/replication, never in response to a rejected message.
local function observeDefaultChatChannel(candidate)
	if not candidate:IsA("TextChannel") then return end
	if candidate.Name ~= "RBXGeneral" then
		-- Unused default channels must not bypass match phases or admin mute.
		if candidate.Name:sub(1,3) == "RBX" then candidate.ShouldDeliverCallback = function() return false end end
		return
	end
	if candidate == lobbyGlobalChannel then return end
	lobbyGlobalChannel = candidate
	candidate.ShouldDeliverCallback = lobbyGlobalDelivery
	ReplicatedStorage:SetAttribute("SpyChatChannelName", candidate.Name)
	for _, chatPlayer in ipairs(Players:GetPlayers()) do
		lobbyChatEnrollGeneration[chatPlayer.UserId] = (lobbyChatEnrollGeneration[chatPlayer.UserId] or 0) + 1
		lobbyChatEnrollBusy[chatPlayer.UserId] = nil
		local connection = lobbyChatSourceConnections[chatPlayer.UserId]
		if connection then connection:Disconnect();lobbyChatSourceConnections[chatPlayer.UserId] = nil end
		task.spawn(ensureLobbyGlobalChatSource, chatPlayer)
	end
end
channelFolder.ChildAdded:Connect(observeDefaultChatChannel)
for _, candidate in ipairs(channelFolder:GetChildren()) do observeDefaultChatChannel(candidate) end

-- Chat starts before scene/economy dependencies. No user text crosses this remote.
local earlyChatAction=shared:FindFirstChild("Action") or Instance.new("RemoteEvent")
earlyChatAction.Name,earlyChatAction.Parent="Action",shared
Players.PlayerAdded:Connect(function(player) task.spawn(ensureLobbyGlobalChatSource,player) end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(ensureLobbyGlobalChatSource,player) end
earlyChatAction.OnServerEvent:Connect(function(player,action)
 if action~="ChatRetry" then return end
 local last=player:GetAttribute("SpyChatRetryAt") or -1000
 if os.clock()-last<5 then return end
 player:SetAttribute("SpyChatRetryAt",os.clock())
 task.spawn(ensureLobbyGlobalChatSource,player)
end)
Players.PlayerRemoving:Connect(function(player)
 local connection=lobbyChatSourceConnections[player.UserId]
 if connection then connection:Disconnect() end
 lobbyChatSourceConnections[player.UserId]=nil
 lobbyChatEnrollGeneration[player.UserId]=(lobbyChatEnrollGeneration[player.UserId] or 0)+1
 lobbyChatEnrollBusy[player.UserId]=nil
 lobbyGlobalLastSent[player.UserId]=nil
end)

local modules = ServerStorage:WaitForChild("SpyModules")
local Config = require(shared.Config)
local studioSimulation = RunService:IsStudio() and Config.StudioNoChatSimulation == true
local Rules = require(modules.Rules)
local Words = require(modules.Words)
local World = require(modules.World)
local refs = World.build(Config) -- Bind baked geometry before optional data services.
local Profiles = require(modules.Profiles)
local profiles = Profiles.new()
-- Reconnect storage is optional for joining Lobby and is never opened at boot.
local RewardRecovery
local Voting = require(modules.Voting)
local CharacterService = require(modules.CharacterService)
local Cosmetics = require(modules.Cosmetics)
local spawning = {}
local function spawnCanonical(player)
	if player.Parent ~= Players or spawning[player] then return end
	spawning[player] = true
	local description = CharacterService.createDescription()
	player:SetAttribute("SpySpawnWithDescription", true)
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescriptionAsync(description)
	end)
	description:Destroy()
	if ok and player.Character then
		player.Character:SetAttribute("SpySpawnAppearanceReady", true)
	end
	if not ok and player.Parent == Players then
		player:SetAttribute("SpySpawnWithDescription", false)
		warn("SpyClub: dressed spawn failed for " .. player.Name .. ": " .. tostring(err))
		pcall(function() player:LoadCharacter() end)
	end
	spawning[player] = nil
end
local Leaderboards = {refresh=function() end}
task.spawn(function()
 local ok,value=pcall(function() return require(modules.Leaderboards) end)
 if ok and type(value)=="table" and type(value.refresh)=="function" then
  Leaderboards=value
  pcall(value.refresh,profiles)
 else warn("SpyClub: optional global leaderboards unavailable") end
end)
local HighStakes = require(modules.HighStakes)
local serverId = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)
local gateAccess={
	refresh=function(_,player)
		if player then player:SetAttribute("HighStakesRoomAccess",false) end
	end,
	connectPlayer=function(self,player) self:refresh(player) end,
	removePlayer=function(self,player) self:refresh(player) end,
}
local function updateHighStakesCollision(player)
	gateAccess:refresh(player)
end

local stateEvent = shared:FindFirstChild("State") or Instance.new("RemoteEvent")
stateEvent.Name, stateEvent.Parent = "State", shared
local actionEvent = shared:FindFirstChild("Action") or Instance.new("RemoteEvent")
actionEvent.Name, actionEvent.Parent = "Action", shared
local noticeEvent = shared:FindFirstChild("Notice") or Instance.new("RemoteEvent")
noticeEvent.Name, noticeEvent.Parent = "Notice", shared
local profileEvent = shared:FindFirstChild("Profile") or Instance.new("RemoteEvent")
profileEvent.Name, profileEvent.Parent = "Profile", shared
local economyAction = shared:FindFirstChild("EconomyAction") or Instance.new("RemoteEvent")
economyAction.Name, economyAction.Parent = "EconomyAction", shared
local feedbackBook = shared:FindFirstChild("FeedbackBook") or Instance.new("RemoteEvent")
feedbackBook.Name, feedbackBook.Parent = "FeedbackBook", shared
local lobbyChatSend = shared:FindFirstChild("LobbyChatSend") or Instance.new("RemoteEvent")
lobbyChatSend.Name, lobbyChatSend.Parent = "LobbyChatSend", shared
local lobbyChatReceive = shared:FindFirstChild("LobbyChatReceive") or Instance.new("RemoteEvent")
lobbyChatReceive.Name, lobbyChatReceive.Parent = "LobbyChatReceive", shared

-- Compatibility endpoint kept for older clients; user conversation is delivered
-- exclusively by TextChannel, including the preset phrase buttons.
local quickChat = shared:FindFirstChild("SpyQuickChat") or Instance.new("RemoteEvent")
quickChat.Name, quickChat.Parent = "SpyQuickChat", shared

local feedbackOpenAt = {}
local economyBusy, economyTime = {}, {}
local requestCooldown = {
	capsule = 0.8,
	accessoryRoll = .65,
	rollPromo = 1,
	equip = 0.25,
	buy = 0.5,
	sell = 0.6,
	onboarding = 1.0,
	useGadget = 0.5,
	daily = 0.8,
	language = 0.25,
	settings = 0.5,
	vincentAccept = 1,
	vincentClaim = 1,
	retry = 2,
}

local function syncPublicProfile(player,profile)
	if player.Parent~=Players then return end
	local ready=profile and profile.ready==true
	player:SetAttribute("SpyProfileReady",ready)
	player:SetAttribute("SpyLevel",ready and math.max(1,math.floor(profile.level or 1)) or 1)
	player:SetAttribute("SpyXP",ready and math.max(0,math.floor(profile.xp or 0)) or 0)
	player:SetAttribute("SpyCoins",ready and math.max(0,math.floor(profile.coins or 0)) or 0)
	player:SetAttribute("SpyRolls",ready and math.max(0,math.floor(profile.rolls or 0)) or 0)
	player:SetAttribute("SpyRank",ready and tostring(profile.rank or "Гость") or "Гость")
	player:SetAttribute("SpyRankShort",ready and tostring(profile.rankShort or "ГОСТЬ") or "ГОСТЬ")
	player:SetAttribute("SpyRankIndex",ready and math.clamp(math.floor(profile.rankIndex or 1),1,10) or 1)
	local equipped = ready and (profile.equipped or {}) or {}
	player:SetAttribute("SpyTitle", tostring(equipped.title or ""))
	player:SetAttribute("SpyFrame", tostring(equipped.frame or ""))
	player:SetAttribute("SpyEffect", tostring(equipped.effect or ""))
	player:SetAttribute("SpyEquippedOutfit", tostring(equipped.outfit or ""))
	player:SetAttribute("SpyEquippedHat", tostring(equipped.hat or ""))
	player:SetAttribute("SpyEquippedHair", tostring(equipped.hair or ""))
	player:SetAttribute("SpyEquippedGlasses", tostring(equipped.glasses or ""))
	player:SetAttribute("SpyEquippedTie", tostring(equipped.tie or ""))
	player:SetAttribute("SpyEquippedGloves", tostring(equipped.gloves or ""))
	player:SetAttribute("SpyEquippedShoulder", tostring(equipped.shoulder or ""))
	player:SetAttribute("SpyEquippedCard", tostring(equipped.card or "classic"))
	player:SetAttribute("SpyEquippedTrinket", tostring(equipped.trinket or ""))
	player:SetAttribute("SpyLanguage", ready and tostring(profile.language or "ru") or "ru")
end

local function changed(player,receipt,requestId)
	if player.Parent ~= Players then return end
	local profile=profiles:public(player.UserId,true)
	syncPublicProfile(player,profile)
	profileEvent:FireClient(player,profile,receipt,requestId)
	pcall(Leaderboards.refresh,profiles)
	pcall(Cosmetics.apply,player,profile)
	pcall(updateHighStakesCollision,player)
end
-- Optional solo archive reuses this exact Profiles instance; never part of boot readiness.
task.defer(function()
    local billiards=ServerStorage.SpyModules:FindFirstChild("BilliardsService")
    if billiards then pcall(function()require(billiards).attachProfiles(profiles,changed)end)end
    local comms=ServerStorage.SpyModules:FindFirstChild("PhoneCommsService")
    if comms then pcall(function()require(comms).attachProfiles(profiles)end)end
    local module=ServerStorage.SpyModules:FindFirstChild("CaseService")
    if module then local ok,err=pcall(function()require(module).start(profiles,function(p)
        changed(p)
    end)end);if not ok then warn("SpyClub: case archive unavailable",err)end end
    local phonePersonal=ServerStorage.SpyModules:FindFirstChild("PhonePersonalService")
    if phonePersonal then local ok,err=pcall(function()require(phonePersonal).start(profiles)end)
        if not ok then warn("SpyClub: phone notes unavailable",err)end end
end)
local publish, startTable, leaveTable
local tables, membership, joining, limits, locked = {}, {}, {}, {}, {}
local monetization
task.spawn(function()
 local ok,value=pcall(function() return require(modules.Monetization).new(profiles,changed,{
  canPrompt=function(player)
   local current=membership[player.UserId]
   return not player:GetAttribute("SpyTeleporting") and not player:GetAttribute("SpyEntryPending")
    and not player:GetAttribute("SpyEntryActive") and not player:GetAttribute("SpyTradeOpen")
    and not player:GetAttribute("SpyPhoneActive")
    and (not current or current.phase=="Waiting" or current.phase=="Result")
  end,
 }) end)
 if ok then
  monetization=value
  task.defer(function() if publish then publish() end end)
  for _,player in ipairs(Players:GetPlayers()) do
   if profiles:public(player.UserId).ready then task.spawn(function() monetization:sync(player) end) end
  end
 else warn("SpyClub: optional monetization unavailable: "..tostring(value)) end
end)

local Catalog=require(shared.Catalog)
local tradeService
local rollService=require(modules.AccessoryRollService).new(profiles,{
    hasLuck=function(player) return monetization and monetization:hasEntitlement(player,"case_luck_2x") or false end,
    canSpendPaidRolls=function(player) return monetization and monetization:canSpendPaidRolls(player) or false end,
    isTrading=function(player) return tradeService and tradeService.byUser[player.UserId]~=nil or false end,
})
local originalPublic=profiles.public
function profiles:public(userId,...)
    local profile=originalPublic(self,userId,...)
    local player=Players:GetPlayerByUserId(userId)
    profile.accessoryRoll=player and rollService:snapshot(player,profile) or {sequence=profile.rollSequence or 0,categories={}}
    profile.rollShop=player and monetization and monetization:shopFor(player,profile) or {ready=false,offers={}}
    return profile
end
task.spawn(function()
 local ok,err=pcall(function()
  local module=modules:FindFirstChild("TradeService")
  if not module then return end
  tradeService=require(module).attach(profiles,Catalog,function(uid)
   local player=Players:GetPlayerByUserId(uid)
   if player then
    changed(player,{ok=true,code="trade_updated"})
    local t=membership[uid]
    if t and refs[t.id] then World.applyCosmetics(refs[t.id],{seat=t.seats[uid],equipped=profiles:public(uid).equipped},uid) end
   end
  end,function(player)
   local t=membership[player.UserId]
   return player:GetAttribute("SpyTeleporting")~=true and not economyBusy[player.UserId] and not rollService.busy[player.UserId]
    and (not t or t.phase=="Waiting" or t.phase=="Result")
  end)
 end)
 shared:SetAttribute("SpyTradeBootStatus",ok and "ready" or "failed")
 if not ok then warn("SpyClub trade boot: "..tostring(err)) end
end)

local random = Random.new()
local I18n=require(shared.I18n)
local phaseLabels = {Waiting="Waiting",Countdown="Countdown",Role="Role",Hint="Hint",Discuss="Discuss",Vote="Vote",Result="Result"}
local function now() return workspace:GetServerTimeNow() end
local function tell(player, message)
	if player.Parent == Players then noticeEvent:FireClient(player, message) end
end
task.spawn(function()
 local ok,err=pcall(function() require(modules.FeedbackService).start(profiles,shared,feedbackOpenAt) end)
 if not ok then warn("SpyClub developer inbox: "..tostring(err)) end
end)

local function lobbyList()
	local result = {}
	for _, def in ipairs(Config.Tables) do
		local t = tables[def.id]
		result[#result + 1] = {id = t.id, title = t.title, count = #t.players, capacity = t.capacity, phase = t.phase, highStakes=t.highStakes}
	end
	return result
end

local function makeState(player, lobby)
	local t = membership[player.UserId]
	local state = {lobby = lobby, studioSimulation = studioSimulation, profile = profiles:public(player.UserId,true),monetization=monetization and monetization:offersFor(player) or {}}
	if not t then return state end
	local people = {}
	for _, member in ipairs(t.players) do
		local person = {id = member.UserId, name = member.DisplayName, username = member.Name, seat = t.seats[member.UserId]}
		if t.phase == "Result" and t.result then person.voteCount = t.result.counts[member.UserId] or 0 end
		people[#people + 1] = person
	end
	state.tableId, state.title, state.capacity = t.id, t.title, t.capacity
	state.phase, state.phaseLabel, state.endAt = t.phase, phaseLabels[t.phase], t.endAt
	state.people, state.roundId = people, t.roundId
	state.runoff,state.candidates,state.highStakes=t.runoff==true,t.candidates,t.highStakes
	state.votesSubmitted=t.round and Rules.voteCount(t.round) or 0
	state.channelName = t.channel.Name
	state.turn, state.lap, state.hintLaps = t.turn, t.lap, Config.HintLaps
	if t.round then
		state.card = Rules.privateCard(t.round, player.UserId)
		state.order = t.round.order
		state.myVote = t.round.votes[player.UserId]
	end
	if t.phase == "Result" then
		state.result = {caught = t.result.caught, accusedId = t.result.accusedId, spyId = t.result.spyId, word = t.result.word, reason = t.result.reason,ballots=t.result.ballots}
	end
	return state
end

local function canSpeak(t, id)
	if membership[id] ~= t then return false end
	if t.phase == "Hint" then return t.turn == id end
	return t.phase == "Waiting" or t.phase == "Discuss" or t.phase == "Result"
end

local function syncRelayTableContext(player,t)
	player:SetAttribute("SpyRelayTableId",t and t.id or "")
	player:SetAttribute("SpyRelayTablePhase",t and t.phase or "")
	player:SetAttribute("SpyRelayTableTurn",t and t.turn or 0)
	player:SetAttribute("SpyRelayTableContext",t and table.concat({t.id,tostring(t.roundId),tostring(t.token),t.phase,tostring(t.lap or 0),tostring(t.turn or 0)},":") or "public")
end

publish = function()
	local lobby = lobbyList()
	for _, t in pairs(tables) do
		local ref = refs[t.id]
		ref.label.Text = t.title .. "  ·  " .. #t.players .. "/" .. t.capacity .. "\n" .. I18n.t("ru",phaseLabels[t.phase])
		ref.label:SetAttribute("TableId",t.id)
		ref.label:SetAttribute("TableCount",#t.players)
		ref.label:SetAttribute("TableCapacity",t.capacity)
		ref.label:SetAttribute("PhaseKey",phaseLabels[t.phase])
		ref.prompt.Enabled = t.phase == "Waiting" and #t.players < t.capacity
		local color = ref.accent
		if t.phase == "Vote" then color = Color3.fromRGB(255, 185, 109) end
		if t.phase == "Result" and t.result then
			color = t.result.caught and Color3.fromRGB(108, 241, 207) or Color3.fromRGB(255, 116, 133)
		end
		ref.glow.Color, ref.light.Color = color, color
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local t=membership[player.UserId]
		syncRelayTableContext(player,t)
		stateEvent:FireClient(player, makeState(player, lobby))
	end
end

local function lockCharacter(player, cf)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	locked[player.UserId] = {root = root, humanoid = humanoid, anchored = root.Anchored, autoRotate = humanoid.AutoRotate}
	humanoid.AutoRotate, humanoid.Sit = false, true
	root.CFrame, root.Anchored = cf, true
	return true
end

local function unlockCharacter(player,stayInRoom)
	local saved = locked[player.UserId]
	locked[player.UserId] = nil
	if not saved then return end
	if saved.humanoid.Parent then
		saved.humanoid.Sit = false
		saved.humanoid.AutoRotate = saved.autoRotate
	end
	if saved.root.Parent then
		if not stayInRoom then saved.root.CFrame = CFrame.new(0, 4, -17) end
		saved.root.Anchored = saved.anchored
	end
end

local function setPhase(t, phase, duration)
	t.phase, t.endAt = phase, now() + duration
	publish()
end

local function waitPhase(t, token, phase, duration)
	if t.token ~= token or #t.players ~= t.capacity then return false end
	setPhase(t, phase, duration)
	repeat
		task.wait(0.15)
		if t.token ~= token or #t.players ~= t.capacity then return false end
		if phase == "Vote" and Rules.voteCount(t.round) == t.capacity then break end
	until now() >= t.endAt
	return true
end

local function takeStakeLedger(t)
	local ledger=t.stakeLedger or {}
	local bank=t.bank or 0
	t.stakeLedger={}
	t.bank=0
	return ledger,bank
end

local function refundStakeEntries(entries,reason,synchronous)
	if not entries or not next(entries) then return end
	local function refund(userId,entry)
		local refundId=(entry.stakeOp or ("stake:unknown:"..tostring(userId)))..":refund:"..tostring(reason or "interrupted")
		local receipt=profiles:transact(userId,refundId,{kind="highstakesRefund"})
		local player=Players:GetPlayerByUserId(userId)
		if player then changed(player,receipt) end
	end
	for userId,entry in pairs(entries) do
		if synchronous then refund(userId,entry) else task.spawn(refund,userId,entry) end
	end
end

local function refundStakeLedger(t,reason,synchronous)
	if not t.highStakes then t.bank=0; t.stakeLedger={} return end
	local entries=takeStakeLedger(t)
	refundStakeEntries(entries,reason,synchronous)
end

local function abortHighStakesRound(t,reason)
	if t.highStakes then refundStakeLedger(t,reason or "interrupted",true) end
end

startTable = function(t)
	if t.phase ~= "Waiting" or #t.players ~= t.capacity then return end
	t.token = t.token + 1
	local token = t.token
	task.spawn(function()
		-- Free contract: no charge transaction, escrow or player-funded bank.
		if t.highStakes then t.stakeLedger={};t.bank=0 end
		if not waitPhase(t, token, "Countdown", Config.Seconds.Countdown) then abortHighStakesRound(t,"countdown_interrupted"); return end
		local ids = {}
		for _, p in ipairs(t.players) do ids[#ids + 1] = p.UserId end
		local historyById = {}
		for _, id in ipairs(ids) do historyById[id] = profiles:history(id) end
		t.round = Rules.newRound(ids, Words, function(a, b) return random:NextInteger(a, b) end, t.previousWord, historyById)
		t.previousWord, t.roundId = t.round.word, t.roundId + 1
		t.result, t.turn, t.lap = nil, nil, nil
		t.runoff,t.candidates,t.participated=false,nil,{}
		if not waitPhase(t, token, "Role", Config.Seconds.Role) then abortHighStakesRound(t,"role_interrupted"); return end
		for lap = 1, Config.HintLaps do
			t.lap = lap
			for _, id in ipairs(t.round.order) do
				t.turn = id
				if not waitPhase(t, token, "Hint", Config.Seconds.Hint) then abortHighStakesRound(t,"hint_interrupted"); return end
			end
		end
		t.turn = nil
		if not waitPhase(t, token, "Discuss", Config.Seconds.Discuss) then abortHighStakesRound(t,"discuss_interrupted"); return end
		if not waitPhase(t, token, "Vote", Config.Seconds.Vote) then abortHighStakesRound(t,"vote_interrupted"); return end
		t.result,t.candidates = Voting.finish(t.round,false,Rules)
		if t.candidates then
			for id in pairs(t.round.votes) do t.participated[id]=true end
			t.round.votes={}
			t.runoff=true
			if not waitPhase(t,token,"Vote",Config.Seconds.Revote) then abortHighStakesRound(t,"revote_interrupted"); return end
			t.result=Voting.finish(t.round,true,Rules)
		end
		local history={word=t.result.word,spyId=t.result.spyId,at=os.time(),ballots={}}
		local names={} for _,member in ipairs(t.players) do names[member.UserId]=member.DisplayName end
		for _,voterId in ipairs(t.round.order) do
			history.ballots[#history.ballots+1]={voterId=voterId,voterName=names[voterId],targetId=t.round.votes[voterId],targetName=names[t.round.votes[voterId]]}
		end
		t.result.ballots=history.ballots
		-- A completed game and an actual ballot are required for every reward.
		local rewardEligibility={}
		local eligibleWinnerCount=0
		for _,member in ipairs(t.players) do
			local userId=member.UserId
			local won=(userId==t.round.spyId)~=t.result.caught
			local participated=t.round.votes[userId]~=nil or t.participated[userId]==true
			rewardEligibility[userId]={won=won,participated=participated}
			if won and participated then eligibleWinnerCount+=1 end
		end
		local payoutById={}
		if t.highStakes then
			for _,member in ipairs(t.players)do
				local info=rewardEligibility[member.UserId]
				payoutById[member.UserId]=HighStakes.payout(info.won,info.participated)
			end
		end
		-- A completed round and a valid ballot are required. The client cannot request rewards.
		for _, member in ipairs(t.players) do
			local userId = member.UserId
			local info=rewardEligibility[userId]
			local operationId = "round:" .. serverId .. ":" .. t.id .. ":" .. t.roundId
			task.spawn(function()
				local receipt = profiles:transact(userId, operationId, {kind="reward", won=info.won, participated=info.participated,highStakes=t.highStakes,highStakesPayout=payoutById[userId] or 0,history=history})
				if member.Parent == Players then changed(member,receipt) end
			end)
		end
		if not waitPhase(t, token, "Result", Config.Seconds.Result) then abortHighStakesRound(t,"result_interrupted"); return end
		t.round, t.result, t.turn, t.lap = nil, nil, nil, nil
		t.runoff,t.candidates=false,nil
		t.bank=0
		t.phase, t.endAt = "Waiting", 0
		publish()
		startTable(t)
	end)
end

leaveTable = function(player)
	joining[player.UserId] = nil
	local t = membership[player.UserId]
	if not t then return end
	membership[player.UserId] = nil
	syncRelayTableContext(player,nil) -- Revoke chat before cosmetics/refunds can yield.
	for i, p in ipairs(t.players) do
		if p == player then table.remove(t.players, i) break end
	end
	t.seats[player.UserId] = nil
	World.applyCosmetics(refs[t.id], nil, player.UserId)
	if t.sources[player.UserId] then t.sources[player.UserId]:Destroy() end
	t.sources[player.UserId] = nil
	t.revision, t.token = t.revision + 1, t.token + 1
	local interrupted = t.phase ~= "Waiting"
	if t.highStakes and t.stakeLedger and next(t.stakeLedger) then refundStakeLedger(t,"player_left",true) end
	t.phase, t.endAt = "Waiting", 0
	t.round, t.result, t.turn, t.lap = nil, nil, nil, nil
	t.runoff,t.candidates=false,nil
	unlockCharacter(player,t.highStakes)
	if interrupted then
		for _, p in ipairs(t.players) do tell(p, "interrupted") end
	end
	publish()
end

local function closeEnough(player, t)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - refs[t.id].center).Magnitude <= Config.JoinDistance
end

local function tryJoin(player, t)
	if player:GetAttribute("SpyQuickQueueActive")or player:GetAttribute("SpyPartyMember")then return end
	if membership[player.UserId] or joining[player.UserId] or t.joinBusy then return end
	if t.phase ~= "Waiting" or #t.players >= t.capacity or not closeEnough(player, t) then return end
	local profile=profiles:public(player.UserId)
	if not profile.ready then tell(player, "profile_unavailable") return end
	if t.highStakes then
		if not profile.eligibleHighStakes then tell(player,"levelRequired") return end
		if (profile.coins or 0)<HighStakes.Stake then tell(player,"not_enough") return end
	end
	t.joinBusy, joining[player.UserId] = true, t
	local relay=ReplicatedStorage:GetAttribute("SpyChatTransport")=="server_filtered"
	local revision = t.revision
	local function release(message)
		t.joinBusy = false
		if joining[player.UserId] == t then joining[player.UserId] = nil end
		if message then tell(player, message) end
	end
	local ok, allowed = pcall(function()
		-- No TextSource is created in this offline test mode, so no chat can be sent.
		if studioSimulation then return true end
		if not relay and not TextChatService:CanUserChatAsync(player.UserId) then return false end
		for _, other in ipairs(t.players) do
			if not TextChatService:CanUsersChatAsync(player.UserId, other.UserId)
				or not TextChatService:CanUsersChatAsync(other.UserId, player.UserId) then return false end
		end
		return true
	end)
	if not ok or not allowed then
		release("incompatibleChat")
		return
	end
	local sourceOK, source = true, nil
	if not studioSimulation and not relay then
		sourceOK, source = pcall(function() return t.channel:AddUserAsync(player.UserId) end)
	end
	if not sourceOK or (not source and not studioSimulation and not relay) then
		release("deniedChat")
		return
	end
	if player.Parent ~= Players or joining[player.UserId] ~= t or membership[player.UserId]
		or player:GetAttribute("SpyQuickQueueActive")or player:GetAttribute("SpyPartyMember")
		or t.revision ~= revision or t.phase ~= "Waiting" or #t.players >= t.capacity or not closeEnough(player, t) then
		if source then source:Destroy() end
		release("tableChanged")
		return
	end
	local used = {}
	for _, seat in pairs(t.seats) do used[seat] = true end
	local seat = 1
	while used[seat] do seat = seat + 1 end
	if not lockCharacter(player, refs[t.id].seats[seat]) then
		if source then source:Destroy() end
		release("characterLoading")
		return
	end
	if source then source:SetAttribute("SpyChatUserId",player.UserId) end
	t.players[#t.players + 1], t.seats[player.UserId] = player, seat
	t.sources[player.UserId], membership[player.UserId] = source, t
	syncRelayTableContext(player,t)
	World.applyCosmetics(refs[t.id], {seat=seat, equipped=profiles:public(player.UserId).equipped}, player.UserId)
	t.revision = t.revision + 1
	release()
	publish()
	startTable(t)
end

for _, def in ipairs(Config.Tables) do
	local channel = Instance.new("TextChannel")
	channel.Name, channel.Parent = "Spy_" .. def.id, channelFolder
	local t = {
		id = def.id, title = def.title, capacity = def.capacity, channel = channel, highStakes=def.highStakes==true,
		players = {}, seats = {}, sources = {}, phase = "Waiting", endAt = 0,
		token = 0, revision = 0, roundId = 0, joinBusy = false, bank = 0, stakeLedger = {},
	}
	tables[t.id] = t
	-- Only table members receive text. Roblox filtering and privacy remain authoritative.
	-- Cache the decision for a message, so every recipient sees the same turn boundary.
	local messagePermissions, lastSent = {}, {}
	channel.ShouldDeliverCallback = function(message, target)
		if ReplicatedStorage:GetAttribute("SpyChatTransport") == "server_filtered" then return false end
		if not message.TextSource or not target then return false end
		local senderId, receiverId = message.TextSource.UserId, target.UserId
		if membership[senderId] ~= t or membership[receiverId] ~= t then return false end
		local sender = Players:GetPlayerByUserId(senderId)
		if not sender or sender:GetAttribute("SpyAdminMuted") == true then return false end
		local key = message.MessageId
		local entry = messagePermissions[key]
		if not entry then
			local accepted = canSpeak(t, senderId) and (now() - (lastSent[senderId] or 0) >= 1.2)
			if accepted then lastSent[senderId] = now() end
			entry = {allowed = accepted}
			messagePermissions[key] = entry
			task.delay(15, function() messagePermissions[key] = nil end)
		end
		return entry.allowed
	end
	refs[t.id].prompt.Triggered:Connect(function(player)
		local key = "join_" .. player.UserId
		if limits[key] and now() - limits[key] < 1 then return end
		limits[key] = now()
		tryJoin(player, t)
	end)
end

actionEvent.OnServerEvent:Connect(function(player, action, value)
	if type(action) ~= "string" then return end
	local id, timestamp = player.UserId, now()
	if limits[id] and timestamp - limits[id] < 0.2 then return end
	limits[id] = timestamp
 if action=="ChatRetry" then return end
 if action == "Sync" then
		stateEvent:FireClient(player, makeState(player, lobbyList()))
	elseif action == "Leave" then
		leaveTable(player)
	elseif action == "Emote" then
		local t=membership[id]
		if not t or t.phase=="Waiting" or t.phase=="Result" then
			if not limits["emote_"..id] or timestamp-limits["emote_"..id]>=5 then
				limits["emote_"..id]=timestamp
				Cosmetics.emote(player,profiles:public(id))
			end
		end
	elseif action == "Vote" then
		local t = membership[id]
		if t and t.phase == "Vote" and now() < t.endAt and type(value) == "number" then
			if Voting.cast(t.round, id, value,t.candidates,Rules) then publish() end
		end
	end
end)

economyAction.OnServerEvent:Connect(function(player, kind, value, requestId)
	if type(kind) ~= "string" or type(requestId) ~= "string" or #requestId > 64 or not requestId:match("^[%w%-]+$") then return end
	local id = player.UserId
	local function respond(receipt)
		if player.Parent == Players then
			local profile=profiles:public(id)
			syncPublicProfile(player,profile)
			profileEvent:FireClient(player, profile, receipt, requestId)
			updateHighStakesCollision(player)
		end
	end
	if player:GetAttribute("SpyTeleporting") then respond({ok=false,code="slowDown"}) return end
	if kind=="preferencesSync" then
		local key="preferencesSync"
		local stamp=os.clock()
		economyTime[id]=economyTime[id] or {}
		if stamp-(economyTime[id][key] or -10)<1 then return end
		economyTime[id][key]=stamp
		respond({ok=true,code="preferencesSynced"})
		return
	end
	local command
	if kind=="accessoryRoll" then
        if type(value)~="string" or #value>32 then respond({ok=false,code="roll_invalid_request"}) return end
        command={kind=kind,category=value,requestId=requestId}
	elseif kind=="rollPurchase" then
        if type(value)~="number" or value~=value or value<1 or value%1~=0 or value>=math.huge then respond({ok=false,code="roll_product_unavailable"}) return end
        command={kind=kind,productId=value}
	elseif kind=="rollPromo" then
        if type(value)~="string" or #value<1 or #value>48 or not value:match("^[%w_%-]+$") then respond({ok=false,code="roll_invalid_award"}) return end
        command={kind=kind,awardId=string.upper(value)}
	elseif kind == "capsule" then
        respond({ok=false,code="use_accessory_roll"});return
	elseif kind == "clubBuy"or kind == "buy" or kind == "equip" or kind=="useGadget" or kind == "sell" then
		if type(value) ~= "string" or #value > 64 then respond({ok=false,code="invalid_item"}) return end
		command = {kind=kind, itemId=value}
	elseif kind == "onboarding" then
		if value ~= "lobbyTourSeen" then respond({ok=false,code="invalid_item"}) return end
		command = {kind=kind, key=value}
	elseif kind=="daily" then command={kind=kind,now=os.time()}
	elseif kind=="vincentAccept" or kind=="vincentClaim" then
		if value~=nil then respond({ok=false,code="invalid_item"}) return end
		command={kind=kind,now=os.time()}
	elseif kind=="settings" then
		local clean=require(shared.Preferences).sanitize(value)
		if not clean then respond({ok=false,code="invalid_settings"}) return end
		command={kind=kind,settings=clean}
	elseif kind == "language" then
		if value ~= "ru" and value ~= "en" then respond({ok=false,code="invalid_item"}) return end
		command = {kind=kind, language=value}
	elseif kind == "retry" then
		command = {kind=kind}
	else
		respond({ok=false,code="invalid_item"})
		return
	end
	local timestamp = now()
	local actionTimes = economyTime[id]
	if not actionTimes then actionTimes = {} economyTime[id] = actionTimes end
	local cooldown = requestCooldown[kind] or 0.5
	if economyBusy[id] or (actionTimes[kind] and timestamp-actionTimes[kind] < cooldown) then
		respond({ok=false,code="slowDown"})
		return
	end
	local t = membership[id]
	if kind ~= "language" and kind ~= "settings" and kind ~= "retry" and kind ~= "onboarding" and not (kind=="useGadget" and value=="notebook") and t and t.phase ~= "Waiting" and t.phase ~= "Result" then
		respond({ok=false,code="shopDuringRound"}) return
	end
	economyBusy[id], actionTimes[kind] = true, timestamp
	player:SetAttribute("SpyEconomyBusy",true)
	local operationOK, receipt = pcall(function()
		if kind=="rollPurchase" then return monetization and monetization:prompt(player,value) or {ok=false,code="roll_product_unavailable"} end
		if kind=="accessoryRoll" then return rollService:roll(player,value,requestId) end
		if kind=="rollPromo" then return rollService:award(player,"promo",command.awardId) end
		if kind == "equip" then
			local ready,code=Cosmetics.canEquip(player,profiles:public(id),value)
			if not ready then return {ok=false,code=code} end
		end
		if kind == "retry" then
			if profiles.busy[id] or profiles.pending[id] then return {ok=false,code="slowDown"} end
			return {ok=profiles:load(id),code="refreshed"}
		end
		return profiles:transact(id, "shop:" .. id .. ":" .. kind .. ":" .. requestId, command)
	end)
	economyBusy[id] = nil
	player:SetAttribute("SpyEconomyBusy",false)
	if not operationOK then
		warn("SpyClub economy action failed: " .. tostring(receipt))
		receipt = {ok=false,code="profile_unavailable"}
	end
	if receipt.ok and (kind == "equip" or kind == "sell" or kind=="accessoryRoll") then
		local current = membership[id]
		if current then World.applyCosmetics(refs[current.id], {seat=current.seats[id], equipped=profiles:public(id).equipped}, id) end
	end
	respond(receipt)
	if kind=="settings" or kind=="language" or kind=="vincentAccept" or kind=="vincentClaim" or kind=="onboarding" then return end
	if receipt.ok then
		pcall(Leaderboards.refresh,profiles)
		local applyOK, applyResult
		if kind == "equip" then
			applyOK, applyResult = pcall(Cosmetics.apply, player, profiles:public(id))
		else
			applyOK, applyResult = pcall(Cosmetics.apply, player, profiles:public(id))
		end
		if not applyOK then
			warn("SpyClub: cosmetic apply crashed after " .. tostring(kind) .. ": " .. tostring(applyResult))
		elseif kind == "equip" and applyResult ~= true then
			warn("SpyClub: cosmetic equip was accepted but character was not ready for rebuild")
		end
	end
end)

local world=workspace:FindFirstChild("SpyClub")
if world then
	local PHYSICAL_CASE_IDS={
		ClassicCase="midnight",
		SilverCase="velvet",
		GoldCase="blackvault",
	}

	local function promptBasePart(prompt)
		return prompt:FindFirstAncestorWhichIsA("BasePart")
	end

	local function promptAttribute(prompt,name)
		local node=prompt
		while node and node~=world.Parent do
			local value=node:GetAttribute(name)
			if value~=nil then return value end
			if node==world then break end
			node=node.Parent
		end
		return nil
	end

	local function promptCaseId(prompt)
		local explicit=promptAttribute(prompt,"CaseId")
		if explicit~=nil then return explicit end
		local node=prompt.Parent
		while node and node~=workspace do
			local mapped=PHYSICAL_CASE_IDS[node.Name]
			if mapped then return mapped end
			node=node.Parent
		end
		return nil
	end

	local supportBoard = world:FindFirstChild("BoardSupporters")
	local supportPart = supportBoard and supportBoard:FindFirstChild("Panel")
	if supportPart and supportPart:IsA("BasePart") then
		local supportPrompt = supportPart:FindFirstChild("OpenSupport") or Instance.new("ProximityPrompt")
		supportPrompt.Name = "OpenSupport"
		supportPrompt.ActionText = "Поддержать"
		supportPrompt.ObjectText = "Spy Club"
		supportPrompt.KeyboardKeyCode = Enum.KeyCode.E
		supportPrompt.HoldDuration = 0
		supportPrompt.MaxActivationDistance = 8
		supportPrompt.RequiresLineOfSight = false
		supportPrompt.Style = Enum.ProximityPromptStyle.Custom
		supportPrompt.Parent = supportPart
	end

	for _,prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt.Name~="JoinTable" then
			prompt.Triggered:Connect(function(player)
				local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local anchor=promptBasePart(prompt)
				if not root or not anchor or (root.Position-anchor.Position).Magnitude>prompt.MaxActivationDistance+3 then return end
				if membership[player.UserId] then return end
				local panels={OpenShop="shop",DailyReward="daily",InspectCase="shop",CasePrompt="shop"}
				if prompt.Name=="FeedbackBook" then
					feedbackOpenAt[player.UserId]=os.clock()
					feedbackBook:FireClient(player,"open")
				elseif prompt.Name=="TalkVincent" then tell(player,{key="talkVincent"})
				elseif panels[prompt.Name] then
					local caseId=promptCaseId(prompt)
					if (prompt.Name=="InspectCase" or prompt.Name=="CasePrompt") and not caseId then caseId="midnight" end
					tell(player,{key="openPanel",panel=panels[prompt.Name],caseId=caseId})
				elseif prompt.Name=="LeaveHighStakes" then return end
			end)
		end
	end
end

local function connectPlayer(player)
	task.spawn(ensureLobbyGlobalChatSource,player)
	task.spawn(function() gateAccess:connectPlayer(player) end)
	task.spawn(function()
        for attempt=1,4 do
            local ok,loaded=pcall(profiles.load,profiles,player.UserId)
            if ok and loaded then break end
            if player.Parent~=Players then return end
            player:SetAttribute("SpyProfileLoadState","retrying")
            task.wait(attempt*2)
        end
        player:SetAttribute("SpyProfileLoadState",profiles:public(player.UserId).ready and "ready" or "failed")
        if player.Parent == Players then
            changed(player)
            task.spawn(function()
                if RunService:IsStudio() then return end
                if not RewardRecovery then
                    local ok,value=pcall(function() return require(modules.ReconnectService).default() end)
                    if not ok then warn("SpyClub: reward recovery unavailable: "..tostring(value));return end
                    RewardRecovery=value
                end
                -- Includes records staged after this player arrived back in Lobby.
                for attempt=1,8 do
                    if player.Parent~=Players then return end
                    local pending=RewardRecovery:pendingRewards(player.UserId)
                    for _,record in ipairs(pending) do
                        if not profiles:public(player.UserId).ready then pcall(profiles.load,profiles,player.UserId) end
                        local ok,receipt=pcall(profiles.transact,profiles,player.UserId,record.operationId,record.command)
                        if ok and receipt.ok then
                            RewardRecovery:ackReward(player.UserId,record.operationId)
                            changed(player,receipt)
                        end
                    end
                    task.wait(5)
                end
            end)
            if monetization then task.spawn(function() monetization:sync(player) end) end
		end
	end)
	player.CharacterRemoving:Connect(function() leaveTable(player) end)
	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		-- CharacterAdded may precede Roblox finishing the clothing and body rig.
		-- Let the async spawn complete before welding anything to that rig.
		local spawnDeadline = os.clock() + 15
		while player.Character == character
			and player:GetAttribute("SpySpawnWithDescription") == true
			and not character:GetAttribute("SpySpawnAppearanceReady")
			and os.clock() < spawnDeadline do
			task.wait(.05)
		end
		if player.Character ~= character then return end
		if not character:GetAttribute("SpySpawnAppearanceReady") then
			player:SetAttribute("SpySpawnWithDescription", false)
		end
		if humanoid then humanoid.Died:Connect(function()
			leaveTable(player)
			task.delay(Players.RespawnTime,function()
				if player.Parent == Players and player.Character == character then
					spawnCanonical(player)
				end
			end)
		end) end

		-- Universal-character order is strict: canonical body first, saved cosmetics second.
		local ok,prepared,reason=pcall(CharacterService.apply,player,character)
		if not ok then
			warn("SpyClub: CharacterService crashed for "..player.Name..": "..tostring(prepared))
			return
		end
		if prepared~=true then
			-- R6/legacy spawn was replaced with our R15 model. The replacement fires
			-- CharacterAdded again and that second pass performs the cosmetic rebuild.
			if reason=="character_replaced" then return end
			warn("SpyClub: canonical character was not prepared for "..player.Name.." ("..tostring(reason)..")")
			return
		end
		local publicProfile = profiles:public(player.UserId)
		syncPublicProfile(player, publicProfile)
		pcall(Cosmetics.apply,player,publicProfile)
		player:SetAttribute("SpySpawnWithDescription", false)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
	if not player.Character then task.spawn(spawnCanonical, player) end
	task.defer(publish)
end
Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player)
	lobbyGlobalLastSent[player.UserId] = nil
	rollService:remove(player.UserId)
	lobbyChatEnrollGeneration[player.UserId] = (lobbyChatEnrollGeneration[player.UserId] or 0) + 1
	lobbyChatEnrollBusy[player.UserId] = nil
	local chatConnection = lobbyChatSourceConnections[player.UserId]
	if chatConnection then chatConnection:Disconnect() end
	lobbyChatSourceConnections[player.UserId] = nil
	spawning[player] = nil
	leaveTable(player)
	gateAccess:removePlayer(player)
	profiles:remove(player.UserId)
	economyBusy[player.UserId], economyTime[player.UserId] = nil, nil
	feedbackOpenAt[player.UserId]=nil
	limits[player.UserId], limits["join_" .. player.UserId] = nil, nil
end)
for _, p in ipairs(Players:GetPlayers()) do connectPlayer(p) end
publish()
game:BindToClose(function()
	-- Cancel in-flight table coroutines before refunding. A stake transaction that resumes
	-- during shutdown sees the token change and immediately returns its own contribution.
	for _,t in pairs(tables) do t.token=t.token+1 end
	for _,t in pairs(tables) do
		if t.highStakes and t.stakeLedger and next(t.stakeLedger) then refundStakeLedger(t,"shutdown",true) end
	end
	profiles:flush(25)
end)
if RunService:IsStudio() then
	print("Spy Club loaded. Studio progress is session-only. Start 3–4 clients for a complete round.")
end


---------------------------------------------------------------------
-- SPY CLUB CREATOR CONTROL V50.4 -- profile/chat integration
---------------------------------------------------------------------
do
    local adminCommand=SpyAdminCore.remote
    local profileWriteAt={}
    local function profileRateAllowed(p)
        local now=os.clock(); local last=profileWriteAt[p.UserId] or -1000
        if now-last<0.5 then return false end; profileWriteAt[p.UserId]=now; return true
    end
    local function refreshMuted(p)
        local global=findLobbyChatSource(p.UserId)
        if global then applyLobbyChatPermission(p,global) end
    end
    adminCommand.OnServerEvent:Connect(function(actor,payload)
        if type(payload)~="table" or actor:GetAttribute("SpyIsAdmin")~=true then return end
        local command=payload.command; local requestId=payload.requestId
        if command~="mute" and command~="unmute" and command~="coins" and command~="level" and command~="grant" then return end
        local target,terr=SpyAdminCore.targetOf(payload); if not target then SpyAdminCore.reply(actor,command,requestId,false,terr); return end
        if command=="mute" or command=="unmute" then
            target:SetAttribute("SpyAdminMuted",command=="mute"); refreshMuted(target)
            SpyAdminCore.reply(actor,command,requestId,true,command=="mute" and "muted" or "unmuted")
            SpyAdminCore.log(actor,target,command,"ok"); return
        end
        if not profileRateAllowed(actor) then SpyAdminCore.reply(actor,command,requestId,false,"profile_rate_limited"); return end
        local tx
        if command=="coins" then
            local d=payload.delta
            if type(d)~="number" or d%1~=0 or d < -1000000 or d > 1000000 then SpyAdminCore.reply(actor,command,requestId,false,"bad_delta"); return end
            tx={kind="adminCoinsDelta",delta=d}
        elseif command=="level" then
            local lv=payload.level
            if type(lv)~="number" or lv%1~=0 or lv<1 or lv>10000 then SpyAdminCore.reply(actor,command,requestId,false,"bad_level"); return end
            tx={kind="adminSetLevel",level=lv}
        else
            local id=payload.itemId; local item=type(id)=="string" and Catalog.ById[id] or nil
            if not item or item.kind=="gadget" then SpyAdminCore.reply(actor,command,requestId,false,"invalid_item"); return end
            tx={kind="adminGrantItem",itemId=id}
        end
        local op="admin:"..actor.UserId..":"..target.UserId..":"..command..":"..HttpService:GenerateGUID(false)
        local receipt=profiles:transact(target.UserId,op,tx)
        if receipt and receipt.ok then changed(target,receipt,op) end
        SpyAdminCore.reply(actor,command,requestId,receipt and receipt.ok,receipt and receipt.code or "save_failed",receipt)
        SpyAdminCore.log(actor,target,command,receipt and receipt.code or "save_failed")
    end)
    shared:SetAttribute("SpyAdminProfileReady",true)
    print("SPY_ADMIN_SERVER_READY","LOBBY","V50.4")
end

end,debug.traceback)
bootTarget:SetAttribute("SpyLobbyBootStatus",bootOK and "ready" or "failed")
if not bootOK then
 bootTarget:SetAttribute("SpyLobbyBootStatusError",string.sub(tostring(bootError),1,1500))
 warn("[SPY V64 BOOT] "..tostring(bootError))
end
