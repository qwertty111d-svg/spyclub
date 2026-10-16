#!/usr/bin/env python3
"""Exercise the actual lobby trade script through Roblox GUI/service boundaries."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
prefix = (ROOT / 'tests/dossier_ui.spec.luau').read_text().split('local Catalog =')[0]
source = (ROOT / 'src/lobby/StarterPlayer/StarterPlayerScripts/TradeUI.client.luau').read_text()
fixture = (ROOT / 'tests/trade_ui.spec.luau').read_text()
bootstrap, assertions = fixture.split('-- TRADE_ASSERTIONS_INSERT\n', 1)
source = source.replace('-- TRADE_UI_FIXTURE_INSERT\ncameraChanged();connectShared();request("sync")', assertions)
with tempfile.TemporaryDirectory(prefix='spy-trade-ui-') as directory:
    target = Path(directory) / 'trade.luau'
    target.write_text(prefix + bootstrap + source)
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT).returncode)
