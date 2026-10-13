local Inventory=require(script and script.Parent.Inventory or "Inventory")
local RollConfig=require(script and game:GetService("ReplicatedStorage").SpyShared.AccessoryRollConfig or "AccessoryRollConfig")
local Daily={}
Daily.Rewards={
    {day=1,coins=80},
    {day=2,coins=120},
    {day=3},
    {day=4,coins=180},
    {day=5,coins=220},
    {day=6},
    {day=7,coins=1000},
}
local function rewardFor(streak)
    local reward=table.clone(Daily.Rewards[math.clamp(streak or 1,1,7)])
    reward.rolls=RollConfig.Rewards.daily
    return reward
end
function Daily.status(profile,now)
    local day=math.floor(now/86400)
    local last=profile.dailyDay or -1
    local streak=profile.dailyStreak or 0
    local nextStreak=(last==day-1) and ((streak%7)+1) or (last==day and streak or 1)
    local rewards={} for index=1,7 do rewards[index]=rewardFor(index) end
    return {available=last<day,nextAt=(day+1)*86400,streak=streak,nextStreak=nextStreak,reward=rewardFor(nextStreak),rewards=rewards}
end
function Daily.claim(profile,now,catalog)
    if type(now)~="number" or now<0 then return {ok=false,code="invalid_item"} end
    local status=Daily.status(profile,now)
    if not status.available then return {ok=false,code="dailyClaimed"} end
    local day=math.floor(now/86400)
    local reward=status.reward
    profile.dailyDay=day
    profile.dailyStreak=status.nextStreak
    local coins=reward.coins or 0
    profile.coins=profile.coins+coins
    local beforeRolls=profile.rolls or 0
    profile.rolls=math.min(RollConfig.MaxRolls,beforeRolls+(reward.rolls or 0))
    local itemId,caseId=reward.itemId,reward.caseId
    if itemId and catalog and catalog.ById[itemId] then Inventory.grant(profile,catalog.ById[itemId]) end
    if caseId then
        profile.freeCases=profile.freeCases or {}
        profile.freeCases[caseId]=(profile.freeCases[caseId] or 0)+1
    end
    return {ok=true,code="dailyReceived",coins=coins,rolls=profile.rolls-beforeRolls,rollsBalance=profile.rolls,itemId=itemId,caseId=caseId,streak=profile.dailyStreak}
end
return Daily
