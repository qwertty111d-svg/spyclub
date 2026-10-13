local Guide={}
local prompts={
 discuss={'Задай вопрос о детали. Сравни ответ с подсказками.','Ask about a detail. Compare the answer with the clues.','询问一个细节，再将回答与提示比较。'},
 vote={'Чьи ответы не сходятся? Выбери подозреваемого.','Whose answers do not fit? Choose a suspect.','谁的回答不吻合？选择嫌疑人。'},
}
function Guide.message(files,lang,state,id,opened)
 if not state then return ''end
 local c=state.case;local key
 if state.phase=='Role'and not opened then key='card'
 elseif c then
  if c.stage=='inspect'then key='inspect'
  elseif c.stage=='defense'then key=c.defenseId==id and'your_defense'or'listen_defense'
  elseif c.stage=='testify'then key=state.turnUserId==id and'testify'or'hint_wait'
  elseif c.stage=='discuss'then key='discuss'
  elseif c.stage=='vote'then key='vote'
  elseif c.stage=='result'then key='review'
  else key='card'end
 elseif state.phase=='Hint'then key=state.turnUserId==id and'hint'or'hint_wait'
 elseif state.phase=='Discuss'then key='discuss'
 elseif state.phase=='Vote'then key='vote'
 elseif state.phase=='Result'then key='review'
 elseif state.phase=='Role'then key='hint'
 end
 local prompt=not c and prompts[key]
 return prompt and prompt[lang=='en'and 2 or lang=='zh'and 3 or 1]or key and files.text(lang,key)or''
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
