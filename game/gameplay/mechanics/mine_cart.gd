class_name MineCartMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## A single side push rolls a cart along horizontal track, carrying its stack.

const Grid = preload("res://gameplay/grid/grid_state.gd")
var _last_roll: Dictionary = {}

func actions() -> Array[String]:
	return ["L", "R"]

func try_action(action: String) -> Dictionary:
	if action not in actions():
		return {"handled": false}
	var context = session()
	var grid = context.grid
	var direction: int = -1 if action == "L" else 1
	var player: Vector2i = Vector2i(int(grid.player.x), int(grid.player.y))
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "mine_cart" or not device.has("at"):
			continue
		var at: Vector2i = _point(device.at)
		var width: int = maxi(1, int(device.get("width", 1)))
		var edge: int = at.x if direction > 0 else at.x + width - 1
		if player.y != at.y or player.x + direction != edge:
			continue
		var riders: Dictionary = _riders(device)
		if not _can_translate(index, direction, riders):
			return {"handled": true, "accepted": false, "reason": "cart-blocked"}
		for crate_index: int in riders.crates:
			var crate: Dictionary = grid.crates[crate_index]
			if not context.safe_to_move_tile(int(crate.x), int(crate.y)):
				return {"handled": true, "accepted": false, "reason": "material-state"}
		return {"handled": true, "accepted": true, "kind": "mine_cart", "mechanic": "mechanic:mine_cart", "device": index, "direction": direction, "player": {"x": player.x + direction, "y": player.y}}
	return {"handled": false}

func apply_plan(plan: Dictionary) -> bool:
	var context = session()
	var grid = context.grid
	var index: int = int(plan.get("device", -1))
	if index < 0 or index >= grid.devices.size():
		context.last_error = "Mine cart plan refers to an unknown device"
		return false
	var device: Dictionary = grid.devices[index]
	var direction: int = int(plan.get("direction", 1))
	var origin: Vector2i = _point(device.at)
	var distance: int = 0
	while true:
		var riders: Dictionary = _riders(device)
		if not _can_translate(index, direction, riders):
			break
		var previous_at: Vector2i = _point(device.at)
		var deck_width: int = maxi(1, int(device.get("width", 1)))
		for offset: int in range(deck_width):
			if not context.set_tile_material(previous_at.x + offset, previous_at.y, "empty"):
				return false
		# Front-to-back order makes overlapping source/target stacks safe.
		var order: Array[int] = []
		for crate_index: int in riders.crates:
			order.append(crate_index)
		order.sort_custom(func(a: int, b: int) -> bool: return int(grid.crates[a].x) > int(grid.crates[b].x) if direction > 0 else int(grid.crates[a].x) < int(grid.crates[b].x))
		for crate_index: int in order:
			var crate: Dictionary = grid.crates[crate_index]
			if not context.safe_to_move_tile(int(crate.x), int(crate.y)):
				context.last_error = "A mine cart rider cannot move in its material state"
				return false
			if not context.move_crate(crate_index, Vector2i(int(crate.x) + direction, int(crate.y))):
				return false
		if bool(riders.player):
			grid.player.x = int(grid.player.x) + direction
		var at: Vector2i = _point(device.at) + Vector2i(direction, 0)
		device.at = [at.x, at.y]
		for offset: int in range(deck_width):
			if not context.set_tile_material(at.x + offset, at.y, "bridge"):
				return false
		distance += 1
	if distance == 0:
		context.last_error = "Mine cart no longer has a clear track"
		return false
	# The person pushing follows only the initial step, while the cart rolls on.
	if plan.has("player"):
		grid.player = plan.player.duplicate(true)
	_last_roll = {"device": index, "from": [origin.x, origin.y], "to": device.at.duplicate(), "distance": distance, "direction": direction}
	device.last_roll = _last_roll.duplicate(true)
	return true

func on_settle_step() -> bool:
	return false

func get_state() -> Dictionary:
	var carts: Dictionary = {}
	for index: int in range(session().grid.devices.size()):
		var device: Dictionary = session().grid.devices[index]
		if str(device.get("type", "")) == "mine_cart":
			carts[str(index)] = {"at": device.get("at", []).duplicate(), "last_roll": device.get("last_roll", {}).duplicate(true)}
	return {"carts": carts, "last_roll": _last_roll.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_last_roll = state.get("last_roll", {}).duplicate(true)
	for key: String in state.get("carts", {}):
		var index: int = int(key)
		if index < 0 or index >= session().grid.devices.size():
			continue
		var saved: Dictionary = state.carts[key]
		session().grid.devices[index].at = saved.at.duplicate()
		session().grid.devices[index].last_roll = saved.get("last_roll", {}).duplicate(true)

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(session().grid.devices.size()):
		var device: Dictionary = session().grid.devices[index]
		if str(device.get("type", "")) == "mine_cart":
			result.append({"type": "mine_cart", "device": index, "at": device.get("at", []), "width": device.get("width", 1), "track": device.get("track", []), "riders": _riders(device), "last_roll": device.get("last_roll", {})})
	return result

func _riders(device: Dictionary) -> Dictionary:
	var grid = session().grid
	var at: Vector2i = _point(device.at)
	var crates: Array[int] = []
	var player: bool = false
	for x: int in range(at.x, at.x + maxi(1, int(device.get("width", 1)))):
		for y: int in range(at.y - 1, -1, -1):
			var crate_index: int = grid.crate_index(x, y)
			var has_player: bool = grid.is_player(x, y)
			if crate_index < 0 and not has_player:
				break
			if crate_index >= 0:
				crates.append(crate_index)
			player = player or has_player
	return {"crates": crates, "player": player}

func _can_translate(device_index: int, direction: int, riders: Dictionary) -> bool:
	var context = session()
	var grid = context.grid
	var device: Dictionary = grid.devices[device_index]
	var at: Vector2i = _point(device.at)
	var destination: Vector2i = at + Vector2i(direction, 0)
	var width: int = maxi(1, int(device.get("width", 1)))
	var track: Array = device.get("track", [])
	for x: int in range(destination.x, destination.x + width):
		if not track.has([x, destination.y]) or not grid.inside(x, destination.y):
			return false
		var old_deck: bool = destination.y == at.y and x >= at.x and x < at.x + width
		if (not old_deck and grid.terrain_at(x, destination.y) not in [Grid.Terrain.EMPTY, Grid.Terrain.SMOKE, Grid.Terrain.FOG]) or grid.crate_index(x, destination.y) >= 0 or grid.is_player(x, destination.y):
			return false
		if context.material_count(context.cell_rect(x, destination.y), "water") > 0:
			return false
		for other_index: int in range(grid.devices.size()):
			if other_index == device_index:
				continue
			var other: Dictionary = grid.devices[other_index]
			if str(other.get("type", "")) == "mine_cart" and other.has("at"):
				var other_at: Vector2i = _point(other.at)
				if other_at.y == destination.y and x >= other_at.x and x < other_at.x + maxi(1, int(other.get("width", 1))):
					return false
	for crate_index: int in riders.crates:
		var crate: Dictionary = grid.crates[crate_index]
		var target: Vector2i = Vector2i(int(crate.x) + direction, int(crate.y))
		if not _rider_destination_clear(target, riders):
			return false
		var other_crate: int = grid.crate_index(target.x, target.y)
		if other_crate < 0 and not context.water_can_accept(crate_index, target, "surface"):
			return false
	if bool(riders.player):
		var player_target: Vector2i = Vector2i(int(grid.player.x) + direction, int(grid.player.y))
		if not _rider_destination_clear(player_target, riders):
			return false
	return true

func _rider_destination_clear(tile: Vector2i, riders: Dictionary) -> bool:
	var grid = session().grid
	if not grid.inside(tile.x, tile.y) or grid.terrain_at(tile.x, tile.y) not in [Grid.Terrain.EMPTY, Grid.Terrain.WATER]:
		return false
	var index: int = grid.crate_index(tile.x, tile.y)
	if index >= 0 and index not in riders.crates:
		return false
	return not grid.is_player(tile.x, tile.y) or bool(riders.player)

func _point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
