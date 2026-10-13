-- StarterPlayerScripts > ReplayPartyClient
-- SPY CLUB
-- Меняет обычную кнопку старта после возврата из Match:
--
-- НАЧАТЬ ИГРУ
-- ->
-- ИГРАТЬ СНОВА
--
-- Если после матча вернулось меньше 3 игроков:
-- ОЖИДАЕМ ИГРОКОВ · 2/3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------

local remotes =
	ReplicatedStorage:WaitForChild(
		"SpyPartyRemotes"
	)

local request =
	remotes:WaitForChild(
		"Request"
	)

local update =
	remotes:WaitForChild(
		"Update"
	)

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

local currentParty = nil

local MIN_PLAYERS = 3

-- A reconnect offer is a server-verified capability, never TeleportData or a
-- client-entered code. Only availability and the absolute expiry are public.
local reconnectGui = Instance.new("ScreenGui")
reconnectGui.Name = "SpyReconnectOffer"
reconnectGui.ResetOnSpawn = false
reconnectGui.DisplayOrder = 180
reconnectGui.Parent = playerGui
local reconnectFrame = Instance.new("Frame")
reconnectFrame.AnchorPoint = Vector2.new(0.5, 0)
reconnectFrame.Position = UDim2.new(0.5, 0, 0, 80)
reconnectFrame.Size = UDim2.new(1, -24, 0, 114)
reconnectFrame.BackgroundColor3 = Color3.fromRGB(31,24,26)
reconnectFrame.Visible = false
reconnectFrame.Parent = reconnectGui
local reconnectLimit = Instance.new("UISizeConstraint")
reconnectLimit.MaxSize = Vector2.new(350, 114)
reconnectLimit.Parent = reconnectFrame
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = reconnectFrame
local reconnectText = Instance.new("TextLabel")
reconnectText.BackgroundTransparency = 1
reconnectText.Position = UDim2.fromOffset(12, 8)
reconnectText.Size = UDim2.new(1, -24, 0, 42)
reconnectText.Font = Enum.Font.GothamMedium
reconnectText.TextSize = 15
reconnectText.TextColor3 = Color3.fromRGB(239,226,205)
reconnectText.TextWrapped = true
reconnectText.Parent = reconnectFrame
local reconnectButton = Instance.new("TextButton")
reconnectButton.Position = UDim2.fromOffset(12, 60)
reconnectButton.Size = UDim2.new(1, -106, 0, 40)
reconnectButton.BackgroundColor3 = Color3.fromRGB(103,75,46)
reconnectButton.TextColor3 = Color3.fromRGB(255,244,218)
reconnectButton.Font = Enum.Font.GothamBold
reconnectButton.TextSize = 15
reconnectButton.Parent = reconnectFrame
local dismissButton = reconnectButton:Clone()
dismissButton.Position = UDim2.new(1, -86, 0, 60)
dismissButton.Size = UDim2.fromOffset(74, 40)
dismissButton.Parent = reconnectFrame
local reconnectExpires = 0
local reconnectBusy = false
local reconnectError = false
local function english()
	return player:GetAttribute("SpyLanguage") == "en"
end
reconnectButton.Activated:Connect(function()
	if reconnectBusy then return end
	reconnectBusy = true
	local ok, result = pcall(function() return request:InvokeServer("Reconnect") end)
	reconnectError = not ok or type(result) ~= "table" or result.ok ~= true
	if reconnectError then reconnectBusy = false end
	task.delay(8, function() reconnectBusy = false end)
end)
dismissButton.Activated:Connect(function()
	if reconnectBusy then return end
	reconnectExpires = 0
	reconnectFrame.Visible = false
	pcall(function() request:InvokeServer("ReconnectDismiss") end)
end)
task.spawn(function()
	while reconnectGui.Parent do
		local ok, result = pcall(function() return request:InvokeServer("ReconnectStatus") end)
		if ok and type(result) == "table" then
			reconnectExpires = result.available and tonumber(result.expiresAt) or 0
		end
		task.wait(4)
	end
end)
task.spawn(function()
	while reconnectGui.Parent do
		local remaining = math.max(0, math.ceil((reconnectExpires or 0) - workspace:GetServerTimeNow()))
		reconnectFrame.Visible = remaining > 0
		dismissButton.Text = english() and "Leave" or "Уйти"
		reconnectButton.Text = reconnectBusy and (english() and "Connecting…" or "Подключение…")
			or (english() and "REJOIN MATCH" or "ВЕРНУТЬСЯ В МАТЧ")
		reconnectText.Text = reconnectError and (english() and "Could not reconnect. Try again before time runs out." or "Не удалось вернуться. Попробуйте снова до конца отсчёта.")
			or string.format(english() and "Your seat is saved · %ds remaining" or "Ваше место сохранено · осталось %d сек.", remaining)
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- BUTTON DETECTION
---------------------------------------------------------------------

local function isStartButton(object)
	if not object:IsA("TextButton") then
		return false
	end

	local text =
		string.upper(
			tostring(
				object.Text or ""
			)
		)

	-- Уже изменённая нами кнопка.
	if string.find(
		text,
		"ИГРАТЬ СНОВА",
		1,
		true
		) then
		return true
	end

	if string.find(
		text,
		"ОЖИДАЕМ ИГРОКОВ",
		1,
		true
		) then
		return true
	end

	-- Обычная кнопка существующего TableReservationClient.
	if string.find(
		text,
		"НАЧАТЬ ИГРУ",
		1,
		true
		) then
		return true
	end

	return false
end

---------------------------------------------------------------------
-- LOCAL PLAYER IS HOST
---------------------------------------------------------------------

local function isOwner()
	return
		currentParty
		and tonumber(
			currentParty.ownerId
		)
		== player.UserId
end

---------------------------------------------------------------------
-- APPLY
---------------------------------------------------------------------

local changing = {}

local function updateButton(button)
	if changing[button] then
		return
	end

	if not currentParty then
		return
	end

	if currentParty.returnedFromMatch
		~= true
	then
		return
	end

	if not isOwner() then
		return
	end

	changing[button] = true

	local count =
		tonumber(
			currentParty.count
		)
		or 0

	-------------------------------------------------------------
	-- ENOUGH PLAYERS
	-------------------------------------------------------------

	if count >= MIN_PLAYERS then
		button.Text =
			"ИГРАТЬ СНОВА"

		button.Active = true
		button.AutoButtonColor = true

		button.TextTransparency = 0

		-------------------------------------------------------------
		-- WAITING FOR PLAYERS
		-------------------------------------------------------------

	else
		button.Text =
			string.format(
				"ОЖИДАЕМ ИГРОКОВ · %d/%d",
				count,
				MIN_PLAYERS
			)

		-- Сам сервер всё равно не позволит старт < 3,
		-- но блокируем кнопку и на клиенте.
		button.Active = false
		button.AutoButtonColor = false

		button.TextTransparency = 0.18
	end

	changing[button] = nil
end

---------------------------------------------------------------------
-- SCAN UI
---------------------------------------------------------------------

local function refreshUI()
	if not currentParty
		or currentParty.returnedFromMatch
		~= true
		or not isOwner()
	then
		return
	end

	for _, object in ipairs(
		playerGui:GetDescendants()
		) do
		if isStartButton(object) then
			updateButton(object)
		end
	end
end

---------------------------------------------------------------------
-- WATCH NEW UI
---------------------------------------------------------------------

playerGui.DescendantAdded:Connect(
	function(object)
		if not object:IsA("TextButton") then
			return
		end

		task.defer(
			function()
				if object.Parent
					and isStartButton(object)
				then
					updateButton(object)
				end
			end
		)
	end
)

---------------------------------------------------------------------
-- WATCH BUTTON TEXT
--
-- Existing TableReservationClient may redraw its button after
-- a party update. We quietly put our replay text back.
---------------------------------------------------------------------

local watched = {}

local function watchButton(button)
	if watched[button] then
		return
	end

	watched[button] = true

	button:GetPropertyChangedSignal(
		"Text"
	):Connect(
		function()
			if not button.Parent then
				watched[button] = nil
				return
			end

			if changing[button] then
				return
			end

			task.defer(
				function()
					if button.Parent
						and currentParty
						and currentParty.returnedFromMatch
						== true
						and isOwner()
						and isStartButton(button)
					then
						updateButton(button)
					end
				end
			)
		end
	)
end

local function refreshWatchers()
	for _, object in ipairs(
		playerGui:GetDescendants()
		) do
		if object:IsA("TextButton") then
			watchButton(object)
		end
	end
end

playerGui.DescendantAdded:Connect(
	function(object)
		if object:IsA("TextButton") then
			watchButton(object)
		end
	end
)

---------------------------------------------------------------------
-- PARTY UPDATE
---------------------------------------------------------------------

update.OnClientEvent:Connect(
	function(party)
		currentParty = party

		task.defer(
			function()
				refreshWatchers()
				refreshUI()
			end
		)
	end
)

---------------------------------------------------------------------
-- INITIAL PARTY STATE
---------------------------------------------------------------------

task.spawn(
	function()
		local ok, response =
			pcall(function()
				return
				request:InvokeServer(
					"Get"
				)
			end)

		if not ok
			or type(response)
			~= "table"
		then
			return
		end

		if response.ok == true then
			currentParty =
				response.party

			refreshWatchers()
			refreshUI()
		end
	end
)

---------------------------------------------------------------------
-- PERIODIC SAFETY REFRESH
---------------------------------------------------------------------

task.spawn(
	function()
		while true do
			task.wait(1)

			if currentParty
				and currentParty.returnedFromMatch
				== true
			then
				refreshUI()
			end
		end
	end
)
