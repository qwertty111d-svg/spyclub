-- Optional phone controller. No dependency is permitted to gate boot or native chat.
local IN_MATCH=false
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService');local Gui=game:GetService('GuiService')
local player=Players.LocalPlayer;local parent=player:WaitForChild('PlayerGui',8);local shared=RS:WaitForChild('SpyShared',8)
if not parent or not shared then return end
local function module(name)
 local node=shared:WaitForChild(name,8)
 if not node then warn('[SpyPhone] Missing module: '..name);return nil end
 local ok,v=pcall(require,node);if ok then return v end
 warn('[SpyPhone] '..name..': '..tostring(v))
end
local State=module('PhoneState');local UI=module('PhoneUI');local Files={};local Pose=module('PhonePose')
if not State or not UI or not Pose then return end
local Social=module('PhoneSocial');local Comms=module('PhoneCommsClient');local Audio=module('PhoneAudio')
if not Social or not Comms or not Audio then return end
local social;local audio=Audio.new(player);local phoneDestroyed=false;local resumeArrival;local arrivalHandled=false;local lightGeneration=0;local requestLight;local notebook;local navigator;local camera
local pose=Pose.start();local visible=false;local seq=0;local awaiting;local launchGeneration=0;local altDown=false;local altChord=false;local ui;local connections={};local close;local deathConnection;local characterSerial=0
local function lang()return player:GetAttribute('SpyLanguage')or'ru'end
local function blocked()
 for _,key in ipairs(State.Blocked)do if player:GetAttribute(key)==true then return true end end
 local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid');return not h or h.Health<=0
end
local function obscured()return blocked()or player:GetAttribute('SpyCaseCinematicActive')==true or player:GetAttribute('SpyPhoneCameraActive')==true end
local function remote(name)local f=RS:FindFirstChild('SpyPhoneRemotes');return f and f:FindFirstChild(name)end
local function transmit(open)
 seq+=1;local current=seq;awaiting=current
 local r=remote('Request')
 if not r then awaiting=nil;visible=false;if ui then ui:hide();ui:error('unavailable')end;return false end
 r:FireServer({open=open,seq=current})
 task.delay(5,function()if awaiting==current then awaiting=nil;close(false);seq+=1;local cleanup=remote('Request');if cleanup then cleanup:FireServer({open=false,seq=seq})end;if ui then ui:error('timeout')end end end)
 return true
end
close=function(send)
 lightGeneration+=1;if ui then ui.lightPending=false end
 if camera then camera:stop(false)end
 visible=false;launchGeneration+=1
 if ui then ui.flash=false end
 if social and send~=false then social:cancel()end;audio:stopRing()
 if ui then ui:hide()end;if send~=false then transmit(false)end
end
local function show(app)
 if blocked()or player:GetAttribute('SpyCaseCinematicActive')==true or player:GetAttribute('SpyMatchIntroActive')==true then if ui then ui:error('blocked')end;return end
 if ui and ui.flash and requestLight then requestLight(false)end
 if camera and camera.active then camera:stop(false)end
 if app=='camera'and not IN_MATCH then
  if not camera then ui:error('unavailable');return end
  if not visible then if not transmit(true)then return end;visible=true end
  ui:hide();if not camera:start()then ui:show('home');ui:error('blocked')end;return
 end
 if app=='light'or app=='cases'or app=='line'or app=='decoder'or app=='evidence'or app=='mission_camera'or app=='camera'then app='home'end
 if not visible then if not transmit(true)then return end;visible=true end
 ui:show(app)
end
local function toggle()if visible then close()else show('home')end end
local function launch(key,arg)
 local event=parent:FindFirstChild('SpyPhoneLaunch');local token
 launchGeneration+=1;token=launchGeneration
 if not event or not event:IsA('BindableEvent')then ui:error('unavailable');return end
 ui:busy(true);event:Fire(key,arg,token)
 task.delay(3,function()if token==launchGeneration and visible and ui.pending then launchGeneration+=1;ui:busy(false);ui:error('timeout')end end)
end
ui=UI.new(parent,State,Files,{inMatch=IN_MATCH,language=lang,blocked=obscured,toggle=toggle,close=close,feedback=function(key)audio:effect(key)end,launch=launch,caseRequest=function()end,profile=function()end})
social=Comms.new(player,{busy=function(v,context)ui:busy(v,context)end,error=function(k,context)local wasLink=ui.linkLoading;ui.linkLoading=false;if wasLink and ui.linkFailed then ui:linkFailed()end;ui:error(k,context)end,response=function(_,d)
 if d.contact and ui.addContact then ui:addContact(d.contact)end
 if d.club and ui.receiveClub then ui:receiveClub(d.club)end
end,call=function(d)
 if d.phase=='ringing'and d.incoming and ui.flash and requestLight then requestLight(false);ui:setTorch(false)end
 ui:setCall(d);audio:ring(d.phase=='ringing'and d.incoming and not obscured())
end,message=function(d)
 ui:receiveMessage(d)
 if d.from~=player.UserId then if not obscured()then audio:effect('message')end else audio:effect('sent');ui:ackMessage(d);if visible and ui.app=='messages'and ui.peer==d.peer and not Input:GetFocusedTextBox()then ui:render()end end
end})
Social.attach(ui,{request=function(p,callback)return social:request(p,callback)end,openChat=function()
 local event=parent:FindFirstChild('SpyOpenChat')
 if not event or not event:IsA('BindableEvent')then ui:error('unavailable');return end
 close();event:Fire()
end,openCall=function()show('calls')end,camera=function()show('camera')end,
 noteLoad=function()if notebook then notebook:load()end end,
 noteSave=function()if notebook then notebook:save()else ui:error('note_loading')end end,
 noteReload=function()if notebook then notebook:reload()end end,
 noteChanged=function()if notebook then notebook:changed()end end,
 sound=function(k,v)audio:set(k,v);if k=='quiet'or k=='ringtone'then audio:ring(ui.call.phase=='ringing'and ui.call.incoming and not obscured())end end})
connections[#connections+1]=player:GetAttributeChangedSignal('SpyPhoneFlash'):Connect(function()if ui.setTorch then ui:setTorch(player:GetAttribute('SpyPhoneFlash')==true)end end)
local clockElapsed=0
connections[#connections+1]=game:GetService('RunService').Heartbeat:Connect(function(dt)clockElapsed+=dt;if clockElapsed>=.5 then clockElapsed=0;if visible then ui:updateClock()end end end)
local open=parent:FindFirstChild('SpyOpenPhone')or Instance.new('BindableEvent');open.Name='SpyOpenPhone';open.Parent=parent
local ack=parent:FindFirstChild('SpyPhoneLaunchAck')or Instance.new('BindableEvent');ack.Name='SpyPhoneLaunchAck';ack.Parent=parent
connections[#connections+1]=ack.Event:Connect(function(token,ok)
 if token~=launchGeneration or not visible then return end
 ui:busy(false);if ok then close()else ui:error('unavailable')end
end)
connections[#connections+1]=open.Event:Connect(function(app)show(app or'home')end)
local watched=setmetatable({},{__mode='k'})
local function listen(r)
 if r.Name~='State'or not r:IsA('RemoteEvent')or not r.Parent or r.Parent.Name~='SpyPhoneRemotes'or watched[r]then return end
 watched[r]=true;connections[#connections+1]=r.OnClientEvent:Connect(function(value)
  if type(value)~='table'or type(value.seq)~='number'or value.seq<seq then return end
  awaiting=nil
  if type(value.flash)=='boolean'and ui.setTorch then lightGeneration+=1;ui.lightPending=false;ui:setTorch(value.flash);if value.code then ui:error(value.code)end end
  if value.open~=true and(visible or(camera and camera.active))then close(false) end
 end)
end
for _,r in ipairs(RS:GetDescendants())do listen(r)end
connections[#connections+1]=RS.DescendantAdded:Connect(listen)
local function canAlt(chord)
 -- Roblox may handle the modifier itself; text focus/menu/chords decide eligibility.
 return not Gui.MenuIsOpen and State.canKey(Input:GetFocusedTextBox()~=nil,chord,false)
end
connections[#connections+1]=Input.InputBegan:Connect(function(key,processed)
 if key.KeyCode==Enum.KeyCode.LeftAlt or key.KeyCode==Enum.KeyCode.RightAlt then altDown=canAlt(false);altChord=false
 elseif altDown then altChord=true end
end)
connections[#connections+1]=Input.InputEnded:Connect(function(key,processed)
 if key.KeyCode==Enum.KeyCode.LeftAlt or key.KeyCode==Enum.KeyCode.RightAlt then
  local allow=altDown and canAlt(altChord);altDown=false;altChord=false;if allow then toggle()end
 elseif(key.KeyCode==Enum.KeyCode.Escape or key.KeyCode==Enum.KeyCode.ButtonB)and visible then close()
 elseif key.KeyCode==Enum.KeyCode.ButtonY and not processed and not Input:GetFocusedTextBox()then toggle()end
end)
connections[#connections+1]=Input.WindowFocusReleased:Connect(function()altDown=false;altChord=true end)
local function characterReady(c)
 characterSerial+=1;local id=characterSerial
 if deathConnection then deathConnection:Disconnect();deathConnection=nil end
 ui:resize()
 task.spawn(function()
  local h=c:WaitForChild('Humanoid',5)
  if id~=characterSerial or player.Character~=c or not h then return end
  deathConnection=h.Died:Connect(function()close();ui:resize()end)
  ui:resize()
  if resumeArrival then resumeArrival()end
 end)
end
connections[#connections+1]=player.CharacterRemoving:Connect(function()characterSerial+=1;if deathConnection then deathConnection:Disconnect();deathConnection=nil end;close();ui:resize()end)
connections[#connections+1]=player.CharacterAdded:Connect(characterReady)
if player.Character then characterReady(player.Character)end
for _,key in ipairs(State.Blocked)do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(function()if blocked()and(visible or(camera and camera.active))then close()end;ui:resize();if resumeArrival then resumeArrival()end end)end
for _,key in ipairs({'SpyCaseCinematicActive','SpyPhoneCameraActive'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(function()
 if camera and camera.active and player:GetAttribute('SpyCaseCinematicActive')==true then close()end
 if obscured()then audio:stopRing()else audio:ring(ui.call.phase=='ringing'and ui.call.incoming)end;ui:resize()
end)end
connections[#connections+1]=player:GetAttributeChangedSignal('SpyLanguage'):Connect(function()ui:render()end)
-- Attach optional social screens after keyboard handlers. Their failure cannot disable ALT.
local function connectScreens(node)
 if phoneDestroyed or ui.connectUI or not node or node.Name~='PhoneConnectUI'or node.Parent~=shared then return end
 local oldRender,oldResize,oldTr=ui.render,ui.resize,ui.tr
 local ok,err=pcall(function()return require(node).attach(ui,State,{request=function(p,callback)return social:request(p,callback)end})end)
 if not ok then ui.connectUI=nil;ui.render=oldRender;ui.resize=oldResize;ui.tr=oldTr;warn('[SpyPhone] PhoneConnectUI: '..tostring(err));ui:render()end
 if ok and resumeArrival then resumeArrival()end
end
-- New phone apps are optional too: failures cannot disable ALT or hold game boot.
local function connectPersonal(node)
 if phoneDestroyed or not node or node.Parent~=shared then return end
 if node.Name=='PhoneCamera'and not IN_MATCH and not camera then
  local ok,value=pcall(function()return require(node).new(ui.gui,lang,{blocked=function()return phoneDestroyed or blocked()or player:GetAttribute('SpyCaseCinematicActive')==true or player:GetAttribute('SpyMatchIntroActive')==true end,onStop=function()if visible and not obscured()then ui:show('home')end end,photo=function(id)if camera then camera:save(id)end end,error=function(key)ui:error(key)end})end)
  if ok then camera=value else warn('[SpyPhone] Camera unavailable: '..tostring(value))end
 elseif node.Name=='PhonePersonalClient'and not notebook then
  local ok,value=pcall(function()return require(node).new(ui)end)
  if ok then notebook=value else warn('[SpyPhone] Notes unavailable: '..tostring(value))end
 elseif node.Name=='PhoneNavigator'and not navigator then
  local render,tr=ui.render,ui.tr
  local ok,value=pcall(function()return require(node).new(ui,{inMatch=IN_MATCH,close=close})end)
  if ok then navigator=value else ui.render=render;ui.tr=tr;warn('[SpyPhone] Navigator unavailable: '..tostring(value))end
 end
end
connectPersonal(shared:FindFirstChild('PhoneCamera'));connectPersonal(shared:FindFirstChild('PhonePersonalClient'));connectPersonal(shared:FindFirstChild('PhoneNavigator'))
connections[#connections+1]=shared.ChildAdded:Connect(connectPersonal)
connectScreens(shared:FindFirstChild('PhoneConnectUI'))
connections[#connections+1]=shared.ChildAdded:Connect(connectScreens)
connections[#connections+1]=player:GetAttributeChangedSignal('SpyPhoneNumber'):Connect(function()ui:resize()end)
resumeArrival=function()
 if IN_MATCH or phoneDestroyed or arrivalHandled or not ui.connectUI or player:GetAttribute('SpyEntryCompleted')~=true or obscured()then return end
 local id=player:GetAttribute('SpyClubLinkTarget')
 if type(id)~='number'or id==player.UserId or not State.number(id)then return end
 show('contacts');if not visible then return end
 arrivalHandled=true;ui.peer=id;ui:render()
 social:request({action='lookup',target=id},function(d)if visible and ui.app=='contacts'and ui.peer==id then ui:showContact(d.contact)end end)
end
for _,key in ipairs({'SpyEntryCompleted','SpyClubLinkTarget'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(resumeArrival)end
resumeArrival()
script.Destroying:Connect(function()phoneDestroyed=true;characterSerial+=1;if deathConnection then deathConnection:Disconnect()end;close();for _,c in ipairs(connections)do c:Disconnect()end;pose.destroy();social:destroy();audio:destroy();if camera then camera:destroy()end;if notebook then notebook:destroy()end;if navigator then navigator:destroy()end;ui:destroy()end)
