#!/usr/bin/env python3
"""Exercise real daily/coin wallet rules independently in both places."""
from pathlib import Path
import os, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
harness=(ROOT/'tests/accessory_roll.spec.luau').read_text().split('local Catalog=loadModule("Catalog")')[0]
server=('Economy','Inventory','Daily','ClubProgress','Rewards','Cases','HighStakes','Profiles','AccessoryRollRules','AccessoryRollService')
shared=('Catalog','Preferences','AccessoryRollConfig','CharacterIdentity','DailyRewardConfig','ClubStoreConfig')
for place in ('lobby','match'):
    paths={n:ROOT/'src'/place/'ServerStorage/SpyModules'/f'{n}.luau' for n in server}
    paths.update({n:ROOT/'src'/place/'ReplicatedStorage/SpyShared'/f'{n}.luau' for n in shared})
    sources='local Sources={\n'+'\n'.join(f'{n}=[====[{p.read_text() if p.exists() else "return {}"}]====],' for n,p in paths.items())+'\n}\n'
    with tempfile.TemporaryDirectory(prefix='spy-collection-') as directory:
        target=Path(directory)/'collection.luau'
        target.write_text(sources+harness+(ROOT/'tests/club_collection.spec.luau').read_text())
        result=subprocess.run([os.environ.get('LUAU_BIN','/workspace/.spy-tools/bin/luau'),str(target)],cwd=ROOT)
        if result.returncode:raise SystemExit(result.returncode)
    print(place+': collection/rewards verified',flush=True)
