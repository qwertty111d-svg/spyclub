-- Atomic economy mutations. No cached profile is ever written over newer data.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.SpyShared.Catalog)
local Economy = require(script.Parent.Economy)
local Players = game:GetService("Players")
local function copy(value)
    if type(value)~="table" then return value end
    local result={} for key,item in pairs(value) do result[key]=copy(item) end return result
end
local function publishPending(userId,count)
    local player=Players:GetPlayerByUserId(userId)
    if player then player:SetAttribute("SpyProfilePending",count or 0) end
end
local Profiles = {}
Profiles.__index = Profiles
function Profiles.new()
    local self = setmetatable({}, Profiles)
    self.studio = RunService:IsStudio()
    if not self.studio then
        local ok,value=pcall(DataStoreService.GetDataStore,DataStoreService,"SpyClubProfiles_v1")
        if ok then self.store=value end
    end
    self.cache, self.busy, self.pending, self.studioRecords, self.removed = {}, {}, {}, {}, {}
    self.studioFeedback = {}
    self.studioTrades = {}
    self.generations={}
    return self
end
function Profiles:public(userId)
    local result = Economy.public(self.cache[userId])
    result.studio = self.studio
    return result
end
-- Owner-only DTO. Never part of Economy.public or table/player broadcasts.
function Profiles:phone(userId)
 local profile=self.cache[userId]
 if not profile then return {ready=false,studio=self.studio} end
 local value=profile.phone or {}
 return {ready=true,studio=self.studio,note=value.note or "",noteRevision=value.noteRevision or 0,noteSavedAt=value.noteSavedAt or 0}
end
function Profiles:history(userId)
    return Economy.public(self.cache[userId],true).history or {}
end
function Profiles:load(userId)
    self.generations[userId]=(self.generations[userId] or 0)+1
    local generation=self.generations[userId]
    self.removed[userId] = nil
    local ok, value
    if self.studio then
        value = self.studioRecords[userId] or Economy.new(Catalog)
        self.studioRecords[userId], ok = value, true
    else
        if not self.store then
            local created,value=pcall(DataStoreService.GetDataStore,DataStoreService,"SpyClubProfiles_v1")
            if not created then return false end
            self.store=value
        end
        for attempt = 1, 3 do
            ok, value = pcall(function()
                return self.store:UpdateAsync("User_" .. userId, function(old)
                    if old == nil then return Economy.new(Catalog) end
                    if not Economy.validate(old) then error("Unsupported player profile; do not overwrite") end
                    return Economy.migrate(old,Catalog)
                end)
            end)
            if ok then break end
            if attempt < 3 then task.wait(2 ^ (attempt-1) + math.random()) end
        end
    end
    if ok and Economy.validate(value) and not self.removed[userId] and self.generations[userId]==generation then
        if not self.cache[userId] or (value.revision or 0)>=(self.cache[userId].revision or 0) then self.cache[userId]=value end
        if value.pendingTrade and self.onTradePending then task.spawn(self.onTradePending,userId,value.pendingTrade.id) end
        return true
    end
    return false
end
function Profiles:transact(userId, operationId, command)
    -- Serialize this player's requests, including retries with uncertain outcomes.
    self.pending[userId] = (self.pending[userId] or 0) + 1
    publishPending(userId,self.pending[userId])
    while self.busy[userId] do task.wait(0.05) end
    if not self.cache[userId] then
        self.pending[userId] = self.pending[userId] - 1
        if self.pending[userId] == 0 then self.pending[userId] = nil end
    publishPending(userId,self.pending[userId])
        return {ok=false, code="profile_unavailable"}
    end
    self.busy[userId] = true
    local ok, saved
    if self.studio then
        ok, saved = pcall(function()
            -- Match production rollback semantics if a command throws after a
            -- local mutation. Never expose a half-applied Studio transaction.
            local profile = copy(self.studioRecords[userId])
            Economy.transaction(profile, operationId, command, Catalog)
            self.studioRecords[userId]=profile
            return profile
        end)
    else
        for attempt = 1, 3 do
            ok, saved = pcall(function()
                return self.store:UpdateAsync("User_" .. userId, function(old)
                    if not Economy.validate(old) then error("Profile missing or invalid; transaction cancelled") end
                    old=Economy.migrate(old,Catalog)
                    -- command.roll was drawn ONCE before this callback. It never rerolls on retry.
                    local updated = Economy.transaction(old, operationId, command, Catalog)
                    return updated
                end)
            end)
            if ok and saved and (saved.receipts[operationId] or Economy.isTradeLocked(saved,command)) then break end
            ok = false
            if attempt < 3 then task.wait(2 ^ (attempt-1) + math.random()) end
        end
    end
    local receipt = {ok=false, code="save_failed"}
    if ok and saved and (saved.receipts[operationId] or Economy.isTradeLocked(saved,command)) then
        receipt = saved.receipts[operationId] or {ok=false,code="trade_processing"}
        if not self.removed[userId] and (not self.cache[userId] or (saved.revision or 0)>=(self.cache[userId].revision or 0)) then self.cache[userId] = saved end
    elseif not self.studio then
        -- An unknown write outcome must not leave an apparently usable stale balance.
        self.cache[userId] = nil
    end
    self.busy[userId] = nil
    self.pending[userId] = self.pending[userId] - 1
    if self.pending[userId] == 0 then self.pending[userId] = nil end
    publishPending(userId,self.pending[userId])
    return receipt
end
-- Used only by server-owned TradeStore, including offline recovery.
function Profiles:tradeJournal(id,transform)
 if type(id)~="string" or #id>40 or not id:match("^[%w%-]+$") then return false,nil end
 local key="Trade_"..id
 if self.studio then
  if transform then
   local value=transform(self.studioTrades[id]);if value~=nil then self.studioTrades[id]=value end
   return true,value
  end
  return true,self.studioTrades[id]
 end
 if not self.store then return false,nil end
 return pcall(function()
  if transform then return self.store:UpdateAsync(key,transform) end
  return self.store:GetAsync(key)
 end)
end
function Profiles:tradeUpdate(userId,transform)
 if not self.studio and not self.store then return false,nil,"store_unavailable" end
 local deadline=os.clock()+10
 while self.busy[userId] and os.clock()<deadline do task.wait(.05) end
 if self.busy[userId] then return false,nil,"busy" end
 self.pending[userId]=(self.pending[userId] or 0)+1;publishPending(userId,self.pending[userId]);self.busy[userId]=true
 local resultCode="save_failed"
 local function update(old)
  if not Economy.validate(old) then resultCode="profile_unavailable";return nil end
  old=Economy.migrate(old,Catalog)
  local value,code=transform(old);resultCode=code or "save_failed"
  if not value then return nil end
  value.revision=(value.revision or 0)+1;return value
 end
 local ok,saved=pcall(function()
  if self.studio then
   local value=update(self.studioRecords[userId]);if value then self.studioRecords[userId]=value end;return value
  end
  return self.store:UpdateAsync("User_"..userId,update)
 end)
 if ok and saved then
  if not self.removed[userId] and (not self.cache[userId] or (saved.revision or 0)>=(self.cache[userId].revision or 0)) then self.cache[userId]=saved end
 elseif not ok then
  resultCode="save_failed";self.cache[userId]=nil
 end
 self.busy[userId]=nil;self.pending[userId]-=1;if self.pending[userId]==0 then self.pending[userId]=nil end
 publishPending(userId,self.pending[userId])
 return ok and saved~=nil,saved,resultCode
end
-- Private developer inbox stored in the EXISTING SpyClubProfiles_v1 DataStore.
-- Entries are grouped by UTC date, which keeps writes bounded and makes export
-- possible without adding another store or changing the player economy schema.
local function feedbackDay(offset)
    return os.date("!%Y%m%d",os.time()-offset*86400)
end
local function containsReceipt(list,id)
    if type(list)~="table" then return false end
    for _,entry in ipairs(list) do if type(entry)=="table" and entry.id==id then return true end end
    return false
end
function Profiles:submitFeedback(userId,category,filteredText,requestId)
    requestId=requestId or (feedbackDay(0)..":"..game:GetService("HttpService"):GenerateGUID(false))
    local day=requestId:match("^(%d%d%d%d%d%d%d%d):[%w%-]+$")
    if not day or (day~=feedbackDay(0) and day~=feedbackDay(1)) then return false,"expired_request" end
    local author=Players:GetPlayerByUserId(userId)
    local entry={id=tostring(userId)..":"..requestId,userId=userId,category=category,text=filteredText,filterVersion="broadcast_v1",
        createdAt=os.time(),status="open",username=author and author.Name or "",displayName=author and author.DisplayName or "",
        placeId=game.PlaceId,jobId=game.JobId}
    local function append(old)
        if old~=nil and type(old)~="table" then error("Unsupported feedback inbox") end
        local list=old or {}
        if containsReceipt(list,entry.id) then return list end
        -- Never silently discard an already accepted letter to make space.
        if #list>=1000 then return nil end
        table.insert(list,entry)
        return list
    end
    if self.studio then
        local saved=append(self.studioFeedback[day])
        if not saved then return false,"inbox_full" end
        self.studioFeedback[day]=saved
        return true,entry.id
    end
    if not self.store then return false,"store_unavailable" end
    for attempt=1,3 do
        local ok,saved=pcall(function() return self.store:UpdateAsync("Feedback_"..day,append) end)
        if ok then return containsReceipt(saved,entry.id),containsReceipt(saved,entry.id) and entry.id or "inbox_full" end
        if attempt<3 then task.wait(attempt) end
    end
    return false,"save_failed"
end
function Profiles:feedbackPage(offset,page)
    if type(offset)~="number" or offset%1~=0 or offset<0 or offset>365 or type(page)~="number" or page%1~=0 or page<1 or page>50 then return false,"bad_request" end
    local day=feedbackDay(offset)
    local list
    if self.studio then list=self.studioFeedback[day] or {}
    elseif self.store then
        local ok,value=pcall(function() return self.store:GetAsync("Feedback_"..day) end)
        if not ok then return false,"read_failed" end
        if value~=nil and type(value)~="table" then return false,"unsupported_inbox" end
        list=value or {}
    else return false,"store_unavailable" end
    local ordered={}
    for _,entry in ipairs(list) do
        if type(entry)=="table" and type(entry.id)=="string" and type(entry.text)=="string" then table.insert(ordered,table.clone(entry)) end
    end
    table.sort(ordered,function(a,b)
        if (a.createdAt or 0)==(b.createdAt or 0) then return a.id>b.id end
        return (a.createdAt or 0)>(b.createdAt or 0)
    end)
    local pages=math.max(1,math.ceil(#ordered/20));page=math.min(page,pages)
    local entries={}
    for i=(page-1)*20+1,math.min(#ordered,page*20) do table.insert(entries,ordered[i]) end
    return true,{day=day,dayOffset=offset,page=page,pages=pages,total=#ordered,entries=entries,studio=self.studio}
end
function Profiles:reviewFeedback(offset,id,reviewerId)
    if type(offset)~="number" or offset%1~=0 or offset<0 or offset>365 or type(id)~="string" or #id>100 then return false,"bad_request" end
    local day=feedbackDay(offset)
    local function mark(old)
        if type(old)~="table" then return nil end
        for _,entry in ipairs(old) do
            if entry.id==id then entry.status="reviewed";entry.reviewedAt=os.time();entry.reviewedBy=reviewerId;return old end
        end
        return nil
    end
    if self.studio then
        local saved=mark(self.studioFeedback[day]);return saved~=nil,saved and "ok" or "not_found"
    end
    if not self.store then return false,"store_unavailable" end
    local ok,saved=pcall(function() return self.store:UpdateAsync("Feedback_"..day,mark) end)
    return ok and containsReceipt(saved,id),ok and "not_found" or "save_failed"
end
function Profiles:remove(userId)
    -- In-flight transactions still finish durably. There is no stale leave-time save.
    self.removed[userId] = true
    local generation=self.generations[userId]
    task.spawn(function()
        while self.pending[userId] do task.wait(0.05) end
        if self.generations[userId]==generation and self.removed[userId] then self.cache[userId] = nil end
    end)
end
function Profiles:flush(timeout)
    local endAt = os.clock() + timeout
    while next(self.pending) and os.clock() < endAt do task.wait(0.1) end
end
return Profiles
