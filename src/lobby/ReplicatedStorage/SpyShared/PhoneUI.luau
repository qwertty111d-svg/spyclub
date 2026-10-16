-- Editorial club device. Scrolling content and phone ownership remain separate.
local UI={};UI.__index=UI
local words={
 phone={'Телефон','Phone','手机'},home={'Клуб','Club','俱乐部'},cases={'Дела','Cases','案件'},tables={'Столы','Tables','牌桌'},inventory={'Инвентарь','Inventory','物品'},trade={'Обмен','Trade','交易'},shop={'Магазин','Shop','商店'},daily={'Награда','Reward','奖励'},profile={'Профиль','Profile','个人资料'},journal={'Журнал','Journal','日志'},settings={'Настройки','Settings','设置'},meeting={'Личные улики','Private clues','个人线索'},
 close={'Убрать','Put away','收起'},back={'Назад','Back','返回'},contacts={'Игроки в клубе','Club members','俱乐部成员'},offer={'Предложить обмен','Offer a trade','发起交易'},empty={'Ты пока один в клубе. Найди компанию через «Столы».','You are alone for now. Find players in Tables.','你暂时独自一人，可在牌桌中寻找玩家。'},
 start={'Начать расследование','Start investigation','开始调查'},replay={'Посмотреть сцену','Replay scene','重看场景'},inspect={'Изучить улику','Examine clue','检查线索'},testimony={'Показания','Statements','陈述'},accuse={'Назвать подозреваемого','Name a suspect','指认嫌疑人'},confirm={'Подтвердить обвинение','Confirm accusation','确认指控'},cancel={'Отмена','Cancel','取消'},
 mission={'Проверь три улики, сравни показания и найди противоречие.','Examine three clues, compare statements and find the contradiction.','检查三条线索，比较陈述并找出矛盾。'},loading={'Подключение…','Connecting…','正在连接…'},unavailable={'Пока недоступно. Попробуй ещё раз.','Unavailable for now. Try again.','暂不可用，请重试。'},timeout={'Нет ответа. Можно повторить.','No response. You can retry.','未收到回应，可以重试。'},busy={'Подожди завершения действия.','Wait for the current action.','请等待当前操作完成。'},blocked={'Сейчас телефон недоступен.','The phone is unavailable right now.','当前无法使用手机。'},
 level={'Уровень','Level','等级'},xp={'XP','XP','经验'},wins={'Победы','Wins','胜场'},rounds={'Матчи','Matches','对局'},coins={'Монеты','Coins','金币'},full_profile={'Полный профиль','Full profile','完整资料'},solved={'Дело раскрыто','Case solved','案件已破'},not_ready={'Профиль загружается. Повтори через несколько секунд.','Profile is loading. Try again in a moment.','资料加载中，请稍后重试。'},skip={'Пропустить','Skip','跳过'},scene={'Восстановление событий','Reconstruction','事件重现'},
}
local C={bg=Color3.fromRGB(22,23,27),panel=Color3.fromRGB(35,36,41),ink=Color3.fromRGB(243,243,246),muted=Color3.fromRGB(162,164,173),accent=Color3.fromRGB(225,226,233),line=Color3.fromRGB(89,91,101),action=Color3.fromRGB(235,235,241),actionInk=Color3.fromRGB(24,25,30)}
local function make(cl,root,p)local n=Instance.new(cl);for k,v in pairs(p)do n[k]=v end;n.Parent=root;return n end
local function round(n,r)make('UICorner',n,{CornerRadius=UDim.new(0,r)})end
function UI.text(lang,key)local a=words[key];return a and a[lang=='en'and 2 or lang=='zh'and 3 or 1]or key end
function UI.new(parent,State,Files,options)
 local self=setmetatable({options=options,State=State,Files=Files,app='home',visible=false,pending=false},UI)
 self.palette=C
 self.gui=make('ScreenGui',parent,{Name='SpyPhoneUI',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=410,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 pcall(function()self.gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
 self.shell=make('Frame',self.gui,{Name='PhoneBody',AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-24,.5,0),Size=UDim2.fromOffset(356,704),BackgroundColor3=Color3.fromRGB(12,13,17),BorderSizePixel=0,Visible=false});round(self.shell,20)
 make('UIStroke',self.shell,{Color=Color3.fromRGB(145,147,157),Thickness=1,Transparency=.34})
 self.screen=make('Frame',self.shell,{Name='Screen',Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,1,-16),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true});round(self.screen,14)
 local speaker=make('Frame',self.screen,{Name='Speaker',AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,8),Size=UDim2.fromOffset(54,4),BackgroundColor3=Color3.fromRGB(4,7,7),BorderSizePixel=0});round(speaker,2)
 self.clock=self:label(self.screen,'Clock','',12);self.clock.Position=UDim2.fromOffset(18,14);self.clock.Size=UDim2.fromOffset(100,20)
 local mark=self:label(self.screen,'Signal','CLUB / LINK',10);mark.Position=UDim2.new(1,-116,0,14);mark.Size=UDim2.fromOffset(98,20);mark.TextColor3=C.muted;mark.TextXAlignment=Enum.TextXAlignment.Right
 make('Frame',self.screen,{Name='StatusRule',Position=UDim2.fromOffset(18,40),Size=UDim2.new(1,-36,0,1),BackgroundColor3=C.line,BackgroundTransparency=.6,BorderSizePixel=0})
 self.title=self:label(self.screen,'AppTitle','',29);self.title.Font=Enum.Font.Bodoni;self.title.TextTruncate=Enum.TextTruncate.AtEnd;self.title.Position=UDim2.fromOffset(64,48);self.title.Size=UDim2.new(1,-82,0,38)
 self.back=self:button(self.screen,'AppBack','‹',function()self:goBack()end);self.back.Position=UDim2.fromOffset(12,45);self.back.Size=UDim2.fromOffset(44,44);self.back.TextSize=28;self.back.BackgroundTransparency=1
 self.content=make('ScrollingFrame',self.screen,{Name='AppsContent',Position=UDim2.fromOffset(18,96),Size=UDim2.new(1,-36,1,-176),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2,ScrollBarImageColor3=C.accent,ClipsDescendants=true})
 self.status=self:label(self.screen,'PhoneStatus','',13);self.status.TextColor3=C.accent;self.status.TextWrapped=true;self.status.Position=UDim2.new(0,18,1,-78);self.status.Size=UDim2.new(1,-36,0,30)
 self.close=self:button(self.screen,'PhoneClose','',function()options.close()end,true);self.close.Position=UDim2.new(0,18,1,-48);self.close.Size=UDim2.new(1,-36,0,44);self.close.BackgroundTransparency=1
 self.dock=self:button(self.gui,'PhoneShortcut','ALT',function()options.toggle()end);self.dock.AnchorPoint=Vector2.new(1,.5);self.dock.Position=UDim2.new(1,-16,.5,52);self.dock.Size=UDim2.fromOffset(52,52);round(self.dock,5);make('UIStroke',self.dock,{Color=C.line,Thickness=1,Transparency=.45})
 self.connection=self.gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:resize()end)
 self.keyboardConnections={}
 local input=game:GetService('UserInputService')
 for _,property in ipairs({'OnScreenKeyboardVisible','OnScreenKeyboardPosition','OnScreenKeyboardSize'})do self.keyboardConnections[#self.keyboardConnections+1]=input:GetPropertyChangedSignal(property):Connect(function()self:resize()end)end
 self:resize();self:render();return self
end
function UI:goBack()
 if self.app=='messages'and self.peer then self.app='contacts'
 elseif self.app=='contacts'and self.peer then self.peer=nil
 elseif self.app=='dialpad'or self.app=='recents'then self.app='calls';self.peer=nil
 else self.app='home';self.peer=nil end
 self.selected=nil;self:render()
end
function UI:tr(k)return UI.text(self.options.language(),k)end
function UI:label(root,name,value,size)
 local n=make('TextLabel',root,{Name=name,Text=value,Font=Enum.Font.BuilderSansMedium,TextSize=size or 16,TextColor3=C.ink,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,24)});n:SetAttribute('SpyUserText',true);return n
end
function UI:button(root,name,value,fn,allowBusy)
 local n=make('TextButton',root,{Name=name,Text=value,Font=Enum.Font.BuilderSansMedium,TextSize=16,TextColor3=C.ink,TextWrapped=true,BackgroundColor3=C.panel,BorderSizePixel=0,Size=UDim2.new(1,0,0,48),AutoButtonColor=true});round(n,5);n:SetAttribute('SpyUserText',true)
 local scale=make('UIScale',n,{Scale=1})
 local function press(v)
  local player=game:GetService('Players').LocalPlayer
  if player and player:GetAttribute('SpyReducedMotion')==true then return end
  pcall(function()game:GetService('TweenService'):Create(scale,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=v}):Play()end)
 end
 n.MouseButton1Down:Connect(function()press(.97)end);n.MouseButton1Up:Connect(function()press(1)end);n.MouseLeave:Connect(function()press(1)end)
 n.Activated:Connect(function()if allowBusy or not self.pending then if self.options.feedback then self.options.feedback('tap')end;fn()end end);return n
end
function UI:resize()
 local size=self.gui.AbsoluteSize;local input=game:GetService('UserInputService');local available=size.Y
 pcall(function()
  if input.OnScreenKeyboardVisible then
   local inset=game:GetService('GuiService'):GetGuiInset();local keyboard=input.OnScreenKeyboardPosition
   if keyboard.Y>0 then available=math.min(available,math.max(1,keyboard.Y-inset.Y-8))
   else available=math.max(1,available-input.OnScreenKeyboardSize.Y-8)end
  end
 end)
 local g=self.State.layout(size.X,available)
 self.shell.Size=UDim2.fromOffset(g.w,g.h)
 local mobile=game:GetService('UserInputService').TouchEnabled or size.X<600 or size.Y<430
 self.shell.AnchorPoint=Vector2.new(mobile and .5 or 1,.5);self.shell.Position=UDim2.new(mobile and .5 or 1,mobile and 0 or -24,0,available*.5)
 self.columns=g.w<310 and 2 or 3;self.dock.Text=mobile and '▣'or'ALT';self.dock.Visible=not self.visible and not self.options.blocked()
 if self.grid then self.grid.CellSize=UDim2.new(1/self.columns,-8,0,102)end
end
function UI:show(app)
 self.visible=true;self.shell.Visible=true;self.app=app or'home';self.status.Text='';self:resize();self:render()
 if self.options.feedback then self.options.feedback('open')end
 local scale=self.shell:FindFirstChildOfClass('UIScale')or make('UIScale',self.shell,{Scale=1})
 if game:GetService('Players').LocalPlayer:GetAttribute('SpyReducedMotion')~=true then scale.Scale=.96;pcall(function()game:GetService('TweenService'):Create(scale,TweenInfo.new(.22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1}):Play()end)else scale.Scale=1 end
end
function UI:hide()self.visible=false;self.shell.Visible=false;self.pending=false;self:resize()end
function UI:error(key)self.status.Text=self:tr(key)end
function UI:busy(v)self.pending=v;self.status.Text=v and self:tr('loading')or''end
function UI:setData(d)self.data=d;self:render()end
function UI:paragraph(text,name,size)
 local p=self:label(self.content,name or'Paragraph',text,size or 16);p.Size=UDim2.new(1,-4,0,0);p.AutomaticSize=Enum.AutomaticSize.Y;p.TextWrapped=true;return p
end
function UI:icon(root,key,color)
 local p=make('Frame',root,{Name='Icon_'..key,Size=UDim2.fromOffset(48,48),Position=UDim2.new(.5,-24,0,6),BackgroundTransparency=1})
 local function line(x,y,w,h)make('Frame',p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color,BorderSizePixel=0})end
 local function box(x,y,w,h)local f=make('Frame',p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0});make('UIStroke',f,{Color=color,Thickness=2});return f end
 if key=='cases'or key=='journal'then box(10,10,28,29);line(12,6,12,4);line(15,18,18,2);line(15,24,14,2);line(15,30,10,2)
 elseif key=='inventory'then box(9,16,30,24);line(17,9,14,2);line(17,9,2,7);line(29,9,2,7);line(9,24,30,2)
 elseif key=='tables'then box(8,15,32,18);line(13,35,2,6);line(33,35,2,6);line(21,20,6,6)
 elseif key=='trade'then line(8,17,30,2);line(31,12,2,7);line(8,30,30,2);line(13,30,2,7)
 elseif key=='profile'then local a=box(18,6,12,13);round(a,6);local b=box(10,25,28,15);round(b,6)
 elseif key=='settings'then for i=0,2 do line(9,12+i*10,30,2);box(i%2==0 and 18 or 29,9+i*10,5,8)end
 else box(12,9,24,30);line(18,16,12,2);line(18,23,12,2)end
end
function UI:launch(key,arg)
 self.options.launch(key,arg)
end
function UI:render()
 self.content:ClearAllChildren();self.grid=nil;self.content.CanvasPosition=Vector2.zero
 self.close.Text=self:tr('close');self.back.Visible=self.app~='home';self.title.Text=self:tr(self.app=='home'and'home'or self.app)
 self.clock.Text=os.date('%H:%M');self.status.Text=self.pending and self:tr('loading')or''
 local layout=make('UIListLayout',self.content,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
 if self.app=='home'then
  layout:Destroy();self.grid=make('UIGridLayout',self.content,{CellSize=UDim2.new(1/self.columns,-8,0,102),CellPadding=UDim2.fromOffset(8,12),SortOrder=Enum.SortOrder.LayoutOrder})
  local apps=self.options.inMatch and{'meeting','settings'}or{'cases','tables','inventory','trade','profile','shop','journal','daily','settings'}
  for i,key in ipairs(apps)do
   local b=self:button(self.content,'App_'..key,'',function()
    if key=='cases'then self.app='cases';self:render();self.options.caseRequest({action='progress'})
    elseif key=='profile'or key=='trade'then self.app=key;self:render()
    else self:launch(key)end
   end);b.LayoutOrder=i;self:icon(b,key,i==1 and C.accent or C.ink)
   local t=self:label(b,'AppCaption',self:tr(key),14);t.TextXAlignment=Enum.TextXAlignment.Center;t.TextWrapped=true;t.Position=UDim2.new(0,2,0,61);t.Size=UDim2.new(1,-4,0,35)
  end
 elseif self.app=='trade'then
  self:paragraph(self:tr('contacts'),'ContactHeading',16)
  local count=0
  for _,p in ipairs(game:GetService('Players'):GetPlayers())do if p~=game:GetService('Players').LocalPlayer then
   count+=1;local b=self:button(self.content,'Contact_'..p.UserId,p.DisplayName..'\n@'..p.Name,function()self:launch('trade',p.UserId)end);b.Size=UDim2.new(1,-4,0,64)
  end end
  if count==0 then self:paragraph(self:tr('empty'))end
 elseif self.app=='profile'then
  local p=self.options.profile()
  if not p or not p.ready then self:paragraph(self:tr('not_ready'))else
   for _,row in ipairs({{'level',p.level or 1},{'xp',p.xp or 0},{'wins',p.wins or 0},{'rounds',p.rounds or 0},{'coins',p.coins or 0}})do self:paragraph(self:tr(row[1])..'    '..row[2],'Stat_'..row[1],18)end
  end
  self:button(self.content,'FullProfile',self:tr('full_profile'),function()self:launch('profile')end)
 elseif self.app=='cases'then self:cases()end
end
function UI:cases()
 local data=self.data
 if not data or data.kind=='archive'then
  for i,id in ipairs(self.Files.Ids)do
   local file=self.Files.public(id,self.options.language());local b=self:button(self.content,'Case_'..id,file.title,function()self.options.caseRequest({action='start',id=id},id)end)
   b.LayoutOrder=i*2;b.Size=UDim2.new(1,-4,0,64)
   local p=self:paragraph(file.brief,'Brief_'..id,14);p.LayoutOrder=i*2+1;p.TextColor3=C.muted
  end
  return
 end
 if data.kind~='case'or not data.file then return end
 local file=data.file;self.title.Text=file.title
 self:paragraph(data.finished and self:tr('solved')or self:tr('mission'),'CaseObjective',16)
 self:button(self.content,'ReplayScene',self:tr('replay'),function()self.options.film(file.id)end)
 self:paragraph(file.brief,'CaseBrief',15)
 local found=0;for _,source in ipairs(file.sources or{})do if(data.evidence or{})[source.id]then found+=1 end end
 self:paragraph(found..' / 3','ClueCount',15)
 for _,source in ipairs(file.sources or{})do
  local evidence=(data.evidence or{})[source.id]
  self:button(self.content,'Inspect_'..source.id,(evidence and '✓  'or'')..source.label,function()self.options.caseRequest({action='inspect',token=data.token,source=source.id})end)
  if evidence then local p=self:paragraph(evidence,'Evidence_'..source.id,15);p.TextColor3=C.muted end
 end
 self:paragraph(self:tr('testimony'),'Witnesses',18)
 for _,suspect in ipairs(file.suspects or{})do
  self:paragraph(suspect.name..'\n'..suspect.statement,'Witness_'..suspect.id,15)
  if not data.finished then
   self:button(self.content,'Accuse_'..suspect.id,self:tr('accuse')..': '..suspect.name,function()self.selected=suspect;self:render()end)
  end
 end
 if self.selected and not data.finished then
  self:paragraph(self.selected.name..'?', 'ConfirmName',20)
  local b=self:button(self.content,'ConfirmAccusation',self:tr('confirm'),function()self.options.caseRequest({action='solve',token=data.token,suspect=self.selected.id})end);b.BackgroundColor3=C.accent;b.TextColor3=C.bg
  self:button(self.content,'CancelAccusation',self:tr('cancel'),function()self.selected=nil;self:render()end)
 end
 if data.finished and data.explanation then self:paragraph(data.explanation,'CaseReview',16);self:button(self.content,'OtherCases',self:tr('back'),function()self.selected=nil;self.data={kind='archive'};self:render();self.options.caseRequest({action='progress'})end)end
end
function UI:destroy()self.connection:Disconnect();for _,c in ipairs(self.keyboardConnections)do c:Disconnect()end;self.gui:Destroy()end
return UI
