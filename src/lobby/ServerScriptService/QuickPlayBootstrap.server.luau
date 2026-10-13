-- Player/nonce ownership around yielding cloud calls. Optional; no game-wide boot lease.
local Bootstrap={};Bootstrap.__index=Bootstrap
function Bootstrap.new(d)return setmetatable({d=d,active={},retired={}},Bootstrap)end
function Bootstrap:current(p,e)
 return e and self.active[p.UserId]==e and e.player==p and not e.withdrawn and p.Parent==self.d.players and self.d.players:GetPlayerByUserId(p.UserId)==p
end
function Bootstrap:allowed(p,e)
 return p.Parent==self.d.players and self.d.players:GetPlayerByUserId(p.UserId)==p
  and not p:GetAttribute('SpyPartyMember')and (not p:GetAttribute('SpyRelayTableId')or p:GetAttribute('SpyRelayTableId')=='')
  and not p:GetAttribute('SpyCheckersPlaying')and not p:GetAttribute('SpyBilliardsPlaying')
  and (not p:GetAttribute('SpyTeleporting')or(e and e.ownedTeleport))
  and (p:GetAttribute('SpyProfilePending')or 0)==0 and p:GetAttribute('SpyProfileReady')==true
end
function Bootstrap:send(p,data)
 if p.Parent==self.d.players and self.d.players:GetPlayerByUserId(p.UserId)==p then self.d.fire(p,data)end
 return data
end
function Bootstrap:clear(p,e)
 if self.active[p.UserId]~=e or e.player~=p then return false end
 self.active[p.UserId]=nil;e.withdrawn=true
 p:SetAttribute('SpyQuickQueueActive',false)
 if e.ownedTeleport then p:SetAttribute('SpyTeleporting',false)end
 return true
end
function Bootstrap:retire(e)
 if not e.retired or self.d.clock()>e.retireUntil then e.retired=true;e.retireUntil=self.d.clock()+100;self.retired[#self.retired+1]=e end
end
function Bootstrap:cleanRetired()
 for i=#self.retired,1,-1 do local e=self.retired[i]
  if self.d.clock()>e.retireUntil then table.remove(self.retired,i)
  elseif e.queue and not e.joining then
   local ok,r=pcall(function()return e.queue:leave(e.player.UserId,e.nonce)end)
   if ok and r and r.ok then table.remove(self.retired,i)
   elseif ok and r and r.code=='matched'then
    local t=e.queue:ticket(e.player.UserId,e.nonce)
    if t and e.queue:drop(e.player.UserId,e.nonce,t)then table.remove(self.retired,i)end
   end
  end
 end
end
function Bootstrap:join(p,mode)
 if mode~='classic'and mode~='case'then return {ok=false,code='invalid',state='idle'}end
 local existing=self.active[p.UserId]
 if existing and existing.player==p then return self:send(p,{ok=false,code='busy',state=existing.ownedTeleport and'matched'or'waiting',mode=existing.mode})end
 if not self:allowed(p)then return {ok=false,code='busy',state='idle'}end
 local e={player=p,nonce=self.d.guid(),mode=mode,joinedAt=self.d.clock(),lastGood=self.d.clock(),joining=true,attempts=0}
 self.active[p.UserId]=e;p:SetAttribute('SpyQuickQueueActive',true)
 local ok,q=pcall(self.d.queue);e.queue=ok and q or nil
 if not self:current(p,e)then e.joining=false;self:retire(e);return {ok=true,state='idle'}end
 if not e.queue then e.joining=false;self:clear(p,e);return self:send(p,{ok=false,code='unavailable',state='idle'})end
 local joined,result=pcall(function()return e.queue:join(p.UserId,mode,e.nonce)end);e.joining=false
 if not self:current(p,e)then self:retire(e);self:cleanRetired();return {ok=true,state='idle'}end
 if not joined or not result or not result.ok then self:clear(p,e);self:retire(e);return self:send(p,{ok=false,code=result and result.code or'unavailable',state='idle'})end
 e.lastGood=self.d.clock();return self:send(p,{ok=true,state='waiting',mode=mode,count=1,canCancel=true})
end
function Bootstrap:cancel(p)
 local e=self.active[p.UserId];if not e or e.player~=p then return {ok=true,state='idle'}end
 if e.ownedTeleport then return {ok=false,code='matched',state='matched',mode=e.mode}end
 local now=self.d.clock()
 if e.cancelling or(e.lastCancelAt and now-e.lastCancelAt<1)then return {ok=false,code='busy',state='waiting',mode=e.mode}end
 e.lastCancelAt=now
 e.cancelling=true
 local ok,r=pcall(function()return e.queue and e.queue:leave(p.UserId,e.nonce)end)
 if not self:current(p,e)then return {ok=true,state='idle'}end
 if ok and r and r.code=='matched'then e.cancelling=false;return self:send(p,{ok=false,code='busy',state='preparing',mode=e.mode})end
 self:clear(p,e);self:retire(e);self:cleanRetired()
 return self:send(p,{ok=true,state='idle',code=(not ok or(r and r.code=='unavailable'))and'unavailable'or nil})
end
function Bootstrap:remove(p)
 local e=self.active[p.UserId];if not e or e.player~=p then return end
 self:clear(p,e);if not e.teleportStarted then self:retire(e)end
end
function Bootstrap:fail(p,e,code)
 if self:clear(p,e)then self:retire(e);self:send(p,{ok=false,state='idle',code=code or'unavailable'})end
end
function Bootstrap:watchdog()
 local now=self.d.clock()
 for _,e in pairs(self.active)do local p=e.player
  if not self:current(p,e)then self:remove(p)
  elseif (e.ownedTeleport and now-e.startedAt>30)or(not e.ownedTeleport and now-e.lastGood>20)then self:fail(p,e,'unavailable')end
 end
end
function Bootstrap:launch(p,e,t)
 if not self:current(p,e)or e.cancelling then return end
 if not self:allowed(p,e)then e.blockedAt=e.blockedAt or self.d.clock();if self.d.clock()-e.blockedAt>20 then self:fail(p,e,'busy')end;return end
 if e.ownedTeleport and not e.retry then return end
 if e.retryAt and self.d.clock()<e.retryAt then return end
 if e.attempts>=2 then self:fail(p,e,'unavailable');return end
 e.attempts+=1;e.ownedTeleport=true;e.teleportStarted=true;e.ticket=t;e.startedAt=self.d.clock();e.retry=false
 p:SetAttribute('SpyTeleporting',true);self:send(p,{ok=true,state='matched',mode=e.mode,canCancel=false})
 local ok=pcall(self.d.teleport,p,t)
 if self:current(p,e)and not ok then e.retry=true;e.retryAt=self.d.clock()+2 end
end
function Bootstrap:failed(p)
 local e=self.active[p.UserId];if e and self:current(p,e)and e.ownedTeleport then e.retry=true;e.retryAt=self.d.clock()+2 end
end
function Bootstrap:cycle()
 self:cleanRetired();if not next(self.active)then return end
 local ok,q=pcall(self.d.queue);if not ok or not q then return end
 if self.d.pump then pcall(self.d.pump,q)end
 for _,e in pairs(self.active)do local p=e.player
  if self:current(p,e)and not e.joining and not e.cancelling then
   local read,r=pcall(function()return q:status(p.UserId)end)
   if not self:current(p,e)then continue end
   if read and r and r.ok then
    e.lastGood=self.d.clock();self:send(p,r)
    if r.state=='idle'then self:fail(p,e,'unavailable');continue end
   else self:send(p,{ok=false,state='waiting',mode=e.mode,code='unavailable',canCancel=true})end
   if not self:current(p,e)then continue end
   if not e.lastHeartbeat or self.d.clock()-e.lastHeartbeat>20 then e.lastHeartbeat=self.d.clock();pcall(function()q:heartbeat(p.UserId,e.nonce)end)end
   if not self:current(p,e)then continue end
   local t=q:ticket(p.UserId,e.nonce)
   if self:current(p,e)and t then self:launch(p,e,t)end
  end
 end
end

if not game or not script then return Bootstrap end
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Http=game:GetService('HttpService')
local Teleport=game:GetService('TeleportService');local Run=game:GetService('RunService');local Memory=game:GetService('MemoryStoreService')
local folder=Instance.new('Folder');folder.Name='SpyQuickPlayRemotes';folder.Parent=RS
local rf=Instance.new('RemoteFunction');rf.Name='Request';rf.Parent=folder
local state=Instance.new('RemoteEvent');state.Name='State';state.Parent=folder
local modules=game:GetService('ServerStorage'):WaitForChild('SpyModules',8)
local core,reconnect
local function queue()
 if Run:IsStudio()or not modules then return nil end
 if not core then
  local Q=require(modules.QuickPlayQueue)
  reconnect=require(modules.ReconnectService).default()
  if not reconnect.sessions or not reconnect.tickets then return nil end
  core=Q.new(Memory:GetSortedMap('SpyClubQuickPlayersV1'),Memory:GetHashMap('SpyClubQuickControlV1'),os.time,game.JobId,function()return Http:GenerateGUID(false)end)
 end
 return core
end
local MATCH=135927279331761
local b=Bootstrap.new({players=Players,clock=os.clock,guid=function()return Http:GenerateGUID(false)end,queue=queue,
 fire=function(p,data)state:FireClient(p,data)end,
 pump=function(q)q:pump(function(place)return Teleport:ReserveServerAsync(place)end,reconnect,MATCH,game.PlaceId)end,
 teleport=function(p,t)local options=Instance.new('TeleportOptions');options.ReservedServerAccessCode=t.code;options:SetTeleportData(t.data);Teleport:TeleportAsync(t.placeId,{p},options)end})
local rates={}
rf.OnServerInvoke=function(p,payload)
 if p.Parent~=Players or Players:GetPlayerByUserId(p.UserId)~=p or type(payload)~='table'then return {ok=false,state='idle',code='invalid'}end
 if payload.action=='cancel'then return b:cancel(p)end
 local at=os.clock();if at-(rates[p.UserId]or -10)<1 then return {ok=false,code='busy',state=b.active[p.UserId]and'waiting'or'idle'}end;rates[p.UserId]=at
 if payload.action=='join'then return b:join(p,payload.mode)end
 local e=b.active[p.UserId];return {ok=true,state=e and(e.ownedTeleport and'matched'or'waiting')or'idle',mode=e and e.mode}
end
Players.PlayerRemoving:Connect(function(p)b:remove(p);rates[p.UserId]=nil end)
Teleport.TeleportInitFailed:Connect(function(p,_,_,place)if place==MATCH then b:failed(p)end end)
task.spawn(function()while true do b:watchdog();task.wait(1)end end)
local cycling=false
task.spawn(function()while true do
 if not cycling and(next(b.active)or #b.retired>0)then cycling=true;task.spawn(function()pcall(function()b:cycle()end);cycling=false end)end
 task.wait(3)
end end)
return Bootstrap
