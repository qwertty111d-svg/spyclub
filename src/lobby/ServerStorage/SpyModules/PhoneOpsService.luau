-- Optional adapter reuses the caller's existing Profiles instance. No boot lease or DataStore.
local Service={}
function Service.start(profiles,onChanged)
 local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Http=game:GetService('HttpService')
 local shared=RS:WaitForChild('SpyShared',8);if not shared then return end
 local Files=require(shared.PhoneOpsFiles);local Core=require(shared.PhoneOpsCore);local World=require(shared.PhoneOpsWorld);local State=require(shared.PhoneState)
 local random=Random.new();local system=Core.new(Files,function(id,key,command)return profiles:transact(id,key,command)end,function()return Http:GenerateGUID(false)end,function(a,b)return random:NextInteger(a,b)end)
 local folder=RS:FindFirstChild('SpyPhoneOpsRemotes')or Instance.new('Folder');folder.Name='SpyPhoneOpsRemotes';folder.Parent=RS
 local request=folder:FindFirstChild('Request')or Instance.new('RemoteFunction');request.Name='Request';request.Parent=folder
 local world,rate,recovering=nil,{},{}
 local function current(p)return p.Parent==Players and Players:GetPlayerByUserId(p.UserId)==p end
 request.OnServerInvoke=function(player,p)
  if not current(player)then return{ok=false,code='stale'}end
  local id=player.UserId;local now=os.clock();local bucket=rate[id]
  if not bucket or now-bucket.at>2 then bucket={at=now,n=0};rate[id]=bucket end
  bucket.n+=1;if bucket.n>12 then return{ok=false,code='busy'}end
  local profile=profiles:public(id)
  if not profile.ready then
   if recovering[id]then return{ok=false,code='busy'}end
   local lease={};recovering[id]=lease;task.delay(8,function()if recovering[id]==lease then recovering[id]=nil end end)
   pcall(profiles.load,profiles,id);if recovering[id]==lease then recovering[id]=nil end
   if not current(player)then return{ok=false,code='stale'}end;profile=profiles:public(id)
   if not profile.ready then return{ok=false,code='save_failed'}end
  end
  if not world then world=World.build(workspace:FindFirstChild('SpyClub'))end
  local char=player.Character;local h=char and char:FindFirstChildOfClass('Humanoid');local blocked=false
  for _,key in ipairs(State.Blocked)do if player:GetAttribute(key)==true then blocked=true end end
  local ctx={alive=h and h.Health>0,blocked=blocked,phone=player:GetAttribute('SpyPhoneActive')==true}
  local active=system.sessions[id]
  if type(p)=='table'and p.action=='capture'and active and p.token==active.token and active.phase=='search'and p.target==active.id then ctx.proof=world and world:capture(player,p,active.id)==true end
  if type(p)=='table'and p.action=='dial'and not world then return{ok=false,code='unavailable'}end
  local result=system:handle(id,p,ctx,player:GetAttribute('SpyLanguage')or profile.language or'ru')
  if not current(player)then return{ok=false,code='stale'}end
  if result.ok and result.phase=='done'and type(p)=='table'and p.action=='resolve'and onChanged then task.defer(function()if current(player)then pcall(onChanged,player)end end)end
  local public=profiles:public(id);result.completed=public.club and public.club.caseFiles and public.club.caseFiles.completed or{}
  return result
 end
 world=World.build(workspace:FindFirstChild('SpyClub'))
 Players.PlayerRemoving:Connect(function(p)system:remove(p.UserId);rate[p.UserId]=nil;recovering[p.UserId]=nil end)
 return system
end
return Service
