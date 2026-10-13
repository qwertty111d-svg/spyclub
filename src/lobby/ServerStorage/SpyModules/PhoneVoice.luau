-- Existing eligible microphones; consent and compatibility checked before routing.
-- No forced unmute and no change to global VoiceChatService configuration.
local Voice={}
local function equal(a,b)
 if #a~=#b then return false end
 for i,id in ipairs(a)do if id~=b[i]then return false end end;return true
end
function Voice.start(a,b,valid)
 local service=game:GetService('VoiceChatService')
 if service.UseAudioApi~=Enum.AudioApiRollout.Enabled then return nil end
 local ia=a:FindFirstChildOfClass('AudioDeviceInput');local ib=b:FindFirstChildOfClass('AudioDeviceInput')
 if not ia or not ib or ia.Player~=a or ib.Player~=b then return nil end
 local ok,groups=pcall(function()return service:GetChatGroupsAsync({a,b})end)
 if not ok or not valid()or type(groups)~='table'or type(groups[1])~='table'or type(groups[2])~='table'then return nil end
 local compatible=false;for _,id in ipairs(groups[1])do if table.find(groups[2],id)then compatible=true;break end end
 if not compatible then return nil end
 local self={from=a.UserId,to=b.UserId,inputs={},wires={},destroyed=false}
 self.root=Instance.new('Folder');self.root.Name='SpyPhoneVoice'
 function self:destroy()
  if self.destroyed then return end;self.destroyed=true
  self.root:Destroy()
  for _,r in ipairs(self.wires)do pcall(function()
   if r.wire.Parent and r.target.Parent and r.wire.SourceInstance==r.input and r.wire.TargetInstance==nil then r.wire.TargetInstance=r.target end
  end)end
  for _,r in ipairs(self.inputs)do pcall(function()
   if r.input.Parent and r.input.AccessType==Enum.AccessModifierType.Allow and equal(r.input:GetUserIdAccessList(),r.applied)then
    r.input:SetUserIdAccessList(r.list);r.input.AccessType=r.access
   end
  end)end
 end
 local good=pcall(function()
  for _,pair in ipairs({{ia,b},{ib,a}})do
   local input,listener=pair[1],pair[2]
   local r={input=input,access=input.AccessType,list=input:GetUserIdAccessList(),applied={listener.UserId}};self.inputs[#self.inputs+1]=r
   input:SetUserIdAccessList(r.applied);input.AccessType=Enum.AccessModifierType.Allow
   -- Suspend only this microphone's spatial path. The phone has one audible route.
   for _,wire in ipairs(input:GetConnectedWires('Output'))do
    if wire:IsA('Wire')and wire.SourceInstance==input and wire.TargetInstance and wire.TargetInstance:IsA('AudioEmitter')then
     self.wires[#self.wires+1]={wire=wire,target=wire.TargetInstance,input=input};wire.TargetInstance=nil
    end
   end
   local output=Instance.new('AudioDeviceOutput');output.Name='Receiver_'..listener.UserId;output.Player=listener;output.Parent=self.root
   local wire=Instance.new('Wire');wire.SourceInstance=input;wire.TargetInstance=output;wire.Parent=self.root
  end
  self.root.Parent=workspace
 end)
 if not good or not valid()then self:destroy();return nil end
 return self
end
return Voice
