#!/usr/bin/env python3
"""Exercise actual premium pricing, controls and prompt/receipt lifecycle."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
prefix=(ROOT/'tests/dossier_ui.spec.luau').read_text().split('local function loadModule()')[0]
paths={
    'PremiumShopRules':ROOT/'src/lobby/ReplicatedStorage/SpyShared/PremiumShopRules.luau',
    'PremiumRollShopUI':ROOT/'src/lobby/ReplicatedStorage/SpyShared/PremiumRollShopUI.luau',
}
sources='local Sources={\n'+'\n'.join(f'{name}=[====[{path.read_text() if path.exists() else "return {}"}]====],' for name,path in paths.items())+'\n}\n'
with tempfile.TemporaryDirectory(prefix='spy-premium-shop-') as directory:
    target=Path(directory)/'premium.luau'
    target.write_text(prefix+sources+(ROOT/'tests/premium_shop.spec.luau').read_text())
    raise SystemExit(subprocess.run([os.environ.get('LUAU_BIN','/workspace/.spy-tools/bin/luau'),str(target)],cwd=ROOT).returncode)
