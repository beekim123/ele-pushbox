class_name DigMechanic
extends "res://gameplay/mechanics/mechanic.gd"

const Grid = preload("res://gameplay/grid/grid_state.gd")

func actions() -> Array[String]:
	return ["DIG_L", "DIG_R", "DIG_D"]

func try_action(action: String) -> Dictionary:
	if not action.begins_with("DIG_"):
		return {"handled": false}
	if action not in actions():
		return {"handled": true, "accepted": false, "reason": "invalid-direction"}
	var context = session()
	var grid = context.grid
	var direction: String = action.trim_prefix("DIG_")
	var dx: int = -1 if direction == "L" else (1 if direction == "R" else 0)
	var dy: int = 1 if direction == "D" else 0
	var x: int = int(grid.player.x) + dx
	var y: int = int(grid.player.y) + dy
	if not grid.inside(x, y) or grid.terrain_at(x, y) not in [Grid.Terrain.EARTH, Grid.Terrain.SAND] or int(grid.bag.sand) >= 9:
		return {"handled": true, "accepted": false, "reason": "not-diggable"}
	if not context.safe_to_move_tile(x, y):
		return {"handled": true, "accepted": false, "reason": "material-state"}
	return {"handled": true, "accepted": true, "kind": "dig", "clear": Vector2i(x, y), "sand_delta": 1}
