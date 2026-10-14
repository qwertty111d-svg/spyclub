-- Two character tabs, one server-owned Rolls wallet, and one retained request per roll.
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Catalog = require(script.Parent.Catalog)
local CharacterIdentity = require(script.Parent.CharacterIdentity)
local RollConfig = require(script.Parent.AccessoryRollConfig)
local RollOdds = require(script.Parent.RollOdds)
local Preview3D = require(script.Parent.Preview3D)
local FloatingUIController = require(script.Parent.FloatingUIController)

local AccessoryRollUI = {}
local C = {
    ink = Color3.fromRGB(16, 17, 19), surface = Color3.fromRGB(28, 29, 32),
    raised = Color3.fromRGB(46, 47, 51), line = Color3.fromRGB(132, 134, 140),
    text = Color3.fromRGB(246, 246, 247), muted = Color3.fromRGB(172, 174, 181),
    primary = Color3.fromRGB(238, 238, 240), error = Color3.fromRGB(231, 157, 151),
}
local COPY = {
    title = {"ПЕРСОНАЖ", "CHARACTER", "角色"},
    personal = {"Личные данные", "Personal data", "个人资料"},
    appearance = {"Внешность", "Appearance", "外观"},
    surname = {"Фамилия", "Surname", "姓氏"}, firstName = {"Имя", "First name", "名字"},
    origin = {"Происхождение", "Origin", "来源"},
    originHint = {"Новое происхождение меняет имя и фамилию", "New origin also changes first name and surname", "新来源也会更改名字和姓氏"},
    rotate = {"Потяни, чтобы повернуть", "Drag to rotate", "拖动旋转"},
    wardrobe = {"ГАРДЕРОБ", "WARDROBE", "衣橱"},
    roll = {"Ролл", "Roll", "抽取"}, retry = {"Повторить запрос", "Retry request", "重试请求"},
    pending = {"Подтверждаем…", "Confirming…", "确认中…"},
    loading = {"Загружаем персонажа…", "Loading your character…", "加载档案…"},
    empty = {"Нет вариантов для прокрутки", "No options to roll", "没有可抽取的选项"},
    none = {"Без предмета", "No item equipped", "未装备物品"},
    original = {"Исходный образ", "Original appearance", "原始外观"},
    owned = {"Моя коллекция", "My collection", "我的收藏"},
    ownedHint = {"Выбери уже полученный предмет", "Choose an item you already own", "选择已获得的物品"},
    noOwned = {"Новые предметы появятся здесь после прокрутки", "Rolled items will appear here", "抽取的物品将显示在这里"},
    equip = {"Надеть", "Equip", "装备"}, saved = {"Надето · сохранено", "Equipped · saved", "已装备 · 已保存"},
    identitySaved = {"Личные данные обновлены · сохранено", "Personal data updated · saved", "档案已更新 · 已保存"},
    duplicate = {"Ещё одна копия · сохранено", "Another copy · saved", "副本 · 已保存"},
    equipped = {"Надето", "Equipped", "已装备"},
    noRolls = {"Нет Rolls · купи или получи за игру", "No Rolls · buy or earn by playing", "抽取次数不足，可购买或通过游戏赚取"},
    paidRestricted = {"Купленные Rolls недоступны аккаунту. Rolls за игру доступны.", "Purchased Rolls are unavailable for this account. Earned Rolls remain usable.", "此账号无法使用购买的抽取次数，游戏奖励次数仍可使用。"},
    policyPending = {"Проверяем доступ к купленным Rolls…", "Checking access to purchased Rolls…", "正在检查购买的抽取次数使用权限…"},
    earn = {"Получить за игру", "Earn by playing", "通过游戏赚取"},
    buy = {"Магазин", "Store", "商店"},
    earnTitle = {"Бесплатные Rolls", "Free Rolls", "免费抽取次数"},
    starter = {"При первом входе", "On your first visit", "首次加入"},
    complete = {"За завершённый матч", "For completing a match", "完成一场比赛"},
    win = {"Дополнительно за победу", "Extra for a win", "赢得比赛的额外奖励"},
    daily = {"Недельные награды", "Weekly rewards", "每周奖励"},
    dailyOpen = {"Открыть ежедневную награду", "Open daily reward", "打开每日奖励"},
    costHint = {"Любая прокрутка — 1 Roll", "Every roll costs 1 Roll", "每次抽取消耗 1 次数"},
    odds = {"Вероятности", "Drop chances", "掉落概率"},
    allOdds = {"Все шансы", "All chances", "所有概率"},
    poolOdds = {"ШАНСЫ ТЕКУЩЕГО ПУЛА", "CURRENT POOL CHANCES", "当前奖池概率"},
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
    {id = "nationality", copy = "origin"},
    {id = "firstName", copy = "firstName"},
    {id = "lastName", copy = "surname"},
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
    make("UICorner", node, {CornerRadius = UDim.new(0, 4)})
    local border = make("UIStroke", node, {Color = C.primary, Transparency = 1, Thickness = 1,
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
    local alive, compact, portrait, shortLayout = true, false, false, false
    local connections = {}
    local selected, pending, busy, retrying = "nationality", nil, false, false
    local mainTab, personalSelected, appearanceSelected = "personal", "nationality", nil
    local previewViewport, previewKey, tabsKey, ownedKey, spinning, spinnerNode
    local statusKey, statusError, equipRequestId, previousSelection
    local motionToken = 0
    local drawerMode = nil
    local oddsCategory = nil
    local openDrawer
    local tabButtons, identityRows = {}, {}
    local startRoll, renderDrawer, selectMainTab, setStatus
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
        if not row then return tr("appearance") end
        return ctx.language() == "en" and (row.labelEn or row.label or row.id)
            or ctx.language() == "zh" and (row.labelZh or row.labelEn or row.label or row.id)
            or (row.labelRu or row.label or row.id)
    end
    local function targetName(id, row)
        for _, definition in ipairs(IDENTITY_ROWS) do
            if definition.id == id then return tr(definition.copy) end
        end
        return row and categoryName(row) or pending and pending.category == id and pending.label or id or tr("appearance")
    end
    local function effectiveCategory() return pending and pending.category or selected end
    local function selectedOdds(row)
        if not row or row.identity then return RollOdds.summary(row, Catalog, ctx.language(), compact) end
        local lines, pairsOfChances = {}, {}
        for _, id in ipairs(RARITY_ORDER) do
            local percent = RollOdds.percent((row.chances or {})[id])
            local rarity = Catalog.Rarities[id]
            if percent and rarity then
                pairsOfChances[#pairsOfChances + 1] = (ctx.language() == "en" and rarity.en or rarity.ru) .. " " .. percent
                if #pairsOfChances == 2 then lines[#lines + 1] = table.concat(pairsOfChances, " · "); pairsOfChances = {} end
            end
        end
        if #pairsOfChances > 0 then lines[#lines + 1] = table.concat(pairsOfChances, " · ") end
        return #lines > 0 and table.concat(lines, "\n") or "—"
    end
    local function itemName(item)
        return ctx.language() == "en" and (item.en or item.ru or item.id) or (item.ru or item.en or item.id)
    end
    local function roundActive()
        local state = ctx.state() or {}
        return state.tableId and state.phase ~= "Waiting" and state.phase ~= "Result" and state.phase ~= "Finished"
    end
    local function requestPending() return ctx.pending and ctx.pending() or false end
    local function paidRestrictionStatus()
        return (profile().rollShop or {}).policyReady == false and "policyPending" or "paidRestricted"
    end
    local function spendStatus(row)
        local reason = row and row.spendReason or dto().spendReason
        if reason == "roll_paid_restricted" then return paidRestrictionStatus() end
        if reason == "roll_policy_pending" or reason == "policy_pending" then return "policyPending" end
        return ({roll_empty = "noRolls", trade_processing = "trade", roll_no_items = "empty"})[reason]
    end
    local function canRoll(id)
        if busy or requestPending() or drawerMode then return false end
        -- Retrying a retained ID only recovers its authoritative receipt. The
        -- server distinguishes recovery from a fresh spend during an active match.
        if pending then return retrying and pending.category == id end
        if roundActive() then return false end
        local row = category(id)
        return profile().ready == true and row ~= nil and row.available ~= false
            and dto().canSpend ~= false and row.canSpend ~= false and (profile().rolls or 0) > 0
    end

    -- The parent ScreenGui supplies device-safe insets. The sheet retains a 12px edge on phones.
    local overlay = make("Frame", ctx.gui, {Name = "AccessoryRollOverlay", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.ink, BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, Active = true, ZIndex = 80})
    local dismiss = make("TextButton", overlay, {Name = "Dismiss", Size = UDim2.fromScale(1, 1),
        Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Selectable = false, ZIndex = 81})
    local panel = make("CanvasGroup", overlay, {Name = "PersonalDossier", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 640),
        BackgroundColor3 = C.surface, BackgroundTransparency = 1, GroupTransparency = 0,
        BorderSizePixel = 0, Active = true, ZIndex = 82, ClipsDescendants = true, SelectionGroup = true,
        SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
        SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop})
    make("UICorner", panel, {CornerRadius = UDim.new(0, 6)})
    local floating = FloatingUIController.create(panel, {container = overlay, maxOffset = 4,
        smoothTime = 0.15, safePadding = 12})
    local header = make("Frame", panel, {Name = "DossierHeader", BackgroundTransparency = 1})
    local title = label(header, "DossierTitle", tr("title"), 28)
    title.Font = Enum.Font.BuilderSansExtraBold
    local balance = label(header, "RollBalance", "0 Rolls", 22, C.primary)
    balance.Font = Enum.Font.BuilderSansBold
    balance.TextXAlignment = Enum.TextXAlignment.Right
    local earn = button(header, "EarnRolls", tr("earn"))
    earn.TextColor3 = C.muted
    earn.BackgroundTransparency = 1
    local buy = button(header, "BuyRolls", tr("buy"))
    buy.BackgroundColor3 = C.raised
    buy.BackgroundTransparency = 0.08
    buy.TextColor3 = C.primary
    local close = button(header, "CloseDossier", "×")
    close.TextSize = 28
    close.BackgroundTransparency = 1
    close.SelectionOrder = 1
    close:SetAttribute("AccessibleLabel", tr("close"))
    local headerLine = divider(panel, "HeaderRule")

    local controlSurface = make("Frame", panel, {Name = "CharacterControlSurface", BackgroundColor3 = C.surface,
        BackgroundTransparency = 0.05, BorderSizePixel = 0})
    local preview = make("Frame", panel, {Name = "PersonalPortrait", BackgroundTransparency = 1})
    local previewStage = make("Frame", preview, {Name = "PortraitStage", BackgroundTransparency = 1,
        ClipsDescendants = true})
    local portraitName = label(preview, "PortraitName", ctx.player.DisplayName, 22)
    portraitName.Font = Enum.Font.BuilderSansBold
    portraitName.TextXAlignment = Enum.TextXAlignment.Center
    local rotateHint = label(preview, "RotateHint", tr("rotate"), 12, C.muted)
    rotateHint.TextXAlignment = Enum.TextXAlignment.Center
    local verticalLine = divider(panel, "DossierSpine")

    local primaryRail = make("Frame", panel, {Name = "CharacterTabs", BackgroundTransparency = 1})
    local personalTab = button(primaryRail, "TabPersonal", tr("personal"))
    local appearanceTab = button(primaryRail, "TabAppearance", tr("appearance"))
    for _, tab in ipairs({personalTab, appearanceTab}) do
        tab.BackgroundTransparency = 1
        tab.Font = Enum.Font.BuilderSansBold
        make("Frame", tab, {Name = "SelectedRule", Position = UDim2.new(0, 0, 1, -3),
            Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.text, BorderSizePixel = 0})
    end
    local content = make("ScrollingFrame", panel, {Name = "DossierFields", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.primary, ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true, AutomaticCanvasSize = Enum.AutomaticSize.None})
    for index, definition in ipairs(IDENTITY_ROWS) do
        local row = make("CanvasGroup", content, {Name = "Identity_" .. definition.id,
            BackgroundColor3 = C.raised, BackgroundTransparency = 0.55, BorderSizePixel = 0, GroupTransparency = 0})
        local choose = button(row, "SelectIdentity_" .. definition.id, "")
        choose.BackgroundTransparency = 1
        choose.SelectionOrder = index + 4
        choose:SetAttribute("RollCategory", definition.id)
        local caption = label(choose, "FieldLabel", tr(definition.copy), 14, C.muted)
        local value = label(choose, "FieldValue", "—", 28)
        value.Font = Enum.Font.BuilderSansBold
        local chevron = label(choose, "SelectChevron", "›", 26, C.muted)
        chevron.TextXAlignment = Enum.TextXAlignment.Right
        local marker = make("Frame", row, {Name = "SelectedField", Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = C.text, BorderSizePixel = 0})
        identityRows[definition.id] = {frame = row, caption = caption, value = value, button = choose,
            marker = marker, chevron = chevron, definition = definition}
        choose.Activated:Connect(function()
            if not choose.Active or pending or busy or drawerMode then return end
            personalSelected, selected = definition.id, definition.id
            setStatus(nil)
            self:update(true)
        end)
    end
    local originHint = label(content, "OriginRule", tr("originHint"), 12, C.muted)
    originHint.TextWrapped, originHint.TextTruncate = true, Enum.TextTruncate.None
    local current = make("CanvasGroup", content, {Name = "CurrentWardrobeItem", BackgroundTransparency = 1,
        GroupTransparency = 0})
    local slotLabel = label(current, "SelectedCategory", "", 13, C.muted)
    local currentName = label(current, "EquippedItemName", "", 28)
    currentName.Font = Enum.Font.BuilderSansBold
    local rarity = label(current, "ItemRarity", "", 12, C.muted)
    local tabRail = make("ScrollingFrame", content, {Name = "WardrobeTabs", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.primary, ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.None, ClipsDescendants = true})
    local owned = button(content, "ChooseOwned", "")
    owned.TextXAlignment = Enum.TextXAlignment.Left
    make("UIPadding", owned, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 24)})
    local ownedChevron = label(owned, "OpenCollection", "›", 25, C.primary)
    ownedChevron.AnchorPoint, ownedChevron.Position = Vector2.new(1, 0.5), UDim2.new(1, -8, 0.5, 0)
    ownedChevron.Size = UDim2.fromOffset(16, 34)

    local footer = make("Frame", panel, {Name = "WardrobeFooter", BackgroundTransparency = 1})
    local selectedTarget = label(footer, "SelectedTarget", "", 20)
    selectedTarget.Font = Enum.Font.BuilderSansBold
    local chanceSummary = label(footer, "ChanceSummary", "—", 12, C.muted)
    chanceSummary.TextWrapped, chanceSummary.TextTruncate = true, Enum.TextTruncate.None
    chanceSummary.TextYAlignment = Enum.TextYAlignment.Top
    local chanceDetails = button(footer, "ChanceDetails", tr("allOdds") .. " ›")
    chanceDetails.BackgroundTransparency = 1
    chanceDetails.TextXAlignment = Enum.TextXAlignment.Right
    chanceDetails:SetAttribute("AccessibleLabel", tr("allOdds"))
    chanceDetails.Activated:Connect(function() if chanceDetails.Active then openDrawer("odds", effectiveCategory()) end end)
    local footerLine = divider(footer, "FooterRule")
    local roll = button(footer, "RollSelectedSlot", "")
    roll.BackgroundColor3, roll.BackgroundTransparency = C.primary, 0
    roll.Font, roll.TextColor3, roll.TextSize = Enum.Font.BuilderSansBold, C.ink, 20
    roll.TextWrapped, roll.TextTruncate = true, Enum.TextTruncate.None
    roll.TextXAlignment = Enum.TextXAlignment.Center
    local pressScale = make("UIScale", roll, {Scale = 1})
    local rollIcon = label(roll, "RequestSpinner", "◌", 20, C.ink)
    rollIcon.Position, rollIcon.Size = UDim2.fromOffset(4, 4), UDim2.fromOffset(22, 24)
    rollIcon.Visible = false
    local status = label(footer, "RequestStatus", "", 12, C.muted)
    status.TextWrapped, status.TextTruncate = true, Enum.TextTruncate.None
    status.TextYAlignment = Enum.TextYAlignment.Top

    local drawerShade = make("TextButton", panel, {Name = "DrawerBackdrop", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.ink, BackgroundTransparency = 0.34, Text = "", AutoButtonColor = false,
        Visible = false, Selectable = false, ZIndex = 110})
    local drawer = make("Frame", panel, {Name = "DossierDrawer", BackgroundColor3 = C.surface,
        BackgroundTransparency = 0.02, BorderSizePixel = 0, Visible = false, ZIndex = 111,
        ClipsDescendants = true, SelectionGroup = true,
        SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
        SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop})
    make("UICorner", drawer, {CornerRadius = UDim.new(0, 6)})
    make("UIStroke", drawer, {Color = C.line, Transparency = 0.36})
    local drawerTitle = label(drawer, "DrawerTitle", "", 24)
    drawerTitle.Font = Enum.Font.BuilderSansBold
    local drawerSubtitle = label(drawer, "DrawerSubtitle", "", 12, C.muted)
    local drawerClose = button(drawer, "CloseDrawer", "×")
    drawerClose.BackgroundTransparency = 1
    drawerClose.TextSize = 26
    local drawerList = make("ScrollingFrame", drawer, {Name = "DrawerRows", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.primary, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y})
    make("UIListLayout", drawerList, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    local daily = button(drawer, "OpenDailyReward", tr("dailyOpen"))
    daily.BackgroundColor3 = C.raised
    daily.BackgroundTransparency = 0.12

    setStatus = function(key, isError)
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
    function openDrawer(mode,categoryId)
        drawerMode = mode
        oddsCategory=categoryId
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
        local row = category(appearanceSelected)
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
        if ownedKey == key and drawerMode~="odds" then return end
        ownedKey = key
        for _, child in ipairs(drawerList:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        daily.Visible = drawerMode == "earn"
        if drawerMode == "earn" then
            drawerTitle.Text, drawerSubtitle.Text = tr("earnTitle"), roundActive() and tr("round") or tr("costHint")
            local rewards = RollConfig.Rewards
            local rows = {{"starter", rewards.starter}, {"complete", rewards.completeMatch},
                {"win", rewards.win}, {"daily", rewards.dailyWeek or 3}}
            for index, reward in ipairs(rows) do
                local row = make("Frame", drawerList, {Name = "Earn_" .. reward[1],
                    Size = UDim2.new(1, -6, 0, 48), BackgroundTransparency = 1, LayoutOrder = index})
                local caption = label(row, "RewardSource", tr(reward[1]), 14)
                caption.Size = UDim2.new(1, -84, 1, 0)
                local amount = label(row, "RollsReward", "+" .. tostring(reward[2]) .. " Rolls", 14, C.primary)
                amount.TextXAlignment = Enum.TextXAlignment.Right
                amount.Position, amount.Size = UDim2.new(1, -84, 0, 0), UDim2.fromOffset(80, 48)
                local rule = divider(row, "RewardRule")
                rule.Position = UDim2.new(0, 0, 1, -1)
            end
        elseif drawerMode == "odds" then
            local row = category(oddsCategory or effectiveCategory())
            drawerTitle.Text, drawerSubtitle.Text = tr("odds"), categoryName(row)
            local found = row and row.identity and #(row.items or{})>0 or false
            for index, rarityId in ipairs(RARITY_ORDER) do
                local chance = (row and not row.identity and row.chances or {})[rarityId]
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
            for index,entry in ipairs(RollOdds.details(row,Catalog,ctx.language()))do
                local line=make("Frame",drawerList,{Name="ItemOdds_"..entry.id,Size=UDim2.new(1,-6,0,36),BackgroundTransparency=1,LayoutOrder=20+index})
                local caption=label(line,"OddsItemName",entry.label,14)
                caption.Size=UDim2.new(1,-82,1,0)
                local value=label(line,"OddsItemPercent",entry.percent,14,C.primary)
                value.TextXAlignment=Enum.TextXAlignment.Right
                value.Position,value.Size=UDim2.new(1,-76,0,0),UDim2.fromOffset(70,36)
            end
        else
            local row = category(appearanceSelected)
            drawerTitle.Text, drawerSubtitle.Text = tr("owned"), categoryName(row)
            local items = ownedItems()
            local currentId = row and (profile().equipped or {})[row.slot or row.id]
            local editable = profile().ready == true and not requestPending() and not pending and not roundActive()
            local function addChoice(id, caption, item, index)
                local isEquipped = id == currentId or id == "" and (not currentId or currentId == "")
                local choice = button(drawerList, "Owned_" .. (id ~= "" and id or "none"), "")
                choice.Size, choice.LayoutOrder = UDim2.new(1, -6, 0, 56), index
                choice.Active, choice.Selectable = editable and not isEquipped, editable and not isEquipped
                choice.BackgroundColor3 = C.raised
                choice.BackgroundTransparency = isEquipped and 0.25 or 0.65
                local name = label(choice, "ItemName", caption, 15, editable and C.text or C.muted)
                name.Position, name.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -52, 0, 24)
                local note = label(choice, "ItemState", isEquipped and tr("equipped") or tr("equip"), 11, C.muted)
                note.Position, note.Size = UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 18)
                if isEquipped then
                    local check = label(choice, "EquippedCheck", "✓", 18, C.primary)
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
            addChoice("", (appearanceSelected == "hair" or appearanceSelected == "outfit") and tr("original") or tr("none"), nil, 1)
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
        local keys = {ctx.language(), selected or "", tostring(tabRail.AbsoluteSize.X), tostring(portrait), tostring(shortLayout)}
        for _, row in ipairs(rows) do keys[#keys + 1] = row.id .. ":" .. categoryName(row) end
        local key = table.concat(keys, "|")
        if not force and tabsKey == key then return end
        tabsKey, tabButtons = key, {}
        for _, child in ipairs(tabRail:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        local columns = (portrait or shortLayout) and 1 or 4
        local tabWidth = math.max(44, (tabRail.AbsoluteSize.X - (columns - 1) * 4) / columns)
        for index, row in ipairs(rows) do
            local tab = button(tabRail, "Slot_" .. row.id, categoryName(row))
            local column, line = (index - 1) % columns, math.floor((index - 1) / columns)
            tab.Position = UDim2.fromOffset(column * (tabWidth + 4), line * 48)
            tab.Size, tab.LayoutOrder, tab.SelectionOrder = UDim2.fromOffset(tabWidth, 44), index, index + 8
            tab.BackgroundTransparency = appearanceSelected == row.id and 0.15 or 0.75
            tab.TextColor3 = appearanceSelected == row.id and C.text or C.muted
            tab.TextSize = compact and 12 or 14
            tab:SetAttribute("RollCategory", row.id)
            tabButtons[row.id] = tab
            tab.Activated:Connect(function()
                if not tab.Active or pending or busy or drawerMode then return end
                appearanceSelected, selected = row.id, row.id
                setStatus(nil); self:update(true)
            end)
        end
        tabRail.CanvasSize = UDim2.fromOffset(0, math.ceil(#rows / columns) * 48 - 4)
    end
    local function scrollSelectedTab()
        local tab = tabButtons[appearanceSelected]
        if not tab then return end
        local y = tab.Position.Y.Offset
        local canvas, view = tabRail.CanvasPosition.Y, tabRail.AbsoluteSize.Y
        if y < canvas then canvas = y
        elseif y + 44 > canvas + view then canvas = y + 44 - view end
        tabRail.CanvasPosition = Vector2.new(0, math.max(0, canvas))
    end
    selectMainTab = function(id)
        if drawerMode then return end
        mainTab = id
        selected = mainTab == "personal" and personalSelected or appearanceSelected
        content.CanvasPosition = Vector2.zero
        self:resize(); self:update(true)
    end
    personalTab.Activated:Connect(function() if personalTab.Active then selectMainTab("personal") end end)
    appearanceTab.Activated:Connect(function() if appearanceTab.Active then selectMainTab("appearance") end end)

    function self:resize()
        local viewport = overlay.AbsoluteSize
        if viewport.X <= 0 or viewport.Y <= 0 then return end
        compact = viewport.X < 760 or viewport.Y < 540
        portrait = viewport.Y > viewport.X * 1.03 and compact
        shortLayout = viewport.Y < 430 and not portrait
        local width = math.max(1, math.min(1160, viewport.X - (compact and 24 or 80)))
        local height = math.max(1, math.min(780, viewport.Y - (compact and 24 or 80)))
        panel.Size = UDim2.fromOffset(width, height)
        floating:setBasePosition(UDim2.fromScale(0.5, 0.5))
        local padding = compact and 12 or 30
        local innerWidth = width - padding * 2
        local headerHeight = portrait and 98 or shortLayout and 56 or 86
        header.Position, header.Size = UDim2.fromOffset(padding, 6), UDim2.fromOffset(innerWidth, headerHeight - 6)
        close.Position, close.Size = UDim2.new(1, -44, 0, 0), UDim2.fromOffset(44, 44)
        if portrait then
            title.Position, title.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(innerWidth - 44, 40)
            title.TextSize = width < 300 and 27 or 32
            balance.Position, balance.Size = UDim2.fromOffset(0, 46), UDim2.fromOffset(72, 44)
            balance.TextXAlignment, balance.TextSize = Enum.TextXAlignment.Left, 16
            local buyWidth = width < 300 and 64 or 80
            buy.Position, buy.Size = UDim2.fromOffset(innerWidth - buyWidth, 46), UDim2.fromOffset(buyWidth, 44)
            earn.Position, earn.Size = UDim2.fromOffset(76, 46), UDim2.fromOffset(math.max(44, innerWidth - buyWidth - 80), 44)
            earn.TextSize, buy.TextSize = 11, 12
        else
            local balanceWidth, earnWidth, buyWidth = shortLayout and 80 or 100, shortLayout and 100 or 132, shortLayout and 80 or 116
            local buyX = innerWidth - 44 - 8 - buyWidth
            local earnX, balanceX = buyX - 8 - earnWidth, buyX - 16 - earnWidth - balanceWidth
            local titleWidth = balanceX - 12
            title.Position, title.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(titleWidth, headerHeight - 8)
            title.TextSize = math.max(24, math.min(shortLayout and 36 or 64, math.floor(titleWidth / 6)))
            balance.Position, balance.Size = UDim2.fromOffset(balanceX, 0), UDim2.fromOffset(balanceWidth, 44)
            balance.TextXAlignment, balance.TextSize = Enum.TextXAlignment.Right, shortLayout and 16 or 20
            earn.Position, earn.Size = UDim2.fromOffset(earnX, 0), UDim2.fromOffset(earnWidth, 44)
            buy.Position, buy.Size = UDim2.fromOffset(buyX, 0), UDim2.fromOffset(buyWidth, 44)
            earn.TextSize, buy.TextSize = shortLayout and 11 or 13, shortLayout and 12 or 15
        end
        headerLine.Position, headerLine.Size = UDim2.fromOffset(padding, headerHeight), UDim2.fromOffset(innerWidth, 1)
        primaryRail.Position, primaryRail.Size = UDim2.fromOffset(padding, headerHeight + 4), UDim2.fromOffset(innerWidth, 44)
        local primaryWidth = portrait and (innerWidth - 8) / 2 or math.min(240, (innerWidth - 8) / 2)
        personalTab.Position, personalTab.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(primaryWidth, 44)
        appearanceTab.Position, appearanceTab.Size = UDim2.fromOffset(primaryWidth + 8, 0), UDim2.fromOffset(primaryWidth, 44)
        personalTab.TextSize, appearanceTab.TextSize = portrait and 14 or 20, portrait and 14 or 20
        local bodyTop = headerHeight + 58
        local gap = compact and 12 or 24
        local bodyHeight = height - bodyTop - padding
        local stageWidth, contentWidth, contentHeight, footerWidth, contentX, footerX, footerTop, footerHeight
        if shortLayout then
            stageWidth = math.floor(innerWidth * 0.30)
            contentWidth = math.floor((innerWidth - stageWidth - gap * 2) * 0.52)
            footerWidth = innerWidth - stageWidth - contentWidth - gap * 2
            contentX, footerX, footerTop = padding + stageWidth + gap, padding + stageWidth + contentWidth + gap * 2, bodyTop
            contentHeight, footerHeight = bodyHeight, bodyHeight
        else
            stageWidth = portrait and math.floor(innerWidth * 0.32) or math.floor(innerWidth * 0.43)
            contentWidth, footerWidth = innerWidth - stageWidth - gap, innerWidth - stageWidth - gap
            contentX, footerX = padding + stageWidth + gap, padding + stageWidth + gap
            footerHeight = 206
            footerTop = height - padding - footerHeight
            contentHeight = footerTop - bodyTop - 12
            if portrait then
                -- The action spans the phone. The avatar and selected field retain
                -- their own visible stage above it instead of sharing a scroll area.
                footerX, footerWidth = padding, innerWidth
            end
        end
        preview.Parent = panel
        preview.Position, preview.Size = UDim2.fromOffset(padding, bodyTop), UDim2.fromOffset(stageWidth, portrait and contentHeight or bodyHeight)
        previewStage.Position, previewStage.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, (portrait or shortLayout) and 0 or -66)
        if portrait or shortLayout then previewStage.Size = UDim2.fromScale(1, 1) end
        portraitName.Visible, rotateHint.Visible = not portrait and not shortLayout, not portrait and not shortLayout
        portraitName.Position, portraitName.Size = UDim2.new(0, 0, 1, -60), UDim2.new(1, 0, 0, 32)
        portraitName.TextSize = 26
        rotateHint.Position, rotateHint.Size = UDim2.new(0, 0, 1, -24), UDim2.new(1, 0, 0, 20)
        verticalLine.Visible = false
        content.Position, content.Size = UDim2.fromOffset(contentX, bodyTop), UDim2.fromOffset(contentWidth, math.max(44, contentHeight))
        local identityHeight = shortLayout and 54 or portrait and math.min(64, math.floor((contentHeight - 42) / 3) - 6) or math.min(112, math.floor((contentHeight - 56) / 3))
        identityHeight = math.max(44, identityHeight)
        for index, definition in ipairs(IDENTITY_ROWS) do
            local field = identityRows[definition.id]
            field.frame.Position, field.frame.Size = UDim2.fromOffset(0, (index - 1) * (identityHeight + 6)), UDim2.fromOffset(contentWidth, identityHeight)
            field.button.Position, field.button.Size = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1)
            field.caption.Position, field.caption.Size = UDim2.fromOffset(12, 5), UDim2.new(1, -32, 0, 18)
            field.caption.TextSize = compact and 11 or 15
            field.value.Position, field.value.Size = UDim2.fromOffset(12, 23), UDim2.new(1, -32, 0, identityHeight - 26)
            field.value.TextSize = shortLayout and 16 or portrait and (definition.id == "nationality" and 15 or 18) or 30
            field.chevron.Position, field.chevron.Size = UDim2.new(1, -24, 0, 0), UDim2.new(0, 18, 1, 0)
        end
        originHint.Position, originHint.Size = UDim2.fromOffset(0, (identityHeight + 6) * 3 + 2), UDim2.fromOffset(contentWidth, shortLayout and 28 or portrait and 38 or 46)
        originHint.TextSize = compact and 10 or 12
        local currentHeight = shortLayout and 68 or portrait and 90 or 110
        current.Position, current.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(contentWidth, currentHeight)
        slotLabel.Position, slotLabel.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18)
        currentName.Position, currentName.Size = UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, portrait and 44 or compact and 26 or 40)
        currentName.TextWrapped, currentName.TextTruncate = portrait, portrait and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
        currentName.TextSize = compact and 18 or 30
        rarity.Position, rarity.Size = UDim2.fromOffset(0, portrait and 70 or compact and 50 or 66), UDim2.new(1, 0, 0, 18)
        local railTop, ownedHeight = currentHeight + 6, 44
        local railHeight = math.max(44, math.min(portrait and 92 or shortLayout and 88 or 144, contentHeight - railTop - ownedHeight - 8))
        tabRail.Position, tabRail.Size = UDim2.fromOffset(0, railTop), UDim2.fromOffset(contentWidth, railHeight)
        owned.Position, owned.Size = UDim2.fromOffset(0, railTop + railHeight + 8), UDim2.fromOffset(contentWidth, ownedHeight)
        owned.TextSize = compact and 11 or 15
        content.CanvasSize = UDim2.fromOffset(0, mainTab == "personal" and (identityHeight + 6) * 3 + (shortLayout and 30 or 48)
            or railTop + railHeight + 8 + ownedHeight)
        controlSurface.Position = UDim2.fromOffset(contentX - (compact and 4 or 16), bodyTop - (compact and 4 or 16))
        controlSurface.Size = UDim2.fromOffset(contentWidth + (shortLayout and gap + footerWidth or 0) + (compact and 8 or 32), (portrait and contentHeight or bodyHeight) + (compact and 8 or 32))
        footer.BackgroundColor3, footer.BackgroundTransparency = C.surface, portrait and 0.05 or 1
        footer.Position, footer.Size = UDim2.fromOffset(footerX, footerTop), UDim2.fromOffset(footerWidth, footerHeight)
        selectedTarget.Position, selectedTarget.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(footerWidth - math.min(116, math.floor(footerWidth * 0.40)) - 8, 38)
        selectedTarget.TextSize = compact and 16 or 20
        local detailsWidth = math.min(116, math.floor(footerWidth * 0.40))
        chanceSummary.Position, chanceSummary.Size = UDim2.fromOffset(0, 44), UDim2.fromOffset(footerWidth, 48)
        chanceSummary.TextSize = compact and 11 or 13
        chanceDetails.Position, chanceDetails.Size = UDim2.fromOffset(footerWidth - detailsWidth, 0), UDim2.fromOffset(detailsWidth, 44)
        chanceDetails.TextSize = compact and 11 or 13
        footerLine.Position = UDim2.fromOffset(0, 94)
        roll.Position, roll.Size = UDim2.fromOffset(0, 100), UDim2.fromOffset(footerWidth, 64)
        roll.TextSize = shortLayout and 16 or portrait and 18 or 22
        status.Position, status.Size = UDim2.fromOffset(0, 170), UDim2.fromOffset(footerWidth, math.max(26, footerHeight - 170))
        status.TextSize = compact and 10 or 11
        local drawerWidth, drawerHeight = math.min(462, width - 24), math.min(440, height - 24)
        drawer.AnchorPoint, drawer.Position, drawer.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(drawerWidth, drawerHeight)
        drawerTitle.Position, drawerTitle.Size = UDim2.fromOffset(20, 16), UDim2.new(1, -78, 0, 34)
        drawerTitle.TextSize = compact and 22 or 24
        drawerSubtitle.Position, drawerSubtitle.Size = UDim2.fromOffset(20, 52), UDim2.new(1, -40, 0, 24)
        drawerClose.Position, drawerClose.Size = UDim2.new(1, -56, 0, 12), UDim2.fromOffset(44, 44)
        drawerList.Position, drawerList.Size = UDim2.fromOffset(20, 90), UDim2.new(1, -40, 1, drawerMode == "earn" and -164 or -110)
        daily.Position, daily.Size = UDim2.new(0, 20, 1, -62), UDim2.new(1, -40, 0, 44)
        tabsKey = nil; drawTabs(true); scrollSelectedTab()
    end

    function self:update(force)
        if not self.visible then return end
        if not appearanceSelected or not category(appearanceSelected) and not pending then
            for _, entry in ipairs(cosmeticCategories()) do appearanceSelected = entry.id; break end
        end
        selected = mainTab == "personal" and personalSelected or appearanceSelected
        local targetId = effectiveCategory()
        local row = category(targetId)
        title.Text, balance.Text = tr("title"), tostring(profile().rolls or 0) .. " Rolls"
        earn.Text, buy.Text, rotateHint.Text = tr("earn"), tr("buy"), tr("rotate")
        earn.Active, earn.Selectable = drawerMode == nil, drawerMode == nil
        buy.Active, buy.Selectable = drawerMode == nil and not roundActive(), drawerMode == nil and not roundActive()
        buy.TextColor3 = buy.Active and C.text or C.muted
        close.Active, close.Selectable = drawerMode == nil, drawerMode == nil
        close:SetAttribute("AccessibleLabel", tr("close"))
        personalTab.Text, appearanceTab.Text = tr("personal"), tr("appearance")
        for id, tab in pairs({personal = personalTab, appearance = appearanceTab}) do
            tab.Active, tab.Selectable = drawerMode == nil, drawerMode == nil
            tab.TextColor3 = mainTab == id and C.text or C.muted
            tab:FindFirstChild("SelectedRule").Visible = mainTab == id
        end
        local savedIdentity = identity()
        selectedTarget.Text = targetName(targetId, row)
        selectedTarget:SetAttribute("RollCategory", targetId)
        chanceDetails.Text = tr("allOdds") .. " ›"
        chanceDetails.Active, chanceDetails.Selectable = row ~= nil and not drawerMode, row ~= nil and not drawerMode
        chanceSummary.Text = selectedOdds(row)
        local fullName = (savedIdentity.firstName or "") .. " " .. (savedIdentity.lastName or "")
        portraitName.Text = fullName:gsub("^%s+", ""):gsub("%s+$", "")
        if portraitName.Text == "" then portraitName.Text = ctx.player.DisplayName end
        for _, definition in ipairs(IDENTITY_ROWS) do
            local field = identityRows[definition.id]
            field.frame.Visible = mainTab == "personal"
            field.caption.Text = tr(definition.copy)
            field.value.Text = definition.id == "nationality" and CharacterIdentity.label(savedIdentity, ctx.language()) or (savedIdentity[definition.id] or "—")
            local enabled = mainTab == "personal" and not pending and not busy and not drawerMode
            field.button.Active, field.button.Selectable = enabled, enabled
            field.marker.Visible = personalSelected == definition.id
            field.frame.BackgroundTransparency = personalSelected == definition.id and 0.15 or 0.65
            field.button:SetAttribute("AccessibleLabel", tr(definition.copy) .. " · " .. field.value.Text)
        end
        originHint.Text, originHint.Visible = tr("originHint"), mainTab == "personal"
        current.Visible, tabRail.Visible, owned.Visible = mainTab == "appearance", mainTab == "appearance", mainTab == "appearance"
        local appearanceRow = category(appearanceSelected)
        slotLabel.Text = categoryName(appearanceRow)
        local equippedId = appearanceRow and (profile().equipped or {})[appearanceRow.slot or appearanceRow.id]
        local item = equippedId and Catalog.ById[equippedId]
        currentName.Text = item and itemName(item)
            or (appearanceSelected == "hair" or appearanceSelected == "outfit") and tr("original") or tr("none")
        local definition = item and Catalog.Rarities[item.rarity]
        rarity.Text = definition and (ctx.language() == "en" and definition.en or definition.ru) or ""
        rarity.TextColor3 = C.muted
        owned.Text = tr("owned") .. " · " .. tostring(#ownedItems())
        owned.Active = mainTab == "appearance" and profile().ready == true and not pending and not requestPending() and not drawerMode
        owned.Selectable, owned.TextColor3 = owned.Active, owned.Active and C.text or C.muted
        drawTabs(force)
        for _, tab in pairs(tabButtons) do
            local enabled = mainTab == "appearance" and not pending and not busy and not drawerMode
            tab.Active, tab.Selectable = enabled, enabled
        end
        -- Recovery uses the retained category before any DTO, wallet, policy or
        -- phase checks. A tab switch can never create a new spend while pending.
        local active = canRoll(targetId)
        roll.Active, roll.Selectable = active == true, active == true
        roll.BackgroundColor3 = roll.Active and C.primary or C.raised
        roll.BackgroundTransparency = roll.Active and 0 or 0.25
        roll.TextColor3 = roll.Active and C.ink or C.muted
        rollIcon.TextColor3, rollIcon.Visible = roll.TextColor3, busy
        local action = busy and tr("pending") or pending and retrying and tr("retry") or tr("roll")
        roll.Text = action .. " · " .. targetName(targetId, row) .. "\n" .. (pending and "" or "1 Roll")
        roll:SetAttribute("RollCategory", targetId)
        roll:SetAttribute("AccessibleLabel", roll.Text)
        if (statusKey == "loading" and profile().ready == true)
            or (statusKey == "empty" and row and row.available ~= false)
            or (statusKey == "noRolls" and (profile().rolls or 0) > 0)
            or (statusKey == "trade" and row and row.reason ~= "trade_processing")
            or ((statusKey == "paidRestricted" or statusKey == "policyPending")
                and dto().canSpend ~= false and row and row.canSpend ~= false)
            or (statusKey == "round" and not roundActive()) then setStatus(nil) end
        if roundActive() then setStatus("round")
        elseif statusKey and statusKey ~= "paidRestricted" and statusKey ~= "policyPending" then setStatus(statusKey, statusError)
        elseif profile().ready ~= true then setStatus("loading")
        elseif row and row.reason == "trade_processing" then setStatus("trade")
        elseif not row or row.available == false then setStatus("empty")
        elseif (profile().rolls or 0) <= 0 and not retrying then setStatus("noRolls")
        elseif dto().canSpend == false or row.canSpend == false then setStatus(spendStatus(row) or "unavailable", true)
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
        if categoryId and category(categoryId) and not pending then
            if identityRows[categoryId] then mainTab, personalSelected = "personal", categoryId
            else mainTab, appearanceSelected = "appearance", categoryId end
        end
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
        TweenService:Create(overlay, TweenInfo.new(0.28), {BackgroundTransparency = 0.78}):Play()
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
                if identityResult then personalSelected = receipt.category or attempt.category
                else appearanceSelected = receipt.category or attempt.category end
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
                    slowDown = "slow", roll_match_active = "round", roll_paid_restricted = paidRestrictionStatus(),
                    roll_policy_pending = "policyPending", policy_pending = "policyPending"}
                setStatus(errors[code] or "unavailable", true)
                self:update(true)
            end
        end)
        return true
    end
    startRoll = function(categoryId)
        if not canRoll(categoryId) then return end
        if not pending then
            pending = {category = categoryId, label = targetName(categoryId, category(categoryId)),
                id = tostring((dto().sequence or 0) + 1) .. "-" .. HttpService:GenerateGUID(false)}
        end
        pending.started = os.clock()
        local attempt, started = pending, pending.started
        busy, retrying = true, false
        setStatus(nil)
        stopSpinner()
        spinnerNode = rollIcon
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
    earn.Activated:Connect(function() if earn.Active then openDrawer("earn") end end)
    buy.Activated:Connect(function()
        if buy.Active then self:close(false); ctx.openPanel("clubStore") end
    end)
    owned.Activated:Connect(function() if owned.Active then openDrawer("owned") end end)
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
            local rows = mainTab == "personal" and IDENTITY_ROWS or cosmeticCategories()
            local index = 1
            for i, row in ipairs(rows) do if row.id == selected then index = i; break end end
            if #rows > 0 then
                selected = rows[(index - 1 + (input.KeyCode == Enum.KeyCode.Right and 1 or -1)) % #rows + 1].id
                if mainTab == "personal" then personalSelected = selected else appearanceSelected = selected end
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
