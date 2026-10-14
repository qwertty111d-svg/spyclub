# Lobby environment integration

The lobby foyer is an additive runtime model inside the existing main lounge.
The match place's lighting, world geometry and spawn scripts are unchanged.

## Changed scripts

- `ServerStorage/SpyModules/World`: builds `SpyClub/ClubEntrance` after geometry
  binding, preserves the existing `ClubArchive/ClubExitDoor`, and reapplies the
  authoritative spawn transform after `WorldGeometry.bind`.
- `ServerStorage/SpyModules/WorldSpec`: declares `entry`, updates the baked
  `ClubSpawn` and first route start to the same position.
- `ServerScriptService/WorldBootstrap`: uses the same transform during the
  independent initial safety bootstrap and fall recovery.
- `ServerStorage/SpyModules/LobbyLighting`: tunes the late-night grade, maintains
  modest bloom, and audits exact fixture/light names inside their expected
  presentation model ancestry. It now calibrates existing interior fixtures to
  absolute warm-neutral levels; the audit is scoped to `SpyClub`.
- `ServerStorage/SpyModules/LobbyWayfinding`: derives its entry route from the
  live spawn and renders the previously unrendered planned route inlays.

## Spawn, routes and existing interactions

`ClubSpawn` is at `(0, 0.25, -26.5)`, yaw `180`, looking along `+Z` toward the
main lounge and Vincent. Its eight-by-five footprint is supported by the
existing colliding `SafetyFloor`. The landing is flush decoration, and every
new foyer part has collision, touch and query disabled. Side piers are outside
the spawn footprint; the canopy is above the eight-stud safety envelope.

The existing closed exit door remains responsible for the front-wall opening,
door leaves, backing collision, and `ClubLockedExit` prompt. The new canopy is
clear of its existing lamp. The foyer's four lights have actual visible lenses:
two warm door-side lights, a broad warm canopy light, and a low-output cool
threshold strip. Stone, dark metal and brass frame the entrance without a new
wall, step, gate or duplicated interaction.

Feedback, daily rewards, Vincent and cosmetic gallery prompt anchors are kept
in place. Wayfinding continues to read those live anchors. Existing geometry
cleanup deliberately removes legacy physical match tables and High Stakes;
that policy was inspected and left intact. Party creation, match teleportation,
NPCs, minigames and phone interaction code are not changed here.

`ClubEntryClient` still presents the isolated `NocturneLounge` at height 60.
`ClubEntryController` derives its final camera frame from the live character,
raycasts for clearance and releases controls back to the native camera. Its
handoff therefore follows the adjusted spawn without a hardcoded camera edit.
The initial tour uses live prompt anchors rather than the old spawn position.

## Lighting audit contract

An arbitrary `ClubFixture` attribute or `Neon` material no longer grants access
to the whitelist. A light must have the correct class, name, visible diffuser,
and expected model ancestry. Approved families include `ClubEntrance`,
`ClubInterior`, `ClubArchive`, `NocturneLounge`, `RainWindows/NightStreet`, the
three exact shelf strips, and the writing desk diffuser. Every existing fixture
creator in these modules was inspected. Late lights are checked through one
`SpyClub.DescendantAdded` connection; repeated setup does not add a connection.
Lights outside `SpyClub` are preserved for unrelated interactive objects.

The existing `SpyClub/ClubBilliards/CeilingLightDiffuser/SurfaceLight` is also
recognized. The previous whitelist removed this real table light at initial
or late startup. The new rule requires its exact direct model ancestry, visible
Neon diffuser, `ClubFixture` attribute and SurfaceLight class; the same lens in
another model and a PointLight on that lens remain rejected.

## Current evening lighting

The club keeps clock time `22.4`, dark cool outdoor ambient `54/67/84`, low bloom
and global shadows. Interior ambient is `106/110/116`, exposure is `+0.24`, and
the existing local keys use warm-neutral `255/238/216`. Lower grade contrast and
light atmospheric haze keep faces out of crushed shadows.

| Existing fixture family | Brightness | Range |
| --- | --- | --- |
| Main aisle | 1.85 | 26 |
| Side seating | 1.7 | 26 |
| Bar | 1.55 | 23 |
| Corridor | 1.25 | 19 |
| Pool table | 1.8 | 24 |

Calibration runs after optional interior construction and for later approved
lights. Repeated setup sets the same absolute values, avoiding multiplied
brightness. Cool window/threshold fixtures, portrait lights and exterior lamp
levels are preserved. No new emitters, fixture geometry or collisions are added.

## Executed validation

`python3 tools/test_lobby_environment.py` executes the actual changed Luau
modules with engine stubs, including the actual LobbyInterior and BilliardsModel
builders. It checks spawn direction/support, preservation of
the locked door, additive non-colliding foyer geometry, live route anchors,
rendered inlay objects, a geometry writer attempting to reset the spawn,
idempotent world setup, approved fixtures including the real pool lamp, eight
rejected fixture combinations, repeated audits, and isolation from lights on
another object. All 14 authored aisle/side/bar/corridor fixtures are checked for
bounded warm-neutral key levels and range extending beyond the floor. It also
checks evening clock/fill/exposure bounds and repeatable absolute calibration.
All assertions passed.

The same check also uses the uploaded lobby's decoded `Workspace` BasePart
positions and sizes to check the spawn envelope for saved colliders. No saved
part intersects the eight-by-five-by-eight envelope. Terrain API extents are
excluded because they do not describe occupied voxels.

Targeted Luau compilation of LobbyLighting succeeded. These are deterministic
contract and syntax checks, not a Roblox engine simulation. Roblox Studio Play
Test, mobile graphics/readability, real avatar head clearance, Terrain voxel
occupancy, two-client behavior and final visual composition remain to be
checked in Studio. No rendering or Output-error claim is made.
