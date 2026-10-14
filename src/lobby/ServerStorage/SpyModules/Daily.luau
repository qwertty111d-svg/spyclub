local Inventory=require(script and script.Parent.Inventory or "Inventory")
local RollConfig=require(script and game:GetService("ReplicatedStorage").SpyShared.AccessoryRollConfig or "AccessoryRollConfig")
local Calendar=require(script and game:GetService("ReplicatedStorage").SpyShared.DailyRewardConfig or "DailyRewardConfig")
local Daily={}
Daily.Rewards=Calendar.Rewards
function Daily.status(profile,now)
    local day=math.floor(now/86400)
    local last=profile.dailyDay or -1
    local streak=profile.dailyStreak or 0
    local nextStreak=(last==day-1) and ((streak%7)+1) or (last==day and streak or 1)
    local cycleStart=last<day and nextStreak==1 and day or last-streak+1
    local rewards={}
    for index=1,7 do
        local saved=(profile.dailyClaimRewards or{})[tostring(index)]
        rewards[index]=saved and saved.claimDay==cycleStart+index-1 and table.clone(saved.reward)or Calendar.resolve(index,profile)
    end
    local current=last==day and rewards[nextStreak]or Calendar.resolve(nextStreak,profile)
    return {available=last<day,nextAt=(day+1)*86400,streak=streak,nextStreak=nextStreak,reward=current,rewards=rewards}
end
function Daily.claim(profile,now,catalog)
    if type(now)~="number" or now~=now or now<0 or now>=math.huge then return {ok=false,code="invalid_item"} end
    local status=Daily.status(profile,now)
    if not status.available then return {ok=false,code="dailyClaimed"} end
    local day=math.floor(now/86400)
    local reward=status.reward
    if reward.itemId and (not catalog or not catalog.ById[reward.itemId])then return {ok=false,code="invalid_item"}end
    profile.dailyDay=day
    profile.dailyStreak=status.nextStreak
    local beforeCoins=profile.coins or 0
    profile.coins=math.min(1000000000,beforeCoins+(reward.coins or 0))
    local coins=profile.coins-beforeCoins
    local beforeXp=profile.xp or 0
    profile.xp=math.min(1000000000,beforeXp+(reward.xp or 0))
    local xp=profile.xp-beforeXp
    local beforeRolls=profile.rolls or 0
    profile.rolls=math.min(RollConfig.MaxRolls,beforeRolls+(reward.rolls or 0))
    local itemId,caseId=reward.itemId,reward.caseId
    if itemId and catalog and catalog.ById[itemId] then Inventory.grant(profile,catalog.ById[itemId]) end
    if caseId then
        profile.freeCases=profile.freeCases or {}
        profile.freeCases[caseId]=(profile.freeCases[caseId] or 0)+1
    end
    if status.nextStreak==1 then profile.dailyClaimRewards={}end
    profile.dailyClaimRewards=profile.dailyClaimRewards or{}
    profile.dailyClaimRewards[tostring(status.nextStreak)]={claimDay=day,reward={day=status.nextStreak,coins=coins,xp=xp,
        rolls=profile.rolls-beforeRolls,itemId=itemId,compensated=reward.compensated}}
    return {ok=true,code="dailyReceived",coins=coins,xp=xp,rolls=profile.rolls-beforeRolls,rollsBalance=profile.rolls,itemId=itemId,caseId=caseId,compensated=reward.compensated,streak=profile.dailyStreak}
end
return Daily
