-- Procedural, asset-free cosmetic art shared by the shop and physical cards.
local Art = {}
local function make(class, parent, properties)
    local node = Instance.new(class)
    for k,v in pairs(properties) do node[k]=v end
    if node:IsA("GuiObject") and not properties.ZIndex and parent:IsA("GuiObject") then node.ZIndex=parent.ZIndex+1 end
    node.Parent=parent
    return node
end
local function shape(parent, x,y,w,h,color,round,rotation,alpha)
    local f = make("Frame", parent, {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(x,y), Size=UDim2.fromScale(w,h),
        BackgroundColor3=color, BorderSizePixel=0, Rotation=rotation or 0, BackgroundTransparency=alpha or 0})
    if round then make("UICorner", f, {CornerRadius=UDim.new(round,0)}) end
    return f
end
local function ring(parent,x,y,w,h,color,rotation)
    local r = shape(parent,x,y,w,h,color,1,rotation,1)
    make("UIStroke",r,{Color=color,Thickness=1.5,Transparency=0.18})
    return r
end
function Art.color(item) return Color3.fromRGB(table.unpack(item.color)) end
function Art.draw(parent, item)
    local root = make("Frame",parent,{Name="CosmeticArt",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(table.unpack(item.dark)),BorderSizePixel=0,ClipsDescendants=true})
    make("UICorner",root,{CornerRadius=UDim.new(0,12)})
    local c, dark = Art.color(item), root.BackgroundColor3
    make("UIGradient",root,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,dark:Lerp(c,0.18)),ColorSequenceKeypoint.new(1,dark)}),Rotation=120})
    local frame=shape(root,0.5,0.5,0.89,0.88,c,0.06,0,1)
    make("UIStroke",frame,{Color=c,Thickness=1,Transparency=0.45})
    for _, x in ipairs({0.12,0.88}) do
        for _, y in ipairs({0.14,0.86}) do shape(root,x,y,0.025,0.025,c,0,45,0.25) end
    end
    local icon=make("Frame",root,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.55,0.66),BackgroundTransparency=1})
    make("UIAspectRatioConstraint",icon,{AspectRatio=1})
    local variants={tuxedo="tuxedo",tophat="tophat",wave="hand",notebook="notebook",gilded_frame="frame",noir_frame="frame",night_guest="ribbon",archivist="ribbon",supporter="ribbon"}
    local art=variants[item.id] or item.art
    if art=="tuxedo" then
        shape(icon,0.5,0.58,0.68,0.72,c,0.05)
        shape(icon,0.5,0.37,0.30,0.48,dark,0.04)
        shape(icon,0.40,0.27,0.21,0.21,c,0.03,45)
        shape(icon,0.60,0.27,0.21,0.21,c,0.03,45)
        shape(icon,0.43,0.40,0.15,0.10,dark,0.02,20)
        shape(icon,0.57,0.40,0.15,0.10,dark,0.02,-20)
        for i=1,3 do shape(icon,0.5,0.56+i*0.10,0.035,0.035,dark,1) end
    elseif art=="tophat" then
        shape(icon,0.5,0.46,0.60,0.55,c,0.07)
        shape(icon,0.5,0.60,0.61,0.11,dark)
        shape(icon,0.5,0.76,0.95,0.13,c,0.3)
    elseif art=="hand" then
        shape(icon,0.48,0.64,0.43,0.44,c,0.18,-18)
        for i=0,3 do shape(icon,0.28+i*0.125,0.34-math.sin(i)*0.07,0.095,0.46,c,0.45,-10+i*5) end
        shape(icon,0.79,0.54,0.15,0.35,c,0.4,30)
        ring(icon,0.91,0.19,0.10,0.30,c,30)
    elseif art=="notebook" then
        shape(icon,0.5,0.5,0.65,0.86,c,0.06)
        shape(icon,0.26,0.5,0.055,0.86,dark)
        for i=1,4 do shape(icon,0.56,0.25+i*0.12,0.32,0.025,dark) end
    elseif art=="frame" then
        local outer=shape(icon,0.5,0.5,0.75,0.9,c,0.08,0,1)
        make("UIStroke",outer,{Color=c,Thickness=4})
        local inner=shape(icon,0.5,0.5,0.57,0.71,c,0.04,0,1)
        make("UIStroke",inner,{Color=c,Thickness=1})
        shape(icon,0.5,0.5,0.2,0.2,c,0,45)
    elseif art=="ribbon" then
        shape(icon,0.5,0.44,0.56,0.56,c,0.08,45)
        shape(icon,0.5,0.44,0.40,0.40,dark,1)
        shape(icon,0.36,0.79,0.21,0.32,c,0.03,16)
        shape(icon,0.64,0.79,0.21,0.32,c,0.03,-16)
        shape(icon,0.5,0.44,0.16,0.16,c,0,45)
    elseif art=="eye" then
        ring(icon,0.5,0.5,0.87,0.43,c)
        ring(icon,0.5,0.5,0.37,0.37,c)
        shape(icon,0.5,0.5,0.14,0.14,c,1)
        for i=0,7 do local a=i*math.pi/4 shape(icon,0.5+math.cos(a)*0.45,0.5+math.sin(a)*0.39,0.02,0.10,c,0,i*45,0.35) end
    elseif art=="moon" then
        shape(icon,0.48,0.49,0.65,0.65,c,1)
        shape(icon,0.65,0.36,0.60,0.60,dark,1)
        shape(icon,0.75,0.65,0.09,0.09,c,0,45)
        shape(icon,0.27,0.22,0.04,0.04,c,0,45)
    elseif art=="cipher" or art=="file" then
        ring(icon,0.5,0.5,0.64,0.64,c,45)
        ring(icon,0.5,0.5,0.40,0.40,c)
        shape(icon,0.5,0.5,0.055,0.38,c)
        shape(icon,0.5,0.5,0.38,0.055,c)
        for i=1,3 do shape(icon,0.5,0.9+i*0.035,0.32-i*0.05,0.008,c,0,0,0.4) end
    elseif art=="watch" then
        ring(icon,0.5,0.57,0.64,0.64,c)
        ring(icon,0.5,0.16,0.20,0.17,c)
        shape(icon,0.5,0.50,0.025,0.22,c)
        shape(icon,0.57,0.60,0.18,0.025,c,0,28)
        for i=1,12 do local a=i*math.pi/6 shape(icon,0.5+math.cos(a)*0.26,0.57+math.sin(a)*0.26,0.02,0.05,c,0,i*30) end
    elseif art=="lens" then
        ring(icon,0.41,0.4,0.51,0.51,c)
        ring(icon,0.41,0.4,0.43,0.43,c)
        shape(icon,0.72,0.72,0.11,0.43,c,0.1,-45)
    elseif art=="dice" then
        local cube=shape(icon,0.5,0.5,0.70,0.70,c,0.15,12)
        for _,pos in ipairs({{0.25,0.25},{0.75,0.25},{0.5,0.5},{0.25,0.75},{0.75,0.75}}) do shape(cube,pos[1],pos[2],0.12,0.12,dark,1) end
    elseif art=="seal" then
        for i=0,7 do shape(icon,0.5,0.5,0.50,0.50,c,0.08,i*22.5,0.15) end
        shape(icon,0.5,0.5,0.4,0.4,dark,1)
        ring(icon,0.5,0.5,0.32,0.32,c)
        shape(icon,0.5,0.5,0.13,0.13,c,0,45)
    else
        ring(icon,0.5,0.5,0.8,0.40,c,45)
        ring(icon,0.5,0.5,0.8,0.40,c,-45)
        shape(icon,0.5,0.5,0.13,0.13,c,0,45)
        shape(icon,0.78,0.25,0.07,0.07,c,1)
    end
    return root
end
return Art
