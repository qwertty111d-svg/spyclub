from pathlib import Path
import subprocess
import tempfile
import os
root=Path(__file__).resolve().parents[1]
client=(root/'src/lobby/StarterPlayer/StarterPlayerScripts/SpyClient.client.luau').read_text()
callpanel=client[client.index('local function callPanelMethod'):client.index('local pendingId=')]
setactive=client[client.index('local function setDockActive'):client.index('player:SetAttribute("SpyCharacterMenuOpen",false)')]
bridge=client[client.index('local function panelName'):client.index('-- Phone applications')]
creator=client[client.index('local function createOptional'):client.index('createOptional("accessoryRoll",AccessoryRollUI)')]
roll=client[client.index('local function setRollDisplay'):client.index('setRollDisplay(nil)')]
render=client[client.index('render = function(newState)'):client.index('local sending = false')]
daily=(root/'src/lobby/ReplicatedStorage/SpyShared/DailyUI.luau').read_text()
helpers=daily[daily.index('\tlocal function rewardExtra'):daily.index('\tlocal function mountPreview')]
serverdaily=(root/'src/lobby/ServerStorage/SpyModules/Daily.luau').read_text()
config=(root/'src/lobby/ReplicatedStorage/SpyShared/AccessoryRollConfig.luau').read_text()
cleanup=(root/'src/lobby/ServerScriptService/LegacyShowcaseCleanup.server.luau').read_text()
source=r'''
local checks=0
local function eq(a,b,label)checks+=1;assert(a==b,(label or "")..": expected "..tostring(b)..", got "..tostring(a))end
local function signal()
 local s={callbacks={}}
 function s:Connect(fn)table.insert(self.callbacks,fn);return {Disconnect=function()end}end
 function s:Fire(...)for _,fn in ipairs(self.callbacks)do fn(...)end end
 return s
end
local createdEvents=0
local function event()
 local e={Event=signal()}
 function e:IsA(k)return k=="BindableEvent"end
 function e:Fire(...)self.Event:Fire(...)end
 return e
end
local Instance={new=function(k)assert(k=="BindableEvent");createdEvents+=1;return event()end}
local task={spawn=function(fn,...)fn(...)end,defer=function(fn,...)fn(...)end,wait=function()end}
local player={attributes={},attributeSignals={}}
function player:GetAttribute(k)return self.attributes[k]end
function player:GetAttributeChangedSignal(k)
 self.attributeSignals[k]=self.attributeSignals[k]or signal();return self.attributeSignals[k]
end
function player:SetAttribute(k,v)
 local old=self.attributes[k];self.attributes[k]=v
 if old~=v and self.attributeSignals[k]then self.attributeSignals[k]:Fire()end
end
local existingEvent=event()
local playerGui={FindFirstChild=function(self,k)if k=="SpyOpenDossier"then return existingEvent end end}
local hudView={setActive=function(self,k)self.active=k end}
local panels={}
local activeDock=nil
local dossierOpenRequested,dossierCategory=false,nil
local openPanel
local language="en"
local Catalog={Cases={atelier={}},ById={}}
local messages={}
local function notify(message)table.insert(messages,message)end
local function warn(message)error(message)end
local receivedState=false
''' + callpanel + setactive + creator + bridge + r'''
eq(createdEvents,0,"bridge must reuse existing BindableEvent")
eq(openPanel("inventory",nil,false),false,"phone unavailable returns failed ack")
eq(dossierOpenRequested,false,"failed phone launch cannot queue surprise panel")
existingEvent:Fire("open")
eq(dossierOpenRequested,true,"open queues while module loads")
eq(player:GetAttribute("SpyCharacterMenuOpen"),nil,"queue must not pretend visible")
existingEvent:Fire("close")
eq(dossierOpenRequested,false,"close cancels queued open")
existingEvent:Fire()
eq(dossierOpenRequested,true,"toggle queues open")
existingEvent:Fire()
eq(dossierOpenRequested,false,"second toggle cancels queue")
player:SetAttribute("SpyEntryPending",true)
existingEvent:Fire("open")
eq(dossierOpenRequested,false,"arrival cannot queue or open dossier")
player:SetAttribute("SpyEntryPending",false)
existingEvent:Fire("open")
local dossier={visible=false,pendingId="same-roll-id",opens=0,closes=0}
function dossier:open(category)self.visible=true;self.category=category;self.opens+=1;setDockActive("accessoryRoll");return true end
function dossier:close()self.visible=false;self.closes+=1;setDockActive(nil)end
createOptional("accessoryRoll",{create=function()return dossier end})
eq(dossier.opens,1,"loaded panel fulfills queued open")
eq(dossierOpenRequested,false)
eq(player:GetAttribute("SpyCharacterMenuOpen"),true)
eq(hudView.active,"accessoryRoll")
existingEvent:Fire("close")
eq(dossier.visible,false)
eq(dossier.pendingId,"same-roll-id","closing must delegate without replacing pending request")
eq(player:GetAttribute("SpyCharacterMenuOpen"),false)
existingEvent:Fire()
eq(dossier.visible,true)
existingEvent:Fire()
eq(dossier.visible,false)
for _,name in ipairs({"shop","inventory","collection","character"})do
 eq(openPanel(name),true,"legacy launcher redirects")
 eq(activeDock,"accessoryRoll")
end
openPanel("shop","atelier")
eq(dossier.category,"hair","legacy hair shortcut")
local profilePanel={open=function(self)self.visible=true;setDockActive("profile")end}
panels.profile=profilePanel
openPanel("profile")
eq(profilePanel.visible,true,"profile launcher remains functional")
eq(player:GetAttribute("SpyCharacterMenuOpen"),false)
dossier:close()
for _,attribute in ipairs({"SpyPhoneActive","SpyTradeOpen"})do
 panels.accessoryRoll=nil
 existingEvent:Fire("open")
 local opensBefore=dossier.opens
 player:SetAttribute(attribute,true)
 createOptional("accessoryRoll",{create=function()return dossier end})
 eq(dossier.opens,opensBefore,"late arrival cannot cover active phone or trade")
 eq(dossierOpenRequested,false,"blocked replay cancels old intent")
 player:SetAttribute(attribute,false)
 existingEvent:Fire("open")
 eq(dossier.opens,opensBefore+1,"new request opens after external panel closes")
 dossier:close()
end
local premium={visible=false,pendingId='native-receipt-pending'}
function premium:open()self.visible=true;setDockActive('premiumShop')end
function premium:close()self.visible=false;setDockActive(nil)end
panels.premiumShop=premium
for _,flag in ipairs({'SpyPhoneActive','SpyTradeOpen','SpyTeleporting','SpyEntryPending','SpyEntryActive'})do
 eq(openPanel('premiumShop'),true,'premium opens before '..flag)
 player:SetAttribute(flag,true)
 eq(premium.visible,false,'external state closes premium: '..flag)
 eq(openPanel('premiumShop'),false,'external state blocks reopening: '..flag)
 eq(premium.pendingId,'native-receipt-pending','closing preserves native receipt tracking')
 player:SetAttribute(flag,false)
end
local rollsValue={}
''' + roll + r'''
setRollDisplay(17)
eq(rollsValue.Text,"17 Rolls","actual Rolls balance")
setRollDisplay(0)
eq(rollsValue.Text,"0 Rolls")
setRollDisplay(nil)
eq(rollsValue.Text,"… Rolls")
setRollDisplay(0/0)
eq(rollsValue.Text,"… Rolls","invalid balance cannot become reward")
''' + r'''
local profile={}
local state={}
local languageInitialized=false
local bindings={}
local rankText={}
local dailyBadge={}
local subtitle={}
local main={}
local lobbyCounts={}
local missionText={}
local lobbyChat={update=function()end}
function hudView:update()end
local function L(k)return k end
local localizeWorld=nil
local onboarding=nil
local lastRound,lastTable,lastPhase=nil,nil,nil
local function focusTable()end
local function clearChat()end
local function resize()end
local render
''' + render + r'''
render({profile={}})
eq(rollsValue.Text,"… Rolls","empty profile sync has no invented balance")
eq(rankText.Text,"profileLoading")
eq(dailyBadge.Visible,false)
render({profile={ready=false}})
eq(rollsValue.Text,"… Rolls","unavailable profile sync remains loading")
render({profile={ready=true,rolls=7,coins=99999}})
eq(rollsValue.Text,"7 Rolls","synced Rolls remains independent of legacy coins")
eq(rankText.Text,"level")
local RollConfig=(function()
''' + config + r'''
end)()
local script=nil
local function require(k)if k=="AccessoryRollConfig"then return RollConfig end;return {}end
local Daily=(function()
''' + serverdaily + r'''
end)()
local ctx={language=function()return "en"end,L=function(k)return k end}
local function tr(k)return ({coins="COINS"})[k]end
''' + helpers + r'''
local status=Daily.status({},86400)
eq(#status.rewards,7,"same seven-day schedule")
local coinDays={80,120,0,180,220,0,1000}
for i,reward in ipairs(status.rewards)do
 eq(rewardName(reward),tostring(RollConfig.Rewards.daily).." Rolls","daily reward headline")
 eq(rewardExtra(reward),coinDays[i]>0 and "+"..coinDays[i].." COINS"or"","real secondary reward remains visible")
end
local startProfile={coins=45,rolls=3}
local receipt=Daily.claim(startProfile,86400,Catalog)
eq(receipt.rolls,RollConfig.Rewards.daily,"UI amount equals actual awarded Rolls")
eq(receipt.coins,80,"legacy bonus preserved")
local nodes={}
local added=signal()
local workspace={DescendantAdded=added,GetDescendants=function()return nodes end}
local function node(k,name)
 local n={ClassName=k,Name=name,Parent=workspace}
 function n:IsA(v)return v==self.ClassName or v=="BasePart"and self.ClassName=="Part"end
 function n:Destroy()self.Parent=nil;self.destroyed=true end
 return n
end
for _,name in ipairs({"ClassicCase","SilverCase","GoldCase","AtelierDisplay","FeaturedCases","CaseFiles","CaseRound","InvestigationCase","ClassicCaseNotes"})do table.insert(nodes,node("Model",name))end
local retainedScript=node("Script","ClassicCase");table.insert(nodes,retainedScript)
''' + cleanup + r'''
for i=1,5 do eq(nodes[i].destroyed,true,"retired exact showroom root")end
for i=6,#nodes do eq(nodes[i].destroyed,nil,"investigation and unrelated objects preserved")end
local late=node("Model","AtelierDisplay");added:Fire(late)
eq(late.destroyed,true,"late authored showroom root removed")
local casefile=node("Model","CaseFiles");added:Fire(casefile)
eq(casefile.destroyed,nil,"late investigation case survives")
print("PASS: "..checks.." checks for reused H bridge, async open/cancel, arrival guard, true Rolls, real daily bonuses, exact cosmetic cleanup and investigation preservation")
'''
with tempfile.TemporaryDirectory(prefix='spyclub-legacy-ui-') as directory:
    target = Path(directory) / 'legacy.luau'
    target.write_text(source)
    result = subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=root)
    raise SystemExit(result.returncode)
