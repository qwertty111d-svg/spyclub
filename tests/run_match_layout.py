#!/usr/bin/env python3
"""Check actual match HUD geometry without claiming a Roblox render test."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/match/ReplicatedStorage/SpyShared/MatchHUD.luau").read_text()
tests = (ROOT / "tests/match_layout.spec.luau").read_text()
delimiter = "===="
while "]" + delimiter + "]" in source:
    delimiter += "="
with tempfile.TemporaryDirectory(prefix="spyclub-match-layout-") as directory:
    harness = Path(directory) / "layout.luau"
    harness.write_text("local hudSource = [" + delimiter + "[" + source + "]" + delimiter + "]\n" + tests)
    raise SystemExit(subprocess.run([os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(harness)], cwd=ROOT).returncode)
