local scheduled = {}
local task = {}
function task.delay(delay, callback) table.insert(scheduled, {delay = delay, callback = callback}) end
function task.defer(callback) callback() end
function task.spawn(callback) callback() end
local function flush(maxDelay)
    local retained = {}
    local current = scheduled
    scheduled = {}
    for _, job in ipairs(current) do
        if job.delay <= maxDelay then job.callback() else table.insert(retained, job) end
    end
    for _, job in ipairs(retained) do table.insert(scheduled, job) end
end
local function signal()
    local callbacks = {}
    return {Connect = function(_, callback)
        table.insert(callbacks, callback)
        return {Disconnect = function() end}
    end, Once = function(_, callback) table.insert(callbacks, callback) end,
    Fire = function(_, ...) for _, callback in ipairs(callbacks) do callback(...) end end}
end
local Enum = setmetatable({}, {__index = function(self, key)
    local group = setmetatable({}, {__index = function(groupSelf, value)
        local result = key .. "." .. value
        rawset(groupSelf, value, result)
        return result
    end})
    rawset(self, key, group)
    return group
end})
local function coord(scale, offset) return {Scale = scale, Offset = offset} end
local UDim = {new = coord}
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo) return {X = coord(xs or 0, xo or 0), Y = coord(ys or 0, yo or 0)} end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local Vector2 = {new = function(x, y) return {X = x, Y = y} end, zero = {X = 0, Y = 0}}
local Color3 = {fromRGB = function(r, g, b) return {r, g, b} end}
local TweenInfo = {new = function(...) return {...} end}
local guiClasses = {Frame = true, CanvasGroup = true, TextLabel = true, TextButton = true, ScrollingFrame = true, ViewportFrame = true}
local events = {Activated = true, MouseEnter = true, MouseLeave = true, SelectionGained = true, SelectionLost = true, Destroying = true}
local Methods = {}
function Methods:IsA(class) return self.ClassName == class or class == "GuiObject" and guiClasses[self.ClassName] == true end
function Methods:GetChildren() local copy = {}; for _, child in ipairs(self._children) do table.insert(copy, child) end; return copy end
function Methods:GetDescendants() local all = {}; for _, child in ipairs(self._children) do table.insert(all, child); for _, node in ipairs(child:GetDescendants()) do table.insert(all, node) end end; return all end
function Methods:FindFirstChild(name) for _, child in ipairs(self._children) do if child.Name == name then return child end end; return nil end
function Methods:IsDescendantOf(ancestor) local parent = self.Parent; while parent do if parent == ancestor then return true end; parent = parent.Parent end; return false end
function Methods:SetAttribute(key, value) self._attributes[key] = value end
function Methods:GetAttribute(key) return self._attributes[key] end
function Methods:GetPropertyChangedSignal(key) self._signals[key] = self._signals[key] or signal(); return self._signals[key] end
function Methods:Destroy()
    if self.Destroying then self.Destroying:Fire() end
    local children = self:GetChildren()
    for _, child in ipairs(children) do child:Destroy() end
    self.Parent = nil
end
local NodeMeta = {}
function NodeMeta.__index(self, key)
    if Methods[key] then return Methods[key] end
    if key == "AbsoluteSize" then
        if self._values.AbsoluteSize then return self._values.AbsoluteSize end
        local parent = self.Parent
        local base = parent and parent.AbsoluteSize or {X = 0, Y = 0}
        local size = self.Size or UDim2.new()
        return {X = base.X * size.X.Scale + size.X.Offset, Y = base.Y * size.Y.Scale + size.Y.Offset}
    elseif key == "AbsolutePosition" then
        local parent = self.Parent
        local base = parent and parent.AbsolutePosition or {X = 0, Y = 0}
        local extent = parent and parent.AbsoluteSize or {X = 0, Y = 0}
        local position = self.Position or UDim2.new()
        local anchor = self.AnchorPoint or Vector2.zero
        local size = self.AbsoluteSize
        return {X = base.X + extent.X * position.X.Scale + position.X.Offset - size.X * anchor.X,
            Y = base.Y + extent.Y * position.Y.Scale + position.Y.Offset - size.Y * anchor.Y}
    end
    return self._values[key]
end
function NodeMeta.__newindex(self, key, value)
    if key == "Parent" then
        local old = self._values.Parent
        if old then for i, child in ipairs(old._children) do if child == self then table.remove(old._children, i); break end end end
        if value then table.insert(value._children, self) end
    end
    self._values[key] = value
end
local Instance = {}
function Instance.new(class)
    local node = setmetatable({_values = {ClassName = class, ZIndex = 1, Active = true, Visible = true,
        CanvasPosition = Vector2.new(0, 0), Position = UDim2.new()}, _children = {}, _attributes = {}, _signals = {}}, NodeMeta)
    for event in pairs(events) do node._values[event] = signal() end
    return node
end
local input = {TouchEnabled = false, InputBegan = signal(), GetFocusedTextBox = function() return nil end,
    GetLastInputType = function() return Enum.UserInputType.Keyboard end}
local guiService = {}
local tweens = {Create = function(_, node, _, properties)
    return {Play = function() for key, value in pairs(properties) do node[key] = value end end, Cancel = function() end}
end}
local guidIndex = 0
local http = {GenerateGUID = function() guidIndex += 1; return "guid" .. tostring(guidIndex) end}
local services = {UserInputService = input, GuiService = guiService, TweenService = tweens, HttpService = http}
local game = {GetService = function(_, name) return services[name] end}
local Catalog = {Items = {
    {id = "hair_a", equipSlot = "hair", en = "Hair A", ru = "Причёска А", rarity = "common"},
    {id = "hair_b", equipSlot = "hair", en = "Hair B", ru = "Причёска Б", rarity = "rare"},
    {id = "premium_hair", equipSlot = "hair", en = "Premium Hair", ru = "Особая причёска", rarity = "rare"},
}, ById = {}, Rarities = {common = {en = "Common", ru = "Обычный", color = {100, 100, 100}}, rare = {en = "Rare", ru = "Редкий", color = {120, 130, 140}}}}
for _, item in ipairs(Catalog.Items) do Catalog.ById[item.id] = item end
local modules = {Catalog = Catalog,
    CharacterIdentity = {label = function(value, language) return language == "en" and "United Kingdom" or "Великобритания" end},
    AccessoryRollConfig = {Rewards = {starter = 5, completeMatch = 1, win = 1, daily = 2}},
    Preview3D = {mountCollection = function(parent) local result = Instance.new("ViewportFrame"); result.Parent = parent; return result end},
    FloatingUIController = {create = function() return {setPaused = function() end, setBasePosition = function() end, setActive = function() end, destroy = function() end} end}}
local script = {Parent = setmetatable({}, {__index = function(_, key) return key end})}
local require = function(key) return modules[key] end
local function loadModule()
-- DOSSIER_SOURCE_INSERT

end
local UI = loadModule()
local gui = Instance.new("ScreenGui")
gui.AbsoluteSize = Vector2.new(1920, 1080)
local player = Instance.new("Player")
player.DisplayName = "Test Subject"
player.PlayerGui = Instance.new("PlayerGui")
player.CharacterAdded, player.CharacterAppearanceLoaded = signal(), signal()
local snapshot = {ready = true, rolls = 5, identity = {nationality = "british", firstName = "James", lastName = "Bennett"},
    owned = {hair_a = true, hair_b = true, premium_hair = true}, equipped = {hair = "hair_a"},
    accessoryRoll = {sequence = 7, categories = {}}}
for _, id in ipairs({"nationality", "firstName", "lastName", "hair", "hat", "glasses", "tie", "gloves", "shoulder", "outfit", "accessory"}) do
    table.insert(snapshot.accessoryRoll.categories, {id = id, slot = id, labelRu = id, labelEn = id,
        identity = id == "nationality" or id == "firstName" or id == "lastName", available = true, chances = {common = 80, rare = 20},
        items={{id='hair_a',rarity='common',chance=80},{id='hair_b',rarity='rare',chance=20}}})
end
for _,row in ipairs(snapshot.accessoryRoll.categories)do
 if row.id=='nationality'then row.items={{id='british',labelRu='Великобритания',chance=50},{id='japanese',labelRu='Япония',chance=50}}end
end
local state, globalPending, language = {}, false, "ru"
local requests, openedPanels = {}, {}
local ctx = {gui = gui, player = player, profile = function() return snapshot end, state = function() return state end,
    language = function() return language end, pending = function() return globalPending end,
    request = function(kind, value, requestId)
        if globalPending then return false end
        local id = requestId or "equip-" .. tostring(#requests + 1)
        table.insert(requests, {kind = kind, value = value, id = id})
        globalPending = true
        return id
    end, closePanels = function() end, notify = function() end, openPanel = function(name) table.insert(openedPanels, name) end,
    setActivePanel = function() end, getActivePanel = function() return "accessoryRoll" end}
local menu = UI.create(ctx)
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function find(name) for _, node in ipairs(gui:GetDescendants()) do if node.Name == name then return node end end; error("Missing " .. name) end
local function activate(name) local node = find(name); if node.Active then node.Activated:Fire() end end
local function visible(node)
    while node do
        if node.Visible == false then return false end
        node = node.Parent
    end
    return true
end
local function onScreen(node, container)
    if not visible(node) then return false end
    local p, size = node.AbsolutePosition, node.AbsoluteSize
    local origin, extent = container.AbsolutePosition, container.AbsoluteSize
    return size.X > 0 and size.Y > 0 and p.X >= origin.X - 1 and p.Y >= origin.Y - 1
        and p.X + size.X <= origin.X + extent.X + 1 and p.Y + size.Y <= origin.Y + extent.Y + 1
end
local function overlaps(a, b)
    local p, x, q, y = a.AbsolutePosition, a.AbsoluteSize, b.AbsolutePosition, b.AbsoluteSize
    return p.X < q.X + y.X and q.X < p.X + x.X and p.Y < q.Y + y.Y and q.Y < p.Y + x.Y
end
local function selectIdentity(id)
    activate("TabPersonal"); activate("SelectIdentity_" .. id)
end
local function selectAppearance(id)
    activate("TabAppearance"); if id then activate("Slot_" .. id) end
end
local function rollTarget(id)
    check(find("RollSelectedSlot").Text:find("1 Roll", 1, true) ~= nil, "fresh main action shows its exact cost")
    activate("RollSelectedSlot")
    check(requests[#requests].value == id, "main action requests its selected target")
end
check(menu:open() == true and menu.visible, "open character")
local primaryTabs = {}
for _, node in ipairs(find("CharacterTabs"):GetChildren()) do
    if node:IsA("TextButton") then primaryTabs[#primaryTabs + 1] = node end
end
check(#primaryTabs == 2, "character has exactly two primary tabs")
check(find("TabPersonal").Text == "Личные данные" and find("TabAppearance").Text == "Внешность", "both primary tabs are explicit")
check(find("SelectedTarget").Text == "Происхождение", "personal tab defaults to origin")
check(find("Identity_nationality").Position.Y.Offset < find("Identity_firstName").Position.Y.Offset
    and find("Identity_firstName").Position.Y.Offset < find("Identity_lastName").Position.Y.Offset, "identity order is origin, name, surname")
selectIdentity("firstName")
check(#requests == 0 and find("SelectedTarget").Text == "Имя", "selecting whole identity row does not spend")
check(find("RollSelectedSlot").Text:find("Имя", 1, true) ~= nil, "main action explicitly names selected identity target")
for _,id in ipairs({"firstName","lastName"})do
    selectIdentity(id)
    check(not visible(find("ChanceDetails")) and not find("ChanceDetails").Active, "random name fields do not expose probability lists")
    check(not find("ChanceSummary").Text:find("%%") and find("ChanceSummary").Text ~= "", "name field explains random choice without percentages")
    find("ChanceDetails").Activated:Fire()
    check(not visible(find("CloseDrawer")), "hidden name probability action cannot open a drawer")
end
selectIdentity("nationality")
check(find("ChanceSummary").Text:find("50%%") ~= nil and visible(find("ChanceSummary")), "selected real identity odds are always visible")
check(find("ChanceDetails").Text == "Все шансы ›", "all chances is an explicit secondary action")
activate("ChanceDetails")
check(find("ItemOdds_british"):FindFirstChild("OddsItemPercent").Text == "50%", "origin details disclose actual individual probability")
activate("CloseDrawer")
check(find("Identity_lastName"):FindFirstChild("SelectIdentity_lastName"):FindFirstChild("FieldValue").Text == "Bennett", "surname comes from profile")
for _, id in ipairs({"firstName", "lastName", "nationality"}) do selectIdentity(id) end
for _, id in ipairs({"hair", "hat", "glasses", "tie", "gloves", "shoulder", "outfit", "accessory"}) do selectAppearance(id) end
check(#requests == 0 and snapshot.rolls == 5, "all identity and cosmetic selectors leave requests and wallet unchanged")
selectAppearance("hair")
check(#requests == 0 and find("SelectedTarget").Text == "hair", "cosmetic selection also does not spend")
check(visible(find("CurrentWardrobeItem")) and not visible(find("Identity_nationality")), "appearance has its own equipped-item content")
check(find("ChanceSummary").Text:find("80%%") ~= nil, "real cosmetic chances are visible")
activate("ChanceDetails")
check(find("ItemOdds_hair_a"):FindFirstChild("OddsItemPercent").Text == "80%", "cosmetic details disclose actual individual probability")
activate("CloseDrawer")
Catalog.Rarities.uncommon = {ru = "Необычный", en = "Uncommon", color = {100, 100, 100}}
Catalog.Rarities.epic = {ru = "Эпический", en = "Epic", color = {100, 100, 100}}
Catalog.Rarities.legendary = {ru = "Легендарный", en = "Legendary", color = {100, 100, 100}}
Catalog.Rarities.mythic = {ru = "Мифический", en = "Mythic", color = {100, 100, 100}}
local hairRow
for _, row in ipairs(snapshot.accessoryRoll.categories) do if row.id == "hair" then hairRow = row end end
local originalChances = hairRow.chances
hairRow.chances = {common = 50, uncommon = 30, rare = 15, epic = 4, legendary = .9, mythic = .1}
for _, viewport in ipairs({{1920,1080}, {360,640}, {360,604}, {844,360}, {280,640}}) do
    gui.AbsoluteSize = Vector2.new(viewport[1], viewport[2])
    menu:resize(); menu:update(true)
    local panel = find("PersonalDossier")
    local size, position = panel.AbsoluteSize, panel.AbsolutePosition
    check(position.X >= 0 and position.Y >= 0 and position.X + size.X <= viewport[1] and position.Y + size.Y <= viewport[2], "panel fits viewport")
    local headerControls = {"DossierTitle", "RollBalance", "EarnRolls", "BuyRolls", "CloseDossier"}
    for i = 1, #headerControls do
        for j = i + 1, #headerControls do check(not overlaps(find(headerControls[i]), find(headerControls[j])), "header controls do not overlap: " .. headerControls[i] .. "/" .. headerControls[j] .. " at " .. tostring(viewport[1])) end
    end
    local bodyRegions = {"CharacterTabs", "PortraitStage", "DossierFields", "WardrobeFooter"}
    for i = 1, #bodyRegions do
        for j = i + 1, #bodyRegions do check(not overlaps(find(bodyRegions[i]), find(bodyRegions[j])), "tabs, stage, fields and named action stay separated") end
    end
    for _, tab in ipairs({"TabPersonal", "TabAppearance"}) do
        activate(tab)
        for _, name in ipairs({"RollSelectedSlot", "SelectedTarget", "ChanceSummary", "ChanceDetails", "CloseDossier", "EarnRolls", "BuyRolls", "DossierFields", "WardrobeFooter", "CharacterTabs", "PortraitStage"}) do
            check(onScreen(find(name), panel), tab .. ": " .. name .. " is visible inside panel")
        end
        check(find("RollSelectedSlot").AbsoluteSize.Y >= 64 and find("ChanceDetails").AbsoluteSize.Y >= 44, "main and chance actions have touch targets")
        check(find(tab).AbsoluteSize.Y >= 44, "primary tabs have touch targets")
        if tab == "TabPersonal" then
            check(onScreen(find("Identity_nationality"), find("DossierFields")), "default identity target is visible without scrolling")
            check(find("SelectIdentity_nationality").AbsoluteSize.Y >= 44, "origin has whole-row touch target")
            check(not find("ChooseOwned").Active and not find("Slot_hair").Selectable, "hidden appearance controls cannot activate")
        else
            check(onScreen(find("CurrentWardrobeItem"), find("DossierFields")) and onScreen(find("ChooseOwned"), find("DossierFields")), "appearance current item and collection stay visible without scrolling")
            check(not find("SelectIdentity_firstName").Active, "hidden identity controls cannot activate")
            for _, percent in ipairs({"50%", "30%", "15%", "4%", "0.9%", "0.1%"}) do
                check(find("ChanceSummary").Text:find(percent, 1, true) ~= nil, "six-rarity pool discloses " .. percent)
            end
            check(find("ChanceSummary").AbsoluteSize.Y >= find("ChanceSummary").TextSize * 3.6, "all three odds rows have visible vertical space")
        end
    end
    check(find("PersonalDossier").BackgroundTransparency == 1, "club remains visible behind the actual avatar stage")
    check(find("PortraitStage").AbsoluteSize.Y >= 112, "actual avatar stage stays substantial")
    check(find("BuyRolls").AbsoluteSize.Y >= 44, "paid Rolls entry has touch target")
end
hairRow.chances = originalChances
gui.AbsoluteSize = Vector2.new(360,640); menu:resize(); menu:update(true)
selectIdentity("nationality")
check(#requests == 0 and find("RollSelectedSlot").Text:find("Происхождение", 1, true) ~= nil, "phone primary explicitly names selected target before spend")
rollTarget("nationality")
check(#requests == 1 and requests[1].id:sub(1,2) == "8-", "origin sends sequenced backend request")
check(snapshot.rolls == 5 and snapshot.identity.firstName == "James", "client does not spend or invent result")
selectIdentity("firstName"); activate("RollSelectedSlot")
check(#requests == 1, "pending prevents second spend")
activate("TabAppearance")
check(find("SelectedTarget").Text == "Происхождение" and find("RollSelectedSlot").Text:find("Происхождение", 1, true), "tab changes keep pending identity type and target visible")
check(menu:receive({ok = true, code = "identityRolled"}, "unrelated") == false, "foreign acknowledgement ignored")
menu:close(false); check(not menu.visible, "pending request can close safely")
menu:open(); activate("RollSelectedSlot")
check(#requests == 1, "reopen retains pending request")
globalPending = false; flush(19)
check(find("RollSelectedSlot").Active and find("RollSelectedSlot").Text:find("Происхождение", 1, true), "timeout permits visibly named same-request retry")
activate("RollSelectedSlot")
check(#requests == 2 and requests[2].id == requests[1].id, "retry retains idempotency ID")
snapshot.identity = {nationality = "british", firstName = "Oliver", lastName = "Walker"}
snapshot.rolls, snapshot.accessoryRoll.sequence, globalPending = 4, 8, false
check(menu:receive({ok = true, code = "identityRolled", category = "nationality", identity = snapshot.identity}, requests[2].id), "identity receipt accepted")
flush(1)
check(find("Identity_lastName"):FindFirstChild("SelectIdentity_lastName"):FindFirstChild("FieldValue").Text == "Walker", "acknowledged identity shown")
selectAppearance("hair")
activate("ChooseOwned")
check(find("Owned_premium_hair") ~= nil, "owned selection includes non-roll premium item")
check(not find("Owned_hair_a").Active, "equipped item cannot toggle off accidentally")
activate("Owned_hair_b")
check(#requests == 3 and requests[3].kind == "equip" and requests[3].value == "hair_b", "owned selection uses equip remote")
snapshot.equipped.hair, globalPending = "hair_b", false
check(menu:receive({ok = true, code = "equipped"}, requests[3].id), "equip receipt accepted")
check(find("EquippedItemName").Text == "Причёска Б", "equipped summary refreshed")
snapshot.rolls = 0; menu:update()
check(find("Slot_hat").Active and find("ChooseOwned").Active, "zero wallet still permits collection browsing")
check(not find("RollSelectedSlot").Active, "zero wallet blocks spending")
selectIdentity("firstName")
check(#requests == 3 and find("SelectedTarget").Text == "Имя", "zero wallet identity browsing does not spend")
state = {tableId = "match", phase = "Discussion"}; snapshot.rolls = 4; menu:update()
check(menu.visible and not find("RollSelectedSlot").Active, "active round is read-only")
selectAppearance("hair"); activate("ChooseOwned")
check(not find("Owned_hair_a").Active, "active round blocks equip")
activate("CloseDrawer"); activate("EarnRolls")
check(not find("OpenDailyReward").Active, "active round blocks daily transition")
activate("CloseDrawer")
state.phase = "Finished"; menu:update()
check(find("RollSelectedSlot").Active, "Finished phase permits changes")
language = "en"; menu:update(true)
check(find("DossierTitle").Text == "Character", "English character copy supported")
check(find("Identity_nationality"):FindFirstChild("SelectIdentity_nationality"):FindFirstChild("FieldValue").Text == "United Kingdom", "nationality localized")
local savedDto = snapshot.accessoryRoll
language = "ru"; state = {}; menu:update(true)
activate("EarnRolls")
check(not find("ChooseOwned").Selectable and not find("Slot_hair").Selectable and not find("CloseDossier").Selectable and not find("BuyRolls").Selectable
    and not find("TabPersonal").Selectable and not find("TabAppearance").Selectable, "drawer traps underlying focus including both primary tabs")
check(find("DossierDrawer").SelectionBehaviorDown == Enum.SelectionBehavior.Stop, "drawer group stops directional escape")
activate("CloseDrawer")
activate("BuyRolls")
check(openedPanels[#openedPanels] == "clubStore" and not menu.visible, "paid entry opens Rolls shop and closes character")
check(#requests == 3, "opening paid shop does not request a roll or mutate wallet")
menu:open(); selectAppearance("hair")
rollTarget("hair")
local cosmeticId = requests[#requests].id
snapshot.ready, snapshot.accessoryRoll, globalPending = false, {}, false
check(menu:receive({ok = false, code = "save_failed"}, cosmeticId), "uncertain save received")
flush(1)
check(find("RollSelectedSlot").Active and find("RollSelectedSlot").Text:find("Повторить запрос", 1, true)
    and find("SelectedTarget").Text == "hair", "missing DTO retains named cosmetic Retry")
activate("TabPersonal")
check(find("SelectedTarget").Text == "hair", "missing DTO and tab change preserve pending target")
activate("RollSelectedSlot")
check(requests[#requests].id == cosmeticId, "cosmetic retry retains request with empty DTO")
globalPending = false
check(menu:receive({ok = false, code = "slowDown"}, cosmeticId), "transient response accepted")
flush(1)
check(find("RollSelectedSlot").Active, "transient response permits safe retry")
activate("RollSelectedSlot")
check(requests[#requests].id == cosmeticId, "slowDown preserves uncertain request ID")
snapshot.ready, snapshot.accessoryRoll, snapshot.rolls, globalPending = true, savedDto, 3, false
snapshot.accessoryRoll.sequence = 9
check(menu:receive({ok = true, code = "accessoryRolled", category = "hair"}, cosmeticId), "late cosmetic receipt reconciled")
flush(1)
check(find("RollSelectedSlot").Active, "acknowledgement releases retained request")
state = {}; menu:update(true)
selectIdentity("firstName"); rollTarget("firstName")
local phaseIdentityId = requests[#requests].id
state = {tableId = "match", phase = "Hint"}; globalPending = false
flush(19)
activate("TabAppearance")
check(find("RollSelectedSlot").Active and find("SelectedTarget").Text == "Имя", "retained identity recovers with visible target in active phase")
check(not find("Slot_hair").Active and not find("ChooseOwned").Active, "active recovery permits no fresh category/equip requests")
activate("RollSelectedSlot")
check(requests[#requests].id == phaseIdentityId, "phase-flip identity retry uses same ID")
globalPending = false
check(menu:receive({ok = false, code = "roll_match_active"}, phaseIdentityId), "phase rejection handled")
flush(1)
check(find("RollSelectedSlot").Active, "phase rejection retains uncertain request")
activate("RollSelectedSlot")
check(requests[#requests].id == phaseIdentityId, "phase rejection cannot create fresh request ID")
snapshot.identity.firstName = "Arthur"; snapshot.rolls = 2; snapshot.accessoryRoll.sequence = 10; globalPending = false
check(menu:receive({ok = true, code = "identityRolled", category = "firstName"}, phaseIdentityId), "saved identity receipt recovered while active")
flush(1)
check(not find("RollSelectedSlot").Active, "recovery completion restores active read-only state")
state = {}; menu:update(true)
selectAppearance("hair"); rollTarget("hair")
local phaseCosmeticId = requests[#requests].id
state = {tableId = "match", phase = "Hint"}; globalPending = false
flush(19)
check(find("RollSelectedSlot").Active and find("RollSelectedSlot").Text:find("Повторить запрос", 1, true), "retained cosmetic retry enabled in active phase")
check(not find("ChooseOwned").Active, "cosmetic recovery blocks fresh equip actions")
activate("RollSelectedSlot")
check(requests[#requests].id == phaseCosmeticId, "phase-flip cosmetic retry uses same ID")
globalPending = false
check(menu:receive({ok = true, code = "accessoryRolled", category = "hair"}, phaseCosmeticId), "saved cosmetic receipt recovered while active")
snapshot.rolls = 1; snapshot.accessoryRoll.sequence = 11
flush(1)
check(not find("RollSelectedSlot").Active, "cosmetic recovery completion blocks new active-phase spend")
local requestCount = #requests
activate("RollSelectedSlot"); selectIdentity("firstName"); activate("RollSelectedSlot")
check(#requests == requestCount, "active phase sends no fresh requests")
state = {}; snapshot.rolls = 5
snapshot.rollShop = {policyReady = true, restricted = true}
snapshot.accessoryRoll.canSpend, snapshot.accessoryRoll.spendReason = false, "roll_paid_restricted"
for _, row in ipairs(snapshot.accessoryRoll.categories) do row.canSpend, row.spendReason = false, "roll_paid_restricted" end
menu:update(true)
check(not find("RollSelectedSlot").Active, "paid-only account restriction blocks fresh identity rolls")
selectAppearance("hair")
check(not find("RollSelectedSlot").Active and find("ChooseOwned").Active and find("Slot_hat").Active, "paid restriction blocks spending and preserves cosmetic browsing")
check(find("RequestStatus").Text == "Купленные Rolls недоступны аккаунту. Rolls за игру доступны.", "paid restriction has specific account copy")
activate("RollSelectedSlot"); selectIdentity("nationality"); activate("RollSelectedSlot")
check(#requests == requestCount, "restricted paid wallet sends no fresh spend request")
snapshot.rollShop.policyReady = false
menu:update()
check(find("RequestStatus").Text == "Проверяем доступ к купленным Rolls…", "pending policy has distinct copy")
snapshot.accessoryRoll.canSpend = true
for _, row in ipairs(snapshot.accessoryRoll.categories) do row.canSpend, row.spendReason = true, nil end
snapshot.accessoryRoll.spendReason, snapshot.accessoryRoll.earnedRolls = nil, 1
menu:update()
check(find("RollSelectedSlot").Active, "earned identity Rolls remain usable while paid policy pending")
selectAppearance("hair")
check(find("RollSelectedSlot").Active and find("RequestStatus").Text ~= "Проверяем доступ к купленным Rolls…", "usable earned cosmetic wallet clears paid restriction status")
for _, row in ipairs(snapshot.accessoryRoll.categories) do if row.id == "hair" then row.canSpend, row.spendReason = false, "roll_paid_restricted" end end
menu:update()
check(not find("RollSelectedSlot").Active, "per-category cosmetic spend restriction honored")
selectIdentity("firstName")
check(find("RollSelectedSlot").Active, "independent identity category remains usable")
for _, row in ipairs(snapshot.accessoryRoll.categories) do row.canSpend, row.spendReason = true, nil end
menu:update()
rollTarget("firstName")
local restrictedRetryId = requests[#requests].id
snapshot.accessoryRoll.canSpend, snapshot.accessoryRoll.spendReason = false, "roll_paid_restricted"
snapshot.rollShop.policyReady = true
for _, row in ipairs(snapshot.accessoryRoll.categories) do row.canSpend, row.spendReason = false, "roll_paid_restricted" end
globalPending = false; flush(19)
check(find("RollSelectedSlot").Active and find("SelectedTarget").Text == "Имя", "paid restriction permits only named retained recovery")
activate("RollSelectedSlot")
check(requests[#requests].id == restrictedRetryId, "restricted recovery retains original idempotency identifier")
globalPending = false
check(menu:receive({ok = false, code = "roll_paid_restricted"}, restrictedRetryId), "paid restriction response handled")
flush(1)
check(find("RequestStatus").Text == "Купленные Rolls недоступны аккаунту. Rolls за игру доступны.", "paid restriction receipt uses specific account copy")
-- Identity recovery must survive the same absence of DTO and wallet as cosmetic recovery.
snapshot.ready, snapshot.accessoryRoll, snapshot.rolls, globalPending, state = true, savedDto, 2, false, {}
snapshot.accessoryRoll.canSpend, snapshot.accessoryRoll.spendReason = true, nil
for _, row in ipairs(snapshot.accessoryRoll.categories) do row.canSpend, row.spendReason = true, nil end
selectIdentity("lastName"); rollTarget("lastName")
local missingIdentityId = requests[#requests].id
snapshot.ready, snapshot.accessoryRoll, snapshot.rolls, globalPending = false, {}, 0, false
check(menu:receive({ok = false, code = "profile_unavailable"}, missingIdentityId), "missing profile identity response accepted")
flush(1)
state = {tableId = "match", phase = "Discussion"}; activate("TabAppearance")
check(find("RollSelectedSlot").Active and find("SelectedTarget").Text == "Фамилия", "identity recovery remains named and usable with no DTO, no wallet, and active phase")
activate("RollSelectedSlot")
check(requests[#requests].id == missingIdentityId, "missing identity DTO cannot generate a new spend identifier")
globalPending = false
snapshot.ready, snapshot.accessoryRoll, snapshot.rolls = true, savedDto, 1
check(menu:receive({ok = true, code = "identityRolled", category = "lastName"}, missingIdentityId), "missing-profile identity receipt recovered")
flush(1)
check(not find("RollSelectedSlot").Active, "recovered identity returns to active round readonly")
print("Dossier UI smoke: " .. tostring(checks) .. " assertions passed")
