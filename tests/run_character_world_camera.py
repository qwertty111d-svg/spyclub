#!/usr/bin/env python3
"""Execute both real world-camera modules against Roblox engine-boundary stubs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    prefix = (ROOT / "tests/native_portrait.spec.luau").read_text().split("-- INSERT_REAL_PREVIEW3D_MODULE")[0]
    checks = (ROOT / "tests/character_world_camera.spec.luau").read_text()
    marker = "-- CHARACTER_WORLD_CAMERA_SOURCE_INSERT"
    assert checks.count(marker) == 1
    with tempfile.TemporaryDirectory(prefix="spy-world-camera-") as directory:
        for place in ("lobby", "match"):
            source = (ROOT / f"src/{place}/ReplicatedStorage/SpyShared/CharacterWorldCamera.luau").read_text()
            harness = prefix + checks.replace(marker, "local CharacterWorldCamera=(function()\n" + source + "\nend)()")
            target = Path(directory) / f"{place}_world_camera.luau"
            target.write_text(harness)
            print(f"Checking {place} world character camera", flush=True)
            result = subprocess.run([os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau"), str(target)], cwd=ROOT)
            if result.returncode:
                return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
