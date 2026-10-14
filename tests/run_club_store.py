#!/usr/bin/env python3
"""Run actual collection store GUI with explicit Roblox rendering boundaries."""
from pathlib import Path
import os, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
names=('ClubStoreConfig','ClubStoreUI','PremiumShopRules')
sources='local Sources={\n'+'\n'.join(f'{n}=[====[{(ROOT/"src/lobby/ReplicatedStorage/SpyShared"/(n+".luau")).read_text() if (ROOT/"src/lobby/ReplicatedStorage/SpyShared"/(n+".luau")).exists() else "return {}"}]====],' for n in names)+'\n}\n'
with tempfile.TemporaryDirectory(prefix='spy-store-gui-') as directory:
    target=Path(directory)/'store.luau'
    target.write_text(prefix+sources+(ROOT/'tests/club_store.spec.luau').read_text())
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN','/workspace/.spy-tools/bin/luau'),str(target)],cwd=ROOT).returncode)
