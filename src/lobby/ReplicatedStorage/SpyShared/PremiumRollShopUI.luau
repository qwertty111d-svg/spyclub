-- Native payment prompts never credit currency; only durable server receipts do.
local Input=game:GetService("UserInputService")
local Marketplace=game:GetService("MarketplaceService")
local Http=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local Rules=require(script.Parent.PremiumShopRules)
local Config=require(script.Parent.RollShopConfig)
local UI={}
local C={ink=Color3.fromRGB(16,17,20),paper=Color3.fromRGB(26,27,31),raised=Color3.fromRGB(49,50,56),
    text=Color3.fromRGB(245,245,247),muted=Color3.fromRGB(168,170,179),line=Color3.fromRGB(111,113,122),
    brass=Color3.fromRGB(238,238,241),error=Color3.fromRGB(231,157,151)}
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
    back={"Вещи · монеты","Items · coins"},unit={"%s R$ за Roll","%s R$ per Roll"}}
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
        BackgroundTransparency=.70,Visible=false,Active=true,BorderSizePixel=0,ZIndex=80})
    local dismiss=make("TextButton",overlay,{Name="PremiumDismiss",Text="",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        AutoButtonColor=false,Selectable=false,ZIndex=81})
    local sheet=make("Frame",overlay,{Name="PremiumRollSheet",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundColor3=C.paper,BackgroundTransparency=.18,BorderSizePixel=0,ClipsDescendants=true,Active=true,ZIndex=82})
    make("UICorner",sheet,{CornerRadius=UDim.new(0,2)})
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
        local row=make("Frame",list,{Name="RollPack_"..quantity,BackgroundColor3=C.raised,BackgroundTransparency=.60,BorderSizePixel=0})
        local amount=text(row,"PackAmount",34);amount.Text=tostring(quantity);amount.Font=Enum.Font.Garamond
        local caption=text(row,"PackCaption",16);caption.Text=quantity==1 and "Roll"or"Rolls"
        local mark=text(row,"PackMark",54,C.muted);mark.Text="↻";mark.TextXAlignment=Enum.TextXAlignment.Right
        local unit=text(row,"PackUnitPrice",11,C.muted)
        local savings=text(row,"PackSavings",12,C.brass)
        local price=text(row,"PackPrice",18);price.TextXAlignment=Enum.TextXAlignment.Right
        local buy=action(row,"Buy_"..quantity)
        local rule=make("Frame",row,{Name="PackRule",BackgroundColor3=C.line,BackgroundTransparency=.5,BorderSizePixel=0})
        rows[quantity]={frame=row,amount=amount,caption=caption,unit=unit,savings=savings,price=price,buy=buy,rule=rule,index=index,mark=mark}
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
        local compact,short=view.X<620,view.Y<430
        local width=math.max(220,math.min(1040,view.X-32))
        local height=math.max(140,math.min(610,view.Y-32))
        sheet.Size=UDim2.fromOffset(width,height)
        local pad=compact and 16 or 30
        local head=short and 82 or compact and 112 or 124
        local foot=short and 66 or compact and 88 or 92
        local inner=width-pad*2
        title.Position,title.Size=UDim2.fromOffset(pad,short and 8 or 14),UDim2.fromOffset(compact and inner-44 or inner-220,short and 42 or 60)
        title.TextSize=compact and 42 or short and 42 or 64
        subtitle.Position,subtitle.Size=UDim2.fromOffset(pad,short and 56 or 80),UDim2.fromOffset(compact and inner-100 or inner-180,22)
        subtitle.TextSize=compact and 11 or 13
        wallet.Position,wallet.Size=UDim2.new(1,-pad-(compact and 96 or 152),0,compact and not short and 80 or 26),UDim2.fromOffset(compact and 96 or 100,24)
        wallet.TextSize=compact and 14 or 18
        close.Position,close.Size=UDim2.new(1,-pad-44,0,short and 6 or 16),UDim2.fromOffset(44,44)
        list.Position,list.Size=UDim2.fromOffset(pad,head),UDim2.fromOffset(inner,math.max(32,height-head-foot))
        local rowHeight=compact and 148 or list.Size.Y.Offset
        local cardWidth=compact and inner-4 or (inner-24)/3
        list.CanvasSize=UDim2.fromOffset(0,compact and rowHeight*3 or 0)
        for _,record in pairs(rows)do
            record.frame.Position=UDim2.fromOffset(compact and 0 or(record.index-1)*(cardWidth+12),compact and(record.index-1)*rowHeight or 0)
            record.frame.Size=UDim2.fromOffset(cardWidth,compact and rowHeight-10 or rowHeight)
            local h=record.frame.Size.Y.Offset
            record.amount.Position,record.amount.Size=UDim2.fromOffset(16,compact and 2 or 12),UDim2.fromOffset(compact and 64 or cardWidth-32,compact and 58 or short and 48 or 108)
            record.amount.TextSize=compact and 62 or short and 52 or 112
            record.caption.Position,record.caption.Size=UDim2.fromOffset(compact and 82 or 18,compact and 29 or short and 56 or 116),UDim2.fromOffset(80,24)
            record.caption.TextSize=(compact or short) and 16 or 20
            record.mark.Position,record.mark.Size=UDim2.new(1,-82,0,16),UDim2.fromOffset(64,64)
            record.mark.Visible=not compact and not short
            record.unit.Position,record.unit.Size=UDim2.fromOffset(16,compact and 80 or short and h-100 or h-124),UDim2.fromOffset(cardWidth-32,18)
            record.unit.TextSize=11
            record.savings.Position,record.savings.Size=UDim2.fromOffset(16,compact and 60 or h-149),UDim2.fromOffset(cardWidth-32,20)
            record.savings.Visible=not short
            record.price.Position,record.price.Size=UDim2.fromOffset(16,compact and 100 or short and h-80 or h-98),UDim2.fromOffset(compact and cardWidth-138 or cardWidth-32,28)
            record.price.TextXAlignment=Enum.TextXAlignment.Left
            record.price.TextSize=compact and 20 or short and 18 or 24
            record.buy.Position,record.buy.Size=compact and UDim2.new(1,-116,1,-54)or UDim2.new(0,16,1,short and -48 or -64),UDim2.fromOffset(compact and 100 or cardWidth-32,(compact or short) and 44 or 48)
            record.rule.Position,record.rule.Size=UDim2.new(0,16,1,-1),UDim2.new(1,-32,0,1)
        end
        footer.Position,footer.Size=UDim2.new(0,pad,1,-foot),UDim2.fromOffset(inner,foot)
        status.Position,status.Size=UDim2.fromOffset(0,8),UDim2.new(1,compact and 0 or -152,0,compact and 36 or 48)
        status.TextSize=compact and 11 or 13
        back.Position,back.Size=UDim2.new(1,-132,1,-44),UDim2.fromOffset(132,44)
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
