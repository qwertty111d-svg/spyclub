#!/usr/bin/env python3
"""Test the actual server eligibility helpers; Roblox Studio is not invoked."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ROUND_SOURCE = ROOT / "src/match/ServerScriptService/MatchRoundServer.server.luau"
RECONNECT_SOURCE = ROOT / "src/match/ServerStorage/SpyModules/ReconnectService.luau"


def extract(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin)]


def main():
    eligibility = extract(
        ROUND_SOURCE.read_text(),
        "local function eligibleForCompletedMatch(",
        "\nlocal function awardRoundRewards(",
    )
    participation = extract(
        RECONNECT_SOURCE.read_text(),
        "function Reconnect.newParticipation(",
        "-- Server-only recovery ledger",
    )
    tests = (ROOT / "tests/match_rewards.spec.luau").read_text()
    runtime = os.environ.get("LUAU_RUNTIME", os.environ.get("LUAU_BIN", "/workspace/.spy-tools/bin/luau"))
    with tempfile.TemporaryDirectory(prefix="spyclub-match-rewards-") as directory:
        harness = Path(directory) / "match_rewards.luau"
        harness.write_text(
            "local Reconnect = {}\nlocal Players = {}\nlocal round\n"
            + participation + eligibility + "\n" + tests
        )
        return subprocess.run([runtime, str(harness)], cwd=ROOT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
