-- Player statistics use the existing authoritative profile. No Vincent panel is created here.
local PlayerProfileUI = {}
local ClubJournalUI=require(script.Parent:WaitForChild("ClubJournalUI"))
local function tr(language, ru, en)
	return language == "en" and en or ru
end

local function number(value, fallback)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.max(0, math.floor(value))
end

function PlayerProfileUI.create(ctx)
	local UserInputService = game:GetService("UserInputService")
	local C = { shell = Color3.fromRGB(25,27,31), raised = Color3.fromRGB(46,48,52),
		cream = Color3.fromRGB(244,240,231), muted = Color3.fromRGB(188,187,181),
		gold = Color3.fromRGB(221,193,151), line = Color3.fromRGB(87,89,93), green = Color3.fromRGB(158, 190, 153) }
	local self = { visible = false, achievementFilter="active", section="overview" }
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
	local old = ctx.gui:FindFirstChild("PlayerProfileRoot")
	if old then old:Destroy() end
	local root = frame(ctx.gui, { Name = "PlayerProfileRoot", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 7, 10), BackgroundTransparency = .76, Active = true, Visible = false, ZIndex = 220 })
	local shell = frame(root, { Name = "ProfilePanel", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 670), BackgroundColor3 = C.shell,
		Active = true, ClipsDescendants = true, ZIndex = 222 })
	round(shell, 20);shell.BackgroundTransparency=.16
	make("UIStroke", shell, { Color = C.gold, Transparency = 0.5, Thickness = 1 })
	frame(shell, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.gold })
	local kicker = text(shell, "Kicker", UDim2.fromOffset(24, 19), UDim2.new(1, -100, 0, 18), 11, C.gold)
	local heading = text(shell, "Heading", UDim2.fromOffset(24, 40), UDim2.new(1, -100, 0, 35), 25)
	heading.Font = Enum.Font.BuilderSansBold
	local close = make("TextButton", shell, { Name = "Close", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 22), Size = UDim2.fromOffset(44, 44), BorderSizePixel = 0,
		BackgroundColor3 = C.raised, Text = "×", Font = Enum.Font.BuilderSansMedium, TextSize = 25, TextColor3 = C.cream, ZIndex = 227 })
	round(close, 4)
	local sectionTabs=frame(shell,{Name="ProfileSections",Position=UDim2.fromOffset(20,84),Size=UDim2.new(1,-40,0,44),BackgroundTransparency=1})
    local sectionButtons={}
    for index,key in ipairs({"overview","achievements"})do
        local button=make("TextButton",sectionTabs,{Name="ProfileSection_"..key,Position=UDim2.new((index-1)/2,0,0,0),Size=UDim2.new(.5,-6,1,0),BorderSizePixel=0,BackgroundColor3=C.raised,TextColor3=C.cream,Font=Enum.Font.BuilderSansBold,TextSize=14,ZIndex=226})
        round(button,14);sectionButtons[key]=button
        button.Activated:Connect(function()self.section=key;self:render()end)
    end
    local scroll = make("ScrollingFrame", shell, { Name = "ProfileScroll", Position = UDim2.fromOffset(20, 140),
		Size = UDim2.new(1, -40, 1, -158), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = C.gold, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 223 })
	make("UIListLayout", scroll, { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	make("UIPadding", scroll, { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
    local profileCard=frame(scroll,{Name="ProfileSummary",Size=UDim2.new(1,0,0,430),BackgroundColor3=C.shell,LayoutOrder=1})
    local profileRank=text(profileCard,"Rank",UDim2.fromOffset(12,10),UDim2.new(1,-24,0,34),23,C.cream)
    profileRank.Font=Enum.Font.BuilderSansBold
    local profileProgress=text(profileCard,"Progress",UDim2.fromOffset(12,50),UDim2.new(1,-24,0,26),12,C.muted)
    profileProgress.Font=Enum.Font.BuilderSansMedium
    local xpTrack=frame(profileCard,{Position=UDim2.fromOffset(12,86),Size=UDim2.new(1,-24,0,8),BackgroundColor3=C.line})
    local xpFill=frame(xpTrack,{Name="XPFill",Size=UDim2.fromScale(0,1),BackgroundColor3=C.gold,ZIndex=225})
    local profileStats1=frame(profileCard,{Name="Stats1",Position=UDim2.fromOffset(12,108),Size=UDim2.new(1,-24,0,82),BackgroundTransparency=1})
    local metricCells={}
    for index,key in ipairs({"Matches","Wins","Losses","WinRate"})do
        local cell=frame(profileStats1,{Name=key,BackgroundColor3=C.raised})
        round(cell,4)
        local caption=text(cell,"Caption",UDim2.fromOffset(12,9),UDim2.new(1,-24,0,20),10,C.muted)
        caption.Font=Enum.Font.BuilderSansMedium
        local value=text(cell,"Value",UDim2.fromOffset(12,32),UDim2.new(1,-24,0,40),29,C.cream)
        metricCells[index]={cell=cell,caption=caption,value=value}
    end
    local profileStats2=frame(profileCard,{Name="Stats2",Position=UDim2.fromOffset(12,202),Size=UDim2.new(1,-24,0,150),BackgroundTransparency=1})
    local detailCells={}
    for index,key in ipairs({"Wallet","LifetimeCoins","SpyWins","FirstCorrect","VotesSurvived"})do
        local row=frame(profileStats2,{Name=key,Position=UDim2.fromOffset(0,(index-1)*30),Size=UDim2.new(1,0,0,30),BackgroundTransparency=1})
        local caption=text(row,"Caption",UDim2.new(),UDim2.new(1,-96,1,0),12,C.muted)
        caption.Font=Enum.Font.BuilderSansMedium
        local value=text(row,"Value",UDim2.new(1,-88,0,0),UDim2.fromOffset(88,30),15,C.cream)
        value.TextXAlignment=Enum.TextXAlignment.Right
        detailCells[index]={caption=caption,value=value}
    end
    local profileNext=text(profileCard,"NextRank",UDim2.fromOffset(12,365),UDim2.new(1,-24,0,52),12,C.gold)
    profileNext.Font=Enum.Font.BuilderSansMedium

	local reconnect = make("TextButton", scroll, {Name="Reconnect",Size=UDim2.new(1,0,0,46),LayoutOrder=2,
        BorderSizePixel=0,BackgroundColor3=C.gold,TextColor3=C.shell,Font=Enum.Font.BuilderSansMedium,TextSize=14,ZIndex=226,Visible=false})
    round(reconnect,8)
	local section = text(scroll, "AchievementHeading", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 33), 13, C.gold)
	section.LayoutOrder = 3
	local achievementCards = {}
    local filters=frame(scroll,{Name="AchievementFilters",Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,LayoutOrder=4})
    local filterButtons={}
    for index,key in ipairs({"active","completed","all"}) do
        local button=make("TextButton",filters,{Name="AchievementFilter_"..key,Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-6,1,0),
            BackgroundColor3=C.raised,BorderSizePixel=0,Font=Enum.Font.BuilderSansMedium,TextSize=12,TextColor3=C.muted,ZIndex=226})
        round(button,4);filterButtons[key]=button
        button.Activated:Connect(function()self.achievementFilter=key;self:render()end)
    end
	local pendingConnection
	local function updateButton()
        local p=ctx.profile()
        reconnect.Visible=not (p and p.ready)
        reconnect.Active=reconnect.Visible and not (ctx.pending and ctx.pending())
        reconnect.AutoButtonColor=reconnect.Active
        reconnect.Text=copy("ПОВТОРИТЬ ПОДКЛЮЧЕНИЕ","RECONNECT")
    end
	local function layout()
		local camera = workspace.CurrentCamera
		local viewport=ctx.gui.AbsoluteSize
		if viewport.X<=0 or viewport.Y<=0 then viewport=camera and camera.ViewportSize or Vector2.new(1280,720) end
		shell.Size = UDim2.fromOffset(math.max(1, math.min(700, viewport.X - 24)), math.max(1, math.min(720, viewport.Y - 32)))
        heading.TextSize=viewport.X<440 and 22 or 28
        local compact=viewport.X<540
        profileRank.TextSize=compact and 18 or 23
        local columns=compact and 2 or 4
        for index,metric in ipairs(metricCells)do
            metric.cell.Position=UDim2.new(((index-1)%columns)/columns,0,0,math.floor((index-1)/columns)*92)
            metric.cell.Size=UDim2.new(1/columns,-8,0,82)
        end
        profileStats1.Size=UDim2.new(1,-24,0,compact and 174 or 82)
        profileStats2.Position=UDim2.fromOffset(12,compact and 294 or 202)
        profileNext.Position=UDim2.fromOffset(12,compact and 457 or 365)
        profileCard.Size=UDim2.new(1,0,0,compact and 522 or 430)
	end
	function self:resize()
		layout()
	end
	function self:render()
        profileCard.Visible=self.section=="overview"
        section.Visible=self.section=="achievements";filters.Visible=section.Visible
        for key,button in pairs(sectionButtons)do
            button.Text=key=="overview" and copy("Статистика","Overview") or copy("Достижения","Achievements")
            button.BackgroundColor3=self.section==key and C.gold or C.raised
            button.TextColor3=self.section==key and C.shell or C.muted
        end
        scroll.CanvasPosition=Vector2.new()
        local profile = ctx.profile()
		kicker.Text = "SPY CLUB · " .. copy("ПРОФИЛЬ", "PROFILE")
		heading.Text = copy("ЛИЧНОЕ ДЕЛО", "PLAYER DOSSIER")
		local ready=profile and profile.ready==true
		local level=ready and number(profile.level,1) or 1
		local xpInto=ready and number(profile.xpIntoLevel,0) or 0
		local xpTo=ready and number(profile.xpToNextLevel,100) or 100
		local rounds=ready and number(profile.rounds,0) or 0
		local wins=ready and number(profile.wins,0) or 0
		local losses=math.max(0,rounds-wins)
		local winrate=rounds>0 and math.floor((wins/rounds)*100+0.5) or 0
		local metrics=ready and profile.club and profile.club.metrics or {}
		profileRank.Text=ready and (copy("УРОВЕНЬ ","LEVEL ")..level.."  ·  "..tostring(profile.rank or copy("Гость","Guest"))) or copy("Профиль не подключён","Profile not connected")
		profileProgress.Text=ready and (copy("Всего ","Total ")..number(profile.xp,0).." XP  ·  "..xpInto.." / 100  ·  "..copy("Осталось ","Remaining ")..xpTo.." XP") or copy("Повтори подключение ниже. Лобби доступно.","Reconnect below. The lobby remains available.")
		xpFill.Size=UDim2.fromScale(math.clamp(xpInto/100,0,1),1)
        local metricCaptions={copy("Матчи","Matches"),copy("Победы","Wins"),copy("Поражения","Losses"),copy("Винрейт","Win rate")}
        local metricValues={rounds,wins,losses,winrate.."%"}
        for index,metric in ipairs(metricCells)do
            metric.caption.Text=metricCaptions[index]
            metric.value.Text=ready and tostring(metricValues[index]) or "—"
        end
        local detailCaptions={copy("Монеты в кошельке","Wallet coins"),copy("Получено монет за всё время","Lifetime coins received"),copy("Победы шпионом","Spy wins"),copy("Первым вычислил шпиона","First to identify the spy"),copy("Пережил голосование","Votes survived")}
        local detailValues={number(profile and profile.coins,0),number(profile and profile.coinsEarned,number(profile and profile.coins,0)),number(metrics.spyWins,0),number(metrics.firstCorrect,0),number(metrics.survivedVotes,0)}
        for index,detail in ipairs(detailCells)do
            detail.caption.Text=detailCaptions[index]
            detail.value.Text=ready and tostring(detailValues[index]) or "—"
        end
		if not ready then
            profileNext.Text=""
        elseif profile.nextRank then
			profileNext.Text=copy("Следующий ранг: ","Next rank: ")..tostring(profile.nextRank).."\n"..copy("Осталось ","Remaining ")..tostring(profile.xpToNextRank or 0).." XP · "..tostring(profile.levelsToNextRank or 0)..copy(" ур. до уровня "," levels to level ")..tostring(profile.nextRankLevel)
		else
			profileNext.Text=copy("Высший ранг клуба достигнут","Highest club rank reached")
		end
		section.Text = copy("ЗНАКИ КЛУБА", "CLUB HONORS")
        local captions={active=copy("В процессе","In progress"),completed=copy("Получено","Completed"),all=copy("Все","All")}
        for key,button in pairs(filterButtons) do
            button.Text=captions[key];button.BackgroundColor3=self.achievementFilter==key and C.gold or C.raised
            button.TextColor3=self.achievementFilter==key and C.shell or C.muted
        end
		for _, card in ipairs(achievementCards) do card:Destroy() end
		achievementCards = {}
		local allRows = ClubJournalUI.achievementViews(profile, language())
        local rows={};local completed=0
        for _,row in ipairs(allRows) do
            if row.unlocked then completed+=1 end
            if self.achievementFilter=="all" or (self.achievementFilter=="completed" and row.unlocked)
                or (self.achievementFilter=="active" and not row.unlocked) then table.insert(rows,row) end
        end
        table.sort(rows,function(a,b) if a.progress==b.progress then return a.id<b.id end;return a.progress>b.progress end)
        section.Text=section.Text.."  ·  "..completed.." / "..#allRows
		if #rows == 0 then
			local empty = text(scroll, "Loading", UDim2.new(), UDim2.new(1, 0, 0, 50), 14, C.muted)
			empty.LayoutOrder = 5;empty.Visible=self.section=="achievements"
			empty.Text = ready and copy("В этой подборке пока нет знаков.","No honors in this selection yet.") or copy("Ожидаем данные достижений…", "Waiting for achievement records…")
			table.insert(achievementCards, empty)
		end
		for index, row in ipairs(rows) do
			local card = frame(scroll, { Name = "Achievement_" .. tostring(row.id), Size = UDim2.new(1, 0, 0, 140),
				BackgroundColor3 = C.raised, LayoutOrder = index + 4, Visible=self.section=="achievements" })
			round(card, 5)
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
		if ctx.setActivePanel then ctx.setActivePanel("profile") end
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
		if ctx.getActivePanel and ctx.getActivePanel()=="profile" then ctx.setActivePanel(nil) end
		self.visible = false
		root.Visible = false
		if pendingConnection then pendingConnection:Disconnect(); pendingConnection = nil end
	end
	function self:isVisible() return self.visible end
	reconnect.Activated:Connect(function()
        local p=ctx.profile()
        if not (p and p.ready) and not (ctx.pending and ctx.pending()) then ctx.request("retry") end
    end)
	close.Activated:Connect(function() self:close() end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if self.visible and not processed and input.KeyCode == Enum.KeyCode.Escape then self:close() end
	end)
	-- Use the inset-safe canvas; rotation and device safe-area changes resize visible panels.
	local sizeConnection=ctx.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then layout()end end)
	root.Destroying:Connect(function()sizeConnection:Disconnect()end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() if self.visible then layout() end end)
	return self
end

return PlayerProfileUI
