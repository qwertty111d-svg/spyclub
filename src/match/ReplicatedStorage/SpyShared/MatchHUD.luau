-- One layout owner: current stage, primary actions and a closed secondary menu.
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local HUD={}
local docks=setmetatable({}, {__mode='k'})
local INK=Color3.fromRGB(25,27,31)
local PANEL=Color3.fromRGB(46,48,52)
local WHITE=Color3.fromRGB(244,240,231)
local MUTED=Color3.fromRGB(188,187,181)
local menuPhases={Waiting=true,TopicVote=true,TopicChosen=true,Role=true,Hint=true,Discuss=true,Vote=true,ExtraRound=true,Result=true,Finished=true}
local primaryPhases={Hint=true,Discuss=true,ExtraRound=true}

function HUD.visibility(phase,covered)
 return{menu=not covered and menuPhases[phase]==true,primary=not covered and primaryPhases[phase]==true}
end

function HUD.metrics(v,touch,active)
 local margin=v.X<520 and 12 or 20
 local width=math.min(420,v.X-margin*2)
 local x=(v.X-width)*.5
 local dockWidth=v.X<360 and 92 or 104
 local controlsWidth=width-dockWidth-8
 local controlsY=v.Y-margin-48
 local primaryY=controlsY-56
 active=active or {ready=true,guess=true}
 local split=active.ready and active.guess
 local primaryWidth=split and width or math.min(320,width)
 local primaryX=(v.X-primaryWidth)*.5
 local half=(primaryWidth-10)*.5
 local phaseWidth=math.min(560,v.X-margin*2)
 local phaseHeight=v.Y<300 and 44 or v.Y<420 and 80 or v.X<420 and 108 or 96
 return{
  phase={x=(v.X-phaseWidth)*.5,y=12,w=phaseWidth,h=phaseHeight},
  controls={x=x,y=controlsY,w=controlsWidth,h=48},
  ready={x=primaryX,y=primaryY,w=split and half or primaryWidth,h=48},
  guess={x=split and primaryX+half+10 or primaryX,y=primaryY,w=split and half or primaryWidth,h=48},
  dock={x=x+controlsWidth+8,y=controlsY,w=dockWidth,h=48,body=math.max(44,math.min(250,controlsY-phaseHeight-28))},
  compact=touch or v.X<1000,
 }
end

function HUD.modal(v,width,height)
 local utilities=HUD.metrics(v,false).controls
 local w=math.min(width,v.X-24)
 local h=math.min(height,math.max(0,utilities.y-24))
 return{x=(v.X-w)*.5,y=(utilities.y-h)*.5,w=w,h=h}
end

-- The smallest safe canvases prioritize the selector and confirmation target.
-- Names stay selectable through the existing scrolling list when details fold.
function HUD.ballot(height)
 local short=height<300
 local minimal=height<146
 local top=minimal and 0 or short and 42 or 90
 local footer=minimal and 52 or short and 60 or 118
 return{short=short,minimal=minimal,choicesTop=top,choicesHeight=math.max(0,height-top-footer),
  confirmBottom=minimal and 0 or short and 12 or 16,extraBottom=minimal and 0 or short and 12 or 70}
end

function HUD.topic(height)
 local compact=height<220
 return{compact=compact,choicesTop=compact and 36 or 108,
  choicesHeight=math.max(0,height-(compact and 44 or 164))}
end

local function create(pg)
 local old=pg:FindFirstChild('SpyMatchActions');if old then old:Destroy()end
 local player=Players.LocalPlayer
 local RS=game:GetService('ReplicatedStorage')
 local function make(class,name,parent,props)
  local n=Instance.new(class);n.Name=name;for k,v in pairs(props)do n[k]=v end;n.Parent=parent;return n
 end
 local gui=make('ScreenGui','SpyMatchActions',pg,{ResetOnSpawn=false,IgnoreGuiInset=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=310,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local root=make('Frame','ActionsDock',gui,{BackgroundColor3=INK,BackgroundTransparency=.12,BorderSizePixel=0,Size=UDim2.fromOffset(104,48)})
 make('UICorner','Corner',root,{CornerRadius=UDim.new(0,12)})
 make('UIStroke','Outline',root,{Color=Color3.fromRGB(96,83,66),Transparency=.7,Thickness=1})
 local toggle=make('TextButton','ActionsToggle',root,{Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,Text='',TextColor3=WHITE,TextSize=15,Font=Enum.Font.BuilderSansBold,AutoButtonColor=true})
 local list=make('ScrollingFrame','ActionsList',root,{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,0),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=MUTED,ScrollingDirection=Enum.ScrollingDirection.Y,Visible=false})
 list.BackgroundColor3=INK
 make('UICorner','Corner',list,{CornerRadius=UDim.new(0,12)})
 make('UICorner','Corner',toggle,{CornerRadius=UDim.new(0,12)})
 local primary=make('Frame','PrimaryActions',gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
 local state={gui=gui,root=root,list=list,toggle=toggle,primary=primary,buttons={},surfaces={},expanded=false}
 local connections,watched={},setmetatable({}, {__mode='k'})
 local sessionConnection
 local function covered()
  if player:GetAttribute('SpyMatchIntroActive')==true or player:GetAttribute('SpyCaseCinematicActive')==true or player:GetAttribute('SpyPhoneActive')==true or player:GetAttribute('SpyMatchChatOpen')==true or player:GetAttribute('SpyCharacterMenuOpen')==true then return true end
  local main=pg:FindFirstChild('MatchUI');local curtain=main and main:FindFirstChild('Blackout')
  if not main or not main.Enabled or curtain and curtain.Visible then return true end
  return false
 end
 function state.fit()
  if not gui.Parent then return end
  local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
  local inset,bottom=game:GetService('GuiService'):GetGuiInset();v=Vector2.new(v.X-inset.X-bottom.X,v.Y-inset.Y-bottom.Y)
  local active={ready=false,guess=false}
  for _,entry in ipairs(state.buttons)do
   if entry.button.Parent==primary and entry.button.Visible then active[entry.slot]=true end
  end
  for _,entry in ipairs(state.surfaces)do
   if entry.object.Parent==primary and entry.object.Visible then active[entry.slot]=true end
  end
  local m=HUD.metrics(v,UIS.TouchEnabled,active)
  state.compact=m.compact
  local hidden=covered()
  local session=RS:FindFirstChild('MatchSession');local phase=session and session:GetAttribute('RoundPhase')
  local visible=HUD.visibility(phase,hidden)
  root.Visible=visible.menu;primary.Visible=visible.primary
  if hidden then state.expanded=false end
  table.sort(state.buttons,function(a,b)if a.order~=b.order then return a.order<b.order end;return a.button.Name<b.button.Name end)
  local y=6
  for _,entry in ipairs(state.buttons)do
   local b=entry.button
   if b.Parent==primary then
    local r=m[entry.slot]
    b.Position=UDim2.fromOffset(r.x,r.y);b.Size=UDim2.fromOffset(r.w,r.h)
   elseif b.Parent==list and b.Visible then b.Position=UDim2.fromOffset(8,y);b.Size=UDim2.new(1,-16,0,44);y+=50 end
   local keycap=b:FindFirstChild('ActionKey');if keycap then keycap.Visible=not UIS.TouchEnabled end
  end
  for _,entry in ipairs(state.surfaces)do
   local r=m[entry.slot];entry.object.Position=UDim2.fromOffset(r.x,r.y);entry.object.Size=UDim2.fromOffset(r.w,r.h)
  end
  local body=state.expanded and math.min(y,m.dock.body)or 0
  local dockWidth=state.expanded and math.min(230,v.X-24)or m.dock.w
  root.Position=UDim2.fromOffset(m.dock.x+m.dock.w-dockWidth,m.dock.y-body)
  root.Size=UDim2.fromOffset(dockWidth,m.dock.h+body)
  -- Only the menu list grows. Its collapsed target keeps its original slot,
  -- leaving Card and Chat reachable alongside it when the menu is expanded.
  root.BackgroundTransparency=state.expanded and 1 or .12
  root.Outline.Transparency=state.expanded and 1 or .7
  toggle.BackgroundColor3=INK;toggle.BackgroundTransparency=state.expanded and .12 or 1
  toggle.Position=UDim2.fromOffset(dockWidth-m.dock.w,body)
  toggle.Size=UDim2.fromOffset(m.dock.w,m.dock.h)
  list.BackgroundTransparency=state.expanded and .06 or 1
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
 for _,key in ipairs({'SpyLanguage','SpyMatchIntroActive','SpyCaseCinematicActive','SpyPhoneActive','SpyMatchChatOpen','SpyCharacterMenuOpen'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(state.fit)end
 connections[#connections+1]=UIS:GetPropertyChangedSignal('TouchEnabled'):Connect(state.fit)
 if workspace.CurrentCamera then connections[#connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(state.fit)end
 gui.Destroying:Connect(function()
  for _,c in ipairs(connections)do c:Disconnect()end;if sessionConnection then sessionConnection:Disconnect()end
  for _,entry in ipairs(state.buttons)do for _,c in ipairs(entry.connections)do c:Disconnect()end end;docks[pg]=nil
  for _,entry in ipairs(state.surfaces)do for _,c in ipairs(entry.connections)do c:Disconnect()end end
 end)
 docks[pg]=state;state.fit();return state
end

function HUD.register(pg,button,order,key)
 local state=docks[pg]or create(pg)
 for _,entry in ipairs(state.buttons)do if entry.button==button then return state end end
 local contextual=button.Name=='SpyGuessButton'or button.Name=='AskQuestion'
 button.Parent=contextual and state.primary or state.list;button.AnchorPoint=Vector2.new();button.ZIndex=2
 button.BorderSizePixel=0;button.BackgroundColor3=contextual and Color3.fromRGB(81,47,48)or PANEL;button.BackgroundTransparency=.08
 button.Font=Enum.Font.BuilderSansBold;button.TextSize=16;button.TextColor3=WHITE
 button.TextXAlignment=contextual and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left;button.TextWrapped=contextual;button.TextTruncate=contextual and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
 local corner=button:FindFirstChildOfClass('UICorner');if corner then corner.CornerRadius=UDim.new(0,12)else corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=button end
 local padding=Instance.new('UIPadding');padding.Name='ActionPadding';padding.PaddingLeft=UDim.new(0,contextual and 8 or 13);padding.PaddingRight=UDim.new(0,key and 45 or 10);padding.Parent=button
 if key then
  local cap=Instance.new('TextLabel');cap.Name='ActionKey';cap.Text=key;cap.AnchorPoint=Vector2.new(1,.5);cap.Position=UDim2.new(1,-8,.5,0);cap.Size=UDim2.fromOffset(30,26)
  cap.BackgroundColor3=INK;cap.TextColor3=MUTED;cap.Font=Enum.Font.BuilderSansBold;cap.TextSize=13;cap.BorderSizePixel=0;cap.ZIndex=3;cap.Parent=button
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=cap
 end
 local entry={button=button,order=order,slot=button.Name=='SpyGuessButton'and'guess'or'ready',connections={}};table.insert(state.buttons,entry)
 entry.connections[#entry.connections+1]=button:GetPropertyChangedSignal('Visible'):Connect(state.fit)
 entry.connections[#entry.connections+1]=button.Activated:Connect(function()state.expanded=false;state.fit()end)
 entry.connections[#entry.connections+1]=button.Destroying:Connect(function()
  for _,c in ipairs(entry.connections)do c:Disconnect()end
  for i,value in ipairs(state.buttons)do if value==entry then table.remove(state.buttons,i);break end end;state.fit()
 end)
 state.fit();return state
end

-- The turn-completion canvas shares the same responsive primary-action row.
-- Its captions, submission state and animation remain owned by turn controls.
function HUD.registerPrimary(pg,object,slot)
 local state=docks[pg]or create(pg)
 for _,entry in ipairs(state.surfaces)do if entry.object==object then return state end end
 object.Parent=state.primary;object.AnchorPoint=Vector2.new()
 local entry={object=object,slot=slot or'ready',connections={}}
 table.insert(state.surfaces,entry)
 entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal('Visible'):Connect(state.fit)
 entry.connections[#entry.connections+1]=object.Destroying:Connect(function()
  for _,c in ipairs(entry.connections)do c:Disconnect()end
  for i,value in ipairs(state.surfaces)do if value==entry then table.remove(state.surfaces,i);break end end
  state.fit()
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
