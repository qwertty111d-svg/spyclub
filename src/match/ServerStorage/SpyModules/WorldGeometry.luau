-- ReplicatedStorage > SpyShared > WorldGeometry
-- ПОЛНАЯ ЗАМЕНА
--
-- Что делает:
-- • удаляет старые Trio / Quartet / HighStakes игровые столы из Lobby;
-- • не создаёт их заново из WorldSpec;
-- • не создаёт JoinTable / Billboard старой системы;
-- • НЕ трогает бар, Vincent, витрины, стены, ковры, двери, декор и т.д.;
-- • новая система "Создать стол" работает отдельно через SpyPartyServer.

local Geometry = {}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function color(v)
	return Color3.fromRGB(
		v[1],
		v[2],
		v[3]
	)
end

local function vector(v)
	return Vector3.new(
		v[1],
		v[2],
		v[3]
	)
end

local function transform(d)
	local cf =
		CFrame.new(
			vector(d.pos)
		)
		* CFrame.Angles(
			math.rad(d.pitch or 0),
			math.rad(d.yaw or 0),
			math.rad(d.roll or 0)
		)

	if d.shape == "Cylinder" then
		cf =
			cf
			* CFrame.Angles(
				0,
				0,
				math.pi / 2
			)
	end

	return cf
end

Geometry.transform = transform

---------------------------------------------------------------------
-- OLD TABLE GROUPS
---------------------------------------------------------------------

local REMOVED_GROUPS = {
	Trio = true,
	Quartet = true,
	HighStakes = true,
}

local function topGroup(path)
	if not path or path == "" then
		return ""
	end

	return path:match("^([^/]+)")
		or path
end

local function isRemovedGroup(path)
	return REMOVED_GROUPS[
	topGroup(path)
	] == true
end

---------------------------------------------------------------------
-- ACTIONS
---------------------------------------------------------------------

local actions = {
	OpenShop = "shop",
	DailyReward = "daily",
	HighStakesDoor = "highStakes",
	TalkVincent = "talkVincent",
	InspectCase = "inspect",

	-- JoinTable специально отсутствует.
	-- Старые физические игровые столы больше не используются.
}

---------------------------------------------------------------------
-- DECORATE
---------------------------------------------------------------------

local function decorate(p, d)
	-----------------------------------------------------------------
	-- SIGN
	-----------------------------------------------------------------

	if d.sign then
		local gui =
			p:FindFirstChild("Sign")
			or Instance.new("SurfaceGui")

		gui.Name = "Sign"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode =
			Enum.SurfaceGuiSizingMode.PixelsPerStud

		gui.PixelsPerStud = 50
		gui.LightInfluence = 0.15
		gui.Parent = p

		local name =
			d.sign.rows
			and "Rows"
			or "Text"

		local label =
			gui:FindFirstChild(name)
			or Instance.new("TextLabel")

		label.Name = name

		label.Size =
			UDim2.fromScale(
				0.94,
				0.94
			)

		label.Position =
			UDim2.fromScale(
				0.03,
				0.03
			)

		label.BackgroundTransparency = 1

		label.Font =
			Enum.Font.BuilderSansMedium

		label.TextColor3 =
			Color3.fromRGB(
				228,
				214,
				185
			)

		label.TextScaled = true
		label.TextWrapped = true

		label.Text =
			d.sign.text

		label.Parent =
			gui

		local limit =
			label:
			FindFirstChildOfClass(
				"UITextSizeConstraint"
			)
			or Instance.new(
				"UITextSizeConstraint"
			)

		limit.MinTextSize = 10

		limit.MaxTextSize =
			d.sign.rows
			and 26
			or 38

		limit.Parent =
			label

		if d.sign.key
			and d.sign.key ~= ""
		then
			label:SetAttribute(
				"TextKey",
				d.sign.key
			)
		end

		if d.sign.rows then
			label.TextXAlignment =
				Enum.TextXAlignment.Left

			label.TextYAlignment =
				Enum.TextYAlignment.Top
		end
	end

	-----------------------------------------------------------------
	-- LIGHT
	-----------------------------------------------------------------

	if d.light then
		local light =
			p:FindFirstChild(
				"WarmLight"
			)
			or Instance.new(
				"PointLight"
			)

		light.Name =
			"WarmLight"

		light.Color =
			color(
				d.light.color
			)

		light.Brightness =
			d.light.brightness

		light.Range =
			d.light.range

		light.Shadows =
			true

		light.Parent =
			p
	end

	-----------------------------------------------------------------
	-- PROMPT
	-----------------------------------------------------------------

	if d.prompt then
		-- Старый JoinTable больше никогда не создаём.
		if d.prompt.name == "JoinTable" then
			local oldPrompt =
				p:FindFirstChild(
					"JoinTable"
				)

			if oldPrompt then
				oldPrompt:Destroy()
			end

		else
			local v =
				d.prompt

			local prompt =
				p:FindFirstChild(
					v.name
				)
				or Instance.new(
					"ProximityPrompt"
				)

			prompt.Name =
				v.name

			prompt.ActionText =
				v.action

			prompt.ObjectText =
				v.object

			prompt.MaxActivationDistance =
				v.distance or 8

			prompt.RequiresLineOfSight =
				false

			prompt.HoldDuration =
				0.1

			prompt:SetAttribute(
				"ActionKey",
				actions[v.name]
			)

			prompt.Parent =
				p
		end
	end

	-----------------------------------------------------------------
	-- ATTRIBUTES
	-----------------------------------------------------------------

	for key, value in pairs(
		d.attributes or {}
		) do
		p:SetAttribute(
			key,
			value
		)
	end
end

---------------------------------------------------------------------
-- DELETE OLD SAVED TABLES
---------------------------------------------------------------------

local function removeOldTables(root)
	for name in pairs(
		REMOVED_GROUPS
		) do
		local object =
			root:FindFirstChild(
				name
			)

		if object then
			object:Destroy()
		end
	end
end

---------------------------------------------------------------------
-- BIND
---------------------------------------------------------------------

function Geometry.bind(root, config)
	local spec =
		require(
			script.Parent.WorldSpec
		)

	-----------------------------------------------------------------
	-- IMPORTANT:
	-- Старые столы уже могут быть физически сохранены внутри rbxl.
	-- Удаляем их ДО построения мира.
	-----------------------------------------------------------------

	removeOldTables(root)

	-----------------------------------------------------------------
	-- GROUP CACHE
	-----------------------------------------------------------------

	local groups = {
		[""] = root,
	}

	local function group(path)
		if groups[path] then
			return groups[path]
		end

		-- Старые игровые группы вообще не создаём.
		if isRemovedGroup(path) then
			return nil
		end

		local parentPath, name =
			path:match(
				"^(.*)/([^/]+)$"
			)

		local parent =
			parentPath
			and group(parentPath)
			or root

		if not parent then
			return nil
		end

		name =
			name
			or path

		local model =
			parent:FindFirstChild(
				name
			)
			or Instance.new(
				"Model"
			)

		model.Name =
			name

		model.Parent =
			parent

		groups[path] =
			model

		return model
	end

	-----------------------------------------------------------------
	-- BUILD NORMAL LOBBY PARTS
	-----------------------------------------------------------------

	for _, d in ipairs(
		spec.parts
		) do
		local groupPath =
			d.group or ""

		-------------------------------------------------------------
		-- SKIP OLD TABLE GEOMETRY
		-------------------------------------------------------------

		if not isRemovedGroup(
			groupPath
			) then
			local parent =
				group(groupPath)

			if parent then
				local p =
					parent:
					FindFirstChild(
						d.name
					)

				if not p then
					p =
						Instance.new(
							d.cls
							or "Part"
						)

					p.Name =
						d.name

					p.Parent =
						parent
				end

				-----------------------------------------------------
				-- BASIC PROPERTIES
				-----------------------------------------------------

				p.Size =
					vector(
						d.size
					)

				p.CFrame =
					transform(d)

				p.Color =
					color(
						d.color
					)

				p.Material =
					Enum.Material[
				d.material
				]

				p.Anchored =
					true

				p.CanCollide =
					d.collide

				p.TopSurface =
					Enum.SurfaceType.Smooth

				p.BottomSurface =
					Enum.SurfaceType.Smooth

				p.Transparency =
					d.transparency
					or 0

				-----------------------------------------------------
				-- SHAPE
				-----------------------------------------------------

				if d.shape then
					p.Shape =
						Enum.PartType[
					d.shape
					]
				end

				-----------------------------------------------------
				-- SPAWN
				-----------------------------------------------------

				if d.cls
					== "SpawnLocation"
				then
					p.Neutral =
						true

					p.Enabled =
						true

					p.Duration =
						0
				end

				decorate(
					p,
					d
				)
			end
		end
	end

	-----------------------------------------------------------------
	-- NORMAL MODELS
	-----------------------------------------------------------------

	for path, d in pairs(
		spec.models or {}
		) do
		if not isRemovedGroup(
			path
			) then
			local model =
				group(path)

			if model then
				local pivot =
					model:
					FindFirstChild(
						d.pivot
					)

				if pivot then
					model.PrimaryPart =
						pivot
				end

				for key, value in pairs(
					d.attributes
						or {}
					) do
					model:SetAttribute(
						key,
						value
					)
				end
			end
		end
	end

	-----------------------------------------------------------------
	-- OLD TABLE REFERENCES REMOVED
	--
	-- Config.Tables теперь пустой.
	-- SpyServer получит пустой refs и старая table-система
	-- ничего не сможет создать / подключить.
	-----------------------------------------------------------------

	local refs = {}

	-----------------------------------------------------------------
	-- SAFETY CLEANUP AGAIN
	--
	-- На случай если какой-либо старый объект был сохранён
	-- необычным образом.
	-----------------------------------------------------------------

	removeOldTables(root)

	return refs
end

return Geometry