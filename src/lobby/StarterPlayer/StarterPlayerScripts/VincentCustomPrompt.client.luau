-- StarterPlayer > StarterPlayerScripts > VincentPrompt_MATCHCASE.lua
-- Только для Винсента.
-- Делает prompt в стиле как у твоего "Осмотреть":
-- черный ромб с E + рядом текст "Поговорить".
-- Без серой карточки, без дублей, без лишнего UI.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ROOT_NAME = "VincentPromptMatchCaseRoot"
local ACTIVE = {}

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
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	return make("TextLabel", parent, props)
end

local function stroke(parent, color, transparency, thickness)
	return make("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	})
end

local function corner(parent, radius)
	return make("UICorner", parent, {
		CornerRadius = UDim.new(0, radius),
	})
end

local function scale(parent, value)
	return make("UIScale", parent, {
		Scale = value or 1,
	})
end

local function tween(target, info, props)
	local tw = TweenService:Create(target, info, props)
	tw:Play()
	return tw
end

local function getRoot()
	local root = playerGui:FindFirstChild(ROOT_NAME)
	if root then
		return root
	end

	root = make("ScreenGui", playerGui, {
		Name = ROOT_NAME,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 120,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	return root
end

local function isVincentPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end

	local candidates = {
		prompt.Name,
		prompt.ObjectText,
		prompt.ActionText,
	}

	local parent = prompt.Parent
	for _ = 1, 5 do
		if not parent then break end
		table.insert(candidates, parent.Name)
		parent = parent.Parent
	end

	for _, value in ipairs(candidates) do
		local s = string.lower(tostring(value or ""))
		if s:find("винсент") or s:find("vincent") or s:find("бармен") or s:find("bartender") then
			return true
		end
	end

	return false
end

local function getAdornee(prompt)
	if prompt.Parent and prompt.Parent:IsA("Attachment") then
		return prompt.Parent
	end
	if prompt.Parent and prompt.Parent:IsA("BasePart") then
		return prompt.Parent
	end
	return nil
end

local function destroyPrompt(prompt)
	local state = ACTIVE[prompt]
	if not state then
		return
	end
	ACTIVE[prompt] = nil

	tween(state.scaleNode, TweenInfo.new(0.10, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Scale = 0.92,
	})
	tween(state.textLabel, TweenInfo.new(0.10, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween(state.badgeStroke, TweenInfo.new(0.10, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Transparency = 1,
	})
	tween(state.keyLabel, TweenInfo.new(0.10, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		TextTransparency = 1,
	})

	task.delay(0.11, function()
		if state.gui and state.gui.Parent then
			state.gui:Destroy()
		end
	end)
end

local function createPrompt(prompt)
	local adornee = getAdornee(prompt)
	if not adornee then
		return
	end

	local root = getRoot()
	local gui = make("BillboardGui", root, {
		Name = "VincentPrompt",
		Adornee = adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(180, 34),
		StudsOffset = Vector3.new(0, 1.55, 0),
		MaxDistance = prompt.MaxActivationDistance + 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local scaleNode = scale(gui, 0.94)

	local holder = frame(gui, {
		Name = "Holder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	local badge = frame(holder, {
		Name = "Badge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Rotation = 45,
		ZIndex = 2,
	})
	corner(badge, 3)
	local badgeStroke = stroke(badge, Color3.fromRGB(255, 255, 255), 0.12, 1)

	local keyLabel = label(holder, {
		Name = "KeyLabel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 17, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		Text = "E",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundTransparency = 1,
		ZIndex = 3,
	})

	local textLabel = label(holder, {
		Name = "ActionLabel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 1),
		Size = UDim2.new(1, -42, 0, 24),
		Text = "Поговорить",
		Font = Enum.Font.GothamMedium,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.55,
		BackgroundTransparency = 1,
		ZIndex = 3,
	})

	keyLabel.TextTransparency = 1
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1
	badgeStroke.Transparency = 1

	tween(scaleNode, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	tween(keyLabel, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	})
	tween(textLabel, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.55,
	})
	tween(badgeStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Transparency = 0.12,
	})

	ACTIVE[prompt] = {
		gui = gui,
		scaleNode = scaleNode,
		textLabel = textLabel,
		keyLabel = keyLabel,
		badgeStroke = badgeStroke,
	}
end

local function patchPrompt(prompt)
	if not isVincentPrompt(prompt) then
		return
	end
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Поговорить"
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
end

for _, desc in ipairs(workspace:GetDescendants()) do
	if desc:IsA("ProximityPrompt") and isVincentPrompt(desc) then
		patchPrompt(desc)
	end
end

workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("ProximityPrompt") and isVincentPrompt(desc) then
		task.defer(function()
			if desc and desc.Parent then
				patchPrompt(desc)
			end
		end)
	end
end)

ProximityPromptService.PromptShown:Connect(function(prompt)
	if not isVincentPrompt(prompt) then
		return
	end
	patchPrompt(prompt)
	destroyPrompt(prompt)
	createPrompt(prompt)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if not isVincentPrompt(prompt) then
		return
	end
	destroyPrompt(prompt)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if not isVincentPrompt(prompt) then
		return
	end
	destroyPrompt(prompt)
end)
