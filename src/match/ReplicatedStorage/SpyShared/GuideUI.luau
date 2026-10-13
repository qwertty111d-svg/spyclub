-- ReplicatedStorage > SpyShared > GuideUI
-- ПОЛНАЯ ЗАМЕНА
--
-- Отдельное руководство-книга.
-- НЕ зависит от DialogueUI / Vincent.
--
-- API:
--   local GuideUI = require(script.Parent.GuideUI)
--   GuideUI.open(ctx)
--   GuideUI.close(ctx)

local TweenService = game:GetService("TweenService")

local GuideUI = {}

local instances = setmetatable({}, {
	__mode = "k",
})

---------------------------------------------------------------------
-- STYLE
---------------------------------------------------------------------

local FONT = {
	Title = Enum.Font.BuilderSans,
	Strong = Enum.Font.BuilderSans,
	Body = Enum.Font.BuilderSans,
	Meta = Enum.Font.BuilderSansMedium,
}

local C = {
	Shade = Color3.fromRGB(10, 8, 9),

	Cover = Color3.fromRGB(41, 31, 35),
	CoverRaised = Color3.fromRGB(52, 40, 44),

	Page = Color3.fromRGB(230, 217, 198),
	PageSecond = Color3.fromRGB(224, 210, 191),

	Ink = Color3.fromRGB(52, 41, 38),
	InkSoft = Color3.fromRGB(94, 78, 72),

	Brass = Color3.fromRGB(185, 145, 89),
	BrassHover = Color3.fromRGB(202, 162, 102),

	Line = Color3.fromRGB(175, 154, 131),

	DarkButton = Color3.fromRGB(39, 31, 34),
	DarkButtonHover = Color3.fromRGB(52, 41, 45),
	DarkButtonPressed = Color3.fromRGB(31, 25, 28),

	Ivory = Color3.fromRGB(239, 232, 223),
	Muted = Color3.fromRGB(164, 150, 144),
}

local MOTION = {
	Fast = TweenInfo.new(
		0.13,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Normal = TweenInfo.new(
		0.22,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Close = TweenInfo.new(
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

	local animation = TweenService:Create(
		object,
		info,
		props
	)

	animation:Play()

	return animation
end

local function frame(parent, props)
	props = props or {}
	props.BorderSizePixel = 0

	return make("Frame", parent, props)
end

local function label(parent, props)
	props = props or {}

	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0

	props.Font = props.Font or FONT.Body
	props.TextColor3 = props.TextColor3 or C.Ink

	props.TextXAlignment =
		props.TextXAlignment
		or Enum.TextXAlignment.Left

	props.TextYAlignment =
		props.TextYAlignment
		or Enum.TextYAlignment.Center

	return make("TextLabel", parent, props)
end

local function button(parent, props)
	props = props or {}

	props.BorderSizePixel = 0
	props.AutoButtonColor = false

	return make("TextButton", parent, props)
end

local function corner(parent, radius)
	return make(
		"UICorner",
		parent,
		{
			CornerRadius = UDim.new(0, radius),
		}
	)
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
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,

			Color = color,
			Transparency = transparency or 0,
			Thickness = thickness or 1,
		}
	)
end

local function addScale(parent)
	return make(
		"UIScale",
		parent,
		{
			Scale = 1,
		}
	)
end

local function english(ctx)
	return ctx.language
		and ctx.language() == "en"
end

---------------------------------------------------------------------
-- BUTTON FEEL
---------------------------------------------------------------------

local function tactile(
	target,
	normal,
	hover,
	pressed
)
	local objectScale = addScale(target)

	local inside = false
	local down = false

	target.MouseEnter:Connect(function()
		inside = true

		if down then
			return
		end

		tween(
			target,
			MOTION.Fast,
			{
				BackgroundColor3 = hover,
			}
		)

		tween(
			objectScale,
			MOTION.Fast,
			{
				Scale = 1.012,
			}
		)
	end)

	target.MouseLeave:Connect(function()
		inside = false

		if down then
			return
		end

		tween(
			target,
			MOTION.Fast,
			{
				BackgroundColor3 = normal,
			}
		)

		tween(
			objectScale,
			MOTION.Normal,
			{
				Scale = 1,
			}
		)
	end)

	target.MouseButton1Down:Connect(function()
		down = true

		tween(
			target,
			MOTION.Fast,
			{
				BackgroundColor3 = pressed,
			}
		)

		tween(
			objectScale,
			MOTION.Fast,
			{
				Scale = 0.96,
			}
		)
	end)

	target.MouseButton1Up:Connect(function()
		down = false

		tween(
			target,
			MOTION.Normal,
			{
				BackgroundColor3 =
					inside
					and hover
					or normal,
			}
		)

		tween(
			objectScale,
			MOTION.Normal,
			{
				Scale =
					inside
					and 1.012
					or 1,
			}
		)
	end)
end

---------------------------------------------------------------------
-- CONTENT
---------------------------------------------------------------------

local function pages(ctx)
	if english(ctx) then
		return {
			{
				index = "01",
				kicker = "WELCOME TO SPY",
				title = "What is this game?",

				body =
					"No, this isn't an obby. And you don't need to click a glowing button 8,000 times.\n\n"
					.. "This is a social deduction game for 3–4 players. Everyone at the table receives the same secret word — except one player.",

				rightTitle = "THE IDEA",

				points = {
					"3–4 players sit at one table.",
					"One player becomes the spy.",
					"Everyone else knows the secret word.",
				},

				note =
					"The spy's main weapon is confidence.",
			},

			{
				index = "02",
				kicker = "IF YOU KNOW THE WORD",
				title = "Give a clue",

				body =
					"When it's your turn, say something connected to the secret word.\n\n"
					.. "The clue must prove that you know the answer — without making the answer obvious to the spy.",

				rightTitle = "REMEMBER",

				points = {
					"Don't say the word itself.",
					"Don't make the clue useless.",
					"Listen to what others already said.",
				},

				note =
					"Too obvious helps the spy. Too vague makes you look like the spy.",
			},

			{
				index = "03",
				kicker = "IF YOU ARE THE SPY",
				title = "You don't know the word",

				body =
					"Nobody gives the spy the secret word.\n\n"
					.. "Listen to the other clues, work out what they might be talking about and answer as if you knew it all along.",

				rightTitle = "YOUR JOB",

				points = {
					"Listen before speaking.",
					"Don't copy a clue word for word.",
					"Survive the vote.",
				},

				note =
					"If you have no idea what's happening, look like you do.",
			},

			{
				index = "04",
				kicker = "THE VOTE",
				title = "Someone is lying",

				body =
					"After the clues, the table votes for the suspected spy.\n\n"
					.. "To accuse someone successfully, more than half of the table must vote for that player.",

				rightTitle = "IMPORTANT",

				points = {
					"A clear majority is required.",
					"If the wrong player gets the majority, the spy survives.",
					"If there is no majority, the spy also survives.",
				},

				note =
					"So yes — chaos is technically a strategy.",
			},

			{
				index = "05",
				kicker = "THAT'S ALL",
				title = "Now play",

				body =
					"You already know everything necessary for your first match.\n\n"
					.. "Sit at a table, receive your role and try not to expose yourself in the first thirty seconds.",

				rightTitle = "ONE LAST THING",

				points = {
					"Watch how people phrase their clues.",
					"Confidence doesn't mean innocence.",
					"Your first clue doesn't need to be perfect.",
				},

				note =
					"There is no perfect clue. That's the point.",
			},
		}
	end

	return {
		{
			index = "01",
			kicker = "ДОБРО ПОЖАЛОВАТЬ В «ШПИОНА»",
			title = "Что это вообще такое?",

			body =
				"Нет, это не обби. И здесь не надо 8 000 раз нажимать на светящуюся кнопку.\n\n"
				.. "Это игра на общение и дедукцию для 3–4 игроков. Все за столом получают одно секретное слово — кроме одного человека.",

			rightTitle = "СУТЬ",

			points = {
				"За столом сидят 3–4 игрока.",
				"Один из них становится шпионом.",
				"Все остальные знают секретное слово.",
			},

			note =
				"Главное оружие шпиона — уверенное лицо.",
		},

		{
			index = "02",
			kicker = "ЕСЛИ ТЫ ЗНАЕШЬ СЛОВО",
			title = "Дай подсказку",

			body =
				"Когда наступит твоя очередь, скажи что-нибудь связанное с секретным словом.\n\n"
				.. "Подсказка должна показать остальным, что ты знаешь ответ, но не должна подарить ответ шпиону.",

			rightTitle = "ЗАПОМНИ",

			points = {
				"Не называй само слово.",
				"Не говори совсем бесполезную ерунду.",
				"Слушай, что уже сказали до тебя.",
			},

			note =
				"Слишком очевидно — поможешь шпиону. Слишком мутно — шпионом посчитают тебя.",
		},

		{
			index = "03",
			kicker = "ЕСЛИ ТЫ ШПИОН",
			title = "Слова у тебя нет",

			body =
				"Шпиону секретное слово не показывают вообще.\n\n"
				.. "Слушай подсказки остальных, пытайся понять тему и отвечай так, будто ты с самого начала всё прекрасно знал.",

			rightTitle = "ТВОЯ ЗАДАЧА",

			points = {
				"Сначала слушай, потом говори.",
				"Не повторяй чужую подсказку один в один.",
				"Переживи голосование.",
			},

			note =
				"Если ты вообще не понимаешь, о чём речь — главное, чтобы этого не поняли остальные.",
		},

		{
			index = "04",
			kicker = "ГОЛОСОВАНИЕ",
			title = "Кто-то за столом врёт",

			body =
				"После подсказок стол голосует за предполагаемого шпиона.\n\n"
				.. "Чтобы обвинить игрока, за него должно проголосовать больше половины стола.",

			rightTitle = "ВАЖНО",

			points = {
				"Нужно абсолютное большинство.",
				"Обвинили не того — шпион ускользнул.",
				"Большинства нет — шпион тоже ускользнул.",
			},

			note =
				"Да, устроить хаос — технически рабочая тактика.",
		},

		{
			index = "05",
			kicker = "ВОТ И ВСЁ",
			title = "Теперь можно играть",

			body =
				"Этого уже достаточно для первой партии.\n\n"
				.. "Садись за стол, получай роль и постарайся не спалиться в первые тридцать секунд.",

			rightTitle = "НАПОСЛЕДОК",

			points = {
				"Слушай не только слова, но и формулировки.",
				"Уверенность ещё не означает невиновность.",
				"Первая подсказка не обязана быть идеальной.",
			},

			note =
				"Идеальной подсказки нет. В этом и смысл.",
		},
	}
end

---------------------------------------------------------------------
-- INSTANCE
---------------------------------------------------------------------

local function createInstance(ctx)
	local self = {
		visible = false,
		page = 1,
	}

	-----------------------------------------------------------------
	-- SHADE
	-----------------------------------------------------------------

	local shade =
		frame(
			ctx.gui,
			{
				Name = "GuideShade",

				Size = UDim2.fromScale(
					1,
					1
				),

				BackgroundColor3 = C.Shade,

				BackgroundTransparency = 1,

				Visible = false,

				Active = true,

				ZIndex = 220,
			}
		)

	-----------------------------------------------------------------
	-- BOOK COVER
	-----------------------------------------------------------------

	local book =
		make(
			"CanvasGroup",
			ctx.gui,
			{
				Name = "GuideBook",

				AnchorPoint = Vector2.new(
					0.5,
					0.5
				),

				Position = UDim2.fromScale(
					0.5,
					0.5
				),

				Size = UDim2.new(
					0.76,
					0,
					0.70,
					0
				),

				BackgroundColor3 = C.Cover,

				BackgroundTransparency = 0,

				GroupTransparency = 1,

				BorderSizePixel = 0,

				Visible = false,

				ClipsDescendants = true,

				ZIndex = 222,
			}
		)

	make(
		"UISizeConstraint",
		book,
		{
			MinSize = Vector2.new(
				760,
				500
			),

			MaxSize = Vector2.new(
				1080,
				650
			),
		}
	)

	corner(book, 10)

	stroke(
		book,
		Color3.fromRGB(
			104,
			81,
			72
		),
		0.22,
		1
	)

	local bookScale =
		addScale(book)

	bookScale.Scale = 0.97

	-----------------------------------------------------------------
	-- COVER SPINE
	-----------------------------------------------------------------

	local coverSpine =
		frame(
			book,
			{
				Position = UDim2.fromOffset(
					15,
					18
				),

				Size = UDim2.new(
					0,
					4,
					1,
					-36
				),

				BackgroundColor3 = C.Brass,

				BackgroundTransparency = 0.08,

				ZIndex = 223,
			}
		)

	corner(coverSpine, 2)

	-----------------------------------------------------------------
	-- CLOSE
	-----------------------------------------------------------------

	local close =
		button(
			book,
			{
				Name = "Close",

				AnchorPoint = Vector2.new(
					1,
					0
				),

				Position = UDim2.new(
					1,
					-15,
					0,
					14
				),

				Size = UDim2.fromOffset(
					38,
					38
				),

				BackgroundColor3 =
				C.CoverRaised,

				Text = "×",

				TextColor3 = C.Ivory,

				Font = FONT.Strong,

				TextSize = 16,

				ZIndex = 230,
			}
		)

	corner(close, 6)

	tactile(
		close,
		C.CoverRaised,
		Color3.fromRGB(
			63,
			48,
			53
		),
		Color3.fromRGB(
			35,
			27,
			30
		)
	)

	-----------------------------------------------------------------
	-- PAGE SPREAD
	-----------------------------------------------------------------

	local spread =
		make(
			"CanvasGroup",
			book,
			{
				Name = "Spread",

				Position = UDim2.fromOffset(
					32,
					28
				),

				Size = UDim2.new(
					1,
					-64,
					1,
					-82
				),

				BackgroundTransparency = 1,

				GroupTransparency = 0,

				ZIndex = 224,
			}
		)

	-----------------------------------------------------------------
	-- LEFT PAGE
	-----------------------------------------------------------------

	local leftPage =
		frame(
			spread,
			{
				Name = "LeftPage",

				Size = UDim2.new(
					0.5,
					-4,
					1,
					0
				),

				BackgroundColor3 = C.Page,

				ZIndex = 225,
			}
		)

	corner(leftPage, 5)

	-----------------------------------------------------------------
	-- RIGHT PAGE
	-----------------------------------------------------------------

	local rightPage =
		frame(
			spread,
			{
				Name = "RightPage",

				Position = UDim2.new(
					0.5,
					4,
					0,
					0
				),

				Size = UDim2.new(
					0.5,
					-4,
					1,
					0
				),

				BackgroundColor3 = C.PageSecond,

				ZIndex = 225,
			}
		)

	corner(rightPage, 5)

	-----------------------------------------------------------------
	-- GUTTER
	-----------------------------------------------------------------

	local gutter =
		frame(
			spread,
			{
				AnchorPoint = Vector2.new(
					0.5,
					0
				),

				Position = UDim2.new(
					0.5,
					0,
					0,
					8
				),

				Size = UDim2.new(
					0,
					2,
					1,
					-16
				),

				BackgroundColor3 =
				Color3.fromRGB(
					133,
					107,
					91
				),

				BackgroundTransparency =
				0.70,

				ZIndex = 227,
			}
		)

	-----------------------------------------------------------------
	-- LEFT CONTENT
	-----------------------------------------------------------------

	local index =
		label(
			leftPage,
			{
				Position = UDim2.fromOffset(
					34,
					31
				),

				Size = UDim2.fromOffset(
					48,
					24
				),

				Text = "",

				Font = FONT.Meta,

				TextSize = 13,

				TextColor3 = C.Brass,

				ZIndex = 228,
			}
		)

	local kicker =
		label(
			leftPage,
			{
				Position = UDim2.fromOffset(
					84,
					31
				),

				Size = UDim2.new(
					1,
					-116,
					0,
					24
				),

				Text = "",

				Font = FONT.Meta,

				TextSize = 12,

				TextColor3 = C.InkSoft,

				ZIndex = 228,
			}
		)

	local title =
		label(
			leftPage,
			{
				Position = UDim2.fromOffset(
					34,
					74
				),

				Size = UDim2.new(
					1,
					-68,
					0,
					80
				),

				Text = "",

				Font = FONT.Title,

				TextSize = 28,

				TextColor3 = C.Ink,

				TextWrapped = true,

				TextYAlignment =
				Enum.TextYAlignment.Top,

				ZIndex = 228,
			}
		)

	frame(
		leftPage,
		{
			Position = UDim2.fromOffset(
				34,
				164
			),

			Size = UDim2.new(
				1,
				-68,
				0,
				1
			),

			BackgroundColor3 = C.Line,

			BackgroundTransparency = 0.18,

			ZIndex = 228,
		}
	)

	local body =
		label(
			leftPage,
			{
				Position = UDim2.fromOffset(
					34,
					187
				),

				Size = UDim2.new(
					1,
					-68,
					1,
					-220
				),

				Text = "",

				Font = FONT.Body,

				TextSize = 17,

				TextColor3 = C.Ink,

				TextWrapped = true,

				TextYAlignment =
				Enum.TextYAlignment.Top,

				LineHeight = 1.22,

				ZIndex = 228,
			}
		)

	-----------------------------------------------------------------
	-- RIGHT PAGE
	-----------------------------------------------------------------

	local rightTitle =
		label(
			rightPage,
			{
				Position = UDim2.fromOffset(
					36,
					41
				),

				Size = UDim2.new(
					1,
					-72,
					0,
					30
				),

				Text = "",

				Font = FONT.Strong,

				TextSize = 15,

				TextColor3 = C.Ink,

				ZIndex = 228,
			}
		)

	local listHolder =
		frame(
			rightPage,
			{
				Position = UDim2.fromOffset(
					36,
					92
				),

				Size = UDim2.new(
					1,
					-72,
					0,
					210
				),

				BackgroundTransparency = 1,

				ZIndex = 228,
			}
		)

	local noteBox =
		frame(
			rightPage,
			{
				AnchorPoint = Vector2.new(
					0,
					1
				),

				Position = UDim2.new(
					0,
					36,
					1,
					-36
				),

				Size = UDim2.new(
					1,
					-72,
					0,
					86
				),

				BackgroundColor3 =
				Color3.fromRGB(
					213,
					196,
					172
				),

				ZIndex = 228,
			}
		)

	corner(noteBox, 5)

	local noteMark =
		label(
			noteBox,
			{
				Position = UDim2.fromOffset(
					14,
					10
				),

				Size = UDim2.fromOffset(
					30,
					24
				),

				Text = "“",

				Font = FONT.Title,

				TextSize = 26,

				TextColor3 = C.Brass,

				ZIndex = 229,
			}
		)

	local noteText =
		label(
			noteBox,
			{
				Position = UDim2.fromOffset(
					43,
					11
				),

				Size = UDim2.new(
					1,
					-57,
					1,
					-22
				),

				Text = "",

				Font = FONT.Strong,

				TextSize = 13,

				TextColor3 = C.InkSoft,

				TextWrapped = true,

				TextYAlignment =
				Enum.TextYAlignment.Center,

				ZIndex = 229,
			}
		)

	-----------------------------------------------------------------
	-- BOTTOM NAV
	-----------------------------------------------------------------

	local previous =
		button(
			book,
			{
				Name = "Previous",

				Position = UDim2.new(
					0,
					32,
					1,
					-46
				),

				Size = UDim2.fromOffset(
					120,
					32
				),

				BackgroundColor3 =
				C.DarkButton,

				Text = "",

				TextColor3 = C.Ivory,

				Font = FONT.Strong,

				TextSize = 11,

				ZIndex = 230,
			}
		)

	corner(previous, 5)

	tactile(
		previous,
		C.DarkButton,
		C.DarkButtonHover,
		C.DarkButtonPressed
	)

	local counter =
		label(
			book,
			{
				AnchorPoint = Vector2.new(
					0.5,
					0
				),

				Position = UDim2.new(
					0.5,
					0,
					1,
					-44
				),

				Size = UDim2.fromOffset(
					100,
					28
				),

				Text = "",

				Font = FONT.Meta,

				TextSize = 11,

				TextColor3 = C.Muted,

				TextXAlignment =
				Enum.TextXAlignment.Center,

				ZIndex = 230,
			}
		)

	local nextButton =
		button(
			book,
			{
				Name = "Next",

				AnchorPoint = Vector2.new(
					1,
					0
				),

				Position = UDim2.new(
					1,
					-32,
					1,
					-46
				),

				Size = UDim2.fromOffset(
					140,
					32
				),

				BackgroundColor3 =
				C.DarkButton,

				Text = "",

				TextColor3 = C.Ivory,

				Font = FONT.Strong,

				TextSize = 11,

				ZIndex = 230,
			}
		)

	corner(nextButton, 5)

	tactile(
		nextButton,
		C.DarkButton,
		C.DarkButtonHover,
		C.DarkButtonPressed
	)

	-----------------------------------------------------------------
	-- LIST
	-----------------------------------------------------------------

	local function renderPoints(points)
		for _, child in ipairs(
			listHolder:GetChildren()
			) do
			child:Destroy()
		end

		for i, value in ipairs(points) do
			local y =
				(i - 1) * 62

			local number =
				label(
					listHolder,
					{
						Position =
						UDim2.fromOffset(
							0,
							y
						),

						Size =
						UDim2.fromOffset(
							26,
							22
						),

						Text =
						string.format(
							"%02d",
							i
						),

						Font =
						FONT.Meta,

						TextSize =
						10,

						TextColor3 =
						C.Brass,

						ZIndex =
						229,
					}
				)

			local point =
				label(
					listHolder,
					{
						Position =
						UDim2.fromOffset(
							36,
							y - 2
						),

						Size =
						UDim2.new(
							1,
							-36,
							0,
							48
						),

						Text = value,

						Font =
						FONT.Body,

						TextSize =
						14,

						TextColor3 =
						C.Ink,

						TextWrapped =
						true,

						TextYAlignment =
						Enum.TextYAlignment.Top,

						ZIndex =
						229,
					}
				)
		end
	end

	-----------------------------------------------------------------
	-- RENDER PAGE
	-----------------------------------------------------------------

	local function renderPage(animate)
		local allPages = pages(ctx)

		self.page =
			math.clamp(
				self.page,
				1,
				#allPages
			)

		local data =
			allPages[self.page]

		if animate then
			spread.GroupTransparency = 1
			spread.Position =
				UDim2.fromOffset(
					42,
					28
				)

			tween(
				spread,
				MOTION.Normal,
				{
					GroupTransparency = 0,

					Position =
						UDim2.fromOffset(
							32,
							28
						),
				}
			)
		end

		index.Text = data.index
		kicker.Text = data.kicker
		title.Text = data.title
		body.Text = data.body

		rightTitle.Text =
			data.rightTitle

		noteText.Text =
			data.note

		renderPoints(
			data.points
		)

		previous.Text =
			english(ctx)
			and "Previous"
			or "Назад"

		previous.Visible =
			self.page > 1

		counter.Text =
			tostring(
				self.page
			)
			.. "  /  "
			.. tostring(
				#allPages
			)

		nextButton.Text =
			self.page == #allPages
			and (
				english(ctx)
				and "Got it"
				or "Понятно"
			)
			or (
				english(ctx)
				and "Next"
				or "Дальше"
			)
	end

	-----------------------------------------------------------------
	-- OPEN / CLOSE
	-----------------------------------------------------------------

	function self:open()
		if self.visible then
			renderPage(false)
			return
		end

		if ctx.closePanels then
			ctx.closePanels(nil)
		end

		if ctx.closeDialogue then
			ctx.closeDialogue()
		end

		self.visible = true

		shade.Visible = true
		book.Visible = true

		shade.BackgroundTransparency = 1
		book.GroupTransparency = 1
		bookScale.Scale = 0.97

		renderPage(false)

		tween(
			shade,
			MOTION.Normal,
			{
				BackgroundTransparency = 0.91,
			}
		)

		tween(
			book,
			MOTION.Normal,
			{
				GroupTransparency = 0,
			}
		)

		tween(
			bookScale,
			MOTION.Normal,
			{
				Scale = 1,
			}
		)
	end

	function self:close()
		if not self.visible then
			return
		end

		self.visible = false

		tween(
			shade,
			MOTION.Close,
			{
				BackgroundTransparency = 1,
			}
		)

		tween(
			book,
			MOTION.Close,
			{
				GroupTransparency = 1,
			}
		)

		local closing =
			tween(
				bookScale,
				MOTION.Close,
				{
					Scale = 0.975,
				}
			)

		if closing then
			closing.Completed:Once(function()
				if not self.visible then
					book.Visible = false
					shade.Visible = false
				end
			end)
		end
	end

	-----------------------------------------------------------------
	-- INPUT
	-----------------------------------------------------------------

	close.Activated:Connect(function()
		self:close()
	end)

	previous.Activated:Connect(function()
		if self.page <= 1 then
			return
		end

		self.page -= 1
		renderPage(true)
	end)

	nextButton.Activated:Connect(function()
		local allPages = pages(ctx)

		if self.page >= #allPages then
			self:close()
			return
		end

		self.page += 1
		renderPage(true)
	end)

	return self
end

---------------------------------------------------------------------
-- SINGLETON
---------------------------------------------------------------------

function GuideUI.get(ctx)
	local existing =
		instances[ctx.gui]

	if existing then
		return existing
	end

	local created =
		createInstance(ctx)

	instances[ctx.gui] =
		created

	return created
end

function GuideUI.open(ctx)
	local guide =
		GuideUI.get(ctx)

	guide:open()

	return guide
end

function GuideUI.close(ctx)
	local guide =
		instances[ctx.gui]

	if guide then
		guide:close()
	end
end

return GuideUI
