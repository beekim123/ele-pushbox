class_name PourMechanic
extends "res://gameplay/mechanics/mechanic.gd"

func actions() -> Array[String]:
	return ["POUR_L", "POUR_R"]

func try_action(action: String) -> Dictionary:
	if not action.begins_with("POUR_"):
		return {"handled": false}
	if action not in actions():
		return {"handled": true, "accepted": false, "reason": "invalid-direction"}
	var grid = session().grid
	var x: int = int(grid.player.x) + (-1 if action == "POUR_L" else 1)
	var y: int = int(grid.player.y)
	if int(grid.bag.sand) < 1 or not grid.is_free(x, y):
		return {"handled": true, "accepted": false, "reason": "cannot-pour"}
	return {"handled": true, "accepted": true, "kind": "pour", "pour": Vector2i(x, y), "sand_delta": -1}
