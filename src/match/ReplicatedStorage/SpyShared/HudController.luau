--[[
	SPYCLUB — HUD CONTROLLER
	Полностью заменить:
	ReplicatedStorage > SpyShared > HudController

	FIX:
	- Три нижние иконки теперь центрируются ПО ВИДИМОЙ ГРАФИКЕ,
	  а не просто по размеру их старого контейнера.
	- Корзина / инвентарь / настройки визуально сидят ровно
	  в центре своих квадратов.
	- Размеры и стиль HUD сохранены.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local HudController = {}
HudController.__index = HudController

---------------------------------------------------------------------
-- ICONS
---------------------------------------------------------------------

local ICONS = {
	Shop = "",
	Inventory = "",
	Settings = "",
}

---------------------------------------------------------------------
-- STYLE
---------------------------------------------------------------------

local STYLE = {
	Main = Color3.fromRGB(221,193,151),
	MainHover = Color3.fromRGB(235,210,174),
	MainPressed = Color3.fromRGB(201,174,133),
	MainText = Color3.fromRGB(26,28,32),

	Dock = Color3.fromRGB(25,27,31),
	DockStroke = Color3.fromRGB(87,89,93),

	Button = Color3.fromRGB(34,36,40),
	ButtonHover = Color3.fromRGB(57,59,63),
	ButtonPressed = Color3.fromRGB(25,27,31),
	ButtonActive = Color3.fromRGB(46,48,52),

	ButtonStroke = Color3.fromRGB(87,89,93),

	Icon = Color3.fromRGB(244,240,231),
	IconHover = Color3.fromRGB(244,240,231),

	MainCorner = 14,
	DockCorner = 18,
	ButtonCorner = 12,
}

---------------------------------------------------------------------
-- TWEENS
---------------------------------------------------------------------

local HOVER = TweenInfo.new(
	0.18,
	Enum.EasingStyle.Quint,
	Enum.EasingDirection.Out
)

local PRESS = TweenInfo.new(
	0.15,
	Enum.EasingStyle.Exponential,
	Enum.EasingDirection.Out
)

local RELEASE = TweenInfo.new(
	0.22,
	Enum.EasingStyle.Quint,
	Enum.EasingDirection.Out
)

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function tween(object, info, goal)
	if not object or not object.Parent then
		return
	end

	local animation = TweenService:Create(object, info, goal)
	animation:Play()

	return animation
end

local function bind(self, signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

local function cleanup(parent)
	if not parent then
		return
	end

	for _, child in ipairs(parent:GetChildren()) do
		if string.sub(child.Name, 1, 6) == "HudGen"
			or string.sub(child.Name, 1, 3) == "Spy"
			or child.Name == "IconPlaceholder"
		then
			child:Destroy()
		end
	end
end

local function hide(object)
	if object and object:IsA("GuiObject") then
		object.Visible = false
	end
end

local function removeGradient(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end
end

local function setCorner(parent, radius)
	local object =
		parent:FindFirstChildOfClass("UICorner")

	if not object then
		object = Instance.new("UICorner")
		object.Parent = parent
	end

	object.CornerRadius =
		UDim.new(0, radius)

	return object
end

local function disableOldStrokes(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UIStroke") then
			child.Enabled = false
		end
	end
end

local function setStroke(parent, color, transparency)
	local object =
		parent:FindFirstChild("HudGenStroke")

	if not object then
		object = Instance.new("UIStroke")
		object.Name = "HudGenStroke"
		object.Parent = parent
	end

	object.Enabled = true
	object.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	object.Color = color
	object.Thickness = 1
	object.Transparency = transparency

	return object
end

local function getScale(parent)
	local object =
		parent:FindFirstChild("HudGenScale")

	if not object then
		object = Instance.new("UIScale")
		object.Name = "HudGenScale"
		object.Parent = parent
	end

	object.Scale = 1

	return object
end

---------------------------------------------------------------------
-- CHECK WHETHER GUI OBJECT ACTUALLY DRAWS SOMETHING
---------------------------------------------------------------------

local function isVisual(gui)
	if not gui:IsA("GuiObject") then
		return false
	end

	if not gui.Visible then
		return false
	end

	if gui:IsA("ImageLabel")
		or gui:IsA("ImageButton")
	then
		return gui.ImageTransparency < 1
	end

	if gui:IsA("TextLabel")
		or gui:IsA("TextButton")
	then
		return gui.TextTransparency < 1
			and gui.Text ~= ""
	end

	if gui:IsA("Frame") then
		return gui.BackgroundTransparency < 1
	end

	return false
end

---------------------------------------------------------------------
-- TRUE VISUAL CENTERING
---------------------------------------------------------------------

local function centerLegacyIcon(icon, button)
	if not icon
		or not icon.Parent
		or not button
		or not button.Parent
	then
		return
	end

	-- Сначала ставим сам контейнер строго в центр.
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)

	task.defer(function()
		if not icon.Parent or not button.Parent then
			return
		end

		RunService.Heartbeat:Wait()

		local minX = math.huge
		local minY = math.huge
		local maxX = -math.huge
		local maxY = -math.huge

		local foundVisual = false

		-------------------------------------------------------------
		-- ROOT ICON
		-------------------------------------------------------------

		if isVisual(icon) then
			foundVisual = true

			minX = math.min(
				minX,
				icon.AbsolutePosition.X
			)

			minY = math.min(
				minY,
				icon.AbsolutePosition.Y
			)

			maxX = math.max(
				maxX,
				icon.AbsolutePosition.X
					+ icon.AbsoluteSize.X
			)

			maxY = math.max(
				maxY,
				icon.AbsolutePosition.Y
					+ icon.AbsoluteSize.Y
			)
		end

		-------------------------------------------------------------
		-- CHILDREN
		-------------------------------------------------------------

		for _, descendant in ipairs(
			icon:GetDescendants()
			) do
			if isVisual(descendant) then
				foundVisual = true

				local position =
					descendant.AbsolutePosition

				local size =
					descendant.AbsoluteSize

				minX = math.min(
					minX,
					position.X
				)

				minY = math.min(
					minY,
					position.Y
				)

				maxX = math.max(
					maxX,
					position.X + size.X
				)

				maxY = math.max(
					maxY,
					position.Y + size.Y
				)
			end
		end

		if not foundVisual then
			return
		end

		-------------------------------------------------------------
		-- CENTER OF ACTUAL DRAWN ICON
		-------------------------------------------------------------

		local visualCenter =
			Vector2.new(
				(minX + maxX) / 2,
				(minY + maxY) / 2
			)

		local buttonCenter =
			Vector2.new(
				button.AbsolutePosition.X
				+ button.AbsoluteSize.X / 2,

				button.AbsolutePosition.Y
				+ button.AbsoluteSize.Y / 2
			)

		local delta =
			buttonCenter - visualCenter

		-------------------------------------------------------------
		-- MOVE ROOT BY EXACT PIXEL DIFFERENCE
		-------------------------------------------------------------

		icon.Position =
			UDim2.new(
				0.5,
				math.round(delta.X),
				0.5,
				math.round(delta.Y)
			)
	end)
end

---------------------------------------------------------------------
-- BUTTON MOTION
---------------------------------------------------------------------

local function setupMotion(
	self,
	button,
	scale,
	normalColor,
	hoverColor,
	pressedColor,
	normalGetter
)
	local hovering = false
	local pressed = false

	local function getNormal()
		if normalGetter then
			return normalGetter()
		end

		return normalColor
	end

	bind(
		self,
		button.MouseEnter,
		function()
			hovering = true

			if pressed then
				return
			end

			tween(
				button,
				HOVER,
				{
					BackgroundColor3 =
						hoverColor,
				}
			)

			tween(
				scale,
				HOVER,
				{
					Scale = 1.018,
				}
			)
		end
	)

	bind(
		self,
		button.MouseLeave,
		function()
			hovering = false

			if pressed then
				return
			end

			tween(
				button,
				HOVER,
				{
					BackgroundColor3 =
						getNormal(),
				}
			)

			tween(
				scale,
				RELEASE,
				{
					Scale = 1,
				}
			)
		end
	)

	bind(
		self,
		button.MouseButton1Down,
		function()
			pressed = true

			tween(
				button,
				PRESS,
				{
					BackgroundColor3 =
						pressedColor,
				}
			)

			tween(
				scale,
				PRESS,
				{
					Scale = 0.95,
				}
			)
		end
	)

	bind(
		self,
		button.MouseButton1Up,
		function()
			pressed = false

			local targetScale =
				hovering and 1.018 or 1

			tween(
				button,
				RELEASE,
				{
					BackgroundColor3 =
						hovering
						and hoverColor
						or getNormal(),
				}
			)

			tween(
				scale,
				TweenInfo.new(
					0.11,
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.Out
				),
				{
					Scale =
						targetScale + 0.012,
				}
			)

			task.delay(
				0.08,
				function()
					if scale.Parent then
						tween(
							scale,
							RELEASE,
							{
								Scale =
									targetScale,
							}
						)
					end
				end
			)
		end
	)
end

---------------------------------------------------------------------
-- CONSTRUCTOR
---------------------------------------------------------------------

function HudController.new(gui, L)
	local self =
		setmetatable({}, HudController)

	self.Gui = gui
	self.L = L
	self.Connections = {}
	self.Active = nil
	self.Buttons = {}

	self.MainAction =
		gui:WaitForChild("MainAction")

	self.BottomDock =
		gui:WaitForChild("BottomDesk")

	local tooltip =
		gui:FindFirstChild("Tooltip")

	if tooltip then
		tooltip.Visible = false
	end

	self:_buildMain()
	self:_buildDock()

	self:resize()
	self:update(false)

	bind(
		self,
		gui:GetPropertyChangedSignal(
			"AbsoluteSize"
		),
		function()
			self:resize()
		end
	)

	return self
end

---------------------------------------------------------------------
-- MAIN
---------------------------------------------------------------------

function HudController:_buildMain()
	local main = self.MainAction

	cleanup(main)
	removeGradient(main)

	main.Visible = true
	main.AutoButtonColor = false

	main.BackgroundColor3 =
		STYLE.Main

	main.BackgroundTransparency = 0
	main.BorderSizePixel = 0

	main.Text = ""
	main.TextTransparency = 1

	hide(main:FindFirstChild("Icon"))
	hide(main:FindFirstChild("Caption"))
	hide(main:FindFirstChild("Subcaption"))

	disableOldStrokes(main)

	setCorner(
		main,
		STYLE.MainCorner
	)

	setStroke(
		main,
		Color3.fromRGB(255, 240, 218),
		0.75
	)

	local mainScale =
		getScale(main)

	local content =
		Instance.new("Frame")

	content.Name =
		"HudGenMainContent"

	content.AnchorPoint =
		Vector2.new(0.5, 0.5)

	content.Position =
		UDim2.fromScale(0.5, 0.5)

	content.Size =
		UDim2.fromOffset(248, 44)

	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0

	content.ZIndex =
		main.ZIndex + 2

	content.Parent = main

	local layout =
		Instance.new("UIListLayout")

	layout.FillDirection =
		Enum.FillDirection.Horizontal

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	layout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	layout.Padding =
		UDim.new(0, 10)

	layout.Parent =
		content

	-----------------------------------------------------------------
	-- PLAY
	-----------------------------------------------------------------

	local playHolder =
		Instance.new("Frame")

	playHolder.Name =
		"HudGenPlayHolder"

	playHolder.LayoutOrder = 1

	playHolder.Size =
		UDim2.fromOffset(38, 42)

	playHolder.BackgroundTransparency = 1
	playHolder.Parent = content

	local play =
		Instance.new("TextLabel")

	play.Name =
		"HudGenPlay"

	play.AnchorPoint =
		Vector2.new(0.5, 0.5)

	play.Position =
		UDim2.fromScale(0.5, 0.5)

	play.Size =
		UDim2.fromOffset(38, 42)

	play.BackgroundTransparency = 1

	play.Font =
		Enum.Font.BuilderSansMedium

	play.Text = "▶"

	play.TextColor3 =
		STYLE.MainText

	play.TextSize = 34

	play.TextXAlignment =
		Enum.TextXAlignment.Center

	play.TextYAlignment =
		Enum.TextYAlignment.Center

	play.Parent =
		playHolder

	local playStroke =
		Instance.new("UIStroke")

	playStroke.Thickness = 1.2
	playStroke.Color = STYLE.MainText
	playStroke.Transparency = 0.62
	playStroke.Parent = play

	-----------------------------------------------------------------
	-- TITLE
	-----------------------------------------------------------------

	local title =
		Instance.new("TextLabel")

	title.Name =
		"HudGenTitle"

	title.LayoutOrder = 2

	title.AutomaticSize =
		Enum.AutomaticSize.X

	title.Size =
		UDim2.fromOffset(0, 42)

	title.BackgroundTransparency = 1

	title.Font =
		Enum.Font.BuilderSansMedium

	title.Text =
		self.L("hudCreate")

	title.TextColor3 =
		STYLE.MainText

	title.TextSize = 22

	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.TextYAlignment =
		Enum.TextYAlignment.Center

	title.Parent =
		content

	self.MainContent = content
	self.MainIcon = play
	self.MainTitle = title
	self.MainScale = mainScale

	setupMotion(
		self,
		main,
		mainScale,
		STYLE.Main,
		STYLE.MainHover,
		STYLE.MainPressed
	)
end

---------------------------------------------------------------------
-- DOCK
---------------------------------------------------------------------

function HudController:_buildDock()
	local dock = self.BottomDock

	cleanup(dock)
	removeGradient(dock)

	for _, child in ipairs(dock:GetChildren()) do
		if child:IsA("UIListLayout")
			or child:IsA("UIGridLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end

	dock.Visible = true

	dock.BackgroundColor3 =
		STYLE.Dock

	dock.BackgroundTransparency =
		0.08

	dock.BorderSizePixel = 0

	disableOldStrokes(dock)

	setCorner(
		dock,
		STYLE.DockCorner
	)

	setStroke(
		dock,
		STYLE.DockStroke,
		0.42
	)

	for _, name in ipairs({
		"Daily",
		"HighStakes",
		"Guide",
		}) do
		local object =
			dock:FindFirstChild(name)

		if object then
			object.Visible = false
		end
	end

	local padding =
		Instance.new("UIPadding")

	padding.Name =
		"HudGenPadding"

	padding.Parent =
		dock

	local layout =
		Instance.new("UIListLayout")

	layout.Name =
		"HudGenLayout"

	layout.FillDirection =
		Enum.FillDirection.Horizontal

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	layout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	layout.Parent =
		dock

	self.DockPadding = padding
	self.DockLayout = layout

	local definitions = {
		{
			Name = "Shop",
			Order = 1,
			Image = ICONS.Shop,
		},
		{
			Name = "Inventory",
			Order = 2,
			Image = ICONS.Inventory,
		},
		{
			Name = "Settings",
			Order = 3,
			Image = ICONS.Settings,
		},
	}

	for _, definition in ipairs(
		definitions
		) do
		local button =
			dock:WaitForChild(
				definition.Name
			)

		cleanup(button)
		removeGradient(button)

		button.Visible = true
		button.LayoutOrder =
			definition.Order

		button.AutoButtonColor = false

		button.BackgroundColor3 =
			STYLE.Button

		button.BackgroundTransparency = 0
		button.BorderSizePixel = 0

		button.Text = ""
		button.TextTransparency = 1

		local oldIcon =
			button:FindFirstChild("Icon")

		local oldCaption =
			button:FindFirstChild("Caption")

		hide(oldCaption)

		disableOldStrokes(button)

		setCorner(
			button,
			STYLE.ButtonCorner
		)

		local buttonStroke =
			setStroke(
				button,
				STYLE.ButtonStroke,
				0.50
			)

		local pngIcon = nil

		-------------------------------------------------------------
		-- PNG
		-------------------------------------------------------------

		if definition.Image ~= "" then
			hide(oldIcon)

			pngIcon =
				Instance.new("ImageLabel")

			pngIcon.Name =
				"HudGenIcon"

			pngIcon.AnchorPoint =
				Vector2.new(0.5, 0.5)

			pngIcon.Position =
				UDim2.fromScale(0.5, 0.5)

			pngIcon.Size =
				UDim2.fromOffset(29, 29)

			pngIcon.BackgroundTransparency = 1

			pngIcon.Image =
				definition.Image

			pngIcon.ImageColor3 =
				STYLE.Icon

			pngIcon.ScaleType =
				Enum.ScaleType.Fit

			pngIcon.Parent =
				button

			-------------------------------------------------------------
			-- EXISTING ICON
			-------------------------------------------------------------

		elseif oldIcon
			and oldIcon:IsA("GuiObject")
		then
			oldIcon.Visible = true

			oldIcon.AnchorPoint =
				Vector2.new(0.5, 0.5)

			oldIcon.Position =
				UDim2.fromScale(0.5, 0.5)

			-- Одинаковый квадрат для всех трёх.
			oldIcon.Size =
				UDim2.fromOffset(36, 36)

			local iconScale =
				oldIcon:FindFirstChild(
					"IconScale"
				)

			if iconScale
				and iconScale:IsA("UIScale")
			then
				iconScale.Scale = 0.78
			end
		end

		local buttonScale =
			getScale(button)

		self.Buttons[
		definition.Name
		] = {
			Button = button,
			Scale = buttonScale,
			Stroke = buttonStroke,
			PngIcon = pngIcon,
			OldIcon = oldIcon,
			Image = definition.Image,
		}

		setupMotion(
			self,
			button,
			buttonScale,
			STYLE.Button,
			STYLE.ButtonHover,
			STYLE.ButtonPressed,

			function()
				if self.Active == definition.Name
					or self.Active
					== string.lower(
						definition.Name
					)
				then
					return
						STYLE.ButtonActive
				end

				return STYLE.Button
			end
		)

		-------------------------------------------------------------
		-- PRECISE CENTERING
		-------------------------------------------------------------

		if pngIcon then
			pngIcon.AnchorPoint =
				Vector2.new(0.5, 0.5)

			pngIcon.Position =
				UDim2.fromScale(0.5, 0.5)
		elseif oldIcon then
			centerLegacyIcon(
				oldIcon,
				button
			)
		end
	end
end

---------------------------------------------------------------------
-- ACTIVE
---------------------------------------------------------------------

function HudController:setActive(name)
	self.Active = name

	for buttonName, item in pairs(
		self.Buttons
		) do
		local active =
			name == buttonName
			or name
			== string.lower(buttonName)

		tween(
			item.Button,
			HOVER,
			{
				BackgroundColor3 =
					active
					and STYLE.ButtonActive
					or STYLE.Button,
			}
		)

		tween(
			item.Stroke,
			HOVER,
			{
				Transparency =
					active
					and 0.30
					or 0.50,
			}
		)
	end
end

---------------------------------------------------------------------
-- RESIZE
---------------------------------------------------------------------

function HudController:resize()
	local size =
		self.Gui.AbsoluteSize

	local compact =
		size.X < 900
		or size.Y < 600

	local buttonSize =
		compact and 54 or 60

	local dockGap =
		compact and 7 or 8

	local dockPadding =
		compact and 7 or 8

	local bottom =
		compact and 10 or 16

	local verticalGap =
		compact and 8 or 9

	local dockWidth =
		buttonSize * 3
		+ dockGap * 2
		+ dockPadding * 2

	local dockHeight =
		buttonSize
		+ dockPadding * 2

	self.BottomDock.AnchorPoint =
		Vector2.new(0.5, 1)

	self.BottomDock.Position =
		UDim2.new(
			0.5,
			0,
			1,
			-bottom
		)

	self.BottomDock.Size =
		UDim2.fromOffset(
			dockWidth,
			dockHeight
		)

	self.DockLayout.Padding =
		UDim.new(0, dockGap)

	self.DockPadding.PaddingLeft =
		UDim.new(0, dockPadding)

	self.DockPadding.PaddingRight =
		UDim.new(0, dockPadding)

	self.DockPadding.PaddingTop =
		UDim.new(0, dockPadding)

	self.DockPadding.PaddingBottom =
		UDim.new(0, dockPadding)

	-----------------------------------------------------------------
	-- THREE BUTTONS
	-----------------------------------------------------------------

	for _, item in pairs(
		self.Buttons
		) do
		item.Button.Size =
			UDim2.fromOffset(
				buttonSize,
				buttonSize
			)

		if item.PngIcon then
			local iconSize =
				compact and 27 or 29

			item.PngIcon.Size =
				UDim2.fromOffset(
					iconSize,
					iconSize
				)

			item.PngIcon.AnchorPoint =
				Vector2.new(0.5, 0.5)

			item.PngIcon.Position =
				UDim2.fromScale(0.5, 0.5)
		end

		if item.OldIcon
			and item.Image == ""
		then
			local legacySize =
				compact and 34 or 36

			item.OldIcon.Size =
				UDim2.fromOffset(
					legacySize,
					legacySize
				)

			item.OldIcon.AnchorPoint =
				Vector2.new(0.5, 0.5)

			item.OldIcon.Position =
				UDim2.fromScale(0.5, 0.5)

			centerLegacyIcon(
				item.OldIcon,
				item.Button
			)
		end
	end

	-----------------------------------------------------------------
	-- MAIN
	-----------------------------------------------------------------

	local mainWidth =
		compact and 320 or 370

	local mainHeight =
		compact and 60 or 66

	self.MainAction.AnchorPoint =
		Vector2.new(0.5, 1)

	self.MainAction.Position =
		UDim2.new(
			0.5,
			0,
			1,
			-(
				bottom
				+ dockHeight
				+ verticalGap
			)
		)

	self.MainAction.Size =
		UDim2.fromOffset(
			mainWidth,
			mainHeight
		)

	self.MainContent.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	self.MainContent.Size =
		UDim2.fromOffset(
			compact and 232 or 248,
			44
		)

	self.MainTitle.TextSize =
		compact and 20 or 22

	self.MainIcon.TextSize =
		compact and 31 or 34
end

---------------------------------------------------------------------
-- UPDATE
---------------------------------------------------------------------

function HudController:update(inRound)
	local visible =
		not inRound

	self.MainAction.Visible =
		visible

	self.BottomDock.Visible =
		visible

	if self.MainTitle then
		self.MainTitle.Text =
			self.L("hudCreate")
	end
end

---------------------------------------------------------------------
-- DESTROY
---------------------------------------------------------------------

function HudController:Destroy()
	for _, connection in ipairs(
		self.Connections
		) do
		if connection.Connected then
			connection:Disconnect()
		end
	end

	table.clear(
		self.Connections
	)
end

return HudController
