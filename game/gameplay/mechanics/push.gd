class_name PushMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Includes walk and one-tile ascent, in the exact GD-4.1 priority order.

func actions() -> Array[String]:
	return ["L", "R"]

func try_action(action: String) -> Dictionary:
	if action not in actions():
		return {"handled": false}
	var context = session()
	var grid = context.grid
	var dx: int = -1 if action == "L" else 1
	var x: int = int(grid.player.x)
	var y: int = int(grid.player.y)
	var nx: int = x + dx
	var crate: int = grid.crate_index(nx, y)
	if crate >= 0 and grid.is_free(nx + dx, y):
		if not context.safe_to_move_tile(nx, y):
			return {"handled": true, "accepted": false, "reason": "material-state"}
		return {"handled": true, "accepted": true, "kind": "push", "player": {"x": nx, "y": y}, "crate": crate, "crate_to": {"x": nx + dx, "y": y}}
	if grid.is_free(nx, y):
		return {"handled": true, "accepted": true, "kind": "walk", "player": {"x": nx, "y": y}}
	if grid.supports(nx, y) and grid.is_free(x, y - 1) and grid.is_free(nx, y - 1):
		return {"handled": true, "accepted": true, "kind": "step", "player": {"x": nx, "y": y - 1}}
	return {"handled": true, "accepted": false, "reason": "blocked"}
