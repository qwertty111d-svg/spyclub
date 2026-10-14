#!/usr/bin/env python3
"""Exercise the actual dossier lifecycle and geometry with Roblox GUI stubs."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
relative = Path('ReplicatedStorage/SpyShared/AccessoryRollUI.luau')
source = (ROOT / 'src/lobby' / relative).read_text()
if source != (ROOT / 'src/match' / relative).read_text():
    raise SystemExit('Lobby and match dossier UI implementations differ')
template = (ROOT / 'tests/dossier_ui.spec.luau').read_text()
odds=(ROOT/'src/lobby/ReplicatedStorage/SpyShared/RollOdds.luau').read_text()
template=template.replace('local function loadModule()', 'modules.RollOdds=(function()\n'+odds+'\nend)()\nlocal function loadModule()')
if template.count('-- DOSSIER_SOURCE_INSERT') != 1:
    raise SystemExit('Dossier test source insertion marker is invalid')
with tempfile.TemporaryDirectory(prefix='spyclub-dossier-ui-') as directory:
    target = Path(directory) / 'ui.luau'
    target.write_text(template.replace('-- DOSSIER_SOURCE_INSERT', source))
    result = subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT)
    raise SystemExit(result.returncode)
