local TweenService = game:GetService("TweenService")

local ModalUI = require(script.Parent.ModalUI)
local Catalog = require(script.Parent.Catalog)
local Preview3D = require(script.Parent.Preview3D)
local IconUI = require(script.Parent.IconUI)
local RollConfig = require(script.Parent.AccessoryRollConfig)

local DailyUI = {}

local REWARDS = {
	{ coins = 80 },
	{ coins = 120 },
	{},
	{ coins = 180 },
	{ coins = 220 },
	{},
	{ coins = 1000 },
}

for _,reward in ipairs(REWARDS) do reward.rolls=RollConfig.Rewards.daily end

-- Все настройки внешнего вида — здесь.
local STYLE = {
	Background = Color3.fromRGB(25,27,31),
	Card = Color3.fromRGB(46,48,52),
	CardHover = Color3.fromRGB(57,60,65),
	Current = Color3.fromRGB(63,60,55),

	Border = Color3.fromRGB(87,89,93),
	Cream = Color3.fromRGB(244,240,231),
	Text = Color3.fromRGB(244,240,231),
	Muted = Color3.fromRGB(188,187,181),
	Gold = Color3.fromRGB(221,193,151),
	Collected = Color3.fromRGB(160, 189, 151),
	Ink = Color3.fromRGB(25,27,31),

	HeadingFont = Enum.Font.BuilderSansBold,
	BodyFont = Enum.Font.BuilderSansMedium,
	BoldFont = Enum.Font.BuilderSansBold,
}

local STRINGS = {
	title = { "ЕЖЕДНЕВНЫЕ НАГРАДЫ", "DAILY REWARDS" },
	subtitle = {
		"7 ДНЕЙ · ФИНАЛ — 1000 МОНЕТ",
		"7 DAYS · FINALE — 1000 COINS",
	},
	day = { "ДЕНЬ %d", "DAY %d" },
	coins = { "МОНЕТ", "COINS" },
	today = { "СЕГОДНЯ", "TODAY" },
	collected = { "ПОЛУЧЕНО", "COLLECTED" },
	later = { "ДАЛЕЕ", "UP NEXT" },
	final = { "НАГРАДА НЕДЕЛИ", "WEEKLY REWARD" },
	bonus = { "ФИНАЛ СЕРИИ", "STREAK FINALE" },
	claim = { "ЗАБРАТЬ НАГРАДУ", "CLAIM REWARD" },
	claimed = { "НАГРАДА ПОЛУЧЕНА", "REWARD CLAIMED" },
	loading = { "ЗАГРУЗКА…", "LOADING…" },
	retry = { "ПОВТОРИТЬ", "TRY AGAIN" },
	ready = {
		"Твоя награда готова.",
		"Your reward is ready.",
	},
	next = {
		"Следующая награда через %s",
		"Next reward in %s",
	},
	unavailable = {
		"Ожидаем данные наград…",
		"Waiting for reward data…",
	},
}

local function isFinite(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function formatTime(seconds)
	if not isFinite(seconds) then
		return "—"
	end

	seconds = math.max(0, math.floor(seconds))

	return string.format(
		"%02d:%02d:%02d",
		math.floor(seconds / 3600),
		math.floor(seconds / 60) % 60,
		seconds % 60
	)
end

function DailyUI.create(ctx)
	local self = ModalUI.create(
		ctx,
		"daily",
		"daily",
		"dailyHint",
		940
	)

	local C = STYLE
	local activeTweens = {}
	local entranceToken = 0
	local playEntrance = false
	local lastStatusKey
	local lastButtonState
	local requestLockedUntil = 0

	local function tr(key, ...)
		local chinese={title="每日奖励",subtitle="连续 7 天 · 最终奖励 1000 硬币",day="第 %d 天",coins="硬币",today="今天",collected="已领取",later="即将解锁",final="每周奖励",bonus="连续奖励",claim="领取奖励",claimed="已领取奖励",loading="加载中…",retry="重试",ready="奖励已准备就绪。",next="下一份奖励：%s",unavailable="正在等待奖励数据…"}
        if ctx.language()=="zh" then return string.format(chinese[key],...)end
        local index = ctx.language() == "en" and 2 or 1
		return string.format(STRINGS[key][index], ...)
	end

	local function make(className, parent, properties)
		return ctx.make(className, parent, properties)
	end

	local function corner(parent, radius)
		local existing = parent:FindFirstChildOfClass("UICorner")

		if existing then
			existing.CornerRadius = UDim.new(0, radius)
			return existing
		end

		return make("UICorner", parent, {
			CornerRadius = UDim.new(0, radius),
		})
	end

	local function stroke(parent, color, thickness, transparency)
		return make("UIStroke", parent, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = color,
			Thickness = thickness,
			Transparency = transparency or 0,
		})
	end

	-- Свои TextLabel: размеры не наследуют мелкий стиль ctx.label.
	local function text(parent, name, value, position, size, fontSize, color, font)
		return make("TextLabel", parent, {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Position = position,
			Size = size,

			Text = value,
			TextColor3 = color or C.Text,
			TextSize = fontSize,
			Font = font or C.BodyFont,

			TextScaled = false,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			RichText = false,
		})
	end

	local function animate(instance, duration, properties)
		local previous = activeTweens[instance]

		if previous then
			previous:Cancel()
		end

		local motion = TweenService:Create(
			instance,
			TweenInfo.new(
				duration,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),
			properties
		)

		activeTweens[instance] = motion
		motion:Play()
	end

	local function cancelAnimations()
		entranceToken = entranceToken + 1

		for _, motion in pairs(activeTweens) do
			motion:Cancel()
		end

		activeTweens = {}
	end

	local function getStatus()
		local profile = ctx.profile() or {}
		local daily = type(profile.daily) == "table"
			and profile.daily
			or {}

		local nextAt = isFinite(daily.nextAt)
			and daily.nextAt
			or math.huge

		local streak = isFinite(daily.streak)
			and math.clamp(math.floor(daily.streak), 0, 7)
			or 0

		local nextDay = isFinite(daily.nextStreak)
			and math.clamp(math.floor(daily.nextStreak), 1, 7)
			or 1

		local now = os.time()
		local loaded = profile.ready == true
		local hasSchedule = daily.available == true or isFinite(nextAt)

		local available = loaded
			and hasSchedule
			and (daily.available == true or now >= nextAt)

		if not daily.available and now >= nextAt then
			nextDay = now < nextAt + 86400
				and (streak % 7 + 1)
				or 1
		end

		return {
			loaded = loaded,
			hasSchedule = hasSchedule,
			available = available,
			nextDay = nextDay,
			nextAt = nextAt,
			progress = available and nextDay - 1 or streak,
		}
	end

	local function statusKey(state)
		return table.concat({
			tostring(state.loaded),
			tostring(state.hasSchedule),
			tostring(state.available),
			tostring(state.nextDay),
			tostring(state.progress),
		}, ":")
	end

	local function rewardName(reward)
		if reward.caseId then
			local entry = Catalog.Cases[reward.caseId]
			return entry and ctx.L(entry.nameKey) or reward.caseId
		end

		if reward.itemId then
			local entry = Catalog.ById[reward.itemId]

			if entry then
				return ctx.language() == "en" and entry.en or entry.ru
			end

			return reward.itemId
		end

		local parts={}
		if (reward.coins or 0)>0 then parts[#parts+1]=tostring(reward.coins).." "..tr("coins") end
		if (reward.rolls or 0)>0 then parts[#parts+1]=tostring(reward.rolls).." Rolls" end
		return table.concat(parts," · ")
	end

	local function mountPreview(parent, reward)
		if reward.caseId then
			Preview3D.mount(parent, nil, reward.caseId)
		elseif reward.itemId then
			Preview3D.mount(parent, Catalog.ById[reward.itemId])
		elseif (reward.coins or 0)>0 then
			IconUI.draw(parent, "coin", C.Gold)
		else
			make("TextLabel",parent,{Text="↻",TextSize=42,Font=Enum.Font.BuilderSansBold,TextColor3=C.Gold,BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
		end
	end

	-- Нижняя панель находится вне прокрутки.
	local footer = make("Frame", self.modal, {
		Name = "DailyFooter",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -18),
		Size = UDim2.new(1, -40, 0, 94),
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
	})

	local countdown = text(
		footer,
		"Countdown",
		"",
		UDim2.new(),
		UDim2.new(1, 0, 0, 28),
		18,
		C.Muted,
		C.BodyFont
	)

	countdown.TextXAlignment = Enum.TextXAlignment.Center

	local claimButton = make("TextButton", footer, {
		Name = "ClaimReward",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 56),

		BackgroundColor3 = C.Cream,
		BorderSizePixel = 0,

		AutoButtonColor = false,
		Text = "",
		TextSize = 25,
		TextScaled = false,
		Font = C.HeadingFont,
		TextColor3 = C.Ink,
	})

	corner(claimButton, 14)

	local buttonScale = make("UIScale", claimButton, {
		Scale = 1,
	})

	local function canInteract()
		local state = getStatus()

		return not ctx.pending()
			and os.clock() >= requestLockedUntil
			and (
				state.available
				or not state.loaded
				or not state.hasSchedule
			)
	end

	local function releaseButton()
		animate(buttonScale, 0.18, {
			Scale = 1,
		})
	end

	claimButton.MouseEnter:Connect(function()
		if canInteract() then
			animate(claimButton, 0.16, {
				BackgroundColor3 = Color3.fromRGB(255, 238, 215),
			})
		end
	end)

	claimButton.MouseLeave:Connect(function()
		releaseButton()
		lastButtonState = nil
		self:tick()
	end)

	claimButton.InputBegan:Connect(function(input)
		local pressed = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch

		if pressed and canInteract() then
			animate(buttonScale, 0.09, {
				Scale = 0.98,
			})
		end
	end)

	claimButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			releaseButton()
		end
	end)

	claimButton.Activated:Connect(function()
		releaseButton()

		if not canInteract() then
			return
		end

		local state = getStatus()

		-- Локальная защита от двойного клика.
		-- Выдачей наград по-прежнему управляет сервер.
		requestLockedUntil = os.clock() + 0.7

		if not state.loaded or not state.hasSchedule then
			ctx.request("retry")
		elseif state.available then
			ctx.request("daily")
		end

		self:tick()
	end)

	local function buildCard(parent, day, reward, state, featured, compact)
		local collected = state.loaded and day <= state.progress
		local current = state.loaded
			and state.hasSchedule
			and not collected
			and day == state.nextDay

		local baseColor = current and C.Current or C.Card

		local card = make("Frame", parent, {
			Name = "Day" .. day,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = baseColor,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})

		corner(card, 16)

		local border = stroke(
			card,
			current and C.Cream or C.Border,
			current and 2 or 1,
			current and 0 or 0.45
		)

		local dayLabel = text(
			card,
			"DayLabel",
			tr("day", day),
			UDim2.fromOffset(12, 8),
			UDim2.new(1, -24, 0, 28),
			21,
			current and C.Cream or C.Muted,
			C.HeadingFont
		)

		local caption = collected and tr("collected")
			or (current and state.available and tr("today"))
			or tr("later")

		if featured then
			dayLabel.Text = tr("day", day) .. " / " .. tr("final")
			dayLabel.TextSize = compact and 18 or 20

			local previewWidth = compact and 90 or 114

			local previewHost = make("Frame", card, {
				Name = "RewardPreview",
				Position = UDim2.new(1, -previewWidth - 8, 0, 37),
				Size = UDim2.fromOffset(previewWidth, 102),
				BackgroundTransparency = 1,
			})

			mountPreview(previewHost, reward)

			text(
				card,
				"RewardName",
				rewardName(reward),
				UDim2.fromOffset(14, 46),
				UDim2.new(1, -previewWidth - 30, 0, 48),
				compact and 22 or 26,
				C.Cream,
				C.HeadingFont
			)

			text(
				card,
				"Bonus",
				tr("bonus"),
				UDim2.fromOffset(14, 96),
				UDim2.new(1, -previewWidth - 30, 0, 26),
				18,
				C.Gold,
				C.BoldFont
			)
		elseif reward.coins then
			local coinHost = make("Frame", card, {
				Name = "CoinIcon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 39),
				Size = UDim2.fromOffset(36, 36),
				BackgroundTransparency = 1,
			})

			mountPreview(coinHost, reward)

			local amount = text(
				card,
				"Amount",
				tostring(reward.coins),
				UDim2.fromOffset(8, 73),
				UDim2.new(1, -16, 0, 43),
				36,
				C.Cream,
				C.HeadingFont
			)

			amount.TextXAlignment = Enum.TextXAlignment.Center

			local currency = text(
				card,
				"Currency",
				tr("coins"),
				UDim2.fromOffset(8, 113),
				UDim2.new(1, -16, 0, 22),
				15,
				C.Muted,
				C.BoldFont
			)

			currency.TextXAlignment = Enum.TextXAlignment.Center
		else
			local previewHost = make("Frame", card, {
				Name = "RewardPreview",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 35),
				Size = UDim2.fromOffset(104, 62),
				BackgroundTransparency = 1,
			})

			mountPreview(previewHost, reward)

			local name = text(
				card,
				"RewardName",
				rewardName(reward),
				UDim2.fromOffset(8, 96),
				UDim2.new(1, -16, 0, 42),
				compact and 16 or 18,
				C.Cream,
				C.HeadingFont
			)

			name.TextXAlignment = Enum.TextXAlignment.Center
		end

		local statusLabel = text(
			card,
			"RewardStatus",
			caption,
			UDim2.new(0, 10, 1, -29),
			UDim2.new(1, -20, 0, 24),
			15,
			collected and C.Collected
				or (current and C.Gold or C.Muted),
			C.HeadingFont
		)

		statusLabel.TextXAlignment = featured
			and Enum.TextXAlignment.Left
			or Enum.TextXAlignment.Center

		card.MouseEnter:Connect(function()
			animate(card, 0.16, {
				BackgroundColor3 = C.CardHover,
			})

			animate(border, 0.16, {
				Transparency = 0,
			})
		end)

		card.MouseLeave:Connect(function()
			animate(card, 0.2, {
				BackgroundColor3 = baseColor,
			})

			animate(border, 0.2, {
				Transparency = current and 0 or 0.45,
			})
		end)

		if playEntrance then
			local destination = card.Position
			local token = entranceToken

			card.Position = UDim2.fromOffset(0, 10)

			task.delay((day - 1) * 0.035, function()
				if token ~= entranceToken
					or not card.Parent
					or not self.visible
				then
					return
				end

				animate(card, 0.28, {
					Position = destination,
				})
			end)
		end
	end

	function self:render()
		cancelAnimations()
		self:clear()

		local state = getStatus()
		local width = self.layoutWidth or 940
		local compact = width < 640
        local short=self.modal.Size.Y.Offset<340

		lastStatusKey = statusKey(state)
		lastButtonState = nil

		self.modal.BackgroundColor3 = C.Background
		corner(self.modal, 20);self.modal.BackgroundTransparency=.16

		local modalBorder = self.modal:FindFirstChildOfClass("UIStroke")

		if modalBorder then
			modalBorder.Color = C.Border
			modalBorder.Thickness = 1
			modalBorder.Transparency = 0.2
		end

		self.title.Text = tr("title")
		self.title.Font = C.HeadingFont
		self.title.TextScaled = false
		self.title.TextSize = compact and 22 or 28
		self.title.TextColor3 = C.Cream
		self.title.Position = UDim2.fromOffset(20, 13)
		self.title.Size = UDim2.new(1, -88, 0, 42)

		self.hint.Visible=not short
        self.hint.Text = tr("subtitle")
		self.hint.Font = C.BodyFont
		self.hint.TextScaled = false
		self.hint.TextSize = compact and 16 or 18
		self.hint.TextColor3 = C.Muted
		self.hint.Position = UDim2.fromOffset(20, 58)
		self.hint.Size = UDim2.new(1, -40, 0, 44)

		local contentTop=short and 66 or 106
        local footerHeight=short and 72 or 88
        footer.Position=UDim2.new(0,20,1,-12);footer.Size=UDim2.new(1,-40,0,footerHeight)
        claimButton.Size=UDim2.new(1,0,0,short and 44 or 50)
        countdown.Size=UDim2.new(1,0,0,22)
        self.surface.Position=UDim2.fromOffset(18,contentTop)
        self.surface.Size=UDim2.new(1,-36,1,-contentTop-footerHeight-24)
		self.surface.ScrollBarThickness = 4
		self.surface.ScrollBarImageColor3 = C.Gold

		local columns = compact and 2 or 4
		local rows = compact and 4 or 2
		local gap = 10
		local cardHeight = 172

		local board = self:row(
			rows * cardHeight + (rows - 1) * gap
		)

		board.Name = "RewardBoard"

		local configuredRewards=((ctx.profile() or {}).daily or {}).rewards or REWARDS
		for day, reward in ipairs(configuredRewards) do
			local featured = day == 7
			local span = featured and 2 or 1
			local index = day - 1

			local col = index % columns
			local row = math.floor(index / columns)

			local slot = make("Frame", board, {
				Name = "RewardSlot" .. day,
				BackgroundTransparency = 1,

				Position = UDim2.new(
					col / columns,
					col * gap / columns,
					0,
					row * (cardHeight + gap)
				),

				Size = UDim2.new(
					span / columns,
					-gap * (columns - span) / columns,
					0,
					cardHeight
				),
			})

			buildCard(
				slot,
				day,
				reward,
				state,
				featured,
				compact
			)
		end

		claimButton.TextSize = compact and 16 or 18
		countdown.TextSize = compact and 13 or 14

		playEntrance = false
		self:tick()
	end

	function self:tick()
		if not self.visible then
			return
		end

		local state = getStatus()
		local key = statusKey(state)

		if key ~= lastStatusKey then
			self:render()
			return
		end

		local busy = ctx.pending()
			or os.clock() < requestLockedUntil

		local retry = not state.loaded or not state.hasSchedule
		local enabled = not busy and (state.available or retry)

		if retry then
			countdown.Text = tr("unavailable")
		elseif state.available then
			countdown.Text = tr("ready")
		else
			countdown.Text = tr(
				"next",
				formatTime(state.nextAt - os.time())
			)
		end

		claimButton.Text = busy and tr("loading")
			or (retry and tr("retry"))
			or (state.available and tr("claim"))
			or tr("claimed")

		claimButton.Selectable = enabled

		local buttonState = tostring(enabled)

		if buttonState ~= lastButtonState then
			lastButtonState = buttonState

			animate(claimButton, 0.18, {
				BackgroundColor3 = enabled and C.Cream or C.Card,
				TextColor3 = enabled and C.Ink or C.Muted,
			})
		end
	end

	local baseOpen = self.open
	local baseClose = self.close
	local baseResize = self.resize

	function self:open()
		playEntrance = not self.visible
		baseOpen(self)

		if playEntrance then
			playEntrance = false
		end
	end

	function self:close(animated)
		cancelAnimations()
		buttonScale.Scale = 1
		baseClose(self, animated)
	end

	function self:resize()
		local previousWidth = self.layoutWidth
		baseResize(self)
        if self.visible then self:render()end

		-- ModalUI может повторно менять размер заголовка.
		if self.visible then
			local compact = (self.layoutWidth or 940) < 640
			self.title.TextSize = compact and 22 or 28

			if previousWidth ~= self.layoutWidth then
				self.surface.CanvasPosition = Vector2.new(0, 0)
			end
		end
	end

	self.modal.Destroying:Connect(cancelAnimations)

	return self
end

return DailyUI
