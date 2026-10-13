-- Optional panel. All requests have a visible deadline; no movement or boot lease.
local IN_MATCH=true -- Native builder sets this constant for the match copy.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local player=Players.LocalPlayer;local parent=player:WaitForChild('PlayerGui',8);local shared=RS:WaitForChild('SpyShared',8)
if not parent or not shared then return end
-- Lobby archive entry was retired; cases are a phone application.
if not IN_MATCH then
 local open=parent:FindFirstChild('SpyOpenCase')or Instance.new('BindableEvent');open.Name='SpyOpenCase';open.Parent=parent
 open.Event:Connect(function()
  local phone=parent:FindFirstChild('SpyOpenPhone');if phone and phone:IsA('BindableEvent')then phone:Fire('cases')end
 end)
 return
end
local fm=shared:WaitForChild('CaseFiles',8);local um=shared:WaitForChild('CaseDeskUI',8);if not fm or not um then return end
local ok,Files=pcall(require,fm);local uiOk,Desk=pcall(require,um);if not ok or not uiOk then return end
local ui;local serial=0;local pending=false;local meetingData;local localePending=false;local connections={};local observed=setmetatable({},{__mode='k'})
local function language()return player:GetAttribute('SpyLanguage')or'ru'end
local request,refresh
local function applyMeeting(data)
 if meetingData and meetingData.token==data.token and(data.revision or 0)<(meetingData.revision or 0)then return end
 meetingData=data;ui:setData(data)
end
request=function(payload)
 if pending or not ui.window.Visible then return end
 local folder=RS:FindFirstChild(IN_MATCH and'SpyMeetingRemotes'or'SpyCaseRemotes');local remote=folder and folder:FindFirstChild('Request')
 if not remote then ui:error('unavailable');return end
 serial+=1;local id=serial;local before=meetingData;pending=true;ui:setBusy(true)
 task.delay(8,function()if serial==id and pending then
  serial+=1;pending=false;ui:setBusy(false);ui:error('timeout')
  if localePending then localePending=false;request({action='snapshot'})end
 end end)
 task.spawn(function()
  local success,value=pcall(function()return remote:InvokeServer(payload)end)
  if serial~=id then return end
  pending=false;ui:setBusy(false)
  if success and type(value)=='table'and value.ok then
   if IN_MATCH then
    if not(meetingData and meetingData~=before and meetingData.token~=value.token)then applyMeeting(value)end
   else ui:setData(value)end
  else ui:error(type(value)=='table'and value.code or'unavailable')end
  if localePending then localePending=false;refresh()end
 end)
end
refresh=function()
 if ui.window.Visible then request({action=IN_MATCH and'snapshot'or(ui.data and ui.data.kind=='archive'and'progress'or'snapshot')})end
end
ui=Desk.new(parent,Files,language,request,IN_MATCH and 390 or 82)
ui.onClose=function()serial+=1;pending=false;localePending=false;ui:setBusy(false)end
local open=parent:FindFirstChild('SpyOpenCase')or Instance.new('BindableEvent');open.Name='SpyOpenCase';open.Parent=parent
connections[#connections+1]=open.Event:Connect(function(kind)
 if IN_MATCH then ui:show(meetingData or{kind='meeting'});request({action='snapshot'})
 else ui:show({kind='archive'});request({action=kind=='training'and'training'or'progress'})end
end)
local function prompt(p)
 if not p:IsA('ProximityPrompt')or not p:GetAttribute('SpyCasePrompt')or observed[p]then return end
 observed[p]=true
 local function refresh()
  p.ObjectText=Files.text(language(),p:GetAttribute('SpyCasePrompt'))
  p.ActionText=Files.text(language(),p:GetAttribute('SpyCaseAction')or'inspect_action')
 end
 refresh();local c=player:GetAttributeChangedSignal('SpyLanguage'):Connect(refresh)
 p.Destroying:Connect(function()c:Disconnect();observed[p]=nil end)
 p.Triggered:Connect(function(who)
  if who and who~=player then return end
  if IN_MATCH then
   ui:show(meetingData or{kind='meeting'})
   if meetingData and meetingData.canInspect then request({action='inspect',token=meetingData.token,source=p:GetAttribute('SpyCasePrompt')})else request({action='snapshot'})end
  else open:Fire('archive')end
 end)
end
for _,p in ipairs(workspace:GetDescendants())do prompt(p)end
connections[#connections+1]=workspace.DescendantAdded:Connect(prompt)
local hooked=setmetatable({},{__mode='k'})
local function listen(n)
 if not IN_MATCH or n.Name~='State'or not n:IsA('RemoteEvent')or not n.Parent or n.Parent.Name~='SpyMeetingRemotes'or hooked[n]then return end
 hooked[n]=true;connections[#connections+1]=n.OnClientEvent:Connect(function(data)
  if type(data)~='table'or data.kind~='meeting'then return end
  applyMeeting(data)
 end)
end
for _,n in ipairs(RS:GetDescendants())do listen(n)end
connections[#connections+1]=RS.DescendantAdded:Connect(listen)
connections[#connections+1]=player:GetAttributeChangedSignal('SpyLanguage'):Connect(function()
 if ui.data then ui:setData(ui.data)end
 if pending then localePending=true else refresh()end
end)
connections[#connections+1]=player:GetAttributeChangedSignal('SpyTeleporting'):Connect(function()if player:GetAttribute('SpyTeleporting')then ui:close()end end)
script.Destroying:Connect(function()serial+=1;for _,c in ipairs(connections)do c:Disconnect()end;ui:destroy();open:Destroy()end)
