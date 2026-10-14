-- One receipt owner in each place, using its existing shared Profiles instance.
local Marketplace=game:GetService("MarketplaceService")
local PolicyService=game:GetService("PolicyService")
local Players=game:GetService("Players")
local Config=require(script.Parent.MonetizationConfig)
local RollConfig=require(game:GetService("ReplicatedStorage").SpyShared.AccessoryRollConfig)
local Monetization={}
local activeController
local function validId(value)
    return type(value)=="number" and value==value and value>0 and value%1==0 and value<math.huge
end
local function integer(value)
    return type(value)=="number" and value==value and value>=0 and value%1==0 and value<math.huge
end
function Monetization.new(profiles,onChange,options)
    if activeController then
        assert(activeController.profiles==profiles,"SpyClub receipt owner already uses a different Profiles instance")
        return activeController
    end
    options=options or {}
    local self={profiles=profiles,products={},rollProducts={},passes={},definitions={},policy={},prices={},entitlements={},lastPrompt={}}
    local function notify(player,receipt)
        if onChange and player.Parent==Players then
            local ok,err=pcall(onChange,player,receipt)
            if not ok then warn("SpyClub monetization profile notification: "..tostring(err))end
        end
    end
    for _,def in ipairs(Config.Passes)do if validId(def.id)then self.passes[def.id]=def end end
    for _,def in ipairs(Config.LegacyProducts or {})do
        if validId(def.id) and Config.validateReward(def) then self.products[def.id]=def end
    end
    local duplicate={}
    for _,def in ipairs(Config.Products)do
        table.insert(self.definitions,def)
        local reward=type(def.reward)=="table" and def.reward or {}
        local valid=Config.validateReward(def) and (reward.rolls or 0)>0
            and (reward.coins or 0)==0 and (reward.xp or 0)==0
        if valid and validId(def.id) and not self.products[def.id] and not duplicate[def.id] then
            self.products[def.id]=def;self.rollProducts[def.id]=def
        elseif validId(def.id) and self.rollProducts[def.id]then
            -- Ambiguous new product definitions cannot deliver the wrong quantity.
            duplicate[def.id]=true;self.products[def.id]=nil;self.rollProducts[def.id]=nil
        end
    end
    local policyFor
    policyFor=function(player)
        local id=player.UserId
        local entry=self.policy[id]
        if not entry or entry.player~=player then
            entry={player=player,known=false,restricted=true,busy=false,retryAt=0,expiresAt=0,failures=0}
            self.policy[id]=entry
        end
        local now=os.clock()
        if not entry.busy and now>=entry.retryAt and (not entry.known or now>=entry.expiresAt) then
            entry.busy=true;entry.known=false;entry.restricted=true
            player:SetAttribute("SpyPaidRandomRestricted",true)
            task.spawn(function()
                local ok,info=pcall(PolicyService.GetPolicyInfoForPlayerAsync,PolicyService,player)
                if self.policy[id]~=entry or player.Parent~=Players then return end
                entry.busy=false
                if ok and type(info)=="table" and type(info.ArePaidRandomItemsRestricted)=="boolean"then
                    entry.known=true;entry.restricted=info.ArePaidRandomItemsRestricted
                    entry.failures=0;entry.retryAt=0;entry.expiresAt=os.clock()+60
                else
                    entry.known=false;entry.restricted=true;entry.failures=math.min(8,entry.failures+1)
                    local delay=math.min(30,2^(entry.failures-1));entry.retryAt=os.clock()+delay
                    task.delay(delay,function()
                        if self.policy[id]==entry and player.Parent==Players then policyFor(player)end
                    end)
                end
                player:SetAttribute("SpyPaidRandomRestricted",entry.restricted)
                notify(player,{ok=true,code="roll_shop_synced"})
            end)
        end
        return entry
    end
    local function priceFor(def)
        if self.rollProducts[def.id]~=def then return nil end
        local entry=self.prices[def.id]
        if not entry then entry={known=false,busy=false,retryAt=0,expiresAt=0,failures=0};self.prices[def.id]=entry end
        local now=os.clock()
        if not entry.busy and now>=entry.retryAt and (not entry.known or now>=entry.expiresAt)then
            entry.busy=true;entry.known=false
            task.spawn(function()
                local ok,info=pcall(Marketplace.GetProductInfoAsync,Marketplace,def.id,Enum.InfoType.Product)
                entry.busy=false
                if ok and type(info)=="table" and integer(info.PriceInRobux) and info.PriceInRobux>0 and info.IsForSale~=false then
                    entry.known=true;entry.price=info.PriceInRobux;entry.expiresAt=os.clock()+300;entry.failures=0;entry.retryAt=0
                else
                    entry.known=false;entry.price=nil;entry.failures=math.min(8,entry.failures+1)
                    entry.retryAt=os.clock()+math.min(30,2^(entry.failures-1))
                end
                for _,player in ipairs(Players:GetPlayers())do notify(player,{ok=true,code="roll_shop_synced"})end
            end)
        end
        return entry
    end
    function self:canSpendPaidRolls(player)
        local policy=policyFor(player)
        return policy.known and policy.restricted==false
    end
    function self:isPaidRandomRestricted(player)return not self:canSpendPaidRolls(player)end
    function self:hasEntitlement(player,key)
        if key=="case_luck_2x" and not self:canSpendPaidRolls(player)then return false end
        return self.entitlements[player.UserId] and self.entitlements[player.UserId][key]==true or false
    end
    function self:shopFor(player,profile)
        profile=profile or profiles:public(player.UserId)
        local policy=policyFor(player)
        local shop={offers={},restricted=policy.restricted,policyReady=policy.known,ready=profile.ready==true}
        for _,def in ipairs(self.definitions)do
            local configured=self.rollProducts[def.id]==def
            local price=configured and priceFor(def) or nil
            local quantity=type(def.reward)=="table" and def.reward.rolls or 0
            local available=configured and price and price.known and policy.known and not policy.restricted
                and profile.ready==true and not profile.pendingTrade and not profiles.pending[player.UserId]
                and not profiles.busy[player.UserId] and not player:GetAttribute("SpyTeleporting")
                and (profile.rolls or 0)+quantity<=RollConfig.MaxRolls
                and (not options.canPrompt or options.canPrompt(player)==true) or false
            table.insert(shop.offers,{id=def.id,key=def.key,kind="product",category="rolls",rolls=quantity,
                previewPrice=def.previewPrice,configured=configured,available=available,priceReady=price and price.known or false,
                priceRobux=price and price.known and price.price or nil,priceSource=price and price.known and "marketplace" or nil})
        end
        return shop
    end
    function self.offersFor(first,second)
        local player=second or first
        local offers={}
        for _,offer in ipairs(self:shopFor(player).offers)do
            if offer.configured and not self:isPaidRandomRestricted(player)then table.insert(offers,offer)end
        end
        return offers
    end
    function self:prompt(player,productId)
        if not validId(productId) or not self.rollProducts[productId]then return {ok=false,code="roll_product_unavailable"}end
        if not self:canSpendPaidRolls(player)then return {ok=false,code="roll_paid_restricted"}end
        local profile=profiles:public(player.UserId)
        if not profile.ready then return {ok=false,code="profile_unavailable"}end
        if profile.pendingTrade or profiles.pending[player.UserId] or profiles.busy[player.UserId] then return {ok=false,code="trade_processing"}end
        if player:GetAttribute("SpyTeleporting") or options.canPrompt and options.canPrompt(player)~=true then return {ok=false,code="roll_match_active"}end
        if (profile.rolls or 0)+self.rollProducts[productId].reward.rolls>RollConfig.MaxRolls then return {ok=false,code="roll_wallet_full"}end
        local price=priceFor(self.rollProducts[productId])
        if not price or not price.known then return {ok=false,code="roll_product_unavailable"}end
        local now=os.clock()
        if now-(self.lastPrompt[player.UserId] or -10)<2 then return {ok=false,code="slowDown"}end
        self.lastPrompt[player.UserId]=now
        local ok=pcall(Marketplace.PromptProductPurchase,Marketplace,player,productId)
        return {ok=ok,code=ok and "rollPurchasePrompted" or "roll_product_unavailable",productId=productId}
    end
    function self:sync(player)
        policyFor(player)
        local owned=self.entitlements[player.UserId] or {};self.entitlements[player.UserId]=owned
        for id,def in pairs(self.passes)do
            local ok,result=pcall(Marketplace.UserOwnsGamePassAsync,Marketplace,player.UserId,id)
            local key=def.entitlement or def.key
            owned[key]=ok and result==true
            if owned[key] and def.ids and #def.ids>0 then
                local saved,receipt=pcall(profiles.transact,profiles,player.UserId,"pass:"..id,{kind="grantCosmetics",ids=def.ids})
                if saved and receipt and receipt.ok then notify(player,receipt)end
            end
        end
        player:SetAttribute("SpyCaseLuck2x",self:hasEntitlement(player,"case_luck_2x"))
        notify(player,{ok=true,code="monetizationSynced"})
    end
    Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
        if purchased==true and self.passes[id]then task.spawn(function()self:sync(player)end)end
    end)
    Marketplace.ProcessReceipt=function(info)
        local def=self.products[info.ProductId]
        local player=Players:GetPlayerByUserId(info.PlayerId)
        local purchaseId=type(info.PurchaseId)=="string" and info.PurchaseId or ""
        if not def or not player or purchaseId=="" or not Config.validateReward(def)then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local profile=profiles:public(info.PlayerId)
        if not profile or profile.ready~=true then return Enum.ProductPurchaseDecision.NotProcessedYet end
        -- Payment grants a deterministic wallet balance. Policy gates its RANDOM
        -- use and prompting, never acknowledgement of an already paid receipt.
        local reward=def.reward or {}
        local robux=integer(info.CurrencySpent) and info.CurrencySpent or 0
        local ok,receipt=pcall(profiles.transact,profiles,info.PlayerId,"purchase:"..purchaseId,
            {kind="paidGrant",rolls=reward.rolls,coins=reward.coins,xp=reward.xp,ids=def.ids,robux=robux,purchaseId=purchaseId,productId=info.ProductId})
        if ok and receipt and receipt.ok then
            notify(player,receipt)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
        if not ok then warn("SpyClub purchase persistence: "..tostring(receipt))end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    Players.PlayerRemoving:Connect(function(player)
        self.policy[player.UserId]=nil;self.entitlements[player.UserId]=nil;self.lastPrompt[player.UserId]=nil
    end)
    activeController=self
    return self
end
return Monetization
