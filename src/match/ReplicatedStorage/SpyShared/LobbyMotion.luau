-- Local decorative motion only. The server owns the independent solid gate.
local RunService=game:GetService("RunService")
local LobbyMotion={}
function LobbyMotion.start(player,getProfile)
    local self={}
    local cases,doors={},{}
    local elapsed,scanAt=0,-1
    local doorOpen=0
    local shoulder,shoulderBase
    local function bind(model,records)
        if not model or not model:IsA("Model") then return end
        local pivot=model.PrimaryPart
        if not pivot or pivot.Name~="Pivot" then return end
        if not records[model] then records[model]={base=model:GetPivot()} end
    end
    local function scan()
        local club=workspace:FindFirstChild("SpyClub")
        local shelf=club and club:FindFirstChild("FeaturedCases")
        if shelf then for _,model in ipairs(shelf:GetChildren()) do
            if model:GetAttribute("CaseId") then bind(model,cases) end
        end end
        if club then
            bind(club:FindFirstChild("HighStakesDoorLeft"),doors)
            bind(club:FindFirstChild("HighStakesDoorRight"),doors)
            local bartender=club:FindFirstChild("Bartender")
            local torso=bartender and bartender:FindFirstChild("Torso")
            local candidate=torso and torso:FindFirstChild("Right Shoulder")
            if candidate and candidate:IsA("Motor6D") and candidate~=shoulder then
                if shoulder and shoulder.Parent then shoulder.C0=shoulderBase end
                shoulder,shoulderBase=candidate,candidate.C0
            end
        end
        for model in pairs(cases) do if not model:IsDescendantOf(workspace) then cases[model]=nil end end
        for model in pairs(doors) do if not model:IsDescendantOf(workspace) then doors[model]=nil end end
    end
    local connection=RunService.RenderStepped:Connect(function(dt)
        elapsed=elapsed+dt
        if elapsed>=scanAt then scan(); scanAt=elapsed+1 end
        if shoulder and shoulder.Parent then
            shoulder.C0=shoulderBase*CFrame.Angles(math.rad(4)*math.sin(elapsed*.8),0,math.rad(2)*math.sin(elapsed*.55))
        end
        for model,record in pairs(cases) do
            if model.Parent and model.PrimaryPart then
                local amplitude=tonumber(model:GetAttribute("FloatAmplitude")) or .14
                local speed=tonumber(model:GetAttribute("SpinSpeed")) or 8
                -- Apply absolute transforms from the captured base; never accumulate drift.
                model:PivotTo(record.base*CFrame.new(0,math.sin(elapsed*1.35)*amplitude,0)*CFrame.Angles(0,math.rad(speed)*elapsed,0))
            end
        end
        local center,count=Vector3.new(),0
        for _,record in pairs(doors) do center=center+record.base.Position; count=count+1 end
        local profile=getProfile()
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local nearby=count>0 and root and (root.Position-center*(1/count)).Magnitude<=12
        local eligible=profile and profile.ready==true and (profile.level or 1)>=3
        local target=eligible and nearby and 1 or 0
        doorOpen=doorOpen+(target-doorOpen)*(1-math.exp(-dt*7))
        for model,record in pairs(doors) do
            if model.Parent and model.PrimaryPart then
                local angle=tonumber(model:GetAttribute("OpenAngleDegrees")) or (model.Name=="HighStakesDoorLeft" and 88 or -88)
                model:PivotTo(record.base*CFrame.Angles(0,math.rad(angle)*doorOpen,0))
            end
        end
    end)
    function self:Destroy()
        connection:Disconnect()
        if shoulder and shoulder.Parent then shoulder.C0=shoulderBase end
        for _,records in ipairs({cases,doors}) do
            for model,record in pairs(records) do if model.Parent then model:PivotTo(record.base) end end
        end
        cases={}; doors={}
    end
    return self
end
return LobbyMotion
