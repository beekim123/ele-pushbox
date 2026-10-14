extends SceneTree

var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL: " + message)

func _initialize() -> void:
	if not FileAccess.file_exists("res://pushbox/scripts/board.gd"):
		check(false, "pure board implementation missing")
		quit(1)
		return
	var script: Script = load("res://pushbox/scripts/board.gd")
	var board: RefCounted = script.new()
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://pushbox/rules.json"))
	var materials: Array = JSON.parse_string(FileAccess.get_file_as_string("res://pushbox/content/default/materials.json")).materials
	board.configure(rules, materials)
	board.player = Vector2i(3, 3)
	var ids := PackedInt32Array()
	ids.resize(61440)
	# C01: summing solid into loose would incorrectly return SAND.
	rules.classify.threshold = 152
	board.configure(rules, materials)
	for i in 144:
		ids[(16 + i / 16) * 320 + 16 + i % 16] = 1
	for i in range(144, 152):
		ids[(16 + i / 16) * 320 + 16 + i % 16] = 3
	board.read(ids)
	check(board.category(Vector2i(1, 1)) == "OPEN", "C01: SAND uses loose only")
	# C02: crumble must run without a preceding bomb.
	ids.fill(1)
	for i in 256:
		ids[(16 + i / 16) * 320 + 16 + i % 16] = 2 if i < 64 else 0
	board.read(ids)
	var result: Dictionary = board.resolve_round()
	check(board.counts(Vector2i(1, 1)).breakable == 0, "C02: non-bomb crumble clears remnants")
	check(result.commands.size() == 64, "C02: emits one named empty command per remnant")
	# Class priority and threshold, independent hand-checked inputs.
	ids.fill(0)
	for i in 152:
		ids[(32 + i / 16) * 320 + 32 + i % 16] = 3
	board.read(ids)
	check(board.category(Vector2i(2, 2)) == "SAND", "loose threshold blocks tile")
	check(board.category(Vector2i(-1, 0)) == "SOLID", "world boundary blocks actors")
	print("Board tests: %d failures" % failures)
	quit(1 if failures else 0)
