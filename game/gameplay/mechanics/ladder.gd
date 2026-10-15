class_name LadderMechanic
extends "res://gameplay/mechanics/mechanic.gd"

func actions() -> Array[String]:
	return ["U", "D"]

func try_action(action: String) -> Dictionary:
	if action not in actions():
		return {"handled": false}
	var grid = session().grid
	var x: int = int(grid.player.x)
	var y: int = int(grid.player.y)
	if action == "U" and grid.is_ladder(x, y) and grid.is_ladder(x, y - 1) and grid.is_free(x, y - 1):
		return {"handled": true, "accepted": true, "kind": "climb", "player": {"x": x, "y": y - 1}}
	if action == "D" and (grid.is_ladder(x, y) or grid.is_ladder(x, y + 1)) and grid.is_free(x, y + 1):
		return {"handled": true, "accepted": true, "kind": "climb", "player": {"x": x, "y": y + 1}}
	return {"handled": true, "accepted": false, "reason": "no-ladder"}
