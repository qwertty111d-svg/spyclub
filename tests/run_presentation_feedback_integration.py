#!/usr/bin/env python3
"""Execute both presentation bootstraps and real typography callbacks."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def quote(source):
    delimiter = "===="
    while "]" + delimiter + "]" in source:
        delimiter += "="
    return "[" + delimiter + "[" + source + "]" + delimiter + "]"


sources = {}
for place in ("lobby", "match"):
    base = ROOT / "src" / place
    sources[place + "Presentation"] = (
        base / "ReplicatedStorage/SpyShared/Presentation.luau"
    ).read_text()
    sources[place + "Bootstrap"] = (
        base / "StarterPlayer/StarterPlayerScripts/PresentationClient.client.luau"
    ).read_text()
prefix = "local Sources={\n" + "\n".join(
    f"{name}={quote(source)}," for name, source in sources.items()
) + "\n}\n"
with tempfile.TemporaryDirectory(prefix="spyclub-feedback-integration-") as directory:
    harness = Path(directory) / "integration.luau"
    harness.write_text(prefix + (
        ROOT / "tests/presentation_feedback_integration.spec.luau"
    ).read_text())
    result = subprocess.run([
        os.environ.get("LUAU_RUNTIME", "/workspace/.spy-tools/bin/luau"), str(harness)
    ], cwd=ROOT)

legacy = {
    "lobby/StarterPlayer/StarterPlayerScripts/SpyClient.client.luau":
        ("hookLobbyAudioButton", "lobbyAudioButtons"),
    "match/StarterPlayer/StarterPlayerScripts/MatchIntroClient.client.luau":
        ("hookAudioButton", "hookedAudioButtons"),
}
retired = True
for relative, names in legacy.items():
    source = (ROOT / "src" / relative).read_text()
    for name in names:
        if name in source:
            print(f"FAIL: duplicate legacy button audio binding remains: {relative}: {name}")
            retired = False
raise SystemExit(result.returncode or (0 if retired else 1))
