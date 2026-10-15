-- Shared personal controls. No purchase/economy controls are present here.
local UserInputService = game:GetService('UserInputService')
local Preferences = require(script.Parent.ClientPreferences)
local I18n = require(script.Parent.I18n)
local SettingsUI = {}
local COLORS = {bg=Color3.fromRGB(26,27,31), card=Color3.fromRGB(49,50,56), white=Color3.fromRGB(238,238,241), text=Color3.fromRGB(245,245,247), muted=Color3.fromRGB(168,170,179), line=Color3.fromRGB(100,102,110)}
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
local function round(node,radius) make('UICorner',node,{CornerRadius=UDim.new(0,radius or 2)}) end
local function text(parent,value,size,color)
 return make('TextLabel',parent,{BackgroundTransparency=1,Text=value,TextSize=size or 16,TextColor3=color or COLORS.text,Font=Enum.Font.BuilderSansMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,26),ZIndex=103})
end
local function button(parent,value,callback)
 local b=make('TextButton',parent,{BackgroundColor3=COLORS.card,BackgroundTransparency=.4,Text=value,TextColor3=COLORS.text,TextSize=16,Font=Enum.Font.BuilderSansMedium,AutoButtonColor=true,BorderSizePixel=0,Size=UDim2.fromOffset(48,44),ZIndex=103})
 round(b,2)
 b.Activated:Connect(callback)
 return b
end
function SettingsUI.create(ctx)
 Preferences.start()
 local self={visible=false,name='settings',category='language'}
 local overlay=make('Frame',ctx.gui,{Name='settingsOverlay',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(16,17,20),BackgroundTransparency=.78,Visible=false,Active=true,ZIndex=100})
 local modal=make('Frame',overlay,{Name='SettingsPanel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(740,430),BackgroundColor3=COLORS.bg,BackgroundTransparency=.16,BorderSizePixel=0,ClipsDescendants=true,Active=true,ZIndex=101})
 round(modal,3)
 make('UIStroke',modal,{Color=COLORS.line,Transparency=.74,Thickness=1})
 local title=text(modal,'',42);title.Name='SettingsHeading';title.Font=Enum.Font.Garamond
 local subtitle=text(modal,'',14,COLORS.muted);subtitle.Name='SettingsSubtitle';subtitle.Visible=false
 local close=button(modal,'×',function() self:close() end);close.Name='SettingsClose';close.TextSize=25;close.BackgroundTransparency=1
 local divider=make('Frame',modal,{Name='SettingsDivider',BackgroundColor3=COLORS.line,BackgroundTransparency=.7,BorderSizePixel=0,ZIndex=102})
 local surface=make('ScrollingFrame',modal,{Name='Controls',BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=COLORS.muted,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=102})
 make('UIListLayout',surface,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
 make('UIPadding',surface,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
 local statusLabel=text(modal,'',14,COLORS.muted);statusLabel.Name='SettingsStatus'
 local retry=button(modal,'',function() if self.visible then Preferences.set('fov',Preferences.get().fov) end end);retry.Name='SettingsRetry';retry.BackgroundColor3=COLORS.white;retry.BackgroundTransparency=0;retry.TextColor3=COLORS.bg
 self.modal,self.surface,self.title,self.hint=modal,surface,title,subtitle
 local renderedKey
 local tabs={}
 local tabMarks={}
 local categoryOrder={'language','audio','picture','controls'}
 for _,key in ipairs(categoryOrder)do
  local b=button(modal,'',function() self.category=key;renderedKey=nil;surface.CanvasPosition=Vector2.new();self:update()end)
  b.Name='SettingsCategory_'..key;b.BackgroundTransparency=1
  tabs[key]=b
  tabMarks[key]=make('Frame',b,{Name='Selected',Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),BackgroundColor3=COLORS.white,BorderSizePixel=0,ZIndex=104})
 end
 local function tr(key) return I18n.text(Preferences.get().language,COPY[key][1]) end
 local function fit()
  local size=ctx.gui.AbsoluteSize
  local narrow=size.X<520
  local desired=self.category=='language'and 430 or self.category=='audio'and 430 or self.category=='picture'and 550 or 530
  local width=math.max(1,math.min(740,size.X-24))
  local height=math.max(1,math.min(desired,size.Y-24))
  local pad=narrow and 16 or 28
  local short=height<350
  local twoRows=width<300
  local top=(short and 106 or 136)+(twoRows and 46 or 0)
  local status=Preferences.status()
  local failed=status=='failed'
  local stackedFailure=narrow and not short
  local footer=status=='saved'and 12 or failed and(stackedFailure and 114 or 76)or 48
  self.compactFailure=failed and narrow and short
  modal.Size=UDim2.fromOffset(width,height)
  self.rail=false
  title.Position=UDim2.fromOffset(pad,short and 6 or 12);title.Size=UDim2.new(1,-pad*2-54,0,short and 40 or 52)
  title.TextSize=narrow and 32 or short and 36 or 44
  close.Position=UDim2.new(1,-pad-44,0,short and 6 or 12);close.Size=UDim2.fromOffset(44,44)
  local tabTop=short and 52 or 76
  divider.Position=UDim2.fromOffset(pad,tabTop+44+(twoRows and 46 or 0));divider.Size=UDim2.new(1,-pad*2,0,1)
  local gap=narrow and 2 or 14
  local columns=twoRows and 2 or 4
  local cell=(width-pad*2-gap*(columns-1))/columns
  for index,key in ipairs(categoryOrder)do
   local tab=tabs[key];tab.Position=UDim2.fromOffset(pad+((index-1)%columns)*(cell+gap),tabTop+math.floor((index-1)/columns)*46)
   tab.Size=UDim2.fromOffset(cell,44);tab.TextSize=narrow and 14 or 16
  end
  surface.Position=UDim2.fromOffset(pad,top)
  surface.Size=UDim2.new(1,-pad*2,0,math.max(1,height-top-footer))
  statusLabel.Position=UDim2.fromOffset(pad,height-footer+4)
  statusLabel.Size=UDim2.new(1,-pad*2-(failed and not stackedFailure and 130 or 0),0,failed and 52 or 32)
  retry.Position=stackedFailure and UDim2.new(0,pad,1,-56)or UDim2.new(1,-pad-112,1,-60)
  retry.Size=stackedFailure and UDim2.new(1,-pad*2,0,44)or UDim2.fromOffset(112,44)
 end
 local function row(key)
  local frame=make('Frame',surface,{Name=key,Size=UDim2.new(1,0,0,94),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=103})
  local label=text(frame,tr(key),17);label.Name='SettingLabel';label.Position=UDim2.fromOffset(0,0);label.Size=UDim2.new(1,0,0,32)
  make('Frame',frame,{Name='RowDivider',Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),BackgroundColor3=COLORS.line,BackgroundTransparency=.82,BorderSizePixel=0,ZIndex=103})
  return frame
 end
 local function controls(frame)
  return make('Frame',frame,{Name='Options',BackgroundTransparency=1,Position=UDim2.fromOffset(0,38),Size=UDim2.new(1,0,0,44),ZIndex=103})
 end
 local function enabled(b,ready)
  b.Active=ready;b.Selectable=ready;b.AutoButtonColor=ready;b.TextTransparency=ready and 0 or .5
 end
 function self:render()
  if not self.visible then return end
  fit()
  local current=Preferences.get()
  local status,ready=Preferences.status()
  title.Text,subtitle.Text=tr('title'),tr('subtitle')
  local localeNames={ru={'Язык','Звук','Графика','Камера'},en={'Language','Audio','Graphics','Camera'},zh={'语言','声音','画面','镜头'}}
  local labels=localeNames[current.language]or localeNames.ru
  for index,key in ipairs(categoryOrder)do
   local selected=key==self.category;local b=tabs[key];b.Text=labels[index];b.TextColor3=selected and COLORS.text or COLORS.muted;tabMarks[key].Visible=selected
  end
  statusLabel.Text=status=='saved'and ''or tr(status);statusLabel.Visible=status~='saved';retry.Text=tr('retry');retry.Visible=status=='failed'
  if self.compactFailure then
   statusLabel.Text=current.language=='en'and'Not saved. Retry.'or current.language=='zh'and'未保存，请重试。'or'Не сохранено. Повтори.'
  end
  local key=table.concat({current.language,tostring(current.musicVolume),tostring(current.sfxVolume),tostring(current.motionBlur),tostring(current.cameraMotion),tostring(current.reducedMotion),tostring(current.fov),tostring(current.effects),tostring(ready),self.category},':')
  if key==renderedKey then return end
  renderedKey=key
  local scroll=surface.CanvasPosition
  for _,child in ipairs(surface:GetChildren())do if child:IsA('GuiObject')then child:Destroy()end end
  local function numeric(key,min,max,step,format)
   local bar=controls(row(key))
   local minus=button(bar,'−',function()Preferences.set(key,math.clamp(math.round((Preferences.get()[key]-step)*100)/100,min,max))end);minus.Name='Decrease_'..key
   local plus=button(bar,'+',function()Preferences.set(key,math.clamp(math.round((Preferences.get()[key]+step)*100)/100,min,max))end);plus.Name='Increase_'..key
   plus.Position=UDim2.new(1,-48,0,0)
   local value=text(bar,format(current[key]),22,COLORS.text);value.Name='Value_'..key;value.Position=UDim2.fromOffset(56,0);value.Size=UDim2.new(1,-112,1,0);value.TextXAlignment=Enum.TextXAlignment.Center
   enabled(minus,ready and current[key]>min);enabled(plus,ready and current[key]<max)
  end
  local function toggle(key)
   local frame=row(key)
   local b=button(controls(frame),tr(current[key]and'on'or'off'),function()Preferences.set(key,not Preferences.get()[key])end);b.Name='Toggle_'..key
   b.Size=UDim2.fromScale(1,1)
   if current[key]then b.BackgroundColor3=COLORS.white;b.BackgroundTransparency=0;b.TextColor3=COLORS.bg end
   enabled(b,ready)
  end
  if self.category=='language'then
   for _,entry in ipairs({{'ru','Русский'},{'en','English'},{'zh','简体中文'}})do
    local code,caption=entry[1],entry[2]
    local b=button(surface,caption,function()Preferences.set('language',code)end)
    b.Name='Language_'..code;b:SetAttribute('SpyLocalize',false);b.Size=UDim2.new(1,0,0,58);b.TextSize=19;b.TextXAlignment=Enum.TextXAlignment.Center
    if current.language==code then
     local mark=text(b,'✓',20,COLORS.text);mark.Name='SelectedLanguage';mark.Position=UDim2.new(1,-36,0,0);mark.Size=UDim2.fromOffset(28,58)
     b.BackgroundTransparency=.1
    end
    enabled(b,ready)
   end
  elseif self.category=='audio'then
   numeric('musicVolume',0,1,.1,function(value)return tostring(math.round(value*100))..'%'end)
   numeric('sfxVolume',0,1,.1,function(value)return tostring(math.round(value*100))..'%'end)
  elseif self.category=='picture'then
   toggle('effects');toggle('motionBlur');numeric('fov',60,90,5,function(value)return tostring(math.round(value))..'°'end)
  else
   toggle('reducedMotion');toggle('cameraMotion')
   local note=text(surface,tr('note'),14,COLORS.muted);note.Name='ComfortNote';note.Size=UDim2.new(1,0,0,100)
   if ctx.make and ctx.L then
    local guide=button(surface,tr('guide'),function()self:close();require(script.Parent.GuideUI).open(ctx)end);guide.Name='OpenGuide';guide.Size=UDim2.new(1,0,0,44)
   end
  end
  surface.CanvasPosition=scroll
 end
 function self:update()fit();self:render()end
 function self:resize()self:update()end
 function self:open()
  if ctx.closeDialogue then ctx.closeDialogue()end
  if ctx.closePanels then ctx.closePanels('settings')end
  self.visible=true;overlay.Visible=true
  if ctx.setActivePanel then ctx.setActivePanel('settings')end
  self:update()
 end
 function self:close()
  self.visible=false;overlay.Visible=false
  if ctx.getActivePanel and ctx.getActivePanel()=='settings'and ctx.setActivePanel then ctx.setActivePanel(nil)end
 end
 local changeConnection=Preferences.Changed:Connect(function()self:render()end)
 local resizeConnection=ctx.gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:update()end)
 local inputConnection=UserInputService.InputBegan:Connect(function(input,processed)
  if not processed and input.KeyCode==Enum.KeyCode.Escape and self.visible then self:close()end
 end)
 overlay.Destroying:Connect(function()self:close();changeConnection:Disconnect();resizeConnection:Disconnect();inputConnection:Disconnect()end)
 return self
end
return SettingsUI
