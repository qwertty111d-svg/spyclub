-- Runoff orchestration wraps the unchanged, exhaustively tested core Rules.
local Voting={}
function Voting.cast(round,voterId,targetId,candidates,rules)
    if candidates then
        local found=false
        for _,id in ipairs(candidates) do if id==targetId then found=true end end
        if not found then return false end
    end
    return rules.castVote(round,voterId,targetId)
end
function Voting.finish(round,wasRunoff,rules)
    local result=rules.resolve(round)
    if not result.accusedId then
        local maximum,leaders=0,{}
        for id,count in pairs(result.counts) do
            if count>maximum then maximum,leaders=count,{id}
            elseif count==maximum and count>0 then leaders[#leaders+1]=id end
        end
        if maximum>0 and #leaders>1 then
            if wasRunoff then result.reason='tie'
            else table.sort(leaders); return nil,leaders end
        end
    end
    return result
end
return Voting
