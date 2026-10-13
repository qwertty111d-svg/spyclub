#!/usr/bin/env python3
"""Exercise real request/input rules in Luau; no Roblox rendering claim."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
paths = {
    'PreferencesServer': ROOT / 'src/match/ServerStorage/SpyModules/PreferencesServer.luau',
    'Preferences': ROOT / 'src/match/ReplicatedStorage/SpyShared/Preferences.luau',
    'DossierPolicy': ROOT / 'src/lobby/ReplicatedStorage/SpyShared/DossierPolicy.luau',
}
sources = 'local Sources = {\n' + '\n'.join(
    f'{name}=[====[{path.read_text() if path.exists() else "return {}"}]====],'
    for name, path in paths.items()
) + '\n}\n'
with tempfile.TemporaryDirectory(prefix='spy-dossier-controls-') as directory:
    target = Path(directory) / 'controls.luau'
    target.write_text(sources + (ROOT / 'tests/dossier_controls.spec.luau').read_text())
    result = subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT)
    raise SystemExit(result.returncode)
