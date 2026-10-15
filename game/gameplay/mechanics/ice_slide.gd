class_name IceSlideMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## A push onto SDK ice follows the crate until the first blocker or ice edge.

const ICE_SUPPORT_CELLS: int = 128
var _last_slide: Dictionary = {}

func actions() -> Array[String]:
	return ["L", "R"]

func try_action(action: String) -> Dictionary:
	if action not in actions():
		return {"handled": false}
	var context = session()
	var grid = context.grid
	var direction: int = -1 if action == "L" else 1
	var origin: Vector2i = Vector2i(int(grid.player.x) + direction, int(grid.player.y))
	var index: int = grid.crate_index(origin.x, origin.y)
	var destination: Vector2i = origin + Vector2i(direction, 0)
	if index < 0 or not _is_ice(destination + Vector2i.DOWN):
		return {"handled": false}
	if not grid.is_free(destination.x, destination.y) or not context.water_can_accept(index, destination, "surface"):
		return {"handled": true, "accepted": false, "reason": "blocked"}
	if not context.safe_to_move_tile(origin.x, origin.y) or not context.safe_to_move_tile(destination.x, destination.y):
		return {"handled": true, "accepted": false, "reason": "material-state"}
	return {"handled": true, "accepted": true, "kind": "ice_slide", "mechanic": "mechanic:ice_slide", "crate": index, "direction": direction}

func apply_plan(plan: Dictionary) -> bool:
	var context = session()
	var index: int = int(plan.get("crate", -1))
	if index < 0 or index >= context.grid.crates.size():
		context.last_error = "Ice slide refers to a missing crate"
		return false
	var direction: int = int(plan.get("direction", 1))
	var crate: Dictionary = context.grid.crates[index]
	var origin: Vector2i = Vector2i(int(crate.x), int(crate.y))
	var position: Vector2i = origin + Vector2i(direction, 0)
	if not context.move_crate(index, position):
		return false
	context.grid.player.x = origin.x
	context.grid.player.y = origin.y
	var distance: int = 1
	while _is_ice(position + Vector2i.DOWN):
		var target: Vector2i = position + Vector2i(direction, 0)
		if not context.grid.is_free(target.x, target.y) or not context.water_can_accept(index, target, "surface"):
			break
		if not context.safe_to_move_tile(position.x, position.y) or not context.safe_to_move_tile(target.x, target.y):
			break
		if not context.move_crate(index, target):
			return false
		position = target
		distance += 1
	_last_slide = {"crate": index, "from": [origin.x, origin.y], "to": [position.x, position.y], "distance": distance, "move": int(context.grid.moves) + 1}
	return true

func on_settle_step() -> bool:
	return false

func get_state() -> Dictionary:
	return {"last_slide": _last_slide.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_last_slide = state.get("last_slide", {}).duplicate(true)

func observe() -> Array[Dictionary]:
	return [{"type": "ice_slide", "last_slide": _last_slide.duplicate(true)}]

func _is_ice(tile: Vector2i) -> bool:
	var context = session()
	return context.grid.inside(tile.x, tile.y) and context.material_count(context.cell_rect(tile.x, tile.y), "ice") >= ICE_SUPPORT_CELLS
