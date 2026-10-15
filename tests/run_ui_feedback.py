#!/usr/bin/env python3
"""Execute both real UIFeedback scene copies with Roblox engine boundaries."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    checks = (ROOT / "tests/ui_feedback.spec.luau").read_text()
    marker = "-- INSERT_REAL_UIFEEDBACK_MODULE"
    if checks.count(marker) != 1:
        raise ValueError("UI feedback spec must contain exactly one module marker")
    result = 0
    with tempfile.TemporaryDirectory(prefix="spy-ui-feedback-") as directory:
        for place in ("lobby", "match"):
            module = ROOT / f"src/{place}/ReplicatedStorage/SpyShared/UIFeedback.luau"
            if not module.exists():
                print(f"FAIL: {place}: UIFeedback module does not exist", flush=True)
                result = 1
                continue
            source = module.read_text()
            harness = checks.replace(marker, "local UIFeedback=(function()\n" + source + "\nend)()")
            path = Path(directory) / f"{place}_ui_feedback.luau"
            path.write_text(harness)
            print(f"UI feedback checks: {place}", flush=True)
            completed = subprocess.run([
                os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(path)
            ], cwd=ROOT)
            if completed.returncode:
                result = completed.returncode
    return result


if __name__ == "__main__":
    raise SystemExit(main())
