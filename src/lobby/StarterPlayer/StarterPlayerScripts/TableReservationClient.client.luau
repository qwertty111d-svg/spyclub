local controlShared=game:GetService("ReplicatedStorage"):FindFirstChild("SpyShared")
local controlThemeNode=controlShared and controlShared:FindFirstChild("UITheme")
local ControlTheme=controlThemeNode and require(controlThemeNode)
-- StarterPlayer > StarterPlayerScripts > TableReservationClient
-- ПОЛНАЯ ЗАМЕНА · DARK CLUB REDESIGN
--
-- В этом скрипте:
-- • создание лобби;
-- • название лобби;
-- • 3 / 4 игрока;
-- • открытое / по приглашению;
-- • поиск открытых лобби;
-- • вход по коду;
-- • список участников;
-- • хост отмечается;
-- • хост может выгнать игрока;
-- • только хост видит кнопку старта;
-- • старт доступен от 3 игроков;
-- • клик по пустому месту ВНУТРИ окна не закрывает меню.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hud = playerGui:WaitForChild("HudGui")
local mainAction = hud:WaitForChild("MainAction")

local remotes =
	ReplicatedStorage:
	WaitForChild("SpyPartyRemotes")

local request =
	remotes:
	WaitForChild("Request")

local update =
	remotes:
	WaitForChild("Update")

---------------------------------------------------------------------
-- STYLE
---------------------------------------------------------------------

local FONT = {
	Title = Enum.Font.BuilderSansBold,
	Strong = Enum.Font.BuilderSansBold,
	Body = Enum.Font.BuilderSansMedium,
}

local C = {
	Shade = Color3.fromRGB(26,28,32),

	Shell = Color3.fromRGB(25,27,31),
	ShellRaised = Color3.fromRGB(46,48,52),

	Paper = Color3.fromRGB(34,36,40),
	PaperSide = Color3.fromRGB(46,48,52),

	Ink = Color3.fromRGB(244,240,231),
	InkSoft = Color3.fromRGB(188,187,181),
	InkFaint = Color3.fromRGB(154,153,149),

	Ivory = Color3.fromRGB(244,240,231),
	Muted = Color3.fromRGB(188,187,181),

	Brass = Color3.fromRGB(221,193,151),
	BrassHover = Color3.fromRGB(174, 229, 237),
	BrassPressed = Color3.fromRGB(117, 182, 195),

	Selected = Color3.fromRGB(61, 69, 79),
	SelectedHover = Color3.fromRGB(73, 82, 94),
	SelectedPressed = Color3.fromRGB(47, 53, 62),

	Line = Color3.fromRGB(67, 74, 85),

	Dark = Color3.fromRGB(29, 33, 39),
	DarkHover = Color3.fromRGB(44, 49, 57),
	DarkPressed = Color3.fromRGB(21, 24, 29),

	Danger = Color3.fromRGB(85, 46, 49),
	DangerHover = Color3.fromRGB(112, 58, 61),
}

local T = {
	Fast = TweenInfo.new(
		0.12,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Normal = TweenInfo.new(
		0.20,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Close = TweenInfo.new(
		0.15,
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

local function frame(parent, props)
	props = props or {}
	props.BorderSizePixel = 0

	return make(
		"Frame",
		parent,
		props
	)
end

local function label(parent, props)
	props = props or {}

	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0

	props.Font =
		props.Font
		or FONT.Body

	props.TextColor3 =
		props.TextColor3
		or C.Ivory

	props.TextXAlignment =
		props.TextXAlignment
		or Enum.TextXAlignment.Left

	props.TextYAlignment =
		props.TextYAlignment
		or Enum.TextYAlignment.Center

	return make(
		"TextLabel",
		parent,
		props
	)
end

local function button(parent, props)
	props = props or {}

	props.BorderSizePixel = 0
	props.AutoButtonColor = false
 props.Font=props.Font or FONT.Strong

	local b=make("TextButton",parent,props)
 if ControlTheme and ControlTheme.button then ControlTheme.button(b,false)end
 return b
end

local function corner(parent, radius)
 if parent:IsA("TextButton")or parent:IsA("TextBox")then radius=math.max(radius or 12,12)end
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
				transparency or 0,

			Thickness =
				thickness or 1,
		}
	)
end

local function premiumPanel(parent, accent)
	stroke(
		parent,
		accent and C.Brass or C.Line,
		accent and 0.34 or 0.22,
		1.5
	)
end

local function addScale(parent, value)
	return make(
		"UIScale",
		parent,
		{
			Scale =
				value or 1,
		}
	)
end

local function tactile(
	target,
	normal,
	hover,
	pressed
)
	local objectScale =
		addScale(
			target,
			1
		)

	local inside = false
	local down = false

	target.MouseEnter:Connect(function()
		inside = true

		if down then
			return
		end

		tween(
			target,
			T.Fast,
			{
				BackgroundColor3 =
					hover,
			}
		)

		tween(
			objectScale,
			T.Fast,
			{
				Scale = 1.015,
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
			T.Fast,
			{
				BackgroundColor3 =
					normal,
			}
		)

		tween(
			objectScale,
			T.Normal,
			{
				Scale = 1,
			}
		)
	end)

	target.MouseButton1Down:Connect(function()
		down = true

		tween(
			target,
			T.Fast,
			{
				BackgroundColor3 =
					pressed,
			}
		)

		tween(
			objectScale,
			T.Fast,
			{
				Scale = 0.965,
			}
		)
	end)

	target.MouseButton1Up:Connect(function()
		down = false

		tween(
			target,
			T.Normal,
			{
				BackgroundColor3 =
					inside
					and hover
					or normal,
			}
		)

		tween(
			objectScale,
			T.Normal,
			{
				Scale =
					inside
					and 1.015
					or 1,
			}
		)
	end)
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
			"TableReservationGui",

			ResetOnSpawn =
			false,

			IgnoreGuiInset =
			true,

			DisplayOrder =
			80,

			ZIndexBehavior =
			Enum.ZIndexBehavior.Sibling,
		}
	)

---------------------------------------------------------------------
-- SHADE
---------------------------------------------------------------------

local shade =
	button(
		gui,
		{
			Name = "Shade",

			Size =
			UDim2.fromScale(
				1,
				1
			),

			BackgroundColor3 =
			C.Shade,

			BackgroundTransparency =
			1,

			Text = "",

			Visible =
			false,

			ZIndex =
			1,
		}
	)

---------------------------------------------------------------------
-- WINDOW
---------------------------------------------------------------------

local window =
	make(
		"CanvasGroup",
		gui,
		{
			Name =
			"ReservationWindow",

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
			UDim2.fromOffset(
				620,
				420
			),

			BackgroundColor3 =
			C.Shell,

			GroupTransparency =
			1,

			Visible =
			false,

			Active =
			true,

			ClipsDescendants =
			true,

			BorderSizePixel =
			0,

			ZIndex =
			5,
		}
	)

corner(window, 20);window.BackgroundTransparency=.16

stroke(window, C.Line, 0.25, 1)

local topAccent =
	frame(
		window,
		{
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -44, 0, 3),
			BackgroundColor3 = C.Brass,
			BackgroundTransparency = 0,
			ZIndex = 6,
		}
	)

local windowScale =
	addScale(
		window,
		1
	)

---------------------------------------------------------------------
-- BLOCK CLICKS THROUGH WINDOW
---------------------------------------------------------------------

local modalBlocker =
	button(
		window,
		{
			Name =
			"ModalBlocker",

			Size =
			UDim2.fromScale(
				1,
				1
			),

			BackgroundTransparency =
			1,

			Text = "",

			ZIndex =
			5,
		}
	)

modalBlocker.Activated:Connect(function()
	-- intentionally empty
end)

---------------------------------------------------------------------
-- RESPONSIVE
---------------------------------------------------------------------

pcall(function()gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end)
local findView,partyView,secondaryLayout
local reservationLayout
local function resize()
	local camera =
		workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport=gui.AbsoluteSize
	if viewport.X<=0 or viewport.Y<=0 then viewport=camera.ViewportSize end

	if reservationLayout then reservationLayout(viewport) end
	local value = math.min(1,(viewport.X-24)/window.Size.X.Offset,(viewport.Y-24)/window.Size.Y.Offset)
	windowScale.Scale = math.clamp(value,0,1)
end

resize()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

if workspace.CurrentCamera then
	workspace.CurrentCamera:
		GetPropertyChangedSignal(
			"ViewportSize"
		):
		Connect(resize)
end

---------------------------------------------------------------------
-- HEADER
---------------------------------------------------------------------

local title =
	label(
		window,
		{
			Position =
			UDim2.fromOffset(
				28,
				21
			),

			Size =
			UDim2.new(
				1,
				-265,
				0,
				35
			),

			Text =
			"Создать стол",

			Font =
			FONT.Title,

			TextSize =
			26,

			TextColor3 =
			C.Ivory,

			TextTruncate =
			Enum.TextTruncate.AtEnd,

			ZIndex =
			7,
		}
	)

local modeButton =
	button(
		window,
		{
			AnchorPoint =
			Vector2.new(
				1,
				0
			),

			Position =
			UDim2.new(
				1,
				-68,
				0,
				19
			),

			Size =
			UDim2.fromOffset(
				125,
				34
			),

			BackgroundTransparency =
			1,

			Text =
			"Найти стол",

			TextColor3 =
			C.Brass,

			Font =
			FONT.Strong,

			TextSize =
			13,

			TextXAlignment =
			Enum.TextXAlignment.Right,

			ZIndex =
			8,
		}
	)

local close =
	button(
		window,
		{
			AnchorPoint =
			Vector2.new(
				1,
				0
			),

			Position =
			UDim2.new(
				1,
				-18,
				0,
				17
			),

			Size =
			UDim2.fromOffset(
				34,
				34
			),

			BackgroundColor3 =
			C.ShellRaised,

			Text =
			"×",

			TextColor3 =
			C.Muted,

			Font =
			FONT.Strong,

			TextSize =
			18,

			ZIndex =
			9,
		}
	)

corner(close, 6)

tactile(
	close,
	C.ShellRaised,
	C.DarkHover,
	C.DarkPressed
)

frame(
	window,
	{
		Position =
			UDim2.fromOffset(
				28,
				72
			),

		Size =
			UDim2.new(
				1,
				-56,
				0,
				1
			),

		BackgroundColor3 =
			C.Line,

		BackgroundTransparency =
			0.35,

		ZIndex =
			7,
	}
)

---------------------------------------------------------------------
-- PARTY RULES
---------------------------------------------------------------------

local fixedHintSeconds=45
local sharedRules=ReplicatedStorage:FindFirstChild("SpyShared")
local rulesModule=sharedRules and sharedRules:FindFirstChild("MatchRules")
if rulesModule then
 local ok,rules=pcall(require,rulesModule)
 if ok and type(rules)=="table" and type(rules.defaults)=="function" then fixedHintSeconds=rules.defaults().hintSeconds or 45 end
end

local RULE_THEME_CHOICES = {
	{id="cities", title="Города"}, {id="countries", title="Страны"}, {id="animals", title="Животные"},
	{id="professions", title="Профессии"}, {id="food", title="Еда"}, {id="brands", title="Бренды"},
	{id="games", title="Игры"}, {id="dota2_characters", title="Герои Dota 2"}, {id="movies", title="Фильмы"},
	{id="series", title="Сериалы"}, {id="cartoons", title="Мультфильмы"}, {id="anime_characters", title="Аниме"},
	{id="superheroes", title="Супергерои"}, {id="mythology", title="Мифология"}, {id="transport", title="Транспорт"},
	{id="sports", title="Спорт"}, {id="instruments", title="Инструменты"}, {id="space", title="Космос"},
	{id="clothes", title="Одежда"}, {id="household", title="Быт"}, {id="technology", title="Технологии"},
	{id="places", title="Места"}, {id="school_subjects", title="Школьные предметы"}, {id="game_characters", title="Персонажи игр"},
	{id="fairytale_characters", title="Сказочные персонажи"}, {id="drinks", title="Напитки"}, {id="nature", title="Природа"},
	{id="emotions", title="Эмоции"},
}

---------------------------------------------------------------------
-- CREATE VIEW
---------------------------------------------------------------------

-- A single form surface, with values grouped by their own field captions.
local createView = frame(window,{Name="CreateView",Position=UDim2.fromOffset(24,88),Size=UDim2.new(1,-48,0,320),BackgroundTransparency=1,ZIndex=7})
local createPaper = make("ScrollingFrame",createView,{Name="CreateForm",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,ScrollBarThickness=3,ScrollBarImageColor3=C.Brass,CanvasSize=UDim2.fromOffset(0,276),ZIndex=8})
-- Retained as data-only targets for the existing selection renderer.
local summary = frame(createPaper,{Name="SelectionSummary",Visible=false,BackgroundTransparency=1,ZIndex=9})
local summaryCount = label(summary,{Text="3",ZIndex=10})
local summaryAccess = label(summary,{Text="Открытый",ZIndex=10})
local form = frame(createPaper,{Size=UDim2.new(1,-8,0,276),BackgroundTransparency=1,ZIndex=9})
local function fieldCaption(parent,name,text)
 return label(parent,{Name=name,Text=text,Font=FONT.Strong,TextSize=12,TextColor3=C.Muted,ZIndex=10})
end
local function choice(parent,name,text)
 local b=button(parent,{Name=name,Text=text,BackgroundColor3=C.PaperSide,TextColor3=C.InkSoft,Font=FONT.Strong,TextSize=13,ZIndex=10})
 corner(b,6);stroke(b,C.Line,.55,1)
 return b
end
local nameCaption=fieldCaption(form,"NameCaption","Название стола")
local nameInput=make("TextBox",form,{Name="NameInput",BackgroundColor3=C.Dark,BorderSizePixel=0,PlaceholderText="Например: Ночной стол",PlaceholderColor3=C.InkFaint,Text="",TextColor3=C.Ink,Font=FONT.Body,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,ZIndex=10})
corner(nameInput,7);stroke(nameInput,C.Line,.3,1)
make("UIPadding",nameInput,{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
local capacityCaption=fieldCaption(form,"CapacityCaption","Игроки")
local three=choice(form,"CapacityThree","3 игрока")
local four=choice(form,"CapacityFour","4 игрока")
local accessCaption=fieldCaption(form,"AccessCaption","Доступ")
local public=choice(form,"AccessPublic","Открытый")
local invite=choice(form,"AccessInvite","По приглашению")
local hint=label(form,{Name="AccessHint",Text="Другие игроки увидят стол.",Font=FONT.Body,TextSize=12,TextColor3=C.Muted,TextWrapped=true,ZIndex=10})
local rulesButton=choice(createView,"EditRules","Правила матча · 28 тем")
rulesButton.TextXAlignment=Enum.TextXAlignment.Left;rulesButton.TextWrapped=true;rulesButton.TextSize=12
make("UIPadding",rulesButton,{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
make("UIPadding",rulesButton,{PaddingLeft=UDim.new(0,12)})
local create=choice(createView,"CreateTable","Создать стол")
create.BackgroundColor3=C.Brass;create.TextColor3=C.Shell;create.TextSize=16
if ControlTheme and ControlTheme.button then ControlTheme.button(create,true,{arrow=true})end
tactile(create,C.Brass,C.BrassHover,C.BrassPressed)
local createNote=label(createView,{Name="CreateNote",Text="Собери игроков и начни матч.",Font=FONT.Body,TextSize=11,TextColor3=C.InkFaint,TextWrapped=true,ZIndex=9})

local rulesView=make("ScrollingFrame",createView,{Name="RulesView",BackgroundColor3=C.Shell,BorderSizePixel=0,ClipsDescendants=true,ScrollBarThickness=3,ScrollBarImageColor3=C.Brass,CanvasSize=UDim2.fromOffset(0,540),Visible=false,ZIndex=20})
local function ruleChoice(name)
 local b=button(rulesView,{Name=name,BackgroundColor3=C.PaperSide,TextColor3=C.Ink,Font=FONT.Strong,TextSize=13,ZIndex=21})
 corner(b,6);stroke(b,C.Line,.6,1);return b
end
local function ruleCaption(name,text)
 return label(rulesView,{Name=name,Text=text,Font=FONT.Body,TextSize=11,TextColor3=C.Muted,ZIndex=21})
end
local rulesBack=ruleChoice("RulesBack");rulesBack.Text="← Назад"
local rulesTitle=label(rulesView,{Name="RulesTitle",Text="Правила матча",TextColor3=C.Ink,Font=FONT.Strong,TextSize=19,ZIndex=21})
local modeCaption=ruleCaption("TopicModeCaption","Как выбрать тему")
local discussionCaption=ruleCaption("DiscussionCaption","Время обсуждения")
local lapsCaption=ruleCaption("HintLapsCaption","Подсказки · "..tostring(fixedHintSeconds).." сек на ход")
local extraCaption=ruleCaption("ExtraRoundCaption","Дополнительный круг")
local ruleModeButton=ruleChoice("TopicMode")
local ruleDiscussionButton=ruleChoice("DiscussionSeconds")
local ruleLapsButton=ruleChoice("HintLaps")
local ruleExtraButton=ruleChoice("AllowExtraRound")
local ruleGameplayButton=ruleChoice("GameMode")
local themesCaption=label(rulesView,{Name="ThemesCaption",Text="Доступные темы",TextColor3=C.Ink,Font=FONT.Strong,TextSize=13,ZIndex=21})
local ruleAllButton=ruleChoice("SelectAllThemes");ruleAllButton.Text="Все"
local ruleNoneButton=ruleChoice("ClearThemes");ruleNoneButton.Text="Снять все"
local rulesThemeCount=ruleCaption("ThemeSelectionSummary","")
local themesScroll=make("ScrollingFrame",rulesView,{Name="Themes",BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,ScrollBarThickness=3,ScrollBarImageColor3=C.Brass,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=21})
make("UIPadding",themesScroll,{PaddingRight=UDim.new(0,5),PaddingBottom=UDim.new(0,6)})
local themeGrid=make("UIGridLayout",themesScroll,{CellPadding=UDim2.fromOffset(8,7),SortOrder=Enum.SortOrder.LayoutOrder})
local ruleThemeButtons={}
for index,theme in ipairs(RULE_THEME_CHOICES) do
 local b=button(themesScroll,{Name="Theme_"..theme.id,BackgroundColor3=C.Selected,Text=theme.title,TextColor3=C.Ivory,Font=FONT.Body,TextSize=12,TextWrapped=true,LayoutOrder=index,ZIndex=22})
 corner(b,5);ruleThemeButtons[theme.id]=b
end

reservationLayout=function(viewport)
 local width=math.max(1,math.min(viewport.X-28,740))
 local compact=width<500
 local preferred=rulesView.Visible and 674 or (compact and 548 or 438)
 local height=math.max(1,math.min(createView.Visible and preferred or 432,viewport.Y-28))
 local short=height<430
 local header=compact and 108 or 88
 window.Size=UDim2.fromOffset(width,height)
 topAccent.Visible=false
 title.Position=UDim2.fromOffset(24,compact and 12 or 20);title.Size=UDim2.new(1,compact and -78 or -264,0,36);title.TextSize=compact and 21 or 24
 modeButton.Name="SwitchReservationMode";close.Name="ReservationClose"
 modeButton.AnchorPoint=Vector2.new(0,0)
 modeButton.Position=compact and UDim2.fromOffset(24,52) or UDim2.new(1,-232,0,18)
 modeButton.Size=UDim2.fromOffset(compact and 146 or 176,44);modeButton.TextSize=13
 modeButton.TextXAlignment=Enum.TextXAlignment.Center;modeButton.BackgroundColor3=C.Dark
 modeButton.BackgroundTransparency=0;modeButton.TextColor3=C.Ink;corner(modeButton,6)
 close.AnchorPoint=Vector2.new(0,0)
 close.Position=UDim2.new(1,-56,0,compact and 8 or 16);close.Size=UDim2.fromOffset(44,44)
 for _,child in ipairs(window:GetChildren())do if child:IsA("Frame") and child.Size.Y.Offset==1 then
  child.Position=UDim2.fromOffset(24,header-16);child.Size=UDim2.new(1,-48,0,1);child.BackgroundTransparency=.6
 end end
 createView.Position=UDim2.fromOffset(24,header);createView.Size=UDim2.new(1,-48,0,height-header-24)
 createPaper.Size=UDim2.new(1,0,1,short and -56 or -124)
 nameCaption.Position=UDim2.new();nameCaption.Size=UDim2.new(1,0,0,20)
 nameInput.Position=UDim2.fromOffset(0,26);nameInput.Size=UDim2.new(1,0,0,44)
 capacityCaption.Position=UDim2.fromOffset(0,86);capacityCaption.Size=UDim2.new(1,0,0,20)
 three.Position=UDim2.fromOffset(0,112);four.Position=UDim2.new(.5,4,0,112)
 three.Size=UDim2.new(.5,-4,0,44);four.Size=three.Size
 accessCaption.Position=UDim2.fromOffset(0,174);accessCaption.Size=UDim2.new(1,0,0,20)
 public.Position=UDim2.fromOffset(0,200);invite.Position=UDim2.new(.5,4,0,200)
 public.Size=three.Size;invite.Size=three.Size;public.TextSize=compact and 11 or 13;invite.TextSize=public.TextSize
 hint.Position=UDim2.fromOffset(0,251);hint.Size=UDim2.new(1,0,0,24);hint.TextSize=11
 rulesButton.Position=UDim2.new(0,0,1,short and -44 or -112);rulesButton.Size=short and UDim2.new(.5,-4,0,44)or UDim2.new(1,0,0,54)
 create.AnchorPoint=Vector2.new(1,1);create.Position=UDim2.fromScale(1,1)
 create.Size=short and UDim2.new(.5,-4,0,44)or compact and UDim2.new(1,0,0,44)or UDim2.fromOffset(190,44)
 createNote.Visible=not compact and not short and not rulesView.Visible
 createNote.Position=UDim2.new(0,0,1,-44);createNote.Size=UDim2.new(1,-208,0,44)
 if not compact then
  -- Two deliberate groups replace the long row of unrelated fields.
  accessCaption.Position=UDim2.new(.5,8,0,86);accessCaption.Size=UDim2.new(.5,-8,0,20)
  capacityCaption.Size=UDim2.new(.5,-12,0,20)
  three.Position=UDim2.fromOffset(0,112);four.Position=UDim2.new(.25,2,0,112)
  public.Position=UDim2.new(.5,8,0,112);invite.Position=UDim2.new(.75,10,0,112)
  for _,b in ipairs({three,four,public,invite})do b.Size=UDim2.new(.25,-12,0,48);b.TextSize=14 end
  hint.Position=UDim2.fromOffset(0,174);hint.Size=UDim2.new(1,0,0,24);hint.TextSize=13
  createPaper.CanvasSize=UDim2.fromOffset(0,204)
 else createPaper.CanvasSize=UDim2.fromOffset(0,276)end
 rulesView.Size=UDim2.fromScale(1,1)
 rulesBack.Position=UDim2.new();rulesBack.Size=UDim2.fromOffset(78,44)
 rulesTitle.Position=UDim2.fromOffset(92,0);rulesTitle.Size=UDim2.new(1,-100,0,34)
 ruleGameplayButton.Position=UDim2.fromOffset(0,58);ruleGameplayButton.Size=UDim2.new(1,-8,0,48)
 rulesView.CanvasSize=UDim2.fromOffset(0,616)
 for index,caption in ipairs({modeCaption,discussionCaption,lapsCaption,extraCaption})do
  local column=(index-1)%2;local row=math.floor((index-1)/2)
  caption.Position=UDim2.new(column*.5,column*4,0,128+row*76);caption.Size=UDim2.new(.5,-8,0,18)
 end
 for index,b in ipairs({ruleModeButton,ruleDiscussionButton,ruleLapsButton,ruleExtraButton})do
  local column=(index-1)%2;local row=math.floor((index-1)/2)
  b.Position=UDim2.new(column*.5,column*4,0,150+row*76);b.Size=UDim2.new(.5,-8,0,44);b.TextSize=compact and 11 or 13;b.TextWrapped=true
 end
 themesCaption.Position=UDim2.fromOffset(0,290);themesCaption.Size=UDim2.new(1,-158,0,44);themesCaption.TextWrapped=true
 ruleAllButton.Position=UDim2.new(1,-150,0,290);ruleAllButton.Size=UDim2.fromOffset(58,44)
 ruleNoneButton.Position=UDim2.new(1,-84,0,290);ruleNoneButton.Size=UDim2.fromOffset(76,44);ruleNoneButton.TextSize=11
 rulesThemeCount.Position=UDim2.fromOffset(0,346);rulesThemeCount.Size=UDim2.new(1,-8,0,38);rulesThemeCount.TextSize=11;rulesThemeCount.TextWrapped=true
 themesScroll.Position=UDim2.fromOffset(0,398);themesScroll.Size=UDim2.new(1,-8,0,200)
 themeGrid.CellSize=UDim2.new(compact and .5 or 1/3,compact and -6 or -7,0,44)
 for _,view in pairs({findView,partyView})do
  view.Position=UDim2.fromOffset(24,header);view.Size=UDim2.new(1,-48,0,height-header-24)
 end
 if secondaryLayout then secondaryLayout(compact)end
end

resize()

---------------------------------------------------------------------
-- FIND VIEW
---------------------------------------------------------------------

findView =
	make(
		"ScrollingFrame",
		window,
		{
			Name =
			"FindView",
            BorderSizePixel=0,ScrollBarThickness=3,ClipsDescendants=true,CanvasSize=UDim2.fromOffset(0,300),

			Position =
			UDim2.fromOffset(
				28,
				92
			),

			Size =
			UDim2.new(
				1,
				-56,
				0,
				300
			),

			BackgroundTransparency =
			1,

			Visible =
			false,

			ZIndex =
			7,
		}
	)

local listPaper =
	frame(
		findView,
		{
			Size =
			UDim2.new(
				1,
				0,
				0,
				208
			),

			BackgroundColor3 =
			C.Paper,

			ZIndex =
			8,
		}
	)

corner(listPaper, 8)
premiumPanel(listPaper, false)

local list =
	make(
		"ScrollingFrame",
		listPaper,
		{
			Name =
			"PublicTables",

			Position =
			UDim2.fromOffset(
				14,
				10
			),

			Size =
			UDim2.new(
				1,
				-28,
				1,
				-20
			),

			BackgroundTransparency =
			1,

			BorderSizePixel =
			0,

			CanvasSize =
			UDim2.new(),

			AutomaticCanvasSize =
			Enum.AutomaticSize.Y,

			ScrollBarThickness =
			2,

			ScrollBarImageColor3 =
			C.InkFaint,

			ZIndex =
			9,
		}
	)

local listLayout =
	make(
		"UIListLayout",
		list,
		{
			SortOrder =
			Enum.SortOrder.LayoutOrder,

			Padding =
			UDim.new(0, 8),
		}
	)

local empty =
	label(
		listPaper,
		{
			Position =
			UDim2.fromOffset(
				20,
				0
			),

			Size =
			UDim2.new(
				1,
				-40,
				1,
				0
			),

			Text =
			"Открытых столов пока нет.",

			Font =
			FONT.Body,

			TextSize =
			13,

			TextColor3 =
			C.InkSoft,

			TextXAlignment =
			Enum.TextXAlignment.Center,

			Visible =
			false,

			ZIndex =
			10,
		}
	)

---------------------------------------------------------------------
-- JOIN BY CODE
---------------------------------------------------------------------

local codeCaption=label(
	findView,
	{
		Position =
			UDim2.fromOffset(
				0,
				228
			),

		Size =
			UDim2.fromOffset(
				50,
				39
			),

		Text =
			"Код",

		Font =
			FONT.Strong,

		TextSize =
			11,

		TextColor3 =
			C.Muted,

		ZIndex =
			8,
	}
)

local codeInput =
	make(
		"TextBox",
		findView,
		{
			Position =
			UDim2.fromOffset(
				55,
				228
			),

			Size =
			UDim2.fromOffset(
				150,
				39
			),

			BackgroundColor3 =
			C.Dark,

			BorderSizePixel =
			0,

			PlaceholderText =
			"ABCDE",

			PlaceholderColor3 =
			C.Muted,

			Text = "",

			TextColor3 =
			C.Ivory,

			Font =
			FONT.Strong,

			TextSize =
			12,

			ClearTextOnFocus =
			false,

			TextXAlignment =
			Enum.TextXAlignment.Center,

			ZIndex =
			9,
		}
	)

corner(codeInput, 7)
stroke(codeInput, C.Line, 0.20, 1.2)

local codeJoin =
	button(
		findView,
		{
			Position =
			UDim2.fromOffset(
				214,
				228
			),

			Size =
			UDim2.fromOffset(
				90,
				39
			),

			BackgroundColor3 =
			C.Dark,

			Text =
			"Войти",

			TextColor3 =
			C.Ivory,

			Font =
			FONT.Strong,

			TextSize =
			11,

			ZIndex =
			9,
		}
	)

corner(codeJoin, 5)

tactile(
	codeJoin,
	C.Dark,
	C.DarkHover,
	C.DarkPressed
)

local status =
	label(
		findView,
		{
			AnchorPoint =
			Vector2.new(
				1,
				0
			),

			Position =
			UDim2.new(
				1,
				0,
				0,
				228
			),

			Size =
			UDim2.fromOffset(
				235,
				39
			),

			Text = "",

			Font =
			FONT.Body,

			TextSize =
			10,

			TextColor3 =
			C.Muted,

			TextXAlignment =
			Enum.TextXAlignment.Right,

			ZIndex =
			8,
		}
	)

---------------------------------------------------------------------
-- PARTY VIEW
---------------------------------------------------------------------

partyView =
	make(
		"ScrollingFrame",
		window,
		{
			Name =
			"PartyView",
            BorderSizePixel=0,ScrollBarThickness=3,ClipsDescendants=true,CanvasSize=UDim2.fromOffset(0,300),

			Position =
			UDim2.fromOffset(
				28,
				92
			),

			Size =
			UDim2.new(
				1,
				-56,
				0,
				300
			),

			BackgroundTransparency =
			1,

			Visible =
			false,

			ZIndex =
			11,
		}
	)

local partyPaper =
	frame(
		partyView,
		{
			Size =
			UDim2.new(
				1,
				0,
				0,
				228
			),

			BackgroundColor3 =
			C.Paper,

			ZIndex =
			12,
		}
	)

corner(partyPaper, 8)
premiumPanel(partyPaper, true)

---------------------------------------------------------------------
-- PARTY SIDE
---------------------------------------------------------------------

local partySide =
	frame(
		partyPaper,
		{
			Size =
			UDim2.fromOffset(
				118,
				228
			),

			BackgroundColor3 =
			C.PaperSide,

			ZIndex =
			13,
		}
	)

corner(partySide, 8)
premiumPanel(partySide, false)

local partyCount =
	label(
		partySide,
		{
			Position =
			UDim2.fromOffset(
				0,
				38
			),

			Size =
			UDim2.new(
				1,
				0,
				0,
				52
			),

			Text =
			"1 / 3",

			Font =
			FONT.Title,

			TextSize =
			27,

			TextColor3 =
			C.Ink,

			TextXAlignment =
			Enum.TextXAlignment.Center,

			ZIndex =
			14,
		}
	)

local partyPlayersCaption=label(
	partySide,
	{
		Position =
			UDim2.fromOffset(
				0,
				88
			),

		Size =
			UDim2.new(
				1,
				0,
				0,
				20
			),

		Text =
			"игроков",

		Font =
			FONT.Body,

		TextSize =
			10,

		TextColor3 =
			C.InkSoft,

		TextXAlignment =
			Enum.TextXAlignment.Center,

		ZIndex =
			14,
	}
)

local partyDivider=frame(
	partySide,
	{
		Position =
			UDim2.fromOffset(
				20,
				128
			),

		Size =
			UDim2.new(
				1,
				-40,
				0,
				1
			),

		BackgroundColor3 =
			C.Brass,

		ZIndex =
			14,
	}
)

local partyAccess =
	label(
		partySide,
		{
			Position =
			UDim2.fromOffset(
				10,
				140
			),

			Size =
			UDim2.new(
				1,
				-20,
				0,
				35
			),

			Text =
			"Открытый",

			Font =
			FONT.Strong,

			TextSize =
			10,

			TextColor3 =
			C.InkSoft,

			TextWrapped =
			true,

			TextXAlignment =
			Enum.TextXAlignment.Center,

			ZIndex =
			14,
		}
	)

local partyCode =
	label(
		partySide,
		{
			Position =
			UDim2.fromOffset(
				8,
				181
			),

			Size =
			UDim2.new(
				1,
				-16,
				0,
				25
			),

			Text =
			"ABCDE",

			Font =
			FONT.Strong,

			TextSize =
			12,

			TextColor3 =
			C.Brass,

			TextXAlignment =
			Enum.TextXAlignment.Center,

			Visible =
			false,

			ZIndex =
			14,
		}
	)

---------------------------------------------------------------------
-- MEMBERS
---------------------------------------------------------------------

local partyContent =
	frame(
		partyPaper,
		{
			Position =
			UDim2.fromOffset(
				145,
				0
			),

			Size =
			UDim2.new(
				1,
				-170,
				1,
				0
			),

			BackgroundTransparency =
			1,

			ZIndex =
			13,
		}
	)

local membersCaption=label(
	partyContent,
	{
		Position =
			UDim2.fromOffset(
				0,
				13
			),

		Size =
			UDim2.new(
				1,
				0,
				0,
				25
			),

		Text =
			"Участники",

		Font =
			FONT.Strong,

		TextSize =
			13,

		TextColor3 =
			C.Ink,

		ZIndex =
			14,
	}
)

local membersHolder =
	frame(
		partyContent,
		{
			Position =
			UDim2.fromOffset(
				0,
				43
			),

			Size =
			UDim2.new(
				1,
				0,
				0,
				172
			),

			BackgroundTransparency =
			1,

			ZIndex =
			14,
		}
	)

---------------------------------------------------------------------
-- PARTY FOOTER
---------------------------------------------------------------------

local leaveButton =
	button(
		partyView,
		{
			Position =
			UDim2.fromOffset(
				0,
				246
			),

			Size =
			UDim2.fromOffset(
				150,
				40
			),

			BackgroundColor3 =
			C.Dark,

			Text =
			"Выйти",

			TextColor3 =
			C.Muted,

			Font =
			FONT.Strong,

			TextSize =
			11,

			ZIndex =
			13,
		}
	)

corner(leaveButton, 5)

tactile(
	leaveButton,
	C.Dark,
	C.DarkHover,
	C.DarkPressed
)

local partyStatus =
	label(
		partyView,
		{
			Position =
			UDim2.fromOffset(
				165,
				246
			),

			Size =
			UDim2.new(
				1,
				-405,
				0,
				40
			),

			Text = "",

			Font =
			FONT.Body,

			TextSize =
			10,

			TextColor3 =
			C.Muted,

			TextXAlignment =
			Enum.TextXAlignment.Center,

			ZIndex =
			13,
		}
	)

local startButton =
	button(
		partyView,
		{
			AnchorPoint =
			Vector2.new(
				1,
				0
			),

			Position =
			UDim2.new(
				1,
				0,
				0,
				246
			),

			Size =
			UDim2.fromOffset(
				205,
				40
			),

			BackgroundColor3 =
			C.Paper,

			Text =
			"Нужно 3 игрока",

			TextColor3 =
			C.InkSoft,

			Font =
			FONT.Strong,

			TextSize =
			11,

			ZIndex =
			13,
		}
	)

corner(startButton, 5)

-- Reflow the browser and party content itself, not just its scrolling viewport.
secondaryLayout=function(compact)
 codeInput.Name="TableCodeInput";codeJoin.Name="JoinByCode"
 codeCaption.Position=UDim2.fromOffset(0,224);codeCaption.Size=UDim2.fromOffset(38,44)
 codeInput.Position=UDim2.fromOffset(compact and 46 or 55,224)
 codeInput.Size=compact and UDim2.new(1,-138,0,44)or UDim2.fromOffset(150,44)
 codeJoin.Position=compact and UDim2.new(1,-84,0,224)or UDim2.fromOffset(214,224)
 codeJoin.Size=UDim2.fromOffset(compact and 84 or 90,44)
 status.Position=compact and UDim2.fromOffset(0,276)or UDim2.new(1,0,0,224)
 status.AnchorPoint=compact and Vector2.new()or Vector2.new(1,0)
 status.Size=compact and UDim2.new(1,0,0,36)or UDim2.fromOffset(235,44)
 status.TextWrapped=true;findView.CanvasSize=UDim2.fromOffset(0,compact and 324 or 300)
 partyPaper.Name="PartyPaper";partyContent.Name="PartyMembers";leaveButton.Name="LeaveParty";startButton.Name="StartParty"
 partyPaper.Size=UDim2.new(1,0,0,compact and 322 or 228)
 partySide.Size=compact and UDim2.new(1,0,0,78)or UDim2.fromOffset(118,228)
 partyCount.Position=UDim2.fromOffset(compact and 12 or 0,compact and 6 or 38)
 partyCount.Size=compact and UDim2.fromOffset(70,44)or UDim2.new(1,0,0,52)
 partyPlayersCaption.Position=UDim2.fromOffset(compact and 12 or 0,compact and 49 or 88)
 partyPlayersCaption.Size=compact and UDim2.fromOffset(70,20)or UDim2.new(1,0,0,20)
 partyDivider.Visible=not compact
 partyAccess.Position=UDim2.fromOffset(compact and 96 or 10,compact and 6 or 140)
 partyAccess.Size=compact and UDim2.new(1,-108,0,32)or UDim2.new(1,-20,0,35)
 partyCode.Position=UDim2.fromOffset(compact and 96 or 8,compact and 44 or 181)
 partyCode.Size=UDim2.new(1,compact and -108 or -16,0,25)
 partyContent.Position=UDim2.fromOffset(compact and 12 or 145,compact and 90 or 0)
 partyContent.Size=compact and UDim2.new(1,-24,0,226)or UDim2.new(1,-170,1,0)
 membersCaption.Position=UDim2.fromOffset(0,compact and 4 or 8)
 membersHolder.Position=UDim2.fromOffset(0,compact and 36 or 40)
 membersHolder.Size=UDim2.new(1,0,0,184)
 leaveButton.Position=UDim2.fromOffset(0,compact and 332 or 246)
 leaveButton.Size=compact and UDim2.new(.5,-4,0,44)or UDim2.fromOffset(150,44)
 startButton.Position=UDim2.new(1,0,0,compact and 332 or 246)
 startButton.Size=compact and UDim2.new(.5,-4,0,44)or UDim2.fromOffset(205,44)
 partyStatus.Position=compact and UDim2.fromOffset(0,384)or UDim2.fromOffset(165,246)
 partyStatus.Size=compact and UDim2.new(1,0,0,36)or UDim2.new(1,-405,0,44)
 partyStatus.TextWrapped=true;partyView.CanvasSize=UDim2.fromOffset(0,compact and 432 or 300)
end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

local selectedCapacity = 3
local selectedVisibility = "public"
local selectedRuleThemes = {}
for _, theme in ipairs(RULE_THEME_CHOICES) do selectedRuleThemes[theme.id] = true end
local selectedTopicMode = "vote"
local selectedGameMode = "classic"
local selectedAllowExtraRound = true
local selectedDiscussionSeconds = 30
local selectedHintLaps = 1
local discussionChoices = {20,30,45,60}

local currentParty = nil

local visible = false
local busy = false

local mode = "create"

local browserToken = 0

local thumbnailCache = {}

local renderParty

---------------------------------------------------------------------
-- CREATE SELECTION
---------------------------------------------------------------------

local function refreshSelection()
	local threeSelected =
		selectedCapacity == 3

	three.BackgroundColor3 =
		threeSelected
		and C.Selected
		or C.PaperSide

	three.TextColor3 =
		threeSelected
		and C.Ivory
		or C.InkSoft

	four.BackgroundColor3 =
		not threeSelected
		and C.Selected
		or C.PaperSide

	four.TextColor3 =
		not threeSelected
		and C.Ivory
		or C.InkSoft

	local publicSelected =
		selectedVisibility
		== "public"

	public.BackgroundColor3 =
		publicSelected
		and C.Selected
		or C.PaperSide

	public.TextColor3 =
		publicSelected
		and C.Ivory
		or C.InkSoft

	invite.BackgroundColor3 =
		not publicSelected
		and C.Selected
		or C.PaperSide

	invite.TextColor3 =
		not publicSelected
		and C.Ivory
		or C.InkSoft

	summaryCount.Text =
		tostring(
			selectedCapacity
		)

	summaryAccess.Text =
		publicSelected
		and "Открытый"
		or "По приглашению"

	hint.Text =
		publicSelected
		and "Другие игроки увидят стол."
		or "Войти можно будет по коду."
end

local function selectedThemeIds()
	local ids = {}
	for _, theme in ipairs(RULE_THEME_CHOICES) do
		if selectedRuleThemes[theme.id] then ids[#ids+1] = theme.id end
	end
	return ids
end

local function rulePayload()
	return {
		allowedThemes = selectedThemeIds(),
		topicMode = selectedTopicMode,
		allowExtraRound = selectedAllowExtraRound,
		discussionSeconds = selectedDiscussionSeconds,
		hintLaps = selectedHintLaps,
		hintSeconds = fixedHintSeconds,
		mode = selectedGameMode,
	}
end

local function refreshRules()
	local ids = selectedThemeIds()
	rulesButton.Text = "Правила матча · " .. tostring(#ids) .. " тем · ход " .. tostring(fixedHintSeconds) .. "с →"
	rulesThemeCount.Text = #ids == 1 and "Одна тема — матч начнётся с неё сразу." or (#ids == 0 and "Выбери хотя бы одну тему." or ("Выбрано " .. tostring(#ids) .. " из " .. tostring(#RULE_THEME_CHOICES) .. " · можно выбрать несколько"))
	ruleModeButton.Text = selectedTopicMode == "vote" and "Голосование" or "Случайная тема"
	local lang=player:GetAttribute("SpyLanguage") or "ru"
	local names={ru={"Классика","Тайная встреча"},en={"Classic","Secret meeting"},zh={"经典模式","秘密会面"}}
	ruleGameplayButton:SetAttribute("SpyUserText",true)
	ruleGameplayButton.Text=names[lang]and names[lang][selectedGameMode=="case"and 2 or 1]or names.ru[selectedGameMode=="case"and 2 or 1]
	ruleExtraButton.Text = selectedAllowExtraRound and "Разрешён" or "Выключен"
	ruleDiscussionButton.Text = tostring(selectedDiscussionSeconds) .. " секунд"
	ruleLapsButton.Text = tostring(selectedHintLaps) .. (selectedHintLaps == 1 and " круг" or " круга")
	for _, theme in ipairs(RULE_THEME_CHOICES) do
		local b = ruleThemeButtons[theme.id]
		local active = selectedRuleThemes[theme.id] == true
		b.BackgroundColor3 = active and C.Selected or C.PaperSide
		b.TextColor3 = active and C.Ivory or C.InkSoft
	end
end

local function openRulesEditor()
	createPaper.Visible = false
	create.Visible = false
	rulesButton.Visible = false
	rulesView.Visible = true
	createNote.Visible = false
	resize()
	refreshRules()
end

local function closeRulesEditor()
	rulesView.Visible = false
	createPaper.Visible = true
	create.Visible = true
	rulesButton.Visible = true
	createNote.Visible = true
	resize()
end

rulesButton.Activated:Connect(openRulesEditor)
rulesBack.Activated:Connect(closeRulesEditor)
ruleGameplayButton.Activated:Connect(function()selectedGameMode=selectedGameMode=="classic"and"case"or"classic";refreshRules()end)
player:GetAttributeChangedSignal("SpyLanguage"):Connect(refreshRules)
ruleModeButton.Activated:Connect(function() selectedTopicMode = selectedTopicMode == "vote" and "random" or "vote"; refreshRules() end)
ruleExtraButton.Activated:Connect(function() selectedAllowExtraRound = not selectedAllowExtraRound; refreshRules() end)
ruleLapsButton.Activated:Connect(function() selectedHintLaps = selectedHintLaps == 1 and 2 or 1; refreshRules() end)
ruleDiscussionButton.Activated:Connect(function()
	local at = table.find(discussionChoices, selectedDiscussionSeconds) or 2
	selectedDiscussionSeconds = discussionChoices[(at % #discussionChoices) + 1]
	refreshRules()
end)
ruleAllButton.Activated:Connect(function() for _,theme in ipairs(RULE_THEME_CHOICES) do selectedRuleThemes[theme.id]=true end; refreshRules() end)
ruleNoneButton.Activated:Connect(function() for _,theme in ipairs(RULE_THEME_CHOICES) do selectedRuleThemes[theme.id]=false end; refreshRules() end)
for _,theme in ipairs(RULE_THEME_CHOICES) do
	ruleThemeButtons[theme.id].Activated:Connect(function()
		selectedRuleThemes[theme.id] = not selectedRuleThemes[theme.id]
		refreshRules()
	end)
end

three.Activated:Connect(function()
	selectedCapacity = 3
	refreshSelection()
end)

four.Activated:Connect(function()
	selectedCapacity = 4
	refreshSelection()
end)

public.Activated:Connect(function()
	selectedVisibility = "public"
	refreshSelection()
end)

invite.Activated:Connect(function()
	selectedVisibility = "invite"
	refreshSelection()
end)

---------------------------------------------------------------------
-- PUBLIC LIST
---------------------------------------------------------------------

local function clearList()
	for _, child in ipairs(
		list:GetChildren()
		) do
		if child ~= listLayout then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------
-- JOIN
---------------------------------------------------------------------

local function joinCode(code)
	if busy then
		return
	end

	busy = true

	status.Text =
		"Подключаем..."

	local ok, result =
		pcall(function()
			return request:
			InvokeServer(
				"JoinByCode",
				code
			)
		end)

	busy = false

	if not ok
		or not result
		or not result.ok
	then
		local reason =
			result
			and result.code

		if reason == "party_full" then
			status.Text =
				"Стол заполнен"

		elseif reason == "party_locked" then
			status.Text =
				"Игра уже начинается"

		else
			status.Text =
				"Стол не найден"
		end

		return
	end

	status.Text = ""

	renderParty(
		result.party
	)
end

---------------------------------------------------------------------
-- PARTY ROW
---------------------------------------------------------------------

local function partyRow(
	data,
	order
)
	local row =
		frame(
			list,
			{
				Size =
				UDim2.new(
					1,
					-4,
					0,
					60
				),

				BackgroundColor3 =
				C.PaperSide,

				BackgroundTransparency =
				0.18,

				LayoutOrder =
				order,

				ZIndex =
				10,
			}
		)

	corner(row, 6)
	stroke(row, C.Line, 0.58, 1)

	label(
		row,
		{
			Position =
				UDim2.fromOffset(
					5,
					5
				),

			Size =
				UDim2.new(
					1,
					-190,
					0,
					23
				),

			Text =
				tostring(
					data.name
					or "Стол"
				),

			Font =
				FONT.Strong,

			TextSize =
				12,

			TextColor3 =
				C.Ink,

			TextTruncate =
				Enum.TextTruncate.AtEnd,

			ZIndex =
				11,
		}
	)

	label(
		row,
		{
			Position =
				UDim2.fromOffset(
					5,
					28
				),

			Size =
				UDim2.new(
					1,
					-190,
					0,
					20
				),

			Text =
				tostring(
					data.ownerName
					or ""
				)
				.. "  ·  "
				.. tostring(
					data.count
					or 0
				)
				.. "/"
				.. tostring(
					data.capacity
					or 4
				),

			Font =
				FONT.Body,

			TextSize =
				10,

			TextColor3 =
				C.InkSoft,

			ZIndex =
				11,
		}
	)

	local join =
		button(
			row,
			{
				AnchorPoint =
				Vector2.new(
					1,
					0.5
				),

				Position =
				UDim2.new(
					1,
					-5,
					0.5,
					0
				),

				Size =
				UDim2.fromOffset(
					76,
					32
				),

				BackgroundColor3 =
				C.Selected,

				Text =
				"Войти",

				TextColor3 =
				C.Ivory,

				Font =
				FONT.Strong,

				TextSize =
				10,

				ZIndex =
				11,
			}
		)

	corner(join, 4)

	tactile(
		join,
		C.Selected,
		C.SelectedHover,
		C.SelectedPressed
	)

	frame(
		row,
		{
			AnchorPoint =
				Vector2.new(
					0,
					1
				),

			Position =
				UDim2.new(
					0,
					5,
					1,
					0
				),

			Size =
				UDim2.new(
					1,
					-10,
					0,
					1
				),

			BackgroundColor3 =
				C.InkFaint,

			BackgroundTransparency =
				0.73,

			ZIndex =
				10,
		}
	)

	join.Activated:Connect(function()
		joinCode(
			data.code
		)
	end)
end

---------------------------------------------------------------------
-- REFRESH PUBLIC
---------------------------------------------------------------------

local function refreshPublic()
	if not visible
		or currentParty
		or mode ~= "find"
	then
		return
	end

	local ok, result =
		pcall(function()
			return request:
			InvokeServer(
				"ListPublic"
			)
		end)

	if not ok
		or not result
		or not result.ok
	then
		status.Text =
			"Не удалось обновить"

		return
	end

	status.Text = ""

	clearList()

	local parties =
		result.parties
		or {}

	empty.Visible =
		#parties == 0

	for index, data in ipairs(
		parties
		) do
		partyRow(
			data,
			index
		)
	end
end

local function startBrowser()
	browserToken += 1

	local token =
		browserToken

	task.spawn(function()
		while visible
			and not currentParty
			and mode == "find"
			and token == browserToken
		do
			refreshPublic()

			task.wait(2.5)
		end
	end)
end

---------------------------------------------------------------------
-- MODE
---------------------------------------------------------------------

local function setMode(newMode)
	if currentParty then
		return
	end

	mode =
		newMode

	if rulesView.Visible then
		closeRulesEditor()
	end

	if mode == "find" then
		createView.Visible =
			false

		findView.Visible =
			true

		partyView.Visible =
			false

		title.Text =
			"Найти стол"

		modeButton.Text =
			"Создать стол"

		startBrowser()
	else
		browserToken += 1

		createView.Visible =
			true

		findView.Visible =
			false

		partyView.Visible =
			false

		title.Text =
			"Создать стол"

		modeButton.Text =
			"Найти стол"
	end
	resize()
end

modeButton.Activated:Connect(function()
	if currentParty then
		return
	end

	setMode(
		mode == "create"
			and "find"
			or "create"
	)
end)

---------------------------------------------------------------------
-- MEMBERS
---------------------------------------------------------------------

local function clearMembers()
	for _, child in ipairs(
		membersHolder:GetChildren()
		) do
		child:Destroy()
	end
end

local function avatarFor(
	userId,
	image
)
	if thumbnailCache[userId] then
		image.Image =
			thumbnailCache[userId]

		return
	end

	task.spawn(function()
		local ok, content =
			pcall(function()
				local imageUrl =
				Players:
				GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)

				return imageUrl
			end)

		if not ok
			or not content
		then
			return
		end

		thumbnailCache[userId] =
			content

		if image.Parent then
			image.Image =
				content
		end
	end)
end

local function renderMembers(party)
	clearMembers()

	local localIsOwner =
		party.ownerId
		== player.UserId

	for index, member in ipairs(
		party.members
			or {}
		) do
		local row =
			frame(
				membersHolder,
				{
					Position =
					UDim2.fromOffset(
						0,
						(index - 1) * 46
					),

					Size =
					UDim2.new(
						1,
						0,
						0,
						44
					),

					BackgroundTransparency =
					1,

					ZIndex =
					15,
				}
			)

		local avatar =
			make(
				"ImageLabel",
				row,
				{
					Position =
					UDim2.fromOffset(
						0,
						4
					),

					Size =
					UDim2.fromOffset(
						30,
						30
					),

					BackgroundColor3 =
					C.PaperSide,

					BorderSizePixel =
					0,

					Image = "",

					ZIndex =
					16,
				}
			)

		corner(
			avatar,
			15
		)

		avatarFor(
			member.userId,
			avatar
		)

		local isOwner =
			member.userId
			== party.ownerId

		local suffix =
			isOwner
			and (player:GetAttribute("SpyLanguage")=="zh"and "  ·  房主"or player:GetAttribute("SpyLanguage")=="en"and "  ·  Host"or "  ·  Хост")
			or ""

		label(
			row,
			{
                Name="ParticipantName",
				Position =
					UDim2.fromOffset(
						41,
						0
					),

				Size =
					UDim2.new(
						1,
						-105,
						1,
						0
					),

				Text =
					tostring(
						member.name
						or member.username
						or "Игрок"
					)
					.. suffix,

				Font =
					isOwner
					and FONT.Strong
					or FONT.Body,

				TextSize =
					11,

				TextColor3 =
					isOwner
					and C.Ink
					or C.InkSoft,

				TextTruncate =
					Enum.TextTruncate.AtEnd,

				ZIndex =
					16,
			}
		)

		-------------------------------------------------------------
		-- HOST CAN KICK
		-------------------------------------------------------------

		if localIsOwner
			and member.userId
			~= player.UserId
		then
			local kick =
				button(
					row,
					{
                        Name="KickMember_"..tostring(member.userId),
						AnchorPoint =
						Vector2.new(
							1,
							0.5
						),

						Position =
						UDim2.new(
							1,
							0,
							0.5,
							0
						),

						Size =
						UDim2.fromOffset(
							64,
							44
						),

						BackgroundColor3 =
						C.Danger,

						Text =
						"Убрать",

						TextColor3 =
						C.InkSoft,

						Font =
						FONT.Strong,

						TextSize =
						9,

						ZIndex =
						17,
					}
				)

			corner(
				kick,
				4
			)

			kick.MouseEnter:Connect(function()
				tween(
					kick,
					T.Fast,
					{
						BackgroundColor3 =
							C.DangerHover,
					}
				)
			end)

			kick.MouseLeave:Connect(function()
				tween(
					kick,
					T.Fast,
					{
						BackgroundColor3 =
							C.Danger,
					}
				)
			end)

			kick.Activated:Connect(function()
				if busy then
					return
				end

				busy = true

				local ok, result =
					pcall(function()
						return request:
						InvokeServer(
							"Kick",
							member.userId
						)
					end)

				busy = false

				if ok
					and result
					and result.ok
				then
					renderParty(
						result.party
					)
				end
			end)
		end
	end
end

---------------------------------------------------------------------
-- RENDER PARTY
---------------------------------------------------------------------

renderParty = function(party)
	currentParty =
		party
    title:SetAttribute("SpyUserText",party~=nil)

	if not party then
		partyView.Visible =
			false

		modeButton.Visible =
			true

		setMode(mode)

		return
	end

	browserToken += 1
	if rulesView.Visible then closeRulesEditor() end

	createView.Visible =
		false

	findView.Visible =
		false

	partyView.Visible =
		true
	resize()

	modeButton.Visible =
		false

	title.Text =
		tostring(
			party.name
			or "Ваш стол"
		)

	partyCount.Text =
		tostring(
			party.count
			or 1
		)
		.. " / "
		.. tostring(
			party.capacity
			or 4
		)

	local private =
		party.visibility
		== "invite"

	partyAccess.Text =
		private
		and "По приглашению"
		or "Открытый"

	partyCode.Visible =
		private

	if private then
		partyCode.Text =
			tostring(
				party.code
				or ""
			)
	end

	renderMembers(party)

	-----------------------------------------------------------------
	-- START BUTTON
	-----------------------------------------------------------------

	local localIsOwner =
		party.ownerId
		== player.UserId

	if localIsOwner then
		startButton.Visible =
			true

		partyStatus.Text =
			""

		if (party.count or 0) >= 3 then
			startButton.Text =
				"Начать игру"

			startButton.BackgroundColor3 =
				C.Brass

			startButton.TextColor3 =
				C.Shell
		else
			local missing =
				3
			- (party.count or 0)

			if missing == 1 then
				startButton.Text =
					"Нужен ещё 1 игрок"
			else
				startButton.Text =
					"Нужно ещё "
					.. tostring(
						missing
					)
			end

			startButton.BackgroundColor3 =
				C.Dark

			startButton.TextColor3 =
				C.Muted
		end
	else
		startButton.Visible =
			false

		partyStatus.Text =
			"Ждём, когда хост начнёт игру"
	end
end

---------------------------------------------------------------------
-- CREATE
---------------------------------------------------------------------

create.Activated:Connect(function()
	if busy then
		return
	end

	if #selectedThemeIds() == 0 then
		hint.Text = "Выбери хотя бы одну тему в правилах."
		openRulesEditor()
		return
	end

	busy = true

	create.Text =
		"Создаём..."

	local ok, result =
		pcall(function()
			return request:
			InvokeServer(
				"Create",
				{
					name =
					nameInput.Text,

					capacity =
					selectedCapacity,

					visibility =
					selectedVisibility,

					rules =
						rulePayload(),
				}
			)
		end)

	busy = false

	create.Text =
		"Создать стол"

	if not ok
		or not result
		or not result.ok
	then
		hint.Text = "Не удалось создать стол. Попробуй ещё раз."
		return
	end

	nameInput.Text = ""

	renderParty(
		result.party
	)
end)

---------------------------------------------------------------------
-- PRIVATE CODE
---------------------------------------------------------------------

local function submitCode()
	local code =
		string.upper(
			(
				codeInput.Text
				or ""
			):
			gsub(
				"%s+",
				""
			)
		)

	if code == "" then
		status.Text =
			"Введите код"

		return
	end

	codeInput.Text =
		code

	joinCode(code)
end

codeJoin.Activated:Connect(
	submitCode
)

codeInput.FocusLost:Connect(function(
	enterPressed
)
	if enterPressed then
		submitCode()
	end
end)

---------------------------------------------------------------------
-- LEAVE PARTY
---------------------------------------------------------------------

leaveButton.Activated:Connect(function()
	if busy then
		return
	end

	busy = true

	leaveButton.Text =
		"Выходим..."

	local ok, result =
		pcall(function()
			return request:
			InvokeServer(
				"Leave"
			)
		end)

	busy = false

	leaveButton.Text =
		"Выйти"

	if ok
		and result
		and result.ok
	then
		currentParty =
			nil

		mode =
			"create"

		renderParty(nil)
	end
end)

---------------------------------------------------------------------
-- START PARTY
---------------------------------------------------------------------

startButton.Activated:Connect(function()
	if busy
		or not currentParty
	then
		return
	end

	if currentParty.ownerId
		~= player.UserId
	then
		return
	end

	if (currentParty.count or 0) < 3 then
		return
	end

	busy = true

	startButton.Text =
		"Запускаем..."

	local ok, result =
		pcall(function()
			return request:
			InvokeServer(
				"Start"
			)
		end)

	busy = false

	if not ok
		or not result
		or not result.ok
	then
		if result
			and result.code
			== "match_not_connected"
		then
			partyStatus.Text =
				"Матчевая комната пока не подключена"
        elseif result and result.code=="studio_teleport" then
            partyStatus.Text="Переход доступен в опубликованной игре Roblox"
        elseif result and result.code=="profile_busy" then
            partyStatus.Text="Сохраняем данные игроков. Попробуй через пару секунд"
		else
			partyStatus.Text =
				"Не удалось запустить"
		end

		startButton.Text =
			"Начать игру"

		return
	end
end)

---------------------------------------------------------------------
-- SERVER UPDATE
---------------------------------------------------------------------

update.OnClientEvent:Connect(function(
	party,
	reason
)
	if not party then
		currentParty =
			nil

		if reason == "kicked" then
			mode =
				"find"

			status.Text =
				"Вас исключили из лобби"
		else
			mode =
				"create"
		end

		if visible then
			renderParty(nil)
		end

		return
	end

	renderParty(
		party
	)
end)

---------------------------------------------------------------------
-- OPEN
---------------------------------------------------------------------

local function openWindow()
	if visible then
		return
	end

	visible = true

	shade.Visible =
		true

	window.Visible =
		true

	shade.BackgroundTransparency =
		1

	window.GroupTransparency =
		1

	resize()

	local finalScale =
		windowScale.Scale

	windowScale.Scale =
		finalScale * 0.94

	refreshSelection()

	renderParty(
		currentParty
	)

	tween(
		shade,
		T.Normal,
		{
			BackgroundTransparency =
				0.84,
		}
	)

	tween(
		window,
		T.Normal,
		{
			GroupTransparency =
				0,
		}
	)

	tween(
		windowScale,
		T.Normal,
		{
			Scale =
				finalScale,
		}
	)

	if mode == "find"
		and not currentParty
	then
		startBrowser()
	end
end

---------------------------------------------------------------------
-- CLOSE
---------------------------------------------------------------------

local function closeWindow()
	if not visible then
		return
	end

	visible =
		false

	browserToken += 1

	tween(
		shade,
		T.Close,
		{
			BackgroundTransparency =
				1,
		}
	)

	tween(
		window,
		T.Close,
		{
			GroupTransparency =
				1,
		}
	)

	local currentScale =
		windowScale.Scale

	local closing =
		tween(
			windowScale,
			T.Close,
			{
				Scale =
				currentScale * 0.98,
			}
		)

	if closing then
		closing.Completed:Once(function()
			if not visible then
				window.Visible =
					false

				shade.Visible =
					false

				resize()
			end
		end)
	end
end

---------------------------------------------------------------------
-- RESTORE EXISTING PARTY
---------------------------------------------------------------------

task.spawn(function()
	local ok, result =
		pcall(function()
			return request:
			InvokeServer(
				"Get"
			)
		end)

	if ok
		and result
		and result.ok
	then
		currentParty =
			result.party
	end
end)

---------------------------------------------------------------------
-- CONNECTIONS
---------------------------------------------------------------------

do
 local manual=playerGui:FindFirstChild("SpyOpenManualTable")or Instance.new("BindableEvent")
 manual.Name="SpyOpenManualTable";manual.Parent=playerGui;manual.Event:Connect(openWindow)
 mainAction.Activated:Connect(function()
  local quick=playerGui:FindFirstChild("SpyOpenQuickPlay")
  if quick and not currentParty then quick:Fire()else openWindow()end
 end)
end

close.Activated:Connect(
	closeWindow
)

shade.Activated:Connect(
	closeWindow
)

---------------------------------------------------------------------
-- INITIAL
---------------------------------------------------------------------

refreshSelection()
refreshRules()
