-- Global, persistent rankings shared by every server in this experience.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Storage = game:GetService("ReplicatedStorage")

local Leaderboards = {}

local DEFINITIONS = {
	{
		board = "Wins",
		field = "wins",
		store = DataStoreService:GetOrderedDataStore("SpyClubWins_AllTime_v1"),
		monotonic = true,
	},
	{
		board = "Coins",
		field = "coinsEarned",
		store = DataStoreService:GetOrderedDataStore("SpyClubCoins_AllTime_v1"),
		monotonic = true,
	},
	{
		board = "Level",
		field = "level",
		store = DataStoreService:GetOrderedDataStore("SpyClubLevel_AllTime_v1"),
		monotonic = true,
	},
	{
		board = "Supporters",
		field = "supporters",
		store = DataStoreService:GetOrderedDataStore("SpyClubSupporters_AllTime_v1"),
		monotonic = true,
	},
}

local pending = {}
local recorded = {}
local nameCache = {}
local workerRunning = false
local rerunRequested = false
local lastReadAt,forceRead=-math.huge,false
local boardCache,lastRequest={},{}
local PAGE_SIZE=5
local folder=Storage:FindFirstChild("SpyLeaderboards") or Instance.new("Folder")
folder.Name="SpyLeaderboards";folder.Parent=Storage
local function remote(name)
 local r=folder:FindFirstChild(name) or Instance.new("RemoteEvent")
 r.Name=name;r.Parent=folder;return r
end
local request,state=remote("Request"),remote("State")
local boardNames={Wins=true,Coins=true,Level=true,Supporters=true}
request.OnServerEvent:Connect(function(player,payload)
 if player.Parent~=Players or type(payload)~="table" or not boardNames[payload.board]
  or type(payload.id)~="string" or #payload.id>80 or #payload.id==0
  or type(payload.page)~="number" or payload.page~=payload.page or payload.page%1~=0 then return end
 local now=os.clock()
 if now-(lastRequest[player.UserId] or -math.huge)<.25 then return end
 lastRequest[player.UserId]=now
 local cached=boardCache[payload.board]
 if not cached then state:FireClient(player,{id=payload.id,board=payload.board,ok=false,code="loading"});return end
 local pages=math.max(1,math.ceil(#cached.rows/PAGE_SIZE))
 local page=math.clamp(payload.page,1,pages)
 local rows={}
 for index=(page-1)*PAGE_SIZE+1,math.min(page*PAGE_SIZE,#cached.rows) do
  table.insert(rows,cached.rows[index])
 end
 state:FireClient(player,{id=payload.id,board=payload.board,ok=true,page=page,pages=pages,rows=rows,
  total=#cached.rows,updatedAt=cached.updatedAt,stale=cached.stale==true,allTime=true})
end)
Players.PlayerRemoving:Connect(function(player)lastRequest[player.UserId]=nil;recorded[player.UserId]=nil end)

local function profileValue(profile, field)
	return math.max(0, math.floor(tonumber(profile[field]) or (field=="coinsEarned" and tonumber(profile.coins)) or 0))
end

local function queueProfiles(profiles)
	if not profiles then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = profiles:public(player.UserId)
		if profile.ready then
			local values = {}
			for _, definition in ipairs(DEFINITIONS) do
				values[definition.field] = profileValue(profile, definition.field)
			end
			pending[player.UserId] = values
			nameCache[player.UserId] = player.DisplayName
		end
	end
end

local function writePending()
	local batch = pending
	pending = {}
    local wrote=false

	for userId, values in pairs(batch) do
        -- Retain this row across a yielding write. PlayerRemoving may detach
        -- the cache entry while Roblox is still persisting the snapshot.
        local recordedValues=recorded[userId] or {}
        recorded[userId]=recordedValues
		for _, definition in ipairs(DEFINITIONS) do
			local value = values[definition.field]
            local prior=recordedValues[definition.field]
			if prior==nil or (definition.monotonic and value>prior) or (not definition.monotonic and prior~=value) then
				local ok,persisted = pcall(function()
					return definition.store:UpdateAsync("u_" .. tostring(userId), function(oldValue)
						if definition.monotonic then
							return math.max(tonumber(oldValue) or 0, value)
						end
						return value
					end)
				end)

				if ok then
					recordedValues[definition.field] = tonumber(persisted) or value
                    wrote=true
				end
			end
		end
	end
    return wrote
end

local function displayName(userId)
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end

	if nameCache[userId] then
		return nameCache[userId]
	end

	local ok, username = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local resolved = ok and username or ("Игрок " .. tostring(userId))
	nameCache[userId] = resolved
	return resolved
end

local function boardLabel(boardName)
	local world = workspace:FindFirstChild("SpyClub")
	local board = world and world:FindFirstChild("Board" .. boardName)
	return board and board:FindFirstChild("Rows", true)
end

local function readBoards()
	for _, definition in ipairs(DEFINITIONS) do
		local ok, entries = pcall(function()
			return definition.store:GetSortedAsync(false,100):GetCurrentPage()
		end)

		if ok and type(entries)=="table" then
			local lines,rows = {},{}
			for _, entry in ipairs(entries) do
				local userId = tonumber(string.match(tostring(entry.key), "^u_(%d+)$"))
				local value = math.max(0, math.floor(tonumber(entry.value) or 0))
				if userId and userId>0 and (definition.field ~= "supporters" or value > 0) then
                    local name=displayName(userId)
                    table.insert(rows,{rank=#rows+1,userId=userId,name=name,value=value})
                    if #lines<PAGE_SIZE then lines[#lines + 1] = string.format(
						"%d.  %s  ·  %d",
						#lines + 1,
						name,
						value
					) end
				end
			end

			boardCache[definition.board]={rows=rows,updatedAt=os.time(),stale=false}
			local label = boardLabel(definition.board)
			if label then
				label.Text = #lines > 0 and table.concat(lines, "\n") or "—"
				label:SetAttribute("GlobalAllTime", true)
			end
        elseif boardCache[definition.board] then
            boardCache[definition.board].stale=true
		end
	end
end

local function startWorker()
	if workerRunning then
		rerunRequested = true
		return
	end

	workerRunning = true
	task.spawn(function()
        local ok=pcall(function()repeat
			rerunRequested = false
            local wrote=writePending()
            if wrote or forceRead or os.clock()-lastReadAt>=60 then
                forceRead=false;lastReadAt=os.clock();readBoards()
            end
		until not rerunRequested and next(pending) == nil end)
		workerRunning = false
        if not ok then warn("[SPY LEADERBOARDS] worker_failed") end
	end)
end

function Leaderboards.refresh(profiles)
    if not profiles then forceRead=true end
	queueProfiles(profiles)
	startWorker()
end

task.spawn(function()
	while task.wait(60) do
		Leaderboards.refresh(nil)
	end
end)

return Leaderboards
