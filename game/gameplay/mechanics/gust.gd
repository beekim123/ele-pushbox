class_name GustMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Once per action, a gust moves light crates one tile horizontally.

var _last_move: int = 0
var _last_blow: Array[Dictionary] = []

func setup(spec: Dictionary, context) -> void:
	super.setup(spec, context)
	_last_move = int(context.grid.moves)
	_last_blow.clear()

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	if int(grid.moves) <= _last_move or bool(context.settle_step_changed):
		return false
	_last_move = int(grid.moves)
	_last_blow.clear()
	var moved: Dictionary = {}
	var changed: bool = false
	for device_index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[device_index]
		if str(device.get("type", "")) != "gust" or not bool(device.get("enabled", true)):
			continue
		var period: int = maxi(1, int(device.get("period", 1)))
		if posmod(int(grid.moves) - int(device.get("phase", 0)), period) != 0:
			continue
		var values: Array = device.get("area", [0, 0, grid.width, grid.height])
		var area: Rect2i = Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		var direction: int = _direction(device.get("direction", "R"))
		var light: Array = device.get("light_kinds", ["wood", "paper", "balloon", "tumbleweed"])
		var order: Array[int] = []
		for index: int in range(grid.crates.size()):
			order.append(index)
		order.sort_custom(func(a: int, b: int) -> bool: return int(grid.crates[a].x) > int(grid.crates[b].x) if direction > 0 else int(grid.crates[a].x) < int(grid.crates[b].x))
		for index: int in order:
			var crate: Dictionary = grid.crates[index]
			var origin: Vector2i = Vector2i(int(crate.x), int(crate.y))
			if moved.has(index) or str(crate.kind) == "iron" or str(crate.kind) not in light or not area.has_point(origin):
				continue
			moved[index] = true
			var target: Vector2i = origin + Vector2i(direction, 0)
			if not grid.is_free(target.x, target.y) or not context.water_can_accept(index, target, "surface"):
				continue
			if not context.safe_to_move_tile(origin.x, origin.y) or not context.safe_to_move_tile(target.x, target.y):
				continue
			if not context.move_crate(index, target):
				return changed
			changed = true
			_last_blow.append({"device": device_index, "crate": index, "from": [origin.x, origin.y], "to": [target.x, target.y]})
	return changed

func get_state() -> Dictionary:
	return {"last_move": _last_move, "last_blow": _last_blow.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_last_move = int(state.get("last_move", 0))
	_last_blow.clear()
	for item: Dictionary in state.get("last_blow", []):
		_last_blow.append(item.duplicate(true))

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(session().grid.devices.size()):
		var device: Dictionary = session().grid.devices[index]
		if str(device.get("type", "")) == "gust":
			result.append({"type": "gust", "device": index, "area": device.get("area", []), "direction": _direction(device.get("direction", "R")), "period": device.get("period", 1), "last_blow": _last_blow.duplicate(true)})
	return result

func _direction(value: Variant) -> int:
	if value is Array and not value.is_empty():
		return -1 if int(value[0]) < 0 else 1
	return -1 if str(value).to_lower() in ["l", "left", "-1"] else 1
