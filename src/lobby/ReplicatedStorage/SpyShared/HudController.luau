-- Style the authored controls in one compact rail; existing click owners remain intact.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local player = Players.LocalPlayer
local HudController = {}
HudController.__index = HudController
local C = {
    surface = Color3.fromRGB(34, 36, 38), hover = Color3.fromRGB(45, 47, 49),
    text = Color3.fromRGB(238, 233, 223), muted = Color3.fromRGB(170, 166, 157),
    line = Color3.fromRGB(120, 115, 104), brass = Color3.fromRGB(192, 166, 115),
    ink = Color3.fromRGB(19, 21, 23),
}
-- Keep authored names and callbacks, including the daily reward and trade routes.
local definitions = {
    {"Shop", nil, "clubStore"}, {"Daily", nil, "daily"},
    {"Profile", "hudProfile", "profile"}, {"Trade", "hudTrade", "trade"},
    {"Settings", "hudSettings", "settings"},
}
local function externalPanel()
    return player and (player:GetAttribute("SpyTradeOpen") == true or player:GetAttribute("SpyPhoneActive") == true)
end
local function dockText(definition, L)
    local language = player and player:GetAttribute("SpyLanguage") or "ru"
    if definition[1] == "Shop" then
        return language == "en" and "Store" or language == "zh" and "商店" or "Магазин"
    elseif definition[1] == "Daily" then
        return language == "en" and "Daily reward" or language == "zh" and "每日奖励" or "Награда"
    end
    return L(definition[2])
end
local function prepare(button, primary)
    for _, child in ipairs(button:GetChildren()) do
        if child:IsA("GuiObject") then
            if child.Name ~= "NotificationBadge" then child.Visible = false end
        elseif child:IsA("UIGradient") or child:IsA("UIScale") or child:IsA("UIListLayout")
            or child:IsA("UIPadding") or child:IsA("UITextSizeConstraint") then child:Destroy()
        elseif child:IsA("UIStroke") then child.Enabled = false end
    end
    local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", button)
    corner.CornerRadius = UDim.new(0, 4)
    local outline = Instance.new("UIStroke")
    outline.Name = "HudOutline"
    outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outline.Color, outline.Transparency, outline.Thickness = C.brass, 1, 1
    outline.Parent = button
    button.BorderSizePixel, button.TextScaled, button.AutoButtonColor = 0, false, false
    button.BackgroundColor3 = primary and C.brass or C.surface
    button.BackgroundTransparency = primary and 0 or 1
    button.TextColor3, button.TextTransparency = primary and C.ink or C.text, 0
    button.Font = primary and Enum.Font.BuilderSansBold or Enum.Font.BuilderSansMedium
    button.TextSize, button.TextWrapped = primary and 18 or 14, false
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.TextXAlignment, button.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
    button.Selectable = true
    return outline
end
function HudController.new(gui, L)
    local self = setmetatable({Gui = gui, L = L, Connections = {}, Buttons = {},
        Active = nil, MenuExpanded = false, InRound = false}, HudController)
    self.MainAction = gui:WaitForChild("MainAction")
    self.BottomDock = gui:WaitForChild("BottomDesk")
    self.MainAction.Active = true
    prepare(self.MainAction, true)
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    self.MenuButton = Instance.new("TextButton")
    self.MenuButton.Name, self.MenuButton.Parent = "MobileMenu", gui
    prepare(self.MenuButton, false)
    self.MenuButton.BackgroundTransparency = 0.04
    table.insert(self.Connections, self.MenuButton.Activated:Connect(function()
        self.MenuExpanded = not self.MenuExpanded
        self:resize()
    end))
    local tooltip = gui:FindFirstChild("Tooltip")
    if tooltip then tooltip.Visible = false end
    local dock = self.BottomDock
    dock.BackgroundColor3, dock.BackgroundTransparency, dock.BorderSizePixel = C.surface, 0.04, 0
    for _, child in ipairs(dock:GetChildren()) do
        if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") then child:Destroy()
        elseif child:IsA("UIStroke") then child.Enabled = false
        elseif child:IsA("GuiObject") then child.Visible = false end
    end
    local corner = dock:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", dock)
    corner.CornerRadius = UDim.new(0, 6)
    local dockLine = dock:FindFirstChild("DockOutline") or Instance.new("UIStroke", dock)
    dockLine.Name, dockLine.Enabled = "DockOutline", true
    dockLine.Color, dockLine.Transparency, dockLine.Thickness = C.line, 0.5, 1
    for index, definition in ipairs(definitions) do
        local button = dock:FindFirstChild(definition[1])
        if not button then button = Instance.new("TextButton"); button.Name = definition[1]; button.Parent = dock end
        button.Visible, button.Active = true, true
        button.Text = dockText(definition, L)
        button:SetAttribute("SpyUserText", true)
        local outline = prepare(button, false)
        button.SelectionOrder = index + 1
        button.TextTransparency = 1
        local caption = Instance.new("TextLabel")
        caption.Name, caption.Parent = "DockLabel", button
        caption.BackgroundTransparency = 1
        caption.Size, caption.Position = UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0)
        caption.Font, caption.TextSize = Enum.Font.BuilderSansMedium, 14
        caption.TextWrapped, caption.TextTruncate = false, Enum.TextTruncate.AtEnd
        caption.TextColor3 = definition[1] == "Shop" and C.brass or C.text
        caption.Text = button.Text
        caption:SetAttribute("SpyUserText", true)
        local marker = Instance.new("Frame")
        marker.Name, marker.Parent = "ActiveMark", button
        marker.Position, marker.Size = UDim2.new(0, 12, 1, -1), UDim2.new(1, -24, 0, 1)
        marker.BackgroundColor3, marker.BorderSizePixel, marker.Visible = C.brass, 0, false
        local badge = button:FindFirstChild("NotificationBadge")
        if badge then
            badge.BackgroundColor3, badge.BorderSizePixel = C.brass, 0
            badge.Size, badge.Position = UDim2.fromOffset(5, 5), UDim2.new(1, -9, 0.5, -2)
            local badgeCorner = badge:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", badge)
            badgeCorner.CornerRadius = UDim.new(1, 0)
        end
        self.Buttons[definition[1]] = {Button = button, Caption = caption, Stroke = outline,
            Marker = marker, Key = definition[2], Panel = definition[3]}
        table.insert(self.Connections, button:GetPropertyChangedSignal("Text"):Connect(function() caption.Text = button.Text end))
        if definition[1] == "Trade" then
            table.insert(self.Connections, button.Activated:Connect(function()
                local opener = gui.Parent and gui.Parent:FindFirstChild("SpyOpenTrade")
                if opener and opener:IsA("BindableEvent") then opener:Fire() end
            end))
        end
        local function focus(active)
            TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = C.hover,
                BackgroundTransparency = active and 0.08 or 1}):Play()
            outline.Transparency = active and 0.55 or 1
        end
        table.insert(self.Connections, button.MouseEnter:Connect(function() focus(true) end))
        table.insert(self.Connections, button.MouseLeave:Connect(function() focus(self.Active == definition[3]) end))
        table.insert(self.Connections, button.SelectionGained:Connect(function() focus(true) end))
        table.insert(self.Connections, button.SelectionLost:Connect(function() focus(self.Active == definition[3]) end))
    end
    table.insert(self.Connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end))
    if player then
        player:SetAttribute("SpyTradeDockReady", true)
        for _, key in ipairs({"SpyTradeOpen", "SpyPhoneActive"}) do
            table.insert(self.Connections, player:GetAttributeChangedSignal(key):Connect(function() self:resize() end))
        end
    end
    self:resize()
    self:update(false)
    return self
end
function HudController:resize()
    local width, height = math.max(1, self.Gui.AbsoluteSize.X), self.Gui.AbsoluteSize.Y
    self.Mobile = Input.TouchEnabled or width < 760 or height < 430
    local portrait = width < 600 and height >= 430
    -- Stay above Roblox's default touch controls in a portrait lobby.
    local bottom = self.Mobile and portrait and 176 or 16
    local dockWidth, dockHeight
    if self.Mobile then
        dockWidth, dockHeight = math.min(256, width - 28), #definitions * 44 + 12
        self.BottomDock.AnchorPoint = Vector2.new(0.5, 1)
        self.BottomDock.Position = UDim2.new(0.5, 0, 1, -(bottom + 54))
        self.BottomDock.Size = UDim2.fromOffset(dockWidth, dockHeight)
        for index, definition in ipairs(definitions) do
            local item = self.Buttons[definition[1]]
            item.Button.Position, item.Button.Size = UDim2.fromOffset(6, 6 + (index - 1) * 44), UDim2.fromOffset(dockWidth - 12, 44)
            item.Caption.TextXAlignment, item.Caption.TextSize = Enum.TextXAlignment.Left, 14
        end
        local actionWidth = math.min(212, math.max(140, width - 132))
        local menuWidth, gap = 88, 8
        local groupWidth = actionWidth + menuWidth + gap
        self.MainAction.AnchorPoint, self.MenuButton.AnchorPoint = Vector2.new(0, 1), Vector2.new(0, 1)
        self.MainAction.Position = UDim2.new(0.5, -groupWidth / 2, 1, -bottom)
        self.MainAction.Size, self.MainAction.TextSize = UDim2.fromOffset(actionWidth, 44), 17
        self.MenuButton.Position = UDim2.new(0.5, -groupWidth / 2 + actionWidth + gap, 1, -bottom)
        self.MenuButton.Size, self.MenuButton.TextSize = UDim2.fromOffset(menuWidth, 44), 14
    else
        local actionWidth, gap, padding = width < 900 and 180 or 206, 16, 6
        local cellWidth = math.min(112, math.floor((width - 28 - actionWidth - gap - padding * 2) / #definitions))
        dockWidth, dockHeight = cellWidth * #definitions + padding * 2, 56
        local groupWidth = actionWidth + gap + dockWidth
        self.MainAction.AnchorPoint = Vector2.new(0, 1)
        self.MainAction.Position = UDim2.new(0.5, -groupWidth / 2, 1, -bottom)
        self.MainAction.Size, self.MainAction.TextSize = UDim2.fromOffset(actionWidth, 56), 18
        self.BottomDock.AnchorPoint = Vector2.new(0, 1)
        self.BottomDock.Position = UDim2.new(0.5, -groupWidth / 2 + actionWidth + gap, 1, -bottom)
        self.BottomDock.Size = UDim2.fromOffset(dockWidth, dockHeight)
        for index, definition in ipairs(definitions) do
            local item = self.Buttons[definition[1]]
            item.Button.Position, item.Button.Size = UDim2.fromOffset(padding + (index - 1) * cellWidth, 6), UDim2.fromOffset(cellWidth, 44)
            item.Caption.TextXAlignment, item.Caption.TextSize = Enum.TextXAlignment.Center, 14
        end
    end
    local unobstructed = not self.InRound and not self.Active and not externalPanel()
    self.MainAction.Visible = unobstructed
    self.MenuButton.Text = self.L("menuToggle")
    self.MenuButton.Visible = self.Mobile and unobstructed
    self.BottomDock.Visible = unobstructed and (not self.Mobile or self.MenuExpanded)
    local status = self.Gui:FindFirstChild("TopStatus")
    if status then
        local statusWidth, statusHeight = self.Mobile and math.min(232, width - 112) or 292, 36
        status.AnchorPoint, status.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 8)
        status.Size = UDim2.fromOffset(statusWidth, statusHeight)
        status.BackgroundTransparency = 1
        local coins = status:FindFirstChild("Coins")
        if coins then coins.Visible = false end
        for index, name in ipairs({"Level", "Rolls"}) do
            local pill = status:FindFirstChild(name)
            if pill then
                pill.Position = UDim2.fromOffset((index - 1) * (statusWidth / 2 + 3), 0)
                pill.Size = UDim2.fromOffset(statusWidth / 2 - 3, statusHeight)
                pill.BackgroundColor3, pill.BackgroundTransparency, pill.BorderSizePixel = C.surface, 0.04, 0
                local corner = pill:FindFirstChildOfClass("UICorner")
                if corner then corner.CornerRadius = UDim.new(0, 4) end
                for _, node in ipairs(pill:GetDescendants()) do
                    if node:IsA("UIStroke") then node.Color, node.Transparency, node.Thickness = C.line, 0.65, 1 end
                end
                local value = pill:FindFirstChild("Value")
                if value then
                    value.Position, value.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0)
                    value.TextSize, value.Font, value.TextColor3 = 14, Enum.Font.BuilderSansMedium, C.text
                end
                local icon = pill:FindFirstChild("Icon")
                if icon then icon.Visible = false end
            end
        end
    end
end
function HudController:setActive(name)
    self.Active = name
    if name then self.MenuExpanded = false end
    self:resize()
    for _, item in pairs(self.Buttons) do
        local active = name == item.Panel
        item.Button.BackgroundColor3, item.Button.BackgroundTransparency = C.hover, active and 0.08 or 1
        item.Caption.TextColor3 = (active or item.Panel == "accessoryRoll") and C.brass or C.text
        item.Marker.Visible, item.Stroke.Transparency = active, 1
    end
end
function HudController:update(inRound)
    self.InRound = inRound
    self:resize()
    local language = player and player:GetAttribute("SpyLanguage") or "ru"
    self.MainAction:SetAttribute("SpyUserText", true)
    self.MainAction.Text = language == "en" and "Play" or language == "zh" and "开始游戏" or "Играть"
    for _, definition in ipairs(definitions) do
        local item = self.Buttons[definition[1]]
        item.Button.Text = dockText(definition, self.L)
        item.Caption.Text = item.Button.Text
    end
end
function HudController:Destroy()
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections)
    if player then player:SetAttribute("SpyTradeDockReady", false) end
end
return HudController
