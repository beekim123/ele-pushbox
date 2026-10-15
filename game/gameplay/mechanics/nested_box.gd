class_name NestedBoxMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Damage removes one shell, exposing the next full-tile crate (at most three).

const Grid = preload("res://gameplay/grid/grid_state.gd")
const TILE_SIZE: int = 16
var _layers: Dictionary = {}
var _last_damage_move: Dictionary = {}
var _last_damage: Dictionary = {}
var _bindings: Dictionary = {}

func setup(spec: Dictionary, context) -> void:
	super.setup(spec, context)
	_layers.clear()
	_last_damage_move.clear()
	_last_damage.clear()
	_bindings.clear()
	for index: int in range(context.grid.devices.size()):
		var device: Dictionary = context.grid.devices[index]
		if str(device.get("type", "")) != "nested_box" or not device.has("at"):
			continue
		var crate_index: int = context.grid.crate_index(int(device.at[0]), int(device.at[1]))
		if crate_index < 0:
			continue
		_layers[str(index)] = 0
		var crate: Dictionary = context.grid.crates[crate_index]
		crate.nested_device = index
		crate.nested_layer = 0
		crate.nested_scale = 1.0
		var kinds: Array = _kinds(device)
		crate.kind = str(kinds[0])
		crate.nested_layers = kinds.size()
		if crate.has("id"):
			_bindings[str(index)] = str(crate.id)

func on_blast(center: Vector2i, radius: float) -> bool:
	var context = session()
	var changed: bool = false
	# Iterate devices, because destruction can remove/reindex the crate array.
	for index: int in range(context.grid.devices.size()):
		if str(context.grid.devices[index].get("type", "")) != "nested_box":
			continue
		var crate_index: int = _crate_index(index)
		if crate_index < 0:
			continue
		var crate: Dictionary = context.grid.crates[crate_index]
		var distance: Vector2 = Vector2(int(crate.x) - center.x, int(crate.y) - center.y)
		if distance.length_squared() <= radius * radius:
			changed = _damage(index, "blast") or changed
	return changed

func on_settle_step() -> bool:
	var context = session()
	var changed: bool = false
	for index: int in range(context.grid.devices.size()):
		if str(context.grid.devices[index].get("type", "")) != "nested_box":
			continue
		if int(_last_damage_move.get(str(index), -1)) == int(context.grid.moves):
			continue
		var crate_index: int = _crate_index(index)
		if crate_index < 0:
			continue
		var crate: Dictionary = context.grid.crates[crate_index]
		var cause: String = _contact_damage(Vector2i(int(crate.x), int(crate.y)))
		if not cause.is_empty():
			changed = _damage(index, cause) or changed
	return changed

func get_state() -> Dictionary:
	return {"layers": _layers.duplicate(true), "last_damage_move": _last_damage_move.duplicate(true), "last_damage": _last_damage.duplicate(true), "bindings": _bindings.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_layers = state.get("layers", {}).duplicate(true)
	_last_damage_move = state.get("last_damage_move", {}).duplicate(true)
	_last_damage = state.get("last_damage", {}).duplicate(true)
	_bindings = state.get("bindings", {}).duplicate(true)

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "nested_box":
			continue
		var crate_index: int = _crate_index(index)
		var at: Array = device.get("at", [])
		var scale_value: float = 0.0
		if crate_index >= 0:
			at = [int(grid.crates[crate_index].x), int(grid.crates[crate_index].y)]
			scale_value = float(grid.crates[crate_index].get("nested_scale", 1.0))
		result.append({"type": "nested_box", "device": index, "at": at, "layer": _layers.get(str(index), 0), "layers": _kinds(device).size(), "destroyed": crate_index < 0, "scale": scale_value, "last_damage": _last_damage.get(str(index), {})})
	return result

func _damage(device_index: int, cause: String) -> bool:
	var context = session()
	var grid = context.grid
	var index: int = _crate_index(device_index)
	if index < 0:
		return false
	var crate: Dictionary = grid.crates[index]
	var key: String = str(device_index)
	var kinds: Array = _kinds(grid.devices[device_index])
	var next_layer: int = int(_layers.get(key, 0)) + 1
	var x: int = int(crate.x)
	var y: int = int(crate.y)
	if next_layer >= kinds.size():
		# The exposed innermost crate follows normal indestructible crate rules.
		return false
	var kind: String = str(kinds[next_layer])
	var material: String = "iron_crate" if kind == "iron" else "crate"
	if context.world.paint_rect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE, material) != 0:
		context.last_error = str(context.world.last_error)
		return false
	crate.kind = kind
	crate.nested_layer = next_layer
	crate.nested_layers = kinds.size() - next_layer
	crate.nested_scale = 1.0 - 0.25 * float(next_layer)
	grid.terrain[grid.tile_index(x, y)] = Grid.Terrain.EMPTY
	_layers[key] = next_layer
	var damage_move: int = int(grid.moves) + (1 if cause == "blast" and not context.busy else 0)
	_last_damage_move[key] = damage_move
	_last_damage[key] = {"cause": cause, "layer": next_layer, "at": [x, y], "move": damage_move}
	return true

func _contact_damage(tile: Vector2i) -> String:
	var context = session()
	var rectangle: Rect2i = context.cell_rect(tile.x, tile.y)
	var borders: Array[Rect2i] = [Rect2i(rectangle.position.x - 1, rectangle.position.y, 1, TILE_SIZE), Rect2i(rectangle.end.x, rectangle.position.y, 1, TILE_SIZE), Rect2i(rectangle.position.x, rectangle.position.y - 1, TILE_SIZE, 1), Rect2i(rectangle.position.x, rectangle.end.y, TILE_SIZE, 1)]
	for border: Rect2i in borders:
		if context.material_count(border, "acid") > 0:
			return "acid"
		for y: int in range(border.position.y, border.end.y):
			for x: int in range(border.position.x, border.end.x):
				if bool(context.world.get_cell(x, y).get("burning", false)):
					return "burn"
	return ""

func _crate_index(device_index: int) -> int:
	var crates: Array = session().grid.crates
	for index: int in range(crates.size()):
		if _bindings.has(str(device_index)):
			if str(crates[index].get("id", "")) == str(_bindings[str(device_index)]):
				return index
		elif int(crates[index].get("nested_device", -1)) == device_index:
			return index
	return -1

func _kinds(device: Dictionary) -> Array:
	var kinds: Array = device.get("layers", ["wood", "wood", "wood"])
	if kinds.is_empty():
		return ["wood"]
	return kinds.slice(0, mini(3, kinds.size()))
