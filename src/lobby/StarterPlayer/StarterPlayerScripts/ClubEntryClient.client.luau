-- Optional presentation layer. The independent BootClient keeps its hard loading deadline.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
if player:GetAttribute("SpyEntryCompleted")==true then return end
player:SetAttribute("SpyEntryPending",true)
local controller,screen,hero,guiConnection,entryDepth,entryMusic,selectionConnection
local depthConnections={}
local hidden={}
local visibilityConnections={}
local hideNames={HudGui=true,SpyClubUI=true,SpyLobbyPolishUI=true,SpyClubCinematicTour=true,SpyCreatorLauncher=true,SpyPlayerDirectory=true,SpyChatFrontend=true}
local function clearSelection()
    -- Clear our focus before hiding the portrait or restoring the lobby HUD.
    -- Do not let the navigator carry movement keys into the next visible button.
    pcall(function()
        local selected=GuiService.SelectedObject
        if selected and screen and selected:IsDescendantOf(screen) then GuiService.SelectedObject=nil end
    end)
end
local function clearDepth()
    for _,c in ipairs(depthConnections)do c:Disconnect()end;table.clear(depthConnections)
    if entryDepth then entryDepth:Destroy();entryDepth=nil end
end
local function close()
    if selectionConnection then selectionConnection:Disconnect();selectionConnection=nil end
    clearSelection()
    clearDepth()
    if entryMusic then pcall(function()entryMusic:Stop()end);entryMusic:Destroy();entryMusic=nil end
    if guiConnection then guiConnection:Disconnect();guiConnection=nil end
    for _,connection in ipairs(visibilityConnections) do connection:Disconnect() end
    table.clear(visibilityConnections)
    for gui,enabled in pairs(hidden) do if gui.Parent then gui.Enabled=enabled end end
    table.clear(hidden)
    if hero then hero:destroy();hero=nil end
    if screen then screen:Destroy();screen=nil end
    player:SetAttribute("SpyEntryPending",false)
    player:SetAttribute("SpyEntryActive",false)
    player:SetAttribute("SpyEntryCompleted",true)
end
local function abort()
    if controller then controller.finish() else close() end
end
script.Destroying:Connect(abort)
player.CharacterRemoving:Connect(abort)
-- This timer covers missing scene, UI or modules. It never waits on profile/chat/admin initialization.
task.delay(15,function() if not controller or not controller.active then abort() end end)
task.spawn(function()
    local ok,err=xpcall(function()
        local pg,anchor,module,set
        for _=1,48 do
            if player:GetAttribute("SpyEntryCompleted")==true then return end
            if player:GetAttribute("SpyReturnedFromMatch")==true or player:GetAttribute("SpyTeleporting")==true then close();return end
            pg=player:FindFirstChildOfClass("PlayerGui")
            local club=workspace:FindFirstChild("SpyClub")
            set=club and club:FindFirstChild("NocturneLounge")
            anchor=set and set:FindFirstChild("EntryCamera")
            local shared=Storage:FindFirstChild("SpyShared")
            module=shared and shared:FindFirstChild("ClubEntryController")
            if pg and anchor and module and workspace.CurrentCamera then break end
            task.wait(.25)
        end
        if not (pg and anchor and module and workspace.CurrentCamera) then close();return end
        local function make(class,parent,props)
            local n=Instance.new(class);for k,v in pairs(props) do n[k]=v end;n.Parent=parent;return n
        end
        screen=make("ScreenGui",pg,{Name="SpyClubEntry",DisplayOrder=700,ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
        local scrim=make("Frame",screen,{Name="InvitationScrim",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(9,10,12),BackgroundTransparency=0,BorderSizePixel=0,Active=true})
        local shade=make("UIGradient",scrim,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.48,1),NumberSequenceKeypoint.new(.72,.77),NumberSequenceKeypoint.new(1,.36)})})
        local panel=make("Frame",screen,{Name="Invitation",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-56,.5,0),Size=UDim2.fromOffset(360,318),BackgroundTransparency=1,BorderSizePixel=0})
        local function text(name,value,y,height,size,color)
            return make("TextLabel",panel,{Name=name,Text=value,Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,0,0,height),BackgroundTransparency=1,
                Font=Enum.Font.Roboto,TextSize=size,TextColor3=color,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
        end
        local localeEnglish=game:GetService("LocalizationService").SystemLocaleId:sub(1,2)=="en"
        local function isEnglish()
            local language=player:GetAttribute("SpyLanguage")
            return language=="en" or (language==nil and localeEnglish)
        end
        local english=isEnglish()
        local ice=Color3.fromRGB(203,186,145)
        local heading=text("Wordmark","SPY\nCLUB",0,224,86,Color3.fromRGB(238,235,224))
        heading.Font=Enum.Font.Bodoni;heading.TextYAlignment=Enum.TextYAlignment.Top
        local enter=make("TextButton",panel,{Name="EnterLobby",Position=UDim2.fromOffset(0,256),Size=UDim2.new(1,0,0,56),BackgroundColor3=ice,BackgroundTransparency=.06,BorderSizePixel=0,
            Text=english and "ENTER THE CLUB    →" or "ВОЙТИ В КЛУБ    →",Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(30,32,29),AutoButtonColor=false,Selectable=true})
        make("UICorner",enter,{CornerRadius=UDim.new(0,2)})
        local outline=make("UIStroke",enter,{Name="EntryButtonOutline",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=ice,Thickness=1,Transparency=.30})
        local rule=make("Frame",panel,{Name="MastheadRule",Size=UDim2.fromOffset(1,220),Position=UDim2.fromOffset(-22,2),BackgroundColor3=ice,BackgroundTransparency=.25,BorderSizePixel=0})
        -- Short briefing on every fresh visit; no dependencies on profiles, badges or chat.
        local rules=make("CanvasGroup",screen,{Name="ClubRules",Visible=false,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(660,440),BackgroundColor3=Color3.fromRGB(228,223,209),BorderSizePixel=0,GroupTransparency=0})
        make("UICorner",rules,{CornerRadius=UDim.new(0,3)})
        make("UIStroke",rules,{Color=Color3.fromRGB(143,137,121),Transparency=.4,Thickness=1})
        local rulesTitle=make("TextLabel",rules,{Name="Title",BackgroundTransparency=1,Position=UDim2.fromOffset(24,20),Size=UDim2.new(1,-48,0,42),Font=Enum.Font.GothamBold,TextSize=30,TextColor3=Color3.fromRGB(31,39,36),TextXAlignment=Enum.TextXAlignment.Left})
        local ruleList=make("ScrollingFrame",rules,{Name="RuleList",Position=UDim2.fromOffset(24,86),Size=UDim2.new(1,-48,1,-170),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Active=true,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=3,ScrollBarImageColor3=Color3.fromRGB(92,103,92)})
        local rows={}
        for i=1,3 do
            local row=make("Frame",ruleList,{Name="Rule"..i,BackgroundTransparency=1,BorderSizePixel=0})
            local number=make("TextLabel",row,{Name="Number",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(30,30),BackgroundColor3=Color3.fromRGB(41,66,56),BorderSizePixel=0,Text=tostring(i),Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(242,239,228)})
            make("UICorner",number,{CornerRadius=UDim.new(1,0)})
            local title=make("TextLabel",row,{Name="Heading",BackgroundTransparency=1,Position=UDim2.fromOffset(44,0),Size=UDim2.new(1,-44,0,27),Font=Enum.Font.GothamBold,TextSize=18,TextColor3=Color3.fromRGB(31,39,36),TextXAlignment=Enum.TextXAlignment.Left})
            local body=make("TextLabel",row,{Name="Body",BackgroundTransparency=1,Position=UDim2.fromOffset(44,29),Size=UDim2.new(1,-44,1,-29),Font=Enum.Font.Gotham,TextSize=16,TextColor3=Color3.fromRGB(72,78,71),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true})
            rows[i]={frame=row,title=title,body=body}
        end
        local enterClub=make("TextButton",rules,{Name="EnterClub",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,24,1,-20),Size=UDim2.new(1,-48,0,52),BackgroundColor3=Color3.fromRGB(41,66,56),BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(242,239,228),AutoButtonColor=false,Selectable=true})
        make("UICorner",enterClub,{CornerRadius=UDim.new(0,3)})
        local briefing={
            ru={{"Не мусори","Береги обстановку. После партии оставь стол чистым для следующих гостей."},{"Играй честно","Не выдавай чужую роль и не подсказывай соседнему столу."},{"Уважай гостей","Без оскорблений и спама. Не публикуй чужие личные данные."}},
            en={{"Leave a clean table","Take care of the club. Leave the table clean for the next guests."},{"Play fair","Keep other players' roles secret. Do not give clues to another table."},{"Respect the guests","No insults or spam. Keep other people's personal information private."}},
        }
        local function translate()
            english=isEnglish()
            rulesTitle.Text=english and "Club rules" or "Правила клуба"
            enterClub.Text=english and "ENTER THE CLUB    →" or "ВОЙТИ В КЛУБ    →"
            for i,row in ipairs(rows)do local copy=briefing[english and "en" or "ru"][i];row.title.Text=copy[1];row.body.Text=copy[2]end
        end
        translate()
        local languageConnection=player:GetAttributeChangedSignal("SpyLanguage"):Connect(translate)
        screen.Destroying:Connect(function()languageConnection:Disconnect()end)
        local function hide(gui)
            if gui:IsA("ScreenGui") and hideNames[gui.Name] and hidden[gui]==nil then
                hidden[gui]=gui.Enabled;gui.Enabled=false
                table.insert(visibilityConnections,gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if gui.Enabled then hidden[gui]=true;gui.Enabled=false end
                end))
            end
        end
        for _,gui in ipairs(pg:GetChildren()) do hide(gui) end
        guiConnection=pg.ChildAdded:Connect(hide)
        local curtain
        local fadeScreen
        local function revealWorld()
            clearSelection()
            clearDepth()
            if screen then screen.Enabled=false end
            if fadeScreen then
                local captured=fadeScreen
                task.delay(.35,function()captured:Destroy()end)
                local faded=pcall(function()
                    game:GetService("TweenService"):Create(curtain,TweenInfo.new(.3),{BackgroundTransparency=1}):Play()
                end)
                if not faded then captured:Destroy()end
            end
        end
        local rawClose=close
        local function finishPresentation()
            rawClose()
            if fadeScreen then
                local captured=fadeScreen
                -- Register destruction before the optional animation: an engine error cannot strand an opaque GUI.
                task.delay(.35,function()captured:Destroy()end)
                task.delay(.7,function()if captured.Parent then captured:Destroy()end end)
                local faded=pcall(function()
                    game:GetService("TweenService"):Create(curtain,TweenInfo.new(.3),{BackgroundTransparency=1}):Play()
                end)
                if not faded then captured:Destroy() end
            end
        end
        local function fadeOut()
            clearDepth()
            fadeScreen=make("ScreenGui",pg,{Name="SpyEntryFade",DisplayOrder=701,IgnoreGuiInset=true,ResetOnSpawn=false})
            curtain=make("Frame",fadeScreen,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(9,10,12),BackgroundTransparency=1,BorderSizePixel=0,Active=true})
            game:GetService("TweenService"):Create(curtain,TweenInfo.new(.2),{BackgroundTransparency=0}):Play()
        end
        local mobileAnchor=set:FindFirstChild("MobileCamera")
        local function portraitViewport()
            local v=workspace.CurrentCamera.ViewportSize
            return v.X<600 and v.Y>v.X
        end
        local framedPortrait=portraitViewport()
        local startFrame=framedPortrait and mobileAnchor and mobileAnchor.CFrame or anchor.CFrame
        controller=require(module).create({player=player,workspace=workspace,input=Input,actions=game:GetService("ContextActionService"),run=game:GetService("RunService"),prompts=game:GetService("ProximityPromptService"),
            tweens=game:GetService("TweenService"),delay=task.delay,close=finishPresentation,openingFrame=framedPortrait and startFrame or(set:FindFirstChild("OpeningCamera") and set.OpeningCamera.CFrame),exitFrame=set:FindFirstChild("ExitCamera") and set.ExitCamera.CFrame,fadeOut=fadeOut,revealWorld=revealWorld})
        if not controller:start(startFrame) then return end
        local shared=Storage:FindFirstChild("SpyShared")
        local portrait=shared and shared:FindFirstChild("ClubEntryHero")
        if portrait then
            local loaded,value=pcall(function()return require(portrait).create({player=player,set=set,run=game:GetService("RunService"),delay=task.delay})end)
            if loaded then hero=value else warn("[ClubPortrait] "..tostring(value))end
        end
        -- Verified Creator Store instrumental; Loaded never gates entry.
        pcall(function()
            entryMusic=make("Sound",nil,{Name="SpyEntryMusic",SoundId="rbxassetid://1837228361",Volume=.24,Looped=true})
            entryMusic:SetAttribute("SpyAudioCategory","Music")
            entryMusic.Parent=game:GetService("SoundService")
            entryMusic:Play()
        end)
        -- Optional native controls can arrive after the room; never wait for them in boot.
        task.spawn(function()
            for _=1,60 do
                if not controller.active then return end
                local ps=player:FindFirstChild("PlayerScripts")
                local native=ps and ps:FindFirstChild("PlayerModule")
                if native then
                    local loaded,value=pcall(function()return require(native):GetControls()end)
                    if loaded and value then controller:setControls(value)end
                    return
                end
                task.wait(.2)
            end
        end)
        player:SetAttribute("SpyEntryPresented",true)
        local function preference(name)
            local value=player:GetAttribute(name)
            return value==true
        end
        local function fit()
            local v=workspace.CurrentCamera.ViewportSize
            local portrait=v.X<600 and v.Y>v.X
            local compact=portrait or v.Y<450
            local width=math.min(compact and 300 or 360,math.max(220,v.X-48))
            local height=compact and 132 or 318
            panel.Size=UDim2.fromOffset(width,height)
            local rw=math.min(660,math.max(260,v.X-32));local rh=math.min(440,v.Y-28)
            rules.Size=UDim2.fromOffset(rw,rh)
            local small=rw<480;local short=rh<400
            rulesTitle.TextSize=small and 24 or 30
            rulesTitle.Position=UDim2.fromOffset(24,short and 10 or 20)
            local rowTop=short and 64 or 86;local listHeight=rh-rowTop-84
            ruleList.Position=UDim2.fromOffset(24,rowTop);ruleList.Size=UDim2.new(1,-48,0,listHeight)
            local rowHeight=math.max(86,math.floor(listHeight/3))
            for i,row in ipairs(rows)do
                row.frame.Position=UDim2.fromOffset(0,(i-1)*rowHeight)
                row.frame.Size=UDim2.new(1,-8,0,rowHeight-6)
                row.body.Size=UDim2.new(1,-44,0,rowHeight-35)
                row.title.TextSize=small and 15 or(short and 17 or 18)
                row.body.TextSize=small and 14 or(short and 15 or 16)
            end
            enterClub.Size=UDim2.new(1,-48,0,short and 46 or 52)
            panel.AnchorPoint=Vector2.new(1,portrait and 1 or .5)
            panel.Position=portrait and UDim2.new(1,-24,1,-28) or UDim2.new(1,-math.max(24,math.floor(v.X*.055)),.5,0)
            heading.Text=compact and "SPY CLUB" or "SPY\nCLUB"
            heading.TextSize=compact and (width<280 and 36 or 44) or 86
            heading.Position=UDim2.fromOffset(0,0)
            heading.Size=UDim2.new(1,0,0,compact and 64 or 224)
            rule.Position=UDim2.fromOffset(compact and 0 or -22,compact and 67 or 2)
            rule.Size=compact and UDim2.new(1,0,0,1)or UDim2.fromOffset(1,220)
            enter.Position=UDim2.fromOffset(0,compact and 78 or 256);enter.Size=UDim2.new(1,0,0,compact and 50 or 56)
            shade.Rotation=portrait and 90 or 0
            if portrait~=framedPortrait and mobileAnchor then
                framedPortrait=portrait;controller:setPortraitFrame(portrait and mobileAnchor.CFrame or anchor.CFrame)
            end
        end
        fit()
        local viewportConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
        screen.Destroying:Connect(function() viewportConnection:Disconnect() end)
        local hovering,selected=false,false
        local buttonTween
        local function buttonStyle()
            local focused=enter.Active and (hovering or selected)
            local color=focused and Color3.fromRGB(227,211,175) or ice
            outline.Transparency=enter.Active and (focused and .12 or .55) or .78
            if buttonTween then pcall(function()buttonTween:Cancel()end);buttonTween=nil end
            if player:GetAttribute("SpyReducedMotion")==true then enter.BackgroundColor3=color;return end
            local animated=pcall(function()
                buttonTween=game:GetService("TweenService"):Create(enter,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=color})
                buttonTween:Play()
            end)
            if not animated then enter.BackgroundColor3=color end
        end
        enter.MouseEnter:Connect(function()hovering=true;buttonStyle()end)
        enter.MouseLeave:Connect(function()hovering=false;buttonStyle()end)
        enter.SelectionGained:Connect(function()selected=true;buttonStyle()end)
        enter.SelectionLost:Connect(function()selected=false;buttonStyle()end)
        screen.Destroying:Connect(function()if buttonTween then pcall(function()buttonTween:Cancel()end)end end)
        local function selectEntryButton()
            local gamepad=false
            pcall(function()gamepad=Input.PreferredInput==Enum.PreferredInput.Gamepad end)
            if not gamepad or not controller.active or controller.entering then clearSelection();return end
            local button=rules.Visible and enterClub or enter
            if button.Active and screen.Enabled then
                pcall(function()
                    local selected=GuiService.SelectedObject
                    if not GuiService.MenuIsOpen and (not selected or selected:IsDescendantOf(screen)) then
                        GuiService.SelectedObject=button
                    end
                end)
            end
        end
        selectionConnection=Input:GetPropertyChangedSignal("PreferredInput"):Connect(selectEntryButton)
        local function ready()
            local yes=player:GetAttribute("SpyLoadingReleased")==true
            enter.Active=yes and not controller.entering
            enter.Text=yes and (isEnglish() and "CLICK TO CONTINUE    →" or "ПРОДОЛЖИТЬ    →") or (isEnglish() and "LOADING…" or "ЗАГРУЗКА…")
            enter.BackgroundTransparency=yes and .06 or .55
            buttonStyle()
            selectEntryButton()
        end
        ready()
        if player:GetAttribute("SpyReducedMotion")~=true then
            for _,n in ipairs(panel:GetDescendants())do if n:IsA("TextLabel")or n:IsA("TextButton")then
                n.TextTransparency=1
                local shown=pcall(function()game:GetService("TweenService"):Create(n,TweenInfo.new(.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()end)
                if not shown then n.TextTransparency=0 end
                -- A stalled optional tween cannot hide the invitation indefinitely.
                task.delay(.7,function()if n.Parent then n.TextTransparency=0 end end)
            end end
        end
        local readyConnection=player:GetAttributeChangedSignal("SpyLoadingReleased"):Connect(ready)
        screen.Destroying:Connect(function()readyConnection:Disconnect()end)
        -- Independent boot release is still required; this room is only presentation.
        task.delay(30,function()if controller and controller.active and player:GetAttribute("SpyLoadingReleased")~=true then abort() end end)
        enter.Activated:Connect(function()
            if not enter.Active or not controller.active or rules.Visible then return end
            clearSelection()
            enter.Active=false;panel.Visible=false;rules.Visible=true;translate()
            scrim.BackgroundTransparency=.18;shade.Transparency=NumberSequence.new(.18)
            selectEntryButton()
        end)
        enterClub.Activated:Connect(function()
            if not rules.Visible or not controller.active or controller.entering then return end
            enterClub.Active=false
            clearSelection()
            controller:enter(preference("SpyReducedMotion") or player:GetAttribute("SpyCameraMotion")==false)
        end)
        -- Return restoration may arrive after the scene streamed in.
        -- Camera-local depth belongs solely to this portrait; never a permanent gameplay blur.
        if not Input.TouchEnabled then
            entryDepth=make("DepthOfFieldEffect",workspace.CurrentCamera,{Name="ClubEntryDOF",FarIntensity=.16,NearIntensity=0,FocusDistance=17,InFocusRadius=7,Enabled=false})
            local graphics
            pcall(function()graphics=UserSettings():GetService("UserGameSettings")end)
            local function depthPreference()
                local quality=not graphics or graphics.SavedQualityLevel==Enum.SavedQualitySetting.Automatic or graphics.SavedQualityLevel.Value>3
                if entryDepth then entryDepth.Enabled=quality and controller.active and player:GetAttribute("SpyEffects")~=false and player:GetAttribute("SpyReducedMotion")~=true end
            end
            depthConnections[#depthConnections+1]=player:GetAttributeChangedSignal("SpyEffects"):Connect(depthPreference)
            depthConnections[#depthConnections+1]=player:GetAttributeChangedSignal("SpyReducedMotion"):Connect(depthPreference)
            if graphics then depthConnections[#depthConnections+1]=graphics:GetPropertyChangedSignal("SavedQualityLevel"):Connect(depthPreference)end
            depthPreference()
        end
        local returnConnection=player:GetAttributeChangedSignal("SpyReturnedFromMatch"):Connect(function()
            if player:GetAttribute("SpyReturnedFromMatch")==true then abort() end
        end)
        screen.Destroying:Connect(function() returnConnection:Disconnect() end)
    end,debug.traceback)
    if not ok then warn("[ClubEntry] "..tostring(err));abort() end
end)
