local bootStorage = game:GetService("ReplicatedStorage")
bootStorage:SetAttribute("SpySessionBootStatus", "starting")
local bootOK, bootError = xpcall(function()
-- ServerScriptService > MatchSessionServer
-- SPY CLUB / MATCH SESSION SERVER · V23 LOAD FIX
-- FULL REPLACEMENT
--
-- Lobby -> Match:
-- • принимает TeleportData;
-- • проверяет partyId / memberIds / sourcePlaceId;
-- • знает хозяина, название, вместимость, видимость;
-- • ждёт игроков;
-- • переживает частичный Teleport;
-- • 4 отправились, 3 дошли -> играем втроём;
-- • меньше 3 -> матч отменяется;
-- • если хозяин пропал до старта -> передаёт хоста;
-- • при отмене возвращает оставшихся в Lobby
--   с данными для восстановления того же стола;
-- • Studio direct Play работает с одним игроком.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local MatchRules = require(game:GetService("ReplicatedStorage"):WaitForChild("SpyShared"):WaitForChild("MatchRules"))
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Reconnect = require(game:GetService("ServerStorage"):WaitForChild("SpyModules"):WaitForChild("ReconnectService")).default()

---------------------------------------------------------------------
-- PLACES
---------------------------------------------------------------------

local LOBBY_PLACE_ID = 93859909286393

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------

-- Сколько ждём человека, который не долетел в reserved server.
local ARRIVAL_GRACE_SECONDS = 20

-- Дополнительное время, если Player уже дошёл,
-- но его Character почему-то долго не появился.
local CHARACTER_GRACE_SECONDS = 10

local LIVE_MINIMUM_PLAYERS = 3
local LIVE_MAXIMUM_PLAYERS = 4

---------------------------------------------------------------------
-- SESSION STATE
---------------------------------------------------------------------

local session = nil

-- Игрок физически прибыл в Match server.
local arrivedPlayers = {}

-- Character игрока был поставлен в комнату.
local readyPlayers = {}

local sessionCancelled = false
local arrivalTimerStarted = false
local matchStarted = false

---------------------------------------------------------------------
-- REPLICATED SESSION
---------------------------------------------------------------------

local sessionFolder =
	ReplicatedStorage:FindFirstChild(
		"MatchSession"
	)

if not sessionFolder then
	sessionFolder = Instance.new("Folder")
	sessionFolder.Name = "MatchSession"
	sessionFolder.Parent = ReplicatedStorage
end

sessionFolder:SetAttribute(
	"Ready",
	false
)

sessionFolder:SetAttribute(
	"ReadyCount",
	0
)

sessionFolder:SetAttribute(
	"ConnectedCount",
	0
)

sessionFolder:SetAttribute(
	"ExpectedCount",
	0
)

sessionFolder:SetAttribute(
	"Cancelled",
	false
)

sessionFolder:SetAttribute(
	"CancelReason",
	""
)

sessionFolder:SetAttribute(
	"RoundPhase",
	"Waiting"
)

sessionFolder:SetAttribute(
	"PhaseEndAt",
	0
)

---------------------------------------------------------------------
-- ROOM HELPERS
---------------------------------------------------------------------

local function getMatchRoot()
	return workspace:FindFirstChild(
		"SpyMatchRoom"
	)
end

local function findSpawn(index)
	local root =
		getMatchRoot()

	-----------------------------------------------------------------
	-- GENERATED PLAYER SPAWNS
	-----------------------------------------------------------------

	if root then
		local spawns =
			root:FindFirstChild(
				"PlayerSpawns"
			)

		if spawns then
			local marker =
				spawns:FindFirstChild(
					"Spawn" .. tostring(index)
				) or spawns:FindFirstChild(
					"Player"
					.. tostring(index)
				)

			if marker
				and marker:IsA("BasePart")
			then
				return marker.CFrame
			end
		end
	end

	-----------------------------------------------------------------
	-- SEARCH ANYWHERE
	-----------------------------------------------------------------

	local spawns =
		workspace:FindFirstChild(
			"PlayerSpawns",
			true
		)

	if spawns then
		local marker =
			spawns:FindFirstChild(
				"Spawn" .. tostring(index)
			) or spawns:FindFirstChild(
				"Player"
				.. tostring(index)
			)

		if marker
			and marker:IsA("BasePart")
		then
			return marker.CFrame
		end
	end

	-----------------------------------------------------------------
	-- CHAIR FALLBACK
	-----------------------------------------------------------------

	local chairs =
		root
		and root:FindFirstChild(
			"Chairs"
		)

	if not chairs then
		chairs =
			workspace:FindFirstChild(
				"Chairs",
				true
			)
	end

	if chairs then
		local chair =
			chairs:FindFirstChild(
				"Chair"
				.. tostring(index)
			)

		if chair then
			local seat =
				chair:FindFirstChild(
					"Seat",
					true
				)

			if seat
				and seat:IsA("BasePart")
			then
				return
					seat.CFrame
					* CFrame.new(
						0,
						2.5,
						3
					)
			end
		end
	end

	-----------------------------------------------------------------
	-- FINAL FALLBACK
	-----------------------------------------------------------------

	local fallbacks = {
		CFrame.new(0, 4, -10)
			* CFrame.Angles(
				0,
				math.rad(180),
				0
			),

		CFrame.new(10, 4, 0)
			* CFrame.Angles(
				0,
				math.rad(-90),
				0
			),

		CFrame.new(0, 4, 10),

		CFrame.new(-10, 4, 0)
			* CFrame.Angles(
				0,
				math.rad(90),
				0
			),
	}

	return
		fallbacks[index]
		or CFrame.new(
			0,
			4,
			0
		)
end

---------------------------------------------------------------------
-- MEMBER HELPERS
---------------------------------------------------------------------

local function indexOfUserId(
	list,
	userId
)
	userId =
		tonumber(userId)

	if not userId then
		return nil
	end

	for index, value in ipairs(
		list or {}
		) do
		if tonumber(value)
			== userId
		then
			return index
		end
	end

	return nil
end

local function containsUserId(
	list,
	userId
)
	return
		indexOfUserId(
			list,
			userId
		)
		~= nil
end

local function dedupeMemberIds(
	rawIds
)
	local result = {}
	local seen = {}

	for _, rawId in ipairs(
		rawIds or {}
		) do
		local id =
			tonumber(rawId)

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

local function getMemberIndex(
	userId
)
	if not session then
		return nil
	end

	return
		indexOfUserId(
			session.memberIds,
			userId
		)
end

---------------------------------------------------------------------
-- CONNECTED PLAYERS
---------------------------------------------------------------------

local function getConnectedExpectedPlayers()
	local result = {}

	if not session then
		return result
	end

	for _, userId in ipairs(
		session.memberIds
		) do
		local targetPlayer =
			Players:GetPlayerByUserId(
				tonumber(userId)
			)

		if targetPlayer
			and targetPlayer.Parent
			== Players
		then
			table.insert(
				result,
				targetPlayer
			)
		end
	end

	return result
end

local function connectedExpectedCount()
	return
		#getConnectedExpectedPlayers()
end

---------------------------------------------------------------------
-- OWNER
---------------------------------------------------------------------

local function repairOwner()
	if not session then
		return
	end

	if containsUserId(
		session.memberIds,
		session.ownerId
		) then
		return
	end

	session.ownerId =
		tonumber(
			session.memberIds[1]
		)
		or 0

	print(
		"[MatchSession] Host transferred:",
		session.ownerId
	)
end

---------------------------------------------------------------------
-- PUBLISH SESSION
---------------------------------------------------------------------

local function publishSession()
	if not session then
		return
	end

	sessionFolder:SetAttribute(
		"PartyId",
		session.partyId or ""
	)

	sessionFolder:SetAttribute(
		"PartyCode",
		session.partyCode or ""
	)

	sessionFolder:SetAttribute(
		"PartyName",
		session.partyName or "Стол"
	)

	sessionFolder:SetAttribute(
		"OwnerId",
		session.ownerId or 0
	)

	sessionFolder:SetAttribute(
		"Capacity",
		session.capacity or 4
	)

	sessionFolder:SetAttribute(
		"Visibility",
		session.visibility or "invite"
	)

	sessionFolder:SetAttribute(
		"ExpectedCount",
		#session.memberIds
	)

	sessionFolder:SetAttribute(
		"StartedAt",
		session.startedAt or os.time()
	)

	sessionFolder:SetAttribute("RulesJson", HttpService:JSONEncode(session.rules or MatchRules.defaults()))
	sessionFolder:SetAttribute("SessionId", session.sessionId or "")
	local jsonValue =
		sessionFolder:FindFirstChild(
			"MemberIdsJson"
		)

	if not jsonValue then
		jsonValue =
			Instance.new(
				"StringValue"
			)

		jsonValue.Name =
			"MemberIdsJson"

		jsonValue.Parent =
			sessionFolder
	end

	local ok, json =
		pcall(function()
			return
			HttpService:JSONEncode(
				session.memberIds
			)
		end)

	jsonValue.Value =
		ok
		and json
		or "[]"
end

---------------------------------------------------------------------
-- READY STATE
---------------------------------------------------------------------

local function updateReadyState()
	if not session
		or sessionCancelled
	then
		sessionFolder:SetAttribute(
			"Ready",
			false
		)

		return
	end

	local readyCount = 0

	for _, userId in ipairs(
		session.memberIds
		) do
		if readyPlayers[
			tonumber(userId)
			] then
			readyCount += 1
		end
	end

	local expected =
		#session.memberIds

	sessionFolder:SetAttribute(
		"ReadyCount",
		readyCount
	)

	sessionFolder:SetAttribute(
		"ConnectedCount",
		connectedExpectedCount()
	)

	sessionFolder:SetAttribute(
		"ExpectedCount",
		expected
	)

	-----------------------------------------------------------------
	-- STUDIO
	-----------------------------------------------------------------

	if RunService:IsStudio() then
		local ready =
			expected > 0
			and readyCount >= expected

		sessionFolder:SetAttribute(
			"Ready",
			ready
		)

		if ready then
			print(
				"[MatchSession] Studio ready:",
				readyCount,
				"/",
				expected
			)
		end

		return
	end

	-----------------------------------------------------------------
	-- LIVE
	-----------------------------------------------------------------

	local ready =
		expected
		>= LIVE_MINIMUM_PLAYERS

		and readyCount
		>= expected

	sessionFolder:SetAttribute(
		"Ready",
		ready
	)

	if ready then
		print(
			"[MatchSession] All players ready:",
			readyCount,
			"/",
			expected
		)
	end
end

---------------------------------------------------------------------
-- STUDIO TEST SESSION
---------------------------------------------------------------------

local function createStudioSession(
	player
)
	session = {
		version = 1,

		partyId =
			"studio-test",

		partyCode =
			"TEST",

		partyName =
			"Тестовый матч",

		ownerId =
			player.UserId,

		capacity =
			4,

		visibility =
			"invite",

		memberIds = {
			player.UserId,
		},

		sourcePlaceId =
			LOBBY_PLACE_ID,

		startedAt =
			os.time(),
	}

	publishSession()
end

---------------------------------------------------------------------
-- TELEPORT DATA VALIDATION
---------------------------------------------------------------------

local function acceptPlayer(
	player
)
	local ok, joinData =
		pcall(function()
			return
			player:GetJoinData()
		end)

	if not ok then
		return false
	end

	local data =
		joinData
		and joinData.TeleportData

	-----------------------------------------------------------------
	-- STUDIO DIRECT PLAY
	-----------------------------------------------------------------

	if RunService:IsStudio()
		and type(data) ~= "table"
	then
		if not session then
			createStudioSession(
				player
			)
		end

		return
			getMemberIndex(
				player.UserId
			)
			~= nil
	end

	-----------------------------------------------------------------
	-- BASIC VALIDATION
	-----------------------------------------------------------------

	if type(data) ~= "table" then
		return false
	end

	if tonumber(
		data.version
		) ~= 1 then
		return false
	end

	if type(data.partyId)
		~= "string"
		or data.partyId == ""
	then
		return false
	end

	if type(data.memberIds)
		~= "table"
	then
		return false
	end

    if not RunService:IsStudio() and tonumber(joinData.SourcePlaceId) ~= LOBBY_PLACE_ID then
        return false
    end
	if tonumber(
		data.sourcePlaceId
		) ~= LOBBY_PLACE_ID then
		return false
	end

	-- TeleportData is not authorization. The server-only ticket binds this user,
	-- session, reserved server ID and original live JobId.
	if not RunService:IsStudio() then
		if type(data.sessionId) ~= "string" then return false end
		local trusted = Reconnect:admit(player.UserId, data.sessionId, game.PrivateServerId, game.JobId)
		if not trusted then return false end
		data = trusted
	end

	local cleanRules = MatchRules.sanitize(data.rules)
	if not cleanRules then return false end
	local memberIds =
		dedupeMemberIds(
			data.memberIds
		)

	-----------------------------------------------------------------
	-- PARTY SIZE
	-----------------------------------------------------------------

	if #memberIds
		< LIVE_MINIMUM_PLAYERS
		or #memberIds
		> LIVE_MAXIMUM_PLAYERS
	then
		return false
	end

	-----------------------------------------------------------------
	-- PLAYER MUST BE MEMBER
	-----------------------------------------------------------------

	if not containsUserId(
		memberIds,
		player.UserId
		) then
		return false
	end

	-----------------------------------------------------------------
	-- FIRST PLAYER DEFINES RESERVED SESSION
	-----------------------------------------------------------------

	if not session then
		local visibility =
			data.visibility

		if visibility ~= "public"
			and visibility ~= "invite"
		then
			visibility =
				"invite"
		end

		session = {
			version = 1,
			sessionId = data.sessionId,
			rules = cleanRules,

			partyId =
				data.partyId,

			partyCode =
				tostring(
					data.partyCode
					or ""
				),

			partyName =
				tostring(
					data.partyName
					or "Стол"
				),

			ownerId =
				tonumber(
					data.ownerId
				)
				or 0,

			capacity =
				math.clamp(
					tonumber(
						data.capacity
					)
					or 4,
					3,
					4
				),

			visibility =
				visibility,

			memberIds =
				memberIds,

			sourcePlaceId =
				LOBBY_PLACE_ID,

			startedAt =
				tonumber(
					data.startedAt
				)
				or os.time(),
		}

		repairOwner()
		publishSession()
		sessionFolder:SetAttribute("ReconnectSessionId", session.sessionId or "")
		if session.sessionId then
			task.spawn(function()
				while not sessionCancelled do
					local phase = sessionFolder:GetAttribute("RoundPhase")
					if phase == "Finished" or phase == "Result" then break end
					Reconnect:heartbeat(session.sessionId, game.JobId)
					task.wait(20)
				end
			end)
		end
	end

	-----------------------------------------------------------------
	-- SAME PARTY
	-----------------------------------------------------------------

	if data.partyId
		~= session.partyId
	then
		return false
	end

	-----------------------------------------------------------------
	-- MUST STILL BE EXPECTED
	-----------------------------------------------------------------

	return
		getMemberIndex(
			player.UserId
		)
		~= nil
end

---------------------------------------------------------------------
-- RETURN INVALID PLAYER
---------------------------------------------------------------------

local function returnInvalidPlayer(
	player
)
	if RunService:IsStudio() then
		warn(
			"[MatchSession] Invalid player:",
			player.Name
		)

		return
	end

	-- ВАЖНО:
	-- invalid player НЕ получает данные чужой party.
	task.spawn(function()
		local ok, err =
			pcall(function()
				TeleportService:
				TeleportAsync(
					LOBBY_PLACE_ID,
					{
						player,
					}
				)
			end)

		if not ok then
			warn(
				"[MatchSession] Invalid-player return failed:",
				err
			)

			if player.Parent == Players then
				player:Kick(
					"Не удалось подключиться к матчу."
				)
			end
		end
	end)
end

---------------------------------------------------------------------
-- RETURN DATA AFTER CANCEL
---------------------------------------------------------------------

local function makeReturnOptions(
	reason,
	playerList
)
	local options =
		Instance.new(
			"TeleportOptions"
		)

	local memberIds = {}

	for _, targetPlayer in ipairs(
		playerList or {}
		) do
		if targetPlayer.Parent == Players then
			table.insert(
				memberIds,
				targetPlayer.UserId
			)
		end
	end

	local ownerId =
		session
		and tonumber(
			session.ownerId
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

	options:SetTeleportData({
		rules = session and session.rules or MatchRules.defaults(),
		version = 1,

		fromMatch = true,

		-- SpyPartyServer проверяет этот PlaceId.
		sourcePlaceId =
			game.PlaceId,

		partyId =
			session
			and session.partyId
			or nil,

		partyCode =
			session
			and session.partyCode
			or nil,

		partyName =
			session
			and session.partyName
			or nil,

		ownerId =
			ownerId,

		capacity =
			session
			and session.capacity
			or 4,

		visibility =
			session
			and session.visibility
			or "invite",

		memberIds =
			memberIds,

		matchCancelled =
			true,

		reason =
			reason
			or "match_cancelled",

		finishedAt =
			os.time(),
	})

	return options
end

---------------------------------------------------------------------
-- RETURN GROUP TO LOBBY
---------------------------------------------------------------------

local function returnPlayersToLobby(
	playerList,
	reason
)
	if #playerList == 0 then
		return
	end

	if RunService:IsStudio() then
		warn(
			"[MatchSession] Studio: would return",
			#playerList,
			"player(s). Reason:",
			reason or "cancelled"
		)

		return
	end

	task.spawn(function()
		local ok, err =
			pcall(function()
				TeleportService:
				TeleportAsync(
					LOBBY_PLACE_ID,
					playerList,
					makeReturnOptions(
						reason,
						playerList
					)
				)
			end)

		if not ok then
			warn(
				"[MatchSession] Return failed:",
				err
			)

			for _, targetPlayer in ipairs(
				playerList
				) do
				if targetPlayer.Parent
					== Players
				then
					targetPlayer:Kick(
						"Не удалось вернуть вас в лобби."
					)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- CANCEL BEFORE ROUND START
---------------------------------------------------------------------

local function cancelSession(
	reason
)
	if sessionCancelled
		or matchStarted
	then
		return
	end

	sessionCancelled = true
	if session and session.sessionId then Reconnect:close(session.sessionId, game.JobId) end

	sessionFolder:SetAttribute(
		"Ready",
		false
	)

	sessionFolder:SetAttribute(
		"Cancelled",
		true
	)

	sessionFolder:SetAttribute(
		"CancelReason",
		reason
			or "cancelled"
	)

	local players =
		getConnectedExpectedPlayers()

	warn(
		"[MatchSession] Session cancelled:",
		reason,
		"players:",
		#players
	)

	returnPlayersToLobby(
		players,
		reason
			or "match_cancelled"
	)
end

---------------------------------------------------------------------
-- REMOVE EXPECTED MEMBER
---------------------------------------------------------------------

local function removeExpectedMember(
	userId
)
	if not session then
		return false
	end

	userId =
		tonumber(userId)

	if not userId then
		return false
	end

	local index =
		getMemberIndex(
			userId
		)

	if not index then
		return false
	end

	table.remove(
		session.memberIds,
		index
	)

	arrivedPlayers[userId] =
		nil

	readyPlayers[userId] =
		nil

	repairOwner()
	publishSession()
	updateReadyState()

	-----------------------------------------------------------------
	-- Нельзя начинать live матч вдвоём.
	-----------------------------------------------------------------

	if not RunService:IsStudio()
		and #session.memberIds
		< LIVE_MINIMUM_PLAYERS
	then
		cancelSession(
			"not_enough_players"
		)
	end

	return true
end

---------------------------------------------------------------------
-- MOVEMENT
---------------------------------------------------------------------

local function lockMovement(
	humanoid
)
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Jumping,
		false
	)

	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end
end

local function enableMovement(
	humanoid
)
	humanoid.WalkSpeed = 16
	humanoid.AutoRotate = true

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Jumping,
		true
	)

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Running,
		true
	)

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.GettingUp,
		true
	)

	if humanoid.UseJumpPower then
		if humanoid.JumpPower <= 0 then
			humanoid.JumpPower = 50
		end
	else
		if humanoid.JumpHeight <= 0 then
			humanoid.JumpHeight = 7.2
		end
	end

	if humanoid.Sit then
		humanoid.Sit = false
	end
end

---------------------------------------------------------------------
-- PLACE CHARACTER
---------------------------------------------------------------------

local function prepareCharacter(
	player,
	character
)
	if not session
		or sessionCancelled
	then
		return
	end

	local index =
		getMemberIndex(
			player.UserId
		)

	if not index then
		return
	end

	local humanoid =
		character:WaitForChild(
			"Humanoid",
			10
		)

	local rootPart =
		character:WaitForChild(
			"HumanoidRootPart",
			10
		)

	if not humanoid
		or not rootPart
	then
		return
	end

	-- Freeze immediately. A cosmetic/avatar failure must never leave the
	-- player walking around behind the loading screen.
	lockMovement(humanoid)

	-- Match readiness is transport/UI readiness, not cosmetic readiness.
	-- SpyBaseReady may arrive later; MatchAvatar/MatchRoundServer can finish
	-- appearance in the background without blocking the whole table.
	local readyDeadline = os.clock() + 20
	while player.Character == character and player.Parent == Players
		and player:GetAttribute("SpyMatchClientReady") ~= true
		and os.clock() < readyDeadline do
		task.wait(0.1)
	end
	if player.Character ~= character or player.Parent ~= Players then return end
	if player:GetAttribute("SpyMatchClientReady") ~= true then
		player:SetAttribute("SpyMatchPreparationFailed", true)
		warn("[SPY M23/READY] Match client handshake timed out: " .. player.Name)
		return
	end
	player:SetAttribute("SpyMatchPreparationFailed", nil)

	-----------------------------------------------------------------
	-- WAIT FOR ROOM
	-----------------------------------------------------------------

	local deadline =
		os.clock() + 10

	while os.clock() < deadline do
		if getMatchRoot()
			or workspace:
			FindFirstChild(
				"PlayerSpawns",
				true
			)
		then
			break
		end

		task.wait(0.1)
	end

	if not matchStarted then
		lockMovement(humanoid)
		character:PivotTo(findSpawn(index) * CFrame.new(0, 2.5, 0))
		task.wait(0.1)
		lockMovement(humanoid)
	end

	readyPlayers[
	player.UserId
	] = true

	updateReadyState()

	print(
		"[MatchSession] Player ready:",
		player.Name,
		"index:",
		index
	)
end

---------------------------------------------------------------------
-- ARRIVAL GRACE TIMER
---------------------------------------------------------------------

local placementInFlight = setmetatable({}, {__mode="k"})
local function placeCharacter(player, character)
	if placementInFlight[character] or player.Character ~= character then return end
	placementInFlight[character] = true
	local ok, message = xpcall(function() prepareCharacter(player, character) end, debug.traceback)
	placementInFlight[character] = nil
	if not ok then warn("[SPY M22/PLACEMENT] " .. tostring(message)) end
end

local function startArrivalTimer()
	if arrivalTimerStarted
		or RunService:IsStudio()
	then
		return
	end

	arrivalTimerStarted = true

	task.delay(
		ARRIVAL_GRACE_SECONDS,
		function()

			if sessionCancelled
				or matchStarted
				or not session
			then
				return
			end

			if sessionFolder:
				GetAttribute(
					"Ready"
				)
					== true
			then
				return
			end

			---------------------------------------------------------
			-- KEEP ONLY PLAYERS WHO ACTUALLY ARRIVED
			---------------------------------------------------------

			local survivors = {}

			for _, rawId in ipairs(
				session.memberIds
				) do
				local userId =
					tonumber(rawId)

				local targetPlayer =
					userId
					and Players:
					GetPlayerByUserId(
						userId
					)

				if userId
					and arrivedPlayers[
					userId
					]
						and targetPlayer
						and targetPlayer.Parent
						== Players
				then
					table.insert(
						survivors,
						userId
					)
				end
			end

			---------------------------------------------------------
			-- TOO FEW ARRIVED
			---------------------------------------------------------

			if #survivors
				< LIVE_MINIMUM_PLAYERS
			then
				cancelSession(
					"not_enough_players_after_teleport"
				)

				return
			end

			---------------------------------------------------------
			-- ACCEPT PARTIAL TELEPORT
			---------------------------------------------------------

			local oldCount =
				#session.memberIds

			session.memberIds =
				survivors

			repairOwner()
			publishSession()
			updateReadyState()

			if oldCount
				~= #survivors
			then
				print(
					"[MatchSession] Partial teleport accepted:",
					oldCount,
					"->",
					#survivors
				)
			end

			---------------------------------------------------------
			-- THEY ARRIVED BUT CHARACTER IS STILL NOT READY
			---------------------------------------------------------

			if sessionFolder:
				GetAttribute(
					"Ready"
				)
					== true
			then
				return
			end

			task.delay(
				CHARACTER_GRACE_SECONDS,
				function()

					if sessionCancelled
						or matchStarted
					then
						return
					end

					if sessionFolder:
						GetAttribute(
							"Ready"
						)
							== true
					then
						return
					end

					cancelSession(
						"players_not_ready"
					)
				end
			)
		end
	)
end

---------------------------------------------------------------------
-- PLAYER ADDED
---------------------------------------------------------------------

local function playerAdded(
	player
)
	if sessionCancelled then
		returnInvalidPlayer(
			player
		)

		return
	end

	if not acceptPlayer(
		player
		) then
		returnInvalidPlayer(
			player
		)

		return
	end

	arrivedPlayers[
	player.UserId
	] = true
	player:SetAttribute("SpySessionAccepted", true)

	sessionFolder:SetAttribute(
		"ConnectedCount",
		connectedExpectedCount()
	)

	startArrivalTimer()

	-----------------------------------------------------------------
	-- CHARACTER
	-----------------------------------------------------------------

	local function observeCharacter(character)
		character:GetAttributeChangedSignal("SpyBaseReady"):Connect(function()
			if character:GetAttribute("SpyBaseReady") then task.defer(placeCharacter, player, character) end
		end)
		task.defer(placeCharacter, player, character)
	end
	player.CharacterAdded:Connect(observeCharacter)
	player:GetAttributeChangedSignal("SpyMatchClientReady"):Connect(function()
		if player.Character then task.defer(placeCharacter, player, player.Character) end
	end)
	if player.Character then observeCharacter(player.Character) end
end

---------------------------------------------------------------------
-- MATCH START DETECTION
---------------------------------------------------------------------

local function updateMatchStarted()
	local phase =
		sessionFolder:GetAttribute(
			"RoundPhase"
		)

	if type(phase) == "string"
		and phase ~= ""
		and phase ~= "Waiting"
	then
		if not matchStarted then
			matchStarted = true

			print(
				"[MatchSession] Match started. Phase:",
				phase
			)
		end
	end
end

sessionFolder:
	GetAttributeChangedSignal(
		"RoundPhase"
	):
	Connect(
		updateMatchStarted
	)

updateMatchStarted()

---------------------------------------------------------------------
-- PLAYER REMOVING
---------------------------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		local userId =
			player.UserId

		arrivedPlayers[
		userId
		] = nil

		readyPlayers[
		userId
		] = nil

		-----------------------------------------------------------------
		-- DURING RETURN/CANCEL
		-----------------------------------------------------------------

		if sessionCancelled then
			return
		end

		-----------------------------------------------------------------
		-- ROUND ALREADY RUNNING
		--
		-- From this point MatchRoundServer owns the roster.
		-----------------------------------------------------------------

		if matchStarted or sessionFolder:GetAttribute("RosterLocked") == true then
			sessionFolder:SetAttribute(
				"ConnectedCount",
				math.max(
					0,
					connectedExpectedCount() - 1
				)
			)

			return
		end

		-----------------------------------------------------------------
		-- LEFT BEFORE MATCH
		-----------------------------------------------------------------

		if session
			and getMemberIndex(
				userId
			)
		then
			print(
				"[MatchSession] Player left before round:",
				player.Name
			)

			removeExpectedMember(
				userId
			)
		else
			updateReadyState()
		end
	end
)

---------------------------------------------------------------------
-- CONNECTIONS
---------------------------------------------------------------------

Players.PlayerAdded:Connect(
	playerAdded
)

for _, player in ipairs(
	Players:GetPlayers()
	) do
	task.defer(
		playerAdded,
		player
	)
end

end, debug.traceback)
if bootOK then
	bootStorage:SetAttribute("SpySessionBootStatus", "ready")
else
	bootStorage:SetAttribute("SpySessionBootStatus", "failed")
	bootStorage:SetAttribute("SpyMatchBootError", "M22-SESSION")
	bootStorage:SetAttribute("SpySessionBootStatusError", tostring(bootError):sub(1,1500))
	warn("[SPY M22-SESSION] " .. tostring(bootError))
end
