-- Ephemeral cross-server intent. No profile DataStore and no client access codes.
local Queue={TTL=90,CLAIM=45,GRACE=15};Queue.__index=Queue
local function modeValid(v)return v=='classic'or v=='case'end
local function idValid(id)return type(id)=='number'and id>0 and id%1==0 and id<math.huge end
function Queue.new(rows,control,clock,job,guid)
 return setmetatable({map=rows,control=control,clock=clock or os.time,job=job,guid=guid},Queue)
end
function Queue:_read(map,key)
 local ok,v=pcall(function()return map:GetAsync(tostring(key))end);return v,ok
end
function Queue:_update(map,key,f,ttl)
 local ok,v=pcall(function()return map:UpdateAsync(tostring(key),f,ttl or Queue.TTL)end)
 return ok and v~=nil,v,ok
end
function Queue:rows()
 local ok,v=pcall(function()return self.map:GetRangeAsync(Enum and Enum.SortDirection.Ascending or'Ascending',50)end)
 return ok and v or nil
end
function Queue:join(id,mode,nonce)
 if not idValid(id)or not modeValid(mode)or type(nonce)~='string'or #nonce>80 then return {ok=false,code='invalid'}end
 local now=self.clock()
 local accepted,_,cloud=self:_update(self.map,id,function(old)
  if old and old.expires>now and old.state~='cancelled'then return nil end
  return {id=id,mode=mode,nonce=nonce,job=self.job,state='waiting',joined=now,heartbeat=now,expires=now+Queue.TTL},now
 end)
 return {ok=accepted,code=not cloud and'unavailable'or not accepted and'busy'or nil}
end
function Queue:heartbeat(id,nonce)
 local now=self.clock()
 return self:_update(self.map,id,function(old)
  if not old or old.nonce~=nonce or old.job~=self.job or old.state~='waiting'or old.expires<=now then return nil end
  old.heartbeat=now;old.expires=now+Queue.TTL;return old,old.joined
 end)
end
function Queue:leave(id,nonce)
 local allowedClaim
 for _=1,4 do
  local claim,absent,mismatch
  -- Read and cancel an unclaimed row in the same atomic transform. An earlier
  -- GetAsync('waiting') response cannot authorize cancelling a later ready row.
  local cancelled,_,available=self:_update(self.map,id,function(old)
   claim,absent,mismatch=nil,false,false
   if not old or old.expires<=self.clock()then absent=true;return nil end
   if old.nonce~=nonce or old.job~=self.job then mismatch=true;return nil end
   if old.state=='cancelled'then absent=true;return nil end
   if old.claim and old.claim~=allowedClaim then claim=old.claim;return nil end
   old.state='cancelled';old.expires=self.clock()+Queue.TTL;return old,old.expires
  end)
  if not available then return {ok=false,code='unavailable'}end
  if cancelled or absent then return {ok=true}end
  if mismatch or not claim then return {ok=false,code='busy'}end
  -- Cancellation competes with ready on this exact control key. Never yield
  -- within a transform; recheck the row if it moved into a different claim.
  local gated,_,cloud=self:_update(self.control,'session:'..claim,function(old)
   if old and old.state=='ready'then return nil end
   old=old or{};old.state='cancelled';return old
  end,Queue.CLAIM)
  if not gated then return {ok=false,code=cloud and'matched'or'unavailable'}end
  allowedClaim=claim
 end
 return {ok=false,code='busy'}
end
function Queue:ticket(id,nonce)
 local row,ok=self:_read(self.map,id)
 if not ok or not row or row.job~=self.job or(nonce and row.nonce~=nonce)or row.state~='assigned'or row.expires<=self.clock()then return nil end
 local control,available=self:_read(self.control,'session:'..row.claim)
 if not available or not control or control.state~='ready'then return nil end
 return row.ticket
end
function Queue:drop(id,nonce,ticket)
 return self:_update(self.map,id,function(old)
  if not old or old.job~=self.job or old.nonce~=nonce or old.claim~=ticket.sessionId then return nil end
  old.state='cancelled';old.expires=self.clock()+Queue.TTL;return old,old.expires
 end)
end
function Queue:status(id,known)
 local row,ok=self:_read(self.map,id);if not ok then return {ok=false,code='unavailable',state='unavailable'}end
 if not row or row.expires<=self.clock()or row.state=='cancelled'then return {ok=true,state='idle'}end
 local count=0;local list=known or self:rows()
 for _,x in ipairs(list or{})do local r=x.value;if r.mode==row.mode and r.state=='waiting'and r.expires>self.clock()then count+=1 end end
 local state=row.state=='waiting'and'waiting'or'preparing'
 if row.state=='assigned'and self:ticket(id,row.nonce)then state='matched';count=#row.ticket.data.memberIds end
 return {ok=true,state=state,count=count,mode=row.mode,elapsed=math.max(0,self.clock()-row.joined),canCancel=state=='waiting'or state=='preparing'}
end
function Queue:pump(reserve,reconnect,placeId,lobbyPlaceId)
 local now=self.clock();local leader=self:_update(self.control,'leader',function(old)
  if old and old.untilAt>now then return nil end
  return {job=self.job,untilAt=now+8}
 end,10)
 if not leader then return false end
 local list=self:rows();if not list then return false end
 local groups={classic={},case={}}
 for _,x in ipairs(list)do local r=x.value
  if modeValid(r.mode)and r.state=='waiting'and r.expires>now and now-r.heartbeat<=35 then groups[r.mode][#groups[r.mode]+1]=r end
 end
 local candidates,mode
 for _,m in ipairs({'classic','case'})do local g=groups[m]
  if (#g>=4 or(#g>=3 and now-g[1].joined>=Queue.GRACE))and(not candidates or g[1].joined<candidates[1].joined)then candidates=g;mode=m end
 end
 if not candidates then return false end
 local sessionId=self.guid();local picked={};local prepared=false
 local controlOK=self:_update(self.control,'session:'..sessionId,function()return {state='preparing',deadline=now+Queue.CLAIM}end,Queue.CLAIM)
 if not controlOK then return false end
 local function rollback()
  self:_update(self.control,'session:'..sessionId,function(c)if not c or c.state=='ready'then return nil end;c.state='cancelled';return c end,Queue.CLAIM)
  for _,r in ipairs(picked)do self:_update(self.map,r.id,function(old)
   if not old or old.claim~=sessionId or old.nonce~=r.nonce then return nil end
   if old.state=='cancelled'then return nil end
   old.state='waiting';old.claim=nil;old.ticket=nil;old.expires=self.clock()+Queue.TTL;return old,old.joined
  end)end
  if prepared then pcall(function()reconnect:close(sessionId)end)end
  return false
 end
 for i=1,math.min(4,#candidates)do local r=candidates[i]
  local claimed=self:_update(self.map,r.id,function(old)
   if not old or old.nonce~=r.nonce or old.state~='waiting'or old.expires<=self.clock()then return nil end
   old.state='claimed';old.claim=sessionId;return old,old.joined
  end)
  if not claimed then return rollback()end;picked[#picked+1]=r
 end
 local ok,code,privateId=pcall(reserve,placeId)
 if not ok or type(code)~='string'or code==''or type(privateId)~='string'or privateId==''then return rollback()end
 local ids={};for _,r in ipairs(picked)do ids[#ids+1]=r.id end
 local rules={allowedThemes={'cities','countries','animals','professions','food','games'},topicMode='vote',discussionSeconds=45,hintSeconds=45,hintLaps=1,allowExtraRound=true,mode=mode}
 local data={version=1,partyId=sessionId,partyCode=sessionId:gsub('%W',''):sub(1,5):upper(),sessionId=sessionId,partyName=mode=='case'and'Тайная встреча'or'Spy Club',ownerId=ids[1],memberIds=ids,capacity=#ids,visibility='public',sourcePlaceId=lobbyPlaceId,rules=rules,startedAt=self.clock()}
 local stored,result=pcall(function()return reconnect:prepare(data,placeId,code,privateId)end);prepared=stored and result==true
 if not prepared then return rollback()end
 for _,r in ipairs(picked)do
  local assigned=self:_update(self.map,r.id,function(old)
   if not old or old.nonce~=r.nonce or old.claim~=sessionId or old.state~='claimed'or old.expires<=self.clock()then return nil end
   old.state='assigned';old.expires=self.clock()+Queue.TTL;old.ticket={sessionId=sessionId,placeId=placeId,code=code,privateId=privateId,data=data,nonce=r.nonce};return old,old.expires
  end)
  if not assigned then return rollback()end
 end
 for _,r in ipairs(picked)do local current,available=self:_read(self.map,r.id)
  if not available or not current or current.nonce~=r.nonce or current.claim~=sessionId or current.state~='assigned'then return rollback()end
 end
 local committed,_,available=self:_update(self.control,'session:'..sessionId,function(c)
  if not c or c.state~='preparing'or c.deadline<self.clock()then return nil end
  c.state='ready';return c
 end,Queue.TTL)
 if committed then return true end
 -- A lost response after the final commit is ambiguous. Never revoke a group that may already teleport.
 if not available then local c,readOK=self:_read(self.control,'session:'..sessionId)
  if not readOK then return false end;if c and c.state=='ready'then return true end
 end
 return rollback()
end
return Queue
