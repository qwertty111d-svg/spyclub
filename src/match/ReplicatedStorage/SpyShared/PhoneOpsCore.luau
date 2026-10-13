-- Pure, authoritative mission protocol. No scene, inventory or chat dependencies.
local Core={};Core.__index=Core
local outcomes={cassette='archive',envelope='hold',call='warn'}
function Core.new(files,save,guid,random)
 return setmetatable({files=files,save=save,guid=guid,random=random,sessions={}},Core)
end
function Core:view(id,lang)
 local s=self.sessions[id];if not s then return{ok=true,phase='idle'}end
 local file=self.files.story(s.id,lang)
 local d={ok=true,phase=s.phase,id=s.id,token=s.token,saving=s.saving==true,file={id=s.id,title=file.title,contact=file.contact,target=file.target,location=file.location}}
 if s.phase=='call'then d.call={step=s.step,text=s.step==1 and file.intro or(s.branch=='hurry'and file.short or file.detail)}end
 if s.phase=='cipher'or s.phase=='decision'or s.phase=='done'then d.transmission={digits=table.clone(s.transmission),shift=s.shift};d.captured=true end
 if s.phase=='decision'or s.phase=='done'then d.message=file.message;d.choices=table.clone(file.choices)end
 if s.phase=='done'then d.ending=file.ending end
 return d
end
function Core:handle(id,p,ctx,lang)
 if type(p)~='table'or type(p.action)~='string'then return{ok=false,code='invalid'}end
 if p.action=='snapshot'then return self:view(id,lang)end
 if ctx.blocked or not ctx.alive or not ctx.phone then return{ok=false,code='blocked'}end
 local s=self.sessions[id]
 if p.action=='dial'then
  if not self.files.valid(p.id)then return{ok=false,code='invalid'}end
  if s and(s.saving or(s.phase~='done'and p.reset~=true))then return{ok=false,code='busy'}end
  local shift=self.random(1,5);local answer={self.random(0,9),self.random(0,9),self.random(0,9)}
  local encoded={};for i,v in ipairs(answer)do encoded[i]=(v+shift)%10 end
  s={id=p.id,token=self.guid(),phase='call',step=1,shift=shift,answer=answer,transmission=encoded};self.sessions[id]=s
  return self:view(id,lang)
 end
 if not s or p.token~=s.token then return{ok=false,code='stale'}end
 if s.saving then return{ok=false,code='busy'}end
 if s.phase=='done'then return self:view(id,lang)end
 if p.action=='choice'and s.phase=='call'then
  if s.step==1 and(p.choice=='listen'or p.choice=='hurry')then s.branch=p.choice;s.step=2
  elseif s.step==2 and p.choice=='accept'then s.phase='search'
  elseif s.step==2 and p.choice=='decline'then self.sessions[id]=nil
  else return{ok=false,code='invalid'}end
 elseif p.action=='capture'and s.phase=='search'then
  if p.target~=s.id or ctx.proof~=true then return{ok=false,code='no_target'}end
  s.phase='cipher'
 elseif p.action=='decode'and s.phase=='cipher'then
  if type(p.digits)~='table'or #p.digits~=3 then return{ok=false,code='invalid'}end
  for i,v in ipairs(p.digits)do if type(v)~='number'or v%1~=0 or v<0 or v>9 then return{ok=false,code='invalid'}end;if v~=s.answer[i]then return{ok=false,code='wrong'}end end
  s.phase='decision'
 elseif p.action=='resolve'and s.phase=='decision'then
  if p.choice~=outcomes[s.id]then return{ok=false,code='wrong'}end
  s.saving=true;local good,result=pcall(self.save,id,'case:'..id..':'..s.id,{kind='caseSolved',caseId=s.id});s.saving=false
  if self.sessions[id]~=s then return{ok=false,code='stale'}end
  if not good or type(result)~='table'or not result.ok then return{ok=false,code='save_failed'}end
  s.phase='done'
 else return{ok=false,code='invalid'}end
 return self:view(id,lang)
end
function Core:remove(id)self.sessions[id]=nil end
return Core
