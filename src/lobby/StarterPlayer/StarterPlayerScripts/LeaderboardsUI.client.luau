-- Each visitor browses independently. SurfaceGui controls live in PlayerGui;
-- Workspace-owned SurfaceGuis cannot receive GUI input.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
local pg=player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",5))
if not pg or pg:FindFirstChild("SpyBoardWins") then return end
local C={ink=Color3.fromRGB(20,21,22),paper=Color3.fromRGB(236,230,216),gold=Color3.fromRGB(190,153,99),
 muted=Color3.fromRGB(159,157,151),raised=Color3.fromRGB(31,32,33),line=Color3.fromRGB(70,65,56)}
local boards,remote,observed={},nil,nil
local keys={"Wins","Coins","Level","Supporters"}
local function make(class,parent,props)
 local n=Instance.new(class);for k,v in pairs(props)do n[k]=v end;n.Parent=parent;return n
end
local function text(parent,name,caption,pos,size,fontSize,color)
 return make("TextLabel",parent,{Name=name,Text=caption,Position=pos,Size=size,TextSize=fontSize,Font=Enum.Font.BuilderSans,
  TextColor3=color or C.paper,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
  TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,RichText=false})
end
local function button(parent,name,caption,pos,size,callback)
 local b=make("TextButton",parent,{Name=name,Text=caption,Position=pos,Size=size,BackgroundColor3=C.raised,
  TextColor3=C.paper,TextSize=25,Font=Enum.Font.BuilderSansMedium,BorderSizePixel=0,AutoButtonColor=true,Selectable=true})
 make("UICorner",b,{CornerRadius=UDim.new(0,4)})
 b.Activated:Connect(function()if b.Active then callback()end end);return b
end
local function ru(a,b)return player:GetAttribute("SpyLanguage")=="en" and b or a end
local request
local function controls(b)
 b.previous.Active=not b.pending and b.page>1
 b.next.Active=not b.pending and b.page<b.pages
 b.refresh.Active=not b.pending
 for _,control in ipairs({b.previous,b.next,b.refresh})do control.TextTransparency=control.Active and 0 or .65 end
end
local function bind()
 local folder=Storage:FindFirstChild("SpyLeaderboards")
 local send=folder and folder:FindFirstChild("Request")
 local state=folder and folder:FindFirstChild("State")
 if not send or not state then return end
 remote=send
 if observed==state then return end
 observed=state
 state.OnClientEvent:Connect(function(payload)
  if type(payload)~="table" then return end
  local b=boards[payload.board]
  if not b or not b.pending or b.pending~=payload.id then return end
  b.pending=nil
  if payload.ok~=true or type(payload.rows)~="table" then
   b.status.Text=ru("Рейтинг ещё не готов. Нажми обновление.","Ranking is not ready. Press refresh.");controls(b);return
  end
  b.page=math.max(1,tonumber(payload.page) or 1);b.pages=math.max(1,tonumber(payload.pages) or 1)
  b.pageLabel.Text=b.page.." / "..b.pages
  for _,node in ipairs(b.rows:GetChildren())do node:Destroy()end
  for index,entry in ipairs(payload.rows)do
   if index>5 then break end
   local row=make("Frame",b.rows,{Name="Rank_"..tostring(entry.rank),Position=UDim2.fromOffset(0,(index-1)*94),
    Size=UDim2.new(1,0,0,83),BackgroundColor3=C.raised,BorderSizePixel=0})
   local first=entry.rank==1
   text(row,"Rank",string.format("%02d",tonumber(entry.rank) or 0),UDim2.fromOffset(16,0),UDim2.fromOffset(72,83),31,first and C.gold or C.muted)
   local name=text(row,"PlayerName",tostring(entry.name or ""),UDim2.fromOffset(94,10),UDim2.new(1,-230,0,63),25)
   name.Font=Enum.Font.BuilderSansMedium
   local value=text(row,"Value",tostring(entry.value or 0),UDim2.new(1,-132,0,10),UDim2.fromOffset(116,63),28,first and C.gold or C.paper)
   value.Font=Enum.Font.RobotoMono;value.TextXAlignment=Enum.TextXAlignment.Right
  end
  b.status.Text=payload.stale and ru("Последний сохранённый рейтинг", "Last saved ranking")
   or #payload.rows==0 and ru("Здесь скоро появятся участники", "Members will appear here soon")
   or ru("Топ 100 · весь опыт", "Top 100 · entire experience")
  controls(b)
 end)
 for index,key in ipairs(keys)do task.delay(index*.35,function()local b=boards[key];if b and not b.pending then request(b,b.page)end end)end
end
request=function(b,page)
 if b.pending then return end
 bind()
 if not remote then b.status.Text=ru("Рейтинг не подключён. Нажми обновление.","Ranking is not connected. Press refresh.");controls(b);return end
 local id=Http:GenerateGUID(false);b.pending=id;controls(b)
 b.status.Text=ru("Получаем страницу…", "Fetching page…")
 remote:FireServer({id=id,board=b.key,page=page})
 task.delay(8,function()
  if b.pending~=id then return end
  b.pending=nil;b.status.Text=ru("Ответ задерживается. Нажми обновление.","Response delayed. Press refresh.");controls(b)
 end)
end
local function install(key)
 if boards[key] then return end
 local club=workspace:FindFirstChild("SpyClub")
 local model=club and club:FindFirstChild("Board"..key)
 local panel=model and model:FindFirstChild("Panel")
 local old=panel and panel:FindFirstChild("Sign")
 if not panel or not panel:IsA("BasePart") or not old then return end
 -- FixedSize maps the whole canvas onto the physical face. Equal X/Y on
 -- a wide board stretches every glyph. Keep pixels per stud equal on both axes.
 local dimensions=panel.Size
 local width,height=dimensions.X,dimensions.Y
 if old.Face==Enum.NormalId.Top or old.Face==Enum.NormalId.Bottom then
  width,height=dimensions.X,dimensions.Z
 elseif old.Face==Enum.NormalId.Left or old.Face==Enum.NormalId.Right then
  width,height=dimensions.Z,dimensions.Y
 end
 local canvasHeight=700
 local canvasWidth=math.max(350,math.floor(canvasHeight*width/math.max(.01,height)+.5))
 local gui=make("SurfaceGui",pg,{Name="SpyBoard"..key,Adornee=panel,Face=old.Face,Active=true,
  SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,CanvasSize=Vector2.new(canvasWidth,canvasHeight),LightInfluence=.25,
  AlwaysOnTop=false,MaxDistance=70,ClipsDescendants=true,ZOffset=.01})
 local body=make("Frame",gui,{Name="BoardBody",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BorderSizePixel=0})
 text(body,"Period",key=="Coins" and ru("ПОЛУЧЕНО ЗА ВСЁ ВРЕМЯ","LIFETIME COINS RECEIVED") or ru("ЗА ВСЁ ВРЕМЯ","ALL TIME"),
  UDim2.fromOffset(28,16),UDim2.new(1,-56,0,54),24,C.gold).Font=Enum.Font.BuilderSansMedium
 local rows=make("Frame",body,{Name="Rows",Position=UDim2.fromOffset(26,86),Size=UDim2.new(1,-52,0,470),BackgroundTransparency=1})
 local b={key=key,page=1,pages=1,rows=rows,gui=gui}
 boards[key]=b
 b.pageLabel=text(body,"Page","1 / 1",UDim2.new(.5,-70,0,578),UDim2.fromOffset(140,52),26,C.paper)
 b.pageLabel.TextXAlignment=Enum.TextXAlignment.Center
 b.previous=button(body,"Previous","‹",UDim2.fromOffset(28,574),UDim2.fromOffset(84,60),function()request(b,b.page-1)end)
 b.next=button(body,"Next","›",UDim2.new(1,-112,0,574),UDim2.fromOffset(84,60),function()request(b,b.page+1)end)
 b.refresh=button(body,"Refresh","↻",UDim2.new(1,-208,0,574),UDim2.fromOffset(72,60),function()request(b,b.page)end)
 b.status=text(body,"BoardStatus",ru("Подключаем рейтинг…","Connecting ranking…"),UDim2.fromOffset(28,645),UDim2.new(1,-56,0,36),19,C.muted)
 old.Enabled=false;controls(b)
 task.delay(table.find(keys,key)*.35,function()request(b,1)end)
end
local function scan()for _,key in ipairs(keys)do install(key)end end
Storage.ChildAdded:Connect(function(item)
 if item.Name=="SpyLeaderboards" then item.ChildAdded:Connect(bind);bind()end
end)
local queued=false
workspace.DescendantAdded:Connect(function(item)
 if item.Name~="SpyClub" and item.Name~="Panel" and item.Name~="Sign" and not string.find(item.Name,"^Board") then return end
 if queued then return end;queued=true
 task.defer(function()queued=false;scan()end)
end)
local initial=Storage:FindFirstChild("SpyLeaderboards")
if initial then initial.ChildAdded:Connect(bind)end
scan();bind()
task.spawn(function()
 while task.wait(60)do
  for index,key in ipairs(keys)do task.delay(index*.35,function()local b=boards[key];if b then request(b,b.page)end end)end
 end
end)
