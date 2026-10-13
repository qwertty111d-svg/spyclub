#!/usr/bin/env python3
"""Run actual Luau modules with explicit Roblox API stubs, never a Play Test."""
from pathlib import Path
import subprocess
import tempfile
import os

ROOT = Path(__file__).resolve().parents[1]
LOBBY = ROOT / 'src/lobby'
MODULES = {}
for name in ('Economy', 'Inventory', 'Daily', 'ClubProgress', 'Rewards', 'Cases',
             'HighStakes', 'Profiles', 'AccessoryRollRules', 'AccessoryRollService'):
    MODULES[name] = LOBBY / 'ServerStorage/SpyModules' / (name + '.luau')
for name in ('Catalog', 'Preferences', 'AccessoryRollConfig', 'CharacterIdentity'):
    MODULES[name] = LOBBY / 'ReplicatedStorage/SpyShared' / (name + '.luau')

sources = 'local Sources = {\n' + '\n'.join(
    f'{name}=[====[{path.read_text()}]====],' for name, path in MODULES.items()
) + '\n}\n'
test = (ROOT / 'tests/accessory_roll.spec.luau').read_text()
cli = os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau')
with tempfile.TemporaryDirectory(prefix='spyclub-roll-tests-') as folder:
    bundle = Path(folder) / 'actual_modules.spec.luau'
    bundle.write_text(sources + test)
    result = subprocess.run([cli, str(bundle)], cwd=ROOT, text=True)
    raise SystemExit(result.returncode)
