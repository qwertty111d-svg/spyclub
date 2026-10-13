local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SUPPORT_PRODUCT_ID = 3714115805

local function isSupportedPrompt(prompt)
	return prompt.Name == "CasePrompt"
		or prompt.Name == "OpenSupport"
		or prompt.Name == "FeedbackBook"
		or prompt.Name == "DailyReward"
end

local function patchPrompt(prompt)
	if not isSupportedPrompt(prompt) then
		return
	end

	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E

	if prompt.Name == "DailyReward" then
		prompt.ActionText = "ЕЖЕДНЕВНАЯ НАГРАДА"
		prompt.ObjectText = ""
	end
end

local activeGui
local activeHighlight

local function getPart(prompt)
	local object = prompt.Parent

	if object:IsA("BasePart") then
		return object
	end

	if object:IsA("Attachment") and object.Parent:IsA("BasePart") then
		return object.Parent
	end

	return object:FindFirstAncestorWhichIsA("BasePart")
end

local function getTarget(part)
	return part:FindFirstAncestorOfClass("Model") or part
end

local function getAccent(prompt)
	if prompt.Name == "OpenSupport" or prompt.Name == "DailyReward" or prompt.Name == "FeedbackBook" then
		return Color3.fromRGB(174, 139, 85)
	end

	local text = string.lower(prompt.ObjectText)

	if string.find(text, "золот") then
		return Color3.fromRGB(205, 162, 77)
	elseif string.find(text, "сереб") then
		return Color3.fromRGB(185, 191, 202)
	end

	return Color3.fromRGB(180, 174, 166)
end

local function clearPrompt()
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function showPrompt(prompt)
	if not isSupportedPrompt(prompt) then
		return
	end
	patchPrompt(prompt)

	clearPrompt()

	local part = getPart(prompt)
	if not part then
		return
	end

	local target = getTarget(part)
	local accent = getAccent(prompt)

	-- Тонкий контур кейса
	local highlight = Instance.new("Highlight")
	highlight.Name = "CaseInspectHighlight"
	highlight.Adornee = target
	highlight.FillTransparency = 1
	highlight.OutlineColor = accent
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = target

	activeHighlight = highlight

	TweenService:Create(
		highlight,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{OutlineTransparency = 0.25}
	):Play()

	-- Prompt
	local gui = Instance.new("BillboardGui")
	gui.Name = "CasePromptDisplay"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(225, 62)
	gui.StudsOffset = prompt.Name == "DailyReward"
		and Vector3.new(0, 0.8, 0)
		or Vector3.new(0, -0.7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 14
	gui.Parent = playerGui

	activeGui = gui

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(205, 48)
	root.BackgroundTransparency = 1
	root.Parent = gui

	-- Ромб E
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromOffset(26, 24)
	diamond.Size = UDim2.fromOffset(35, 35)
	diamond.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
	diamond.BackgroundTransparency = 0.02
	diamond.BorderSizePixel = 0
	diamond.Rotation = 45
	diamond.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.4
	stroke.Transparency = 0.05
	stroke.Parent = diamond

	local e = Instance.new("TextLabel")
	e.AnchorPoint = Vector2.new(0.5, 0.5)
	e.Position = UDim2.fromScale(0.5, 0.5)
	e.Size = UDim2.fromScale(1, 1)
	e.BackgroundTransparency = 1
	e.Text = "E"
	e.TextColor3 = Color3.fromRGB(245, 242, 237)
	e.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	e.TextStrokeTransparency = 0.7
	e.Font = Enum.Font.BuilderSansMedium
	e.TextSize = 17
	e.Rotation = -45
	e.Parent = diamond

	-- Осмотреть
	local action = Instance.new("TextLabel")
	action.Position = UDim2.fromOffset(57, 4)
	action.Size = UDim2.fromOffset(140, 40)
	action.BackgroundTransparency = 1
	action.Text = prompt.ActionText
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextYAlignment = Enum.TextYAlignment.Center

	action.TextColor3 = Color3.fromRGB(242, 239, 235)
	action.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	action.TextStrokeTransparency = 0.55

	action.Font = Enum.Font.BuilderSansMedium
	action.TextSize = 16
	action.TextTransparency = 1
	action.Parent = root

	local scale = Instance.new("UIScale")
	scale.Scale = 0.92
	scale.Parent = root

	TweenService:Create(
		scale,
		TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{Scale = 1}
	):Play()

	TweenService:Create(
		action,
		TweenInfo.new(0.1),
		{TextTransparency = 0}
	):Play()
end

local function hidePrompt(prompt)
	if not isSupportedPrompt(prompt) then
		return
	end

	if activeHighlight then
		local highlight = activeHighlight
		activeHighlight = nil

		local tween = TweenService:Create(
			highlight,
			TweenInfo.new(0.1),
			{OutlineTransparency = 1}
		)

		tween:Play()
		tween.Completed:Once(function()
			highlight:Destroy()
		end)
	end

	if activeGui then
		local gui = activeGui
		activeGui = nil

		local root = gui:FindFirstChildOfClass("Frame")
		local scale = root and root:FindFirstChildOfClass("UIScale")

		if scale then
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(0.08),
				{Scale = 0.94}
			)

			tween:Play()
			tween.Completed:Once(function()
				gui:Destroy()
			end)
		else
			gui:Destroy()
		end
	end
end


local purchaseLocked = false

local function triggerPrompt(prompt)
	if prompt.Name ~= "OpenSupport" or purchaseLocked then
		return
	end

	purchaseLocked = true
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, SUPPORT_PRODUCT_ID)
	end)

	task.delay(ok and 1 or 0.2, function()
		purchaseLocked = false
	end)
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") and isSupportedPrompt(descendant) then
		patchPrompt(descendant)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") and isSupportedPrompt(descendant) then
		task.defer(function()
			if descendant.Parent then
				patchPrompt(descendant)
			end
		end)
	end
end)

ProximityPromptService.PromptShown:Connect(showPrompt)
ProximityPromptService.PromptTriggered:Connect(triggerPrompt)
ProximityPromptService.PromptHidden:Connect(hidePrompt)
