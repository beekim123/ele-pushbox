extends RefCounted
## Tick-exact state machine shared by animation, headless replay and preview.

const Board := preload("res://pushbox/scripts/board.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")

var world: Node
var board: RefCounted
var level: Dictionary
var level_path: String
var running: bool = false
var total_ticks: int = 0
var last_ticks: int = 0
var last_rounds: int = 0
var max_round_ticks: int = 0
var errors: Array[String] = []
var exploded: int = 0
var undo_stack: Array = []
var initial: Dictionary = {}
var history: Array[String] = []
var batch_us: Array[int] = []
var last_key_us: int = 0
var last_resolve_us: int = 0
var _pending: Array = []
var _offset: int = 0
var _quiet: int = 0
var _round_ticks: int = 0
var _seen: Dictionary = {}
var _serial: int = 0
var _snapshot_dir: String = ""
var _chunk_versions: Array[int] = []
var _opening_task: int = -1

func load_level(path: String, parent: Node, render: bool = false) -> String:
	level_path = path
	level = Loader.json(path)
	var materials: Array = Loader.json("res://pushbox/content/%s/materials.json" % level.get("content", "default")).get("materials", [])
	var config: Dictionary = Loader.merge(Loader.json("res://pushbox/rules.json"), level.get("rules_override", {}))
	var reason: String = Loader.validate(level, materials, config)
	if not reason.is_empty():
		return reason
	world = ClassDB.instantiate("EleWorld")
	parent.add_child(world)
	world.world_size = Vector2i(320, 192)
	world.seed = int(level.get("seed", 1))
	world.threads = 1
	world.auto_step = false
	world.render_enabled = render
	world.cell_scale = 1
	if render:
		world.render_shader_path = "res://pushbox/scripts/render/world.gdshader"
	world.collision_enabled = false
	world.materials_path = "res://pushbox/content/%s/materials.json" % level.content
	world.profile_path = "res://pushbox/content/%s/profile.json" % level.content
	world.reactions_path = "res://pushbox/content/%s/reactions.json" % level.content
	if world.start() != 0:
		return world.get_last_error()
	world.exploded.connect(func(_x: int, _y: int, _radius: int, destroyed: int) -> void: exploded += destroyed)
	world.command_rejected.connect(func(type: int, error: int) -> void: errors.append("command %d rejected %d" % [type, error]))
	board = Board.new()
	var mapping: Dictionary = {}
	for material in materials:
		mapping[material.name] = world.material_id(material.name)
	board.configure(config, materials, mapping)
	_snapshot_dir = "user://undo/session-%d-%d" % [OS.get_process_id(), get_instance_id()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_snapshot_dir)) != OK:
		return "无法创建快照目录。"
	_begin(Loader.populate(board, level))
	# Queue the complete map before the first physics frame. All commands still
	# execute together at SDK tick 0, in the exact template order.
	_pump()
	# Execute the map's tick-0 commands as part of level loading. Subsequent
	# opening settlement uses the same quiet counter and includes this tick.
	advance(1)
	return ""

func _begin(commands: Array) -> void:
	_pending = commands
	_offset = 0
	_quiet = 0
	_round_ticks = 0
	last_ticks = 0
	last_rounds = 0
	_seen = {board.movement_key(): true}
	running = true

func perform(action: String, save_undo: bool = false) -> Dictionary:
	if running:
		return {"legal": false, "reason": "正在结算。"}
	var reason: String = board.action_reason(action)
	if not reason.is_empty():
		return {"legal": false, "reason": reason}
	if save_undo:
		var saved: Dictionary = snapshot("undo")
		if saved.is_empty():
			return {"legal": false, "reason": "无法保存撤销快照，本次动作未执行。"}
		undo_stack.append(saved)
		if undo_stack.size() > 200:
			_remove_snapshot(undo_stack.pop_front())
	var result: Dictionary = board.apply_action(action)
	_begin(result.commands)
	return result

func _pump() -> void:
	var end: int = mini(_offset + 4096, _pending.size())
	while _offset < end:
		var command: Dictionary = _pending[_offset]
		var error: int = world.callv(command.op, command.args)
		if error != 0:
			errors.append("submit %s: %d %s" % [command.op, error, world.get_last_error()])
		_offset += 1

func _read_world() -> void:
	var changed_tiles: Array[int] = []
	var versions: Array[int] = []
	for cy in 3:
		for cx in 5:
			var version: int = world.get_chunk_version(cx, cy)
			var index: int = cy * 5 + cx
			versions.append(version)
			if index >= _chunk_versions.size() or version != _chunk_versions[index]:
				for y in range(cy * 4, cy * 4 + 4):
					for x in range(cx * 4, cx * 4 + 4):
						changed_tiles.append(y * 20 + x)
	_chunk_versions = versions
	board.read(world.get_material_ids(0, 0, 320, 192), changed_tiles)
	for key in changed_tiles:
		board.seed_counts(key, world.count_materials((key % 20) * 16, (key / 20) * 16, 16, 16))

func advance(tick_budget: int = 4) -> void:
	var begin: int = Time.get_ticks_usec()
	last_key_us = 0
	last_resolve_us = 0
	for _i in tick_budget:
		if not running:
			break
		if _offset < _pending.size():
			_pump()
		if world.step(1) != 0:
			errors.append(world.get_last_error())
			running = false
			break
		last_ticks += 1
		total_ticks += 1
		_round_ticks += 1
		var stats: Dictionary = world.get_stats()
		_quiet = _quiet + 1 if stats.active_chunks == 0 and stats.queue_size == 0 and _offset == _pending.size() else 0
		if _quiet < int(board.rules.settle.quiet_ticks) and _round_ticks < int(board.rules.settle.max_ticks):
			continue
		max_round_ticks = maxi(max_round_ticks, _round_ticks)
		if _quiet < int(board.rules.settle.quiet_ticks):
			errors.append("settle hit max_ticks")
		var resolve_begin: int = Time.get_ticks_usec()
		_read_world()
		last_rounds += 1
		var result: Dictionary = board.resolve_round()
		last_resolve_us += Time.get_ticks_usec() - resolve_begin
		if not result.changed:
			running = false
			break
		_pending = result.commands
		_offset = 0
		_quiet = 0
		_round_ticks = 0
		var oscillation: bool = false
		if result.moved:
			var key: String = board.movement_key()
			oscillation = _seen.has(key)
			_seen[key] = true
		if oscillation or last_rounds >= int(board.rules.settle.max_rounds):
			errors.append("oscillation" if oscillation else "max_rounds reached")
			while _offset < _pending.size():
				_pump()
				# Commit the last batch too; do not leave speculative board cells
				# behind after a warning. No further discrete round is started.
				world.step(1)
				last_ticks += 1
				total_ticks += 1
			_read_world()
			running = false
			break
	if not running:
		var key_begin: int = Time.get_ticks_usec()
		history.append(board.position_key())
		last_key_us = Time.get_ticks_usec() - key_begin
	batch_us.append(Time.get_ticks_usec() - begin)

func settle_sync() -> void:
	while running:
		advance(4)

func snapshot(label: String = "state") -> Dictionary:
	_serial += 1
	var path: String = "%s/%s-%d.snap" % [_snapshot_dir, label, _serial]
	var error: int = world.save_snapshot(path)
	if error != 0:
		errors.append("snapshot: " + world.get_last_error())
		return {}
	var data: Dictionary = {"path": path, "board": board.state(), "ticks": total_ticks, "last_ticks": last_ticks, "last_rounds": last_rounds, "history": history.duplicate(), "exploded": exploded, "errors": Array(errors)}
	var file := FileAccess.open(path + ".json", FileAccess.WRITE)
	if file == null:
		errors.append("Cannot write game-state JSON")
		return {}
	file.store_string(JSON.stringify(data))
	return data

func restore(saved: Dictionary) -> bool:
	if saved.is_empty():
		return false
	var data: Dictionary = Loader.json(saved.path + ".json")
	if data.is_empty() or world.load_snapshot(saved.path) != 0:
		errors.append("restore: " + world.get_last_error())
		return false
	board.restore(data.board)
	_chunk_versions.clear()
	board.read(world.get_material_ids(0, 0, 320, 192))
	total_ticks = int(data.ticks)
	last_ticks = int(data.last_ticks)
	last_rounds = int(data.last_rounds)
	history.assign(data.history)
	exploded = int(data.exploded)
	errors.assign(data.errors)
	running = false
	_pending.clear()
	_offset = 0
	return true

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var saved: Dictionary = undo_stack.pop_back()
	var ok: bool = restore(saved)
	_remove_snapshot(saved)
	return ok

func seal_opening() -> void:
	initial = snapshot("opening")

func begin_opening_snapshot() -> void:
	if _opening_task < 0:
		# One existing worker-pool slot; caller freezes simulation/input until done.
		_opening_task = WorkerThreadPool.add_task(seal_opening, false, "opening snapshot")

func opening_snapshot_finished() -> bool:
	if _opening_task < 0 or not WorkerThreadPool.is_task_completed(_opening_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_opening_task)
	_opening_task = -1
	return true

func restart() -> bool:
	if not restore(initial):
		return false
	for saved in undo_stack:
		_remove_snapshot(saved)
	undo_stack.clear()
	return true

func _remove_snapshot(saved: Dictionary) -> void:
	if saved.has("path"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.path + ".json"))

func dispose() -> void:
	if _opening_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_opening_task)
		_opening_task = -1
	if is_instance_valid(world):
		world.stop()
		world.free()
	var dir := DirAccess.open(_snapshot_dir)
	if dir != null:
		for filename in dir.get_files():
			dir.remove(filename)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_snapshot_dir))
