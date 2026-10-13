local TweenService = game:GetService("TweenService")

local ModalUI = require(script.Parent.ModalUI)
local CatalogUI = require(script.Parent.CatalogUI)
local Catalog = require(script.Parent.Catalog)
local Preview3D = require(script.Parent.Preview3D)
local Art = require(script.Parent.Art)

local InventoryUI = {}

local C = {
	Background = Color3.fromRGB(27, 23, 22),
	Surface = Color3.fromRGB(35, 29, 26),
	Card = Color3.fromRGB(43, 36, 32),
	Hover = Color3.fromRGB(58, 47, 39),
	Selected = Color3.fromRGB(67, 51, 37),
	Preview = Color3.fromRGB(24, 21, 20),

	Cream = Color3.fromRGB(249, 226, 194),
	Text = Color3.fromRGB(236, 222, 203),
	Muted = Color3.fromRGB(183, 164, 143),
	Border = Color3.fromRGB(110, 89, 70),
	Gold = Color3.fromRGB(226, 184, 117),
	Ink = Color3.fromRGB(48, 32, 24),
	Green = Color3.fromRGB(160, 189, 151),
}

local FONT = Enum.Font.Oswald
local BODY = Enum.Font.BuilderSans

local COPY = {
	title = { "ИНВЕНТАРЬ", "INVENTORY" },
	all = { "ВСЁ", "ALL" },
	sets = { "НАБОРЫ", "SETS" },
	back = { "← НАЗАД", "← BACK" },
	shop = { "МАГАЗИН", "SHOP" },
	empty = { "ПОКА ПУСТО", "NOTHING HERE YET" },
	emptyHint = {
		"Предметы из наград и чемоданов появятся здесь.",
		"Items from rewards and cases will appear here.",
	},
	unavailable = {
		"ПРОФИЛЬ НЕДОСТУПЕН",
		"PROFILE UNAVAILABLE",
	},
	retry = { "ПОВТОРИТЬ", "TRY AGAIN" },
	equipped = { "ЭКИПИРОВАНО", "EQUIPPED" },
	equip = { "ЭКИПИРОВАТЬ", "EQUIP" },
	unequip = { "СНЯТЬ", "UNEQUIP" },
	use = { "ИСПОЛЬЗОВАТЬ", "USE" },
	play = { "ПРОИГРАТЬ ЭМОЦИЮ", "PLAY EMOTE" },
	loading = { "ПОДОЖДИ…", "PLEASE WAIT…" },
	quantity = { "В наличии: %d", "Available: %d" },
	copies = { "Копий в наличии: %d", "Copies owned: %d" },
	progress = { "Собрано %d из %d", "%d of %d collected" },
	reward = { "НАГРАДА ЗА НАБОР", "SET REWARD" },
	locked = {
		"Собери набор, чтобы получить награду.",
		"Complete the set to earn its reward.",
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
	legendary = Color3.fromRGB(226, 184, 117),
	mythic = Color3.fromRGB(226, 143, 155),
}

local function make(className, parent, properties)
	local object = Instance.new(className)

	for key, value in pairs(properties or {}) do
		object[key] = value
	end

	object.Parent = parent
	return object
end

local function round(parent, radius)
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

	local function tr(key, ...)
		local index = ctx.language() == "en" and 2 or 1
		return string.format(COPY[key][index], ...)
	end

	local SLOT_NAMES = {
		hat = { "ШЛЯПЫ", "HATS" },
		glasses = { "ОЧКИ", "GLASSES" },
		tie = { "ГАЛСТУКИ", "TIES" },
		outfit = { "КОСТЮМЫ", "OUTFITS" },
		gloves = { "ПЕРЧАТКИ", "GLOVES" },
		shoulder = { "КОБУРА", "HOLSTER" },
	}

	local function itemSlot(item)
		return item.equipSlot or item.kind
	end

	local function slotName(key)
		local value = SLOT_NAMES[key]
		if value then return value[ctx.language() == "en" and 2 or 1] end
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

		if currentTabs and currentTabs.Parent then
			tabsPosition = currentTabs.CanvasPosition
		end
	end

	local function fit()
		local viewport = ctx.gui.AbsoluteSize
		local width = math.max(1, math.min(1120, viewport.X - 24))
		local height = math.max(1, math.min(760, viewport.Y - 32))

		self.layoutWidth = width
		self.modal.Size = UDim2.fromOffset(width, height)
		self.modal.BackgroundColor3 = C.Background
		self.modal.BackgroundTransparency = 0
		self.modal.ClipsDescendants = true
		self.modal.Active = true

		round(self.modal, 12)

		local border = self.modal:FindFirstChildOfClass("UIStroke")

		if border then
			border.Color = C.Border
			border.Thickness = 1
			border.Transparency = 0.2
		end

		self.title.Text = tr("title")
		self.title.Font = FONT
		self.title.TextScaled = false
		self.title.TextSize = width < 600 and 28 or 34
		self.title.TextColor3 = C.Cream
		self.title.Position = UDim2.fromOffset(20, 12)
		self.title.Size = UDim2.new(1, -88, 0, 44)

		self.hint.Visible = false

		self.surface.Position = UDim2.fromOffset(16, 70)
		self.surface.Size = UDim2.new(1, -32, 1, -86)
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
		local result = {}

		for _, item in ipairs(Catalog.Items) do
			if (profile.owned or {})[item.id]
				and (self.filter == "all" or itemSlot(item) == self.filter or item.kind == self.filter)
			then
				table.insert(result, item)
			end
		end

		return result
	end

	local function useItem(item)
		local profile = ctx.profile() or {}

		if ctx.pending()
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

		ctx.request(
			"equip",
			equipped and ("clear:" .. itemSlot(item)) or item.id
		)
	end

	local function buildTabs(parent)
		currentTabs = scrolling(
			parent,
			"Categories",
			UDim2.new(),
			UDim2.new(1, 0, 0, 54),
			true
		)

		make("UIListLayout", currentTabs, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})

		local categories = { "all", "sets" }
		local seen = { all = true, sets = true }

		for _, slot in ipairs(Catalog.Slots) do
			if not seen[slot] then
				seen[slot] = true
				table.insert(categories, slot)
			end
		end

		for order, key in ipairs(categories) do
			local active = self.filter == key

			local tab = button(
				currentTabs,
				categoryName(key),
				UDim2.new(),
				UDim2.fromOffset(0, 44),
				active,
				function()
					if self.filter == key then
						return
					end

					rememberScroll()
					self.filter = key
					self.selectedItem = nil
					self.selectedSet = nil
					detailOpen = false
					scrollPosition = Vector2.new()
					currentScroll = nil
					self:render()
				end
			)

			tab.LayoutOrder = order
			tab.AutomaticSize = Enum.AutomaticSize.X
			tab.TextWrapped = false
			tab.TextSize = 20

			make("UIPadding", tab, {
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
			})
		end

		currentTabs.CanvasPosition = tabsPosition
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
		round(parent, 9)
		outline(parent, C.Border, 1, 0.45)

		local top = compact and 52 or 0

		if compact then
			button(
				parent,
				tr("back"),
				UDim2.fromOffset(10, 8),
				UDim2.new(1, -20, 0, 40),
				false,
				function()
					detailOpen = false
					self:render()
				end
			)
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

		local canPerform = owned
			and item.kind == "emote"
			and equipped

		local actionHeight = canPerform and 110 or 56

		local content = scrolling(
			parent,
			"ItemDetails",
			UDim2.fromOffset(12, top + 12),
			UDim2.new(1, -24, 1, -(top + actionHeight + 34)),
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
			Size = UDim2.new(1, 0, 0, compact and 190 or 220),
			BackgroundColor3 = C.Preview,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})

		round(preview, 8)
		Preview3D.mount(preview, item, nil)

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
			RARITY[item.rarity] or C.Muted,
			3,
			28,
			true
		)

		if setData then
			local count = 0

			for _, id in ipairs(setData.items) do
				if (profile.owned or {})[id] then
					count = count + 1
				end
			end

			line(tr("reward"), 20, C.Gold, 4)
			line(ctx.L(setData.nameKey), 23, C.Text, 5)
			line(
				tr("progress", count, #setData.items),
				18,
				C.Muted,
				6,
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
						7 + index,
						28,
						true
					)
				end
			end
		elseif item.kind == "gadget" then
			line(tr("quantity", quantity), 18, C.Muted, 4, 28, true)
		elseif equipped then
			line(tr("equipped"), 20, C.Green, 4)
		end

		if owned and not setData and item.kind ~= "gadget" then
			local copies = (profile.itemCounts or {})[item.id] or 1
			local count = line(tr("copies", copies), 17, C.Muted, 20, 28, true)
			count.Name = "OwnedCopyCount"
		end

		local actions = make("Frame", parent, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			Size = UDim2.new(1, -24, 0, actionHeight),
			BackgroundTransparency = 1,
		})

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

		if canPerform then
			button(
				actions,
				tr("play"),
				UDim2.new(),
				UDim2.new(1, 0, 0, 48),
				false,
				function()
					local latest = ctx.profile() or {}

					if not ctx.pending()
						and (latest.equipped or {})[itemSlot(item)] == item.id
						and ctx.emote
					then
						ctx.emote()
					end
				end
			)
		end

		local disabled = ctx.pending()
			or (item.kind == "gadget" and quantity <= 0)

		local caption = ctx.pending() and tr("loading")
			or (item.kind == "gadget" and tr("use"))
			or (equipped and tr("unequip"))
			or tr("equip")

		local action = button(
			actions,
			caption,
			UDim2.new(0, 0, 1, -52),
			UDim2.new(1, 0, 0, 52),
			not disabled and not equipped,
			function()
				useItem(item)
			end
		)

		action.Selectable = not disabled

		if disabled then
			action.TextColor3 = C.Muted
		end
	end

	local function buildCollection(parent, entries, isSets, compact)
		if #entries == 0 then
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

		local available = math.max(1, parent.AbsoluteSize.X - 14)
		local columns = math.max(1, math.floor((available + 10) / 174))
		local cellWidth = math.floor((available - (columns - 1) * 10) / columns)
		local cardHeight = isSets and 184 or 204

		make("UIGridLayout", currentScroll, {
			CellSize = UDim2.fromOffset(cellWidth, cardHeight),
			CellPadding = UDim2.fromOffset(10, 10),
			FillDirectionMaxCells = columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})

		local profile = ctx.profile() or {}

		for index, entry in ipairs(entries) do
			local item = isSets and Catalog.ById[entry.reward] or entry
			local selected = isSets
				and self.selectedSet == entry.id
				or (not isSets and self.selectedItem == entry.id)

			local card = button(
				currentScroll,
				"",
				UDim2.new(),
				UDim2.fromOffset(cellWidth, cardHeight),
				false,
				function()
					rememberScroll()

					if isSets then
						self.selectedSet = entry.id
					else
						self.selectedItem = entry.id
					end

					detailOpen = compact
					self:render()
				end
			)

			card.Name = (isSets and "Set_" or "Item_") .. entry.id
			card.LayoutOrder = index

			outline(
				card,
				selected and C.Cream or C.Border,
				selected and 2 or 1,
				selected and 0 or 0.5
			)

			local preview = make("Frame", card, {
				Name = "Preview",
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.new(1, -20, 0, isSets and 86 or 108),
				BackgroundColor3 = C.Preview,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			})

			round(preview, 6)

			if item then
				Art.draw(preview, item)
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

			label(
				card,
				name,
				UDim2.fromOffset(12, isSets and 103 or 124),
				UDim2.new(1, -24, 0, 46),
				21,
				C.Cream
			)

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

				caption = equipped and tr("equipped") or ctx.L(entry.rarity)
				captionColor = equipped and C.Green
					or RARITY[entry.rarity]
					or C.Muted
			end

			label(
				card,
				caption,
				UDim2.new(0, 12, 1, -32),
				UDim2.new(1, -24, 0, 26),
				16,
				captionColor
			)

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
		rememberScroll()
		stopAnimations()
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

		buildTabs(root)

		local body = make("Frame", root, {
			Name = "InventoryBody",
			Position = UDim2.fromOffset(0, 64),
			Size = UDim2.new(1, 0, 1, -64),
			BackgroundTransparency = 1,
		})

		local compact = self.layoutWidth < 800
		local isSets = self.filter == "sets"
		local entries = isSets and Catalog.Sets or ownedItems(profile)
		local selected

		for _, entry in ipairs(entries) do
			if entry.id == (isSets and self.selectedSet or self.selectedItem) then
				selected = entry
				break
			end
		end

		selected = selected or entries[1]

		if selected then
			if isSets then
				self.selectedSet = selected.id
			else
				self.selectedItem = selected.id
			end
		else
			detailOpen = false
		end

		local showDetails = #entries > 0 and (not compact or detailOpen)

		if not compact or not detailOpen then
			local collection = make("Frame", body, {
				Name = "CollectionArea",
				Size = UDim2.new(1, showDetails and -314 or 0, 1, 0),
				BackgroundTransparency = 1,
			})

			buildCollection(collection, entries, isSets, compact)
		end

		if showDetails then
			local inspector = make("Frame", body, {
				Name = "Inspector",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = compact
					and UDim2.fromScale(1, 1)
					or UDim2.new(0, 300, 1, 0),
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

		entrance = false
	end

	local baseUpdate = self.update
	local baseOpen = self.open
	local baseClose = self.close

	function self:update(force)
		fit()
		baseUpdate(self, force)
		fit()
	end

	function self:resize()
		rememberScroll()
		fit()
		self.contentKey = nil
		self:update(true)
	end

	function self:open()
		entrance = not self.visible
		baseOpen(self)
	end

	function self:close(animated)
		rememberScroll()
		stopAnimations()
		baseClose(self, animated)
	end

	self.modal.Destroying:Connect(stopAnimations)

	return self
end

return InventoryUI
