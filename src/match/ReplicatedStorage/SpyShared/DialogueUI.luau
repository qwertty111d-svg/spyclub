-- ReplicatedStorage > SpyShared > DialogueUI
-- ПОЛНАЯ ЗАМЕНА
--
-- Совместим с текущим SpyClient:
--   local DialogueUI = require(SpyShared.DialogueUI)
--   dialogue = DialogueUI.create(ctx, onTalked)
--   dialogue:open("start")

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ClubJournalUI = require(script.Parent:WaitForChild("ClubJournalUI"))
local Catalog = require(script.Parent:WaitForChild("Catalog"))
local Preview3D = require(script.Parent:WaitForChild("Preview3D"))

local DialogueUI = {}

local SHADE_TRANSPARENCY = 0.94

local FONT = {
	Display = Enum.Font.Garamond,
	Strong = Enum.Font.BuilderSansBold,
	Body = Enum.Font.BuilderSansMedium,
	Meta = Enum.Font.BuilderSansMedium,
}

local C = {
	Shade = Color3.fromRGB(16,17,20),
	Shell = Color3.fromRGB(26,27,31),
	Rail = Color3.fromRGB(31,32,36),
	Raised = Color3.fromRGB(49,50,56),
	Hover = Color3.fromRGB(57,59,63),
	Pressed = Color3.fromRGB(34,36,40),

	Ivory = Color3.fromRGB(245,245,247),
	Text = Color3.fromRGB(245,245,247),
	Muted = Color3.fromRGB(168,170,179),
	Dim = Color3.fromRGB(147,149,157),

	Gold = Color3.fromRGB(238,238,241),
	GoldBright = Color3.fromRGB(255,255,255),
	GoldDark = Color3.fromRGB(224,225,230),
	Line = Color3.fromRGB(111,113,122),

	Success = Color3.fromRGB(118, 171, 124),
	Shadow = Color3.fromRGB(0, 0, 0),
}

local MOTION = {
	Fast = TweenInfo.new(0.10, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Hover = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Open = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
	Content = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

local function make(className, parent, props)
	local object = Instance.new(className)

	for key, value in pairs(props or {}) do
		object[key] = value
	end

	object.Parent = parent
	return object
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
	props.TextColor3 = props.TextColor3 or C.Text
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	return make("TextLabel", parent, props)
end

local function button(parent, props)
	props = props or {}
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	return make("TextButton", parent, props)
end

local function corner(parent, radius)
 radius=math.min(radius or 2,3)
	return make("UICorner", parent, {
		CornerRadius = UDim.new(0, radius),
	})
end

local function stroke(parent, color, transparency, thickness)
	return make("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	})
end

local function scale(parent, value)
	return make("UIScale", parent, {
		Scale = value or 1,
	})
end

local function tween(object, info, props)
	if not object or not object.Parent then
		return nil
	end

	local animation = TweenService:Create(object, info, props)
	animation:Play()
	return animation
end

local function english(ctx)
	return ctx.language and ctx.language() == "en"
end

local function copy(ctx, ru, en)
	return english(ctx) and en or ru
end

local function localized(ctx, key)
	if ctx.L then
		return ctx.L(key)
	end

	return key
end

local function graphemeCount(text)
	local ok, result = pcall(utf8.len, text)
	if ok and result then
		return result
	end

	return #text
end

local function addButtonMotion(target, outline, accent, normalColor)
	local targetScale = scale(target)
	local inside = false
	local down = false

	target.MouseEnter:Connect(function()
		inside = true
		if down then
			return
		end

		tween(target, MOTION.Hover, {
			BackgroundColor3 = normalColor == C.Gold and C.GoldBright or C.Hover,
		})
		tween(outline, MOTION.Hover, {
			Color = C.Gold,
			Transparency = 0.12,
		})
		tween(accent, MOTION.Hover, {
			BackgroundColor3 = C.GoldBright,
		})
		tween(targetScale, MOTION.Hover, {
			Scale = 1.012,
		})
	end)

	target.MouseLeave:Connect(function()
		inside = false
		if down then
			return
		end

		tween(target, MOTION.Hover, {
			BackgroundColor3 = normalColor,
		})
		tween(outline, MOTION.Hover, {
			Color = C.Line,
			Transparency = 0.28,
		})
		tween(accent, MOTION.Hover, {
			BackgroundColor3 = C.Gold,
		})
		tween(targetScale, MOTION.Hover, {
			Scale = 1,
		})
	end)

	target.MouseButton1Down:Connect(function()
		down = true
		tween(target, MOTION.Fast, {
			BackgroundColor3 = normalColor == C.Gold and C.Gold or C.Pressed,
		})
		tween(targetScale, MOTION.Fast, {
			Scale = 0.975,
		})
	end)

	target.MouseButton1Up:Connect(function()
		down = false
		tween(target, MOTION.Hover, {
			BackgroundColor3 = inside and (normalColor == C.Gold and C.GoldBright or C.Hover) or normalColor,
		})
		tween(targetScale, MOTION.Hover, {
			Scale = inside and 1.012 or 1,
		})
	end)
end

function DialogueUI.create(ctx, onTalked)
	local self = {
		visible = false,
		node = "start",
		reported = false,
	}

	local renderToken = 0
	local compact = false
	local destroyed = false
	local connections = {}
	local portrait, portraitReadyConnection

	local oldRoot = ctx.gui:FindFirstChild("VincentDialogueRoot")
	if oldRoot then
		oldRoot:Destroy()
	end

	local root = frame(ctx.gui, {
		Name = "VincentDialogueRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 180,
	})

	local shade = frame(root, {
		Name = "DialogueShade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shade,
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 181,
	})

	local shell = frame(root, {
		Name = "VincentDialogueShell",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(960, 344),
		BackgroundTransparency = 1,
		ZIndex = 182,
	})
	local shellScale = scale(shell, 1)

	local shadow = frame(shell, {
		Name = "Shadow", Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(1, 20, 1, 20),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.62,
		ZIndex = 182,
	})
	corner(shadow, 18)

	local panel = make("CanvasGroup", shell, {
		Name = "VincentDialogue",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shell,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		GroupTransparency = 1,
		ZIndex = 183,
	})
	corner(panel, 20);panel.BackgroundTransparency=.16
	stroke(panel, C.Line, 0.3, 1)

	local panelScale = scale(panel, 0.97)

	frame(panel, {
		Name = "GoldAccent",
		Size = UDim2.fromOffset(48, 2),
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0,
		ZIndex = 184,
	})

	local identityRail = frame(panel, {
		Name = "IdentityRail",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(0, 184, 1, -4),
		BackgroundColor3 = C.Rail,
		BackgroundTransparency = 0,
		ZIndex = 184,
	})

	frame(identityRail, {
		Name = "RailEdge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = C.Line,
		BackgroundTransparency = 0.20,
		ZIndex = 185,
	})

	local registration = label(identityRail, {
        Name = "VincentRegistration", Position = UDim2.fromOffset(24, 12), Size = UDim2.fromOffset(180, 18),
        Text = "S C  /  0 1", Font = FONT.Meta, TextSize = 10, TextColor3 = C.Dim, ZIndex = 185,
    })
    local portraitHost = frame(identityRail, {
        Name = "VincentPortraitHost", Position = UDim2.fromOffset(16, 36), Size = UDim2.fromOffset(220, 252),
        BackgroundColor3 = C.Rail, BackgroundTransparency = .28, ClipsDescendants = true, ZIndex = 185,
    })
    local portraitFallback = label(portraitHost, {
        Name = "VincentPortraitFallback", Size = UDim2.fromScale(1, 1), Text = "V", Font = FONT.Display,
        TextSize = 190, TextColor3 = C.Line, TextTransparency = .58, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 186,
    })
    local portraitRule = frame(identityRail, {
        Name = "VincentPortraitRule", Position = UDim2.fromOffset(24, 302), Size = UDim2.fromOffset(204, 1),
        BackgroundColor3 = C.Line, BackgroundTransparency = .5, ZIndex = 187,
    })
    local clubSeal = label(portraitHost, {
        Name = "VincentClubSeal", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10),
        Size = UDim2.fromOffset(34, 34), Text = "SC", Font = FONT.Display, TextSize = 15,
        TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, Rotation = -8, ZIndex = 188,
    })
    make("UICorner", clubSeal, {CornerRadius = UDim.new(1, 0)})
    stroke(clubSeal, C.Line, .35, 1)
    local function releasePortrait()
        if portraitReadyConnection then portraitReadyConnection:Disconnect(); portraitReadyConnection = nil end
        if portrait then portrait:Destroy(); portrait = nil end
        portraitFallback.Visible = true
    end
    local function mountPortrait()
        if portrait or destroyed or not self.visible or not root.Visible or not portraitHost.Visible then return end
        local ok, mounted = pcall(Preview3D.mountNPC, portraitHost)
        if not ok or not mounted then return end
        portrait = mounted
        local function refreshPortrait()
            if not destroyed and portrait == mounted then portraitFallback.Visible = mounted:GetAttribute("PortraitReady") ~= true end
        end
        refreshPortrait()
        if mounted.GetAttributeChangedSignal then
            portraitReadyConnection = mounted:GetAttributeChangedSignal("PortraitReady"):Connect(refreshPortrait)
        end
    end

	local speaker = label(identityRail, {
        Name = "VincentName",
		Position = UDim2.fromOffset(14, 140),
		Size = UDim2.new(1, -28, 0, 28),
		Text = "",
		Font = FONT.Display,
		TextSize = 18,
		TextColor3 = C.Ivory,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 185,
	})

	local role = label(identityRail, {
        Name = "VincentRole",
		Position = UDim2.fromOffset(14, 168),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "",
		Font = FONT.Meta,
		TextSize = 12,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 185,
	})

	local status = frame(identityRail, {
		Position = UDim2.new(0.5, -48, 1, -64),
		Size = UDim2.fromOffset(96, 28),
		BackgroundColor3 = C.Raised,
		BackgroundTransparency = 0,
		ZIndex = 185,
	})
	corner(status, 14)
	stroke(status, C.Line, 0.38, 1)

	local statusDot = frame(status, {
		Position = UDim2.fromOffset(11, 10),
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = C.Success,
		BackgroundTransparency = 0,
		ZIndex = 186,
	})
	corner(statusDot, 4)

	label(status, {
		Position = UDim2.fromOffset(25, 0),
		Size = UDim2.new(1, -32, 1, 0),
		Text = copy(ctx, "БАР ОТКРЫТ", "BAR OPEN"),
		Font = FONT.Meta,
		TextSize = 10,
		TextColor3 = C.Muted,
		ZIndex = 186,
	})

	local close = button(panel, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.Raised,
		Text = "×",
		TextColor3 = C.Muted,
		Font = FONT.Strong,
		TextSize = 20,
		ZIndex = 190,
	})
	corner(close, 8)
	local closeStroke = stroke(close, C.Line, 0.34, 1)
	local closeAccent = frame(close, {
		Size = UDim2.fromOffset(2, 2),
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 1,
	})
	addButtonMotion(close, closeStroke, closeAccent, C.Raised)

	local main = frame(panel, {
		Name = "Main",
		Position = UDim2.fromOffset(208, 20),
		Size = UDim2.new(1, -232, 1, -40),
		BackgroundTransparency = 1,
		ZIndex = 185,
	})

	local eyebrow = label(main, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -54, 0, 24),
		Text = copy(ctx, "ЛИЧНЫЙ РАЗГОВОР", "PRIVATE CONVERSATION"),
		Font = FONT.Strong,
		TextSize = 11,
		TextColor3 = C.Gold,
		ZIndex = 186,
	})

	local nodeTitle = label(main, {
        Name = "DialogueTitle",
		Position = UDim2.fromOffset(0, 23),
		Size = UDim2.new(1, -54, 0, 25),
		Text = "",
		Font = FONT.Display,
		TextSize = 22,
		TextColor3 = C.Ivory,
		ZIndex = 186,
	})

	local content = make("CanvasGroup", main, {
		Name = "DialogueContent",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		ZIndex = 186,
	})

	local bodyScroll = make("ScrollingFrame", content, {
		Name = "BodyScroll", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -8, 0, 82),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Gold, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 187,
	})
	local body = label(bodyScroll, {
		Name = "Body",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "",
		Font = FONT.Body,
		TextSize = 15,
		TextColor3 = C.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxVisibleGraphemes = -1,
		ZIndex = 187,
	})

	local guide = frame(content, {
		Name = "GuideSteps",
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 187,
	})

	local guideCells = {}
	local guideData = {
		{
			"01",
			"ПОЛУЧИ КАРТУ",
			"GET YOUR CARD",
			"Все знают слово. Шпион — нет.",
			"Everyone knows the word. The spy doesn't.",
		},
		{
			"02",
			"ДАЙ ПОДСКАЗКУ",
			"GIVE A CLUE",
			"Намекни, но не выдай ответ.",
			"Hint without revealing the answer.",
		},
		{
			"03",
			"ПРОГОЛОСУЙ",
			"VOTE",
			"Найди того, кто импровизирует.",
			"Find the player who is improvising.",
		},
	}

	for index, data in ipairs(guideData) do
		local cell = frame(guide, {
			Name = "Step" .. index,
			Position = UDim2.new((index - 1) / 3, index == 1 and 0 or 5, 0, 0),
			Size = UDim2.new(1 / 3, -7, 1, 0),
			BackgroundColor3 = C.Raised,
			BackgroundTransparency = 0,
			ZIndex = 188,
		})
		corner(cell, 8)
		stroke(cell, C.Line, 0.42, 1)

		label(cell, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.fromOffset(36, 26),
			Text = data[1],
			Font = FONT.Display,
			TextSize = 22,
			TextColor3 = C.Gold,
			ZIndex = 189,
		})

		label(cell, {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -22, 0, 18),
			Text = english(ctx) and data[3] or data[2],
			Font = FONT.Strong,
			TextSize = 12,
			TextColor3 = C.Ivory,
			ZIndex = 189,
		})

		label(cell, {
			Position = UDim2.fromOffset(12, 56),
			Size = UDim2.new(1, -24, 0, 36),
			Text = english(ctx) and data[5] or data[4],
			Font = FONT.Meta,
			TextSize = 12,
			TextColor3 = C.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 189,
		})

		guideCells[index] = cell
	end

	local responseGrid = make("ScrollingFrame", content, {
		Name = "ResponseGrid",
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=C.Gold,ScrollingDirection=Enum.ScrollingDirection.Y,BorderSizePixel=0,ClipsDescendants=true,
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(1, 0, 0, 142),
		BackgroundTransparency = 1,
		ZIndex = 187,
	})

	local nodes = {
		start = {
			titleRu = "Чем могу помочь?",
			titleEn = "What can I do for you?",
			bodyKey = "vincentHello",
			choices = {
				{{"Что нового?", "What's new?"}, "news"},
				{{"Продать вещи", "Sell items"}, "sellItems"},
				{"vincentClubChoice", "club"},
				{"vincentShopChoice", "shop"},
				{"vincentByeChoice", "bye"},
			},
		},
		who = {
			titleRu = "О Винсенте",
			titleEn = "About Vincent",
			bodyKey = "vincentWho",
			choices = {
				{"vincentBackChoice", "start"},
				{"vincentClubChoice", "club"},
				{"vincentShopChoice", "shop"},
				{"vincentByeChoice", "bye"},
			},
		},
		club = {
			titleRu = "Правила клуба",
			titleEn = "Club rules",
			guide = true,
			choices = {
				{"vincentBackChoice", "start"},
				{"vincentShopChoice", "shop"},
				{"vincentByeChoice", "bye"},
			},
		},
		highstakes = {
			titleRu = "Бархатный зал",
			titleEn = "The Velvet Room",
			bodyKey = "vincentHighStakes",
			choices = {
				{"vincentBackChoice", "start"},
				{"vincentByeChoice", "bye"},
			},
		},
	}

	local function dailyNode(node)
		local daily = ClubJournalUI.dailyView(ctx.profile(), ctx.language and ctx.language() or "ru")
		if node == "news" then
			local choices = {
				{{daily.button, daily.button}, daily.action or "task"},
				{{"Журнал клуба", "Club journal"}, "journal"},
			}
			if daily.secret then table.insert(choices, {{"Между нами…", "Between us…"}, "secret"}) end
			table.insert(choices, {"vincentBackChoice", "start"})
			return { titleRu = "Новости у стойки", titleEn = "Word at the bar", bodyText = daily.rumor or daily.body, choices = choices }
		elseif node == "task" then
			return { titleRu = "Поручение Винсента", titleEn = "Vincent's assignment", bodyText = daily.body,
				choices = { {{"Журнал клуба", "Club journal"}, "journal"}, {"vincentBackChoice", "news"} } }
		elseif node == "secret" then
			return { titleRu = "Только между нами", titleEn = "Just between us", bodyText = daily.secret or daily.body,
				choices = { {"vincentBackChoice", "news"} } }
		end
	end

	local function guideIntro()
		return copy(
			ctx,
			"Один игрок — шпион. Остальные знают секретное слово. Слушай внимательно: лишняя уверенность иногда подозрительнее молчания.",
			"One player is the spy. Everyone else knows the secret word. Listen closely: too much confidence can be more suspicious than silence."
		)
	end

	local function clearResponses()
		for _, child in ipairs(responseGrid:GetChildren()) do
			child:Destroy()
		end
	end

	local function setBodyText(text)
		renderToken += 1
		local token = renderToken

		body.Text = text
		body.MaxVisibleGraphemes = 0

		task.spawn(function()
			local count = graphemeCount(text)
			for index = 1, count do
				if token ~= renderToken or not self.visible then
					return
				end

				body.MaxVisibleGraphemes = index
				if index % 2 == 0 then
					task.wait(0.012)
				end
			end
		end)
	end

	local function createResponse(textKey, target, index, count, guideMode)
		local byeChoice = target == "bye"
		local columns = guideMode and count or math.min(count, shell.Size.X.Offset < 300 and 1 or 2)
		local column = guideMode and (index - 1) or ((index - 1) % columns)
		local row = guideMode and 0 or math.floor((index - 1) / columns)
		local gap = 8
		local height = 52
        local primary = index == 1 and not byeChoice

		local response = button(responseGrid, {
			Name = "Response_" .. target,
			Position = UDim2.new(
				column / columns,
				column == 0 and 0 or gap / 2,
				0,
				row * (height + gap)
			),
			Size = UDim2.new(1 / columns, -gap / 2, 0, height),
			BackgroundColor3 = primary and C.Gold or C.Rail,
			BackgroundTransparency = primary and 0 or .82,
			Text = "",
			ZIndex = 188,
		})
		corner(response, 2)

		local outline = stroke(
			response,
			C.Line,
			0.72,
			1
		)

		local accent = frame(response, {
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.fromOffset(3, height - 20),
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 1,
			ZIndex = 189,
		})
		corner(accent, 2)

        label(response, {
            Name = "ResponseIndex", Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(26, height),
            Text = string.format("%02d", index), Font = FONT.Display, TextSize = 18,
            TextColor3 = primary and C.Shade or C.Dim, ZIndex = 189,
        })
		label(response, {
            Name = "ResponseText",
			Position = UDim2.fromOffset(44, 0),
			Size = UDim2.new(1, -70, 1, 0),
			Text = type(textKey) == "table" and copy(ctx, textKey[1], textKey[2]) or localized(ctx, textKey),
			Font = FONT.Strong,
			TextSize = compact and 14 or 16,
			TextColor3 = primary and C.Shade or byeChoice and C.Muted or C.Ivory,
			TextWrapped = true,
			ZIndex = 189,
		})

		label(response, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 0),
			Size = UDim2.fromOffset(22, height),
			Text = "›",
			Font = FONT.Display,
			TextSize = 19,
			TextColor3 = primary and C.Shade or byeChoice and C.Dim or C.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 189,
		})

		addButtonMotion(
			response,
			outline,
			accent,
			primary and C.Gold or C.Rail
		)

		response.Activated:Connect(function()
			if target == "vincentAccept" or target == "vincentClaim" then
				local daily = ClubJournalUI.dailyView(ctx.profile(), ctx.language and ctx.language() or "ru")
				if daily.action ~= target or (ctx.pending and ctx.pending()) then return end
				ctx.request(target)
			elseif target == "journal" then
				self:close()
				if ctx.openPanel then ctx.openPanel("journal") end
			elseif target == "sellItems" then
				self:openSell()
			elseif target == "shop" then
				self:close()
				task.defer(function()
					if ctx.openPanel then
						ctx.openPanel("shop")
					end
				end)
			elseif target == "bye" then
				self:close()
			else
				self:render(target)
			end
		end)
	end

	local function buildResponses(data)
		clearResponses()
		local count = #data.choices
		local singleRow = data.guide == true and not compact
		for index, info in ipairs(data.choices) do
			createResponse(info[1], info[2], index, count, singleRow)
		end
	end

    local dialogueHeight=400
    local function applyLayout()
        local camera=workspace.CurrentCamera
        local viewport=ctx.gui.AbsoluteSize
        if viewport.X<=0 or viewport.Y<=0 then viewport=camera and camera.ViewportSize or Vector2.new(1280,720)end
        compact=viewport.X<720
        dialogueHeight=math.min(440,viewport.Y-24)
        shellScale.Scale=1
        shell.Size=UDim2.fromOffset(math.min(1040,viewport.X-24),dialogueHeight)
        shell.Position=UDim2.new(.5,0,1,-12)
        local desktop=not compact and dialogueHeight>=330
        local short=dialogueHeight<260
        identityRail.Position=UDim2.fromOffset(0,0)
        identityRail.Size=UDim2.new(1,0,0,84)
        identityRail.BackgroundTransparency=1
        identityRail.RailEdge.Visible=desktop
        registration.Visible=desktop;portraitRule.Visible=desktop;clubSeal.Visible=desktop
        portraitHost.Position=UDim2.fromOffset(16,12);portraitHost.Size=UDim2.fromOffset(60,68)
        portraitHost.Visible=not short
        portraitFallback.TextSize=58
        local headerX=short and 20 or (viewport.X<320 and 80 or 90)
        speaker.Position=UDim2.fromOffset(headerX,12);speaker.Size=UDim2.new(1,-headerX-68,0,36)
        speaker.TextXAlignment=Enum.TextXAlignment.Left;speaker.TextSize=viewport.X<320 and 28 or (compact and 30 or 36)
        role.Position=UDim2.fromOffset(headerX,48);role.Size=UDim2.new(1,-headerX-68,0,24)
        role.TextXAlignment=Enum.TextXAlignment.Left;role.TextSize=12;role.TextWrapped=true
        status.Visible=false
        main.Position=UDim2.fromOffset(20,short and 72 or 94);main.Size=UDim2.new(1,-40,1,short and -88 or -110)
        eyebrow.Visible=false
        nodeTitle.Position=UDim2.fromOffset(0,0);nodeTitle.Size=UDim2.new(1,0,0,36);nodeTitle.TextSize=compact and 25 or 30
        content.Position=UDim2.fromOffset(0,short and 36 or 42);content.Size=UDim2.new(1,0,1,short and -36 or -42)
        body.TextSize=compact and 16 or 18
        if desktop then
            identityRail.Size=UDim2.new(0,252,1,0)
            local portraitHeight=dialogueHeight-188
            portraitHost.Position=UDim2.fromOffset(16,36);portraitHost.Size=UDim2.fromOffset(220,portraitHeight)
            portraitRule.Position=UDim2.fromOffset(24,portraitHeight+50)
            portraitFallback.TextSize=190
            speaker.Position=UDim2.fromOffset(24,portraitHeight+58);speaker.Size=UDim2.new(1,-48,0,54);speaker.TextSize=42
            role.Position=UDim2.fromOffset(24,portraitHeight+114);role.Size=UDim2.new(1,-48,0,30);role.TextSize=13
            main.Position=UDim2.fromOffset(284,24);main.Size=UDim2.new(1,-312,1,-48)
            eyebrow.Visible=true;eyebrow.Position=UDim2.fromOffset(0,0);eyebrow.Size=UDim2.new(1,-48,0,18)
            nodeTitle.Position=UDim2.fromOffset(0,24);nodeTitle.Size=UDim2.new(1,-48,0,44);nodeTitle.TextSize=32
            content.Position=UDim2.fromOffset(0,78);content.Size=UDim2.new(1,0,1,-78)
        end
        close.Position=UDim2.new(1,-16,0,14)
        if not portraitHost.Visible then releasePortrait() elseif self.visible and root.Visible then mountPortrait() end
    end

	function self:render(node)
        if destroyed then return end
		self.node = node or self.node
		local data = dailyNode(self.node) or nodes[self.node] or nodes.start

		content.GroupTransparency = 1
		speaker.Text = copy(ctx, "Винсент", "Vincent")
		role.Text = copy(ctx, "Бармен клуба", "Club bartender")
		eyebrow.Text = data.guide
			and copy(ctx, "ДЕЛО № 01 · ПРАВИЛА", "CASE 01 · RULES")
			or copy(ctx, "ЛИЧНЫЙ РАЗГОВОР", "PRIVATE CONVERSATION")
		nodeTitle.Text = english(ctx) and data.titleEn or data.titleRu

        local contentHeight=dialogueHeight-(dialogueHeight<260 and 120 or 136)
        local bodyHeight=math.floor(math.clamp(contentHeight*.35,48,88))
        bodyHeight=math.min(bodyHeight,math.max(28,contentHeight-76))
        local responseTop=bodyHeight+16
        guide.Visible=data.guide==true and not compact and contentHeight>=245
        if guide.Visible then
            bodyHeight=60;guide.Position=UDim2.fromOffset(0,68);guide.Size=UDim2.new(1,0,0,100)
            responseTop=180;setBodyText(guideIntro())
        elseif data.guide then
            bodyHeight=math.max(48,math.min(120,contentHeight-68));responseTop=bodyHeight+12
            local rules={guideIntro()}
            for _,data in ipairs(guideData)do rules[#rules+1]=english(ctx)and data[5]or data[4]end
            setBodyText(table.concat(rules,"\n\n"))
        else
            setBodyText(data.bodyText or localized(ctx,data.bodyKey))
        end
        bodyScroll.Size=UDim2.new(1,-8,0,bodyHeight)
        responseGrid.Position=UDim2.fromOffset(0,responseTop)
        responseGrid.Size=UDim2.new(1,0,1,-responseTop)
        responseGrid.CanvasPosition=Vector2.new()

		buildResponses(data)
		tween(content, MOTION.Content, {
			GroupTransparency = 0,
		})
	end


	-----------------------------------------------------------------
	-- V44 VINCENT RESALE VIEW (integrated to preserve current RBXL structure)
	-----------------------------------------------------------------
	local sellRoot = frame(ctx.gui, {Name="VincentSellRoot",Size=UDim2.fromScale(1,1),BackgroundColor3=C.Shade,BackgroundTransparency=0.18,Visible=false,ZIndex=210})
	local sellShell = frame(sellRoot, {Name="VincentSellShell",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(720,500),BackgroundColor3=C.Shell,BackgroundTransparency=.18,ZIndex=211})
	corner(sellShell,12); stroke(sellShell,C.Line,.18,1.2)
	local sellTitle=label(sellShell,{Position=UDim2.fromOffset(22,14),Size=UDim2.new(1,-90,0,34),Text="",Font=FONT.Display,TextSize=22,TextColor3=C.GoldBright,ZIndex=212})
	local sellStatus=label(sellShell,{Position=UDim2.fromOffset(22,52),Size=UDim2.new(1,-44,0,44),Text="",Font=FONT.Body,TextSize=14,TextColor3=C.Muted,TextWrapped=true,ZIndex=212})
	local sellClose=button(sellShell,{Name="CloseSale",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,12),Size=UDim2.fromOffset(44,44),BackgroundColor3=C.Raised,Text="×",Font=FONT.Strong,TextSize=20,TextColor3=C.Ivory,ZIndex=213}); corner(sellClose,8)
	local sellList=make("ScrollingFrame",sellShell,{Name="SellItems",Position=UDim2.fromOffset(18,104),Size=UDim2.new(1,-36,1,-124),BackgroundColor3=C.Rail,BackgroundTransparency=.12,BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=212}); corner(sellList,9)
	make("UIPadding",sellList,{PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)})
	local sellLayout=make("UIListLayout",sellList,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
	local confirmBar=frame(sellShell,{Name="SellConfirmation",Position=UDim2.new(0,18,1,-132),Size=UDim2.new(1,-36,0,116),BackgroundColor3=C.Raised,ZIndex=212}); corner(confirmBar,9)
	local confirmText=label(confirmBar,{Name="SaleSummary",Position=UDim2.fromOffset(12,6),Size=UDim2.new(1,-24,0,50),Text="",TextSize=14,TextWrapped=true,ZIndex=213})
	local cancelSell=button(confirmBar,{Name="CancelSale",Position=UDim2.fromOffset(12,64),Size=UDim2.new(.5,-18,0,44),BackgroundColor3=C.Rail,TextColor3=C.Text,Text="Отмена",TextSize=14,ZIndex=213}); corner(cancelSell,6)
	local confirmSell=button(confirmBar,{Name="ConfirmSale",Position=UDim2.new(.5,6,0,64),Size=UDim2.new(.5,-18,0,44),BackgroundColor3=C.GoldDark,TextColor3=C.Shade,Text="Подтвердить",TextSize=14,ZIndex=213}); corner(confirmSell,6)
	confirmBar.Visible=false
	local selectedSellId=nil
	local compactSale=false
	local function layoutSellRow(row)
		local name,value,offer=row:FindFirstChild("ItemName"),row:FindFirstChild("ItemValue"),row:FindFirstChild("Offer")
		if not name or not value or not offer then return end
		row.Size=UDim2.new(1,-2,0,compactSale and 104 or 72)
		name.Size=UDim2.new(1,compactSale and -24 or -200,0,26)
		value.Size=UDim2.new(1,compactSale and -24 or -200,0,22)
		offer.AnchorPoint=compactSale and Vector2.new(0,0)or Vector2.new(1,.5)
		offer.Position=compactSale and UDim2.fromOffset(12,68)or UDim2.new(1,-12,.5,0)
		offer.Size=compactSale and UDim2.new(1,-24,0,26)or UDim2.fromOffset(164,32)
		offer.TextXAlignment=compactSale and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	end
	local function applySellLayout()
		local viewport=ctx.gui.AbsoluteSize
		if viewport.X<=0 or viewport.Y<=0 then local camera=workspace.CurrentCamera;viewport=camera and camera.ViewportSize or Vector2.new(1280,720)end
		local width=math.max(1,math.min(720,viewport.X-24));local height=math.max(1,math.min(500,viewport.Y-24))
		sellShell.Size=UDim2.fromOffset(width,height);compactSale=width<520
		sellTitle.TextSize=compactSale and 28 or 40
		sellStatus.Size=UDim2.new(1,-44,0,height<236 and 24 or 44)
		sellStatus.TextWrapped=height>=236;sellStatus.TextTruncate=Enum.TextTruncate.AtEnd
		sellList.Visible=not(confirmBar.Visible and height<360)
		sellList.Size=UDim2.new(1,-36,1,confirmBar.Visible and -244 or -124)
		for _,row in ipairs(sellList:GetChildren())do if row:IsA("GuiButton")then layoutSellRow(row)end end
	end

	local function isEquipped(profile,itemId)
		for _,equippedId in pairs(profile.equipped or {}) do if equippedId==itemId then return true end end
		return false
	end
	local function clearSellRows()
		for _,child in ipairs(sellList:GetChildren()) do if child:IsA("GuiButton") then child:Destroy() end end
	end
	local function resaleReaction(receipt)
		if not receipt or receipt.ok==false then return english(ctx) and "Some things are worth more than coins." or "Некоторые вещи стоят больше, чем монеты." end
		local value=tonumber(receipt.value) or 0
		if value>=2200 then return english(ctx) and "Now this is interesting." or "Вот это уже интереснее." end
		if value>=600 then return english(ctx) and "Not a bad piece. There will be a buyer for it." or "Неплохая вещь. В клубе на такое найдётся покупатель." end
		return english(ctx) and "Not a treasure, but I can find shelf space for it." or "Не сокровище, но место на полке найдётся."
	end
	local function renderSellList()
		clearSellRows(); selectedSellId=nil; confirmBar.Visible=false
		local p=ctx.profile()
		local rows={}
		for id,owned in pairs(p.owned or {}) do
			if owned==true then
				local info=Catalog.sellInfo(id)
				if info.sellable then table.insert(rows,{id=id,info=info}) end
			end
		end
		table.sort(rows,function(a,b) if a.info.value==b.info.value then return a.id<b.id end return a.info.value>b.info.value end)
		if #rows==0 then sellStatus.Text=english(ctx) and "You have nothing Vincent is buying right now." or "Сейчас у тебя нет вещей, которые Винсент готов купить." end
		for order,row in ipairs(rows) do
			local item,info=row.info.item,row.info
			local equipped=isEquipped(p,row.id)
			local b=button(sellList,{Name="Sell_"..row.id,Size=UDim2.new(1,-2,0,72),BackgroundColor3=C.Raised,Text="",LayoutOrder=order,ZIndex=213}); corner(b,7); stroke(b,C.Line,.42,1)
			label(b,{Name="ItemName",Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-200,0,26),Text=(english(ctx) and item.en or item.ru)..(equipped and (english(ctx) and "  · EQUIPPED" or "  · НАДЕТО") or ""),Font=FONT.Strong,TextSize=16,TextTruncate=Enum.TextTruncate.AtEnd,TextColor3=C.Ivory,ZIndex=214})
			local rarity=(Catalog.Rarities[item.rarity] or {})
			label(b,{Name="ItemValue",Position=UDim2.fromOffset(12,38),Size=UDim2.new(1,-200,0,22),Text=(english(ctx) and rarity.en or rarity.ru).."  ·  "..info.value.." ◈",TextSize=13,TextColor3=C.Muted,ZIndex=214})
			label(b,{Name="Offer",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-12,.5,0),Size=UDim2.fromOffset(164,32),Text=(english(ctx) and "VINCENT: " or "ВИНСЕНТ: ")..info.offer.." ◈",Font=FONT.Strong,TextSize=14,TextColor3=C.GoldBright,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=214})
			layoutSellRow(b)
			b.Activated:Connect(function()
				selectedSellId=row.id; confirmBar.Visible=true
				confirmText.Text=english(ctx) and ("Sell one copy of “"..item.en.."” for "..info.offer.." ◈?") or ("Продать одну копию «"..item.ru.."» за "..info.offer.." ◈?")
				applySellLayout()
			end)
		end
		applySellLayout()
	end
	function self:openSell()
        if destroyed then return end
        releasePortrait()
		self.visible=false; root.Visible=false; sellRoot.Visible=true
		sellTitle.Text=english(ctx) and "VINCENT · RESALE" or "ВИНСЕНТ · СКУПКА"
		sellStatus.Text=english(ctx) and "I pay 30% of a piece's club value. Some things are not for sale." or "Плачу 30% от клубной стоимости. Некоторые вещи не продаются."
		cancelSell.Text=english(ctx) and "Cancel" or "Отмена"; confirmSell.Text=english(ctx) and "Confirm" or "Подтвердить"
		renderSellList()
	end
	function self:receive(receipt)
		if destroyed or not receipt then return end
		if receipt.code=="sold" and receipt.ok then
			sellStatus.Text=resaleReaction(receipt); renderSellList()
		elseif receipt.code=="protected_item" then
			sellStatus.Text=english(ctx) and "No. That is not for sale." or "Нет. Это не продаётся. Некоторые вещи стоят больше, чем монеты."
		end
	end
	local function closeSell() sellRoot.Visible=false; selectedSellId=nil; confirmBar.Visible=false end
	sellClose.Activated:Connect(closeSell); cancelSell.Activated:Connect(function() selectedSellId=nil; confirmBar.Visible=false;applySellLayout()end)
	confirmSell.Activated:Connect(function()
		local itemId=selectedSellId
		if not itemId or (ctx.pending and ctx.pending()) then return end
		ctx.request("sell", itemId)
	end)

	function self:open(node)
        if destroyed then return end
		closeSell()
		if self.visible then
			self:render(node or "start")
			return
		end

		if ctx.closePanels then
			ctx.closePanels(nil)
		end

		self.visible = true
		applyLayout()
		root.Visible = true
        mountPortrait()
		shade.BackgroundTransparency = 1
		panel.GroupTransparency = 1
		panelScale.Scale = 0.96

		local targetPosition = shell.Position
		shell.Position = UDim2.new(
			targetPosition.X.Scale,
			targetPosition.X.Offset,
			1,
			34
		)

		self:render(node or "start")

		tween(shade, MOTION.Open, {
			BackgroundTransparency = SHADE_TRANSPARENCY,
		})
		tween(panel, MOTION.Open, {
			GroupTransparency = 0,
		})
		tween(panelScale, MOTION.Open, {
			Scale = 1,
		})
		tween(shell, MOTION.Open, {
			Position = targetPosition,
		})
	end

	function self:close()
        if destroyed then return end
        releasePortrait()
		if sellRoot.Visible then closeSell()end
		if not self.visible then
			return
		end

		self.visible = false
		renderToken += 1
		body.MaxVisibleGraphemes = -1

		if onTalked and not self.reported then
			self.reported = true
			onTalked()
		end

		tween(shade, MOTION.Close, {
			BackgroundTransparency = 1,
		})
		tween(panel, MOTION.Close, {
			GroupTransparency = 1,
		})
		tween(panelScale, MOTION.Close, {
			Scale = 0.97,
		})

		local closing = tween(shell, MOTION.Close, {
			Position = UDim2.new(0.5, 0, 1, 34),
		})

		if closing then
			closing.Completed:Once(function()
				if not destroyed and not self.visible then
					root.Visible = false
				end
			end)
		else
			root.Visible = false
		end
	end

	close.Activated:Connect(function()
		self:close()
	end)

	-- Фон специально НЕ закрывает диалог: случайный клик по пустому месту
	-- ничего не делает. Закрытие только через X, Escape или вариант "уйти".

	connections[#connections+1] = UserInputService.InputBegan:Connect(function(input, processed)
		if destroyed or processed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			if self.visible or sellRoot.Visible then self:close()end
		end
	end)

	local function refreshLayout()
        if destroyed then return end
		if self.visible then applyLayout();self:render()end
		if sellRoot.Visible then applySellLayout()end
	end
	local viewportConnection
    local function bindViewport()
        if destroyed then return end
        if viewportConnection then viewportConnection:Disconnect();viewportConnection=nil end
        local camera=workspace.CurrentCamera
        if camera then
            viewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshLayout)
        end
        if self.visible then applyLayout() end
        if sellRoot.Visible then applySellLayout()end
    end
    connections[#connections+1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
    connections[#connections+1] = ctx.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshLayout)
    bindViewport()

	-- Defer until SpyClient has applied the authoritative profile and cleared pendingId.
	-- No duplicate profile cache and no additional SpyClient hook are needed.
	connections[#connections+1] = script.Parent:WaitForChild("Profile").OnClientEvent:Connect(function()
		task.defer(function()
            if destroyed then return end
			if self.visible then self:render() end
			if sellRoot.Visible then renderSellList() end
		end)
	end)

    function self:Destroy(fromRoot)
        if destroyed then return end
        destroyed=true;self.visible=false;renderToken+=1
        releasePortrait()
        if viewportConnection then viewportConnection:Disconnect();viewportConnection=nil end
        for _,connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
        sellRoot:Destroy()
        if not fromRoot and root.Parent then root:Destroy() end
    end
    root.Destroying:Connect(function() self:Destroy(true) end)
	return self
end

return DialogueUI
