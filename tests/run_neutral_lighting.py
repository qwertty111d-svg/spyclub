#!/usr/bin/env python3
"""Exercise room finish and both real preview modules; this is not Studio rendering."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from test_lobby_environment import STUBS

BOUNDARIES = r'''
local serviceObjects={Lighting=lighting}
function game:GetService(name)
 if not serviceObjects[name]then serviceObjects[name]=object("Folder",name)end
 return serviceObjects[name]
end
function objectMethods:GetAttributeChangedSignal()return signal end
function objectMethods:GetPropertyChangedSignal()return signal end
function objectMethods:FindFirstChildOfClass(class)
 for _,child in ipairs(self._children)do if child:IsA(class)then return child end end
end
function objectMethods:WaitForChild(name)return self:FindFirstChild(name)end
local previousFrameIndex=cmeta.__index
cmeta.__index=function(value,key)
 if key=="VectorToWorldSpace"then return function(self,direction)return direction end end
 return previousFrameIndex(value,key)
end
CFrame.lookAt=function(position)return frame(position)end
local players=game:GetService("Players")
function players:GetPlayerByUserId()return nil end
game:GetService("ReplicatedStorage").ChildAdded=signal
local input=game:GetService("UserInputService");input.InputChanged=signal;input.InputEnded=signal
local originalNew=Instance.new
Instance.new=function(class)
 local node=originalNew(class);node.InputBegan=signal;return node
end
modules.Art={}
modules.Wardrobe={itemsToEquipment=function()return {}end}
script.Parent.Art="Art";script.Parent.Wardrobe="Wardrobe"
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function neutral(color,message)
 check(color.r==color.g and color.g==color.b,message)
end
'''

ROOM_CHECKS = r'''
local room=object("Model","SpyMatchRoom",workspace)
local floor=object("Part","MainFloor",room);floor.CanCollide=true;floor.Anchored=true
local gameTable=object("Model","GameTable",room)
local felt=object("Part","Felt",gameTable);felt.CFrame=CFrame.new(0,2,0);felt.Size=Vector3.new(16,.2,12)
felt.CanCollide=true;felt.Anchored=true
local lamp=object("Part","LampFace",gameTable);lamp.CFrame=CFrame.new(0,10,0);lamp.Size=Vector3.new(.2,4,4)
lamp.CanCollide=false;lamp.Anchored=true
local lampLight=object("PointLight","WarmLight",lamp)
local shade=object("Part","Lamp",gameTable);shade.Size=Vector3.new(.2,4,4);shade.Anchored=true
local wall=object("Part","WestWall",room);wall.CanCollide=true;wall.Anchored=true
local sconces=object("Model","WallSconces",room)
local wallLights={}
for i=1,6 do
 local lens=object("Part","SconceGlow"..i,sconces);lens.CanCollide=false
 wallLights[i]=object("PointLight","WarmLight",lens)
end
local unrelated=object("PointLight","OtherRoomLight",object("Part","Elsewhere",workspace))
unrelated.Color=Color3.fromRGB(12,34,56);unrelated.Brightness=2
local controller=modules.Room.start(room)
check(controller~=nil,"authored room fixture must finish")
neutral(lighting.Ambient,"room ambient must not tint the neutral lights")
neutral(lighting.OutdoorAmbient,"room exterior fill must be neutral")
check(lighting.Ambient.r>=120 and lighting.Ambient.r<=145,"room needs useful bounded face fill")
check(lighting.ExposureCompensation<=.20,"local fill must not be replaced by a large exposure lift")
for _,light in ipairs(wallLights)do
 neutral(light.Color,"wall sconces must emit neutral light")
 check(light.Enabled and light.Range>=18 and light.Brightness>=.6 and light.Brightness<=1.1,"existing sconces need bounded local edge coverage")
end
local pool=lamp:FindFirstChild("TablePool")
check(pool and pool.Enabled,"authored overhead lamp must retain a downward table pool")
neutral(pool.Color,"table pool must be neutral")
check(pool.Face==Enum.NormalId.Bottom and pool.Range>=20,"table light must illuminate down from its real fixture")
neutral(lampLight.Color,"overhead face fill must be neutral")
check(lampLight.Range>=20 and lampLight.Brightness>=.6 and lampLight.Brightness<=1.1 and not lampLight.Shadows,"existing lamp should supply soft fill without another hard shadow")
check(floor.CanCollide and felt.CanCollide and wall.CanCollide,"light finish must preserve authored collisions")
check(floor.Anchored and felt.Anchored and lamp.Anchored,"lighting must not release authored anchors")
check(unrelated.Brightness==2 and unrelated.Color.g==34,"room finish must not touch another room's emitters")
local count=#room:GetDescendants();local lampSize=lamp.Size
check(modules.Room.start(room)==controller,"repeated room boot must reuse its controller")
check(#room:GetDescendants()==count and lamp.Size==lampSize,"repeated finish must not duplicate lights or repeatedly shrink a lamp")
'''

PREVIEW_CHECKS = r'''
local parent=object("Frame","Portrait",workspace);parent.ZIndex=4
local preview=modules.Preview.mountCollection(parent,{}, {})
check(preview.Parent==parent,"real preview initializer must create its viewport")
neutral(preview.Ambient,"portrait fill must be neutral independently of world Lighting")
neutral(preview.LightColor,"H/store avatar key must not be yellow or blue")
check(preview.Ambient.r>=180 and preview.LightColor.r>=240,"neutral portrait lighting must remain readable")
'''


def module(path, key):
    return f"\nmodules.{key}=(function()\n{path.read_text()}\nend)()\n"


def main():
    assembled = STUBS + BOUNDARIES
    assembled += module(ROOT / "src/match/ServerStorage/SpyModules/MatchRoomExperience.luau", "Room")
    assembled += ROOM_CHECKS
    for scene in ("lobby", "match"):
        assembled += module(ROOT / f"src/{scene}/ReplicatedStorage/SpyShared/Preview3D.luau", "Preview")
        assembled += PREVIEW_CHECKS
    assembled += '\nprint("PASS: "..checks.." neutral room/portrait lighting and preservation checks")\n'
    with tempfile.TemporaryDirectory(prefix="spy-neutral-lighting-") as directory:
        harness = Path(directory) / "lighting.luau"
        harness.write_text(assembled)
        result = subprocess.run([os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(harness)], cwd=ROOT)
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
