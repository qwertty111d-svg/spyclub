local HttpService=game:GetService("HttpService")
local Inbox={}
local C={paper=Color3.fromRGB(239,232,220),muted=Color3.fromRGB(155,139,120),gold=Color3.fromRGB(236,198,128),panel=Color3.fromRGB(26,23,21)}
function Inbox.mount(body,shared)
 local connections={};local alive=true;local remote;local requestId;local offset,page,pages=0,1,1
 local function make(class,parent,props)
  local n=Instance.new(class);for k,v in pairs(props) do n[k]=v end;n.Parent=parent;return n
 end
 local function label(parent,text,height,color)
  return make("TextLabel",parent,{Size=UDim2.new(1,0,0,height),Text=text,TextColor3=color or C.paper,TextSize=12,Font=Enum.Font.BuilderSans,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,RichText=false,BackgroundTransparency=1})
 end
 local function button(parent,name,text,width)
  local b=make("TextButton",parent,{Name=name,Size=UDim2.fromOffset(width,32),Text=text,TextSize=11,Font=Enum.Font.BuilderSans,TextColor3=C.paper,BackgroundColor3=C.panel,BorderSizePixel=0})
  make("UICorner",b,{CornerRadius=UDim.new(0,6)});return b
 end
 label(body,"ОБРАЩЕНИЯ ИГРОКОВ",24,C.gold)
 label(body,"Личный ящик разработчика • сообщения сохраняются между серверами",34,C.muted)
 local controls=make("Frame",body,{Name="InboxControls",Size=UDim2.new(1,0,0,36),BackgroundTransparency=1})
 make("UIListLayout",controls,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6)})
 local older=button(controls,"OlderDay","← День",84)
 local newer=button(controls,"NewerDay","День →",84)
 local refresh=button(controls,"RefreshInbox","Обновить",100)
 local previous=button(controls,"PreviousPage","← Стр.",84)
 local nextPage=button(controls,"NextPage","Стр. →",84)
 local status=label(body,"",36,C.muted);status.Name="InboxStatus"
 local letters=make("Frame",body,{Name="InboxLetters",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
 make("UIListLayout",letters,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
 local request
 local function received(msg)
  if not alive or type(msg)~="table" or msg.requestId~=requestId then return end
  requestId=nil
  if not msg.ok or type(msg.data)~="table" then
   status.Text=msg.code=="rate_limited" and "Подожди секунду и обнови." or "Не удалось получить обращения. Нажми «Обновить».";return
  end
  local data=msg.data;offset,page,pages=data.dayOffset,data.page,data.pages
  status.Text=tostring(data.day).."  •  "..tostring(data.total).." обращений  •  страница "..page.." / "..pages..(data.studio and "  •  тестовый ящик Studio" or "")
  for _,n in ipairs(letters:GetChildren()) do if n:IsA("GuiObject") then n:Destroy() end end
  older.Active=offset<365;newer.Active=offset>0;previous.Active=page>1;nextPage.Active=page<pages
  if #data.entries==0 then label(letters,"За этот день обращений нет. Можно выбрать предыдущий день.",46,C.muted) end
  local category={bug="Ошибка",wish="Пожелание",idea="Идея"}
  for index,entry in ipairs(data.entries) do
   local card=make("Frame",letters,{Name="Letter_"..index,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.panel,BorderSizePixel=0,LayoutOrder=index})
   make("UICorner",card,{CornerRadius=UDim.new(0,6)})
   make("UIPadding",card,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10)})
   make("UIListLayout",card,{Padding=UDim.new(0,6)})
   local author=tostring(entry.username or "");if author=="" then author="Игрок" end
   label(card,(category[entry.category] or "Обращение").."  /  @"..author.."  /  ID "..tostring(entry.userId),28,C.gold)
   local message=label(card,entry.text,0);message.Name="FilteredMessage";message.AutomaticSize=Enum.AutomaticSize.Y;message.TextYAlignment=Enum.TextYAlignment.Top;message.TextSize=14
   label(card,os.date("!%H:%M UTC",entry.createdAt or 0).."  •  Place "..tostring(entry.placeId or "—").."  •  "..tostring(entry.id),34,C.muted)
   if entry.status=="reviewed" then label(card,"Прочитано",20,C.muted)
   else
    local mark=button(card,"ReviewLetter","Отметить прочитанным",200)
    mark.Activated:Connect(function() if not requestId then request("review",entry.id,data.dayOffset,data.page) end end)
   end
  end
 end
 request=function(command,id,letterDay,letterPage)
  if not alive then return end
  if not remote then
   remote=shared:FindFirstChild("FeedbackInbox")
   if remote and remote:IsA("RemoteEvent") then table.insert(connections,remote.OnClientEvent:Connect(received)) else remote=nil end
  end
  if not remote then status.Text="Ящик ещё не подключён. Нажми «Обновить».";return end
  requestId="inbox:"..HttpService:GenerateGUID(false);local token=requestId
  status.Text="Получаем обращения…"
  remote:FireServer({command=command or "read",requestId=token,dayOffset=letterDay or offset,page=letterPage or page,id=id})
  task.delay(12,function() if alive and requestId==token then requestId=nil;status.Text="Сервис не ответил. Нажми «Обновить»." end end)
 end
 older.Activated:Connect(function() if offset<365 then offset+=1;page=1;request("read") end end)
 newer.Activated:Connect(function() if offset>0 then offset-=1;page=1;request("read") end end)
 refresh.Activated:Connect(function() request("read") end)
 previous.Activated:Connect(function() if page>1 then page-=1;request("read") end end)
 nextPage.Activated:Connect(function() if page<pages then page+=1;request("read") end end)
 request("read")
 return {destroy=function() alive=false;for _,connection in ipairs(connections) do connection:Disconnect() end end}
end
return Inbox
