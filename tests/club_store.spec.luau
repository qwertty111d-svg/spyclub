local checks=0
local function check(value,label)checks+=1;assert(value,label)end
local function load(name)
 local chunk=assert(loadstring(Sources[name],name))
 setfenv(chunk,setmetatable({script=script,game=game,require=function(key)return modules[key]end,
  Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,task=task},{__index=getfenv(0)}))
 return chunk()
end
modules.ClubStoreConfig=load('ClubStoreConfig');modules.PremiumShopRules=load('PremiumShopRules')
for _,item in ipairs(modules.ClubStoreConfig.Items)do Catalog.ById[item.id]=item;table.insert(Catalog.Items,item)end
for _,item in ipairs(modules.ClubStoreConfig.DailyItems)do Catalog.ById[item.id]=item;table.insert(Catalog.Items,item)end
local UI=load('ClubStoreUI')
check(type(UI.create)=='function','actual curated coin store must exist')
local gui=Instance.new('ScreenGui');gui.AbsoluteSize=Vector2.new(1920,1080)
local player=Instance.new('Player');player.UserId=7;player.Character=nil
local p={ready=true,revision=1,coins=1000,rolls=5,owned={},equipped={}}
local state,requests,opened={}, {}, {}
local pending=false
local active
local ctx={gui=gui,player=player,profile=function()return p end,language=function()return'ru'end,state=function()return state end,
 pending=function()return pending end,closePanels=function()end,setActivePanel=function(v)active=v end,getActivePanel=function()return active end,
 openPanel=function(name)opened[#opened+1]=name end,request=function(kind,value,id)requests[#requests+1]={kind=kind,value=value,id=id};pending=true;return id or'coin-guid'end}
local store=UI.create(ctx)
local function find(name)for _,node in ipairs(gui:GetDescendants())do if node.Name==name then return node end end;error('Missing '..name)end
check(store:open()and active=='clubStore','store opens through existing panel contract')
find('StoreItem_velvet_lapel_pin').Activated:Fire()
check(find('CollectionPrice').Text:find('600')~=nil,'selected fixed-price item displays six hundred coins')
find('CollectionAction').Activated:Fire()
check(requests[#requests].kind=='clubBuy'and requests[#requests].value=='velvet_lapel_pin','buy only sends selected item ID')
check(p.coins==1000 and not p.owned.velvet_lapel_pin,'UI never invents wallet spend or ownership')
check(not find('CollectionAction').Active,'pending purchase blocks repeat action')
pending=false;p.owned.velvet_lapel_pin=true;p.coins=400
check(store:receive({ok=true,code='clubBought'},requests[#requests].id),'matching durable purchase reply releases action')
find('CollectionAction').Activated:Fire()
check(requests[#requests].kind=='equip','owned collectible equips through existing validated server route')
pending=false;p.equipped.trinket='velvet_lapel_pin'
store:receive({ok=true,code='equipped'},requests[#requests].id)
check(not find('CollectionAction').Active,'equipped collectible cannot accidentally toggle off')
p.equipped={};p.owned={};p.coins=10;store:update(true)
check(not find('CollectionAction').Active,'insufficient coins visibly disable purchase')
p.coins=1000;state={tableId='round',phase='Hint'};store:update(true)
check(not find('CollectionAction').Active,'active match prevents collection changes')
state={};find('StoreRobuxTab').Activated:Fire()
check(opened[#opened]=='premiumShop'and not store.visible,'store gives explicit access to real Robux Roll products')
check(#find('CollectionPreview'):GetChildren()==1,'closing store releases the moving avatar preview')
player:SetAttribute('SpyPhoneActive',true)
check(not store:open(),'store cannot cover the phone')
player:SetAttribute('SpyPhoneActive',false);store:open()
check(not find('StoreItem_club_seal_pin').Visible,'unearned daily collectible is not for sale')
p.owned.club_seal_pin=true;store:update()
check(find('StoreItem_club_seal_pin').Visible,'earned daily collectible is accessible in collection')
find('StoreItem_club_seal_pin').Activated:Fire();find('CollectionAction').Activated:Fire()
check(requests[#requests].kind=='equip'and requests[#requests].value=='club_seal_pin','daily collectible can actually be worn')
pending=false;store:receive({ok=true,code='equipped'},requests[#requests].id)
find('StoreItem_burgundy_dossier').Activated:Fire();find('CollectionAction').Activated:Fire()
local originalId=requests[#requests].id
pending=false;p.ready=false
check(store:receive({ok=false,code='save_failed'},originalId),'uncertain save reply is handled')
check(find('CollectionAction').Active,'unloaded profile exposes a recovery action')
find('CollectionAction').Activated:Fire()
check(requests[#requests].kind=='retry'and requests[#requests].id~=originalId,'recovery reloads profile without another purchase')
local syncId=requests[#requests].id
pending=false;p.ready=true;store:receive({ok=true,code='refreshed'},syncId)
find('CollectionAction').Activated:Fire()
check(requests[#requests].kind=='clubBuy'and requests[#requests].id==originalId,'resolved profile replays the original purchase ID')
pending=false;store:receive({ok=false,code='not_enough'},originalId)
p.ready=false;store:update()
check(find('CollectionAction').Active,'initially unavailable profile can be reloaded from the collection')
find('CollectionAction').Activated:Fire()
check(requests[#requests].kind=='retry','initial profile recovery is read-only')
pending=false;p.ready=true;store:receive({ok=true,code='refreshed'},requests[#requests].id)
for _,size in ipairs({{1920,1080},{360,640},{844,360}})do
 gui.AbsoluteSize=Vector2.new(size[1],size[2]);store:resize()
 local sheet=find('ClubStoreSheet');local s,a=sheet.AbsoluteSize,sheet.AbsolutePosition
 check(a.X>=0 and a.Y>=0 and a.X+s.X<=size[1]and a.Y+s.Y<=size[2],'curated store fits device canvas')
 check(find('CollectionAction').AbsoluteSize.Y>=44,'collection action remains tappable')
end
store:Destroy();check(not store.visible,'destroy closes store')
print('Club store GUI: '..checks..' assertions passed')
