class_name LevelGoals
extends RefCounted

const Grid = preload("res://gameplay/grid/grid_state.gd")

func evaluate(grid, spec: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(grid.markers.size()):
		var x: int = index % grid.width
		var y: int = int(index / grid.width)
		if grid.markers[index] == Grid.Marker.SOCKET:
			var crate: int = grid.crate_index(x, y)
			var lit: bool = crate >= 0
			for goal: Dictionary in spec.get("goals", []):
				if str(goal.get("type", "")) == "socket" and goal.get("at", []) == [x, y]:
					var accept: Dictionary = goal.get("accept", {})
					if accept.has("nested_layers"):
						lit = lit and int(grid.crates[crate].get("nested_layers", 1)) == int(accept.nested_layers) if crate >= 0 else false
			result.append({"kind": "socket", "x": x, "y": y, "lit": lit})
		elif grid.markers[index] == Grid.Marker.EXIT:
			result.append({"kind": "exit", "x": x, "y": y, "lit": grid.is_player(x, y)})
	return result

func won(grid) -> bool:
	var goals: Array[Dictionary] = evaluate(grid)
	if goals.is_empty():
		return false
	for goal: Dictionary in goals:
		if not bool(goal.lit):
			return false
	return true
