-- Persistent club progress. Pure rules; called only by server Economy transactions.
local Progress = {}
local definitions = {
    {id="first_night",metric="matches",target=1,reward=40,nameRu="Первая ночь",nameEn="First night",detailRu="Завершить первую партию",detailEn="Finish your first match"},
    {id="first_win",metric="wins",target=1,reward=80,nameRu="Хорошее начало",nameEn="A good start",detailRu="Одержать первую победу",detailEn="Win your first match"},
    {id="regular10",metric="matches",target=10,reward=120,nameRu="Уже знакомы",nameEn="A familiar face",detailRu="Завершить 10 партий",detailEn="Finish 10 matches"},
    {id="wins25",metric="wins",target=25,reward=400,nameRu="Холодный расчёт",nameEn="Cold calculation",detailRu="Выиграть 25 партий",detailEn="Win 25 matches"},
    {id="spy1",metric="spyWins",target=1,reward=100,nameRu="Чистый выход",nameEn="Clean exit",detailRu="Впервые выиграть шпионом",detailEn="Win as the spy for the first time"},
    {id="spy50",metric="spyWins",target=50,reward=1500,nameRu="Легенда прикрытия",nameEn="Undercover legend",detailRu="Выиграть 50 партий шпионом",detailEn="Win 50 matches as the spy"},
    {id="first_read10",metric="firstCorrect",target=10,reward=350,nameRu="Вижу насквозь",nameEn="Read you like a book",detailRu="10 раз первым вычислить шпиона",detailEn="Identify the spy first 10 times"},
    {id="survivor10",metric="survivedVotes",target=10,reward=300,nameRu="Железное алиби",nameEn="Ironclad alibi",detailRu="10 раз пережить голосование против себя",detailEn="Survive a ballot against you 10 times"},
    {id="spy10",metric="spyWins",target=10,reward=500,nameRu="Без следа",nameEn="No trace",detailRu="Выиграть 10 матчей шпионом",detailEn="Win 10 matches as the spy"},
    {id="first_read",metric="firstCorrect",target=1,reward=200,nameRu="Первым заметил",nameEn="First to notice",detailRu="Первым проголосовать за шпиона в решающем голосовании",detailEn="Be the first to vote for the spy in the decisive ballot"},
    {id="survivor",metric="survivedVotes",target=1,reward=150,nameRu="Под подозрением",nameEn="Under suspicion",detailRu="Получить голос против себя и пережить голосование",detailEn="Receive a vote against you and survive the ballot"},
    {id="regular100",metric="matches",target=100,reward=1000,nameRu="Свой человек",nameEn="One of us",detailRu="Сыграть 100 матчей",detailEn="Play 100 matches"},
}
local rumors = {
    {"Кто повторяет чужую подсказку, иногда просто боится сказать свою.","Someone repeating another clue might be afraid to give their own."},
    {"Вчера один гость молчал весь вечер. Шпионом оказался тот, кто его торопил.","A guest stayed quiet all evening yesterday. The spy was the one rushing him."},
    {"Слишком точная подсказка помогает не только друзьям. Шпион тоже слушает.","A clue that's too precise helps more than your friends. The spy is listening too."},
    {"Не спеши обвинять первого, кто замялся. Иногда человек просто подбирает слова.","Don't accuse the first person to hesitate. Sometimes they're just choosing their words."},
    {"Хорошая подсказка понятна своим. Остальным остаётся делать уверенное лицо.","A good clue makes sense to those who know. The rest have to look confident."},
    {"Если за столом все согласны слишком быстро, послушай того, кто предложил ответ.","When everyone agrees too quickly, listen to whoever suggested the answer."},
    {"Самый уверенный голос не всегда самый честный. Ты это ещё увидишь.","The most confident voice isn't always the most honest. You'll see."},
}
local function count(value)
    if type(value)~="number" or value~=value or value==math.huge then return 0 end
    return math.clamp(math.floor(value),0,1000000000)
end
local function dayAt(now) return math.floor(now/86400) end

function Progress.migrate(profile)
    if type(profile.clubProgress)~="table" then
        profile.clubProgress={metrics={matches=count(profile.rounds)},unlocked={}}
    end
    local state=profile.clubProgress
    if type(state.metrics)~="table" then state.metrics={} end
    if type(state.unlocked)~="table" then state.unlocked={} end
    if state.metrics.wins==nil then state.metrics.wins=count(profile.wins) end
    for _,definition in ipairs(definitions) do
        state.metrics[definition.metric]=count(state.metrics[definition.metric])
    end
    if type(state.vincent)~="table" then state.vincent={day=-1} end
    if type(state.caseFiles)~="table" then state.caseFiles={} end
    local archive=state.caseFiles
    if type(archive.completed)~="table" then archive.completed={} end
    archive.tutorial=archive.tutorial==true
    for id,value in pairs(archive.completed)do
        if not ({cassette=true,envelope=true,call=true})[id]or value~=true then archive.completed[id]=nil end
    end
    return state
end

function Progress.completeCase(profile,id)
    local archive=Progress.migrate(profile).caseFiles
    if id==nil then archive.tutorial=true
    elseif ({cassette=true,envelope=true,call=true})[id]then archive.completed[id]=true
    else return {ok=false,code="invalid_case"}end
    return {ok=true,code="case_saved"}
end

function Progress.onRound(profile,command)
    local state=Progress.migrate(profile)
    if command.eligibleMatch~=true then return {} end
    state.metrics.matches=math.min(1000000000,state.metrics.matches+1)
    state.metrics.wins=count(profile.wins)
    for flag,metric in pairs({spyWin="spyWins",firstCorrect="firstCorrect",survivedVote="survivedVotes"}) do
        if command[flag]==true then state.metrics[metric]=math.min(1000000000,state.metrics[metric]+1) end
    end
    local unlocked={}
    for _,definition in ipairs(definitions) do
        if state.metrics[definition.metric]>=definition.target and not state.unlocked[definition.id] then
            state.unlocked[definition.id]=true
            profile.coins+=definition.reward
            table.insert(unlocked,definition.id)
        end
    end
    local taskState=state.vincent
    local timestamp=command.now
    if type(timestamp)=="number" and timestamp==timestamp and taskState.day==dayAt(timestamp)
        and taskState.accepted and not taskState.claimed and timestamp>=(taskState.acceptedAt or 0) then
        taskState.completed=true
    end
    return unlocked
end

function Progress.accept(profile,now)
    local state=Progress.migrate(profile)
    local day=dayAt(now)
    if state.vincent.day==day and state.vincent.accepted then
        return {ok=false,code="vincentAlreadyAccepted"}
    end
    -- Only the authoritative server clock reaches this function.
    state.vincent={day=day,accepted=true,acceptedAt=now,completed=false,claimed=false}
    return {ok=true,code="vincentAccepted"}
end

function Progress.claim(profile,now)
    local state=Progress.migrate(profile).vincent
    if state.day~=dayAt(now) or not state.accepted or not state.completed then
        return {ok=false,code="vincentNotComplete"}
    end
    if state.claimed then return {ok=false,code="vincentAlreadyClaimed"} end
    state.claimed=true
    profile.coins+=100
    return {ok=true,code="vincentClaimed",coins=100}
end

function Progress.public(profile,now)
    local state=Progress.migrate(profile)
    local day=dayAt(now)
    local rumor=rumors[(day%#rumors)+1]
    local taskState=state.vincent.day==day and state.vincent or {}
    local rows={}
    for _,definition in ipairs(definitions) do
        table.insert(rows,{id=definition.id,nameRu=definition.nameRu,nameEn=definition.nameEn,
            detailRu=definition.detailRu,detailEn=definition.detailEn,target=definition.target,reward=definition.reward,
            value=math.min(definition.target,state.metrics[definition.metric]),unlocked=state.unlocked[definition.id]==true})
    end
    local rare=day%11==3
    return {caseFiles={tutorial=state.caseFiles.tutorial,completed=table.clone(state.caseFiles.completed)},metrics={matches=count(state.metrics.matches),wins=count(state.metrics.wins),spyWins=count(state.metrics.spyWins),firstCorrect=count(state.metrics.firstCorrect),survivedVotes=count(state.metrics.survivedVotes)},achievements=rows,vincent={day=day,rumorRu=rumor[1],rumorEn=rumor[2],
        secretRu=rare and "В клубе есть одно негласное правило: директор никогда не садится спиной к двери. Впрочем, ты этого от меня не слышал." or nil,
        secretEn=rare and "There's an unwritten rule here: the director never sits with his back to the door. You didn't hear that from me." or nil,
        accepted=taskState.accepted==true,completed=taskState.completed==true,claimed=taskState.claimed==true,reward=100}}
end
return Progress
