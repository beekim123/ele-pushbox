class_name BinMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## SDK cell counts are sampled during physics so transient fullness also latches.

func setup(level_spec: Dictionary, context) -> void:
	super.setup(level_spec, context)
	for device: Dictionary in context.grid.devices:
		if str(device.get("type", "")) == "bin":
			device.latched = bool(device.get("latched", false))
			device.count = int(device.get("count", 0))

func on_physics_tick() -> bool:
	return _update_bins()

func on_settle_step() -> bool:
	return _update_bins()

func goals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "bin" or not bool(device.get("latch", false)):
			continue
		var rectangle: Array = device.get("rect", [])
		result.append({"kind": "bin", "device": index, "x": int(rectangle[0]), "y": int(rectangle[1]), "lit": bool(device.get("latched", false)), "count": int(device.get("count", 0)), "need": maxi(1, int(device.get("need", 256)))})
	return result

func get_state() -> Dictionary:
	var states: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) == "bin":
			states.append({"index": index, "latched": bool(device.get("latched", false)), "count": int(device.get("count", 0))})
	return {"devices": states}

func set_state(saved: Dictionary) -> void:
	var grid = session().grid
	for state: Dictionary in saved.get("devices", []):
		var index: int = int(state.get("index", -1))
		if index < 0 or index >= grid.devices.size() or str(grid.devices[index].get("type", "")) != "bin":
			continue
		grid.devices[index].latched = bool(state.get("latched", false))
		grid.devices[index].count = int(state.get("count", 0))

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) == "bin":
			result.append({"kind": "bin", "device": index, "rect": device.get("rect", []).duplicate(), "material": str(device.get("material", "water")), "count": int(device.get("count", 0)), "need": maxi(1, int(device.get("need", 256))), "latched": bool(device.get("latched", false)), "goal": bool(device.get("latch", false)), "trigger": device.get("trigger", {}).duplicate(true)})
	return result

func _update_bins() -> bool:
	var context = session()
	var grid = context.grid
	var changed: bool = false
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "bin":
			continue
		var rectangle: Array = device.get("rect", [])
		var bounds: Rect2i = context.cell_rect(int(rectangle[0]), int(rectangle[1]))
		bounds.size *= Vector2i(int(rectangle[2]), int(rectangle[3]))
		device.count = context.sdk_material_count(bounds, str(device.get("material", "water")))
		if not context.last_error.is_empty():
			return changed
		if bool(device.get("latched", false)) or int(device.count) < maxi(1, int(device.get("need", 256))):
			continue
		# Every bin remembers its first threshold crossing, even without a goal lamp.
		device.latched = true
		changed = true
		var trigger: Dictionary = device.get("trigger", {})
		if trigger.has("device"):
			context.trigger_device(int(trigger.device))
			if not context.last_error.is_empty():
				return changed
	return changed
