local Inventory={Slots={"card","effect","trinket","outfit","accessory","emote","frame","title","hat","glasses","tie","gloves","shoulder","hair"},MaxGadgets=10}
Inventory.EquipSlots={}
for _,slot in ipairs(Inventory.Slots) do Inventory.EquipSlots[slot]=true end
local function defaultFor(slot)
    if slot=="card" then return "classic" end
    if slot=="effect" then return "soft" end
    return ""
end
local function validSlot(slot)
    return Inventory.EquipSlots[slot] == true
end
function Inventory.initialize(profile)
    profile.owned=profile.owned or {classic=true,soft=true}
    profile.itemCounts=profile.itemCounts or {}
    -- Older profiles use booleans. Counts stay in that same saved profile.
    for id,owned in pairs(profile.owned) do
        if owned==true and profile.itemCounts[id]==nil then profile.itemCounts[id]=1 end
    end
    for id,count in pairs(profile.itemCounts) do
        profile.owned[id]=count>0 and true or nil
        if count==0 then profile.itemCounts[id]=nil end
    end
    profile.quantities=profile.quantities or {}
    profile.equipped=profile.equipped or {}
    for _,slot in ipairs(Inventory.Slots) do if profile.equipped[slot]==nil then profile.equipped[slot]="" end end
    profile.equipped.card=profile.equipped.card~="" and profile.equipped.card or "classic"
    profile.equipped.effect=profile.equipped.effect~="" and profile.equipped.effect or "soft"
end
function Inventory.count(profile,itemId)
    local count=profile.itemCounts and profile.itemCounts[itemId]
    return count~=nil and count or profile.owned and profile.owned[itemId]==true and 1 or 0
end
function Inventory.grant(profile,item,keepDuplicate)
    Inventory.initialize(profile)
    if item.kind=="gadget" then
        local old=profile.quantities[item.id] or 0
        if old>=Inventory.MaxGadgets then return false end
        profile.quantities[item.id]=math.min(Inventory.MaxGadgets,old+(item.quantity or 1))
        profile.owned[item.id]=true
        return true,profile.quantities[item.id]-old
    end
    if profile.owned[item.id] then
        if keepDuplicate==true then
            profile.itemCounts[item.id]=Inventory.count(profile,item.id)+1
        end
        return false,Inventory.count(profile,item.id)
    end
    profile.owned[item.id]=true
    profile.itemCounts[item.id]=1
    return true,1
end
function Inventory.equip(profile,itemId,catalog,options)
    if itemId=="none" then profile.equipped.trinket="" return {ok=true,code="equipped"} end
    local clear=type(itemId)=="string" and itemId:match("^clear:([%w_]+)$")
    if clear then
        if not validSlot(clear) then return {ok=false,code="invalid_item"} end
        profile.equipped[clear]=defaultFor(clear)
        return {ok=true,code="equipped",slot=clear,itemId=profile.equipped[clear]}
    end
    local item=catalog.ById[itemId]
    if not item then return {ok=false,code="invalid_item"} end
    if item.kind=="gadget" then return {ok=false,code="invalid_item"} end
    if profile.owned[itemId] ~= true then return {ok=false,code="not_owned"} end
    local slot=item.equipSlot or item.kind
    if not slot or not validSlot(slot) then return {ok=false,code="invalid_item"} end
    if profile.equipped[slot]==item.id and not (options and options.force) then
        profile.equipped[slot]=defaultFor(slot)
        return {ok=true,code="equipped",slot=slot,itemId=profile.equipped[slot]}
    end
    if not (options and options.preserveOtherSlots) then
        if slot=="hat" then profile.equipped.accessory="" end
        if slot=="accessory" and item.id=="tophat" then profile.equipped.hat="" end
    end
    profile.equipped[slot]=item.id
    return {ok=true,code="equipped",slot=slot,itemId=item.id}
end
function Inventory.use(profile,itemId,catalog)
    local item=catalog.ById[itemId]
    if not item or item.kind~="gadget" or (profile.quantities[itemId] or 0)<1 then return {ok=false,code="gadgetEmpty"} end
    profile.quantities[itemId]=profile.quantities[itemId]-1
    return {ok=true,code="gadgetUsed",itemId=itemId}
end

function Inventory.removeOwned(profile, itemId, catalog)
    if type(profile)~="table" or type(itemId)~="string" or type(catalog)~="table" then return {ok=false,code="invalid_item",resetSlots={}} end
    Inventory.initialize(profile)
    local item=catalog.ById and catalog.ById[itemId]
    if not item then return {ok=false,code="invalid_item",resetSlots={}} end
    if item.kind == "gadget" then return {ok=false,code="protected_item",resetSlots={}} end
    if profile.owned[itemId] ~= true then return {ok=false,code="not_owned",resetSlots={}} end
    local remaining=Inventory.count(profile,itemId)-1
    profile.itemCounts[itemId]=remaining>0 and remaining or nil
    profile.owned[itemId]=remaining>0 and true or nil
    local resetSlots={}
    if remaining==0 then
        for _,slot in ipairs(Inventory.Slots) do
            if profile.equipped[slot] == itemId then
                profile.equipped[slot] = defaultFor(slot)
                table.insert(resetSlots,slot)
            end
        end
    end
    return {ok=true,code="removed",itemId=itemId,remaining=remaining,resetSlots=resetSlots}
end

return Inventory
