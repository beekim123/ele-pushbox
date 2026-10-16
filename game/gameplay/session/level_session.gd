class_name LevelSession
extends RefCounted
## Scene-independent level owner. SDK work runs only through GameplaySettleLoop.

const SdkWorld = preload("res://sim/ele_world.gd")
const Grid = preload("res://gameplay/grid/grid_state.gd")
const SettleLoop = preload("res://gameplay/session/settle_loop.gd")
const Snapshot = preload("res://sim/snapshot.gd")
const Goals = preload("res://gameplay/session/goals.gd")
const ResourceIndex = preload("res://core/ids/registry.gd")
const Checkpoint = preload("res://gameplay/session/checkpoint.gd")
const WaterRules = preload("res://gameplay/grid/rules/water.gd")
const PowderRules = preload("res://gameplay/grid/rules/powder.gd")
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
var settle_step_changed: bool = false
var _tick_changed: bool = false
var _layer_pulses: Array[Dictionary] = []
var _queued_materials: Dictionary = {}
var _checkpoint_store = Checkpoint.new()
var _checkpoint_uid: String = ""
var _checkpoint_hash: String = ""
var checkpoint_error: String = ""
var _opening_visual_state: Dictionary = {}
var _last_checkpoint_key: String = ""
var _checkpoint_write_blocked: bool = false

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
	if not world.open(int(spec.get("seed", 1)), render_enabled, spec):
		last_error = str(world.last_error)
		return false
	var index: RefCounted = ResourceIndex.new()
	if index.load_registry() != OK:
		last_error = "Cannot load authoritative mechanism uid map"
		return false
	_mechanics.clear()
	var mechanism_ids: Array[String] = ["push", "ladder", "dig", "pour", "fall", "plate_door"]
	if str(spec.get("group", "basics")) != "basics":
		mechanism_ids.append_array(["float_sink", "lever", "lift", "bin", "load_bridge", "portal", "bomb", "mine_cart", "lantern_reveal", "nested_box", "vine", "bounce", "seesaw", "ice_slide", "gust", "burn", "freeze", "melt", "lifetime"])
	for id: String in spec.get("mechanisms", []):
		if not mechanism_ids.has(id):
			mechanism_ids.append(id)
	for id: String in mechanism_ids:
		var uid: String = "mechanic:" + id
		var implementation: Variant = index.get_resource(uid)
		if not implementation is Script:
			last_error = "Missing mapped mechanism implementation: " + uid
			return false
		_mechanics[uid] = implementation.new()
	for mechanic in _mechanics.values():
		mechanic.setup(spec, self)
	_action_mechanics.clear()
	for id: String in ["lever", "bomb", "mine_cart", "ice_slide", "push", "ladder", "dig", "pour"]:
		if _mechanics.has("mechanic:" + id):
			_action_mechanics.append(_mechanics["mechanic:" + id])
	settle_mechanics.clear()
	for id: String in ["lantern_reveal", "fall", "float_sink", "nested_box", "vine", "bounce", "seesaw", "ice_slide", "lift", "bin", "load_bridge", "plate_door", "portal", "gust"]:
		if _mechanics.has("mechanic:" + id):
			settle_mechanics.append(_mechanics["mechanic:" + id])
	world.tick_observer = on_physics_tick
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
	_opening_visual_state = state().duplicate(true)
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
	output.won = is_won()
	return output

func goal_lights() -> Array[Dictionary]:
	var result: Array[Dictionary] = Goals.new().evaluate(grid, spec) if grid != null else []
	for mechanic in _mechanics.values():
		result.append_array(mechanic.goals())
	return result

func is_won() -> bool:
	var lights: Array[Dictionary] = goal_lights()
	if lights.is_empty():
		return false
	for light: Dictionary in lights:
		if not bool(light.lit):
			return false
	return true

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mechanic in _mechanics.values():
		result.append_array(mechanic.observe())
	return result

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
		_checkpoint_write_blocked = false
		_undo_stack.append(_pending_snapshot)
		while _undo_stack.size() > UNDO_LIMIT:
			_snapshot_service.remove(_undo_stack.pop_front())
		hash_history.append_array(result.hashes)
	result.won = is_won()
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
	_checkpoint_write_blocked = false
	_undo_stack.append(before)
	while _undo_stack.size() > UNDO_LIMIT:
		_snapshot_service.remove(_undo_stack.pop_front())
	last_error = ""
	return true

func cell_rect(x: int, y: int) -> Rect2i:
	return Rect2i(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

func water_can_accept(crate_index: int, destination: Vector2i, mode: String = "surface") -> bool:
	var powder: Dictionary = PowderRules.displacement(self, crate_index, destination)
	return bool(powder.get("ok", false)) and bool(WaterRules.displacement(self, crate_index, destination, mode, powder.get("reserved", [])).get("ok", false))

func move_crate(index: int, destination: Vector2i, water_mode: String = "surface") -> bool:
	var crate: Dictionary = grid.crates[index]
	var source: Rect2i = cell_rect(int(crate.x), int(crate.y))
	var target: Rect2i = cell_rect(destination.x, destination.y)
	var powder: Dictionary = PowderRules.displacement(self, index, destination)
	if not bool(powder.get("ok", false)):
		return false
	var displacement: Dictionary = WaterRules.displacement(self, index, destination, water_mode, powder.get("reserved", []))
	if not bool(displacement.get("ok", false)):
		return false
	if world.clear_rect(source.position.x, source.position.y, TILE_SIZE, TILE_SIZE) != 0:
		last_error = str(world.last_error)
		return false
	_record_material_rect(source, "empty")
	for pixel: int in displacement.get("from", []):
		_queued_materials[pixel] = int(world.material_ids.empty)
		if world.set_cell(pixel % 320, int(pixel / 320), "empty") != 0:
			last_error = str(world.last_error)
			return false
	if world.paint_rect(target.position.x, target.position.y, TILE_SIZE, TILE_SIZE, "iron_crate" if str(crate.kind) == "iron" else "crate") != 0:
		last_error = str(world.last_error)
		return false
	_record_material_rect(target, "iron_crate" if str(crate.kind) == "iron" else "crate")
	if not _apply_powder_displacement(powder):
		return false
	for pixel: int in displacement.get("to", []):
		_queued_materials[pixel] = int(world.material_ids.water)
		if world.set_cell(pixel % 320, int(pixel / 320), "water") != 0:
			last_error = str(world.last_error)
			return false
	grid.terrain[grid.tile_index(int(crate.x), int(crate.y))] = Grid.Terrain.WATER if not displacement.get("to", []).is_empty() and water_mode == "exchange" else Grid.Terrain.EMPTY
	crate.x = destination.x
	crate.y = destination.y
	grid.crates[index] = crate
	grid.terrain[grid.tile_index(destination.x, destination.y)] = Grid.Terrain.EMPTY
	wake_water_near(Vector2i(source.position / TILE_SIZE))
	wake_water_near(destination)
	return true

func _apply_powder_displacement(displacement: Dictionary) -> bool:
	for cell: Dictionary in displacement.get("cells", []):
		var pixel: int = int(cell.to)
		_queued_materials[pixel] = int(world.material_ids[cell.material])
		if world.set_cell(pixel % 320, int(pixel / 320), str(cell.material)) != 0:
			last_error = str(world.last_error)
			return false
	return true

func float_crate(index: int) -> bool:
	var plan: Dictionary = WaterRules.surface_lift(self, index)
	if plan.is_empty():
		return false
	if plan.mode == "exchange":
		return move_crate(index, plan.destination, "exchange")
	var crate: Dictionary = grid.crates[index]
	var source: Vector2i = Vector2i(int(crate.x), int(crate.y))
	var destination: Vector2i = plan.destination
	# Remove precisely one footprint of water from the highest connected
	# surface, then refill the vacated crate footprint with that same volume.
	for pixel: int in plan.from:
		_queued_materials[pixel] = int(world.material_ids.empty)
		if world.set_cell(pixel % 320, int(pixel / 320), "empty") != 0:
			last_error = str(world.last_error)
			return false
	if not move_crate(index, destination, "float"):
		last_error = "Cannot complete a conservative crate lift"
		return false
	return set_tile_material(source.x, source.y, "water")

func material_ids_view() -> PackedInt32Array:
	var ids: PackedInt32Array = world.get_material_ids(0, 0, 320, 192)
	if ids.size() == 320 * 192:
		for pixel: int in _queued_materials:
			ids[pixel] = int(_queued_materials[pixel])
	return ids

func _record_material_rect(rectangle: Rect2i, material: String) -> void:
	var material_id: int = int(world.material_ids.get(material, 0))
	for y: int in range(rectangle.position.y, rectangle.end.y):
		for x: int in range(rectangle.position.x, rectangle.end.x):
			_queued_materials[y * 320 + x] = material_id

func wake_water_near(tile: Vector2i) -> void:
	if not world.material_ids.has("water"):
		return
	var ids: PackedInt32Array = material_ids_view()
	if ids.size() != 320 * 192:
		return
	for y: int in range(maxi(0, tile.y * 16 - 1), mini(height * 16, (tile.y + 1) * 16 + 1)):
		for x: int in range(maxi(0, tile.x * 16 - 1), mini(width * 16, (tile.x + 1) * 16 + 1)):
			if ids[y * 320 + x] == int(world.material_ids.water):
				if world.set_cell(x, y, "water") != 0:
					last_error = str(world.last_error)
				return

func door_blocked(index: int) -> bool:
	var x: int = index % width
	var y: int = int(index / width)
	if grid.is_player(x, y) or grid.crate_index(x, y) >= 0:
		return true
	var ids: PackedInt32Array = material_ids_view()
	if ids.size() != 320 * 192:
		return true
	var rectangle: Rect2i = cell_rect(x, y)
	for py: int in range(rectangle.position.y, rectangle.end.y):
		for px: int in range(rectangle.position.x, rectangle.end.x):
			if ids[py * 320 + px] != int(world.material_ids.empty):
				return true
	return false

func set_door_group(index: int, value: int) -> bool:
	if value == 0 and int(grid.open[index]) != 0:
		for tile: int in grid.groups[index].doors:
			if door_blocked(tile):
				return false
	for tile: int in grid.groups[index].doors:
		var x: int = tile % width
		var y: int = int(tile / width)
		var error: int = world.clear_rect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE) if value != 0 else world.paint_rect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE, "gate")
		if error != 0:
			last_error = str(world.last_error)
			return false
	for tile: int in grid.groups[index].doors:
		_record_material_rect(cell_rect(tile % width, int(tile / width)), "empty" if value != 0 else "gate")
	for tile: int in grid.groups[index].doors:
		wake_water_near(Vector2i(tile % width, int(tile / width)))
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
	_layer_pulses.clear()
	_queued_materials.clear()
	_tick_changed = false
	settle_step_changed = false
	_checkpoint_uid = ""
	_checkpoint_hash = ""
	checkpoint_error = ""
	_opening_visual_state.clear()
	_last_checkpoint_key = ""
	_checkpoint_write_blocked = false

func _populate() -> bool:
	var materials: Dictionary = Grid.TILE_MATERIALS
	for y: int in range(height):
		for x: int in range(width):
			var terrain: int = int(grid.terrain[grid.tile_index(x, y)])
			if materials.has(terrain) and world.paint_rect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE, str(materials[terrain])) != 0:
				last_error = str(world.last_error)
				return false
	for crate: Dictionary in grid.crates:
		_record_material_rect(cell_rect(int(crate.x), int(crate.y)), "iron_crate" if str(crate.kind) == "iron" else "crate")
		if world.paint_rect(int(crate.x) * TILE_SIZE, int(crate.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE, "iron_crate" if str(crate.kind) == "iron" else "crate") != 0:
			last_error = str(world.last_error)
			return false
	for group_index: int in range(grid.groups.size()):
		if not set_door_group(group_index, 0):
			return false
	for device: Dictionary in grid.devices:
		if device.type == "lift":
			var at: Array = device.stops[int(device.get("stop", 0))]
			for offset: int in range(int(device.get("width", 1))):
				if not set_tile_material(int(at[0]) + offset, int(at[1]), "bridge"):
					return false
		elif device.type in ["mine_cart", "bounce"]:
			var at: Array = device.get("at", [])
			for offset: int in range(int(device.get("width", 1))):
				if at.size() == 2 and not set_tile_material(int(at[0]) + offset, int(at[1]), "bridge"):
					return false
		elif device.type == "seesaw":
			for at: Array in device.get("ends", []):
				if not set_tile_material(int(at[0]), int(at[1]), "bridge"):
					return false
	return true

func _apply_plan(plan: Dictionary) -> bool:
	if plan.has("bomb"):
		if not blast(plan.bomb):
			return false
		grid.bag.bomb = int(grid.bag.bomb) - 1
		return true
	if plan.has("mechanic"):
		var mechanic = _mechanics.get(str(plan.mechanic))
		if mechanic == null or not mechanic.has_method("apply_plan"):
			last_error = "Missing mechanism action handler"
			return false
		return bool(mechanic.apply_plan(plan))
	if plan.get("kind", "") == "lever":
		var device: Dictionary = grid.devices[int(plan.device)]
		device.on = not bool(device.get("on", false))
		var action: Dictionary = device.get("action", {})
		if action.has("device"):
			return trigger_device(int(action.device)) or last_error.is_empty()
		if action.has("release"):
			return trigger_device(int(action.release)) or last_error.is_empty()
		return true
	if plan.has("crate_to") and not move_crate(int(plan.crate), Vector2i(int(plan.crate_to.x), int(plan.crate_to.y))):
		return false
	if plan.has("player"):
		grid.player = plan.player.duplicate()
	if plan.has("clear"):
		var tile: Vector2i = plan.clear
		if world.clear_rect(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE) != 0:
			last_error = str(world.last_error)
			return false
		_record_material_rect(cell_rect(tile.x, tile.y), "empty")
		grid.terrain[grid.tile_index(tile.x, tile.y)] = Grid.Terrain.EMPTY
	if plan.has("pour"):
		var tile: Vector2i = plan.pour
		var displaced: Dictionary = WaterRules.pour_displacement(self, tile)
		if not bool(displaced.get("ok", false)):
			last_error = "No free surface for displaced water"
			return false
		for pixel: int in displaced.get("from", []):
			if world.set_cell(pixel % 320, int(pixel / 320), "empty") != 0:
				last_error = str(world.last_error)
				return false
			_queued_materials[pixel] = int(world.material_ids.empty)
		for pixel: int in displaced.get("to", []):
			if world.set_cell(pixel % 320, int(pixel / 320), "water") != 0:
				last_error = str(world.last_error)
				return false
			_queued_materials[pixel] = int(world.material_ids.water)
		if world.paint_rect(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, "sand", 2) != 0:
			last_error = str(world.last_error)
			return false
		var before_ids: PackedInt32Array = material_ids_view()
		var target_rect: Rect2i = cell_rect(tile.x, tile.y)
		for py: int in range(target_rect.position.y, target_rect.end.y):
			for px: int in range(target_rect.position.x, target_rect.end.x):
				var pixel: int = py * 320 + px
				if before_ids[pixel] in [int(world.material_ids.empty), int(world.material_ids.get("water", -1)), int(world.material_ids.get("acid", -1)), int(world.material_ids.get("smoke", -1)), int(world.material_ids.get("fog", -1))]:
					_queued_materials[pixel] = int(world.material_ids.sand)
		grid.terrain[grid.tile_index(tile.x, tile.y)] = Grid.Terrain.SAND
	grid.bag.sand = int(grid.bag.sand) + int(plan.get("sand_delta", 0))
	return true

func _snapshot_state() -> Dictionary:
	var mechanism_states: Dictionary = {}
	for uid: String in _mechanics:
		mechanism_states[uid] = _mechanics[uid].get_state()
	return {"grid": grid.export_state(), "mechanisms": mechanism_states, "phase_ticks": world.pending_phase_ticks, "layer_pulses": _layer_pulses.duplicate(true)}

func _capture(label: String) -> Dictionary:
	_serial += 1
	return _snapshot_service.save(world, _snapshot_state(), "%s-%d" % [label, _serial])

func _restore(snapshot: Dictionary) -> bool:
	var saved: Dictionary = _snapshot_service.load_into(world, snapshot)
	if saved.is_empty() or not saved.has("grid"):
		last_error = "Cannot restore SDK and game snapshot: " + str(world.last_error)
		return false
	return _restore_game_state(saved)

func _restore_game_state(saved: Dictionary) -> bool:
	if not saved.get("grid") is Dictionary:
		return false
	var saved_grid: Dictionary = saved.grid
	if int(saved_grid.get("w", 0)) != width or int(saved_grid.get("h", 0)) != height or not saved_grid.get("terrain") is Array or saved_grid.terrain.size() != width * height:
		return false
	if not saved_grid.get("player") is Dictionary or not saved_grid.get("crates") is Array or not saved_grid.get("bag") is Dictionary or not saved_grid.get("open") is Array or saved_grid.open.size() != grid.groups.size():
		return false
	if saved_grid.has("devices") and (not saved_grid.devices is Array or saved_grid.devices.size() != spec.get("devices", []).size()):
		return false
	grid.import_state(saved_grid)
	_queued_materials.clear()
	world.pending_phase_ticks = int(saved.get("phase_ticks", 0))
	_layer_pulses.clear()
	for pulse: Dictionary in saved.get("layer_pulses", []):
		_layer_pulses.append(pulse.duplicate(true))
	_tick_changed = false
	for uid: String in saved.get("mechanisms", {}):
		if _mechanics.has(uid):
			_mechanics[uid].set_state(saved.mechanisms[uid])
	return true

func configure_checkpoint(uid: String, spec_hash: String) -> void:
	_checkpoint_uid = uid
	_checkpoint_hash = spec_hash
	_checkpoint_write_blocked = false
	_last_checkpoint_key = ""
	checkpoint_error = ""

func save_checkpoint(mode_state: Dictionary = {}) -> bool:
	if _checkpoint_write_blocked:
		if checkpoint_error.is_empty():
			checkpoint_error = "Previous checkpoint could not be restored; its files are retained"
		return false
	if busy or world == null or _checkpoint_uid.is_empty() or _checkpoint_hash.is_empty():
		checkpoint_error = "Cannot save an unsettled or unidentified level"
		return false
	var data: Dictionary = _snapshot_state()
	data.mode_state = mode_state.duplicate(true)
	var key: String = world.get_state_hash() + ":" + JSON.stringify(data).sha256_text()
	if key == _last_checkpoint_key:
		checkpoint_error = ""
		return true
	var error: Error = _checkpoint_store.save_checkpoint(world, data, _checkpoint_uid, _checkpoint_hash)
	checkpoint_error = _checkpoint_store.last_error if error != OK else ""
	if error == OK:
		_last_checkpoint_key = key
	return error == OK

func restore_checkpoint() -> Dictionary:
	if busy or world == null or _checkpoint_uid.is_empty() or _checkpoint_hash.is_empty():
		return {}
	var data: Dictionary = _checkpoint_store.load_checkpoint(world, _checkpoint_uid, _checkpoint_hash)
	checkpoint_error = _checkpoint_store.last_error
	_checkpoint_write_blocked = _checkpoint_store.load_status == "failed"
	if data.is_empty():
		# A failed native load is not assumed to leave its world untouched.
		if not _restore(_opening):
			_checkpoint_write_blocked = true
			checkpoint_error = "Cannot restore the opening after checkpoint load failure"
			return {"fatal": true}
		return {"failed": true} if _checkpoint_write_blocked else {}
	if not _restore_game_state(data):
		_checkpoint_write_blocked = true
		if not _restore(_opening):
			checkpoint_error = "Cannot restore the opening after invalid checkpoint state"
			return {"fatal": true}
		checkpoint_error = "Checkpoint game state is invalid; previous checkpoint retained"
		return {"failed": true}
	for snapshot: Dictionary in _undo_stack:
		_snapshot_service.remove(snapshot)
	_undo_stack.clear()
	_pending_snapshot = {}
	_pending_plan = {}
	hash_history.clear()
	last_error = ""
	var mode_state: Variant = data.get("mode_state", {})
	return {"restored": true, "mode_state": mode_state if mode_state is Dictionary else {}}

func sdk_material_count(rectangle: Rect2i, material: String) -> int:
	var count: int = world.count_material(material, rectangle)
	if count < 0:
		last_error = "Cannot count SDK material: " + material
	return count

func material_count(rectangle: Rect2i, material: String) -> int:
	if _queued_materials.is_empty():
		return sdk_material_count(rectangle, material)
	if not world.material_ids.has(material):
		last_error = "Unknown SDK material: " + material
		return -1
	var ids: PackedInt32Array = material_ids_view()
	if ids.size() != 320 * 192:
		last_error = "Cannot read SDK materials for pending writes"
		return -1
	var count: int = 0
	var material_id: int = int(world.material_ids[material])
	for y: int in range(maxi(0, rectangle.position.y), mini(192, rectangle.end.y)):
		for x: int in range(maxi(0, rectangle.position.x), mini(320, rectangle.end.x)):
			if ids[y * 320 + x] == material_id:
				count += 1
	return count

func set_tile_material(x: int, y: int, material: String) -> bool:
	if not grid.inside(x, y):
		last_error = "Material write outside level"
		return false
	var actual: String = {"platform": "bridge", "rock": "bedrock", "limestone": "limestone_a", "marble": "limestone_b"}.get(material, material)
	var rectangle: Rect2i = cell_rect(x, y)
	var error: int = world.clear_rect(rectangle.position.x, rectangle.position.y, 16, 16) if actual == "empty" else world.paint_rect(rectangle.position.x, rectangle.position.y, 16, 16, actual)
	if error != 0:
		last_error = str(world.last_error)
		return false
	var category: int = Grid.Terrain.EMPTY
	for value: int in Grid.TILE_MATERIALS:
		if str(Grid.TILE_MATERIALS[value]) == actual:
			category = value
	if actual == "plug_decay":
		category = Grid.Terrain.PLUG
	_record_material_rect(rectangle, actual)
	grid.terrain[grid.tile_index(x, y)] = category
	if actual == "empty":
		wake_water_near(Vector2i(x, y))
	return true

func link_enabled(group: int) -> bool:
	for device: Dictionary in grid.devices:
		if str(device.get("type", "")) == "lever" and int(device.get("action", {}).get("link", -1)) == group and bool(device.get("on", false)):
			return true
	return false

func trigger_device(index: int) -> bool:
	if index < 0 or index >= grid.devices.size():
		last_error = "Unknown device index: %d" % index
		return false
	var device: Dictionary = grid.devices[index]
	match str(device.get("type", "")):
		"lift":
			return move_platform(index)
		"release":
			if bool(device.get("released", false)):
				return false
			for point: Array in device.get("cells", []):
				if not set_tile_material(int(point[0]), int(point[1]), str(device.get("to", "empty"))):
					return false
			device.released = true
			if str(device.get("to", "")) == "plug_decay":
				world.require_phase(maxi(124, int(device.get("phase_ticks", 124))))
			return true
		"torch", "frost_vent", "heat_vent":
			var region: Array = device.get("area", [])
			if region.size() != 4:
				last_error = "Device has no rectangular action area"
				return false
			var layer: String = "temperature" if device.type == "torch" else str(device.get("layer", "frost" if device.type == "frost_vent" else "heat"))
			var value: int = int(device.get("temperature", 7200)) if device.type == "torch" else int(device.get("value", 1))
			if device.type == "torch":
				var center: Vector2i = Vector2i(int(region[0]) * 16 + int(region[2]) * 8, int(region[1]) * 16 + int(region[3]) * 8)
				var radius: int = mini(int(region[2]), int(region[3])) * 8
				if world.paint_layer_circle(layer, center.x, center.y, radius, value) != 0:
					last_error = str(world.last_error)
					return false
			else:
				for y: int in range(int(region[1]) * 16, (int(region[1]) + int(region[3])) * 16):
					for x: int in range(int(region[0]) * 16, (int(region[0]) + int(region[2])) * 16):
						if world.set_layer_value(layer, x, y, value) != 0:
							last_error = str(world.last_error)
							return false
			if device.type != "torch":
				_layer_pulses.append({"layer": layer, "area": region.duplicate()})
			device.on = not bool(device.get("on", false))
			world.require_phase(maxi(1, int(device.get("phase_ticks", 240 if device.type == "torch" else 4))))
			return true
	last_error = "Unsupported trigger device: " + str(device.get("type", ""))
	return false

func on_physics_tick() -> void:
	_queued_materials.clear()
	# Coupler layers are pulses: clear after their conversion tick so water
	# arriving on a later turn is not silently frozen or melted.
	var pulses: Array[Dictionary] = _layer_pulses.duplicate(true)
	_layer_pulses.clear()
	for pulse: Dictionary in pulses:
		var area: Array = pulse.area
		for y: int in range(int(area[1]) * 16, (int(area[1]) + int(area[3])) * 16):
			for x: int in range(int(area[0]) * 16, (int(area[0]) + int(area[2])) * 16):
				if world.set_layer_value(str(pulse.layer), x, y, 0) != 0:
					last_error = str(world.last_error)
					return
	for mechanic in _mechanics.values():
		if mechanic.has_method("on_physics_tick"):
			_tick_changed = bool(mechanic.on_physics_tick()) or _tick_changed
			if not last_error.is_empty():
				world.last_error = last_error
				return

func take_tick_changes() -> bool:
	var changed: bool = _tick_changed
	_tick_changed = false
	return changed

func move_platform(index: int) -> bool:
	var device: Dictionary = grid.devices[index]
	var stops: Array = device.get("stops", [])
	if stops.size() != 2:
		last_error = "Lift must have two stops"
		return false
	var stop: int = int(device.get("stop", 0))
	var from: Vector2i = Vector2i(int(stops[stop][0]), int(stops[stop][1]))
	var to: Vector2i = Vector2i(int(stops[1 - stop][0]), int(stops[1 - stop][1]))
	var delta: Vector2i = to - from
	var deck_width: int = maxi(1, int(device.get("width", 1)))
	var riders: Array[int] = []
	var player_rides: bool = false
	for x: int in range(from.x, from.x + deck_width):
		for y: int in range(from.y - 1, -1, -1):
			var crate: int = grid.crate_index(x, y)
			if crate >= 0:
				riders.append(crate)
			elif grid.is_player(x, y):
				player_rides = true
			else:
				break
	var path: Vector2i = Vector2i.ZERO
	while path != delta:
		path += Vector2i(0, signi(delta.y - path.y)) if path.y != delta.y else Vector2i(signi(delta.x - path.x), 0)
		for offset: int in range(deck_width):
			if not _platform_path_free(from + Vector2i(offset, 0) + path, from, deck_width, riders, player_rides):
				device.blocked = true
				return false
		for crate: int in riders:
			var body: Dictionary = grid.crates[crate]
			if not _platform_path_free(Vector2i(int(body.x), int(body.y)) + path, from, deck_width, riders, player_rides):
				device.blocked = true
				return false
		if player_rides and not _platform_path_free(Vector2i(int(grid.player.x), int(grid.player.y)) + path, from, deck_width, riders, player_rides):
			device.blocked = true
			return false
	var vacated: Array[Vector2i] = []
	var occupied: Array[Vector2i] = []
	for offset: int in range(deck_width):
		vacated.append(from + Vector2i(offset,0))
		occupied.append(to + Vector2i(offset,0))
		# No displacement rule exists for the deck itself: do not overwrite dust.
		for material: String in ["sand", "gravel"]:
			if material_count(cell_rect(to.x+offset,to.y),material) > 0:
				device.blocked = true
				return false
	for crate: int in riders:
		var body: Dictionary = grid.crates[crate]
		vacated.append(Vector2i(int(body.x),int(body.y)))
		occupied.append(Vector2i(int(body.x),int(body.y))+delta)
	if player_rides:
		vacated.append(Vector2i(int(grid.player.x),int(grid.player.y)))
		occupied.append(Vector2i(int(grid.player.x),int(grid.player.y))+delta)
	var powder_moves: Array[Dictionary] = []
	for crate: int in riders:
		var body: Dictionary = grid.crates[crate]
		var powder: Dictionary = PowderRules.displacement(self,crate,Vector2i(int(body.x),int(body.y))+delta,vacated,occupied)
		if not bool(powder.get("ok",false)):
			device.blocked = true
			return false
		powder_moves.append(powder)
	# Clear all old footprints before writing any destination: stacked riders
	# must never erase another rider or the destination deck while moving.
	for offset: int in range(deck_width):
		if not set_tile_material(from.x + offset, from.y, "empty"):
			return false
	for crate: int in riders:
		var body: Dictionary = grid.crates[crate]
		if not set_tile_material(int(body.x), int(body.y), "empty"):
			return false
	for offset: int in range(deck_width):
		if not set_tile_material(to.x + offset, to.y, "bridge"):
			return false
	for crate: int in riders:
		var body: Dictionary = grid.crates[crate]
		body.x = int(body.x) + delta.x
		body.y = int(body.y) + delta.y
		var rectangle: Rect2i = cell_rect(int(body.x), int(body.y))
		_record_material_rect(rectangle, "iron_crate" if body.kind == "iron" else "crate")
		if world.paint_rect(rectangle.position.x, rectangle.position.y, 16, 16, "iron_crate" if body.kind == "iron" else "crate") != 0:
			last_error = str(world.last_error)
			return false
	for powder: Dictionary in powder_moves:
		if not _apply_powder_displacement(powder):
			return false
	if player_rides:
		grid.player.x = int(grid.player.x) + delta.x
		grid.player.y = int(grid.player.y) + delta.y
	device.stop = 1 - stop
	device.blocked = false
	return true

func _platform_path_free(tile: Vector2i, from: Vector2i, deck_width: int, riders: Array[int], player_rides: bool) -> bool:
	if not grid.inside(tile.x, tile.y):
		return false
	var old_deck: bool = tile.y == from.y and tile.x >= from.x and tile.x < from.x + deck_width
	var category: int = grid.terrain_at(tile.x, tile.y)
	if not old_deck and category not in [Grid.Terrain.EMPTY, Grid.Terrain.SMOKE, Grid.Terrain.FOG]:
		return false
	var crate: int = grid.crate_index(tile.x, tile.y)
	if crate >= 0 and not riders.has(crate):
		return false
	if grid.is_player(tile.x, tile.y) and not player_rides:
		return false
	# Reject a thin pool too: lift movement never discards fractional water.
	return not world.material_ids.has("water") or material_count(cell_rect(tile.x, tile.y), "water") == 0

func blast(tile: Vector2i) -> bool:
	if world.explode(tile.x * 16 + 8, tile.y * 16 + 8, 20, 8000) != 0:
		last_error = str(world.last_error)
		return false
	for mechanic in _mechanics.values():
		if mechanic.has_method("on_blast"):
			mechanic.on_blast(tile, 20.0 / 16.0)
	world.require_phase(maxi(0, int(spec.get("phase_ticks", 0))))
	return last_error.is_empty()

func water_can_pour(destination: Vector2i) -> bool:
	return bool(WaterRules.pour_displacement(self, destination).get("ok", false))

func opening_state() -> Dictionary:
	return _opening_visual_state.duplicate(true)
