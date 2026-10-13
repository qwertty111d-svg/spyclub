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
        identity = id == "nationality" or id == "firstName" or id == "lastName", available = true, chances = {common = 80, rare = 20}})
end
local state, globalPending, language = {}, false, "ru"
local requests = {}
local ctx = {gui = gui, player = player, profile = function() return snapshot end, state = function() return state end,
    language = function() return language end, pending = function() return globalPending end,
    request = function(kind, value, requestId)
        if globalPending then return false end
        local id = requestId or "equip-" .. tostring(#requests + 1)
        table.insert(requests, {kind = kind, value = value, id = id})
        globalPending = true
        return id
    end, closePanels = function() end, notify = function() end, openPanel = function() end,
    setActivePanel = function() end, getActivePanel = function() return "accessoryRoll" end}
local menu = UI.create(ctx)
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function find(name) for _, node in ipairs(gui:GetDescendants()) do if node.Name == name then return node end end; error("Missing " .. name) end
local function activate(name) local node = find(name); if node.Active then node.Activated:Fire() end end
check(menu:open() == true and menu.visible, "open dossier")
check(find("FieldValue").Text == "Bennett", "surname comes from profile")
check(find("WardrobeTabs"):GetChildren()[2] ~= nil, "cosmetic tabs exist")
for _, viewport in ipairs({{1920,1080}, {360,640}, {360,604}, {844,360}}) do
    gui.AbsoluteSize = Vector2.new(viewport[1], viewport[2])
    menu:resize(); menu:update(true)
    local panel = find("PersonalDossier")
    local size, position = panel.AbsoluteSize, panel.AbsolutePosition
    check(position.X >= 0 and position.Y >= 0 and position.X + size.X <= viewport[1] and position.Y + size.Y <= viewport[2], "panel fits viewport")
    for _, name in ipairs({"RollSelectedSlot", "CloseDossier", "EarnRolls", "DossierFields", "WardrobeFooter"}) do
        local node = find(name)
        local p, s = node.AbsolutePosition, node.AbsoluteSize
        check(p.X >= position.X and p.Y >= position.Y and p.X + s.X <= position.X + size.X + 1 and p.Y + s.Y <= position.Y + size.Y + 1, name .. " stays inside panel")
    end
    check(find("RollSelectedSlot").AbsoluteSize.Y >= 44, "roll has touch target")
    check(find("Reroll_nationality").AbsoluteSize.Y >= 44, "origin has touch target")
end
gui.AbsoluteSize = Vector2.new(360,640); menu:resize(); menu:update(true)
activate("Reroll_nationality")
check(#requests == 1 and requests[1].value == "nationality" and requests[1].id:sub(1,2) == "8-", "origin sends sequenced backend request")
check(snapshot.rolls == 5 and snapshot.identity.firstName == "James", "client does not spend or invent result")
activate("Reroll_firstName"); activate("RollSelectedSlot")
check(#requests == 1, "pending prevents second spend")
check(menu:receive({ok = true, code = "identityRolled"}, "unrelated") == false, "foreign acknowledgement ignored")
menu:close(false); check(not menu.visible, "pending request can close safely")
menu:open(); activate("Reroll_lastName")
check(#requests == 1, "reopen retains pending request")
globalPending = false; flush(19)
check(find("Reroll_nationality").Active, "timeout permits same request retry")
activate("Reroll_nationality")
check(#requests == 2 and requests[2].id == requests[1].id, "retry retains idempotency ID")
snapshot.identity = {nationality = "british", firstName = "Oliver", lastName = "Walker"}
snapshot.rolls, snapshot.accessoryRoll.sequence, globalPending = 4, 8, false
check(menu:receive({ok = true, code = "identityRolled", category = "nationality", identity = snapshot.identity}, requests[2].id), "identity receipt accepted")
flush(1)
check(find("Identity_lastName"):FindFirstChild("FieldValue").Text == "Walker", "acknowledged identity shown")
check(find("Reroll_firstName").Active, "next identity row enabled after acknowledgement")
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
state = {tableId = "match", phase = "Discussion"}; snapshot.rolls = 4; menu:update()
check(menu.visible and not find("Reroll_firstName").Active and not find("RollSelectedSlot").Active, "active round is read-only")
activate("ChooseOwned")
check(not find("Owned_hair_a").Active, "active round blocks equip")
activate("CloseDrawer"); activate("EarnRolls")
check(not find("OpenDailyReward").Active, "active round blocks daily transition")
activate("CloseDrawer")
state.phase = "Finished"; menu:update()
check(find("Reroll_firstName").Active, "Finished phase permits changes")
language = "en"; menu:update(true)
check(find("DossierTitle").Text == "Personal dossier", "English copy supported")
check(find("Identity_nationality"):FindFirstChild("FieldValue").Text == "United Kingdom", "nationality localized")
local savedDto = snapshot.accessoryRoll
language = "ru"; state = {}; menu:update(true)
activate("EarnRolls")
check(not find("ChooseOwned").Selectable and not find("Slot_hair").Selectable and not find("CloseDossier").Selectable, "drawer traps underlying focus")
check(find("DossierDrawer").SelectionBehaviorDown == Enum.SelectionBehavior.Stop, "drawer group stops directional escape")
activate("CloseDrawer")
activate("RollSelectedSlot")
local cosmeticId = requests[#requests].id
snapshot.ready, snapshot.accessoryRoll, globalPending = false, {}, false
check(menu:receive({ok = false, code = "save_failed"}, cosmeticId), "uncertain save received")
flush(1)
check(find("RollSelectedSlot").Active and find("RollSelectedSlot").Text == "Повторить запрос", "unavailable DTO retains cosmetic Retry")
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
check(find("RollSelectedSlot").Active and find("Reroll_firstName").Active, "acknowledgement releases retained request")
state = {}; menu:update(true)
activate("Reroll_firstName")
local phaseIdentityId = requests[#requests].id
state = {tableId = "match", phase = "Hint"}; globalPending = false
flush(19)
check(find("Reroll_firstName").Active, "retained identity can recover in active phase")
check(not find("Reroll_nationality").Active and not find("RollSelectedSlot").Active, "active recovery permits no new category spends")
activate("Reroll_firstName")
check(requests[#requests].id == phaseIdentityId, "phase-flip identity retry uses same ID")
globalPending = false
check(menu:receive({ok = false, code = "roll_match_active"}, phaseIdentityId), "phase rejection handled")
flush(1)
check(find("Reroll_firstName").Active, "phase rejection retains uncertain request")
activate("Reroll_firstName")
check(requests[#requests].id == phaseIdentityId, "phase rejection cannot create fresh request ID")
snapshot.identity.firstName = "Arthur"; snapshot.rolls = 2; snapshot.accessoryRoll.sequence = 10; globalPending = false
check(menu:receive({ok = true, code = "identityRolled", category = "firstName"}, phaseIdentityId), "saved identity receipt recovered while active")
flush(1)
check(not find("Reroll_firstName").Active, "recovery completion restores active read-only state")
state = {}; menu:update(true)
activate("RollSelectedSlot")
local phaseCosmeticId = requests[#requests].id
state = {tableId = "match", phase = "Hint"}; globalPending = false
flush(19)
check(find("RollSelectedSlot").Active and find("RollSelectedSlot").Text == "Повторить запрос", "retained cosmetic retry enabled in active phase")
check(not find("Reroll_firstName").Active and not find("ChooseOwned").Active, "cosmetic recovery blocks fresh identity and equip actions")
activate("RollSelectedSlot")
check(requests[#requests].id == phaseCosmeticId, "phase-flip cosmetic retry uses same ID")
globalPending = false
check(menu:receive({ok = true, code = "accessoryRolled", category = "hair"}, phaseCosmeticId), "saved cosmetic receipt recovered while active")
snapshot.rolls = 1; snapshot.accessoryRoll.sequence = 11
flush(1)
check(not find("RollSelectedSlot").Active, "cosmetic recovery completion blocks new active-phase spend")
local requestCount = #requests
activate("RollSelectedSlot"); activate("Reroll_firstName")
check(#requests == requestCount, "active phase does not issue any fresh requests")
print("Dossier UI smoke: " .. tostring(checks) .. " assertions passed")
