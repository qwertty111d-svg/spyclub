#!/usr/bin/env python3
"""Run actual match luck verification with deterministic official-service stubs."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'src/match/ServerStorage/SpyModules/RollLuckService.luau'
source = path.read_text() if path.exists() else 'return {}'
config = (ROOT / 'src/match/ServerStorage/SpyModules/MonetizationConfig.luau').read_text()
shop = (ROOT / 'src/match/ReplicatedStorage/SpyShared/RollShopConfig.luau').read_text()
test = (ROOT / 'tests/roll_luck.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='spyclub-roll-luck-') as directory:
    bundle = Path(directory) / 'roll_luck.spec.luau'
    bundle.write_text('local serviceSource=[====[' + source + ']====]\n'
                      + 'local configSource=[====[' + config + ']====]\n'
                      + 'local shopConfigSource=[====[' + shop + ']====]\n' + test)
    runtime = os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau')
    raise SystemExit(subprocess.run([runtime, str(bundle)], cwd=ROOT).returncode)
