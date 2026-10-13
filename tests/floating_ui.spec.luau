-- Tests run the current project module; no renderer/Roblox Studio result is claimed.
local checks = 0
local function check(value, message)
    checks += 1
    assert(value, message)
end
local function near(actual, expected, message)
    check(math.abs(actual - expected) < 1e-7, message .. ": " .. tostring(actual) .. " vs " .. tostring(expected))
end

local Vector = {}
Vector.__index = Vector
function Vector.new(x,y) return setmetatable({X=x,Y=y},Vector) end
function Vector.__add(a,b) return Vector.new(a.X+b.X,a.Y+b.Y) end
function Vector.__sub(a,b) return Vector.new(a.X-b.X,a.Y-b.Y) end
function Vector.__mul(a,b) return Vector.new(a.X*b,a.Y*b) end
function Vector:Lerp(target,alpha) return Vector.new(self.X+(target.X-self.X)*alpha,self.Y+(target.Y-self.Y)*alpha) end
Vector.zero = Vector.new(0,0)
local UDim2Stub = {}
function UDim2Stub.new(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end

local function signal()
    local self={connections={},created=0,active=0}
    function self:Connect(callback)
        self.created+=1;self.active+=1
        local connection={Connected=true,callback=callback}
        function connection:Disconnect()
            if not self.Connected then return end
            self.Connected=false;self.signal.active-=1
        end
        connection.signal=self
        table.insert(self.connections,connection)
        return connection
    end
    function self:Once(callback)
        local connection
        connection=self:Connect(function(...)
            connection:Disconnect();callback(...)
        end)
        return connection
    end
    function self:Fire(...)
        for _,connection in ipairs(self.connections) do
            if connection.Connected then connection.callback(...) end
        end
    end
    return self
end

local function fixture()
    local render=signal()
    local insetTop,insetBottom=Vector.new(0,36),Vector.zero
    local mouse,focused=Vector.new(500,418),nil
    local input={MouseEnabled=true,TouchEnabled=false}
    function input:GetMouseLocation() return mouse end
    function input:GetFocusedTextBox() return focused end
    local gui={IgnoreGuiInset=false}
    local parent={AbsoluteSize=Vector.new(1000,764)}
    local panel={Position=UDim2Stub.new(.5,0,.5,0),AbsoluteSize=Vector.new(500,400),
        AnchorPoint=Vector.new(.5,.5),Visible=true,Parent=parent,Destroying=signal()}
    function panel:FindFirstAncestorWhichIsA(className) return className=="ScreenGui" and gui or nil end
    local services={
        GuiService={GetGuiInset=function() return insetTop,insetBottom end},
        RunService={RenderStepped=render},UserInputService=input,
    }
    local environment=setmetatable({game={GetService=function(_,name) return assert(services[name],name) end},
        workspace={CurrentCamera={ViewportSize=Vector.new(1000,800)}},Vector2=Vector,UDim2=UDim2Stub},
        {__index=getfenv(0)})
    local chunk=assert(loadstring(controllerSource,"FloatingUIController-under-test"))
    setfenv(chunk,environment)
    local controller=chunk().create(panel,{container=parent,maxOffset=14,smoothTime=.15,safePadding=18})
    return {
        panel=panel,parent=parent,render=render,controller=controller,input=input,gui=gui,
        mouse=function(value) mouse=value end,focus=function(value) focused=value end,
        step=function(dt,count) for _=1,count or 1 do render:Fire(dt) end end,
    }
end

local outcomes={}
for _,fps in ipairs({30,60,144}) do
    local f=fixture();f.controller:setActive(true);f.mouse(Vector.new(10000,10000));f.step(1/fps,fps)
    outcomes[fps]=f.panel.Position.X.Offset
    near(outcomes[fps],14*(1-math.exp(-1/.15)),"Exponential smoothing at "..fps.." FPS")
    check(math.abs(f.panel.Position.X.Offset)<=14 and math.abs(f.panel.Position.Y.Offset)<=14,"14 px movement bounds")
    f.controller:destroy()
end
near(outcomes[30],outcomes[60],"30 and 60 FPS agree")
near(outcomes[60],outcomes[144],"60 and 144 FPS agree")

do
    local f=fixture();f.controller:setActive(true);f.step(1/60,60)
    near(f.panel.Position.X.Offset,0,"GuiInset-adjusted horizontal center")
    near(f.panel.Position.Y.Offset,0,"GuiInset-adjusted vertical center")
    f.mouse(Vector.new(10000,10000));f.step(1/60,20)
    local x,y=f.panel.Position.X.Offset,f.panel.Position.Y.Offset
    f.controller:setPaused(true);f.mouse(Vector.new(-10000,-10000));f.step(1/60,60)
    near(f.panel.Position.X.Offset,x,"Preview drag freezes X")
    near(f.panel.Position.Y.Offset,y,"Preview drag freezes Y")
    f.controller:setPaused(false);f.step(1/60,120)
    check(f.panel.Position.X.Offset<0 and f.panel.Position.Y.Offset<0,"Movement resumes after drag")
    f.focus({});f.step(1/60,180)
    near(f.panel.Position.X.Offset,0,"Focused text input returns floating panel to center")
    f.focus(nil);f.input.TouchEnabled=true;f.mouse(Vector.new(10000,10000));f.step(1/60,60)
    near(f.panel.Position.X.Offset,0,"Touch has no cursor movement")
    near(f.panel.Position.Y.Offset,0,"Touch has no vertical drift")
    f.input.TouchEnabled=false;f.input.MouseEnabled=false;f.step(1/60,60)
    near(f.panel.Position.X.Offset,0,"Missing mouse disables floating movement")
    for _=1,20 do f.controller:setActive(false);f.controller:setActive(true) end
    check(f.render.created==1 and f.render.active==1,"Repeated opens reuse one render connection")
    f.panel.Destroying:Fire()
    check(f.render.active==0,"Panel destruction disconnects RenderStepped")
    f.controller:destroy()
    check(f.render.active==0,"Explicit repeated destruction stays safe")
end

do
    local f=fixture()
    f.controller:setBasePosition(UDim2Stub.new(0,269,0,219))
    f.controller:setActive(true);f.mouse(Vector.new(-10000,-10000));f.step(1/60,120)
    local left=f.panel.Position.X.Offset-250;local top=f.panel.Position.Y.Offset-200
    check(left>=18-1e-8 and top>=18-1e-8,"Floating respects safe left/top margins")
    f.controller:setActive(false)
    near(f.panel.Position.X.Offset,269,"Closing restores base X")
    near(f.panel.Position.Y.Offset,219,"Closing restores base Y")
    f.controller:destroy()
end
print("FloatingUIController: "..checks.." assertions passed (actual module, deterministic input/frame stubs)")
