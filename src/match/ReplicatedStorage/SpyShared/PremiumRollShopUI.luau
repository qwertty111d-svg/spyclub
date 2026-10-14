-- Native payment prompts never credit currency; only durable server receipts do.
local Input=game:GetService("UserInputService")
local Marketplace=game:GetService("MarketplaceService")
local Http=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local Rules=require(script.Parent.PremiumShopRules)
local Config=require(script.Parent.RollShopConfig)
local UI={}
local C={ink=Color3.fromRGB(15,15,19),paper=Color3.fromRGB(29,23,28),raised=Color3.fromRGB(48,32,38),
    text=Color3.fromRGB(244,232,213),muted=Color3.fromRGB(179,154,141),line=Color3.fromRGB(110,82,73),
    brass=Color3.fromRGB(216,180,119),error=Color3.fromRGB(214,147,139)}
local COPY={title={"Rolls","Rolls"},subtitle={"Магазин · Robux","Store · Robux"},
    balance={"Ваш баланс","Your balance"},buy={"Купить","Buy"},soon={"Скоро","Coming soon"},
    loading={"Загрузка цены…","Loading price…"},pending={"Открываем покупку…","Opening purchase…"},
    processing={"Ожидаем подтверждение Roblox","Waiting for Roblox confirmation"},
    saved={"Получено +%d Rolls","Received +%d Rolls"},cancelled={"Покупка отменена","Purchase cancelled"},
    delayed={"Ответ задерживается. Проверьте баланс перед новой покупкой.","Reply delayed. Check your balance before another purchase."},
    unavailable={"Покупка сейчас недоступна","Purchases are unavailable right now"},
    match={"Покупка доступна после матча","Purchases are available after the match"},
    restricted={"Покупки Rolls недоступны для этого аккаунта","Roll purchases are unavailable for this account"},
    explanation={"Небольшие пакеты. Rolls также доступны за игру и ежедневные награды.","Small packs. You can also earn Rolls by playing and claiming daily rewards."},
    back={"Коллекция","Collection"},unit={"%s R$ за Roll","%s R$ per Roll"}}
local function make(class,parent,properties)
    local node=Instance.new(class)
    for key,value in pairs(properties or {})do node[key]=value end
    if node:IsA("GuiObject") and parent and parent:IsA("GuiObject") and not(properties and properties.ZIndex)then node.ZIndex=parent.ZIndex+1 end
    node.Parent=parent;return node
end
local function text(parent,name,size,color)
    return make("TextLabel",parent,{Name=name,Text="",TextSize=size,Font=Enum.Font.BuilderSansMedium,
        TextColor3=color or C.text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,TextWrapped=false})
end
local function action(parent,name)
    local node=make("TextButton",parent,{Name=name,Text="",TextSize=15,Font=Enum.Font.BuilderSansMedium,
        TextColor3=C.text,BackgroundColor3=C.raised,BorderSizePixel=0,AutoButtonColor=true,Selectable=true})
    make("UICorner",node,{CornerRadius=UDim.new(0,4)});return node
end
function UI.create(ctx)
    local self={visible=false,name="premiumShop"}
    local alive=true
    local connections,rows={},{}
    local prompt,noticeKey,noticeAmount=nil,nil,nil
    local seenReceipts,receiptOrder={},{}
    local quotes={}
    local previousSelection
    local function tr(key)
        local row=COPY[key]or COPY.unavailable
        return row[ctx.language()=="en"and 2 or 1]
    end
    local function profile()return ctx.profile()or{}end
    local function shop()return profile().rollShop or{}end
    local function blocked()
        for _,key in ipairs({"SpyPhoneActive","SpyTradeOpen","SpyTeleporting","SpyEntryPending","SpyEntryActive"})do
            if ctx.player:GetAttribute(key)then return true end
        end
        return false
    end
    local function offers()
        local byQuantity={}
        for _,offer in ipairs(type(shop().offers)=="table"and shop().offers or{})do
            if type(offer)=="table"then byQuantity[offer.rolls]=offer end
        end
        local result={}
        for _,pack in ipairs(Config.Packs)do
            local offer=byQuantity[pack.rolls]
            table.insert(result,offer or {rolls=pack.rolls,id=pack.id,previewPrice=pack.previewPrice,configured=false,available=false})
        end
        return result
    end
    local overlay=make("Frame",ctx.gui,{Name="PremiumRollOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,
        BackgroundTransparency=.35,Visible=false,Active=true,BorderSizePixel=0,ZIndex=80})
    local dismiss=make("TextButton",overlay,{Name="PremiumDismiss",Text="",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        AutoButtonColor=false,Selectable=false,ZIndex=81})
    local sheet=make("Frame",overlay,{Name="PremiumRollSheet",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundColor3=C.paper,BorderSizePixel=0,ClipsDescendants=true,Active=true,ZIndex=82})
    make("UICorner",sheet,{CornerRadius=UDim.new(0,6)})
    make("UIStroke",sheet,{Color=C.line,Transparency=.25,Thickness=1})
    local title=text(sheet,"RollShopTitle",36);title.Font=Enum.Font.Garamond
    local subtitle=text(sheet,"RollShopSubtitle",13,C.muted)
    local wallet=text(sheet,"RollShopBalance",16,C.brass);wallet.TextXAlignment=Enum.TextXAlignment.Right
    local close=action(sheet,"ClosePremiumRolls");close.Text="×";close.TextSize=26;close.BackgroundTransparency=1
    local list=make("ScrollingFrame",sheet,{Name="RollPackList",BackgroundTransparency=1,BorderSizePixel=0,
        CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.brass,ScrollingDirection=Enum.ScrollingDirection.Y})
    local footer=make("Frame",sheet,{Name="RollShopFooter",BackgroundTransparency=1})
    local status=text(footer,"PurchaseStatus",13,C.muted);status.TextWrapped=true;status.TextTruncate=Enum.TextTruncate.None
    local back=action(footer,"BackToCharacter");back.BackgroundTransparency=1
    local function createRow(quantity,index)
        local row=make("Frame",list,{Name="RollPack_"..quantity,BackgroundTransparency=1})
        local amount=text(row,"PackAmount",34);amount.Text=tostring(quantity);amount.Font=Enum.Font.BuilderSansBold
        local caption=text(row,"PackCaption",16);caption.Text=quantity==1 and "Roll"or"Rolls"
        local unit=text(row,"PackUnitPrice",11,C.muted)
        local savings=text(row,"PackSavings",12,C.brass)
        local price=text(row,"PackPrice",18);price.TextXAlignment=Enum.TextXAlignment.Right
        local buy=action(row,"Buy_"..quantity)
        local rule=make("Frame",row,{Name="PackRule",BackgroundColor3=C.line,BackgroundTransparency=.5,BorderSizePixel=0})
        rows[quantity]={frame=row,amount=amount,caption=caption,unit=unit,savings=savings,price=price,buy=buy,rule=rule,index=index}
        buy.Activated:Connect(function()
            if not buy.Active or prompt or ctx.pending()then return end
            local offer=rows[quantity].offer
            if not Rules.canPurchase(offer,profile(),ctx.state(),false)then return end
            local id=Http:GenerateGUID(false)
            prompt={productId=offer.id,requestId=id,phase="opening"}
            noticeKey="pending"
            local attempt=prompt
            local sent=ctx.request("rollPurchase",offer.id,id)
            if not sent then prompt=nil;noticeKey="unavailable"end
            self:update(true)
            task.delay(19,function()
                if alive and prompt==attempt and prompt.phase=="opening"then
                    -- Recovery permits a new explicit Roblox confirmation;
                    -- it never retries or assumes that a payment succeeded.
                    prompt=nil;noticeKey="delayed";self:update(true)
                end
            end)
            task.delay(90,function()
                if alive and prompt==attempt then
                    prompt=nil;noticeKey="delayed"
                    if not ctx.pending()then ctx.request("retry")end
                    self:update(true)
                end
            end)
        end)
    end
    for index,quantity in ipairs({1,3,5})do createRow(quantity,index)end
    function self:resize()
        local view=overlay.AbsoluteSize
        if view.X<=0 or view.Y<=0 then return end
        local compact=view.X<560
        local width=math.max(220,math.min(720,view.X-32))
        local height=math.max(140,math.min(520,view.Y-32))
        sheet.Size=UDim2.fromOffset(width,height)
        local pad=compact and 18 or 28
        local head=compact and 92 or 100
        local foot=compact and 92 or 76
        title.Position,title.Size=UDim2.fromOffset(pad,18),UDim2.fromOffset(width-pad*2-196,36)
        subtitle.Position,subtitle.Size=UDim2.fromOffset(pad,57),UDim2.fromOffset(width-pad*2,20)
        wallet.Position,wallet.Size=UDim2.new(1,-pad-148,0,26),UDim2.fromOffset(96,24)
        close.Position,close.Size=UDim2.new(1,-pad-44,0,14),UDim2.fromOffset(44,44)
        list.Position,list.Size=UDim2.fromOffset(pad,head),UDim2.fromOffset(width-pad*2,math.max(32,height-head-foot))
        local rowHeight=compact and 110 or 103
        list.CanvasSize=UDim2.fromOffset(0,rowHeight*3)
        local rowWidth=width-pad*2
        for _,record in pairs(rows)do
            record.frame.Position,record.frame.Size=UDim2.fromOffset(0,(record.index-1)*rowHeight),UDim2.fromOffset(rowWidth,rowHeight)
            record.amount.Position,record.amount.Size=UDim2.fromOffset(0,13),UDim2.fromOffset(54,45)
            record.caption.Position,record.caption.Size=UDim2.fromOffset(56,24),UDim2.fromOffset(65,24)
            record.unit.Position,record.unit.Size=UDim2.fromOffset(0,66),UDim2.fromOffset(compact and rowWidth-105 or 250,18)
            record.savings.Position,record.savings.Size=UDim2.fromOffset(126,28),UDim2.fromOffset(90,20)
            record.savings.Visible=not compact
            record.price.Position,record.price.Size=UDim2.new(1,-106,0,10),UDim2.fromOffset(98,30)
            record.buy.Position,record.buy.Size=UDim2.new(1,-104,0,46),UDim2.fromOffset(100,44)
            record.rule.Position,record.rule.Size=UDim2.new(0,0,1,-1),UDim2.new(1,-8,0,1)
        end
        footer.Position,footer.Size=UDim2.new(0,pad,1,-foot),UDim2.fromOffset(width-pad*2,foot)
        status.Position,status.Size=UDim2.fromOffset(0,10),UDim2.new(1,compact and 0 or -132,0,compact and 40 or 46)
        back.Position,back.Size=compact and UDim2.new(1,-120,1,-44)or UDim2.new(1,-120,0,7),UDim2.fromOffset(120,44)
        self:update()
    end
    function self:update()
        if not self.visible then return end
        title.Text,subtitle.Text=tr("title"),tr("subtitle")
        wallet.Text=tostring(profile().rolls or 0).." Rolls";back.Text=tr("back").."  →"
        local liveOffers,lookups={},{}
        for _,source in ipairs(offers())do
            local offer=table.clone(source)
            if offer.configured and type(offer.id)=="number"and offer.id>0 then
                local quote=quotes[offer.id]
                if not quote then
                    quote={pending=true};quotes[offer.id]=quote
                    table.insert(lookups,offer.id)
                end
                -- Server prices may be base prices. Only the local native quote
                -- may label a payable price or create a regional saving.
                offer.priceReady=quote.ready==true
                offer.priceRobux=quote.price
                offer.available=offer.available==true and quote.forSale==true
            end
            table.insert(liveOffers,offer)
        end
        local single
        for _,offer in ipairs(liveOffers)do if offer.rolls==1 then single=offer end end
        for _,record in pairs(rows)do record.offer=nil end
        for _,offer in ipairs(liveOffers)do
            local record=rows[offer.rolls]
            if record then
                record.offer=offer
                local value,live=Rules.price(offer)
                local discount=Rules.savings(single,offer)
                record.price.Text=value and tostring(value).." R$"or"—"
                local per=value and value/offer.rolls
                record.unit.Text=per and string.format(tr("unit"),per%1==0 and tostring(per)or string.format("%.1f",per))or""
                record.savings.Text=discount and (discount.percent>0 and "−"..tostring(discount.percent).."%"or"−"..tostring(discount.amount).." R$")or""
                if discount and overlay.AbsoluteSize.X<560 then record.unit.Text=record.unit.Text.."  ·  "..record.savings.Text end
                record.buy.Text=prompt and "…"or not offer.configured and tr("soon")or not live and tr("loading")or tr("buy")
                record.buy.Active=not blocked()and Rules.canPurchase(offer,profile(),ctx.state(),prompt~=nil or ctx.pending())==true
                record.buy.Selectable=record.buy.Active
                record.buy.BackgroundColor3=record.buy.Active and C.brass or C.raised
                record.buy.TextColor3=record.buy.Active and C.ink or C.muted
            end
        end
        local key=noticeKey
        if not key then
            if Rules.activeRound(ctx.state())then key="match"
            elseif shop().policyReady and shop().restricted then key="restricted"
            else key="explanation"end
        end
        status.Text=key=="saved"and string.format(tr(key),noticeAmount or 0)or tr(key)
        status.TextColor3=key=="unavailable"and C.error or C.muted
        for _,productId in ipairs(lookups)do
            task.spawn(function()
                local ok,info=pcall(Marketplace.GetProductInfoAsync,Marketplace,productId,Enum.InfoType.Product)
                if not alive then return end
                local price=ok and type(info)=="table"and info.PriceInRobux
                local ready=type(price)=="number"and price==price and price>0 and price<math.huge and price%1==0
                quotes[productId]={ready=ready,price=ready and price or nil,forSale=ready and info.IsForSale~=false}
                self:update()
                task.delay(ready and 300 or 10,function()
                    if alive then quotes[productId]=nil;self:update()end
                end)
            end)
        end
    end
    function self:open()
        if blocked()then return false end
        if self.visible then self:update();return true end
        if ctx.closeDialogue then ctx.closeDialogue()end
        if ctx.closePanels then ctx.closePanels("premiumShop")end
        self.visible=true;overlay.Visible=true
        previousSelection=GuiService.SelectedObject
        if ctx.setActivePanel then ctx.setActivePanel("premiumShop")end
        self:resize();self:update()
        if Input:GetLastInputType()==Enum.UserInputType.Gamepad1 then GuiService.SelectedObject=close end
        return true
    end
    function self:close()
        if not self.visible then return end
        self.visible=false;overlay.Visible=false
        if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(sheet)then GuiService.SelectedObject=previousSelection end
        if ctx.getActivePanel and ctx.getActivePanel()=="premiumShop"and ctx.setActivePanel then ctx.setActivePanel(nil)end
    end
    function self:receive(receipt,requestId)
        if type(receipt)~="table"then return false end
        if receipt.ok and receipt.code=="rollsPurchased"then
            if receipt.purchaseId and seenReceipts[receipt.purchaseId]then return true end
            if receipt.purchaseId then
                seenReceipts[receipt.purchaseId]=true;table.insert(receiptOrder,receipt.purchaseId)
                if #receiptOrder>128 then seenReceipts[table.remove(receiptOrder,1)]=nil end
            end
            if not receipt.replayed then noticeKey,noticeAmount="saved",receipt.rolls or 0 end
            if prompt and receipt.productId==prompt.productId then prompt=nil end
            self:update();return true
        end
        if not prompt or requestId~=prompt.requestId then return false end
        if receipt.ok and receipt.code=="rollPurchasePrompted"then prompt.phase="native";noticeKey="processing"
        else prompt=nil;noticeKey="unavailable"end
        self:update();return true
    end
    connections[#connections+1]=Marketplace.PromptProductPurchaseFinished:Connect(function(userId,productId,purchased)
        if userId~=ctx.player.UserId or not prompt or prompt.productId~=productId then return end
        if purchased then prompt.phase="receipt";noticeKey="processing"
        else prompt=nil;noticeKey="cancelled"end
        self:update()
    end)
    connections[#connections+1]=Input.InputBegan:Connect(function(input,processed)
        if self.visible and not Input:GetFocusedTextBox()and not processed
            and(input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB)then self:close()end
    end)
    connections[#connections+1]=overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:resize()end end)
    close.Activated:Connect(function()self:close()end)
    dismiss.Activated:Connect(function()self:close()end)
    back.Activated:Connect(function()self:close();if ctx.openPanel then ctx.openPanel("clubStore")end end)
    function self:Destroy()
        self:close();alive=false
        for _,connection in ipairs(connections)do connection:Disconnect()end
        overlay:Destroy()
    end
    return self
end
return UI
