-- Selecting a row is local. Only the separate confirmation button sends a ballot.
local VotingUI={}
function VotingUI.create(ctx,parent)
    local self={selectedId=nil,roundKey=nil,sending=false}
    local make,L=ctx.make,ctx.L
    local status=ctx.label(parent,"suspect",UDim2.new(1,0,0,34),UDim2.new(),11,ctx.colors.muted)
    local rows=make("ScrollingFrame",parent,{Name="CandidateRows",Size=UDim2.fromScale(1,1),Position=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
    make("UIListLayout",rows,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
    local choice=ctx.label(parent,"",UDim2.new(1,0,0,30),UDim2.new(0,0,1,-78),11,ctx.colors.muted)
    local confirm=ctx.button(parent,"confirmVote",UDim2.new(1,0,0,44),UDim2.new(0,0,1,-44),ctx.colors.gold)
    confirm.TextSize=12
    -- Entire ballot, including confirmation, scrolls on short landscape screens.
    status.Parent,choice.Parent,confirm.Parent=rows,rows,rows
    status.LayoutOrder,choice.LayoutOrder,confirm.LayoutOrder=0,200,201
    status.Size,choice.Size,confirm.Size=UDim2.new(1,-4,0,34),UDim2.new(1,-4,0,44),UDim2.new(1,-4,0,44)
    status.Position,choice.Position,confirm.Position=UDim2.new(),UDim2.new(),UDim2.new()
    function self:update(state)
        local roundKey=tostring(state.tableId)..":"..tostring(state.roundId)..":"..tostring(state.runoff==true)
        if self.roundKey~=roundKey then self.selectedId,self.sending,self.roundKey=nil,false,roundKey end
        if state.myVote then self.sending=false end
        for _,node in ipairs(rows:GetChildren()) do if node:IsA("GuiObject") and node~=status and node~=choice and node~=confirm then node:Destroy() end end
        local voting=state.phase=="Vote"
        local candidates={}
        for _,id in ipairs(state.candidates or {}) do candidates[id]=true end
        status.Text=L(state.result and "voteCounts" or (state.runoff and "runoff" or "suspect"))
        local chosenName=""
        for index,p in ipairs(state.people or {}) do
            local eligible=p.id~=ctx.userId and (not state.runoff or candidates[p.id])
            local selected=(state.myVote or self.selectedId)==p.id
            local text=(selected and "✓  " or "")..(p.id==ctx.userId and L("me").." · " or "")..p.name
            if state.result then text=text.."  ·  "..tostring(p.voteCount or 0) end
            if p.id==self.selectedId then chosenName=p.name end
            local row=ctx.button(rows,text,UDim2.new(1,-4,0,44),UDim2.new(),selected and ctx.colors.accent or ctx.colors.bg)
            row.TextSize,row.LayoutOrder=13,index
            row.TextColor3=selected and ctx.colors.bg or (voting and not eligible and ctx.colors.muted or ctx.colors.text)
            row.AutoButtonColor=voting and eligible and not state.myVote and not self.sending
            row.Activated:Connect(function()
                local current=ctx.state()
                if current.phase~="Vote" or current.myVote or self.sending then return end
                if not eligible then ctx.notify(L(p.id==ctx.userId and "noSelfVote" or "notCandidate")) return end
                self.selectedId=p.id
                self:update(current)
                task.defer(function()
                    if rows.Parent then rows.CanvasPosition=Vector2.new(0,math.max(0,rows.AbsoluteCanvasSize.Y-rows.AbsoluteSize.Y)) end
                end)
            end)
        end
        if state.result then
            for _,ballot in ipairs(state.result.ballots or {}) do
                local line=ctx.label(rows,L("ballotLine",{voter=ballot.voterName or L("player"),target=ballot.targetName or L("abstained")}),UDim2.new(1,-6,0,0),UDim2.new(),12,ctx.colors.muted)
                line.AutomaticSize=Enum.AutomaticSize.Y
                line.LayoutOrder=100
            end
        end
        choice.Text=state.myVote and L("voteProgress",{n=state.votesSubmitted or 0,total=state.capacity or 0}) or (self.selectedId and L("selectedSuspect",{name=chosenName}) or L(voting and "chooseVote" or "voteLater"))
        confirm.Visible=voting
        choice.Visible=not state.result
        rows.Size=UDim2.fromScale(1,1)
        confirm.Text=L(state.myVote and "voteSubmitted" or (self.sending and "voteSending" or "confirmVote"))
        local ready=voting and self.selectedId and not state.myVote and not self.sending
        confirm.BackgroundColor3=ready and ctx.colors.gold or ctx.colors.edge
        confirm.TextColor3=ready and ctx.colors.bg or ctx.colors.muted
        confirm.AutoButtonColor=ready==true or type(ready)=="number"
    end
    confirm.Activated:Connect(function()
        local state=ctx.state()
        if state.phase~="Vote" or state.myVote or not self.selectedId or self.sending then return end
        self.sending=true
        ctx.vote(self.selectedId)
        self:update(state)
        local roundKey=self.roundKey
        task.delay(3,function()
            if self.roundKey==roundKey and self.sending then self.sending=false self:update(ctx.state()) end
        end)
    end)
    return self
end
return VotingUI
