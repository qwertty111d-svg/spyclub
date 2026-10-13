-- Server-owned, pairwise collision exceptions. The saved doorway stays solid.
-- Avatar collision groups and CanCollide settings are never changed.
local HighStakesGate={Level=3}
HighStakesGate.__index=HighStakesGate

function HighStakesGate.eligible(profile)
    return type(profile)=="table" and profile.ready==true
        and type(profile.level)=="number" and profile.level>=HighStakesGate.Level
end

local function clearCharacter(state)
    for _,connection in ipairs(state.characterConnections) do connection:Disconnect() end
    state.characterConnections={}
    if state.folder then state.folder:Destroy() end
    state.folder,state.character=nil,nil
    state.constraints={}
end

local function addPart(self,state,part)
    if not state.allowed or not part:IsA("BasePart") or state.constraints[part] then return end
    if not state.folder then
        state.folder=Instance.new("Folder")
        state.folder.Name,state.folder.Parent="HighStakesGateAccess",state.character
    end
    local exception=Instance.new("NoCollisionConstraint")
    exception.Name,exception.Enabled="DoorwayAccess",false
    exception.Part0,exception.Part1=self.barrier,part
    state.constraints[part]=exception
    exception.Parent=state.folder
    exception.Enabled=true
end

function HighStakesGate.new(world,profiles)
    local barrier=world and world:FindFirstChild("HighStakesGate")
    assert(barrier and barrier:IsA("BasePart"),"High Stakes requires its baked doorway blocker")
    barrier.Anchored,barrier.CanCollide,barrier.CollisionGroup=true,true,"Default"
    return setmetatable({barrier=barrier,profiles=profiles,players={}},HighStakesGate)
end

function HighStakesGate:refresh(player,profile)
    local state=self.players[player]
    if not state then return end
    if profile==nil then
        local ok,value=pcall(self.profiles.public,self.profiles,player.UserId)
        profile=ok and value or nil
    end
    state.allowed=HighStakesGate.eligible(profile)
    if not state.allowed then
        player:SetAttribute("HighStakesRoomAccess",false)
        if state.folder then state.folder:Destroy();state.folder=nil end
        state.constraints={}
    elseif state.character then
        for _,part in ipairs(state.character:GetDescendants()) do addPart(self,state,part) end
    end
    player:SetAttribute("HighStakesRoomAccess",state.allowed)
end

function HighStakesGate:connectPlayer(player)
    self:removePlayer(player)
    local state={allowed=false,constraints={},connections={},characterConnections={}}
    self.players[player]=state
    player:SetAttribute("HighStakesRoomAccess",false)
    local function onCharacter(character)
        clearCharacter(state)
        state.character=character
        state.characterConnections={
            character.DescendantAdded:Connect(function(part) addPart(self,state,part) end),
            character.DescendantRemoving:Connect(function(part)
                local exception=state.constraints[part]
                if exception then state.constraints[part]=nil;exception:Destroy() end
            end),
        }
        self:refresh(player)
    end
    state.connections={
        player.CharacterAdded:Connect(onCharacter),
        player.CharacterRemoving:Connect(function(character)
            if state.character==character then clearCharacter(state) end
        end),
    }
    if player.Character then onCharacter(player.Character) else self:refresh(player) end
end

function HighStakesGate:removePlayer(player)
    local state=self.players[player]
    if not state then return end
    self.players[player]=nil
    player:SetAttribute("HighStakesRoomAccess",false)
    for _,connection in ipairs(state.connections) do connection:Disconnect() end
    clearCharacter(state)
end

return HighStakesGate
