local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local UITheme=require(script.Parent.UITheme)
local UIEffects=require(script.Parent.UIEffects)
local LayoutUI=require(script.Parent.LayoutUI)
local ModalUI={}
local COLORS={
    bg=Color3.fromRGB(16,17,20),
    panel=Color3.fromRGB(26,27,31),
    text=Color3.fromRGB(245,245,247),
    muted=Color3.fromRGB(168,170,179),
    gold=Color3.fromRGB(238,238,241),
}
function ModalUI.create(ctx,name,titleKey,hintKey,width)
    local self={visible=false,name=name}
    local make,colors=ctx.make,COLORS
    local function round(node,radius)
        local corner=node:FindFirstChildOfClass("UICorner") or make("UICorner",node)
        corner.CornerRadius=UDim.new(0,radius)
    end
    local function outline(node,color,transparency)
        local line=node:FindFirstChildOfClass("UIStroke") or make("UIStroke",node)
        line.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        line.Color,line.Transparency,line.Thickness=color,transparency,1
    end
    local function styleButton(button,accented)
        if UITheme.button then UITheme.button(button,accented)end
        button.BackgroundColor3=accented and colors.gold or colors.panel
        button.BackgroundTransparency=0
        button.TextColor3=accented and colors.bg or colors.text
        button.Font=Enum.Font.BuilderSansMedium
        button.TextSize=16
        round(button,4)
        outline(button,accented and colors.gold or colors.muted,accented and .35 or .76)
    end
    local dim=make("Frame",ctx.gui,{Name=name.."Overlay",Size=UDim2.fromScale(1,1),BackgroundColor3=colors.bg,BackgroundTransparency=1,Visible=false,ZIndex=40,Active=true})
    local dismiss=make("TextButton",dim,{Name="DismissBackdrop",Text="",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,AutoButtonColor=false})
    local modal=ctx.panel(dim,UDim2.fromOffset(600,560),UDim2.fromScale(.5,.5))
    modal.Name="ModalSurface"; modal.AnchorPoint=Vector2.new(.5,.5); modal.ClipsDescendants=true
    modal.BackgroundColor3=colors.bg; modal.BackgroundTransparency=.18; modal.BorderSizePixel=0
    round(modal,2); outline(modal,colors.muted,.76)
    local modalScale=make("UIScale",modal,{Scale=1})
    local kicker=ctx.label(modal,"SPY CLUB",UDim2.new(1,-90,0,16),UDim2.fromOffset(24,16),10,colors.gold)
    kicker.Name="ClubSection";kicker.Font=Enum.Font.BuilderSansMedium;kicker.Visible=false
    local title=ctx.label(modal,titleKey,UDim2.new(1,-98,0,48),UDim2.fromOffset(24,16),44,colors.text)
    title.Font=Enum.Font.Garamond; title.TextWrapped=false; title.TextTruncate=Enum.TextTruncate.AtEnd
    local hint=ctx.label(modal,hintKey,UDim2.new(1,-48,0,28),UDim2.fromOffset(24,72),14,colors.muted)
    hint.Font=Enum.Font.BuilderSans; hint.TextYAlignment=Enum.TextYAlignment.Top
    local close=ctx.button(modal,"×",UDim2.fromOffset(44,44),UDim2.new(1,-66,0,22),colors.panel)
    styleButton(close,false); close.TextSize=26;close.BackgroundTransparency=1
    outline(close,colors.muted,1)
    local headerRule=make("Frame",modal,{Name="HeaderRule",Position=UDim2.fromOffset(24,104),Size=UDim2.new(1,-48,0,1),BackgroundColor3=colors.gold,BackgroundTransparency=.65,BorderSizePixel=0})
    local scroll=make("ScrollingFrame",modal,{Name="Content",Position=UDim2.fromOffset(24,112),Size=UDim2.new(1,-48,1,-132),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=colors.gold,ScrollingDirection=Enum.ScrollingDirection.Y})
    make("UIPadding",scroll,{PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,12)})
    make("UIListLayout",scroll,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
    self.surface,self.modal,self.title,self.hint,self.kicker=scroll,modal,title,hint,kicker
    self.headerRule=headerRule
    self.closeButton=close
    local motionToken=0
    local function resizeSurface()
        local v=ctx.gui.AbsoluteSize
        local d=LayoutUI.measure(v.X,v.Y).modal
        local w=math.min(d.w,width or 780)
        modal.Size=UDim2.fromOffset(w,d.h)
        title.TextSize=w<420 and 30 or 44
        if self.layoutWidth~=w then self.layoutWidth=w; self.contentKey=nil end
    end
    function self:clear()
        for _,node in ipairs(scroll:GetChildren()) do if node:IsA("GuiObject") then node:Destroy() end end
    end
    function self:row(height) return make("Frame",scroll,{Size=UDim2.new(1,0,0,height),BackgroundTransparency=1}) end
    function self:text(text,size,color)
        local item=ctx.label(scroll,text,UDim2.new(1,0,0,0),UDim2.new(),size or UITheme.Text.Body,color or colors.muted)
        item.Font=Enum.Font.BuilderSans
        item.AutomaticSize,item.TextYAlignment=Enum.AutomaticSize.Y,Enum.TextYAlignment.Top
        return item
    end
    function self:action(text,callback,accented)
        local b=ctx.button(scroll,text,UDim2.new(1,0,0,44),UDim2.new(),accented and colors.gold or colors.panel)
        styleButton(b,accented)
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
