-- One personal dossier, one server-owned Rolls wallet, and one retained request per roll.
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Catalog = require(script.Parent.Catalog)
local CharacterIdentity = require(script.Parent.CharacterIdentity)
local RollConfig = require(script.Parent.AccessoryRollConfig)
local Preview3D = require(script.Parent.Preview3D)
local FloatingUIController = require(script.Parent.FloatingUIController)

local AccessoryRollUI = {}
local C = {
    ink = Color3.fromRGB(13, 14, 16), surface = Color3.fromRGB(26, 27, 29),
    raised = Color3.fromRGB(41, 42, 44), line = Color3.fromRGB(120, 115, 104),
    text = Color3.fromRGB(236, 231, 219), muted = Color3.fromRGB(164, 160, 150),
    brass = Color3.fromRGB(192, 166, 115), oxblood = Color3.fromRGB(95, 42, 44),
    error = Color3.fromRGB(231, 157, 151),
}
local COPY = {
    title = {"Личное дело", "Personal dossier", "个人档案"},
    classification = {"SPY CLUB  /  АРХИВ ПЕРСОНАЛА", "SPY CLUB  /  PERSONNEL ARCHIVE", "SPY CLUB  /  人员档案"},
    subject = {"ОБЪЕКТ НАБЛЮДЕНИЯ", "SUBJECT OF RECORD", "档案对象"},
    surname = {"Фамилия", "Surname", "姓氏"}, firstName = {"Имя", "First name", "名字"},
    origin = {"Происхождение", "Origin", "来源"},
    originHint = {"Новое происхождение меняет имя и фамилию", "New origin also changes first name and surname", "新来源也会更改名字和姓氏"},
    rotate = {"Потяни, чтобы повернуть", "Drag to rotate", "拖动旋转"},
    wardrobe = {"ГАРДЕРОБ", "WARDROBE", "衣橱"},
    roll = {"Новый вариант", "Roll a new look", "抽取新外观"}, retry = {"Повторить запрос", "Retry request", "重试请求"},
    pending = {"Подтверждаем…", "Confirming…", "确认中…"},
    loading = {"Загружаем личное дело…", "Loading your dossier…", "加载档案…"},
    empty = {"Нет вариантов для прокрутки", "No options to roll", "没有可抽取的选项"},
    none = {"Без предмета", "No item equipped", "未装备物品"},
    original = {"Исходный образ", "Original appearance", "原始外观"},
    owned = {"Моя коллекция", "My collection", "我的收藏"},
    ownedHint = {"Выбери уже полученный предмет", "Choose an item you already own", "选择已获得的物品"},
    noOwned = {"Новые предметы появятся здесь после прокрутки", "Rolled items will appear here", "抽取的物品将显示在这里"},
    equip = {"Надеть", "Equip", "装备"}, saved = {"Надето · сохранено", "Equipped · saved", "已装备 · 已保存"},
    identitySaved = {"Личное дело обновлено · сохранено", "Dossier updated · saved", "档案已更新 · 已保存"},
    duplicate = {"Ещё одна копия · сохранено", "Another copy · saved", "副本 · 已保存"},
    equipped = {"Надето", "Equipped", "已装备"},
    noRolls = {"Rolls закончились — их можно заработать", "No Rolls left — earn more below", "抽取次数不足，可在下方赚取"},
    earn = {"Как получить Rolls", "Earn Rolls", "赚取抽取次数"},
    earnTitle = {"Следующее дело", "Your next assignment", "下一项任务"},
    starter = {"При первом входе", "On your first visit", "首次加入"},
    complete = {"За завершённый матч", "For completing a match", "完成一场比赛"},
    win = {"Дополнительно за победу", "Extra for a win", "赢得比赛的额外奖励"},
    daily = {"Ежедневная награда", "Daily reward", "每日奖励"},
    dailyOpen = {"Открыть ежедневную награду", "Open daily reward", "打开每日奖励"},
    costHint = {"Любая прокрутка — 1 Roll", "Every roll costs 1 Roll", "每次抽取消耗 1 次数"},
    odds = {"Вероятности", "Drop chances", "掉落概率"},
    uniform = {"Все варианты равновероятны", "Every option has an equal chance", "每个选项的概率相同"},
    timeout = {"Ответ задерживается. Повтор безопасен.", "No reply yet. Retrying is safe.", "暂未收到回复，可安全重试。"},
    round = {"Изменения доступны после матча", "Changes are available after the match", "比赛结束后可修改"},
    trade = {"Заверши обмен перед прокруткой", "Finish your trade before rolling", "请先完成交易"},
    save = {"Сохранение не подтверждено. Повтори запрос.", "Save is unconfirmed. Retry the request.", "未能确认保存，请重试请求。"},
    unavailable = {"Профиль пока недоступен", "Profile is not available yet", "资料暂不可用"},
    style = {"Нет вариантов для текущего образа", "No options for the current style", "当前风格没有可用选项"},
    stale = {"Данные обновлены. Можно прокрутить снова.", "Data refreshed. You can roll again.", "数据已更新，可再次抽取。"},
    slow = {"Подожди немного", "Please wait a moment", "请稍候"},
    waiting = {"Дождись подтверждения предыдущего запроса", "Wait for your previous request to confirm", "等待上一次请求确认"},
    close = {"Закрыть", "Close", "关闭"},
}
local IDENTITY_ROWS = {
    {id = "lastName", copy = "surname"},
    {id = "firstName", copy = "firstName"},
    {id = "nationality", copy = "origin"},
}
local RARITY_ORDER = {"common", "uncommon", "rare", "epic", "legendary", "mythic"}

local function make(className, parent, properties)
    local node = Instance.new(className)
    for key, value in pairs(properties or {}) do node[key] = value end
    if node:IsA("GuiObject") and parent and parent:IsA("GuiObject") and not (properties and properties.ZIndex) then
        node.ZIndex = parent.ZIndex + 1
    end
    node.Parent = parent
    return node
end
local function label(parent, name, value, size, color)
    return make("TextLabel", parent, {Name = name, Text = value or "", TextSize = size or 16,
        Font = Enum.Font.BuilderSansMedium, TextColor3 = color or C.text, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0})
end
local function button(parent, name, caption)
    local node = make("TextButton", parent, {Name = name, Text = caption or "", TextSize = 14,
        Font = Enum.Font.BuilderSansMedium, TextColor3 = C.text, BackgroundColor3 = C.raised,
        BackgroundTransparency = 0.55, AutoButtonColor = false, BorderSizePixel = 0,
        Selectable = true, SelectionOrder = 1, TextTruncate = Enum.TextTruncate.AtEnd})
    make("UICorner", node, {CornerRadius = UDim.new(0, 5)})
    local border = make("UIStroke", node, {Color = C.brass, Transparency = 1, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    local function focus(value)
        if value and node.Active then
            TweenService:Create(border, TweenInfo.new(0.12), {Transparency = 0.28}):Play()
        else
            TweenService:Create(border, TweenInfo.new(0.12), {Transparency = 1}):Play()
        end
    end
    node.MouseEnter:Connect(function() focus(true) end)
    node.MouseLeave:Connect(function() focus(false) end)
    node.SelectionGained:Connect(function() focus(true) end)
    node.SelectionLost:Connect(function() focus(false) end)
    return node
end
local function divider(parent, name)
    return make("Frame", parent, {Name = name, Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.line, BackgroundTransparency = 0.70, BorderSizePixel = 0})
end

function AccessoryRollUI.create(ctx)
    local self = {visible = false, name = "accessoryRoll"}
    local alive, compact, portrait = true, false, false
    local connections = {}
    local selected, pending, busy, retrying = nil, nil, false, false
    local previewViewport, previewKey, tabsKey, ownedKey, spinning, spinnerNode
    local statusKey, statusError, equipRequestId, previousSelection
    local motionToken = 0
    local drawerMode = nil
    local tabButtons, identityRows = {}, {}
    local startRoll, renderDrawer
    local function tr(key)
        local row = COPY[key] or COPY.unavailable
        return row[ctx.language() == "zh" and 3 or ctx.language() == "en" and 2 or 1]
    end
    local function profile() return ctx.profile() or {} end
    local function dto() return profile().accessoryRoll or {} end
    local function identity() return profile().identity or dto().identity or {} end
    local function categoryList() return dto().categories or {} end
    local function category(id)
        for _, row in ipairs(categoryList()) do if row.id == id then return row end end
        return nil
    end
    local function cosmeticCategories()
        local rows = {}
        for _, row in ipairs(categoryList()) do if row.identity ~= true then rows[#rows + 1] = row end end
        return rows
    end
    local function categoryName(row)
        if not row then return tr("wardrobe") end
        return ctx.language() == "en" and (row.labelEn or row.label or row.id)
            or ctx.language() == "zh" and (row.labelZh or row.labelEn or row.label or row.id)
            or (row.labelRu or row.label or row.id)
    end
    local function itemName(item)
        return ctx.language() == "en" and (item.en or item.ru or item.id) or (item.ru or item.en or item.id)
    end
    local function roundActive()
        local state = ctx.state() or {}
        return state.tableId and state.phase ~= "Waiting" and state.phase ~= "Result" and state.phase ~= "Finished"
    end
    local function requestPending() return ctx.pending and ctx.pending() or false end
    local function canRoll(id)
        if busy or requestPending() or drawerMode then return false end
        -- Retrying a retained ID only recovers its authoritative receipt. The
        -- server distinguishes recovery from a fresh spend during an active match.
        if pending then return retrying and pending.category == id end
        if roundActive() then return false end
        local row = category(id)
        return profile().ready == true and row ~= nil and row.available ~= false and (profile().rolls or 0) > 0
    end

    -- The parent ScreenGui supplies device-safe insets. The sheet retains a 12px edge on phones.
    local overlay = make("Frame", ctx.gui, {Name = "AccessoryRollOverlay", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.ink, BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, Active = true, ZIndex = 80})
    local dismiss = make("TextButton", overlay, {Name = "Dismiss", Size = UDim2.fromScale(1, 1),
        Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Selectable = false, ZIndex = 81})
    local panel = make("CanvasGroup", overlay, {Name = "PersonalDossier", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1080, 660),
        BackgroundColor3 = C.surface, BackgroundTransparency = 0.16, GroupTransparency = 0,
        BorderSizePixel = 0, Active = true, ZIndex = 82, ClipsDescendants = true, SelectionGroup = true,
        SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
        SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop})
    make("UICorner", panel, {CornerRadius = UDim.new(0, 9)})
    make("UIStroke", panel, {Color = C.brass, Transparency = 0.65, Thickness = 1})
    local floating = FloatingUIController.create(panel, {container = overlay, maxOffset = 10,
        smoothTime = 0.15, safePadding = 12})
    local header = make("Frame", panel, {Name = "DossierHeader", BackgroundTransparency = 1})
    local title = label(header, "DossierTitle", tr("title"), 34)
    title.Font = Enum.Font.Garamond
    local classification = label(header, "ArchiveClassification", tr("classification"), 10, C.muted)
    local balance = label(header, "RollBalance", "0 Rolls", 22, C.brass)
    balance.Font = Enum.Font.BuilderSansBold
    balance.TextXAlignment = Enum.TextXAlignment.Right
    local earn = button(header, "EarnRolls", tr("earn"))
    earn.TextColor3 = C.brass
    earn.BackgroundTransparency = 1
    earn.TextXAlignment = Enum.TextXAlignment.Right
    local close = button(header, "CloseDossier", "×")
    close.TextSize = 28
    close.BackgroundTransparency = 1
    close.SelectionOrder = 1
    close:SetAttribute("AccessibleLabel", tr("close"))
    local headerLine = divider(panel, "HeaderRule")

    local preview = make("Frame", panel, {Name = "PersonalPortrait", BackgroundTransparency = 1})
    local subject = label(preview, "SubjectLabel", tr("subject"), 10, C.brass)
    local previewStage = make("Frame", preview, {Name = "PortraitStage", BackgroundTransparency = 1,
        ClipsDescendants = true})
    local portraitName = label(preview, "PortraitName", ctx.player.DisplayName, 22)
    portraitName.Font = Enum.Font.Garamond
    portraitName.TextXAlignment = Enum.TextXAlignment.Center
    local rotateHint = label(preview, "RotateHint", tr("rotate"), 12, C.muted)
    rotateHint.TextXAlignment = Enum.TextXAlignment.Center
    local verticalLine = divider(panel, "DossierSpine")

    local content = make("ScrollingFrame", panel, {Name = "DossierFields", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.brass, ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true, AutomaticCanvasSize = Enum.AutomaticSize.None})
    for index, definition in ipairs(IDENTITY_ROWS) do
        local row = make("CanvasGroup", content, {Name = "Identity_" .. definition.id,
            BackgroundTransparency = 1, GroupTransparency = 0})
        local caption = label(row, "FieldLabel", tr(definition.copy), 12, C.muted)
        local value = label(row, "FieldValue", "—", 23)
        local reroll = button(row, "Reroll_" .. definition.id, "")
        reroll.BackgroundTransparency = 1
        reroll.SelectionOrder = index + 1
        reroll:SetAttribute("RollCategory", definition.id)
        local icon = label(reroll, "RerollIcon", "↻", 24, C.brass)
        icon.TextXAlignment = Enum.TextXAlignment.Center
        local cost = label(reroll, "RollCost", "1 Roll", 11, C.muted)
        cost.TextXAlignment = Enum.TextXAlignment.Center
        local rule = divider(row, "FieldRule")
        identityRows[definition.id] = {frame = row, caption = caption, value = value, button = reroll,
            icon = icon, cost = cost, rule = rule, definition = definition}
        reroll.Activated:Connect(function() if startRoll then startRoll(definition.id) end end)
    end
    local originHint = label(content, "OriginRule", tr("originHint"), 11, C.muted)
    local current = make("CanvasGroup", content, {Name = "CurrentWardrobeItem", BackgroundTransparency = 1,
        GroupTransparency = 0})
    local slotLabel = label(current, "SelectedCategory", "", 11, C.brass)
    local currentName = label(current, "EquippedItemName", "", 23)
    local rarity = label(current, "ItemRarity", "", 12, C.muted)
    local odds = button(current, "ShowOdds", "ⓘ")
    odds.BackgroundTransparency = 1
    odds.TextColor3 = C.muted
    odds.TextSize = 20
    local owned = button(content, "ChooseOwned", "")
    owned.TextXAlignment = Enum.TextXAlignment.Left
    make("UIPadding", owned, {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)})
    local ownedChevron = label(owned, "OpenCollection", "›", 25, C.brass)
    ownedChevron.AnchorPoint = Vector2.new(1, 0.5)
    ownedChevron.Position = UDim2.new(1, -12, 0.5, 0)
    ownedChevron.Size = UDim2.fromOffset(20, 34)
    local collectionNote = label(content, "CollectionHint", tr("ownedHint"), 11, C.muted)

    local footer = make("Frame", panel, {Name = "WardrobeFooter", BackgroundTransparency = 1})
    local tabRail = make("ScrollingFrame", footer, {Name = "WardrobeTabs", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.brass, ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X, ClipsDescendants = true})
    make("UIListLayout", tabRail, {FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top})
    local footerLine = divider(footer, "FooterRule")
    local roll = button(footer, "RollSelectedSlot", "")
    roll.BackgroundColor3 = C.brass
    roll.BackgroundTransparency = 0
    roll.Font = Enum.Font.BuilderSansBold
    roll.TextColor3 = C.ink
    roll.TextSize = 16
    make("UIPadding", roll, {PaddingLeft = UDim.new(0, 42), PaddingRight = UDim.new(0, 18)})
    local pressScale = make("UIScale", roll, {Scale = 1})
    local rollIcon = label(roll, "RerollIcon", "↻", 26, C.ink)
    rollIcon.AnchorPoint = Vector2.new(0, 0.5)
    rollIcon.Position = UDim2.new(0, 12, 0.5, 0)
    rollIcon.Size = UDim2.fromOffset(30, 40)
    rollIcon.TextXAlignment = Enum.TextXAlignment.Center
    local status = label(footer, "RequestStatus", "", 12, C.muted)
    status.TextWrapped = true
    status.TextTruncate = Enum.TextTruncate.None
    status.TextYAlignment = Enum.TextYAlignment.Top

    local drawerShade = make("TextButton", panel, {Name = "DrawerBackdrop", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.ink, BackgroundTransparency = 0.34, Text = "", AutoButtonColor = false,
        Visible = false, Selectable = false, ZIndex = 110})
    local drawer = make("Frame", panel, {Name = "DossierDrawer", BackgroundColor3 = C.surface,
        BackgroundTransparency = 0.02, BorderSizePixel = 0, Visible = false, ZIndex = 111,
        ClipsDescendants = true, SelectionGroup = true,
        SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
        SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop})
    make("UICorner", drawer, {CornerRadius = UDim.new(0, 7)})
    make("UIStroke", drawer, {Color = C.brass, Transparency = 0.46})
    local drawerTitle = label(drawer, "DrawerTitle", "", 28)
    drawerTitle.Font = Enum.Font.Garamond
    local drawerSubtitle = label(drawer, "DrawerSubtitle", "", 12, C.muted)
    local drawerClose = button(drawer, "CloseDrawer", "×")
    drawerClose.BackgroundTransparency = 1
    drawerClose.TextSize = 26
    local drawerList = make("ScrollingFrame", drawer, {Name = "DrawerRows", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.brass, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y})
    make("UIListLayout", drawerList, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    local daily = button(drawer, "OpenDailyReward", tr("dailyOpen"))
    daily.BackgroundColor3 = C.oxblood
    daily.BackgroundTransparency = 0.12

    local function setStatus(key, isError)
        statusKey, statusError = key, isError == true
        status.Text = key and tr(key) or tr("costHint")
        status.TextColor3 = statusError and C.error or C.muted
    end
    local function stopSpinner()
        if spinning then spinning:Cancel(); spinning = nil end
        if spinnerNode then spinnerNode.Rotation = 0; spinnerNode = nil end
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
        if ok then previewViewport = result
        else warn("[AccessoryRollUI] Preview: " .. tostring(result)) end
    end
    local function closeDrawer()
        drawerMode = nil
        drawer.Visible, drawerShade.Visible = false, false
        ownedKey = nil
        if self.visible then self:update() end
        if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(drawer) then
            GuiService.SelectedObject = roll.Active and roll or close
        end
    end
    local function openDrawer(mode)
        drawerMode = mode
        drawer.Visible, drawerShade.Visible = true, true
        drawerList.CanvasPosition = Vector2.zero
        ownedKey = nil
        renderDrawer()
        self:update()
        if UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then
            GuiService.SelectedObject = drawerClose
        end
    end
    local function ownedItems()
        local row = category(selected)
        if not row then return {} end
        local result = {}
        for _, item in ipairs(Catalog.Items) do
            if (item.equipSlot or item.kind) == (row.slot or row.id) and (profile().owned or {})[item.id] == true then
                result[#result + 1] = item
            end
        end
        table.sort(result, function(a, b) return itemName(a) < itemName(b) end)
        return result
    end
    renderDrawer = function()
        if not drawerMode then return end
        local values = {drawerMode, selected or "", ctx.language(), tostring(requestPending()),
            tostring(pending ~= nil), tostring(roundActive()), tostring(profile().ready)}
        for id, equippedId in pairs(profile().equipped or {}) do values[#values + 1] = id .. "=" .. tostring(equippedId) end
        for id, isOwned in pairs(profile().owned or {}) do if isOwned then values[#values + 1] = id end end
        table.sort(values)
        local key = table.concat(values, "|")
        if ownedKey == key then return end
        ownedKey = key
        for _, child in ipairs(drawerList:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        daily.Visible = drawerMode == "earn"
        if drawerMode == "earn" then
            drawerTitle.Text, drawerSubtitle.Text = tr("earnTitle"), roundActive() and tr("round") or tr("costHint")
            local rewards = RollConfig.Rewards
            local rows = {{"starter", rewards.starter}, {"complete", rewards.completeMatch},
                {"win", rewards.win}, {"daily", rewards.daily}}
            for index, reward in ipairs(rows) do
                local row = make("Frame", drawerList, {Name = "Earn_" .. reward[1],
                    Size = UDim2.new(1, -6, 0, 48), BackgroundTransparency = 1, LayoutOrder = index})
                local caption = label(row, "RewardSource", tr(reward[1]), 14)
                caption.Size = UDim2.new(1, -84, 1, 0)
                local amount = label(row, "RollsReward", "+" .. tostring(reward[2]) .. " Rolls", 14, C.brass)
                amount.TextXAlignment = Enum.TextXAlignment.Right
                amount.Position, amount.Size = UDim2.new(1, -84, 0, 0), UDim2.fromOffset(80, 48)
                local rule = divider(row, "RewardRule")
                rule.Position = UDim2.new(0, 0, 1, -1)
            end
        elseif drawerMode == "odds" then
            local row = category(selected)
            drawerTitle.Text, drawerSubtitle.Text = tr("odds"), categoryName(row)
            local found = false
            for index, rarityId in ipairs(RARITY_ORDER) do
                local chance = (row and row.chances or {})[rarityId]
                if type(chance) == "number" and chance > 0 then
                    local definition = Catalog.Rarities[rarityId]
                    local line = label(drawerList, "Odds_" .. rarityId,
                        (ctx.language() == "en" and definition.en or definition.ru) .. "     " .. string.format("%.2f%%", chance), 15)
                    line.Size, line.LayoutOrder = UDim2.new(1, -6, 0, 36), index
                    found = true
                end
            end
            if not found then
                local line = label(drawerList, "OddsUnavailable", tr("empty"), 14, C.muted)
                line.Size = UDim2.new(1, -6, 0, 50)
            end
        else
            local row = category(selected)
            drawerTitle.Text, drawerSubtitle.Text = tr("owned"), categoryName(row)
            local items = ownedItems()
            local currentId = row and (profile().equipped or {})[row.slot or row.id]
            local editable = profile().ready == true and not requestPending() and not pending and not roundActive()
            local function addChoice(id, caption, item, index)
                local isEquipped = id == currentId or id == "" and (not currentId or currentId == "")
                local choice = button(drawerList, "Owned_" .. (id ~= "" and id or "none"), "")
                choice.Size, choice.LayoutOrder = UDim2.new(1, -6, 0, 56), index
                choice.Active, choice.Selectable = editable and not isEquipped, editable and not isEquipped
                choice.BackgroundColor3 = isEquipped and C.oxblood or C.raised
                choice.BackgroundTransparency = isEquipped and 0.25 or 0.65
                local name = label(choice, "ItemName", caption, 15, editable and C.text or C.muted)
                name.Position, name.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -52, 0, 24)
                local note = label(choice, "ItemState", isEquipped and tr("equipped") or tr("equip"), 11, C.muted)
                note.Position, note.Size = UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 18)
                if isEquipped then
                    local check = label(choice, "EquippedCheck", "✓", 18, C.brass)
                    check.Position, check.Size = UDim2.new(1, -35, 0, 10), UDim2.fromOffset(24, 24)
                elseif item and Catalog.Rarities[item.rarity] then
                    local dot = make("Frame", choice, {Name = "RarityMark", Position = UDim2.new(1, -22, 0, 17),
                        Size = UDim2.fromOffset(5, 5), BorderSizePixel = 0,
                        BackgroundColor3 = Color3.fromRGB(table.unpack(Catalog.Rarities[item.rarity].color))})
                    make("UICorner", dot, {CornerRadius = UDim.new(1, 0)})
                end
                choice.Activated:Connect(function()
                    if not choice.Active or requestPending() or pending or not row or roundActive() then return end
                    local requestId = ctx.request("equip", id == "" and "clear:" .. (row.slot or row.id) or id)
                    if requestId then
                        equipRequestId = requestId
                        closeDrawer(); setStatus("pending"); self:update()
                        task.delay(18.2, function()
                            if alive and equipRequestId == requestId then
                                equipRequestId = nil
                                setStatus("unavailable", true); self:update()
                            end
                        end)
                    end
                end)
            end
            addChoice("", (selected == "hair" or selected == "outfit") and tr("original") or tr("none"), nil, 1)
            -- Equipped choices are a no-op: the inventory endpoint otherwise toggles them off.
            for index, item in ipairs(items) do addChoice(item.id, itemName(item), item, index + 1) end
            if #items == 0 then
                local line = label(drawerList, "EmptyCollection", tr("noOwned"), 13, C.muted)
                line.Size, line.LayoutOrder, line.TextWrapped = UDim2.new(1, -8, 0, 64), 2, true
            end
        end
    end
    local function reveal(target)
        if not self.visible or not target then return end
        target.GroupTransparency = 0.65
        TweenService:Create(target, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {GroupTransparency = 0}):Play()
    end
    local function drawTabs(force)
        local rows = cosmeticCategories()
        local keys = {ctx.language(), selected or ""}
        for _, row in ipairs(rows) do keys[#keys + 1] = row.id .. ":" .. categoryName(row) end
        local key = table.concat(keys, "|")
        if not force and tabsKey == key then return end
        tabsKey = key
        tabButtons = {}
        for _, child in ipairs(tabRail:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        for index, row in ipairs(rows) do
            local tab = button(tabRail, "Slot_" .. row.id, categoryName(row))
            tab.Size, tab.LayoutOrder, tab.SelectionOrder = UDim2.fromOffset(compact and 100 or 94, 44), index, index + 5
            tab.BackgroundTransparency = selected == row.id and 0.36 or 1
            tab.BackgroundColor3 = selected == row.id and C.oxblood or C.raised
            tab.TextSize = 13
            tab.TextColor3 = selected == row.id and C.text or C.muted
            tab:SetAttribute("RollCategory", row.id)
            local underline = make("Frame", tab, {Name = "SelectedRule", Position = UDim2.new(0, 8, 1, -2),
                Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = C.brass, BorderSizePixel = 0,
                Visible = selected == row.id})
            underline.BackgroundTransparency = 0.2
            tabButtons[row.id] = tab
            tab.Activated:Connect(function()
                if pending or busy then return end
                selected = row.id
                setStatus(nil)
                self:update(true)
            end)
        end
    end
    local function scrollSelectedTab()
        local tab = tabButtons[selected]
        if not tab then return end
        task.defer(function()
            if not alive or not tab.Parent then return end
            local x = tab.AbsolutePosition.X - tabRail.AbsolutePosition.X + tabRail.CanvasPosition.X
            local view = tabRail.AbsoluteSize.X
            local canvas = tabRail.CanvasPosition.X
            if x < canvas then canvas = x
            elseif x + tab.AbsoluteSize.X > canvas + view then canvas = x + tab.AbsoluteSize.X - view end
            tabRail.CanvasPosition = Vector2.new(math.max(0, canvas), 0)
        end)
    end

    function self:resize()
        local viewport = overlay.AbsoluteSize
        if viewport.X <= 0 or viewport.Y <= 0 then return end
        compact = viewport.X < 760 or viewport.Y < 540
        portrait = compact and viewport.Y > viewport.X * 1.03
        local width = math.max(240, math.min(1080, viewport.X - (compact and 24 or 80)))
        local height = math.max(240, math.min(portrait and 760 or 660, viewport.Y - (compact and 24 or 80)))
        panel.Size = UDim2.fromOffset(width, height)
        floating:setBasePosition(UDim2.fromScale(0.5, 0.5))
        local padding = compact and 16 or 30
        local headerHeight = compact and 70 or 87
        header.Position, header.Size = UDim2.fromOffset(padding, 10), UDim2.fromOffset(width - padding * 2, headerHeight - 12)
        local headerWidth = width - padding * 2
        title.Position, title.Size = UDim2.fromOffset(0, compact and 4 or 6), UDim2.fromOffset(headerWidth - (compact and 142 or 232), compact and 30 or 42)
        title.TextSize = compact and 26 or 36
        classification.Position = UDim2.fromOffset(1, 48)
        classification.Size = UDim2.fromOffset(headerWidth - 230, 18)
        classification.Visible = not compact
        balance.Position, balance.Size = UDim2.new(1, compact and -146 or -223, 0, 2), UDim2.fromOffset(compact and 98 or 167, 27)
        balance.TextSize = compact and 18 or 22
        earn.Position, earn.Size = UDim2.new(1, compact and -184 or -239, 0, 25), UDim2.fromOffset(compact and 136 or 183, 44)
        earn.TextSize = compact and 11 or 13
        close.Position, close.Size = UDim2.new(1, -44, 0, 0), UDim2.fromOffset(44, 44)
        headerLine.Position, headerLine.Size = UDim2.fromOffset(padding, headerHeight), UDim2.fromOffset(width - padding * 2, 1)
        local footerHeight = compact and 146 or 164
        local footerTop = height - footerHeight - (compact and 10 or 18)
        local contentTop = headerHeight + (compact and 12 or 18)
        local contentWidth, bodyHeight, identityX, identityWidth, identityHeight
        if portrait then
            content.Position = UDim2.fromOffset(padding, contentTop)
            contentWidth, bodyHeight = width - padding * 2, footerTop - contentTop - 8
            preview.Parent = content
            preview.Position, preview.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(92, 155)
            identityX, identityWidth, identityHeight = 104, contentWidth - 104, 49
            verticalLine.Visible = false
            subject.Visible, portraitName.Visible, rotateHint.Visible = false, false, false
            previewStage.Position, previewStage.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(90, 153)
            originHint.Position, originHint.Size = UDim2.fromOffset(0, 157), UDim2.fromOffset(contentWidth, 29)
            originHint.TextSize, originHint.TextWrapped = 10, true
            current.Position, current.Size = UDim2.fromOffset(0, 193), UDim2.fromOffset(contentWidth, 74)
            owned.Position, owned.Size = UDim2.fromOffset(0, 275), UDim2.fromOffset(contentWidth, 44)
            collectionNote.Position, collectionNote.Size = UDim2.fromOffset(0, 325), UDim2.fromOffset(contentWidth, 21)
            collectionNote.Visible = bodyHeight >= 346
            content.CanvasSize = UDim2.fromOffset(0, collectionNote.Visible and 346 or 319)
            footer.Position, footer.Size = UDim2.fromOffset(padding, footerTop), UDim2.fromOffset(contentWidth, footerHeight)
        else
            local split = math.floor(width * (compact and 0.32 or 0.40))
            content.Position = UDim2.fromOffset(split + (compact and 12 or 25), contentTop)
            contentWidth, bodyHeight = width - split - padding - (compact and 12 or 25), footerTop - contentTop - 10
            preview.Parent = panel
            preview.Position, preview.Size = UDim2.fromOffset(padding, contentTop), UDim2.fromOffset(split - padding - 18, height - contentTop - padding)
            subject.Visible, portraitName.Visible, rotateHint.Visible = not compact, not compact, true
            subject.Position, subject.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, 20)
            previewStage.Position = UDim2.fromOffset(0, compact and 0 or 28)
            previewStage.Size = UDim2.new(1, 0, 1, compact and -34 or -116)
            portraitName.Position, portraitName.Size = UDim2.new(0, 0, 1, -76), UDim2.new(1, 0, 0, 37)
            rotateHint.Position, rotateHint.Size = UDim2.new(0, 0, 1, -31), UDim2.new(1, 0, 0, 24)
            rotateHint.TextSize = compact and 10 or 12
            verticalLine.Position, verticalLine.Size = UDim2.fromOffset(split, contentTop), UDim2.fromOffset(1, height - contentTop - padding)
            verticalLine.Visible = not compact
            identityX, identityWidth, identityHeight = 0, contentWidth, compact and 51 or 61
            local belowIdentity = identityHeight * 3 + 9
            originHint.Position, originHint.Size = UDim2.fromOffset(0, belowIdentity), UDim2.fromOffset(contentWidth, 23)
            originHint.TextSize, originHint.TextWrapped = 11, false
            current.Position, current.Size = UDim2.fromOffset(0, belowIdentity + 39), UDim2.fromOffset(contentWidth, 76)
            owned.Position, owned.Size = UDim2.fromOffset(0, belowIdentity + 120), UDim2.fromOffset(contentWidth, 44)
            collectionNote.Position, collectionNote.Size = UDim2.fromOffset(0, belowIdentity + 170), UDim2.fromOffset(contentWidth, 22)
            collectionNote.Visible = not compact
            content.CanvasSize = UDim2.fromOffset(0, belowIdentity + (collectionNote.Visible and 192 or 164))
            footer.Position, footer.Size = UDim2.fromOffset(split + (compact and 12 or 25), footerTop), UDim2.fromOffset(contentWidth, footerHeight)
        end
        content.Size = UDim2.fromOffset(contentWidth, math.max(40, bodyHeight))
        for index, definition in ipairs(IDENTITY_ROWS) do
            local row = identityRows[definition.id]
            row.frame.Position = UDim2.fromOffset(identityX, (index - 1) * identityHeight)
            row.frame.Size = UDim2.fromOffset(identityWidth, identityHeight)
            row.caption.Position, row.caption.Size = UDim2.fromOffset(0, 1), UDim2.fromOffset(identityWidth - 52, compact and 17 or 20)
            row.caption.TextSize = compact and 10 or 12
            row.value.Position, row.value.Size = UDim2.fromOffset(0, compact and 18 or 22), UDim2.fromOffset(identityWidth - 52, compact and 24 or 31)
            row.value.TextSize = compact and 17 or 23
            row.button.Position, row.button.Size = UDim2.new(1, -48, 0, 0), UDim2.fromOffset(48, math.max(44, identityHeight - 4))
            row.icon.Position, row.icon.Size = UDim2.fromOffset(0, 1), UDim2.fromOffset(48, 29)
            row.cost.Position, row.cost.Size = UDim2.fromOffset(0, 29), UDim2.fromOffset(48, 14)
            row.rule.Position = UDim2.new(0, 0, 1, -1)
        end
        slotLabel.Position, slotLabel.Size = UDim2.fromOffset(0, 0), UDim2.new(1, -48, 0, 19)
        currentName.Position, currentName.Size = UDim2.fromOffset(0, 21), UDim2.new(1, -48, 0, 30)
        currentName.TextSize = compact and 20 or 24
        rarity.Position, rarity.Size = UDim2.fromOffset(0, 53), UDim2.new(1, -48, 0, 20)
        odds.Position, odds.Size = UDim2.new(1, -44, 0, 22), UDim2.fromOffset(44, 44)
        tabRail.Position, tabRail.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 48)
        footerLine.Position = UDim2.fromOffset(0, 51)
        roll.Position, roll.Size = UDim2.fromOffset(0, compact and 61 or 65), UDim2.new(1, 0, 0, compact and 48 or 54)
        status.Position, status.Size = UDim2.fromOffset(0, compact and 115 or 126), UDim2.new(1, 0, 0, 38)
        local drawerWidth = math.min(462, width - (compact and 24 or 64))
        local drawerHeight = math.min(440, height - (compact and 30 or 90))
        drawer.AnchorPoint, drawer.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
        drawer.Size = UDim2.fromOffset(drawerWidth, drawerHeight)
        drawerTitle.Position, drawerTitle.Size = UDim2.fromOffset(20, 16), UDim2.new(1, -78, 0, 36)
        drawerTitle.TextSize = compact and 25 or 28
        drawerSubtitle.Position, drawerSubtitle.Size = UDim2.fromOffset(20, 52), UDim2.new(1, -40, 0, 24)
        drawerClose.Position, drawerClose.Size = UDim2.new(1, -56, 0, 12), UDim2.fromOffset(44, 44)
        drawerList.Position, drawerList.Size = UDim2.fromOffset(20, 90), UDim2.new(1, -40, 1, drawerMode == "earn" and -164 or -110)
        daily.Position, daily.Size = UDim2.new(0, 20, 1, -62), UDim2.new(1, -40, 0, 44)
        tabsKey = nil
        drawTabs(true)
        scrollSelectedTab()
    end

    function self:update(force)
        if not self.visible then return end
        local row = category(selected)
        if pending and not identityRows[pending.category] then
            selected = pending.category
            row = category(selected)
        elseif not row or row.identity == true then
            selected = nil
            for _, entry in ipairs(cosmeticCategories()) do selected = entry.id; break end
            row = category(selected)
        end
        title.Text, classification.Text = tr("title"), tr("classification")
        balance.Text = tostring(profile().rolls or 0) .. " Rolls"
        earn.Text, subject.Text, rotateHint.Text = tr("earn"), tr("subject"), tr("rotate")
        earn.Active, earn.Selectable = drawerMode == nil, drawerMode == nil
        close.Active, close.Selectable = drawerMode == nil, drawerMode == nil
        close:SetAttribute("AccessibleLabel", tr("close"))
        local savedIdentity = identity()
        local fullName = (savedIdentity.firstName or "") .. " " .. (savedIdentity.lastName or "")
        portraitName.Text = fullName:gsub("^%s+", ""):gsub("%s+$", "")
        if portraitName.Text == "" then portraitName.Text = ctx.player.DisplayName end
        for _, definition in ipairs(IDENTITY_ROWS) do
            local field = identityRows[definition.id]
            field.caption.Text = tr(definition.copy)
            field.value.Text = definition.id == "nationality" and CharacterIdentity.label(savedIdentity, ctx.language()) or (savedIdentity[definition.id] or "—")
            local allowed = canRoll(definition.id)
            field.button.Active, field.button.Selectable = allowed == true, allowed == true
            field.icon.TextColor3 = allowed and C.brass or C.muted
            field.cost.Text = pending and pending.category == definition.id and (busy and "…" or retrying and "↻" or "1 Roll") or "1 Roll"
            field.button:SetAttribute("AccessibleLabel", tr(definition.copy) .. " · 1 Roll")
        end
        originHint.Text, collectionNote.Text = tr("originHint"), tr("ownedHint")
        slotLabel.Text = categoryName(row)
        local equippedId = row and (profile().equipped or {})[row.slot or row.id]
        local item = equippedId and Catalog.ById[equippedId]
        currentName.Text = item and itemName(item)
            or (selected == "hair" or selected == "outfit") and tr("original") or tr("none")
        local definition = item and Catalog.Rarities[item.rarity]
        rarity.Text = definition and (ctx.language() == "en" and definition.en or definition.ru) or ""
        rarity.TextColor3 = definition and Color3.fromRGB(table.unpack(definition.color)) or C.muted
        owned.Text = tr("owned") .. "   ·   " .. tostring(#ownedItems())
        owned.Active = profile().ready == true and not pending and not requestPending() and not drawerMode
        owned.Selectable = owned.Active
        owned.TextColor3 = owned.Active and C.text or C.muted
        odds.Active, odds.Selectable = row ~= nil and not drawerMode, row ~= nil and not drawerMode
        drawTabs(force)
        for _, tab in pairs(tabButtons) do
            local enabled = not pending and not busy and not drawerMode
            tab.Active, tab.Selectable = enabled, enabled
        end
        -- A save uncertainty may return an unavailable profile with no category DTO.
        -- The retained request still carries its type and must remain retryable.
        local retryCosmetic = pending and retrying and identityRows[pending.category] == nil
        local active = canRoll(selected) or retryCosmetic and not requestPending() and not busy and not drawerMode
        roll.Active, roll.Selectable = active == true, active == true
        roll.BackgroundColor3 = roll.Active and C.brass or C.raised
        roll.BackgroundTransparency = roll.Active and 0 or 0.25
        roll.TextColor3 = roll.Active and C.ink or C.muted
        rollIcon.TextColor3 = roll.TextColor3
        roll.Text = busy and tr("pending") or retryCosmetic and tr("retry") or tr("roll") .. " · 1 Roll"
        if (statusKey == "loading" and profile().ready == true)
            or (statusKey == "empty" and row and row.available ~= false)
            or (statusKey == "noRolls" and (profile().rolls or 0) > 0)
            or (statusKey == "trade" and row and row.reason ~= "trade_processing")
            or (statusKey == "round" and not roundActive()) then setStatus(nil) end
        if roundActive() then setStatus("round")
        elseif statusKey then setStatus(statusKey, statusError)
        elseif profile().ready ~= true then setStatus("loading")
        elseif row and row.reason == "trade_processing" then setStatus("trade")
        elseif not row or row.available == false then setStatus("empty")
        elseif (profile().rolls or 0) <= 0 and not retrying then setStatus("noRolls")
        else setStatus(nil) end
        daily.Text = tr("dailyOpen")
        local dailyAllowed = profile().ready == true and not pending and not requestPending() and not roundActive()
        daily.Active, daily.Selectable = dailyAllowed, dailyAllowed
        daily.TextColor3 = dailyAllowed and C.text or C.muted
        drawerList.Size = UDim2.new(1, -40, 1, drawerMode == "earn" and -164 or -110)
        renderDrawer()
        refreshPreview(false)
        if force then scrollSelectedTab() end
    end

    function self:open(categoryId)
        if ctx.player:GetAttribute("SpyEntryPending") or ctx.player:GetAttribute("SpyEntryActive") then return false end
        local tourScreen = ctx.player.PlayerGui:FindFirstChild("SpyClubCinematicTour")
        local tourOverlay = tourScreen and tourScreen:FindFirstChild("LobbyTourOverlay")
        if tourOverlay and tourOverlay.Visible then return false end
        if categoryId and category(categoryId) and category(categoryId).identity ~= true and not pending then selected = categoryId end
        if self.visible then self:update(true); return true end
        if ctx.closeDialogue then ctx.closeDialogue() end
        ctx.closePanels("accessoryRoll")
        self.visible = true
        previousSelection = GuiService.SelectedObject
        if ctx.setActivePanel then ctx.setActivePanel("accessoryRoll") end
        motionToken += 1
        overlay.Visible, overlay.BackgroundTransparency, panel.GroupTransparency = true, 1, 1
        self:resize(); self:update(true)
        floating:setActive(true)
        TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.28), {BackgroundTransparency = 0.58}):Play()
        if UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then GuiService.SelectedObject = close end
        return true
    end
    function self:close(animated)
        if not self.visible then return end
        self.visible = false
        drawerMode = nil
        drawer.Visible, drawerShade.Visible = false, false
        floating:setActive(false)
        destroyPreview(); stopSpinner()
        motionToken += 1
        local token = motionToken
        if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
            GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
        end
        previousSelection = nil
        if ctx.getActivePanel and ctx.getActivePanel() == "accessoryRoll" and ctx.setActivePanel then ctx.setActivePanel(nil) end
        if animated == false then overlay.Visible = false; return end
        TweenService:Create(panel, TweenInfo.new(0.20), {GroupTransparency = 1}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.20), {BackgroundTransparency = 1}):Play()
        task.delay(0.20, function() if alive and token == motionToken and not self.visible then overlay.Visible = false end end)
    end
    function self:receive(receipt, requestId)
        if type(receipt) ~= "table" then return false end
        if equipRequestId and requestId == equipRequestId then
            equipRequestId = nil
            setStatus(receipt.ok and "saved" or "unavailable", not receipt.ok)
            self:update(true)
            if receipt.ok then reveal(current) end
            return true
        end
        if not pending or requestId ~= pending.id then return false end
        local attempt = pending
        local delay = math.max(0, 0.48 - (os.clock() - attempt.started))
        task.delay(delay, function()
            if not alive or pending ~= attempt then return end
            stopSpinner()
            busy = false
            if receipt.ok and (receipt.code == "accessoryRolled" or receipt.code == "identityRolled") then
                local identityResult = receipt.code == "identityRolled"
                if not identityResult then selected = receipt.category or attempt.category end
                pending, retrying = nil, false
                setStatus(identityResult and "identitySaved" or receipt.duplicate and "duplicate" or "saved")
                self:update(true)
                if self.visible then
                    if identityResult then
                        if attempt.category == "nationality" then
                            for _, field in pairs(identityRows) do reveal(field.frame) end
                        else reveal(identityRows[attempt.category] and identityRows[attempt.category].frame) end
                    else reveal(current) end
                    if ctx.playSound and not receipt.replayed then ctx.playSound("Reward", 1.04) end
                end
            else
                local code = receipt.code
                local uncertain = code == "save_failed" or code == "profile_unavailable"
                    or code == "slowDown" or code == "roll_match_active"
                retrying = uncertain
                if not uncertain then pending = nil end
                local errors = {roll_empty = "noRolls", roll_no_items = "empty", roll_style = "style",
                    roll_stale_request = "stale", roll_request_conflict = "stale", appearanceLoading = "loading",
                    trade_processing = "trade", profile_unavailable = "unavailable", save_failed = "save",
                    slowDown = "slow", roll_match_active = "round"}
                setStatus(errors[code] or "unavailable", true)
                self:update(true)
            end
        end)
        return true
    end
    startRoll = function(categoryId)
        if not canRoll(categoryId) then return end
        if not pending then
            pending = {category = categoryId, id = tostring((dto().sequence or 0) + 1) .. "-" .. HttpService:GenerateGUID(false)}
        end
        pending.started = os.clock()
        local attempt, started = pending, pending.started
        busy, retrying = true, false
        setStatus(nil)
        stopSpinner()
        spinnerNode = identityRows[attempt.category] and identityRows[attempt.category].icon or rollIcon
        spinning = TweenService:Create(spinnerNode, TweenInfo.new(0.65, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Rotation = 360})
        spinning:Play()
        TweenService:Create(pressScale, TweenInfo.new(0.08), {Scale = 0.97}):Play()
        task.delay(0.08, function() if alive then TweenService:Create(pressScale, TweenInfo.new(0.14), {Scale = 1}):Play() end end)
        self:update()
        local sent = ctx.request("accessoryRoll", attempt.category, attempt.id)
        if not sent then
            busy, retrying = false, true
            stopSpinner()
            setStatus("slow", true); self:update()
            return
        end
        task.delay(18.2, function()
            if not alive or pending ~= attempt or attempt.started ~= started or not busy then return end
            busy, retrying = false, true
            stopSpinner()
            setStatus("timeout", true); self:update()
        end)
    end
    roll.Activated:Connect(function() startRoll(pending and pending.category or selected) end)
    earn.Activated:Connect(function() openDrawer("earn") end)
    owned.Activated:Connect(function() if owned.Active then openDrawer("owned") end end)
    odds.Activated:Connect(function() if odds.Active then openDrawer("odds") end end)
    daily.Activated:Connect(function() if daily.Active then self:close(false); ctx.openPanel("daily") end end)
    drawerClose.Activated:Connect(closeDrawer)
    drawerShade.Activated:Connect(closeDrawer)
    close.Activated:Connect(function() self:close() end)
    dismiss.Activated:Connect(function() self:close() end)
    connections[#connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
        if not self.visible or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.ButtonB or not processed and input.KeyCode == Enum.KeyCode.Escape then
            if drawerMode then closeDrawer() else self:close() end
        elseif not processed and not drawerMode and input.KeyCode == Enum.KeyCode.R then
            startRoll(pending and pending.category or selected)
        elseif not processed and not drawerMode and not pending and (input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Right) then
            local rows = cosmeticCategories()
            local index = 1
            for i, row in ipairs(rows) do if row.id == selected then index = i; break end end
            if #rows > 0 then
                selected = rows[(index - 1 + (input.KeyCode == Enum.KeyCode.Right and 1 or -1)) % #rows + 1].id
                setStatus(nil); self:update(true)
            end
        end
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
        floating:destroy(); stopSpinner()
        for _, connection in ipairs(connections) do connection:Disconnect() end
    end)
    return self
end

return AccessoryRollUI
