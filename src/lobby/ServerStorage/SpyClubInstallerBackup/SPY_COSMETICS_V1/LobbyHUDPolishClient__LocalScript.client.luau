-- StarterPlayer > StarterPlayerScripts > LobbyHUDPolishClient
-- SPY CLUB / LOBBY HUD POLISH V5
-- FULL REPLACEMENT
--
-- • Daily всегда остаётся слева
-- • нижний статус меняется Lobby <-> Party
-- • справа ничего не создаётся
-- • код приватного стола не показывается
-- • настоящий DailyDock остаётся рабочим
-- • TableReservationClient не изменяется

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- COLORS
---------------------------------------------------------------------

local C = {
	Panel = Color3.fromRGB(21, 17, 17),
	PanelRaised = Color3.fromRGB(29, 23, 22),

	Cream = Color3.fromRGB(244, 218, 184),
	CreamSoft = Color3.fromRGB(194, 158, 119),

	Gold = Color3.fromRGB(181, 133, 78),

	Text = Color3.fromRGB(241, 226, 205),
	Muted = Color3.fromRGB(145, 126, 106),

	Shadow = Color3.fromRGB(0, 0, 0),
}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function create(className, parent, properties)
	local object = Instance.new(className)

	for property, value in pairs(properties or {}) do
		object[property] = value
	end

	object.Parent = parent

	return object
end

local function getCorner(parent, radius)
	local corner =
		parent:FindFirstChild(
			"SpyPolishCorner"
		)

	if not corner then
		corner = Instance.new("UICorner")
		corner.Name = "SpyPolishCorner"
		corner.Parent = parent
	end

	corner.CornerRadius =
		UDim.new(
			0,
			radius
		)

	return corner
end

local function getStroke(
	parent,
	color,
	transparency,
	thickness
)
	local stroke =
		parent:FindFirstChild(
			"SpyPolishStroke"
		)

	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "SpyPolishStroke"
		stroke.Parent = parent
	end

	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness

	return stroke
end

local function textLabel(
	parent,
	name,
	text,
	position,
	size,
	font,
	textSize,
	color,
	zIndex
)
	local label = create(
		"TextLabel",
		parent,
		{
			Name = name,

			BackgroundTransparency = 1,

			Position = position,
			Size = size,

			Text = text,

			Font =
				font
				or Enum.Font.GothamMedium,

			TextSize =
				textSize
				or 12,

			TextColor3 =
				color
				or C.Text,

			TextXAlignment =
				Enum.TextXAlignment.Left,

			TextYAlignment =
				Enum.TextYAlignment.Center,

			BorderSizePixel = 0,

			ZIndex =
				zIndex
				or 10,
		}
	)

	return label
end

---------------------------------------------------------------------
-- CLEAN OLD VERSION
---------------------------------------------------------------------

local previous =
	playerGui:FindFirstChild(
		"SpyLobbyPolishUI"
	)

if previous then
	-----------------------------------------------------------------
	-- DailyDock настоящий.
	-- Спасаем его перед удалением старого HUD.
	-----------------------------------------------------------------

	local savedDaily =
		previous:FindFirstChild(
			"DailyDock",
			true
		)

	if savedDaily
		and savedDaily:IsA("GuiButton")
	then
		savedDaily.Parent =
			playerGui
	end

	previous:Destroy()
end

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local gui = create(
	"ScreenGui",
	playerGui,
	{
		Name = "SpyLobbyPolishUI",

		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		DisplayOrder = 24,

		ZIndexBehavior =
			Enum.ZIndexBehavior.Sibling,
	}
)

---------------------------------------------------------------------
-- LEFT RAIL
---------------------------------------------------------------------

local rail = create(
	"Frame",
	gui,
	{
		Name = "LeftRail",

		AnchorPoint =
			Vector2.new(
				0,
				0.5
			),

		Position =
			UDim2.new(
				0,
				28,
				0.5,
				0
			),

		Size =
			UDim2.fromOffset(
				248,
				128
			),

		BackgroundTransparency = 1,

		ZIndex = 40,
	}
)

---------------------------------------------------------------------
-- DAILY SHADOW
---------------------------------------------------------------------

local dailyShadow = create(
	"Frame",
	rail,
	{
		Name = "DailyShadow",

		Position =
			UDim2.fromOffset(
				4,
				5
			),

		Size =
			UDim2.fromOffset(
				244,
				66
			),

		BackgroundColor3 =
			C.Shadow,

		BackgroundTransparency =
			0.52,

		BorderSizePixel = 0,

		ZIndex = 40,
	}
)

getCorner(
	dailyShadow,
	9
)

---------------------------------------------------------------------
-- DAILY HOST
---------------------------------------------------------------------

local dailyHost = create(
	"Frame",
	rail,
	{
		Name = "DailyHost",

		Position =
			UDim2.fromOffset(
				0,
				0
			),

		Size =
			UDim2.fromOffset(
				244,
				66
			),

		BackgroundTransparency = 1,

		ZIndex = 41,
	}
)

---------------------------------------------------------------------
-- STATUS PANEL
---------------------------------------------------------------------

local status = create(
	"Frame",
	rail,
	{
		Name = "Status",

		Position =
			UDim2.fromOffset(
				0,
				78
			),

		Size =
			UDim2.fromOffset(
				244,
				50
			),

		BackgroundColor3 =
			C.Panel,

		BackgroundTransparency =
			0.05,

		BorderSizePixel = 0,

		ZIndex = 42,
	}
)

getCorner(
	status,
	8
)

local statusStroke =
	getStroke(
		status,
		C.CreamSoft,
		0.55,
		1
	)

---------------------------------------------------------------------
-- STATUS ACCENT
---------------------------------------------------------------------

local statusAccent = create(
	"Frame",
	status,
	{
		Name = "Accent",

		Position =
			UDim2.fromOffset(
				0,
				11
			),

		Size =
			UDim2.fromOffset(
				2,
				28
			),

		BackgroundColor3 =
			C.Gold,

		BorderSizePixel = 0,

		ZIndex = 44,
	}
)

getCorner(
	statusAccent,
	2
)

---------------------------------------------------------------------
-- STATUS TITLE
---------------------------------------------------------------------

local statusTitle = textLabel(
	status,
	"Title",
	"ЛОББИ",
	UDim2.fromOffset(
		14,
		5
	),
	UDim2.new(
		1,
		-82,
		0,
		22
	),
	Enum.Font.GothamBold,
	11,
	C.Cream,
	45
)

---------------------------------------------------------------------
-- STATUS SUBTITLE
---------------------------------------------------------------------

local statusSubtitle = textLabel(
	status,
	"Subtitle",
	"ИГРОКОВ В СЕРВЕРЕ",
	UDim2.fromOffset(
		14,
		26
	),
	UDim2.new(
		1,
		-76,
		0,
		17
	),
	Enum.Font.GothamMedium,
	8,
	C.Muted,
	45
)

statusSubtitle.TextTruncate =
	Enum.TextTruncate.AtEnd

---------------------------------------------------------------------
-- STATUS COUNT
---------------------------------------------------------------------

local statusCount = textLabel(
	status,
	"Count",
	"1",
	UDim2.new(
		1,
		-66,
		0,
		0
	),
	UDim2.fromOffset(
		50,
		50
	),
	Enum.Font.GothamBold,
	13,
	C.Cream,
	45
)

statusCount.TextXAlignment =
	Enum.TextXAlignment.Right

---------------------------------------------------------------------
-- STATUS SCALE FOR TRANSITION
---------------------------------------------------------------------

local statusScale = create(
	"UIScale",
	status,
	{
		Scale = 1,
	}
)

---------------------------------------------------------------------
-- PARTY
---------------------------------------------------------------------

local currentParty = nil

---------------------------------------------------------------------
-- SERVER COUNT
---------------------------------------------------------------------

local function serverPlayerCount()
	return #Players:GetPlayers()
end

---------------------------------------------------------------------
-- STATUS TRANSITION
---------------------------------------------------------------------

local statusAnimationId = 0

local function animateStatusChange()
	statusAnimationId += 1

	local thisAnimation =
		statusAnimationId

	TweenService:
		Create(
			statusScale,
			TweenInfo.new(
				0.08,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{
				Scale = 0.975,
			}
		):
		Play()

	TweenService:
		Create(
			statusStroke,
			TweenInfo.new(
				0.08
			),
			{
				Transparency = 0.18,
				Color = C.Gold,
			}
		):
		Play()

	task.delay(
		0.08,
		function()
			if thisAnimation
				~= statusAnimationId
			then
				return
			end

			TweenService:
				Create(
					statusScale,
					TweenInfo.new(
						0.22,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{
						Scale = 1,
					}
				):
				Play()

			TweenService:
				Create(
					statusStroke,
					TweenInfo.new(
						0.22
					),
					{
						Transparency = 0.55,
						Color = C.CreamSoft,
					}
				):
				Play()
		end
	)
end

---------------------------------------------------------------------
-- UPDATE STATUS
---------------------------------------------------------------------

local function refreshStatus(animated)
	-----------------------------------------------------------------
	-- NOT IN PARTY
	-----------------------------------------------------------------

	if not currentParty then
		statusTitle.Text =
			"ЛОББИ"

		statusSubtitle.Text =
			"ИГРОКОВ В СЕРВЕРЕ"

		statusCount.Text =
			tostring(
				serverPlayerCount()
			)

		statusAccent.BackgroundColor3 =
			C.Gold

		if animated then
			animateStatusChange()
		end

		return
	end

	-----------------------------------------------------------------
	-- PARTY
	-----------------------------------------------------------------

	local members =
		currentParty.members
		or {}

	local capacity =
		math.clamp(
			tonumber(
				currentParty.capacity
			)
			or 4,
			3,
			4
		)

	statusTitle.Text =
		"СТОЛ"

	statusCount.Text =
		tostring(
			#members
		)
		.. "/"
		.. tostring(
			capacity
		)

	-----------------------------------------------------------------
	-- PRIVATE / PUBLIC
	-----------------------------------------------------------------

	local visibility =
		currentParty.visibility

	local privacyText

	if visibility == "public" then
		privacyText =
			"ОТКРЫТЫЙ"
	else
		privacyText =
			"ПО ПРИГЛАШЕНИЮ"
	end

	-----------------------------------------------------------------
	-- PARTY NAME
	-----------------------------------------------------------------

	local partyName =
		tostring(
			currentParty.name
			or ""
		)

	if partyName ~= "" then
		statusSubtitle.Text =
			privacyText
			.. "  ·  "
			.. string.upper(
				partyName
			)
	else
		statusSubtitle.Text =
			privacyText
	end

	if animated then
		animateStatusChange()
	end
end

---------------------------------------------------------------------
-- PLAYER COUNT
---------------------------------------------------------------------

Players.PlayerAdded:Connect(
	function()
		if not currentParty then
			refreshStatus(false)
		end
	end
)

Players.PlayerRemoving:Connect(
	function()
		task.defer(
			function()
				if not currentParty then
					refreshStatus(false)
				end
			end
		)
	end
)

---------------------------------------------------------------------
-- FIND REAL DAILY BUTTON
---------------------------------------------------------------------

local dailyButton = nil
local dailyScale = nil
local dailyBadgeConnection = nil

local function findDaily()
	for _, object in ipairs(
		playerGui:GetDescendants()
		) do
		if object:IsA("GuiButton")
			and object.Name
			== "DailyDock"
		then
			return object
		end
	end

	return nil
end

---------------------------------------------------------------------
-- DAILY ACTION TEXT
---------------------------------------------------------------------

local function updateDailyAction()
	if not dailyButton then
		return
	end

	local action =
		dailyButton:
		FindFirstChild(
			"SpyDailyAction"
		)

	if not action then
		return
	end

	local badge =
		dailyButton:
		FindFirstChild(
			"NotificationBadge"
		)

	if badge
		and badge:IsA("GuiObject")
		and badge.Visible
	then
		action.Text =
			"ГОТОВО"

		action.TextColor3 =
			C.Gold
	else
		action.Text =
			"ОТКРЫТЬ"

		action.TextColor3 =
			C.CreamSoft
	end
end

---------------------------------------------------------------------
-- STYLE DAILY
---------------------------------------------------------------------

local function styleDaily(button)
	if dailyButton == button then
		return
	end

	dailyButton = button

	button.Parent =
		dailyHost

	button.AnchorPoint =
		Vector2.new(
			0,
			0
		)

	button.Position =
		UDim2.fromOffset(
			0,
			0
		)

	button.Size =
		UDim2.fromOffset(
			244,
			66
		)

	button.BackgroundColor3 =
		C.Panel

	button.BackgroundTransparency =
		0.02

	button.BorderSizePixel = 0
	button.AutoButtonColor = false

	button.Visible = true

	button.ZIndex = 42

	getCorner(
		button,
		9
	)

	getStroke(
		button,
		C.Cream,
		0.27,
		1.05
	)

	-----------------------------------------------------------------
	-- HIDE ORIGINAL ACTIVE MARK
	-----------------------------------------------------------------

	local activeMark =
		button:FindFirstChild(
			"ActiveMark"
		)

	if activeMark
		and activeMark:IsA("GuiObject")
	then
		activeMark.Visible = false
	end

	-----------------------------------------------------------------
	-- HIDE ORIGINAL CAPTION
	-----------------------------------------------------------------

	local caption =
		button:FindFirstChild(
			"DockCaption"
		)

	if caption
		and caption:IsA("GuiObject")
	then
		caption.Visible = false
	end

	-----------------------------------------------------------------
	-- ICON
	-----------------------------------------------------------------

	local icon =
		button:FindFirstChild(
			"ObjectIcon"
		)

	if icon
		and icon:IsA("GuiObject")
	then
		icon.AnchorPoint =
			Vector2.new(
				0,
				0.5
			)

		icon.Position =
			UDim2.new(
				0,
				7,
				0.5,
				0
			)

		icon.Size =
			UDim2.fromOffset(
				53,
				53
			)

		icon.ZIndex = 44
	end

	-----------------------------------------------------------------
	-- DIVIDER
	-----------------------------------------------------------------

	local divider =
		button:FindFirstChild(
			"SpyDailyDivider"
		)

	if not divider then
		divider = Instance.new("Frame")
		divider.Name = "SpyDailyDivider"
		divider.Parent = button
	end

	divider.Position =
		UDim2.fromOffset(
			68,
			14
		)

	divider.Size =
		UDim2.fromOffset(
			1,
			38
		)

	divider.BackgroundColor3 =
		C.CreamSoft

	divider.BackgroundTransparency =
		0.67

	divider.BorderSizePixel = 0

	divider.ZIndex = 44

	-----------------------------------------------------------------
	-- TITLE
	-----------------------------------------------------------------

	local title =
		button:FindFirstChild(
			"SpyDailyTitle"
		)

	if not title then
		title =
			textLabel(
				button,
				"SpyDailyTitle",
				"ЕЖЕДНЕВНАЯ НАГРАДА",
				UDim2.fromOffset(
					82,
					8
				),
				UDim2.new(
					1,
					-110,
					0,
					24
				),
				Enum.Font.GothamBold,
				11,
				C.Cream,
				45
			)
	end

	-----------------------------------------------------------------
	-- SUBTITLE
	-----------------------------------------------------------------

	local subtitle =
		button:FindFirstChild(
			"SpyDailySubtitle"
		)

	if not subtitle then
		subtitle =
			textLabel(
				button,
				"SpyDailySubtitle",
				"БОНУС ЗА ВХОД",
				UDim2.fromOffset(
					82,
					31
				),
				UDim2.new(
					1,
					-110,
					0,
					18
				),
				Enum.Font.GothamMedium,
				8,
				C.Muted,
				45
			)
	end

	-----------------------------------------------------------------
	-- ACTION
	-----------------------------------------------------------------

	local action =
		button:FindFirstChild(
			"SpyDailyAction"
		)

	if not action then
		action =
			textLabel(
				button,
				"SpyDailyAction",
				"ОТКРЫТЬ",
				UDim2.new(
					1,
					-67,
					0,
					0
				),
				UDim2.fromOffset(
					54,
					66
				),
				Enum.Font.GothamBold,
				7,
				C.CreamSoft,
				45
			)

		action.TextXAlignment =
			Enum.TextXAlignment.Right
	end

	-----------------------------------------------------------------
	-- BADGE
	-----------------------------------------------------------------

	local badge =
		button:FindFirstChild(
			"NotificationBadge"
		)

	if badge
		and badge:IsA("GuiObject")
	then
		badge.Position =
			UDim2.new(
				1,
				-13,
				0,
				13
			)

		badge.Size =
			UDim2.fromOffset(
				7,
				7
			)

		badge.ZIndex = 50

		if dailyBadgeConnection then
			dailyBadgeConnection:
				Disconnect()
		end

		dailyBadgeConnection =
			badge:
			GetPropertyChangedSignal(
				"Visible"
			):
			Connect(
				updateDailyAction
			)
	end

	-----------------------------------------------------------------
	-- PRESS SCALE
	-----------------------------------------------------------------

	dailyScale =
		button:FindFirstChild(
			"SpyDailyScale"
		)

	if not dailyScale then
		dailyScale =
			Instance.new("UIScale")

		dailyScale.Name =
			"SpyDailyScale"

		dailyScale.Scale = 1

		dailyScale.Parent =
			button
	end

	button.MouseButton1Down:
		Connect(
			function()
				TweenService:
				Create(
					dailyScale,
					TweenInfo.new(
						0.06,
						Enum.EasingStyle.Quint,
						Enum.EasingDirection.Out
					),
					{
						Scale = 0.975,
					}
				):
				Play()
			end
		)

	button.MouseButton1Up:
		Connect(
			function()
				TweenService:
				Create(
					dailyScale,
					TweenInfo.new(
						0.16,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{
						Scale = 1,
					}
				):
				Play()
			end
		)

	updateDailyAction()
end

---------------------------------------------------------------------
-- DAILY BIND
---------------------------------------------------------------------

local function tryBindDaily()
	if dailyButton
		and dailyButton.Parent
	then
		return
	end

	local button =
		findDaily()

	if button then
		styleDaily(
			button
		)
	end
end

task.defer(tryBindDaily)
task.delay(0.4, tryBindDaily)
task.delay(1, tryBindDaily)
task.delay(2, tryBindDaily)
task.delay(4, tryBindDaily)

playerGui.DescendantAdded:
	Connect(
		function(object)
			if object:IsA("GuiButton")
				and object.Name
				== "DailyDock"
			then
				task.defer(
					function()
						styleDaily(
							object
						)
					end
				)
			end
		end
	)

---------------------------------------------------------------------
-- PARTY REMOTES
---------------------------------------------------------------------

task.spawn(
	function()
		local folder =
			ReplicatedStorage:
			WaitForChild(
				"SpyPartyRemotes",
				20
			)

		if not folder then
			return
		end

		local request =
			folder:FindFirstChild(
				"Request"
			)

		local update =
			folder:FindFirstChild(
				"Update"
			)

		-----------------------------------------------------------------
		-- INITIAL PARTY
		-----------------------------------------------------------------

		if request
			and request:IsA(
				"RemoteFunction"
			)
		then
			local ok, response =
				pcall(
					function()
						return
						request:
						InvokeServer(
							"Get"
						)
					end
				)

			if ok
				and type(response)
				== "table"
			then
				currentParty =
					response.party

				refreshStatus(false)
			end
		end

		-----------------------------------------------------------------
		-- LIVE PARTY STATE
		-----------------------------------------------------------------

		if update
			and update:IsA(
				"RemoteEvent"
			)
		then
			update.OnClientEvent:
				Connect(
					function(party)
						currentParty =
						party

						refreshStatus(true)
					end
				)
		end
	end
)

---------------------------------------------------------------------
-- RESPONSIVE
---------------------------------------------------------------------

local camera =
	workspace.CurrentCamera

local function updateResponsive()
	if not camera then
		return
	end

	local viewport =
		camera.ViewportSize

	-----------------------------------------------------------------
	-- NARROW
	-----------------------------------------------------------------

	if viewport.X < 1100 then
		rail.Position =
			UDim2.new(
				0,
				18,
				0.5,
				0
			)

		rail.Size =
			UDim2.fromOffset(
				220,
				120
			)

		dailyHost.Size =
			UDim2.fromOffset(
				216,
				62
			)

		dailyShadow.Size =
			UDim2.fromOffset(
				216,
				62
			)

		status.Size =
			UDim2.fromOffset(
				216,
				46
			)

		status.Position =
			UDim2.fromOffset(
				0,
				73
			)

		if dailyButton then
			dailyButton.Size =
				UDim2.fromOffset(
					216,
					62
				)
		end

		-----------------------------------------------------------------
		-- NORMAL
		-----------------------------------------------------------------

	else
		rail.Position =
			UDim2.new(
				0,
				28,
				0.5,
				0
			)

		rail.Size =
			UDim2.fromOffset(
				248,
				128
			)

		dailyHost.Size =
			UDim2.fromOffset(
				244,
				66
			)

		dailyShadow.Size =
			UDim2.fromOffset(
				244,
				66
			)

		status.Size =
			UDim2.fromOffset(
				244,
				50
			)

		status.Position =
			UDim2.fromOffset(
				0,
				78
			)

		if dailyButton then
			dailyButton.Size =
				UDim2.fromOffset(
					244,
					66
				)
		end
	end
end

updateResponsive()

if camera then
	camera:
		GetPropertyChangedSignal(
			"ViewportSize"
		):
		Connect(
			updateResponsive
		)
end

---------------------------------------------------------------------
-- INITIAL STATUS
---------------------------------------------------------------------

refreshStatus(false)

---------------------------------------------------------------------
-- ENTRANCE
---------------------------------------------------------------------

local finalPosition =
	rail.Position

rail.Position =
	finalPosition
- UDim2.fromOffset(
	14,
	0
)

TweenService:
	Create(
		rail,
		TweenInfo.new(
			0.35,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),
		{
			Position =
			finalPosition,
		}
	):
	Play()