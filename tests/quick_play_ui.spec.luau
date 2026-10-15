-- Actual client source and authored translations, with Roblox service boundaries.
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
Vector2.new=function(x,y)return {X=x or 0,Y=y or 0}end
function Methods:WaitForChild(name)return self:FindFirstChild(name)end
function Methods:GetAttributeChangedSignal(name)return self:GetPropertyChangedSignal('attribute_'..name)end
function Methods:SetAttribute(name,value)
 local previous=self._attributes[name];self._attributes[name]=value
 if previous~=value and self._signals['attribute_'..name]then self._signals['attribute_'..name]:Fire()end
end
local nativeNew=Instance.new
function Instance.new(class)
 local n=nativeNew(class);n.DescendantAdded=signal()
 if class=='BindableEvent'then n.Event=signal();n.Fire=function(self,...)self.Event:Fire(...)end end
 if class=='ScreenGui'then n.Size=UDim2.fromScale(1,1);n.Enabled=true end
 return n
end
local function make(class,parent,props)
 local n=Instance.new(class);for key,value in pairs(props or{})do n[key]=value end;n.Parent=parent;return n
end
local function within(node,size,name)
 local p,s=node.AbsolutePosition,node.AbsoluteSize
 check(p.X>=-.01 and p.Y>=-.01 and p.X+s.X<=size.X+.01 and p.Y+s.Y<=size.Y+.01,name..' fits viewport')
end
local function separate(a,b,name)
 local ap,as,bp,bs=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
 check(ap.X+as.X<=bp.X+.01 or bp.X+bs.X<=ap.X+.01 or ap.Y+as.Y<=bp.Y+.01 or bp.Y+bs.Y<=ap.Y+.01,name..' do not overlap')
end
local Files=assert(loadstring(Sources.Files,'actual-CaseFiles'))()
local player=Instance.new('Player');player:SetAttribute('SpyLanguage','ru')
local pg=make('PlayerGui',player,{Name='PlayerGui',AbsoluteSize=Vector2.new(1440,900)})
local rs=Instance.new('ReplicatedStorage')
local shared=make('Folder',rs,{Name='SpyShared'})
local filesNode=make('ModuleScript',shared,{Name='CaseFiles'})
local remotes=make('Folder',rs,{Name='SpyQuickPlayRemotes'})
local remote=make('RemoteFunction',remotes,{Name='Request'})
local stateEvent=make('RemoteEvent',remotes,{Name='State',OnClientEvent=signal()})
local manualOpener=make('BindableEvent',pg,{Name='SpyOpenManualTable'})
local manualOpened=0;manualOpener.Event:Connect(function()manualOpened+=1 end)
local requests={}
remote.InvokeServer=function(_,request)
 requests[#requests+1]=request
 if request.action=='join'then return {state='waiting',count=1,mode=request.mode}end
 return {state='idle'}
end
local camera=make('Camera',nil,{ViewportSize=pg.AbsoluteSize})
services.Players={LocalPlayer=player};services.ReplicatedStorage=rs
guiService.GetGuiInset=function()return Vector2.zero,Vector2.zero end
local scriptNode=Instance.new('LocalScript')
local env=setmetatable({game=game,workspace={CurrentCamera=camera},Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,task=task,script=scriptNode,
 require=function(n)check(n==filesNode,'client requires actual CaseFiles owner');return Files end},{__index=getfenv(0)})
local chunk=assert(loadstring(Sources.QuickPlay,'actual-QuickPlay-client'));setfenv(chunk,env);chunk()
local gui=pg:FindFirstChild('SpyQuickPlay');local window=gui:FindFirstChild('SearchWindow')
local header=window:FindFirstChild('QuickInvitation');local scroll=window:FindFirstChild('QuickChoices')
local modes=scroll:FindFirstChild('ModeChoices');local classic=modes:FindFirstChild('Mode_classic');local meeting=modes:FindFirstChild('Mode_case')
local manual=scroll:FindFirstChild('QuickManual');local status=scroll:FindFirstChild('QuickState')
local footer=window:FindFirstChild('QuickActions');local join=footer:FindFirstChild('JoinSearch');local cancel=footer:FindFirstChild('CancelSearch')
local open=pg:FindFirstChild('SpyOpenQuickPlay')
check(not window.Visible,'play starts closed')
open:Fire();check(window.Visible,'existing Play event opens the invitation')
check(#requests==1 and requests[1].action=='status','opening requests current queue status')
check(classic.Active and meeting.Active and manual.Active,'all three choices remain actionable')
meeting.Activated:Fire();join.Activated:Fire()
check(requests[#requests].action=='join'and requests[#requests].mode=='case','secret-meeting choice uses existing case protocol')
check(not modes.Visible and cancel.Visible and not join.Visible,'queue replaces choices with cancellable search state')
check(status.Text:find('1 / 4',1,true)~=nil,'queue status includes actual player count')
local count=#requests;classic.Activated:Fire();join.Activated:Fire()
check(#requests==count,'active search does not issue a second join')
cancel.Activated:Fire();check(modes.Visible and join.Visible and not cancel.Visible,'cancellation restores choice list')
classic.Activated:Fire();join.Activated:Fire()
check(requests[#requests].mode=='classic','classic choice keeps existing classic protocol')
manual.Activated:Fire()
check(requests[#requests].action=='cancel'and manualOpened==1,'own-table choice cancels queue before opening actual table picker')
check(not window.Visible,'manual navigation closes invitation')
open:Fire();stateEvent.OnClientEvent:Fire({state='preparing',count=4,canCancel=false})
check(not cancel.Active and cancel.Visible,'server cancellation lock remains visible and respected')
stateEvent.OnClientEvent:Fire({state='matched'});check(not window.Visible,'matched event closes invitation')
stateEvent.OnClientEvent:Fire({state='idle'})
for _,language in ipairs({'ru','en','zh'})do
 player:SetAttribute('SpyLanguage',language)
 check(header:FindFirstChild('QuickTitle').Text==Files.text(language,'quick'),'title keeps actual localized text')
 check(classic:FindFirstChild('ModeTitle').Text==Files.text(language,'classic'),'classic choice keeps localization')
 check(meeting:FindFirstChild('ModeTitle').Text==Files.text(language,'meeting'),'meeting choice keeps localization')
 for _,size in ipairs({{1440,900},{360,640},{360,540},{280,640},{844,360},{280,180}})do
  pg.AbsoluteSize=Vector2.new(size[1],size[2]);camera.ViewportSize=pg.AbsoluteSize
  camera:GetPropertyChangedSignal('ViewportSize'):Fire()
  within(window,pg.AbsoluteSize,'invitation');within(join,pg.AbsoluteSize,'join');within(cancel,pg.AbsoluteSize,'cancel')
  within(header:FindFirstChild('QuickClose'),pg.AbsoluteSize,'close')
  check(scroll.AbsoluteSize.Y>=44,'scrolling choices retain usable touch viewport')
  check(join.AbsoluteSize.Y>=44 and cancel.AbsoluteSize.Y>=44,'search actions remain tappable')
  separate(scroll,footer,'choices and search action');separate(header,scroll,'invitation header and choices')
  separate(classic,meeting,'queue choices')
  for _,card in ipairs({classic,meeting,manual})do
   local title=card:FindFirstChild('ModeTitle');local description=card:FindFirstChild('ModeDescription')
   check(card.AbsoluteSize.Y>=44,'choice touch targets remain usable')
   separate(title,description,'choice title and description')
   check(description.AbsoluteSize.X>=150 and description.AbsoluteSize.Y>=44,'choice descriptions retain readable space')
  end
 end
end
-- Pending requests keep the existing dedupe guard while the transport is in flight.
local pendingJobs={};local previousSpawn=task.spawn;task.spawn=function(job)pendingJobs[#pendingJobs+1]=job end
local before=#requests;join.Activated:Fire();join.Activated:Fire();manual.Activated:Fire()
check(not join.Active and #pendingJobs==1 and #requests==before,'pending join locks choices and deduplicates transport')
task.spawn=previousSpawn;pendingJobs[1]()
check(#requests==before+1 and cancel.Visible,'pending join settles into server queue state')
scriptNode.Destroying:Fire();check(not gui.Parent,'client teardown removes invitation')
print('QuickPlay UI: '..checks..' assertions passed (actual client, translations and queue callbacks; Studio was not run)')
