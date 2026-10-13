local controlThemeNode=script.Parent:FindFirstChild("UITheme")
local ControlTheme=controlThemeNode and require(controlThemeNode)
-- Shared personal controls. No purchase/economy controls are present here.
local UserInputService = game:GetService('UserInputService')
local Preferences = require(script.Parent.ClientPreferences)
local I18n = require(script.Parent.I18n)
local SettingsUI = {}
local COLORS = {bg=Color3.fromRGB(25,27,31), card=Color3.fromRGB(46,48,52), gold=Color3.fromRGB(221,193,151), text=Color3.fromRGB(244,240,231), muted=Color3.fromRGB(188,187,181)}
local COPY = {
 title={'Настройки','Settings'}, subtitle={'Настрой игру под себя','Make yourself comfortable'},
 language={'Язык интерфейса','Interface language'}, audio={'ЗВУК','AUDIO'}, musicVolume={'Музыка','Music'},
 sfxVolume={'Звуковые эффекты','Sound effects'}, comfort={'КАМЕРА И КОМФОРТ','CAMERA & COMFORT'},
 motionBlur={'Размытие движения','Motion blur'}, cameraMotion={'Движение камеры','Camera motion'},
 reducedMotion={'Меньше движения','Reduced motion'}, fov={'Поле зрения','Field of view'}, effects={'Частицы и свечение','Particles & glow'},
 note={'Меньше движения отключает размытие и движение камеры. Поле зрения применяется вне кинематографических сцен.',
 'Reduced motion disables blur and camera movement. Field of view applies outside cinematic scenes.'},
 on={'ВКЛ','ON'}, off={'ВЫКЛ','OFF'}, loading={'Подключаем профиль…','Connecting profile…'},
 saving={'Сохраняем…','Saving…'}, saved={'Сохранено автоматически','Saved automatically'},
 failed={'Не сохранено. Вернули подтверждённые настройки.','Not saved. Restored confirmed settings.'},
 retry={'ПОВТОРИТЬ','RETRY'}, guide={'КАК ИГРАТЬ','HOW TO PLAY'},
}
local function make(class,parent,props)
 local object=Instance.new(class)
 for key,value in pairs(props or {}) do object[key]=value end
 object.Parent=parent
 return object
end
local function round(node,radius) make('UICorner',node,{CornerRadius=UDim.new(0,radius or 10)}) end
local function text(parent,value,size,color)
 return make('TextLabel',parent,{BackgroundTransparency=1,Text=value,TextSize=size or 17,TextColor3=color or COLORS.text,Font=Enum.Font.BuilderSansMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,26)})
end
local function button(parent,value,callback)
 local b=make('TextButton',parent,{BackgroundColor3=COLORS.card,Text=value,TextColor3=COLORS.text,TextSize=17,Font=Enum.Font.BuilderSansBold,AutoButtonColor=true,BorderSizePixel=0,Size=UDim2.fromOffset(48,44)})
 round(b,12)
 if ControlTheme and ControlTheme.button then ControlTheme.button(b,false)end
 b.Activated:Connect(callback)
 return b
end
function SettingsUI.create(ctx)
 Preferences.start()
 local self={visible=false,name='settings',category='language'}
 local overlay=make('Frame',ctx.gui,{Name='settingsOverlay',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.65,Visible=false,Active=true,ZIndex=100})
 local modal=make('Frame',overlay,{Name='SettingsPanel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(600,600),BackgroundColor3=COLORS.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true,ZIndex=101})
 round(modal,20);modal.BackgroundTransparency=.16
 make('UIStroke',modal,{Color=COLORS.gold,Transparency=.72,Thickness=1})
 local title=text(modal,'',27); title.Position=UDim2.fromOffset(20,12); title.Size=UDim2.new(1,-88,0,36); title.ZIndex=102
 local subtitle=text(modal,'',12,COLORS.gold); subtitle.Position=UDim2.fromOffset(20,49); subtitle.Size=UDim2.new(1,-40,0,20); subtitle.ZIndex=102
 local close=button(modal,'×',function() self:close() end); close.Position=UDim2.new(1,-60,0,12); close.ZIndex=103; close.TextSize=26
 local surface=make('ScrollingFrame',modal,{Name='Controls',Position=UDim2.fromOffset(20,128),Size=UDim2.new(1,-40,1,-202),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollBarImageColor3=COLORS.gold,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=102})
 make('UIListLayout',surface,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
 make('UIPadding',surface,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,12)})
 local statusLabel=text(modal,'',13,COLORS.muted); statusLabel.Position=UDim2.new(0,20,1,-64); statusLabel.Size=UDim2.new(1,-142,0,52); statusLabel.ZIndex=103
 local retry=button(modal,'',function() Preferences.set('fov',Preferences.get().fov) end); retry.Position=UDim2.new(1,-120,1,-60); retry.Size=UDim2.fromOffset(100,44); retry.ZIndex=103
 self.modal,self.surface,self.title,self.hint=modal,surface,title,subtitle
 local renderedKey
 local tabs={}
 for index,key in ipairs({'language','audio','picture','controls'})do
  local b=button(modal,'',function() self.category=key;renderedKey=nil;surface.CanvasPosition=Vector2.new();self:update()end)
  b.Name='SettingsCategory_'..key;b.Position=UDim2.new((index-1)/4,16,0,78);b.Size=UDim2.new(1/4,-18,0,44);b.TextSize=13;b.ZIndex=103
  tabs[key]=b
 end
 local function tr(key)
  return I18n.text(Preferences.get().language,COPY[key][1])
 end
 local function fit()
  local size=ctx.gui.AbsoluteSize
  local desired=self.category=="audio"and 340 or self.category=="language"and 400 or 460
  modal.Size=UDim2.fromOffset(math.max(240,math.min(740,size.X-24)),math.max(180,math.min(desired,size.Y-28)))
  local short=modal.Size.Y.Offset<360
  self.rail=false
  subtitle.Visible=false
  title.Position=UDim2.fromOffset(20,12);title.TextSize=28;title.Font=Enum.Font.BuilderSansBold
  close.Position=UDim2.new(1,-64,0,12)
  for index,key in ipairs({'language','audio','picture','controls'})do
   local tab=tabs[key]
   local cell=(modal.Size.X.Offset-64)/4
   tab.Position=UDim2.fromOffset(20+(index-1)*(cell+8),64)
   tab.Size=UDim2.fromOffset(cell,44);tab.TextSize=size.X<500 and 13 or 16
  end
  local top=120
  surface.Position=UDim2.fromOffset(20,top)
  surface.Size=UDim2.new(1,-40,1,-top-36)
  statusLabel.Position=UDim2.new(0,20,1,-32);statusLabel.Size=UDim2.new(1,-150,0,26)
  retry.Position=UDim2.new(1,-120,1,-52)
 end
 local function section(key)
  local label=text(surface,tr(key),13,COLORS.gold); label.Size=UDim2.new(1,0,0,24)
 end
 local function row(key)
  local frame=make('Frame',surface,{Name=key,Size=UDim2.new(1,0,0,88),BackgroundColor3=COLORS.card,BorderSizePixel=0})
  round(frame,14)
  local label=text(frame,tr(key),17); label.Font=Enum.Font.BuilderSansBold;label.Position=UDim2.fromOffset(12,6); label.Size=UDim2.new(1,-24,0,30)
  return frame
 end
 local function controls(frame)
  return make('Frame',frame,{Name='Options',BackgroundTransparency=1,Position=UDim2.fromOffset(10,38),Size=UDim2.new(1,-20,0,44)})
 end
 local function enabled(b,ready)
  b.Active=ready; b.Selectable=ready; b.AutoButtonColor=ready
  b.TextTransparency=ready and 0 or .5
 end
 function self:render()
  if not self.visible then return end
  fit()
  local current=Preferences.get()
  local status,ready=Preferences.status()
  title.Text,subtitle.Text=tr('title'),tr('subtitle')
  local en=current.language=='en'
  local localeNames={ru={'Язык','Звук','Графика','Камера'},en={'Language','Audio','Graphics','Camera'},zh={'语言','声音','画面','镜头'}}
  local labels=localeNames[current.language]or localeNames.ru
  local names={language=labels[1],audio=labels[2],picture=labels[3],controls=labels[4]}
  for key,b in pairs(tabs)do b.Text=names[key];b.BackgroundColor3=key==self.category and COLORS.gold or COLORS.card;b.TextColor3=key==self.category and COLORS.bg or COLORS.text end
  statusLabel.Text=status=='saved'and ''or tr(status);statusLabel.Visible=status~='saved'; retry.Text=tr('retry'); retry.Visible=status=='failed'
  if status=='failed'then surface.Size=UDim2.new(1,-40,1,-180);statusLabel.Position=UDim2.new(0,20,1,-56);statusLabel.Size=UDim2.new(1,-150,0,48)end
  local key=table.concat({current.language,tostring(current.musicVolume),tostring(current.sfxVolume),tostring(current.motionBlur),tostring(current.cameraMotion),tostring(current.reducedMotion),tostring(current.fov),tostring(current.effects),tostring(ready),self.category},':')
  if key==renderedKey then return end
  renderedKey=key
  local scroll=surface.CanvasPosition
  for _,child in ipairs(surface:GetChildren()) do if child:IsA('GuiObject') then child:Destroy() end end
  local function numeric(key,min,max,step,format)
   local bar=controls(row(key))
   local minus=button(bar,'−',function() Preferences.set(key,math.clamp(math.round((Preferences.get()[key]-step)*100)/100,min,max)) end)
   local plus=button(bar,'+',function() Preferences.set(key,math.clamp(math.round((Preferences.get()[key]+step)*100)/100,min,max)) end)
   plus.Position=UDim2.new(1,-48,0,0)
   local value=text(bar,format(current[key]),21,COLORS.gold); value.Position=UDim2.fromOffset(56,0); value.Size=UDim2.new(1,-112,1,0); value.TextXAlignment=Enum.TextXAlignment.Center
   enabled(minus,ready and current[key]>min); enabled(plus,ready and current[key]<max)
  end
  local function toggle(key)
   local frame=row(key)
   local b=button(controls(frame),tr(current[key] and 'on' or 'off'),function() Preferences.set(key,not Preferences.get()[key]) end)
   b.Size=UDim2.fromScale(1,1)
   if current[key] then b.BackgroundColor3=COLORS.gold; b.TextColor3=COLORS.bg end
   enabled(b,ready)
  end
  if self.category=='language' then
   for _,entry in ipairs({{'ru','Русский'},{'en','English'},{'zh','简体中文'}})do
    local code,title=entry[1],entry[2]
    local b=button(surface,title,function()Preferences.set('language',code)end)
    b.Name='Language_'..code;b:SetAttribute('SpyLocalize',false)
    b.Size=UDim2.new(1,0,0,52);b.Font=Enum.Font.BuilderSansBold;b.TextSize=19
    b.TextXAlignment=Enum.TextXAlignment.Center
    if current.language==code then local mark=text(b,'✓',20,COLORS.gold);mark.Position=UDim2.new(1,-36,0,0);mark.Size=UDim2.fromOffset(28,52);b.BackgroundColor3=Color3.fromRGB(65,62,56)end
    enabled(b,ready)
   end

  elseif self.category=='audio' then
   numeric('musicVolume',0,1,.1,function(value) return tostring(math.round(value*100))..'%' end)
   numeric('sfxVolume',0,1,.1,function(value) return tostring(math.round(value*100))..'%' end)
  elseif self.category=='picture' then
   toggle('effects');toggle('motionBlur')
   numeric('fov',60,90,5,function(value)return tostring(math.round(value))..'°'end)
  else
   toggle('reducedMotion');toggle('cameraMotion')
   local note=text(surface,tr('note'),13,COLORS.muted);note.Size=UDim2.new(1,0,0,54)
   if ctx.make and ctx.L then
    local guide=button(surface,tr('guide'),function()self:close();require(script.Parent.GuideUI).open(ctx)end);guide.Size=UDim2.new(1,0,0,44)
   end
  end
  for _,node in ipairs(surface:GetDescendants()) do if node:IsA('GuiObject') then node.ZIndex=103 end end
  surface.CanvasPosition=scroll
 end
 function self:update() fit(); self:render() end
 function self:resize() self:update() end
 function self:open()
  if ctx.closeDialogue then ctx.closeDialogue() end
  if ctx.closePanels then ctx.closePanels('settings') end
  self.visible=true; overlay.Visible=true
  if ctx.setActivePanel then ctx.setActivePanel('settings') end
  self:update()
 end
 function self:close()
  self.visible=false; overlay.Visible=false
  if ctx.getActivePanel and ctx.getActivePanel()=='settings' and ctx.setActivePanel then ctx.setActivePanel(nil) end
 end
 local changeConnection=Preferences.Changed:Connect(function() self:render() end)
 local resizeConnection=ctx.gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:update()end)
 local inputConnection=UserInputService.InputBegan:Connect(function(input,processed)
  if not processed and input.KeyCode==Enum.KeyCode.Escape and self.visible then self:close() end
 end)
 overlay.Destroying:Connect(function()
  changeConnection:Disconnect(); resizeConnection:Disconnect(); inputConnection:Disconnect()
 end)
 return self
end
return SettingsUI

