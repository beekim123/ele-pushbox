# Pushbox Demo Implementation Plan

> 历史归档：本文件保留当时的规格、计划或结论，不是当前执行指令。最新目标与新版设计见 [项目文档导航](../../README.md)。目录整理仅修复引用，不重算历史结果。

> Execute inline with executing-plans, one task and one local worker at a time. User authorized M0–M5 on 2026-10-13; no additional design approval is required.

**Goal:** Deliver the five playable Godot rooms and reproducible acceptance evidence.

**Architecture:** `board.gd` is pure data logic and emits named-material commands. `session.gd` owns the SDK, snapshots and the tick-exact settlement state machine; both game and preview call it. UI observes sessions without introducing simulation randomness.

**Tech Stack:** Godot 4.7.2, GDScript, ele-base-cpp dacb93e/v1.2.0, Apple clang 17.

**Spec:** `docs/demo-template.md`, `docs/pushbox_sim.cpp`, user-provided prompt and 2026-10-13 adjudication.

## Global Constraints

- World 320×192; tile 16×16; seed 1; scale 2; tick rate 60; max physics steps 2; HDR 2D disabled.
- Materials/profile JSON copied verbatim from template; empty reaction table.
- C01/C02 adjudicated: SAND counts only loose; scan crumble every round.
- One worker, numerical library threads 1, SDK build `--jobs 1`, low priority build; check global process budget before computation.
- T2 threads 4/8 explicitly unexecuted. No SDK source modifications.
- Commands ≤4096 per tick; invalid actions do not step the world; no game randomness.

## M0: Locked extension and world

Files: `tools/prepare_sdk.sh`, `project.godot`, `ele.gdextension`, `bin/`, content JSON, `tests/m0.gd`.

- [x] Run initial `Godot --headless --path . --script tests/m0.gd`; expect `FAIL M0: EleWorld extension is unavailable` before building.
- [x] Prepare independent SDK at dacb93e and locked dependencies; run `check_environment.py --mode all`, save output.
- [x] Run `nice -n 10 .venv/bin/python tools/build.py --mode godot --config release --jobs 1`; copy dylib/shader/extension definition.
- [x] Before Godot invocation write `.godot/extension_list.cfg`; rerun M0 and verify `start()==0`, array length 61440 and successful step.

## M1: Pure board, loading and settlement

Files: `level_loader.gd`, `board.gd`, `session.gd`, five level JSON files, `tests/m1.gd / tests/acceptance.gd`.

Interfaces: loader validates JSON and produces centered level data; board consumes `PackedInt32Array` plus material metadata, emits `{op,args}` commands. Session `load_level(path)`, `perform(action)`, `advance(tick_budget)`, `settle_sync()` are shared by tests and UI.

- [x] Write and run regression tests before board implementation: classification uses one tag; crumble removes 1–127 cells on a non-bomb round; board initially fails with missing implementation (board-red.log).
- [x] Port deterministic action/swap/buoyancy/actor/gate ordering, preserving local cell updates.
- [x] Implement each `step(1)` with quiet-counter check, fixed stop tick, command queue batching, moved-round oscillation guard and settlement limits.
- [x] Replay all five author solutions. Assert literal total ticks `[37,152,143,67,331]`, D2 `[220,192,58]`, D3 `160`, D5 `[200,456,128,224]`; record every action/hash/position.

## M2: Presentation and input

Files: `game.gd`, `ui/board_view.gd`, `ui/hud.gd`, `main.tscn`, `tests/ui.gd`.

- [x] Add UI smoke test before scene implementation; load scene, select all five rooms and exercise input actions.
- [x] Render SDK at 2× scale, draw goals/ladders/levers/plates, player and crate detail; classify outlines and category legend.
- [x] Keyboard arrows/WASD, tools 1/2/3, E, Z/R, mouse adjacent tile actions; disable input during settlement; six-frame actor tween; Space speeds up ticks without changing stop tick.
- [x] Run graphical smoke/screenshot and author solutions through actual controller. Manual human completion remains user acceptance, separate from technical evidence.

## M3: Snapshots, preview and hints

Files: `preview.gd`, session snapshot methods, game/HUD controls, generated author key/hash fixture.

- [x] Write T5/T6 first: undo + same action reproduces hash; preview actual tick/actors/categories/hash match and leave real session unchanged.
- [x] Save SDK files plus JSON game state, cap undo at 200, restart from opening snapshot.
- [x] Preview destructive actions in non-rendered second world; confirm only same second input; cancelled tool/direction discards preview.
- [x] Generate solution keys/hashes using real execution; match hint with board key (not world hash), show latest matching undo distance for deviations. Rule hints evaluate data conditions.

## M4: Acceptance and limits

Files: `tests/m1.gd / tests/acceptance.gd`, `tests/edge_cases.gd`, `artifacts/logs/`, `docs/v2/report.md`.

- [x] T1 compare replay against generated author fixture and victory; T2 single-worker repeated hash determinism, mark 4/8 unexecuted.
- [x] T3 thresholds 104/152, support 48/80: assert per-action actors match baseline and all rooms win.
- [x] T4 sand+bag/water conservation; independently account SDK destroyed cells and gate crush; test ≤16/17-cell gate boundary and occupied groups.
- [x] T5 undo/repeat; T6 preview real consistency; T7 per-round max ticks/rounds and no author-solution oscillation; T9 literal M1 values.
- [x] Validate bad maps/unknown legend/gate mismatch/static partial fills and invalid actions; test stack/no-chain pushing, directional tool restrictions, multi-material bags and mechanism expressions.

## M5: Performance and delivery

Files: `tests/performance.gd`, `README.md`, `docs/v2/report.md`, `docs/v2/status.md`.

- [x] Measure real four-tick settlement batches and complete previews (including snapshot I/O); record max/p50/p95 and compare 4ms/100ms thresholds.
- [x] If a performance test fails, profile game overhead and optimize without changing SDK/JSON/tick semantics; rerun affected correctness tests.
- [x] Review implementation against template; run headless suite and scene smoke; preserve full output and explicit failed/unexecuted items.
- [x] Document clean setup/build/run/test commands, exact versions and conflicts; distinguish playable candidate, technical results, user acceptance and formal release. Clean only own unnecessary processes.

## User decision

2026-10-13: “这两条以模板为准，继续按 M0–M5 实施。本机保持单 worker，T2 的 4/8 线程测试列为未执行。”

Final evidence: docs/v2/report.md; latest full suite 10/10 passed. T2 4/8 and T10 remain explicitly unexecuted.
