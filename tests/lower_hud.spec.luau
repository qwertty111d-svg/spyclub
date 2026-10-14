-- Roblox GUI boundary stubs are shared with the existing dossier runner.
-- The layout and visibility owners, plus both integrating client excerpts, are real.
Vector2.new=function(x,y)return {X=x or 0,Y=y or 0}end
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function near(a,b,message)check(math.abs(a-b)<.001,message)end
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
function Methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function Methods:GetAttributeChangedSignal(name)return self:GetPropertyChangedSignal('attribute_'..name)end
function Methods:SetAttribute(name,value)
 local previous=self._attributes[name];self._attributes[name]=value
 if previous~=value and self._signals['attribute_'..name]then self._signals['attribute_'..name]:Fire()end
end
local baseIndex,baseNew=NodeMeta.__index,NodeMeta.__newindex
function NodeMeta.__index(node,key)
 local value=baseIndex(node,key)
 if value~=nil then return value end
 return Methods.FindFirstChild(node,key)
end
function NodeMeta.__newindex(node,key,value)
 local previous=node._values[key];baseNew(node,key,value)
 if previous~=value and node._signals[key]then node._signals[key]:Fire()end
end
local nativeNew=Instance.new
function Instance.new(class)
 local node=nativeNew(class)
 node.DescendantAdded,node.ChildRemoved,node.ChildAdded=signal(),signal(),signal()
 if class=='ScreenGui'then node.Size=UDim2.fromScale(1,1);node.Enabled=true end
 return node
end
local player=Instance.new('Player')
player:SetAttribute('SpyLanguage','ru')
local pg=Instance.new('PlayerGui');pg.AbsoluteSize=Vector2.new(900,600)
player.PlayerGui=pg
services.Players={LocalPlayer=player}
services.ReplicatedStorage=Instance.new('ReplicatedStorage')
guiService.GetGuiInset=function()return Vector2.zero,Vector2.zero end
input.GetPropertyChangedSignal=function(_,name)return signal()end
local camera=Instance.new('Camera');camera.ViewportSize=pg.AbsoluteSize
local workspace={CurrentCamera=camera}
local function loadSource(name,extra)
 local env=setmetatable(extra or {},{__index=getfenv(0)})
 env.game,env.workspace,env.Instance,env.Enum=game,workspace,Instance,Enum
 env.UDim,env.UDim2,env.Vector2,env.Color3,env.TweenInfo=UDim,UDim2,Vector2,Color3,TweenInfo
 env.task=task
 local chunk=assert(loadstring(Sources[name],name));setfenv(chunk,env);return chunk()
end
local function make(class,parent,properties)
 local node=Instance.new(class);for key,value in pairs(properties or{})do node[key]=value end;node.Parent=parent;return node
end
local function visible(node)
 while node do
  if node:IsA('GuiObject')and node.Visible==false or node:IsA('ScreenGui')and node.Enabled==false then return false end
  node=node.Parent
 end
 return true
end
local function within(node,size,name)
 local p,s=node.AbsolutePosition,node.AbsoluteSize
 check(p.X>=-.01 and p.Y>=-.01 and p.X+s.X<=size.X+.01 and p.Y+s.Y<=size.Y+.01,name..' fits viewport')
end
local function separate(a,b,name)
 local ap,as,bp,bs=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
 check(ap.X+as.X<=bp.X+.01 or bp.X+bs.X<=ap.X+.01 or ap.Y+as.Y<=bp.Y+.01 or bp.Y+bs.Y<=ap.Y+.01,name..' do not overlap')
end
local LobbyHUD=loadSource('LobbyHUD')
local hud=make('ScreenGui',pg,{Name='HudGui'})
local main=make('TextButton',hud,{Name='MainAction'})
local dock=make('Frame',hud,{Name='BottomDesk'})
for _,name in ipairs({'Shop','Daily','Inventory','Profile','Trade','Settings','HighStakes','Guide'})do make('TextButton',dock,{Name=name})end
local function L(key)return({hudProfile='Статистика',hudTrade='Обмен',hudSettings='Настройки',menuToggle='Меню'})[key]or key end
local hudView=LobbyHUD.new(hud,L)
local clientGui=make('ScreenGui',pg,{Name='SpyClubUI'})
local quickEnv={gui=clientGui,hudView=hudView,player=player,ReplicatedStorage=services.ReplicatedStorage,
 colors={panel=Color3.fromRGB(20,22,25),gold=Color3.fromRGB(240,240,237),raised=Color3.fromRGB(30,32,35),text=Color3.fromRGB(240,240,237)},
 corner=function(node,radius)make('UICorner',node,{CornerRadius=UDim.new(0,radius)})end,make=make}
local quickChunk=assert(loadstring(Sources.QuickChatSetup..Sources.QuickChatLayout..'\nreturn {resize=resize,button=quickButton,panel=quickPanel}','actual-SpyClient-QuickChat'))
setfenv(quickChunk,setmetatable(quickEnv,{__index=getfenv(0)}))
quickEnv.game,quickEnv.Instance,quickEnv.UDim2,quickEnv.UDim,quickEnv.Enum,quickEnv.Vector2,quickEnv.Color3=game,Instance,UDim2,UDim,Enum,Vector2,Color3
local quick=quickChunk()
for _,size in ipairs({{1920,1080},{900,600},{760,600},{360,640},{844,360},{280,180}})do
 pg.AbsoluteSize=Vector2.new(size[1],size[2]);input.TouchEnabled=size[1]<700;quick.resize();hudView:resize()
 within(main,pg.AbsoluteSize,'play')
 check(main.AbsoluteSize.Y>=44,'play remains tappable')
 if visible(quick.button)then separate(main,quick.button,'quick phrases and play')end
 hudView.MenuButton.Activated:Fire()
 check(visible(quick.button),'quick phrases are reachable in the secondary menu')
 within(quick.button,pg.AbsoluteSize,'quick phrases')
 separate(main,quick.button,'expanded quick phrases and play')
 for _,button in ipairs({dock.Inventory,dock.Shop,dock.Daily,hudView.MenuButton})do
  if visible(button)then within(button,pg.AbsoluteSize,button.Name);separate(main,button,button.Name..' and play')end
 end
 quick.button.Activated:Fire();check(quick.panel.Visible,'quick phrases open through the menu');within(quick.panel,pg.AbsoluteSize,'quick phrase picker')
 quick.panel.Visible=false
 if hudView.MenuExpanded then hudView.MenuButton.Activated:Fire()end
end
for _,flag in ipairs({'SpyCharacterMenuOpen','SpyPhoneActive','SpyTradeOpen','SpyEntryPending','SpyEntryActive','SpyTeleporting','SpyBilliardsPlaying','SpyCheckersPlaying'})do
 pg.AbsoluteSize=Vector2.new(900,600);input.TouchEnabled=false;hudView:setActive(nil);quick.resize()
 hudView.MenuButton.Activated:Fire();quick.panel.Visible=true
 player:SetAttribute(flag,true)
 check(not visible(main),'play closes under '..flag)
 check(not visible(quick.button)and not quick.panel.Visible,'quick phrases close under '..flag)
 player:SetAttribute(flag,false)
end
hudView:Destroy();hud:Destroy();clientGui:Destroy()
local MatchHUD=loadSource('MatchHUD')
local matchGui=make('ScreenGui',pg,{Name='MatchUI'})
local blackout=make('Frame',matchGui,{Name='Blackout',Visible=false})
local session=make('Folder',services.ReplicatedStorage,{Name='MatchSession'})
session:SetAttribute('RoundPhase','Hint')
local ready=make('CanvasGroup',matchGui,{Name='ReadyRoot',Visible=true})
make('TextButton',ready,{Name='ReadyButton',Size=UDim2.fromScale(1,1)})
local readyTitle=make('TextLabel',ready,{Name='TurnTitle',Text='Закончить ход',Visible=true,Position=UDim2.fromOffset(54,0),Size=UDim2.new(1,-66,1,0)})
make('Frame',ready,{Name='ReadyKeycap',Visible=true,Size=UDim2.fromOffset(30,30)})
local guess=make('TextButton',matchGui,{Name='SpyGuessButton',Visible=false,Text='Назвать место'})
local state=MatchHUD.registerPrimary(pg,ready,'ready')
MatchHUD.register(pg,guess,10)
local utilitiesEnv={matchUI={},gui=matchGui,MatchHUD=MatchHUD,playerGui=pg,player=player,UserInputService=input,
 COLORS={Panel=Color3.fromRGB(19,21,24),Panel2=Color3.fromRGB(32,34,38),Ivory=Color3.fromRGB(245,245,241)},
 make=make,corner=quickEnv.corner}
local utilitiesChunk=assert(loadstring(Sources.MatchUtilities..'\nreturn matchUI','actual-MatchIntro-shortcuts'))
setfenv(utilitiesChunk,setmetatable(utilitiesEnv,{__index=getfenv(0)}))
utilitiesEnv.UDim2,utilitiesEnv.Vector2,utilitiesEnv.Enum=UDim2,Vector2,Enum
local matchUI=utilitiesChunk();matchUI.controls.Visible=true
check(type(MatchHUD.registerUtilities)=='function','actual MatchIntro utilities have a shared lower layout owner')
for _,size in ipairs({{1920,1080},{900,600},{360,640},{844,360},{280,180}})do
 pg.AbsoluteSize=Vector2.new(size[1],size[2]);camera.ViewportSize=pg.AbsoluteSize
 for _,active in ipairs({{true,false},{false,true},{true,true}})do
  ready.Visible,guess.Visible=active[1],active[2];state.fit()
  if active[1]and active[2]then
   check(guess.Parent==state.list,'spy attempt stays available in Menu while finishing the turn has primary focus')
   state.toggle.Activated:Fire();check(visible(guess),'spy attempt remains reachable during own turn');state.toggle.Activated:Fire()
  end
  if visible(ready)then check(readyTitle.AbsoluteSize.X>=64,'actual finish-turn caption retains readable width')end
  near(matchUI.controls.AbsolutePosition.Y,state.root.AbsolutePosition.Y,'Card/Chat/Menu share baseline')
  for _,object in ipairs({ready,guess})do
   if visible(object)then within(object,pg.AbsoluteSize,object.Name);near(object.AbsolutePosition.Y,matchUI.controls.AbsolutePosition.Y,'context action shares the rail');separate(object,matchUI.controls,'context action and utilities');separate(object,state.root,'context action and menu');check(object.AbsoluteSize.Y>=44,'context touch target')end
  end
  within(matchUI.controls,pg.AbsoluteSize,'Card/Chat');within(state.root,pg.AbsoluteSize,'Menu')
  separate(matchUI.controls,state.root,'utilities and menu')
  for _,shortcut in ipairs({matchUI.cardShortcut,matchUI.chatShortcut})do check(shortcut.AbsoluteSize.X>=44 and shortcut.AbsoluteSize.Y>=44,'Card and Chat actual integrated touch targets')end
  separate(matchUI.cardShortcut,matchUI.chatShortcut,'Card and Chat')
 end
end
for _,flag in ipairs({'SpyCharacterMenuOpen','SpyPhoneActive','SpyMatchIntroActive','SpyCaseCinematicActive','SpyMatchChatOpen'})do
 player:SetAttribute(flag,true);state.fit()
 check(not visible(matchUI.controls)and not visible(ready)and not visible(state.root),'entire match rail hides under '..flag)
 player:SetAttribute(flag,false)
end
player:SetAttribute('SpyReturningToLobby',true)
check(not visible(matchUI.controls)and not visible(ready)and not visible(state.root),'return transport hides the whole rail through attribute subscription')
player:SetAttribute('SpyReturningToLobby',false)
check(visible(matchUI.controls)and visible(ready)and visible(state.root),'failed return restores navigation through attribute subscription')
session:SetAttribute('RoundPhase','Vote');state.fit()
check(not visible(ready)and not visible(guess),'context actions remain phase gated')
print('Integrated lower HUD: '..checks..' assertions passed (actual owners and client integration; Studio was not run)')
