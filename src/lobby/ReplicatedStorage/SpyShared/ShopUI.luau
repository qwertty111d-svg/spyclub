-- SPY CLUB PREMIUM SHOP V1 :: ShopUI
--[[
    ReplicatedStorage > SpyShared > ShopUI
    Appearance opens category Rolls; Club keeps deterministic coin purchases.
    Premium Game Passes and Developer Products retain their payment flow.
    Existing case stand callers route to AccessoryRollUI.
    Marketplace preview offers remain Studio-only.
]]

local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Catalog = require(script.Parent.Catalog)
local CatalogUI = require(script.Parent.CatalogUI)
local ModalUI = require(script.Parent.ModalUI)
local Preview3D = require(script.Parent.Preview3D)
local Art = require(script.Parent.Art)

local ShopUI = {}
local themeNode=script.Parent:FindFirstChild("UITheme")
local Theme=themeNode and require(themeNode)

---------------------------------------------------------------------
-- TYPE
---------------------------------------------------------------------

local FONT = {
	Display = Enum.Font.BuilderSansBold,
	Strong = Enum.Font.BuilderSansBold,
	Body = Enum.Font.BuilderSansMedium,
	Meta = Enum.Font.BuilderSansMedium,
}

---------------------------------------------------------------------
-- COLOR
---------------------------------------------------------------------

local C = {
	Modal = Color3.fromRGB(25,27,31),

	Surface = Color3.fromRGB(34,36,40),
	SurfaceRaised = Color3.fromRGB(46,48,52),

	Deep = Color3.fromRGB(26,28,32),

	Hover = Color3.fromRGB(57,59,63),
	Pressed = Color3.fromRGB(34,36,40),

	Line = Color3.fromRGB(87,89,93),
	LineSoft = Color3.fromRGB(46,48,52),

	Ivory = Color3.fromRGB(244,240,231),
	Text = Color3.fromRGB(244,240,231),
	Muted = Color3.fromRGB(188,187,181),
	Dim = Color3.fromRGB(154,153,149),

	Champagne = Color3.fromRGB(221,193,151),
	ChampagneHover = Color3.fromRGB(235,210,174),
	ChampagnePressed = Color3.fromRGB(201,174,133),

	ChampagneDark = Color3.fromRGB(26,28,32),

	Owned = Color3.fromRGB(160, 189, 151),
}

---------------------------------------------------------------------
-- MOTION
---------------------------------------------------------------------

local MOTION = {
	Hover = TweenInfo.new(
		0.18,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Press = TweenInfo.new(
		0.10,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	),

	Release = TweenInfo.new(
		0.22,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),
}

---------------------------------------------------------------------
-- STUDIO PREVIEW
---------------------------------------------------------------------

local STUDIO_OFFERS = {
	{preview=true,id=-1001,kind="pass",key="black_tie_collection",category="collection",ids={"founder_suit","closed_club_fedora","interrogation_glasses","founder_tie","inner_circle_frame","club_founder"},ru="BLACK TIE COLLECTION",en="BLACK TIE COLLECTION",descriptionRu="Шесть постоянных предметов закрытого клуба. Только внешний вид — без преимущества в матче.",descriptionEn="Six permanent private-club cosmetics. Style only, with no gameplay advantage.",price=399},
	{preview=true,id=-1002,kind="pass",key="case_luck_2x",category="boosts",ids={},ru="УДАЧА КЕЙСОВ ×2",en="CASE LUCK ×2",descriptionRu="Два серверных выбора за один Roll. Сохраняется более редкий результат.",descriptionEn="Two server draws for one Roll. The rarer result is kept.",price=299},
	{preview=true,id=-1003,kind="product",key="level_plus_one",category="boosts",ids={},ru="+1 УРОВЕНЬ",en="+1 LEVEL",descriptionRu="Сразу добавляет 100 опыта к текущему профилю.",descriptionEn="Adds 100 XP to your current profile.",price=49},
	{preview=true,id=-1004,kind="product",key="coins_500",category="coins",ids={},ru="500 МОНЕТ",en="500 COINS",descriptionRu="Монеты поступят в существующий баланс.",descriptionEn="Coins go to your existing balance.",price=49},
	{preview=true,id=-1005,kind="product",key="coins_1600",category="coins",ids={},ru="1 600 МОНЕТ",en="1,600 COINS",descriptionRu="Выбор клуба для пополнения баланса.",descriptionEn="The club choice for topping up your balance.",price=129},
	{preview=true,id=-1006,kind="product",key="coins_5000",category="coins",ids={},ru="5 000 МОНЕТ",en="5,000 COINS",descriptionRu="Большой запас для коллекции клуба.",descriptionEn="A large reserve for your club collection.",price=299},
}

---------------------------------------------------------------------
-- CREATION HELPERS
---------------------------------------------------------------------

local function tween(object, info, properties)
	if not object or not object.Parent then
		return
	end

	local animation =
		TweenService:Create(
			object,
			info,
			properties
		)

	animation:Play()

	return animation
end

local function make(className, parent, properties)
	local object =
		Instance.new(className)

	for key, value in pairs(
		properties or {}
		) do
		object[key] = value
	end

	object.Parent = parent

	return object
end

local function frame(parent, name)
	return make(
		"Frame",
		parent,
		{
			Name = name or "Frame",
			BorderSizePixel = 0,
		}
	)
end

local function button(parent, name)
	return make(
		"TextButton",
		parent,
		{
			Name = name or "Button",

			Text = "",

			AutoButtonColor = false,

			BorderSizePixel = 0,
		}
	)
end

local function label(
	parent,
	value,
	font,
	textSize,
	color
)
	return make(
		"TextLabel",
		parent,
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Text = value or "",

			Font = font or FONT.Body,
			TextSize = textSize or 13,

			TextColor3 =
				color or C.Text,

			TextXAlignment =
				Enum.TextXAlignment.Left,

			TextYAlignment =
				Enum.TextYAlignment.Center,

			TextWrapped = false,

			TextTruncate =
				Enum.TextTruncate.AtEnd,
		}
	)
end

local function corner(parent, radius)
 radius=math.max(radius or 12,12)
	return make(
		"UICorner",
		parent,
		{
			CornerRadius =
				UDim.new(0, radius),
		}
	)
end

local function stroke(
	parent,
	color,
	transparency,
	thickness
)
	return make(
		"UIStroke",
		parent,
		{
			Color = color,

			Transparency =
				transparency or 0,

			Thickness =
				thickness or 1,

			ApplyStrokeMode =
				Enum.ApplyStrokeMode.Border,
		}
	)
end

local function addScale(parent)
	return make(
		"UIScale",
		parent,
		{
			Scale = 1,
		}
	)
end

---------------------------------------------------------------------
-- LANGUAGE
---------------------------------------------------------------------

local function isEnglish(ctx)
	return ctx.language
		and ctx.language() == "en"
end

local function utilityText(ctx,item)
	if not item then return "" end
	local value=isEnglish(ctx) and item.useEn or item.useRu
	if value and value~="" then return value end
	local slot=item.equipSlot or item.kind
	local fallback={
		card={"Секретное досье и карта на столе","Secret dossier and table card"},
		frame={"Досье, табличка над головой и состав клуба","Dossier, overhead tag and club roster"},
		title={"Табличка над головой и состав клуба","Overhead tag and club roster"},
		effect={"Персонаж и финал матча","Character aura and match result"},
		trinket={"Предмет на игровом столе","Physical table prop"},
	}
	local pair=fallback[slot]
	return pair and pair[isEnglish(ctx) and 2 or 1] or (isEnglish(ctx) and "Equipped on your character" or "Надевается на персонажа")
end

---------------------------------------------------------------------
-- BUTTON JUICE
---------------------------------------------------------------------

local function motion(
	target,
	normalColor,
	hoverColor,
	pressedColor,
	hoverScale
)
	local scale =
		addScale(target)

	hoverScale =
		hoverScale or 1.01

	local hovering = false
	local pressed = false

	target.MouseEnter:Connect(function()
		hovering = true

		if pressed then
			return
		end

		tween(
			target,
			MOTION.Hover,
			{
				BackgroundColor3 =
					hoverColor,
			}
		)

		tween(
			scale,
			MOTION.Hover,
			{
				Scale = hoverScale,
			}
		)
	end)

	target.MouseLeave:Connect(function()
		hovering = false

		if pressed then
			return
		end

		tween(
			target,
			MOTION.Hover,
			{
				BackgroundColor3 =
					normalColor,
			}
		)

		tween(
			scale,
			MOTION.Release,
			{
				Scale = 1,
			}
		)
	end)

	target.MouseButton1Down:Connect(function()
		pressed = true

		tween(
			target,
			MOTION.Press,
			{
				BackgroundColor3 =
					pressedColor,
			}
		)

		tween(
			scale,
			MOTION.Press,
			{
				Scale = 0.965,
			}
		)
	end)

	target.MouseButton1Up:Connect(function()
		pressed = false

		local resting =
			hovering
			and hoverScale
			or 1

		tween(
			target,
			MOTION.Release,
			{
				BackgroundColor3 =
					hovering
					and hoverColor
					or normalColor,
			}
		)

		tween(
			scale,
			TweenInfo.new(
				0.10,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{
				Scale =
					resting + 0.012,
			}
		)

		task.delay(0.065, function()
			if scale.Parent then
				tween(
					scale,
					MOTION.Release,
					{
						Scale = resting,
					}
				)
			end
		end)
	end)

	return scale
end

---------------------------------------------------------------------
-- MODAL CLEANUP
---------------------------------------------------------------------

local function cleanSurface(surface)
	for _, child in ipairs(
		surface:GetChildren()
		) do
		if child:IsA("UIListLayout")
			or child:IsA("UIGridLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end

	surface.CanvasSize =
		UDim2.new()

	surface.AutomaticCanvasSize =
		Enum.AutomaticSize.None

	surface.ScrollingEnabled =
		false

	surface.ScrollBarThickness = 0
end

local function disableBackdrop(self)
	local overlay =
		self.modal
		and self.modal.Parent

	if not overlay then
		return
	end

	overlay.Active = true
	self.modal.Active = true

	local dismiss =
		overlay:FindFirstChild(
			"DismissBackdrop"
		)

	if dismiss
		and dismiss:IsA("GuiButton")
	then
		dismiss.Visible = false
		dismiss.Active = false
		dismiss.Selectable = false
	end
end

---------------------------------------------------------------------
-- MODAL SIZE
---------------------------------------------------------------------

-- Native UI components. Shop purchases and receipt handling stay in ShopUI.
local function uiText(parent, value, x, y, width, height, size, color, body)
	local node=label(parent,value,body and FONT.Body or FONT.Display,size,color or C.Ivory)
	node.Position=UDim2.fromOffset(x,y)
	node.Size=UDim2.new(width[1],width[2],0,height)
	node.TextScaled=false
	node.TextWrapped=true
	node.TextTruncate=Enum.TextTruncate.None
	return node
end

local function uiScroll(parent,name,pos,size,horizontal)
	return make("ScrollingFrame",parent,{
		Name=name,Position=pos,Size=size,BackgroundTransparency=1,BorderSizePixel=0,
		CanvasSize=UDim2.new(),AutomaticCanvasSize=horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		ScrollingDirection=horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		ScrollBarThickness=4,ScrollBarImageColor3=C.Champagne,ScrollBarImageTransparency=.25,
	})
end

local function uiAction(parent,name,caption,pos,size,primary,callback)
	local b=button(parent,name)
	b.Position=pos;b.Size=size;b.Text=caption;b.Font=FONT.Display;b.TextSize=23;b.TextWrapped=true
	b.BackgroundColor3=primary and C.Champagne or C.SurfaceRaised
	b.TextColor3=primary and C.ChampagneDark or C.Text
	b.Selectable=callback~=nil
	corner(b,22)
 if Theme and Theme.button then Theme.button(b,primary,{quiet=not primary}) end
	if callback then
		motion(b,b.BackgroundColor3,primary and C.ChampagneHover or C.Hover,primary and C.ChampagnePressed or C.Pressed,1)
		b.Activated:Connect(callback)
	end
	return b
end


local function resizeShop(self,ctx)
	if self.kicker then self.kicker.Visible=false end
	local v=ctx.gui.AbsoluteSize
	self.layoutWidth=math.max(1,math.min(1080,v.X-24))
	local storeHeight=(self.layoutWidth>=976 and 486 or self.layoutWidth<480 and 680 or 800)
 self.layoutHeight=math.max(1,math.min(self.mode=="store" and storeHeight or 800,v.Y-32))
	self.modal.Size=UDim2.fromOffset(self.layoutWidth,self.layoutHeight)
	self.surface.Position=UDim2.fromOffset(18,76)
	self.surface.Size=UDim2.new(1,-36,1,-94)
	self.title.Position=UDim2.fromOffset(20,12)
	self.title.Size=UDim2.new(1,-88,0,44)
	self.title.Font=FONT.Display;self.title.TextSize=self.layoutWidth<480 and 27 or 30
	self.title.TextScaled=false;self.title.TextXAlignment=Enum.TextXAlignment.Left
end


local function styleModal(
	self,
	ctx
)
	if self.kicker then self.kicker.Visible=false end
	local modal =
		self.modal

	modal.BackgroundColor3 =
		C.Modal

	modal.BackgroundTransparency =
		.16

	modal.BorderSizePixel = 0

	modal.ClipsDescendants = true

	-------------------------------------------------------------
	-- REMOVE OLD GOLD STRIP / OLD STROKES
	-------------------------------------------------------------

	for _, child in ipairs(
		modal:GetChildren()
		) do
		if child:IsA("UIStroke") then
			child:Destroy()
		end

		if child:IsA("Frame")
			and child ~= self.surface
			and child.Size.Y.Offset <= 5
		then
			child.Visible = false
		end
	end

	local oldCorner =
		modal:FindFirstChildOfClass(
			"UICorner"
		)

	if oldCorner then
		oldCorner.CornerRadius =
			UDim.new(0, 20)
	else
		corner(
			modal,
			9
		)
	end

	stroke(
		modal,
		C.Line,
		0.34,
		1
	)

	-------------------------------------------------------------
	-- TITLE
	-------------------------------------------------------------

	self.title.Position =
		UDim2.fromOffset(
			27,
			17
		)

	self.title.Size =
		UDim2.new(
			1,
			-100,
			0,
			40
		)

	self.title.Text =
		isEnglish(ctx)
		and "Detective's Shop"
		or "Лавка сыщика"

	self.title.Font =
		FONT.Display

	self.title.TextSize = 24

	self.title.TextColor3 =
		C.Ivory

	self.title.TextXAlignment =
		Enum.TextXAlignment.Left

	-------------------------------------------------------------
	-- REMOVE OLD HINT
	-------------------------------------------------------------

	self.hint.Visible = false
	self.hint.Text = ""

	-------------------------------------------------------------
	-- CLOSE
	-------------------------------------------------------------

	for _, child in ipairs(
		modal:GetChildren()
		) do
		if child:IsA("TextButton")
			and child.Text == "×"
		then
			child.Position =
				UDim2.new(
					1,
					-55,
					0,
					14
				)

			child.Size =
				UDim2.fromOffset(
					39,
					39
				)

			child.BackgroundColor3 =
				C.Surface

			child.BackgroundTransparency = 0

			child.TextColor3 =
				C.Ivory

			child.TextSize = 17
			child.Font = FONT.Strong

			local existing =
				child:FindFirstChildOfClass(
					"UICorner"
				)

			if existing then
				existing.CornerRadius =
					UDim.new(0, 6)
			else
				corner(
					child,
					6
				)
			end

			local existingStroke =
				child:FindFirstChildOfClass(
					"UIStroke"
				)

			if existingStroke then
				existingStroke.Color =
					C.Line

				existingStroke.Transparency =
					0.46
			else
				stroke(
					child,
					C.Line,
					0.46,
					1
				)
			end

			motion(
				child,
				C.Surface,
				C.Hover,
				C.Pressed,
				1.02
			)

			break
		end
	end

	cleanSurface(
		self.surface
	)

	resizeShop(
		self,
		ctx
	)

	disableBackdrop(
		self
	)
end

---------------------------------------------------------------------
-- OFFER HELPERS
---------------------------------------------------------------------

local function offerKey(offer)
	return tostring(
		offer.kind
	)
		.. ":"
		.. tostring(
			offer.id
		)
end

local function offerItems(offer)
	local result = {}

	for _, id in ipairs(
		offer.ids or {}
		) do
		local item =
			Catalog.ById[id]

		if item then
			table.insert(
				result,
				item
			)
		end
	end

	return result
end

local function validLiveOffers(ctx)
	local result = {}

	for _, offer in ipairs(
		ctx.state().monetization
			or {}
		) do
		if type(offer.id) == "number"
			and offer.id > 0
			and (
				offer.kind == "pass"
					or offer.kind == "product"
			)
		then
			table.insert(
				result,
				offer
			)
		end
	end

	return result
end

local function offersForUI(ctx)
	local real =
		validLiveOffers(ctx)

	if #real > 0 then
		return real
	end

	if RunService:IsStudio() then
		return STUDIO_OFFERS
	end

	return {}
end

---------------------------------------------------------------------
-- CATEGORY
---------------------------------------------------------------------

local CATEGORY_INFO = {
	{id="collection",ru="Коллекция",en="Collection"},
	{id="boosts",ru="Усиления",en="Boosts"},
	{id="coins",ru="Монеты",en="Coins"},
}
local function categoryOf(offer)
	if offer.category then
		return offer.category
	end

	local items =
		offerItems(offer)

	if #items > 1 then
		return "bundles"
	end

	local item =
		items[1]

	if item then
		if item.kind == "emote" then
			return "emotes"
		end

		if item.kind == "outfit"
			or item.kind == "costume"
			or item.kind == "accessory"
		then
			return "looks"
		end
	end

	return "special"
end

local function filterOffers(
	offers,
	category
)
	if category == "featured" then
		return offers
	end

	local result = {}

	for _, offer in ipairs(
		offers
		) do
		if categoryOf(offer)
			== category
		then
			table.insert(
				result,
				offer
			)
		end
	end

	return result
end

---------------------------------------------------------------------
-- PRODUCT DATA
---------------------------------------------------------------------

local function productInfo(
	self,
	offer
)
	return self.productInfo[
	offerKey(offer)
	]
end

local function productTitle(ctx,self,offer)
 local lang=ctx.language();local titles={
  black_tie_collection={"Black Tie","Black Tie","黑领带"},case_luck_2x={"Удача ×2","Luck ×2","幸运 ×2"},
  level_plus_one={"+1 уровень","+1 level","+1 等级"},coins_500={"500 монет","500 coins","500 金币"},
  coins_1600={"1 600 монет","1,600 coins","1,600 金币"},coins_5000={"5 000 монет","5,000 coins","5,000 金币"}}
 local row=titles[offer.key];if row then return row[lang=="zh"and 3 or lang=="en"and 2 or 1]end
 local translated=ctx.L and ctx.L(offer.key);if translated and translated~=offer.key then return translated end
 local supplied=lang=="zh"and offer.zh or lang=="en"and offer.en or offer.ru
 if supplied then return supplied end
 local info=productInfo(self,offer);return info and info.Name or (lang=="zh"and "商品"or lang=="en"and "Item"or "Товар")
end

local function productDescription(
	ctx,
	self,
	offer
)
	if offer.preview then
		return isEnglish(ctx)
			and offer.descriptionEn
			or offer.descriptionRu
	end

	local info =
		productInfo(
			self,
			offer
		)

	if not info
		or not info.Description
	then
		return ""
	end

	local result =
		tostring(
			info.Description
		)


	return result
end

local function productPrice(
	self,
	offer
)
	if offer.preview then
		return offer.price
	end

	local info =
		productInfo(
			self,
			offer
		)

	if info
		and type(
			info.PriceInRobux
		) == "number"
	then
		return info.PriceInRobux
	end

	return nil
end

local function isAvailable(
	self,
	offer
)
	if offer.preview then
		return true
	end

	local info =
		productInfo(
			self,
			offer
		)

	if not info
		or info.unavailable
	then
		return false
	end

	return info.IsForSale ~= false
		and type(
			info.PriceInRobux
		) == "number"
end

local function iconAsset(
	self,
	offer
)
	if offer.preview then
		return nil
	end

	local info =
		productInfo(
			self,
			offer
		)

	if not info then
		return nil
	end

	local id =
		info.IconImageAssetId

	if type(id) == "number"
		and id > 0
	then
		return
			"rbxassetid://"
			.. tostring(id)
	end

	return nil
end


local function mountMarketplaceIcon(
	self,
	parent,
	offer,
	scaleAmount
)
	local image = iconAsset(self, offer)

	if not image then
		return false
	end

	local plate = frame(parent, "MarketplaceIconPlate")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(scaleAmount or 0.76, scaleAmount or 0.76)
	plate.BackgroundColor3 = C.Deep
	plate.BackgroundTransparency = 0
	plate.ClipsDescendants = true
	corner(plate, 10)
	stroke(plate, C.Line, 0.35, 1)

	local picture = make(
		"ImageLabel",
		plate,
		{
			Name = "MarketplaceIcon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
		}
	)

	corner(picture, 9)
	return true
end

---------------------------------------------------------------------
-- FETCH MARKETPLACE INFO
---------------------------------------------------------------------

local function fetchOffer(
	self,
	offer
)
	if offer.preview then
		return
	end

	local key =
		offerKey(
			offer
		)

	if self.productInfo[key]
		or self.productLoading[key]
	then
		return
	end

	self.productLoading[key] =
		true

	task.spawn(function()
		local infoType =
			offer.kind == "pass"
			and Enum.InfoType.GamePass
			or Enum.InfoType.Product

		local ok, result =
			pcall(function()
				return MarketplaceService:
				GetProductInfoAsync(
					offer.id,
					infoType
				)
			end)

		self.productInfo[key] =
			ok
			and result
			or {
				unavailable = true,
			}

		self.productLoading[key] =
			nil

		---------------------------------------------------------
		-- OWNERSHIP
		---------------------------------------------------------

		if offer.kind == "pass"
			and not RunService:IsStudio()
		then
			local ownedOk,
			owned =
				pcall(function()
					return MarketplaceService:
					UserOwnsGamePassAsync(
						Players.LocalPlayer.UserId,
						offer.id
					)
				end)

			if ownedOk then
				self.ownership[key] =
					owned == true
			end
		end

		if self.visible then
			self.contentKey = nil
			self:render()
		end
	end)
end

---------------------------------------------------------------------
-- ITEM PREVIEW
---------------------------------------------------------------------

local function mountPreview(
	parent,
	item
)
	if not item then
		return false
	end

	local ok =
		pcall(function()
			Preview3D.mount(
				parent,
				item,
				nil,
				{
					motion = true,
				}
			)
		end)

	if ok then
		return true
	end

	pcall(function()
		Art.draw(
			parent,
			item
		)
	end)

	return false
end

local function buildOfferVisual(
	self,
	parent,
	offer
)
	local items =
		offerItems(
			offer
		)

	-------------------------------------------------------------
	-- BLACK TIE -> REAL GAME PASS ICON
	-------------------------------------------------------------

	if offer.key == "black_tie_collection" then
		if mountMarketplaceIcon(self, parent, offer, 0.78) then
			return
		end
	end

	-------------------------------------------------------------
	-- NO CATALOG ITEM -> MARKETPLACE ICON
	-------------------------------------------------------------

	if #items == 0 then
		local image =
			iconAsset(
				self,
				offer
			)

		if image then
			make(
				"ImageLabel",
				parent,
				{
					AnchorPoint =
						Vector2.new(
							0.5,
							0.5
						),

					Position =
						UDim2.fromScale(
							0.5,
							0.5
						),

					Size =
						UDim2.fromScale(
							0.66,
							0.66
						),

					BackgroundTransparency = 1,

					Image = image,

					ScaleType =
						Enum.ScaleType.Fit,
				}
			)
		end

		return
	end

	-------------------------------------------------------------
	-- SINGLE
	-------------------------------------------------------------

	if #items == 1 then
		mountPreview(
			parent,
			items[1]
		)

		return
	end

	-------------------------------------------------------------
	-- MULTI / LARGE LEFT
	-------------------------------------------------------------

	local main =
		frame(
			parent,
			"Main"
		)

	main.Size =
		UDim2.new(
			0.64,
			-5,
			1,
			0
		)

	main.BackgroundColor3 =
		C.Deep

	main.ClipsDescendants =
		true

	corner(
		main,
		5
	)

	mountPreview(
		main,
		items[1]
	)

	-------------------------------------------------------------
	-- TOP RIGHT
	-------------------------------------------------------------

	local secondary =
		frame(
			parent,
			"Secondary"
		)

	secondary.Position =
		UDim2.new(
			0.64,
			5,
			0,
			0
		)

	secondary.Size =
		UDim2.new(
			0.36,
			-5,
			0.5,
			-5
		)

	secondary.BackgroundColor3 =
		C.Deep

	secondary.ClipsDescendants =
		true

	corner(
		secondary,
		5
	)

	mountPreview(
		secondary,
		items[2]
	)

	-------------------------------------------------------------
	-- BOTTOM RIGHT
	-------------------------------------------------------------

	local tertiary =
		frame(
			parent,
			"Tertiary"
		)

	tertiary.Position =
		UDim2.new(
			0.64,
			5,
			0.5,
			5
		)

	tertiary.Size =
		UDim2.new(
			0.36,
			-5,
			0.5,
			-5
		)

	tertiary.BackgroundColor3 =
		C.Deep

	tertiary.ClipsDescendants =
		true

	corner(
		tertiary,
		5
	)

	mountPreview(
		tertiary,
		items[3] or items[2]
	)
end

---------------------------------------------------------------------
-- CATEGORY NAV
---------------------------------------------------------------------

local function languageText(ctx,ru,en,zh)
 local lang=ctx.language()
 return lang=="zh" and zh or lang=="en" and en or ru
end
local SHOP_TABS={{"accessoryRoll","Образ","Appearance","外观"},{"club","Клуб","Club","俱乐部"},{"products","Премиум","Premium","精选"},{"coins","Монеты","Coins","金币"}}
local function buildNavigation(ctx,self,parent)
 local nav=frame(parent,"ShopNavigation");nav.BackgroundColor3=C.Deep;nav.BackgroundTransparency=.28
 nav.Size=UDim2.new(1,0,0,48);corner(nav,24)
 for index,entry in ipairs(SHOP_TABS)do
  local selected=self.storeSection==entry[1]
  local b=uiAction(nav,"ShopTab_"..entry[1],languageText(ctx,entry[2],entry[3],entry[4]),
   UDim2.new((index-1)/#SHOP_TABS,3,0,2),UDim2.new(1/#SHOP_TABS,-6,0,44),false,function()
    if entry[1]=="accessoryRoll" then self:close(false);ctx.openPanel("accessoryRoll");return end
    if self.storeSection==entry[1]then return end
    self.storeSection=entry[1];self.inspectedOffer=nil;self.selectedOffer=nil;self.contentKey=nil;self:render()
   end)
  b.TextSize=16;b.TextWrapped=false;b.BackgroundColor3=selected and C.SurfaceRaised or C.Deep
  b.BackgroundTransparency=selected and 0 or 1;b.TextColor3=selected and C.Text or C.Muted
  b:SetAttribute("Selected",selected)
 end
end


local function buy(
	ctx,
	self,
	offer
)
	if offer.preview then
		if ctx.notify then
			ctx.notify(
				isEnglish(ctx)
					and "Studio preview. Add a real product ID before release."
					or "Это предпросмотр Studio. Перед релизом добавь реальный ID товара."
			)
		end

		return
	end

	local key =
		offerKey(
			offer
		)

	if offer.kind == "pass"
		and self.ownership[key]
	then
		return
	end

	if not isAvailable(
		self,
		offer
		) then
		return
	end

	self.promptActive=true
	local ok =
		pcall(function()
			if offer.kind == "pass" then
				MarketplaceService:
				PromptGamePassPurchase(
					Players.LocalPlayer,
					offer.id
				)
			else
				MarketplaceService:
				PromptProductPurchase(
					Players.LocalPlayer,
					offer.id
				)
			end
		end)

	if not ok then self.promptActive=false end
	if not ok
		and ctx.notify
	then
		ctx.notify(
			ctx.L(
				"productUnavailable"
			)
		)
	end
end

---------------------------------------------------------------------
-- HERO
---------------------------------------------------------------------

local function buildHero(ctx,self,parent,offer)
	local compact=self.layoutWidth<720
	local hero=frame(parent,"Hero")
	hero.Size=UDim2.new(1,0,0,compact and 672 or 438)
	hero.BackgroundColor3=C.Surface;corner(hero,10);stroke(hero,C.Line,.2,1)
	local visual=frame(hero,"Visual")
	visual.Position=UDim2.fromOffset(12,12)
	visual.Size=compact and UDim2.new(1,-24,0,278) or UDim2.new(.54,-18,1,-24)
	visual.BackgroundColor3=C.Deep;corner(visual,8)
	local stage=frame(visual,"PreviewStage")
	stage.Size=UDim2.new(1,0,1,-88);stage.BackgroundTransparency=1;stage.ClipsDescendants=true
	local items=offerItems(offer)
	local index=math.clamp(self.previewIndex or 1,1,math.max(1,#items))
	local caption=uiText(visual,"",12,0,{1,-24},28,18,C.Muted)
	caption.Position=UDim2.new(0,12,1,-88)
	local thumbnails=uiScroll(visual,"ItemSelector",UDim2.new(0,10,1,-58),UDim2.new(1,-20,0,52),true)
	make("UIListLayout",thumbnails,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
	local selectors={}
	local function showItem(i,animated)
		for _,child in ipairs(stage:GetChildren()) do child:Destroy() end
		self.previewIndex=i
		if offer.key == "black_tie_collection" then
			if self.inspectCollection then
				Preview3D.mountCollection(stage, items, {motion=true, avatarDescription=true})
				caption.Text = isEnglish(ctx) and "Complete collection · inspect" or "Полная коллекция · осмотр"
			else
				local mountedIcon = mountMarketplaceIcon(self, stage, offer, 0.72)
				if not mountedIcon then
					Preview3D.mountCollection(stage, items, {motion=true, avatarDescription=false})
				end
				caption.Text = "BLACK TIE COLLECTION"
			end
		elseif items[i] then
			mountPreview(stage, items[i])
			caption.Text = CatalogUI.itemName(ctx, items[i])
		else
			buildOfferVisual(self, stage, offer)
			caption.Text = isEnglish(ctx) and "Club collection" or "Клубная коллекция"
		end
		for n,b in ipairs(selectors) do
			tween(b,MOTION.Hover,{BackgroundColor3=n==i and C.Champagne or C.SurfaceRaised})
			b.TextColor3=n==i and C.ChampagneDark or C.Ivory
		end
		if animated then
			local s=addScale(stage);s.Scale=.94
			tween(s,TweenInfo.new(.28,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1})
		end
	end
	for n,item in ipairs(items) do
		local b=button(thumbnails,"PreviewItem_"..item.id)
		b.Size=UDim2.fromOffset(46,44);b.Text=tostring(n);b.Font=FONT.Display;b.TextSize=23
		b.BackgroundColor3=C.SurfaceRaised;corner(b,6)
		b.Activated:Connect(function() if self.previewIndex~=n then showItem(n,true) end end)
		b.LayoutOrder=n;selectors[n]=b
	end
	if #items<=1 or offer.key=="black_tie_collection" then
		thumbnails.Visible=false
		stage.Size=UDim2.new(1,0,1,-38)
		caption.Position=UDim2.new(0,12,1,-34)
	end
	showItem(index,self.animateHero)

	local info=frame(hero,"Information")
	info.BackgroundTransparency=1
	info.Position=compact and UDim2.fromOffset(16,302) or UDim2.new(.54,4,0,18)
	info.Size=compact and UDim2.new(1,-32,0,354) or UDim2.new(.46,-22,1,-36)
	local details=uiScroll(info,"Details",UDim2.new(),UDim2.new(1,0,1,-74),false)
	make("UIListLayout",details,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
	make("UIPadding",details,{PaddingRight=UDim.new(0,10),PaddingBottom=UDim.new(0,8)})
	local function line(value,size,color,order,body)
		local t=uiText(details,value,0,0,{1,0},size+8,size,color,body)
		t.LayoutOrder=order;t.AutomaticSize=Enum.AutomaticSize.Y
		return t
	end
	if offer.preview then line(languageText(ctx,"Тест Studio","Studio test","Studio 测试"),12,C.Muted,1)end
	line(productTitle(ctx,self,offer),compact and 24 or 28,C.Ivory,2)
	local price=productPrice(self,offer)
	if price then line(tostring(price).." ROBUX",28,C.Champagne,3) end
	local description=productDescription(ctx,self,offer)
	if description~="" then line(description,15,C.Muted,4,true) end
    if offer.key=="case_luck_2x" then
        line(languageText(ctx,"Два серверных выбора за один Roll. Сохраняется более редкий результат.","Two server draws for one Roll. The rarer result is kept.","每次抽取进行两次服务器选择，保留更稀有结果。"),14,C.Text,5,true)
        local oddsOrder=6
        for _,category in ipairs((ctx.profile().accessoryRoll or {}).categories or {}) do
            local name=ctx.language()=="en" and category.labelEn or category.labelRu
            line(name or category.id,15,C.Champagne,oddsOrder,true);oddsOrder+=1
            for _,rarity in ipairs({"common","uncommon","rare","epic","legendary","mythic"}) do
                local chance=(category.chances or {})[rarity]
                if chance and chance>0 then
                    line(ctx.L(rarity).." · "..string.format("%.2f%%",chance),13,C.Text,oddsOrder,true)
                    oddsOrder+=1
                end
            end
        end
    end
	if #items>0 then
		line(isEnglish(ctx) and "INCLUDED" or "В КОМПЛЕКТЕ",19,C.Champagne,5)
		for n,item in ipairs(items) do line("• "..CatalogUI.itemName(ctx,item),18,C.Text,5+n,true) end
	end
	local key=offerKey(offer)
	local owned=offer.kind=="pass" and self.ownership[key]
	local ready=isAvailable(self,offer) and price~=nil and not self.promptActive and not ctx.pending()
	local captionText=owned and (isEnglish(ctx) and "OWNED" or "КУПЛЕНО")
		or (offer.preview and (isEnglish(ctx) and "PREVIEW ONLY" or "ТЕСТОВЫЙ ТОВАР"))
		or ((self.productLoading[key] or self.promptActive or ctx.pending()) and ctx.L("loading"))
		or (ready and ((isEnglish(ctx) and "BUY · " or "КУПИТЬ · ")..tostring(price).." ROBUX"))
		or (isEnglish(ctx) and "UNAVAILABLE" or "НЕДОСТУПНО")
	if offer.key=="black_tie_collection" then
		-- Non-physical Black Tie rewards are shown in INCLUDED: inner_circle_frame + club_founder.
		local inspect=uiAction(info,"Inspect",languageText(ctx,"Осмотреть","Inspect","查看"),UDim2.new(0,0,1,-112),UDim2.new(1,0,0,48),false,function()
			self.inspectCollection=true;self.previewIndex=1;self.contentKey=nil;self:render()
		end)
		inspect.TextSize=20
	end
	local b=uiAction(info,"Purchase",captionText,UDim2.new(0,0,1,-56),UDim2.new(1,0,0,56),ready and not owned,
		(ready or offer.preview) and not owned and function() buy(ctx,self,offer) end or nil)
	b.TextSize=18
 if Theme and Theme.button then Theme.button(b,ready and not owned,{arrow=ready and not owned})end
	if owned then b.TextColor3=C.Owned end
	if self.animateHero then
		local s=addScale(hero);s.Scale=.98
		tween(s,TweenInfo.new(.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1})
	end
	return hero
end



local function gridColumns(width)
 return width>=940 and 4 or width>=660 and 3 or 2
end
local function newGallery(parent,name,width,height,cols,count)
 local gallery=uiScroll(parent,name,UDim2.new(),UDim2.fromScale(1,1),false)
 gallery.AutomaticCanvasSize=Enum.AutomaticSize.None
 local gap=12;local cell=math.floor((width-8-gap*(cols-1))/cols)
 gallery.CanvasSize=UDim2.fromOffset(0,math.ceil(count/cols)*(height+gap)-gap+4)
 gallery:SetAttribute("Columns",cols)
 return gallery,cell,gap
end
local function cardTitle(parent,name,value,y,size)
 local text=label(parent,value,FONT.Strong,size or 18,C.Text)
 text.Name=name;text.Position=UDim2.fromOffset(14,y);text.Size=UDim2.new(1,-28,0,28)
 text.TextWrapped=false;text.TextTruncate=Enum.TextTruncate.AtEnd
 return text
end
local function buildProductShelf(ctx,self,parent,offers)
 local width=self.layoutWidth-36;local cols=gridColumns(width);local h=width<420 and 244 or 298
 local gallery,cell,gap=newGallery(parent,"ProductGallery",width,h,cols,#offers)
 for index,offer in ipairs(offers)do
  local card=frame(gallery,"ProductCard_"..offerKey(offer));card.Position=UDim2.fromOffset((index-1)%cols*(cell+gap),math.floor((index-1)/cols)*(h+gap))
  card.Size=UDim2.fromOffset(cell,h);card.BackgroundColor3=C.Surface;card.BackgroundTransparency=.18;corner(card,20)
  local stage=frame(card,"Preview");stage.Position=UDim2.fromOffset(4,4);stage.Size=UDim2.new(1,-8,0,h-98);stage.BackgroundTransparency=1;stage.ClipsDescendants=true
  buildOfferVisual(self,stage,offer)
  cardTitle(card,"Name",productTitle(ctx,self,offer),h-94,width<420 and 15 or 19)
  local price=productPrice(self,offer)
  local value=offer.kind=="pass" and self.ownership[offerKey(offer)] and languageText(ctx,"Куплено","Owned","已拥有") or (price and tostring(price).." R$" or "—")
  local cost=label(card,value,FONT.Strong,16,C.Champagne);cost.Visible=false;cost.Position=UDim2.fromOffset(14,h-79);cost.Size=UDim2.new(1,-28,0,23)
  local view=uiAction(card,"Offer_"..offerKey(offer),languageText(ctx,"Смотреть","View","查看"),UDim2.new(0,10,1,-54),UDim2.new(1,-20,0,44),false,function()
   self.selectedOffer=offerKey(offer);self.inspectedOffer=self.selectedOffer;self.previewIndex=1;self.contentKey=nil;self:render()
  end)
  view.Text=value;view.TextSize=18
  if Theme and Theme.button then Theme.button(view,false,{arrow=width>=420})end
 end
end
-- Cards, effects, tools and legacy collectibles keep the existing coin-buy route.
local function buildCoinShelf(ctx,self,parent)
 local items={}
 for _,item in ipairs(Catalog.Items) do
  if (item.price or 0)>0 and not item.caseOnly and not item.premium then items[#items+1]=item end
 end
 local width=self.layoutWidth-36;local cols=gridColumns(width);local h=width<420 and 238 or 282
 local gallery,cell,gap=newGallery(parent,"ClubCoinGallery",width,h,cols,#items)
 local profile=ctx.profile() or {}
 for index,item in ipairs(items) do
  local card=frame(gallery,"ClubItem_"..item.id)
  card.Position=UDim2.fromOffset((index-1)%cols*(cell+gap),math.floor((index-1)/cols)*(h+gap))
  card.Size=UDim2.fromOffset(cell,h);card.BackgroundColor3=C.Surface;card.BackgroundTransparency=.18;corner(card,12)
  local stage=frame(card,"Preview");stage.Position=UDim2.fromOffset(4,4)
  stage.Size=UDim2.new(1,-8,0,h-108);stage.BackgroundTransparency=1;stage.ClipsDescendants=true
  mountPreview(stage,item)
  cardTitle(card,"Name",CatalogUI.itemName(ctx,item),h-104,width<420 and 14 or 17)
  local owned=(profile.owned or {})[item.id]==true and item.kind~="gadget"
  local ready=profile.ready==true and not owned and not ctx.pending() and (profile.coins or 0)>=item.price
  local caption=owned and languageText(ctx,"В коллекции","Owned","已拥有")
   or tostring(item.price)..languageText(ctx," монет"," coins"," 金币")
  local buyButton=uiAction(card,"Buy_"..item.id,caption,UDim2.new(0,10,1,-60),UDim2.new(1,-20,0,50),ready,
   ready and function()ctx.request("buy",item.id)end or nil)
  buyButton.TextSize=width<420 and 14 or 16
  buyButton.Active=ready
  if not ready then buyButton.TextColor3=C.Muted end
 end
end
local function renderStore(ctx,self)
 self.title.Visible=true
 self.title.Text=languageText(ctx,"Магазин","Shop","商店")
 local offers=offersForUI(ctx);for _,offer in ipairs(offers)do fetchOffer(self,offer)end
 buildNavigation(ctx,self,self.surface)
 local body=frame(self.surface,"StoreBody");body.Position=UDim2.fromOffset(0,62);body.Size=UDim2.new(1,0,1,-62);body.BackgroundTransparency=1
 if self.storeSection=="cases" or self.storeSection=="accessoryRoll" then
  self.storeSection="products";self:close(false);ctx.openPanel("accessoryRoll");return
 end
 if self.storeSection=="club" then buildCoinShelf(ctx,self,body);return end
 local selected={}
 for _,offer in ipairs(offers)do
  if (self.storeSection=="coins")== (categoryOf(offer)=="coins")then table.insert(selected,offer)end
 end
 if #selected==0 then
  local msg=label(body,languageText(ctx,"Пока нет товаров","No items yet","暂无商品"),FONT.Body,18,C.Muted);msg.Size=UDim2.fromScale(1,1);msg.TextXAlignment=Enum.TextXAlignment.Center;return
 end
 local inspected
 for _,offer in ipairs(selected)do if offerKey(offer)==self.inspectedOffer then inspected=offer end end
 if inspected then
  local back=uiAction(body,"BackToProducts",languageText(ctx,"Назад","Back","返回"),UDim2.new(),UDim2.fromOffset(100,44),false,function()
   self.inspectedOffer=nil;self.contentKey=nil;self:render()
  end);back.TextSize=15
  local details=uiScroll(body,"ProductDetails",UDim2.fromOffset(0,56),UDim2.new(1,0,1,-56),false)
  make("UIListLayout",details,{SortOrder=Enum.SortOrder.LayoutOrder})
  buildHero(ctx,self,details,inspected)
 else buildProductShelf(ctx,self,body,selected)end
end


function ShopUI.create(ctx)
	local self =
		ModalUI.create(
			ctx,
			"shop",
			"shop",
			"cosmeticHint",
			1050
		)

	self.tab = "premium"
	self.mode = "store"
 self.storeSection="products"

	self.caseId = (Catalog.CaseOrder or {})[1] or "atelier"

	self.category =
		"collection"
	self.section="collection"

	self.selectedOffer =
		nil

	self.productInfo =
		{}

	self.productLoading =
		{}

	self.ownership =
		{}

	self.caseRequestPending=false
 self.repeatRefresh=nil
 -- Legacy stand callers lead to the same cosmetic panel, never to a capsule request.
 function self:requestCaseOpen(caseId)
  self:close(false)
  ctx.openPanel("accessoryRoll",caseId=="atelier" and "hair" or nil)
  return true
 end
	self.opening = false
	self.revealSheet = nil
	self.lastConfirmedRevision=(ctx.profile() or {}).revision or 0
	self.inspectCollection=false
	self.promptActive=false
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(completedPlayer,passId,purchased)
		if completedPlayer~=Players.LocalPlayer then return end
		self.promptActive=false
		if purchased then
			task.spawn(function()
				if RunService:IsStudio() then
					-- Studio does not persist real Game Pass ownership. The server
					-- simulates it for this play session, so mirror that state in UI.
					self.ownership["pass:"..tostring(passId)] = true
				else
					local ok,owns=pcall(MarketplaceService.UserOwnsGamePassAsync,MarketplaceService,Players.LocalPlayer.UserId,passId)
					if ok and owns then self.ownership["pass:"..tostring(passId)]=true end
				end
				self.contentKey=nil;if self.visible then self:render() end
			end)
		elseif self.visible then self.contentKey=nil;self:render() end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId,_,_)
		if userId~=Players.LocalPlayer.UserId then return end
		self.promptActive=false;self.contentKey=nil;if self.visible then self:render() end
	end)

	styleModal(
		self,
		ctx
	)

	-----------------------------------------------------------------
	-- CACHE
	-----------------------------------------------------------------

	function self:cacheKey()
		local values = {
			self.mode or "",
			self.tab or "",
			self.caseId or "",
			self.category or "",
   self.storeSection or "cases",
   self.inspectedOffer or "",
   self.hairStyle or "all",
			self.selectedOffer or "",
		}

		for _, offer in ipairs(
			offersForUI(ctx)
			) do
			local key =
				offerKey(
					offer
				)

			local info =
				self.productInfo[key]

			table.insert(
				values,
				key
					.. ":"
					.. tostring(
						info
						and info.PriceInRobux
						or offer.price
						or "?"
					)
					.. ":"
					.. tostring(
						self.ownership[key]
					)
			)
		end

		return table.concat(
			values,
			"|"
		)
	end

	-----------------------------------------------------------------
	-- RENDER
	-----------------------------------------------------------------

	function self:render()
		if not self.visible then
			return
		end

		self:clear()

		cleanSurface(
			self.surface
		)

		disableBackdrop(
			self
		)

		-------------------------------------------------------------
		-- PHYSICAL CASE MODE
		-------------------------------------------------------------


		-------------------------------------------------------------
		-- STORE
		-------------------------------------------------------------

		self.title.Text =
			isEnglish(ctx)
			and "Detective's Shop"
			or "Лавка сыщика"

		renderStore(
			ctx,
			self
		)
	end

	-----------------------------------------------------------------
	-- OPEN
	-----------------------------------------------------------------

	local baseOpen =
		self.open

	function self:open(tab)
		local state =
			ctx.state()

		if state.tableId
			and state.phase ~= "Waiting"
			and state.phase ~= "Result"
		then
			if ctx.notify then
				ctx.notify(
					ctx.L(
						"shopDuringRound"
					)
				)
			end

			return
		end

		-------------------------------------------------------------
		-- COLLECTION LINK
		-------------------------------------------------------------

		if tab == "collection" then
			ctx.openPanel(
				"inventory"
			)

			return
		end

		-------------------------------------------------------------
		-- OLD CASE PROMPT COMPATIBILITY
		-------------------------------------------------------------

        if self.tab == "capsules" or tab == "capsules" then
            self.tab="premium";self.mode="store"
            ctx.openPanel("accessoryRoll",self.caseId=="atelier" and "hair" or nil)
            return
        end
        self.mode="store";self.tab="premium"

		resizeShop(
			self,
			ctx
		)

		baseOpen(
			self
		)

		disableBackdrop(
			self
		)
	end

	-----------------------------------------------------------------
	-- CLOSE
	-----------------------------------------------------------------

	local baseClose =
		self.close

	function self:close(animated)
		baseClose(
			self,
			animated
		)

		-------------------------------------------------------------
		-- NEXT NORMAL SHOP OPEN = ROBUX SHOP
		-------------------------------------------------------------

		if self.mode == "case" then
			self.mode = "store"
			self.tab = "premium"
		end
	end

	-----------------------------------------------------------------
	-- UPDATE
	-----------------------------------------------------------------

	local baseUpdate =
		self.update

	function self:update(force)
		local state =
			ctx.state()
		local revision=(ctx.profile() or {}).revision or 0
  if self.caseRequestPending and not ctx.pending() then self.caseRequestPending=false end
  if self.repeatRefresh then self.repeatRefresh() end
		if revision>self.lastConfirmedRevision then self.lastConfirmedRevision=revision self.promptActive=false end

		if state.tableId
			and state.phase ~= "Waiting"
			and state.phase ~= "Result"
		then
			self:close()
			self:interruptReveal()

			return
		end

		baseUpdate(
			self,
			force
		)

		disableBackdrop(
			self
		)
	end

	-----------------------------------------------------------------
	-- RESIZE
	-----------------------------------------------------------------

	local baseResize =
		self.resize

	function self:resize()
		baseResize(
			self
		)

		resizeShop(
			self,
			ctx
		)

		disableBackdrop(
			self
		)

		if self.visible then
			self.contentKey =
				nil

			self:render()
		end
	end

	-----------------------------------------------------------------
	-- LEGACY ACQUISITION API
	-----------------------------------------------------------------

    -- Kept as a compatibility API; acquisition results belong to AccessoryRollUI.
    function self:reveal()
        self:close(false)
        ctx.openPanel("accessoryRoll")
    end


	function self:interruptReveal()
  self.repeatRefresh=nil;self.rewardReady=false
		if self.revealSheet then
			self.revealSheet:Destroy()
			self.revealSheet = nil
		end

		self.opening = false
	end

	-- Preserve the established shop API while applying the new layout before drawing.
	local draw=self.render
	function self:render()
		if self.storeScroll and self.storeScroll.Parent then
			self.savedStoreScroll=self.storeScroll.CanvasPosition
		end
		self.storeScroll=nil
		resizeShop(self,ctx)
		draw(self)
		self.title.TextSize=self.layoutWidth<480 and 27 or 30
		-- Each component owns its typography; a global font floor broke compact filters.
	end
	local openPolished=self.open
	function self:open(tab)
		self.animateHero=not self.visible
		if tab=="premium" or tab=="store" then self.tab="premium" end
		if tab=="capsules" then self.tab="capsules" end
		openPolished(self,tab)
	end
	function self:resize()
		resizeShop(self,ctx)
		self.contentKey=nil
		if self.visible then self:render() end
	end
	local updatePolished=self.update
	function self:update(force)
		resizeShop(self,ctx)
		updatePolished(self,force)
		self.title.TextSize=self.layoutWidth<480 and 27 or 30
	end

	return self
end

return ShopUI
