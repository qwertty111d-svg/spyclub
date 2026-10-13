-- Server-owned two-player calls. No text, roles, profile or economy in this state.
local Core={};Core.__index=Core
function Core.new(clock,token,emit)
 return setmetatable({clock=clock,token=token,emit=emit,calls={},members={},revisions={},cooldown={},serial=0},Core)
end
function Core:view(id)
 local call=self.calls[self.members[id]]
 if not call then return{phase='idle',revision=self.revisions[id]or 0}end
 return{id=call.id,phase=call.phase,from=call.from,to=call.to,peer=call.from==id and call.to or call.from,incoming=call.to==id,at=call.at,expires=call.expires,revision=call.revision,voice=call.voice==true,voiceState=call.voiceState}
end
function Core:publish(c,reason)
 self.serial+=1;c.revision=self.serial
 for _,id in ipairs({c.from,c.to})do self.revisions[id]=self.serial;local v=self:view(id);v.reason=reason;self.emit(id,v)end
end
function Core:dial(from,to,allowed)
 if allowed~=true then return{ok=false,code='privacy'}end
 if type(to)~='number'or to==from then return{ok=false,code='invalid'}end
 if self.members[from]or self.members[to]then return{ok=false,code='busy'}end
 local now=self.clock();if now-(self.cooldown[from]or -100)<5 then return{ok=false,code='rate'}end
 self.cooldown[from]=now
 local c={id=self.token(),from=from,to=to,phase='ringing',at=now,expires=now+25,voice=false}
 self.calls[c.id]=c;self.members[from]=c.id;self.members[to]=c.id;self:publish(c)
 return{ok=true,call=self:view(from)}
end
function Core:answer(id,token,accept)
 local c=self.calls[token]
 if not c or self.members[id]~=token or c.to~=id or c.phase~='ringing'then return{ok=false,code='stale'}end
 if self.clock()>=c.expires then self:finish(id,token,'missed');return{ok=false,code='stale'}end
 if not accept then return self:finish(id,token,'declined')end
 c.phase='active';c.voiceState='connecting';c.at=self.clock();c.expires=c.at+300;self:publish(c)
 return{ok=true,call=self:view(id)}
end
function Core:voice(token,enabled,state)
 local c=self.calls[token];if not c or c.phase~='active'then return false end
 c.voice=enabled==true;c.voiceState=enabled and'ready'or(state or'unavailable');self:publish(c);return true
end
function Core:finish(id,token,reason)
 local c=self.calls[token]
 if not c or self.members[id]~=token then return{ok=false,code='stale'}end
 self.calls[token]=nil;self.members[c.from]=nil;self.members[c.to]=nil;self:publish(c,reason or'ended')
 return{ok=true,call=self:view(id)}
end
function Core:tick()
 for token,c in pairs(self.calls)do if self.clock()>=c.expires then self:finish(c.from,token,c.phase=='ringing'and'missed'or'ended')end end
end
function Core:remove(id)
 local token=self.members[id];if token then self:finish(id,token,'left')end
 self.cooldown[id]=nil;self.revisions[id]=nil
end
return Core
