-- Club eight-ball without pocket orders; WPA nine-ball / FBSRF free pyramid.
local Physics=require(script.Parent.BilliardsPhysics)
local Rules={}
function Rules.group(id)if id and id>=1 and id<=7 then return "solids"elseif id and id>=9 and id<=15 then return "stripes"end end
local function count(t)local n=0;for _ in pairs(t or {})do n+=1 end;return n end
function Rules.lowest(g)for id=1,15 do local b=Physics.ball(g.balls,id);if b and not b.pocketed then return id end end end
function Rules.callLegal(g,id,ball)
 if g.mode=="pool9"then return ball==Rules.lowest(g)end
 if g:canEight(id)then return ball==8 end
 if not g.groups[id]and ball==8 then return g:groupRemaining("solids")==0 or g:groupRemaining("stripes")==0 end
 local gr=Rules.group(ball);return gr~=nil and(not g.groups[id]or g.groups[id]==gr)
end
function Rules.homeSpot(g)
 if g.mode~="pool8"or(g.ballInHand~="home"and g.placedArea~="home")then return nil end
 local nearest=nil
 for _,b in ipairs(g.balls)do if not b.pocketed and b.id~=0 and Rules.callLegal(g,g.turn,b.id)then
  if b.x>=-Physics.HALF_X/2 then return nil end
  if not nearest or b.x>nearest.x then nearest=b end
 end end;return nearest and nearest.id
end
function Rules.pool(g,now)
 local id,other=g.shooter,g:opponent(g.shooter);local t,pots=g.trace,g.potted
 local cue,eight=Physics.ball(g.balls,0),Physics.ball(g.balls,8)
 local foul=t.firstContact==nil and "no_contact"or nil
 if t.badHome then foul=foul or "bad_home"end
 if cue.pocketed then foul="scratch"end
 local gr=g.groups[id]
 if not g.breakShot then
  local wrong=(gr and((g.eightAllowed and t.firstContact~=8)or(not g.eightAllowed and Rules.group(t.firstContact)~=gr)))or(not gr and t.firstContact==8)
  if wrong then foul=foul or "wrong_first"end
  if #pots==0 and(t.railCount or 0)==0 then foul=foul or "no_rail"end
 elseif not foul and #pots==0 and count(t.objectsAtRail)<4 then foul="weak_break"end
 if g.breakShot then
  if eight.pocketed then
   Physics.spot(g.balls,8,g:parameters())
   g.foul=foul;g.turn=foul and other or id
   g:setDecision(foul and "eight_foul"or "eight_break",g.turn,now);return
  elseif foul then
   g.foul=foul;g.turn=other
   g:setDecision(foul=="weak_break"and "illegal_break"or "break_foul",other,now);return
  end
 else
  if eight.pocketed then
   local legal=g.eightAllowed and not foul and not g.safety
   g.foul=foul or(not g.eightAllowed and "early_eight"or(not legal and "illegal_eight"or nil))
   g:endRack(legal and id or(#g.players==2 and other or 0),legal and "Восьмёрка · победа"or "Восьмёрка с нарушением · поражение");return
  end
 end
 local made=false
 if not foul and not g.safety and not g.breakShot then
  for _,bid in ipairs(pots)do
   local group=Rules.group(bid)
   if group then
    if not gr then
     gr=group;g.groups[id]=gr
     if #g.players==2 then g.groups[other]=gr=="solids"and "stripes"or "solids"end
    end
    if group==gr then made=true end
   end
  end
 end
 for _,p in ipairs(g.players)do g.scores[p.id]=g.groups[p.id]and(7-g:groupRemaining(g.groups[p.id]))or 0 end
 local continue=g.breakShot and #pots>0 or(not g.breakShot and made)
 g.phase="aiming";g.foul=foul
 if foul then Physics.respawnCue(g.balls,g:parameters());g.cueId=0;g.ballInHand="table"end
 g:beginTurn((foul or not continue)and other or id,now)
 g.note=foul and "Фол · биток с руки"or(g.safety and "Отыгрыш · переход хода"or(continue and "Шар забит · продолжай"or "Переход хода"))
end
function Rules.pyramid(g,now)
 local id,other=g.shooter,g:opponent(g.shooter);local t,pots=g.trace,g.potted
 local foul=t.firstContact==nil and "no_contact"or nil
 if not foul and g.breakShot and #pots==0 and not(count(t.objectsAtRail)>=3 or(count(t.objectsAtRail)>=2 and t.objectCrossed))then foul="weak_break"end
 if not foul and not g.breakShot and #pots==0 and not t.pyramidLegal then foul="no_rail"end
 if foul then
  for _,bid in ipairs(pots)do Physics.spot(g.balls,bid,g:parameters())end
  g.foul=foul;g.phase=#g.players==2 and "penalty"or "aiming";g.pendingPenalty=#g.players==2 and other or nil
  g.pyramidBreakOptions=g.breakShot and #g.players==2;g:beginTurn(other,now)
  g.note=#g.players==2 and "Фол · выбери штрафной шар"or "Фол · шары возвращены"
 else
  g.scores[id]=(g.scores[id]or 0)+#pots;g.phase="aiming";g.foul=nil;g:beginTurn(#pots>0 and id or other,now)
  g.note=#pots>0 and "Шар на полке · продолжай"or "Переход хода"
  if g.scores[id]>=8 then g:endRack(id,"Восемь шаров · победа")end
 end
 g:chooseCue()
end
function Rules.nineFoul(g,id,reason,now)
 local other=g:opponent(id);g.nineFouls[id]=(g.nineFouls[id]or 0)+1;g.foul=reason;g.pushOutAvailable=false
 if g.nineFouls[id]>=3 then g:endRack(#g.players==2 and other or 0,"Три фола подряд · поражение");return end
 Physics.respawnCue(g.balls,g:parameters());g.cueId=0;g.ballInHand="table";g.phase="aiming";g:beginTurn(other,now)
 g.note="Фол · биток с руки по всему столу"
end
function Rules.nine(g,now)
 local id,other=g.shooter,g:opponent(g.shooter);local t,pots=g.trace,g.potted
 local nine,cue=Physics.ball(g.balls,9),Physics.ball(g.balls,0)
 local foul=cue.pocketed and "scratch"or nil
 if not g.pushOutShot then
  if t.firstContact==nil then foul=foul or "no_contact"elseif t.firstContact~=g.nineTarget then foul=foul or "wrong_first"end
  if g.breakShot then if #pots==0 and count(t.objectsAtRail)<4 then foul=foul or "weak_break"end
  elseif #pots==0 and(t.railCount or 0)==0 then foul=foul or "no_rail"end
 end
 if foul then
  if nine.pocketed then Physics.spot(g.balls,9,g:parameters())end
  Rules.nineFoul(g,id,foul,now);return
 end
 g.nineFouls[id]=0;g.foul=nil
 if g.pushOutShot then
  if nine.pocketed then Physics.spot(g.balls,9,g:parameters())end
  g:setDecision("nine_pushout",other,now);g.note="Push-out · соперник принимает позицию или возвращает удар";return
 end
 if g.breakShot then
  local passed={};for bid in pairs(t.headCrossedObjects or {})do passed[bid]=true end;for _,bid in ipairs(pots)do if bid~=0 then passed[bid]=true end end
  if count(passed)<3 then
   if nine.pocketed then Physics.spot(g.balls,9,g:parameters())end
   g:setDecision("nine_break",other,now);g.note="Разбой: меньше трёх шаров за домом / в лузах";return
  end
 end
 if nine.pocketed then g:endRack(id,"Девятка · победа");return end
 g.phase="aiming";g:beginTurn(#pots>0 and id or other,now);g.pushOutAvailable=g.breakShot==true
 g.note=#pots>0 and "Шар забит · продолжай с младшего"or "Переход хода · младший шар первым"
end
function Rules.finish(g,now)if g.mode=="pyramid"then Rules.pyramid(g,now)elseif g.mode=="pool9"then Rules.nine(g,now)else Rules.pool(g,now)end end
return Rules
