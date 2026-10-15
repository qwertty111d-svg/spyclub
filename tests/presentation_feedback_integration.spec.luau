-- Execute production bootstrap and Presentation; Roblox services are boundaries.
local checks, failures = 0, 0
local function check(value, message)
 checks += 1
 assert(value, message)
end
local function test(name, callback)
 local ok, message = pcall(callback)
 if not ok then failures += 1; print('FAIL: '..name..': '..tostring(message)) end
end
local function signal()
 local entries = {}
 return {
  Connect = function(_, callback)
   local entry = {callback=callback, active=true}; entries[#entries+1]=entry
   return {Disconnect=function()entry.active=false end}
  end,
  Fire = function(_, ...)
   for _, entry in ipairs(entries) do if entry.active then entry.callback(...) end end
  end,
 }
end
local Methods = {}
local function node(class, name, parent, properties)
 local value = setmetatable({ClassName=class, Name=name, Parent=parent, Enabled=true,
  children={}, signals={}, ChildAdded=signal(), DescendantAdded=signal(), Destroying=signal()}, {__index=Methods})
 for key, property in pairs(properties or {}) do value[key]=property end
 if parent then parent.children[#parent.children+1]=value end
 return value
end
function Methods:IsA(class)return self.ClassName==class end
function Methods:GetDescendants()
 local all={}
 for _, child in ipairs(self.children) do
  all[#all+1]=child
  for _, descendant in ipairs(child:GetDescendants()) do all[#all+1]=descendant end
 end
 return all
end
function Methods:GetPropertyChangedSignal(key)
 self.signals[key]=self.signals[key] or signal();return self.signals[key]
end
local Enum={Font={Garamond='Garamond', BuilderSansBold='BuilderSansBold', BuilderSansMedium='BuilderSansMedium', Arial='Arial'}}
local function loadModule(source, environment)
 local chunk=assert(loadstring(source))
 setfenv(chunk, setmetatable(environment or {}, {__index=getfenv(0)}))
 return chunk()
end
local function playerFixture()
 local player={attributes={},signals={}}
 function player:GetAttribute(key)return self.attributes[key]end
 function player:GetAttributeChangedSignal(key)
  self.signals[key]=self.signals[key]or signal();return self.signals[key]
 end
 return player
end
for _, place in ipairs({'lobby','match'}) do
 test(place..' preserves authored display fonts on initial and late UI', function()
  local pg=node('PlayerGui','PlayerGui')
  local gui=node('ScreenGui','SpyClubUI',pg)
  local display=node('TextLabel','CollectionTitle',gui,{Font=Enum.Font.Garamond,TextSize=56})
  local heading=node('TextLabel','Heading',gui,{Font=Enum.Font.Arial,TextSize=24})
  local body=node('TextLabel','Body',gui,{Font=Enum.Font.Arial,TextSize=14})
  local player=playerFixture()
  local service=loadModule(Sources[place..'Presentation'],{Enum=Enum}).start(pg,player)
  check(display.Font==Enum.Font.Garamond,'existing authored Garamond must survive Presentation.start')
  check(heading.Font==Enum.Font.BuilderSansBold and body.Font==Enum.Font.BuilderSansMedium,'normal presentation typography remains active')
  local lateRoot=node('ScreenGui','SpyMatchUI',pg)
  local lateDisplay=node('TextLabel','SeatIndex',lateRoot,{Font=Enum.Font.Garamond,TextSize=68})
  pg.DescendantAdded:Fire(lateRoot);pg.DescendantAdded:Fire(lateDisplay)
  check(lateDisplay.Font==Enum.Font.Garamond,'late authored Garamond must survive the actual discovery callback')
  local lateButton=node('TextButton','Continue',lateRoot,{Font=Enum.Font.Arial,TextSize=14})
  pg.DescendantAdded:Fire(lateButton)
  check(lateButton.Font==Enum.Font.BuilderSansBold,'late standard controls retain presentation styling')
  player.attributes.SpyEntryActive=true;player:GetAttributeChangedSignal('SpyEntryActive'):Fire()
  check(gui.Enabled==false,'presentation still suppresses gameplay during entry')
  service:destroy()
  check(gui.Enabled==true,'presentation teardown restores held screens')
  local after=node('TextLabel','After',lateRoot,{Font=Enum.Font.Arial,TextSize=30})
  pg.DescendantAdded:Fire(after)
  check(after.Font==Enum.Font.Arial,'presentation teardown disconnects late discovery')
 end)

 local function bootstrap(options)
  options=options or {}
  local queued, warnings={},{}
  local pg={name='pg'};local player={}
  local script={Destroying=signal()}
  local starts={presentation=0,feedback=0};local stops={presentation=0,feedback=0}
  local modules={Presentation={},UIFeedback={}}
  function modules.Presentation.start(root,who)
   starts.presentation+=1
   check(root==pg and who==player,'presentation receives the real player UI root')
   if options.presentationStartError then error('presentation fixture failure')end
   return{destroy=function()stops.presentation+=1 end}
  end
  function modules.UIFeedback.start(root,who)
   starts.feedback+=1
   check(root==pg and who==player,'feedback receives PlayerGui for existing and late UI roots')
   if options.feedbackStartError then error('feedback start fixture failure')end
   if options.destroyDuringStart then script.Destroying:Fire()end
   return{destroy=function()stops.feedback+=1 end}
  end
  function player:WaitForChild(name)
   check(name=='PlayerGui','bootstrap requests PlayerGui');return pg
  end
  local shared={}
  function shared:WaitForChild(name)
   if name=='UIFeedback' and options.destroyDuringWait then script.Destroying:Fire()end
   if name=='UIFeedback' and options.missingFeedback then return nil end
   return name
  end
  local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function()return shared end}}
  local environment={script=script,game={GetService=function(_,key)return services[key]end},
   task={spawn=function(callback)queued[#queued+1]=callback end},
   require=function(key)
    if key=='UIFeedback' and options.feedbackLoadError then error('feedback load fixture failure')end
    return modules[key]
   end,warn=function(message)warnings[#warnings+1]=message end}
  local chunk=assert(loadstring(Sources[place..'Bootstrap']));setfenv(chunk,setmetatable(environment,{__index=getfenv(0)}));chunk()
  return{starts=starts,stops=stops,warnings=warnings,script=script,flush=function()
   while #queued>0 do table.remove(queued,1)()end
  end}
 end
 test(place..' starts optional feedback independently and tears both controllers down',function()
  local run=bootstrap()
  check(run.starts.presentation==1,'presentation starts immediately')
  check(run.starts.feedback==0,'optional feedback loading cannot block presentation boot')
  run.flush()
  check(run.starts.feedback==1,'bootstrap starts exactly one shared feedback owner')
  run.script.Destroying:Fire()
  check(run.stops.presentation==1 and run.stops.feedback==1,'script teardown releases both controllers')
 end)
 test(place..' optional module missing or failing leaves presentation usable',function()
  for _, options in ipairs({{missingFeedback=true},{feedbackLoadError=true},{feedbackStartError=true}})do
   local run=bootstrap(options);run.flush()
   check(run.starts.presentation==1,'optional feedback failure preserves presentation')
   run.script.Destroying:Fire()
   check(run.stops.presentation==1,'optional failure retains presentation cleanup')
   check(run.stops.feedback==0,'failed startup does not invent a controller to destroy')
  end
 end)
 test(place..' presentation failure does not cancel optional feedback startup',function()
  local run=bootstrap({presentationStartError=true});run.flush()
  check(run.starts.feedback==1,'feedback still starts after protected presentation failure')
  run.script.Destroying:Fire();check(run.stops.feedback==1,'independent feedback owner is cleaned up')
 end)
 test(place..' destroyed bootstrap cannot create late feedback work',function()
  local run=bootstrap();run.script.Destroying:Fire();run.flush()
  check(run.starts.feedback==0,'destroy before optional load prevents startup')
  run=bootstrap({destroyDuringWait=true});run.flush()
  check(run.starts.feedback==0,'destroy during optional load prevents startup')
  run=bootstrap({destroyDuringStart=true});run.flush()
  check(run.starts.feedback==1 and run.stops.feedback==1,'controller returned after destruction is immediately retired')
 end)
end
assert(failures==0,tostring(failures)..' presentation/feedback integration cases failed')
print('Presentation/feedback integration: '..checks..' assertions passed (actual bootstraps and presentation modules)')
