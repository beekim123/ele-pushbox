class_name LevelSession
extends RefCounted
## Scene-independent level owner. SDK work runs only through GameplaySettleLoop.

const SdkWorld = preload("res://sim/ele_world.gd")
const Grid = preload("res://gameplay/grid/grid_state.gd")
const SettleLoop = preload("res://gameplay/session/settle_loop.gd")
const Snapshot = preload("res://sim/snapshot.gd")
const Goals = preload("res://gameplay/session/goals.gd")
const ResourceIndex = preload("res://core/ids/registry.gd")
const TILE_SIZE: int = 16
const UNDO_LIMIT: int = 200
const SAFETY_CELLS_PER_ADVANCE: int = 64

var spec: Dictionary = {}
var width: int = 0
var height: int = 0
var grid
var world
var render_enabled: bool = DisplayServer.get_name() != "headless"
var busy: bool = false
var last_error: String = ""
var hash_history: Array[String] = []
var settle_mechanics: Array = []
var _action_mechanics: Array = []
var _mechanics: Dictionary = {}
var _undo_stack: Array[Dictionary] = []
var _opening: Dictionary = {}
var _pending_snapshot: Dictionary = {}
var _pending_plan: Dictionary = {}
var _settlement
var _snapshot_service = Snapshot.new()
var _serial: int = 0
var _last_result: Dictionary = {}
var last_commit_profile: Dictionary = {}
var _planning_safety: bool = false
var _planned_safety_targets: Array[Vector2i] = []
var _pending_safety_targets: Array[Vector2i] = []
var _preparing_safety: bool = false
var _snapshot_stage: int = 0
var _safety_target_index: int = 0
var _safety_cell_index: int = 0

func setup(level_spec: Dictionary) -> bool:
	dispose()
	last_error = ""
	spec = level_spec.duplicate(true)
	grid = Grid.new()
	if not grid.parse(spec):
		last_error = str(grid.last_error)
		return false
	width = int(grid.width)
	height = int(grid.height)
	world = SdkWorld.new()
	if not world.open(int(spec.get("seed", 1)), render_enabled):
		last_error = str(world.last_error)
		return false
	var index: RefCounted = ResourceIndex.new()
	if index.load_registry() != OK:
		last_error = "Cannot load authoritative mechanism uid map"
		return false
	_mechanics.clear()
	for uid: String in ["mechanic:push", "mechanic:ladder", "mechanic:dig", "mechanic:pour", "mechanic:fall", "mechanic:plate_door"]:
		var implementation: Variant = index.get_resource(uid)
		if not implementation is Script:
			last_error = "Missing mapped mechanism implementation: " + uid
			return false
		_mechanics[uid] = implementation.new()
	for mechanic in _mechanics.values():
		mechanic.setup(spec, self)
	_action_mechanics = [_mechanics["mechanic:push"], _mechanics["mechanic:ladder"], _mechanics["mechanic:dig"], _mechanics["mechanic:pour"]]
	settle_mechanics = [_mechanics["mechanic:fall"], _mechanics["mechanic:plate_door"]]
	if not _populate():
		return false
	_settlement = SettleLoop.new()
	_settlement.begin(self)
	while not _settlement.finished:
		_settlement.advance(4)
	if not bool(_settlement.result.ok):
		last_error = str(_settlement.result.error)
		return false
	hash_history.assign(_settlement.result.hashes)
	_opening = _capture("opening")
	if _opening.is_empty():
		last_error = "Cannot save opening SDK and game snapshot"
		return false
	return true

func state() -> Dictionary:
	if grid == null:
		return {}
	var output: Dictionary = grid.export_state()
	output.erase("open")
	var doors: Array[bool] = []
	for door: int in grid.open:
		doors.append(door != 0)
	output.doors = doors
	output.won = Goals.new().won(grid)
	return output

func goal_lights() -> Array[Dictionary]:
	return Goals.new().evaluate(grid) if grid != null else []

func can_perform(action: String) -> Dictionary:
	if busy:
		return {"handled": true, "accepted": false, "reason": "settling"}
	if world == null or not world.is_started():
		return {"handled": true, "accepted": false, "reason": "not-started"}
	for mechanic in _action_mechanics:
		var plan: Dictionary = mechanic.try_action(action)
		if bool(plan.get("handled", false)):
			return plan
	return {"handled": true, "accepted": false, "reason": "unknown-action"}

func perform(action: String) -> Dictionary:
	var result: Dictionary = begin_action(action)
	if not bool(result.accepted):
		return result
	while busy:
		result = advance_settle(4)
	return result

func begin_action(action: String, deferred_safety: bool = false) -> Dictionary:
	last_commit_profile = {}
	_planned_safety_targets.clear()
	_planning_safety = deferred_safety
	var plan: Dictionary = can_perform(action)
	_planning_safety = false
	if not bool(plan.get("accepted", false)):
		_planned_safety_targets.clear()
		return {"accepted": false, "finished": true, "won": bool(state().get("won", false)), "ticks": 0, "error": "", "reason": str(plan.get("reason", "blocked"))}
	if deferred_safety and not _planned_safety_targets.is_empty():
		last_error = ""
		_pending_plan = plan
		_pending_snapshot = {}
		_pending_safety_targets.assign(_planned_safety_targets)
		_planned_safety_targets.clear()
		_safety_target_index = 0
		_safety_cell_index = 0
		_preparing_safety = true
		busy = true
		return {"accepted": true, "finished": false, "won": false, "ticks": 0, "error": "", "kind": plan.kind, "phase": "safety"}
	_planned_safety_targets.clear()
	return _schedule_snapshot(plan) if deferred_safety else _commit_plan(plan)

func _commit_plan(plan: Dictionary, prepared_snapshot: Dictionary = {}) -> Dictionary:
	var commit_started: int = Time.get_ticks_usec()
	# Both synchronous and deferred preparation enter this single commit.
	# No snapshot, command, entity update or move count occurs before here.
	_reset_safety_preparation()
	busy = false
	last_error = ""
	_snapshot_stage = 0
	_pending_snapshot = prepared_snapshot if not prepared_snapshot.is_empty() else _capture("undo")
	if _pending_snapshot.is_empty():
		_pending_plan = {}
		last_error = "Cannot save undo SDK and game snapshot"
		return {"accepted": false, "finished": true, "won": bool(state().get("won", false)), "ticks": 0, "error": last_error}
	last_commit_profile = _snapshot_service.last_save_profile.duplicate(true)
	last_commit_profile.snapshot_capture_us = Time.get_ticks_usec() - commit_started
	_pending_plan = plan
	if not _apply_plan(plan):
		var apply_error: String = last_error
		_restore(_pending_snapshot)
		_snapshot_service.remove(_pending_snapshot)
		_pending_snapshot = {}
		_pending_plan = {}
		last_error = apply_error
		return {"accepted": false, "finished": true, "won": bool(state().get("won", false)), "ticks": 0, "error": last_error}
	grid.moves += 1
	busy = true
	_settlement = SettleLoop.new()
	_settlement.begin(self)
	last_commit_profile.total_commit_us = Time.get_ticks_usec() - commit_started
	return {"accepted": true, "finished": false, "won": false, "ticks": 0, "error": "", "kind": plan.kind}

func advance_settle(max_ticks: int = 4) -> Dictionary:
	if not busy:
		return _last_result.duplicate(true)
	if _preparing_safety:
		return _advance_safety_preparation()
	if _snapshot_stage != 0:
		return _advance_snapshot_preparation()
	var result: Dictionary = _settlement.advance(max_ticks)
	result.accepted = true
	result.won = false
	result.kind = _pending_plan.get("kind", "")
	if not bool(result.finished):
		return result
	busy = false
	if not bool(result.ok):
		var error: String = str(result.error)
		_restore(_pending_snapshot)
		_snapshot_service.remove(_pending_snapshot)
		last_error = error
		result.accepted = false
		result.error = error
	else:
		_undo_stack.append(_pending_snapshot)
		while _undo_stack.size() > UNDO_LIMIT:
			_snapshot_service.remove(_undo_stack.pop_front())
		hash_history.append_array(result.hashes)
	result.won = Goals.new().won(grid)
	_pending_snapshot = {}
	_pending_plan = {}
	_last_result = result.duplicate(true)
	return result

func _advance_safety_preparation() -> Dictionary:
	var remaining: int = SAFETY_CELLS_PER_ADVANCE
	var check_temperature: bool = world.temperature_present
	while remaining > 0 and _safety_target_index < _pending_safety_targets.size():
		var target: Vector2i = _pending_safety_targets[_safety_target_index]
		var x: int = target.x * TILE_SIZE + _safety_cell_index % TILE_SIZE
		var y: int = target.y * TILE_SIZE + int(_safety_cell_index / TILE_SIZE)
		if not _safe_cell_to_move(x, y, check_temperature):
			_reset_safety_preparation()
			busy = false
			_pending_plan = {}
			_pending_snapshot = {}
			_last_result = {"accepted": false, "finished": true, "won": bool(state().get("won", false)), "ticks": 0, "hashes": [], "error": "", "reason": "material-state"}
			return _last_result.duplicate(true)
		remaining -= 1
		_safety_cell_index += 1
		if _safety_cell_index == TILE_SIZE * TILE_SIZE:
			_safety_cell_index = 0
			_safety_target_index += 1
	if _safety_target_index < _pending_safety_targets.size():
		return {"accepted": true, "finished": false, "won": false, "ticks": 0, "hashes": [], "error": "", "kind": _pending_plan.kind, "phase": "safety"}
	return _schedule_snapshot(_pending_plan)

func _schedule_snapshot(plan: Dictionary) -> Dictionary:
	_reset_safety_preparation()
	_pending_plan = plan
	_snapshot_stage = 1
	busy = true
	return {"accepted": true, "finished": false, "won": false, "ticks": 0, "error": "", "kind": plan.kind, "phase": "snapshot_sdk"}

func _advance_snapshot_preparation() -> Dictionary:
	if _snapshot_stage == 1:
		_serial += 1
		_pending_snapshot = _snapshot_service.begin_save(world, _snapshot_state(), "undo-%d" % _serial)
		if not _pending_snapshot.is_empty():
			_snapshot_stage = 2
			return {"accepted": true, "finished": false, "won": false, "ticks": 0, "error": "", "kind": _pending_plan.kind, "phase": "snapshot_json"}
	else:
		var completed: Dictionary = _snapshot_service.finish_save(_pending_snapshot)
		if not completed.is_empty():
			var result: Dictionary = _commit_plan(_pending_plan, completed)
			result.phase = "committed"
			return result
	_snapshot_stage = 0
	busy = false
	_pending_snapshot = {}
	_pending_plan = {}
	last_error = "Cannot save undo SDK and game snapshot"
	_last_result = {"accepted": false, "finished": true, "won": bool(state().get("won", false)), "ticks": 0, "error": last_error}
	return _last_result.duplicate(true)

func _reset_safety_preparation() -> void:
	_preparing_safety = false
	_pending_safety_targets.clear()
	_safety_target_index = 0
	_safety_cell_index = 0

func undo() -> bool:
	if busy or _undo_stack.is_empty():
		return false
	var snapshot: Dictionary = _undo_stack.back()
	if not _restore(snapshot):
		return false
	_undo_stack.pop_back()
	_snapshot_service.remove(snapshot)
	last_error = ""
	return true

func restart() -> bool:
	if busy or _opening.is_empty():
		return false
	var before: Dictionary = _capture("restart")
	if before.is_empty():
		last_error = "Cannot save restart undo point"
		return false
	if not _restore(_opening):
		_snapshot_service.remove(before)
		return false
	_undo_stack.append(before)
	while _undo_stack.size() > UNDO_LIMIT:
		_snapshot_service.remove(_undo_stack.pop_front())
	last_error = ""
	return true

func cell_rect(x: int, y: int) -> Rect2i:
	return Rect2i(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

func move_crate(index: int, destination: Vector2i) -> bool:
	var crate: Dictionary = grid.crates[index]
	var source: Rect2i = cell_rect(int(crate.x), int(crate.y))
	var target: Rect2i = cell_rect(destination.x, destination.y)
	if world.clear_rect(source.position.x, source.position.y, TILE_SIZE, TILE_SIZE) != 0 or world.paint_rect(target.position.x, target.position.y, TILE_SIZE, TILE_SIZE, "iron_crate" if str(crate.kind) == "iron" else "crate") != 0:
		last_error = str(world.last_error)
		return false
	crate.x = destination.x
	crate.y = destination.y
	grid.crates[index] = crate
	return true

func set_door_group(index: int, value: int) -> bool:
	for tile: int in grid.groups[index].doors:
		var x: int = tile % width
		var y: int = int(tile / width)
		var error: int = world.clear_rect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE) if value != 0 else world.paint_rect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE, "gate")
		if error != 0:
			last_error = str(world.last_error)
			return false
	grid.open[index] = value
	return true

func safe_to_move_tile(x: int, y: int) -> bool:
	if _planning_safety:
		var target: Vector2i = Vector2i(x, y)
		if not _planned_safety_targets.has(target):
			_planned_safety_targets.append(target)
		return true
	var rectangle: Rect2i = cell_rect(x, y)
	var check_temperature: bool = world.temperature_present
	for pixel_y: int in range(rectangle.position.y, rectangle.end.y):
		for pixel_x: int in range(rectangle.position.x, rectangle.end.x):
			if not _safe_cell_to_move(pixel_x, pixel_y, check_temperature):
				return false
	return true

func _safe_cell_to_move(x: int, y: int, check_temperature: bool) -> bool:
	var cell: Dictionary = world.get_cell(x, y)
	if cell.is_empty() or bool(cell.get("burning", false)) or int(cell.get("reg", 0)) != 0:
		return false
	if check_temperature:
		var temperature: int = world.layer_value("temperature", x, y)
		if temperature >= 0 and temperature != 2344:
			return false
	return true

func dispose() -> void:
	_snapshot_stage = 0
	busy = false
	_planning_safety = false
	_planned_safety_targets.clear()
	_reset_safety_preparation()
	_action_mechanics.clear()
	settle_mechanics.clear()
	_mechanics.clear()
	_undo_stack.clear()
	_opening = {}
	_pending_snapshot = {}
	_pending_plan = {}
	_settlement = null
	if world != null:
		world.dispose()
	world = null
	grid = null
	hash_history.clear()
	spec.clear()
	width = 0
	height = 0
	_serial = 0
	_last_result = {}

func _populate() -> bool:
	var materials: Dictionary = {Grid.Terrain.ROCK: "bedrock", Grid.Terrain.EARTH: "packed_earth", Grid.Terrain.SAND: "sand"}
	for y: int in range(height):
		for x: int in range(width):
			var terrain: int = int(grid.terrain[grid.tile_index(x, y)])
			if materials.has(terrain) and world.paint_rect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE, str(materials[terrain])) != 0:
				last_error = str(world.last_error)
				return false
	for crate: Dictionary in grid.crates:
		if world.paint_rect(int(crate.x) * TILE_SIZE, int(crate.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE, "iron_crate" if str(crate.kind) == "iron" else "crate") != 0:
			last_error = str(world.last_error)
			return false
	for group_index: int in range(grid.groups.size()):
		if not set_door_group(group_index, 0):
			return false
	return true

func _apply_plan(plan: Dictionary) -> bool:
	if plan.has("crate_to") and not move_crate(int(plan.crate), Vector2i(int(plan.crate_to.x), int(plan.crate_to.y))):
		return false
	if plan.has("player"):
		grid.player = plan.player.duplicate()
	if plan.has("clear"):
		var tile: Vector2i = plan.clear
		if world.clear_rect(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE) != 0:
			last_error = str(world.last_error)
			return false
		grid.terrain[grid.tile_index(tile.x, tile.y)] = Grid.Terrain.EMPTY
	if plan.has("pour"):
		var tile: Vector2i = plan.pour
		if world.paint_rect(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, "sand", 2) != 0:
			last_error = str(world.last_error)
			return false
		grid.terrain[grid.tile_index(tile.x, tile.y)] = Grid.Terrain.SAND
	grid.bag.sand = int(grid.bag.sand) + int(plan.get("sand_delta", 0))
	return true

func _snapshot_state() -> Dictionary:
	var mechanism_states: Dictionary = {}
	for uid: String in _mechanics:
		mechanism_states[uid] = _mechanics[uid].get_state()
	return {"grid": grid.export_state(), "mechanisms": mechanism_states}

func _capture(label: String) -> Dictionary:
	_serial += 1
	return _snapshot_service.save(world, _snapshot_state(), "%s-%d" % [label, _serial])

func _restore(snapshot: Dictionary) -> bool:
	var saved: Dictionary = _snapshot_service.load_into(world, snapshot)
	if saved.is_empty() or not saved.has("grid"):
		last_error = "Cannot restore SDK and game snapshot: " + str(world.last_error)
		return false
	grid.import_state(saved.grid)
	for uid: String in saved.get("mechanisms", {}):
		if _mechanics.has(uid):
			_mechanics[uid].set_state(saved.mechanisms[uid])
	return true
