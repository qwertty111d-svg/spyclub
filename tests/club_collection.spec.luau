local Catalog=loadModule('Catalog')
local Economy=loadModule('Economy')
local Daily=loadModule('Daily')
local Config=loadModule('DailyRewardConfig')
local Shop=loadModule('ClubStoreConfig')
local p=Economy.new(Catalog)
local day=20000
local schedule=Daily.status(p,day*86400)
check((schedule.reward.rolls or 0)==0 and schedule.reward.coins==150,'first day must be a real coin reward, not another two Rolls')
local initialRolls=p.rolls
local weeklyRolls=0
for index=1,7 do
 local preview=Daily.status(p,(day+index-1)*86400)
 check(preview.nextStreak==index,'consecutive UTC day advances weekly reward')
 local receipt=Daily.claim(p,(day+index-1)*86400,Catalog)
 check(receipt.ok and (receipt.rolls or 0)==(preview.reward.rolls or 0),'actual Rolls match visible reward')
 check((receipt.coins or 0)==(preview.reward.coins or 0),'actual coins match visible reward')
 check((receipt.xp or 0)==(preview.reward.xp or 0),'actual XP matches visible reward')
 if index==5 then check(Daily.status(p,(day+index-1)*86400).reward.itemId=='noir_calling_card','claimed card must not immediately be displayed as duplicate coins')end
 local saved=clone(p)
 check(not Daily.claim(p,(day+index-1)*86400,Catalog).ok,'claim cannot repeat on the same UTC day')
 check(p.rolls==saved.rolls and p.coins==saved.coins,'duplicate daily claim never changes wallets')
 weeklyRolls+=receipt.rolls or 0
end
check(weeklyRolls==3 and p.rolls==initialRolls+3,'whole week awards only three Rolls')
check(p.owned.noir_calling_card and p.owned.club_seal_pin,'week grants two actual themed collectibles')
check(Daily.status(p,(day+7)*86400).nextStreak==1,'seven-day series cycles')
check(Daily.status(p,(day+10)*86400).nextStreak==1,'missed day starts a fresh week')
p.dailyDay=(day+10)-1;p.dailyStreak=4
local repeated=Daily.status(p,(day+10)*86400)
check(repeated.reward.itemId==nil and repeated.reward.coins==200,'owned card previews fixed compensation')
local compensation=Daily.claim(p,(day+10)*86400,Catalog)
check(compensation.coins==200 and compensation.itemId==nil,'owned card grants exactly the advertised compensation')
local buyer=Economy.new(Catalog);buyer.coins=2000;buyer.paidCoinReserve=1000
local beforeRolls=buyer.rolls
local function purchase(id,request)
 local _,receipt=Economy.transaction(buyer,'club:'..request,{kind='clubBuy',itemId=id},Catalog)
 return receipt
end
check(purchase('velvet_lapel_pin','first').ok and buyer.owned.velvet_lapel_pin,'fixed-price shop grants a real item')
check(buyer.coins==1400 and buyer.rolls==beforeRolls,'coin purchase spends six hundred coins and no Rolls')
check(buyer.paidCoinReserve==400,'deterministic purchase preserves legacy paid-coin accounting')
check(purchase('velvet_lapel_pin','first').ok and buyer.coins==1400,'same coin transaction is idempotent')
check(not purchase('velvet_lapel_pin','duplicate').ok and buyer.coins==1400,'owned nonconsumable cannot be bought twice')
check(not purchase('gold','outside-shop').ok,'coin storefront cannot expose arbitrary legacy items')
buyer.pendingTrade={id='pending'}
check(not purchase('burnished_watch','trade').ok and buyer.coins==1400,'trade lock prevents collection mutation')
buyer.pendingTrade=nil;buyer.coins=100;buyer.paidCoinReserve=0
check(not purchase('burnished_watch','poor').ok and not buyer.owned.burnished_watch,'insufficient coins never grant the item')
local Rules=loadModule('AccessoryRollRules')
for _,item in ipairs(Catalog.Items)do
 if item.coinOnly or item.dailyOnly then
  for _,category in ipairs(loadModule('AccessoryRollConfig').Categories)do
   check(not Rules.allowed(item,category,buyer,Catalog),'deterministic collectible never dilutes paid random pools')
  end
 end
end
check(#Shop.Items==4,'coin store is a curated four-piece collection')
print('Club collection: '..assertions..' assertions passed')
