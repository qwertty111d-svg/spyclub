-- Local presentation only. Action handlers remain owned by each control.
local TweenService = game:GetService("TweenService")
local Input = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ClientPreferences = require(script.Parent:WaitForChild("ClientPreferences"))
local UIFeedback = {}
local roots = setmetatable({}, {__mode = "k"})
local excluded = {Dismiss=true, DismissBackdrop=true, DismissClubStore=true, PremiumDismiss=true, DrawerBackdrop=true}
local motionOwners = {TopicPanel=true, BallotOverlay=true, BallotPanel=true, AnotherClueRound=true}

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

function UIFeedback.start(playerGui, player)
	if roots[playerGui] then return roots[playerGui] end
	local controller = {}
	roots[playerGui] = controller
	local dead = false
	local buttons, connections = {}, {}
	local lastHover = -math.huge
	local audioRoot = Instance.new("Folder")
	audioRoot.Name = "SpyUIFeedbackAudio"
	audioRoot.Parent = SoundService
	local function sound(name, base, speed)
		local node = Instance.new("Sound")
		node.Name = name
		node.SoundId = "rbxassetid://113397864512278"
		node.Volume = base
		node.PlaybackSpeed = speed
		node:SetAttribute("SpyAudioCategory", "SFX")
		-- ClientPreferences records this unscaled base when the sound is parented.
		node.Parent = audioRoot
		return node
	end
	local click = sound("UIClick", .12, 1)
	local hover = sound("UIHover", .025, 1.25)
	local function play(node)
		local preferences = ClientPreferences.get()
		if dead or not node.Parent or (tonumber(preferences.sfxVolume) or 1) <= 0 then return end
		node:Stop()
		node:Play()
	end
	local function allowed(button)
		if dead or not button.Active or button.Interactable == false or not button:IsDescendantOf(playerGui) then return false end
		local node = button
		while node and node ~= playerGui do
			if node.Name == "SpyPhoneUI" or excluded[node.Name] then return false end
			if node:IsA("GuiObject") and not node.Visible then return false end
			if node:IsA("LayerCollector") and not node.Enabled then return false end
			node = node.Parent
		end
		return node == playerGui
	end
	local function pointerAvailable(button, input)
		local ok, hits = pcall(function()
			local touch = input and input.UserInputType == Enum.UserInputType.Touch
			local point = touch and input.Position or Input:GetMouseLocation()
			local x, y = point.X, point.Y
			if not touch then
				-- Mouse locations are raw screen pixels; touch Position already excludes the inset.
				local insetOK, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
				if insetOK and inset then x -= tonumber(inset.X) or 0; y -= tonumber(inset.Y) or 0 end
			end
			return playerGui:GetGuiObjectsAtPosition(x, y)
		end)
		-- Older test/preview hosts need not expose native screen hit testing.
		if not ok or type(hits) ~= "table" then return true end
		for _, hit in ipairs(hits) do
			if hit == button or hit:IsDescendantOf(button) then return true end
			-- A transparent layout wrapper does not cover controls behind it.
			if not button:IsDescendantOf(hit) and hit:IsA("GuiObject")
				and (hit.Active or hit.BackgroundTransparency < 1) then return false end
		end
		return false
	end
	local function resetScale(record)
		if record.tween then record.tween:Cancel(); record.tween = nil end
		if record.scale and record.scale.Parent == record.button then record.scale.Scale = 1 end
	end
	local function reset(record)
		record.pointer, record.selected, record.input = false, false, nil
		resetScale(record)
	end
	local function motionAllowed(record)
		if player:GetAttribute("SpyReducedMotion") == true or not allowed(record.button) then return false end
		local node = record.button
		while node and node ~= playerGui do
			if motionOwners[node.Name] or node.Name:sub(1, 8) == "Suspect_" or node:GetAttribute("ThemeId") ~= nil then return false end
			node = node.Parent
		end
		for _, child in ipairs(record.button:GetChildren()) do
			if child:IsA("UIScale") and child ~= record.scale then return false end
		end
		return true
	end
	local function scaleTo(record, target)
		if not motionAllowed(record) then resetScale(record); return end
		if not record.scale or record.scale.Parent ~= record.button then
			if target == 1 then return end
			-- Never reuse a scale belonging to another presentation owner.
			local scale = Instance.new("UIScale")
			scale.Name = "SpyUIFeedbackScale"
			scale.Scale = 1
			record.scale = scale
			scale.Parent = record.button
		end
		if record.tween then record.tween:Cancel() end
		record.tween = TweenService:Create(record.scale, TweenInfo.new(.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=target})
		record.tween:Play()
	end
	local function enter(record, kind)
		if not allowed(record.button) then reset(record); return end
		-- MouseEnter also fires beneath other GUI; selection focus is independent.
		if kind == "pointer" and not pointerAvailable(record.button) then
			record.pointer = false
			if not record.selected and not record.input then resetScale(record) end
			return
		end
		local wasHovered = record.pointer or record.selected
		record[kind] = true
		if not wasHovered and os.clock() - lastHover >= .09 then
			lastHover = os.clock()
			play(hover)
		end
		if not record.input then scaleTo(record, 1.01) end
	end
	local function leave(record, kind)
		record[kind] = false
		record.input = nil
		scaleTo(record, (record.pointer or record.selected) and 1.01 or 1)
	end
	local function pressInput(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
	end
	local function beginPress(record, input)
		if record.input or not pressInput(input) or not allowed(record.button) then return end
		if input.KeyCode ~= Enum.KeyCode.ButtonA and not pointerAvailable(record.button, input) then return end
		record.input = input
		-- Owners can hide or destroy their control in Activated before our listener.
		-- A valid press gives tactile audio now; its later Activated is deduplicated.
		record.clickOnPress = true
		play(click)
		scaleTo(record, .985)
	end
	local cleanup
	local function watchAncestors(record)
		disconnect(record.ancestors)
		local node = record.button.Parent
		while node and node ~= playerGui do
			local property = node:IsA("GuiObject") and "Visible" or node:IsA("LayerCollector") and "Enabled"
			if property then
				table.insert(record.ancestors, node:GetPropertyChangedSignal(property):Connect(function()
					if not allowed(record.button) then reset(record) end
				end))
			end
			node = node.Parent
		end
	end
	cleanup = function(button)
		local record = buttons[button]
		if not record then return end
		buttons[button] = nil
		reset(record)
		disconnect(record.connections)
		disconnect(record.ancestors)
		if record.scale and record.scale.Parent == button then record.scale:Destroy() end
	end
	local function bind(button)
		if dead or not button:IsA("GuiButton") or buttons[button] or not button:IsDescendantOf(playerGui) then return end
		local node = button
		while node and node ~= playerGui do
			if node.Name == "SpyPhoneUI" or excluded[node.Name] then return end
			node = node.Parent
		end
		local record = {button=button, connections={}, ancestors={}, pointer=false, selected=false}
		buttons[button] = record
		local function connect(event, callback) table.insert(record.connections, event:Connect(callback)) end
		connect(button.MouseEnter, function() enter(record, "pointer") end)
		connect(button.MouseLeave, function() leave(record, "pointer") end)
		connect(button.SelectionGained, function() enter(record, "selected") end)
		connect(button.SelectionLost, function() leave(record, "selected") end)
		connect(button.InputBegan, function(input)
			beginPress(record, input)
		end)
		connect(button.Activated, function()
			local sounded = record.clickOnPress
			record.clickOnPress = false
			if not sounded and allowed(button) then play(click) end
			record.input = nil
			scaleTo(record, 1)
		end)
		for _, property in ipairs({"Active", "Interactable", "Visible"}) do
			connect(button:GetPropertyChangedSignal(property), function() if not allowed(button) then reset(record) end end)
		end
		connect(button.ChildAdded, function(child)
			if child:IsA("UIScale") and child ~= record.scale then resetScale(record) end
		end)
		connect(button.AncestryChanged, function()
			if not button:IsDescendantOf(playerGui) then cleanup(button)
			else reset(record); watchAncestors(record) end
		end)
		connect(button.Destroying, function() cleanup(button) end)
		watchAncestors(record)
	end
	local function queueBind(node)
		if node:IsA("GuiButton") then
			-- Factories can install their own UIScale after setting Parent.
			task.defer(function() bind(node) end)
		end
	end
	for _, node in ipairs(playerGui:GetDescendants()) do queueBind(node) end
	table.insert(connections, playerGui.DescendantAdded:Connect(queueBind))
	table.insert(connections, playerGui.DescendantRemoving:Connect(function(node)
		if buttons[node] then cleanup(node) end
	end))
	table.insert(connections, Input.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonA then
			for _, record in pairs(buttons) do
				if record.selected then beginPress(record, input) end
			end
		end
	end))
	table.insert(connections, Input.InputEnded:Connect(function(input)
		for _, record in pairs(buttons) do
			local pressed = record.input
			if pressed and (pressed == input
				or input.UserInputType == Enum.UserInputType.MouseButton1 and pressed.UserInputType == input.UserInputType
				or input.KeyCode == Enum.KeyCode.ButtonA and pressed.KeyCode == input.KeyCode) then
				record.input = nil
				scaleTo(record, 1)
			end
		end
	end))
	table.insert(connections, Input.WindowFocusReleased:Connect(function()
		for _, record in pairs(buttons) do reset(record) end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("SpyReducedMotion"):Connect(function()
		if player:GetAttribute("SpyReducedMotion") == true then
			for _, record in pairs(buttons) do resetScale(record) end
		end
	end))
	function controller:destroy()
		if dead then return end
		dead = true
		roots[playerGui] = nil
		disconnect(connections)
		local bound = {}
		for button in pairs(buttons) do table.insert(bound, button) end
		for _, button in ipairs(bound) do cleanup(button) end
		audioRoot:Destroy()
	end
	table.insert(connections, playerGui.Destroying:Connect(function() controller:destroy() end))
	return controller
end

return UIFeedback
