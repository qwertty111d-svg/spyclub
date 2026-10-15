local Input=game:GetService("UserInputService")
local Http=game:GetService("HttpService")
local Catalog=require(script.Parent.Catalog)
local Config=require(script.Parent.ClubStoreConfig)
local Policy=require(script.Parent.PremiumShopRules)
local Preview=require(script.Parent.Preview3D)
local UI={}
local C={ink=Color3.fromRGB(16,17,20),surface=Color3.fromRGB(26,27,31),velvet=Color3.fromRGB(49,50,56),
    cream=Color3.fromRGB(245,245,247),muted=Color3.fromRGB(168,170,179),brass=Color3.fromRGB(238,238,241),line=Color3.fromRGB(111,113,122)}
local COPY={title={"Магазин","Store"},shortTitle={"Магазин","Store"},coins={"Вещи · монеты","Items · coins"},
    robux={"Rolls · Robux","Rolls · Robux"},buy={"Купить","Buy"},equip={"Надеть","Equip"},equipped={"Надето","Equipped"},
    pending={"Сохраняем…","Saving…"},retry={"Проверить и повторить","Check and retry"},
    hint={"Монеты за матчи и ежедневные награды — для вещей, которые вы выбираете сами.","Match and daily coins buy the pieces you choose."},
    round={"Покупка и переодевание доступны после матча.","Purchases and outfit changes are available after the match."},
    poor={"Не хватает монет. Они доступны за матчи и ежедневные награды.","Earn more coins through matches and daily rewards."},
    bought={"Добавлено в коллекцию. Можно надеть.","Added to your collection. Ready to equip."},
    saved={"Образ сохранён.","Outfit saved."},unavailable={"Пока недоступно. Попробуйте ещё раз.","Unavailable right now. Please try again."},
    owned={"В коллекции","Owned"},character={"Персонаж · H","Character · H"}}
local function make(class,parent,properties)
    local node=Instance.new(class)
    for key,value in pairs(properties or{})do node[key]=value end
    if node:IsA("GuiObject")and parent and parent:IsA("GuiObject")and not(properties and properties.ZIndex)then node.ZIndex=parent.ZIndex+1 end
    node.Parent=parent;return node
end
local function label(parent,name,size,color)
    return make("TextLabel",parent,{Name=name,Text="",Font=Enum.Font.BuilderSansMedium,TextSize=size,
        TextColor3=color or C.cream,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd})
end
local function button(parent,name)
    local node=make("TextButton",parent,{Name=name,Text="",Font=Enum.Font.BuilderSansMedium,TextSize=15,
        TextColor3=C.cream,BackgroundColor3=C.surface,BorderSizePixel=0,AutoButtonColor=false,Selectable=true})
    make("UICorner",node,{CornerRadius=UDim.new(0,4)});return node
end
function UI.create(ctx)
    local self={name="clubStore",visible=false}
    local alive=true
    local selected=Config.Items[1].id
    local attempt,notice,viewport,previewKey,profileSync
    local rows,connections,entries={},{},{}
    for _,group in ipairs({Config.Items,Config.DailyItems})do
        for _,entry in ipairs(group)do entries[#entries+1]=entry end
    end
    local function tr(key)return COPY[key][ctx.language()=="en"and 2 or 1]end
    local function profile()return ctx.profile()or{}end
    local function blocked()
        for _,flag in ipairs({"SpyPhoneActive","SpyTradeOpen","SpyTeleporting","SpyEntryPending","SpyEntryActive"})do
            if ctx.player:GetAttribute(flag)then return true end
        end
        return false
    end
    local function editable()
        return profile().ready==true and not profile().pendingTrade and not Policy.activeRound(ctx.state())and not blocked()
    end
    local overlay=make("Frame",ctx.gui,{Name="ClubStoreOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,
        BackgroundTransparency=.70,BorderSizePixel=0,Visible=false,Active=true,ZIndex=80})
    local dismiss=make("TextButton",overlay,{Name="DismissClubStore",Text="",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        AutoButtonColor=false,Selectable=false,ZIndex=81})
    local sheet=make("Frame",overlay,{Name="ClubStoreSheet",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundColor3=C.surface,BackgroundTransparency=.18,BorderSizePixel=0,ClipsDescendants=true,Active=true,ZIndex=82})
    make("UICorner",sheet,{CornerRadius=UDim.new(0,2)})
    make("UIStroke",sheet,{Color=C.line,Transparency=.25})
    local title=label(sheet,"CollectionTitle",34);title.Font=Enum.Font.Garamond
    local wallet=label(sheet,"CoinBalance",18,C.brass);wallet.TextXAlignment=Enum.TextXAlignment.Right
    local close=button(sheet,"CloseClubStore");close.Text="×";close.TextSize=26;close.BackgroundTransparency=1
    local coinsTab=button(sheet,"StoreCoinsTab");coinsTab.TextColor3=C.brass;coinsTab.BackgroundTransparency=1
    local robuxTab=button(sheet,"StoreRobuxTab");robuxTab.BackgroundTransparency=1
    local rule=make("Frame",sheet,{Name="StoreHeaderRule",BackgroundColor3=C.line,BorderSizePixel=0})
    local hero=make("Frame",sheet,{Name="CollectionPreview",BackgroundColor3=C.velvet,BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true})
    make("UICorner",hero,{CornerRadius=UDim.new(0,4)})
    local list=make("ScrollingFrame",sheet,{Name="CollectionList",BackgroundTransparency=1,BorderSizePixel=0,
        CanvasSize=UDim2.new(),ScrollBarThickness=2,ScrollBarImageColor3=C.brass,ScrollingDirection=Enum.ScrollingDirection.Y})
    local itemName=label(sheet,"CollectionItemName",29);itemName.Font=Enum.Font.Garamond
    local price=label(sheet,"CollectionPrice",18,C.brass)
    local action=button(sheet,"CollectionAction")
    action.TextXAlignment=Enum.TextXAlignment.Center
    local status=label(sheet,"CollectionStatus",12,C.muted);status.TextWrapped=true;status.TextTruncate=Enum.TextTruncate.None
    local back=button(sheet,"StoreToCharacter");back.BackgroundTransparency=1;back.TextSize=13
    for index,offer in ipairs(entries)do
        local row=button(list,"StoreItem_"..offer.id);row.TextXAlignment=Enum.TextXAlignment.Left
        local art=make("Frame",row,{Name="ItemArt",BackgroundTransparency=1})
        local name=label(row,"CollectionRowName",16)
        local cost=label(row,"CollectionRowPrice",14,C.muted)
        local marker=label(row,"SelectedCollectionMark",20,C.brass);marker.Text="›"
        local line=make("Frame",row,{Name="CollectionRowRule",BackgroundColor3=C.line,BackgroundTransparency=.4,BorderSizePixel=0})
        rows[offer.id]={frame=row,name=name,cost=cost,marker=marker,line=line,art=art,index=index}
        row.Activated:Connect(function()
            if attempt then return end
            selected=offer.id;notice=nil;self:update()
        end)
    end
    local gridColumns,rowHeight=2,138
    local function layoutRows()
        local count=0
        local rowWidth=(list.Size.X.Offset-8*(gridColumns-1)-4)/gridColumns
        for _,offer in ipairs(entries)do
            local row=rows[offer.id]
            row.frame.Visible=not offer.dailyOnly or(profile().owned or{})[offer.id]==true
            if row.frame.Visible then
                local col,index=count%gridColumns,math.floor(count/gridColumns)
                row.frame.Position=UDim2.fromOffset(col*(rowWidth+8),index*(rowHeight+8))
                row.frame.Size=UDim2.fromOffset(rowWidth,rowHeight)
                row.name.Position,row.name.Size=UDim2.fromOffset(12,8),UDim2.fromOffset(rowWidth-36,38)
                row.name.TextWrapped=true;row.name.TextTruncate=Enum.TextTruncate.None
                row.name.TextSize=rowWidth<150 and 14 or 16
                row.art.Position,row.art.Size=UDim2.fromOffset(12,48),UDim2.fromOffset(48,math.max(24,rowHeight-84))
                row.cost.Position,row.cost.Size=UDim2.fromOffset(12,rowHeight-28),UDim2.fromOffset(rowWidth-24,20)
                row.marker.Position,row.marker.Size=UDim2.new(1,-24,0,5),UDim2.fromOffset(18,34)
                row.line.Position,row.line.Size=UDim2.new(0,12,1,-1),UDim2.new(1,-24,0,1)
                count+=1
            end
        end
        list.CanvasSize=UDim2.fromOffset(0,math.ceil(count/gridColumns)*(rowHeight+8))
    end
    local function refreshPreview()
        local equipment=profile().equipped or{}
        local parts={selected}
        for slot,id in pairs(equipment)do parts[#parts+1]=slot.."="..tostring(id)end
        table.sort(parts);local key=table.concat(parts,"|")
        if viewport and previewKey==key then return end
        if viewport then viewport:Destroy();viewport=nil end
        previewKey=key
        local item=Catalog.ById[selected]
        local ok,node=pcall(Preview.mountCollection,hero,{item},{equipped=equipment,character=ctx.player.Character,fullBody=true,motion=true})
        if ok then viewport=node end
    end
    function self:update()
        if not self.visible then return end
        if attempt then selected=attempt.itemId end
        local item=Catalog.ById[selected];local offer=Config.ById[selected]
        local owned=(profile().owned or{})[selected]==true
        local equipped=(profile().equipped or{})[item.equipSlot or item.kind]==selected
        title.Text=tr(overlay.AbsoluteSize.X<660 and"shortTitle"or"title");wallet.Text=tostring(profile().coins or 0).." ◈"
        coinsTab.Text,robuxTab.Text=tr("coins"),tr("robux")
        itemName.Text=ctx.language()=="en"and item.en or item.ru
        price.Text=owned and tr("owned")or tostring(offer.price)..(ctx.language()=="en"and" coins"or" монет")
        local retry=attempt and attempt.retry==true
        action.Text=profileSync and tr("pending")or profile().ready~=true and tr("retry")or attempt and (retry and tr("retry")or tr("pending"))or equipped and tr("equipped")or owned and tr("equip")or tr("buy")
        action.Active=not ctx.pending()and not blocked()and
            (not profileSync and not attempt and profile().ready~=true or retry==true and(profile().ready~=true or editable())or not attempt and editable()and not equipped
            and(owned or not offer.dailyOnly and(profile().coins or 0)>=offer.price))
        action.Selectable=action.Active
        action.BackgroundColor3=action.Active and C.brass or C.line
        action.TextColor3=action.Active and C.ink or C.muted
        for id,row in pairs(rows)do
            local entry=Catalog.ById[id];local def=Config.ById[id]
            row.name.Text=ctx.language()=="en"and entry.en or entry.ru
            row.cost.Text=(profile().owned or{})[id]and tr("owned")or tostring(def.price).." ◈"
            row.frame.BackgroundColor3=id==selected and C.velvet or C.surface
            row.frame.BackgroundTransparency=id==selected and .25 or .62
            row.frame.Active=not attempt;row.frame.Selectable=not attempt
            row.marker.Visible=id==selected
        end
        layoutRows()
        for id,row in pairs(rows)do
            if row.frame.Visible and not row.preview then
                local ok,node=pcall(Preview.mount,row.art,Catalog.ById[id])
                if ok then row.preview=node end
            end
        end
        local key=notice or Policy.activeRound(ctx.state())and"round"or not owned and(profile().coins or 0)<offer.price and"poor"or"hint"
        status.Text=tr(key);back.Text=tr("character").."  →"
        refreshPreview()
    end
    function self:resize()
        local view=overlay.AbsoluteSize
        if view.X<=0 or view.Y<=0 then return end
        local compact,short=view.X<660,view.Y<430
        local width,height=math.min(1120,view.X-24),math.min(720,view.Y-24)
        sheet.Size=UDim2.fromOffset(width,height)
        local pad=compact and 16 or 28
        local inner=width-pad*2
        local header=short and 88 or compact and 142 or 122
        title.Position,title.Size=UDim2.fromOffset(pad,short and 8 or 14),UDim2.fromOffset(inner-156,short and 38 or 58)
        title.TextSize=compact and 34 or short and 38 or 56
        if compact and not short then
            title.Position,title.Size=UDim2.fromOffset(pad,8),UDim2.fromOffset(inner-44,44)
            wallet.TextXAlignment=Enum.TextXAlignment.Left
        else wallet.TextXAlignment=Enum.TextXAlignment.Right end
        wallet.Position,wallet.Size=UDim2.new(1,-pad-144,0,short and 12 or 24),UDim2.fromOffset(92,28)
        if compact and not short then wallet.Position,wallet.Size=UDim2.fromOffset(pad,56),UDim2.fromOffset(inner,24) end
        wallet.TextSize=compact and 15 or 18
        close.Position,close.Size=UDim2.new(1,-pad-44,0,short and 4 or 14),UDim2.fromOffset(44,44)
        local tabWidth=math.floor((inner-12)/2)
        coinsTab.Position,coinsTab.Size=UDim2.fromOffset(pad,header-46),UDim2.fromOffset(tabWidth,44)
        robuxTab.Position,robuxTab.Size=UDim2.fromOffset(pad+tabWidth+12,header-46),UDim2.fromOffset(tabWidth,44)
        coinsTab.TextXAlignment,robuxTab.TextXAlignment=Enum.TextXAlignment.Left,Enum.TextXAlignment.Left
        coinsTab.TextSize=compact and 12 or 15;robuxTab.TextSize=compact and 12 or 15
        rule.Position,rule.Size=UDim2.fromOffset(pad,header),UDim2.fromOffset(inner,1)
        gridColumns=2;rowHeight=short and 94 or compact and 126 or 138
        hero.Visible=not(short and compact)
        local contentTop=header+16
        local actionX,actionWidth
        if compact and not short then
            local stageWidth=math.min(120,math.floor(inner*.42))
            hero.Position,hero.Size=UDim2.fromOffset(pad,contentTop),UDim2.fromOffset(stageWidth,142)
            local detailX=pad+stageWidth+14
            itemName.Position,itemName.Size=UDim2.fromOffset(detailX,contentTop+6),UDim2.fromOffset(width-pad-detailX,80)
            itemName.TextSize=26;itemName.TextWrapped=true
            price.Position,price.Size=UDim2.fromOffset(detailX,contentTop+96),UDim2.fromOffset(width-pad-detailX,40)
            price.TextSize=14;price.TextWrapped=true
            list.Position,list.Size=UDim2.fromOffset(pad,contentTop+158),UDim2.fromOffset(inner,math.max(64,height-contentTop-158-158))
            actionX,actionWidth=pad,inner
        else
            local split=compact and pad or math.floor(width*.42)
            hero.Position,hero.Size=UDim2.fromOffset(pad,contentTop),UDim2.fromOffset(math.max(1,split-pad-24),height-contentTop-pad)
            local x=compact and pad or split+16
            local w=width-x-pad
            local detailHeight=short and 60 or 96
            local footerHeight=short and 96 or 150
            local listHeight=math.max(44,height-contentTop-detailHeight-footerHeight-8)
            list.Position,list.Size=UDim2.fromOffset(x,contentTop),UDim2.fromOffset(w,listHeight)
            itemName.Position,itemName.Size=UDim2.fromOffset(x,contentTop+listHeight+8),UDim2.fromOffset(w,short and 28 or 40)
            itemName.TextSize=short and 23 or 34;itemName.TextWrapped=false
            price.Position,price.Size=UDim2.fromOffset(x,contentTop+listHeight+(short and 36 or 52)),UDim2.fromOffset(w,22)
            price.TextSize=16;price.TextWrapped=false
            actionX,actionWidth=x,w
        end
        action.Position,action.Size=UDim2.new(0,actionX,1,-(short and 92 or 150)),UDim2.fromOffset(actionWidth,short and 44 or 52)
        status.Position,status.Size=UDim2.new(0,actionX,1,-88),UDim2.fromOffset(actionWidth,36);status.Visible=not short
        back.Position,back.Size=UDim2.new(1,-pad-156,1,-48),UDim2.fromOffset(156,44)
        layoutRows();self:update()
    end
    function self:open()
        if blocked()then return false end
        if ctx.closeDialogue then ctx.closeDialogue()end
        if ctx.closePanels then ctx.closePanels("clubStore")end
        self.visible=true;overlay.Visible=true
        if ctx.setActivePanel then ctx.setActivePanel("clubStore")end
        self:resize();return true
    end
    function self:close()
        self.visible=false;overlay.Visible=false
        if viewport then viewport:Destroy();viewport=nil end
        for _,row in pairs(rows)do if row.preview then row.preview:Destroy();row.preview=nil end end
        previewKey=nil
        if ctx.getActivePanel and ctx.getActivePanel()=="clubStore"and ctx.setActivePanel then ctx.setActivePanel(nil)end
    end
    function self:receive(receipt,requestId)
        if profileSync and requestId==profileSync and type(receipt)=="table"then profileSync=nil;notice=nil;self:update();return true end
        if not attempt or type(receipt)~="table"then return false end
        if requestId==attempt.syncId then
            attempt.syncId=nil;attempt.retry=true;notice="unavailable";self:update();return true
        end
        if requestId~=attempt.id then return false end
        notice=receipt.ok and(receipt.code=="clubBought"and"bought"or"saved")or receipt.code=="not_enough"and"poor"or"unavailable"
        local uncertain={save_failed=true,profile_unavailable=true,slowDown=true}
        if receipt.ok~=true and uncertain[receipt.code]then attempt.retry=true else attempt=nil end
        self:update();return true
    end
    action.Activated:Connect(function()
        if not action.Active then return end
        if not attempt and profile().ready~=true then
            profileSync=Http:GenerateGUID(false)
            local id=profileSync
            if not ctx.request("retry",nil,id)then profileSync=nil;notice="unavailable"end
            self:update()
            task.delay(19,function()if alive and profileSync==id then profileSync=nil;notice="unavailable";self:update()end end)
            return
        end
        if not attempt then
            attempt={itemId=selected,kind=(profile().owned or{})[selected]and"equip"or"clubBuy",id=Http:GenerateGUID(false)}
        end
        local current=attempt;attempt.retry=false
        local requestId=attempt.id
        local kind,value=attempt.kind,attempt.itemId
        if profile().ready~=true then
            attempt.syncId=attempt.syncId or Http:GenerateGUID(false)
            requestId=attempt.syncId;kind,value="retry",nil
        end
        if not ctx.request(kind,value,requestId)then attempt.retry=true;notice="unavailable"end
        self:update()
        task.delay(19,function()if alive and attempt==current then attempt.retry=true;self:update()end end)
    end)
    robuxTab.Activated:Connect(function()self:close();if ctx.openPanel then ctx.openPanel("premiumShop")end end)
    back.Activated:Connect(function()self:close();if ctx.openPanel then ctx.openPanel("accessoryRoll")end end)
    close.Activated:Connect(function()self:close()end);dismiss.Activated:Connect(function()self:close()end)
    connections[#connections+1]=Input.InputBegan:Connect(function(input,processed)
        if self.visible and not processed and not Input:GetFocusedTextBox()and(input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB)then self:close()end
    end)
    connections[#connections+1]=overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:resize()end end)
    function self:Destroy()
        self:close();alive=false
        for _,connection in ipairs(connections)do connection:Disconnect()end
        overlay:Destroy()
    end
    return self
end
return UI
