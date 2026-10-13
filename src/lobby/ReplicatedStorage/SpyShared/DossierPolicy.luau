-- Pure input/phase rules shared by the character menu and match endpoint.
local Policy={}
local editable={Waiting=true,Result=true,Finished=true}
function Policy.canChange(phase)
    return editable[phase]==true
end
function Policy.canOpen(flags)
    flags=flags or {}
    return not (flags.teleporting or flags.cinematic or flags.phone or flags.trade or flags.minigame)
end
function Policy.hotkey(processed,focused,flags)
    return not processed and not focused and Policy.canOpen(flags)
end
return Policy
