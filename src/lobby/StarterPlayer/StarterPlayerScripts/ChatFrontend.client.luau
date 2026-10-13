-- One presentation using Roblox TextChannels for sending and delivery.
-- Display only final engine-filtered messages, never an optimistic raw echo.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local TextChatService=game:GetService("TextChatService")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui",10)
if not pg then return end
local function tr(ru,en)return player:GetAttribute("SpyLanguage")=="en" and en or ru end
local inMatch=false
local stateAttribute=inMatch and "SpyMatchChatState" or "SpyLobbyChatState"
local defaultChannelName=inMatch and "SpyMatchGlobal" or "SpyLobbyGlobal"
local clientId=game:GetService("HttpService"):GenerateGUID(false)
local function stateName() return stateAttribute end
local function detailName() return inMatch and "SpyMatchChatDetail" or "SpyLobbyChatDetail" end
local function tableId() return not inMatch and tostring(player:GetAttribute("SpyRelayTableId") or "") or "" end
local function channelName()
 local seated=tableId()
 if seated~="" then return "Spy_"..seated end
 local selected=Storage:GetAttribute("SpyChatChannelName")
 if selected=="RBXGeneral" or selected==defaultChannelName then return selected end
 return defaultChannelName
end
-- Discover the exact server-selected channel or authoritative table membership.
local function resolve()
 local folder=TextChatService:FindFirstChild("TextChannels")
 if not folder then return nil end
 local selected=folder:FindFirstChild(channelName())
 return selected and selected:IsA("TextChannel") and selected or nil
end
-- UserId is marked NotReplicated by the engine API; the server mirrors only
-- the identity returned by AddUserAsync. Permission remains engine-owned.
local function sourceUserId(source)
 if not source then return nil end
 local id=source.UserId
 if type(id)=="number" and id~=0 then return id end
 return source:GetAttribute("SpyChatUserId")
end
local function localSource(target)
 if not target then return nil end
 for _,candidate in ipairs(target:GetChildren()) do
  if candidate:IsA("TextSource") and sourceUserId(candidate)==player.UserId then return candidate end
 end
end
local function matchPhaseAllows()
 if not inMatch then
  if tableId()=="" then return true end
  local phase=player:GetAttribute("SpyRelayTablePhase")
  return phase=="Waiting" or phase=="Discuss" or phase=="Result"
   or (phase=="Hint" and player:GetAttribute("SpyRelayTableTurn")==player.UserId)
 end
 if player:GetAttribute("SpySessionAccepted")~=true then return false end
 local session=Storage:FindFirstChild("MatchSession")
 if not session then return false end
 local phase=session:GetAttribute("RoundPhase")
 return phase=="Discuss" or (phase=="Hint" and session:GetAttribute("CurrentTurnUserId")==player.UserId)
end
local gui=Instance.new("ScreenGui");gui.Name="SpyChatFrontend";gui.ResetOnSpawn=false;gui.DisplayOrder=82;gui.IgnoreGuiInset=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=pg
local function make(class,parent,props)
 local n=Instance.new(class);for k,v in pairs(props) do n[k]=v end;n.Parent=parent;return n
end
local foreground=Color3.fromRGB(235,235,235)
local button=make("TextButton",gui,{Name="OpenChat",Position=UDim2.fromOffset(116,12),Size=UDim2.fromOffset(44,44),Text="",TextSize=16,Font=Enum.Font.BuilderSansBold,BackgroundColor3=Color3.fromRGB(27,29,33),TextColor3=foreground,BorderSizePixel=0})
make("UICorner",button,{CornerRadius=UDim.new(0,16)})
local chatGlyph=make("Frame",button,{Position=UDim2.fromOffset(11,11),Size=UDim2.fromOffset(20,15),BackgroundTransparency=1,BorderSizePixel=0})
make("UICorner",chatGlyph,{CornerRadius=UDim.new(0,4)})
make("UIStroke",chatGlyph,{Color=foreground,Thickness=1.5})
make("Frame",chatGlyph,{Position=UDim2.fromOffset(5,5),Size=UDim2.fromOffset(10,2),BackgroundColor3=foreground,BorderSizePixel=0})
make("Frame",chatGlyph,{Position=UDim2.fromOffset(5,9),Size=UDim2.fromOffset(7,2),BackgroundColor3=foreground,BorderSizePixel=0})
make("Frame",chatGlyph,{Position=UDim2.fromOffset(4,13),Size=UDim2.fromOffset(2,6),Rotation=30,BackgroundColor3=foreground,BorderSizePixel=0})
local panel=make("Frame",gui,{Name="ChatPanel",Position=UDim2.fromOffset(16,64),Size=UDim2.new(.36,0,0,270),BackgroundColor3=Color3.fromRGB(32,32,32),BackgroundTransparency=.3,BorderSizePixel=0,Visible=false})
make("UISizeConstraint",panel,{MinSize=Vector2.new(180,96),MaxSize=Vector2.new(420,280)})
make("UICorner",panel,{CornerRadius=UDim.new(0,5)})
make("UIStroke",panel,{Color=foreground,Transparency=.9})
local title=make("TextLabel",panel,{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-54,0,26),BackgroundTransparency=1,Text=tr("Чат","Chat"),TextSize=16,Font=Enum.Font.BuilderSansBold,TextColor3=foreground,TextXAlignment=Enum.TextXAlignment.Left})
local close=make("TextButton",panel,{Name="Close",Position=UDim2.new(1,-48,0,4),Size=UDim2.fromOffset(44,44),Text="×",BackgroundTransparency=1,TextColor3=foreground,TextSize=22})
local log=make("ScrollingFrame",panel,{Position=UDim2.fromOffset(12,40),Size=UDim2.new(1,-24,1,-132),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
log.Name="ChatLog";log:SetAttribute("SpyUserText",true)
local layout=make("UIListLayout",log,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local status=make("TextLabel",panel,{Position=UDim2.new(0,12,1,-82),Size=UDim2.new(1,-110,0,32),BackgroundTransparency=1,Text="",TextWrapped=true,TextSize=13,Font=Enum.Font.BuilderSans,TextColor3=Color3.fromRGB(200,200,200),TextXAlignment=Enum.TextXAlignment.Left})
local retry=make("TextButton",panel,{Name="ChatRetry",Position=UDim2.new(1,-96,1,-78),Size=UDim2.fromOffset(84,44),BackgroundTransparency=.3,BackgroundColor3=Color3.fromRGB(55,57,60),BorderSizePixel=0,Text=tr("Повторить","Retry"),Font=Enum.Font.BuilderSans,TextSize=13,TextColor3=foreground})
make("UICorner",retry,{CornerRadius=UDim.new(0,5)})
local box=make("TextBox",panel,{Position=UDim2.new(0,12,1,-52),Size=UDim2.new(1,-72,0,44),BackgroundColor3=Color3.fromRGB(60,60,60),BorderSizePixel=0,Text="",ClearTextOnFocus=false,PlaceholderText=tr("Сообщение…","Message…"),TextSize=14,Font=Enum.Font.BuilderSans,TextColor3=Color3.fromRGB(235,235,235),TextXAlignment=Enum.TextXAlignment.Left})
make("UICorner",box,{CornerRadius=UDim.new(0,6)})
make("UIPadding",box,{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)})
local send=make("TextButton",panel,{Name="ChatSend",Position=UDim2.new(1,-56,1,-52),Size=UDim2.fromOffset(44,44),BackgroundColor3=Color3.fromRGB(80,80,80),BorderSizePixel=0,Text="→",TextSize=18,TextColor3=Color3.fromRGB(235,235,235)})
make("UICorner",send,{CornerRadius=UDim.new(0,6)})
-- Layout follows the actual safe canvas and the keyboard; transport stays unchanged.
local function fitChat()
 local camera=workspace.CurrentCamera;local view=gui.AbsoluteSize
 if view.X<=0 or view.Y<=0 then view=camera and camera.ViewportSize or Vector2.new(800,600)end
 local available=view.Y
 if Input.OnScreenKeyboardVisible then
  local inset=GuiService:GetGuiInset();local key=Input.OnScreenKeyboardPosition
  if key.Y>0 then available=math.min(available,key.Y-inset.Y)
  else available=math.max(0,available-Input.OnScreenKeyboardSize.Y)end
 end
 local height=math.min(280,math.max(96,available-16));local top=math.max(0,math.min(60,available-height-8))
 panel.Position=UDim2.fromOffset(12,top);panel.Size=UDim2.fromOffset(math.min(420,math.max(180,view.X-24)),height)
 local compact=height<160
 title.Visible=not compact;status.Visible=not compact
 close.Position=UDim2.new(1,-48,0,4)
 log.Position=UDim2.fromOffset(12,52);log.Size=UDim2.new(1,-24,0,math.max(0,height-156));log.Visible=height>=176
 status.Position=UDim2.new(0,12,1,-100);status.Size=UDim2.new(1,retry.Visible and -116 or -24,0,44)
 retry.Position=compact and UDim2.fromOffset(12,4)or UDim2.new(1,-96,1,-100)
 button.Position=Input.TouchEnabled and UDim2.fromOffset(12,8)or UDim2.fromOffset(116,12)
 button.Visible=not Input.OnScreenKeyboardVisible
end
for _,property in ipairs({"OnScreenKeyboardVisible","OnScreenKeyboardPosition","OnScreenKeyboardSize"})do Input:GetPropertyChangedSignal(property):Connect(fitChat)end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitChat)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitChat)end
fitChat()
local pending=nil
local sequence=0
local last=-1000
local notice=nil
local connectionGeneration=0
local function allowed()
 local target=resolve()
 -- Server relay is the active transport; TextChannel presence is optional.
 -- Server-side filtering and delivery remain authoritative.
 return player:GetAttribute("SpyAdminMuted")~=true and matchPhaseAllows(),target
end
                                local function presentationHidden()
 if GuiService.MenuIsOpen then return true end
 -- Keep the custom chat button available in the lobby even during the
 -- entrance presentation. Match-specific presentation rules stay intact.
 if not inMatch then return false end
 if player:GetAttribute("SpySessionAccepted")~=true then return true end
 local session=Storage:FindFirstChild("MatchSession")
 local phase=session and session:GetAttribute("RoundPhase")
 return phase=="Intro" or phase=="Role"
end
local retrying=false
local lastClientState=nil
local function update()
 title.Text=tr("Чат","Chat");retry.Text=tr("Повторить","Retry");box.PlaceholderText=tr("Сообщение…","Message…")
 -- Global chat: table membership does not change the chat scope.
          gui.Enabled=not presentationHidden()
 box.Visible=true;send.Visible=true
 if not gui.Enabled then box:ReleaseFocus() end
 local state=tostring(player:GetAttribute(stateName()) or "connecting")
 local canSend,target=allowed()
 local source=localSource(target)
 if canSend then retrying=false end
 box.TextEditable=canSend and pending==nil;send.Active=box.TextEditable;send.AutoButtonColor=send.Active
 local clientState=canSend and "server_filtered"
  or player:GetAttribute("SpyAdminMuted")==true and "admin_muted"
  or not matchPhaseAllows() and "phase" or not target and "no_channel" or state
 if clientState~=lastClientState then
  lastClientState=clientState
  player:SetAttribute("SpyChatClientState",clientState)
  print("[SPY CHAT] "..channelName().." client="..clientState.." server="..state.." detail="..tostring(player:GetAttribute(detailName()) or ""))
 end
 if pending then status.Text=tr("Roblox проверяет сообщение…","Roblox is checking the message…")
 elseif notice then status.Text=notice
 elseif player:GetAttribute("SpyAdminMuted")==true then status.Text=tr("Администратор отключил твой чат.","An admin disabled your chat.")
 elseif not matchPhaseAllows() then status.Text=tr("Чат доступен в обсуждении и в свой ход подсказки.","Chat opens during discussion and your hint turn.")
 elseif canSend then status.Text=tr("/ — открыть · Enter — отправить","/ to open · Enter to send")
 elseif state=="blocked" then status.Text=tr("Канал пока не готов. Нажми «Повторить».","Channel is not ready yet. Press Retry.")
 elseif state=="failed" then status.Text=tr("Не удалось подключить канал. Нажми «Повторить».","Could not connect the channel. Press Retry.")
 elseif retrying then status.Text=tr("Повторное подключение…","Reconnecting…")
 else status.Text=tr("Подключение к Roblox…","Connecting to Roblox…") end
 retry.Visible=not canSend or notice~=nil
 retry.Active=pending==nil
 fitChat()
end
local function connectionDeadline()
 connectionGeneration+=1;local token=connectionGeneration
 task.delay(12,function()
  if token~=connectionGeneration or pending then return end
  retrying=false
  if allowed() then update();return end
  local state=player:GetAttribute(stateName())
  if state==nil or state=="connecting" or (state=="ready" and (not resolve() or not localSource(resolve()))) then
   notice=resolve() and tr("Нет доступа к каналу. Нажми «Повторить».","Channel access is missing. Press Retry.") or tr("Нет канала чата. Нажми «Повторить».","Server chat channel is missing. Press Retry.")
   update()
  end
 end)
end
local function failureDetail(status)
 if status==Enum.TextChatMessageStatus.InvalidPrivacySettings then return tr("Roblox отклонил отправку: доступ к чату ограничен.","Roblox denied sending: chat access is restricted.") end
 if status==Enum.TextChatMessageStatus.InvalidTextChannelPermissions then return tr("Нет доступа к каналу. Нажми «Повторить».","No channel access. Press Retry.") end
 if status==Enum.TextChatMessageStatus.Floodchecked then return tr("Слишком быстро. Подожди перед следующей отправкой.","Please wait before sending another message.") end
 if status==Enum.TextChatMessageStatus.TextFilterFailed then return tr("Roblox не смог проверить сообщение [F03]. Текст сохранён.","Roblox could not filter the message [F03]. Your draft is saved.") end
 if status==Enum.TextChatMessageStatus.ModerationTimeout then return tr("Проверка Roblox заняла слишком много времени [F04]. Текст сохранён.","Roblox moderation timed out [F04]. Your draft is saved.") end
 if status==Enum.TextChatMessageStatus.MessageTooLong then return tr("Сообщение слишком длинное. Текст сохранён.","The message is too long. Your draft is saved.") end
 return tr("Roblox не разрешил отправку. Текст сохранён.","Roblox denied sending. Your draft is saved.")
end
local function diagnostic(result,stage,reason,metadata)
 local safeMeta=tostring(metadata or "")
 if #safeMeta>180 then safeMeta=safeMeta:sub(1,180) end
 player:SetAttribute("SpyChatLastSendStatus",result)
 player:SetAttribute("SpyChatLastSendStage",stage)
 player:SetAttribute("SpyChatLastSendReason",reason or "")
 player:SetAttribute("SpyChatLastSendMetadata",safeMeta)
 print("[SPY CHAT SEND] channel="..channelName().." result="..result.." stage="..stage.." reason="..(reason or "none").." metadata="..(safeMeta~="" and safeMeta or "none"))
end
local function responseDetail(response)
 local statusName=response and response.Status and response.Status.Name or "transport_error"
 local metadata=response and tostring(response.Metadata or "") or ""
 if #metadata>120 then metadata=metadata:sub(1,120) end
 return statusName,metadata
end
local function transportReason(value)
 -- Engine exceptions may contain a draft. Never print or store them.
 local detail=type(value)=="string" and string.lower(value) or ""
 if string.find(detail,"timeout",1,true) or string.find(detail,"timed out",1,true) then return "service_timeout" end
 if string.find(detail,"privacy",1,true) or string.find(detail,"permission",1,true) then return "permission_error" end
 return "service_error"
end
local function finish(request,success,detail)
 if pending~=request then return end
 pending=nil
 if success then
  -- A delayed acknowledgement must never erase text typed after submission.
  if not request.preserveDraft and box.Text==request.text then box.Text="" end
  notice=nil
 else notice=detail or tr("Roblox не разрешил отправку.","Roblox denied sending.") end
 update()
end
local presets={
 hello={"Привет!","Hello!"},ready={"Я готов.","I'm ready."},wait={"Подожди.","Please wait."},
 join={"Присоединяйся!","Join us!"},back={"Я вернулся.","I'm back."},thanks={"Спасибо!","Thank you!"},
}
local function submit(presetId)
 local preset=presetId and type(presetId)=="string" and presets[presetId] or nil
 if presetId~=nil and not preset then return end
 if pending or os.clock()-last<.8 then update();return end
 if player:GetAttribute("SpyAdminMuted")==true or not matchPhaseAllows() then update();return end
 local text=preset and tr(preset[1],preset[2]) or box.Text;local length=utf8.len(text)
 if not length or length<1 or length>180 or not text:match("%S") then status.Text=tr("Сообщение: от 1 до 180 символов","Message: 1–180 characters");return end
 local relay=Storage:FindFirstChild("SpyChatRelay")
 if not relay or not relay:IsA("RemoteEvent") then
  notice=tr("Серверный чат ещё не готов [R00].","Server chat is not ready yet [R00].");update();return
 end
 sequence+=1
 local id=clientId..":"..sequence
 local request={text=text,preserveDraft=preset~=nil,id=id}
 pending=request;notice=nil;last=os.clock();update()
 diagnostic("Sending","server_filtered")
 relay:FireServer({id=id,text=text})
 task.delay(10,function()
  if pending==request then
   diagnostic("local_timeout","server_filtered","relay_timeout")
   finish(request,false,tr("Сервер чата не ответил [R01]. Текст сохранён.","Chat server did not respond [R01]. Your draft is saved."))
  end
 end)
end
send.Activated:Connect(function()submit()end)
box.FocusLost:Connect(function(enter) if enter then submit() end end)
box.ReturnPressedFromOnScreenKeyboard:Connect(function()submit()end)
local presetEvent=pg:FindFirstChild("SpyChatPreset")
if not presetEvent then
 presetEvent=Instance.new("BindableEvent");presetEvent.Name="SpyChatPreset";presetEvent.Parent=pg
end
if presetEvent:IsA("BindableEvent") then presetEvent.Event:Connect(function(id)
 if type(id)=="string" and presets[id] then submit(id) end
end) end
button.Activated:Connect(function() panel.Visible=not panel.Visible;update() end)
local openChat=pg:FindFirstChild("SpyOpenChat")
if not openChat then openChat=Instance.new("BindableEvent");openChat.Name="SpyOpenChat";openChat.Parent=pg end
if openChat:IsA("BindableEvent")then openChat.Event:Connect(function()
 if presentationHidden()then return end
 panel.Visible=true;update()
 task.defer(function()if panel.Visible and gui.Enabled and box.TextEditable then box:CaptureFocus()end end)
end)end

close.Activated:Connect(function() panel.Visible=false;box:ReleaseFocus() end)
local lastRetry=-1000
retry.Activated:Connect(function()
 if pending or os.clock()-lastRetry<5 then return end
 local folder=Storage:FindFirstChild(inMatch and "MatchRemotes" or "SpyShared")
 local action=folder and folder:FindFirstChild("Action")
 if action and action:IsA("RemoteEvent") then
  lastRetry=os.clock();action:FireServer("ChatRetry")
  retrying=true;notice=nil
  connectionDeadline()
 else notice=tr("Подключение ещё не готово. Попробуй позже.","Connection is not ready yet. Try again later.") end
 update()
end)
local function permissionChanged() notice=nil;retrying=false;update() end
player:GetAttributeChangedSignal(stateAttribute):Connect(permissionChanged)
player:GetAttributeChangedSignal("SpyRelayTableId"):Connect(permissionChanged)
player:GetAttributeChangedSignal("SpyRelayTablePhase"):Connect(permissionChanged)
player:GetAttributeChangedSignal("SpyRelayTableTurn"):Connect(permissionChanged)
player:GetAttributeChangedSignal("SpyAdminMuted"):Connect(permissionChanged)
player:GetAttributeChangedSignal("SpyChatEligibility"):Connect(permissionChanged)
Storage:GetAttributeChangedSignal("SpyChatTransport"):Connect(permissionChanged)
Storage:GetAttributeChangedSignal("SpyChatChannelName"):Connect(permissionChanged)
player:GetAttributeChangedSignal("SpyLanguage"):Connect(update)
player:GetAttributeChangedSignal("SpySessionAccepted"):Connect(permissionChanged)
player:GetAttributeChangedSignal("SpyEntryPending"):Connect(update)
player:GetAttributeChangedSignal("SpyEntryActive"):Connect(update)
GuiService.MenuOpened:Connect(update)
GuiService.MenuClosed:Connect(update)
-- Membership and configuration can replicate after this optional script starts.
-- Event-driven observation needs no yielding boot loop or alternate transport.
local observed=setmetatable({},{__mode="k"})
local function observe(instance)
 if observed[instance] then return end
 if instance.Name=="TextChannels" or instance:IsA("TextChannel") then
  observed[instance]=true
  instance.ChildAdded:Connect(function(child) observe(child);permissionChanged() end)
  instance.ChildRemoved:Connect(permissionChanged)
  for _,child in ipairs(instance:GetChildren()) do observe(child) end
 elseif instance:IsA("TextSource") then
  observed[instance]=true
  instance:GetPropertyChangedSignal("CanSend"):Connect(permissionChanged)
  instance:GetAttributeChangedSignal("SpyChatUserId"):Connect(permissionChanged)
 end
end
TextChatService.ChildAdded:Connect(function(child) observe(child);permissionChanged() end)
TextChatService.ChildRemoved:Connect(permissionChanged)
local folder=TextChatService:FindFirstChild("TextChannels")
if folder then observe(folder) end
local function observeSession(session)
 if not inMatch or session.Name~="MatchSession" or observed[session] then return end
 observed[session]=true
 for _,attribute in ipairs({"RoundPhase","CurrentTurnUserId"}) do
  session:GetAttributeChangedSignal(attribute):Connect(permissionChanged)
 end
 permissionChanged()
end
Storage.ChildAdded:Connect(observeSession)
Storage.ChildRemoved:Connect(function(child) if child.Name=="MatchSession" then permissionChanged() end end)
local session=Storage:FindFirstChild("MatchSession")
if session then observeSession(session) end
local rows,seen={},{}
local rowNumber=0
local function append(id,fromId,name,text)
 if seen[id] then return false end;seen[id]=true
 rowNumber+=1
 local sender=Players:GetPlayerByUserId(fromId)
 local line=make("TextLabel",log,{Size=UDim2.new(1,-6,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Text=(sender and sender.DisplayName or name or tr("Игрок","Player"))..": "..text,TextWrapped=true,RichText=false,TextSize=15,Font=Enum.Font.BuilderSans,TextColor3=Color3.fromRGB(235,235,235),TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=rowNumber})
 table.insert(rows,{line=line,id=id})
 while #rows>60 do local old=table.remove(rows,1);old.line:Destroy();seen[old.id]=nil end
 line:SetAttribute("SpyUserText",true)
 task.defer(function() log.CanvasPosition=Vector2.new(0,math.max(0,layout.AbsoluteContentSize.Y-log.AbsoluteSize.Y)) end)
 return true
end

local function showRelayBubble(fromUserId,text)
 local speaker=Players:GetPlayerByUserId(tonumber(fromUserId) or 0)
 local character=speaker and speaker.Character
 if not character then return end
 local target=character:FindFirstChild("Head") or character
 local bubbleConfig=TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
 if bubbleConfig then bubbleConfig.Enabled=true end
 local ok,err=pcall(function()
  TextChatService:DisplayBubble(target,text)
 end)
 if not ok then warn("[SPY CHAT BUBBLE] "..tostring(err)) end
end
local hookedRelay=nil
local function hookRelay(relay)
 if hookedRelay==relay or not relay or not relay:IsA("RemoteEvent") then return end
 hookedRelay=relay
 relay.OnClientEvent:Connect(function(payload)
  if type(payload)~="table" then return end
  local id=tostring(payload.id or "")
  if payload.kind=="status" then
   if pending and id==pending.id then
    local code=tostring(payload.code or "server_error")
    if payload.ok==true then diagnostic("Success","server_filtered","ok");finish(pending,true)
    else
     diagnostic("Failed","server_filtered",code)
     local detail=code=="chat_disabled" and tr("Roblox не разрешает этому аккаунту общаться в чате.","Roblox does not allow this account to use chat.")
      or code=="empty_filtered" and tr("Roblox вернул пустой текст после фильтра для получателей. Проверь региональное ограничение чата в Communication.","Roblox returned empty filtered text for recipients. Check the regional chat restriction in Communication.")
      or code=="rate_limited" and tr("Слишком быстро. Подожди немного.","Please wait before sending again.")
      or code=="blocked" and tr("Сейчас отправлять сообщения нельзя.","You cannot send messages right now.")
      or code=="filter_failed" and tr("Roblox не смог проверить сообщение. Текст сохранён.","Roblox could not filter the message. Your draft is saved.")
      or tr("Сообщение не отправлено: ","Message was not sent: ")..code
     finish(pending,false,detail)
    end
   end
   return
  end
  if payload.kind~="message" or type(payload.text)~="string" or not payload.text:match("%S") then return end
  local fromUserId=tonumber(payload.fromUserId) or 0
  append("relay:"..tostring(fromUserId)..":"..id,fromUserId,tostring(payload.name or ""),payload.text)
  showRelayBubble(fromUserId,payload.text)
 end)
end
hookRelay(Storage:FindFirstChild("SpyChatRelay"))
Storage.ChildAdded:Connect(function(child) if child.Name=="SpyChatRelay" then hookRelay(child) end end)

TextChatService.MessageReceived:Connect(function(message)
 -- The custom server-filtered relay owns presentation. Never mix native chat
 -- echoes into this UI; they can be empty when Roblox blocks TextChannel chat.
 if Storage:GetAttribute("SpyChatTransport")=="server_filtered" then return end
 local selected=resolve()
 if not selected or message.TextChannel~=selected or not message.TextSource then return end
 if message.Status~=Enum.TextChatMessageStatus.Success then return end
 local id=tostring(message.MessageId or "")
 if id~="" and type(message.Text)=="string" and message.Text:match("%S") then
  append(id,sourceUserId(message.TextSource) or 0,nil,message.Text)
 end
end)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    Input.InputBegan:Connect(function(key,processed)
 if not processed and key.KeyCode==Enum.KeyCode.Slash and gui.Enabled
  and not Input:GetFocusedTextBox() then
  panel.Visible=true;update()
  if box.TextEditable then task.defer(function()
   if gui.Enabled and panel.Visible and box.Visible and box.TextEditable
    and not Input:GetFocusedTextBox() then box:CaptureFocus() end
  end) end
 end
 if panel.Visible and not processed and key.KeyCode==Enum.KeyCode.Escape then panel.Visible=false;box:ReleaseFocus() end
end)
update()
connectionDeadline()
