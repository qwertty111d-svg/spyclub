-- Russian draughts: pure rules, independent of Roblox services or player profiles.
local Core={}
local directions={{1,1},{-1,1},{1,-1},{-1,-1}}
local function valid(n)return type(n)=="number"and n==n and n>=1 and n<=64 and n%1==0 end
local function square(c,r)if c>=1 and c<=8 and r>=1 and r<=8 then return(r-1)*8+c end end
local function coords(s)return(s-1)%8+1,math.floor((s-1)/8)+1 end
local function side(v)return v>0 and 1 or 2 end
local function key(st)return st.turn..":"..table.concat(st.board,",")end
function Core.new(position,turn)
 local st={board=table.create(64,0),ids=table.create(64,0),turn=turn==2 and 2 or 1,captured={},ply=0,status="playing",quietKings=0,repetitions={}}
 local id=0
 for i=1,64 do
  local c,r=coords(i);local v=position and(position[i]or 0)or(((c+r)%2==0)and(r<=3 and 1 or(r>=6 and -1 or 0))or 0)
  st.board[i]=v;if v~=0 then id+=1;st.ids[i]=id end
 end
 st.repetitions[key(st)]=1;return st
end
local function captures(st,from)
 local result={};local value=st.board[from];if value==0 or st.captured[from]then return result end
 local c,r=coords(from)
 for _,d in ipairs(directions)do
  local step=1;local victim
  while true do
   local target=square(c+d[1]*step,r+d[2]*step);if not target then break end
   local other=st.board[target]
   if other~=0 then
    if victim or st.captured[target]or side(other)==side(value)then break end
    victim=target
   elseif victim then
    result[#result+1]={from=from,to=target,over=victim}
    if math.abs(value)==1 then break end
   elseif math.abs(value)==1 then break end
   step+=1;if math.abs(value)==1 and step>2 then break end
  end
 end
 return result
end
function Core.moves(st)
 if st.status~="playing"then return{}end
 if st.chain then return captures(st,st.chain)end
 local take={}
 for i,v in ipairs(st.board)do if v~=0 and side(v)==st.turn then for _,m in ipairs(captures(st,i))do take[#take+1]=m end end end
 if #take>0 then return take end
 local moves={}
 for i,v in ipairs(st.board)do if v~=0 and side(v)==st.turn then
  local c,r=coords(i)
  for _,d in ipairs(directions)do if math.abs(v)==2 or d[2]==(st.turn==1 and 1 or -1)then
   local step=1
   while true do
    local target=square(c+d[1]*step,r+d[2]*step)
    if not target or st.board[target]~=0 then break end
    moves[#moves+1]={from=i,to=target};if math.abs(v)==1 then break end;step+=1
   end
  end end
 end end
 return moves
end
function Core.play(st,from,to)
 if not valid(from)or not valid(to)or st.status~="playing"then return false,"invalid_move"end
 local move
 for _,m in ipairs(Core.moves(st))do if m.from==from and m.to==to then move=m;break end end
 if not move then return false,"illegal_move"end
 local value=st.board[from];local id=st.ids[from]
 if not st.chain then st.turnWasKing=math.abs(value)==2;st.turnHadCapture=false;st.lastMove={from=from,to=to}end
 st.board[from]=0;st.ids[from]=0;st.board[to]=value;st.ids[to]=id;st.lastMove.to=to
 local _,r=coords(to)
 if math.abs(value)==1 and r==(st.turn==1 and 8 or 1)then st.board[to]=value*2;st.promoted=true end
 if move.over then
  st.captured[move.over]=true;st.turnHadCapture=true;st.chain=to
  if #captures(st,to)>0 then return true,"continue"end
 end
 for s in pairs(st.captured)do st.board[s]=0;st.ids[s]=0 end
 st.captured={};st.chain=nil;st.ply+=1
 st.quietKings=(st.turnWasKing and not st.turnHadCapture and not st.promoted)and(st.quietKings+1)or 0
 st.promoted=nil;local previous=st.turn;st.turn=3-st.turn
 if #Core.moves(st)==0 then st.status="finished";st.winner=previous;st.reason="no_moves"
 else
  local k=key(st);st.repetitions[k]=(st.repetitions[k]or 0)+1
  if st.repetitions[k]>=3 or st.quietKings>=30 then st.status="finished";st.winner=0;st.reason=st.repetitions[k]>=3 and"repetition"or"quiet_kings"end
 end
 return true,st.status=="finished"and"finished"or"moved"
end
function Core.snapshot(st)
 local pieces={}
 for s,v in ipairs(st.board)do if v~=0 then pieces[#pieces+1]={id=st.ids[s],square=s,side=side(v),king=math.abs(v)==2,captured=st.captured[s]==true}end end
 return{board=table.clone(st.board),pieces=pieces,turn=st.turn,chain=st.chain,ply=st.ply,status=st.status,winner=st.winner,reason=st.reason,lastMove=st.lastMove and table.clone(st.lastMove),moves=Core.moves(st)}
end
local function copy(st)
 local n=table.clone(st);n.board=table.clone(st.board);n.ids=table.clone(st.ids);n.captured=table.clone(st.captured);n.repetitions=table.clone(st.repetitions)
 n.lastMove=st.lastMove and table.clone(st.lastMove);return n
end
local function evaluate(st,perspective)
 if st.status=="finished"then return st.winner==0 and 0 or(st.winner==perspective and 10000 or -10000)end
 local score=0
 for s,v in ipairs(st.board)do if v~=0 and not st.captured[s]then
  local c,r=coords(s);local strength=math.abs(v)==2 and 3.2 or 1+(v>0 and r-1 or 8-r)*.045
  strength+=(4.5-math.abs(c-4.5))*.012;score+=(side(v)==perspective and 1 or -1)*strength
 end end
 return score
end
function Core.choose(st)
 local best,bestScore;local perspective=st.turn
 for _,move in ipairs(Core.moves(st))do
  local n=copy(st);Core.play(n,move.from,move.to);local score=evaluate(n,perspective)
  -- Avoid obvious hanging pieces; bounded one-reply search, never a client calculation.
  if n.status=="playing"and n.turn~=perspective then
   local worst=math.huge
   for _,reply in ipairs(Core.moves(n))do local after=copy(n);Core.play(after,reply.from,reply.to);worst=math.min(worst,evaluate(after,perspective))end
   if worst<math.huge then score=worst end
  end
  if not best or score>bestScore then best=move;bestScore=score end
 end
 return best
end
return Core
