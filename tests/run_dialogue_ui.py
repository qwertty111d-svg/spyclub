#!/usr/bin/env python3
"""Run real Vincent dialogue/resale modules with documented native UI boundaries."""
from pathlib import Path
import os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
names=('Catalog','ClubStoreConfig','ClubJournalUI','DialogueUI','I18n')
with tempfile.TemporaryDirectory(prefix='spy-vincent-ui-')as directory:
 for place in ('lobby','match'):
  # Match retains a compatibility DialogueUI copy; its lobby-only journal
  # dependency uses the real lobby source at this explicit module boundary.
  def module_source(name):
   path=ROOT/'src'/place/'ReplicatedStorage/SpyShared'/(name+'.luau')
   if not path.exists():path=ROOT/'src/lobby/ReplicatedStorage/SpyShared'/(name+'.luau')
   return path.read_text()
  sources='local Sources={\n'+'\n'.join(f'{n}=[====[{module_source(n)}]====],' for n in names)+'\n}\n'
  target=Path(directory)/(place+'-dialogue.luau');target.write_text(prefix+sources+(ROOT/'tests/dialogue_ui.spec.luau').read_text())
  print('Vincent dialogue checks: '+place,flush=True)
  result=subprocess.run([os.environ.get('LUAU_BIN','/workspace/.spy-tools/bin/luau'),str(target)],cwd=ROOT)
  if result.returncode:raise SystemExit(result.returncode)
