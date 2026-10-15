#!/usr/bin/env python3
"""Check live match folio presenters at the six supported review sizes."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SIZES = ((1440, 900), (1920, 1080), (360, 640), (280, 640), (360, 540), (844, 360))


def overlaps(a, b):
    return (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"]
            and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"])


checks = 0
with tempfile.TemporaryDirectory(prefix="spy-match-folio-") as directory:
    for width, height in SIZES:
        for variant, panel in (("hud", "MatchPhasePanel"), ("topic", "TopicPanel"),
                               ("result", "MatchResultPanel")):
            target = Path(directory) / f"{variant}-{width}-{height}.html"
            result = subprocess.run([
                sys.executable, str(ROOT / "tools/render_match_layout_preview.py"), variant,
                "--players", "7", "--width", str(width), "--height", str(height),
                "--output", str(target),
            ], cwd=ROOT, capture_output=True, text=True)
            assert result.returncode == 0, result.stderr + result.stdout
            nodes = json.loads(target.with_suffix(".json").read_text())
            named = {node["name"]: node for node in nodes}
            root = named[panel]
            assert root["x"] >= 0 and root["y"] >= 0, (variant, width, height)
            assert root["x"] + root["w"] <= width and root["y"] + root["h"] <= height
            checks += 3
            if variant == "hud":
                title, timer, task = (named[key] for key in ("StageTitle", "StageTimer", "StageInstruction"))
                assert not overlaps(title, timer), "The clock must leave the task heading readable"
                assert title["y"] + title["h"] <= task["y"], "Heading and guidance need separate lines"
                assert task["h"] >= task["fontSize"], "Guidance retains a readable line"
                assert all("PrivateRole" != n["name"] and "PrivateWord" != n["name"] for n in nodes)
                checks += 4
            elif variant == "topic":
                assert not overlaps(named["TopicHeading"], named["TopicTimer"]), "Theme heading clears the clock"
                assert len([n for n in nodes if n["name"] == "TopicChoice"]) == 4
                checks += 2
            else:
                reveal, reward, stats, content = (named[key] for key in ("PublicReveal", "RewardStatus", "SavedStats", "ResultContent"))
                assert len(reveal["text"].splitlines()) == 7, "Every public identity appears in the result"
                assert reveal["y"] + reveal["h"] < reward["y"], "The full reveal clears saved reward status"
                assert reward["y"] + reward["h"] <= stats["y"], "Reward and saved statistics have separate lines"
                scroll = max(0, content["canvasHeight"] - content["h"])
                footer = named["ReturnRoot"]
                assert content["y"] + content["h"] <= footer["y"] - 8, "The result scroll viewport reserves the pinned footer"
                for item in (reward, stats):
                    assert item["y"] + item["h"] - scroll <= footer["y"] - 8, "Reward and saved statistics scroll fully above the footer"
                    assert item["clip"]["bottom"] <= footer["y"] - 8, "Result content is clipped before the opaque footer"
                checks += 8

print(f"Match folio: {checks} assertions passed across six sizes (actual GUI excerpts; Studio was not run)")
