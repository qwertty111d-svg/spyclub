-- One layout for the authored HudGui; existing button connections stay intact.
local TweenService=game:GetService("TweenService")
local player=game:GetService("Players").LocalPlayer
local Input=game:GetService("UserInputService")
local shared=game:GetService("ReplicatedStorage"):FindFirstChild("SpyShared")
local themeNode=shared and shared:FindFirstChild("UITheme")
local Theme=themeNode and require(themeNode)
local function externalPanel()
 return player and(player:GetAttribute("SpyTradeOpen")==true or player:GetAttribute("SpyPhoneActive")==true)
end
local HudController={}
HudController.__index=HudController
local C={surface=Color3.fromRGB(25,27,31),hover=Color3.fromRGB(57,59,63),
 text=Color3.fromRGB(244,240,231),line=Color3.fromRGB(87,89,93),
 cream=Color3.fromRGB(221,193,151),ink=Color3.fromRGB(26,28,32)}
-- Keep authored button names for existing hooks, with one character entry.
local definitions={{"Shop",nil,"accessoryRoll","profile"},
 {"Profile","hudProfile","profile"},{"Trade","hudTrade","trade"},{"Settings","hudSettings","settings"}}
local function dockText(definition,L)
 if definition[1]=="Shop" then
  local lang=player and player:GetAttribute("SpyLanguage")or"ru"
  return lang=="en"and"Character H"or lang=="zh"and"角色 H"or"Персонаж H"
 end
 return L(definition[2])
end

local function prepare(button,main)
 for _,child in ipairs(button:GetChildren()) do
  if child:IsA("GuiObject") then child.Visible=false
  elseif child:IsA("UIGradient") or child:IsA("UIScale") or child:IsA("UIListLayout") or child:IsA("UIPadding") or child:IsA("UITextSizeConstraint") then child:Destroy()
  elseif child:IsA("UIStroke") then child.Enabled=false end
 end
 local corner=button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner",button)
 corner.CornerRadius=UDim.new(0,12)
 local outline=Instance.new("UIStroke")
 outline.Name="HudOutline";outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 outline.Color=C.line;outline.Transparency=main and .65 or 1;outline.Thickness=1;outline.Parent=button
 button.TextScaled=false;button.AutoButtonColor=false;button.BackgroundTransparency=main and 0 or 1;button.BorderSizePixel=0
 button.BackgroundColor3=main and C.cream or C.surface
 button.TextColor3=main and C.ink or C.text;button.TextTransparency=0
 button.Font=Enum.Font.BuilderSansBold
 button.TextSize=main and 18 or 16
 button.TextXAlignment=Enum.TextXAlignment.Center;button.TextYAlignment=Enum.TextYAlignment.Center
 if Theme and Theme.button then Theme.button(button,main,{arrow=main})end
 return outline
end

function HudController.new(gui,L)
 local self=setmetatable({Gui=gui,L=L,Connections={},Buttons={},Active=nil,MenuExpanded=false,InRound=false},HudController)
 self.MainAction=gui:WaitForChild("MainAction");self.BottomDock=gui:WaitForChild("BottomDesk")
 self.MainAction.Active=true;prepare(self.MainAction,true)
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
 self.MenuButton=Instance.new("TextButton");self.MenuButton.Name="MobileMenu";self.MenuButton.Parent=gui
 prepare(self.MenuButton,false);self.MenuButton.BackgroundTransparency=.08
 table.insert(self.Connections,self.MenuButton.Activated:Connect(function()
  self.MenuExpanded=not self.MenuExpanded;self:resize()
 end))
 local status=gui:FindFirstChild("TopStatus")
 if status then
  for _,n in ipairs(status:GetDescendants()) do
   if n:IsA("TextLabel") then n.Font=Enum.Font.BuilderSansBold end
   if n:IsA("UIStroke") then n.Color=C.line;n.Transparency=.45;n.Thickness=1 end
  end
 end
 local tooltip=gui:FindFirstChild("Tooltip");if tooltip then tooltip.Visible=false end
 local dock=self.BottomDock
 dock.BackgroundTransparency=1;dock.BackgroundColor3=C.surface;dock.BorderSizePixel=0
 for _,child in ipairs(dock:GetChildren()) do
  if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") then child:Destroy()
  elseif child:IsA("UIStroke") then child.Enabled=false
  elseif child:IsA("GuiObject") then child.Visible=false end
 end
 local corner=dock:FindFirstChildOfClass("UICorner") or Instance.new("UICorner",dock)
 corner.CornerRadius=UDim.new(0,6)
 local dockLine=dock:FindFirstChild("DockOutline") or Instance.new("UIStroke",dock)
 dockLine.Name="DockOutline";dockLine.Enabled=true;dockLine.Color=C.line;dockLine.Transparency=1;dockLine.Thickness=1
 for _,definition in ipairs(definitions) do
  local button=dock:FindFirstChild(definition[1])
  if not button then button=Instance.new("TextButton");button.Name=definition[1];button.Parent=dock end
  button.Visible=true;button.Active=true
  button.Text=dockText(definition,L)
  button:SetAttribute("SpyUserText",true)
  local outline=prepare(button,false)
  button.BackgroundTransparency=.22
  local glyph
  if Theme and Theme.icon then glyph=Theme.icon(button,definition[4] or definition[3],definition[1]=="Shop"and C.cream or C.text)end
  if glyph then glyph.AnchorPoint=Vector2.new(.5,0);glyph.Position=UDim2.new(.5,0,0,12);glyph.Size=UDim2.fromOffset(24,24)end
  button.TextTransparency=1;button.TextWrapped=false
  local caption=Instance.new("TextLabel");caption.Name="DockLabel";caption.Parent=button
  caption.BackgroundTransparency=1;caption.Position=UDim2.new(0,4,1,-31);caption.Size=UDim2.new(1,-8,0,24)
  caption.Font=Enum.Font.BuilderSansBold;caption.TextSize=15;caption.TextColor3=C.text
  caption.TextWrapped=false;caption.TextTruncate=Enum.TextTruncate.AtEnd;caption.Text=button.Text
  caption.TextColor3=definition[1]=="Shop"and C.cream or C.text
  caption:SetAttribute("SpyUserText",true)
  table.insert(self.Connections,button:GetPropertyChangedSignal("Text"):Connect(function()caption.Text=button.Text end))
  local rounded=button:FindFirstChildOfClass("UICorner");if rounded then rounded.CornerRadius=UDim.new(0,14)end
  local marker=Instance.new("Frame");marker.Name="ActiveMark";marker.Size=UDim2.new(1,-28,0,2)
  marker.Position=UDim2.new(0,14,1,-5);marker.BackgroundColor3=C.cream;marker.BackgroundTransparency=0;marker.BorderSizePixel=0;marker.Visible=false;marker.Parent=button
  self.Buttons[definition[1]]={Button=button,Caption=caption,Stroke=outline,Marker=marker,Key=definition[2],Panel=definition[3]}
  if definition[1]=="Trade" then
   table.insert(self.Connections,button.Activated:Connect(function()
    local opener=gui.Parent and gui.Parent:FindFirstChild("SpyOpenTrade")
    if opener and opener:IsA("BindableEvent") then opener:Fire() end
   end))
  end
  table.insert(self.Connections,button.MouseEnter:Connect(function()
   TweenService:Create(button,TweenInfo.new(.12),{BackgroundColor3=C.hover,BackgroundTransparency=.2}):Play()
  end))
  table.insert(self.Connections,button.MouseLeave:Connect(function()
   TweenService:Create(button,TweenInfo.new(.12),{BackgroundColor3=self.Active==definition[3] and C.hover or C.surface,BackgroundTransparency=self.Active==definition[3] and .08 or .22}):Play()
  end))
 end
 table.insert(self.Connections,gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:resize()end))
 if player then
  player:SetAttribute("SpyTradeDockReady",true)
  for _,key in ipairs({"SpyTradeOpen","SpyPhoneActive"})do
   table.insert(self.Connections,player:GetAttributeChangedSignal(key):Connect(function()self:resize()end))
  end
 end
 self:resize();self:update(false)
 return self
end

function HudController:resize()
 local width=math.max(1,self.Gui.AbsoluteSize.X)
 local screenHeight=self.Gui.AbsoluteSize.Y
 self.Mobile=Input.TouchEnabled or width<600 or screenHeight<430
 local compact=self.Mobile
 local columns=compact and 2 or #definitions
 local gap=8
 local padding=8
 local buttonWidth=math.max(1,math.min(116,math.floor((width-28-padding*2-gap*(columns-1))/columns)))
 local height=compact and 76 or 80
 local dockWidth=columns*buttonWidth+(columns-1)*gap+padding*2
 local dockHeight=height*(compact and 2 or 1)+padding*2+(compact and gap or 0)
 local bottom=self.Mobile and width<600 and screenHeight>=430 and 176 or 16
 self.BottomDock.AnchorPoint=Vector2.new(.5,1)
 self.BottomDock.Position=UDim2.new(.5,0,1,-bottom)
 self.BottomDock.Size=UDim2.fromOffset(dockWidth,dockHeight)
 for index,definition in ipairs(definitions) do
  local button=self.Buttons[definition[1]].Button
  local row=math.floor((index-1)/columns);local col=(index-1)%columns
  local shift=0
  button.AnchorPoint=Vector2.new(0,0)
  button.Position=UDim2.fromOffset(padding+shift+col*(buttonWidth+gap),padding+row*(height+gap))
  button.Size=UDim2.fromOffset(buttonWidth,height);button.TextSize=15
  self.Buttons[definition[1]].Caption.TextSize=compact and 14 or(definition[1]=="Shop"and 15 or 16)
 end
 self.MainAction.AnchorPoint=Vector2.new(.5,1)
 self.MainAction.Position=UDim2.new(.5,0,1,-(bottom+dockHeight+10))
 self.MainAction.Size=UDim2.fromOffset(math.max(1,math.min(236,width-28)),56)
 if self.Mobile then
  local actionWidth=screenHeight<430 and width<600 and 140 or math.min(212,math.max(140,width-160))
  local menuWidth=76;local groupWidth=actionWidth+menuWidth+8
  self.MainAction.AnchorPoint=Vector2.new(0,1)
  self.MainAction.Position=UDim2.new(.5,-groupWidth*.5,1,-bottom)
  self.MainAction.Size=UDim2.fromOffset(actionWidth,44);self.MainAction.TextSize=16
  self.MenuButton.AnchorPoint=Vector2.new(0,1)
  self.MenuButton.Position=UDim2.new(.5,-groupWidth*.5+actionWidth+8,1,-bottom)
  self.MenuButton.Size=UDim2.fromOffset(menuWidth,44);self.MenuButton.TextSize=14
  self.BottomDock.Position=UDim2.new(.5,0,1,-(bottom+54))
 end
 self.MainAction.Visible=not self.InRound and not self.Active and not externalPanel()
 self.MenuButton.Text=self.L("menuToggle")
 self.MenuButton.Visible=self.Mobile and not self.InRound and not self.Active and not externalPanel()
 self.BottomDock.Visible=not self.InRound and not self.Active and not externalPanel() and(not self.Mobile or self.MenuExpanded)
 local status=self.Gui:FindFirstChild("TopStatus")
 if status then
  local h=self.Mobile and 36 or 44;local w=self.Mobile and math.min(232,math.max(140,width-140))or 328
  status.AnchorPoint=Vector2.new(1,0);status.Position=UDim2.new(1,-12,0,8);status.Size=UDim2.fromOffset(w,h)
  local coins=status:FindFirstChild("Coins");if coins then coins.Visible=false end
  for index,name in ipairs({"Level","Rolls"})do
   local pill=status:FindFirstChild(name)
   if pill then
    pill.AnchorPoint=Vector2.new();pill.Position=UDim2.fromOffset((index-1)*(w*.5+3),0);pill.Size=UDim2.fromOffset(w*.5-3,h)
    local value=pill:FindFirstChild("Value")
    if value then value.Position=UDim2.fromOffset(8,0);value.Size=UDim2.new(1,-16,1,0);value.TextSize=self.Mobile and 14 or 16 end
    local icon=pill:FindFirstChild("Icon");if icon then icon.Position=UDim2.fromOffset(6,(h-14)*.5);icon.Size=UDim2.fromOffset(14,14)end
   end
  end
 end
end

function HudController:setActive(name)
 self.Active=name
 if name then self.MenuExpanded=false end
 self:resize()
 for _,item in pairs(self.Buttons) do
  local active=name==item.Panel
  item.Button.BackgroundColor3=active and C.hover or C.surface
  item.Button.TextColor3=(active or item.Panel=="accessoryRoll")and C.cream or C.text
  item.Caption.TextColor3=item.Button.TextColor3
  item.Button.BackgroundTransparency=active and .08 or .22
  item.Marker.Visible=false
  local glyph=item.Button:FindFirstChild("ControlIcon")
  if glyph then for _,node in ipairs(glyph:GetDescendants())do if node:IsA("Frame")then node.BackgroundColor3=item.Button.TextColor3 elseif node:IsA("UIStroke")then node.Color=item.Button.TextColor3 end end end
  item.Stroke.Transparency=1
 end
end

function HudController:update(inRound)
 self.InRound=inRound;self.MainAction.Visible=not inRound;self:resize()
 local lang=player and player:GetAttribute("SpyLanguage")or"ru"
 self.MainAction:SetAttribute("SpyUserText",true)
 self.MainAction.Text=lang=="en"and"Play"or lang=="zh"and"开始游戏"or"Играть"
 for _,definition in ipairs(definitions)do
  local item=self.Buttons[definition[1]]
  item.Button.Text=dockText(definition,self.L);item.Caption.Text=item.Button.Text
 end
end

function HudController:Destroy()
 for _,connection in ipairs(self.Connections) do connection:Disconnect() end
 table.clear(self.Connections)
 if player then player:SetAttribute("SpyTradeDockReady",false) end
end
return HudController
