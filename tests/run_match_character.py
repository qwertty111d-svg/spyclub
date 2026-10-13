#!/usr/bin/env python3
"""Execute the actual match dossier client against minimal Roblox service stubs."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    '-- MATCH_CHARACTER_SOURCE_INSERT': ROOT / 'src/match/StarterPlayer/StarterPlayerScripts/MatchCharacterClient.client.luau',
    '-- DOSSIER_POLICY_SOURCE_INSERT': ROOT / 'src/match/ReplicatedStorage/SpyShared/DossierPolicy.luau',
}

template = (ROOT / 'tests/match_character.spec.luau').read_text()
for marker, path in SOURCES.items():
    if template.count(marker) != 1:
        raise SystemExit(f'Match character test source insertion marker is invalid: {marker}')
    template = template.replace(marker, path.read_text())
with tempfile.TemporaryDirectory(prefix='spyclub-match-character-') as directory:
    target = Path(directory) / 'match_character.luau'
    target.write_text(template)
    result = subprocess.run(
        [os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT
    )
    raise SystemExit(result.returncode)
