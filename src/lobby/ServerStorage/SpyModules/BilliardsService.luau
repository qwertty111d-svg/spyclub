local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Physics=require(script.Parent.BilliardsPhysics)
local Game=require(script.Parent.BilliardsGame)
local Model=require(script.Parent.BilliardsModel)
local Service={}
local profileStore,profileChanged
function Service.attachProfiles(profiles,onChange)profileStore=profiles;profileChanged=onChange end
function Service.start(root)
    if root:GetAttribute("BilliardsReady") then return end
    local model,parts,prompt=Model.build(root,Physics)
    local folder=Storage:FindFirstChild("SpyBilliards")
    if folder and not folder:IsA("Folder") then folder:Destroy();folder=nil end
    if not folder then folder=Instance.new("Folder");folder.Name="SpyBilliards";folder.Parent=Storage end
    local function remote(name)
        local r=folder:FindFirstChild(name)
        if r and not r:IsA("RemoteEvent") then r:Destroy();r=nil end
        if not r then r=Instance.new("RemoteEvent");r.Name=name;r.Parent=folder end
        return r
    end
    local action,state=remote("Action"),remote("State")
    -- Existing pure server module is also used for this viewer's bounded visual motion.
    local visualPhysics=folder:FindFirstChild("VisualPhysics")
    if visualPhysics and not visualPhysics:IsA("ModuleScript")then visualPhysics:Destroy();visualPhysics=nil end
    if not visualPhysics then visualPhysics=script.Parent.BilliardsPhysics:Clone();visualPhysics.Name="VisualPhysics";visualPhysics.Parent=folder end
    local match=Game.new();local viewers={};local nextRateNotice={};local serial=0
    local accumulator,sendRemainder,checkRemainder=0,0,0
    local runPrefix=game:GetService("HttpService"):GenerateGUID(false)
    local recordedRack,clubResults=nil,{}
    local boardCache,boardAt={scope="current_club",entries={}},-math.huge
    local clubBest={}
    local function leaderboard()
        if os.clock()<boardAt+1 then return boardCache end
        boardAt=os.clock();local entries={};clubBest={}
        for _,p in ipairs(Players:GetPlayers())do
            local best=clubResults[p.UserId]
            if profileStore and type(profileStore.public)=="function"then
                local ok,dto=pcall(function()return profileStore:public(p.UserId)end)
                if ok and dto and dto.ready and dto.billiards and((dto.billiards.attempts or 0)>0 or(dto.billiards.bestScore or 0)>0)then best=math.max(best or 0,dto.billiards.bestScore or 0)end
            end
            if best~=nil then clubBest[p.UserId]=best;table.insert(entries,{id=p.UserId,name=p.DisplayName,score=best})end
        end
        table.sort(entries,function(a,b)return a.score==b.score and a.id<b.id or a.score>b.score end)
        while #entries>20 do table.remove(entries)end
        boardCache={scope="current_club",entries=entries};return boardCache
    end
    local function recordCompletion()
        local c=match.challenge
        if not c or not c.complete or match.phase~="finished"or c.shots~=5 then return end
        local uid=match.winner;local rack=runPrefix.."_"..match.rackId
        if recordedRack==rack then return end
        recordedRack=rack;clubResults[uid]=math.max(clubResults[uid]or 0,c.score);boardAt=-math.huge
        if not profileStore then return end
        local command={kind="billiardsRecord",score=c.score,shots=5,potted=c.potted,rackId=rack,now=os.time()}
        local operation="billiards:"..rack..":"..uid;local attempts=0
        local function attempt()
            local p=Players:GetPlayerByUserId(uid)
            if not p or p.Parent~=Players then return end
            attempts+=1
            local ok,receipt=pcall(function()
                local dto=profileStore:public(uid)
                if not dto.ready and type(profileStore.load)=="function"then profileStore:load(uid)end
                return profileStore:transact(uid,operation,command)
            end)
            if ok and receipt and receipt.ok then
                boardAt=-math.huge
                if profileChanged then pcall(profileChanged,p,receipt)end
                local feed=game:GetService("ServerStorage"):FindFirstChild("SpyClubActivity")
                if feed and feed:IsA("BindableEvent")then
                    pcall(function()feed:Fire({id=operation,kind="billiards",userId=uid,at=workspace:GetServerTimeNow(),score=command.score})end)
                end
            elseif attempts<3 then task.delay(attempts,attempt)end
        end
        task.spawn(attempt)
    end
    local function now()return workspace:GetServerTimeNow()end
    local function near(player)
        local character=player.Character
        local hrp=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid or humanoid.Health<=0 then return false end
        local p=hrp.Position;local c=Model.CENTER
        return Physics.finite(p.X) and Physics.finite(p.Y) and Physics.finite(p.Z)
            and (p.X-c.X)^2+(p.Z-c.Z)^2<=(12*Model.WORLD_SCALE)^2 and math.abs(p.Y-3)<8
    end
    local function available(player)
        return player.Parent==Players and not player:GetAttribute("SpyTeleporting") and not player:GetAttribute("SpyReconnectBusy")
            and not (player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").SeatPart)
    end
    local function worldSnapshot()
        local data=match:snapshot(now())
        data.clubLeaderboard=leaderboard();data.center=Model.CENTER;data.height=Model.heightFor(match.mode);data.scale=Model.WORLD_SCALE
        data.halfX=Physics.HALF_X;data.halfZ=Physics.HALF_Z;data.radius=match:parameters().RADIUS;data.pocketRadius=match:parameters().POCKET_RADIUS;data.cornerPocketRadius=match:parameters().CORNER_RADIUS;data.tipLimit=Physics.TIP_LIMIT;data.fallSeconds=Physics.FALL_SECONDS
        return data
    end
    local function send(player,ok,code,open,shared,shotRequestId)
        if player.Parent~=Players then return end
        serial+=1;local data=table.clone(shared or worldSnapshot())
        local owner=match.challenge and match.players[1]and match.players[1].id or player.UserId
        data.personalBest=clubBest[owner]or clubResults[owner]or 0
        data.sequence=serial;data.ok=ok;data.code=code;data.open=open==true;data.ackShotRequestId=shotRequestId
        state:FireClient(player,data)
    end
    local visualCache,visualConnections={},{}
    local function cacheBall(id,part)
        local record={part=part,parts={part},surfaces={}};visualCache[id]=record
        for _,object in ipairs(part:GetDescendants())do
            if object:IsA("BasePart")then table.insert(record.parts,object)
            elseif object:IsA("SurfaceGui")then table.insert(record.surfaces,object)end
        end
    end
    local function cacheVisuals()
        for _,connection in ipairs(visualConnections)do connection:Disconnect()end
        visualConnections={};visualCache={}
        for id,part in pairs(parts)do
            cacheBall(id,part)
            table.insert(visualConnections,part.DescendantAdded:Connect(function()cacheBall(id,part)end))
        end
    end
    cacheVisuals()
    local function visuals()
        if model:GetAttribute("Mode")~=match.mode then parts=Model.applyMode(model,Physics,match.mode);cacheVisuals()end
        for _,b in ipairs(match.balls) do
            local p=parts[b.id]
            local hidden=b.pocketed and(not b.fallT or b.fallT>=Physics.FALL_SECONDS)
            local record=visualCache[b.id]
            if not record or record.part~=p then cacheBall(b.id,p);record=visualCache[b.id]end
            if record.hidden~=hidden then
                record.hidden=hidden
                for _,part in ipairs(record.parts)do part.Transparency=hidden and 1 or 0 end
                for _,surface in ipairs(record.surfaces)do surface.Enabled=not hidden end
            end
            -- Static balls require no replicated transform write during aiming.
            if record.x~=b.x or record.z~=b.z or record.fallT~=b.fallT or record.qx~=b.qx or record.qy~=b.qy or record.qz~=b.qz or record.qw~=b.qw then
                p.CFrame=Model.pose(b,Model.heightFor(match.mode))
                record.x,record.z,record.fallT=b.x,b.z,b.fallT
                record.qx,record.qy,record.qz,record.qw=b.qx,b.qy,b.qz,b.qw
            end
        end
        model:SetAttribute("Phase",match.phase);model:SetAttribute("Players",#match.players)
    end
    local function publish()
        local shared
        for uid,p in pairs(viewers)do
            if p.Parent~=Players then viewers[uid]=nil
            elseif near(p) or match:member(uid) then
                shared=shared or worldSnapshot();send(p,true,"state",false,shared)
            else send(p,false,"too_far",false);viewers[uid]=nil end
        end
    end
    local function remove(player,reason)
        if match:leave(player.UserId,now()) then
            player:SetAttribute("SpyBilliardsPlaying",false);visuals();publish()
        end
        if viewers[player.UserId] then send(player,false,reason or "left",false) end
        viewers[player.UserId]=nil;nextRateNotice[player.UserId]=nil
    end
    prompt.Triggered:Connect(function(player)
        if not near(player) or not available(player) then return end
        local uid=player.UserId
        viewers[uid]=player
        send(player,true,"open",true)
    end)
    action.OnServerEvent:Connect(function(player,payload)
        if type(payload)~="table" then return end
        local uid=player.UserId
        -- Only table visitors can use the transport; opening still requires proximity.
        if not viewers[uid] then
            if payload.action~="sync" or not near(player) or not available(player) then return end
            viewers[uid]=player
        end
        recordCompletion()
        local candidate=match.joinOffer and Players:GetPlayerByUserId(match.joinOffer.id)
        local candidateAvailable=candidate and candidate.Parent==Players and near(candidate)and available(candidate)
        local ok,code=match:request(uid,player.DisplayName,payload,now(),near(player),available(player),candidateAvailable==true)
        local shotId=payload.action=="shot"and type(payload.shotRequestId)=="number"and payload.shotRequestId or nil
        if code=="rate_limited"then
            -- Reply only to actual seated shooters, at most once per second.
            if payload.action=="shot"and match:member(uid)and(now()>=(nextRateNotice[uid]or -math.huge))then
                nextRateNotice[uid]=now()+1;send(player,false,code,false,nil,shotId)
            end
            return
        end
        -- Aim has its own limiter and publishes at Heartbeat cadence, not per packet.
        if payload.action=="aim"then return end
        player:SetAttribute("SpyBilliardsPlaying",match:member(uid)~=nil)
        if ok and code=="joined"then
            for _,member in ipairs(match.players)do local p=Players:GetPlayerByUserId(member.id);if p then p:SetAttribute("SpyBilliardsPlaying",true)end end
        end
        if ok and payload.action~="sync"then visuals()end
        send(player,ok,code,false,nil,shotId)
        if ok and payload.action~="sync"then publish()end
        if payload.action=="leave"then viewers[uid]=nil;nextRateNotice[uid]=nil end
    end)
    local function watch(player)
        player:GetAttributeChangedSignal("SpyTeleporting"):Connect(function()if player:GetAttribute("SpyTeleporting") then remove(player,"unavailable") end end)
        player:GetAttributeChangedSignal("SpyReconnectBusy"):Connect(function()if player:GetAttribute("SpyReconnectBusy") then remove(player,"unavailable") end end)
        player.CharacterRemoving:Connect(function()remove(player,"unavailable")end)
    end
    for _,player in ipairs(Players:GetPlayers())do watch(player)end
    Players.PlayerAdded:Connect(watch)
    Players.PlayerRemoving:Connect(function(player)remove(player,"left");match:forget(player.UserId)end)
    RunService.Heartbeat:Connect(function(dt)
        if not Physics.finite(dt) or dt<=0 then return end
        -- A slow server catches up at most 0.25s; no unbounded simulation backlog.
        accumulator+=math.min(dt,.25);sendRemainder+=dt;checkRemainder+=dt
        local changed=false
        while accumulator>=Physics.DT do changed=match:step(now()) or changed;accumulator-=Physics.DT end
        if checkRemainder>=.5 then
            checkRemainder=0
            local offer=match.joinOffer
            if offer then
                local p=Players:GetPlayerByUserId(offer.id)
                if not p or not near(p)or not available(p)then changed=match:clearJoin(now(),"join_expired")or changed end
            end
            local ids={};for _,p in ipairs(match.players)do table.insert(ids,p.id)end
            for _,uid in ipairs(ids)do
                local player=Players:GetPlayerByUserId(uid)
                if not player then match:leave(uid,now());changed=true
                elseif not near(player) or not available(player) then remove(player,"unavailable");changed=true end
            end
        end
        recordCompletion()
        if changed or sendRemainder>=1/15 then
            sendRemainder=0;visuals()
            if changed or match.phase=="moving" or match.phase=="aiming" then publish() end
        end
    end)
    folder:SetAttribute("Ready",true);root:SetAttribute("BilliardsReady",true);visuals()
    return {match=match,model=model,action=action,state=state}
end
return Service
