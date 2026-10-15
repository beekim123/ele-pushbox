class_name PortalMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Arrival locks follow an entity until it leaves that destination pad.

func setup(level_spec: Dictionary, context) -> void:
	super.setup(level_spec, context)
	for device: Dictionary in context.grid.devices:
		if str(device.get("type", "")) == "portal":
			device.blocked = []

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	# Release arrival locks even while other rules are still moving entities.
	for device: Dictionary in grid.devices:
		if str(device.get("type", "")) != "portal":
			continue
		var retained: Array[Dictionary] = []
		for lock: Dictionary in device.get("blocked", []):
			var tile: int = int(lock.get("pad", -1))
			if tile >= 0 and _occupant_key(tile % grid.width, int(tile / grid.width)) == str(lock.get("entity", "")):
				retained.append(lock.duplicate())
		device.blocked = retained
	if bool(context.settle_step_changed):
		return false
	for device: Dictionary in grid.devices:
		if str(device.get("type", "")) != "portal":
			continue
		var pads: Array = device.get("pads", [])
		for source_pad: int in range(2):
			var source: Vector2i = Vector2i(int(pads[source_pad][0]), int(pads[source_pad][1]))
			var entity: String = _occupant_key(source.x, source.y)
			if entity.is_empty() or _arrival_locked(device, entity, grid.tile_index(source.x, source.y)):
				continue
			var destination_pad: Array = pads[1 - source_pad]
			var destination: Vector2i = Vector2i(int(destination_pad[0]), int(destination_pad[1]))
			if not grid.is_free(destination.x, destination.y):
				continue
			if entity == "player":
				grid.player.x = destination.x
				grid.player.y = destination.y
			else:
				var crate: int = grid.crate_index(source.x, source.y)
				if not context.water_can_accept(crate, destination, "surface"):
					continue
				if not context.move_crate(crate, destination, "surface"):
					return false
			device.blocked.append({"entity": entity, "pad": grid.tile_index(destination.x, destination.y)})
			# The next round settles this arrival before another entity is sent.
			return true
	return false

func get_state() -> Dictionary:
	var states: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) == "portal":
			states.append({"index": index, "blocked": device.get("blocked", []).duplicate(true)})
	return {"devices": states}

func set_state(saved: Dictionary) -> void:
	var grid = session().grid
	for state: Dictionary in saved.get("devices", []):
		var index: int = int(state.get("index", -1))
		if index >= 0 and index < grid.devices.size() and str(grid.devices[index].get("type", "")) == "portal":
			grid.devices[index].blocked = state.get("blocked", []).duplicate(true)

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) == "portal":
			result.append({"kind": "portal", "device": index, "pads": device.get("pads", []).duplicate(true), "symbol": str(device.get("symbol", "circle")), "blocked": device.get("blocked", []).duplicate(true)})
	return result

func _occupant_key(x: int, y: int) -> String:
	var grid = session().grid
	if grid.is_player(x, y):
		return "player"
	var crate: int = grid.crate_index(x, y)
	return "crate:" + str(grid.crates[crate].get("id", crate)) if crate >= 0 else ""

func _arrival_locked(device: Dictionary, entity: String, tile: int) -> bool:
	for lock: Dictionary in device.get("blocked", []):
		if str(lock.get("entity", "")) == entity and int(lock.get("pad", -1)) == tile:
			return true
	return false
