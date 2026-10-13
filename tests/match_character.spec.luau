-- The client source is executed, rather than checking subscription names or strings.
-- GUI modules are small probes; dossier_ui.spec independently tests the real UI.
local function signal()
    local listeners = {}
    local event = {}
    function event:Connect(callback)
        local listener = {callback = callback, connected = true}
        table.insert(listeners, listener)
        return {Disconnect = function() listener.connected = false end}
    end
    function event:Fire(...)
        local current = table.clone(listeners)
        for _, listener in ipairs(current) do
            if listener.connected then listener.callback(...) end
        end
    end
    function event:ActiveCount()
        local count = 0
        for _, listener in ipairs(listeners) do if listener.connected then count += 1 end end
        return count
    end
    return event
end
local Enum = setmetatable({}, {__index = function(self, key)
    local group = setmetatable({}, {__index = function(groupSelf, value)
        local token = key .. "." .. value
        rawset(groupSelf, value, token)
        return token
    end})
    rawset(self, key, group)
    return group
end})
local UDim = {new = function(scale, offset) return {Scale = scale, Offset = offset} end}
local UDim2 = {new = function(...) return {...} end}
local Vector2 = {new = function(x, y) return {X = x, Y = y} end}
local Color3 = {fromRGB = function(...) return {...} end}
local guiClasses = {Frame = true, TextLabel = true, TextButton = true, ScrollingFrame = true}
local methods = {}
function methods:IsA(class) return self.ClassName == class or class == "GuiObject" and guiClasses[self.ClassName] == true end
function methods:FindFirstChild(name)
    for _, child in ipairs(self._children) do if child.Name == name then return child end end
    return nil
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:GetAttributeChangedSignal(key)
    self._attributeSignals[key] = self._attributeSignals[key] or signal()
    return self._attributeSignals[key]
end
function methods:SetAttribute(key, value)
    local previous = self._attributes[key]
    self._attributes[key] = value
    if previous ~= value and self._attributeSignals[key] then self._attributeSignals[key]:Fire() end
end
function methods:GetPropertyChangedSignal(key)
    self._propertySignals[key] = self._propertySignals[key] or signal()
    return self._propertySignals[key]
end
function methods:Fire(...) self.Event:Fire(...) end
function methods:FireServer(...) if self._fireServer then self._fireServer(...) end end
function methods:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Destroying:Fire()
    for _, child in ipairs(table.clone(self._children)) do child:Destroy() end
    self.Parent = nil
end
local nodeMeta = {}
function nodeMeta.__index(self, key) return methods[key] or self._values[key] end
function nodeMeta.__newindex(self, key, value)
    if key == "Parent" then
        local old = self._values.Parent
        if old then
            for i, child in ipairs(old._children) do if child == self then table.remove(old._children, i); break end end
        end
        self._values.Parent = value
        if value then table.insert(value._children, self); value.ChildAdded:Fire(self) end
        return
    end
    self._values[key] = value
end
local Instance = {}
function Instance.new(class)
    local node = setmetatable({_values = {ClassName = class, ZIndex = 1, Destroying = signal(),
        ChildAdded = signal(), AbsoluteSize = Vector2.new(1920, 1080)},
        _children = {}, _attributes = {}, _attributeSignals = {}, _propertySignals = {}}, nodeMeta)
    if class == "BindableEvent" then node.Event = signal() end
    if class == "RemoteEvent" then node.OnClientEvent = signal() end
    if class == "Player" then node.CharacterAdded = signal() end
    return node
end
local function loadPolicy()
-- DOSSIER_POLICY_SOURCE_INSERT
end
local Policy = loadPolicy()
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function snapshot(rolls, revision, available)
    return {ready = true, rolls = rolls, revision = revision, owned = {}, equipped = {},
        accessoryRoll = {sequence = 0, categories = {{id = "hair", slot = "hair", available = available ~= false}}}}
end
local function boot(options)
    options = options or {}
    local clock, scheduled = 0, {}
    local requests, warnings, menus = {}, {}, {}
    local task = {}
    function task.delay(delay, callback) table.insert(scheduled, {at = clock + delay, callback = callback}) end
    local player = Instance.new("Player")
    player.Name = "LocalPlayer"
    player.Character = Instance.new("Model")
    local pg = Instance.new("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = player
    local rs = Instance.new("ReplicatedStorage")
    local function child(class, name, parent)
        local node = Instance.new(class); node.Name = name; node.Parent = parent; return node
    end
    local shared = child("Folder", "SpyShared", rs)
    child("ModuleScript", "DossierPolicy", shared)
    child("ModuleScript", "I18n", shared)
    child("ModuleScript", "AccessoryRollUI", shared)
    child("ModuleScript", "DailyUI", shared)
    local action = not options.noAction and child("RemoteEvent", "EconomyAction", shared) or nil
    local profileEvent = not options.noProfile and child("RemoteEvent", "Profile", shared) or nil
    if action then
        action._fireServer = function(kind, value, id) table.insert(requests, {kind = kind, value = value, id = id}) end
    end
    local session = child("Folder", "MatchSession", rs)
    session:SetAttribute("RoundPhase", options.phase or "Hint")
    local matchRemotes = child("Folder", "MatchRemotes", rs)
    local reward = child("RemoteEvent", "Reward", matchRemotes)
    local run = {Heartbeat = signal()}
    local guid = 0
    local http = {GenerateGUID = function() guid += 1; return "request-" .. tostring(guid) end}
    local services = {Players = {LocalPlayer = player}, ReplicatedStorage = rs, HttpService = http, RunService = run}
    local game = {GetService = function(_, name) return services[name] end}
    local script = {Destroying = signal()}
    local warn = function(value) table.insert(warnings, tostring(value)) end
    local function menuModule(name)
        return {create = function(ctx)
            local menu = {name = name, visible = false, opens = 0, updates = 0, destroyed = 0, received = {}, ctx = ctx}
            function menu:update()
                self.updates += 1
                self.last = {profile = ctx.profile(), pending = ctx.pending(), state = ctx.state()}
            end
            function menu:open()
                self.visible = true; self.opens += 1; ctx.setActivePanel(name); self:update()
            end
            function menu:close()
                self.visible = false
                if ctx.getActivePanel() == name then ctx.setActivePanel(nil) end
            end
            function menu:resize() end
            function menu:receive(receipt, id)
                table.insert(self.received, {receipt = receipt, id = id})
                return false
            end
            function menu:Destroy() self.destroyed += 1 end
            function menu:tick() self.ticks = (self.ticks or 0) + 1 end
            menus[name] = menu
            return menu
        end}
    end
    local modules = {DossierPolicy = Policy, I18n = {Strings = {}, t = function(_, key) return key end},
        AccessoryRollUI = menuModule("accessoryRoll"), DailyUI = menuModule("daily")}
    local require = function(module) return modules[module.Name] end
    local function executeClient()
-- MATCH_CHARACTER_SOURCE_INSERT
    end
    local ok, failure = pcall(executeClient)
    check(ok, "actual match client boot: " .. tostring(failure))
    local fixture = {player = player, pg = pg, rs = rs, session = session, reward = reward, run = run,
        script = script, requests = requests, warnings = warnings, profileEvent = profileEvent, menus = menus}
    function fixture:heartbeat() run.Heartbeat:Fire(1.1) end
    function fixture:advance(seconds)
        clock += seconds
        local waiting = {}
        local current = scheduled; scheduled = {}
        for _, job in ipairs(current) do
            if job.at <= clock then job.callback() else table.insert(waiting, job) end
        end
        for _, job in ipairs(waiting) do table.insert(scheduled, job) end
    end
    function fixture:answer(value, id, receipt) profileEvent.OnClientEvent:Fire(value, receipt, id) end
    function fixture:latest() return requests[#requests] end
    function fixture:open(mode) pg:FindFirstChild("SpyOpenDossier"):Fire(mode or "open") end
    function fixture:addAssets() return child("Folder", "SpyWardrobeAssets", rs) end
    return fixture
end
local function readyOpen(fixture, rolls, revision, available)
    fixture:answer(snapshot(rolls, revision, available), fixture:latest().id)
    fixture:open()
    fixture:answer(snapshot(rolls, revision, available), fixture:latest().id)
    return fixture.menus.accessoryRoll
end

-- The menu stays open through a result phase and a saved wallet award.
local f = boot({phase = "Hint"})
check(#f.requests == 1 and f:latest().kind == "dossierSync", "boot requests authoritative dossier")
local menu = readyOpen(f, 0, 1)
check(menu.visible and menu.opens == 1 and menu.ctx.profile().rolls == 0, "active-phase menu opens with empty wallet")
check(menu.ctx.state().tableId == "match", "active phase reaches menu as read-only")
check(menu.ctx.request("daily") == false and #f.requests == 2, "active-phase fresh changes do not send requests")
f.session:SetAttribute("RoundPhase", "Result")
f.reward.OnClientEvent:Fire({state = "saved", rewardRolls = {total = 3}})
f.player:SetAttribute("SpyRolls", 3)
check(menu.ctx.profile().rolls == 0, "reward signal does not invent a local wallet grant")
f:heartbeat()
check(#f.requests == 3 and f:latest().kind == "dossierSync", "result and reward subscriptions coalesce one refresh")
f:answer(snapshot(3, 2), f:latest().id)
check(menu.ctx.profile().rolls == 3 and menu.last.profile.rolls == 3 and not menu.ctx.pending(), "saved reward becomes usable through matching sync")
check(menu.visible and menu.opens == 1 and menu.ctx.state().tableId == nil, "result wallet refresh needs no reopen")

-- Each saved-wallet signal works without relying on the other subscription.
f.player:SetAttribute("SpyRolls", 4); f:heartbeat()
check(#f.requests == 4 and f:latest().kind == "dossierSync", "SpyRolls alone queues authoritative refresh")
f:answer(snapshot(4, 3), f:latest().id)
f.reward.OnClientEvent:Fire({state = "pending", rewardRolls = {total = 99}}); f:heartbeat()
check(#f.requests == 4, "uncommitted reward does not refresh or grant")
f.reward.OnClientEvent:Fire({state = "saved", rewardRolls = {total = 5}}); f:heartbeat()
check(#f.requests == 5 and f:latest().kind == "dossierSync", "saved Reward alone queues authoritative refresh")
f:answer(snapshot(5, 4), f:latest().id)

-- Refresh work waits for a paid action, and unrelated snapshots cannot unlock it.
local rollId = menu.ctx.request("accessoryRoll", "hair", "7-retained-roll")
check(rollId == "7-retained-roll" and f:latest().id == rollId and menu.ctx.pending(), "roll owns pending request ID")
f.player:SetAttribute("SpyRolls", 6)
f.reward.OnClientEvent:Fire({state = "saved", rewardRolls = {total = 6}})
local count = #f.requests; f:heartbeat()
check(#f.requests == count and f:latest().id == rollId, "queued refresh cannot replace in-flight roll ID")
f:answer(snapshot(99, 1), "late-sync")
check(menu.ctx.profile().rolls == 5 and menu.ctx.pending(), "stale sync neither replaces profile nor unlocks roll")
f:answer(snapshot(6, 5), "unrelated-profile")
check(menu.ctx.pending() and menu.last.pending, "unrelated ready profile cannot clear pending action")
f:heartbeat(); check(#f.requests == count, "unrelated profile cannot permit overlapping sync")
f:answer(snapshot(5, 6), rollId, {ok = true, code = "accessoryRolled"})
check(not menu.ctx.pending(), "matching roll response releases pending action")

-- A saved reward arriving during a sync must survive that older sync response.
f.player:SetAttribute("SpyRolls", 7); f:heartbeat()
local staleSyncId = f:latest().id
f.reward.OnClientEvent:Fire({state = "saved", rewardRolls = {total = 8}})
f:answer(snapshot(7, 7), staleSyncId)
count = #f.requests; f:heartbeat()
check(#f.requests == count + 1 and f:latest().kind == "dossierSync", "new reward during sync is not lost on older ready response")
f:answer(snapshot(8, 8), f:latest().id)
check(menu.ctx.profile().rolls == 8 and menu.opens == 1, "follow-up sync supplies newly committed wallet")

-- A lost refresh keeps its dirty generation and retries once transport is free.
f.player:SetAttribute("SpyRolls", 9); f:heartbeat()
local lostSyncId = f:latest().id
count = #f.requests; f:advance(18)
check(not menu.ctx.pending(), "lost sync releases transport after timeout")
f:heartbeat()
check(#f.requests == count + 1 and f:latest().kind == "dossierSync" and f:latest().id ~= lostSyncId, "lost dirty sync is retried with a fresh read request")
f:answer(snapshot(8, 8), lostSyncId)
check(menu.ctx.pending(), "late lost-sync response cannot unlock replacement sync")
f:answer(snapshot(9, 9), f:latest().id)
check(menu.ctx.profile().rolls == 9 and not menu.ctx.pending(), "replacement sync reconciles saved wallet")
f:open("toggle"); f:open("open")
count = #f.requests; f:advance(18); f:heartbeat()
check(#f.requests == count + 1 and f:latest().kind == "dossierSync", "lost open-time sync of cached profile remains retryable")
f:answer(snapshot(9, 10), f:latest().id)

-- An unavailable response cannot lower the accepted profile revision ceiling.
local r = boot({phase = "Result"})
local revisionMenu = readyOpen(r, 12, 12)
r:answer({ready = false}, "prefs-old")
check(revisionMenu.ctx.profile().ready and revisionMenu.ctx.profile().rolls == 12, "unrelated unavailable profile cannot evict ready cache")
r:answer(snapshot(11, 11), "old-ready-profile")
check(revisionMenu.ctx.profile().revision == 12, "delayed ready profile cannot roll back revision")
local unavailableSync = revisionMenu.ctx.request("dossierSync")
r:answer({ready = false}, unavailableSync, {ok = false, code = "profile_unavailable"})
check(not revisionMenu.ctx.profile().ready and not revisionMenu.ctx.pending(), "matching unavailable profile marks cache unavailable")
r:answer(snapshot(11, 11), "old-ready-after-unavailable")
check(not revisionMenu.ctx.profile().ready, "revision ceiling survives matching unavailable response")
r:heartbeat(); r:answer(snapshot(12, 12), r:latest().id)
check(revisionMenu.ctx.profile().ready and revisionMenu.ctx.profile().revision == 12, "current revision restores unavailable cache")

-- Appearance readiness changes refresh the same open menu's server eligibility.
local a = boot({phase = "Result"})
local appearanceMenu = readyOpen(a, 3, 1, false)
check(appearanceMenu.ctx.profile().accessoryRoll.categories[1].available == false, "loaded profile can still have unavailable avatar category")
a.player.Character:SetAttribute("SpyBaseReady", true)
a.player:SetAttribute("SpyAppearanceStatus", "ready")
a.player:SetAttribute("SpyAppearanceRevision", 1)
local assets = a:addAssets(); assets:SetAttribute("Revision", 1)
a:heartbeat()
check(#a.requests == 3 and a:latest().kind == "dossierSync", "avatar and newly added assets coalesce eligibility refresh")
a:answer(snapshot(3, 2, true), a:latest().id)
check(appearanceMenu.ctx.profile().accessoryRoll.categories[1].available and appearanceMenu.opens == 1, "avatar-ready sync enables category without reopening")
assets:SetAttribute("Revision", 2); a:heartbeat()
check(#a.requests == 4, "existing asset revision queues eligibility refresh")
a:answer(snapshot(3, 3), a:latest().id)
local oldCharacter = a.player.Character
local newCharacter = Instance.new("Model")
a.player.Character = newCharacter; a.player.CharacterAdded:Fire(newCharacter)
check(oldCharacter:GetAttributeChangedSignal("SpyBaseReady"):ActiveCount() == 0, "respawn disconnects old readiness observer")
a:heartbeat(); a:answer(snapshot(3, 4, false), a:latest().id)
count = #a.requests; oldCharacter:SetAttribute("SpyBaseReady", false); a:heartbeat()
check(#a.requests == count, "old character readiness cannot refresh new character")
newCharacter:SetAttribute("SpyBaseReady", true); a:heartbeat()
check(#a.requests == count + 1, "new character readiness observer is rebound")
a:answer(snapshot(3, 5, true), a:latest().id)
local oldAssets = assets
oldAssets:Destroy(); assets = a:addAssets(); assets:SetAttribute("Revision", 1)
check(oldAssets:GetAttributeChangedSignal("Revision"):ActiveCount() == 0, "asset replacement disconnects old revision observer")
a:heartbeat(); a:answer(snapshot(3, 6), a:latest().id)

-- The shared H action closes through the client and restores the modal attribute.
a:open("toggle")
check(not appearanceMenu.visible and a.player:GetAttribute("SpyCharacterMenuOpen") == false, "H toggle closes and clears global modal flag")
count = #a.requests; assets:SetAttribute("Revision", 3); a:heartbeat()
check(#a.requests == count, "closed menu does not issue asset refresh requests")
a:open("open"); check(appearanceMenu.visible and a.player:GetAttribute("SpyCharacterMenuOpen") == true, "H open restores modal flag")
a:answer(snapshot(3, 6), a:latest().id)
a.player:SetAttribute("SpyPhoneActive", true)
check(not appearanceMenu.visible and a.player:GetAttribute("SpyCharacterMenuOpen") == false, "phone activation closes menu and restores attribute")
a.player:SetAttribute("SpyPhoneActive", false); a:open("open")
a:answer(snapshot(3, 7), a:latest().id)
for index, attribute in ipairs({"SpyTradeOpen", "SpyReconnectBusy", "SpyBilliardsPlaying", "SpyCheckersPlaying"}) do
    a.player:SetAttribute(attribute, true)
    check(not appearanceMenu.visible and a.player:GetAttribute("SpyCharacterMenuOpen") == false, attribute .. " closes existing menu")
    local openCount = appearanceMenu.opens
    count = #a.requests; a:open("open")
    check(appearanceMenu.opens == openCount and #a.requests == count, attribute .. " prevents visible-button opening")
    a.player:SetAttribute(attribute, false); a:open("open")
    a:answer(snapshot(3, 7 + index), a:latest().id)
end

-- Teardown disconnects network, heartbeat, character and asset subscriptions.
local beforeDestroyProfile = appearanceMenu.ctx.profile()
count = #a.requests; a.script.Destroying:Fire()
check(a.player:GetAttribute("SpyCharacterMenuOpen") == false and appearanceMenu.destroyed == 1, "teardown closes and destroys modal")
check(a.run.Heartbeat:ActiveCount() == 0 and a.profileEvent.OnClientEvent:ActiveCount() == 0 and a.reward.OnClientEvent:ActiveCount() == 0, "teardown disconnects service and remote callbacks")
check(newCharacter:GetAttributeChangedSignal("SpyBaseReady"):ActiveCount() == 0 and assets:GetAttributeChangedSignal("Revision"):ActiveCount() == 0, "teardown disconnects readiness callbacks")
a:answer(snapshot(99, 99), "after-destroy"); a.player:SetAttribute("SpyRolls", 99); a:heartbeat()
check(#a.requests == count and appearanceMenu.ctx.profile() == beforeDestroyProfile, "destroyed client cannot consume profile or request refresh")

-- A retry with the same ID receives its own full timeout window.
local t = boot({phase = "Result"})
local timedMenu = readyOpen(t, 2, 1)
local timedId = timedMenu.ctx.request("accessoryRoll", "hair", "same-id-retry")
t:advance(5)
t:answer({ready = false}, timedId, {ok = false, code = "save_failed"})
check(not timedMenu.ctx.pending(), "uncertain response clears transport before UI retry")
check(timedMenu.ctx.request("accessoryRoll", "hair", timedId) == timedId, "retained retry sends same operation ID")
t:advance(13)
check(timedMenu.ctx.pending(), "old attempt timer cannot clear a newer same-ID retry")
t:advance(5)
check(not timedMenu.ctx.pending(), "current retry times out after its own window")

-- Missing remotes stop safely before constructing an unusable menu.
for _, options in ipairs({{noAction = true}, {noProfile = true}}) do
    local missing = boot(options)
    check(#missing.requests == 0 and #missing.warnings == 1 and missing.menus.accessoryRoll == nil, "missing remote fails gracefully without requests or panel")
end
print("Match character integration: " .. tostring(checks) .. " assertions passed")
