local Rewards={}
function Rewards.completeSets(profile,catalog)
    profile.setRewards=profile.setRewards or {}
    local granted={}
    for _,set in ipairs(catalog.Sets or {}) do
        local complete=true
        for _,id in ipairs(set.items) do if not profile.owned[id] then complete=false break end end
        if complete and not profile.setRewards[set.id] then
            profile.setRewards[set.id]=true
            profile.owned[set.reward]=true
            granted[#granted+1]=set.reward
        end
    end
    return granted
end
return Rewards
