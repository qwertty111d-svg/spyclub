-- Phone-native functions. Inventory/shop/profile remain in the game UI.
local Social={}
local words={
 home={'Телефон','Phone','手机'},clublink={'ClubLink','ClubLink','ClubLink'},messages={'Сообщения','Messages','消息'},contacts={'Контакты','Contacts','联系人'},calls={'Звонки','Calls','通话'},camera={'Камера','Camera','相机'},notes={'Заметки','Notes','笔记'},timer={'Секундомер','Timer','计时器'},light={'Фонарик','Light','手电筒'},sound={'Звук','Sound','声音'},
 online={'Сейчас в клубе','In the club','俱乐部在线成员'},empty={'Пока никого. Контакты появятся, когда зайдут другие игроки.','Nobody here yet. Contacts appear when other players join.','其他玩家加入后，将显示联系人。'},write={'Написать','Message','发消息'},dial={'Позвонить','Call','拨打'},send={'Отправить','Send','发送'},input={'Сообщение…','Message…','输入消息…'},
 unknown={'Не отмечен','Unmarked','未标记'},suspect={'Подозреваю','Suspected','怀疑'},clear={'Доверяю','Trusted','信任'},mission_camera={'Камера','Camera','相机'},
 incoming={'Входящий звонок','Incoming call','来电'},outgoing={'Вызов…','Calling…','呼叫中…'},answer={'Принять','Answer','接听'},decline={'Отклонить','Decline','拒接'},endcall={'Завершить','End call','挂断'},voice={'Голосовой разговор','Voice call','语音通话'},voice_connecting={'Подключаем звук…','Connecting audio…','正在连接音频…'},textcall={'Голос недоступен. Можно открыть сообщения.','Voice unavailable. You can open Messages.','语音不可用，可打开消息。'},idlecall={'Выбери контакт, чтобы позвонить.','Choose a contact to call.','选择联系人拨打。'},chatcall={'Открыть переписку','Open conversation','打开聊天'},
 private={'Только для тебя. Нажми «Сохранить», чтобы забрать записи в следующий сеанс.','Only for you. Tap Save to keep notes for your next session.','仅自己可见。点击保存，即可在下次登录时查看。'},note={'Запиши свои мысли…','Write your notes…','记录你的想法…'},starttimer={'Начать','Start','开始'},stoptimer={'Пауза','Pause','暂停'},reset={'Сбросить','Reset','重置'},lighton={'Включить фонарик','Turn light on','打开手电筒'},lightoff={'Выключить фонарик','Turn light off','关闭手电筒'},quieton={'Без звука','Silent','静音'},quietoff={'Со звуком','Sound on','开启声音'},
 ringtone={'Рингтон','Ringtone','铃声'},test={'Послушать','Preview','试听'},short={'Мягкий','Soft','柔和'},classic={'Классический','Classic','经典'},photograph={'Сделать фото','Take photo','拍照'},savephoto={'Сохранить в галерею Roblox','Save to Roblox gallery','保存到Roblox图库'},photoempty={'Сними клуб или друзей. Фото видно только тебе.','Photograph the club or your friends. Only you see the photo.','拍摄俱乐部或朋友，照片仅自己可见。'},stories={'Винсент','Vincent','文森特'},
 privacy={'Roblox не разрешает общение между этими аккаунтами.','Roblox does not allow these accounts to communicate.','Roblox不允许这两个账号交流。'},filter={'Фильтрация недоступна. Сообщение не отправлено.','Filtering unavailable. Message was not sent.','过滤服务不可用，消息未发送。'},left={'Игрок сейчас недоступен.','Player is unavailable.','玩家当前不可用。'},rate={'Подожди немного перед следующим действием.','Wait a moment before trying again.','请稍后再试。'},busy={'Игрок уже разговаривает.','Player is already in a call.','玩家正在通话。'},timeout={'Нет ответа. Попробуй ещё раз.','No response. Try again.','无响应，请重试。'},loading={'Подключение…','Connecting…','连接中…'},stale={'Этот вызов уже закончился.','This call has ended.','通话已结束。'},blocked={'Сейчас телефон недоступен.','Phone unavailable right now.','当前无法使用手机。'},unavailable={'Пока недоступно. Повтори позже.','Unavailable. Try again later.','暂时不可用，请稍后重试。'},invalid={'Проверь сообщение: максимум160 символов.','Check the message: up to160 characters.','请检查消息，最多160个字符。'},
}
words.sent={'Отправлено','Sent','已发送'}
words.dm_restricted={'Личные сообщения между вами запрещены Roblox [DM04]. Черновик сохранён.','Roblox blocks private messages between you [DM04]. Draft saved.','Roblox禁止你们之间的私信 [DM04]。草稿已保留。'}
words.permission_unavailable={'Не удалось проверить доступ к ЛС [DM01]. Текст сохранён.','Messaging check failed [DM01]. Your draft is saved.','无法检查私信权限 [DM01]。草稿已保留。'}
words.channel_unavailable={'Не удалось открыть канал ЛС [DM02]. Попробуй позже.','Private channel unavailable [DM02]. Try again later.','无法打开私信频道 [DM02]。请稍后重试。'}
words.channel_permissions={'Roblox не открыл доступ к каналу ЛС [DM03]. Черновик сохранён.','Roblox did not grant private channel access [DM03]. Draft saved.','Roblox未授予私信频道权限 [DM03]。草稿已保留。'}
words.send_timeout={'Доставка не подтверждена. Черновик сохранён.','Delivery not confirmed. Draft saved.','未确认送达。草稿已保留。'}
words.publicchat={'Открыть общий чат','Open public chat','打开公共聊天'}
words.dm_restricted={'ЛС недоступны. Черновик сохранён.','Private chat unavailable. Draft saved.','私信不可用。草稿已保留。'}
words.lighthint={'Подсвети тёмные углы клуба. В режиме осмотра телефон не закрывает сцену.','Inspect the club’s darker corners. The phone moves aside while the light is on.','照亮俱乐部的暗角。打开灯光时手机界面会收起。'}
words.torchhint={'Поверни персонажа, чтобы направить свет.','Turn your character to aim the light.','转动角色以调整照明方向。'}
words.torchstop={'Выключить','Turn off','关闭'}
words.navigator={'Навигатор','Navigator','导航'}
words.note_save={'Сохранить','Save','保存'}
words.note_reload={'Обновить сохранённую запись','Refresh saved note','刷新已保存的笔记'}
words.note_saved={'Сохранено в профиле','Saved to your profile','已保存至个人资料'}
words.note_studio={'Сохранено в тестовом сеансе Studio','Saved in this Studio test session','已在Studio测试会话中保存'}
words.note_unsaved={'Есть несохранённые изменения','Unsaved changes','有未保存的更改'}
words.note_loading={'Запись загружается…','Loading your note…','正在加载笔记…'}
words.note_saving={'Сохраняем…','Saving…','正在保存…'}
words.note_load_failed={'Нет ответа. Обнови запись. Текст остался здесь.','No response. Refresh the note. Your text is kept.','未收到回应。请刷新笔记，当前文本已保留。'}
words.note_failed={'Не удалось подтвердить сохранение. Текст остался здесь.','Save unconfirmed. Your text is still here.','保存尚未确认，当前文本已保留。'}
words.note_conflict={'Запись изменилась. Обнови её перед сохранением.','The saved note changed. Refresh before saving.','已保存的笔记发生了变化。请刷新后再保存。'}
words.note_invalid={'До4096 символов. Не используй служебные символы.','Up to4096 characters. Avoid control characters.','最多4096个字符，请勿使用控制字符。'}
words.note_busy={'Профиль занят. Повтори сохранение чуть позже.','Profile busy. Try saving again in a moment.','资料处理中，请稍后再保存。'}
local function noteText(value)
 if type(value)~='string'or not utf8.len(value)then return ''end
 local stop=utf8.offset(value,4097)
 return stop and value:sub(1,stop-1)or value
end
local ink=Color3.fromRGB(243,243,246);local muted=Color3.fromRGB(162,164,173);local brass=Color3.fromRGB(211,212,221)
words.party_full={'Все места за столом заняты.','This table is full.','牌桌已满。'}
words.party_locked={'Матч за этим столом уже начинается.','This table is starting a match.','这桌比赛即将开始。'}
words.party_not_found={'Этого стола уже нет.','This table is no longer available.','牌桌已不存在。'}
words.already_active={'Сначала закончи текущее действие.','Finish your current activity first.','请先结束当前活动。'}
words.tools={'Инструменты клуба','Club tools','俱乐部工具'}
words.club={'Клуб','Club','俱乐部'}
words.club_tables={'Столы','Tables','牌桌'};words.club_meetups={'Встречи','Meetups','聚会'};words.club_results={'Лента','Results','成绩'}
words.club_scope={'В этом сервере','In this server','当前服务器'};words.club_refresh={'Обновить','Refresh','刷新'}
words.club_empty={'Открой события клуба','Load club activity','查看俱乐部动态'};words.club_no_table={'Создай стол в лобби, чтобы пригласить друзей.','Create a lobby table to invite friends.','在大厅创建牌桌后邀请好友。'}
words.club_my_table={'Мой стол','My table','我的牌桌'};words.club_join={'Сесть за стол','Join table','加入牌桌'}
words.club_invite={'Пригласить','Invite','邀请'};words.club_busy={'Занят','Busy','忙碌'};words.club_no_results={'Первые результаты появятся после игры.','Results appear after a game.','游戏结束后将显示成绩。'}
words.club_billiards={'Бильярд','Billiards','台球'};words.club_checkers={'Шашки','Checkers','跳棋'};words.club_spy={'Матч','Match','对局'}
words.club_plan_after={'Встреча через','Meet in','多久后聚会'};words.club_minutes={'мин','min','分钟'};words.club_people={'Участники','Attending','参加人数'};words.club_attend={'Участвовать','Attend','参加'}
words.club_leave={'Не участвую','Leave meetup','退出聚会'};words.club_cancel={'Отменить встречу','Cancel meetup','取消聚会'}
words.club_won={'Победа в матче','Match win','对局获胜'};words.club_lost={'Матч завершён','Match finished','对局结束'}
words.club_expired={'Приглашение или встреча уже недоступны.','Invitation or meetup has expired.','邀请或聚会已失效。'}
local function make(cl,parent,p)local n=Instance.new(cl);for k,v in pairs(p)do n[k]=v end;n.Parent=parent;return n end
local function round(n,r)make('UICorner',n,{CornerRadius=UDim.new(0,r)})end
function Social.attach(ui,options)
 local oldTr,oldRender=ui.tr,ui.render
 ui.call={phase='idle',revision=0};ui.conversations={};ui.drafts={};ui.messageDirty={};ui.unread={};ui.note='';ui.noteDirty=false;ui.noteStatus='note_loading';ui.timer={elapsed=0};ui.quiet=false;ui.ringtone='soft'
 function ui:tr(k)local w=words[k];return w and w[self.options.language()=='en'and 2 or self.options.language()=='zh'and 3 or 1]or oldTr(self,k)end
 local function go(key)if key=='camera'and not ui.options.inMatch then if options.camera then options.camera()else ui:error('unavailable')end;return end;ui.app=key;ui.peer=nil;ui:render();if key=='club'then ui:loadClub()end end
 local function row(text,name,size,color)local n=ui:paragraph(text,name,size or 16);n.TextColor3=color or ink;return n end
 local function button(name,text,fn,color)local b=ui:button(ui.content,name,text,fn);b.Font=Enum.Font.BuilderSansMedium;if color then b.BackgroundColor3=color;if color==ui.palette.action then b.TextColor3=ui.palette.actionInk end end;return b end
 local function name(id)
  -- Idle calls have no peer. Roblox requires a user ID for this lookup.
  if type(id)~='number'then return ''end
  local p=game:GetService('Players'):GetPlayerByUserId(id)
  local saved=ui.contacts and ui.contacts[id]
  return p and p.DisplayName or(saved and saved.displayName)or tostring(id)
 end
 local function avatar(parent,id)
  local n=make('ImageLabel',parent,{Name='Avatar',Size=UDim2.fromOffset(40,40),Position=UDim2.fromOffset(10,7),BackgroundColor3=Color3.fromRGB(44,45,52),BorderSizePixel=0,Image='rbxthumb://type=AvatarHeadShot&id='..id..'&w=150&h=150'});round(n,20);return n
 end
 local homeClock=ui:label(ui.screen,'HomeClock','',48);homeClock.Font=Enum.Font.Bodoni;homeClock.Position=UDim2.fromOffset(20,56);homeClock.Size=UDim2.new(1,-40,0,62)
 local homeDate=ui:label(ui.screen,'HomeDate','',14);homeDate.TextColor3=muted;homeDate.Position=UDim2.fromOffset(22,118);homeDate.Size=UDim2.new(1,-44,0,28)
 make('UIGradient',ui.screen,{Rotation=114,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(40,41,48)),ColorSequenceKeypoint.new(.48,Color3.fromRGB(24,25,30)),ColorSequenceKeypoint.new(1,Color3.fromRGB(17,18,22))})})
 local dock=make('Frame',ui.screen,{Name='HomeDock',AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-48),Size=UDim2.new(1,-36,0,54),BackgroundColor3=Color3.fromRGB(31,32,38),BackgroundTransparency=.08,BorderSizePixel=0});round(dock,5);make('UIStroke',dock,{Color=ui.palette.line,Thickness=1,Transparency=.55})
 ui.composer=make('Frame',ui.screen,{Name='MessageComposer',Position=UDim2.new(0,18,1,-154),Size=UDim2.new(1,-36,0,64),BackgroundTransparency=1,Visible=false})

 function ui:socialIcon(root,key)
  local tile=make('Frame',root,{Name='Glyph',AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,2),Size=UDim2.fromOffset(44,44),BackgroundColor3=Color3.fromRGB(43,44,52),BackgroundTransparency=1,BorderSizePixel=0});round(tile,5)
  local function line(x,y,w,h,rot)local p=make('Frame',tile,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=rot or 0,BackgroundColor3=ink,BorderSizePixel=0});round(p,2);return p end
  local function box(x,y,w,h,r)local p=make('Frame',tile,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0});round(p,r or 4);make('UIStroke',p,{Color=ink,Thickness=2});return p end
  if key=='club'then box(8,17,28,12,6);line(12,30,2,6);line(30,30,2,6);box(18,5,8,8,4)
  elseif key=='clublink'then box(8,12,19,12,6);box(18,21,19,12,6);line(18,21,10,2,-35)
  elseif key=='calls'then line(11,12,5,20,-26);line(11,10,11,5,-26);line(19,29,12,5,-26)
  elseif key=='messages'then box(8,10,28,21,8);line(10,27,9,4,-32);for i=0,2 do line(14+i*7,19,3,3)end
  elseif key=='contacts'then box(17,8,10,10,5);box(10,23,24,12,6)
  elseif key=='camera'then box(8,13,28,21,5);box(17,18,10,10,5);line(12,9,10,4)
  elseif key=='navigator'then box(9,9,26,26,13);line(19,15,3,15,35);line(24,19,3,10,-55)
  elseif key=='timer'then box(11,12,23,23,12);line(20,7,6,3);line(22,18,2,9);line(22,25,7,2)
  elseif key=='light'then line(17,21,10,15);box(14,10,16,12);line(8,5,5,2,-35);line(31,5,5,2,35)
  elseif key=='sound'then box(10,17,8,10);line(19,12,4,20);box(28,14,6,17,4)
  else box(11,8,22,28);line(16,16,12,2);line(16,22,12,2);line(16,28,9,2)end
  return tile
 end
 for i,key in ipairs({'calls','contacts','messages','notes'})do
  local b=ui:button(dock,'Dock_'..key,'',function()go(key)end);b.Position=UDim2.new((i-1)/4,4,0,5);b.Size=UDim2.new(.25,-8,0,46);b.BackgroundTransparency=1;ui:socialIcon(b,key)
 end
 local notification=make('Frame',ui.gui,{Name='PhoneIncoming',AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,72),Size=UDim2.fromOffset(284,126),BackgroundColor3=Color3.fromRGB(25,26,32),BorderSizePixel=0,Visible=false});round(notification,8)
 local noticeTitle=ui:label(notification,'IncomingTitle','',17);noticeTitle.Position=UDim2.fromOffset(14,10);noticeTitle.Size=UDim2.new(1,-28,0,48);noticeTitle.TextWrapped=true;noticeTitle.Font=Enum.Font.BuilderSansBold
 local pickup=ui:button(notification,'PickupNotification','',function()options.openCall();options.request({action='answer',id=ui.call.id})end,true);pickup.Position=UDim2.fromOffset(14,68);pickup.Size=UDim2.new(.5,-20,0,44);pickup.BackgroundColor3=ui.palette.action;pickup.TextColor3=ui.palette.actionInk
 local decline=ui:button(notification,'DeclineNotification','',function()options.request({action='answer',id=ui.call.id,accept=false})end,true);decline.Position=UDim2.new(.5,6,0,68);decline.Size=UDim2.new(.5,-20,0,44)
 function ui:setTorch()self.flash=false end
 function ui:notice()
  notification.Visible=(not self.visible or self.app~='calls'or self.torch==true)and self.call.phase=='ringing'and self.call.incoming and not self.options.blocked()
  noticeTitle.Text=name(self.call.peer)..'\n'..self:tr('incoming');pickup.Text=self:tr('answer');decline.Text=self:tr('decline')
 end
 function ui:setCall(d)
  if type(d)~='table'or(d.revision or 0)<(self.call.revision or 0)then return end
  local previous=self.call;self.call=d
  if d.phase=='idle'and previous.phase~='idle'and self.recordCall then self:recordCall(previous,d.reason)end
  local editing=self.torch or self.app=='notes'or(self.app=='messages'and self.peer~=nil)
  local focus=game:GetService('UserInputService'):GetFocusedTextBox()
  local obscured=self.options.blocked()
  if self.visible and not editing and not focus and not obscured and d.phase~='idle'and(previous.id~=d.id or previous.phase=='ringing')then self.app='calls';self.peer=d.peer end
  self:notice();if self.visible and not editing and not focus and not obscured then self:render()end
 end
 function ui:receiveMessage(d)
  if type(d.text)~='string'or type(d.peer)~='number'then return end
  local history=self.conversations[d.peer]or{};self.conversations[d.peer]=history
  for _,m in ipairs(history)do if m.id==d.id then return end end
  history[#history+1]=d;if #history>60 then table.remove(history,1)end
  if d.from~=game:GetService('Players').LocalPlayer.UserId and not(self.visible and self.app=='messages'and self.peer==d.peer)then self.unread[d.peer]=(self.unread[d.peer]or 0)+1 end
  local focus=game:GetService('UserInputService'):GetFocusedTextBox()
  self.messageDirty[d.peer]=true
  if self.visible and self.app=='messages'and self.peer==d.peer and not focus then self:render()end
 end
 function ui:ackMessage(d)
  local sent=self.sentDraft
  if sent and sent.peer==d.peer and sent.id==d.requestId then
   if self.drafts[d.peer]==sent.text then
    self.drafts[d.peer]=''
    if self.editor and self.editor.Parent and self.editorPeer==d.peer then self.editor.Text=''end
   end
   self.sentDraft=nil
  end
 end
 function ui:updateNoteStatus()if self.noteStatusLabel and self.noteStatusLabel.Parent then self.noteStatusLabel.Text=self:tr(self.noteStatus or'note_loading')end end
 function ui:updateClock()
  self.clock.Text=os.date('%H:%M');homeClock.Text=self.clock.Text;homeDate.Text=os.date('%d.%m.%Y')..' · SPY CLUB'
  if self.timerLabel then
   local seconds=math.floor(self.timer.elapsed+(self.timer.at and os.clock()-self.timer.at or 0))
   self.timerLabel.Text=string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
  end
  if self.callLabel and self.call.phase=='active'then
   local seconds=math.max(0,math.floor(workspace:GetServerTimeNow()-(self.call.at or 0)))
   self.callLabel.Text=string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
  end
 end
 ui.clubTab='tables';ui.clubRevision=0;ui.clubData=nil;ui.clubLoading=false;ui.clubRequestSerial=0
 local clubDot=make('Frame',ui.dock,{Name='ClubInvitationDot',AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-3,0,3),Size=UDim2.fromOffset(12,12),BackgroundColor3=brass,BorderSizePixel=0,Visible=false});round(clubDot,6)
 function ui:receiveClub(data)
  if type(data)~='table'or type(data.revision)~='number'or data.revision<=self.clubRevision then return end
  self.clubRevision=data.revision;self.clubData=data;self.clubLoading=false
  clubDot.Visible=type(data.invites)=='table'and #data.invites>0
  local focus=game:GetService('UserInputService'):GetFocusedTextBox()
  if self.visible and self.app=='club'and not self.options.blocked()and not focus then self:render()end
 end
 function ui:requestClub(payload)
  if self.options.inMatch or self.pending then return false end
  self.clubRequestSerial+=1;local serial=self.clubRequestSerial;self.clubLoading=true
  local accepted=options.request(payload,function(d)
   if not self.gui.Parent or serial~=self.clubRequestSerial then return end
   self.clubLoading=false;if d.club then self:receiveClub(d.club)end
  end)
  if not accepted then self.clubLoading=false;return false end
  task.delay(8,function()
   if self.gui.Parent and self.clubLoading and self.clubRequestSerial==serial then
    self.clubLoading=false
    if self.visible and self.app=='club'then self:render();self:error('timeout')end
   end
  end)
  return true
 end
 function ui:loadClub()return self:requestClub({action='club_snapshot'})end
 local function clubRow(name,height)
  local frame=make('Frame',ui.content,{Name=name,Size=UDim2.new(1,0,0,height),BackgroundColor3=Color3.fromRGB(39,42,46),BackgroundTransparency=.18,BorderSizePixel=0});round(frame,6);return frame
 end
 local function clubLabel(parent,name,value,y,size)
  local label=ui:label(parent,name,value,size or 16);label.Position=UDim2.fromOffset(12,y);label.Size=UDim2.new(1,-24,0,26);label.TextTruncate=Enum.TextTruncate.AtEnd;return label
 end
 function ui:renderClub()
  local tabs=make('Frame',self.content,{Name='ClubTabs',Size=UDim2.new(1,0,0,44),BackgroundTransparency=1})
  for i,key in ipairs({'tables','meetups','results'})do
   local b=self:button(tabs,'ClubTab_'..key,self:tr('club_'..key),function()self.clubTab=key;self:render()end)
   b.Position=UDim2.new((i-1)/3,0,0,0);b.Size=UDim2.new(1/3,-4,0,44);b.TextSize=14;b.TextWrapped=false
   if self.clubTab==key then b.BackgroundColor3=brass;b.TextColor3=Color3.fromRGB(25,27,31)end
  end
  local data=self.clubData
  if not data then row(self:tr(self.clubLoading and'loading'or'club_empty'),'ClubEmpty',16,muted);button('ClubRefresh',self:tr('club_refresh'),function()self:loadClub()end);return end
  row(self:tr('club_scope'),'ClubScope',14,muted)
  if self.clubTab=='tables'then
   for _,inv in ipairs(data.invites or{})do
    local r=clubRow('ClubInvite_'..inv.id,110);clubLabel(r,'InviteSender',inv.name,8,18).Font=Enum.Font.BuilderSansBold
    local join=self:button(r,'ClubAccept_'..inv.id,self:tr('club_join'),function()self:requestClub({action='club_accept',id=inv.id})end)
    join.Position=UDim2.fromOffset(12,52);join.Size=UDim2.new(.67,-16,0,44)
    local decline=self:button(r,'ClubDecline_'..inv.id,'×',function()self:requestClub({action='club_decline',id=inv.id})end)
    decline.Position=UDim2.new(.67,4,0,52);decline.Size=UDim2.new(.33,-16,0,44)
   end
   local party=data.party
   if not party then row(self:tr('club_no_table'),'ClubNoTable',16,muted)
   else
    local r=clubRow('ClubMyTable',78);clubLabel(r,'TableTitle',self:tr('club_my_table'),8,18).Font=Enum.Font.BuilderSansBold
    clubLabel(r,'TableSeats',tostring(party.count)..' / '..tostring(party.capacity),40,16)
    for _,peer in ipairs(data.peers or{})do
     local b=button('ClubInvitePlayer_'..peer.id,peer.name..'  ·  '..self:tr(peer.busy and'club_busy'or'club_invite'),function()self:requestClub({action='club_invite',target=peer.id})end)
     b.Active=not peer.busy and not party.locked and party.count<party.capacity;b.TextSize=16;b.TextTruncate=Enum.TextTruncate.AtEnd
    end
   end
  elseif self.clubTab=='meetups'then
   local choose=make('Frame',self.content,{Name='ClubPlanKind',Size=UDim2.new(1,0,0,44),BackgroundTransparency=1})
   self.clubPlanKind=self.clubPlanKind or'billiards'
   for i,key in ipairs({'billiards','checkers','spy'})do
    local b=self:button(choose,'ClubKind_'..key,self:tr('club_'..key),function()self.clubPlanKind=key;self:render()end)
    b.Position=UDim2.new((i-1)/3,0,0,0);b.Size=UDim2.new(1/3,-4,0,44);b.TextSize=14
    if self.clubPlanKind==key then b.BackgroundColor3=brass;b.TextColor3=Color3.fromRGB(25,27,31)end
   end
   row(self:tr('club_plan_after'),'ClubPlanAfter',14,muted)
   local times=make('Frame',self.content,{Name='ClubPlanTimes',Size=UDim2.new(1,0,0,44),BackgroundTransparency=1})
   for i,minutes in ipairs({5,15,30})do
    local b=self:button(times,'ClubPlan_'..minutes,tostring(minutes)..' '..self:tr('club_minutes'),function()self:requestClub({action='club_plan',kind=self.clubPlanKind,delay=minutes*60})end)
    b.Position=UDim2.new((i-1)/3,0,0,0);b.Size=UDim2.new(1/3,-4,0,44);b.TextSize=15
   end
   for _,plan in ipairs(data.plans or{})do
    local r=clubRow('ClubPlanRow_'..plan.id,150);clubLabel(r,'MeetingKind',self:tr('club_'..plan.kind)..' · '..os.date('%H:%M',plan.at),8,18).Font=Enum.Font.BuilderSansBold
    clubLabel(r,'MeetingHost',plan.name,40,16);clubLabel(r,'MeetingCount',self:tr('club_people')..': '..tostring(plan.count),68,15)
    local own=plan.owner==game:GetService('Players').LocalPlayer.UserId
    local b=self:button(r,'ClubAttend_'..plan.id,self:tr(own and'club_cancel'or plan.joined and'club_leave'or'club_attend'),function()self:requestClub({action=own and'club_cancel_plan'or'club_rsvp',id=plan.id})end)
    b.Position=UDim2.fromOffset(12,100);b.Size=UDim2.new(1,-24,0,44)
   end
  else
   if #(data.results or{})==0 then row(self:tr('club_no_results'),'ClubNoResults',16,muted)end
   for _,result in ipairs(data.results or{})do
    local r=clubRow('ClubResult_'..result.id,92);clubLabel(r,'ResultPlayer',result.name,8,18).Font=Enum.Font.BuilderSansBold
    local value=result.kind=='billiards'and(self:tr('club_billiards')..' · '..tostring(result.score)..' / 50')or self:tr(result.won and'club_won'or'club_lost')
    clubLabel(r,'ResultValue',value,42,16)
   end
  end
  button('ClubRefresh',self:tr('club_refresh'),function()self:loadClub()end)
 end
 local conversationHeader=make('Frame',ui.screen,{Name='ConversationHeader',Position=UDim2.fromOffset(18,82),Size=UDim2.new(1,-36,0,60),BackgroundTransparency=1,Visible=false})
 local conversationAvatar=avatar(conversationHeader,game:GetService('Players').LocalPlayer.UserId);conversationAvatar.Position=UDim2.fromOffset(0,8);conversationAvatar.Size=UDim2.fromOffset(44,44)
 local conversationName=ui:label(conversationHeader,'ConversationName','',17);conversationName.Font=Enum.Font.BuilderSansBold;conversationName.Position=UDim2.fromOffset(56,6);conversationName.Size=UDim2.new(1,-110,0,24);conversationName.TextTruncate=Enum.TextTruncate.AtEnd
 local conversationNumber=ui:label(conversationHeader,'ConversationNumber','',12);conversationNumber.Position=UDim2.fromOffset(56,30);conversationNumber.Size=UDim2.new(1,-110,0,20);conversationNumber.TextColor3=muted;conversationNumber.TextTruncate=Enum.TextTruncate.AtEnd
 local callShortcut=ui:button(conversationHeader,'ConversationCall','',function()if ui.peer then options.request({action='dial',target=ui.peer})end end);callShortcut.Position=UDim2.new(1,-48,0,8);callShortcut.Size=UDim2.fromOffset(48,44);ui:socialIcon(callShortcut,'calls');callShortcut.BackgroundTransparency=1
 local recovery=ui:button(ui.screen,'OpenClubChat','',function()
  if options.openChat then options.openChat()else ui:error('unavailable')end
 end,true)
 recovery.Visible=false;ui.messageNotices={}
 local function currentError(self)
  if self.app=='messages'and self.peer then return self.messageNotices[self.peer]end
  return self.noticeKey
 end
 function ui:error(key,context)
  local peer=context and context.action=='message'and context.target or(self.app=='messages'and self.peer)
  if type(peer)=='number'then self.messageNotices[peer]=key else self.noticeKey=key end
  local visibleError=currentError(self);self.status.Text=visibleError and self:tr(visibleError)or'';self:resize()
 end
 function ui:busy(value,context)
  self.pending=value
  if value then
   local peer=context and context.action=='message'and context.target or(self.app=='messages'and self.peer)
   if type(peer)=='number'then self.messageNotices[peer]=nil else self.noticeKey=nil end
  end
  local visibleError=currentError(self);self.status.Text=value and self:tr('loading')or(visibleError and self:tr(visibleError)or'');self:resize()
 end
 local resize=ui.resize
 function ui:resize()
  resize(self);local h=self.shell.Size.Y.Offset;local short=h<430;local tight=h<430
  homeClock.TextSize=short and 36 or 58;homeClock.Position=UDim2.fromOffset(20,short and 36 or 48)
  homeDate.Position=UDim2.fromOffset(22,short and 84 or 112)
  self.status.Position=UDim2.new(0,18,1,-76);self.status.Size=UDim2.new(1,-36,0,26)
  self.composer.Visible=self.app=='messages'and self.peer~=nil
  conversationHeader.Visible=self.composer.Visible and not tight
  conversationHeader.Position=UDim2.fromOffset(18,90)
  self.composer.Position=UDim2.new(0,18,1,tight and -102 or -140);self.composer.Size=UDim2.new(1,-36,0,tight and 44 or 52)
  if tight then self.status.Position=UDim2.new(0,18,1,-58);self.status.Size=UDim2.new(1,-36,0,16);self.status.TextTruncate=Enum.TextTruncate.AtEnd end
  if self.composer.Visible then
   if tight then self.title.Text=name(self.peer)end
   conversationName.Text=name(self.peer);conversationAvatar.Image='rbxthumb://type=AvatarHeadShot&id='..self.peer..'&w=150&h=150'
   local State=self.State;conversationNumber.Text=State.formatNumber(State.number(self.peer))
  end
  if self.app=='home'then
   local top=short and 92 or 178;self.homeTop=top
   homeClock.Visible=not short;homeDate.Visible=not short
   local noticeVisible=self.status.Text~=''
   if noticeVisible then self.status.Position=UDim2.new(0,18,1,-136);self.status.Size=UDim2.new(1,-36,0,26)end
   self.content.Position=UDim2.fromOffset(18,top);self.content.Size=UDim2.new(1,-36,1,-top-(noticeVisible and 142 or 110))
  else local top=self.composer.Visible and(tight and 94 or 158)or 94;self.content.Position=UDim2.fromOffset(18,top);self.content.Size=UDim2.new(1,-36,1,-top-(self.composer.Visible and(tight and 106 or 152)or 86))end
  local failure=self.messageNotices[self.peer]
  recovery.Visible=self.visible and self.composer.Visible and(failure=='dm_restricted'or failure=='privacy'or failure=='channel_permissions')
  recovery.Text=self:tr('publicchat');recovery.Size=UDim2.new(1,-36,0,44)
  recovery.Position=UDim2.new(0,18,1,tight and -152 or -190)
  if recovery.Visible then self.content.Size=UDim2.new(1,-36,0,math.max(0,h-16+self.composer.Position.Y.Offset-50-self.content.Position.Y.Offset))end
  local callHero=self.content:FindFirstChild('CallHero')
  local callActions=self.content:FindFirstChild('CallActions')
  if callHero and callActions then
   callHero.Size=UDim2.new(1,0,0,tight and 64 or 228)
   local face=callHero:FindFirstChild('Avatar');local person=callHero:FindFirstChild('CallPeer');local mode=callHero:FindFirstChild('CallMode')
   face.AnchorPoint=Vector2.new(tight and 0 or .5,0);face.Position=tight and UDim2.fromOffset(0,8)or UDim2.new(.5,0,0,8);face.Size=UDim2.fromOffset(tight and 48 or 88,tight and 48 or 88)
   person.Position=UDim2.fromOffset(tight and 62 or 0,tight and 4 or 112);person.Size=UDim2.new(1,tight and(self.callLabel and -126 or -62)or 0,0,32);person.TextSize=tight and 20 or 25;person.TextXAlignment=tight and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
   mode.Position=UDim2.fromOffset(tight and 62 or 8,tight and 32 or 152);mode.Size=UDim2.new(1,tight and -62 or -16,0,tight and 30 or 48);mode.TextSize=tight and 12 or 14;mode.TextXAlignment=tight and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
   if self.callLabel then
    self.callLabel.Position=tight and UDim2.new(1,-62,0,7)or UDim2.fromOffset(0,198);self.callLabel.Size=UDim2.new(tight and 0 or 1,tight and 62 or 0,0,28);self.callLabel.TextSize=tight and 17 or 25;self.callLabel.TextXAlignment=tight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center
   end
   local buttons={};for _,child in ipairs(callActions:GetChildren())do if child:IsA('TextButton')then buttons[#buttons+1]=child end end
   callActions.Size=UDim2.new(1,0,0,tight and 48 or #buttons*58-10)
   for i,b in ipairs(buttons)do
    b.Position=tight and UDim2.new((i-1)/#buttons,i>1 and 5 or 0,0,0)or UDim2.fromOffset(0,(i-1)*58)
    b.Size=tight and UDim2.new(1/#buttons,#buttons>1 and -5 or 0,0,48)or UDim2.new(1,0,0,48)
    b.TextSize=tight and 14 or 16
   end
  end
  if self.grid then self.grid.CellSize=UDim2.new(1/3,-6,0,100)end
  notification.Size=UDim2.fromOffset(math.min(284,self.gui.AbsoluteSize.X-24),126);self:notice()

 end
 function ui:render()
  if self.editor and self.editor.Parent and self.editorPeer then self.drafts[self.editorPeer]=self.editor.Text end
  if self.noteEditor and self.noteEditor.Parent then self.note=noteText(self.noteEditor.Text)end
  self.editor=nil;self.editorPeer=nil;self.noteEditor=nil;self.composer:ClearAllChildren()
  if self.app=='light'or self.app=='cases'or self.app=='line'or self.app=='decoder'or self.app=='evidence'or self.app=='mission_camera'or self.app=='camera'then self.app='home'end
  self.content:ClearAllChildren();self.grid=nil;self.timerLabel=nil;self.callLabel=nil
  self.title.Text=self:tr(self.app);self.title.Visible=self.app~='home';self.title.Font=Enum.Font.Bodoni
  self.back.Visible=self.app~='home';self.close.Text='—';self.close.TextSize=24;self.close.Font=Enum.Font.BuilderSansBold
  self.close.Size=UDim2.fromOffset(100,36);self.close.AnchorPoint=Vector2.new(.5,0);self.close.Position=UDim2.new(.5,0,1,-42)
  local visibleError=currentError(self);self.status.Text=self.pending and self:tr('loading')or(visibleError and self:tr(visibleError)or'')
  dock.Visible=self.app=='home';homeClock.Visible=dock.Visible;homeDate.Visible=dock.Visible
  if self.app=='home'then
   make('UIListLayout',self.content,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
   local connections=make('Frame',self.content,{Name='HomeConnections',Size=UDim2.new(1,0,0,166),BackgroundTransparency=1,LayoutOrder=1})
   for i,key in ipairs({'clublink','messages','calls','contacts'})do
    local b=self:button(connections,'App_'..key,'',function()go(key)end)
    local col=(i-1)%2;local rowIndex=math.floor((i-1)/2)
    b.Position=UDim2.new(col*.5,col==0 and 0 or 5,0,rowIndex*88);b.Size=UDim2.new(.5,-5,0,78)
    b.BackgroundColor3=i==1 and Color3.fromRGB(58,59,69)or ui.palette.panel
    local glyph=self:socialIcon(b,key);glyph.AnchorPoint=Vector2.zero;glyph.Position=UDim2.fromOffset(9,4);glyph.Size=UDim2.fromOffset(44,44)
    local t=self:label(b,'AppCaption_'..key,self:tr(key),15);t.Font=Enum.Font.BuilderSansMedium;t.Position=UDim2.fromOffset(12,49);t.Size=UDim2.new(1,-24,0,23);t.TextTruncate=Enum.TextTruncate.AtEnd
    local arrow=self:label(b,'AppArrow','↗',16);arrow.Position=UDim2.new(1,-30,0,11);arrow.Size=UDim2.fromOffset(20,24);arrow.TextColor3=muted
   end
   local heading=self:label(self.content,'HomeToolsHeading',self:tr('tools'),11);heading.TextColor3=muted;heading.Size=UDim2.new(1,0,0,24);heading.LayoutOrder=2
   local appKeys=self.options.inMatch and{'notes','timer','sound'}or{'club','navigator','notes','timer','sound','camera'}
   for i,key in ipairs(appKeys)do
    local b=self:button(self.content,'App_'..key,'',function()go(key)end);b.BackgroundTransparency=1;b.Size=UDim2.new(1,0,0,50);b.LayoutOrder=i+2
    local glyph=self:socialIcon(b,key);glyph.AnchorPoint=Vector2.zero;glyph.Position=UDim2.fromOffset(0,1)
    local t=self:label(b,'AppCaption_'..key,self:tr(key),16);t.Position=UDim2.fromOffset(54,9);t.Size=UDim2.new(1,-82,0,28);t.TextTruncate=Enum.TextTruncate.AtEnd
    local arrow=self:label(b,'AppArrow','›',20);arrow.Position=UDim2.new(1,-20,0,9);arrow.Size=UDim2.fromOffset(20,28);arrow.TextColor3=muted
    make('Frame',b,{Name='AppRule',Position=UDim2.new(0,54,1,-1),Size=UDim2.new(1,-54,0,1),BackgroundColor3=ui.palette.line,BackgroundTransparency=.72,BorderSizePixel=0})
   end
  else
   make('UIListLayout',self.content,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
   if self.app=='club'then self:renderClub()
   elseif(self.app=='contacts'or self.app=='messages')and not self.peer then
    if not self.connectUI then
    row(self:tr('online'),'OnlineMembers',14,muted);local count=0
    for _,p in ipairs(game:GetService('Players'):GetPlayers())do if p~=game:GetService('Players').LocalPlayer then
     count+=1;local b=button('Contact_'..p.UserId,'',function()self.peer=p.UserId;self:render()end);b.Size=UDim2.new(1,0,0,60);avatar(b,p.UserId)
     local t=self:label(b,'ContactName',p.DisplayName,16);t.Position=UDim2.fromOffset(60,8);t.Size=UDim2.new(1,-70,0,22);t.Font=Enum.Font.BuilderSansBold
     local sub=self:label(b,'ContactHandle','@'..p.Name,12);sub.Position=UDim2.fromOffset(60,30);sub.Size=UDim2.new(1,-70,0,20);sub.TextColor3=muted
    end end
    if count==0 then row(self:tr('empty'),'ContactsEmpty',16,muted)end
    end
   elseif self.app=='contacts'then
    row(name(self.peer),'ContactTitle',24)
    button('ContactMessage',self:tr('write'),function()self.app='messages';self:render()end)
    button('ContactCall',self:tr('dial'),function()options.request({action='dial',target=self.peer})end,ui.palette.action)
   elseif self.app=='messages'then
    self.unread[self.peer]=0
    self.title.Text=self:tr('messages')
    for index,m in ipairs(self.conversations[self.peer]or{})do
     local mine=m.from==game:GetService('Players').LocalPlayer.UserId
     local wrap=make('Frame',self.content,{Name='MessageRow_'..m.id,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=index})
     local bubble=ui:label(wrap,'Message_'..m.id,m.text,16)
     bubble.AnchorPoint=Vector2.new(mine and 1 or 0,0);bubble.Position=UDim2.fromScale(mine and 1 or 0,0);bubble.Size=UDim2.new(.88,0,0,0);bubble.AutomaticSize=Enum.AutomaticSize.Y;bubble.TextWrapped=true;bubble.TextYAlignment=Enum.TextYAlignment.Top
     bubble.BackgroundTransparency=0;bubble.BackgroundColor3=mine and Color3.fromRGB(59,60,72)or Color3.fromRGB(36,37,44);round(bubble,6)
     make('UIPadding',bubble,{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,30),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
     local receipt=ui:label(bubble,(mine and'MessageReceipt_'or'MessageTime_')..m.id,mine and self:tr('sent')or os.date('%H:%M'),11)
     receipt.Position=UDim2.new(0,14,1,-22);receipt.Size=UDim2.new(1,-28,0,16);receipt.TextColor3=muted;receipt.TextXAlignment=Enum.TextXAlignment.Right
    end
    local peer=self.peer;self.messageDirty[peer]=nil
    local input=make('TextBox',self.composer,{Name='MessageInput',Size=UDim2.new(1,-56,1,0),BackgroundColor3=Color3.fromRGB(34,35,42),BorderSizePixel=0,Font=Enum.Font.BuilderSansMedium,TextSize=16,TextColor3=ink,PlaceholderColor3=muted,PlaceholderText=self:tr('input'),Text=self.drafts[peer]or'',ClearTextOnFocus=false,TextWrapped=true,MultiLine=false});round(input,10)
    make('UIPadding',input,{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,10)});input.TextXAlignment=Enum.TextXAlignment.Left
    self.editor=input;self.editorPeer=peer
    input:GetPropertyChangedSignal('Text'):Connect(function()self.drafts[peer]=input.Text end)
    local function send()
     if self.pending or not input.Parent or self.editor~=input or not self.visible or self.app~='messages'or self.peer~=peer then return end
     if self.lastMessageAttempt and self.lastMessageAttempt.peer==peer and self.lastMessageAttempt.text==input.Text and os.clock()-self.lastMessageAttempt.at<.35 then return end
     if input.Text:find('%S')then
     self.lastMessageAttempt={peer=peer,text=input.Text,at=os.clock()}
     self.messageSerial=(self.messageSerial or 0)+1;local key='phone:'..game:GetService('Players').LocalPlayer.UserId..':'..self.messageSerial
     self.drafts[peer]=input.Text;self.sentDraft={peer=peer,text=input.Text,id=key};options.request({action='message',target=peer,text=input.Text,messageKey=key})
    end end
    input.ReturnPressedFromOnScreenKeyboard:Connect(send)
    input.FocusLost:Connect(function(enter)
     self.drafts[peer]=input.Text;if enter then send()end
     task.defer(function()if self.visible and self.app=='messages'and self.peer==peer and self.editor==input and self.messageDirty[peer]then self:render()end end)
    end)
    local sendButton=self:button(self.composer,'SendMessage','↑',send);sendButton.Position=UDim2.new(1,-48,0,0);sendButton.Size=UDim2.new(0,48,1,0);sendButton.TextSize=26;sendButton.BackgroundColor3=ui.palette.action;sendButton.TextColor3=ui.palette.actionInk
   elseif self.app=='calls'then
    local c=self.call
    if c.phase=='idle'then row(self:tr('idlecall'),'CallEmpty',17,muted);button('ChooseCallContact',self:tr('contacts'),function()go('contacts')end)
    else
     local hero=make('Frame',self.content,{Name='CallHero',Size=UDim2.new(1,0,0,228),BackgroundTransparency=1})
     local face=avatar(hero,c.peer);face.AnchorPoint=Vector2.new(.5,0);face.Position=UDim2.new(.5,0,0,8);face.Size=UDim2.fromOffset(88,88);round(face,44)
     local person=ui:label(hero,'CallPeer',name(c.peer),25);person.Font=Enum.Font.BuilderSansBold;person.Position=UDim2.fromOffset(0,112);person.Size=UDim2.new(1,0,0,32);person.TextXAlignment=Enum.TextXAlignment.Center;person.TextTruncate=Enum.TextTruncate.AtEnd
     local mode=ui:label(hero,'CallMode',self:tr(c.phase=='ringing'and(c.incoming and'incoming'or'outgoing')or(c.voice and'voice'or c.voiceState=='connecting'and'voice_connecting'or'textcall')),14);mode.Position=UDim2.fromOffset(8,152);mode.Size=UDim2.new(1,-16,0,48);mode.TextWrapped=true;mode.TextColor3=muted;mode.TextXAlignment=Enum.TextXAlignment.Center
     local actions=make('Frame',self.content,{Name='CallActions',Size=UDim2.new(1,0,0,106),BackgroundTransparency=1})
     local function callAction(name,text,fn,primary)
      local b=self:button(actions,name,text,fn)
      if primary then b.BackgroundColor3=ui.palette.action;b.TextColor3=ui.palette.actionInk end
      return b
     end
     if c.phase=='ringing'and c.incoming then
      callAction('AnswerCall',self:tr('answer'),function()options.request({action='answer',id=c.id})end,true)
      callAction('DeclineCall',self:tr('decline'),function()options.request({action='answer',id=c.id,accept=false})end)
     else
      if c.phase=='active'then
       self.callLabel=self:label(hero,'CallDuration','00:00',30)
       callAction('CallMessages',self:tr('chatcall'),function()self.app='messages';self.peer=c.peer;self:render()end)
      end
      local finish=callAction('EndCall',self:tr('endcall'),function()options.request({action='end',id=c.id})end,true)
      if c.phase~='active'then finish.BackgroundColor3=Color3.fromRGB(87,54,55);finish.TextColor3=ink end
     end
    end
   elseif self.app=='notes'then
    row(self:tr('private'),'PrivateNoteInfo',14,muted)
    local n=make('TextBox',self.content,{Name='PrivateNote',Size=UDim2.new(1,0,0,self.shell.Size.Y.Offset<430 and 132 or 200),Text=self.note,PlaceholderText=self:tr('note'),ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.BuilderSansMedium,TextSize=17,TextColor3=ink,BackgroundColor3=Color3.fromRGB(34,35,42),BorderSizePixel=0});round(n,10)
    self.noteEditor=n;n:SetAttribute('SpyUserText',true)
    make('UIPadding',n,{PaddingTop=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
    local function edited()
     self.note=noteText(n.Text)
     if self.note~=n.Text then n.Text=self.note end
     if options.noteChanged then options.noteChanged()else self.noteDirty=true end
    end
    n:GetPropertyChangedSignal('Text'):Connect(edited);n.FocusLost:Connect(edited)
    self.noteStatusLabel=row(self:tr(self.noteStatus or'note_loading'),'NoteSaveStatus',13,brass)
    local save=self:button(self.content,'SaveNote',self:tr('note_save'),function()edited();if options.noteSave then options.noteSave()end end,true)
    save.BackgroundColor3=ui.palette.action;save.TextColor3=ui.palette.actionInk;save.Size=UDim2.new(1,0,0,44)
    local reload=self:button(self.content,'ReloadNote',self:tr('note_reload'),function()if options.noteReload then options.noteReload()end end,true);reload.Size=UDim2.new(1,0,0,44);reload.TextSize=14
    if options.noteLoad then options.noteLoad()end

    if self.options.inMatch then
     self.marks=self.marks or{}
     for _,p in ipairs(game:GetService('Players'):GetPlayers())do if p~=game:GetService('Players').LocalPlayer then
      button('Note_'..p.UserId,p.DisplayName..' · '..self:tr(({[0]='unknown',[1]='suspect',[2]='clear'})[self.marks[p.UserId]or 0]),function()
       self.note=noteText(n.Text);self.marks[p.UserId]=((self.marks[p.UserId]or 0)+1)%3;self:render()
      end)
     end end
    end
   elseif self.app=='timer'then
    self.timerLabel=row('00:00','TimerValue',48);self.timerLabel.Font=Enum.Font.BuilderSansBold;self.timerLabel.Size=UDim2.new(1,0,0,72);self.timerLabel.AutomaticSize=Enum.AutomaticSize.None
    button('TimerToggle',self:tr(self.timer.at and'stoptimer'or'starttimer'),function()if self.timer.at then self.timer.elapsed+=os.clock()-self.timer.at;self.timer.at=nil else self.timer.at=os.clock()end;self:render()end)
    button('TimerReset',self:tr('reset'),function()self.timer={elapsed=0};self:render()end)
   elseif self.app=='sound'then
    button('ToggleQuiet',self:tr(self.quiet and'quietoff'or'quieton'),function()self.quiet=not self.quiet;options.sound('quiet',self.quiet);self:render()end)
    row(self:tr('ringtone'),'RingtoneTitle',18)
    for _,key in ipairs({'soft','classic'})do button('Ringtone_'..key,(self.ringtone==key and'✓ 'or'')..self:tr(key=='soft'and'short'or'classic'),function()self.ringtone=key;options.sound('ringtone',key);self:render()end)end
    button('TestRingtone',self:tr('test'),function()options.sound('preview')end)
   end
  end
  self:resize();self:updateClock()
 end
 local hide=ui.hide
 function ui:hide()self.torch=false;self.flash=false;hide(self);notification.Visible=false;self:notice()end
 ui:render();return ui
end
return Social
