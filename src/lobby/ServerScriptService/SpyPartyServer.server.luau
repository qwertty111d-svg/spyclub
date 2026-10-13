-- ServerScriptService > SpyPartyServer
-- FULL REPLACEMENT
--
-- Lobby <-> Match party system
--
-- + восстановление стола после возврата из Match:
--   Match -> Lobby -> та же группа снова находится в одном столе
-- + если старый хозяин вернулся, он снова становится хозяином
-- + если хозяин не вернулся, хозяином остаётся первый вернувшийся
-- + если часть игроков не вернулась, стол просто остаётся неполным
-- + новый матч нельзя начать, пока игроков меньше 3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

---------------------------------------------------------------------
-- MATCH PLACE
---------------------------------------------------------------------

local MATCH_PLACE_ID = 135927279331761

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------

local folder = ReplicatedStorage:FindFirstChild("SpyPartyRemotes")

if not folder then
	folder = Instance.new("Folder")
	folder.Name = "SpyPartyRemotes"
	folder.Parent = ReplicatedStorage
end

local request = folder:FindFirstChild("Request")

if not request then
	request = Instance.new("RemoteFunction")
	request.Name = "Request"
	request.Parent = folder
end

local update = folder:FindFirstChild("Update")

if not update then
	update = Instance.new("RemoteEvent")
	update.Name = "Update"
	update.Parent = folder
end

---------------------------------------------------------------------
-- RECONNECT BOOTSTRAP
-- Party remotes above are deliberately created first. Reconnect uses
-- MemoryStore and may be unavailable in Studio; it must never kill
-- the Create Table / party UI. Production match start still fails
-- closed if reconnect storage cannot be initialized.
---------------------------------------------------------------------
local reconnectInitOk, Reconnect = pcall(function()
	local modules = game:GetService("ServerStorage"):FindFirstChild("SpyModules")
	local reconnectModule = modules and modules:FindFirstChild("ReconnectService")
	if not reconnectModule or not reconnectModule:IsA("ModuleScript") then
		error("ReconnectService missing")
	end
	local service = require(reconnectModule)
	return service.default()
end)

if not reconnectInitOk or not Reconnect then
	warn("[SpyPartyServer] Reconnect unavailable; party UI remains enabled:", Reconnect)
	Reconnect = {
		prepare = function() return false end,
		close = function() return false end,
		offer = function() return nil end,
		clearUser = function() return false end,
	}
end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

local parties = {}
local membership = {}
local reconnectStatusCache = {}
local reconnectActionAt = {}

---------------------------------------------------------------------
-- CUSTOM PARTY RULES
---------------------------------------------------------------------

local MatchRules = require(ReplicatedStorage:WaitForChild("SpyShared"):WaitForChild("MatchRules"))
local defaultPartyRules = MatchRules.defaults
local sanitizePartyRules = MatchRules.sanitize
local function publicRules(raw)
	local rules=sanitizePartyRules(raw) or defaultPartyRules()
	return {allowedThemes=table.clone(rules.allowedThemes),topicMode=rules.topicMode,allowExtraRound=rules.allowExtraRound,discussionSeconds=rules.discussionSeconds,hintSeconds=rules.hintSeconds,hintLaps=rules.hintLaps,mode=rules.mode}
end


---------------------------------------------------------------------
-- PARTY CODE
---------------------------------------------------------------------

local alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function randomCode(length)
	local result = {}

	for _ = 1, length do
		local index = math.random(1, #alphabet)

		result[#result + 1] =
			alphabet:sub(index, index)
	end

	return table.concat(result)
end

local function uniqueCode()
	for _ = 1, 50 do
		local code = randomCode(5)

		if not parties[code] then
			return code
		end
	end

	return string.upper(
		HttpService:
			GenerateGUID(false):
			gsub("-", ""):
			sub(1, 5)
	)
end

---------------------------------------------------------------------
-- TEXT
---------------------------------------------------------------------

local function trim(text)
	return (
		tostring(text or ""):
			gsub("^%s+", ""):
			gsub("%s+$", ""):
			gsub("%s+", " ")
	)
end

local function truncateUtf8(text, maxCharacters)
	local length = utf8.len(text)

	if not length then
		return ""
	end

	if length <= maxCharacters then
		return text
	end

	local byte =
		utf8.offset(
			text,
			maxCharacters + 1
		)

	if not byte then
		return text
	end

	return string.sub(
		text,
		1,
		byte - 1
	)
end

local function defaultPartyName(player)
	return "Стол " .. player.DisplayName
end

local function filterPartyName(player, rawName)
	local name = trim(rawName)

	name =
		truncateUtf8(
			name,
			24
		)

	if name == "" then
		return defaultPartyName(player)
	end

	local ok, filtered =
		pcall(function()
			local result =
			TextService:FilterStringAsync(
				name,
				player.UserId,
				Enum.TextFilterContext.PublicChat
			)

			return
			result:
			GetNonChatStringForBroadcastAsync()
		end)

	if not ok
		or type(filtered) ~= "string"
	then
		return defaultPartyName(player)
	end

	filtered = trim(filtered)

	if filtered == "" then
		return defaultPartyName(player)
	end

	return truncateUtf8(
		filtered,
		24
	)
end

---------------------------------------------------------------------
-- MEMBER HELPERS
---------------------------------------------------------------------

local function memberPublic(member)
	return {
		userId = member.UserId,
		name = member.DisplayName,
		username = member.Name,
	}
end

local function cleanMembers(party)
	if not party then
		return
	end

	for index = #party.members, 1, -1 do
		local member = party.members[index]

		if member.Parent ~= Players then
			if membership[member.UserId] == party then
				membership[member.UserId] = nil
				member:SetAttribute("SpyPartyMember",false)
			member:SetAttribute("SpyTeleporting",false)
			end

			table.remove(
				party.members,
				index
			)
		end
	end

	if party.owner
		and party.owner.Parent ~= Players
	then
		party.owner =
			party.members[1]
	end

	-----------------------------------------------------------------
	-- Если старый хозяин вернулся после Match,
	-- возвращаем ownership ему.
	-----------------------------------------------------------------

	if party.restoreOwnerId then
		for _, member in ipairs(party.members) do
			if member.UserId == party.restoreOwnerId then
				party.owner = member
				break
			end
		end
	end
end

local function containsMember(party, userId)
	for _, member in ipairs(party.members) do
		if member.UserId == userId then
			return true
		end
	end

	return false
end

local function findPartyById(partyId)
	if type(partyId) ~= "string"
		or partyId == ""
	then
		return nil
	end

	for _, party in pairs(parties) do
		if party.id == partyId then
			return party
		end
	end

	return nil
end

---------------------------------------------------------------------
-- PARTY SNAPSHOT
---------------------------------------------------------------------

local function partyPublic(party)
	if not party then
		return nil
	end

	cleanMembers(party)

	if #party.members == 0 then
		return nil
	end

	if not party.owner then
		party.owner =
			party.members[1]
	end

	if not party.owner then
		return nil
	end

	local members = {}

	for _, member in ipairs(party.members) do
		members[#members + 1] =
			memberPublic(member)
	end

	return {
		id = party.id,
		code = party.code,
		name = party.name,

		ownerId =
			party.owner.UserId,

		ownerName =
			party.owner.DisplayName,

		ownerUsername =
			party.owner.Name,

		capacity =
			party.capacity,

		visibility =
			party.visibility,

		count =
			#members,

		members =
			members,

		locked =
			party.locked == true,

		createdAt =
			party.createdAt,

		returnedFromMatch =
			party.restoredFromMatch == true,

		rules = publicRules(party.rules),
	}
end

---------------------------------------------------------------------
-- PUSH
---------------------------------------------------------------------

local function pushParty(party)
	if not party then
		return
	end

	local snapshot =
		partyPublic(party)

	if not snapshot then
		return
	end

	for _, member in ipairs(party.members) do
		if member.Parent == Players then
			member:SetAttribute("SpyTeleporting",party.teleporting==true)
			member:SetAttribute("SpyPartyMember",true)
			update:FireClient(
				member,
				snapshot
			)
		end
	end
end

---------------------------------------------------------------------
-- DESTROY
---------------------------------------------------------------------

local function destroyParty(party)
	if not party then
		return
	end

	if parties[party.code] == party then
		parties[party.code] = nil
	end

	for _, member in ipairs(party.members) do
		if membership[member.UserId] == party then
			membership[member.UserId] = nil
			member:SetAttribute("SpyPartyMember",false)
			member:SetAttribute("SpyTeleporting",false)
		end
	end

	party.members = {}
end

---------------------------------------------------------------------
-- LEAVE
---------------------------------------------------------------------

local function leaveParty(player, reason)
	local party =
		membership[player.UserId]

	if not party then
		return {
			ok = true,
			party = nil,
		}
	end

	membership[player.UserId] = nil
	player:SetAttribute("SpyPartyMember",false)
	player:SetAttribute("SpyTeleporting",false)

	for index, member in ipairs(party.members) do
		if member == player then
			table.remove(
				party.members,
				index
			)

			break
		end
	end

	if player.Parent == Players then
		update:FireClient(
			player,
			nil,
			reason or "left"
		)
	end

	if #party.members == 0 then
		destroyParty(party)

		return {
			ok = true,
			party = nil,
		}
	end

	if party.owner == player then
		party.owner =
			party.members[1]
	end

	if not party.teleporting then
		party.locked = false
	end

	cleanMembers(party)
	pushParty(party)

	return {
		ok = true,
		party = nil,
	}
end

---------------------------------------------------------------------
-- RESTORE AFTER MATCH :: V44 validated/idempotent
---------------------------------------------------------------------

local RETURN_RESTORE_ATTEMPTS = 6
local RETURN_RESTORE_RETRY_SECONDS = 0.45
local returnDataCache = {}
local returnRestoreKeys = {}
local returnRestoreInFlight = {}

local function readReturnData(player)
	local userId=player.UserId
	if returnDataCache[userId]~=nil then return returnDataCache[userId] or nil end
	local ok,joinData=pcall(function() return player:GetJoinData() end)
	if not ok or type(joinData)~="table" or type(joinData.TeleportData)~="table" then returnDataCache[userId]=false return nil end
	local data=joinData.TeleportData
	if data.fromMatch ~= true then returnDataCache[userId]=false return nil end
	if type(data.sourcePlaceId)~="number" or data.sourcePlaceId ~= MATCH_PLACE_ID then returnDataCache[userId]=false return nil end
	if type(data.partyId) ~= "string" or data.partyId == "" or #data.partyId>128 then returnDataCache[userId]=false return nil end
	if data.partyCode~=nil and (type(data.partyCode)~="string" or #data.partyCode>16) then returnDataCache[userId]=false return nil end
	if data.partyName~=nil and (type(data.partyName)~="string" or #data.partyName>128) then returnDataCache[userId]=false return nil end
	if data.ownerId~=nil and type(data.ownerId)~="number" then returnDataCache[userId]=false return nil end
	if data.capacity~=nil and (type(data.capacity)~="number" or (data.capacity~=3 and data.capacity~=4)) then returnDataCache[userId]=false return nil end
	if data.visibility~=nil and (type(data.visibility)~="string" or (data.visibility~="public" and data.visibility~="invite")) then returnDataCache[userId]=false return nil end
	if data.rules~=nil and not sanitizePartyRules(data.rules) then returnDataCache[userId]=false return nil end
	if data.memberIds ~= nil and type(data.memberIds) ~= "table" then returnDataCache[userId]=false return nil end
	if type(data.memberIds) == "table" then
		local found=false
		for _,rawId in ipairs(data.memberIds) do
			if type(rawId)~="number" then returnDataCache[userId]=false return nil end
			if rawId==player.UserId then found=true end
		end
		if not found then returnDataCache[userId]=false return nil end
	end
	returnDataCache[userId]=data
	return data
end

local function restorePartyFromMatch(player,data)
	data=data or readReturnData(player)
	if not data then return false,"invalid_return" end
	local active=membership[player.UserId]
	if active then
		if active.id==data.partyId then return true,"already_restored" end
		return false, "already_active"
	end
	local key=data.partyId .. ":" .. tostring(player.UserId)
	if returnRestoreKeys[key] then return true,"already_restored" end
	if returnRestoreInFlight[key] then return false,"in_flight" end
	returnRestoreInFlight[key]=true
	local party=findPartyById(data.partyId)
	if not party then
		local capacity=data.capacity or 4
		local visibility=data.visibility or "invite"
		local code=string.upper(tostring(data.partyCode or ""):gsub("%s+", ""))
		if #code~=5 or parties[code] then code=uniqueCode() end
		local restoredName=truncateUtf8(trim(data.partyName or "Стол"),24)
		if restoredName=="" then restoredName="Стол" end
		party={id=data.partyId,code=code,name=restoredName,owner=nil,restoreOwnerId=tonumber(data.ownerId),capacity=capacity,visibility=visibility,rules=sanitizePartyRules(data.rules) or defaultPartyRules(),members={},locked=false,teleporting=false,createdAt=os.time(),restoredFromMatch=true}
		parties[party.code]=party
	end
	if containsMember(party,player.UserId) then
		membership[player.UserId]=party; returnRestoreKeys[key]=true; returnRestoreInFlight[key]=nil
		return true,"already_member"
	end
	cleanMembers(party)
	if #party.members>=party.capacity then returnRestoreInFlight[key]=nil return false,"party_full" end
	-- Re-check after any yielding helpers: never overwrite an active table/party membership.
	if membership[player.UserId] then returnRestoreInFlight[key]=nil return false, "already_active" end
	table.insert(party.members,player); membership[player.UserId]=party
	if not party.owner or party.restoreOwnerId==player.UserId then party.owner=player end
	cleanMembers(party); pushParty(party)
	returnRestoreKeys[key]=true; returnRestoreInFlight[key]=nil
	task.delay(1,function()
		if player.Parent==Players and membership[player.UserId]==party then pushParty(party) end
	end)
	return true,"restored"
end

local function restoreReturningPlayer(player)
	if player.Parent~=Players then return false end
	local data=readReturnData(player)
	if not data then
		player:SetAttribute("SpyReturnRestoreState","none")
		player:SetAttribute("SpyReturnedFromMatch",false)
		return false
	end
	local key=data.partyId .. ":" .. tostring(player.UserId)
	if returnRestoreKeys[key] then
		player:SetAttribute("SpyReturnRestoreState","restored")
		player:SetAttribute("SpyReturnedFromMatch",true)
		return true
	end
	player:SetAttribute("SpyReturnRestoreState","restoring")
	player:SetAttribute("SpyReturnedFromMatch",true)
	player:SetAttribute("SpyReturnPartyId",data.partyId)
	for attempt=1,RETURN_RESTORE_ATTEMPTS do
		if player.Parent~=Players then return false end
		local ok,reason=restorePartyFromMatch(player,data)
		if ok then player:SetAttribute("SpyReturnRestoreState","restored") return true end
		if reason=="already_active" then
			player:SetAttribute("SpyReturnRestoreState","failed")
			warn("[SpyPartyServer] Return restore skipped active membership for "..player.Name)
			return false
		end
		if attempt<RETURN_RESTORE_ATTEMPTS then task.wait(RETURN_RESTORE_RETRY_SECONDS*attempt) end
	end
	if player.Parent==Players then
		player:SetAttribute("SpyReturnRestoreState","failed")
		warn("[SpyPartyServer] Failed to restore returned player after "..RETURN_RESTORE_ATTEMPTS.." attempts: "..player.Name.." party="..tostring(data.partyId))
	end
	return false
end

---------------------------------------------------------------------
-- CREATE
---------------------------------------------------------------------

local function createParty(player, data)
	if player.Parent~=Players or Players:GetPlayerByUserId(player.UserId)~=player
		or player:GetAttribute("SpyQuickQueueActive")or(player:GetAttribute("SpyRelayTableId")or "")~="" then return {ok=false,code="already_active"}end
	if type(data) ~= "table" then
		return {
			ok = false,
			code = "invalid_request",
		}
	end

	local capacity =
		tonumber(
			data.capacity
		)

	if capacity ~= 3
		and capacity ~= 4
	then
		return {
			ok = false,
			code = "invalid_capacity",
		}
	end

	local visibility =
		data.visibility

	if visibility ~= "public"
		and visibility ~= "invite"
	then
		return {
			ok = false,
			code = "invalid_visibility",
		}
	end

	local cleanRules=sanitizePartyRules(data.rules)
	if not cleanRules then return {ok=false,code="invalid_rules"} end

	if membership[player.UserId] then
		local oldParty =
			membership[player.UserId]

		if oldParty.teleporting then
			return {
				ok = false,
				code = "already_starting",
			}
		end

		leaveParty(
			player,
			"replaced"
		)
	end

	local code =
		uniqueCode()

	local party = {
		id =
			HttpService:
			GenerateGUID(false),

		code =
			code,

		name =
			filterPartyName(
				player,
				data.name
			),

		owner =
			player,

		capacity =
			capacity,

		visibility =
			visibility,

		rules = cleanRules,

		members = {
			player,
		},

		locked =
			false,

		teleporting =
			false,

		createdAt =
			os.time(),

		restoredFromMatch =
			false,
	}

	-- Filtering yields; never overwrite membership established in the meantime.
	if player.Parent~=Players or Players:GetPlayerByUserId(player.UserId)~=player
		or player:GetAttribute("SpyQuickQueueActive")or membership[player.UserId]
		or(player:GetAttribute("SpyRelayTableId")or "")~="" then return {ok=false,code="already_active"}end
	parties[code] =
		party

	membership[player.UserId] =
		party

	pushParty(party)

	return {
		ok = true,
		party =
			partyPublic(party),
	}
end

---------------------------------------------------------------------
-- JOIN
---------------------------------------------------------------------

local function joinParty(player, party)
	if player:GetAttribute("SpyQuickQueueActive")or(player:GetAttribute("SpyRelayTableId")or "")~=""then return {ok=false,code="already_active"}end
	if not party then
		return {
			ok = false,
			code = "party_not_found",
		}
	end

	cleanMembers(party)

	if party.locked
		or party.teleporting
	then
		return {
			ok = false,
			code = "party_locked",
		}
	end

	if membership[player.UserId]
		== party
	then
		return {
			ok = true,
			party =
				partyPublic(party),
		}
	end

	if #party.members
		>= party.capacity
	then
		return {
			ok = false,
			code = "party_full",
		}
	end

	if membership[player.UserId] then
		local previous =
			membership[player.UserId]

		if previous.teleporting then
			return {
				ok = false,
				code = "already_starting",
			}
		end

		leaveParty(
			player,
			"replaced"
		)
	end

	table.insert(
		party.members,
		player
	)

	membership[player.UserId] =
		party

	pushParty(party)

	return {
		ok = true,
		party =
			partyPublic(party),
	}
end

---------------------------------------------------------------------
-- JOIN BY CODE
---------------------------------------------------------------------

local function joinByCode(player, rawCode)
	if type(rawCode) ~= "string" then
		return {
			ok = false,
			code = "invalid_code",
		}
	end

	local code =
		string.upper(
			rawCode:
			gsub("%s+", "")
		)

	if #code ~= 5 then
		return {
			ok = false,
			code = "invalid_code",
		}
	end

	return joinParty(
		player,
		parties[code]
	)
end

---------------------------------------------------------------------
-- KICK
---------------------------------------------------------------------

local function kickMember(
	player,
	targetUserId
)
	local party =
		membership[player.UserId]

	if not party then
		return {
			ok = false,
			code = "not_in_party",
		}
	end

	if party.locked
		or party.teleporting
	then
		return {
			ok = false,
			code = "party_locked",
		}
	end

	if party.owner ~= player then
		return {
			ok = false,
			code = "not_owner",
		}
	end

	targetUserId =
		tonumber(
			targetUserId
		)

	if not targetUserId then
		return {
			ok = false,
			code = "invalid_target",
		}
	end

	if targetUserId
		== player.UserId
	then
		return {
			ok = false,
			code = "cannot_kick_self",
		}
	end

	local target = nil

	for _, member in ipairs(
		party.members
		) do
		if member.UserId
			== targetUserId
		then
			target = member
			break
		end
	end

	if not target then
		return {
			ok = false,
			code = "target_not_found",
		}
	end

	membership[target.UserId] =
		nil

	for index, member in ipairs(
		party.members
		) do
		if member == target then
			table.remove(
				party.members,
				index
			)

			break
		end
	end

	if target.Parent == Players then
		update:FireClient(
			target,
			nil,
			"kicked"
		)
	end

	pushParty(party)

	return {
		ok = true,
		party =
			partyPublic(party),
	}
end

---------------------------------------------------------------------
-- PUBLIC LIST
---------------------------------------------------------------------

local function publicList()
	local result = {}

	for code, party in pairs(parties) do
		cleanMembers(party)

		if #party.members == 0 then
			parties[code] = nil

		elseif party.visibility == "public"
			and not party.locked
			and not party.teleporting
			and #party.members < party.capacity
		then
			if not party.owner then
				party.owner =
					party.members[1]
			end

			if party.owner then
				result[#result + 1] = {
					id =
						party.id,

					code =
						party.code,

					name =
						party.name,

					ownerId =
						party.owner.UserId,

					ownerName =
						party.owner.DisplayName,

					count =
						#party.members,

					capacity =
						party.capacity,

					createdAt =
						party.createdAt,
				}
			end
		end
	end

	table.sort(
		result,
		function(a, b)
			if a.count ~= b.count then
				return a.count > b.count
			end

			return a.createdAt < b.createdAt
		end
	)

	return result
end

---------------------------------------------------------------------
-- TELEPORT DATA
---------------------------------------------------------------------

local function makeTeleportData(party)
	local memberIds = {}

	for _, member in ipairs(party.members) do
		if member.Parent == Players then
			memberIds[#memberIds + 1] =
				member.UserId
		end
	end

	return {
		version = 1,

		partyId =
			party.id,

		partyCode =
			party.code,

		partyName =
			party.name,

		ownerId =
			party.owner.UserId,

		capacity =
			party.capacity,

		visibility =
			party.visibility,

		memberIds =
			memberIds,

		rules = publicRules(party.rules),

		sourcePlaceId =
			game.PlaceId,
		lobbyJobId = game.JobId,

		startedAt =
			os.time(),
	}
end

---------------------------------------------------------------------
-- START MATCH
---------------------------------------------------------------------

local function startParty(player)
	local party =
		membership[player.UserId]

	if not party then
		return {
			ok = false,
			code = "not_in_party",
		}
	end

	if party.owner ~= player then
		return {
			ok = false,
			code = "not_owner",
		}
	end

	if party.locked
		or party.teleporting
	then
		return {
			ok = false,
			code = "already_starting",
		}
	end

	cleanMembers(party)

	if #party.members < 3 then
		return {
			ok = false,
			code = "not_enough_players",
		}
	end

	local teleportPlayers = {}

	for _, member in ipairs(
		party.members
		) do
		if member.Parent == Players then
			teleportPlayers[
			#teleportPlayers + 1
			] = member
		end
	end

	if #teleportPlayers < 3 then
		return {
			ok = false,
			code = "not_enough_players",
		}
	end

    if RunService:IsStudio() then
        return {ok=false,code="studio_teleport"}
    end
    for _,member in ipairs(teleportPlayers) do
        if member:GetAttribute("SpyProfileReady")~=true
            or member:GetAttribute("SpyEconomyBusy")==true
            or (member:GetAttribute("SpyProfilePending") or 0)>0 then
            return {ok=false,code="profile_busy"}
        end
    end
	party.locked = true
	party.teleporting = true

	pushParty(party)

	local options =
		Instance.new(
			"TeleportOptions"
		)

	-- Reserve explicitly: the capability stays exclusively in server MemoryStore.
	local reserved, accessCode, privateId = pcall(function()
		return TeleportService:ReserveServerAsync(MATCH_PLACE_ID)
	end)
	local data = makeTeleportData(party)
	data.sessionId = HttpService:GenerateGUID(false)
	if not reserved or not Reconnect:prepare(data, MATCH_PLACE_ID, accessCode, privateId) then
		party.locked = false
		party.teleporting = false
		pushParty(party)
		return {ok=false, code="reconnect_service_unavailable"}
	end
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(data)

	local success, teleportResult =
		pcall(function()
			return
			TeleportService:
			TeleportAsync(
				MATCH_PLACE_ID,
				teleportPlayers,
				options
			)
		end)

	if not success then
		Reconnect:close(data.sessionId)
		warn(
			"[SpyPartyServer] Teleport failed:",
			teleportResult
		)

		party.locked = false
		party.teleporting = false

		pushParty(party)

		return {
			ok = false,
			code = "teleport_failed",
		}
	end

	return {
		ok = true,
		code = "teleporting",
	}
end

---------------------------------------------------------------------
-- ASYNC TELEPORT FAILURE
---------------------------------------------------------------------

TeleportService.TeleportInitFailed:Connect(
	function(
		player,
		teleportResult,
		errorMessage,
		placeId
	)
		if placeId ~= MATCH_PLACE_ID then
			return
		end
		if player:GetAttribute("SpyReconnectBusy") then
			player:SetAttribute("SpyReconnectBusy", false)
			player:SetAttribute("SpyTeleporting", false)
			return
		end

		warn(
			"[SpyPartyServer] TeleportInitFailed:",
			player.Name,
			teleportResult,
			errorMessage
		)

		local party =
			membership[
		player.UserId
		]

		if not party
			or not party.teleporting
		then
			return
		end

		party.teleporting = false
		party.locked = false

		pushParty(party)
	end
)

-- Structured phone invitations use the same server party ownership and join rules.
local clubPartyBridge=Instance.new("BindableFunction")
clubPartyBridge.Name="SpyClubPartyBridge";clubPartyBridge.Parent=game:GetService("ServerStorage")
clubPartyBridge.OnInvoke=function(player,action,partyId)
 if not player or player.Parent~=Players or Players:GetPlayerByUserId(player.UserId)~=player then return nil end
 if action=="get"then return partyPublic(membership[player.UserId])end
 if action~="join"or type(partyId)~="string"then return{ok=false,code="party_not_found"}end
 if player:GetAttribute("SpyTeleporting")or player:GetAttribute("SpyReconnectBusy")or player:GetAttribute("SpyBilliardsPlaying")or player:GetAttribute("SpyCheckersPlaying")then return{ok=false,code="already_active"}end
 for _,party in pairs(parties)do if party.id==partyId then return joinParty(player,party)end end
 return{ok=false,code="party_not_found"}
end

---------------------------------------------------------------------
-- REQUESTS
---------------------------------------------------------------------

request.OnServerInvoke =
	function(player, action, value)
		if action == "ReconnectStatus" then
			local cached = reconnectStatusCache[player.UserId]
			if cached and os.clock() - cached.at < 2 then return cached.value end
			local slot = {at=os.clock(), value={ok=true,available=false,expiresAt=0}}
			reconnectStatusCache[player.UserId] = slot
			local offer = Reconnect:offer(player.UserId)
			slot.value = {ok=true, available=offer ~= nil, expiresAt=offer and offer.expiresAt or 0}
			return slot.value
		elseif action == "ReconnectDismiss" then
			if player:GetAttribute("SpyReconnectBusy") or player:GetAttribute("SpyTeleporting") then return {ok=false,code="busy"} end
			if os.clock() - (reconnectActionAt[player.UserId] or -10) < 1 then return {ok=false,code="busy"} end
			reconnectActionAt[player.UserId] = os.clock()
			Reconnect:clearUser(player.UserId)
			reconnectStatusCache[player.UserId] = nil
			return {ok=true}
		elseif action == "Reconnect" then
			if player:GetAttribute("SpyQuickQueueActive")then return {ok=false,code="already_active"}end
			if os.clock() - (reconnectActionAt[player.UserId] or -10) < 1 then return {ok=false,code="busy"} end
			reconnectActionAt[player.UserId] = os.clock()
			if player:GetAttribute("SpyReconnectBusy") or player:GetAttribute("SpyTeleporting") then return {ok=false, code="busy"} end
			player:SetAttribute("SpyReconnectBusy", true)
			player:SetAttribute("SpyTeleporting", true)
			local function resetReconnectBusy()
				player:SetAttribute("SpyReconnectBusy", false)
				player:SetAttribute("SpyTeleporting", false)
			end
			local offer = Reconnect:offer(player.UserId)
			if not offer then
				resetReconnectBusy()
				return {ok=false, code="reconnect_expired"}
			end
			if player:GetAttribute("SpyProfileReady") ~= true or player:GetAttribute("SpyEconomyBusy") == true
				or (player:GetAttribute("SpyProfilePending") or 0) > 0 then
				resetReconnectBusy()
				return {ok=false, code="profile_busy"}
			end
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = offer.code
			options:SetTeleportData(offer.data)
			local ok = pcall(function() TeleportService:TeleportAsync(offer.placeId, {player}, options) end)
			if not ok then resetReconnectBusy() end
			task.delay(8, function() if player.Parent then resetReconnectBusy() end end)
			return {ok=ok, code=ok and "teleporting" or "teleport_failed"}
		end

		if type(action) ~= "string" then
			return {
				ok = false,
				code = "invalid_action",
			}
		end

		if action == "Create" then
			return createParty(
				player,
				value
			)

		elseif action == "Leave" then
			local party =
			membership[
			player.UserId
			]

			if party
				and party.teleporting
			then
				return {
					ok = false,
					code = "already_starting",
				}
			end
			Reconnect:clearUser(player.UserId)
			reconnectStatusCache[player.UserId] = nil

			return leaveParty(
				player,
				"left"
			)

		elseif action == "Get" then
			if not membership[player.UserId] then
				restoreReturningPlayer(player)
			end

			return {
				ok = true,

				party =
				partyPublic(
					membership[
					player.UserId
					]
				),
			}

		elseif action == "ListPublic" then
			return {
				ok = true,
				parties =
				publicList(),
			}

		elseif action == "JoinByCode" then
			return joinByCode(
				player,
				value
			)

		elseif action == "Kick" then
			return kickMember(
				player,
				value
			)

		elseif action == "Start" then
			return startParty(
				player
			)
		end

		return {
			ok = false,
			code = "unknown_action",
		}
	end

---------------------------------------------------------------------
-- RETURNING PLAYERS
---------------------------------------------------------------------

local function playerAdded(player)
	player:SetAttribute("SpyReturnRestoreState", "checking")
	task.spawn(function()
		restoreReturningPlayer(player)
	end)
end

Players.PlayerAdded:Connect(
	playerAdded
)

for _, player in ipairs(
	Players:GetPlayers()
	) do
	playerAdded(player)
end

---------------------------------------------------------------------
-- PLAYER REMOVING
---------------------------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)
		reconnectStatusCache[player.UserId] = nil
		reconnectActionAt[player.UserId] = nil
		leaveParty(
			player,
			"disconnected"
		)
	end
)
