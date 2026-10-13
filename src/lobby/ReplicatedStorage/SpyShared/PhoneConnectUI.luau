-- Social extensions live inside the phone. No inventory/profile controls here.
local Connect={}
local words={
 clublink={'ClubLink','ClubLink','ClubLink'},dialpad={'Набор номера','Dial pad','拨号'},recents={'Недавние','Recents','最近通话'},mynumber={'Мой клубный номер','My club number','我的俱乐部号码'},findnumber={'Найти номер','Find number','查找号码'},numberhint={'Клубный номер','Club number','俱乐部号码'},refresh={'Обновить','Refresh','刷新'},visibleon={'Я в сети ClubLink','Visible in ClubLink','ClubLink可见'},visibleoff={'Показать мой номер','Show my number','显示我的号码'},linkhelp={'Здесь появляются участники ClubLink. Подключись к человеку или набери его номер.','ClubLink members appear here. Connect to someone or enter their number.','ClubLink成员显示在这里。连接成员或输入号码。'},linkempty={'Пока никого. Другие участники появятся здесь, когда откроют ClubLink.','Nobody here yet. Other members appear when they open ClubLink.','暂无成员。其他玩家打开ClubLink后会显示。'},nearby={'В этом сервере','This server','当前服务器'},remote={'Другое лобби','Another lobby','其他大厅'},inmatch={'Сейчас в матче','In a match','正在比赛'},connect={'Подключиться','Connect','连接'},remotehelp={'Подключение перенесёт тебя в публичное лобби этого игрока. Затем можно позвонить или написать.','Connect joins this player’s public lobby. Then you can call or message.','连接会进入该玩家的公共大厅，之后可以通话或发消息。'},private_match={'Этот матч закрыт. Подключиться можно, когда игрок вернётся в лобби.','This match is closed. Connect when the player returns to the lobby.','此比赛已关闭，玩家回到大厅后可连接。'},finish_match={'Сначала закончи матч и вернись в лобби.','Finish your match and return to the lobby first.','请先结束比赛并返回大厅。'},link_offline={'Межсерверный список временно недоступен. Игроки этого сервера остаются на связи.','The cross-server list is unavailable. Players in this server remain reachable.','跨服务器列表暂时不可用，当前服务器玩家仍可联系。'},favorites={'Избранные','Favorites','收藏'},favoriteadd={'В избранное','Add to favorites','添加收藏'},favoriteremove={'Убрать из избранного','Remove favorite','取消收藏'},favoritehint={'Избранное и история хранятся в этом сеансе.','Favorites and history stay in this session.','收藏和记录在本次会话中保留。'},norecents={'Здесь появятся твои звонки.','Your calls appear here.','通话记录将显示在这里。'},missed={'Пропущенный','Missed','未接'},incoming={'Входящий','Incoming','来电'},outgoing={'Исходящий','Outgoing','去电'},sent={'Отправлено','Sent','已发送'},unread={'Новое сообщение','New message','新消息'},localnumber={'Номера работают только внутри Spy Club.','Numbers work inside Spy Club only.','号码仅在Spy Club内使用。'},connecting={'Переход в лобби…','Joining lobby…','正在进入大厅…'},lookupself={'Это твой номер.','That is your number.','这是你的号码。'}
}
local ink=Color3.fromRGB(242,241,231);local muted=Color3.fromRGB(166,180,174);local green=Color3.fromRGB(53,114,88)
words.linkvisible={'Виден другим участникам','Visible to other members','其他成员可见'}
words.linkhidden={'Ты скрыт из списка','Hidden from the list','已从列表隐藏'}
words.linknearby={'Виден игрокам этого сервера','Visible in this server','当前服务器可见'}
words.linkwaiting={'Обновляем список…','Updating list…','正在更新列表…'}
words.linkhide={'Скрыться','Hide from list','隐藏'}
words.linkappear={'Появиться в списке','Appear in list','显示在列表中'}
words.linkhelp={'Найди собеседника здесь или по номеру.','Find someone here or by their club number.','在这里或通过俱乐部号码寻找联系人。'}
words.linkmembers={'Участники ClubLink','ClubLink members','ClubLink成员'}
words.savedcontacts={'Сохранённые','Saved contacts','已保存联系人'}
words.openlink={'Открыть ClubLink','Open ClubLink','打开ClubLink'}
words.nomessages={'Пока нет переписок','No conversations yet','暂无对话'}
words.linkhelp={'Твой номер виден в списке только после входа в ClubLink.','Your number appears in the directory after joining ClubLink.','加入ClubLink后，你的号码才会显示在列表中。'}

local function make(cl,parent,p)local n=Instance.new(cl);for k,v in pairs(p)do n[k]=v end;n.Parent=parent;return n end
local function round(n,r)make('UICorner',n,{CornerRadius=UDim.new(0,r)})end
function Connect.attach(ui,State,options)
 local oldTr,oldRender,oldResize=ui.tr,ui.render,ui.resize
 local Players=game:GetService('Players');local player=Players.LocalPlayer
 ui.contacts=ui.contacts or{};ui.favorites=ui.favorites or{};ui.unread=ui.unread or{};ui.recents={};ui.members={};ui.linkVisible=player:GetAttribute('SpyClubLinkVisible')==true
 ui.connectUI=true
 ui.localDirectoryEpoch={}
 function ui:tr(k)local w=words[k];return w and w[self.options.language()=='en'and 2 or self.options.language()=='zh'and 3 or 1]or oldTr(self,k)end
 local own=ui:label(ui.screen,'OwnPhoneNumber','',13);own.Font=Enum.Font.BuilderSansBold;own.TextColor3=muted
 local function number(id)return State.formatNumber(State.number(id))end
 local function paragraph(text,name,size,color)local p=ui:paragraph(text,name,size or 15);p.TextColor3=color or muted;return p end
 local function button(name,text,fn)local b=ui:button(ui.content,name,text,fn);b.Size=UDim2.new(1,0,0,48);return b end
 function ui:addContact(c)
  if type(c)~='table'or type(c.userId)~='number'or State.number(c.userId)~=c.number or type(c.displayName)~='string'then return false end
  self.contacts[c.userId]=table.clone(c);return true
 end
 function ui:showContact(c)
  if not self:addContact(c)then return end
  self.app='contacts';self.peer=c.userId;self:render()
 end
 function ui:recordCall(previous,reason)
  if not previous.id or not previous.peer then return end
  for _,r in ipairs(self.recents)do if r.id==previous.id then return end end
  table.insert(self.recents,1,{id=previous.id,peer=previous.peer,at=os.date('%H:%M'),kind=previous.phase=='ringing'and previous.incoming and reason=='missed'and'missed'or(previous.incoming and'incoming'or'outgoing')})
  while #self.recents>24 do table.remove(self.recents)end
 end
 local function unreadBadge()
  local total=0;for _,n in pairs(ui.unread)do total+=n end
  local caption=ui.gui:FindFirstChild('AppCaption_messages',true)
  if caption then caption.Text=ui:tr('messages')..(total>0 and' · '..total or'')end
 end
 local receive=ui.receiveMessage
 function ui:receiveMessage(d)
  if type(d.peer)=='number'and d.peer~=player.UserId and not self.contacts[d.peer]then
   local p=Players:GetPlayerByUserId(d.peer)
   self:addContact({userId=d.peer,number=State.number(d.peer),displayName=p and p.DisplayName or number(d.peer),sameServer=p~=nil,joinable=p~=nil})
  end
  receive(self,d);unreadBadge()
 end
 local function contactRow(parent,c,name,onClick,sub)
  local b=ui:button(parent,name,'',onClick);b.Size=UDim2.new(1,0,0,72);b.BackgroundColor3=Color3.fromRGB(32,44,40)
  local avatar=make('ImageLabel',b,{Name='Avatar',Position=UDim2.fromOffset(12,14),Size=UDim2.fromOffset(44,44),BackgroundColor3=Color3.fromRGB(50,66,60),BorderSizePixel=0,Image='rbxthumb://type=AvatarHeadShot&id='..c.userId..'&w=150&h=150'});round(avatar,22)
  local title=ui:label(b,'MemberName',c.displayName,16);title.Font=Enum.Font.BuilderSansBold;title.Position=UDim2.fromOffset(68,9);title.Size=UDim2.new(1,-80,0,22);title.TextTruncate=Enum.TextTruncate.AtEnd
  local digits=ui:label(b,'MemberNumber',number(c.userId),13);digits.Position=UDim2.fromOffset(68,31);digits.Size=UDim2.new(1,-80,0,18);digits.TextColor3=ink
  local status=ui:label(b,'MemberStatus',sub or ui:tr(c.sameServer and'nearby'or(c.joinable and'remote'or'inmatch')),11);status.Position=UDim2.fromOffset(68,49);status.Size=UDim2.new(1,-80,0,18);status.TextColor3=muted
  return b
 end
 local function directory(visible)
  if ui.linkLoading then if type(visible)=='boolean'then ui.linkQueuedVisibility=visible end;return end
  ui.linkLoading=true;ui.linkRequestGeneration=(ui.linkRequestGeneration or 0)+1;local generation=ui.linkRequestGeneration
  local accepted=options.request({action='link',visible=visible},function(d)
   if generation~=ui.linkRequestGeneration then return end
   ui.linkLoading=false;if visible~=nil then ui.linkStarted=true end;ui.linkVisible=d.visible==true;ui.linkNetwork=d.network==true;ui.members=type(d.members)=='table'and d.members or{}
   if ui.visible and(ui.app=='clublink'or ui.app=='contacts'and not ui.peer)and not game:GetService('UserInputService'):GetFocusedTextBox()then ui:render()end
   local queued=ui.linkQueuedVisibility;ui.linkQueuedVisibility=nil
   if queued~=nil then task.defer(function()directory(queued)end)end
  end)
  if accepted==false then ui.linkLoading=false end
 end
 local hide=ui.hide
 function ui:hide()
  self.linkRequestGeneration=(self.linkRequestGeneration or 0)+1;self.linkLoading=false;self.linkQueuedVisibility=nil
  self.lastConnectApp=nil;self.lastConnectPeer=nil;hide(self)
 end
 function ui:linkFailed()
  self.linkLoading=false;self.linkNetwork=false;self.linkVisible=player:GetAttribute('SpyClubLinkVisible')==true
  if self.visible and self.app=='clublink'and not game:GetService('UserInputService'):GetFocusedTextBox()then self:render()end
 end
 local function directoryContacts()
  local entries,seen={},{}
  -- Replicated opt-in is authoritative for this server. A cached row cannot
  -- keep a hidden local member visible or resurrect someone who left.
  for _,p in ipairs(Players:GetPlayers())do
   seen[p.UserId]=true
   if p~=player and p:GetAttribute('SpyClubLinkVisible')==true and State.number(p.UserId)then
    entries[#entries+1]={userId=p.UserId,displayName=p.DisplayName,number=State.number(p.UserId),sameServer=true,joinable=true}
   end
  end
  for _,c in ipairs(ui.members)do
   local epoch=type(c)=='table'and ui.localDirectoryEpoch[c.userId]
   local fresh=not epoch or type(c.started)=='number'and c.started==c.started and c.started>epoch
   if type(c)=='table'and type(c.userId)=='number'and c.userId~=player.UserId and State.number(c.userId)==c.number and type(c.displayName)=='string'and not seen[c.userId]and c.sameServer==false and fresh then
    seen[c.userId]=true;entries[#entries+1]=c
   end
  end
  table.sort(entries,function(a,b)if a.sameServer~=b.sameServer then return a.sameServer end;return a.userId<b.userId end)
  return entries
 end
 function ui:directoryContacts()return directoryContacts()end
 local function conversationContacts()
  local ids={};for id in pairs(ui.contacts)do ids[id]=true end;for id in pairs(ui.conversations)do ids[id]=true end
  local ordered={};for id in pairs(ids)do if id~=player.UserId then ordered[#ordered+1]=id end end;table.sort(ordered)
  return ordered
 end
 local function lookup()
  local editor=ui.dialEditor;local n=editor and editor.Text or ui.dialText or'';ui.dialText=n
  local id=State.numberId(n);if not id then ui:error('invalid');return end
  if id==player.UserId then ui:error('lookupself');return end
  options.request({action='lookup',number=State.number(id)},function(d)
   if ui.visible and ui.app=='dialpad'and ui.dialEditor==editor and editor and editor.Text==n then ui:showContact(d.contact)end
  end)
 end
 function ui:resize()
  oldResize(self);own.Visible=self.app=='home';own.Text=number(player.UserId)
  local h=self.shell.Size.Y.Offset;local compact=h<360
  own.Position=UDim2.fromOffset(22,compact and 48 or(h<430 and 113 or 143));own.Size=UDim2.new(1,-44,0,20)
  if self.app=='home'then
   local clock=self.screen:FindFirstChild('HomeClock');local date=self.screen:FindFirstChild('HomeDate')
   if clock then clock.Visible=not compact end;if date then date.Visible=not compact;date.Size=UDim2.new(1,-44,0,18)end
   local top=compact and 78 or(h<430 and 141 or 181)
   self.content.Position=UDim2.fromOffset(18,top);self.content.Size=UDim2.new(1,-36,1,-top-108)
   if self.grid then self.grid.CellSize=UDim2.new(1/3,-6,0,100)end
  end
 end
 function ui:render()
  local entering=self.app=='clublink'and self.lastConnectApp~='clublink'
  local contactsEntering=self.app=='contacts'and not self.peer and(self.lastConnectApp~='contacts'or self.lastConnectPeer~=nil)
  self.lastConnectApp=self.app;self.lastConnectPeer=self.peer
  oldRender(self)
  if self.app=='clublink'then
   local status=self.linkLoading and'linkwaiting'or(not self.linkVisible and'linkhidden'or(self.linkNetwork==false and'linknearby'or'linkvisible'))
   paragraph(self:tr(status),'ClubLinkStatus',16,self.linkVisible and Color3.fromRGB(127,189,153)or muted)
   paragraph(self:tr('linkhelp'),'ClubLinkHelp',14)
   paragraph(self:tr('mynumber')..'\n'..number(player.UserId),'ClubLinkOwnNumber',18,ink)
   button('LinkVisibility',self:tr(self.linkVisible and'linkhide'or'linkappear'),function()directory(not self.linkVisible)end)
   button('LinkRefresh',self:tr('refresh'),function()directory()end)
   if self.linkNetwork==false then paragraph(self:tr('link_offline'),'LinkOffline',14)end
   local active=directoryContacts()
   for _,c in ipairs(active)do contactRow(self.content,c,'ClubLink_'..c.userId,function()self:showContact(c)end)end
   if #active==0 then paragraph(self:tr('linkempty'),'ClubLinkEmpty',15)end
   if entering then directory(not self.linkStarted and true or nil)end
  elseif self.app=='dialpad'then
   local input=make('TextBox',self.content,{Name='DialNumber',Text=self.dialText or'',PlaceholderText=self:tr('numberhint'),ClearTextOnFocus=false,TextSize=21,Font=Enum.Font.BuilderSansBold,TextColor3=ink,PlaceholderColor3=muted,BackgroundColor3=Color3.fromRGB(31,42,38),BorderSizePixel=0,Size=UDim2.new(1,0,0,56)});round(input,10);self.dialEditor=input
   input:GetPropertyChangedSignal('Text'):Connect(function()self.dialText=input.Text:sub(1,32)end)
   local keys=make('Frame',self.content,{Name='DialKeys',Size=UDim2.new(1,0,0,248),BackgroundTransparency=1})
   make('UIGridLayout',keys,{CellSize=UDim2.new(1/3,-5,0,56),CellPadding=UDim2.fromOffset(7,8),SortOrder=Enum.SortOrder.LayoutOrder})
   for i,key in ipairs({'1','2','3','4','5','6','7','8','9','clear','0','back'})do
    local b=self:button(keys,'DialKey_'..key,key=='clear'and'×'or(key=='back'and'⌫'or key),function()
     if key=='clear'then input.Text=''elseif key=='back'then input.Text=input.Text:sub(1,-2)elseif #input.Text<32 then input.Text..=key end
     self.dialText=input.Text
    end);b.LayoutOrder=i;b.TextSize=27;b.Size=UDim2.new(1/3,-5,0,56)
   end
   local find=button('DialLookup',self:tr('findnumber'),lookup);find.BackgroundColor3=green
   paragraph(self:tr('localnumber'),'NumberScope',13)
  elseif self.app=='calls'then
   button('PhoneDialpad',self:tr('dialpad'),function()self.app='dialpad';self:render()end)
   button('PhoneRecents',self:tr('recents'),function()self.app='recents';self:render()end)
  elseif self.app=='recents'then
   for _,r in ipairs(self.recents)do
    local p=Players:GetPlayerByUserId(r.peer);local c=self.contacts[r.peer]or{userId=r.peer,displayName=p and p.DisplayName or number(r.peer),number=State.number(r.peer),sameServer=p~=nil}
    contactRow(self.content,c,'RecentCall_'..r.id,function()self:showContact(c)end,self:tr(r.kind)..' · '..r.at)
   end
   if #self.recents==0 then paragraph(self:tr('norecents'),'RecentsEmpty',16)end
   paragraph(self:tr('favoritehint'),'HistoryScope',12)
  elseif self.app=='contacts'then
   if self.peer then
    local p=Players:GetPlayerByUserId(self.peer);local c=self.contacts[self.peer]
    paragraph(number(self.peer),'ContactNumber',18,ink)
    button('FavoriteContact',self:tr(self.favorites[self.peer]and'favoriteremove'or'favoriteadd'),function()self.favorites[self.peer]=not self.favorites[self.peer];self:render()end)
    if not p and c and not c.sameServer then
     local message=self.content:FindFirstChild('ContactMessage');if message then message:Destroy()end
     local call=self.content:FindFirstChild('ContactCall');if call then call:Destroy()end
     if c.joinable then
      paragraph(self:tr('remotehelp'),'RemoteConnectHelp',15)
      local join=button('ConnectLobby',self:tr('connect'),function()
       options.request({action='connect',target=c.userId},function(d)
        if not self.visible or self.app~='contacts'or self.peer~=c.userId or game:GetService('UserInputService'):GetFocusedTextBox()then return end
        if d.contact and d.contact.userId==c.userId then self:showContact(d.contact)elseif d.teleporting then self:error('connecting')end
       end)
      end);join.BackgroundColor3=green
     else paragraph(self:tr('private_match'),'ClosedMatchHelp',15)end
    end
   else
    local ordered={};for id,value in pairs(self.favorites)do if value then ordered[#ordered+1]=id end end;table.sort(ordered)
    if #ordered>0 then paragraph(self:tr('savedcontacts'),'FavoritesHeading',17,ink)end
    for _,id in ipairs(ordered)do local p=Players:GetPlayerByUserId(id);local c=self.contacts[id]or{userId=id,displayName=p and p.DisplayName or number(id),number=State.number(id),sameServer=p~=nil}
     contactRow(self.content,c,'Favorite_'..id,function()self:showContact(c)end,self:tr('savedcontacts'))
    end
    paragraph(self:tr('linkmembers'),'ContactsHeading',17,ink)
    local active=directoryContacts()
    for _,c in ipairs(active)do
     if not self.favorites[c.userId]then contactRow(self.content,c,'Contact_'..c.userId,function()self:showContact(c)end)end
    end
    if #active==0 then paragraph(self:tr('linkempty'),'ContactsEmpty',15)end
    button('OpenClubLink',self:tr('openlink'),function()self.peer=nil;self.app='clublink';self:render()end)
    button('ContactsRefresh',self:tr('refresh'),function()directory()end)
    button('ContactDialpad',self:tr('dialpad'),function()self.app='dialpad';self:render()end)
    if contactsEntering then directory()end
   end
  elseif self.app=='messages'and not self.peer then
   local ids=conversationContacts()
   for _,id in ipairs(ids)do
    local p=Players:GetPlayerByUserId(id);local c=self.contacts[id]or{userId=id,displayName=p and p.DisplayName or number(id),number=State.number(id),sameServer=p~=nil}
    contactRow(self.content,c,'Conversation_'..id,function()self.peer=id;self:render()end,(self.unread[id]or 0)>0 and self:tr('unread')or nil)
   end
   if #ids==0 then paragraph(self:tr('nomessages'),'MessagesEmpty',17)end
   button('OpenClubLink',self:tr('openlink'),function()self.peer=nil;self.app='clublink';self:render()end)
  end
  if self.app=='home'then unreadBadge()end
  self:resize()
 end
 local connections={};local watched={}
 local function refreshDirectory()
  if ui.visible and(ui.app=='clublink'or ui.app=='contacts'and not ui.peer)and not game:GetService('UserInputService'):GetFocusedTextBox()then ui:render()end
 end
 local function watch(p)
  if watched[p]then return end;watched[p]=true
  ui.localDirectoryEpoch[p.UserId]=workspace:GetServerTimeNow()
  connections[#connections+1]=p:GetAttributeChangedSignal('SpyClubLinkVisible'):Connect(function()
   if p:GetAttribute('SpyClubLinkVisible')~=true then ui.localDirectoryEpoch[p.UserId]=workspace:GetServerTimeNow()end
   refreshDirectory()
  end)
 end
 for _,p in ipairs(Players:GetPlayers())do watch(p)end
 connections[#connections+1]=Players.PlayerAdded:Connect(function(p)watch(p);refreshDirectory()end)
 connections[#connections+1]=Players.PlayerRemoving:Connect(function(p)ui.localDirectoryEpoch[p.UserId]=workspace:GetServerTimeNow();task.defer(refreshDirectory)end)
 connections[#connections+1]=player:GetAttributeChangedSignal('SpyClubLinkVisible'):Connect(function()ui.linkVisible=player:GetAttribute('SpyClubLinkVisible')==true;refreshDirectory()end)
 ui.gui.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end end)
 ui:render();return ui
end
return Connect
