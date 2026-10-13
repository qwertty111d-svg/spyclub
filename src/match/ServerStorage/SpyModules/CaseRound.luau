-- Private investigation rules. No competitive secret is stored in ReplicatedStorage.
local Core={};Core.__index=Core
local sources={'tape','phone','folder'}
function Core.new(files,people,spyId,fileId,token,code)
 local self=setmetatable({files=files,people={},byId={},spyId=spyId,fileId=fileId,token=token,code=code,
  stage='intro',revision=1,pairs={},inspections={},used={},nominations={}},Core)
 local witnesses={}
 for i,p in ipairs(people)do
  local copy={id=p.id,name=p.name,index=i};self.people[i]=copy;self.byId[p.id]=copy
  if p.id~=spyId then witnesses[#witnesses+1]=p.id end
 end
 for i,source in ipairs(sources)do
  local pair={spyId,witnesses[(i-1)%math.max(1,#witnesses)+1]or spyId};table.sort(pair);self.pairs[source]=pair
 end
 return self
end
function Core:setStage(stage,defenseId)
 self.stage=stage;self.defenseId=stage=='defense'and defenseId or nil;self.revision+=1
end
function Core:public()
 local used={};for _,source in ipairs(sources)do used[source]=self.used[source]==true end
 return {mode='case',stage=self.stage,revision=self.revision,defenseId=self.defenseId,sourcesUsed=used,fileId=self.fileId}
end
function Core:private(id,lang)
 local p=self.byId[id];if not p then return nil end
 local f=self.files;local spy=id==self.spyId;local file=f.public(self.fileId,lang)
 -- Cards name the current guests only. Solo-case NPC testimony never enters a live match.
 local suspects={};for _,person in ipairs(self.people)do suspects[#suspects+1]={id=person.id,name=person.name}end
 local out={ok=true,kind='meeting',token=self.token,revision=self.revision,stage=self.stage,selfId=id,
  role=spy and'spy'or'detective',file={id=self.fileId,title=file.title,brief=f.text(lang,'meeting_brief'),sources=file.sources,suspects=suspects},
  alibi=f.text(lang,'alibi_'..((p.index-1)%4+1)),secret=f.text(lang,spy and'spy_secret'or'secret_'..((p.index-1)%4+1)),
  goal=f.text(lang,spy and'spy_goal'or'testify'),canInspect=self.stage=='inspect'and self.inspections[id]==nil,
  canNominate=self.stage=='discuss',nomination=self.nominations[id],defenseId=self.defenseId,finished=self.stage=='result'}
 local source=self.inspections[id]
 if source then
  local pair=self.pairs[source];local a=self.byId[pair[1]];local b=self.byId[pair[2]]
  local index=table.find(sources,source)
  out.source=source;out.evidence=string.format(f.text(lang,source..'_clue'),a and a.name or'?',b and b.name or'?')
  out.fragment=string.sub(self.code,index*2-1,index*2)
  out.fragmentIndex=index;out.fragmentCount=#sources
 end
 if out.finished then
  out.canInspect=false;out.canNominate=false
  out.explanation=string.format(f.text(lang,'conclusion'),self.byId[self.spyId].name,self.code)
 end
 return out
end
function Core:inspect(id,token,source)
 if not self.byId[id]then return {ok=false,code='not_member'}end
 if token~=self.token then return {ok=false,code='stale'}end
 if self.stage~='inspect'then return {ok=false,code='busy'}end
 if self.inspections[id]then return {ok=false,code='already_inspected'}end
 if not self.pairs[source]then return {ok=false,code='invalid'}end
 local coverage=true;for _,name in ipairs(sources)do if not self.used[name]then coverage=false end end
 if self.used[source]and not coverage then return {ok=false,code='source_taken'}end
 self.inspections[id]=source;self.used[source]=true;self.revision+=1;return {ok=true}
end
function Core:nominate(id,token,target)
 if not self.byId[id]or not self.byId[target]then return {ok=false,code='not_member'}end
 if token~=self.token then return {ok=false,code='stale'}end
 if self.stage~='discuss'or target==id then return {ok=false,code='busy'}end
 self.nominations[id]=target;self.revision+=1;return {ok=true}
end
function Core:leader(active)
 local counts={};for id,target in pairs(self.nominations)do
  if not active or(active[id]and active[target])then counts[target]=(counts[target]or 0)+1 end
 end
 local winner,most,tied=nil,0,false
 for id,n in pairs(counts)do if n>most then winner,most,tied=id,n,false elseif n==most then tied=true end end
 return not tied and winner or nil
end
function Core.run(h)
 local round=h.round;local token=round.token;local Players=h.players;local RS=h.rs
 local Files=require(RS:WaitForChild('SpyShared'):WaitForChild('CaseFiles'))
 local code=string.format('%06d',h.random:NextInteger(0,999999))
 local fileId=Files.Ids[h.random:NextInteger(1,#Files.Ids)]
 if not h.chooseSecrets({id='case_'..fileId,title=Files.text('ru','meeting'),words={code}})then return end
 local people={};for _,p in ipairs(round.players)do people[#people+1]={id=p.UserId,name=p.DisplayName or p.Name}end
 local ctx=Core.new(Files,people,round.spyId,fileId,token,code);round.caseContext=ctx
 local folder=RS:FindFirstChild('SpyMeetingRemotes')or Instance.new('Folder');folder.Name='SpyMeetingRemotes';folder.Parent=RS
 local event=folder:FindFirstChild('State')or Instance.new('RemoteEvent');event.Name='State';event.Parent=folder
 local request=folder:FindFirstChild('Request')or Instance.new('RemoteFunction');request.Name='Request';request.Parent=folder
 function ctx:push(one)
  for _,p in ipairs(round.players)do if (not one or one==p)and p.Parent==Players and p:GetAttribute('SpySessionAccepted')==true then
   event:FireClient(p,self:private(p.UserId,p:GetAttribute('SpyLanguage')or'ru'))
  end end
 end
 local rate={}
 request.OnServerInvoke=function(p,payload)
  local index=round.playerIndex[p.UserId]
  if p.Parent~=Players or Players:GetPlayerByUserId(p.UserId)~=p or not index or round.players[index]~=p or p:GetAttribute('SpySessionAccepted')~=true then return {ok=false,code='not_member'}end
  if type(payload)~='table'then return {ok=false,code='invalid'}end
  local at=os.clock();local gate=rate[p.UserId]
  if not gate or at-gate.at>2 then gate={at=at,count=0};rate[p.UserId]=gate end
  gate.count+=1;if gate.count>12 then return {ok=false,code='busy'}end
  if round.terminal or round.caseContext~=ctx then return {ok=false,code='stale'}end
  if payload.action=='snapshot'then return ctx:private(p.UserId,p:GetAttribute('SpyLanguage')or'ru')end
  if round.token~=token or round.resultStarted or round.finished then return {ok=false,code='stale'}end
  local result
  if payload.action=='inspect'then result=ctx:inspect(p.UserId,payload.token,payload.source)
  elseif payload.action=='nominate'and round.playerIndex[payload.target]then result=ctx:nominate(p.UserId,payload.token,payload.target)
  else return {ok=false,code='invalid'}end
  if not result.ok then return result end
  if round.participation then round.participation:respond(p.UserId,'case')end
  ctx:push();h.broadcast(round.phase,{category=round.category})
  return ctx:private(p.UserId,p:GetAttribute('SpyLanguage')or'ru')
 end
 -- Props are optional presentation. Their absence cannot hold the round open.
 task.defer(function()
  local model=h.modules:FindFirstChild('CaseSet');if not model then return end
  local ok,set=pcall(require,model);if ok then pcall(set.match,workspace)end
 end)
 local function stage(name,phase,seconds)
  if round.token~=token or round.finished then return false end
  ctx:setStage(name);h.setPhase(phase,seconds);ctx:push();h.broadcast(phase,{category=round.category,themeId=round.selectedThemeId})
  return h.waitPhase(seconds,token)
 end
 h.sendCards()
 if not stage('intro','Intro',h.introSeconds)or not stage('role','Role',h.roleSeconds)then return end
 if not stage('inspect','Discuss',45)then return end
 ctx:setStage('testify');ctx:push()
 if not h.runInitialHints(token)then return end
 local result;local discussion=h.discussionSeconds
 while not result do
  if round.token~=token or round.finished then return end
  ctx:setStage('discuss');ctx:push()
  if not h.runDiscussion(token,discussion)then return end
  discussion=h.discussionSeconds
  local active={};for _,p in ipairs(round.players)do if p.Parent==Players and not round.disconnected[p.UserId]then active[p.UserId]=true end end
  local suspect=ctx:leader(active)
  if suspect then
   ctx:setStage('defense',suspect);round.currentTurnUserId=suspect;round.hintTurnDone=false;round.turnIndex=1
   h.session:SetAttribute('CurrentTurnUserId',suspect);h.session:SetAttribute('CurrentTurnIndex',1)
   h.setPhase('Hint',30);ctx:push();h.broadcast('Hint',{turnUserId=suspect,turnIndex=1,category=round.category})
   local endAt=h.now()+30
   while h.now()<endAt and not round.hintTurnDone do
    if round.token~=token or round.finished then return end
    if round.disconnected[suspect]then break end
    task.wait(.1)
   end
   round.currentTurnUserId=nil;round.turnIndex=0;round.hintTurnDone=false
   h.session:SetAttribute('CurrentTurnUserId',0);h.session:SetAttribute('CurrentTurnIndex',0)
  end
  ctx:setStage('vote');ctx:push()
  local decision=h.runVoting(token);if not decision or round.finished then return end
  if decision.type=='restart_vote'then discussion=h.restartSeconds
  elseif decision.type=='extra_round'then
   ctx:setStage('testify');ctx:push();if not h.runExtraHintRound(token)then return end;discussion=h.restartSeconds
  elseif decision.type=='result'then result=decision.result
  else return end
 end
 h.finishRound(result,token)
end
return Core
