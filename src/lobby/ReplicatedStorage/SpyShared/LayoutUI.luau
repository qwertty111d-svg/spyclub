-- Pixel layouts share one policy. Touch targets never shrink with a desktop UIScale.
local LayoutUI={}
function LayoutUI.measure(width,height)
    local narrow=width<600
    local compact=height<500
    local modalWidth=math.min(width-24,880)
    return {
        narrow=narrow,compact=compact,
        modal={w=modalWidth,h=math.min(height-24,660)},
        dock={w=compact and 86 or 104,h=compact and 248 or 344,button=compact and 58 or 82,icon=compact and 38 or 60,columns=1},
        match={w=math.min(width-24,900),h=math.min(height-72,compact and 286 or 326)},
        reveal={w=math.min(width-24,780),h=math.min(height-24,610),resultHeight=narrow and 264 or 218},
    }
end
function LayoutUI.shouldOpenMatch(previous,current)
    if not current.tableId then return false end
    if not previous or previous.tableId~=current.tableId then return true end
    if current.roundId~=previous.roundId and current.phase=="Role" then return true end
    if current.phase~=previous.phase then return current.phase=="Role" or current.phase=="Vote" or current.phase=="Result" end
    return current.phase=="Vote" and current.runoff==true and previous.runoff~=true
end
return LayoutUI
