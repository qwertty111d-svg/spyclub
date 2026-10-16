#!/usr/bin/env python3
"""Execute both real world-camera modules against Roblox engine-boundary stubs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def scene_checks(place):
    source = (ROOT / f"src/{place}/ReplicatedStorage/SpyShared/AccessoryRollUI.luau").read_text()
    fixture = (ROOT / "tests/character_close_ui.spec.luau").read_text()
    sections = {
        "-- CHARACTER_CLOSE_RELEASE_SCENE_SOURCE_INSERT": (
            "    local function releaseScene()", "    local function panePosition("),
        "-- CHARACTER_CLOSE_FINISH_SOURCE_INSERT": (
            "    finishClose = function(token, immediate)", "    worldCamera = CharacterWorldCamera.create("),
        "-- CHARACTER_CLOSE_METHOD_SOURCE_INSERT": (
            "    function self:close(animated)", "    function self:receive(receipt, requestId)"),
        "-- CHARACTER_CLOSE_UNAVAILABLE_SOURCE_INSERT": (
            "        local function sceneUnavailable(reason)", "        local succeeded, accepted = xpcall("),
    }
    for marker, (start, end) in sections.items():
        assert fixture.count(marker) == 1, f"Invalid character close source insertion marker: {marker}"
        begin = source.index(start)
        fixture = fixture.replace(marker, source[begin:source.index(end, begin)])
    return fixture


def build_harness(place):
    prefix = (ROOT / "tests/native_portrait.spec.luau").read_text().split("-- INSERT_REAL_PREVIEW3D_MODULE")[0]
    checks = (ROOT / "tests/character_world_camera.spec.luau").read_text()
    marker = "-- CHARACTER_WORLD_CAMERA_SOURCE_INSERT"
    cleanup = 'for _,scene in ipairs(controllers)do scene:destroy()end\nprint('
    assert checks.count(marker) == 1
    assert checks.count(cleanup) == 1
    checks = checks.replace(cleanup, scene_checks(place) + "\n" + cleanup)
    source = (ROOT / f"src/{place}/ReplicatedStorage/SpyShared/CharacterWorldCamera.luau").read_text()
    return prefix + checks.replace(marker, "local CharacterWorldCamera=(function()\n" + source + "\nend)()")


def main():
    with tempfile.TemporaryDirectory(prefix="spy-world-camera-") as directory:
        for place in ("lobby", "match"):
            target = Path(directory) / f"{place}_world_camera.luau"
            target.write_text(build_harness(place))
            print(f"Checking {place} world character camera", flush=True)
            result = subprocess.run([os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau"), str(target)], cwd=ROOT)
            if result.returncode:
                return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
