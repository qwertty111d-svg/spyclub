#!/usr/bin/env python3
"""Check that match diagnostics expose real current UI and usable key geometry."""
import hashlib
import importlib.util
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
    def test_selecting_during_hover_keeps_the_final_ballot_readable(self):
        # Run real callbacks with delayed native Tween completion: property
        # assignment alone does not cancel a Tween that is already playing.
        spec = importlib.util.spec_from_file_location("match_preview", ROOT / "tools/render_match_layout_preview.py")
        preview = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(preview)
        original = preview.between(preview.BOUNDARIES, "-- Tween completion is immediate;", "local player=Instance.new('Player')")
        deferred_tweens = r'''
local pendingHover={}
tweens.Create=function(_,node,_,properties)
 local completed=signal();completed.Wait=function()end
 local cancelled=false
 return{Play=function()
  local function finish()
   if cancelled then return end
   for key,value in pairs(properties)do node[key]=value end
   completed:Fire()
  end
  if properties.BackgroundColor3 then table.insert(pendingHover,finish)else finish()end
 end,Cancel=function()cancelled=true end,Completed=completed}
end
local function finishHovers()
 local current=pendingHover;pendingHover={}
 for _,finish in ipairs(current)do finish()end
end
'''
        assertions = r'''
local function node(name)return assert(playerGui:FindFirstChild(name,true),name)end
local first=node('Suspect_102')
first.MouseEnter:Fire()
assert(first.BackgroundColor3==view.COLORS.Panel2,'normal hover keeps its transition')
finishHovers()
assert(first.BackgroundColor3==view.COLORS.Panel3,'normal hover reaches its target')
first.MouseLeave:Fire();finishHovers()
first.MouseEnter:Fire();first.Activated:Fire();finishHovers()
assert(first.BackgroundColor3==view.COLORS.Ivory,'a pending hover cannot darken the selected card')
assert(first.SuspectName.TextColor3==view.COLORS.Ink and first.SelectionMarker.Visible,'selected identity stays legible')
local extra=node('AnotherClueRound')
extra.MouseEnter:Fire();extra.Activated:Fire();finishHovers()
assert(extra.BackgroundColor3==view.COLORS.Ivory,'a pending hover cannot darken the selected extra round')
assert(extra.ExtraRoundTitle.TextColor3==view.COLORS.Ink,'selected extra-round caption stays legible')
assert(first.BackgroundColor3==view.COLORS.Panel2 and not first.SelectionMarker.Visible,'replacing the selection clears its old marker')
print('Deferred ballot hover callbacks passed')
'''
        boundary = preview.BOUNDARIES.replace(original, deferred_tweens, 1)
        boundary = boundary.replace("view.present(fixture)", "view.present(fixture)\n" + assertions, 1)
        sources = "local Sources={\n" + "\n".join(
            f"{name}={preview.long_string(value)}," for name, value in preview.excerpts().items()
        ) + "\n}\n"
        prefix = preview.STUB.read_text().split("local Catalog =", 1)[0]
        with tempfile.TemporaryDirectory(prefix="spy-ballot-hover-test-") as directory:
            path = Path(directory) / "hover.luau"
            path.write_text(prefix + 'local WIDTH,HEIGHT,VARIANT,PLAYER_COUNT=1440,900,"vote",4\n' + sources + boundary)
            result = subprocess.run(["/workspace/.spy-tools/bin/luau", str(path)],
                                    cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertIn("Deferred ballot hover callbacks passed", result.stdout)

    def test_tablet_portraits_clear_the_large_seat_numbers(self):
        with tempfile.TemporaryDirectory(prefix="spy-ballot-tablet-test-") as directory:
            target = Path(directory) / "vote-804.html"
            result = subprocess.run(
                [sys.executable, str(ROOT / "tools/render_match_layout_preview.py"), "vote",
                 "--width", "804", "--height", "900", "--output", str(target)],
                cwd=ROOT, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            nodes = json.loads(target.with_suffix(".json").read_text())
            portraits = [node for node in nodes if node["name"] == "Portrait"]
            numbers = [node for node in nodes if node["name"] == "SeatIndex"]
            self.assertEqual(len(portraits), 3)
            self.assertEqual(len(numbers), 3)
            for portrait, number in zip(portraits, numbers):
                self.assertLessEqual(portrait["x"] + portrait["w"] + 8, number["x"],
                                     "live avatar leaves a clear gutter before its seat number")

    def test_last_ballot_row_is_reachable_for_a_larger_table(self):
        # Regresses a real selection failure: the desktop canvas covered only
        # its first grid row, preventing players from reaching later suspects.
        with tempfile.TemporaryDirectory(prefix="spy-ballot-overflow-test-") as directory:
            for width, height in ((1440, 900), (360, 640), (844, 360)):
                with self.subTest(viewport=(width, height)):
                    target = Path(directory) / f"vote-seven-{width}.html"
                    result = subprocess.run(
                        [sys.executable, str(ROOT / "tools/render_match_layout_preview.py"), "vote",
                         "--players", "7", "--width", str(width), "--height", str(height),
                         "--output", str(target)], cwd=ROOT, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                    nodes = json.loads(target.with_suffix(".json").read_text())
                    named = {node["name"]: node for node in nodes}
                    self.assertNotIn("Suspect_101", named, "own player is never a voting target")
                    self.assertEqual(sum(n["name"].startswith("Suspect_") for n in nodes), 6)
                    choices, last = named["Suspects"], named["Suspect_107"]
                    last_bottom = last["y"] + last["h"]
                    maximum_scroll = max(0, choices["canvasHeight"] - choices["h"])
                    self.assertLessEqual(last_bottom - maximum_scroll,
                                         choices["y"] + choices["h"] + .01,
                                         "last suspect can be fully revealed by scrolling to the end")
                    footer = named["SubmitBallot"]
                    self.assertLessEqual(choices["y"] + choices["h"], footer["y"],
                                         "scrolling suspects do not cover confirmation")
                    metadata = json.loads(target.with_suffix(".metadata.json").read_text())
                    self.assertEqual(metadata["playerCount"], 7)

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
