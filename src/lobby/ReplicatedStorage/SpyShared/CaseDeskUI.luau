-- One line of conversation and a deliberate choice. Match evidence stays private.
local UI={};UI.__index=UI
local C={bg=Color3.fromRGB(25,27,31),ink=Color3.fromRGB(244,240,231),muted=Color3.fromRGB(188,187,181),line=Color3.fromRGB(87,89,93),accent=Color3.fromRGB(221,193,151)}
local function make(class,parent,props)local n=Instance.new(class);for k,v in pairs(props)do n[k]=v end;n.Parent=parent;return n end
local function label(parent,name,value,size,color)
 local n=make('TextLabel',parent,{Name=name,Text=value or'',TextSize=size or 18,Font=Enum.Font.BuilderSansMedium,TextColor3=color or C.ink,BackgroundTransparency=1,
  Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=42})
 n:SetAttribute('SpyUserText',true);return n
end
local function canSelect(n)
 if not n or not n.Parent or not n:IsA('GuiObject')or not n.Selectable or not n.Active then return false end
 local current=n
 while current do
  if current:IsA('GuiObject')and not current.Visible then return false end
  if current:IsA('ScreenGui')then return current.Enabled end
  current=current.Parent
 end
 return false
end
function UI.new(parent,files,language,send,displayOrder)
 local self=setmetatable({files=files,language=language,send=send,connections={},busy=false,page='brief',choiceCount=0},UI)
 self.gui=make('ScreenGui',parent,{Name='SpyCaseDesk',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=displayOrder or 82,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 pcall(function()self.gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
 self.window=make('Frame',self.gui,{Name='CaseDeskWindow',AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-12),Size=UDim2.fromOffset(1024,270),BackgroundColor3=C.bg,BackgroundTransparency=.16,BorderSizePixel=0,Visible=false,ZIndex=40})
 make('UICorner',self.window,{CornerRadius=UDim.new(0,18)})
 make('Frame',self.window,{Name='DialogueRule',Size=UDim2.new(1,0,0,1),BackgroundColor3=C.accent,BackgroundTransparency=.3,BorderSizePixel=0,ZIndex=41})
 self.title=label(self.window,'DeskTitle','',15,C.muted);self.title.AutomaticSize=Enum.AutomaticSize.None;self.title.TextWrapped=false;self.title.TextTruncate=Enum.TextTruncate.AtEnd;self.title.Size=UDim2.new(1,-80,0,26)
 self.speaker=label(self.window,'DialogueSpeaker','',18,C.accent);self.speaker.Font=Enum.Font.BuilderSansBold;self.speaker.AutomaticSize=Enum.AutomaticSize.None;self.speaker.Size=UDim2.new(1,-40,0,28)
 self.status=label(self.window,'DeskStatus','',13,C.muted);self.status.AutomaticSize=Enum.AutomaticSize.None;self.status.TextWrapped=false;self.status.TextTruncate=Enum.TextTruncate.AtEnd;self.status.Size=UDim2.new(1,-40,0,20)
 self.body=make('ScrollingFrame',self.window,{Name='DialogueText',BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.accent,ClipsDescendants=true,ZIndex=41})
 self.scroll=self.body
 self.choices=make('ScrollingFrame',self.window,{Name='DialogueChoices',BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.accent,ClipsDescendants=true,ZIndex=41})
 self.closeButton=make('TextButton',self.window,{Name='DeskClose',Text='×',Font=Enum.Font.BuilderSansMedium,TextSize=28,TextColor3=C.ink,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(44,44),Position=UDim2.new(1,-52,0,6),ZIndex=44})
 self.closeButton.Activated:Connect(function()self:close()end)
 self.cut=make('Frame',self.gui,{Name='ConversationCut',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=60})
 local shared=game:GetService('ReplicatedStorage'):FindFirstChild('SpyShared');local mod=shared and shared:FindFirstChild('CaseScene')
 if mod then local ok,Scene=pcall(require,mod);if ok then
  local built,value=pcall(Scene.new,{onStop=function()self:close()end});if built then self.scene=value end
 end end
 self.connections[#self.connections+1]=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()self:watchCamera();self:resize()end)
 self.connections[#self.connections+1]=self.gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:resize()end)
 self.connections[#self.connections+1]=self.gui:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()self:resize()end)
 self:watchCamera();self:resize();return self
end
function UI:watchCamera()
 if self.viewportConnection then self.viewportConnection:Disconnect();self.viewportConnection=nil end
 local camera=workspace.CurrentCamera
 if camera then self.viewportConnection=camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()self:resize()end)end
end
function UI:resize()
 local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
 local top,bottom=Vector2.zero,Vector2.zero;pcall(function()top,bottom=game:GetService('GuiService'):GetGuiInset()end)
 local usable=self.gui.AbsoluteSize;local insetY=self.gui.AbsolutePosition.Y
 if usable.X<=0 or usable.Y<=0 then usable=Vector2.new(viewport.X-top.X-bottom.X,viewport.Y-top.Y-bottom.Y);insetY=top.Y end
 local available=math.max(1,usable.Y-24);local w=math.max(1,math.min(1040,usable.X-24));local wide=w>=680 or available<350
 local h=math.min(available,wide and 268 or 320);self.window.Size=UDim2.fromOffset(w,h)
 self.title.Position=UDim2.fromOffset(20,12);self.speaker.Position=UDim2.fromOffset(20,44)
 if wide then
  local split=math.floor(w*.57)
  self.body.Position=UDim2.fromOffset(20,80);self.body.Size=UDim2.fromOffset(math.max(44,split-38),math.max(44,h-116))
  self.choices.Position=UDim2.fromOffset(split+8,54);self.choices.Size=UDim2.fromOffset(math.max(44,w-split-28),math.max(44,h-68))
  self.status.Position=UDim2.fromOffset(20,h-28);self.status.Size=UDim2.fromOffset(math.max(44,split-38),20)
 else
  local bh=math.max(44,math.min(90,math.floor(h*.25)))
  self.body.Position=UDim2.fromOffset(20,78);self.body.Size=UDim2.fromOffset(w-40,bh)
  self.status.Position=UDim2.fromOffset(20,82+bh);self.status.Size=UDim2.fromOffset(w-40,20)
  self.choices.Position=UDim2.fromOffset(16,108+bh);self.choices.Size=UDim2.fromOffset(w-32,math.max(44,h-120-bh))
 end
 if self.scene then
  self.scene.space=available-h
  self.scene.insetY=insetY
  if self.scene.space<96 and self.scene.active then self.scene:stop(false)end
  if self.window.Visible and self.cinematicWanted and self.scene.space>=96 and not self.scene.active then
   local ok,err=pcall(function()self.scene:start()end);if not ok then warn('[SpyCaseCamera] '..tostring(err));self.scene:stop(false)end
  end
 end
 if self.scene and self.scene.active then self.window.BackgroundTransparency=.08 else self.window.BackgroundTransparency=0 end
end
function UI:tr(key)return self.files.text(self.language(),key)end
function UI:say(name,content,speaker)
 self.speaker.Text=speaker or self:tr('vincent');return label(self.body,name,content,18)
end
function UI:choose(name,caption,callback,locked)
 self.choiceCount+=1
 local b=make('TextButton',self.choices,{Name=name,Text=string.format('%02d   %s',self.choiceCount,caption),TextSize=16,Font=Enum.Font.BuilderSansMedium,TextColor3=locked and C.muted or C.ink,
  BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,-8,0,48),TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutoButtonColor=false,Selectable=true,ZIndex=43})
 b:SetAttribute('SpyUserText',true);b:SetAttribute('SpyActionLocked',locked==true)
 make('UIPadding',b,{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,10)})
 make('Frame',b,{Name='ReplyDivider',Position=UDim2.new(0,8,1,-1),Size=UDim2.new(1,-16,0,1),BorderSizePixel=0,BackgroundColor3=C.line,BackgroundTransparency=.3,ZIndex=43})
 b.MouseEnter:Connect(function()if not locked and not self.busy then b.TextColor3=C.accent end end)
 b.MouseLeave:Connect(function()b.TextColor3=locked and C.muted or C.ink end)
 b.Activated:Connect(function()if not self.busy and not b:GetAttribute('SpyActionLocked')then callback()end end)
 return b
end
function UI:go(page,id)
 self.page=page;self.selectedSource=page=='evidence'and id or nil;self.selectedSuspect=(page=='testimony'or page=='confirm')and id or nil
 self.body.CanvasPosition=Vector2.zero;self.choices.CanvasPosition=Vector2.zero;self:render()
end
function UI:setBusy(value)
 self.busy=value==true
 for _,b in ipairs(self.choices:GetChildren())do if b:IsA('TextButton')then b.Active=not self.busy and not b:GetAttribute('SpyActionLocked')end end
 self.closeButton.Active=true
end
function UI:show(data)
 if not self.window.Visible then self.previousSelection=game:GetService('GuiService').SelectedObject end
 self.cutSerial=(self.cutSerial or 0)+1;local serial=self.cutSerial
 self.cut.Visible=true;self.cut.BackgroundTransparency=0
 self.cinematicWanted=not data or data.kind~='meeting'
 self.window.Visible=true;game:GetService('Players').LocalPlayer:SetAttribute('SpyCasePanelOpen',true)
 self:setData(data or self.data or{kind='archive'})
 if self.scene and self.data.kind~='meeting'then
  local ok,err=pcall(function()self.scene:start()end);if not ok then warn('[SpyCaseCamera] '..tostring(err));self.scene:stop(false)end
 end
 self:resize()
 local ok=pcall(function()
  if self.cutTween then self.cutTween:Cancel()end
  self.cutTween=game:GetService('TweenService'):Create(self.cut,TweenInfo.new(.28,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{BackgroundTransparency=1});self.cutTween:Play()
 end)
 if not ok then self.cut.Visible=false end
 task.delay(.35,function()if self.cutSerial==serial then self.cut.Visible=false end end)
end
function UI:close()
 self.cutSerial=(self.cutSerial or 0)+1;self.cut.Visible=false
 if self.cutTween then pcall(function()self.cutTween:Cancel()end)end
 self.cinematicWanted=false
 self.window.Visible=false;game:GetService('Players').LocalPlayer:SetAttribute('SpyCasePanelOpen',false)
 if self.scene then self.scene:stop(false)end
 local gs=game:GetService('GuiService');local selected=gs.SelectedObject
 if selected and selected:IsDescendantOf(self.gui)then
  gs.SelectedObject=canSelect(self.previousSelection)and self.previousSelection or nil
 end
 self.previousSelection=nil
 if self.onClose then self.onClose()end
end
function UI:setData(data)
 if type(data)~='table'then return end
 local key=(data.kind or'archive')..':'..tostring(data.token or'')..':'..tostring(data.file and data.file.id or'')
 if key~=self.presentationKey then self.presentationKey=key;self.page='brief';self.selectedSuspect=nil;self.selectedSource=nil;self.presentedFinished=false end
 if data.finished and not self.presentedFinished then self.page='result' end
 self.presentedFinished=data.finished==true;self.data=data
 if data.kind=='meeting'then self.cinematicWanted=false;if self.scene then self.scene:stop(false)end end
 self:render()
end
function UI:render()
 local data=self.data;if not data then return end
 local gs=game:GetService('GuiService');local selected=gs.SelectedObject
 local retainFocus=selected and selected:IsDescendantOf(self.gui)
 if retainFocus then gs.SelectedObject=nil end
 for _,n in ipairs(self.body:GetChildren())do n:Destroy()end;for _,n in ipairs(self.choices:GetChildren())do n:Destroy()end
 make('UIListLayout',self.body,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
 make('UIListLayout',self.choices,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
 self.choiceCount=0;self.body.CanvasPosition=Vector2.zero;self.choices.CanvasPosition=Vector2.zero
 local function tr(k)return self:tr(k)end;local file=data.file or{};local page=self.page
 self.title.Text=data.kind=='training'and tr('training')or data.kind=='meeting'and tr('clues')or file.title or tr('archive')
 self.status.Text=data.finished and tr('saved')or data.kind=='training'and tr('tutorial_note')or data.kind=='case'and tr('solo_note')or''
 local function send(name,caption,payload,locked)return self:choose(name,caption,function()self.send(payload)end,locked)end
 local function back(target)self:choose('DialogueBack',tr('back'),function()self:go(target)end)end
 local function clueMenu()
  self:say('CluesPrompt',tr('ask_evidence'))
  for _,source in ipairs(file.sources or{})do self:choose('Inspect_'..source.id,(data.evidence and data.evidence[source.id]and'✓  'or'')..source.label,function()
   self:go('evidence',source.id)
   if not data.finished and not(data.evidence and data.evidence[source.id])then self.send({action='inspect',token=data.token,source=source.id})end
  end)end
  back(data.finished and'result'or'brief')
 end
 if data.kind=='archive'or not data.kind then
  self:say('ArchiveIntro',tr('vincent_welcome'))
  for _,id in ipairs(self.files.Ids)do local done=data.progress and data.progress.completed and data.progress.completed[id]
   send('Start_'..id,(done and'✓  'or'')..self.files.public(id,self.language()).title,{action='start',id=id})
  end
  send('Training',tr('training'),{action='training'})
 elseif data.kind=='training'then
  local training=data.training or{};self:say(data.finished and'CaseReview'or'TrainingBrief',data.finished and(data.explanation or'')or(training.brief or''))
  self.status.Text=data.finished and tr('saved')or tostring(training.step or 1)..' / '..tostring(training.total or 5)..' · '..tr('tutorial_note')
  if not data.finished then for _,choice in ipairs(training.choices or{})do send('Answer_'..choice.id,choice.label,{action='answer',token=data.token,choice=choice.id})end end
  send('ArchiveBack',tr('return_cases'),{action='progress'})
 elseif data.kind=='meeting'then
  self.speaker.Text=tr('notes')
  label(self.body,'CaseBrief',file.brief or'',16,C.muted)
  label(self.body,'PrivateAlibi',data.alibi or'',18);label(self.body,'PrivateSecret',data.secret or'',16,C.muted);label(self.body,'YourGoal',data.goal or'',16,C.accent)
  label(self.body,'CodeOrder',tr('code_order'),14,C.muted)
  if data.evidence then label(self.body,'PrivateEvidence',data.evidence,18);label(self.body,'CodeFragment',tr('code_pair')..' '..tostring(data.fragmentIndex or'?')..' / '..tostring(data.fragmentCount or 3)..' · '..tr(data.source or'clues')..' '..tostring(data.fragment or'—'),18,C.accent)end
  if data.canInspect then for _,source in ipairs(file.sources or{})do send('Inspect_'..source.id,source.label,{action='inspect',token=data.token,source=source.id})end end
  if data.canNominate then for _,p in ipairs(file.suspects or{})do if p.id~=data.selfId then send('Nominate_'..p.id,(data.nomination==p.id and'✓  'or'')..p.name,{action='nominate',token=data.token,target=p.id})end end end
  if data.finished then label(self.body,'CaseReview',data.explanation or'',18,C.accent)end
 else
  local ready=data.evidence and data.evidence.tape and data.evidence.phone and data.evidence.folder
  if page=='result'then
   self:say('CaseReview',data.explanation or'')
   self:choose('RevisitClues',tr('review_evidence'),function()self:go('clues')end)
   send('ArchiveBack',tr('return_cases'),{action='progress'})
  elseif page=='clues'then clueMenu()
  elseif page=='evidence'then
   local id=self.selectedSource;self:say('FocusedEvidence_'..tostring(id),data.evidence and data.evidence[id]or tr('unexamined'),tr(id or'clues'))
   back('clues')
   if not data.finished and not(data.evidence and data.evidence[id])then send('RetryInspect',tr('inspect_action'),{action='inspect',token=data.token,source=id})end
  elseif page=='interviews'then
   self:say('InterviewsPrompt',tr('ask_testimony'))
   for _,p in ipairs(file.suspects or{})do self:choose('Interview_'..p.id,p.name,function()self:go('testimony',p.id)end)end
   back('brief')
  elseif page=='testimony'or page=='confirm'then
   local person;for _,p in ipairs(file.suspects or{})do if p.id==self.selectedSuspect then person=p end end
   if person then
    self:say('Statement_'..person.id,person.statement,tr('testimony_record')..' · '..person.name)
    if page=='confirm'then
     label(self.body,'ConfirmQuestion',tr('confirm_accusation'),16,C.accent)
     send('Solve_'..person.id,tr('accuse')..' · '..person.name,{action='solve',token=data.token,suspect=person.id},not ready)
     back('accusation')
    else back('interviews')end
   else self.page='brief' end
  elseif page=='accusation'then
   self:say('AccusationPrompt',tr(ready and'choose_accused'or'inspect_first'))
   for _,p in ipairs(file.suspects or{})do self:choose('ChooseAccused_'..p.id,p.name,function()self:go('confirm',p.id)end,not ready)end
   back('brief')
  else
   self:say('CaseBrief',file.brief or'')
   self:choose('OpenClues',tr('question_evidence'),function()self:go('clues')end)
   self:choose('OpenInterviews',tr('question_testimony'),function()self:go('interviews')end)
   self:choose('OpenAccusation',tr('question_accuse'),function()self:go('accusation')end)
   local count=0;for _,id in ipairs({'tape','phone','folder'})do if data.evidence and data.evidence[id]then count+=1 end end
   self.status.Text=tr('clue_progress')..' · '..count..' / 3'
  end
 end
 for _,parent in ipairs({self.body,self.choices})do local i=0;for _,n in ipairs(parent:GetChildren())do if n:IsA('GuiObject')then i+=1;n.LayoutOrder=i end end end
 self:setBusy(self.busy)
 if self.window.Visible then
  local ok,last=pcall(function()return game:GetService('UserInputService'):GetLastInputType()end)
  if retainFocus or(ok and string.match(last.Name,'^Gamepad'))then
   local first
   for _,b in ipairs(self.choices:GetChildren())do if b:IsA('TextButton')and b.Active then first=b;break end end
   gs.SelectedObject=first or self.closeButton
  end
 end
 if self.scene then self.scene:focus(page=='testimony'or page=='confirm'or data.kind=='training')end
 self:resize()
end
function UI:error(code)self.status.Text=self:tr(code or'unavailable')end
function UI:destroy()
 self:close();if self.viewportConnection then self.viewportConnection:Disconnect()end
 for _,c in ipairs(self.connections)do c:Disconnect()end
 if self.scene then self.scene:destroy()end;self.gui:Destroy()
end
return UI
