-- Actual pure MatchGuide behavior. Rendering and multiplayer still require Studio.
local Guide = assert(loadstring(guideSource, "MatchGuide-under-test"))()
local checks = 0
local function check(value, message)
    checks += 1
    assert(value, message)
end
local function equal(actual, expected, message)
    check(actual == expected, message .. ": " .. tostring(actual) .. " vs " .. tostring(expected))
end
local function contains(actual, expected, message)
    check(string.find(actual, expected, 1, true) ~= nil, message .. ": " .. actual)
end

-- CaseFiles is supplied by the UI; this seam verifies that authored case guidance
-- remains delegated to that provider rather than replaced by classic prompts.
local files = {text = function(lang, key)
    local locale = lang == "en" and "en" or lang == "zh" and "zh" or "ru"
    return "case:" .. locale .. ":" .. key
end}
local localId, otherId = 41, 57

check(type(Guide.context) == "function", "Public round context is available to the stage folio")
equal(Guide.context("en", {phase="Hint",lap=2,hintLaps=3,turnIndex=1,players={{},{},{},{}}}), "ROUND 2/3 · 1/4", "Stage context identifies public lap and speaking order")
equal(Guide.context("zh", {phase="Discuss",lap=1,hintLaps=2}), "第 1/2 轮", "Round context is localized")
equal(Guide.context("en", {phase="TopicVote"}), "SPY CLUB", "Pre-round context does not invent a round")
equal(Guide.context("en", {phase="Unknown"}), "", "Unknown phases have no public context")
equal(Guide.context("en", {phase="Hint",lap=1,hintLaps=2,role="PRIVATE_ROLE",word="PRIVATE_WORD"}), Guide.context("en", {phase="Hint",lap=1,hintLaps=2}), "Round context ignores all private role fields")

check(type(Guide.phase) == "function", "Guide exposes localized public phase labels")
for _, locale in ipairs({
    {"en", "YOUR TURN", "CLUES", "Open your private card", "Give one association", "Listen to the clue"},
    {"ru", "ТВОЙ ХОД", "ПОДСКАЗКИ", "Открой свою личную карточку", "Дай одну ассоциацию", "Слушай подсказку"},
    {"zh", "你的回合", "提示", "打开你的私人卡片", "给出一个联想", "听取提示"},
}) do
    local lang = locale[1]
    equal(Guide.phase(lang, {phase="Hint", turnUserId=localId}, localId), locale[2], lang .. " own hint label")
    equal(Guide.phase(lang, {phase="Hint", turnUserId=otherId}, localId), locale[3], lang .. " listening label")
    contains(Guide.message(files, lang, {phase="Role"}, localId, false), locale[4], lang .. " unopened role card objective")
    contains(Guide.message(files, lang, {phase="Hint", turnUserId=localId}, localId, true), locale[5], lang .. " own association objective")
    contains(Guide.message(files, lang, {phase="Hint", turnUserId=otherId}, localId, true), locale[6], lang .. " listening objective")
end

local ownHint = Guide.message(files, "en", {phase="Hint", turnUserId=localId}, localId, true)
contains(ownHint, "Do not say the secret word", "Hint objective prevents naming the secret")
local unopened = Guide.message(files, "en", {phase="Role"}, localId, false)
local opened = Guide.message(files, "en", {phase="Role"}, localId, true)
check(unopened ~= opened, "Opening the private card advances the role objective")
contains(opened, "Keep your card private", "Opened role card remains private")
contains(Guide.message(files, "en", {phase="Discuss"}, localId, true), "Ask", "Discussion gives a concrete question task")
contains(Guide.message(files, "en", {phase="Discuss"}, localId, true), "Compare", "Discussion connects answers to clues")
contains(Guide.message(files, "en", {phase="Vote"}, localId, true), "Choose a suspect", "Vote objective tells new players what to select")
contains(Guide.message(files, "en", {phase="ExtraRound"}, localId, true), "new association", "Extra round prepares another clue without assuming a tied vote")
contains(Guide.message(files, "en", {phase="Result"}, localId, true), "Review", "Results objective invites review")
contains(Guide.message(files, "en", {phase="Finished"}, localId, true), "rematch", "Finished objective identifies the next action")
contains(Guide.message(files, "en", {phase="TopicVote"}, localId, true), "Choose a theme", "Theme voting has a selection objective")
contains(Guide.message(files, "en", {phase="Intro"}, localId, true), "briefing", "Intro explains the next step")
contains(Guide.message(files, "en", {phase="Waiting"}, localId, true), "Wait", "Waiting identifies the pending transition")

for _, phase in ipairs({"Waiting", "TopicVote", "TopicChosen", "Intro", "Role", "Hint", "Discuss", "Vote", "ExtraRound", "Result", "Finished"}) do
    for _, lang in ipairs({"ru", "en", "zh"}) do
        check(#Guide.phase(lang, {phase=phase}, localId) > 0, lang .. " " .. phase .. " has a phase label")
        check(#Guide.message(files, lang, {phase=phase}, localId, true) > 0, lang .. " " .. phase .. " has an actionable objective")
    end
    equal(Guide.phase("unknown", {phase=phase}, localId), Guide.phase("ru", {phase=phase}, localId), phase .. " label defaults to Russian")
    equal(Guide.message(files, nil, {phase=phase}, localId, true), Guide.message(files, "ru", {phase=phase}, localId, true), phase .. " objective defaults to Russian")
end
equal(Guide.phase("en", {phase="Hint"}, nil), "CLUES", "Absent ids never claim the player's turn")

for _, lang in ipairs({"ru", "en", "zh"}) do
    for _, scenario in ipairs({
        {{phase="Role", case={stage="inspect"}}, false, "card"},
        {{phase="Role", case={stage="inspect"}}, true, "inspect"},
        {{phase="Hint", case={stage="testify"}, turnUserId=localId}, true, "testify"},
        {{phase="Hint", case={stage="testify"}, turnUserId=otherId}, true, "hint_wait"},
        {{phase="Discuss", case={stage="defense", defenseId=localId}}, true, "your_defense"},
        {{phase="Discuss", case={stage="defense", defenseId=otherId}}, true, "listen_defense"},
        {{phase="Discuss", case={stage="discuss"}}, true, "discuss"},
        {{phase="Vote", case={stage="vote"}}, true, "vote"},
        {{phase="Result", case={stage="result"}}, true, "review"},
    }) do
        equal(Guide.message(files, lang, scenario[1], localId, scenario[2]), files.text(lang, scenario[3]), lang .. " preserves case task " .. scenario[3])
    end
end
equal(Guide.phase("en", {phase="Hint", case={stage="testify"}, turnUserId=localId}, localId), "YOUR TURN", "Case testimony identifies own speaking turn")
equal(Guide.phase("en", {phase="Hint", case={stage="testify"}, turnUserId=otherId}, localId), "TESTIMONY", "Case testimony uses the case stage")
equal(Guide.phase("ru", {phase="Hint", case={stage="inspect"}}, localId), "УЛИКИ", "Case inspection uses an evidence label")
equal(Guide.phase("en", {phase="Discuss", case={stage="defense", defenseId=localId}}, localId), "YOUR DEFENSE", "Case defense identifies own task")
equal(Guide.phase("zh", {phase="Discuss", case={stage="defense", defenseId=otherId}}, localId), "最后陈述", "Case defense listening label is localized")
equal(Guide.phase("en", {phase="Result", case={stage="result"}}, localId), "CASE REVIEW", "Case result uses case terminology")
for _, stage in ipairs({"inspect", "testify", "defense", "discuss", "vote", "result"}) do
    local state = {phase="Discuss", case={stage=stage, defenseId=otherId}, turnUserId=otherId}
    for _, lang in ipairs({"ru", "en", "zh"}) do
        check(#Guide.phase(lang, state, localId) > 0, lang .. " case " .. stage .. " has a label")
    end
    equal(Guide.phase("unknown", state, localId), Guide.phase("ru", state, localId), "Case " .. stage .. " label defaults to Russian")
    equal(Guide.message(files, "unknown", state, localId, true), Guide.message(files, "ru", state, localId, true), "Case " .. stage .. " keeps the provider's locale fallback")
end

local active = {from=localId, target=otherId, prompt="detail", endAt=20}
local discussion = {phase="Discuss", turnUserId=localId, discussion={active=active}}
equal(Guide.speaker(discussion), otherId, "Question target remains the active speaker")
equal(Guide.speaker({phase="Discuss", case={stage="defense", defenseId=otherId}}), otherId, "Defense speaker remains the suspect")
equal(Guide.speaker({phase="Hint", turnUserId=localId}), localId, "Hint speaker remains the public turn id")
equal(Guide.questionText("en", "detail"), "Give another detail without naming the word.", "Existing question copy is preserved")
equal(Guide.questionText("unknown", "reason"), Guide.questionText("ru", "reason"), "Question copy still defaults to Russian")
equal(Guide.questionText("en", "missing"), "", "Unknown question remains empty")

-- Frozen inputs catch accidental mutation. Deliberate private-looking fields must
-- never affect or appear in guidance, even if a caller mixes card/state payloads.
local public = table.freeze({phase="Hint", turnUserId=localId})
local mixed = table.freeze({phase="Hint", turnUserId=localId, role="private-role-sentinel", word="private-word-sentinel", caseFile="private-case-sentinel"})
equal(Guide.phase("en", public, localId), Guide.phase("en", mixed, localId), "Phase label only depends on public context")
equal(Guide.message(files, "en", public, localId, true), Guide.message(files, "en", mixed, localId, true), "Guidance ignores private card fields")
local frozenCase = table.freeze({phase="Discuss", case=table.freeze({stage="defense", defenseId=otherId})})
equal(Guide.message(files, "en", frozenCase, localId, true), "case:en:listen_defense", "Frozen case input is read without mutation")
for _, invalid in ipairs({false, true, 9, "Hint", {}, {ok=true, code="closed"}, {phase="Unknown"}}) do
    equal(Guide.phase("en", invalid, localId), "", "Nonphase input has no display label")
    equal(Guide.message(files, "en", invalid, localId, false), "", "Nonphase input has no player task")
end
equal(Guide.phase("en", nil, localId), "", "Missing state has no label")
equal(Guide.message(files, "en", nil, localId, false), "", "Missing state has no task")

-- Existing timed question ownership and public snapshots remain unchanged.
local now = 0
local d = Guide.newDiscussion({localId, otherId}, "round", function() return now end, 30)
equal(d:ask(localId, otherId, "detail", "round").ok, true, "Question request still succeeds")
equal(d:public().active.target, otherId, "Question snapshot preserves its target")
equal(d:ask(otherId, localId, "reason", "round").code, "busy", "Active question still blocks another request")
equal(d:finish(localId, 1, "round").code, "invalid", "Only the target can finish answering")
equal(d:finish(otherId, 1, "round").ok, true, "Question target can finish answering")
equal(d:ask(localId, otherId, "detail", "round").code, "used", "One question per player remains enforced")
equal(d:ask(otherId, localId, "reason", "round").ok, true, "Other player retains a question")
now = 8
equal(d:tick(), true, "Eight-second answer deadline still expires")
equal(d:public().active, nil, "Expired answers are removed from public state")

print("MatchGuide: " .. checks .. " assertions passed (actual module; pure presentation and preserved discussion contracts)")
