local Marketplace=game:GetService('MarketplaceService')
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Config=require(script.Parent.MonetizationConfig)
local Monetization={}
function Monetization.new(profiles,onChange)
    local self={offers={},passes={},products={}}
    for _,def in ipairs(Config.Passes) do
        if type(def.id)=='number' and def.id>0 then self.passes[def.id]=def; self.offers[#self.offers+1]={id=def.id,key=def.key,kind='pass',ids=def.ids} end
    end
    for _,def in ipairs(Config.Products) do
        if type(def.id)=='number' and def.id>0 then self.products[def.id]=def; self.offers[#self.offers+1]={id=def.id,key=def.key,kind='product',ids=def.ids} end
    end
    function self.sync(player)
        if RunService:IsStudio() then return end
        for id,def in pairs(self.passes) do
            local ok,owns=pcall(Marketplace.UserOwnsGamePassAsync,Marketplace,player.UserId,id)
            if ok and owns then
                local receipt=profiles:transact(player.UserId,'pass:'..id,{kind='grantCosmetics',ids=def.ids})
                if receipt.ok then onChange(player,receipt) end
            end
        end
    end
    Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
        if purchased and self.passes[id] then task.spawn(self.sync,player) end
    end)
    Marketplace.ProcessReceipt=function(info)
        local def=self.products[info.ProductId]
        local player=Players:GetPlayerByUserId(info.PlayerId)
        if RunService:IsStudio() or not def or not player or not profiles:public(info.PlayerId).ready then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local ok,receipt=pcall(function()
            return profiles:transact(info.PlayerId,'purchase:'..tostring(info.PurchaseId),{
                kind='support',ids=def.ids,robux=info.CurrencySpent,purchaseId=tostring(info.PurchaseId)})
        end)
        if ok and receipt.ok then
            onChange(player,receipt)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    return self
end
return Monetization
