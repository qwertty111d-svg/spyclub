-- Live club plan and one local destination beacon. No camera takeover or screen overlay.
local Navigator={};Navigator.__index=Navigator
local words={
 navigator={'Навигатор','Navigator','导航'},nav_hint={'Выбери место на плане или в списке.','Pick a place on the plan or in the list.','在地图或列表中选择地点。'},
 nav_go={'Показать в клубе','Show in the club','在俱乐部中标记'},nav_stop={'Убрать отметку','Clear marker','清除标记'},nav_you={'Ты здесь','You are here','你在这里'},
 nav_refresh={'Обновить план','Refresh plan','刷新地图'},nav_empty={'План ещё загружается.','The club plan is loading.','俱乐部地图正在加载。'},nav_match={'Навигатор доступен в лобби.','Navigator is available in the lobby.','导航仅在大厅中可用。'},
 nav_cases={'Кейсы','Cases','宝箱'},nav_atelier={'Ателье','Atelier','发型店'},nav_vincent={'Винсент','Vincent','文森特'},nav_reward={'Награда','Reward','奖励'},
 nav_pool={'Бильярд','Billiards','台球'},nav_checkers={'Шашки','Checkers','跳棋'},nav_feedback={'Связь с разработчиком','Developer feedback','开发者反馈'},nav_distance={'студ.','studs','格'},
}
local specs={
 {id='atelier',label='nav_atelier',names={'AtelierPromptAnchor','AtelierCase'}},
 {id='cases',label='nav_cases',names={'ClassicCase'}},
 {id='vincent',label='nav_vincent',names={'VincentTalkPoint'}},
 {id='reward',label='nav_reward',names={'DailyEnvelope','DailyTop'}},
 {id='pool',label='nav_pool',names={'ClubBilliards'}},
 {id='checkers',label='nav_checkers',names={'SpyCheckers'}},
 {id='feedback',label='nav_feedback',names={'FeedbackDesk'},prompt='FeedbackBook'},
}
local function make(cl,parent,p)local n=Instance.new(cl);for k,v in pairs(p)do n[k]=v end;n.Parent=parent;return n end
local ink=Color3.fromRGB(237,235,224);local muted=Color3.fromRGB(158,176,166);local green=Color3.fromRGB(117,185,145)
function Navigator.resolve(root)
 local results={}
 for _,spec in ipairs(specs)do
  local object
  if spec.prompt then local p=root:FindFirstChild(spec.prompt,true);object=p and p.Parent end
  for _,name in ipairs(spec.names)do if object then break end;object=root:FindFirstChild(name,true)end
  if object then
   local part=object:IsA('BasePart')and object or object:IsA('Model')and object.PrimaryPart or object:FindFirstChildWhichIsA('BasePart',true)
   if part then results[#results+1]={id=spec.id,label=spec.label,part=part,position=part.Position}end
  end
 end
 return results
end
function Navigator.new(ui,options)
 local self=setmetatable({ui=ui,options=options,elapsed=0,entries={},dots={}},Navigator)
 local oldRender,oldTr=ui.render,ui.tr
 function ui:tr(key)local w=words[key];return w and w[self.options.language()=='en'and 2 or self.options.language()=='zh'and 3 or 1]or oldTr(self,key)end
 function ui:render()
  oldRender(self)
  if self.app=='navigator'then
   self.content:ClearAllChildren();self.grid=nil
   make('UIListLayout',self.content,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
   self.title.Text=self:tr('navigator')
   if self.options.inMatch then self:paragraph(self:tr('nav_match'),'NavigatorUnavailable');return end
   self:paragraph(self:tr('nav_hint'),'NavigatorHint',14)
   self.navigator:render()
  end
 end
 ui.navigator=self
 self.connection=game:GetService('RunService').Heartbeat:Connect(function(dt)
  self.elapsed+=dt;if self.elapsed<.25 then return end;self.elapsed=0;self:update()
 end)
 self.characterConnection=game:GetService('Players').LocalPlayer.CharacterRemoving:Connect(function()self:clear()end)
 return self
end
function Navigator:root()
 local p=game:GetService('Players').LocalPlayer
 return p.Character and p.Character:FindFirstChild('HumanoidRootPart')
end
function Navigator:clear()
 self.active=nil;if self.beacon then self.beacon:Destroy();self.beacon=nil end
end
function Navigator:select(entry)
 self.selected=entry.id;self.ui:render()
end
function Navigator:show(entry)
 self:clear();self.active=entry
 local gui=make('BillboardGui',self.ui.gui.Parent,{Name='PhoneDestination',Adornee=entry.part,Size=UDim2.fromOffset(150,52),StudsOffsetWorldSpace=Vector3.new(0,2.1,0),AlwaysOnTop=true,LightInfluence=0,MaxDistance=140})
 local dot=make('TextLabel',gui,{Name='DestinationPin',Text='◇',TextSize=25,Font=Enum.Font.BuilderSansBold,TextColor3=green,BackgroundTransparency=1,Size=UDim2.new(1,0,0,26)})
 self.beacon=gui;self.caption=make('TextLabel',gui,{Name='DestinationDistance',Text='',TextSize=13,Font=Enum.Font.BuilderSansBold,TextColor3=ink,BackgroundColor3=Color3.fromRGB(22,32,29),BackgroundTransparency=.15,BorderSizePixel=0,Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,0,24)})
 self:update();self.options.close()
end
function Navigator:update()
 if self.options.inMatch or self.ui.options.blocked()then self:clear();return end
 local root=self:root()
 if self.active then
  local entry=self.active
  if not root or not entry.part.Parent then self:clear();return end
  local delta=entry.part.Position-root.Position;local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
  if distance<5 then self:clear();return end
  self.caption.Text=self.ui:tr(entry.label)..' · '..math.floor(distance+.5)..' '..self.ui:tr('nav_distance')
 end
 if self.ui.visible and self.ui.app=='navigator'and self.map and self.map.Parent and root then
  local x,z=root.Position.X,root.Position.Z
  self.you.Position=UDim2.fromScale(math.clamp((x-self.minX)/self.width,.04,.96),math.clamp((z-self.minZ)/self.depth,.04,.96))
  self.you.Rotation=-math.deg(math.atan2(root.CFrame.LookVector.X,-root.CFrame.LookVector.Z))
  for _,d in ipairs(self.dots)do
   if d.entry.part.Parent then local delta=d.entry.part.Position-root.Position;d.button.Text=self.ui:tr(d.entry.label)..'  ·  '..math.floor(Vector3.new(delta.X,0,delta.Z).Magnitude+.5)..' '..self.ui:tr('nav_distance')end
  end
 end
end
function Navigator:render()
 local ui=self.ui;self.entries=Navigator.resolve(workspace);self.dots={};self.map=nil
 if #self.entries==0 then ui:paragraph(ui:tr('nav_empty'),'NavigatorEmpty',15);ui:button(ui.content,'NavigatorRefresh',ui:tr('nav_refresh'),function()ui:render()end);return end
 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for _,e in ipairs(self.entries)do minX=math.min(minX,e.position.X);maxX=math.max(maxX,e.position.X);minZ=math.min(minZ,e.position.Z);maxZ=math.max(maxZ,e.position.Z)end
 self.minX,self.minZ=minX-6,minZ-6;self.width,self.depth=math.max(24,maxX-minX+12),math.max(24,maxZ-minZ+12)
 local map=make('Frame',ui.content,{Name='ClubPlan',Size=UDim2.new(1,0,0,174),BackgroundColor3=Color3.fromRGB(23,35,32),BorderSizePixel=0,ClipsDescendants=true})
 make('UICorner',map,{CornerRadius=UDim.new(0,10)});make('UIStroke',map,{Color=Color3.fromRGB(66,90,79),Thickness=1});self.map=map
 for i=1,4 do make('Frame',map,{Size=UDim2.new(1,0,0,1),Position=UDim2.fromScale(0,i/5),BackgroundColor3=Color3.fromRGB(49,66,59),BackgroundTransparency=.6,BorderSizePixel=0})end
 local selected
 for i,e in ipairs(self.entries)do
  local dot=ui:button(map,'MapPlace_'..e.id,tostring(i),function()self:select(e)end,true)
  dot.AnchorPoint=Vector2.new(.5,.5);dot.Size=UDim2.fromOffset(32,32);dot.Position=UDim2.fromScale((e.position.X-self.minX)/self.width,(e.position.Z-self.minZ)/self.depth)
  dot.TextSize=14;dot.BackgroundColor3=self.selected==e.id and Color3.fromRGB(57,105,77)or Color3.fromRGB(48,66,58)
  if self.selected==e.id then selected=e end
 end
 self.you=make('TextLabel',map,{Name='PlayerOnPlan',Text='▲',Font=Enum.Font.BuilderSansBold,TextSize=20,TextColor3=green,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(24,24),ZIndex=3})
 local legend=ui:paragraph('▲  '..ui:tr('nav_you'),'NavigatorLegend',13);legend.TextColor3=muted
 if selected then
  local b=ui:button(ui.content,'NavigatorGo',ui:tr('nav_go')..' · '..ui:tr(selected.label),function()self:show(selected)end);b.BackgroundColor3=Color3.fromRGB(48,95,69)
 end
 if self.active then ui:button(ui.content,'NavigatorClear',ui:tr('nav_stop'),function()self:clear();ui:render()end)end
 for i,e in ipairs(self.entries)do
  local b=ui:button(ui.content,'Navigate_'..e.id,tostring(i)..'  '..ui:tr(e.label),function()self:select(e)end)
  b.Size=UDim2.new(1,0,0,44);b.TextSize=15;self.dots[#self.dots+1]={entry=e,button=b}
 end
 self:update()
end
function Navigator:destroy()
 self:clear();self.connection:Disconnect();self.characterConnection:Disconnect()
end
return Navigator
