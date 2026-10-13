---------------------------------------------------------------------
-- SPY CLUB / CREATOR CONTROL V50.5
---------------------------------------------------------------------
task.spawn(function()
    local Players=game:GetService("Players")
    local UIS=game:GetService("UserInputService")
    local CAS=game:GetService("ContextActionService")
    local RunService=game:GetService("RunService")
    local TweenService=game:GetService("TweenService")
    local ReplicatedStorage=game:GetService("ReplicatedStorage")
    local TextChatService=game:GetService("TextChatService")
    local Workspace=game:GetService("Workspace")
    local me=Players.LocalPlayer
    local pg=me:WaitForChild("PlayerGui")
    local shared=ReplicatedStorage:WaitForChild("SpyShared",20)
    if not shared then return end
    local remote=shared:WaitForChild("AdminCommand",20)
    if not remote or not remote:IsA("RemoteEvent") then return end
    local broadcast=shared:WaitForChild("SpyBroadcast",20)
    local MODE="LOBBY"

    local C={
        bg=Color3.fromRGB(15,19,25), panel=Color3.fromRGB(22,28,36), raised=Color3.fromRGB(29,37,46),
        raised2=Color3.fromRGB(34,44,54), line=Color3.fromRGB(65,82,97), gold=Color3.fromRGB(127,199,218),
        gold2=Color3.fromRGB(167,222,236), text=Color3.fromRGB(238,243,246), muted=Color3.fromRGB(151,165,180),
        red=Color3.fromRGB(174,79,66), redBg=Color3.fromRGB(55,28,26), green=Color3.fromRGB(102,164,112),
    }

    local function corner(parent,r)
        local x=Instance.new("UICorner"); x.CornerRadius=UDim.new(0,r or 8); x.Parent=parent; return x
    end
    local function stroke(parent,color,transparency,thickness)
        local x=Instance.new("UIStroke"); x.Color=color or C.line; x.Transparency=transparency or .35; x.Thickness=thickness or 1; x.Parent=parent; return x
    end
    local function pad(parent,l,r,t,b)
        local x=Instance.new("UIPadding"); x.PaddingLeft=UDim.new(0,l or 0); x.PaddingRight=UDim.new(0,r or l or 0); x.PaddingTop=UDim.new(0,t or 0); x.PaddingBottom=UDim.new(0,b or t or 0); x.Parent=parent; return x
    end
    local function label(parent,text,size,font,color)
        local x=Instance.new("TextLabel"); x.BackgroundTransparency=1; x.BorderSizePixel=0; x.Text=text or ""; x.TextColor3=color or C.text
        x.Font=font or Enum.Font.Roboto; x.TextSize=size or 13; x.TextXAlignment=Enum.TextXAlignment.Left; x.TextYAlignment=Enum.TextYAlignment.Center; x.Parent=parent; return x
    end
    local drafts={};local draftTarget="server"
    local function textbox(parent,placeholder,height)
        local x=Instance.new("TextBox"); x.Size=UDim2.new(1,0,0,height or 40); x.BackgroundColor3=C.raised; x.BorderSizePixel=0; x.Text=""; x.PlaceholderText=placeholder or ""
        x.PlaceholderColor3=Color3.fromRGB(108,124,138); x.TextColor3=C.text; x.Font=Enum.Font.Roboto; x.TextSize=12; x.TextXAlignment=Enum.TextXAlignment.Left
        local key=draftTarget..":"..tostring(placeholder)
        x.Text=drafts[key] or ""
        x:GetPropertyChangedSignal("Text"):Connect(function() drafts[key]=x.Text end)
        x.ClearTextOnFocus=false; x.MultiLine=false; x.Parent=parent; corner(x,8); stroke(x,C.line,.5,1); pad(x,12,12,0,0); return x
    end
    local function button(parent,text,width,danger)
        local x=Instance.new("TextButton"); x.AutoButtonColor=false; x.Active=true; x.Selectable=true; x.Size=UDim2.fromOffset(width or 142,38); x.BackgroundColor3=danger and C.redBg or C.raised2; x.BorderSizePixel=0
        x.Text=text; x.TextColor3=danger and Color3.fromRGB(244,194,181) or C.text; x.Font=Enum.Font.Roboto; x.TextSize=12; x.Parent=parent; corner(x,8); stroke(x,danger and C.red or C.line,.42,1)
        local normal=x.BackgroundColor3
        x.MouseEnter:Connect(function() if x.Active then TweenService:Create(x,TweenInfo.new(.09),{BackgroundColor3=danger and Color3.fromRGB(70,34,30) or Color3.fromRGB(45,62,78)}):Play() end end)
        x.MouseLeave:Connect(function() TweenService:Create(x,TweenInfo.new(.09),{BackgroundColor3=normal}):Play() end)
        return x
    end
    local function setEnabled(x,value)
        local yes=value==true; x.Active=yes; x.Selectable=yes; x.TextTransparency=yes and 0 or .56; x.BackgroundTransparency=yes and 0 or .34
    end
    local function hrow(parent,height,gap)
        local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,height or 40); f.BackgroundTransparency=1; f.Parent=parent
        local l=Instance.new("UIListLayout"); l.FillDirection=Enum.FillDirection.Horizontal; l.Padding=UDim.new(0,gap or 8); l.VerticalAlignment=Enum.VerticalAlignment.Center; l.Parent=f
        return f
    end

    -----------------------------------------------------------------
    -- Broadcast surface. This part runs for every player, not only owner.
    -----------------------------------------------------------------
    local broadcastGui=pg:FindFirstChild("SpyBroadcastGui")
    if broadcastGui then broadcastGui:Destroy() end
    broadcastGui=Instance.new("ScreenGui"); broadcastGui.Name="SpyBroadcastGui"; broadcastGui.ResetOnSpawn=false; broadcastGui.IgnoreGuiInset=true; broadcastGui.DisplayOrder=1140; broadcastGui.Parent=pg
    local banner=Instance.new("Frame"); banner.AnchorPoint=Vector2.new(.5,0); banner.Position=UDim2.new(.5,0,0,-100); banner.Size=UDim2.fromOffset(620,82); banner.BackgroundColor3=Color3.fromRGB(17,15,14); banner.BackgroundTransparency=.035; banner.BorderSizePixel=0; banner.Visible=false; banner.Parent=broadcastGui; corner(banner,10); local bannerStroke=stroke(banner,C.gold,.20,1)
    local accent=Instance.new("Frame"); accent.Size=UDim2.fromOffset(4,54); accent.Position=UDim2.fromOffset(12,14); accent.BackgroundColor3=C.gold; accent.BorderSizePixel=0; accent.Parent=banner; corner(accent,2)
    local bannerTitle=label(banner,"SPY CLUB",11,Enum.Font.RobotoCondensed,C.gold2); bannerTitle.Position=UDim2.fromOffset(30,12); bannerTitle.Size=UDim2.new(1,-48,0,18)
    local bannerText=label(banner,"",15,Enum.Font.Roboto,C.text); bannerText.Position=UDim2.fromOffset(30,30); bannerText.Size=UDim2.new(1,-48,0,42); bannerText.TextWrapped=true; bannerText.TextYAlignment=Enum.TextYAlignment.Top
    local bannerToken=0
    local function chatSystemLine(kind,text)
        local folder=TextChatService:FindFirstChild("TextChannels")
        local channelName=ReplicatedStorage:GetAttribute("SpyChatChannelName") or (MODE=="LOBBY" and "SpyLobbyGlobal" or "SpyMatchGlobal")
        local channel=folder and folder:FindFirstChild(channelName)
        if channel and channel:IsA("TextChannel") then
            local prefix=kind=="warning" and "[ПРЕДУПРЕЖДЕНИЕ] " or "[SPY CLUB] "
            pcall(function() channel:DisplaySystemMessage(prefix..tostring(text or "")) end)
        end
    end
    local function showBroadcast(kind,text)
        if type(text)~="string" or text=="" then return end
        bannerToken=bannerToken+1; local token=bannerToken
        local warning=kind=="warning"
        bannerTitle.Text=warning and "ЛИЧНОЕ ПРЕДУПРЕЖДЕНИЕ" or "SPY CLUB"
        bannerText:SetAttribute("SpyUserText",true);bannerText.Text=text
        local accentColor=warning and C.red or C.gold
        accent.BackgroundColor3=accentColor; bannerStroke.Color=accentColor
        banner.Position=UDim2.new(.5,0,0,-100); banner.Visible=true
        TweenService:Create(banner,TweenInfo.new(.30,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,0,56)}):Play()
        chatSystemLine(kind,text)
        task.delay(warning and 7 or 6,function()
            if token~=bannerToken or not banner.Parent then return end
            local t=TweenService:Create(banner,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(.5,0,0,-100)})
            t:Play(); t.Completed:Once(function() if token==bannerToken and banner.Parent then banner.Visible=false end end)
        end)
    end
    if broadcast and broadcast:IsA("RemoteEvent") then
        broadcast.OnClientEvent:Connect(function(payload)
            if type(payload)~="table" then return end
            if payload.kind=="announcement" or payload.kind=="warning" then showBroadcast(payload.kind,tostring(payload.text or "")) end
        end)
    end

    -----------------------------------------------------------------
    -- Only the owner gets the control panel.
    -----------------------------------------------------------------
    local creatorPanel
    local function buildCreatorPanel()
    local old=pg:FindFirstChild("SpyClubControl")
    if old then old:Destroy() end

    local gui=Instance.new("ScreenGui"); gui.Name="SpyClubControl"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=1120; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Enabled=false; gui.Parent=pg
    local shade=Instance.new("Frame"); shade.Name="AdminBackdrop"; shade.Active=true; shade.ZIndex=1; shade.Size=UDim2.fromScale(1,1); shade.BackgroundColor3=Color3.new(0,0,0); shade.BackgroundTransparency=.45; shade.BorderSizePixel=0; shade.Parent=gui
    local shell=Instance.new("Frame"); shell.Name="AdminPanel"; shell.Active=true; shell.ZIndex=2; shell.AnchorPoint=Vector2.new(.5,.5); shell.Position=UDim2.fromScale(.5,.5); shell.Size=UDim2.fromOffset(980,590); shell.BackgroundColor3=C.bg; shell.BorderSizePixel=0; shell.Parent=gui; corner(shell,12); stroke(shell,C.gold,.34,1)
    local scale=Instance.new("UIScale"); scale.Parent=shell
    local function fit()
        local v=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        scale.Scale=math.max(.1,math.min(1,(v.X-28)/980,(v.Y-28)/590))
    end
    fit(); if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end

    local header=Instance.new("Frame"); header.Size=UDim2.new(1,0,0,64); header.BackgroundTransparency=1; header.Parent=shell
    local title=label(header,"ПУЛЬТ СОЗДАТЕЛЯ",17,Enum.Font.RobotoCondensed,C.gold2); title.Position=UDim2.fromOffset(22,12); title.Size=UDim2.fromOffset(280,24)
    local sub=label(header,MODE=="LOBBY" and "лобби" or "матч",10,Enum.Font.Roboto,C.muted); sub.Position=UDim2.fromOffset(22,35); sub.Size=UDim2.fromOffset(240,18)
    local connection=label(header,"●  подключение",10,Enum.Font.RobotoCondensed,C.muted); connection.AnchorPoint=Vector2.new(1,.5); connection.Position=UDim2.new(1,-74,.5,0); connection.Size=UDim2.fromOffset(160,24); connection.TextXAlignment=Enum.TextXAlignment.Right
    local close=button(header,"×",42,false); close.AnchorPoint=Vector2.new(1,.5); close.Position=UDim2.new(1,-18,.5,0); close.TextSize=18
    local line=Instance.new("Frame"); line.Position=UDim2.new(0,18,1,-1); line.Size=UDim2.new(1,-36,0,1); line.BackgroundColor3=C.line; line.BackgroundTransparency=.35; line.BorderSizePixel=0; line.Parent=header

    local left=Instance.new("Frame"); left.Position=UDim2.fromOffset(18,78); left.Size=UDim2.fromOffset(276,494); left.BackgroundColor3=C.panel; left.BorderSizePixel=0; left.Parent=shell; corner(left,10); stroke(left,C.line,.48,1)
    local search=textbox(left,"Найти игрока…",38); search.Position=UDim2.fromOffset(12,12); search.Size=UDim2.new(1,-24,0,38)
    local rosterStatus=label(left,"Подключение…",10,Enum.Font.Roboto,C.muted); rosterStatus.Position=UDim2.fromOffset(12,54); rosterStatus.Size=UDim2.new(1,-24,0,18)
    local list=Instance.new("ScrollingFrame"); list.Position=UDim2.fromOffset(8,78); list.Size=UDim2.new(1,-16,1,-86); list.BackgroundTransparency=1; list.BorderSizePixel=0; list.ScrollBarThickness=2; list.ScrollBarImageColor3=C.line; list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.new(); list.Parent=left
    local listLayout=Instance.new("UIListLayout"); listLayout.Padding=UDim.new(0,6); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=list

    local right=Instance.new("Frame"); right.Position=UDim2.fromOffset(308,78); right.Size=UDim2.new(1,-326,1,-96); right.BackgroundTransparency=1; right.Parent=shell
    local identity=Instance.new("Frame"); identity.Size=UDim2.new(1,0,0,88); identity.BackgroundColor3=C.panel; identity.BorderSizePixel=0; identity.Parent=right; corner(identity,10); stroke(identity,C.line,.48,1)
    local avatar=Instance.new("ImageLabel"); avatar.Position=UDim2.fromOffset(12,12); avatar.Size=UDim2.fromOffset(64,64); avatar.BackgroundColor3=C.raised; avatar.BorderSizePixel=0; avatar.Image=""; avatar.Parent=identity; corner(avatar,8)
    local identityName=label(identity,"Выбери игрока",15,Enum.Font.RobotoCondensed,C.text); identityName.Position=UDim2.fromOffset(90,12); identityName.Size=UDim2.new(1,-260,0,22)
    local identityUser=label(identity,"",10,Enum.Font.Roboto,C.muted); identityUser.Position=UDim2.fromOffset(90,36); identityUser.Size=UDim2.new(1,-260,0,18)
    local identityStats=label(identity,"",11,Enum.Font.Roboto,C.gold2); identityStats.Position=UDim2.fromOffset(90,56); identityStats.Size=UDim2.new(1,-260,0,18)
    local serverText=label(identity,"",10,Enum.Font.Roboto,C.muted); serverText.AnchorPoint=Vector2.new(1,0); serverText.Position=UDim2.new(1,-14,0,14); serverText.Size=UDim2.fromOffset(210,56); serverText.TextXAlignment=Enum.TextXAlignment.Right; serverText.TextYAlignment=Enum.TextYAlignment.Top

    local tabs=Instance.new("Frame"); tabs.Position=UDim2.fromOffset(0,100); tabs.Size=UDim2.new(1,0,0,42); tabs.BackgroundTransparency=1; tabs.Parent=right
    local tabLayout=Instance.new("UIListLayout"); tabLayout.FillDirection=Enum.FillDirection.Horizontal; tabLayout.Padding=UDim.new(0,8); tabLayout.VerticalAlignment=Enum.VerticalAlignment.Center; tabLayout.Parent=tabs
    local body=Instance.new("ScrollingFrame"); body.Position=UDim2.fromOffset(0,150); body.Size=UDim2.new(1,0,1,-150); body.BackgroundTransparency=1; body.BorderSizePixel=0; body.ScrollBarThickness=2; body.ScrollBarImageColor3=C.line; body.AutomaticCanvasSize=Enum.AutomaticSize.Y; body.CanvasSize=UDim2.new(); body.Parent=right
    local bodyLayout=Instance.new("UIListLayout"); bodyLayout.Padding=UDim.new(0,10); bodyLayout.SortOrder=Enum.SortOrder.LayoutOrder; bodyLayout.Parent=body

    local modal=Instance.new("Frame"); modal.AnchorPoint=Vector2.new(.5,.5); modal.Position=UDim2.fromScale(.5,.5); modal.Size=UDim2.fromOffset(430,190); modal.BackgroundColor3=C.panel; modal.BorderSizePixel=0; modal.Visible=false; modal.ZIndex=50; modal.Parent=shell; corner(modal,10); stroke(modal,C.gold,.26,1)
    local modalTitle=label(modal,"Подтвердить действие",14,Enum.Font.RobotoCondensed,C.gold2); modalTitle.Position=UDim2.fromOffset(18,16); modalTitle.Size=UDim2.new(1,-36,0,22); modalTitle.ZIndex=51
    local modalText=label(modal,"",12,Enum.Font.Roboto,C.text); modalText.Position=UDim2.fromOffset(18,48); modalText.Size=UDim2.new(1,-36,0,76); modalText.TextWrapped=true; modalText.TextYAlignment=Enum.TextYAlignment.Top; modalText.ZIndex=51
    local modalYes=button(modal,"Подтвердить",150,true); modalYes.Position=UDim2.new(1,-318,1,-52); modalYes.ZIndex=51
    local modalNo=button(modal,"Отмена",130,false); modalNo.Position=UDim2.new(1,-152,1,-52); modalNo.ZIndex=51
    local pendingConfirm=nil
    local function confirm(text,fn) pendingConfirm=fn; modalText.Text=text; modal.Visible=true end
    modalNo.Activated:Connect(function() pendingConfirm=nil; modal.Visible=false end)
    modalYes.Activated:Connect(function() local fn=pendingConfirm; pendingConfirm=nil; modal.Visible=false; if fn then fn() end end)

    local toast=label(shell,"",11,Enum.Font.Roboto,C.text); toast.AnchorPoint=Vector2.new(.5,1); toast.Position=UDim2.new(.5,0,1,-10); toast.Size=UDim2.fromOffset(420,28); toast.BackgroundColor3=C.raised; toast.BackgroundTransparency=.08; toast.TextXAlignment=Enum.TextXAlignment.Center; toast.Visible=false; toast.ZIndex=45; corner(toast,8); local toastStroke=stroke(toast,C.line,.42,1)
    local toastToken=0
    local function flash(text,bad)
        toastToken=toastToken+1; local token=toastToken; toast.Text=tostring(text or ""); toast.TextColor3=bad and Color3.fromRGB(245,190,177) or C.text; toastStroke.Color=bad and C.red or C.line; toast.Visible=true; toast.TextTransparency=1; toast.BackgroundTransparency=1
        TweenService:Create(toast,TweenInfo.new(.12),{TextTransparency=0,BackgroundTransparency=.08}):Play()
        task.delay(2.2,function() if token~=toastToken or not toast.Parent then return end; TweenService:Create(toast,TweenInfo.new(.16),{TextTransparency=1,BackgroundTransparency=1}):Play(); task.delay(.18,function() if token==toastToken and toast.Parent then toast.Visible=false end end) end)
    end

    local open=false; local roster={}; local serverData={}; local selected=nil; local selectedUserId=nil; local requestSerial=0; local activeTab="PLAYER"; local tabButtons={}; local spectating=false; local previousCameraSubject=nil
    local friendly={ok="Готово",healed="Здоровье восстановлено",killed="Игрок убит",respawned="Персонаж перезагружен",frozen="Игрок заморожен",unfrozen="Заморозка снята",muted="Чат игрока выключен",unmuted="Чат игрока включён",sent="Предупреждение отправлено",announced="Объявление показано",kicked="Игрок исключён",returning="Возвращаем в лобби",ending="Матч завершается",target_left="Игрок уже вышел",character_unavailable="Персонаж недоступен",rate_limited="Слишком быстро",profile_rate_limited="Подожди немного",invalid_item="Такого предмета нет",bad_delta="Проверь число монет",bad_level="Проверь уровень",filter_failed="Фильтрация Roblox недоступна. Повтори позже.",filter_unavailable_in_studio="Фильтрация Roblox недоступна в Studio. Проверь в опубликованной игре.",denied="Нет доступа",bad_text="Проверь текст"}

    local diagnosticText="Нажми «Проверить запуск», чтобы увидеть состояние сервера и чата."
    local diagnosticBox
    local pendingCommands={}
    local function send(command,extra)
        requestSerial=requestSerial+1;local id=requestSerial;local p=extra or {};p.command=command;p.requestId=id
        if command~="list" then
            pendingCommands[id]=command
            task.delay(10,function()
                if pendingCommands[id] then pendingCommands[id]=nil;flash("Сервер не ответил. Повтори действие.",true) end
            end)
        end
        remote:FireServer(p);return id
    end
    local function sendTarget(command,extra)
        if not selectedUserId then flash("Сначала выбери игрока",true); return end
        local p=extra or {}; p.targetUserId=selectedUserId; send(command,p)
    end
    local requestList
    requestList=function() send("list") end

    local function formatUptime(value)
        local n=math.max(0,tonumber(value) or 0); local h=math.floor(n/3600); local m=math.floor(n%3600/60); local s=math.floor(n%60)
        return h>0 and string.format("%dч %02dм",h,m) or string.format("%02d:%02d",m,s)
    end
    local function findSelected()
        if not selectedUserId then return nil end
        for _,item in ipairs(roster) do if item.userId==selectedUserId then return item end end
        return nil
    end
    local function updateIdentity()
        selected=findSelected()
        if not selected then
            identityName.Text="Выбери игрока"; identityUser.Text=""; identityStats.Text=""; avatar.Image=""; return
        end
        identityName:SetAttribute("SpyUserText",true);identityName.Text=tostring(selected.displayName or selected.username or "Игрок")
        identityUser.Text="@"..tostring(selected.username or "").."   •   ID "..tostring(selected.userId)
        local hp=(selected.maxHealth or 0)>0 and ("HP "..tostring(selected.health or 0).."/"..tostring(selected.maxHealth or 0)) or "HP —"
        identityStats.Text=hp.."   •   ур. "..tostring(selected.level or 1).."   •   ◈ "..tostring(selected.coins or 0)..(selected.muted and "   •   чат выключен" or "")
        task.spawn(function()
            local ok,img=pcall(function() return Players:GetUserThumbnailAsync(selected.userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100) end)
            if ok and selected and selected.userId==selectedUserId then avatar.Image=img end
        end)
    end
    local function updateServerText()
        serverText.Text="игроки  "..tostring(serverData.playerCount or #roster).."/"..tostring(serverData.maxPlayers or 0).."\nвремя  "..formatUptime(serverData.uptime).."\n"..(MODE=="LOBBY" and "лобби" or "матч")
    end
    local render
    local serverInfoLabel
    local function clearRows()
        for _,x in ipairs(list:GetChildren()) do if x:IsA("GuiObject") then x:Destroy() end end
    end
    local function drawRoster()
        clearRows(); local q=string.lower(search.Text or ""); local shown=0
        for _,item in ipairs(roster) do
            local hay=string.lower(tostring(item.displayName or "").." "..tostring(item.username or "").." "..tostring(item.userId or ""))
            if q=="" or string.find(hay,q,1,true) then
                shown=shown+1
                local row=Instance.new("TextButton"); row.AutoButtonColor=false; row.Size=UDim2.new(1,-4,0,58); row.BackgroundColor3=item.userId==selectedUserId and Color3.fromRGB(41,61,74) or C.raised; row.BorderSizePixel=0; row.Text=""; row.Parent=list; corner(row,8); stroke(row,item.staffRole=="creator" and C.gold or C.line,item.userId==selectedUserId and .20 or .58,1)
                local av=Instance.new("ImageLabel"); av.Position=UDim2.fromOffset(7,7); av.Size=UDim2.fromOffset(44,44); av.BackgroundColor3=C.raised2; av.BorderSizePixel=0; av.Parent=row; corner(av,7)
                local nm=label(row,tostring(item.displayName or item.username or "Игрок"),12,Enum.Font.Roboto,item.staffRole=="creator" and C.gold2 or C.text); nm.Name="ParticipantName";nm:SetAttribute("SpyUserText",true); nm.Position=UDim2.fromOffset(60,8); nm.Size=UDim2.new(1,-68,0,20)
                local st=label(row,"@"..tostring(item.username or "").."   •   ур. "..tostring(item.level or 1).."   •   ◈ "..tostring(item.coins or 0),9,Enum.Font.Roboto,C.muted); st.Name="ParticipantUsername";st:SetAttribute("SpyUserText",true); st.Position=UDim2.fromOffset(60,29); st.Size=UDim2.new(1,-68,0,18)
                if item.staffRole=="creator" then local cr=label(row,"СОЗДАТЕЛЬ",8,Enum.Font.RobotoCondensed,C.gold2); cr.AnchorPoint=Vector2.new(1,0); cr.Position=UDim2.new(1,-8,0,7); cr.Size=UDim2.fromOffset(72,14); cr.TextXAlignment=Enum.TextXAlignment.Right end
                row.Activated:Connect(function() selectedUserId=item.userId; updateIdentity(); drawRoster(); if render then render() end end)
                task.spawn(function() local ok,img=pcall(function() return Players:GetUserThumbnailAsync(item.userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48) end); if ok and av.Parent then av.Image=img end end)
            end
        end
        rosterStatus.Text=tostring(shown).." игрок"..(shown==1 and "" or "ов")
    end
    local function applyRoster(data)
        local hadSelection=selected~=nil
        roster=type(data.players)=="table" and data.players or {}; serverData=type(data.server)=="table" and data.server or {}
        selected=findSelected();connection.Text="●  на связи";connection.TextColor3=C.green
        updateIdentity();updateServerText();drawRoster()
        if serverInfoLabel and serverInfoLabel.Parent then
            serverInfoLabel.Text="Онлайн  "..tostring(serverData.playerCount or #roster).."/"..tostring(serverData.maxPlayers or 0).."     •     Время  "..formatUptime(serverData.uptime).."     •     Place  "..tostring(serverData.placeId or game.PlaceId)
        end
        -- Keep focused textboxes and their contents alive during periodic polling.
        if hadSelection~=(selected~=nil) and activeTab~="SERVER" and activeTab~="FEEDBACK" and render then render() end
    end

    remote.OnClientEvent:Connect(function(msg)
        if type(msg)~="table" or msg.type~="receipt" then return end
        if msg.requestId then pendingCommands[msg.requestId]=nil end
        if msg.command=="diagnostics" and msg.ok and type(msg.data)=="table" then
            local d=msg.data
            diagnosticText="Сборка: "..tostring(d.build).." | Place: "..tostring(d.placeId).."\nВладелец: "..tostring(d.creatorId).." | Права: "..tostring(d.identity)..
                "\nLobby: "..tostring(d.lobby or "—").." | Session: "..tostring(d.session or "—").." | Match: "..tostring(d.round or "—")..
                "\nЧат Lobby: "..tostring(d.lobbyChat or "—").." / "..tostring(d.lobbyChatDetail or "")..
                "\nЧат Match: "..tostring(d.matchChat or "—").." / "..tostring(d.matchChatDetail or "")..
                "\nПоследняя отправка: "..tostring(me:GetAttribute("SpyChatLastSendStatus") or "—")..
                "\nЭтап: "..tostring(me:GetAttribute("SpyChatLastSendStage") or "—").." / "..tostring(me:GetAttribute("SpyChatLastSendReason") or "—")..
                "\nОшибка: "..tostring(d.lobbyError or d.sessionError or d.roundError or me:GetAttribute("SpyAdminUIError") or "нет")
            if diagnosticBox and diagnosticBox.Parent then diagnosticBox.Text=diagnosticText end
            return
        end
        if msg.command=="list" and msg.ok and type(msg.data)=="table" then applyRoster(msg.data); return end
        flash((msg.ok and "✓  " or "×  ")..(friendly[msg.code] or tostring(msg.code or "Ошибка")),not msg.ok)
        if msg.ok then task.delay(.12,requestList) end
    end)

    local function stopSpectate()
        if not spectating then return end; spectating=false; local cam=Workspace.CurrentCamera; if cam then local char=me.Character; cam.CameraSubject=(char and char:FindFirstChildOfClass("Humanoid")) or previousCameraSubject end; previousCameraSubject=nil
    end
    local function startSpectate()
        if not selectedUserId then flash("Сначала выбери игрока",true); return end
        local p=Players:GetPlayerByUserId(selectedUserId); local hum=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid"); local cam=Workspace.CurrentCamera
        if not hum or not cam then flash("Персонаж недоступен",true); return end
        previousCameraSubject=cam.CameraSubject; cam.CameraSubject=hum; spectating=true; flash("Наблюдение: "..tostring(p.DisplayName),false); if render then render() end
    end
    local function highlightSelected()
        local p=selectedUserId and Players:GetPlayerByUserId(selectedUserId); local char=p and p.Character; if not char then flash("Персонаж недоступен",true); return end
        local old=char:FindFirstChild("SpyAdminLocate"); if old then old:Destroy() end
        local h=Instance.new("Highlight"); h.Name="SpyAdminLocate"; h.FillColor=C.gold; h.FillTransparency=.72; h.OutlineColor=C.gold2; h.OutlineTransparency=.05; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.Parent=char
        task.delay(10,function() if h.Parent then h:Destroy() end end); flash("Игрок подсвечен на 10 секунд",false)
    end

    local inboxView
    local function clearBody()
        if inboxView then inboxView.destroy();inboxView=nil end
        for _,x in ipairs(body:GetChildren()) do if x:IsA("GuiObject") then x:Destroy() end end
        body.CanvasPosition=Vector2.new()
    end
    local function heading(text,subtext)
        local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,46); f.BackgroundTransparency=1; f.Parent=body
        local a=label(f,text,13,Enum.Font.RobotoCondensed,C.gold2); a.Size=UDim2.new(1,0,0,20)
        local b=label(f,subtext or "",10,Enum.Font.Roboto,C.muted); b.Position=UDim2.fromOffset(0,21); b.Size=UDim2.new(1,0,0,18)
    end
    local function action(parent,text,command,danger,confirmText)
        local b=button(parent,text,146,danger); setEnabled(b,selectedUserId~=nil)
        b.Activated:Connect(function() if not selectedUserId then return end; local run=function() sendTarget(command) end; if confirmText then confirm(confirmText,run) else run() end end); return b
    end

    render=function()
        clearBody();serverInfoLabel=nil;diagnosticBox=nil;selected=findSelected();updateIdentity()
        draftTarget=activeTab..":"..(activeTab=="SERVER" and "server" or tostring(selectedUserId or "none"))
        if activeTab=="PLAYER" then
            heading("Игрок","Быстрые действия без лишних окон")
            local r1=hrow(body); action(r1,"К нему","goto"); action(r1,"Ко мне","bring"); action(r1,"Заморозить","freeze"); action(r1,"Снять заморозку","unfreeze")
            local r2=hrow(body); action(r2,"Вылечить","heal"); action(r2,"Переродить","respawn",false,"Перезагрузить персонажа выбранного игрока?")
            local watch=button(r2,spectating and "Вернуть камеру" or "Наблюдать",146,false); setEnabled(watch,selectedUserId~=nil or spectating); watch.Activated:Connect(function() if spectating then stopSpectate(); flash("Камера возвращена",false); render() else startSpectate() end end)
            local locate=button(r2,"Подсветить",146,false); setEnabled(locate,selectedUserId~=nil); locate.Activated:Connect(highlightSelected)
            local r3=hrow(body); action(r3,"Убить","kill",true,"Убить выбранного игрока?")
            if MODE=="MATCH" then action(r3,"Вернуть в лобби","returnLobby",true,"Вернуть выбранного игрока в лобби?") end
        elseif activeTab=="CHAT" then
            heading("Чат и модерация","Только для выбранного игрока")
            local r1=hrow(body); action(r1,"Выключить чат","mute"); action(r1,"Вернуть чат","unmute")
            local warn=textbox(body,"Напиши предупреждение игроку…",42)
            local r2=hrow(body); local wb=button(r2,"Отправить предупреждение",210,false); setEnabled(wb,selectedUserId~=nil); wb.Activated:Connect(function() if warn.Text~="" then sendTarget("warning",{text=warn.Text}) end end)
            local reason=textbox(body,"Причина исключения…",42)
            local r3=hrow(body); local kb=button(r3,"Исключить с сервера",190,true); setEnabled(kb,selectedUserId~=nil); kb.Activated:Connect(function() if selectedUserId then confirm("Исключить "..tostring(selected and selected.displayName or "игрока").."?",function() sendTarget("kick",{reason=reason.Text}) end) end end)
        elseif activeTab=="PROFILE" then
            heading("Профиль","Монеты, уровень и косметика")
            local quick=hrow(body)
            for _,e in ipairs({{"+100",100},{"+1 000",1000},{"−100",-100},{"−1 000",-1000}}) do local b=button(quick,e[1],112,e[2]<0); setEnabled(b,selectedUserId~=nil); b.Activated:Connect(function() if not selected then return end; local after=math.max(0,(tonumber(selected.coins) or 0)+e[2]); confirm("Монеты: "..tostring(selected.coins or 0).." → "..tostring(after),function() sendTarget("coins",{delta=e[2]}) end) end) end
            local coins=textbox(body,"Своё изменение монет, например 5000 или -250",42); local cr=hrow(body); local cb=button(cr,"Применить",150,false); setEnabled(cb,selectedUserId~=nil); cb.Activated:Connect(function() local n=tonumber(coins.Text); if not n or n%1~=0 or not selected then flash("Нужно целое число",true); return end; local after=math.max(0,(tonumber(selected.coins) or 0)+n); confirm("Монеты: "..tostring(selected.coins or 0).." → "..tostring(after),function() sendTarget("coins",{delta=n}) end) end)
            local lvl=textbox(body,"Новый уровень, 1–10000",42); local lr=hrow(body); local lb=button(lr,"Установить уровень",190,false); setEnabled(lb,selectedUserId~=nil); lb.Activated:Connect(function() local n=tonumber(lvl.Text); if not n or n%1~=0 or not selected then flash("Проверь уровень",true); return end; confirm("Уровень: "..tostring(selected.level or 1).." → "..tostring(n),function() sendTarget("level",{level=n}) end) end)
            local item=textbox(body,"ID предмета из каталога",42); local ir=hrow(body); local ib=button(ir,"Выдать предмет",170,false); setEnabled(ib,selectedUserId~=nil); ib.Activated:Connect(function() if item.Text=="" or not selected then flash("Укажи ID предмета",true); return end; confirm("Выдать «"..item.Text.."» игроку "..tostring(selected.displayName).."?",function() sendTarget("grant",{itemId=item.Text}) end) end)
        elseif activeTab=="FEEDBACK" then
            local module=shared:FindFirstChild("DeveloperInboxUI")
            local ok,value=pcall(function() return module and require(module).mount(body,shared) end)
            if ok and value then inboxView=value else heading("Обращения","Ящик временно недоступен. Открой вкладку ещё раз.") end
        elseif activeTab=="SERVER" then
            heading("Сервер","Объявления и общие действия")
            local info=Instance.new("Frame"); info.Size=UDim2.new(1,0,0,76); info.BackgroundColor3=C.panel; info.BorderSizePixel=0; info.Parent=body; corner(info,8); stroke(info,C.line,.55,1)
            local il=label(info,"Онлайн  "..tostring(serverData.playerCount or #roster).."/"..tostring(serverData.maxPlayers or 0).."     •     Время  "..formatUptime(serverData.uptime).."     •     Place  "..tostring(serverData.placeId or game.PlaceId),11,Enum.Font.Roboto,C.text); il.Position=UDim2.fromOffset(14,10); il.Size=UDim2.new(1,-28,0,22);serverInfoLabel=il
            local hint=label(info,"Объявление увидит весь текущий сервер и появится в чате.",10,Enum.Font.Roboto,C.muted); hint.Position=UDim2.fromOffset(14,36); hint.Size=UDim2.new(1,-28,0,20)
            local ann=textbox(body,"Текст объявления…",44)
            local ar=hrow(body); local ab=button(ar,"Показать объявление",200,false); ab.Activated:Connect(function() if ann.Text:match("%S") then send("announce",{text=ann.Text}) else flash("Напиши текст объявления",true) end end); local ref=button(ar,"Обновить список",160,false); ref.Activated:Connect(requestList)
            local dr=hrow(body);local db=button(dr,"Проверить запуск",190,false)
            db.Activated:Connect(function() send("diagnostics") end)
            diagnosticBox=textbox(body,"Состояние запуска",180);diagnosticBox.Text=diagnosticText;diagnosticBox.MultiLine=true;diagnosticBox.TextWrapped=true;diagnosticBox.TextEditable=false;diagnosticBox.TextYAlignment=Enum.TextYAlignment.Top
            if MODE=="MATCH" then local sr=hrow(body); local all=button(sr,"Всех в лобби",170,true); all.Activated:Connect(function() confirm("Вернуть всех игроков этого сервера в лобби?",function() send("returnAll") end) end); local e=button(sr,"Завершить матч",170,true); e.Activated:Connect(function() confirm("Завершить текущий матч и вернуть игроков в лобби?",function() send("endMatch") end) end) end
        end
    end

    local tabsSpec=MODE=="LOBBY" and {{"PLAYER","Игрок"},{"CHAT","Чат"},{"PROFILE","Профиль"},{"SERVER","Сервер"},{"FEEDBACK","Обращения"}} or {{"PLAYER","Игрок"},{"CHAT","Чат"},{"SERVER","Сервер"},{"FEEDBACK","Обращения"}}
    local function setTab(name)
        activeTab=name; for key,b in pairs(tabButtons) do local on=key==name; b.BackgroundColor3=on and Color3.fromRGB(41,61,74) or C.raised; b.TextColor3=on and C.gold2 or C.muted end; render()
    end
    for _,spec in ipairs(tabsSpec) do local b=button(tabs,spec[2],112,false); tabButtons[spec[1]]=b; b.Activated:Connect(function() setTab(spec[1]) end) end
    setTab("PLAYER")
    search:GetPropertyChangedSignal("Text"):Connect(drawRoster)

    local function setOpen(value)
        open=value==true and me:GetAttribute("SpyIsAdmin")==true; gui.Enabled=open
        if open then connection.Text="●  подключение"; connection.TextColor3=C.muted; rosterStatus.Text="Подключение…"; requestList(); updateIdentity(); drawRoster(); render() else modal.Visible=false; if spectating then stopSpectate() end end
    end
    local openerGui=pg:FindFirstChild("SpyCreatorLauncher")
    if not openerGui then openerGui=Instance.new("ScreenGui");openerGui.Name="SpyCreatorLauncher";openerGui.ResetOnSpawn=false;openerGui.IgnoreGuiInset=true;openerGui.DisplayOrder=1110;openerGui.Parent=pg end
    local launcher=button(openerGui,"ПУЛЬТ  ·  F2",124,false)
    launcher.Name="OpenCreatorControl";launcher.AnchorPoint=Vector2.new(1,0);launcher.Position=UDim2.new(1,-18,0,108)
    launcher.Activated:Connect(function() setOpen(not open) end)
    me:GetAttributeChangedSignal("SpyIsAdmin"):Connect(function()
        local allowed=me:GetAttribute("SpyIsAdmin")==true
        launcher.Visible=allowed
        if not allowed then setOpen(false) end
    end)
    close.Activated:Connect(function() setOpen(false) end)
    CAS:BindActionAtPriority("SpyClubCreatorControlF2",function(_,state) if state==Enum.UserInputState.Begin then setOpen(not open) end; return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+50,Enum.KeyCode.F2)
    UIS.InputBegan:Connect(function(input) if input.KeyCode==Enum.KeyCode.Escape and open then setOpen(false) end end)
    Players.PlayerAdded:Connect(function() if open then task.delay(.15,requestList) end end)
    Players.PlayerRemoving:Connect(function(p) if selectedUserId==p.UserId then selectedUserId=nil; selected=nil; stopSpectate() end; if open then task.delay(.15,requestList) end end)
    task.spawn(function() while gui.Parent do if open then requestList() end; task.wait(2.5) end end)

    if MODE=="LOBBY" then
        task.spawn(function()
            local directory=pg:WaitForChild("SpyPlayerDirectory",20); if not directory then return end
            local dp=directory:FindFirstChild("DirectoryPanel",true); if not dp or dp:FindFirstChild("SpyControlButton") then return end
            local b=button(dp,"ПУЛЬТ  [F2]",122,false); b.Name="SpyControlButton"; b.AnchorPoint=Vector2.new(1,0); b.Position=UDim2.new(1,-62,0,18); b.ZIndex=30; b.Activated:Connect(function() setOpen(true) end)
        end)
    end
    print("SPY_CREATOR_CONTROL_READY",MODE,"V50.5",me.Name,me.UserId,RunService:IsStudio())
    return gui
    end
    local building=false
    local function launchIfAuthorized()
        if me:GetAttribute("SpyIsAdmin")~=true or building or (creatorPanel and creatorPanel.Parent) then return end
        building=true
        local ok,value=xpcall(buildCreatorPanel,debug.traceback)
        building=false
        if ok then creatorPanel=value;me:SetAttribute("SpyAdminUIState","ready")
        else me:SetAttribute("SpyAdminUIState","failed");me:SetAttribute("SpyAdminUIError",tostring(value):sub(1,1000));warn("SpyClub creator panel: "..tostring(value)) end
    end
    me:SetAttribute("SpyAdminUIState","waiting_authorization")
    me:GetAttributeChangedSignal("SpyIsAdmin"):Connect(function() task.spawn(launchIfAuthorized) end)
    launchIfAuthorized()

end)

-- SPY CLUB PREMIUM SHOP V1 :: LobbyHUDPolishClient
-- SPY_COSMETICS_V1: LobbyHUDPolishClient
-- StarterPlayer > StarterPlayerScripts > LobbyHUDPolishClient
-- SPY CLUB / LOBBY HUD POLISH V5
-- FULL REPLACEMENT
--
-- • Daily всегда остаётся слева
-- • нижний статус меняется Lobby <-> Party
-- • справа ничего не создаётся
-- • код приватного стола не показывается
-- • настоящий DailyDock остаётся рабочим
-- • TableReservationClient не изменяется

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("SpyShared"):WaitForChild("Catalog"))
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- COLORS
---------------------------------------------------------------------

local C = {
	Panel = Color3.fromRGB(16, 24, 33),
	PanelRaised = Color3.fromRGB(26, 37, 49),

	Cream = Color3.fromRGB(236, 243, 247),
	CreamSoft = Color3.fromRGB(167, 190, 210),

	Gold = Color3.fromRGB(143, 208, 224),

	Text = Color3.fromRGB(237, 243, 247),
	Muted = Color3.fromRGB(145, 167, 188),

	Shadow = Color3.fromRGB(0, 0, 0),
}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function create(className, parent, properties)
	local object = Instance.new(className)

	for property, value in pairs(properties or {}) do
		object[property] = value
	end

	object.Parent = parent

	return object
end

local function getCorner(parent, radius)
	local corner =
		parent:FindFirstChild(
			"SpyPolishCorner"
		)

	if not corner then
		corner = Instance.new("UICorner")
		corner.Name = "SpyPolishCorner"
		corner.Parent = parent
	end

	corner.CornerRadius =
		UDim.new(
			0,
			radius
		)

	return corner
end

local function getStroke(
	parent,
	color,
	transparency,
	thickness
)
	local stroke =
		parent:FindFirstChild(
			"SpyPolishStroke"
		)

	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "SpyPolishStroke"
		stroke.Parent = parent
	end

	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness

	return stroke
end

local function textLabel(
	parent,
	name,
	text,
	position,
	size,
	font,
	textSize,
	color,
	zIndex
)
	local label = create(
		"TextLabel",
		parent,
		{
			Name = name,

			BackgroundTransparency = 1,

			Position = position,
			Size = size,

			Text = text,

			Font =
				font
				or Enum.Font.BuilderSans,

			TextSize =
				textSize
				or 12,

			TextColor3 =
				color
				or C.Text,

			TextXAlignment =
				Enum.TextXAlignment.Left,

			TextYAlignment =
				Enum.TextYAlignment.Center,

			BorderSizePixel = 0,

			ZIndex =
				zIndex
				or 10,
		}
	)

	return label
end

---------------------------------------------------------------------
-- CLEAN OLD VERSION
---------------------------------------------------------------------

local previous =
	playerGui:FindFirstChild(
		"SpyLobbyPolishUI"
	)

if previous then
	-----------------------------------------------------------------
	-- DailyDock настоящий.
	-- Спасаем его перед удалением старого HUD.
	-----------------------------------------------------------------

	local savedDaily =
		previous:FindFirstChild(
			"DailyDock",
			true
		)

	if savedDaily
		and savedDaily:IsA("GuiButton")
	then
		savedDaily.Parent =
			playerGui
	end

	previous:Destroy()
end

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local gui = create(
	"ScreenGui",
	playerGui,
	{
		Name = "SpyLobbyPolishUI",

		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		DisplayOrder = 24,

		ZIndexBehavior =
			Enum.ZIndexBehavior.Sibling,
	}
)

---------------------------------------------------------------------
-- LEFT RAIL
---------------------------------------------------------------------

local rail = create(
	"Frame",
	gui,
	{
		Name = "LeftRail",

		AnchorPoint =
			Vector2.new(
				0,
				0.5
			),

		Position =
			UDim2.new(
				0,
				28,
				0.5,
				0
			),

		Size =
			UDim2.fromOffset(
				248,
				128
			),

		BackgroundTransparency = 1,

		ZIndex = 40,
	}
)

---------------------------------------------------------------------
-- DAILY SHADOW
---------------------------------------------------------------------

local dailyShadow = create(
	"Frame",
	rail,
	{
		Name = "DailyShadow",

		Position =
			UDim2.fromOffset(
				4,
				5
			),

		Size =
			UDim2.fromOffset(
				244,
				66
			),

		BackgroundColor3 =
			C.Shadow,

		BackgroundTransparency =
			0.52,

		BorderSizePixel = 0,

		ZIndex = 40,
	}
)

getCorner(
	dailyShadow,
	9
)

-- Remove the unused translucent DailyShadow above the lobby status card.
local dailyShadow = rail:FindFirstChild("DailyShadow")
if dailyShadow then
	dailyShadow:Destroy()
end

---------------------------------------------------------------------
-- DAILY HOST
---------------------------------------------------------------------

local dailyHost = create(
	"Frame",
	rail,
	{
		Name = "DailyHost",

		Position =
			UDim2.fromOffset(
				0,
				0
			),

		Size =
			UDim2.fromOffset(
				244,
				66
			),

		BackgroundTransparency = 1,

		ZIndex = 41,
	}
)

---------------------------------------------------------------------
-- STATUS PANEL
---------------------------------------------------------------------

local status = create(
	"Frame",
	rail,
	{
		Name = "Status",

		Position =
			UDim2.fromOffset(
				0,
				78
			),

		Size =
			UDim2.fromOffset(
				244,
				50
			),

		BackgroundColor3 =
			C.Panel,

		BackgroundTransparency =
			0.05,

		BorderSizePixel = 0,

		ZIndex = 42,
	}
)

getCorner(
	status,
	8
)

local statusStroke =
	getStroke(
		status,
		C.CreamSoft,
		0.55,
		1
	)

---------------------------------------------------------------------
-- STATUS ACCENT
---------------------------------------------------------------------

local statusAccent = create(
	"Frame",
	status,
	{
		Name = "Accent",

		Position =
			UDim2.fromOffset(
				0,
				11
			),

		Size =
			UDim2.fromOffset(
				2,
				28
			),

		BackgroundColor3 =
			C.Gold,

		BorderSizePixel = 0,

		ZIndex = 44,
	}
)

getCorner(
	statusAccent,
	2
)

---------------------------------------------------------------------
-- STATUS TITLE
---------------------------------------------------------------------

local statusTitle = textLabel(
	status,
	"Title",
	"ЛОББИ",
	UDim2.fromOffset(
		14,
		5
	),
	UDim2.new(
		1,
		-82,
		0,
		22
	),
	Enum.Font.BuilderSansMedium,
	11,
	C.Cream,
	45
)

---------------------------------------------------------------------
-- STATUS SUBTITLE
---------------------------------------------------------------------

local statusSubtitle = textLabel(
	status,
	"Subtitle",
	"ИГРОКОВ В СЕРВЕРЕ",
	UDim2.fromOffset(
		14,
		26
	),
	UDim2.new(
		1,
		-76,
		0,
		17
	),
	Enum.Font.BuilderSans,
	8,
	C.Muted,
	45
)

statusSubtitle.TextTruncate =
	Enum.TextTruncate.AtEnd

---------------------------------------------------------------------
-- STATUS COUNT
---------------------------------------------------------------------

local statusCount = textLabel(
	status,
	"Count",
	"1",
	UDim2.new(
		1,
		-66,
		0,
		0
	),
	UDim2.fromOffset(
		50,
		50
	),
	Enum.Font.BuilderSansMedium,
	13,
	C.Cream,
	45
)

statusCount.TextXAlignment =
	Enum.TextXAlignment.Right

---------------------------------------------------------------------
-- STATUS SCALE FOR TRANSITION
---------------------------------------------------------------------

local statusScale = create(
	"UIScale",
	status,
	{
		Scale = 1,
	}
)

---------------------------------------------------------------------
-- PARTY
---------------------------------------------------------------------

local currentParty = nil

---------------------------------------------------------------------
-- SERVER COUNT
---------------------------------------------------------------------

local function serverPlayerCount()
	return #Players:GetPlayers()
end

---------------------------------------------------------------------
-- STATUS TRANSITION
---------------------------------------------------------------------

local statusAnimationId = 0

local function animateStatusChange()
	statusAnimationId += 1

	local thisAnimation =
		statusAnimationId

	TweenService:
		Create(
			statusScale,
			TweenInfo.new(
				0.08,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{
				Scale = 0.975,
			}
		):
		Play()

	TweenService:
		Create(
			statusStroke,
			TweenInfo.new(
				0.08
			),
			{
				Transparency = 0.18,
				Color = C.Gold,
			}
		):
		Play()

	task.delay(
		0.08,
		function()
			if thisAnimation
				~= statusAnimationId
			then
				return
			end

			TweenService:
				Create(
					statusScale,
					TweenInfo.new(
						0.22,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{
						Scale = 1,
					}
				):
				Play()

			TweenService:
				Create(
					statusStroke,
					TweenInfo.new(
						0.22
					),
					{
						Transparency = 0.55,
						Color = C.CreamSoft,
					}
				):
				Play()
		end
	)
end

---------------------------------------------------------------------
-- UPDATE STATUS
---------------------------------------------------------------------

local function refreshStatus(animated)
    -- Location belongs to the interior plaque. Keep this compact card only for an active party.
    status.Visible=not not currentParty
	-----------------------------------------------------------------
	-- NOT IN PARTY
	-----------------------------------------------------------------

	if not currentParty then
		statusTitle.Text =
			"ЛОББИ"

		statusSubtitle.Text =
			"ИГРОКОВ В СЕРВЕРЕ"

		statusCount.Text =
			tostring(
				serverPlayerCount()
			)

		statusAccent.BackgroundColor3 =
			C.Gold

		if animated then
			animateStatusChange()
		end

		return
	end

	-----------------------------------------------------------------
	-- PARTY
	-----------------------------------------------------------------

	local members =
		currentParty.members
		or {}

	local capacity =
		math.clamp(
			tonumber(
				currentParty.capacity
			)
			or 4,
			3,
			4
		)

	statusTitle.Text =
		"СТОЛ"

	statusCount.Text =
		tostring(
			#members
		)
		.. "/"
		.. tostring(
			capacity
		)

	-----------------------------------------------------------------
	-- PRIVATE / PUBLIC
	-----------------------------------------------------------------

	local visibility =
		currentParty.visibility

	local privacyText

	if visibility == "public" then
		privacyText =
			"ОТКРЫТЫЙ"
	else
		privacyText =
			"ПО ПРИГЛАШЕНИЮ"
	end

	-----------------------------------------------------------------
	-- PARTY NAME
	-----------------------------------------------------------------

	local partyName =
		tostring(
			currentParty.name
			or ""
		)

	if partyName ~= "" then
		statusSubtitle.Text =
			privacyText
			.. "  ·  "
			.. string.upper(
				partyName
			)
	else
		statusSubtitle.Text =
			privacyText
	end

	if animated then
		animateStatusChange()
	end
end

---------------------------------------------------------------------
-- PLAYER COUNT
---------------------------------------------------------------------

Players.PlayerAdded:Connect(
	function()
		if not currentParty then
			refreshStatus(false)
		end
	end
)

Players.PlayerRemoving:Connect(
	function()
		task.defer(
			function()
				if not currentParty then
					refreshStatus(false)
				end
			end
		)
	end
)

---------------------------------------------------------------------
-- FIND REAL DAILY BUTTON
---------------------------------------------------------------------

local dailyButton = nil
local dailyScale = nil
local dailyBadgeConnection = nil

local function findDaily()
	for _, object in ipairs(
		playerGui:GetDescendants()
		) do
		if object:IsA("GuiButton")
			and object.Name
			== "DailyDock"
		then
			return object
		end
	end

	return nil
end

---------------------------------------------------------------------
-- DAILY ACTION TEXT
---------------------------------------------------------------------

local function updateDailyAction()
	if not dailyButton then
		return
	end

	local action =
		dailyButton:
		FindFirstChild(
			"SpyDailyAction"
		)

	if not action then
		return
	end

	local badge =
		dailyButton:
		FindFirstChild(
			"NotificationBadge"
		)

	if badge
		and badge:IsA("GuiObject")
		and badge.Visible
	then
		action.Text =
			"ГОТОВО"

		action.TextColor3 =
			C.Gold
	else
		action.Text =
			"ОТКРЫТЬ"

		action.TextColor3 =
			C.CreamSoft
	end
end

---------------------------------------------------------------------
-- STYLE DAILY
---------------------------------------------------------------------

local function styleDaily(button)
	if dailyButton == button then
		return
	end

	dailyButton = button

	button.Parent =
		dailyHost

	button.AnchorPoint =
		Vector2.new(
			0,
			0
		)

	button.Position =
		UDim2.fromOffset(
			0,
			0
		)

	button.Size =
		UDim2.fromOffset(
			244,
			66
		)

	button.BackgroundColor3 =
		C.Panel

	button.BackgroundTransparency =
		0.02

	button.BorderSizePixel = 0
	button.AutoButtonColor = false

	button.Visible = true

	button.ZIndex = 42

	getCorner(
		button,
		9
	)

	getStroke(
		button,
		C.Cream,
		0.27,
		1.05
	)

	-----------------------------------------------------------------
	-- HIDE ORIGINAL ACTIVE MARK
	-----------------------------------------------------------------

	local activeMark =
		button:FindFirstChild(
			"ActiveMark"
		)

	if activeMark
		and activeMark:IsA("GuiObject")
	then
		activeMark.Visible = false
	end

	-----------------------------------------------------------------
	-- HIDE ORIGINAL CAPTION
	-----------------------------------------------------------------

	local caption =
		button:FindFirstChild(
			"DockCaption"
		)

	if caption
		and caption:IsA("GuiObject")
	then
		caption.Visible = false
	end

	-----------------------------------------------------------------
	-- ICON
	-----------------------------------------------------------------

	local icon =
		button:FindFirstChild(
			"ObjectIcon"
		)

	if icon
		and icon:IsA("GuiObject")
	then
		icon.AnchorPoint =
			Vector2.new(
				0,
				0.5
			)

		icon.Position =
			UDim2.new(
				0,
				7,
				0.5,
				0
			)

		icon.Size =
			UDim2.fromOffset(
				53,
				53
			)

		icon.ZIndex = 44
	end

	-----------------------------------------------------------------
	-- DIVIDER
	-----------------------------------------------------------------

	local divider =
		button:FindFirstChild(
			"SpyDailyDivider"
		)

	if not divider then
		divider = Instance.new("Frame")
		divider.Name = "SpyDailyDivider"
		divider.Parent = button
	end

	divider.Position =
		UDim2.fromOffset(
			68,
			14
		)

	divider.Size =
		UDim2.fromOffset(
			1,
			38
		)

	divider.BackgroundColor3 =
		C.CreamSoft

	divider.BackgroundTransparency =
		0.67

	divider.BorderSizePixel = 0

	divider.ZIndex = 44

	-----------------------------------------------------------------
	-- TITLE
	-----------------------------------------------------------------

	local title =
		button:FindFirstChild(
			"SpyDailyTitle"
		)

	if not title then
		title =
			textLabel(
				button,
				"SpyDailyTitle",
				"ЕЖЕДНЕВНАЯ НАГРАДА",
				UDim2.fromOffset(
					82,
					8
				),
				UDim2.new(
					1,
					-110,
					0,
					24
				),
				Enum.Font.BuilderSansMedium,
				11,
				C.Cream,
				45
			)
	end

	-----------------------------------------------------------------
	-- SUBTITLE
	-----------------------------------------------------------------

	local subtitle =
		button:FindFirstChild(
			"SpyDailySubtitle"
		)

	if not subtitle then
		subtitle =
			textLabel(
				button,
				"SpyDailySubtitle",
				"БОНУС ЗА ВХОД",
				UDim2.fromOffset(
					82,
					31
				),
				UDim2.new(
					1,
					-110,
					0,
					18
				),
				Enum.Font.BuilderSans,
				8,
				C.Muted,
				45
			)
	end

	-----------------------------------------------------------------
	-- ACTION
	-----------------------------------------------------------------

	local action =
		button:FindFirstChild(
			"SpyDailyAction"
		)

	if not action then
		action =
			textLabel(
				button,
				"SpyDailyAction",
				"ОТКРЫТЬ",
				UDim2.new(
					1,
					-67,
					0,
					0
				),
				UDim2.fromOffset(
					54,
					66
				),
				Enum.Font.BuilderSansMedium,
				7,
				C.CreamSoft,
				45
			)

		action.TextXAlignment =
			Enum.TextXAlignment.Right
	end

	-----------------------------------------------------------------
	-- BADGE
	-----------------------------------------------------------------

	local badge =
		button:FindFirstChild(
			"NotificationBadge"
		)

	if badge
		and badge:IsA("GuiObject")
	then
		badge.Position =
			UDim2.new(
				1,
				-13,
				0,
				13
			)

		badge.Size =
			UDim2.fromOffset(
				7,
				7
			)

		badge.ZIndex = 50

		if dailyBadgeConnection then
			dailyBadgeConnection:
				Disconnect()
		end

		dailyBadgeConnection =
			badge:
			GetPropertyChangedSignal(
				"Visible"
			):
			Connect(
				updateDailyAction
			)
	end

	-----------------------------------------------------------------
	-- PRESS SCALE
	-----------------------------------------------------------------

	dailyScale =
		button:FindFirstChild(
			"SpyDailyScale"
		)

	if not dailyScale then
		dailyScale =
			Instance.new("UIScale")

		dailyScale.Name =
			"SpyDailyScale"

		dailyScale.Scale = 1

		dailyScale.Parent =
			button
	end

	button.MouseButton1Down:
		Connect(
			function()
				TweenService:
				Create(
					dailyScale,
					TweenInfo.new(
						0.06,
						Enum.EasingStyle.Quint,
						Enum.EasingDirection.Out
					),
					{
						Scale = 0.975,
					}
				):
				Play()
			end
		)

	button.MouseButton1Up:
		Connect(
			function()
				TweenService:
				Create(
					dailyScale,
					TweenInfo.new(
						0.16,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{
						Scale = 1,
					}
				):
				Play()
			end
		)

	updateDailyAction()
end

---------------------------------------------------------------------
-- DAILY BIND
---------------------------------------------------------------------

local function tryBindDaily()
	if dailyButton
		and dailyButton.Parent
	then
		return
	end

	local button =
		findDaily()

	if button then
		styleDaily(
			button
		)
	end
end

task.defer(tryBindDaily)
task.delay(0.4, tryBindDaily)
task.delay(1, tryBindDaily)
task.delay(2, tryBindDaily)
task.delay(4, tryBindDaily)

playerGui.DescendantAdded:
	Connect(
		function(object)
			if object:IsA("GuiButton")
				and object.Name
				== "DailyDock"
			then
				task.defer(
					function()
						styleDaily(
							object
						)
					end
				)
			end
		end
	)

---------------------------------------------------------------------
-- PARTY REMOTES
---------------------------------------------------------------------

task.spawn(
	function()
		local folder =
			ReplicatedStorage:
			WaitForChild(
				"SpyPartyRemotes",
				20
			)

		if not folder then
			return
		end

		local request =
			folder:FindFirstChild(
				"Request"
			)

		local update =
			folder:FindFirstChild(
				"Update"
			)

		-----------------------------------------------------------------
		-- INITIAL PARTY
		-----------------------------------------------------------------

		if request
			and request:IsA(
				"RemoteFunction"
			)
		then
			local ok, response =
				pcall(
					function()
						return
						request:
						InvokeServer(
							"Get"
						)
					end
				)

			if ok
				and type(response)
				== "table"
			then
				currentParty =
					response.party

				refreshStatus(false)
			end
		end

		-----------------------------------------------------------------
		-- LIVE PARTY STATE
		-----------------------------------------------------------------

		if update
			and update:IsA(
				"RemoteEvent"
			)
		then
			update.OnClientEvent:
				Connect(
					function(party)
						currentParty =
						party

						refreshStatus(true)
					end
				)
		end
	end
)

---------------------------------------------------------------------
-- RESPONSIVE
---------------------------------------------------------------------

local camera =
	workspace.CurrentCamera

local function updateResponsive()
	if not camera then
		return
	end

	local viewport =
		camera.ViewportSize

	-----------------------------------------------------------------
	-- NARROW
	-----------------------------------------------------------------

	if viewport.X < 1100 then
		rail.Position =
			UDim2.new(
				0,
				18,
				0.5,
				0
			)

		rail.Size =
			UDim2.fromOffset(
				220,
				120
			)

		dailyHost.Size =
			UDim2.fromOffset(
				216,
				62
			)

		dailyShadow.Size =
			UDim2.fromOffset(
				216,
				62
			)

		status.Size =
			UDim2.fromOffset(
				216,
				46
			)

		status.Position =
			UDim2.fromOffset(
				0,
				73
			)

		if dailyButton then
			dailyButton.Size =
				UDim2.fromOffset(
					216,
					62
				)
		end

		-----------------------------------------------------------------
		-- NORMAL
		-----------------------------------------------------------------

	else
		rail.Position =
			UDim2.new(
				0,
				28,
				0.5,
				0
			)

		rail.Size =
			UDim2.fromOffset(
				248,
				128
			)

		dailyHost.Size =
			UDim2.fromOffset(
				244,
				66
			)

		dailyShadow.Size =
			UDim2.fromOffset(
				244,
				66
			)

		status.Size =
			UDim2.fromOffset(
				244,
				50
			)

		status.Position =
			UDim2.fromOffset(
				0,
				78
			)

		if dailyButton then
			dailyButton.Size =
				UDim2.fromOffset(
					244,
					66
				)
		end
	end
end

updateResponsive()

if camera then
	camera:
		GetPropertyChangedSignal(
			"ViewportSize"
		):
		Connect(
			updateResponsive
		)
end

---------------------------------------------------------------------
-- INITIAL STATUS
---------------------------------------------------------------------

refreshStatus(false)

---------------------------------------------------------------------
-- ENTRANCE
---------------------------------------------------------------------

local finalPosition =
	rail.Position

rail.Position =
	finalPosition
- UDim2.fromOffset(
	14,
	0
)

TweenService:
	Create(
		rail,
		TweenInfo.new(
			0.35,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),
		{
			Position =
			finalPosition,
		}
	):
	Play()

---------------------------------------------------------------------
-- PLAYER DIRECTORY / CUSTOM TAB
---------------------------------------------------------------------

local function disableDefaultPlayerList()
	pcall(
		function()
			StarterGui:SetCoreGuiEnabled(
				Enum.CoreGuiType.PlayerList,
				false
			)
		end
	)
end

disableDefaultPlayerList()
task.defer(disableDefaultPlayerList)

local englishDirectory = false -- Ранги и титулы в лобби всегда на русском

local directoryRanks = {
	{ "ГОСТЬ", "GUEST" },
	{ "ЗНАКОМЫЙ", "KNOWN" },
	{ "ЧЛЕН КЛУБА", "MEMBER" },
	{ "ДОВЕРЕННЫЙ", "CONFIDANT" },
	{ "ИНСАЙДЕР", "INSIDER" },
	{ "АГЕНТ", "AGENT" },
	{ "КУРАТОР", "HANDLER" },
	{ "РЕЗИДЕНТ", "RESIDENT" },
	{ "СОВЕТНИК", "ADVISOR" },
	{ "ДИРЕКТОР", "DIRECTOR" },
}

local function directoryRank(index)
	index = math.clamp(
		math.floor(
			tonumber(index) or 1
		),
		1,
		#directoryRanks
	)

	return directoryRanks[index][englishDirectory and 2 or 1]
end

local function groupedNumber(value)
	local digits = tostring(
		math.max(
			0,
			math.floor(
				tonumber(value) or 0
			)
		)
	)

	local grouped

	repeat
		digits, grouped =
			digits:gsub(
				"^(-?%d+)(%d%d%d)",
				"%1 %2"
			)
	until grouped == 0

	return digits
end

local directoryGui = create(
	"ScreenGui",
	playerGui,
	{
		Name = "SpyPlayerDirectory",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 920,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}
)

local backdrop = create(
	"Frame",
	directoryGui,
	{
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(5, 4, 5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}
)

local shadow = create(
	"Frame",
	backdrop,
	{
		Name = "PanelShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 7, 0.5, 12),
		Size = UDim2.new(1, -48, 1, -100),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.34,
		BorderSizePixel = 0,
		ZIndex = 2,
	}
)
getCorner(shadow, 14)
create(
	"UISizeConstraint",
	shadow,
	{
		MinSize = Vector2.new(280, 280),
		MaxSize = Vector2.new(900, 620),
	}
)

local directoryPanel = create(
	"CanvasGroup",
	backdrop,
	{
		Name = "DirectoryPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -48, 1, -100),
		BackgroundColor3 = Color3.fromRGB(20, 17, 17),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 3,
	}
)
getCorner(directoryPanel, 14)
getStroke(directoryPanel, Color3.fromRGB(119, 85, 50), 0.28, 1)
create(
	"UISizeConstraint",
	directoryPanel,
	{
		MinSize = Vector2.new(280, 280),
		MaxSize = Vector2.new(900, 620),
	}
)

local topRule = create(
	"Frame",
	directoryPanel,
	{
		Name = "TopRule",
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		ZIndex = 5,
	}
)
create(
	"UIGradient",
	topRule,
	{
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(89, 60, 35)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(227, 177, 104)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 60, 35)),
		}),
	}
)

local eyebrow = textLabel(
	directoryPanel,
	"Eyebrow",
	"ВНУТРЕННИЙ РЕЕСТР",
	UDim2.fromOffset(28, 22),
	UDim2.new(1, -100, 0, 18),
	Enum.Font.BuilderSansMedium,
	10,
	C.Gold,
	5
)
eyebrow.TextXAlignment = Enum.TextXAlignment.Left

local directoryTitle = textLabel(
	directoryPanel,
	"Title",
	"СОСТАВ КЛУБА",
	UDim2.fromOffset(28, 40),
	UDim2.new(1, -100, 0, 38),
	Enum.Font.BuilderSansMedium,
	26,
	C.Text,
	5
)
directoryTitle.TextXAlignment = Enum.TextXAlignment.Left

local closeDirectory = create(
	"TextButton",
	directoryPanel,
	{
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 22),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = Color3.fromRGB(45, 35, 33),
		Text = "×",
		TextColor3 = C.Cream,
		TextSize = 21,
		Font = Enum.Font.BuilderSansMedium,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 7,
	}
)
getCorner(closeDirectory, 9)
getStroke(closeDirectory, C.Gold, 0.55, 1)

local columnHeader = create(
	"Frame",
	directoryPanel,
	{
		Name = "Columns",
		Position = UDim2.fromOffset(24, 92),
		Size = UDim2.new(1, -48, 0, 32),
		BackgroundColor3 = Color3.fromRGB(27, 22, 21),
		BorderSizePixel = 0,
		ZIndex = 4,
	}
)
getCorner(columnHeader, 7)

local function column(text, position, size, alignment)
	local result = textLabel(
		columnHeader,
		text,
		text,
		position,
		size,
		Enum.Font.BuilderSansMedium,
		9,
		C.Muted,
		5
	)
	result.TextXAlignment = alignment or Enum.TextXAlignment.Left
	return result
end

column("АГЕНТ", UDim2.fromScale(0.02, 0), UDim2.fromScale(0.45, 1))
column("СТАТУС", UDim2.fromScale(0.48, 0), UDim2.fromScale(0.22, 1))
column("УР.", UDim2.fromScale(0.71, 0), UDim2.fromScale(0.1, 1), Enum.TextXAlignment.Center)
column("БАЛАНС", UDim2.fromScale(0.82, 0), UDim2.fromScale(0.16, 1), Enum.TextXAlignment.Right)

local playerList = create(
	"ScrollingFrame",
	directoryPanel,
	{
		Name = "PlayerList",
		Position = UDim2.fromOffset(24, 134),
		Size = UDim2.new(1, -48, 1, -180),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Gold,
		ScrollBarImageTransparency = 0.25,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		ZIndex = 4,
	}
)
create(
	"UIListLayout",
	playerList,
	{
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}
)
create(
	"UIPadding",
	playerList,
	{
		PaddingRight = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 3),
	}
)

local footer = textLabel(
	directoryPanel,
	"Footer",
	"TAB  ·  ЗАКРЫТЬ",
	UDim2.new(0, 28, 1, -37),
	UDim2.new(1, -56, 0, 18),
	Enum.Font.BuilderSansMedium,
	9,
	C.Muted,
	5
)
footer.TextXAlignment = Enum.TextXAlignment.Right

local function resolvedTitle(targetPlayer)
	local titleId=targetPlayer:GetAttribute("SpyTitle")
	local item=type(titleId)=="string" and Catalog.ById[titleId] or nil
	if not item or item.kind~="title" then return "",C.Muted end
	local rgb=item.titleColor or item.color or {194,158,119}
	return englishDirectory and (item.en or item.ru) or item.ru,Color3.fromRGB(rgb[1],rgb[2],rgb[3])
end

-- inner_circle_frame receives the strongest gold lobby-card treatment.
local function resolvedFrameStyle(targetPlayer)
	local frameId=targetPlayer:GetAttribute("SpyFrame")
	local effectId=targetPlayer:GetAttribute("SpyEffect")
	local item=type(frameId)=="string" and Catalog.ById[frameId] or nil
	local effectItem=type(effectId)=="string" and Catalog.ById[effectId] or nil
	local source=item or effectItem
	local rgb=source and source.color or {194,158,119}
	local special=frameId=="inner_circle_frame"
	return Color3.fromRGB(rgb[1],rgb[2],rgb[3]), special and 2.4 or (item and 1.7 or 1), special and 0.02 or (item and 0.22 or 0.58)
end

local directoryRows = {}
local directoryConnections = {}
local overheadConnections = {}

local function refreshDirectoryOrder()
	local sorted = Players:GetPlayers()

	table.sort(
		sorted,
		function(a, b)
			local creatorA = a:GetAttribute("SpyStaffRole") == "creator"
			local creatorB = b:GetAttribute("SpyStaffRole") == "creator"
			if creatorA ~= creatorB then return creatorA end
			local levelA = tonumber(a:GetAttribute("SpyLevel")) or 1
			local levelB = tonumber(b:GetAttribute("SpyLevel")) or 1
			if levelA ~= levelB then return levelA > levelB end
			return string.lower(a.DisplayName) < string.lower(b.DisplayName)
		end
	)

	for order, targetPlayer in ipairs(sorted) do
		local record = directoryRows[targetPlayer]
		if record then record.Frame.LayoutOrder = order end
	end
end

local function updateDirectoryRow(targetPlayer)
	local record = directoryRows[targetPlayer]
	if not record then return end

	local level = math.max(
		1,
		math.floor(
			tonumber(targetPlayer:GetAttribute("SpyLevel")) or 1
		)
	)
	local coins = targetPlayer:GetAttribute("SpyCoins") or 0
	local rankIndex = targetPlayer:GetAttribute("SpyRankIndex") or 1

	record.Display.Text = targetPlayer.DisplayName
	record.Username.Text = "@" .. targetPlayer.Name
	local badge=record.Frame:FindFirstChild("CreatorBadge",true); if badge then badge.Visible=targetPlayer:GetAttribute("SpyStaffRole")=="creator" end
	record.Rank.Text = directoryRank(rankIndex)
	local titleText,titleColor=resolvedTitle(targetPlayer)
	record.Title.Text=titleText;record.Title.TextColor3=titleColor;record.Title.Visible=titleText~=""
	local frameColor,frameThickness,frameTransparency=resolvedFrameStyle(targetPlayer)
	if record.Stroke then
		if targetPlayer:GetAttribute("SpyStaffRole") == "creator" then record.Stroke.Color=C.Gold;record.Stroke.Thickness=2.2;record.Stroke.Transparency=0.08
		else record.Stroke.Color=frameColor;record.Stroke.Thickness=frameThickness;record.Stroke.Transparency=frameTransparency end
	end
	record.Level.Text = tostring(level)
	record.Coins.Text = groupedNumber(coins)
	record.Loading.Visible = targetPlayer:GetAttribute("SpyProfileReady") ~= true

	refreshDirectoryOrder()
end

local function createDirectoryRow(targetPlayer)
	if directoryRows[targetPlayer] then return end

	local row = create(
		"Frame",
		playerList,
		{
			Name = "Player_" .. tostring(targetPlayer.UserId),
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = targetPlayer == player
				and Color3.fromRGB(48, 35, 29)
				or Color3.fromRGB(29, 24, 23),
			BackgroundTransparency = targetPlayer == player and 0.08 or 0.18,
			BorderSizePixel = 0,
			ZIndex = 5,
		}
	)
	getCorner(row, 9)
	local rowStroke = getStroke(
		row,
		targetPlayer == player and C.Gold or Color3.fromRGB(86, 65, 48),
		targetPlayer == player and 0.18 or 0.68,
		1
	)

	local avatarFrame = create(
		"Frame",
		row,
		{
			Name = "AvatarFrame",
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = Color3.fromRGB(16, 14, 14),
			BorderSizePixel = 0,
			ZIndex = 6,
		}
	)
	getCorner(avatarFrame, 8)

	local monogram = textLabel(
		avatarFrame,
		"Monogram",
		"◆",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		Enum.Font.BuilderSansMedium,
		18,
		C.Gold,
		6
	)
	local avatar = create(
		"ImageLabel",
		avatarFrame,
		{
			Name = "Avatar",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = "",
			ZIndex = 7,
		}
	)
	getCorner(avatar, 8)

	local agent = create(
		"Frame",
		row,
		{
			Name = "Agent",
			Position = UDim2.new(0, 68, 0, 7),
			Size = UDim2.new(0.39, -70, 1, -14),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}
	)
	local display = textLabel(
		agent,
		"Display",
		targetPlayer.DisplayName,
		UDim2.fromScale(0, 0),
		UDim2.new(1, 0, 0.56, 0),
		Enum.Font.BuilderSansMedium,
		14,
		C.Text,
		6
	)
	display.TextXAlignment = Enum.TextXAlignment.Left
	display.TextTruncate = Enum.TextTruncate.AtEnd
	local username = textLabel(
		agent,
		"Username",
		"@" .. targetPlayer.Name,
		UDim2.new(0, 0, 0.54, 0),
		UDim2.new(1, 0, 0.4, 0),
		Enum.Font.BuilderSans,
		9,
		C.Muted,
		6
	)
	username.TextXAlignment = Enum.TextXAlignment.Left
	username.TextTruncate = Enum.TextTruncate.AtEnd
	local creatorBadge = textLabel(agent,"CreatorBadge","◆ СОЗДАТЕЛЬ",UDim2.new(0.54,0,0,0),UDim2.new(0.46,0,0.5,0),Enum.Font.BuilderSansMedium,8,C.Gold,8)
	creatorBadge.TextXAlignment=Enum.TextXAlignment.Right
	creatorBadge.Visible=targetPlayer:GetAttribute("SpyStaffRole")=="creator"

	local rank = textLabel(
		row,"Rank","ГОСТЬ",UDim2.new(0.48,0,0,8),UDim2.new(0.22,-5,0,22),
		Enum.Font.BuilderSansMedium,10,C.CreamSoft,6
	)
	rank.TextXAlignment=Enum.TextXAlignment.Left;rank.TextTruncate=Enum.TextTruncate.AtEnd
	local title = textLabel(
		row,"Title","",UDim2.new(0.48,0,0,31),UDim2.new(0.22,-5,0,20),
		Enum.Font.BuilderSansMedium,9,C.Muted,6
	)
	title.TextXAlignment=Enum.TextXAlignment.Left;title.TextTruncate=Enum.TextTruncate.AtEnd

	local level = textLabel(
		row,
		"Level",
		"1",
		UDim2.new(0.71, 0, 0, 0),
		UDim2.new(0.1, 0, 1, 0),
		Enum.Font.BuilderSansMedium,
		15,
		C.Cream,
		6
	)

	local coins = textLabel(
		row,
		"Coins",
		"0",
		UDim2.new(0.82, 0, 0, 0),
		UDim2.new(0.16, -12, 1, 0),
		Enum.Font.BuilderSansMedium,
		12,
		C.Cream,
		6
	)
	coins.TextXAlignment = Enum.TextXAlignment.Right
	local tradeButton
	if targetPlayer ~= player then
		coins.Position = UDim2.new(0.82, 0, 0, 6)
		coins.Size = UDim2.new(0.16, -12, 0, 22)
		tradeButton = create("TextButton", row, {
			Name = "OpenDirectoryTrade_" .. tostring(targetPlayer.UserId),
			Text = player:GetAttribute("SpyLanguage") == "en" and "TRADE" or "ОБМЕН",
			Position = UDim2.new(1, -102, 0, 35),
			Size = UDim2.fromOffset(88, 24),
			BackgroundColor3 = Color3.fromRGB(51, 39, 29),
			TextColor3 = C.Gold, Font = Enum.Font.BuilderSansMedium, TextSize = 10,
			BorderSizePixel = 0, AutoButtonColor = true, ZIndex = 8,
		})
		getCorner(tradeButton, 6)
		getStroke(tradeButton, C.Gold, 0.6, 1)
		tradeButton.Activated:Connect(function()
			if not targetPlayer.Parent then return end
			local opener = playerGui:FindFirstChild("SpyOpenTrade")
			if not opener then opener = create("BindableEvent", playerGui, {Name = "SpyOpenTrade"}) end
			if opener:IsA("BindableEvent") then opener:Fire(targetPlayer.UserId) end
		end)
	end

	local loading = create(
		"Frame",
		row,
		{
			Name = "Loading",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(3, 26),
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 7,
		}
	)
	getCorner(loading, 2)

	directoryRows[targetPlayer] = {
		Frame = row,
		Stroke = rowStroke,
		Display = display,
		Username = username,
		Rank = rank,
		Title = title,
		Level = level,
		Coins = coins,
		Loading = loading,
		Trade = tradeButton,
	}

	task.spawn(
		function()
			local ok, image = pcall(
				function()
					return Players:GetUserThumbnailAsync(
						targetPlayer.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
				end
			)
			if ok and row.Parent and image ~= "" then
				avatar.Image = image
				monogram.Visible = false
			end
		end
	)

	updateDirectoryRow(targetPlayer)
end

player:GetAttributeChangedSignal("SpyLanguage"):Connect(function()
	for _, record in pairs(directoryRows) do
		if record.Trade then
			record.Trade.Text = player:GetAttribute("SpyLanguage") == "en" and "TRADE" or "ОБМЕН"
		end
	end
end)

---------------------------------------------------------------------
-- OVERHEAD RANK TAGS
---------------------------------------------------------------------

local function updateOverhead(targetPlayer)
	local character=targetPlayer.Character
	local head=character and character:FindFirstChild("Head")
	local tag=head and head:FindFirstChild("SpyRankTag")
	local body=tag and tag:FindFirstChild("Body")
	if not body then return end
	local name=body:FindFirstChild("DisplayName")
	local title=body:FindFirstChild("Title")
	local rank=body:FindFirstChild("Rank")
	local mark=body:FindFirstChild("BlackTieMark")
	local level=math.max(1,math.floor(tonumber(targetPlayer:GetAttribute("SpyLevel")) or 1))
	local titleText,titleColor=resolvedTitle(targetPlayer)
	if name then name.Text=targetPlayer.DisplayName end
	if title then title.Text=titleText;title.TextColor3=titleColor;title.Visible=titleText~="" end
	local frameColor,frameThickness,frameTransparency=resolvedFrameStyle(targetPlayer)
	local bodyStroke=body:FindFirstChildOfClass("UIStroke")
	if bodyStroke then bodyStroke.Color=frameColor;bodyStroke.Thickness=frameThickness;bodyStroke.Transparency=frameTransparency end
	if rank then rank.Text=directoryRank(targetPlayer:GetAttribute("SpyRankIndex")).."  ·  УР. "..tostring(level) end
	local equippedOutfit=targetPlayer:GetAttribute("SpyEquippedOutfit")
	if mark then mark.Visible=equippedOutfit == "founder_suit"and tag:GetAttribute("SpyMobileTag")~=true end
end

local function createOverhead(targetPlayer,character)
	local head=character:WaitForChild("Head",8)
	local humanoid=character:FindFirstChildOfClass("Humanoid")
	if not head or targetPlayer.Character~=character then return end
	if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
	local old=head:FindFirstChild("SpyRankTag");if old then old:Destroy() end
	if targetPlayer==player then return end
	local touch=game:GetService("UserInputService").TouchEnabled
	local tag=Instance.new("BillboardGui")
	tag:SetAttribute("SpyMobileTag",touch)
	tag.Name="SpyRankTag";tag.Adornee=head;tag.Size=UDim2.fromOffset(touch and 178 or 244,touch and 62 or 72)
	tag.StudsOffsetWorldSpace=Vector3.new(0,2.62,0);tag.AlwaysOnTop=false;tag.MaxDistance=42;tag.LightInfluence=.28;tag.Parent=head
	local body=create("Frame",tag,{Name="Body",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,0),Size=UDim2.fromOffset(touch and 178 or 244,touch and 58 or 66),BackgroundColor3=Color3.fromRGB(16,13,14),BackgroundTransparency=.2,BorderSizePixel=0})
	getCorner(body,8);getStroke(body,C.Gold,.55,1)
	local name=textLabel(body,"DisplayName",targetPlayer.DisplayName,UDim2.fromOffset(12,5),UDim2.new(1,touch and -24 or -112,0,22),Enum.Font.BuilderSansMedium,touch and 13 or 14,C.Text,2)
	name.TextXAlignment=Enum.TextXAlignment.Left;name.TextTruncate=Enum.TextTruncate.AtEnd
	local mark=textLabel(body,"BlackTieMark","◆  BLACK TIE",UDim2.new(1,-100,0,6),UDim2.fromOffset(88,18),Enum.Font.BuilderSansMedium,8,C.Gold,2)
	mark.TextXAlignment=Enum.TextXAlignment.Right
	local title=textLabel(body,"Title","",UDim2.fromOffset(12,26),UDim2.new(1,-24,0,17),Enum.Font.BuilderSansMedium,9,C.Muted,2)
	title.TextXAlignment=Enum.TextXAlignment.Left;title.TextTruncate=Enum.TextTruncate.AtEnd
	local rank=textLabel(body,"Rank","",UDim2.fromOffset(12,touch and 40 or 44),UDim2.new(1,-24,0,16),Enum.Font.BuilderSansMedium,9,C.CreamSoft,2)
	rank.TextXAlignment=Enum.TextXAlignment.Left;rank.TextTruncate=Enum.TextTruncate.AtEnd
	updateOverhead(targetPlayer)
	if mark.Visible then
		local sweep=create("UIGradient",mark,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(150,104,57)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,231,177)),ColorSequenceKeypoint.new(1,Color3.fromRGB(181,133,78))}),Offset=Vector2.new(-1,0)})
		TweenService:Create(sweep,TweenInfo.new(.65,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Offset=Vector2.new(1,0)}):Play()
	end
end

local function disconnectDirectoryPlayer(targetPlayer)
	for _, connection in ipairs(directoryConnections[targetPlayer] or {}) do
		connection:Disconnect()
	end
	directoryConnections[targetPlayer] = nil

	for _, connection in ipairs(overheadConnections[targetPlayer] or {}) do
		connection:Disconnect()
	end
	overheadConnections[targetPlayer] = nil

	local record = directoryRows[targetPlayer]
	if record then record.Frame:Destroy() end
	directoryRows[targetPlayer] = nil
end

local function connectDirectoryPlayer(targetPlayer)
	if directoryConnections[targetPlayer] then return end

	createDirectoryRow(targetPlayer)
	directoryConnections[targetPlayer] = {}
	overheadConnections[targetPlayer] = {}

	local overheadReconcileToken = 0
	local function reconcileOverhead()
		overheadReconcileToken += 1
		local token = overheadReconcileToken
		task.spawn(function()
			local character = targetPlayer.Character
			if not character then return end

			-- ApplyDescriptionResetAsync can reconstruct Head without CharacterAdded.
			-- Wait for the replicated replacement before deciding whether the tag exists.
			local head = character:WaitForChild("Head",8)
			if token ~= overheadReconcileToken then return end
			if not head or targetPlayer.Character~=character then return end

			if not head:FindFirstChild("SpyRankTag") then
				createOverhead(targetPlayer,character)
			else
				updateOverhead(targetPlayer)
			end
		end)
	end

	for _, attribute in ipairs({ "SpyProfileReady", "SpyLevel", "SpyCoins", "SpyRankIndex", "SpyTitle", "SpyFrame", "SpyEffect", "SpyLanguage", "SpyEquippedOutfit", "SpyAppearanceRevision", "SpyStaffRole", "SpyIsAdmin" }) do
		table.insert(
			directoryConnections[targetPlayer],
			targetPlayer:GetAttributeChangedSignal(attribute):Connect(
				function()
					updateDirectoryRow(targetPlayer)
					reconcileOverhead()
				end
			)
		)
	end

	table.insert(
		overheadConnections[targetPlayer],
		targetPlayer.CharacterAdded:Connect(function(character) task.spawn(createOverhead,targetPlayer,character) end)
	)
	if targetPlayer.Character then task.spawn(createOverhead,targetPlayer,targetPlayer.Character) end
end

Players.PlayerAdded:Connect(
	function(targetPlayer)
		connectDirectoryPlayer(targetPlayer)
		refreshDirectoryOrder()
	end
)

Players.PlayerRemoving:Connect(
	function(targetPlayer)
		disconnectDirectoryPlayer(targetPlayer)
		refreshDirectoryOrder()
	end
)

for _, targetPlayer in ipairs(Players:GetPlayers()) do
	connectDirectoryPlayer(targetPlayer)
end
refreshDirectoryOrder()

---------------------------------------------------------------------
-- DIRECTORY MOTION / INPUT
---------------------------------------------------------------------

local directoryOpen = false
local directoryMotion = 0

local function setDirectoryOpen(open)
	directoryOpen = open == true
	directoryMotion += 1
	local motion = directoryMotion

	if directoryOpen then
		disableDefaultPlayerList()
		directoryGui.Enabled = true
		backdrop.BackgroundTransparency = 1
		directoryPanel.GroupTransparency = 1
		directoryPanel.Position = UDim2.new(0.5, 0, 0.5, 18)
		shadow.Visible = true

		TweenService:Create(
			backdrop,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.32 }
		):Play()
		TweenService:Create(
			directoryPanel,
			TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				GroupTransparency = 0,
				Position = UDim2.fromScale(0.5, 0.5),
			}
		):Play()
	else
		TweenService:Create(
			backdrop,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		):Play()
		TweenService:Create(
			directoryPanel,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				GroupTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 12),
			}
		):Play()

		task.delay(
			0.2,
			function()
				if motion == directoryMotion and not directoryOpen then
					directoryGui.Enabled = false
				end
			end
		)
	end
end

closeDirectory.Activated:Connect(
	function()
		setDirectoryOpen(false)
	end
)

closeDirectory.MouseEnter:Connect(
	function()
		TweenService:Create(
			closeDirectory,
			TweenInfo.new(0.12),
			{ BackgroundColor3 = Color3.fromRGB(67, 47, 39) }
		):Play()
	end
)

closeDirectory.MouseLeave:Connect(
	function()
		TweenService:Create(
			closeDirectory,
			TweenInfo.new(0.12),
			{ BackgroundColor3 = Color3.fromRGB(45, 35, 33) }
		):Play()
	end
)

local function directoryTabAction(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end

	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end

	setDirectoryOpen(not directoryOpen)
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"SpyClubPlayerDirectory",
	directoryTabAction,
	false,
	Enum.ContextActionPriority.High.Value + 1,
	Enum.KeyCode.Tab
)

UserInputService.InputBegan:Connect(
	function(input)
		if input.KeyCode == Enum.KeyCode.Escape and directoryOpen then
			setDirectoryOpen(false)
		end
	end
)
