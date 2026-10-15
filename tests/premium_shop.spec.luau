local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function load(name)
    local chunk=assert(loadstring(Sources[name],name))
    setfenv(chunk,setmetatable({script=script,game=game,require=function(key)return modules[key]end,
        Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,
        TweenInfo=TweenInfo,task=task},{__index=getfenv(0)}))
    return chunk()
end
local Rules=load('PremiumShopRules');modules.PremiumShopRules=Rules
check(type(Rules.savings)=='function','premium price comparison must exist')
local one={id=101,rolls=1,priceReady=true,priceRobux=99,configured=true,available=true}
local three={id=103,rolls=3,priceReady=true,priceRobux=279,configured=true,available=true}
local five={id=105,rolls=5,priceReady=true,priceRobux=449,configured=true,available=true}
check(Rules.savings(one,three).amount==18,'three-pack saves18 against actual unit price')
check(Rules.savings(one,five).percent==9,'five-pack shows moderate9percent savings')
check(Rules.savings({priceReady=false,previewPrice=99},three)==nil,'suggested price cannot create fake live savings')
check(Rules.savings(one,{rolls=3,priceReady=true,priceRobux=350})==nil,'more expensive pack cannot advertise savings')
check(Rules.savings({rolls=1,priceReady=true,priceRobux=50},three)==nil,'regional single price controls real comparison')
check(Rules.savings(one,{rolls=0,priceReady=true,priceRobux=1})==nil,'invalid quantity has no savings')
check(Rules.canPurchase(one,{ready=true},{},false),'configured live offer available in lobby')
check(not Rules.canPurchase(one,{ready=false},{},false),'unloaded profile cannot prompt')
check(not Rules.canPurchase({id=0,rolls=1,available=true,priceReady=true,configured=false},{ready=true},{},false),'unconfigured product cannot prompt')
check(not Rules.canPurchase(one,{ready=true},{tableId='match',phase='Hint'},false),'active match cannot prompt')
check(Rules.canPurchase(one,{ready=true},{tableId='match',phase='Result'},false),'result permits purchase')
check(not Rules.canPurchase(one,{ready=true,pendingTrade={id='t'}},{},false),'trade blocks purchase')
check(not Rules.canPurchase(one,{ready=true},{},true),'pending request blocks new prompt')
print('Premium shop rules: '..checks..' assertions passed')
local marketplace={PromptProductPurchaseFinished=signal()}
local localPrices={[101]=99,[103]=279,[105]=449}
local localForSale=true
function marketplace:GetProductInfoAsync(id,kind)
 check(kind==Enum.InfoType.Product,'quote must be for a developer product')
 return {PriceInRobux=localPrices[id],IsForSale=localForSale}
end
services.MarketplaceService=marketplace
modules.RollShopConfig={Packs={{key='roll_1',id=0,rolls=1,previewPrice=99},{key='roll_3',id=0,rolls=3,previewPrice=279},{key='roll_5',id=0,rolls=5,previewPrice=449}}}
local UI=load('PremiumRollShopUI')
check(type(UI.create)=='function','actual premium UI must exist')
local gui=Instance.new('ScreenGui');gui.AbsoluteSize=Vector2.new(1920,1080)
local testPlayer=Instance.new('Player');testPlayer.UserId=7;testPlayer.PlayerGui=gui
local p={ready=true,rolls=2,rollShop={ready=true,policyReady=true,offers={one,three,five}}}
local state,requests={},{}
local globalPending=false
local active,notifyMessage=nil,nil
local ctx={gui=gui,player=testPlayer,language=function()return 'ru'end,profile=function()return p end,
    state=function()return state end,pending=function()return globalPending end,
    closePanels=function()end,setActivePanel=function(value)active=value end,getActivePanel=function()return active end,
    openPanel=function()end,notify=function(message)notifyMessage=message end,
    request=function(kind,value,id)requests[#requests+1]={kind=kind,value=value,id=id};globalPending=true;return id end}
local shop=UI.create(ctx);shop:open()
local function find(name)for _,node in ipairs(gui:GetDescendants())do if node.Name==name then return node end end;error('Missing '..name)end
check(shop.visible and active=='premiumShop','shop opens through normal modal contract')
check(find('PackUnitPrice').TextSize>=13,'price per Roll remains readable without ten or eleven pixel text')
check(find('Buy_1').Active,'live single-pack can be purchased')
local originalOffers=p.rollShop.offers
p.rollShop.offers={};shop:update()
check(find('Buy_1').Text~='' and not find('Buy_1').Active,'empty loading DTO must show a disabled preview')
check(find('PackPrice').Text~='','loading DTO keeps a price label')
p.rollShop.offers=originalOffers;shop:update()
testPlayer:SetAttribute('SpyPhoneActive',true);shop:close()
check(shop:open()==false and not shop.visible,'phone blocks shop opening')
testPlayer:SetAttribute('SpyPhoneActive',false);shop:open()
find('Buy_1').Activated:Fire()
check(requests[#requests].kind=='rollPurchase' and requests[#requests].value==101,'client asks only configured product ID')
check(p.rolls==2,'opening prompt never grants currency')
local requestId=requests[#requests].id;globalPending=false
check(shop:receive({ok=true,code='rollPurchasePrompted',productId=101},requestId),'opening acknowledged')
marketplace.PromptProductPurchaseFinished:Fire(7,101,true)
check(p.rolls==2,'purchased callback never grants currency')
check(not find('Buy_3').Active,'awaiting receipt blocks duplicate prompt')
p.rolls=3
check(shop:receive({ok=true,code='rollsPurchased',productId=101,purchaseId='native-paid-1',rolls=1},nil),'real receipt accepted')
check(find('Buy_3').Active,'durable grant clears prompt lock')
check(not shop:receive({ok=true,code='identityRolled'},nil),'unrelated receipt ignored')
find('Buy_3').Activated:Fire();globalPending=false
shop:receive({ok=true,code='rollPurchasePrompted',productId=103},requests[#requests].id)
marketplace.PromptProductPurchaseFinished:Fire(7,103,false)
check(p.rolls==3 and find('Buy_3').Active,'cancelled native prompt grants nothing and unlocks')
find('Buy_1').Activated:Fire();globalPending=false
flush(19)
check(find('Buy_1').Active,'lost prompt acknowledgement recovers without granting currency')
check(p.rolls==3,'timeout never invents a paid grant')
find('Buy_1').Activated:Fire();globalPending=false
shop:receive({ok=true,code='rollPurchasePrompted'},requests[#requests].id)
marketplace.PromptProductPurchaseFinished:Fire(7,101,true)
flush(90)
check(requests[#requests].kind=='retry','delayed receipt checks authoritative wallet without another purchase')
globalPending=false;shop:update()
check(find('Buy_1').Active and p.rolls==3,'lost receipt notification allows explicit recovery after delay')
state={tableId='match',phase='Hint'};shop:update(true)
check(not find('Buy_1').Active,'active match is read-only')
state={};p.rollShop.offers[1]={id=0,rolls=1,configured=false,available=false,previewPrice=99};shop:update(true)
check(not find('Buy_1').Active,'preview price is never a live purchase')
for _,size in ipairs({{1920,1080},{360,640},{640,360},{280,640}})do
 gui.AbsoluteSize=Vector2.new(size[1],size[2]);shop:resize()
 local surface=find('PremiumRollSheet')
 check(surface.AbsolutePosition.X>=0 and surface.AbsolutePosition.Y>=0,'purchase sheet stays inside safe canvas')
 check(surface.AbsolutePosition.X+surface.AbsoluteSize.X<=size[1] and surface.AbsolutePosition.Y+surface.AbsoluteSize.Y<=size[2],'purchase sheet fits screen')
 check(find('Buy_1').AbsoluteSize.Y>=44,'purchase button stays tappable')
 for _,name in ipairs({'RollShopTitle','RollShopBalance','BackToCharacter'})do
  local node=find(name);local a,s=node.AbsolutePosition,node.AbsoluteSize
  local b,e=surface.AbsolutePosition,surface.AbsoluteSize
  check(s.X>0 and a.X>=b.X and a.X+s.X<=b.X+e.X+1,'premium header fits narrow viewport: '..name)
 end
end
shop:close(false);check(not shop.visible and active==nil,'close restores parent HUD')
localPrices={[101]=50,[103]=149,[105]=249}
localForSale=nil
p.rollShop.offers={one,three,five}
local regional=UI.create(ctx);regional:open()
local regionalPrices={}
local regionalBuy
local regionalSavings={}
for _,node in ipairs(gui:GetDescendants())do
 if node.Name=='PackPrice' and node.Parent.Parent.Parent.Parent.Visible then regionalPrices[#regionalPrices+1]=node.Text end
 if node.Name=='Buy_1' and node.Parent.Parent.Parent.Parent.Visible then regionalBuy=node end
 if node.Name=='PackSavings' and node.Parent.Parent.Parent.Parent.Visible then regionalSavings[#regionalSavings+1]=node.Text end
end
check(table.find(regionalPrices,'50 R$')~=nil,'local native quote replaces server base price')
check(regionalBuy.Active,'developer product quote can omit the asset-only IsForSale field')
check(table.find(regionalSavings,'−1%')~=nil,'savings compare local native single and pack prices')
check(table.find(regionalSavings,'−0%')==nil,'small regional saving must not round into meaningless zero percent')
regional:Destroy()
print('Premium shop UI: '..checks..' total assertions passed (GUI/native services stubbed)')
