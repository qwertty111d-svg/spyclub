#!/usr/bin/env python3
"""Render actual GUI geometry through documented boundary stubs, not Roblox Studio.

Viewport avatars are labelled placeholders. Useful for spacing/clipping review.
"""
from pathlib import Path
import argparse,html,json,subprocess,tempfile

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('panel',choices=('dossier','store','premium','daily','dialogue','settings','journal','play','lobbyhud'))
parser.add_argument('--width',type=int,default=1280)
parser.add_argument('--height',type=int,default=900)
parser.add_argument('--tab',choices=('personal','appearance'),default='personal')
parser.add_argument('--target',choices=('nationality','firstName','lastName'),default='nationality')
parser.add_argument('--section',default='start')
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
names=('Catalog','ClubStoreConfig','AccessoryRollConfig','CharacterIdentity','RollOdds','PremiumShopRules','AccessoryRollUI','ClubStoreUI','RollShopConfig','PremiumRollShopUI','DailyRewardConfig','DailyUI','ModalUI','IconUI','LayoutUI','DialogueUI','SettingsUI','ClubJournalUI','I18n','UITheme','CaseFiles','HudController')
source_files={n:(ROOT/'src/lobby/ReplicatedStorage/SpyShared'/(n+'.luau')).read_text() for n in names}
if args.panel=='play':
    quick=(ROOT/'src/lobby/StarterPlayer/StarterPlayerScripts/QuickPlayClient.client.luau').read_text()
    source_files['QuickPlay']=quick.split('-- QUICK_PLAY_CANVAS_BEGIN',1)[1].split('-- QUICK_PLAY_CANVAS_END',1)[0]+'''\nrefresh();resize();return {gui=gui,window=window,setState=function(value,selectedMode)data=value;mode=selectedMode or mode;refresh();resize()end}\n'''
sources='local Sources={\n'+'\n'.join(f'{n}=[====[{source}]====],' for n,source in source_files.items())+'\n}\n'
probe=r'''
for name in pairs(Sources)do modules[name]=nil end
function Methods:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
events.InputBegan=true;events.InputEnded=true
Color3.new=function(r,g,b)return Color3.fromRGB((r or 0)*255,(g or 0)*255,(b or 0)*255)end
Vector2.new=function(x,y)return{X=x or 0,Y=y or 0}end
events.MouseButton1Down=true;events.MouseButton1Up=true
task.wait=function()end
function Methods:WaitForChild(name)return self:FindFirstChild(name)end
function Methods:GetAttributeChangedSignal(name)return self:GetPropertyChangedSignal('attribute_'..name)end
local oldIsA=Methods.IsA
function Methods:IsA(class)return class=='GuiButton'and self.ClassName=='TextButton'or oldIsA(self,class)end
local baseIndex=NodeMeta.__index
-- Auto text height uses substitute metrics. Native font wrapping stays a Studio check.
local function autoTextHeight(node,width)
 local count=0
 for line in ((node.Text or '')..'\n'):gmatch('(.-)\n')do
  local length=utf8.len(line)or #line
  count+=math.max(1,math.ceil(length*(node.TextSize or 14)*.54/math.max(1,width)))
 end
 return count*(node.TextSize or 14)*1.18
end
NodeMeta.__index=function(node,key)
 local value=baseIndex(node,key)
 if key=='AbsoluteSize'and node.ClassName=='TextLabel'and node.AutomaticSize==Enum.AutomaticSize.Y then
  return{X=value.X,Y=math.max(value.Y,autoTextHeight(node,value.X))}
 end
 if key=='AbsolutePosition'and node.Parent then
  local parent=node.Parent
  local layout=parent:FindFirstChildOfClass('UIListLayout')
  if layout then
   local siblings={};local padding=parent:FindFirstChildOfClass('UIPadding')
   local y=padding and padding.PaddingTop and padding.PaddingTop.Offset or 0
   local x=padding and padding.PaddingLeft and padding.PaddingLeft.Offset or 0
   for i,c in ipairs(parent:GetChildren())do if c:IsA('GuiObject')and c.Visible~=false then siblings[#siblings+1]={node=c,index=i}end end
   table.sort(siblings,function(a,b)local x,y=a.node.LayoutOrder or 0,b.node.LayoutOrder or 0;return x==y and a.index<b.index or x<y end)
   for _,entry in ipairs(siblings)do
    if entry.node==node then break end
    y+=entry.node.AbsoluteSize.Y+(layout.Padding and layout.Padding.Offset or 0)
   end
   local pos=parent.AbsolutePosition;value={X=pos.X+x,Y=pos.Y+y}
  end
  if parent.ClassName=='ScrollingFrame'then local offset=parent.CanvasPosition;value={X=value.X-offset.X,Y=value.Y-offset.Y}end
 end
 if value==nil then return node:FindFirstChild(key)end
 return value
end
local tweenCreate=tweens.Create
tweens.Create=function(self,node,info,props)local t=tweenCreate(self,node,info,props);t.Completed={Once=function(_,fn)fn()end};return t end
local profileEvent=signal()
script.Parent=setmetatable({WaitForChild=function(_,name)return name=='Profile'and{OnClientEvent=profileEvent}or name end,
 FindFirstChild=function(_,name)return Sources[name]and name or nil end},{__index=function(_,key)return key end})
local world=Instance.new('Workspace');world.CurrentCamera=Instance.new('Camera');world.CurrentCamera.ViewportSize=Vector2.new(WIDTH,HEIGHT)
local workspace=world
services.RunService={Heartbeat=signal()}
local preferences={language='ru',musicVolume=.6,sfxVolume=.8,motionBlur=true,cameraMotion=true,reducedMotion=false,fov=75,effects=true}
modules.ClientPreferences={start=function()end,get=function()return table.clone(preferences)end,status=function()return'saved',true end,Changed=signal(),set=function()return false end}
-- Native services are intentionally boundaries in this geometry-only preview.
modules.UIEffects={pushBlur=function()end,popBlur=function()end}
services.MarketplaceService={PromptProductPurchaseFinished=signal(),GetProductInfoAsync=function(_,id)
 local prices={[3718610025]=99,[3718610195]=279,[3718610306]=449};return{PriceInRobux=prices[id],IsForSale=true}end}
local function load(name)
 if modules[name]then return modules[name]end
 local chunk=assert(loadstring(Sources[name],name))
 setfenv(chunk,setmetatable({script=script,game=game,require=load,Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,
  Vector2=Vector2,Color3=Color3,task=task,TweenInfo=TweenInfo,workspace=workspace},{__index=getfenv(0)}))
 modules[name]=chunk();return modules[name]
end
modules.Preview3D.mountCollection=function(parent)
 local v=Instance.new('ViewportFrame');v.Name='ViewportPlaceholder';v.Size=UDim2.fromScale(1,1);v.BackgroundTransparency=1;v.ZIndex=parent.ZIndex+1;v.Parent=parent;return v
end
modules.Preview3D.mount=modules.Preview3D.mountCollection
modules.Preview3D.mountNPC=function(parent)
 -- Composition fixture only: browser draws a labelled schematic, never a native NPC render.
 local v=modules.Preview3D.mountCollection(parent);v.Name='VincentPortrait';v:SetAttribute('PortraitReady',true);return v
end
local catalog=load('Catalog');local config=load('AccessoryRollConfig');local identity=load('CharacterIdentity')
local p={ready=true,revision=1,coins=1400,rolls=12,owned={hair_charmer=true,copper=true},equipped={hair='hair_charmer',outfit='club_vest'},
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
p.rollShop={ready=true,policyReady=true,offers={
 {id=3718610025,rolls=1,available=true,configured=true},{id=3718610195,rolls=3,available=true,configured=true},{id=3718610306,rolls=5,available=true,configured=true}}}
p.daily={available=true,streak=2,nextStreak=3,nextAt=os.time()+86400,rewards=load('DailyRewardConfig').Rewards}
p.club={vincent={accepted=false,completed=false,claimed=false,reward=100,rumorRu='За столом говорят о новом госте. Присмотрись к нему в следующей партии.',rumorEn='There is a new guest at the table.'},achievements={
 {id='first',nameRu='Первый вечер',nameEn='First evening',detailRu='Заверши первый матч.',detailEn='Finish your first match.',target=1,value=1,reward=100,unlocked=true},
 {id='regular',nameRu='Постоянный гость',nameEn='Regular guest',detailRu='Сыграй десять матчей.',detailEn='Play ten matches.',target=10,value=4,reward=350,unlocked=false}}}
local gui=Instance.new('ScreenGui');gui.AbsoluteSize=Vector2.new(WIDTH,HEIGHT)
local player=Instance.new('Player');player.DisplayName='James Bennett';player.PlayerGui=Instance.new('PlayerGui');player.PlayerGui.AbsoluteSize=Vector2.new(WIDTH,HEIGHT)
player.CharacterAdded=signal();player.CharacterAppearanceLoaded=signal()
player:SetAttribute('SpyLanguage','ru');services.Players={LocalPlayer=player}
input.GetPropertyChangedSignal=function()return signal()end
local activePanel
local ctx={gui=gui,player=player,profile=function()return p end,state=function()return{}end,language=function()return'ru'end,
 pending=function()return false end,request=function()return false end,openPanel=function()end,closePanels=function()end,
 setActivePanel=function(value)activePanel=value end,getActivePanel=function()return activePanel end}
local function make(class,parent,properties)
 local n=Instance.new(class);for k,v in pairs(properties or{})do n[k]=v end
 if n:IsA('GuiObject')and parent and parent:IsA('GuiObject')and not(properties and properties.ZIndex)then n.ZIndex=parent.ZIndex+1 end
 n.Parent=parent;return n
end
ctx.make=make;local i18n=load('I18n');ctx.L=function(k)return i18n.t('ru',k)end
ctx.panel=function(parent,size,pos)return make('Frame',parent,{Size=size,Position=pos})end
ctx.label=function(parent,value,size,pos,font,color)return make('TextLabel',parent,{Text=value,Size=size,Position=pos,TextSize=font,TextColor3=color,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1})end
ctx.button=function(parent,value,size,pos,color)return make('TextButton',parent,{Text=value,Size=size,Position=pos,BackgroundColor3=color,TextSize=16,TextColor3=Color3.fromRGB(245,245,247),Font=Enum.Font.BuilderSansBold})end
if PANEL=='play'then
 local env=setmetatable({parent=player.PlayerGui,player=player,Files=load('CaseFiles'),Theme=load('UITheme'),RS=services.ReplicatedStorage,
  game=game,workspace=workspace,Instance=Instance,Enum=Enum,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Color3=Color3,task=task},{__index=getfenv(0)})
 local chunk=assert(loadstring(Sources.QuickPlay,'QuickPlay-canvas'));setfenv(chunk,env);local view=chunk()
 view.setState(SECTION=='searching'and{state='searching',count=2,canCancel=true}or{state='idle'},SECTION=='case'and'case'or'classic')
 gui=view.gui;gui.AbsoluteSize=Vector2.new(WIDTH,HEIGHT);gui.Size=UDim2.fromScale(1,1);view.window.Visible=true
elseif PANEL=='lobbyhud'then
 gui.Name='HudGui';gui.Parent=player.PlayerGui;gui.Size=UDim2.fromScale(1,1)
 make('TextButton',gui,{Name='MainAction',Text='Играть',TextSize=16})
 local dock=make('Frame',gui,{Name='BottomDesk'})
 for _,name in ipairs({'Inventory','Shop','Daily','Profile','Trade','Settings'})do make('TextButton',dock,{Name=name,TextSize=14})end
 local view=load('HudController').new(gui,ctx.L);view:update(false)
 if SECTION=='menu'then view.MenuExpanded=true;view:resize()end
else
 local ui=load(({dossier='AccessoryRollUI',store='ClubStoreUI',premium='PremiumRollShopUI',daily='DailyUI',dialogue='DialogueUI',settings='SettingsUI',journal='ClubJournalUI'})[PANEL]).create(ctx)
 if PANEL=='settings'then ui.category=SECTION=='start'and'language'or SECTION end
 ui:open(PANEL=='dossier'and(TAB=='appearance'and'hair'or TARGET)or PANEL=='dialogue'and(SECTION=='sell'and'start'or SECTION)or nil)
 if PANEL=='dialogue'and SECTION=='sell'then ui:openSell()end
end
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
   local radius=0;local strokeColor,strokeAlpha,strokeWidth=nil,0,0
   for _,child in ipairs(node:GetChildren())do if child.ClassName=='UICorner'then radius=math.min(math.min(s.X,s.Y)*.5,child.CornerRadius.Offset+child.CornerRadius.Scale*math.min(s.X,s.Y)) elseif child.ClassName=='UIStroke'and child.Enabled~=false then strokeColor=child.Color;strokeAlpha=1-(child.Transparency or 0);strokeWidth=child.Thickness or 1 end end
   nodes[#nodes+1]={name=node.Name or'',class=node.ClassName,x=a.X,y=a.Y,w=s.X,h=s.Y,z=node.ZIndex,
    active=node.Active~=false,interactable=node.Interactable~=false,
    text=node.Text or'',font=node.Font or'',fontSize=node.TextSize or 14,align=tostring(node.TextXAlignment or Enum.TextXAlignment.Center),
    valign=tostring(node.TextYAlignment or''),wrap=node.TextWrapped==true,truncate=tostring(node.TextTruncate or''),color=node.TextColor3,bg=node.BackgroundColor3,
    textAlpha=1-(node.TextTransparency or 0),bgAlpha=1-(node.BackgroundTransparency or 0),radius=radius,clip=clip,strokeColor=strokeColor,strokeAlpha=strokeAlpha,strokeWidth=strokeWidth}
  end
 end
end
print('LAYOUT:'..json(nodes))
'''
probe=f'local WIDTH,HEIGHT,PANEL,TAB,TARGET,SECTION={args.width},{args.height},{json.dumps(args.panel)},{json.dumps(args.tab)},{json.dumps(args.target)},{json.dumps(args.section)}\n'+probe
with tempfile.TemporaryDirectory(prefix='spy-layout-') as d:
    code=Path(d)/'layout.luau';code.write_text(prefix+sources+probe)
    result=subprocess.run(['/workspace/.spy-tools/bin/luau',str(code)],capture_output=True,text=True)
    if result.returncode:
        raise SystemExit(result.stderr or result.stdout)
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
