local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local PolicyService=game:GetService("PolicyService")
local Http=game:GetService("HttpService")
local Rules=require(Storage.SpyShared.TradeRules)
local TradeStore=require(script.Parent.TradeStore)
local Service={};Service.__index=Service
local function clone(v)if type(v)~="table" then return v end;local n={}for k,x in pairs(v)do n[k]=clone(x)end return n end
local function finished(s)return s.stage=="complete" or s.stage=="cancelled" end
-- History is written during apply, before the two-profile journal is finished.
-- Any still-reserved ID is therefore excluded, including its mirrored entry.
-- This is a sample of loaded club profiles, never a global price or inventory DTO.
function Service:exchangeSamples()
 local blocked,byId,conflicts={},{},{}
 for _,profile in pairs(self.profiles.cache or {}) do
  if type(profile)=="table" and type(profile.pendingTrade)=="table" and type(profile.pendingTrade.id)=="string" then blocked[profile.pendingTrade.id]=true end
 end
 for _,session in pairs(self.sessions or {}) do
  if type(session)=="table" and session.stage~="complete" and type(session.id)=="string" then blocked[session.id]=true end
 end
 local function items(value)
  if type(value)~="table" or #value<1 or #value>4 then return nil end
  local count=0
  for key in pairs(value) do
   if type(key)~="number" or key%1~=0 or key<1 or key>#value then return nil end
   count+=1
  end
  if count~=#value then return nil end
  local result={}
  for _,id in ipairs(value) do
   if type(id)~="string" or #id>80 or not self.catalog.ById or not self.catalog.ById[id] then return nil end
   table.insert(result,id)
  end
  table.sort(result);return result
 end
 for _,profile in pairs(self.profiles.cache or {}) do
  if type(profile)=="table" and type(profile.tradeHistory)=="table" then
   for index=1,math.min(#profile.tradeHistory,100) do
    local row=profile.tradeHistory[index]
    if type(row)=="table" and type(row.id)=="string" and #row.id>0 and #row.id<=64 and row.id:match("^[%w%-]+$") and not blocked[row.id]
     and type(row.at)=="number" and row.at==row.at and row.at>0 and row.at<math.huge and row.at%1==0
     and (row.phase==nil or row.phase=="complete") and (row.stage==nil or row.stage=="complete") then
     local gave,received=items(row.gave),items(row.received)
     if gave and received then
      -- Mirrored participants describe the same exchange in opposite directions.
      -- Stable item-side ordering deduplicates them without publishing identities.
      if table.concat(gave,"\0")>table.concat(received,"\0") then gave,received=received,gave end
      local clean={id=row.id,at=row.at,gave=gave,received=received}
      local previous=byId[row.id]
      if previous and (previous.at~=clean.at or table.concat(previous.gave,"\0")~=table.concat(gave,"\0") or table.concat(previous.received,"\0")~=table.concat(received,"\0")) then conflicts[row.id]=true
      else byId[row.id]=clean end
     end
    end
   end
  end
 end
 local result={}
 for id,row in pairs(byId) do if not conflicts[id] then table.insert(result,row) end end
 table.sort(result,function(a,b)return a.at==b.at and a.id<b.id or a.at>b.at end)
 while #result>20 do table.remove(result) end
 return result
end
function Service.recovery(profiles,catalog,onChange)
 local repository=TradeStore.new(profiles,catalog,onChange)
 local active={}
 local function recover(_,id)
  if active[id] then return end;active[id]=true
  task.spawn(function()
   for attempt=1,12 do
    local _,code=repository:recover(id)
    if code=="complete" or code=="aborted" then break end
    task.wait(math.min(30,2^math.min(attempt,5)))
   end
   active[id]=nil
  end)
 end
 profiles.onTradePending=recover
 for uid,p in pairs(profiles.cache) do if p.pendingTrade then recover(uid,p.pendingTrade.id) end end
 return repository
end
function Service:policyFor(p,force)
 local entry=self.policy[p.UserId]
 if not force and entry and (entry.state=="ready" or entry.state=="blocked" or entry.state=="checking") then return entry.state end
 if not force and entry and os.clock()-(entry.at or 0)<5 then return entry.state end
 local generation=(entry and entry.generation or 0)+1
 entry={state="checking",generation=generation,at=os.clock()};self.policy[p.UserId]=entry
 p:SetAttribute("SpyTradePolicy","checking")
 task.delay(8,function()
  if self.policy[p.UserId]==entry and entry.state=="checking" then
   entry.state="failed";entry.generation+=1;p:SetAttribute("SpyTradePolicy","failed");self:push(p)
  end
 end)
 task.spawn(function()
  local ok,result
  if self.profiles.studio then ok,result=true,{IsPaidItemTradingAllowed=true}
  else ok,result=pcall(PolicyService.GetPolicyInfoForPlayerAsync,PolicyService,p) end
  if self.policy[p.UserId]~=entry or entry.generation~=generation or p.Parent~=Players then return end
  entry.state=ok and type(result)=="table" and result.IsPaidItemTradingAllowed==true and "ready"
   or ok and type(result)=="table" and result.IsPaidItemTradingAllowed==false and "blocked" or "failed"
  p:SetAttribute("SpyTradePolicy",entry.state);self:push(p)
 end)
 return entry.state
end
function Service:snapshot(p,override)
 local s=override or self.byUser[p.UserId] or self.terminal[p.UserId]
 local view
 if s then
  local otherId=s.a==p.UserId and s.b or s.a
  local other=Players:GetPlayerByUserId(otherId)
  local identity=s.names[otherId]
  view={id=s.id,revision=s.revision,stage=s.stage,inviterId=s.a,
   partner={id=otherId,name=other and other.Name or identity.name,displayName=other and other.DisplayName or identity.displayName},
   selfOffer=clone(s.offers[p.UserId]),otherOffer=clone(s.offers[otherId]),selfReady=s.ready[p.UserId]==true,otherReady=s.ready[otherId]==true,
   selfConfirmed=s.confirmed[p.UserId]==true,otherConfirmed=s.confirmed[otherId]==true,confirmAt=s.confirmAt or 0,expiresAt=s.expiresAt,reason=s.reason}
 end
 local list={}
 for _,other in ipairs(Players:GetPlayers()) do
  if other~=p then table.insert(list,{id=other.UserId,name=other.Name,displayName=other.DisplayName,
   busy=self.byUser[other.UserId]~=nil,available=self.profiles:public(other.UserId).ready==true}) end
 end
 return {serverNow=os.time(),policy=self.policy[p.UserId] and self.policy[p.UserId].state or "checking",profile=self.profiles:public(p.UserId),
  players=list,invitesEnabled=self.profiles:public(p.UserId).tradeInvitesEnabled~=false,session=view,studio=self.profiles.studio,exchangeSamples=self:exchangeSamples()}
end
function Service:push(p,requestId,ok,code,override)
 if not p or p.Parent~=Players then return end
 local state=self:snapshot(p,override);state.requestId=requestId;state.ok=ok==nil and true or ok;state.code=code or "state"
 self.sequenceByUser[p.UserId]=(self.sequenceByUser[p.UserId] or 0)+1
 state.sequence=self.sequenceByUser[p.UserId]
 self.state:FireClient(p,state)
end
function Service:broadcast(s)
 self:push(Players:GetPlayerByUserId(s.a),nil,true,"state",s)
 self:push(Players:GetPlayerByUserId(s.b),nil,true,"state",s)
end
function Service:close(s,reason)
 if s.stage=="saving" or finished(s) then return end
 s.stage="cancelled";s.reason=reason
 for _,uid in ipairs({s.a,s.b}) do
  if self.byUser[uid]==s then self.byUser[uid]=nil end
  self.terminal[uid]=s
 end
 self:broadcast(s)
end
function Service:watch(s)
 task.delay(math.min(10,math.max(1,s.expiresAt-os.time())),function()
  if finished(s) or s.stage=="saving" then return end
  if os.time()>=s.expiresAt then self:close(s,"expired") else self:watch(s) end
 end)
end
function Service:available(p)
 local profile=self.profiles:public(p.UserId)
 if not profile.ready then return false,"profile_unavailable" end
 if profile.pendingTrade then return false,"trade_processing" end
 if not self.canTrade(p) then return false,"unavailable" end
 if self:policyFor(p)~="ready" then return false,"policy_unavailable" end
 return true
end
function Service:runSave(s)
 if self.saving[s.id] then return end;self.saving[s.id]=true
 task.spawn(function()
  if not s.record then
   local a,b=Players:GetPlayerByUserId(s.a),Players:GetPlayerByUserId(s.b)
   if not a or not b or not self.canTrade(a) or not self.canTrade(b) then
    s.stage="review";self.saving[s.id]=nil;self:close(s,"unavailable");return
   end
   -- Recheck permissions through the same bounded gateway used on startup.
   -- A hung platform request cannot leave an uncommitted trade in saving.
   self:policyFor(a,true);self:policyFor(b,true)
   local deadline=os.clock()+8.5
   while os.clock()<deadline and ((self.policy[a.UserId] and self.policy[a.UserId].state=="checking")
    or (self.policy[b.UserId] and self.policy[b.UserId].state=="checking")) do task.wait(.1) end
   for _,p in ipairs({a,b}) do
    if p.Parent~=Players or not self.canTrade(p) or not self.policy[p.UserId] or self.policy[p.UserId].state~="ready" then
     s.stage="review";self.saving[s.id]=nil;self:close(s,"policy_unavailable");return
    end
   end
   s.record={id=s.id,a=s.a,b=s.b,offers={[tostring(s.a)]=clone(s.offers[s.a]),[tostring(s.b)]=clone(s.offers[s.b])},
    owner=game.JobId,phase="preparing",createdAt=os.time(),leaseUntil=os.time()+60}
  end
  for attempt=1,12 do
   local record,code=self.repository:execute(s.record)
   if code=="complete" or code=="aborted" then
    s.stage=code=="complete" and "complete" or "cancelled";s.reason=record and record.reason or code
    for _,uid in ipairs({s.a,s.b}) do if self.byUser[uid]==s then self.byUser[uid]=nil end;self.terminal[uid]=s end
    self:broadcast(s);break
   end
   if attempt<12 then task.wait(math.min(30,2^math.min(attempt,5))) end
  end
  self.saving[s.id]=nil
 end)
end
function Service:handle(p,data)
 if type(data)~="table" or type(data.requestId)~="string" or #data.requestId>64 or not data.requestId:match("^[%w%-]+$") then return end
 local request=data.requestId;local action=data.action
 local function reply(ok,code,s)self:push(p,request,ok,code,s)end
 local state=self.rate[p.UserId] or {at=-1000,seen={},order={}};self.rate[p.UserId]=state
 if state.seen[request] then reply(true,"already_processed");return end
 if os.clock()-state.at<.12 then reply(false,"slow_down");return end
 state.at=os.clock();state.seen[request]=true;table.insert(state.order,request)
 while #state.order>64 do state.seen[table.remove(state.order,1)]=nil end
 if action=="sync" then
  self:policyFor(p);local current=self.byUser[p.UserId];if current and current.stage=="saving" then self:runSave(current) end
  local pending=self.profiles:public(p.UserId).pendingTrade
  if pending and type(self.profiles.onTradePending)=="function" then task.spawn(self.profiles.onTradePending,p.UserId,pending.id) end
  reply(true,"state");return
 end
 if action=="setInvites" then
  if type(data.enabled)~="boolean" then reply(false,"invalid_request");return end
  local receipt=self.profiles:transact(p.UserId,"tradepref:"..p.UserId..":"..request,{kind="tradeSettings",enabled=data.enabled})
  pcall(self.onChange,p.UserId,"settings");reply(receipt.ok,receipt.code or "settings");return
 end
 if action=="invite" then
  local id=data.targetId
  if type(id)~="number" or id%1~=0 then reply(false,"invalid_request");return end
  if id==p.UserId then reply(false,"self_trade");return end
  local other=Players:GetPlayerByUserId(id)
  if not other then reply(false,"player_left");return end
  if self.profiles:public(id).tradeInvitesEnabled==false then reply(false,"invites_disabled");return end
  if self.byUser[id] or self.byUser[p.UserId] then reply(false,"trade_busy");return end
  for _,party in ipairs({p,other}) do local ok,code=self:available(party);if not ok then reply(false,code);return end end
  local key=tostring(p.UserId)..":"..tostring(id)
  if os.clock()-(self.invitedAt[key] or -1000)<30 then reply(false,"invite_cooldown");return end
  self.invitedAt[key]=os.clock()
  local s={id=Http:GenerateGUID(false),a=p.UserId,b=id,revision=1,stage="invited",offers={[p.UserId]={},[id]={}},ready={},confirmed={},expiresAt=os.time()+20,
   names={[p.UserId]={name=p.Name,displayName=p.DisplayName},[id]={name=other.Name,displayName=other.DisplayName}}}
  self.byUser[p.UserId],self.byUser[id]=s,s;self.terminal[p.UserId],self.terminal[id]=nil,nil
  self.sessions[s.id]=s;self:watch(s);self:broadcast(s);reply(true,"invited",s);return
 end
 local s=type(data.id)=="string" and self.sessions[data.id]
 if not s or (s.a~=p.UserId and s.b~=p.UserId) or self.byUser[p.UserId]~=s then reply(false,"denied");return end
 if data.revision~=s.revision then reply(false,"stale_trade",s);return end
 if action=="cancel" then
  if s.stage=="saving" then reply(false,"trade_processing",s);return end
  self:close(s,"cancelled");reply(true,"cancelled",s);return
 end
 if os.time()>=s.expiresAt then self:close(s,"expired");reply(false,"expired",s);return end
 if action=="respond" then
  if s.stage~="invited" or p.UserId~=s.b or type(data.accept)~="boolean" then reply(false,"denied",s);return end
  if not data.accept then self:close(s,"declined");reply(true,"declined",s);return end
  for _,uid in ipairs({s.a,s.b}) do
   local party=Players:GetPlayerByUserId(uid);local ok,code=false,"player_left"
   if party then ok,code=self:available(party) end
   if not ok then self:close(s,code or "player_left");reply(false,code or "player_left",s);return end
  end
  s.stage="offering";s.expiresAt=os.time()+120;self:broadcast(s);reply(true,"accepted",s);return
 end
 if s.stage~="offering" and s.stage~="review" then reply(false,"trade_processing",s);return end
 local other=s.a==p.UserId and s.b or s.a
 if action=="offer" then
  local count=0
  if type(data.items)~="table" then reply(false,"invalid_offer",s);return end
  for k in pairs(data.items) do if type(k)~="number" or k%1~=0 or k<1 or k>4 then reply(false,"invalid_offer",s);return end;count+=1 end
  if count~=#data.items or count>4 then reply(false,"invalid_offer",s);return end
  local clean,code={},"ok"
  if count>0 then clean,code=Rules.offer(self.profiles:public(p.UserId),data.items,self.profiles:public(other),self.catalog) end
  if not clean then reply(false,code,s);return end
  s.offers[p.UserId]=clean;s.revision+=1;s.ready={};s.confirmed={};s.confirmAt=nil;s.stage="offering";s.expiresAt=os.time()+120
  self:broadcast(s);reply(true,"offer_updated",s);return
 end
 if action=="ready" then
  if type(data.ready)~="boolean" then reply(false,"invalid_request",s);return end
  if data.ready and #s.offers[s.a]+#s.offers[s.b]==0 then reply(false,"empty_offer",s);return end
  for _,uid in ipairs({s.a,s.b}) do
   local peer=uid==s.a and s.b or s.a
   local clean,code=Rules.offer(self.profiles:public(uid),s.offers[uid],self.profiles:public(peer),self.catalog)
   if data.ready and not clean then reply(false,code,s);return end
  end
  s.ready[p.UserId]=data.ready;s.confirmed={};s.confirmAt=nil
  s.stage=s.ready[s.a] and s.ready[s.b] and "review" or "offering"
  if s.stage=="review" then s.confirmAt=os.time()+3 end
  s.expiresAt=os.time()+120;self:broadcast(s);reply(true,"ready_updated",s);return
 end
 if action=="confirm" then
  if s.stage~="review" or not s.ready[s.a] or not s.ready[s.b] then reply(false,"not_ready",s);return end
  if os.time()<(s.confirmAt or math.huge) then reply(false,"review_wait",s);return end
  for _,uid in ipairs({s.a,s.b}) do
   local party=Players:GetPlayerByUserId(uid);local ok,code=false,"player_left"
   if party then ok,code=self:available(party) end
   if not ok then reply(false,code or "player_left",s);return end
  end
  s.confirmed[p.UserId]=true
  if s.confirmed[s.a] and s.confirmed[s.b] then s.stage="saving";self:runSave(s) end
  self:broadcast(s);reply(true,"confirmed",s);return
 end
 reply(false,"invalid_request",s)
end
function Service.attach(profiles,catalog,onChange,canTrade)
 local shared=Storage.SpyShared
 local function remote(name)
  local n=shared:FindFirstChild(name) or Instance.new("RemoteEvent");n.Name=name;n.Parent=shared;return n
 end
 local self=setmetatable({profiles=profiles,catalog=catalog,onChange=onChange or function()end,canTrade=canTrade or function()return true end,
  sessions={},byUser={},terminal={},rate={},policy={},saving={},invitedAt={},sequenceByUser={},action=remote("TradeAction"),state=remote("TradeState")},Service)
 self.repository=Service.recovery(profiles,catalog,function(uid,phase)
  pcall(self.onChange,uid,phase)
  self:push(Players:GetPlayerByUserId(uid))
 end)
 self.action.OnServerEvent:Connect(function(p,data)
  local ok,err=xpcall(function()self:handle(p,data)end,debug.traceback)
  if not ok then warn("SpyClub trade request failed: "..tostring(err));self:push(p,type(data)=="table" and data.requestId or nil,false,"unavailable") end
 end)
 local function joined(p)self:policyFor(p)end
 Players.PlayerAdded:Connect(joined);for _,p in ipairs(Players:GetPlayers()) do joined(p) end
 Players.PlayerRemoving:Connect(function(p)
  local s=self.byUser[p.UserId];if s and s.stage~="saving" then self:close(s,"player_left") end
  self.policy[p.UserId],self.rate[p.UserId]=nil,nil
 end)
 return self
end
return Service
