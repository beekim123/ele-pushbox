class_name GameplayRuleTests
extends SceneTree
## Literal fixtures cover valid actions and rejection without using tilemodel.

var checks: Array[Dictionary] = []

func _initialize() -> void:
	create_timer(45.0).timeout.connect(_watchdog_timeout)
	call_deferred("_main")

func _main() -> void:
	var result: Variant = run()
	if not result is Dictionary or not result.has("ok"):
		print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "gameplay", "ok": false, "error": "test runner aborted"}))
		quit(1)
		return
	_emit_report(result)
	quit(0 if result.ok else 1)

func _emit_report(result: Dictionary) -> void:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
	var path: String = "res://tests/results/gameplay.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE) if directory_error == OK else null
	if file == null:
		result.ok = false
		result.error = "Cannot write gameplay test report"
	else:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	var failures: Array[String] = []
	for item: Dictionary in result.get("checks", []):
		if item.status != "pass":
			failures.append(str(item.id))
	print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "gameplay", "ok": result.ok, "check_count": result.get("checks", []).size(), "failed": failures, "report": path}))

func _watchdog_timeout() -> void:
	print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "gameplay", "ok": false, "error": "test runner timeout"}))
	quit(1)

func run() -> Dictionary:
	checks.clear()
	if not FileAccess.file_exists("res://gameplay/session/level_session.gd"):
		check("gameplay.session_exists", false, "LevelSession implementation", "missing")
		return report()
	_push_and_step()
	_ladder_and_fall()
	_dig_and_bag()
	_pour()
	_plate_and_door()
	_restart_and_undo()
	_async_matches_perform()
	_physics_classification_frame_boundary()
	_deferred_safety_matches_default(["#######", "#.....#", "#PB.o.#", "#######"], "R", "push", 8)
	_deferred_safety_matches_default(["#######", "#.e...#", "#Pe...#", "#######"], "DIG_R", "dig")
	_deferred_safety_matches_default(["########", "#......#", "#P.B.o.#", "########"], "R", "walk", 0)
	_deferred_snapshot_lifecycle()
	_deferred_preparation_can_be_disposed()
	_deferred_rejects_lifetime_material()
	return report()

func fixture(rows: Array, sand: int = 0):
	var session = load("res://gameplay/session/level_session.gd").new()
	session.render_enabled = false
	var started: bool = session.setup({"id": "test-fixture", "map": rows, "bag": {"sand": sand, "bomb": 0}})
	check("fixture.setup.%d" % checks.size(), started, "SDK settles fixture", session.last_error)
	return session

func _push_and_step() -> void:
	var session = fixture(["#######", "#.....#", "#PB.o.#", "#######"])
	var result: Dictionary = session.perform("R")
	check("push.single_box", result.accepted and session.state().crates[0].x == 3 and session.state().player.x == 2, "player2 box3", session.state())
	check("push.sdk_box_full", session.world.count_material("crate", Rect2i(48, 32, 16, 16)) == 256, 256, session.world.count_material("crate", Rect2i(48, 32, 16, 16)))
	session.dispose()
	session = fixture(["#######", "#######", "#PBB..#", "#######"])
	result = session.perform("R")
	check("push.reject_chain", not result.accepted and session.state().moves == 0 and session.state().crates[0].x == 2 and session.state().crates[1].x == 3, "no movement or step", session.state())
	session.dispose()
	session = fixture(["#######", "#.....#", "#P#...#", "#######"])
	result = session.perform("R")
	check("move.one_step_up", result.accepted and session.state().player == {"x": 2, "y": 1}, {"x": 2, "y": 1}, session.state().player)
	session.dispose()
	session = fixture(["#######", "#.#...#", "#P#...#", "#######"])
	result = session.perform("R")
	check("move.reject_two_high", not result.accepted and session.state().moves == 0, "blocked; no move spent", result)
	session.dispose()

func _ladder_and_fall() -> void:
	var session = fixture(["#######", "#H....#", "#h....#", "#.....#", "#######"])
	check("ladder.holds_player", session.state().player.y == 2, 2, session.state().player.y)
	check("ladder.climb_up", session.perform("U").accepted and session.state().player.y == 1, 1, session.state().player.y)
	check("ladder.reject_up_without_next_rung", not session.perform("U").accepted, false, session.state().player)
	check("ladder.down", session.perform("D").accepted and session.state().player.y == 2, 2, session.state().player.y)
	check("ladder.leave_and_fall", session.perform("R").accepted and session.state().player.y == 3, 3, session.state().player.y)
	session.dispose()
	session = fixture(["#######", "#.B...#", "#.P...#", "#######"])
	check("fall.person_holds_crate", session.state().crates[0].y == 1, 1, session.state().crates[0].y)
	session.perform("R")
	check("fall.crate_after_person_leaves", session.state().crates[0].y == 2, 2, session.state().crates[0].y)
	session.dispose()

func _dig_and_bag() -> void:
	var session = fixture(["#######", "#.e...#", "#Pe...#", "#######"])
	check("dig.static_earth", session.perform("DIG_R").accepted and session.state().bag.sand == 1 and session.state().terrain[9] == 3, "upper earth stays; bag1", session.state())
	check("dig.reject_empty", not session.perform("DIG_R").accepted, false, session.state().bag.sand)
	check("dig.reject_rock", not session.perform("DIG_L").accepted, false, session.state().bag.sand)
	check("dig.reject_up", not session.perform("DIG_U").accepted, false, session.state().bag.sand)
	session.dispose()
	session = fixture(["#######", "#.....#", "#Pe...#", "#######"], 9)
	check("bag.cap_nine", not session.perform("DIG_R").accepted and session.state().bag.sand == 9, 9, session.state().bag.sand)
	session.dispose()

func _pour() -> void:
	var session = fixture(["########", "#......#", "#.P..###", "########"], 1)
	check("pour.reject_down", not session.perform("POUR_D").accepted and session.state().bag.sand == 1, "reject; bag unchanged", session.state().bag)
	check("pour.one_bag_256", session.perform("POUR_R").accepted and session.world.count_material("sand", Rect2i(0, 0, 320, 192)) == 256 and session.state().bag.sand == 0, "256 cells, bag0", session.state())
	check("pour.reject_no_sand", not session.perform("POUR_L").accepted, false, session.state().bag)
	session.dispose()
	session = fixture(["#######", "#.....#", "#PB...#", "#######"], 1)
	check("pour.reject_box", not session.perform("POUR_R").accepted and session.state().bag.sand == 1, "cannot overwrite crate", session.state())
	check("pour.box_intact", session.world.count_material("crate", Rect2i(32, 32, 16, 16)) == 256, 256, session.world.count_material("crate", Rect2i(32, 32, 16, 16)))
	session.dispose()

func _plate_and_door() -> void:
	var session = fixture(["########", "#......#", "#P_|.X.#", "########"])
	check("door.initial_closed", not session.state().doors[0], false, session.state().doors)
	session.perform("R")
	check("plate.person_opens", session.state().doors[0], true, session.state().doors)
	session.perform("R")
	check("door.occupied_stays_open", session.state().player.x == 3 and session.state().doors[0], "player in open door", session.state())
	session.perform("R")
	check("door.closes_after_clear", not session.state().doors[0], false, session.state().doors)
	session.dispose()
	session = fixture(["#########", "#.......#", "#PB..|X.#", "###_#####", "#########"])
	session.perform("R")
	check("plate.fallen_box_opens", session.state().crates[0].y == 3 and session.state().doors[0], "box in plate pit; door open", session.state())
	session.dispose()

func _restart_and_undo() -> void:
	var session = fixture(["#######", "#.....#", "#PB.o.#", "#######"])
	var opening: Dictionary = session.state()
	session.perform("R")
	var before: Dictionary = session.state()
	var before_hash: String = session.world.get_state_hash()
	check("restart.accepted", session.restart(), true, session.last_error)
	check("restart.restores_opening", session.state() == opening, opening, session.state())
	check("restart.undoable", session.undo() and session.state() == before, before, session.state())
	check("undo.restores_sdk_hash", session.world.get_state_hash() == before_hash, before_hash, session.world.get_state_hash())
	session.dispose()

func _async_matches_perform() -> void:
	var synchronous = fixture(["########", "#......#", "#PB..X.#", "###_####", "########"])
	synchronous.perform("R")
	var expected: Dictionary = synchronous.state()
	var expected_hash: String = synchronous.world.get_state_hash()
	var asynchronous = fixture(["########", "#......#", "#PB..X.#", "###_####", "########"])
	var begin: Dictionary = asynchronous.begin_action("R")
	check("async.accepts_action", begin.accepted and asynchronous.busy, "accepted; settling", begin)
	var previous_tick: int = int(asynchronous.world.get_stats().tick)
	var calls: int = 0
	while asynchronous.busy and calls < 400:
		var tick_result: Dictionary = asynchronous.advance_settle(4)
		var now_tick: int = int(asynchronous.world.get_stats().tick)
		check("async.max_four_ticks.%d" % calls, now_tick - previous_tick <= 4, "<=4 SDK ticks", now_tick - previous_tick)
		previous_tick = now_tick
		calls += 1
		if bool(tick_result.finished):
			check("async.finishes_without_error", tick_result.error == "", "", tick_result)
	check("async.same_game_state", expected == asynchronous.state(), expected, asynchronous.state())
	check("async.same_sdk_state", expected_hash == asynchronous.world.get_state_hash(), expected_hash, asynchronous.world.get_state_hash())
	synchronous.dispose()
	asynchronous.dispose()

func _physics_classification_frame_boundary() -> void:
	var session = fixture(["#######", "#.....#", "#.B...#", "#Pe...#", "#######"])
	check("settle.phase.begin_dig", session.begin_action("DIG_R").accepted, "dig support below crate", session.state())
	var result: Dictionary = {}
	var calls: int = 0
	while session.busy and str(result.get("phase", "")) != "classification" and calls < 10:
		result = session.advance_settle(4)
		calls += 1
	check("settle.phase.physics_yields_before_classification", str(result.get("phase", "")) == "classification" and session.busy and int(session.state().crates[0].y) == 2, "SDK has four consecutive quiet ticks, no game-layer fall yet", result)
	var after_physics_tick: int = int(session.world.get_stats().tick)
	result = session.advance_settle(4)
	check("settle.phase.classification_without_extra_ticks", int(session.world.get_stats().tick) == after_physics_tick and int(session.state().crates[0].y) == 3 and session.busy, "next frame classifies and applies fall without SDK step", result)
	while session.busy:
		result = session.advance_settle(4)
	check("settle.phase.final_result", bool(result.get("accepted", false)) and str(result.get("error", "")) == "" and int(result.get("ticks", 0)) == 10, "exactly two rounds of one wake tick plus four quiet ticks", result)
	session.dispose()

func _snapshot_files(directory: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var opened: DirAccess = DirAccess.open(directory)
	if opened != null:
		for filename: String in opened.get_files():
			if filename.ends_with(".snap"):
				result.append(filename)
	result.sort()
	return result

func _deferred_safety_matches_default(rows: Array, action: String, label: String, safety_slices: int = 4) -> void:
	var synchronous = fixture(rows)
	var expected_result: Dictionary = synchronous.perform(action)
	var expected_state: Dictionary = synchronous.state()
	var expected_hash: String = synchronous.world.get_state_hash()
	var expected_sequence: Array = synchronous.hash_history.duplicate()
	synchronous.dispose()
	var deferred = fixture(rows)
	var opening: Dictionary = deferred.state()
	var opening_hash: String = deferred.world.get_state_hash()
	var opening_snapshots: PackedStringArray = _snapshot_files(deferred.world.storage_dir)
	var opening_tick: int = int(deferred.world.get_stats().tick)
	var begin: Dictionary = deferred.begin_action(action, true)
	check("deferred.%s.accepts_preparation" % label, begin.accepted and not begin.finished and deferred.busy, "accepted; preparing", begin)
	check("deferred.%s.no_early_grid_change" % label, deferred.state() == opening, opening, deferred.state())
	check("deferred.%s.no_early_sdk_change" % label, deferred.world.get_state_hash() == opening_hash, opening_hash, deferred.world.get_state_hash())
	check("deferred.%s.no_early_snapshot" % label, _snapshot_files(deferred.world.storage_dir) == opening_snapshots, opening_snapshots, _snapshot_files(deferred.world.storage_dir))
	var result: Dictionary = {}
	for slice_index: int in range(safety_slices):
		result = deferred.advance_settle(4)
		check("deferred.%s.safety_no_ticks_%d" % [label, slice_index], int(result.ticks) == 0 and int(deferred.world.get_stats().tick) == opening_tick, opening_tick, deferred.world.get_stats().tick)
		if slice_index < 3:
			check("deferred.%s.only_prepares_slice_%d" % [label, slice_index], deferred.busy and deferred.state() == opening and deferred.world.get_state_hash() == opening_hash, "no effects before all 256 cells checked", deferred.state())
			check("deferred.%s.no_snapshot_slice_%d" % [label, slice_index], _snapshot_files(deferred.world.storage_dir) == opening_snapshots, opening_snapshots, _snapshot_files(deferred.world.storage_dir))
	check("deferred.%s.safe_before_snapshot" % label, deferred.state() == opening and _snapshot_files(deferred.world.storage_dir) == opening_snapshots, "safety complete; snapshot not yet written", deferred.state())
	result = deferred.advance_settle(4)
	check("deferred.%s.sdk_snapshot_before_json" % label, deferred.state() == opening and deferred.world.get_state_hash() == opening_hash and int(result.ticks) == 0 and _snapshot_files(deferred.world.storage_dir).size() == opening_snapshots.size() + 1, "SDK file saved; no commands, game changes or ticks", deferred.state())
	var partial_files: PackedStringArray = _snapshot_files(deferred.world.storage_dir)
	var last_snapshot: String = partial_files[-1]
	check("deferred.%s.json_not_in_sdk_save_frame" % label, not FileAccess.file_exists(deferred.world.storage_dir.path_join(last_snapshot + ".json")), "JSON remains pending until next frame", last_snapshot)
	result = deferred.advance_settle(4)
	check("deferred.%s.commit_after_both_files" % label, int(deferred.state().moves) == 1 and int(result.ticks) == 0 and FileAccess.file_exists(deferred.world.storage_dir.path_join(last_snapshot + ".json")), "SDK plus game JSON saved before applying one move", deferred.state().moves)
	var calls: int = 0
	while deferred.busy and calls < 400:
		result = deferred.advance_settle(4)
		calls += 1
	check("deferred.%s.finished" % label, not deferred.busy and bool(result.get("accepted", false)) and str(result.get("error", "")) == "", "completed without error", result)
	check("deferred.%s.same_game_state" % label, deferred.state() == expected_state, expected_state, deferred.state())
	check("deferred.%s.same_sdk_hash" % label, deferred.world.get_state_hash() == expected_hash, expected_hash, deferred.world.get_state_hash())
	check("deferred.%s.same_tick_count" % label, int(result.get("ticks", -1)) == int(expected_result.ticks), expected_result.ticks, result.get("ticks"))
	check("deferred.%s.same_complete_hash_sequence" % label, deferred.hash_history == expected_sequence and not expected_sequence.is_empty(), expected_sequence, deferred.hash_history.duplicate())
	check("deferred.%s.undo_restores_opening" % label, deferred.undo() and deferred.state() == opening and deferred.world.get_state_hash() == opening_hash, "opening game and SDK state", deferred.state())
	deferred.dispose()

func _deferred_snapshot_lifecycle() -> void:
	for fail_json: bool in [false, true]:
		var session = fixture(["########", "#......#", "#P.B.o.#", "########"])
		var before: Dictionary = session.state()
		var before_hash: String = session.world.get_state_hash()
		var before_tick: int = int(session.world.get_stats().tick)
		var begin: Dictionary = session.begin_action("R", true)
		check("deferred.snapshot.starts.%s" % fail_json, begin.accepted and session.busy and session.state() == before, "pending move", begin)
		session.advance_settle(4)
		var files: PackedStringArray = _snapshot_files(session.world.storage_dir)
		check("deferred.snapshot.partial_sdk.%s" % fail_json, files.size() == 2 and session.state() == before, "opening plus pending SDK file; no move", files)
		if fail_json:
			var json_path: String = session.world.storage_dir.path_join(files[-1] + ".json")
			check("deferred.snapshot.failure_fixture", DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(json_path)) == OK, "directory blocks JSON file write", json_path)
			var result: Dictionary = session.advance_settle(4)
			check("deferred.snapshot.failure_rejected", result.finished and not result.accepted and not str(result.error).is_empty() and not session.busy, "write failure rejects action", result)
			check("deferred.snapshot.failure_no_effect", session.state() == before and session.world.get_state_hash() == before_hash and int(session.world.get_stats().tick) == before_tick and not session.undo(), "no SDK ticks/game move/undo point", session.state())
			check("deferred.snapshot.failure_partial_removed", _snapshot_files(session.world.storage_dir).size() == 1, "only opening snapshot remains", _snapshot_files(session.world.storage_dir))
		var directory: String = session.world.storage_dir
		session.dispose()
		check("deferred.snapshot.dispose_partial.%s" % fail_json, not session.busy and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)), "no abandoned partial snapshot", directory)

func _deferred_preparation_can_be_disposed() -> void:
	var session = fixture(["########", "#......#", "#P.B.o.#", "########"])
	session.perform("R")
	var before: Dictionary = session.state()
	var before_hash: String = session.world.get_state_hash()
	var begin: Dictionary = session.begin_action("R", true)
	check("deferred.lifecycle.preparation_started", begin.accepted and session.busy, "preparing push with prior undo history", begin)
	check("deferred.lifecycle.undo_refused_while_preparing", not session.undo() and session.state() == before, "do not consume prior undo point", session.state())
	check("deferred.lifecycle.restart_refused_while_preparing", not session.restart() and session.world.get_state_hash() == before_hash, before_hash, session.world.get_state_hash())
	session.advance_settle(4)
	var storage: String = session.world.storage_dir
	session.dispose()
	check("deferred.lifecycle.dispose_cancels_preparation", not session.busy and session.world == null and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(storage)), "no pending work or snapshot directory", session.busy)

func _deferred_rejects_lifetime_material() -> void:
	var session = fixture(["#######", "#.....#", "#PB.o.#", "#######"])
	# Reconfigure only this disposable real SDK fixture. A static crate with a
	# lifetime owns a nonzero reg; checking it must reject before any movement.
	var materials: Dictionary = load("res://sim/materials.gd").definitions()
	for material: Dictionary in materials.materials:
		if material.name == "crate":
			material.lifetime = {"min": 255, "max": 255, "to": "empty"}
	var path: String = session.world.storage_dir.path_join("unsafe-test-materials.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(materials))
	file.close()
	session.world.node.set("materials_path", path)
	var started: int = int(session.world.node.call("start"))
	check("deferred.unsafe.real_sdk_fixture_starts", started == 0, 0, session.world.node.call("get_last_error"))
	if started != 0:
		session.dispose()
		return
	session.world.paint_rect(0, 48, 112, 16, "bedrock")
	session.world.paint_rect(32, 32, 16, 16, "crate")
	session.world.step(1)
	var cell: Dictionary = session.world.get_cell(32, 32)
	check("deferred.unsafe.fixture_has_reg", int(cell.get("reg", 0)) > 0, "real SDK nonzero lifetime reg", cell)
	var before: Dictionary = session.state()
	var before_hash: String = session.world.get_state_hash()
	var before_files: PackedStringArray = _snapshot_files(session.world.storage_dir)
	var before_tick: int = int(session.world.get_stats().tick)
	check("deferred.unsafe.default_rejects", not session.can_perform("R").accepted, false, session.can_perform("R"))
	var begin: Dictionary = session.begin_action("R", true)
	check("deferred.unsafe.defers_real_check", begin.accepted and session.busy, "prepare without prematurely rejecting or changing state", begin)
	var result: Dictionary = session.advance_settle(4)
	check("deferred.unsafe.rejected_without_tick", result.finished and not result.accepted and not session.busy and int(result.ticks) == 0 and int(session.world.get_stats().tick) == before_tick, "reject before SDK step", result)
	check("deferred.unsafe.no_game_effects", session.state() == before, before, session.state())
	check("deferred.unsafe.no_sdk_effects", session.world.get_state_hash() == before_hash, before_hash, session.world.get_state_hash())
	check("deferred.unsafe.no_snapshot", _snapshot_files(session.world.storage_dir) == before_files, before_files, _snapshot_files(session.world.storage_dir))
	session.dispose()

func check(id: String, passed: bool, expected: Variant, actual: Variant) -> void:
	checks.append({"id": id, "status": "pass" if passed else "fail", "expected": expected, "actual": actual})

func report() -> Dictionary:
	var ok: bool = not checks.is_empty()
	for item: Dictionary in checks:
		ok = ok and item.status == "pass"
	return {"suite": "gameplay", "runtime": "real-ele-sdk", "ok": ok, "checks": checks}
