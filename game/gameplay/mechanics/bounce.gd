class_name BounceMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## A downward arrival on a mushroom launches an entity vertically once per move.

var _previous: Dictionary = {}
var _fired: Dictionary = {}
var _next_uid: int = 0
var _last_launch: Dictionary = {}

func setup(spec: Dictionary, context) -> void:
	super.setup(spec, context)
	_previous.clear()
	_fired.clear()
	_next_uid = 0
	_last_launch.clear()
	_remember_positions()

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	var changed: bool = false
	for device_index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[device_index]
		if str(device.get("type", "")) != "bounce" or not device.has("at"):
			continue
		var top: Vector2i = Vector2i(int(device.at[0]), int(device.at[1]) - 1)
		var entity: String = ""
		var crate_index: int = grid.crate_index(top.x, top.y)
		if grid.is_player(top.x, top.y):
			entity = "player"
		elif crate_index >= 0:
			entity = _crate_uid(grid.crates[crate_index])
		if entity.is_empty() or not _previous.has(entity):
			continue
		var previous: Array = _previous[entity]
		var key: String = "%d:%s" % [device_index, entity]
		if int(previous[1]) >= top.y or int(_fired.get(key, -1)) == int(grid.moves):
			continue
		# Record even a blocked landing, so headroom cannot cause an idle loop.
		_fired[key] = int(grid.moves)
		var target: Vector2i = top + Vector2i.UP * maxi(1, int(device.get("height", 2)))
		var clear: bool = true
		for y: int in range(top.y - 1, target.y - 1, -1):
			if not grid.is_free(top.x, y):
				clear = false
				break
		if not clear:
			continue
		if crate_index >= 0:
			if not context.water_can_accept(crate_index, target, "surface") or not context.safe_to_move_tile(top.x, top.y):
				continue
			if not context.move_crate(crate_index, target):
				return changed
		else:
			grid.player.x = target.x
			grid.player.y = target.y
		changed = true
		_last_launch = {"device": device_index, "entity": entity, "from": [top.x, top.y], "to": [target.x, target.y], "move": int(grid.moves)}
	_remember_positions()
	return changed

func get_state() -> Dictionary:
	return {"previous": _previous.duplicate(true), "fired": _fired.duplicate(true), "next_uid": _next_uid, "last_launch": _last_launch.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_previous = state.get("previous", {}).duplicate(true)
	_fired = state.get("fired", {}).duplicate(true)
	_next_uid = int(state.get("next_uid", 0))
	_last_launch = state.get("last_launch", {}).duplicate(true)

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(session().grid.devices.size()):
		var device: Dictionary = session().grid.devices[index]
		if str(device.get("type", "")) == "bounce":
			result.append({"type": "bounce", "device": index, "at": device.get("at", []), "height": device.get("height", 2), "last_launch": _last_launch.duplicate(true)})
	return result

func _crate_uid(crate: Dictionary) -> String:
	if crate.has("id"):
		return "crate:" + str(crate.id)
	if not crate.has("bounce_uid"):
		_next_uid += 1
		crate.bounce_uid = _next_uid
	return "crate:%d" % int(crate.bounce_uid)

func _remember_positions() -> void:
	var grid = session().grid
	_previous = {"player": [int(grid.player.x), int(grid.player.y)]}
	for crate: Dictionary in grid.crates:
		_previous[_crate_uid(crate)] = [int(crate.x), int(crate.y)]
