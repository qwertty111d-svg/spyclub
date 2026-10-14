#!/usr/bin/env python3
"""Exercise the actual DailyUI and ModalUI with minimal Roblox GUI boundaries."""
from pathlib import Path
import os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
names=('DailyRewardConfig','ClubStoreConfig','ModalUI','DailyUI')
sources='local Sources={\n'+'\n'.join(f'{n}=[====[{(ROOT/"src/lobby/ReplicatedStorage/SpyShared"/(n+".luau")).read_text()}]====],' for n in names)+'\n}\n'
with tempfile.TemporaryDirectory(prefix='spy-daily-gui-') as d:
    target=Path(d)/'daily.luau';target.write_text(prefix+sources+(ROOT/'tests/daily_ui.spec.luau').read_text())
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN','/workspace/.spy-tools/bin/luau'),str(target)],cwd=ROOT).returncode)
