#!/usr/bin/env python3
"""Exercise actual match portrait setup and local visibility; no native rendering."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from test_lobby_environment import STUBS


def main():
    source = (ROOT / "src/match/ReplicatedStorage/SpyShared/MatchPresentation.luau").read_text()
    checks = (ROOT / "tests/match_portraits.spec.luau").read_text()
    harness = STUBS + "\nlocal Presentation=(function()\n" + source + "\nend)()\n" + checks
    with tempfile.TemporaryDirectory(prefix="spy-match-portraits-") as directory:
        path = Path(directory) / "portraits.luau"
        path.write_text(harness)
        return subprocess.run([
            os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(path)
        ], cwd=ROOT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
