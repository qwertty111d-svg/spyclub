#!/usr/bin/env python3
"""Exercise the real cleanup against saved lobby topology and late assembly."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
saved = json.loads((ROOT / "src/lobby/instances.json").read_text())
workspace_ref = next(node["ref"] for node in saved if node["path"] == "Workspace")
server_storage_ref = next(node["ref"] for node in saved if node["path"] == "ServerStorage")
podiums = [node for node in saved if node["parent"] == workspace_ref
           and node["class"] == "Model" and node["name"] == "Model"]
assert len(podiums) == 3, "saved lobby must still contain its three imported podiums"
retired_roots = {node["ref"] for node in podiums}
retired_roots.update(node["ref"] for node in saved
                     if node["path"] in {"Workspace/ClassicCase", "Workspace/SilverCase", "Workspace/GoldCase"})
assert len(retired_roots) == 6
removed = set(retired_roots)
while True:
    descendants = {node["ref"] for node in saved if node["parent"] in removed}
    if descendants <= removed:
        break
    removed.update(descendants)


def luau(value):
    if value is None:
        return "nil"
    if isinstance(value, list):
        return "{" + ",".join(luau(item) for item in value) + "}"
    return json.dumps(value, ensure_ascii=False)


source = r'''
local checks=0
local function eq(actual,expected,label)
 checks+=1;assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function signal()
 local s={listeners={}}
 function s:Connect(fn)table.insert(self.listeners,fn);return {Disconnect=function()end}end
 function s:Fire(node)for _,fn in ipairs(self.listeners)do fn(node)end end
 return s
end
local deferred={}
local task={defer=function(fn)table.insert(deferred,fn)end}
local function flush()
 while #deferred>0 do local pending=deferred;deferred={};for _,fn in ipairs(pending)do fn()end end
end
local nodes={}
local methods={}
local function vector(values)return {X=values[1],Y=values[2],Z=values[3]}end
local function node(ref,class,name,parentRef,pos,size)
 local n=setmetatable({ref=ref,ClassName=class,Name=name,parentRef=parentRef,children={},DescendantAdded=signal()}, {__index=methods})
 if pos then n.Position=vector(pos);n.Size=vector(size)end
 nodes[ref]=n;return n
end
function methods:IsA(class)
 return class==self.ClassName or class=="BasePart"and(self.ClassName=="Part"or self.ClassName=="WedgePart"or self.ClassName=="MeshPart"or self.ClassName=="Seat"or self.ClassName=="SpawnLocation")
end
function methods:GetChildren()return table.clone(self.children)end
function methods:GetDescendants()
 local out={};local function walk(n)for _,child in ipairs(n.children)do table.insert(out,child);walk(child)end end
 walk(self);return out
end
local workspace
local function attach(n,parent,announce)
 if n.Parent then for i,child in ipairs(n.Parent.children)do if child==n then table.remove(n.Parent.children,i);break end end end
 n.Parent=parent;if parent then table.insert(parent.children,n)end
 if announce then
  local ancestor=parent;local live=false
  while ancestor do if ancestor==workspace then live=true;break end;ancestor=ancestor.Parent end
  if live then workspace.DescendantAdded:Fire(n);for _,child in ipairs(n:GetDescendants())do workspace.DescendantAdded:Fire(child)end end
 end
end
function methods:Destroy()
 for _,child in ipairs(self:GetChildren())do child:Destroy()end
 attach(self,nil,false);self.destroyed=true
end
'''
for entry in saved:
    properties = entry["properties"]
    position = properties.get("CFrame", {}).get("position")
    size = properties.get("size")
    args = [entry["ref"], entry["class"], entry["name"], entry["parent"],
            position if size else None, size]
    source += "node(" + ",".join(luau(arg) for arg in args) + ")\n"
source += f"workspace=nodes[{workspace_ref}]\n"
source += f"local protectedStorage=nodes[{server_storage_ref}]\n"
source += "for _,n in pairs(nodes)do if nodes[n.parentRef]then attach(n,nodes[n.parentRef],false)end end\n"
source += "local podiumRefs={" + ",".join(str(node["ref"]) for node in podiums) + "}\n"
source += r'''
local freshRef=20000
local function make(class,name,parent,pos,size)
 freshRef+=1;local n=node(freshRef,class,name,-1,pos,size);if parent then attach(n,parent,true)end;return n
end
local function cloneTree(original,offset,parent,announce)
 local pos=original.Position
 local copy=make(original.ClassName,original.Name,nil,pos and {pos.X+offset[1],pos.Y+offset[2],pos.Z+offset[3]},original.Size and {original.Size.X,original.Size.Y,original.Size.Z})
 for _,child in ipairs(original:GetChildren())do cloneTree(child,offset,copy,false)end
 if parent then attach(copy,parent,announce)end;return copy
end
-- Capture actual imported geometry before the cleanup runs. Later clones therefore
-- exercise the saved scene, independently of production fingerprint constants.
local templates={}
for _,ref in ipairs(podiumRefs)do table.insert(templates,cloneTree(nodes[ref],{0,0,0},nil,false))end
local unrelated=cloneTree(templates[1],{0,0,1},workspace,false)
local movedBase=cloneTree(templates[1],{0,0,0},workspace,false)
for _,child in ipairs(movedBase:GetChildren())do if child:IsA("Part")and child.Size.Y>.9 and child.Size.Y<1.1 then child.Position.X+=.1 end end
local nested=make("Model","InvestigationCase",workspace)
local nestedPodium=cloneTree(templates[1],{0,0,0},nested,false)
local renamed=cloneTree(templates[1],{0,0,0},nil,false);renamed.Name="CaseFiles";attach(renamed,workspace,false)
local functional={}
for _,name in ipairs({"CaseFiles","CaseRound","SpyCaseArchive","SpyMeetingClues","FeedbackDesk","ClubArchive"})do
 local root=make("Model",name,workspace);table.insert(functional,root)
 for _,child in ipairs({"ArchiveFolder","FeedbackBook","LetterTray","MeetingDossier","RecorderBody","CasePrompt_archive"})do make("Part",child,root)end
end
local paidRights=make("Folder","PaidRights",protectedStorage)
paidRights.entitlements={case_luck_2x=true};paidRights.receipts={"original-paid-receipt"}
local classicScript=make("Script","ClassicCase",workspace)
local originalParents={}
for ref,n in pairs(nodes)do if ref<20000 then originalParents[ref]=n.Parent end end
'''
source += (ROOT / "src/lobby/ServerScriptService/LegacyShowcaseCleanup.server.luau").read_text()
source += "\nlocal removed={" + ",".join(f"[{ref}]=true" for ref in sorted(removed)) + "}\n"
source += r'''
for _,ref in ipairs(podiumRefs)do eq(nodes[ref].Parent,nil,"saved imported podium must retire: "..ref)end
for ref,parent in pairs(originalParents)do
 local n=nodes[ref]
 if removed[ref]then eq(n.destroyed,true,"retired saved subtree: "..ref)
 else eq(n.Parent,parent,"unrelated saved topology survives: "..ref)end
end
for _,root in ipairs({unrelated,movedBase,nested,nestedPodium,renamed,classicScript})do eq(root.destroyed,nil,"similar or functional model survives")end
for _,root in ipairs(functional)do eq(#root:GetChildren(),6,"functional props remain intact")end
eq(paidRights.Parent,protectedStorage,"paid rights remain in server storage")
eq(paidRights.entitlements.case_luck_2x,true,"paid entitlement remains intact")
eq(paidRights.receipts[1],"original-paid-receipt","paid receipt remains intact")

-- A whole authored subtree can arrive after startup.
local whole=cloneTree(templates[2],{0,0,0},workspace,true)
eq(whole.Parent,workspace,"deferred removal leaves parenting atomic")
eq(#deferred,1,"a streamed subtree coalesces into one pending root check")
flush();eq(whole.destroyed,true,"late complete saved podium retires")

-- A parent may arrive first, with its base and cap attached in separate turns.
local incremental=make("Model","Model",workspace);flush()
eq(incremental.Parent,workspace,"empty unnamed root survives")
local cap
for _,child in ipairs(templates[3]:GetChildren())do
 if child:IsA("WedgePart")then cap=child else cloneTree(child,{0,0,0},incremental,true)end
end
flush();eq(incremental.Parent,workspace,"base without matching cap survives")
assert(cap,"saved podium cap is required")
cloneTree(cap,{0,0,0},incremental,true);flush()
eq(incremental.destroyed,true,"late incremental saved podium retires after cap arrives")

local lateUnrelated=cloneTree(templates[3],{0,0,-1},workspace,true);flush()
eq(lateUnrelated.Parent,workspace,"nearby same-sized late podium survives")
local lateInvestigation=make("Model","CaseFiles",workspace)
for i=1,30 do make("Part","Clue"..i,lateInvestigation)end
eq(#deferred,0,"functional ancestry does not schedule podium geometry scans")
local lateNamed=make("Model","AtelierDisplay",workspace);flush()
eq(lateNamed.destroyed,true,"late named cosmetic display still retires")
print("PASS: "..checks.." checks for saved podium topology, unrelated props, paid rights and late incremental assembly")
'''

with tempfile.TemporaryDirectory(prefix="spyclub-showcase-cleanup-") as directory:
    target = Path(directory) / "showcase.luau"
    target.write_text(source)
    result = subprocess.run([os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau"), str(target)], cwd=ROOT)
    raise SystemExit(result.returncode)
