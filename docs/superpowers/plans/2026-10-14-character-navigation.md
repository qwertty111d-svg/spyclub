# Character and Navigation Implementation Plan

> **For agentic workers:** Follow the assigned ownership boundaries in this existing isolated checkout. Use actual-module tests; root integrates and reviews before one release commit.

**Goal:** Replace confusing H and lower controls with two clear character tabs and coherent navigation; illuminate scenes neutrally.

**Architecture:** Presentation changes reuse existing UI contexts and server-owned Economy/Profiles. Lighting keeps existing fixture generators. Independent workers own H, navigation and lighting; root owns integration, docs and release.

**Tech Stack:** Roblox Luau, actual-module boundary harnesses, Python binary place tools.

**Spec:** ../specs/2026-10-14-character-navigation-design.md

## Global Constraints

- Existing checkout /workspace/spyclub; no new worktree.
- One server receipt owner and existing paid/equipped profile contracts.
- Product IDs 3718610025/3718610195/3718610306 retain 1/3/5 Rolls.
- Exactly two primary H tabs; selecting a target never spends.
- Main roll action explicitly names its target; actual chances and 1 Roll cost.
- White light/grade/preview, preserve geometry/collisions and material identity.
- Target size at least44px; no lower overlap at900px or phone360px.

## Review Focus

- Retained identity/cosmetic requests with absent category DTO or phase changes.
- A visible main action must have a visible named target on portrait screens.
- Hidden-tab and modal controls must not receive unintended actions.
- Independent quick chat must respect the same lower geometry and overlay flags.
- Neutral viewport, room lamps and cinematic grade must agree, including repeat setup.

## Task1: Two-tab H

Files: both AccessoryRollUI.luau, tests/dossier_ui.spec.luau and its runner if needed.
Consumes existing ctx and Preview3D; preserves create/open/close/update/resize/receive.

- [x] Add tests: exactly two tabs; field selection sends no request; one named action sends the selected category; appearance/current item visible; viewport bounds.
- [x] Run focused dossier test and observe missing behavior.
- [x] Implement separate identity and appearance presentation, one roll action and clear odds/owned entry.
- [x] Exercise close/reopen, timeout, missing DTO, zero balance, policy, match phase and delayed receipt through both tabs.
- [x] Mirror shared source and run focused tests/compile.

## Task2: Lower navigation

Files: lobby HudController/SpyClient, match MatchHUD/MatchIntroClient, relevant GUI/legacy harnesses.
Consumes existing authored buttons/actions; keeps all phase and role restrictions.

- [x] Pin integrated QuickChat overlap at900px and modal visibility; retain actual-module checks.
- [x] Implement one restrained lower row and relocate supplementary quick chat.
- [x] Exercise desktop/phone/short landscape and all indispensable action routes.
- [x] Run focused HUD/legacy checks/compile.

## Task3: Neutral light

Files: LobbyLighting, MatchRoomExperience, both Preview3D copies, focused lighting tests.
MatchIntro tint patch applied by root after navigation worker finishes.

- [x] Check actual generator colors/fixture ownership and unchanged collisions.
- [x] Neutralize global/source/preview light and improve bounded local match fill.
- [x] Preserve repeat application, audit whitelist and face/room fixture coverage.
- [x] Run focused lighting harnesses/compile.

## Task4: Integrate and release

- [x] Inspect actual GUI geometry and conceptual layout; make no Studio-render claim.
- [x] Apply neutral client/cinematic grade and update release filenames/docs.
- [x] Run full validate, build, six binary tests, independent property and embedded-source comparison.
- [x] Review the complete branch, resolve findings, package verified ZIP.
- [x] Commit/push main and confirm remote SHA/clean worktree.
