class_name SdkSampleTests
extends SceneTree
## Real SDK characterization tests. No design-model substitution is permitted.

var checks: Array[Dictionary] = []

func _initialize() -> void:
	create_timer(45.0).timeout.connect(_watchdog_timeout)
	call_deferred("_main")

func _main() -> void:
	var result: Variant = run()
	if not result is Dictionary or not result.has("ok"):
		print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "sdk", "ok": false, "error": "test runner aborted"}))
		quit(1)
		return
	_emit_report(result)
	quit(0 if result.ok else 1)

func _emit_report(result: Dictionary) -> void:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
	var path: String = "res://tests/results/sdk.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE) if directory_error == OK else null
	if file == null:
		result.ok = false
		result.error = "Cannot write SDK test report"
	else:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	var failures: Array[String] = []
	for item: Dictionary in result.get("checks", []):
		if item.status != "pass":
			failures.append(str(item.id))
	print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "sdk", "ok": result.ok, "check_count": result.get("checks", []).size(), "failed": failures, "report": path}))

func _watchdog_timeout() -> void:
	print("PORTITOR_TEST_RESULT=" + JSON.stringify({"suite": "sdk", "ok": false, "error": "test runner timeout"}))
	quit(1)

func run() -> Dictionary:
	checks.clear()
	if not FileAccess.file_exists("res://sim/ele_world.gd"):
		check("sdk.adapter_exists", false, "Real SDK adapter must exist", "missing")
		return report()
	if not ClassDB.class_exists("EleWorld"):
		check("sdk.extension_loaded", false, "EleWorld registered", "missing")
		return report()
	_sample_sand()
	_sample_earth()
	_sample_crates()
	_sample_quiet()
	_sample_snapshot()
	return report()

func new_world(seed_value: int = 17):
	var world = load("res://sim/ele_world.gd").new()
	check("sdk.start.%d" % checks.size(), world.open(seed_value, false), "SDK starts", world.last_error)
	return world

func settle_world(world, label: String) -> Dictionary:
	var result: Dictionary = load("res://sim/settle.gd").new().run(world)
	check(label + ".settled", result.ok, "4 quiet ticks before 1200", result)
	return result

func _sample_sand() -> void:
	var world = new_world()
	if not world.is_started():
		world.dispose()
		return
	world.paint_rect(0, 128, 320, 64, "bedrock")
	world.paint_rect(128, 0, 16, 128, "bedrock")
	world.paint_rect(112, 112, 16, 16, "sand", 2)
	settle_world(world, "sample.a")
	var total: int = world.count_material("sand", Rect2i(0, 0, 320, 192))
	var target: int = world.count_material("sand", Rect2i(112, 112, 16, 16))
	var neighbour: int = world.count_material("sand", Rect2i(96, 112, 16, 16))
	check("sample.a.conserves_256_cells", total == 256, 256, total)
	check("sample.a.target_classifies_sand", target >= 128, ">=128", target)
	check("sample.a.neighbour_under_128", neighbour < 128, "<128", neighbour)
	check("sample.a.total_spill_under_128", total - target < 128, "<128", total - target)
	world.dispose()

func _sample_earth() -> void:
	var world = new_world()
	if not world.is_started():
		world.dispose()
		return
	world.paint_rect(32, 32, 16, 32, "packed_earth")
	settle_world(world, "sample.b.initial")
	world.clear_rect(32, 48, 16, 16)
	settle_world(world, "sample.b.dug")
	check("sample.b.upper_earth_static", world.count_material("packed_earth", Rect2i(32, 32, 16, 16)) == 256, 256, world.count_material("packed_earth", Rect2i(32, 32, 16, 16)))
	check("sample.b.lower_earth_removed", world.count_material("packed_earth", Rect2i(32, 48, 16, 16)) == 0, 0, world.count_material("packed_earth", Rect2i(32, 48, 16, 16)))
	world.dispose()

func _sample_crates() -> void:
	var world = new_world()
	if not world.is_started():
		world.dispose()
		return
	world.paint_rect(32, 64, 16, 16, "crate")
	settle_world(world, "sample.c.initial")
	for destination: int in [48, 64, 80]:
		world.clear_rect(destination - 16, 64, 16, 16)
		world.paint_rect(destination, 64, 16, 16, "crate")
		settle_world(world, "sample.c.move_%d" % destination)
		check("sample.c.material_count_%d" % destination, world.count_material("crate", Rect2i(0, 0, 320, 192)) == 256, 256, world.count_material("crate", Rect2i(0, 0, 320, 192)))
		check("sample.c.target_full_%d" % destination, world.count_material("crate", Rect2i(destination, 64, 16, 16)) == 256, 256, world.count_material("crate", Rect2i(destination, 64, 16, 16)))
		check("sample.c.source_empty_%d" % destination, world.count_material("crate", Rect2i(destination - 16, 64, 16, 16)) == 0, 0, world.count_material("crate", Rect2i(destination - 16, 64, 16, 16)))
	world.dispose()

func _sample_quiet() -> void:
	var world = new_world()
	if not world.is_started():
		world.dispose()
		return
	world.paint_rect(0, 128, 320, 64, "bedrock")
	world.paint_rect(128, 96, 16, 16, "sand")
	var result: Dictionary = settle_world(world, "sample.d")
	check("sample.d.four_quiet_ticks", int(result.get("quiet", 0)) >= 4, ">=4", result.get("quiet", 0))
	var first_hash: String = world.get_state_hash()
	var first_ids: PackedInt32Array = world.get_material_ids(0, 0, 320, 192)
	for i: int in range(8):
		world.step(1)
		var stats: Dictionary = world.get_stats()
		check("sample.d.quiet_%d" % i, stats.active_chunks == 0 and stats.queue_size == 0 and stats.pressure_moves == 0, "no pending physics", stats)
	check("sample.d.materials_remain_static", first_ids == world.get_material_ids(0, 0, 320, 192), "same material ids", "compared all 61440 cells")
	check("sample.d.hash_includes_tick", first_hash != world.get_state_hash(), "different hash after 8 ticks", world.get_state_hash())
	world.dispose()

func _sample_snapshot() -> void:
	var world = new_world()
	if not world.is_started():
		world.dispose()
		return
	world.paint_rect(0, 128, 320, 64, "bedrock")
	world.paint_rect(64, 112, 16, 16, "crate")
	settle_world(world, "sample.e.initial")
	var before_hash: String = world.get_state_hash()
	var before_ids: PackedInt32Array = world.get_material_ids(0, 0, 320, 192)
	var path: String = world.storage_dir.path_join("sample.snap")
	check("sample.e.save", world.save_snapshot(path) == 0, 0, world.last_error)
	world.clear_rect(64, 112, 16, 16)
	world.paint_rect(80, 112, 16, 16, "crate")
	settle_world(world, "sample.e.changed")
	check("sample.e.load", world.load_snapshot(path) == 0, 0, world.last_error)
	check("sample.e.restores_hash", before_hash == world.get_state_hash(), before_hash, world.get_state_hash())
	check("sample.e.restores_all_cells", before_ids == world.get_material_ids(0, 0, 320, 192), "61440 identical material ids", "full world comparison")
	world.dispose()

func check(id: String, passed: bool, expected: Variant, actual: Variant) -> void:
	checks.append({"id": id, "status": "pass" if passed else "fail", "expected": expected, "actual": actual})

func report() -> Dictionary:
	var ok: bool = not checks.is_empty()
	for item: Dictionary in checks:
		ok = ok and item.status == "pass"
	return {"suite": "sdk", "runtime": "real-ele-sdk", "ok": ok, "checks": checks.duplicate(true)}
