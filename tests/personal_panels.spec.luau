-- Actual GUI modules and activation callbacks; service/profile edges are explicit.
Color3.new=function(r,g,b)return{r*255,g*255,b*255}end
Vector2.new=function(x,y)return{X=x or 0,Y=y or 0}end
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function liveSignal()
 local listeners={}
 return{Connect=function(_,callback)
  local entry={callback=callback,active=true};table.insert(listeners,entry)
  return{Disconnect=function()entry.active=false end}
 end,Fire=function(_,...)for _,entry in ipairs(listeners)do if entry.active then entry.callback(...)end end end,
 Count=function()local n=0;for _,entry in ipairs(listeners)do if entry.active then n+=1 end end;return n end}
end
function Methods:GetPropertyChangedSignal(key)self._signals[key]=self._signals[key]or liveSignal();return self._signals[key]end
input.InputBegan=liveSignal()
services.RunService={Heartbeat=liveSignal()}
local camera=Instance.new('Camera');camera.ViewportSize=Vector2.new(1440,900)
local workspaceSignals={}
local workspace={CurrentCamera=camera,GetPropertyChangedSignal=function(_,key)workspaceSignals[key]=workspaceSignals[key]or liveSignal();return workspaceSignals[key]end}
local settings={language='ru',musicVolume=.5,sfxVolume=.8,motionBlur=true,cameraMotion=true,reducedMotion=false,fov=75,effects=true}
local prefStatus,prefReady='saved',true
local edits={}
local changed=liveSignal()
local Preferences={Changed=changed,start=function()end,get=function()return table.clone(settings)end,
 status=function()return prefStatus,prefReady end,set=function(key,value)
  if not prefReady then return false end
  table.insert(edits,{key=key,value=value});settings[key]=value;changed:Fire();return true
 end}
local modules={ClientPreferences=Preferences,I18n={text=function(_,ru)return ru end}}
local script={Parent=setmetatable({FindFirstChild=function()return nil end},{__index=function(_,key)return key end})}
local function load(name)
 local chunk=assert(loadstring(Sources[name],name));setfenv(chunk,setmetatable({script=script,
  require=function(key)return modules[key]end,game=game,workspace=workspace,Instance=Instance,Enum=Enum,
  UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,task=task},{__index=getfenv(0)}));return chunk()
end
local function make(class,parent,props)
 local n=Instance.new(class);for k,v in pairs(props or{})do n[k]=v end;n.Parent=parent;return n
end
local function find(parent,name)
 for _,node in ipairs(parent:GetDescendants())do if node.Name==name then return node end end
 error('Missing '..name)
end
local function fits(node,parent,message)
 local p,s=node.AbsolutePosition,node.AbsoluteSize;local q,t=parent.AbsolutePosition,parent.AbsoluteSize
 check(s.X>0 and s.Y>0 and p.X>=q.X-.01 and p.Y>=q.Y-.01 and p.X+s.X<=q.X+t.X+.01 and p.Y+s.Y<=q.Y+t.Y+.01,message)
end
local function separate(a,b,message)
 local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
 check(p.X+s.X<=q.X+.01 or q.X+t.X<=p.X+.01 or p.Y+s.Y<=q.Y+.01 or q.Y+t.Y<=p.Y+.01,message)
end
local function neutral(color)return color and math.max(color[1],color[2],color[3])-math.min(color[1],color[2],color[3])<=12 end
local gui=make('ScreenGui',nil,{AbsoluteSize=Vector2.new(1440,900)})
local active,closedDialogue,closedPanels=nil,0,0
local settingsUI=load('SettingsUI').create({gui=gui,closeDialogue=function()closedDialogue+=1 end,
 closePanels=function()closedPanels+=1 end,setActivePanel=function(value)active=value end,getActivePanel=function()return active end})
settingsUI:open()
check(settingsUI.visible and active=='settings'and closedDialogue==1 and closedPanels==1,'settings open keeps modal ownership')
local panel=find(gui,'SettingsPanel')
check(find(panel,'SettingsHeading').Font==Enum.Font.Garamond,'settings uses club display typography')
check(neutral(panel.BackgroundColor3),'settings shell is neutral')
local categories={'language','audio','picture','controls'}
for _,size in ipairs({{1440,900},{360,640},{280,320},{844,360}})do
 gui.AbsoluteSize=Vector2.new(size[1],size[2])
 for _,category in ipairs(categories)do
  find(panel,'SettingsCategory_'..category).Activated:Fire()
  settingsUI:resize();fits(panel,gui,'settings safe bounds')
  fits(find(panel,'SettingsHeading'),panel,'settings heading fits')
  check(find(panel,'SettingsHeading').TextSize<=find(panel,'SettingsHeading').AbsoluteSize.Y,'short settings display text fits header height')
  fits(find(panel,'SettingsClose'),panel,'settings close fits')
  fits(find(panel,'Controls'),panel,'settings scroll fits')
  local previous
  for _,key in ipairs(categories)do
   local tab=find(panel,'SettingsCategory_'..key);fits(tab,panel,'settings category fits')
   check(tab.AbsoluteSize.Y>=44,'settings categories remain tappable')
   if previous then separate(previous,tab,'settings tabs do not overlap')end;previous=tab
  end
  separate(find(panel,'SettingsHeading'),find(panel,'SettingsClose'),'heading avoids close')
 end
end
gui.AbsoluteSize=Vector2.new(360,640);find(panel,'SettingsCategory_audio').Activated:Fire()
find(panel,'Increase_musicVolume').Activated:Fire();check(edits[#edits].key=='musicVolume'and edits[#edits].value==.6,'numeric control saves one preference')
find(panel,'Decrease_sfxVolume').Activated:Fire();check(edits[#edits].key=='sfxVolume'and edits[#edits].value==.7,'decrease preserves step')
prefStatus,prefReady='loading',false;changed:Fire()
check(not find(panel,'Increase_musicVolume').Active,'loading preferences disable edits')
prefStatus,prefReady='failed',true;changed:Fire()
check(find(panel,'SettingsRetry').Visible,'failed save keeps retry')
fits(find(panel,'SettingsStatus'),panel,'failed status stays inside narrow modal')
fits(find(panel,'SettingsRetry'),panel,'failed retry stays inside narrow modal')
separate(find(panel,'SettingsStatus'),find(panel,'SettingsRetry'),'failed status and retry do not overlap')
find(panel,'SettingsRetry').Activated:Fire();check(edits[#edits].key=='fov','retry uses original settings save path')
gui.AbsoluteSize=Vector2.new(280,320);settingsUI:resize()
check(find(panel,'Controls').AbsoluteSize.Y>=44,'short failed-save window keeps a full touch row visible')
fits(find(panel,'SettingsStatus'),panel,'short failed status fits');fits(find(panel,'SettingsRetry'),panel,'short retry fits')
separate(find(panel,'SettingsStatus'),find(panel,'SettingsRetry'),'short failure footer stays separate')
prefStatus='saved';changed:Fire()
find(panel,'SettingsCategory_picture').Activated:Fire();find(panel,'Toggle_effects').Activated:Fire()
check(edits[#edits].key=='effects'and edits[#edits].value==false,'graphics toggle retains setting key')
find(panel,'SettingsCategory_language').Activated:Fire();find(panel,'Language_en').Activated:Fire()
check(edits[#edits].key=='language'and settings.language=='en','language action unchanged')
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Escape},false)
check(not settingsUI.visible and active==nil,'settings Escape closes ownership')
settingsUI:open();find(panel,'SettingsClose').Activated:Fire();check(not settingsUI.visible,'settings close action')

local journal=load('ClubJournalUI')
local profile={ready=true,club={vincent={reward=100,accepted=false,completed=false,claimed=false},achievements={
 {id='first',nameRu='Первый вечер',nameEn='First evening',detailRu='Заверши один матч.',detailEn='Finish a match.',target=1,value=0,reward=100,unlocked=false},
 {id='long',nameRu='Постоянный гость клуба и хранитель тайн',nameEn='A regular guest',detailRu='Заверши десять матчей и возвращайся в клуб.',detailEn='Finish ten matches.',target=10,value=25,reward=350,unlocked=true}}}}
local pending=false;local requests={}
local journalUI=journal.create({gui=gui,profile=function()return profile end,language=function()return'ru'end,
 closePanels=function()closedPanels+=1 end,pending=function()return pending end,request=function(action)table.insert(requests,action)end})
journalUI:open();local shell=find(gui,'JournalPanel')
check(journalUI:isVisible()and find(shell,'Heading').Font==Enum.Font.Garamond,'journal opens with club display typography')
check(neutral(shell.BackgroundColor3),'journal shell is neutral')
for _,size in ipairs({{1440,900},{360,640},{280,320},{844,360}})do
 gui.AbsoluteSize=Vector2.new(size[1],size[2]);journalUI:resize()
 fits(shell,gui,'journal safe bounds');fits(find(shell,'Heading'),shell,'journal heading fits')
 check(find(shell,'Heading').TextSize<=find(shell,'Heading').AbsoluteSize.Y,'short journal display text fits header height')
 fits(find(shell,'Close'),shell,'journal close fits');fits(find(shell,'JournalScroll'),shell,'journal scroll fits')
 local assignment=find(shell,'DailyAssignment')
 for _,name in ipairs({'Title','Body','TaskAction'})do fits(find(assignment,name),assignment,'assignment '..name..' fits')end
 separate(find(assignment,'Title'),find(assignment,'Body'),'assignment title and body separate')
 separate(find(assignment,'Body'),find(assignment,'TaskAction'),'assignment body and action separate')
 check(find(assignment,'TaskAction').AbsoluteSize.Y>=44,'journal task action tappable')
 for _,id in ipairs({'first','long'})do
  local card=find(shell,'Achievement_'..id)
  for _,name in ipairs({'Title','Detail','Progress','Reward','Track'})do fits(find(card,name),card,'achievement '..name..' fits')end
  separate(find(card,'Title'),find(card,'Detail'),'achievement title avoids detail')
  separate(find(card,'Detail'),find(card,'Progress'),'achievement detail avoids progress')
 end
end
local action=find(shell,'TaskAction')
action.Activated:Fire();check(requests[#requests]=='vincentAccept','available task asks authority to accept')
profile.club.vincent.accepted=true;profile.club.vincent.completed=true;journalUI:update()
action.Activated:Fire();check(requests[#requests]=='vincentClaim','complete task asks authority to claim')
local count=#requests;pending=true;action.Activated:Fire();check(#requests==count,'pending task rejects duplicate activation')
pending=false;profile.club.vincent.claimed=true;action.Activated:Fire();check(#requests==count,'activation re-reads claimed authority')
profile.ready=false;journalUI:update();action.Activated:Fire();check(requests[#requests]=='retry','unready journal reconnect route preserved')
check(journal.achievementViews(profile,'ru')[2].progress==1,'achievement progress stays clamped to server records')
journalUI:close();check(not journalUI:isVisible(),'journal closes')
count=#requests;action.Activated:Fire();check(#requests==count,'closed journal cannot submit a hidden task')
local heartbeatBefore=services.RunService.Heartbeat.Count();journalUI:open();journalUI:open()
check(services.RunService.Heartbeat.Count()==heartbeatBefore+1,'reopening does not duplicate task poller')
journalUI:close();check(services.RunService.Heartbeat.Count()==heartbeatBefore,'close releases task poller')
journalUI:open();gui.AbsoluteSize=Vector2.new(360,640);gui:GetPropertyChangedSignal('AbsoluteSize'):Fire()
fits(shell,gui,'live GUI resize keeps journal inside viewport')
local inputCount=input.InputBegan.Count()
find(gui,'ClubJournalRoot'):Destroy()
check(not journalUI:isVisible()and input.InputBegan.Count()==inputCount-1,'journal destruction releases input and modal lifecycle')
check(services.RunService.Heartbeat.Count()==heartbeatBefore,'journal destruction releases task poller')
settingsUI:open();inputCount=input.InputBegan.Count()
find(gui,'settingsOverlay'):Destroy()
check(not settingsUI.visible and active==nil,'settings destruction releases active ownership')
check(input.InputBegan.Count()==inputCount-1 and changed.Count()==0,'settings destruction disconnects profile and input listeners')
print('Personal panels: '..checks..' checks passed')
