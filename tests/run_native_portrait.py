#!/usr/bin/env python3
"""Run the real NPC portrait helper with isolated Roblox engine boundaries.

This checks cloning, framing math and lifecycle; Roblox Studio must validate
native mesh/clothing rendering and the final visual composition.
"""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    checks = (ROOT / "tests/native_portrait.spec.luau").read_text()
    marker = "-- INSERT_REAL_PREVIEW3D_MODULE"
    if checks.count(marker) != 1:
        raise ValueError("native portrait spec must contain exactly one module marker")
    result = 0
    with tempfile.TemporaryDirectory(prefix="spy-native-portrait-") as directory:
        for place in ("lobby", "match"):
            source = (ROOT / f"src/{place}/ReplicatedStorage/SpyShared/Preview3D.luau").read_text()
            harness = checks.replace(marker, "local Preview3D=(function()\n" + source + "\nend)()")
            path = Path(directory) / f"{place}_native_portrait.luau"
            path.write_text(harness)
            print(f"Native portrait checks: {place}", flush=True)
            completed = subprocess.run([
                os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(path)
            ], cwd=ROOT)
            if completed.returncode:
                result = completed.returncode
    return result


if __name__ == "__main__":
    raise SystemExit(main())
