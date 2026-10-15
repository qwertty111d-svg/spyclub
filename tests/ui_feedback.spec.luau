-- Executes the real UIFeedback module; only Roblox engine boundaries are supplied.
-- Studio must still validate native input, sound asset access and visual timing.
local checks,passed,failures=0,0,0
local function check(value,message) checks+=1;assert(value,message) end
local function close(actual,expected,message)
    check(type(actual)=="number" and math.abs(actual-expected)<1e-8,message.." (got "..tostring(actual)..")")
end
local enumCache={}
local function enumBranch(prefix)
    return setmetatable({}, {__index=function(self,key)
        local path=prefix.."."..key
        if not enumCache[path]then enumCache[path]=enumBranch(path)end
        rawset(self,key,enumCache[path]);return enumCache[path]
    end})
end
local Enum=enumBranch("Enum")
local allSignals={}
local function signal()
    local event={_connections={}}
    function event:Connect(callback)
        local connection={Connected=true,_callback=callback}
        function connection:Disconnect()self.Connected=false end
        self._connections[#self._connections+1]=connection;return connection
    end
    function event:Once(callback)
        local connection
        connection=self:Connect(function(...)connection:Disconnect();callback(...)end)
        return connection
    end
    function event:Fire(...)
        for _,connection in ipairs(table.clone(self._connections))do
            if connection.Connected then connection._callback(...)end
        end
    end
    function event:DisconnectAll()
        for _,connection in ipairs(self._connections)do connection:Disconnect()end
    end
    allSignals[#allSignals+1]=event;return event
end
local function activeConnections()
    local total=0
    for _,event in ipairs(allSignals)do
        for _,connection in ipairs(event._connections)do if connection.Connected then total+=1 end end
    end
    return total
end
local clock,scheduled=0,{}
local task={}
local function schedule(delay,callback,...)
    local thread=type(callback)=="thread" and callback or coroutine.create(callback)
    scheduled[#scheduled+1]={at=clock+delay,thread=thread,args={...}};return thread
end
function task.defer(callback,...)return schedule(0,callback,...)end
function task.spawn(callback,...)return schedule(0,callback,...)end
function task.delay(delay,callback,...)return schedule(delay,callback,...)end
function task.wait(delay)return coroutine.yield(delay or .03)end
function task.cancel(thread)
    for index=#scheduled,1,-1 do if scheduled[index].thread==thread then table.remove(scheduled,index)end end
end
local function advance(seconds)
    local limit=clock+seconds
    local executed=0
    while true do
        local nextIndex,nextAt
        for index,item in ipairs(scheduled)do
            if item.at<=limit and(not nextAt or item.at<nextAt)then nextIndex,nextAt=index,item.at end
        end
        if not nextIndex then break end
        executed+=1;assert(executed<512,"UI feedback scheduled unbounded work")
        clock=nextAt
        local item=table.remove(scheduled,nextIndex)
        local ok,delay=coroutine.resume(item.thread,table.unpack(item.args));assert(ok,delay)
        if coroutine.status(item.thread)~="dead"then schedule(delay or .03,item.thread)end
    end
    clock=limit
end
local os=table.clone(os)
os.clock=function()return clock end
local methods,instanceMeta={},{}
local admissions,plays,tweens={},{},{}
local function subtree(root)
    local nodes={root}
    local function walk(node)
        for _,child in ipairs(node._children)do nodes[#nodes+1]=child;walk(child)end
    end
    walk(root);return nodes
end
instanceMeta.__index=function(instance,key)
    if methods[key]then return methods[key]end
    if key=="Parent"then return rawget(instance,"_parent")end
    local value=instance._properties[key]
    if value~=nil then return value end
    for _,child in ipairs(instance._children)do if child.Name==key then return child end end
end
instanceMeta.__newindex=function(instance,key,value)
    if key:sub(1,1)=="_"then rawset(instance,key,value);return end
    if key=="Parent"then
        local previous=instance.Parent
        if previous==value then return end
        local nodes=subtree(instance)
        if previous then
            local ancestor=previous
            while ancestor do
                for _,node in ipairs(nodes)do ancestor.DescendantRemoving:Fire(node)end
                ancestor=ancestor.Parent
            end
            for index,child in ipairs(previous._children)do
                if child==instance then table.remove(previous._children,index);break end
            end
            previous.ChildRemoved:Fire(instance)
        end
        rawset(instance,"_parent",value)
        if value then
            for _,node in ipairs(nodes)do if node:IsA("Sound")then
                admissions[#admissions+1]={sound=node,volume=node.Volume,category=node:GetAttribute("SpyAudioCategory")}
            end end
            value._children[#value._children+1]=instance;value.ChildAdded:Fire(instance)
            local ancestor=value
            while ancestor do
                for _,node in ipairs(nodes)do ancestor.DescendantAdded:Fire(node)end
                ancestor=ancestor.Parent
            end
        end
        if instance._propertySignals.Parent then instance._propertySignals.Parent:Fire()end
        for _,node in ipairs(nodes)do node.AncestryChanged:Fire(node,node.Parent)end
    else
        local previous=instance._properties[key]
        instance._properties[key]=value
        if key=="Volume"then instance._volumeWrites=(instance._volumeWrites or 0)+1 end
        if key=="Scale"then instance._scaleWrites=(instance._scaleWrites or 0)+1 end
        if previous~=value then
            if instance._propertySignals[key]then instance._propertySignals[key]:Fire()end
            instance.Changed:Fire(key)
        end
    end
end
function methods:IsA(class)
    if self.ClassName==class or class=="Instance"then return true end
    if class=="GuiButton"then return self.ClassName=="TextButton"or self.ClassName=="ImageButton"end
    if class=="GuiObject"then
        return self:IsA("GuiButton")or table.find({"Frame","ScrollingFrame","TextLabel","ImageLabel","ViewportFrame"},self.ClassName)~=nil
    end
    if class=="LayerCollector"then return self.ClassName=="ScreenGui"or self.ClassName=="SurfaceGui"or self.ClassName=="BillboardGui"end
    return false
end
function methods:GetChildren()return table.clone(self._children)end
function methods:GetDescendants()
    local result=subtree(self);table.remove(result,1);return result
end
function methods:FindFirstChild(name,recursive)
    for _,child in ipairs(self._children)do if child.Name==name then return child end end
    if recursive then for _,child in ipairs(self._children)do
        local found=child:FindFirstChild(name,true);if found then return found end
    end end
end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self._children)do if child.ClassName==class then return child end end
end
function methods:FindFirstChildWhichIsA(class,recursive)
    for _,child in ipairs(recursive and self:GetDescendants()or self:GetChildren())do
        if child:IsA(class)then return child end
    end
end
function methods:FindFirstAncestor(name)
    local node=self.Parent;while node do if node.Name==name then return node end;node=node.Parent end
end
function methods:FindFirstAncestorOfClass(class)
    local node=self.Parent;while node do if node.ClassName==class then return node end;node=node.Parent end
end
function methods:WaitForChild(name)return self:FindFirstChild(name)end
function methods:IsDescendantOf(ancestor)
    local node=self.Parent;while node do if node==ancestor then return true end;node=node.Parent end;return false
end
function methods:GetPropertyChangedSignal(key)
    if not self._propertySignals[key]then self._propertySignals[key]=signal()end
    return self._propertySignals[key]
end
function methods:GetAttribute(key)return self._attributes[key]end
function methods:GetAttributes()return table.clone(self._attributes)end
function methods:SetAttribute(key,value)
    local previous=self._attributes[key];self._attributes[key]=value
    if previous~=value then
        if self._attributeSignals[key]then self._attributeSignals[key]:Fire()end
        self.AttributeChanged:Fire(key)
    end
end
function methods:GetAttributeChangedSignal(key)
    if not self._attributeSignals[key]then self._attributeSignals[key]=signal()end
    return self._attributeSignals[key]
end
function methods:Destroy()
    if self._destroyed then return end
    self._destroyed=true;self.Destroying:Fire()
    for _,child in ipairs(self:GetChildren())do child:Destroy()end
    self.Parent=nil
    for _,event in pairs(self._propertySignals)do event:DisconnectAll()end
    for _,event in pairs(self._attributeSignals)do event:DisconnectAll()end
    for _,event in ipairs(self._events)do event:DisconnectAll()end
end
function methods:Play()
    check(self:IsA("Sound"),"only sounds are played through the instance boundary")
    plays[#plays+1]={sound=self,volume=self.Volume,speed=self.PlaybackSpeed,time=clock}
    self.IsPlaying=true
end
function methods:Stop()self.IsPlaying=false end
local Instance={}
function Instance.new(class)
    local instance=setmetatable({_properties={ClassName=class,Name=class,Visible=true,Active=true,
        Interactable=true,Enabled=true,Scale=1,Volume=.5,PlaybackSpeed=1,IsPlaying=false,SoundId="",
        AutoButtonColor=true,BackgroundTransparency=.2,Size={authored="size"},Position={authored="position"}},
        _children={},_propertySignals={},_attributeSignals={},_attributes={},_events={}},instanceMeta)
    for _,name in ipairs({"Changed","AttributeChanged","Destroying","AncestryChanged","ChildAdded","ChildRemoved", "DescendantAdded","DescendantRemoving","MouseEnter","MouseLeave","SelectionGained","SelectionLost", "InputBegan","InputEnded","Activated","MouseButton1Down","MouseButton1Up"})do
        local event=signal();instance._properties[name]=event;instance._events[#instance._events+1]=event
    end
    return instance
end
local function object(class,name,parent)
    local instance=Instance.new(class);instance.Name=name;instance.Parent=parent;return instance
end
local TweenInfo={new=function(...)return {...}end}
local services={SoundService=object("SoundService","SoundService"),TweenService={},
    UserInputService={InputBegan=signal(),InputEnded=signal(),WindowFocusReleased=signal()},GuiService={SelectionChanged=signal()}}
function services.TweenService:Create(target,info,goals)
    local tween={target=target,goals=goals,info=info,Completed=signal(),cancelled=false,played=false}
    function tween:Play()
        self.played=true
        for key,value in pairs(self.goals)do self.target[key]=value end
    end
    function tween:Cancel()self.cancelled=true end
    function tween:Destroy()self:Cancel();self.Completed:DisconnectAll()end
    tweens[#tweens+1]=tween;return tween
end
local game={GetService=function(_,name)assert(services[name],"unexpected service "..name);return services[name]end}
local preferences={sfxVolume=.8,reducedMotion=false}
local ClientPreferences={Changed=signal()}
function ClientPreferences.get()return table.clone(preferences)end
local script={Parent=object("Folder","SpyShared")}
object("ModuleScript","ClientPreferences",script.Parent)
local function require(module)
    assert(module==script.Parent.ClientPreferences,"unexpected module require");return ClientPreferences
end
local nativeTypeof=typeof
local function typeof(value)
    if getmetatable(value)==instanceMeta then return "Instance"end
    return nativeTypeof(value)
end
local function warn(message)error("unexpected UIFeedback warning: "..tostring(message))end

-- Model the actual ClientPreferences observation contract, including its response
-- to external Volume writes. This makes double scaling observable in playback.
local soundRecords={}
local function applySound(sound,record)
    record.applied=record.base*preferences.sfxVolume
    if sound.Volume~=record.applied then sound.Volume=record.applied end
end
services.SoundService.DescendantAdded:Connect(function(sound)
    if not sound:IsA("Sound")or soundRecords[sound]then return end
    local record={base=sound.Volume};soundRecords[sound]=record
    sound:GetPropertyChangedSignal("Volume"):Connect(function()
        if sound.Volume~=record.applied then record.base=sound.Volume;applySound(sound,record)end
    end)
    applySound(sound,record)
end)

-- INSERT_REAL_UIFEEDBACK_MODULE

check(type(UIFeedback.start)=="function","UIFeedback.start must bind the supplied PlayerGui")
local current
local function fixture(options)
    services.UserInputService.GetMouseLocation=nil
    services.GuiService.GetGuiInset=function()return {X=0,Y=0},{X=0,Y=0}end
    preferences={sfxVolume=.8,reducedMotion=false}
    if options then for key,value in pairs(options)do preferences[key]=value end end
    local player=object("Player","LocalPlayer")
    player:SetAttribute("SpyReducedMotion",preferences.reducedMotion)
    local pg=object("PlayerGui","PlayerGui",player)
    local screen=object("ScreenGui","SpyClubUI",pg)
    local panel=object("Frame","Panel",screen)
    local button=object("TextButton","OpenInventory",panel)
    current={player=player,pg=pg,screen=screen,panel=panel,button=button}
    function current:start()
        self.controller=UIFeedback.start(self.pg,self.player)
        check(type(self.controller)=="table"and type(self.controller.destroy)=="function","start returns a controller with :destroy()")
        advance(0);return self.controller
    end
    function current:set(key,value)
        preferences[key]=value
        if key=="reducedMotion"then self.player:SetAttribute("SpyReducedMotion",value)end
        for sound,record in pairs(soundRecords)do if sound.Parent then applySound(sound,record)end end
        ClientPreferences.Changed:Fire()
    end
    function current:hitTesting(hits,mouse)
        self.hits=hits;self.mouse=mouse or {X=40,Y=50}
        local context=self
        self.pg.GetGuiObjectsAtPosition=function(_,x,y)
            if type(context.hits)=="function"then return context.hits(x,y)end
            return table.clone(context.hits)
        end
        services.UserInputService.GetMouseLocation=function()return context.mouse end
    end
    return current
end
local function ownedScale(button)return button:FindFirstChild("SpyUIFeedbackScale")end
local function ownSounds()
    local folder=services.SoundService:FindFirstChild("SpyUIFeedbackAudio")
    return folder,folder and folder:FindFirstChild("UIClick"),folder and folder:FindFirstChild("UIHover")
end
local function input(kind)
    return {UserInputType=kind=="ButtonA"and Enum.UserInputType.Gamepad1 or Enum.UserInputType[kind],
        KeyCode=kind=="ButtonA"and Enum.KeyCode.ButtonA or Enum.KeyCode.Unknown,Position={X=40,Y=50,Z=0}}
end
local function press(button,kind)
    local pressed=input(kind or "MouseButton1");button.InputBegan:Fire(pressed,false);return pressed
end
local function release(kind)
    services.UserInputService.InputEnded:Fire(type(kind)=="table"and kind or input(kind or "MouseButton1"),false)
end
local function test(name,callback)
    local baseline=activeConnections()
    local ok,message=pcall(callback)
    if current then
        if current.controller then current.controller:destroy()end
        current.player:Destroy();current=nil
    end
    advance(1)
    if ok then
        passed+=1;print("PASS "..name)
    else
        failures+=1;print("FAIL "..name..": "..tostring(message))
    end
    if activeConnections()~=baseline then
        failures+=1;print("FAIL "..name..": leaked "..tostring(activeConnections()-baseline).." signal connections")
    end
end

test("start is idempotent and preserves one action per activation",function()
    local f=fixture();local actions=0
    local action=f.button.Activated:Connect(function()actions+=1 end)
    f:start();UIFeedback.start(f.pg,f.player);advance(0)
    local folder=ownSounds()
    check(folder and #folder:GetChildren()==2,"idempotent startup owns exactly two sounds")
    local before=#plays
    f.button.Activated:Fire(input("MouseButton1"),1)
    check(#plays==before+1,"one activation plays exactly one click")
    check(actions==1,"existing action handler executes once")
    action:Disconnect()
end)

-- Exercise the ordering where an existing action callback runs before generic
-- feedback. Action owners can hide, disable or destroy their control
-- synchronously during Activated. Feedback
-- must count the valid input once even if that action invalidates the button
-- before the binder's Activated connection runs (or disconnects it entirely).
for _,effect in ipairs({"hide panel","disable button","destroy button"})do
    test("owner subscribed first can "..effect.." without losing the click",function()
        local f=fixture();local actions=0
        f.button.Activated:Connect(function()
            actions+=1
            if effect=="hide panel"then f.panel.Visible=false
            elseif effect=="disable button"then f.button.Active=false
            else f.button:Destroy()end
        end)
        f:start();local before=#plays
        local pressed=press(f.button);release(pressed);f.button.Activated:Fire(pressed,1)
        check(actions==1,"the original action executes once before generic feedback")
        check(#plays==before+1,"a valid physical activation keeps exactly one click when owner can "..effect)
    end)
end

test("Interactable false gates feedback while Active remains true",function()
    local f=fixture();f.button.Interactable=false;f:start()
    check(f.button.Active,"the engine-disabled control remains Active")
    local before=#plays;local beforeTweens=#tweens
    f.button.MouseEnter:Fire();f.button.SelectionGained:Fire();press(f.button);release();f.button.Activated:Fire()
    check(#plays==before,"Interactable false gates hover and activation audio")
    check(#tweens==beforeTweens,"Interactable false gates hover and press motion")
end)

test("changing Interactable during a press immediately resets motion",function()
    local f=fixture();f:start();press(f.button)
    local scale=ownedScale(f.button);check(scale~=nil,"a valid press creates owned scale")
    close(scale.Scale,.985,"the enabled control receives press motion")
    f.button.Interactable=false
    close(scale.Scale,1,"disabling interaction immediately resets the pressed scale")
    local before=#plays;local beforeTweens=#tweens
    f.button.MouseEnter:Fire();press(f.button);release();f.button.Activated:Fire()
    check(#plays==before and #tweens==beforeTweens,"the newly disabled control receives no further feedback")
end)

test("audio bases and category are set before observation and scale once",function()
    local f=fixture({sfxVolume=.5});local first=#admissions+1;f:start()
    local folder,click,hover=ownSounds()
    check(folder and click and hover,"controller owns its click and hover audio")
    check(click.SoundId=="rbxassetid://113397864512278"and hover.SoundId==click.SoundId,"both effects reuse the approved click asset")
    close(hover.PlaybackSpeed,1.25,"hover has a lighter playback speed")
    local seen={}
    for index=first,#admissions do
        local entry=admissions[index]
        if entry.sound==click or entry.sound==hover then
            seen[entry.sound]=true
            check(entry.category=="SFX","SFX category exists when sound enters service")
            close(entry.volume,entry.sound==click and .12 or .025,"nominal base exists before preferences observe sound")
        end
    end
    check(seen[click]and seen[hover],"both owned sounds were observed")
    close(click.Volume,.06,"click is scaled once")
    close(hover.Volume,.0125,"hover is scaled once")
    local writes=click._volumeWrites
    local before=#plays;f.button.Activated:Fire();advance(.2);f.button.Activated:Fire()
    check(#plays==before+2,"separate actions each retain one click")
    close(plays[#plays].volume,.06,"playback retains preference-scaled volume")
    check(click._volumeWrites==writes,"playing does not rewrite or rebase Volume")
    f:set("sfxVolume",.25);f.button.Activated:Fire()
    close(plays[#plays].volume,.03,"later preference change still applies the original base once")
end)

test("mute gates Play without blocking existing actions",function()
    local f=fixture({sfxVolume=0});f:start();local actions=0
    local connection=f.button.Activated:Connect(function()actions+=1 end)
    local before=#plays
    f.button.MouseEnter:Fire();f.button.SelectionGained:Fire();f.button.Activated:Fire()
    check(#plays==before,"zero SFX volume skips sound Play")
    check(actions==1,"mute leaves button action intact")
    connection:Disconnect()
end)

test("hover and selection share dedupe and a short throttle",function()
    local f=fixture();f:start();local actions=0
    local connection=f.button.Activated:Connect(function()actions+=1 end)
    local before=#plays
    f.button.MouseEnter:Fire();f.button.SelectionGained:Fire()
    check(#plays==before+1,"simultaneous hover and focus play one tick")
    f.button.MouseLeave:Fire();f.button.SelectionLost:Fire();advance(.04);f.button.MouseEnter:Fire()
    check(#plays==before+1,"hover within 90ms is throttled")
    f.button.MouseLeave:Fire();advance(.051);f.button.MouseEnter:Fire()
    check(#plays==before+2,"hover becomes available after 90ms")
    check(actions==0,"hover and focus never invoke the action")
    connection:Disconnect()
end)

test("hover throttle is shared across adjacent controls",function()
    local f=fixture();local nextButton=object("TextButton","NextAction",f.panel);f:start()
    local before=#plays;f.button.MouseEnter:Fire();advance(.04);nextButton.MouseEnter:Fire()
    check(#plays==before+1,"rapid movement between buttons shares the 90ms audio throttle")
    nextButton.MouseLeave:Fire();advance(.051);nextButton.MouseEnter:Fire()
    check(#plays==before+2,"the next control can play after the shared throttle expires")
end)

-- Native MouseEnter can also reach a GuiButton behind a higher layer. The
-- engine query supplies objects in front-to-back order; these cases exercise
-- that boundary without making the binder responsible for gameplay actions.
test("covered hover is silent and leaves the foreground hover throttle free",function()
    local f=fixture();local foreground=object("TextButton","ForegroundAction",f.screen)
    local actions=0;f.button.Activated:Connect(function()actions+=1 end)
    f:hitTesting({foreground,f.button,f.panel});f:start();local before=#plays
    f.button.MouseEnter:Fire()
    check(#plays==before,"covered native MouseEnter produces no audio")
    check(not ownedScale(f.button),"covered native MouseEnter produces no scale")
    check(actions==0,"covered hover never invokes an underlying action")
    foreground.MouseEnter:Fire()
    check(#plays==before+1,"covered hover does not consume the foreground hover throttle")
    local scale=ownedScale(foreground);check(scale~=nil,"foreground hover remains eligible for motion")
    close(scale.Scale,1.01,"foreground control receives hover motion")
end)

test("an active modal backdrop blocks mouse and touch presses beneath it",function()
    local f=fixture();local backdrop=object("Frame","ModalBackdrop",f.screen)
    backdrop.Active=true;backdrop.BackgroundTransparency=1
    local actions=0;f.button.Activated:Connect(function()actions+=1 end)
    f:hitTesting(function(x,y)
        if x==40 and y==50 or x==120 and y==130 then return {backdrop,f.button,f.panel}end
        return {f.button,f.panel}
    end)
    f:start();local before=#plays;local beforeTweens=#tweens
    local mouse=input("MouseButton1");f.button.InputBegan:Fire(mouse,false);release(mouse)
    f.mouse={X=800,Y=900}
    local touch=input("Touch");touch.Position={X=120,Y=130,Z=0}
    f.button.InputBegan:Fire(touch,false);release(touch)
    check(#plays==before,"covered mouse and touch presses produce no click")
    check(#tweens==beforeTweens and not ownedScale(f.button),"covered pointer presses produce no motion")
    check(actions==0,"covered pointer events never invoke an underlying action")
end)

test("a button label and transparent inactive wrappers permit feedback",function()
    local f=fixture();local label=object("TextLabel","Caption",f.button)
    label.Active=false;label.BackgroundTransparency=1
    local wrapper=object("Frame","DecorationWrapper",f.screen)
    wrapper.Active=false;wrapper.BackgroundTransparency=1
    f:hitTesting({wrapper,label,f.button,f.panel});f:start();local before=#plays
    f.button.MouseEnter:Fire();local pressed=press(f.button);release(pressed);f.button.Activated:Fire(pressed,1)
    check(#plays==before+2,"a descendant label and pass-through wrapper permit hover and one click")
    local scale=ownedScale(f.button);check(scale~=nil,"a decorated foreground button retains motion")
    close(scale.Scale,1,"decorated foreground button releases to neutral scale")
end)

test("an opaque panel blocks feedback even without Active input capture",function()
    local f=fixture();local modal=object("Frame","OpaquePanel",f.screen)
    modal.Active=false;modal.BackgroundTransparency=0
    f:hitTesting({modal,f.button,f.panel});f:start();local before=#plays;local beforeTweens=#tweens
    f.button.MouseEnter:Fire();local pressed=press(f.button);release(pressed)
    check(#plays==before,"an opaque panel blocks underlying hover and press audio")
    check(#tweens==beforeTweens and not ownedScale(f.button),"an opaque panel blocks underlying hover and press motion")
end)

test("gamepad selection and ButtonA are independent of pointer occlusion",function()
    local f=fixture();local foreground=object("TextButton","PointerTarget",f.screen)
    local actions=0;f.button.Activated:Connect(function()actions+=1 end)
    f:hitTesting({foreground},{X=800,Y=900});f:start();local before=#plays
    f.button.SelectionGained:Fire()
    local scale=ownedScale(f.button);check(scale~=nil,"gamepad selection ignores another mouse target")
    close(scale.Scale,1.01,"gamepad selection keeps its hover motion")
    local buttonA=input("ButtonA")
    services.UserInputService.InputBegan:Fire(buttonA,false);f.button.InputBegan:Fire(buttonA,false)
    close(scale.Scale,.985,"selected ButtonA press ignores pointer occlusion")
    release(buttonA);f.button.Activated:Fire(buttonA,1)
    check(#plays==before+2,"gamepad selection and action retain hover and one click")
    check(actions==1,"gamepad activation retains exactly one existing action")
end)

test("missing optional hit testing APIs retain safe feedback fallback",function()
    local f=fixture();f:hitTesting({f.button});local query=f.pg.GetGuiObjectsAtPosition
    f.pg.GetGuiObjectsAtPosition=nil;f:start();local before=#plays;f.button.MouseEnter:Fire()
    check(#plays==before+1,"missing PlayerGui hit query falls back without crashing")
    f.pg.GetGuiObjectsAtPosition=query;services.UserInputService.GetMouseLocation=nil
    f.button.MouseLeave:Fire();advance(.1);f.button.MouseEnter:Fire()
    check(#plays==before+2,"missing pointer location falls back without crashing")
end)

test("mouse hit coordinates remove the GUI inset while touch coordinates remain adjusted",function()
    local f=fixture();local blocker=object("Frame","CoordinateMismatchBlocker",f.screen)
    services.GuiService.GetGuiInset=function()return {X=7,Y=36},{X=0,Y=0}end
    f:hitTesting(function(x,y)
        if x==33 and y==14 then return {f.button,f.panel}end
        return {blocker,f.button,f.panel}
    end,{X=40,Y=50})
    f:start();local before=#plays;f.button.MouseEnter:Fire()
    check(#plays==before+1,"raw mouse coordinates subtract both inset axes before querying PlayerGui")
    local mouse=press(f.button);release(mouse);f.button.Activated:Fire(mouse,1)
    check(#plays==before+2,"mouse press uses the inset-adjusted query")
    local touch=input("Touch");touch.Position={X=33,Y=14,Z=0}
    f.button.InputBegan:Fire(touch,false);release(touch);f.button.Activated:Fire(touch,1)
    check(#plays==before+3,"touch Position is queried without subtracting the inset twice")
    f.hits=function(x,y)
        if x==40 and y==50 then return {f.button,f.panel}end
        return {blocker,f.button,f.panel}
    end
    services.GuiService.GetGuiInset=nil
    f.button.MouseLeave:Fire();advance(.1);f.button.MouseEnter:Fire()
    check(#plays==before+4,"missing optional GetGuiInset safely uses zero inset")
    services.GuiService.GetGuiInset=function()error("injected unavailable GUI inset")end
    f.button.MouseLeave:Fire();advance(.1);f.button.MouseEnter:Fire()
    check(#plays==before+5,"a failed optional GetGuiInset safely uses zero inset")
end)

test("inactive hidden and disabled ancestors gate feedback",function()
    local f=fixture();f:start()
    local cases={{f.button,"Active"},{f.button,"Visible"},{f.panel,"Visible"},{f.screen,"Enabled"}}
    for _,entry in ipairs(cases)do
        advance(.2);entry[1][entry[2]]=false
        local before=#plays;local beforeTweens=#tweens
        f.button.MouseEnter:Fire();press(f.button);f.button.Activated:Fire();f.button.SelectionGained:Fire()
        check(#plays==before,"disabled "..entry[2].." gates audio through ancestors")
        check(#tweens==beforeTweens,"disabled "..entry[2].." gates motion through ancestors")
        entry[1][entry[2]]=true;f.button.MouseLeave:Fire();f.button.SelectionLost:Fire();release()
    end
end)

test("full screen dismiss controls retain actions without feedback",function()
    local f=fixture();f:start()
    for _,name in ipairs({"Dismiss","DismissBackdrop","DismissClubStore","PremiumDismiss","DrawerBackdrop"})do
        local button=object("TextButton",name,f.panel);advance(0)
        local actions=0;local connection=button.Activated:Connect(function()actions+=1 end)
        local before=#plays
        button.MouseEnter:Fire();press(button);button.Activated:Fire();release()
        check(#plays==before,"excluded dismiss control has no audio: "..name)
        check(not ownedScale(button),"excluded dismiss control has no motion: "..name)
        check(actions==1,"dismiss action remains owned by its existing handler")
        connection:Disconnect()
    end
end)

test("phone subtree retains exclusive audio and motion ownership",function()
    local f=fixture();local phone=object("ScreenGui","SpyPhoneUI",f.pg)
    local nested=object("Frame","PhoneBody",phone);local button=object("TextButton","PhoneSend",nested)
    f:start();local before=#plays
    button.MouseEnter:Fire();button.SelectionGained:Fire();press(button,"Touch");button.Activated:Fire();release("Touch")
    check(#plays==before,"phone controls do not receive generic audio")
    check(not ownedScale(button),"phone controls do not receive generic scale")
end)

test("hover press and global release animate only the owned scale",function()
    local f=fixture();local size,position=f.button.Size,f.button.Position
    local transparency,auto=f.button.BackgroundTransparency,f.button.AutoButtonColor
    local background={R=.14,G=.25,B=.36};local text={R=.91,G=.85,B=.7}
    f.button.BackgroundColor3=background;f.button.TextColor3=text
    local stroke=object("UIStroke","AuthoredStroke",f.button)
    local strokeColor={R=.7,G=.6,B=.2};stroke.Color=strokeColor;stroke.Thickness=1.7;stroke.Transparency=.42
    f:start();f.button.MouseEnter:Fire()
    local scale=ownedScale(f.button);check(scale~=nil,"eligible hover creates an owned UIScale")
    close(scale.Scale,1.01,"hover subtly lifts scale")
    press(f.button);close(scale.Scale,.985,"mouse press compresses scale")
    release();close(scale.Scale,1,"global mouse release restores scale")
    check(f.button.Size==size and f.button.Position==position,"feedback preserves authored geometry")
    check(f.button.BackgroundTransparency==transparency and f.button.AutoButtonColor==auto,"feedback preserves authored styling")
    check(f.button.BackgroundColor3==background and f.button.TextColor3==text,"feedback preserves authored background and text colors")
    check(stroke.Parent==f.button and stroke.Color==strokeColor and stroke.Thickness==1.7 and stroke.Transparency==.42,
        "feedback preserves the authored stroke and its color thickness and transparency")
end)

test("touch and gamepad ButtonA release outside the button",function()
    local f=fixture();f:start()
    for _,kind in ipairs({"Touch","ButtonA"})do
        local pressed=press(f.button,kind)
        local scale=ownedScale(f.button);check(scale~=nil,"eligible "..kind.." press creates owned scale")
        close(scale.Scale,.985,kind.." input presses")
        release(pressed);close(scale.Scale,1,kind.." global release restores scale")
    end
end)

test("releasing an unrelated touch preserves the active finger press",function()
    local f=fixture();f:start();local pressed=press(f.button,"Touch")
    local scale=ownedScale(f.button);check(scale~=nil,"touch press creates scale")
    release(input("Touch"));close(scale.Scale,.985,"a different finger ending does not release this press")
    release(pressed);close(scale.Scale,1,"the active finger ending releases its press")
end)

test("global ButtonA input presses the selected gamepad control once",function()
    local f=fixture();f:start();f.button.SelectionGained:Fire()
    local scale=ownedScale(f.button);check(scale~=nil,"selection creates owned hover scale")
    local buttonA=input("ButtonA");buttonA.UserInputType=Enum.UserInputType.Gamepad1
    local before=#tweens
    services.UserInputService.InputBegan:Fire(buttonA,false)
    close(scale.Scale,.985,"global ButtonA presses the selected control")
    f.button.InputBegan:Fire(buttonA,false)
    check(#tweens==before+1,"the same gamepad input delivered twice starts one press tween")
    release("ButtonA");close(scale.Scale,1,"global ButtonA release restores selected control")
end)

test("a held gamepad press plays once through leave release and activation",function()
    local f=fixture();local actions=0
    f.button.Activated:Connect(function()actions+=1 end)
    f:start();f.button.SelectionGained:Fire();local before=#plays
    local buttonA=input("ButtonA")
    services.UserInputService.InputBegan:Fire(buttonA,false);f.button.InputBegan:Fire(buttonA,false)
    check(#plays==before+1,"global and button delivery of one input produce one click")
    advance(12);f.button.MouseLeave:Fire();release(buttonA);f.button.Activated:Fire(buttonA,1)
    check(#plays==before+1,"a long hold and leave/release events preserve activation dedupe")
    check(actions==1,"the existing gamepad action executes once")
    local nextPress=input("ButtonA")
    services.UserInputService.InputBegan:Fire(nextPress,false);f.button.InputBegan:Fire(nextPress,false)
    release(nextPress);f.button.Activated:Fire(nextPress,1)
    check(#plays==before+2,"a subsequent physical press receives one fresh click")
    check(actions==2,"the subsequent physical activation executes one fresh action")
end)

test("focus loss releases an active press",function()
    local f=fixture();f:start();press(f.button)
    local scale=ownedScale(f.button);check(scale~=nil,"press creates scale")
    services.UserInputService.WindowFocusReleased:Fire()
    close(scale.Scale,1,"window focus loss restores neutral scale")
end)

test("new motion cancels its previous tween and reduced motion resets",function()
    local f=fixture();f:start();f.button.MouseEnter:Fire()
    local scale=ownedScale(f.button);check(scale~=nil,"hover creates scale")
    local previous=tweens[#tweens];press(f.button)
    check(previous.cancelled,"press cancels the hover tween")
    local active=tweens[#tweens];f:set("reducedMotion",true)
    close(scale.Scale,1,"enabling reduced motion resets active scale")
    check(active.cancelled,"enabling reduced motion cancels active tween")
    local before=#tweens;f.button.MouseLeave:Fire();f.button.MouseEnter:Fire();press(f.button);release()
    check(#tweens==before,"reduced motion starts no new tween")
end)

test("initial reduced motion skips animation but retains audio",function()
    local f=fixture({reducedMotion=true});f:start();local beforeTweens=#tweens;local before=#plays
    f.button.MouseEnter:Fire();press(f.button);f.button.Activated:Fire();release()
    check(#tweens==beforeTweens,"reduced motion preference prevents animation")
    check(#plays==before+2,"reduced motion keeps hover and action audio")
end)

test("existing foreign scale is never animated or overwritten",function()
    local f=fixture();local foreign=object("UIScale","ModalScale",f.button);foreign.Scale=.73
    local writes=foreign._scaleWrites
    f:start();local before=#plays;local beforeTweens=#tweens
    f.button.MouseEnter:Fire();press(f.button);release();f.button.Activated:Fire()
    close(foreign.Scale,.73,"foreign scale keeps its owner's value")
    check(foreign._scaleWrites==writes,"foreign scale receives no direct Scale writes")
    check(not ownedScale(f.button),"foreign scale suppresses owned scale creation")
    check(#tweens==beforeTweens,"foreign scale gets no tween")
    check(#plays==before+2,"foreign scale does not suppress audio")
end)

test("a foreign scale sharing the binder name is still owned by its author",function()
    local f=fixture();local foreign=object("UIScale","SpyUIFeedbackScale",f.button);foreign.Scale=.77
    local writes=foreign._scaleWrites;f:start();local before=#tweens
    f.button.MouseEnter:Fire();press(f.button);release();f.controller:destroy()
    close(foreign.Scale,.77,"name collision does not transfer scale ownership")
    check(foreign._scaleWrites==writes,"name collision receives no feedback writes")
    check(foreign.Parent==f.button and not foreign._destroyed,"destroy preserves a foreign scale sharing the owned name")
    check(#tweens==before,"name collision receives no tween")
end)

test("synchronous owner scale wins over deferred initial binding",function()
    local f=fixture();f.controller=UIFeedback.start(f.pg,f.player)
    local foreign=object("UIScale","LateAuthoredScale",f.button);foreign.Scale=.81
    advance(0);f.button.MouseEnter:Fire();press(f.button);release()
    close(foreign.Scale,.81,"owner's synchronous scale remains unchanged")
    check(not ownedScale(f.button),"deferred initial bind recognizes owner scale")
end)

test("a future foreign scale cancels and resets active generic motion",function()
    local f=fixture();f:start();press(f.button)
    local scale=ownedScale(f.button);check(scale~=nil,"press creates scale")
    local active=tweens[#tweens]
    local foreign=Instance.new("UIScale");foreign.Name="RewardAnimationScale";foreign.Scale=.65;foreign.Parent=f.button
    local writes=foreign._scaleWrites
    check(active.cancelled,"foreign ownership cancels an active feedback tween")
    close(scale.Scale,1,"owned feedback scale is reset when foreign owner appears")
    local before=#tweens;f.button.MouseEnter:Fire();press(f.button);release()
    close(foreign.Scale,.65,"future foreign scale is never changed")
    check(foreign._scaleWrites==writes,"future foreign scale receives no direct Scale writes")
    check(#tweens==before,"foreign owner prevents later generic motion")
end)

test("authored cleanup of the owned scale recovers on a later interaction",function()
    local f=fixture();f:start();f.button.MouseEnter:Fire()
    local original=ownedScale(f.button);check(original~=nil,"first hover creates owned scale")
    original:Destroy();f.button.MouseLeave:Fire();advance(.1);f.button.MouseEnter:Fire()
    local replacement=ownedScale(f.button)
    check(replacement~=nil and replacement~=original,"later hover replaces the removed feedback scale")
    close(replacement.Scale,1.01,"replacement scale receives hover motion")
    local count=0
    for _,child in ipairs(f.button:GetChildren())do if child:IsA("UIScale")then count+=1 end end
    check(count==1,"recovering an owned scale creates no duplicates")
end)

test("special topic and ballot owners keep scale while retaining audio",function()
    local f=fixture();f:start()
    local buttons={}
    for _,name in ipairs({"TopicPanel","BallotOverlay","BallotPanel"})do
        local owner=object("Frame",name,f.screen);buttons[#buttons+1]=object("TextButton","Choice",owner)
    end
    for _,name in ipairs({"Suspect_42","AnotherClueRound"})do buttons[#buttons+1]=object("TextButton",name,f.panel)end
    local themed=object("TextButton","NoirTheme",f.panel);themed:SetAttribute("ThemeId","noir");buttons[#buttons+1]=themed
    advance(0)
    for _,button in ipairs(buttons)do
        advance(.2);local before=#plays
        button.MouseEnter:Fire();press(button);button.Activated:Fire();release()
        check(not ownedScale(button),"special control keeps motion owner: "..button.Name)
        check(#plays==before+2,"special control retains hover and click audio: "..button.Name)
    end
end)

test("hiding or disabling an ancestor immediately resets pressed motion",function()
    local f=fixture();f:start()
    for _,entry in ipairs({{f.panel,"Visible"},{f.screen,"Enabled"},{f.button,"Active"}})do
        press(f.button);local scale=ownedScale(f.button);check(scale~=nil,"press creates owned scale")
        entry[1][entry[2]]=false
        close(scale.Scale,1,"changing "..entry[2].." cancels active feedback")
        entry[1][entry[2]]=true;release()
    end
end)

test("dynamic descendants bind once and removal disconnects feedback",function()
    local f=fixture();f:start()
    local owner=object("Frame","NewModal")
    local button=object("ImageButton","DynamicAction",owner);owner.Parent=f.screen;advance(0)
    local before=#plays;button.Activated:Fire()
    check(#plays==before+1,"new descendant gets one click binding")
    press(button);local scale=ownedScale(button);check(scale~=nil,"dynamic control gets motion")
    owner.Parent=nil
    close(scale.Scale,1,"removal resets owned scale before detaching")
    before=#plays;button.MouseEnter:Fire();press(button);button.Activated:Fire();release()
    check(#plays==before,"detached control has no feedback callbacks")
    owner:Destroy()
end)

test("removed descendants are not bound by queued deferred work",function()
    local f=fixture();f:start()
    local button=object("TextButton","TransientButton",f.panel);button.Parent=nil;advance(0)
    local before=#plays;button.MouseEnter:Fire();press(button);button.Activated:Fire();release()
    check(#plays==before,"deferred binding ignores a removed button")
    check(not ownedScale(button),"deferred binding adds no scale to a removed button")
    button:Destroy()
end)

test("reparented controls watch their new ancestor and rebind once",function()
    local f=fixture();f:start()
    local nextPanel=object("Frame","NextPanel",f.screen)
    f.button.Parent=nextPanel;advance(0);press(f.button)
    local scale=ownedScale(f.button);check(scale~=nil,"reparented control still receives press motion")
    nextPanel.Visible=false;close(scale.Scale,1,"new hidden ancestor resets active motion")
    nextPanel.Visible=true;f.button.Parent=nil;f.button.Parent=f.panel;advance(0)
    local before=#plays;f.button.Activated:Fire()
    check(#plays==before+1,"remove and readd produces one action sound")
end)

test("destroy resets motion removes audio and disconnects service hooks",function()
    local f=fixture();local baseline=activeConnections();f:start();press(f.button)
    local scale=ownedScale(f.button);check(scale~=nil,"press creates scale")
    f.controller:destroy();f.controller:destroy()
    close(scale.Scale,1,"destroy restores neutral scale")
    local folder=ownSounds();check(not folder,"destroy removes owned sound folder")
    local before=#plays;f.button.MouseEnter:Fire();press(f.button);f.button.Activated:Fire();release()
    services.UserInputService.WindowFocusReleased:Fire();f:set("reducedMotion",true)
    check(#plays==before,"destroyed controller produces no feedback")
    check(activeConnections()==baseline,"destroy disconnects instance service and preference hooks")
end)

test("PlayerGui destruction cleans up the controller",function()
    local f=fixture();local baseline=activeConnections();f:start();f.pg:Destroy();advance(0)
    local folder=ownSounds();check(not folder,"destroying root removes owned audio")
    check(activeConnections()==baseline,"destroying root disconnects external service hooks")
end)

print(string.format("UI feedback: %d passed, %d failures, %d assertions",passed,failures,checks))
assert(failures==0,"UI feedback checks failed")
