-- ReplicatedStorage > SpyShared > OnboardingUI
-- ПОЛНАЯ ЗАМЕНА
--
-- Новый onboarding:
-- • никаких обязательных квестов;
-- • никаких подсветок Винсента;
-- • никаких "сядь за стол";
-- • только аккуратная книга "РУКОВОДСТВО";
-- • нажал -> открывается GuideUI;
-- • после первой сыгранной партии она сама больше не появляется.

local TweenService = game:GetService("TweenService")

local GuideUI = require(script.Parent.GuideUI)

local OnboardingUI = {}

---------------------------------------------------------------------
-- STYLE
---------------------------------------------------------------------

local C = {
	Cover = Color3.fromRGB(50, 38, 42),
	CoverHover = Color3.fromRGB(61, 47, 51),
	CoverPressed = Color3.fromRGB(42, 32, 36),

	Page = Color3.fromRGB(221, 207, 188),

	Brass = Color3.fromRGB(194, 158, 101),
	Border = Color3.fromRGB(111, 86, 76),

	Text = Color3.fromRGB(239, 231, 221),
}

local FONT = {
	Strong = Enum.Font.BuilderSans,
}

local T = {
	Hover = TweenInfo.new(
		0.17,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Press = TweenInfo.new(
		0.09,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	),

	Show = TweenInfo.new(
		0.24,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Hide = TweenInfo.new(
		0.16,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	),
}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function make(className, parent, props)
	local object = Instance.new(className)

	for key, value in pairs(props or {}) do
		object[key] = value
	end

	object.Parent = parent

	return object
end

local function tween(object, info, props)
	if not object or not object.Parent then
		return
	end

	local animation =
		TweenService:Create(
			object,
			info,
			props
		)

	animation:Play()

	return animation
end

local function corner(parent, radius)
	return make(
		"UICorner",
		parent,
		{
			CornerRadius =
				UDim.new(
					0,
					radius
				),
		}
	)
end

local function stroke(
	parent,
	color,
	transparency
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

			Thickness = 1,
		}
	)
end

local function english(ctx)
	return ctx.language
		and ctx.language() == "en"
end

---------------------------------------------------------------------
-- CREATE
---------------------------------------------------------------------

function OnboardingUI.create(ctx)
	local self = {
		dismissed = false,
		talked = false,
		stage = nil,
	}

	local parent =
		ctx.hintRail
		or ctx.gui

	-----------------------------------------------------------------
	-- ROOT
	-----------------------------------------------------------------

	local card =
		make(
			"CanvasGroup",
			parent,
			{
				Name =
				"GuideBookPrompt",

				Size =
				UDim2.fromOffset(
					232,
					58
				),

				BackgroundColor3 =
				C.Cover,

				BackgroundTransparency =
				0,

				GroupTransparency =
				1,

				Visible =
				false,

				BorderSizePixel =
				0,

				LayoutOrder =
				1,

				ZIndex =
				30,
			}
		)

	corner(card, 7)

	local outline =
		stroke(
			card,
			C.Border,
			0.30
		)

	local objectScale =
		make(
			"UIScale",
			card,
			{
				Scale = 0.97,
			}
		)

	-----------------------------------------------------------------
	-- MINI BOOK
	-----------------------------------------------------------------

	local book =
		make(
			"Frame",
			card,
			{
				Name = "Book",

				Position =
				UDim2.fromOffset(
					10,
					7
				),

				Size =
				UDim2.fromOffset(
					40,
					44
				),

				BackgroundColor3 =
				Color3.fromRGB(
					64,
					45,
					50
				),

				BorderSizePixel =
				0,

				ZIndex =
				32,
			}
		)

	corner(book, 4)

	stroke(
		book,
		C.Brass,
		0.28
	)

	-----------------------------------------------------------------
	-- SPINE
	-----------------------------------------------------------------

	local spine =
		make(
			"Frame",
			book,
			{
				Position =
				UDim2.fromOffset(
					5,
					3
				),

				Size =
				UDim2.new(
					0,
					3,
					1,
					-6
				),

				BackgroundColor3 =
				C.Brass,

				BorderSizePixel =
				0,

				ZIndex =
				33,
			}
		)

	corner(spine, 2)

	-----------------------------------------------------------------
	-- PAGE EDGES
	-----------------------------------------------------------------

	for i = 0, 2 do
		make(
			"Frame",
			book,
			{
				Position =
					UDim2.new(
						0,
						11,
						1,
						-9 - i * 3
					),

				Size =
					UDim2.new(
						1,
						-17,
						0,
						1
					),

				BackgroundColor3 =
					C.Page,

				BackgroundTransparency =
					0.18 + i * 0.12,

				BorderSizePixel =
					0,

				ZIndex =
					33,
			}
		)
	end

	-----------------------------------------------------------------
	-- SYMBOL
	-----------------------------------------------------------------

	local symbol =
		make(
			"TextLabel",
			book,
			{
				Position =
				UDim2.fromOffset(
					11,
					5
				),

				Size =
				UDim2.new(
					1,
					-16,
					0,
					24
				),

				BackgroundTransparency =
				1,

				Text = "?",

				Font =
				FONT.Strong,

				TextSize =
				14,

				TextColor3 =
				C.Brass,

				TextXAlignment =
				Enum.TextXAlignment.Center,

				ZIndex =
				34,
			}
		)

	-----------------------------------------------------------------
	-- TITLE ONLY
	-----------------------------------------------------------------

	local title =
		make(
			"TextLabel",
			card,
			{
				Position =
				UDim2.fromOffset(
					62,
					0
				),

				Size =
				UDim2.new(
					1,
					-74,
					1,
					0
				),

				BackgroundTransparency =
				1,

				Text =
				english(ctx)
				and "GUIDE"
				or "РУКОВОДСТВО",

				Font =
				FONT.Strong,

				TextSize =
				12,

				TextColor3 =
				C.Text,

				TextXAlignment =
				Enum.TextXAlignment.Left,

				TextYAlignment =
				Enum.TextYAlignment.Center,

				ZIndex =
				33,
			}
		)

	-----------------------------------------------------------------
	-- HIT AREA
	-----------------------------------------------------------------

	local hit =
		make(
			"TextButton",
			card,
			{
				Name = "OpenGuide",

				Size =
				UDim2.fromScale(
					1,
					1
				),

				BackgroundTransparency =
				1,

				Text = "",

				AutoButtonColor =
				false,

				ZIndex =
				40,
			}
		)

	-----------------------------------------------------------------
	-- STATE
	-----------------------------------------------------------------

	local visible = false
	local token = 0

	local function show()
		title.Text =
			english(ctx)
			and "GUIDE"
			or "РУКОВОДСТВО"

		if visible then
			return
		end

		visible = true
		self.stage = "guide"

		token += 1

		card.Visible = true
		card.GroupTransparency = 1
		objectScale.Scale = 0.97

		tween(
			card,
			T.Show,
			{
				GroupTransparency = 0,
			}
		)

		tween(
			objectScale,
			T.Show,
			{
				Scale = 1,
			}
		)
	end

	local function hide()
		if not visible then
			card.Visible = false
			self.stage = nil
			return
		end

		visible = false
		self.stage = nil

		token += 1

		local currentToken =
			token

		tween(
			card,
			T.Hide,
			{
				GroupTransparency = 1,
			}
		)

		local closing =
			tween(
				objectScale,
				T.Hide,
				{
					Scale = 0.97,
				}
			)

		if closing then
			closing.Completed:Once(function()
				if currentToken == token
					and not visible
				then
					card.Visible =
						false
				end
			end)
		end
	end

	-----------------------------------------------------------------
	-- HOVER
	-----------------------------------------------------------------

	hit.MouseEnter:Connect(function()
		tween(
			card,
			T.Hover,
			{
				BackgroundColor3 =
					C.CoverHover,
			}
		)

		tween(
			outline,
			T.Hover,
			{
				Color =
					C.Brass,

				Transparency =
					0.12,
			}
		)

		tween(
			objectScale,
			T.Hover,
			{
				Scale = 1.018,
			}
		)

		tween(
			book,
			T.Hover,
			{
				Position =
					UDim2.fromOffset(
						11,
						6
					),
			}
		)
	end)

	hit.MouseLeave:Connect(function()
		tween(
			card,
			T.Hover,
			{
				BackgroundColor3 =
					C.Cover,
			}
		)

		tween(
			outline,
			T.Hover,
			{
				Color =
					C.Border,

				Transparency =
					0.30,
			}
		)

		tween(
			objectScale,
			T.Show,
			{
				Scale = 1,
			}
		)

		tween(
			book,
			T.Show,
			{
				Position =
					UDim2.fromOffset(
						10,
						7
					),
			}
		)
	end)

	-----------------------------------------------------------------
	-- PRESS
	-----------------------------------------------------------------

	hit.MouseButton1Down:Connect(function()
		tween(
			card,
			T.Press,
			{
				BackgroundColor3 =
					C.CoverPressed,
			}
		)

		tween(
			objectScale,
			T.Press,
			{
				Scale = 0.96,
			}
		)
	end)

	hit.MouseButton1Up:Connect(function()
		tween(
			objectScale,
			T.Show,
			{
				Scale = 1.018,
			}
		)
	end)

	-----------------------------------------------------------------
	-- CLICK
	-----------------------------------------------------------------

	hit.Activated:Connect(function()
		self.dismissed = true

		hide()

		task.defer(function()
			GuideUI.open(ctx)
		end)
	end)

	-----------------------------------------------------------------
	-- COMPATIBILITY
	-----------------------------------------------------------------

	function self:markTalked()
		self.talked = true
	end

	function self:isVisible()
		return visible
			and card.Visible
	end

	-----------------------------------------------------------------
	-- UPDATE
	-----------------------------------------------------------------

	function self:update(profile, state)
		if self.dismissed then
			hide()
			return
		end

		if not profile
			or not profile.ready
		then
			hide()
			return
		end

		---------------------------------------------------------
		-- После первой партии автоматически больше не показываем.
		---------------------------------------------------------

		if (profile.rounds or 0) > 0 then
			hide()
			return
		end

		---------------------------------------------------------
		-- Во время игры / за столом не мешаем.
		---------------------------------------------------------

		if state
			and state.tableId
		then
			hide()
			return
		end

		---------------------------------------------------------
		-- Если открыт диалог — тоже прячем.
		---------------------------------------------------------

		if ctx.dialogueVisible
			and ctx.dialogueVisible()
		then
			hide()
			return
		end

		show()
	end

	return self
end

return OnboardingUI
