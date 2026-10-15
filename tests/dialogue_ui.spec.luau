-- Tests the actual NPC routes and confirmation UI, not native font/mesh rendering.
events.MouseButton1Down=true;events.MouseButton1Up=true
Color3.new=function(r,g,b)return Color3.fromRGB(r*255,g*255,b*255)end
function Methods:WaitForChild(name)return self:FindFirstChild(name)end
function Methods:FindFirstChildOfClass(class)for _,c in ipairs(self:GetChildren())do if c:IsA(class)then return c end end end
local oldIsA=Methods.IsA
function Methods:IsA(class)return class=='GuiButton'and self.ClassName=='TextButton'or oldIsA(self,class)end
local baseIndex=NodeMeta.__index
NodeMeta.__index=function(node,key)local value=baseIndex(node,key);if value~=nil then return value end;return node:FindFirstChild(key)end
local tweenCreate=tweens.Create
tweens.Create=function(self,node,info,props)local t=tweenCreate(self,node,info,props);t.Completed={Once=function(_,fn)fn()end};return t end
task.wait=function()end
local profileEvent=signal()
local parent={WaitForChild=function(_,name)return name=='Profile'and {OnClientEvent=profileEvent}or name end,FindFirstChild=function(_,name)return Sources[name]and name or nil end}
local nativeScript={Parent=parent}
local function load(name)
 if modules[name]and not Sources[name]then return modules[name]end
 local chunk=assert(loadstring(Sources[name],name))
 setfenv(chunk,setmetatable({script=nativeScript,game=game,require=function(key)return modules[key]end,workspace=workspace,
  Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,TweenInfo=TweenInfo,task=task},{__index=getfenv(0)}))
 local m=chunk();modules[name]=m;return m
end
modules.ClubStoreConfig=load('ClubStoreConfig');modules.Catalog=load('Catalog');modules.ClubJournalUI=load('ClubJournalUI');local I18n=load('I18n')
local world=Instance.new('Workspace');world.CurrentCamera=Instance.new('Camera');world.CurrentCamera.ViewportSize=Vector2.new(1440,900)
workspace=world
local gui=Instance.new('ScreenGui');gui.AbsoluteSize=Vector2.new(1440,900)
local p={ready=true,revision=1,coins=100,owned={copper=true},equipped={},club={vincent={accepted=false,completed=false,claimed=false,rumorRu='У стойки есть работа.',rumorEn='Work at the bar.'}}}
local language='ru';local pending=false;local requests,opened={},{ };local talked=0
local ctx={gui=gui,language=function()return language end,profile=function()return p end,pending=function()return pending end,
 L=function(key)return I18n.t(language,key)end,closePanels=function()end,openPanel=function(name)opened[#opened+1]=name end,
 request=function(kind,value)requests[#requests+1]={kind=kind,value=value};pending=true;return'test-id'end}
local portraitMounts=0
modules.Preview3D.mountNPC=function(host)
 portraitMounts+=1
 local portrait=Instance.new('ViewportFrame');portrait.Name='VincentPortrait';portrait.Size=UDim2.fromScale(1,1)
 portrait.BackgroundTransparency=1;portrait.ZIndex=host.ZIndex+1;portrait.Parent=host
 portrait:SetAttribute('PortraitReady',true)
 return portrait
end
-- workspace is a late native boundary; load Dialogue only once it exists.
local UI=load('DialogueUI');local ui=UI.create(ctx,function()talked+=1 end)
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function find(name,base)for _,n in ipairs((base or gui):GetDescendants())do if n.Name==name then return n end end;error('Missing '..name)end
local function onScreen(node,host)local a,b=node.AbsolutePosition,node.AbsoluteSize;local x,s=host.AbsolutePosition,host.AbsoluteSize;return a.X>=x.X and a.Y>=x.Y and a.X+b.X<=x.X+s.X+1 and a.Y+b.Y<=x.Y+s.Y+1 end
check(portraitMounts==0,'hidden dialogue does not create native portrait work')
ui:open('start')
check(portraitMounts==1 and find('VincentPortrait').Parent~=nil,'opening dialogue mounts the existing NPC portrait')
local firstPortrait=find('VincentPortrait')
ui:render('news');check(portraitMounts==1,'changing conversation nodes retains one native portrait')
ui:close();check(firstPortrait.Parent==nil,'closing dialogue releases portrait and native work')
ui:open('start');check(portraitMounts==2,'reopening mounts one fresh portrait')
for _,size in ipairs({{1440,900},{1920,1080},{360,640},{360,540},{280,640},{844,250},{844,360}})do
 gui.AbsoluteSize=Vector2.new(size[1],size[2]);ui:open('start');gui:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 local shell=find('VincentDialogueShell')
 check(onScreen(shell,gui),'Vincent dialogue fits safe viewport')
 check(find('Close',shell).AbsoluteSize.X>=44 and find('Close',shell).AbsoluteSize.Y>=44,'dialogue close remains a touch target')
 check(onScreen(find('VincentName'),shell)and onScreen(find('VincentRole'),shell),'Vincent identity stays inside the responsive shell')
 if find('VincentPortraitHost').Visible then check(onScreen(find('VincentPortraitHost'),shell),'portrait fits the responsive shell')end
 if not find('VincentPortraitHost').Visible then check(find('VincentPortraitHost'):FindFirstChild('VincentPortrait')==nil,'hidden short-screen portrait performs no native clone work')end
 check(onScreen(find('BodyScroll'),shell)and onScreen(find('ResponseGrid'),shell),'dialogue body and responses stay inside the shell')
 for _,target in ipairs({'news','sellItems','club','shop','bye'})do check(find('Response_'..target).AbsoluteSize.Y>=48,'dialogue response remains tappable')end
 check(#requests==0,'opening/resize do not request rewards or sell things')
end
local primary=find('Response_news')
local function primaryReadable(message)
 for _,child in ipairs(primary:GetChildren())do
  if child:IsA('TextLabel')then
   check(primary.BackgroundColor3[1]-child.TextColor3[1]>=150,message)
  end
 end
end
primary.MouseEnter:Fire();primaryReadable('primary reply keeps readable ink on hover')
primary.MouseButton1Down:Fire();primaryReadable('primary reply keeps readable ink while held')
primary.MouseButton1Up:Fire();primary.MouseLeave:Fire();primaryReadable('primary reply returns to readable idle state')
find('Response_shop').Activated:Fire();check(opened[#opened]=='shop'and not ui.visible,'shop choice uses existing shop routing')
ui:open('news');find('Response_vincentAccept').Activated:Fire()
check(#requests==1 and requests[1].kind=='vincentAccept'and p.coins==100,'NPC assignment requests server action without inventing wallet credit')
find('Response_vincentAccept').Activated:Fire();check(#requests==1,'pending prevents a second assignment request')
pending=false;p.club.vincent.accepted=true;p.club.vincent.completed=true;ui:render('news')
find('Response_vincentClaim').Activated:Fire();check(requests[#requests].kind=='vincentClaim'and p.coins==100,'NPC claim remains server authoritative')
pending=false;ui:open('start');find('Response_sellItems').Activated:Fire()
check(find('VincentSellRoot').Visible and not ui.visible,'resale replaces conversation')
check(find('VincentPortraitHost'):FindFirstChild('VincentPortrait')==nil,'resale releases conversation portrait')
local before=#requests;find('Sell_copper').Activated:Fire()
check(find('SellConfirmation').Visible and #requests==before,'resale first opens explicit confirmation')
find('ConfirmSale').Activated:Fire();check(requests[#requests].kind=='sell'and requests[#requests].value=='copper','resale confirms the selected item through existing route')
check(p.coins==100 and p.owned.copper,'resale UI cannot mutate coins or ownership')
find('ConfirmSale').Activated:Fire();check(#requests==before+1,'pending resale cannot be submitted twice')
pending=false;ui:close();check(not find('VincentSellRoot').Visible,'close also closes resale')
language='en';ui:open('start');check(find('Response_shop')~=nil,'English conversation retains shop choice')
ui:close();check(talked==1,'onTalked callback remains once per controller')
ui:open('start');local retiredPortrait=find('VincentPortrait');local retiredRoot=find('VincentDialogueRoot');local retiredSellList=find('SellItems')
retiredRoot:Destroy();check(retiredPortrait.Parent==nil and not ui.visible,'destroying dialogue root releases portrait and retires controller')
local mountsBefore=portraitMounts;profileEvent:Fire();gui:GetPropertyChangedSignal('AbsoluteSize'):Fire();ui:open('start')
check(portraitMounts==mountsBefore,'retired controller cannot recreate late native portrait work')
ui:receive({code='sold',ok=true,value=100});check(#retiredSellList:GetChildren()==0,'late sale receipts cannot rebuild a retired resale view')
print('Vincent dialogue/resale: '..checks..' assertions passed (real modules; native rendering not exercised)')
