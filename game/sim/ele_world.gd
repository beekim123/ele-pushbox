class_name PortitorSdkWorld
extends RefCounted
## Owns exactly one real EleWorld. All calls remain on the calling thread.

const Materials = preload("res://sim/materials.gd")
const Profiles = preload("res://sim/profiles.gd")
const WORLD_WIDTH: int = 320
const WORLD_HEIGHT: int = 192

var node: Node2D
var material_ids: Dictionary = {}
var last_error: String = ""
var storage_dir: String = ""
var command_errors: Array[Dictionary] = []
var temperature_present: bool = false
var pending_phase_ticks: int = 0
var tick_observer: Callable = Callable()
var profile: Dictionary = {}

func open(seed_value: int, enable_rendering: bool = false, spec: Dictionary = {}) -> bool:
	dispose()
	last_error = ""
	command_errors.clear()
	if not ClassDB.class_exists("EleWorld"):
		last_error = "EleWorld extension is not registered"
		return false
	var base_dir: String = OS.get_environment("PUSHBOX_TEST_STORAGE")
	if base_dir.is_empty():
		base_dir = "user://sim"
	storage_dir = base_dir.path_join("sdk-%d-%d" % [OS.get_process_id(), get_instance_id()])
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_dir))
	if mkdir_error != OK:
		last_error = "Cannot create SDK storage: %d" % mkdir_error
		return false
	var materials: Dictionary = Materials.definitions(spec)
	var reactions: Dictionary = Materials.reactions(spec)
	profile = Profiles.for_level(spec)
	if not _write_json(storage_dir.path_join("materials.json"), materials) or not _write_json(storage_dir.path_join("profile.json"), profile):
		return false
	var reactions_path: String = ""
	if not reactions.is_empty():
		reactions_path = storage_dir.path_join("reactions.json")
		if not _write_json(reactions_path, reactions):
			return false
	node = ClassDB.instantiate("EleWorld") as Node2D
	node.set("world_size", Vector2i(WORLD_WIDTH, WORLD_HEIGHT))
	node.set("seed", seed_value)
	node.set("threads", 1)
	node.set("auto_step", false)
	node.set("cell_scale", 1.0)
	node.set("collision_enabled", false)
	node.set("render_enabled", enable_rendering)
	node.set("materials_path", storage_dir.path_join("materials.json"))
	node.set("profile_path", storage_dir.path_join("profile.json"))
	node.set("reactions_path", reactions_path)
	node.set("render_shader_path", "res://bin/palette.gdshader")
	node.visible = false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.add_child(node)
	node.connect("command_rejected", _on_command_rejected)
	var error: int = int(node.call("start"))
	if error != 0:
		last_error = str(node.call("get_last_error"))
		return false
	for material: Dictionary in materials.materials:
		material_ids[material.name] = int(node.call("material_id", material.name))
	# Only probe after start succeeds; (0, 0) is valid in this dense world,
	# so the SDK's negative sentinel means the layer does not exist.
	temperature_present = int(node.call("layer_value", "temperature", 0, 0)) >= 0
	return true

func is_started() -> bool:
	return is_instance_valid(node) and bool(node.call("is_started"))

func paint_rect(x: int, y: int, width: int, height: int, material: String, mode: int = 0) -> int:
	return _command("paint_rect", [x, y, width, height, material, mode])

func clear_rect(x: int, y: int, width: int, height: int, mode: int = 0) -> int:
	return _command("clear_rect", [x, y, width, height, mode])

func set_cell(x: int, y: int, material: String, mode: int = 0) -> int:
	return _command("set_cell", [x, y, material, mode])

func explode(x: int, y: int, radius: int, power: int) -> int:
	return _command("explode", [x, y, radius, power])

func set_layer_value(layer: String, x: int, y: int, value: int) -> int:
	return _command("set_layer_value", [layer, x, y, value])

func paint_layer_circle(layer: String, x: int, y: int, radius: int, value: int) -> int:
	return _command("paint_layer_circle", [layer, x, y, radius, value])

func require_phase(ticks: int) -> void:
	pending_phase_ticks = maxi(pending_phase_ticks, maxi(0, ticks))

func get_pending_phase_ticks() -> int:
	return pending_phase_ticks

func set_pending_phase_ticks(ticks: int) -> void:
	pending_phase_ticks = maxi(0, ticks)

func step(count: int = 1) -> int:
	return _command("step", [count])

func get_stats() -> Dictionary:
	return node.call("get_stats") if is_started() else {}

func get_state_hash() -> String:
	return str(node.call("get_state_hash")) if is_started() else ""

func get_material_ids(x: int, y: int, width: int, height: int) -> PackedInt32Array:
	return node.call("get_material_ids", x, y, width, height) if is_started() else PackedInt32Array()

func get_cell(x: int, y: int) -> Dictionary:
	return node.call("get_cell", x, y) if is_started() else {}

func layer_value(layer: String, x: int, y: int) -> int:
	return int(node.call("layer_value", layer, x, y)) if is_started() else -1

func count_materials(rectangle: Rect2i) -> PackedInt32Array:
	return node.call("count_materials", rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y) if is_started() else PackedInt32Array()

func count_material(material: String, rectangle: Rect2i) -> int:
	if not is_started() or not material_ids.has(material):
		return -1
	var counts: PackedInt32Array = node.call("count_materials", rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y)
	var id: int = int(material_ids[material])
	return int(counts[id]) if id >= 0 and id < counts.size() else -1

func save_snapshot(path: String) -> int:
	return _command("save_snapshot", [path])

func load_snapshot(path: String) -> int:
	var error: int = _command("load_snapshot", [path])
	if error == 0:
		command_errors.clear()
		last_error = ""
		temperature_present = int(node.call("layer_value", "temperature", 0, 0)) >= 0
	return error

func get_render_tiles() -> Array:
	return node.call("get_render_tiles") if is_started() else []

func render_material_image() -> Image:
	var ids: PackedInt32Array = get_material_ids(0, 0, WORLD_WIDTH, WORLD_HEIGHT)
	var image: Image = Image.create(WORLD_WIDTH, WORLD_HEIGHT, false, Image.FORMAT_RGBA8)
	for y: int in range(WORLD_HEIGHT):
		for x: int in range(WORLD_WIDTH):
			var id: int = int(ids[y * WORLD_WIDTH + x]) if ids.size() == WORLD_WIDTH * WORLD_HEIGHT else 0
			image.set_pixel(x, y, Color8(id & 255, (id >> 8) & 15, 0, 255))
	return image

func dispose() -> void:
	if is_instance_valid(node):
		node.call("stop")
		# SceneTree can already be removing siblings during application exit.
		# Stop SDK resources now; let Godot safely remove the inert node.
		node.queue_free()
	node = null
	material_ids.clear()
	temperature_present = false
	pending_phase_ticks = 0
	tick_observer = Callable()
	profile.clear()
	if not storage_dir.is_empty():
		var absolute: String = ProjectSettings.globalize_path(storage_dir)
		var directory: DirAccess = DirAccess.open(absolute)
		if directory != null:
			for filename: String in directory.get_files():
				directory.remove(filename)
			DirAccess.remove_absolute(absolute)
	storage_dir = ""

func _command(method: String, arguments: Array) -> int:
	if not is_started():
		last_error = "SDK world has not started"
		return 10
	var error: int = int(node.callv(method, arguments))
	if error != 0:
		last_error = str(node.call("get_last_error"))
	return error

func _write_json(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot write SDK content: " + path
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _on_command_rejected(type: int, error: int) -> void:
	command_errors.append({"type": type, "error": error})
	last_error = "SDK command %d rejected: %d" % [type, error]
