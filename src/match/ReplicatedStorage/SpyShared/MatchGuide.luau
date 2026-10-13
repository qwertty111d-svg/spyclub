local Guide={}
local phases={
 Waiting={'ОЖИДАНИЕ','WAITING','等待'},
 TopicVote={'ВЫБОР ТЕМЫ','CHOOSE A THEME','选择主题'},
 TopicChosen={'ТЕМА ВЫБРАНА','THEME CHOSEN','主题已选'},
 Intro={'ИНСТРУКТАЖ','BRIEFING','任务说明'},
 Role={'ЛИЧНАЯ КАРТА','PRIVATE CARD','私人卡片'},
 Hint={'ПОДСКАЗКИ','CLUES','提示'},
 Discuss={'ОБСУЖДЕНИЕ','DISCUSSION','讨论'},
 Vote={'ГОЛОСОВАНИЕ','VOTE','投票'},
 ExtraRound={'ЕЩЁ КРУГ','ANOTHER ROUND','再一轮'},
 Result={'ИТОГИ','RESULTS','结果'},
 Finished={'МАТЧ ЗАВЕРШЁН','MATCH FINISHED','比赛结束'},
}
local casePhases={
 inspect={'УЛИКИ','EVIDENCE','线索'},
 testify={'ПОКАЗАНИЯ','TESTIMONY','陈述'},
 defense={'ПОСЛЕДНЕЕ СЛОВО','LAST WORD','最后陈述'},
 your_defense={'ТВОЯ ЗАЩИТА','YOUR DEFENSE','你的陈述'},
 discuss=phases.Discuss,
 vote=phases.Vote,
 result={'РАЗБОР ДЕЛА','CASE REVIEW','案件解析'},
}
local yourTurn={'ТВОЙ ХОД','YOUR TURN','你的回合'}
local function translated(values,lang)
 return values and values[lang=='en'and 2 or lang=='zh'and 3 or 1]or''
end
local function validState(state)
 return type(state)=='table'and phases[state.phase]~=nil
end
local function ownTurn(activeId,id)
 return id~=nil and activeId==id
end
-- Public phase/task context only; private card fields never enter presentation.
function Guide.phase(lang,state,id)
 if not validState(state)then return''end
 local c=type(state.case)=='table'and state.case
 if c then
  if c.stage=='defense'and ownTurn(c.defenseId,id)then return translated(casePhases.your_defense,lang)end
  if c.stage=='testify'and ownTurn(state.turnUserId,id)then return translated(yourTurn,lang)end
  if casePhases[c.stage]then return translated(casePhases[c.stage],lang)end
 end
 if state.phase=='Hint'and ownTurn(state.turnUserId,id)then return translated(yourTurn,lang)end
 return translated(phases[state.phase],lang)
end
local prompts={
 Waiting={'Жди игроков. Раунд начнётся, когда стол будет готов.','Wait for players. The round starts when the table is ready.','等待玩家。桌子准备好后，回合就会开始。'},
 TopicVote={'Выбери тему для этой партии.','Choose a theme for this match.','选择本场比赛的主题。'},
 TopicChosen={'Тема выбрана. Скоро ты получишь личную карточку.','The theme is chosen. Your private card comes next.','主题已选。接下来会收到你的私人卡片。'},
 Intro={'Слушай инструктаж. Затем прочитай свою личную карточку.','Listen to the briefing. Read your private card next.','听取任务说明，然后阅读你的私人卡片。'},
 card={'Открой свою личную карточку. Сохрани роль и слово в секрете.','Open your private card. Keep your role and word secret.','打开你的私人卡片。保守身份和词语的秘密。'},
 Role={'Запомни свою роль. Держи карточку в секрете.','Remember your role. Keep your card private.','记住你的身份。不要给别人看卡片。'},
 hint={'Дай одну ассоциацию. Не называй секретное слово.','Give one association. Do not say the secret word.','给出一个联想。不要说出秘密词语。'},
 hint_wait={'Слушай подсказку. Сравни её с предыдущими.','Listen to the clue. Compare it with earlier clues.','听取提示，并与之前的提示比较。'},
 discuss={'Задай вопрос о детали. Сравни ответ с подсказками.','Ask about a detail. Compare the answer with the clues.','询问一个细节，再将回答与提示比较。'},
 vote={'Чьи ответы не сходятся? Выбери подозреваемого.','Whose answers do not fit? Choose a suspect.','谁的回答不吻合？选择嫌疑人。'},
 ExtraRound={'Начинается ещё круг подсказок. Приготовь новую ассоциацию.','Another clue round is starting. Prepare a new association.','新一轮提示即将开始。准备一个新的联想。'},
 Result={'Посмотри итог партии. Затем выбери, играть ли снова.','Review the result, then choose whether to play again.','查看比赛结果，再选择是否继续玩。'},
 Finished={'Выбери реванш или вернись в лобби.','Choose a rematch or return to the lobby.','选择再玩一次或返回大厅。'},
}
function Guide.message(files,lang,state,id,opened)
 if not validState(state)then return ''end
 local c=type(state.case)=='table'and state.case;local key
 if c then
  if state.phase=='Role'and not opened then key='card'
  elseif c.stage=='inspect'then key='inspect'
  elseif c.stage=='defense'then key=ownTurn(c.defenseId,id)and'your_defense'or'listen_defense'
  elseif c.stage=='testify'then key=ownTurn(state.turnUserId,id)and'testify'or'hint_wait'
  elseif c.stage=='discuss'then key='discuss'
  elseif c.stage=='vote'then key='vote'
  elseif c.stage=='result'then key='review'
  else key='card'end
  return files.text(lang,key)
 elseif state.phase=='Role'and not opened then key='card'
 elseif state.phase=='Hint'then key=ownTurn(state.turnUserId,id)and'hint'or'hint_wait'
 elseif state.phase=='Discuss'then key='discuss'
 elseif state.phase=='Vote'then key='vote'
 else key=state.phase
 end
 return translated(prompts[key],lang)
end
function Guide.speaker(state)
 local active=state and state.phase=='Discuss'and state.discussion and state.discussion.active
 return active and active.target or state and state.case and state.case.stage=='defense'and state.case.defenseId or state and state.turnUserId
end
local questions={
 reason={'Почему подходит твоя подсказка?','Why does your clue fit?','为什么你的提示符合？'},
 detail={'Назови ещё одну деталь, не называя слово.','Give another detail without naming the word.','再说一个细节，但别说出答案。'},
 odd={'Какая подсказка кажется тебе лишней?','Which clue seems out of place?','哪条提示显得不合适？'},
}
function Guide.questionText(lang,key)
 local v=questions[key];return v and v[lang=='en'and 2 or lang=='zh'and 3 or 1]or''
end
function Guide.newDiscussion(ids,token,clock,endAt)
 local d={members={},original={},used={},active=nil,revision=0,serial=0,token=token}
 for _,id in ipairs(ids)do d.members[id]=true;d.original[id]=true end
 local function fail(code)return{ok=false,code=code}end
 function d:tick()
  if self.active and clock()>=self.active.endAt then self.active=nil;self.revision+=1;return true end
  return false
 end
 function d:ask(from,target,prompt,segment)
  self:tick()
  if segment~=self.token or clock()>=endAt then return fail('closed')end
  if not self.members[from]or not self.members[target]or from==target or not questions[prompt]then return fail('invalid')end
  if self.active then return fail('busy')end
  if self.used[from]then return fail('used')end
  self.serial+=1;self.revision+=1;self.used[from]=true
  self.active={id=self.serial,from=from,target=target,prompt=prompt,endAt=math.min(clock()+8,endAt)}
  return{ok=true}
 end
 function d:finish(target,id,segment)
  self:tick()
  if segment~=self.token or clock()>=endAt or not self.active or self.active.id~=id then return fail('closed')end
  if self.active.target~=target or not self.members[target]then return fail('invalid')end
  self.active=nil;self.revision+=1;return{ok=true}
 end
 function d:drop(id)
  self.members[id]=nil
  if self.active and(self.active.from==id or self.active.target==id)then self.active=nil;self.revision+=1;return true end
  return false
 end
 function d:restore(id)if self.original[id]then self.members[id]=true end end
 function d:public()
  local used={};for id in pairs(self.used)do used[#used+1]=id end;table.sort(used)
  return{token=self.token,revision=self.revision,used=used,active=self.active and table.clone(self.active)or nil}
 end
 return d
end
return Guide
