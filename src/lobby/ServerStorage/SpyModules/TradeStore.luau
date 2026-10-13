-- Two-profile journal in the EXISTING profile store. Decisions are monotonic.
local Rules=require(game:GetService("ReplicatedStorage").SpyShared.TradeRules)
local Store={};Store.__index=Store
function Store.new(profiles,catalog,onChange)
 return setmetatable({profiles=profiles,catalog=catalog,onChange=onChange or function()end,busy={}},Store)
end
function Store:read(id)
 local ok,value=self.profiles:tradeJournal(id)
 if not ok then return nil,"save_failed" end
 if not Rules.valid(value) then return nil,"journal_unavailable" end
 return value
end
function Store:write(id,fn)
 local ok,value=self.profiles:tradeJournal(id,fn)
 if not ok or not Rules.valid(value) then return nil,"save_failed" end
 return value
end
local function same(a,b)
 if not Rules.valid(a) or a.a~=b.a or a.b~=b.b then return false end
 for _,uid in ipairs({a.a,a.b}) do
  local x,y=a.offers[tostring(uid)],b.offers[tostring(uid)]
  if #x~=#y then return false end;for i,v in ipairs(x) do if y[i]~=v then return false end end
 end
 return true
end
function Store:updateProfile(uid,record,operation)
 return self.profiles:tradeUpdate(uid,function(p)
  local ok,code=operation(p,record,uid,self.catalog)
  if not ok then return nil,code end
  return p,code
 end)
end
function Store:finish(record)
 for _,uid in ipairs({record.a,record.b}) do
  local ok=self:updateProfile(uid,record,Rules.release)
  if not ok then return record,"save_failed" end
 end
 for _,uid in ipairs({record.a,record.b}) do pcall(self.onChange,uid,record.phase) end
 return record,record.phase
end
function Store:continue(record,canPrepare)
 if record.phase=="complete" or record.phase=="aborted" then return self:finish(record) end
 if record.phase=="preparing" then
  if record.leaseUntil<os.time() then
   local updated,code=self:write(record.id,function(old)
    if old.phase=="preparing" and old.leaseUntil<os.time() then old.phase="aborted";old.reason="preparation_expired" end
    return old
   end)
   if not updated then return record,code end
   record=updated
  elseif not canPrepare or record.owner~=game.JobId then return record,"pending"
  else
   local sequences={}
   for _,uid in ipairs({record.a,record.b}) do
    local ok,p,code=self:updateProfile(uid,record,Rules.reserve)
    if not ok then
     if code~="save_failed" and code~="store_unavailable" and code~="busy" then
      local aborted=self:write(record.id,function(old)
       if old.phase=="preparing" then old.phase="aborted";old.reason=code end;return old
      end)
      if aborted then return self:continue(aborted,false) end
     end
     return record,code or "save_failed"
    end
    sequences[tostring(uid)]=p.pendingTrade.sequence
   end
   local updated,code=self:write(record.id,function(old)
    if old.phase=="preparing" then
     if old.leaseUntil<os.time() then old.phase="aborted";old.reason="preparation_expired"
     else old.sequences=sequences;old.phase="committed" end
    end
    return old
   end)
   if not updated then return record,code end
   record=updated
  end
 end
 if record.phase=="aborted" then return self:finish(record) end
 if record.phase~="committed" then return record,"pending" end
 for _,uid in ipairs({record.a,record.b}) do
  local ok,_,code=self:updateProfile(uid,record,Rules.apply)
  if not ok then return record,code or "save_failed" end
 end
 local completed,code=self:write(record.id,function(old)
  if old.phase=="committed" then old.phase="complete";old.completedAt=os.time() end
  return old
 end)
 if not completed then return record,code end
 return self:finish(completed)
end
function Store:execute(record)
 if not Rules.valid(record) then return nil,"invalid_trade" end
 if self.busy[record.id] then return nil,"busy" end
 self.busy[record.id]=true
 local ok,result,code=xpcall(function()
  local created,reason=self:write(record.id,function(old) return old or record end)
  if not created then return nil,reason end
  if not same(created,record) then return nil,"journal_conflict" end
  return self:continue(created,true)
 end,debug.traceback)
 self.busy[record.id]=nil
 if not ok then warn("SpyClub trade write failed: "..tostring(result));return nil,"save_failed" end
 return result,code
end
function Store:recover(id)
 if self.busy[id] then return nil,"busy" end
 self.busy[id]=true
 local ok,result,code=xpcall(function()
  local record,reason=self:read(id)
  if not record then return nil,reason end
  return self:continue(record,false)
 end,debug.traceback)
 self.busy[id]=nil
 if not ok then warn("SpyClub trade recovery failed: "..tostring(result));return nil,"save_failed" end
 return result,code
end
return Store
