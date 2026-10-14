-- Display the current server-prepared pool and its actual luck adjustment.
local Odds={}
local ORDER={"common","uncommon","rare","epic","legendary","mythic"}
function Odds.percent(value)
    if type(value)~="number"or value~=value or value<=0 or value>100.00001 then return nil end
    return string.format("%.2f",math.min(100,value)):gsub("0+$",""):gsub("%.$","").."%"
end
function Odds.details(row,catalog,language)
    local result={}
    for _,entry in ipairs(row and row.items or{})do
        local percent=Odds.percent(entry.chance)
        if percent then
            local item=(catalog.ById or{})[entry.id]
            local name=language=="en"and (entry.labelEn or item and item.en)or(entry.labelRu or item and item.ru)
            result[#result+1]={id=entry.id,label=name or entry.label or entry.id,percent=percent,chance=entry.chance,rarity=entry.rarity}
        end
    end
    table.sort(result,function(a,b)return a.chance==b.chance and tostring(a.label)<tostring(b.label)or a.chance>b.chance end)
    return result
end
function Odds.summary(row,catalog,language,compact)
    if not row then return "—"end
    if row.identity then
        local entries=Odds.details(row,catalog,language)
        if #entries==0 then return "—"end
        local uniform=true
        for _,entry in ipairs(entries)do if math.abs(entry.chance-entries[1].chance)>.00001 then uniform=false end end
        if compact and uniform then return entries[1].percent..(language=="en"and" each"or" каждый")end
        return tostring(#entries)..(language=="en"and" options"or" вариантов")
            ..(uniform and" · "..entries[1].percent..(language=="en"and" each"or" каждый")or"")
    end
    local parts={}
    for _,id in ipairs(ORDER)do
        local percent=Odds.percent((row.chances or{})[id])
        local rarity=(catalog.Rarities or{})[id]
        if percent and rarity then parts[#parts+1]=(language=="en"and rarity.en or rarity.ru).." "..percent end
    end
    return #parts>0 and table.concat(parts,"   ·   ")or"—"
end
return Odds
