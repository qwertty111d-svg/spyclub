#!/usr/bin/env python3
"""Exercise the actual layered phone UI with Roblox GUI service boundaries."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
prefix = (ROOT / 'tests/dossier_ui.spec.luau').read_text().split('local Catalog =')[0]
names = ('PhoneState', 'PhoneUI', 'PhoneSocial', 'PhoneConnectUI')
sources = {}
for name in names:
    relative = Path('ReplicatedStorage/SpyShared') / (name + '.luau')
    sources[name] = (ROOT / 'src/lobby' / relative).read_text()
    if sources[name] != (ROOT / 'src/match' / relative).read_text():
        raise SystemExit(f'Phone module copies differ: {name}')
encoded = 'local Sources={\n' + '\n'.join(f'{name}=[====[{source}]====],' for name, source in sources.items()) + '\n}\n'
with tempfile.TemporaryDirectory(prefix='spy-phone-ui-') as directory:
    target = Path(directory) / 'phone.luau'
    target.write_text(prefix + encoded + (ROOT / 'tests/phone_ui.spec.luau').read_text())
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT).returncode)
