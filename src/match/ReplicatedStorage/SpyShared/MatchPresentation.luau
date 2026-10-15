-- Match-only client presentation. Actual game clothing; no account thumbnails.
local Players=game:GetService("Players")
local Presentation={}
local marks={}
local roundToken
local changed=Instance.new("BindableEvent")
Presentation.MarkChanged=changed.Event

function Presentation.getMark(userId) return marks[userId] end
function Presentation.cycleMark(userId)
    marks[userId]=marks[userId]==nil and "suspect" or marks[userId]=="suspect" and "clear" or nil
    changed:Fire(userId,marks[userId])
    return marks[userId]
end
function Presentation.updateState(state)
    if type(state)~="table" or not state.roundToken or state.phase=="VoteAccepted" then return end
    if state.phase=="Result" or state.phase=="Finished" then return end
    if roundToken~=state.roundToken then
        roundToken=state.roundToken
        table.clear(marks)
        changed:Fire(nil,nil)
    end
end

function Presentation.applyCameraVisibility(character,showHead)
    if not character then return end
    for _,object in ipairs(character:GetDescendants())do
        if object:IsA("BasePart") and object.Name~="HumanoidRootPart"then
            local hidden=false
            if not showHead then
                hidden=object.Name=="Head" or object.Name=="SpyClassicHead"
                local accessory=object:FindFirstAncestorWhichIsA("Accessory")
                if accessory then
                    local slot=accessory:GetAttribute("SpySlot")
                    hidden=slot=="hat" or slot=="hair" or slot=="glasses"
                    local handle=accessory:FindFirstChild("Handle")
                    if handle then
                        for _,a in ipairs(handle:GetChildren())do
                            if a:IsA("Attachment") and (a.Name=="HatAttachment" or a.Name=="HairAttachment"
                                or a.Name=="FaceFrontAttachment" or a.Name=="FaceCenterAttachment")then hidden=true end
                        end
                    end
                end
            end
            object.LocalTransparencyModifier=hidden and 1 or 0
        end
    end
end
function Presentation.cameraFrame(head,rotation,mode,cardOpen)
    local look=rotation.LookVector
    if mode=="table" and not cardOpen then
        -- A close shoulder composition keeps the opposite faces and felt in view.
        -- The private card still switches to the existing first-person framing.
        local position=head-look*2.5+rotation.RightVector*.85+Vector3.new(0,.65,0)
        return CFrame.lookAt(position,head+look*10+Vector3.new(0,-.85,0)),true
    end
    local position=head+Vector3.new(0,.04,0)
    return CFrame.lookAt(position,position+look),false
end

local function strip(copy)
    for _,object in ipairs(copy:GetDescendants())do
        if object:IsA("LuaSourceContainer") or object:IsA("LayerCollector") or object:IsA("Sound")
            or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Light") or object:IsA("RemoteEvent") or object:IsA("RemoteFunction")
            or object:IsA("BindableEvent") or object:IsA("BindableFunction")
            or object:IsA("ProximityPrompt") or object:IsA("ClickDetector") or object:IsA("Animator") then
            object:Destroy()
        elseif object:IsA("BasePart") then
            object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false
            object.LocalTransparencyModifier=0
        elseif object:IsA("Humanoid") then
            object.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        elseif object:IsA("JointInstance") then
            if (object.Part0 and not object.Part0:IsDescendantOf(copy))
                or (object.Part1 and not object.Part1:IsDescendantOf(copy)) then object:Destroy() end
        end
    end
end

function Presentation.attachPortrait(host,targetPlayer,options)
    options=options or {}
    local watchedUserId=options.userId or (targetPlayer and targetPlayer.UserId)
    local old=host:FindFirstChild("LivePortrait")
    if old then old:Destroy() end
    local viewport=Instance.new("ViewportFrame")
    viewport.Name="LivePortrait";viewport.Size=UDim2.fromScale(1,1)
    viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0;viewport.ZIndex=host.ZIndex+1
    viewport.Ambient=Color3.fromRGB(190,190,190)
    viewport.LightColor=Color3.fromRGB(255,255,255);viewport.LightDirection=Vector3.new(-1,-.7,-1)
    viewport.Parent=host
    local world=Instance.new("WorldModel");world.Name="PortraitWorld";world.Parent=viewport
    local camera=Instance.new("Camera");camera.FieldOfView=options.fullBody and 38 or 36;camera.Parent=viewport
    viewport.CurrentCamera=camera
    local waiting=Instance.new("TextLabel")
    waiting.Name="PortraitStatus";waiting.Size=UDim2.fromScale(1,1);waiting.BackgroundTransparency=1
    waiting.Text="…";waiting.Font=Enum.Font.BuilderSansBold;waiting.TextSize=18
    waiting.TextColor3=Color3.fromRGB(188,187,181);waiting.ZIndex=viewport.ZIndex+1;waiting.Parent=viewport
    local disposed,queued=false,false
    local connections,characterConnections,playerConnections={},{},{}
    local function clearCharacterConnections()
        for _,connection in ipairs(characterConnections)do connection:Disconnect()end
        table.clear(characterConnections)
    end
    local function rebuild()
        if disposed or not host.Parent then return end
        local character=targetPlayer and targetPlayer.Character
        if not character or not character.Parent then waiting.Visible=true;world:ClearAllChildren();return end
        local archivable=character.Archivable
        character.Archivable=true
        local ok,copy=pcall(function()return character:Clone()end)
        character.Archivable=archivable
        if not ok or not copy then waiting.Visible=true;return end
        local assembled,error=pcall(function()
            strip(copy);copy.Name="EquippedCharacter";copy:PivotTo(CFrame.new())
            local head=copy:FindFirstChild("Head")
            if not head then error("missing_head")end
            local focus=head.Position+Vector3.new(0,.05,0)
            local distance=3.8
            if options.fullBody then
                local _,size=copy:GetBoundingBox()
                focus=head.Position-Vector3.new(0,1.35,0)
                distance=math.max(7.5,size.Y*1.1)
            end
            camera.CFrame=CFrame.lookAt(focus+Vector3.new(0,.12,-distance),focus)
        end)
        if not assembled then copy:Destroy();waiting.Visible=true;return end
        world:ClearAllChildren();copy.Parent=world;waiting.Visible=false
    end
    local function schedule()
        if disposed or queued then return end
        queued=true
        task.delay(.15,function()queued=false;rebuild()end)
    end
    local function observe(character)
        clearCharacterConnections()
        if character then
            table.insert(characterConnections,character.ChildAdded:Connect(schedule))
            table.insert(characterConnections,character.ChildRemoved:Connect(schedule))
            table.insert(characterConnections,character:GetAttributeChangedSignal("SpyCosmeticsReady"):Connect(schedule))
        end
        schedule()
    end
    local function dispose()
        if disposed then return end
        disposed=true;clearCharacterConnections()
        for _,connection in ipairs(connections)do connection:Disconnect()end
        for _,connection in ipairs(playerConnections)do connection:Disconnect()end
        viewport:Destroy()
    end
    local function bindTarget(nextPlayer)
        if disposed then return end
        for _,connection in ipairs(playerConnections)do connection:Disconnect()end
        table.clear(playerConnections);clearCharacterConnections()
        targetPlayer=nextPlayer
        if targetPlayer then
            table.insert(playerConnections,targetPlayer.CharacterAdded:Connect(observe))
            table.insert(playerConnections,targetPlayer.CharacterRemoving:Connect(function()clearCharacterConnections();world:ClearAllChildren();waiting.Visible=true end))
            table.insert(playerConnections,targetPlayer:GetAttributeChangedSignal("SpyAppearanceRevision"):Connect(schedule))
            observe(targetPlayer.Character)
        else world:ClearAllChildren();waiting.Visible=true end
    end
    if watchedUserId then
        table.insert(connections,Players.PlayerAdded:Connect(function(nextPlayer)
            if nextPlayer.UserId==watchedUserId then bindTarget(nextPlayer);schedule()end
        end))
        table.insert(connections,Players.PlayerRemoving:Connect(function(leaving)
            if leaving==targetPlayer then bindTarget(nil)end
        end))
    end
    bindTarget(targetPlayer)
    table.insert(connections,host.Destroying:Connect(dispose))
    rebuild()
    return dispose
end
return Presentation
