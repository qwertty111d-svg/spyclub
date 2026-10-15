#!/usr/bin/env python3
"""Run real Vincent dialogue/resale modules with documented native UI boundaries."""
from pathlib import Path
import os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
names=('Catalog','ClubStoreConfig','ClubJournalUI','DialogueUI','I18n')
sources='local Sources={\n'+'\n'.join(f'{n}=[====[{(ROOT/"src/lobby/ReplicatedStorage/SpyShared"/(n+".luau")).read_text()}]====],' for n in names)+'\n}\n'
with tempfile.TemporaryDirectory(prefix='spy-vincent-ui-')as directory:
 target=Path(directory)/'dialogue.luau';target.write_text(prefix+sources+(ROOT/'tests/dialogue_ui.spec.luau').read_text())
 raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN','/workspace/.spy-tools/bin/luau'),str(target)],cwd=ROOT).returncode)
