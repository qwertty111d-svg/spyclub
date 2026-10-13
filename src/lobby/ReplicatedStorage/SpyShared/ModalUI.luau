local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local UITheme=require(script.Parent.UITheme)
local UIEffects=require(script.Parent.UIEffects)
local LayoutUI=require(script.Parent.LayoutUI)
local ModalUI={}
function ModalUI.create(ctx,name,titleKey,hintKey,width)
    local self={visible=false,name=name}
    local make,colors=ctx.make,ctx.colors
    local dim=make("Frame",ctx.gui,{Name=name.."Overlay",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(4,7,8),BackgroundTransparency=1,Visible=false,ZIndex=40,Active=true})
    local dismiss=make("TextButton",dim,{Name="DismissBackdrop",Text="",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,AutoButtonColor=false})
    local modal=ctx.panel(dim,UDim2.fromOffset(600,560),UDim2.fromScale(.5,.5))
    modal.Name="ModalSurface"; modal.AnchorPoint=Vector2.new(.5,.5); modal.ClipsDescendants=true
    local modalScale=make("UIScale",modal,{Scale=1})
    local kicker=ctx.label(modal,"SPY CLUB",UDim2.new(1,-90,0,16),UDim2.fromOffset(24,16),10,colors.gold)
    kicker.Name="ClubSection";kicker.Font=Enum.Font.BuilderSansMedium;kicker.Visible=false
    local title=ctx.label(modal,titleKey,UDim2.new(1,-98,0,36),UDim2.fromOffset(24,24),UITheme.Text.Title,colors.text)
    title.Font=Enum.Font.BuilderSansBold; title.TextWrapped=false; title.TextTruncate=Enum.TextTruncate.AtEnd
    local hint=ctx.label(modal,hintKey,UDim2.new(1,-48,0,36),UDim2.fromOffset(24,68),UITheme.Text.Caption,colors.muted)
    hint.TextYAlignment=Enum.TextYAlignment.Top
    local close=ctx.button(modal,"×",UDim2.fromOffset(44,44),UDim2.new(1,-66,0,22),colors.raised or colors.edge)
    close.TextSize=22
    if UITheme.button then UITheme.button(close,false)end
    local scroll=make("ScrollingFrame",modal,{Name="Content",Position=UDim2.fromOffset(24,112),Size=UDim2.new(1,-48,1,-132),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=colors.gold,ScrollingDirection=Enum.ScrollingDirection.Y})
    make("UIPadding",scroll,{PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,12)})
    make("UIListLayout",scroll,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
    self.surface,self.modal,self.title,self.hint,self.kicker=scroll,modal,title,hint,kicker
    local motionToken=0
    local function resizeSurface()
        local v=ctx.gui.AbsoluteSize
        local d=LayoutUI.measure(v.X,v.Y).modal
        local w=math.min(d.w,width or 780)
        modal.Size=UDim2.fromOffset(w,d.h)
        title.TextSize=w<420 and 20 or UITheme.Text.Title
        if self.layoutWidth~=w then self.layoutWidth=w; self.contentKey=nil end
    end
    function self:clear()
        for _,node in ipairs(scroll:GetChildren()) do if node:IsA("GuiObject") then node:Destroy() end end
    end
    function self:row(height) return make("Frame",scroll,{Size=UDim2.new(1,0,0,height),BackgroundTransparency=1}) end
    function self:text(text,size,color)
        local item=ctx.label(scroll,text,UDim2.new(1,0,0,0),UDim2.new(),size or UITheme.Text.Body,color or colors.muted)
        item.AutomaticSize,item.TextYAlignment=Enum.AutomaticSize.Y,Enum.TextYAlignment.Top
        return item
    end
    function self:action(text,callback,accented)
        local b=ctx.button(scroll,text,UDim2.new(1,0,0,44),UDim2.new(),accented and colors.gold or colors.edge)
        if UITheme.button then UITheme.button(b,accented,{arrow=accented})end
        if accented then b.TextColor3=colors.bg end
        b.Activated:Connect(callback)
        return b
    end
    function self:update(force)
        if not self.visible then return end
        local p=ctx.profile()
        local key=table.concat({tostring(p.revision),tostring(p.ready),ctx.language(),tostring(ctx.pending()),tostring(self.tab),tostring(self.filter),tostring(self.mode),tostring(self.unlocked),self.cacheKey and self:cacheKey() or ""},":")
        if force or self.contentKey~=key then
            self.contentKey=key
            title.Text,hint.Text=ctx.L(titleKey),ctx.L(hintKey)
            if self.render then self:render() end
        end
    end
    function self:resize()
        resizeSurface()
        self:update()
    end
    function self:open()
        if self.visible then self:update(true); return end
        if ctx.closeDialogue then ctx.closeDialogue() end
        if ctx.closePanels then ctx.closePanels(name) end
        motionToken=motionToken+1; self.visible=true
        if ctx.setActivePanel then ctx.setActivePanel(name) end
        resizeSurface()
        dim.Visible=true; dim.BackgroundTransparency=1; modalScale.Scale=.98; scroll.CanvasPosition=Vector2.new(0,0)
        self:update(true); UIEffects.pushBlur(self,0)
        TweenService:Create(dim,TweenInfo.new(.18,UITheme.Motion.Easing,Enum.EasingDirection.Out),{BackgroundTransparency=.76}):Play()
        TweenService:Create(modalScale,TweenInfo.new(.2,UITheme.Motion.Easing,Enum.EasingDirection.Out),{Scale=1}):Play()
    end
    function self:close(animated)
        if not self.visible then return end
        motionToken=motionToken+1; local token=motionToken; self.visible=false
        if ctx.getActivePanel and ctx.getActivePanel()==name and ctx.setActivePanel then ctx.setActivePanel(nil) end
        UIEffects.popBlur(self)
        if animated==false then dim.Visible=false; return end
        TweenService:Create(dim,TweenInfo.new(.12,UITheme.Motion.Easing,Enum.EasingDirection.In),{BackgroundTransparency=1}):Play()
        task.delay(.12,function() if motionToken==token and not self.visible then dim.Visible=false end end)
    end
    close.Activated:Connect(function() self:close() end)
    dismiss.Activated:Connect(function() self:close() end)
    UserInputService.InputBegan:Connect(function(input,processed) if not processed and input.KeyCode==Enum.KeyCode.Escape and self.visible then self:close() end end)
    return self
end
return ModalUI
