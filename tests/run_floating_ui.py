#!/usr/bin/env python3
"""Execute the actual floating controller with deterministic input/frame stubs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/lobby/ReplicatedStorage/SpyShared/FloatingUIController.luau").read_text()
tests = (ROOT / "tests/floating_ui.spec.luau").read_text()
delimiter = "===="
while "]" + delimiter + "]" in source:
    delimiter += "="
with tempfile.TemporaryDirectory(prefix="spyclub-floating-ui-") as directory:
    harness = Path(directory) / "floating_ui.luau"
    harness.write_text("local controllerSource = [" + delimiter + "[" + source + "]" + delimiter + "]\n" + tests)
    raise SystemExit(subprocess.run([os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(harness)], cwd=ROOT).returncode)
