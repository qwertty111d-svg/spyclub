-- A camera and input lease belongs only to this optional table, never to game boot.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local PromptService=game:GetService("ProximityPromptService")
local player=Players.LocalPlayer
local folder=Storage:WaitForChild("SpyCheckers",45)
local action=folder and folder:WaitForChild("Action",5)
local stateRemote=folder and folder:WaitForChild("State",5)
if not action or not stateRemote then return end
local opened,snapshot,gui,header,footer,status,hint,clockLabel,rulesSheet=false
local selected,padSquare,pending,pendingAt,retryAt=nil,17,false,0,0
local saved,ownedCamera,controls,controlsChanged,promptLease
local renderFrame,overlays,viewportConnection,cameraConnection
local hidden={};local buttons={};local playersLabels={};local localConnections={};local generation=0
local topHeight,bottomHeight=76,108
local cards,counts,teams,hitButtons,hitRects={},{},{},{},{}
local boardInput,projectionDirty,rail,compact=false,true,false,false
local notice,noticeUntil
local fixtureMasks={}
local hideNames={SpyClubUI=true,HudGui=true,SpyLobbyPolishUI=true,SpyCreatorLauncher=true,SpyPlayerDirectory=true}
local C={ink=Color3.fromRGB(25,27,31),cream=Color3.fromRGB(244,240,231),muted=Color3.fromRGB(188,187,181),brass=Color3.fromRGB(221,193,151),green=Color3.fromRGB(147,184,140)}
local function english()return player:GetAttribute("SpyLanguage")=="en"end
local i18n
local shared=Storage:FindFirstChild("SpyShared");local translation=shared and shared:FindFirstChild("I18n")
if translation then local ok,value=pcall(require,translation);if ok then i18n=value end end
local function tr(ru,en)
 if player:GetAttribute("SpyLanguage")=="zh"and i18n then return i18n.text("zh",ru)end
 return english()and en or ru
end
local function gamepad()return Input.PreferredInput==Enum.PreferredInput.Gamepad end
local function make(class,parent,props)
 local n=Instance.new(class);for k,v in pairs(props)do n[k]=v end;n.Parent=parent;return n
end
local function clearFocus()
 pcall(function()local s=GuiService.SelectedObject;if s and gui and s:IsDescendantOf(gui)then GuiService.SelectedObject=nil end end)
end
local function request(kind,fields)
 if not snapshot or not action.Parent then return end
 local payload=fields or{};payload.action=kind;payload.revision=snapshot.revision;action:FireServer(payload)
end
local function close(notify)
 if not opened then return end;opened=false;generation+=1
 clearFocus();pcall(function()Run:UnbindFromRenderStep("SpyCheckersCamera")end)
 for _,c in ipairs(localConnections)do c:Disconnect()end;localConnections={}
 if viewportConnection then viewportConnection:Disconnect();viewportConnection=nil end
 if cameraConnection then cameraConnection:Disconnect();cameraConnection=nil end
 if controls and controlsChanged then pcall(function()controls:Enable()end)end
 controls=nil;controlsChanged=false
 if saved and ownedCamera==workspace.CurrentCamera then
  pcall(function()
   ownedCamera.CFrame=saved.frame;ownedCamera.Focus=saved.focus;ownedCamera.FieldOfView=player:GetAttribute("SpyFOV")or saved.fov
   ownedCamera.CameraSubject=player.Character and player.Character:FindFirstChildOfClass("Humanoid")or saved.subject
   ownedCamera.CameraType=Enum.CameraType.Custom;Input.MouseBehavior=saved.mouse
  end)
 end
 saved=nil;ownedCamera=nil;renderFrame=nil
 if promptLease~=nil then if PromptService.Enabled==false then PromptService.Enabled=promptLease end;promptLease=nil end
 for object,value in pairs(fixtureMasks)do if object.Parent and object.LocalTransparencyModifier==1 then object.LocalTransparencyModifier=value end end;fixtureMasks={}
 for g,enabled in pairs(hidden)do if g.Parent then g.Enabled=enabled end end;hidden={}
 if overlays then overlays:Destroy();overlays=nil end
 if gui then gui:Destroy();gui=nil end
 selected=nil;pending=false;rulesSheet=nil;boardInput=nil;hitButtons={};cards={};counts={};teams={}
 if notify then pcall(function()request("leave")end)end
end
local function label(parent,name,size)
 return make("TextLabel",parent,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Font=Enum.Font.BuilderSansMedium,TextSize=size,TextColor3=C.cream,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd,Active=false})
end
local function button(parent,name,callback)
 local b=make("TextButton",parent,{Name=name,Text="",BackgroundColor3=C.ink,TextColor3=C.cream,Font=Enum.Font.BuilderSansBold,TextSize=14,BorderSizePixel=0,AutoButtonColor=true,Selectable=true,Size=UDim2.fromOffset(100,44)})
 make("UICorner",b,{CornerRadius=UDim.new(0,12)})
 make("UIStroke",b,{Color=C.brass,Transparency=.45,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 b.Activated:Connect(callback);return b
end
local function yourTurn()return snapshot and snapshot.phase=="playing"and snapshot.role>0 and snapshot.role==snapshot.turn end
local function captureRequired()
 if snapshot then for _,m in ipairs(snapshot.moves)do if m.over then return true end end end
 return false
end
local function squareFrame(s,y)
 local c,r=(s-1)%8+1,math.floor((s-1)/8)+1;local center=snapshot.center
 return CFrame.new(center.X+(c-4.5)*snapshot.cell,center.Y+y,center.Z+(4.5-r)*snapshot.cell)
end
local function outlineSquare(s,color,alpha)
 local size=snapshot.cell;local f=squareFrame(s,.008)
 for _,d in ipairs({{size,.006,.009,0,-size*.5},{size,.006,.009,0,size*.5},{.009,.006,size,-size*.5,0},{.009,.006,size,size*.5,0}})do
  make("Part",overlays,{Name="SquareOutline",Size=Vector3.new(d[1],d[2],d[3]),CFrame=f*CFrame.new(d[4],0,d[5]),Color=color,Material=Enum.Material.Fabric,Transparency=alpha or .15,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 end
end
local function drawSelection()
 if overlays then overlays:Destroy()end
 if not opened or not snapshot then return end
 overlays=make("Folder",workspace,{Name="SpyCheckersSelection"})
 if snapshot.lastMove then outlineSquare(snapshot.lastMove.from,C.brass);outlineSquare(snapshot.lastMove.to,C.brass)end
 if yourTurn()and not selected then
  local shown={};for _,m in ipairs(snapshot.moves)do if not shown[m.from]then shown[m.from]=true;outlineSquare(m.from,captureRequired()and C.brass or C.green,.68)end end
 end
 if selected then
  outlineSquare(selected,C.cream)
  for _,m in ipairs(snapshot.moves)do if m.from==selected then
   make("Part",overlays,{Name="LegalDestination",Shape=Enum.PartType.Cylinder,Size=Vector3.new(.006,snapshot.cell*.24,snapshot.cell*.24),CFrame=squareFrame(m.to,.007)*CFrame.Angles(0,0,math.pi*.5),Color=C.green,Material=Enum.Material.Fabric,Transparency=.18,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
  end end
 end
 if gamepad()and yourTurn()then outlineSquare(padSquare,C.green)end
end
local layout,update
local function chooseSquare(s)
 if not yourTurn()or pending or GuiService.MenuIsOpen or(rulesSheet and rulesSheet.Visible)then return end
 if selected then
  for _,move in ipairs(snapshot.moves)do if move.from==selected and move.to==s then
   pending=true;pendingAt=os.clock();retryAt=pendingAt+3;request("move",{from=selected,to=s});update();return
  end end
 end
 for _,move in ipairs(snapshot.moves)do if move.from==s then selected=s;drawSelection();update();return end end
 selected=snapshot.chain
 notice=snapshot.chain and tr("Продолжи взятие отмеченной шашкой.","Continue capturing with the marked piece.")or captureRequired()and tr("Взятие обязательно. Выбери отмеченную шашку.","You must capture. Choose a marked piece.")or tr("У этой шашки нет хода. Выбери отмеченную.","This piece cannot move. Choose a marked piece.")
 noticeUntil=os.clock()+3;drawSelection();update()
end
local function nickname(side)
 local p=snapshot.players[side];if not p then return tr("Свободно","Available")end
 return p.id==0 and tr("Клуб","The Club")or p.name
end
local function showRules()
 rulesSheet.Visible=true;projectionDirty=true;clearFocus()
 if gamepad()then GuiService.SelectedObject=rulesSheet.CloseRules end
end
local function hideRules()rulesSheet.Visible=false;projectionDirty=true;clearFocus();drawSelection()end
local function acquireControls(token)
 task.spawn(function()
  for _=1,60 do
   if not opened or token~=generation then return end
   local ps=player:FindFirstChild("PlayerScripts");local native=ps and ps:FindFirstChild("PlayerModule")
   if native then
    local ok,c=pcall(function()return require(native):GetControls()end)
    if ok and c and opened and token==generation then
     controls=c;controlsChanged=c.controlsEnabled~=false;if controlsChanged then c:Disable()end
    end
    return
   end
   task.wait(.2)
  end
 end)
end
local function projectInput()
 if not opened or not ownedCamera or not boardInput then return end
 for square,b in ipairs(hitButtons)do
  local c,r=(square-1)%8+1,math.floor((square-1)/8)+1
  local x=snapshot.center.X+(c-4.5)*snapshot.cell;local z=snapshot.center.Z+(4.5-r)*snapshot.cell
  local half=snapshot.cell*.5;local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge;local inFront=true
  for _,dx in ipairs({-half,half})do for _,dz in ipairs({-half,half})do
   local p=ownedCamera:WorldToViewportPoint(Vector3.new(x+dx,snapshot.center.Y,z+dz))
   if p.Z<=0 then inFront=false end
   minX=math.min(minX,p.X);minY=math.min(minY,p.Y);maxX=math.max(maxX,p.X);maxY=math.max(maxY,p.Y)
  end end
  b.Position=UDim2.fromOffset(minX,minY);b.Size=UDim2.fromOffset(math.max(1,maxX-minX),math.max(1,maxY-minY))
  b.Visible=inFront and not rulesSheet.Visible;b.Active=yourTurn()and not pending
 end
 projectionDirty=false
end
layout=function()
 if not opened or not ownedCamera or not gui then return end
 local v=ownedCamera.ViewportSize;compact=v.Y<450;rail=(v.X>=1024 and v.Y>=540)or(compact and v.X>v.Y*1.35)
 local cramped=compact and v.Y<320;local panelTop=compact and 96 or 104
 local panelW=compact and 178 or 282;local panelH=math.min(compact and 252 or 390,v.Y-panelTop-12)
 topHeight=rail and(compact and 44 or 54)or(compact and 96 or 104);bottomHeight=rail and 0 or(compact and 112 or 132)
 header.AnchorPoint=Vector2.new(0,0);header.Position=UDim2.fromOffset(20,44);header.Size=UDim2.fromOffset(v.X-40,topHeight);header.BackgroundTransparency=1
 header.Title.Position=UDim2.fromOffset(0,0);header.Title.Size=UDim2.new(1,-106,0,30);header.Title.TextSize=compact and 20 or 26
 header.Subtitle.Visible=not compact;header.Subtitle.Position=UDim2.fromOffset(0,31);header.Subtitle.Size=UDim2.new(1,-110,0,18)
 header.Close.Position=UDim2.new(1,-94,0,0);header.Close.Size=UDim2.fromOffset(94,44)
 if rail then
  footer.AnchorPoint=Vector2.new(1,0);footer.Position=UDim2.new(1,-20,0,panelTop);footer.Size=UDim2.fromOffset(panelW,panelH)
  status.Position=UDim2.fromOffset(14,14);status.Size=UDim2.new(1,clockLabel.Visible and -78 or -28,0,32);status.TextSize=compact and 17 or 23
  clockLabel.Position=UDim2.new(1,-66,0,14);clockLabel.Size=UDim2.fromOffset(52,30)
  hint.Position=UDim2.fromOffset(14,cramped and 39 or compact and 44 or 52);hint.Size=UDim2.new(1,-28,0,cramped and 24 or compact and 28 or 46);hint.TextSize=compact and 12 or 14;hint.Visible=true
  for side,card in ipairs(cards)do
   card.Parent=footer;card.Visible=panelH>=158;card.Position=UDim2.fromOffset(12,(cramped and 65 or compact and 76 or 110)+(side-1)*(cramped and 22 or compact and 44 or 90));card.Size=UDim2.new(1,-24,0,cramped and 20 or compact and 40 or 78)
  end
 else
  local width=math.min(650,v.X-24);footer.AnchorPoint=Vector2.new(.5,1);footer.Position=UDim2.new(.5,0,1,-12);footer.Size=UDim2.fromOffset(width,bottomHeight)
  status.Position=UDim2.fromOffset(12,7);status.Size=UDim2.new(1,clockLabel.Visible and -74 or -24,0,26);status.TextSize=compact and 17 or 21
  clockLabel.Position=UDim2.new(1,-62,0,6);clockLabel.Size=UDim2.fromOffset(50,26)
  hint.Visible=true;hint.Position=UDim2.fromOffset(12,35);hint.Size=UDim2.new(1,-24,0,compact and 24 or 40);hint.TextSize=compact and 11 or 12
  for side,card in ipairs(cards)do
   card.Parent=header;card.Visible=true;card.Position=UDim2.new((side-1)*.5,0,0,52);card.Size=UDim2.new(.5,-5,0,42)
  end
 end
 for side,l in ipairs(playersLabels)do
  l.Position=UDim2.fromOffset(cramped and 28 or 32,rail and not compact and 22 or cramped and 0 or 2);l.Size=UDim2.new(1,rail and not compact and -90 or -68,0,rail and not compact and 30 or cramped and 20 or 22);l.TextSize=rail and not compact and 17 or cramped and 11 or 12
  counts[side].Position=UDim2.new(1,rail and not compact and -56 or -30,0,rail and not compact and 20 or 0);counts[side].Size=UDim2.fromOffset(rail and not compact and 46 or 26,rail and not compact and 40 or cramped and 20 or 25);counts[side].TextSize=rail and not compact and 30 or cramped and 17 or 20
  teams[side].Visible=not cramped;teams[side].Position=UDim2.fromOffset(32,rail and not compact and 4 or 23);teams[side].Size=UDim2.new(1,-50,0,16);teams[side].Font=Enum.Font.BuilderSansMedium;teams[side].TextSize=11
  cards[side].PieceIcon.Size=UDim2.fromOffset(cramped and 13 or 17,cramped and 13 or 17);cards[side].PieceIcon.Position=UDim2.fromOffset(8,rail and not compact and 28 or cramped and 3 or 7)
 end
 local active={};for _,b in pairs(buttons)do b.Visible=false end
 if snapshot.phase=="waiting"or(snapshot.phase=="finished"and(not snapshot.players[1]or not snapshot.players[2]))then
  active=snapshot.role==0 and{buttons.White,buttons.Black,buttons.Rules}or{buttons.Practice,buttons.Rules}
 elseif snapshot.phase=="finished"and snapshot.role>0 then active={buttons.Rematch,buttons.Rules}
 elseif snapshot.role>0 then active={buttons.Draw,buttons.Rules}else active={buttons.Rules}end
 for i,b in ipairs(active)do b.Visible=true;b.Size=UDim2.new(1/#active,-8,0,44);b.Position=UDim2.new((i-1)/#active,4,1,-48);b.TextSize=compact and 11 or 13 end
 rulesSheet.Size=UDim2.fromOffset(math.min(510,v.X-28),math.min(306,v.Y-28))
 local top=44+topHeight+12;local bottom=rail and 12 or(bottomHeight+24)
 local availableY=math.max(80,v.Y-top-bottom);local availableX=math.max(100,v.X-(rail and panelW+64 or 24))
 local visibleWorld=1.86*math.max(v.Y/availableY,v.Y/availableX)
 local distance=visibleWorld/(2*math.tan(math.rad(42)*.5));local flip=snapshot.role==2 and -1 or 1
 local target=snapshot.center+Vector3.new((rail and(panelW+40)*.5 or 0)*visibleWorld/v.Y*flip,0,-(top-bottom)*.5*visibleWorld/v.Y*flip)
 renderFrame=CFrame.lookAt(target+Vector3.new(0,distance,0),target,Vector3.new(0,0,-flip));projectionDirty=true
 local fw,fh=footer.Size.X.Offset,footer.Size.Y.Offset
 hitRects={{20,44,v.X-40,topHeight},{rail and v.X-20-fw or(v.X-fw)*.5,rail and panelTop or v.Y-12-fh,fw,fh}}
end
update=function()
 if not opened or not snapshot or not gui then return end
 header.Title.Text=tr("Шашки","Draughts");header.Subtitle.Text=tr("Русские правила","Russian rules");header.Close.Text=tr("Выйти","Leave")
 for side,l in ipairs(playersLabels)do
  local count=0;for _,p in ipairs(snapshot.pieces)do if p.side==side and not p.captured then count+=1 end end
  local entry=snapshot.players[side];local static=not entry or entry.id==0
  local own=entry and entry.id==player.UserId
  l:SetAttribute("SpyUserText",not static and not own);l:SetAttribute("SpyLocalize",static or own)
  l.Text=own and tr("Ты","You")or nickname(side);counts[side].Text="×"..count
  teams[side].Text=side==1 and tr(own and "Светлые · ты"or"Светлые","Light"..(own and " · you"or""))or tr(own and "Тёмные · ты"or"Тёмные","Dark"..(own and " · you"or""))
  cards[side].BackgroundTransparency=(snapshot.turn==side and snapshot.phase=="playing"or snapshot.winner==side and snapshot.phase=="finished")and .10 or .65
  l.TextColor3=snapshot.turn==side and snapshot.phase=="playing"and C.cream or C.muted
 end
 buttons.White.Text=tr("Светлые","Light");buttons.Black.Text=tr("Тёмные","Dark");buttons.Practice.Text=tr("Тренировка","Practice")
 buttons.White.Active=not snapshot.players[1];buttons.Black.Active=not snapshot.players[2]
 buttons.White.Selectable=buttons.White.Active;buttons.Black.Selectable=buttons.Black.Active
 buttons.White.TextTransparency=buttons.White.Active and 0 or .6;buttons.Black.TextTransparency=buttons.Black.Active and 0 or .6
 buttons.Rules.Text=tr("Правила","Rules");buttons.Rematch.Text=snapshot.rematchVotes and snapshot.rematchVotes[player.UserId]and tr("Ждём согласия","Waiting for reply")or tr("Ещё партия","Play again")
 buttons.Draw.Text=snapshot.drawOffer and snapshot.drawOffer~=player.UserId and tr("Принять ничью","Accept draw")or(snapshot.drawOffer==player.UserId and tr("Ничья предложена","Draw offered")or tr("Ничья","Offer draw"))
 local text,guide
 if snapshot.phase=="waiting"then
  text=tr("Стол свободен","Table available")
  guide=snapshot.role>0 and tr("Жди соперника или начни тренировку.","Wait for a partner or start practice.")or tr("Выбери цвет и займи место за доской.","Choose a colour and take a seat.")
 elseif snapshot.phase=="finished"then
  local result=snapshot.result;local ownWin=snapshot.winner==snapshot.role and snapshot.role>0
  local winnerName=result and result.name or nickname(snapshot.winner)
  if result and result.id==0 then winnerName=tr("Клуб","Club")end
  text=snapshot.winner==0 and tr("Ничья","Draw")or(ownWin and tr("Ты победил","You won")or(snapshot.role>0 and tr("Ты проиграл","You lost")or tr("Партия завершена","Game finished")))
  if not snapshot.players[1]or not snapshot.players[2]then
   guide=snapshot.role>0 and tr("Жди нового соперника или начни тренировку.","Wait for a new partner or start practice.")or tr("Выбери свободное место для новой партии.","Take the available seat to start a new game.")
  else guide=snapshot.reason=="timeout"and tr("Время на ход истекло.","Move time expired.")or tr("Можно договориться о реванше.","You can agree to play again.")end
  if snapshot.winner~=0 then guide=tr("Победитель: ","Winner: ")..winnerName..". "..guide end
 else
  text=yourTurn()and tr("Твой ход","Your turn")or tr("Ход: ","Turn: ")..nickname(snapshot.turn)
  guide=snapshot.role==0 and tr("Ты наблюдаешь за партией.","You are watching this game.")or not yourTurn()and tr("Соперник выбирает ход.","Your opponent is choosing a move.")or snapshot.chain and tr("Продолжи взятие этой фишкой.","Continue capturing with this piece.")or captureRequired()and tr("Взятие обязательно. Выбери отмеченную шашку.","You must capture. Choose a marked piece.")or tr("Выбери отмеченную шашку, затем поле.","Choose a marked piece, then a square.")
 end
 if pending then guide=tr("Подтверждаем ход…","Confirming move…")end
 if notice and os.clock()<noticeUntil then guide=notice end
 status.Text=text;hint.Text=guide
 status:SetAttribute('SpyUserText',true);hint:SetAttribute('SpyUserText',true)
 status.Font=snapshot.phase=="finished"and Enum.Font.BuilderSansBold or Enum.Font.BuilderSansMedium
 clockLabel.Visible=snapshot.phase=="playing"and snapshot.deadline~=nil
 if clockLabel.Visible then clockLabel.Text=tostring(math.max(0,math.ceil(snapshot.deadline-workspace:GetServerTimeNow())))..tr(" с"," s")end
 rulesSheet.RuleText.Text=tr("Ходи по тёмным клеткам. Простая фишка идёт вперёд, бьёт в обе стороны.\n\nВзятие обязательно; цепочку заверши той же фишкой. Дамка ходит и бьёт на расстояние.\n\nПоследний ряд превращает фишку в дамку. На весь ход — 90 секунд.","Use dark squares. Men move forward and capture in both directions.\n\nCapturing is mandatory; finish the chain with the same piece. Kings travel and capture along diagonals.\n\nReaching the last row crowns a king. Each complete turn has 90 seconds.")
 rulesSheet.CloseRules.Text=tr("К доске","Back to board")
 layout()
end
local function open()
 if opened then return end
 -- CHARACTER SCENE HANDOFF BEGIN
 if player:GetAttribute('SpyCharacterSceneActive')==true or player:GetAttribute('SpyCharacterMenuOpen')==true then
  local pg=player:FindFirstChildOfClass('PlayerGui');local close=pg and pg:FindFirstChild('SpyOpenDossier')
  if close and close:IsA('BindableEvent')then close:Fire('close',false)end
  player:SetAttribute('SpyCharacterSceneInterrupt',(tonumber(player:GetAttribute('SpyCharacterSceneInterrupt'))or 0)+1)
 end
 -- CHARACTER SCENE HANDOFF END
 local pg=player:FindFirstChildOfClass("PlayerGui");local camera=workspace.CurrentCamera
 if not pg or not camera then return end
 opened=true;generation+=1;local token=generation;ownedCamera=camera
 if PromptService.Enabled~=false then promptLease=PromptService.Enabled;PromptService.Enabled=false end
 saved={frame=camera.CFrame,focus=camera.Focus,subject=camera.CameraSubject,fov=camera.FieldOfView,mouse=Input.MouseBehavior}
 gui=make("ScreenGui",pg,{Name="SpyCheckersUI",DisplayOrder=640,IgnoreGuiInset=true,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 header=make("Frame",gui,{Name="Header",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,12),BackgroundColor3=C.ink,BackgroundTransparency=.16,BorderSizePixel=0,Active=true})
 footer=make("Frame",gui,{Name="Footer",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-12),BackgroundColor3=C.ink,BackgroundTransparency=.16,BorderSizePixel=0,Active=true})
 make("UICorner",header,{CornerRadius=UDim.new(0,18)})
 make("UICorner",footer,{CornerRadius=UDim.new(0,18)});make("UIStroke",footer,{Color=C.brass,Transparency=.58,Thickness=1})
 label(header,"Title",26).Font=Enum.Font.BuilderSansBold
 local subtitle=label(header,"Subtitle",12);subtitle.Font=Enum.Font.BuilderSansMedium;subtitle.TextColor3=C.muted
 button(header,"Close",function()close(true)end)
 playersLabels={};cards={};counts={};teams={}
 for side=1,2 do
  local card=make("Frame",gui,{Name=side==1 and"LightPlayer"or"DarkPlayer",BackgroundColor3=Color3.fromRGB(58,68,61),BorderSizePixel=0})
  make("UICorner",card,{CornerRadius=UDim.new(0,12)})
  local dot=make("Frame",card,{Name="PieceIcon",Size=UDim2.fromOffset(17,17),BackgroundColor3=side==1 and C.cream or Color3.fromRGB(37,32,28),BorderSizePixel=0})
  make("UICorner",dot,{CornerRadius=UDim.new(1,0)});make("UIStroke",dot,{Color=C.brass,Transparency=.35,Thickness=1})
  cards[side]=card;playersLabels[side]=label(card,side==1 and"WhitePlayer"or"BlackPlayer",17);playersLabels[side]:SetAttribute("SpyUserText",true)
  counts[side]=label(card,"PieceCount",30);counts[side].TextXAlignment=Enum.TextXAlignment.Right
  teams[side]=label(card,"Team",11);teams[side].TextColor3=C.muted
 end
 status=label(footer,"Turn",17);hint=label(footer,"Hint",13);hint.Font=Enum.Font.BuilderSansMedium;hint.TextColor3=C.muted;hint.TextWrapped=true
 clockLabel=label(footer,"Clock",17);clockLabel.TextXAlignment=Enum.TextXAlignment.Right
 buttons={White=button(footer,"White",function()request("join",{side=1})end),Black=button(footer,"Black",function()request("join",{side=2})end),Practice=button(footer,"Practice",function()request("practice")end),Draw=button(footer,"Draw",function()request("draw")end),Rematch=button(footer,"Rematch",function()request("rematch")end),Rules=button(footer,"Rules",showRules)}
 rulesSheet=make("Frame",gui,{Name="RulesSheet",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=C.ink,BorderSizePixel=0,Visible=false,Active=true,ZIndex=10})
 make("UICorner",rulesSheet,{CornerRadius=UDim.new(0,18)})
 local ruleText=label(rulesSheet,"RuleText",15);ruleText.Font=Enum.Font.BuilderSansMedium;ruleText.Position=UDim2.fromOffset(18,14);ruleText.Size=UDim2.new(1,-36,1,-82);ruleText.TextWrapped=true;ruleText.TextYAlignment=Enum.TextYAlignment.Top;ruleText.ZIndex=11
 local back=button(rulesSheet,"CloseRules",hideRules);back.Position=UDim2.new(0,14,1,-58);back.Size=UDim2.new(1,-28,0,44);back.ZIndex=11
 for _,g in ipairs(pg:GetChildren())do if g:IsA("ScreenGui")and hideNames[g.Name]then hidden[g]=g.Enabled;g.Enabled=false end end
 localConnections[#localConnections+1]=pg.ChildAdded:Connect(function(g)if opened and g:IsA("ScreenGui")and hideNames[g.Name]and hidden[g]==nil then hidden[g]=g.Enabled;g.Enabled=false end end)
 local club=workspace:FindFirstChild('SpyClub');local board=club and club:FindFirstChild('SpyCheckers',true);local group=board and board.Parent
 if group then for _,n in ipairs(group:GetDescendants())do if n:IsA('BasePart')and n.Name:sub(1,8)=='CafeLamp'then fixtureMasks[n]=n.LocalTransparencyModifier;n.LocalTransparencyModifier=1 end end end
 viewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
 cameraConnection=workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()close(true)end)
 Run:BindToRenderStep("SpyCheckersCamera",Enum.RenderPriority.Camera.Value+1,function()
  if not opened or not renderFrame then return end
  local ok=pcall(function()camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=renderFrame;camera.Focus=CFrame.new(snapshot.center);camera.FieldOfView=42;Input.MouseBehavior=Enum.MouseBehavior.Default;if projectionDirty then projectInput()end end)
  if not ok then close(true)end
 end)
 boardInput=make("Frame",gui,{Name="BoardInput",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,Active=false,ZIndex=1})
 hitButtons={}
 for square=1,64 do
  local b=make("TextButton",boardInput,{Name="Square"..square,Text="",BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Selectable=false,ZIndex=1})
  b.Activated:Connect(function()chooseSquare(square)end);hitButtons[square]=b
 end
 camera.CameraType=Enum.CameraType.Scriptable;update();camera.CFrame=renderFrame;camera.FieldOfView=42;projectInput()
 acquireControls(token)
end
local function message(code)
 if code=="rate_limited"then return tr("Ход не принят. Выбери поле ещё раз.","Move not accepted. Choose the square again.")end
 if code=="stale"then return tr("Состояние обновлено. Выбери ход ещё раз.","State updated. Choose your move again.")end
 if code=="occupied"then return tr("Это место уже занято.","That seat is taken.")end
 if code=="not_turn"then return tr("Сейчас ход соперника.","It is your opponent's turn.")end
 if code=="waiting_opponent"then return tr("Нужен второй игрок.","A second player is needed.")end
 if code=="illegal_move"then return tr("Выбери подсвеченное поле.","Choose a lit square.")end
 return tr("Действие сейчас недоступно.","That action is unavailable right now.")
end
local function receive(data)
 if type(data)~="table"or type(data.revision)~="number"or not data.center or type(data.pieces)~="table"then return end
 if data.closed then close(false);return end
 if snapshot and data.revision<snapshot.revision then return end
 if not opened and not data.open then return end
 local changed=not snapshot or data.revision~=snapshot.revision
 snapshot=data
 if changed or data.ok==false or(pending and data.code=="state")then pending=false;selected=yourTurn()and data.chain or nil end
 if changed then notice=nil;noticeUntil=0;projectionDirty=true;padSquare=data.moves[1]and data.moves[1].from or 17 end
 if data.ok==false then notice=message(data.code);noticeUntil=os.clock()+3 end
 if data.open then open()end
 if not opened then return end
 update();drawSelection()
 local focus=GuiService.SelectedObject
 if focus and focus:IsDescendantOf(gui)and(not focus.Visible or not focus.Active)then clearFocus()end
 if yourTurn()then clearFocus()
 elseif gamepad()and not GuiService.SelectedObject then
  for _,b in ipairs({buttons.White,buttons.Black,buttons.Practice,buttons.Rematch,buttons.Rules})do if b.Visible and b.Active then GuiService.SelectedObject=b;break end end
 end
end
local remoteConnection=stateRemote.OnClientEvent:Connect(function(data)
 local ok,err=pcall(receive,data)
 if not ok then close(true);warn("[SpyCheckers] Panel closed: "..tostring(err))end
end)
local function hit(position)
 if not opened or not yourTurn()or GuiService.MenuIsOpen then return end
 local v=ownedCamera.ViewportSize
 local inset=GuiService:GetGuiInset();local screenY=position.Y+inset.Y
 local screenX=position.X+inset.X
 for _,rect in ipairs(hitRects)do if screenX>=rect[1]and screenX<=rect[1]+rect[3]and screenY>=rect[2]and screenY<=rect[2]+rect[4]then return end end
 local ray=ownedCamera:ScreenPointToRay(position.X,position.Y)
 if math.abs(ray.Direction.Y)<.001 then return end
 local t=(snapshot.center.Y-ray.Origin.Y)/ray.Direction.Y;if t<=0 then return end
 local p=ray.Origin+ray.Direction*t;local half=snapshot.cell*4
 local c=math.floor((p.X-snapshot.center.X+half)/snapshot.cell)+1
 local r=math.floor((snapshot.center.Z-p.Z+half)/snapshot.cell)+1
 if c>=1 and c<=8 and r>=1 and r<=8 then chooseSquare((r-1)*8+c)end
end
local began=Input.InputBegan:Connect(function(input,processed)
 if not opened then return end
 if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then
  if rulesSheet.Visible then hideRules()else close(true)end;return
 end
 if not gamepad()or GuiService.SelectedObject or processed then return end
 if input.KeyCode==Enum.KeyCode.ButtonA then chooseSquare(padSquare);return end
 local d=({[Enum.KeyCode.DPadLeft]={-1,0},[Enum.KeyCode.DPadRight]={1,0},[Enum.KeyCode.DPadUp]={0,1},[Enum.KeyCode.DPadDown]={0,-1}})[input.KeyCode]
 if d then local flip=snapshot.role==2 and -1 or 1;local c,r=(padSquare-1)%8+1,math.floor((padSquare-1)/8)+1;c=math.clamp(c+d[1]*flip,1,8);r=math.clamp(r+d[2]*flip,1,8);padSquare=(r-1)*8+c;drawSelection()end
end)
local ended=Input.InputEnded:Connect(function(input,processed)
 if not opened or processed then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then hit(input.Position)end
end)
local preference=Input:GetPropertyChangedSignal("PreferredInput"):Connect(function()if opened then if not gamepad()then clearFocus()end;drawSelection()end end)
local language=player:GetAttributeChangedSignal("SpyLanguage"):Connect(function()if opened then update()end end)
local character=player.CharacterRemoving:Connect(function()close(true)end)
local tick=Run.Heartbeat:Connect(function()
 if not opened then return end
 if pending and os.clock()-pendingAt>=10 then close(true);return end
 if pending and os.clock()>=retryAt then retryAt=os.clock()+3;request("sync")end
 if notice and os.clock()>=noticeUntil then notice=nil;update()end
 if clockLabel and clockLabel.Visible and snapshot.deadline then clockLabel.Text=tostring(math.max(0,math.ceil(snapshot.deadline-workspace:GetServerTimeNow())))..tr(" с"," s")end
end)
script.Destroying:Connect(function()
 close(true);remoteConnection:Disconnect();began:Disconnect();ended:Disconnect();preference:Disconnect();language:Disconnect();character:Disconnect();tick:Disconnect()
end)
