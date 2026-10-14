#!/usr/bin/env python3
"""Exercise actual lower-HUD owners with SpyClient/MatchIntro integration excerpts."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
prefix = (ROOT / 'tests/dossier_ui.spec.luau').read_text().split('local Catalog =')[0]
client = (ROOT / 'src/lobby/StarterPlayer/StarterPlayerScripts/SpyClient.client.luau').read_text()
quick_setup = client[client.index('local QUICK_CHAT_ORDER='):client.index('local function resize()', client.index('local QUICK_CHAT_ORDER='))]
quick_layout = client[client.index('local function resize()', client.index('local QUICK_CHAT_ORDER=')):client.index('\thintRail.Position=', client.index('local QUICK_CHAT_ORDER='))] + '\nend\n'
intro = (ROOT / 'src/match/StarterPlayer/StarterPlayerScripts/MatchIntroClient.client.luau').read_text()
utilities = intro[intro.index('matchUI.controls=make('):intro.index('matchUI.viewShortcut=')]
utilities += intro[intro.index(' matchUI.cardShortcut.Position='):intro.index(' matchUI.phaseSubtitle.TextWrapped=')]
sources = {
    'LobbyHUD': (ROOT / 'src/lobby/ReplicatedStorage/SpyShared/HudController.luau').read_text(),
    'MatchHUD': (ROOT / 'src/match/ReplicatedStorage/SpyShared/MatchHUD.luau').read_text(),
    'QuickChatSetup': quick_setup,
    'QuickChatLayout': quick_layout,
    'MatchUtilities': utilities,
}
with tempfile.TemporaryDirectory(prefix='spy-lower-hud-') as directory:
    target = Path(directory) / 'lower.luau'
    encoded = 'local Sources={\n' + '\n'.join(f'{key}=[====[{value}]====],' for key, value in sources.items()) + '\n}\n'
    target.write_text(prefix + encoded + (ROOT / 'tests/lower_hud.spec.luau').read_text())
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT).returncode)
