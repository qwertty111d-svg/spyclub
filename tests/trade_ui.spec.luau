-- GUI/service boundaries only. Assertions execute inside the actual script scope.
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
guiClasses.ImageLabel=true;guiClasses.TextBox=true
events.FocusLost=true
function Methods:FindFirstChild(name,recursive)
 for _,child in ipairs(self:GetChildren())do if child.Name==name then return child end end
 if recursive then for _,child in ipairs(self:GetChildren())do local found=child:FindFirstChild(name,true);if found then return found end end end
end
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
function Methods:WaitForChild(name)return self:FindFirstChild(name)end
local focusedBox
function Methods:ReleaseFocus()if focusedBox==self then focusedBox=nil end end
input.GetFocusedTextBox=function()return focusedBox end
local oldIndex=NodeMeta.__index
NodeMeta.__index=function(self,key)local value=oldIndex(self,key);if value~=nil then return value end;for _,child in ipairs(self._children)do if child.Name==key then return child end end end
local oldNew=Instance.new
function Instance.new(class)
 local n=oldNew(class);n.ChildAdded=signal();n.ChildRemoved=signal();n.DescendantAdded=signal();if class=='BindableEvent'then n.Event=signal()end
 if class=='ScreenGui'then n.Size=UDim2.fromScale(1,1)end
 return n
end
Color3.new=function(r,g,b)return{r,g,b}end
Vector2.new=function(x,y)return{X=x or 0,Y=y or 0}end
local fixturePlayer=Instance.new('Player');fixturePlayer.Name='James';fixturePlayer.DisplayName='James Bennett';fixturePlayer.UserId=123;fixturePlayer:SetAttribute('SpyLanguage','ru')
local fixturePg=Instance.new('PlayerGui');fixturePg.AbsoluteSize=Vector2.new(1440,900);fixturePg.Parent=fixturePlayer
local fixtureCamera=Instance.new('Camera');fixtureCamera.ViewportSize=Vector2.new(1440,900)
services.Players={LocalPlayer=fixturePlayer}
local fixtureReplicated=Instance.new('ReplicatedStorage');services.ReplicatedStorage=fixtureReplicated
services.Workspace=Instance.new('Workspace');services.Workspace.CurrentCamera=fixtureCamera
services.RunService={Heartbeat=signal()}
local keyboardSignals={}
function input:GetPropertyChangedSignal(name)
 keyboardSignals[name]=keyboardSignals[name]or signal();return keyboardSignals[name]
end
local guiInsetY=0
guiService.GetGuiInset=function()return Vector2.new(0,guiInsetY),Vector2.zero end
local fixtureSent={}
local fixtureRemote=Instance.new('RemoteEvent');fixtureRemote.FireServer=function(_,payload)fixtureSent[#fixtureSent+1]=payload end
local fixtureCatalog={Items={{id='coat',ru='Бордовый архив',en='Burgundy archive',rarity='rare'},{id='watch',ru='Латунные часы',en='Brass watch',rarity='common'},{id='pin',ru='Значок клуба',en='Club pin',rarity='common'},{id='hat',ru='Шляпа',en='Hat',rarity='common'},{id='five',ru='Пятый предмет',en='Fifth item',rarity='common'},{id='bound',ru='Личный предмет',en='Bound item',rarity='rare'}},ById={},Rarities={rare={ru='Редкий',en='Rare',color={140,150,170}},common={ru='Обычный',en='Common',color={120,125,130}}}}
for _,item in ipairs(fixtureCatalog.Items)do fixtureCatalog.ById[item.id]=item end
fixtureCatalog.tradeInfo=function(id)return{tradeable=id~='bound'}end
-- TRADE_ASSERTIONS_INSERT
Catalog=fixtureCatalog;actionRemote=fixtureRemote
local function find(name)return assert(gui:FindFirstChild(name,true),name)end
local function within(a,b,label)
 local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
 check(p.X>=q.X-.01 and p.Y>=q.Y-.01 and p.X+s.X<=q.X+t.X+.01 and p.Y+s.Y<=q.Y+t.Y+.01,label..' fits')
end
local function separate(a,b,label)
 local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
 check(p.X+s.X<=q.X+.01 or q.X+t.X<=p.X+.01 or p.Y+s.Y<=q.Y+.01 or q.Y+t.Y<=p.Y+.01,label..' separated')
end
local function base()
 snapshot={policy='ready',profile={ready=true,owned={coat=true,watch=true,pin=true,hat=true,five=true,bound=true},itemCounts={coat=3,watch=1}},players={{id=456,name='Vincent',displayName='Vincent'},{id=789,name='Busy',displayName='Busy',busy=true}},invitesEnabled=true,exchangeSamples={{gave={'coat'},received={'watch'}}}}
 inflight=nil;errorKey=nil;drawerOpen=false;current=nil;epoch+=1;lastSequence=0;requests={};retired={};savingSince=nil
end
local function session(stage,give,get)
 return{id='trade-1',revision=3,stage=stage,partner={id=456,name='Vincent',displayName='Vincent'},selfOffer=give or{'coat'},otherOffer=get or{'watch'},inviterId=123,expiresAt=now()+30,confirmAt=now()+10}
end
local function click(name)find(name).Activated:Fire()end
local function lastAction()return fixtureSent[#fixtureSent]end
base();setOpen(true);render()
check(not gui:FindFirstChild('RecentExchanges',true)and not gui:FindFirstChild('RecentExchangesTitle',true),'recent exchange examples are entirely absent even when server data contains samples')
check(find('TradeTitle').Font==Enum.Font.Bodoni,'trade heading uses club serif')
check(find('Invite_456').Active and not find('Invite_789').Active,'directory preserves available versus busy gating')
click('Invite_456');check(lastAction().action=='invite'and lastAction().targetId==456,'directory sends target invite unchanged')
base();current=session('invited');render();check(find('CancelTrade').Visible and not find('AcceptInvite').Visible,'outgoing invitation has cancellation')
click('CancelTrade');check(lastAction().action=='cancel'and lastAction().id=='trade-1','cancel preserves trade identity')
base();current=session('invited');current.inviterId=456;render();check(find('AcceptInvite').Visible and find('DeclineInvite').Visible,'incoming invitation offers both decisions')
click('AcceptInvite');check(lastAction().action=='respond'and lastAction().accept==true,'accept preserves consent protocol')
base();current=session('offering');render();click('SelfSlot_1');check(lastAction().action=='offer'and #lastAction().items==0,'own offered item can be removed')
base();current=session('offering');render();check(not find('OtherSlot_1').Active,'partner items are never editable')
click('AddTradeItems');check(chooser.Visible and not selfOffer.Visible and not otherOffer.Visible,'inventory drawer replaces offers inside content viewport');check(not find('ReadyTrade').Visible,'inventory selection cannot mark unseen offers ready')
check(find('CopyCount').Text=='×3','inventory preserves owned stack count')
check(not find('Item_bound').Active,'protected item remains disabled')
click('Item_watch');check(lastAction().action=='offer'and #lastAction().items==2 and lastAction().items[2]=='watch','inventory click updates real offer')
base();current=session('offering',{'coat','watch','pin','hat'});drawerOpen=true;render();check(not find('Item_five').Active,'fifth selection disabled at four slots')
click('CloseInventory');check(not chooser.Visible and selfOffer.Visible,'drawer done returns to offers')
base();current=session('offering',{},{});render();check(not find('ReadyTrade').Active,'both-empty offer cannot become ready')
base();current=session('offering',{'coat'},{});render();check(giftDisclosure.Visible and string.find(status.Text,tr('giftDetail'),1,true)~=nil,'one-way offer explicitly discloses gift above fixed actions')
click('ReadyTrade');check(lastAction().action=='ready'and lastAction().ready==true,'gift still requires explicit ready')
base();current=session('review');render();check(not find('ConfirmTrade').Active and find('ChangeTradeOffer').Active and find('CancelTrade').Visible,'timed review keeps change and cancel available')
current.confirmAt=now()-1;updateControls();check(find('ConfirmTrade').Active,'confirm unlocks only after review deadline')
click('ConfirmTrade');check(lastAction().action=='confirm'and lastAction().revision==3,'confirmation carries current revision')
base();current=session('review',{'coat'},{});current.confirmAt=now()-1;render();check(find('ConfirmTrade').Text==tr('confirmGift'),'giver confirmation explicitly says gift')
base();current=session('review',{}, {'watch'});current.confirmAt=now()-1;render();check(find('ConfirmTrade').Text==tr('acceptGift'),'receiver confirmation explicitly accepts gift')
click('ChangeTradeOffer');check(lastAction().action=='ready'and lastAction().ready==false,'change returns ready state through server protocol')
base();current=session('saving');savingSince=os.clock()-20;render();check(not find('CancelTrade').Visible and not find('ConfirmTrade').Visible and find('RetryTrade').Visible,'saving hides mutating actions and exposes refresh')
check(status.Text==tr('savingLong'),'long save gets recovery copy')
local before=#fixtureSent;closeTrade();check(#fixtureSent==before and not panel.Visible,'closing saving hides UI without cancelling transaction')
base();current=session('complete');render();check(seal.Visible and find('NewTrade').Visible,'completion has receipt and new exchange')
click('NewTrade');check(current==nil and lastAction().action=='sync','new trade clears receipt and requests fresh state')
base();current=session('offering');render();local beforeClose=#fixtureSent;closeTrade();check(#fixtureSent==beforeClose+1 and lastAction().action=='cancel','closing editable trade cancels server session')
for _,size in ipairs({{1920,1080},{1440,900},{900,600},{360,640},{844,360},{320,568}})do
 fixturePg.AbsoluteSize=Vector2.new(size[1],size[2]);fixtureCamera.ViewportSize=fixturePg.AbsoluteSize
 for _,stage in ipairs({'directory','invited','offering','review','saving','complete','cancelled'})do
  base();current=stage~='directory'and session(stage,{'coat','watch','pin','hat'},{'hat','pin','watch','coat'})or nil;render();setOpen(true)
  within(panel,fixturePg,'trade panel '..stage);within(content,panel,'trade content '..stage);within(status,panel,'trade status '..stage);within(actions,panel,'trade footer '..stage);separate(content,status,'scroll content and status '..stage);separate(content,actions,'scroll content and footer '..stage)
  for _,b in ipairs(actions:GetChildren())do if b:IsA('GuiObject')and b.Visible then within(b,actions,'action '..b.Name);check(b.AbsoluteSize.Y>=44,'action tappable '..b.Name)end end
 end
 base();current=session('offering');drawerOpen=true;render();within(chooser,content,'inventory drawer');within(find('CloseInventory'),chooser,'inventory done');within(find('InventoryItems'),chooser,'inventory list');within(find('InventorySearch'),chooser,'inventory search');separate(find('InventorySearch'),find('InventoryItems'),'inventory search and items')
end
-- A system keyboard must leave search, Done and a usable item row accessible.
for _,viewport in ipairs({{360,640,320,36},{844,360,200,36},{280,640,320,0}})do
 guiInsetY=viewport[4]
 fixturePg.AbsoluteSize=Vector2.new(viewport[1],viewport[2]);fixtureCamera.ViewportSize=fixturePg.AbsoluteSize
 base();current=session('offering');drawerOpen=true;render()
 local search=find('InventorySearch');search.Text='архив';search:GetPropertyChangedSignal('Text'):Fire();focusedBox=search
 local sentBeforeKeyboard=#fixtureSent
 input.OnScreenKeyboardVisible=true;input.OnScreenKeyboardPosition=Vector2.new(0,viewport[3]);input.OnScreenKeyboardSize=Vector2.new(viewport[1],viewport[2]-viewport[3])
 render()
 check(panel.AbsolutePosition.Y+panel.AbsoluteSize.Y<=viewport[3]-guiInsetY-8.01,'trade window remains above system keyboard')
 within(find('InventorySearch'),panel,'keyboard search');within(find('CloseInventory'),panel,'keyboard Done')
 check(find('InventoryItems').AbsoluteSize.Y>=44,'keyboard leaves a touch-sized visible list area')
 check(inventoryDraft=='архив'and find('InventorySearch').Text=='архив'and #fixtureSent==sentBeforeKeyboard,'keyboard layout keeps draft and sends no trade request')
 input.OnScreenKeyboardVisible=false;keyboardSignals.OnScreenKeyboardVisible:Fire()
 check(panel.AbsoluteSize.Y>viewport[3]and drawerOpen,'dismissing keyboard restores regular inventory layout')
 click('CloseInventory');check(focusedBox==nil and not drawerOpen,'Done retires the search focus before returning to offers')
end
guiInsetY=0
base();current=session('offering');drawerOpen=true;render();focusedBox=find('InventorySearch')
current=session('review');render();check(focusedBox==nil and not drawerOpen,'server review transition retires hidden inventory focus')
base();current=session('offering');drawerOpen=true;render();focusedBox=find('InventorySearch')
closeTrade();check(focusedBox==nil and not panel.Visible,'closing the trade retires only its search focus')
-- Real receive path preserves server ordering and pending-save ownership.
base();current=session('saving');received({sequence=2,session=session('offering'),policy='ready',profile={ready=true}});check(current.stage=='saving','stale offering cannot erase in-progress save')
base();current=session('review');current.revision=6;received({sequence=3,session=session('offering'),policy='ready',profile={ready=true}});check(current.stage=='review'and current.revision==6,'old revision cannot replace review')
base();snapshot.policy='blocked';current=session('offering');render();check(not find('ReadyTrade').Active and not find('AddTradeItems').Active,'policy block disables offer changes and ready')
base();snapshot.profile.pendingTrade=true;current=session('offering');render();check(not find('SelfSlot_1').Active and not find('ReadyTrade').Active,'pending inventory lock prevents mutation')
print('Actual trade UI: '..checks..' assertions passed (native rendering not run)')
