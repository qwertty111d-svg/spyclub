-- Uses the already-running profile instance. Private notes never enter public profile DTOs.
local Service={}
function Service.start(profiles)
 if not profiles then return end
 local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
 local shared=RS:FindFirstChild('SpyShared');if not shared then return end
 local State=require(shared.PhoneState)
 local folder=RS:FindFirstChild('SpyPhonePersonalRemotes')or Instance.new('Folder');folder.Name='SpyPhonePersonalRemotes';folder.Parent=RS
 local request=folder:FindFirstChild('Request')or Instance.new('RemoteFunction');request.Name='Request';request.Parent=folder
 local rates,active={},{ }
 local function current(p)return p and p.Parent==Players and Players:GetPlayerByUserId(p.UserId)==p end
 local function allowed(p)
  if not current(p)or p:GetAttribute('SpyPhoneActive')~=true then return false end
  for _,k in ipairs(State.Blocked)do if p:GetAttribute(k)==true then return false end end
  local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid');return h and h.Health>0
 end
 request.OnServerInvoke=function(player,payload)
  if not allowed(player)then return{ok=false,code='blocked'}end
  if type(payload)~='table'or(payload.action~='read'and payload.action~='save')then return{ok=false,code='note_invalid'}end
  -- There is no target/user ID argument. Roblox's authenticated caller owns the key.
  local id=player.UserId;local now=os.clock();local b=rates[id]
  if not b or now-b.at>=10 then b={at=now,reads=0,saves=0};rates[id]=b end
  local key=payload.action=='read'and'reads'or'saves';b[key]+=1
  if b[key]>(key=='reads'and 8 or 4)then return{ok=false,code='rate'}end
  local private=profiles:phone(id)
  if not private.ready and payload.action=='read'then
   if active[id]or profiles.busy[id]then return{ok=false,code='note_busy'}end
   local lease={};active[id]=lease
   pcall(profiles.load,profiles,id)
   if active[id]==lease then active[id]=nil end
   if not allowed(player)then return{ok=false,code='blocked'}end
   private=profiles:phone(id)
  end
  if not private.ready then return{ok=false,code='note_load_failed'}end
  if payload.action=='read'then private.ok=true;return private end
  local text,revision,nonce=payload.text,payload.revision,payload.nonce
  if type(text)~='string'or #text>16384 or text:find('[%z\1-\8\11\12\14-\31]')or not utf8.len(text)or utf8.len(text)>4096
   or type(revision)~='number'or revision~=revision or revision%1~=0 or revision<0 or revision>1000000000
   or type(nonce)~='string'or #nonce<8 or #nonce>80 or not nonce:match('^[%w_-]+$')then return{ok=false,code='note_invalid'}end
  if active[id]or profiles.busy[id]then return{ok=false,code='note_busy'}end
  local lease={};active[id]=lease
  local ok,receipt=pcall(profiles.transact,profiles,id,'phone-note:'..id..':'..nonce,{kind='phoneNote',text=text,expectedRevision=revision,now=os.time()})
  if active[id]==lease then active[id]=nil end
  if not current(player)then return{ok=false,code='stale'}end
  if not ok or type(receipt)~='table'then return{ok=false,code='note_failed'}end
  if not receipt.ok then return{ok=false,code=receipt.code=='note_conflict'and'note_conflict'or'note_failed'}end
  -- Replays may acknowledge an older successful save; receipt revision identifies that save.
  return{ok=true,noteRevision=receipt.noteRevision,noteSavedAt=receipt.noteSavedAt,studio=private.studio}
 end
 Players.PlayerRemoving:Connect(function(p)rates[p.UserId]=nil;active[p.UserId]=nil end)
 return{request=request}
end
return Service
