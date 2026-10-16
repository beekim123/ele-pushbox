class_name LevelReplayTests
extends SceneTree
## Every report check comes from an executed assertion against the real SDK.

var checks: Array[Dictionary] = []
var levels: Array[Dictionary] = []

func _initialize() -> void:
	create_timer(45.0).timeout.connect(_watchdog_timeout)
	call_deferred("_main")

func _main() -> void:
	var result: Variant = run()
	if not result is Dictionary or not result.has("ok"):
		print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "levels", "ok": false, "error": "test runner aborted"}))
		quit(1)
		return
	_emit_report(result)
	quit(0 if result.ok else 1)

func _emit_report(result: Dictionary) -> void:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
	var path: String = "res://tests/results/levels.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE) if directory_error == OK else null
	if file == null:
		result.ok = false
		result.error = "Cannot write level test report"
	else:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	var failures: Array[String] = []
	for item: Dictionary in result.get("checks", []):
		if item.status != "pass":
			failures.append(str(item.id))
	print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "levels", "ok": result.ok, "check_count": result.get("checks", []).size(), "failed": failures, "report": path}))

func _watchdog_timeout() -> void:
	print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "levels", "ok": false, "error": "test runner timeout"}))
	quit(1)

func run() -> Dictionary:
	checks.clear()
	levels.clear()
	check("model.comparison.integer_json_number", _same_value({"x": 1}, {"x": 1.0}), "same numeric coordinate", {"int": 1, "json": 1.0})
	check("model.comparison.reject_wrong_coordinate", not _same_value({"x": 1}, {"x": 2.0}), "different coordinates remain different", {"actual": 1, "expected": 2.0})
	check("model.comparison.reject_fractional_coordinate", not _same_value({"x": 1}, {"x": 1.25}), "fractional difference remains different", {"actual": 1, "expected": 1.25})
	check("model.comparison.reject_boolean_number", not _same_value(false, 0), "boolean distinct from coordinate", {"boolean": false, "number": 0})
	if not FileAccess.file_exists("res://tests/levels/model_expected.json"):
		check("model.expected_states_exist", false, "run node game/tools/export_model.mjs first", "missing")
		return report()
	if not FileAccess.file_exists("res://gameplay/session/level_session.gd"):
		check("levels.session_exists", false, "LevelSession implementation", "missing")
		return report()
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/levels/model_expected.json"))
	if not expected is Dictionary or not expected.get("routes") is Dictionary:
		check("model.expected_states_valid", false, "object with routes dictionary", expected)
		return report()
	var manifest_path: String = "res://generated/content-manifest.json"
	if not FileAccess.file_exists(manifest_path):
		check("levels.content_manifest", false, "imported content manifest", manifest_path + " missing")
		return report()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or not manifest.get("groups") is Array:
		check("levels.content_manifest", false, "imported content manifest", "missing or malformed")
		return report()
	for group: Dictionary in manifest.groups:
		if group.id != "basics" or group.mode != "lab":
			continue
		for entry: Dictionary in group.levels:
			var spec_path: String = "res://generated/" + str(entry.spec)
			if not FileAccess.file_exists(spec_path):
				check("%s.spec_exists" % entry.id, false, "imported level spec", spec_path + " missing")
				continue
			var spec_bytes: PackedByteArray = FileAccess.get_file_as_bytes(spec_path)
			var hashing: HashingContext = HashingContext.new()
			hashing.start(HashingContext.HASH_SHA256)
			hashing.update(spec_bytes)
			var digest: String = hashing.finish().hex_encode()
			check("%s.spec_hash" % entry.id, digest == entry.sha256, entry.sha256, digest)
			var spec: Variant = JSON.parse_string(spec_bytes.get_string_from_utf8())
			if not spec is Dictionary or not spec.get("solution") is Array:
				check("%s.spec_json" % entry.id, false, "object with solution array", spec)
				continue
			var uid: String = "level:" + str(entry.id)
			if not expected.routes.has(uid):
				check("%s.model_export" % entry.id, false, "independent expected states", "missing")
				continue
			_replay(spec, expected.routes[uid], digest)
	return report()

func _replay(spec: Dictionary, model_steps: Array, spec_hash: String) -> void:
	var first_check: int = checks.size()
	var hash_runs: Array = []
	var won_runs: Array[bool] = []
	var max_ticks: int = 0
	var max_rounds: int = 0
	var max_advance_us: int = 0
	var max_undo_us: int = 0
	var all_steps: Array = []
	for repeat_index: int in range(3):
		var prefix: String = "%s.run%d" % [spec.id, repeat_index + 1]
		var session = load("res://gameplay/session/level_session.gd").new()
		session.render_enabled = false
		var started: bool = session.setup(spec)
		check(prefix + ".setup", started, "real SDK setup settles", session.last_error)
		if not started:
			session.dispose()
			continue
		var hashes: Array = session.hash_history.duplicate()
		var before_states: Array[Dictionary] = []
		var before_hashes: Array[String] = []
		check(prefix + ".model_initial", _same(session.state(), model_steps[0]), model_steps[0], session.state())
		for step_index: int in range(spec.solution.size()):
			before_states.append(session.state())
			before_hashes.append(session.world.get_state_hash())
			var result: Dictionary = session.perform(str(spec.solution[step_index]))
			var step_key: String = prefix + ".step%d" % (step_index + 1)
			check(step_key + ".accepted", result.accepted, true, result)
			check(step_key + ".settles", result.error == "" and result.ticks < 1200, "no error; <1200 ticks", result)
			check(step_key + ".model", _same(session.state(), model_steps[step_index + 1]), model_steps[step_index + 1], session.state())
			var stable_state: Dictionary = session.state()
			check(step_key + ".bag_range", int(stable_state.bag.sand) >= 0 and int(stable_state.bag.sand) <= 9, "0..9", stable_state.bag.sand)
			check(step_key + ".wood_cells_conserved", session.world.count_material("crate", Rect2i(0, 0, 320, 192)) == stable_state.crates.filter(func(crate): return crate.kind == "wood").size() * 256, "256 cells per wood crate", session.world.count_material("crate", Rect2i(0, 0, 320, 192)))
			for crate: Dictionary in stable_state.crates:
				var material: String = "iron_crate" if crate.kind == "iron" else "crate"
				check(step_key + ".crate_%d_%d.full" % [crate.x, crate.y], session.world.count_material(material, session.cell_rect(int(crate.x), int(crate.y))) == 256, 256, session.world.count_material(material, session.cell_rect(int(crate.x), int(crate.y))))
			_acceptance(spec, session, str(spec.solution[step_index]), step_key)
			max_ticks = maxi(max_ticks, int(result.ticks))
			max_rounds = maxi(max_rounds, int(result.get("rounds", 0)))
			max_advance_us = maxi(max_advance_us, int(result.get("max_advance_us", 0)))
			if repeat_index == 0:
				all_steps.append({"action": spec.solution[step_index], "ticks": result.ticks, "state": session.state(), "hash": session.world.get_state_hash()})
			hashes.append_array(result.get("hashes", []))
		var did_win: bool = bool(session.state().won)
		won_runs.append(did_win)
		check(prefix + ".won", did_win, true, did_win)
		hash_runs.append(hashes)
		for step_index: int in range(before_states.size() - 1, -1, -1):
			var undo_started: int = Time.get_ticks_usec()
			var undo_succeeded: bool = session.undo()
			max_undo_us = maxi(max_undo_us, Time.get_ticks_usec() - undo_started)
			check(prefix + ".undo%d" % step_index, undo_succeeded, true, session.last_error)
			check(prefix + ".undo%d.game_state" % step_index, _same(session.state(), before_states[step_index]), before_states[step_index], session.state())
			check(prefix + ".undo%d.sdk_hash" % step_index, session.world.get_state_hash() == before_hashes[step_index], before_hashes[step_index], session.world.get_state_hash())
		session.dispose()
	var consistent: bool = hash_runs.size() == 3 and hash_runs[0] == hash_runs[1] and hash_runs[1] == hash_runs[2]
	check(str(spec.id) + ".three_hash_runs", consistent, "three identical per-tick sequences", hash_runs.map(func(sequence): return sequence.size()))
	var level_checks: Array = checks.slice(first_check)
	var passed: bool = true
	var undo_ok: bool = true
	for item: Dictionary in level_checks:
		passed = passed and item.status == "pass"
		if ".undo" in str(item.id):
			undo_ok = undo_ok and item.status == "pass"
	var every_run_won: bool = won_runs.size() == 3 and not won_runs.has(false)
	var alternative: Dictionary = {}
	var specification_checks: Array = _spec_acceptance(spec, level_checks)
	var acceptance_ok: bool = true
	for requirement: Dictionary in specification_checks:
		acceptance_ok = acceptance_ok and requirement.status == "pass"
	levels.append({
		"id": spec.id, "uid": "level:" + str(spec.id), "spec_sha256": spec_hash,
		"sdk_verified": passed, "author_solution_verified": passed, "acceptance_ok": acceptance_ok,
		"won": every_run_won, "replays": hash_runs.size(), "repeats": hash_runs.size(),
		"consistent": consistent, "undo_ok": undo_ok, "max_ticks": max_ticks, "max_settle_ticks": max_ticks,
		"tick_limit": 1200, "max_rounds": max_rounds, "round_limit": 16,
		"max_advance_us": max_advance_us, "max_undo_us": max_undo_us,
		"checks": level_checks, "spec_checks": specification_checks, "alternative": alternative, "steps": all_steps
	})

func _acceptance(spec: Dictionary, session, action: String, prefix: String) -> void:
	var current: Dictionary = session.state()
	match str(spec.id):
		"M03":
			if action == "DIG_R":
				check(prefix + ".upper_earth_static", session.world.count_material("packed_earth", Rect2i(48, 32, 16, 16)) == 256 and int(current.bag.sand) == 1, "upper earth256; bag1", {"earth": session.world.count_material("packed_earth", Rect2i(48, 32, 16, 16)), "bag": current.bag.sand})
		"M04":
			if action == "POUR_R":
				var target: int = session.world.count_material("sand", Rect2i(80, 64, 16, 16))
				var neighbour: int = session.world.count_material("sand", Rect2i(64, 64, 16, 16))
				check(prefix + ".sand_step_majority", target >= 128 and int(current.terrain[4 * session.width + 5]) == 4, "target>=128; terrain SAND", target)
				check(prefix + ".spill_under_majority", neighbour < 128, "<128", neighbour)
		"M07":
			if action == "DIG_R":
				check(prefix + ".fall_opens_same_settle", int(current.crates[0].y) == 4 and current.doors[0] and int(current.bag.sand) == 1, "box on plate; door open; bag1", current)

func _spec_acceptance(spec: Dictionary, local_checks: Array) -> Array:
	var pool: Dictionary = {}
	for item: Dictionary in local_checks:
		pool[str(item.id)] = str(item.status)
	for suite: String in ["sdk", "gameplay"]:
		var path: String = "res://tests/results/" + suite + ".json"
		if not FileAccess.file_exists(path):
			continue
		var external: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not external is Dictionary or not external.get("checks") is Array:
			continue
		for item: Dictionary in external.checks:
			pool[suite + ":" + str(item.id)] = str(item.status)
	var coverage: Dictionary = {
		"M01": [["*.won", "*.undo*.game_state"], ["gameplay:move.reject_two_high", "gameplay:push.reject_chain"]],
		"M02": [["*.won", "*.undo*.game_state"], ["gameplay:ladder.holds_player", "gameplay:ladder.leave_and_fall", "gameplay:async.same_game_state"]],
		"M03": [["*.won", "*.undo*.game_state"], ["*.upper_earth_static", "*.bag_range"]],
		"M04": [["*.sand_step_majority", "gameplay:move.one_step_up"], ["*.won"], ["sdk:sample.a.target_classifies_sand", "sdk:sample.a.total_spill_under_128"]],
		"M05": [["gameplay:plate.fallen_box_opens"], ["gameplay:plate.person_opens", "gameplay:door.occupied_stays_open", "gameplay:door.closes_after_clear"]],
		"M06": [["*.won"], ["*.undo*.game_state", "*.undo*.sdk_hash"]],
		"M07": [["*.fall_opens_same_settle"], ["*.undo*.game_state", "*.undo*.sdk_hash"]]
	}
	var patterns: Array = coverage.get(str(spec.id), [])
	var output: Array = []
	var texts: Array = spec.get("checks", [])
	for index: int in range(texts.size()):
		var references: Array[String] = []
		var status: String = "pass"
		if index >= patterns.size():
			status = "not_run"
		else:
			for pattern: String in patterns[index]:
				var matched: bool = false
				for id: String in pool:
					if id.match(pattern):
						matched = true
						references.append(id)
						if pool[id] == "fail":
							status = "fail"
						elif pool[id] != "pass" and status != "fail":
							status = "not_run"
				if not matched and status != "fail":
					status = "not_run"
		var row: Dictionary = {"text": str(texts[index]), "status": status, "assertions": references}
		output.append(row)
	return output

func _same(actual: Dictionary, expected: Dictionary) -> bool:
	for key: String in ["w", "h", "player", "crates", "terrain", "bag", "doors", "moves", "won"]:
		var observed: Variant = actual.get(key)
		var reference: Variant = expected.get(key)
		if key == "crates":
			observed = actual.get(key, []).map(func(c: Dictionary) -> Dictionary: return {"x": c.x, "y": c.y, "kind": c.kind})
		if key == "crates":
			reference = expected.get(key, []).map(func(c: Dictionary) -> Dictionary: return {"x": c.x, "y": c.y, "kind": c.kind})
		if not _same_value(observed, reference):
			return false
	return true

func _same_value(actual: Variant, expected: Variant) -> bool:
	var actual_type: int = typeof(actual)
	var expected_type: int = typeof(expected)
	if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type in [TYPE_INT, TYPE_FLOAT]:
		return float(actual) == float(expected)
	if actual_type != expected_type:
		return false
	if actual is Array:
		if actual.size() != expected.size():
			return false
		for index: int in range(actual.size()):
			if not _same_value(actual[index], expected[index]):
				return false
		return true
	if actual is Dictionary:
		if actual.size() != expected.size():
			return false
		for key: Variant in actual:
			if not expected.has(key) or not _same_value(actual[key], expected[key]):
				return false
		return true
	return actual == expected

func check(id: String, passed: bool, expected: Variant, actual: Variant) -> void:
	checks.append({"id": id, "status": "pass" if passed else "fail", "expected": expected, "actual": actual})

func report() -> Dictionary:
	var ok: bool = checks.size() > 0
	for item: Dictionary in checks:
		ok = ok and item.status == "pass"
	return {"suite": "levels", "runtime": "real-ele-sdk", "ok": ok, "checks": checks, "levels": levels}
