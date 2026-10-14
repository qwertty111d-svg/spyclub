-- One personal dossier, one server-owned Rolls wallet, and one retained request per roll.
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
    ink = Color3.fromRGB(15, 15, 19), surface = Color3.fromRGB(29, 23, 28),
    raised = Color3.fromRGB(48, 32, 38), line = Color3.fromRGB(110, 82, 73),
    text = Color3.fromRGB(244, 232, 213), muted = Color3.fromRGB(179, 154, 141),
    brass = Color3.fromRGB(216, 180, 119), oxblood = Color3.fromRGB(103, 36, 48),
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
    make("UICorner", node, {CornerRadius = UDim.new(0, 4)})
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
    local alive, compact, portrait, shortLayout = true, false, false, false
    local connections = {}
    local selected, pending, busy, retrying = nil, nil, false, false
    local previewViewport, previewKey, tabsKey, ownedKey, spinning, spinnerNode
    local statusKey, statusError, equipRequestId, previousSelection
    local motionToken = 0
    local drawerMode = nil
    local oddsCategory = nil
    local openDrawer
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
        BackgroundColor3 = C.surface, BackgroundTransparency = 0.02, GroupTransparency = 0,
        BorderSizePixel = 0, Active = true, ZIndex = 82, ClipsDescendants = true, SelectionGroup = true,
        SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
        SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop})
    make("UICorner", panel, {CornerRadius = UDim.new(0, 6)})
    make("UIStroke", panel, {Color = C.line, Transparency = 0.36, Thickness = 1})
    local floating = FloatingUIController.create(panel, {container = overlay, maxOffset = 4,
        smoothTime = 0.15, safePadding = 12})
    local header = make("Frame", panel, {Name = "DossierHeader", BackgroundTransparency = 1})
    local title = label(header, "DossierTitle", tr("title"), 28)
    title.Font = Enum.Font.Garamond
    local classification = label(header, "ArchiveClassification", tr("classification"), 10, C.muted)
    local balance = label(header, "RollBalance", "0 Rolls", 22, C.brass)
    balance.Font = Enum.Font.BuilderSansBold
    balance.TextXAlignment = Enum.TextXAlignment.Right
    local earn = button(header, "EarnRolls", tr("earn"))
    earn.TextColor3 = C.muted
    earn.BackgroundTransparency = 1
    local buy = button(header, "BuyRolls", tr("buy"))
    buy.BackgroundColor3 = C.raised
    buy.BackgroundTransparency = 0.08
    buy.TextColor3 = C.brass
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
    local portraitPlate=make("Frame",previewStage,{Name="VelvetPortraitPlate",Size=UDim2.fromScale(1,1),
        BackgroundColor3=C.oxblood,BackgroundTransparency=.54,BorderSizePixel=0,ZIndex=previewStage.ZIndex})
    make("UICorner",portraitPlate,{CornerRadius=UDim.new(0,4)})
    local monogram=label(portraitPlate,"ClubMonogram","SC",180,C.brass)
    monogram.Font=Enum.Font.Garamond;monogram.TextTransparency=.89
    monogram.ZIndex=previewStage.ZIndex
    monogram.TextXAlignment=Enum.TextXAlignment.Center;monogram.Size=UDim2.fromScale(1,1)
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
        local chance=label(row,"IdentityOdds_"..definition.id,"—",10,C.brass)
        local details=button(row,"IdentityDetails_"..definition.id,"")
        details.BackgroundTransparency=1
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
            icon = icon, cost = cost, rule = rule, definition = definition,chance=chance,details=details}
        reroll.Activated:Connect(function() if startRoll then startRoll(definition.id) end end)
        details.Activated:Connect(function()if details.Active then openDrawer("odds",definition.id)end end)
    end
    local originHint = label(content, "OriginRule", tr("originHint"), 11, C.muted)
    local current = make("CanvasGroup", content, {Name = "CurrentWardrobeItem", BackgroundTransparency = 1,
        GroupTransparency = 0})
    local slotLabel = label(current, "SelectedCategory", "", 11, C.brass)
    local currentName = label(current, "EquippedItemName", "", 23)
    local rarity = label(current, "ItemRarity", "", 12, C.muted)
    local odds = button(current, "ShowOdds", tr("allOdds"))
    odds.BackgroundTransparency = 1
    odds.TextColor3 = C.muted
    odds.TextSize = 12
    local owned = button(content, "ChooseOwned", "")
    owned.TextXAlignment = Enum.TextXAlignment.Left
    make("UIPadding", owned, {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)})
    local ownedChevron = label(owned, "OpenCollection", "›", 25, C.brass)
    ownedChevron.AnchorPoint = Vector2.new(1, 0.5)
    ownedChevron.Position = UDim2.new(1, -12, 0.5, 0)
    ownedChevron.Size = UDim2.fromOffset(20, 34)
    local collectionNote = label(content, "CollectionHint", tr("ownedHint"), 11, C.muted)

    local footer = make("Frame", panel, {Name = "WardrobeFooter", BackgroundTransparency = 1})
    local chanceTitle=label(footer,"ChanceTitle",tr("poolOdds"),10,C.brass)
    local chanceSummary=label(footer,"ChanceSummary","—",12,C.text)
    local chanceDetails=button(footer,"ChanceDetails","")
    chanceDetails.BackgroundTransparency=1
    chanceDetails:SetAttribute("AccessibleLabel",tr("allOdds"))
    chanceDetails.Activated:Connect(function()if chanceDetails.Active then openDrawer("odds")end end)
    chanceSummary.TextWrapped=true;chanceSummary.TextTruncate=Enum.TextTruncate.None
    chanceSummary.TextYAlignment=Enum.TextYAlignment.Top
    local tabRail = make("ScrollingFrame", footer, {Name = "WardrobeTabs", BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.brass, ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.None, ClipsDescendants = true})
    local footerLine = divider(footer, "FooterRule")
    local roll = button(footer, "RollSelectedSlot", "")
    roll.BackgroundColor3 = C.brass
    roll.BackgroundTransparency = 0
    roll.Font = Enum.Font.BuilderSansBold
    roll.TextColor3 = C.ink
    roll.TextSize = 16
    roll.TextXAlignment=Enum.TextXAlignment.Center
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
                local amount = label(row, "RollsReward", "+" .. tostring(reward[2]) .. " Rolls", 14, C.brass)
                amount.TextXAlignment = Enum.TextXAlignment.Right
                amount.Position, amount.Size = UDim2.new(1, -84, 0, 0), UDim2.fromOffset(80, 48)
                local rule = divider(row, "RewardRule")
                rule.Position = UDim2.new(0, 0, 1, -1)
            end
        elseif drawerMode == "odds" then
            local row = category(oddsCategory or selected)
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
                local value=label(line,"OddsItemPercent",entry.percent,14,C.brass)
                value.TextXAlignment=Enum.TextXAlignment.Right
                value.Position,value.Size=UDim2.new(1,-76,0,0),UDim2.fromOffset(70,36)
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
        local columns = shortLayout and #rows or 4
        local tabWidth = shortLayout and 104 or math.max(1, (tabRail.AbsoluteSize.X - 12) / 4)
        for index, row in ipairs(rows) do
            local tab = button(tabRail, "Slot_" .. row.id, categoryName(row))
            local column, line = (index - 1) % math.max(1, columns), math.floor((index - 1) / math.max(1, columns))
            tab.Position = UDim2.fromOffset(column * (tabWidth + 4), line * 48)
            tab.Size, tab.LayoutOrder, tab.SelectionOrder = UDim2.fromOffset(tabWidth, 44), index, index + 5
            tab.BackgroundTransparency = selected == row.id and 0.28 or 1
            tab.BackgroundColor3 = C.raised
            tab.TextSize = compact and 12 or 13
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
        tabRail.CanvasSize = UDim2.fromOffset(shortLayout and #rows * 108 - 4 or 0,
            shortLayout and 0 or math.ceil(#rows / 4) * 48 - 4)
    end
    local function scrollSelectedTab()
        if not shortLayout then return end
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
        shortLayout = viewport.Y < 430
        local width = math.max(240, math.min(1120, viewport.X - (compact and 24 or 80)))
        local height = math.max(240, math.min(portrait and 780 or 760, viewport.Y - (compact and 24 or 80)))
        panel.Size = UDim2.fromOffset(width, height)
        floating:setBasePosition(UDim2.fromScale(0.5, 0.5))
        local padding = compact and 16 or 32
        local headerHeight = portrait and 96 or compact and 64 or 76
        local headerWidth = width - padding * 2
        header.Position = UDim2.fromOffset(padding, portrait and 8 or 12)
        header.Size = UDim2.fromOffset(headerWidth, headerHeight - (portrait and 12 or 24))
        classification.Visible = not compact
        classification.Position,classification.Size=UDim2.fromOffset(0,0),UDim2.fromOffset(320,16)
        close.Position, close.Size = UDim2.new(1, -44, 0, 0), UDim2.fromOffset(44, 44)
        if portrait then
            title.Position, title.Size = UDim2.fromOffset(0, 2), UDim2.fromOffset(headerWidth - 50, 32)
            title.TextSize = 24
            balance.Position, balance.Size = UDim2.fromOffset(0, 42), UDim2.fromOffset(82, 44)
            balance.TextXAlignment, balance.TextSize = Enum.TextXAlignment.Left, 17
            earn.Position, earn.Size = UDim2.fromOffset(86, 42), UDim2.fromOffset(headerWidth - 194, 44)
            earn.TextSize = 11
            buy.Position, buy.Size = UDim2.new(1, -104, 0, 42), UDim2.fromOffset(104, 44)
            buy.TextSize = 12
        else
            title.Position, title.Size = UDim2.fromOffset(0, compact and 1 or 13), UDim2.fromOffset(headerWidth - 424, 44)
            title.TextSize = compact and 28 or 38
            balance.Position, balance.Size = UDim2.new(1, -408, 0, 0), UDim2.fromOffset(100, 44)
            balance.TextXAlignment, balance.TextSize = Enum.TextXAlignment.Right, compact and 17 or 19
            earn.Position, earn.Size = UDim2.new(1, -300, 0, 0), UDim2.fromOffset(124, 44)
            earn.TextSize = 12
            buy.Position, buy.Size = UDim2.new(1, -168, 0, 0), UDim2.fromOffset(116, 44)
            buy.TextSize = 13
        end
        headerLine.Position, headerLine.Size = UDim2.fromOffset(padding, headerHeight), UDim2.fromOffset(headerWidth, 1)
        local chanceHeight=shortLayout and 44 or 58
        local footerHeight = (shortLayout and 134 or 184)+chanceHeight
        local footerTop = height - footerHeight - (compact and 10 or 18)
        local contentTop = headerHeight + (compact and 12 or 18)
        local contentWidth, bodyHeight, identityX, identityWidth, identityHeight
        subject.Visible = false
        if portrait then
            content.Position = UDim2.fromOffset(padding, contentTop)
            contentWidth, bodyHeight = width - padding * 2, footerTop - contentTop - 10
            preview.Parent = content
            preview.Position, preview.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(112, 216)
            identityX, identityWidth, identityHeight = 124, contentWidth - 124, 72
            verticalLine.Visible, portraitName.Visible, rotateHint.Visible = false, false, false
            previewStage.Position, previewStage.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(112, 216)
            originHint.Position, originHint.Size = UDim2.fromOffset(0, 225), UDim2.fromOffset(contentWidth, 29)
            originHint.TextSize, originHint.TextWrapped = 11, true
            current.Position, current.Size = UDim2.fromOffset(0, 266), UDim2.fromOffset(contentWidth, 66)
            owned.Position, owned.Size = UDim2.fromOffset(0, 340), UDim2.fromOffset(contentWidth, 44)
            collectionNote.Visible = false
            content.CanvasSize = UDim2.fromOffset(0, 384)
            footer.Position, footer.Size = UDim2.fromOffset(padding, footerTop), UDim2.fromOffset(contentWidth, footerHeight)
        else
            local split = math.floor(width * (compact and 0.36 or 0.44))
            local columnGap = compact and 16 or 24
            content.Position = UDim2.fromOffset(split + columnGap, contentTop)
            contentWidth, bodyHeight = width - split - padding - columnGap, footerTop - contentTop - 10
            preview.Parent = panel
            preview.Position, preview.Size = UDim2.fromOffset(padding, contentTop), UDim2.fromOffset(split - padding - 20, height - contentTop - padding)
            portraitName.Visible, rotateHint.Visible = not compact, true
            previewStage.Position = UDim2.fromOffset(0, 0)
            previewStage.Size = UDim2.new(1, 0, 1, compact and -28 or -84)
            portraitName.Position, portraitName.Size = UDim2.new(0, 0, 1, -72), UDim2.new(1, 0, 0, 38)
            portraitName.TextSize = 36
            rotateHint.Position, rotateHint.Size = UDim2.new(0, 0, 1, -26), UDim2.new(1, 0, 0, 22)
            rotateHint.TextSize = compact and 11 or 12
            verticalLine.Position, verticalLine.Size = UDim2.fromOffset(split, contentTop), UDim2.fromOffset(1, height - contentTop - padding)
            verticalLine.Visible = not compact
            identityX, identityWidth, identityHeight = 0, contentWidth, 72
            local belowIdentity = identityHeight * 3 + 8
            originHint.Position, originHint.Size = UDim2.fromOffset(0, belowIdentity), UDim2.fromOffset(contentWidth, 24)
            originHint.TextSize, originHint.TextWrapped = 11, false
            current.Position, current.Size = UDim2.fromOffset(0, belowIdentity + 34), UDim2.fromOffset(contentWidth, 68)
            owned.Position, owned.Size = UDim2.fromOffset(0, belowIdentity + 110), UDim2.fromOffset(contentWidth, 44)
            collectionNote.Visible = false
            content.CanvasSize = UDim2.fromOffset(0, belowIdentity + 154)
            footer.Position, footer.Size = UDim2.fromOffset(split + columnGap, footerTop), UDim2.fromOffset(contentWidth, footerHeight)
        end
        content.Size = UDim2.fromOffset(contentWidth, math.max(40, bodyHeight))
        for index, definition in ipairs(IDENTITY_ROWS) do
            local row = identityRows[definition.id]
            row.frame.Position = UDim2.fromOffset(identityX, (index - 1) * identityHeight)
            row.frame.Size = UDim2.fromOffset(identityWidth, identityHeight)
            row.caption.Position, row.caption.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(identityWidth - 48, 18)
            row.caption.TextSize = compact and 11 or 12
            row.value.Position, row.value.Size = UDim2.fromOffset(0, 19), UDim2.fromOffset(identityWidth - 48, compact and 26 or 30)
            row.value.TextSize = compact and(definition.id=="nationality"and 15 or 17)or 22
            row.button.Position, row.button.Size = UDim2.new(1, -44, 0, 0), UDim2.fromOffset(44, math.max(44, identityHeight - 4))
            row.icon.Position, row.icon.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(44, 28)
            row.cost.Position, row.cost.Size = UDim2.fromOffset(0, 28), UDim2.fromOffset(44, 15)
            row.chance.Position,row.chance.Size=UDim2.fromOffset(0,49),UDim2.new(1,-50,0,18)
            row.details.Position,row.details.Size=UDim2.fromOffset(0,0),UDim2.new(1,-50,1,-1)
            row.rule.Position = UDim2.new(0, 0, 1, -1)
        end
        slotLabel.Position, slotLabel.Size = UDim2.fromOffset(0, 0), UDim2.new(1, -104, 0, 18)
        currentName.Position, currentName.Size = UDim2.fromOffset(0, 19), UDim2.new(1, -104, 0, 28)
        currentName.TextSize = compact and 19 or 22
        rarity.Position, rarity.Size = UDim2.fromOffset(0, 47), UDim2.new(1, -48, 0, 19)
        odds.Position, odds.Size = UDim2.new(1, -100, 0, 16), UDim2.fromOffset(100, 44)
        chanceTitle.Position,chanceTitle.Size=UDim2.fromOffset(0,0),UDim2.new(1,0,0,14)
        chanceSummary.Position,chanceSummary.Size=UDim2.fromOffset(0,17),UDim2.new(1,0,0,chanceHeight-18)
        chanceDetails.Position,chanceDetails.Size=UDim2.fromOffset(0,0),UDim2.new(1,0,0,chanceHeight)
        local railHeight = shortLayout and 44 or 92
        tabRail.Position, tabRail.Size = UDim2.fromOffset(0, chanceHeight), UDim2.new(1, 0, 0, railHeight)
        tabRail.ScrollingDirection = shortLayout and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
        tabRail.CanvasPosition = Vector2.zero
        footerLine.Position = UDim2.fromOffset(0, chanceHeight+railHeight + 5)
        roll.Position, roll.Size = UDim2.fromOffset(0, chanceHeight+railHeight + 14), UDim2.new(1, 0, 0, 44)
        status.Position, status.Size = UDim2.fromOffset(0, chanceHeight+railHeight + 64), UDim2.new(1, 0, 0, 28)
        status.TextSize = 11
        local drawerWidth = math.min(462, width - (compact and 24 or 64))
        local drawerHeight = math.min(440, height - (compact and 30 or 90))
        drawer.AnchorPoint, drawer.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
        drawer.Size = UDim2.fromOffset(drawerWidth, drawerHeight)
        drawerTitle.Position, drawerTitle.Size = UDim2.fromOffset(20, 16), UDim2.new(1, -78, 0, 34)
        drawerTitle.TextSize = compact and 22 or 24
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
        earn.Text, buy.Text, subject.Text, rotateHint.Text = tr("earn"), tr("buy"), tr("subject"), tr("rotate")
        earn.Active, earn.Selectable = drawerMode == nil, drawerMode == nil
        buy.Active, buy.Selectable = drawerMode == nil and not roundActive(), drawerMode == nil and not roundActive()
        buy.TextColor3 = buy.Active and C.brass or C.muted
        close.Active, close.Selectable = drawerMode == nil, drawerMode == nil
        close:SetAttribute("AccessibleLabel", tr("close"))
        local savedIdentity = identity()
        chanceTitle.Text=tr("poolOdds").." · "..tr("allOdds").." ›"
        chanceDetails.Active,chanceDetails.Selectable=row~=nil and not drawerMode,row~=nil and not drawerMode
        chanceSummary.Text=RollOdds.summary(row,Catalog,ctx.language())
        local fullName = (savedIdentity.firstName or "") .. " " .. (savedIdentity.lastName or "")
        portraitName.Text = fullName:gsub("^%s+", ""):gsub("%s+$", "")
        if portraitName.Text == "" then portraitName.Text = ctx.player.DisplayName end
        for _, definition in ipairs(IDENTITY_ROWS) do
            local field = identityRows[definition.id]
            field.caption.Text = tr(definition.copy)
            field.value.Text = definition.id == "nationality" and CharacterIdentity.label(savedIdentity, ctx.language()) or (savedIdentity[definition.id] or "—")
            field.chance.Text=RollOdds.summary(category(definition.id),Catalog,ctx.language(),panel.AbsoluteSize.X<660)
            field.details.Active,field.details.Selectable=drawerMode==nil and category(definition.id)~=nil,drawerMode==nil and category(definition.id)~=nil
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
        odds.Text=tr("allOdds")
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
    buy.Activated:Connect(function()
        if buy.Active then self:close(false); ctx.openPanel("clubStore") end
    end)
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
