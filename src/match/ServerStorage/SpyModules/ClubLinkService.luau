-- Optional club directory. Only server-owned public Lobby destinations are joinable.
local Link={};Link.__index=Link
local LOBBY=93859909286393;local MATCH=135927279331761
function Link.new(State)
 local self=setmetatable({State=State,players=game:GetService('Players'),http=game:GetService('HttpService'),teleport=game:GetService('TeleportService'),active={},leases={},nextWrite={},pending={},connections={},cache={},cacheAt=-100,inFlight={},closed=false},Link)
 self.job=game.JobId;self.place=game.PlaceId;self.public=self.place==LOBBY and game.PrivateServerId==''and self.job~=''
 local ok,map=pcall(function()return game:GetService('MemoryStoreService'):GetSortedMap('SpyClubLink_v1')end)
 self.map=ok and map or nil
 local elapsed=0
 self.connections[#self.connections+1]=game:GetService('RunService').Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<25 then return end;elapsed=0
  for p in pairs(self.active)do if not self.pending[p]then
   self.pending[p]=true;task.spawn(function()self:_publish(p);self.pending[p]=nil end)
  end end
 end)
 self.connections[#self.connections+1]=self.teleport.TeleportInitFailed:Connect(function(p,_,_,place,options)
  local flight=self.inFlight[p]
  if flight and place==LOBBY and(options==nil or options==flight.options)then self:_releaseFlight(p,flight)end
 end)
 return self
end
function Link:_now()return workspace:GetServerTimeNow()end
function Link:_current(p)return p and p.Parent==self.players and self.players:GetPlayerByUserId(p.UserId)==p end
function Link:_valid(valid)return not self.closed and(not valid or valid())end
function Link:_contact(p)
 return{userId=p.UserId,displayName=p.DisplayName,number=self.State.number(p.UserId),sameServer=true,joinable=true,placeId=self.place}
end
function Link:_record(p,lease)
 return{protocol=1,userId=p.UserId,displayName=p.DisplayName,number=self.State.number(p.UserId),jobId=self.job,placeId=self.place,joinable=self.public,visible=true,owner=lease.token,started=lease.started,expiresAt=self:_now()+75}
end
function Link:_usable(r)
 return type(r)=='table'and r.protocol==1 and r.visible==true and type(r.userId)=='number'and r.userId>0 and self.State.number(r.userId)==r.number and type(r.expiresAt)=='number'and r.expiresAt>self:_now()and(r.placeId==LOBBY or r.placeId==MATCH)and type(r.displayName)=='string'and #r.displayName<=100 and type(r.jobId)=='string'and #r.jobId<=128
end
function Link:_publish(p,valid)
 local lease=self.leases[p]
 if not self.map or not lease or p.UserId<1 or not self:_current(p)or not self.active[p]or not self:_valid(valid)then return false end
 local record=self:_record(p,lease)
 local ok,value=pcall(function()
  return self.map:UpdateAsync(tostring(p.UserId),function(old)
   if not self:_valid(valid)or not self:_current(p)or self.leases[p]~=lease or not self.active[p]then return nil end
   if type(old)=='table'and type(old.started)=='number'and old.started>lease.started then return nil end
   return record,record.expiresAt
  end,75)
 end)
 if ok and value and value.owner==lease.token then self.nextWrite[p]=self:_now()+25;return true end
 return false
end
function Link:_withdraw(p,lease)
 if not self.map or not lease then return false end
 local ok=pcall(function()
  self.map:UpdateAsync(tostring(p.UserId),function(old)
   if type(old)~='table'or old.owner~=lease.token then return nil end
   local gone=table.clone(old);gone.visible=false;gone.expiresAt=self:_now();return gone,gone.expiresAt
  end,75)
 end)
 return ok
end
function Link:list(p,visible,valid)
 if not self:_current(p)or not self:_valid(valid)then return{ok=false,code='timeout'}end
 local writeOK=true
 if type(visible)=='boolean'then
  if visible and not self.active[p]then self.leases[p]={token=self.http:GenerateGUID(false),started=self:_now()};self.active[p]=true;self.nextWrite[p]=nil end
  if not visible then local lease=self.leases[p];self.active[p]=nil;self.leases[p]=nil;self.nextWrite[p]=nil;writeOK=self:_withdraw(p,lease)end
  p:SetAttribute('SpyClubLinkVisible',visible)
 end
 if self.active[p]and self:_now()>=(self.nextWrite[p]or 0)then writeOK=self:_publish(p,valid)end
 local network=self.map~=nil and writeOK
 if self:_now()-self.cacheAt>=10 then
  local ok,rows=pcall(function()return self.map and self.map:GetRangeAsync(Enum.SortDirection.Descending,30)end)
  network=network and ok and type(rows)=='table'
  if network then self.cache=rows;self.cacheAt=self:_now()else self.cache={}end
 end
 if not self:_valid(valid)then return{ok=false,code='timeout'}end
 local members,seen={},{}
 for _,other in ipairs(self.players:GetPlayers())do
  seen[other.UserId]=true
  if other~=p and self.active[other]then members[#members+1]=self:_contact(other)end
 end
 if network then for _,row in ipairs(self.cache)do local r=row.value
  if self:_usable(r)and r.jobId~=self.job and r.userId~=p.UserId and not seen[r.userId]then
   seen[r.userId]=true;members[#members+1]={userId=r.userId,displayName=r.displayName,number=r.number,sameServer=r.jobId==self.job,joinable=r.joinable==true and r.placeId==LOBBY and r.jobId~='',placeId=r.placeId,started=r.started}
  end
 end end
 table.sort(members,function(a,b)if a.sameServer~=b.sameServer then return a.sameServer end;return a.userId<b.userId end)
 while #members>30 do table.remove(members)end
 return{ok=true,members=members,number=self.State.number(p.UserId),visible=self.active[p]==true,network=network==true}
end
function Link:lookup(id,valid)
 if type(id)~='number'or id%1~=0 or not self.State.number(id)or not self:_valid(valid)then return{ok=false,code='invalid'}end
 local p=self.players:GetPlayerByUserId(id);if self:_current(p)then return{ok=true,contact=self:_contact(p)}end
 local ok,r=pcall(function()return self.map and self.map:GetAsync(tostring(id))end)
 if not self:_valid(valid)then return{ok=false,code='timeout'}end
 if not ok or not self.map then return{ok=false,code='link_offline'}end
 if not self:_usable(r)then return{ok=false,code='left'}end
 if r.jobId==self.job then return{ok=false,code='left'}end
 return{ok=true,contact={userId=r.userId,displayName=r.displayName,number=r.number,sameServer=false,joinable=r.joinable==true and r.placeId==LOBBY and r.jobId~='',placeId=r.placeId},route=r}
end
function Link:_releaseFlight(p,flight)
 if self.inFlight[p]~=flight then return end;self.inFlight[p]=nil
 if p:GetAttribute('SpyClubLinkTeleport')==flight.token then p:SetAttribute('SpyClubLinkTeleport',nil);p:SetAttribute('SpyTeleporting',false)end
end
function Link:connect(p,id,valid)
 if not self:_current(p)or not self:_valid(valid)then return{ok=false,code='timeout'}end
 if id==p.UserId then return{ok=false,code='invalid'}end
 local found=self:lookup(id,valid);if not found.ok then return found end
 if found.contact.sameServer then return{ok=true,contact=found.contact}end
 if not self.public then return{ok=false,code='finish_match'}end
 local r=found.route
 if not r or not found.contact.joinable or r.placeId~=LOBBY or r.jobId==self.job or #r.jobId<5 then return{ok=false,code='private_match'}end
 if not self:_valid(valid)or p:GetAttribute('SpyTeleporting')==true then return{ok=false,code='blocked'}end
 local options=Instance.new('TeleportOptions');options.ServerInstanceId=r.jobId
 options:SetTeleportData({SpyClubLink={target=id,from=p.UserId,at=self:_now()}})
 local flight={token=self.http:GenerateGUID(false),options=options};self.inFlight[p]=flight
 p:SetAttribute('SpyClubLinkTeleport',flight.token);p:SetAttribute('SpyTeleporting',true)
 task.delay(15,function()self:_releaseFlight(p,flight)end)
 local ok=pcall(function()self.teleport:TeleportAsync(LOBBY,{p},options)end)
 if not ok then self:_releaseFlight(p,flight);return{ok=false,code='unavailable'}end
 return{ok=true,teleporting=true}
end
function Link:remove(p)
 local lease=self.leases[p];self.active[p]=nil;self.leases[p]=nil;self.nextWrite[p]=nil
 p:SetAttribute('SpyClubLinkVisible',false);self:_withdraw(p,lease)
 local flight=self.inFlight[p];if flight then self:_releaseFlight(p,flight)end
end
function Link:destroy()
 self.closed=true;for _,c in ipairs(self.connections)do c:Disconnect()end
 for p in pairs(self.leases)do self:remove(p)end
end
return Link
