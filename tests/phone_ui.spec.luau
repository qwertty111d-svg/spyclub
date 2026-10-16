-- Real UI -> Social -> Connect layering. Services/font metrics are boundaries.
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
guiClasses.ImageLabel=true;guiClasses.TextBox=true
events.MouseButton1Down=true;events.MouseButton1Up=true;events.FocusLost=true;events.ReturnPressedFromOnScreenKeyboard=true
function Methods:FindFirstChild(name,recursive)
 for _,child in ipairs(self:GetChildren())do if child.Name==name then return child end end
 if recursive then for _,child in ipairs(self:GetChildren())do local found=child:FindFirstChild(name,true);if found then return found end end end
end
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
function Methods:ClearAllChildren()for _,child in ipairs(self:GetChildren())do child:Destroy()end end
local oldNew=Instance.new
function Instance.new(class)
 local n=oldNew(class);n.ChildAdded=signal();n.ChildRemoved=signal();n.DescendantAdded=signal()
 if class=='ScreenGui'then n.Size=UDim2.fromScale(1,1)end
 return n
end
Vector2.new=function(x,y)return{X=x or 0,Y=y or 0}end
local ColorSequence={new=function(v)return v end};local ColorSequenceKeypoint={new=function(...)return{...}end}
local player=Instance.new('Player');player.UserId=123;player.DisplayName='James';player.Name='James'
local peer=Instance.new('Player');peer.UserId=456;peer.DisplayName='Vincent';peer.Name='Vincent'
player:SetAttribute('SpyLanguage','ru');peer:SetAttribute('SpyClubLinkVisible',true)
local pg=Instance.new('PlayerGui');pg.AbsoluteSize=Vector2.new(1440,900)
services.Players={LocalPlayer=player,GetPlayers=function()return{player,peer}end,GetPlayerByUserId=function(_,id)return id==peer.UserId and peer or id==player.UserId and player end,PlayerAdded=signal(),PlayerRemoving=signal()}
input.GetPropertyChangedSignal=function(_,name)return signal()end
guiService.GetGuiInset=function()return Vector2.zero,Vector2.zero end
local workspace={GetServerTimeNow=function()return 1000 end}
local function load(name)
 local env=setmetatable({game=game,workspace=workspace,Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,ColorSequence=ColorSequence,ColorSequenceKeypoint=ColorSequenceKeypoint,task=task,TweenInfo=TweenInfo},{__index=getfenv(0)})
 local chunk=assert(loadstring(Sources[name],name));setfenv(chunk,env);return chunk()
end
local State,UI,Social,Connect=load('PhoneState'),load('PhoneUI'),load('PhoneSocial'),load('PhoneConnectUI')
local requested,feedback={},{}
local function request(p,callback)requested[#requested+1]=p;return true end
local function create(inMatch)
 local ui
 ui=UI.new(pg,State,{}, {inMatch=inMatch,language=function()return'ru'end,blocked=function()return false end,toggle=function()end,close=function()ui:hide()end,feedback=function(k)feedback[#feedback+1]=k end,launch=function()end,caseRequest=function()end,profile=function()return{}end})
 Social.attach(ui,{request=request,openCall=function()ui:show('calls')end,sound=function()end,openChat=function()end,noteLoad=function()end})
 Connect.attach(ui,State,{request=request});return ui
end
local function find(ui,name)return assert(ui.gui:FindFirstChild(name,true),name)end
local function within(node,parent,label)
 local p,s,q,t=node.AbsolutePosition,node.AbsoluteSize,parent.AbsolutePosition,parent.AbsoluteSize
 check(p.X>=q.X-.01 and p.Y>=q.Y-.01 and p.X+s.X<=q.X+t.X+.01 and p.Y+s.Y<=q.Y+t.Y+.01,label..' fits')
end
local function separate(a,b,label)
 local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
 check(p.X+s.X<=q.X+.01 or q.X+t.X<=p.X+.01 or p.Y+s.Y<=q.Y+.01 or q.Y+t.Y<=p.Y+.01,label..' do not overlap')
end
for _,inMatch in ipairs({false,true})do
 local ui=create(inMatch);ui:show('home')
 check(find(ui,'HomeConnections')~=nil,'communication cards are grouped before utility apps')
 for _,key in ipairs({'clublink','messages','calls','contacts'})do
  local b=find(ui,'App_'..key);check(b.Parent.Name=='HomeConnections','primary communication action belongs to main group');check(b.AbsoluteSize.Y>=64,'primary communication action is tappable')
 end
 local keys=inMatch and{'notes','timer','sound'}or{'club','navigator','notes','timer','sound','camera'}
 for _,key in ipairs(keys)do check(find(ui,'App_'..key)~=nil,'secondary '..key..' remains reachable')end
 check(find(ui,'HomeClock').Font==Enum.Font.Bodoni,'home clock uses editorial serif')
 for _,size in ipairs({{1920,1080},{1440,900},{900,600},{360,640},{844,360},{320,568}})do
  pg.AbsoluteSize=Vector2.new(size[1],size[2]);input.TouchEnabled=size[1]<600;ui:show('home')
  within(ui.shell,pg,'phone body');within(ui.content,ui.screen,'home scroller');within(find(ui,'HomeDock'),ui.screen,'communication dock')
  separate(ui.content,find(ui,'HomeDock'),'home content and dock')
  ui:error('blocked');within(ui.status,ui.screen,'home failure notice');separate(ui.status,find(ui,'HomeDock'),'home failure notice and dock');separate(ui.status,ui.content,'home failure notice and apps');ui.noticeKey=nil;ui.status.Text='';ui:resize()
  for _,key in ipairs({'calls','contacts','messages','notes'})do local b=find(ui,'Dock_'..key);check(b.AbsoluteSize.Y>=44,'dock target height');within(b,find(ui,'HomeDock'),'dock action')end
  ui.app='messages';ui.peer=peer.UserId;ui:render()
  within(ui.composer,ui.screen,'composer');within(ui.content,ui.screen,'message content');separate(ui.content,ui.composer,'messages and composer');separate(ui.status,ui.composer,'status and composer')
 end
 pg.AbsoluteSize=Vector2.new(360,640);input.TouchEnabled=true;ui.app='messages';ui.peer=456;ui:render()
 input.OnScreenKeyboardVisible=true;input.OnScreenKeyboardPosition=Vector2.new(0,320);ui:resize()
 check(ui.shell.AbsolutePosition.Y+ui.shell.AbsoluteSize.Y<=312.01,'phone rises above on-screen keyboard')
 within(ui.composer,ui.screen,'keyboard composer');separate(ui.content,ui.composer,'keyboard message content and composer')
 input.OnScreenKeyboardVisible=false;ui:resize()
 pg.AbsoluteSize=Vector2.new(1440,900);ui:show('home')
 find(ui,'App_messages').Activated:Fire();check(ui.app=='messages','communication card opens actual message screen')
 ui:showContact({userId=456,number=State.number(456),displayName='Vincent',sameServer=true,joinable=true})
 find(ui,'ContactMessage').Activated:Fire();check(ui.app=='messages'and ui.peer==456,'contact message action preserves peer')
 local inputBox=find(ui,'MessageInput');inputBox.Text='Test';find(ui,'SendMessage').Activated:Fire()
 local sent=requested[#requested];check(sent.action=='message'and sent.target==456 and sent.text=='Test','composer preserves actual request payload')
 ui:error('dm_restricted',{action='message',target=456});check(ui.drafts[456]=='Test','privacy error preserves draft');check(find(ui,'OpenClubChat').Visible,'privacy recovery remains available')
 ui:setCall({phase='ringing',incoming=true,peer=456,id='call-1',revision=1});ui:show('calls')
 check(find(ui,'PhoneIncoming').Visible==false,'visible call screen strictly hides the duplicate notification')
 for _,size in ipairs({{1440,900},{360,640},{844,360}})do
  pg.AbsoluteSize=Vector2.new(size[1],size[2]);ui:resize()
  local hero,actions=find(ui,'CallHero'),find(ui,'CallActions')
  check(hero.AbsoluteSize.Y+10+actions.AbsoluteSize.Y<=ui.content.AbsoluteSize.Y,'call identity and primary controls fit without scrolling')
  within(find(ui,'AnswerCall'),actions,'answer control');within(find(ui,'DeclineCall'),actions,'decline control');separate(find(ui,'AnswerCall'),find(ui,'DeclineCall'),'incoming call actions')
 end
 find(ui,'AnswerCall').Activated:Fire();check(requested[#requested].action=='answer'and requested[#requested].id=='call-1','answer preserves call protocol')
 ui:setCall({phase='active',incoming=true,peer=456,id='call-1',revision=2,at=980,voice=true});ui:show('calls')
 check(find(ui,'CallDuration').Text=='00:20','call duration still uses server time')
 for _,size in ipairs({{844,360},{1440,900}})do
  pg.AbsoluteSize=Vector2.new(size[1],size[2]);ui:resize()
  check(find(ui,'CallHero').AbsoluteSize.Y+10+find(ui,'CallActions').AbsoluteSize.Y<=ui.content.AbsoluteSize.Y,'active call controls fit after live resize')
  within(find(ui,'EndCall'),find(ui,'CallActions'),'end call control');separate(find(ui,'CallMessages'),find(ui,'EndCall'),'active call actions')
 end
 find(ui,'EndCall').Activated:Fire();check(requested[#requested].action=='end'and requested[#requested].id=='call-1','end preserves call protocol')
 ui:hide();check(not ui.visible and not ui.shell.Visible,'put away hides device');ui:destroy()
end
print('Layered phone UI: '..checks..' assertions passed (native rendering/keyboard not run)')
