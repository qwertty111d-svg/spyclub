-- Client supplies a category and request identifier, never a result or item ID.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("SpyShared")
local HttpService=game:GetService("HttpService")
local Catalog=require(Shared.Catalog)
local Config=require(Shared.AccessoryRollConfig)
local Identity=require(Shared.CharacterIdentity)
local Wardrobe=require(Shared.Wardrobe)
local Rules=require(script.Parent.AccessoryRollRules)
local Service={}
Service.__index=Service
function Service.new(profiles,options)
    return setmetatable({profiles=profiles,options=options or {},random=Random.new(),busy={},last={},snapshots={},loading={},lastLoad={}},Service)
end
local function rendered(item,slot)
    if slot=="outfit" then return Wardrobe.Outfits[item.id]~=nil end
    if slot=="gloves" then return item.id=="agent_gloves" end
    if slot=="shoulder" then return item.id=="shoulder_holster" end
    return Wardrobe.Accessories[item.id]~=nil
end
function Service:locked(player,profile)
    return profile.pendingTrade~=nil or self.options.isTrading and self.options.isTrading(player)==true
end
function Service:pool(player,profile,category,prepare)
    -- Dossier fields need a loaded profile, never a spawned/loaded avatar asset.
    if category.identity then return Rules.pool(Catalog.Items,category,profile,Catalog) end
    local character=player.Character
    if not character or not character:GetAttribute("SpyBaseReady") then return {},{} end
    local deadline=os.clock()+Config.PreparationTimeout
    return Rules.pool(Catalog.Items,category,profile,Catalog,function(item,slot)
        if not rendered(item,slot) then return false end
        local proposed=table.clone(profile.equipped or {})
        proposed[slot]=item.id
        -- No spending before a real, renderable R15 attachment/clothing check.
        local ok,ready=pcall(Wardrobe.prepare,proposed,prepare and math.max(0,deadline-os.clock()) or 0,slot)
        if not ok or not ready or player.Character~=character or not character.Parent then return false end
        local valid,result=pcall(Wardrobe.validate,character,proposed,slot)
        return valid and result==true
    end)
end
function Service:snapshot(player,profile)
    local lucky=self.options.hasLuck and self.options.hasLuck(player)==true or false
    local paidAllowed=self.options.canSpendPaidRolls and self.options.canSpendPaidRolls(player)==true or false
    local paid=profile.paidRolls or 0
    local earned=profile.earnedRolls or math.max(0,(profile.rolls or 0)-paid)
    local canSpend=earned>0 or paid>0 and paidAllowed
    local spendReason=not canSpend and ((profile.rolls or 0)>0 and "roll_paid_restricted" or "roll_empty") or nil
    local result={sequence=profile.rollSequence or 0,categories={},lucky=lucky,
        paidRolls=paid,earnedRolls=earned,paidAllowed=paidAllowed,canSpend=canSpend,spendReason=spendReason,
        identity=profile.ready and Identity.sanitize(profile.identity) or nil}
    if not profile.ready then return result end
    local parts={profile.language or "ru",profile.appearanceStyleGroup or "all",tostring(lucky),tostring(self:locked(player,profile)),tostring(canSpend),tostring(paidAllowed),tostring(spendReason),
        tostring(player.Character and player.Character:GetAttribute("SpyBaseReady"))}
    local identity=Identity.sanitize(profile.identity)
    for _,field in ipairs({"nationality","firstName","lastName"}) do table.insert(parts,identity[field]) end
    for _,category in ipairs(Config.Categories) do table.insert(parts,(profile.equipped or {})[category.slot] or "") end
    local assets=Shared.Parent:FindFirstChild("SpyWardrobeAssets")
    table.insert(parts,tostring(assets and assets:GetAttribute("Revision") or 0))
    local signature=table.concat(parts,"|")
    local cached=self.snapshots[player.UserId]
    if cached and cached.character==player.Character and cached.signature==signature then
        result.categories=cached.categories;return result
    end
    for _,category in ipairs(Config.Categories) do
        local entries,chances=self:pool(player,profile,category,false)
        local items={}
        local adjusted={}
        -- Preserve the paid legacy best-of-two perk and disclose its real odds.
        if lucky and not category.identity then
            local cumulative=0
            for _,rarity in ipairs(Config.RarityOrder) do
                local chance=(chances[rarity] or 0)/100
                if chance>0 then
                    adjusted[rarity]=((cumulative+chance)^2-cumulative^2)*100
                    cumulative+=chance
                end
            end
        else adjusted=chances end
        for _,entry in ipairs(entries) do
            if category.identity then
                table.insert(items,{id=entry.item.id,label=entry.item.label,labelRu=entry.item.labelRu,
                    labelEn=entry.item.labelEn,chance=entry.chance})
            else
                local rarity=entry.item.rarity
                table.insert(items,{id=entry.item.id,rarity=rarity,chance=entry.chance*(adjusted[rarity] or 0)/(chances[rarity] or 1)})
            end
        end
        local locked=self:locked(player,profile)
        table.insert(result.categories,{id=category.id,slot=category.slot,label=profile.language=="en" and category.en or category.ru,
            labelRu=category.ru,labelEn=category.en,available=#entries>0 and not locked,
            canSpend=#entries>0 and not locked and canSpend,
            spendReason=locked and "trade_processing" or #entries==0 and "roll_no_items" or spendReason,
            reason=locked and "trade_processing" or #entries==0 and "roll_no_items" or nil,
            chances=adjusted,items=items,identity=category.identity==true,
            lucky=not category.identity and lucky or false,distribution=category.identity and "uniform" or "rarity",
            styleGroup=not category.identity and Rules.style(profile,category,Catalog) or nil})
    end
    self.snapshots[player.UserId]={character=player.Character,signature=signature,categories=result.categories}
    return result
end
function Service:roll(player,categoryId,requestId)
    local category=Config.ById[categoryId]
    local sequence=Rules.sequence(requestId)
    if not category or not sequence then return {ok=false,code="roll_invalid_request"} end
    local id=player.UserId
    local saved=self.profiles.cache[id]
    if not saved then
        -- An uncertain UpdateAsync result deliberately invalidates the cache.
        -- Reload durable state before retrying the SAME request identifier.
        if self.loading[id] or self.busy[id] or self.profiles.busy[id] or self.profiles.pending[id]
            or os.clock()-(self.lastLoad[id] or -100)<1 then return {ok=false,code="slowDown"} end
        self.loading[id]=true;self.lastLoad[id]=os.clock()
        local loadOK,loaded=pcall(self.profiles.load,self.profiles,id)
        self.loading[id]=nil
        if not loadOK or not loaded then return {ok=false,code="profile_unavailable"} end
        saved=self.profiles.cache[id]
        if not saved then return {ok=false,code="profile_unavailable"} end
    end
    local previous=(saved.rollReceipts or {})[requestId]
    if previous then
        if previous.category~=categoryId then return {ok=false,code="roll_request_conflict"} end
        local receipt=table.clone(previous);receipt.replayed=true;return receipt
    end
    if sequence~=(saved.rollSequence or 0)+1 then return {ok=false,code="roll_stale_request"} end
    -- Recover saved replies before checking whether a new roll is permitted.
    if self.options.canRoll and self.options.canRoll(player)~=true then return {ok=false,code="roll_match_active"} end
    if self:locked(player,saved) then return {ok=false,code="trade_processing"} end
    if self.busy[id] or os.clock()-(self.last[id] or -100)<Config.Cooldown then return {ok=false,code="slowDown"} end
    if (saved.rolls or 0)<1 then return {ok=false,code="roll_empty"} end
    if (saved.rolls or 0)-(saved.paidRollReserve or 0)<1
        and not (self.options.canSpendPaidRolls and self.options.canSpendPaidRolls(player)==true) then
        return {ok=false,code="roll_paid_restricted"}
    end
    self.busy[id]=true;self.last[id]=os.clock()
    local ok,receipt=pcall(function()
        local profile=self.profiles:public(id)
        local character=player.Character
        if not category.identity and (not character or not character:GetAttribute("SpyBaseReady")) then return {ok=false,code="appearanceLoading"} end
        local entries=self:pool(player,profile,category,false)
        if #entries==0 then entries=self:pool(player,profile,category,true) end
        if #entries==0 then return {ok=false,code="roll_no_items"} end
        if not category.identity and (player.Character~=character or not character.Parent) then return {ok=false,code="appearanceLoading"} end
        if self:locked(player,self.profiles.cache[id] or {}) then return {ok=false,code="trade_processing"} end
        -- Preparation may yield while a match begins. Never draw/spend after
        -- that transition; retries still use the saved-receipt path above.
        if self.options.canRoll and self.options.canRoll(player)~=true then return {ok=false,code="roll_match_active"} end
        local paidAllowed=self.options.canSpendPaidRolls and self.options.canSpendPaidRolls(player)==true or false
        local chosen=Rules.select(entries,self.random:NextNumber(0,100))
        if category.identity then
            local current=Identity.sanitize(profile.identity)
            local proposed=Identity.sanitize(current)
            proposed[category.id]=chosen.id
            if category.id=="nationality" then
                proposed.firstName=Rules.select(Identity.pool("firstName",proposed),self.random:NextNumber(0,100)).id
                proposed.lastName=Rules.select(Identity.pool("lastName",proposed),self.random:NextNumber(0,100)).id
            end
            -- Uniform identity choices are independent of cosmetic rarity/luck.
            -- Draw all three fields before any repeatable datastore callback.
            return self.profiles:transact(id,"roll:"..id..":"..categoryId..":"..requestId,{kind="accessoryRoll",category=categoryId,
                requestId=requestId,sequence=sequence,prepared=true,sourceNationality=current.nationality,identity=proposed,paidRandomAllowed=paidAllowed})
        end
        local lucky=self.options.hasLuck and self.options.hasLuck(player)==true or false
        if lucky then
            local second=Rules.select(entries,self.random:NextNumber(0,100))
            if Catalog.Rarities[second.rarity].rank>Catalog.Rarities[chosen.rarity].rank then chosen=second end
        end
        -- The immutable command is drawn ONCE before UpdateAsync retries.
        return self.profiles:transact(id,"roll:"..id..":"..categoryId..":"..requestId,{kind="accessoryRoll",category=categoryId,
            requestId=requestId,sequence=sequence,itemId=chosen.id,prepared=true,lucky=lucky,paidRandomAllowed=paidAllowed})
    end)
    self.busy[id]=nil
    if not ok then warn("[AccessoryRoll] "..tostring(receipt));return {ok=false,code="profile_unavailable"} end
    return receipt
end
function Service:remove(userId)
    self.last[userId]=nil
    self.snapshots[userId]=nil
    self.lastLoad[userId]=nil
end
-- Invoke from a server event controller or trusted code redemption handler.
-- No client can specify an amount or bypass the configured award definition.
function Service:award(player,source,awardId)
    if (source~="event" and source~="promo") or type(awardId)~="string" or #awardId<1 or #awardId>48 or not awardId:match("^[%w_%-]+$") then
        return {ok=false,code="roll_invalid_award"}
    end
    -- A failed time/achievement gate must not poison a later valid claim.
    -- Successful awards dedupe permanently through profile.rollAwards.
    return self.profiles:transact(player.UserId,"rollaward:"..source..":"..awardId..":"..HttpService:GenerateGUID(false),
        {kind="rollAward",source=source,awardId=awardId,now=os.time()})
end
return Service
