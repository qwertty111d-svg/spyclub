-- Pure server rules, shared by the preparation service and atomic economy update.
local Config=require(script and game:GetService("ReplicatedStorage").SpyShared.AccessoryRollConfig or "AccessoryRollConfig")
local Rules={}
local styles={male=true,female=true,unisex=true}
function Rules.style(profile,category,catalog)
    if category.styleGroup and styles[category.styleGroup] then return category.styleGroup end
    local preference=profile.appearanceStyleGroup
    if styles[preference] then return preference end
    if category.slot=="hair" then
        local current=catalog.ById[(profile.equipped or {}).hair]
        if current and styles[current.styleGroup] then return current.styleGroup end
    end
    return "all"
end
function Rules.allowed(item,category,profile,catalog)
    if not item or not category or (item.equipSlot or item.kind)~=category.slot then return false end
    if item.kind~="cosmetic" and item.kind~="outfit" and item.kind~="accessory" then return false end
    if item.premium or item.setReward or item.dailyOnly or item.rollDisabled then return false end
    if not Config.Weights[item.rarity] then return false end
    local style=Rules.style(profile,category,catalog)
    if item.styleGroup and style~="all" and item.styleGroup~=style and item.styleGroup~="unisex" then return false end
    -- The existing renderer selects a hat before the legacy top-hat accessory.
    if category.slot=="accessory" and item.id=="tophat" and (profile.equipped or {}).hat and profile.equipped.hat~="" then return false end
    return true
end
function Rules.sequence(requestId)
    if type(requestId)~="string" or #requestId>64 then return nil end
    local sequence,token=requestId:match("^(%d+)%-([%w%-]+)$")
    if not sequence or #sequence>10 or not token or #token<8 then return nil end
    local value=tonumber(sequence)
    if not value or value<1 or value%1~=0 or value>Config.MaxRolls then return nil end
    return value
end
function Rules.pool(items,category,profile,catalog,isPrepared)
    local groups,total={},0
    local weights=category.weights or Config.Weights
    for _,item in ipairs(items) do
        local weight=weights[item.rarity]
        if type(weight)=="number" and weight==weight and weight>0 and weight<math.huge
            and Rules.allowed(item,category,profile,catalog) and isPrepared(item,category.slot) then
            groups[item.rarity]=groups[item.rarity] or {}
            table.insert(groups[item.rarity],item)
        end
    end
    for rarity in pairs(groups) do total+=weights[rarity] end
    local chances,entries={},{}
    for _,rarity in ipairs(Config.RarityOrder) do
        local group=groups[rarity]
        if group and total>0 then
            local chance=100*weights[rarity]/total
            chances[rarity]=chance
            for _,item in ipairs(group) do table.insert(entries,{item=item,chance=chance/#group}) end
        end
    end
    return entries,chances
end
function Rules.select(entries,ticket)
    local cursor=0
    for _,entry in ipairs(entries) do
        cursor+=entry.chance
        if ticket<cursor then return entry.item end
    end
    return entries[#entries] and entries[#entries].item
end
return Rules
