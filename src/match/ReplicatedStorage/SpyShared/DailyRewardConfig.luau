-- One calendar for the server, previews and claim copy. UTC days, seven-day cycle.
local Config={Version=2,Rewards={
    {day=1,coins=150},
    {day=2,xp=100},
    {day=3,rolls=1},
    {day=4,coins=300},
    {day=5,itemId="noir_calling_card",duplicateCoins=200},
    {day=6,rolls=1,coins=150},
    {day=7,itemId="club_seal_pin",rolls=1,duplicateCoins=400},
}}
function Config.resolve(day,profile)
    local reward=table.clone(Config.Rewards[math.clamp(math.floor(day or 1),1,7)])
    if reward.itemId and profile and (profile.owned or {})[reward.itemId]then
        reward.coins=(reward.coins or 0)+(reward.duplicateCoins or 0)
        reward.itemId=nil;reward.compensated=true
    end
    return reward
end
return Config
