local Catalog=require(script.Parent.Catalog)
local Art=require(script.Parent.Art)
local Preview3D=require(script.Parent.Preview3D)
local CatalogUI={}
function CatalogUI.itemName(ctx,item) return ctx.language()=="en" and item.en or item.ru end
function CatalogUI.kind(ctx,kind) return ctx.L(kind=="title" and "titleSlot" or kind) end
function CatalogUI.filters(ctx,parent,choices,selected,callback,nameFor)
    local strip=ctx.make("ScrollingFrame",parent,{Name="Filters",Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X})
    ctx.make("UIListLayout",strip,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
    for _,key in ipairs(choices) do
        local b=ctx.button(strip,nameFor and nameFor(key) or CatalogUI.kind(ctx,key),UDim2.fromOffset(0,44),UDim2.new(),key==selected and ctx.colors.gold or ctx.colors.bg)
        b.AutomaticSize=Enum.AutomaticSize.X
        b.TextSize=13
        b.TextWrapped=false
        b.TextColor3=key==selected and ctx.colors.bg or ctx.colors.text
        ctx.make("UIPadding",b,{PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,18)})
        b.Activated:Connect(function() callback(key) end)
    end
    return strip
end
function CatalogUI.item(ctx,parent,item,caption,callback,accent,extra)
    local tile=ctx.panel(parent,UDim2.new(1,0,0,186),UDim2.new())
    local top=ctx.make("Frame",tile,{Size=UDim2.new(1,-28,0,110),Position=UDim2.fromOffset(14,12),BackgroundTransparency=1})
    local topLayout=ctx.make("UIListLayout",top,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,14),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
    local art=ctx.make("Frame",top,{Size=UDim2.fromOffset(82,96),BackgroundColor3=ctx.colors.bg,BackgroundTransparency=.35,BorderSizePixel=0,LayoutOrder=1})
    ctx.make("UICorner",art,{CornerRadius=UDim.new(0,12)})
    Preview3D.mount(art,item,nil)
    local info=ctx.make("Frame",top,{Size=UDim2.new(1,-96,1,0),BackgroundTransparency=1,LayoutOrder=2})
    ctx.make("UIListLayout",info,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
    local rarity=ctx.label(info,ctx.L(item.rarity).." · "..CatalogUI.kind(ctx,item.kind),UDim2.new(1,0,0,30),UDim2.new(),11,Art.color(item)); rarity.TextWrapped=true
    local title=ctx.label(info,CatalogUI.itemName(ctx,item),UDim2.new(1,0,0,42),UDim2.new(),16); title.Font=Enum.Font.BuilderSansMedium; title.TextWrapped=true
    local meta=ctx.label(info,extra or ctx.L("decorative"),UDim2.new(1,0,0,30),UDim2.new(),12,ctx.colors.muted); meta.TextYAlignment=Enum.TextYAlignment.Top; meta.TextTruncate=Enum.TextTruncate.AtEnd
    local b=ctx.button(tile,caption,UDim2.new(1,-28,0,44),UDim2.fromOffset(14,130),accent and ctx.colors.gold or ctx.colors.edge)
    b.TextColor3=accent and ctx.colors.bg or ctx.colors.text
    b.TextSize=13
    b.Activated:Connect(callback)
    return tile
end
function CatalogUI.sets(ctx,self)
    self:text(ctx.L("setHint"),14)
    local p=ctx.profile()
    for _,set in ipairs(Catalog.Sets) do
        local heading=self:text(ctx.L(set.nameKey),20,ctx.colors.gold); heading.Font=Enum.Font.BuilderSansMedium
        local count=0
        for _,id in ipairs(set.items) do
            if (p.owned or {})[id] then count=count+1 end
            local item=Catalog.ById[id]
            self:text(((p.owned or {})[id] and "✓  " or "○  ")..CatalogUI.itemName(ctx,item),14,(p.owned or {})[id] and ctx.colors.accent or ctx.colors.muted)
        end
        self:text(ctx.L("setProgress",{n=count,total=#set.items}),14)
        local reward=Catalog.ById[set.reward]
        CatalogUI.item(ctx,self.surface,reward,(p.setRewards or {})[set.id] and ctx.L("setComplete") or ctx.L("setReward",{item=CatalogUI.itemName(ctx,reward)}),function()
            if (p.owned or {})[reward.id] then ctx.request("equip",reward.id) end
        end,false)
    end
end
return CatalogUI
