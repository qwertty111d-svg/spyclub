-- Cosmetic replication adapter. Only the owning Player may change its own device.
local Service={}
function Service.start()
 local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
 local shared=RS:WaitForChild('SpyShared',8);if not shared then return end
 local State=require(shared.PhoneState);local Hardware=require(shared.PhoneModel)
 local core=State.new(function()return workspace:GetServerTimeNow()end)
 local folder=RS:FindFirstChild('SpyPhoneRemotes')or Instance.new('Folder');folder.Name='SpyPhoneRemotes';folder.Parent=RS
 local request=Instance.new('RemoteEvent');request.Name='Request';request.Parent=folder
 local ack=Instance.new('RemoteEvent');ack.Name='State';ack.Parent=folder
 local models,watches,deaths,lightAt={},{},{},{}
 local function flash(player,root,value)
  local lamp=root and root:FindFirstChild('PhoneFlash',true);if lamp then lamp.Enabled=value end
  local led=root and root:FindFirstChild('FlashLED',true);if led then led.Material=value and Enum.Material.Neon or Enum.Material.Metal end
  player:SetAttribute('SpyPhoneFlash',value)
  if player.Character then player.Character:SetAttribute('SpyPhoneFlash',value)end
 end
 local function close(player)
  flash(player,models[player],false)
  core:close(player.UserId);player:SetAttribute('SpyPhoneActive',false)
  local c=player.Character;if c then c:SetAttribute('SpyPhoneActive',false);c:SetAttribute('SpyPhoneAt',workspace:GetServerTimeNow())end
  if models[player]then models[player]:Destroy();models[player]=nil end
 end
 local function context(player)
  local c=player.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local blocked=false
  for _,key in ipairs(State.Blocked)do if player:GetAttribute(key)==true then blocked=true end end
  return{blocked=blocked,alive=h and h.Health>0,hasHand=c and Hardware.hand(c)~=nil}
 end
 request.OnServerEvent:Connect(function(player,p)
  if player.Parent~=Players or Players:GetPlayerByUserId(player.UserId)~=player then return end
  if type(p)=='table'and type(p.light)=='boolean'then
   flash(player,models[player],false)
   local session=core.sessions[player.UserId]
   if session then ack:FireClient(player,{seq=session.seq,open=session.open,flash=false,code='removed'})end
   return
  end
  local before=core.sessions[player.UserId];local was=before and before.open
  local result=core:request(player.UserId,p,context(player));local character=player.Character
  if character and result.open~=was then
   if result.open then
    flash(player,nil,false)
    local good,root=pcall(Hardware.create,character)
    if not good or not root then result.open=false;result.code='unavailable';core.sessions[player.UserId].open=false
    else models[player]=root;Hardware.visible(root,false)
     task.delay(.24,function()if models[player]==root and player:GetAttribute('SpyPhoneActive')then Hardware.visible(root,true)end end)
    end
   else
    flash(player,models[player],false)
    local root=models[player]
    task.delay(.42,function()if models[player]==root and not player:GetAttribute('SpyPhoneActive')then if root then root:Destroy()end;models[player]=nil end end)
   end
   character:SetAttribute('SpyPhoneAt',result.at);character:SetAttribute('SpyPhoneActive',result.open)
  end
  player:SetAttribute('SpyPhoneActive',result.open);ack:FireClient(player,result)
 end)
 local function watch(p)
  p:SetAttribute('SpyPhoneFlash',false)
  p:SetAttribute('SpyPhoneNumber',State.number(p.UserId))
  local list={};watches[p]=list
  list[#list+1]=p.CharacterRemoving:Connect(function()close(p)end)
  list[#list+1]=p.CharacterAdded:Connect(function(c)
   close(p);if deaths[p]then deaths[p]:Disconnect();deaths[p]=nil end;local h=c:WaitForChild('Humanoid',5)
   if h and p.Character==c then deaths[p]=h.Died:Connect(function()close(p)end)end
  end)
  if p.Character then local h=p.Character:FindFirstChildOfClass('Humanoid');if h then deaths[p]=h.Died:Connect(function()close(p)end)end end
  for _,key in ipairs(State.Blocked)do list[#list+1]=p:GetAttributeChangedSignal(key):Connect(function()if p:GetAttribute(key)then close(p)end end)end
 end
 for _,p in ipairs(Players:GetPlayers())do watch(p)end
 Players.PlayerAdded:Connect(watch);Players.PlayerRemoving:Connect(function(p)close(p);core:remove(p.UserId);lightAt[p]=nil;if deaths[p]then deaths[p]:Disconnect();deaths[p]=nil end;for _,c in ipairs(watches[p]or{})do c:Disconnect()end;watches[p]=nil end)
 return core
end
return Service
