-- Addressed SMS uses the same server filter as SpyChatRelay. Game chat stays untouched.
local Service={}
function Service.attachProfiles(profiles)Service.profiles=profiles end
function Service.start()
 local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
 local Text=game:GetService('TextChatService');local Filter=game:GetService('TextService');local Http=game:GetService('HttpService')
 local shared=RS:FindFirstChild('SpyShared');if not shared then return end
 local Core=require(shared.PhoneCommsCore);local State=require(shared.PhoneState)
 local folder=RS:FindFirstChild('SpyPhoneComms')or Instance.new('Folder');folder.Name='SpyPhoneComms';folder.Parent=RS
 local request=Instance.new('RemoteFunction');request.Name='Request';request.Parent=folder
 local event=Instance.new('RemoteEvent');event.Name='Event';event.Parent=folder
 folder:SetAttribute('SmsTransport','server_filtered')
 local self={serials={},rates={},messages={},connections={},voice={},smsInFlight={},closed=false}
 local modules=game:GetService('ServerStorage'):FindFirstChild('SpyModules');local linkModule=modules and modules:FindFirstChild('ClubLinkService')
 if linkModule then
  local ok,value=pcall(function()return require(linkModule).new(State)end)
  if ok then self.link=value else warn('[SpyClubLink] '..tostring(value))end
 end
 local function clock()return workspace:GetServerTimeNow()end
 local function current(p)return p and p.Parent==Players and Players:GetPlayerByUserId(p.UserId)==p end
 local function alive(p)
  local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid');if not h or h.Health<=0 or p:GetAttribute('SpyAdminMuted')==true then return false end
  for _,key in ipairs(State.Blocked)do if p:GetAttribute(key)==true then return false end end
  return true
 end
 local club={invites={},plans={},events={},seen={},serials={},inviteAt={},planAt={}}
 local function partyFor(p)
  local bridge=game:GetService('ServerStorage'):FindFirstChild('SpyClubPartyBridge')
  if not bridge or not bridge:IsA('BindableFunction')then return nil end
  local ok,value=pcall(function()return bridge:Invoke(p,'get')end)
  return ok and type(value)=='table'and value or nil
 end
 local function activity(data)
  if type(data)~='table'or(data.kind~='billiards'and data.kind~='match')or type(data.id)~='string'or #data.id>100 or club.seen[data.id]then return end
  if type(data.userId)~='number'or data.userId%1~=0 or not current(Players:GetPlayerByUserId(data.userId))then return end
  local at=data.at;if type(at)~='number'or at~=at or at<clock()-604800 or at>clock()+5 then return end
  local value={id=data.id,kind=data.kind,userId=data.userId,at=at}
  if data.kind=='match'then if type(data.won)~='boolean'then return end;value.won=data.won
  else if type(data.score)~='number'or data.score%1~=0 or data.score<0 or data.score>50 then return end;value.score=data.score end
  club.seen[data.id]=true;table.insert(club.events,value)
  if #club.events>24 then local old=table.remove(club.events,1);club.seen[old.id]=nil end
 end
 local activityEvent=game:GetService('ServerStorage'):FindFirstChild('SpyClubActivity')
 if not activityEvent then activityEvent=Instance.new('BindableEvent');activityEvent.Name='SpyClubActivity';activityEvent.Parent=game:GetService('ServerStorage')end
 if activityEvent:IsA('BindableEvent')then self.connections[#self.connections+1]=activityEvent.Event:Connect(activity)end
 local function clubSnapshot(p)
  local now=clock();local peers,invites,plans,results={},{},{},{}
  for _,other in ipairs(Players:GetPlayers())do if current(other)then
   if other~=p and #peers<64 then table.insert(peers,{id=other.UserId,name=other.DisplayName,busy=not alive(other)})end
   local cache=Service.profiles and Service.profiles.cache;local profile=cache and cache[other.UserId]
   local h=profile and type(profile.history)=='table'and profile.history[1]
   if type(h)=='table'and type(h.at)=='number'and type(h.spyId)=='number'and type(h.caught)=='boolean'then
    activity({id='match:'..h.at..':'..h.spyId..':'..other.UserId,kind='match',userId=other.UserId,at=h.at,won=(other.UserId==h.spyId)==not h.caught})
   end
  end end
  for id,inv in pairs(club.invites)do
   local from=Players:GetPlayerByUserId(inv.from);local to=Players:GetPlayerByUserId(inv.to)
   if inv.expires<=now or not current(from)or not current(to)then club.invites[id]=nil
   elseif inv.to==p.UserId then table.insert(invites,{id=id,from=inv.from,name=from.DisplayName,partyId=inv.partyId,expires=inv.expires})end
  end
  for id,plan in pairs(club.plans)do
   local host=Players:GetPlayerByUserId(plan.owner)
   if not current(host)or now>plan.at+600 then club.plans[id]=nil
   else
    local count=0;for uid in pairs(plan.attendees)do if current(Players:GetPlayerByUserId(uid))then count+=1 else plan.attendees[uid]=nil end end
    table.insert(plans,{id=id,owner=plan.owner,name=host.DisplayName,kind=plan.kind,at=plan.at,count=count,joined=plan.attendees[p.UserId]==true})
   end
  end
  table.sort(plans,function(a,b)return a.at<b.at end)
  for _,r in ipairs(club.events)do
   local actor=Players:GetPlayerByUserId(r.userId)
   if current(actor)then local copy=table.clone(r);copy.name=actor.DisplayName;table.insert(results,copy)end
  end
  table.sort(results,function(a,b)return a.at>b.at end)
  club.serials[p.UserId]=(club.serials[p.UserId]or 0)+1
  return{revision=club.serials[p.UserId],now=now,party=partyFor(p),peers=peers,invites=invites,plans=plans,results=results}
 end
 local function clubPush(p)if current(p)then event:FireClient(p,{kind='club',data=clubSnapshot(p)})end end
 local function clubRequest(p,payload,valid)
  local function fail(code)return{ok=false,code=code}end
  if game.PlaceId==135927279331761 or payload.text~=nil then return fail('invalid')end
  local a=payload.action;local now=clock()
  if a=='club_invite'then
   local target=payload.target;local other=type(target)=='number'and target%1==0 and Players:GetPlayerByUserId(target)
   if not current(other)or other==p or not alive(other)then return fail('left')end
   local party=partyFor(p)
   if not valid()or not party or party.locked or party.count>=party.capacity then return fail('club_no_table')end
   local key=p.UserId..':'..target;if now-(club.inviteAt[key]or-math.huge)<5 then return fail('rate')end
   club.inviteAt[key]=now
   for id,inv in pairs(club.invites)do if inv.from==p.UserId and inv.to==target then club.invites[id]=nil end end
   local id=Http:GenerateGUID(false);club.invites[id]={from=p.UserId,to=target,partyId=party.id,expires=now+60}
   clubPush(other)
  elseif a=='club_accept'or a=='club_decline'then
   local id=payload.id;local inv=type(id)=='string'and club.invites[id]
   if not inv or inv.to~=p.UserId or inv.expires<=now then return fail('club_expired')end
   if a=='club_decline'then club.invites[id]=nil
   else
    local from=Players:GetPlayerByUserId(inv.from);local party=current(from)and partyFor(from)
    if not valid()or not party or party.id~=inv.partyId or party.locked then club.invites[id]=nil;return fail('club_expired')end
    local bridge=game:GetService('ServerStorage'):FindFirstChild('SpyClubPartyBridge')
    local ok,r=pcall(function()return bridge:Invoke(p,'join',inv.partyId)end)
    if not ok or type(r)~='table'or not r.ok then return fail(type(r)=='table'and r.code or'club_expired')end
    club.invites[id]=nil
   end
  elseif a=='club_plan'then
   local kind,delay=payload.kind,payload.delay
   if(kind~='billiards'and kind~='checkers'and kind~='spy')or(delay~=300 and delay~=900 and delay~=1800)then return fail('invalid')end
   if now-(club.planAt[p.UserId]or-math.huge)<15 then return fail('rate')end
   local count=0;for id,plan in pairs(club.plans)do count+=1;if plan.owner==p.UserId then club.plans[id]=nil;count-=1 end end
   if count>=24 then return fail('busy')end
   club.planAt[p.UserId]=now;local id=Http:GenerateGUID(false)
   club.plans[id]={owner=p.UserId,kind=kind,at=now+delay,attendees={[p.UserId]=true}}
   for _,other in ipairs(Players:GetPlayers())do if other~=p then clubPush(other)end end
  elseif a=='club_rsvp'or a=='club_cancel_plan'then
   local plan=type(payload.id)=='string'and club.plans[payload.id]
   if not plan or not current(Players:GetPlayerByUserId(plan.owner))or now>plan.at+600 then return fail('club_expired')end
   if a=='club_cancel_plan'then if plan.owner~=p.UserId then return fail('invalid')end;club.plans[payload.id]=nil
   else plan.attendees[p.UserId]=not plan.attendees[p.UserId]or nil end
  elseif a~='club_snapshot'then return fail('invalid')end
  if not valid()then return fail('stale')end
  return{ok=true,club=clubSnapshot(p)}
 end
 local function stopVoice(token)
  local v=self.voice[token];self.voice[token]=nil;if v then v:destroy()end
 end
 local core
 core=Core.new(clock,function()return Http:GenerateGUID(false)end,function(id,d)
  if d.phase=='idle'then for token,v in pairs(self.voice)do if v.from==id or v.to==id then stopVoice(token)end end end
  local p=Players:GetPlayerByUserId(id);if current(p)then event:FireClient(p,{kind='call',call=d})end
 end);self.core=core
 local function permission(a,b,valid,full)
  local function query()
   return pcall(function()
   -- Call and voice permission gates are unchanged.
   if full then
    if not Text:CanUserChatAsync(a.UserId)or not valid()then return{}end
    if not Text:CanUserChatAsync(b.UserId)or not valid()then return{}end
    if not Text:CanUsersChatAsync(a.UserId,b.UserId)or not valid()then return{}end
    if not Text:CanUsersChatAsync(b.UserId,a.UserId)or not valid()then return{}end
   end
   local allowed=Text:CanUsersDirectChatAsync(a.UserId,{b.UserId})
   if full and type(allowed)=='table'and table.find(allowed,b.UserId)then
    if not valid()then return{}end
    local reverse=Text:CanUsersDirectChatAsync(b.UserId,{a.UserId})
    if type(reverse)~='table'then return nil end
    if not table.find(reverse,a.UserId)then return{}end
   end
   return allowed
  end)
  end
  local ok,permitted=query()
  if (not ok or type(permitted)~='table')and valid()then
   if valid()then ok,permitted=query()end
  end
  if not valid()then return false,'timeout'end
  if not ok or type(permitted)~='table'then
   warn('[SpyPhoneDM] stage=permission_api code=permission_unavailable')
   return false,'permission_unavailable'
  end
  if not table.find(permitted,b.UserId)then
   local code=full and'privacy'or'dm_restricted'
   warn('[SpyPhoneDM] stage=permission_api code='..code..' requester='..a.UserId..' recipient='..b.UserId)
   return false,code
  end
  return true
 end
 local function voice(token)
  local c=core.calls[token];if not c or c.phase~='active'then return end
  local a,b=Players:GetPlayerByUserId(c.from),Players:GetPlayerByUserId(c.to);local deadline=clock()+8
  local function valid()return not self.closed and core.calls[token]==c and c.phase=='active'and clock()<deadline and current(a)and current(b)and alive(a)and alive(b)end
  local modules=game:GetService('ServerStorage'):FindFirstChild('SpyModules');local m=modules and modules:FindFirstChild('PhoneVoice')
  if not m then core:voice(token,false,'unavailable');return end
  -- An unavailable/slow voice API must not leave the call saying it is connecting.
  task.delay(8,function()if core.calls[token]==c and c.phase=='active'and not self.voice[token]then core:voice(token,false,'unavailable')end end)
  local ok,v=pcall(function()return require(m).start(a,b,valid)end)
  if not ok or not v then if core.calls[token]==c then core:voice(token,false,'unavailable')end;return end
  if not valid()then v:destroy();return end
  self.voice[token]=v;core:voice(token,true)
 end
 request.OnServerInvoke=function(p,payload)
  local function fail(code)return{ok=false,code=code}end
  if self.closed or not current(p)or type(payload)~='table'then return fail('invalid')end
  local seq=payload.seq
  if type(seq)~='number'or seq%1~=0 or seq<1 or seq>1e9 or seq<=(self.serials[p]or 0)then return fail('stale')end
  self.serials[p]=seq;local action=payload.action
  if action=='end'then
   local token=payload.id or core.members[p.UserId]
   if not token then return{ok=true,call=core:view(p.UserId)}end
   return core:finish(p.UserId,token)
  end
  local rate=self.rates[p]or{at=clock(),count=0};self.rates[p]=rate
  if clock()-rate.at>3 then rate.at=clock();rate.count=0 end
  rate.count+=1;if rate.count>10 then return fail('rate')end
  if not alive(p)then return fail('blocked')end
  if action=='snapshot'then return{ok=true,call=core:view(p.UserId)}end
  if action~='answer'and p:GetAttribute('SpyPhoneActive')~=true then return fail('blocked')end
  local requestDeadline=clock()+7
  local function liveRequest()return not self.closed and self.serials[p]==seq and clock()<requestDeadline and current(p)and alive(p)and p:GetAttribute('SpyPhoneActive')==true end
  if type(action)=='string'and action:sub(1,5)=='club_'then return clubRequest(p,payload,liveRequest)end
  if action=='link'then
   if payload.visible~=nil and type(payload.visible)~='boolean'then return fail('invalid')end
   return self.link and self.link:list(p,payload.visible,liveRequest)or fail('link_offline')
  end
  local target=payload.target
  if payload.number~=nil then
   local parsed=State.numberId(payload.number)
   if not parsed or(target~=nil and target~=parsed)then return fail('invalid')end
   target=parsed
  end
  if action=='answer'then
   local c=core.calls[payload.id];if not c or c.to~=p.UserId then return fail('stale')end;target=c.from
  end
  if type(target)~='number'or target%1~=0 or target==p.UserId then return fail('invalid')end
  if action=='lookup'and self.link then
   local found=self.link:lookup(target,liveRequest)
   return found.ok and{ok=true,contact=found.contact}or fail(found.code)
  end
  if action=='connect'then return self.link and self.link:connect(p,target,liveRequest)or fail('link_offline')end
  local other=Players:GetPlayerByUserId(target)
  if not current(other)or not alive(other)then return fail('left')end
  if action=='lookup'then return{ok=true,contact={userId=other.UserId,displayName=other.DisplayName,number=State.number(other.UserId),sameServer=true,joinable=true}}end
  local deadline=clock()+7
  local function valid()return not self.closed and self.serials[p]==seq and clock()<deadline and current(p)and current(other)and alive(p)and alive(other)end
  if action~='dial'and action~='answer'then return fail('invalid')end
  local allowed,permissionCode=permission(p,other,valid,true)
  if not allowed then return fail(permissionCode)end
  if not valid()then return fail('stale')end
  if action=='dial'then return core:dial(p.UserId,target,true)end
  if action=='answer'then
   local r=core:answer(p.UserId,payload.id,payload.accept~=false)
   if r.ok and r.call.phase=='active'then task.spawn(voice,r.call.id)end;return r
  end
  return fail('invalid')
 end
 local function validText(text)
  local n=type(text)=='string'and utf8.len(text)
  return n and n>=1 and n<=160 and #text<=640 and text:find('%S')and not text:find('[%z\1-\8\11\12\14-\31]')
 end
 local function invalidateSms(p)
  for from,record in pairs(self.smsInFlight)do if from==p or record.other==p then record.cancelled=true end end
 end
 self.connections[#self.connections+1]=event.OnServerEvent:Connect(function(p,payload)
  if self.closed or not current(p)or type(payload)~='table'or payload.action~='message'then return end
  local seq,key=payload.seq,payload.messageKey
  if type(seq)~='number'or seq%1~=0 or seq<1 or seq>1e9 or type(key)~='string'or #key<1 or #key>100 or key:find('[%c]')then return end
  local previous=self.smsInFlight[p]
  if previous and previous.seq==seq then return end -- Duplicate in-flight packet cannot fail the original draft.
  local record
  local function receipt(code,message)
   if record and self.smsInFlight[p]==record then self.smsInFlight[p]=nil end
   if not self.closed and current(p)then
    event:FireClient(p,{kind='sms_receipt',seq=seq,requestId=key,ok=code==nil,code=code,message=message})
   end
  end
  if seq<=(self.serials[p]or 0)then receipt('stale');return end
  self.serials[p]=seq
  local rate=self.rates[p]or{at=clock(),count=0};self.rates[p]=rate
  if clock()-rate.at>3 then rate.at=clock();rate.count=0 end
  rate.count+=1;if rate.count>10 then receipt('rate');return end
  if not alive(p)or p:GetAttribute('SpyPhoneActive')~=true then receipt('blocked');return end
  local target=payload.target
  if type(target)~='number'or target%1~=0 or target==p.UserId or not validText(payload.text)then receipt('invalid');return end
  local other=Players:GetPlayerByUserId(target)
  if not current(other)or not alive(other)then receipt('left');return end
  if clock()-(self.messages[p]or -100)<.8 then receipt('rate');return end
  self.messages[p]=clock()
  record={seq=seq,other=other,cancelled=false};self.smsInFlight[p]=record
  local senderCharacter,otherCharacter=p.Character,other.Character
  local deadline=clock()+7
  local function valid()
   return not self.closed and self.smsInFlight[p]==record and not record.cancelled and self.serials[p]==seq and clock()<deadline and current(p)and current(other)and p.Character==senderCharacter and other.Character==otherCharacter and alive(p)and alive(other)and p:GetAttribute('SpyPhoneActive')==true
  end
  -- Filter once per submission, just as the working global server chat does.
  -- Never relay the submitted text when either filter stage fails.
  local ok,result=pcall(function()return Filter:FilterStringAsync(payload.text,p.UserId)end)
  if not valid()then receipt('send_timeout');return end
  if not ok or not result then receipt('filter');return end
  local filtered,text=pcall(function()return result:GetNonChatStringForBroadcastAsync()end)
  if not valid()then receipt('send_timeout');return end
  if not filtered or not validText(text)then receipt('filter');return end
  local id='sms:'..Http:GenerateGUID(false)..':'..p.UserId..':'..seq;local at=clock()
  event:FireClient(other,{kind='message',id=id,peer=p.UserId,from=p.UserId,text=text,at=at})
  receipt(nil,{kind='message',id=id,peer=target,from=p.UserId,text=text,at=at,requestId=key})
 end)
 local function close(p)
  invalidateSms(p);self.smsInFlight[p]=nil
  for id,inv in pairs(club.invites)do if inv.from==p.UserId or inv.to==p.UserId then club.invites[id]=nil end end
  for id,plan in pairs(club.plans)do if plan.owner==p.UserId then club.plans[id]=nil else plan.attendees[p.UserId]=nil end end
  club.serials[p.UserId]=nil;club.planAt[p.UserId]=nil
  if self.link then self.link:remove(p)end
  core:remove(p.UserId);self.serials[p]=nil;self.rates[p]=nil;self.messages[p]=nil
 end
 local function watch(p)
  -- Arrival only selects a contact; it never calls, sends or unmutes automatically.
  local ok,joined=pcall(function()return p:GetJoinData()end)
  local data=ok and type(joined)=='table'and joined.TeleportData
  local link=type(data)=='table'and data.SpyClubLink
  if game.PlaceId==93859909286393 and type(link)=='table'and link.from==p.UserId and type(link.target)=='number'and link.target%1==0 and link.target~=p.UserId and State.number(link.target)and type(link.at)=='number'and clock()-link.at>=-2 and clock()-link.at<120 then p:SetAttribute('SpyClubLinkTarget',link.target)end
  self.connections[#self.connections+1]=p.CharacterRemoving:Connect(function()core:remove(p.UserId);invalidateSms(p)end)
  for _,key in ipairs(State.Blocked)do self.connections[#self.connections+1]=p:GetAttributeChangedSignal(key):Connect(function()if p:GetAttribute(key)==true then core:remove(p.UserId);invalidateSms(p)end end)end
  self.connections[#self.connections+1]=p:GetAttributeChangedSignal('SpyAdminMuted'):Connect(function()if p:GetAttribute('SpyAdminMuted')==true then invalidateSms(p)end end)
  self.connections[#self.connections+1]=p:GetAttributeChangedSignal('SpyPhoneActive'):Connect(function()if p:GetAttribute('SpyPhoneActive')~=true and self.smsInFlight[p]then self.smsInFlight[p].cancelled=true end end)
 end
 for _,p in ipairs(Players:GetPlayers())do watch(p)end
 self.connections[#self.connections+1]=Players.PlayerAdded:Connect(watch)
 self.connections[#self.connections+1]=Players.PlayerRemoving:Connect(close)
 local elapsed=0
 self.connections[#self.connections+1]=game:GetService('RunService').Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.5 then return end;elapsed=0
  core:tick()
  for _,c in pairs(core.calls)do
   local a,b=Players:GetPlayerByUserId(c.from),Players:GetPlayerByUserId(c.to)
   if not current(a)or not current(b)or not alive(a)or not alive(b)then core:finish(c.from,c.id,'left')end
  end
 end)
 function self:destroy()
  if self.link then self.link:destroy()end
  self.closed=true;for _,c in ipairs(self.connections)do c:Disconnect()end
  table.clear(self.smsInFlight)
  for token in pairs(self.voice)do stopVoice(token)end
  for _,c in pairs(core.calls)do core:finish(c.from,c.id,'ended')end
  request:Destroy();event:Destroy()
 end
 return self
end
return Service
