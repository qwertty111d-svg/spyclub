local bootTarget=game:GetService("Players").LocalPlayer
bootTarget:SetAttribute("SpyClientBootStatus","starting")
bootTarget:SetAttribute("SpyBuild","LOBBY V139 · CINEMA")
local bootOK,bootError=xpcall(function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local LOBBY_MIN_ZOOM=3.5
local LOBBY_MAX_ZOOM=10
local function applyLobbyCameraLimits()
	if player.CameraMinZoomDistance~=LOBBY_MIN_ZOOM then
		player.CameraMinZoomDistance=LOBBY_MIN_ZOOM
	end
	if player.CameraMaxZoomDistance~=LOBBY_MAX_ZOOM then
		player.CameraMaxZoomDistance=LOBBY_MAX_ZOOM
	end
end
applyLobbyCameraLimits()
player:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(applyLobbyCameraLimits)
player:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(applyLobbyCameraLimits)
player.CharacterAdded:Connect(applyLobbyCameraLimits)
local shared = ReplicatedStorage:WaitForChild("SpyShared")
local Config = require(shared:WaitForChild("Config"))
local I18n = require(shared:WaitForChild("I18n"))
local Catalog = require(shared:WaitForChild("Catalog"))
local Art = require(shared:WaitForChild("Art"))
local function optionalModule(name)
 return {create=function(...)
  local node=shared:WaitForChild(name,6)
  if not node then error("Missing optional panel "..name) end
  return require(node).create(...)
 end}
end
local AccessoryRollUI = optionalModule("AccessoryRollUI")
local PremiumRollShopUI = optionalModule("PremiumRollShopUI")
local ClubStoreUI = optionalModule("ClubStoreUI")
local SettingsUI = optionalModule("SettingsUI")
local ClubJournalUI = optionalModule("ClubJournalUI")
local PlayerProfileUI = optionalModule("PlayerProfileUI")
local ClientPreferences = {get=function() return {language="ru"} end,Changed=Instance.new("BindableEvent").Event}
task.spawn(function()
 local ok,result=pcall(function() return require(shared:WaitForChild("ClientPreferences",8)) end)
 if ok then ClientPreferences=result;pcall(result.start) else warn("[SpyBoot] Preferences: "..tostring(result)) end
end)
local DailyUI = optionalModule("DailyUI")
local DialogueUI = optionalModule("DialogueUI")
local OnboardingUI = optionalModule("OnboardingUI")
local HighStakesUI = optionalModule("HighStakesUI")
local GadgetUI = optionalModule("GadgetUI")
local VotingUI = optionalModule("VotingUI")
local UITheme = require(shared:WaitForChild("UITheme"))
local IconUI = require(shared:WaitForChild("IconUI"))
local HudController

local HttpService = game:GetService("HttpService")
local profileEvent = shared:WaitForChild("Profile")
local economyAction = shared:WaitForChild("EconomyAction")

---------------------------------------------------------------------
-- SPY CLUB / LOBBY AUDIO v1
-- These sounds use the SAME ClientPreferences controller as Settings.
-- SpyAudioCategory="Music" follows Music; "SFX" follows Sound effects.
---------------------------------------------------------------------
local oldLobbyAudio = SoundService:FindFirstChild("SPYLobbyAudio")
if oldLobbyAudio then oldLobbyAudio:Destroy() end

local lobbyAudioRoot = Instance.new("Folder")
lobbyAudioRoot.Name = "SPYLobbyAudio"
lobbyAudioRoot.Parent = SoundService

local function makeLobbySound(name, assetId, baseVolume, looped, category)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. tostring(assetId)
	sound.Volume = baseVolume
	sound.Looped = looped == true
	sound:SetAttribute("SpyAudioCategory", category or "SFX")
	sound.Parent = lobbyAudioRoot
	return sound
end

local lobbySounds = {
	-- Barely-there room presence. SFX slider owns ambience intentionally.
	Ambience = makeLobbySound("LobbyRoomTone", 80839920767164, 0.035, true, "SFX"),
	UIClick = makeLobbySound("UIClick", 113397864512278, 0.16, false, "SFX"),
	CaseUnlock = makeLobbySound("CaseUnlock", 9116323566, 0.28, false, "SFX"),
	CaseOpen = makeLobbySound("CaseOpen", 9120880880, 0.20, false, "SFX"),
	CaseReveal = makeLobbySound("CaseReveal", 9125644410, 0.20, false, "SFX"),
	Reward = makeLobbySound("Reward", 9125644410, 0.18, false, "SFX"),
	Coin = makeLobbySound("Coin", 5314631765, 0.22, false, "SFX"),
	Vincent = makeLobbySound("Vincent", 9120299506, 0.10, false, "SFX"),
}

local function playLobbySound(name, playbackSpeed)
	local sound = lobbySounds[name]
	if not sound or not sound.Parent then return end
	sound:Stop()
	sound.PlaybackSpeed = playbackSpeed or 1
	sound:Play()
end

task.defer(function()
	-- ClientPreferences observes descendants of SoundService, so saved slider
	-- values are already applied before/while these loops begin.
	if lobbySounds.Ambience.Parent and not lobbySounds.Ambience.IsPlaying then lobbySounds.Ambience:Play() end
end)

local language, languageInitialized = "ru", false
player:SetAttribute("SpyLanguage",language)
local profile = {ready=false, coins=0, rolls=0, owned={}, equipped={card="classic",effect="soft",trinket=""}}
local bindings = setmetatable({}, {__mode="k"})
local render, requestEconomy, localizeWorld, openPanel, voting, gadgets, dialogue, onboarding
local activeDock=nil
local dossierOpenRequested,dossierCategory=false,nil
local panels={}
local function callPanelMethod(modal, method)
	if type(modal) ~= "table" then return end
	local fn = modal[method]
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, modal)
	if not ok then warn("SpyClub panel "..tostring(method).." failed: "..tostring(err)) end
end
local pendingId=nil
local pendingAttempt=0
local clientInitialized,receivedState=false,false
local function updateClientReadiness()
	if clientInitialized and receivedState then player:SetAttribute("SpyClientReady",true) end
end
local function L(key,args) return I18n.t(language,key,args) end
local stateEvent = shared:WaitForChild("State")
local actionEvent = shared:WaitForChild("Action")
local noticeEvent = shared:WaitForChild("Notice")
local T=UITheme.Colors
local palette = {T.Accent, T.Lilac, T.Gold}
local colors = {bg=T.Background,panel=T.Surface,edge=T.Border,text=T.Text,muted=T.Muted,danger=T.Danger,gold=T.Gold,accent=T.Accent,raised=T.SurfaceRaised}
local theme, state, mobile, selectedTab = 1, {lobby = {}}, false, "Info"
local cardOpen, sentAt, lastRound, lastTable, lastPhase = false, 0, nil, nil, nil
local messageIds, messageCount, effectToken = {}, 0, 0
local cameraSaved, cameraTween, lastCameraTable = nil, nil, nil

local function make(class, parent, props)
	local object = Instance.new(class)
	for k, value in pairs(props or {}) do object[k] = value end
	if object:IsA("GuiObject") and not (props and props.ZIndex) and parent and parent:IsA("GuiObject") then object.ZIndex=parent.ZIndex+1 end
	object.Parent = parent
	return object
end
local function corner(parent, radius) make("UICorner", parent, {CornerRadius = UDim.new(0, radius or UITheme.Metrics.RadiusSmall)}) end
local function label(parent, text, size, position, fontSize, color)
	local object = make("TextLabel", parent, {Text = I18n.Strings[text] and L(text) or text, Size = size, Position = position, BackgroundTransparency = 1,
		TextColor3 = color or colors.text, TextSize = fontSize or UITheme.Text.Body, Font = Enum.Font.BuilderSansMedium,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center})
	if I18n.Strings[text] then bindings[object]=text end
	return object
end
local function button(parent, text, size, position, color)
	local b = make("TextButton", parent, {Text = I18n.Strings[text] and L(text) or text, Size = size, Position = position,
		BackgroundColor3 = color or colors.edge, TextColor3 = colors.text, TextSize = UITheme.Text.Button,
		Font = Enum.Font.BuilderSansBold, AutoButtonColor = true, BorderSizePixel = 0, TextWrapped = true})
	corner(b, 6)
	if I18n.Strings[text] then bindings[b]=text end
	return b
end
local function panel(parent, size, position)
	local p = make("Frame", parent, {Size = size, Position = position, BackgroundColor3 = colors.panel, BackgroundTransparency = .16, BorderSizePixel = 0})
	corner(p, UITheme.Metrics.Radius)
	make("UIStroke", p, {Color = colors.edge, Thickness = 1, Transparency = 0.68})
	return p
end

local playerGui=player:WaitForChild("PlayerGui",10)
if not playerGui then error("PlayerGui unavailable after 10 seconds") end
local manualHud=playerGui:FindFirstChild("HudGui") or playerGui:WaitForChild("HudGui",5)
-- StarterGui can arrive after the bounded fallback. Keep the same controls
-- already used by TableReservationClient instead of stacking a second copy.
playerGui.ChildAdded:Connect(function(child)
 if child.Name=="HudGui" and child:IsA("ScreenGui") and manualHud and child~=manualHud then child:Destroy() end
end)
if not manualHud then
 local template=game:GetService("StarterGui"):FindFirstChild("HudGui")
 if template then manualHud=template:Clone();manualHud.Parent=playerGui end
end
if not manualHud then error("HudGui template missing") end
manualHud.ResetOnSpawn=false
for _,child in ipairs(playerGui:GetChildren()) do
 if child.Name=="HudGui" and child~=manualHud and child:IsA("ScreenGui") then child:Destroy() end
end
local profileButton=manualHud.BottomDesk:FindFirstChild("Profile")
if not profileButton then
 profileButton=make("TextButton",manualHud.BottomDesk,{Name="Profile",Text="Статистика",TextSize=15,Font=Enum.Font.BuilderSansMedium,TextColor3=colors.text,BackgroundColor3=colors.panel,Size=UDim2.fromOffset(122,44),BorderSizePixel=0})
end
local hudView={resize=function() end,update=function() end,setActive=function() end,Destroy=function() end}
task.spawn(function()
 local ok,value=pcall(function()
  local module=shared:WaitForChild("HudController",6)
  if not module then error("HudController missing") end
  HudController=require(module)
  return HudController.new(manualHud,L)
 end)
 if ok then hudView=value;hudView:setActive(activeDock)
 else player:SetAttribute("SpyHudBootError",tostring(value));warn("SpyClub HUD styling: "..tostring(value)) end
end)
local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "SpyClubUI", DisplayOrder=10, ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local header=manualHud.TopStatus
local rankPill=header.Level
local rankText=rankPill.Value
-- Retire the authored coin pill without touching the saved legacy balance.
local coinPill=header:FindFirstChild("Coins")
if coinPill then coinPill.Visible=false end
local rollsPill=header:FindFirstChild("Rolls")
if not rollsPill then
 rollsPill=rankPill:Clone();rollsPill.Name="Rolls";rollsPill.Parent=header
 for _,child in ipairs(rollsPill:GetChildren())do
  if child:IsA("GuiButton") or child.Name=="Icon" then child:Destroy() end
 end
end
rollsPill.Visible=true
local rollsValue=rollsPill:WaitForChild("Value")
rollsValue:SetAttribute("SpyUserText",true)
local rollsHotspot=make("TextButton",rollsPill,{Name="RollsHotspot",Size=UDim2.fromScale(1,1),
 BackgroundTransparency=1,Text="",AutoButtonColor=false,Selectable=true,ZIndex=rollsPill.ZIndex+4})
local rollsPlus=label(rollsHotspot,"+",UDim2.fromOffset(20,24),UDim2.new(1,-22,.5,-12),20,colors.gold)
rollsPlus.TextXAlignment=Enum.TextXAlignment.Center
rollsHotspot.Activated:Connect(function()if openPanel then openPanel("premiumShop")end end)
local profileHotspot=make("TextButton",rankPill,{Name="ProfileHotspot",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=rankPill.ZIndex+3})
local function setRollDisplay(value)
 local valid=type(value)=="number" and value==value and value>=0 and value<math.huge
 rollsValue.Text=(valid and tostring(math.floor(value))or"…").." Rolls"
end
setRollDisplay(nil)
hudView:resize()
-- Compatibility labels stay out of the visual tree; state code can still update them safely.
local logo=label(gui,"",UDim2.fromOffset(0,0),UDim2.new(),1,colors.text); logo.Visible=false
local subtitle=label(gui,"",UDim2.fromOffset(0,0),UDim2.new(),1,colors.muted); subtitle.Visible=false
local lobbyCounts=label(gui,"",UDim2.fromOffset(0,0),UDim2.new(),1,colors.muted); lobbyCounts.Visible=false
local missionText=label(gui,"",UDim2.fromOffset(0,0),UDim2.new(),1,colors.muted); missionText.Visible=false

-- Top transient messages share one layout rail so onboarding and phase banners never overlap.
local hintRail=make("Frame",gui,{Name="HintRail",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,64),Size=UDim2.new(1,-160,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=28})
make("UISizeConstraint",hintRail,{MinSize=Vector2.new(280,0),MaxSize=Vector2.new(560,320)})
make("UIListLayout",hintRail,{Padding=UDim.new(0,8),HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})

local sideDock=manualHud.BottomDesk
local function setDockActive(name)
	activeDock=name
	player:SetAttribute("SpyCharacterMenuOpen",name=="accessoryRoll"or name=="premiumShop"or name=="clubStore")
	hudView:setActive(name)
end
player:SetAttribute("SpyCharacterMenuOpen",false)
local shopButton=sideDock.Shop
local collectionButton=sideDock.Inventory
local dailyButton=sideDock.Daily
local themeButton=sideDock.Settings
local dailyBadge=dailyButton.NotificationBadge

local main = panel(gui, UDim2.new(1, -180, 0, 326), UDim2.new(0.5, 0, 1, -16))
main.AnchorPoint, main.Visible = Vector2.new(0.5, 1), false
make("UISizeConstraint", main, {MaxSize = Vector2.new(860, 430)})
local phaseTitle = label(main, "Waiting", UDim2.new(1, -124, 0, 32), UDim2.fromOffset(18, 8), 17, palette[theme])
phaseTitle.Font = Enum.Font.BuilderSansBold
local timer = label(main, "", UDim2.fromOffset(86, 32), UDim2.new(1, -104, 0, 8), 23)
timer.TextXAlignment = Enum.TextXAlignment.Right
local progress = make("Frame", main, {BackgroundColor3 = palette[theme], BorderSizePixel = 0, Position = UDim2.fromOffset(18, 47), Size = UDim2.new(1, -36, 0, 2)})
local body = make("Frame", main, {BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 64), Size = UDim2.new(1, -36, 1, -126)})
local info = make("Frame", body, {BackgroundTransparency = 1})
local chat = make("Frame", body, {BackgroundTransparency = 1})
local votes = make("Frame", body, {BackgroundTransparency = 1})
local panes = {Info = info, Chat = chat, Vote = votes}
local infoTitle = label(info, "secretCard", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 0), 11, colors.muted)
local card = button(info, "waitingCard", UDim2.new(1, 0, 0, 92), UDim2.fromOffset(0, 30), colors.bg)
card.TextSize = 22
card.TextTransparency = 1
local skinHost=make("Frame",card,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=1})
local skinShade=make("Frame",card,{Size=UDim2.fromScale(1,1),BackgroundColor3=colors.bg,BackgroundTransparency=0.3,BorderSizePixel=0,ZIndex=2})
corner(skinShade,10)
local cardText=label(card,"",UDim2.new(1,-18,1,-12),UDim2.fromOffset(9,6),21)
card:SetAttribute("SpyUserText",true);cardText:SetAttribute("SpyUserText",true)
cardText.Font,cardText.TextXAlignment,cardText.ZIndex=Enum.Font.BuilderSansBold,Enum.TextXAlignment.Center,3
local currentSkin=nil
local cardStroke = make("UIStroke", card, {Color = palette[theme], Transparency = 0.4})
local instruction = label(info, "", UDim2.new(1, 0, 1, -132), UDim2.fromOffset(0, 130), 14, colors.muted)
instruction.TextYAlignment = Enum.TextYAlignment.Top

local chatTitle = label(chat, "tableChat", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 0), 11, colors.muted)
local log = make("ScrollingFrame", chat, {Size = UDim2.new(1, 0, 1, -77), Position = UDim2.fromOffset(0, 28),
	BackgroundColor3 = colors.bg, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y})
corner(log, 10)
make("UIPadding", log, {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
local logLayout = make("UIListLayout", log, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
local input = make("TextBox", chat, {Size = UDim2.new(1, -53, 0, 42), Position = UDim2.new(0, 0, 1, -42),
	BackgroundColor3 = colors.bg, BorderSizePixel = 0, Text = "", PlaceholderText = L("typeHere"),
	PlaceholderColor3 = colors.muted, TextColor3 = colors.text, TextSize = 15, Font = Enum.Font.BuilderSansMedium,
	ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left})
corner(input, 10)
make("UIPadding", input, {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
local send = button(chat, "→", UDim2.fromOffset(45, 42), UDim2.new(1, -45, 1, -42))
local footer = make("Frame", main, {Size = UDim2.new(1, -36, 0, 46), Position = UDim2.new(0, 18, 1, -54), BackgroundTransparency = 1})
local tableLabel = label(footer, "", UDim2.new(1, -150, 1, 0), UDim2.fromOffset(0, 0), 12, colors.muted)
local leave = button(footer, "leave", UDim2.fromOffset(90, 44), UDim2.new(1, -90, 0, 0))
local tabs = {}
for i, data in ipairs({{"Info", "tabRole"}, {"Chat", "tabChat"}, {"Vote", "tabPlayers"}}) do
	tabs[data[1]] = button(footer, data[2], UDim2.new(0.23, -6, 0, 44), UDim2.new((i - 1) * 0.23, 0, 0, 0))
end

local toast = panel(gui, UDim2.new(1, -40, 0, 86), UDim2.new(0.5, 0, 0, 108))
toast.AnchorPoint, toast.Visible, toast.ZIndex = Vector2.new(0.5, 0), false, 95
toast.BackgroundTransparency=.08
make("UISizeConstraint", toast, {MaxSize = Vector2.new(680, 86)})
local toastScale=make("UIScale",toast,{Scale=1})
local toastText = label(toast, "", UDim2.new(1, -28, 1, -16), UDim2.fromOffset(14, 8), 14)
toastText.ZIndex = 96
local noticeToken = 0
local function toastTargetY()
	return hintRail.Position.Y.Offset + hintRail.AbsoluteSize.Y + 8
end
local function notify(message)
	noticeToken += 1
	local token = noticeToken
	toastText.Text=message
	toast.Visible=true
	local targetY=toastTargetY()
	toast.Position=UDim2.new(.5,0,0,targetY-16)
	toast.BackgroundTransparency=.42
	toastText.TextTransparency=1
	toastScale.Scale=.96
	TweenService:Create(toast,TweenInfo.new(.22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,0,targetY),BackgroundTransparency=.08}):Play()
	TweenService:Create(toastText,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
	TweenService:Create(toastScale,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	task.delay(3.8,function()
		if noticeToken~=token or not toast.Visible then return end
		TweenService:Create(toast,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Position=UDim2.new(.5,0,0,toastTargetY()-12),BackgroundTransparency=.5}):Play()
		TweenService:Create(toastText,TweenInfo.new(.14,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{TextTransparency=1}):Play()
		TweenService:Create(toastScale,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Scale=.97}):Play()
		task.delay(.19,function() if noticeToken==token then toast.Visible=false end end)
	end)
end
hintRail:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if toast.Visible then
		TweenService:Create(toast,TweenInfo.new(.14,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,0,toastTargetY())}):Play()
	end
end)

local phaseBanner=panel(hintRail,UDim2.new(1,0,0,54),UDim2.new())
make("UISizeConstraint",phaseBanner,{MaxSize=Vector2.new(360,54),MinSize=Vector2.new(260,54)})
phaseBanner.LayoutOrder=2; phaseBanner.Visible=false; phaseBanner.ZIndex=30; phaseBanner.BackgroundTransparency=.08
local phaseScale=make("UIScale",phaseBanner,{Scale=.96})
local phaseBannerText=label(phaseBanner,"",UDim2.new(1,-24,1,0),UDim2.fromOffset(12,0),15,colors.text); phaseBannerText.TextXAlignment=Enum.TextXAlignment.Center; phaseBannerText.Font=Enum.Font.BuilderSansBold; phaseBannerText.TextWrapped=false; phaseBannerText.ZIndex=33
local phaseToken=0
local function showPhaseBanner(text,color)
	phaseToken+=1; local token=phaseToken
	phaseBannerText.Text=text; phaseBannerText.TextColor3=color or colors.gold
	phaseBanner.BackgroundTransparency=.45; phaseBannerText.TextTransparency=1; phaseScale.Scale=.96; phaseBanner.Visible=true
	TweenService:Create(phaseBanner,TweenInfo.new(.24,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency=.08}):Play()
	TweenService:Create(phaseBannerText,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
	TweenService:Create(phaseScale,TweenInfo.new(.24,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	task.delay(1.25,function()
		if phaseToken~=token then return end
		TweenService:Create(phaseBanner,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{BackgroundTransparency=.55}):Play()
		TweenService:Create(phaseBannerText,TweenInfo.new(.14,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{TextTransparency=1}):Play()
		task.delay(.2,function() if phaseToken==token then phaseBanner.Visible=false end end)
	end)
end

---------------------------------------------------------------------
-- SPY_NATIVE_CHAT_V505
-- Roblox owns the visible chat window, filtering, privacy and bubbles.
-- SPY CLUB only chooses the server-wide TextChannel.
---------------------------------------------------------------------
-- NativeChatBootstrap is the sole presentation writer.
local lobbyChat={resize=function()end,update=function()end}

---------------------------------------------------------------------
-- Preset buttons use the same filtered native channel as typed messages.
---------------------------------------------------------------------
local QUICK_CHAT_ORDER={{"hello","Привет"},{"ready","Готов"},{"wait","Подождите"},{"join","Иду к столу"},{"back","Я вернулся"},{"thanks","Спасибо"}}
local quickButton=make("TextButton",gui,{Name="QuickChatButton",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-18),Size=UDim2.fromOffset(150,44),BackgroundColor3=colors.panel,BorderSizePixel=0,Text="БЫСТРЫЕ ФРАЗЫ",TextColor3=colors.gold,TextSize=11,Font=Enum.Font.BuilderSansBold,AutoButtonColor=true,ZIndex=70})
corner(quickButton,3)
local quickPanel=make("ScrollingFrame",gui,{Name="QuickChatPanel",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-68),Size=UDim2.fromOffset(304,174),BackgroundColor3=Color3.fromRGB(18,20,23),BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.fromOffset(0,174),ClipsDescendants=true,Visible=false,ZIndex=70})
corner(quickPanel,3)
make("UIStroke",quickPanel,{Color=Color3.fromRGB(100,100,100),Transparency=.7,Thickness=1})
make("UIPadding",quickPanel,{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
local quickGrid=make("UIGridLayout",quickPanel,{CellSize=UDim2.fromOffset(137,44),CellPadding=UDim2.fromOffset(8,7),SortOrder=Enum.SortOrder.LayoutOrder})
for index,entry in ipairs(QUICK_CHAT_ORDER) do
 local phraseId,title=entry[1],entry[2]
 local b=make("TextButton",quickPanel,{Name="Quick_"..phraseId,Text=title,BackgroundColor3=colors.raised,BorderSizePixel=0,TextColor3=colors.text,TextSize=11,Font=Enum.Font.BuilderSansMedium,LayoutOrder=index,AutoButtonColor=true,ZIndex=72})
 corner(b,6)
 b.Activated:Connect(function()
  local preset=gui.Parent and gui.Parent:FindFirstChild("SpyChatPreset")
  if preset and preset:IsA("BindableEvent") then preset:Fire(phraseId) end
  quickPanel.Visible=false
 end)
end
quickButton.Activated:Connect(function()quickPanel.Visible=not quickPanel.Visible end)

local function resize()
	local relay=(ReplicatedStorage:GetAttribute("SpyChatTransport")=="server_filtered" or ReplicatedStorage:GetAttribute("SpyChatTransport")=="text_channel")
	if relay and selectedTab=="Chat" then selectedTab="Info" end
	local viewport = gui.AbsoluteSize
	mobile = game:GetService("UserInputService").TouchEnabled or viewport.X < 760 or viewport.Y < 500
    if hudView.setQuickChat then
        hudView:setQuickChat(quickButton, quickPanel)
    else
        quickButton.Visible = false
    end
    local quickWidth=math.min(304,viewport.X-24)
    quickPanel.Size=UDim2.fromOffset(quickWidth,math.min(174,math.max(44,viewport.Y-24)))
    quickGrid.CellSize=UDim2.fromOffset(math.max(44,math.floor((quickWidth-28)/2)),44)
	hintRail.Position=UDim2.new(.5,0,0,64)
	hintRail.Size=UDim2.new(1,-(mobile and 32 or 160),0,0)
	hudView:resize()
	logo.Visible=false; subtitle.Visible=false; lobbyCounts.Visible=false; missionText.Visible=false
	for _,modal in pairs(panels) do callPanelMethod(modal,"resize") end
	if mobile then
		main.Size = UDim2.new(1, -24, 0, math.min(viewport.Y - 72, math.min(430, math.max(286, viewport.Y * 0.56))))
	else
		main.Size = UDim2.new(1, -180, 0, math.min(326, math.max(270, viewport.Y * 0.52)))
	end
	header.Visible = viewport.Y >= 430 or state.tableId == nil
	for name, pane in pairs(panes) do
		pane.Visible = (not mobile or selectedTab == name) and (name~="Chat" or not relay)
		if mobile then pane.Size, pane.Position = UDim2.fromScale(1, 1), UDim2.fromScale(0, 0) end
	end
	if not mobile then
		info.Size, info.Position = UDim2.fromScale(0.27, 1), UDim2.fromScale(0, 0)
		chat.Size, chat.Position = UDim2.fromScale(0.43, 1), UDim2.fromScale(0.29, 0)
		votes.Size, votes.Position = UDim2.fromScale(0.26, 1), UDim2.fromScale(0.74, 0)
		if relay then
			info.Size,info.Position=UDim2.fromScale(.47,1),UDim2.fromScale(0,0)
			votes.Size,votes.Position=UDim2.fromScale(.50,1),UDim2.fromScale(.50,0)
		end
	end
	tableLabel.Visible = not mobile
	for name, tab in pairs(tabs) do
		tab.Visible = mobile and (name~="Chat" or not relay)
		if relay and name~="Chat" then
			tab.Size=UDim2.new(.32,0,0,44)
			tab.Position=UDim2.new(name=="Info" and 0 or .35,0,0,0)
		end
		tab.BackgroundColor3 = selectedTab == name and palette[theme] or colors.edge
		tab.TextColor3 = selectedTab == name and colors.bg or colors.text
	end
	leave.Size = mobile and UDim2.new(0.29, 0, 0, 44) or UDim2.fromOffset(90, 44)
	leave.Position = mobile and UDim2.new(0.71, 0, 0, 0) or UDim2.new(1, -90, 0, 0)
	lobbyChat.resize()

end
for name, tab in pairs(tabs) do
	tab.Activated:Connect(function() selectedTab = name resize() end)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
ReplicatedStorage:GetAttributeChangedSignal("SpyChatTransport"):Connect(resize)

local function personName(id)
	for _, p in ipairs(state.people or {}) do if p.id == id then return p.name end end
	return L("player")
end
local function allowedToSpeak()
	if state.studioSimulation then return false end
	return state.tableId and (state.phase == "Waiting" or state.phase == "Discuss" or state.phase == "Result"
		or (state.phase == "Hint" and state.turn == player.UserId))
end
local function clearChat()
	messageIds, messageCount = {}, 0
	for _, child in ipairs(log:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
end
local function updateCard()
	local skin=Catalog.ById[profile.equipped and profile.equipped.card or "classic"] or Catalog.ById.classic
	if currentSkin~=skin.id then
		currentSkin=skin.id
		for _,child in ipairs(skinHost:GetChildren()) do child:Destroy() end
		Art.draw(skinHost,skin)
	end
	local frameItem=Catalog.ById[profile.equipped and profile.equipped.frame or ""]
	cardStroke.Color=frameItem and Art.color(frameItem) or palette[theme]
	cardStroke.Thickness=frameItem and 3 or 1
	cardStroke.Transparency=frameItem and 0.05 or 0.4
	skinShade.BackgroundTransparency=state.card and cardOpen and 0.12 or 0.28
	if state.result then
		infoTitle.Text=L(state.result.caught and "caughtTitle" or "escapedTitle")
		card.Text=personName(state.result.spyId).."\n"..I18n.word(language,state.result.word)
		card.TextColor3=state.result.caught and palette[theme] or colors.danger
	elseif state.card and cardOpen then
		infoTitle.Text=L(state.card.role=="spy" and "spyRole" or "agentRole")
		card.Text=state.card.word and I18n.word(language,state.card.word) or L("unknown")
		card.TextColor3=state.card.role=="spy" and colors.danger or Art.color(skin)
	else
		infoTitle.Text,card.TextColor3=L("secretCard"),colors.text
		card.Text=L(state.card and "openRole" or "waitingCard")
	end
	cardText.Text,cardText.TextColor3=card.Text,card.TextColor3
end

card.Activated:Connect(function() cardOpen = not cardOpen updateCard() end)

local function focusTable(id)
	if lastCameraTable == id then return end
	lastCameraTable = id
	local camera = workspace.CurrentCamera
	if cameraTween then cameraTween:Cancel() end
	if not id then
		if cameraSaved then
			camera.CameraType, camera.FieldOfView = cameraSaved.type, player:GetAttribute("SpyFOV") or cameraSaved.fov
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
			cameraSaved = nil
		end
		return
	end
	if not cameraSaved then cameraSaved = {type = camera.CameraType, fov = camera.FieldOfView} end
	for _, def in ipairs(Config.Tables) do
		if def.id == id then
			camera.CameraType = Enum.CameraType.Scriptable
			local center = Vector3.new(def.x, 2, def.z)
			local target = CFrame.lookAt(center + Vector3.new(0, 16, -19), center + Vector3.new(0, -6, 0))
			local fov = player:GetAttribute("SpyFOV") or 70
			if player:GetAttribute("SpyReducedMotion") or player:GetAttribute("SpyCameraMotion")==false then
				camera.CFrame, camera.FieldOfView = target, fov
			else
				cameraTween = TweenService:Create(camera, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CFrame=target,FieldOfView=fov})
				cameraTween:Play()
			end
		end
	end
end

local function resultEffect()
	if player:GetAttribute("SpyEffects")==false or player:GetAttribute("SpyReducedMotion")==true then return end
	effectToken = effectToken + 1
	local token = effectToken
	local cosmetic=Catalog.ById[profile.equipped and profile.equipped.effect or "soft"] or Catalog.ById.soft
	local color = Art.color(cosmetic)
	cardStroke.Color = color
	local amount=cosmetic.id=="soft" and 8 or (cosmetic.id=="embers" and 36 or 24)
	for i = 1, amount do
		local spark = make("Frame", gui, {Size = UDim2.fromOffset(5, 12), Position = UDim2.fromScale(math.random(), -0.05),
			BackgroundColor3 = color, BorderSizePixel = 0, Rotation = math.random(-80, 80), ZIndex = 15})
		TweenService:Create(spark, TweenInfo.new(1.3 + math.random(), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Position = UDim2.fromScale(math.random(), 1.1), Rotation = math.random(-240, 240), BackgroundTransparency = 1}):Play()
		task.delay(2.5, function() spark:Destroy() end)
	end
	task.delay(3, function() if effectToken == token then updateCard() end end)
end

render = function(newState)
	state = newState
	if state.profile and (not state.profile.ready or not profile.ready or (state.profile.revision or 0)>=(profile.revision or 0)) then
		profile=state.profile
	end
	if profile.ready and not languageInitialized then language=profile.language or "ru" languageInitialized=true player:SetAttribute("SpyLanguage",language) end
	for object,key in pairs(bindings) do if object.Parent then object.Text=L(key) end end
	setRollDisplay(profile.ready and profile.rolls or nil)
	local titleItem=Catalog.ById[profile.equipped and profile.equipped.title or ""]
	rankText.Text=profile.ready and L("level",{n=profile.level or 1}) or L("profileLoading")
	dailyBadge.Visible=profile.daily and (profile.daily.available or os.time()>=(profile.daily.nextAt or math.huge)) or false
	subtitle.Text=L(profile.studio and "studio" or "tagline")
	main.Visible=state.tableId~=nil
	lobbyChat.update()
	hudView:update(state.tableId~=nil)
	local counts={}
	for _,t in ipairs(state.lobby or {}) do counts[#counts+1]=L(t.id).."  "..t.count.."/"..t.capacity end
	lobbyCounts.Text=table.concat(counts,"   ·   ")
	missionText.Text=profile.ready and (profile.milestone and L("missionDone") or (L("missionProgress",{n=math.min(profile.rounds or 0,3)}).." · +60 ◈")) or L("welcome")
	if localizeWorld then localizeWorld() end
	for _,modal in pairs(panels) do callPanelMethod(modal,"update") end
	if onboarding then pcall(onboarding.update,onboarding,profile,state) end
	if state.roundId ~= lastRound or state.tableId ~= lastTable then
		clearChat()
		cardOpen = state.phase == "Role"
		lastRound, lastTable = state.roundId, state.tableId
	end
	focusTable(state.tableId)
	if not state.tableId then lastPhase = nil resize() return end
	if state.phase ~= lastPhase then
		if state.phase and state.phase~="Waiting" then showPhaseBanner(L(state.phase),state.phase=="Vote" and colors.gold or palette[theme]) end
		if state.phase == "Hint" or state.phase == "Discuss" then selectedTab = "Chat" cardOpen = false
		elseif state.phase == "Vote" then selectedTab = "Vote"
		else selectedTab = "Info" end
		if state.phase == "Result" then resultEffect() end
	end
	lastPhase = state.phase
	phaseTitle.Text = L(state.phase=="Vote" and state.runoff and "runoff" or state.phase)
	tableLabel.Text = L(state.tableId) .. "  •  " .. #state.people .. "/" .. state.capacity
	if state.phase=="Hint" then
		local mine=state.turn==player.UserId
		instruction.Text=L(mine and "myTurn" or "theirTurn",{name=personName(state.turn)}).."\n"..L("lap",{n=state.lap,total=state.hintLaps})
		chatTitle.Text=L(mine and "myClue" or "speaking",{name=personName(state.turn)})
	elseif state.phase=="Discuss" then instruction.Text,chatTitle.Text=L("discussionHint"),L("everyone")
	elseif state.phase=="Vote" then
		instruction.Text=state.myVote and L("voted") or (state.runoff and L("runoffHint") or L("voteHint",{n=state.capacity==3 and 2 or 3}))
		chatTitle.Text=L("timeToVote")
	elseif state.phase=="Result" then
		instruction.Text=L(state.result.reason).."\n"..L("nextRound")
		chatTitle.Text=L("afterRound")
	else
		instruction.Text=L(state.phase=="Waiting" and "waitFull" or "rememberRole")
		chatTitle.Text=L("tableChat")
	end
	updateCard()
	input.TextEditable = allowedToSpeak() == true
	input.PlaceholderText = allowedToSpeak() and L("typeHere") or L("waitTurn")
	if state.studioSimulation then input.PlaceholderText, chatTitle.Text = L("noTestChat"), L("studio") end
	send.BackgroundColor3 = allowedToSpeak() and palette[theme] or colors.edge
	send.TextColor3 = allowedToSpeak() and colors.bg or colors.muted
	if voting then pcall(voting.update,voting,state) end
	resize()
end

local sending = false
local function sendMessage()
	if (ReplicatedStorage:GetAttribute("SpyChatTransport")=="server_filtered" or ReplicatedStorage:GetAttribute("SpyChatTransport")=="text_channel") then return end
	if sending or not allowedToSpeak() or os.clock() - sentAt < 1.3 then return end
	local text = input.Text:match("^%s*(.-)%s*$") or ""
	if text == "" then return end
	local length = utf8.len(text)
	if not length or length > 160 then notify(L("shortClue")) return end
	local folder = TextChatService:FindFirstChild("TextChannels")
	local channel = folder and folder:FindFirstChild(state.channelName or "")
	if not channel then notify(L("chatConnecting")) return end
	sending, sentAt = true, os.clock()
	input.Text = ""
	local ok, response = pcall(function() return channel:SendAsync(text) end)
	sending = false
	if not ok or not response or (response.Status ~= Enum.TextChatMessageStatus.Success and response.Status ~= Enum.TextChatMessageStatus.Sending) then
		notify(L("chatFailed"))
	end
end
send.Activated:Connect(sendMessage)
input.FocusLost:Connect(function(enterPressed) if enterPressed then sendMessage() end end)
TextChatService.MessageReceived:Connect(function(message)
	if (ReplicatedStorage:GetAttribute("SpyChatTransport")=="server_filtered" or ReplicatedStorage:GetAttribute("SpyChatTransport")=="text_channel") then return end
	if not state.tableId or not message.TextChannel or message.TextChannel.Name ~= state.channelName then return end
	if message.Status ~= Enum.TextChatMessageStatus.Success or not message.TextSource then return end
	if messageIds[message.MessageId] then return end
	messageIds[message.MessageId] = true
	messageCount = messageCount + 1
	local sender = Players:GetPlayerByUserId(message.TextSource.UserId)
	local name = sender and sender.DisplayName or L("player")
	-- ONLY the final TextChatService delivery enters this UI. Never use RemoteEvents for chat text.
	local line = label(log, name .. ":  " .. message.Text, UDim2.new(1, -4, 0, 0), UDim2.new(), 14)
	line.AutomaticSize, line.LayoutOrder, line.TextYAlignment = Enum.AutomaticSize.Y, messageCount, Enum.TextYAlignment.Top
	line.RichText = false
	if messageCount > 60 then
		for _, old in ipairs(log:GetChildren()) do
			if old:IsA("TextLabel") and old.LayoutOrder <= messageCount - 60 then old:Destroy() end
		end
	end
	task.defer(function() log.CanvasPosition = Vector2.new(0, math.max(0, logLayout.AbsoluteContentSize.Y - log.AbsoluteSize.Y + 20)) end)
end)

local leaveConfirmUntil = 0
leave.Activated:Connect(function()
	if state.roundId and state.phase ~= "Waiting" and state.phase ~= "Result" and os.clock() > leaveConfirmUntil then
		leaveConfirmUntil = os.clock() + 4
		notify(L("leaveConfirm"))
		return
	end
	actionEvent:FireServer("Leave")
end)
requestEconomy=function(kind,value,existingRequestId)
	if pendingId then notify(L("slowDown")) return false end
	local requestId=existingRequestId or HttpService:GenerateGUID(false)
	pendingAttempt+=1
	local attempt=pendingAttempt
	pendingId=requestId
	for _,modal in pairs(panels) do callPanelMethod(modal,"update") end
	economyAction:FireServer(kind,value,requestId)
	task.delay(18,function()
		if pendingId==requestId and pendingAttempt==attempt then
			pendingId=nil
			for _,modal in pairs(panels) do callPanelMethod(modal,"update") end
			notify(L("save_failed"))
		end
	end)
	return requestId
end
local function closePanels(except)
	for name,modal in pairs(panels) do if name~=except then callPanelMethod(modal,"close") end end
end
local ctx={gui=gui,player=player,hintRail=hintRail,make=make,panel=panel,label=label,button=button,L=L,colors=colors,userId=player.UserId,
	profile=function() return profile end,state=function() return state end,language=function() return language end,
	request=requestEconomy,notify=notify,pending=function() return pendingId~=nil end,closePanels=closePanels,
	closeDialogue=function() if dialogue then dialogue:close() end end,
	setActivePanel=setDockActive,getActivePanel=function() return activeDock end,
	openPanel=function(name,categoryId,queueOnLoad) openPanel(name,categoryId) end,openNotes=function() if gadgets then gadgets:openNotes() end end,
	openVincent=function(node) if dialogue then playLobbySound("Vincent",1.02); dialogue:open(node or "start") end end,
	dialogueVisible=function() return dialogue and dialogue.visible end,
	notesUnlocked=function() return gadgets and gadgets.unlocked end,
	playSound=function(name,speed) playLobbySound(name,speed) end,
	emote=function() actionEvent:FireServer("Emote") end,
	vote=function(id) actionEvent:FireServer("Vote",id) end}
-- Per-panel failure isolation: a broken panel cannot stop state subscription.
local function createOptional(key,module,assign,...)
 local arguments=table.pack(...)
 task.spawn(function()
  for attempt=1,2 do
   local ok,result=pcall(module.create,ctx,table.unpack(arguments,1,arguments.n))
   if ok and type(result)=="table" then
    if key then panels[key]=result end
    if assign then assign(result) end
    if key=="accessoryRoll" and dossierOpenRequested then
     task.defer(function()
      if not dossierOpenRequested or not openPanel then return end
      if player:GetAttribute("SpyTradeOpen")==true or player:GetAttribute("SpyPhoneActive")==true then
       dossierOpenRequested,dossierCategory=false,nil;return
      end
      openPanel("accessoryRoll",dossierCategory)
     end)
    end
    player:SetAttribute("SpyPanel_"..tostring(key or "service"),"ready")
    if receivedState then pcall(render,state) end
    return
   end
   warn("[SpyBoot] Panel "..tostring(key)..": "..tostring(result))
   if attempt==1 then task.wait(2) end
  end
  player:SetAttribute("SpyPanel_"..tostring(key or "service"),"failed")
 end)
end
createOptional("accessoryRoll",AccessoryRollUI)
createOptional("premiumShop",PremiumRollShopUI)
createOptional("clubStore",ClubStoreUI)
createOptional("gadgets",GadgetUI,function(p) gadgets=p end)
createOptional("dialogue",DialogueUI,function(p) dialogue=p end,function() if onboarding then onboarding:markTalked();onboarding:update(profile,state) end end)
createOptional("onboarding",OnboardingUI,function(p) onboarding=p end)
createOptional("settings",SettingsUI)
createOptional("daily",DailyUI)
createOptional("highstakes",HighStakesUI)
createOptional("journal",ClubJournalUI)
createOptional("profile",PlayerProfileUI)
createOptional("voting",VotingUI,function(p) voting=p end,votes)
task.spawn(function()
 local mod=shared:WaitForChild("ClientPreferences",8)
 if not mod then return end
 local ok,result=pcall(require,mod)
 if ok then result.Changed:Connect(function()
  local nextLanguage=result.get().language
  if nextLanguage~=language then language=nextLanguage;languageInitialized=true;pcall(render,state) end
 end) end
end)
local function panelName(name,categoryId)
 if name=="shop"then return categoryId and Catalog.Cases[categoryId]and"accessoryRoll"or"clubStore"end
 if name=="inventory" or name=="collection" or name=="character" then return "accessoryRoll" end
 return name
end
openPanel=function(name,categoryId,queueOnLoad)
 name=panelName(name,categoryId)
 if name=="premiumShop"or name=="clubStore"then
  for _,flag in ipairs({"SpyPhoneActive","SpyTradeOpen","SpyTeleporting","SpyEntryPending","SpyEntryActive"})do
   if player:GetAttribute(flag)then return false end
  end
 end
 if name=="accessoryRoll" then
  -- Authored shop hooks can still pass a legacy case ID.
  if categoryId and Catalog.Cases[categoryId] then categoryId=categoryId=="atelier"and"hair"or nil end
  if player:GetAttribute("SpyEntryPending")or player:GetAttribute("SpyEntryActive")then
   dossierOpenRequested,dossierCategory=false,nil;return false
  end
  local target=panels.accessoryRoll
  if not target then
   if queueOnLoad~=false then dossierOpenRequested,dossierCategory=true,categoryId end
   notify(language=="en"and"Character dossier is loading…"or language=="zh"and"角色档案正在加载…"or"Досье персонажа загружается…")
   return false
  end
  dossierOpenRequested,dossierCategory=false,nil
  local ok,result=pcall(target.open,target,categoryId)
  if not ok then warn("[SpyClub] Character dossier: "..tostring(result)) end
  return ok and result~=false
 end
 dossierOpenRequested,dossierCategory=false,nil
 local target=panels[name]
 if target then callPanelMethod(target,"open");return true end
 notify(language=="en"and"Panel is still loading. Try again."or"Панель ещё загружается. Попробуй снова.")
 return false
end
for _,flag in ipairs({"SpyPhoneActive","SpyTradeOpen","SpyTeleporting","SpyEntryPending","SpyEntryActive"})do
 player:GetAttributeChangedSignal(flag):Connect(function()
  if player:GetAttribute(flag)then
   dossierOpenRequested,dossierCategory=false,nil
   callPanelMethod(panels.accessoryRoll,"close")
   callPanelMethod(panels.premiumShop,"close")
   callPanelMethod(panels.clubStore,"close")
  end
 end)
end
local function togglePanel(name)
 name=panelName(name)
 local target=panels[name]
 if name=="accessoryRoll"and dossierOpenRequested then dossierOpenRequested,dossierCategory=false,nil;return end
 if target and target.visible then callPanelMethod(target,"close")else openPanel(name)end
end
-- Shared H controller and legacy launchers use this same lobby panel.
local dossierEvent=playerGui:FindFirstChild("SpyOpenDossier")
if not dossierEvent then dossierEvent=Instance.new("BindableEvent");dossierEvent.Name="SpyOpenDossier";dossierEvent.Parent=playerGui end
if dossierEvent:IsA("BindableEvent")then
 dossierEvent.Event:Connect(function(action)
  if action=="close"then
   dossierOpenRequested,dossierCategory=false,nil
   callPanelMethod(panels.accessoryRoll,"close")
   callPanelMethod(panels.premiumShop,"close")
   callPanelMethod(panels.clubStore,"close")
  elseif action=="open"then openPanel("accessoryRoll")
  else togglePanel("accessoryRoll")end
 end)
end
-- Phone applications use the same existing panels and economy actions.
local phoneLaunch=player.PlayerGui:FindFirstChild("SpyPhoneLaunch") or Instance.new("BindableEvent")
phoneLaunch.Name="SpyPhoneLaunch";phoneLaunch.Parent=player.PlayerGui
local phoneQuery=player.PlayerGui:FindFirstChild("SpyPhoneQuery") or Instance.new("BindableFunction")
phoneQuery.Name="SpyPhoneQuery";phoneQuery.Parent=player.PlayerGui
phoneQuery.OnInvoke=function() return profile end
phoneLaunch.Event:Connect(function(key,arg,token)
 dossierOpenRequested,dossierCategory=false,nil
 local targetName=panelName(key,arg)
 if targetName=="clubStore"then
  local ack=player.PlayerGui:FindFirstChild("SpyPhoneLaunchAck")
  local ready=panels.clubStore~=nil
  for _,flag in ipairs({"SpyTradeOpen","SpyTeleporting","SpyEntryPending","SpyEntryActive"})do
   if player:GetAttribute(flag)then ready=false end
  end
  if ack and ack:IsA("BindableEvent")then
   -- The phone releases its modal/input state on successful acknowledgement.
   ack:Fire(token,ready)
   if ready then task.defer(function()openPanel("clubStore",nil,false)end)end
  end
  return
 end
 local success=false
 if key=="tables" or key=="trade" then
  local event=player.PlayerGui:FindFirstChild(key=="tables" and "SpyOpenQuickPlay" or "SpyOpenTrade")
  if event and event:IsA("BindableEvent") then event:Fire(arg);success=true end
 elseif ({inventory=true,profile=true,settings=true,journal=true,shop=true,daily=true,accessoryRoll=true})[key] then
  success=openPanel(key,arg,false)==true
 end
 local ack=player.PlayerGui:FindFirstChild("SpyPhoneLaunchAck")
 if ack and ack:IsA("BindableEvent") then ack:Fire(token,success) end
end)

shopButton.Activated:Connect(function() togglePanel("clubStore") end)
collectionButton.Activated:Connect(function() togglePanel("accessoryRoll") end)
dailyButton.Activated:Connect(function() togglePanel("daily") end)
themeButton.Activated:Connect(function() togglePanel("settings") end)
profileHotspot.Activated:Connect(function() togglePanel("profile") end)
profileButton.Activated:Connect(function() togglePanel("profile") end)
sideDock.HighStakes.Activated:Connect(function() togglePanel("highstakes") end)
sideDock.Guide.Activated:Connect(function() notify(L("firstVisitHint")) end)
-- TableReservationClient owns the existing MainAction and its create form.
profileEvent.OnClientEvent:Connect(function(newProfile,receipt,requestId)
	if requestId and requestId==pendingId then pendingId=nil end
	if not newProfile.ready or not profile.ready or (newProfile.revision or 0)>=(profile.revision or 0) then profile=newProfile end
	if profile.ready and (not languageInitialized or (receipt and receipt.code=="language" and receipt.ok)) then
		language=profile.language or "ru"
		languageInitialized=true
		player:SetAttribute("SpyLanguage",language)
	end
	state.profile=profile
	render(state)
	if receipt and (receipt.code=="roll_shop_synced"or receipt.code=="roll_luck_synced"or receipt.code=="monetizationSynced")then return end
	if receipt and panels.clubStore and panels.clubStore:receive(receipt,requestId)then return end
	if receipt and receipt.ok and receipt.code=="clubBought"then
		local item=Catalog.ById[receipt.itemId]
		notify((language=="en"and"Added to collection · "or"В коллекции · ")..(item and(language=="en"and item.en or item.ru)or""));return
	end
	if receipt and panels.premiumShop and panels.premiumShop:receive(receipt,requestId)then return end
	if receipt and receipt.code=="rollPurchasePrompted"then return end
	if receipt and receipt.code=="rollsPurchased"then
        if receipt.ok and not receipt.replayed then notify("+"..tostring(receipt.rolls or 0).." Rolls")end
        return
    end
	if receipt and receipt.ok and receipt.code=="paidGranted"then
		local rewards={}
		if (receipt.coins or 0)>0 then table.insert(rewards,tostring(receipt.coins)..(language=="en"and" coins"or" монет"))end
		if (receipt.xp or 0)>0 then table.insert(rewards,tostring(receipt.xp).." XP")end
		notify((language=="en"and"Purchase saved"or"Покупка сохранена")..(#rewards>0 and" · "..table.concat(rewards," · ")or""))
		return
	end
	if receipt and panels.accessoryRoll and panels.accessoryRoll:receive(receipt,requestId) then return end
	if receipt and receipt.code=="accessoryRolled" then return end
	if panels.journal and panels.journal.visible then panels.journal:render() end
	if panels.profile and panels.profile.visible then panels.profile:render() end
	if receipt and not (type(requestId)=="string" and requestId:sub(1,6)=="prefs-") then
		if receipt.code=="gadgetUsed" and receipt.ok then if gadgets then gadgets:receive(receipt) end
		elseif receipt.code=="dailyReceived" and receipt.ok then
			playLobbySound("Reward",1)
			local parts={}
			if receipt.itemId then local item=Catalog.ById[receipt.itemId];parts[#parts+1]=item and(language=="en"and item.en or item.ru)or receipt.itemId end
			if (receipt.rolls or 0)>0 then parts[#parts+1]="+"..tostring(receipt.rolls).." Rolls"end
			if (receipt.coins or 0)>0 then parts[#parts+1]="+"..tostring(receipt.coins).." ◈"end
			if (receipt.xp or 0)>0 then parts[#parts+1]="+"..tostring(receipt.xp).." XP"end
			notify(table.concat(parts," · "))
		elseif receipt.code=="reward" and receipt.ok then
			local rolls=receipt.rolls or 0
			if rolls>0 then playLobbySound("Reward",1);notify("+"..tostring(rolls).." Rolls")end
		elseif receipt.code=="bought" and receipt.ok then
			playLobbySound("Coin",0.98)
			local item=Catalog.ById[receipt.itemId]
			notify(L("bought",{item=item and (language=="en" and item.en or item.ru) or ""}))
			elseif receipt.code=="sold" and receipt.ok then
				playLobbySound("Coin",1.05); playLobbySound("Vincent",1.01)
				if dialogue and dialogue.receive then dialogue:receive(receipt) end
				notify((language=="en" and "Vincent paid " or "Винсент заплатил ")..tostring(receipt.coins or 0).." ◈")
			elseif receipt.code=="protected_item" then
				if dialogue and dialogue.receive then dialogue:receive(receipt) end
				notify(language=="en" and "That item cannot be sold." or "Эту вещь нельзя продать.")
		elseif receipt.code~="language" and receipt.code~="onboardingComplete" then notify(L(receipt.ok==false and receipt.code=="refreshed" and "profile_unavailable" or receipt.code)) end
	end
end)
local promptObjects={OpenShop="collection",DailyReward="dailyUtc",HighStakesDoor="highStakesDoorHint",LeaveHighStakes="mainLounge",TalkVincent="vincentName",InspectCase="archiveCase"}
local promptActions={OpenShop="shop",DailyReward="daily",HighStakesDoor="highStakes",LeaveHighStakes="returnLounge",TalkVincent="talkVincent",InspectCase="inspect",JoinTable="seat"}
localizeWorld=function()
	local world=workspace:FindFirstChild("SpyClub")
	if not world then return end
	for _,object in ipairs(world:GetDescendants()) do
		if object:IsA("TextLabel") then
			local key=object:GetAttribute("TextKey")
			local tableId=object:GetAttribute("TableId")
			if tableId then
				object.Text=L(tableId).." · "..tostring(object:GetAttribute("TableCount") or 0).."/"..tostring(object:GetAttribute("TableCapacity") or 4).."\n"..L(object:GetAttribute("PhaseKey") or "Waiting")
			elseif key and not object:GetAttribute("ServerRanking") then object.Text=L(key) end
		elseif object:IsA("ProximityPrompt") then
			local key=object:GetAttribute("ActionKey") or promptActions[object.Name]
			if key then object.ActionText=L(key) end
			if object.Name=="JoinTable" then object.ObjectText=L(object.Parent.Parent.Name)
			elseif promptObjects[object.Name] then object.ObjectText=L(promptObjects[object.Name]) end
		end
	end
end
noticeEvent.OnClientEvent:Connect(function(notice)
	if type(notice)=="table" and notice.key=="talkVincent" then playLobbySound("Vincent",1.02); if dialogue then dialogue:open("start") end
	elseif type(notice)=="table" and notice.key=="openPanel" then openPanel(notice.panel,notice.category or notice.caseId)
	elseif type(notice)=="table" then notify(L(notice.key,notice.args))
	else notify(L(notice)) end
end)
local function receiveState(snapshot)
	if type(snapshot)~="table" then return end
	receivedState=true
	local ok,err=pcall(render,snapshot)
	if not ok then warn("[SpyBoot] render: "..tostring(err)) end
	updateClientReadiness()
end
stateEvent.OnClientEvent:Connect(receiveState)
-- Native chat configuration is owned by the independent NativeChatBootstrap.
RunService.RenderStepped:Connect(function(dt)
	if panels.daily then panels.daily:tick() end
	if not state.tableId then return end
	local remaining = math.max(0, math.ceil((state.endAt or 0) - workspace:GetServerTimeNow()))
	timer.Text = state.phase == "Waiting" and (#state.people .. "/" .. state.capacity) or string.format("%02d", remaining)
	local duration = state.phase=="Vote" and state.runoff and 10 or (Config.Seconds[state.phase] or 1)
	progress.Size = UDim2.fromOffset(math.max(0, main.AbsoluteSize.X - 36) * math.clamp(remaining / duration, 0, 1), 2)
end)
pcall(resize)
pcall(render,state)
task.spawn(function()
 local ok,motion=pcall(function() return require(shared:WaitForChild("LobbyMotion",8)).start(player,function() return profile end) end)
 if ok then gui.Destroying:Connect(function() motion:Destroy() end) end
end)
gui.Destroying:Connect(function() hudView:Destroy() end)
-- Readiness requires both a complete local UI and a live server snapshot. If a
-- snapshot arrives while the remaining services initialize, this final check
-- closes that race without letting the loader hide on remotes alone.
clientInitialized=true
updateClientReadiness()
actionEvent:FireServer("Sync")

task.spawn(function()
-- Club movement and the private writing desk. This block is deliberately
-- isolated from commerce, dialogue and the existing HUD.
do
    local motionToken=0
    local fallbackTracks={}
    local motionConnection
    local restoreConnection
    local restorePose
    local function stopFallback()
        for _,track in pairs(fallbackTracks) do
            pcall(function() track:Stop(.18);track:Destroy() end)
        end
        fallbackTracks={}
    end
    local function bindMotion(character)
        motionToken+=1
        local token=motionToken
        if motionConnection then motionConnection:Disconnect();motionConnection=nil end
        if restoreConnection then restoreConnection:Disconnect();restoreConnection=nil end
        if restorePose then restorePose();restorePose=nil end
        stopFallback()
        local humanoid=character:WaitForChild("Humanoid",8)
        local root=character:WaitForChild("HumanoidRootPart",8)
        if not humanoid or not root then return end
        local animator=humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator",3)
        local waist
        local neck
        local leftShoulder
        local rightShoulder
        local previous=root.CFrame.LookVector
        local turn=0
        local elapsed=0
        local walkCycle=0
        local motionBlend=0
        local nextTrackCheck=0
        local fallback=false
        local playing=""
        local offsets={}
        restorePose=function()
            for joint,offset in pairs(offsets) do
                if joint.Parent then joint.Transform=joint.Transform*offset:Inverse() end
            end
            table.clear(offsets)
        end
        restoreConnection=RunService.PreAnimation:Connect(restorePose)
        local function pose(joint,offset)
            if not joint then return end
            joint.Transform=joint.Transform*offset
            offsets[joint]=offset
        end
        local function makeTrack(id,priority)
            if not animator then return nil end
            local animation=Instance.new("Animation")
            animation.AnimationId="rbxassetid://"..id
            local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
            animation:Destroy()
            if not ok or not track then return nil end
            track.Priority=priority
            track.Looped=true
            return track
        end
        task.delay(1.2,function()
            if motionToken~=token or not character.Parent then return end
            if not animator then return end
            -- A present but disabled Animate script must not leave the rig
            -- frozen. Only install fallback if nothing is actually playing.
            for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.IsPlaying and track.Priority.Value<=Enum.AnimationPriority.Movement.Value then return end
            end
            fallbackTracks.idle=makeTrack(507766666,Enum.AnimationPriority.Idle)
            fallbackTracks.walk=makeTrack(507777826,Enum.AnimationPriority.Movement)
            fallback=fallbackTracks.idle~=nil or fallbackTracks.walk~=nil
        end)
        character.ChildAdded:Connect(function(child)
            if motionToken==token and child.Name=="Animate" and fallback then
                stopFallback()
                fallback=false
                playing=""
            end
        end)
        motionConnection=RunService.PreSimulation:Connect(function(dt)
            if motionToken~=token or not character.Parent or humanoid.Health<=0 then return end
            elapsed+=dt
            if fallback and animator and elapsed>=nextTrackCheck then
                nextTrackCheck=elapsed+1
                for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if track~=fallbackTracks.idle and track~=fallbackTracks.walk
                        and track.IsPlaying and track.Priority.Value<=Enum.AnimationPriority.Movement.Value then
                        stopFallback();fallback=false;playing=""
                        break
                    end
                end
            end
            if not waist or not waist.Parent then
                local upper=character:FindFirstChild("UpperTorso")
                local lower=character:FindFirstChild("LowerTorso")
                local head=character:FindFirstChild("Head")
                waist=(lower and lower:FindFirstChild("Waist")) or (upper and upper:FindFirstChild("Waist"))
                neck=(upper and upper:FindFirstChild("Neck")) or (head and head:FindFirstChild("Neck"))
                leftShoulder=character:FindFirstChild("LeftShoulder",true)
                rightShoulder=character:FindFirstChild("RightShoulder",true)
            end
            local direction=root.CFrame.LookVector
            local current=Vector3.new(direction.X,0,direction.Z)
            local old=Vector3.new(previous.X,0,previous.Z)
            local angle=math.atan2(old:Cross(current).Y,old:Dot(current))
            previous=direction
            local moving=humanoid.MoveDirection.Magnitude>.07
            local onGround=humanoid.FloorMaterial~=Enum.Material.Air
            local seated=humanoid.Sit
            local flatVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
            local wantsMotion=moving and onGround and not seated
            motionBlend+=( (wantsMotion and 1 or 0)-motionBlend)*math.clamp(dt*5,0,1)
            if wantsMotion then walkCycle+=dt*math.clamp(flatVelocity*.66,5,10) end
            local target=moving and onGround and not seated and math.clamp(angle*3,-.14,.14) or 0
            turn+= (target-turn)*math.clamp(dt*8,0,1)
            local breath=math.sin(elapsed*1.85)*(moving and .002 or .010)
            if waist and not seated then pose(waist,CFrame.Angles(breath*.35,turn,breath)) end
            if neck and not seated then pose(neck,CFrame.Angles(-breath*.5,-turn*.35,0)) end
            if not seated then
                local armSway=math.sin(walkCycle)*motionBlend*.075
                local idleSway=math.sin(elapsed*1.32)*(1-motionBlend)*.016
                if leftShoulder then pose(leftShoulder,CFrame.Angles(armSway+idleSway,0,breath*.35)) end
                if rightShoulder then pose(rightShoulder,CFrame.Angles(-armSway-idleSway,0,-breath*.35)) end
            end
            if fallback then
                local nextState=seated and "" or (moving and onGround and "walk" or "idle")
                if nextState~=playing then
                    if fallbackTracks[playing] then fallbackTracks[playing]:Stop(.2) end
                    if fallbackTracks[nextState] then fallbackTracks[nextState]:Play(.22) end
                    playing=nextState
                end
                if nextState=="walk" and fallbackTracks.walk then
                    fallbackTracks.walk:AdjustSpeed(math.clamp(root.AssemblyLinearVelocity.Magnitude/13,.7,1.35))
                end
            end
        end)
    end
    player.CharacterAdded:Connect(bindMotion)
    if player.Character then task.spawn(bindMotion,player.Character) end

    local FeedbackBook=shared:WaitForChild("FeedbackBook",10)
    if not FeedbackBook then return end
    local bookGui=Instance.new("ScreenGui")
    bookGui.Name="SpyFeedbackBookUI"
    bookGui.DisplayOrder=84
    bookGui.ResetOnSpawn=false
    bookGui.IgnoreGuiInset=true
    bookGui.Enabled=false
    bookGui.Parent=player:WaitForChild("PlayerGui")
    local veil=Instance.new("TextButton")
    veil.Name="ModalShade"
    veil.Size=UDim2.fromScale(1,1)
    veil.Text=""
    veil.AutoButtonColor=false
    veil.BackgroundColor3=Color3.fromRGB(5,5,8)
    veil.BackgroundTransparency=.28
    veil.Parent=bookGui
    local card=Instance.new("Frame")
    card.Name="WritingDesk"
    card.AnchorPoint=Vector2.new(.5,.5)
    card.Position=UDim2.fromScale(.5,.5)
    card.Size=UDim2.new(.9,0,.76,0)
    card.BackgroundColor3=Color3.fromRGB(24,21,22)
    card.BorderSizePixel=0
    card.Parent=veil
    local limit=Instance.new("UISizeConstraint")
    limit.MaxSize=Vector2.new(660,510)
    limit.MinSize=Vector2.new(300,390)
    limit.Parent=card
    local border=Instance.new("UIStroke")
    border.Color=Color3.fromRGB(124,95,64)
    border.Thickness=1
    border.Transparency=.25
    border.Parent=card
    local function label(name,text,pos,size,font,px,color)
        local item=Instance.new("TextLabel")
        item.Name=name
        item.BackgroundTransparency=1
        item.Position=pos
        item.Size=size
        item.Text=text
        item.TextColor3=color or Color3.fromRGB(235,218,192)
        item.TextSize=px
        item.Font=font
        item.TextXAlignment=Enum.TextXAlignment.Left
        item.TextWrapped=true
        item.Parent=card
        return item
    end
    local accent=Instance.new("Frame")
    accent.Size=UDim2.new(0,3,1,0)
    accent.BorderSizePixel=0
    accent.BackgroundColor3=Color3.fromRGB(194,151,94)
    accent.Parent=card
    label("Stamp","SPY CLUB  /  СВЯЗЬ",UDim2.fromOffset(26,21),UDim2.new(1,-100,0,22),Enum.Font.BuilderSansBold,11,Color3.fromRGB(206,160,100))
    label("Title","Связь с разработчиком",UDim2.fromOffset(26,49),UDim2.new(1,-95,0,38),Enum.Font.BuilderSansBold,23)
    local close=Instance.new("TextButton")
    close.Name="CloseBook"
    close.Position=UDim2.new(1,-60,0,24)
    close.Size=UDim2.fromOffset(34,34)
    close.Text="×"
    close.TextColor3=Color3.fromRGB(235,218,192)
    close.TextSize=24
    close.Font=Enum.Font.BuilderSansBold
    close.BackgroundColor3=Color3.fromRGB(42,35,34)
    close.BorderSizePixel=0
    close.Parent=card
    Instance.new("UICorner",close).CornerRadius=UDim.new(0,5)
    local rule=Instance.new("Frame")
    rule.Position=UDim2.fromOffset(26,106)
    rule.Size=UDim2.new(1,-52,0,1)
    rule.BorderSizePixel=0
    rule.BackgroundColor3=Color3.fromRGB(75,59,50)
    rule.Parent=card
    local categories={{"bug","ОШИБКА"},{"wish","ПОЖЕЛАНИЕ"},{"idea","ИДЕЯ"}}
    local choice="bug"
    local selectors={}
    local function syncCategory()
        for key,b in pairs(selectors) do
            b.BackgroundColor3=key==choice and Color3.fromRGB(190,146,87) or Color3.fromRGB(42,35,33)
            b.TextColor3=key==choice and Color3.fromRGB(21,18,17) or Color3.fromRGB(220,201,179)
        end
    end
    for index,entry in ipairs(categories) do
        local category=Instance.new("TextButton")
        category.Name="Category_"..entry[1]
        category.Position=UDim2.new((index-1)/3,26-(index-1)*8,0,126)
        category.Size=UDim2.new(1/3,-23,0,40)
        category.BackgroundColor3=Color3.fromRGB(42,35,33)
        category.BorderSizePixel=0
        category.Text=entry[2]
        category.TextSize=12
        category.Font=Enum.Font.BuilderSansBold
        category.Parent=card
        Instance.new("UICorner",category).CornerRadius=UDim.new(0,5)
        local selected=entry[1]
        selectors[selected]=category
        category.Activated:Connect(function() choice=selected;syncCategory() end)
    end
    syncCategory()
    local textbox=Instance.new("TextBox")
    textbox.Name="Message"
    textbox.Position=UDim2.fromOffset(26,183)
    textbox.Size=UDim2.new(1,-52,1,-290)
    textbox.BackgroundColor3=Color3.fromRGB(30,26,26)
    textbox.BorderSizePixel=0
    textbox.TextColor3=Color3.fromRGB(238,225,206)
    textbox.PlaceholderColor3=Color3.fromRGB(147,127,111)
    textbox.PlaceholderText="Что случилось? Где? Как это повторить?"
    textbox.Font=Enum.Font.BuilderSansMedium
    textbox.TextSize=16
    textbox.MultiLine=true
    textbox.ClearTextOnFocus=false
    textbox.TextXAlignment=Enum.TextXAlignment.Left
    textbox.TextYAlignment=Enum.TextYAlignment.Top
    textbox.TextWrapped=true
    textbox.Text=""
    textbox.Parent=card
    Instance.new("UICorner",textbox).CornerRadius=UDim.new(0,5)
    local padding=Instance.new("UIPadding")
    padding.PaddingTop=UDim.new(0,14)
    padding.PaddingLeft=UDim.new(0,14)
    padding.PaddingRight=UDim.new(0,14)
    padding.Parent=textbox
    local count=label("CharacterCount","0 / 240",UDim2.new(1,-115,1,-104),UDim2.fromOffset(90,22),Enum.Font.BuilderSansMedium,12,Color3.fromRGB(166,141,115))
    count.TextXAlignment=Enum.TextXAlignment.Right
    local status=label("Status","",UDim2.fromOffset(26,0),UDim2.new(1,-52,0,34),Enum.Font.BuilderSansMedium,12,Color3.fromRGB(180,161,141))
    status.Position=UDim2.new(0,26,1,-103)
    local send=Instance.new("TextButton")
    send.Name="Submit"
    send.Position=UDim2.new(0,26,1,-65)
    send.Size=UDim2.new(1,-52,0,43)
    send.BackgroundColor3=Color3.fromRGB(218,180,127)
    send.BorderSizePixel=0
    send.TextColor3=Color3.fromRGB(26,20,19)
    send.Text="ОТПРАВИТЬ"
    send.TextSize=14
    send.Font=Enum.Font.BuilderSansBold
    send.Parent=card
    Instance.new("UICorner",send).CornerRadius=UDim.new(0,5)
    local busy=false
    local attempt=0
    local pending
    local function updateCount()
        local length=utf8.len(textbox.Text) or #textbox.Text
        count.Text=tostring(length).." / 240"
        count.TextColor3=length>240 and Color3.fromRGB(229,124,114) or Color3.fromRGB(166,141,115)
    end
    textbox:GetPropertyChangedSignal("Text"):Connect(updateCount)
    local function hide()
        bookGui.Enabled=false
        textbox:ReleaseFocus()
    end
    close.Activated:Connect(hide)
    game:GetService("UserInputService").InputBegan:Connect(function(input)
        if bookGui.Enabled and input.KeyCode==Enum.KeyCode.Escape then hide() end
    end)
    send.Activated:Connect(function()
        if busy then return end
        local length=utf8.len(textbox.Text)
        if not length or length<5 or length>240 or not textbox.Text:match("%S") then
            status.Text="Нужно от 5 до 240 символов."
            return
        end
        if not pending or pending.text~=textbox.Text or pending.category~=choice then
            pending={id=os.date("!%Y%m%d")..":"..game:GetService("HttpService"):GenerateGUID(false),text=textbox.Text,category=choice}
        end
        busy=true;attempt+=1;local token=attempt
        status.Text="Отправляем во входящие разработчика…"
        send.Text="ОТПРАВЛЯЕМ…"
        FeedbackBook:FireServer(choice,textbox.Text,pending.id)
        task.delay(15,function()
            if busy and token==attempt then
                busy=false
                send.Text="ПОВТОРИТЬ ОТПРАВКУ"
                status.Text="Нет ответа сервера. Текст сохранён, можно повторить."
            end
        end)
    end)
    FeedbackBook.OnClientEvent:Connect(function(action,ok,info,studio,requestId)
        if action=="open" then
            bookGui.Enabled=true
            if not busy then status.Text="Обращение получит разработчик в личном ящике клуба." end
        elseif action=="result" and pending and requestId==pending.id then
            busy=false;attempt+=1
            send.Text="ОТПРАВИТЬ"
            if ok then
                if textbox.Text==pending.text then textbox.Text="" end
                pending=nil
                status.Text=studio and "Тестовое обращение принято в ящик Studio." or "Доставлено. № "..tostring(info):sub(-8).." • входящие разработчика"
            else
                status.Text=tostring(info or "Не удалось отправить. Текст сохранён.")
            end
        end
    end)
end

end)

end,debug.traceback)
bootTarget:SetAttribute("SpyClientBootStatus",bootOK and "ready" or "failed")
if not bootOK then
 bootTarget:SetAttribute("SpyClientBootStatusError",string.sub(tostring(bootError),1,1500))
 warn("[SPY V52.1 BOOT] "..tostring(bootError))
end
