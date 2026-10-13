-- Pure phone protocol: cosmetic state only, no economy or chat payloads.
local State={};State.__index=State
State.Blocked={'SpyEntryActive','SpyEntryPending','SpyTeleporting','SpyReconnectBusy','SpyBilliardsPlaying','SpyCheckersPlaying','SpyMatchIntroActive'}
function State.new(clock)return setmetatable({clock=clock,sessions={}},State)end
function State:request(id,p,ctx)
 local s=self.sessions[id]or{open=false,seq=0,at=-math.huge};self.sessions[id]=s
 local function view(code)return{open=s.open,seq=s.seq,at=s.at,code=code}end
 if type(p)~='table'or type(p.open)~='boolean'or type(p.seq)~='number'or p.seq%1~=0 or p.seq<1 or p.seq>1e9 then return view('invalid')end
 if p.seq<=s.seq then return view()end
 s.seq=p.seq
 if p.open and(ctx.blocked or not ctx.alive or not ctx.hasHand)then return view('blocked')end
 local now=self.clock()
 if p.open~=s.open then
  if p.open and now-s.at<.25 then return view('busy')end
  s.open=p.open;s.at=now
 end
 return view()
end
function State:close(id)
 local s=self.sessions[id];if s then s.open=false;s.at=self.clock()end
end
function State:remove(id)self.sessions[id]=nil end
function State.canKey(focused,chord,processed)return not(focused or chord or processed)end
function State.layout(w,h)
 return{w=math.max(1,math.min(356,w-24)),h=math.max(1,math.min(704,h-24)),columns=w<330 and 2 or 3}
end
function State.number(id)
 if type(id)~='number'or id~=id or id%1~=0 or id==0 or math.abs(id)>999999999999999 then return nil end
 if id<0 then return 'TEST'..string.format('%03.0f',-id)end
 return '77'..string.format('%010.0f',id)
end
function State.numberId(text)
 if type(text)~='string'or #text>32 then return nil end
 local compact=text:gsub('[%s%-]','')
 local test=compact:match('^TEST(%d+)$')
 if test then local id=-tonumber(test);return State.number(id)==compact and id or nil end
 if not compact:match('^77%d+$')then return nil end
 local id=tonumber(compact:sub(3));return id and State.number(id)==compact and id or nil
end
function State.formatNumber(text)
 local id=State.numberId(text);if not id then return '—'end
 local n=State.number(id);if id<0 then return 'TEST '..n:sub(5)end
 local rest=n:sub(3);local groups={}
 while #rest>4 do groups[#groups+1]=rest:sub(1,3);rest=rest:sub(4)end
 groups[#groups+1]=rest;return '77 '..table.concat(groups,' ')
end
return State
