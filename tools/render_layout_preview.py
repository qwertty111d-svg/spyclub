#!/usr/bin/env python3
"""Render actual GUI geometry through documented boundary stubs, not Roblox Studio.

Viewport avatars are labelled placeholders. Useful for spacing/clipping review.
"""
from pathlib import Path
import argparse,html,json,subprocess,tempfile

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('panel',choices=('dossier','store'))
parser.add_argument('--width',type=int,default=1280)
parser.add_argument('--height',type=int,default=900)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
names=('Catalog','ClubStoreConfig','AccessoryRollConfig','CharacterIdentity','RollOdds','PremiumShopRules','AccessoryRollUI','ClubStoreUI')
sources='local Sources={\n'+'\n'.join(f'{n}=[====[{(ROOT/"src/lobby/ReplicatedStorage/SpyShared"/(n+".luau")).read_text()}]====],' for n in names)+'\n}\n'
probe=r'''
for name in pairs(Sources)do modules[name]=nil end
local function load(name)
 if modules[name]then return modules[name]end
 local chunk=assert(loadstring(Sources[name],name))
 setfenv(chunk,setmetatable({script=script,game=game,require=load,Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,
  Vector2=Vector2,Color3=Color3,task=task,TweenInfo=TweenInfo},{__index=getfenv(0)}))
 modules[name]=chunk();return modules[name]
end
modules.Preview3D.mountCollection=function(parent)
 local v=Instance.new('ViewportFrame');v.Name='ViewportPlaceholder';v.Size=UDim2.fromScale(1,1);v.BackgroundTransparency=1;v.ZIndex=parent.ZIndex+1;v.Parent=parent;return v
end
local catalog=load('Catalog');local config=load('AccessoryRollConfig');local identity=load('CharacterIdentity')
local p={ready=true,revision=1,coins=1400,rolls=12,owned={hair_charmer=true},equipped={hair='hair_charmer',outfit='club_vest'},
 identity={nationality='british',firstName='James',lastName='Bennett'},accessoryRoll={sequence=3,categories={}}}
for _,category in ipairs(config.Categories)do
 local items={}
 if category.identity then
  for _,entry in ipairs(identity.pool(category.id,p.identity))do
   items[#items+1]={id=entry.item.id,label=entry.item.label,labelRu=entry.item.labelRu,labelEn=entry.item.labelEn,chance=entry.chance}
  end
 end
 p.accessoryRoll.categories[#p.accessoryRoll.categories+1]={id=category.id,slot=category.slot,identity=category.identity,
  labelRu=category.ru,labelEn=category.en,available=true,canSpend=true,items=items,chances=config.Weights}
end
local gui=Instance.new('ScreenGui');gui.AbsoluteSize=Vector2.new(WIDTH,HEIGHT)
local player=Instance.new('Player');player.DisplayName='James Bennett';player.PlayerGui=Instance.new('PlayerGui')
player.CharacterAdded=signal();player.CharacterAppearanceLoaded=signal()
local ctx={gui=gui,player=player,profile=function()return p end,state=function()return{}end,language=function()return'ru'end,
 pending=function()return false end,request=function()return false end,openPanel=function()end,closePanels=function()end,
 setActivePanel=function()end,getActivePanel=function()return PANEL=='dossier'and'accessoryRoll'or'clubStore'end}
local ui=load(PANEL=='dossier'and'AccessoryRollUI'or'ClubStoreUI').create(ctx);ui:open()
local function q(v)return'"'..tostring(v):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'end
local function json(v)
 if type(v)=='string'then return q(v)elseif type(v)=='number'or type(v)=='boolean'then return tostring(v)
 elseif type(v)=='table'then
  local r={};for k,x in pairs(v)do r[#r+1]=q(k)..':'..json(x)end;return'{'..table.concat(r,',')..'}'
 else return'null'end
end
local nodes={}
for _,node in ipairs(gui:GetDescendants())do
 if node:IsA('GuiObject')then
  local visible=true;local ancestor=node
  local clip={x=0,y=0,right=WIDTH,bottom=HEIGHT}
  while ancestor and ancestor~=gui do
   if ancestor.Visible==false then visible=false;break end
   if ancestor~=node and(ancestor.ClipsDescendants or ancestor.ClassName=='ScrollingFrame')then
    local a,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize
    clip.x=math.max(clip.x,a.X);clip.y=math.max(clip.y,a.Y);clip.right=math.min(clip.right,a.X+s.X);clip.bottom=math.min(clip.bottom,a.Y+s.Y)
   end
   ancestor=ancestor.Parent
  end
  if visible then
   local a,s=node.AbsolutePosition,node.AbsoluteSize
   local radius=0
   for _,child in ipairs(node:GetChildren())do if child.ClassName=='UICorner'then radius=child.CornerRadius.Offset end end
   nodes[#nodes+1]={name=node.Name or'',class=node.ClassName,x=a.X,y=a.Y,w=s.X,h=s.Y,z=node.ZIndex,
    text=node.Text or'',font=node.Font or'',fontSize=node.TextSize or 14,align=tostring(node.TextXAlignment or''),
    valign=tostring(node.TextYAlignment or''),wrap=node.TextWrapped==true,color=node.TextColor3,bg=node.BackgroundColor3,
    textAlpha=1-(node.TextTransparency or 0),bgAlpha=1-(node.BackgroundTransparency or 0),radius=radius,clip=clip}
  end
 end
end
print('LAYOUT:'..json(nodes))
'''
probe=f'local WIDTH,HEIGHT,PANEL={args.width},{args.height},{json.dumps(args.panel)}\n'+probe
with tempfile.TemporaryDirectory(prefix='spy-layout-') as d:
    code=Path(d)/'layout.luau';code.write_text(prefix+sources+probe)
    result=subprocess.run(['/workspace/.spy-tools/bin/luau',str(code)],capture_output=True,text=True,check=True)
    raw=next(l[7:] for l in result.stdout.splitlines() if l.startswith('LAYOUT:'))
    nodes=list(json.loads(raw).values())
def color(v,alpha=1):
    if not v:return 'transparent'
    return f'rgba({v["1"]},{v["2"]},{v["3"]},{alpha})'
blocks=[]
for n in sorted(enumerate(nodes),key=lambda pair:(pair[1]['z'],pair[0])):
    n=n[1];w,h=max(0,n['w']),max(0,n['h']);clip=n['clip']
    if not w or not h:continue
    align='right'if'Right'in n['align']else'center'if'Center'in n['align']else'left'
    top=max(0,clip['y']-n['y']);right=max(0,n['x']+w-clip['right']);bottom=max(0,n['y']+h-clip['bottom']);left=max(0,clip['x']-n['x'])
    family='Georgia,serif'if'Garamond'in n['font']else'Arial,sans-serif'
    style=f'left:{n["x"]}px;top:{n["y"]}px;width:{w}px;height:{h}px;background:{color(n.get("bg"),n["bgAlpha"])};color:{color(n.get("color"),n["textAlpha"])};font:{n["fontSize"]}px {family};border-radius:{n["radius"]}px;text-align:{align};clip-path:inset({top}px {right}px {bottom}px {left}px);'
    text=html.escape(n['text'])
    if n['class']=='ViewportFrame':text='<span style="font:11px Arial;color:#ba9a7f">3D preview · Roblox Studio</span>'
    valign='flex-start'if'Top'in n['valign']else'center'
    wrap='normal'if n['wrap']else'nowrap'
    blocks.append(f'<div class="node" title="{html.escape(n["name"])}" style="{style}align-items:{valign}"><span style="width:100%;white-space:{wrap};overflow:hidden;text-overflow:ellipsis">{text}</span></div>')
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(f'<!doctype html><meta charset="utf-8"><style>body{{margin:0;background:#19171b;width:{args.width}px;height:{args.height}px;overflow:hidden}}.node{{position:absolute;display:flex;box-sizing:border-box;overflow:hidden}}</style>'+''.join(blocks))
args.output.with_suffix('.json').write_text(json.dumps(nodes,ensure_ascii=False))
print(args.output)
