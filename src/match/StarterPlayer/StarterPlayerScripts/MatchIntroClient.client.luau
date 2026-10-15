---------------------------------------------------------------------
-- SPY CLUB / CREATOR CONTROL V31.5
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
    local MODE="MATCH"

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
        x.Font=font or Enum.Font.BuilderSansMedium; x.TextSize=size or 13; x.TextXAlignment=Enum.TextXAlignment.Left; x.TextYAlignment=Enum.TextYAlignment.Center; x.Parent=parent; return x
    end
    local drafts={};local draftTarget="server"
    local function textbox(parent,placeholder,height)
        local x=Instance.new("TextBox"); x.Size=UDim2.new(1,0,0,height or 40); x.BackgroundColor3=C.raised; x.BorderSizePixel=0; x.Text=""; x.PlaceholderText=placeholder or ""
        x.PlaceholderColor3=Color3.fromRGB(108,124,138); x.TextColor3=C.text; x.Font=Enum.Font.BuilderSansMedium; x.TextSize=12; x.TextXAlignment=Enum.TextXAlignment.Left
        local key=draftTarget..":"..tostring(placeholder)
        x.Text=drafts[key] or ""
        x:GetPropertyChangedSignal("Text"):Connect(function() drafts[key]=x.Text end)
        x.ClearTextOnFocus=false; x.MultiLine=false; x.Parent=parent; corner(x,8); stroke(x,C.line,.5,1); pad(x,12,12,0,0); return x
    end
    local function button(parent,text,width,danger)
        local x=Instance.new("TextButton"); x.AutoButtonColor=false; x.Active=true; x.Selectable=true; x.Size=UDim2.fromOffset(width or 142,38); x.BackgroundColor3=danger and C.redBg or C.raised2; x.BorderSizePixel=0
        x.Text=text; x.TextColor3=danger and Color3.fromRGB(244,194,181) or C.text; x.Font=Enum.Font.BuilderSansMedium; x.TextSize=12; x.Parent=parent; corner(x,8); stroke(x,danger and C.red or C.line,.42,1)
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
    local bannerTitle=label(banner,"SPY CLUB",11,Enum.Font.BuilderSansBold,C.gold2); bannerTitle.Position=UDim2.fromOffset(30,12); bannerTitle.Size=UDim2.new(1,-48,0,18)
    local bannerText=label(banner,"",15,Enum.Font.BuilderSansMedium,C.text); bannerText.Position=UDim2.fromOffset(30,30); bannerText.Size=UDim2.new(1,-48,0,42); bannerText.TextWrapped=true; bannerText.TextYAlignment=Enum.TextYAlignment.Top
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
    local title=label(header,"ПУЛЬТ СОЗДАТЕЛЯ",17,Enum.Font.BuilderSansBold,C.gold2); title.Position=UDim2.fromOffset(22,12); title.Size=UDim2.fromOffset(280,24)
    local sub=label(header,MODE=="LOBBY" and "лобби" or "матч",10,Enum.Font.BuilderSansMedium,C.muted); sub.Position=UDim2.fromOffset(22,35); sub.Size=UDim2.fromOffset(240,18)
    local connection=label(header,"●  подключение",10,Enum.Font.BuilderSansBold,C.muted); connection.AnchorPoint=Vector2.new(1,.5); connection.Position=UDim2.new(1,-74,.5,0); connection.Size=UDim2.fromOffset(160,24); connection.TextXAlignment=Enum.TextXAlignment.Right
    local close=button(header,"×",42,false); close.AnchorPoint=Vector2.new(1,.5); close.Position=UDim2.new(1,-18,.5,0); close.TextSize=18
    local line=Instance.new("Frame"); line.Position=UDim2.new(0,18,1,-1); line.Size=UDim2.new(1,-36,0,1); line.BackgroundColor3=C.line; line.BackgroundTransparency=.35; line.BorderSizePixel=0; line.Parent=header

    local left=Instance.new("Frame"); left.Position=UDim2.fromOffset(18,78); left.Size=UDim2.fromOffset(276,494); left.BackgroundColor3=C.panel; left.BorderSizePixel=0; left.Parent=shell; corner(left,10); stroke(left,C.line,.48,1)
    local search=textbox(left,"Найти игрока…",38); search.Position=UDim2.fromOffset(12,12); search.Size=UDim2.new(1,-24,0,38)
    local rosterStatus=label(left,"Подключение…",10,Enum.Font.BuilderSansMedium,C.muted); rosterStatus.Position=UDim2.fromOffset(12,54); rosterStatus.Size=UDim2.new(1,-24,0,18)
    local list=Instance.new("ScrollingFrame"); list.Position=UDim2.fromOffset(8,78); list.Size=UDim2.new(1,-16,1,-86); list.BackgroundTransparency=1; list.BorderSizePixel=0; list.ScrollBarThickness=2; list.ScrollBarImageColor3=C.line; list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.new(); list.Parent=left
    local listLayout=Instance.new("UIListLayout"); listLayout.Padding=UDim.new(0,6); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=list

    local right=Instance.new("Frame"); right.Position=UDim2.fromOffset(308,78); right.Size=UDim2.new(1,-326,1,-96); right.BackgroundTransparency=1; right.Parent=shell
    local identity=Instance.new("Frame"); identity.Size=UDim2.new(1,0,0,88); identity.BackgroundColor3=C.panel; identity.BorderSizePixel=0; identity.Parent=right; corner(identity,10); stroke(identity,C.line,.48,1)
    local avatar=Instance.new("ImageLabel"); avatar.Position=UDim2.fromOffset(12,12); avatar.Size=UDim2.fromOffset(64,64); avatar.BackgroundColor3=C.raised; avatar.BorderSizePixel=0; avatar.Image=""; avatar.Parent=identity; corner(avatar,8)
    local identityName=label(identity,"Выбери игрока",15,Enum.Font.BuilderSansBold,C.text); identityName.Position=UDim2.fromOffset(90,12); identityName.Size=UDim2.new(1,-260,0,22)
    local identityUser=label(identity,"",10,Enum.Font.BuilderSansMedium,C.muted); identityUser.Position=UDim2.fromOffset(90,36); identityUser.Size=UDim2.new(1,-260,0,18)
    local identityStats=label(identity,"",11,Enum.Font.BuilderSansMedium,C.gold2); identityStats.Position=UDim2.fromOffset(90,56); identityStats.Size=UDim2.new(1,-260,0,18)
    local serverText=label(identity,"",10,Enum.Font.BuilderSansMedium,C.muted); serverText.AnchorPoint=Vector2.new(1,0); serverText.Position=UDim2.new(1,-14,0,14); serverText.Size=UDim2.fromOffset(210,56); serverText.TextXAlignment=Enum.TextXAlignment.Right; serverText.TextYAlignment=Enum.TextYAlignment.Top

    local tabs=Instance.new("Frame"); tabs.Position=UDim2.fromOffset(0,100); tabs.Size=UDim2.new(1,0,0,42); tabs.BackgroundTransparency=1; tabs.Parent=right
    local tabLayout=Instance.new("UIListLayout"); tabLayout.FillDirection=Enum.FillDirection.Horizontal; tabLayout.Padding=UDim.new(0,8); tabLayout.VerticalAlignment=Enum.VerticalAlignment.Center; tabLayout.Parent=tabs
    local body=Instance.new("ScrollingFrame"); body.Position=UDim2.fromOffset(0,150); body.Size=UDim2.new(1,0,1,-150); body.BackgroundTransparency=1; body.BorderSizePixel=0; body.ScrollBarThickness=2; body.ScrollBarImageColor3=C.line; body.AutomaticCanvasSize=Enum.AutomaticSize.Y; body.CanvasSize=UDim2.new(); body.Parent=right
    local bodyLayout=Instance.new("UIListLayout"); bodyLayout.Padding=UDim.new(0,10); bodyLayout.SortOrder=Enum.SortOrder.LayoutOrder; bodyLayout.Parent=body

    local modal=Instance.new("Frame"); modal.AnchorPoint=Vector2.new(.5,.5); modal.Position=UDim2.fromScale(.5,.5); modal.Size=UDim2.fromOffset(430,190); modal.BackgroundColor3=C.panel; modal.BorderSizePixel=0; modal.Visible=false; modal.ZIndex=50; modal.Parent=shell; corner(modal,10); stroke(modal,C.gold,.26,1)
    local modalTitle=label(modal,"Подтвердить действие",14,Enum.Font.BuilderSansBold,C.gold2); modalTitle.Position=UDim2.fromOffset(18,16); modalTitle.Size=UDim2.new(1,-36,0,22); modalTitle.ZIndex=51
    local modalText=label(modal,"",12,Enum.Font.BuilderSansMedium,C.text); modalText.Position=UDim2.fromOffset(18,48); modalText.Size=UDim2.new(1,-36,0,76); modalText.TextWrapped=true; modalText.TextYAlignment=Enum.TextYAlignment.Top; modalText.ZIndex=51
    local modalYes=button(modal,"Подтвердить",150,true); modalYes.Position=UDim2.new(1,-318,1,-52); modalYes.ZIndex=51
    local modalNo=button(modal,"Отмена",130,false); modalNo.Position=UDim2.new(1,-152,1,-52); modalNo.ZIndex=51
    local pendingConfirm=nil
    local function confirm(text,fn) pendingConfirm=fn; modalText.Text=text; modal.Visible=true end
    modalNo.Activated:Connect(function() pendingConfirm=nil; modal.Visible=false end)
    modalYes.Activated:Connect(function() local fn=pendingConfirm; pendingConfirm=nil; modal.Visible=false; if fn then fn() end end)

    local toast=label(shell,"",11,Enum.Font.BuilderSansMedium,C.text); toast.AnchorPoint=Vector2.new(.5,1); toast.Position=UDim2.new(.5,0,1,-10); toast.Size=UDim2.fromOffset(420,28); toast.BackgroundColor3=C.raised; toast.BackgroundTransparency=.08; toast.TextXAlignment=Enum.TextXAlignment.Center; toast.Visible=false; toast.ZIndex=45; corner(toast,8); local toastStroke=stroke(toast,C.line,.42,1)
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
                local nm=label(row,tostring(item.displayName or item.username or "Игрок"),12,Enum.Font.BuilderSansMedium,item.staffRole=="creator" and C.gold2 or C.text); nm.Name="ParticipantName";nm:SetAttribute("SpyUserText",true); nm.Position=UDim2.fromOffset(60,8); nm.Size=UDim2.new(1,-68,0,20)
                local st=label(row,"@"..tostring(item.username or "").."   •   ур. "..tostring(item.level or 1).."   •   ◈ "..tostring(item.coins or 0),9,Enum.Font.BuilderSansMedium,C.muted); st.Name="ParticipantUsername";st:SetAttribute("SpyUserText",true); st.Position=UDim2.fromOffset(60,29); st.Size=UDim2.new(1,-68,0,18)
                if item.staffRole=="creator" then local cr=label(row,"СОЗДАТЕЛЬ",8,Enum.Font.BuilderSansBold,C.gold2); cr.AnchorPoint=Vector2.new(1,0); cr.Position=UDim2.new(1,-8,0,7); cr.Size=UDim2.fromOffset(72,14); cr.TextXAlignment=Enum.TextXAlignment.Right end
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
                "\nЭтап отправки: "..tostring(me:GetAttribute("SpyChatLastSendStage") or "—")..
                " | Причина: "..tostring(me:GetAttribute("SpyChatLastSendReason") or "—")..
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
        local a=label(f,text,13,Enum.Font.BuilderSansBold,C.gold2); a.Size=UDim2.new(1,0,0,20)
        local b=label(f,subtext or "",10,Enum.Font.BuilderSansMedium,C.muted); b.Position=UDim2.fromOffset(0,21); b.Size=UDim2.new(1,0,0,18)
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
            local il=label(info,"Онлайн  "..tostring(serverData.playerCount or #roster).."/"..tostring(serverData.maxPlayers or 0).."     •     Время  "..formatUptime(serverData.uptime).."     •     Place  "..tostring(serverData.placeId or game.PlaceId),11,Enum.Font.BuilderSansMedium,C.text); il.Position=UDim2.fromOffset(14,10); il.Size=UDim2.new(1,-28,0,22);serverInfoLabel=il
            local hint=label(info,"Объявление увидит весь текущий сервер и появится в чате.",10,Enum.Font.BuilderSansMedium,C.muted); hint.Position=UDim2.fromOffset(14,36); hint.Size=UDim2.new(1,-28,0,20)
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
    launcher.Name="OpenCreatorControl";launcher.AnchorPoint=Vector2.new(1,1);launcher.Position=UDim2.new(1,-18,1,-66)
    local dockModule=shared:FindFirstChild("MatchHUD")
    local creatorAccess
    if dockModule then
        launcher.Text="Пульт"
        local dock=require(dockModule)
        dock.register(pg,launcher,100,"F2")
        creatorAccess=dock.creatorAccess(pg,openerGui,launcher,function() setOpen(not open)end)
    end
    launcher.Activated:Connect(function() setOpen(not open) end)
    me:GetAttributeChangedSignal("SpyIsAdmin"):Connect(function()
        local allowed=me:GetAttribute("SpyIsAdmin")==true
        if creatorAccess then creatorAccess.refresh()else launcher.Visible=allowed end
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
    print("SPY_CREATOR_CONTROL_READY",MODE,"V31.5",me.Name,me.UserId,RunService:IsStudio())
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

-- StarterPlayer > StarterPlayerScripts > MatchIntroClient
-- SPY CLUB / MATCH CLIENT v18 · TEXTCHANNEL CHAT
-- ПОЛНАЯ ЗАМЕНА

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

-- Draw before waiting on server remotes. A failed server boot must never leave
-- a raw grey character and no explanation. The full arrival UI takes over.
do
	local owner = Players.LocalPlayer
	local holder = owner:WaitForChild("PlayerGui")
	local old = holder:FindFirstChild("SpyMatchConnecting")
	if old then old:Destroy() end
	local screen = Instance.new("ScreenGui")
	screen.Name = "SpyMatchConnecting"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 600
	screen.Parent = holder
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(18, 16, 18)
	background.BorderSizePixel = 0
	background.Parent = screen
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.45)
	title.Size = UDim2.new(1, -40, 0, 54)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansMedium
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(239, 222, 194)
	title.Text = "SPY CLUB"
	title.Parent = background
	local detail = title:Clone()
	detail.Position = UDim2.fromScale(0.5, 0.53)
	detail.TextSize = 16
	detail.TextWrapped = true
	detail.TextColor3 = Color3.fromRGB(181, 161, 140)
	detail.Text = "Собираем стол…"
	detail.Parent = background
	local since = os.clock()
	task.spawn(function()
		while screen.Parent do
			local phase = ReplicatedStorage:GetAttribute("SpyMatchBootError")
			if phase then
				detail.Text = "Не удалось подготовить матч · " .. tostring(phase)
			elseif os.clock() - since > 20 then
				detail.Text = "Подключение занимает больше времени · M22-CONNECT"
			end
			task.wait(0.5)
		end
	end)
end

-- Subscribe before requiring cosmetics or building the interface. Otherwise
-- the server's short Intro phase can end while this LocalScript is still loading.
local function bootMatchClient()
local remotes = ReplicatedStorage:WaitForChild("MatchRemotes")
local stateEvent = remotes:WaitForChild("State")
local cardEvent = remotes:WaitForChild("Card")
local rewardEvent = remotes:WaitForChild("Reward")
local actionEvent = remotes:WaitForChild("Action")
local snapshotFunction = remotes:WaitForChild("Snapshot", 10)
local sessionFolder = ReplicatedStorage:WaitForChild("MatchSession", 10)

local pendingMatchEvents = {}
local stateHandler
local cardHandler
local rewardHandler

stateEvent.OnClientEvent:Connect(function(state)
	if stateHandler then
		stateHandler(state)
	else
		table.insert(pendingMatchEvents, {"state", state})
	end
end)

cardEvent.OnClientEvent:Connect(function(data)
	if cardHandler then
		cardHandler(data)
	else
		table.insert(pendingMatchEvents, {"card", data})
	end
end)

rewardEvent.OnClientEvent:Connect(function(data)
 if rewardHandler then rewardHandler(data) else table.insert(pendingMatchEvents,{"reward",data}) end
end)

local Catalog = require(ReplicatedStorage:WaitForChild("SpyShared"):WaitForChild("Catalog"))
local MatchI18n = require(ReplicatedStorage.SpyShared.I18n)
local MatchHUD = require(ReplicatedStorage.SpyShared.MatchHUD)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

---------------------------------------------------------------------
-- SPY CLUB / MATCH AUDIO
-- Live-bound to the same ClientPreferences module used by the Settings UI.
-- Changing Music or SFX in Settings updates these sounds immediately.
---------------------------------------------------------------------
local ClientPreferences={_signal=Instance.new("BindableEvent"),get=function() return {musicVolume=1,sfxVolume=1} end}
ClientPreferences.Changed=ClientPreferences._signal.Event
task.spawn(function()
 local ok,err=pcall(function()
  local sharedFolder=ReplicatedStorage:WaitForChild("SpyShared",8)
  local module=sharedFolder and sharedFolder:WaitForChild("ClientPreferences",8)
  if not module then error("ClientPreferences unavailable") end
  local value=require(module)
  ClientPreferences.get=value.get
  value.Changed:Connect(function() ClientPreferences._signal:Fire() end)
  value.start()
  ClientPreferences._signal:Fire()
 end)
 if not ok then player:SetAttribute("SpyMatchPreferencesError",tostring(err));warn("SpyClub match preferences: "..tostring(err)) end
end)

local oldAudioRoot = SoundService:FindFirstChild("SPYMatchAudio")
if oldAudioRoot then oldAudioRoot:Destroy() end

local audioRoot = Instance.new("Folder")
audioRoot.Name = "SPYMatchAudio"
audioRoot.Parent = SoundService

local function makeMatchSound(name, assetId, baseVolume, looped, category)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. tostring(assetId)
	sound.Volume = baseVolume
	sound.Looped = looped == true
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound:SetAttribute("SpyAudioCategory", category or "SFX")
	sound.Parent = audioRoot
	return sound
end

-- ClubMusic owns the music bed, including pauses for the introduction.
-- Physical / UI feedback.
local uiClickSound = makeMatchSound("UIClick", 9119144736, 0.22, false, "SFX")
local cardDealSound = makeMatchSound("CardDeal", 9125557143, 0.34, false, "SFX")
local cardWhooshSound = makeMatchSound("CardFlipPaper", 9125654188, 0.24, false, "SFX")
local phaseChimeSound = makeMatchSound("PhaseChime", 9119802009, 0.18, false, "SFX")
local spyRevealSound = makeMatchSound("SpyReveal", 9044827672, 0.12, false, "SFX")
-- Tension only during the voting phase. Marked SFX intentionally so the SFX slider owns it.
local voteTickSound = makeMatchSound("VoteTick", 9043366741, 0.075, true, "SFX")

local matchAudioMix = {
	[uiClickSound] = {base = 0.22, key = "sfxVolume"},
	[cardDealSound] = {base = 0.34, key = "sfxVolume"},
	[cardWhooshSound] = {base = 0.24, key = "sfxVolume"},
	[phaseChimeSound] = {base = 0.18, key = "sfxVolume"},
	[spyRevealSound] = {base = 0.12, key = "sfxVolume"},
	[voteTickSound] = {base = 0.075, key = "sfxVolume"},
}

local function applyMatchAudioPreferences()
	local prefs = ClientPreferences.get()
	for sound, info in pairs(matchAudioMix) do
		if sound and sound.Parent then
			local level = math.clamp(tonumber(prefs[info.key]) or 1, 0, 1)
			local target = info.base * level
			if math.abs(sound.Volume - target) > 0.0005 then
				sound.Volume = target
			end
		end
	end
end

ClientPreferences.Changed:Connect(applyMatchAudioPreferences)
task.defer(applyMatchAudioPreferences)

local function playMatchSound(sound, playbackSpeed)
	if not sound or not sound.Parent then return end
	sound:Stop()
	sound.PlaybackSpeed = playbackSpeed or 1
	sound:Play()
end

local function stopMatchSound(sound)
	if sound and sound.IsPlaying then sound:Stop() end
end

-- Essential match transport is already subscribed above. Handshake now instead
-- of after thousands of lines of cinematic/UI setup, so cosmetics or optional
-- presentation can never deadlock the entire table on the loading screen.
task.spawn(function()
	while script.Parent and player.Parent == Players
		and player:GetAttribute("SpyMatchClientReady") ~= true do
		actionEvent:FireServer("ClientReady", 22)
		task.wait(0.75)
	end
end)

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)

local EXTRA_ROUND_VOTE_VALUE = "__EXTRA_ROUND__"


---------------------------------------------------------------------
-- SPY CLUB / PRIVATE ROOM POST PROCESS
-- The server authors the room and all physical lights. This local pass
-- handles only the subtle grade; it adds no duplicate table lamps.
---------------------------------------------------------------------
local function ensureRoomEffect(className, name)
    local effect = Lighting:FindFirstChild(name)
    if effect and not effect:IsA(className) then
        effect:Destroy()
        effect = nil
    end
    if not effect then
        effect = Instance.new(className)
        effect.Name = name
        effect.Parent = Lighting
    end
    return effect
end

local function applyPrivateRoomGrade()
    for _, name in ipairs({
        "MatchBloom", "MatchGrade", "MatchAtmosphere",
        "MatchVisualV2_Bloom", "MatchVisualV2_Grade",
    }) do
        local old = Lighting:FindFirstChild(name)
        if old then old:Destroy() end
    end

    local bloom = ensureRoomEffect("BloomEffect", "SpyMatchVisual_Bloom")
    bloom.Enabled = true
    bloom.Intensity = 0.065
    bloom.Size = 17
    bloom.Threshold = 2.15

    local grade = ensureRoomEffect("ColorCorrectionEffect", "SpyMatchVisual_Grade")
    grade.Enabled = true
    grade.Brightness = 0.008
    grade.Contrast = 0.035
    grade.Saturation = 0
    grade.TintColor = Color3.fromRGB(255, 255, 255)
end

task.defer(applyPrivateRoomGrade)

-- SPY_MATCH_VISUAL_PASS_V3_END
---------------------------------------------------------------------

---------------------------------------------------------------------
-- SPY_NATIVE_MATCH_CHAT_V315
-- Native Roblox TextChatService window/input; SPY CLUB owns one match channel.
---------------------------------------------------------------------
-- Presentation is owned by independent NativeChatBootstrap.
local MATCH_CHAT_CHANNEL="SpyMatchGlobal"
local function resolveMatchChatChannel()
 local folder=TextChatService:FindFirstChild("TextChannels")
 local channel=folder and folder:FindFirstChild(ReplicatedStorage:GetAttribute("SpyChatChannelName") or MATCH_CHAT_CHANNEL)
 return channel and channel:IsA("TextChannel") and channel or nil
end

local function localMatchTextSource()
    local channel = resolveMatchChatChannel()
    if not channel then return nil end
    for _, child in ipairs(channel:GetChildren()) do
        if child:IsA("TextSource") and (child.UserId == Players.LocalPlayer.UserId or child:GetAttribute("SpyChatUserId") == Players.LocalPlayer.UserId) then return child end
    end
    return nil
end

---------------------------------------------------------------------
-- COLORS
---------------------------------------------------------------------

-- The same graphite / white screens as Character and the club store.
-- Legacy token names stay local to this presentation owner. Suspect/error colors
-- and the physical role-card fallback remain meaningful rather than decorative.
local COLORS = {
 Black=Color3.fromRGB(16,17,19),
 Panel=Color3.fromRGB(28,29,32),Panel2=Color3.fromRGB(36,37,41),Panel3=Color3.fromRGB(46,47,51),
 Wine=Color3.fromRGB(58,32,37),WineSoft=Color3.fromRGB(81,47,48),
 Brass=Color3.fromRGB(238,236,230),BrassDark=Color3.fromRGB(112,114,120),
 Ivory=Color3.fromRGB(246,244,238),IvorySoft=Color3.fromRGB(172,174,181),
 Ink=Color3.fromRGB(26,28,32),Muted=Color3.fromRGB(172,174,181),Danger=Color3.fromRGB(209,108,110),
}
local CARD_ACCENT=Color3.fromRGB(220,221,225)

local matchUI = {}
local MatchPresentation
pcall(function()
    local module=ReplicatedStorage.SpyShared:FindFirstChild("MatchPresentation")
    if module then MatchPresentation=require(module) end
end)

---------------------------------------------------------------------
-- PROFILE COSMETIC PRESENTATION
---------------------------------------------------------------------

local function catalogColor(item, fallback)
	if item and type(item.color) == "table" and #item.color >= 3 then
		return Color3.fromRGB(item.color[1], item.color[2], item.color[3])
	end
	return fallback
end

local function catalogDark(item, fallback)
	if item and type(item.dark) == "table" and #item.dark >= 3 then
		return Color3.fromRGB(item.dark[1], item.dark[2], item.dark[3])
	end
	return fallback
end

local function equippedCardFor(targetPlayer)
	local id = targetPlayer and targetPlayer:GetAttribute("SpyEquippedCard") or "classic"
	return Catalog.ById[tostring(id)] or Catalog.ById.classic
end

local function resolvedMatchTitle(targetPlayer)
	local id = targetPlayer and targetPlayer:GetAttribute("SpyTitle")
	local item = type(id) == "string" and Catalog.ById[id] or nil
	if not item or item.kind ~= "title" then
		return "", COLORS.Muted
	end
	return item.ru or item.en or "", catalogColor(item, COLORS.Brass)
end

local function resolvedMatchFrameStyle(targetPlayer)
	local frameId = targetPlayer and targetPlayer:GetAttribute("SpyFrame")
	local effectId = targetPlayer and targetPlayer:GetAttribute("SpyEffect")
	local frameItem = type(frameId) == "string" and Catalog.ById[frameId] or nil
	local effectItem = type(effectId) == "string" and Catalog.ById[effectId] or nil
	local source = frameItem or effectItem
	local color = catalogColor(source, COLORS.Brass)
	local special = frameId == "inner_circle_frame"
	return color, special and 2.2 or (frameItem and 1.6 or 1), special and 0.04 or (frameItem and 0.24 or 0.52)
end

local identityConnections = {}

local function clearIdentityConnections(targetPlayer)
	for _, connection in ipairs(identityConnections[targetPlayer] or {}) do
		connection:Disconnect()
	end
	identityConnections[targetPlayer] = nil
end

local function createMatchIdentityTag(targetPlayer, character)
	local head = character and character:WaitForChild("Head", 8)
	if not head or targetPlayer.Character ~= character then
		return
	end

	local old = head:FindFirstChild("SpyMatchIdentityTag")
	if old then old:Destroy() end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "SpyMatchIdentityTag"
	tag.Adornee = head
	tag.Size = UDim2.fromOffset(148, 24)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0)
	tag.AlwaysOnTop = false
	tag.MaxDistance = 26
	tag.Enabled = targetPlayer ~= player
	tag.LightInfluence = 0.24
	tag.Parent = head

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = Color3.fromRGB(16, 13, 14)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = tag

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = body

	local outline = Instance.new("UIStroke")
	outline.Name = "IdentityStroke"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = body

	local display = Instance.new("TextLabel")
	display.Name = "DisplayName"
	display.BackgroundTransparency = 1
	display.Position = UDim2.fromOffset(4, 0)
	display.Size = UDim2.new(1, -8, 1, 0)
	display.Font = Enum.Font.BuilderSansBold
	display.TextSize = 14
	display.TextColor3 = COLORS.Ivory
	display.TextXAlignment = Enum.TextXAlignment.Center
	display.TextTruncate = Enum.TextTruncate.AtEnd
	display.Parent = body

	local title = display:Clone()
	title.Name = "Title"
	title.Position = UDim2.fromOffset(8, 21)
	title.Size = UDim2.new(1, -20, 0, 15)
	title.Font = Enum.Font.BuilderSansMedium
	title.TextSize = 10
	title.Parent = body

	local rank = display:Clone()
	rank.Name = "Rank"
	rank.Position = UDim2.fromOffset(8, 22)
	rank.Size = UDim2.new(1, -20, 0, 13)
	rank.Font = Enum.Font.BuilderSansMedium
	rank.TextSize = 10
	rank.TextColor3 = COLORS.IvorySoft
	rank.Parent = body

	local function refresh()
		if not tag.Parent then return end
		display.Text = targetPlayer.DisplayName
		local titleText, titleColor = resolvedMatchTitle(targetPlayer)
        local speaking=sessionFolder and sessionFolder:GetAttribute("RoundPhase")=="Hint"
            and sessionFolder:GetAttribute("CurrentTurnUserId")==targetPlayer.UserId
        title.Text=speaking and "СЕЙЧАС ГОВОРИТ" or titleText
        title.TextColor3=speaking and COLORS.Brass or titleColor
        -- The room needs identities; rank/title cards belong in the dossier.
        title.Visible=false
        rank.Visible=false
        display.TextColor3=speaking and COLORS.Brass or COLORS.IvorySoft
		rank.Text = tostring(targetPlayer:GetAttribute("SpyRankShort") or "ГОСТЬ")
			.. "  ·  УР. "
			.. tostring(math.max(1, math.floor(tonumber(targetPlayer:GetAttribute("SpyLevel")) or 1)))
		local frameColor, thickness, transparency = resolvedMatchFrameStyle(targetPlayer)
        outline.Color=speaking and COLORS.Brass or frameColor
        outline.Thickness=thickness
        outline.Transparency=1
	end
	refresh()

	local list = identityConnections[targetPlayer]
	if list then
		list[#list + 1] = targetPlayer:GetAttributeChangedSignal("SpyTitle"):Connect(refresh)
		list[#list + 1] = targetPlayer:GetAttributeChangedSignal("SpyFrame"):Connect(refresh)
		list[#list + 1] = targetPlayer:GetAttributeChangedSignal("SpyEffect"):Connect(refresh)
		list[#list + 1] = targetPlayer:GetAttributeChangedSignal("SpyLevel"):Connect(refresh)
		list[#list + 1] = targetPlayer:GetAttributeChangedSignal("SpyRankShort"):Connect(refresh)
        if sessionFolder then
            list[#list+1]=sessionFolder:GetAttributeChangedSignal("RoundPhase"):Connect(refresh)
            list[#list+1]=sessionFolder:GetAttributeChangedSignal("CurrentTurnUserId"):Connect(refresh)
        end
	end
end

local function connectMatchIdentity(targetPlayer)
	if identityConnections[targetPlayer] then return end
	identityConnections[targetPlayer] = {}

	local function reconcile()
		local character = targetPlayer.Character
		if character then
			task.spawn(createMatchIdentityTag, targetPlayer, character)
		end
	end

	identityConnections[targetPlayer][#identityConnections[targetPlayer] + 1] =
		targetPlayer.CharacterAdded:Connect(function(character)
			task.defer(createMatchIdentityTag, targetPlayer, character)
		end)

	identityConnections[targetPlayer][#identityConnections[targetPlayer] + 1] =
		targetPlayer:GetAttributeChangedSignal("SpyAppearanceRevision"):Connect(function()
			task.delay(0.08, reconcile)
		end)

	reconcile()
end

for _, targetPlayer in ipairs(Players:GetPlayers()) do
	connectMatchIdentity(targetPlayer)
end

Players.PlayerAdded:Connect(connectMatchIdentity)
Players.PlayerRemoving:Connect(clearIdentityConnections)

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function make(className, parent, props)
	local object = Instance.new(className)

	for key, value in pairs(props or {}) do
		object[key] = value
	end

	object.Parent = parent

	return object
end

local function tween(object, duration, props, style, direction)
	local animation =
		TweenService:Create(
			object,
			TweenInfo.new(
				duration,
				style or Enum.EasingStyle.Quint,
				direction or Enum.EasingDirection.Out
			),
			props
		)

	animation:Play()

	return animation
end

local function waitTween(animation)
	if animation then
		animation.Completed:Wait()
	end
end

local function label(parent, props)
	props = props or {}

	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.BuilderSansMedium
	props.TextColor3 = props.TextColor3 or COLORS.Ivory
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center

	return make("TextLabel", parent, props)
end

local function corner(parent, radius)
 -- Club screens use restrained edges, including dynamically created choices.
 radius=math.clamp(radius or 3,2,4)
	return make(
		"UICorner",
		parent,
		{
			CornerRadius = UDim.new(0, radius),
		}
	)
end

local function stroke(parent, color, transparency, thickness)
	return make(
		"UIStroke",
		parent,
		{
			Color = color,
			Transparency = transparency or 0,
			Thickness = thickness or 1,
		}
	)
end

---------------------------------------------------------------------
-- FORWARD DECLARATION
---------------------------------------------------------------------

local playerDisplayName
local currentState

---------------------------------------------------------------------
-- OLD UI REMOVE
---------------------------------------------------------------------

local oldGui = playerGui:FindFirstChild("MatchUI")

if oldGui then
	oldGui:Destroy()
end

---------------------------------------------------------------------
-- ROOT
---------------------------------------------------------------------

local gui =
	make(
		"ScreenGui",
		playerGui,
		{
			Name = "MatchUI",

			IgnoreGuiInset = false,
            ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
			ResetOnSpawn = false,

			DisplayOrder = 300,

			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}
	)

---------------------------------------------------------------------
-- ARRIVAL BRIEFING / LOADING
---------------------------------------------------------------------

local blackout =
	make(
		"Frame",
		gui,
		{
			Name="Blackout",
			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = COLORS.Black,
			BackgroundTransparency = 0.10,

			BorderSizePixel = 0,

			ZIndex = 500,
		}
	)

make(
	"UIGradient",
	blackout,
	{
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 8, 10)),
			ColorSequenceKeypoint.new(0.58, Color3.fromRGB(17, 17, 19)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 35)),
		}),
		Rotation = 18,
	}
)

matchUI.arrivalRoot =
	make(
		"CanvasGroup",
		blackout,
		{
			Name = "ArrivalBriefing",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 0,
			ZIndex = 501,
		}
	)

matchUI.arrivalPanel =
	make(
		"Frame",
		matchUI.arrivalRoot,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.50),
			Size = UDim2.fromOffset(720, 328),
			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			ZIndex = 502,
		}
	)

matchUI.arrivalPanelScale =
	make(
		"UIScale",
		matchUI.arrivalPanel,
		{Scale = 1}
	)

corner(matchUI.arrivalPanel, 10)
stroke(matchUI.arrivalPanel, COLORS.BrassDark, 0.65, 1)

make(
	"Frame",
	matchUI.arrivalPanel,
	{
		Size = UDim2.fromOffset(4, 328),
		BackgroundColor3 = COLORS.Brass,
		BorderSizePixel = 0,
		ZIndex = 503,
	}
)

matchUI.arrivalMark =
	make(
		"Frame",
		matchUI.arrivalPanel,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(70, 72),
			Size = UDim2.fromOffset(48, 48),
			Rotation = 45,
			BackgroundColor3 = COLORS.Panel3,
			BorderSizePixel = 0,
			ZIndex = 503,
		}
	)

matchUI.arrivalMark.Visible=false
corner(matchUI.arrivalMark, 8)
stroke(matchUI.arrivalMark, COLORS.Brass, 0.05, 2)

make(
	"Frame",
	matchUI.arrivalMark,
	{
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = COLORS.Brass,
		BorderSizePixel = 0,
		ZIndex = 504,
	}
)

label(
	matchUI.arrivalPanel,
	{
		Position = UDim2.fromOffset(118, 34),
		Size = UDim2.new(1, -150, 0, 24),
		Text = "ЗАКРЫТАЯ ПАРТИЯ",
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 12,
		TextColor3 = COLORS.Brass,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 504,
	}
)

label(
	matchUI.arrivalPanel,
	{
		Position = UDim2.fromOffset(118, 56),
		Size = UDim2.new(1, -150, 0, 44),
		Text = "SPY CLUB",
		Font = Enum.Font.Garamond,
		TextSize = 38,
		TextColor3 = COLORS.Ivory,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 504,
	}
)

make(
	"Frame",
	matchUI.arrivalPanel,
	{
		Position = UDim2.fromOffset(36, 122),
		Size = UDim2.new(1, -72, 0, 1),
		BackgroundColor3 = COLORS.BrassDark,
		BackgroundTransparency = 0.32,
		BorderSizePixel = 0,
		ZIndex = 503,
	}
)

matchUI.arrivalStatus =
	label(
		matchUI.arrivalPanel,
		{
			Position = UDim2.fromOffset(36, 151),
			Size = UDim2.new(1, -72, 0, 32),
			Text = "Собираем стол…",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 22,
			TextColor3 = COLORS.Ivory,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 504,
		}
	)

matchUI.arrivalDetail =
	label(
		matchUI.arrivalPanel,
		{
			Position = UDim2.fromOffset(36, 184),
			Size = UDim2.new(1, -72, 0, 24),
			Text = "Подтверждаем места и готовим колоду.",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 13,
			TextColor3 = COLORS.IvorySoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 504,
		}
	)

matchUI.arrivalTrack =
	make(
		"Frame",
		matchUI.arrivalPanel,
		{
			Position = UDim2.fromOffset(36, 226),
			Size = UDim2.new(1, -72, 0, 3),
			BackgroundColor3 = COLORS.Panel3,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 503,
		}
	)

matchUI.arrivalSweep =
	make(
		"Frame",
		matchUI.arrivalTrack,
		{
			Position = UDim2.fromScale(-0.32, 0),
			Size = UDim2.fromScale(0.32, 1),
			BackgroundColor3 = COLORS.Brass,
			BorderSizePixel = 0,
			ZIndex = 504,
		}
	)

make(
	"UIGradient",
	matchUI.arrivalSweep,
	{
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}
)

matchUI.arrivalCount =
	label(
		matchUI.arrivalPanel,
		{
			Position = UDim2.fromOffset(36, 252),
			Size = UDim2.new(0.5, -36, 0, 24),
			Text = "ИГРОКИ · —",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 11,
			TextColor3 = COLORS.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 504,
		}
	)

matchUI.arrivalAgent =
	label(
		matchUI.arrivalPanel,
		{
			Position = UDim2.new(0.5, 0, 0, 252),
			Size = UDim2.new(0.5, -36, 0, 24),
			Name = "PlayerName",
            Text = string.upper(player.DisplayName),
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 11,
			TextColor3 = COLORS.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 504,
		}
	)

label(
	matchUI.arrivalPanel,
	{
		Position = UDim2.fromOffset(36, 289),
		Size = UDim2.new(1, -72, 0, 18),
		Text = "НЕ ПОКИДАЙ СТОЛ · СВЯЗЬ ЗАЩИЩЕНА",
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 10,
		TextColor3 = COLORS.BrassDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 504,
	}
)

matchUI.blackoutText =
	label(
		blackout,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(650, 60),
			Text = "Собираем стол…",
			Visible = false,
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 20,
			TextColor3 = COLORS.IvorySoft,
			ZIndex = 506,
		}
	)

local gameRevealed = false

local function updateArrivalStatus()
	if gameRevealed then
		return
	end

	local ready = sessionFolder
		and sessionFolder:GetAttribute("Ready") == true
	local readyCount = sessionFolder
		and tonumber(sessionFolder:GetAttribute("ReadyCount"))
		or 0
	local expected = sessionFolder
		and tonumber(sessionFolder:GetAttribute("ExpectedCount"))
		or 0
	local connected = sessionFolder
		and tonumber(sessionFolder:GetAttribute("ConnectedCount"))
		or readyCount

	if expected > 0 then
		matchUI.arrivalCount.Text =
			"ИГРОКИ · "
			.. tostring(math.max(readyCount, connected))
			.. "/"
			.. tostring(expected)
	else
		matchUI.arrivalCount.Text = "ИГРОКИ · ПОДКЛЮЧЕНИЕ"
	end

	if ReplicatedStorage:GetAttribute("SpyMatchBootError") then
		matchUI.arrivalStatus.Text = "НЕ УДАЛОСЬ ПОДГОТОВИТЬ МАТЧ"
		matchUI.arrivalDetail.Text = "Код: " .. tostring(ReplicatedStorage:GetAttribute("SpyMatchBootError"))
	elseif player:GetAttribute("SpyAppearanceStatus") == "failed" then
		matchUI.arrivalStatus.Text = "ОДЕЖДА НЕ ЗАГРУЗИЛАСЬ"
		matchUI.arrivalDetail.Text = "Сервис внешности не ответил · M22-AVATAR"
	elseif player:GetAttribute("SpyMatchPreparationFailed") then
		matchUI.arrivalStatus.Text = "ПОДГОТОВКА ЗАНИМАЕТ БОЛЬШЕ ВРЕМЕНИ"
		matchUI.arrivalDetail.Text = "Ожидаем персонажа и интерфейс · M22-READY"
	elseif ready then
		matchUI.arrivalStatus.Text = "СТОЛ ПОДТВЕРЖДЁН"
		matchUI.arrivalDetail.Text = "Открываем комнату и передаём управление."
	elseif connected > readyCount then
		matchUI.arrivalStatus.Text = "РАССАЖИВАЕМ ГОСТЕЙ"
		matchUI.arrivalDetail.Text = "Ожидаем готовность персонажей."
	elseif connected > 0 then
		matchUI.arrivalStatus.Text = "СОБИРАЕМ СТОЛ"
		matchUI.arrivalDetail.Text = "Ждём остальных участников закрытой партии."
	else
		matchUI.arrivalStatus.Text = "СОБИРАЕМ СТОЛ"
		matchUI.arrivalDetail.Text = "Проверяем приглашение и резервируем место."
	end
end

if sessionFolder then
	for _, attribute in ipairs({
		"Ready",
		"ReadyCount",
		"ExpectedCount",
		"ConnectedCount",
	}) do
		sessionFolder:GetAttributeChangedSignal(attribute):Connect(
			updateArrivalStatus
		)
	end
end

updateArrivalStatus()

player:GetAttributeChangedSignal("SpyAppearanceStatus"):Connect(updateArrivalStatus)
player:GetAttributeChangedSignal("SpyMatchPreparationFailed"):Connect(updateArrivalStatus)
ReplicatedStorage:GetAttributeChangedSignal("SpyMatchBootError"):Connect(updateArrivalStatus)

do
	local connecting = playerGui:FindFirstChild("SpyMatchConnecting")
	if connecting then connecting:Destroy() end
end

task.spawn(function()
	while matchUI.arrivalRoot.Parent and not gameRevealed do
		matchUI.arrivalSweep.Position = UDim2.fromScale(-0.32, 0)
		waitTween(
			tween(
				matchUI.arrivalSweep,
				1.15,
				{Position = UDim2.fromScale(1, 0)},
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut
			)
		)
		task.wait(0.35)
	end
end)

task.delay(18, function()
	if gameRevealed then
		return
	end

	updateArrivalStatus()
end)

local function revealGame()
	if gameRevealed then
		return
	end

	gameRevealed = true
	matchUI.blackoutText.Visible = false

	tween(
		matchUI.arrivalRoot,
		0.32,
		{GroupTransparency = 1},
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)

	local fade =
		tween(
			blackout,
			0.72,
			{BackgroundTransparency = 1},
			Enum.EasingStyle.Sine
		)

	task.spawn(function()
		fade.Completed:Wait()
		if gameRevealed then
			matchUI.arrivalRoot.Visible = false
			blackout.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- CUT FADE
---------------------------------------------------------------------

matchUI.cutFade =
	make(
		"Frame",
		gui,
		{
			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = COLORS.Black,
			BackgroundTransparency = 1,

			BorderSizePixel = 0,

			Visible = false,

			ZIndex = 480,
		}
	)

---------------------------------------------------------------------
-- CINEMA BARS
---------------------------------------------------------------------

matchUI.topBar =
	make(
		"Frame",
		gui,
		{
			Size = UDim2.new(1, 0, 0, 0),

			BackgroundColor3 = COLORS.Black,

			BorderSizePixel = 0,

			ZIndex = 450,
		}
	)

matchUI.bottomBar =
	make(
		"Frame",
		gui,
		{
			AnchorPoint = Vector2.new(0, 1),

			Position = UDim2.fromScale(0, 1),

			Size = UDim2.new(1, 0, 0, 0),

			BackgroundColor3 = COLORS.Black,

			BorderSizePixel = 0,

			ZIndex = 450,
		}
	)

local function cinemaBars(_enabled)
 -- Camera motion supplies the transition. Letterboxing never covers gameplay.
 matchUI.topBar.Visible=false;matchUI.bottomBar.Visible=false
 matchUI.topBar.Size=UDim2.new(1,0,0,0);matchUI.bottomBar.Size=UDim2.new(1,0,0,0)
end

---------------------------------------------------------------------
-- AGENT LEVEL / INTRO DOSSIER
---------------------------------------------------------------------

matchUI.agentBadge =
	make(
		"CanvasGroup",
		gui,
		{
			Name = "AgentLevelBadge",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, 22),
			Size = UDim2.fromOffset(214, 58),
			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 120,
		}
	)

corner(matchUI.agentBadge, 8)
stroke(matchUI.agentBadge, COLORS.BrassDark, 0.30, 1)

matchUI.agentNameLabel =
	label(
		matchUI.agentBadge,
		{
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 18),
			Name = "PlayerName",
            Text = string.upper(player.DisplayName),
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 11,
			TextColor3 = COLORS.Ivory,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 121,
		}
	)

matchUI.agentLevelLabel =
	label(
		matchUI.agentBadge,
		{
			Position = UDim2.fromOffset(14, 27),
			Size = UDim2.new(1, -28, 0, 16),
			Text = "УРОВЕНЬ 1",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 12,
			TextColor3 = COLORS.Brass,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 121,
		}
	)

matchUI.agentXpTrack =
	make(
		"Frame",
		matchUI.agentBadge,
		{
			Position = UDim2.fromOffset(14, 48),
			Size = UDim2.new(1, -28, 0, 2),
			BackgroundColor3 = COLORS.Panel3,
			BorderSizePixel = 0,
			ZIndex = 121,
		}
	)

matchUI.agentXpFill =
	make(
		"Frame",
		matchUI.agentXpTrack,
		{
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = COLORS.Brass,
			BorderSizePixel = 0,
			ZIndex = 122,
		}
	)

matchUI.briefingRoot =
	make(
		"CanvasGroup",
		gui,
		{
			Name = "IntroDossier",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 34, 0.54, 0),
			Size = UDim2.fromOffset(520, 214),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 420,
		}
	)

matchUI.briefingScale =
	make(
		"UIScale",
		matchUI.briefingRoot,
		{Scale = 1}
	)

local function updateCinematicScale()
	local viewport = camera.ViewportSize
	local scale = math.clamp(
		math.min(
			viewport.X / 900,
			viewport.Y / 560
		),
		0.46,
		1
	)

	matchUI.arrivalPanelScale.Scale = scale
	matchUI.briefingScale.Scale = math.max(0.58, scale)
end

camera:GetPropertyChangedSignal("ViewportSize"):Connect(
	updateCinematicScale
)

updateCinematicScale()

make(
	"Frame",
	matchUI.briefingRoot,
	{
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(3, 162),
		BackgroundColor3 = COLORS.Brass,
		BorderSizePixel = 0,
		ZIndex = 421,
	}
)

matchUI.briefingMeta =
	label(
		matchUI.briefingRoot,
		{
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -22, 0, 22),
			Text = "SPY CLUB",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 11,
			TextColor3 = COLORS.Brass,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 421,
		}
	)

matchUI.briefingTitle =
	label(
		matchUI.briefingRoot,
		{
			Position = UDim2.fromOffset(22, 30),
			Size = UDim2.new(1, -22, 0, 48),
			Text = "НАЧИНАЕМ",
			Font = Enum.Font.Garamond,
			TextSize = 36,
			TextColor3 = COLORS.Ivory,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 421,
		}
	)

matchUI.briefingParty =
	label(
		matchUI.briefingRoot,
		{
			Position = UDim2.fromOffset(22, 84),
			Size = UDim2.new(1, -22, 0, 24),
			Text = "",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 14,
			TextColor3 = COLORS.IvorySoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 421,
		}
	)

matchUI.briefingAgent =
	label(
		matchUI.briefingRoot,
		{
			Position = UDim2.fromOffset(22, 124),
			Size = UDim2.new(1, -22, 0, 22),
			Text = "",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 12,
			TextColor3 = COLORS.Brass,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 421,
		}
	)

matchUI.briefingHint =
	label(
		matchUI.briefingRoot,
		{
			Position = UDim2.fromOffset(22, 151),
			Size = UDim2.new(1, -22, 0, 24),
			Text = "",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 10,
			TextColor3 = COLORS.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 421,
		}
	)

local function resolveLocalProgress(state)
	local level = tonumber(player:GetAttribute("SpyLevel")) or 1
	local xp = tonumber(player:GetAttribute("SpyXP")) or 0
	local coins = tonumber(player:GetAttribute("SpyCoins")) or 0

	for _, info in ipairs(state and state.players or {}) do
		if tonumber(info.userId) == player.UserId then
			level = tonumber(info.level) or level
			xp = tonumber(info.xp) or xp
			coins = tonumber(info.coins) or coins
			break
		end
	end

	return
		math.max(1, math.floor(level)),
		math.max(0, math.floor(xp)),
		math.max(0, math.floor(coins))
end

local function updateAgentBadge(state)
	local level, xp = resolveLocalProgress(state)
	local withinLevel = xp % 100

	matchUI.agentNameLabel.Text = string.upper(player.DisplayName)
	matchUI.agentLevelLabel.Text = "УРОВЕНЬ " .. tostring(level)
	matchUI.agentXpFill.Size = UDim2.fromScale(withinLevel / 100, 1)
	matchUI.arrivalAgent.Text =
		string.upper(player.DisplayName)
		.. " · УР. "
		.. tostring(level)
end

local briefingToken = 0

local function playIntroBriefing(state)
	briefingToken += 1
	local token = briefingToken
	local level = resolveLocalProgress(state)
	local playerCount = #(state.players or {})

	matchUI.briefingMeta.Text =
		"SPY CLUB  /  "
		.. string.upper(tostring(state.partyName or "ЗАКРЫТЫЙ СТОЛ"))
	matchUI.briefingParty.Text =
		"ЗА СТОЛОМ · "
		.. tostring(playerCount)
		.. "   /   КАРТЫ ГОТОВЫ"
	matchUI.briefingAgent.Text =
		string.upper(player.DisplayName)
		.. "   ·   УРОВЕНЬ "
		.. tostring(level)

	-- The first second belongs to the physical room, not to an overlay.
	task.delay(1.05, function()
		if token ~= briefingToken or not currentState or currentState.phase ~= "Intro" then return end
		matchUI.briefingRoot.Visible = true
		matchUI.briefingRoot.GroupTransparency = 1
		matchUI.briefingRoot.Position = UDim2.new(0, 34, 0.54, 0)
		tween(matchUI.briefingRoot, 0.48, {
			GroupTransparency = 0,
			Position = UDim2.new(0, 58, 0.54, 0),
		}, Enum.EasingStyle.Quint)
	end)

	task.delay(4.65, function()
		if token ~= briefingToken then
			return
		end

		local fade = tween(
			matchUI.briefingRoot,
			0.32,
			{GroupTransparency = 1},
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)

		fade.Completed:Wait()
		if token == briefingToken then
			matchUI.briefingRoot.Visible = false
		end
	end)
end

for _, attribute in ipairs({"SpyLevel", "SpyXP", "SpyCoins"}) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		updateAgentBadge(currentState)
	end)
end

updateAgentBadge(nil)

---------------------------------------------------------------------
-- PHASE / TURN HUD
---------------------------------------------------------------------

-- A public round folio. Private card data never enters this surface.
matchUI.phaseRoot=make("CanvasGroup",gui,{
 Name="MatchPhasePanel",AnchorPoint=Vector2.new(),Position=UDim2.fromOffset(24,516),
 Size=UDim2.fromOffset(640,112),BackgroundColor3=COLORS.Panel,BackgroundTransparency=.10,
 BorderSizePixel=0,GroupTransparency=1,ZIndex=100,
})
corner(matchUI.phaseRoot,3)
stroke(matchUI.phaseRoot,COLORS.BrassDark,.78,1)
make("Frame",matchUI.phaseRoot,{Name="PhaseRule",Size=UDim2.new(1,-28,0,1),Position=UDim2.fromOffset(14,0),
 BackgroundColor3=COLORS.Brass,BackgroundTransparency=.35,BorderSizePixel=0,ZIndex=101})
matchUI.matchIdentity=label(matchUI.phaseRoot,{
 Name="MatchIdentity",Position=UDim2.fromOffset(18,9),Size=UDim2.fromOffset(140,14),
 Text="SPY CLUB /",TextSize=10,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.Muted,
 TextXAlignment=Enum.TextXAlignment.Left,ZIndex=101,
})
matchUI.stageSequence=label(matchUI.phaseRoot,{
 Name="StageSequence",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,9),Size=UDim2.new(1,-180,0,14),
 Text="",TextSize=10,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.Muted,
 TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=101,
})
matchUI.stageSequence:SetAttribute("SpyUserText",true)
matchUI.clockDivider=make("Frame",matchUI.phaseRoot,{
 Name="ClockDivider",Position=UDim2.new(1,-118,0,34),Size=UDim2.fromOffset(1,38),
 BackgroundColor3=COLORS.BrassDark,BackgroundTransparency=.62,BorderSizePixel=0,ZIndex=101,
})
matchUI.timerLabel=label(matchUI.phaseRoot,{
 Name="StageTimerLabel",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,30),Size=UDim2.fromOffset(84,13),
 Text="ОСТАЛОСЬ",TextSize=9,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.Muted,ZIndex=101,
})
matchUI.speakerPortrait=make("Frame",matchUI.phaseRoot,{
 Name="SpeakerPortrait",Position=UDim2.fromOffset(14,12),Size=UDim2.fromOffset(42,42),
 BackgroundColor3=COLORS.Panel3,BorderSizePixel=0,ZIndex=101,
})
corner(matchUI.speakerPortrait,3)
matchUI.phaseMeta=label(matchUI.phaseRoot,{
 Name="StageMeta",Position=UDim2.fromOffset(84,12),Size=UDim2.new(1,-184,0,18),
 Text="",TextSize=12,Font=Enum.Font.BuilderSansBold,TextColor3=COLORS.IvorySoft,
 TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=101,
})
matchUI.phaseTitle=label(matchUI.phaseRoot,{
 Name="StageTitle",Position=UDim2.fromOffset(84,35),Size=UDim2.new(1,-184,0,30),
 Text="",TextSize=22,Font=Enum.Font.Garamond,TextColor3=COLORS.Ivory,
 TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=101,
})
matchUI.instructionSurface=make("Frame",matchUI.phaseRoot,{Name="InstructionSurface",BackgroundColor3=COLORS.Panel3,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(14,58),Size=UDim2.new(1,-28,0,32),ZIndex=101})
corner(matchUI.instructionSurface,12)
matchUI.phaseSubtitle=label(matchUI.instructionSurface,{
 Name="StageInstruction",Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),
 Text="",TextSize=15,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.IvorySoft,
 TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=101,
})
matchUI.timer=label(matchUI.phaseRoot,{
 Name="StageTimer",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,12),
 Size=UDim2.fromOffset(84,36),Text="",TextSize=26,Font=Enum.Font.Garamond,TextColor3=COLORS.Ivory,ZIndex=102,
})
matchUI.turnPips={}
matchUI.instructionRule=make("Frame",matchUI.phaseRoot,{Name="InstructionRule",Position=UDim2.fromOffset(18,78),Size=UDim2.new(1,-36,0,1),BackgroundColor3=COLORS.BrassDark,BackgroundTransparency=.72,BorderSizePixel=0,ZIndex=101})
local clockTrack=make("Frame",matchUI.phaseRoot,{Name="ClockTrack",Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),BackgroundColor3=COLORS.Panel3,BorderSizePixel=0,ZIndex=102})
matchUI.clockFill=make("Frame",clockTrack,{Name="ClockFill",Size=UDim2.fromScale(1,1),BackgroundColor3=COLORS.Brass,BorderSizePixel=0,ZIndex=103})
local clockKey,clockWindow
local phaseAnimationToken = 0
local lastTurnBannerUserId = nil
function matchUI.setPhasePortrait(userId)
    matchUI.showSpeaker=userId~=nil
    matchUI.speakerPortrait.Visible=matchUI.showSpeaker
    if matchUI.fitPanels then matchUI.fitPanels()end
    if not userId then
        if matchUI.phasePortraitDispose then matchUI.phasePortraitDispose();matchUI.phasePortraitDispose=nil end
        matchUI.phasePortraitTarget=nil;return
    end
    if not MatchPresentation then return end
    local target=Players:GetPlayerByUserId(userId or player.UserId)
    if matchUI.phasePortraitTarget==target and matchUI.phasePortraitDispose then return end
    if matchUI.phasePortraitDispose then matchUI.phasePortraitDispose()end
    matchUI.phasePortraitTarget=target
    matchUI.phasePortraitDispose=MatchPresentation.attachPortrait(matchUI.speakerPortrait,target)
end
script.Destroying:Connect(function()if matchUI.phasePortraitDispose then matchUI.phasePortraitDispose()end end)

local function setPhase(titleText, subtitleText)
	phaseAnimationToken += 1
    matchUI.setPhasePortrait(nil)

    for _,pip in ipairs(matchUI.turnPips) do pip.Visible=false end
    matchUI.phaseMeta:SetAttribute('SpyUserText',false)
	matchUI.phaseMeta.Text = MatchI18n.text(player:GetAttribute('SpyLanguage')or'ru',"ЗАКРЫТЫЙ СТОЛ")
	matchUI.phaseMeta.TextColor3 = COLORS.Brass

	matchUI.phaseTitle:SetAttribute("SpyUserText",false)
	matchUI.phaseTitle.Text = titleText or ""
	matchUI.phaseTitle.TextColor3 = COLORS.Ivory

	matchUI.phaseSubtitle.Text = subtitleText or ""

	tween(
		matchUI.phaseRoot,
		0.18,
		{
			GroupTransparency = 0,
		}
	)
end

local function setTurnPhase(state)
	if not state then
		return
	end

	local userId = state.turnUserId

	local displayName =
		playerDisplayName(
			state,
			userId
		)

	local currentTurn = tonumber(state.turnIndex) or 1

	local totalPlayers = #(state.players or {})

	local currentLap = tonumber(state.lap) or 1
	local totalLaps = tonumber(state.hintLaps) or currentLap

	local ownTurn = userId == player.UserId

	phaseAnimationToken += 1

	local token = phaseAnimationToken

	local function applyText()
		if token ~= phaseAnimationToken then
			return
		end

        local lang=player:GetAttribute('SpyLanguage')
        matchUI.phaseMeta:SetAttribute('SpyUserText',true)
        matchUI.phaseMeta.Text=ownTurn and(lang=='en'and'Your turn'or lang=='zh'and'你的回合'or'Твой ход')or(lang=='en'and'Speaking'or lang=='zh'and'发言者'or'Говорит')
        matchUI.setPhasePortrait(userId~=player.UserId and userId or nil)
        matchUI.phaseMeta.TextColor3=ownTurn and COLORS.Brass or COLORS.IvorySoft
        matchUI.phaseTitle:SetAttribute("SpyUserText",true)
        matchUI.phaseTitle.Text=ownTurn and not state.case and(lang=='en'and'Give your clue'or lang=='zh'and'给出你的提示'or'Дай подсказку')or displayName
        matchUI.phaseTitle.TextColor3=COLORS.Ivory
        matchUI.phaseSubtitle.Text=(ownTurn and "Одна подсказка" or "Слушай подсказку")
            .. "  ·  Круг " .. tostring(currentLap) .. "/" .. tostring(totalLaps)
        for i,pip in ipairs(matchUI.turnPips) do
            pip.Visible=i<=totalPlayers
            pip.BackgroundColor3=i==currentTurn and COLORS.Brass or i<currentTurn and COLORS.IvorySoft or COLORS.Muted
            pip.BackgroundTransparency=i>currentTurn and .6 or 0
            pip.TextColor3=i>currentTurn and COLORS.IvorySoft or COLORS.Ink
        end
		if matchUI.refreshGuide then matchUI.refreshGuide() end
	end

	if lastTurnBannerUserId ~= userId then
		lastTurnBannerUserId = userId

		task.spawn(function()
			if token ~= phaseAnimationToken then return end
			local fade =
				tween(
					matchUI.phaseRoot,
					0.10,
					{
						GroupTransparency = 0.72,
					},
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)

			fade.Completed:Wait()

			if token ~= phaseAnimationToken then
				return
			end

			applyText()

			tween(
				matchUI.phaseRoot,
				0.22,
				{
					GroupTransparency = 0,
				},
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			)
		end)
	else
		applyText()

		tween(
			matchUI.phaseRoot,
			0.16,
			{
				GroupTransparency = 0,
			}
		)
	end
end

---------------------------------------------------------------------
-- CONTROLS
---------------------------------------------------------------------

matchUI.controls=make("CanvasGroup",gui,{
 Name="MatchShortcuts",AnchorPoint=Vector2.new(),Position=UDim2.fromOffset(24,648),
 Size=UDim2.fromOffset(436,44),BackgroundColor3=COLORS.Panel,BackgroundTransparency=.16,Visible=false,
 BorderSizePixel=0,GroupTransparency=1,ZIndex=90,
})
corner(matchUI.controls,5)
local function shortcut(name,x,key,ru,en,zh)
 local b=make("TextButton",matchUI.controls,{Name=name,Position=UDim2.new(x,4,0,4),Size=UDim2.new(.5,-8,1,-8),
  BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,Text="",TextSize=15,Font=Enum.Font.BuilderSansBold,
  TextColor3=COLORS.Ivory,ZIndex=91,AutoButtonColor=true})
 corner(b,14)
 local function copy()
  local language=player:GetAttribute("SpyLanguage")
  local caption=language=="en"and en or language=="zh"and(zh or en)or ru
  local compact=UserInputService.TouchEnabled or gui.AbsoluteSize.X<700
  b.Text=(compact and ""or key.."  ·  ")..caption
 end
 player:GetAttributeChangedSignal("SpyLanguage"):Connect(copy)
 UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(copy)
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(copy)
 copy();return b
end
matchUI.cardShortcut=shortcut("ShowRoleCard",0,"C","Карта","Card","角色卡")
matchUI.chatShortcut=shortcut("OpenTableChat",.5,"/","Чат","Chat","聊天")
MatchHUD.registerUtilities(playerGui,matchUI.controls)
gui.Destroying:Connect(function()matchUI.controls:Destroy()end)
matchUI.viewShortcut=shortcut("ChangeTableView",.5,"V","Вид стола","Table view","视角")
MatchHUD.register(playerGui,matchUI.viewShortcut,80,"V")
do
 local entry=make('TextButton',gui,{Name='MatchCharacterMenu',Text='',Visible=true})
 MatchHUD.register(playerGui,entry,30,'H')
 local function caption()
  local lang=player:GetAttribute('SpyLanguage')
  entry:SetAttribute('SpyUserText',true)
  entry.Text=lang=='en'and'Character'or lang=='zh'and'角色'or'Персонаж'
 end
 entry.Activated:Connect(function()
  local event=playerGui:FindFirstChild('SpyOpenDossier')
  if event and event:IsA('BindableEvent')then event:Fire()end
 end)
 player:GetAttributeChangedSignal('SpyLanguage'):Connect(caption);caption()
end
do
 local shared=ReplicatedStorage:FindFirstChild("SpyShared")
 local files=shared and shared:FindFirstChild("CaseFiles")
 local guide=shared and shared:FindFirstChild("MatchGuide")
 if files and guide then
  local ok,f=pcall(require,files);local good,g=pcall(require,guide)
  if ok and good then matchUI.caseFiles=f;matchUI.guide=g end
 end
 matchUI.helpHidden=player:GetAttribute("SpyMatchHelpHidden")==true
 matchUI.helpShortcut=shortcut("MatchHelp",.76,"?","Подсказки","Guidance","提示")
 MatchHUD.register(playerGui,matchUI.helpShortcut,85)
 matchUI.cardShortcut.Position=UDim2.fromOffset(0,0);matchUI.cardShortcut.Size=UDim2.new(.5,-5,1,0)
 matchUI.chatShortcut.Position=UDim2.new(.5,5,0,0);matchUI.chatShortcut.Size=UDim2.new(.5,-5,1,0)
 for _,b in ipairs({matchUI.cardShortcut,matchUI.chatShortcut})do b.TextWrapped=false end
 matchUI.phaseSubtitle.TextWrapped=true;matchUI.phaseSubtitle.TextTruncate=Enum.TextTruncate.None
 matchUI.phaseSubtitle.Size=UDim2.new(1,-28,0,28)
 function matchUI.refreshGuide()
  if not currentState or not matchUI.guide then return end
  local lang=player:GetAttribute("SpyLanguage")or"ru"
  matchUI.stageSequence.Text=matchUI.guide.context(lang,currentState)
  matchUI.timerLabel:SetAttribute("SpyUserText",true)
  matchUI.timerLabel.Text=lang=="en"and"TIME LEFT"or lang=="zh"and"剩余时间"or"ОСТАЛОСЬ"
  matchUI.phaseMeta:SetAttribute('SpyUserText',true)
  matchUI.phaseMeta.Text=matchUI.guide.phase(lang,currentState,player.UserId)
  if currentState.phase=='Hint'then
   if currentState.turnUserId==player.UserId and not currentState.case then
    matchUI.phaseTitle.Text=lang=='en'and'Give your clue'or lang=='zh'and'给出你的提示'or'Дай подсказку'
   end
  end
  matchUI.phaseSubtitle:SetAttribute("SpyUserText",true)
  matchUI.phaseSubtitle.Text=matchUI.helpHidden and""or matchUI.guide.message(matchUI.caseFiles,lang,currentState,player.UserId,player:GetAttribute("SpyRoleCardOpened"))
  matchUI.helpShortcut:SetAttribute("SpyUserText",true);matchUI.helpShortcut.Text=lang=="en"and(matchUI.helpHidden and"Show guidance"or"Hide guidance")or lang=="zh"and(matchUI.helpHidden and"显示提示"or"隐藏提示")or(matchUI.helpHidden and"Показать подсказку"or"Скрыть подсказку")
  local active=currentState.phase=="Discuss"and currentState.discussion and currentState.discussion.active
  if active then
   matchUI.phaseSubtitle.Text=matchUI.guide.questionText(lang,active.prompt)
   matchUI.phaseTitle:SetAttribute("SpyUserText",true);matchUI.phaseTitle.Text=playerDisplayName(currentState,active.target)
   matchUI.phaseMeta:SetAttribute("SpyUserText",true);matchUI.phaseMeta.Text=lang=="en"and"Answering"or lang=="zh"and"正在回答"or"Отвечает"
   matchUI.setPhasePortrait(active.target~=player.UserId and active.target or nil)
   for _,pip in ipairs(matchUI.turnPips)do pip.Visible=false end
  end
  local c=currentState.case
  if c then
   matchUI.cardShortcut:SetAttribute("SpyUserText",true);matchUI.cardShortcut.Text=matchUI.caseFiles.text(lang,"clues")
   if c.stage=="defense"then
    matchUI.phaseTitle:SetAttribute("SpyUserText",true);matchUI.phaseTitle.Text=playerDisplayName(currentState,c.defenseId)
    matchUI.setPhasePortrait(c.defenseId~=player.UserId and c.defenseId or nil)
    for _,pip in ipairs(matchUI.turnPips)do pip.Visible=false end
   elseif c.stage=="inspect"then
    matchUI.phaseTitle:SetAttribute("SpyUserText",true);matchUI.phaseTitle.Text=matchUI.caseFiles.text(lang,"inspect_stage")
   end
  end
 end
 matchUI.helpShortcut.Activated:Connect(function()
  matchUI.helpHidden=not matchUI.helpHidden;player:SetAttribute("SpyMatchHelpHidden",matchUI.helpHidden);matchUI.refreshGuide()
 end)
 player:GetAttributeChangedSignal("SpyLanguage"):Connect(function()matchUI.refreshGuide()end)
 player:GetAttributeChangedSignal("SpyRoleCardOpened"):Connect(function()matchUI.refreshGuide()end)
end
-- MATCH_EMOTE_UI_BEGIN
 do
  local emote=make("TextButton",gui,{Name="MatchEmote",Text="",Visible=false,AutoButtonColor=false})
  MatchHUD.register(player:WaitForChild("PlayerGui"),emote,40,nil)
  local function refreshEmote()
   local phase=sessionFolder and sessionFolder:GetAttribute("RoundPhase")
   local lang=player:GetAttribute("SpyLanguage")
   emote:SetAttribute("SpyUserText",true)
   emote.Text=lang=="en"and"Greeting"or lang=="zh"and"打招呼"or"Приветствие"
   emote.Visible=player:GetAttribute("SpyEquippedEmote")=="wave"and player:GetAttribute("SpyPhoneActive")~=true
    and (phase=="Discuss"or phase=="Result")and gui.Enabled and not blackout.Visible
  end
  emote.Activated:Connect(function()actionEvent:FireServer("Emote")end)
  for _,key in ipairs({"SpyEquippedEmote","SpyPhoneActive","SpyLanguage"})do player:GetAttributeChangedSignal(key):Connect(refreshEmote)end
  if sessionFolder then sessionFolder:GetAttributeChangedSignal("RoundPhase"):Connect(refreshEmote)end
  gui:GetPropertyChangedSignal("Enabled"):Connect(refreshEmote)
  blackout:GetPropertyChangedSignal("Visible"):Connect(refreshEmote);refreshEmote()
 end
-- MATCH_EMOTE_UI_END
-- QUESTION_UI_BEGIN
do
 local G=matchUI.guide
 if G then
  local copies={open={'Задать вопрос','Ask a question','提出问题'},title={'Вопрос за столом','Table question','桌边提问'},target={'Кому?','Who?','问谁？'},prompt={'Что спросить?','What to ask?','问什么？'},finish={'Ответ закончен','Answer finished','回答完毕'},used={'Вопрос задан','Question used','已提问'},busy={'Игрок отвечает','Player is answering','玩家正在回答'},wait={'Отправляем…','Sending…','正在发送…'},failed={'Вопрос недоступен. Попробуй ещё раз.','Question unavailable. Try again.','问题暂不可用，请重试。'},timeout={'Нет ответа сервера. Повтори вопрос.','No server response. Try again.','服务器未响应，请重试。'}}
  local function text(k)local v=copies[k];local l=player:GetAttribute('SpyLanguage');return v[l=='en'and 2 or l=='zh'and 3 or 1]end
  local qGui=make('ScreenGui',player:WaitForChild('PlayerGui'),{Name='MatchQuestionUI',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=315,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
  pcall(function()qGui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end)
  local veil=make('Frame',qGui,{Name='QuestionVeil',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.55,Visible=false,Active=true})
  local panel=make('Frame',veil,{Name='QuestionPanel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(446,420),BackgroundColor3=COLORS.Panel,BackgroundTransparency=.10,BorderSizePixel=0})
  corner(panel,3);stroke(panel,COLORS.BrassDark,.78,1)
  make('Frame',panel,{Name='QuestionRule',Position=UDim2.fromOffset(16,54),Size=UDim2.new(1,-32,0,1),BackgroundColor3=COLORS.BrassDark,BackgroundTransparency=.55,BorderSizePixel=0})
  local title=label(panel,{Name='QuestionTitle',Position=UDim2.fromOffset(16,12),Size=UDim2.new(1,-80,0,36),TextSize=28,Font=Enum.Font.Garamond,TextColor3=COLORS.Ivory})
  title:SetAttribute('SpyUserText',true)
  local close=make('TextButton',panel,{Name='CloseQuestion',Position=UDim2.new(1,-60,0,10),Size=UDim2.fromOffset(44,44),Text='×',TextSize=24,Font=Enum.Font.BuilderSansBold,BackgroundColor3=COLORS.Panel3,TextColor3=COLORS.Ivory,AutoButtonColor=false});corner(close,12)
  local list=make('ScrollingFrame',panel,{Name='QuestionChoices',Position=UDim2.fromOffset(16,62),Size=UDim2.new(1,-32,1,-106),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=COLORS.Brass,CanvasSize=UDim2.new()})
  local status=label(panel,{Name='QuestionStatus',Position=UDim2.new(0,16,1,-38),Size=UDim2.new(1,-32,0,30),TextSize=14,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.IvorySoft,TextWrapped=true});status:SetAttribute('SpyUserText',true)
  local launch=make('TextButton',gui,{Name='AskQuestion',Visible=false,Text='',AutoButtonColor=false})
  MatchHUD.register(player:WaitForChild('PlayerGui'),launch,20,nil)
  local selected,pending,serial=nil,false,0
  local connections={}
  local function allowed()
   return currentState and currentState.phase=='Discuss'and currentState.discussion and not blackout.Visible and gui.Enabled
    and player:GetAttribute('SpyPhoneActive')~=true and player:GetAttribute('SpyMatchIntroActive')~=true
    and player:GetAttribute('SpyCharacterMenuOpen')~=true
  end
  local function fit()
   local v=qGui.AbsoluteSize;if v.X<100 or v.Y<100 then v=camera.ViewportSize end
   panel.Size=UDim2.fromOffset(math.min(446,math.max(220,v.X-24)),math.min(420,math.max(170,v.Y-24)))
  end
  local function hide()veil.Visible=false;selected=nil;fit()end
  local function send(kind,prompt)
   if pending or not allowed()then return end
   local d=currentState.discussion;serial+=1;local token=serial;pending=true;status.Text=text('wait')
   actionEvent:FireServer('Question',{kind=kind,target=selected,prompt=prompt,id=d.active and d.active.id,token=d.token,requestId=token})
   task.delay(4,function()if pending and serial==token and qGui.Parent then pending=false;status.Text=text('timeout');matchUI.refreshQuestion()end end)
  end
  local function button(name,value,y,fn,on)
   local b=make('TextButton',list,{Name=name,Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,-4,0,48),Text=value,TextSize=16,TextWrapped=true,Font=Enum.Font.BuilderSansBold,TextColor3=on and COLORS.Ink or COLORS.Ivory,BackgroundColor3=on and COLORS.Brass or COLORS.Panel3,AutoButtonColor=false,Active=not pending})
   b:SetAttribute('SpyUserText',true);corner(b,12);b.Activated:Connect(function()if b.Active then fn()end end);return b
  end
  function matchUI.refreshQuestion()
   if not qGui.Parent then return end
   title.Text=text('title');launch:SetAttribute('SpyUserText',true);launch.Visible=allowed()==true
   if not launch.Visible then pending=false;serial+=1;hide();return end
   local d=currentState.discussion;local active=d.active
   local spent=table.find(d.used or{},player.UserId)~=nil
   local finish=active and active.target==player.UserId
   launch.Text=text(finish and'finish'or active and'busy'or spent and'used'or'open')
   launch.Active=not pending and(finish or not active and not spent)or false
   if active or spent then hide()end
   if not veil.Visible then return end
   fit();for _,n in ipairs(list:GetChildren())do n:Destroy()end
   local y=0
   local function caption(name,key)
    local n=label(list,{Name=name,Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,-4,0,24),Text=text(key),TextSize=16,Font=Enum.Font.BuilderSansBold,TextColor3=COLORS.IvorySoft});n:SetAttribute('SpyUserText',true);y+=30
   end
   if selected then
    local chosen
    for _,p in ipairs(currentState.players or{})do if p.userId==selected and p.connected~=false then chosen=p end end
    if not chosen then selected=nil;matchUI.refreshQuestion();return end
    button('ChangeQuestionTarget','‹  '..(chosen.displayName or chosen.name or tostring(selected)),y,function()selected=nil;matchUI.refreshQuestion()end,true);y+=56
    caption('QuestionPromptHeading','prompt')
    for _,key in ipairs({'reason','detail','odd'})do local prompt=key;button('QuestionPrompt_'..key,G.questionText(player:GetAttribute('SpyLanguage')or'ru',key),y,function()send('ask',prompt);matchUI.refreshQuestion()end,false);y+=56 end
   else
    caption('QuestionTargetHeading','target')
    for _,p in ipairs(currentState.players or{})do if p.userId~=player.UserId and p.connected~=false then
     local id=p.userId;button('QuestionTarget_'..id,p.displayName or p.name or tostring(id),y,function()selected=id;matchUI.refreshQuestion()end,false);y+=56
    end end
   end
   list.CanvasSize=UDim2.fromOffset(0,y+8)
  end
  local function keyOpen()
   if not launch.Visible or not launch.Active then return end
   local a=currentState.discussion.active
   if a and a.target==player.UserId then send('finish');matchUI.refreshQuestion()else selected=nil;status.Text='';veil.Visible=true;matchUI.refreshQuestion()end
  end
  launch.Activated:Connect(keyOpen)
  close.Activated:Connect(hide)
  local listened={}
  local function listen(ack)
   if ack.Name~='QuestionAck'or not ack:IsA('RemoteEvent')or listened[ack]then return end
   listened[ack]=true;connections[#connections+1]=ack.OnClientEvent:Connect(function(d)
    if type(d)~='table'or d.requestId~=serial or not pending then return end
    pending=false
    if d.ok then status.Text='';hide()else status.Text=text('failed')end
    matchUI.refreshQuestion()
   end)
  end
  local ack=remotes:FindFirstChild('QuestionAck');if ack then listen(ack)end
  connections[#connections+1]=remotes.ChildAdded:Connect(listen)
  connections[#connections+1]=UserInputService.InputBegan:Connect(function(input,processed)
   if not processed and input.KeyCode==Enum.KeyCode.Q and not UserInputService:GetFocusedTextBox()then keyOpen()end
  end)
  for _,key in ipairs({'SpyLanguage','SpyPhoneActive','SpyMatchIntroActive','SpyCharacterMenuOpen'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(matchUI.refreshQuestion)end
  connections[#connections+1]=blackout:GetPropertyChangedSignal('Visible'):Connect(matchUI.refreshQuestion)
  connections[#connections+1]=gui:GetPropertyChangedSignal('Enabled'):Connect(matchUI.refreshQuestion)
  connections[#connections+1]=qGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit)
  qGui.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end end)
  gui.Destroying:Connect(function()qGui:Destroy()end)
  matchUI.refreshQuestion()
 end
end
-- QUESTION_UI_END

local function showControls(visible)
	matchUI.controlsShown=visible
	matchUI.controls.Visible=visible and player:GetAttribute("SpyMatchChatOpen")~=true and player:GetAttribute('SpyCharacterMenuOpen')~=true
	tween(
		matchUI.controls,
		0.18,
		{
			GroupTransparency = visible and 0 or 1,
		}
	)
end

---------------------------------------------------------------------
-- TOPIC UI
---------------------------------------------------------------------

matchUI.topicRoot =
	make(
		"CanvasGroup",
		gui,
		{
            Name="TopicPanel",
			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.fromScale(0.5, 0.56),

			Size = UDim2.fromOffset(690, 300),

			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.07,

			BorderSizePixel = 0,

			GroupTransparency = 1,

			Visible = false,

			ZIndex = 180,
		}
	)

corner(matchUI.topicRoot, 3)
stroke(matchUI.topicRoot, COLORS.BrassDark, 0.52, 1)

make(
	"Frame",
	matchUI.topicRoot,
	{
		Size = UDim2.new(1, 0, 0, 1),

		BackgroundColor3 = COLORS.Brass,
		BackgroundTransparency = 0.18,

		BorderSizePixel = 0,

		ZIndex = 181,
	}
)

matchUI.topicMeta=label(
	matchUI.topicRoot,
	{
        Name="TopicMeta",
		Position = UDim2.fromOffset(28, 18),

		Size = UDim2.new(1, -56, 0, 20),

		Text = "SPY CLUB / ПЕРЕД РАЗДАЧЕЙ",
        TextXAlignment=Enum.TextXAlignment.Left,

		Font = Enum.Font.BuilderSansMedium,
		TextSize = 11,

		TextColor3 = COLORS.Brass,

		ZIndex = 182,
	}
)

matchUI.topicHeading=label(
	matchUI.topicRoot,
	{
        Name="TopicHeading",
        TextXAlignment=Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(28, 39),

		Size = UDim2.new(1, -56, 0, 38),

		Text = "Выберите тему",

		Font = Enum.Font.Garamond,
		TextSize = 28,

		ZIndex = 182,
	}
)

matchUI.topicInstruction=label(
	matchUI.topicRoot,
	{
        Name="TopicInstruction",
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,
		Position = UDim2.fromOffset(28, 78),

		Size = UDim2.new(1, -56, 0, 26),

		Text = "Каждый игрок выбирает один вариант.",

		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,

		TextColor3 = COLORS.Muted,

		ZIndex = 182,
	}
)

matchUI.topicOptionsHolder =
	make(
		"ScrollingFrame",
		matchUI.topicRoot,
		{
			Name="TopicChoices",
            Position = UDim2.fromOffset(25, 108),

			Size = UDim2.new(1, -50, 1, -164),

			BackgroundTransparency = 1,
            BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,

			ZIndex = 182,
		}
	)

matchUI.topicLayout=make(
	"UIGridLayout",
	matchUI.topicOptionsHolder,
	{
		CellSize = UDim2.new(0.5, -6, 0, 54),
		CellPadding = UDim2.fromOffset(12, 10),

		FillDirectionMaxCells = 2,

		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,

		SortOrder = Enum.SortOrder.LayoutOrder,
	}
)

matchUI.topicStatus =
	label(
		matchUI.topicRoot,
		{
			AnchorPoint = Vector2.new(0.5, 1),

			Position = UDim2.new(0.5, 0, 1, -16),

			Size = UDim2.new(1, -50, 0, 28),

			Text = "",

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 12,

			TextColor3 = COLORS.IvorySoft,

			ZIndex = 182,
		}
	)

---------------------------------------------------------------------
-- CHOSEN TOPIC
---------------------------------------------------------------------

matchUI.chosenView =
	make(
		"CanvasGroup",
		matchUI.topicRoot,
		{
            Name="ChosenTheme",
			Position = UDim2.fromOffset(25, 112),

			Size = UDim2.new(1, -50, 0, 135),

			BackgroundTransparency = 1,

			GroupTransparency = 1,

			Visible = false,

			ZIndex = 185,
		}
	)

label(
	matchUI.chosenView,
	{
		Size = UDim2.new(1, 0, 0, 24),

		Text = "ТЕМА ЭТОЙ ПАРТИИ",

		Font = Enum.Font.BuilderSansMedium,
		TextSize = 11,

		TextColor3 = COLORS.Brass,

		ZIndex = 186,
	}
)

matchUI.chosenTitle =
	label(
		matchUI.chosenView,
		{
            Name="ChosenThemeTitle",
			Position = UDim2.fromOffset(0, 27),

			Size = UDim2.new(1, 0, 0, 58),

			Text = "",

			Font = Enum.Font.Garamond,
			TextSize = 32,

			TextColor3 = COLORS.Ivory,

			TextWrapped = true,

			ZIndex = 186,
		}
	)

make(
	"Frame",
	matchUI.chosenView,
	{
		AnchorPoint = Vector2.new(0.5, 0),

		Position = UDim2.new(0.5, 0, 0, 91),

		Size = UDim2.fromOffset(64, 1),

		BackgroundColor3 = COLORS.Brass,

		BorderSizePixel = 0,

		ZIndex = 186,
	}
)

label(
	matchUI.chosenView,
	{
		Position = UDim2.fromOffset(0, 99),

		Size = UDim2.new(1, 0, 0, 28),

		Text = "Карты уже готовятся.",

		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,

		TextColor3 = COLORS.Muted,

		ZIndex = 186,
	}
)

matchUI.topicTimer=label(matchUI.topicRoot,{
 Name="TopicTimer",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-25,0,14),Size=UDim2.fromOffset(84,30),
 Text="",TextSize=22,Font=Enum.Font.Garamond,ZIndex=186,
})

local topicButtons = {}
local selectedTopicId = nil
local topicVoteSubmitted = false

local function clearTopicButtons()
	for _, button in ipairs(topicButtons) do
		if button and button.Parent then
			button:Destroy()
		end
	end

	table.clear(topicButtons)
end

local function hideTopicVote()
	if not matchUI.topicRoot.Visible then
		return
	end

	local animation =
		tween(
			matchUI.topicRoot,
			0.18,
			{
				GroupTransparency = 1,
			}
		)

	animation.Completed:Once(function()
		matchUI.topicRoot.Visible = false

		matchUI.chosenView.Visible = false
		matchUI.chosenView.GroupTransparency = 1

		matchUI.topicOptionsHolder.Visible = true
		matchUI.topicStatus.Visible = not matchUI.topicCompact
	end)
end

local function updateTopicVote(state)
	matchUI.topicRoot.Visible = true
	matchUI.topicRoot.GroupTransparency = 0

	matchUI.topicOptionsHolder.Visible = true
	matchUI.topicStatus.Visible = not matchUI.topicCompact

	matchUI.chosenView.Visible = false

	clearTopicButtons()

	for index, option in ipairs(state.topicOptions or {}) do
		local button =
			make(
				"TextButton",
				matchUI.topicOptionsHolder,
				{
					Name="TopicChoice",
                    LayoutOrder = index,

					BackgroundColor3 = COLORS.Panel2,

					BorderSizePixel = 0,

					AutoButtonColor = false,

					Text = "",

					ZIndex = 183,
				}
			)

		button:SetAttribute("ThemeId", option.id)

		corner(button, 4)

		local outline =
			stroke(
				button,
				COLORS.BrassDark,
				0.72,
				1
			)

		local accent =
			make(
				"Frame",
				button,
				{
					Size = UDim2.new(0, 2, 1, -14),

					Position = UDim2.fromOffset(7, 7),

					BackgroundColor3 = COLORS.Brass,
					BackgroundTransparency = 0.52,

					BorderSizePixel = 0,

					ZIndex = 184,
				}
			)

		local title =
			label(
				button,
				{
					Name="ThemeTitle",
                    Position = UDim2.fromOffset(20, 0),

					Size = UDim2.new(1, -75, 1, 0),

					Text = tostring(option.title or "Тема"),

					Font = Enum.Font.Garamond,
					TextSize = 23,
                    TextTruncate=Enum.TextTruncate.AtEnd,

					TextColor3 = COLORS.Ivory,

					TextXAlignment = Enum.TextXAlignment.Left,

					ZIndex = 184,
				}
			)

		local votes =
			label(
				button,
				{
					Name="ThemeVotes",
                    AnchorPoint = Vector2.new(1, 0.5),

					Position = UDim2.new(1, -15, 0.5, 0),

					Size = UDim2.fromOffset(40, 28),

					Text = tostring(option.votes or 0),

					Font = Enum.Font.BuilderSansMedium,
					TextSize = 15,

					TextColor3 = COLORS.Brass,

					ZIndex = 184,
				}
			)

		if selectedTopicId == option.id then
			button.BackgroundColor3 = COLORS.Panel3
			outline.Transparency = 0.15
			accent.BackgroundTransparency = 0

			title.TextColor3 = COLORS.Ivory
			votes.TextColor3 = COLORS.Ivory
		end

		button.MouseEnter:Connect(function()
			if topicVoteSubmitted then
				return
			end

			if selectedTopicId == option.id then
				return
			end

			tween(
				button,
				0.12,
				{
					BackgroundColor3 = COLORS.Panel3,
				},
				Enum.EasingStyle.Quad
			)
		end)

		button.MouseLeave:Connect(function()
			if topicVoteSubmitted then
				return
			end

			if selectedTopicId == option.id then
				return
			end

			tween(
				button,
				0.12,
				{
					BackgroundColor3 = COLORS.Panel2,
				},
				Enum.EasingStyle.Quad
			)
		end)

		button.Activated:Connect(function()
			if topicVoteSubmitted then
				return
			end

			if not option.id then
				return
			end

			topicVoteSubmitted = true
			selectedTopicId = option.id

			for _, other in ipairs(topicButtons) do
				local otherId =
					other:GetAttribute("ThemeId")

				local otherStroke =
					other:FindFirstChildOfClass("UIStroke")

				if otherId == selectedTopicId then
					other.BackgroundColor3 = COLORS.Panel3

					if otherStroke then
						otherStroke.Transparency = 0.15
					end
				else
					other.BackgroundColor3 = COLORS.Panel2
				end
			end

			matchUI.topicStatus.Text = "Голос принят · ждём остальных"

			actionEvent:FireServer(
				"TopicVote",
				option.id
			)
		end)

		table.insert(topicButtons, button)
	end

	local voted = tonumber(state.votedCount) or 0
	local total = tonumber(state.totalPlayers) or #(state.players or {})

	if topicVoteSubmitted then
		matchUI.topicStatus.Text =
			"Голос принят  ·  "
			.. tostring(voted)
			.. "/"
			.. tostring(total)
			.. " проголосовали"
	else
		matchUI.topicStatus.Text =
			tostring(voted)
			.. "/"
			.. tostring(total)
			.. " проголосовали"
	end
end

local function showChosenTopic(state)
	matchUI.topicRoot.Visible = true
	matchUI.topicRoot.GroupTransparency = 0

	matchUI.topicOptionsHolder.Visible = false
	matchUI.topicStatus.Visible = false

	matchUI.chosenView.Visible = true
	matchUI.chosenView.GroupTransparency = 1

	local selected = state.selectedTheme or {}

	matchUI.chosenTitle.Text =
		tostring(
			selected.title
			or "Тема выбрана"
		)

	tween(
		matchUI.chosenView,
		0.28,
		{
			GroupTransparency = 0,
		},
		Enum.EasingStyle.Quint
	)
end

---------------------------------------------------------------------
-- CHAT UI
---------------------------------------------------------------------

matchUI.chatFrame =
	make(
		"CanvasGroup",
		gui,
		{
			AnchorPoint = Vector2.new(0, 1),

			Position = UDim2.new(0, 22, 1, -54),

			Size = UDim2.fromOffset(365, 190),

			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.13,

			BorderSizePixel = 0,

			GroupTransparency = 1,

			Visible = false,

			ZIndex = 160,
		}
	)

corner(matchUI.chatFrame, 5)
stroke(matchUI.chatFrame, COLORS.BrassDark, 0.68, 1)

make(
	"Frame",
	matchUI.chatFrame,
	{
		Size = UDim2.new(1, 0, 0, 1),

		BackgroundColor3 = COLORS.Brass,
		BackgroundTransparency = 0.20,

		BorderSizePixel = 0,

		ZIndex = 161,
	}
)

label(
	matchUI.chatFrame,
	{
		Position = UDim2.fromOffset(14, 8),

		Size = UDim2.new(1, -54, 0, 26),

		Text = "РАЗГОВОР ЗА СТОЛОМ",

		Font = Enum.Font.BuilderSansMedium,
		TextSize = 12,

		TextColor3 = COLORS.Brass,

		TextXAlignment = Enum.TextXAlignment.Left,

		ZIndex = 162,
	}
)

matchUI.chatCollapse =
	make(
		"TextButton",
		matchUI.chatFrame,
		{
			AnchorPoint = Vector2.new(1, 0),

			Position = UDim2.new(1, -7, 0, 5),

			Size = UDim2.fromOffset(30, 30),

			BackgroundTransparency = 1,

			BorderSizePixel = 0,

			AutoButtonColor = false,

			Text = "—",

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 18,

			TextColor3 = COLORS.IvorySoft,

			ZIndex = 164,
		}
	)

matchUI.chatMessages =
	make(
		"ScrollingFrame",
		matchUI.chatFrame,
		{
			Position = UDim2.fromOffset(13, 38),

			Size = UDim2.new(1, -26, 1, -87),

			BackgroundTransparency = 1,

			BorderSizePixel = 0,

			CanvasSize = UDim2.fromOffset(0, 0),

			AutomaticCanvasSize = Enum.AutomaticSize.Y,

			ScrollBarThickness = 2,

			ScrollBarImageColor3 = COLORS.BrassDark,

			ZIndex = 162,
		}
	)

make(
	"UIListLayout",
	matchUI.chatMessages,
	{
		Padding = UDim.new(0, 7),

		SortOrder = Enum.SortOrder.LayoutOrder,
	}
)

matchUI.chatMessages.Name="ChatLog";matchUI.chatMessages:SetAttribute("SpyUserText",true)

matchUI.chatInputBar =
	make(
		"Frame",
		matchUI.chatFrame,
		{
			Position = UDim2.new(0, 13, 1, -40),

			Size = UDim2.new(1, -26, 0, 30),

			BackgroundColor3 = COLORS.Panel2,
			BackgroundTransparency = 0.03,

			BorderSizePixel = 0,

			ZIndex = 162,
		}
	)

corner(matchUI.chatInputBar, 3)

matchUI.chatInput =
	make(
		"TextBox",
		matchUI.chatInputBar,
		{
			Position = UDim2.fromOffset(9, 0),

			Size = UDim2.new(1, -44, 1, 0),

			BackgroundTransparency = 1,

			BorderSizePixel = 0,

			Text = "",

			PlaceholderText = "Обсудить подозрения…",
			PlaceholderColor3 = COLORS.Muted,

			ClearTextOnFocus = false,

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 14,

			TextColor3 = COLORS.Ivory,

			TextXAlignment = Enum.TextXAlignment.Left,

			ZIndex = 163,
		}
	)

matchUI.chatSend =
	make(
		"TextButton",
		matchUI.chatInputBar,
		{
			AnchorPoint = Vector2.new(1, 0.5),

			Position = UDim2.new(1, -4, 0.5, 0),

			Size = UDim2.fromOffset(27, 24),

			BackgroundColor3 = COLORS.Brass,

			BorderSizePixel = 0,

			AutoButtonColor = false,

			Text = "↵",

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 14,

			TextColor3 = COLORS.Ink,

			ZIndex = 164,
		}
	)

corner(matchUI.chatSend, 3)

matchUI.collapsedChat =
	make(
		"TextButton",
		gui,
		{
			AnchorPoint = Vector2.new(0, 1),

			Position = UDim2.new(0, 22, 1, -54),

			Size = UDim2.fromOffset(118, 32),

			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.13,

			BorderSizePixel = 0,

			AutoButtonColor = false,

			Text = "РАЗГОВОР   /",

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 10,

			TextColor3 = COLORS.IvorySoft,

			Visible = false,

			ZIndex = 159,
		}
	)

corner(matchUI.collapsedChat, 3)
stroke(matchUI.collapsedChat, COLORS.BrassDark, 0.70, 1)

---------------------------------------------------------------------
-- VOTE UI
---------------------------------------------------------------------

matchUI.voteBackdrop=make("CanvasGroup",gui,{
 Name="BallotOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=COLORS.Black,
 BackgroundTransparency=.45,BorderSizePixel=0,GroupTransparency=1,Visible=false,ZIndex=200,
})
matchUI.voteRoot=make("Frame",matchUI.voteBackdrop,{
 Name="BallotPanel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.51),
 Size=UDim2.fromOffset(880,560),BackgroundColor3=COLORS.Panel,BackgroundTransparency=.02,BorderSizePixel=0,ZIndex=201,
})
corner(matchUI.voteRoot,3);stroke(matchUI.voteRoot,COLORS.BrassDark,.5,1)
make("Frame",matchUI.voteRoot,{Name="BallotRule",Position=UDim2.fromOffset(28,0),Size=UDim2.new(1,-56,0,1),
 BackgroundColor3=COLORS.Brass,BackgroundTransparency=.64,BorderSizePixel=0,ZIndex=202})
matchUI.voteMeta=label(matchUI.voteRoot,{
 Name="BallotMeta",Position=UDim2.fromOffset(28,20),Size=UDim2.new(1,-166,0,18),
 Text="ЗАКРЫТЫЙ БЮЛЛЕТЕНЬ",TextSize=11,Font=Enum.Font.BuilderSansMedium,
 TextColor3=COLORS.IvorySoft,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=202,
})
matchUI.voteHeading=label(matchUI.voteRoot,{
 Name="BallotHeading",Position=UDim2.fromOffset(28,39),Size=UDim2.new(1,-166,0,44),
 Text="Кто здесь шпион?",TextSize=40,Font=Enum.Font.Garamond,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=202,
})
matchUI.voteTimerLabel=label(matchUI.voteRoot,{
 Name="BallotTimerLabel",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-28,0,20),Size=UDim2.fromOffset(94,18),
 Text="ОСТАЛОСЬ",TextSize=10,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.IvorySoft,
 TextXAlignment=Enum.TextXAlignment.Right,ZIndex=202,
})
matchUI.voteTimer=label(matchUI.voteRoot,{
 Name="BallotTimer",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-28,0,40),Size=UDim2.fromOffset(94,42),
 Text="",TextSize=36,Font=Enum.Font.Garamond,TextColor3=COLORS.Ivory,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=202,
})
matchUI.voteInstruction=label(matchUI.voteRoot,{
 Name="BallotInstruction",Position=UDim2.fromOffset(28,84),Size=UDim2.new(1,-56,0,24),
 Text="Выбери подозреваемого. Твой голос будет показан после решения стола.",TextSize=14,
 TextColor3=COLORS.IvorySoft,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=202,
})
matchUI.votePlayers=make("ScrollingFrame",matchUI.voteRoot,{
 Name="Suspects",Position=UDim2.fromOffset(28,116),Size=UDim2.new(1,-56,1,-202),BackgroundTransparency=1,
 BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=COLORS.IvorySoft,
 CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=202,
})
matchUI.voteLayout=make("UIGridLayout",matchUI.votePlayers,{
 SortOrder=Enum.SortOrder.LayoutOrder,CellSize=UDim2.fromOffset(266,242),CellPadding=UDim2.fromOffset(12,12),
 FillDirectionMaxCells=3,HorizontalAlignment=Enum.HorizontalAlignment.Center,
})
matchUI.voteFooterRule=make("Frame",matchUI.voteRoot,{
 Name="BallotFooterRule",Position=UDim2.new(0,28,1,-74),Size=UDim2.new(1,-56,0,1),
 BackgroundColor3=COLORS.BrassDark,BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=202,
})
matchUI.extraRoundButton=make("TextButton",matchUI.voteRoot,{
 Name="AnotherClueRound",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-70),
 Size=UDim2.new(1,-44,0,44),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,
 AutoButtonColor=false,Text="",Visible=true,ZIndex=203,
})
corner(matchUI.extraRoundButton,4)
matchUI.extraRoundStroke=stroke(matchUI.extraRoundButton,COLORS.BrassDark,.65,1)
label(matchUI.extraRoundButton,{
 Name="ExtraRoundTitle",Position=UDim2.fromOffset(16,3),Size=UDim2.new(1,-32,0,22),Text="Ещё круг подсказок",
 Font=Enum.Font.BuilderSansMedium,TextSize=14,TextColor3=COLORS.Ivory,ZIndex=204,
})
label(matchUI.extraRoundButton,{
 Name="ExtraRoundDetail",Position=UDim2.fromOffset(16,24),Size=UDim2.new(1,-32,0,16),Text="По решению большинства",
 Font=Enum.Font.BuilderSansMedium,TextSize=11,TextColor3=COLORS.IvorySoft,ZIndex=204,
})
matchUI.confirmVote=make("TextButton",matchUI.voteRoot,{
 Name="SubmitBallot",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-16),
 Size=UDim2.new(1,-44,0,44),BackgroundColor3=COLORS.Brass,BackgroundTransparency=.65,
 BorderSizePixel=0,AutoButtonColor=false,Active=false,Text="Выбери подозреваемого",
 Font=Enum.Font.BuilderSansBold,TextSize=16,TextTruncate=Enum.TextTruncate.AtEnd,TextColor3=COLORS.Ivory,ZIndex=203,
})
corner(matchUI.confirmVote,4)

---------------------------------------------------------------------
-- RESULT
---------------------------------------------------------------------

matchUI.resultRoot=make("CanvasGroup",gui,{
 Name="MatchResultPanel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.48),
 Size=UDim2.fromOffset(620,470),BackgroundColor3=COLORS.Panel,BackgroundTransparency=.10,
 BorderSizePixel=0,GroupTransparency=1,Visible=false,ZIndex=300,
})
corner(matchUI.resultRoot,3)
stroke(matchUI.resultRoot,COLORS.BrassDark,.65,1)
matchUI.resultRule=make("Frame",matchUI.resultRoot,{Name="OutcomeAccent",Size=UDim2.new(1,-44,0,2),
 Position=UDim2.fromOffset(22,0),BorderSizePixel=0,BackgroundColor3=COLORS.Brass,ZIndex=301})
matchUI.resultContent=make("ScrollingFrame",matchUI.resultRoot,{
 -- The separate return/rematch owner pins its 52px footer 18px above the edge.
 Name="ResultContent",Size=UDim2.new(1,0,1,-78),ClipsDescendants=true,BackgroundTransparency=1,BorderSizePixel=0,
 CanvasSize=UDim2.fromOffset(0,450),ScrollBarThickness=3,ScrollBarImageColor3=COLORS.Brass,ZIndex=301,
})
matchUI.resultMeta=label(matchUI.resultContent,{
 Name="ResultMeta",
 Position=UDim2.fromOffset(22,18),Size=UDim2.new(1,-44,0,22),Text="",
 TextSize=13,Font=Enum.Font.BuilderSansBold,TextColor3=COLORS.Brass,ZIndex=301,
 TextTruncate=Enum.TextTruncate.AtEnd,
})
matchUI.resultTitle=label(matchUI.resultContent,{
 Name="ResultHeading",
 Position=UDim2.fromOffset(22,44),Size=UDim2.new(1,-44,0,62),Text="",
 TextSize=32,Font=Enum.Font.Garamond,TextColor3=COLORS.Ivory,TextWrapped=true,ZIndex=301,
})
matchUI.resultOutcome=label(matchUI.resultContent,{
 Name="ResultOutcome",
 Position=UDim2.fromOffset(22,108),Size=UDim2.new(1,-44,0,24),Text="",
 TextSize=18,Font=Enum.Font.BuilderSansBold,TextColor3=COLORS.Brass,ZIndex=301,
})
matchUI.resultDescription=label(matchUI.resultContent,{
 Name="ResultDescription",
 Position=UDim2.fromOffset(22,140),Size=UDim2.new(1,-44,0,42),Text="",
 TextSize=14,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.IvorySoft,TextWrapped=true,ZIndex=301,
})
matchUI.resultDescription:SetAttribute("SpyUserText",true)
matchUI.resultReveal=label(matchUI.resultContent,{
 Name="PublicReveal",
 Position=UDim2.fromOffset(22,190),Size=UDim2.new(1,-44,0,66),Text="",
 TextSize=14,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.IvorySoft,TextWrapped=true,ZIndex=301,
})
matchUI.resultReveal:SetAttribute("SpyUserText",true)
matchUI.resultReward=label(matchUI.resultContent,{
 Name="RewardStatus",Position=UDim2.fromOffset(22,264),Size=UDim2.new(1,-44,0,36),Text="",
 TextSize=15,Font=Enum.Font.BuilderSansBold,TextColor3=COLORS.Brass,TextWrapped=true,ZIndex=301,
})
matchUI.resultStats=label(matchUI.resultContent,{
 Name="SavedStats",Position=UDim2.fromOffset(22,304),Size=UDim2.new(1,-44,0,22),Text="",
 TextSize=13,Font=Enum.Font.BuilderSansMedium,TextColor3=COLORS.IvorySoft,ZIndex=301,
})
for _,caption in ipairs({matchUI.resultMeta,matchUI.resultTitle,matchUI.resultOutcome,matchUI.resultDescription,matchUI.resultReveal,matchUI.resultReward,matchUI.resultStats})do
 caption.TextXAlignment=Enum.TextXAlignment.Left
end
matchUI.resultReveal.TextYAlignment=Enum.TextYAlignment.Top
matchUI.resultReveal.BackgroundColor3=COLORS.Panel3
matchUI.resultReveal.BackgroundTransparency=.45
matchUI.resultReveal.TextSize=14
corner(matchUI.resultReveal,3)
make("UIPadding",matchUI.resultReveal,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,9),PaddingBottom=UDim.new(0,9)})
matchUI.caseReviewButton=make("TextButton",matchUI.resultContent,{
 Name="CaseReview",Position=UDim2.fromOffset(22,346),Size=UDim2.new(1,-44,0,44),Visible=false,
 BackgroundColor3=COLORS.Panel3,BorderSizePixel=0,Text="",TextSize=16,Font=Enum.Font.BuilderSansBold,TextColor3=COLORS.Ivory,ZIndex=302,
})
corner(matchUI.caseReviewButton,6)
matchUI.caseReviewButton.Activated:Connect(function()local event=playerGui:FindFirstChild("SpyOpenCase");if event then event:Fire("review")end end)
-- Reflow panel widths, preserving legible text on phones and large monitors.
local function fitMatchPanels()
 local v=gui.AbsoluteSize
 if v.X<=0 or v.Y<=0 then v=camera.ViewportSize end
 local narrow=v.X<520
 local landscape=v.Y<420
 local layout=MatchHUD.currentMetrics(playerGui,v,UserInputService.TouchEnabled)
 matchUI.agentBadge.Visible=false
 local chatOpen=player:GetAttribute('SpyMatchChatOpen')==true
 local characterOpen=player:GetAttribute('SpyCharacterMenuOpen')==true
 local headerOnly=chatOpen and landscape or layout.phase.h<72
 local instructionY=headerOnly and 0 or landscape and 55 or 83
 local phaseHeight=headerOnly and math.min(64,layout.phase.h)or layout.phase.h
 local tinyHeader=phaseHeight<64
 matchUI.phaseRoot.Size=UDim2.fromOffset(layout.phase.w,phaseHeight)
 matchUI.phaseRoot.Position=UDim2.fromOffset(layout.phase.x,layout.phase.y)
 matchUI.phaseRoot.Visible=not characterOpen and player:GetAttribute('SpyMatchChatCompact')~=true
 matchUI.phaseTitle.TextSize=headerOnly and 20 or narrow and 26 or landscape and 26 or 32
 matchUI.phaseSubtitle.TextSize=narrow and 14 or landscape and 13 or 14
 matchUI.matchIdentity.Visible=not headerOnly and not landscape and not narrow
 matchUI.stageSequence.Visible=not headerOnly and not landscape
 matchUI.stageSequence.AnchorPoint=narrow and Vector2.new()or Vector2.new(1,0)
 matchUI.stageSequence.Position=narrow and UDim2.fromOffset(18,9)or UDim2.new(1,-18,0,9)
 matchUI.stageSequence.Size=UDim2.new(1,narrow and -112 or -148,0,14)
 matchUI.stageSequence.TextXAlignment=narrow and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
 matchUI.matchIdentity.Size=UDim2.fromOffset(100,14)
 matchUI.timerLabel.Visible=not headerOnly and not landscape and not narrow
 matchUI.clockDivider.Visible=not tinyHeader and not narrow
 matchUI.clockDivider.Position=UDim2.new(1,-(narrow and 94 or 118),0,landscape and 12 or 34)
 matchUI.clockDivider.Size=UDim2.fromOffset(1,landscape and 32 or 38)
 matchUI.instructionRule.Visible=not headerOnly
 matchUI.instructionRule.Position=UDim2.fromOffset(18,instructionY-5)
 matchUI.instructionSurface.Visible=not headerOnly
 matchUI.instructionSurface.BackgroundTransparency=1
 matchUI.instructionSurface.Position=UDim2.fromOffset(18,instructionY)
 matchUI.instructionSurface.Size=UDim2.new(1,-36,0,phaseHeight-instructionY-7)
 matchUI.phaseSubtitle.Position=UDim2.fromOffset(0,0)
 matchUI.phaseSubtitle.Size=UDim2.fromScale(1,1)
 matchUI.phaseSubtitle.TextYAlignment=Enum.TextYAlignment.Top
 local timerWidth=narrow and 64 or 84
 matchUI.timer.Position=UDim2.new(1,-18,0,tinyHeader and 6 or narrow and 8 or landscape and 12 or 42)
 matchUI.timer.Size=UDim2.fromOffset(timerWidth,tinyHeader and 28 or 36)
 matchUI.timer.TextSize=(headerOnly or narrow)and 28 or 34
 matchUI.timerLabel.Size=UDim2.fromOffset(timerWidth,13)
 matchUI.timer.TextTruncate=Enum.TextTruncate.None
 matchUI.phaseMeta.TextSize=narrow and 10 or 11
 local portraitSize=tinyHeader and 24 or headerOnly and 32 or 40
 matchUI.speakerPortrait.Size=UDim2.fromOffset(portraitSize,portraitSize)
 matchUI.speakerPortrait.Position=UDim2.fromOffset(18,tinyHeader and 10 or landscape and 9 or 32)
 local textX=matchUI.showSpeaker==true and(18+portraitSize+12)or 18
 matchUI.speakerPortrait.Visible=matchUI.showSpeaker==true
 matchUI.phaseMeta.Position=UDim2.fromOffset(textX,tinyHeader and 2 or landscape and 6 or 29)
 matchUI.phaseTitle.Position=UDim2.fromOffset(textX,tinyHeader and 20 or landscape and 22 or 44)
 matchUI.phaseMeta.Size=UDim2.new(1,-textX-timerWidth-48,0,14)
 matchUI.phaseTitle.Size=UDim2.new(1,narrow and not landscape and -textX-18 or -textX-timerWidth-48,0,tinyHeader and 22 or 32)
 for _,pip in ipairs(matchUI.turnPips)do pip.Visible=false end
 matchUI.controls.Size=UDim2.fromOffset(layout.controls.w,layout.controls.h)
 matchUI.controls.Position=UDim2.fromOffset(layout.controls.x,layout.controls.y)
 matchUI.controls.Visible=matchUI.controlsShown==true and not chatOpen and not characterOpen
 local resultPanel=MatchHUD.modal(v,620,470)
 matchUI.resultRoot.Size=UDim2.fromOffset(resultPanel.w,resultPanel.h)
 matchUI.resultRoot.Position=UDim2.fromOffset(resultPanel.x+resultPanel.w*.5,resultPanel.y+resultPanel.h*.5)
 matchUI.resultTitle.TextSize=narrow and 30 or 38
 local topicPanel=MatchHUD.modal(v,640,narrow and 440 or 328)
 matchUI.topicRoot.Size=UDim2.fromOffset(topicPanel.w,topicPanel.h)
 matchUI.topicRoot.Position=UDim2.fromOffset(topicPanel.x+topicPanel.w*.5,topicPanel.y+topicPanel.h*.5)
 matchUI.topicRoot.BackgroundColor3=COLORS.Panel
 local topicContent=MatchHUD.topic(topicPanel.h)
 matchUI.topicCompact=topicContent.compact
 matchUI.topicMeta.Visible=not topicContent.compact
 matchUI.topicInstruction.Visible=not topicContent.compact
 matchUI.topicHeading.Position=UDim2.fromOffset(topicContent.compact and 16 or 28,topicContent.compact and 4 or 39)
 matchUI.topicHeading.Size=UDim2.new(1,topicContent.compact and -124 or -144,0,topicContent.compact and 28 or 38)
 matchUI.topicHeading.TextSize=topicContent.compact and 24 or 34
 matchUI.topicOptionsHolder.Position=UDim2.fromOffset(topicContent.compact and 16 or 25,topicContent.choicesTop)
 matchUI.topicOptionsHolder.Size=UDim2.new(1,topicContent.compact and -32 or -50,0,topicContent.choicesHeight)
 matchUI.topicStatus.Visible=not topicContent.compact and not matchUI.chosenView.Visible
 matchUI.topicTimer.Position=UDim2.new(1,-18,0,topicContent.compact and 4 or 18)
 matchUI.chosenView.Position=UDim2.fromOffset(topicContent.compact and 16 or 25,topicContent.compact and 36 or 112)
 matchUI.chosenView.Size=UDim2.new(1,topicContent.compact and -32 or -50,0,topicContent.compact and math.max(24,topicPanel.h-44)or 135)
 matchUI.chosenTitle.Position=UDim2.fromOffset(0,topicContent.compact and 0 or 27)
 matchUI.chosenTitle.Size=topicContent.compact and UDim2.fromScale(1,1)or UDim2.new(1,0,0,58)
 matchUI.chosenTitle.TextSize=topicContent.compact and 26 or 36
 for _,object in ipairs(matchUI.chosenView:GetChildren())do
  if object:IsA('GuiObject')and object~=matchUI.chosenTitle then object.Visible=not topicContent.compact end
 end
 matchUI.topicLayout.FillDirectionMaxCells=narrow and 1 or 2
 matchUI.topicLayout.CellSize=narrow and UDim2.new(1,-4,0,54) or UDim2.new(.5,-6,0,54)
 local ballotPanel=MatchHUD.modal(v,880,560)
 local width,height=ballotPanel.w,ballotPanel.h
 matchUI.voteRoot.Size=UDim2.fromOffset(width,height)
 matchUI.voteRoot.Position=UDim2.fromOffset(ballotPanel.x+width*.5,ballotPanel.y+height*.5)
 local ballotContent=MatchHUD.ballot(height,width)
 local shortBallot=ballotContent.short
 local stacked=width<600
 local margin=stacked and 20 or 28
 local timerWidth=stacked and 76 or 94
 matchUI.voteMeta.Visible=not shortBallot
 matchUI.voteMeta.Position=UDim2.fromOffset(margin,18)
 matchUI.voteMeta.Size=UDim2.new(1,-margin*2-timerWidth-12,0,18)
 matchUI.voteHeading.Visible=not ballotContent.minimal
 matchUI.voteTimer.Visible=not ballotContent.minimal
 matchUI.voteHeading.Position=UDim2.fromOffset(margin,shortBallot and 3 or 38)
 matchUI.voteHeading.Size=UDim2.new(1,-margin*2-(stacked and not shortBallot and 0 or timerWidth+12),0,shortBallot and 32 or 42)
 matchUI.voteHeading.TextSize=shortBallot and(stacked and 20 or 28)or stacked and 29 or 40
 matchUI.voteTimerLabel.Visible=not shortBallot and not stacked
 matchUI.voteTimerLabel.Position=UDim2.new(1,-margin,0,18)
 matchUI.voteTimerLabel.Size=UDim2.fromOffset(timerWidth,18)
 matchUI.voteTimer.Position=UDim2.new(1,-margin,0,shortBallot and 3 or stacked and 8 or 38)
 matchUI.voteTimer.Size=UDim2.fromOffset(timerWidth,shortBallot and 32 or 42)
 matchUI.voteTimer.TextSize=stacked and 24 or shortBallot and 28 or 36
 matchUI.voteInstruction.Visible=not shortBallot
 matchUI.voteInstruction.Position=UDim2.fromOffset(margin,stacked and 79 or 84)
 matchUI.voteInstruction.Size=UDim2.new(1,-margin*2,0,stacked and 28 or 24)
 matchUI.voteInstruction.TextSize=stacked and 12 or 14
 matchUI.votePlayers.Position=UDim2.fromOffset(margin,ballotContent.choicesTop)
 matchUI.votePlayers.Size=UDim2.new(1,-margin*2,0,ballotContent.choicesHeight)
 local sideBySide=not stacked or shortBallot
 local extraVisible=matchUI.extraRoundButton.Visible
 local footerWidth=width-margin*2
 local extraWidth=sideBySide and math.floor((footerWidth-12)*.40)or footerWidth
 local confirmWidth=sideBySide and extraVisible and footerWidth-extraWidth-12 or footerWidth
 matchUI.extraRoundButton.AnchorPoint=Vector2.new(0,1)
 matchUI.extraRoundButton.Position=UDim2.new(0,margin,1,-ballotContent.extraBottom)
 matchUI.extraRoundButton.Size=UDim2.fromOffset(extraWidth,44)
 matchUI.confirmVote.AnchorPoint=Vector2.new(1,1)
 matchUI.confirmVote.Position=UDim2.new(1,-margin,1,-ballotContent.confirmBottom)
 matchUI.confirmVote.Size=UDim2.fromOffset(confirmWidth,44)
 matchUI.confirmVote.TextSize=stacked and 14 or 16
 matchUI.voteFooterRule.Position=UDim2.new(0,margin,0,ballotContent.choicesTop+ballotContent.choicesHeight+10)
 matchUI.voteFooterRule.Size=UDim2.new(1,-margin*2,0,1)
 matchUI.voteFooterRule.Visible=not shortBallot
 for _,caption in ipairs(matchUI.extraRoundButton:GetChildren())do
  if caption:IsA("TextLabel")then
   if caption.Name=="ExtraRoundDetail"then caption.Visible=not shortBallot
   else caption.Position=UDim2.fromOffset(shortBallot and 6 or 16,shortBallot and 11 or 3);caption.Size=UDim2.new(1,shortBallot and -12 or -32,0,22);caption.TextSize=shortBallot and 12 or 14 end
  end
 end
 local rowHeight=stacked and 84 or math.min(242,math.max(96,ballotContent.choicesHeight))
 local compact=not stacked and rowHeight<234
 local count=0
 for _,child in ipairs(matchUI.votePlayers:GetChildren())do if child:IsA("TextButton")then count+=1 end end
 local columns=stacked and 1 or math.min(width<780 and 2 or 3,math.max(1,count))
 local gap=stacked and 10 or 12
 local cellWidth=math.floor((width-margin*2-4-(columns-1)*gap)/columns)
 matchUI.voteLayout.FillDirectionMaxCells=columns
 matchUI.voteLayout.CellPadding=UDim2.fromOffset(gap,gap)
 matchUI.voteLayout.CellSize=UDim2.fromOffset(cellWidth,rowHeight)
 -- Every row must be reachable, including tables with more than three targets.
 local rows=math.ceil(count/columns)
 matchUI.votePlayers.CanvasSize=UDim2.fromOffset(0,rows*rowHeight+math.max(0,rows-1)*gap)
 for _,button in ipairs(matchUI.votePlayers:GetChildren()) do
    if button:IsA("TextButton") then
        local avatar=button:FindFirstChild("Portrait")
        local name=button:FindFirstChild("SuspectName")
        local seat=button:FindFirstChild("SeatLabel")
        local index=button:FindFirstChild("SeatIndex")
        local selected=button:FindFirstChild("SelectionMarker")
        local horizontal=stacked or compact
        local portraitSize=horizontal and 64 or math.min(144,cellWidth-18-72-16-8)
        avatar.AnchorPoint=Vector2.new()
        avatar.Position=UDim2.fromOffset(horizontal and 12 or 18,horizontal and 10 or 24)
        avatar.Size=UDim2.fromOffset(portraitSize,portraitSize)
        name.Position=UDim2.fromOffset(horizontal and 88 or 18,horizontal and 15 or 184)
        name.Size=UDim2.new(1,horizontal and -100 or -36,0,26)
        name.TextSize=stacked and 17 or 18
        name.TextXAlignment=Enum.TextXAlignment.Left
        seat.Position=UDim2.fromOffset(horizontal and 88 or 18,horizontal and 42 or 214)
        seat.Size=UDim2.new(1,horizontal and -100 or -36,0,18)
        seat.TextXAlignment=Enum.TextXAlignment.Left
        index.Visible=not horizontal
        selected.Position=UDim2.new(1,-12,0,horizontal and rowHeight-20 or 10)
        selected.Size=UDim2.fromOffset(90,14)
    end
 end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitMatchPanels)
matchUI.fitPanels=fitMatchPanels
for _,attribute in ipairs({'SpyMatchChatOpen','SpyMatchChatCompact','SpyCharacterMenuOpen'})do player:GetAttributeChangedSignal(attribute):Connect(fitMatchPanels)end
fitMatchPanels()

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

currentState = nil
local secretData = nil

local introStarted = false
local roleSequence = 0
local lastPhase = nil

local cards = {}
local cardsByUserId = {}

-- DEAL_TIMELINE_BEGIN
-- Pure timing policy: the server deadline, never a local replay, owns the deal.
local DealMotion = {}
function DealMotion.plan(count, phase, remaining, reduced)
	local budget = math.min(5.8, math.max(0, (remaining or 6.5) - 0.25))
	if count == 0 or phase ~= "Intro" or reduced or budget < 0.45 + count * 0.55 then
		return {instant = true, duration = 0, count = count}
	end
	return {instant = false, count = count, lead = 0.45, slot = (budget - 0.45) / count, duration = budget}
end
function DealMotion.sample(plan, elapsed)
	if plan.instant or elapsed >= plan.duration then return {stage = "done"} end
	if elapsed < plan.lead then return {stage = "wait", index = 1, grip = 0} end
	local step = (elapsed - plan.lead) / plan.slot
	local index = math.floor(step) + 1
	local t = step - math.floor(step)
	if t < 0.22 then
		return {stage = "reach", index = index, progress = t / 0.22, grip = t / 0.22, attached = false}
	elseif t < 0.52 then
		return {stage = "carry", index = index, progress = (t - 0.22) / 0.30, grip = 1, attached = true}
	end
	return {stage = "slide", index = index, progress = (t - 0.52) / 0.48, grip = 0, attached = false}
end
-- DEAL_TIMELINE_END

-- DEAL_LIFECYCLE_BEGIN
local dealer = nil
local dealerConnection = nil
local dealGeneration = 0

local function stopDealer(settle)
	dealGeneration += 1
	if dealerConnection then dealerConnection:Disconnect(); dealerConnection = nil end
	if dealer then dealer:Destroy(); dealer = nil end
	if settle then
		for _, data in ipairs(cards) do
			if data.part and data.part.Parent and data.tableCFrame then
				data.part.CFrame = data.tableCFrame
			end
		end
	end
end
-- DEAL_LIFECYCLE_END

local ownCard = nil

local cardMode = nil
local cardAnimating = false

local hintSent = false
local previousTurnId = nil

local voteButtons = {}

local selectedVoteValue = nil
local voteSubmitted = false

local chatRows = {}
local seenMessages = {}

local chatSessionStarted = false
local chatCollapsed = false

---------------------------------------------------------------------
-- CAMERA STATE
---------------------------------------------------------------------

local seatedCameraActive = false
local cursorReleased = false

local cameraBaseYaw = 0
local cameraYawOffset = 0
local cameraPitch = math.rad(-2)
matchUI.seatedView = "table"
matchUI.cameraDragging = false
matchUI.cameraTouch = nil
matchUI.cameraTouchPosition = nil

local CAMERA_YAW_LIMIT = math.rad(50)

local CAMERA_PITCH_MIN = math.rad(-19)
local CAMERA_PITCH_MAX = math.rad(23)

local CAMERA_SENSITIVITY = 0.0025

local cameraSequenceToken = 0
local activeCameraTween = nil
local cinematicGrade = nil
local cinematicFocus = nil

local function cancelCameraSequence()
	cameraSequenceToken += 1

	if activeCameraTween then
		activeCameraTween:Cancel()
		activeCameraTween = nil
	end
end

local function clearCinematicEffects()
	for _, name in ipairs({
		"SpyMatchCinematicGrade",
		"SpyMatchCinematicFocus",
	}) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	cinematicGrade = nil
	cinematicFocus = nil
end

local function beginCinematicGrade()
	player:SetAttribute('SpyMatchIntroActive',true)
	clearCinematicEffects()
	if player:GetAttribute("SpyEffects") == false then return end

	cinematicGrade = Instance.new("ColorCorrectionEffect")
	cinematicGrade.Name = "SpyMatchCinematicGrade"
	cinematicGrade.Brightness = 0
	cinematicGrade.Contrast = 0.035
	cinematicGrade.Saturation = 0
	cinematicGrade.TintColor = Color3.fromRGB(255, 255, 255)
	cinematicGrade.Parent = Lighting

	cinematicFocus = Instance.new("DepthOfFieldEffect")
	cinematicFocus.Name = "SpyMatchCinematicFocus"
	cinematicFocus.FocusDistance = 24
	cinematicFocus.InFocusRadius = 18
	cinematicFocus.NearIntensity = 0
	cinematicFocus.FarIntensity = 0
 cinematicFocus.Enabled=false
	cinematicFocus.Parent = Lighting

	tween(cinematicGrade, 0.55, {
		Brightness = 0,
		Contrast = 0.06,
		Saturation = -0.045,
	})
end

local function endCinematicGrade()
	player:SetAttribute('SpyMatchIntroActive',false)
	local grade = cinematicGrade
	local focus = cinematicFocus

	if grade then
		tween(grade, 0.28, {
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
		})
	end

	if focus then
		tween(focus, 0.28, {
			NearIntensity = 0,
			FarIntensity = 0,
		})
	end

	task.delay(0.32, function()
		if grade and grade.Parent then
			grade:Destroy()
		end
		if focus and focus.Parent then
			focus:Destroy()
		end
		if cinematicGrade == grade then
			cinematicGrade = nil
		end
		if cinematicFocus == focus then
			cinematicFocus = nil
		end
	end)
end

---------------------------------------------------------------------
-- CUTSCENE STATE
---------------------------------------------------------------------

local forceCharacterVisible = false

local armRig = nil
local armPose = nil

local cardFollowHand = false

---------------------------------------------------------------------
-- WORLD
---------------------------------------------------------------------

local function matchRoom()
	return workspace:FindFirstChild("SpyMatchRoom") or workspace
end

local function findTableSurface()
	local root = matchRoom()

	for _, objectName in ipairs({
		"CenterEmblem",
		"InnerFelt",
		"Felt",
		"TableTop",
		}) do
		local object = root:FindFirstChild(objectName, true)

		if object and object:IsA("BasePart") then
			return object
		end
	end

	return nil
end

local function tableCenter()
	local surface = findTableSurface()

	if surface then
		return surface.Position
	end

	return Vector3.new(0, 3, 0)
end

local function tableTopY()
	local surface = findTableSurface()

	if surface then
		-- The authored oval felt is a flattened Part rotated so local X
		-- is its thin face axis. Size.Y is the table diameter, not height.
		if surface:IsA("Part")
			and surface.Size.X < math.min(surface.Size.Y, surface.Size.Z) * 0.1 then
			local faceNormal = surface.CFrame:VectorToWorldSpace(Vector3.xAxis)
			return surface.Position.Y + math.abs(faceNormal.Y) * surface.Size.X * 0.5
		end
		return surface.Position.Y + surface.Size.Y * 0.5
	end

	return 3.5
end

---------------------------------------------------------------------
-- SEATS
---------------------------------------------------------------------

local function seatCFrame(index)
	local runtime =
		workspace:FindFirstChild("MatchRuntimeSeats")

	if runtime then
		local seat =
			runtime:FindFirstChild(
				"MatchSeat" .. tostring(index)
			)

		if seat and seat:IsA("BasePart") then
			return seat.CFrame
		end
	end

	local center = tableCenter()

	local angles = {
		0,
		90,
		180,
		270,
	}

	local angle =
		math.rad(
			angles[index]
			or 0
		)

	local position =
		center
		+ Vector3.new(
			math.sin(angle) * 8,
			0,
			-math.cos(angle) * 8
		)

	return CFrame.lookAt(position, center)
end

local function ownSeatIndex(state)
	for index, info in ipairs(state.players or {}) do
		if info.userId == player.UserId then
			return info.seat or index
		end
	end

	return 1
end

playerDisplayName = function(state, userId)
	for _, info in ipairs(state.players or {}) do
		if info.userId == userId then
			return
				info.name
				or info.username
				or "Игрок"
		end
	end

	return "Игрок"
end

---------------------------------------------------------------------
-- CHARACTER VISIBILITY
---------------------------------------------------------------------

local function showLocalAvatar()
	local character = player.Character

	if not character then
		return
	end

	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart")
			and object.Name ~= "HumanoidRootPart"
		then
			object.LocalTransparencyModifier = 0
		end
	end
end

local function hideHeadForPOV()
    if MatchPresentation then MatchPresentation.applyCameraVisibility(player.Character,false);return end
    local character=player.Character
    if not character then return end
    for _,object in ipairs(character:GetDescendants())do
        if object:IsA("BasePart")then
            local accessory=object:FindFirstAncestorWhichIsA("Accessory")
            local slot=accessory and accessory:GetAttribute("SpySlot")
            if object.Name=="Head" or object.Name=="SpyClassicHead" or slot=="hat" or slot=="hair" or slot=="glasses" then
                object.LocalTransparencyModifier=1
            end
        end
    end
end

---------------------------------------------------------------------
-- CAMERA
---------------------------------------------------------------------

local function yawFromDirection(direction)
	direction =
		Vector3.new(
			direction.X,
			0,
			direction.Z
		)

	if direction.Magnitude < 0.001 then
		return 0
	end

	direction = direction.Unit

	return math.atan2(
		-direction.X,
		-direction.Z
	)
end

local function stopSeatedCamera()
	seatedCameraActive = false
    matchUI.cameraDragging=false;matchUI.cameraTouch=nil;matchUI.cameraTouchPosition=nil
end

local function startSeatedCamera(state)
	cancelCameraSequence()
	endCinematicGrade()

	local character = player.Character

	local head =
		character
		and character:FindFirstChild("Head")

	if not head then
		return
	end

	forceCharacterVisible = false

	hideHeadForPOV()

	player.CameraMode = Enum.CameraMode.Classic

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = math.clamp(tonumber(player:GetAttribute("SpyFOV")) or 70, 60, 90)

	local center = tableCenter()

	local direction =
		Vector3.new(
			center.X - head.Position.X,
			0,
			center.Z - head.Position.Z
		)

	if direction.Magnitude < 0.1 then
		local seat =
			seatCFrame(
				ownSeatIndex(state)
			)

		direction =
			Vector3.new(
				center.X - seat.Position.X,
				0,
				center.Z - seat.Position.Z
			)
	end

	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	cameraBaseYaw = yawFromDirection(direction)

	cameraYawOffset = 0
	cameraPitch = math.rad(-2)

	seatedCameraActive = true
	cursorReleased = true

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function releaseCursor()
	cursorReleased = true

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function lockCursor()
	cursorReleased = false

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

---------------------------------------------------------------------
-- INTRO CAMERA
---------------------------------------------------------------------

local function introCamera(state)
	stopSeatedCamera()
	cancelCameraSequence()
	beginCinematicGrade()

	local token = cameraSequenceToken

	player.CameraMode = Enum.CameraMode.Classic
	camera.CameraType = Enum.CameraType.Scriptable

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	local center = tableCenter()
	local seat = seatCFrame(ownSeatIndex(state))
	local outward = Vector3.new(
		seat.Position.X - center.X,
		0,
		seat.Position.Z - center.Z
	)

	if outward.Magnitude < 0.1 then
		outward = Vector3.new(0, 0, 1)
	else
		outward = outward.Unit
	end

	local side = Vector3.new(-outward.Z, 0, outward.X)
	local target = center + Vector3.new(0, 0.35, 0)

	local widePosition =
		center
		- outward * 11.5
		+ side * 7.2
		+ Vector3.new(0, 6.8, 0)

	local orbitPosition =
		center
		- outward * 8.5
		- side * 4.0
		+ Vector3.new(0, 5.6, 0)

	local approachPosition =
		center
		+ outward * 7.0
		+ side * 0.7
		+ Vector3.new(0, 4.6, 0)

	camera.FieldOfView = 56
	camera.CFrame = CFrame.lookAt(widePosition, target)
	if player:GetAttribute("SpyReducedMotion") == true or player:GetAttribute("SpyCameraMotion") == false then
		camera.CFrame = CFrame.lookAt(approachPosition, target)
		return
	end

	activeCameraTween = tween(
		camera,
		2.1,
		{
			CFrame = CFrame.lookAt(orbitPosition, target),
			FieldOfView = 49,
		},
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)

	task.spawn(function()
		activeCameraTween.Completed:Wait()

		if token ~= cameraSequenceToken then
			return
		end

		activeCameraTween = tween(
			camera,
			2.75,
			{
				CFrame = CFrame.lookAt(
					approachPosition,
					target + outward * -0.35
				),
				FieldOfView = 44,
			},
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.InOut
		)

		activeCameraTween.Completed:Wait()

		if token == cameraSequenceToken then
			activeCameraTween = nil
		end
	end)
end

---------------------------------------------------------------------
-- CHARACTER CAMERA
---------------------------------------------------------------------

local function characterCamera()
	stopSeatedCamera()
	cancelCameraSequence()
	endCinematicGrade()

	local character = player.Character

	local root =
		character
		and character:FindFirstChild("HumanoidRootPart")

	local head =
		character
		and character:FindFirstChild("Head")

	if not root then
		return nil
	end

	forceCharacterVisible = true

	showLocalAvatar()

	player.CameraMode = Enum.CameraMode.Classic

	camera.CameraType = Enum.CameraType.Scriptable

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	local center = tableCenter()

	local toTable =
		Vector3.new(
			center.X - root.Position.X,
			0,
			center.Z - root.Position.Z
		)

	if toTable.Magnitude < 0.1 then
		toTable = Vector3.new(0, 0, -1)
	end

	toTable = toTable.Unit

	local side =
		Vector3.new(
			-toTable.Z,
			0,
			toTable.X
		)

	local cameraPosition =
		root.Position
		+ toTable * 3.55
		+ side * 2.15
		+ Vector3.new(0, 2.05, 0)

	local target =
		head
		and (
			head.Position
			+ Vector3.new(0, -0.55, 0)
		)
		or (
			root.Position
			+ Vector3.new(0, 1.2, 0)
		)

	camera.FieldOfView = 52

	return tween(
		camera,
		0.65,
		{
			CFrame =
				CFrame.lookAt(
					cameraPosition,
					target
				),
		}
	)
end

---------------------------------------------------------------------
-- RESULT CAMERA
---------------------------------------------------------------------

local function resultCamera()
	stopSeatedCamera()
	cancelCameraSequence()
	endCinematicGrade()

	local center = tableCenter()

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 52

	tween(
		camera,
		0.7,
		{
			CFrame =
				CFrame.lookAt(
					center + Vector3.new(7, 7.4, 10),

					center + Vector3.new(0, 0.3, 0)
				),
		}
	)
end

---------------------------------------------------------------------
-- CARD HELPERS
---------------------------------------------------------------------

local function surfaceLabel(parent, props)
	local object = Instance.new("TextLabel")

	for key, value in pairs(props or {}) do
		object[key] = value
	end

	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0

	object.Font = props.Font or Enum.Font.BuilderSansMedium
	object.TextColor3 = props.TextColor3 or COLORS.Ink

	object.TextXAlignment = Enum.TextXAlignment.Center
	object.TextYAlignment = Enum.TextYAlignment.Center

	object.Parent = parent

	return object
end

local function createCard(userId)
	local targetPlayer = Players:GetPlayerByUserId(userId)
	local profileCard = equippedCardFor(targetPlayer)
	local cardAccent = catalogColor(profileCard, CARD_ACCENT)
	local cardDark = catalogDark(profileCard, COLORS.Panel)
	local cardPaper = Color3.fromRGB(
		math.clamp(math.floor(232 + cardAccent.R * 12), 0, 255),
		math.clamp(math.floor(230 + cardAccent.G * 12), 0, 255),
		math.clamp(math.floor(224 + cardAccent.B * 12), 0, 255)
	)

	local card = Instance.new("Part")

	card.Name = "MatchCard_" .. tostring(userId)

	card.Size = Vector3.new(1.10, 1.58, 0.04)

	card.Anchored = true

	card.CanCollide = false
	card.CanTouch = false
	card.CanQuery = false

	card.CastShadow = true

	card.Material = Enum.Material.SmoothPlastic

	card.Color = cardDark

	card.Parent = workspace

	-------------------------------------------------------------
	-- BACK
	-------------------------------------------------------------

	local backGui =
		make(
			"SurfaceGui",
			card,
			{
				Face = Enum.NormalId.Back,

				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,

				PixelsPerStud = 220,

				LightInfluence = 0.10,
			}
		)

	local back =
		make(
			"Frame",
			backGui,
			{
				Size = UDim2.fromScale(1, 1),

				BackgroundColor3 = cardDark,

				BorderSizePixel = 0,
			}
		)

	local backBorder =
		make(
			"Frame",
			back,
			{
				Position = UDim2.fromScale(0.06, 0.04),

				Size = UDim2.fromScale(0.88, 0.92),

				BackgroundTransparency = 1,
			}
		)

	stroke(backBorder, cardAccent, 0.08, 1.8)

	surfaceLabel(
		back,
		{
			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.fromScale(0.5, 0.5),

			Size = UDim2.fromScale(0.80, 0.14),

			Text = "SPY CLUB",

			Font = Enum.Font.Garamond,
			TextSize = 34,

			TextColor3 = cardAccent,
		}
	)

	-------------------------------------------------------------
	-- FRONT
	-------------------------------------------------------------

	local frontGui =
		make(
			"SurfaceGui",
			card,
			{
				Face = Enum.NormalId.Front,

				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,

				PixelsPerStud = 220,

				LightInfluence = 0.05,

				Enabled = false,
			}
		)

	local front =
		make(
			"Frame",
			frontGui,
			{
				Size = UDim2.fromScale(1, 1),

				BackgroundColor3 = cardPaper,

				BorderSizePixel = 0,
			}
		)

	local border =
		make(
			"Frame",
			front,
			{
				Position = UDim2.fromScale(0.055, 0.035),

				Size = UDim2.fromScale(0.89, 0.93),

				BackgroundTransparency = 1,
			}
		)

	stroke(
		border,
		cardAccent,
		0.34,
		1.2
	)

	surfaceLabel(
		front,
		{
			Position = UDim2.fromScale(0.07, 0.052),

			Size = UDim2.fromScale(0.86, 0.10),

			Text = "SPY CLUB",

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 21,

			TextColor3 = COLORS.Ink,
		}
	)

	make(
		"Frame",
		front,
		{
			AnchorPoint = Vector2.new(0.5, 0),

			Position = UDim2.fromScale(0.5, 0.17),

			Size = UDim2.fromScale(0.25, 0.004),

			BackgroundColor3 = cardAccent,

			BorderSizePixel = 0,
		}
	)

	local category =
		surfaceLabel(
			front,
			{
				Position = UDim2.fromScale(0.07, 0.205),

				Size = UDim2.fromScale(0.86, 0.09),

				Text = "",

				Font = Enum.Font.BuilderSansMedium,
				TextSize = 15,

				TextColor3 = Color3.fromRGB(92, 93, 98),
			}
		)

	local role =
		surfaceLabel(
			front,
			{
				Name="PrivateRole",
                Position = UDim2.fromScale(0.06, 0.35),

				Size = UDim2.fromScale(0.88, 0.15),

				Text = "",

				Font = Enum.Font.Garamond,
				TextSize = 34,

				TextColor3 = COLORS.Ink,

				TextWrapped = true,
			}
		)

	local word =
		surfaceLabel(
			front,
			{
				Name="PrivateWord",
                Position = UDim2.fromScale(0.05, 0.52),

				Size = UDim2.fromScale(0.90, 0.19),

				Text = "",

				Font = Enum.Font.Garamond,
				TextSize = 33,

				TextColor3 = COLORS.Ink,

				TextWrapped = true,
			}
		)

	local hint =
		surfaceLabel(
			front,
			{
				Position = UDim2.fromScale(0.07, 0.77),

				Size = UDim2.fromScale(0.86, 0.16),

				Text = "",

				Font = Enum.Font.BuilderSansMedium,
				TextSize = 12,

				TextColor3 = Color3.fromRGB(92, 93, 98),

				TextWrapped = true,
			}
		)

	local data = {
		part = card,

		frontGui = frontGui,

		category = category,
		role = role,
		word = word,
		hint = hint,

		userId = userId,

		tableCFrame = nil,
	}

	table.insert(cards, data)

	cardsByUserId[userId] = data

	return data
end

local function clearCards()
	stopDealer(false)
	for _, data in ipairs(cards) do
		if data.part and data.part.Parent then
			data.part:Destroy()
		end
	end

	table.clear(cards)
	table.clear(cardsByUserId)

	ownCard = nil

	cardMode = nil
	cardAnimating = false
end

local function tableCardCFrame(index, seatIndex)
	local center = tableCenter()
	local seat = seatCFrame(seatIndex or index)

	local direction =
		Vector3.new(
			seat.Position.X - center.X,
			0,
			seat.Position.Z - center.Z
		)

	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	direction = direction.Unit

	local position =
		center
		+ direction * 3.70

	position =
		Vector3.new(
			position.X,

			tableTopY() + 0.075,

			position.Z
		)

	local facing =
		CFrame.lookAt(
			position,

			Vector3.new(
				seat.Position.X,
				position.Y,
				seat.Position.Z
			)
		)

	return
		facing
		* CFrame.Angles(
			math.rad(-90),
			0,
			0
		)
end

-- Locally authored geometry only: a tailored sleeve, cuff and articulated
-- gloved hand. These parts never replicate, collide or carry role information.
local function createDealer()
	local model = Instance.new("Model")
	model.Name = "SpyLocalDealer"
	local function part(name, size, color)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local glove = Color3.fromRGB(44, 40, 39)
	local rig = {
		palm = part("GlovedPalm", Vector3.new(0.62, 0.20, 0.72), glove),
		sleeve = part("TailoredSleeve", Vector3.new(0.70, 0.65, 2.2), Color3.fromRGB(21, 23, 28)),
		cuff = part("IvoryCuff", Vector3.new(0.62, 0.34, 0.23), Color3.fromRGB(182, 171, 151)),
		fingers = {},
	}
	for index = 1, 5 do
		rig.fingers[index] = {
			part("Finger" .. index .. "Proximal", Vector3.new(0.115, 0.13, 0.30), glove),
			part("Finger" .. index .. "Distal", Vector3.new(0.105, 0.12, 0.25), glove),
		}
	end
	dealer = model
	-- Parent only after the first pose so no pieces flash at the origin.
	return rig
end

local function poseDealer(rig, palmCF, elbow, grip)
	rig.palm.CFrame = palmCF
	local wrist = palmCF:PointToWorldSpace(Vector3.new(0, 0, 0.40))
	local sleeveEnd = wrist + Vector3.new(0, 0.04, 0)
	rig.sleeve.Size = Vector3.new(0.70, 0.65, (elbow - sleeveEnd).Magnitude)
	rig.sleeve.CFrame = CFrame.lookAt((elbow + sleeveEnd) / 2, sleeveEnd)
	rig.cuff.CFrame = palmCF * CFrame.new(0, 0.025, 0.43)
	for index, segments in ipairs(rig.fingers) do
		local joint
		if index == 5 then
			joint = palmCF * CFrame.new(-0.34, -0.02, 0.06) * CFrame.Angles(0, math.rad(52), 0)
		else
			joint = palmCF * CFrame.new((index - 2.5) * 0.145, 0, -0.34)
		end
		joint *= CFrame.Angles(math.rad(-12 - grip * 24), 0, 0)
		segments[1].CFrame = joint * CFrame.new(0, 0, -0.15)
		local knuckle = joint * CFrame.new(0, 0, -0.30) * CFrame.Angles(math.rad(-grip * 38), 0, 0)
		segments[2].CFrame = knuckle * CFrame.new(0, 0, -0.125)
	end
end

local function dealCards(roster, state)
	clearCards()
	state = state or currentState or {}
	local remaining = type(state.endAt) == "number" and state.endAt - workspace:GetServerTimeNow() or 6.5
	local plan = DealMotion.plan(#(roster or {}), state.phase, remaining, player:GetAttribute("SpyReducedMotion") == true)
	local center = Vector3.new(tableCenter().X, tableTopY() + 0.075, tableCenter().Z)
	local seat = seatCFrame(ownSeatIndex(state))
	local outward = Vector3.new(seat.Position.X - center.X, 0, seat.Position.Z - center.Z)
	outward = outward.Magnitude > 0.1 and outward.Unit or Vector3.new(0, 0, 1)
	local deck = center - outward * 0.85
	local elbow = center - outward * 3.8 + Vector3.new(0, 0.75, 0)
	for index, info in ipairs(roster or {}) do
		local data = createCard(info.userId)
		data.frontGui.Enabled = false
		data.tableCFrame = tableCardCFrame(index, info.seat)
		local height = (#roster - index) * 0.012
		data.dealStart = CFrame.lookAt(deck + Vector3.new(0, height, 0), deck + outward + Vector3.new(0, height, 0)) * CFrame.Angles(math.rad(-90), 0, 0)
		data.dealRelease = data.dealStart:Lerp(data.tableCFrame, 0.27)
		data.part.CFrame = plan.instant and data.tableCFrame or data.dealStart
	end
	if plan.instant then return end
	local rig = createDealer()
	local token = dealGeneration
	local started = os.clock()
	local soundedDealIndex = 0
	local rest = CFrame.lookAt(deck - outward * 0.8 + Vector3.new(0, 0.60, 0), deck + Vector3.new(0, 0.60, 0))
	poseDealer(rig, rest, elbow, 0)
	dealer.Parent = workspace
	dealerConnection = RunService.RenderStepped:Connect(function()
		if token ~= dealGeneration then return end
		if not currentState or currentState.phase ~= "Intro" or player:GetAttribute("SpyReducedMotion") == true then
			stopDealer(true)
			return
		end
		local sample = DealMotion.sample(plan, os.clock() - started)
		if sample.stage == "done" then stopDealer(true); return end
		for index = 1, sample.index - 1 do
			local previous = cards[index]
			if previous and previous.part.Parent then previous.part.CFrame = previous.tableCFrame end
		end
		local data = cards[sample.index]
		if not data or not data.part.Parent then stopDealer(true); return end
		if sample.stage == "slide" and soundedDealIndex ~= sample.index then
			soundedDealIndex = sample.index
			playMatchSound(cardDealSound, 0.97 + (sample.index % 3) * 0.025)
		end
		local function above(cf)
			local position = cf.Position + Vector3.new(0, 0.27, 0)
			local forward = Vector3.new(cf.UpVector.X, 0, cf.UpVector.Z)
			return CFrame.lookAt(position, position + (forward.Magnitude > 0.1 and forward.Unit or outward))
		end
		local palm = rest
		if sample.stage == "reach" then
			palm = rest:Lerp(above(data.dealStart), sample.progress)
		elseif sample.stage == "carry" then
			local t = sample.progress
			data.part.CFrame = data.dealStart:Lerp(data.dealRelease, t) + Vector3.new(0, math.sin(t * math.pi) * 0.24, 0)
			palm = above(data.part.CFrame)
		elseif sample.stage == "slide" then
			local t = sample.progress
			data.part.CFrame = data.dealRelease:Lerp(data.tableCFrame, 1 - (1 - t) ^ 3)
			palm = above(data.dealRelease):Lerp(rest, math.min(1, t * 1.3))
		end
		poseDealer(rig, palm, elbow, sample.grip)
	end)
end

local function fillOwnCard(data)
	if not secretData then
		return
	end
	player:SetAttribute("SpyRoleCardOpened",true)
	if secretData.caseFile and matchUI.caseFiles then
		local lang=player:GetAttribute("SpyLanguage")or"ru";local file=secretData.caseFile
		data.category.Text=matchUI.caseFiles.text(lang,"meeting")
		data.role.Text=secretData.role=="spy"and MatchI18n.text(lang,"Ты — шпион")or matchUI.caseFiles.text(lang,"innocent")
		data.word.Text=file.alibi or"";data.word.TextSize=15;data.word.TextColor3=COLORS.Ink
		data.hint.Text=file.secret or file.goal or""
		return
	end

	data.category.Text =
		"ТЕМА · "
		.. tostring(
			secretData.category
			or "—"
		)

	if secretData.role == "spy" then
		data.role.Text = "ТЫ — ШПИОН"
		data.role.TextColor3 = COLORS.Danger

		data.word.Text = "СЛОВА НЕТ"
		data.word.TextColor3 = COLORS.Danger

		data.hint.Text =
			"Слушай остальных. Пойми слово и не выдай себя."
	else
		data.role.Text = "ТВОЁ СЛОВО"
		data.role.TextColor3 = COLORS.Ink

		data.word.Text =
			tostring(
				secretData.word
				or "—"
			)

		data.word.TextColor3 = COLORS.Ink

		data.hint.Text =
			"Запомни слово. Шпион его не видел."
	end
end

---------------------------------------------------------------------
-- ARM
---------------------------------------------------------------------

local function findArmRig()
	local character = player.Character

	if not character then
		return nil
	end

	local result = {}

	local upperTorso = character:FindFirstChild("UpperTorso")
	local upperArm = character:FindFirstChild("RightUpperArm")
	local lowerArm = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")

	if upperTorso
		and upperArm
		and lowerArm
		and hand
	then
		result.rigType = "R15"

		result.shoulder =
			upperTorso:FindFirstChild("RightShoulder")

		result.elbow =
			upperArm:FindFirstChild("RightElbow")

		result.wrist =
			lowerArm:FindFirstChild("RightWrist")

		result.hand = hand

		return result
	end

	local torso = character:FindFirstChild("Torso")
	local rightArm = character:FindFirstChild("Right Arm")

	if torso and rightArm then
		result.rigType = "R6"

		result.shoulder =
			torso:FindFirstChild("Right Shoulder")

		result.hand = rightArm

		return result
	end

	return nil
end

local function clearArmPose()
	armPose = nil

	if not armRig then
		return
	end

	if armRig.shoulder then
		armRig.shoulder.Transform = CFrame.identity
	end

	if armRig.elbow then
		armRig.elbow.Transform = CFrame.identity
	end

	if armRig.wrist then
		armRig.wrist.Transform = CFrame.identity
	end
end

---------------------------------------------------------------------
-- CARD CAMERA POSITIONS
---------------------------------------------------------------------

local function closedCardCF()
    -- Secret card returns to its physical seat; C lifts it only when requested.
    if ownCard and ownCard.tableCFrame then return ownCard.tableCFrame end
    return camera.CFrame*CFrame.new(.96,-2.2,-4.6)*CFrame.Angles(math.rad(-18),math.rad(12),math.rad(-9))
end

local function openBackCF()
	return
		camera.CFrame
		* CFrame.new(
			0.32,
			-0.03,
			-3.55
		)
		* CFrame.Angles(
			0,
			math.rad(5),
			math.rad(-2)
		)
end

local function openFrontCF()
	return
		camera.CFrame
		* CFrame.new(
			0.32,
			-0.03,
			-3.45
		)
		* CFrame.Angles(
			0,
			math.rad(175),
			math.rad(-2)
		)
end

local function openCard()
	if cardAnimating
		or not ownCard
		or not ownCard.part
		or not ownCard.part.Parent
	then
		return
	end

	if cardMode == "open" then
		return
	end

	cardAnimating = true
	cardMode = nil
	playMatchSound(cardWhooshSound, 1.55)

	local card = ownCard.part

	local back = openBackCF()

	local edge =
		back
		* CFrame.Angles(
			0,
			math.rad(88),
			0
		)

	local front = openFrontCF()

	waitTween(
		tween(
			card,
			0.25,
			{
				CFrame = back,
			}
		)
	)

	waitTween(
		tween(
			card,
			0.12,
			{
				CFrame = edge,
			},
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.In
		)
	)

	ownCard.frontGui.Enabled = true

	waitTween(
		tween(
			card,
			0.19,
			{
				CFrame = front,
			},
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
	)

	cardMode = "open"
	cardAnimating = false
end

local function closeCard()
	if cardAnimating
		or not ownCard
		or not ownCard.part
		or not ownCard.part.Parent
	then
		return
	end

	if cardMode == "closed" then
		return
	end

	cardAnimating = true
	cardMode = nil
	playMatchSound(cardWhooshSound, 1.32)

	local card = ownCard.part

	local front = openFrontCF()

	local edge =
		front
		* CFrame.Angles(
			0,
			math.rad(-88),
			0
		)

	local back = openBackCF()
	local closed = closedCardCF()

	waitTween(
		tween(
			card,
			0.12,
			{
				CFrame = edge,
			},
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.In
		)
	)

	ownCard.frontGui.Enabled = false

	waitTween(
		tween(
			card,
			0.16,
			{
				CFrame = back,
			}
		)
	)

	waitTween(
		tween(
			card,
			0.26,
			{
				CFrame = closed,
			}
		)
	)

	cardMode = "closed"
	cardAnimating = false
end

local function recoverOwnCard()
	if not currentState or currentState.phase == "Intro" or currentState.phase == "Role" then return end
	if ownCard or not secretData then
		return
	end

	local data = cardsByUserId[player.UserId]

	if not data
		or not data.part
		or not data.part.Parent
	then
		return
	end

	ownCard = data
	fillOwnCard(data)
	data.frontGui.Enabled = false

	if data.tableCFrame then
		data.part.CFrame = data.tableCFrame
	end

	cardMode = "closed"
end

local function toggleCard()
	if not currentState or cardAnimating then
		return
	end

	if currentState.phase ~= "Hint"
		and currentState.phase ~= "Discuss"
	then
		return
	end

	if cardMode == "open" then
		task.spawn(closeCard)
	else
		task.spawn(openCard)
	end
end

---------------------------------------------------------------------
-- ROLE CUTSCENE
---------------------------------------------------------------------

local function revealOwnCard(state)
	if ownCard or not secretData or not currentState or currentState.phase ~= "Role" then
		return
	end

	local data =
		cardsByUserId[
	player.UserId
	]

	if not data
		or not data.part
		or not data.part.Parent
	then
		return
	end

	ownCard = data
	local token = roleSequence
	local function valid()
		return token == roleSequence and currentState and currentState.phase == "Role" and data.part.Parent ~= nil
	end

	fillOwnCard(data)

	local card = data.part
	local remaining = type(state.endAt) == "number" and state.endAt - workspace:GetServerTimeNow() or 5.5
	if player:GetAttribute("SpyReducedMotion") == true or player:GetAttribute("SpyCameraMotion") == false or remaining < 3.5 then
		startSeatedCamera(state)
		cinemaBars(false)
		card.CFrame = openFrontCF()
		data.frontGui.Enabled = true
		cardMode = "open"
		return
	end

	armRig = findArmRig()

	local cameraMove = characterCamera()

	if cameraMove then
		cameraMove.Completed:Wait()
	end
	if not valid() then return end

	task.wait(0.18)
	if not valid() then return end

	armPose = "reach"

	task.wait(0.50)
	if not valid() then return end

	if armRig and armRig.hand then
		cardFollowHand = true

		task.wait(0.10)
		if not valid() then return end

		armPose = "lift"

		task.wait(0.55)
	else
		task.wait(0.45)
	end
	if not valid() then return end

	matchUI.cutFade.Visible = true
	matchUI.cutFade.BackgroundTransparency = 1

	waitTween(
		tween(
			matchUI.cutFade,
			0.11,
			{
				BackgroundTransparency = 0,
			},
			Enum.EasingStyle.Sine
		)
	)
	if not valid() then return end

	cardFollowHand = false

	clearArmPose()

	forceCharacterVisible = false

	startSeatedCamera(state)

	card.CFrame = closedCardCF()

	cardMode = "closed"

	waitTween(
		tween(
			matchUI.cutFade,
			0.17,
			{
				BackgroundTransparency = 1,
			},
			Enum.EasingStyle.Sine
		)
	)

	matchUI.cutFade.Visible = false
	if not valid() then return end

	task.wait(0.10)
	if not valid() then return end

	if secretData and secretData.role == "spy" then
		playMatchSound(spyRevealSound, 1)
	else
		playMatchSound(phaseChimeSound, 1.08)
	end
	openCard()

	task.wait(1.55)
	if not valid() then return end

	if cardMode == "open"
		and not cardAnimating
	then
		closeCard()
	end
end

local function returnCard()
	if not ownCard
		or not ownCard.part
		or not ownCard.part.Parent
		or not ownCard.tableCFrame
	then
		return
	end

	while cardAnimating do
		task.wait()
	end

	cardMode = nil

	local card = ownCard.part

	ownCard.frontGui.Enabled = false

	local target = ownCard.tableCFrame

	tween(
		card,
		0.35,
		{
			CFrame = target,
		}
	)
end

---------------------------------------------------------------------
-- CHAT LOGIC
---------------------------------------------------------------------

local chatSending = false
local pendingChatMessageId = ""
local pendingChatText = ""
local pendingChatWasHint = false
local chatSendToken = 0

local function canWriteChat()
	if not currentState then return false end
	local source = localMatchTextSource()
	local serverState = tostring(player:GetAttribute("SpyMatchChatState") or "connecting")
	if serverState ~= "ready" or not source or source.CanSend ~= true then return false end

	if currentState.phase == "Discuss" then
		return true
	end

	if currentState.phase == "Hint" then
		return currentState.turnUserId == player.UserId and not hintSent
	end

	return false
end

local function updateChatPlaceholder()
	if not currentState then
		return
	end

	local source = localMatchTextSource()
	local serverState = tostring(player:GetAttribute("SpyMatchChatState") or "connecting")
	local transportReady = serverState == "ready" and source ~= nil and source.CanSend == true
	local allowed = canWriteChat()
	local sendReady = allowed and not chatSending

	matchUI.chatInput.TextEditable = sendReady
	matchUI.chatSend.Active = sendReady
	matchUI.chatSend.BackgroundTransparency = sendReady and 0 or 0.58

	if not transportReady then
		if serverState == "connecting" then
			matchUI.chatInput.PlaceholderText = "Подключаем чат…"
		elseif serverState == "failed" then
			matchUI.chatInput.PlaceholderText = "Не удалось подключить чат"
		else
			matchUI.chatInput.PlaceholderText = "Чат недоступен для этого аккаунта"
		end
		return
	end

	if currentState.phase == "Hint" then
		if currentState.turnUserId == player.UserId then
			matchUI.chatInput.PlaceholderText =
				hintSent
				and "Подсказка отправлена"
				or "Напиши одну подсказку…"
		else
			matchUI.chatInput.PlaceholderText =
				"Сейчас говорит "
				.. playerDisplayName(
					currentState,
					currentState.turnUserId
				)
		end
	elseif currentState.phase == "Discuss" then
		matchUI.chatInput.PlaceholderText =
			"Обсудить подозрения…"
	else
		matchUI.chatInput.PlaceholderText = ""
	end
end

ReplicatedStorage:GetAttributeChangedSignal("SpyChatChannelName"):Connect(function() task.defer(updateChatPlaceholder) end)
player:GetAttributeChangedSignal("SpyMatchChatState"):Connect(function()
	task.defer(updateChatPlaceholder)
end)
TextChatService.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("TextSource") then
		descendant:GetPropertyChangedSignal("CanSend"):Connect(function() task.defer(updateChatPlaceholder) end)
		descendant:GetAttributeChangedSignal("SpyChatUserId"):Connect(function() task.defer(updateChatPlaceholder) end)
		task.defer(updateChatPlaceholder)
	end
end)

---------------------------------------------------------------------
-- SPY_NATIVE_MATCH_CHAT_ONLY
-- The old in-match textbox is kept as layout baggage but never shown or focused.
---------------------------------------------------------------------
local function openChat()
    chatCollapsed=true
    chatSessionStarted=true
    matchUI.chatFrame.Visible=false
    matchUI.chatFrame.GroupTransparency=1
    matchUI.collapsedChat.Visible=false
end
local function collapseChat()
    openChat()
end
local function hideChatCompletely()
    openChat()
end
local function ensureChatSession()
    openChat()
end

local function addChatMessage(userId, message)
	local sender =
		Players:GetPlayerByUserId(userId)

	local name =
		sender
		and sender.DisplayName
		or "Игрок"

	local row =
		make(
			"Frame",
			matchUI.chatMessages,
			{
				Size = UDim2.new(1, -4, 0, 0),

				AutomaticSize = Enum.AutomaticSize.Y,

				BackgroundTransparency = 1,

				BorderSizePixel = 0,

				ZIndex = 162,
			}
		)

	make(
		"UIListLayout",
		row,
		{
			Padding = UDim.new(0, 2),
		}
	)

	label(
		row,
		{
			Size = UDim2.new(1, 0, 0, 18),

			Text = name,

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 12,

			TextColor3 =
				userId == player.UserId
				and COLORS.Brass
				or COLORS.IvorySoft,

			TextXAlignment = Enum.TextXAlignment.Left,

			ZIndex = 163,
		}
	)

	label(
		row,
		{
			Size = UDim2.new(1, -4, 0, 0),

			AutomaticSize = Enum.AutomaticSize.Y,

			Text = tostring(message),

			Font = Enum.Font.BuilderSansMedium,
			TextSize = 14,

			TextColor3 = COLORS.Ivory,

			TextWrapped = true,

			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,

			ZIndex = 163,
		}
	)

	table.insert(chatRows, row)

	while #chatRows > 35 do
		local oldest =
			table.remove(
				chatRows,
				1
			)

		if oldest then
			oldest:Destroy()
		end
	end
end

local function finishChatSend(success)
	if success then
		if matchUI.chatInput.Text == pendingChatText then matchUI.chatInput.Text = "" end
		if pendingChatWasHint then hintSent = true end
	end
	pendingChatMessageId = ""
	pendingChatText = ""
	pendingChatWasHint = false
	chatSending = false
	updateChatPlaceholder()
end

local function sendChat()
	if chatSending then return end
	local channel = resolveMatchChatChannel()
	if not canWriteChat() or not channel then
		updateChatPlaceholder()
		return
	end

	local text = matchUI.chatInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return end

	local length = utf8.len(text)
	if not length then return end
	if length > 180 then
		local cut = utf8.offset(text, 181)
		if cut then text = text:sub(1, cut - 1) end
	end

	chatSending = true
	chatSendToken += 1
	local token = chatSendToken
	pendingChatText = text
	pendingChatWasHint = currentState.phase == "Hint"
	updateChatPlaceholder()

	task.spawn(function()
		local ok, response = pcall(function() return channel:SendAsync(text) end)
		if not ok or not response then
			warn("SpyClub match chat send failed: " .. tostring(response))
			finishChatSend(false)
			return
		end

		pendingChatMessageId = tostring(response.MessageId or "")
		if response.Status == Enum.TextChatMessageStatus.Success then
			finishChatSend(true)
			return
		end
		if response.Status ~= Enum.TextChatMessageStatus.Sending then
			warn("SpyClub match chat rejected: " .. tostring(response.Status))
			finishChatSend(false)
			return
		end

		task.delay(8, function()
			if token ~= chatSendToken or not chatSending then return end
			warn("SpyClub match chat acknowledgement timeout")
			finishChatSend(false)
		end)
	end)
end

matchUI.chatCollapse.Activated:Connect(collapseChat)
matchUI.collapsedChat.Activated:Connect(openChat)
matchUI.chatSend.Activated:Connect(sendChat)

matchUI.chatInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		sendChat()
	end
end)

TextChatService.MessageReceived:Connect(function(message)
	if not message.TextChannel or message.TextChannel ~= resolveMatchChatChannel() then return end
	local messageId = tostring(message.MessageId or "")

	if pendingChatMessageId ~= "" and messageId == pendingChatMessageId
		and message.Status ~= Enum.TextChatMessageStatus.Sending then
		finishChatSend(message.Status == Enum.TextChatMessageStatus.Success)
	end

	if message.Status ~= Enum.TextChatMessageStatus.Success then return end
	if not message.TextSource or type(message.Text) ~= "string" or message.Text == "" then return end
	if messageId ~= "" then
		if seenMessages[messageId] then return end
		seenMessages[messageId] = true
		task.delay(30, function() seenMessages[messageId] = nil end)
	end

	addChatMessage(message.TextSource.UserId~=0 and message.TextSource.UserId or message.TextSource:GetAttribute("SpyChatUserId"), message.Text)
end)

---------------------------------------------------------------------
-- VOTE
---------------------------------------------------------------------

local function clearVoteMenu()
	matchUI.stopBallotHovers()
	for _, button in ipairs(voteButtons) do
		if button.Parent then
			button:Destroy()
		end
	end

	table.clear(voteButtons)

	selectedVoteValue = nil
	voteSubmitted = false

	matchUI.extraRoundButton.BackgroundColor3 = COLORS.Panel2
	matchUI.extraRoundStroke.Transparency = 0.65
	for _,caption in ipairs(matchUI.extraRoundButton:GetChildren())do
		if caption:IsA("TextLabel")then caption.TextColor3=caption.Name=="ExtraRoundDetail"and COLORS.IvorySoft or COLORS.Ivory end
	end

	matchUI.confirmVote.Active = false
    matchUI.confirmVote.TextColor3=COLORS.IvorySoft
	matchUI.confirmVote.BackgroundTransparency = 0.65

	matchUI.confirmVote.Text = "Сначала выбери вариант"
end

local function closeVote()
	if not matchUI.voteBackdrop.Visible then
		return
	end

	local animation =
		tween(
			matchUI.voteBackdrop,
			0.18,
			{
				GroupTransparency = 1,
			}
		)

	animation.Completed:Once(function()
		matchUI.voteBackdrop.Visible = false
	end)
end

function matchUI.stopBallotHovers()
    for _,animation in pairs(matchUI.ballotHoverTweens or {})do animation:Cancel()end
    matchUI.ballotHoverTweens={}
end

function matchUI.hoverBallot(button,color)
    matchUI.ballotHoverTweens=matchUI.ballotHoverTweens or {}
    local previous=matchUI.ballotHoverTweens[button]
    if previous then previous:Cancel()end
    matchUI.ballotHoverTweens[button]=tween(button,.12,{BackgroundColor3=color},Enum.EasingStyle.Quad)
end

local function deselectVoteButtons()
	-- Finish selection with one stable paint, even when a hover is still playing.
	matchUI.stopBallotHovers()
	for _, other in ipairs(voteButtons) do
		local outline =
			other:FindFirstChildOfClass("UIStroke")

		other.BackgroundColor3 = COLORS.Panel2
		other.SuspectName.TextColor3=COLORS.Ivory
		other.SeatLabel.TextColor3=COLORS.IvorySoft
		other.SeatIndex.TextColor3=COLORS.IvorySoft
		other.SelectionMarker.Visible=false

		if outline then
			outline.Transparency = 0.76
		end
	end

	matchUI.extraRoundButton.BackgroundColor3 = COLORS.Panel2
	matchUI.extraRoundStroke.Transparency = 0.65
	for _,caption in ipairs(matchUI.extraRoundButton:GetChildren())do
		if caption:IsA("TextLabel")then caption.TextColor3=caption.Name=="ExtraRoundDetail"and COLORS.IvorySoft or COLORS.Ivory end
	end
end

matchUI.extraRoundButton.MouseEnter:Connect(function()
	if voteSubmitted
		or selectedVoteValue == EXTRA_ROUND_VOTE_VALUE
	then
		return
	end

	matchUI.hoverBallot(matchUI.extraRoundButton,COLORS.Panel3)
end)

matchUI.extraRoundButton.MouseLeave:Connect(function()
	if voteSubmitted
		or selectedVoteValue == EXTRA_ROUND_VOTE_VALUE
	then
		return
	end

	matchUI.hoverBallot(matchUI.extraRoundButton,COLORS.Panel2)
end)

matchUI.extraRoundButton.Activated:Connect(function()
	if voteSubmitted
		or not matchUI.extraRoundButton.Visible
	then
		return
	end

	deselectVoteButtons()

	selectedVoteValue = EXTRA_ROUND_VOTE_VALUE

	matchUI.extraRoundButton.BackgroundColor3 = COLORS.Ivory
	matchUI.extraRoundStroke.Transparency = 0.10
	for _,caption in ipairs(matchUI.extraRoundButton:GetChildren())do
		if caption:IsA("TextLabel")then caption.TextColor3=COLORS.Ink end
	end

	matchUI.confirmVote.Active = true
    matchUI.confirmVote.TextColor3=COLORS.Ink
	matchUI.confirmVote.BackgroundTransparency = 0

	matchUI.confirmVote.Text = "Подтвердить · ещё один круг"
end)

local function openVote(state)
	stopSeatedCamera()

	hideChatCompletely()

	showControls(false)

	if cardMode == "open"
		and not cardAnimating
	then
		task.spawn(closeCard)
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	cursorReleased = true

	clearVoteMenu()

	matchUI.extraRoundButton.Visible =
		state.allowExtraRound ~= false

	matchUI.voteBackdrop.Visible = true
	matchUI.voteBackdrop.GroupTransparency = 1

    matchUI.votePlayers.CanvasPosition=Vector2.new()
    for index,info in ipairs(state.players or {}) do
        if info.userId==player.UserId then continue end
        local button=make("TextButton",matchUI.votePlayers,{
            Name="Suspect_"..tostring(info.userId),Size=UDim2.fromOffset(266,242),LayoutOrder=index,
            BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,AutoButtonColor=false,Text="",ZIndex=203,
        })
        button:SetAttribute("VoteUserId",info.userId)
        corner(button,2);stroke(button,COLORS.Brass,.76,1)
        -- Small registration corners give the live portraits a contact-sheet frame.
        for cornerIndex,edge in ipairs({{0,0},{1,0},{0,1},{1,1}})do
            local x,y=edge[1],edge[2]
            make("Frame",button,{
                Name="RegistrationH"..cornerIndex,AnchorPoint=Vector2.new(x,y),
                Position=UDim2.new(x,x==0 and 5 or -5,y,y==0 and 5 or -5),Size=UDim2.fromOffset(12,1),
                BackgroundColor3=COLORS.BrassDark,BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=204,
            })
            make("Frame",button,{
                Name="RegistrationV"..cornerIndex,AnchorPoint=Vector2.new(x,y),
                Position=UDim2.new(x,x==0 and 5 or -5,y,y==0 and 5 or -5),Size=UDim2.fromOffset(1,12),
                BackgroundColor3=COLORS.BrassDark,BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=204,
            })
        end
        local avatar=make("Frame",button,{
            Name="Portrait",Position=UDim2.fromOffset(18,24),Size=UDim2.fromOffset(144,144),
            BackgroundColor3=COLORS.Panel3,BorderSizePixel=0,ClipsDescendants=true,ZIndex=204,
        })
        corner(avatar,2)
        label(button,{
            Name="SeatIndex",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,37),Size=UDim2.fromOffset(72,76),
            Text=string.format("%02d",tonumber(info.seat)or index),Font=Enum.Font.Garamond,TextSize=68,
            TextColor3=COLORS.IvorySoft,TextTransparency=.4,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=204,
        })
        label(button,{
            Name="SelectionMarker",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,10),Size=UDim2.fromOffset(90,14),
            Text="ВЫБРАН",Font=Enum.Font.BuilderSansBold,TextSize=10,TextColor3=COLORS.Ink,
            TextXAlignment=Enum.TextXAlignment.Right,Visible=false,ZIndex=204,
        })
        local name=tostring(info.name or info.username or "Игрок")
        label(button,{
            Name="SuspectName",Position=UDim2.fromOffset(18,184),Size=UDim2.new(1,-36,0,26),
            Text=name,Font=Enum.Font.BuilderSansBold,TextSize=18,TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=204,
        })
        label(button,{
            Name="SeatLabel",Position=UDim2.fromOffset(18,214),Size=UDim2.new(1,-36,0,18),
            Text="Место "..tostring(info.seat or index)
                ..(MatchPresentation and MatchPresentation.getMark(info.userId)=="suspect" and " · подозрение"
                    or MatchPresentation and MatchPresentation.getMark(info.userId)=="clear" and " · алиби" or ""),
            Font=Enum.Font.BuilderSansMedium,TextSize=12,
            TextColor3=COLORS.IvorySoft,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=204,
        })
		button.MouseEnter:Connect(function()
			if voteSubmitted
				or selectedVoteValue == info.userId
			then
				return
			end

			matchUI.hoverBallot(button,COLORS.Panel3)
		end)

		button.MouseLeave:Connect(function()
			if voteSubmitted
				or selectedVoteValue == info.userId
			then
				return
			end

			matchUI.hoverBallot(button,COLORS.Panel2)
		end)

		button.Activated:Connect(function()
			if info.userId==player.UserId then return end
			if voteSubmitted then
				return
			end

			deselectVoteButtons()

			selectedVoteValue = info.userId

			local outline =
				button:FindFirstChildOfClass("UIStroke")

			button.BackgroundColor3 = COLORS.Ivory
			button.SuspectName.TextColor3=COLORS.Ink
			button.SeatLabel.TextColor3=COLORS.Ink
			button.SeatIndex.TextColor3=COLORS.Ink
			button.SelectionMarker.Visible=true

			if outline then
				outline.Transparency = 0.04
			end

			matchUI.confirmVote.Active = true
            matchUI.confirmVote.TextColor3=COLORS.Ink
			matchUI.confirmVote.BackgroundTransparency = 0

			matchUI.confirmVote.Text =
				"Голосовать за "
				.. name
		end)

        if MatchPresentation then
            MatchPresentation.attachPortrait(avatar,Players:GetPlayerByUserId(info.userId),{userId=info.userId})
        end

		table.insert(voteButtons, button)
	end

    fitMatchPanels()
    matchUI.phaseRoot.GroupTransparency=1

	tween(
		matchUI.voteBackdrop,
		0.23,
		{
			GroupTransparency = 0,
		}
	)
end

matchUI.confirmVote.Activated:Connect(function()
	if selectedVoteValue==player.UserId then return end
	if voteSubmitted
		or selectedVoteValue == nil
	then
		return
	end

	voteSubmitted = true

	actionEvent:FireServer(
		"Vote",
		selectedVoteValue
	)

	matchUI.confirmVote.Active = false

	if selectedVoteValue == EXTRA_ROUND_VOTE_VALUE then
		matchUI.confirmVote.Text =
			"Голос за ещё один круг принят"
	else
		matchUI.confirmVote.Text =
			"Голос принят"
	end

	matchUI.confirmVote.BackgroundTransparency = 0.30
end)

---------------------------------------------------------------------
-- RESULT
---------------------------------------------------------------------

local function paintResult()
 local state=matchUI.lastResultState
 local result=state and state.result
 if not result then return end
 local language=player:GetAttribute("SpyLanguage") or "ru"
 local english=language=="en"
 local spy=playerDisplayName(state,result.spyId)
 matchUI.caseReviewButton.Visible=state.case~=nil
 if state.case and matchUI.caseFiles then
  matchUI.caseReviewButton:SetAttribute("SpyUserText",true);matchUI.caseReviewButton.Text=matchUI.caseFiles.text(language,"review")
 end
 matchUI.resultMeta.Text=(english and "ROUND COMPLETE · WORD: " or "ИТОГ ПАРТИИ · СЛОВО: ")..tostring(result.word or "—")
 if result.reason=="spy_guessed" then
  matchUI.resultTitle.Text=english and "The spy cracked the word" or "Шпион разгадал слово"
  matchUI.resultDescription.Text=MatchI18n.t(language,"resultSpyGuessedName",{name=spy})
 elseif result.reason=="spy_guess_wrong" then
  matchUI.resultTitle.Text=english and "The spy's guess failed" or "Шпион ошибся"
  matchUI.resultDescription.Text=MatchI18n.text(language,"Шпион рискнул и назвал неверное слово. Победа агентов.")
 elseif result.reason=="caught" then
  matchUI.resultTitle.Text=english and "Spy exposed" or "Шпион раскрыт"
  matchUI.resultDescription.Text=MatchI18n.t(language,"resultSpyCaughtName",{name=spy})
 elseif result.reason=="wrong" then
  matchUI.resultTitle.Text=english and "Spy escaped" or "Шпион остался в тени"
  matchUI.resultDescription.Text=MatchI18n.t(language,"resultWrongName",{name=spy})
 else
  matchUI.resultTitle.Text=english and "No majority" or "Стол не определился"
  matchUI.resultDescription.Text=MatchI18n.t(language,"resultNoMajorityName",{name=spy})
 end
 if state.case and matchUI.caseFiles then
  matchUI.resultMeta:SetAttribute("SpyUserText",true)
  matchUI.resultMeta.Text=matchUI.caseFiles.text(language,"accesscode").." · "..tostring(result.word or"—")
  if result.reason=="spy_guessed"then matchUI.resultTitle.Text=matchUI.caseFiles.text(language,"codeAttempt").." · ✓"end
 end
 local receipt=matchUI.rewardReceipt or {state="saving"}
 local won=receipt.won
 if won==nil then won=(player.UserId==result.spyId)==(result.caught~=true) end
 local role=player.UserId==result.spyId and (english and "SPY" or "ШПИОН") or (english and "AGENT" or "АГЕНТ")
 matchUI.resultOutcome.Text=(won and (english and "VICTORY" or "ПОБЕДА") or (english and "DEFEAT" or "ПОРАЖЕНИЕ")).." · "..role
 matchUI.resultOutcome.TextColor3=won and Color3.fromRGB(164,206,180) or COLORS.IvorySoft
 matchUI.resultRule.BackgroundColor3=matchUI.resultOutcome.TextColor3
 local reveal={}
 for _,info in ipairs(state.players or {})do
  reveal[#reveal+1]=tostring(info.displayName or info.name or "Player").." · "..MatchI18n.text(language,info.userId==result.spyId and "Шпион"or "Агент")
 end
 matchUI.resultReveal.Text=table.concat(reveal,"\n")
 local revealHeight=math.max(58,#reveal*22+18)
 matchUI.resultReveal.Size=UDim2.new(1,-44,0,revealHeight)
 matchUI.resultReward.Position=UDim2.fromOffset(22,200+revealHeight)
 matchUI.resultStats.Position=UDim2.fromOffset(22,240+revealHeight)
 matchUI.caseReviewButton.Position=UDim2.fromOffset(22,274+revealHeight)
 matchUI.resultContent.CanvasSize=UDim2.fromOffset(0,matchUI.caseReviewButton.Visible and 330+revealHeight or 274+revealHeight)

 matchUI.resultStats.Text=""
 if receipt.state=="saved" then
  matchUI.resultReward.Text=string.format(english and "Saved · +%d Rolls · +%d XP" or "Сохранено · +%d Rolls · +%d опыта",receipt.rolls or 0,receipt.xp or 0)
  matchUI.resultStats.Text=string.format(english and "%d wins · %d rounds" or "%d побед · %d партий",receipt.wins or 0,receipt.rounds or 0)
  if receipt.studio then matchUI.resultStats.Text=matchUI.resultStats.Text..(english and " · Studio session" or " · сессия Studio") end
 elseif receipt.state=="pending" then
  matchUI.resultReward.Text=english and "Save pending · reward queued for recovery" or "Сохранение ожидается · награда в очереди"
 elseif receipt.state=="failed" then
  matchUI.resultReward.Text=english and "Save could not be confirmed · rejoin to check" or "Не удалось подтвердить сохранение · переподключись для проверки"
 elseif receipt.state=="ineligible" then
  matchUI.resultReward.Text=english and "No reward · participation requirement not met" or "Без награды · недостаточно участия"
 else
  matchUI.resultReward.Text=english and "Saving your reward and statistics…" or "Сохраняем награду и статистику…"
 end
end
local function handleReward(data)
 if type(data)~="table" or type(data.state)~="string" then return end
 matchUI.rewardReceipt=data
 paintResult()
end
player:GetAttributeChangedSignal("SpyLanguage"):Connect(paintResult)

local function showResult(state)
 if not state.result then return end
 phaseAnimationToken += 1
 matchUI.lastResultState=state
 hideChatCompletely()
 showControls(false)
 closeVote()
 task.spawn(returnCard)
 cinemaBars(false)
 resultCamera()
 releaseCursor()
 matchUI.phaseRoot.GroupTransparency=1
 paintResult()
 matchUI.resultRoot.Visible=true
 matchUI.resultRoot.GroupTransparency=1
 tween(matchUI.resultRoot,.32,{GroupTransparency=0})
end

---------------------------------------------------------------------
-- INTRO
---------------------------------------------------------------------

local function beginIntro(state)
	if introStarted then
		return
	end

	introStarted = true

	hideTopicVote()

	hideChatCompletely()

	showControls(false)

	lockCursor()

	cinemaBars(true)

	introCamera(state)
	playIntroBriefing(state)

	setPhase(
		"Раздаём карты",

		state.category
			and (
				"Тема · "
				.. tostring(state.category)
			)
			or ""
	)

	revealGame()

	dealCards(state.players, state)
end

---------------------------------------------------------------------
-- STATE EVENTS
---------------------------------------------------------------------

local function handleState(state)
	if type(state) ~= "table" then
		return
	end

	if state.phase == "VoteAccepted" then
		return
	end

	currentState = state
	if matchUI.dossierController then
        local ok,detail=pcall(matchUI.dossierController.updateState,state)
        if not ok then warn("[MatchDossier state] "..tostring(detail))end
    end
	updateAgentBadge(state)

	local phase = state.phase
	if phase == "Vote" then
		if not voteTickSound.IsPlaying then voteTickSound:Play() end
	else
		stopMatchSound(voteTickSound)
	end
	if phase ~= lastPhase then
		if phase == "TopicChosen" then
			playMatchSound(phaseChimeSound, 1.08)
		elseif phase == "Vote" then
			playMatchSound(phaseChimeSound, 0.90)
		elseif phase == "ExtraRound" then
			playMatchSound(phaseChimeSound, 0.96)
		elseif phase == "Result" then
			playMatchSound(phaseChimeSound, 0.80)
		end
	end
	-- A late snapshot is current state, not permission to replay an old deal.
	if phase ~= "Intro" and dealer then stopDealer(true) end
	if phase ~= "Role" and lastPhase == "Role" then
		roleSequence += 1
		cardFollowHand = false
		clearArmPose()
		matchUI.cutFade.Visible = false
		forceCharacterVisible = false
	end

	local needsCards =
		phase == "Role"
		or phase == "Hint"
		or phase == "Discuss"
		or phase == "Vote"
		or phase == "ExtraRound"
		or phase == "Result"

	if #cards == 0
		and needsCards
		and #(state.players or {}) > 0
	then
		dealCards(state.players, state)
	end

	if phase ~= "Role" then
		recoverOwnCard()
	end

	-------------------------------------------------------------
	-- TOPIC VOTE
	-------------------------------------------------------------

	if phase == "TopicVote" then
		revealGame()

		cinemaBars(false)

		hideChatCompletely()

		showControls(false)

		if not seatedCameraActive then
			startSeatedCamera(state)
		end

		releaseCursor()

		setPhase(
			"Выбор темы",
			"Решите, о чём будет эта партия."
		)

		updateTopicVote(state)
        matchUI.phaseRoot.GroupTransparency=1

		-------------------------------------------------------------
		-- TOPIC CHOSEN
		-------------------------------------------------------------

	elseif phase == "TopicChosen" then
		revealGame()

		showControls(false)

		hideChatCompletely()

		releaseCursor()

		setPhase(
			"Тема выбрана",
			""
		)

		showChosenTopic(state)

		-------------------------------------------------------------
		-- INTRO
		-------------------------------------------------------------

	elseif phase == "Intro" then
		beginIntro(state)

		-------------------------------------------------------------
		-- ROLE
		-------------------------------------------------------------

	elseif phase == "Role" then
		revealGame()
		setPhase(
			"Твоя карта",
			"Посмотри и запомни."
		)

		if lastPhase ~= "Role" then
			task.spawn(
				revealOwnCard,
				state
			)
		end

		-------------------------------------------------------------
		-- HINT
		-------------------------------------------------------------

	elseif phase == "Hint" then
		closeVote()
        if lastPhase~="Hint"then releaseCursor()end

		forceCharacterVisible = false

		clearArmPose()

		cinemaBars(false)

		if not seatedCameraActive then
			startSeatedCamera(state)
		end

		showControls(true)

		ensureChatSession()

		if previousTurnId ~= state.turnUserId then
			previousTurnId = state.turnUserId

			hintSent = false
		end

		updateChatPlaceholder()

		---------------------------------------------------------
		-- НОВЫЙ КРАСИВЫЙ БАННЕР ОЧЕРЕДИ
		---------------------------------------------------------

		setTurnPhase(state)

		-------------------------------------------------------------
		-- DISCUSS
		-------------------------------------------------------------

	elseif phase == "Discuss" then
		closeVote()
        if lastPhase~="Discuss"then releaseCursor()end

		lastTurnBannerUserId = nil

		if not seatedCameraActive then
			startSeatedCamera(state)
		end

		cinemaBars(false)

		showControls(true)

		ensureChatSession()

		updateChatPlaceholder()

		setPhase(
			"Обсуждение",
			"Сопоставь подсказки и реши, кому ты не веришь."
		)

		-------------------------------------------------------------
		-- VOTE
		-------------------------------------------------------------

	elseif phase == "Vote" then
		lastTurnBannerUserId = nil

		setPhase(
			"Голосование",
			"Обвини игрока или попроси ещё один круг."
		)

		if lastPhase ~= "Vote" then openVote(state) end
        matchUI.phaseRoot.GroupTransparency=1

		-------------------------------------------------------------
		-- EXTRA ROUND
		-------------------------------------------------------------

	elseif phase == "ExtraRound" then
		closeVote()

		lastTurnBannerUserId = nil

		hideChatCompletely()

		showControls(false)

		cinemaBars(false)

		startSeatedCamera(state)

		releaseCursor()

		setPhase(
			"Ещё один круг",
			"Большинство решило собрать ещё одну подсказку."
		)

		-------------------------------------------------------------
		-- RESULT
		-------------------------------------------------------------

	elseif phase == "Result" then
		lastTurnBannerUserId = nil

		matchUI.phaseRoot.GroupTransparency=1

		if lastPhase ~= "Result" then
			showResult(state)
		end

		-------------------------------------------------------------
		-- FINISHED
		-------------------------------------------------------------

	elseif phase == "Finished" then
		stopMatchSound(voteTickSound)
		stopDealer(false)
		clearCards()
		stopSeatedCamera()
		cancelCameraSequence()
		endCinematicGrade()
		briefingToken += 1
		matchUI.briefingRoot.Visible = false
		matchUI.agentBadge.Visible = false

		clearArmPose()

		hideTopicVote()

		hideChatCompletely()

		showControls(false)

		closeVote()

		cardMode = nil

		releaseCursor()
		matchUI.phaseRoot.GroupTransparency=1
		if state.result then
			matchUI.lastResultState=state
			paintResult()
			matchUI.resultRoot.Visible=true
			matchUI.resultRoot.GroupTransparency=0
		end
		cinemaBars(false)
		blackout.Visible=false
		matchUI.blackoutText.Visible=false

	end

    matchUI.agentBadge.Visible=false

	lastPhase = phase
	if matchUI.refreshGuide then matchUI.refreshGuide() end
 if matchUI.refreshQuestion then matchUI.refreshQuestion()end
end

---------------------------------------------------------------------
-- SECRET CARD
---------------------------------------------------------------------

local function handleSecret(data)
	if type(data) ~= "table" then
		return
	end

	secretData = data
	if matchUI.dossierController then
        local ok,detail=pcall(matchUI.dossierController.updateSecret,data)
        if not ok then warn("[MatchDossier card] "..tostring(detail))end
    end

	if currentState
		and currentState.phase == "Role"
		and not ownCard
	then
		task.spawn(
			revealOwnCard,
			currentState
		)
	end
end

-- Replay buffered events in arrival order, then switch to live handlers.
-- No event can be lost between draining the queue and assigning the handlers:
-- Luau does not interleave another callback until this thread yields.
local nextPendingEvent = 1
while pendingMatchEvents[nextPendingEvent] do
	local event = pendingMatchEvents[nextPendingEvent]
	if event[1] == "state" then
		handleState(event[2])
	elseif event[1]=="reward" then
		handleReward(event[2])
	else
		handleSecret(event[2])
	end
	nextPendingEvent += 1
end
table.clear(pendingMatchEvents)
stateHandler = handleState
cardHandler = handleSecret
rewardHandler = handleReward

-- Personal settings can change while a shot is running. Freeze the current
-- composition, settle a deal and remove optional effects without restarting it.
local function applyCinematicPreferences()
	if player:GetAttribute("SpyReducedMotion") == true then
		if dealer then stopDealer(true) end
		cancelCameraSequence()
	elseif player:GetAttribute("SpyCameraMotion") == false then
		cancelCameraSequence()
	end
	if player:GetAttribute("SpyEffects") == false then clearCinematicEffects() end
	for _, name in ipairs({"SpyMatchVisual_Bloom", "SpyMatchVisual_Grade"}) do
		local effect = Lighting:FindFirstChild(name)
		if effect then effect.Enabled = player:GetAttribute("SpyEffects") ~= false end
	end
	if seatedCameraActive then
		camera.FieldOfView = math.clamp(tonumber(player:GetAttribute("SpyFOV")) or 70, 60, 90)
	end
end
for _, attribute in ipairs({"SpyReducedMotion", "SpyCameraMotion", "SpyEffects", "SpyFOV"}) do
	player:GetAttributeChangedSignal(attribute):Connect(applyCinematicPreferences)
end
applyCinematicPreferences()
script.Destroying:Connect(function()
	roleSequence += 1
	stopDealer(false)
	cancelCameraSequence()
	clearCinematicEffects()
	clearCards()
end)

task.spawn(function()
	if not snapshotFunction then
		return
	end

	local ok, snapshot = pcall(function()
		return snapshotFunction:InvokeServer()
	end)

	if not ok or type(snapshot) ~= "table" then
		return
	end

	if type(snapshot.reward)=="table" then handleReward(snapshot.reward) end
	if type(snapshot.secret) == "table" then
		handleSecret(snapshot.secret)
	end

	if type(snapshot.state) == "table" then
		handleState(snapshot.state)
	end
end)

---------------------------------------------------------------------
-- INPUT
---------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if player:GetAttribute('SpyCharacterMenuOpen')==true then return end
	if input.KeyCode == Enum.KeyCode.Slash then
		-- Native Roblox chat owns Slash and focus.
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.C then
		toggleCard()

		return
	end

	if input.KeyCode == Enum.KeyCode.LeftAlt
		or input.KeyCode == Enum.KeyCode.RightAlt
	then
		if not seatedCameraActive then
			return
		end

		if currentState
			and currentState.phase == "TopicVote"
		then
			return
		end

		if cursorReleased then
			lockCursor()
		else
			releaseCursor()
		end
	end
end)

---------------------------------------------------------------------
-- ARM UPDATE
---------------------------------------------------------------------

local function updateArm(dt)
	if not armRig
		or not armPose
	then
		return
	end

	local alpha =
		1 - math.exp(-10 * dt)

	if armRig.rigType == "R15" then
		local shoulderTarget
		local elbowTarget
		local wristTarget

		if armPose == "reach" then
			shoulderTarget =
				CFrame.Angles(
					math.rad(-42),
					math.rad(-5),
					math.rad(8)
				)

			elbowTarget =
				CFrame.Angles(
					math.rad(-27),
					0,
					math.rad(-3)
				)

			wristTarget =
				CFrame.Angles(
					math.rad(3),
					math.rad(-6),
					math.rad(4)
				)
		else
			shoulderTarget =
				CFrame.Angles(
					math.rad(-63),
					math.rad(-4),
					math.rad(9)
				)

			elbowTarget =
				CFrame.Angles(
					math.rad(-47),
					0,
					math.rad(-4)
				)

			wristTarget =
				CFrame.Angles(
					math.rad(6),
					math.rad(-5),
					math.rad(5)
				)
		end

		if armRig.shoulder then
			armRig.shoulder.Transform =
				armRig.shoulder.Transform:Lerp(
					shoulderTarget,
					alpha
				)
		end

		if armRig.elbow then
			armRig.elbow.Transform =
				armRig.elbow.Transform:Lerp(
					elbowTarget,
					alpha
				)
		end

		if armRig.wrist then
			armRig.wrist.Transform =
				armRig.wrist.Transform:Lerp(
					wristTarget,
					alpha
				)
		end
	end
end

---------------------------------------------------------------------
-- SEATED CAMERA UPDATE
---------------------------------------------------------------------

local function updateSeatedCamera(dt)
	if not seatedCameraActive or player:GetAttribute('SpyCharacterMenuOpen')==true then
		return
	end

	local character = player.Character

	local head =
		character
		and character:FindFirstChild("Head")

	if not head then
		return
	end

	if (not cursorReleased or matchUI.cameraDragging)
		and not UserInputService:GetFocusedTextBox()
	then
		local delta =
			UserInputService:GetMouseDelta()

		cameraYawOffset =
			math.clamp(
				cameraYawOffset
				- delta.X
				* CAMERA_SENSITIVITY,

				-CAMERA_YAW_LIMIT,
				CAMERA_YAW_LIMIT
			)

		cameraPitch =
			math.clamp(
				cameraPitch
				- delta.Y
				* CAMERA_SENSITIVITY,

				CAMERA_PITCH_MIN,
				CAMERA_PITCH_MAX
			)
	end

	local yaw =
		cameraBaseYaw
		+ cameraYawOffset

	local rotation =
		CFrame.Angles(
			0,
			yaw,
			0
		)
		* CFrame.Angles(
			cameraPitch,
			0,
			0
		)

	local target,showHead
    if MatchPresentation then
        target,showHead=MatchPresentation.cameraFrame(head.Position,rotation,matchUI.seatedView,cardMode=="open")
        MatchPresentation.applyCameraVisibility(character,showHead)
    else
        hideHeadForPOV()
        target=CFrame.lookAt(head.Position+Vector3.new(0,.04,0),head.Position+Vector3.new(0,.04,0)+rotation.LookVector)
    end
    if player:GetAttribute("SpyReducedMotion")==true or player:GetAttribute("SpyCameraMotion")==false then camera.CFrame=target
    else camera.CFrame=camera.CFrame:Lerp(target,1-math.exp(-12*(dt or 1/60))) end
end

---------------------------------------------------------------------
-- RENDER
---------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	if forceCharacterVisible then
		showLocalAvatar()
	end

	updateSeatedCamera(dt)

	updateArm(dt)

	-------------------------------------------------------------
	-- CARD FOLLOWS HAND
	-------------------------------------------------------------

	if cardFollowHand
		and ownCard
		and ownCard.part
		and ownCard.part.Parent
		and armRig
		and armRig.hand
	then
		local target =
			armRig.hand.CFrame
			* CFrame.new(
				0,
				-0.20,
				-0.28
			)
			* CFrame.Angles(
				math.rad(4),
				math.rad(90),
				math.rad(-4)
			)

		local alpha =
			1 - math.exp(-14 * dt)

		ownCard.part.CFrame =
			ownCard.part.CFrame:Lerp(
				target,
				alpha
			)
	end

	-------------------------------------------------------------
	-- CAMERA RELATIVE CARD
	-------------------------------------------------------------

	if not cardAnimating
		and not cardFollowHand
		and ownCard
		and ownCard.part
		and ownCard.part.Parent
	then
		local target

		if cardMode == "open" then
			target = openFrontCF()
		elseif cardMode == "closed" then
			target = closedCardCF()
		end

		if target then
			local alpha =
				1 - math.exp(-14 * dt)

			ownCard.part.CFrame =
				ownCard.part.CFrame:Lerp(
					target,
					alpha
				)
		end
	end

	-------------------------------------------------------------
	-- TIMER
	-------------------------------------------------------------

	if currentState then
		local endAt =
			tonumber(
				currentState.endAt
			)
			or 0

		if endAt > 0 then
			local secondsLeft =
				math.max(
					0,
					math.ceil(
						endAt
						- workspace:GetServerTimeNow()
					)
				)

			matchUI.timer.Text = string.format("%02d:%02d",math.floor(secondsLeft/60),secondsLeft%60)
            local key=tostring(currentState.phase)..":"..tostring(currentState.turnUserId)..":"..tostring(endAt)
            if clockKey~=key then clockKey=key;clockWindow=math.max(1,endAt-workspace:GetServerTimeNow()) end
            matchUI.clockFill.Size=UDim2.fromScale(math.clamp((endAt-workspace:GetServerTimeNow())/clockWindow,0,1),1)
            matchUI.clockFill.BackgroundColor3=secondsLeft<=10 and COLORS.Danger or COLORS.Brass
            matchUI.voteTimer.Text=matchUI.timer.Text
            matchUI.topicTimer.Text=matchUI.timer.Text
            matchUI.timer.TextColor3=secondsLeft<=10 and Color3.fromRGB(232,137,125) or COLORS.Ivory
            matchUI.voteTimer.TextColor3=matchUI.timer.TextColor3
            matchUI.topicTimer.TextColor3=matchUI.timer.TextColor3
		else
			matchUI.timer.Text = ""
            matchUI.clockFill.Size=UDim2.fromScale(0,1)
		end
	else
		matchUI.timer.Text = ""
	end
end)

---------------------------------------------------------------------
-- INITIAL
---------------------------------------------------------------------

player.CameraMinZoomDistance = 0.5
player.CameraMaxZoomDistance = 0.5

matchUI.phaseRoot.GroupTransparency = 1
matchUI.controls.GroupTransparency = 1

matchUI.topicRoot.Visible = false

matchUI.chatFrame.Visible = false
matchUI.collapsedChat.Visible = false

matchUI.voteBackdrop.Visible = false

matchUI.resultRoot.Visible = false

blackout.Visible = true
blackout.BackgroundTransparency = 0.10

matchUI.blackoutText.Visible = false

---------------------------------------------------------------------
-- Match controls stay clickable. Hold RMB (or drag empty scene on touch) to look.
do
matchUI.chatShortcut.Activated:Connect(function()
 local event=playerGui:FindFirstChild('SpyOpenChat');if event and event:IsA('BindableEvent')then event:Fire()end
end)
local function toggleTableView()
    if not seatedCameraActive or player:GetAttribute('SpyCharacterMenuOpen')==true then return end
    matchUI.seatedView=matchUI.seatedView=="table" and "pov" or "table"
    return matchUI.seatedView=="table"
end
matchUI.cardShortcut.Activated:Connect(function()
 if currentState and currentState.case then
  local event=playerGui:FindFirstChild("SpyOpenCase");if event then event:Fire()end
 else toggleCard()end
end)
matchUI.viewShortcut.Activated:Connect(toggleTableView)
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or not seatedCameraActive or UserInputService:GetFocusedTextBox()
        or player:GetAttribute('SpyCharacterMenuOpen')==true then return end
    if input.KeyCode==Enum.KeyCode.V then toggleTableView()
    elseif input.UserInputType==Enum.UserInputType.MouseButton2 then
        matchUI.cameraDragging=true;UserInputService.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
    elseif input.UserInputType==Enum.UserInputType.Touch then
        matchUI.cameraTouch=input;matchUI.cameraTouchPosition=input.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input~=matchUI.cameraTouch or not seatedCameraActive or UserInputService:GetFocusedTextBox()
        or player:GetAttribute('SpyCharacterMenuOpen')==true then return end
    local delta=input.Position-(matchUI.cameraTouchPosition or input.Position)
    matchUI.cameraTouchPosition=input.Position
    cameraYawOffset=math.clamp(cameraYawOffset-delta.X*CAMERA_SENSITIVITY,-CAMERA_YAW_LIMIT,CAMERA_YAW_LIMIT)
    cameraPitch=math.clamp(cameraPitch-delta.Y*CAMERA_SENSITIVITY,CAMERA_PITCH_MIN,CAMERA_PITCH_MAX)
end)
player:GetAttributeChangedSignal('SpyCharacterMenuOpen'):Connect(function()
    if player:GetAttribute('SpyCharacterMenuOpen')==true then
        matchUI.cameraDragging=false;matchUI.cameraTouch=nil;matchUI.cameraTouchPosition=nil
        releaseCursor()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input==matchUI.cameraTouch then matchUI.cameraTouch=nil;matchUI.cameraTouchPosition=nil end
    if input.UserInputType==Enum.UserInputType.MouseButton2 then
        matchUI.cameraDragging=false
        if cursorReleased then UserInputService.MouseBehavior=Enum.MouseBehavior.Default end
    end
end)
task.defer(function()
    local ok,error=pcall(function()
        local module=ReplicatedStorage.SpyShared:FindFirstChild("MatchDossier")
        if not module then return end
        local dossier=require(module).start({gui=gui,player=player,remotes=ReplicatedStorage.MatchRemotes,externallyManaged=true,
            initialState=currentState,initialSecret=secretData,onOpen=releaseCursor,onView=toggleTableView})
        matchUI.dossierController=dossier
        script.Destroying:Connect(dossier.destroy)
    end)
    player:SetAttribute("SpyDossierStatus",ok and "ready" or "failed")
    if not ok then warn("[MatchDossier] "..tostring(error))end
end)

end

-- SPY CLUB CUSTOM CHARACTER MOTION V1
-- Procedural polish only. It never moves the root/camera and disables itself
-- while seated, so the Director's Cut cutscenes keep full control.
---------------------------------------------------------------------
do
    local motionToken = 0
    local motionConnection
    local fallbackTracks = {}

    local function stopFallback()
        for _, track in pairs(fallbackTracks) do
            pcall(function()
                track:Stop(0.18)
                track:Destroy()
            end)
        end
        fallbackTracks = {}
    end

    local function bindClubMotion(character)
        motionToken += 1
        local token = motionToken
        if motionConnection then
            motionConnection:Disconnect()
            motionConnection = nil
        end
        stopFallback()

        local humanoid = character:WaitForChild("Humanoid", 8)
        local root = character:WaitForChild("HumanoidRootPart", 8)
        if not humanoid or not root then return end

        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 3)
        local waist, neck
        local previous = root.CFrame.LookVector
        local turn, lean, elapsed = 0, 0, 0
        local fallback = false
        local playing = ""

        local function makeTrack(id, priority)
            if not animator then return nil end
            local animation = Instance.new("Animation")
            animation.AnimationId = "rbxassetid://" .. id
            local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
            animation:Destroy()
            if not ok or not track then return nil end
            track.Priority = priority
            track.Looped = true
            return track
        end

        task.delay(1, function()
            if motionToken ~= token or not character.Parent then return end
            if character:FindFirstChild("Animate") then return end
            fallbackTracks.idle = makeTrack(507766666, Enum.AnimationPriority.Idle)
            fallbackTracks.walk = makeTrack(507777826, Enum.AnimationPriority.Movement)
            fallback = true
        end)

        character.ChildAdded:Connect(function(child)
            if motionToken == token and child.Name == "Animate" and fallback then
                stopFallback()
                fallback = false
                playing = ""
            end
        end)

        motionConnection = RunService.PreSimulation:Connect(function(dt)
            if motionToken ~= token or not character.Parent or humanoid.Health <= 0 then return end
            elapsed += dt

            if not waist or not waist.Parent then
                local upper = character:FindFirstChild("UpperTorso")
                local lower = character:FindFirstChild("LowerTorso")
                local head = character:FindFirstChild("Head")
                waist = (lower and lower:FindFirstChild("Waist")) or (upper and upper:FindFirstChild("Waist"))
                neck = (upper and upper:FindFirstChild("Neck")) or (head and head:FindFirstChild("Neck"))
            end

            local direction = root.CFrame.LookVector
            local current = Vector3.new(direction.X, 0, direction.Z)
            local old = Vector3.new(previous.X, 0, previous.Z)
            local angle = math.atan2(old:Cross(current).Y, old:Dot(current))
            previous = direction

            local moving = humanoid.MoveDirection.Magnitude > 0.07
            local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
            local seated = humanoid.Sit
            local localMove = root.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
            local targetTurn = moving and onGround and not seated and math.clamp(angle * 3, -0.14, 0.14) or 0
            local targetLean = moving and onGround and not seated and math.clamp(-localMove.X * 0.045, -0.045, 0.045) or 0
            turn += (targetTurn - turn) * math.clamp(dt * 8, 0, 1)
            lean += (targetLean - lean) * math.clamp(dt * 7, 0, 1)

            local breath = math.sin(elapsed * 2.15) * (moving and 0.002 or 0.009)
            if waist and not seated then
                waist.Transform = waist.Transform * CFrame.Angles(breath * 0.35, turn, breath + lean)
            end
            if neck and not seated then
                neck.Transform = neck.Transform * CFrame.Angles(-breath * 0.5, -turn * 0.35, -lean * 0.35)
            end

            if fallback then
                local nextState = seated and "" or (moving and onGround and "walk" or "idle")
                if nextState ~= playing then
                    if fallbackTracks[playing] then fallbackTracks[playing]:Stop(0.2) end
                    if fallbackTracks[nextState] then fallbackTracks[nextState]:Play(0.22) end
                    playing = nextState
                end
                if nextState == "walk" and fallbackTracks.walk then
                    fallbackTracks.walk:AdjustSpeed(math.clamp(root.AssemblyLinearVelocity.Magnitude / 13, 0.7, 1.35))
                end
            end
        end)
    end

    player.CharacterAdded:Connect(bindClubMotion)
    if player.Character then task.spawn(bindClubMotion, player.Character) end
end
end
local bootOK, bootError = xpcall(bootMatchClient, debug.traceback)
if bootOK then
	game:GetService("Players").LocalPlayer:SetAttribute("SpyMatchUIInitialized",true)
end
if not bootOK then
	ReplicatedStorage:SetAttribute("SpyMatchBootError", "M22-CLIENT")
	warn("[SPY M22-CLIENT] " .. tostring(bootError))
end
