-- Solo case state and an optional Roblox adapter. Profiles is the only durable store.
local Service={};Service.__index=Service
local answers={cassette='felix',envelope='hugo',call='felix'}
local tutorial={'open','subtle','felix','listen','code'}
function Service.new(files,save,clock,guid)
 return setmetatable({files=files,save=save,clock=clock or os.time,guid=guid,sessions={}},Service)
end
function Service:view(id,lang)
 local s=self.sessions[id];if not s then return {ok=true,kind='archive'}end
 local out={ok=true,kind=s.kind,token=s.token,finished=s.finished==true,saving=s.saving==true}
 if s.kind=='training'then out.training=self.files.training(s.step,lang);if s.finished then out.explanation=self.files.text(lang,'training_done')end
 else
  out.file=self.files.public(s.id,lang);out.evidence={}
  for source in pairs(s.sources)do out.evidence[source]=self.files.evidence(s.id,source,lang)end
  if s.finished then out.explanation=self.files.explanation(s.id,lang)end
 end
 return out
end
function Service:handle(id,p,lang)
 if type(p)~='table'then return {ok=false,code='invalid'}end
 local s=self.sessions[id]
 if p.action=='snapshot'then return self:view(id,lang)end
 if p.action=='start'or p.action=='training'then
  if s and s.saving then return {ok=false,code='busy'}end
  if p.action=='start'and not self.files.valid(p.id)then return {ok=false,code='invalid'}end
  local kind=p.action=='training'and'training'or'case'
  -- Tutorial identity is canonical; ignore any payload.id.
  local fileId;if kind=='case'then fileId=p.id end
  s={kind=kind,id=fileId,token=self.guid(),sources={},step=1,finished=false}
  self.sessions[id]=s;return self:view(id,lang)
 end
 if not s or p.token~=s.token then return {ok=false,code='stale'}end
 if s.saving then return {ok=false,code='busy'}end
 if s.finished then return self:view(id,lang)end
 if p.action=='inspect'and s.kind=='case'then
  if not self.files.evidence(s.id,p.source,lang)then return {ok=false,code='invalid'}end
  s.sources[p.source]=true;return self:view(id,lang)
 elseif p.action=='answer'and s.kind=='training'then
  if p.choice~=tutorial[s.step]then return {ok=false,code='wrong'}end
  if s.step<#tutorial then s.step+=1;return self:view(id,lang)end
 elseif p.action=='solve'and s.kind=='case'then
  for _,source in ipairs({'tape','phone','folder'})do if not s.sources[source]then return {ok=false,code='inspect_first'}end end
  if p.suspect~=answers[s.id]then return {ok=false,code='wrong'}end
 else return {ok=false,code='invalid'}end
 s.saving=true
 local command={kind=s.kind=='training'and'tutorialComplete'or'caseSolved',caseId=s.id,now=self.clock()}
 local key='case:'..id..':'..(s.kind=='training'and'tutorial'or s.id)
 local ok,result=pcall(self.save,id,key,command);s.saving=false
 if self.sessions[id]~=s then return {ok=false,code='stale'}end
 if not ok or type(result)~='table'or not result.ok then return {ok=false,code='save_failed'}end
 s.finished=true;return self:view(id,lang)
end
function Service:remove(id)self.sessions[id]=nil end
function Service.start(profiles,onChanged)
 local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Http=game:GetService('HttpService')
 local files=require(RS:WaitForChild('SpyShared'):WaitForChild('CaseFiles'))
 local self=Service.new(files,function(id,key,command)return profiles:transact(id,key,command)end,os.time,function()return Http:GenerateGUID(false)end)
 local folder=RS:FindFirstChild('SpyCaseRemotes')or Instance.new('Folder');folder.Name='SpyCaseRemotes';folder.Parent=RS
 local request=folder:FindFirstChild('Request')or Instance.new('RemoteFunction');request.Name='Request';request.Parent=folder
 local rate,recovering={},{}
 local function notify(player)
  if not onChanged then return end
  -- Wardrobe preparation may yield. It is optional presentation and cannot
  -- retain a request that could later act on a replacement Player's session.
  task.defer(function()
   if player.Parent==Players and Players:GetPlayerByUserId(player.UserId)==player then pcall(onChanged,player)end
  end)
 end
 request.OnServerInvoke=function(player,p)
  if player.Parent~=Players or Players:GetPlayerByUserId(player.UserId)~=player then return {ok=false,code='stale'}end
  local now=os.clock();local gate=rate[player.UserId]
  if not gate or now-gate.at>2 then gate={at=now,count=0};rate[player.UserId]=gate end
  gate.count+=1;if gate.count>12 then return {ok=false,code='busy'}end
  local profile=profiles:public(player.UserId)
  if not profile.ready and self.sessions[player.UserId]then
   -- Profiles deliberately invalidates its cache after an unknown write outcome.
   -- Recover from the existing durable record, retaining this case's exact token.
   if recovering[player.UserId]then return {ok=false,code='busy'}end
   local lease={player=player};recovering[player.UserId]=lease
   task.delay(8,function()if recovering[player.UserId]==lease then recovering[player.UserId]=nil end end)
   pcall(function()profiles:load(player.UserId)end)
   if recovering[player.UserId]==lease then recovering[player.UserId]=nil end
   if player.Parent~=Players or Players:GetPlayerByUserId(player.UserId)~=player then return {ok=false,code='stale'}end
   profile=profiles:public(player.UserId)
   if profile.ready then notify(player)end
  end
  if not profile or not profile.ready then return {ok=false,code='save_failed'}end
  if type(p)=='table'and p.action=='progress'then return {ok=true,kind='archive',progress=profile.club and profile.club.caseFiles}end
  if player:GetAttribute('SpyTeleporting')or player:GetAttribute('SpyCheckersPlaying')or player:GetAttribute('SpyBilliardsPlaying')then return {ok=false,code='busy'}end
  local result=self:handle(player.UserId,p,player:GetAttribute('SpyLanguage')or profile.language or'ru')
  if result.ok and result.finished then notify(player)end
  result.progress=(profiles:public(player.UserId)or{}).club;result.progress=result.progress and result.progress.caseFiles
  return result
 end
 Players.PlayerRemoving:Connect(function(p)self:remove(p.UserId);rate[p.UserId]=nil;if recovering[p.UserId]and recovering[p.UserId].player==p then recovering[p.UserId]=nil end end)
 return self
end
return Service
