local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local modules={}
local function loadModule(name)
    if modules[name] then return modules[name] end
    local chunk=assert(loadstring(Sources[name],name))
    setfenv(chunk,setmetatable({script=nil,require=function(path)return loadModule(path:gsub('^%./',''))end},{__index=getfenv(0)}))
    modules[name]=chunk();return modules[name]
end
local Server=loadModule('PreferencesServer')
local id='1-guidtest0001'
check(type(Server.command('dossierSync',nil,id))=='table','match endpoint must provide full dossier snapshot')
check(type(Server.command('accessoryRoll','nationality',id))=='table','match supports identity roll action')
check(type(Server.command('accessoryRoll','hair',id))=='table','match supports cosmetic roll action')
check(type(Server.command('equip','black_tie',id))=='table','match can equip owned items')
check(type(Server.command('daily',nil,id))=='table','match supports daily reward')
check(Server.command('daily',999,id)==nil,'client cannot choose reward timestamp')
check(Server.command('accessoryRoll',{},id)==nil,'reject malformed category')
check(Server.command('accessoryRoll',string.rep('a',100),id)==nil,'reject excessive category')
check(Server.command('buy','black_tie',id)==nil,'retired shop cannot be reopened through match endpoint')
check(Server.command('capsule','midnight',id)==nil,'cosmetic cases remain retired')
check(Server.command('accessoryRoll','hair','../bad')==nil,'reject unsafe request identifier')
check(Server.command('language','en','prefs-guidtest0001').language=='en','existing preference route remains usable')
check(type(Server.recover)=='function','saved roll can be recovered after phase changes without spending')
local saved={rolls=3,rollSequence=1,rollReceipts={[id]={ok=true,code='identityRolled',category='nationality',sequence=1,rolls=3}}}
local recovered=Server.recover(saved,'nationality',id)
check(recovered and recovered.replayed and recovered.code=='identityRolled','return durable saved receipt')
check(saved.rolls==3 and saved.rollReceipts[id].replayed==nil,'recovery never mutates wallet or stored receipt')
check(Server.recover(saved,'hair',id).code=='roll_request_conflict','recovery rejects category conflict')
check(Server.recover(saved,'hair','2-guidtest0002')==nil,'unsaved request cannot spend through recovery')
check(Server.recover(nil,'nationality',id)==nil,'missing cache is not proof of saved result')
local Policy=loadModule('DossierPolicy')
check(type(Policy.canChange)=='function','shared dossier input policy is available')
for _,phase in ipairs({'Waiting','Result','Finished'}) do check(Policy.canChange(phase),'allow changes between matches: '..phase) end
for _,phase in ipairs({'Hint','Discuss','Vote','Role','Intro','TopicVote','ExtraRound'}) do check(not Policy.canChange(phase),'protect active match: '..phase) end
check(Policy.canOpen({phase='Hint'}),'H can inspect character during match')
check(not Policy.canOpen({teleporting=true}),'no modal during teleport')
check(not Policy.canOpen({cinematic=true}),'no modal over arrival cinematic')
check(not Policy.canOpen({phone=true}),'no overlapping phone modal')
check(not Policy.hotkey(true,false,{}),'processed key does not toggle')
check(not Policy.hotkey(false,true,{}),'typing H does not toggle')
check(Policy.hotkey(false,false,{}),'unprocessed H opens dossier')
check(not Policy.hotkey(false,false,{trade=true}),'no modal during trade')

-- Execute the actual endpoint handler with only its external services stubbed.
-- Removing phase gating, receipt recovery, reload, or canEquip fails this flow.
local function signal()
    return {Connect=function(self,fn)self.callback=fn;return {Disconnect=function()end}end}
end
local players={PlayerRemoving=signal()}
local player={UserId=7,Parent=players,SetAttribute=function()end,GetAttribute=function()return false end}
function players:GetPlayerByUserId(userId)return userId==7 and player or nil end
local replies={}
local action={OnServerEvent=signal()}
local event={FireClient=function(_,_,public,receipt,requestId)replies[#replies+1]={profile=public,receipt=receipt,id=requestId}end}
local shared={EconomyAction=action,Profile=event,Preferences='Preferences'}
function shared:FindFirstChild(name)return self[name]end
local rs={SpyShared=shared,WaitForChild=function(self,name)return self[name]end}
local clock=100
local serviceCalls,writes,reloads,changes=0,0,0,0
local phaseOpen,assetsReady=true,true
local records={cache={[7]=saved},busy={},pending={}}
function records:public(userId)
    return {ready=self.cache[userId]~=nil,revision=1,rolls=self.cache[userId] and self.cache[userId].rolls or 0,language='ru'}
end
function records:transact(_,_,command)writes+=1;return {ok=true,code=command.kind=='equip' and 'equipped' or 'dailyReceived'}end
local fakeRollService={new=function(_,options)
    return {snapshot=function()return {sequence=1,categories={}}end,
        roll=function()serviceCalls+=1;return {ok=true,code='identityRolled'}end,remove=function()end}
end}
local chunk=assert(loadstring(Sources.PreferencesServer,'match-endpoint-under-test'))
setfenv(chunk,setmetatable({script={Parent={AccessoryRollService='AccessoryRollService'}},
    game={GetService=function(_,name)return name=='Players' and players or rs end},
    require=function(name)return name=='AccessoryRollService' and fakeRollService or modules[name]end,
    os=setmetatable({clock=function()return clock end},{__index=os}),warn=function()end}, {__index=getfenv(0)}))
local Endpoint=chunk()
Endpoint.start(records,{canChange=function()return phaseOpen end,
    canEquip=function()return assetsReady,'appearanceLoading'end,
    ensureLoaded=function()reloads+=1;records.cache[7]=saved;return true end,
    onChanged=function()changes+=1 end})
local function send(kind,value,requestId)
    clock+=4
    action.OnServerEvent.callback(player,kind,value,requestId or id)
    return replies[#replies]
end
phaseOpen=false
local reply=send('accessoryRoll','nationality',id)
check(reply.receipt.replayed and serviceCalls==0 and writes==0,'closed phase recovers old receipt without calling mutation service')
reply=send('accessoryRoll','nationality','2-guidtest0002')
check(reply.receipt.code=='roll_match_active' and serviceCalls==0 and writes==0,'closed phase rejects new request before mutation')
records.cache[7]=nil
reply=send('accessoryRoll','nationality',id)
check(reloads==1 and reply.receipt.replayed and writes==0,'unknown write outcome reloads durable receipt without spending')
records.cache[7]=nil
reply=send('dossierSync',nil,'dossier-guidtest0001')
check(reloads==2 and reply.profile.ready,'sync repairs invalidated profile cache')
phaseOpen=true;assetsReady=false
reply=send('equip','black_tie','equip-guidtest0001')
check(reply.receipt.code=='appearanceLoading' and writes==0 and changes==0,'missing equipment assets cannot produce saved success')
assetsReady=true
reply=send('equip','black_tie','equip-guidtest0002')
check(reply.receipt.ok and writes==1 and changes==1,'validated equipment commits and updates appearance')
phaseOpen=false
reply=send('daily',nil,'daily-guidtest0001')
check(reply.receipt.code=='roll_match_active' and writes==1,'daily cannot interrupt an active match')
phaseOpen=true
reply=send('daily',nil,'daily-guidtest0002')
check(reply.receipt.ok and writes==2 and changes==2,'daily remains available after match')
print('Dossier command/input policy: '..checks..' assertions passed')
