-- Verify the existing pass in this server; teleport/client attributes grant nothing.
local Marketplace=game:GetService("MarketplaceService")
local PolicyService=game:GetService("PolicyService")
local Players=game:GetService("Players")
local Config=require(script.Parent.MonetizationConfig)
local Service={}
Service.__index=Service

function Service.eligible(owns,policy)
    return owns==true and type(policy)=="table" and policy.ArePaidRandomItemsRestricted==false
end
local function validPassId(value)
    return type(value)=="number" and value==value and value>0 and value<math.huge and value%1==0
end
function Service.new(options)
    options=options or {}
    local self=setmetatable({passId=options.passId or Config.RollLuckPassId,onChanged=options.onChanged,
        records={},connections={},destroyed=false},Service)
    table.insert(self.connections,Players.PlayerRemoving:Connect(function(player)self:remove(player)end))
    table.insert(self.connections,Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,passId,purchased)
        if passId==self.passId and purchased==true then self:refresh(player)end
    end))
    return self
end
function Service:_current(entry)
    return not self.destroyed and entry.player.Parent==Players and self.records[entry.player.UserId]==entry
end
function Service:_entry(player)
    if self.destroyed or not player or player.Parent~=Players or not validPassId(self.passId)then return nil end
    local entry=self.records[player.UserId]
    if not entry or entry.player~=player then
        entry={player=player,eligible=false,known=false,busy=false,failures=0,retryAt=0,attempt=0}
        self.records[player.UserId]=entry
    end
    return entry
end
function Service:_setEligible(entry,value)
    local changed=entry.eligible~=value
    entry.eligible=value
    if changed and self.onChanged and self:_current(entry)then
        local ok,err=pcall(self.onChanged,entry.player)
        if not ok then warn("SpyClub verified Roll luck callback: "..tostring(err))end
    end
end
function Service:_start(entry,force)
    if not self:_current(entry)then return end
    if force then entry.known=false;entry.failures=0;entry.retryAt=0 end
    if entry.busy then
        if force then entry.refreshRequested=true;self:_setEligible(entry,false)end
        return
    end
    if not force and (entry.known or os.clock()<entry.retryAt)then return end
    entry.busy=true
    entry.attempt+=1
    local attempt=entry.attempt
    -- Publish conservatively before refreshing a previously verified grant.
    if force then self:_setEligible(entry,false)end
    task.spawn(function()
        if not self:_current(entry)then return end
        local ownsOK,owns=pcall(Marketplace.UserOwnsGamePassAsync,Marketplace,entry.player.UserId,self.passId)
        if not self:_current(entry)then return end
        local policyOK,policy=pcall(PolicyService.GetPolicyInfoForPlayerAsync,PolicyService,entry.player)
        if not self:_current(entry)then return end
        entry.busy=false
        -- An official purchase can complete while an older lookup is yielding.
        if entry.refreshRequested then
            entry.refreshRequested=false
            self:_start(entry,true)
            return
        end
        local verified=ownsOK and type(owns)=="boolean" and policyOK and type(policy)=="table"
            and type(policy.ArePaidRandomItemsRestricted)=="boolean"
        entry.known=verified
        if verified then
            entry.failures=0;entry.retryAt=0
            self:_setEligible(entry,Service.eligible(owns,policy))
        else
            self:_setEligible(entry,false)
            entry.failures=math.min(entry.failures+1,8)
            local backoff=math.min(30,2^(entry.failures-1))
            entry.retryAt=os.clock()+backoff
            task.delay(backoff,function()
                if self:_current(entry) and entry.attempt==attempt then self:_start(entry,false)end
            end)
        end
    end)
end
function Service:has(player)
    local entry=self:_entry(player)
    if not entry then return false end
    self:_start(entry,false)
    return entry.eligible==true
end
function Service:refresh(player)
    local entry=self:_entry(player)
    if entry then self:_start(entry,true)end
end
function Service:remove(playerOrId)
    local id=type(playerOrId)=="number" and playerOrId or playerOrId and playerOrId.UserId
    if id then self.records[id]=nil end
end
function Service:Destroy()
    if self.destroyed then return end
    self.destroyed=true
    for _,connection in ipairs(self.connections)do connection:Disconnect()end
    table.clear(self.connections);table.clear(self.records)
end
return Service
