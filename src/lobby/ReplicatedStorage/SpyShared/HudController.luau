-- Open club view: Play at the left edge, Character / Menu at the right.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local player = Players.LocalPlayer
local HudController = {}
HudController.__index = HudController
local C = {
    surface = Color3.fromRGB(27, 29, 33), hover = Color3.fromRGB(46, 49, 55),
    text = Color3.fromRGB(238, 236, 230), muted = Color3.fromRGB(166, 169, 174),
    line = Color3.fromRGB(100, 106, 114), brass = Color3.fromRGB(238, 238, 238),
    ink = Color3.fromRGB(18, 20, 23),
}
local definitions = {
    {"Inventory", nil, "accessoryRoll"}, {"Shop", nil, "clubStore"}, {"Daily", nil, "daily"},
    {"Profile", "hudProfile", "profile"}, {"Trade", "hudTrade", "trade"},
    {"Settings", "hudSettings", "settings"},
}
local blockedFlags = {"SpyTradeOpen", "SpyPhoneActive", "SpyCharacterMenuOpen", "SpyTeleporting", "SpyEntryPending", "SpyEntryActive", "SpyBilliardsPlaying", "SpyCheckersPlaying"}
local function externalPanel()
    for _, key in ipairs(blockedFlags) do if player and player:GetAttribute(key) == true then return true end end
    return false
end
local function dockText(definition, L)
    local language = player and player:GetAttribute("SpyLanguage") or "ru"
    if definition[1] == "Inventory" then
        return language == "en" and "Character" or language == "zh" and "角色" or "Персонаж"
    elseif definition[1] == "Shop" then
        return language == "en" and "Store" or language == "zh" and "商店" or "Магазин"
    elseif definition[1] == "Daily" then
        return language == "en" and "Daily" or language == "zh" and "每日奖励" or "Награды"
    end
    return L(definition[2])
end
local function prepare(button, primary)
    for _, child in ipairs(button:GetChildren()) do
        if child:IsA("GuiObject") then
            if child.Name ~= "NotificationBadge" then child.Visible = false end
        elseif child:IsA("UIGradient") or child:IsA("UIScale") and child.Name ~= "SpyUIFeedbackScale" or child:IsA("UIListLayout")
            or child:IsA("UIPadding") or child:IsA("UITextSizeConstraint") then child:Destroy()
        elseif child:IsA("UIStroke") then child.Enabled = false end
    end
    local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", button)
    corner.CornerRadius = UDim.new(0, 3)
    local outline = Instance.new("UIStroke")
    outline.Name = "HudOutline"
    outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outline.Color, outline.Transparency, outline.Thickness = C.text, 1, 1
    outline.Parent = button
    button.BorderSizePixel, button.TextScaled, button.AutoButtonColor = 0, false, false
    button.BackgroundColor3 = primary and C.ink or C.hover
    button.BackgroundTransparency = primary and 0.14 or 1
    button.TextColor3, button.TextTransparency = C.text, 0
    button.Font = primary and Enum.Font.Garamond or Enum.Font.BuilderSansMedium
    button.TextSize, button.TextWrapped = primary and 29 or 14, false
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.TextXAlignment, button.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
    button.Selectable, button.ZIndex = true, 14
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
    local rail = Instance.new("Frame")
    rail.Name, rail.Parent = "LowerRail", gui
    rail.BackgroundColor3, rail.BackgroundTransparency, rail.BorderSizePixel, rail.ZIndex = C.surface, 1, 0, 12
    local railCorner = Instance.new("UICorner", rail); railCorner.CornerRadius = UDim.new(0, 3)
    local rule = Instance.new("Frame", rail)
    rule.Name, rule.Position, rule.Size = "RailRule", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, 1)
    rule.BackgroundColor3, rule.BackgroundTransparency, rule.BorderSizePixel = C.line, 1, 0
    self.Rail = rail
    local arrow = Instance.new("TextLabel")
    arrow.Name, arrow.Parent = "PlayArrow", self.MainAction
    arrow.BackgroundTransparency, arrow.Text = 1, "→"
    arrow.Font, arrow.TextSize, arrow.TextColor3 = Enum.Font.Garamond, 30, C.text
    arrow.AnchorPoint, arrow.Position, arrow.Size = Vector2.new(1, 0.5), UDim2.new(1, -15, 0.5, 0), UDim2.fromOffset(25, 36)
    arrow.ZIndex = 15
    self.PlayArrow = arrow
    local playCaption = Instance.new("TextLabel")
    playCaption.Name, playCaption.Parent = "PlayCaption", self.MainAction
    playCaption.BackgroundTransparency, playCaption.Font, playCaption.TextColor3 = 1, Enum.Font.Garamond, C.text
    playCaption.TextWrapped, playCaption.TextTruncate, playCaption.ZIndex = false, Enum.TextTruncate.AtEnd, 15
    playCaption:SetAttribute("SpyUserText", true)
    self.PlayCaption = playCaption
    local playRule = Instance.new("Frame")
    playRule.Name, playRule.Parent = "PlayRule", self.MainAction
    playRule.Position, playRule.Size = UDim2.new(0, 12, 1, -1), UDim2.new(1, -24, 0, 1)
    playRule.BackgroundColor3, playRule.BackgroundTransparency, playRule.BorderSizePixel, playRule.ZIndex = C.text, 0.18, 0, 15
    self.MainAction.TextTransparency = 1
    table.insert(self.Connections, self.MainAction:GetPropertyChangedSignal("Text"):Connect(function() playCaption.Text = self.MainAction.Text end))
    self.MenuButton = Instance.new("TextButton")
    self.MenuButton.Name, self.MenuButton.Parent = "MobileMenu", gui
    local menuOutline = prepare(self.MenuButton, false)
    self.MenuButton.BackgroundColor3, self.MenuButton.BackgroundTransparency = C.ink, 0.14
    local menuShape = self.MenuButton:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    menuShape.CornerRadius, menuShape.Parent = UDim.new(0, 3), self.MenuButton
    menuOutline.Color, menuOutline.Transparency = C.line, 0.72
    self.MenuButton:SetAttribute("SpyUserText", true)
    table.insert(self.Connections, self.MenuButton.Activated:Connect(function()
        self.MenuExpanded = not self.MenuExpanded
        if self.QuickPanel then self.QuickPanel.Visible = false end
        self:resize()
    end))
    local tooltip = gui:FindFirstChild("Tooltip")
    if tooltip then tooltip.Visible = false end
    local dock = self.BottomDock
    dock.BackgroundTransparency, dock.BorderSizePixel, dock.ClipsDescendants, dock.ZIndex = 1, 0, false, 14
    for _, child in ipairs(dock:GetChildren()) do
        if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") then child:Destroy()
        elseif child:IsA("UIStroke") then child.Enabled = false
        elseif child:IsA("GuiObject") then child.Visible = false end
    end
    local secondary = Instance.new("ScrollingFrame")
    secondary.Name, secondary.Parent = "SecondaryNavigation", gui
    secondary.BackgroundColor3, secondary.BackgroundTransparency, secondary.BorderSizePixel = C.surface, 0.04, 0
    secondary.ScrollBarThickness, secondary.ScrollBarImageColor3 = 2, C.muted
    secondary.ScrollingDirection, secondary.ClipsDescendants, secondary.Visible, secondary.ZIndex = Enum.ScrollingDirection.Y, true, false, 18
    local menuCorner = Instance.new("UICorner", secondary); menuCorner.CornerRadius = UDim.new(0, 3)
    self.Secondary = secondary
    local dockSurface = Instance.new("Frame")
    dockSurface.Name, dockSurface.Parent = "NavigationSurface", dock
    dockSurface.Size, dockSurface.BackgroundColor3 = UDim2.fromScale(1, 1), C.surface
    dockSurface.BackgroundTransparency, dockSurface.BorderSizePixel, dockSurface.ZIndex = 1, 0, 13
    local navCorner = Instance.new("UICorner", dockSurface); navCorner.CornerRadius = UDim.new(0, 5)
    local navOutline = Instance.new("UIStroke", dockSurface)
    navOutline.Color, navOutline.Transparency, navOutline.Thickness = C.line, 1, 1
    self.DockSurface = dockSurface
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
        caption.Size, caption.Position = UDim2.new(1, -24, 0, 27), UDim2.fromOffset(12, 21)
        caption.Font, caption.TextSize = Enum.Font.Garamond, 20
        caption.TextWrapped, caption.TextTruncate = false, Enum.TextTruncate.AtEnd
        caption.TextColor3, caption.Text, caption.ZIndex = C.text, button.Text, 15
        caption:SetAttribute("SpyUserText", true)
        local folio = Instance.new("TextLabel")
        folio.Name, folio.Parent = "DockIndex", button
        folio.BackgroundTransparency, folio.Position, folio.Size = 1, UDim2.fromOffset(12, 7), UDim2.new(1, -24, 0, 12)
        folio.Font, folio.TextSize, folio.TextColor3, folio.Text = Enum.Font.BuilderSansMedium, 11, C.muted, index == 1 and "H" or ""
        folio.TextXAlignment, folio.ZIndex = Enum.TextXAlignment.Left, 15
        local divider = Instance.new("Frame")
        divider.Name, divider.Parent = "NavigationDivider", button
        divider.Position, divider.Size = UDim2.new(1, -1, 0, 12), UDim2.fromOffset(1, 28)
        divider.BackgroundColor3, divider.BackgroundTransparency, divider.BorderSizePixel, divider.ZIndex = C.line, 0.58, 0, 15
        local marker = Instance.new("Frame")
        marker.Name, marker.Parent = "ActiveMark", button
        marker.Position, marker.Size = UDim2.new(0, 12, 1, -1), UDim2.new(1, -24, 0, 1)
        marker.BackgroundColor3, marker.BorderSizePixel, marker.Visible = C.text, 0, false
        local badge = button:FindFirstChild("NotificationBadge")
        if badge then
            badge.BackgroundColor3, badge.BorderSizePixel, badge.ZIndex = C.text, 0, 16
            badge.Size, badge.Position = UDim2.fromOffset(4, 4), UDim2.new(1, -9, 0.5, -2)
        end
        self.Buttons[definition[1]] = {Button = button, Caption = caption, Stroke = outline,
            Marker = marker, Folio = folio, Divider = divider, Key = definition[2], Panel = definition[3]}
        table.insert(self.Connections, button:GetPropertyChangedSignal("Text"):Connect(function() caption.Text = button.Text end))
        if definition[1] == "Trade" then
            table.insert(self.Connections, button.Activated:Connect(function()
                local opener = gui.Parent and gui.Parent:FindFirstChild("SpyOpenTrade")
                if opener and opener:IsA("BindableEvent") then opener:Fire() end
            end))
        end
        local function focus(active)
            TweenService:Create(button, TweenInfo.new(0.12), {BackgroundTransparency = active and 0.25 or 1}):Play()
        end
        table.insert(self.Connections, button.MouseEnter:Connect(function() focus(true) end))
        table.insert(self.Connections, button.MouseLeave:Connect(function() focus(false) end))
        table.insert(self.Connections, button.Activated:Connect(function()
            self.MenuExpanded = false; self:resize()
        end))
    end
    table.insert(self.Connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end))
    if player then
        player:SetAttribute("SpyTradeDockReady", true)
        for _, key in ipairs(blockedFlags) do
            table.insert(self.Connections, player:GetAttributeChangedSignal(key):Connect(function() self:resize() end))
        end
    end
    self:resize(); self:update(false)
    return self
end
function HudController:setQuickChat(button, panel)
    if self.QuickButton == button then return end
    self.QuickButton, self.QuickPanel = button, panel
    button.Parent = self.Secondary
    prepare(button, false)
    button.TextSize, button.TextXAlignment, button.ZIndex = 14, Enum.TextXAlignment.Left, 19
    table.insert(self.Connections, button.Activated:Connect(function()
        self.MenuExpanded = false; self:resize()
    end))
end
function HudController:resize()
    local width, height = math.max(1, self.Gui.AbsoluteSize.X), self.Gui.AbsoluteSize.Y
    self.Mobile = Input.TouchEnabled or width < 700 or height < 430
    local portrait = self.Mobile and width < 600 and height >= 430
    local bottom = portrait and 176 or Input.TouchEnabled and height >= 300 and 80 or 24
    local gap = width < 360 and 6 or 12
    local playWidth = self.Mobile and (width < 360 and 88 or 128) or 204
    local characterWidth = self.Mobile and (width < 360 and 86 or 104) or 154
    local menuWidth = self.Mobile and 56 or 88
    local navWidth = characterWidth
    local totalWidth = playWidth + navWidth + menuWidth + gap * 2
    local left = self.Mobile and (width - totalWidth) / 2 or 32
    local right = self.Mobile and left + totalWidth or width - 32
    local navLeft = right - navWidth - menuWidth - gap
    local top = height - bottom - 60
    local unobstructed = not self.InRound and not self.Active and not externalPanel()
    if not unobstructed then self.MenuExpanded = false end
    self.Rail.Position, self.Rail.Size, self.Rail.Visible = UDim2.fromOffset(left, top), UDim2.fromOffset(right - left, 60), unobstructed
    self.MainAction.AnchorPoint = Vector2.new(0, 0)
    self.MainAction.Position, self.MainAction.Size = UDim2.fromOffset(left, top + 4), UDim2.fromOffset(playWidth, 52)
    self.PlayCaption.TextSize = self.Mobile and 24 or 34
    self.PlayCaption.TextXAlignment = self.Mobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    self.PlayCaption.Position = UDim2.fromOffset(self.Mobile and 8 or 14, 0)
    self.PlayCaption.Size = UDim2.new(1, self.Mobile and -16 or -60, 1, 0)
    self.PlayArrow.Visible = not self.Mobile
    self.BottomDock.AnchorPoint = Vector2.new(0, 0)
    self.BottomDock.Position, self.BottomDock.Size = UDim2.fromOffset(navLeft, top + 4), UDim2.fromOffset(navWidth, 52)
    self.MenuButton.AnchorPoint = Vector2.new(0, 0)
    self.MenuButton.Position, self.MenuButton.Size = UDim2.fromOffset(right - menuWidth, top + 4), UDim2.fromOffset(menuWidth, 52)
    self.MainAction.Visible, self.BottomDock.Visible, self.MenuButton.Visible = unobstructed, unobstructed, unobstructed
    local language = player and player:GetAttribute("SpyLanguage")
    self.MenuButton.Text = self.MenuExpanded and "×" or language == "en" and "Menu  +" or language == "zh" and "菜单 +" or self.Mobile and "Меню" or "Меню  +"
    self.MenuButton.TextSize = self.MenuExpanded and 25 or self.Mobile and 11 or 14
    local menuWidthFull = math.min(240, width - 24)
    local menuX = math.min(width - 12 - menuWidthFull, math.max(12, right - menuWidthFull))
    local secondaryCount = (self.QuickButton and 1 or 0) + 5
    local contentHeight = secondaryCount * 44 + 12
    local menuHeight = math.min(contentHeight, math.max(44, top - 12))
    self.Secondary.Position, self.Secondary.Size = UDim2.fromOffset(menuX, top - menuHeight - 8), UDim2.fromOffset(menuWidthFull, menuHeight)
    self.Secondary.CanvasSize = UDim2.fromOffset(0, contentHeight)
    self.Secondary.Visible = unobstructed and self.MenuExpanded
    local menuY = 6
    if self.QuickButton then
        self.QuickButton.Text = player and player:GetAttribute("SpyLanguage") == "en" and "Quick phrases" or "Быстрые фразы"
        self.QuickButton.Visible = unobstructed and self.MenuExpanded
        self.QuickButton.Position, self.QuickButton.Size = UDim2.fromOffset(8, menuY), UDim2.fromOffset(menuWidthFull - 16, 44)
        self.QuickButton.AnchorPoint = Vector2.new(0, 0)
        menuY += 44
        if not unobstructed and self.QuickPanel then self.QuickPanel.Visible = false end
        if self.QuickPanel then
            self.QuickPanel.AnchorPoint = Vector2.new(0, 0)
            local panelHeight = self.QuickPanel.Size.Y.Offset
            self.QuickPanel.Position = UDim2.fromOffset(math.max(12, menuX - 64), math.max(12, math.min(height - panelHeight - 12, top - panelHeight - 16)))
        end
    end
    local navX = 0
    for index, definition in ipairs(definitions) do
        local entry = self.Buttons[definition[1]]
        local persistent = index == 1
        local button = entry.Button
        button.Parent = (persistent or not self.MenuExpanded) and self.BottomDock or self.Secondary
        button.AnchorPoint = Vector2.new(0, 0)
        button.Visible = unobstructed and (persistent or self.MenuExpanded)
        if persistent then
            local cellWidth = index == 1 and characterWidth or 108
            button.Position, button.Size = UDim2.fromOffset(navX, 0), UDim2.fromOffset(cellWidth, 52)
            navX += cellWidth
            entry.Caption.Position, entry.Caption.Size = UDim2.fromOffset(self.Mobile and 8 or 34, 0), UDim2.new(1, self.Mobile and -16 or -42, 1, 0)
            entry.Caption.Font, entry.Caption.TextSize, entry.Caption.TextXAlignment = Enum.Font.Garamond, self.Mobile and 18 or 23, self.Mobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
            entry.Folio.Position, entry.Folio.Size = UDim2.fromOffset(12, 0), UDim2.new(0, 18, 1, 0)
        else
            button.Position, button.Size = UDim2.fromOffset(8, menuY), UDim2.fromOffset(menuWidthFull - 16, 44)
            menuY += 44
            entry.Caption.Position, entry.Caption.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0)
            entry.Caption.Font, entry.Caption.TextSize, entry.Caption.TextXAlignment = Enum.Font.BuilderSansMedium, 14, Enum.TextXAlignment.Left
        end
        entry.Folio.Visible = persistent and not self.Mobile
        entry.Divider.Visible = false
        button.ZIndex, entry.Caption.ZIndex = persistent and 14 or 19, persistent and 15 or 20
    end
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
        item.Caption.TextColor3 = active and C.text or C.muted
        item.Marker.Visible = active
    end
end
function HudController:update(inRound)
    self.InRound = inRound
    self:resize()
    local language = player and player:GetAttribute("SpyLanguage") or "ru"
    self.MainAction:SetAttribute("SpyUserText", true)
    self.MainAction.Text = language == "en" and "Play" or language == "zh" and "开始游戏" or "Играть"
    self.PlayCaption.Text = self.MainAction.Text
    for _, definition in ipairs(definitions) do
        local item = self.Buttons[definition[1]]
        item.Button.Text = dockText(definition, self.L)
        item.Caption.Text = item.Button.Text
    end
end
function HudController:Destroy()
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections)
    self.Rail:Destroy(); self.Secondary:Destroy(); self.MenuButton:Destroy()
    if player then player:SetAttribute("SpyTradeDockReady", false) end
end
return HudController
