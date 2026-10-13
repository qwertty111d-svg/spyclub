-- Match-only endpoint. Uses the SAME Profiles instance as round rewards.
local Preferences=require(script and game:GetService("ReplicatedStorage").SpyShared.Preferences or "./Preferences")
local Server={}
function Server.command(kind,value,requestId)
    if type(requestId)~="string" or #requestId<1 or #requestId>64 or not requestId:match("^[%w%-]+$") then return nil end
    if kind=="preferencesSync" and value==nil then return {kind=kind} end
    if kind=="settings" then
        local clean=Preferences.sanitize(value)
        if clean then return {kind=kind,settings=clean} end
    elseif kind=="language" and (value=="ru" or value=="en" or value=="zh") then
        return {kind=kind,language=value}
    end
    return nil
end

function Server.start(profiles)
    if Server.started or not profiles then return end
    Server.started=true
    local Players=game:GetService("Players")
    local shared=game:GetService("ReplicatedStorage"):WaitForChild("SpyShared")
    local function remote(name)
        local event=shared:FindFirstChild(name)
        if not event then event=Instance.new("RemoteEvent");event.Name=name;event.Parent=shared end
        return event
    end
    local profileEvent=remote("Profile")
    local action=remote("EconomyAction")
    local last,busy={},{}
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
        if command.kind=="preferencesSync" then
            respond(player,{ok=true,code="preferencesSynced"},requestId)
            return
        end
        if player:GetAttribute("SpyTeleporting") or not profiles.cache[id] then
            respond(player,{ok=false,code="profile_unavailable"},requestId)
            return
        end
        busy[id]=true
        local ok,receipt=pcall(function()
            return profiles:transact(id,"preferences:"..id..":"..requestId,command)
        end)
        busy[id]=nil
        respond(player,ok and receipt or {ok=false,code="save_failed"},requestId)
    end)
    Players.PlayerRemoving:Connect(function(player) last[player.UserId]=nil end)
end
return Server
