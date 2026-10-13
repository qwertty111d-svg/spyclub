-- ServerStorage.SpyModules only. No access codes in replicated data.
-- Two ephemeral MemoryStore maps; never a profile store or wallet.
local Reconnect = {}
local TTL = 120
local GRACE = 90
local function member(ids, id)
	for _, value in ipairs(ids or {}) do if value == id then return true end end
	return false
end
function Reconnect.new(sessions, tickets, clock)
	local self = {sessions=sessions, tickets=tickets, clock=clock or os.time}
	return setmetatable(self, {__index=Reconnect})
end
function Reconnect:_read(map, key)
	local ok, value = pcall(function() return map:GetAsync(tostring(key)) end)
	if ok and type(value) == "table" then return value end
	return nil
end
function Reconnect:_update(map, key, callback, ttl)
	local ok, result = pcall(function() return map:UpdateAsync(tostring(key), callback, ttl or TTL) end)
	return ok and result ~= nil, result
end
function Reconnect:prepare(data, placeId, code, privateId)
	if type(data) ~= "table" or type(data.sessionId) ~= "string" or type(code) ~= "string"
		or code == "" or type(privateId) ~= "string" or privateId == "" then return false end
	local record = {data=data, placeId=placeId, code=code, privateId=privateId,
		state="pending", heartbeat=self.clock(), expiresAt=self.clock()+TTL}
	local ok = pcall(function()
		self.sessions:SetAsync(data.sessionId, record, TTL)
		for _, id in ipairs(data.memberIds) do
			self.tickets:SetAsync(tostring(id), {sessionId=data.sessionId, state="pending", expiresAt=self.clock()+TTL}, TTL)
		end
	end)
	if not ok then self:close(data.sessionId) end
	return ok
end
function Reconnect:admit(id, sessionId, privateId, jobId)
	local ticket = self:_read(self.tickets, id)
	local record = self:_read(self.sessions, sessionId)
	local now = self.clock()
	if not ticket or ticket.sessionId ~= sessionId or not record or record.state == "closed"
		or record.privateId ~= privateId or not member(record.data.memberIds,id)
		or ticket.expiresAt <= now or record.expiresAt <= now then return nil end
	if record.jobId and record.jobId ~= jobId then return nil end
	if record.state == "live" and (ticket.state ~= "disconnected" or now-record.heartbeat > 40) then return nil end
	if record.state == "pending" and ticket.state ~= "pending" then return nil end
	local claimed = self:_update(self.sessions, sessionId, function(old)
		if not old or old.state == "closed" or (old.jobId and old.jobId ~= jobId) then return nil end
		old.jobId = jobId
		old.heartbeat = now
		old.expiresAt = now+TTL
		return old
	end)
	if not claimed then return nil end
	local accepted = self:_update(self.tickets, id, function(old)
		if not old or old.sessionId ~= sessionId or old.expiresAt <= now
			or (old.state ~= "pending" and old.state ~= "disconnected") then return nil end
		old.state = "connected"
		old.expiresAt = now+TTL
		return old
	end)
	if accepted then return record.data end
	return nil
end
function Reconnect:markLive(sessionId, jobId, ids)
	return self:_update(self.sessions, sessionId, function(old)
		if not old or old.state ~= "pending" or old.jobId ~= jobId then return nil end
		old.state = "live"
		old.liveIds = ids
		old.heartbeat = self.clock()
		old.expiresAt = self.clock()+TTL
		return old
	end)
end
function Reconnect:heartbeat(sessionId, jobId)
	return self:_update(self.sessions, sessionId, function(old)
		if not old or old.state == "closed" or old.jobId ~= jobId then return nil end
		old.heartbeat = self.clock()
		old.expiresAt = self.clock()+TTL
		return old
	end)
end
function Reconnect:disconnect(id, sessionId, jobId)
	local record = self:_read(self.sessions, sessionId)
	if not record or record.state ~= "live" or record.jobId ~= jobId or not member(record.liveIds,id) then return false end
	-- Connected tickets may have expired during a long match. Membership in the
	-- exact live server, not a client-supplied ticket, authorizes their renewal.
	return self:_update(self.tickets, id, function(old)
		if old and old.sessionId ~= sessionId then return nil end
		if old and old.state == "disconnected" then return old end
		if old and old.state == "cleared" then return nil end
		return {sessionId=sessionId,state="disconnected",expiresAt=self.clock()+GRACE}
	end, GRACE)
end
function Reconnect:offer(id)
	local ticket = self:_read(self.tickets,id)
	if not ticket or ticket.state ~= "disconnected" or ticket.expiresAt <= self.clock() then return nil end
	local record = self:_read(self.sessions,ticket.sessionId)
	if not record or record.state ~= "live" or record.expiresAt <= self.clock()
		or self.clock()-record.heartbeat > 40 or not member(record.liveIds,id) then return nil end
	-- Server-only result. Lobby sends only available / expiresAt to clients.
	return {code=record.code, placeId=record.placeId, data=record.data, expiresAt=ticket.expiresAt}
end
function Reconnect:clearUser(id, sessionId)
	return self:_update(self.tickets,id,function(old)
		if not old or (sessionId and old.sessionId ~= sessionId) then return nil end
		return {sessionId=old.sessionId, state="cleared", expiresAt=self.clock()+TTL}
	end)
end
function Reconnect:close(sessionId, jobId)
	local ok, record = self:_update(self.sessions,sessionId,function(old)
		if not old or (jobId and old.jobId ~= jobId) then return nil end
		old.state = "closed"
		old.expiresAt = self.clock()+TTL
		return old
	end)
	if ok then
		for _, id in ipairs(record.data.memberIds) do self:clearUser(id,sessionId) end
	end
	return ok
end
local singleton
function Reconnect.default()
	if not singleton then
        if game:GetService("RunService"):IsStudio() then
            singleton=Reconnect.new(nil,nil)
        else
            local ok,value=pcall(function()
                local memory=game:GetService("MemoryStoreService")
                return Reconnect.new(memory:GetHashMap("SpyClubReconnectSessionsV21"),memory:GetHashMap("SpyClubReconnectUsersV21"))
            end)
            if not ok then
                warn("SpyClub: reconnect storage unavailable: "..tostring(value))
                -- No admission without a trusted session. A later default() can retry.
                return Reconnect.new(nil,nil)
            end
            singleton=value
        end
	end
	return singleton
end

function Reconnect.ballotFacts(spyId, result, votes, order)
	local facts = {firstCorrect=nil,survived={}}
	if result.caught == true then
		for _, id in ipairs(order) do
			if votes[id] == spyId then facts.firstCorrect = id break end
		end
	end
	for id, count in pairs(result.counts or {}) do
		if count > 0 and id ~= result.accusedId then facts.survived[id] = true end
	end
	return facts
end
function Reconnect.newParticipation(ids)
	local state = {members={},startingCount=0}
	for _, id in ipairs(ids) do
		if not state.members[id] then
			if type(id) == "number" and id > 0 and id % 1 == 0 then state.startingCount += 1 end
			state.members[id] = {misses=0,hint=false,vote=false,forfeit=false}
		end
	end
	function state:respond(id, kind)
		local person = self.members[id]
		if not person or person.forfeit then return end
		person.misses = 0
		if kind == "hint" then person.hint = true elseif kind == "vote" then person.vote = true end
	end
	function state:miss(id)
		local person = self.members[id]
		if not person then return false end
		person.misses += 1
		if person.misses >= 2 then person.forfeit = true end
		return person.forfeit
	end
	function state:forfeit(id)
		if self.members[id] then self.members[id].forfeit = true end
	end
	function state:eligible(id)
		local person = self.members[id]
		return self.startingCount >= 3 and person ~= nil and not person.forfeit 
	end
	return state
end
-- Server-only recovery ledger inside the EXISTING ephemeral reconnect maps.
-- Profiles remains the sole authority for stats/coins; operation IDs prevent double awards.
local REWARD_TTL=86400
function Reconnect:stageReward(userId,sessionId,jobId,operationId,command)
 local session=self:_read(self.sessions,sessionId)
 if not session or session.jobId~=jobId or not member(session.data.memberIds,userId)
  or type(command)~="table" or command.kind~="reward" or command.participated~=true then return false end
 local recordKey="pendingReward:"..operationId
 local stored=self:_update(self.sessions,recordKey,function(old)
  if old then
   if old.userId~=userId or old.operationId~=operationId then return nil end
   return old
  end
  return {userId=userId,operationId=operationId,command=command,expiresAt=self.clock()+REWARD_TTL}
 end,REWARD_TTL)
 if not stored then return false end
 return self:_update(self.tickets,"pendingRewards:"..userId,function(old)
  local entries=type(old)=="table" and old.entries or {}
  if type(entries)~="table" then entries={} end
  local nextEntries={}
  local found=false
  for _,entry in ipairs(entries) do
   if entry.expiresAt>self.clock() then
    table.insert(nextEntries,entry)
    if entry.key==recordKey then found=true end
   end
  end
  if not found then table.insert(nextEntries,{key=recordKey,expiresAt=self.clock()+REWARD_TTL}) end
  return {entries=nextEntries}
 end,REWARD_TTL)
end
function Reconnect:pendingRewards(userId)
 local index=self:_read(self.tickets,"pendingRewards:"..userId)
 local results={}
 for _,entry in ipairs(index and index.entries or {}) do
  if type(entry)=="table" and type(entry.key)=="string" and entry.expiresAt>self.clock() then
   local record=self:_read(self.sessions,entry.key)
   if record and record.userId==userId and type(record.operationId)=="string"
    and record.expiresAt>self.clock() and type(record.command)=="table" and record.command.kind=="reward" then
    table.insert(results,{key=entry.key,operationId=record.operationId,command=record.command})
   end
  end
 end
 return results
end
function Reconnect:ackReward(userId,operationId)
 local key="pendingReward:"..operationId
 return self:_update(self.tickets,"pendingRewards:"..userId,function(old)
  if type(old)~="table" or type(old.entries)~="table" then return nil end
  local kept={}
  for _,entry in ipairs(old.entries) do if entry.key~=key and entry.expiresAt>self.clock() then table.insert(kept,entry) end end
  return {entries=kept}
 end,REWARD_TTL)
end

return Reconnect
