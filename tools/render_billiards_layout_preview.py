#!/usr/bin/env python3
"""Export the real billiards GUI as diagnostic HTML and measured node JSON.

The current client's presentation sections run against public sample state.
Roblox services, text measurement and the native cue-ball viewport are explicit
boundaries; this does not render the table, simulate physics or send actions.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from render_match_layout_preview import (
    BOUNDARIES as MATCH_BOUNDARIES,
    ROOT,
    STUB,
    between,
    write_html,
)


CLIENT = ROOT / "src/lobby/StarterPlayer/StarterPlayerScripts/BilliardsClient.client.luau"
MATCH_RENDERER = ROOT / "tools/render_match_layout_preview.py"
VARIANTS = ("mode", "hud", "rules", "result")

# Reuse the existing GUI property/size/clip boundary and serializer. They contain
# no match construction or presenter state in these two selected sections.
GUI_BOUNDARIES = MATCH_BOUNDARIES.split("local player=Instance.new('Player')", 1)[0]
SERIALIZER = MATCH_BOUNDARIES[MATCH_BOUNDARIES.index("-- Native UIGridLayout"):]

BOUNDARIES = r'''
-- Geometry-only boundaries. No input event is fired by the exporter.
events.InputBegan=true;events.InputChanged=true;events.InputEnded=true;events.FocusLost=true
function Methods:IsFocused()return false end
local baseInstanceNew=Instance.new
function Instance.new(class)
 local node=baseInstanceNew(class)
 if guiClasses[class]then node.Size=UDim2.fromOffset(100,100)end
 if class=='ScrollingFrame'then node.CanvasSize=UDim2.new()end
 return node
end
input.InputChanged=signal();input.InputEnded=signal()
local Input,GuiService=input,guiService
local Vector3={new=function(x,y,z)return{X=x or 0,Y=y or 0,Z=z or 0}end,zero={X=0,Y=0,Z=0}}
local CFrame={lookAt=function()return{}end}
-- TextService is unavailable outside Roblox. Keep a conservative deterministic
-- wrapped-text estimate; metadata calls out this native measurement boundary.
services.TextService={GetTextSize=function(_,text,size,_,bounds)
 local width=math.max(1,bounds.X);local lines=0
 for line in (text..'\n'):gmatch('(.-)\n')do
  local count=utf8.len(line)or #line
  lines+=math.max(1,math.ceil(count*size*.55/width))
 end
 return Vector2.new(width,math.max(1,lines)*size*1.2)
end}
local player=Instance.new('Player');player.UserId=101;player.DisplayName='James Bennett'
player:SetAttribute('SpyLanguage','ru')
local playerGui=Instance.new('PlayerGui');playerGui.Name='PlayerGui'
playerGui.AbsoluteSize=Vector2.new(WIDTH,HEIGHT);playerGui.Parent=player;player.PlayerGui=playerGui
local camera=Instance.new('Camera');camera.ViewportSize=playerGui.AbsoluteSize
local workspace={CurrentCamera=camera,GetServerTimeNow=function()return 100 end}
local Players={LocalPlayer=player,GetPlayerByUserId=function()return nil end}
local function send()error('Billiards preview cannot send gameplay actions')end
local function close()error('Billiards preview cannot run camera or interaction actions')end
'''

FIXTURE = r'''
-- Public illustrative state only. Server ball/scoring authority is not run.
snapshot={ok=true,revision=1,rackId=1,turnToken=1,mode='pool8',phase='aiming',
 turn=101,turnSeconds=60,deadline=128,shots=4,cueId=0,lowest=2,
 players={{id=101,name='James Bennett',score=3,group='solids'},
  {id=102,name='Alice Morgan',score=2,group='stripes'}},balls={},
 clubLeaderboard={entries={{name='James Bennett',score=38},{name='Alice Morgan',score=32}}}}
for id=0,15 do
 snapshot.balls[#snapshot.balls+1]={id=id,x=id*.1,z=0,pocketed=id==1 or id==3 or id==5 or id==9 or id==11}
end
opened=true;visualMode=snapshot.mode;angle=24.5;aimTarget=angle;aimChosen=true
if VARIANT=='mode'then
 snapshot.players={};snapshot.phase='waiting';snapshot.shots=0
elseif VARIANT=='result'then
 snapshot.phase='finished';snapshot.winner=101;snapshot.note='Восьмёрка забита после своей группы'
end
buildGui();updateHud()
if VARIANT=='mode'then showModePicker()
elseif VARIANT=='rules'then instructions.Visible=true end
layoutUI();updateHud()
'''


def excerpts(source: str | None = None) -> str:
    """Select current declarations and actual GUI code; missing markers fail."""
    source = CLIENT.read_text() if source is None else source
    state = between(source, "local snapshot,sequence,opened=", "local physicsModule=")
    state += between(source, "local prediction,ownMotion,localStroke=", "local audioFolder,audioLastId=")
    cancel = between(source, "local function cancelPull()", "local visualMode,sourceBalls,promptGui=")
    forwards = between(source, "local visualMode,sourceBalls,promptGui=", "local function cueBall()")
    canvas = between(source, "local function canvasSize()", "-- BILLIARDS_STYLE_BEGIN")
    permissions = between(source, "local function member()", "local function send(command,extra)")
    sections = [
        between(source, f"-- BILLIARDS_{name}_BEGIN", f"-- BILLIARDS_{name}_END")
        for name in ("STYLE", "HELPERS", "PRESENTATION")
    ]
    return "\n".join([state, cancel, forwards, canvas, permissions, *sections])


def assemble_harness(variant: str, width: int, height: int, appendix: str = "", *, source: str | None = None) -> str:
    """Build the shared geometry harness; tests may append same-scope assertions.

    ``appendix`` is trusted repository test code, never a CLI argument. The
    exporter itself appends the common node serializer after the real presenter.
    """
    if variant not in VARIANTS:
        raise ValueError(f"unknown billiards variant: {variant}")
    if width < 200 or height < 180:
        raise ValueError("preview viewport must be at least 200×180")
    prefix = STUB.read_text().split("local Catalog =", 1)[0]
    constants = f"\nlocal WIDTH,HEIGHT,VARIANT={width},{height},{json.dumps(variant)}\n"
    return prefix + constants + GUI_BOUNDARIES + BOUNDARIES + excerpts(source) + FIXTURE + appendix


def render(variant: str, width: int, height: int, output: Path) -> dict:
    """Write HTML, JSON and metadata from one execution of the current source."""
    source_bytes = CLIENT.read_bytes()
    harness = assemble_harness(variant, width, height, SERIALIZER, source=source_bytes.decode())
    with tempfile.TemporaryDirectory(prefix="spy-billiards-preview-") as directory:
        path = Path(directory) / "preview.luau"
        path.write_text(harness)
        runtime = os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau")
        result = subprocess.run([runtime, str(path)], capture_output=True, text=True, cwd=ROOT)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Luau billiards preview failed")
        layouts = [line.removeprefix("LAYOUT:") for line in result.stdout.splitlines() if line.startswith("LAYOUT:")]
        if len(layouts) != 1:
            raise RuntimeError(f"expected one billiards layout export, received {len(layouts)}")
        nodes = list(json.loads(layouts[0]).values())
    if not nodes:
        raise RuntimeError("billiards preview exported no visible GUI nodes")
    for node in nodes:
        if node["class"] == "ViewportFrame":
            node["placeholder"] = "NativeCueBall · Roblox Studio"
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.with_suffix(".json").write_text(json.dumps(nodes, ensure_ascii=False))
    write_html(output, nodes, width, height)
    # The shared writer already labels native viewports. Specialize that label
    # for this native cue-ball sphere without inventing rendered 3D content.
    output.write_text(output.read_text().replace("3D · Roblox Studio", "NativeCueBall · Roblox Studio"))
    metadata = {
        "variant": variant,
        "viewport": [width, height],
        "nodeCount": len(nodes),
        "renderer": "actual BilliardsClient GUI sections with explicit Roblox boundaries; not Studio",
        "sourceSha256": {
            str(CLIENT.relative_to(ROOT)): hashlib.sha256(source_bytes).hexdigest(),
            **{str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
               for path in (STUB, MATCH_RENDERER, Path(__file__).resolve())},
        },
        "boundaries": [
            "native Instance and services",
            "UIGridLayout and UISizeConstraint geometry from real properties",
            "TextService uses a conservative deterministic estimate; browser text is diagnostic",
            "native cue-ball viewport labelled NativeCueBall; no 3D rendering",
            "public sample state; no real physics, camera, input, networking or interaction claim",
            "gameplay and camera action attempts raise errors",
        ],
    }
    output.with_suffix(".metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2))
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("variant", choices=VARIANTS)
    parser.add_argument("--width", type=int, default=1440)
    parser.add_argument("--height", type=int, default=900)
    parser.add_argument("--output", type=Path, required=True, help="Diagnostic HTML; matching .json and .metadata.json are also written")
    args = parser.parse_args()
    if args.width < 200 or args.height < 180:
        parser.error("preview viewport must be at least 200×180")
    try:
        render(args.variant, args.width, args.height, args.output)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
        raise SystemExit(str(exc)) from exc
    print(args.output)


if __name__ == "__main__":
    main()
