#!/usr/bin/env python3
"""Execute native camera handoff blocks from the real lobby and match clients."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
lobby = (ROOT / 'src/lobby/StarterPlayer/StarterPlayerScripts/SpyClient.client.luau').read_text()
match = (ROOT / 'src/match/StarterPlayer/StarterPlayerScripts/MatchIntroClient.client.luau').read_text()
checkers = (ROOT / 'src/lobby/StarterPlayer/StarterPlayerScripts/CheckersClient.client.luau').read_text()
billiards = (ROOT / 'src/lobby/StarterPlayer/StarterPlayerScripts/BilliardsClient.client.luau').read_text()


def section(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]


sources = {
    '-- LOBBY_CAMERA_SOURCE_INSERT': section(lobby,
        '-- CHARACTER WORLD TABLE CAMERA BEGIN' if '-- CHARACTER WORLD TABLE CAMERA BEGIN' in lobby else 'local function focusTable(id)',
        'local function resultEffect()'),
    '-- MATCH_CAMERA_OWNERSHIP_SOURCE_INSERT': (
        section(match, '-- CHARACTER WORLD SCENE OWNERSHIP BEGIN', '-- CHARACTER WORLD SCENE OWNERSHIP END')
        if '-- CHARACTER WORLD SCENE OWNERSHIP BEGIN' in match else ''
    ),
    '-- MATCH_POINTER_OWNERSHIP_SOURCE_INSERT': section(match, '-- CHARACTER WORLD SCENE OWNERSHIP BEGIN', '-- CHARACTER WORLD SCENE OWNERSHIP END'),
    '-- MATCH_POINTER_HANDLERS_SOURCE_INSERT': section(match[match.index('-- Match controls stay clickable.'):],
        'UserInputService.InputBegan:Connect(function(input,processed)', 'task.defer(function()'),
    '-- MATCH_AVATAR_WRITERS_SOURCE_INSERT': section(match, 'local function showLocalAvatar()', 'local function yawFromDirection('),
    '-- MATCH_ARM_CAMERA_WRITERS_SOURCE_INSERT': section(match, 'local function updateArm(dt)', 'RunService.RenderStepped:Connect(function(dt)'),
    '-- MATCH_RENDER_SOURCE_INSERT': section(match, '-- RENDER\n', '-- INITIAL\n'),
    '-- MATCH_FOV_SOURCE_INSERT': section(match, 'local function applyCinematicPreferences()', 'for _, attribute in ipairs({"SpyReducedMotion"'),
    '-- MATCH_TWEEN_SOURCE_INSERT': section(match, 'local function tween(object, duration, props, style, direction)', 'local function waitTween('),
    '-- MATCH_PHASE_ADMISSION_SOURCE_INSERT': section(match, 'local function handleState(state)', '\tcurrentState = state') + '\tcurrentState = state\nend',
    '-- MATCH_CAMERA_ENTRY_SOURCE_INSERT': '\n'.join([
        section(match, 'local function startSeatedCamera(state)', 'local function releaseCursor()'),
        section(match, 'local function introCamera(state)', 'local function characterCamera()'),
        section(match, 'local function characterCamera()', 'local function resultCamera()'),
        section(match, 'local function resultCamera()', '-- CARD HELPERS'),
    ]),
    '-- LOBBY_PANEL_CALL_SOURCE_INSERT': section(lobby, 'local function callPanelMethod(', 'local pendingId='),
    '-- LOBBY_DOSSIER_BINDER_SOURCE_INSERT': section(lobby, 'local dossierEvent=playerGui:FindFirstChild("SpyOpenDossier")', '-- Phone applications'),
    '-- CHECKERS_CAPTURE_SOURCE_INSERT': section(checkers, 'local function open()', ' gui=make("ScreenGui"') + '\nend',
    '-- CHECKERS_CONTROLS_SOURCE_INSERT': section(checkers, 'local function acquireControls(token)', 'local function projectInput()'),
    '-- BILLIARDS_CAPTURE_SOURCE_INSERT': section(billiards, 'local function enterCamera()', '-- BILLIARDS_PRESENTATION_BEGIN'),
}
template = (ROOT / 'tests/character_camera_integration.spec.luau').read_text()
for marker, source in sources.items():
    if template.count(marker) != 1:
        raise SystemExit(f'Invalid native camera source insertion marker: {marker}')
    template = template.replace(marker, source)
with tempfile.TemporaryDirectory(prefix='spyclub-character-camera-integration-') as directory:
    target = Path(directory) / 'camera_integration.luau'
    target.write_text(template)
    result = subprocess.run([os.environ.get('LUAU_BIN', '/workspace/.spy-tools/bin/luau'), str(target)], cwd=ROOT)
    raise SystemExit(result.returncode)
