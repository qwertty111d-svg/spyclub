-- Independent mini-game. Server simulation owns every stroke and challenge result.
local Physics=require(script.Parent.BilliardsPhysics)
local Rules=require(script.Parent.BilliardsRules)
local Game={};Game.__index=Game;Game.TURN_SECONDS=60
local modes={pool8=true,pyramid=true,pool9=true}
local actions={sync=true,join=true,join_decision=true,join_cancel=true,leave=true,shot=true,reset=true,select=true,place=true,penalty=true,pass=true,decision=true,aim=true,spot_home=true}
local function integer(v,a,b)return Physics.finite(v)and v%1==0 and v>=a and v<=b end
function Game.new()
 return setmetatable({players={},scores={},groups={},lives={},nineFouls={},mode="pool8",strictOpponent=false,turnSeconds=60,
 balls=Physics.newRack(),phase="idle",turn=0,revision=1,rackId=1,turnToken=1,deadline=0,shots=0,cueId=0,
 audioSerial=0,audioHistory={},nextAudio={},note="Выбери игру",nextRequest={},nextAim={},nextJoin={},joinSerial=0,shotSeconds=0},Game)
end
function Game:clearJoin(now,code)
 local offer=self.joinOffer;if not offer then return false end
 self.joinOffer=nil;self.joinOutcome={id=offer.id,token=offer.token,code=code or"join_expired",expires=now+4}
 return true
end
function Game:expireJoin(now)
 if self.joinOffer and now>=self.joinOffer.expires then return self:clearJoin(now,"join_expired")end
 return false
end
function Game:member(id)for index,p in ipairs(self.players)do if p.id==id then return index end end end
function Game:opponent(id)for _,p in ipairs(self.players)do if p.id~=id then return p.id end end;return id end
function Game:touch()self.revision+=1 end
function Game:parameters()return Physics.parameters(self.mode)end
function Game:groupRemaining(g)local n=0;for _,b in ipairs(self.balls)do if not b.pocketed and Rules.group(b.id)==g then n+=1 end end;return n end
function Game:canEight(id)
 if self.groups[id]then return self:groupRemaining(self.groups[id])==0 end
 return self:groupRemaining("solids")==0 or self:groupRemaining("stripes")==0
end
function Game:deadlineFor(now)return #self.players==2 and now+self.turnSeconds or 0 end
function Game:beginTurn(id,now)self.turn=id;self.placedArea=nil;self.turnToken+=1;self.aim=nil;self.deadline=self:deadlineFor(now)end
function Game:setRules(payload)
 local mode=payload.mode;local seconds=payload.turnSeconds
 if mode==nil then mode=self.challengeWanted and "challenge"or self.mode end;if seconds==nil then seconds=self.turnSeconds end
 if type(mode)~="string"or(mode~="challenge"and not modes[mode])or not Physics.finite(seconds)then return false end
 if mode=="challenge"and #self.players>1 then return false end
 if seconds==30 then seconds=60 end
 if seconds~=30 and seconds~=45 and seconds~=60 and seconds~=90 then return false end
 self.challengeWanted=mode=="challenge";self.mode,self.turnSeconds,self.strictOpponent=self.challengeWanted and "pool8"or mode,seconds,false;return true
end
function Game:rack(now,note,starter)
 self:clearJoin(now,"join_expired")
 self.balls=Physics.newRack(self.mode,self.rackId+math.floor(now*1000));self.scores={};self.groups={};self.lives={};self.nineFouls={};self.pushOutAvailable=false;self.pushOutShot=false;self.shots=0;self.shotSeconds=0;self.rackId+=1
 self.winner=nil;self.foul=nil;self.ballInHand=#self.players>0 and "home"or nil;self.cueId=0;self.canReturn=false;self.pendingPenalty=nil;self.decision=nil;self.pyramidBreakOptions=nil
 for _,p in ipairs(self.players)do self.scores[p.id]=0;self.lives[p.id]=3 end
 self.phase=#self.players>0 and "aiming"or "idle";self:beginTurn(starter or(self.players[1]and self.players[1].id or 0),now)
 if self.challengeWanted and #self.players==1 then
  -- Identical physical layout for every attempt, regardless of wall clock or seed.
  for _,b in ipairs(self.balls)do
   if b.id==0 then b.x,b.z=-3.8,0
   elseif b.id==1 then b.x,b.z=0,-2.55
   elseif b.id==2 then b.x,b.z=0,2.55
   else local index=b.id-3;b.x,b.z=.2+math.floor(index/3)*1.12,(index%3-1)*1.45 end
  end
  self.challenge={score=0,potted=0,shots=0,complete=false};self.ballInHand=nil;self.deadline=0
 else self.challenge=nil end
 self.breaker=self.turn;self.note=self.challenge and "Пять ударов · забей как можно больше"or(note or "Разбой · поставь биток в доме");self:touch()
end
function Game:leave(id,now)
 local canceled=self.joinOffer and(self.joinOffer.id==id or self.joinOffer.owner==id)and self:clearJoin(now,"join_expired")
 local index=self:member(id);if not index then return canceled==true end
 table.remove(self.players,index);self.scores[id]=nil;if #self.players==0 then self.challengeWanted=false end;self:rack(now,#self.players>0 and "Соперник вышел · новая тренировка"or "Стол свободен");return true
end
function Game:setDecision(kind,id,now)
 self.phase="decision";self.decision={kind=kind,owner=id};self:beginTurn(id,now);self.note="Выбери продолжение после разбоя"
end
function Game:decisionOptions()
 if not self.decision then return {}end
 local k=self.decision.kind
 if k=="eight_break"then return {"accept","rerack_self"}
 elseif k=="eight_foul"then return {"hand","rerack_self"}
 elseif k=="illegal_break"then return {"accept","rerack_self","rerack_other"}
 elseif k=="nine_pushout"or k=="nine_break"then return {"accept","pass"}
 elseif k=="pyramid_break"then return {"accept","pass","rerack_self","rerack_other"}
 else return {"accept","hand"}end
end
function Game:resolveDecision(choice,now)
 local allowed=false;for _,v in ipairs(self:decisionOptions())do if v==choice then allowed=true end end;if not allowed then return false end
 local owner=self.turn;local kind=self.decision.kind;self.decision=nil
 if choice=="rerack_self"or choice=="rerack_other"then
  local starter=choice=="rerack_self"and owner or self:opponent(owner)
  if kind=="pyramid_break"then
   -- Re-rack only remaining balls; penalty and earned shelf scores are retained.
   local active={};for _,b in ipairs(self.balls)do if not b.pocketed then table.insert(active,b.id)end end
   local cue=active[1];for _,bid in ipairs(active)do if bid==0 then cue=0;break end end
   self.cueId=cue;local spacing=2*self:parameters().RADIUS+.0002;local index=1
   for _,bid in ipairs(active)do local b=Physics.ball(self.balls,bid);b.vx,b.vz,b.wx,b.wy,b.wz=0,0,0,0,0
    if bid==cue then b.x,b.z=-3.8,0
    else local row=0;while index>(row+1)*(row+2)/2 do row+=1 end;local col=index-row*(row+1)/2-1
     b.x,b.z=3.05+row*spacing*math.sqrt(3)/2,(col-row/2)*spacing;index+=1 end
   end
   self.shots=0;self.rackId+=1;self.breaker=starter;self.phase="aiming";self.ballInHand="home";self:beginTurn(starter,now)
  else self:rack(now,"Повторный разбой · поставь биток",starter)end
 else
  self.phase="aiming";self.ballInHand=nil
  if choice=="hand"or(kind=="break_foul"and Physics.ball(self.balls,0).pocketed)then Physics.respawnCue(self.balls,self:parameters());self.cueId=0;self.ballInHand="home"end
  if kind=="pyramid_break"then self.canReturn=choice~="pass"end
  self:beginTurn(choice=="pass"and self:opponent(owner)or owner,now);self.note="Продолжай партию"
  if kind=="nine_break"then self.pushOutAvailable=choice=="pass"end
 end;return true
end
function Game:awardPenalty(id,b,now)
 b.pocketed=true;b.fallT=nil;b.vx,b.vz,b.wx,b.wy,b.wz=0,0,0,0,0;self.scores[id]=(self.scores[id]or 0)+1
 self.pendingPenalty=nil;self.phase="aiming";self.canReturn=true;self:chooseCue();self:beginTurn(id,now);self.note="Штрафной шар получен · твой ход"
 if self.scores[id]>=8 then self:endRack(id,"Восемь шаров · победа")
 elseif self.pyramidBreakOptions then self:setDecision("pyramid_break",id,now)end
 self.pyramidBreakOptions=nil;self:touch()
end
function Game:receiveAim(id,payload,now,near,available)
 if not near or not available or not self:member(id)or self.turn~=id or self.phase~="aiming"or self.ballInHand then return false,"unavailable"end
 if payload.rackId~=self.rackId or payload.turnToken~=self.turnToken then return false,"stale_aim"end
 if #self.players==2 and now>=self.deadline then return false,"turn_expired"end
 if not Physics.finite(payload.angle)or math.abs(payload.angle)>360 or not Physics.finite(payload.power)or payload.power<.08 or payload.power>1 or not Physics.validSpin(payload.spin)then return false,"bad_aim"end
 if(self.nextAim[id]or -math.huge)>now then return false,"rate_limited"end;self.nextAim[id]=now+.095
 self.aim={id=id,angle=payload.angle,power=payload.power,spin={x=payload.spin and payload.spin.x or 0,y=payload.spin and payload.spin.y or 0},cueId=self.cueId,at=now}
 return true,"aim"
end
function Game:request(id,name,payload,now,near,available,requesterAvailable)
 if type(payload)~="table"or not actions[payload.action]or not Physics.finite(now)then return false,"bad_request"end
 local action=payload.action
 if action=="leave"then self:leave(id,now);return true,"left"end
 if action=="aim"then return self:receiveAim(id,payload,now,near,available)end
 if(self.nextRequest[id]or -math.huge)>now then return false,"rate_limited"end;self.nextRequest[id]=now+.12
 if action=="sync"then return true,"ok"end
 if not near or not available then return false,"unavailable"end
 self:expireJoin(now)
 if action=="join_decision"or action=="join_cancel"then
  local offer=self.joinOffer
  if not offer or payload.token~=offer.token or offer.rackId~=self.rackId or #self.players~=1 then return false,"join_expired"end
  if action=="join_cancel"then
   if id~=offer.id then return false,"not_playing"end
   self:clearJoin(now,"join_canceled");return true,"join_canceled"
  end
  if id~=offer.owner or self.players[1].id~=id then return false,"host_only"end
  if type(payload.accept)~="boolean"then return false,"bad_request"end
  if not payload.accept then self:clearJoin(now,"join_declined");return true,"join_declined"end
  if requesterAvailable~=true then self:clearJoin(now,"join_expired");return false,"join_expired"end
  if self.phase=="moving"or self.phase=="penalty"or self.phase=="decision"then return false,"balls_moving"end
  table.insert(self.players,{id=offer.id,name=offer.name});self.challengeWanted=false
  self:clearJoin(now,"joined");self:rack(now,"Новая партия · разбой");return true,"joined"
 end
 if not integer(payload.revision,1,math.huge)or payload.revision~=self.revision then return false,"stale_state"end
 if action=="join"then
  if self:member(id)then return true,"joined"end;if #self.players>=2 then return false,"table_full"end
  if #self.players==1 then
   if self.joinOffer then return self.joinOffer.id==id,self.joinOffer.id==id and"join_pending"or"join_busy"end
   if now<(self.nextJoin[id]or-math.huge)then return false,"join_wait"end
   self.nextJoin[id]=now+5;self.joinSerial+=1;self.joinOutcome=nil
   self.joinOffer={id=id,name=name,owner=self.players[1].id,token=self.joinSerial,rackId=self.rackId,expires=now+20}
   return true,"join_pending"
  end
  if self.phase=="moving"or self.phase=="penalty"or self.phase=="decision"then return false,"balls_moving"end
  if #self.players==0 and not self:setRules(payload)then return false,"bad_rules"end
  table.insert(self.players,{id=id,name=name});self:rack(now);return true,"joined"
 end
 if not self:member(id)then return false,"not_playing"end
 if action=="reset"then
  if self.phase=="moving"then return false,"balls_moving"end
  if #self.players==2 and self.phase~="finished"and self.shots>0 then return false,"match_in_progress"end
  if self.players[1].id~=id and(payload.mode~=nil or payload.turnSeconds~=nil)then return false,"host_only"end
  if not self:setRules(payload)then return false,"bad_rules"end
  local starter=self.phase=="finished"and self:opponent(self.breaker)or self.players[1].id
  self:rack(now,"Новая партия · разбой",starter);return true,"reset"
 end
 if self.turn~=id then return false,"not_your_turn"end
 if #self.players==2 and now>=self.deadline then return false,"turn_expired"end
 if action=="decision"then
  if self.phase~="decision"or not self:resolveDecision(payload.choice,now)then return false,"bad_request"end;self:touch();return true,"decided"
 end
 if action=="penalty"then
  local b=Physics.ball(self.balls,payload.ball)
  if self.phase~="penalty"or self.pendingPenalty~=id or not b or b.pocketed then return false,"bad_ball"end
  self:awardPenalty(id,b,now);return true,"penalty"
 end
 if self.phase~="aiming"then return false,"balls_moving"end
 if action=="pass"then
  if self.mode~="pyramid"or not self.canReturn or #self.players<2 then return false,"bad_request"end
  self.canReturn=false;self:beginTurn(self:opponent(id),now);self:touch();return true,"passed"
 end
 if action=="select"then
  local b=Physics.ball(self.balls,payload.ball)
  if self.mode~="pyramid"or self.shots==0 or not b or b.pocketed then return false,"bad_ball"end
  self.cueId=b.id;self.aim=nil;self:touch();return true,"selected"
 end
 if action=="spot_home"then
  if self.challenge then return false,"bad_request"end
  local ballId=Rules.homeSpot(self)
  if not ballId or not Physics.spot(self.balls,ballId,self:parameters())then return false,"bad_request"end
  self.aim=nil;self.note="Ближайшая цель выставлена за дом";self:touch();return true,"spotted"
 end
 if action=="place"then
  if not self.ballInHand or not Physics.place(self.balls,self.cueId,payload.x,payload.z,self:parameters(),self.ballInHand)then return false,"bad_placement"end
  self.placedArea=self.ballInHand;self.ballInHand=nil;self.note="Биток установлен · выполняй удар";self:touch();return true,"placed"
 end
 if action~="shot"then return false,"bad_request"end
 if self.ballInHand then return false,"place_cue"end
 local isBreak=self.shots==0;local safe=payload.safety==true
 if payload.pushOut~=nil and type(payload.pushOut)~="boolean"then return false,"bad_request"end
 local push=payload.pushOut==true
 if push and(self.mode~="pool9"or not self.pushOutAvailable or isBreak)then return false,"pushout_unavailable"end
 if payload.safety~=nil and type(payload.safety)~="boolean"then return false,"bad_request"end
 if not Physics.strike(self.balls,payload.angle,payload.power,self.mode,self.cueId,payload.spin)then return false,"bad_shot"end
 if not self.challenge and self.mode=="pool8"and not isBreak and not self.groups[id]then
  local empty=self:groupRemaining("solids")==0 and "solids"or(self:groupRemaining("stripes")==0 and "stripes"or nil)
  if empty then self.groups[id]=empty;if #self.players==2 then self.groups[self:opponent(id)]=empty=="solids"and "stripes"or "solids"end end
 end
 self.breakShot=isBreak;self.eightAllowed=self:canEight(id);self.calledPocket=nil;self.calledBall=nil;self.safety=safe
 self.nineTarget=self.mode=="pool9"and Rules.lowest(self)or nil;self.pushOutShot=push;self.pushOutAvailable=false
 self.trace=Physics.newTrace(self.balls,self.cueId,self:parameters());self.trace.homeRestricted=self.mode=="pool8"and self.placedArea=="home";self.placedArea=nil;self.potted={};self.shooter=id
 self:recordAudio("cue",payload.power,now)
 self.phase="moving";self.shots+=1;self.shotSeconds=0;self.canReturn=false;self.foul=nil;self.aim=nil;self.note="Шары в игре";self:touch();return true,"shot"
end
function Game:chooseCue()
 local b=Physics.ball(self.balls,self.cueId);if not b or b.pocketed then for _,ball in ipairs(self.balls)do if not ball.pocketed then self.cueId=ball.id;return end end end
end
function Game:endRack(id,reason)
 self.phase="finished";self.deadline=0;self.winner=id;self.ballInHand=nil;self.pendingPenalty=nil;self.decision=nil;self.aim=nil;self.note=reason
end
function Game:finishShot(now)
 if self.challenge then
  local objects,scratch=0,false
  for _,id in ipairs(self.potted or {})do if id==0 then scratch=true else objects+=1 end end
  local c=self.challenge
  c.potted+=objects;c.shots=self.shots
  c.score+=math.clamp(3*objects+((self.trace and self.trace.firstContact~=nil)and 1 or 0)-(scratch and 2 or 0),0,10)
  self.scores[self.shooter]=c.score;self.foul=scratch and "scratch"or nil
  if scratch then Physics.respawnCue(self.balls,self:parameters())end
  self.cueId=0;self.ballInHand=nil
  if self.shots>=5 then c.complete=true;self:endRack(self.shooter,"Пять ударов завершены")
  else self.phase="aiming";self:beginTurn(self.shooter,now);self.note="Удар "..(self.shots+1).." из 5"end
 else Rules.finish(self,now)end
 self:touch()
end
function Game:recordAudio(kind,level,now)
 if(self.nextAudio[kind]or -math.huge)>now then return end;self.nextAudio[kind]=now+.035
 self.audioSerial+=1;table.insert(self.audioHistory,{id=self.audioSerial,kind=kind,level=level,at=now})
 if #self.audioHistory>20 then table.remove(self.audioHistory,1)end
end
function Game:step(now)
 local offerExpired=self:expireJoin(now)
 if self.phase=="moving"then
  self.shotSeconds+=Physics.DT;for _,id in ipairs(Physics.step(self.balls,self:parameters(),self.trace))do table.insert(self.potted,id)end
  for _,e in ipairs(self.trace.audio or {})do self:recordAudio(e.kind,e.level,now)end;self.trace.audio={}
  if self.shotSeconds>=40 then Physics.stop(self.balls);self.physicsTimeout=true end
  if Physics.allStopped(self.balls)then self:finishShot(now);return true end
 elseif(self.phase=="aiming"or self.phase=="penalty"or self.phase=="decision")and #self.players==2 and now>=self.deadline then
  if self.phase=="decision"then local fallback=self.decision.kind=="eight_foul"and "hand"or "accept";self:resolveDecision(fallback,now)
  elseif self.phase=="penalty"then for _,b in ipairs(self.balls)do if not b.pocketed then self:awardPenalty(self.turn,b,now);break end end
  elseif self.mode=="pool9"then Rules.nineFoul(self,self.turn,"timeout",now)
  else
   local other=self:opponent(self.turn);self.foul="timeout";self:beginTurn(other,now)
   if self.mode=="pool8"then Physics.respawnCue(self.balls,self:parameters());self.cueId=0;self.ballInHand="table"
   else self.phase="penalty";self.pendingPenalty=other end
   self.note="Время истекло · фол"
  end;self:touch();return true
 end;return offerExpired
end
function Game:snapshot(now)
 local balls,players={},{}
 for _,b in ipairs(self.balls)do table.insert(balls,{id=b.id,x=b.x,z=b.z,vx=b.vx,vz=b.vz,wx=b.wx,wy=b.wy,wz=b.wz,pocketed=b.pocketed,pocketIndex=b.pocketIndex,fallT=b.fallT,qx=b.qx,qy=b.qy,qz=b.qz,qw=b.qw})end
 for _,p in ipairs(self.players)do table.insert(players,{id=p.id,name=p.name,score=self.scores[p.id]or 0,lives=self.lives[p.id],group=self.groups[p.id],targetEight=self.mode=="pool8"and self:canEight(p.id),fouls=self.nineFouls[p.id]or 0,foulWarning=(self.nineFouls[p.id]or 0)==2})end
 local aim=self.aim and self.phase=="aiming"and not self.ballInHand and self.aim.at>=now-1.1 and self.aim or nil
 local audio={};for _,e in ipairs(self.audioHistory)do if now-e.at<.8 then table.insert(audio,e)end end
 return {joinOffer=self.joinOffer and now<self.joinOffer.expires and table.clone(self.joinOffer)or nil,joinOutcome=self.joinOutcome and now<self.joinOutcome.expires and table.clone(self.joinOutcome)or nil,audio=audio,audioSerial=self.audioSerial,revision=self.revision,rackId=self.rackId,turnToken=self.turnToken,phase=self.phase,turn=self.turn,players=players,balls=balls,note=self.note,
 mode=self.mode,strictOpponent=false,turnSeconds=self.turnSeconds,cueId=self.cueId,ballInHand=self.ballInHand,
 winner=self.winner,foul=self.foul,canReturn=self.canReturn,pendingPenalty=self.pendingPenalty,decision=self.decision,decisionOptions=self:decisionOptions(),
 challenge=self.challenge and table.clone(self.challenge)or nil,canSpotHome=not self.challenge and Rules.homeSpot(self)~=nil,homeRestriction=self.placedArea=="home",remaining=Physics.remaining(self.balls,self.mode=="pyramid"),shots=self.shots,deadline=self.deadline,serverTime=now,aim=aim,lowest=self.mode=="pool9"and Rules.lowest(self)or nil,pushOutAvailable=self.pushOutAvailable==true}
end
function Game:forget(id)self.nextRequest[id]=nil;self.nextAim[id]=nil;self.nextJoin[id]=nil end
return Game
