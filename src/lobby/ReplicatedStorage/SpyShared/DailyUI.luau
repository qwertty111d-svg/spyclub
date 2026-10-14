local TweenService = game:GetService("TweenService")

local ModalUI = require(script.Parent.ModalUI)
local Catalog = require(script.Parent.Catalog)
local Preview3D = require(script.Parent.Preview3D)
local IconUI = require(script.Parent.IconUI)
local Calendar = require(script.Parent.DailyRewardConfig)

local DailyUI = {}

local REWARDS=Calendar.Rewards

-- Все настройки внешнего вида — здесь.
local STYLE = {
	Background = Color3.fromRGB(20,21,24),
	Card = Color3.fromRGB(31,32,36),
	CardHover = Color3.fromRGB(43,44,49),
	Current = Color3.fromRGB(48,49,54),

	Border = Color3.fromRGB(111,113,120),
	Cream = Color3.fromRGB(245,245,247),
	Text = Color3.fromRGB(245,245,247),
	Muted = Color3.fromRGB(169,171,179),
	Gold = Color3.fromRGB(238,238,241),
	Collected = Color3.fromRGB(151,153,161),
	Ink = Color3.fromRGB(19,21,23),

	HeadingFont = Enum.Font.BuilderSansBold,
	BodyFont = Enum.Font.BuilderSansMedium,
	BoldFont = Enum.Font.BuilderSansBold,
}

local STRINGS = {
	title = { "Семь дней", "Seven days" },
	subtitle = {
		"Сегодня · %s",
		"Today · %s",
	},
	day = { "ДЕНЬ %d", "DAY %d" },
	coins = { "МОНЕТ", "COINS" },
	today = { "СЕГОДНЯ", "TODAY" },
	collected = { "ПОЛУЧЕНО", "COLLECTED" },
	later = { "ДАЛЕЕ", "UP NEXT" },
	claim = { "ЗАБРАТЬ %s", "CLAIM %s" },
	claimed = { "НАГРАДА ПОЛУЧЕНА", "REWARD CLAIMED" },
	loading = { "ЗАГРУЗКА…", "LOADING…" },
	retry = { "ПОВТОРИТЬ", "TRY AGAIN" },
	ready = {
		"Бесплатная награда готова.",
		"Your free reward is ready.",
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
    local focusDay, focusWidth

	local function tr(key, ...)
		local chinese={title="七日奖励",subtitle="每日免费 · %s",day="第 %d 天",coins="硬币",today="今天",collected="已领取",later="即将解锁",claim="领取 %s",claimed="已领取奖励",loading="加载中…",retry="重试",ready="免费奖励已准备就绪。",next="下一份奖励：%s",unavailable="正在等待奖励数据…"}
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

		local projected=now>=nextAt
		local continueCycle=projected and not daily.available and now<nextAt+86400 and streak<7
		if projected then
			nextDay = not daily.available and now < nextAt + 86400
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
			projected=projected,
			continueCycle=continueCycle,
		}
	end

	local function statusKey(state)
		return table.concat({
			tostring(state.loaded),
			tostring(state.hasSchedule),
			tostring(state.available),
			tostring(state.nextDay),
			tostring(state.progress),
			tostring(state.projected),
			tostring(state.continueCycle),
		}, ":")
	end

	local function rewardExtra(reward)
		local parts={}
		if reward.itemId and (reward.rolls or 0)>0 then parts[#parts+1]="+"..tostring(reward.rolls).." Roll"end
		if (reward.rolls or 0)>0 and(reward.coins or 0)>0 then parts[#parts+1]="+"..tostring(reward.coins).." "..tr("coins")end
		if reward.compensated then parts[#parts+1]=ctx.language()=="en"and"Collection repeat"or"Повтор коллекции"end
		return table.concat(parts," · ")
	end

	local function rewardName(reward)
		if reward.itemId then local item=Catalog.ById[reward.itemId];return item and(ctx.language()=="en"and item.en or item.ru)or reward.itemId end
		if (reward.rolls or 0)>0 then return tostring(reward.rolls)..(reward.rolls==1 and" Roll"or" Rolls")end
		if(reward.xp or 0)>0 then return tostring(reward.xp).." XP"end
		return tostring(reward.coins or 0).." "..tr("coins")
	end

	local function mountPreview(parent,reward)
		if reward.itemId then Preview3D.mount(parent,Catalog.ById[reward.itemId])
		elseif (reward.rolls or 0)>0 then
			make("TextLabel",parent,{Text="↻",TextSize=20,Font=Enum.Font.BuilderSansBold,TextColor3=C.Gold,BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
		elseif reward.caseId then Preview3D.mount(parent,nil,reward.caseId)
		elseif (reward.coins or 0)>0 then IconUI.draw(parent,"coin",C.Gold)
		elseif(reward.xp or 0)>0 then make("TextLabel",parent,{Text="XP",TextSize=15,Font=Enum.Font.BuilderSansBold,TextColor3=C.Gold,BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})end
	end

	local function currentReward(day)
		local profile=ctx.profile()or{}
		local daily=profile.daily or{}
		if isFinite(daily.nextAt)and os.time()>=daily.nextAt then return Calendar.resolve(day,profile)end
		if daily.reward and(daily.reward.day==day or daily.reward.day==nil and daily.nextStreak==day)then return daily.reward end
		return(daily.rewards or REWARDS)[day]or Calendar.resolve(day,profile)
	end

	-- Нижняя панель находится вне прокрутки.
	local footer = make("Frame", self.modal, {
		Name = "DailyFooter",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -18),
		Size = UDim2.new(1, -40, 0, 80),
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
	})

	local countdown = text(
		footer,
		"Countdown",
		"",
		UDim2.new(),
		UDim2.new(1, 0, 0, 24),
		14,
		C.Muted,
		C.BodyFont
	)

	countdown.TextXAlignment = Enum.TextXAlignment.Left

	local claimButton = make("TextButton", footer, {
		Name = "ClaimReward",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 44),

		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,

		AutoButtonColor = false,
		Text = "",
		TextSize = 16,
		TextScaled = false,
		Font = C.HeadingFont,
		TextColor3 = C.Ink,
	})

	corner(claimButton, 4)
	stroke(claimButton, C.Gold, 1, 0.45)

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
				BackgroundColor3 = Color3.fromRGB(255,255,255),
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

	local function buildCard(parent, day, reward, state, short)
        local collected = state.loaded and day <= state.progress
        local current = state.loaded and state.hasSchedule and not collected and day == state.nextDay
        local card = make("Frame", parent, {Name="Day"..day,Size=UDim2.fromScale(1,1),
            BackgroundColor3=current and C.Current or C.Card,BackgroundTransparency=current and .12 or .42,
            BorderSizePixel=0,ClipsDescendants=true})
        stroke(card,current and C.Gold or C.Border,1,current and .2 or .72)
        local w,h=parent.Size.X.Offset,parent.Size.Y.Offset
        local inset=short and 10 or 14
        local dayLabel=text(card,"DayLabel",tr("day",day),UDim2.fromOffset(inset,short and 6 or 16),UDim2.fromOffset(w-inset*2,18),10,C.Muted,C.BodyFont)
        dayLabel.TextWrapped=false
        local numeral=text(card,"DayNumber",string.format("%02d",day),UDim2.fromOffset(inset,short and 23 or 40),UDim2.fromOffset(w-inset*2,short and 28 or 60),short and 28 or 64,collected and C.Collected or C.Cream,Enum.Font.Garamond)
        numeral.TextTransparency=collected and .45 or .08
        local previewHost=make("Frame",card,{Name="RewardPreview",BackgroundTransparency=1,
            Position=UDim2.fromOffset(inset,short and 50 or 112),Size=UDim2.fromOffset(short and 28 or 64,short and 24 or 64)})
        mountPreview(previewHost,reward)
        local nameY=short and 78 or math.min(190,h-100)
        local name=text(card,"RewardName",rewardName(reward),UDim2.fromOffset(inset,nameY),UDim2.fromOffset(w-inset*2,short and 32 or 48),short and 15 or 22,C.Cream,Enum.Font.Garamond)
        name.TextWrapped=true
        local extra=text(card,day==7 and "Bonus" or "ExtraReward",rewardExtra(reward),UDim2.fromOffset(inset,nameY+(short and 32 or 50)),UDim2.fromOffset(w-inset*2,short and 16 or 28),10,C.Muted,C.BodyFont)
        extra.TextWrapped=true
        local caption=collected and ("✓  "..tr("collected")) or current and state.available and tr("today") or tr("later")
        local status=text(card,"RewardStatus",caption,UDim2.new(0,inset,1,-(short and 20 or 34)),UDim2.fromOffset(w-inset*2,18),10,current and C.Gold or C.Muted,C.BodyFont)
        status.TextWrapped=false
        local rule=make("Frame",card,{Name="DayRule",BackgroundColor3=C.Border,BackgroundTransparency=.65,BorderSizePixel=0,
            Position=UDim2.new(0,inset,1,-(short and 24 or 44)),Size=UDim2.new(1,-inset*2,0,1)})
        if short then previewHost.Visible=false;rule.Visible=false;extra.Visible=false end
    end

	function self:render()
		cancelAnimations()
		self:clear()
		local state = getStatus()
		local width = self.layoutWidth or 940
		local compact = width < 640
		local short = self.modal.Size.Y.Offset < 400
		local profile = ctx.profile() or {}
		local configuredRewards = (profile.daily or {}).rewards or REWARDS
		local daily=profile.daily or{}
		if state.projected then
			configuredRewards={}
			for day=1,7 do
				local claimed=state.continueCycle and day<=(daily.streak or 0)and(daily.rewards or{})[day]
				configuredRewards[day]=claimed or Calendar.resolve(day,profile)
			end
		end
		lastStatusKey = statusKey(state)
		lastButtonState = nil

		self.modal.BackgroundColor3 = C.Background
		self.modal.BackgroundTransparency = .18
		corner(self.modal, 2)
		local modalBorder = self.modal:FindFirstChildOfClass("UIStroke")
		if modalBorder then
			modalBorder.Color = C.Border
			modalBorder.Thickness = 1
			modalBorder.Transparency = 0.35
		end
		self.title.Text = tr("title")
		self.title.Font = Enum.Font.Garamond
		self.title.TextScaled = false
		self.title.TextSize = compact and 34 or 52
		self.title.TextColor3 = C.Cream
		self.title.TextXAlignment = Enum.TextXAlignment.Left
		self.title.Position = UDim2.fromOffset(20, 16)
		self.title.Size = UDim2.new(1, -88, 0, short and 36 or 56)
        if self.closeButton then
            self.closeButton.Position = UDim2.new(1,-64,0,10)
            self.closeButton.BackgroundTransparency=1
            self.closeButton.TextColor3=C.Text
            local border=self.closeButton:FindFirstChildOfClass("UIStroke")
            if border then border.Transparency=1 end
        end
		self.hint.Visible = not short
		self.hint.Text = tr("subtitle", rewardName(currentReward(state.nextDay)))
		self.hint.Font = C.BodyFont
		self.hint.TextScaled = false
		self.hint.TextSize = 14
		self.hint.TextColor3 = C.Muted
		self.hint.TextXAlignment = Enum.TextXAlignment.Left
		self.hint.Position = UDim2.fromOffset(20, 76)
		self.hint.Size = UDim2.new(1, -40, 0, 28)

		local contentTop = short and 66 or 118
		local footerHeight = short and 78 or 96
		footer.Position = UDim2.new(0, 20, 1, -14)
		footer.Size = UDim2.new(1, -40, 0, footerHeight)
		claimButton.Size = UDim2.new(1, 0, 0, short and 44 or 52)
		countdown.Size = UDim2.new(1, 0, 0, 22)
		self.surface.Position = UDim2.fromOffset(18, contentTop)
		self.surface.Size = UDim2.new(1, -36, 1, -contentTop - footerHeight - 30)
		self.surface.ScrollingDirection = Enum.ScrollingDirection.X
        self.surface.AutomaticCanvasSize = Enum.AutomaticSize.None
        self.surface.ScrollBarThickness = 3
		self.surface.ScrollBarImageColor3 = C.Gold
		if self.headerRule then
			self.headerRule.Position = UDim2.fromOffset(20, contentTop - 8)
			self.headerRule.Size = UDim2.new(1, -40, 0, 1)
		end
		local footerRule = footer:FindFirstChild("FooterRule")
		if not footerRule then
			footerRule = make("Frame", footer, {Name = "FooterRule", BorderSizePixel = 0, BackgroundColor3 = C.Border, BackgroundTransparency = 0.45})
		end
		footerRule.Position = UDim2.fromOffset(0, -8)
		footerRule.Size = UDim2.new(1, 0, 0, 1)

        -- One seven-day canvas. Narrow screens reveal the next card and scroll
        -- horizontally; the authoritative claim action never scrolls away.
        local gap=8
        local available=math.max(1,width-46)
        local cardWidth=math.max(short and 112 or 126,math.floor((available-gap*6)/7.35))
        if not compact and not short then cardWidth=math.floor((available-gap*6)/7.35) end
        local finaleWidth=math.floor(cardWidth*1.35)
        local canvasWidth=cardWidth*6+finaleWidth+gap*6
        local cardHeight=math.max(short and 126 or 240,math.min(340,self.surface.Size.Y.Offset+self.modal.Size.Y.Offset-12))
        local board=self:row(cardHeight)
        board.Name="RewardBoard"
        board.Size=UDim2.fromOffset(canvasWidth,cardHeight)
        self.surface.CanvasSize=UDim2.fromOffset(canvasWidth+12,0)
        for day,reward in ipairs(configuredRewards)do
            local slot=make("Frame",board,{Name="RewardSlot"..day,BackgroundTransparency=1,
                Position=UDim2.fromOffset((day-1)*(cardWidth+gap),0),
                Size=UDim2.fromOffset(day==7 and finaleWidth or cardWidth,cardHeight)})
            buildCard(slot,day,reward,state,short)
        end
        if focusDay~=state.nextDay or focusWidth~=width or playEntrance then
            self.surface.CanvasPosition=Vector2.new(math.clamp((state.nextDay-1)*(cardWidth+gap),0,math.max(0,canvasWidth-available+12)),0)
            focusDay,focusWidth=state.nextDay,width
        end

		claimButton.TextSize = 16
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
			or (state.available and tr("claim", rewardName(currentReward(state.nextDay))))
			or tr("claimed")

		claimButton.Selectable = enabled
		claimButton.Active = enabled

		local buttonState = tostring(enabled)

		if buttonState ~= lastButtonState then
			lastButtonState = buttonState

			animate(claimButton, 0.18, {
				BackgroundColor3 = enabled and C.Gold or C.Card,
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
		baseResize(self)
        if self.visible then self:render()end

		-- ModalUI может повторно менять размер заголовка.
		if self.visible then
			local compact = (self.layoutWidth or 940) < 640
			self.title.TextSize = compact and 34 or 52

		end
	end

	self.modal.Destroying:Connect(cancelAnimations)

	return self
end

return DailyUI
