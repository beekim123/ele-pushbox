extends SceneTree
## Run generator first, then Godot --path game --script res://tests/refs/test_render.gd.
## This CPU oracle covers integer background/environment behavior; GPU parity is
## separately tested by test_terrain_shader.gd using a rendering driver.
var raster_script: GDScript
var background_script: GDScript
var environment_script: GDScript
var ambient_script: GDScript
var sprites_script: GDScript
var failures: Array[String] = []

class BindingSession extends RefCounted:
	var spec: Dictionary
	var snapshot: Dictionary
	func state() -> Dictionary:
		return snapshot.duplicate(true)

class BindingView extends "res://presentation/render/world_view.gd":
	var refresh_calls: int = 0
	var observed_state: Dictionary = {}
	func refresh() -> void:
		refresh_calls += 1
		observed_state = session.state() if session != null else {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dependencies: Array[String] = ["res://presentation/render/palette_raster.gd", "res://presentation/render/themes/background.gd", "res://presentation/render/env/environment.gd", "res://presentation/render/ambient/ambient.gd"]
	for dependency: String in dependencies:
		if not FileAccess.file_exists(dependency):
			push_error("Missing renderer: " + dependency)
			quit(1)
			return
	raster_script = load(dependencies[0])
	background_script = load(dependencies[1])
	environment_script = load(dependencies[2])
	ambient_script = load(dependencies[3])
	sprites_script = load("res://presentation/render/sprites/sprite_assets.gd")
	var file := FileAccess.open("res://tests/refs/workbench.reference.json", FileAccess.READ)
	if file == null:
		push_error("Generate oracle: node game/tests/refs/generate_workbench_refs.mjs")
		quit(1)
		return
	var refs: Dictionary = JSON.parse_string(file.get_as_text())
	for item: Dictionary in refs.hashes:
		_check(raster_script.h32(int(item.p[0]), int(item.p[1]), int(item.p[2])) == int(item.expected), "h32 %s" % str(item.p))
	for item: Dictionary in refs.triangles:
		_check(ambient_script.tri(int(item.p[0]), int(item.p[1]), int(item.p[2])) == int(item.expected), "triangle %s" % str(item.p))
	for item: Dictionary in refs.get("frames", []):
		_check(sprites_script.frame_at(root.get_node("Registry").art(item.uid), item.name, int(item.tick)) == int(item.expected), "sprite frame %s" % str(item))
	for item: Dictionary in refs.cases:
		var theme: Dictionary = root.get_node("Registry").art(item.theme).params
		var raster: RefCounted = raster_script.new(320, 180)
		background_script.draw(raster, theme, Rect2i(0, 0, 320, 180), int(item.tick))
		_compare(raster, item.background, "%s/%s/background" % [item.theme, item.tick])
		var incremental: RefCounted = raster_script.new(320, 180)
		background_script.draw_static(incremental, theme, Rect2i(0, 0, 320, 180))
		background_script.draw_dynamic(incremental, theme, Rect2i(0, 0, 320, 180), int(item.tick))
		_compare(incremental, item.background, "%s/%s/background-static-plus-dynamic" % [item.theme, item.tick])
		var map: Dictionary = {"w": 8, "h": 5, "terrain": []}
		for row: String in item.materials:
			for x: int in range(row.length()):
				map.terrain.append(row.substr(x, 1).to_int())
		for mode: String in ["sparse", "one", "full"]:
			var commands: Array[Dictionary] = []
			var occupied: Callable = func(x: int, y: int) -> bool: return x == 1 and y == 1
			for layer: String in ["back", "front"]:
				commands.append_array(ambient_script.plan(theme, map, Vector2i(40, 30), int(item.tick), layer, occupied, Rect2i(56, 46, 96, 48), Callable(), {"mode": mode, "seed": ambient_script.seed_of("M03")}))
			_compare_commands(commands, item.ambient[mode], "%s/%s/ambient/%s" % [item.theme, item.tick, mode])
		for mode: String in ["full", "lite", "off"]:
			var copy: RefCounted = raster.copy()
			var ctx := {"tick": int(item.tick), "area": Rect2i(40, 30, 240, 140), "lights": [{"id": "deco.dungeon_torch", "x": 80, "y": 50}], "level": mode}
			for phase: String in ["back", "light", "front"]:
				environment_script.draw(copy, theme, phase, ctx)
			_compare(copy, item[mode], "%s/%s/%s" % [item.theme, item.tick, mode])
	for item: Dictionary in refs.get("lighting_edges", []):
		var raster: RefCounted = raster_script.new(int(item.w), int(item.h))
		for y: int in range(int(item.h)):
			for x: int in range(int(item.w)):
				raster.set_code(x, y, item.base[y].substr(x, 1))
		var a: Array = item.area
		var ctx: Dictionary = {"tick": int(item.tick), "area": Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])), "lights": item.lights, "level": "full"}
		environment_script.draw(raster, {"env": item.env}, "back", ctx)
		_compare(raster, item.expected, item.label)
	_check_session_rebind()
	for failure: String in failures:
		push_error(failure)
	print("render reference failures: ", failures.size())
	quit(0 if failures.is_empty() else 1)

func _compare(raster: RefCounted, rows: Array, label: String) -> void:
	for y: int in range(raster.h):
		for x: int in range(raster.w):
			if raster.get_code(x, y) != rows[y].substr(x, 1):
				failures.append("%s first mismatch (%d,%d): got %s expected %s" % [label, x, y, raster.get_code(x, y), rows[y].substr(x, 1)])
				return

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _compare_commands(actual: Array[Dictionary], expected: Array, label: String) -> void:
	if actual.size() != expected.size():
		failures.append("%s count: got %d expected %d; actual=%s expected=%s" % [label, actual.size(), expected.size(), actual, expected])
		return
	for i: int in range(actual.size()):
		for key: String in ["uid", "anim", "tick", "x", "y", "flip"]:
			var a: Variant = actual[i][key]
			var b: Variant = expected[i][key]
			var equal: bool = false
			if (a is int or a is float) and (b is int or b is float):
				# JSON numbers parse as float. Preserve exact value, including any
				# fractional coordinate, instead of truncating or using a tolerance.
				equal = float(a) == float(b)
			else:
				equal = a == b
			if not equal:
				failures.append("%s command %d.%s: got %s expected %s; actual=%s expected=%s" % [label, i, key, a, b, actual[i], expected[i]])
				return

func _check_session_rebind() -> void:
	# No SDK world, tree attachment, simulation or file mutation is involved.
	var first: BindingSession = BindingSession.new()
	first.spec = root.get_node("Registry").level_spec("level:M04")
	first.snapshot = BindingView._parse_opening(first.spec)
	var view: BindingView = BindingView.new()
	view.set_session(first)
	var opening: Dictionary = view._opening.duplicate(true)
	view._elapsed = 37.5
	first.snapshot.terrain[0] = 3
	first.snapshot.player.x = int(first.snapshot.player.x) + 1
	var calls_before: int = view.refresh_calls
	view.set_session(first)
	_check(view._opening == opening, "Rebinding the same session preserves opening decoration layout")
	_check(view._elapsed == 37.5, "Rebinding the same session preserves animation time")
	_check(view.refresh_calls == calls_before + 1 and view.observed_state == first.state(), "Rebinding the same session refreshes its latest state")
	var second: BindingSession = BindingSession.new()
	second.spec = first.spec.duplicate(true)
	second.snapshot = first.snapshot.duplicate(true)
	view.set_session(second)
	_check(view._elapsed == 0 and view._opening.terrain == second.snapshot.terrain, "A new session initializes opening layout and resets animation time")
	view.free()
