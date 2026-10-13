-- Private, filtered developer mail. Uses the existing profile store through Profiles.
local Players=game:GetService("Players")
local TextService=game:GetService("TextService")
local RunService=game:GetService("RunService")
local FeedbackService={}
function FeedbackService.start(profiles,shared,openAt)
 local function remote(name)
  local r=shared:FindFirstChild(name)
  if r and not r:IsA("RemoteEvent") then r:Destroy();r=nil end
  if not r then r=Instance.new("RemoteEvent");r.Name=name;r.Parent=shared end
  return r
 end
 local inbox=remote("FeedbackInbox")
 local active,lastRead,lastSend,accepted={},{},{},{}
 local function displayPage(player,data)
  -- Stored broadcast-filtered output is safe for every viewer after the author leaves.
  -- Re-filtering with an offline author would make a cross-server inbox unreadable.
  for _,entry in ipairs(data.entries) do
   if entry.filterVersion~="broadcast_v1" then
    entry.text="Архивное обращение без отметки фильтрации. Текст скрыт."
   end
  end
  return data
 end
 local function answer(player,requestId,ok,code,data)
  if player.Parent==Players then inbox:FireClient(player,{requestId=requestId,ok=ok,code=code,data=data}) end
 end
 inbox.OnServerEvent:Connect(function(player,payload)
  if type(payload)~="table" or type(payload.requestId)~="string" or #payload.requestId>80 then return end
  if player:GetAttribute("SpyIsAdmin")~=true then answer(player,payload.requestId,false,"denied");return end
  local offset,page=payload.dayOffset,payload.page or 1
  if type(offset)~="number" or offset%1~=0 or offset<0 or offset>365 or type(page)~="number" or page%1~=0 or page<1 or page>50 then answer(player,payload.requestId,false,"bad_request");return end
  local now=os.clock()
  if now-(lastRead[player.UserId] or -1000)<.8 then answer(player,payload.requestId,false,"rate_limited");return end
  lastRead[player.UserId]=now
  task.spawn(function()
   local worked,ok,data=pcall(function()
    if payload.command=="read" then return profiles:feedbackPage(offset,page) end
    if payload.command=="review" and type(payload.id)=="string" and #payload.id<=100 then
     local saved,reason=profiles:reviewFeedback(offset,payload.id,player.UserId)
     if not saved then return false,reason end
     return profiles:feedbackPage(offset,page)
    end
    return false,"bad_request"
   end)
   if worked and ok then
    local displayed,value=pcall(displayPage,player,data)
    if displayed then data=value else worked=false end
   end
   answer(player,payload.requestId,worked and ok,worked and (ok and "ok" or tostring(data)) or "read_failed",worked and ok and data or nil)
  end)
 end)
 if openAt then
  local book=remote("FeedbackBook")
  local function result(player,requestId,ok,info)
   if player.Parent==Players then book:FireClient(player,"result",ok,info,RunService:IsStudio(),requestId) end
  end
  book.OnServerEvent:Connect(function(player,category,message,requestId)
   local id=player.UserId
   if type(requestId)~="string" or #requestId>60 or not requestId:match("^%d%d%d%d%d%d%d%d:[%w%-]+$") then return end
   local receipt=accepted[id]
   if receipt and receipt.requestId==requestId then result(player,requestId,true,receipt.id);return end
   if active[id] then result(player,requestId,false,"Предыдущее обращение ещё обрабатывается.");return end
   if not openAt[id] or os.clock()-openAt[id]>180 then result(player,requestId,false,"Открой связь с разработчиком у стойки.");return end
   if not ({bug=true,wish=true,idea=true})[category] or type(message)~="string" then return end
   local clean=message:gsub("%c"," "):gsub("^%s+",""):gsub("%s+$","")
   local length=utf8.len(clean)
   if not length or length<5 or length>240 or #clean>800 then result(player,requestId,false,"Напиши от 5 до 240 символов.");return end
   local remaining=40-(os.clock()-(lastSend[id] or -1000))
   if remaining>0 then result(player,requestId,false,"Следующее обращение через "..math.ceil(remaining).." с.");return end
   local token={};active[id]=token
   task.delay(20,function() if active[id]==token then active[id]=nil;result(player,requestId,false,"Сервис не ответил. Повтори отправку: текст сохранён.") end end)
   task.spawn(function()
    local worked,ok,info=pcall(function()
     local filtered=TextService:FilterStringAsync(clean,id,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
     if type(filtered)~="string" or filtered=="" then return false,"Не удалось проверить текст. Повтори позже." end
     return profiles:submitFeedback(id,category,filtered,requestId)
    end)
    if worked and ok then
     accepted[id]={requestId=requestId,id=info};lastSend[id]=os.clock()
    end
    if active[id]==token then active[id]=nil end
    result(player,requestId,worked and ok,worked and (ok and info or "Не удалось сохранить обращение. Повтори позже.") or "Фильтрация Roblox недоступна. Повтори позже.")
   end)
  end)
 end
 Players.PlayerRemoving:Connect(function(player)
  local id=player.UserId;active[id]=nil;lastRead[id]=nil;lastSend[id]=nil;accepted[id]=nil
 end)
 shared:SetAttribute("SpyFeedbackInboxReady",true)
 return inbox
end
return FeedbackService
