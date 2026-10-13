#!/usr/bin/env python3
"""Execute lobby setup and fixture audit in Luau with bounded engine stubs.

This validates runtime contracts and spawn/route metadata, not Studio rendering.
"""
from pathlib import Path
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUAU = os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau")

STUBS = r'''
local function eq(a,b,message) assert(a==b,message or tostring(a).." ~= "..tostring(b)) end
local enumCache={}
local function enumBranch(prefix)
 return setmetatable({}, {__index=function(self,k)
  local key=prefix.."."..k
  local value=enumCache[key]
  if not value then value=enumBranch(key);enumCache[key]=value end
  rawset(self,k,value);return value
 end})
end
local Enum=enumBranch("Enum")
local vmeta={}
vmeta.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
end
local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vmeta) end
vmeta.__add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vmeta.__sub=function(a,b)return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vmeta.__mul=function(a,b)return vector(a.X*b,a.Y*b,a.Z*b)end
vmeta.__div=function(a,b)return vector(a.X/b,a.Y/b,a.Z/b)end
local Vector3={new=vector,zero=vector()}
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local cmeta={}
local function frame(pos,yaw) return setmetatable({Position=pos,Yaw=yaw or 0},cmeta) end
cmeta.__index=function(c,k)
 if k=="LookVector" then return vector(-math.sin(c.Yaw),0,-math.cos(c.Yaw)) end
 if k=="RightVector" then return vector(math.cos(c.Yaw),0,-math.sin(c.Yaw)) end
 if k=="UpVector" then return vector(0,1,0) end
end
cmeta.__mul=function(a,b)return frame(a.Position+b.Position,a.Yaw+b.Yaw)end
local CFrame={new=function(x,y,z)return frame(type(x)=="table" and x or vector(x,y,z))end,
 Angles=function(x,y,z)return frame(vector(),y)end}
local Color3={fromRGB=function(r,g,b)return {r=r,g=g,b=b}end,new=function(r,g,b)return {r=r,g=g,b=b}end}
local UDim2={fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end}
local signal={Connect=function(self,fn)return {Disconnect=function()end}end}
local objectMethods={}
local imeta={}
imeta.__index=function(o,k)
 if objectMethods[k] then return objectMethods[k] end
 if k=="Position" then return o.CFrame.Position end
 if k=="Parent" then return rawget(o,"_parent") end
 return nil
end
imeta.__newindex=function(o,k,v)
 if k~="Parent" then rawset(o,k,v);return end
 local previous=rawget(o,"_parent")
 if previous then for i,child in ipairs(previous._children)do if child==o then table.remove(previous._children,i);break end end end
 rawset(o,"_parent",v)
 if v then table.insert(v._children,o) end
end
function objectMethods:IsA(class)
 if self.ClassName==class then return true end
 if class=="BasePart" then return self.ClassName=="Part" or self.ClassName=="SpawnLocation" or self.ClassName=="Seat"end
 if class=="Light" then return self.ClassName=="SurfaceLight" or self.ClassName=="PointLight" or self.ClassName=="SpotLight"end
 return false
end
function objectMethods:GetChildren()return table.clone(self._children)end
function objectMethods:GetDescendants()
 local out={};local function walk(o)for _,child in ipairs(o._children)do out[#out+1]=child;walk(child)end end
 walk(self);return out
end
function objectMethods:FindFirstChild(name,recursive)
 for _,child in ipairs(self._children)do if child.Name==name then return child end end
 if recursive then for _,child in ipairs(self._children)do local found=child:FindFirstChild(name,true);if found then return found end end end
end
function objectMethods:IsDescendantOf(other)local p=self.Parent;while p do if p==other then return true end;p=p.Parent end;return false end
function objectMethods:FindFirstAncestor(name)local p=self.Parent;while p do if p.Name==name then return p end;p=p.Parent end end
function objectMethods:SetAttribute(k,v)self._attributes[k]=v end
function objectMethods:GetAttribute(k)return self._attributes[k]end
function objectMethods:Destroy()self.Destroyed=true;self.Parent=nil end
local Instance={new=function(class)
 return setmetatable({ClassName=class,Name=class,_children={},_attributes={},Transparency=0,
  CFrame=frame(vector()),Size=vector(1,1,1),Destroying=signal,DescendantAdded=signal,Enabled=true},imeta)
end}
local function object(class,name,parent)
 local o=Instance.new(class);o.Name=name;o.Parent=parent;return o
end
local workspace=object("Workspace","Workspace")
local lighting=object("Lighting","Lighting")
local game={GetService=function(self,name)if name=="Lighting"then return lighting end;return object("Folder",name)end}
local task={spawn=function(fn,...)fn(...)end,defer=function(fn,...)fn(...)end}
local script={Parent={FindFirstChild=function()return nil end}}
local modules={}
local function require(value)assert(modules[value],"unknown stub require: "..tostring(value));return modules[value]end
local function warn(message)error(message)end
'''

CHECKS = r'''
local club=object("Model","SpyClub",workspace)
local archive=object("Model","ClubArchive",club)
local door=object("Part","ClosedLeaf",archive);door.CanCollide=true
local vincent=object("Part","VincentAnchor",club);vincent.CFrame=CFrame.new(0,3,29)
object("ProximityPrompt","TalkVincent",vincent)
local daily=object("Part","DailyEnvelope",club);daily.CFrame=CFrame.new(-25,3,25)
object("ProximityPrompt","DailyReward",daily)
local classic=object("Model","ClassicCase",workspace)
local anchor=object("Part","Handle",classic);anchor.CFrame=CFrame.new(35,3,0)
object("ProximityPrompt","CasePrompt",anchor)

local world=modules.World
local bakedSpawn
for _,definition in ipairs(modules.Spec.parts)do if definition.name=="ClubSpawn"then bakedSpawn=definition end end
assert(bakedSpawn,"WorldSpec must retain the spawn definition")
eq(bakedSpawn.pos[3],modules.Spec.entry.spawn.position[3],"baked and live spawn must agree")
eq(bakedSpawn.yaw,modules.Spec.entry.spawn.yaw,"baked and live facing must agree")
eq(modules.Spec.routes[1][2],modules.Spec.entry.spawn.position[3],"baked route must start at the live spawn")
world.build({})
local spawn=club:FindFirstChild("ClubSpawn")
eq(spawn.Position.Z,-26.5,"world bind must not reset the foyer spawn")
assert(spawn.CFrame.LookVector.Z>.999,"spawn must face the main lounge")
eq(spawn.CanCollide,false)
eq(club:FindFirstChild("SafetyFloor").CanCollide,true)
eq(door.Parent,archive,"existing locked door must survive")
eq(door.CanCollide,true)
local entrance=club:FindFirstChild("ClubEntrance")
assert(entrance,"foyer was not built")
local entryLightCount=0
for _,n in ipairs(entrance:GetDescendants())do
 if n:IsA("BasePart")then eq(n.CanCollide,false,"foyer decoration must not obstruct spawning")end
 if n:IsA("Light")then entryLightCount+=1 end
end
eq(entryLightCount,4)
local plan=modules.Wayfinding.plan(club)
eq(plan.destinations.entrance.anchor.Z,-26.5)
local entryRoute=plan.rectangles[1]
eq(entryRoute.z-entryRoute.length*.5,-29.5,"runner starts behind the actual spawn")
eq(plan.destinations.vincent.anchor,vincent.Position)
eq(plan.destinations.daily.anchor,daily.Position)
assert(club:FindFirstChild("ClubWayfinding"):FindFirstChild("WelcomeInlay"),"planned route labels must be rendered")
world.build({})
eq(club:FindFirstChild("ClubEntrance"),entrance,"world build must be idempotent")

local function fixture(setName,ownerName,lightName,class)
 local set=club:FindFirstChild(setName)or object("Model",setName,club)
 local owner=object("Part",ownerName,set);owner.Material=Enum.Material.Neon;owner:SetAttribute("ClubFixture",true)
 return object(class or "SurfaceLight",lightName,owner),owner
end
local allowed={}
for _,row in ipairs({
 {"ClubInterior","SconceLens","FixtureEmission"},
 {"ClubInterior","CornerUpperLens","FixtureEmission"},
 {"ClubInterior","Aisle1Lens","FixtureEmission"},
 {"ClubInterior","Side2Lens","FixtureEmission"},
 {"ClubInterior","Bar3Lens","FixtureEmission"},
 {"ClubInterior","Corridor44Lens","FixtureEmission"},
 {"ClubInterior","LoungeLampBulb","BulbGlow","PointLight"},
 {"ClubInterior","DisplayLens","DisplayAccent"},
 {"NocturneLounge","LampDiffuser","LampLight"},
 {"NocturneLounge","PortraitKeyDiffuser","PortraitKeyLight"},
 {"NocturneLounge","PortraitRimDiffuser","PortraitRimLight"},
 {"NocturneLounge","CeilingDiffuser","CeilingLight","SpotLight"},
 {"ClubArchive","CafeLampDiffuser","ArchiveLight"},
 {"ClubArchive","DoorLampDiffuser","ArchiveLight"},
 {"ClubArchive","MeetingDiffuser","ArchiveLight","SpotLight"},
 {"ClubArchive","BarArchiveNeon","ArchiveLight"},
 {"ClubArchive","BoardLampDiffuser","ArchiveLight"},
 {"RainWindows","WindowStreetLens","StreetSpill"},
 {"RainWindows","WindowStreetLens","CanopyPavement"},
 })do allowed[#allowed+1]=fixture(table.unpack(row))end
for _,name in ipairs({"ShelfLight4.0","ShelfLight7.0","ShelfLight10.0"})do
 local owner=object("Part",name,club);owner.Material=Enum.Material.Neon;owner:SetAttribute("ClubFixture",true)
 allowed[#allowed+1]=object("SurfaceLight","FixtureEmission",owner)
end
local exterior=object("Model","Exterior",club:FindFirstChild("RainWindows"))
local street=object("Model","NightStreet",exterior)
for _,name in ipairs({"LampLens","ShopWindow","FacadeLampLens"})do
 local owner=object("Part",name,street);owner.Material=Enum.Material.Neon;owner:SetAttribute("ClubFixture",true)
 allowed[#allowed+1]=object("SurfaceLight","FixtureLight",owner)
end
local rogue,rogueOwner=fixture("WrongSet","EntranceWarmLens","EntryWarmLight")
local forged=fixture("ClubEntrance","UnrecognizedEmitter","EntryWarmLight")
local hidden,hiddenOwner=fixture("ClubEntrance","EntranceWarmLens","EntryWarmLight");hiddenOwner.Transparency=1
local wrongClass=fixture("ClubEntrance","EntranceFaceLens","EntryFaceLight","PointLight")
local wrongIdentity=fixture("ClubInterior","SconceLens","ArbitraryLight")
local unmarked,unmarkedOwner=fixture("ClubEntrance","EntranceWarmLens","EntryWarmLight");unmarkedOwner:SetAttribute("ClubFixture",false)
local outside=object("PointLight","MinigameLight",object("Part","OtherGame",workspace))
local report=modules.Lighting.audit(workspace)
eq(report.removed,6,"audit must reject unapproved owner/class/ancestry combinations")
for _,light in ipairs(allowed)do assert(light.Parent,"known fixture was wrongly removed: "..light.Name)end
for _,light in ipairs({rogue,forged,hidden,wrongClass,wrongIdentity,unmarked})do assert(light.Destroyed)end
assert(outside.Parent,"lobby audit must not remove another interactive object's light")
eq(#entrance:GetDescendants(),#club:FindFirstChild("ClubEntrance"):GetDescendants())
eq(modules.Lighting.audit(club).removed,0,"second audit must be stable")
print("PASS: spawn facing/support; additive foyer; route anchors/inlays; repeatable setup; 30 approved fixture identities; 6 audit rejections; scope isolation")
'''


def source(name):
    return (ROOT / "src/lobby/ServerStorage/SpyModules" / (name + ".luau")).read_text()


def main():
    # Validate the authored collision envelope from the actual uploaded lobby.
    instances = json.loads((ROOT / "src/lobby/instances.json").read_text())
    obstacles = []
    for item in instances:
        prop = item["properties"]
        if not item["path"].startswith("Workspace/") or not prop.get("CanCollide"):
            continue
        # Terrain's API extents are not its occupied voxel volume.
        if item["class"] == "Terrain":
            continue
        position = prop.get("CFrame", {}).get("position")
        size = prop.get("size")
        if not position or not size:
            continue
        x, y, z = position
        sx, sy, sz = size
        if y + sy / 2 <= .2 or y - sy / 2 >= 8:
            continue
        if x + sx / 2 > -4 and x - sx / 2 < 4 and z + sz / 2 > -29 and z - sz / 2 < -24:
            obstacles.append(item["path"])
    assert not obstacles, f"saved colliders intersect spawn envelope: {obstacles}"
    assembled = STUBS
    for file, key in [("WorldSpec", "Spec"), ("LobbyLighting", "Lighting"), ("LobbyWayfinding", "Wayfinding"), ("World", "World")]:
        assembled += f"\nmodules.{key}=(function()\n{source(file)}\nend)()\n"
    assembled += r'''
script.Parent.WorldSpec="Spec"
script.Parent.WorldGeometry="Geometry"
script.Parent.LobbyWayfinding="Wayfinding"
script.Parent.LobbyLighting="Lighting"
script.Parent.Npc="Npc"
modules.Npc={spawn=function()end}
modules.Geometry={bind=function(root)
 -- Emulate the geometry writer to catch a missing post-bind safety assertion.
 root:FindFirstChild("ClubSpawn").CFrame=CFrame.new(0,.25,-23)
 return {}
end}
'''
    assembled += CHECKS
    with tempfile.TemporaryDirectory(prefix="spy-lobby-tests-") as directory:
        test = Path(directory) / "lobby.luau"
        test.write_text(assembled)
        subprocess.run([LUAU, str(test)], check=True)
    print("PASS: uploaded geometry has no authored collider in the eight-by-five-by-eight spawn envelope")


if __name__ == "__main__":
    main()
