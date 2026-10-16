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
            reply(actor,command,requestId,true,"ok",{players=roster(),server=serverInfo("match")})
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
    print("SPY_ADMIN_CORE_READY","MATCH",RunServiceService:IsStudio())
    return {remote=remote,broadcast=broadcast,reply=reply,log=log,targetOf=targetOf,serverInfo=serverInfo,filterText=filterText}
end)()


local bootStorage = game:GetService("ReplicatedStorage")
bootStorage:SetAttribute("SpyBuild","V101_WORLD")
bootStorage:SetAttribute("SpyRoundBootStatus", "starting")
local bootOK, bootError = xpcall(function()
-- ServerScriptService > MatchRoundServer
-- SPY CLUB / MATCH ROUND SERVER
-- FULL REPLACEMENT
--
-- FLOW:
-- Topic vote
-- -> Topic chosen
-- -> Intro / role cards
-- -> 1 mandatory hint lap
-- -> Discussion
-- -> Vote
-- -> optional extra hint lap
-- -> Result
-- -> Lobby
--
-- LEAVERS:
-- • 4 -> 3: match continues
-- • current speaker leaves: turn skips
-- • leaver removed from future turns and votes
-- • leave during Vote: vote restarts
-- • fewer than 3 live players: match cancelled
-- • spy leaves after roles assigned: match cancelled
--
-- RETURN:
-- • sends party data back to Lobby
-- • Lobby can rebuild the same table
-- • party name / owner / capacity / visibility / memberIds preserved

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local ServerStorage = game:GetService("ServerStorage")

-- Transport is initialized before catalog/profile dependencies.
-- MatchSessionServer reuses this folder. Creating it does not admit anyone or
-- start a phase; the chat stays closed until that server accepts the player.
local sessionFolder = ReplicatedStorage:FindFirstChild("MatchSession")
if not sessionFolder then
	sessionFolder = Instance.new("Folder")
	sessionFolder.Name = "MatchSession"
	sessionFolder.Parent = ReplicatedStorage
end
local round={hintTurnDone=false}
-- Relay hint progress is server-only, after successful filtered delivery.
local relayHintObserved=setmetatable({},{__mode="k"})
local function observeRelayHint(event)
	if event.Name~="SpyFilteredHintAccepted" or not event:IsA("BindableEvent") or relayHintObserved[event] then return end
	relayHintObserved[event]=true
	event.Event:Connect(function(userId,lap,index)
		local sender=Players:GetPlayerByUserId(userId)
		if not sender or sender:GetAttribute("SpySessionAccepted")~=true or sender:GetAttribute("SpyAdminMuted")==true
			or sessionFolder:GetAttribute("RoundPhase")~="Hint" or sessionFolder:GetAttribute("CurrentTurnUserId")~=userId
			or sessionFolder:GetAttribute("CurrentHintLap")~=lap or sessionFolder:GetAttribute("CurrentTurnIndex")~=index
			or round.hintTurnDone then return end
		if round.participation then round.participation:respond(userId,"hint") end
		round.hintTurnDone=true
	end)
end
ServerStorage.ChildAdded:Connect(observeRelayHint)
local relayHint=ServerStorage:FindFirstChild("SpyFilteredHintAccepted")
if relayHint then observeRelayHint(relayHint) end
local MATCH_CHAT_CHANNEL = "SpyMatchGlobal"
local matchTextChannels = TextChatService:FindFirstChild("TextChannels")
if not matchTextChannels then
	matchTextChannels = Instance.new("Folder")
	matchTextChannels.Name = "TextChannels"
	matchTextChannels.Parent = TextChatService
end

local matchChatChannel = matchTextChannels:FindFirstChild("RBXGeneral") or matchTextChannels:FindFirstChild(MATCH_CHAT_CHANNEL)
if matchChatChannel and not matchChatChannel:IsA("TextChannel") then
	matchChatChannel:Destroy()
	matchChatChannel = nil
end
if not matchChatChannel then
	matchChatChannel = Instance.new("TextChannel")
	matchChatChannel.Name = MATCH_CHAT_CHANNEL
	matchChatChannel.Parent = matchTextChannels
end

ReplicatedStorage:SetAttribute("SpyChatChannelName", matchChatChannel.Name)

local MATCH_CHAT_MAX = 180
local MATCH_CHAT_COOLDOWN = 0.75
local matchChatLastSent = {}
local matchChatMessagePermissions = {}
local matchHintMessageTurns = {}

local function matchChatPhaseAllows(senderId)
	local phase = sessionFolder:GetAttribute("RoundPhase")
	if phase == "Discuss" then return true end
	if phase == "Hint" then
		return sessionFolder:GetAttribute("CurrentTurnUserId") == senderId
	end
	return false
end

local function matchChatMessageAllowed(message)
	if not message or not message.TextSource then return false end
	local senderId = message.TextSource.UserId
	local sender = Players:GetPlayerByUserId(senderId)
	if not sender or sender:GetAttribute("SpySessionAccepted") ~= true or sender:GetAttribute("SpyAdminMuted") == true then return false end

	local messageId = tostring(message.MessageId or "")
	if messageId ~= "" and matchChatMessagePermissions[messageId] ~= nil then
		return matchChatMessagePermissions[messageId]
	end

	local text = tostring(message.Text or "")
	local length = utf8.len(text)
	local phase = sessionFolder:GetAttribute("RoundPhase")
	local allowed = length ~= nil and length > 0 and length <= MATCH_CHAT_MAX and matchChatPhaseAllows(senderId)

	if allowed and phase == "Discuss" then
		local nowClock = os.clock()
		allowed = nowClock - (matchChatLastSent[senderId] or -1000) >= MATCH_CHAT_COOLDOWN
		if allowed then matchChatLastSent[senderId] = nowClock end
	elseif allowed and phase == "Hint" then
		local turnKey = table.concat({
			tostring(sessionFolder:GetAttribute("CurrentHintLap") or 0),
			tostring(sessionFolder:GetAttribute("CurrentTurnIndex") or 0),
			tostring(senderId),
		}, ":")
		if matchHintMessageTurns[turnKey] then
			allowed = false
		else
			matchHintMessageTurns[turnKey] = true
			if round.participation then round.participation:respond(senderId,"hint") end
			round.hintTurnDone = true
		end
	end

	if messageId ~= "" then
		matchChatMessagePermissions[messageId] = allowed
		task.delay(20, function() matchChatMessagePermissions[messageId] = nil end)
	end
	return allowed
end

local function matchChatDelivery(message, target)
	if ReplicatedStorage:GetAttribute("SpyChatTransport") == "server_filtered" then return false end
	if not message or (message.TextChannel and message.TextChannel ~= matchChatChannel) then return false end
	if not target then return false end
	local receiver = Players:GetPlayerByUserId(target.UserId)
	if not receiver or receiver:GetAttribute("SpySessionAccepted") ~= true then return false end
	return matchChatMessageAllowed(message)
end

matchChatChannel.ShouldDeliverCallback = matchChatDelivery

local matchChatSourceConnections = {}
local matchChatEnrollGeneration = {}
local matchChatEnrollBusy = {}

local function setMatchChatState(player, stateName, ready, detail)
	if player.Parent ~= Players then return end
	if player:GetAttribute("SpyMatchChatState") ~= stateName or player:GetAttribute("SpyMatchChatDetail") ~= tostring(detail or "") then
		print("[SPY CHAT SERVER] Match channel=" .. matchChatChannel.Name .. " state=" .. stateName .. " eligibility=" .. tostring(player:GetAttribute("SpyChatEligibility") or "pending") .. " detail=" .. tostring(detail or ""))
	end
	player:SetAttribute("SpyMatchChatState", stateName)
	player:SetAttribute("SpyMatchChatReady", ready == true)
	player:SetAttribute("SpyMatchChatDetail", tostring(detail or ""))
end

local function findMatchChatSource(userId)
	for _, child in ipairs(matchChatChannel:GetChildren()) do
		if child:IsA("TextSource") and child.UserId == userId then return child end
	end
	return nil
end

local function applyMatchChatPermission(player, source)
	if player.Parent ~= Players or not source or not source.Parent then return end
	-- Diagnostic mode: keep game/session gates, but do not pre-block on account
	-- eligibility. SendAsync returns Roblox's authoritative chat result.
	if player:GetAttribute("SpySessionAccepted") ~= true then
		setMatchChatState(player, "blocked", false, "session")
	elseif player:GetAttribute("SpyAdminMuted") == true then
		setMatchChatState(player, "blocked", false, "muted")
	elseif not matchChatPhaseAllows(player.UserId) then
		setMatchChatState(player, "blocked", false, "phase")
	elseif source.CanSend == true then
		setMatchChatState(player, "ready", true, "")
	else
		setMatchChatState(player, "ready", false, "TextSource.CanSend=false; SendAsync probe enabled")
	end
end

local function observeMatchChatSource(player, source)
	local previous = matchChatSourceConnections[player.UserId]
	if previous then previous:Disconnect() end
	matchChatSourceConnections[player.UserId] = nil
	if not source or not source.Parent then return end
	source:SetAttribute("SpyChatUserId",player.UserId)
	local function refresh() applyMatchChatPermission(player, source) end
	local connections = {source:GetPropertyChangedSignal("CanSend"):Connect(refresh),
		player:GetAttributeChangedSignal("SpyAdminMuted"):Connect(refresh)}
	table.insert(connections, player:GetAttributeChangedSignal("SpySessionAccepted"):Connect(refresh))
	matchChatSourceConnections[player.UserId] = {Disconnect=function()
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end}
	applyMatchChatPermission(player, source)
end

local function ensureMatchChatSource(player)
	if player.Parent ~= Players or matchChatEnrollBusy[player.UserId] then return end
	local generation = (matchChatEnrollGeneration[player.UserId] or 0) + 1
	matchChatEnrollGeneration[player.UserId] = generation
	matchChatEnrollBusy[player.UserId] = generation
	local function current()
		return player.Parent == Players and matchChatEnrollGeneration[player.UserId] == generation
	end
	local existing = findMatchChatSource(player.UserId)
	if existing and player:GetAttribute("SpySessionAccepted") ~= true then
		matchChatEnrollBusy[player.UserId] = nil
		observeMatchChatSource(player, existing)
		return
	end
	player:SetAttribute("SpyChatEligibility", "send_async_probe")
	setMatchChatState(player, "connecting", false, "enrolling_without_precheck")
	task.delay(18, function()
		if current() and matchChatEnrollBusy[player.UserId] == generation then
			matchChatEnrollGeneration[player.UserId] = generation + 1
			matchChatEnrollBusy[player.UserId] = nil
			setMatchChatState(player, "failed", false, "enrollment_timeout")
		end
	end)
	task.spawn(function()
		local deadline = os.clock() + 12
		while current() and player:GetAttribute("SpySessionAccepted") ~= true and os.clock() < deadline do task.wait(0.1) end
		if not current() then return end
		if player:GetAttribute("SpySessionAccepted") ~= true then
			matchChatEnrollBusy[player.UserId] = nil
			setMatchChatState(player, "failed", false, "session_not_accepted")
			return
		end
		-- No CanUserChatAsync precheck: try official channel enrollment directly.
		for attempt = 1, 5 do
			if not current() then return end
			local source = findMatchChatSource(player.UserId)
			local ok = source ~= nil
			if not source then ok, source = pcall(function() return matchChatChannel:AddUserAsync(player.UserId) end) end
			if not current() then return end
			if ok and source then
				matchChatEnrollBusy[player.UserId] = nil
				observeMatchChatSource(player, source)
				return
			end
			warn("SpyClub: Match TextChannel enrollment attempt " .. attempt .. "/5 failed for " .. player.Name)
			if attempt < 5 then task.wait(0.8 * attempt) end
		end
		if not current() then return end
		matchChatEnrollBusy[player.UserId] = nil
		setMatchChatState(player, "failed", false, "TextChannel enrollment failed; SendAsync may still report the exact client status")
	end)
end

local function refreshAllMatchChatPermissions()
	for _, chatPlayer in ipairs(Players:GetPlayers()) do
		local source = findMatchChatSource(chatPlayer.UserId)
		if source then applyMatchChatPermission(chatPlayer, source) end
	end
end
for _, attributeName in ipairs({"RoundPhase","CurrentTurnUserId","CurrentHintLap","CurrentTurnIndex"}) do
	sessionFolder:GetAttributeChangedSignal(attributeName):Connect(function() task.defer(refreshAllMatchChatPermissions) end)
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
	if candidate == matchChatChannel then return end
	matchChatChannel = candidate
	candidate.ShouldDeliverCallback = matchChatDelivery
	ReplicatedStorage:SetAttribute("SpyChatChannelName", candidate.Name)
	for _, chatPlayer in ipairs(Players:GetPlayers()) do
		matchChatEnrollGeneration[chatPlayer.UserId] = (matchChatEnrollGeneration[chatPlayer.UserId] or 0) + 1
		matchChatEnrollBusy[chatPlayer.UserId] = nil
		local connection = matchChatSourceConnections[chatPlayer.UserId]
		if connection then connection:Disconnect();matchChatSourceConnections[chatPlayer.UserId] = nil end
		task.spawn(ensureMatchChatSource, chatPlayer)
	end
end
matchTextChannels.ChildAdded:Connect(observeDefaultChatChannel)
for _, candidate in ipairs(matchTextChannels:GetChildren()) do observeDefaultChatChannel(candidate) end

local earlyChatRemotes=ReplicatedStorage:FindFirstChild("MatchRemotes")
if not earlyChatRemotes then earlyChatRemotes=Instance.new("Folder");earlyChatRemotes.Name="MatchRemotes";earlyChatRemotes.Parent=ReplicatedStorage end
local earlyChatAction=earlyChatRemotes:FindFirstChild("Action") or Instance.new("RemoteEvent")
earlyChatAction.Name,earlyChatAction.Parent="Action",earlyChatRemotes
local matchChatAdmissionConnections = {}
local function connectMatchChatPlayer(player)
	if matchChatAdmissionConnections[player.UserId] then return end
	matchChatAdmissionConnections[player.UserId] = player:GetAttributeChangedSignal("SpySessionAccepted"):Connect(function()
		if player:GetAttribute("SpySessionAccepted") == true then
			task.spawn(ensureMatchChatSource, player)
		end
	end)
	task.spawn(ensureMatchChatSource, player)
end
Players.PlayerAdded:Connect(connectMatchChatPlayer)
for _,player in ipairs(Players:GetPlayers()) do connectMatchChatPlayer(player) end
earlyChatAction.OnServerEvent:Connect(function(player,action)
 if action~="ChatRetry" or player:GetAttribute("SpySessionAccepted")~=true then return end
 local last=player:GetAttribute("SpyChatRetryAt") or -1000
 if os.clock()-last<5 then return end
 player:SetAttribute("SpyChatRetryAt",os.clock())
 task.spawn(ensureMatchChatSource,player)
end)
Players.PlayerRemoving:Connect(function(player)
 local admissionConnection=matchChatAdmissionConnections[player.UserId]
 if admissionConnection then admissionConnection:Disconnect() end
 matchChatAdmissionConnections[player.UserId]=nil
 local connection=matchChatSourceConnections[player.UserId]
 if connection then connection:Disconnect() end
 matchChatSourceConnections[player.UserId]=nil
 matchChatEnrollGeneration[player.UserId]=(matchChatEnrollGeneration[player.UserId] or 0)+1
 matchChatEnrollBusy[player.UserId]=nil
 matchChatLastSent[player.UserId]=nil
end)

local ReconnectModule = require(ServerStorage:WaitForChild("SpyModules"):WaitForChild("ReconnectService"))
local reconnect = ReconnectModule.default()
local StarterPlayer = game:GetService("StarterPlayer")
pcall(function() StarterPlayer.LoadCharacterAppearance = false end)

---------------------------------------------------------------------
-- PLACES
---------------------------------------------------------------------

local LOBBY_PLACE_ID = 93859909286393

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------

local MINIMUM_LIVE_PLAYERS = 3

local TOPIC_VOTE_SECONDS = 12
local TOPIC_CHOSEN_SECONDS = 2.4
local TOPIC_OPTIONS_COUNT = 4

local INTRO_SECONDS = 6.5
local ROLE_SECONDS = 5.5

local INITIAL_HINT_LAPS = 1
local HINT_SECONDS = 45
local EARLY_TURN_ADVANCE_DELAY = 0.85

local DISCUSS_SECONDS = 30
local VOTE_SECONDS = 20

local VOTE_RESTART_DISCUSS_SECONDS = 8

local EXTRA_ROUND_ANNOUNCE_SECONDS = 2.2

local RESULT_SECONDS = 18
local RETURN_DELAY = 2.2

local EXTRA_ROUND_VOTE_VALUE = "__EXTRA_ROUND__"

---------------------------------------------------------------------
-- THEME CATALOG
---------------------------------------------------------------------

local ThemeCatalog =
	require(
		ReplicatedStorage:WaitForChild(
			"MatchThemeCatalog"
		)
	)

---------------------------------------------------------------------
-- SESSION
---------------------------------------------------------------------

local MatchRules = require(ReplicatedStorage:WaitForChild("SpyShared"):WaitForChild("MatchRules"))
local activeRules = MatchRules.defaults()
local RoleRules = require(ServerStorage:WaitForChild("SpyModules"):WaitForChild("Rules"))

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------

local remotes =
	ReplicatedStorage:FindFirstChild(
		"MatchRemotes"
	)

if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "MatchRemotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(name)
	local remote =
		remotes:FindFirstChild(name)

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end

	return remote
end

local stateEvent = getRemote("State")
local cardEvent = getRemote("Card")
local actionEvent = getRemote("Action")
local rewardEvent = getRemote("Reward")

local snapshotFunction = remotes:FindFirstChild("Snapshot")

if snapshotFunction
	and not snapshotFunction:IsA("RemoteFunction")
then
	snapshotFunction:Destroy()
	snapshotFunction = nil
end

if not snapshotFunction then
	snapshotFunction = Instance.new("RemoteFunction")
	snapshotFunction.Name = "Snapshot"
	snapshotFunction.Parent = remotes
end

---------------------------------------------------------------------
-- ECONOMY / PROFILES
--
-- Match uses the SAME persistent economy as Lobby.
-- Nothing in this script edits coins directly.
-- All mutations go through Profiles -> Economy.transaction().
---------------------------------------------------------------------

local Catalog = require(ReplicatedStorage:WaitForChild("SpyShared"):WaitForChild("Catalog"))
local Cosmetics = require(ServerStorage:WaitForChild("SpyModules"):WaitForChild("Cosmetics"))

local profiles = nil
local profileLoadState = {}

do
	local spyModules =
		ServerStorage:FindFirstChild(
			"SpyModules"
		)

	local profilesModule =
		spyModules
		and spyModules:FindFirstChild(
			"Profiles"
		)

	if profilesModule
		and profilesModule:IsA(
			"ModuleScript"
		)
	then
		local okRequire, Profiles =
			pcall(
				require,
				profilesModule
			)

		if okRequire
			and type(Profiles) == "table"
			and type(Profiles.new) == "function"
		then
			local okCreate, result =
				pcall(
					Profiles.new
				)

			if okCreate then
				profiles = result
			else
				warn(
					"[MatchRoundServer] Profiles.new failed:",
					result
				)
			end
		else
			warn(
				"[MatchRoundServer] Could not require SpyModules.Profiles:",
				Profiles
			)
		end
	else
		warn(
			"[MatchRoundServer] Economy disabled: ServerStorage.SpyModules.Profiles is missing in Match."
		)
	end
end

task.spawn(function()
 local modules=ServerStorage:FindFirstChild("SpyModules")
 local module=modules and modules:FindFirstChild("FeedbackService")
 if module and profiles then
  local ok,err=pcall(function() require(module).start(profiles,ReplicatedStorage.SpyShared) end)
  if not ok then warn("SpyClub developer inbox: "..tostring(err)) end
 end
end)

local function profileSnapshot(
	targetPlayer
)
	local fallback = {
		level = math.max(1, math.floor(tonumber(targetPlayer and targetPlayer:GetAttribute("SpyLevel")) or 1)),
		xp = math.max(0, math.floor(tonumber(targetPlayer and targetPlayer:GetAttribute("SpyXP")) or 0)),
		coins = math.max(0, math.floor(tonumber(targetPlayer and targetPlayer:GetAttribute("SpyCoins")) or 0)),
		rolls = math.max(0, math.floor(tonumber(targetPlayer and targetPlayer:GetAttribute("SpyRolls")) or 0)),
		rank = tostring(targetPlayer and targetPlayer:GetAttribute("SpyRank") or "Гость"),
		rankShort = tostring(targetPlayer and targetPlayer:GetAttribute("SpyRankShort") or "ГОСТЬ"),
		rankIndex = math.max(1, math.floor(tonumber(targetPlayer and targetPlayer:GetAttribute("SpyRankIndex")) or 1)),
		language = tostring(targetPlayer and targetPlayer:GetAttribute("SpyLanguage") or "ru"),
		equipped = {},
		ready = false,
	}

	if not profiles
		or not targetPlayer
		or profileLoadState[targetPlayer.UserId] ~= "ready"
	then
		return fallback
	end

	local ok, public = pcall(function()
		return profiles:public(targetPlayer.UserId)
	end)

	if not ok
		or type(public) ~= "table"
		or public.ready ~= true
	then
		return fallback
	end

	return {
		ready = true,
		level = math.max(1, math.floor(tonumber(public.level) or 1)),
		xp = math.max(0, math.floor(tonumber(public.xp) or 0)),
		coins = math.max(0, math.floor(tonumber(public.coins) or 0)),
		rolls = math.max(0, math.floor(tonumber(public.rolls) or 0)),
		rank = tostring(public.rank or "Гость"),
		rankShort = tostring(public.rankShort or "ГОСТЬ"),
		rankIndex = math.max(1, math.floor(tonumber(public.rankIndex) or 1)),
		language = tostring(public.language or "ru"),
		equipped = type(public.equipped) == "table" and public.equipped or {},
	}
end

local function publishProfileAttributes(
	targetPlayer
)
	if not targetPlayer
		or targetPlayer.Parent ~= Players
	then
		return
	end

	local progress = profileSnapshot(targetPlayer)
	local equipped = progress.equipped or {}

	targetPlayer:SetAttribute("SpyProfileReady", progress.ready == true)
	targetPlayer:SetAttribute("SpyLevel", progress.level)
	targetPlayer:SetAttribute("SpyXP", progress.xp)
	targetPlayer:SetAttribute("SpyCoins", progress.coins)
	targetPlayer:SetAttribute("SpyRolls", progress.rolls)
	targetPlayer:SetAttribute("SpyRank", progress.rank)
	targetPlayer:SetAttribute("SpyRankShort", progress.rankShort)
	targetPlayer:SetAttribute("SpyRankIndex", progress.rankIndex)
	targetPlayer:SetAttribute("SpyLanguage", progress.language)

	targetPlayer:SetAttribute("SpyTitle", tostring(equipped.title or ""))
	targetPlayer:SetAttribute("SpyFrame", tostring(equipped.frame or ""))
	targetPlayer:SetAttribute("SpyEffect", tostring(equipped.effect or ""))
	targetPlayer:SetAttribute("SpyEquippedCard", tostring(equipped.card or "classic"))
	targetPlayer:SetAttribute("SpyEquippedOutfit", tostring(equipped.outfit or ""))
	targetPlayer:SetAttribute("SpyEquippedHat", tostring(equipped.hat or ""))
	targetPlayer:SetAttribute("SpyEquippedHair", tostring(equipped.hair or ""))
	targetPlayer:SetAttribute("SpyEquippedGlasses", tostring(equipped.glasses or ""))
	targetPlayer:SetAttribute("SpyEquippedTie", tostring(equipped.tie or ""))
	targetPlayer:SetAttribute("SpyEquippedGloves", tostring(equipped.gloves or ""))
	targetPlayer:SetAttribute("SpyEquippedShoulder", tostring(equipped.shoulder or ""))
	targetPlayer:SetAttribute("SpyEquippedEmote", tostring(equipped.emote or ""))
end

local function applyProfileAppearance(targetPlayer, forceRebuild)
	if not profiles
		or not targetPlayer
		or targetPlayer.Parent ~= Players
		or profileLoadState[targetPlayer.UserId] ~= "ready"
		or not targetPlayer.Character
	then
		return false
	end

	local character = targetPlayer.Character
	local baseDeadline = os.clock() + 30
	while targetPlayer.Character == character
		and character.Parent
		and not character:GetAttribute("SpyBaseReady")
		and os.clock() < baseDeadline
	do
		task.wait(0.05)
	end
	if targetPlayer.Character ~= character
		or not character.Parent
		or not character:GetAttribute("SpyBaseReady")
	then
		return false
	end

	local okProfile, public = pcall(function()
		return profiles:public(targetPlayer.UserId)
	end)
	if not okProfile or type(public) ~= "table" or public.ready ~= true then
		return false
	end

	local okApply, result = pcall(
		Cosmetics.apply,
		targetPlayer,
		public,
		Catalog,
		forceRebuild == true
	)
	if not okApply then
		warn("[MatchRoundServer] Cosmetics.apply failed:", targetPlayer.Name, result)
		return false
	end
	return result == true
end

local function ensureProfileLoaded(
	targetPlayer
)
	if not profiles
		or not targetPlayer
	then
		return false
	end

	local userId =
		targetPlayer.UserId

	if profileLoadState[userId]
		== "ready"
		and profiles.cache[userId]
	then
		publishProfileAttributes(targetPlayer)
		task.defer(applyProfileAppearance, targetPlayer, false)
		return true
	end

	if profileLoadState[userId]
		== "loading"
	then
		local deadline =
			os.clock() + 12

		while profileLoadState[userId]
			== "loading"
			and os.clock() < deadline
		do
			task.wait(0.05)
		end

		local ready =
			profileLoadState[userId]
			== "ready"

		if ready then
			publishProfileAttributes(targetPlayer)
			task.defer(applyProfileAppearance, targetPlayer, false)
		end

		return ready
	end

	profileLoadState[userId] =
		"loading"

	local ok, loaded =
		pcall(
			function()
				return profiles:load(
					userId
				)
			end
		)

	if ok and loaded then
		profileLoadState[userId] =
			"ready"

		publishProfileAttributes(targetPlayer)
		task.defer(applyProfileAppearance, targetPlayer, true)

		return true
	end

	profileLoadState[userId] =
		"failed"

	warn(
		"[MatchRoundServer] Profile load failed:",
		targetPlayer.Name,
		loaded
	)

	return false
end

local function preloadProfiles(
	players
)
	if not profiles then
		return
	end

	for _, targetPlayer in ipairs(
		players
		) do
		task.spawn(
			function()
				ensureProfileLoaded(
					targetPlayer
				)
			end
		)
	end
end

-- Notes bind to the same profile instance; failure never gates match startup.
task.spawn(function()
 if not profiles then return end
 local module=ServerStorage.SpyModules:FindFirstChild("PhonePersonalService")
 if not module then return end
 local ok,err=pcall(function()require(module).start(profiles)end)
 if not ok then warn("SpyClub match phone notes: "..tostring(err))end
end)

-- Optional trade recovery remains active across Lobby -> Match -> Lobby.
task.spawn(function()
 if not profiles then return end
 local ok,err=pcall(function()
  local module=ServerStorage.SpyModules:FindFirstChild("TradeService")
  if not module then return end
  require(module).recovery(profiles,Catalog,function(uid)
   local player=Players:GetPlayerByUserId(uid)
   if player then
    publishProfileAttributes(player)
    task.defer(applyProfileAppearance,player,true)
    local event=ReplicatedStorage.SpyShared:FindFirstChild("Profile")
    if event then event:FireClient(player,profiles:public(uid),{ok=true,code="trade_updated"}) end
   end
  end)
 end)
 ReplicatedStorage:SetAttribute("SpyTradeRecoveryBootStatus",ok and "ready" or "failed")
 if not ok then warn("SpyClub match trade recovery: "..tostring(err)) end
end)

---------------------------------------------------------------------
-- ROUND STATE
---------------------------------------------------------------------

local verifiedRollLuck=require(ServerStorage.SpyModules.RollLuckService).new({
    passId=require(ServerStorage.SpyModules.MonetizationConfig).RollLuckPassId,
    onChanged=function(player)
        task.defer(function()
            if profiles and player.Parent==Players then
                local event=ReplicatedStorage.SpyShared:FindFirstChild("Profile")
                if event then event:FireClient(player,profiles:public(player.UserId),{ok=true,code="roll_luck_synced"}) end
            end
        end)
    end,
})
local matchMonetization=require(ServerStorage.SpyModules.Monetization).new(profiles,function(player,receipt)
    publishProfileAttributes(player)
    local event=ReplicatedStorage.SpyShared:FindFirstChild("Profile")
    if event then event:FireClient(player,profiles:public(player.UserId),receipt)end
    if receipt and (receipt.code=="cosmeticsGranted" or receipt.code=="paidGranted")then task.defer(applyProfileAppearance,player,true)end
end,{
    canPrompt=function(player)
        return player:GetAttribute("SpySessionAccepted")==true and not player:GetAttribute("SpyTeleporting")
            and not player:GetAttribute("SpyPhoneActive") and not player:GetAttribute("SpyTradeOpen")
            and require(ReplicatedStorage.SpyShared.DossierPolicy).canChange(round and round.phase)
    end,
})
require(ServerStorage:WaitForChild("SpyModules"):WaitForChild("PreferencesServer")).start(profiles,{
    ensureLoaded=function(player)
        if player:GetAttribute("SpySessionAccepted")==true then return ensureProfileLoaded(player) end
        return false
    end,
    canEquip=Cosmetics.canEquip,
    canChange=function(player)
        return player:GetAttribute("SpySessionAccepted")==true
            and not player:GetAttribute("SpyTeleporting")
            and require(ReplicatedStorage.SpyShared.DossierPolicy).canChange(round and round.phase)
    end,
    hasLuck=function(player) return verifiedRollLuck:has(player) end,
    canSpendPaidRolls=function(player) return matchMonetization:canSpendPaidRolls(player) end,
    shopFor=function(player,profile)return matchMonetization:shopFor(player,profile)end,
    prompt=function(player,productId)return matchMonetization:prompt(player,productId)end,
    onChanged=function(player,receipt)
        publishProfileAttributes(player)
        if receipt.code=="equipped" or receipt.code=="unequipped" or receipt.code=="accessoryRolled" then
            task.defer(applyProfileAppearance,player,true)
        end
    end,
})

round = {
	started = false,
	finished = false,
	aborting = false,

	token = 0,

	players = {},
	playerIndex = {},

	seatByUserId = {},

	topicOptions = {},
	topicVotes = {},
	topicVoteClosed = false,

	selectedThemeId = nil,

	category = nil,
	word = nil,
	spyId = nil,
	rolesAssigned = false,
	spyGuessUsed = false,
	resultStarted = false,

	order = {},

	currentTurnUserId = nil,
	turnIndex = 0,

	lap = 0,
	hintLaps = INITIAL_HINT_LAPS,
	extraRounds = 0,

	hintTurnDone = false,

	phase = "Waiting",
	endAt = 0,

	votes = {},
	voteClosed = false,
	voteRestartRequested = false,

	returnScheduled = false,

	rewardsStarted = false,
	rewardReceipts = {},
	rewardPending = 0,
	disconnected = {},
	participation = nil,
	voteOrder = {},
	survivedVote = {},
	firstCorrect = nil,
	terminal = false,
}

-- PlayerRemoving fires while Parent can still be Players. Keep one eligible
-- roster for consent, transport and the table restored in Lobby.
local function getRemainingPlayers()
 local result = {}
 local departed = round.rematch and round.rematch.departed
 for _, p in ipairs(round.players) do
  if p.Parent == Players and p:GetAttribute("SpyExplicitLeave") ~= true
   and not (departed and departed[p.UserId]) then result[#result + 1] = p end
 end
 return result
end

---------------------------------------------------------------------
-- MATCH TEXT CHANNEL
---------------------------------------------------------------------

local function reconnectSessionId()
	return sessionFolder:GetAttribute("ReconnectSessionId")
end
local function closeReconnect()
	round.terminal = true
	sessionFolder:SetAttribute("DisconnectedCount", 0)
	sessionFolder:SetAttribute("ReconnectDeadline", 0)
	sessionFolder:SetAttribute("ReconnectWaiting", false)
	local id = reconnectSessionId()
	if type(id) == "string" and id ~= "" then
		task.spawn(function() reconnect:close(id, game.JobId) end)
	end
end

local function publishConnections()
	if round.terminal then return end
	local count, deadline = 0, 0
	for _, expiresAt in pairs(round.disconnected) do
		count += 1
		deadline = math.max(deadline, expiresAt)
	end
	sessionFolder:SetAttribute("DisconnectedCount", count)
	sessionFolder:SetAttribute("ReconnectDeadline", count > 0 and workspace:GetServerTimeNow() + math.max(0, deadline-os.time()) or 0)
	sessionFolder:SetAttribute("ReconnectWaiting", count > 0 and round.phase == "Vote" and workspace:GetServerTimeNow() >= round.endAt)
end

local runtimeSeats = {}
local removeRoundPlayer

local random = Random.new()

---------------------------------------------------------------------
-- TIME
---------------------------------------------------------------------

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------
-- SESSION MEMBER IDS
---------------------------------------------------------------------

local function getExpectedIds()
	local value =
		sessionFolder:FindFirstChild(
			"MemberIdsJson"
		)

	if not value
		or not value:IsA("StringValue")
	then
		return {}
	end

	local ok, decoded =
		pcall(function()
			return HttpService:JSONDecode(
				value.Value
			)
		end)

	if not ok
		or type(decoded) ~= "table"
	then
		return {}
	end

	local result = {}
	local seen = {}

	for _, rawId in ipairs(decoded) do
		local id = tonumber(rawId)

		if id
			and id > 0
			and not seen[id]
		then
			seen[id] = true

			table.insert(
				result,
				id
			)
		end
	end

	return result
end

---------------------------------------------------------------------
-- PLAYER INDEX
---------------------------------------------------------------------

local function rebuildPlayerIndex()
	round.playerIndex = {}

	for index, targetPlayer in ipairs(
		round.players
		) do
		round.playerIndex[
		targetPlayer.UserId
		] = index
	end
end

local function indexInOrder(userId)
	userId = tonumber(userId)

	if not userId then
		return nil
	end

	for index, id in ipairs(
		round.order
		) do
		if tonumber(id) == userId then
			return index
		end
	end

	return nil
end

---------------------------------------------------------------------
-- INITIAL PLAYERS
---------------------------------------------------------------------

local function refreshPlayers()
	local expected =
		getExpectedIds()

	local result = {}

	for expectedIndex, userId in ipairs(
		expected
		) do
		local targetPlayer =
			Players:GetPlayerByUserId(
				userId
			)

		if targetPlayer
			and targetPlayer.Parent == Players
		then
			table.insert(
				result,
				targetPlayer
			)

			if not round.seatByUserId[userId] then
				round.seatByUserId[userId] =
					expectedIndex
			end
		end
	end

	round.players = result

	rebuildPlayerIndex()
end

---------------------------------------------------------------------
-- ROOM
---------------------------------------------------------------------

local function getRoom()
	return
		workspace:FindFirstChild(
			"SpyMatchRoom"
		)
		or workspace
end

local function findTableCenter()
	local root = getRoom()

	for _, name in ipairs({
		"CenterEmblem",
		"InnerFelt",
		"Felt",
		"TableTop",
		}) do
		local object =
			root:FindFirstChild(
				name,
				true
			)

		if object
			and object:IsA("BasePart")
		then
			return object
		end
	end

	return nil
end

---------------------------------------------------------------------
-- CHAIRS
---------------------------------------------------------------------

local function findChair(index)
	local gameTable = getRoom():FindFirstChild("GameTable")
	return gameTable or getRoom()
end

local function findCushion(index)
	local chair =
		findChair(index)

	if not chair then
		return nil
	end

	-- The authored chairs are grouped directly inside GameTable, and the
	-- actual seats are named Cushion1..4 rather than Chair1..4.
	local realCushion = chair:FindFirstChild("Cushion" .. tostring(index), true)
	if realCushion and realCushion:IsA("BasePart") then
		return realCushion
	end

	local anchor =
		chair:FindFirstChild(
			"SeatAnchor",
			true
		)

	if anchor
		and anchor:IsA("BasePart")
	then
		return anchor
	end

	local cushion =
		chair:FindFirstChild(
			"Cushion",
			true
		)

	if cushion
		and cushion:IsA("BasePart")
	then
		return cushion
	end

	return nil
end

---------------------------------------------------------------------
-- RUNTIME SEATS
---------------------------------------------------------------------

local function clearRuntimeSeats()
	local old =
		workspace:FindFirstChild(
			"MatchRuntimeSeats"
		)

	if old then
		old:Destroy()
	end

	table.clear(runtimeSeats)
end

local function fallbackSeatCFrame(index)
	local tablePart =
		findTableCenter()

	local center =
		tablePart
		and tablePart.Position
		or Vector3.new(0, 3, 0)

	local radius = 8.2

	local angles = {
		0,
		90,
		180,
		270,
	}

	local angle =
		math.rad(
			angles[index]
			or 0
		)

	local position =
		Vector3.new(
			center.X
			+ math.sin(angle) * radius,

			center.Y - 1.55,

			center.Z
			- math.cos(angle) * radius
		)

	return
		CFrame.lookAt(
			position,
			Vector3.new(
				center.X,
				position.Y,
				center.Z
			)
		)
end

local function buildRuntimeSeats()
	clearRuntimeSeats()

	local folder =
		Instance.new("Folder")

	folder.Name = "MatchRuntimeSeats"
	folder.Parent = workspace

	for index = 1, 4 do
		local seat =
			Instance.new("Seat")

		seat.Name =
			"MatchSeat"
			.. tostring(index)

		seat.Size =
			Vector3.new(
				2.1,
				0.35,
				2.1
			)

		seat.Anchored = true
		seat.Transparency = 1

		seat.CanCollide = false
		seat.CanTouch = false
		seat.CanQuery = false

		local cushion =
			findCushion(index)

		if cushion then
			seat.CFrame =
				cushion.CFrame
				* CFrame.new(
					0,
					0.48,
					0
				)
		else
			seat.CFrame =
				fallbackSeatCFrame(
					index
				)
		end

		seat.Parent = folder

		runtimeSeats[index] = seat
	end
end

---------------------------------------------------------------------
-- HUMANOID
---------------------------------------------------------------------

local function lockHumanoid(humanoid)
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false

	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Jumping,
		false
	)
end

local function unlockHumanoid(humanoid)
	humanoid.WalkSpeed = 16
	humanoid.AutoRotate = true

	if humanoid.UseJumpPower then
		humanoid.JumpPower = 50
	else
		humanoid.JumpHeight = 7.2
	end

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Jumping,
		true
	)

	humanoid.Sit = false
end

---------------------------------------------------------------------
-- SIT PLAYER
---------------------------------------------------------------------

local function sitPlayer(targetPlayer)
	local seatIndex =
		round.seatByUserId[
	targetPlayer.UserId
	]

	if not seatIndex then
		return false
	end

	local character =
		targetPlayer.Character

	if not character then
		return false
	end

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	local seat =
		runtimeSeats[
	seatIndex
	]

	if not humanoid
		or not root
		or not seat
	then
		return false
	end

	lockHumanoid(humanoid)

	character:PivotTo(
		seat.CFrame
			* CFrame.new(
				0,
				2.65,
				0
			)
	)

	task.wait(0.12)

	seat:Sit(humanoid)

	lockHumanoid(humanoid)

	return true
end

local function sitEveryone()
	buildRuntimeSeats()

	for _, targetPlayer in ipairs(
		round.players
		) do
		sitPlayer(
			targetPlayer
		)
	end
end

---------------------------------------------------------------------
-- KEEP SEATED
---------------------------------------------------------------------

local function maintainRoundSeats()
	task.spawn(function()
		while round.started
			and not round.finished
		do
			for _, targetPlayer in ipairs(
				round.players
				) do
				local seatIndex =
					round.seatByUserId[
				targetPlayer.UserId
				]

				local character =
					targetPlayer.Character

				local humanoid =
					character
					and character:
					FindFirstChildOfClass(
						"Humanoid"
					)

				local seat =
					seatIndex
					and runtimeSeats[
				seatIndex
				]

				if humanoid and seat then
					lockHumanoid(humanoid)

					if humanoid.SeatPart ~= seat then
						seat:Sit(humanoid)
					end
				end
			end

			task.wait(0.4)
		end
	end)
end

local function releaseEveryone()
	for _, targetPlayer in ipairs(
		round.players
		) do
		local character =
			targetPlayer.Character

		local humanoid =
			character
			and character:
			FindFirstChildOfClass(
				"Humanoid"
			)

		if humanoid then
			unlockHumanoid(humanoid)
		end
	end
end

---------------------------------------------------------------------
-- PUBLIC PLAYERS
---------------------------------------------------------------------

local function publicPlayers()
	local result = {}

	for _, targetPlayer in ipairs(
		round.players
		) do
		local progress =
			profileSnapshot(targetPlayer)

		table.insert(
			result,
			{
				userId =
					targetPlayer.UserId,

				name =
					targetPlayer.DisplayName,

				username =
					targetPlayer.Name,

				seat =
					round.seatByUserId[
				targetPlayer.UserId
				]
					or 1,

				level = progress.level,
				connected = round.disconnected[targetPlayer.UserId] == nil,
				reconnectUntil = round.disconnected[targetPlayer.UserId] or 0,
				xp = progress.xp,
				coins = progress.coins,
			}
		)
	end

	return result
end

---------------------------------------------------------------------
-- PHASE
---------------------------------------------------------------------

local function setPhase(
	phase,
	duration
)
	round.phase = phase

	if duration then
		round.endAt =
			now() + duration
	else
		round.endAt = 0
	end

	sessionFolder:SetAttribute(
		"RoundPhase",
		phase
	)

	sessionFolder:SetAttribute(
		"PhaseEndAt",
		round.endAt
	)
end

---------------------------------------------------------------------
-- BROADCAST / SNAPSHOT
---------------------------------------------------------------------

local lastPublicState = nil
local QuestionGuide=require(ReplicatedStorage.SpyShared.MatchGuide)
local questionAck=getRemote("QuestionAck")
local discussionSerial=0

local function broadcast(
	phase,
	extra
)
	extra = extra or {}

	extra.phase = phase
	extra.endAt = round.endAt
	extra.roundToken = round.token

	extra.players =
		publicPlayers()

	extra.partyName =
		sessionFolder:GetAttribute(
			"PartyName"
		)
		or "Стол"

	extra.ownerId =
		sessionFolder:GetAttribute(
			"OwnerId"
		)
		or 0

	extra.lap =
		round.lap

	extra.hintLaps =
		round.hintLaps

	extra.extraRounds =
		round.extraRounds
	if round.caseContext then extra.case = round.caseContext:public() end
 if phase=="Discuss" and round.discussion then extra.discussion=round.discussion:public()end
 if (phase=="Result"or phase=="Finished")and round.rematch then
  local readyIds={};local required=0
  for _,p in ipairs(getRemainingPlayers())do
   required+=1;if round.rematch.ready[p.UserId]then readyIds[#readyIds+1]=p.UserId end
  end
  table.sort(readyIds);extra.rematch={readyIds=readyIds,count=#readyIds,required=required,state=round.rematch.state,revision=round.rematch.revision,error=round.rematch.error}
 end

	lastPublicState = extra

	stateEvent:FireAllClients(
		extra
	)
end

RunService.Heartbeat:Connect(function()
 if round.phase~="Discuss"or round.terminal or not round.discussion then return end
 if round.discussion:tick()then broadcast("Discuss",{category=round.category})end
end)

snapshotFunction.OnServerInvoke =
	function(targetPlayer)
		local secret = nil

		if not round.terminal and round.rolesAssigned
			and round.playerIndex[targetPlayer.UserId]
			and targetPlayer:GetAttribute("SpySessionAccepted") == true
		then
			secret = {
				role =
					targetPlayer.UserId == round.spyId
					and "spy"
					or "detective",

				category = round.category,

				word =
					targetPlayer.UserId == round.spyId
					and nil
					or round.word,
			}
			-- Lua's `spy and nil or word` leaks the word; clear explicitly.
			if targetPlayer.UserId == round.spyId then
				secret.word = nil
				secret.roundToken = round.token
				secret.guessUsed = round.spyGuessUsed
			end
			if round.caseContext then
				secret.word = nil
				secret.caseFile = round.caseContext:private(targetPlayer.UserId, targetPlayer:GetAttribute("SpyLanguage") or "ru")
			end
		end

		return {
			state = lastPublicState,
			secret = secret,
			reward = round.rewardReceipts[targetPlayer.UserId],
		}
	end

---------------------------------------------------------------------
-- WAIT
---------------------------------------------------------------------

local function waitPhase(
	seconds,
	token
)
	local deadline =
		now() + seconds

	while now() < deadline do
		if round.token ~= token
			or round.finished
		then
			return false
		end

		task.wait(0.1)
	end

	return true
end

---------------------------------------------------------------------
-- RETURN DATA
---------------------------------------------------------------------

local function makeReturnOptions(reason)
	local options =
		Instance.new(
			"TeleportOptions"
		)

	local memberIds = {}

	for _, targetPlayer in ipairs(
		getRemainingPlayers()
		) do
		if targetPlayer.Parent == Players then
			table.insert(
				memberIds,
				targetPlayer.UserId
			)
		end
	end

	local ownerId =
		tonumber(
			sessionFolder:GetAttribute(
				"OwnerId"
			)
		)
		or 0

	if not table.find(
		memberIds,
		ownerId
		) then
		ownerId =
			memberIds[1]
			or 0
	end

	local visibility =
		"invite"

	for _, targetPlayer in ipairs(
		round.players
		) do
		if targetPlayer.Parent == Players then
			local ok, joinData =
				pcall(function()
					return
					targetPlayer:
					GetJoinData()
				end)

			local teleportData =
				ok
				and joinData
				and joinData.TeleportData

			if type(teleportData)
				== "table"
				and (
					teleportData.visibility
						== "public"
						or teleportData.visibility
						== "invite"
				)
			then
				visibility =
					teleportData.visibility

				break
			end
		end
	end

 local origin=round.rematch and round.rematch.origin
 if reason~="explicit_leave" and type(origin)=="string"and origin~=""then options.ServerInstanceId=origin end
	options:SetTeleportData({
		rules = activeRules,
		version = 1,

		fromMatch = true,

		sourcePlaceId =
			game.PlaceId,

		partyId =
			sessionFolder:GetAttribute(
				"PartyId"
			),

		partyCode =
			sessionFolder:GetAttribute(
				"PartyCode"
			),

		partyName =
			sessionFolder:GetAttribute(
				"PartyName"
			),

		ownerId =
			ownerId,

		capacity =
			sessionFolder:GetAttribute(
				"Capacity"
			)
			or 4,

		visibility =
			visibility,

		memberIds =
			memberIds,

		matchCancelled =
			reason ~= nil,

		reason =
			reason,

		finishedAt =
			os.time(),
	})

	return options
end

---------------------------------------------------------------------
-- RETURN TO LOBBY
---------------------------------------------------------------------

local returnLobbyEvent = getRemote("ReturnLobby")
local rewardJobs = {}
local MAX_RETURN_ATTEMPTS = 3
local returnAttempts = {}
local returnReasons = {}
local returnState = {}
local returnRetryScheduled = {}

local function setReturnState(targetPlayer, stateName)
	if not targetPlayer then return end
	returnState[targetPlayer.UserId] = stateName
	if targetPlayer.Parent == Players then
		targetPlayer:SetAttribute("SpyReturnState", stateName)
		targetPlayer:SetAttribute("SpyReturningToLobby", stateName == "returning" or stateName == "retrying")
	end
end

local function rematchOwnsTransport()
 local m = round.rematch
 return m and (m.state == "preparing" or m.state == "returning" or m.state == "uncertain")
end

local function reportReturnFailure(targetPlayer, reason, detail)
	if not targetPlayer or targetPlayer.Parent ~= Players then return end
	local userId=targetPlayer.UserId
	returnRetryScheduled[userId]=nil
	setReturnState(targetPlayer, "failed")
	warn("[MatchRoundServer] Return failed permanently:",targetPlayer.Name,reason or "finished",detail or "unknown")
	returnLobbyEvent:FireClient(targetPlayer, "Failed")
	stateEvent:FireClient(targetPlayer, {phase="ReturnFailed",reason=reason})
end

local queueReturn
local function scheduleReturnRetry(targetPlayer, reason, detail)
	if not targetPlayer or targetPlayer.Parent ~= Players then return end
	local userId=targetPlayer.UserId
	if returnRetryScheduled[userId] then return end
	local attempts=returnAttempts[userId] or 0
	if attempts >= MAX_RETURN_ATTEMPTS then reportReturnFailure(targetPlayer,reason,detail) return end
	returnRetryScheduled[userId]=true
	setReturnState(targetPlayer,"retrying")
	task.delay(0.9 + attempts * 0.8,function()
		returnRetryScheduled[userId]=nil
		if targetPlayer.Parent == Players and (returnState[userId]=="retrying" or returnState[userId]=="returning") then
			queueReturn(targetPlayer,reason,false,true)
		end
	end)
end

queueReturn = function(targetPlayer, reason, explicitRequest, isRetry, ownerNonce)
 if not explicitRequest and (rematchOwnsTransport()
  or (ownerNonce ~= nil and round.rematch and round.rematch.nonce ~= ownerNonce)) then return end
 ownerNonce = ownerNonce or (round.rematch and round.rematch.nonce)
 if targetPlayer and rewardJobs[targetPlayer.UserId] then
  if targetPlayer:GetAttribute("SpyRewardReturnQueued") then return end
  targetPlayer:SetAttribute("SpyRewardReturnQueued",true)
  if explicitRequest then returnLobbyEvent:FireClient(targetPlayer,"Saving") end
  task.spawn(function()
   while rewardJobs[targetPlayer.UserId] and targetPlayer.Parent==Players do task.wait(.1) end
   targetPlayer:SetAttribute("SpyRewardReturnQueued",nil)
   if targetPlayer.Parent==Players then queueReturn(targetPlayer,reason,explicitRequest,isRetry,ownerNonce) end
  end)
  return
 end
	if not targetPlayer or targetPlayer.Parent ~= Players then return end
	if RunService:IsStudio() then
		setReturnState(targetPlayer,"idle")
		if explicitRequest then returnLobbyEvent:FireClient(targetPlayer,"Studio") end
		return
	end
	local userId=targetPlayer.UserId
	local state=returnState[userId] or "idle"
	if explicitRequest and state=="failed" then
		returnAttempts[userId]=0; returnRetryScheduled[userId]=nil; state="idle"
	end
	if not isRetry and (state=="returning" or state=="retrying") then return end
	local nextAttempt=(returnAttempts[userId] or 0)+1
	if nextAttempt>MAX_RETURN_ATTEMPTS then reportReturnFailure(targetPlayer,reason,"attempt_limit") return end
	returnAttempts[userId]=nextAttempt
	returnReasons[userId]=reason or false
	setReturnState(targetPlayer,isRetry and "retrying" or "returning")
	if explicitRequest or nextAttempt==1 then returnLobbyEvent:FireClient(targetPlayer,"Returning") end
	local ok,err=pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID,{targetPlayer},makeReturnOptions(reason))
	end)
	if ok then return end
	warn("[MatchRoundServer] Return attempt failed:",targetPlayer.Name,nextAttempt,err)
	scheduleReturnRetry(targetPlayer,reason,tostring(err))
end

local function returnEveryoneToLobby(reason)
	if rematchOwnsTransport() then return end
	local owner = round.rematch
	local ownerNonce = owner and owner.nonce
	local players=getRemainingPlayers()
	if #players==0 then return end
	-- Bounded durability pass happens before return starts. One profile timeout cannot
	-- become an unbounded match-server trap.
	if profiles then pcall(function() profiles:flush(4) end) end
	-- Consent may change during the yielding save pass. Never let an older
	-- automatic continuation reclaim a group transport or reset its states.
	if rematchOwnsTransport() or round.rematch ~= owner
		or (owner and owner.nonce ~= ownerNonce) then return end
	if RunService:IsStudio() then
		print("[MatchRoundServer] Studio: would return",#players,"player(s). Reason:",reason or "finished")
		releaseEveryone()
		return
	end
	for _, targetPlayer in ipairs(getRemainingPlayers()) do
		setReturnState(targetPlayer,"idle")
		task.spawn(queueReturn,targetPlayer,reason,false,false,ownerNonce)
	end
end

local function pushRematch()
 if not round.rematch or not lastPublicState or not lastPublicState.result then return end
 local phase=round.phase=="Finished"and"Finished"or"Result"
 broadcast(phase,{result=lastPublicState.result,returning=phase=="Finished"})
end
local function rematchOrigin()
 for _,p in ipairs(getRemainingPlayers())do
  local ok,joined=pcall(function()return p:GetJoinData()end)
  local d=ok and type(joined)=="table"and joined.TeleportData
  if type(d)=="table"and d.sourcePlaceId==LOBBY_PLACE_ID and type(d.lobbyJobId)=="string"
   and #d.lobbyJobId<=128 and d.lobbyJobId:match("^[%w%-]+$")then return d.lobbyJobId end
 end
end
local function prepareRematch()
 local m=round.rematch;m.nonce+=1;local nonce=m.nonce
 local group=getRemainingPlayers();local deadline=now()+8
 m.state="preparing";m.error=nil;m.revision+=1;m.origin=rematchOrigin();pushRematch()
 local function valid()
  if round.rematch~=m or m.nonce~=nonce or m.state~="preparing"or now()>=deadline then return false end
  for _,p in ipairs(group)do if p.Parent~=Players or p:GetAttribute("SpyExplicitLeave")==true or not m.ready[p.UserId]then return false end end
  return #group>=3
 end
 local function fail(code)
  if m.nonce~=nonce then return end
  m.nonce+=1;m.state="failed";m.error=code;m.revision+=1
  for _,p in ipairs(group)do if p.Parent==Players then setReturnState(p,"idle")end end
  pushRematch()
 end
 task.delay(8,function()if m.nonce==nonce and m.state=="preparing"then fail("save_pending")end end)
 task.spawn(function()
  while valid()do
   local saving=false;for _,p in ipairs(group)do if rewardJobs[p.UserId]then saving=true;break end end
   if not saving then break end;task.wait(.1)
  end
  if not valid()then if m.nonce==nonce and m.state=="preparing"then fail("group_changed")end;return end
  if profiles then pcall(function()profiles:flush(4)end)end
  if not valid()then if m.nonce==nonce and m.state=="preparing"then fail("group_changed")end;return end
  if RunService:IsStudio()then fail("studio");return end
  local options=makeReturnOptions(nil)
  m.state="returning";m.revision+=1;m.transportNonce=nonce
  for _,p in ipairs(group)do
   returnAttempts[p.UserId]=1;returnReasons[p.UserId]=false;setReturnState(p,"returning")
   returnLobbyEvent:FireClient(p,"Returning")
  end
  pushRematch()
  local confirmed=false
  task.delay(10,function()
   if not confirmed and m.nonce==nonce and m.state=="returning"then
    m.nonce+=1;m.state="uncertain";m.error="teleport_unconfirmed";m.revision+=1
    for _,p in ipairs(group)do if p.Parent==Players then setReturnState(p,"failed");returnLobbyEvent:FireClient(p,"Failed")end end
    pushRematch()
   end
  end)
  local ok,err=pcall(function()return TeleportService:TeleportAsync(LOBBY_PLACE_ID,group,options)end)
  if m.nonce~=nonce then return end
  confirmed=true
  if not ok then fail("teleport_failed");warn("[SpyRematch] Group return failed:",tostring(err))
   for _,p in ipairs(group)do if p.Parent==Players then returnLobbyEvent:FireClient(p,"Failed")end end
  end
 end)
end
local function tryRematch()
 local m = round.rematch
 if not m or m.state == "preparing" or m.state == "returning" or m.state == "uncertain" then return end
 local group = getRemainingPlayers()
 if #group < 3 then return end
 for _, p in ipairs(group) do
  if not m.ready[p.UserId] or returnState[p.UserId] == "returning"
   or returnState[p.UserId] == "retrying" then return end
 end
 prepareRematch()
end
local function reconcileRematchDeparture(player)
 local m = round.rematch
 if not m then return end
 m.departed = m.departed or {}
 m.departed[player.UserId] = true
 m.ready[player.UserId] = nil
 if m.state == "preparing" then m.nonce += 1; m.state = "choosing"; m.error = nil end
 m.revision += 1
 pushRematch()
 tryRematch()
end
local function handleRematch(player,value)
 local m=round.rematch;local index=round.playerIndex[player.UserId]
 if not m or not lastPublicState or not lastPublicState.result or(round.phase~="Result"and round.phase~="Finished")
  or not index or round.players[index]~=player or player.Parent~=Players or player:GetAttribute("SpyExplicitLeave")==true
  or(m.departed and m.departed[player.UserId])
  or type(value)~="table"or value.roundToken~=round.token or type(value.ready)~="boolean"
  or m.state=="returning"or m.state=="uncertain"then return end
 if m.ready[player.UserId]==value.ready then return end
 m.rates=m.rates or{}
 if value.ready and now()-(m.rates[player.UserId]or-math.huge)<.5 then return end
 if value.ready then m.rates[player.UserId]=now()end
 if m.state=="preparing"then m.nonce+=1;m.state="choosing"end
 m.ready[player.UserId]=value.ready;m.revision+=1;m.error=nil;pushRematch()
 tryRematch()
end


---------------------------------------------------------------------
-- SCHEDULE RETURN
---------------------------------------------------------------------

local function scheduleReturn(
	reason
)
	if round.returnScheduled then
		return
	end

	round.returnScheduled = true

	task.delay(
		RETURN_DELAY,
		function()
			returnEveryoneToLobby(
				reason
			)
		end
	)
end

---------------------------------------------------------------------
-- ABORT
---------------------------------------------------------------------

local function abortRound(
	reason
)
	if round.finished
		or round.aborting
	then
		return
	end

	round.aborting = true
	round.finished = true
	closeReconnect()

	round.token += 1

	round.currentTurnUserId = nil
	round.hintTurnDone = true

	setPhase(
		"Finished",
		RETURN_DELAY
	)

	broadcast(
		"Finished",
		{
			cancelled = true,

			cancelReason =
				reason
				or "match_cancelled",

			returning = true,
		}
	)

	warn(
		"[MatchRoundServer] Match cancelled:",
		reason
	)

	scheduleReturn(
		reason
			or "match_cancelled"
	)
end

---------------------------------------------------------------------
-- TOPIC VOTE HELPERS
---------------------------------------------------------------------

local function topicVoteCount()
	local count = 0

	for userId in pairs(
		round.topicVotes
		) do
		if round.playerIndex[
			tonumber(userId)
			] then
			count += 1
		end
	end

	return count
end

local function topicVoteCounts()
	local counts = {}

	for voterId, themeId in pairs(
		round.topicVotes
		) do
		if round.playerIndex[
			tonumber(voterId)
			] then
			counts[themeId] =
				(counts[themeId] or 0)
				+ 1
		end
	end

	return counts
end

local function publicTopicOptions()
	local counts =
		topicVoteCounts()

	local result = {}

	for _, theme in ipairs(
		round.topicOptions
		) do
		table.insert(
			result,
			{
				id =
					theme.id,

				title =
					theme.title,

				votes =
					counts[
				theme.id
				]
					or 0,
			}
		)
	end

	return result
end

local function isValidTopicOption(
	themeId
)
	for _, theme in ipairs(
		round.topicOptions
		) do
		if theme.id == themeId then
			return true
		end
	end

	return false
end

local function chooseTopicWinner()
	local counts =
		topicVoteCounts()

	local highest = -1
	local leaders = {}

	for _, theme in ipairs(
		round.topicOptions
		) do
		local count =
			counts[theme.id]
			or 0

		if count > highest then
			highest = count

			leaders = {
				theme,
			}
		elseif count == highest then
			table.insert(
				leaders,
				theme
			)
		end
	end

	if #leaders == 0 then
		return nil
	end

	return
		leaders[
	random:NextInteger(
		1,
		#leaders
	)
	]
end

---------------------------------------------------------------------
-- TOPIC VOTE
---------------------------------------------------------------------

local function runTopicVote(
	token
)
	local pool = MatchRules.pool(activeRules,ThemeCatalog,random)
 local skipVote = #pool==1 or activeRules.topicMode=="random"
 round.topicOptions={}
 local amount=skipVote and math.min(1,#pool) or math.min(TOPIC_OPTIONS_COUNT,#pool)
 for i=1,amount do table.insert(round.topicOptions,pool[i]) end

	if type(round.topicOptions)
		~= "table"
		or #round.topicOptions == 0
	then
		abortRound(
			"theme_catalog_error"
		)

		return nil
	end

	round.topicVotes = {}
	round.topicVoteClosed = false
	round.selectedThemeId = nil

	setPhase("TopicVote",skipVote and 0 or TOPIC_VOTE_SECONDS)
 if not skipVote then broadcast("TopicVote",
		{
			topicOptions =
				publicTopicOptions(),

			votedCount = 0,

			totalPlayers =
				#round.players,
		}
	)

	end
	local deadline = now() + (skipVote and 0 or TOPIC_VOTE_SECONDS)

	while now() < deadline do
		if round.token ~= token
			or round.finished
		then
			return nil
		end

		if topicVoteCount()
			>= #round.players
		then
			break
		end

		task.wait(0.1)
	end

	round.topicVoteClosed = true

	local winner =
		chooseTopicWinner()

	if not winner then
		abortRound(
			"no_topic"
		)

		return nil
	end

	round.selectedThemeId =
		winner.id

	round.category =
		winner.title

	sessionFolder:SetAttribute(
		"SelectedThemeId",
		winner.id
	)

	sessionFolder:SetAttribute(
		"SelectedThemeTitle",
		winner.title
	)

	setPhase(
		"TopicChosen",
		TOPIC_CHOSEN_SECONDS
	)

	broadcast(
		"TopicChosen",
		{
			selectedTheme = {
				id =
					winner.id,

				title =
					winner.title,
			},

			topicOptions =
				publicTopicOptions(),

			topicVotes =
				topicVoteCounts(),

			votedCount =
				topicVoteCount(),

			totalPlayers =
				#round.players,
		}
	)

	if not waitPhase(
		TOPIC_CHOSEN_SECONDS,
		token
		) then
		return nil
	end

	return winner
end

---------------------------------------------------------------------
-- SECRET
---------------------------------------------------------------------

local function chooseSecrets(
	theme
)
	if not theme
		or type(theme) ~= "table"
	then
		abortRound(
			"invalid_theme"
		)

		return false
	end

	if type(theme.words) ~= "table"
		or #theme.words == 0
	then
		abortRound(
			"theme_without_words"
		)

		return false
	end

	if #round.players
		<
		(
			RunService:IsStudio()
				and 1
				or MINIMUM_LIVE_PLAYERS
		)
	then
		abortRound(
			"not_enough_players"
		)

		return false
	end

	round.word =
		theme.words[
	random:NextInteger(
		1,
		#theme.words
	)
	]

    local ids, historyById = {}, {}
    for _, member in ipairs(round.players) do
        ids[#ids + 1] = member.UserId
        historyById[member.UserId] = profiles and profiles:history(member.UserId) or {}
    end
    local spyId = RoleRules.chooseSpy(ids, historyById, function(a, b)
        return random:NextInteger(a, b)
    end)
    local spy
    for _, member in ipairs(round.players) do
        if member.UserId == spyId then spy = member; break end
    end

	round.spyId =
		spy.UserId

	round.selectedThemeId =
		theme.id

	round.category =
		theme.title

	round.rolesAssigned = true

	round.order = {}

	for _, targetPlayer in ipairs(
		round.players
		) do
		table.insert(
			round.order,
			targetPlayer.UserId
		)
	end

	for index = #round.order, 2, -1 do
		local other =
			random:NextInteger(
				1,
				index
			)

		round.order[index],
			round.order[other] =
			round.order[other],
			round.order[index]
	end

	local ok, encoded =
		pcall(function()
			return HttpService:JSONEncode(
				round.order
			)
		end)

	if ok then
		sessionFolder:SetAttribute(
			"TurnOrderJson",
			encoded
		)
	end

	return true
end

---------------------------------------------------------------------
-- CARDS
---------------------------------------------------------------------

local function sendCards()
	for _, targetPlayer in ipairs(
		round.players
		) do
		if targetPlayer.Parent ~= Players then continue end
		if round.caseContext then
			cardEvent:FireClient(targetPlayer, {
				role=targetPlayer.UserId == round.spyId and "spy" or "detective",
				roundToken=round.token, guessUsed=round.spyGuessUsed, category=round.category,
				caseFile=round.caseContext:private(targetPlayer.UserId,targetPlayer:GetAttribute("SpyLanguage") or "ru"),
			})
			continue
		end
		if targetPlayer.UserId
			== round.spyId
		then
			cardEvent:FireClient(
				targetPlayer,
				{
					role = "spy",
					roundToken = round.token,
					guessUsed = round.spyGuessUsed,

					category =
						round.category,

					word = nil,
				}
			)
		else
			cardEvent:FireClient(
				targetPlayer,
				{
					role =
						"detective",

					category =
						round.category,

					word =
						round.word,
				}
			)
		end
	end
end

---------------------------------------------------------------------
-- HINT DONE
---------------------------------------------------------------------

local function completeCurrentHintTurn(
	targetPlayer
)
	if not round.started
		or round.finished
	then
		return false
	end

	if round.phase ~= "Hint" then
		return false
	end

	if not targetPlayer then
		return false
	end

	if targetPlayer.UserId
		~= round.currentTurnUserId
	then
		return false
	end

	if round.hintTurnDone then
		return false
	end

	round.hintTurnDone = true
	if round.participation then round.participation:respond(targetPlayer.UserId, "hint") end

	return true
end

---------------------------------------------------------------------
-- HINT LAP
---------------------------------------------------------------------

local function runHintLap(
	token,
	lapNumber
)
	round.lap = lapNumber

	local index = 1

	while index <= #round.order do
		if round.token ~= token
			or round.finished
		then
			return false
		end

		local userId =
			round.order[index]

		if not round.playerIndex[
			userId
			] then
			table.remove(
				round.order,
				index
			)

			continue
		end

		round.currentTurnUserId =
			userId

		round.turnIndex =
			index

		round.hintTurnDone =
			false

		sessionFolder:SetAttribute(
			"CurrentTurnUserId",
			userId
		)

		sessionFolder:SetAttribute(
			"CurrentTurnIndex",
			index
		)

		sessionFolder:SetAttribute(
			"CurrentHintLap",
			lapNumber
		)

		setPhase(
			"Hint",
			HINT_SECONDS
		)

		broadcast(
			"Hint",
			{
				turnUserId =
					userId,

				turnIndex =
					index,

				category =
					round.category,
			}
		)

		local deadline = now() + HINT_SECONDS

		local endedEarly =
			false

		while now() < deadline do
			if round.token ~= token
				or round.finished
			then
				return false
			end

			if round.hintTurnDone then
				endedEarly = true
				break
			end
			-- A disconnected seat is preserved, but cannot hold each turn open.
			if round.disconnected[userId] then
				deadline = math.min(deadline, now() + 3)
			end

			task.wait(0.05)
		end

		if round.finished then
			return false
		end
		if not endedEarly and not round.disconnected[userId] and round.participation
			and round.participation:miss(userId) then
			local missing = round.players[round.playerIndex[userId]]
			removeRoundPlayer(missing)
			if round.finished then return false end
		end

		if endedEarly then
			task.wait(
				EARLY_TURN_ADVANCE_DELAY
			)
		else
			task.wait(0.15)
		end

		local currentPosition =
			indexInOrder(
				userId
			)

		if currentPosition then
			index =
				currentPosition + 1
		else
			index =
				math.max(
					1,
					round.turnIndex
				)
		end
	end

	round.currentTurnUserId = nil
	round.hintTurnDone = false
	round.turnIndex = 0

	sessionFolder:SetAttribute(
		"CurrentTurnUserId",
		0
	)

	sessionFolder:SetAttribute(
		"CurrentTurnIndex",
		0
	)

	return true
end

---------------------------------------------------------------------
-- INITIAL HINTS
---------------------------------------------------------------------

local function runInitialHints(
	token
)
	round.hintLaps =
		INITIAL_HINT_LAPS

	for lap = 1, INITIAL_HINT_LAPS do
		if not runHintLap(
			token,
			lap
			) then
			return false
		end
	end

	return true
end

---------------------------------------------------------------------
-- EXTRA HINT
---------------------------------------------------------------------

local function runExtraHintRound(
	token
)
	if round.token ~= token or round.finished or round.terminal then return false end
	round.extraRounds += 1
	round.hintLaps += 1

	local newLap =
		round.hintLaps

	setPhase(
		"ExtraRound",
		EXTRA_ROUND_ANNOUNCE_SECONDS
	)

	broadcast(
		"ExtraRound",
		{
			category =
				round.category,

			extraRound =
				round.extraRounds,

			newLap =
				newLap,
		}
	)

	if not waitPhase(
		EXTRA_ROUND_ANNOUNCE_SECONDS,
		token
		) then
		return false
	end

	return
		runHintLap(
			token,
			newLap
		)
end

---------------------------------------------------------------------
-- DISCUSSION
---------------------------------------------------------------------

local function runDiscussion(
	token,
	duration
)
	if round.token ~= token or round.finished or round.terminal then return false end
	duration =
		duration
		or DISCUSS_SECONDS

	round.currentTurnUserId =
		nil

	sessionFolder:SetAttribute(
		"CurrentTurnUserId",
		0
	)

	setPhase(
		"Discuss",
		duration
	)

 discussionSerial+=1
 local ids={};for _,p in ipairs(round.players)do ids[#ids+1]=p.UserId end
 round.discussion=QuestionGuide.newDiscussion(ids,tostring(round.token)..":"..discussionSerial,now,round.endAt)
	broadcast(
		"Discuss",
		{
			category =
				round.category,
		}
	)

	return
		waitPhase(
			duration,
			token
		)
end

---------------------------------------------------------------------
-- VOTE HELPERS
---------------------------------------------------------------------

local function voteCount()
	local count = 0

	for voterId in pairs(
		round.votes
		) do
		if round.playerIndex[
			tonumber(voterId)
			] then
			count += 1
		end
	end

	return count
end

local function requiredMajority()
	return
		math.floor(
			#round.players / 2
		)
		+ 1
end

local function calculateVoteDecision()
	local playerCounts = {}
	local extraRoundVotes = 0

	for voterId, vote in pairs(
		round.votes
		) do
		if round.playerIndex[
			tonumber(voterId)
			] then
			if vote
				== EXTRA_ROUND_VOTE_VALUE
			then
				extraRoundVotes += 1
			else
				local targetId =
					tonumber(vote)

				if targetId
					and round.playerIndex[
					targetId
					]
				then
					playerCounts[
					targetId
					] =
						(
							playerCounts[
							targetId
							]
							or 0
						)
						+ 1
				end
			end
		end
	end

	local needed =
		requiredMajority()

	if activeRules.allowExtraRound and extraRoundVotes >= needed then
		return {
			type =
				"extra_round",

			required =
				needed,

			extraRoundVotes =
				extraRoundVotes,

			counts =
				playerCounts,
		}
	end

	local bestId = nil
	local bestCount = 0

	for targetId, count in pairs(
		playerCounts
		) do
		if count > bestCount then
			bestId = targetId
			bestCount = count
		end
	end

	local accusedId = nil
	local reason

	if bestId
		and bestCount >= needed
	then
		accusedId = bestId

		if accusedId
			== round.spyId
		then
			reason = "caught"
		else
			reason = "wrong"
		end
	else
		reason =
			"no_majority"
	end

	return {
		type = "result",

		result = {
			spyId =
				round.spyId,

			accusedId =
				accusedId,

			word =
				round.word,

			category =
				round.category,

			reason =
				reason,

			caught =
				reason == "caught",

			counts =
				playerCounts,

			required =
				needed,

			extraRoundVotes =
				extraRoundVotes,
		},
	}
end

---------------------------------------------------------------------
-- VOTING
---------------------------------------------------------------------

local function runVoting(
	token
)
	if round.token ~= token or round.finished or round.terminal then return nil end
	round.votes = {}
	round.voteOrder = {}
	round.voteClosed = false
	round.voteRestartRequested = false

	setPhase(
		"Vote",
		VOTE_SECONDS
	)

	broadcast(
		"Vote",
		{
			required =
				requiredMajority(),

			category =
				round.category,

			allowExtraRound = activeRules.allowExtraRound,

			extraRoundValue =
				EXTRA_ROUND_VOTE_VALUE,
		}
	)

	local deadline =
		now()
		+ VOTE_SECONDS

	local reconnectWaitLimit = deadline + 90
	while now() < deadline or (next(round.disconnected) ~= nil and now() < reconnectWaitLimit) do
		if round.token ~= token
			or round.finished
		then
			return nil
		end

		if round.voteRestartRequested then
			round.voteClosed = true

			return {
				type =
					"restart_vote",
			}
		end

		if voteCount()
			>= #round.players and next(round.disconnected) == nil
		then
			break
		end

		task.wait(0.1)
	end

	round.voteClosed = true
	-- No synthetic ballots: a missed vote is recorded only as inactivity.
	local forfeits = {}
	for _, voter in ipairs(round.players) do
		if not round.votes[voter.UserId] and not round.disconnected[voter.UserId]
			and round.participation and round.participation:miss(voter.UserId) then
			table.insert(forfeits, voter)
		end
	end
	for _, voter in ipairs(forfeits) do removeRoundPlayer(voter) end
	if round.finished then return nil end

	if round.voteRestartRequested then
		return {
			type =
				"restart_vote",
		}
	end

	local decision = calculateVoteDecision()
	local facts = ReconnectModule.ballotFacts(round.spyId, decision.result or decision, round.votes, round.voteOrder)
	for id in pairs(facts.survived) do round.survivedVote[id] = true end
	round.firstCorrect = facts.firstCorrect
	return decision
end

---------------------------------------------------------------------
-- REMOVE PLAYER MID ROUND
---------------------------------------------------------------------

removeRoundPlayer = function(
	targetPlayer
)
	if not targetPlayer then
		return
	end

	local userId =
		targetPlayer.UserId

	local oldPlayerIndex =
		round.playerIndex[
	userId
	]

	if not oldPlayerIndex then
		return
	end
	round.disconnected[userId] = nil
	if round.participation then round.participation:forfeit(userId) end
	local sessionId = reconnectSessionId()
	if sessionId and sessionId ~= "" then task.spawn(function() reconnect:clearUser(userId, sessionId) end) end

	if round.rolesAssigned
		and round.spyId == userId
	then
		for index, playerObject in ipairs(
			round.players
			) do
			if playerObject.UserId == userId then
				table.remove(
					round.players,
					index
				)

				break
			end
		end

		rebuildPlayerIndex()

		abortRound(
			"participant_forfeit"
		)

		return
	end

	for index, playerObject in ipairs(
		round.players
		) do
		if playerObject.UserId == userId then
			table.remove(
				round.players,
				index
			)

			break
		end
	end

	rebuildPlayerIndex()

	round.topicVotes[
	userId
	] = nil

	round.votes[
	userId
	] = nil

	for voterId, vote in pairs(
		round.votes
		) do
		if tonumber(vote) == userId then
			round.votes[
			voterId
			] = nil
		end
	end

	local removedOrderIndex =
		indexInOrder(
			userId
		)

	if removedOrderIndex then
		table.remove(
			round.order,
			removedOrderIndex
		)
	end

	if round.currentTurnUserId
		== userId
	then
		round.turnIndex =
			removedOrderIndex
			or round.turnIndex

		round.currentTurnUserId =
			nil

		round.hintTurnDone =
			true
	end

	local minimum =
		RunService:IsStudio()
		and 1
		or 2

	if #round.players < minimum then
		abortRound(
			"not_enough_players"
		)

		return
	end

	if round.phase == "TopicVote"
		and not round.topicVoteClosed
	then
		broadcast(
			"TopicVote",
			{
				topicOptions =
					publicTopicOptions(),

				votedCount =
					topicVoteCount(),

				totalPlayers =
					#round.players,
			}
		)

	elseif round.phase == "Hint" then
		if round.currentTurnUserId then
			local newIndex =
				indexInOrder(
					round.currentTurnUserId
				)

			if newIndex then
				round.turnIndex =
					newIndex

				broadcast(
					"Hint",
					{
						turnUserId =
							round.currentTurnUserId,

						turnIndex =
							newIndex,

						category =
							round.category,
					}
				)
			end
		end

	elseif round.phase == "Discuss" then
		broadcast(
			"Discuss",
			{
				category =
					round.category,
			}
		)

	elseif round.phase == "Vote" then
		round.voteRestartRequested =
			true

		round.voteClosed =
			true
	end

	print(
		"[MatchRoundServer] Player removed:",
		targetPlayer.Name,
		"remaining:",
		#round.players
	)
end

---------------------------------------------------------------------
-- MATCH REWARDS
---------------------------------------------------------------------

local function rewardOperationId(userId)
 local id=tostring(sessionFolder:GetAttribute("SessionId") or "")
 if id=="" then id=game.JobId~="" and game.JobId or tostring(sessionFolder:GetAttribute("StartedAt") or 0) end
 return "match:"..id..":"..tostring(userId)
end

local function buildRoundHistory(
	finalResult
)
	local names = {}

	for _, targetPlayer in ipairs(
		round.players
		) do
		names[targetPlayer.UserId] =
			targetPlayer.DisplayName
	end

	local ballots = {}

	for _, voterId in ipairs(
		round.order
		) do
		local vote =
			round.votes[voterId]

		local targetId =
			tonumber(vote)

		table.insert(
			ballots,
			{
				voterId =
					voterId,

				voterName =
					names[voterId],

				targetId =
					targetId,

				targetName =
					targetId
					and names[targetId]
					or nil,
			}
		)
	end

	return {
		word =
			finalResult
			and finalResult.word
			or round.word,

		spyId =
			finalResult
			and finalResult.spyId
			or round.spyId,

		at =
			os.time(),

		ballots =
			ballots,

		category =
			finalResult
			and finalResult.category
			or round.category,

		caught =
			finalResult
			and finalResult.caught
			or false,

		reason =
			finalResult
			and finalResult.reason
			or nil,
	}
end

-- Private result receipts accompany snapshots so slow-loading clients also see
-- the real save state. A victory and a successful persistent write are separate.
local function publishRewardReceipt(targetPlayer, data)
 round.rewardReceipts[targetPlayer.UserId] = data
 targetPlayer:SetAttribute("SpyRewardState", data.state)
 targetPlayer:SetAttribute("SpyMatchWon", data.won)
 if targetPlayer.Parent == Players then rewardEvent:FireClient(targetPlayer, data) end
end

-- Rewards are for a completed server round and its original live roster.
-- closeReconnect marks normal results terminal, so terminal is not a cancellation flag.
local function eligibleForCompletedMatch(targetPlayer)
 local userId = targetPlayer.UserId
 local index = round.playerIndex[userId]
 return round.started == true and round.rolesAssigned == true and round.resultStarted == true
  and round.aborting ~= true and targetPlayer.Parent == Players
  and targetPlayer:GetAttribute("SpyExplicitLeave") ~= true
  and index ~= nil and round.players[index] == targetPlayer and round.disconnected[userId] == nil
  and round.participation ~= nil and round.participation:eligible(userId) == true
end

local function awardRoundRewards(finalResult)
 if round.rewardsStarted then return end
 round.rewardsStarted = true
 local history = buildRoundHistory(finalResult)
 for _, targetPlayer in ipairs(round.players) do
  if targetPlayer.Parent == Players then
   local userId = targetPlayer.UserId
   local isSpy = userId == round.spyId
   local spyWon = finalResult.caught ~= true
   local won = (isSpy and spyWon) or (not isSpy and not spyWon)
   local eligible = eligibleForCompletedMatch(targetPlayer)
   if not eligible or not profiles then
    publishRewardReceipt(targetPlayer, {state=eligible and "failed" or "ineligible",won=won,
     role=isSpy and "spy" or "detective",code=eligible and "profile_unavailable" or "no_reward"})
   else
    local operationId = rewardOperationId(userId)
    local command = {kind="reward",participated=true,eligibleMatch=true,won=won,
     spyWin=isSpy and spyWon,firstCorrect=round.firstCorrect==userId and finalResult.caught==true,
     survivedVote=round.survivedVote[userId]==true,now=os.time(),highStakesPayout=0,history=history}
    round.rewardPending += 1
    rewardJobs[userId] = true
    publishRewardReceipt(targetPlayer, {state="saving",won=won,role=isSpy and "spy" or "detective"})
    task.spawn(function()
     local staged = false
     if not RunService:IsStudio() then
      local ok,value=pcall(function()
       return reconnect:stageReward(userId,tostring(sessionFolder:GetAttribute("SessionId") or ""),game.JobId,operationId,command)
      end)
      staged=ok and value and true or false
     end
     local receipt={ok=false,code="profile_unavailable"}
     local xpBefore=nil
     for attempt=1,4 do
      if ensureProfileLoaded(targetPlayer) then
       if xpBefore==nil then xpBefore=tonumber(profiles:public(userId).xp) or 0 end
       local ok,value=pcall(function() return profiles:transact(userId,operationId,command) end)
       receipt=ok and type(value)=="table" and value or {ok=false,code="save_failed"}
      end
      if receipt.ok then break end
      profileLoadState[userId]=nil
      if attempt<4 then task.wait(attempt) end
     end
     local data={state=receipt.ok and "saved" or (staged and "pending" or "failed"),won=won,
      role=isSpy and "spy" or "detective",code=receipt.code,studio=RunService:IsStudio()}
     if receipt.ok then
      local public=profiles:public(userId)
      data.amount=tonumber(receipt.coins) or 0
      data.rolls=math.max(0,math.floor(tonumber(receipt.rolls) or 0))
      data.rollsBalance=math.max(0,math.floor(tonumber(public.rolls) or 0))
      data.xp=math.max(0,(tonumber(public.xp) or 0)-(xpBefore or tonumber(public.xp) or 0))
      data.newBalance=tonumber(public.coins) or 0
      data.previousBalance=math.max(0,data.newBalance-data.amount)
      data.totalXP=tonumber(public.xp) or 0
      data.wins=tonumber(public.wins) or 0
      data.rounds=tonumber(public.rounds) or 0
      data.milestone=receipt.milestone==true
      publishProfileAttributes(targetPlayer)
      if staged then task.spawn(function() reconnect:ackReward(userId,operationId) end) end
     else
      warn("[MatchRoundServer] Reward not saved:",targetPlayer.Name,receipt.code or "unknown",data.state)
     end
     publishRewardReceipt(targetPlayer,data)
     rewardJobs[userId]=nil
     round.rewardPending=math.max(0,round.rewardPending-1)
    end)
   end
  end
 end
end

local function waitForRewardSettlement(
	timeout
)
	if not profiles then
		return
	end

	local deadline =
		os.clock()
		+ (
			tonumber(timeout)
			or 4
		)

	while round.rewardPending > 0
		and os.clock() < deadline
	do
		task.wait(0.05)
	end

	if round.rewardPending > 0 then
		warn(
			"[MatchRoundServer] Reward settlement still pending:",
			round.rewardPending
		)
	end
end

---------------------------------------------------------------------
-- MAIN ROUND
---------------------------------------------------------------------

-- One settlement path for the ballot and the spy's private guess.
local function finishRound(finalResult, token)
	if round.token ~= token or round.finished or round.aborting or round.resultStarted then return end
	round.resultStarted = true
	round.currentTurnUserId = nil
	round.turnIndex = 0
	round.hintTurnDone = false
	sessionFolder:SetAttribute("CurrentTurnUserId", 0)
	sessionFolder:SetAttribute("CurrentTurnIndex", 0)
	if round.finished then
		return
	end

	closeReconnect()
	setPhase(
		"Result",
		RESULT_SECONDS
	)

	-- Establish every reward/return fence before clients can press Return.
	awardRoundRewards(finalResult)
	if round.caseContext then
		round.caseContext:setStage("result")
		finalResult.caseId = round.caseContext.fileId
		round.caseContext:push()
	end
	round.rematch={ready={},state="choosing",revision=0,nonce=0}
	broadcast("Result", {result=finalResult})

	if not waitPhase(
		RESULT_SECONDS,
		token
		) then
		return
	end

	waitForRewardSettlement(
		4
	)

	round.finished = true

	setPhase(
		"Finished",
		RETURN_DELAY
	)

	broadcast(
		"Finished",
		{
			result =
				finalResult,

			returning =
				true,
		}
	)

	scheduleReturn(nil)
end

-- Exact catalog-word comparison, with Russian case/ё and word separators.
-- The draft is private input, never public text or persistent history.
local I18n = require(ReplicatedStorage:WaitForChild("SpyShared"):WaitForChild("I18n"))
local function normalizeSpyGuess(value)
	if type(value) ~= "string" or #value > 320 then return nil end
	local length = utf8.len(value)
	if not length or length == 0 or length > 80 then return nil end
	local parts = {}
	local separated = false
	for _, code in utf8.codes(value) do
		if code < 32 or code == 127 or code == 0x200B or code == 0x200E or code == 0x200F
			or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069) then return nil end
		if (code >= 65 and code <= 90) or (code >= 0x410 and code <= 0x42F) then code += 32 end
		if code == 0x401 or code == 0x451 then code = 0x435 end
		if code == 32 or code == 0xA0 or (code >= 0x2000 and code <= 0x200A)
			or code == 45 or (code >= 0x2010 and code <= 0x2014) then
			separated = #parts > 0
		else
			if separated then table.insert(parts, " "); separated = false end
			table.insert(parts, utf8.char(code))
		end
	end
	return #parts > 0 and table.concat(parts) or nil
end

local function isCorrectSpyGuess(guess, word)
	if not guess then return false end
	for _, language in ipairs({"ru", "en", "zh"}) do
		if guess == normalizeSpyGuess(I18n.word(language, word)) then return true end
	end
	return false
end

local function trySpyGuess(targetPlayer, payload)
	local id = targetPlayer.UserId
	local function reject(code)
		actionEvent:FireClient(targetPlayer, {kind="SpyGuessReceipt", ok=false, code=code,
			roundToken=round.token, used=round.spyGuessUsed and id == round.spyId})
	end
	local index = round.playerIndex[id]
	if not round.started or not round.rolesAssigned or id ~= round.spyId
		or not index or round.players[index] ~= targetPlayer or targetPlayer.Parent ~= Players
		or targetPlayer:GetAttribute("SpySessionAccepted") ~= true then reject("not_spy"); return end
	if round.finished or round.terminal or round.resultStarted or round.aborting then reject("closed"); return end
	if round.spyGuessUsed then reject("used"); return end
	if type(payload) ~= "table" or payload.roundToken ~= round.token then reject("stale"); return end
	if (round.phase ~= "Hint" and round.phase ~= "Discuss") or round.endAt <= now() then reject("closed"); return end
	local guess = normalizeSpyGuess(payload.word)
	if not guess then reject("invalid"); return end
	local correct = isCorrectSpyGuess(guess, round.word)
	-- Consume and invalidate the old coroutine before any yielding operation.
	round.spyGuessUsed = true
	round.token += 1
	round.firstCorrect = nil -- A failed guess is not a correct ballot by an agent.
	if round.participation then round.participation:respond(id, "guess") end
	actionEvent:FireClient(targetPlayer, {kind="SpyGuessReceipt", ok=true, used=true,
		correct=correct, roundToken=payload.roundToken})
	local result = {spyId=round.spyId, word=round.word, category=round.category,
		caught=not correct, reason=correct and "spy_guessed" or "spy_guess_wrong"}
	task.spawn(finishRound, result, round.token)
end

local function runRound()
	if round.started
		or round.finished
	then
		return
	end

	refreshPlayers()

	local minimum =
		RunService:IsStudio()
		and 1
		or MINIMUM_LIVE_PLAYERS

	if #round.players < minimum then
		return
	end

 local okRules,decodedRules=pcall(function() return HttpService:JSONDecode(sessionFolder:GetAttribute("RulesJson") or "null") end)
 activeRules=MatchRules.sanitize(okRules and decodedRules or nil) or MatchRules.defaults()
 INITIAL_HINT_LAPS=activeRules.hintLaps
 DISCUSS_SECONDS=activeRules.discussionSeconds
 HINT_SECONDS=activeRules.hintSeconds
 round.started = true
	sessionFolder:SetAttribute("RosterLocked", true)
	round.finished = false
	round.aborting = false
	local startingIds = {}
	for _, player in ipairs(round.players) do table.insert(startingIds, player.UserId) end
	round.participation = ReconnectModule.newParticipation(startingIds)
	local sessionId = reconnectSessionId()
	if sessionId and sessionId ~= "" then
		if not reconnect:markLive(sessionId, game.JobId, startingIds) then
			warn("[MatchRoundServer] Reconnect temporarily unavailable; no unverified admission allowed")
		end
	end
	-- Only this script owns departures once the round starts. Preserve the old
	-- Player seat/role until either this deadline or authenticated replacement.
	task.spawn(function()
		while not round.finished and not round.terminal do
			for id, deadline in pairs(round.disconnected) do
				if os.time() >= deadline then
					local index = round.playerIndex[id]
					if index then removeRoundPlayer(round.players[index]) else round.disconnected[id] = nil end
				end
			end
			publishConnections()
			task.wait(0.25)
		end
	end)

	round.token += 1

	round.extraRounds = 0
	round.hintLaps = INITIAL_HINT_LAPS
	round.spyGuessUsed = false
	round.resultStarted = false
	round.rewardsStarted = false
	round.rewardReceipts = {}
	round.rewardPending = 0

	preloadProfiles(
		round.players
	)

	local token =
		round.token

	sitEveryone()

	maintainRoundSeats()

	task.wait(0.75)

	if round.finished then
		return
	end

	if activeRules.mode == "case" then
		local Core = require(ServerStorage:WaitForChild("SpyModules"):WaitForChild("CaseRound"))
		Core.run({round=round,players=Players,rs=ReplicatedStorage,modules=ServerStorage.SpyModules,
			random=random,session=sessionFolder,now=now,chooseSecrets=chooseSecrets,sendCards=sendCards,
			setPhase=setPhase,broadcast=broadcast,waitPhase=waitPhase,runInitialHints=runInitialHints,
			runDiscussion=runDiscussion,runVoting=runVoting,runExtraHintRound=runExtraHintRound,finishRound=finishRound,
			introSeconds=INTRO_SECONDS,roleSeconds=ROLE_SECONDS,discussionSeconds=DISCUSS_SECONDS,restartSeconds=VOTE_RESTART_DISCUSS_SECONDS})
		return
	end

	local chosenTheme =
		runTopicVote(
			token
		)

	if not chosenTheme
		or round.finished
	then
		return
	end

	if not chooseSecrets(
		chosenTheme
		) then
		return
	end

	setPhase(
		"Intro",
		INTRO_SECONDS
	)

	broadcast(
		"Intro",
		{
			category =
				round.category,

			themeId =
				round.selectedThemeId,
		}
	)

	sendCards()

	if not waitPhase(
		INTRO_SECONDS,
		token
		) then
		return
	end

	setPhase(
		"Role",
		ROLE_SECONDS
	)

	broadcast(
		"Role",
		{
			category =
				round.category,

			themeId =
				round.selectedThemeId,
		}
	)

	if not waitPhase(
		ROLE_SECONDS,
		token
		) then
		return
	end

	if not runInitialHints(
		token
		) then
		return
	end

	local finalResult = nil

	local nextDiscussionTime =
		DISCUSS_SECONDS

	while not finalResult do
		if round.finished then
			return
		end

		if not runDiscussion(
			token,
			nextDiscussionTime
			) then
			return
		end

		nextDiscussionTime =
			DISCUSS_SECONDS

		local decision =
			runVoting(
				token
			)

		if not decision
			or round.finished
		then
			return
		end

		if decision.type
			== "restart_vote"
		then
			nextDiscussionTime =
				VOTE_RESTART_DISCUSS_SECONDS

		elseif decision.type
			== "extra_round"
		then
			if not runExtraHintRound(
				token
				) then
				return
			end

			nextDiscussionTime =
				DISCUSS_SECONDS

		else
			finalResult =
				decision.result
		end
	end

	finishRound(finalResult, token)
end

---------------------------------------------------------------------
-- ACTIONS
---------------------------------------------------------------------

local matchEmoteAt={}
actionEvent.OnServerEvent:Connect(
	function(
		targetPlayer,
		action,
		value
	)
		if targetPlayer:GetAttribute("SpySessionAccepted") ~= true then return end
  if round.terminal and action~="Rematch"and action~="Emote"then return end
        if action=="ChatRetry" then return end
        if action == "ClientReady" then
			if value == 22 then targetPlayer:SetAttribute("SpyMatchClientReady", true) end
			return
		end

		if round.started
			and not round.playerIndex[
			targetPlayer.UserId
			]
		then
			return
		end

        if action=="Question"then
         local index=round.playerIndex[targetPlayer.UserId]
         local r={ok=false,code="closed"}
         if type(value)=="table"and round.phase=="Discuss"and round.discussion and index
          and round.players[index]==targetPlayer and targetPlayer.Parent==Players and value.text==nil then
          local other=type(value.target)=="number"and value.target>=1 and value.target%1==0 and Players:GetPlayerByUserId(value.target)
          if value.kind=="ask"and other and other.Parent==Players and other:GetAttribute("SpySessionAccepted")==true then
           r=round.discussion:ask(targetPlayer.UserId,value.target,value.prompt,value.token)
          elseif value.kind=="finish"then r=round.discussion:finish(targetPlayer.UserId,value.id,value.token)end
          if r.ok then broadcast("Discuss",{category=round.category})end
         end
         questionAck:FireClient(targetPlayer,{ok=r.ok,code=r.code,requestId=type(value)=="table"and type(value.requestId)=="number"and value.requestId%1==0 and value.requestId>=1 and value.requestId<=1000000 and value.requestId or nil})
         return
        end
        if action=="Rematch"then handleRematch(targetPlayer,value);return end

        -- MATCH_EMOTE_BEGIN
        if action == "Emote" then
            local index=round.playerIndex[targetPlayer.UserId]
            if not round.started or not index or round.players[index]~=targetPlayer
                or targetPlayer.Parent~=Players or (round.phase~="Discuss" and round.phase~="Result")
                or targetPlayer:GetAttribute("SpyPhoneActive")==true then return end
            local at=now()
            if at-(matchEmoteAt[targetPlayer.UserId] or -math.huge)<5 then return end
            local public=profileSnapshot(targetPlayer)
            if not public.ready or (public.equipped or {}).emote~="wave" then return end
            matchEmoteAt[targetPlayer.UserId]=at
            Cosmetics.emote(targetPlayer,public)
            return
        end
        -- MATCH_EMOTE_END

        if action == "SpyGuess" then
			trySpyGuess(targetPlayer, value)
			return
		end

		if action == "HintDone" then
			completeCurrentHintTurn(
				targetPlayer
			)

			return
		end

		if action == "TopicVote" then
			if round.phase
				~= "TopicVote"
			then
				return
			end

			if round.topicVoteClosed then
				return
			end

			if not round.playerIndex[
				targetPlayer.UserId
				] then
				return
			end

			if round.topicVotes[
				targetPlayer.UserId
				] then
				return
			end

			if type(value)
				~= "string"
			then
				return
			end

			if not isValidTopicOption(
				value
				) then
				return
			end

			round.topicVotes[
			targetPlayer.UserId
			] = value
			if round.participation then round.participation:respond(targetPlayer.UserId, "topic") end

			broadcast(
				"TopicVote",
				{
					topicOptions =
						publicTopicOptions(),

					votedCount =
						topicVoteCount(),

					totalPlayers =
						#round.players,
				}
			)

			return
		end

		if action ~= "Vote" then
			return
		end

		if round.phase ~= "Vote" then
			return
		end

		if round.voteClosed
			or round.voteRestartRequested
		then
			return
		end

		if not round.playerIndex[
			targetPlayer.UserId
			] then
			return
		end

		if round.votes[
			targetPlayer.UserId
			] then
			return
		end

		if value == EXTRA_ROUND_VOTE_VALUE
			or value == "extra_round"
		then
			if not activeRules.allowExtraRound then return end
			round.votes[
			targetPlayer.UserId
			] =
				EXTRA_ROUND_VOTE_VALUE
			table.insert(round.voteOrder, targetPlayer.UserId)
			if round.participation then round.participation:respond(targetPlayer.UserId, "vote") end

			stateEvent:FireClient(
				targetPlayer,
				{
					phase =
						"VoteAccepted",

					extraRound =
						true,

					targetId =
						EXTRA_ROUND_VOTE_VALUE,
				}
			)

			return
		end

		local targetId = tonumber(value)
		if targetId == targetPlayer.UserId then return end

		if not targetId then
			return
		end

		if not round.playerIndex[
			targetId
			] then
			return
		end

		round.votes[
		targetPlayer.UserId
		] =
			targetId
		table.insert(round.voteOrder, targetPlayer.UserId)
		if round.participation then round.participation:respond(targetPlayer.UserId, "vote") end

		stateEvent:FireClient(
			targetPlayer,
			{
				phase =
					"VoteAccepted",

				targetId =
					targetId,
			}
		)
	end
)

---------------------------------------------------------------------
-- TEXT HINT -> AUTO FINISH
---------------------------------------------------------------------

local chatConnections = {}

local function hookChat(
	targetPlayer
)
	if chatConnections[
		targetPlayer
		] then
		return
	end

	chatConnections[
	targetPlayer
	] =
		targetPlayer.Chatted:Connect(
			function(message)
				if round.phase
					~= "Hint"
				then
					return
				end

				if round.currentTurnUserId
					~= targetPlayer.UserId
				then
					return
				end

				if round.hintTurnDone then
					return
				end

				local text =
				tostring(
					message
					or ""
				)

				if not text:match("%S") then
					return
				end

				completeCurrentHintTurn(
					targetPlayer
				)
			end
		)
end

---------------------------------------------------------------------
-- PLAYER HOOK
---------------------------------------------------------------------

local function hookPlayer(
	targetPlayer
)
	ensureMatchChatSource(targetPlayer)
	local ownershipSyncStarted=false
	local ownershipSyncFailures=0
	local function syncOwnedPasses()
		if ownershipSyncStarted or targetPlayer.Parent~=Players or targetPlayer:GetAttribute("SpySessionAccepted")~=true then return end
		ownershipSyncStarted=true
		task.spawn(function()
			local ok,err=pcall(function()
				if not ensureProfileLoaded(targetPlayer)then error("profile unavailable")end
				matchMonetization:sync(targetPlayer)
			end)
			if not ok then
				ownershipSyncStarted=false
				ownershipSyncFailures=math.min(5,ownershipSyncFailures+1)
				warn("SpyClub match ownership sync: "..tostring(err))
				task.delay(math.min(30,2^ownershipSyncFailures),syncOwnedPasses)
			end
		end)
	end
	targetPlayer:GetAttributeChangedSignal("SpySessionAccepted"):Connect(syncOwnedPasses)
	syncOwnedPasses()
	task.spawn(
		function()
			ensureProfileLoaded(targetPlayer)
		end
	)

	hookChat(
		targetPlayer
	)
    -- Description loading may outlast the initial profile task. Reapply at the
    -- actual ready signal, including a character that existed before this hook.
    local function observeAppearance(character)
        character:GetAttributeChangedSignal("SpyBaseReady"):Connect(function()
            if character:GetAttribute("SpyBaseReady") and targetPlayer.Character==character then
                task.spawn(function()
                    if ensureProfileLoaded(targetPlayer) then applyProfileAppearance(targetPlayer) end
                end)
            end
        end)
        if character:GetAttribute("SpyBaseReady") then
            task.spawn(function()
                if ensureProfileLoaded(targetPlayer) then applyProfileAppearance(targetPlayer) end
            end)
        end
    end
    targetPlayer.CharacterAdded:Connect(observeAppearance)
    if targetPlayer.Character then observeAppearance(targetPlayer.Character) end
    targetPlayer.CharacterAppearanceLoaded:Connect(function(character)
        if targetPlayer.Character~=character then return end
        task.spawn(function()
            if ensureProfileLoaded(targetPlayer) then applyProfileAppearance(targetPlayer,true) end
        end)
    end)


	targetPlayer.CharacterAdded:Connect(
		function()
			task.spawn(function()
				if ensureProfileLoaded(targetPlayer) then
					task.wait(0.10)
					applyProfileAppearance(targetPlayer, true)
				end
			end)

			if not round.started
				or round.finished
			then
				return
			end

			task.wait(0.85)

			if round.playerIndex[
				targetPlayer.UserId
				] then
				sitPlayer(
					targetPlayer
				)
			end
		end
	)
end

for _, targetPlayer in ipairs(
	Players:GetPlayers()
	) do
	hookPlayer(
		targetPlayer
	)
end

Players.PlayerAdded:Connect(
	function(targetPlayer)
		hookPlayer(
			targetPlayer
		)
		if round.started then
			task.spawn(function()
				local deadline = now() + 10
				while targetPlayer.Parent == Players and targetPlayer:GetAttribute("SpySessionAccepted") ~= true and now() < deadline do task.wait(0.1) end
				local id = targetPlayer.UserId
				local index = round.playerIndex[id]
				local expiresAt = round.disconnected[id]
				if not round.terminal and not round.finished and index and expiresAt and os.time() < expiresAt
					and targetPlayer.Parent == Players and targetPlayer:GetAttribute("SpySessionAccepted") == true then
					round.players[index] = targetPlayer
     if round.discussion then round.discussion:restore(id)end
					round.disconnected[id] = nil
					publishConnections()
					sitPlayer(targetPlayer)
					-- Send current state, not a new Intro event or rerolled secrets.
					local state = table.clone(lastPublicState or {})
					state.resuming = true
					state.players = publicPlayers()
					stateEvent:FireClient(targetPlayer, state)
					if round.rolesAssigned then
						local secret = {role=id == round.spyId and "spy" or "detective", category=round.category}
						if id ~= round.spyId then secret.word = round.word else
							secret.roundToken = round.token
							secret.guessUsed = round.spyGuessUsed
						end
						if round.caseContext then
							secret.word = nil
							secret.caseFile = round.caseContext:private(id,targetPlayer:GetAttribute("SpyLanguage") or "ru")
						end
						cardEvent:FireClient(targetPlayer, secret)
					end
				end
			end)
		end

		if round.started
			and not round.finished
		then
			task.delay(
				11,
				function()
					if targetPlayer.Parent
						~= Players
					then
						return
					end

					if not round.terminal and round.playerIndex[targetPlayer.UserId]
						and round.disconnected[targetPlayer.UserId] == nil
						and targetPlayer:GetAttribute("SpySessionAccepted") == true then
						return
					end

					if RunService:IsStudio() then
						return
					end

					pcall(function()
						TeleportService:
							TeleportAsync(
								LOBBY_PLACE_ID,
								{
									targetPlayer,
								},
								makeReturnOptions(
									"round_already_started"
								)
							)
					end)
				end
			)
		end
	end
)

---------------------------------------------------------------------
-- PLAYER REMOVING
---------------------------------------------------------------------

Players.PlayerRemoving:Connect(
	function(targetPlayer)
        if round.discussion and round.discussion:drop(targetPlayer.UserId)and round.phase=="Discuss"then broadcast("Discuss",{category=round.category})end
		reconcileRematchDeparture(targetPlayer)
		returnAttempts[targetPlayer.UserId] = nil
		returnReasons[targetPlayer.UserId] = nil
		returnState[targetPlayer.UserId] = nil
		returnRetryScheduled[targetPlayer.UserId] = nil
		matchChatLastSent[targetPlayer.UserId] = nil
		matchChatEnrollGeneration[targetPlayer.UserId] = (matchChatEnrollGeneration[targetPlayer.UserId] or 0) + 1
		matchChatEnrollBusy[targetPlayer.UserId] = nil
		local matchChatConnection = matchChatSourceConnections[targetPlayer.UserId]
		if matchChatConnection then matchChatConnection:Disconnect() end
		matchChatSourceConnections[targetPlayer.UserId] = nil
		local id = targetPlayer.UserId
		if round.started and not round.finished and not round.terminal and round.playerIndex[id]
			and targetPlayer:GetAttribute("SpyExplicitLeave") ~= true then
			round.disconnected[id] = round.disconnected[id] or (os.time() + 90)
			publishConnections()
			local sessionId = reconnectSessionId()
			if sessionId and sessionId ~= "" then
				task.spawn(function() reconnect:disconnect(id, sessionId, game.JobId) end)
			end
		end
		if profiles then
			profiles:remove(
				targetPlayer.UserId
			)
		end

		profileLoadState[
		targetPlayer.UserId
		] = nil

		local connection =
			chatConnections[
		targetPlayer
		]

		if connection then
			connection:Disconnect()

			chatConnections[
			targetPlayer
			] = nil
		end

		if not round.started
			or round.finished
		then
			return
		end

	end
)

-- Explicit return button. The client already has a polished busy/failed state;
-- acknowledge immediately, then use the same resilient per-player transport.
local leaving = {}
returnLobbyEvent.OnServerEvent:Connect(function(player)
	if leaving[player.UserId] or player:GetAttribute("SpySessionAccepted") ~= true then return end

	if RunService:IsStudio() then
		returnLobbyEvent:FireClient(player, "Studio")
		return
	end

	leaving[player.UserId] = true
	player:SetAttribute("SpyExplicitLeave", true)
 reconcileRematchDeparture(player)

	local sessionId = reconnectSessionId()
	if sessionId and sessionId ~= "" then
		reconnect:clearUser(player.UserId, sessionId)
	end

	-- The button is normally visible only in Result/Finished. Keep this guard for
	-- malicious remote calls without making a legitimate result-screen click fail.
	if not round.terminal and round.playerIndex[player.UserId] then
		removeRoundPlayer(player)
	end

	if profiles then
		task.spawn(function()
			pcall(function() profiles:flush(4) end)
		end)
	end

	queueReturn(
		player,
		"explicit_leave",
		true,
		false
	)

	task.delay(12, function()
		if player.Parent == Players then
			leaving[player.UserId] = nil
		end
	end)
end)

---------------------------------------------------------------------
-- RETURN RETRY
---------------------------------------------------------------------

TeleportService.TeleportInitFailed:Connect(function(targetPlayer,teleportResult,message,placeId)
	if placeId ~= LOBBY_PLACE_ID then return end
	if RunService:IsStudio() then return end
	if not targetPlayer or targetPlayer.Parent ~= Players then return end
	local userId=targetPlayer.UserId
	local state=returnState[userId] or "idle"
	if state~="returning" and state~="retrying" then return end
	local storedReason=returnReasons[userId]
	local reason=storedReason==false and nil or storedReason
	warn("[MatchRoundServer] TeleportInitFailed:",targetPlayer.Name,returnAttempts[userId] or 0,teleportResult,message)
	scheduleReturnRetry(targetPlayer,reason,tostring(teleportResult)..": "..tostring(message))
end)

---------------------------------------------------------------------
-- ECONOMY SHUTDOWN
---------------------------------------------------------------------

game:BindToClose(
	function()
		local sessionId = reconnectSessionId()
		if sessionId and sessionId ~= "" then reconnect:close(sessionId, game.JobId) end
		if profiles then
			pcall(
				function()
					profiles:flush(
						8
					)
				end
			)
		end
	end
)

---------------------------------------------------------------------
-- START
---------------------------------------------------------------------

local function tryStart()
	if round.started
		or round.finished
	then
		return
	end

	if sessionFolder:GetAttribute(
		"Cancelled"
		) == true
	then
		return
	end

	if sessionFolder:GetAttribute(
		"Ready"
		) ~= true
	then
		return
	end

	task.delay(
		0.75,
		function()
			if not round.started
				and not round.finished
				and sessionFolder:
				GetAttribute(
					"Ready"
				)
					== true
			then
				runRound()
			end
		end
	)
end

sessionFolder:
	GetAttributeChangedSignal(
		"Ready"
	):
	Connect(
		tryStart
	)

task.defer(
	tryStart
)


---------------------------------------------------------------------
-- SPY CLUB CREATOR CONTROL V31.4 -- match/chat integration
---------------------------------------------------------------------
do
    local adminCommand=SpyAdminCore.remote
    local function refreshMuted(p)
        local source=findMatchChatSource(p.UserId)
        if source then applyMatchChatPermission(p,source) end
    end
    adminCommand.OnServerEvent:Connect(function(actor,payload)
        if type(payload)~="table" or actor:GetAttribute("SpyIsAdmin")~=true then return end
        local command=payload.command; local requestId=payload.requestId
        if command=="mute" or command=="unmute" then
            local target,terr=SpyAdminCore.targetOf(payload); if not target then SpyAdminCore.reply(actor,command,requestId,false,terr); return end
            target:SetAttribute("SpyAdminMuted",command=="mute"); refreshMuted(target)
            SpyAdminCore.reply(actor,command,requestId,true,command=="mute" and "muted" or "unmuted")
            SpyAdminCore.log(actor,target,command,"ok"); return
        elseif command=="returnLobby" then
            local target,terr=SpyAdminCore.targetOf(payload); if not target then SpyAdminCore.reply(actor,command,requestId,false,terr); return end
            target:SetAttribute("SpyExplicitLeave",true)
            SpyAdminCore.reply(actor,command,requestId,true,"returning"); SpyAdminCore.log(actor,target,command,"ok")
            queueReturn(target,"admin_return",false,false); return
        elseif command=="returnAll" then
            SpyAdminCore.reply(actor,command,requestId,true,"returning"); SpyAdminCore.log(actor,nil,command,"ok")
            returnEveryoneToLobby("admin_return_all"); return
        elseif command=="endMatch" then
            SpyAdminCore.reply(actor,command,requestId,true,"ending"); SpyAdminCore.log(actor,nil,command,"ok")
            abortRound("admin_end_match"); return
        end
    end)
    ReplicatedStorage.SpyShared:SetAttribute("SpyAdminMatchReady",true)
    print("SPY_ADMIN_SERVER_READY","MATCH","V31.4")
end

end, debug.traceback)
if bootOK then
	bootStorage:SetAttribute("SpyRoundBootStatus", "ready")
else
	bootStorage:SetAttribute("SpyRoundBootStatus", "failed")
	bootStorage:SetAttribute("SpyMatchBootError", "M22-ROUND")
	bootStorage:SetAttribute("SpyRoundBootStatusError", tostring(bootError):sub(1,1500))
	warn("[SPY M22-ROUND] " .. tostring(bootError))
end
