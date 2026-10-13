-- SPY CLUB PREMIUM SHOP V1 :: Cases
local Inventory=require(script and script.Parent.Inventory or "Inventory")
local Cases={}

local function spendCaseCoins(profile,amount,allowPaidCoins)
	local reserve=math.clamp(math.floor(profile.paidCoinReserve or 0),0,profile.coins)
	local earned=profile.coins-reserve
	if earned>=amount then profile.coins-=amount return true end
	if not allowPaidCoins or profile.coins<amount then return false end
	local paidNeeded=amount-earned
	profile.coins-=amount
	profile.paidCoinReserve=math.max(0,reserve-paidNeeded)
	return true
end

function Cases.open(profile,command,catalog)
	local caseId=command.caseId or "midnight"
	local case=catalog.Cases and catalog.Cases[caseId]
	if not case then return {ok=false,code="invalid_item"} end
	local rolls=command.rolls
	if type(rolls)~="table" or (#rolls~=1 and #rolls~=2) then return {ok=false,code="invalid_item"} end
	for _,roll in ipairs(rolls) do
		if type(roll)~="number" or roll%1~=0 or roll<1 or roll>(case.rollMax or 100) then return {ok=false,code="invalid_item"} end
	end
	profile.freeCases=profile.freeCases or {}
	profile.paidCoinReserve=math.clamp(math.floor(profile.paidCoinReserve or 0),0,profile.coins)
	local free=(profile.freeCases[caseId] or 0)>0
	local balanceBefore=profile.coins
	local chosen=#rolls==2 and catalog.resolveLuckyRoll(caseId,rolls[1],rolls[2]) or catalog.resolveCaseRoll(caseId,rolls[1])
	if not chosen then return {ok=false,code="invalid_item"} end
	if not free and not spendCaseCoins(profile,case.price,command.allowPaidCoins==true) then return {ok=false,code="not_enough"} end
	-- A duplicate is a saved, tradeable copy. It is never paid out a second time as cashback.
	local fresh,quantity=Inventory.grant(profile,chosen,true)
	local refund=0
	if free then profile.freeCases[caseId]=math.max(0,(profile.freeCases[caseId] or 1)-1) end
	profile.coins+=refund
	return {ok=true,code="opened",itemId=chosen.id,caseId=caseId,duplicate=not fresh,refund=refund,coins=refund,cost=free and 0 or case.price,balanceBefore=balanceBefore,balanceAfter=profile.coins,quantity=quantity,free=free,lucky=#rolls==2}
end
return Cases
