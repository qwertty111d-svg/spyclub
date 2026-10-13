-- StarterPlayer > StarterPlayerScripts > CoinRewardFXClient
-- SPY CLUB / COIN REWARD FX V3
--
-- Универсальный:
-- • MatchRewardServer
-- • Lobby Daily/Profile rewards
--
-- НИКАКИХ тестовых N-кнопок.
-- Показывает только реальную серверную награду.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- STYLE
---------------------------------------------------------------------

local C = {
	Dark = Color3.fromRGB(27, 23, 22),
	Surface = Color3.fromRGB(38, 31, 28),

	Cream = Color3.fromRGB(249, 226, 194),
	Text = Color3.fromRGB(236, 222, 203),
	Muted = Color3.fromRGB(183, 164, 143),

	Gold = Color3.fromRGB(226, 184, 117),
	GoldLight = Color3.fromRGB(252, 220, 162),
	GoldDark = Color3.fromRGB(137, 94, 51),

	Line = Color3.fromRGB(108, 84, 65),
}

local FONT_HEAVY = Enum.Font.GothamBlack
local FONT_BOLD = Enum.Font.GothamBold
local FONT_BODY = Enum.Font.BuilderSans

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function make(className, parent, properties)
	local object =
		Instance.new(
			className
		)

	for key, value in pairs(
		properties or {}
		) do
		object[key] =
			value
	end

	object.Parent =
		parent

	return object
end

local function round(parent, radius)
	local corner =
		parent:
		FindFirstChildOfClass(
			"UICorner"
		)

	if not corner then
		corner =
			Instance.new(
				"UICorner"
			)

		corner.Parent =
			parent
	end

	corner.CornerRadius =
		UDim.new(
			0,
			radius
		)

	return corner
end

local function stroke(
	parent,
	color,
	transparency,
	thickness
)
	return make(
		"UIStroke",
		parent,
		{
			ApplyStrokeMode =
				Enum.ApplyStrokeMode.Border,

			Color = color,

			Transparency =
				transparency,

			Thickness =
				thickness,
		}
	)
end

local function tween(
	object,
	duration,
	style,
	direction,
	properties
)
	local motion =
		TweenService:
		Create(
			object,
			TweenInfo.new(
				duration,
				style
				or Enum.EasingStyle.Quint,
				direction
				or Enum.EasingDirection.Out
			),
			properties
		)

	motion:Play()

	return motion
end

local function label(
	parent,
	text,
	position,
	size,
	font,
	textSize,
	color,
	z
)
	return make(
		"TextLabel",
		parent,
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Position = position,
			Size = size,

			Text = text,

			TextScaled = false,
			TextWrapped = false,

			Font = font,
			TextSize = textSize,

			TextColor3 = color,

			TextXAlignment =
				Enum.TextXAlignment.Center,

			TextYAlignment =
				Enum.TextYAlignment.Center,

			ZIndex = z or 10,
		}
	)
end

---------------------------------------------------------------------
-- REMOVE PREVIOUS
---------------------------------------------------------------------

local old =
	playerGui:
	FindFirstChild(
		"SpyCoinRewardFX"
	)

if old then
	old:Destroy()
end

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local gui =
	make(
		"ScreenGui",
		playerGui,
		{
			Name =
			"SpyCoinRewardFX",

			ResetOnSpawn = false,
			IgnoreGuiInset = true,

			DisplayOrder = 600,

			ZIndexBehavior =
			Enum.ZIndexBehavior.Sibling,
		}
	)

local layer =
	make(
		"Frame",
		gui,
		{
			Name =
			"RewardLayer",

			Size =
			UDim2.fromScale(
				1,
				1
			),

			BackgroundTransparency =
			1,

			ClipsDescendants =
			false,
		}
	)

---------------------------------------------------------------------
-- WALLET
---------------------------------------------------------------------

local walletFrame = nil
local walletText = nil

local function discoverWallet()
	local hudGui = playerGui:FindFirstChild("HudGui")
	local topStatus = hudGui and hudGui:FindFirstChild("TopStatus")
	local coins = topStatus and topStatus:FindFirstChild("Coins")
	local value = coins and coins:FindFirstChild("Value")

	if coins
		and coins:IsA("GuiObject")
		and value
		and value:IsA("TextLabel")
	then
		walletFrame = coins
		walletText = value
		return true
	end

	return false
end

local function ensureWallet(_balance)
	if walletFrame
		and walletFrame.Parent
		and walletText
		and walletText.Parent
	then
		return walletFrame, walletText
	end

	if discoverWallet() then
		return walletFrame, walletText
	end

	local hudGui = playerGui:WaitForChild("HudGui")
	local topStatus = hudGui:WaitForChild("TopStatus")
	local coins = topStatus:WaitForChild("Coins")
	local value = coins:WaitForChild("Value")

	if not coins:IsA("GuiObject")
		or not value:IsA("TextLabel")
	then
		error("[CoinRewardFX] Lobby wallet has an invalid structure")
	end

	walletFrame = coins
	walletText = value
	return walletFrame, walletText
end

local function walletCenter(balance)
	local frame =
		ensureWallet(
			balance
		)

	return
		frame.AbsolutePosition
		+ frame.AbsoluteSize / 2
end

---------------------------------------------------------------------
-- WALLET COUNTER
---------------------------------------------------------------------

local counterOverlay = nil
local hiddenText = nil
local hiddenTransparency = nil

local function beginCounter(
	previousBalance
)
	local frame, text =
		ensureWallet(
			previousBalance
		)

	if counterOverlay then
		counterOverlay:Destroy()
		counterOverlay = nil
	end

	hiddenText =
		text

	hiddenTransparency =
		text.TextTransparency

	text.TextTransparency =
		1

	local overlay =
		text:Clone()

	overlay.Name =
		"RewardCounter"

	overlay.Text =
		tostring(
			math.floor(
				previousBalance
			)
		)

	overlay.TextTransparency =
		0

	overlay.Font =
		FONT_HEAVY

	overlay.ZIndex =
		text.ZIndex
		+ 30

	for _, child in ipairs(
		overlay:GetChildren()
		) do
		if child:IsA(
			"UIScale"
			) then
			child:Destroy()
		end
	end

	overlay.Parent =
		frame

	counterOverlay =
		overlay
end

local function setCounter(
	value
)
	if counterOverlay
		and counterOverlay.Parent
	then
		counterOverlay.Text =
			tostring(
				math.floor(
					value + 0.5
				)
			)
	end
end

local function endCounter(
	finalBalance
)
	if hiddenText
		and hiddenText.Parent
	then
        -- SpyClient owns the balance. A queued effect may finish after a
        -- newer purchase, so it must never restore its old numeric snapshot.

		hiddenText.TextTransparency =
			hiddenTransparency
			or 0
	end

	hiddenText = nil
	hiddenTransparency = nil

	if counterOverlay then
		counterOverlay:Destroy()
		counterOverlay = nil
	end
end

---------------------------------------------------------------------
-- WALLET IMPACT
---------------------------------------------------------------------

local walletPulse =
	0

local function popWallet()
	local frame =
		ensureWallet(0)

	walletPulse += 1

	local token =
		walletPulse

	local scale =
		frame:
		FindFirstChild(
			"RewardPop"
		)

	if not scale then
		scale =
			Instance.new(
				"UIScale"
			)

		scale.Name =
			"RewardPop"

		scale.Scale =
			1

		scale.Parent =
			frame
	end

	tween(
		scale,
		0.055,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out,
		{
			Scale = 1.075,
		}
	)

	task.delay(
		0.06,
		function()
			if token
				~= walletPulse
			then
				return
			end

			tween(
				scale,
				0.15,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out,
				{
					Scale = 1,
				}
			)
		end
	)
end

---------------------------------------------------------------------
-- COIN
---------------------------------------------------------------------

local function createCoin(
	position,
	size
)
	local coin =
		make(
			"Frame",
			layer,
			{
				Name =
				"RewardCoin",

				AnchorPoint =
				Vector2.new(
					0.5,
					0.5
				),

				Position =
				UDim2.fromOffset(
					position.X,
					position.Y
				),

				Size =
				UDim2.fromOffset(
					size,
					size
				),

				BackgroundColor3 =
				C.Gold,

				BorderSizePixel =
				0,

				Rotation =
				math.random(
					-25,
					25
				),

				ZIndex =
				630,
			}
		)

	round(
		coin,
		size
	)

	stroke(
		coin,
		C.GoldLight,
		0.10,
		1.3
	)

	local inset =
		make(
			"Frame",
			coin,
			{
				AnchorPoint =
				Vector2.new(
					0.5,
					0.5
				),

				Position =
				UDim2.fromScale(
					0.5,
					0.5
				),

				Size =
				UDim2.fromScale(
					0.62,
					0.62
				),

				BackgroundTransparency =
				1,

				BorderSizePixel =
				0,

				ZIndex =
				631,
			}
		)

	round(
		inset,
		size
	)

	stroke(
		inset,
		C.GoldDark,
		0.25,
		1
	)

	local diamond =
		make(
			"Frame",
			coin,
			{
				AnchorPoint =
				Vector2.new(
					0.5,
					0.5
				),

				Position =
				UDim2.fromScale(
					0.5,
					0.5
				),

				Size =
				UDim2.fromScale(
					0.22,
					0.22
				),

				BackgroundColor3 =
				C.GoldDark,

				BorderSizePixel =
				0,

				Rotation =
				45,

				ZIndex =
				632,
			}
		)

	round(
		diamond,
		2
	)

	local scale =
		make(
			"UIScale",
			coin,
			{
				Scale =
				0.20,
			}
		)

	tween(
		scale,
		0.19,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out,
		{
			Scale = 1,
		}
	)

	return coin, scale
end

---------------------------------------------------------------------
-- BEZIER
---------------------------------------------------------------------

local function bezier(
	a,
	b,
	c,
	t
)
	local u =
		1 - t

	return
		a * u * u
		+ b * 2 * u * t
		+ c * t * t
end

---------------------------------------------------------------------
-- FLY
---------------------------------------------------------------------

local function fly(
	data,
	targetBalance,
	delayTime,
	onArrive
)
	task.spawn(
		function()
			task.wait(
				delayTime
			)

			local coin =
				data.coin

			local scale =
				data.scale

			if not coin.Parent then
				return
			end

			local start =
				Vector2.new(
					coin.AbsolutePosition.X
					+ coin.AbsoluteSize.X / 2,

					coin.AbsolutePosition.Y
					+ coin.AbsoluteSize.Y / 2
				)

			local target =
				walletCenter(
					targetBalance
				)

			local control =
				Vector2.new(
					start.X
					+ (
						target.X
						- start.X
					) * 0.46,

					math.min(
						start.Y,
						target.Y
					)
					- math.random(
						80,
						145
					)
				)

			local duration =
				0.52
				+ math.random()
				* 0.16

			local started =
				os.clock()

			local originalRotation =
				coin.Rotation

			while coin.Parent do
				local t =
					math.clamp(
						(
							os.clock()
							- started
						)
						/ duration,

						0,
						1
					)

				local eased =
					1
				- math.pow(
					1 - t,
					3
				)

				target =
					walletCenter(
						targetBalance
					)

				local point =
					bezier(
						start,
						control,
						target,
						eased
					)

				coin.Position =
					UDim2.fromOffset(
						point.X,
						point.Y
					)

				coin.Rotation =
					originalRotation
					+ eased
					* 380

				if t > 0.72 then
					scale.Scale =
						math.max(
							0.32,

							1
							- (
								(t - 0.72)
								/ 0.28
							)
							* 0.68
						)
				end

				if t >= 1 then
					break
				end

				RunService.RenderStepped:
					Wait()
			end

			if coin.Parent then
				popWallet()

				if onArrive then
					onArrive()
				end

				coin:Destroy()
			end
		end
	)
end

---------------------------------------------------------------------
-- MAIN PRESENTATION
---------------------------------------------------------------------

local function buildPresentation(
	amount
)
	local camera =
		workspace.CurrentCamera

	local viewport =
		camera
		and camera.ViewportSize
		or Vector2.new(
			1920,
			1080
		)

	local center =
		Vector2.new(
			viewport.X * 0.5,
			viewport.Y * 0.47
		)

	local root =
		make(
			"CanvasGroup",
			layer,
			{
				Name =
				"Presentation",

				AnchorPoint =
				Vector2.new(
					0.5,
					0.5
				),

				Position =
				UDim2.fromOffset(
					center.X,
					center.Y
				),

				Size =
				UDim2.fromOffset(
					430,
					210
				),

				BackgroundTransparency =
				1,

				GroupTransparency =
				1,

				ZIndex =
				640,
			}
		)

	local title =
		label(
			root,
			"НАГРАДА ЗА МАТЧ",

			UDim2.fromOffset(
				0,
				6
			),

			UDim2.new(
				1,
				0,
				0,
				26
			),

			FONT_BOLD,
			12,
			C.Muted,
			641
		)

	local value =
		label(
			root,
			"+" .. tostring(amount),

			UDim2.fromOffset(
				0,
				27
			),

			UDim2.new(
				1,
				0,
				0,
				67
			),

			FONT_HEAVY,
			54,
			C.Cream,
			641
		)

	local currency =
		label(
			root,
			"МОНЕТ",

			UDim2.fromOffset(
				0,
				88
			),

			UDim2.new(
				1,
				0,
				0,
				27
			),

			FONT_BOLD,
			15,
			C.Gold,
			641
		)

	local line =
		make(
			"Frame",
			root,
			{
				AnchorPoint =
				Vector2.new(
					0.5,
					0
				),

				Position =
				UDim2.new(
					0.5,
					0,
					0,
					122
				),

				Size =
				UDim2.fromOffset(
					0,
					2
				),

				BackgroundColor3 =
				C.Gold,

				BorderSizePixel =
				0,

				ZIndex =
				641,
			}
		)

	round(
		line,
		2
	)

	local rootScale =
		make(
			"UIScale",
			root,
			{
				Scale =
				0.94,
			}
		)

	tween(
		root,
		0.18,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out,
		{
			GroupTransparency =
				0,
		}
	)

	tween(
		rootScale,
		0.25,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out,
		{
			Scale = 1,
		}
	)

	tween(
		line,
		0.32,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out,
		{
			Size =
				UDim2.fromOffset(
					82,
					2
				),
		}
	)

	return root,
		rootScale,
		center
end

---------------------------------------------------------------------
-- QUEUE
---------------------------------------------------------------------

local queue = {}
local playing = false

local function playReward(
	amount,
	previousBalance,
	newBalance
)
	amount =
		math.max(
			1,
			math.floor(
				tonumber(amount)
				or 0
			)
		)

	previousBalance =
		math.max(
			0,
			math.floor(
				tonumber(
					previousBalance
				)
				or (
					newBalance
					- amount
				)
			)
		)

	newBalance =
		math.max(
			0,
			math.floor(
				tonumber(
					newBalance
				)
				or (
					previousBalance
					+ amount
				)
			)
		)

	ensureWallet(
		previousBalance
	)

	beginCounter(
		previousBalance
	)

	local presentation,
		presentationScale,
		center =
		buildPresentation(
			amount
		)

	-----------------------------------------------------------------
	-- FAN OF COINS
	-----------------------------------------------------------------

	local count =
		math.clamp(
			7
			+ math.floor(
				amount / 60
			),

			7,
			12
		)

	local coins = {}

	for i = 1, count do
		local coin, scale =
			createCoin(
				Vector2.new(
					center.X,
					center.Y + 78
				),

				math.random(
					25,
					30
				)
			)

		local normalized =
			count == 1
			and 0
			or (
				(i - 1)
				/ (count - 1)
			)

		local x =
			(normalized - 0.5)
			* 190

		local curve =
			math.abs(
				normalized - 0.5
			)

		local y =
			82
			+ curve * 30

		local target =
			Vector2.new(
				center.X + x,
				center.Y + y
			)

		tween(
			coin,
			0.28
				+ i * 0.012,

			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out,

			{
				Position =
					UDim2.fromOffset(
						target.X,
						target.Y
					),

				Rotation =
					-24
					+ normalized
					* 48,
			}
		)

		coins[i] = {
			coin = coin,
			scale = scale,
		}
	end

	-----------------------------------------------------------------
	-- HOLD
	-----------------------------------------------------------------

	task.wait(
		0.68
	)

	-----------------------------------------------------------------
	-- TEXT EXITS UP
	-----------------------------------------------------------------

	tween(
		presentation,
		0.25,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.In,
		{
			GroupTransparency =
				1,

			Position =
				presentation.Position
			- UDim2.fromOffset(
				0,
				18
			),
		}
	)

	tween(
		presentationScale,
		0.25,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.In,
		{
			Scale =
				0.97,
		}
	)

	task.delay(
		0.27,
		function()
			if presentation.Parent then
				presentation:Destroy()
			end
		end
	)

	-----------------------------------------------------------------
	-- PAYOUT
	-----------------------------------------------------------------

	local arrived =
		0

	for index, data in ipairs(
		coins
		) do
		fly(
			data,
			newBalance,
			(index - 1)
				* 0.055,

			function()
				arrived += 1

				local progress =
					arrived
					/ count

				local shown =
					previousBalance
					+ math.floor(
						amount
						* progress
						+ 0.5
					)

				setCounter(
					shown
				)

				if arrived >= count then
					setCounter(
						newBalance
					)

					task.delay(
						0.18,
						function()
							popWallet()

							task.delay(
								0.12,
								function()
									endCounter(
										newBalance
									)
								end
							)
						end
					)
				end
			end
		)
	end

	task.wait(
		1.55
	)
end

local function processQueue()
	if playing then
		return
	end

	playing =
		true

	task.spawn(
		function()
			while #queue > 0 do
				local entry =
					table.remove(
						queue,
						1
					)

				playReward(
					entry.amount,
					entry.previousBalance,
					entry.newBalance
				)
			end

			playing =
				false
		end
	)
end

local function enqueue(
	amount,
	previousBalance,
	newBalance
)
	if tonumber(amount)
		and tonumber(amount) > 0
	then
		table.insert(
			queue,
			{
				amount =
					amount,

				previousBalance =
					previousBalance,

				newBalance =
					newBalance,
			}
		)

		processQueue()
	end
end

---------------------------------------------------------------------
-- MATCH REAL REWARD
---------------------------------------------------------------------

task.spawn(
	function()
		local remotes =
			ReplicatedStorage:
			WaitForChild(
				"MatchRemotes",
				8
			)

		if not remotes then
			return
		end

		local reward =
			remotes:
			WaitForChild(
				"Reward",
				8
			)

		if not reward
			or not reward:IsA(
				"RemoteEvent"
			)
		then
			return
		end

		reward.OnClientEvent:
			Connect(
				function(data)
					if type(data)
						~= "table"
					then
						return
					end

					enqueue(
						data.amount,
						data.previousBalance,
						data.newBalance
					)
				end
			)
	end
)

---------------------------------------------------------------------
-- LOBBY / DAILY REAL REWARD
---------------------------------------------------------------------

task.spawn(
	function()
		local shared =
			ReplicatedStorage:
			FindFirstChild(
				"SpyShared"
			)

		if not shared then
			return
		end

		local profileEvent =
			shared:
			FindFirstChild(
				"Profile"
			)

		if not profileEvent
			or not profileEvent:IsA(
				"RemoteEvent"
			)
		then
			return
		end

		local previousKnown = nil
        local lastRevision = -1
        local seenRequests = {}
        local requestOrder = {}

		profileEvent.OnClientEvent:
			Connect(
				function(
					profile,
					receipt,
                    requestId
				)
					if type(profile)
						~= "table"
					then
						return
					end

					local balance =
					tonumber(
						profile.coins
					)

					if not balance then
						return
					end

                    local revision=tonumber(profile.revision) or 0
                    if revision<lastRevision then return end
                    lastRevision=revision
                    if requestId and seenRequests[requestId] then return end
                    if requestId then
                        seenRequests[requestId]=true
                        table.insert(requestOrder,requestId)
                        if #requestOrder>128 then seenRequests[table.remove(requestOrder,1)]=nil end
                    end
                    if previousKnown==nil then
                        previousKnown=balance
                        ensureWallet(balance)
                    end

					local amount =
					type(receipt)
					== "table"
					and receipt.ok
					and tonumber(
						(receipt.code == "opened" and receipt.refund or receipt.coins)
					)
					or nil

					if amount
						and amount > 0
					then
						enqueue(
							amount,
							balance - amount,
							balance
						)

					elseif balance
						> previousKnown
					then
						enqueue(
							balance
							- previousKnown,

							previousKnown,
							balance
						)
					end

					previousKnown =
					balance
				end
			)
	end
)

print(
	"[CoinRewardFX V3] Ready."
)