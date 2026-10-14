local Shop=require(game:GetService("ReplicatedStorage").SpyShared.RollShopConfig)
local Config={
    RollLuckPassId=1998344385,
    -- Hidden grandfathered rights; ownership is still restored in both places.
    Passes={
        {id=1998632381,key="black_tie_collection",category="collection",
            ids={"founder_suit","closed_club_fedora","interrogation_glasses","founder_tie","inner_circle_frame","club_founder"}},
        {id=1998344385,key="case_luck_2x",category="boosts",entitlement="case_luck_2x",paidRandom=true},
    },
    -- Hidden receipt definitions are permanent. Never sell these as Roll packs.
    LegacyProducts={
        {id=3714674590,key="level_plus_one",reward={xp=100}},
        {id=3714674680,key="coins_500",reward={coins=500}},
        {id=3714674731,key="coins_1600",reward={coins=1600}},
        {id=3714674783,key="coins_5000",reward={coins=5000}},
        {id=3714115805,key="supportPack",ids={}},
    },
    Products={},
}
for _,pack in ipairs(Shop.Packs)do
    table.insert(Config.Products,{id=pack.id,key=pack.key,category="rolls",paidRandom=true,
        reward={rolls=pack.rolls},previewPrice=pack.previewPrice})
end
local function integer(value,maximum)
    return type(value)=="number" and value==value and value>=0 and value%1==0 and value<=maximum
end
function Config.validateReward(def)
    if type(def)~="table" or def.reward~=nil and type(def.reward)~="table" then return false end
    local reward=def.reward or {}
    local coins=reward.coins==nil and 0 or reward.coins
    local xp=reward.xp==nil and 0 or reward.xp
    return integer(coins,1000000) and integer(xp,100000)
        and (reward.rolls==nil or integer(reward.rolls,Shop.MaxPackRolls) and reward.rolls>0)
end
return Config
