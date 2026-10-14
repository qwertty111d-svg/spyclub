-- Honest comparisons use verified native prices, never suggested placeholders.
local Rules={}
local function positiveInteger(value)
    return type(value)=="number" and value==value and value>0 and value<math.huge and value%1==0
end
function Rules.activeRound(state)
    state=state or {}
    return state.tableId~=nil and state.phase~="Waiting" and state.phase~="Result" and state.phase~="Finished"
end
function Rules.canPurchase(offer,profile,state,pending)
    return not pending and profile and profile.ready==true and profile.pendingTrade==nil
        and not Rules.activeRound(state) and offer and offer.available==true and offer.configured==true
        and offer.priceReady==true and positiveInteger(offer.id) and positiveInteger(offer.priceRobux)
        and positiveInteger(offer.rolls)
end
function Rules.savings(single,offer)
    if not single or not offer or single.priceReady~=true or offer.priceReady~=true
        or not positiveInteger(single.priceRobux) or not positiveInteger(offer.priceRobux)
        or not positiveInteger(offer.rolls) or offer.rolls<=1 then return nil end
    local reference=single.priceRobux*offer.rolls
    if offer.priceRobux>=reference then return nil end
    return {amount=reference-offer.priceRobux,percent=math.floor((reference-offer.priceRobux)/reference*100+.5),reference=reference}
end
function Rules.price(offer)
    if offer and offer.priceReady==true and positiveInteger(offer.priceRobux) then return offer.priceRobux,true end
    if offer and positiveInteger(offer.previewPrice) then return offer.previewPrice,false end
    return nil,false
end
return Rules
