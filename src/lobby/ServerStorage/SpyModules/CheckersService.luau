local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Core=require(script.Parent.CheckersCore)
local Model=require(script.Parent.CheckersModel)
local Service={}
local sessions=setmetatable({},{__mode="k"})
function Service.start(group)
 if sessions[group]and sessions[group].live then return sessions[group]end
 local self={live=true,core=Core,game=Core.new(),players={},phase="waiting",revision=1,votes={}}
 self.board=Model.build(group)
 local folder=Instance.new("Folder");folder.Name="SpyCheckers";folder.Parent=Storage;self.folder=folder
 local function remote(name)local r=Instance.new("RemoteEvent");r.Name=name;r.Parent=folder;return r end
 self.action=remote("Action");self.state=remote("State")
 local viewers,connections={},{}
 local function connect(event,f)local c=event:Connect(f);connections[#connections+1]=c;return c end
 local function now()return workspace:GetServerTimeNow()end
 local function member(uid)for side,p in pairs(self.players)do if p.id==uid then return side end end end
 local function near(p)
  local c=p.Character;local root=c and c:FindFirstChild("HumanoidRootPart");local h=c and c:FindFirstChildOfClass("Humanoid")
  if not root or not h or h.Health<=0 then return false end
  local delta=root.Position-self.board.center
  return delta.X==delta.X and delta.Z==delta.Z and delta.Y==delta.Y and delta.X^2+delta.Z^2<=64 and math.abs(delta.Y)<5
 end
 local function available(p)
  if p.Parent~=Players or p:GetAttribute("SpyTeleporting")or p:GetAttribute("SpyReconnectBusy")or p:GetAttribute("SpyEntryActive")or p:GetAttribute("SpyEntryPending")or p:GetAttribute("SpyBilliardsPlaying")then return false end
  local c=p.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
  return h and h.Health>0 and(not h.SeatPart or h.SeatPart==self.board.seats[1]or h.SeatPart==self.board.seats[2])
 end
 local function send(p,ok,code,open,closed)
  if p.Parent~=Players then return end
  local data=Core.snapshot(self.game)
  data.phase=self.phase;data.revision=self.revision;data.players=table.clone(self.players);data.role=member(p.UserId)or 0
  data.result=self.result and table.clone(self.result)or nil
  data.center=self.board.center;data.cell=self.board.cell;data.deadline=self.deadline;data.drawOffer=self.drawOffer;data.rematchVotes=table.clone(self.votes)
  data.ok=ok;data.code=code;data.open=open==true;data.closed=closed==true
  self.state:FireClient(p,data)
 end
 local function publish()for _,v in pairs(viewers)do send(v.player,true,"state",false)end end
 local function render()self.board:render(self.game)end
 local function change()self.revision+=1;render();publish()end
 local function unsit(p)
  p:SetAttribute("SpyCheckersPlaying",false)
  local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if h and(h.SeatPart==self.board.seats[1]or h.SeatPart==self.board.seats[2])then h.Sit=false end
 end
 local function finish(winner,reason)
  self.phase="finished";self.game.status="finished";self.game.winner=winner;self.game.reason=reason
  local entry=self.players[winner]
  self.result={side=winner,id=entry and entry.id or nil,name=entry and entry.name or nil}
  self.deadline=nil;self.botAt=nil;self.drawOffer=nil;self.votes={}
 end
 local function startGame()
  self.game=Core.new();self.phase="playing";self.deadline=now()+90;self.drawOffer=nil;self.votes={}
  self.result=nil
  self.botAt=self.players[1]and self.players[1].id==0 and now()+1 or nil
 end
 local function remove(p,reason)
  local side=member(p.UserId)
  if side then
   if self.phase=="playing"then finish(3-side,reason or"left")end
   self.players[side]=nil;unsit(p)
   if self.players[3-side]and self.players[3-side].id==0 then self.players[3-side]=nil end
   if not next(self.players)then self.phase="waiting";self.game=Core.new();self.result=nil;self.votes={};self.deadline=nil;self.botAt=nil end
   self.revision+=1;render();publish()
  end
  if viewers[p.UserId]then send(p,reason==nil or reason=="left",reason or"left",false,true)end
  viewers[p.UserId]=nil
 end
 local function move(from,to)
  local before=self.game.ply;local ok,code=Core.play(self.game,from,to)
  if not ok then return ok,code end
  self.drawOffer=nil
  if self.game.status=="finished"then finish(self.game.winner,self.game.reason)
  elseif self.game.ply~=before then self.deadline=now()+90 end
  if self.phase=="playing"and self.players[self.game.turn]and self.players[self.game.turn].id==0 then self.botAt=now()+.8 else self.botAt=nil end
  return true,code
 end
 connect(self.board.prompt.Triggered,function(p)
  if self.live and near(p)and available(p)then viewers[p.UserId]=viewers[p.UserId]or{player=p,last=-math.huge};send(p,true,"open",true)end
 end)
 connect(self.action.OnServerEvent,function(p,payload)
  if not self.live or type(payload)~="table"or type(payload.action)~="string"then return end
  local v=viewers[p.UserId];if not v then return end
  local act=payload.action
  if act=="leave"then remove(p,"left");return end
  if now()-v.last<.08 then
   if now()>=(v.noticeAt or 0)then v.noticeAt=now()+1;send(p,false,"rate_limited",false)end
   return
  end
  v.last=now()
  if not near(p)or not available(p)then remove(p,"unavailable");return end
  if act=="sync"then send(p,true,"state",false);return end
  if payload.revision~=self.revision then send(p,false,"stale",false);return end
  local side=member(p.UserId);local ok,code=false,"invalid_action"
  if act=="join"then
   local choice=payload.side
   if choice~=1 and choice~=2 then code="invalid_side"
   elseif self.players[choice]then code="occupied"
   elseif side then code="already_joined"
   else
    local h=p.Character:FindFirstChildOfClass("Humanoid");local seat=self.board.seats[choice]
    if seat.Occupant and seat.Occupant~=h then code="occupied"
    else
     self.players[choice]={id=p.UserId,name=p.DisplayName};p:SetAttribute("SpyCheckersPlaying",true);seat:Sit(h)
     if self.players[1]and self.players[2]then startGame()else self.phase="waiting";self.game=Core.new();self.votes={}end
     ok=true;code="joined"
    end
   end
  elseif act=="practice"then
   if not side then code="join_first"
   elseif self.players[3-side]then code="occupied"
   else self.players[3-side]={id=0,name="Клуб"};startGame();ok=true;code="practice"end
  elseif act=="move"then
   if self.phase~="playing"then code="not_playing"
   elseif not side or side~=self.game.turn then code="not_turn"
   else ok,code=move(payload.from,payload.to)end
  elseif act=="draw"then
   if not side or self.phase~="playing"then code="not_playing"
   elseif self.players[3-side].id==0 or(self.drawOffer and self.drawOffer~=p.UserId)then finish(0,"agreement");ok=true;code="draw"
   else self.drawOffer=p.UserId;ok=true;code="draw_offered"end
  elseif act=="resign"then
   if side and self.phase=="playing"then finish(3-side,"resigned");ok=true;code="resigned"else code="not_playing"end
  elseif act=="rematch"then
   if not side or self.phase~="finished"then code="not_finished"
   elseif not self.players[3-side]then code="waiting_opponent"
   else
    self.votes[p.UserId]=true
    if self.players[3-side].id==0 or self.votes[self.players[3-side].id]then startGame()end
    ok=true;code="rematch"
   end
  end
  if ok then change()end
  send(p,ok,code,false)
 end)
 local function watch(p)
  connect(p.CharacterRemoving,function()if self.live then remove(p,"unavailable")end end)
  for _,name in ipairs({"SpyTeleporting","SpyReconnectBusy","SpyBilliardsPlaying"})do
   connect(p:GetAttributeChangedSignal(name),function()if self.live and p:GetAttribute(name)then remove(p,"unavailable")end end)
  end
 end
 for _,p in ipairs(Players:GetPlayers())do watch(p)end
 connect(Players.PlayerAdded,watch);connect(Players.PlayerRemoving,function(p)remove(p,"left")end)
 local accumulator=0
 connect(RunService.Heartbeat,function(dt)
  if not self.live or type(dt)~="number"or dt~=dt or dt<=0 then return end
  accumulator+=math.min(dt,1);if accumulator<.5 then return end;accumulator=0
  local absent={}
  for _,v in pairs(viewers)do if not near(v.player)or not available(v.player)then absent[#absent+1]=v.player end end
  for _,p in ipairs(absent)do remove(p,"unavailable")end
  if self.phase=="playing"then
   if self.deadline and now()>=self.deadline then finish(3-self.game.turn,"timeout");change()
   elseif self.botAt and now()>=self.botAt then
    local choice=Core.choose(self.game)
    if choice then move(choice.from,choice.to);change()else finish(3-self.game.turn,"no_moves");change()end
   end
  end
 end)
 function self.stop()
  if not self.live then return end;self.live=false
  for _,c in ipairs(connections)do c:Disconnect()end
  for _,v in pairs(viewers)do unsit(v.player);send(v.player,true,"closed",false,true)end
  viewers={};self.board:destroy();folder:Destroy();sessions[group]=nil
 end
 connect(group.Destroying,self.stop);folder:SetAttribute("Ready",true);render();sessions[group]=self;return self
end
return Service
