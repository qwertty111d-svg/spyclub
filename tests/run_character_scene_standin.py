#!/usr/bin/env python3
"""Execute the match world stand-in with shared immutable Roblox math stubs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    prefix = (ROOT / "tests/native_portrait.spec.luau").read_text().split("-- INSERT_REAL_PREVIEW3D_MODULE")[0]
    checks = (ROOT / "tests/character_scene_standin.spec.luau").read_text()
    source = (ROOT / "src/match/ReplicatedStorage/SpyShared/CharacterSceneStandIn.luau").read_text()
    marker = "-- CHARACTER_SCENE_STAND_IN_SOURCE_INSERT"
    assert checks.count(marker) == 1
    harness = prefix + checks.replace(marker, "local StandIn=(function()\n" + source + "\nend)()")
    with tempfile.TemporaryDirectory(prefix="spy-character-standin-") as directory:
        target = Path(directory) / "standin.luau"
        target.write_text(harness)
        return subprocess.run([os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau"), str(target)], cwd=ROOT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
