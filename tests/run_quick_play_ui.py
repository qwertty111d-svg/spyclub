#!/usr/bin/env python3
"""Exercise actual QuickPlay choices, queue callbacks and responsive geometry."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
prefix = (ROOT / 'tests/dossier_ui.spec.luau').read_text().split('local Catalog =')[0]
sources = {
    'QuickPlay': (ROOT / 'src/lobby/StarterPlayer/StarterPlayerScripts/QuickPlayClient.client.luau').read_text(),
    'Files': (ROOT / 'src/lobby/ReplicatedStorage/SpyShared/CaseFiles.luau').read_text(),
}
encoded = 'local Sources={\n' + '\n'.join(f'{key}=[====[{value}]====],' for key, value in sources.items()) + '\n}\n'
with tempfile.TemporaryDirectory(prefix='spy-quick-play-ui-') as directory:
    target = Path(directory) / 'quick.luau'
    target.write_text(prefix + encoded + (ROOT / 'tests/quick_play_ui.spec.luau').read_text())
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT).returncode)
