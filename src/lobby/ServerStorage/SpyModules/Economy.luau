-- SPY CLUB PREMIUM SHOP V1 :: Economy
-- Pure rules; transactions and Roblox services live in Profiles.lua.
local Economy = {}

Economy.RankBands={
	{minLevel=1,maxLevel=2,ru="Гость",shortRu="ГОСТЬ",en="Guest",shortEn="GUEST"},
	{minLevel=3,maxLevel=4,ru="Знакомый",shortRu="ЗНАКОМЫЙ",en="Known Guest",shortEn="KNOWN"},
	{minLevel=5,maxLevel=7,ru="Член клуба",shortRu="ЧЛЕН КЛУБА",en="Club Member",shortEn="MEMBER"},
	{minLevel=8,maxLevel=11,ru="Доверенное лицо",shortRu="ДОВЕРЕННЫЙ",en="Confidant",shortEn="CONFIDANT"},
	{minLevel=12,maxLevel=16,ru="Инсайдер",shortRu="ИНСАЙДЕР",en="Insider",shortEn="INSIDER"},
	{minLevel=17,maxLevel=24,ru="Агент",shortRu="АГЕНТ",en="Agent",shortEn="AGENT"},
	{minLevel=25,maxLevel=34,ru="Куратор",shortRu="КУРАТОР",en="Handler",shortEn="HANDLER"},
	{minLevel=35,maxLevel=49,ru="Резидент",shortRu="РЕЗИДЕНТ",en="Resident",shortEn="RESIDENT"},
	{minLevel=50,maxLevel=74,ru="Советник",shortRu="СОВЕТНИК",en="Advisor",shortEn="ADVISOR"},
	{minLevel=75,maxLevel=1000000000,ru="Директор клуба",shortRu="ДИРЕКТОР",en="Club Director",shortEn="DIRECTOR"},
}

function Economy.levelForXP(xp)
	return 1+math.floor(math.max(0,math.floor(xp or 0))/100)
end

function Economy.rankForLevel(level,language)
	-- SPY CLUB uses Russian rank names everywhere, regardless of Roblox client locale.
	level=math.max(1,math.floor(level or 1))
	for index,rank in ipairs(Economy.RankBands) do
		if level>=rank.minLevel and level<=rank.maxLevel then
			return {
				name=rank.ru,
				short=rank.shortRu,
				minLevel=rank.minLevel,
				maxLevel=rank.maxLevel,
			},index
		end
	end
	local rank=Economy.RankBands[#Economy.RankBands]
	return {
		name=rank.ru,
		short=rank.shortRu,
		minLevel=rank.minLevel,
		maxLevel=rank.maxLevel,
	},#Economy.RankBands
end

local function copy(v)
	if type(v)~='table' then return v end
	local result={} for k,value in pairs(v) do result[k]=copy(value) end return result
end
local Daily=require(script and script.Parent.Daily or "Daily")
local Inventory=require(script and script.Parent.Inventory or "Inventory")
local Rewards=require(script and script.Parent.Rewards or "Rewards")
local Cases=require(script and script.Parent.Cases or "Cases")
local HighStakes=require(script and script.Parent.HighStakes or "HighStakes")
local ClubProgress=require(script and script.Parent.ClubProgress or "ClubProgress")
local Preferences=require(script and game:GetService("ReplicatedStorage").SpyShared.Preferences or "Preferences")
local RollConfig=require(script and game:GetService("ReplicatedStorage").SpyShared.AccessoryRollConfig or "AccessoryRollConfig")
local RollRules=require(script and script.Parent.AccessoryRollRules or "AccessoryRollRules")
local Identity=require(script and game:GetService("ReplicatedStorage").SpyShared.CharacterIdentity or "CharacterIdentity")
local inventoryCommands={buy=true,capsule=true,accessoryRoll=true,equip=true,sell=true,useGadget=true,grantCosmetics=true,adminGrantItem=true,daily=true,vincentClaim=true}
function Economy.isTradeLocked(p,command)
 if type(p.pendingTrade)~="table" then return false end
 if command.kind=="paidGrant" then return type(command.ids)=="table" and #command.ids>0 end
 return inventoryCommands[command.kind]==true
end
local function validPhoneNote(text)
 if type(text)~="string" or #text>16384 or text:find("[%z\1-\8\11\12\14-\31]") then return false end
 local length=utf8.len(text)
 return length~=nil and length<=4096
end
local function phoneData(value)
 value=type(value)=="table" and value or {}
 local revision=value.noteRevision
 if type(revision)~="number" or revision~=revision or revision<0 or revision%1~=0 or revision>1000000000 then revision=0 end
 local at=value.noteSavedAt
 if type(at)~="number" or at~=at or at<0 or at%1~=0 then at=0 end
 return {note=validPhoneNote(value.note) and value.note or "",noteRevision=revision,noteSavedAt=at}
end
local function counter(value,maxValue)
 if type(value)~="number"or value~=value or value<0 or value==math.huge then return 0 end
 return math.min(maxValue,math.floor(value))
end
local function billiardsData(value)
 value=type(value)=="table"and value or{}
 local runs={};local count=0
 for id,at in pairs(type(value.runs)=="table"and value.runs or{})do
  if type(id)=="string"and #id<=80 and id:match("^[%w_-]+$")and type(at)=="number"and at==at and at>=0 and at<math.huge and count<256 then runs[id]=at;count+=1 end
 end
 return{bestScore=counter(value.bestScore,50),attempts=counter(value.attempts,1000000000),lastScore=counter(value.lastScore,50),runs=runs}
end
local function migrateRolls(p)
    if p.rolls==nil then p.rolls=RollConfig.Rewards.starter end
    -- Historical Rolls came from play/rewards; preserve their earned provenance.
    p.paidRollReserve=p.paidRollReserve or 0
    p.rollSequence=p.rollSequence or 0
    p.rollReceipts=type(p.rollReceipts)=="table" and p.rollReceipts or {}
    p.rollReceiptOrder=type(p.rollReceiptOrder)=="table" and p.rollReceiptOrder or {}
    p.rollAwards=type(p.rollAwards)=="table" and p.rollAwards or {}
    p.matchReceiptFloor=p.matchReceiptFloor or 0
    if p.rollMigrationVersion~=RollConfig.Version then
        p.legacyFreeCases=type(p.legacyFreeCases)=="table" and p.legacyFreeCases or {}
        -- One free case becomes one free category roll, once. Preserve an audit
        -- record; never leave a second redeemable copy in the old balance.
        for id,value in pairs(p.freeCases or {}) do
            if type(id)=="string" and type(value)=="number" and value==value and value>0 and value<math.huge then
                local amount=math.min(RollConfig.MaxRolls,math.floor(value))
                p.legacyFreeCases[id]=(p.legacyFreeCases[id] or 0)+amount
                p.rolls=math.min(RollConfig.MaxRolls,p.rolls+amount)
            end
        end
        p.freeCases={}
        p.rollMigrationVersion=RollConfig.Version
    end
end
function Economy.new(catalog)
	local p={schema=3, revision=0, coins=catalog.WelcomeCoins, coinsEarned=catalog.WelcomeCoins, xp=0, rounds=0, wins=0, milestone=false,
		language="ru", owned={classic=true, soft=true}, equipped={card="classic", effect="soft", trinket=""}, receipts={}, receiptOrder={},matchReceipts={},
		quantities={},setRewards={},dailyDay=-1,dailyStreak=0,freeCases={},supporters=0,history={},purchaseReceipts={},paidCoinReserve=0,paidStakeReserve=0,lobbyTourSeen=false}
	Inventory.initialize(p)
	migrateRolls(p)
	p.identity=Identity.default()
	p.settings=Preferences.defaults()
	p.phone=phoneData(p.phone)
 p.billiards=billiardsData(p.billiards)
	ClubProgress.migrate(p)
	return p
end
function Economy.migrate(p,catalog)
	if not Economy.validate(p) then return nil end
	p.schema=3
	migrateRolls(p)
	p.identity=Identity.sanitize(p.identity)
 p.phone=phoneData(p.phone)
 p.billiards=billiardsData(p.billiards)
 p.coinsEarned=p.coinsEarned or p.coins
 p.tradeSequence=p.tradeSequence or 0
 p.tradeFinalizedSequence=p.tradeFinalizedSequence or 0
 p.tradeHistory=p.tradeHistory or {}
 if p.tradeInvitesEnabled==nil then p.tradeInvitesEnabled=true end
	if p.lobbyTourSeen == nil then p.lobbyTourSeen = false end
	p.matchReceipts=type(p.matchReceipts)=="table" and p.matchReceipts or {}
	p.quantities=p.quantities or {}
	p.setRewards=p.setRewards or {}
	p.dailyDay=p.dailyDay or -1
	p.dailyStreak=p.dailyStreak or 0
	p.freeCases=p.freeCases or {}
	p.highStakes=nil
	p.supporters=p.supporters or 0
	p.history=p.history or {}
	p.purchaseReceipts=p.purchaseReceipts or {}
	p.paidCoinReserve=p.paidCoinReserve or 0
	p.paidCoinReserve=math.clamp(math.floor(p.paidCoinReserve),0,p.coins)
	p.paidStakeReserve=math.max(0,math.floor(p.paidStakeReserve or 0))
	p.settings=Preferences.sanitize(p.settings or {}) or Preferences.defaults()
	p.settings.language=p.language
	ClubProgress.migrate(p)
	Inventory.initialize(p)
	return p
end
function Economy.validate(p)
	if type(p) ~= "table" or (p.schema ~= 1 and p.schema ~= 2 and p.schema ~= 3) then return false end
    if p.identity~=nil and not Identity.validate(p.identity) then return false end
	for _, k in ipairs({"coins", "xp", "rounds", "wins"}) do
		local v = p[k]
		if type(v) ~= "number" or v ~= v or v < 0 or v % 1 ~= 0 or v > 1000000000 then return false end
	end
    for _,key in ipairs({"rolls","rollSequence","matchReceiptFloor"}) do
        local v=p[key]
        local limit=key=="matchReceiptFloor" and 1000000000000 or RollConfig.MaxRolls
        if v~=nil and (type(v)~="number" or v~=v or v<0 or v%1~=0 or v>limit) then return false end
    end
    local paid=p.paidRollReserve
    if paid~=nil and (type(paid)~="number" or paid~=paid or paid<0 or paid%1~=0 or paid>(p.rolls or 0)) then return false end
    for _,key in ipairs({"rollReceipts","rollReceiptOrder","rollAwards","legacyFreeCases"}) do
        if p[key]~=nil and type(p[key])~="table" then return false end
    end
    if p.rollReceiptOrder and #p.rollReceiptOrder>RollConfig.ReceiptLimit then return false end
    local rollReceiptCount=0
    for id,receipt in pairs(p.rollReceipts or {}) do
        rollReceiptCount+=1
        if rollReceiptCount>RollConfig.ReceiptLimit or not RollRules.sequence(id) or type(receipt)~="table"
            or receipt.ok~=true or not RollConfig.ById[receipt.category] or receipt.sequence~=RollRules.sequence(id)
            or receipt.sequence>(p.rollSequence or 0) then return false end
    end
	if p.coinsEarned~=nil and (type(p.coinsEarned)~="number" or p.coinsEarned~=p.coinsEarned or p.coinsEarned<0 or p.coinsEarned%1~=0 or p.coinsEarned>1000000000000) then return false end
	if p.language ~= "ru" and p.language ~= "en" and p.language ~= "zh" then return false end
	for _,key in ipairs({"quantities","itemCounts","setRewards","history","purchaseReceipts","freeCases"}) do
		if p[key]~=nil and type(p[key])~="table" then return false end
	end
	for _,key in ipairs({"revision","supporters","dailyDay","dailyStreak"}) do
		local v=p[key]
		if v~=nil and (type(v)~="number" or v~=v or v%1~=0 or v<(key=="dailyDay" and -1 or 0)) then return false end
	end
	if p.paidCoinReserve~=nil and (type(p.paidCoinReserve)~="number" or p.paidCoinReserve~=p.paidCoinReserve or p.paidCoinReserve%1~=0 or p.paidCoinReserve<0 or p.paidCoinReserve>p.coins) then return false end
	if p.paidStakeReserve~=nil and (type(p.paidStakeReserve)~="number" or p.paidStakeReserve~=p.paidStakeReserve or p.paidStakeReserve%1~=0 or p.paidStakeReserve<0 or p.paidStakeReserve>1000000000) then return false end
	for _,v in pairs(p.quantities or {}) do
		if type(v)~="number" or v~=v or v%1~=0 or v<0 or v>Inventory.MaxGadgets then return false end
	end
	for id,count in pairs(p.itemCounts or {}) do
		if type(id)~="string" or type(count)~="number" or count~=count or count%1~=0 or count<0 or count>1000000000 then return false end
	end
	return type(p.owned)=="table" and type(p.equipped)=="table" and type(p.receipts)=="table" and type(p.receiptOrder)=="table"
end
local function spendDeterministicCoins(p,amount)
	if p.coins<amount then return false end
	local reserve=math.clamp(math.floor(p.paidCoinReserve or 0),0,p.coins)
	local fromPaid=math.min(reserve,amount)
	p.paidCoinReserve=reserve-fromPaid
	p.coins-=amount
	return true
end
function Economy.apply(p, command, catalog)
 if Economy.isTradeLocked(p,command) then return {ok=false,code="trade_processing"} end
 if command.kind=="tradeSettings" then
  if type(command.enabled)~="boolean" then return {ok=false,code="invalid_item"} end
  p.tradeInvitesEnabled=command.enabled;return {ok=true,code="tradeSettings"}
 end
	local kind = command.kind
 if kind=="billiardsRecord"then
  local score,shots,potted,id,at=command.score,command.shots,command.potted,command.rackId,command.now
  if type(score)~="number"or score~=score or score%1~=0 or score<0 or score>50
   or shots~=5 or type(potted)~="number"or potted~=potted or potted%1~=0 or potted<0 or potted>15
   or type(id)~="string"or #id<1 or #id>80 or not id:match("^[%w_-]+$")
   or type(at)~="number"or at~=at or at<0 or at>=math.huge then return{ok=false,code="invalid_record"}end
  local b=billiardsData(p.billiards);p.billiards=b
  if not b.runs[id]then
   b.runs[id]=at;b.attempts=math.min(1000000000,b.attempts+1);b.lastScore=score;b.bestScore=math.max(b.bestScore,score)
   local count,oldest,oldestAt=0,nil,math.huge
   for key,stamp in pairs(b.runs)do count+=1;if key~=id and stamp<oldestAt then oldest,oldestAt=key,stamp end end
   if count>256 and oldest then b.runs[oldest]=nil end
  end
  return{ok=true,code="billiardsRecord",bestScore=b.bestScore,attempts=b.attempts,lastScore=b.lastScore}
 end
	if kind == "reward" then
		if not command.participated then return {ok=false, code="no_reward"} end
		local bonus=command.highStakes==true and HighStakes.payout(command.won,command.participated)or 0
		local coins = catalog.RoundCoins + (command.won and catalog.WinCoins or 0) + bonus
		p.rounds = p.rounds + 1
		if command.won then p.wins = p.wins + 1 end
		p.xp = p.xp + (command.won and 30 or 20)
		local milestone = not p.milestone and p.rounds >= catalog.MilestoneRounds
		if milestone then p.milestone = true coins = coins + catalog.MilestoneCoins end
		p.coins = p.coins + coins
		local beforeAchievements=p.coins
		local achievements=ClubProgress.onRound(p,command)
		local awardedRolls=command.eligibleMatch==true and (RollConfig.Rewards.completeMatch+(command.won and RollConfig.Rewards.win or 0)) or 0
		p.rolls=math.min(RollConfig.MaxRolls,(p.rolls or 0)+awardedRolls)
		coins+=p.coins-beforeAchievements
		if command.highStakes then p.paidStakeReserve=0 end
		if command.history then table.insert(p.history,1,command.history) while #p.history>3 do table.remove(p.history) end end
		return {ok=true, code="reward", coins=coins, rolls=awardedRolls,rollsBalance=p.rolls,milestone=milestone,achievements=achievements}
	elseif kind=="accessoryRoll" then
        local category=RollConfig.ById[command.category]
        local sequence=RollRules.sequence(command.requestId)
        if not category or not sequence or sequence~=command.sequence or command.prepared~=true then return {ok=false,code="roll_invalid_request"} end
        if sequence~=(p.rollSequence or 0)+1 then return {ok=false,code="roll_stale_request"} end
        if category.identity then
            local current=Identity.sanitize(p.identity)
            local chosen=command.identity
            -- Recheck the durable nationality after preparation. A concurrent
            -- nationality change cannot apply a name drawn from its old pool.
            if command.sourceNationality~=current.nationality then return {ok=false,code="roll_stale_request"} end
            if not Identity.validate(chosen) then return {ok=false,code="roll_invalid_item"} end
            if category.id~="nationality" and chosen.nationality~=current.nationality then return {ok=false,code="roll_invalid_item"} end
            if category.id=="firstName" and chosen.lastName~=current.lastName
                or category.id=="lastName" and chosen.firstName~=current.firstName then return {ok=false,code="roll_invalid_item"} end
            if (p.rolls or 0)<1 then return {ok=false,code="roll_empty"} end
            local fromPaid=(p.rolls or 0)-(p.paidRollReserve or 0)<1
            if fromPaid and command.paidRandomAllowed~=true then return {ok=false,code="roll_paid_restricted"} end
            p.identity=Identity.sanitize(chosen)
            if fromPaid then p.paidRollReserve-=1 end
            p.rolls-=1;p.rollSequence=sequence
            return {ok=true,code="identityRolled",requestId=command.requestId,sequence=sequence,category=category.id,
                value=p.identity[category.id],identity=copy(p.identity),rolls=p.rolls,rollsSpent=1,
                duplicate=current.nationality==p.identity.nationality and current.firstName==p.identity.firstName
                    and current.lastName==p.identity.lastName,lucky=false,replayed=false}
        end
        local item=catalog.ById[command.itemId]
        if not RollRules.allowed(item,category,p,catalog) then return {ok=false,code="roll_style"} end
        if (p.rolls or 0)<1 then return {ok=false,code="roll_empty"} end
        local fromPaid=(p.rolls or 0)-(p.paidRollReserve or 0)<1
        if fromPaid and command.paidRandomAllowed~=true then return {ok=false,code="roll_paid_restricted"} end
        -- Validate ALL prerequisites before touching the wallet or inventory.
        local slot=category.slot
        if not Inventory.EquipSlots[slot] or Inventory.count(p,item.id)>=1000000000 then return {ok=false,code="roll_invalid_item"} end
        local fresh,quantity=Inventory.grant(p,item,true)
        local equipped=Inventory.equip(p,item.id,catalog,{force=true,preserveOtherSlots=true})
        if not equipped.ok then error("Validated roll item cannot equip") end
        if fromPaid then p.paidRollReserve-=1 end
        p.rolls-=1;p.rollSequence=sequence
        return {ok=true,code="accessoryRolled",requestId=command.requestId,sequence=sequence,category=category.id,
            itemId=item.id,rarity=item.rarity,duplicate=not fresh,quantity=quantity,rolls=p.rolls,rollsSpent=1,
            equipped=true,slot=slot,lucky=command.lucky==true,replayed=false,setRewards=Rewards.completeSets(p,catalog)}
	elseif kind=="rollAward" then
        -- Only server-defined events/promocodes, persisted separately from the UI cache.
        local definitions=command.source=="event" and RollConfig.Events or command.source=="promo" and RollConfig.PromoCodes
        local definition=definitions and definitions[command.awardId]
        if not definition or type(definition.rolls)~="number" or definition.rolls~=definition.rolls or definition.rolls<0 or definition.rolls==math.huge then return {ok=false,code="roll_invalid_award"} end
        if type(command.now)~="number" or command.now~=command.now or command.now<0
            or (definition.startsAt and command.now<definition.startsAt) or (definition.endsAt and command.now>=definition.endsAt)
            or (definition.achievement and not ((p.clubProgress or {}).unlocked or {})[definition.achievement]) then return {ok=false,code="roll_award_unavailable"} end
        local key=command.source..":"..command.awardId
        p.rollAwards=p.rollAwards or {}
        if p.rollAwards[key] then return {ok=true,code="rollAwardAlreadySaved",rolls=0,rollsBalance=p.rolls} end
        local amount=math.min(RollConfig.MaxRolls,math.floor(definition.rolls))
        p.rolls=math.min(RollConfig.MaxRolls,(p.rolls or 0)+amount);p.rollAwards[key]=true
        return {ok=true,code="rollAwarded",rolls=amount,rollsBalance=p.rolls}
	elseif kind == "buy" then
		local item = catalog.ById[command.itemId]
		if not item or item.price <= 0 then return {ok=false, code="invalid_item"} end
		if p.owned[item.id] and item.kind~="gadget" then return {ok=false, code="already_owned"} end
		if item.kind=="gadget" and (p.quantities[item.id] or 0)+(item.quantity or 1)>Inventory.MaxGadgets then return {ok=false,code="gadgetFull"} end
		if not spendDeterministicCoins(p,item.price) then return {ok=false, code="not_enough"} end
		Inventory.grant(p,item)
		return {ok=true, code="bought", itemId=item.id,setRewards=Rewards.completeSets(p,catalog)}
	elseif kind == "capsule" then
		-- Legacy case balances were converted. Old clients cannot redeem them again.
		return {ok=false,code="use_accessory_roll"}
	elseif kind == "sell" then
		local info = catalog.sellInfo(command.itemId)
		if not info.sellable then return {ok=false,code=info.code or "protected_item",itemId=command.itemId} end
		if p.owned[command.itemId] ~= true then return {ok=false,code="not_owned",itemId=command.itemId} end
		local removed = Inventory.removeOwned(p, command.itemId, catalog)
		if not removed.ok then return removed end
		p.coins = p.coins + info.offer
		return {ok=true,code="sold",itemId=command.itemId,value=info.value,coins=info.offer,remaining=removed.remaining,resetSlots=removed.resetSlots}
	elseif kind == "onboarding" then
		if command.key ~= "lobbyTourSeen" then return {ok=false,code="invalid_item"} end
		p.lobbyTourSeen = true
		return {ok=true,code="onboardingComplete",key="lobbyTourSeen"}
	elseif kind == "equip" then
		return Inventory.equip(p,command.itemId,catalog)
	elseif kind=="daily" then return Daily.claim(p,command.now,catalog)
	elseif kind=="highstakesStake" then
		local before=p.coins
		local result=HighStakes.takeStake(p)
		local spent=math.max(0,before-p.coins)
		if spent>0 then
			local fromPaid=math.min(p.paidCoinReserve or 0,spent)
			p.paidCoinReserve=math.max(0,(p.paidCoinReserve or 0)-fromPaid)
			p.paidStakeReserve=(p.paidStakeReserve or 0)+fromPaid
		end
		return result
	elseif kind=="highstakesRefund" then
		local result=HighStakes.refund(p)
		if result.ok then
			local restorePaid=math.min(p.paidStakeReserve or 0,math.max(0,math.floor(result.coins or 0)))
			p.paidStakeReserve=math.max(0,(p.paidStakeReserve or 0)-restorePaid)
			p.paidCoinReserve=math.min(p.coins,(p.paidCoinReserve or 0)+restorePaid)
		end
		return result
	elseif kind=="useGadget" then
		local receipt=Inventory.use(p,command.itemId,catalog)
		if receipt.ok and command.itemId=="history" then receipt.history=copy(p.history) end
		return receipt
	elseif kind=="paidGrant" then
		local rolls=command.rolls==nil and 0 or command.rolls
		if type(rolls)~="number" or rolls~=rolls or rolls<0 or rolls%1~=0 or rolls>RollConfig.MaxRolls then
			return {ok=false,code="roll_invalid_grant"}
		end
		-- Never acknowledge a paid pack that only partly fits in the wallet.
		if (p.rolls or 0)+rolls>RollConfig.MaxRolls then return {ok=false,code="roll_wallet_full"} end
		local coins=math.clamp(math.floor(command.coins or 0),0,1000000)
		local xp=math.clamp(math.floor(command.xp or 0),0,100000)
		p.coins=p.coins+coins
		p.paidCoinReserve=math.min(p.coins,(p.paidCoinReserve or 0)+coins)
		p.xp=p.xp+xp
		p.rolls=(p.rolls or 0)+rolls
		p.paidRollReserve=(p.paidRollReserve or 0)+rolls
		local granted={}
		for _,id in ipairs(command.ids or {}) do
			local item=catalog.ById[id]
			if item then Inventory.grant(p,item) granted[#granted+1]=id end
		end
		p.supporters+=(math.max(0,math.floor(command.robux or 0)))
		if rolls>0 then
			return {ok=true,code="rollsPurchased",rolls=rolls,rollsBalance=p.rolls,purchaseId=command.purchaseId,
                productId=command.productId,paidRolls=p.paidRollReserve}
		end
		return {ok=true,code="paidGranted",coins=coins,xp=xp,ids=granted,setRewards=Rewards.completeSets(p,catalog)}
	elseif kind=="grantCosmetics" or kind=="support" then
		local granted={}
		local equipped={}
		for _,id in ipairs(command.ids or {}) do
			local item=catalog.ById[id]
			if item then
				Inventory.grant(p,item)
				granted[#granted+1]=id
				if command.autoEquip==true and item.kind~="gadget" then
					local equipReceipt=Inventory.equip(p,id,catalog)
					if equipReceipt and equipReceipt.ok then
						equipped[#equipped+1]=id
					end
				end
			end
		end
		if kind=="support" then p.supporters=p.supporters+math.max(0,math.floor(command.robux or 0)) end
		return {
			ok=true,
			code=kind=="support" and "supportReceived" or "cosmeticsGranted",
			ids=granted,
			equipped=equipped,
			setRewards=Rewards.completeSets(p,catalog),
		}
	-- SPY_ADMIN_ECONOMY_V50
	elseif kind=="adminCoinsDelta" then
		local delta=math.clamp(math.floor(tonumber(command.delta) or 0),-1000000,1000000)
		local before=p.coins
		p.coins=math.max(0,math.min(1000000000,p.coins+delta))
		return {ok=true,code="adminCoinsDelta",before=before,after=p.coins,delta=p.coins-before}
	elseif kind=="adminSetLevel" then
		local level=math.clamp(math.floor(tonumber(command.level) or 1),1,10000)
		local before=1+math.floor(math.max(0,p.xp or 0)/100)
		p.xp=(level-1)*100
		return {ok=true,code="adminSetLevel",before=before,after=level}
	elseif kind=="adminGrantItem" then
		local item=catalog.ById[command.itemId]
		if not item or item.kind=="gadget" then return {ok=false,code="invalid_item"} end
		Inventory.grant(p,item)
		return {ok=true,code="adminGrantItem",itemId=item.id,setRewards=Rewards.completeSets(p,catalog)}
	elseif kind=="caseSolved" then
		if type(command.caseId)~="string" then return {ok=false,code="invalid_case"}end
		return ClubProgress.completeCase(p,command.caseId)
	elseif kind=="tutorialComplete" then
		return ClubProgress.completeCase(p,nil)
	elseif kind=="vincentAccept" then
		return ClubProgress.accept(p,command.now)
	elseif kind=="vincentClaim" then
		return ClubProgress.claim(p,command.now)
	elseif kind=="settings" then
		local clean=Preferences.sanitize(command.settings)
		if not clean then return {ok=false,code="invalid_settings"} end
		p.settings=clean
		p.language=clean.language
		return {ok=true,code="settingsSaved"}
	elseif kind == "language" then
		if command.language ~= "ru" and command.language ~= "en" and command.language ~= "zh" then return {ok=false, code="invalid_item"} end
		p.language = command.language
		p.settings=p.settings or Preferences.defaults()
		p.settings.language=command.language
		return {ok=true, code="language"}
	end
	return {ok=false, code="invalid_item"}
end
-- Gross grants survive spending. Stake returns are transfers of the same
-- coins, so they cannot raise the lifetime board. Receipt replay stays above
-- this accounting boundary in transaction(). No additional DataStore.
local applyCommand=Economy.apply
function Economy.apply(p,command,catalog)
 if command.kind=="phoneNote" then
  if not validPhoneNote(command.text) or type(command.expectedRevision)~="number" or command.expectedRevision%1~=0 or command.expectedRevision<0 or command.expectedRevision>1000000000 then return {ok=false,code="note_invalid"} end
  p.phone=phoneData(p.phone)
 p.billiards=billiardsData(p.billiards)
  if p.phone.noteRevision~=command.expectedRevision then return {ok=false,code="note_conflict"} end
  if p.phone.note~=command.text then
   p.phone.note=command.text;p.phone.noteRevision+=1
   p.phone.noteSavedAt=math.max(0,math.floor(command.now or os.time()))
  end
  return {ok=true,code="note_saved",noteRevision=p.phone.noteRevision,noteSavedAt=p.phone.noteSavedAt}
 end
 local lifetime=p.coinsEarned or p.coins
 local before=p.coins
 local receipt=applyCommand(p,command,catalog)
 local credit=0
 if receipt.ok and command.kind~="highstakesRefund" then
  local cost=command.kind=="capsule" and (receipt.cost or 0)
   or command.kind=="buy" and ((catalog.ById[command.itemId] or {}).price or 0) or 0
  credit=math.max(0,p.coins-before+cost)
 end
 p.coinsEarned=math.min(1000000000000,lifetime+credit)
 return receipt
end
function Economy.transaction(p, operationId, command, catalog)
    -- Replay precedes inventory reservations: returning an already saved result
    -- does not mutate inventory and must still work during a trade.
    if command.kind=="accessoryRoll" then
        local previous=(p.rollReceipts or {})[command.requestId]
        if previous then
            if previous.category~=command.category then
                local receipt={ok=false,code="roll_request_conflict"};p.receipts[operationId]=receipt
                return p,receipt,true
            end
            p.receipts[operationId]=previous
            return p,previous,true
        end
        if (command.sequence or 0)<=(p.rollSequence or 0) then
            local receipt={ok=false,code="roll_stale_request"}
            p.receipts[operationId]=receipt
            return p,receipt,true
        end
    end
 -- A temporary inventory reservation must never poison a paid/UI receipt.
 if Economy.isTradeLocked(p,command) then return p,{ok=false,code="trade_processing"},false end
    p.matchReceipts=p.matchReceipts or {}
    if command.kind=="reward" and (p.matchReceipts[operationId]
        or command.eligibleMatch==true and type(command.now)=="number" and command.now<=(p.matchReceiptFloor or 0)) then
        local receipt=p.receipts[operationId]
        if not receipt then
            receipt={ok=true,code="rewardAlreadySaved",coins=0,rolls=0,rollsBalance=p.rolls}
            p.receipts[operationId]=receipt
            table.insert(p.receiptOrder,operationId)
            while #p.receiptOrder>96 do p.receipts[table.remove(p.receiptOrder,1)]=nil end
        end
        return p,receipt,true
    end
	-- Paid receipts are never pruned with the short-lived UI request cache.
	if command.purchaseId and p.purchaseReceipts[command.purchaseId] then
		local saved=p.purchaseReceipts[command.purchaseId]
		local code=type(saved)=="table" and saved.code or "supportReceived"
		local receipt={ok=true,code=code,rolls=0,rollsBalance=p.rolls,purchaseId=command.purchaseId,
            productId=type(saved)=="table" and saved.productId or nil,replayed=true}
		p.receipts[operationId]=receipt
		return p,receipt,true
	end
	local previous=p.receipts[operationId]
	-- Capacity/policy can recover. A rejected payment must remain retryable.
	if previous and not (command.purchaseId and not previous.ok)
		and previous.code~="roll_paid_restricted" then return p, previous, true end
	local receipt = Economy.apply(p, command, catalog)
	p.paidCoinReserve=math.clamp(math.floor(p.paidCoinReserve or 0),0,p.coins)
	p.paidStakeReserve=math.max(0,math.floor(p.paidStakeReserve or 0))
	p.revision = (p.revision or 0) + 1
	p.receipts[operationId] = receipt
    if command.kind=="accessoryRoll" and receipt.ok then
        p.rollReceipts=p.rollReceipts or {};p.rollReceiptOrder=p.rollReceiptOrder or {}
        p.rollReceipts[command.requestId]=copy(receipt)
        table.insert(p.rollReceiptOrder,command.requestId)
        while #p.rollReceiptOrder>RollConfig.ReceiptLimit do p.rollReceipts[table.remove(p.rollReceiptOrder,1)]=nil end
    end
    if command.kind=="reward" and receipt.ok then
        local stamp=os.time()
        p.matchReceipts[operationId]=stamp
        for id,at in pairs(p.matchReceipts) do
            if type(at)~="number" or at<stamp-172800 then
                if type(at)=="number" then p.matchReceiptFloor=math.max(p.matchReceiptFloor or 0,at) end
                p.matchReceipts[id]=nil
            end
        end
    end
	if command.purchaseId and receipt.ok then
        p.purchaseReceipts[command.purchaseId]={code=receipt.code,rolls=receipt.rolls or 0,productId=receipt.productId}
    end
	table.insert(p.receiptOrder, operationId)
	while #p.receiptOrder > 96 do
		local old = table.remove(p.receiptOrder, 1)
		p.receipts[old] = nil
	end
	return p, receipt, false
end
function Economy.public(p,includeHistory)
	if not p then return {ready=false} end
	local owned, equipped = {}, {}
	for id, value in pairs(p.owned) do if value == true then owned[id] = true end end
	for k, value in pairs(p.equipped) do equipped[k] = value end
	local level=Economy.levelForXP(p.xp)
	local rank,rankIndex=Economy.rankForLevel(level,p.language)
	local xpIntoLevel=math.max(0,math.floor(p.xp or 0))%100
	local xpToNextLevel=100-xpIntoLevel
	local nextBand=Economy.RankBands[rankIndex+1]
	local nextRank=nextBand and nextBand.ru or nil
	local nextRankLevel=nextBand and nextBand.minLevel or nil
	local levelsToNextRank=nextRankLevel and math.max(0,nextRankLevel-level) or 0
	return {ready=true, revision=p.revision or 0, identity=Identity.sanitize(p.identity),coins=p.coins, rolls=p.rolls or 0,
        paidRolls=p.paidRollReserve or 0,earnedRolls=math.max(0,(p.rolls or 0)-(p.paidRollReserve or 0)),
        rollSequence=p.rollSequence or 0,appearanceStyleGroup=p.appearanceStyleGroup,coinsEarned=p.coinsEarned or p.coins, xp=p.xp, rounds=p.rounds, wins=p.wins, milestone=p.milestone,
		billiards={bestScore=counter((p.billiards or{}).bestScore,50),attempts=counter((p.billiards or{}).attempts,1000000000),lastScore=counter((p.billiards or{}).lastScore,50)},language=p.language,settings=copy(p.settings or Preferences.defaults()),club=ClubProgress.public(p,os.time()), owned=owned, itemCounts=copy(p.itemCounts or {}), equipped=equipped, level=level,rank=rank.name,rankShort=rank.short,rankIndex=rankIndex,
		xpIntoLevel=xpIntoLevel,xpToNextLevel=xpToNextLevel,xpProgress=xpIntoLevel/100,losses=math.max(0,p.rounds-p.wins),winRate=p.rounds>0 and p.wins/p.rounds*100 or 0,xpToNextRank=nextRankLevel and math.max(0,(nextRankLevel-1)*100-p.xp) or 0,nextRank=nextRank,nextRankLevel=nextRankLevel,levelsToNextRank=levelsToNextRank,quantities=copy(p.quantities or {}),
		setRewards=copy(p.setRewards or {}),dailyDay=p.dailyDay or -1,dailyStreak=p.dailyStreak or 0,freeCases=copy(p.freeCases or {}),supporters=p.supporters or 0,
		tradeInvitesEnabled=p.tradeInvitesEnabled~=false,pendingTrade=p.pendingTrade and {id=p.pendingTrade.id,applied=p.pendingTrade.applied==true} or nil,tradeHistory=copy(p.tradeHistory or {}),lobbyTourSeen=p.lobbyTourSeen==true,history=includeHistory and copy(p.history or {}) or nil,eligibleHighStakes=HighStakes.eligible(p),daily=Daily.status(p,os.time())}
end
return Economy
