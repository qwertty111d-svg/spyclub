local ModalUI=require(script.Parent.ModalUI)
local HighStakesUI={}
function HighStakesUI.create(ctx)
    local self=ModalUI.create(ctx,"highstakes","highStakes","highStakesHint",660)
    function self:render()
        self:clear()
        local p=ctx.profile()
        local eligible=p.ready and (p.level or 1)>=3
        self:text(ctx.L(eligible and "highStakesBadgeReady" or "highStakesBadgeLocked"),14,eligible and ctx.colors.accent or ctx.colors.muted)
        self:text(ctx.L("highStakesRoomTitle"),22,ctx.colors.gold).Font=Enum.Font.BuilderSansMedium
        self:text(ctx.L("highStakesEntry"),17,ctx.colors.text)
        self:text(ctx.L("highStakesPotRule"),14)
        self:text(ctx.L(eligible and "highStakesAccessReady" or "highStakesAccessLocked"),15)
        self:text(ctx.L("highStakesCharged"),13)
        self:text(ctx.L("highStakesRefundHint"),13)
        self:action(ctx.L("close"),function() self:close() end)
    end
    return self
end
return HighStakesUI
