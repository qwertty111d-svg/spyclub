-- New phone activities. Existing shop/profile/trade controllers remain outside this device.
local Apps={}
local ink=Color3.fromRGB(230,231,218);local muted=Color3.fromRGB(154,170,165);local accent=Color3.fromRGB(195,172,118)
local function make(class,root,p)local n=Instance.new(class);for k,v in pairs(p)do n[k]=v end;n.Parent=root;return n end
function Apps.attach(ui,files,options)
 local oldTr=ui.tr;ui.ops={phase='idle'};ui.wheels={0,0,0};ui.marks={}
 function ui:tr(key)local text=files.text(self.options.language(),key);return text~=key and text or oldTr(self,key)end
 local function go(key)ui.app=key;ui:render();if not ui.options.inMatch then options.request({action='snapshot'})end end
 function ui:setOperations(d)
  if self.ops.token~=d.token then self.wheels={0,0,0};self.restart=nil end
  self.ops=d;self:render()
 end
 function ui:operation(p)
  p.token=p.token or self.ops.token;options.request(p)
 end
 local function text(value,name,size,color)local n=ui:paragraph(value,name,size);n.TextColor3=color or ink;return n end
 local function button(name,key,fn)local b=ui:button(ui.content,name,ui:tr(key),fn);b.Size=UDim2.new(1,-4,0,48);return b end
 local function contact(id,completed)
  local file=files.story(id,ui.options.language())
  local b=ui:button(ui.content,'Dial_'..id,file.contact..'\n'..file.title..(completed and '  ✓'or''),function()
   if ui.ops.phase~='idle'and ui.ops.phase~='done'and not ui.restart then ui.restart=id;ui:render();return end
   ui.restart=nil;ui:operation({action='dial',id=id,reset=true})
  end);b.Size=UDim2.new(1,-4,0,72)
 end
 function ui:mission()
  local d=self.ops;local phase=d.phase
  if phase=='idle'then text(self:tr('no_mission'),'MissionEmpty',16);return end
  text(d.file.contact,'CallContact',14,accent);text(d.file.title,'MissionTitle',22)
  if phase=='call'then
   text(d.call.text,'CallTranscript',18)
   for _,key in ipairs(d.call.step==1 and{'listen','hurry'}or{'accept','decline'})do button('CallChoice_'..key,key,function()self:operation({action='choice',choice=key})end)end
  elseif phase=='search'then
   text(d.file.location,'FindLocation',17);button('MissionCamera','open_camera',function()go('mission_camera')end)
  elseif phase=='cipher'then
   text(d.file.target,'CapturedTarget',16)
   button('MissionDecoder','open_decoder',function()go('decoder')end)
  elseif phase=='decision'then self:decision()
  elseif phase=='done'then
   text(self:tr('done'),'MissionDone',20,accent);text(d.ending,'MissionEnding',17);text(self:tr('recorded'),'Recorded',14,muted)
  end
 end
 function ui:decision()
  local d=self.ops;text(d.message,'DecodedMessage',18)
  for _,key in ipairs(d.choices or{})do button('Decision_'..key,key,function()self:operation({action='resolve',choice=key})end)end
 end
 function ui:preview(id)
  local set=workspace:FindFirstChild('SpyClub');set=set and set:FindFirstChild('SpyPhoneEvidenceSet')
  local original=set and set:FindFirstChild(id);if not original or not original.PrimaryPart then return end
  local view=make('ViewportFrame',self.content,{Name='EvidencePreview',Size=UDim2.new(1,-4,0,152),BackgroundColor3=Color3.fromRGB(29,35,33),BorderSizePixel=0,Ambient=Color3.fromRGB(157,161,150),LightColor=Color3.fromRGB(255,230,195),LightDirection=Vector3.new(-1,-1,-1)})
  local ok=pcall(function()
   local model=original:Clone();model.Parent=view
   local camera=Instance.new('Camera');local origin=model.PrimaryPart.Position;camera.CFrame=CFrame.lookAt(origin+Vector3.new(2.5,2.7,3),origin);camera.FieldOfView=35;camera.Parent=view;view.CurrentCamera=camera
  end)
  if not ok then view:Destroy()end
 end
 function ui:render()
  if self.app=='cases'then self.app='line'end
  self.content:ClearAllChildren();self.grid=nil;self.content.CanvasPosition=Vector2.zero
  self.close.Text=self:tr('close');self.back.Visible=self.app~='home';self.title.Text=self:tr(self.app)
  self.clock.Text=os.date('%H:%M');self.status.Text=self.pending and self:tr('loading')or''
  make('UIListLayout',self.content,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
  if self.app=='home'then
   for _,key in ipairs(self.options.inMatch and{'notes'}or{'line','camera','decoder','evidence'})do
    local captions={line='dial',camera='aim',decoder='cipher_rule',evidence='empty',notes='local_notes'}
    local b=self:button(self.content,'App_'..key,'',function()go(key)end);b.Size=UDim2.new(1,-4,0,90)
    self:icon(b,key,accent)
    -- The app icon occupies the left edge; captions use the full readable width beside it.
    local icon=b:FindFirstChild('Icon_'..key);if icon then icon.Position=UDim2.fromOffset(8,18)end
    local title=self:label(b,'AppCaption',self:tr(key),19);title.Font=Enum.Font.BuilderSansBold;title.Position=UDim2.fromOffset(68,10);title.Size=UDim2.new(1,-78,0,25)
    local caption=self:label(b,'AppDetail',self:tr(captions[key]),12);caption.TextColor3=muted;caption.TextWrapped=true;caption.Position=UDim2.fromOffset(68,37);caption.Size=UDim2.new(1,-78,0,46)
   end
  elseif self.app=='notes'then
   text(self:tr('local_notes'),'NotesHelp',14,muted)
   for _,p in ipairs(game:GetService('Players'):GetPlayers())do if p~=game:GetService('Players').LocalPlayer then
    local name='Note_'..p.UserId;local b=self:button(self.content,name,p.DisplayName..'\n'..self:tr(self.marks[p.UserId]and'suspect'or'clear'),function()self.marks[p.UserId]=not self.marks[p.UserId];self:render()end);b.Size=UDim2.new(1,-4,0,64)
   end end
  elseif self.options.inMatch then text(self:tr('blocked'),'MatchBlocked',16)
  elseif self.app=='line'then
   if self.restart then
    text(self:tr('confirm_restart'),'ConfirmRestart',17)
    button('ConfirmDial','continue',function()local id=self.restart;self.restart=nil;self:operation({action='dial',id=id,reset=true})end)
    button('CancelDial','cancel',function()self.restart=nil;self:render()end)
   else
    if self.ops.phase~='idle'then self:mission()end
    for _,id in ipairs(files.Ids)do contact(id,(self.ops.completed or{})[id])end
    text(self:tr('session'),'SessionScope',12,muted)
   end
  elseif self.app=='mission_camera'then
   local d=self.ops
   if d.phase=='search'then text(d.file.location,'CameraLocation',17);button('StartScanner','open_camera',function()options.scan(d)end)
   elseif d.captured then text(d.file.target,'PhotoTarget',18);self:preview(d.id);button('PhotoDecoder','open_decoder',function()go('decoder')end)
   else text(self:tr('no_mission'),'CameraEmpty',16)end
  elseif self.app=='decoder'then
   local d=self.ops
   if d.phase=='decision'then self:decision()
   elseif d.phase=='done'then self:mission()
   elseif d.transmission then
    local transmission=d.transmission
    text(self:tr('transmission')..'  '..table.concat(transmission.digits,' · '),'CipherTransmission',24,accent)
    text(self:tr('key')..'  '..transmission.shift,'CipherKey',18);text(self:tr('cipher_rule'),'CipherRule',15,muted)
    local row=make('Frame',self.content,{Name='CipherWheels',Size=UDim2.new(1,-4,0,152),BackgroundTransparency=1})
    for i=1,3 do
     local column=make('Frame',row,{Position=UDim2.new((i-1)/3,0,0,0),Size=UDim2.new(1/3,-6,1,0),BackgroundTransparency=1})
     local number
     local up=self:button(column,'WheelUp_'..i,'+',function()self.wheels[i]=(self.wheels[i]+1)%10;number.Text=tostring(self.wheels[i])end);up.Size=UDim2.new(1,0,0,44)
     number=self:label(column,'WheelValue_'..i,tostring(self.wheels[i]),30);number.TextXAlignment=Enum.TextXAlignment.Center;number.Position=UDim2.fromOffset(0,50);number.Size=UDim2.new(1,0,0,46)
     local down=self:button(column,'WheelDown_'..i,'−',function()self.wheels[i]=(self.wheels[i]-1)%10;number.Text=tostring(self.wheels[i])end);down.Position=UDim2.fromOffset(0,104);down.Size=UDim2.new(1,0,0,44)
    end
    button('CheckCipher','check',function()self:operation({action='decode',digits=table.clone(self.wheels)})end)
   else text(self:tr('no_photo'),'DecoderEmpty',16)end
  elseif self.app=='evidence'then
   local d=self.ops
   if not d.captured then text(self:tr('empty'),'EvidenceEmpty',16)else
    text(d.file.title,'EvidenceTitle',20);self:preview(d.id);text(self:tr('preview'),'PreviewCaption',12,muted)
    text(d.file.target,'EvidenceObject',16);text(self:tr('transmission')..'  '..table.concat(d.transmission.digits,' · '),'EvidenceTransmission',20,accent);text(self:tr('key')..'  '..d.transmission.shift,'EvidenceKey',16)
    if d.message then text(d.message,'EvidenceMessage',16)end
   end
  end
  if not self.options.inMatch and self.app~='home'then button('RefreshOperation','retry',function()options.request({action='snapshot'})end)end
 end
 -- Four distinct geometric icons, consistent with the actual hardware.
 local oldIcon=ui.icon
 function ui:icon(root,key,color)
  if key~='line'and key~='camera'and key~='decoder'and key~='evidence'and key~='notes'then return oldIcon(self,root,key,color)end
  local p=make('Frame',root,{Name='Icon_'..key,Size=UDim2.fromOffset(48,48),BackgroundTransparency=1})
  local function line(x,y,w,h,rotation)make('Frame',p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color,BorderSizePixel=0,Rotation=rotation or 0})end
  local function box(x,y,w,h,round)
   local b=make('Frame',p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0});make('UIStroke',b,{Color=color,Thickness=2});if round then make('UICorner',b,{CornerRadius=UDim.new(1,0)})end;return b
  end
  if key=='camera'then box(6,14,36,26);box(17,19,14,14,true);line(13,9,12,4)
  elseif key=='line'then line(11,12,4,23,24);line(12,11,10,5,24);line(22,31,12,5,24);box(28,11,5,5,true);box(36,18,5,5,true)
  elseif key=='decoder'then for i=0,2 do box(6+i*14,10,10,28);line(9+i*14,18,4,2);line(9+i*14,28,4,2)end
  else box(10,8,28,34);line(16,17,16,2);line(16,24,12,2);line(16,31,15,2)end
 end
 ui:render();return ui
end
return Apps
