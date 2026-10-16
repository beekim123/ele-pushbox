extends SceneTree
## Real SDK author replays. Model search results are never used as SDK evidence.
const SESSION = preload("res://gameplay/session/level_session.gd")
const GROUPS: Array[String] = ["blast", "react", "thermal", "experimental"]
var levels: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _digest(value: Variant) -> String:
	return JSON.stringify(value).sha256_text()

func _same(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) in [TYPE_INT,TYPE_FLOAT] and typeof(expected) in [TYPE_INT,TYPE_FLOAT]:
		return float(actual) == float(expected)
	if typeof(actual) in [TYPE_STRING,TYPE_STRING_NAME] and typeof(expected) in [TYPE_STRING,TYPE_STRING_NAME]:
		return str(actual) == str(expected)
	if typeof(actual) != typeof(expected): return false
	if actual is Array:
		if actual.size() != expected.size(): return false
		for index: int in range(actual.size()):
			if not _same(actual[index],expected[index]): return false
		return true
	if actual is Dictionary:
		if actual.size() != expected.size(): return false
		for key: Variant in actual:
			if not expected.has(key) or not _same(actual[key],expected[key]): return false
		return true
	return actual == expected

func _counts(session) -> Dictionary:
	var counts: PackedInt32Array = session.world.count_materials(Rect2i(0, 0, session.width * 16, session.height * 16))
	var output: Dictionary = {}
	for name: String in session.world.material_ids:
		var index: int = int(session.world.material_ids[name])
		if index >= 0 and index < counts.size():
			output[name] = int(counts[index])
	return output

func _sample(session) -> Dictionary:
	var tiles: Dictionary = {}
	for y: int in range(session.height):
		for x: int in range(session.width):
			var counts: PackedInt32Array = session.world.count_materials(session.cell_rect(x, y))
			var tile: Dictionary = {}
			for name: String in session.world.material_ids:
				var index: int = int(session.world.material_ids[name])
				if index >= 0 and index < counts.size() and counts[index] > 0:
					tile[name] = int(counts[index])
			tiles["%d,%d" % [x,y]] = tile
	return {"state": session.state().duplicate(true), "goals":session.goal_lights(), "observe": session.observe().duplicate(true), "materials": _counts(session), "tiles":tiles, "hash": session.world.get_state_hash(), "tick": session.world.get_stats().get("tick", -1)}

func _record_tick(session, output: Array) -> void:
	var probes: Array[Dictionary] = []
	var fuse_tiles: Array[Dictionary] = []
	for y: int in range(session.height):
		for x: int in range(session.width):
			if str(session.spec.map[y]).substr(x,1) in ["w","f","p"]:
				probes.append({"tile":[x,y],"cell":session.world.get_cell(x*16+8,y*16+8)})
			if str(session.spec.map[y]).substr(x,1) == "f":
				fuse_tiles.append({"tile":[x,y],"count":session.material_count(session.cell_rect(x,y),"fuse")})
	var bins: Array[Dictionary] = []
	var spatial: Array[Dictionary] = []
	for index: int in range(session.grid.devices.size()):
		var device: Dictionary = session.grid.devices[index]
		if str(device.get("type", "")) == "bin":
			var rect: Array = device.rect
			bins.append({"device":index,"material":device.get("material","water"),"count":session.material_count(Rect2i(int(rect[0])*16,int(rect[1])*16,int(rect[2])*16,int(rect[3])*16),str(device.get("material","water"))),"need":device.get("need",256),"latched":device.get("latched",false)})
		var points: Array = []
		if str(device.get("type", "")) == "vine": points.append(device.root)
		if str(device.get("type", "")) == "bridge":
			for cell: Array in device.get("cells",[]):
				for offset: int in range(3):
					if int(cell[1])-offset >= 0: points.append([int(cell[0]),int(cell[1])-offset])
		if str(device.get("type", "")) == "seesaw":
			for end: Array in device.ends:
				points.append(end)
				points.append([int(end[0]),int(end[1])-1])
		for point: Array in points:
			var local: PackedInt32Array = session.world.count_materials(session.cell_rect(int(point[0]),int(point[1])))
			var values: Dictionary = {}
			for name: String in session.world.material_ids:
				var id: int = int(session.world.material_ids[name])
				if id >= 0 and id < local.size() and local[id] > 0: values[name] = int(local[id])
			spatial.append({"device":index,"tile":point,"materials":values})
	var materials: Dictionary = _counts(session)
	var observed: Array = session.observe().duplicate(true)
	var entry: Dictionary = {"tick":session.world.get_stats().get("tick", -1),"move":session.grid.moves,"phase":"after_sdk_and_tick_hooks_before_grid_classification","materials":materials,"cells":probes,"fuse_tiles":fuse_tiles,"bins":bins,"probes":spatial,"observe":observed}
	if output.is_empty() or output.back().materials != materials or output.back().cells != probes or output.back().fuse_tiles != fuse_tiles or output.back().bins != bins or output.back().probes != spatial or output.back().observe != observed:
		output.append(entry)

func _run() -> void:
	if not _same({"a":[1,{"x":2}]},{"a":[1.0,{"x":2.0}]}) or _same({"x":1},{"x":2.0}) or _same(true,1):
		printerr("Semantic snapshot comparator failed its numeric/type controls")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/content-manifest.json"))
	var only: String = OS.get_environment("PORTITOR_VERIFY_GROUP")
	if not only.is_empty() and only not in GROUPS:
		printerr("Unknown chapter group: " + only)
		quit(1)
		return
	var ids: PackedStringArray = OS.get_environment("PORTITOR_VERIFY_LEVELS").split(",", false)
	for group: Dictionary in manifest.groups:
		if group.mode != "lab" or str(group.id) not in GROUPS or not only.is_empty() and str(group.id) != only:
			continue
		for entry: Dictionary in group.levels:
			if not ids.is_empty() and str(entry.id) not in ids:
				continue
			var location: String = "res://generated/" + str(entry.spec)
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(location)
			var hashing := HashingContext.new()
			hashing.start(HashingContext.HASH_SHA256)
			hashing.update(bytes)
			var digest: String = hashing.finish().hex_encode()
			if digest != str(entry.sha256):
				levels.append({"id":entry.id, "group":group.id, "won":false, "replays":0, "consistent":false, "undo_ok":false, "max_ticks":0, "tick_limit":1200, "checks":[{"text":"spec SHA matches imported manifest", "ok":false}], "issues":[{"step":0,"reason":"spec SHA mismatch"}]})
				continue
			var spec: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
			_replay(spec, digest)
			await process_frame
	var ok: bool = not levels.is_empty() and levels.all(func(item: Dictionary) -> bool: return bool(item.get("sdk_verified", false)))
	var result: Dictionary = {"format":"portitor.chapter-sdk/1", "suite":"chapters", "ok":ok, "complete":true, "subset":not only.is_empty() or not ids.is_empty(), "levels":levels}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
	var output_path: String = "res://tests/results/chapters" + ("-" + only if not only.is_empty() else "") + ".json"
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write chapter evidence")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite":"chapters", "ok":ok, "levels":levels.size(), "complete":true}))
	quit(0 if ok else 1)

func _replay(spec: Dictionary, digest: String) -> void:
	var runs: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	var trace: Array[Dictionary] = []
	var physics: Array[Dictionary] = []
	var max_ticks: int = 0
	var max_rounds: int = 0
	var undo_ok: bool = true
	var restart_ok: bool = true
	var setup_ok: bool = true
	for repeat_index: int in range(3):
		var session = SESSION.new()
		session.render_enabled = false
		if not session.setup(spec):
			setup_ok = false
			issues.append({"run":repeat_index + 1,"step":0,"reason":session.last_error})
			runs.append({"won":false,"accepted_steps":0,"error":session.last_error,"sequence_sha256":""})
			session.dispose()
			continue
		var opening: Dictionary = _sample(session)
		if repeat_index == 0:
			var base_observer: Callable = session.world.tick_observer
			session.world.tick_observer = func() -> void:
				base_observer.call()
				_record_tick(session, physics)
		var sequence: Array = [session.hash_history.duplicate()]
		var before: Array[Dictionary] = []
		var before_hashes: Array[String] = []
		var before_observe: Array = []
		var accepted: int = 0
		var rejected: bool = false
		if repeat_index == 0:
			trace.append({"step":0,"action":"opening","actual":_sample(session)})
		for step_index: int in range(spec.solution.size()):
			var initial: Dictionary = session.state().duplicate(true)
			var sdk_hash: String = session.world.get_state_hash()
			var observation: Array = session.observe().duplicate(true)
			var action: String = str(spec.solution[step_index])
			var result: Dictionary = session.perform(action)
			max_ticks = maxi(max_ticks, int(result.get("ticks",0)))
			max_rounds = maxi(max_rounds, int(result.get("rounds",0)))
			sequence.append(result.get("hashes",[]))
			if repeat_index == 0:
				var measured: Dictionary = result.duplicate(true)
				measured["tick_hash_count"] = result.get("hashes", []).size()
				measured["tick_sequence_sha256"] = _digest(result.get("hashes", []))
				measured.erase("hashes")
				trace.append({"step":step_index + 1,"action":action,"result":measured,"actual":_sample(session)})
			if not bool(result.get("accepted",false)) or not str(result.get("error","")).is_empty():
				rejected = true
				issues.append({"run":repeat_index + 1,"step":step_index + 1,"action":action,"reason":result.get("reason", result.get("error","rejected")),"actual":session.state()})
				break
			before.append(initial)
			before_hashes.append(sdk_hash)
			before_observe.append(observation)
			accepted += 1
		var won: bool = not rejected and accepted == spec.solution.size() and session.is_won()
		if not won and not rejected:
			issues.append({"run":repeat_index + 1,"step":accepted,"reason":"author sequence ended without all goal lamps","actual":session.state(),"goals":session.goal_lights()})
		var ending: Dictionary = _sample(session)
		var run_restart: bool = session.restart() and _same(session.state(), opening.state) and session.world.get_state_hash() == opening.hash and _same(session.observe(), opening.observe)
		var restart_undo: bool = session.undo() and _same(session.state(), ending.state) and session.world.get_state_hash() == ending.hash and _same(session.observe(), ending.observe)
		restart_ok = restart_ok and run_restart and restart_undo
		if not run_restart or not restart_undo:
			issues.append({"run":repeat_index + 1,"step":accepted,"reason":"restart or undo-restart differs","restart_ok":run_restart,"undo_restart_ok":restart_undo})
		var run_undo: bool = true
		for undo_index: int in range(before.size() - 1, -1, -1):
			var restored: bool = session.undo()
			var matches: bool = restored and _same(session.state(), before[undo_index]) and session.world.get_state_hash() == before_hashes[undo_index] and _same(session.observe(), before_observe[undo_index])
			if not matches:
				run_undo = false
				issues.append({"run":repeat_index + 1,"undo_to_step":undo_index,"reason":"undo game/SDK/observations differ","game_same":_same(session.state(),before[undo_index]),"sdk_hash_same":session.world.get_state_hash() == before_hashes[undo_index],"observe_same":_same(session.observe(),before_observe[undo_index]),"expected":before[undo_index],"actual":session.state(),"expected_observe":before_observe[undo_index],"actual_observe":session.observe()})
		undo_ok = undo_ok and run_undo
		runs.append({"won":won,"accepted_steps":accepted,"undo_ok":run_undo,"restart_ok":run_restart and restart_undo,"sequence_sha256":_digest(sequence)})
		session.dispose()
	var consistent: bool = setup_ok and runs.size() == 3 and runs[0] == runs[1] and runs[1] == runs[2]
	var won: bool = setup_ok and runs.size() == 3 and runs.all(func(item: Dictionary) -> bool: return bool(item.won))
	var complete_actions: bool = setup_ok and runs.all(func(item: Dictionary) -> bool: return int(item.accepted_steps) == spec.solution.size())
	var limits_ok: bool = setup_ok and max_ticks < 1200 and max_rounds < 16
	var checks: Array[Dictionary] = [
		{"text":"author solution wins on real SDK in three runs","ok":won,"status":"pass" if won else "fail"},
		{"text":"three complete tick hash sequences agree","ok":consistent,"status":"pass" if consistent else "fail"},
		{"text":"every accepted action restores game, SDK and observations on undo","ok":setup_ok and undo_ok,"status":"pass" if setup_ok and undo_ok else "fail"},
		{"text":"restart and undo-restart preserve opening and final snapshots","ok":setup_ok and restart_ok,"status":"pass" if setup_ok and restart_ok else "fail"},
		{"text":"settlement stays below 1200 ticks and 16 rounds","ok":limits_ok,"status":"pass" if limits_ok else "fail"}]
	var spec_checks: Array[Dictionary] = []
	for text: String in spec.get("checks",[]):
		var generic_author: bool = text.contains("作者解合法并点亮全部目标灯") and text.contains("3 次结果一致")
		var generic_undo: bool = text.begins_with("待真实 SDK 验收：每一步撤销及重开") or text.begins_with("待真实 SDK / 游戏联合验收：每一步撤销及重开")
		var status: String = "not_run"
		var detail: String = "Requires its dedicated assertion; author victory alone does not prove this claim. Inspect measured steps/material counts."
		if generic_author:
			status = "pass" if won and consistent else "fail"
			detail = "Three author replays and complete per-tick sequence digests."
		# Restart-specific and isolated negative cases are deliberately never inferred from undo.
		if generic_undo:
			status = "pass" if complete_actions and undo_ok and restart_ok and limits_ok else "fail"
			detail = "Every action's undo, restart, undo-restart, ticks and rounds measured on three SDK runs."
		var row: Dictionary = {"text":text,"ok":status == "pass","status":status,"detail":detail}
		spec_checks.append(row)
	var summary: Dictionary = {"won":won,"consistent":consistent,"undo_ok":setup_ok and undo_ok,"restart_ok":setup_ok and restart_ok,"complete_actions":complete_actions,"limits_ok":limits_ok,"max_ticks":max_ticks,"max_rounds":max_rounds,"physics":physics}
	var acceptance_path: String = "res://tests/chapters/" + str(spec.group) + ".gd"
	if FileAccess.file_exists(acceptance_path):
		var implementation: Script = load(acceptance_path)
		if implementation != null:
			var verifier: RefCounted = implementation.new()
			var supplied: Array = verifier.evaluate(spec, trace, runs, summary)
			for index: int in range(spec_checks.size()):
				for candidate: Dictionary in supplied:
					if candidate.get("text") == spec_checks[index].text:
						spec_checks[index] = candidate
						break
	levels.append({"id":spec.id,"uid":"level:" + str(spec.id),"group":spec.group,"spec_sha256":digest,"won":won,"replays":runs.size(),"consistent":consistent,"undo_ok":setup_ok and undo_ok,"restart_ok":setup_ok and restart_ok,"max_ticks":max_ticks,"max_rounds":max_rounds,"tick_limit":1200,"round_limit":16,"author_solution_verified":won and consistent and undo_ok and limits_ok,"sdk_verified":checks.all(func(c: Dictionary)->bool:return c.ok) and spec_checks.all(func(c: Dictionary)->bool:return c.ok),"runs":runs,"checks":checks,"spec_checks":spec_checks,"issues":issues,"steps":trace,"physics":physics})
	print("CHAPTER_RESULT=" + JSON.stringify({"id":spec.id,"won":won,"consistent":consistent,"undo_ok":undo_ok,"max_ticks":max_ticks,"max_rounds":max_rounds,"issues":issues.size()}))
