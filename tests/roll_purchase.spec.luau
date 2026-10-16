-- run_roll_purchase.py bundles unmodified actual Lobby/Match module sources.
-- Roblox services are explicit boundary stubs; no Studio rendering is asserted.
local assertions=0
local function check(value,message)
    assertions+=1
    assert(value,message)
end
local function clone(value)
    if type(value)~="table" then return value end
    local result={} for key,item in pairs(value) do result[key]=clone(item) end
    return result
end
local function signal()
    local result={listeners={}}
    function result:Connect(fn)
        table.insert(self.listeners,fn)
        return {Disconnect=function()end}
    end
    function result:Fire(...)
        for _,fn in ipairs(self.listeners) do fn(...) end
    end
    return result
end
local function fixture(options)
    options=options or {}
    local modules,parent,shared={},{},{}
    for name in pairs(Sources) do parent[name]=name;shared[name]=name end
    local storage={SpyShared=shared}
    function storage:WaitForChild(name)return assert(self[name],name)end
    function shared:WaitForChild(name)return assert(self[name],name)end
    function parent:WaitForChild(name)return assert(self[name],name)end
    local player={UserId=7,attributes={}}
    function player:GetAttribute(name)return self.attributes[name]end
    function player:SetAttribute(name,value)self.attributes[name]=value end
    local players={present=true,PlayerRemoving=signal()}
    player.Parent=players
    function players:GetPlayerByUserId(id)return self.present and id==player.UserId and player or nil end
    function players:GetPlayers()return self.present and {player} or {} end
    local processReceipt
    local marketplace={PromptGamePassPurchaseFinished=signal(),PromptProductPurchaseFinished=signal(),
        prompts={},nativePromptCalls=0,priceCalls=0,priceInfo={},receiptAssignments=0,ownedPasses={}}
    setmetatable(marketplace,{
        __index=function(_,key)if key=="ProcessReceipt" then return processReceipt end end,
        __newindex=function(target,key,value)
            if key=="ProcessReceipt" then
                target.receiptAssignments+=1;processReceipt=value
            else rawset(target,key,value) end
        end,
    })
    function marketplace:GetProductInfoAsync(id,kind)
        self.priceCalls+=1
        if self.priceFailure then error("simulated official price metadata failure") end
        if self.priceInfo[id] then return clone(self.priceInfo[id]) end
        return {PriceInRobux=id==71001 and 99 or id==71003 and 279 or 449,
            IsForSale=true,Name="Test Roll pack"}
    end
    function marketplace:UserOwnsGamePassAsync(_,id)return self.ownedPasses[id]==true end
    function marketplace:PromptProductPurchase(target,id)
        self.nativePromptCalls+=1
        if self.promptFailure then error("simulated native prompt failure") end
        table.insert(self.prompts,{player=target,id=id})
    end
    local policy={answer={ArePaidRandomItemsRestricted=false},calls=0}
    function policy:GetPolicyInfoForPlayerAsync()
        self.calls+=1
        if self.failure then error("simulated official policy service failure") end
        return clone(self.answer)
    end
    local run={studio=options.studio==true}
    function run:IsStudio()return self.studio end
    local clock=100
    local pending={}
    local taskStub={wait=function()end}
    function taskStub.spawn(fn,...)
        table.insert(pending,{at=clock,fn=fn,args={...}})
    end
    taskStub.defer=taskStub.spawn
    function taskStub.delay(seconds,fn,...)
        table.insert(pending,{at=clock+seconds,fn=fn,args={...}})
    end
    local store={data={},writes=0,mode=nil}
    function store:UpdateAsync(key,transform)
        self.writes+=1
        if self.mode=="before" then error("simulated datastore failure before commit") end
        local value=transform(clone(self.data[key]))
        if value~=nil then self.data[key]=clone(value) end
        if self.mode=="after" then error("simulated datastore lost reply after commit") end
        return clone(value)
    end
    local guidCount=0
    local http={GenerateGUID=function()guidCount+=1;return "test-guid-"..guidCount end}
    local services={Players=players,MarketplaceService=marketplace,PolicyService=policy,
        RunService=run,ReplicatedStorage=storage,HttpService=http,
        DataStoreService={GetDataStore=function()return store end}}
    local gameStub={GetService=function(_,name)return assert(services[name],name)end}
    local enum={ProductPurchaseDecision={PurchaseGranted="PurchaseGranted",NotProcessedYet="NotProcessedYet"},
        InfoType={Product="Product",GamePass="GamePass"}}
    local loadModule
    loadModule=function(name)
        if modules[name] then return modules[name] end
        local chunk=assert(loadstring(assert(Sources[name],name),name))
        setfenv(chunk,setmetatable({game=gameStub,script={Parent=parent},require=loadModule,
            task=taskStub,Enum=enum,os=setmetatable({clock=function()return clock end},{__index=os}),
            warn=function()end},{__index=getfenv(0)}))
        local value=chunk();modules[name]=value;return value
    end
    local profiles=loadModule("Profiles").new()
    check(profiles:load(player.UserId),"fixture loads actual profile")
    local fixtureResult={load=loadModule,profiles=profiles,player=player,players=players,
        marketplace=marketplace,policy=policy,run=run,store=store,enum=enum,changes={}}
    function fixtureResult:flush(seconds)
        clock+=seconds or 0
        local count=0
        while true do
            local due
            for index,job in ipairs(pending) do if job.at<=clock then due=index;break end end
            if not due then break end
            local job=table.remove(pending,due);count+=1
            assert(count<=100,"unbounded immediate task scheduling")
            job.fn(table.unpack(job.args))
        end
    end
    function fixtureResult:start(serviceOptions)
        self.monetization=loadModule("Monetization").new(profiles,function(target,receipt)
            if self.callbackFailure then error("simulated publication failure after persistence") end
            table.insert(self.changes,{player=target,receipt=clone(receipt)})
        end,serviceOptions)
        return self.monetization
    end
    function fixtureResult:configure()
        local config=loadModule("MonetizationConfig")
        local ids={71001,71003,71005}
        for index,def in ipairs(config.Products) do def.id=ids[index] end
        return config
    end
    function fixtureResult:snapshot()
        return self.monetization:shopFor(player,profiles:public(player.UserId))
    end
    function fixtureResult:ready()
        self:snapshot();self:flush()
        return self:snapshot()
    end
    function fixtureResult:receipt(purchaseId,productId,spent)
        return self.marketplace.ProcessReceipt({PlayerId=player.UserId,
            ProductId=productId or 71001,PurchaseId=purchaseId,CurrencySpent=spent or 99})
    end
    return fixtureResult
end

-- Removing shopFor (or accidentally loading the dormant Match implementation)
-- must fail before any purchase can be exposed to a player.
local first=fixture()
-- Fixture-only placeholders keep this scenario valid after real IDs are filled.
for _,def in ipairs(first.load("MonetizationConfig").Products) do def.id=0 end
local service=first:start()
check(type(service.shopFor)=="function","real Monetization must expose shopFor for Roll packs")

-- Changing a legacy identifier or exposing the old currency products would
-- violate saved purchase rights even if the new Roll pack UI looked correct.
local config=first.load("MonetizationConfig")
local shopConfig=first.load("RollShopConfig")
check(#shopConfig.Packs==3 and #config.Products==3,"shop has exactly three Roll packs")
local quantities,prices={1,3,5},{99,279,449}
local configuredIds={}
local legacyIds={[3714674590]=true,[3714674680]=true,[3714674731]=true,[3714674783]=true,[3714115805]=true}
for index,pack in ipairs(shopConfig.Packs) do
    check(type(pack.id)=="number" and pack.id==pack.id and pack.id<math.huge
        and pack.id>=0 and pack.id%1==0 and not legacyIds[pack.id],
        "production Roll product ID is zero or a valid nonlegacy configured ID")
    if pack.id>0 then
        check(not configuredIds[pack.id],"configured production Roll product IDs must be unique")
        configuredIds[pack.id]=true
    end
    check(pack.key=="rolls_"..quantities[index] and pack.rolls==quantities[index]
        and pack.previewPrice==prices[index],"shared pack quantity and preview price")
    local def=config.Products[index]
    check(def.key==pack.key and def.reward.rolls==pack.rolls and def.category=="rolls"
        and def.paidRandom==true,"server Roll product definition follows shared pack")
end
local expectedLegacy={
    [3714674590]={xp=100},[3714674680]={coins=500},[3714674731]={coins=1600},
    [3714674783]={coins=5000},[3714115805]={},
}
local legacyCount=0
for _,def in ipairs(config.LegacyProducts) do
    legacyCount+=1
    local expected=expectedLegacy[def.id]
    check(expected~=nil,"legacy product retains original ID")
    local reward=def.reward or {}
    check((reward.coins or 0)==(expected.coins or 0)
        and (reward.xp or 0)==(expected.xp or 0) and reward.rolls==nil,
        "legacy product reward cannot be repurposed into Rolls")
end
check(legacyCount==5,"all five legacy receipt products retained")
local passIds={}
for _,def in ipairs(config.Passes) do passIds[def.id]=true end
check(passIds[1998632381] and passIds[1998344385],"both purchased pass IDs retained")
check(config.validateReward({reward={rolls=1}}),"positive integer Roll reward valid")
for _,quantity in ipairs({-1,0,1.5,0/0,math.huge,-math.huge,"1"}) do
    check(not config.validateReward({reward={rolls=quantity}}),"invalid Roll quantity rejected")
end
check(config.validateReward({reward={coins=500}}),"legacy currency reward remains valid")
for _,reward in ipairs({{coins=0/0},{coins=math.huge},{xp=math.huge},{rolls=1,coins=-1}}) do
    check(not config.validateReward({reward=reward}),"nonfinite or invalid combined reward rejected")
end

-- Unknown policy must deny paid spending and still show accurate disabled
-- placeholder cards without fetching product zero or opening native prompts.
local unknown=first:snapshot()
check(unknown.ready and unknown.policyReady==false and unknown.restricted==true,
    "unknown official policy produces conservative owner snapshot")
check(#unknown.offers==3,"unconfigured packs remain visible for preview")
for _,offer in ipairs(unknown.offers) do
    check(offer.kind=="product" and offer.category=="rolls" and offer.rolls>0,
        "shop only exposes Roll pack purchase DTOs")
    check(offer.configured==false and offer.available==false and offer.priceReady==false,
        "placeholder products never become purchasable")
end
check(not service:canSpendPaidRolls(first.player),"unknown policy denies paid spending")
check(not service:prompt(first.player,0).ok and #first.marketplace.prompts==0,
    "placeholder cannot prompt native purchase")
first:flush()
check(first.marketplace.priceCalls==0,"unconfigured product zero never fetched from Marketplace")
check(first:snapshot().policyReady and service:canSpendPaidRolls(first.player),
    "explicit official unrestricted response enables paid spending")
check(#service:offersFor(first.player)==0,"legacy and unconfigured offers stay out of purchase listing")

-- A pending getter must stay nonyielding; only explicit official false may
-- enable offers, including Studio sessions and recovery after a failed request.
for _,answer in ipairs({{}, {ArePaidRandomItemsRestricted="false"},
    {ArePaidRandomItemsRestricted=0}, {ArePaidRandomItemsRestricted=true}}) do
    local f=fixture();f:configure();f.policy.answer=answer;local m=f:start()
    check(not m:canSpendPaidRolls(f.player) and f.policy.calls==0,
        "policy lookup schedules work without yielding the getter")
    f:flush()
    check(not m:canSpendPaidRolls(f.player),"malformed or restricted official policy denies paid spending")
    local snapshot=f:snapshot()
    for _,offer in ipairs(snapshot.offers) do check(not offer.available,"restricted policy disables every pack") end
end
local studioPolicy=fixture({studio=true});studioPolicy:configure()
studioPolicy.policy.answer={ArePaidRandomItemsRestricted=true};studioPolicy:start();studioPolicy:ready()
check(not studioPolicy.monetization:canSpendPaidRolls(studioPolicy.player),
    "Studio cannot bypass official paid-random restriction")
local recovering=fixture();recovering:configure();recovering.policy.failure=true;recovering:start()
recovering:ready()
check(not recovering:snapshot().policyReady and not recovering.monetization:canSpendPaidRolls(recovering.player),
    "policy failure remains unknown and restricted")
check(recovering.policy.calls==1,"failed policy request is backed off instead of immediately looped")
recovering.policy.failure=false;recovering:flush(31);recovering:ready()
check(recovering:snapshot().policyReady and recovering.monetization:canSpendPaidRolls(recovering.player),
    "official policy failure recovers on bounded retry")

-- Only verified prices allow the native prompt; preview Robux cannot substitute
-- for a missing, malformed or unpublished Marketplace price.
local priced=fixture();priced:configure();priced:start()
local pendingPrice=priced:snapshot()
check(priced.marketplace.priceCalls==0,"price getter schedules official work without yielding")
for _,offer in ipairs(pendingPrice.offers) do check(not offer.priceReady and not offer.available,"pending price disables offer") end
local readyPrice=priced:ready()
for index,offer in ipairs(readyPrice.offers) do
    check(offer.configured and offer.priceReady and offer.available and offer.priceRobux==prices[index],
        "official price and known unrestricted policy enable configured pack")
end
for _,metadata in ipairs({{}, {PriceInRobux="99",IsForSale=true},
    {PriceInRobux=-1,IsForSale=true},{PriceInRobux=1.5,IsForSale=true},
    {PriceInRobux=0/0,IsForSale=true},{PriceInRobux=math.huge,IsForSale=true},
    {PriceInRobux=99,IsForSale=false}}) do
    local f=fixture();f:configure();f.marketplace.priceInfo[71001]=metadata;f:start()
    local snap=f:ready()
    check(not snap.offers[1].available,"unusable official price prevents sale")
    check(not f.monetization:prompt(f.player,71001).ok and #f.marketplace.prompts==0,
        "unusable metadata cannot prompt purchase")
end
local unavailablePrice=fixture();unavailablePrice:configure();unavailablePrice.marketplace.priceFailure=true
unavailablePrice:start();unavailablePrice:ready()
check(not unavailablePrice:snapshot().offers[1].available,"price service failure cannot use preview price")
unavailablePrice.marketplace.priceFailure=false;unavailablePrice:flush(31);unavailablePrice:ready()
check(unavailablePrice:snapshot().offers[1].available,"official price failure recovers after bounded retry")
local omittedSale=fixture();omittedSale:configure()
omittedSale.marketplace.priceInfo[71001]={PriceInRobux=99};omittedSale:start()
check(omittedSale:ready().offers[1].available,"official price accepts omitted optional IsForSale field")
priced.policy.answer={ArePaidRandomItemsRestricted=true};priced:flush(61)
check(not priced.monetization:canSpendPaidRolls(priced.player),"expired policy cache denies spending during refresh")
priced:flush()
check(priced:snapshot().policyReady and priced:snapshot().restricted,
    "official refreshed restriction replaces previous cached permission")

-- Placeholder, missing, malformed and colliding IDs must fail safely; a Roll
-- pack collision must preserve the original legacy receipt reward.
for _,id in ipairs({0,-1,71001.5,"71001",math.huge,0/0}) do
    local f=fixture();local cfg=f:configure();cfg.Products[1].id=id;f:start()
    local snapshot=f:ready()
    check(not snapshot.offers[1].configured and not snapshot.offers[1].available,
        "invalid product ID disables only its pack")
end
local missing=fixture();local missingConfig=missing:configure();missingConfig.Products[1].id=nil
missing:start()
check(not missing:ready().offers[1].configured,"missing product ID remains a safe visible placeholder")
local colliding=fixture();local collisionConfig=colliding:configure()
collisionConfig.Products[1].id=3714674590;colliding:start()
check(not colliding:ready().offers[1].configured,"legacy-ID collision disables new pack")
check(not colliding.monetization:prompt(colliding.player,3714674590).ok,
    "legacy collision cannot prompt a repurposed Roll purchase")
local collisionBefore=colliding.profiles:public(7)
check(colliding:receipt("collision-preserves-legacy",3714674590,49)
    ==colliding.enum.ProductPurchaseDecision.PurchaseGranted,"collided legacy receipt still fulfills")
local collisionAfter=colliding.profiles:public(7)
check(collisionAfter.xp==collisionBefore.xp+100 and collisionAfter.rolls==collisionBefore.rolls,
    "legacy registry wins collision with its original reward")
local duplicated=fixture();local duplicateConfig=duplicated:configure()
duplicateConfig.Products[2].id=71001;duplicated:start()
local duplicateSnapshot=duplicated:ready()
check(not duplicateSnapshot.offers[1].available and not duplicateSnapshot.offers[2].available,
    "ambiguous new product ID cannot expose either pack")
check(duplicated:receipt("duplicate-pack-id")==duplicated.enum.ProductPurchaseDecision.NotProcessedYet,
    "ambiguous Roll product receipt stays retryable until configuration repaired")

-- Mutating any server guard to trust the requested ID alone would permit
-- purchases during an active match, trade, pending save, or full wallet.
local allowPrompt=true
local guarded=fixture();guarded:configure()
guarded:start({canPrompt=function()return allowPrompt end});guarded:ready()
local beforeBalance=guarded.profiles:public(7).rolls
local prompted=guarded.monetization:prompt(guarded.player,71001)
check(prompted.ok and prompted.code=="rollPurchasePrompted"
    and prompted.productId==71001
    and #guarded.marketplace.prompts==1 and guarded.marketplace.prompts[1].player==guarded.player,
    "allowed server request opens native product prompt for its owner")
check(guarded.profiles:public(7).rolls==beforeBalance,"prompt never grants currency before receipt")
local function guardReject(message)
    local old=#guarded.marketplace.prompts
    check(not guarded.monetization:prompt(guarded.player,71001).ok
        and #guarded.marketplace.prompts==old,message)
end
allowPrompt=false;guardReject("active match phase cannot prompt purchase");allowPrompt=true
guarded.profiles.cache[7].pendingTrade={id="locked-trade"}
guardReject("trade processing cannot prompt purchase");guarded.profiles.cache[7].pendingTrade=nil
guarded.profiles.pending[7]=1;guarded.player:SetAttribute("SpyProfilePending",1)
guardReject("pending profile transaction cannot prompt purchase")
guarded.profiles.pending[7]=nil;guarded.player:SetAttribute("SpyProfilePending",0)
guarded.profiles.busy[7]=true;guardReject("busy profile transaction cannot prompt purchase")
guarded.profiles.busy[7]=nil
guarded.player:SetAttribute("SpyTeleporting",true);guardReject("teleporting player cannot prompt purchase")
guarded.player:SetAttribute("SpyTeleporting",false)
local cached=guarded.profiles.cache[7];guarded.profiles.cache[7]=nil
guardReject("unavailable profile cannot prompt purchase");guarded.profiles.cache[7]=cached
local maxRolls=guarded.load("AccessoryRollConfig").MaxRolls
cached.rolls=maxRolls;guardReject("full Roll wallet cannot prompt purchase");cached.rolls=beforeBalance
guarded:flush(3)
local beforeNativeCalls=guarded.marketplace.nativePromptCalls
guarded.marketplace.promptFailure=true;guardReject("native prompt failure returns failure")
check(guarded.marketplace.nativePromptCalls==beforeNativeCalls+1,
    "native prompt failure actually reaches Marketplace after cooldown")
guarded.marketplace.promptFailure=false
for _,id in ipairs({3714674680,12345,-1,71001.5,"71001"}) do
    check(not guarded.monetization:prompt(guarded.player,id).ok,"legacy, unknown or malformed IDs cannot prompt Roll sale")
end

-- Receipt delivery must remain deterministic across policy/phase changes,
-- receipt cache pruning, reloads, and lost write replies on the actual profile.
for _,studio in ipairs({false,true}) do
    local f=fixture({studio=studio});f:configure();f.policy.answer={ArePaidRandomItemsRestricted=true}
    f:start({canPrompt=function()return false end})
    local initial=f.profiles:public(7)
    check(f:receipt("stable-purchase")==f.enum.ProductPurchaseDecision.PurchaseGranted,
        "completed deterministic Roll grant ignores subsequent policy or phase restriction")
    local granted=f.profiles.cache[7]
    check(granted.rolls==initial.rolls+1 and granted.paidRollReserve==1
        and granted.supporters==initial.supporters+99,"receipt atomically credits paid Rolls and supporters")
    check(granted.purchaseReceipts["stable-purchase"]~=nil,"stable Roblox purchase identity persisted")
    check(granted.receipts["purchase:stable-purchase"].productId==71001,
        "first durable receipt identifies actual Roll product")
    check(f:receipt("stable-purchase")==f.enum.ProductPurchaseDecision.PurchaseGranted
        and f.profiles.cache[7].rolls==initial.rolls+1
        and f.profiles.cache[7].supporters==initial.supporters+99,"same live or Studio receipt grants exactly once")
    local cacheFillSucceeded=true
    for index=1,97 do
        local receipt=f.profiles:transact(7,"cache-fill-"..index,{kind="language",language="ru"})
        cacheFillSucceeded=cacheFillSucceeded and receipt.ok
    end
    check(cacheFillSucceeded and f.profiles.cache[7].receipts["purchase:stable-purchase"]==nil,
        "actual transactions prune old purchase from bounded 96-entry UI receipt cache")
    check(f.profiles:load(7),"actual profile reload succeeds after short receipt pruning")
    check(f:receipt("stable-purchase")==f.enum.ProductPurchaseDecision.PurchaseGranted
        and f.profiles.cache[7].rolls==initial.rolls+1,
        "permanent purchase ledger prevents replay after short receipt pruning and reload")
    check(f.profiles.cache[7].receipts["purchase:stable-purchase"].productId==71001,
        "permanent purchase replay retains actual product metadata after pruning")
    for _,identity in ipairs({"",false}) do
        local before=f.profiles.cache[7].rolls
        check(f:receipt(identity)==f.enum.ProductPurchaseDecision.NotProcessedYet
            and f.profiles.cache[7].rolls==before,"missing or invalid purchase identity never fabricated")
    end
    check(f:receipt(nil)==f.enum.ProductPurchaseDecision.NotProcessedYet,
        "nil purchase identity never fabricated in live or Studio")
    f.callbackFailure=true
    local ok,result=pcall(function()return f:receipt("callback-failure")end)
    check(ok and result==f.enum.ProductPurchaseDecision.PurchaseGranted
        and f.profiles.cache[7].rolls==initial.rolls+2,
        "publication callback failure cannot undo acknowledged durable purchase")
end

-- Original receipt IDs must retain their original rewards even for players
-- who now have restricted policy, while obsolete offers remain hidden.
local legacy=fixture();legacy:configure();legacy.policy.answer={ArePaidRandomItemsRestricted=true}
legacy:start();legacy:ready()
for id,reward in pairs(expectedLegacy) do
    local before=legacy.profiles:public(7)
    check(legacy:receipt("legacy-"..id,id,49)==legacy.enum.ProductPurchaseDecision.PurchaseGranted,
        "legacy receipt ID remains fulfillable regardless of current policy")
    local after=legacy.profiles:public(7)
    check(after.coins==before.coins+(reward.coins or 0) and after.xp==before.xp+(reward.xp or 0)
        and after.rolls==before.rolls and after.supporters==before.supporters+49,
        "legacy product keeps its previous deterministic reward and supporter grant")
end

-- Failed receipt preconditions must not acknowledge a purchase or mutate the
-- wallet; these failures stay retryable until the profile/config recovers.
local failed=fixture();local failedConfig=failed:configure();failed:start()
check(failed:receipt("unknown",12345)==failed.enum.ProductPurchaseDecision.NotProcessedYet,"unknown product remains retryable")
failed.players.present=false
check(failed:receipt("absent")==failed.enum.ProductPurchaseDecision.NotProcessedYet,"absent owner remains retryable")
failed.players.present=true
local saved=failed.profiles.cache[7];failed.profiles.cache[7]=nil
local unloadedWrites=failed.store.writes
check(failed:receipt("profile")==failed.enum.ProductPurchaseDecision.NotProcessedYet,"unloaded owner profile remains retryable")
check(failed.store.writes==unloadedWrites,"receipt cannot auto-load a profile that was initially unavailable")
failed.profiles.cache[7]=saved
local invalid=fixture();local invalidConfig=invalid:configure();invalidConfig.Products[1].reward.rolls=1.5
local beforeInvalid=invalid.profiles:public(7).rolls;invalid:start()
check(invalid:receipt("invalid-reward")==invalid.enum.ProductPurchaseDecision.NotProcessedYet
    and invalid.profiles:public(7).rolls==beforeInvalid,"invalid configured Roll reward never acknowledged or credited")
failed.store.data.User_7.rolls=maxRolls
failed.profiles:load(7)
check(failed:receipt("wallet-cap")==failed.enum.ProductPurchaseDecision.NotProcessedYet
    and failed.store.data.User_7.rolls==maxRolls,"cap overflow rolls back actual persisted purchase")

for _,mode in ipairs({"before","after"}) do
    local f=fixture();f:configure();f:start();local before=f.profiles:public(7).rolls
    f.store.mode=mode
    check(f:receipt("datastore-"..mode)==f.enum.ProductPurchaseDecision.NotProcessedYet,
        "uncertain datastore outcome remains retryable: "..mode)
    check(f.store.data.User_7.rolls==before+(mode=="after" and 1 or 0),
        "actual store has correct durable balance after request failure: "..mode)
    f.store.mode=nil
    check(f:receipt("datastore-"..mode)==f.enum.ProductPurchaseDecision.PurchaseGranted
        and f.profiles.cache[7].rolls==before+1,"same-session receipt retry reloads and delivers exactly once: "..mode)
end

-- A receipt save failure permits recovery only in its existing live session.
-- Reloads stay bounded and wait for existing profile work to finish.
for _,mode in ipairs({"before","after"}) do
    local f=fixture();f:configure();f:start();local before=f.profiles:public(7).rolls
    f.store.mode=mode
    check(f:receipt("repeated-outage")==f.enum.ProductPurchaseDecision.NotProcessedYet,
        "first persistence outage leaves payment pending")
    local writes=f.store.writes
    check(f:receipt("repeated-outage")==f.enum.ProductPurchaseDecision.NotProcessedYet
        and f.store.writes==writes+3,"receipt reload uses only the existing bounded load attempts")
    writes=f.store.writes;f:flush(100)
    check(f.store.writes==writes,"receipt failure never starts background polling")
    f.store.mode=nil
    f.profiles.pending[7]=1
    check(f:receipt("repeated-outage")==f.enum.ProductPurchaseDecision.NotProcessedYet
        and f.store.writes==writes,"receipt recovery does not overlap queued profile work")
    f.profiles.pending[7]=nil;f.profiles.busy[7]=true
    check(f:receipt("repeated-outage")==f.enum.ProductPurchaseDecision.NotProcessedYet
        and f.store.writes==writes,"receipt recovery does not overlap an active transaction")
    f.profiles.busy[7]=nil
    check(f:receipt("repeated-outage")==f.enum.ProductPurchaseDecision.PurchaseGranted
        and f.profiles:public(7).rolls==before+1,"later receipt retry recovers after a repeated outage")
end

local coalesced=fixture();coalesced:configure();coalesced:start()
coalesced.store.mode="before"
check(coalesced:receipt("coalesced")==coalesced.enum.ProductPurchaseDecision.NotProcessedYet,
    "coalesced recovery starts from a real failed receipt save")
coalesced.store.mode=nil
local update=coalesced.store.UpdateAsync
local hold=true
function coalesced.store:UpdateAsync(key,transform)
    if hold then hold=false;coroutine.yield("receipt reload waiting") end
    return update(self,key,transform)
end
local recoveredDecision
local recoveryThread=coroutine.create(function()recoveredDecision=coalesced:receipt("coalesced")end)
local resumed,waiting=coroutine.resume(recoveryThread)
check(resumed and waiting=="receipt reload waiting","actual datastore reload can yield")
local coalescedWrites=coalesced.store.writes
check(coalesced:receipt("coalesced")==coalesced.enum.ProductPurchaseDecision.NotProcessedYet
    and coalesced.store.writes==coalescedWrites,"concurrent receipt retries share one in-flight reload")
check(coroutine.resume(recoveryThread) and coroutine.status(recoveryThread)=="dead"
    and recoveredDecision==coalesced.enum.ProductPurchaseDecision.PurchaseGranted
    and coalesced.store.writes==coalescedWrites+2 and coalesced.profiles:public(7).paidRolls==1,
    "one completed reload permits one atomic receipt credit")

local manual=fixture();manual:configure();manual:start()
manual.store.mode="after"
check(manual:receipt("manual-reload")==manual.enum.ProductPurchaseDecision.NotProcessedYet,
    "manual recovery starts after a lost durable response")
manual.store.mode=nil;check(manual.profiles:load(7),"external profile reload remains supported")
local manualWrites=manual.store.writes
manual.callbackFailure=true
check(manual:receipt("manual-reload")==manual.enum.ProductPurchaseDecision.PurchaseGranted
    and manual.store.writes==manualWrites+1 and manual.profiles:public(7).paidRolls==1,
    "external reload skips receipt reload and publication failure cannot undo durable acknowledgement")
manual.profiles.cache[7]=nil;manualWrites=manual.store.writes
check(manual:receipt("after-recovery")==manual.enum.ProductPurchaseDecision.NotProcessedYet
    and manual.store.writes==manualWrites,"successful receipt clears permission to reload unrelated missing profiles")

-- Departure clears recovery rights. A yielded reload for an old Player cannot
-- retry a purchase on the replacement Player's session, even after it loads.
local departing=fixture();departing:configure();departing:start()
departing.store.mode="before"
check(departing:receipt("departure")==departing.enum.ProductPurchaseDecision.NotProcessedYet,
    "departure recovery starts after failed receipt persistence")
departing.store.mode=nil
local departingUpdate=departing.store.UpdateAsync
local holdDeparture=true
function departing.store:UpdateAsync(key,transform)
    if holdDeparture then holdDeparture=false;coroutine.yield("departing reload waiting") end
    return departingUpdate(self,key,transform)
end
local oldDecision
local oldThread=coroutine.create(function()oldDecision=departing:receipt("departure")end)
local oldResumed,oldWaiting=coroutine.resume(oldThread)
check(oldResumed and oldWaiting=="departing reload waiting","departure can interrupt a yielded receipt reload")
local oldPlayer=departing.player
departing.players.present=false;oldPlayer.Parent=nil
departing.players.PlayerRemoving:Fire(oldPlayer);departing.profiles:remove(7)
local returned={UserId=7,Parent=departing.players,attributes={}}
function returned:GetAttribute(name)return self.attributes[name]end
function returned:SetAttribute(name,value)self.attributes[name]=value end
function departing.players:GetPlayerByUserId(id)return self.present and id==7 and returned or nil end
departing.players.present=true
local departedWrites=departing.store.writes
check(departing:receipt("departure")==departing.enum.ProductPurchaseDecision.NotProcessedYet
    and departing.store.writes==departedWrites,"replacement player cannot inherit old receipt reload permission")
check(departing.profiles:load(7),"replacement session loads its own profile normally")
local replacementRolls=departing.profiles:public(7).rolls
check(coroutine.resume(oldThread) and coroutine.status(oldThread)=="dead"
    and oldDecision==departing.enum.ProductPurchaseDecision.NotProcessedYet
    and departing.profiles:public(7).rolls==replacementRolls,
    "old yielded callback cannot grant into the returned player's session")
check(departing:receipt("departure")==departing.enum.ProductPurchaseDecision.PurchaseGranted
    and departing.profiles:public(7).rolls==replacementRolls+1,"returned player fulfills the original pending receipt once")

-- Restoring existing passes must retain cosmetics without forcing equipment,
-- and paid cosmetic luck remains disabled under official restricted policy.
local passes=fixture();passes:start()
passes.marketplace.ownedPasses[1998632381]=true;passes.marketplace.ownedPasses[1998344385]=true
passes:ready()
local equippedBefore=clone(passes.profiles.cache[7].equipped)
passes.monetization:sync(passes.player);passes:flush()
local passProfile=passes.profiles.cache[7]
for _,def in ipairs(passes.load("MonetizationConfig").Passes) do
    for _,id in ipairs(def.ids or {}) do check(passProfile.owned[id],"existing cosmetic pass restores owned item "..id) end
end
for slot,id in pairs(equippedBefore) do check(passProfile.equipped[slot]==id,"pass sync preserves chosen equipment") end
check(passes.monetization:hasEntitlement(passes.player,"case_luck_2x"),
    "existing owned cosmetic luck entitlement restores when policy permits")
passes.policy.answer={ArePaidRandomItemsRestricted=true};passes:flush(61)
passes.monetization:canSpendPaidRolls(passes.player);passes:flush()
check(not passes.monetization:hasEntitlement(passes.player,"case_luck_2x"),
    "official restricted policy disables restored cosmetic luck")

-- Receipt ownership is process-wide: repeated startup cannot silently replace
-- the active handler or attach another purchase-finished grant controller.
local owned=fixture();owned:configure();owned:start()
local ownerHandler=owned.marketplace.ProcessReceipt
pcall(function()owned:start()end)
check(owned.marketplace.ProcessReceipt==ownerHandler and owned.marketplace.receiptAssignments==1,
    "repeated startup keeps exactly one global receipt owner")
check(#owned.marketplace.PromptGamePassPurchaseFinished.listeners==1,
    "repeated startup does not duplicate pass purchase listeners")
local secondProfiles=owned.load("Profiles").new()
local acceptedDifferentOwner=pcall(function()
    owned.load("Monetization").new(secondProfiles,function()end)
end)
check(not acceptedDifferentOwner and owned.marketplace.ProcessReceipt==ownerHandler,
    "different profile instance cannot steal global receipt ownership")

-- Use the actual configured products, without fixture.configure() replacing IDs.
-- These customer IDs must reach native prompting and persist the right quantity.
local activated=fixture()
local liveProducts={
    {id=3718610025,key="rolls_1",rolls=1,price=99},
    {id=3718610195,key="rolls_3",rolls=3,price=279},
    {id=3718610306,key="rolls_5",rolls=5,price=449},
}
for _,product in ipairs(liveProducts)do
    activated.marketplace.priceInfo[product.id]={PriceInRobux=product.price,IsForSale=true}
end
activated:start()
local activeShop=activated:ready()
for index,product in ipairs(liveProducts)do
    local offer=activeShop.offers[index]
    check(offer.configured and offer.available and offer.id==product.id and offer.key==product.key,
        "configured customer product becomes available: "..product.key)
    check(offer.priceRobux==product.price and offer.priceSource=="marketplace",
        "customer product uses Marketplace price: "..product.key)
    activated:flush(3)
    check(activated.monetization:prompt(activated.player,product.id).ok
        and activated.marketplace.prompts[#activated.marketplace.prompts].id==product.id,
        "native prompt receives customer product ID: "..product.key)
    local before=activated.profiles:public(7)
    local purchaseId="customer-product-"..product.key
    check(activated:receipt(purchaseId,product.id,product.price)==activated.enum.ProductPurchaseDecision.PurchaseGranted,
        "customer product receipt is saved: "..product.key)
    local after=activated.profiles:public(7)
    check(after.rolls==before.rolls+product.rolls
        and after.paidRolls==before.paidRolls+product.rolls,
        "customer product credits its exact paid Roll quantity: "..product.key)
    check(activated:receipt(purchaseId,product.id,product.price)==activated.enum.ProductPurchaseDecision.PurchaseGranted
        and activated.profiles:public(7).rolls==after.rolls,
        "customer receipt replay never credits twice: "..product.key)
end

print(PlaceName.." roll purchase tests passed: "..assertions.." assertions")
