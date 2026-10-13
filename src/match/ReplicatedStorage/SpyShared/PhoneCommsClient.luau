-- Finite social requests and server-filtered, addressed SMS receipts.
local Client={}
function Client.new(player,options)
 local RS=game:GetService('ReplicatedStorage')
 local self={seq=0,pending=false,dead=false,revision=0,connections={},seen={},seenOrder={}}
 local pendingSms
 local function folder()return RS:FindFirstChild('SpyPhoneComms')end
 local function messageValid(d)
  local n=type(d.text)=='string'and utf8.len(d.text)
  return type(d.id)=='string'and #d.id>0 and #d.id<=200 and n and n>=1 and n<=160 and #d.text<=640 and d.text:find('%S')and not d.text:find('[%z\1-\8\11\12\14-\31]')and type(d.at)=='number'and d.at==d.at and math.abs(d.at)<math.huge
 end
 local function receive(d)
  if self.dead or self.seen[d.id]then return end
  self.seen[d.id]=true;table.insert(self.seenOrder,d.id)
  while #self.seenOrder>180 do self.seen[table.remove(self.seenOrder,1)]=nil end
  options.message(d)
 end
 function self:request(p,callback)
  if self.dead or(self.pending and p.action~='end')then return false end
  local context={action=p.action,target=p.target};local isMessage=p.action=='message'
  if isMessage then
   local n=type(p.text)=='string'and utf8.len(p.text)
   if not n or n<1 or n>160 or #p.text>640 or not p.text:find('%S')or p.text:find('[%z\1-\8\11\12\14-\31]')or type(p.messageKey)~='string'or #p.messageKey<1 or #p.messageKey>100 or p.messageKey:find('[%c]')then options.error('invalid',context);return false end
  end
  local f=folder();local r=f and f:FindFirstChild(isMessage and'Event'or'Request')
  if not r then options.error('unavailable',context);return false end
  self.seq+=1;local seq=self.seq;p.seq=seq;self.pending=true;pendingSms=nil;options.busy(true,context)
  local wire=table.clone(p)
  local function valid()return not self.dead and self.seq==seq and self.pending end
  local function finish(code)
   if not valid()then return end
   self.pending=false;pendingSms=nil;options.busy(false,context)
   if code then warn('[SpyPhoneDM] stage='..(isMessage and'send'or'request')..' code='..code);options.error(code,context)end
   if code and callback and type(p.action)=='string'and p.action:sub(1,5)=='club_'then callback({ok=false,code=code})end
  end
  task.delay(8,function()
   if valid()then finish(isMessage and'send_timeout'or'timeout');self.seq+=1 end
  end)
  if isMessage then
   -- Install correlation before sending: a fast receipt may arrive immediately.
   pendingSms={seq=seq,key=p.messageKey,target=p.target,finish=finish,valid=valid,request=wire,callback=callback}
   local ok=pcall(function()r:FireServer(wire)end)
   if not ok then finish('unavailable')end
  else
   task.spawn(function()
    local ok,d=pcall(function()return r:InvokeServer(wire)end)
    if not valid()then return end
    if not ok or type(d)~='table'or not d.ok then finish(type(d)=='table'and d.code or'unavailable');return end
    finish();if d.call then options.call(d.call)end
    if options.response then options.response(p,d)end
    if callback then callback(d)end
   end)
  end
  return true
 end
 local watched={}
 local function listen(n)
  if n.Name~='Event'or not n:IsA('RemoteEvent')or n.Parent~=folder()or watched[n]then return end
  watched[n]=true;self.connections[#self.connections+1]=n.OnClientEvent:Connect(function(d)
   if self.dead or type(d)~='table'then return end
   if d.kind=='sms_receipt'then
    local pending=pendingSms
    if not pending or not pending.valid()or d.seq~=pending.seq or d.requestId~=pending.key then return end
    if d.ok~=true then
     local safe={invalid=true,stale=true,rate=true,blocked=true,left=true,filter=true,send_timeout=true}
     pending.finish(safe[d.code]and d.code or'filter');return
    end
    local m=d.message
    if type(m)~='table'or not messageValid(m)or m.from~=player.UserId or m.peer~=pending.target or m.requestId~=pending.key then pending.finish('filter');return end
    pending.finish();receive(m)
    if options.response then options.response(pending.request,d)end
    if pending.callback then pending.callback(d)end
   elseif d.kind=='message'then
    if type(d.from)~='number'or d.from%1~=0 or d.from==player.UserId or d.peer~=d.from or not messageValid(d)then return end
    receive(d)
   elseif d.kind=='club'and type(d.data)=='table'and options.response then options.response({action='club_push'},{club=d.data})
   elseif d.kind=='call'and type(d.call)=='table'then
    local r=d.call.revision;if type(r)~='number'or r<self.revision then return end
    self.revision=r;options.call(d.call)
   end
  end)
 end
 for _,n in ipairs(RS:GetDescendants())do listen(n)end
 self.connections[#self.connections+1]=RS.DescendantAdded:Connect(listen)
 function self:cancel()self:request({action='end'})end
 function self:destroy()
  self:cancel();self.dead=true;self.seq+=1;pendingSms=nil
  for _,c in ipairs(self.connections)do c:Disconnect()end
  table.clear(self.seen)
 end
 return self
end
return Client
