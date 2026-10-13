-- Match uses the same dossier and the same profile instance as round rewards.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local shared=RS:WaitForChild("SpyShared")
local Policy=require(shared:WaitForChild("DossierPolicy"))
local I18n=require(shared:WaitForChild("I18n"))
local action=shared:WaitForChild("EconomyAction",30)
local profileEvent=shared:WaitForChild("Profile",30)
if not action or not profileEvent then warn("SpyClub character menu remotes unavailable");return end
local old=pg:FindFirstChild("SpyMatchCharacterUI")
if old then return end
local gui=Instance.new("ScreenGui")
gui.Name="SpyMatchCharacterUI";gui.ResetOnSpawn=false;gui.DisplayOrder=390
gui.IgnoreGuiInset=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local colors={bg=Color3.fromRGB(15,17,19),panel=Color3.fromRGB(24,26,29),
    raised=Color3.fromRGB(36,38,41),edge=Color3.fromRGB(76,74,70),
    text=Color3.fromRGB(240,235,222),muted=Color3.fromRGB(161,160,154),gold=Color3.fromRGB(198,176,130)}
local profile={ready=false,rolls=0,owned={},equipped={}}
local profileRevision=-1
local panels,active,pending={},nil,nil
local connections={}
local alive=true
local refreshVersion,syncedVersion=0,0
local pendingGeneration,pendingKind,pendingRefreshVersion=0,nil,nil
local function markRefresh()if active then refreshVersion+=1 end end
local function language()return player:GetAttribute("SpyLanguage") or "ru"end
local function L(key,args)return I18n.t(language(),key,args)end
local function make(class,parent,properties)
    local node=Instance.new(class)
    for key,value in pairs(properties or {})do node[key]=value end
    if node:IsA("GuiObject") and not (properties and properties.ZIndex) and parent and parent:IsA("GuiObject") then
        node.ZIndex=parent.ZIndex+1
    end
    node.Parent=parent;return node
end
local function label(parent,value,size,position,fontSize,color)
    return make("TextLabel",parent,{Text=I18n.Strings[value] and L(value) or value,
        Size=size,Position=position,TextSize=fontSize or 16,TextColor3=color or colors.text,
        Font=Enum.Font.BuilderSansMedium,BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function panel(parent,size,position)
    local node=make("Frame",parent,{Size=size,Position=position,BackgroundColor3=colors.panel,BorderSizePixel=0})
    make("UICorner",node,{CornerRadius=UDim.new(0,12)})
    make("UIStroke",node,{Color=colors.edge,Transparency=.6})
    return node
end
local function button(parent,value,size,position,color)
    local node=make("TextButton",parent,{Text=I18n.Strings[value] and L(value) or value,
        Size=size,Position=position,TextSize=16,TextColor3=colors.text,Font=Enum.Font.BuilderSansBold,
        BackgroundColor3=color or colors.raised,BorderSizePixel=0,AutoButtonColor=true})
    make("UICorner",node,{CornerRadius=UDim.new(0,8)});return node
end
local toast=label(gui,"",UDim2.new(1,-40,0,54),UDim2.new(.5,0,0,16),15)
toast.Name="CharacterNotice";toast.AnchorPoint=Vector2.new(.5,0);toast.Visible=false;toast.ZIndex=100
toast.BackgroundTransparency=.08;toast.BackgroundColor3=colors.panel
make("UISizeConstraint",toast,{MaxSize=Vector2.new(580,54)})
make("UICorner",toast,{CornerRadius=UDim.new(0,8)})
local noticeToken=0
local function notify(value)
    noticeToken+=1;local token=noticeToken
    toast.Text=tostring(value);toast.Visible=true
    task.delay(4,function()if alive and noticeToken==token then toast.Visible=false end end)
end
local function update()
    for _,modal in pairs(panels)do modal:update()end
end
local function closePanels(except)
    for key,modal in pairs(panels)do if key~=except then modal:close()end end
end
local function flags()
    return {teleporting=player:GetAttribute("SpyTeleporting")==true or player:GetAttribute("SpyReconnectBusy")==true,
        cinematic=player:GetAttribute("SpyMatchIntroActive")==true or player:GetAttribute("SpyCaseCinematicActive")==true,
        phone=player:GetAttribute("SpyPhoneActive")==true,trade=player:GetAttribute("SpyTradeOpen")==true,
        minigame=player:GetAttribute("SpyBilliardsPlaying")==true or player:GetAttribute("SpyCheckersPlaying")==true}
end
local function phase()
    local session=RS:FindFirstChild("MatchSession")
    return session and session:GetAttribute("RoundPhase") or "Waiting"
end
local function request(kind,value,requestId)
    if pending then return false end
    if kind=="retry" then kind="dossierSync"end
    local recovering=kind=="accessoryRoll" and requestId~=nil
    if (kind=="accessoryRoll" or kind=="equip" or kind=="daily") and not recovering and not Policy.canChange(phase()) then
        notify(language()=="en" and "Changes are available after the match." or "Изменения доступны после матча.")
        return false
    end
    local id=requestId or Http:GenerateGUID(false)
    pendingGeneration+=1
    local generation=pendingGeneration
    pendingKind=kind
    pendingRefreshVersion=kind=="dossierSync" and refreshVersion or nil
    pending=id
    action:FireServer(kind,value,id)
    update()
    task.delay(18,function()
        if alive and pending==id and pendingGeneration==generation then
            pending,pendingKind,pendingRefreshVersion=nil,nil,nil;update()
            notify(language()=="en" and "Reply delayed. Retrying the same roll is safe." or "Ответ задерживается. Повторить этот ролл безопасно.")
        end
    end)
    return id
end
local ctx={gui=gui,player=player,make=make,panel=panel,label=label,button=button,L=L,colors=colors,
    profile=function()return profile end,language=language,request=request,notify=notify,
    pending=function()return pending~=nil end,closePanels=closePanels,
    state=function()
        local current=phase()
        local state={phase=current}
        if not Policy.canChange(current)then state.tableId="match"end
        return state
    end,
    setActivePanel=function(name)active=name;player:SetAttribute("SpyCharacterMenuOpen",name~=nil)end,
    getActivePanel=function()return active end,
    openPanel=function(name,category)
        local modal=panels[name]
        if modal then modal:open(category)end
    end}
panels.accessoryRoll=require(shared:WaitForChild("AccessoryRollUI")).create(ctx)
panels.daily=require(shared:WaitForChild("DailyUI")).create(ctx)
player:SetAttribute("SpyPanel_accessoryRoll","ready")
local open=pg:FindFirstChild("SpyOpenDossier") or Instance.new("BindableEvent")
open.Name="SpyOpenDossier";open.Parent=pg
connections[#connections+1]=open.Event:Connect(function(mode)
    if mode=="close" or (mode~="open" and active)then closePanels();return end
    if not Policy.canOpen(flags())then return end
    local closeChat=pg:FindFirstChild("SpyCloseChat")
    if closeChat and closeChat:IsA("BindableEvent")then closeChat:Fire()end
    panels.accessoryRoll:open()
    markRefresh()
    if not pending then request("dossierSync")end
end)
connections[#connections+1]=profileEvent.OnClientEvent:Connect(function(incoming,receipt,requestId)
    if not alive or type(incoming)~="table"then return end
    local matching=requestId==pending
    local acknowledgedRefresh=matching and pendingKind=="dossierSync" and pendingRefreshVersion or nil
    if matching then pending,pendingKind,pendingRefreshVersion=nil,nil,nil end
    if incoming.ready and (incoming.revision or 0)>=profileRevision then
        profile=incoming
        profileRevision=incoming.revision or 0
        if acknowledgedRefresh then syncedVersion=math.max(syncedVersion,acknowledgedRefresh)end
    elseif not incoming.ready and (matching or profileRevision<0)then
        profile=incoming
    end
    update()
    local consumed=panels.accessoryRoll:receive(receipt,requestId)
    if not consumed and receipt and requestId and receipt.ok==false and requestId:sub(1,6)~="prefs-"then
        notify(receipt.code=="roll_match_active" and (language()=="en" and "Changes are available after the match." or "Изменения доступны после матча.") or L(receipt.code))
    end
end)
for _,key in ipairs({"SpyTeleporting","SpyReconnectBusy","SpyPhoneActive","SpyTradeOpen","SpyMatchIntroActive","SpyCaseCinematicActive","SpyBilliardsPlaying","SpyCheckersPlaying"})do
    connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(function()
        if not Policy.canOpen(flags())then closePanels()end
    end)
end
connections[#connections+1]=gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    for _,modal in pairs(panels)do modal:resize()end
end)
local session=RS:WaitForChild("MatchSession",15)
if session then connections[#connections+1]=session:GetAttributeChangedSignal("RoundPhase"):Connect(function()
    update()
    if Policy.canChange(phase())then markRefresh()end
end)end
connections[#connections+1]=player:GetAttributeChangedSignal("SpyRolls"):Connect(function()
    markRefresh()
end)
for _,key in ipairs({"SpyAppearanceRevision","SpyAppearanceStatus"})do
    connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(function()
        markRefresh()
    end)
end
local characterReady,assetRevision
local function watchCharacter(character)
    if characterReady then characterReady:Disconnect();characterReady=nil end
    if not character then return end
    characterReady=character:GetAttributeChangedSignal("SpyBaseReady"):Connect(function()
        markRefresh()
    end)
    markRefresh()
end
connections[#connections+1]=player.CharacterAdded:Connect(watchCharacter)
watchCharacter(player.Character)
local function watchAssets(folder)
    if folder.Name~="SpyWardrobeAssets"then return end
    if assetRevision then assetRevision:Disconnect()end
    assetRevision=folder:GetAttributeChangedSignal("Revision"):Connect(function()
        markRefresh()
    end)
    markRefresh()
end
connections[#connections+1]=RS.ChildAdded:Connect(watchAssets)
local assets=RS:FindFirstChild("SpyWardrobeAssets")
if assets then watchAssets(assets)end
local matchRemotes=RS:FindFirstChild("MatchRemotes")
local reward=matchRemotes and matchRemotes:FindFirstChild("Reward")
if reward then connections[#connections+1]=reward.OnClientEvent:Connect(function(receipt)
    if type(receipt)=="table" and receipt.state=="saved"then markRefresh()end
end)end
local elapsed=0
connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
    elapsed+=dt
    if elapsed<1 then return end
    elapsed=0
    if panels.daily.visible and panels.daily.tick then panels.daily:tick()end
    if active and not pending and (not profile.ready or refreshVersion>syncedVersion)then request("dossierSync")end
end)
script.Destroying:Connect(function()
    alive=false;closePanels()
    for _,connection in ipairs(connections)do connection:Disconnect()end
    if characterReady then characterReady:Disconnect()end
    if assetRevision then assetRevision:Disconnect()end
    if panels.accessoryRoll.Destroy then panels.accessoryRoll:Destroy()end
    gui:Destroy();player:SetAttribute("SpyCharacterMenuOpen",false)
end)
request("dossierSync")
