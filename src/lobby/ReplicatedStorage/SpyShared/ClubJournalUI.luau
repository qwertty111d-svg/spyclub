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
 local UserInputService=game:GetService('UserInputService')
 local C={shell=Color3.fromRGB(26,27,31),raised=Color3.fromRGB(49,50,56),
  cream=Color3.fromRGB(245,245,247),muted=Color3.fromRGB(168,170,179),
  white=Color3.fromRGB(238,238,241),line=Color3.fromRGB(100,102,110)}
 local self={visible=false}
 local daily
 local function language()return ctx.language and ctx.language()or'ru'end
 local function copy(ru,en)return tr(language(),ru,en)end
 local function make(className,parent,props)
  local instance=Instance.new(className);for key,value in pairs(props or{})do instance[key]=value end;instance.Parent=parent;return instance
 end
 local function frame(parent,props)props.BorderSizePixel=0;props.ZIndex=props.ZIndex or 224;return make('Frame',parent,props)end
 local function round(parent,radius)make('UICorner',parent,{CornerRadius=UDim.new(0,radius or 2)})end
 local function text(parent,name,position,size,fontSize,color)
  return make('TextLabel',parent,{Name=name,Position=position,Size=size,BackgroundTransparency=1,BorderSizePixel=0,Text='',TextSize=fontSize,
   TextColor3=color or C.cream,Font=Enum.Font.BuilderSansMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=226})
 end
 local function line(parent,name,position,size)
  return frame(parent,{Name=name,Position=position,Size=size,BackgroundColor3=C.line,BackgroundTransparency=.74})
 end
 local old=ctx.gui:FindFirstChild('ClubJournalRoot');if old then old:Destroy()end
 local root=frame(ctx.gui,{Name='ClubJournalRoot',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(16,17,20),BackgroundTransparency=.78,Active=true,Visible=false,ZIndex=220})
 local shell=frame(root,{Name='JournalPanel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(820,720),BackgroundColor3=C.shell,BackgroundTransparency=.16,Active=true,ClipsDescendants=true,ZIndex=222})
 round(shell,3);make('UIStroke',shell,{Color=C.line,Transparency=.74,Thickness=1})
 local kicker=text(shell,'Kicker',UDim2.fromOffset(28,16),UDim2.new(1,-112,0,20),14,C.muted)
 local heading=text(shell,'Heading',UDim2.fromOffset(28,36),UDim2.new(1,-112,0,50),44);heading.Font=Enum.Font.Garamond
 local close=make('TextButton',shell,{Name='Close',AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-24,0,16),Size=UDim2.fromOffset(44,44),BorderSizePixel=0,
  BackgroundTransparency=1,Text='×',Font=Enum.Font.BuilderSansMedium,TextSize=25,TextColor3=C.cream,ZIndex=227})
 local headerLine=line(shell,'HeaderDivider',UDim2.fromOffset(28,98),UDim2.new(1,-56,0,1))
 local scroll=make('ScrollingFrame',shell,{Name='JournalScroll',Position=UDim2.fromOffset(28,112),Size=UDim2.new(1,-56,1,-132),BackgroundTransparency=1,BorderSizePixel=0,
  ScrollBarThickness=3,ScrollBarImageColor3=C.muted,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=223})
 make('UIListLayout',scroll,{Padding=UDim.new(0,16),SortOrder=Enum.SortOrder.LayoutOrder})
 make('UIPadding',scroll,{PaddingBottom=UDim.new(0,8),PaddingRight=UDim.new(0,8)})
 local taskCard=frame(scroll,{Name='DailyAssignment',Size=UDim2.new(1,0,0,210),BackgroundColor3=C.raised,BackgroundTransparency=.68,LayoutOrder=2});round(taskCard,2)
 local taskTitle=text(taskCard,'Title',UDim2.fromOffset(16,12),UDim2.new(1,-32,0,34),26);taskTitle.Font=Enum.Font.Garamond
 local taskBody=text(taskCard,'Body',UDim2.fromOffset(16,54),UDim2.new(1,-32,0,68),16,C.muted)
 local taskButton=make('TextButton',taskCard,{Name='TaskAction',Position=UDim2.fromOffset(16,142),Size=UDim2.new(1,-32,0,48),BorderSizePixel=0,Font=Enum.Font.BuilderSansMedium,
  Text='',TextSize=16,TextWrapped=true,BackgroundColor3=C.white,TextColor3=C.shell,ZIndex=226});round(taskButton,2)
 local section=text(scroll,'AchievementHeading',UDim2.new(),UDim2.new(1,0,0,36),16,C.muted);section.LayoutOrder=3
 local achievementCards={}
 local pendingConnection
 local function updateButton()
  local pending=ctx.pending and ctx.pending()
  local enabled=daily and daily.action~=nil and not pending
  taskButton.Active=enabled;taskButton.Selectable=enabled;taskButton.AutoButtonColor=enabled
  taskButton.BackgroundColor3=enabled and C.white or C.raised
  taskButton.BackgroundTransparency=enabled and 0 or .3
  taskButton.TextColor3=enabled and C.shell or C.muted
  taskButton.Text=pending and copy('Ожидаем ответ…','Waiting for confirmation…')or(daily and daily.button or'')
 end
 local function layout()
  local camera=workspace.CurrentCamera
  local viewport=ctx.gui.AbsoluteSize
  if viewport.X<=0 or viewport.Y<=0 then viewport=camera and camera.ViewportSize or Vector2.new(1280,720)end
  local narrow=viewport.X<520
  local pad=narrow and 16 or 28
  shell.Size=UDim2.fromOffset(math.max(1,math.min(820,viewport.X-24)),math.max(1,math.min(720,viewport.Y-24)))
  local short=shell.Size.Y.Offset<350
  local headerHeight=short and 86 or 106
  kicker.Position=UDim2.fromOffset(pad,short and 8 or 16);kicker.Size=UDim2.new(1,-pad*2-54,0,20)
  heading.Position=UDim2.fromOffset(pad,short and 28 or 36);heading.Size=UDim2.new(1,-pad*2-54,0,short and 40 or 50);heading.TextSize=viewport.X<340 and 28 or narrow and 32 or short and 36 or 44
  close.Position=UDim2.new(1,-pad,0,short and 8 or 16)
  headerLine.Position=UDim2.fromOffset(pad,headerHeight-8);headerLine.Size=UDim2.new(1,-pad*2,0,1)
  scroll.Position=UDim2.fromOffset(pad,headerHeight);scroll.Size=UDim2.new(1,-pad*2,1,-headerHeight-16)
  taskCard.Size=UDim2.new(1,0,0,narrow and 292 or 210)
  taskTitle.Position=UDim2.fromOffset(16,12);taskTitle.Size=UDim2.new(1,-32,0,narrow and 76 or 34);taskTitle.TextSize=narrow and 24 or 26
  taskBody.Position=UDim2.fromOffset(16,narrow and 96 or 54);taskBody.Size=UDim2.new(1,-32,0,narrow and 104 or 68)
  taskButton.Position=UDim2.fromOffset(16,narrow and 224 or 142)
  for _,card in ipairs(achievementCards)do
   if card.Name~='Loading'then
    card.Size=UDim2.new(1,0,0,narrow and 250 or 170)
    local title=card:FindFirstChild('Title');title.Size=UDim2.new(1,-32,0,narrow and 76 or 34);title.TextSize=narrow and 22 or 26
    local detail=card:FindFirstChild('Detail');detail.Position=UDim2.fromOffset(16,narrow and 96 or 54);detail.Size=UDim2.new(1,-32,0,narrow and 64 or 44)
    local progress=card:FindFirstChild('Progress');progress.Position=UDim2.fromOffset(16,narrow and 178 or 112)
    local reward=card:FindFirstChild('Reward');reward.Position=UDim2.new(.5,0,0,narrow and 178 or 112)
    card:FindFirstChild('Track').Position=UDim2.fromOffset(16,narrow and 226 or 150)
   end
  end
 end
 function self:resize()layout()end
 function self:render()
  local profile=ctx.profile();daily=ClubJournalUI.dailyView(profile,language())
  kicker.Text=copy('Винсент · Записи клуба','Vincent · Club records')
  heading.Text=copy('Журнал клуба','Club journal')
  if not(profile and profile.ready)then
   daily={status='loading',action='retry',title=copy('Подключение журнала','Journal connection'),body=copy('Записи клуба пока недоступны. Повтори подключение.','Club records are unavailable. Reconnect to try again.'),button=copy('Повторить подключение','Reconnect')}
  end
  taskTitle.Text=daily.title;taskBody.Text=daily.body;section.Text=copy('Достижения','Achievements')
  for _,card in ipairs(achievementCards)do card:Destroy()end;achievementCards={}
  local rows=ClubJournalUI.achievementViews(profile,language())
  if #rows==0 then
   local empty=text(scroll,'Loading',UDim2.new(),UDim2.new(1,0,0,72),16,C.muted);empty.LayoutOrder=4
   empty.Text=copy('Ожидаем данные достижений…','Waiting for achievement records…');table.insert(achievementCards,empty)
  end
  for index,row in ipairs(rows)do
   local card=frame(scroll,{Name='Achievement_'..tostring(row.id),Size=UDim2.new(1,0,0,170),BackgroundTransparency=1,LayoutOrder=index+3});table.insert(achievementCards,card)
   local title=text(card,'Title',UDim2.fromOffset(16,12),UDim2.new(1,-32,0,34),26);title.Font=Enum.Font.Garamond;title.Text=row.title
   local detail=text(card,'Detail',UDim2.fromOffset(16,54),UDim2.new(1,-32,0,44),16,C.muted);detail.Text=row.detail
   local progress=text(card,'Progress',UDim2.fromOffset(16,112),UDim2.new(.5,-16,0,24),14,row.unlocked and C.cream or C.muted)
   progress.Text=row.unlocked and copy('Выполнено','Completed')or(math.min(row.value,row.target)..' / '..row.target)
   local reward=text(card,'Reward',UDim2.new(.5,0,0,112),UDim2.new(.5,-16,0,24),14,row.unlocked and C.muted or C.cream)
   reward.TextXAlignment=Enum.TextXAlignment.Right;reward.Text=row.unlocked and copy('Получено','Collected')or('+'..row.reward..copy(' монет',' coins'))
   local track=frame(card,{Name='Track',Position=UDim2.fromOffset(16,150),Size=UDim2.new(1,-32,0,3),BackgroundColor3=C.line,BackgroundTransparency=.6})
   frame(track,{Name='Fill',Size=UDim2.fromScale(row.progress,1),BackgroundColor3=C.white,BackgroundTransparency=row.unlocked and .1 or .3,ZIndex=225})
  end
  updateButton();layout()
 end
 function self:update()if self.visible then self:render()end end
 function self:open()
  if ctx.closePanels then ctx.closePanels(nil)end
  self.visible=true;root.Visible=true;self:render()
  if not pendingConnection then
   local elapsed=0
   pendingConnection=game:GetService('RunService').Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed>=.2 then elapsed=0;updateButton()end end)
  end
 end
 function self:close()
  self.visible=false;root.Visible=false
  if pendingConnection then pendingConnection:Disconnect();pendingConnection=nil end
 end
 function self:isVisible()return self.visible end
 taskButton.Activated:Connect(function()
  -- Re-read authority at activation, never trust the previously rendered button.
  if not self.visible then return end
  local profile=ctx.profile()
  if not profile or not profile.ready then
   if not(ctx.pending and ctx.pending())then ctx.request('retry')end
   return
  end
  local current=ClubJournalUI.dailyView(profile,language())
  if not current.action or(ctx.pending and ctx.pending())then return end
  ctx.request(current.action);updateButton()
 end)
 close.Activated:Connect(function()self:close()end)
 local inputConnection=UserInputService.InputBegan:Connect(function(input,processed)
  if self.visible and not processed and input.KeyCode==Enum.KeyCode.Escape then self:close()end
 end)
 local sizeConnection=ctx.gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()if self.visible then layout()end end)
 local cameraConnection=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()if self.visible then layout()end end)
 root.Destroying:Connect(function()
  self:close();inputConnection:Disconnect();sizeConnection:Disconnect();cameraConnection:Disconnect()
 end)
 return self
end

return ClubJournalUI
