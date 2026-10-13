#!/usr/bin/env python3
"""Exercise the actual pure match guidance module without Roblox services."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/match/ReplicatedStorage/SpyShared/MatchGuide.luau").read_text()
tests = (ROOT / "tests/match_presentation.spec.luau").read_text()
delimiter = "===="
while "]" + delimiter + "]" in source:
    delimiter += "="
with tempfile.TemporaryDirectory(prefix="spyclub-match-presentation-") as directory:
    harness = Path(directory) / "match_presentation.luau"
    harness.write_text("local guideSource = [" + delimiter + "[" + source + "]" + delimiter + "]\n" + tests)
    raise SystemExit(subprocess.run([
        os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(harness)
    ], cwd=ROOT).returncode)
