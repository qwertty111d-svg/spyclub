local assertions=0
local function check(value,message)assertions+=1;assert(value,message)end
local function signal()
    local listeners={}
    return {
        Connect=function(_,callback)
            local record={callback=callback,active=true};table.insert(listeners,record)
            return {Disconnect=function()record.active=false end}
        end,
        Fire=function(_,...)
            for _,record in ipairs(listeners)do if record.active then record.callback(...)end end
        end,
    }
end
local clock=0
local queued,timers={},{}
local taskStub={
    spawn=function(callback)table.insert(queued,callback)end,
    delay=function(seconds,callback)table.insert(timers,{at=clock+seconds,delay=seconds,callback=callback})end,
}
local function flush()
    local steps=0
    while #queued>0 do
        steps+=1;assert(steps<30,"unexpected retry loop")
        local callback=table.remove(queued,1);callback()
    end
end
local function advance(seconds)
    clock+=seconds
    local remaining={}
    for _,timer in ipairs(timers)do
        if timer.at<=clock then table.insert(queued,timer.callback)else table.insert(remaining,timer)end
    end
    timers=remaining;flush()
end
local Players={PlayerRemoving=signal()}
local ownership,policy=true,{ArePaidRandomItemsRestricted=false}
local ownershipFails,policyFails=false,false
local ownCalls,policyCalls=0,0
local requestedPasses={}
local onOwnershipLookup
local Marketplace={PromptGamePassPurchaseFinished=signal()}
function Marketplace:UserOwnsGamePassAsync(userId,passId)
    ownCalls+=1;table.insert(requestedPasses,{userId=userId,passId=passId})
    if onOwnershipLookup then
        local callback=onOwnershipLookup;onOwnershipLookup=nil
        return callback()
    end
    if ownershipFails then error("ownership lookup failed")end
    return ownership
end
local Policy={}
function Policy:GetPolicyInfoForPlayerAsync(_)
    policyCalls+=1
    if policyFails then error("policy lookup failed")end
    return policy
end
local services={Players=Players,MarketplaceService=Marketplace,PolicyService=Policy}
local config=assert(loadstring(configSource,"MonetizationConfig"))()
local chunk=assert(loadstring(serviceSource,"RollLuckService"))
setfenv(chunk,setmetatable({game={GetService=function(_,name)return assert(services[name],name)end},
    script={Parent={MonetizationConfig="config"}},require=function(name)assert(name=="config");return config end,
    task=taskStub,os=setmetatable({clock=function()return clock end},{__index=os}),warn=function()end},
    {__index=getfenv(0)}))
local Service=chunk()
check(type(Service.eligible)=="function","verified ownership and policy determine luck eligibility")
check(Service.eligible(true,{ArePaidRandomItemsRestricted=false}),"owned pass plus explicit unrestricted policy is eligible")
for _,owns in ipairs({false,"true",1})do
    check(not Service.eligible(owns,{ArePaidRandomItemsRestricted=false}),"ownership must be verified boolean true")
end
check(not Service.eligible(nil,{ArePaidRandomItemsRestricted=false}),"unknown ownership denied")
check(not Service.eligible(true,nil),"unknown policy denied")
check(not Service.eligible(true,{}),"missing policy restriction field denied")
check(not Service.eligible(true,{ArePaidRandomItemsRestricted=true}),"restricted policy denied")
check(not Service.eligible(true,{ArePaidRandomItemsRestricted="false"}),"malformed restriction field denied")
check(config.RollLuckPassId==1998344385,"match restores the existing lobby luck pass identifier")
local function player(id)return {UserId=id,Parent=Players,GetAttribute=function()return true end}end
local first=player(101)
local notifications=0
local service
service=Service.new({onChanged=function(changed)
    notifications+=1
    check(changed==first,"callback identifies owner")
    check(service:has(changed),"verified eligibility is cached before notification")
end})
check(not service:has(first),"first snapshot denies unknown entitlement without yielding")
for _=1,5 do check(not service:has(first),"pending lookup remains conservative")end
check(ownCalls==0 and #queued==1,"snapshot schedules only one lookup and never calls yielding APIs")
flush()
check(ownCalls==1 and policyCalls==1,"both official verification services queried once")
check(requestedPasses[1].passId==1998344385 and requestedPasses[1].userId==101,"query targets configured pass and actual user")
check(service:has(first) and notifications==1 and #queued==0,"verified result is cached and published")
for _=1,4 do check(service:has(first),"cached eligibility reused")end
check(ownCalls==1,"cache avoids repeated marketplace queries")
service:Destroy()

local restricted=Service.new({passId=777})
policy={ArePaidRandomItemsRestricted=true}
local second=player(102)
check(not restricted:has(second),"client attributes cannot authorize luck")
flush()
check(not restricted:has(second) and requestedPasses[#requestedPasses].passId==777,"restriction overrides ownership and custom server pass is used")
local beforeRestricted=ownCalls
restricted:has(second);flush()
check(ownCalls==beforeRestricted,"verified restricted result is cached")
restricted:Destroy()

policy={ArePaidRandomItemsRestricted=false};ownershipFails=true
local retry=Service.new({passId=888})
local third=player(103)
local beforeRetry=ownCalls
retry:has(third);flush()
check(not retry:has(third) and ownCalls==beforeRetry+1,"lookup failure denies luck")
check(#timers==1 and timers[1].delay>0,"failure schedules a bounded retry")
local firstBackoff=timers[1].delay
advance(firstBackoff/2)
check(ownCalls==beforeRetry+1,"retry respects backoff")
advance(firstBackoff/2)
check(ownCalls==beforeRetry+2 and #timers==1 and timers[1].delay>firstBackoff,"successive failures increase retry delay")
for _=1,7 do
    local delay=timers[1].delay
    check(delay<=60,"retry backoff has a fixed upper bound")
    advance(delay)
end
ownershipFails=false
advance(timers[1].delay)
check(retry:has(third),"retry recovers verified ownership after transient failure")
retry:Destroy()

ownership=false
local purchaseChanges={}
local purchased
purchased=Service.new({passId=999,onChanged=function(changed)
    table.insert(purchaseChanges,purchased:has(changed))
end})
local fourth=player(104)
purchased:has(fourth);flush()
check(not purchased:has(fourth),"unowned pass stays ineligible")
local beforePurchase=ownCalls
Marketplace.PromptGamePassPurchaseFinished:Fire(fourth,998,true)
Marketplace.PromptGamePassPurchaseFinished:Fire(fourth,999,false)
flush()
check(ownCalls==beforePurchase,"unrelated or cancelled purchase does not invalidate cache")
ownership=true
Marketplace.PromptGamePassPurchaseFinished:Fire(fourth,999,true)
check(not purchased:has(fourth),"matching purchase rechecks ownership rather than trusting the event")
flush()
check(purchased:has(fourth) and ownCalls==beforePurchase+1,"matching purchase refresh restores verified perk")
check(#purchaseChanges==1 and purchaseChanges[1]==true,"verified purchase result publishes eligibility change")
policyFails=true
purchased:refresh(fourth);flush()
check(not purchased:has(fourth),"failed policy refresh revokes cached eligibility")
check(#purchaseChanges==2 and purchaseChanges[2]==false,"revocation publishes conservative eligibility")
policyFails=false
advance(timers[1].delay)
check(purchased:has(fourth),"policy failure recovers through retry")
check(#purchaseChanges==3 and purchaseChanges[3]==true,"recovery publishes verified eligibility")
purchased:Destroy()

-- Purchase completion while a lookup yields must recheck, not cache an old reply.
local racing=Service.new({passId=1111})
local racePlayer=player(107)
local beforeRace=ownCalls
onOwnershipLookup=function()
    Marketplace.PromptGamePassPurchaseFinished:Fire(racePlayer,1111,true)
    return false
end
racing:has(racePlayer);flush()
check(ownCalls==beforeRace+2 and racing:has(racePlayer),"purchase during lookup refreshes once after the stale query")
racing:Destroy()

local removed=Service.new({passId=1000})
local fifth=player(105)
local beforeRemoval=ownCalls
removed:has(fifth)
Players.PlayerRemoving:Fire(fifth);fifth.Parent=nil
flush()
check(ownCalls==beforeRemoval and not removed:has(fifth),"removal cancels queued lookup and denies old player")
local sixth=player(106)
ownershipFails=true
removed:has(sixth);flush()
local pendingTimer=timers[1].delay
local beforeRemovedRetry=ownCalls
Players.PlayerRemoving:Fire(sixth);sixth.Parent=nil
advance(pendingTimer)
check(ownCalls==beforeRemovedRetry,"removal cancels delayed retries")
ownershipFails=false
removed:Destroy()
local beforeDestroy=ownCalls
Marketplace.PromptGamePassPurchaseFinished:Fire(first,1000,true)
flush()
check(ownCalls==beforeDestroy and not removed:has(first),"destroy disconnects purchase listener and clears eligibility")
local invalid=Service.new({passId=0})
check(not invalid:has(first) and #queued==0,"invalid server pass configuration fails closed")
invalid:Destroy()
print("Roll luck verification: "..assertions.." assertions passed (official services stubbed; no Studio Play Test)")
