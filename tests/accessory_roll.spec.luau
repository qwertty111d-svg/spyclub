-- Tests actual Economy/Profiles/Service sources bundled by run_accessory_roll.py.
-- Wardrobe is an explicit asset/rig stub: these checks do not validate rendering.
local assertions=0
local function check(value,message) assertions+=1;assert(value,message) end
local function clone(value)
    if type(value)~="table" then return value end
    local out={} for k,v in pairs(value) do out[k]=clone(v) end return out
end
local modules,loadModule={},nil
local storage={SpyShared={}}
local shared=storage.SpyShared
for name in pairs(Sources) do shared[name]=name end
function shared:WaitForChild(name) return self[name] end
shared.Parent=storage
function storage:WaitForChild(name) return self[name] end
function storage:FindFirstChild() return {GetAttribute=function()return 0 end} end
local attributes={}
local character={Parent=true}
function character:GetAttribute(name) return name=="SpyBaseReady" end
local player={UserId=7,Character=character}
function player:SetAttribute(name,value) attributes[name]=value end
local players={}
function players:GetPlayerByUserId(id)return id==7 and player or nil end
local run={studio=false}
function run:IsStudio()return self.studio end
local store={data=nil,mode=nil,writes=0,callbackCount=0,onRead=nil}
function store:UpdateAsync(_,transform)
    self.writes+=1
    if self.onRead then local fn=self.onRead;self.onRead=nil;fn() end
    if self.mode=="before" then error("simulated request failure before commit") end
    self.callbackCount+=1
    local value=transform(clone(self.data))
    if value~=nil then self.data=clone(value) end
    if self.mode=="after" then error("simulated lost reply after commit") end
    return clone(value)
end
local dataStore={GetDataStore=function()return store end}
local guidCounter=0
local http={GenerateGUID=function()guidCounter+=1;return "awardguid"..guidCounter end}
local services={ReplicatedStorage=storage,Players=players,RunService=run,DataStoreService=dataStore,HttpService=http}
local gameStub={GetService=function(_,name)return assert(services[name],name) end}
local prepared,validated={},{}
local Wardrobe={Accessories={},Outfits={club_vest=true,velvet_tuxedo=true,director_suit=true}}
function Wardrobe.prepare(equipment,_,slot)return prepared[equipment[slot]]~=false end
function Wardrobe.validate(_,equipment,slot)return validated[equipment[slot]]~=false end
modules.Wardrobe=Wardrobe;shared.Wardrobe="Wardrobe"
local draws=0
local clock=100
local osStub=setmetatable({clock=function()return clock end},{__index=os})
local randomStub={new=function()return {NextNumber=function()draws+=1;return 10 end} end}
local taskStub={wait=function()end,spawn=function(fn,...)return fn(...)end}
local parent={}
for name in pairs(Sources) do parent[name]=name end
loadModule=function(name)
    if modules[name] then return modules[name] end
    local chunk=assert(loadstring(assert(Sources[name],name),name))
    setfenv(chunk,setmetatable({script={Parent=parent},game=gameStub,require=loadModule,
        task=taskStub,Random=randomStub,os=osStub,warn=function()end},{__index=getfenv(0)}))
    local result=chunk();modules[name]=result;return result
end
local Catalog=loadModule("Catalog")
local Config=loadModule("AccessoryRollConfig")
local Economy=loadModule("Economy")
local Inventory=loadModule("Inventory")
local Rules=loadModule("AccessoryRollRules")
local Profiles=loadModule("Profiles")
local Service=loadModule("AccessoryRollService")
for _,item in ipairs(Catalog.Items)do
    if item.wearable and item.wearable.assetId then Wardrobe.Accessories[item.id]={id=item.wearable.assetId} end
end
for _,id in ipairs({"black_tie","burgundy_tie","tophat","classic_glasses","noir_glasses","dark_fedora","agent_fedora"})do Wardrobe.Accessories[id]={id=1} end
local function command(sequence,item,category)
    return {kind="accessoryRoll",category=category or "tie",requestId=tostring(sequence).."-uuidtest0001",
        sequence=sequence,itemId=item or "black_tie",prepared=true}
end
local function mutate(profile,sequence,item,category)
    local cmd=command(sequence,item,category)
    local _,receipt=Economy.transaction(profile,"roll:7:"..cmd.category..":"..cmd.requestId,cmd,Catalog)
    return receipt,cmd
end

-- Migration preserves original ownership/equipment/progress; credits once.
local legacy=Economy.new(Catalog)
legacy.rolls=nil;legacy.rollMigrationVersion=nil;legacy.rollSequence=nil
legacy.freeCases={midnight=2,velvet=1};legacy.coins=450;legacy.xp=200
legacy.owned.gold=true;legacy.equipped.hair="hair_charmer";legacy.itemCounts.gold=3
local migrated=Economy.migrate(legacy,Catalog)
check(migrated.rolls==8,"five initial migration rolls plus three legacy credits")
check(migrated.coins==450 and migrated.xp==200 and migrated.itemCounts.gold==3,"old progress/counts preserved")
check(migrated.equipped.hair=="hair_charmer" and migrated.owned.gold,"old appearance and ownership preserved")
check(next(migrated.freeCases)==nil and migrated.legacyFreeCases.midnight==2,"case redemption moved into audit")
Economy.migrate(migrated,Catalog);check(migrated.rolls==8,"migration is idempotent")
local corrupted=clone(migrated);corrupted.rolls=0/0;check(not Economy.validate(corrupted),"NaN wallet rejected")
corrupted=clone(migrated);corrupted.rollSequence=-1;check(not Economy.validate(corrupted),"negative sequence rejected")

-- Actual catalog pools normalize absent rarities and never treat loadout as clothes.
local profile=Economy.new(Catalog)
local entries,chances=Rules.pool(Catalog.Items,Config.ById.gloves,profile,Catalog,function()return true end)
check(#entries==1 and chances.common==100,"single-rarity glove pool normalizes to100")
local tieEntries,tieChances=Rules.pool(Catalog.Items,Config.ById.tie,profile,Catalog,function(item)return item.id=="black_tie" or item.id=="burgundy_tie" end)
check(#tieEntries==2 and math.abs(tieChances.common-48/78*100)<1e-8,"tie weights normalize valid models only")
check(Rules.select(tieEntries,0).id=="black_tie" and Rules.select(tieEntries,99).id=="burgundy_tie","weighted selection crosses boundary")
check(not Rules.allowed(Catalog.ById.gold,Config.ById.hat,profile,Catalog),"card cannot become hat")
check(not Rules.allowed(Catalog.ById.founder_suit,Config.ById.outfit,profile,Catalog),"paid outfit excluded")
check(not Rules.allowed(Catalog.ById.tuxedo,Config.ById.outfit,profile,Catalog),"daily exclusive outfit excluded")
profile.equipped.hair="hair_charmer"
check(not Rules.allowed(Catalog.ById.hair_noir,Config.ById.hair,profile,Catalog),"style group respected")
check(Rules.allowed(Catalog.ById.hair_messy_brown,Config.ById.hair,profile,Catalog),"unisex works with current style")
profile.equipped.hat="dark_fedora"
check(not Rules.allowed(Catalog.ById.tophat,Config.ById.accessory,profile,Catalog),"unrenderable accessory conflict unavailable")

-- One atomic balance/grant/equip change; duplicate never toggles equipment off.
profile=Economy.new(Catalog)
profile.equipped.hair="hair_charmer";profile.equipped.outfit="club_vest";profile.equipped.accessory="tophat"
local before=clone(profile.equipped)
local first,cmd=mutate(profile,1,"black_tie")
check(first.ok and profile.rolls==4 and profile.equipped.tie=="black_tie","spend and equip exactly one")
check(profile.itemCounts.black_tie==1 and first.quantity==1,"item granted")
for slot,value in pairs(before)do if slot~="tie" then check(profile.equipped[slot]==value,"other slot preserved: "..slot) end end
local _,replay,replayed=Economy.transaction(profile,"roll:7:tie:"..cmd.requestId,cmd,Catalog)
check(replayed and replay.itemId==first.itemId and profile.rolls==4 and profile.itemCounts.black_tie==1,"replay does not spend or duplicate")
local duplicate=mutate(profile,2,"black_tie")
check(duplicate.ok and duplicate.duplicate and profile.equipped.tie=="black_tie" and profile.itemCounts.black_tie==2,"duplicate stays equipped and count increases")
local hat=mutate(profile,3,"dark_fedora","hat")
check(hat.ok and profile.equipped.accessory=="tophat","hat roll preserves other accessory slot")
local balance=profile.rolls
profile.pendingTrade={id="trade"}
local locked=mutate(profile,4,"black_tie")
check(not locked.ok and locked.code=="trade_processing" and profile.rolls==balance,"trade reservation blocks spend")
profile.pendingTrade=nil
local invalid=mutate(profile,4,"founder_tie")
check(not invalid.ok and profile.rolls==balance and not profile.owned.founder_tie,"protected result never granted")
local conflictCmd=command(1,"dark_fedora","hat")
local _,conflict=Economy.transaction(profile,"conflict-op",conflictCmd,Catalog)
check(conflict.code=="roll_request_conflict" and profile.receipts["conflict-op"].code=="roll_request_conflict","conflicting category durable failure")
local empty=Economy.new(Catalog);empty.rolls=0
check(not mutate(empty,1).ok and not empty.owned.black_tie,"zero balance never grants")

-- Bounded receipts retain a permanent monotonic replay floor across reloads.
local many=Economy.new(Catalog);many.rolls=Config.ReceiptLimit+10
for sequence=1,Config.ReceiptLimit+2 do check(mutate(many,sequence).ok,"stress sequence "..sequence) end
check(#many.rollReceiptOrder==Config.ReceiptLimit and many.rollReceipts["1-uuidtest0001"]==nil,"successful receipt pruning is bounded")
local oldBalance=many.rolls
check(mutate(many,1).code=="roll_stale_request" and many.rolls==oldBalance,"pruned request cannot spend again")
local reloaded=Economy.migrate(clone(many),Catalog)
check(reloaded.rollSequence==Config.ReceiptLimit+2 and mutate(reloaded,1).code=="roll_stale_request","rejoin preserves replay floor")

-- Daily/full-match/configured server award routes are persisted and idempotent.
local rewards=Economy.new(Catalog)
local _,daily=Economy.transaction(rewards,"daily1",{kind="daily",now=86400},Catalog)
check(daily.rolls==2 and rewards.rolls==7,"daily adds configured two")
Economy.transaction(rewards,"daily2",{kind="daily",now=86400},Catalog)
check(rewards.rolls==7,"daily cannot repeat under a new id")
check(Economy.public(rewards).daily.rewards[3].rolls==2,"daily board supplies configured reward DTO")
Economy.transaction(rewards,"partial",{kind="reward",participated=true,won=true},Catalog)
check(rewards.rolls==7,"partial lobby round does not award full-match rolls")
local now=os.time()
local _,match=Economy.transaction(rewards,"match-complete",{kind="reward",participated=true,eligibleMatch=true,won=true,now=now},Catalog)
check(match.rolls==2 and rewards.rolls==9,"full match and win grant two together")
rewards.receipts["match-complete"]=nil
Economy.transaction(rewards,"match-complete",{kind="reward",participated=true,eligibleMatch=true,won=true,now=now},Catalog)
check(rewards.rolls==9,"long-lived match receipt survives short UI cache")
local oldAt=now-172801
rewards.matchReceipts.expiredMatch=oldAt
Economy.transaction(rewards,"newMatch",{kind="reward",participated=true,eligibleMatch=true,won=false,now=now},Catalog)
local afterPrune=rewards.rolls
local _,expired=Economy.transaction(rewards,"expiredMatch",{kind="reward",participated=true,eligibleMatch=true,won=true,now=oldAt},Catalog)
check(expired.code=="rewardAlreadySaved" and rewards.rolls==afterPrune,"expired/pruned old match cannot earn twice")
Config.PromoCodes.TEST={rolls=3,endsAt=now+1}
Economy.transaction(rewards,"promo1",{kind="rollAward",source="promo",awardId="TEST",now=now},Catalog)
local awarded=rewards.rolls
Economy.transaction(rewards,"promo2",{kind="rollAward",source="promo",awardId="TEST",now=now},Catalog)
check(awarded==afterPrune+3 and rewards.rolls==awarded,"promo once even with new operation identifier")
Config.Events.LATER={rolls=4,startsAt=now+10}
local _,early=Economy.transaction(rewards,"event-early",{kind="rollAward",source="event",awardId="LATER",now=now},Catalog)
check(not early.ok and rewards.rolls==awarded,"configured award time gate enforced")

-- Actual Profiles + Service use frozen draws and recover lost DataStore replies.
local function freshService()
    run.studio=false;prepared={};validated={};store.mode=nil;store.data=nil;store.writes=0;store.callbackCount=0;draws=0
    local profiles=Profiles.new();check(profiles:load(7),"production stub loads profile")
    return profiles,Service.new(profiles)
end
local profiles,service=freshService()
prepared.agent_gloves=false
local noModel=service:roll(player,"gloves","1-modelmissing")
check(noModel.code=="roll_no_items" and store.data.rolls==5 and draws==0,"no valid prepared model means no draw/no spend")
profiles,service=freshService();validated.agent_gloves=false
local invalidRig=service:roll(player,"gloves","1-invalidrig00")
check(invalidRig.code=="roll_no_items" and store.data.rolls==5,"invalid attachment means no spend")
profiles,service=freshService();store.mode="after"
local uncertain=service:roll(player,"gloves","1-unknown00001")
check(uncertain.code=="save_failed" and profiles.cache[7]==nil,"unknown outcome invalidates cache")
check(store.data.rolls==4 and store.data.itemCounts.agent_gloves==1 and draws==1,"repeated UpdateAsync callbacks retain one draw/charge/grant")
store.mode=nil
local recovered=service:roll(player,"gloves","1-unknown00001")
check(recovered.ok and recovered.replayed and store.data.rolls==4 and draws==1,"same-id retry reloads durable result")
check(recovered.itemId=="agent_gloves" and profiles:public(7).rolls==4,"recovered result and profile match")
profiles,service=freshService();store.mode="before"
local failed=service:roll(player,"gloves","1-before000001")
check(failed.code=="save_failed" and store.data.rolls==5 and not store.data.owned.agent_gloves,"failed write does not spend")
store.mode=nil
clock+=1
local retried=service:roll(player,"gloves","1-before000001")
check(retried.ok and store.data.rolls==4,"same-id retry succeeds when failed write never committed")
profiles,service=freshService();profiles.cache[7]=nil
local nested
store.onRead=function()nested=service:roll(player,"gloves","1-nested000001")end
local loading=service:roll(player,"gloves","1-loading00001")
check(loading.ok and nested.code=="slowDown" and store.writes==3,"concurrent missing-cache recovery only loads once")
local DTO=service:snapshot(player,profiles:public(7))
check(DTO.sequence==1 and #DTO.categories==8,"category/sequence snapshot supplies client")
local lucky=Service.new(profiles,{hasLuck=function()return true end})
local luckDTO=lucky:snapshot(player,profiles:public(7))
local tieRow
for _,row in ipairs(luckDTO.categories)do if row.id=="tie" then tieRow=row end end
local total=0 for _,chance in pairs(tieRow.chances)do total+=chance end
check(math.abs(total-100)<1e-8 and luckDTO.lucky,"legacy lucky odds disclosed and normalized")
Config.Events.ACHIEVEMENT={rolls=3,achievement="first_win"}
local beforeAward=store.data.rolls
local notReady=service:award(player,"event","ACHIEVEMENT")
check(not notReady.ok and store.data.rolls==beforeAward,"event prerequisite failure preserves wallet")
store.data.clubProgress.unlocked.first_win=true
local readyAward=service:award(player,"event","ACHIEVEMENT")
check(readyAward.ok and store.data.rolls==beforeAward+3,"same event can redeem after prerequisite changes")
service:award(player,"event","ACHIEVEMENT")
check(store.data.rolls==beforeAward+3,"per-attempt event requests still grant once")

-- Studio follows production rollback semantics when a mutation throws.
run.studio=true
local studio=Profiles.new();studio:load(7)
local originalEquip=Inventory.equip
Inventory.equip=function()error("simulated assembly rule error")end
local studioFailure=studio:transact(7,"studio-error",command(1,"black_tie"))
Inventory.equip=originalEquip
check(not studioFailure.ok and studio.studioRecords[7].rolls==5 and not studio.studioRecords[7].owned.black_tie,"Studio transaction error cannot leave half grant")
check(Catalog.ById.obsidian_frame.price==1980 and Catalog.ById.velvet_patron.price==900,"legacy nonwearables retain deterministic acquisition")
print("Accessory roll integration: "..assertions.." assertions passed (Roblox services/assets stubbed; no Play Test)")
