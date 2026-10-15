class_name LevelGoals
extends RefCounted

const Grid = preload("res://gameplay/grid/grid_state.gd")

func evaluate(grid) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(grid.markers.size()):
		var x: int = index % grid.width
		var y: int = int(index / grid.width)
		if grid.markers[index] == Grid.Marker.SOCKET:
			result.append({"kind": "socket", "x": x, "y": y, "lit": grid.crate_index(x, y) >= 0})
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
