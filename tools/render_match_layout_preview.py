#!/usr/bin/env python3
"""Export real match GUI construction/layout as diagnostic HTML and node JSON.

This is not a Roblox renderer. It runs current MatchIntro and TurnControls source
excerpts with the actual MatchHUD module. Native Instance/services, tweens, grid
placement and avatar rendering are explicit boundaries. Sample public state feeds
the real topic/ballot/result presenters; no private role card is rendered.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
INTRO = ROOT / "src/match/StarterPlayer/StarterPlayerScripts/MatchIntroClient.client.luau"
TURN = ROOT / "src/match/StarterPlayer/StarterPlayerScripts/MatchTurnControlsClient.client.luau"
HUD = ROOT / "src/match/ReplicatedStorage/SpyShared/MatchHUD.luau"
I18N = ROOT / "src/match/ReplicatedStorage/SpyShared/I18n.luau"
RETURN = ROOT / "src/match/StarterPlayer/StarterPlayerScripts/MatchReturnLobbyClient.client.luau"
STUB = ROOT / "tests/dossier_ui.spec.luau"


def between(source: str, start: str, end: str) -> str:
    """Fail clearly on source changes, rather than silently fabricating a view."""
    try:
        first = source.index(start)
        last = source.index(end, first + len(start))
    except ValueError as exc:
        raise ValueError(f"Match preview source marker missing: {start!r} / {end!r}") from exc
    return source[first:last]


def long_string(value: str) -> str:
    separator = "===="
    while f"]{separator}]" in value:
        separator += "="
    return f"[{separator}[{value}]{separator}]"


BOUNDARIES = r'''
-- Geometry-only boundaries. Native services and avatars are not simulated.
Vector2.new=function(x,y)return {X=x or 0,Y=y or 0}end
Color3.new=function(r,g,b)return Color3.fromRGB((r or 0)*255,(g or 0)*255,(b or 0)*255)end
guiClasses.ImageLabel=true;guiClasses.ImageButton=true;guiClasses.TextBox=true
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
function Methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function Methods:FindFirstChild(name,recursive)
 for _,child in ipairs(self:GetChildren())do if child.Name==name then return child end end
 if recursive then for _,child in ipairs(self:GetChildren())do local found=child:FindFirstChild(name,true);if found then return found end end end
end
function Methods:GetAttributeChangedSignal(name)return self:GetPropertyChangedSignal('attribute_'..name)end
function Methods:SetAttribute(name,value)
 local old=self._attributes[name];self._attributes[name]=value
 if old~=value and self._signals['attribute_'..name]then self._signals['attribute_'..name]:Fire()end
end
local baseIndex,baseNew=NodeMeta.__index,NodeMeta.__newindex
function NodeMeta.__index(node,key)
 local value=baseIndex(node,key)
 if value~=nil then
  if key=='AbsoluteSize'then
   for _,child in ipairs(node:GetChildren())do if child.ClassName=='UISizeConstraint'then
    local minimum,maximum=child.MinSize or Vector2.new(),child.MaxSize or Vector2.new(math.huge,math.huge)
    return{X=math.clamp(value.X,minimum.X,maximum.X),Y=math.clamp(value.Y,minimum.Y,maximum.Y)}
   end end
  end
  if key=='AbsolutePosition'and node.Parent and node.Parent.ClassName=='ScrollingFrame'then
   local offset=node.Parent.CanvasPosition;return{X=value.X-offset.X,Y=value.Y-offset.Y}
  end
  return value
 end
 return Methods.FindFirstChild(node,key)
end
function NodeMeta.__newindex(node,key,value)
 local previous=node._values[key];baseNew(node,key,value)
 if previous~=value and node._signals[key]then node._signals[key]:Fire()end
end
local nativeNew=Instance.new
function Instance.new(class)
 local node=nativeNew(class)
 node.DescendantAdded,node.ChildRemoved,node.ChildAdded=signal(),signal(),signal()
 if class=='ScreenGui'then node.Size=UDim2.fromScale(1,1);node.Enabled=true end
 return node
end
input.GetPropertyChangedSignal=function()return signal()end
input.TouchEnabled=WIDTH<700
guiService.GetGuiInset=function()return Vector2.zero,Vector2.zero end
-- Tween completion is immediate; no timing, camera or animation claim is made.
tweens.Create=function(_,node,_,properties)
 local completed=signal();completed.Wait=function()end
 return{Play=function()for key,value in pairs(properties)do node[key]=value end;completed:Fire()end,
  Cancel=function()end,Completed=completed}
end
local player=Instance.new('Player');player.UserId=101;player.DisplayName='James Bennett'
player:SetAttribute('SpyLanguage','ru')
local playerGui=Instance.new('PlayerGui');playerGui.AbsoluteSize=Vector2.new(WIDTH,HEIGHT)
playerGui.Name='PlayerGui';playerGui.Parent=player;player.PlayerGui=playerGui
local camera=Instance.new('Camera');camera.ViewportSize=playerGui.AbsoluteSize
local workspace={CurrentCamera=camera}
services.Players={LocalPlayer=player,GetPlayerByUserId=function()return nil end}
services.ReplicatedStorage=Instance.new('ReplicatedStorage')
local session=Instance.new('Folder');session.Name='MatchSession';session.Parent=services.ReplicatedStorage
session:SetAttribute('RoundPhase',({hud='Hint',topic='TopicVote',vote='Vote',result='Result'})[VARIANT])
local remotes=Instance.new('Folder');remotes.Name='MatchRemotes';remotes.Parent=services.ReplicatedStorage
local returnEvent=Instance.new('RemoteEvent');returnEvent.Name='ReturnLobby';returnEvent.OnClientEvent=signal();returnEvent.Parent=remotes
local stateEvent=Instance.new('RemoteEvent');stateEvent.Name='State';stateEvent.OnClientEvent=signal();stateEvent.Parent=remotes
local gui=Instance.new('ScreenGui');gui.Name='MatchUI';gui.Parent=playerGui;gui.DisplayOrder=300
local blackout=Instance.new('Frame');blackout.Name='Blackout';blackout.Visible=false;blackout.Parent=gui
local function loadSource(name,extra)
 local env=setmetatable(extra or{},{__index=getfenv(0)})
 env.game,env.workspace,env.Instance,env.Enum=game,workspace,Instance,Enum
 env.UDim,env.UDim2,env.Vector2,env.Color3,env.TweenInfo=UDim,UDim2,Vector2,Color3,TweenInfo
 env.task,env.TweenService=task,tweens
 local chunk=assert(loadstring(Sources[name],name));setfenv(chunk,env);return chunk()
end
local MatchHUD=loadSource('MatchHUD')
local MatchI18n=loadSource('I18n')
local fixture={phase=({hud='Hint',topic='TopicVote',vote='Vote',result='Result'})[VARIANT],
 turnUserId=101,turnIndex=1,lap=1,hintLaps=2,allowExtraRound=true,
 players={{userId=101,name='James Bennett',displayName='James Bennett',seat=1},
  {userId=102,name='Akira Sato',displayName='Akira Sato',seat=2},
  {userId=103,name='Alice Morgan',displayName='Alice Morgan',seat=3},
  {userId=104,name='Luc Moreau',displayName='Luc Moreau',seat=4}},
 topicOptions={{id='places',title='Места',votes=1},{id='cinema',title='Кино',votes=2},
  {id='objects',title='Предметы',votes=0},{id='travel',title='Путешествия',votes=0}},
 votedCount=3,totalPlayers=4,result={word='Библиотека',reason='caught',spyId=102,caught=true}}
local function playerDisplayName(state,userId)
 for _,info in ipairs(state.players or{})do if info.userId==userId then return info.displayName or info.name end end
 return'Игрок'
end
local actionEvent={FireServer=function()error('Preview cannot send gameplay actions')end}
local common={gui=gui,player=player,playerGui=playerGui,camera=camera,MatchHUD=MatchHUD,MatchI18n=MatchI18n,
 Players=services.Players,ReplicatedStorage=services.ReplicatedStorage,UserInputService=input,
 actionEvent=actionEvent,playerDisplayName=playerDisplayName,VARIANT=VARIANT,script=Instance.new('LocalScript')}
-- All visual constructors and responsive calculations below are real excerpts.
local view=loadSource('View',common)
local turnGui=Instance.new('ScreenGui');turnGui.Name='TurnControls';turnGui.Parent=playerGui;turnGui.DisplayOrder=320
local turn=loadSource('Turn',{gui=turnGui,playerGui=playerGui,player=player,MatchHUD=MatchHUD,UserInputService=input,
 PANEL=view.COLORS.Panel,PANEL_HOVER=view.COLORS.Panel3,BRASS=view.COLORS.Brass,IVORY=view.COLORS.Ivory,MUTED=view.COLORS.Muted})
turn.root.Visible=VARIANT=='hud';turn.root.GroupTransparency=0
view.present(fixture)
loadSource('Return')
if VARIANT=='result'then
 stateEvent.OnClientEvent:Fire({roundToken=1,rematch={revision=1,count=2,required=4,state='idle',readyIds={102,103}}})
end
turn.state.fit()
view.fit()

-- Native UIGridLayout is a documented geometry boundary. Apply its actual
-- CellSize/CellPadding/count/order values; never substitute hand-drawn cards.
for _,layout in ipairs(playerGui:GetDescendants())do
 if layout.ClassName=='UIGridLayout'then
  local parent=layout.Parent;local extent=parent.AbsoluteSize;local children={}
  for _,child in ipairs(parent:GetChildren())do if child:IsA('GuiObject')and child.Visible then children[#children+1]=child end end
  table.sort(children,function(a,b)return(a.LayoutOrder or 0)<(b.LayoutOrder or 0)end)
  local cell,pad=layout.CellSize,layout.CellPadding
  local w,h=extent.X*cell.X.Scale+cell.X.Offset,extent.Y*cell.Y.Scale+cell.Y.Offset
  local px,py=extent.X*pad.X.Scale+pad.X.Offset,extent.Y*pad.Y.Scale+pad.Y.Offset
  local cols=math.min(layout.FillDirectionMaxCells or #children,math.max(1,math.floor((extent.X+px+.01)/(w+px))))
  local used=math.min(cols,#children);local left=layout.HorizontalAlignment==Enum.HorizontalAlignment.Center and(extent.X-(used*w+math.max(0,used-1)*px))*.5 or 0
  for index,child in ipairs(children)do
   child.AnchorPoint=Vector2.new();child.Size=UDim2.fromOffset(w,h)
   child.Position=UDim2.fromOffset(left+(index-1)%cols*(w+px),math.floor((index-1)/cols)*(h+py))
  end
 end
end
local function q(v)return'"'..tostring(v):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'end
local function json(v)
 if type(v)=='string'then return q(v)elseif type(v)=='number'or type(v)=='boolean'then return tostring(v)
 elseif type(v)=='table'then local r={};for k,x in pairs(v)do r[#r+1]=q(k)..':'..json(x)end;return'{'..table.concat(r,',')..'}'
 else return'null'end
end
local nodes={}
for _,node in ipairs(playerGui:GetDescendants())do
 if node:IsA('GuiObject')then
  local visible,alpha,order=true,1,0;local ancestor=node
  local clip={x=0,y=0,right=WIDTH,bottom=HEIGHT}
  while ancestor and ancestor~=playerGui do
   if ancestor.Visible==false or ancestor.ClassName=='ScreenGui'and ancestor.Enabled==false then visible=false;break end
   if ancestor.ClassName=='CanvasGroup'then alpha*=1-(ancestor.GroupTransparency or 0)end
   if ancestor.ClassName=='ScreenGui'then order=ancestor.DisplayOrder or 0 end
   if ancestor~=node and(ancestor.ClipsDescendants or ancestor.ClassName=='ScrollingFrame')then
    local a,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize
    clip.x=math.max(clip.x,a.X);clip.y=math.max(clip.y,a.Y);clip.right=math.min(clip.right,a.X+s.X);clip.bottom=math.min(clip.bottom,a.Y+s.Y)
   end
   ancestor=ancestor.Parent
  end
  if visible and alpha>0 then
   local a,s=node.AbsolutePosition,node.AbsoluteSize
   local radius,strokeColor,strokeAlpha,strokeWidth=0,nil,0,0
   for _,child in ipairs(node:GetChildren())do
    if child.ClassName=='UICorner'then radius=child.CornerRadius.Offset
    elseif child.ClassName=='UIStroke'then strokeColor=child.Color;strokeAlpha=alpha*(1-(child.Transparency or 0));strokeWidth=child.Thickness or 1 end
   end
   nodes[#nodes+1]={name=node.Name or'',class=node.ClassName,x=a.X,y=a.Y,w=s.X,h=s.Y,z=order*10000+node.ZIndex,
    text=node.Text or'',font=node.Font or'',fontSize=node.TextSize or 14,align=tostring(node.TextXAlignment or Enum.TextXAlignment.Center),
    valign=tostring(node.TextYAlignment or''),wrap=node.TextWrapped==true,color=node.TextColor3,bg=node.BackgroundColor3,
    textAlpha=alpha*(1-(node.TextTransparency or 0)),bgAlpha=alpha*(1-(node.BackgroundTransparency or 0)),
    radius=radius,clip=clip,strokeColor=strokeColor,strokeAlpha=strokeAlpha,strokeWidth=strokeWidth}
  end
 end
end
print('LAYOUT:'..json(nodes))
'''


def excerpts() -> dict[str, str]:
    intro, turn = INTRO.read_text(), TURN.read_text()
    colors = between(intro, "local COLORS = {", "local CARD_ACCENT=")
    helpers = between(intro, "local function make(className, parent, props)", "-- FORWARD DECLARATION")
    phase = between(intro, 'matchUI.phaseRoot=make(', "-- CONTROLS")
    utilities = between(intro, 'matchUI.controls=make(', "matchUI.viewShortcut=")
    utilities += between(intro, " matchUI.cardShortcut.Position=", " matchUI.phaseSubtitle.TextWrapped=")
    topics = between(intro, "matchUI.topicRoot =", "local function showChosenTopic(state)")
    ballot_and_result = between(intro, 'matchUI.voteBackdrop=make(', 'camera:GetPropertyChangedSignal("ViewportSize")')
    ballots = between(intro, "local function clearVoteMenu()", "-- RESULT")
    result = between(intro, "local function paintResult()", "local function handleReward(data)")
    show_result = between(intro, "local function showResult(state)", "-- INTRO")
    # The native avatar component is labelled, never a fictional character image.
    view = colors + r'''
local matchUI={}
local MatchPresentation={getMark=function()return nil end,attachPortrait=function(parent)
 local viewport=Instance.new('ViewportFrame');viewport.Name='NativeAvatarPlaceholder'
 viewport.Size=UDim2.fromScale(1,1);viewport.BackgroundTransparency=1;viewport.ZIndex=parent.ZIndex+1;viewport.Parent=parent
end}
''' + helpers + phase + utilities + topics + ballot_and_result + r'''
local voteButtons={};local selectedVoteValue=nil;local voteSubmitted=false;local EXTRA_ROUND_VOTE_VALUE='extra'
local cursorReleased=false;local cardMode='closed';local cardAnimating=false
local function stopSeatedCamera()end
local function hideChatCompletely()end
local function showControls(shown)matchUI.controlsShown=shown;matchUI.controls.Visible=shown;matchUI.controls.GroupTransparency=shown and 0 or 1 end
local function returnCard()end
local function cinemaBars()end
local function resultCamera()end
local function releaseCursor()end
''' + ballots + result + show_result + r'''
local badge=Instance.new('Frame');badge.Visible=false;badge.Parent=gui;matchUI.agentBadge=badge
return{COLORS=COLORS,fit=fitMatchPanels,present=function(state)
 showControls(true)
 matchUI.phaseRoot.GroupTransparency=0
 if VARIANT=='hud'then setTurnPhase(state);matchUI.timer.Text='00:28'
 elseif VARIANT=='topic'then
  showControls(false);matchUI.phaseRoot.GroupTransparency=1;updateTopicVote(state);matchUI.topicTimer.Text='00:18'
 elseif VARIANT=='vote'then openVote(state);matchUI.voteTimer.Text='00:24'
 elseif VARIANT=='result'then
  matchUI.phaseRoot.GroupTransparency=1;matchUI.lastResultState=state
  matchUI.rewardReceipt={state='saved',won=true,rolls=1,xp=120,wins=8,rounds=14}
  showResult(state)
 end
 fitMatchPanels()
end}
'''
    # The real turn action construction and localization, with networking and
    # continuous input/state loops excluded at explicit source markers.
    turn_code = between(turn, "local root =", "local function tweenRoot(")
    turn_code = "local settingsButton=Instance.new('TextButton')\n" + turn_code
    turn_code += "\nreturn {root=root,state=MatchHUD.registerPrimary(playerGui,root,'ready')}\n"
    return {"View": view, "Turn": turn_code, "Return": RETURN.read_text(), "MatchHUD": HUD.read_text(), "I18n": I18N.read_text()}


def rgba(value: dict | None, alpha: float = 1) -> str:
    return "transparent" if not value else f'rgba({value["1"]},{value["2"]},{value["3"]},{alpha})'


def write_html(path: Path, nodes: list[dict], width: int, height: int) -> None:
    blocks = []
    for _, node in sorted(enumerate(nodes), key=lambda pair: (pair[1]["z"], pair[0])):
        w, h = max(0, node["w"]), max(0, node["h"])
        if not w or not h:
            continue
        clip = node["clip"]
        align = "right" if "Right" in node["align"] else "center" if "Center" in node["align"] else "left"
        top, right = max(0, clip["y"] - node["y"]), max(0, node["x"] + w - clip["right"])
        bottom, left = max(0, node["y"] + h - clip["bottom"]), max(0, clip["x"] - node["x"])
        family = "Georgia,serif" if "Garamond" in node["font"] else "Arial,sans-serif"
        style = (f'left:{node["x"]}px;top:{node["y"]}px;width:{w}px;height:{h}px;'
                 f'background:{rgba(node.get("bg"), node["bgAlpha"])};color:{rgba(node.get("color"), node["textAlpha"])};'
                 f'font:{node["fontSize"]}px {family};border-radius:{node["radius"]}px;text-align:{align};'
                 f'clip-path:inset({top}px {right}px {bottom}px {left}px);')
        text = html.escape(node["text"])
        if node["class"] == "ViewportFrame":
            text = '<span style="font:11px Arial;color:#aaa">3D · Roblox Studio</span>'
        valign = "flex-start" if "Top" in node["valign"] else "center"
        wrap = "normal" if node["wrap"] else "nowrap"
        blocks.append(f'<div class="node" title="{html.escape(node["name"])}" style="{style}align-items:{valign}"><span style="width:100%;white-space:{wrap};overflow:hidden;text-overflow:ellipsis">{text}</span></div>')
    path.write_text(f'<!doctype html><meta charset="utf-8"><style>body{{margin:0;background:#19191d;width:{width}px;height:{height}px;overflow:hidden}}.node{{position:absolute;display:flex;box-sizing:border-box;overflow:hidden}}</style>' + "".join(blocks))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("variant", choices=("hud", "topic", "vote", "result"))
    parser.add_argument("--width", type=int, default=1440)
    parser.add_argument("--height", type=int, default=900)
    parser.add_argument("--output", type=Path, required=True, help="Diagnostic .html path; matching .json and .metadata.json are also written")
    args = parser.parse_args()
    if args.width < 200 or args.height < 180:
        parser.error("preview viewport must be at least 200×180")
    prefix = STUB.read_text().split("local Catalog =", 1)[0]
    sources = excerpts()
    # VARIANT is a fixture selector; no supplied text is executed as Luau.
    constants = f"local WIDTH,HEIGHT,VARIANT={args.width},{args.height},{json.dumps(args.variant)}\n"
    encoded = "local Sources={\n" + "\n".join(f"{name}={long_string(value)}," for name, value in sources.items()) + "\n}\n"
    with tempfile.TemporaryDirectory(prefix="spy-match-preview-") as directory:
        path = Path(directory) / "preview.luau"
        path.write_text(prefix + constants + encoded + BOUNDARIES)
        runtime = os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau")
        result = subprocess.run([runtime, str(path)], capture_output=True, text=True)
        if result.returncode:
            raise SystemExit(result.stderr or result.stdout)
        raw = next(line[len("LAYOUT:"):] for line in result.stdout.splitlines() if line.startswith("LAYOUT:"))
        nodes = list(json.loads(raw).values())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.with_suffix(".json").write_text(json.dumps(nodes, ensure_ascii=False))
    write_html(args.output, nodes, args.width, args.height)
    metadata = {"variant": args.variant, "viewport": [args.width, args.height], "nodeCount": len(nodes),
                "renderer": "actual Luau GUI excerpts with explicit Roblox boundaries; not Studio",
                "sourceSha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (INTRO, TURN, RETURN, HUD, I18N, STUB)},
                "boundaries": ["native Instance and services", "immediate tween completion", "UIGridLayout and UISizeConstraint geometry from real properties", "native avatars labelled placeholders", "public sample state; no private role card"]}
    args.output.with_suffix(".metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2))
    print(args.output)


if __name__ == "__main__":
    main()
