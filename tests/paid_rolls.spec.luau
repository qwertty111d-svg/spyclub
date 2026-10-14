local Catalog=loadModule("Catalog")
local Config=loadModule("AccessoryRollConfig")
local Economy=loadModule("Economy")
local Profiles=loadModule("Profiles")
local Service=loadModule("AccessoryRollService")
local Identity=loadModule("CharacterIdentity")
Wardrobe.Accessories.black_tie={id=1}
local function buy(profile,purchaseId,amount)
    return select(2,Economy.transaction(profile,"purchase:"..purchaseId,
        {kind="paidGrant",rolls=amount,purchaseId=purchaseId,productId=71003,robux=type(amount)=="number" and amount*99 or 0},Catalog))
end
local profile=Economy.new(Catalog)
local receipt=buy(profile,"real-receipt-1",3)
check(receipt.ok and receipt.code=="rollsPurchased" and profile.rolls==8,
    "confirmed payment credits the complete Roll pack to the existing wallet")
check(profile.paidRollReserve==3 and receipt.rolls==3 and receipt.rollsBalance==8
    and receipt.purchaseId=="real-receipt-1" and receipt.productId==71003,"paid provenance and authoritative receipt saved together")
check(profile.supporters==297 and profile.coins==Catalog.WelcomeCoins and profile.xp==0,
    "paid Rolls preserve existing coin and XP balances")
local replay=buy(profile,"real-receipt-1",3)
check(replay.ok and profile.rolls==8 and profile.paidRollReserve==3 and profile.supporters==297,
    "repeated payment cannot credit wallet or support totals twice")
for index=1,110 do Economy.transaction(profile,"ui:"..index,{kind="language",language="en"},Catalog)end
check(profile.receipts["purchase:real-receipt-1"]==nil,"short UI cache actually pruned purchase response")
local reloaded=Economy.migrate(clone(profile),Catalog)
replay=buy(reloaded,"real-receipt-1",3)
check(replay.ok and replay.code=="rollsPurchased" and replay.replayed and replay.rolls==0
    and replay.productId==71003 and reloaded.rolls==8 and reloaded.paidRollReserve==3,"durable paid receipt survives pruning and reload")

local legacy=Economy.new(Catalog);legacy.paidRollReserve=nil
check(Economy.migrate(legacy,Catalog).paidRollReserve==0,"old saved wallets migrate with all existing Rolls earned")
for _,value in ipairs({-1,1.5,0/0,math.huge,"3"})do
    local broken=clone(profile);broken.paidRollReserve=value
    check(not Economy.validate(broken),"invalid paid reserve is rejected without overwriting old profile")
end
local broken=clone(profile);broken.paidRollReserve=broken.rolls+1
check(not Economy.validate(broken),"paid reserve cannot exceed total wallet")
for _,amount in ipairs({-1,1.5,0/0,math.huge,"3"})do
    local before=Economy.new(Catalog)
    local result=buy(before,"invalid",amount)
    check(not result.ok and before.rolls==5 and before.paidRollReserve==0 and not before.purchaseReceipts.invalid,
        "invalid grant cannot spend, partially credit, or mark payment delivered")
end
local full=Economy.new(Catalog);full.rolls=Config.MaxRolls-2
local blocked=buy(full,"capacity",3)
check(not blocked.ok and blocked.code=="roll_wallet_full" and full.rolls==Config.MaxRolls-2
    and full.paidRollReserve==0 and not full.purchaseReceipts.capacity,"full pack capacity failure keeps receipt pending")
full.rolls-=1
check(buy(full,"capacity",3).ok and full.rolls==Config.MaxRolls and full.paidRollReserve==3,
    "same paid receipt succeeds after wallet capacity becomes available")

local function roll(profile,paidAllowed,identity)
    local sequence=(profile.rollSequence or 0)+1
    local requestId=sequence.."-paidtest0001"
    local category=identity and "firstName" or "tie"
    local cmd={kind="accessoryRoll",category=category,requestId=requestId,sequence=sequence,
        prepared=true,itemId="black_tie",paidRandomAllowed=paidAllowed}
    if identity then
        cmd.sourceNationality=profile.identity.nationality;cmd.identity=clone(profile.identity)
        cmd.identity.firstName=Identity.pool("firstName",profile.identity)[2].item.id
    end
    return select(2,Economy.transaction(profile,"roll:"..requestId,cmd,Catalog)),cmd
end
for _,identity in ipairs({false,true})do
    local wallet=Economy.new(Catalog);wallet.rolls=2;wallet.paidRollReserve=1
    local earned=roll(wallet,false,identity)
    check(earned.ok and wallet.rolls==1 and wallet.paidRollReserve==1,"earned Roll spends first even when paid randomness is restricted")
    local denied=roll(wallet,nil,identity)
    check(not denied.ok and denied.code=="roll_paid_restricted" and wallet.rolls==1 and wallet.paidRollReserve==1,
        "unknown policy cannot consume paid-only balance for any category")
    local accepted,cmd=roll(wallet,true,identity)
    check(accepted.ok and wallet.rolls==0 and wallet.paidRollReserve==0,"explicit verified policy permits atomic paid Roll spend")
    cmd.paidRandomAllowed=false
    local old=select(2,Economy.transaction(wallet,"recovery",cmd,Catalog))
    check(old.ok and wallet.rolls==0 and wallet.paidRollReserve==0,"saved roll replays even after policy becomes restricted")
end

-- Use the actual UpdateAsync-backed profiles for unknown write outcome recovery.
run.studio=false;store.data=Economy.new(Catalog);store.mode=nil
local persisted=Profiles.new();check(persisted:load(7),"load existing shared datastore profile")
store.mode="after"
local command={kind="paidGrant",rolls=5,purchaseId="lost-reply",robux=495}
local lost=persisted:transact(7,"purchase:lost-reply",command)
check(not lost.ok and store.data.rolls==10 and store.data.paidRollReserve==5,
    "lost durable response cannot duplicate paid credit on UpdateAsync retries")
store.mode=nil;check(persisted:load(7),"reload after unknown write outcome")
local recovered=persisted:transact(7,"purchase:lost-reply",command)
check(recovered.ok and store.data.rolls==10 and store.data.supporters==495,"retry after reload acknowledges one durable credit")

local policyAllowed=false
local service=Service.new(persisted,{canSpendPaidRolls=function()return policyAllowed end})
persisted.cache[7].rolls=1;persisted.cache[7].paidRollReserve=1
store.data=clone(persisted.cache[7])
local snapshot=service:snapshot(player,persisted:public(7))
check(snapshot.paidRolls==1 and snapshot.earnedRolls==0 and not snapshot.paidAllowed and not snapshot.canSpend,
    "snapshot distinguishes usable earned and policy-restricted paid Rolls")
for _,row in ipairs(snapshot.categories)do
    check(not row.canSpend and row.spendReason==(row.available and "roll_paid_restricted" or "roll_no_items"),
        "category explains the wallet or unavailable-model restriction")
end
local drawsBefore=draws
local denied=service:roll(player,"firstName","1-servicepaid0001")
check(not denied.ok and denied.code=="roll_paid_restricted" and draws==drawsBefore,
    "restricted service fails before choosing any random paid result")
policyAllowed=true;clock+=1
local bought=service:roll(player,"firstName","1-servicepaid0001")
check(bought.ok and store.data.rolls==0 and store.data.paidRollReserve==0,"service passes verified policy to atomic economy")
policyAllowed=false
local saved=service:roll(player,"firstName","1-servicepaid0001")
check(saved.ok and saved.replayed,"cached receipt recovers before current paid policy checks")
print("Paid Roll integration: "..assertions.." assertions passed (official Roblox services stubbed; no Studio Play Test)")
