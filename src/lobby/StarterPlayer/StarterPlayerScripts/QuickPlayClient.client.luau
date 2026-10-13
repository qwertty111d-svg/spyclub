-- Play menu: find a group or choose a table.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local player=Players.LocalPlayer
local parent=player:WaitForChild('PlayerGui',8);local shared=RS:WaitForChild('SpyShared',8);local fm=shared and shared:WaitForChild('CaseFiles',8)
if not parent or not fm then return end
local ok,Files=pcall(require,fm);if not ok then return end
local themeNode=shared:FindFirstChild("UITheme");local Theme=themeNode and require(themeNode)
local C={bg=Color3.fromRGB(25,27,31),raised=Color3.fromRGB(46,48,52),selected=Color3.fromRGB(66,59,49),ink=Color3.fromRGB(244,240,231),muted=Color3.fromRGB(188,187,181),accent=Color3.fromRGB(221,193,151),line=Color3.fromRGB(87,89,93)}
local function make(class,root,props)local n=Instance.new(class);for k,v in pairs(props)do n[k]=v end;n.Parent=root;return n end
local function round(n,r)make('UICorner',n,{CornerRadius=UDim.new(0,r)})end
local gui=make('ScreenGui',parent,{Name='SpyQuickPlay',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=81,ZIndexBehavior=Enum.ZIndexBehavior.Sibling});pcall(function()gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
local window=make('Frame',gui,{Name='SearchWindow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(520,620),BackgroundColor3=C.bg,BackgroundTransparency=.16,BorderSizePixel=0,Visible=false})
round(window,20);make('UIStroke',window,{Color=C.line,Thickness=1,Transparency=.68})
local function label(root,name,value,size)
 local n=make('TextLabel',root,{Name=name,Text=value,Font=Enum.Font.BuilderSansMedium,TextSize=size or 16,TextColor3=C.ink,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y});n:SetAttribute('SpyUserText',true);return n
end
local title=label(window,'QuickTitle','',32);title.Font=Enum.Font.BuilderSansBold;title.AutomaticSize=Enum.AutomaticSize.None
local subtitle=label(window,'QuickSubtitle','',16);subtitle.TextColor3=C.muted;subtitle.AutomaticSize=Enum.AutomaticSize.None
local function button(root,name,value)
 local n=make('TextButton',root,{Name=name,Text=value,TextSize=17,Font=Enum.Font.BuilderSansBold,TextColor3=C.ink,BackgroundColor3=C.raised,BorderSizePixel=0,Size=UDim2.new(1,0,0,50),TextWrapped=true,AutoButtonColor=true,Selectable=true});n:SetAttribute('SpyUserText',true);round(n,14);if Theme and Theme.button and not name:match('^Mode_')then Theme.button(n,name=='JoinSearch',{arrow=name=='JoinSearch'})end;return n
end
local close=button(window,'QuickClose','×');close.TextSize=28;close.Size=UDim2.fromOffset(44,44)
local scroll=make('ScrollingFrame',window,{Name='QuickChoices',BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=3,ScrollBarImageColor3=C.accent,ClipsDescendants=true})
make('UIListLayout',scroll,{Padding=UDim.new(0,16),SortOrder=Enum.SortOrder.LayoutOrder});make('UIPadding',scroll,{PaddingBottom=UDim.new(0,8),PaddingRight=UDim.new(0,6)})
local modes=make('Frame',scroll,{Name='ModeChoices',BackgroundTransparency=1,Size=UDim2.new(1,0,0,228),LayoutOrder=1})
local function choice(name)
 local b=button(modes,name,'');round(b,16)
 local outline=make('UIStroke',b,{Color=C.line,Thickness=1,Transparency=.65,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local heading=label(b,'ModeTitle','',20);heading.Font=Enum.Font.BuilderSansBold;heading.AutomaticSize=Enum.AutomaticSize.None
 local description=label(b,'ModeDescription','',15);description.TextColor3=C.muted;description.AutomaticSize=Enum.AutomaticSize.None
 local mark=make('Frame',b,{Name='SelectionMark',Size=UDim2.fromOffset(16,16),BackgroundColor3=C.accent,BorderSizePixel=0});round(mark,8)
 return{button=b,title=heading,description=description,outline=outline,mark=mark}
end
local classicCard=choice('Mode_classic');local meetingCard=choice('Mode_case')
local classic=classicCard.button;local meeting=meetingCard.button
local status=label(scroll,'QuickState','',16);status.TextColor3=C.muted;status.LayoutOrder=2
local footer=make('Frame',window,{Name='QuickActions',BackgroundTransparency=1})
local join=button(footer,'JoinSearch','');join.BackgroundColor3=C.accent;join.TextColor3=C.bg
local cancel=button(footer,'CancelSearch','');cancel.Visible=false
local manual=button(footer,'QuickManual','');manual.BackgroundTransparency=.1
local mode='classic';local data={state='idle'};local serial=0;local pending=false;local queuedAt;local connections={};local hooked=setmetatable({},{__mode='k'})
local function lang()return player:GetAttribute('SpyLanguage')or'ru'end
local function tr(key)return Files.text(lang(),key)end
local emptyHints={ru='Можно найти компанию или выбрать стол в клубе.',en='Find a group or choose a table in the club.',zh='寻找伙伴，或在俱乐部选择一张桌子。'}
local function select(card,chosen)
 card.button.BackgroundColor3=chosen and C.selected or C.raised
 card.button.BackgroundTransparency=chosen and .02 or .08
 card.outline.Color=chosen and C.accent or C.line;card.outline.Transparency=chosen and .25 or .68
 card.mark.Visible=chosen
end
local function refresh()
 title.Text=tr('quick');subtitle.Text=tr('quick_caption')
 classicCard.title.Text=tr('classic');meetingCard.title.Text=tr('meeting')
 classicCard.description.Text=tr('classic_brief');meetingCard.description.Text=tr('meeting_brief_short')
 select(classicCard,mode=='classic');select(meetingCard,mode=='case')
 join.Text=tr('join');cancel.Text=tr('cancel');manual.Text=tr('manual')
 local active=data.state~='idle';join.Visible=not active;cancel.Visible=active;cancel.Active=data.canCancel~=false and not pending
 modes.Visible=not active;join.Active=not pending;classic.Active=not pending;meeting.Active=not pending
 join.TextTransparency=pending and .35 or 0;cancel.TextTransparency=cancel.Active and 0 or .35
 if data.code then status.Text=tr(data.code)
 elseif active then status.Text=tr(data.state)..(data.count and('\n'..tr('players')..': '..data.count..' / 4')or'')
 else status.Text=emptyHints[lang()]or emptyHints.ru end
 status.TextColor3=data.code and C.accent or C.muted
end
local function resize()
 local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600);local t,b=Vector2.zero,Vector2.zero
 pcall(function()t,b=game:GetService('GuiService'):GetGuiInset()end)
 local width=math.max(1,math.min(520,v.X-t.X-b.X-24));local height=math.max(1,math.min(620,v.Y-t.Y-b.Y-24));local compact=height<480
 window.Size=UDim2.fromOffset(width,height)
 title.Position=UDim2.fromOffset(20,compact and 14 or 20);title.Size=UDim2.new(1,-84,0,40);title.TextSize=compact and 26 or 32
 subtitle.Position=UDim2.fromOffset(20,compact and 54 or 68);subtitle.Size=UDim2.new(1,-40,0,24);subtitle.TextSize=compact and 14 or 16
 close.Position=UDim2.new(1,-64,0,compact and 12 or 20)
 local top=compact and 92 or 108;local bottom=compact and 124 or 144
 scroll.Position=UDim2.fromOffset(20,top);scroll.Size=UDim2.new(1,-40,1,-top-bottom)
 footer.Position=UDim2.new(0,20,1,-bottom+6);footer.Size=UDim2.new(1,-40,0,bottom-18)
 join.Position=UDim2.new();cancel.Position=UDim2.new();manual.Position=UDim2.fromOffset(0,compact and 58 or 66)
 join.Size=UDim2.new(1,0,0,compact and 46 or 52);cancel.Size=join.Size;manual.Size=join.Size
 -- Only wide, short screens use side-by-side choices. Portrait choices never shrink.
 local sideBySide=compact and width>=460
 modes.Size=UDim2.new(1,0,0,sideBySide and 128 or 228)
 for i,card in ipairs({classicCard,meetingCard})do
  card.button.Position=sideBySide and UDim2.new((i-1)*.5,(i-1)*6,0,0)or UDim2.fromOffset(0,(i-1)*120)
  card.button.Size=sideBySide and UDim2.new(.5,-6,0,128)or UDim2.new(1,0,0,108)
  card.title.Position=UDim2.fromOffset(16,14);card.title.Size=UDim2.new(1,-58,0,sideBySide and 44 or 28);card.title.TextSize=sideBySide and 18 or 20
  card.description.Position=UDim2.fromOffset(16,sideBySide and 62 or 48);card.description.Size=UDim2.new(1,-32,0,sideBySide and 54 or 52);card.description.TextSize=sideBySide and 14 or 15
  card.mark.Position=UDim2.new(1,-30,0,18)
 end
end
local function invoke(payload,done)
 if pending then return end
 local folder=RS:FindFirstChild('SpyQuickPlayRemotes');local remote=folder and folder:FindFirstChild('Request')
 if not remote then data={state='idle',code='unavailable'};refresh();if done then done(false)end;return end
 serial+=1;local id=serial;pending=true;refresh()
 task.delay(8,function()if serial==id and pending then
  serial+=1;pending=false;data.code='timeout';data.canCancel=true;refresh();if done then done(false)end
 end end)
 task.spawn(function()
  local success,result=pcall(function()return remote:InvokeServer(payload)end)
  if serial~=id then return end
  pending=false
  if success and type(result)=='table'then data=result;if result.mode then mode=result.mode end
  else data.code='unavailable' end
  refresh();if done then done(success and type(result)=='table'and result.state=='idle')end
 end)
end
classic.Activated:Connect(function()if data.state~='idle'or pending then return end;mode='classic';refresh()end)
meeting.Activated:Connect(function()if data.state~='idle'or pending then return end;mode='case';refresh()end)
join.Activated:Connect(function()if data.state~='idle'then return end;queuedAt=os.clock();invoke({action='join',mode=mode})end)
cancel.Activated:Connect(function()invoke({action='cancel'})end)
manual.Activated:Connect(function()
 local function open(free)
  if not free then data.code='manual_busy';refresh();return end
  local event=parent:FindFirstChild('SpyOpenManualTable');if event then window.Visible=false;event:Fire()else data.code='unavailable';refresh()end
 end
 if data.state~='idle'or player:GetAttribute('SpyQuickQueueActive')then invoke({action='cancel'},open)else open(true)end
end)
close.Activated:Connect(function()window.Visible=false end)
local open=parent:FindFirstChild('SpyOpenQuickPlay')or Instance.new('BindableEvent');open.Name='SpyOpenQuickPlay';open.Parent=parent
connections[#connections+1]=open.Event:Connect(function()window.Visible=not window.Visible;refresh();resize();if window.Visible then invoke({action='status'})end end)
local function listen(n)
 if n.Name~='State'or not n:IsA('RemoteEvent')or not n.Parent or n.Parent.Name~='SpyQuickPlayRemotes'or hooked[n]then return end
 hooked[n]=true;connections[#connections+1]=n.OnClientEvent:Connect(function(value)
  if type(value)~='table'then return end;data=value;if value.mode then mode=value.mode end;refresh()
  if value.state=='matched'then window.Visible=false end
 end)
end
for _,n in ipairs(RS:GetDescendants())do listen(n)end
connections[#connections+1]=RS.DescendantAdded:Connect(listen)
connections[#connections+1]=player:GetAttributeChangedSignal('SpyLanguage'):Connect(refresh)
connections[#connections+1]=player:GetAttributeChangedSignal('SpyQuickQueueActive'):Connect(function()
 if not player:GetAttribute('SpyQuickQueueActive')and data.state~='idle'then data={state='idle'};refresh()end
end)
if workspace.CurrentCamera then connections[#connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(resize)end
script.Destroying:Connect(function()serial+=1;for _,c in ipairs(connections)do c:Disconnect()end;gui:Destroy();open:Destroy()end)
refresh();resize()
