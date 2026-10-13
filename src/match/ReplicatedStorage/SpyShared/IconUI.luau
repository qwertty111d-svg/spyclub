local IconUI={}
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function frame(parent,size,pos,color,rotation,radius)
    local f=make("Frame",parent,{AnchorPoint=Vector2.new(.5,.5),Size=size,Position=pos,BackgroundColor3=color,BorderSizePixel=0,Rotation=rotation or 0})
    if radius then make("UICorner",f,{CornerRadius=UDim.new(radius,0)}) end
    return f
end
local function outline(parent,size,pos,color,radius,thickness)
    local f=frame(parent,size,pos,color,0,radius)
    f.BackgroundTransparency=1
    make("UIStroke",f,{Color=color,Thickness=thickness or 1.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    return f
end
local function root(parent)
    return make("Frame",parent,{Name="VectorIcon",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(24,24),BackgroundTransparency=1})
end
function IconUI.draw(parent,name,color)
    local old=parent:FindFirstChild("VectorIcon")
    if old then old:Destroy() end
    local r=root(parent)
    color=color or Color3.new(1,1,1)
    if name=="shop" then
        outline(r,UDim2.fromOffset(17,15),UDim2.fromOffset(12,14),color,.18,1.7)
        local h=outline(r,UDim2.fromOffset(9,7),UDim2.fromOffset(12,7),color,.45,1.7)
        h.ClipsDescendants=true
        frame(r,UDim2.fromOffset(11,5),UDim2.fromOffset(12,9.7),parent.BackgroundColor3,0,.35)
    elseif name=="inventory" then
        outline(r,UDim2.fromOffset(18,13),UDim2.fromOffset(12,14),color,.16,1.7)
        outline(r,UDim2.fromOffset(9,5),UDim2.fromOffset(12,7),color,.35,1.6)
        frame(r,UDim2.fromOffset(4,2),UDim2.fromOffset(12,13),color,0,.5)
    elseif name=="daily" then
        outline(r,UDim2.fromOffset(18,17),UDim2.fromOffset(12,13),color,.15,1.7)
        frame(r,UDim2.fromOffset(18,2),UDim2.fromOffset(12,9),color)
        for _,x in ipairs({8,16}) do frame(r,UDim2.fromOffset(2,5),UDim2.fromOffset(x,5),color,0,.5) end
        frame(r,UDim2.fromOffset(4,4),UDim2.fromOffset(12,15),color,45,.15)
    elseif name=="highstakes" then
        frame(r,UDim2.fromOffset(18,3),UDim2.fromOffset(12,18),color,0,.35)
        for i,x in ipairs({6.5,12,17.5}) do
            local h=i==2 and 10 or 7
            frame(r,UDim2.fromOffset(4,h),UDim2.fromOffset(x,16-h/2),color,0,.3)
            frame(r,UDim2.fromOffset(4,4),UDim2.fromOffset(x,9-h/2),color,45,.1)
        end
    elseif name=="guide" then
        local o=outline(r,UDim2.fromOffset(18,18),UDim2.fromOffset(12,12),color,1,1.7)
        frame(o,UDim2.fromOffset(2,8),UDim2.fromOffset(9,11),color,0,.5)
        frame(o,UDim2.fromOffset(2.5,2.5),UDim2.fromOffset(9,5.5),color,0,1)
    elseif name=="settings" then
        for i,y in ipairs({6,12,18}) do
            frame(r,UDim2.fromOffset(18,2),UDim2.fromOffset(12,y),color,0,.5)
            local x=({8,15,10})[i]
            frame(r,UDim2.fromOffset(5,5),UDim2.fromOffset(x,y),color,0,1)
        end
    elseif name=="notes" then
        outline(r,UDim2.fromOffset(17,19),UDim2.fromOffset(12,12),color,.12,1.6)
        for _,y in ipairs({8,12,16}) do frame(r,UDim2.fromOffset(10,1.7),UDim2.fromOffset(12,y),color,0,.5) end
    elseif name=="coin" then
        local o=outline(r,UDim2.fromOffset(17,17),UDim2.fromOffset(12,12),color,1,1.7)
        frame(o,UDim2.fromOffset(6,6),UDim2.fromOffset(8.5,8.5),color,45,.08)
    else
        outline(r,UDim2.fromOffset(16,16),UDim2.fromOffset(12,12),color,.25,1.6)
    end
    return r
end
return IconUI
