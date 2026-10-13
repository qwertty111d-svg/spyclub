-- ReplicatedFirst presentation; no optional panels, assets or profile waits.
local Players=game:GetService("Players")
local First=game:GetService("ReplicatedFirst")
local player=Players.LocalPlayer
local gui,finished
local connections={}
local function finish()
    if finished then return end
    finished=true
    for _,connection in ipairs(connections)do connection:Disconnect()end
    if gui then gui:Destroy();gui=nil end
    pcall(function()First:RemoveDefaultLoadingScreen()end)
    player:SetAttribute("SpyLoadingReleased",true)
end
-- Registered before creating UI; also guarded by the independent BootClient.
task.delay(25,finish)
local pg=player:FindFirstChildOfClass("PlayerGui")or player:WaitForChild("PlayerGui",10)
if not pg or finished then return end
if player:GetAttribute("SpyLoadingReleased")==true then finish();return end
local function make(class,parent,props)
    local n=Instance.new(class);for k,v in pairs(props)do n[k]=v end;n.Parent=parent;return n
end
gui=make("ScreenGui",pg,{Name="ClubLoading",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=1000})
local root=make("Frame",gui,{Name="Screen",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(16,23,24),BorderSizePixel=0})
local panel=make("Frame",root,{Name="LoadingPanel",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-48,1,-52),Size=UDim2.fromOffset(380,228),BackgroundTransparency=1,BorderSizePixel=0})
local brand=make("TextLabel",panel,{Name="Wordmark",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,98),BackgroundTransparency=1,Text="SPY CLUB",Font=Enum.Font.Bodoni,TextSize=62,TextColor3=Color3.fromRGB(236,233,221),TextXAlignment=Enum.TextXAlignment.Left})
local status=make("TextLabel",panel,{Name="Status",Position=UDim2.fromOffset(0,109),Size=UDim2.new(1,0,0,25),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.fromRGB(199,184,148),TextXAlignment=Enum.TextXAlignment.Left})
local track=make("Frame",panel,{Name="ProgressTrack",Position=UDim2.fromOffset(0,144),Size=UDim2.new(1,0,0,2),BackgroundColor3=Color3.fromRGB(61,70,67),BorderSizePixel=0})
local fill=make("Frame",track,{Name="Progress",Size=UDim2.fromScale(.08,1),BackgroundColor3=Color3.fromRGB(199,184,148),BorderSizePixel=0})
local tip=make("TextLabel",panel,{Name="Tip",Position=UDim2.fromOffset(0,160),Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=14,TextColor3=Color3.fromRGB(156,169,160),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
local skip=make("TextButton",root,{Name="ContinueLoading",Visible=false,Active=false,AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,32,1,-28),Size=UDim2.fromOffset(310,44),BackgroundColor3=Color3.fromRGB(35,47,42),BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.fromRGB(225,231,220),AutoButtonColor=false,Selectable=true})
make("UICorner",skip,{CornerRadius=UDim.new(0,3)})
local locale=game:GetService("LocalizationService").SystemLocaleId:sub(1,2)
local function refresh()
    if finished then return end
    local language=player:GetAttribute("SpyLanguage");local en=language=="en"or(language==nil and locale=="en");local zh=language=="zh"or(language==nil and locale=="zh")
    local core=player:GetAttribute("SpyCoreReady")==true;local state=player:GetAttribute("SpyStateReceived")==true
    local scene=player:GetAttribute("SpyEntryPresented")==true
    fill.Size=UDim2.fromScale(core and(scene and .95 or .78)or(state and .55 or .16),1)
    status.Text=zh and(core and "准备入场"or(state and "开启俱乐部"or "连接中"))or en and(core and "PREPARING YOUR ENTRANCE"or(state and "OPENING THE CLUB"or "CONNECTING"))or(core and "ГОТОВИМ ВХОД"or(state and "ОТКРЫВАЕМ КЛУБ"or "ПОДКЛЮЧЕНИЕ"))
    tip.Text=zh and "一个谨慎的问题，比直接指控更能揭开秘密。"or en and "A careful question reveals more than a direct accusation."or "Хороший вопрос расскажет больше, чем прямое обвинение."
    skip.Text=zh and "进入游戏，继续加载    →"or en and "CONTINUE WHILE LOADING    →"or "ПРОДОЛЖИТЬ ЗАГРУЗКУ В ИГРЕ    →"
end
local function fit()
    if finished then return end
    local camera=workspace.CurrentCamera;local v=camera and camera.ViewportSize or Vector2.new(800,600)
    local small=v.X<600
    panel.Size=UDim2.fromOffset(math.min(380,v.X-48),228)
    local bottom=math.min(small and 108 or 52,math.max(12,v.Y-240))
    panel.Position=UDim2.new(1,small and -24 or -48,1,-bottom)
    brand.TextSize=small and 45 or 62
    skip.Size=UDim2.fromOffset(math.min(310,v.X-48),44);skip.Position=UDim2.new(0,24,1,-28)
end
skip.Activated:Connect(function()if skip.Active then finish()end end)
task.delay(6,function()if not finished and gui and gui.Parent then skip.Visible=true;skip.Active=true end end)
for _,attribute in ipairs({"SpyLanguage","SpyCoreReady","SpyStateReceived","SpyEntryPresented"})do connections[#connections+1]=player:GetAttributeChangedSignal(attribute):Connect(refresh)end
for _,attribute in ipairs({"SpyLoadingReleased","SpyClientReady"})do connections[#connections+1]=player:GetAttributeChangedSignal(attribute):Connect(function()if player:GetAttribute(attribute)==true then finish()end end)end
if workspace.CurrentCamera then connections[#connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)end
refresh();fit();pcall(function()First:RemoveDefaultLoadingScreen()end)
if player:GetAttribute("SpyClientReady")==true then finish()end
