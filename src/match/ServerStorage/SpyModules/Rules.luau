-- Pure Lua/Luau. No Roblox services: the real game rules are executable in tests.
local Rules = {}

-- Use the existing, newest-first completed-match journal. This stays on the
-- server: clients never submit role history or see selection weights.
function Rules.chooseSpy(ids, historyById, randomInt)
    assert(#ids > 0, "No participants")
    local weights, total = {}, 0
    for i, id in ipairs(ids) do
        local spyStreak, agentStreak = 0, 0
        for _, entry in ipairs((historyById or {})[id] or {}) do
            if type(entry) ~= "table" or type(entry.spyId) ~= "number" then break end
            if entry.spyId == id then
                if agentStreak > 0 then break end
                spyStreak += 1
            else
                if spyStreak > 0 then break end
                agentStreak += 1
            end
            if spyStreak >= 3 or agentStreak >= 3 then break end
        end
        local weight = spyStreak >= 3 and 0
            or spyStreak == 2 and 4
            or spyStreak == 1 and 16
            or 64 + agentStreak * 16
        weights[i] = weight
        total += weight
    end
    if total == 0 then return ids[randomInt(1, #ids)] end
    local roll = randomInt(1, total)
    for i, weight in ipairs(weights) do
        roll -= weight
        if roll <= 0 and weight > 0 then return ids[i] end
    end
    error("Random result outside selection range")
end

function Rules.newRound(ids, words, randomInt, previousWord, historyById)
    assert(#ids == 3 or #ids == 4, "A table requires 3 or 4 players")
    assert(#words > 1, "Word pool must contain at least two words")
    local members, order = {}, {}
    for i, id in ipairs(ids) do
        assert(not members[id], "Duplicate participant")
        members[id], order[i] = true, id
    end
    for i = #order, 2, -1 do
        local j = randomInt(1, i)
        order[i], order[j] = order[j], order[i]
    end
    local choices = {}
    for _, word in ipairs(words) do
        if word ~= previousWord then table.insert(choices, word) end
    end
    assert(#choices > 0, "No fresh word available")
    return {
        order = order,
        members = members,
        spyId = Rules.chooseSpy(ids, historyById, randomInt),
        word = choices[randomInt(1, #choices)],
        votes = {},
    }
end

function Rules.privateCard(round, userId)
    if not round or not round.members[userId] then return nil end
    if userId == round.spyId then return {role = "spy"} end
    return {role = "agent", word = round.word}
end

function Rules.castVote(round, voter, target)
    if not round or not round.members[voter] or not round.members[target] then return false end
    if voter == target or round.votes[voter] ~= nil then return false end
    round.votes[voter] = target
    return true
end

function Rules.voteCount(round)
    local count = 0
    for _ in pairs(round.votes) do count = count + 1 end
    return count
end

function Rules.resolve(round)
    local counts, total = {}, #round.order
    for _, id in ipairs(round.order) do counts[id] = 0 end
    for _, target in pairs(round.votes) do counts[target] = counts[target] + 1 end
    local caught, accused = false, nil
    for _, id in ipairs(round.order) do
        if counts[id] > total / 2 then
            accused, caught = id, id == round.spyId
        end
    end
    return {
        caught = caught,
        accusedId = accused,
        spyId = round.spyId,
        word = round.word,
        counts = counts,
        -- An absolute majority is necessary. Ties / abstentions favor the spy.
        reason = accused and (caught and "caught" or "wrong") or "no_majority",
    }
end

return Rules
