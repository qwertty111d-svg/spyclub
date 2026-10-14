#!/usr/bin/env python3
"""Exercise actual rotating playlist behavior, with sound delivery stubbed."""
from pathlib import Path
import os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
names=('ClubMusicConfig','ClubMusicPlaylist')
sources='local Sources={\n'+'\n'.join(f'{n}=[====[{p.read_text() if p.exists() else "return {}"}]====],' for n in names for p in [ROOT/'src/lobby/ReplicatedStorage/SpyShared'/f'{n}.luau'])+'\n}\n'
intro=(ROOT/'src/match/StarterPlayer/StarterPlayerScripts/MatchIntroClient.client.luau').read_text()
audio_setup=intro[intro.index('local oldAudioRoot ='):intro.index('-- Essential match transport')]
sources+='Sources.MatchAudioSetup=[====['+audio_setup+']====]\n'
with tempfile.TemporaryDirectory(prefix='spy-music-') as d:
    target=Path(d)/'music.luau';target.write_text(prefix+sources+(ROOT/'tests/club_music.spec.luau').read_text())
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN','/workspace/.spy-tools/bin/luau'),str(target)],cwd=ROOT).returncode)
