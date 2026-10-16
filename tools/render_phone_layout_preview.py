#!/usr/bin/env python3
"""Export actual PhoneUI -> PhoneSocial -> PhoneConnectUI GUI geometry.

The fixtures are public, synthetic contacts and conversation text. Roblox image
fetching, fonts, physical phone/camera, keyboard and all network actions are
explicit boundaries. Auto text height/grid placement use substitute metrics.
PhoneApps is a legacy module and is not attached by the actual PhoneClient.
"""
from pathlib import Path
import argparse
import html
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('state', choices=('home', 'contact', 'messages', 'call'))
parser.add_argument('--width', type=int, default=1440)
parser.add_argument('--height', type=int, default=900)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
prefix = (ROOT / 'tests/dossier_ui.spec.luau').read_text().split('local Catalog =')[0]
names = ('PhoneState', 'PhoneUI', 'PhoneSocial', 'PhoneConnectUI')
sources = {name: (ROOT / 'src/lobby/ReplicatedStorage/SpyShared' / (name + '.luau')).read_text() for name in names}
encoded = 'local Sources={\n' + '\n'.join(f'{name}=[====[{source}]====],' for name, source in sources.items()) + '\n}\n'
probe = r'''
-- Explicit Roblox GUI/service boundaries shared with the actual phone tests.
guiClasses.ImageLabel=true;guiClasses.TextBox=true
events.MouseButton1Down=true;events.MouseButton1Up=true;events.FocusLost=true;events.ReturnPressedFromOnScreenKeyboard=true
function Methods:FindFirstChild(name,recursive)
 for _,child in ipairs(self:GetChildren())do if child.Name==name then return child end end
 if recursive then for _,child in ipairs(self:GetChildren())do local found=child:FindFirstChild(name,true);if found then return found end end end
end
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
function Methods:ClearAllChildren()for _,child in ipairs(self:GetChildren())do child:Destroy()end end
local oldNew=Instance.new
local oldWrite=NodeMeta.__newindex
NodeMeta.__newindex=function(node,key,value)
 if key=='Visible'or key=='Active'or key=='ClipsDescendants'then assert(type(value)=='boolean',node.ClassName..'.'..key..' requires a boolean')end
 oldWrite(node,key,value)
end
function Instance.new(class)
 local n=oldNew(class);n.ChildAdded=signal();n.ChildRemoved=signal();n.DescendantAdded=signal()
 if class=='ScreenGui'then n.Size=UDim2.fromScale(1,1)end
 return n
end
Vector2.new=function(x,y)return{X=x or 0,Y=y or 0}end
local ColorSequence={new=function(v)return v end};local ColorSequenceKeypoint={new=function(...)return{...}end}
local baseIndex=NodeMeta.__index
local function ordered(parent)
 local rows={};for index,child in ipairs(parent:GetChildren())do if child:IsA('GuiObject')and child.Visible~=false then rows[#rows+1]={node=child,index=index}end end
 table.sort(rows,function(a,b)local x,y=a.node.LayoutOrder or 0,b.node.LayoutOrder or 0;return x==y and a.index<b.index or x<y end)
 return rows
end
local function padding(parent,key)local p=parent:FindFirstChildOfClass('UIPadding');local v=p and p[key];return v and v.Offset or 0 end
local function textHeight(node,width)
 local count=0;local size=node.TextSize or 14
 for line in ((node.Text or '')..'\n'):gmatch('(.-)\n')do count+=math.max(1,math.ceil((utf8.len(line)or #line)*size*.54/math.max(1,width)))end
 return count*size*1.18
end
local axisSize
axisSize=function(node,axis)
 local explicit=node._values.AbsoluteSize;if explicit then return explicit[axis]end
 local parent=node.Parent;local size=node.Size or UDim2.new();local dim=size[axis]
 local grid=parent and parent:FindFirstChildOfClass('UIGridLayout')
 if grid and node:IsA('GuiObject')then dim=grid.CellSize[axis]end
 local extent=dim.Offset+(dim.Scale~=0 and parent and axisSize(parent,axis)*dim.Scale or 0)
 if axis=='Y'and node.AutomaticSize==Enum.AutomaticSize.Y then
   local h=extent
   if node.ClassName=='TextLabel'or node.ClassName=='TextButton'or node.ClassName=='TextBox'then
    h=math.max(h,textHeight(node,axisSize(node,'X')-padding(node,'PaddingLeft')-padding(node,'PaddingRight'))+padding(node,'PaddingTop')+padding(node,'PaddingBottom'))
   else
    local list=node:FindFirstChildOfClass('UIListLayout');local gridLayout=node:FindFirstChildOfClass('UIGridLayout');local children=ordered(node)
    if list then for i,entry in ipairs(children)do h+=axisSize(entry.node,'Y')+(i>1 and(list.Padding and list.Padding.Offset or 0)or 0)end
    elseif gridLayout then local width=axisSize(node,'X');local cell=gridLayout.CellSize;local spacing=gridLayout.CellPadding;local cw=width*cell.X.Scale+cell.X.Offset;local ch=cell.Y.Offset;local gapX=spacing and spacing.X.Offset or 0;local gapY=spacing and spacing.Y.Offset or 0;local columns=math.max(1,math.floor((width+gapX+.01)/(cw+gapX)));h=math.max(h,math.ceil(#children/columns)*(ch+gapY)-gapY)
    else for _,entry in ipairs(children)do local child=entry.node;local p=child.Position or UDim2.new();if p.Y.Scale==0 then h=math.max(h,p.Y.Offset+axisSize(child,'Y'))end end end
    h+=padding(node,'PaddingTop')+padding(node,'PaddingBottom')
   end
   extent=h
 end
 return extent
end
NodeMeta.__index=function(node,key)
 if key=='AbsoluteSize'then return{X=axisSize(node,'X'),Y=axisSize(node,'Y')}end
 local value=baseIndex(node,key)
 if key=='AbsolutePosition'and node.Parent then
  local parent=node.Parent;local list=parent:FindFirstChildOfClass('UIListLayout');local grid=parent:FindFirstChildOfClass('UIGridLayout')
  if list or grid then
   local x,y=padding(parent,'PaddingLeft'),padding(parent,'PaddingTop');local entries=ordered(parent)
   for index,entry in ipairs(entries)do
    if entry.node==node then
     if grid then local cell=grid.CellSize;local spacing=grid.CellPadding;local cw=parent.AbsoluteSize.X*cell.X.Scale+cell.X.Offset;local ch=cell.Y.Offset;local gx=spacing and spacing.X.Offset or 0;local gy=spacing and spacing.Y.Offset or 0;local cols=math.max(1,math.floor((parent.AbsoluteSize.X+gx+.01)/(cw+gx)));x+=(index-1)%cols*(cw+gx);y+=math.floor((index-1)/cols)*(ch+gy)end
     break
    end
    if list then if list.FillDirection==Enum.FillDirection.Horizontal then x+=entry.node.AbsoluteSize.X+(list.Padding and list.Padding.Offset or 0)else y+=entry.node.AbsoluteSize.Y+(list.Padding and list.Padding.Offset or 0)end end
   end
   local pos=parent.AbsolutePosition;value={X=pos.X+x,Y=pos.Y+y}
   if parent.ClassName=='ScrollingFrame'then value={X=value.X-parent.CanvasPosition.X,Y=value.Y-parent.CanvasPosition.Y}end
  end
 end
 return value
end
local player=Instance.new('Player');player.UserId=123;player.DisplayName='James';player.Name='James'
local peer=Instance.new('Player');peer.UserId=456;peer.DisplayName='Vincent';peer.Name='Vincent'
player:SetAttribute('SpyLanguage','ru');peer:SetAttribute('SpyClubLinkVisible',true)
local pg=Instance.new('PlayerGui');pg.AbsoluteSize=Vector2.new(WIDTH,HEIGHT)
services.Players={LocalPlayer=player,GetPlayers=function()return{player,peer}end,GetPlayerByUserId=function(_,id)return id==peer.UserId and peer or id==player.UserId and player end,PlayerAdded=signal(),PlayerRemoving=signal()}
input.TouchEnabled=WIDTH<600;input.GetPropertyChangedSignal=function()return signal()end
guiService.GetGuiInset=function()return Vector2.zero,Vector2.zero end
local workspace={GetServerTimeNow=function()return 1000 end}
-- Deterministic clock values are public illustration fixtures, not session data.
local fixtureOS={clock=os.clock,time=os.time,date=function(format)if format=='%H:%M'then return'20:45'elseif format=='%d.%m.%Y'then return'16.10.2026'else return os.date(format)end end}
local function load(name)
 local env=setmetatable({game=game,workspace=workspace,Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,ColorSequence=ColorSequence,ColorSequenceKeypoint=ColorSequenceKeypoint,task=task,TweenInfo=TweenInfo,os=fixtureOS},{__index=getfenv(0)})
 local chunk=assert(loadstring(Sources[name],name));setfenv(chunk,env);return chunk()
end
local State,UI,Social,Connect=load('PhoneState'),load('PhoneUI'),load('PhoneSocial'),load('PhoneConnectUI')
-- No requests are emitted; only this explicit directory response is local.
local function request(payload,callback)
 if payload.action=='link'and callback then callback({visible=true,network=true,members={}})end
 return false
end
local ui
ui=UI.new(pg,State,{}, {inMatch=false,language=function()return'ru'end,blocked=function()return false end,toggle=function()end,close=function()ui:hide()end,feedback=function()end,launch=function()end,caseRequest=function()end,profile=function()return{}end})
Social.attach(ui,{request=request,openCall=function()ui:show('calls')end,sound=function()end,openChat=function()end,noteLoad=function()end})
Connect.attach(ui,State,{request=request})
local contact={userId=456,number=State.number(456),displayName='Vincent',sameServer=true,joinable=true}
ui:addContact(contact)
if STATE=='home'then ui:show('home')
elseif STATE=='contact'then ui:show('contacts');ui:showContact(contact)
elseif STATE=='messages'then
 ui:show('messages');ui.peer=456;ui.conversations[456]={{id='public-fixture-1',from=456,peer=456,text='Встретимся у бильярда?'},{id='public-fixture-2',from=123,peer=456,text='Иду. Оставь мне место.'}};ui:render()
elseif STATE=='call'then ui:setCall({phase='ringing',incoming=true,peer=456,id='public-fixture-call',revision=1});ui:show('calls')end
ui:resize()
local function q(v)return'"'..tostring(v):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'end
local function json(v)
 if type(v)=='string'then return q(v)elseif type(v)=='number'or type(v)=='boolean'then return tostring(v)
 elseif type(v)=='table'then local r={};for k,x in pairs(v)do r[#r+1]=q(k)..':'..json(x)end;return'{'..table.concat(r,',')..'}'else return'null'end
end
local nodes={}
for _,node in ipairs(ui.gui:GetDescendants())do if node:IsA('GuiObject')then
 local visible=true;local ancestor=node;local alpha=1;local clip={x=0,y=0,right=WIDTH,bottom=HEIGHT}
 while ancestor and ancestor~=ui.gui do
  if ancestor.Visible==false then visible=false;break end
  if ancestor.ClassName=='CanvasGroup'then alpha*=1-(ancestor.GroupTransparency or 0)end
  if ancestor~=node and(ancestor.ClipsDescendants or ancestor.ClassName=='ScrollingFrame')then local a,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize;clip.x=math.max(clip.x,a.X);clip.y=math.max(clip.y,a.Y);clip.right=math.min(clip.right,a.X+s.X);clip.bottom=math.min(clip.bottom,a.Y+s.Y)end
  ancestor=ancestor.Parent
 end
 if visible then
  local a,s=node.AbsolutePosition,node.AbsoluteSize;local radius=0;local strokeColor,strokeAlpha,strokeWidth=nil,0,0
  for _,child in ipairs(node:GetChildren())do
   if child.ClassName=='UICorner'then radius=math.min(math.min(s.X,s.Y)*.5,child.CornerRadius.Offset+child.CornerRadius.Scale*math.min(s.X,s.Y))
   elseif child.ClassName=='UIStroke'and child.Enabled~=false then strokeColor=child.Color;strokeAlpha=1-(child.Transparency or 0);strokeWidth=child.Thickness or 1 end
  end
  local text=node.Text or'';local placeholder=text==''and node.ClassName=='TextBox';if placeholder then text=node.PlaceholderText or''end
  nodes[#nodes+1]={name=node.Name or'',class=node.ClassName,x=a.X,y=a.Y,w=s.X,h=s.Y,z=node.ZIndex,rotation=node.Rotation or 0,active=node.Active~=false,interactable=node.Interactable~=false,
   text=text,font=node.Font or'',fontSize=node.TextSize or 14,align=tostring(node.TextXAlignment or Enum.TextXAlignment.Center),valign=tostring(node.TextYAlignment or''),wrap=node.TextWrapped==true,truncate=tostring(node.TextTruncate or''),color=placeholder and node.PlaceholderColor3 or node.TextColor3,bg=node.BackgroundColor3,
   textAlpha=alpha*(1-(node.TextTransparency or 0)),bgAlpha=alpha*(1-(node.BackgroundTransparency or 0)),radius=radius,clip=clip,strokeColor=strokeColor,strokeAlpha=alpha*strokeAlpha,strokeWidth=strokeWidth,image=node.Image,
   textInsets={left=padding(node,'PaddingLeft'),right=padding(node,'PaddingRight'),top=padding(node,'PaddingTop'),bottom=padding(node,'PaddingBottom')}}
 end
end end
print('LAYOUT:'..json(nodes))
'''
settings = f'local WIDTH,HEIGHT,STATE={args.width},{args.height},{json.dumps(args.state)}\n'
with tempfile.TemporaryDirectory(prefix='spy-phone-layout-') as directory:
    target = Path(directory) / 'phone.luau'
    target.write_text(prefix + encoded + settings + probe)
    result = subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], capture_output=True, text=True, cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.stderr or result.stdout)
    raw = next(line[7:] for line in result.stdout.splitlines() if line.startswith('LAYOUT:'))
    nodes = list(json.loads(raw).values())
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.with_suffix('.json').write_text(json.dumps(nodes, ensure_ascii=False))
# HTML is only a convenient structural fallback; the atlas consumes JSON.
blocks = ''.join(f'<li>{html.escape(node["name"])}: {html.escape(node["text"])}</li>' for node in nodes if node['text'])
args.output.write_text('<!doctype html><meta charset="utf-8"><title>Actual phone component export</title><p>Geometry is in the adjacent JSON. Avatar images, fonts, input and network require Roblox Studio.</p><ul>' + blocks + '</ul>')
print(args.output)
