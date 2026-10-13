-- Private observation tools. No messages, network actions, rewards or hidden roles.
local Players=game:GetService("Players")
local Presentation=require(script.Parent.MatchPresentation)
local Catalog=require(script.Parent.Catalog)
local HUD=require(script.Parent.MatchHUD)
local Dossier={}
local INK=Color3.fromRGB(25,27,31)
local SURFACE=Color3.fromRGB(38,39,42)
local WHITE=Color3.fromRGB(244,240,231)
local MUTED=Color3.fromRGB(188,187,181)
local ACCENT=Color3.fromRGB(221,193,151)

function Dossier.start(context)
    local gui,player,remotes=context.gui,context.player or Players.LocalPlayer,context.remotes
    local state,secret=context.initialState,context.initialSecret
    local open,lookTab=false,false
    local connections,rows={},{}
    local function english()return player:GetAttribute("SpyLanguage")=="en"end
    local function text(ru,en)return english()and en or ru end
    local function make(class,name,parent,props)
        local object=Instance.new(class);object.Name=name
        for k,v in pairs(props)do object[k]=v end
        object.Parent=parent;return object
    end
    local function rounded(object,radius)
        make("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius)})
    end
    local function label(name,parent,position,size,sizeText)
        return make("TextLabel",name,parent,{Position=position,Size=size,BackgroundTransparency=1,Text="",
            TextColor3=WHITE,Font=Enum.Font.BuilderSansBold,TextSize=sizeText,TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=173})
    end
    local launcher=make("TextButton","DossierButton",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,138),
        Size=UDim2.fromOffset(124,38),BackgroundColor3=INK,BorderSizePixel=0,Text="ДОСЬЕ",
        Font=Enum.Font.BuilderSansBold,TextSize=13,TextColor3=WHITE,Visible=false,ZIndex=171})
    rounded(launcher,12)
    HUD.register(player:FindFirstChild("PlayerGui"),launcher,20)
    local panel=make("Frame","DossierPanel",gui,{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-18,.5,-10),
        Size=UDim2.fromOffset(366,438),BackgroundColor3=INK,BorderSizePixel=0,Visible=false,Active=true,ZIndex=172})
    rounded(panel,16);make("UIStroke","Outline",panel,{Color=ACCENT,Transparency=.75})
    local heading=label("Heading",panel,UDim2.fromOffset(18,15),UDim2.new(1,-156,0,32),24)
    local close=make("TextButton","CloseDossier",panel,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,14),
        Size=UDim2.fromOffset(32,32),BackgroundTransparency=1,Text="×",Font=Enum.Font.BuilderSansBold,
        TextSize=23,TextColor3=MUTED,ZIndex=174})
    local view=make("TextButton","TableView",panel,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-53,0,17),
        Size=UDim2.fromOffset(82,28),BackgroundColor3=SURFACE,BorderSizePixel=0,Text="КАМЕРА",
        Font=Enum.Font.BuilderSansBold,TextSize=11,TextColor3=ACCENT,ZIndex=174})
    rounded(view,4)
    local privateRole=label("PrivateRole",panel,UDim2.fromOffset(18,55),UDim2.new(1,-36,0,36),15)
    privateRole.TextWrapped=true;privateRole.TextTruncate=Enum.TextTruncate.None
    privateRole.TextColor3=ACCENT;privateRole.TextYAlignment=Enum.TextYAlignment.Top
    local function tab(name,x)
        local button=make("TextButton",name,panel,{Position=UDim2.new(x,18-x*28,0,96),Size=UDim2.new(.5,-22,0,32),
            BackgroundColor3=SURFACE,Text="",BorderSizePixel=0,TextColor3=WHITE,Font=Enum.Font.BuilderSansBold,TextSize=13,ZIndex=174})
        rounded(button,4);return button
    end
    local tableTab=tab("PlayersTab",0)
    local ownTab=tab("OwnLookTab",.5)
    local list=make("ScrollingFrame","ObservationRows",panel,{Position=UDim2.fromOffset(18,138),Size=UDim2.new(1,-36,1,-204),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=MUTED,
        CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=173})
    make("UIListLayout","Rows",list,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
    local ownLook=make("Frame","OwnLook",panel,{Position=list.Position,Size=list.Size,BackgroundColor3=SURFACE,
        BorderSizePixel=0,Visible=false,ZIndex=173})
    rounded(ownLook,6)
    local ownDispose=Presentation.attachPortrait(ownLook,player,{fullBody=true})
    ownLook.LivePortrait.Size=UDim2.new(1,0,1,-34)
    local outfit=label("EquippedName",ownLook,UDim2.new(0,10,1,-34),UDim2.new(1,-20,0,26),13)
    outfit.ZIndex=176;outfit.BackgroundTransparency=.15;outfit.BackgroundColor3=INK
    local helper=label("ObservationHelp",panel,UDim2.new(0,18,1,-59),UDim2.new(1,-36,0,44),12)
    helper.Font=Enum.Font.BuilderSansMedium;helper.TextColor3=MUTED;helper.TextWrapped=true
    helper.TextTruncate=Enum.TextTruncate.None;helper.TextYAlignment=Enum.TextYAlignment.Top
    local function available()
        return player:GetAttribute('SpyCharacterMenuOpen')~=true
            and state and (state.phase=="Hint" or state.phase=="Discuss" or state.phase=="ExtraRound")
    end
    local promptsRu={"Одна ассоциация. Без названия.","Вспомни звук, цвет или ощущение.","Коротко опиши личный опыт.","Сравни с чем-то знакомым, не называя слово."}
    local promptsEn={"One association. Don't name it.","Think of a sound, colour or feeling.","Briefly describe a personal experience.","Compare it to something familiar without naming it."}
    local function refresh()
        launcher.Visible=available()and not open or false
        panel.Visible=open and available()or false
        heading.Text=text("Досье стола","Table dossier")
        launcher.Text=text("Досье стола","Table dossier")
        if secret and secret.caseFile then
            local m=script.Parent:FindFirstChild("CaseFiles");local ok,files=pcall(require,m)
            if ok then
                heading:SetAttribute("SpyUserText",true);launcher:SetAttribute("SpyUserText",true)
                heading.Text=files.text(player:GetAttribute("SpyLanguage")or"ru","notes");launcher.Text=heading.Text
            end
        end
        tableTab.Text=text("Участники","Players");ownTab.Text=text("Мой образ","My look")
        view.Text=text("КАМЕРА","VIEW")
        list.Visible=not lookTab;ownLook.Visible=lookTab
        tableTab.TextColor3=not lookTab and ACCENT or MUTED;ownTab.TextColor3=lookTab and ACCENT or MUTED
        if secret and secret.caseFile then
            privateRole.Text=secret.caseFile.alibi or""
        elseif secret and secret.role=="detective" and secret.word then
            privateRole.Text=text("Твоё слово: ","Your word: ")..tostring(secret.word)
        elseif secret and secret.role=="spy" then
            privateRole.Text=text("Ты — шпион. Слово неизвестно.","You are the spy. The word is unknown.")
        else privateRole.Text=text("Карточка роли ещё не получена.","Your role card has not arrived yet.")end
        local item=Catalog.ById[player:GetAttribute("SpyEquippedOutfit") or ""]
        outfit.Text=item and (english()and item.en or item.ru)or text("Текущий игровой образ","Current game outfit")
        local live={}
        for index,info in ipairs(state and state.players or {})do
            live[info.userId]=true
            local row=rows[info.userId]
            if not row then
                local root=make("Frame","Participant_"..info.userId,list,{Size=UDim2.new(1,-4,0,62),BackgroundColor3=SURFACE,BorderSizePixel=0,ZIndex=174})
                rounded(root,5)
                local portrait=make("Frame","Portrait",root,{Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset(48,48),BackgroundTransparency=1,ZIndex=175})
                local name=label("Name",root,UDim2.fromOffset(64,9),UDim2.new(1,-143,0,23),15);name.ZIndex=176
                local detail=label("Detail",root,UDim2.fromOffset(64,34),UDim2.new(1,-151,0,18),13);detail.ZIndex=176;detail.TextColor3=MUTED
                local mark=make("TextButton","Mark_"..info.userId,root,{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-8,.5,0),Size=UDim2.fromOffset(68,36),
                    BackgroundColor3=INK,Text="",BorderSizePixel=0,TextColor3=MUTED,Font=Enum.Font.BuilderSansBold,TextSize=12,ZIndex=176})
                rounded(mark,4)
                local id=info.userId
                mark.Activated:Connect(function()if id~=player.UserId then Presentation.cycleMark(id)end end)
                local target=Players:GetPlayerByUserId(id)
                row={root=root,name=name,detail=detail,mark=mark,portrait=portrait,target=target,dispose=Presentation.attachPortrait(portrait,target)};rows[id]=row
            end
            local target=Players:GetPlayerByUserId(info.userId)
            if row.target~=target then row.dispose();row.target=target;row.dispose=Presentation.attachPortrait(row.portrait,target)end
            row.root.LayoutOrder=index;row.name.Text=tostring(info.name or info.username or "Player")
            local speaking=state.phase=="Hint" and state.turnUserId==info.userId
            row.root.BackgroundColor3=speaking and Color3.fromRGB(71,49,45)or SURFACE
            row.detail.Text=info.connected==false and text("Переподключается","Reconnecting")or speaking and text("Сейчас говорит","Speaking now")or text("Место ","Seat ")..tostring(info.seat or index)
            local mark=Presentation.getMark(info.userId)
            row.mark.Text=info.userId==player.UserId and text("Ты","You")or mark=="suspect" and text("Подозр.","Suspect")or mark=="clear" and text("Алиби","Clear")or text("Отметить","Mark")
            row.mark.TextColor3=mark=="suspect" and Color3.fromRGB(231,178,148)or mark=="clear" and Color3.fromRGB(174,197,179)or MUTED
        end
        for id,row in pairs(rows)do if not live[id]then row.dispose();row.root:Destroy();rows[id]=nil end end
        list.CanvasSize=UDim2.fromOffset(0,#(state and state.players or {})*70)
        if state and state.phase=="Hint" and state.turnUserId==player.UserId then
            local index=((tonumber(state.lap)or 1)+(tonumber(state.turnIndex)or 1)-2)%4+1
            helper.Text=(english()and promptsEn or promptsRu)[index]
        else helper.Text=text("Личные отметки видишь только ты. Голос отправляется отдельно.","Only you can see your notes. Cast your vote separately.")end
    end
    local function closePanel()open=false;refresh()end
    local function fit()
        local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        local compact=v.Y<520
        panel.Size=UDim2.fromOffset(math.min(366,v.X-24),math.min(438,math.max(192,v.Y-(compact and 24 or 80))))
        panel.Position=(v.X<520 or compact)and UDim2.new(1,-12,.5,0)or UDim2.new(1,-18,.5,-10)
        heading.Position=UDim2.fromOffset(18,compact and 9 or 15)
        heading.TextSize=compact and 22 or 24
        privateRole.Position=UDim2.fromOffset(18,compact and 46 or 55)
        privateRole.Size=UDim2.new(1,-36,0,compact and 22 or 36)
        privateRole.TextSize=compact and 13 or 15;privateRole.TextWrapped=not compact
        privateRole.TextTruncate=compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
        tableTab.Position=UDim2.fromOffset(18,compact and 75 or 96)
        ownTab.Position=UDim2.new(.5,4,0,compact and 75 or 96)
        list.Position=UDim2.fromOffset(18,compact and 117 or 138)
        list.Size=UDim2.new(1,-36,1,compact and -164 or -204)
        ownLook.Position=list.Position;ownLook.Size=list.Size
        helper.Position=UDim2.new(0,18,1,compact and -38 or -59)
        helper.Size=UDim2.new(1,-36,0,compact and 30 or 44)
        helper.TextSize=compact and 11 or 12
    end
    local function updateState(nextState)
        if type(nextState)~="table" or not nextState.phase or nextState.phase=="VoteAccepted"then return end
        state=nextState;Presentation.updateState(state)
        if not available()then open=false end
        refresh()
    end
    local function updateSecret(card)
        if type(card)=="table"then secret=card;refresh()end
    end
    table.insert(connections,launcher.Activated:Connect(function()if available()then open=true;refresh();if context.onOpen then context.onOpen()end end end))
    table.insert(connections,close.Activated:Connect(closePanel))
    table.insert(connections,tableTab.Activated:Connect(function()lookTab=false;refresh()end))
    table.insert(connections,ownTab.Activated:Connect(function()lookTab=true;refresh()end))
    table.insert(connections,view.Activated:Connect(function()if context.onView then context.onView()end end))
    table.insert(connections,Presentation.MarkChanged:Connect(refresh))
    if not context.externallyManaged then
        table.insert(connections,remotes.State.OnClientEvent:Connect(updateState))
        table.insert(connections,remotes.Card.OnClientEvent:Connect(updateSecret))
    end
    table.insert(connections,player:GetAttributeChangedSignal("SpyLanguage"):Connect(refresh))
    table.insert(connections,player:GetAttributeChangedSignal("SpyCharacterMenuOpen"):Connect(function()
        if player:GetAttribute('SpyCharacterMenuOpen')==true then open=false end
        refresh()
    end))
    table.insert(connections,player:GetAttributeChangedSignal("SpyAppearanceRevision"):Connect(refresh))
    if workspace.CurrentCamera then table.insert(connections,workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit))end
    fit();Presentation.updateState(state);refresh()
    return {close=closePanel,updateState=updateState,updateSecret=updateSecret,destroy=function()
        for _,c in ipairs(connections)do c:Disconnect()end
        for _,row in pairs(rows)do row.dispose()end
        ownDispose();panel:Destroy();launcher:Destroy()
    end}
end
return Dossier
