-- StarterPlayerScripts > MatchReturnLobbyClient
-- FULL REPLACEMENT
-- Match result footer, consistent with the graphite / white club screens

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sessionFolder =
	ReplicatedStorage:WaitForChild("MatchSession")

local remotes =
	ReplicatedStorage:WaitForChild("MatchRemotes")

local returnEvent =
	remotes:WaitForChild("ReturnLobby")

---------------------------------------------------------------------
-- COLORS
---------------------------------------------------------------------

local COLORS = {
	Background = Color3.fromRGB(46,47,51),
	BackgroundHover = Color3.fromRGB(56,57,61),

	Text = Color3.fromRGB(246,246,247),

	Border = Color3.fromRGB(112,114,120),

	Shadow = Color3.fromRGB(0, 0, 0),
	Primary = Color3.fromRGB(238,238,240),
	PrimaryInk = Color3.fromRGB(26,28,32),
}

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local old =
	playerGui:FindFirstChild("MatchReturnLobbyUI")

if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")

gui.Name = "MatchReturnLobbyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 150

gui.Parent = playerGui

---------------------------------------------------------------------
-- ROOT
---------------------------------------------------------------------

local root = Instance.new("Frame")

root.Name = "ReturnRoot"

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
		-78
	)

root.Size =
	UDim2.fromOffset(
		310,
		58
	)

root.BackgroundTransparency = 1

root.Visible = false

root.Parent = gui

---------------------------------------------------------------------
-- SHADOW
---------------------------------------------------------------------

local shadow = Instance.new("Frame")

shadow.Name = "Shadow"

shadow.Position =
	UDim2.fromOffset(
		0,
		5
	)

shadow.Size =
	UDim2.fromScale(
		1,
		1
	)

shadow.BackgroundColor3 =
	COLORS.Shadow

shadow.BackgroundTransparency = 0.55

shadow.BorderSizePixel = 0

shadow.Parent = root

local shadowCorner =
	Instance.new("UICorner")

shadowCorner.CornerRadius =
	UDim.new(
		0,
		3
	)

shadowCorner.Parent = shadow

---------------------------------------------------------------------
-- BUTTON
---------------------------------------------------------------------

local button = Instance.new("TextButton")

button.Name = "ReturnLobbyButton"

button.Size =
	UDim2.fromScale(
		1,
		1
	)

button.Position =
	UDim2.fromOffset(
		0,
		0
	)

button.BackgroundColor3 =
	COLORS.Background

button.BackgroundTransparency = 0

button.BorderSizePixel = 0

button.AutoButtonColor = false

button.Active = true

button.Font =
	Enum.Font.BuilderSansBold

button.Text =
	"ВЕРНУТЬСЯ В ЛОББИ"

button.TextColor3 =
	COLORS.Text

button.TextSize = 16
button.TextWrapped=true
button:SetAttribute("SpyUserText",true)

button.TextTransparency = 0

button.Parent = root

---------------------------------------------------------------------
-- CORNER
---------------------------------------------------------------------

local buttonCorner =
	Instance.new("UICorner")

buttonCorner.CornerRadius =
	UDim.new(
		0,
		3
	)

buttonCorner.Parent = button

---------------------------------------------------------------------
-- BORDER
---------------------------------------------------------------------

local border =
	Instance.new("UIStroke")

border.Color =
	COLORS.Border

border.Thickness = 1

border.Transparency = 0.22

border.ApplyStrokeMode =
	Enum.ApplyStrokeMode.Border

border.Parent = button

---------------------------------------------------------------------
-- SCALE
---------------------------------------------------------------------

local scale =
	Instance.new("UIScale")

scale.Scale = 1

scale.Parent = root

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

local busy = false
local hovering = false
local busyMessage = "Returning"

local function localize()
 local english=player:GetAttribute("SpyLanguage")=="en"
 button.Text=busy and (busyMessage=="Saving" and (english and "SAVING YOUR REWARD…" or "СОХРАНЯЕМ НАГРАДУ…") or (english and "RETURNING…" or "ВОЗВРАЩАЕМСЯ…")) or (english and "RETURN TO LOBBY" or "ВЕРНУТЬСЯ В ЛОББИ")
end
player:GetAttributeChangedSignal("SpyLanguage"):Connect(localize)
localize()

local returnLimit=Instance.new("UISizeConstraint")
returnLimit.MaxSize=Vector2.new(560,58)
returnLimit.Parent=root

local function attachReturnButton()
 local matchGui=playerGui:FindFirstChild("MatchUI")
 local result=matchGui and matchGui:FindFirstChild("MatchResultPanel",true)
 if result and result.Visible then
  root.Parent=result
  root.Position=UDim2.new(.5,0,1,-18)
  root.Size=UDim2.new(1,-44,0,52)
  root.ZIndex=302;shadow.ZIndex=302;button.ZIndex=303
 else
  root.Parent=gui
  root.Position=UDim2.new(.5,0,1,-28)
  root.Size=UDim2.new(1,-32,0,58)
 end
end

---------------------------------------------------------------------
-- VISIBILITY
---------------------------------------------------------------------

local function updateVisibility()
	attachReturnButton()
	localize()
	if busy then
		root.Visible = true
		return
	end

	local phase =
		sessionFolder:GetAttribute(
			"RoundPhase"
		)

	root.Visible =
		phase == "Result"
		or phase == "Finished"
end

---------------------------------------------------------------------
-- NORMAL LOOK
---------------------------------------------------------------------

local function normalLook()
	TweenService:Create(
		button,
		TweenInfo.new(
			0.16,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			BackgroundColor3 =
				COLORS.Background,
		}
	):Play()

	TweenService:Create(
		scale,
		TweenInfo.new(
			0.16,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Scale = 1,
		}
	):Play()

	TweenService:Create(
		border,
		TweenInfo.new(
			0.16,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Transparency = 0.22,
		}
	):Play()
end

---------------------------------------------------------------------
-- HOVER LOOK
---------------------------------------------------------------------

local function hoverLook()
	TweenService:Create(
		button,
		TweenInfo.new(
			0.16,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			BackgroundColor3 =
				COLORS.BackgroundHover,
		}
	):Play()

	TweenService:Create(
		scale,
		TweenInfo.new(
			0.16,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Scale = 1.025,
		}
	):Play()

	TweenService:Create(
		border,
		TweenInfo.new(
			0.16,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Transparency = 0.05,
		}
	):Play()
end

---------------------------------------------------------------------
-- HOVER
---------------------------------------------------------------------

button.MouseEnter:Connect(
	function()
		if busy then
			return
		end

		hovering = true

		hoverLook()
	end
)

button.MouseLeave:Connect(
	function()
		if busy then
			return
		end

		hovering = false

		normalLook()
	end
)

---------------------------------------------------------------------
-- CLICK
---------------------------------------------------------------------

button.Activated:Connect(
	function()
		if busy then
			return
		end

		busy = true
		busyMessage="Returning"

		button.Active = false

		button.Text =
			"ВОЗВРАЩАЕМСЯ..."

		TweenService:Create(
			scale,
			TweenInfo.new(
				0.08,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Scale = 0.965,
			}
		):Play()

		task.delay(
			0.08,
			function()
				TweenService:Create(
					scale,
					TweenInfo.new(
						0.18,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{
						Scale = 1,
					}
				):Play()
			end
		)

		localize()
		returnEvent:FireServer()
	end
)

---------------------------------------------------------------------
-- SERVER RESPONSE
---------------------------------------------------------------------

returnEvent.OnClientEvent:Connect(
	function(status)

		if status == "Returning" or status == "Saving" then
			busyMessage=status

			busy = true

			root.Visible = true

			button.Active = false

			localize()

		elseif status == "Failed"
			or status == "Denied"
			or status == "Studio"
		then

			busy = false

			button.Active = true

			localize()

			if hovering then
				hoverLook()
			else
				normalLook()
			end

			updateVisibility()
		end
	end
)

---------------------------------------------------------------------
-- PHASE
---------------------------------------------------------------------

sessionFolder:
	GetAttributeChangedSignal(
		"RoundPhase"
	):
	Connect(
		updateVisibility
	)

---------------------------------------------------------------------
-- INITIAL
---------------------------------------------------------------------

-- The server publishes phase before State creates the visible result.
local function observeResult(object)
 if object.Name=="MatchResultPanel" then
  object:GetPropertyChangedSignal("Visible"):Connect(updateVisibility)
 end
end
for _,object in ipairs(playerGui:GetDescendants())do observeResult(object)end
playerGui.DescendantAdded:Connect(observeResult)
updateVisibility()
-- REMATCH_FOOTER_BEGIN
buttonCorner.CornerRadius=UDim.new(0,3);shadowCorner.CornerRadius=UDim.new(0,3)
local replay=Instance.new('TextButton')
replay.Name='RematchButton';replay.Position=UDim2.new(0,0,0,0);replay.Size=UDim2.new(.5,-5,1,0)
replay.Font=Enum.Font.BuilderSansBold;replay.TextSize=16;replay.TextWrapped=true;replay.AutoButtonColor=false
replay.TextColor3=COLORS.PrimaryInk;replay.BackgroundColor3=COLORS.Primary;replay.BorderSizePixel=0
replay.ZIndex=303;replay.Visible=false;replay.Parent=root
local replayCorner=Instance.new('UICorner');replayCorner.CornerRadius=UDim.new(0,3);replayCorner.Parent=replay
local replayState,roundToken,revision,pending,serial=nil,nil,-1,false,0
local received=0;local connections={}
local function copy(ru,en,zh)local l=player:GetAttribute('SpyLanguage');return l=='en'and en or l=='zh'and zh or ru end
local function myReady()
 return replayState and table.find(replayState.readyIds or{},player.UserId)~=nil
end
local function paintReplay()
 local phase=sessionFolder:GetAttribute('RoundPhase')
 replay.Visible=replayState~=nil and(phase=='Result'or phase=='Finished')
 button.Size=replay.Visible and UDim2.new(.5,-5,1,0)or UDim2.fromScale(1,1)
 button.Position=replay.Visible and UDim2.new(.5,5,0,0)or UDim2.new()
 if not replay.Visible then return end
 local stage=replayState.state
 local count=tostring(replayState.count)..' / '..tostring(replayState.required)
 local view=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
 local gap=view and view.X<380 and '\n'or ' '
 replay.Text=stage=='uncertain'and copy('Нет подтверждения','Entry unconfirmed','未确认进入')
  or stage=='returning'and copy('Переходим…','Joining…','正在前往…')
  or pending and copy('Отправляем…','Sending…','正在发送…')
  or(stage=='preparing'and not myReady())and copy('Готовим…','Preparing…','准备中…')
  or(myReady()and copy('Отменить','Cancel','取消')or copy('Реванш','Rematch','再来'))..gap..count
 replay.Active=not busy and not pending and(stage~='preparing'or myReady())and stage~='returning'and stage~='uncertain'and(replayState.required or 0)>=3
 replay.BackgroundColor3=myReady()and COLORS.Background or COLORS.Primary
 replay.TextColor3=myReady()and COLORS.Text or COLORS.PrimaryInk
end
localize=function()
 button.Text=busy and(busyMessage=='Saving'and copy('Сохраняем…','Saving…','正在保存…')or copy('Возвращаемся…','Returning…','正在返回…'))or copy('В лобби','Lobby','大厅')
 paintReplay()
end
replay.Activated:Connect(function()
 if not replay.Active or not roundToken then return end
 local action=remotes:FindFirstChild('Action');if not action then return end
 serial+=1;local token=serial;pending=true;paintReplay()
 action:FireServer('Rematch',{roundToken=roundToken,ready=not myReady()})
 task.delay(4,function()if gui.Parent and pending and serial==token then pending=false;paintReplay()end end)
end)
local function receive(state)
 if type(state)~='table'or type(state.rematch)~='table'or type(state.roundToken)~='number'then return end
 local value=state.rematch
 if type(value.revision)~='number'or type(value.count)~='number'or type(value.required)~='number'then return end
 if roundToken==state.roundToken and value.revision<=revision then return end
 roundToken=state.roundToken;revision=value.revision;replayState=value;pending=false;received+=1;localize()
end
local stateEvent=remotes:FindFirstChild('State')
if stateEvent then connections[#connections+1]=stateEvent.OnClientEvent:Connect(receive)end
connections[#connections+1]=sessionFolder:GetAttributeChangedSignal('RoundPhase'):Connect(paintReplay)
connections[#connections+1]=player:GetAttributeChangedSignal('SpyLanguage'):Connect(localize)
connections[#connections+1]=returnEvent.OnClientEvent:Connect(function()paintReplay()end)
if workspace.CurrentCamera then connections[#connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(paintReplay)end
-- Optional late snapshot never owns boot, cursor or return availability.
local startSerial=received
task.delay(8,function()if received==startSerial then received+=1 end end)
task.spawn(function()
 local snapshot=remotes:FindFirstChild('Snapshot');if not snapshot then return end
 local ok,data=pcall(function()return snapshot:InvokeServer()end)
 if ok and type(data)=='table'and gui.Parent and received==startSerial then receive(data.state)end
end)
gui.Destroying:Connect(function()
 for _,c in ipairs(connections)do c:Disconnect()end
 if root.Parent and root.Parent~=gui then root:Destroy()end
end)
localize()
-- REMATCH_FOOTER_END
