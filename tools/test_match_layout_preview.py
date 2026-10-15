#!/usr/bin/env python3
"""Check that match diagnostics expose real current UI and usable key geometry."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    "hud": ("MatchPhasePanel", "ReadyRoot", "ShowRoleCard", "OpenTableChat"),
    "topic": ("TopicPanel",),
    "vote": ("BallotPanel", "Suspect_102", "Suspect_103", "Suspect_104", "SubmitBallot"),
    "result": ("MatchResultPanel", "ReturnLobbyButton", "RematchButton", "RewardStatus"),
}


class MatchLayoutPreviewTests(unittest.TestCase):
    def test_desktop_and_phone_actual_presenters(self):
        with tempfile.TemporaryDirectory(prefix="spy-match-preview-test-") as directory:
            for variant, required in REQUIRED.items():
                for width, height in ((1440, 900), (360, 640), (844, 360)):
                    with self.subTest(variant=variant, viewport=(width, height)):
                        target = Path(directory) / f"{variant}-{width}.html"
                        result = subprocess.run(
                            [sys.executable, str(ROOT / "tools/render_match_layout_preview.py"), variant,
                             "--width", str(width), "--height", str(height), "--output", str(target)],
                            cwd=ROOT, capture_output=True, text=True,
                        )
                        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                        self.assertTrue(target.read_text().startswith("<!doctype html>"))
                        nodes = json.loads(target.with_suffix(".json").read_text())
                        named = {node["name"]: node for node in nodes}
                        metadata = json.loads(target.with_suffix(".metadata.json").read_text())
                        self.assertEqual(metadata["viewport"], [width, height])
                        self.assertEqual(metadata["variant"], variant)
                        self.assertEqual(metadata["nodeCount"], len(nodes))
                        for source, digest in metadata["sourceSha256"].items():
                            self.assertEqual(hashlib.sha256((ROOT / source).read_bytes()).hexdigest(), digest)
                        for name in required:
                            self.assertIn(name, named)
                            node = named[name]
                            self.assertGreaterEqual(node["x"], -.01, name)
                            self.assertGreaterEqual(node["y"], -.01, name)
                            self.assertLessEqual(node["x"] + node["w"], width + .01, name)
                            self.assertLessEqual(node["y"] + node["h"], height + .01, name)
                            if node["class"] == "TextButton":
                                self.assertGreaterEqual(node["h"], 44, name)
                        if variant == "hud":
                            title, instruction = named["StageTitle"], named["StageInstruction"]
                            self.assertLessEqual(title["y"] + title["h"], instruction["y"],
                                                 "phase title clears its task instruction")
                            self.assertGreaterEqual(instruction["h"], instruction["fontSize"],
                                                    "task instruction keeps a full text line")
                            primary, card, chat = (named[k] for k in ("ReadyRoot", "ShowRoleCard", "OpenTableChat"))
                            self.assertLessEqual(primary["x"] + primary["w"], card["x"])
                            self.assertLessEqual(card["x"] + card["w"], chat["x"])
                            self.assertTrue(all("Шпион" not in n["text"] and "Агент" not in n["text"] for n in nodes))
                        if variant == "vote":
                            # Native avatars are labelled placeholders, and all
                            # suspect rows have distinct grid cells in real order.
                            self.assertEqual(sum(n["class"] == "ViewportFrame" for n in nodes), 3)
                            suspects = [named[f"Suspect_{uid}"] for uid in (102, 103, 104)]
                            for first, second in zip(suspects, suspects[1:]):
                                self.assertTrue(first["x"] + first["w"] <= second["x"] + .01 or
                                                first["y"] + first["h"] <= second["y"] + .01)
                        if variant == "result":
                            lobby, rematch = named["ReturnLobbyButton"], named["RematchButton"]
                            self.assertLess(rematch["x"] + rematch["w"], lobby["x"])
                            self.assertNotIn("MatchShortcuts", named)
                            self.assertIn("Сохранено", named["RewardStatus"]["text"])
                        else:
                            self.assertNotIn("RematchButton", named)


if __name__ == "__main__":
    unittest.main()
