-- Match-only endpoint. Uses the SAME Profiles instance as round rewards.
local Preferences=require(script and game:GetService("ReplicatedStorage").SpyShared.Preferences or "./Preferences")
local Server={}
function Server.command(kind,value,requestId)
    if type(requestId)~="string" or #requestId<1 or #requestId>64 or not requestId:match("^[%w%-]+$") then return nil end
    if kind=="preferencesSync" and value==nil then return {kind=kind} end
    if kind=="dossierSync" and value==nil then return {kind=kind} end
    if kind=="rollPurchase" and type(value)=="number" and value==value and value>0 and value<math.huge and value%1==0 then
        return {kind=kind,productId=value}
    end
    if kind=="accessoryRoll" and type(value)=="string" and #value>0 and #value<=32 then
        return {kind=kind,category=value,requestId=requestId}
    end
    if kind=="equip" and type(value)=="string" and #value>0 and #value<=64 then return {kind=kind,itemId=value} end
    if kind=="daily" and value==nil then return {kind=kind,now=os.time()} end
    if kind=="settings" then
        local clean=Preferences.sanitize(value)
        if clean then return {kind=kind,settings=clean} end
    elseif kind=="language" and (value=="ru" or value=="en" or value=="zh") then
        return {kind=kind,language=value}
    end
    return nil
end

-- Resolving an old request after a phase change is read-only, never a new roll.
function Server.recover(profile,category,requestId)
    local previous=profile and (profile.rollReceipts or {})[requestId]
    if not previous then return nil end
    if previous.category~=category then return {ok=false,code="roll_request_conflict"} end
    local receipt=table.clone(previous)
    receipt.replayed=true
    return receipt
end

function Server.start(profiles,options)
    if Server.started or not profiles then return end
    Server.started=true
    local Players=game:GetService("Players")
    local shared=game:GetService("ReplicatedStorage"):WaitForChild("SpyShared")
    options=options or {}
    local rolls=require(script.Parent.AccessoryRollService).new(profiles,{hasLuck=options.hasLuck,canRoll=options.canChange,canSpendPaidRolls=options.canSpendPaidRolls})
    local originalPublic=profiles.public
    function profiles:public(userId,...)
        local public=originalPublic(self,userId,...)
        local player=Players:GetPlayerByUserId(userId)
        public.accessoryRoll=player and rolls:snapshot(player,public) or {sequence=public.rollSequence or 0,categories={}}
        public.rollShop=player and options.shopFor and options.shopFor(player,public) or {ready=false,offers={}}
        return public
    end
    local function remote(name)
        local event=shared:FindFirstChild(name)
        if not event then event=Instance.new("RemoteEvent");event.Name=name;event.Parent=shared end
        return event
    end
    local profileEvent=remote("Profile")
    local action=remote("EconomyAction")
    local last,busy,lastReload={},{},{}
    local function restore(player)
        local id=player.UserId
        if profiles.cache[id] or not options.ensureLoaded or profiles.busy[id] or profiles.pending[id]
            or os.clock()-(lastReload[id] or -100)<3 then return end
        lastReload[id]=os.clock()
        busy[id]=true
        local ok,err=pcall(options.ensureLoaded,player)
        busy[id]=nil
        if not ok then warn("SpyClub dossier profile reload: "..tostring(err)) end
    end
    local function respond(player,receipt,requestId)
        if player.Parent~=Players then return end
        local public=profiles:public(player.UserId)
        if public.ready then player:SetAttribute("SpyLanguage",public.language) end
        profileEvent:FireClient(player,public,receipt,requestId)
    end
    action.OnServerEvent:Connect(function(player,kind,value,requestId)
        local command=Server.command(kind,value,requestId)
        if not command then return end
        local id=player.UserId
        local stamp=os.clock()
        if busy[id] or stamp-(last[id] or -10)<0.5 then
            respond(player,{ok=false,code="slowDown"},requestId)
            return
        end
        last[id]=stamp
        if command.kind=="preferencesSync" or command.kind=="dossierSync" then
            restore(player)
            respond(player,{ok=true,code="preferencesSynced"},requestId)
            return
        end
        local characterAction=kind=="accessoryRoll" or kind=="equip" or kind=="daily" or kind=="rollPurchase"
        if characterAction and (not options.canChange or not options.canChange(player)) then
            if kind=="accessoryRoll" then
                restore(player)
                local previous=Server.recover(profiles.cache[id],value,requestId)
                if previous then respond(player,previous,requestId);return end
                if not profiles.cache[id] then respond(player,{ok=false,code="profile_unavailable"},requestId);return end
            end
            respond(player,{ok=false,code="roll_match_active"},requestId)
            return
        end
        if player:GetAttribute("SpyTeleporting") or (not profiles.cache[id] and kind~="accessoryRoll") then
            respond(player,{ok=false,code="profile_unavailable"},requestId)
            return
        end
        busy[id]=true
        local ok,receipt=pcall(function()
            if kind=="rollPurchase" then return options.prompt and options.prompt(player,value) or {ok=false,code="roll_product_unavailable"} end
            if kind=="accessoryRoll" then return rolls:roll(player,value,requestId) end
            if kind=="equip" then
                if not options.canEquip then return {ok=false,code="appearanceLoading"} end
                local ready,code=options.canEquip(player,profiles:public(id),value)
                if not ready then return {ok=false,code=code} end
            end
            if characterAction and not options.canChange(player) then return {ok=false,code="roll_match_active"} end
            return profiles:transact(id,"preferences:"..id..":"..requestId,command)
        end)
        busy[id]=nil
        if ok and receipt.ok and options.onChanged then
            local changedOK,changedError=pcall(options.onChanged,player,receipt)
            if not changedOK then warn("SpyClub dossier appearance: "..tostring(changedError)) end
        end
        respond(player,ok and receipt or {ok=false,code="save_failed"},requestId)
    end)
    Players.PlayerRemoving:Connect(function(player) last[player.UserId]=nil;lastReload[player.UserId]=nil;rolls:remove(player.UserId) end)
end
return Server
