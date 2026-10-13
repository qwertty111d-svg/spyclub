-- Pure trade rules. No services, random rolls or yielding callbacks.
local Rules = {}
local function copy(v)
 if type(v)~="table" then return v end
 local n={} for k,x in pairs(v) do n[k]=copy(x) end return n
end
function Rules.info(id,catalog)
 local item=type(id)=="string" and catalog.ById[id]
 if not item or item.tradeable~=true or item.premium or item.dailyOnly or item.setReward or item.achievementOnly or item.uniqueReward or item.noSell or item.kind=="gadget" or item.rarity=="starter" then
  return {tradeable=false,code="protected_item"}
 end
 return {tradeable=true,code="ok"}
end
local function list(ids)
 if type(ids)~="table" then return nil end
 local n=0;for k in pairs(ids) do if type(k)~="number" or k%1~=0 or k<1 or k>4 then return nil end;n+=1 end
 if n>4 or #ids~=n then return nil end
 local seen,clean={},{}
 for i=1,n do
  local id=ids[i]
  if type(id)~="string" or #id>64 or not id:match("^[%w_%-]+$") or seen[id] then return nil end
  seen[id]=true;table.insert(clean,id)
 end
 table.sort(clean);return clean
end
function Rules.count(profile,id)
 local count=profile.itemCounts and profile.itemCounts[id]
 return count~=nil and count or profile.owned and profile.owned[id]==true and 1 or 0
end
function Rules.offer(profile,ids,recipient,catalog)
 local clean=list(ids)
 if not clean then return nil,"invalid_offer" end
 if type(profile)~="table" or type(profile.owned)~="table" then return nil,"profile_unavailable" end
 for _,id in ipairs(clean) do
  if not Rules.info(id,catalog).tradeable then return nil,"protected_item" end
  if Rules.count(profile,id)<1 then return nil,"not_owned" end
 end
 return clean,"ok"
end
function Rules.valid(record)
 if type(record)~="table" or type(record.id)~="string" or #record.id>40 or not record.id:match("^[%w%-]+$") then return false end
 for _,id in ipairs({record.a,record.b}) do
  if type(id)~="number" or id~=id or id%1~=0 or id==0 or math.abs(id)>1e15 then return false end
 end
 if record.a==record.b or type(record.offers)~="table" then return false end
 local a,b=list(record.offers[tostring(record.a)]),list(record.offers[tostring(record.b)])
 return a~=nil and b~=nil and #a+#b>0 and type(record.createdAt)=="number" and type(record.leaseUntil)=="number"
end
local function sides(record,userId)
 if userId~=record.a and userId~=record.b then return nil end
 local other=userId==record.a and record.b or record.a
 return record.offers[tostring(userId)],record.offers[tostring(other)],other
end
local function equal(a,b)
 if type(a)~="table" or type(b)~="table" or #a~=#b then return false end
 for i,v in ipairs(a) do if b[i]~=v then return false end end;return true
end
function Rules.reserve(p,record,userId,catalog)
 if not Rules.valid(record) then return false,"invalid_trade" end
 local outgoing,incoming,other=sides(record,userId)
 if not outgoing then return false,"denied" end
 if p.pendingTrade then
  local pending=p.pendingTrade
  if pending.id==record.id and equal(pending.outgoing,outgoing) and equal(pending.incoming,incoming) then return true,"reserved" end
  return false,"trade_processing"
 end
 local clean,code=Rules.offer(p,outgoing,nil,catalog)
 if not clean then return false,code end
 for _,id in ipairs(incoming) do
  if not Rules.info(id,catalog).tradeable then return false,"protected_item" end
  if Rules.count(p,id)>=1000000000 and not table.find(outgoing,id) then return false,"inventory_full" end
 end
 local seq=math.max(p.tradeSequence or 0,p.tradeFinalizedSequence or 0)+1
 p.tradeSequence=seq
 p.pendingTrade={id=record.id,sequence=seq,outgoing=copy(outgoing),incoming=copy(incoming),other=other,applied=false}
 return true,"reserved"
end
function Rules.apply(p,record,userId,catalog)
 if not Rules.valid(record) or (record.phase~="committed" and record.phase~="complete") then return false,"undecided" end
 local outgoing,incoming=sides(record,userId)
 if not outgoing then return false,"denied" end
 local seq=record.sequences and record.sequences[tostring(userId)]
 if type(seq)~="number" then return false,"invalid_trade" end
 if (p.tradeFinalizedSequence or 0)>=seq then return true,"already_applied" end
 local pending=p.pendingTrade
 if not pending or pending.id~=record.id or pending.sequence~=seq or not equal(pending.outgoing,outgoing) or not equal(pending.incoming,incoming) then return false,"reservation_missing" end
 if pending.applied then return true,"already_applied" end
 for _,id in ipairs(outgoing) do if Rules.count(p,id)<1 then return false,"not_owned" end end
 -- Compute net copies before updating owned/equipped: swapping identical items
 -- keeps an equipped copy, and recovery never applies these deltas twice.
 local counts={}
 for _,id in ipairs(outgoing) do counts[id]=Rules.count(p,id)-1 end
 for _,id in ipairs(incoming) do counts[id]=(counts[id] or Rules.count(p,id))+1 end
 for _,count in pairs(counts) do if count>1000000000 then return false,"inventory_full" end end
 p.itemCounts=p.itemCounts or {}
 for id,count in pairs(counts) do
  p.itemCounts[id]=count>0 and count or nil
  p.owned[id]=count>0 and true or nil
  if count==0 then
   for slot,equipped in pairs(p.equipped) do
    if equipped==id then p.equipped[slot]=slot=="card" and "classic" or slot=="effect" and "soft" or "" end
   end
  end
 end
 pending.applied=true
 p.tradeHistory=p.tradeHistory or {}
 table.insert(p.tradeHistory,1,{id=record.id,other=pending.other,gave=copy(outgoing),received=copy(incoming),at=record.createdAt})
 while #p.tradeHistory>20 do table.remove(p.tradeHistory) end
 return true,"applied"
end
function Rules.release(p,record,userId)
 if record.phase~="complete" and record.phase~="aborted" then return false,"undecided" end
 local pending=p.pendingTrade
 if not pending then return true,"released" end
 if pending.id~=record.id then return true,"released" end
 if record.phase=="complete" and not pending.applied then return false,"not_applied" end
 if record.phase=="aborted" and pending.applied then return false,"decision_conflict" end
 p.tradeFinalizedSequence=math.max(p.tradeFinalizedSequence or 0,pending.sequence)
 p.pendingTrade=nil;return true,"released"
end
return Rules
