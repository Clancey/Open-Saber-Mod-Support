# Open-Saber-Mod-Support Implementation Plan

Edits are made by Copilot CLI (`copilot -p "<task>" --allow-all-tools` from this dir). Claude agents review and direct only.
Reference docs (read-only): `../OpenSaber_Current_State.md`, `../Gap_Analysis_Report.md`, `../Implementation_Roadmap.md`, `../ChroMapper_Feature_Inventory.md`. ChroMapper C# source: `../ChroMapper`.

Schedule: Stage 1 and Stage 2a run in parallel. Stage 2b and Stage 3 run in parallel after Stage 1. Stage 4 follows Stage 2b (both touch `Playing.gd`). Stage 5 last.

## Stage 1: Code Review, Dead Code, Test Harness
**Goal**: Reviewed, cleaned codebase plus a headless GDScript test runner for parser logic.
**Success Criteria**: Zero `print()` in spawn/load/event paths; no unused threads/vars; `godot --headless -s tests/run.gd` passes.
**Tests**: Parser unit tests for `ColorNoteInfo`, `ObstacleInfo.get_position_and_size`, `Map.beat_to_seconds`, `Map.set_colors_from_custom_data`.
**Status**: Complete
**Agents**: code-reviewer (lead), general-purpose (write Copilot prompts).
**Files**: `game/Map.gd` (12 static Threads, DEBUG prints, duplicate v2/v3 load funcs), `game/scripts/GameState/Playing.gd:62` (`print(note_info.custom_data)` per note), `game/event_driver.gd:37,70,77` (no-op `Thread.PRIORITY_LOW`, prints), `game/scripts/Utils.gd` (untyped thread helpers), `game/BeepCube/BeepCube.gd:64-68` (commented code), `game/Wall/Wall.gd` (untyped vars, `testforLayer` unused), `game/Constants.gd`, `game/BeatmapInfo/*.gd`.
**Tell code-reviewer**: Flag correctness bugs, not style. Known: `Wall.gd:55` missing `Constants.LANE_ZERO_X`; `ColorNoteInfo.new_v3`/`ObstacleInfo.new_v3` read `"_customData"` (v3 key is `"customData"`). Output a numbered fix list; general-purpose turns each into one Copilot prompt.

## Stage 2: Performance (Quest/OpenXR)
**Goal**: 72 fps sustained on Quest with dense maps (test: shrek, Air 67ba, Bumblebee 922f).
**Success Criteria**: No frame >13.9 ms during spawn bursts; zero per-frame allocations in `_process_map`; map load <30 ms desktop.
**Tests**: Profiler capture before/after; debug label (`BeepSaber_Game.gd:158`) pool counts never hit zero.
**Status**: Complete
**Agents**: performance-engineer (2a profile, 2b direct), game-developer (2b Godot-specific pooling/rendering).
**Files**: `game/scripts/GameState/Playing.gd` (bombs/walls/arcs `instantiate()` per spawn; move to `ScenePool`), `game/Wall/Wall.gd` (`queue_free`, string node paths per spawn), `game/Bomb/Bomb.gd`, `game/Arc/Arc.gd`, `game/scripts/ScenePool/ScenePool.gd`, `game/Cuttable.gd:30` (`_physics_process` on all 200 pooled nodes), `game/BeepCube/BeepCube.gd:31` (material `duplicate(true)` per cube), `game/event_driver.gd`, `game/LightManager.gd` (tweens per light event), `game/Map.gd` (replace 12 Threads with `WorkerThreadPool`), `project.godot` (`msaa=6`, shadow atlas 2048 on mobile renderer).
**Tell performance-engineer**: Profile first, fix top three only. Prefer pooling and `set_physics_process(false)` on released nodes over rewrites. Report ms per fix.

## Stage 3: Godot 4.7 Migration
**Goal**: Project opens and runs in Godot 4.7 with OpenXR, no deprecation errors.
**Success Criteria**: `config/features` = 4.7; editor opens with zero errors; VR simulator and a Quest build both play the bundled demo song.
**Tests**: Headless import (`godot --headless --import`) exits 0; Stage 1 test suite passes on 4.7.
**Status**: Complete
**Agents**: game-developer (lead), debugger (import/runtime errors).
**Files**: `project.godot` (remove `3d/physics_engine="Bullet"`, `[gdnative]` `godot_openxr.gdnlib`, legacy `quality/*` and `xr/shaders/enabled`; evaluate Jolt), `addons/godot-openxr/` (Godot 3 plugin, delete), `OQ_Toolkit/vr_autoload.gd`, `OQ_Toolkit/OQ_UI2D/scripts/*.gd`, `export_presets.cfg`, `addons/stopwatch/`.
**Tell game-developer**: Use context7 for 4.4 to 4.7 breaking changes before prompting Copilot. One Copilot prompt per subsystem; run headless import after each.

## Stage 4: ChroMapper Map Compatibility (v2/v3/v4 + customData)
**Goal**: Maps exported from ChroMapper load and play with Chroma colors, ME positions, and basic Noodle coordinates.
**Success Criteria**: v2, v3, v4 fixtures each load; v3 `customData.color` and `coordinates` applied; ME walls positioned correctly; unsupported Noodle animation degrades gracefully (no crash).
**Tests**: Parser fixtures (one per version, exported from ChroMapper) under `tests/fixtures/`; assertion tests for note position, wall position/size, event colors.
**Status**: Complete
**Agents**: game-developer (lead), qa-expert (fixtures and assertions), general-purpose (ChroMapper source lookup in `../ChroMapper/Assets/__Scripts/Beatmap/`).
**Files**: `game/Map.gd:88-106` (v4 info.dat rejected), `game/BeatmapInfo/MapInfo.gd` (add `new_v4`), `game/BeatmapInfo/DifficultyInfo.gd`, `game/BeatmapInfo/ColorNoteInfo.gd`, `ObstacleInfo.gd`, `BombInfo.gd`, `ArcInfo.gd`, `ChainInfo.gd`, `EventInfo.gd`, `V3LightingInfo.gd`, `game/scripts/GameState/Playing.gd:63,80,104` (v2-only `"_color"` lookup), `game/Wall/Wall.gd`, `game/BeepCube/BeepCube.gd`, `game/Constants.gd` (where `usingMappingExtension` flags are set).
**Tell game-developer**: Match ChroMapper's `V3/V4` serializer key names exactly; v4 splits `colorNotes` into `colorNotesData` with index refs. Copilot prompt per version, then one for customData.

## Stage 5: QA and Regression
**Goal**: Verified end to end on desktop simulator and Quest.
**Success Criteria**: All fixtures play to completion; score, events, pause/restart work; fps target met.
**Tests**: Full test suite plus manual Quest checklist.
**Status**: In Progress (desktop verified: 29 unit tests, both shipped maps play via harness, XR-mode launch clean, Quest APK exports via 4.7 gradle template + vendors 5.1.0; on-device pass still to do)
**Agents**: qa-expert (lead), debugger (on failures).
**Tell qa-expert**: Reuse Stage 4 fixtures; log any regression as a Stage-numbered follow-up rather than fixing inline.

## Stage 6: Local Playtest Harness and Lighting Fidelity
**Goal**: Automated desktop (non-XR) playthrough that emulates controllers, verifies cuts/score/lighting, records FPS and draw calls, and screenshots the run; v3 lighting lights the whole environment (data-driven group table + fallback, ring rotation, boost colors).
**Success Criteria**: `tests/autoplay/AutoPlayHarness.tscn` plays Golden (v3) and Timelapse (v2) with 0 script errors, >90% cuts, lighting events firing every second; draw calls reduced vs. the 250-290 baseline.
**Tests**: `tests/test_v3_lighting.gd`; harness report.json per map.
**Status**: Complete (v4 rotation boxes and v3 per-instance lightID filters added 2026-09-04)
**Run**: `/Applications/Godot4.7.app/Contents/MacOS/Godot --path . --xr-mode off --resolution 1280x720 tests/autoplay/AutoPlayHarness.tscn -- --song="res://game/data/maps/Songs/48088 (Golden - sammy & Tonkie)/" --diff=ExpertStandard --duration=45 --out=/tmp/autoplay --shot-every=5`

## Stage 7: Fail Mode, Energy Bar, Visual Pass
**Goal**: Beat Saber energy/fail rules with a No Fail setting and an in-world energy bar; a visual pass (notes, bombs, sabers + trail, runway grid, platform border, rings, light bars, sky) tuned for Quest.
**Success Criteria**: `tests/test_scoreboard.gd` passes; harness with `--bot=0` reports `AUTOPLAY|FAILED`; normal run reaches energy 1.0; screenshots show colored sabers, per-side sky tint, energy bar in view; draw calls stay ~50.
**Tests**: 38 headless tests; harness runs on Golden and Timelapse.
**Status**: In Progress (fail mode verified on desktop; visual refinement of sabers/sky/energy-bar placement running)

## Stage 9: Online Multiplayer
**Goal**: Beat Saber style lobbies over the user's WebRTC signaling worker (game id `open-saber`): host/join by code, ready-up, synchronized song start, live scores and avatars.
**Status**: Foundation and wiring done (2026-09-11): `MultiplayerSession` autoload, lobby panel under the Online tile, host picks the song in the level list, synced start with countdown, score/finish broadcast, in-game ranking, remote avatars. Follow-ups: TURN server, host migration, downloading a missing map for joiners, results ranking on the end screen, avatar polish.
**Files**: `game/multiplayer/*`, `addons/webrtc/`, `game/BeepSaberMainMenu.gd/.tscn`, `game/BeepSaber_Game.gd/.tscn`, `tests/test_clock_sync.gd`, `tests/multiplayer/`.

## Stage 8: Look and Feel Parity with the Original
**Goal**: Gameplay objects, movement and the default environment match Beat Saber.
**Success Criteria**: Notes travel at the map NJS with Beat Saber's spawn-ahead, jump arc and rotation; notes/bombs/walls/sabers use the original meshes and equivalent materials; the environment is "The First" layout with its light-ID mapping; harness runs clean.
**Tests**: 38 headless tests; `tests/visual/VisualPreview.tscn` screenshot; harness on Timelapse with `--nofail=1`.
**Status**: Complete: movement, notes, bombs, walls, chain links, sabers, trails, cut/bomb particles, HUD panels (combo lines, multiplier circle, rank, progress bar), colors, environment layout, event-driven scene lights, menu tiles, Teko bitmap font (OFL, generated), level list rows, characteristic selector, pause and results panels. The 3D HUD, results, floating cut scores and 3D buttons use Label3D with the same Teko bitmap font. Per-map environments generated (21 environments from Origins to Gaga) load from `game/environments/`. Follow-ups: the newer environments (Weave, Pyro, EDM, TheSecond, Lizzo, TheWeeknd, RockMixtape, Dragons2, Panic2, Queen, LinkinPark2, TheRollingStones, Lattice, DaftPunk, HipHop, Collider, Britney, Monstercat2, Metallica) use v3 light groups, plus per-environment materials and spectrograms.
**Files**: `game/scripts/NoteMovementData.gd`, `game/BeepCube/*`, `game/Bomb/*`, `game/Wall/*`, `game/Chain/ChainLink.gd`, `game/Arc/Arc.gd`, `game/sabers/default/*`, `game/event_driver.tscn` (+ `game/environments/TrackLaneRings.gd`), `game/assets/beatsaber/`.
