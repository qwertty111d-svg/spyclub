-- Shares the real camera module and its engine-boundary harness. The runner
-- inserts the corresponding place's real UI close and failure callbacks below;
-- pane animation and selection are the only UI boundaries replaced here.
test("an interrupted UI return releases its standing actor and permits reopening",function()
    local standIn=character("ClosingStandIn")
    local firstStandIn=standIn
    local worldCamera=controller(function()return standIn end)
    local alive,motionToken,sceneSession,scenePhase=true,0,false,"closed"
    local self={visible=false}
    local released=0
    local activePanel
    local ctx={characterSceneClosed=function()
        released+=1
        standIn:Destroy()
    end,getActivePanel=function()return activePanel end,setActivePanel=function(name)
        activePanel=name
        player:SetAttribute("SpyCharacterMenuOpen",name~=nil)
    end}
    local overlay={Visible=false}
    local leftPane,rightPane={},{}
    local leftPosition,rightPosition={},{}
    local drawer,drawerShade={},{}
    local drawerMode,previousSelection
    local GuiService={SelectedObject=nil}
    local function stopSceneTweens()end
    local function stopSpinner()end
    local function gateControls()end
    local function reducedMotion()return false end
    local function animateScene()end
    local function panePosition(position)return position end
    local finishClose
-- CHARACTER_CLOSE_RELEASE_SCENE_SOURCE_INSERT
-- CHARACTER_CLOSE_FINISH_SOURCE_INSERT
-- CHARACTER_CLOSE_METHOD_SOURCE_INSERT
    local function openSession()
        motionToken+=1
        local token=motionToken
        local unavailableSeen=false
        self.visible,sceneSession,scenePhase=true,true,"framing"
        overlay.Visible=true
        ctx.setActivePanel("accessoryRoll")
-- CHARACTER_CLOSE_UNAVAILABLE_SOURCE_INSERT
        return worldCamera:open({onUnavailable=sceneUnavailable})
    end

    check(openSession(),"the UI session acquires its standing actor")
    step(.73)
    self:close()
    advance(.22)
    step(.1)
    check(scenePhase=="returning" and worldCamera.active,"pane close reaches the animated camera return")
    local successor=object("Camera","SuccessorCamera",workspace)
    successor.CFrame=CFrame.new(100,200,300)
    successor.Focus=CFrame.new(14,20,30)
    successor.FieldOfView=81
    successor.CameraType=Enum.CameraType.Custom
    successor.CameraSubject=human
    successor.ViewportSize=camera.ViewportSize
    workspace.CurrentCamera=successor
    step(1);advance(1)
    check(scenePhase=="closed" and not sceneSession,"camera replacement settles the actual UI session")
    check(firstStandIn.Parent==nil and released==1,"the UI releases its standing actor exactly once")
    check(successor.CFrame==CFrame.new(100,200,300) and successor.Focus==CFrame.new(14,20,30)
        and successor.FieldOfView==81 and successor.CameraType==Enum.CameraType.Custom
        and successor.CameraSubject==human,"close cleanup preserves every successor camera property")
    check(controls.controlsEnabled,"the interrupted UI return releases movement controls")
    assertCleanup()

    standIn=character("ReopenedStandIn")
    check(openSession(),"a later UI session can acquire the replacement camera")
    step(.73)
    self:close(false)
    check(scenePhase=="closed" and not sceneSession and standIn.Parent==nil and released==2,
        "the reopened session releases its own standing actor once")
    step(1);advance(1)
    check(released==2 and firstStandIn.Parent==nil,"retired callbacks cannot release either session again")
    assertCleanup()
end)
