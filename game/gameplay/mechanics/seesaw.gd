class_name SeesawMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## New load on one end launches the opposite occupant along a swept path.

const Grid = preload("res://gameplay/grid/grid_state.gd")
var _loads: Dictionary = {}
var _fired: Dictionary = {}
var _last_launch: Dictionary = {}

func setup(spec: Dictionary, context) -> void:
	super.setup(spec, context)
	_loads.clear()
	_fired.clear()
	_last_launch.clear()
	for index: int in range(context.grid.devices.size()):
		var device: Dictionary = context.grid.devices[index]
		if str(device.get("type", "")) == "seesaw" and device.get("ends", []).size() == 2:
			_loads[str(index)] = [_load(_point(device.ends[0])), _load(_point(device.ends[1]))]

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	var changed: bool = false
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "seesaw" or device.get("ends", []).size() != 2:
			continue
		var key: String = str(index)
		var ends: Array = device.ends
		var loads: Array = [_load(_point(ends[0])), _load(_point(ends[1]))]
		var previous: Array = _loads.get(key, loads)
		_loads[key] = loads.duplicate()
		device.loads = loads.duplicate()
		if int(_fired.get(key, -1)) == int(grid.moves):
			continue
		for heavy: int in range(2):
			var light: int = 1 - heavy
			var threshold: float = maxf(0.0, float(device.get("threshold", 1)))
			if float(loads[heavy]) <= float(previous[heavy]) or float(loads[heavy]) - float(previous[heavy]) < threshold:
				continue
			_fired[key] = int(grid.moves)
			var origin: Vector2i = _point(ends[light]) + Vector2i.UP
			var target: Vector2i = origin + Vector2i.UP * maxi(1, int(device.get("height", 2)))
			if device.get("landings", []).size() == 2:
				target = _point(device.landings[light])
			if _launch(origin, target):
				changed = true
				_last_launch = {"device": index, "heavy_end": heavy, "from": [origin.x, origin.y], "to": [target.x, target.y], "move": int(grid.moves)}
			break
	return changed

func get_state() -> Dictionary:
	return {"loads": _loads.duplicate(true), "fired": _fired.duplicate(true), "last_launch": _last_launch.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_loads = state.get("loads", {}).duplicate(true)
	_fired = state.get("fired", {}).duplicate(true)
	_last_launch = state.get("last_launch", {}).duplicate(true)

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(session().grid.devices.size()):
		var device: Dictionary = session().grid.devices[index]
		if str(device.get("type", "")) == "seesaw":
			var paths: Array = []
			if device.get("ends", []).size() == 2:
				for side: int in range(2):
					var origin: Vector2i = _point(device.ends[side]) + Vector2i.UP
					var target: Vector2i = origin + Vector2i.UP * maxi(1, int(device.get("height", 2)))
					if device.get("landings", []).size() == 2:
						target = _point(device.landings[side])
					paths.append(_swept_path(origin, target))
			result.append({"type": "seesaw", "device": index, "ends": device.get("ends", []), "landings": device.get("landings", []), "paths": paths, "loads": _loads.get(str(index), [0, 0]), "threshold": device.get("threshold", 1), "last_launch": _last_launch.duplicate(true)})
	return result

func _load(end: Vector2i) -> float:
	var context = session()
	var grid = context.grid
	var result: float = 0.0
	for y: int in range(end.y - 1, -1, -1):
		var present: bool = false
		if grid.is_player(end.x, y):
			result += 1.0
			present = true
		var crate_index: int = grid.crate_index(end.x, y)
		if crate_index >= 0:
			result += 2.0 if str(grid.crates[crate_index].kind) == "iron" else 1.0
			present = true
		if grid.terrain_at(end.x, y) == Grid.Terrain.SAND:
			# Match the bridge's classified one-tile sand load, never thin dust.
			result += 1.0
			present = true
		if not present:
			break
	return result

func _launch(origin: Vector2i, target: Vector2i) -> bool:
	var context = session()
	var grid = context.grid
	var crate_index: int = grid.crate_index(origin.x, origin.y)
	if crate_index < 0 and not grid.is_player(origin.x, origin.y):
		return false
	if target.y >= origin.y:
		return false
	# First rise vertically, then cross at the apex; every crossed tile must fit.
	for y: int in range(origin.y - 1, target.y - 1, -1):
		if not grid.is_free(origin.x, y):
			return false
	var direction: int = signi(target.x - origin.x)
	if direction != 0:
		for x: int in range(origin.x + direction, target.x + direction, direction):
			if not grid.is_free(x, target.y):
				return false
	if crate_index >= 0:
		if not context.water_can_accept(crate_index, target, "surface") or not context.safe_to_move_tile(origin.x, origin.y):
			return false
		return context.move_crate(crate_index, target)
	grid.player.x = target.x
	grid.player.y = target.y
	return true

func _point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

func _swept_path(origin: Vector2i, target: Vector2i) -> Array:
	var result: Array = [[origin.x, origin.y]]
	for y: int in range(origin.y - 1, target.y - 1, -1):
		result.append([origin.x, y])
	var direction: int = signi(target.x - origin.x)
	if direction != 0:
		for x: int in range(origin.x + direction, target.x + direction, direction):
			result.append([x, target.y])
	return result
