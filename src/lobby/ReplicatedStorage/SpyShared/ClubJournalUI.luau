-- ReplicatedStorage > SpyShared > ClubJournalUI
-- Presentation only. All progress, task eligibility and rewards come from the server.
local ClubJournalUI = {}

local function tr(language, ru, en)
	return language == "en" and en or ru
end

local function number(value, fallback)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.max(0, math.floor(value))
end

function ClubJournalUI.dailyView(profile, language)
	local daily = profile and profile.club and profile.club.vincent
	local view = { status = "loading", title = tr(language, "Поручение Винсента", "Vincent's assignment"),
		body = tr(language, "Ожидаем данные клуба…", "Waiting for club records…"),
		button = tr(language, "Загрузка…", "Loading…"), reward = 100 }
	if not profile or not profile.ready or type(daily) ~= "table" then return view end
	view.rumor = tr(language, daily.rumorRu, daily.rumorEn)
	view.secret = tr(language, daily.secretRu, daily.secretEn)
	view.reward = number(daily.reward, 100)
	if daily.claimed then
		view.status = "claimed"
		view.body = tr(language, "Хорошая работа. Награда получена. Следующее поручение — завтра.", "Good work. Reward collected. Your next assignment arrives tomorrow.")
		view.button = tr(language, "Награда получена", "Reward collected")
	elseif daily.accepted and daily.completed then
		view.status = "complete"
		view.action = "vincentClaim"
		view.body = tr(language, "Дело сделано. Твои 100 монет ждут у стойки.", "Job done. Your 100 coins are waiting at the bar.")
		view.button = tr(language, "Забрать 100 монет", "Collect 100 coins")
	elseif daily.accepted then
		view.status = "active"
		view.body = tr(language, "Заверши один матч, участвуя в игре, и возвращайся за 100 монетами.", "Finish one match as an active player, then return for 100 coins.")
		view.button = tr(language, "Поручение принято", "Assignment accepted")
	else
		view.status = "available"
		view.action = "vincentAccept"
		view.body = tr(language, "Есть дело: заверши один матч, участвуя в игре. Награда — 100 монет. Один раз в день.", "An assignment: finish one match as an active player. Reward: 100 coins, once per day.")
		view.button = tr(language, "Принять поручение", "Accept assignment")
	end
	return view
end

function ClubJournalUI.achievementViews(profile, language)
	local result = {}
	local achievements = profile and profile.club and profile.club.achievements or {}
	for _, achievement in ipairs(achievements) do
		local target = math.max(1, number(achievement.target, 1))
		local value = number(achievement.value, 0)
		table.insert(result, { id = achievement.id, title = tr(language, achievement.nameRu, achievement.nameEn) or "—",
			detail = tr(language, achievement.detailRu, achievement.detailEn) or "", value = value, target = target,
			progress = math.clamp(value / target, 0, 1), reward = number(achievement.reward, 0), unlocked = achievement.unlocked == true })
	end
	return result
end

function ClubJournalUI.create(ctx)
	local UserInputService = game:GetService("UserInputService")
	local C = { shell = Color3.fromRGB(25,27,31), raised = Color3.fromRGB(46,48,52),
		cream = Color3.fromRGB(244,240,231), muted = Color3.fromRGB(188,187,181),
		gold = Color3.fromRGB(221,193,151), line = Color3.fromRGB(87,89,93), green = Color3.fromRGB(158, 190, 153) }
	local self = { visible = false }
	local daily
	local function language() return ctx.language and ctx.language() or "ru" end
	local function copy(ru, en) return tr(language(), ru, en) end
	local function make(className, parent, props)
		local instance = Instance.new(className)
		for key, value in pairs(props or {}) do instance[key] = value end
		instance.Parent = parent
		return instance
	end
	local function frame(parent, props)
		props.BorderSizePixel = 0
		props.ZIndex = props.ZIndex or 224
		return make("Frame", parent, props)
	end
	local function round(parent, radius)
		make("UICorner", parent, { CornerRadius = UDim.new(0, math.max(radius or 12,12)) })
	end
	local function text(parent, name, position, size, fontSize, color)
		return make("TextLabel", parent, { Name = name, Position = position, Size = size,
			BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", TextSize = fontSize,
			TextColor3 = color or C.cream, Font = Enum.Font.BuilderSansMedium, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 226 })
	end
	local old = ctx.gui:FindFirstChild("ClubJournalRoot")
	if old then old:Destroy() end
	local root = frame(ctx.gui, { Name = "ClubJournalRoot", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 7, 10), BackgroundTransparency = .76, Active = true, Visible = false, ZIndex = 220 })
	local shell = frame(root, { Name = "JournalPanel", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 670), BackgroundColor3 = C.shell,
		Active = true, ClipsDescendants = true, ZIndex = 222 })
	round(shell, 20);shell.BackgroundTransparency=.16
	make("UIStroke", shell, { Color = C.line, Transparency = .68, Thickness = 1 })
	frame(shell, { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.gold })
	local kicker = text(shell, "Kicker", UDim2.fromOffset(24, 19), UDim2.new(1, -100, 0, 18), 11, C.gold)
	local heading = text(shell, "Heading", UDim2.fromOffset(24, 40), UDim2.new(1, -100, 0, 35), 25)
	heading.Font = Enum.Font.BuilderSansBold
	local close = make("TextButton", shell, { Name = "Close", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 22), Size = UDim2.fromOffset(44, 44), BorderSizePixel = 0,
		BackgroundColor3 = C.raised, Text = "×", Font = Enum.Font.BuilderSansMedium, TextSize = 25, TextColor3 = C.cream, ZIndex = 227 })
	round(close, 10)
	local scroll = make("ScrollingFrame", shell, { Name = "JournalScroll", Position = UDim2.fromOffset(20, 91),
		Size = UDim2.new(1, -40, 1, -109), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = C.gold, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 223 })
	make("UIListLayout", scroll, { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	make("UIPadding", scroll, { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	local taskCard = frame(scroll, { Name = "DailyAssignment", Size = UDim2.new(1, 0, 0, 186),
		BackgroundColor3 = C.raised, LayoutOrder = 2 })
	round(taskCard, 12)
	local taskTitle = text(taskCard, "Title", UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 26), 17, C.gold)
	taskTitle.Font=Enum.Font.BuilderSansBold
	local taskBody = text(taskCard, "Body", UDim2.fromOffset(16, 42), UDim2.new(1, -32, 0, 64), 14, C.muted)
	taskBody.Font = Enum.Font.BuilderSansMedium
	local taskButton = make("TextButton", taskCard, { Name = "TaskAction", Position = UDim2.fromOffset(16, 124),
		Size = UDim2.new(1, -32, 0, 46), BorderSizePixel = 0, Font = Enum.Font.BuilderSansMedium,
		Text = "", TextSize = 14, TextWrapped = true, BackgroundColor3 = C.gold, TextColor3 = C.shell, ZIndex = 226 })
	round(taskButton, 8)
	local section = text(scroll, "AchievementHeading", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 33), 13, C.gold)
	section.LayoutOrder = 3
	local achievementCards = {}
	local pendingConnection
	local function updateButton()
		local pending = ctx.pending and ctx.pending()
		local enabled = daily and daily.action ~= nil and not pending
		taskButton.Active = enabled
		taskButton.Selectable = enabled
		taskButton.AutoButtonColor = enabled
		taskButton.BackgroundColor3 = enabled and C.gold or C.line
		taskButton.TextColor3 = enabled and C.shell or C.cream
		taskButton.Text = pending and copy("Ожидаем ответ…", "Waiting for confirmation…") or (daily and daily.button or "")
	end
	local function layout()
		local camera = workspace.CurrentCamera
		local viewport=ctx.gui.AbsoluteSize
        if viewport.X<=0 or viewport.Y<=0 then viewport=camera and camera.ViewportSize or Vector2.new(1280,720)end
		shell.Size = UDim2.fromOffset(math.max(1, math.min(700, viewport.X - 24)), math.max(1, math.min(720, viewport.Y - 32)))
		heading.TextSize = viewport.X < 440 and 21 or 25
	end
	function self:resize()
		layout()
	end
	function self:render()
		local profile = ctx.profile()
		daily = ClubJournalUI.dailyView(profile, language())
		kicker.Text = "SPY CLUB · " .. copy("ВИНСЕНТ", "VINCENT")
        heading.Text = copy("Журнал клуба", "Club journal")
        if not (profile and profile.ready) then
            daily={status="loading",action="retry",title=copy("Подключение журнала","Journal connection"),body=copy("Записи клуба пока недоступны. Повтори подключение.","Club records are unavailable. Reconnect to try again."),button=copy("ПОВТОРИТЬ ПОДКЛЮЧЕНИЕ","RECONNECT")}
        end
		taskTitle.Text = daily.title
		taskBody.Text = daily.body
		section.Text = copy("ДОСТИЖЕНИЯ", "ACHIEVEMENTS")
		for _, card in ipairs(achievementCards) do card:Destroy() end
		achievementCards = {}
		local rows = ClubJournalUI.achievementViews(profile, language())
		if #rows == 0 then
			local empty = text(scroll, "Loading", UDim2.new(), UDim2.new(1, 0, 0, 50), 14, C.muted)
			empty.LayoutOrder = 4
			empty.Text = copy("Ожидаем данные достижений…", "Waiting for achievement records…")
			table.insert(achievementCards, empty)
		end
		for index, row in ipairs(rows) do
			local card = frame(scroll, { Name = "Achievement_" .. tostring(row.id), Size = UDim2.new(1, 0, 0, 140),
				BackgroundColor3 = C.raised, LayoutOrder = index + 3 })
			round(card, 10)
			table.insert(achievementCards, card)
			local title = text(card, "Title", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 26), 17)
			title.Text = row.title
			local detail = text(card, "Detail", UDim2.fromOffset(16, 40), UDim2.new(1, -32, 0, 38), 13, C.muted)
			detail.Font = Enum.Font.BuilderSansMedium
			detail.Text = row.detail
			local progress = text(card, "Progress", UDim2.fromOffset(16, 82), UDim2.new(0.5, -16, 0, 23), 12, row.unlocked and C.green or C.muted)
			progress.Text = row.unlocked and copy("ВЫПОЛНЕНО", "COMPLETED") or (math.min(row.value, row.target) .. " / " .. row.target)
			local reward = text(card, "Reward", UDim2.new(0.5, 0, 0, 82), UDim2.new(0.5, -16, 0, 23), 12, row.unlocked and C.green or C.gold)
			reward.TextXAlignment = Enum.TextXAlignment.Right
			reward.Text = row.unlocked and copy("ПОЛУЧЕНО", "COLLECTED") or ("+" .. row.reward .. copy(" МОНЕТ", " COINS"))
			local track = frame(card, { Name = "Track", Position = UDim2.fromOffset(16, 116), Size = UDim2.new(1, -32, 0, 6), BackgroundColor3 = C.line })
			round(track, 3)
			local fill = frame(track, { Name = "Fill", Size = UDim2.fromScale(row.progress, 1), BackgroundColor3 = row.unlocked and C.green or C.gold, ZIndex = 225 })
			round(fill, 3)
		end
		updateButton()
		layout()
	end
	function self:update()
		if self.visible then self:render() end
	end
	function self:open()
		if ctx.closePanels then ctx.closePanels(nil) end
		self.visible = true
		root.Visible = true
		self:render()
		if not pendingConnection then
			local elapsed = 0
			pendingConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
				elapsed += dt
				if elapsed >= 0.2 then elapsed = 0; updateButton() end
			end)
		end
	end
	function self:close()
		self.visible = false
		root.Visible = false
		if pendingConnection then pendingConnection:Disconnect(); pendingConnection = nil end
	end
	function self:isVisible() return self.visible end
	taskButton.Activated:Connect(function()
		-- Re-read authority at activation, never trust the previously rendered button.
		local profile=ctx.profile()
        if not profile or not profile.ready then
            if not (ctx.pending and ctx.pending()) then ctx.request("retry") end
            return
        end
        local current = ClubJournalUI.dailyView(profile, language())
		if not current.action or (ctx.pending and ctx.pending()) then return end
		ctx.request(current.action)
		updateButton()
	end)
	close.Activated:Connect(function() self:close() end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if self.visible and not processed and input.KeyCode == Enum.KeyCode.Escape then self:close() end
	end)
	-- Layout follows the camera viewport. Recompute on replacement and on open/render.
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() if self.visible then layout() end end)
	return self
end

return ClubJournalUI
