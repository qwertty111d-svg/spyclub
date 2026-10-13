local controlThemeNode=script.Parent:FindFirstChild("UITheme")
local ControlTheme=controlThemeNode and require(controlThemeNode)
-- SPY CLUB PREMIUM SHOP V1 :: InventoryUI
-- SPY_COSMETICS_V1: InventoryUI
local TweenService = game:GetService("TweenService")

local ModalUI = require(script.Parent.ModalUI)
local CatalogUI = require(script.Parent.CatalogUI)
local Catalog = require(script.Parent.Catalog)
local Preview3D = require(script.Parent.Preview3D)
local Art = require(script.Parent.Art)

local InventoryUI = {}

local C = {
	Background = Color3.fromRGB(25,27,31),
	Surface = Color3.fromRGB(34,36,40),
	Card = Color3.fromRGB(46,48,52),
	Hover = Color3.fromRGB(57,59,63),
	Selected = Color3.fromRGB(68,60,47),
	Preview = Color3.fromRGB(34,36,40),

	Cream = Color3.fromRGB(244,240,231),
	Text = Color3.fromRGB(244,240,231),
	Muted = Color3.fromRGB(188,187,181),
	Border = Color3.fromRGB(87,89,93),
	Gold = Color3.fromRGB(221,193,151),
	Ink = Color3.fromRGB(26,28,32),
	Green = Color3.fromRGB(160, 189, 151),
}

local FONT = Enum.Font.BuilderSansBold
local BODY = Enum.Font.BuilderSansMedium

local COPY = {
	title = { "Инвентарь", "Inventory", "背包" },
	all = { "ВСЁ", "ALL" },
	sets = { "НАБОРЫ", "SETS" },
	back = { "← НАЗАД", "← BACK", "← 返回" },
	shop = { "МАГАЗИН", "SHOP" },
	trade = { "ОБМЕН", "TRADE" },
	empty = { "ПОКА ПУСТО", "NOTHING HERE YET" },
	emptyHint = {
		"Предметы из наград и Rolls появятся здесь.",
		"Items from rewards and Rolls will appear here.",
	},
	unavailable = {
		"ПРОФИЛЬ НЕДОСТУПЕН",
		"PROFILE UNAVAILABLE",
	},
	retry = { "ПОВТОРИТЬ", "TRY AGAIN" },
	equipped = { "НАДЕТО", "EQUIPPED", "已装备" },
	equip = { "НАДЕТЬ", "EQUIP", "装备" },
	unequip = { "СНЯТЬ", "UNEQUIP", "卸下" },
	use = { "ИСПОЛЬЗОВАТЬ", "USE", "使用" },
	play = { "ИГРАТЬ", "PLAY" },
	loading = { "ПОДОЖДИ…", "PLEASE WAIT…", "请稍候…" },
	quantity = { "В наличии: %d", "Available: %d" },
	copies = { "Копий в наличии: %d", "Copies owned: %d" },
	progress = { "Собрано %d из %d", "%d of %d collected" },
	reward = { "НАГРАДА ЗА НАБОР", "SET REWARD" },
	locked = {
		"Предмет ещё не получен. Источник указан выше.",
		"Not collected yet. See the source above.",
	},
	select = {
		"ВЫБЕРИ ПРЕДМЕТ",
		"SELECT AN ITEM",
	},
}

local RARITY = {
	starter = Color3.fromRGB(176, 181, 178),
	common = Color3.fromRGB(211, 201, 185),
	uncommon = Color3.fromRGB(151, 192, 156),
	rare = Color3.fromRGB(143, 175, 221),
	epic = Color3.fromRGB(188, 155, 222),
	legendary = Color3.fromRGB(197, 161, 104),
	mythic = Color3.fromRGB(226, 143, 155),
}
for key,rarity in pairs(Catalog.Rarities)do RARITY[key]=Color3.fromRGB(table.unpack(rarity.color))end

local function make(className, parent, properties)
	local object = Instance.new(className)

	for key, value in pairs(properties or {}) do
		object[key] = value
	end

	object.Parent = parent
	return object
end

local function round(parent, radius)
    radius=math.clamp(radius or 12,10,20)
	local existing = parent:FindFirstChildOfClass("UICorner")

	if existing then
		existing.CornerRadius = UDim.new(0, radius)
		return existing
	end

	return make("UICorner", parent, {
		CornerRadius = UDim.new(0, radius),
	})
end

local function outline(parent, color, thickness, transparency)
	return make("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or C.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	})
end

local function label(parent, value, position, size, fontSize, color, body)
	return make("TextLabel", parent, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,

		Text = value,
		TextSize = fontSize or 20,
		TextScaled = false,
		TextColor3 = color or C.Text,
		Font = body and BODY or FONT,

		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
end

local function scrolling(parent, name, position, size, horizontal)
	return make("ScrollingFrame", parent, {
		Name = name,
		Position = position,
		Size = size,

		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = horizontal
			and Enum.AutomaticSize.X
			or Enum.AutomaticSize.Y,

		ScrollingDirection = horizontal
			and Enum.ScrollingDirection.X
			or Enum.ScrollingDirection.Y,

		ScrollBarThickness = horizontal and 3 or 4,
		ScrollBarImageColor3 = C.Gold,
		ScrollBarImageTransparency = 0.25,
		ClipsDescendants = true,
	})
end

function InventoryUI.create(ctx)
	local self = ModalUI.create(
		ctx,
		"inventory",
		"inventory",
		"inventoryHint",
		1120
	)

	self.filter = "all"
 self.query="";self.slot="all";self.style="all";self.tier="all";self.collectionMode="items"
 self.sort="rarity";self.duplicates=false;self.filtersOpen=false;self.saleItemId=nil
	self.selectedItem = nil
	self.selectedSet = nil

	local detailOpen = false
	local motions = {}
	local generation = 0
	local entrance = false
	local scrollPosition = Vector2.new()
	local tabsPosition = Vector2.new()
	local currentScroll
	local currentTabs
	local currentSearch
	local refreshBrowser
	local searchFocused=false
	local searchRefreshKey=nil
	local searchRevision = 0

	local function tr(key, ...)
		local index = ctx.language() == "zh" and 3 or ctx.language() == "en" and 2 or 1
		return string.format(COPY[key][index] or COPY[key][1], ...)
	end

	local SLOT_NAMES = {
		hair = { "Причёски", "Hair", "发型" },
		hat = { "Шляпы", "Hats", "帽子" },
		glasses = { "Очки", "Glasses", "眼镜" },
		tie = { "На шею", "Neckwear", "领饰" },
		outfit = { "Костюмы", "Outfits", "服装" },
		gloves = { "Перчатки", "Gloves", "手套" },
		shoulder = { "Кобуры", "Holsters", "枪套" },
		accessory = { "Аксессуары", "Accessories", "配饰" },
		card = { "Карточки", "Cards", "卡片" },
		effect = { "Эффекты", "Effects", "特效" },
		trinket = { "На стол", "Table props", "桌面饰品" },
		emote = { "Эмоции", "Emotes", "动作" },
		frame = { "Рамки", "Frames", "边框" },
		title = { "Звания", "Titles", "称号" },
		gadget = { "Инструменты", "Tools", "工具" },
	}

	local function text(ru, en, zh)
		return ctx.language() == "zh" and zh or ctx.language() == "en" and en or ru
	end

	local function browserToolsHeight(width, height)
		local base = height < 430 and 126 or 156
		if height >= 430 and self.filtersOpen then
			base += width < 500 and 96 or 48
			if self.slot == "hair" then base += 48 end
		end
		return base
	end

	local function itemSlot(item)
		return item.equipSlot or item.kind
	end

	local function utilityText(item)
		local value=ctx.language()=="en" and item.useEn or item.useRu
		if value and value~="" then return value end
		local slot=itemSlot(item)
		local fallback={
			card={"Досье на поясе и карта на столе","Belt dossier and table card"},
			frame={"Досье, табличка над головой и состав клуба","Dossier, overhead tag and club roster"},
			title={"Табличка над головой и состав клуба","Overhead tag and club roster"},
			effect={"Персонаж и финал матча","Character aura and match result"},
			trinket={"Предмет на поясе и игровом столе","Belt prop and table prop"},
		}
		local pair=fallback[slot]
		return pair and pair[ctx.language()=="en" and 2 or 1] or (ctx.language()=="en" and "Equipped on your character" or "Надевается на персонажа")
	end

	local function slotName(key)
		local value = SLOT_NAMES[key]
		if value then return value[ctx.language() == "zh" and 3 or ctx.language() == "en" and 2 or 1] end
		return CatalogUI.kind(ctx, key)
	end

	local function tween(object, duration, properties)
		if motions[object] then
			motions[object]:Cancel()
		end

		local motion = TweenService:Create(
			object,
			TweenInfo.new(
				duration,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),
			properties
		)

		motions[object] = motion
		motion:Play()
	end

	local function stopAnimations()
		generation = generation + 1

		for _, motion in pairs(motions) do
			motion:Cancel()
		end

		motions = {}
	end

	local function button(parent, caption, position, size, primary, callback)
		local normal = primary and C.Cream or C.Card
		local hover = primary
			and Color3.fromRGB(255, 238, 215)
			or C.Hover

		local b = make("TextButton", parent, {
			Position = position,
			Size = size,
			BackgroundColor3 = normal,
			BorderSizePixel = 0,
			AutoButtonColor = false,

			Text = caption,
			TextSize = 22,
			TextScaled = false,
			TextWrapped = true,
			Font = FONT,
			TextColor3 = primary and C.Ink or C.Text,
		})

		round(b, 7)
        if ControlTheme and ControlTheme.button then ControlTheme.button(b,primary)end

		local scale = make("UIScale", b, {
			Scale = 1,
		})

		local function release()
			tween(scale, 0.18, { Scale = 1 })
		end

		b.MouseEnter:Connect(function()
			tween(b, 0.16, {
				BackgroundColor3 = hover,
			})
		end)

		b.MouseLeave:Connect(function()
			release()

			tween(b, 0.2, {
				BackgroundColor3 = normal,
			})
		end)

		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				tween(scale, 0.09, {
					Scale = 0.98,
				})
			end
		end)

		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				release()
			end
		end)

		b.Activated:Connect(function()
			release()

			if callback then
				callback()
			end
		end)

		return b
	end

	local function rememberScroll()
		if currentScroll and currentScroll.Parent then
			scrollPosition = currentScroll.CanvasPosition
		end

		if currentTabs and currentTabs.Parent and currentTabs:IsA("ScrollingFrame") then
			tabsPosition = currentTabs.CanvasPosition
		end
	end

	local function fit()
		if self.kicker then self.kicker.Visible=false end
		local viewport = ctx.gui.AbsoluteSize
		local width = math.max(1, math.min(1120, viewport.X - 24))
		local height = math.max(1, math.min(760, viewport.Y - 32))

  -- A small desktop collection needs only its actual rows. Inspection retains
  -- the full stage; phones and short landscape keep their established bounds.
  if not detailOpen and width>=900 and height>=560 then
   local profile=ctx.profile()or{}
   if profile.ready then
    local isSets=self.filter=="sets"or(self.filter=="collection"and self.collectionMode=="sets")
    local entries=isSets and Catalog.Sets or Catalog.inventoryItems(profile,{
     group=self.filter,query=self.query,slot=self.slot,style=self.style,tier=self.tier,
     sort=self.sort,duplicates=self.duplicates,language=ctx.language(),
    })
    local available=width-46
    local columns=math.max(1,math.floor((available+12)/200))
    local cell=math.floor((available-(columns-1)*12)/columns)
    local rows=math.max(1,math.ceil(#entries/columns))
    local tools=browserToolsHeight(width,height)
    local cardHeight=cell+(isSets and 54 or 106)
    height=math.min(height,math.max(440,70+tools+rows*cardHeight+(rows-1)*12+26))
   end
  end

		self.layoutWidth = width
  self.layoutHeight = height
		self.modal.Size = UDim2.fromOffset(width, height)
		self.modal.BackgroundColor3 = C.Background
		self.modal.BackgroundTransparency = .16
		self.modal.ClipsDescendants = true
		self.modal.Active = true

		round(self.modal, 20)

		local border = self.modal:FindFirstChildOfClass("UIStroke")

		if border then
			border.Color = C.Border
			border.Thickness = 1
			border.Transparency = 0.2
		end

		self.title.Text = tr("title")
		self.title.Font = Enum.Font.BuilderSansBold
		self.title.TextScaled = false
  self.title.TextXAlignment=Enum.TextXAlignment.Left
		self.title.TextSize = width < 500 and 20 or 32
		self.title.TextColor3 = C.Cream
		self.title.Position = UDim2.fromOffset(20, height<320 and 2 or 12)
		self.title.Size = UDim2.new(1, width<500 and -186 or -210, 0, 44)

		self.hint.Visible = false

		local surfaceTop=height<320 and 52 or 70
		self.surface.Position = UDim2.fromOffset(16, surfaceTop)
		self.surface.Size = UDim2.new(1, -32, 1, -(surfaceTop+12))
		self.surface.CanvasPosition = Vector2.new()
		self.surface.CanvasSize = UDim2.new()
		self.surface.AutomaticCanvasSize = Enum.AutomaticSize.None
		self.surface.ScrollingEnabled = false
		self.surface.ScrollBarThickness = 0

		local overlay = self.modal.Parent
		local dismiss = overlay and overlay:FindFirstChild("DismissBackdrop")

		if dismiss then
			dismiss.Visible = false
			dismiss.Active = false
			dismiss.Selectable = false
		end

		if overlay then
			overlay.Active = true
		end
	end

	-- Убираем автоматическую вертикальную раскладку ModalUI.
	for _, child in ipairs(self.surface:GetChildren()) do
		if child:IsA("UIListLayout")
			or child:IsA("UIGridLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end

	local function categoryName(key)
		if key == "all" or key == "sets" then
			return tr(key)
		end

		return slotName(key)
	end

	local function ownedItems(profile)
		return Catalog.inventoryItems(profile,{group=self.filter,query=self.query,slot=self.slot,style=self.style,tier=self.tier,sort=self.sort,duplicates=self.duplicates,language=ctx.language()})
	end

	local function useItem(item)
		local profile = ctx.profile() or {}

		if self.filter == "collection"
			or ctx.pending()
			or not profile.ready
			or not (profile.owned or {})[item.id]
		then
			return
		end

		if item.kind == "gadget" then
			local quantity = (profile.quantities or {})[item.id] or 0

			if quantity <= 0 then
				return
			end

			if item.id == "notebook"
				and ctx.notesUnlocked
				and ctx.notesUnlocked()
			then
				if ctx.openNotes then
					ctx.openNotes()
				end
			else
				ctx.request("useGadget", item.id)
			end

			return
		end

		local equipped = (profile.equipped or {})[itemSlot(item)] == item.id

		-- EconomyAction -> kind="equip" is sent only through ctx.request after server-owned state checks.
		ctx.request(
			"equip",
			equipped and ("clear:" .. itemSlot(item)) or item.id
		)
	end

	local function buildTabs(parent)
		local short = self.layoutHeight < 430
		local narrow = self.layoutWidth < 500
		local searchTop = short and 30 or 52
		local typesTop = short and 78 or 104
		self.categoryRailWidth = 0

		local function change(field, value)
			searchRevision += 1
			self[field] = value
			self.saleItemId = nil
			self.selectedItem = nil
			self.selectedSet = nil
			detailOpen = false
			scrollPosition = Vector2.new()
			currentScroll = nil
			self:render()
		end

		local tradeButton = button(self.modal, text("Обмен", "Trade", "交易"), UDim2.new(1, narrow and -132 or -154, 0, short and 5 or 13), UDim2.fromOffset(narrow and 78 or 100, 40), false, function()
			local player = game:GetService("Players").LocalPlayer
			local pg = player and player:FindFirstChildOfClass("PlayerGui")
			if not pg then return end
			local event = pg:FindFirstChild("SpyOpenTrade") or make("BindableEvent", pg, { Name = "SpyOpenTrade" })
			if event:IsA("BindableEvent") then self:close(false); event:Fire() end
		end)
		tradeButton.Name = "OpenInventoryTrade"
		tradeButton.TextSize = 16

		currentTabs = make("Frame", parent, { Name = "Categories", Size = UDim2.new(1, 0, 0, short and 28 or 44), BackgroundTransparency = 1 })
		local groups = {
			{ "all", "Все", "All", "全部" },
			{ "appearance", "Одежда", "Style", "外观" },
			{ "loadout", "Для игры", "Gear", "道具" },
			{ "collection", "Каталог", "Catalog", "图鉴" },
		}
		for index, group in ipairs(groups) do
			local tab = button(currentTabs, text(group[2], group[3], group[4]), UDim2.new((index - 1) / 4, 0, 0, 0), UDim2.new(.25, -4, 0, short and 28 or 44), false, function()
				self.slot = "all"; self.style = "all"; self.tier = "all"; self.duplicates = false
				tabsPosition = Vector2.new(); currentTabs = nil
				change("filter", group[1])
			end)
			tab.Name = "Group_" .. group[1]
			tab.TextSize = narrow and 13 or 17
			tab.BackgroundTransparency = 1
			tab.TextColor3 = self.filter == group[1] and C.Cream or C.Muted
			if self.filter == group[1] then
				make("Frame", tab, { Name = "SelectedCategory", Position = UDim2.new(0, 10, 1, -2), Size = UDim2.new(1, -20, 0, 2), BackgroundColor3 = C.Gold, BorderSizePixel = 0 })
			end
		end

		local search = make("TextBox", parent, {
			Name = "InventorySearch", Text = self.query,
			PlaceholderText = text("Поиск предметов", "Search items", "搜索物品"), ClearTextOnFocus = false,
			Position = UDim2.fromOffset(0, searchTop), Size = UDim2.new(1, -100, 0, 44),
			BackgroundColor3 = C.Preview, BackgroundTransparency = .18,
			TextColor3 = C.Text, PlaceholderColor3 = C.Muted, TextSize = 17,
			Font = BODY, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0,
		})
		currentSearch = search
		round(search, 12); outline(search, C.Border, 1, .5)
		make("UIPadding", search, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) })
		local function commit()
			if search ~= currentSearch or not search.Parent or detailOpen then return end
			if self.query == search.Text then return end
			self.query = search.Text
			self.saleItemId = nil; self.selectedItem = nil; self.selectedSet = nil
			scrollPosition = Vector2.new(); currentScroll = nil
			if refreshBrowser then refreshBrowser() end
		end
		search:GetPropertyChangedSignal("Text"):Connect(function()
			searchRevision += 1
			local revision = searchRevision
			task.delay(.16, function()
				if revision == searchRevision and self.visible then commit() end
			end)
		end)
		search.Focused:Connect(function()searchFocused=true end)
		search.FocusLost:Connect(function()searchFocused=false;searchRevision += 1;commit()end)
		local filters = button(parent, text("Фильтры", "Filters", "筛选"), UDim2.new(1, -92, 0, searchTop), UDim2.fromOffset(92, 44), self.filtersOpen, function()
			self.filtersOpen = not self.filtersOpen; self:render()
		end)
		filters.Name = "InventoryFilters"; filters.TextSize = 14
		if self.duplicates or self.tier ~= "all" or self.sort ~= "rarity" or self.style ~= "all" then filters.Text ..= " ·" end

		local isCatalog = self.filter == "collection"
		local types = scrolling(parent, "InventoryTypes", UDim2.fromOffset(0, typesTop), UDim2.new(1, isCatalog and -108 or 0, 0, 44), true)
		currentTabs = types
		types.ScrollBarThickness = 2
		make("UIListLayout", types, { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
		local slots = { { "all", text("Все типы", "All types", "全部类型") } }
		local seen = {}
		for _, item in ipairs(Catalog.Items) do
			if self.filter == "all" or isCatalog or Catalog.itemGroup(item) == self.filter then seen[itemSlot(item)] = true end
		end
		for _, slot in ipairs({ "hair", "hat", "outfit", "glasses", "tie", "gloves", "shoulder", "accessory", "card", "effect", "trinket", "emote", "frame", "title", "gadget" }) do
			if seen[slot] then slots[#slots + 1] = { slot, slotName(slot) } end
		end
		for index, entry in ipairs(slots) do
			local width = math.clamp(utf8.len(entry[2]) * (ctx.language() == "zh" and 15 or ctx.language() == "ru" and 9 or 8) + 24, 76, 144)
			local chip = button(types, entry[2], UDim2.new(), UDim2.fromOffset(width, 44), self.slot == entry[1], function()
				self.style = "all"; change("slot", entry[1])
			end)
			chip.Name = "Type_" .. entry[1]; chip.LayoutOrder = index; chip.TextSize = 14; chip.TextWrapped = false
			chip.BackgroundTransparency = self.slot == entry[1] and .08 or .48
		end
		local token = generation
		task.defer(function()
			if token == generation and types.Parent then types.CanvasPosition = tabsPosition end
		end)
		if isCatalog then
			local mode = button(parent, self.collectionMode == "sets" and text("Вещи", "Items", "物品") or text("Наборы", "Sets", "套装"), UDim2.new(1, -100, 0, typesTop), UDim2.fromOffset(100, 44), false, function()
				change("collectionMode", self.collectionMode == "sets" and "items" or "sets")
			end)
			mode.Name = "CollectionMode"; mode.TextSize = 14
		end

		self.filtersHeight = browserToolsHeight(self.layoutWidth, self.layoutHeight)
		if not self.filtersOpen then return end
		local advancedTop = typesTop + 48
		local controls = parent
		if short then
			controls = scrolling(parent, "AdvancedInventoryFilters", UDim2.fromOffset(0, advancedTop), UDim2.new(1, 0, 1, -advancedTop), false)
			controls.BackgroundColor3 = C.Surface; controls.BackgroundTransparency = .08
		end
		local columns = narrow and 2 or 4
		local function controlPosition(index)
			return UDim2.new(((index - 1) % columns) / columns, 0, 0, (short and 0 or advancedTop) + math.floor((index - 1) / columns) * 48)
		end
		local duplicate = button(controls, text("Повторы", "Copies", "重复物品"), controlPosition(1), UDim2.new(1 / columns, -6, 0, 44), self.duplicates, function() change("duplicates", not self.duplicates) end)
		duplicate.Name = "DuplicateFilter"; duplicate.TextSize = 14
		local function selectFilter(field, name, choices, index)
			local selected = ""
			for _, entry in ipairs(choices) do if entry[1] == self[field] then selected = entry[2] end end
			local control = button(controls, selected, controlPosition(index), UDim2.new(1 / columns, -6, 0, 44), false, function()
				local old = parent:FindFirstChild("FilterPopup")
				if old then old:Destroy(); return end
				local popupTop = short and advancedTop or advancedTop + math.ceil(4 / columns) * 48
				local popupHeight = math.max(44, math.min(226, self.layoutHeight - (self.surface.Position.Y.Offset + 12 + popupTop)))
				local popup = make("Frame", parent, { Name = "FilterPopup", Position = UDim2.fromOffset(0, popupTop), Size = UDim2.new(1, 0, 0, popupHeight), BackgroundColor3 = C.Surface, BorderSizePixel = 0, ZIndex = 70, ClipsDescendants = true })
				round(popup, 12); outline(popup, C.Gold, 1, .35)
				local list = scrolling(popup, "FilterOptions", UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12), false); list.ZIndex = 71
				make("UIListLayout", list, { Padding = UDim.new(0, 3) })
				for _, entry in ipairs(choices) do
					local option = button(list, entry[2], UDim2.new(), UDim2.new(1, -4, 0, 44), entry[1] == self[field], function()
						if field == "slot" then self.style = "all" end
						change(field, entry[1])
					end)
					option.Name = "Filter_" .. field .. "_" .. entry[1]; option.TextSize = 14; option.ZIndex = 72
				end
			end)
			control.Name = name; control.TextSize = narrow and 12 or 14
			control.TextWrapped = false; control.TextTruncate = Enum.TextTruncate.AtEnd
		end
		selectFilter("slot", "SlotFilter", slots, 2)
		local tiers = { { "all", text("Все редкости", "All tiers", "全部稀有度") } }
		local tierZh = { starter = "基础", common = "普通", uncommon = "非凡", rare = "稀有", epic = "史诗", legendary = "传说", mythic = "神话" }
		for _, key in ipairs({ "starter", "common", "uncommon", "rare", "epic", "legendary", "mythic" }) do
			local rarity = Catalog.Rarities[key]; tiers[#tiers + 1] = { key, text(rarity.ru, rarity.en, tierZh[key]) }
		end
		selectFilter("tier", "TierFilter", tiers, 3)
		selectFilter("sort", "SortFilter", { { "rarity", text("По редкости", "By rarity", "按稀有度") }, { "value", text("По ценности", "By value", "按价值") }, { "name", text("По названию", "By name", "按名称") } }, 4)
		if self.slot == "hair" then
			local stripTop = (short and 0 or advancedTop) + math.ceil(4 / columns) * 48
			local strip = make("Frame", controls, { Name = "HairSections", Position = UDim2.fromOffset(0, stripTop), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
			local choices = { { "all", "Все", "All", "全部", "HairAll" }, { "male", "Мужские", "Male", "男式", "HairMale" }, { "female", "Женские", "Female", "女式", "HairFemale" }, { "unisex", "Унисекс", "Unisex", "通用", "HairUnisex" } }
			for index, entry in ipairs(choices) do
				local option = button(strip, text(entry[2], entry[3], entry[4]), UDim2.new((index - 1) / 4, 0, 0, 0), UDim2.new(.25, -4, 0, 44), self.style == entry[1], function() change("style", entry[1]) end)
				option.Name = entry[5]; option.TextSize = narrow and 11 or 14
			end
		end
	end

	local function emptyState(parent, unavailable)
		local title = label(
			parent,
			tr(unavailable and "unavailable" or "empty"),
			UDim2.new(0, 16, 0.2, 0),
			UDim2.new(1, -32, 0, 68),
			28,
			C.Cream
		)

		title.TextXAlignment = Enum.TextXAlignment.Center

		if not unavailable then
			local hint = label(
				parent,
				tr("emptyHint"),
				UDim2.new(0, 20, 0.2, 72),
				UDim2.new(1, -40, 0, 64),
				18,
				C.Muted,
				true
			)

			hint.TextXAlignment = Enum.TextXAlignment.Center
		end

		button(
			parent,
			tr(unavailable and "retry" or "shop"),
			UDim2.new(0.1, 0, 0.2, unavailable and 90 or 152),
			UDim2.new(0.8, 0, 0, 48),
			true,
			function()
				if unavailable then
					if not ctx.pending() then
						ctx.request("retry")
					end
				else
					ctx.openPanel("shop")
				end
			end
		)
	end

	local function buildInspector(parent, item, setData, compact)
		parent.BackgroundColor3 = C.Surface
  parent.BackgroundTransparency = .22
		round(parent, 16)
		outline(parent, C.Border, 1, 0.45)

  local short=self.layoutHeight<430
		local top = 52
  local wide = not compact and not short

		do
			local back=button(
				parent,
				tr("back"),
				UDim2.fromOffset(10, 8),
				UDim2.fromOffset(150, 44),
				false,
				function()
					detailOpen = false
     self.saleItemId=nil
					self:render()
				end
			)
   back.Name="InventoryBack"
		end

		if not item then
			local message = label(
				parent,
				tr("select"),
				UDim2.fromOffset(16, top + 20),
				UDim2.new(1, -32, 0, 80),
				24,
				C.Muted
			)

			message.TextXAlignment = Enum.TextXAlignment.Center
			return
		end

		local profile = ctx.profile() or {}
		local owned = (profile.owned or {})[item.id] == true
		local equipped = (profile.equipped or {})[itemSlot(item)] == item.id
		local quantity = (profile.quantities or {})[item.id] or 0

		local catalogOnly = self.filter == "collection"
		local canPerform = owned and not catalogOnly
			and item.kind == "emote"
			and equipped

  local sale=Catalog.sellInfo(item.id)
  local canSell=owned and not catalogOnly and not setData and sale.sellable
  local confirming=canSell and self.saleItemId==item.id
		local actionHeight = short and 48 or ((canPerform and 54 or 0)+(canSell and 48 or 0)+56)
  local columns=1+(canSell and 1 or 0)+(canPerform and 1 or 0)
  local function shortAction(index)
   return UDim2.new(index/columns,4,0,0),UDim2.new(1/columns,-8,0,44)
  end

		local content = scrolling(
			parent,
			"ItemDetails",
			UDim2.fromOffset(12, top + (short and 8 or 12)),
			UDim2.new(1, -24, 1, -(top + actionHeight + (short and 24 or 34))),
			false
		)

		make("UIListLayout", content, {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})

		make("UIPadding", content, {
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 10),
		})

		local preview = make("Frame", content, {
			Name = "ItemPreview",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, compact and math.min(300,self.layoutWidth-80) or 360),
			BackgroundColor3 = C.Preview,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})

  if wide then
   preview.Parent=parent
   preview.Position=UDim2.fromOffset(20,top+12)
   preview.Size=UDim2.new(.57,-32,1,-(top+32))
   content.Position=UDim2.new(.57,0,0,top+20)
   content.Size=UDim2.new(.43,-24,1,-(top+actionHeight+44))
  end
  preview.BackgroundTransparency=.35
		round(preview, 16)
		if item and (item.wearable or item.kind=="outfit" or item.kind=="accessory" or item.kind=="trinket") then
			Preview3D.mountCollection(preview, { item }, { motion = false, equipped = profile.equipped })
		else
			Preview3D.mount(preview, item, nil)
		end

		local function line(value, size, color, order, height, body)
			local node = label(
				content,
				value,
				UDim2.new(),
				UDim2.new(1, 0, 0, height or 28),
				size,
				color,
				body
			)

			node.LayoutOrder = order
			node.AutomaticSize = Enum.AutomaticSize.Y
			return node
		end

		line(
			CatalogUI.itemName(ctx, item),
			28,
			C.Cream,
			2,
			40
		)

		line(
			ctx.L(item.rarity) .. " · " .. slotName(itemSlot(item)),
			17,
			(item.kind=="title" and item.titleColor and Color3.fromRGB(item.titleColor[1],item.titleColor[2],item.titleColor[3])) or RARITY[item.rarity] or C.Muted,
			3,
			28,
			true
		)

  if item.kind=="gadget"then line(utilityText(item),16,C.Muted,4,34,true)end

  if not setData then
   if sale.value>0 then
    local appraisal=line((ctx.language()=="en"and"Value: "or"Ценность: ")..tostring(sale.value),16,C.Cream,6,28,true)
    appraisal.Name="CatalogAppraisal"
    if sale.sellable then
     local offer=line((ctx.language()=="en"and"Sell for "or"Продать за ")..tostring(sale.offer)..(ctx.language()=="en"and" coins"or" монет"),13,C.Muted,7,26,true)
     offer.Name="ServerSaleOffer";offer.Visible=false
    end
   end
   if not owned then
    for _,category in ipairs((profile.accessoryRoll or {}).categories or {}) do
     for _,entry in ipairs(category.items or {}) do
      if entry.id==item.id then
       local categoryName=ctx.language()=="en" and category.labelEn or category.labelRu
       line((categoryName or category.id).." · "..string.format("%.2f%%",entry.chance or 0).." · 1 Roll",13,C.Muted,22,24,true)
      end
     end
    end
   end
  end
  if setData then
			local count = 0

			for _, id in ipairs(setData.items) do
				if (profile.owned or {})[id] then
					count = count + 1
				end
			end

			line(tr("reward"), 20, C.Gold, 5)
			line(ctx.L(setData.nameKey), 23, C.Text, 6)
			line(
				tr("progress", count, #setData.items),
				18,
				C.Muted,
				7,
				28,
				true
			)

			for index, id in ipairs(setData.items) do
				local member = Catalog.ById[id]

				if member then
					local collected = (profile.owned or {})[id]

					line(
						(collected and "✓  " or "—  ")
							.. CatalogUI.itemName(ctx, member),
						17,
						collected and C.Green or C.Muted,
						8 + index,
						28,
						true
					)
				end
			end
		elseif item.kind == "gadget" then
			line(tr("quantity", quantity), 18, C.Muted, 5, 28, true)
		elseif equipped then
			line(tr("equipped"), 20, C.Green, 5)
		end

		if owned and not setData and item.kind ~= "gadget" then
			local copies = (profile.itemCounts or {})[item.id] or 1
			local count = line("×"..tostring(copies), 17, C.Muted, 20, 28, true)
			count.Name = "OwnedCopyCount"
   count.Visible = copies>1
		end

		local actions = make("Frame", parent, {
   Name="InventoryActions",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			Size = UDim2.new(1, -24, 0, actionHeight),
			BackgroundTransparency = 1,
		})

  if wide then
   actions.Position=UDim2.new(.57,0,1,-20)
   actions.Size=UDim2.new(.43,-24,0,actionHeight)
  end
		if catalogOnly and owned then
			local collected = label(actions, text("Предмет в инвентаре", "In your inventory", "已在背包中"), UDim2.new(), UDim2.fromScale(1, 1), 17, C.Muted, true)
			collected.Name = "CatalogOwnedStatus"
			collected.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		if not owned then
			local locked = label(
				actions,
				tr("locked"),
				UDim2.new(),
				UDim2.fromScale(1, 1),
				17,
				C.Muted,
				true
			)

			locked.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
  if confirming then
   content.Visible=false
   preview.Visible=false
   actions.AnchorPoint=Vector2.new(0,0)
   actions.Position=UDim2.fromOffset(12,top+(short and 8 or 12))
   actions.Size=UDim2.new(1,-24,1,-(top+(short and 20 or 24)))
   local copies=(profile.itemCounts or {})[item.id]or 1
   local text=(ctx.language()=="en"and"Sell one copy for "or"Продать одну копию за ")..tostring(sale.offer)..(ctx.language()=="en"and" coins?"or" монет?")
   if copies==1 and equipped then text..=ctx.language()=="en"and"\nThis is your last copy. It will be unequipped."or"\nЭто последняя копия. Предмет будет снят."end
   local explanation=scrolling(actions,"SaleExplanation",UDim2.new(),UDim2.new(1,0,1,-52),false)
   local warning=label(explanation,text,UDim2.new(),UDim2.new(1,-8,0,short and 48 or 96),short and 16 or 22,C.Cream,true)
   warning.AutomaticSize=Enum.AutomaticSize.Y
   warning.TextYAlignment=Enum.TextYAlignment.Top
   local cancel=button(actions,ctx.language()=="en"and"CANCEL"or"ОТМЕНА",UDim2.new(0,0,1,-44),UDim2.new(.5,-4,0,44),false,function()self.saleItemId=nil;self:render()end)
   cancel.Name="CancelInventorySale";cancel.TextSize=15
   local confirm=button(actions,ctx.language()=="en"and"SELL"or"ПРОДАТЬ",UDim2.new(.5,4,1,-44),UDim2.new(.5,-4,0,44),not ctx.pending(),function()
    local latest=ctx.profile()or{}
    if self.filter=="collection"or ctx.pending()or latest.ready~=true or (latest.owned or{})[item.id]~=true then return end
    self.saleItemId=nil;ctx.request("sell",item.id);self:render()
   end)
   confirm.Name="ConfirmInventorySale";confirm.TextSize=15;confirm.Active=not ctx.pending();confirm.Selectable=not ctx.pending()
   return
  end
  if canSell then
   local pos,size=UDim2.new(0,0,1,-100),UDim2.new(1,0,0,40)
   if short then pos,size=shortAction(canPerform and 1 or 0)end
   local caption=(ctx.language()=="en"and(short and "Sell · "or"Sell · ")or(short and "Продать · "or"Продать · "))..tostring(sale.offer)
   local sell=button(actions,caption,pos,size,false,function()
    if self.filter~="collection"and not ctx.pending()then self.saleItemId=item.id;self:render()end
   end)
   sell.Name="SellInventoryItem";sell.TextSize=short and 13 or 16;sell.Active=not ctx.pending();sell.Selectable=not ctx.pending()
  end

		if canPerform then
   local pos,size=UDim2.new(),UDim2.new(1,0,0,48)
   if short then pos,size=shortAction(0)end
			local play=button(
				actions,
				tr("play"),
				pos,
				size,
				false,
				function()
					local latest = ctx.profile() or {}

					if self.filter ~= "collection" and not ctx.pending()
						and (latest.equipped or {})[itemSlot(item)] == item.id
						and ctx.emote
					then
						ctx.emote()
					end
				end
			)
   play.Name="PerformInventoryEmote";if short then play.TextSize=13 end
		end

		local disabled = self.filter == "collection" or ctx.pending()
			or (item.kind == "gadget" and quantity <= 0)

		local caption = ctx.pending() and tr("loading")
			or (item.kind == "gadget" and tr("use"))
			or (equipped and tr("unequip"))
			or tr("equip")

  local pos,size=UDim2.new(0,0,1,-52),UDim2.new(1,0,0,52)
  if short then pos,size=shortAction(columns-1)end
		local action = button(
			actions,
			caption,
			pos,
			size,
			not disabled and not equipped,
			function()
				useItem(item)
			end
		)
  action.Name="EquipInventoryItem";if short then action.TextSize=14 end

		action.Selectable = not disabled
		action.Active = not disabled

		if disabled then
			action.TextColor3 = C.Muted
		end
	end

	local function buildCollection(parent, entries, isSets, compact)
		if #entries == 0 then
			if self.query ~= "" or self.slot ~= "all" or self.tier ~= "all" or self.style ~= "all" or self.duplicates then
				local hint = label(parent, text("Ничего не найдено", "No items found", "没有找到物品"), UDim2.fromOffset(8, 0), UDim2.new(1, -112, 0, 44), 16, C.Muted, true)
				hint.Name = "InventoryNoResults"
				local reset = button(parent, text("Сбросить", "Reset", "重置"), UDim2.new(1, -100, 0, 0), UDim2.fromOffset(100, 44), false, function()
					if currentSearch then currentSearch.Text="" end
					self.query = ""; self.slot = "all"; self.tier = "all"; self.style = "all"; self.duplicates = false
					scrollPosition = Vector2.new(); currentScroll = nil; tabsPosition = Vector2.new(); currentTabs = nil
					self:render()
				end)
				reset.Name = "ResetInventorySearch"; reset.TextSize = 14
				return
			end
			emptyState(parent, false)
			return
		end

		currentScroll = scrolling(
			parent,
			"Collection",
			UDim2.new(),
			UDim2.fromScale(1, 1),
			false
		)

		make("UIPadding", currentScroll, {
			PaddingLeft = UDim.new(0, 3),
			PaddingTop = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		})

		local available = math.max(1,self.layoutWidth-46)
		local columns = math.max(1, math.floor((available + 12) / (compact and 166 or 200)))
		local cellWidth = math.floor((available - (columns - 1) * 12) / columns)
		local previewSide=math.max(40,cellWidth-24)
		local nameHeight=compact and 32 or 36
		local cardHeight=previewSide+(isSets and 78 or nameHeight+94)

		make("UIGridLayout", currentScroll, {
			CellSize = UDim2.fromOffset(cellWidth, cardHeight),
			CellPadding = UDim2.fromOffset(12, 12),
			FillDirectionMaxCells = columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})

		local profile = ctx.profile() or {}

		for index, entry in ipairs(entries) do
			local item = isSets and Catalog.ById[entry.reward] or entry
			local selected = isSets
				and self.selectedSet == entry.id
				or (not isSets and self.selectedItem == entry.id)

			local function inspect()
				rememberScroll()
				self.saleItemId = nil
				if isSets then self.selectedSet = entry.id else self.selectedItem = entry.id end
				detailOpen = true
				self:render()
			end
			local card = button(
				currentScroll,
				"",
				UDim2.new(),
				UDim2.fromOffset(cellWidth, cardHeight),
				false,
				function()
					if isSets then inspect() else useItem(entry) end
				end
			)

			card.Name = (isSets and "Set_" or "Item_") .. entry.id
			card.LayoutOrder = index
   card.BackgroundTransparency=.24
   round(card,16)
   if item then
    make("Frame",card,{Name="RarityRail",Size=UDim2.new(1,-2,0,3),Position=UDim2.fromOffset(1,1),BackgroundColor3=RARITY[item.rarity]or C.Muted,BorderSizePixel=0})
   end

			outline(
				card,
				selected and C.Cream or C.Border,
				selected and 2 or 1,
				selected and 0 or 0.5
			)

			local preview = make("Frame", card, {
				Name = "Preview",
				Position = UDim2.new(.5,0,0,10),
				Size = UDim2.fromOffset(previewSide,previewSide),
    AnchorPoint=Vector2.new(.5,0),
				BackgroundColor3 = C.Preview,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			})

			round(preview, 6)

			if item then
				if not isSets and entry.wearable and (entry.wearable.assetId or entry.wearable.shirtId) then
     make("ImageLabel",preview,{Name="CatalogThumbnail",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,Image="rbxthumb://type=Asset&id="..tostring(entry.wearable.assetId or entry.wearable.shirtId).."&w=420&h=420"})
				else
					if isSets then Art.draw(preview,item) else Preview3D.mount(preview,item,nil,{motion=false}) end
				end
			end

			local copies = not isSets and entry.kind ~= "gadget" and ((profile.itemCounts or {})[entry.id] or 1) or 1
			if copies > 1 then
				local count = label(card, "×" .. copies, UDim2.new(1, -58, 0, 14), UDim2.fromOffset(40, 22), 13, C.Cream)
				count.Name = "InventoryCopyCount"
				count.BackgroundColor3 = C.Ink
				count.BackgroundTransparency = .12
				count.TextXAlignment = Enum.TextXAlignment.Center
				round(count, 4)
			end

			local name = isSets
				and ctx.L(entry.nameKey)
				or CatalogUI.itemName(ctx, entry)

			local itemName = label(
				card,
				name,
				UDim2.fromOffset(12, previewSide+18),
				UDim2.new(1, -24, 0, nameHeight),
				compact and 14 or 16,
				C.Cream
			)
   itemName.Name="ItemName"
   itemName.TextWrapped=true
   itemName.TextTruncate=Enum.TextTruncate.AtEnd

			local caption
			local captionColor = C.Muted

			if isSets then
				local count = 0

				for _, id in ipairs(entry.items) do
					if (profile.owned or {})[id] then
						count = count + 1
					end
				end

				caption = tr("progress", count, #entry.items)
				captionColor = count == #entry.items and C.Green or C.Muted
			else
				local equipped = (profile.equipped or {})[itemSlot(entry)] == entry.id

				local tier=Catalog.Rarities[entry.rarity]
    caption=ctx.language()=="en"and tier.en or tier.ru
    if equipped then caption="✓ "..caption end
				captionColor = equipped and C.Green
					or (entry.kind=="title" and entry.titleColor and Color3.fromRGB(entry.titleColor[1],entry.titleColor[2],entry.titleColor[3]))
					or RARITY[entry.rarity]
					or C.Muted
			end

			local rarityLabel=label(
				card,
				caption,
				UDim2.fromOffset(12,previewSide+nameHeight+20),
				UDim2.new(1, -24, 0, 20),
				isSets and 13 or (compact and 12 or 14),
				captionColor
			)
   rarityLabel.Name="ItemRarity"
   if not isSets then
    local owned = (profile.owned or {})[entry.id] == true
    local equipped = (profile.equipped or {})[itemSlot(entry)] == entry.id
    local disabled = self.filter == "collection" or not owned or ctx.pending() or (entry.kind == "gadget" and ((profile.quantities or {})[entry.id] or 0) <= 0)
    local caption = not owned and text("Не получен", "Unowned", "未获得")
     or self.filter == "collection" and tr("equipped")
     or ctx.pending() and tr("loading")
     or entry.kind == "gadget" and tr("use")
     or equipped and tr("unequip") or tr("equip")
    if self.filter == "collection" and owned and not equipped then caption = text("Получен", "Owned", "已获得") end
    local action = button(card, caption, UDim2.new(0, 8, 1, -52), UDim2.new(1, -78, 0, 44), not disabled and not equipped, function() useItem(entry) end)
    action.Name = "EquipCard_" .. entry.id; action.TextSize = compact and 12 or 13
    action.TextWrapped = false; action.Active = not disabled; action.Selectable = not disabled
    if disabled then action.TextColor3 = C.Muted end
    local details = button(card, text("О вещи", "Info", "详情"), UDim2.new(1, -64, 1, -52), UDim2.fromOffset(56, 44), false, inspect)
    details.Name = "Details_" .. entry.id; details.TextSize = 12; details.TextWrapped = false
    local value=Catalog.valueFor(entry)
    local price=label(card,value>0 and ((ctx.language()=="en"and"Value "or"Ценность ")..tostring(value))or(ctx.language()=="en"and"Collection reward"or"Награда коллекции"),UDim2.new(0,12,1,-30),UDim2.new(1,-24,0,20),12,C.Cream,true)
    price.Name="ItemAppraisal";price.Visible=false
    if not(profile.owned or{})[entry.id]then preview.BackgroundTransparency=.5;price.Text=ctx.language()=="en"and"Not collected"or"Не получен";price.TextColor3=C.Muted end
   end

			if entrance and index <= 12 then
				local scale = card:FindFirstChildOfClass("UIScale")
				local token = generation
				scale.Scale = 0.96

				task.delay((index - 1) * 0.025, function()
					if token == generation and card.Parent and self.visible then
						tween(scale, 0.25, { Scale = 1 })
					end
				end)
			end
		end

		local token = generation
		local target = currentScroll

		task.defer(function()
			if token == generation and target.Parent then
				target.CanvasPosition = scrollPosition
			end
		end)
	end

	function self:render()
        local restoreFocus=searchFocused and currentSearch and currentSearch.Parent and not detailOpen
        local oldSearch=currentSearch
        local cursor,selection
        if restoreFocus then
            self.query=currentSearch.Text
            pcall(function()cursor=currentSearch.CursorPosition;selection=currentSearch.SelectionStart end)
        end
        searchFocused=false;searchRefreshKey=nil
		rememberScroll()
		stopAnimations()
		searchRevision += 1
		currentSearch = nil
		refreshBrowser = nil
		local trade = self.modal:FindFirstChild("OpenInventoryTrade")
		if trade then trade:Destroy() end
		self:clear()

		currentScroll = nil
		currentTabs = nil

		fit()

		local root = make("Frame", self.surface, {
			Name = "InventoryRoot",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		})

		local profile = ctx.profile() or {}

		if not profile.ready then
			emptyState(root, true)
			return
		end

  local isSets = self.filter == "sets" or (self.filter=="collection" and self.collectionMode=="sets")
  local entries = isSets and Catalog.Sets or ownedItems(profile)
  local selected
  for _,entry in ipairs(entries)do
   if entry.id==(isSets and self.selectedSet or self.selectedItem)then selected=entry;break end
  end
  if not selected then
   detailOpen=false;self.saleItemId=nil;self.selectedItem=nil;self.selectedSet=nil
  end
  self.categoryRailWidth=0
  local compact=self.layoutWidth<900 or (detailOpen and self.layoutHeight<560)
  local hideFilters=detailOpen
  if not hideFilters then buildTabs(root)end
  local filtersHeight=self.filtersHeight or 128
  local railWidth=self.categoryRailWidth or 0

		local body = make("Frame", root, {
			Name = "InventoryBody",
			Position = UDim2.fromOffset(railWidth, hideFilters and 0 or filtersHeight),
			Size = UDim2.new(1, -railWidth, 1, hideFilters and 0 or -filtersHeight),
			BackgroundTransparency = 1,
   Visible=hideFilters or not (self.layoutHeight<430 and self.filtersOpen),
		})

		local showDetails = selected ~= nil and detailOpen

		if not showDetails then
			local collection = make("Frame", body, {
				Name = "CollectionArea",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			})

			buildCollection(collection, entries, isSets, compact)

			-- Redraw results only while typing. The same TextBox keeps keyboard focus,
			-- selection and cursor position across debounce and empty-result states.
			refreshBrowser = function()
				if not collection.Parent or detailOpen then return end
				stopAnimations()
				collection:ClearAllChildren()
				local latest = ctx.profile() or {}
				buildCollection(collection, isSets and Catalog.Sets or ownedItems(latest), isSets, compact)
			end
		end

		if showDetails then
			local inspector = make("Frame", body, {
				Name = "Inspector",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.Surface,
				BorderSizePixel = 0,
			})

			local item = isSets
				and selected
				and Catalog.ById[selected.reward]
				or selected

			buildInspector(
				inspector,
				item,
				isSets and selected or nil,
				compact
			)
		end

        if restoreFocus and currentSearch then
            local field=currentSearch;local token=generation
            task.defer(function()
                if not self.visible or field~=currentSearch or not field.Parent or token~=generation then return end
                local focused=game:GetService("UserInputService"):GetFocusedTextBox()
                if focused and focused~=oldSearch and focused~=field then return end
                pcall(function()
                    field:CaptureFocus()
                    if type(cursor)=="number"then field.CursorPosition=cursor end
                    if type(selection)=="number"then field.SelectionStart=selection end
                end)
            end)
        end
		entrance = false
	end

	local baseUpdate = self.update
	local baseOpen = self.open
	local baseClose = self.close

	function self:update(force)
        local profile=ctx.profile()or{}
        -- A profile acknowledgement must not replace a live typing field.
        if not force and self.visible and profile.ready and not detailOpen and currentSearch and currentSearch.Parent and refreshBrowser and(searchFocused or currentSearch.Text~=self.query)then
            local query=currentSearch.Text
            local key=tostring(profile.revision)..":"..tostring(ctx.pending())..":"..query
            if key~=searchRefreshKey then
                searchRefreshKey=key;searchRevision+=1;self.query=query;self.saleItemId=nil
                rememberScroll();refreshBrowser()
            end
            return
        end
		fit()
		baseUpdate(self, force)
		fit()
	end

	function self:resize()
		rememberScroll()
		fit()
  if self.layoutHeight<430 then self.filtersOpen=false end
		self.contentKey = nil
		self:update(true)
	end

	function self:open()
		entrance = not self.visible
		baseOpen(self)
	end

	function self:close(animated)
        if searchFocused and currentSearch and currentSearch.Parent then self.query=currentSearch.Text end
        searchFocused=false;searchRefreshKey=nil
		rememberScroll()
		stopAnimations()
  searchRevision += 1
  self.saleItemId=nil
		baseClose(self, animated)
	end

	self.modal.Destroying:Connect(stopAnimations)

	return self
end

return InventoryUI
