#!/usr/bin/env python3
"""Exercise real settings/journal modules; Roblox rendering stays a boundary."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
prefix = (ROOT / 'tests/dossier_ui.spec.luau').read_text().split('local Catalog =')[0]
names = ('SettingsUI', 'ClubJournalUI')
sources = 'local Sources={\n' + '\n'.join(
    f'{name}=[====[{(ROOT / "src/lobby/ReplicatedStorage/SpyShared" / (name + ".luau")).read_text()}]====],'
    for name in names
) + '\n}\n'
assert (ROOT / 'src/lobby/ReplicatedStorage/SpyShared/SettingsUI.luau').read_bytes() == (
    ROOT / 'src/match/ReplicatedStorage/SpyShared/SettingsUI.luau'
).read_bytes(), 'Both active SettingsUI modules must stay equal'
with tempfile.TemporaryDirectory(prefix='spy-personal-panels-') as directory:
    target = Path(directory) / 'personal.luau'
    target.write_text(prefix + sources + (ROOT / 'tests/personal_panels.spec.luau').read_text())
    raise SystemExit(subprocess.run([
        os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)
    ], cwd=ROOT).returncode)
