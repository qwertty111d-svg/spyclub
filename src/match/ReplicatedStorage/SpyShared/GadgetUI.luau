-- Notes exist only in this LocalScript-owned UI. Never include their text in a remote payload.
local ModalUI=require(script.Parent.ModalUI)
local I18n=require(script.Parent.I18n)
local GadgetUI={}
function GadgetUI.create(ctx)
    local self=ModalUI.create(ctx,"gadgets","gadgets","notebookHint",700)
    self.notes,self.unlocked,self.mode,self.history="",false,"notebook",{}
    function self:render()
        -- A keyboard resize or incoming snapshot must never recreate a focused TextBox.
        if self.mode=="notebook" and self.unlocked and self.input and self.input.Parent then
            self.notes=self.input.Text
            self.title.Text=ctx.L("notebookTitle")
            self.hint.Text=ctx.L("notebookHint")
            self.input.PlaceholderText=ctx.L("notebookPlaceholder")
            if self.privateLabel then self.privateLabel.Text=ctx.L("notebookPrivate") end
            return
        end
        if self.input and self.input.Parent then self.notes=self.input.Text end
        self:clear()
        self.input=nil
        local L=ctx.L
        if self.mode=="notebook" then
            self.title.Text=L("notebookTitle")
            self.hint.Text=L("notebookHint")
            self.privateLabel=self:text(L("notebookPrivate"),14)
            if not self.unlocked then
                self:action(L("use"),function() ctx.request("useGadget","notebook") end,true)
                return
            end
            local input=ctx.make("TextBox",self.surface,{Name="PrivateNotes",Text=self.notes,PlaceholderText=L("notebookPlaceholder"),Size=UDim2.new(1,0,0,280),BackgroundColor3=ctx.colors.bg,BorderSizePixel=0,TextColor3=ctx.colors.text,PlaceholderColor3=ctx.colors.muted,TextSize=16,Font=Enum.Font.BuilderSans,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ClearTextOnFocus=false,MultiLine=true})
            ctx.make("UICorner",input,{CornerRadius=UDim.new(0,10)})
            ctx.make("UIPadding",input,{PaddingTop=UDim.new(0,14),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),PaddingBottom=UDim.new(0,14)})
            input:GetPropertyChangedSignal("Text"):Connect(function() self.notes=input.Text end)
            self.input=input
        else
            self.title.Text=L("historyTitle")
            self.hint.Text=L("historyHint")
            if #self.history==0 then self:text(L("noBallots"),17) end
            for index,round in ipairs(self.history) do
                self:text(L("historyRound",{n=index,word=I18n.word(ctx.language(),round.word)}),19,ctx.colors.gold)
                local spyName=L("player")
                for _,ballot in ipairs(round.ballots or {}) do
                    if ballot.voterId==round.spyId then spyName=ballot.voterName or spyName end
                    if ballot.targetId==round.spyId then spyName=ballot.targetName or spyName end
                    self:text(L("ballotLine",{voter=ballot.voterName or L("player"),target=ballot.targetName or L("abstained")}),14)
                end
                self:text(L("historySpy",{name=spyName}),14,ctx.colors.accent)
            end
        end
    end
    function self:receive(receipt)
        if not receipt.ok or receipt.code~="gadgetUsed" then return end
        if receipt.itemId=="notebook" then self.unlocked,self.mode=true,"notebook"
        elseif receipt.itemId=="history" then self.history,self.mode=receipt.history or {},"history"
        else return end
        self:open()
    end
    function self:openNotes()
        self.mode="notebook"
        self:open()
    end
    return self
end
return GadgetUI
