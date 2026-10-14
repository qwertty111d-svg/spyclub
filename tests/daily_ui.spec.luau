local checks=0
local function check(v,message)checks+=1;assert(v,message)end
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
events.InputBegan=true;events.InputEnded=true
modules.UITheme={Text={Caption=13,Body=16},Motion={Easing=Enum.EasingStyle.Quart}}
modules.UIEffects={pushBlur=function()end,popBlur=function()end}
modules.LayoutUI={measure=function(w,h)return{modal={w=math.min(940,w-24),h=math.min(640,h-24)}}end}
modules.IconUI={draw=function(parent)local icon=Instance.new('Frame');icon.Parent=parent;return icon end}
modules.Preview3D.mount=function(parent)local icon=Instance.new('ViewportFrame');icon.Name='ItemPreview';icon.Size=UDim2.fromScale(1,1);icon.Parent=parent;return icon end
local now=os.time()
local clock={time=function()return now end,clock=function()return now end}
local function load(name)
 local chunk=assert(loadstring(Sources[name],name))
 setfenv(chunk,setmetatable({script=script,game=game,require=function(k)return modules[k]end,
  Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,TweenInfo=TweenInfo,task=task,os=clock},{__index=getfenv(0)}))
 return chunk()
end
modules.DailyRewardConfig=load('DailyRewardConfig');modules.ClubStoreConfig=load('ClubStoreConfig')
for _,item in ipairs(modules.ClubStoreConfig.DailyItems)do Catalog.ById[item.id]=item end
modules.ModalUI=load('ModalUI');local Daily=load('DailyUI')
local gui=Instance.new('ScreenGui');gui.AbsoluteSize=Vector2.new(1920,1080)
local p={ready=true,revision=1,coins=100,rolls=5,daily={available=true,streak=0,nextStreak=1,nextAt=os.time()+86400,
 rewards=modules.DailyRewardConfig.Rewards,reward=modules.DailyRewardConfig.Rewards[1]}}
local pending=false
local requests={}
local function make(class,parent,properties)
 local node=Instance.new(class);for key,value in pairs(properties or{})do node[key]=value end
 if node:IsA('GuiObject')and parent and parent:IsA('GuiObject')and not(properties and properties.ZIndex)then node.ZIndex=parent.ZIndex+1 end
 node.Parent=parent;return node
end
local ctx={gui=gui,make=make,language=function()return'en'end,L=function(k)return k end,profile=function()return p end,
 pending=function()return pending end,closePanels=function()end,setActivePanel=function()end,getActivePanel=function()return'daily'end,
 request=function(kind)requests[#requests+1]=kind;pending=true;return'test-daily'end,
 panel=function(parent,size,pos)return make('Frame',parent,{Size=size,Position=pos})end,
 label=function(parent,value,size,pos,font,color)return make('TextLabel',parent,{Text=value,Size=size,Position=pos,TextSize=font,TextColor3=color})end,
 button=function(parent,value,size,pos,color)return make('TextButton',parent,{Text=value,Size=size,Position=pos,BackgroundColor3=color})end}
local ui=Daily.create(ctx);ui:open()
local function find(name,parent)for _,node in ipairs((parent or gui):GetDescendants())do if node.Name==name then return node end end;error('Missing '..name)end
check(find('RewardName',find('Day1')).Text=='150 COINS','coin day has an explicit coin headline')
check(find('RewardName',find('Day2')).Text=='100 XP','experience day is distinct from Rolls')
check(find('RewardName',find('Day5')).Text=='Club invitation','fifth-day card has its real item name')
check(find('RewardName',find('Day7')).Text=='Club seal','weekly finale leads with the actual collectible')
check(find('Bonus',find('Day7')).Text=='+1 Roll','weekly collectible also discloses its Roll')
for day=1,7 do
 check(math.abs(find('Day'..day).AbsolutePosition.Y-find('Day1').AbsolutePosition.Y)<1,'desktop reward calendar is a single seven-day track')
end
find('ClaimReward').Activated:Fire()
check(requests[#requests]=='daily'and p.coins==100 and p.rolls==5,'claim requests server grant without changing client balances')
check(not find('ClaimReward').Active,'pending daily claim cannot repeat')
pending=false;p.revision=2;p.daily.available=false;ui:update(true)
check(not find('ClaimReward').Active,'claimed UTC day remains disabled')
p.daily.streak=1;p.daily.nextStreak=1;p.daily.nextAt=now+1
now+=2;ui:tick()
check(find('ClaimReward').Text:find('100 XP',1,true)~=nil,'UTC rollover shows next-day XP instead of yesterday coins')
p.owned={noir_calling_card=true};now+=86400;ui:tick()
check(find('RewardName',find('Day5')).Text=='200 COINS','fresh cycle projects owned collectible compensation before profile refresh')
p.daily.available=true;p.daily.streak=1;p.daily.nextStreak=2;p.daily.reward=modules.DailyRewardConfig.Rewards[2];p.daily.nextAt=now+1
ui:update(true);now+=2;ui:tick()
check(find('ClaimReward').Text:find('150 COINS',1,true)~=nil,'missed available UTC day resets reward to day one')
p.daily.available=false;p.daily.streak=5;p.daily.nextStreak=5;p.daily.nextAt=now+1
p.daily.reward=modules.DailyRewardConfig.Rewards[5];p.daily.rewards=modules.DailyRewardConfig.Rewards
ui:update(true);now+=2;ui:tick()
check(find('RewardName',find('Day5')).Text=='Club invitation','midnight keeps already collected card when continuing the same week')
for _,size in ipairs({{1920,1080},{360,640},{844,360},{280,640}})do
 gui.AbsoluteSize=Vector2.new(size[1],size[2]);ui:resize()
 local action=find('ClaimReward');local surface=ui.modal
 local a,s=surface.AbsolutePosition,surface.AbsoluteSize
 check(a.X>=0 and a.Y>=0 and a.X+s.X<=size[1]and a.Y+s.Y<=size[2],'daily modal fits device canvas')
 check(action.AbsoluteSize.Y>=44,'daily action is a tappable target')
 check(action.AbsolutePosition.Y+action.AbsoluteSize.Y<=a.Y+s.Y,'claim stays above the modal edge')
 check(ui.surface.ScrollingDirection==Enum.ScrollingDirection.X,'weekly canvas scrolls horizontally on small screens')
 check(find('Day7').AbsolutePosition.X>find('Day6').AbsolutePosition.X,'weekly finale follows the sixth day')
 if size[1]<600 then check(ui.surface.CanvasPosition.X>0,'phone calendar starts at the current reward rather than hiding it offscreen') end
end
ui:close(false);check(not ui.visible,'daily close preserves modal lifecycle')
print('Daily/Modal GUI: '..checks..' assertions passed')
