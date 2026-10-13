-- One layout owner: current stage, primary actions and a closed secondary menu.
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local HUD={}
local docks=setmetatable({}, {__mode='k'})
local INK=Color3.fromRGB(25,27,31)
local PANEL=Color3.fromRGB(46,48,52)
local WHITE=Color3.fromRGB(244,240,231)
local MUTED=Color3.fromRGB(188,187,181)

function HUD.metrics(v,touch)
 local margin=v.X<520 and 12 or 20
 local short=v.Y<420
 local width=math.min(440,v.X-margin*2)
 local x=(v.X-width)*.5
 local controlsWidth=v.X<740 and width-108 or width
 local controlsY=v.Y-margin-48
 local primaryY=controlsY-56
 local half=(width-10)*.5
 local phaseWidth=math.min(560,v.X-margin*2)
 return{
  phase={x=(v.X-phaseWidth)*.5,y=12,w=phaseWidth,h=v.Y<260 and math.max(44,math.min(108,v.Y-156))or short and 108 or 128},
  controls={x=x,y=controlsY,w=controlsWidth,h=48},
  ready={x=x,y=primaryY,w=half,h=48},
  guess={x=x+half+10,y=primaryY,w=half,h=48},
  dock={x=v.X-margin-(v.X<740 and 98 or 120),y=controlsY+1,w=v.X<740 and 98 or 120,h=46,body=math.max(44,math.min(250,controlsY-24))},
  compact=touch or v.X<1000,
 }
end

local function create(pg)
 local old=pg:FindFirstChild('SpyMatchActions');if old then old:Destroy()end
 local player=Players.LocalPlayer
 local RS=game:GetService('ReplicatedStorage')
 local function make(class,name,parent,props)
  local n=Instance.new(class);n.Name=name;for k,v in pairs(props)do n[k]=v end;n.Parent=parent;return n
 end
 local gui=make('ScreenGui','SpyMatchActions',pg,{ResetOnSpawn=false,IgnoreGuiInset=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=310,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local root=make('Frame','ActionsDock',gui,{BackgroundColor3=INK,BackgroundTransparency=.12,BorderSizePixel=0,Size=UDim2.fromOffset(120,46)})
 make('UICorner','Corner',root,{CornerRadius=UDim.new(0,16)})
 make('UIStroke','Outline',root,{Color=Color3.fromRGB(92,97,101),Transparency=.65,Thickness=1})
 local toggle=make('TextButton','ActionsToggle',root,{Size=UDim2.new(1,0,0,46),BackgroundTransparency=1,Text='',TextColor3=WHITE,TextSize=16,Font=Enum.Font.BuilderSansBold,AutoButtonColor=true})
 local list=make('ScrollingFrame','ActionsList',root,{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,0),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=MUTED,ScrollingDirection=Enum.ScrollingDirection.Y,Visible=false})
 local primary=make('Frame','PrimaryActions',gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
 local state={gui=gui,root=root,list=list,toggle=toggle,primary=primary,buttons={},expanded=false}
 local connections,watched={},setmetatable({}, {__mode='k'})
 local sessionConnection
 local function covered()
  if player:GetAttribute('SpyMatchIntroActive')==true or player:GetAttribute('SpyCaseCinematicActive')==true or player:GetAttribute('SpyPhoneActive')==true or player:GetAttribute('SpyMatchChatOpen')==true then return true end
  local main=pg:FindFirstChild('MatchUI');local curtain=main and main:FindFirstChild('Blackout')
  if main and(not main.Enabled or curtain and curtain.Visible)then return true end
  local session=RS:FindFirstChild('MatchSession');local phase=session and session:GetAttribute('RoundPhase')
  return phase~=nil and phase~='Hint'and phase~='Discuss'and phase~='ExtraRound'
 end
 function state.fit()
  if not gui.Parent then return end
  local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
  local inset,bottom=game:GetService('GuiService'):GetGuiInset();v=Vector2.new(v.X-inset.X-bottom.X,v.Y-inset.Y-bottom.Y)
  local m=HUD.metrics(v,UIS.TouchEnabled)
  state.compact=m.compact
  local hidden=covered();root.Visible=not hidden;primary.Visible=not hidden
  if hidden then state.expanded=false end
  table.sort(state.buttons,function(a,b)if a.order~=b.order then return a.order<b.order end;return a.button.Name<b.button.Name end)
  local y=6
  for _,entry in ipairs(state.buttons)do
   local b=entry.button
   if b.Parent==primary then
    local r=b.Name=='SpyGuessButton'and m.guess or m.ready
    b.Position=UDim2.fromOffset(r.x,r.y);b.Size=UDim2.fromOffset(r.w,r.h)
   elseif b.Parent==list and b.Visible then b.Position=UDim2.fromOffset(8,y);b.Size=UDim2.new(1,-16,0,44);y+=50 end
  end
  local body=state.expanded and math.min(y,m.dock.body)or 0
  root.Position=UDim2.fromOffset(v.X-(v.X<520 and 12 or 20)-(state.expanded and 220 or m.dock.w),m.dock.y-body)
  root.Size=UDim2.fromOffset(state.expanded and 220 or m.dock.w,46+body)
  toggle.Position=UDim2.fromOffset(0,body)
  list.Visible=state.expanded;list.Size=UDim2.new(1,0,0,body);list.CanvasSize=UDim2.fromOffset(0,y)
  local lang=player:GetAttribute('SpyLanguage')
  toggle.Text=(lang=='en'and'Menu'or lang=='zh'and'菜单'or'Меню')..(state.expanded and'  ×'or'  ≡')
  toggle.Active=true;toggle.Selectable=true
 end
 toggle.Activated:Connect(function()state.expanded=not state.expanded;state.fit()end)
 local function watch(n)
  if watched[n]then return end
  local property=n.Name=='Blackout'and n:IsA('GuiObject')and'Visible'or n.Name=='MatchUI'and n:IsA('ScreenGui')and'Enabled'
  if property then watched[n]=true;connections[#connections+1]=n:GetPropertyChangedSignal(property):Connect(state.fit)end
 end
 local function bindSession(n)
  if n.Name~='MatchSession'then return end
  if sessionConnection then sessionConnection:Disconnect()end
  sessionConnection=n:GetAttributeChangedSignal('RoundPhase'):Connect(state.fit);state.fit()
 end
 for _,n in ipairs(pg:GetDescendants())do watch(n)end
 connections[#connections+1]=pg.DescendantAdded:Connect(function(n)watch(n);state.fit()end)
 connections[#connections+1]=pg.ChildRemoved:Connect(state.fit)
 connections[#connections+1]=RS.ChildAdded:Connect(bindSession)
 connections[#connections+1]=RS.ChildRemoved:Connect(state.fit)
 local session=RS:FindFirstChild('MatchSession');if session then bindSession(session)end
 for _,key in ipairs({'SpyLanguage','SpyMatchIntroActive','SpyCaseCinematicActive','SpyPhoneActive','SpyMatchChatOpen'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(state.fit)end
 connections[#connections+1]=UIS:GetPropertyChangedSignal('TouchEnabled'):Connect(state.fit)
 if workspace.CurrentCamera then connections[#connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(state.fit)end
 gui.Destroying:Connect(function()
  for _,c in ipairs(connections)do c:Disconnect()end;if sessionConnection then sessionConnection:Disconnect()end
  for _,entry in ipairs(state.buttons)do for _,c in ipairs(entry.connections)do c:Disconnect()end end;docks[pg]=nil
 end)
 docks[pg]=state;state.fit();return state
end

function HUD.register(pg,button,order,key)
 local state=docks[pg]or create(pg)
 for _,entry in ipairs(state.buttons)do if entry.button==button then return state end end
 local contextual=button.Name=='SpyGuessButton'or button.Name=='AskQuestion'
 button.Parent=contextual and state.primary or state.list;button.AnchorPoint=Vector2.new();button.ZIndex=2
 button.BorderSizePixel=0;button.BackgroundColor3=contextual and Color3.fromRGB(48,77,68)or PANEL;button.BackgroundTransparency=.08
 button.Font=Enum.Font.BuilderSansBold;button.TextSize=16;button.TextColor3=WHITE
 button.TextXAlignment=contextual and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left;button.TextWrapped=contextual;button.TextTruncate=contextual and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
 local corner=button:FindFirstChildOfClass('UICorner');if corner then corner.CornerRadius=UDim.new(0,14)else corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,14);corner.Parent=button end
 local padding=Instance.new('UIPadding');padding.Name='ActionPadding';padding.PaddingLeft=UDim.new(0,contextual and 8 or 13);padding.PaddingRight=UDim.new(0,key and 45 or 10);padding.Parent=button
 if key then
  local cap=Instance.new('TextLabel');cap.Name='ActionKey';cap.Text=key;cap.AnchorPoint=Vector2.new(1,.5);cap.Position=UDim2.new(1,-8,.5,0);cap.Size=UDim2.fromOffset(30,26)
  cap.BackgroundColor3=INK;cap.TextColor3=MUTED;cap.Font=Enum.Font.BuilderSansBold;cap.TextSize=13;cap.BorderSizePixel=0;cap.ZIndex=3;cap.Parent=button
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=cap
 end
 local entry={button=button,order=order,connections={}};table.insert(state.buttons,entry)
 entry.connections[#entry.connections+1]=button:GetPropertyChangedSignal('Visible'):Connect(state.fit)
 entry.connections[#entry.connections+1]=button.Activated:Connect(function()state.expanded=false;state.fit()end)
 entry.connections[#entry.connections+1]=button.Destroying:Connect(function()
  for _,c in ipairs(entry.connections)do c:Disconnect()end
  for i,value in ipairs(state.buttons)do if value==entry then table.remove(state.buttons,i);break end end;state.fit()
 end)
 state.fit();return state
end

-- Keep the pre-existing high-layer creator entry reachable on touch while
-- a loading curtain or ballot covers the normal dock. Only one entry is shown.
function HUD.creatorAccess(pg,highGui,launcher,onOpen)
    local player=Players.LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local rescue=launcher:Clone();rescue.Name="CreatorLoadingAccess"
    rescue.AnchorPoint=Vector2.new(0,1);rescue.Position=UDim2.new(0,16,1,-20)
    rescue.Size=UDim2.fromOffset(140,44);rescue.ZIndex=1;rescue.Parent=highGui
    local connections,watched={},setmetatable({}, {__mode="k"})
    local sessionConnection
    local active={Hint=true,Discuss=true,ExtraRound=true}
    local function refresh()
        local allowed=player:GetAttribute("SpyIsAdmin")==true
        local main=pg:FindFirstChild("MatchUI")
        local curtain=main and main:FindFirstChild("Blackout")
        local session=RS:FindFirstChild("MatchSession")
        local phase=session and session:GetAttribute("RoundPhase")
        local covered=not main or not main.Enabled or (curtain and curtain.Visible)or not active[phase]
        rescue.Visible=allowed and covered or false
        launcher.Visible=allowed and not covered
    end
    local function watch(n)
        if watched[n]then return end
        local property=n.Name=="Blackout"and n:IsA("GuiObject")and "Visible"
            or n.Name=="MatchUI"and n:IsA("ScreenGui")and "Enabled"
        if property then
            watched[n]=true;table.insert(connections,n:GetPropertyChangedSignal(property):Connect(refresh))
            refresh()
        end
    end
    local function bindSession(n)
        if n.Name~="MatchSession"then return end
        if sessionConnection then sessionConnection:Disconnect()end
        sessionConnection=n:GetAttributeChangedSignal("RoundPhase"):Connect(refresh);refresh()
    end
    rescue.Activated:Connect(onOpen)
    table.insert(connections,player:GetAttributeChangedSignal("SpyIsAdmin"):Connect(refresh))
    table.insert(connections,pg.DescendantAdded:Connect(watch))
    table.insert(connections,pg.ChildRemoved:Connect(refresh))
    table.insert(connections,RS.ChildAdded:Connect(bindSession))
    table.insert(connections,RS.ChildRemoved:Connect(refresh))
    for _,n in ipairs(pg:GetDescendants())do watch(n)end
    local initial=RS:FindFirstChild("MatchSession");if initial then bindSession(initial)end
    local function destroy()
        for _,c in ipairs(connections)do c:Disconnect()end
        if sessionConnection then sessionConnection:Disconnect()end
    end
    highGui.Destroying:Connect(destroy);refresh()
    return {refresh=refresh,destroy=destroy}
end
return HUD
