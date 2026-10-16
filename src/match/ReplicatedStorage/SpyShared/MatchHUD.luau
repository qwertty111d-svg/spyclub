-- Open table view: the current action at left, private utilities at right.
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local HUD={}
local docks=setmetatable({}, {__mode='k'})
local INK=Color3.fromRGB(27,29,33)
local PANEL=Color3.fromRGB(36,39,44)
local WHITE=Color3.fromRGB(238,236,230)
local MUTED=Color3.fromRGB(166,169,174)
local menuPhases={Waiting=true,TopicVote=true,TopicChosen=true,Role=true,Hint=true,Discuss=true,Vote=true,ExtraRound=true,Result=true,Finished=true}
local primaryPhases={Hint=true,Discuss=true,ExtraRound=true}

function HUD.visibility(phase,covered)
 return{menu=not covered and menuPhases[phase]==true,primary=not covered and primaryPhases[phase]==true}
end

function HUD.metrics(v,touch,active)
 local margin=v.X<520 and 12 or 20
 local compact=touch or v.X<700
 active=active or {ready=true,guess=true,utilities=true}
 local count=(active.ready and 1 or 0)+(active.guess and 1 or 0)
 local utilities=active.utilities~=false
 local gap,padding=v.X<360 and 6 or 12,0
 local desiredControls=utilities and(compact and(v.X<360 and 100 or 128)or 220)or 0
 local desiredMenu=v.X<360 and 44 or compact and 56 or 88
 local desiredPrimary=compact and(count==2 and 108 or 152)or(count==2 and 172 or 224)
 local gaps=(count+(utilities and 1 or 0))*gap
 local desiredWidth=count*desiredPrimary+desiredControls+desiredMenu+gaps+padding*2
 local width=math.min(desiredWidth,v.X-margin*2)
 local inner=width-padding*2
 local menuWidth=math.max(44,math.min(desiredMenu,inner-count*44-(utilities and 98 or 0)-gaps))
 local controlsWidth=utilities and math.max(98,math.min(desiredControls,inner-menuWidth-count*44-gaps))or 0
 local primaryWidth=count>0 and(inner-menuWidth-controlsWidth-gaps)/count or 0
 local spread=not compact and v.X>=900
 if spread then width=v.X-margin*2 end
 local x=(v.X-width)*.5
 local actionHeight=v.Y<300 and 44 or 52
 local y=v.Y-margin-actionHeight-8
 local cursor=x+padding
 local ready={x=cursor,y=y+4,w=primaryWidth,h=actionHeight}
 if active.ready then cursor+=primaryWidth+gap end
 local guess={x=cursor,y=y+4,w=primaryWidth,h=actionHeight}
 if active.guess then cursor+=primaryWidth+gap end
 if spread then cursor=v.X-margin-controlsWidth-menuWidth-(utilities and gap or 0)end
 local controls={x=cursor,y=y+4,w=controlsWidth,h=actionHeight}
 if utilities then cursor+=controlsWidth+gap end
 local phaseWidth=math.min(640,v.X-margin*2)
 local phaseHeight=v.Y<300 and 44 or v.Y<420 and 80 or v.X<420 and 132 or 112
 return{
  rail={x=x,y=y,w=width,h=actionHeight+8},
  phase={x=(v.X-phaseWidth)*.5,y=12,w=phaseWidth,h=phaseHeight},
  controls=controls,ready=ready,guess=guess,
  dock={x=cursor,y=y+4,w=menuWidth,h=actionHeight,body=math.max(44,math.min(294,y-phaseHeight-32))},
  compact=compact,gap=gap,
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
function HUD.ballot(height,width)
 local short=height<300
 local minimal=height<146
 local narrow=width~=nil and width<600
 local top=minimal and 0 or short and 42 or narrow and 110 or 116
 local footer=minimal and 52 or short and 60 or narrow and 118 or 86
 return{short=short,minimal=minimal,choicesTop=top,choicesHeight=math.max(0,height-top-footer),
  confirmBottom=minimal and 0 or short and 12 or 18,extraBottom=minimal and 0 or short and 12 or narrow and 72 or 18}
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
 local rail=make('Frame','BottomRail',gui,{BackgroundColor3=INK,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=1})
 make('UICorner','RailCorner',rail,{CornerRadius=UDim.new(0,3)})
 make('Frame','RailRule',rail,{Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-16,0,1),BackgroundColor3=Color3.fromRGB(112,114,120),BackgroundTransparency=1,BorderSizePixel=0})
 local root=make('Frame','ActionsDock',gui,{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(80,44),ZIndex=3})
 local toggle=make('TextButton','ActionsToggle',root,{Size=UDim2.new(1,0,0,44),BackgroundColor3=INK,BackgroundTransparency=.14,BorderSizePixel=0,Text='',TextColor3=WHITE,TextSize=14,Font=Enum.Font.BuilderSansMedium,AutoButtonColor=false})
 make('UICorner','MenuShape',toggle,{CornerRadius=UDim.new(0,3)})
 make('UIStroke','MenuOutline',toggle,{Color=Color3.fromRGB(86,90,97),Transparency=.72,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local list=make('ScrollingFrame','ActionsList',root,{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,0),CanvasSize=UDim2.new(),BackgroundColor3=INK,BackgroundTransparency=.08,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=MUTED,ScrollingDirection=Enum.ScrollingDirection.Y,Visible=false,ClipsDescendants=true})
 make('UICorner','Corner',list,{CornerRadius=UDim.new(0,3)})
 local primary=make('Frame','PrimaryActions',gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=3})
 local utilities=make('Frame','UtilityActions',gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=3})
 local state={gui=gui,root=root,list=list,toggle=toggle,rail=rail,primary=primary,utilities=utilities,buttons={},surfaces={},utilitySurfaces={},expanded=false}
 local connections,watched={},setmetatable({}, {__mode='k'})
 local sessionConnection
 local function covered()
  if player:GetAttribute('SpyMatchIntroActive')==true or player:GetAttribute('SpyCaseCinematicActive')==true or player:GetAttribute('SpyPhoneActive')==true or player:GetAttribute('SpyMatchChatOpen')==true or player:GetAttribute('SpyCharacterMenuOpen')==true or player:GetAttribute('SpyReturningToLobby')==true then return true end
  local main=pg:FindFirstChild('MatchUI');local curtain=main and main:FindFirstChild('Blackout')
  if not main or not main.Enabled or curtain and curtain.Visible then return true end
  return false
 end
 local function currentMetrics(v,touch)
  local session=RS:FindFirstChild('MatchSession');local phase=session and session:GetAttribute('RoundPhase')
  local visible=HUD.visibility(phase,covered())
  local active={ready=false,guess=false,utilities=false}
  if visible.primary then
   for _,entry in ipairs(state.surfaces)do if entry.object.Parent==primary and entry.object.Visible then active[entry.slot]=true end end
   for _,entry in ipairs(state.buttons)do if entry.contextual and entry.button.Visible and not active.ready then active.guess=true end end
  end
  for _,entry in ipairs(state.utilitySurfaces)do if entry.object.Visible and visible.menu then active.utilities=true end end
  return HUD.metrics(v,touch,active),visible,active
 end
 state.metrics=currentMetrics
 function state.fit()
  if not gui.Parent then return end
  local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
  local inset,bottom=game:GetService('GuiService'):GetGuiInset();v=Vector2.new(v.X-inset.X-bottom.X,v.Y-inset.Y-bottom.Y)
  local m,visible,active=currentMetrics(v,UIS.TouchEnabled)
  state.compact=m.compact
  rail.Position,rail.Size=UDim2.fromOffset(m.rail.x,m.rail.y),UDim2.fromOffset(m.rail.w,m.rail.h)
  rail.Visible,root.Visible,utilities.Visible,primary.Visible=visible.menu,visible.menu,visible.menu,visible.primary
  if not visible.menu then state.expanded=false end
  table.sort(state.buttons,function(a,b)if a.order~=b.order then return a.order<b.order end;return a.button.Name<b.button.Name end)
  local y=6
  for _,entry in ipairs(state.buttons)do
   local b=entry.button
   if entry.contextual then
    b.Parent=active.ready and visible.primary and list or primary
    b.BackgroundTransparency=b.Parent==primary and .14 or 1
    b.TextColor3=WHITE
    b.TextXAlignment=b.Parent==primary and Enum.TextXAlignment.Left or Enum.TextXAlignment.Left
    b.Font=b.Parent==primary and Enum.Font.Garamond or Enum.Font.BuilderSansMedium
    b.TextSize=b.Parent==primary and(m.compact and 18 or 24)or 14
   end
   if b.Parent==primary then
    local r=m[entry.slot];b.Position=UDim2.fromOffset(r.x,r.y);b.Size=UDim2.fromOffset(r.w,r.h)
   elseif b.Parent==list and b.Visible then b.Position=UDim2.fromOffset(8,y);b.Size=UDim2.new(1,-16,0,44);y+=44 end
   local keycap=b:FindFirstChild('ActionKey');if keycap then keycap.Visible=not m.compact end
   local rule=b:FindFirstChild('PrimaryRule');if rule then rule.Visible=b.Parent==primary end
  end
  for _,entry in ipairs(state.surfaces)do
   local r=m[entry.slot];entry.object.Position=UDim2.fromOffset(r.x,r.y);entry.object.Size=UDim2.fromOffset(r.w,r.h)
   if entry.object.BackgroundColor3~=INK then entry.object.BackgroundColor3=INK end
   local key=entry.object:FindFirstChild('ReadyKeycap')
   local keyVisible=not m.compact and r.w>=156
   if key then key.Visible=keyVisible end
   local left=key and keyVisible and 48 or 8
   for _,caption in ipairs(entry.object:GetChildren())do
    if caption:IsA('TextLabel')and caption.Visible then
     if caption.Position.X.Offset~=left or caption.Position.Y.Offset~=0 then caption.Position=UDim2.fromOffset(left,0)end
     if caption.Size.X.Scale~=1 or caption.Size.X.Offset~=-left-8 or caption.Size.Y.Scale~=1 then caption.Size=UDim2.new(1,-left-8,1,0)end
     caption.Font=Enum.Font.Garamond;caption.TextSize=m.compact and 18 or 24;caption.TextXAlignment=keyVisible and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
    end
   end
  end
  for _,entry in ipairs(state.utilitySurfaces)do
   entry.object.Position=UDim2.fromOffset(m.controls.x,m.controls.y);entry.object.Size=UDim2.fromOffset(m.controls.w,m.controls.h)
   for _,button in ipairs(entry.object:GetChildren())do
    if button:IsA('TextButton')then button.TextSize=m.compact and(m.controls.w<112 and 14 or 17)or 22 end
   end
  end
  local body=state.expanded and math.min(y,m.dock.body)or 0
  local dockWidth=state.expanded and math.min(240,v.X-24)or m.dock.w
  root.Position=UDim2.fromOffset(m.dock.x+m.dock.w-dockWidth,m.dock.y-body- (state.expanded and 8 or 0))
  root.Size=UDim2.fromOffset(dockWidth,m.dock.h+body+(state.expanded and 8 or 0))
  toggle.Position=UDim2.fromOffset(dockWidth-m.dock.w,body+(state.expanded and 8 or 0))
  toggle.Size=UDim2.fromOffset(m.dock.w,m.dock.h)
  list.Visible=state.expanded;list.Size=UDim2.new(1,0,0,body);list.CanvasSize=UDim2.fromOffset(0,y)
  local lang=player:GetAttribute('SpyLanguage')
  toggle.Text=state.expanded and'×'or(lang=='en'and(m.compact and'Menu'or'Menu  +')or lang=='zh'and'菜单'or(m.compact and'Меню'or'Меню  +'))
  toggle:SetAttribute('SpyUserText',true)
  toggle.TextSize=state.expanded and 25 or m.compact and 11 or 14
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
 for _,key in ipairs({'SpyLanguage','SpyMatchIntroActive','SpyCaseCinematicActive','SpyPhoneActive','SpyMatchChatOpen','SpyCharacterMenuOpen','SpyReturningToLobby'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(state.fit)end
 connections[#connections+1]=UIS:GetPropertyChangedSignal('TouchEnabled'):Connect(state.fit)
 if workspace.CurrentCamera then connections[#connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(state.fit)end
 gui.Destroying:Connect(function()
  for _,c in ipairs(connections)do c:Disconnect()end;if sessionConnection then sessionConnection:Disconnect()end
  for _,entry in ipairs(state.buttons)do for _,c in ipairs(entry.connections)do c:Disconnect()end end;docks[pg]=nil
  for _,entry in ipairs(state.surfaces)do for _,c in ipairs(entry.connections)do c:Disconnect()end end
  for _,entry in ipairs(state.utilitySurfaces)do for _,c in ipairs(entry.connections)do c:Disconnect()end end
 end)
 docks[pg]=state;state.fit();return state
end

function HUD.register(pg,button,order,key)
 local state=docks[pg]or create(pg)
 for _,entry in ipairs(state.buttons)do if entry.button==button then return state end end
 local contextual=button.Name=='SpyGuessButton'
 button.Parent=contextual and state.primary or state.list;button.AnchorPoint=Vector2.new();button.ZIndex=2
 button.BorderSizePixel=0;button.BackgroundColor3=contextual and INK or PANEL;button.BackgroundTransparency=contextual and .14 or 1
 button.Font=contextual and Enum.Font.Garamond or Enum.Font.BuilderSansMedium;button.TextSize=contextual and 24 or 14;button.TextColor3=WHITE
 button.TextXAlignment=contextual and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left;button.TextWrapped=contextual;button.TextTruncate=contextual and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
 local corner=button:FindFirstChildOfClass('UICorner');if corner then corner.CornerRadius=UDim.new(0,3)else corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,3);corner.Parent=button end
 local padding=Instance.new('UIPadding');padding.Name='ActionPadding';padding.PaddingLeft=UDim.new(0,contextual and 8 or 12);padding.PaddingRight=UDim.new(0,10);padding.Parent=button
 if contextual then
  local rule=Instance.new('Frame');rule.Name='PrimaryRule';rule.Position=UDim2.new(0,12,1,-1);rule.Size=UDim2.new(1,-24,0,1)
  rule.BackgroundColor3=WHITE;rule.BackgroundTransparency=.18;rule.BorderSizePixel=0;rule.ZIndex=3;rule.Parent=button
 end
 if key then
  local cap=Instance.new('TextLabel');cap.Name='ActionKey';cap.Text=key;cap.AnchorPoint=Vector2.new(1,.5);cap.Position=UDim2.new(1,-8,.5,0);cap.Size=UDim2.fromOffset(30,26)
  cap.BackgroundColor3=INK;cap.TextColor3=MUTED;cap.Font=Enum.Font.BuilderSansBold;cap.TextSize=13;cap.BorderSizePixel=0;cap.ZIndex=3;cap.Parent=button
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,3);c.Parent=cap
 end
 local entry={button=button,order=order,slot=button.Name=='SpyGuessButton'and'guess'or'ready',contextual=contextual,connections={}};table.insert(state.buttons,entry)
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
 object.BackgroundColor3=INK;object.BackgroundTransparency=.14
 for _,node in ipairs(object:GetDescendants())do
  if node:IsA('UIStroke')then node.Enabled=false
  elseif node:IsA('UICorner')then node.CornerRadius=UDim.new(0,3)
  elseif node:IsA('TextLabel')then node.TextColor3=WHITE;node.TextSize=14 end
 end
 local key=object:FindFirstChild('ReadyKeycap');if key then key.BackgroundTransparency=1 end
 local rule=Instance.new('Frame');rule.Name='PrimaryRule';rule.Position=UDim2.new(0,12,1,-1);rule.Size=UDim2.new(1,-24,0,1)
 rule.BackgroundColor3=WHITE;rule.BackgroundTransparency=.18;rule.BorderSizePixel=0;rule.ZIndex=4;rule.Parent=object
 local entry={object=object,slot=slot or'ready',connections={}}
 table.insert(state.surfaces,entry)
 entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal('Visible'):Connect(state.fit)
 entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal('BackgroundColor3'):Connect(state.fit)
 for _,node in ipairs(object:GetChildren())do
  if node:IsA('TextLabel')then
   entry.connections[#entry.connections+1]=node:GetPropertyChangedSignal('Size'):Connect(state.fit)
   entry.connections[#entry.connections+1]=node:GetPropertyChangedSignal('Position'):Connect(state.fit)
  end
 end
 entry.connections[#entry.connections+1]=object.Destroying:Connect(function()
  for _,c in ipairs(entry.connections)do c:Disconnect()end
  for i,value in ipairs(state.surfaces)do if value==entry then table.remove(state.surfaces,i);break end end
  state.fit()
 end)
 state.fit();return state
end

-- Card and Chat share the same baseline and visibility owner as the turn actions.
function HUD.registerUtilities(pg,object)
 local state=docks[pg]or create(pg)
 for _,entry in ipairs(state.utilitySurfaces)do if entry.object==object then return state end end
 object.Parent=state.utilities;object.AnchorPoint=Vector2.new();object.BackgroundColor3=INK;object.BackgroundTransparency=.14;object.ZIndex=2
 local shape=object:FindFirstChildOfClass('UICorner')or Instance.new('UICorner');shape.CornerRadius=UDim.new(0,3);shape.Parent=object
 local divider=Instance.new('Frame');divider.Name='UtilityDivider';divider.Position=UDim2.new(.5,0,0,12);divider.Size=UDim2.new(0,1,1,-24)
 divider.BackgroundColor3=Color3.fromRGB(86,90,97);divider.BackgroundTransparency=.58;divider.BorderSizePixel=0;divider.Parent=object;divider.ZIndex=3
 for _,button in ipairs(object:GetChildren())do
  if button:IsA('TextButton')then
   button.BackgroundTransparency=1;button.Font=Enum.Font.Garamond;button.TextSize=20;button.TextColor3=WHITE
   local corner=button:FindFirstChildOfClass('UICorner');if corner then corner.CornerRadius=UDim.new(0,3)end
  end
 end
 local entry={object=object,connections={}};table.insert(state.utilitySurfaces,entry)
 entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal('Visible'):Connect(state.fit)
 entry.connections[#entry.connections+1]=object.Destroying:Connect(function()
  for _,c in ipairs(entry.connections)do c:Disconnect()end
  for i,value in ipairs(state.utilitySurfaces)do if value==entry then table.remove(state.utilitySurfaces,i);break end end
  state.fit()
 end)
 state.fit();return state
end
function HUD.currentMetrics(pg,v,touch)
 local state=docks[pg]
 if state then return state.metrics(v,touch)end
 return HUD.metrics(v,touch,{ready=false,guess=false,utilities=false})
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
