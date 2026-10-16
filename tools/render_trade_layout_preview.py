#!/usr/bin/env python3
"""Export actual TradeUI.client GUI geometry with explicit local fixtures.

The client source is cut at its inert fixture marker before network boot. Item
names and tradeability come from the real Catalog. Participants and offers are
synthetic illustrations; no trade requests are emitted. Roblox asset thumbnails,
fonts, physical rendering, native input and services require Roblox Studio.
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
parser.add_argument('state', choices=('directory', 'incoming', 'outgoing', 'offering', 'inventory', 'inventory-keyboard', 'review', 'gift-review', 'saving', 'complete'))
parser.add_argument('--width', type=int, default=1440)
parser.add_argument('--height', type=int, default=900)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
prefix = (ROOT / 'tests/dossier_ui.spec.luau').read_text().split('local Catalog =')[0]
source = (ROOT / 'src/lobby/StarterPlayer/StarterPlayerScripts/TradeUI.client.luau').read_text()
marker = '-- TRADE_UI_FIXTURE_INSERT'
if source.count(marker) != 1:
    raise SystemExit('TradeUI must have exactly one inert fixture marker before network boot')
source = source.split(marker)[0]
names = ('ClubStoreConfig', 'Catalog', 'Art')
sources = {name: (ROOT / 'src/lobby/ReplicatedStorage/SpyShared' / (name + '.luau')).read_text() for name in names}
encoded = 'local Sources={\n' + '\n'.join(f'{name}=[====[{value}]====],' for name, value in sources.items()) + '\n}\n'
probe = r'''

-- Explicit Roblox GUI/service boundaries shared with the phone geometry exporter.
guiClasses.ImageLabel=true;guiClasses.TextBox=true
events.Event=true;events.MouseButton1Down=true;events.MouseButton1Up=true;events.FocusLost=true;events.ReturnPressedFromOnScreenKeyboard=true
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
 if value==nil then for _,child in ipairs(node:GetChildren())do if child.Name==key then return child end end end
 return value
end

local rgb=Color3.fromRGB
Color3.fromRGB=function(r,g,b)return setmetatable(rgb(r,g,b),{__index={Lerp=function(self,other,t)return Color3.fromRGB(self[1]+(other[1]-self[1])*t,self[2]+(other[2]-self[2])*t,self[3]+(other[3]-self[3])*t)end}})end
Color3.new=function(r,g,b)return Color3.fromRGB(r*255,g*255,b*255)end
local pg=Instance.new('PlayerGui');pg.AbsoluteSize=Vector2.new(WIDTH,HEIGHT)
local playerFixture=Instance.new('Player');playerFixture.UserId=123;playerFixture.DisplayName='James';playerFixture.Name='James';pg.Parent=playerFixture
playerFixture:SetAttribute('SpyLanguage','ru');playerFixture:SetAttribute('SpyTradeDockReady',true)
services.Players={LocalPlayer=playerFixture}
services.ReplicatedStorage=Instance.new('ReplicatedStorage')
services.Workspace=Instance.new('Workspace')
services.Workspace.CurrentCamera=Instance.new('Camera');services.Workspace.CurrentCamera.ViewportSize=Vector2.new(WIDTH,HEIGHT)
services.RunService={Heartbeat=signal()}
function input:GetPropertyChangedSignal(name)return signal()end
function Methods:ReleaseFocus()end
guiService.GetGuiInset=function()return Vector2.new(0,36),Vector2.zero end
local loaded={}
local function loadModule(name)
 if loaded[name]then return loaded[name]end
 local env=setmetatable({game=game,Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,ColorSequence=ColorSequence,ColorSequenceKeypoint=ColorSequenceKeypoint,task=task,TweenInfo=TweenInfo,require=loadModule},{__index=getfenv(0)})
 local chunk=assert(loadstring(Sources[name],name));setfenv(chunk,env);local result=chunk();loaded[name]=result;return result
end
local realCatalog=loadModule('Catalog')

'''
fixture = r'''

-- Synthetic public illustration fixtures. No request or confirmation is fired.
Catalog=realCatalog;Art=loadModule('Art')
snapshot={policy='ready',invitesEnabled=true,profile={ready=true,owned={},itemCounts={}},players={
 {id=456,name='Vincent',displayName='Vincent',available=true},
 {id=789,name='Mira',displayName='Mira',available=true},
 {id=987,name='Leon',displayName='Leon',available=true,busy=true},
}}
for _,id in ipairs({'noir_beret','hair_slick_brown','pearl_necklace','club_shades','copper','moon','gold','classic'})do
 assert(Catalog.ById[id], 'Fixture item must exist in the public Catalog: '..id)
 snapshot.profile.owned[id]=true;snapshot.profile.itemCounts[id]=id=='copper'and 2 or 1
end
actionRemote={FireServer=function()error('Layout export must never emit a network request')end}
if STATE~='directory'then
 current={id='public-fixture-trade',revision=3,stage=(STATE=='inventory'or STATE=='inventory-keyboard')and 'offering'or (STATE=='incoming'or STATE=='outgoing')and 'invited'or STATE=='gift-review'and 'review'or STATE,
 partner={id=456,name='Vincent',displayName='Vincent'},selfOffer={'noir_beret','copper'},otherOffer={'hair_slick_brown','moon'},
 selfReady=false,otherReady=true,selfConfirmed=false,otherConfirmed=false,confirmAt=now()-1}
 if STATE=='incoming'or STATE=='outgoing'then current.inviterId=STATE=='incoming'and 456 or 123;current.expiresAt=now()+20 end
 if STATE=='gift-review'then current.selfOffer={'noir_beret'};current.otherOffer={}end
 if STATE=='saving'or STATE=='complete'then current.selfReady=true;current.otherReady=true;current.selfConfirmed=true;current.otherConfirmed=true end
 if STATE=='saving'then savingSince=os.clock()end
end
drawerOpen=STATE=='inventory'or STATE=='inventory-keyboard'
if STATE=='inventory-keyboard'then
 input.OnScreenKeyboardVisible=true;input.OnScreenKeyboardPosition=Vector2.new(0,math.floor(HEIGHT*.56));input.OnScreenKeyboardSize=Vector2.new(WIDTH,HEIGHT-math.floor(HEIGHT*.56))
end
setOpen(true);render()

'''
exporter = r'''
local function q(v)return'"'..tostring(v):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'end
local function json(v)
 if type(v)=='string'then return q(v)elseif type(v)=='number'or type(v)=='boolean'then return tostring(v)
 elseif type(v)=='table'then local r={};for k,x in pairs(v)do r[#r+1]=q(k)..':'..json(x)end;return'{'..table.concat(r,',')..'}'else return'null'end
end
local nodes={}
for _,node in ipairs(gui:GetDescendants())do if node:IsA('GuiObject')then
 local visible=true;local ancestor=node;local alpha=1;local clip={x=0,y=0,right=WIDTH,bottom=HEIGHT}
 while ancestor and ancestor~=gui do
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
with tempfile.TemporaryDirectory(prefix='spy-trade-layout-') as directory:
    target = Path(directory) / 'trade.luau'
    target.write_text(prefix + encoded + settings + probe + source + fixture + exporter)
    result = subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], capture_output=True, text=True, cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.stderr or result.stdout)
    raw = next(line[7:] for line in result.stdout.splitlines() if line.startswith('LAYOUT:'))
    nodes = list(json.loads(raw).values())
if any('RecentExchange' in node['name'] or 'ExchangeSample' in node['name'] for node in nodes):
    raise SystemExit('Recent exchange examples must not appear in the actual trade UI')
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.with_suffix('.json').write_text(json.dumps(nodes, ensure_ascii=False))
blocks = ''.join(f'<li>{html.escape(node["name"])}: {html.escape(node["text"])}</li>' for node in nodes if node['text'])
args.output.write_text('<!doctype html><meta charset="utf-8"><title>Actual trade component export</title><p>Actual GUI geometry with synthetic public participant and offer fixtures. No real trades or network actions. Roblox thumbnails, fonts and input require Roblox Studio.</p><ul>' + blocks + '</ul>')
print(args.output)
