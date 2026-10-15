-- Play menu: find a group or choose a table.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local player=Players.LocalPlayer
local parent=player:WaitForChild('PlayerGui',8);local shared=RS:WaitForChild('SpyShared',8);local fm=shared and shared:WaitForChild('CaseFiles',8)
if not parent or not fm then return end
local ok,Files=pcall(require,fm);if not ok then return end
-- QUICK_PLAY_CANVAS_BEGIN
local C={bg=Color3.fromRGB(27,29,33),raised=Color3.fromRGB(36,39,44),ink=Color3.fromRGB(238,236,230),muted=Color3.fromRGB(167,169,173),accent=Color3.fromRGB(238,236,230),line=Color3.fromRGB(86,90,97),dark=Color3.fromRGB(30,32,36)}
local function make(class,root,props)local n=Instance.new(class);for k,v in pairs(props)do n[k]=v end;n.Parent=root;return n end
local function round(n,r)make('UICorner',n,{CornerRadius=UDim.new(0,r)})end
local gui=make('ScreenGui',parent,{Name='SpyQuickPlay',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=81,ZIndexBehavior=Enum.ZIndexBehavior.Sibling});pcall(function()gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
local window=make('Frame',gui,{Name='SearchWindow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(568,604),BackgroundColor3=C.bg,BackgroundTransparency=0,BorderSizePixel=0,Visible=false})
round(window,8);make('UIStroke',window,{Color=C.line,Thickness=1,Transparency=.35,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
local function label(root,name,value,size)
 local n=make('TextLabel',root,{Name=name,Text=value,Font=Enum.Font.BuilderSansMedium,TextSize=size or 16,TextColor3=C.ink,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y});n:SetAttribute('SpyUserText',true);return n
end
local header=make('Frame',window,{Name='QuickInvitation',BackgroundColor3=C.ink,BorderSizePixel=0})
round(header,8)
local headerFoot=make('Frame',header,{Name='SquareFoot',AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,8),BackgroundColor3=C.ink,BorderSizePixel=0})
local edition=label(header,'QuickEdition','',10);edition.TextColor3=C.dark;edition.AutomaticSize=Enum.AutomaticSize.None
local title=label(header,'QuickTitle','',42);title.Font=Enum.Font.Garamond;title.TextColor3=C.dark;title.AutomaticSize=Enum.AutomaticSize.None
local subtitle=label(header,'QuickSubtitle','',14);subtitle.TextColor3=C.dark;subtitle.TextTransparency=.28;subtitle.AutomaticSize=Enum.AutomaticSize.None
local function button(root,name,value)
 local n=make('TextButton',root,{Name=name,Text=value,TextSize=17,Font=Enum.Font.BuilderSansMedium,TextColor3=C.ink,BackgroundColor3=C.raised,BorderSizePixel=0,Size=UDim2.new(1,0,0,50),TextWrapped=true,AutoButtonColor=false,Selectable=true});n:SetAttribute('SpyUserText',true);round(n,4);return n
end
local close=button(header,'QuickClose','×');close.TextColor3=C.dark;close.BackgroundTransparency=1;close.TextSize=26;close.Size=UDim2.fromOffset(44,44)
local scroll=make('ScrollingFrame',window,{Name='QuickChoices',BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=2,ScrollBarImageColor3=C.muted,ClipsDescendants=true})
make('UIListLayout',scroll,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder});make('UIPadding',scroll,{PaddingBottom=UDim.new(0,6),PaddingRight=UDim.new(0,5)})
local modes=make('Frame',scroll,{Name='ModeChoices',BackgroundTransparency=1,Size=UDim2.new(1,0,0,202),LayoutOrder=1})
local function choice(root,name,number)
 local b=button(root,name,'')
 local outline=make('UIStroke',b,{Color=C.line,Thickness=1,Transparency=.52,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local index=label(b,'ChoiceIndex',number,11);index.AutomaticSize=Enum.AutomaticSize.None;index.TextColor3=C.muted
 local heading=label(b,'ModeTitle','',26);heading.Font=Enum.Font.Garamond;heading.AutomaticSize=Enum.AutomaticSize.None
 local description=label(b,'ModeDescription','',13);description.TextColor3=C.muted;description.AutomaticSize=Enum.AutomaticSize.None
 local mark=label(b,'SelectionMark','↗',24);mark.AutomaticSize=Enum.AutomaticSize.None;mark.TextXAlignment=Enum.TextXAlignment.Center;mark.TextYAlignment=Enum.TextYAlignment.Center
 return{button=b,title=heading,description=description,outline=outline,mark=mark,index=index}
end
local classicCard=choice(modes,'Mode_classic','01');local meetingCard=choice(modes,'Mode_case','02')
local classic=classicCard.button;local meeting=meetingCard.button
local manualCard=choice(scroll,'QuickManual','03');manualCard.button.LayoutOrder=2
local manual=manualCard.button
local status=label(scroll,'QuickState','',13);status.TextColor3=C.muted;status.LayoutOrder=3
local footer=make('Frame',window,{Name='QuickActions',BackgroundTransparency=1})
local footerRule=make('Frame',footer,{Name='FooterRule',Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BackgroundTransparency=.5,BorderSizePixel=0})
local join=button(footer,'JoinSearch','');join.BackgroundColor3=C.ink;join.TextColor3=C.dark;join.Font=Enum.Font.Garamond;join.TextSize=23;join.TextXAlignment=Enum.TextXAlignment.Left
local joinCaption=label(join,'JoinCaption','',23);joinCaption.Font=Enum.Font.Garamond;joinCaption.Position=UDim2.fromOffset(18,0);joinCaption.Size=UDim2.new(1,-64,1,0);joinCaption.AutomaticSize=Enum.AutomaticSize.None;joinCaption.TextColor3=C.dark;joinCaption.TextWrapped=false;joinCaption.TextTruncate=Enum.TextTruncate.AtEnd;joinCaption.TextYAlignment=Enum.TextYAlignment.Center;join.TextTransparency=1
local joinArrow=label(join,'JoinArrow','→',25);joinArrow.Position=UDim2.new(1,-42,0,0);joinArrow.Size=UDim2.fromOffset(26,48);joinArrow.AutomaticSize=Enum.AutomaticSize.None;joinArrow.TextColor3=C.dark;joinArrow.TextYAlignment=Enum.TextYAlignment.Center
local cancel=button(footer,'CancelSearch','');cancel.Visible=false;cancel.BackgroundTransparency=1;make('UIStroke',cancel,{Color=C.line,Thickness=1,Transparency=.2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
local mode='classic';local data={state='idle'};local serial=0;local pending=false;local queuedAt;local connections={};local hooked=setmetatable({},{__mode='k'})
local function lang()return player:GetAttribute('SpyLanguage')or'ru'end
local function tr(key)return Files.text(lang(),key)end
local copy={
 ru={edition='ВЕЧЕР В КЛУБЕ',manual='Свой стол',manualBrief='Выбрать компанию или открыть свой стол.',empty='Выбери формат вечера. Компания найдётся сама.'},
 en={edition='AN EVENING AT THE CLUB',manual='Your own table',manualBrief='Choose a group or open a table of your own.',empty='Choose your evening. We will find the company.'},
 zh={edition='俱乐部之夜',manual='自选牌桌',manualBrief='选择伙伴，或创建自己的牌桌。',empty='选择今晚的玩法，我们会为你寻找伙伴。'},
}
local function select(card,chosen)
 card.button.BackgroundColor3=chosen and C.ink or C.raised
 card.button.BackgroundTransparency=chosen and 0 or .24
 card.outline.Color=chosen and C.ink or C.line;card.outline.Transparency=chosen and 1 or .52
 card.title.TextColor3=chosen and C.dark or C.ink
 card.description.TextColor3=chosen and C.dark or C.muted;card.description.TextTransparency=chosen and .18 or 0
 card.index.TextColor3=chosen and C.dark or C.muted
 card.mark.TextColor3=chosen and C.dark or C.muted;card.mark.Text=chosen and '•'or'↗'
end
local function refresh()
 local words=copy[lang()]or copy.ru
 edition.Text=words.edition;title.Text=tr('quick');subtitle.Text=tr('quick_caption')
 classicCard.title.Text=tr('classic');meetingCard.title.Text=tr('meeting')
 classicCard.description.Text=tr('classic_brief');meetingCard.description.Text=tr('meeting_brief_short')
 manualCard.title.Text=words.manual;manualCard.description.Text=words.manualBrief
 select(classicCard,mode=='classic');select(meetingCard,mode=='case');select(manualCard,false)
 join.Text=tr('join');joinCaption.Text=join.Text;cancel.Text=tr('cancel')
 local active=data.state~='idle';join.Visible=not active;cancel.Visible=active;cancel.Active=data.canCancel~=false and not pending
 status.LayoutOrder=active and 1 or 3;status.TextSize=active and 17 or 13
 modes.Visible=not active;join.Active=not pending;classic.Active=not pending;meeting.Active=not pending;manual.Active=not pending
 joinCaption.TextTransparency=pending and .35 or 0;joinArrow.TextTransparency=joinCaption.TextTransparency;cancel.TextTransparency=cancel.Active and 0 or .35
 if data.code then status.Text=tr(data.code)
 elseif active then status.Text=tr(data.state)..(data.count and('\n'..tr('players')..': '..data.count..' / 4')or'')
 else status.Text=words.empty end
 status.TextColor3=(data.code or active)and C.ink or C.muted
end
local function resize()
 local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600);local t,b=Vector2.zero,Vector2.zero
 pcall(function()t,b=game:GetService('GuiService'):GetGuiInset()end)
 local width=math.max(1,math.min(568,v.X-t.X-b.X-24));local height=math.max(1,math.min(604,v.Y-t.Y-b.Y-24));local compact=height<480;local minimal=height<300;local narrow=width<380
 local inset=narrow and 18 or 26;local headerHeight=minimal and 48 or compact and 94 or 126
 window.Size=UDim2.fromOffset(width,height)
 header.Position=UDim2.new();header.Size=UDim2.new(1,0,0,headerHeight)
 edition.Visible=not minimal;subtitle.Visible=not minimal
 edition.Position=UDim2.fromOffset(inset,compact and 12 or 18);edition.Size=UDim2.new(1,-inset*2-46,0,14)
 title.Position=UDim2.fromOffset(inset,minimal and 5 or compact and 24 or 38);title.Size=UDim2.new(1,-inset*2-44,0,compact and 38 or 46);title.TextSize=compact and 34 or 42
 subtitle.Position=UDim2.fromOffset(inset,compact and 68 or 94);subtitle.Size=UDim2.new(1,-inset*2,0,20);subtitle.TextSize=13
 close.Position=UDim2.new(1,-inset-34,0,minimal and 2 or compact and 10 or 18)
 local top=headerHeight+(minimal and 8 or compact and 14 or 20);local bottom=minimal and 56 or compact and 76 or 86
 scroll.Position=UDim2.fromOffset(inset,top);scroll.Size=UDim2.new(1,-inset*2,1,-top-bottom)
 footer.Position=UDim2.new(0,inset,1,-bottom);footer.Size=UDim2.new(1,-inset*2,0,bottom)
 join.Position=UDim2.fromOffset(0,minimal and 8 or 12);cancel.Position=join.Position
 join.Size=UDim2.new(1,0,0,minimal and 44 or 48);cancel.Size=join.Size
 joinCaption.TextSize=width<300 and 21 or 23
 local rowHeight=width<300 and 132 or compact and 100 or 104
 modes.Size=UDim2.new(1,0,0,rowHeight*2+10)
 for i,card in ipairs({classicCard,meetingCard,manualCard})do
  card.button.Position=UDim2.fromOffset(0,(i-1)*(rowHeight+10));card.button.Size=UDim2.new(1,0,0,rowHeight)
  card.index.Position=UDim2.fromOffset(14,15);card.index.Size=UDim2.fromOffset(22,16)
  card.title.Position=UDim2.fromOffset(46,10);card.title.Size=UDim2.new(1,-90,0,31);card.title.TextSize=narrow and 24 or 27
  card.description.Position=UDim2.fromOffset(46,46);card.description.Size=UDim2.new(1,-68,0,rowHeight-50);card.description.TextSize=13
  card.mark.Position=UDim2.new(1,-37,0,10);card.mark.Size=UDim2.fromOffset(24,30)
 end
 status.Size=UDim2.new(1,-2,0,0)
end
-- QUICK_PLAY_CANVAS_END
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
