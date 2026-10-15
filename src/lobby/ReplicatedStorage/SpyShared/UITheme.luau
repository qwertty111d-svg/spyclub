local UITheme={}
UITheme.Colors={
    Background=Color3.fromRGB(16,17,20),
    Surface=Color3.fromRGB(26,27,31),
    SurfaceRaised=Color3.fromRGB(49,50,56),
    Border=Color3.fromRGB(111,113,122),
    Text=Color3.fromRGB(245,245,247),
    Muted=Color3.fromRGB(168,170,179),
    Gold=Color3.fromRGB(238,238,241),
    Accent=Color3.fromRGB(238,238,241),
    Lilac=Color3.fromRGB(180,182,190),
    Danger=Color3.fromRGB(205,130,120),
}
UITheme.Metrics={
    Radius=3,
    RadiusSmall=2,
    Gap=12,
    GapSmall=8,
    SectionGap=16,
    Padding=18,
    PaddingLarge=22,
    ButtonHeight=44,
    ControlHeight=42,
    DockWidth=104,
}
UITheme.Text={Title=28,Section=18,Body=16,Caption=13,Button=16}
UITheme.Motion={Fast=.12,Normal=.18,Slow=.24,Easing=Enum.EasingStyle.Quint}

local function make(class,parent,props)
 local n=Instance.new(class);for key,value in pairs(props or{})do n[key]=value end;n.Parent=parent;return n
end
function UITheme.icon(parent,kind,color)
 color=color or UITheme.Colors.Text
 local old=parent:FindFirstChild("ControlIcon");if old then old:Destroy()end
 local root=make("Frame",parent,{Name="ControlIcon",Size=UDim2.fromOffset(24,24),BackgroundTransparency=1})
 local function part(x,y,w,h,round,outline,rotation)
  local f=make("Frame",root,{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=color,BorderSizePixel=0,Rotation=rotation or 0,BackgroundTransparency=outline and 1 or 0})
  if round then make("UICorner",f,{CornerRadius=UDim.new(round,0)})end
  if outline then make("UIStroke",f,{Color=color,Thickness=1.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})end
  return f
 end
 if kind=="shop"or kind=="inventory"then
  part(.16,.38,.68,.5,.16,true);part(.34,.2,.32,.25,.3,true)
  if kind=="inventory"then part(.44,.48,.12,.07,.3)end
 elseif kind=="profile"then
  part(.36,.12,.28,.28,1,true);part(.18,.58,.64,.28,.35,true)
 elseif kind=="trade"then
  part(.14,.28,.65,.07,.3);part(.60,.20,.22,.07,.3,false,35);part(.60,.36,.22,.07,.3,false,-35)
  part(.20,.68,.65,.07,.3);part(.14,.59,.22,.07,.3,false,-35);part(.14,.77,.22,.07,.3,false,35)
 elseif kind=="settings"then
  for i,y in ipairs({.25,.5,.75})do part(.12,y,.76,.065,.5);part(({.3,.65,.43})[i],y-.08,.14,.22,.5)end
 elseif kind=="coin"then
  part(.1,.1,.8,.8,1,true);part(.40,.32,.20,.36,.12,true)
 elseif kind=="play"or kind=="arrow"then
  part(.26,.30,.45,.09,.3,false,38);part(.26,.58,.45,.09,.3,false,-38)
 else part(.16,.16,.68,.68,.3,true)end
 return root
end
-- Owners keep geometry, captions, state and existing click callbacks.
function UITheme.button(button,primary,options)
 options=options or{}
 button.BorderSizePixel=0;button.Font=Enum.Font.BuilderSansBold;button.TextScaled=false
 button.TextSize=math.min(button.TextSize,18)
 if not button.TextWrapped then button.TextTruncate=Enum.TextTruncate.AtEnd end
 button.BackgroundColor3=primary and UITheme.Colors.Gold or UITheme.Colors.SurfaceRaised
 button.BackgroundTransparency=primary and 0 or options.quiet and .45 or .12
 button.TextColor3=primary and UITheme.Colors.Background or UITheme.Colors.Text
 local corner=button:FindFirstChildOfClass("UICorner")or make("UICorner",button)
 corner.CornerRadius=UDim.new(0,3)
 local line=button:FindFirstChild("ControlEdge")or make("UIStroke",button,{Name="ControlEdge",ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 line.Color=primary and UITheme.Colors.Text or UITheme.Colors.Border;line.Transparency=primary and .65 or .8;line.Thickness=1
 -- Keep the host free of content padding: it also offsets child graphics in Roblox.
 for _,name in ipairs({"ControlPadding","ActionCap"})do
  local old=button:FindFirstChild(name);if old then old:Destroy()end
 end

end
return UITheme
