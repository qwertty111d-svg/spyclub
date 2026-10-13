-- Cosmetic acquisition uses the existing profile, inventory and EconomyAction remote.
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Catalog = require(script.Parent.Catalog)
local Preview3D = require(script.Parent.Preview3D)
local FloatingUIController = require(script.Parent.FloatingUIController)

local AccessoryRollUI = {}
local C = {
    ink = Color3.fromRGB(12, 14, 18), surface = Color3.fromRGB(24, 27, 32),
    raised = Color3.fromRGB(36, 40, 46), line = Color3.fromRGB(81, 86, 94),
    text = Color3.fromRGB(239, 237, 230), muted = Color3.fromRGB(156, 163, 171),
    accent = Color3.fromRGB(198, 180, 142), error = Color3.fromRGB(223, 136, 132),
}
local COPY = {
    roll = {"Прокрутить", "Roll", "抽取"}, retry = {"Повторить запрос", "Retry request", "重试请求"},
    pending = {"Выбираем…", "Rolling…", "抽取中…"}, loading = {"Загружаем образ…", "Loading appearance…", "加载外观…"},
    idle = {"Выбери категорию", "Choose a category", "选择类别"}, empty = {"Нет доступных моделей", "No available models", "没有可用模型"},
    noRolls = {"Rolls закончились", "No Rolls remaining", "抽取次数不足"},
    rotate = {"Потяни, чтобы повернуть", "Drag to rotate", "拖动旋转"},
    inventory = {"Инвентарь", "Inventory", "背包"}, shop = {"Магазин", "Shop", "商店"},
    chance = {"Вероятности", "Drop chances", "掉落概率"}, equipped = {"Надето · сохранено", "Equipped · saved", "已装备 · 已保存"},
    duplicate = {"Ещё одна копия · сохранено", "Another copy · saved", "副本 · 已保存"},
    timeout = {"Ответ задерживается. Повтор безопасен.", "No reply yet. Retrying is safe.", "暂未收到回复，可安全重试。"},
    round = {"Образ доступен между матчами", "Appearance is available between matches", "比赛间隙可更改外观"},
    trade = {"Заверши обмен перед прокруткой", "Finish your trade before rolling", "请先完成交易"},
    save = {"Не удалось подтвердить сохранение. Повтори запрос.", "Save could not be confirmed. Retry the request.", "未能确认保存，请重试请求。"},
    unavailable = {"Профиль пока недоступен", "Profile is not available yet", "资料暂不可用"},
    style = {"Нет моделей для текущего образа", "No models for the current style", "当前风格没有可用模型"},
    stale = {"Данные обновлены. Можно прокрутить снова.", "Data refreshed. You can roll again.", "数据已更新，可再次抽取。"},
    slow = {"Подожди немного", "Please wait a moment", "请稍候"},
    lucky = {"Удача ×2", "Luck ×2", "幸运 ×2"},
}
local RARITY_ORDER = {"common", "uncommon", "rare", "epic", "legendary", "mythic"}

local function make(className, parent, properties)
    local node = Instance.new(className)
    for key, value in pairs(properties or {}) do node[key] = value end
    node.Parent = parent
    return node
end
local function text(parent, name, value, size, color)
    return make("TextLabel", parent, {Name = name, Text = value or "", TextSize = size or 16,
        Font = Enum.Font.BuilderSansMedium, TextColor3 = color or C.text, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, BorderSizePixel = 0})
end
local function action(parent, name, caption)
    local node = make("TextButton", parent, {Name = name, Text = caption, TextSize = 16,
        Font = Enum.Font.BuilderSansMedium, TextColor3 = C.text, BackgroundColor3 = C.raised,
        BackgroundTransparency = 0.25, AutoButtonColor = false, BorderSizePixel = 0})
    make("UICorner", node, {CornerRadius = UDim.new(0, 7)})
    if not UserInputService.TouchEnabled then
        node.MouseEnter:Connect(function()
            if node.Active then TweenService:Create(node, TweenInfo.new(0.12), {BackgroundTransparency = 0.04}):Play() end
        end)
        node.MouseLeave:Connect(function()
            TweenService:Create(node, TweenInfo.new(0.12), {BackgroundTransparency = 0.25}):Play()
        end)
    end
    return node
end

function AccessoryRollUI.create(ctx)
    local self = {visible = false, name = "accessoryRoll"}
    local alive = true
    local connections = {}
    local motionToken, previewKey, categoriesKey = 0, nil, nil
    local selected, pending, busy, retrying, spinning = nil, nil, false, false, nil
    local statusKey, statusError = nil, false
    local previewViewport
    local mobile = UserInputService.TouchEnabled
    local function tr(key)
        local row = COPY[key] or COPY.unavailable
        return row[ctx.language() == "zh" and 3 or ctx.language() == "en" and 2 or 1]
    end
    local function profile() return ctx.profile() or {} end
    local function dto() return profile().accessoryRoll or {} end
    local function categoryList() return dto().categories or {} end
    local function category(id)
        for _, row in ipairs(categoryList()) do if row.id == id then return row end end
        return nil
    end
    local function categoryName(row)
        if not row then return tr("idle") end
        return ctx.language() == "en" and (row.labelEn or row.label or row.id)
            or ctx.language() == "zh" and (row.labelZh or row.labelEn or row.label or row.id)
            or (row.labelRu or row.label or row.id)
    end
    local function roundActive()
        local state = ctx.state() or {}
        return state.tableId and state.phase ~= "Waiting" and state.phase ~= "Result"
    end

    -- The parent ScreenGui already respects Roblox's device-safe inset.
    local overlay = make("Frame", ctx.gui, {Name = "AccessoryRollOverlay", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.ink, BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, Active = true, ZIndex = 70})
    local dismiss = make("TextButton", overlay, {Name = "Dismiss", Size = UDim2.fromScale(1, 1),
        Text = "", BackgroundTransparency = 1, AutoButtonColor = false})
    local panel = make("CanvasGroup", overlay, {Name = "FloatingAppearance", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(920, 570),
        BackgroundColor3 = C.surface, BackgroundTransparency = 0.12, GroupTransparency = 0,
        BorderSizePixel = 0, Active = true})
    make("UICorner", panel, {CornerRadius = UDim.new(0, 12)})
    make("UIStroke", panel, {Color = C.line, Transparency = 0.58, Thickness = 1})
    local scale = make("UIScale", panel, {Scale = 1})
    local floating = FloatingUIController.create(panel, {container = overlay, maxOffset = 14, smoothTime = 0.15, safePadding = 18})
    local close = action(panel, "Close", "×")
    close.TextSize = 26
    close.BackgroundTransparency = 1

    local preview = make("Frame", panel, {Name = "PersonalPreview", BackgroundTransparency = 1, ClipsDescendants = true})
    local identity = text(preview, "Identity", ctx.player.DisplayName, 22)
    identity.Font = Enum.Font.BuilderSansBold
    identity.Position = UDim2.fromOffset(12, 8)
    identity.Size = UDim2.new(1, -24, 0, 34)
    local previewStage = make("Frame", preview, {Name = "PreviewStage", Position = UDim2.fromOffset(0, 44),
        Size = UDim2.new(1, 0, 1, -82), BackgroundTransparency = 1})
    local rotateHint = text(preview, "RotateHint", tr("rotate"), 13, C.muted)
    rotateHint.Position = UDim2.new(0, 8, 1, -32)
    rotateHint.Size = UDim2.new(1, -16, 0, 28)
    rotateHint.TextXAlignment = Enum.TextXAlignment.Center

    local controls = make("Frame", panel, {Name = "RollControls", BackgroundTransparency = 1})
    local count = text(controls, "RollBalance", "0 Rolls", 25, C.accent)
    count.Font = Enum.Font.BuilderSansBold
    local luck = text(controls, "LegacyLuck", "", 12, C.muted)
    local info = action(controls, "ChanceInfo", "ⓘ")
    info.TextSize = 22
    local categories = make("ScrollingFrame", controls, {Name = "Categories", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y})
    local categoryLayout = make("UIGridLayout", categories, {CellSize = UDim2.new(0.5, -5, 0, 56),
        CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    local current = make("CanvasGroup", controls, {Name = "CurrentItem", BackgroundTransparency = 1,
        GroupTransparency = 0})
    local slotLabel = text(current, "SelectedCategory", "", 13, C.muted)
    slotLabel.Position = UDim2.new()
    slotLabel.Size = UDim2.new(1, 0, 0, 22)
    local itemName = text(current, "ItemName", "", 21)
    itemName.Font = Enum.Font.BuilderSansBold
    itemName.Position = UDim2.fromOffset(0, 23)
    itemName.Size = UDim2.new(1, 0, 0, 32)
    itemName.TextWrapped = false
    itemName.TextTruncate = Enum.TextTruncate.AtEnd
    local rarity = text(current, "Rarity", "", 14, C.muted)
    rarity.Position = UDim2.fromOffset(0, 56)
    rarity.Size = UDim2.new(1, 0, 0, 26)
    local roll = action(controls, "Roll", "")
    roll.BackgroundColor3 = C.accent
    roll.TextColor3 = C.ink
    roll.Font = Enum.Font.BuilderSansBold
    roll.TextSize = 18
    roll.TextWrapped = false
    roll.TextTruncate = Enum.TextTruncate.AtEnd
    make("UIPadding", roll, {PaddingLeft = UDim.new(0, 44), PaddingRight = UDim.new(0, 6)})
    local pressScale = make("UIScale", roll, {Scale = 1})
    local rollIcon = text(roll, "CircularArrow", "↻", 29, C.ink)
    rollIcon.Size = UDim2.fromOffset(44, 48)
    rollIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    rollIcon.Position = UDim2.new(0, 30, 0.5, 0)
    local status = text(controls, "Status", "", 13, C.muted)
    local inventory = action(controls, "Inventory", tr("inventory"))
    local shop = action(controls, "Shop", tr("shop"))
    local oddsPanel = make("Frame", controls, {Name = "ActualServerChances", BackgroundColor3 = C.ink,
        BackgroundTransparency = 0.03, BorderSizePixel = 0, Visible = false, ZIndex = 8})
    make("UICorner", oddsPanel, {CornerRadius = UDim.new(0, 8)})
    make("UIStroke", oddsPanel, {Color = C.line, Transparency = 0.35})
    local oddsText = text(oddsPanel, "Odds", "", 14)
    oddsText.Position = UDim2.fromOffset(14, 12)
    oddsText.Size = UDim2.new(1, -28, 1, -24)
    oddsText.TextYAlignment = Enum.TextYAlignment.Top

    local function setStatus(key, isError)
        statusKey, statusError = key, isError == true
        status.Text = key and tr(key) or ""
        status.TextColor3 = statusError and C.error or C.muted
    end
    local function destroyPreview()
        floating:setPaused(false)
        if previewViewport then previewViewport:Destroy(); previewViewport = nil end
        previewKey = nil
    end
    local function refreshPreview(force)
        if not self.visible then return end
        local equipment = profile().equipped or {}
        local parts = {}
        for slot, id in pairs(equipment) do parts[#parts + 1] = tostring(slot) .. "=" .. tostring(id) end
        table.sort(parts)
        local key = table.concat(parts, ";")
        if not force and previewKey == key and previewViewport then return end
        destroyPreview()
        previewKey = key
        local ok, result = pcall(Preview3D.mountCollection, previewStage, {}, {
            equipped = equipment, character = ctx.player.Character, fullBody = true, motion = true,
            onDraggingChanged = function(value) floating:setPaused(value) end,
        })
        if ok then previewViewport = result else setStatus("loading", false); warn("[AccessoryRollUI] Preview: " .. tostring(result)) end
    end
    local function drawOdds()
        local row = category(selected)
        local lines = {categoryName(row) .. " · " .. tr("chance")}
        local probabilities = row and row.chances or {}
        local found = false
        for _, key in ipairs(RARITY_ORDER) do
            local probability = probabilities[key]
            if type(probability) == "number" and probability > 0 then
                local definition = Catalog.Rarities[key]
                lines[#lines + 1] = (ctx.language() == "en" and definition.en or definition.ru)
                    .. "   " .. string.format("%.2f%%", probability)
                found = true
            end
        end
        if not found then lines[#lines + 1] = tr("empty") end
        if dto().lucky then lines[#lines + 1] = tr("lucky") end
        oddsText.Text = table.concat(lines, "\n")
    end
    local function drawCurrent()
        local row = category(selected)
        local id = row and (profile().equipped or {})[row.slot or row.id]
        local item = id and Catalog.ById[id]
        slotLabel.Text = categoryName(row)
        itemName.Text = item and (ctx.language() == "en" and item.en or item.ru) or "—"
        local definition = item and Catalog.Rarities[item.rarity]
        rarity.Text = definition and (ctx.language() == "en" and definition.en or definition.ru) or ""
        rarity.TextColor3 = definition and Color3.fromRGB(table.unpack(definition.color)) or C.muted
        drawOdds()
    end
    local function drawCategories(force)
        local values = {ctx.language()}
        for _, row in ipairs(categoryList()) do values[#values + 1] = row.id .. ":" .. tostring(row.available) end
        local key = table.concat(values, "|")
        if not force and categoriesKey == key then return end
        categoriesKey = key
        for _, node in ipairs(categories:GetChildren()) do if node:IsA("GuiObject") then node:Destroy() end end
        for index, row in ipairs(categoryList()) do
            local button = action(categories, "Category_" .. row.id, categoryName(row))
            button.LayoutOrder = index
            button.TextSize = 15
            button.TextColor3 = row.available == false and C.muted or C.text
            button.Active = row.available ~= false
            button:SetAttribute("Category", row.id)
            make("UIStroke", button, {Color = C.accent, Transparency = row.id == selected and 0.3 or 1, Thickness = 1})
            button.Activated:Connect(function()
                if not button.Active or busy or pending then return end
                selected = row.id
                setStatus(nil)
                drawCategories(true); drawCurrent()
                self:update()
            end)
        end
    end

    function self:resize()
        local visible = overlay.AbsoluteSize
        if visible.X <= 0 or visible.Y <= 0 then return end
        local compact = mobile or visible.X < 760 or visible.Y < 540
        local portrait = compact and visible.Y > visible.X * 1.05
        -- Keep the physical button area >= 44 px even when desktop uses UIScale.
        local uiScale = compact and 1 or math.clamp(math.min(visible.X * 0.80 / 920, visible.Y * 0.79 / 570), 0.82, 1)
        local width = compact and math.min(720, visible.X - 44) or math.min(920, (visible.X - 64) / uiScale)
        local height = compact and math.min(660, visible.Y - 64) or math.min(570, (visible.Y - 64) / uiScale)
        width, height = math.max(240, width), math.max(240, height)
        panel.Size = UDim2.fromOffset(width, height)
        scale.Scale = uiScale
        floating:setBasePosition(UDim2.fromScale(0.5, 0.5))
        close.Position = UDim2.new(1, compact and -58 or -66, 0, 8)
        close.Size = UDim2.fromOffset(compact and 48 or 56, compact and 48 or 56)
        local controlWidth, controlHeight
        if portrait then
            local previewHeight = math.max(120, math.min(280, height * 0.43))
            preview.Position = UDim2.fromOffset(14, 10)
            preview.Size = UDim2.fromOffset(width - 28, previewHeight)
            controls.Position = UDim2.fromOffset(18, previewHeight + 20)
            controlWidth, controlHeight = width - 36, height - previewHeight - 34
        else
            local left = math.floor(width * (compact and 0.39 or 0.43))
            preview.Position = UDim2.fromOffset(18, 18)
            preview.Size = UDim2.fromOffset(left - 24, height - 36)
            controls.Position = UDim2.fromOffset(left + 12, 24)
            controlWidth, controlHeight = width - left - 38, height - 48
        end
        controls.Size = UDim2.fromOffset(controlWidth, controlHeight)
        count.Position = UDim2.new()
        count.Size = UDim2.new(1, portrait and -90 or -148, 0, 38)
        count.TextSize = compact and 21 or 25
        luck.Position = UDim2.fromOffset(0, 35)
        luck.Size = UDim2.new(1, -56, 0, 20)
        info.Position = UDim2.new(1, portrait and -50 or -114, 0, 6)
        info.Size = UDim2.fromOffset(compact and 48 or 56, compact and 48 or 56)
        local short = compact and not portrait and height < 400
        local categoriesTop = short and 46 or 62
        categories.Position = UDim2.fromOffset(0, categoriesTop)
        local categoriesHeight = short and 48 or compact and 54 or math.min(250, math.max(118, controlHeight - 274))
        categories.Size = UDim2.new(1, 0, 0, categoriesHeight)
        categories.ScrollingDirection = compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
        categories.AutomaticCanvasSize = compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
        categoryLayout.FillDirection = compact and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
        categoryLayout.FillDirectionMaxCells = compact and 1 or 2
        categoryLayout.CellSize = compact and UDim2.fromOffset(math.max(96, math.min(132, controlWidth * 0.43)), 48)
            or UDim2.new(0.5, -5, 0, 56)
        current.Position = UDim2.fromOffset(0, categoriesTop + 6 + categoriesHeight)
        current.Size = UDim2.new(1, 0, 0, short and 56 or compact and 72 or 88)
        itemName.TextSize = compact and 18 or 21
        slotLabel.Size = UDim2.new(1, 0, 0, short and 16 or 22)
        itemName.Position = UDim2.fromOffset(0, short and 15 or 23)
        itemName.Size = UDim2.new(1, 0, 0, short and 23 or 32)
        rarity.Position = UDim2.fromOffset(0, short and 37 or compact and 49 or 56)
        rarity.Size = UDim2.new(1, 0, 0, short and 18 or 26)
        local rollY = categoriesTop + 6 + categoriesHeight + (short and 60 or compact and 76 or 92)
        roll.Position = UDim2.fromOffset(0, rollY)
        roll.Size = UDim2.new(1, 0, 0, compact and 48 or 56)
        status.Position = UDim2.fromOffset(0, rollY + (compact and 50 or 59))
        status.Size = UDim2.new(1, 0, 0, 32)
        status.Visible = not short or rollY + 82 <= controlHeight + 10
        local footerY = rollY + (compact and 86 or 96)
        inventory.Position = UDim2.fromOffset(0, footerY)
        shop.Position = UDim2.new(0.5, 4, 0, footerY)
        inventory.Size = UDim2.new(0.5, -4, 0, compact and 48 or 54)
        shop.Size = inventory.Size
        local footerFits = footerY + (compact and 48 or 54) <= controlHeight
        inventory.Visible, shop.Visible = footerFits, footerFits
        oddsPanel.Position = UDim2.fromOffset(0, 62)
        oddsPanel.Size = UDim2.new(1, 0, 0, math.min(controlHeight - 62, 240))
    end

    function self:update(force)
        if not self.visible then return end
        if roundActive() then self:close(); return end
        if pending then selected = pending.category
        elseif not category(selected) then
            selected = nil
            for _, row in ipairs(categoryList()) do if row.available ~= false then selected = row.id; break end end
            if not selected and categoryList()[1] then selected = categoryList()[1].id end
        end
        count.Text = tostring(profile().rolls or 0) .. " Rolls"
        luck.Text = dto().lucky and tr("lucky") or ""
        rotateHint.Text = tr("rotate")
        inventory.Text, shop.Text = tr("inventory"), tr("shop")
        drawCategories(force); drawCurrent(); refreshPreview(false)
        local row = category(selected)
        local ready = profile().ready == true and row and row.available ~= false
        if (statusKey == "loading" and profile().ready == true)
            or (statusKey == "empty" and ready)
            or (statusKey == "trade" and row and row.reason ~= "trade_processing")
            or (statusKey == "noRolls" and (profile().rolls or 0) > 0) then setStatus(nil) end
        -- A save uncertainty can make the next snapshot unavailable. Retrying the
        -- retained request must still be possible without creating a second spend.
        local allowed = not busy and not ctx.pending()
            and ((retrying and pending ~= nil) or (ready and (profile().rolls or 0) > 0))
        roll.Active = allowed == true
        roll.BackgroundColor3 = roll.Active and C.accent or C.raised
        roll.TextColor3 = roll.Active and C.ink or C.muted
        rollIcon.TextColor3 = roll.TextColor3
        roll.Text = busy and tr("pending") or retrying and tr("retry") or tr("roll") .. " · 1 Roll"
        if statusKey then status.Text = tr(statusKey)
        elseif profile().ready ~= true then setStatus("loading")
        elseif row and row.reason == "trade_processing" then setStatus("trade")
        elseif not row or row.available == false then setStatus("empty")
        elseif (profile().rolls or 0) <= 0 and not retrying then setStatus("noRolls") end
    end

    function self:open(categoryId)
        if ctx.player:GetAttribute("SpyEntryPending") or ctx.player:GetAttribute("SpyEntryActive") then return false end
        local tourScreen = ctx.player.PlayerGui:FindFirstChild("SpyClubCinematicTour")
        local tourOverlay = tourScreen and tourScreen:FindFirstChild("LobbyTourOverlay")
        if tourOverlay and tourOverlay.Visible then return false end
        if roundActive() then ctx.notify(tr("round")); return false end
        if self.visible then
            if categoryId and category(categoryId) and not pending then selected = categoryId end
            self:update(true); return true
        end
        if ctx.closeDialogue then ctx.closeDialogue() end
        ctx.closePanels("accessoryRoll")
        if categoryId and category(categoryId) and not pending then selected = categoryId end
        self.visible = true
        if ctx.setActivePanel then ctx.setActivePanel("accessoryRoll") end
        motionToken += 1
        overlay.Visible = true
        overlay.BackgroundTransparency = 1
        panel.GroupTransparency = 1
        self:resize(); self:update(true)
        floating:setActive(true)
        TweenService:Create(panel, TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.30), {BackgroundTransparency = 0.80}):Play()
        return true
    end
    function self:close(animated)
        if not self.visible then return end
        self.visible = false
        floating:setActive(false)
        destroyPreview()
        if spinning then spinning:Cancel(); spinning = nil end
        rollIcon.Rotation = 0
        oddsPanel.Visible = false
        motionToken += 1
        local token = motionToken
        if ctx.getActivePanel and ctx.getActivePanel() == "accessoryRoll" and ctx.setActivePanel then ctx.setActivePanel(nil) end
        if animated == false then overlay.Visible = false; return end
        TweenService:Create(panel, TweenInfo.new(0.22), {GroupTransparency = 1}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.22), {BackgroundTransparency = 1}):Play()
        task.delay(0.22, function() if alive and token == motionToken and not self.visible then overlay.Visible = false end end)
    end
    function self:receive(receipt, requestId)
        if not pending or type(receipt) ~= "table" or requestId ~= pending.id then return false end
        local attempt = pending
        local delay = math.max(0, 0.62 - (os.clock() - attempt.started))
        task.delay(delay, function()
            if not alive or pending ~= attempt then return end
            if spinning then spinning:Cancel(); spinning = nil end
            rollIcon.Rotation = 0
            busy = false
            if receipt.ok and receipt.code == "accessoryRolled" then
                selected = receipt.category or attempt.category
                pending, retrying = nil, false
                setStatus(receipt.duplicate and "duplicate" or "equipped")
                current.GroupTransparency = 0.6
                TweenService:Create(current, TweenInfo.new(0.16), {GroupTransparency = 0}):Play()
                if ctx.playSound then ctx.playSound("Reward", 1.04) end
                self:update(true)
            else
                local code = receipt.code
                local uncertain = code == "save_failed" or code == "profile_unavailable"
                retrying = uncertain
                if not uncertain then pending = nil end
                local errors = {roll_empty = "noRolls", roll_no_items = "empty", roll_style = "style",
                    roll_stale_request = "stale", roll_request_conflict = "stale", appearanceLoading = "loading",
                    trade_processing = "trade", profile_unavailable = "unavailable", save_failed = "save", slowDown = "slow"}
                setStatus(errors[code] or "unavailable", true)
                self:update(true)
            end
        end)
        return true
    end
    roll.Activated:Connect(function()
        if not roll.Active or busy then return end
        if not pending then
            pending = {category = selected,
                id = tostring((dto().sequence or 0) + 1) .. "-" .. HttpService:GenerateGUID(false)}
        end
        pending.started = os.clock()
        local attempt, started = pending, pending.started
        busy, retrying = true, false
        setStatus(nil)
        TweenService:Create(pressScale, TweenInfo.new(0.08), {Scale = 0.96}):Play()
        task.delay(0.08, function() if alive then TweenService:Create(pressScale, TweenInfo.new(0.14), {Scale = 1}):Play() end end)
        if spinning then spinning:Cancel() end
        spinning = TweenService:Create(rollIcon, TweenInfo.new(0.65, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Rotation = 360})
        spinning:Play()
        self:update()
        local sent = ctx.request("accessoryRoll", attempt.category, attempt.id)
        if not sent then
            busy, retrying = false, true
            if spinning then spinning:Cancel(); spinning = nil end
            rollIcon.Rotation = 0
            setStatus("slow", true); self:update()
            return
        end
        task.delay(18.2, function()
            if not alive or pending ~= attempt or attempt.started ~= started or not busy then return end
            busy, retrying = false, true
            if spinning then spinning:Cancel(); spinning = nil end
            rollIcon.Rotation = 0
            setStatus("timeout", true); self:update()
        end)
    end)
    info.Activated:Connect(function() oddsPanel.Visible = not oddsPanel.Visible; drawOdds() end)
    inventory.Activated:Connect(function() ctx.openPanel("inventory") end)
    shop.Activated:Connect(function() ctx.openPanel("shop") end)
    close.Activated:Connect(function() self:close() end)
    dismiss.Activated:Connect(function() self:close() end)
    connections[#connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.Escape and self.visible then self:close() end
    end)
    connections[#connections + 1] = ctx.player.CharacterAdded:Connect(function(character)
        previewKey = nil
        task.spawn(function()
            character:WaitForChild("Humanoid", 10)
            character:WaitForChild("Head", 10)
            if alive and self.visible and character == ctx.player.Character then refreshPreview(true) end
        end)
    end)
    connections[#connections + 1] = ctx.player.CharacterAppearanceLoaded:Connect(function()
        if alive and self.visible then refreshPreview(true) end
    end)
    connections[#connections + 1] = overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if self.visible then self:resize() end end)
    overlay.Destroying:Once(function()
        alive = false
        floating:destroy()
        if spinning then spinning:Cancel() end
        for _, connection in ipairs(connections) do connection:Disconnect() end
    end)
    return self
end

return AccessoryRollUI
