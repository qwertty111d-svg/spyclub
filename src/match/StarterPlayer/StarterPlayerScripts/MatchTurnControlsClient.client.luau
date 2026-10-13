-- StarterPlayer > StarterPlayerScripts > MatchTurnControlsClient
-- SPY CLUB / TURN CONTROLS
--
-- Shows "READY" only during your own hint turn.
-- E = finish turn.
-- Useful for voice chat / spoken clues.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes =
	ReplicatedStorage:WaitForChild(
		"MatchRemotes"
	)

local stateEvent =
	remotes:WaitForChild(
		"State"
	)

local actionEvent =
	remotes:WaitForChild(
		"Action"
	)

---------------------------------------------------------------------
-- COLORS
---------------------------------------------------------------------

local PANEL=Color3.fromRGB(48,77,68)
local PANEL_HOVER=Color3.fromRGB(38,47,59)
local WINE=Color3.fromRGB(26,58,68)
local BRASS=Color3.fromRGB(135,212,222)
local IVORY=Color3.fromRGB(244,240,231)
local MUTED=Color3.fromRGB(174,188,202)

local old =
	playerGui:FindFirstChild(
		"MatchTurnControls"
	)

if old then
	old:Destroy()
end

---------------------------------------------------------------------
-- ROOT
---------------------------------------------------------------------

local gui =
	Instance.new(
		"ScreenGui"
	)

gui.Name =
	"MatchTurnControls"

gui.IgnoreGuiInset =
	false
gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets

gui.ResetOnSpawn =
	false

gui.DisplayOrder =
	320

gui.Parent =
	playerGui

-- The same persisted personal settings are available during a match.
local shared = ReplicatedStorage:WaitForChild("SpyShared")
local MatchHUD = require(shared.MatchHUD)
local ClientPreferences = require(shared:WaitForChild("ClientPreferences"))
local SettingsUI = require(shared:WaitForChild("SettingsUI"))
ClientPreferences.start()
local settingsPanel = SettingsUI.create({gui=gui})
-- Phone uses the existing match settings and private clue panel.
local phoneLaunch=playerGui:FindFirstChild("SpyPhoneLaunch") or Instance.new("BindableEvent")
phoneLaunch.Name="SpyPhoneLaunch";phoneLaunch.Parent=playerGui
phoneLaunch.Event:Connect(function(key,arg,token)
 local success=false
 if key=="settings" then success=pcall(settingsPanel.open,settingsPanel)
 elseif key=="meeting" then
  local event=playerGui:FindFirstChild("SpyOpenCase")
  if event and event:IsA("BindableEvent") then event:Fire();success=true end
 end
 local ack=playerGui:FindFirstChild("SpyPhoneLaunchAck")
 if ack and ack:IsA("BindableEvent") then ack:Fire(token,success) end
end)

local closeSpyGuess
local updateSpyGuess
local spyGuessOpen = false
local settingsButton = Instance.new("TextButton")
settingsButton.Name="PersonalSettings"
settingsButton.AnchorPoint=Vector2.new(1,1)
settingsButton.Position=UDim2.new(1,-18,1,-18)
settingsButton.Size=UDim2.fromOffset(142,44)
settingsButton.BackgroundColor3=PANEL
settingsButton.BackgroundTransparency=.03
settingsButton.TextColor3=IVORY
settingsButton.Font=Enum.Font.BuilderSansBold
settingsButton.TextSize=14
settingsButton.Text="НАСТРОЙКИ"
settingsButton.ZIndex=5
settingsButton.Parent=gui
local settingsCorner=Instance.new("UICorner")
settingsCorner.CornerRadius=UDim.new(0,6)
settingsCorner.Parent=settingsButton
MatchHUD.register(playerGui,settingsButton,90)
settingsButton.Activated:Connect(function()
	if closeSpyGuess then closeSpyGuess() end
	if settingsPanel.visible then settingsPanel:close() else settingsPanel:open() end
end)

-- Connection status is independent of State events: never restart a cinematic
-- or ballot merely because another participant disconnects.
local connectionNotice = Instance.new("TextLabel")
connectionNotice.Name = "ConnectionNotice"
connectionNotice.AnchorPoint = Vector2.new(0.5, 0)
connectionNotice.Position = UDim2.new(0.5, 0, 0, 180)
connectionNotice.Size = UDim2.new(1, -32, 0, 46)
connectionNotice.BackgroundColor3 = PANEL
connectionNotice.BackgroundTransparency = 0.08
connectionNotice.BorderSizePixel = 0
connectionNotice.Font = Enum.Font.BuilderSansBold
connectionNotice.TextSize = 14
connectionNotice.TextColor3 = IVORY
connectionNotice.TextWrapped = true
connectionNotice.Visible = false
connectionNotice.ZIndex = 3
connectionNotice.Parent = gui
local noticeLimit = Instance.new("UISizeConstraint")
noticeLimit.MaxSize = Vector2.new(440, 46)
noticeLimit.Parent = connectionNotice
local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 8)
noticeCorner.Parent = connectionNotice
task.spawn(function()
	local session = ReplicatedStorage:WaitForChild("MatchSession")
	while gui.Parent do
		local count = tonumber(session:GetAttribute("DisconnectedCount")) or 0
		local deadline = tonumber(session:GetAttribute("ReconnectDeadline")) or 0
		local seconds = math.max(0, math.ceil(deadline - workspace:GetServerTimeNow()))
		local waiting = session:GetAttribute("ReconnectWaiting") == true
		local english = player:GetAttribute("SpyLanguage") == "en"
		connectionNotice.Visible = count > 0 and seconds > 0 and not settingsPanel.visible
		connectionNotice.Text = string.format(
			waiting and (english and "Waiting for reconnection · %ds" or "Ждём возвращения игрока · %d сек.")
				or (english and "Connection lost · seat held for %ds" or "Игрок потерял связь · место сохранено на %d сек."), seconds)
		if updateSpyGuess then updateSpyGuess() end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------
-- BUTTON
---------------------------------------------------------------------

local root =
	Instance.new(
		"CanvasGroup"
	)

root.Name =
	"ReadyRoot"

root.AnchorPoint =
	Vector2.new(
		0.5,
		1
	)

root.Position =
	UDim2.new(
		0.5,
		0,
		1,
		-52
	)

root.Size =
	UDim2.fromOffset(
		240,
		56
	)

root.BackgroundColor3 =
	PANEL

root.BackgroundTransparency =
	0.05

root.BorderSizePixel =
	0

root.GroupTransparency =
	1

root.Visible =
	false

root.Parent =
	gui

local corner =
	Instance.new(
		"UICorner"
	)

corner.CornerRadius =
	UDim.new(
		0,
		14
	)

corner.Parent =
	root

local outline =
	Instance.new(
		"UIStroke"
	)

outline.Color =
	BRASS

outline.Transparency =
	0.58

outline.Thickness =
	1

outline.Parent =
	root

local button =
	Instance.new(
		"TextButton"
	)

button.Size =
	UDim2.fromScale(
		1,
		1
	)

button.BackgroundTransparency =
	1

button.BorderSizePixel =
	0

button.AutoButtonColor =
	false

button.Text =
	""

button.Parent =
	root

button.Name="ReadyButton"

local title =
	Instance.new(
		"TextLabel"
	)

title.BackgroundTransparency =
	1

title.Position =
	UDim2.fromOffset(
		10,
		5
	)

title.Size =
	UDim2.new(
		1,
		-20,
		0,
		22
	)

title.Font =
	Enum.Font.BuilderSansBold

title.TextSize =
	16

title.TextColor3 =
	IVORY

title.Text =
	"E   ·   ПОДСКАЗКА ДАНА"

title.Parent =
	root

local subtitle =
	Instance.new(
		"TextLabel"
	)

subtitle.BackgroundTransparency =
	1

subtitle.Position =
	UDim2.fromOffset(
		10,
		30
	)

subtitle.Size =
	UDim2.new(
		1,
		-20,
		0,
		15
	)

subtitle.Font =
	Enum.Font.BuilderSansMedium

subtitle.TextSize =
	12

subtitle.TextColor3 =
	MUTED

subtitle.Text =
	"Я дал подсказку"

subtitle.Parent =
	root

-- One useful action with a separate keycap, rather than two repeated captions.
local readyKey=Instance.new("Frame")
readyKey.Name="ReadyKeycap";readyKey.AnchorPoint=Vector2.new(0,.5)
readyKey.Position=UDim2.new(0,12,.5,0);readyKey.Size=UDim2.fromOffset(30,30)
readyKey.BackgroundColor3=PANEL_HOVER;readyKey.BorderSizePixel=0;readyKey.Parent=root
local keyCorner=Instance.new("UICorner");keyCorner.CornerRadius=UDim.new(0,5);keyCorner.Parent=readyKey
local keyText=Instance.new("TextLabel")
keyText.Name="Key";keyText.Size=UDim2.fromScale(1,1);keyText.BackgroundTransparency=1
keyText.Font=Enum.Font.BuilderSansBold;keyText.TextSize=16;keyText.TextColor3=IVORY;keyText.Text="E";keyText.Parent=readyKey
readyKey.Active=false
readyKey.ZIndex=button.ZIndex+1;keyText.ZIndex=readyKey.ZIndex+1
subtitle.Visible=false
title.Position=UDim2.fromOffset(54,0);title.Size=UDim2.new(1,-66,1,0)
title.TextXAlignment=Enum.TextXAlignment.Left
title.TextWrapped=true

local function fitTurnControls()
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local inset,bottom=game:GetService("GuiService"):GetGuiInset();viewport=Vector2.new(viewport.X-inset.X-bottom.X,viewport.Y-inset.Y-bottom.Y)
 local layout=MatchHUD.metrics(viewport,UserInputService.TouchEnabled)
 root.AnchorPoint=Vector2.new()
 root.Size=UDim2.fromOffset(layout.ready.w,layout.ready.h)
 root.Position=UDim2.fromOffset(layout.ready.x,layout.ready.y)
 readyKey.Visible=not UserInputService.TouchEnabled
 title.Position=UDim2.fromOffset(UserInputService.TouchEnabled and 18 or 54,0)
 title.Size=UDim2.new(1,UserInputService.TouchEnabled and -36 or -66,1,0)
end
fitTurnControls()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitTurnControls) end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

local ownTurn =
	false

local submitted =
	false

local function localizeTurn()
	local language=player:GetAttribute("SpyLanguage");local english=language=="en"
	settingsButton.Text=english and "Settings"or language=="zh"and"设置"or"Настройки"
	title.Text=submitted and(english and"Done"or language=="zh"and"完成"or"Готово")or(english and"Finish turn"or language=="zh"and"结束回合"or"Закончить ход")
	subtitle.Text=submitted and (english and "Passing turn…" or "Передаём ход…") or (english and "I gave my clue" or "Я дал подсказку")
end
player:GetAttributeChangedSignal("SpyLanguage"):Connect(localizeTurn)
localizeTurn()

local function tweenRoot(
	duration,
	props
)
	local animation =
		TweenService:Create(
			root,

			TweenInfo.new(
				duration,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),

			props
		)

	animation:Play()

	return animation
end

local function show()
	submitted = false

	title.Text =
		"E   ·   ПОДСКАЗКА ДАНА"

	subtitle.Text =
		"Я дал подсказку"
	localizeTurn()

	root.BackgroundColor3 =
		PANEL

	outline.Transparency =
		0.58

	root.Visible =
		true

	root.GroupTransparency =
		1

	tweenRoot(
		0.18,
		{
			GroupTransparency =
				0,
		}
	)
end

local function hide()
	if not root.Visible then
		return
	end

	local animation =
		tweenRoot(
			0.13,
			{
				GroupTransparency =
				1,
			}
		)

	animation.Completed:Once(
		function()
			if not ownTurn then
				root.Visible =
					false
			end
		end
	)
end

local function submit()
	if not ownTurn
		or submitted
		or settingsPanel.visible
		or spyGuessOpen
	then
		return
	end

	submitted = true

	title.Text =
		"ГОТОВО"

	subtitle.Text =
		"Передаём ход…"
	localizeTurn()

	root.BackgroundColor3 =
		WINE

	outline.Transparency =
		0.18

	actionEvent:FireServer(
		"HintDone"
	)
end

---------------------------------------------------------------------
-- PRIVATE SPY ATTEMPT — independent of every chat surface/transport.
---------------------------------------------------------------------

local guessRole, guessCategory, guessToken
local guessPhase, guessDeadline, guessStateToken = "Waiting", 0, nil
local guessUsed, guessPending = false, false
local guessStep, guessStatus = "edit", nil
local guessSerial, guessRevision = 0, 0

local function guessText(ru, en)
	return player:GetAttribute("SpyLanguage") == "en" and en or ru
end
local function guessObject(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in pairs(props) do object[key] = value end
	object.Parent = parent
	return object
end
local function guessCorner(parent, radius)
	guessObject("UICorner", "Corner", parent, {CornerRadius=UDim.new(0, radius)})
end
local guessButton = guessObject("TextButton", "SpyGuessButton", gui, {
	AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-18,0,90), Size=UDim2.fromOffset(172,40),
	BackgroundColor3=PANEL, TextColor3=BRASS, Font=Enum.Font.BuilderSansBold,
	TextSize=13, Text="", BorderSizePixel=0, Visible=false, ZIndex=6,
})
guessCorner(guessButton, 6)
MatchHUD.register(playerGui,guessButton,10)
guessObject("UIStroke", "Outline", guessButton, {Color=BRASS, Transparency=.6, Thickness=1})
local guessOverlay = guessObject("Frame", "SpyGuessOverlay", gui, {
	Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.fromRGB(4,8,12),
	BackgroundTransparency=.38, BorderSizePixel=0, Visible=false, Active=true, ZIndex=20,
})
local guessPanel = guessObject("Frame", "SpyGuessPanel", guessOverlay, {
	AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.fromOffset(420,288),
	BackgroundColor3=PANEL, BorderSizePixel=0, ZIndex=21,
})
guessCorner(guessPanel, 8)
guessObject("UIStroke", "Outline", guessPanel, {Color=BRASS, Transparency=.65, Thickness=1})
local guessScale = guessObject("UIScale", "Fit", guessPanel, {Scale=1})
local guessHeading = guessObject("TextLabel", "Heading", guessPanel, {
	Position=UDim2.fromOffset(22,18), Size=UDim2.new(1,-74,0,28), BackgroundTransparency=1,
	Font=Enum.Font.BuilderSansBold, TextSize=21, TextColor3=IVORY,
	TextXAlignment=Enum.TextXAlignment.Left, Text="", ZIndex=22,
})
local guessClose = guessObject("TextButton", "CloseGuess", guessPanel, {
	AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-16,0,16), Size=UDim2.fromOffset(32,32),
	BackgroundTransparency=1, Text="×", TextColor3=MUTED, Font=Enum.Font.BuilderSans,
	TextSize=24, ZIndex=22,
})
local guessDetails = guessObject("TextLabel", "Details", guessPanel, {
	Position=UDim2.fromOffset(22,54), Size=UDim2.new(1,-44,0,42), BackgroundTransparency=1,
	Font=Enum.Font.BuilderSans, TextSize=14, TextColor3=MUTED, TextWrapped=true,
	TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Text="", ZIndex=22,
})
local guessEntry = guessObject("TextBox", "GuessWord", guessPanel, {
	Position=UDim2.fromOffset(22,106), Size=UDim2.new(1,-44,0,48), BackgroundColor3=PANEL_HOVER,
	BorderSizePixel=0, TextColor3=IVORY, PlaceholderColor3=MUTED, Text="",
	Font=Enum.Font.BuilderSans, TextSize=18, ClearTextOnFocus=false, MultiLine=false, ZIndex=22,
})
guessCorner(guessEntry, 5)
local guessDraft = guessObject("TextLabel", "Draft", guessPanel, {
	Position=guessEntry.Position, Size=guessEntry.Size, BackgroundColor3=PANEL_HOVER,
	BorderSizePixel=0, TextColor3=IVORY, Font=Enum.Font.BuilderSansBold, TextSize=18,
	TextWrapped=true, Text="", Visible=false, ZIndex=22,
})
guessCorner(guessDraft, 5)
local guessMessage = guessObject("TextLabel", "Message", guessPanel, {
	Position=UDim2.fromOffset(22,164), Size=UDim2.new(1,-44,0,44), BackgroundTransparency=1,
	Font=Enum.Font.BuilderSans, TextSize=13, TextColor3=MUTED, TextWrapped=true,
	TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Text="", ZIndex=22,
})
local guessConfirm = guessObject("TextButton", "ConfirmGuess", guessPanel, {
	Position=UDim2.fromOffset(22,224), Size=UDim2.new(1,-44,0,42), BackgroundColor3=WINE,
	BorderSizePixel=0, TextColor3=IVORY, Font=Enum.Font.BuilderSansBold, TextSize=14, Text="", ZIndex=22,
})
guessCorner(guessConfirm, 5)
local guessEdit = guessObject("TextButton", "EditGuess", guessPanel, {
	Position=UDim2.fromOffset(22,224), Size=UDim2.fromOffset(104,42), BackgroundColor3=PANEL_HOVER,
	BorderSizePixel=0, TextColor3=MUTED, Font=Enum.Font.BuilderSans, TextSize=14, Text="", Visible=false, ZIndex=22,
})
guessCorner(guessEdit, 5)

local function canGuess()
	return guessRole == "spy" and not guessUsed and guessToken ~= nil and guessToken == guessStateToken
		and (guessPhase == "Hint" or guessPhase == "Discuss") and guessDeadline > workspace:GetServerTimeNow()
end
closeSpyGuess = function()
	spyGuessOpen = false
	guessOverlay.Visible = false
	guessPending = false
	guessSerial += 1
	guessStep, guessStatus = "edit", nil
	guessEntry:ReleaseFocus()
	guessEntry.Text = ""
end
local function fitGuess()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280,720)
	guessScale.Scale = math.min(1, (size.X-24)/420, (size.Y-32)/288)
end
fitGuess()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitGuess) end
local statusCopy = {
	invalid={"Напиши полное слово: от 1 до 80 символов, без переноса строки.","Enter the full word: 1–80 characters, without line breaks."},
	stale={"Состояние матча изменилось. Открой попытку снова.","The round changed. Open your attempt again."},
	closed={"Сейчас нельзя угадывать. Дождись подсказок или обсуждения.","Guessing is closed. Wait for clues or discussion."},
	not_spy={"Эта попытка доступна только шпиону.","Only the spy can make this attempt."},
	timeout={"Ответ сервера не пришёл. Можно отправить повторно — второй попытки это не создаст.","No server reply. You can retry; it will not create a second attempt."},
}
updateSpyGuess = function()
	local available = canGuess()
	guessButton.Visible = available and not settingsPanel.visible and not spyGuessOpen
	if spyGuessOpen and (not available or settingsPanel.visible) then closeSpyGuess() end
	guessButton.Text = guessText("Назвать слово", "Guess the word")
	guessHeading.Text = guessText("Попытка шпиона", "Spy's attempt")
	guessDetails.Text = guessText("Тема: ", "Category: ")..tostring(guessCategory or "—").."\n"
		..guessText("Одно секретное слово. Одна попытка за матч.", "One secret word. One attempt per match.")
	guessEntry.PlaceholderText = guessText("Секретное слово", "Secret word")
	if player:GetAttribute("SpyCaseMode")==true then
		local f=ReplicatedStorage:FindFirstChild("SpyShared")
		local m=f and f:FindFirstChild("CaseFiles")
		if m then
			local ok,files=pcall(require,m)
			if ok then
				local lang=player:GetAttribute("SpyLanguage")or"ru"
				guessButton.Text=files.text(lang,"codeAttempt");guessDetails.Text=files.text(lang,"one_attempt");guessEntry.PlaceholderText=files.text(lang,"accesscode")
			end
		end
	end
	local confirming = guessStep == "confirm"
	guessEntry.Visible = not confirming
	guessDraft.Visible = confirming
	guessEdit.Visible = confirming and not guessPending
	guessDraft.Text = guessEntry.Text
	guessEdit.Text = guessText("Изменить", "Edit")
	guessConfirm.Position = UDim2.fromOffset(confirming and 136 or 22,224)
	guessConfirm.Size = UDim2.new(1,confirming and -158 or -44,0,42)
	guessConfirm.Active = not guessPending
	guessConfirm.AutoButtonColor = not guessPending
	guessConfirm.Text = guessPending and guessText("Проверяем…", "Checking…")
		or confirming and guessText("Подтвердить попытку", "Confirm attempt") or guessText("Продолжить", "Continue")
	local copy = guessStatus and statusCopy[guessStatus]
	guessMessage.Text = copy and guessText(copy[1],copy[2]) or guessText(
		"Верно — твоя победа. Неверно — победа агентов. После подтверждения ответ изменить нельзя.",
		"Correct: you win. Wrong: agents win. Once confirmed, the answer cannot be changed.")
end
player:GetAttributeChangedSignal("SpyLanguage"):Connect(updateSpyGuess)
guessButton.Activated:Connect(function()
	if not canGuess() or settingsPanel.visible then return end
	spyGuessOpen = true
	guessOverlay.Visible = true
	guessStep, guessStatus = "edit", nil
	updateSpyGuess()
	guessEntry:CaptureFocus()
end)
guessClose.Activated:Connect(function() closeSpyGuess(); updateSpyGuess() end)
guessEdit.Activated:Connect(function()
	if guessPending then return end
	guessStep, guessStatus = "edit", nil
	updateSpyGuess(); guessEntry:CaptureFocus()
end)
local function prepareGuess()
	local length = utf8.len(guessEntry.Text)
	if not length or length < 1 or length > 80 or #guessEntry.Text > 320
		or guessEntry.Text:match("^%s*$") or guessEntry.Text:find("[%c]") then
		guessStatus = "invalid"; updateSpyGuess(); return false
	end
	guessEntry:ReleaseFocus()
	guessStep, guessStatus = "confirm", nil
	updateSpyGuess()
	return true
end
guessConfirm.Activated:Connect(function()
	if not spyGuessOpen or guessPending or not canGuess() then updateSpyGuess(); return end
	if guessStep ~= "confirm" then prepareGuess(); return end
	guessPending = true
	guessSerial += 1
	local serial, token = guessSerial, guessToken
	updateSpyGuess()
	actionEvent:FireServer("SpyGuess", {word=guessEntry.Text, roundToken=token})
	task.delay(5,function()
		if not gui.Parent or serial ~= guessSerial or not guessPending then return end
		guessPending = false
		guessStep, guessStatus = "edit", "timeout"
		updateSpyGuess()
	end)
end)
guessEntry.FocusLost:Connect(function(enterPressed)
	if enterPressed and spyGuessOpen and not guessPending and canGuess() then prepareGuess() end
end)
actionEvent.OnClientEvent:Connect(function(receipt)
	if type(receipt) ~= "table" or receipt.kind ~= "SpyGuessReceipt" or receipt.roundToken ~= guessToken then return end
	if receipt.used then
		guessUsed = true; closeSpyGuess(); updateSpyGuess(); return
	end
	if not guessPending then return end
	guessPending = false
	guessSerial += 1
	guessStep, guessStatus = "edit", receipt.code
	updateSpyGuess()
end)
local function applyGuessState(state)
	if type(state) ~= "table" or type(state.phase) ~= "string" or state.phase == "VoteAccepted" then return end
	guessRevision += 1
	guessPhase = state.phase
	guessDeadline = tonumber(state.endAt) or 0
	guessStateToken = state.roundToken
	updateSpyGuess()
end
local function applyGuessCard(card)
	if type(card) ~= "table" or type(card.role) ~= "string" then return end
	guessRevision += 1
	if guessToken ~= card.roundToken then closeSpyGuess() end
	guessRole, guessCategory, guessToken = card.role, card.category, card.roundToken
	guessUsed = card.guessUsed == true
	player:SetAttribute("SpyCaseMode",card.caseFile~=nil)
	updateSpyGuess()
end
stateEvent.OnClientEvent:Connect(applyGuessState)
local guessCardEvent = remotes:FindFirstChild("Card")
if guessCardEvent then guessCardEvent.OnClientEvent:Connect(applyGuessCard) end
-- Optional late snapshot has a deadline and cannot gate Match, chat or loading.
local function requestGuessSnapshot(attempt)
	if guessRole or not gui.Parent then return end
	local revision, settled = guessRevision, false
	local function retry()
		if settled then return end
		settled = true
		if not guessRole and gui.Parent and attempt < 3 then
			task.delay(.5*attempt,function() requestGuessSnapshot(attempt+1) end)
		end
	end
	task.delay(3,retry)
	task.spawn(function()
		local snapshot = remotes:FindFirstChild("Snapshot")
		if not snapshot then retry(); return end
		local ok, data = pcall(function() return snapshot:InvokeServer() end)
		if settled or not gui.Parent then return end
		if not ok or type(data) ~= "table" then retry(); return end
		if guessRevision == revision then
			applyGuessState(data.state)
			applyGuessCard(data.secret)
		elseif not guessRole and data.state and data.state.roundToken == guessStateToken then
			applyGuessCard(data.secret)
		end
		if guessRole then settled = true else retry() end
	end)
end
requestGuessSnapshot(1)
updateSpyGuess()

---------------------------------------------------------------------
-- HOVER
---------------------------------------------------------------------

button.MouseEnter:Connect(
	function()
		if submitted then
			return
		end

		TweenService:Create(
			root,
			TweenInfo.new(
				0.10,
				Enum.EasingStyle.Quad
			),
			{
				BackgroundColor3 =
					PANEL_HOVER,
			}
		):Play()
	end
)

button.MouseLeave:Connect(
	function()
		if submitted then
			return
		end

		TweenService:Create(
			root,
			TweenInfo.new(
				0.10,
				Enum.EasingStyle.Quad
			),
			{
				BackgroundColor3 =
					PANEL,
			}
		):Play()
	end
)

button.Activated:Connect(
	submit
)

---------------------------------------------------------------------
-- KEY
---------------------------------------------------------------------

UserInputService.InputBegan:Connect(
	function(
		input,
		gameProcessed
	)
		if gameProcessed then
			return
		end

		if UserInputService:GetFocusedTextBox() then
			return
		end

		if input.KeyCode
			== Enum.KeyCode.E
		then
			submit()
		end
	end
)

---------------------------------------------------------------------
-- ROUND STATE
---------------------------------------------------------------------

stateEvent.OnClientEvent:Connect(
	function(state)
		if type(state) ~= "table" then
			return
		end

		if state.phase
			== "VoteAccepted"
		then
			return
		end

		local shouldOwnTurn =
			state.phase
			== "Hint"
			and state.turnUserId
			== player.UserId

		if shouldOwnTurn then
			if not ownTurn then
				ownTurn = true
				show()
			end
		else
			if ownTurn then
				ownTurn = false
				hide()
			else
				root.Visible = false
			end
		end
	end
)
