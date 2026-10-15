class_name LiftMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Buttons fire on an arrival edge; the session moves the complete platform load.

func setup(level_spec: Dictionary, context) -> void:
	super.setup(level_spec, context)
	for device: Dictionary in context.grid.devices:
		if str(device.get("type", "")) != "lift":
			continue
		device.stop = int(device.get("stop", 0))
		device.blocked = bool(device.get("blocked", false))
		# An entity initially standing on a button is already holding it down.
		device.pressed = _button_pressed(device)

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	var changed: bool = false
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "lift" or not device.has("button"):
			continue
		var pressed: bool = _button_pressed(device)
		var was_pressed: bool = bool(device.get("pressed", false))
		device.pressed = pressed
		if pressed != was_pressed:
			changed = true
		if pressed and not was_pressed:
			var moved: bool = context.trigger_device(index)
			changed = moved or changed
	return changed

func get_state() -> Dictionary:
	var states: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) == "lift":
			states.append({"index": index, "stop": int(device.get("stop", 0)), "pressed": bool(device.get("pressed", false)), "blocked": bool(device.get("blocked", false))})
	return {"devices": states}

func set_state(saved: Dictionary) -> void:
	var grid = session().grid
	for state: Dictionary in saved.get("devices", []):
		var index: int = int(state.get("index", -1))
		if index < 0 or index >= grid.devices.size() or str(grid.devices[index].get("type", "")) != "lift":
			continue
		grid.devices[index].stop = int(state.get("stop", 0))
		grid.devices[index].pressed = bool(state.get("pressed", false))
		grid.devices[index].blocked = bool(state.get("blocked", false))

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "lift":
			continue
		var stops: Array = device.get("stops", [])
		var stop: int = int(device.get("stop", 0))
		var at: Array = stops[stop]
		result.append({"kind": "lift", "device": index, "x": int(at[0]), "y": int(at[1]), "width": int(device.get("width", 1)), "stop": stop, "pressed": bool(device.get("pressed", false)), "blocked": bool(device.get("blocked", false)), "button": device.get("button", []).duplicate()})
	return result

func _button_pressed(device: Dictionary) -> bool:
	var button: Array = device.get("button", [])
	if button.size() != 2:
		return false
	var grid = session().grid
	var x: int = int(button[0])
	var y: int = int(button[1])
	return grid.is_player(x, y) or grid.crate_index(x, y) >= 0
