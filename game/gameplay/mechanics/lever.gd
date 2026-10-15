class_name LeverMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Lever actions are plans; the session commits their toggle with the undo point.

func setup(level_spec: Dictionary, context) -> void:
	super.setup(level_spec, context)
	for device: Dictionary in context.grid.devices:
		if str(device.get("type", "")) == "lever":
			device.on = bool(device.get("on", false))

func actions() -> Array[String]:
	return ["U"]

func try_action(action: String) -> Dictionary:
	if action != "U":
		return {"handled": false}
	var grid = session().grid
	var x: int = int(grid.player.x)
	var y: int = int(grid.player.y)
	# Ladder input keeps its design-model priority on a shared tile.
	if grid.is_ladder(x, y):
		return {"handled": false}
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "lever":
			continue
		var at: Array = device.get("at", [])
		if at.size() == 2 and int(at[0]) == x and int(at[1]) == y:
			return {"handled": true, "accepted": true, "kind": "lever", "device": index}
	return {"handled": false}

func get_state() -> Dictionary:
	var states: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) == "lever":
			states.append({"index": index, "on": bool(device.get("on", false))})
	return {"devices": states}

func set_state(saved: Dictionary) -> void:
	var grid = session().grid
	for state: Dictionary in saved.get("devices", []):
		var index: int = int(state.get("index", -1))
		if index >= 0 and index < grid.devices.size() and str(grid.devices[index].get("type", "")) == "lever":
			grid.devices[index].on = bool(state.get("on", false))

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "lever":
			continue
		var at: Array = device.get("at", [])
		result.append({"kind": "lever", "device": index, "x": int(at[0]), "y": int(at[1]), "on": bool(device.get("on", false)), "action": device.get("action", {}).duplicate(true), "symbol": str(device.get("symbol", "circle"))})
	return result
