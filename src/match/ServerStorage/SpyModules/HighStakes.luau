-- Free skill contract. No wallet buy-in or player-funded prize pool.
local HighStakes={Level=3,Stake=0,WinBonus=25,LegacyStake=100}
function HighStakes.eligible(profile)
    return profile and (profile.xp or 0)>=200
end
function HighStakes.canStake(profile)
    if not HighStakes.eligible(profile) then return false,"levelRequired" end
    return true
end
function HighStakes.takeStake(profile)
    local ok,code=HighStakes.canStake(profile)
    if not ok then return {ok=false,code=code} end
    return {ok=true,code="contractReady",coins=0}
end
function HighStakes.payout(won,participated)
    return won==true and participated==true and HighStakes.WinBonus or 0
end
function HighStakes.refund(profile)
    -- Compatibility for an already-recorded old refund; new rounds create no stake ledger.
    profile.coins=profile.coins+HighStakes.LegacyStake
    return {ok=true,code="stakeRefund",coins=HighStakes.LegacyStake}
end
return HighStakes
