-- Test product constraints: legible controls, safe bounds and one centered bar.
-- Changing column allocation, primary visibility or small-window spacing breaks these.
local checks=0
local function check(value,message) checks+=1;assert(value,message)end
local function near(a,b,message)check(math.abs(a-b)<.0001,message)end
local env=setmetatable({
 game={GetService=function()return{}end},
 Color3={fromRGB=function(r,g,b)return{r,g,b}end},
},{__index=getfenv(0)})
local chunk=assert(loadstring(hudSource,"MatchHUD-under-test"));setfenv(chunk,env)
local HUD=chunk()
local function within(rect,v,name)
 check(rect.x>=0 and rect.y>=0,name.." starts inside canvas")
 check(rect.x+rect.w<=v.X and rect.y+rect.h<=v.Y,name.." fits canvas")
end
for _,size in ipairs({{1920,1080},{1280,720},{768,1024},{390,844},{320,568},{844,390},{568,320},{280,180}})do
 local v={X=size[1],Y=size[2]}
 for _,touch in ipairs({false,true})do
  local m=HUD.metrics(v,touch,{ready=true,guess=true})
  for _,key in ipairs({'phase','controls','ready','guess','dock'})do within(m[key],v,key)end
  check(m.controls.h>=44 and m.ready.h>=44 and m.dock.h>=44,'touch targets stay usable')
  check(m.controls.w/2-5>=44,'card and chat stay tappable')
  near(m.controls.y,m.dock.y,'utility menu shares bottom row')
  near(m.controls.x+m.controls.w+8,m.dock.x,'utilities form one bar')
  near(m.controls.x+(m.controls.w+8+m.dock.w)/2,v.X/2,'utility bar centers on canvas')
  check(m.ready.x+m.ready.w<=m.guess.x,'simultaneous primary actions do not overlap')
  check(m.ready.y+m.ready.h<=m.controls.y,'primary action clears utility row')
  check(m.phase.y+m.phase.h<=m.ready.y,'phase panel clears actions in small windows')
  local ready=HUD.metrics(v,touch,{ready=true,guess=false}).ready
  local guess=HUD.metrics(v,touch,{ready=false,guess=true}).guess
  near(ready.x+ready.w/2,v.X/2,'only turn action is centered')
  near(guess.x+guess.w/2,v.X/2,'only spy action is centered')
  check(ready.w>m.ready.w,'one action uses available width')
  check(guess.w>m.guess.w,'one spy action uses available width')
 end
end
check(HUD.metrics({X=1280,Y=720},false).phase.h<=100,'desktop phase strip stays compact')
check(type(HUD.visibility)=='function','phase visibility is explicit')
for _,phase in ipairs({'Hint','Discuss','ExtraRound'})do
 local view=HUD.visibility(phase,false)
 check(view.menu and view.primary,'context actions available during '..phase)
end
for _,phase in ipairs({'Waiting','TopicVote','TopicChosen','Role','Vote','Result','Finished'})do
 local view=HUD.visibility(phase,false)
 check(view.menu and not view.primary,'character menu stays accessible during '..phase)
end
for _,phase in ipairs({'Intro','VoteAccepted','ReturnFailed','Unknown'})do
 local view=HUD.visibility(phase,false)
 check(not view.menu and not view.primary,'no action over cinematic or non-state '..phase)
end
for _,phase in ipairs({'Hint','Discuss','Vote','Result'})do
 local view=HUD.visibility(phase,true)
 check(not view.menu and not view.primary,'modal suppresses match controls during '..phase)
end
check(not HUD.visibility(nil,false).menu,'missing session has no menu')
check(type(HUD.modal)=='function','modal layout reserves the utility footer')
for _,size in ipairs({{1920,1080},{390,844},{320,568},{844,390},{568,320},{280,180}})do
 local v={X=size[1],Y=size[2]};local utilities=HUD.metrics(v,true).dock
 for _,preferred in ipairs({{664,448},{640,440},{620,410}})do
  local panel=HUD.modal(v,preferred[1],preferred[2])
  within(panel,v,'phase modal')
  check(panel.y+panel.h<=utilities.y-12,'ballot/theme/result footer clears utility hitboxes')
  near(panel.x+panel.w/2,v.X/2,'phase modal centers horizontally')
 end
end
check(type(HUD.ballot)=='function','ballot inner layout responds to reserved panel height')
check(type(HUD.topic)=='function','theme inner layout responds to reserved panel height')
for _,size in ipairs({{280,180},{320,240},{568,320},{844,390},{390,844}})do
 local v={X=size[1],Y=size[2]}
 local ballotPanel=HUD.modal(v,664,448);local ballot=HUD.ballot(ballotPanel.h)
 check(ballot.choicesHeight>=44,'suspect list retains a usable touch viewport')
 check(ballot.choicesTop+ballot.choicesHeight<=ballotPanel.h-44-ballot.confirmBottom,'suspect list clears confirmation')
 local topicPanel=HUD.modal(v,640,440);local topic=HUD.topic(topicPanel.h)
 check(topic.choicesHeight>=44,'theme choices retain a usable touch viewport')
 check(topic.choicesTop+topic.choicesHeight<=topicPanel.h,'theme choices fit the reserved panel')
end
print('MatchHUD layout: '..checks..' assertions passed (actual module geometry; Studio was not run)')
