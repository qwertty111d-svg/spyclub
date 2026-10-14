#!/usr/bin/env python3
"""Execute real identity/economy/profile modules with Roblox service stubs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
# Reuse the existing datastore/asset stub harness; assertions below test real rules.
harness = (ROOT / 'tests/accessory_roll.spec.luau').read_text().split(
    'local Catalog=loadModule("Catalog")', 1
)[0]
test = (ROOT / 'tests/identity_roll.spec.luau').read_text()
runtime = os.environ.get('LUAU_RUNTIME', os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'))
for place in ('lobby', 'match'):
    source_root = ROOT / 'src' / place
    modules = {}
    for name in ('Economy', 'Inventory', 'Daily', 'ClubProgress', 'Rewards', 'Cases',
                 'HighStakes', 'Profiles', 'AccessoryRollRules', 'AccessoryRollService'):
        modules[name] = source_root / 'ServerStorage/SpyModules' / (name + '.luau')
    for name in ('Catalog', 'Preferences', 'AccessoryRollConfig', 'CharacterIdentity', 'DailyRewardConfig', 'ClubStoreConfig'):
        modules[name] = source_root / 'ReplicatedStorage/SpyShared' / (name + '.luau')
    sources = 'local Sources = {\n' + '\n'.join(
        f'{name}=[====[{path.read_text()}]====],' for name, path in modules.items()
    ) + '\n}\n'
    with tempfile.TemporaryDirectory(prefix=f'spyclub-{place}-identity-tests-') as folder:
        bundle = Path(folder) / 'identity.spec.luau'
        bundle.write_text(sources + harness + test)
        result = subprocess.run([runtime, str(bundle)], cwd=ROOT)
        if result.returncode:
            raise SystemExit(result.returncode)
    print(f'{place}: identity contract verified', flush=True)
