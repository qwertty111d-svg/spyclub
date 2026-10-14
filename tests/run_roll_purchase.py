#!/usr/bin/env python3
"""Run actual shop/receipt Luau modules with explicit Roblox boundary stubs.

Both place implementations run independently. This is not a Studio Play test.
"""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TEST = (ROOT / "tests/roll_purchase.spec.luau").read_text()
CLI = os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau")
SERVER_MODULES = (
    "Monetization", "MonetizationConfig", "Profiles", "Economy", "Inventory",
    "Daily", "ClubProgress", "Rewards", "Cases", "HighStakes", "AccessoryRollRules",
)
SHARED_MODULES = (
    "RollShopConfig", "Catalog", "Preferences", "AccessoryRollConfig",
    "CharacterIdentity",
)

for place in ("lobby", "match"):
    modules = {
        name: ROOT / "src" / place / "ServerStorage/SpyModules" / f"{name}.luau"
        for name in SERVER_MODULES
    }
    modules.update({
        name: ROOT / "src" / place / "ReplicatedStorage/SpyShared" / f"{name}.luau"
        for name in SHARED_MODULES
    })
    sources = "local Sources = {\n" + "\n".join(
        f"{name}=[====[{path.read_text()}]====],"
        for name, path in modules.items() if path.exists()
    ) + "\n}\n"
    with tempfile.TemporaryDirectory(prefix=f"spyclub-{place}-purchase-tests-") as folder:
        bundle = Path(folder) / "actual_roll_purchase.spec.luau"
        bundle.write_text(sources + f'local PlaceName = "{place}"\n' + TEST)
        result = subprocess.run([CLI, str(bundle)], cwd=ROOT, text=True)
        if result.returncode:
            raise SystemExit(result.returncode)
